extends Node3D
## Authored static habitat instances, spatially batched; no gameplay-state ownership.
var terrain:Node3D
var batches:Array[Dictionary]=[]
var ground_material:ShaderMaterial
var clock:=0.0
var species_nodes:Array[Node3D]=[]
var source_meshes:Dictionary={}
var rng:=RandomNumberGenerator.new()
var low:=false

func build(world:Node3D)->void:
	terrain=world;rng.seed=24092026
	ground_material=ShaderMaterial.new();ground_material.shader=load("res://shaders/ground_life.gdshader")
	for family in ["canopy","sails","pods","cups","spores"]:
		_load_family(family)
	var zones:=[{"z":95.0,"length":120.0,"id":0},{"z":-45.0,"length":105.0,"id":1},{"z":-215.0,"length":130.0,"id":2},{"z":-395.0,"length":210.0,"id":3}]
	var total:=0
	for zone in zones:
		var transforms:Dictionary={}
		for family in source_meshes:transforms[family]=[]
		var n:=7 if zone.id==2 else 3
		for i in n:
			var z:float=zone.z-float(i)/maxf(1.0,n-1)*zone.length
			var side:float=-1.0 if i%2==0 else 1.0
			var x:float=terrain.path_x(z)+side*(22.0+rng.randf_range(0,9))
			var scale_value:float=rng.randf_range(.54,.78) if zone.id==2 else rng.randf_range(.28,.46)
			transforms.canopy.append(_placement(x,z,scale_value))
		for i in (16 if zone.id==2 else 8):
			var z:float=zone.z-rng.randf()*zone.length
			var side:float=-1.0 if i%2==0 else 1.0
			var x:float=terrain.path_x(z)+side*rng.randf_range(11,31)
			transforms.sails.append(_placement(x,z,rng.randf_range(.30,.64) if zone.id==2 else rng.randf_range(.18,.4)))
		var detail_family:="pods" if zone.id==1 else "spores" if zone.id==3 else "cups"
		for i in (9 if zone.id==2 else 5):
			var z:float=zone.z-rng.randf()*zone.length
			var x:float=terrain.path_x(z)+(-1 if i%2==0 else 1)*rng.randf_range(9,19)
			transforms[detail_family].append(_placement(x,z,rng.randf_range(.35,.66)))
		for family in transforms:
			_spatial_batches(family,transforms[family]);total+=transforms[family].size()
		_ground_growth(zone.z,zone.length,zone.id)
	var pool:Vector2=terrain._wetland_center()
	var shore:Array=[]
	for i in 8:
		var angle:float=i/8.0*TAU
		shore.append(_placement(pool.x+cos(angle)*7.5,pool.y+sin(angle)*7.5,.4+rng.randf()*.16))
	_spatial_batches("cups",shore)
	terrain.build_stats["authored_flora_instances"]=total+shore.size()
	terrain.build_stats["flora_spatial_batches"]=batches.size()
	terrain.build_stats["flora_families"]=5
	_build_microfauna(pool)

func _placement(x:float,z:float,size:float)->Transform3D:
	return Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*size),Vector3(x,terrain.height_at(x,z)-.14,z))

func _load_family(family:String)->void:
	var packed:=load("res://assets/visual_flora/"+family+"_lod1.glb") as PackedScene
	if packed==null:return
	var instance:=packed.instantiate()
	var groups:Dictionary={}
	_collect(instance,Transform3D.IDENTITY,groups)
	var entries:Array=[]
	for key in groups:
		var data:Dictionary=groups[key]
		var material:=data.material as StandardMaterial3D
		if material!=null:
			material=material.duplicate()
			material.metallic=0.0;material.roughness=1.0 if material.roughness_texture!=null else .65
			material.vertex_color_use_as_albedo=true
			material.normal_scale=minf(material.normal_scale,.45)
			if material.emission_enabled:material.emission_energy_multiplier=minf(.65,material.emission_energy_multiplier)
			material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		entries.append({"mesh":data.surface.commit(),"material":material})
	source_meshes[family]=entries
	instance.free()

