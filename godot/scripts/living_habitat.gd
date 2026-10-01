extends Node3D
## Authored opaque colonies. Baked placement shares the authoritative driving height.
const SURVEYS = preload("res://scripts/expedition_activities.gd")
const FLORA_KIT := "res://assets/alien_flora/listening-flora.glb"
const FLORA_LAYOUT := "res://assets/alien_flora/habitat-layout.res"
const FLORA_REVISION := 3
const ZONES := [
	{"id":0,"start":173.0,"end":-5.0,"name":"FrostShelf"},
	{"id":1,"start":-16.0,"end":-162.0,"name":"EmberTerrace"},
	{"id":2,"start":-175.0,"end":-347.0,"name":"VeilRootbed"},
	{"id":3,"start":-362.0,"end":-635.0,"name":"PaleGarden"}]
const REGIONS := ["aurora","ember","veil","pale"]
const SOLID_FAMILIES := ["aurora_crown","aurora_fork","ember_crown","ember_fork","veil_crown","veil_fork","pale_crown","pale_fork","veil_rootbed","fallen_root","pale_nurse"]
# Each colony follows the lee of a particular bend; near, middle and far masses overlap.
const REGIONAL_GROVES := [
	[Vector4(-20,143,11,21),Vector4(30,110,13,23),Vector4(-34,62,15,25),Vector4(33,17,12,17)],
	[Vector4(25,-27,12,19),Vector4(-25,-58,14,19),Vector4(36,-107,14,26),Vector4(-37,-146,14,15)],
	[Vector4(-27,-197,15,17),Vector4(35,-219,15,20),Vector4(-45,-253,15,20),Vector4(35,-303,13,22)],
	[Vector4(-25,-393,15,20),Vector4(32,-435,15,23),Vector4(-36,-496,16,26),Vector4(35,-554,15,24),Vector4(-29,-607,14,20)]]
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
var _low_bounds: Dictionary = {}
var _collision_chunks: Dictionary = {}
var _shadow_position := Vector2(INF,INF)
var exposed_geology: Array[Dictionary] = []
var _layout_groups: Array[Dictionary] = []
var _layout_stats: Dictionary = {}
var _shore_mesh: ArrayMesh
var _mud_material: ShaderMaterial

