extends Node3D
## Derived visual habitats; every root samples the authoritative driving height.
const SURVEYS = preload("res://scripts/expedition_activities.gd")
const ZONES := [
	{"id":0,"start":173.0,"end":-5.0,"name":"FrostShelf"},
	{"id":1,"start":-16.0,"end":-162.0,"name":"EmberTerrace"},
	{"id":2,"start":-175.0,"end":-347.0,"name":"VeilRootbed"},
	{"id":3,"start":-362.0,"end":-635.0,"name":"PaleGarden"}]
var terrain: Node3D
var batches: Array[Dictionary] = []
var ground_material: ShaderMaterial
var clock := 0.0
var source_meshes: Dictionary = {}
var rng := RandomNumberGenerator.new()
var low := false
var microfauna: Node3D
var _clearance_points: Array[Vector2] = []
var _ground_nodes: Array[MeshInstance3D] = []
var _formations: Array[Dictionary] = []
var _triangle_budget := 0
var collision_shapes: Dictionary = {}
var placements: Array[Dictionary] = []
var _collision_count := 0
var _material_pairs: Array[Dictionary] = []
var _kit_materials: Dictionary = {}
var _support_vertices: Dictionary = {}
var _family_bounds: Dictionary = {}
var _collision_chunks: Dictionary = {}
var _shadow_position:=Vector2(INF,INF)
var exposed_geology: Array[Dictionary] = []
const SOLID_FAMILIES := ["frost_shelf","frost_rack","frost_blade","vent_stack","rift_terrace","basalt_broken","pale_branch","pale_nurse","pale_stump","root_hummock","canopy","riparian_tree","riparian_arch","riparian_snag","fallen_root","marsh_bank_rock","root_bank","basalt_column","pale_copse"]
# Cross-road offset, longitudinal centre, cross extent, along extent. Each follows
# its own shelf/fault/watershed/collapse rather than five evenly spaced tree rows.
const REGIONAL_GROVES := [
	[Vector4(-49,140,28,32),Vector4(65,95,27,31),Vector4(-64,32,36,32)],
	[Vector4(-49,-36,19,26),Vector4(62,-57,27,26),Vector4(-61,-115,21,30),Vector4(73,-145,25,15)],
	[Vector4(-66,-202,28,25),Vector4(52,-211,22,20),Vector4(-58,-260,25,40),Vector4(-77,-308,22,24)],
	[Vector4(-38,-395,28,27),Vector4(58,-435,28,23),Vector4(-57,-497,30,50),Vector4(58,-571,30,35),Vector4(-40,-610,25,20)]]

func build(world: Node3D) -> void:
	terrain = world
	rng.seed = 26092026
	ground_material = ShaderMaterial.new()
	ground_material.shader = load("res://shaders/ground_life.gdshader")
	for id in SURVEYS.SITES: _clearance_points.append(SURVEYS.point(id))
	for point in terrain.passage_route(): _clearance_points.append(point)
	for point in terrain.root_network_points(): _clearance_points.append(point)
	_clearance_points.append(Vector2(terrain.signal_origin().x,-650.0))
	_clearance_points.append(Vector2(-61.0,-148.0))
	_clearance_points.append_array(terrain.ecology_anchor_points())
	for family in ["canopy","sails","pods","cups","spores"]:
		_load_family(family)
		await terrain.boot_yield()
	_build_native_kit()
	await terrain.boot_yield()
	_build_riparian_kits()
	await terrain.boot_yield()
	_build_mass_templates()
	await terrain.boot_yield()
	_build_region_variants()
	await terrain.boot_yield()
	for zone in ZONES:
		await _build_region(zone)
		await terrain.boot_yield()
	await _build_marsh_shore(terrain._wetland_center())
	var count := 0
	for entry in _formations: count += int(entry.count)
	terrain.build_stats["authored_flora_instances"] = count
	terrain.build_stats["flora_spatial_batches"] = batches.size()
	terrain.build_stats["flora_families"] = source_meshes.size()
	terrain.build_stats["native_habitat_materials"] = _kit_materials.size()
	terrain.build_stats["regional_shape_variants"] = 5
	terrain.build_stats["regional_formations"] = _formations.size()
	terrain.build_stats["regional_ground_triangles"] = _triangle_budget
	terrain.build_stats["habitat_collision_instances"] = _collision_count
	terrain.build_stats["habitat_shared_collision_shapes"] = collision_shapes.size()
	terrain.build_stats["habitat_collision_bodies"] = _collision_chunks.size()
	terrain.build_stats["habitat_clearance_road_m"] = 10.0
	terrain.build_stats["habitat_clearance_activity_m"] = 6.0
	_build_microfauna(terrain._wetland_center())

func _clear(x: float,z: float,radius: float,activity: bool=true) -> bool:
	# Avoid straddling existing gameplay height-field branch boundaries with rigid roots.
	if radius>1.5:
		for boundary in [40.0,-130.0,-300.0,-470.0]:
			if absf(z-boundary)<radius+1.8:return false
	# The road is sampled at the footprint's ends as well as its centre.
	for dz in [-radius,0.0,radius]:
		if absf(x-terrain.path_x(z+dz)) < 5.2+radius: return false
	if activity:
		for point in _clearance_points:
			if Vector2(x,z).distance_to(point) < 6.0+radius: return false
	if terrain.wetland_basin_distance(Vector2(x,z)) < 1.10+radius*.055: return false
	return true

func _placement(x: float,z: float,size: float,yaw: float=INF) -> Transform3D:
	var angle := rng.randf()*TAU if is_inf(yaw) else yaw
	var dx: float=(terrain.height_at(x+1.25,z)-terrain.height_at(x-1.25,z))/2.5
	var dz: float=(terrain.height_at(x,z+1.25)-terrain.height_at(x,z-1.25))/2.5
	var normal := Vector3(-dx,1.0,-dz).normalized()
	var across := Vector3(1.0,dx,0.0).normalized()
	var slope := Basis(across,normal,across.cross(normal).normalized())
	return Transform3D(slope*Basis(Vector3.UP,angle).scaled(Vector3.ONE*size),Vector3(x,terrain.height_at(x,z)-.10*size,z))

func _seat_transform(family: String,t: Transform3D) -> Transform3D:
	# The meshes never mutate after kit registration. Cache exact support vertices,
	# rather than reading/filtering every full mesh for every placement.
	if not _support_vertices.has(family):
		var bottom := INF
		for part: Dictionary in source_meshes[family]: bottom=minf(bottom,part.mesh.get_aabb().position.y)
		var support := PackedVector3Array()
		var unique: Dictionary = {}
		for part: Dictionary in source_meshes[family]:
			var vertices: PackedVector3Array=part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for local: Vector3 in vertices:
				if local.y<=bottom+.2 and not unique.has(local):
					unique[local]=true
					support.append(local)
		_support_vertices[family]=support
	var gap := -INF
	for local: Vector3 in _support_vertices[family]:
		var point := t*local
		gap=maxf(gap,point.y-terrain.height_at(point.x,point.z))
	if gap>-.025:t.origin.y-=gap+.025
	return t

func _footprint(family: String,basis: Basis) -> float:
	if not _family_bounds.has(family):
		var bounds: AABB=source_meshes[family][0].mesh.get_aabb()
		for part: Dictionary in source_meshes[family]:bounds=bounds.merge(part.mesh.get_aabb())
		_family_bounds[family]=bounds
	var radius:=0.0
	var bounds: AABB=_family_bounds[family]
	for i in 8:
		var corner:Vector3=basis*bounds.get_endpoint(i)
		radius=maxf(radius,Vector2(corner.x,corner.z).length())
	return radius

func _grove_place(transforms: Dictionary,family: String,point: Vector2,scale_value: float,yaw: float,height_scale: float=1.0) -> bool:
	var pose:=_placement(point.x,point.y,scale_value,yaw)
	pose.basis=pose.basis.scaled_local(Vector3(1,height_scale,1))
	if not _clear(point.x,point.y,_footprint(family,pose.basis)):return false
	transforms[family].append(pose)
	return true

