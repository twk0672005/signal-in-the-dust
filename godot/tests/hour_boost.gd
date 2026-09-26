extends SceneTree

var output := ""
var checks: Dictionary = {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output = arg.trim_prefix("--evidence-dir=")
	run.call_deferred()

func run() -> void:
	if output.is_empty(): quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	var game = load("res://main.tscn").instantiate()
	game.save_path = output.path_join("boost-fixture-save.json")
	root.add_child(game)
	await physics_frame
	game.start_expedition()
	game._set_phase("exploring")
	game.rover.set_driving_enabled(true)
	var normal: float = game.rover.max_speed_mps()
	Input.action_press("drive_forward")
	Input.action_press("drive_boost")
	checks.forward_boost = game.rover.is_boosting() and game.rover.max_speed_mps() > normal
	await create_timer(0.6).timeout
	checks.boost_accelerates = game.rover.speed > 4.0
	Input.action_press("brake")
	checks.brake_cancels_boost = not game.rover.is_boosting()
	Input.action_release("brake")
	Input.action_release("drive_forward")
	Input.action_press("drive_reverse")
	checks.reverse_not_boosted = not game.rover.is_boosting()
	Input.action_release("drive_reverse")
	Input.action_press("drive_forward")
	game.pause_expedition()
	checks.pause_releases_boost = not Input.is_action_pressed("drive_boost") and game.rover.speed == 0.0
	game.resume_expedition()
	checks.resume_does_not_stick = not Input.is_action_pressed("drive_forward") and not game.rover.is_boosting()
	checks.shift_bound = InputMap.action_get_events("drive_boost").any(func(e): return e is InputEventKey and e.physical_keycode == KEY_SHIFT)
	var passed: bool = checks.values().all(func(x): return x == true)
	var receipt := {"kind":"native_input_fixture_not_browser", "passed":passed,"checks":checks}
	var file := FileAccess.open(output.path_join("boost-checks.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt,"  "))
	file.close()
	print(JSON.stringify(receipt))
	game.set_process(false)
	for player in game.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	await create_timer(0.15).timeout
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if passed else 1)