func build(world: Node3D) -> void:
	terrain = world
	rng.seed = 9302644
	ground_material = ShaderMaterial.new()
	ground_material.shader = load("res://shaders/ground_life.gdshader")
	for map_name in ["albedo","roughness","normal"]:
		var map_path: String="res://assets/alien_flora/lamina-veins-"+map_name+".png"
		var texture: Texture2D
		if ResourceLoader.exists(map_path): texture=load(map_path)
		elif not OS.has_feature("web"):
			var pixels := Image.load_from_file(ProjectSettings.globalize_path(map_path))
			if pixels!=null: texture=ImageTexture.create_from_image(pixels)
		ground_material.set_shader_parameter("lamina_"+map_name,texture)
	var mud_path := "res://assets/terrain/cc0/ground037_alb_ht.png"
	var mud_texture: Texture2D
	if ResourceLoader.exists(mud_path): mud_texture=load(mud_path)
	elif not OS.has_feature("web"):
		var pixels := Image.load_from_file(ProjectSettings.globalize_path(mud_path))
		if pixels!=null: mud_texture=ImageTexture.create_from_image(pixels)
	_mud_material=ground_material.duplicate() as ShaderMaterial
	_mud_material.set_shader_parameter("mud_surface",true)
	_mud_material.set_shader_parameter("mud_albedo",mud_texture)
	for id in SURVEYS.SITES: _clearance_points.append(SURVEYS.point(id))
	for point in terrain.passage_route(): _clearance_points.append(point)
	for point in terrain.root_network_points(): _clearance_points.append(point)
	_clearance_points.append(Vector2(terrain.signal_origin().x,-650.0))
	_clearance_points.append(Vector2(-61.0,-148.0))
	_clearance_points.append_array(terrain.ecology_anchor_points())
	if not _load_market_kit(): return
	await terrain.boot_yield()
	var layout: Resource
	if ResourceLoader.exists(FLORA_LAYOUT) and not "--flora-author-layout" in OS.get_cmdline_user_args():
		layout=load(FLORA_LAYOUT)
	if layout!=null and int(layout.get_meta("terrain_revision",-1))==terrain.TERRAIN_REVISION and int(layout.get_meta("flora_revision",-1))==FLORA_REVISION:
		_layout_stats=layout.get_meta("stats",{})
		_shore_mesh=layout.get_meta("shore_mesh",null)
		_attach_shore_margin()
		for group: Dictionary in layout.get_meta("groups",[]):
			await _spatial_batches(group.family,group.poses,true,int(group.zone))
			await terrain.boot_yield()
		terrain.build_stats["flora_baked_layout"]=true
	else:
		for zone in ZONES:
			await _build_region(zone)
			await terrain.boot_yield()
		await _build_marsh_shore(terrain._wetland_center())
		terrain.build_stats["flora_baked_layout"]=false
	for key in _layout_stats: terrain.build_stats[key]=_layout_stats[key]
	var count := 0
	for entry in _formations: count+=int(entry.count)
	terrain.build_stats["authored_flora_instances"]=count
	terrain.build_stats["flora_spatial_batches"]=batches.size()
	terrain.build_stats["flora_families"]=source_meshes.size()
	terrain.build_stats["native_habitat_materials"]=_kit_materials.size()+2
	terrain.build_stats["authored_market_kit"]=true
	terrain.build_stats["authored_market_families"]=16
	terrain.build_stats["regional_shape_variants"]=12
	terrain.build_stats["regional_formations"]=_formations.size()
	terrain.build_stats["regional_ground_triangles"]=_triangle_budget
	terrain.build_stats["habitat_collision_instances"]=_collision_count
	terrain.build_stats["habitat_shared_collision_shapes"]=collision_shapes.size()
	terrain.build_stats["habitat_collision_bodies"]=_collision_chunks.size()
	terrain.build_stats["habitat_clearance_road_m"]=10.4
	terrain.build_stats["habitat_clearance_activity_m"]=12.0
	terrain.build_stats["flora_runtime_topology_triangles"]=0 if terrain.build_stats["flora_baked_layout"] else (_shore_mesh.get_faces().size()/3 if _shore_mesh!=null else 0)
	terrain.build_stats["flora_revision"]=FLORA_REVISION
	_build_microfauna(terrain._wetland_center())

func _load_market_kit() -> bool:
	var source: Node
	if not OS.has_feature("web") and "--flora-raw-kit" in OS.get_cmdline_user_args():
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file(ProjectSettings.globalize_path(FLORA_KIT),state)==OK: source=document.generate_scene(state)
	elif ResourceLoader.exists(FLORA_KIT): source=(load(FLORA_KIT) as PackedScene).instantiate()
	elif not OS.has_feature("web"):
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file(ProjectSettings.globalize_path(FLORA_KIT),state)==OK: source=document.generate_scene(state)
	if source==null:
		push_error("AUTHORED_ALIEN_FLORA_UNAVAILABLE: "+FLORA_KIT)
		return false
	for child: Node in source.get_children():
		var entries: Array=[]
		_collect(child,Transform3D.IDENTITY,entries)
		if not entries.is_empty(): source_meshes[str(child.name)]=entries
	source.free()
	for region in REGIONS:
		for form in ["crown","fork","floor"]:
			if not source_meshes.has(region+"_"+form):
				push_error("AUTHORED_ALIEN_FLORA_FAMILY_MISSING: "+region+"_"+form)
				return false
	# Preserve the material-review closeup's established cups identity.
	source_meshes["cups"]=source_meshes.veil_floor
	return true