func _build_region(zone: Dictionary) -> void:
	var id:int=zone.id
	await _build_exposed_strata(id)
	var transforms: Dictionary={}
	for family in source_meshes:transforms[family]=[]
	var clusters: Array[Vector3]=[]
	var placed: Array[Vector2]=[]
	for grove:Vector4 in REGIONAL_GROVES[id]:
		var z:=grove.y
		var side:=signf(grove.x)
		var cx:float=terrain.path_x(z)+grove.x
		var cross_extent:=grove.z
		var along_extent:=grove.w
		var wanted:int=[18,20,23,20][id]
		var accepted:=0
		# ponytail: under 150 structural instances/zone; use a grid if that ceiling grows.
		for attempt in wanted*4:
			if accepted>=wanted:break
			var angle:=rng.randf()*TAU
			var r:=pow(rng.randf(),.62)
			var point:=Vector2(cx+cos(angle)*cross_extent*r,z+sin(angle)*along_extent*r)
			if point.y>zone.start+4 or point.y<zone.end-4:continue
			var slope:=Vector2(terrain.height_at(point.x+2,point.y)-terrain.height_at(point.x-2,point.y),terrain.height_at(point.x,point.y+2)-terrain.height_at(point.x,point.y-2)).length()/4.0
			# Trees colonise sheltered flatter ground; the exposed slipface stays bare.
			if id>=2 and slope>.65:continue
			if id==2 and absf(point.x+51.0+12.0*sin((point.y+245.0)*.040))<11.0:continue
			if id==3 and point.x>65.0 and point.y<-465.0 and point.y>-557.0:continue
			var spaced:=true
			for other in placed:
				if point.distance_squared_to(other)<(36.0 if id==1 else 42.25):spaced=false;break
			if not spaced:continue
			var families:Array=[ ["frost_blade","frost_shelf","frost_rack"], ["rift_terrace","basalt_broken","basalt_column","vent_stack"], ["riparian_arch","riparian_tree","riparian_snag","root_hummock"], ["pale_nurse","pale_copse","pale_stump","pale_branch"] ][id]
			var family:String=families[attempt%families.size()]
			if id==1 and r>.7:family="rift_terrace" # cooled edges spread laterally
			if id==3 and r>.74:family="pale_stump" # stripped outer decay edge
			var size:=rng.randf_range(.68,1.18)*(1.16 if r<.45 else .82)
			var yaw:=rng.randf_range(-.35,.35)+(.30 if id==0 else -.25 if id==1 else angle)
			if not _grove_place(transforms,family,point,size,yaw):continue
			placed.append(point);accepted+=1
			if accepted%3==0:clusters.append(Vector3(point.x,1.1,point.y))
			var understory:String=["frost_fan","ember_bract","understory_bush","spore_shelf"][id]
			for j in (5 if family=="pale_nurse" else 2):
				var a:=rng.randf()*TAU
				var child:=point+Vector2(cos(a),sin(a))*rng.randf_range(1.8,4.2)+Vector2(1.8,1.0)
				_grove_place(transforms,understory,child,rng.randf_range(.65,1.35),a)
			if id in [2,3] and accepted%9==0:
				_grove_place(transforms,"fallen_root",point+Vector2(side*4.5,5),.52,rng.randf()*TAU)
		# Sparse larger broken masses connect the colony to the actual landform.
		for i in 6:
			var point:=Vector2(cx+side*rng.randf_range(26,48),z+rng.randf_range(-along_extent,along_extent))
			var family:String=["frost_blade","basalt_broken","riparian_arch","pale_nurse"][id]
			if _grove_place(transforms,family,point,rng.randf_range(1.25,1.85),rng.randf_range(-.4,.4)):placed.append(point)
	# Preserve authored blue-membrane identities as occasional high landmarks.
	if id==2:
		for z:float in [-196.0,-233.0,-267.0,-286.0]:
			var point:=Vector2(terrain.path_x(z)-31.0,z)
			_grove_place(transforms,"canopy",point,.59,z*.013)
	# Low edge growth only opposite a colony, preserving the open intervals.
	for i in 48:
		var z:float=rng.randf_range(zone.end,zone.start)
		var side:float=-1.0 if i%3 else 1.0
		var point:=Vector2(terrain.path_x(z)+side*rng.randf_range(8.5,17.0),z)
		var near_colony:=false
		for grove:Vector4 in REGIONAL_GROVES[id]:
			if signf(grove.x)==side and absf(z-grove.y)<grove.w*.68:near_colony=true;break
		if not near_colony:continue
		var family:String=["frost_fan","ember_bract","understory_bush","spore_shelf"][id]
		_grove_place(transforms,family,point,rng.randf_range(.55,1.0),rng.randf()*TAU)
	_add_sightline_habitat(id,transforms)
	for family in transforms:
		await terrain.boot_yield()
		_spatial_batches(family,transforms[family])
		if not transforms[family].is_empty():_formations.append({"zone":id,"family":family,"count":transforms[family].size()})
	_ground_growth(zone,clusters)
	terrain.build_stats["mass_region_"+str(id)+"_structures"]=placed.size()

func _build_exposed_strata(id: int) -> void:
	# Attached bedrock replaces the blank slipfaces, without changing driving heights.
	# x/z, cross-slope half-width, along-slope half-width; gaps retain the investigations.
	var faces: Array = [
		[Vector4(-47,146,13,14),Vector4(-54,119,15,13),Vector4(-66,88,15,11),Vector4(-69,20,13,12),Vector4(52,136,14,14),Vector4(57,109,16,13),Vector4(51,82,12,10),Vector4(62,50,13,12)],
		[Vector4(-43,-35,10,13),Vector4(-50,-63,10,12),Vector4(-53,-89,12,13),Vector4(-54,-112,11,10),Vector4(58,-42,11,13),Vector4(53,-69,12,12),Vector4(43,-98,9,11)],
		[Vector4(46,-250,8,10),Vector4(43,-275,9,12),Vector4(58,-311,10,10),Vector4(-81,-240,9,12)],
		[Vector4(57,-495,9,8),Vector4(72,-505,13,11),Vector4(88,-493,9,8),Vector4(69,-525,12,10),Vector4(63,-567,13,12),Vector4(56,-591,11,10),Vector4(-43,-453,12,10),Vector4(-60,-493,12,12),Vector4(-64,-520,12,11),Vector4(-50,-566,11,12)]
	][id]
	# Fitted fragments on the visible bank, outside the investigation corridor.
	# The earlier large circular footprints rejected these faces wholesale.
	if id==2: faces.append_array([Vector4(25,-289,4.5,7),Vector4(36,-293,5,7),Vector4(42,-274,5,8),Vector4(30,-260,4.5,6)])
	if id==3: faces.append_array([Vector4(53,-482,4.5,7),Vector4(60,-487,5,7),Vector4(64,-477,5,8),Vector4(70,-486,4.5,6),Vector4(55,-467,4,6)])
	var color: Color=[Color("829895"),Color("766451"),Color("606656"),Color("928887")][id]
	var st:=_surface()
	var count:=0
	for index in faces.size():
		var face:Vector4=faces[index]
		var side:=signf(face.x-terrain.path_x(face.y))
		# The full stepped envelope, including the tilted top, is clearance tested.
		var radius:=Vector2(face.z*1.2+2.0,face.w*1.18).length()
		if not _clear(face.x,face.y,radius) or not _approach_clear(Vector2(face.x,face.y),radius):continue
		var near_x:=face.x-side*face.z*.83
		var far_x:=face.x+side*face.z*.55
		var foot:float=terrain.height_at(near_x,face.y)-1.1
		for dx in [-1.18,-.59,0.0,.59,1.18]:
			for dz in [-1.18,-.59,0.0,.59,1.18]:
				foot=minf(foot,terrain.height_at(face.x+dx*face.z,face.y+dz*face.w)-1.1)
		var crest:float=maxf(terrain.height_at(far_x,face.y),terrain.height_at(face.x,face.y))
		var rise:=maxf(3.6,crest-foot)+(1.5 if id==2 else 3.2)
		# Unequal ledges recede into the bank. Broad tops are quiet; joints and broken
		# ends carry the structure instead of a uniformly banded surface shader.
		for layer in 3:
			var fraction:float=[0.0,.39,.73][layer]
			var thickness:float=[.52,.43,.34][layer]*rise
			var base:=Vector3(face.x+side*layer*1.1,foot+fraction*rise,face.y+float((index+layer)%3-1)*1.1)
			var size:=Vector3(face.z*(1.0-layer*.13),thickness,face.w*(1.0-layer*.07))
			_broken_slab(st,base,size,side*.10,color.darkened(.13 if layer==0 else .0),index*3+layer)
		# Fallen slabs meet the exposed foot; the same exact mesh supplies collision.
		for chip in 3:
			var p:=Vector2(near_x+side*(1.2+chip*.8),face.y+(chip-1)*face.w*.59)
			_broken_slab(st,Vector3(p.x,terrain.height_at(p.x,p.y)-.45,p.y),Vector3(2.0+chip*.35,1.0+chip*.31,2.6),.24+chip*.43,color.darkened(.12),index+chip)
		count+=1
		await terrain.boot_yield()
	if count==0:return
	st.index();st.generate_normals()
	var mesh:=st.commit()
	var node:=MeshInstance3D.new()
	node.name="ExposedRegionalStrata_"+str(id)
	node.mesh=mesh
	node.material_override=source_meshes.frost_shelf[0].material if id==0 else source_meshes.rift_terrace[0].material
	node.visibility_range_end=340.0
	add_child(node)
	var shape:=mesh.create_trimesh_shape()
	shape.backface_collision=true
	var body:=StaticBody3D.new()
	body.name=node.name+"_Collision"
	body.collision_layer=1|128
	add_child(body)
	var owner:=body.create_shape_owner(self)
	body.shape_owner_add_shape(owner,shape)
	exposed_geology.append({"zone":id,"mesh":mesh,"body":body,"shape":shape,"sections":count})
	terrain.build_stats["exposed_strata_"+str(id)+"_sections"]=count
	terrain.build_stats["exposed_strata_"+str(id)+"_triangles"]=mesh.get_faces().size()/3

