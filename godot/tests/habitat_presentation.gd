extends SceneTree
var output := ""
var game: Node3D
var zones := [{"id":"aurora_shelf","z":80.0},{"id":"ember_rift","z":-90.0},{"id":"veil_marsh","z":-250.0},{"id":"pale_decay","z":-540.0}]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output=arg.trim_prefix("--evidence-dir=")
	if output.is_empty(): quit(2); return
	run.call_deferred()
func wait_frames(count: int) -> void:
	for i in count: await process_frame
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await wait_frames(12)
	game.start_expedition();game._set_phase("exploring");game.rover.set_driving_enabled(false);game.rover.set_camera_mode("third_person")
	for zone: Dictionary in zones:
		var z: float=zone.z
		var x: float=game.world.path_x(z)
		game.rover.global_position=Vector3(x,game.world.height_at(x,z)+0.45,z)
		game.rover.heading=0.0;game.rover.rotation=Vector3.ZERO
		game.world.set_player_state(game.rover.global_position,0.0)
		await wait_frames(18);await capture(zone.id)
	var f:=FileAccess.open(output.path_join("presentation.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"kind":"native_graphical_habitat_fixture_not_full_journey","zones":zones,"viewport":str(root.get_visible_rect().size)},"  "));f.close()
	print("HABITAT_PRESENTATION "+JSON.stringify(zones))
	game.queue_free();await process_frame;quit()
