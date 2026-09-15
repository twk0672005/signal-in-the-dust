extends SceneTree

const OUT = "C:/Users/tsang/DeepSpaceRover/deep-space-rover-three-20260906/evidence/assets/godot-material-fix/"
var stage: Node3D
var camera: Camera3D
var report: Dictionary = {}
var final_mode: bool = "--final" in OS.get_cmdline_user_args()

func _initialize() -> void:
	call_deferred("run")

func material_report(node: Node) -> Array:
	var result: Array = []
	for item in node.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = item.mesh
		for i in range(mesh.get_surface_count()):
			var m: Material = mesh.surface_get_material(i)
			var a: Array = mesh.surface_get_arrays(i)
			var colors := PackedColorArray()
			if a[Mesh.ARRAY_COLOR] != null: colors = a[Mesh.ARRAY_COLOR]
			var sample: Array = []
			for j in range(mini(4, colors.size())): sample.append(str(colors[j]))
			result.append({"node":item.name,"surface":i,"material":m.resource_name,"albedo":str(m.albedo_color),"vertex_color_use_as_albedo":m.vertex_color_use_as_albedo,"vertex_color_is_srgb":m.vertex_color_is_srgb,"normal_scale":m.normal_scale,"vertex_color_samples":sample,"aabb":str(item.get_aabb()),"transform":str(item.transform)})
	return result

func capture(name: String) -> void:
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+("-after" if final_mode else "")+".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1200,900)
	stage=Node3D.new();root.add_child(stage)
	var world=WorldEnvironment.new();var env=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color(.055,.065,.085)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color(.38,.43,.53);env.ambient_light_energy=.6
	env.tonemap_exposure=1.05;world.environment=env;stage.add_child(world)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-25,0);sun.light_energy=1.3;stage.add_child(sun)
	var floor_node=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(80,80);floor_node.mesh=plane
	var floor_mat=StandardMaterial3D.new();floor_mat.albedo_color=Color(.18,.11,.07);floor_mat.roughness=1;floor_node.material_override=floor_mat;stage.add_child(floor_node)
	camera=Camera3D.new();camera.fov=60;camera.position=Vector3(11,7,13);stage.add_child(camera);camera.look_at(Vector3(0,3.7,0));camera.current=true
	var signal_node=load("res://assets/models/signal.glb").instantiate();stage.add_child(signal_node)
	report["engine"]=Engine.get_version_info();report["signal"]=material_report(signal_node)
	await capture("signal-imported")
	if not final_mode:
		for item in signal_node.find_children("*", "MeshInstance3D", true, false):
			for i in range(item.mesh.get_surface_count()):
				var m=item.mesh.surface_get_material(i)
				m.vertex_color_use_as_albedo=true
		await capture("signal-forced-vertex-albedo")
	signal_node.queue_free();await process_frame
	if not final_mode:
		var document=GLTFDocument.new();var state=GLTFState.new()
		var parse_result=document.append_from_file(OUT+"signal-explicit-factor.glb",state)
		assert(parse_result==OK)
		var explicit_node=document.generate_scene(state);stage.add_child(explicit_node)
		report["explicit_factor"]=material_report(explicit_node)
		await capture("signal-explicit-factor")
		explicit_node.queue_free();await process_frame
	else:
		for variant in ["rocks","rocks_low"]:
			var rocks_node=load("res://assets/models/"+variant+".glb").instantiate();stage.add_child(rocks_node)
			report[variant]=material_report(rocks_node)
			var children=rocks_node.find_children("rock_*","MeshInstance3D",true,false)
			for i in range(children.size()):children[i].position=Vector3((i%3-1)*1.3,0,(i/3)*1.4)
			camera.position=Vector3(3,3,5);camera.look_at(Vector3(0,.3,.7))
			await capture(variant)
			rocks_node.queue_free();await process_frame
		for key in ["signal","rocks","rocks_low"]:
			for m in report[key]:
				if str(m.material).begins_with("basalt"): assert(m.vertex_color_use_as_albedo)
	var rover=load("res://assets/models/rover.glb").instantiate();stage.add_child(rover)
	report["rover"]=material_report(rover)
	camera.fov=72;camera.near=.06;camera.position=Vector3(0,1.67,-.65);camera.rotation=Vector3(-.1,0,0)
	await capture("hood-original-1_67")
	camera.position=Vector3(0,1.40,-.43)
	await capture("hood-candidate-1_40")
	camera.position=Vector3(0,1.48,-.43)
	await capture("hood-candidate-1_48")
	report["runtime_material_overrides"]=not final_mode
	FileAccess.open(OUT+("probe-after.json" if final_mode else "probe.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ASSET_GODOT_PROBE_COMPLETE")
	quit()