func _approach_clear(point: Vector2,radius: float) -> bool:
	if terrain.environment_access_distance(point.x,point.y)<7.0+radius:return false
	# Match the open cross-slope approaches preserved by world._landform_mask.
	for id in ["aurora_echo","ember_vent","marsh_crossing","spore_pulse"]:
		var anchor:Vector2=SURVEYS.point(id)
		var road:float=terrain.path_x(anchor.y)
		if absf(point.y-anchor.y)<5.0+radius and point.x>minf(road,anchor.x)-6.0-radius and point.x<maxf(road,anchor.x)+6.0+radius:return false
	return true

func _add_sightline_habitat(id: int,transforms: Dictionary) -> void:
	# Deliberate foreground / middle / skyline groups along the actual side and return
	# views. No RNG: the established shore population and its open landing stay exact.
	var groups: Array = [
		[["frost_blade",Vector2(39,119),.9,-.25],["frost_rack",Vector2(66,137),1.35,.1],["frost_shelf",Vector2(38,101),.95,-.15],["frost_blade",Vector2(-33,141),1.15,.3],["frost_shelf",Vector2(-40,76),1.2,.1]],
		[["basalt_broken",Vector2(-35,-105),1.25,.12],["rift_terrace",Vector2(-36,-87),1.25,-.2],["basalt_broken",Vector2(32,-88),.9,-.2],["rift_terrace",Vector2(50,-111),1.3,.2]],
		[["root_bank",Vector2(42,-264),.8,.2],["riparian_arch",Vector2(38,-258),1.2,.3],["riparian_tree",Vector2(51,-272),1.38,.5],["riparian_tree",Vector2(34,-284),1.05,-.3],["riparian_snag",Vector2(28,-262),.88,.2],["riparian_arch",Vector2(66,-285),1.3,1.0],["canopy",Vector2(51,-294),.43,-.5],["riparian_tree",Vector2(64,-248),1.1,.8],["riparian_tree",Vector2(48,-313),1.0,.9],["fallen_root",Vector2(39,-292),.86,.3],["root_hummock",Vector2(28,-279),1.1,.2],["riparian_arch",Vector2(-49,-251),1.1,-.4],["riparian_tree",Vector2(-71,-277),1.2,.7]],
		[["pale_nurse",Vector2(48,-489),1.18,1.3],["pale_stump",Vector2(43,-482),1.15,.3],["pale_branch",Vector2(65,-495),1.2,-.4],["pale_nurse",Vector2(52,-512),1.4,1.2],["pale_copse",Vector2(76,-513),1.35,.2],["pale_branch",Vector2(83,-485),1.1,.8],["pale_nurse",Vector2(-15,-512),1.4,.35],["pale_stump",Vector2(-23,-501),1.2,.7],["pale_branch",Vector2(-33,-529),1.35,-.4],["pale_nurse",Vector2(-30,-551),1.2,-.25],["pale_nurse",Vector2(45,-569),1.2,.5],["pale_stump",Vector2(37,-577),1.0,.3],["pale_nurse",Vector2(-32,-417),1.2,.4],["pale_copse",Vector2(-39,-443),1.2,.6]]
	][id]
	var accepted:=0
	if id==2:
		groups.append_array([["riparian_tree",Vector2(9,-268),1.1,.35],["riparian_arch",Vector2(20,-282),1.05,2.4],["root_hummock",Vector2(14,-302),1.0,.2]])
	for group:Array in groups:
		var family:String=group[0]
		var p:Vector2=group[1]
		var pose:=_placement(p.x,p.y,group[2],group[3])
		if not _approach_clear(p,_footprint(family,pose.basis)):continue
		if not _grove_place(transforms,family,p,group[2],group[3]):continue
		accepted+=1
		var under:String=["frost_fan","ember_bract","understory_bush","spore_shelf"][id]
		for i in 4:
			var a:=i*2.39+float(accepted)
			var offset:=Vector2(cos(a)*3.5,sin(a)*2.1)
			_grove_place(transforms,under,p+offset,.65+float(i%3)*.2,a)
	terrain.build_stats["sightline_habitat_"+str(id)+"_structures"]=accepted

func _load_family(family: String) -> void:
	var path := "res://assets/visual_flora/"+family+"_lod1.glb"
	if not ResourceLoader.exists(path): return
	var packed := load(path) as PackedScene
	if packed==null: return
	var instance := packed.instantiate()
	var groups: Dictionary = {}
	_collect(instance,Transform3D.IDENTITY,groups)
	var entries: Array = []
	for key in groups:
		var data: Dictionary = groups[key]
		var original := data.material as StandardMaterial3D
		var material := original
		if material!=null:
			material = material.duplicate()
			material.metallic = 0
			# Keep baked roughness maps at full range. Multiplying every map by .78
			# made dry bark and membrane highlights converge.
			var name_lower := original.resource_name.to_lower()
			var tissue := "tissue" in name_lower or "inner" in name_lower or "gills" in name_lower
			material.roughness = 1.0 if material.roughness_texture!=null else original.roughness
			material.albedo_color = material.albedo_color.darkened(.07 if tissue else .13)
			material.vertex_color_use_as_albedo = true
			material.normal_scale = minf(material.normal_scale,.24 if tissue else .48)
			material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
			material.metallic_specular = .42 if tissue else .25
			if material.emission_enabled: material.emission_energy_multiplier = minf(.25,material.emission_energy_multiplier)
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		entries.append({"mesh":data.surface.commit(),"material":material,"original":original})
	source_meshes[family] = entries
	instance.free()

func _collect(node: Node,transform: Transform3D,groups: Dictionary) -> void:
	var t := transform
	if node is Node3D: t = transform*node.transform
	if node is MeshInstance3D:
		for index in node.mesh.get_surface_count():
			var mat: Material = node.get_active_material(index)
			var key := str(mat.get_instance_id()) if mat!=null else "none"
			if not groups.has(key):
				var surface := SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"surface":surface,"material":mat}
			groups[key].surface.append_from(node.mesh,index,t)
	for child in node.get_children(): _collect(child,t,groups)

func _spatial_batches(family: String,transforms: Array) -> void:
	if transforms.is_empty() or not source_meshes.has(family): return
	# Filter after generation so removing route obstructions cannot perturb the
	# seeded shore population. Keep every reachable solid out of the access floor.
	if family in SOLID_FAMILIES:
		transforms.assign(transforms.filter(func(t:Transform3D)->bool:return terrain.environment_access_distance(t.origin.x,t.origin.z)>=7.0+_footprint(family,t.basis)))
	if transforms.is_empty():return
	var chunks: Dictionary = {}
	for raw: Transform3D in transforms:
		var t := _seat_transform(family,raw)
		if family=="shore_pebble":t.origin.y-=.025+.055*absf(sin(t.origin.x*.7+t.origin.z*.3))
		if family in SOLID_FAMILIES:
			_add_habitat_collision(family,t)
		var key := Vector2i(floori(t.origin.x/70.0),floori(t.origin.z/90.0))
		if not chunks.has(key): chunks[key] = []
		chunks[key].append(t)
	for key in chunks:
		var center:=Vector2.ZERO
		for pose:Transform3D in chunks[key]:center+=Vector2(pose.origin.x,pose.origin.z)
		center/=float(chunks[key].size())
		var extent:=0.0
		for pose:Transform3D in chunks[key]:extent=maxf(extent,center.distance_to(Vector2(pose.origin.x,pose.origin.z)))
		for part: Dictionary in source_meshes[family]:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part.mesh
			mm.use_colors=true
			mm.instance_count = chunks[key].size()
			for i in chunks[key].size():
				var pose:Transform3D=chunks[key][i]
				mm.set_instance_transform(i,pose)
				var tone:=.87+.13*(.5+.5*sin(pose.origin.x*.73+pose.origin.z*.31))
				mm.set_instance_color(i,Color(tone,tone*.99,tone*.95,1.0))
			var node := MultiMeshInstance3D.new()
			node.multimesh = mm
			node.material_override = part.material
			node.name = family+"_habitat_"+str(key)
			var landmark := family in SOLID_FAMILIES
			node.visibility_range_end = 320.0 if landmark else 130.0
			node.visibility_range_end_margin = 18.0
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if landmark else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)
			if part.get("original") != null:
				_material_pairs.append({"node":node,"authored":part.material,"original":part.original})
			batches.append({"node":node,"count":mm.instance_count,"range":node.visibility_range_end,"family":family,"landmark":landmark,"shadow_center":center,"shadow_radius":extent,"shadow_on":landmark})

func _surface() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