func _collect(node: Node,transform: Transform3D,entries: Array) -> void:
	var pose := transform
	if node is Node3D: pose=transform*node.transform
	if node is MeshInstance3D:
		for index in node.mesh.get_surface_count():
			var original: StandardMaterial3D=node.get_active_material(index)
			if original==null: continue
			var key := original.resource_name
			if not _kit_materials.has(key):
				var material := original.duplicate() as StandardMaterial3D
				material.vertex_color_use_as_albedo=true
				material.albedo_color=Color.WHITE
				material.metallic=0.0
				material.roughness=1.0 if material.roughness_texture!=null else .82
				material.metallic_specular=.28
				material.normal_scale=.22
				material.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED
				material.cull_mode=BaseMaterial3D.CULL_BACK
				_kit_materials[key]=material
			var mesh: Mesh=node.mesh
			# The new kit is joined and transformed before export. Unusual importer
			# transforms still have a bounded fallback, never per-instance rebuild.
			if node.mesh.get_surface_count()!=1 or not pose.is_equal_approx(Transform3D.IDENTITY):
				var surface := SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				surface.append_from(node.mesh,index,pose)
				mesh=surface.commit()
			entries.append({"mesh":mesh,"material":_kit_materials[key],"original":original,"collision":"Stem" in key})
	for child in node.get_children(): _collect(child,pose,entries)

func _clear(x: float,z: float,radius: float,activity: bool=true) -> bool:
	if radius>1.5:
		for boundary in [40.0,-130.0,-300.0,-470.0]:
			if absf(z-boundary)<radius+1.8: return false
	for dz in [-radius,0.0,radius]:
		if absf(x-terrain.path_x(z+dz))<(5.2 if activity else 2.6)+radius: return false
	if activity:
		for point in _clearance_points:
			if Vector2(x,z).distance_to(point)<6.0+radius: return false
	else:
		for point in _clearance_points:
			if Vector2(x,z).distance_to(point)<2.0+radius: return false
	if terrain.wetland_basin_distance(Vector2(x,z))<1.10+radius*.055: return false
	return not activity or _approach_clear(Vector2(x,z),radius)

func _approach_clear(point: Vector2,radius: float) -> bool:
	if terrain.environment_access_distance(point.x,point.y)<7.0+radius: return false
	for id in ["aurora_echo","ember_vent","marsh_crossing","spore_pulse"]:
		var anchor: Vector2=SURVEYS.point(id)
		var road: float=terrain.path_x(anchor.y)
		if absf(point.y-anchor.y)<5.0+radius and point.x>minf(road,anchor.x)-6.0-radius and point.x<maxf(road,anchor.x)+6.0+radius: return false
	return true

func _placement(x: float,z: float,size: float,yaw: float=INF) -> Transform3D:
	var angle := rng.randf()*TAU if is_inf(yaw) else yaw
	var dx: float=(terrain.height_at(x+1.25,z)-terrain.height_at(x-1.25,z))/2.5
	var dz: float=(terrain.height_at(x,z+1.25)-terrain.height_at(x,z-1.25))/2.5
	var normal := Vector3(-dx,1.0,-dz).normalized()
	var across := Vector3(1.0,dx,0.0).normalized()
	var slope := Basis(across,normal,across.cross(normal).normalized())
	return Transform3D(slope*Basis(Vector3.UP,angle).scaled(Vector3.ONE*size),Vector3(x,terrain.height_at(x,z)-.10*size,z))

func _seat_transform(family: String,pose: Transform3D) -> Transform3D:
	if not _support_vertices.has(family):
		var bottom := INF
		for part: Dictionary in source_meshes[family]: bottom=minf(bottom,part.mesh.get_aabb().position.y)
		var support := PackedVector3Array()
		var unique: Dictionary={}
		for part: Dictionary in source_meshes[family]:
			var vertices: PackedVector3Array=part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				if vertex.y<=bottom+.16 and not unique.has(vertex):
					unique[vertex]=true
					support.append(vertex)
		_support_vertices[family]=support
	var gap := -INF
	for local: Vector3 in _support_vertices[family]:
		var point := pose*local
		gap=maxf(gap,point.y-terrain.height_at(point.x,point.z))
	if gap>-.025: pose.origin.y-=gap+.025
	return pose

