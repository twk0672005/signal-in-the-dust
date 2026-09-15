extends Node3D

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

func _ready() -> void:
	_install_inputs()
	world = load("res://scripts/world.gd").new()
	add_child(world)
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
	ui.start_requested.connect(start_expedition)
	ui.resume_requested.connect(resume_expedition)
	ui.reset_requested.connect(reset_expedition)
	ui.interact_requested.connect(interact)
	ui.locale_changed.connect(_on_locale)
	ui.settings_changed.connect(_on_settings)
	_on_settings(ui.get_settings())
	ui.show_state("menu")
	audio.set_paused(true)
	ready_for_play = true
	_publish_snapshot()
	print("EXPEDITION_READY")

func _install_inputs() -> void:
	var bindings := {"drive_forward":[KEY_W,KEY_UP],"drive_reverse":[KEY_S,KEY_DOWN],"turn_left":[KEY_A,KEY_LEFT],"turn_right":[KEY_D,KEY_RIGHT],"brake":[KEY_SPACE],"interact":[KEY_E],"pause_mission":[KEY_ESCAPE],"restart_mission":[KEY_R]}
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
	elapsed = 0.0
	arrival_time = 0.0
	world_clock = 0.0
	transmit_count = 0
	reveal_audio_played = false
	rover.reset()
	rover.set_driving_enabled(false)
	contact.reset()
	world.reset()
	audio.reset()
	audio.set_paused(false)
	_place_exterior()
	exterior.current = true
	_set_phase("arrival")

func reset_expedition() -> void:
	reset_count += 1
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
	if phase == "arrival":
		arrival_time += delta
		var blend: float = smoothstep(1.8,5.5,arrival_time)
		var start: Vector3 = world.spawn_origin()
		exterior.global_position = (start+Vector3(5.5,3.2,5.8)).lerp(rover.camera.global_position,blend)
		var first_look: Vector3 = rover.camera.global_position+rover.view_direction()*20.0
		exterior.look_at((start+Vector3(0,0.85,-0.2)).lerp(first_look,blend))
		if arrival_time >= 5.5:
			rover.camera.current = true
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
		ui.update_readout(target_distance(),elapsed,contact.progress,can_interact())
		if phase == "exploring": ui.set_message("near" if target_distance()<20.0 else "signal_found")
		_publish_snapshot()

func _input(event: InputEvent) -> void:
	if not ready_for_play or event.is_echo(): return
	if event.is_action_pressed("pause_mission"):
		if phase in ["paused","confirm_reset"]: resume_expedition()
		elif phase in ["arrival","exploring","contact"]: pause_expedition()
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
	rover.set_driving_enabled(false)
	contact.paused = true
	audio.set_paused(true)

func pause_expedition() -> void:
	if phase not in ["arrival","exploring","contact"]: return
	previous_phase = phase
	_suspend()
	_set_phase("paused")

func resume_expedition() -> void:
	if phase not in ["paused","confirm_reset"]: return
	contact.paused = false
	audio.set_paused(false)
	rover.set_driving_enabled(previous_phase == "exploring")
	_set_phase(previous_phase)

func target_distance() -> float:
	return Vector2(rover.global_position.x-contact.global_position.x,rover.global_position.z-contact.global_position.z).length()

func can_interact() -> bool:
	if phase != "exploring" or target_distance() > 9.5: return false
	var target: Vector3 = contact.global_position+Vector3(0,2.0,0)-rover.camera.global_position
	var facing: float = rover.view_direction().dot(target.normalized())
	if facing < 0.55: return false
	var query := PhysicsRayQueryParameters3D.create(rover.camera.global_position,contact.global_position+Vector3(0,2.0,0))
	query.exclude = [rover.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or contact.is_ancestor_of(hit.get("collider"))

func interact() -> void:
	if not can_interact(): return
	transmit_count += 1
	rover.set_driving_enabled(false)
	audio.play_transmit()
	contact.begin()
	_set_phase("contact")
	ui.set_message("transmitting")

func _on_contact_completed() -> void:
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
	return {"ready":true,"phase":phase,"position":{"x":rover.global_position.x,"y":rover.global_position.y,"z":rover.global_position.z},"heading":rover.heading,"speed":rover.speed,"distance":rover.distance_travelled,"targetDistance":target_distance(),"elapsed":elapsed,"contactProgress":contact.progress,"transmitCount":transmit_count,"resetCount":reset_count,"view":"first_person" if rover.camera.current else "arrival_exterior","floor":rover.is_on_floor(),"collisions":rover.last_collision_count,"settings":settings}

func metrics() -> Dictionary:
	var ordered := frames.duplicate()
	ordered.sort()
	var count := ordered.size()
	return {"sampleFrames":count,"fps":Engine.get_frames_per_second(),"p50ms":ordered[int((count-1)*0.5)] if count else 0,"p95ms":ordered[int((count-1)*0.95)] if count else 0,"p99ms":ordered[int((count-1)*0.99)] if count else 0,"worstMs":ordered[count-1] if count else 0,"drawCalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"viewport":str(get_viewport().get_visible_rect().size)}

func _publish_snapshot() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__EXPEDITION_STATE__="+JSON.stringify(snapshot())+";window.__EXPEDITION_METRICS__="+JSON.stringify(metrics())+";document.body.dataset.phase="+JSON.stringify(phase)+";",true)