func _triangle(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
	for p in [a,b,c]:
		st.set_color(color.srgb_to_linear().lerp(color,.42))
		st.set_uv(Vector2(p.x+p.z*.25,p.y)*.2)
		st.add_vertex(p)

func _kit_material(color: Color,roughness: float,stone: bool=false) -> Material:
	# Geometry/vertex colour carry regional variety. Share coarse dry/damp response
	# classes so each added shape does not create another first-draw warmup material.
	roughness=snappedf(roughness,.1)
	var key:=str(roughness)+":"+str(stone)
	if _kit_materials.has(key):return _kit_materials[key]
	var material := terrain._strata_material.duplicate() as ShaderMaterial
	material.set_shader_parameter("surface_tint",Color.WHITE)
	material.set_shader_parameter("surface_roughness",roughness)
	material.set_shader_parameter("use_vertex_color",true)
	material.set_shader_parameter("organic_surface",not stone)
	_kit_materials[key]=material
	return material

func _register_kit(family: String,st: SurfaceTool,material: Material) -> void:
	st.index()
	st.generate_normals()
	st.generate_tangents()
	var mesh := st.commit()
	if family not in ["frost_shelf","frost_rack","frost_blade","rift_terrace","basalt_column","basalt_broken"]:mesh=_smooth_organic_normals(mesh)
	source_meshes[family] = [{"mesh":mesh,"material":material}]

func _smooth_organic_normals(mesh: ArrayMesh) -> ArrayMesh:
	# Material colour seams must not split the normal field into visible triangle strips.
	var arrays:=mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var sums: Dictionary={}
	var keys: Array[Vector3i]=[]
	for i in vertices.size():
		var p:=vertices[i]*10000.0
		var key:=Vector3i(roundi(p.x),roundi(p.y),roundi(p.z))
		keys.append(key)
		sums[key]=sums.get(key,Vector3.ZERO)+normals[i]
	for i in normals.size():normals[i]=sums[keys[i]].normalized()
	arrays[Mesh.ARRAY_NORMAL]=normals
	# Tangents are unused by the triplanar material and would no longer match the smoothed normals.
	arrays[Mesh.ARRAY_TANGENT]=null
	var result:=ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result

func _build_native_kit() -> void:
	# Broken frost escarpments: intersecting thick volumes, never repeated plates.
	var st := _surface()
	_shelf(st,Vector3(-1.1,.95,.3),Vector3(3.3,2.6,2.9),-.2,Color("869b9e"),2)
	_shelf(st,Vector3(2.1,.42,-.2),Vector3(3.0,1.7,2.6),.36,Color("9caaa9"),5)
	_shelf(st,Vector3(-1.0,2.15,.5),Vector3(2.4,.65,2.0),-.12,Color("b0c2be"),4)
	for i in 5:
		var a := i*2.4
		_shelf(st,Vector3(cos(a)*3.8,-.06,sin(a)*2.7),Vector3(1.5,.45,.95),a,Color("8b9d9b"),i+7)
	_register_kit("frost_shelf",st,_kit_material(Color("b6cecd"),.83,true))
	# Wind-cut escarpment: buttressed, broken strata. No elevated horizontal
	# plates on matching legs; the silhouette must read as geology from behind.
	st = _surface()
	_shelf(st,Vector3(-1.5,1.3,.15),Vector3(3.4,4.3,2.4),-.17,Color("6e8489"),5)
	_shelf(st,Vector3(.9,2.55,-.35),Vector3(2.0,4.6,1.65),.26,Color("83999a"),9)
	_shelf(st,Vector3(-1.1,4.5,.2),Vector3(2.85,1.3,2.0),-.19,Color("a6b8b4"),8)
	_shelf(st,Vector3(2.9,.4,.65),Vector3(2.45,1.8,2.1),.45,Color("819796"),13)
	_shelf(st,Vector3(-3.5,-.03,1.4),Vector3(2.2,.8,1.55),-.48,Color("718582"),2)
	_register_kit("frost_rack",st,_kit_material(Color("b6cecd"),.83,true))
	# Fused fumaroles have shoulders and asymmetric necks with a mineral lip.
	st = _surface()
	for i in 3:
		var base := Vector3(sin(i*2.2)*1.4,-.3,cos(i*2.2)*1.0)
		var h := 3.5+i*.95
		_tapered_tube(st,[base,base+Vector3(.1,.75,0),base+Vector3(-.32,h*.48,.1),base+Vector3(.1,h*.82,.35),base+Vector3(.25,h,.25)],[1.35,1.08,.82,.47,.40],Color("756353"),13,.11)
		_fan(st,base+Vector3(.25,h-.12,.25),.57,.10,.1,Color("a58b63"),2.0)
		_shelf(st,base+Vector3(.2,.12,0),Vector3(2.5,.7,2.0),i*.8,Color("71574a"),i+3)
	_register_kit("vent_stack",st,_kit_material(Color("b29885"),.92,true))
	# Lateral, broken benches mark the rift rather than repeating vertical vents.
	st = _surface()
	_shelf(st,Vector3(-2.8,.5,.1),Vector3(7.0,1.55,4.1),-.12,Color("786252"),3)
	_shelf(st,Vector3(2.4,1.5,-.9),Vector3(4.6,.95,3.2),.25,Color("9d8064"),9)
	_shelf(st,Vector3(4.0,.05,2.4),Vector3(3.2,.65,2.1),.38,Color("654c41"),13)
	_register_kit("rift_terrace",st,_kit_material(Color("ae937e"),.89,true))
	# Braided hummocks with open inter-root spaces and damp lamellae.
	st = _surface()
	for branch in 8:
		var a := branch/8.0*TAU
		var tip := Vector3(cos(a)*3.3,-.30,sin(a)*3.3)
		_tapered_tube(st,[Vector3(0,1.25,0),Vector3(cos(a)*.85,.95,sin(a)*.85),tip*.77+Vector3.UP*.35,tip],[.63,.45,.23,.04],Color("526d5b"),10,.065)
	_shelf(st,Vector3(0,.56,0),Vector3(2.0,1.4,1.7),.3,Color("5d7662"),3)
	for i in 5:
		_fan(st,Vector3(sin(i*2.4)*.8,.8+i*.19,cos(i*2.4)*.8),1.2,.22,i*2.4,Color("69847a"),1.1)
	_register_kit("root_hummock",st,_kit_material(Color("bdcaba"),.68))
	# Pale is a mineralised fungal woodland, with pigmented crowns and branching ribs.
	st = _surface()
	_tapered_tube(st,[Vector3(0,-.4,0),Vector3(.22,1.4,.15),Vector3(-.26,3.4,0),Vector3(.12,5.35,.28)],[1.0,.68,.47,.16],Color("8c8277"),13,.10)
	for branch in 7:
		var a := branch*2.39
		var h := 1.55+branch*.52
		var origin := Vector3(0,h,0)
		var end := Vector3(cos(a)*(2.1+branch*.14),h+.95,sin(a)*(2.1+branch*.14))
		_tapered_tube(st,[origin,origin.lerp(end,.6)+Vector3.DOWN*.23,end,end+Vector3(cos(a)*.25,.65,sin(a)*.25)],[.36,.27,.17,.065],Color("a29a8a"),10,.085)
		for crown in 3:
			var p := end+Vector3(cos(a)*.16,crown*.26,sin(a)*.16)
			_fan(st,p,1.2-crown*.19,.20,a+PI,Color("998997").darkened(crown*.045),1.8)
		if branch%2==0:
			var fork := end+Vector3(cos(a+.6)*.8,.9,sin(a+.6)*.8)
			_tapered_tube(st,[end-Vector3.UP*.3,fork],[.15,.035],Color("afa391"),8,.06)
	for index in 6:
		var a := index*TAU/6.0
		_tapered_tube(st,[Vector3(0,.65,0),Vector3(cos(a)*1.55,.12,sin(a)*1.55),Vector3(cos(a)*2.65,-.42,sin(a)*2.65)],[.40,.22,.055],Color("726b62"),10,.09)
	_register_kit("pale_branch",st,_kit_material(Color("d6c9bb"),.88))
	for id in 4:
		st = _surface()
		for blade in (9 if id==2 else 7):
			var a := blade*2.39
			var h := .45+float(blade%4)*.19
			var palette: Color = [Color("7d9999"),Color("8c644b"),Color("457868"),Color("897382")][id]
			if id==3 or id==0:
				var p := Vector3(cos(a)*.35,.1+blade*.12,sin(a)*.35)
				_fan(st,p,.44+blade*.055,.12,a,palette,1.5)
				_tapered_tube(st,[Vector3(p.x,-.15,p.z),p],[.075,.055],palette.darkened(.2),7,0)
			else: _leaf(st,Vector3(cos(a)*.17,-.1,sin(a)*.17),h,.08 if id==2 else .24,a,palette)
		var family: String = ["frost_fan","ember_bract","reed_fan","spore_shelf"][id]
		_register_kit(family,st,_kit_material(Color.WHITE,.53 if id==2 else .76))

func _build_riparian_kits() -> void:
	var bark: Material = _kit_material(Color.WHITE,.90).duplicate()
	(bark as ShaderMaterial).set_shader_parameter("surface_tint",Color(.64,.58,.47))
	for part: Dictionary in source_meshes.get("canopy",[]):
		var original: Material=part.get("original")
		if original is StandardMaterial3D and "bark_ridge" in original.resource_name:
			var wood:=original.duplicate() as StandardMaterial3D
			wood.uv1_triplanar=true
			wood.uv1_scale=Vector3.ONE*.55
			wood.normal_scale=.38
			wood.roughness=1.0
			wood.albedo_color=Color("8c7861")
			wood.emission_enabled=false
			wood.vertex_color_use_as_albedo=false
			bark=wood
			break
	var foliage:=StandardMaterial3D.new()
	foliage.vertex_color_use_as_albedo=true
	foliage.albedo_color=Color(.82,.89,.76)
	foliage.roughness=.86
	foliage.metallic_specular=.22
	foliage.cull_mode=BaseMaterial3D.CULL_DISABLED
	for variant in 2:
		var trunk:=_surface()
		var leaves:=_surface()
		var top:=9.6 if variant==0 else 6.8
		_tapered_tube(trunk,[Vector3(0,-.5,0),Vector3(.2,2.2,.1),Vector3(-.45,5,.6),Vector3(.8,top,1.1)],[.85,.62,.43,.08],Color("756b51"),11,.07)
		for branch in (7 if variant==0 else 5):
			var a:=branch*2.39+variant*.8
			var h:=2.4+branch*.8
			var origin:=Vector3(0,h,.2)
			var tip:=origin+Vector3(cos(a)*(2.5+float(branch%3)*.7),1.3+float(branch%2)*.5,sin(a)*(2.5+float(branch%3)*.7))
			_tapered_tube(trunk,[origin,origin.lerp(tip,.55)+Vector3.DOWN*.15,tip],[.23,.15,.035],Color("817459"),8,.05)
			if variant==1 and branch%2==0:continue
			for leaf in 30:
				var phase:=leaf*2.39+a
				var radius:=.2+sqrt(float(leaf%11+1)/11.0)*1.15
				var base:=tip+Vector3(cos(phase)*radius,sin(float(leaf)*1.3)*.3,sin(phase)*radius)
				var direction:=Vector3(cos(phase),.1+float(leaf%3)*.08,sin(phase)).normalized()
				_crown_leaf(leaves,base,direction,.9+float(leaf%4)*.16,.24+float(leaf%3)*.06,Color("596845").darkened(float(leaf%4)*.04))
		for rib in 6:
			var a:=rib*2.39
			_tapered_tube(trunk,[Vector3(0,1.2,0),Vector3(cos(a)*1.8,.35,sin(a)*1.8),Vector3(cos(a)*3.7,-.45,sin(a)*3.7)],[.40,.24,.03],Color("625b43"),9,.065)
		var family:="riparian_tree" if variant==0 else "riparian_snag"
		_register_kit(family,trunk,bark)
		leaves.index();leaves.generate_normals()
		source_meshes[family].append({"mesh":leaves.commit(),"material":foliage,"collision":false})
	var st:=_surface()
	_tapered_tube(st,[Vector3(-7,-.3,0),Vector3(-3,.6,.3),Vector3(2,1.1,-.2),Vector3(8,-.35,.8)],[.45,1.0,.77,.08],Color("746345"),12,.09)
	for i in 5:
		var a:=Vector3(-4+i*2, .7,0)
		_tapered_tube(st,[a,a+Vector3(.5,.2,1.4),a+Vector3(1.7,-.85,2.9)],[.31,.19,.025],Color("665c45"),8,.07)
	_register_kit("fallen_root",st,bark)
	st=_surface()
	_shelf(st,Vector3(-1.5,.8,.4),Vector3(5.4,2.3,3.8),-.12,Color("796d54"),7)
	_shelf(st,Vector3(2.7,1.05,-.2),Vector3(4.0,1.7,3.2),.22,Color("897c62"),13)
	_shelf(st,Vector3(4.9,.06,1.6),Vector3(3.0,.9,2.0),.32,Color("5f5b4d"),4)
	_register_kit("marsh_bank_rock",st,_kit_material(Color.WHITE,.87,true))
	st=_surface()
	_shelf(st,Vector3(0,.12,0),Vector3(.72,.48,.55),.28,Color("4e5549"),3)
	_register_kit("shore_pebble",st,_kit_material(Color.WHITE,.90,true))

	# One medium-scale root bank supports the principal sail and encloses its
	# sheltered shore. Both soil shoulder and roots have the same solid mesh.
	st=_surface()
	_shelf(st,Vector3(-2,.28,-1),Vector3(8.3,2.1,4.4),-.12,Color("57533f"),17)
	_shelf(st,Vector3(5,-.05,1.5),Vector3(6.0,1.15,3.7),.22,Color("484c3b"),9)
	_register_kit("root_bank",st,_kit_material(Color.WHITE,.94,true))
	st=_surface()
	_tapered_tube(st,[Vector3(0,.2,-6),Vector3(-1.4,2.3,-2),Vector3(3.5,1.9,3),Vector3(11,-.55,8)],[1.35,1.10,.73,.12],Color("665a41"),12,.075)
	_tapered_tube(st,[Vector3(-1,1.2,-4),Vector3(-6.5,1.6,-.5),Vector3(-11,-.6,5)],[.84,.59,.09],Color("5c543e"),10,.055)
	_tapered_tube(st,[Vector3(2,1.4,-3),Vector3(7,1.0,-.3),Vector3(12,-.5,4)],[.75,.47,.08],Color("706047"),10,.06)
	st.index();st.generate_normals();st.generate_tangents()
	source_meshes.root_bank.append({"mesh":_smooth_organic_normals(st.commit()),"material":bark,"collision":true})

func _build_mass_templates() -> void:
	var st:=_surface()
	# Fused cooling prisms have broken flat crowns, not a taper to a cone tip.
	_broken_slab(st,Vector3(-.8,-.4,0),Vector3(1.2,6.4,1.6),.08,Color("756450"),2)
	_broken_slab(st,Vector3(1.0,-.35,.6),Vector3(.95,4.0,1.3),-.16,Color("87735a"),5)
	_broken_slab(st,Vector3(-1.6,-.3,1.4),Vector3(1.6,1.2,1.4),.4,Color("635542"),9)
	_register_kit("basalt_column",st,_kit_material(Color.WHITE,.91,true))
	st=_surface()
	_tapered_tube(st,[Vector3(0,-.35,0),Vector3(.28,2,.1),Vector3(-.24,4.4,.35),Vector3(.5,6.6,.1)],[.62,.42,.29,.04],Color("8d8273"),9,.07)
	for branch in 4:
		var a:=branch*2.39
		var origin:=Vector3(0,2.0+branch*.9,0)
		var tip:=origin+Vector3(cos(a)*2.1,.55,sin(a)*2.1)
		_tapered_tube(st,[origin,origin.lerp(tip,.6),tip],[.21,.14,.03],Color("958776"),7,.045)
		_fan(st,tip,1.4,.18,a,Color("857386"),1.65)
		if branch%2==0:_fan(st,tip+Vector3.UP*.25,1.05,.16,a+.2,Color("948193"),1.65)
	for i in 4:
		var a:=i*2.39
		_tapered_tube(st,[Vector3(0,.4,0),Vector3(cos(a)*1.6,-.25,sin(a)*1.6)],[.23,.035],Color("6d6559"),7,.045)
	_register_kit("pale_copse",st,_kit_material(Color.WHITE,.86))
	st=_surface()
	for i in 38:
		var a:=i*2.39
		var origin:=Vector3(cos(a)*(.25+float(i%4)*.16),.25+float(i%5)*.24,sin(a)*(.25+float(i%4)*.16))
		_crown_leaf(st,origin,Vector3(cos(a),.28,sin(a)).normalized(),.75+float(i%3)*.16,.27,Color("566b46").darkened(float(i%4)*.03))
	_register_kit("understory_bush",st,source_meshes.riparian_tree[1].material)

func _build_region_variants() -> void:
	var st:=_surface()
	# Wind peels a tilted face from the shelf; the fallen foot shares its bedding.
	_broken_slab(st,Vector3(-2.4,-.45,0),Vector3(5.7,5.8,2.7),-.22,Color("849b9e"),3)
	_broken_slab(st,Vector3(3.2,-.4,1.2),Vector3(3.8,2.1,4.1),.34,Color("9fb3af"),8)
	_broken_slab(st,Vector3(-4.1,-.45,3.5),Vector3(3.2,.9,2.1),-.1,Color("718985"),7)
	_register_kit("frost_blade",st,source_meshes.frost_shelf[0].material)
	st=_surface()
	# A broken rib keeps its wide fault root and loses one side of the crown.
	_broken_slab(st,Vector3(-1.5,-.4,0),Vector3(2.8,8.3,2.1),.10,Color("6d5e4f"),5)
	_broken_slab(st,Vector3(2.1,-.4,.8),Vector3(3.0,3.9,2.4),-.18,Color("897158"),2)
	_broken_slab(st,Vector3(4,-.4,2.0),Vector3(3.6,1.1,2.0),.34,Color("594d43"),6)
	_register_kit("basalt_broken",st,source_meshes.basalt_column[0].material)
	# Nurse log, stripped stump, and living copse differ in growth architecture.
	st=_surface()
	_tapered_tube(st,[Vector3(-6,-.35,.2),Vector3(-2.9,.7,-.5),Vector3(.6,1.8,0),Vector3(4.8,.1,1.2),Vector3(7,-.5,1.5)],[.25,.85,1.1,.60,.12],Color("736b64"),10,.09)
	for i in 5:
		var root:=Vector3(-3.8+i*1.65,.4+sin(i*.75)*.65,.2)
		_tapered_tube(st,[root,root+Vector3(.3,.5,1.5),root+Vector3(.9,-1.15,2.8)],[.30,.20,.03],Color("625f56"),8,.055)
		if i==2:continue
		_fan(st,root+Vector3(0,.55,0),1.3+float(i%2)*.6,.27,i*1.7,Color("8e7984"),1.2+float(i%2)*.3)
	_register_kit("pale_nurse",st,source_meshes.pale_copse[0].material)
	st=_surface()
	for rib in 3:
		var a:=rib*2.2
		var base:=Vector3(cos(a)*.65,-.4,sin(a)*.65)
		_tapered_tube(st,[base,Vector3(cos(a)*.75,1.6,sin(a)*.7),Vector3(cos(a)*.45,3.1+rib*.5,sin(a)*.45)],[.55,.34,.055],Color("9b9585"),8,.05)
		_tapered_tube(st,[base+Vector3.UP*.6,base+Vector3(cos(a)*1.2,.05,sin(a)*1.2),base+Vector3(cos(a)*2,-.3,sin(a)*2)],[.3,.18,.025],Color("777565"),8,.035)
	_fan(st,Vector3(.75,.5,.25),1.15,.22,.8,Color("80717f"),1.25)
	_register_kit("pale_stump",st,source_meshes.pale_copse[0].material)
	# Swept double trunk with an open inner fork and an asymmetric high crown.
	var trunk:=_surface()
	var leaves:=_surface()
	for side:float in [-1.0,1.0]:
		_tapered_tube(trunk,[Vector3(side*2.7,-.45,0),Vector3(side*1.4,2.8,.5),Vector3(side*.8,5.7,.6),Vector3(1.6+side*.5,8.5,1.5)],[.72,.57,.35,.08],Color("6f7051"),10,.05)
		for rib in 3:
			var a:=rib*2.2+side
			var root:=Vector3(side*2.7,.8,0)
			_tapered_tube(trunk,[root,root+Vector3(cos(a)*1.4,-.55,sin(a)*1.4),root+Vector3(cos(a)*2.8,-1.25,sin(a)*2.8)],[.3,.18,.025],Color("586348"),8,.035)
	for branch in 4:
		var a:=branch*2.39+.5
		var root:=Vector3(.4,4.5+branch*.85,.5)
		var tip:=root+Vector3(cos(a)*3.6,1.0,sin(a)*3.6)
		_tapered_tube(trunk,[root,root.lerp(tip,.55)+Vector3.UP*.3,tip],[.25,.16,.025],Color("7c7956"),8,.05)
		for leaf in 22:
			var phase:=leaf*2.39+a
			var p:=tip+Vector3(cos(phase),sin(leaf*.9)*.5,sin(phase))*(.3+float(leaf%5)*.23)
			_crown_leaf(leaves,p,Vector3(cos(phase),.2,sin(phase)).normalized(),.85+float(leaf%3)*.23,.19,Color("657b55").darkened(float(leaf%4)*.035))
	_register_kit("riparian_arch",trunk,source_meshes.riparian_tree[0].material)
	leaves.index();leaves.generate_normals()
	source_meshes.riparian_arch.append({"mesh":leaves.commit(),"material":source_meshes.riparian_tree[1].material,"collision":false})

func _broken_slab(st: SurfaceTool,base: Vector3,size: Vector3,yaw: float,color: Color,salt: int) -> void:
	var outline: Array[Vector2]=[Vector2(-1,-.6),Vector2(-.25,-1),Vector2(.82,-.78),Vector2(1,.3),Vector2(.35,1),Vector2(-.87,.72)]
	var bottom: Array[Vector3]=[]
	var top: Array[Vector3]=[]
	for i in outline.size():
		var p:=outline[i]
		bottom.append(base+Vector3(p.x*size.x,0,p.y*size.z).rotated(Vector3.UP,yaw))
		top.append(base+Vector3((p.x*.87+.15)*size.x,size.y*(.85+.11*sin(i*2.1+salt)+p.x*.12),p.y*size.z*.84).rotated(Vector3.UP,yaw))
	for i in outline.size():
		var j: int=(i+1)%outline.size()
		_triangle(st,bottom[i],bottom[j],top[i],color.darkened(.12))
		_triangle(st,bottom[j],top[j],top[i],color)
	for i in range(1,outline.size()-1):_triangle(st,top[0],top[i],top[i+1],color.lightened(.08))

func _crown_leaf(st: SurfaceTool,root: Vector3,direction: Vector3,length: float,width: float,color: Color) -> void:
	var across:=direction.cross(Vector3.UP).normalized()*width
	var curl:=sin(root.x*1.7+root.z*.9)
	var ridge:=root+direction*length*.48+Vector3.UP*(.16+.07*curl)
	var tip:=root+direction*length-Vector3.UP*(.14+.12*curl)+across*curl*.4
	var outline: Array[Vector3]=[root,root+direction*length*.25-across*.72,root+direction*length*.62-across,tip,root+direction*length*.62+across,root+direction*length*.25+across*.72]
	for i in outline.size():
		_triangle(st,outline[i],outline[(i+1)%outline.size()],ridge,color.darkened(.06 if i<3 else .0))

func _shore_structure_clear(point: Vector2,radius: float) -> bool:
	for dz in [-radius,0.0,radius]:
		if absf(point.x-terrain.path_x(point.y+dz))<5.2+radius:return false
	for site in _clearance_points:
		if point.distance_to(site)<6.0+radius:return false
	return true

func _add_habitat_collision(family: String,t: Transform3D) -> void:
	var radius:=_footprint(family,t.basis)
	if absf(t.origin.x)-radius>96.0 or t.origin.z+radius<-672 or t.origin.z-radius>182:return
	if not collision_shapes.has(family):
		var faces:=PackedVector3Array()
		for part:Dictionary in source_meshes[family]:
			if part.get("collision",true):faces.append_array(part.mesh.get_faces())
		var shape:=ConcavePolygonShape3D.new()
		shape.set_faces(faces);shape.backface_collision=true
		collision_shapes[family]=shape
	var key:=Vector2i(floori(t.origin.x/70.0),floori(t.origin.z/90.0))
	if not _collision_chunks.has(key):
		var body:=StaticBody3D.new()
		body.name="HabitatCollisionChunk_"+str(key)
		body.collision_layer=1|128
		add_child(body)
		_collision_chunks[key]=body
	var body:StaticBody3D=_collision_chunks[key]
	var owner:=body.create_shape_owner(self)
	body.shape_owner_add_shape(owner,collision_shapes[family])
	body.shape_owner_set_transform(owner,t)
	placements.append({"family":family,"transform":t,"shape":collision_shapes[family],"body":body,"owner":owner})
	_collision_count+=1

func _shelf(st: SurfaceTool,center: Vector3,size: Vector3,yaw: float,color: Color,salt: int) -> void:
	const SIDES := 15
	var points: Array[Vector3] = []
	for layer in 4:
		var profile: float = [.74,1.0,.98,.66][layer]
		var y: float = [-.40,-.14,.25,.43][layer]*size.y
		for j in SIDES:
			var a := j/float(SIDES)*TAU
			var warp := 1.0+sin(j*2.61+salt)*.10+cos(j*1.3+salt)*.055
			var p := Vector3(cos(a)*size.x*profile*warp,y+sin(a*3+salt)*size.y*.1,sin(a)*size.z*profile*warp)
			points.append(center+p.rotated(Vector3.UP,yaw))
	for layer in 3:
		for j in SIDES:
			var a := layer*SIDES+j
			var b := layer*SIDES+(j+1)%SIDES
			var tint := color.darkened(.22 if layer==0 else .04)
			_triangle(st,points[a],points[b],points[a+SIDES],tint)
			_triangle(st,points[b],points[b+SIDES],points[a+SIDES],tint)
	for j in SIDES:
		_triangle(st,center+Vector3.UP*size.y*.43,points[3*SIDES+j],points[3*SIDES+(j+1)%SIDES],color.lightened(.06))

func _tapered_tube(st: SurfaceTool,spine: Array,radii: Array,color: Color,sides: int,flute: float) -> void:
	var curve: Array=[]
	var widths: Array=[]
	for segment in spine.size()-1:
		for step in 3:
			var t:=step/3.0
			curve.append(spine[segment].cubic_interpolate(spine[segment+1],spine[maxi(0,segment-1)],spine[mini(spine.size()-1,segment+2)],t))
			var a: float=radii[maxi(0,segment-1)]
			var b: float=radii[segment]
			var c: float=radii[segment+1]
			var d: float=radii[mini(radii.size()-1,segment+2)]
			widths.append(maxf(.012,.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)))
	curve.append(spine[-1]);widths.append(radii[-1])
	spine=curve;radii=widths
	var points: Array[Vector3] = []
	for i in spine.size():
		var tangent: Vector3 = (spine[mini(i+1,spine.size()-1)]-spine[maxi(i-1,0)]).normalized()
		var axis := Vector3.RIGHT if absf(tangent.dot(Vector3.UP))>.94 else tangent.cross(Vector3.UP).normalized()
		var second := tangent.cross(axis).normalized()
		for j in sides:
			var a := j/float(sides)*TAU
			var radius: float = radii[i]*(1.0+sin(a*5.0+i*.7)*flute)
			points.append(spine[i]+(axis*cos(a)+second*sin(a))*radius)
	for i in spine.size()-1:
		for j in sides:
			var a := i*sides+j
			var b := i*sides+(j+1)%sides
			var tint := color.darkened((1.0-float(i)/maxf(1.0,spine.size()-2))*.23)
			_triangle(st,points[a],points[a+sides],points[b],tint)
			_triangle(st,points[b],points[a+sides],points[b+sides],tint)
	for j in sides:
		var ring := (spine.size()-1)*sides
		_triangle(st,spine[-1],points[ring+(j+1)%sides],points[ring+j],color.darkened(.18))