func _footprint(family: String,basis: Basis) -> float:
	if not _family_bounds.has(family):
		var bounds: AABB=source_meshes[family][0].mesh.get_aabb()
		var low_points := PackedVector3Array()
		for part: Dictionary in source_meshes[family]:
			bounds=bounds.merge(part.mesh.get_aabb())
			if not part.collision: continue
			var vertices: PackedVector3Array=part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				if vertex.y<3.5: low_points.append(vertex)
		_family_bounds[family]=bounds
		if not low_points.is_empty():
			var low_box := AABB(low_points[0],Vector3.ZERO)
			for vertex in low_points: low_box=low_box.expand(vertex)
			_low_bounds[family]=low_box
	var bounds: AABB=_low_bounds.get(family,_family_bounds[family]) if family.ends_with("_crown") else _family_bounds[family]
	var radius := 0.0
	for index in 8:
		var corner: Vector3=basis*bounds.get_endpoint(index)
		radius=maxf(radius,Vector2(corner.x,corner.z).length())
	return radius

func _grove_place(transforms: Dictionary,family: String,point: Vector2,size: float,yaw: float) -> bool:
	var pose := _placement(point.x,point.y,size,yaw)
	if not _clear(point.x,point.y,_footprint(family,pose.basis),family in SOLID_FAMILIES): return false
	transforms[family].append(pose)
	return true

func _ground_patch(transforms: Dictionary,family: String,center: Vector2,radii: Vector2,yaw: float,size: float=1.0,shore: bool=false) -> void:
	# Bounded authoring grid; all exact fitted tufts are saved in the layout resource.
	# Dense interior, scalloped edge and small lee-side gaps replace lane/shore rows.
	var step := 1.20
	var across := int(ceil(radii.x/step))
	var along := int(ceil(radii.y/step))
	for x_index in range(-across,across+1):
		for z_index in range(-along,along+1):
			var local := Vector2(x_index*step+rng.randf_range(-.37,.37),z_index*step+rng.randf_range(-.37,.37))
			var normalized := Vector2(local.x/radii.x,local.y/radii.y)
			var distance := normalized.length()
			var angle := normalized.angle()
			var edge := .87+.13*sin(angle*3+.8)+.08*sin(angle*7)+.055*cos(angle*5+1.2)
			if distance>edge: continue
			if distance>.65 and sin(local.x*.65+local.y*.43)+cos(local.y*.82)<-.92: continue
			var point := center+local.rotated(yaw)
			var scale_value := size*(.65+.34*(1.0-smoothstep(.45,1.0,distance)))*rng.randf_range(.83,1.15)
			if shore:
				var pose := _placement(point.x,point.y,scale_value,rng.randf()*TAU)
				if terrain.height_at(point.x,point.y)<terrain.wetland_water_level()+.035: continue
				if _shore_structure_clear(point,_footprint(family,pose.basis),true): transforms[family].append(pose)
			else: _grove_place(transforms,family,point,scale_value,rng.randf()*TAU)
	_layout_stats["connected_ground_beds"]=int(_layout_stats.get("connected_ground_beds",0))+1

