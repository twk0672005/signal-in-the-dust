extends Node3D

const ExpeditionSave = preload("res://scripts/expedition_save.gd")
const EscortScript = preload("res://scripts/quiet_escort.gd")
const ResonanceScript = preload("res://scripts/resonance_sequence.gd")
const ActivityScript = preload("res://scripts/expedition_activities.gd")
const RoverScript = preload("res://scripts/rover.gd")
const ContactScript = preload("res://scripts/contact.gd")
var world: Node3D
var rover: CharacterBody3D
var contact: Node3D
var ui: CanvasLayer
var audio: Node
var exterior: Camera3D
var phase: String = "menu"
var previous_phase: String = "exploring"
var elapsed: float = 0.0
var arrival_time: float = 0.0
var readout_clock: float = 0.0
var world_clock: float = 0.0
var frames: Array[float] = []
var settings: Dictionary = {}
var transmit_count: int = 0
var reset_count: int = 0
var ready_for_play: bool = false
var reveal_audio_played: bool = false
var save_clock: float = 0.0
const SAVE_PATH := "user://expedition_state.json"
var save_path: String = SAVE_PATH
var _save_available := false
var observed_ecology: Dictionary = {}
var escort: RefCounted
var resonance: RefCounted
var _resonance_band := -1
var _resonance_flash := 0.0
var _resonance_feedback := ""
var activities: RefCounted
var _survey_message_seconds := 0.0

func _ready() -> void:
	# Every native evidence run uses its own disposable save, never the player's slot.
	if save_path == SAVE_PATH:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--evidence-dir="):
				var directory := arg.trim_prefix("--evidence-dir=")
				DirAccess.make_dir_recursive_absolute(directory)
				save_path = directory.path_join("fixture-expedition.json")
	_install_inputs()
	activities = ActivityScript.new()
	resonance = ResonanceScript.new()
	escort = EscortScript.new()
	world = load("res://scripts/world.gd").new()
	add_child(world)
	escort.configure(_escort_route())
	rover = RoverScript.new()
	rover.configure(world)
	add_child(rover)
	contact = ContactScript.new()
	contact.position = world.signal_origin()
	add_child(contact)
	contact.completed.connect(_on_contact_completed)
	exterior = Camera3D.new()
	exterior.fov = 57
	exterior.far = 650
	add_child(exterior)
	_place_exterior()
	exterior.current = true
	audio = load("res://scripts/expedition_audio.gd").new()
	add_child(audio)
	ui = load("res://scripts/interface.gd").new()
	add_child(ui)
	ui.start_requested.connect(request_new_expedition)
	ui.continue_saved_requested.connect(load_expedition)
	ui.resume_requested.connect(resume_expedition)
	ui.reset_requested.connect(reset_expedition)
	ui.interact_requested.connect(interact)
	ui.locale_changed.connect(_on_locale)
	ui.settings_changed.connect(_on_settings)
	_on_settings(ui.get_settings())
	ui.show_state("menu")
	audio.set_paused(true)
	ready_for_play = true
	var available := has_saved_expedition()
	var file_present := FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path+".bak")
	ui.set_saved_available(available, file_present and not available)
	_update_survey_readout()
	_publish_snapshot()
	print("EXPEDITION_READY")

func _install_inputs() -> void:
	var bindings := {"drive_forward":[KEY_W,KEY_UP],"drive_reverse":[KEY_S,KEY_DOWN],"turn_left":[KEY_A,KEY_LEFT],"turn_right":[KEY_D,KEY_RIGHT],"brake":[KEY_SPACE],"toggle_camera":[KEY_V],"interact":[KEY_E],"pause_mission":[KEY_ESCAPE],"restart_mission":[KEY_R],"resonance_1":[KEY_1],"resonance_2":[KEY_2],"resonance_3":[KEY_3]}
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			if not InputMap.action_has_event(action,event): InputMap.action_add_event(action,event)

