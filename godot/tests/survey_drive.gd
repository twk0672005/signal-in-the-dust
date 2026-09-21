extends SceneTree
var game: Node3D
var output := ""
var held: Dictionary={}
var samples: Array[Dictionary]=[]
var started:=0
var full_route := false
var stage := "boot"
var finishing := false
var captures: Array[Dictionary] = []
var total_deadline := 0
var timeout_ms := 900000
var navigation_failure := ""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output=arg.trim_prefix("--evidence-dir=")
		if arg=="--full-route": full_route=true
		if arg.begins_with("--timeout-ms="): timeout_ms=maxi(100,arg.trim_prefix("--timeout-ms=").to_int())
	if output.is_empty(): quit(2);return
	started=Time.get_ticks_msec()
	total_deadline=started+timeout_ms
	run.call_deferred()
func _process(_delta: float) -> bool:
	if Time.get_ticks_msec()>total_deadline and not finishing:
		finishing=true
		release_drive()
		DirAccess.make_dir_recursive_absolute(output)
		var f:=FileAccess.open(output.path_join("drive.json"),FileAccess.WRITE)
		f.store_string(JSON.stringify({"passed":false,"routePassed":false,"stage":"total_timeout_"+stage,"fullRouteRequested":full_route,"seconds":(Time.get_ticks_msec()-started)/1000.0,"state":game.snapshot() if is_instance_valid(game) else {},"captures":captures}));f.close()
		print("DRIVE_TIMEOUT "+stage)
		# Quit synchronously without freeing nodes underneath suspended route coroutines.
		quit(1)
		return true
	return false
