extends "res://tests/combined_drive.gd"
var study_checks: Dictionary={}
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://main.tscn").instantiate();root.add_child(game);await create_timer(0.5).timeout
	if game.has_saved_expedition():finish(false,"not_fresh");return
	await tap(KEY_ENTER)
	var deadline:=Time.get_ticks_msec()+10000
	while game.phase!="exploring" and Time.get_ticks_msec()<deadline:await frame()
	if game.phase!="exploring":finish(false,"start");return
	await tap(KEY_V)
	if not await follow_main(-210.0) or not await use_site("marsh_reed"):finish(false,"sampler_approach");return
	study_checks.sampler_prepared=game.activities.wetland_study.prepared and game.activities.field.marsh_reed
	await capture("study-sampler")
	if not await study_aeral_pair(true):finish(false,"paired_observation");return
	study_checks.both_samples=game.activities.wetland_study.startled and game.activities.wetland_study.recovered
	await tap(KEY_ESCAPE)
	var clock: float=game.world._world_time
	await create_timer(0.35).timeout
	study_checks.pause_freezes=game.phase=="paused" and game.world._world_time==clock
	game.queue_free();await create_timer(0.4).timeout
	game=load("res://main.tscn").instantiate();root.add_child(game);await create_timer(0.5).timeout
	await tap(KEY_ENTER)
	study_checks.paired_continue=game.phase=="exploring" and game.activities.wetland_study.recovered and not game.activities.field.marsh_pool
	var center: Vector2=game.world._wetland_center()
	var shore:=center+Vector2(9,8)
	if not await road_here() or not await follow_main(-342.0) or not await navigate(shore):finish(false,"pool_approach");return
	await aim(center);await capture("study-pool-before")
	study_checks.pool_not_yet_open=game.world._wetland_open==0.0
	if not await navigate(Vector2(game.world.path_x(-330),-330)) or not await use_site("marsh_pool"):finish(false,"pool_validation");return
	await create_timer(2.2).timeout
	study_checks.field_validated=game.activities.field.marsh_pool and game.world._wetland_open>0.95
	if not await navigate(shore):finish(false,"pool_return");return
	await aim(center);await capture("study-pool-after-third")
	await tap(KEY_V);await capture("study-pool-after-first")
	study_checks.first_person=game.rover.camera_mode=="first_person"
	await tap(KEY_ESCAPE)
	game.queue_free();await create_timer(0.4).timeout
	game=load("res://main.tscn").instantiate();root.add_child(game);await create_timer(0.5).timeout
	await tap(KEY_ENTER)
	study_checks.completed_continue=game.phase=="exploring" and game.activities.field.marsh_pool and game.world._wetland_open>0.95
	await capture("study-completed-continue")
	await tap(KEY_R);await tap(KEY_TAB);await tap(KEY_ENTER)
	study_checks.reset_clears=game.phase=="arrival" and not game.activities.wetland_study.prepared and not game.activities.field.marsh_pool and game.world._wetland_open==0
	var passed:=true
	for value in study_checks.values():passed=passed and bool(value)
	finish(passed,"wetland_pair_complete_continue_reset")
func finish(ok: bool,outcome: String) -> void:
	if finishing:return
	finishing=true;release_drive();checkpoint(outcome)
	var result={"passed":ok,"routePassed":ok,"fullRouteRequested":false,"checks":study_checks,"seconds":(Time.get_ticks_msec()-started)/1000.0,"stage":stage,"navigationFailure":navigation_failure,"state":game.snapshot(),"samples":samples,"captures":captures,"visualCaptureStatus":"not_run_headless" if DisplayServer.get_name()=="headless" else ("captured" if ok and captures.size()==7 and captures.all(func(c):return c.status=="captured") else "incomplete"),"kind":"physical_input_wetland_pair_with_Continue_no_teleport"}
	var f:=FileAccess.open(output.path_join("drive.json"),FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close();print("WETLAND_DRIVE "+JSON.stringify({"passed":ok,"seconds":result.seconds,"stage":stage,"checks":study_checks}));game.queue_free();await create_timer(0.5).timeout;quit(0 if ok else 1)
