extends "res://tests/combined_drive.gd"
var thermal_checks: Dictionary={}
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://main.tscn").instantiate();root.add_child(game);await create_timer(0.5).timeout
	if game.has_saved_expedition(): finish(false,"not_fresh");return
	await tap(KEY_ENTER)
	var deadline:=Time.get_ticks_msec()+10000
	while game.phase!="exploring" and Time.get_ticks_msec()<deadline: await frame()
	if game.phase!="exploring": finish(false,"start");return
	await tap(KEY_V)
	if not await follow_main(-90.0) or not await observe("veyra",0): finish(false,"observe_veyra");return
	if not await use_site("ember_rift") or not await use_site("ember_vent"): finish(false,"vent_approach");return
	await aim(game.activities.point("ember_vent"))
	deadline=Time.get_ticks_msec()+10000
	while game.world.thermal_pulse()>0.45 and Time.get_ticks_msec()<deadline: await frame()
	await tap(KEY_E)
	thermal_checks.low_pulse_rejected=not game.thermal.vent_observed
	await capture("thermal-unread")
	deadline=Time.get_ticks_msec()+10000
	while game.world.thermal_pulse()<0.85 and Time.get_ticks_msec()<deadline: await frame()
	await tap(KEY_E)
	thermal_checks.vent_observed=game.thermal.vent_observed
	await tap(KEY_E)
	thermal_checks.cool_chosen=game.thermal.route=="cool" and not game.thermal.locked
	await capture("thermal-cool-selected")
	await tap(KEY_ESCAPE)
	var pulse: float=game.world.thermal_pulse()
	await create_timer(0.35).timeout
	thermal_checks.pause_freezes_vent=game.phase=="paused" and game.world.thermal_pulse()==pulse
	game.queue_free();await create_timer(0.4).timeout
	game=load("res://main.tscn").instantiate();root.add_child(game);await create_timer(0.5).timeout
	await tap(KEY_ENTER)
	thermal_checks.unstarted_continue=game.phase=="exploring" and game.thermal.route=="cool" and game.thermal.vent_observed and game.escort.phase=="idle"
	await capture("thermal-choice-continued")
	if not await road_here() or not await follow_main(-95.0): finish(false,"return_veyra");return
	var animal: Node3D=game.world._ecology_nodes[0]
	if not await navigate(Vector2(animal.position.x,animal.position.z)+Vector2(0,8)): finish(false,"escort_approach");return
	for attempt in 30:
		await aim(Vector2(animal.position.x,animal.position.z))
		if game.interaction_target()=="escort": break
		await create_timer(0.3).timeout
	await tap(KEY_E)
	thermal_checks.started_and_locked=game.escort.phase!="idle" and game.thermal.locked
	if not thermal_checks.started_and_locked: finish(false,"cool_escort_start");return
	await capture("thermal-escort-start")
	deadline=Time.get_ticks_msec()+240000
	var continued:=false
	var sample_time:=0
	while game.escort.phase!="complete" and Time.get_ticks_msec()<deadline:
		if game.escort.travelled>95.0 and not continued:
			release_drive();await tap(KEY_ESCAPE)
			var saved: Dictionary=game.escort.snapshot()
			game.queue_free();await create_timer(0.4).timeout
			game=load("res://main.tscn").instantiate();root.add_child(game);await create_timer(0.5).timeout
			await tap(KEY_ENTER)
			thermal_checks.mid_continue=game.phase=="exploring" and game.thermal.route=="cool" and game.thermal.locked and game.escort.travelled>=float(saved.travelled)-0.1
			continued=true;await capture("thermal-mid-continued")
			await tap(KEY_V)
		var desired: Vector2=game.escort.position+Vector2(8,8)
		var offset:=desired-Vector2(game.rover.position.x,game.rover.position.z)
		var distance:=offset.length()
		var angle:=wrapf(atan2(offset.x,-offset.y)-game.rover.heading,-PI,PI)
		var wanted:=clampf((distance-1.0)*1.5,0,6.0)
		press(KEY_A,distance>1.0 and angle < -0.1);press(KEY_D,distance>1.0 and angle > 0.1)
		press(KEY_W,absf(angle)<0.6 and game.rover.speed<wanted and distance>1.0)
		press(KEY_SPACE,absf(angle)>0.9 or game.rover.speed>wanted+0.4 or distance<=1.0)
		if Time.get_ticks_msec()-sample_time>1000:
			checkpoint("cool_escort_"+game.escort.phase,false)
			samples.append({"rover":str(game.rover.position),"escort":game.escort.snapshot(),"speed":game.rover.speed})
			sample_time=Time.get_ticks_msec()
		await frame()
	release_drive();press(KEY_SPACE,true);await create_timer(0.5).timeout;press(KEY_SPACE,false)
	await create_timer(1.5).timeout
	thermal_checks.cool_completed=game.escort.phase=="complete" and game.activities.escort_complete
	thermal_checks.cool_bed_activated=game.world._cool_bed_material.emission_energy_multiplier>0.2
	thermal_checks.warm_bed_unchanged=game.world._shelter_material.emission_energy_multiplier<=0.2
	thermal_checks.herd_gathers=Vector2(game.world._ecology_nodes[1].position.x,game.world._ecology_nodes[1].position.z).distance_to(Vector2(-64,-143))<3.0
	thermal_checks.first_person=game.rover.camera_mode=="first_person"
	await aim(Vector2(-60,-145));await capture("thermal-cool-complete")
	await tap(KEY_ESCAPE)
	game.queue_free();await create_timer(0.4).timeout
	game=load("res://main.tscn").instantiate();root.add_child(game);await create_timer(0.5).timeout
	await tap(KEY_ENTER)
	thermal_checks.completed_continue=game.thermal.route=="cool" and game.thermal.locked and game.escort.phase=="complete" and game.world._cool_bed_material.emission_energy_multiplier>0.2
	await capture("thermal-completed-continue")
	await tap(KEY_R);await tap(KEY_TAB);await tap(KEY_ENTER)
	thermal_checks.reset_warm=game.phase=="arrival" and game.thermal.route=="warm" and not game.thermal.locked and not game.thermal.vent_observed and game.escort.phase=="idle"
	var passed:=true
	for v in thermal_checks.values(): passed=passed and bool(v)
	finish(passed,"thermal_cool_route_complete_continue_reset")
func finish(ok: bool, outcome: String) -> void:
	if finishing: return
	finishing=true;release_drive();checkpoint(outcome)
	var result={"passed":ok,"routePassed":ok,"fullRouteRequested":false,"checks":thermal_checks,"seconds":(Time.get_ticks_msec()-started)/1000.0,"stage":stage,"navigationFailure":navigation_failure,"visualCaptureStatus":"not_run_headless" if DisplayServer.get_name()=="headless" else ("captured" if ok and captures.size()==7 and captures.all(func(c):return c.status=="captured") else "incomplete"),"state":game.snapshot(),"samples":samples,"captures":captures,"kind":"physical_input_thermal_branch_with_real_Continue_no_teleport"}
	var f:=FileAccess.open(output.path_join("drive.json"),FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
	print("THERMAL_DRIVE "+JSON.stringify({"passed":ok,"stage":stage,"seconds":result.seconds,"checks":thermal_checks}))
	game.queue_free();await create_timer(0.5).timeout;quit(0 if ok else 1)
