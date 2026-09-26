extends SceneTree
## Native graphical asset review, not a gameplay journey or Web performance proof.
var output := ""
var scene: Node3D
var camera: Camera3D
var creature: Node3D
var light: DirectionalLight3D
var environment: Environment
func _initialize() -> void:
	root.size = Vector2i(1440, 900)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output=arg.trim_prefix("--evidence-dir=")
	if output.is_empty(): quit(2);return
	run.call_deferred()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	scene=Node3D.new();root.add_child(scene)
	creature=load("res://scripts/creature_visual.gd").new()
	scene.add_child(creature);creature.configure("aeral")
	var ground:=MeshInstance3D.new()
	var plane:=PlaneMesh.new();plane.size=Vector2(60,60);ground.mesh=plane
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("42454b");mat.roughness=0.8;ground.material_override=mat;scene.add_child(ground)
	var rover:Node3D=(load("res://assets/models/rover.glb") as PackedScene).instantiate();rover.position=Vector3(-4,0,-1);scene.add_child(rover)
	environment=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("555d69")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color.WHITE;environment.ambient_light_energy=0.65
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var env:=WorldEnvironment.new();env.environment=environment;scene.add_child(env)
	light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-30,0);light.light_energy=1.5;light.shadow_enabled=true;scene.add_child(light)
	camera=Camera3D.new();scene.add_child(camera);camera.fov=48;camera.current=true
	var shots := [
		{"id":"neutral-front","pos":Vector3(10,7,-18),"target":Vector3(0,3,0)},
		{"id":"neutral-side","pos":Vector3(18,5,-1),"target":Vector3(0,3,0)},
		{"id":"neutral-back","pos":Vector3(-9,7,19),"target":Vector3(0,3,0)},
		{"id":"head-wing-close","pos":Vector3(4,4.6,-6),"target":Vector3(0,3,-0.9)},
		{"id":"night-front","pos":Vector3(10,7,-18),"target":Vector3(0,3,0)}]
	var captures:Array[Dictionary]=[]
	for shot in shots:
		if shot.id=="night-front":
			environment.background_color=Color("151b3a");environment.ambient_light_color=Color("6b83c0");environment.ambient_light_energy=0.7
			light.light_color=Color("b2c6ff");light.light_energy=1.7
		creature.pose(0.0,0.0,0.0)
		camera.position=shot.pos;camera.look_at(shot.target)
		for frame in 12: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(shot.id+".png"))
		captures.append({"id":shot.id,"camera":str(camera.position),"fov":camera.fov})
	var f:=FileAccess.open(output.path_join("receipt.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"kind":"native_graphical_asset_fixture","godot":Engine.get_version_info().string,"captures":captures,"viewport":str(root.size),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)},"  "));f.close()
	quit()
