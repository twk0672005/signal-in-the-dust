extends SceneTree
var output := ""
var checks: Dictionary = {}
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output=arg.trim_prefix("--evidence-dir=")
	if output.is_empty(): quit(2); return
	run.call_deferred()
func tick(count: int) -> void:
	for i in count: await physics_frame
	await process_frame
func run() -> void:
	var game: Node3D=load("res://main.tscn").instantiate();root.add_child(game)
	await tick(10);game.start_expedition();game._set_phase("exploring");game.rover.set_driving_enabled(false)
	game.rover.global_position += Vector3(2.2,0,-4.5);game.rover.heading=0.47;game.elapsed=123.4;game.rover.distance_travelled=86.2;game.observed_ecology={"veyra":true};game.transmit_count=2
	game.save_expedition()
	checks.save_file_created=FileAccess.file_exists("user://expedition_state.json")
	var before: Dictionary=game.snapshot()
	game.rover.global_position=game.world.spawn_origin();game.elapsed=0.0;game.observed_ecology.clear();game.transmit_count=0
	checks.load_returns_true=game.load_expedition()
	var after: Dictionary=game.snapshot()
	checks.position_restored=before.position==after.position
	checks.heading_restored=is_equal_approx(float(before.heading),float(after.heading))
	checks.elapsed_restored=is_equal_approx(float(before.elapsed),float(after.elapsed))
	checks.distance_restored=is_equal_approx(float(before.distance),float(after.distance))
	checks.observations_restored=bool(game.observed_ecology.get("veyra",false)) and after.get("observedEcology",{}).get("veyra",false)
	checks.phase_resumed=after.phase=="exploring" and game.rover.driving
	game.reset_expedition()
	checks.reset_deletes_save=not FileAccess.file_exists("user://expedition_state.json")
	var passed:=true
	for value in checks.values(): passed=passed and bool(value)
	DirAccess.make_dir_recursive_absolute(output)
	var result={"passed":passed,"checks":checks,"kind":"native_save_resume_fixture_not_full_journey"}
	var file:=FileAccess.open(output.path_join("save-resume.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
	print("SAVE_RESUME_REGRESSION "+JSON.stringify(result))
	root.remove_child(game);game.free();await process_frame;await process_frame;quit(0 if passed else 1)