func _fan(st: SurfaceTool,origin: Vector3,radius: float,rise: float,yaw: float,color: Color,spread: float) -> void:
	const STEPS := 20
	for j in STEPS:
		var a := yaw+(float(j)/STEPS-.5)*PI*spread
		var b := yaw+(float(j+1)/STEPS-.5)*PI*spread
		var ra := radius*(.87+.14*sin(a*2.0+origin.y)+.06*cos(a*5.0))
		var rb := radius*(.87+.14*sin(b*2.0+origin.y)+.06*cos(b*5.0))
		# Localised missing margin, not identical concentric dinner-plate rims.
		ra*=1.0-.24*exp(-pow((a-yaw-.7)/.21,2.0))
		rb*=1.0-.24*exp(-pow((b-yaw-.7)/.21,2.0))
		for ring in 3:
			var t0:=ring/3.0
			var t1:=(ring+1)/3.0
			var p0:=origin+Vector3(cos(a)*ra*t0,(rise+.15)*(1-t0*t0),sin(a)*ra*t0)
			var p1:=origin+Vector3(cos(b)*rb*t0,(rise+.15)*(1-t0*t0),sin(b)*rb*t0)
			var p2:=origin+Vector3(cos(a)*ra*t1,(rise+.15)*(1-t1*t1),sin(a)*ra*t1)
			var p3:=origin+Vector3(cos(b)*rb*t1,(rise+.15)*(1-t1*t1),sin(b)*rb*t1)
			var tone:=color.darkened(.10*(1-t0))
			if ring>0:_triangle(st,p0,p2,p1,tone)
			_triangle(st,p1,p2,p3,tone.lightened(.025))
		var pa:=origin+Vector3(cos(a)*ra,0,sin(a)*ra)
		var pb:=origin+Vector3(cos(b)*rb,0,sin(b)*rb)
		_triangle(st,pa,pa-Vector3.UP*.075,pb,color.darkened(.22))
		_triangle(st,pb,pa-Vector3.UP*.075,pb-Vector3.UP*.075,color.darkened(.22))
		_triangle(st,origin-Vector3.UP*.075,pb-Vector3.UP*.075,pa-Vector3.UP*.075,color.darkened(.28))