func _build_region(zone: Dictionary) -> void:
	var id: int=zone.id
	var region: String=REGIONS[id]
	var transforms: Dictionary={}
	for family in source_meshes: transforms[family]=[]
	var planted: Array[Vector2]=[]
	for grove: Vector4 in REGIONAL_GROVES[id]:
		var center := Vector2(terrain.path_x(grove.y)+grove.x,grove.y)
		for attempt in 44:
			var angle := rng.randf()*TAU
			var distance := sqrt(rng.randf())
			var point := center+Vector2(cos(angle)*grove.z,sin(angle)*grove.w)*distance
			if point.y>zone.start or point.y<zone.end: continue
			var spaced := true
			for other in planted:
				if point.distance_squared_to(other)<30.25: spaced=false;break
			if not spaced: continue
			var slope := Vector2(terrain.height_at(point.x+2,point.y)-terrain.height_at(point.x-2,point.y),terrain.height_at(point.x,point.y+2)-terrain.height_at(point.x,point.y-2)).length()/4.0
			if slope>1.0: continue
			var family := region+("_crown" if attempt%3 else "_fork")
			if not _grove_place(transforms,family,point,rng.randf_range(.78,1.18),angle): continue
			planted.append(point)
			if id==3 and planted.size()%6==0:
				_grove_place(transforms,"pale_nurse",point+Vector2(3.4,4.0),.72,angle+PI*.5)
		_ground_patch(transforms,region+"_floor",center,Vector2(grove.z*.68,grove.w*.57),.1*signf(grove.x),1.05)
		var shoulder := Vector2(terrain.path_x(grove.y)+signf(grove.x)*5.5,grove.y+2.0)
		var belt_center := center.lerp(shoulder,.53)
		_ground_patch(transforms,region+"_floor",belt_center,Vector2(absf(center.x-shoulder.x)*.53+1.0,grove.w*.40),.12*signf(grove.x),1.16)
		await terrain.boot_yield()
	_add_sightline_habitat(id,transforms)
	# Root-to-shoulder belts above replace the disconnected sequence of lane puffs.
	for family in transforms:
		await _spatial_batches(family,transforms[family],false,id)
		await terrain.boot_yield()
	_layout_stats["mass_region_"+str(id)+"_structures"]=planted.size()
	_layout_stats["lane_edge_"+str(id)+"_instances"]=transforms[region+"_floor"].size()

func _add_sightline_habitat(id: int,transforms: Dictionary) -> void:
	var region: String=REGIONS[id]
	# Cross-road offset, z, scale, tall/fork. Spawn and both bend directions have
	# unequal foreground shoulders and overlapping middle crowns.
	var groups: Array=[
		[Vector4(-12,147,1.12,1),Vector4(15,134,.92,1),Vector4(-22,126,1.2,1),Vector4(12,112,1.08,0),Vector4(-15,91,1.1,1),Vector4(30,82,1.25,1),Vector4(12,56,1.0,1),Vector4(-20,33,1.1,0)],
		[Vector4(14,-20,1.05,1),Vector4(-14,-37,.96,0),Vector4(-22,-61,1.18,1),Vector4(14,-82,1.0,1),Vector4(32,-99,1.28,1),Vector4(-19,-115,1.1,0),Vector4(17,-145,1.03,1)],
		[Vector4(-15,-181,1.1,1),Vector4(23,-200,1.18,1),Vector4(-27,-222,1.25,1),Vector4(29,-249,1.14,1),Vector4(-33,-274,1.26,1),Vector4(27,-296,1.1,0),Vector4(-22,-320,1.04,1)],
		[Vector4(-14,-374,1.06,1),Vector4(19,-396,1.18,0),Vector4(-25,-431,1.21,1),Vector4(28,-453,1.17,1),Vector4(-19,-492,1.05,0),Vector4(29,-531,1.25,1),Vector4(-17,-573,1.15,1),Vector4(23,-608,1.08,0)]][id]
	var accepted := 0
	for group: Vector4 in groups:
		var point := Vector2(terrain.path_x(group.y)+group.x,group.y)
		var family := region+("_crown" if group.w>0 else "_fork")
		if not _grove_place(transforms,family,point,group.z,group.y*.023): continue
		accepted+=1
		_ground_patch(transforms,region+"_floor",point+Vector2(signf(group.x)*.8,1),Vector2(4.4,6.8),group.y*.003,1.0)
	_layout_stats["sightline_habitat_"+str(id)+"_structures"]=accepted

func _shore_structure_clear(point: Vector2,radius: float,low_growth: bool=false) -> bool:
	for dz in [-radius,0.0,radius]:
		if absf(point.x-terrain.path_x(point.y+dz))<(2.6 if low_growth else 5.2)+radius: return false
	for site in _clearance_points:
		if point.distance_to(site)<(2.0 if low_growth else 6.0)+radius: return false
	return low_growth or _approach_clear(point,radius)

