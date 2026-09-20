extends SceneTree
var output := ""
var game: Node3D
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output=arg.trim_prefix("--evidence-dir=")
	if output.is_empty(): quit(2); return
	run.call_deferred()
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.5).timeout
	await capture("menu")
	game.start_expedition()
	await create_timer(6.0).timeout
	await capture("first-person")
	var key := InputEventKey.new()
	key.physical_keycode=KEY_V
	key.pressed=true
	Input.parse_input_event(key)
	key=InputEventKey.new()
	key.physical_keycode=KEY_V
	key.pressed=false
	Input.parse_input_event(key)
	await create_timer(0.4).timeout
	await capture("third-person")
	key=InputEventKey.new()
	key.physical_keycode=KEY_W
	key.pressed=true
	Input.parse_input_event(key)
	await create_timer(2.8).timeout
	var sample: Dictionary=game.snapshot()
	await capture("driving")
	key=InputEventKey.new()
	key.physical_keycode=KEY_W
	key.pressed=false
	Input.parse_input_event(key)
	var result: Dictionary={"kind":"native_graphical_fixture","state":sample,"speed_bar_pixels":game.ui._speed_bar.size.x,"viewport":str(root.get_visible_rect().size)}
	var file:=FileAccess.open(output.path_join("presentation.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "));file.close()
	print("PRESENTATION "+JSON.stringify(result))
	game.queue_free()
	await create_timer(0.4).timeout
	quit()