func _leaf(st: SurfaceTool,origin: Vector3,height: float,width: float,yaw: float,color: Color) -> void:
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	var middle: Array[Vector3] = []
	for j in 6:
		var t := j/5.0
		var w := sin(t*PI)*width
		var p := Vector3(t*t*height*.38,t*height,sin(t*PI)*height*.12)
		left.append(origin+(p+Vector3(0,0,-w)).rotated(Vector3.UP,yaw))
		right.append(origin+(p+Vector3(0,0,w)).rotated(Vector3.UP,yaw))
		middle.append(origin+(p+Vector3(-sin(t*PI)*width*.15,.025,0)).rotated(Vector3.UP,yaw))
	for j in 5:
		var tint := color.darkened((1.0-j/5.0)*.35)
		_triangle(st,left[j],left[j+1],middle[j],tint)
		_triangle(st,left[j+1],middle[j+1],middle[j],tint.lightened(.07))
		_triangle(st,middle[j],middle[j+1],right[j],tint)
		_triangle(st,middle[j+1],right[j+1],right[j],tint)

func _ground_growth(zone: Dictionary,clusters: Array[Vector3]) -> void:
	var palettes := [Color("799190"),Color("74634d"),Color("416658"),Color("706574")]
	var id: int = zone.id
	var chunks: Dictionary = {}
	for patch_index in (clusters.size()+6):
		var center: Vector3
		if patch_index<clusters.size(): center = clusters[patch_index]
		else:
			var z: float = rng.randf_range(zone.end,zone.start)
			center = Vector3(terrain.path_x(z)+(-1 if patch_index%2==0 else 1)*rng.randf_range(8,35),1,z)
		var key := floori(center.z/55.0)
		if not chunks.has(key): chunks[key] = _surface()
		var st: SurfaceTool = chunks[key]
		for i in (200 if id==2 else 106):
			var angle := rng.randf()*TAU
			var distance := sqrt(rng.randf())*(4.4+1.8*sin(angle*2.0+.4))*center.y
			# Elongated lee-side beds with open patches; not uniform ground scatter.
			var x := center.x+cos(angle)*distance
			var z := center.z+sin(angle)*distance*1.55
			if sin(x*.67+z*.24)+cos(z*.54-x*.21) < -.85: continue
			if not _clear(x,z,.18,false): continue
			var y: float = terrain.height_at(x,z)-.10
			var h := rng.randf_range(.28,.74)*(1.45 if id==2 else .86)
			var color: Color = palettes[id].lightened(rng.randf_range(0,.14))
			if id!=2 and i%3==0:
				_ground_rosette(st,Vector3(x,y,z),h*.72,angle,color)
				_triangle_budget += 28
				continue
			for blade in 3:
				var yaw := rng.randf()*TAU
				_ground_blade(st,Vector3(x,y,z),h,yaw,color)
				_triangle_budget += 4
	for key in chunks:
		var st: SurfaceTool = chunks[key]
		st.generate_normals()
		var node := MeshInstance3D.new()
		node.name = str(zone.name)+"_GroundCommunity_"+str(key)
		node.mesh = st.commit()
		node.material_override = ground_material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = 95
		node.visibility_range_end_margin = 14
		add_child(node)
		_ground_nodes.append(node)