func checkpoint(value: String, announce: bool = true) -> void:
	stage=value
	var f:=FileAccess.open(output.path_join("progress.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"stage":stage,"seconds":(Time.get_ticks_msec()-started)/1000.0,"state":game.snapshot()}));f.close()
	if announce: print("DRIVE_STAGE "+stage)
func press(code: int, down: bool) -> void:
	if held.get(code,false)==down: return
	held[code]=down
	var event:=InputEventKey.new()
	event.physical_keycode=code;event.keycode=code;event.pressed=down
	Input.parse_input_event(event)
func release_drive() -> void:
	for key in [KEY_W,KEY_A,KEY_D,KEY_SPACE]: press(key,false)
func frame() -> void:
	await physics_frame
	await process_frame
func navigate(point: Vector2) -> bool:
	checkpoint("navigate_"+str(point))
	var deadline:=Time.get_ticks_msec()+45000
	var last_sample:=0
	var last_movement:=Time.get_ticks_msec()
	var anchor: Vector3=game.rover.position
	while Time.get_ticks_msec()<deadline:
		if game.phase!="exploring":
			navigation_failure="phase_"+game.phase
			release_drive();return false
		if game.rover.position.distance_to(anchor)>0.25:
			anchor=game.rover.position;last_movement=Time.get_ticks_msec()
		elif Time.get_ticks_msec()-last_movement>10000:
			navigation_failure="no_position_progress"
			release_drive();return false
		var here:=Vector2(game.rover.position.x,game.rover.position.z)
		var distance:=here.distance_to(point)
		if distance<4.5:
			press(KEY_W,false);press(KEY_A,false);press(KEY_D,false);press(KEY_SPACE,true)
			for i in 35: await frame()
			release_drive();return true
		var direction:=point-here
		var desired:=atan2(direction.x,-direction.y)
		var angle:=wrapf(desired-game.rover.heading,-PI,PI)
		var speed: float=game.rover.speed
		var wanted:=minf(12.0,distance*0.65)
		press(KEY_A,angle < -0.075)
		press(KEY_D,angle > 0.075)
		press(KEY_W,absf(angle)<0.5 and speed<wanted)
		press(KEY_SPACE,absf(angle)>0.7 or speed>wanted+1.0)
		if Time.get_ticks_msec()-last_sample>1000:
			samples.append({"position":str(game.rover.position),"distanceToWaypoint":distance,"speed":speed})
			last_sample=Time.get_ticks_msec()
			checkpoint(stage,false)
		await frame()
	release_drive();return false
func aim(point: Vector2) -> void:
	for i in 240:
		var direction:=point-Vector2(game.rover.position.x,game.rover.position.z)
		var angle:=wrapf(atan2(direction.x,-direction.y)-game.rover.heading,-PI,PI)
		if absf(angle)<0.08: break
		press(KEY_A,angle < 0);press(KEY_D,angle > 0)
		await frame()
	release_drive()
func capture(name: String) -> void:
	checkpoint("capture_"+name)
	if DisplayServer.get_name()=="headless":
		captures.append({"name":name,"status":"skipped_headless"})
		return
	await RenderingServer.frame_post_draw
	var error:=root.get_texture().get_image().save_png(output.path_join(name+".png"))
	captures.append({"name":name,"status":"captured" if error==OK else "write_failed","error":error})
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.4).timeout
	var resumed: bool = game.has_saved_expedition()
	if resumed:
		push_error("Use a fresh evidence directory for an uninterrupted journey")
		quit(2);return
	press(KEY_ENTER,true);await frame();press(KEY_ENTER,false)
	started=Time.get_ticks_msec()
	var deadline:=started+10000
	while game.phase!="exploring" and Time.get_ticks_msec()<deadline: await frame()
	if game.phase!="exploring": finish(false,"start_menu");return
	press(KEY_V,true);await frame();press(KEY_V,false)
	if not resumed:
		var ok:=true
		for z in [120.0,100.0]:
			ok=await navigate(Vector2(game.world.path_x(z),z))
			if not ok: finish(false,"main_approach");return
		var core: Vector2=game.activities.point("aurora_shelf")
		if not await navigate(core): finish(false,"survey_approach");return
		await create_timer(3.3).timeout
		await capture("required-survey")
		if not game.activities.completed.aurora_shelf: finish(false,"quiet_survey");return
		for p in [Vector2(game.world.path_x(95),95),Vector2(-42,95),game.activities.point("aurora_echo")]:
			if not await navigate(p): finish(false,"branch_approach");return
		await aim(game.activities.point("aurora_echo"))
		await capture("optional-before")
		press(KEY_E,true);await frame();press(KEY_E,false)
		await create_timer(0.3).timeout
		await capture("optional-after")
		if not game.activities.optional.aurora_echo: finish(false,"first_optional");return
		for p in [Vector2(-42,95),Vector2(game.world.path_x(95),95)]:
			if not await navigate(p): finish(false,"return_to_main");return
	if not full_route: finish(true,"complete");return
	if not await record_fields("aurora_shelf"): finish(false,"fields_aurora");return
	for row in [
		{"region":"ember_rift","kind":"veyra","node":0,"approach":-90.0,"side":"ember_vent"},
		{"region":"veil_marsh","kind":"aeral","node":4,"approach":-265.0,"side":"marsh_crossing"},
		{"region":"pale_decay","kind":"root_choir","node":9,"approach":-450.0,"side":"spore_pulse"}
	]:
		if game.activities.completed[row.region] and game.activities.optional[row.side]: continue
		print("DRIVE_REGION "+str(row.region))
		if not await follow_main(float(row.approach)): finish(false,"road_"+row.region);return
		var organism: Node3D=game.world._ecology_nodes[int(row.node)]
		var organism_point:=Vector2(organism.position.x,organism.position.z)
		if not await navigate(organism_point+Vector2(0,6)): finish(false,"organism_"+row.region);return
		for retry in 24:
			await create_timer(0.35).timeout
			if game.world.ecology_state(row.kind,game.rover.position)=="disturbed": continue
			await aim(Vector2(organism.position.x,organism.position.z))
			if game.interaction_target()=="ecology":
				press(KEY_E,true);await frame();press(KEY_E,false)
			if game.observed_ecology.get(row.kind,false): break
		if not game.observed_ecology.get(row.kind,false): finish(false,"observe_"+row.region);return
		var required: Vector2=game.activities.point(row.region)
		if not await navigate(required): finish(false,"required_"+row.region);return
		await aim(required)
		press(KEY_E,true);await frame();press(KEY_E,false)
		if not game.activities.completed[row.region]: finish(false,"record_"+row.region);return
		await capture(row.region+"-required")
		var side: Vector2=game.activities.point(row.side)
		if not await navigate(side): finish(false,"optional_"+row.region);return
		await aim(side)
		press(KEY_E,true);await frame();press(KEY_E,false)
		if not game.activities.optional[row.side]: finish(false,"record_"+row.side);return
		await capture(row.side+"-completed")
		if not await navigate(Vector2(game.world.path_x(side.y),side.y)): finish(false,"return_"+row.region);return
		press(KEY_V,true);await frame();press(KEY_V,false)
		if not await record_fields(row.region): finish(false,"fields_"+row.region);return
	if not await follow_main(-620.0): finish(false,"final_approach");return
	var end: Vector3=game.world.signal_origin()
	if not await navigate(Vector2(end.x,end.z+4)): finish(false,"final_site");return
	await aim(Vector2(end.x,end.z))
	press(KEY_E,true);await frame();press(KEY_E,false)
	if game.phase!="contact": finish(false,"final_contact");return
	await create_timer(25.0).timeout
	await capture("ending")
	finish(game.phase=="ending" and game.activities.count()==4 and game.activities.optional_count()==4 and game.activities.field_count()==8,"full_route_complete")
func record_fields(region: String) -> bool:
	for id in game.activities.FIELD:
		if game.activities.SITES[id].region!=region or game.activities.done(id): continue
		var point: Vector2=game.activities.point(id)
		# Return to the road at the current latitude before changing latitude.
		var z: float=game.rover.position.z
		if not await navigate(Vector2(game.world.path_x(z),z)): return false
		if not await follow_main(point.y): return false
		if not await navigate(point): return false
		await aim(point)
		press(KEY_E,true);await frame();press(KEY_E,false)
		if not game.activities.done(id): return false
		await capture(id)
	return true
func follow_main(z: float) -> bool:
	var here: float=game.rover.position.z
	while absf(here-z)>30:
		here+=signf(z-here)*30
		if not await navigate(Vector2(game.world.path_x(here),here)): return false
	return await navigate(Vector2(game.world.path_x(z),z))
func finish(ok: bool, outcome_stage: String) -> void:
	if finishing: return
	finishing=true
	checkpoint(outcome_stage)
	release_drive()
	var result={"passed":ok,"routePassed":ok,"fullRouteRequested":full_route,"navigationFailure":navigation_failure,"visualCaptureStatus":"not_run_headless" if DisplayServer.get_name()=="headless" else ("failed" if captures.any(func(c): return c.status!="captured") else "captured"),"stage":stage,"seconds":(Time.get_ticks_msec()-started)/1000.0,"state":game.snapshot(),"samples":samples,"captures":captures,"rendering":DisplayServer.get_name(),"kind":"native_injected_keyboard_uninterrupted_route_no_teleport_not_independent_human"}
	var f:=FileAccess.open(output.path_join("drive.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(result,"  "));f.close()
	print("SURVEY_DRIVE "+JSON.stringify({"passed":ok,"stage":stage,"seconds":result.seconds,"state":result.state}))
	game.queue_free();await create_timer(0.5).timeout;quit(0 if ok else 1)