func _place_exterior() -> void:
	var start: Vector3 = world.spawn_origin()
	exterior.global_position = start + Vector3(5.5,3.2,5.8)
	exterior.look_at(start+Vector3(0,0.85,-0.2))

func start_expedition() -> void:
	if not ready_for_play: return
	clear_saved_expedition()
	save_clock = 0.0
	elapsed = 0.0
	arrival_time = 0.0
	world_clock = 0.0
	transmit_count = 0
	observed_ecology.clear()
	activities.reset()
	resonance.reset()
	escort.reset()
	_resonance_flash=0.0
	_resonance_band=-1
	_resonance_feedback=""
	_survey_message_seconds=0.0
	reveal_audio_played = false
	rover.reset()
	rover.set_driving_enabled(false)
	contact.reset()
	world.reset()
	world.apply_survey_progress(activities.snapshot())
	audio.reset()
	audio.set_paused(false)
	_place_exterior()
	exterior.current = true
	_set_phase("arrival")

func reset_expedition() -> void:
	reset_count += 1
	clear_saved_expedition()
	start_expedition()

func _set_phase(value: String) -> void:
	phase = value
	ui.show_state(phase)
	_publish_snapshot()

func _process(delta: float) -> void:
	if not ready_for_play: return
	if delta > 0.0:
		frames.append(delta*1000.0)
		if frames.size() > 3600: frames.pop_front()
	var running: bool = phase in ["arrival","exploring","contact","ending"]
	if running:
		world_clock += delta
		if phase != "ending": elapsed += delta
		world.set_response(contact.progress,world_clock)
		world.set_player_state(rover.global_position, rover.speed)
		world.set_region_mood(world.region_at(rover.global_position),delta)
	if phase == "exploring":
		_update_resonance(delta)
		_update_escort(delta)
		var survey_events: Array = activities.tick(world.region_at(rover.global_position),rover.speed,observed_ecology,delta,rover.global_position)
		for id: String in survey_events: _survey_completed(id)
		_survey_message_seconds=maxf(0.0,_survey_message_seconds-delta)
		save_clock += delta
		if save_clock >= 10.0:
			save_clock = 0.0
			save_expedition()
	if phase == "arrival":
		arrival_time += delta
		var blend: float = smoothstep(1.8,5.5,arrival_time)
		var start: Vector3 = world.spawn_origin()
		var selected: Camera3D = rover.get_active_camera()
		exterior.global_position = (start+Vector3(5.5,3.2,5.8)).lerp(selected.global_position,blend)
		var first_look: Vector3 = selected.global_position+rover.view_direction()*20.0
		exterior.look_at((start+Vector3(0,0.85,-0.2)).lerp(first_look,blend))
		if arrival_time >= 5.5:
			rover.set_camera_mode(rover.camera_mode)
			rover.set_driving_enabled(true)
			_set_phase("exploring")
	elif phase == "contact":
		if contact.elapsed >= 6.0 and not reveal_audio_played:
			reveal_audio_played = true
			audio.play_reveal()
			ui.set_message("response")
	if running:
		audio.set_drive(rover.speed)
		audio.set_signal(target_distance())
	readout_clock += delta
	if readout_clock >= 0.15:
		readout_clock = 0.0
		ui.update_readout(target_distance(), elapsed, contact.progress, can_interact(), rover.current_speed_mps(), rover.max_speed_mps(), rover.camera_mode, ecology_snapshot())
		_update_survey_readout()
		if phase == "exploring" and _survey_message_seconds<=0.0:
			ui.set_message("survey_all" if activities.count()==4 and activities.field_count()==8 else ("field_guidance" if activities.count()==4 else "survey_guidance"))
		_publish_snapshot()