func _ground_rosette(st: SurfaceTool,root: Vector3,radius: float,yaw: float,color: Color) -> void:
	# Ground leaves use root-relative UVs just like grass; global elevation cannot drive wind.
	for leaf in 7:
		var angle := yaw+leaf/7.0*TAU
		var axis := Vector3(cos(angle),0,sin(angle))
		var side := Vector3(-axis.z,0,axis.x)
		var tip := root+axis*radius+Vector3.UP*.075
		var mid := root+axis*radius*.58+Vector3.UP*.12
		for p: Vector3 in [root,mid-side*radius*.20,mid,root,mid,mid+side*radius*.20,mid-side*radius*.20,tip,mid,mid,tip,mid+side*radius*.20]:
			st.set_color(color)
			st.set_uv(Vector2(.5,clampf((p.y-root.y)/.15,0,1)))
			st.add_vertex(p)

func _ground_blade(st: SurfaceTool,root: Vector3,height: float,yaw: float,color: Color) -> void:
	var across := Vector3(cos(yaw),0,sin(yaw))
	var bend := Vector3(-across.z,0,across.x)
	for segment in 2:
		for corner: Vector2 in [Vector2(0,-1),Vector2(0,1),Vector2(1,1),Vector2(0,-1),Vector2(1,1),Vector2(1,-1)]:
			var t := (segment+corner.x)/2.0
			var width := height*.040*sin((t*.85+.15)*PI)
			var p := root+Vector3.UP*height*(t-.12*t*t)+bend*height*t*t*.43+across*width*corner.y
			st.set_color(color)
			st.set_uv(Vector2((corner.y+1)*.5,t))
			st.add_vertex(p)