func _build_marsh_shore(_pool: Vector2) -> void:
	var transforms: Dictionary={}
	for family in source_meshes: transforms[family]=[]
	# Broad unequal beds follow bank tongues; the wet margin is intentionally bare.
	var colonies: Array[Vector3]=[Vector3(.92,3.8,1.0),Vector3(1.48,3.0,1.16),Vector3(2.22,4.2,1.04),Vector3(2.88,3.4,1.18),Vector3(3.52,4.6,1.1),Vector3(4.12,3.1,1.0),Vector3(4.70,4.1,1.15),Vector3(5.34,3.6,1.05)]
	for index in colonies.size():
		var colony: Vector3=colonies[index]
		var angle := colony.x
		var point: Vector2=terrain.wetland_shore_point(angle,colony.y)
		_ground_patch(transforms,"veil_floor",point,Vector2(3.0+float(index%3)*.6,7.0+float(index%2)*2),angle-PI*.5,colony.z,true)
		var crown_point: Vector2=terrain.wetland_shore_point(angle,colony.y+5.0)
		var family := "veil_crown" if index%3 else "veil_fork"
		var pose := _placement(crown_point.x,crown_point.y,.9+float(index%3)*.08,angle)
		if _shore_structure_clear(crown_point,_footprint(family,pose.basis)): transforms[family].append(pose)
		var root_point: Vector2=terrain.wetland_shore_point(angle,colony.y+1.4)
		pose=_placement(root_point.x,root_point.y,.58,angle+PI*.5)
		if _shore_structure_clear(root_point,_footprint("veil_rootbed",pose.basis)): transforms.veil_rootbed.append(pose)
		if index%2:
			pose=_placement(root_point.x,root_point.y,.60,angle+PI*.5)
			if _shore_structure_clear(root_point,_footprint("fallen_root",pose.basis)): transforms.fallen_root.append(pose)
		# Small depositional pockets, spanning bed and mud instead of a rock necklace.
		for chip in 9:
			var a := angle+rng.randf_range(-.075,.075)
			var deposit: Vector2=terrain.wetland_shore_point(a,rng.randf_range(-1.0,.9))
			if _shore_structure_clear(deposit,.34,true): transforms.shore_pebble.append(_placement(deposit.x,deposit.y,rng.randf_range(.3,.6),a))
		await terrain.boot_yield()
	# Preserve the existing close material-review identity in one irregular rooted bed.
	var review_point: Vector2=terrain.wetland_shore_point(1.63,2.0)
	_ground_patch(transforms,"cups",review_point,Vector2(2.4,3.8),.35,.72,true)
	for family in transforms:
		await _spatial_batches(family,transforms[family],false,2)
		await terrain.boot_yield()
	_bake_shore_margin()
	_layout_stats["shore_colonies"]=colonies.size()
	_layout_stats["shore_waterline_laminae"]=transforms.veil_floor.size()+transforms.cups.size()
	_layout_stats["shore_inland_shelters"]=transforms.veil_crown.size()+transforms.veil_fork.size()
	_layout_stats["shore_fallen_roots"]=transforms.fallen_root.size()
	_layout_stats["shore_root_bank_structures"]=transforms.veil_rootbed.size()
	_layout_stats["shore_rock_shelves"]=0
	_layout_stats["shore_pebbles"]=transforms.shore_pebble.size()