func _survey_completed(id: String) -> void:
	world.apply_survey_progress(activities.snapshot())
	audio.play_transmit()
	_survey_message_seconds=3.0
	ui.set_message("survey_recorded")
	ui.update_readout(target_distance(),elapsed,contact.progress,can_interact(),rover.current_speed_mps(),rover.max_speed_mps(),rover.camera_mode,ecology_snapshot())
	_update_survey_readout()
	save_expedition()

func _update_survey_readout() -> void:
	var region: String=world.region_at(rover.global_position)
	var target: String=activities.target(region)
	var distance:=0.0
	var bearing:=0.0
	if not target.is_empty():
		distance=Vector2(rover.position.x,rover.position.z).distance_to(ActivityScript.point(target))
		var offset: Vector2=ActivityScript.point(target)-Vector2(rover.position.x,rover.position.z)
		bearing=wrapf(atan2(offset.x,-offset.y)-rover.heading,-PI,PI)
	ui.set_activity_progress(activities.count(),activities.optional_count(),activities.field_count(),region,target,distance,activities.stillness,bearing)
	ui.set_resonance_context(_resonance_context())
	ui.set_escort_context(_escort_context())
	ui.set_interaction_kind(interaction_target())

func _nearby_survey() -> String:
	for id in ActivityScript.SITES:
		if activities.can_record(id,world.region_at(rover.position),rover.position,rover.speed,observed_ecology):
			if _target_visible(world.survey_position(id)+Vector3(0,1,0),world.get_node("Survey_"+id)): return id
	return ""


func _input(event: InputEvent) -> void:
	if not ready_for_play or event.is_echo(): return
	if event.is_action_pressed("pause_mission"):
		if phase in ["paused","confirm_reset"]: resume_expedition()
		elif phase in ["arrival","exploring","contact"]: pause_expedition()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_camera") and phase in ["exploring", "contact"]:
		rover.toggle_camera_mode()
		ui.set_view_message(rover.camera_mode)
		_publish_snapshot()
		get_viewport().set_input_as_handled()
	elif phase=="exploring" and _resonance_near() and (event.is_action_pressed("resonance_1") or event.is_action_pressed("resonance_2") or event.is_action_pressed("resonance_3")):
		var band:=0 if event.is_action_pressed("resonance_1") else (1 if event.is_action_pressed("resonance_2") else 2)
		_resonance_reply(band)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart_mission") and phase != "menu":
		if phase == "ending": reset_expedition()
		elif phase != "confirm_reset":
			if phase != "paused": previous_phase = phase
			_suspend()
			_set_phase("confirm_reset")
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo(): interact()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and ready_for_play and phase in ["arrival","exploring","contact"]:
		pause_expedition()

func _suspend() -> void:
	if phase in ["exploring", "contact"]: save_expedition()
	rover.set_driving_enabled(false)
	contact.paused = true
	world.set_paused(true)
	audio.set_paused(true)

func pause_expedition() -> void:
	if phase not in ["arrival","exploring","contact"]: return
	previous_phase = phase
	_suspend()
	_set_phase("paused")

func resume_expedition() -> void:
	if phase not in ["paused","confirm_reset"]: return
	contact.paused = false
	world.set_paused(false)
	audio.set_paused(false)
	rover.set_driving_enabled(previous_phase == "exploring")
	_set_phase(previous_phase)

func request_new_expedition() -> void:
	if phase == "menu" and has_saved_expedition():
		ui.show_state("confirm_new")
	else: start_expedition()

func save_expedition() -> bool:
	if phase != "exploring": return false
	activities.escort_state=escort.snapshot()
	var payload := {"version":2,"phase":"exploring","position":{"x":rover.global_position.x,"y":rover.global_position.y,"z":rover.global_position.z},"heading":rover.heading,"elapsed":elapsed,"distance":rover.distance_travelled,"observedEcology":observed_ecology.duplicate(true),"activities":activities.snapshot(),"transmitCount":transmit_count,"view":rover.camera_mode}
	var success := ExpeditionSave.write(save_path,payload)
	if success: _save_available = true
	return success