func _build_marsh_shore(pool: Vector2) -> void:
	var transforms: Dictionary={}
	for family in ["canopy","riparian_tree","riparian_snag","fallen_root","marsh_bank_rock","reed_fan","cups","spore_shelf","shore_pebble","root_bank"]:transforms[family]=[]
	var clusters: Array[Vector3]=[]
	# Authored forest edge. Unequal crowns, open dry approach on the east.
	var trees: Array[Vector3]=[Vector3(-35,1.05,-24),Vector3(-44,.83,-15),Vector3(-43,1.08,23),Vector3(-28,.92,29),Vector3(-16,1.13,25),Vector3(-4,.78,26),Vector3(8,.93,24),Vector3(13,.92,-17),Vector3(-2,1.02,-25),Vector3(-17,.84,-25),Vector3(-29,1.05,-29),Vector3(18,.86,-30)]
	for i in trees.size():
		var item:Vector3=trees[i]
		var point:=pool+Vector2(item.x,item.z)
		var family:="riparian_snag" if i%4==1 else "riparian_tree"
		if not _shore_structure_clear(point,6.0*item.y):continue
		if terrain.height_at(point.x,point.y)<terrain.wetland_water_level()+.1:continue
		transforms[family].append(_placement(point.x,point.y,item.y,float(i)*2.39))
		clusters.append(Vector3(point.x,1.45,point.y))
	var crowns: Array[Vector4]=[Vector4(-27,-27,.64,.7),Vector4(-45,-15,.33,1.8),Vector4(-3,27,.39,-1.2),Vector4(14,-21,.29,2.4)]
	for item in crowns:
		var point:=pool+Vector2(item.x,item.y)
		if _shore_structure_clear(point,12.0):
			transforms.canopy.append(_placement(point.x,point.y,item.z,item.w))
			clusters.append(Vector3(point.x,1.5,point.y))
	var bank_center:=pool+Vector2(-27,-21)
	if _shore_structure_clear(bank_center,15.0):
		transforms.root_bank.append(_placement(bank_center.x,bank_center.y,1.0,0.0))
	# Roots lie ALONG shore tongues; broad low rock shelves oppose the forest.
	var roots: Array[Vector3]=[Vector3(-31,-20,.25),Vector3(-31,24,-.30),Vector3(-5,21,.55),Vector3(11,-17,1.25)]
	for i in roots.size():
		var item:Vector3=roots[i]
		var point:=pool+Vector2(item.x,item.y)
		if _shore_structure_clear(point,9.0):transforms.fallen_root.append(_placement(point.x,point.y,.82+float(i%2)*.1,item.z))
	for item: Vector3 in [Vector3(-42,3,.30),Vector3(-22,-20,-.18),Vector3(-7,18,.36)]:
		var point:=pool+Vector2(item.x,item.y)
		if _shore_structure_clear(point,8.5):transforms.marsh_bank_rock.append(_placement(point.x,point.y,.78,item.z))
	var ground:=_surface()
	# Three unequal shoreline colonies, not a necklace. Exposed east landing stays low.
	var arcs: Array[Vector3]=[Vector3(1.2,2.0,80),Vector3(2.65,3.6,120),Vector3(4.05,5.1,105)]
	for colony in arcs:
		for i in int(colony.z):
			var angle:=rng.randf_range(colony.x,colony.y)
			var point:Vector2=terrain.wetland_shore_point(angle,rng.randf_range(.1,4.5))
			if not _shore_structure_clear(point,.7):continue
			var y:float=terrain.height_at(point.x,point.y)
			var color:=Color("697343").lerp(Color("7e8657"),rng.randf()*.5)
			for blade in 3:
				_ground_blade(ground,Vector3(point.x,y-.035,point.y),rng.randf_range(.36,.95),rng.randf()*TAU,color)
				_triangle_budget+=4
			if i%16==0:transforms.reed_fan.append(_placement(point.x,point.y,rng.randf_range(.55,1.05),angle))
			if i%27==0:transforms.cups.append(_placement(point.x,point.y,rng.randf_range(.25,.39),angle+PI))
	# Deposits occupy short leeward pockets. Most of the bank is exposed sediment.
	for pocket: Vector3 in [Vector3(1.72,.10,24),Vector3(3.12,.14,32),Vector3(4.64,.10,21)]:
		for i in int(pocket.z):
			var angle:=pocket.x+rng.randf_range(-pocket.y,pocket.y)
			var offset:=rng.randf_range(-1.4,2.8)
			var point:Vector2=terrain.wetland_shore_point(angle,offset)
			if _shore_structure_clear(point,.5):
				transforms.shore_pebble.append(_placement(point.x,point.y,rng.randf_range(.22,.67),angle+rng.randf_range(-.6,.6)))
	# A sparse open landing, with no continuous bright rim on the approach side.
	for i in 8:
		var angle:=rng.randf_range(.25,.55)
		var point:Vector2=terrain.wetland_shore_point(angle,rng.randf_range(-.7,1.4))
		if _shore_structure_clear(point,.4):transforms.shore_pebble.append(_placement(point.x,point.y,rng.randf_range(.17,.35),angle))
	# Purple decomposer patches root the woodland instead of filling the water.
	for cluster in clusters:
		for i in 4:
			var point:=Vector2(cluster.x+sin(i*2.39)*3.1,cluster.z+cos(i*2.39)*2.7)
			if _shore_structure_clear(point,1.0):transforms.spore_shelf.append(_placement(point.x,point.y,.5+float(i%3)*.15))
	for family in transforms:
		await terrain.boot_yield()
		_spatial_batches(family,transforms[family])
		_formations.append({"zone":2,"family":family,"count":transforms[family].size()})
	ground.generate_normals()
	var node:=MeshInstance3D.new()
	node.name="VeilContinuousBankGrowth"
	node.mesh=ground.commit()
	node.material_override=ground_material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end=110
	add_child(node)
	_ground_nodes.append(node)
	_ground_growth({"id":2,"start":pool.y+32,"end":pool.y-32,"name":"VeilForestFloor"},clusters)
	terrain.build_stats["shore_colonies"]=3
	terrain.build_stats["shore_inland_shelters"]=transforms.canopy.size()+transforms.riparian_tree.size()+transforms.riparian_snag.size()
	terrain.build_stats["shore_fallen_roots"]=transforms.fallen_root.size()
	terrain.build_stats["shore_root_bank_structures"]=transforms.root_bank.size()
	terrain.build_stats["shore_rock_shelves"]=transforms.marsh_bank_rock.size()
	terrain.build_stats["shore_pebbles"]=transforms.shore_pebble.size()

func debug_set_material_variant(variant: String) -> Dictionary:
	if not terrain._debug_material_allowed() or variant not in ["original","authored"]:
		return {"applied":false}
	for pair in _material_pairs: pair.node.material_override = pair[variant]
	return {"applied":true,"variant":variant,"imported_batches":_material_pairs.size(),"procedural_unchanged":true}

func _build_microfauna(pool: Vector2) -> void:
	var path := "res://scripts/microfauna_visual.gd"
	if not ResourceLoader.exists(path):
		terrain.build_stats["microfauna_adapter"] = "awaiting_shared_visual"
		return
	var script = load(path)
	if script==null: return
	microfauna = script.new()
	microfauna.name = "MicrofaunaVisual"
	add_child(microfauna)
	microfauna.build(terrain,pool)
	terrain.build_stats["microfauna_adapter"] = "delegated"

func tick(delta: float,paused: bool) -> void:
	if paused: return
	clock += delta
	ground_material.set_shader_parameter("world_time",clock)
	if is_instance_valid(microfauna): microfauna.tick(delta,paused)

func update_shadow_culling(position:Vector3,force:bool=false) -> void:
	var point:=Vector2(position.x,position.z)
	if not force and point.distance_squared_to(_shadow_position)<64.0:return
	_shadow_position=point
	for batch in batches:
		var enabled:bool=batch.landmark and not low and point.distance_to(batch.shadow_center)<70.0+float(batch.shadow_radius)
		if enabled==bool(batch.shadow_on):continue
		batch.node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.shadow_on=enabled

func set_low_quality(value: bool) -> void:
	low=value
	for batch in batches:
		batch.node.visibility_range_end=float(batch.range)*(.67 if value else 1.0)
		# Structural geometry keeps every instance so Low never creates invisible walls.
		batch.node.multimesh.visible_instance_count=maxi(1,int(batch.count)/2) if value and not batch.landmark else -1
	for node in _ground_nodes:node.visibility_range_end=58 if value else 95
	update_shadow_culling(terrain._player_position,true)
	if is_instance_valid(microfauna):microfauna.set_low_quality(value)

func set_paused(value: bool) -> void:
	if is_instance_valid(microfauna): microfauna.set_paused(value)