func _bake_shore_margin() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 512:
		var angle := float(index)/512.0*TAU
		var next_angle := float(index+1)/512.0*TAU
		var points: Array[Vector2]=[]
		var offsets: Array[float]=[]
		for a in [angle,next_angle]:
			for offset: float in [-.65,-.08,.45,.94,1.45+.28*sin(a*3+.4)+.18*cos(a*7)]:
				points.append(terrain.wetland_shore_point(a,offset))
				offsets.append(offset)
		if points[0].distance_to(points[5])>1.8: continue
		# Broken exposed-bed gaps avoid a continuous polygon apron around inlet jumps.
		if sin(angle*11+.3)>.90 and index%17<5: continue
		for band in 4:
			if points[band].distance_to(points[band+5])>1.8 or points[band+1].distance_to(points[band+6])>1.8: continue
			if maxf(maxf(points[band].distance_to(points[band+1]),points[band+5].distance_to(points[band+6])),maxf(points[band].distance_to(points[band+6]),points[band+1].distance_to(points[band+5])))>2.2: continue
			var middle := (points[band]+points[band+1]+points[band+5]+points[band+6])*.25
			if not _shore_structure_clear(middle,.2,true): continue
			for corner in [band,band+5,band+1,band+1,band+5,band+6]:
				var point: Vector2=points[corner]
				var dx: float=(terrain.height_at(point.x+.3,point.y)-terrain.height_at(point.x-.3,point.y))/.6
				var dz: float=(terrain.height_at(point.x,point.y+.3)-terrain.height_at(point.x,point.y-.3))/.6
				surface.set_normal(Vector3(-dx,1,-dz).normalized())
				var wetness := clampf((offsets[corner]+.65)/2.5,0,1)
				surface.set_color(Color(.66,.64,.60).lerp(Color(.91,.88,.81),wetness).srgb_to_linear())
				surface.set_uv(point*.42)
				surface.add_vertex(Vector3(point.x,terrain.height_at(point.x,point.y)+.013,point.y))
	surface.index()
	_shore_mesh=surface.commit()
	_attach_shore_margin()

func _attach_shore_margin() -> void:
	# The collidable terrain already shades wet sediment from the actual water level.
	# A second opaque strip introduced angular colour edges above that shared surface.
	_layout_stats["shore_sediment_triangles"] = 0
	_layout_stats["shore_uses_authoritative_terrain"] = true

func _spatial_batches(family: String,transforms: Array,seated: bool=false,zone: int=-1) -> void:
	if transforms.is_empty() or not source_meshes.has(family): return
	var chunks: Dictionary={}
	var accepted: Array[Transform3D]=[]
	for raw: Transform3D in transforms:
		if not seated and family in SOLID_FAMILIES and terrain.environment_access_distance(raw.origin.x,raw.origin.z)<7.0+_footprint(family,raw.basis): continue
		var pose := raw if seated else _seat_transform(family,raw)
		if family in SOLID_FAMILIES: _add_habitat_collision(family,pose)
		var key := Vector2i(floori(pose.origin.x/48.0),floori(pose.origin.z/64.0))
		if not chunks.has(key): chunks[key]=[]
		chunks[key].append(pose)
		accepted.append(pose)
	if accepted.is_empty(): return
	_layout_groups.append({"zone":zone,"family":family,"poses":accepted})
	_formations.append({"zone":zone,"family":family,"count":accepted.size()})
	for key in chunks:
		var center := Vector2.ZERO
		for pose: Transform3D in chunks[key]: center+=Vector2(pose.origin.x,pose.origin.z)
		center/=float(chunks[key].size())
		var extent := 0.0
		for pose: Transform3D in chunks[key]: extent=maxf(extent,center.distance_to(Vector2(pose.origin.x,pose.origin.z)))
		var landmark := family in SOLID_FAMILIES
		for part: Dictionary in source_meshes[family]:
			var mm := MultiMesh.new()
			mm.transform_format=MultiMesh.TRANSFORM_3D
			mm.mesh=part.mesh
			mm.use_colors=true
			mm.instance_count=chunks[key].size()
			for index in chunks[key].size():
				var pose: Transform3D=chunks[key][index]
				# Even/odd ordering lets Low thin every bed instead of cutting a row off.
				var write_index: int=index if landmark else index/2+((chunks[key].size()+1)/2 if index%2 else 0)
				mm.set_instance_transform(write_index,pose)
				var tone := .93+.07*sin(pose.origin.x*.23+pose.origin.z*.15)
				mm.set_instance_color(write_index,Color(tone,tone,tone,1))
			var node := MultiMeshInstance3D.new()
			node.name=family+"_habitat_"+str(key)
			node.multimesh=mm
			node.material_override=part.material if landmark or part.collision else ground_material
			node.visibility_range_end=300.0 if landmark else 95.0
			node.visibility_range_end_margin=14.0
			node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if landmark else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)
			_material_pairs.append({"node":node,"authored":node.material_override,"original":part.original})
			batches.append({"node":node,"count":mm.instance_count,"range":node.visibility_range_end,"family":family,"landmark":landmark,"shadow_center":center,"shadow_radius":extent,"shadow_on":landmark,"poses":chunks[key]})
			if not landmark: _triangle_budget+=part.mesh.get_faces().size()/3*mm.instance_count