func _collect(node:Node,transform:Transform3D,groups:Dictionary)->void:
	var t:=transform
	if node is Node3D:t=transform*node.transform
	if node is MeshInstance3D:
		for index in node.mesh.get_surface_count():
			var mat:Material=node.get_active_material(index)
			var key:=str(mat.get_instance_id()) if mat!=null else "none"
			if not groups.has(key):
				var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key]={"surface":surface,"material":mat}
			groups[key].surface.append_from(node.mesh,index,t)
	for child in node.get_children():_collect(child,t,groups)

func _spatial_batches(family:String,transforms:Array)->void:
	if transforms.is_empty() or not source_meshes.has(family):return
	var chunks:Dictionary={}
	for t:Transform3D in transforms:
		var key:=floori(t.origin.z/55.0)
		if not chunks.has(key):chunks[key]=[]
		chunks[key].append(t)
	for key in chunks:
		for part:Dictionary in source_meshes[family]:
			var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=part.mesh;mm.instance_count=chunks[key].size()
			for i in chunks[key].size():mm.set_instance_transform(i,chunks[key][i])
			var node:=MultiMeshInstance3D.new();node.multimesh=mm;node.material_override=part.material
			node.name=family+"_habitat_"+str(key);node.visibility_range_end=160.0 if family=="canopy" else 85.0
			node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node);batches.append({"node":node,"count":mm.instance_count,"range":node.visibility_range_end,"family":family})

func _ground_growth(start:float,length:float,zone:int)->void:
	var palettes:=[Color("5e8592"),Color("76574f"),Color("315e68"),Color("666080")]
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 650:
		var z:=start-rng.randf()*length
		var x:float=terrain.path_x(z)+(-1 if i%2==0 else 1)*rng.randf_range(6.5,38)
		if absf(sin(x*.14+z*.08))<.33:continue
		var y:float=terrain.height_at(x,z)-.05
		var h:=rng.randf_range(.15,.48)*(1.4 if zone==2 else .8)
		var w:=h*.055
		var color:Color=palettes[zone].lightened(rng.randf_range(0,.16))
		for blade in 3:
			var yaw:=rng.randf()*TAU
			var right:=Vector3(cos(yaw),0,sin(yaw))*w
			var root:=Vector3(x,y,z)
			var tip:=root+Vector3(sin(yaw)*h*.5,h,cos(yaw)*h*.5)
			var middle:=root.lerp(tip,.6)+Vector3.UP*h*.16
			for triangle in [[root-right,root+right,middle+right*.7],[root-right,middle+right*.7,middle-right*.7],[middle-right*.7,middle+right*.7,tip]]:
				for j in 3:
					st.set_color(color);st.set_uv(Vector2(float(j%2),float(j)/2));st.add_vertex(triangle[j])
	st.generate_normals()
	var node:=MeshInstance3D.new();node.mesh=st.commit();node.material_override=ground_material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

func _build_microfauna(pool:Vector2)->void:
	var path:="res://assets/visual_microfauna/membrane_flier_01.glb"
	if not ResourceLoader.exists(path):return
	var packed:=load(path) as PackedScene
	for i in 4:
		var node:=packed.instantiate() as Node3D
		node.scale=Vector3.ONE*.5
		node.position=Vector3(pool.x+sin(i*1.7)*5,terrain.height_at(pool.x,pool.y)+2.8,pool.y+cos(i*1.7)*5)
		node.set_meta("rest",node.position);add_child(node);species_nodes.append(node)
		for player in node.find_children("*","AnimationPlayer",true,false):
			for clip in player.get_animation_list():
				if clip!="RESET":player.play(clip);break

func tick(delta:float,paused:bool)->void:
	if paused:return
	clock+=delta;ground_material.set_shader_parameter("world_time",clock)
	for i in species_nodes.size():
		var node:=species_nodes[i];var rest:Vector3=node.get_meta("rest")
		node.position=rest+Vector3(sin(clock*.5+i)*.7,sin(clock*1.1+i)*.2,cos(clock*.6+i)*.6)

func set_low_quality(value:bool)->void:
	low=value
	for batch in batches:
		batch.node.visibility_range_end=float(batch.range)*(.6 if value else 1.0)
		batch.node.multimesh.visible_instance_count=maxi(1,int(batch.count)/2) if value else -1

func set_paused(value:bool)->void:
	for node in species_nodes:
		for player in node.find_children("*","AnimationPlayer",true,false):player.speed_scale=0.0 if value else 1.0
