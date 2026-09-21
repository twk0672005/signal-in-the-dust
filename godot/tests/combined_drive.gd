extends "res://tests/survey_drive.gd"
var milestones: Array[Dictionary]=[]
var combined_checks: Dictionary={}

func _initialize() -> void:
	super._initialize()
	full_route=true
	timeout_ms=1800000
	total_deadline=started+timeout_ms

func mark(name: String) -> void:
	milestones.append({"name":name,"seconds":(Time.get_ticks_msec()-started)/1000.0,"distance":game.rover.distance_travelled})
	checkpoint(name)

func tap(code: int) -> void:
	press(code,true);await frame();press(code,false)
	await create_timer(0.18).timeout

func use_site(id: String) -> bool:
	var point: Vector2=game.activities.point(id)
	if not await navigate(point): return false
	await aim(point);await tap(KEY_E)
	return game.activities.done(id)

func observe(kind: String, index: int) -> bool:
	var organism: Node3D=game.world._ecology_nodes[index]
	if not await navigate(Vector2(organism.position.x,organism.position.z)+Vector2(0,6)): return false
	for retry in 30:
		await create_timer(0.35).timeout
		if game.world.ecology_state(kind,game.rover.position)=="disturbed": continue
		await aim(Vector2(organism.position.x,organism.position.z))
		if game.interaction_target()=="ecology": await tap(KEY_E)
		if game.observed_ecology.get(kind,false): return true
	return false

func resonance_encounter() -> bool:
	await tap(KEY_E)
	await capture("combined-aurora-listening")
	for sequence in [[KEY_1,KEY_3,KEY_2],[KEY_2,KEY_1,KEY_3,KEY_2],[KEY_3,KEY_2,KEY_1,KEY_3,KEY_1]]:
		if not await await_answer(): return false
		for code in sequence: await tap(code)
	await create_timer(1.8).timeout
	await capture("combined-aurora-complete")
	return game.resonance.solved

func escort_encounter() -> bool:
	var animal: Node3D=game.world._ecology_nodes[0]
	if not await follow_main(-95.0): return false
	if not await navigate(Vector2(animal.position.x,animal.position.z)+Vector2(0,8)): return false
	for retry in 30:
		await aim(Vector2(animal.position.x,animal.position.z))
		if game.interaction_target()=="escort": break
		await create_timer(0.3).timeout
	await tap(KEY_E)
	if game.escort.phase=="idle": return false
	await capture("combined-ember-start")
	var deadline:=Time.get_ticks_msec()+180000
	var last_sample:=0
	while game.escort.phase!="complete" and Time.get_ticks_msec()<deadline:
		var desired: Vector2=game.escort.position+Vector2(8,8)
		var offset:=desired-Vector2(game.rover.position.x,game.rover.position.z)
		var distance:=offset.length()
		var angle:=wrapf(atan2(offset.x,-offset.y)-game.rover.heading,-PI,PI)
		var wanted:=clampf((distance-1.0)*1.5,0,6.0)
		press(KEY_A,distance>1.0 and angle < -0.1)
		press(KEY_D,distance>1.0 and angle > 0.1)
		press(KEY_W,absf(angle)<0.6 and game.rover.speed<wanted and distance>1.0)
		press(KEY_SPACE,absf(angle)>0.9 or game.rover.speed>wanted+0.4 or distance<=1.0)
		if Time.get_ticks_msec()-last_sample>1000:
			checkpoint("combined_escort_"+game.escort.phase,false)
			last_sample=Time.get_ticks_msec()
		await frame()
	release_drive();press(KEY_SPACE,true);await create_timer(0.5).timeout;press(KEY_SPACE,false)
	await capture("combined-ember-complete")
	return game.escort.phase=="complete"

func passage_encounter() -> bool:
	var route: Array[Vector2]=game.world.passage_route()
	if not await follow_main(-215.0): return false
	if not await navigate(route[0]+Vector2(0,8),4.0): return false
	await aim(route[0]);await tap(KEY_E)
	if game.passage.phase!="crossing": return false
	await capture("combined-veil-start")
	for point in route:
		if not await navigate(point,4.0): return false
		if game.passage.phase=="scattered": return false
	await create_timer(1.0).timeout
	await capture("combined-veil-complete")
	return game.passage.phase=="complete"

func roots_encounter() -> bool:
	var points: Array[Vector2]=game.world.root_network_points()
	if not await follow_main(-390.0): return false
	for i in 3:
		if not await follow_main(points[i].y): return false
		if not await navigate(points[i]): return false
		await aim(points[i])
		await tap(KEY_E)
		if i==1: await tap(KEY_E)
		if game.root_network.powered_count()!=i+1: return false
		await capture("combined-pale-relay-"+str(i))
		var z: float=game.rover.position.z
		if not await navigate(Vector2(game.world.path_x(z),z)): return false
	if not await follow_main(points[3].y): return false
	if not await navigate(points[3]): return false
	await aim(points[3]);await tap(KEY_E)
	await create_timer(2.0).timeout
	await capture("combined-pale-crown")
	return game.root_network.complete

