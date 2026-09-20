extends SceneTree
var output := ""
var write_stage := false
var game: Node3D
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output=arg.trim_prefix("--evidence-dir=")
		if arg=="--write-save": write_stage=true
	if output.is_empty(): quit(2); return
	run.call_deferred()
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://main.tscn").instantiate()
	game.save_path=output.path_join("relaunch-save.json")
	root.add_child(game)
	await create_timer(0.3).timeout
	if write_stage:
		game.start_expedition();game._set_phase("exploring");game.rover.set_driving_enabled(false)
		var z := -250.0
		var x: float=game.world.path_x(z)
		game.rover.global_position=Vector3(x,game.world.height_at(x,z)+0.35,z)
		game.rover.set_camera_mode("third_person")
		game.observed_ecology={"veyra":true};game.elapsed=156.0;game.rover.distance_travelled=430.0
		var ok: bool=game.save_expedition()
		print("SAVE_WRITER "+JSON.stringify({"passed":ok,"pid":OS.get_process_id()}))
		game.queue_free();await create_timer(0.5).timeout;quit(0 if ok else 1);return
	await capture("continue-menu")
	var key := InputEventKey.new()
	key.physical_keycode=KEY_ENTER;key.keycode=KEY_ENTER;key.pressed=true;Input.parse_input_event(key)
	key=InputEventKey.new();key.physical_keycode=KEY_ENTER;key.keycode=KEY_ENTER;key.pressed=false;Input.parse_input_event(key)
	await create_timer(0.5).timeout
	await capture("continued-expedition")
	var state: Dictionary=game.snapshot()
	var ok: bool=game.phase=="exploring" and game.elapsed>=156.0 and game.elapsed<159.0 and game.rover.camera_mode=="third_person" and game.observed_ecology.get("veyra",false) and absf(game.rover.position.z+250.0)<0.1
	var result := {"passed":ok,"readerPid":OS.get_process_id(),"state":state,"kind":"native_separate_process_relaunch_and_enter_menu_action","viewport":str(root.get_visible_rect().size)}
	var file:=FileAccess.open(output.path_join("relaunch.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
	print("SAVE_RELAUNCH "+JSON.stringify(result))
	game.queue_free();await create_timer(0.5).timeout;quit(0 if ok else 1)