func has_saved_expedition() -> bool:
	_save_available = not ExpeditionSave.read(save_path).is_empty()
	return _save_available

func load_expedition() -> bool:
	var parsed: Dictionary = ExpeditionSave.read(save_path)
	if parsed.is_empty():
		if phase == "menu": ui.set_saved_available(false,true)
		return false
	var point: Dictionary = parsed["position"]
	var position := Vector3(float(point.x),float(point.y),float(point.z))
	# A file from another terrain revision must not put the player below the surface.
	if absf(position.y-world.height_at(position.x,position.z)) > 5.0:
		if phase == "menu": ui.set_saved_available(false,true)
		return false
	var restored_activities: RefCounted=ActivityScript.new()
	if not restored_activities.restore(parsed["activities"]): return false
	var restored_escort: RefCounted=EscortScript.new()
	restored_escort.configure(_escort_route())
	if restored_activities.escort_state.is_empty():
		restored_escort.reset(restored_activities.escort_complete)
	else:
		var saved_escort: Dictionary=restored_activities.escort_state
		var origin:=Vector2(saved_escort.origin.x,saved_escort.origin.z)
		var point_escort:=Vector2(saved_escort.position.x,saved_escort.position.z)
		if absf(point_escort.x)>94.0 or point_escort.y < -670.0 or point_escort.y>180.0: return false
		if saved_escort.phase not in ["idle","complete"] and origin.distance_to(_escort_route()[0])>24.0: return false
		if not restored_escort.restore(saved_escort): return false
	rover.set_driving_enabled(false)
	rover.reset()
	world.reset()
	contact.reset()
	audio.reset()
	observed_ecology = parsed["observedEcology"].duplicate(true)
	activities=restored_activities
	resonance.reset(activities.resonance_complete)
	escort=restored_escort
	world.set_escort_state(escort.snapshot(),true)
	_resonance_flash=0.0
	_resonance_band=-1
	_resonance_feedback=""
	world.apply_survey_progress(activities.snapshot())
	_survey_message_seconds=0.0
	world._observed_regions = observed_ecology.duplicate(true)
	transmit_count = int(parsed["transmitCount"])
	elapsed = float(parsed["elapsed"])
	world_clock = elapsed
	arrival_time = 0.0
	readout_clock = 0.0
	save_clock = 0.0
	reveal_audio_played = false
	previous_phase = "exploring"
	rover.distance_travelled = float(parsed["distance"])
	rover.global_position = position
	rover.heading = float(parsed["heading"])
	rover.rotation.y = -rover.heading
	rover.set_camera_mode(parsed.get("view","first_person"))
	world.set_player_state(position,0.0)
	rover.set_driving_enabled(true)
	audio.set_paused(false)
	_set_phase("exploring")
	return true

func clear_saved_expedition() -> void:
	ExpeditionSave.clear(save_path)
	_save_available = false

func target_distance() -> float:
	return Vector2(rover.global_position.x-contact.global_position.x,rover.global_position.z-contact.global_position.z).length()

