extends SceneTree
var output := ""
var world: Node3D
var records: Array[Dictionary] = []
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output = arg.trim_prefix("--evidence-dir=")
	if output.is_empty(): quit(2); return
	run.call_deferred()
func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))
func advance(seconds: float) -> void:
	for i in int(round(seconds * 60.0)): world._process(1.0/60.0)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	world = load("res://scripts/world.gd").new()
	root.add_child(world)
	world.set_process(false)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.fov = 48
	for index in [0, 4, 9]:
		world.reset()
		var base: Vector3 = world._ecology_meta[index]["base"]
		var kind: String = world._ecology_meta[index]["kind"]
		camera.position = base + Vector3(6,4,11)
		camera.look_at(base + Vector3(0,0.5,0))
		await capture(kind + "-calm")
		world.set_player_state(base + Vector3(0,0,8), 8.0)
		advance(2.0)
		await capture(kind + "-disturbed")
		records.append({"kind":kind,"reaction":world.reaction_snapshot()[index],"position":str(world._ecology_nodes[index].position),"scale":str(world._ecology_nodes[index].scale)})
		world.set_player_state(base + Vector3(0,0,8), 0.0)
		advance(8.0)
		world.observe_ecology(world._ecology_nodes[index].position)
		advance(1.0)
		await capture(kind + "-observed")
	var result := {"kind":"native_graphical_stimulus_fixture_not_real_input", "records":records,"viewport":str(root.get_visible_rect().size)}
	var file := FileAccess.open(output.path_join("presentation.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "));file.close()
	print("ECOLOGY_PRESENTATION " + JSON.stringify(result))
	world.queue_free(); camera.queue_free()
	await process_frame
	quit()