func road_here() -> bool:
	var z: float=game.rover.position.z
	# An off-road echo returns around the visible membrane bank, not through its collider.
	if game.world.region_at(game.rover.position)=="veil_marsh":
		for gate: Vector2 in game.world.passage_route():
			if absf(z-gate.y)<10.0:
				z=gate.y+14.0
				if not await navigate(Vector2(game.rover.position.x,z)): return false
				break
	return await navigate(Vector2(game.world.path_x(z),z))

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(0.4).timeout
	if game.has_saved_expedition(): finish(false,"not_fresh");return
	await tap(KEY_ENTER)
	var deadline:=Time.get_ticks_msec()+10000
	while game.phase!="exploring" and Time.get_ticks_msec()<deadline: await frame()
	if game.phase!="exploring": finish(false,"start");return
	await tap(KEY_V);mark("arrival_complete")
	for z in [120.0,100.0]:
		if not await navigate(Vector2(game.world.path_x(z),z)): finish(false,"aurora_approach");return
	if not await navigate(game.activities.point("aurora_shelf")): finish(false,"aurora_required");return
	await create_timer(3.3).timeout
	if not game.activities.done("aurora_shelf"): finish(false,"aurora_quiet");return
	for point in [Vector2(game.world.path_x(95),95),Vector2(-42,95)]:
		if not await navigate(point): finish(false,"aurora_branch");return
	if not await use_site("aurora_echo"): finish(false,"aurora_echo");return
	if not await resonance_encounter(): finish(false,"aurora_resonance");return
	for point in [Vector2(-42,95),Vector2(game.world.path_x(95),95)]:
		if not await navigate(point): finish(false,"aurora_return");return
	if not await record_fields("aurora_shelf"): finish(false,"aurora_fields");return
	mark("aurora_complete")
	if not await follow_main(-90.0) or not await observe("veyra",0): finish(false,"ember_observe");return
	if not await use_site("ember_rift"): finish(false,"ember_required");return
	if not await use_site("ember_vent") or not await road_here(): finish(false,"ember_echo");return
	if not await record_fields("ember_rift"): finish(false,"ember_fields");return
	if not await escort_encounter() or not await road_here(): finish(false,"ember_escort");return
	mark("ember_complete")
	if not await follow_main(-210.0) or not await use_site("marsh_reed"): finish(false,"veil_sampler");return
	if not await study_aeral_pair(): finish(false,"veil_pair");return
	if not await use_site("veil_marsh"): finish(false,"veil_required");return
	if not await use_site("marsh_crossing") or not await road_here(): finish(false,"veil_echo");return
	if not await record_fields("veil_marsh"): finish(false,"veil_fields");return
	await tap(KEY_V)
	if not await passage_encounter() or not await road_here(): finish(false,"veil_passage");return
	mark("veil_complete")
	if not await follow_main(-450.0) or not await observe("root_choir",9): finish(false,"pale_observe");return
	if not await use_site("pale_decay"): finish(false,"pale_required");return
	if not await use_site("spore_pulse") or not await road_here(): finish(false,"pale_echo");return
	if not await record_fields("pale_decay"): finish(false,"pale_fields");return
	if not await roots_encounter() or not await road_here(): finish(false,"pale_roots");return
	mark("pale_complete")
	combined_checks.all_encounters=game.resonance.solved and game.escort.phase=="complete" and game.passage.phase=="complete" and game.root_network.complete
	combined_checks.all_sixteen_sites=game.activities.count()==4 and game.activities.optional_count()==4 and game.activities.field_count()==8
	combined_checks.all_species=game.observed_ecology.size()==3
	combined_checks.first_person=game.rover.camera_mode=="first_person"
	if not await follow_main(-620.0): finish(false,"final_approach");return
	var end: Vector3=game.world.signal_origin()
	if not await navigate(Vector2(end.x,end.z+4)): finish(false,"final_site");return
	await aim(Vector2(end.x,end.z));await tap(KEY_E)
	if game.phase!="contact": finish(false,"final_contact");return
	await create_timer(25.0).timeout
	await capture("combined-ending")
	combined_checks.ending=game.phase=="ending"
	mark("ending_complete")
	var passed:=true
	for value in combined_checks.values(): passed=passed and bool(value)
	finish(passed,"combined_complete")

func finish(ok: bool, outcome_stage: String) -> void:
	if finishing: return
	finishing=true
	release_drive();checkpoint(outcome_stage)
	var result={"passed":ok,"routePassed":ok,"fullRouteRequested":true,"combinedRoute":true,"checks":combined_checks,"milestones":milestones,"navigationFailure":navigation_failure,"visualCaptureStatus":"not_run_headless" if DisplayServer.get_name()=="headless" else ("captured" if ok and captures.size()==21 and captures.all(func(c): return c.status=="captured") else "incomplete"),"stage":stage,"seconds":(Time.get_ticks_msec()-started)/1000.0,"state":game.snapshot(),"samples":samples,"captures":captures,"rendering":DisplayServer.get_name(),"kind":"native_physical_key_events_continuous_all_encounters_and16sites_no_teleport_no_load_no_human"}
	var file:=FileAccess.open(output.path_join("drive.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "));file.close()
	print("COMBINED_DRIVE "+JSON.stringify({"passed":ok,"stage":stage,"seconds":result.seconds,"checks":combined_checks}))
	game.queue_free();await create_timer(0.5).timeout;quit(0 if ok else 1)