func _target_visible(point: Vector3, allowed: Node = null) -> bool:
	var selected: Camera3D = rover.get_active_camera()
	var direction: Vector3 = point-selected.global_position
	if direction.length_squared() < 0.001: return true
	if rover.view_direction().dot(direction.normalized()) < 0.55: return false
	var query := PhysicsRayQueryParameters3D.create(selected.global_position,point)
	query.exclude = [rover.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or (allowed != null and allowed.is_ancestor_of(hit.get("collider")))

func interaction_target() -> String:
	if phase != "exploring" or absf(rover.speed) >= 2.0: return "none"
	if activities.count()==4 and activities.field_count()==8 and target_distance() <= 9.5 and _target_visible(contact.global_position+Vector3(0,2,0),contact):
		return "contact"
	var survey_id:=_nearby_survey()
	if not survey_id.is_empty(): return "survey:"+survey_id
	if _resonance_near() and not resonance.solved: return "resonance"
	if _escort_can_start(): return "escort"
	var ecology: Dictionary = world.nearest_ecology(rover.global_position)
	if not ecology.is_empty() and float(ecology.get("distance",999.0)) <= 14.0:
		var point: Vector3 = ecology.get("position",ecology["base"])
		if int(ecology.get("index",-1))==0 and escort.phase in ["travelling","alarmed","waiting"]: return "none"
		if _target_visible(point): return "ecology"
	return "none"

func can_interact() -> bool:
	return interaction_target() != "none"

func interact() -> void:
	var target := interaction_target()
	if target == "none": return
	if target.begins_with("survey:"):
		var id:=target.trim_prefix("survey:")
		if activities.record(id,world.region_at(rover.position),rover.position,rover.speed,observed_ecology):
			_survey_completed(id)
		return
	if target == "escort":
		var origin: Vector3=world._ecology_nodes[0].global_position
		escort.start(Vector2(origin.x,origin.z))
		audio.play_transmit()
		_update_survey_readout()
		return
	if target == "resonance":
		resonance.start()
		_resonance_feedback=""
		_update_survey_readout()
		return
	if target == "ecology":
		var observed: Dictionary = world.observe_ecology(rover.global_position)
		if not observed.is_empty():
			observed_ecology[str(observed.get("kind","unknown"))] = true
			activities.tick(world.region_at(rover.global_position),rover.speed,observed_ecology,0.0,rover.global_position)
			_update_survey_readout()
			ui.set_message("ecology_observed")
			_publish_snapshot()
		return
	save_expedition()
	transmit_count += 1
	rover.set_driving_enabled(false)
	audio.play_transmit()
	contact.begin()
	_set_phase("contact")
	ui.set_message("transmitting")

func _on_contact_completed() -> void:
	clear_saved_expedition()
	_set_phase("ending")

func _on_locale(value: String) -> void:
	settings["locale"] = value
	_publish_snapshot()

func _on_settings(value: Dictionary) -> void:
	settings = value.duplicate()
	rover.reduced_motion = bool(settings.get("reduced_motion",false))
	world.set_low_quality(bool(settings.get("low_quality",false)))
	audio.set_mix(float(settings.get("volume",0.5)))
	_publish_snapshot()

func snapshot() -> Dictionary:
	if not ready_for_play: return {"ready":false,"phase":phase}
	return {"ready":true,"phase":phase,"position":{"x":rover.global_position.x,"y":rover.global_position.y,"z":rover.global_position.z},"heading":rover.heading,"speed":rover.speed,"speedMps":rover.current_speed_mps(),"speedKph":rover.current_speed_mps()*3.6,"maxSpeedMps":rover.max_speed_mps(),"distance":rover.distance_travelled,"targetDistance":target_distance(),"elapsed":elapsed,"contactProgress":contact.progress,"transmitCount":transmit_count,"resetCount":reset_count,"view":rover.camera_mode,"camera":rover.camera_snapshot(),"ecology":ecology_snapshot(),"observedEcology":observed_ecology.duplicate(true),"activities":activities.snapshot(),"resonance":resonance.snapshot(),"escort":escort.snapshot(),"activityCount":activities.count(),"floor":rover.is_on_floor(),"collisions":rover.last_collision_count,"settings":settings.duplicate(true),"saveAvailable":_save_available}

func ecology_snapshot() -> Dictionary:
	return {"veyra": world.ecology_state("veyra", rover.global_position), "aeral": world.ecology_state("aeral", rover.global_position), "rootChoir": world.ecology_state("root_choir", rover.global_position)}

func metrics() -> Dictionary:
	var ordered := frames.duplicate()
	ordered.sort()
	var count := ordered.size()
	return {"sampleFrames":count,"fps":Engine.get_frames_per_second(),"p50ms":ordered[int((count-1)*0.5)] if count else 0,"p95ms":ordered[int((count-1)*0.95)] if count else 0,"p99ms":ordered[int((count-1)*0.99)] if count else 0,"worstMs":ordered[count-1] if count else 0,"drawCalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"viewport":str(get_viewport().get_visible_rect().size),"activityCount":activities.count(),"optionalCount":activities.optional_count(),"fieldCount":activities.field_count()}

func _publish_snapshot() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__EXPEDITION_STATE__="+JSON.stringify(snapshot())+";window.__EXPEDITION_METRICS__="+JSON.stringify(metrics())+";document.body.dataset.phase="+JSON.stringify(phase)+";",true)

func _resonance_in_grove() -> bool:
	return activities.done("aurora_echo") and absf(rover.speed)<1.5 and activities.near("aurora_echo",rover.global_position)

func _resonance_near() -> bool:
	return _resonance_in_grove() and (resonance.phase!="idle" or _target_visible(world.survey_position("aurora_echo")+Vector3(0,1,0),world.get_node("Survey_aurora_echo")))

func _resonance_context() -> Dictionary:
	if not _resonance_near(): return {}
	var data: Dictionary=resonance.snapshot()
	data["band"]=_resonance_band
	data["feedback"]=_resonance_feedback
	return data

func _update_resonance(delta: float) -> void:
	_resonance_flash=maxf(0.0,_resonance_flash-delta)
	if _resonance_flash<=0.0: _resonance_band=-1
	if _resonance_in_grove():
		for event: Dictionary in resonance.tick(delta):
			if event.kind=="tone":
				_resonance_band=int(event.band);_resonance_flash=0.5
				audio.play_resonance(_resonance_band)
	elif not resonance.solved and resonance.phase!="idle":
		resonance.reset();_resonance_feedback=""
	world.set_resonance_visual(_resonance_band,activities.resonance_complete,delta)

func _resonance_reply(band: int) -> void:
	var outcome: String=resonance.respond(band)
	if outcome=="ignored": return
	_resonance_feedback=outcome
	_resonance_band=band;_resonance_flash=0.35
	audio.play_resonance(band)
	if outcome=="solved":
		activities.resonance_complete=true
		_survey_message_seconds=4.0
		ui.set_message("resonance_solved")
		save_expedition()
	_update_survey_readout()
	_publish_snapshot()

func _escort_route() -> Array[Vector2]:
	var points: Array[Vector2]=[]
	# The animal first visits the northern warm seam, then crosses to the southern shelter.
	for z in [-105.0,-75.0,-45.0,-65.0,-90.0,-115.0,-140.0,-157.0]:
		points.append(Vector2(world.path_x(z),z))
	return points

func _escort_can_start() -> bool:
	if escort.phase!="idle" or activities.escort_complete or not activities.completed.ember_rift or not observed_ecology.get("veyra",false) or absf(rover.speed)>=1.5: return false
	var animal: Node3D=world._ecology_nodes[0]
	return rover.global_position.distance_to(animal.global_position)<=14.0 and world._ecology_reactions[0].alert<0.2 and _target_visible(animal.global_position+Vector3(0,0.45,0))

func _escort_context() -> Dictionary:
	if phase!="exploring": return {}
	if escort.phase=="complete" and world.region_at(rover.position)!="ember_rift": return {}
	if escort.phase=="idle" and not _escort_can_start(): return {}
	var data: Dictionary=escort.snapshot()
	var animal: Vector3=world._ecology_nodes[0].global_position
	data["distance"]=Vector2(animal.x-rover.position.x,animal.z-rover.position.z).length()
	return data

func _update_escort(delta: float) -> void:
	if escort.tick(Vector2(rover.position.x,rover.position.z),rover.speed,delta):
		activities.escort_complete=true
		audio.play_transmit()
		_survey_message_seconds=4.0
		ui.set_message("escort_complete")
		save_expedition()
	world.set_escort_state(escort.snapshot())
