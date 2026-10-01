extends SceneTree
const Save = preload("res://scripts/expedition_save.gd")
var output := ""
var checks: Dictionary = {}
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output=arg.trim_prefix("--evidence-dir=")
	if output.is_empty(): quit(2); return
	run.call_deferred()
func put(path: String, value: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE); file.store_string(value); file.close()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var game: Node3D = load("res://main.tscn").instantiate()
	game.save_path = output.path_join("isolated-save.json")
	Save.clear(game.save_path)
	checks.empty_slot_status=Save.status(game.save_path)=="absent"
	root.add_child(game)
	await physics_frame; await physics_frame
	game.start_expedition();game._set_phase("exploring")
	game.rover.set_driving_enabled(false)
	game.elapsed = 123.4; game.rover.heading = 0.47; game.rover.distance_travelled=86.2
	game.rover.set_camera_mode("third_person")
	game.observed_ecology={"veyra":true}
	var before: Dictionary=game.snapshot().duplicate(true)
	checks.atomic_save_succeeds = game.save_expedition()
	checks.valid_slot_status=Save.status(game.save_path)=="valid"
	checks.save_path_is_isolated = game.save_path.begins_with(output)
	game.elapsed=200.0
	checks.second_save_succeeds = game.save_expedition()
	checks.previous_generation_backed_up = Save.read(game.save_path+".bak").elapsed == 123.4
	put(game.save_path,"{truncated")
	checks.corrupt_primary_recovers_backup = Save.read(game.save_path).elapsed == 123.4
	checks.backup_counts_as_valid_slot=Save.status(game.save_path)=="valid"
	var path: String=game.save_path
	game.queue_free(); await create_timer(0.4).timeout
	# Save recovery remains internal; the player menu only starts new journeys.
	game=load("res://main.tscn").instantiate();game.save_path=path;root.add_child(game)
	await process_frame;await process_frame
	var button: Button=game.ui._root.find_child("ContinueSaved",true,false)
	checks.continue_button_removed=button == null
	game.load_expedition()
	checks.new_instance_restores_progress=game.phase=="exploring" and is_equal_approx(game.elapsed,123.4) and game.observed_ecology.get("veyra",false)
	checks.camera_and_counters_restored=game.rover.camera_mode=="third_person" and is_equal_approx(game.rover.distance_travelled,86.2) and is_equal_approx(game.rover.heading,0.47)
	checks.world_observations_consistent=game.world._observed_regions==game.observed_ecology
	checks.restored_motion_is_zero=game.rover.speed==0.0 and game.rover.velocity==Vector3.ZERO and game.rover.look_offset==Vector2.ZERO
	Save.clear(path)
	var valid: Dictionary={"version":1,"phase":"exploring","position":before.position,"heading":0.0,"elapsed":4.0,"distance":0.0,"observedEcology":{},"transmitCount":0}
	var invalids: Array=[null,[],{"version":1},valid.duplicate(true),valid.duplicate(true),valid.duplicate(true)]
	invalids[3].position.x=100000
	invalids[4].observedEcology=[]
	invalids[5].elapsed="wrong"
	var bad_escort: Dictionary=valid.duplicate(true)
	bad_escort.version=2;bad_escort.activities=game.activities.snapshot()
	bad_escort.activities.escort_state=game.escort.snapshot()
	bad_escort.activities.escort_state.position.x=9000.0
	invalids.append(bad_escort)
	bad_escort=valid.duplicate(true);bad_escort.version=2;bad_escort.activities=game.activities.snapshot()
	bad_escort.activities.escort_state=game.escort.snapshot();bad_escort.activities.escort_state.total=7
	invalids.append(bad_escort)
	var bad_passage: Dictionary=valid.duplicate(true)
	bad_passage.version=2;bad_passage.activities=game.activities.snapshot()
	bad_passage.activities.passage_state=game.passage.snapshot()
	bad_passage.activities.passage_state.route[0].x+=1.0
	invalids.append(bad_passage)
	var unchanged := true
	var position: Vector3=game.rover.position
	for value in invalids:
		put(path,JSON.stringify(value))
		unchanged = not game.load_expedition() and unchanged
		unchanged = game.rover.position==position and game.observed_ecology.get("veyra",false) and unchanged
	checks.invalid_files_leave_game_unchanged=unchanged
	Save.clear(path)
	put(path+".tmp",JSON.stringify(valid))
	checks.uncommitted_tmp_is_not_loaded=Save.read(path).is_empty()
	Save.clear(path);Save.write(path,valid)
	game._set_phase("menu");game.ui.set_saved_available(true)
	game.request_new_expedition()
	checks.new_run_requires_confirmation=game.ui._state=="confirm_new" and game.has_saved_expedition()
	game.reset_expedition()
	checks.confirmed_reset_clears_all_generations=not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".bak") and not FileAccess.file_exists(path+".tmp")
	# Simulate filesystem failures without changing permissions or touching player data.
	var copy_failure := output.path_join("copy-failure-%d.json" % Time.get_ticks_usec())
	put(copy_failure,JSON.stringify(valid))
	DirAccess.make_dir_recursive_absolute(copy_failure+".bak")
	var newer := valid.duplicate(true);newer.elapsed=88.0
	checks.backup_failure_keeps_primary = not Save.write(copy_failure,newer) and Save.read(copy_failure).elapsed==4.0
	var rename_failure := output.path_join("rename-failure-%d.json" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(rename_failure)
	put(rename_failure+".bak",JSON.stringify(valid))
	checks.rename_failure_keeps_backup = not Save.write(rename_failure,newer) and Save.read(rename_failure).elapsed==4.0
	# A blocked rename is visible to players without undoing the live optional activity.
	game._set_phase("exploring")
	game.passage.start()
	game.save_path=rename_failure
	checks.write_failure_reports_older_checkpoint=not game.save_expedition() and game.ui._message_key=="save_write_failed"
	checks.write_failure_allows_play=game.phase=="exploring" and game.passage.phase=="crossing"
	game.save_path=path
	Save.clear(path)
	put(path,"corrupt")
	checks.corrupt_slot_status=Save.status(path)=="unreadable"
	game.queue_free();await create_timer(0.4).timeout
	game=load("res://main.tscn").instantiate();game.save_path=path;root.add_child(game)
	await process_frame;await process_frame
	checks.corrupt_startup_shows_explanation = game.ui._save_invalid and not game.ui._saved_available
	Save.clear(path)

	var ok:=true
	for value in checks.values(): ok=ok and bool(value)
	var result: Dictionary={"passed":ok,"checks":checks,"kind":"isolated_native_save_flow_with_new_scene_instance_not_OS_relaunch"}
	put(output.path_join("save-flow.json"),JSON.stringify(result,"  "))
	print("SAVE_FLOW "+JSON.stringify(result))
	game.queue_free();await create_timer(0.5).timeout;quit(0 if ok else 1)