func _add_habitat_collision(family: String,pose: Transform3D) -> void:
	var radius := _footprint(family,pose.basis)
	if absf(pose.origin.x)-radius>96.0 or pose.origin.z+radius<-672 or pose.origin.z-radius>182: return
	if not collision_shapes.has(family):
		var faces := PackedVector3Array()
		for part: Dictionary in source_meshes[family]:
			if part.collision: faces.append_array(part.mesh.get_faces())
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		shape.backface_collision=true
		collision_shapes[family]=shape
	var key := Vector2i(floori(pose.origin.x/48.0),floori(pose.origin.z/64.0))
	if not _collision_chunks.has(key):
		var body := StaticBody3D.new()
		body.name="HabitatCollisionChunk_"+str(key)
		body.collision_layer=1|128
		add_child(body)
		_collision_chunks[key]=body
	var body: StaticBody3D=_collision_chunks[key]
	var owner := body.create_shape_owner(self)
	body.shape_owner_add_shape(owner,collision_shapes[family])
	body.shape_owner_set_transform(owner,pose)
	placements.append({"family":family,"transform":pose,"shape":collision_shapes[family],"body":body,"owner":owner})
	_collision_count+=1

func debug_set_material_variant(variant: String) -> Dictionary:
	if not terrain._debug_material_allowed() or variant not in ["original","authored"]: return {"applied":false}
	for pair in _material_pairs: pair.node.material_override=pair[variant]
	return {"applied":true,"variant":variant,"imported_batches":_material_pairs.size(),"procedural_unchanged":true}

func _build_microfauna(pool: Vector2) -> void:
	var path := "res://scripts/microfauna_visual.gd"
	if not ResourceLoader.exists(path):
		terrain.build_stats["microfauna_adapter"]="awaiting_shared_visual"
		return
	var script = load(path)
	if script==null: return
	microfauna=script.new()
	microfauna.name="MicrofaunaVisual"
	add_child(microfauna)
	microfauna.build(terrain,pool)
	terrain.build_stats["microfauna_adapter"]="delegated"

func tick(delta: float,paused: bool) -> void:
	if paused: return
	clock+=delta
	ground_material.set_shader_parameter("world_time",clock)
	if is_instance_valid(microfauna): microfauna.tick(delta,paused)

func update_shadow_culling(position: Vector3,force: bool=false) -> void:
	var point := Vector2(position.x,position.z)
	if not force and point.distance_squared_to(_shadow_position)<64.0: return
	_shadow_position=point
	for batch in batches:
		var enabled: bool=batch.landmark and not low and point.distance_to(batch.shadow_center)<70.0+float(batch.shadow_radius)
		if enabled==bool(batch.shadow_on): continue
		batch.node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.shadow_on=enabled

func set_low_quality(value: bool) -> void:
	low=value
	for batch in batches:
		batch.node.visibility_range_end=float(batch.range)*(.70 if value else 1.0)
		batch.node.multimesh.visible_instance_count=maxi(1,int(batch.count)/2) if value and not batch.landmark else -1
	update_shadow_culling(terrain._player_position,true)
	if is_instance_valid(microfauna): microfauna.set_low_quality(value)

func set_paused(value: bool) -> void:
	if is_instance_valid(microfauna): microfauna.set_paused(value)
