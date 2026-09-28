extends Node3D

const ExpeditionSave = preload("res://scripts/expedition_save.gd")
const ShowcaseBoot = preload("res://scripts/showcase_boot.gd")
const WorldReview = preload("res://scripts/world_review.gd")
const ThermalScript = preload("res://scripts/thermal_route.gd")
const RootScript = preload("res://scripts/root_network.gd")
const PassageScript = preload("res://scripts/quiet_passage.gd")
const EscortScript = preload("res://scripts/quiet_escort.gd")
const ResonanceScript = preload("res://scripts/resonance_sequence.gd")
const ActivityScript = preload("res://scripts/expedition_activities.gd")
const RoverScript = preload("res://scripts/rover.gd")
const ContactScript = preload("res://scripts/contact.gd")
var _touch_callback: JavaScriptObject
var _web_launch_callback: JavaScriptObject
var _web_boot = ShowcaseBoot.new()
var _web_launch_pending := false
var _boot_timing_origin_usec: int = 0
var _boot_timing_timestamps_usec: Dictionary = {}
var _boot_timing_durations_usec: Dictionary = {}
var touch_enabled := false
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
var thermal: RefCounted
var root_network: RefCounted
var passage: RefCounted
var escort: RefCounted
var resonance: RefCounted
var _resonance_band := -1
var _resonance_flash := 0.0
var _resonance_feedback := ""
var activities: RefCounted
var _survey_message_seconds := 0.0

func _begin_boot_timings() -> void:
	_boot_timing_origin_usec = Time.get_ticks_usec()
	_boot_timing_timestamps_usec = {}
	_boot_timing_durations_usec = {}
	_boot_timing_mark("main_ready_enter")

func _boot_timing_mark(name: String) -> void:
	var timestamp_usec := Time.get_ticks_usec()
	_boot_timing_timestamps_usec[name] = timestamp_usec
	_boot_timing_durations_usec[name + "_from_main_ready"] = timestamp_usec - _boot_timing_origin_usec

func _boot_timing_mark_once(name: String) -> void:
	if not _boot_timing_timestamps_usec.has(name): _boot_timing_mark(name)

func _boot_timing_span(name: String, started_usec: int) -> void:
	var completed_usec := Time.get_ticks_usec()
	_boot_timing_timestamps_usec[name + "_start"] = started_usec
	_boot_timing_timestamps_usec[name + "_complete"] = completed_usec
	_boot_timing_durations_usec[name] = completed_usec - started_usec

func _publish_boot_timings() -> void:
	if not OS.has_feature("web"): return
	var payload := {
		"clock": "Time.get_ticks_usec() monotonic microseconds",
		"origin_usec": _boot_timing_origin_usec,
		"timestamps_usec": _boot_timing_timestamps_usec.duplicate(true),
		"durations_usec": _boot_timing_durations_usec.duplicate(true)
	}
	var source := "(() => { const current = window.__EXPEDITION_BOOT_TIMINGS__ || {}; const payload = " + JSON.stringify(payload) + "; const godot = Object.freeze({...payload, timestamps_usec:Object.freeze(payload.timestamps_usec), durations_usec:Object.freeze(payload.durations_usec)}); Object.defineProperty(window, '__EXPEDITION_BOOT_TIMINGS__', {value:Object.freeze({...current, godot}), writable:false, configurable:true, enumerable:true}); })();"
	JavaScriptBridge.eval(source, true)

func _ready() -> void:
	_begin_boot_timings()
	var local_review := WorldReview.enabled_in_browser()
	if local_review: save_path = "user://world-review-expedition.json"
	# Every native evidence run uses its own disposable save, never the player's slot.
	if save_path == SAVE_PATH:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--evidence-dir="):
				var directory := arg.trim_prefix("--evidence-dir=")
				DirAccess.make_dir_recursive_absolute(directory)
				save_path = directory.path_join("fixture-expedition.json")
	_install_inputs()
	if OS.has_feature("web"):
		touch_enabled = bool(JavaScriptBridge.eval("window.__EXPEDITION_TOUCH__ === true",true))
		if touch_enabled:
			get_tree().root.content_scale_size = Vector2i(840,390)
			_touch_callback = JavaScriptBridge.create_callback(_on_touch_action)
			JavaScriptBridge.get_interface("window").expeditionTouch = _touch_callback
	activities = ActivityScript.new()
	resonance = ResonanceScript.new()
	thermal = ThermalScript.new()
	root_network = RootScript.new()
	passage = PassageScript.new()
	escort = EscortScript.new()
	var world_new_started_usec := Time.get_ticks_usec()
	world = load("res://scripts/world.gd").new()
	_boot_timing_span("world_new_including_script_load", world_new_started_usec)
	var world_add_child_started_usec := Time.get_ticks_usec()
	add_child(world)
	_boot_timing_span("world_add_child", world_add_child_started_usec)
	escort.configure(_escort_route())
	if not passage.configure(world.passage_route()):
		push_error("Invalid authored passage route")
		return
	var rover_new_started_usec := Time.get_ticks_usec()
	rover = RoverScript.new()
	_boot_timing_span("rover_new", rover_new_started_usec)
	rover.configure(world)
	var rover_add_child_started_usec := Time.get_ticks_usec()
	add_child(rover)
	_boot_timing_span("rover_add_child", rover_add_child_started_usec)
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
	var ui_new_started_usec := Time.get_ticks_usec()
	ui = load("res://scripts/interface.gd").new()
	_boot_timing_span("ui_new_including_script_load", ui_new_started_usec)
	var ui_add_child_started_usec := Time.get_ticks_usec()
	add_child(ui)
	_boot_timing_span("ui_add_child", ui_add_child_started_usec)
	ui.start_requested.connect(request_new_expedition)
	ui.continue_saved_requested.connect(load_expedition)
	ui.resume_requested.connect(resume_expedition)
	ui.encounter_selected.connect(_on_encounter_selected)
	ui.reset_requested.connect(reset_expedition)
	ui.menu_requested.connect(_on_menu_requested)
	ui.explore_requested.connect(_continue_exploring)
	ui.interact_requested.connect(interact)
	ui.locale_changed.connect(_on_locale)
	ui.settings_changed.connect(_on_settings)
	var map_road := PackedVector2Array()
	for z in range(-670, 181, 8): map_road.append(Vector2(world.path_x(float(z)), float(z)))
	ui.set_map_road(map_road)
	_on_settings(ui.get_settings())
	ui.show_state("menu")
	audio.set_paused(true)
	if OS.has_feature("web"):
		await _warm_web_renderer()
	ready_for_play = true
	_boot_timing_mark("ready_for_play")
	_publish_boot_timings()
	var available := has_saved_expedition()
	var file_present := ExpeditionSave.exists(save_path)
	ui.set_saved_available(available, file_present and not available)
	_update_survey_readout()
	_publish_snapshot()
	print("EXPEDITION_READY")
	_install_web_launch()
	if local_review:
		var review := WorldReview.new()
		add_child(review)
		review.setup(self)

func _warm_web_renderer() -> void:
	# Real hidden-by-shell rendering, not a test-only time/filter adjustment.
	# Keep gameplay paused while the browser compiles first-use material variants.
	var warm_started := Time.get_ticks_usec()
	var original_camera := get_viewport().get_camera_3d()
	var original_paused: bool = world._paused
	var original_low := bool(settings.get("low_quality", false))
	world.set_paused(true)
	var warm_camera := Camera3D.new()
	warm_camera.name = "StartupMaterialWarmup"
	warm_camera.fov = 68.0
	warm_camera.far = 650.0
	warm_camera.near = 0.06
	add_child(warm_camera)
	var extra_started: int = 0
	var views := 0
	var capped := false
	for low in [false, true]:
		world.set_low_quality(low)
		rover.set_low_quality(low)
		for z in [125.0, -100.0, -275.0, -495.0]:
			if extra_started > 0 and Time.get_ticks_usec() - extra_started > 12000000:
				capped = true
				break
			var x: float = world.path_x(z)
			var h: float = world.height_at(x,z)
			warm_camera.position = Vector3(x+5.5,h+3.5,z+8.0)
			warm_camera.look_at(Vector3(world.path_x(z-24.0),h+2.6,z-24.0))
			warm_camera.current = true
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			views += 1
			if extra_started == 0: extra_started = Time.get_ticks_usec()
		if capped: break
	world.set_low_quality(original_low)
	rover.set_low_quality(original_low)
	if is_instance_valid(original_camera): original_camera.current = true
	else: exterior.current = true
	warm_camera.queue_free()
	world.set_paused(original_paused)
	_boot_timing_span("renderer_first_use_warmup", warm_started)
	_boot_timing_durations_usec["renderer_warmup_views"] = views
	_boot_timing_durations_usec["renderer_warmup_capped"] = 1 if capped else 0

func _install_web_launch() -> void:
	if not OS.has_feature("web"): return
	_web_launch_callback = JavaScriptBridge.create_callback(_on_web_launch)
	JavaScriptBridge.get_interface("window").expeditionLaunch = _web_launch_callback
	var serialized: Variant = JavaScriptBridge.eval("JSON.stringify(window.__EXPEDITION_BOOT_REQUEST__ || null)", true)
	if serialized is String and serialized.length() <= 8192:
		_begin_web_launch.call_deferred(JSON.parse_string(serialized))

func _on_web_launch(args: Array) -> void:
	if args.size() != 1 or not args[0] is String or args[0].length() > 8192: return
	_begin_web_launch.call_deferred(JSON.parse_string(args[0]))

func _begin_web_launch(value: Variant) -> void:
	if not ready_for_play: return
	var request: Dictionary = _web_boot.begin(value)
	if request.is_empty(): return
	if phase != "menu":
		_set_web_boot_stage("error")
		return
	_web_launch_pending = true
	ui.apply_startup_settings(request.settings)
	_publish_web_boot()
	if request.action == "continue":
		if not load_expedition():
			_web_launch_pending = false
			_set_web_boot_stage("continue-unavailable")
	else:
		request_new_expedition()
		if ui.current_state() == "confirm_new":
			_set_web_boot_stage("confirm-new")
		elif phase == "menu":
			_web_launch_pending = false
			_set_web_boot_stage("error")

func _set_web_boot_stage(value: String) -> void:
	_web_boot.set_stage(value)
	_publish_web_boot()
	if value in ["playing", "confirm-new"]:
		_web_boot_after_frame.call_deferred(_web_boot.request_id, value)

func _web_boot_after_frame(id: String, expected_stage: String) -> void:
	# Headless tests do not have a rendered frame and must not manufacture one.
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	if _web_boot.rendered(id, expected_stage):
		if expected_stage == "playing": _web_launch_pending = false
		_publish_web_boot()

func _publish_web_boot() -> void:
	if OS.has_feature("web") and not _web_boot.request_id.is_empty():
		JavaScriptBridge.eval("window.__EXPEDITION_BOOT_STATUS__=" + JSON.stringify(_web_boot.snapshot(_save_available)) + ";", true)

func _on_menu_requested() -> void:
	if phase != "menu": return
	_web_launch_pending = false
	if not _web_boot.request_id.is_empty(): _set_web_boot_stage("home")

func _on_touch_action(args: Array) -> void:
	if args.size() != 3 or not touch_enabled or not ready_for_play: return
	var action := str(args[0])
	if action == "pause_only":
		if phase in ["arrival","exploring","contact"]: pause_expedition()
		return
	if action not in ["drive_forward","drive_reverse","turn_left","turn_right","brake","drive_boost","toggle_camera","interact","expedition_journal","pause_mission","resonance_1","resonance_2","resonance_3"]: return
	var pressed := bool(args[1])
	if pressed and phase not in ["exploring","contact","arrival"]: return
	var strength := clampf(float(args[2]),0.0,1.0)
	if not is_finite(strength): return
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = strength
	Input.parse_input_event(event)

func _install_inputs() -> void:
	var bindings := {"drive_forward":[KEY_W,KEY_UP],"drive_reverse":[KEY_S,KEY_DOWN],"turn_left":[KEY_A,KEY_LEFT],"turn_right":[KEY_D,KEY_RIGHT],"brake":[KEY_SPACE],"drive_boost":[KEY_SHIFT],"toggle_camera":[KEY_V],"interact":[KEY_E],"expedition_journal":[KEY_J],"pause_mission":[KEY_ESCAPE],"restart_mission":[KEY_R],"resonance_1":[KEY_1],"resonance_2":[KEY_2],"resonance_3":[KEY_3]}
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

func start_expedition() -> bool:
	if not ready_for_play: return false
	if not clear_saved_expedition() and has_saved_expedition(): return false
	ui.reset_guidance()
	save_clock = 0.0
	elapsed = 0.0
	arrival_time = 0.0
	world_clock = 0.0
	transmit_count = 0
	observed_ecology.clear()
	activities.reset()
	resonance.reset()
	thermal.reset()
	escort.reset()
	escort.configure(_escort_route())
	passage.reset()
	root_network.reset()
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
	return true

func reset_expedition() -> void:
	if start_expedition():
		reset_count += 1
		_publish_snapshot()

func _set_phase(value: String) -> void:
	phase = value
	ui.show_state(phase)
	_publish_snapshot()
	if _web_launch_pending and phase in ["arrival", "exploring"]:
		_set_web_boot_stage("playing")

func _process(delta: float) -> void:
	if not ready_for_play: return
	ui.tick_guidance(delta)
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
		_update_passage(delta)
		world.set_wetland_study_state(_wetland_world_state())
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
			_boot_timing_mark_once("first_playable")
			_publish_boot_timings()
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
		# Web window blur is not consistently forwarded as application focus-out.
		# Consume the real DOM-event request on the engine frame, avoiding WASM re-entry.
		if OS.has_feature("web") and bool(JavaScriptBridge.eval("window.__EXPEDITION_FOCUS_LOST__ === true", true)):
			JavaScriptBridge.eval("window.__EXPEDITION_FOCUS_LOST__ = false;", true)
			pause_expedition()
		ui.update_readout(target_distance(), elapsed, contact.progress, can_interact(), rover.current_speed_mps(), rover.max_speed_mps(), rover.camera_mode, ecology_snapshot())
		_update_survey_readout()
		if phase == "exploring":
			ui.suggest_guidance(world.region_at(rover.global_position), ecology_snapshot())
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
	var tracked: String=activities.tracked_encounter
	if not tracked.is_empty() and _encounter_complete(tracked):
		activities.tracked_encounter=""
		tracked=""
	if tracked.is_empty() and region=="veil_marsh" and activities.wetland_study.prepared and not activities.field.marsh_pool:
		target="marsh_pool" if activities.wetland_study.recovered else "study_aeral"
	if not tracked.is_empty(): target="encounter_"+tracked
	var distance:=0.0
	var bearing:=0.0
	if not target.is_empty():
		var point: Vector2=ActivityScript.point(target) if tracked.is_empty() else _encounter_point(tracked)
		if target=="study_aeral":
			var animal: Vector3=world._ecology_nodes[4].global_position
			point=Vector2(animal.x,animal.z)
		distance=Vector2(rover.position.x,rover.position.z).distance_to(point)
		var offset: Vector2=point-Vector2(rover.position.x,rover.position.z)
		bearing=wrapf(atan2(offset.x,-offset.y)-rover.heading,-PI,PI)
	ui.set_activity_progress(activities.count(),activities.optional_count(),activities.field_count(),region,target,distance,activities.stillness,bearing)
	# Optional manual journal tracking earns one marker; the old mandatory task wall does not.
	var map_target := _encounter_point(tracked) if not tracked.is_empty() else Vector2.ZERO
	ui.set_navigation(Vector2(rover.position.x, rover.position.z), rover.heading, map_target, not tracked.is_empty())
	ui.set_resonance_context(_resonance_context())
	ui.set_escort_context(_escort_context())
	ui.set_passage_context(_passage_context())
	ui.set_root_network_context(_root_network_context())
	ui.set_thermal_context(_thermal_context())
	ui.set_wetland_context(_wetland_context())
	var journal: Dictionary={"tracked":activities.tracked_encounter,"entries":{}}
	for id in ActivityScript.REGIONS:
		journal.entries[id]={"discovered":activities.discovered[id],"complete":_encounter_complete(id)}
	ui.set_journal_context(journal)
	ui.set_interaction_kind(interaction_target())

func _nearby_survey() -> String:
	for id in ActivityScript.SITES:
		if activities.can_record(id,world.region_at(rover.position),rover.position,rover.speed,observed_ecology):
			if _target_visible(world.survey_position(id)+Vector3(0,1,0),world.get_node("Survey_"+id)): return id
	return ""


func _input(event: InputEvent) -> void:
	if not ready_for_play or event.is_echo(): return
	if event.is_action_pressed("pause_mission"):
		if phase == "paused" and ui.current_state() == "settings": ui.show_state("paused")
		elif phase in ["paused","confirm_reset"]: resume_expedition()
		elif phase in ["arrival","exploring","contact"]: pause_expedition()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("expedition_journal") and phase=="exploring":
		pause_expedition()
		_update_survey_readout()
		ui.show_state("journal")
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
	# Contact is optional. Preserve the last explorable position through its closing scene.
	if phase not in ["exploring", "contact", "ending"]: return false
	activities.thermal_state=thermal.snapshot()
	activities.escort_state=escort.snapshot()
	activities.passage_state=passage.snapshot()
	activities.root_network_state=root_network.snapshot()
	var payload := {"version":2,"phase":"exploring","position":{"x":rover.global_position.x,"y":rover.global_position.y,"z":rover.global_position.z},"heading":rover.heading,"elapsed":elapsed,"distance":rover.distance_travelled,"observedEcology":observed_ecology.duplicate(true),"activities":activities.snapshot(),"transmitCount":transmit_count,"view":rover.camera_mode}
	var success := ExpeditionSave.write(save_path,payload)
	if is_instance_valid(ui): ui.set_write_failed(not success)
	if success: _save_available = true
	elif is_instance_valid(ui):
		_survey_message_seconds=6.0
		ui.set_message("save_write_failed")
	return success

func has_saved_expedition() -> bool:
	_save_available = not ExpeditionSave.read(save_path).is_empty()
	return _save_available

func _resume_space_clear(position: Vector3, heading: float) -> bool:
	var collider: CollisionShape3D
	for child in rover.get_children():
		if child is CollisionShape3D:
			collider = child
			break
	if collider == null: return false
	var basis := Basis(Vector3.UP,-heading)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = Transform3D(basis,position) * collider.transform
	# Habitat solids have their own bit; resting contact with ordinary ground
	# must not relocate an otherwise unchanged save.
	query.collision_mask = 128
	query.exclude = [rover.get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	# Concave shapes can enclose the whole box. Physics flips backface ray normals,
	# so inspect original triangle winding, tracking each shape within a chunk.
	var cursor := position+Vector3.UP*.55
	var end := position+Vector3.UP*40.0
	var entered: Dictionary = {}
	for crossing in 32:
		var ray := PhysicsRayQueryParameters3D.create(cursor,end,128,[rover.get_rid()])
		ray.hit_back_faces = true
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty(): return true
		var body: CollisionObject3D = hit.collider
		var owner := body.shape_find_owner(int(hit.shape))
		var mesh := body.shape_owner_get_shape(owner,0) as ConcavePolygonShape3D
		var face: int = hit.get("face_index",-1)
		if mesh == null or face < 0: return false
		var vertices := mesh.get_faces()
		if face*3+2 >= vertices.size(): return false
		var transform := body.global_transform*body.shape_owner_get_transform(owner)
		var a: Vector3 = transform*vertices[face*3]
		var b: Vector3 = transform*vertices[face*3+1]
		var c: Vector3 = transform*vertices[face*3+2]
		var facing := (b-a).cross(c-a).y
		var key := str(body.get_instance_id())+":"+str(hit.shape)
		# Godot front faces wind clockwise: negative upward cross is an exit.
		var depth: int = int(entered.get(key,0))+(1 if facing>0 else -1)
		if depth < 0: return false
		entered[key] = depth
		cursor = (hit.position as Vector3)+Vector3.UP*.005
	return false # Conservatively reject unusually complex/unresolved enclosures.

func _free_resume_position(position: Vector3, heading: float) -> Variant:
	if _resume_space_clear(position,heading): return position
	# Only an obstructed legacy footprint moves; progress and saved bytes stay intact.
	var candidates: Array[Vector2] = []
	for radius in [1.5,3.0,6.0]:
		for i in 8:
			candidates.append(Vector2(position.x,position.z)+Vector2.from_angle(i*TAU/8.0)*radius)
	candidates.append(Vector2(world.path_x(position.z),position.z))
	for point in candidates:
		if absf(point.x)>94.0 or point.y < -670.0 or point.y > 180.0: continue
		var height: float = world.height_at(point.x,point.y)
		var ray := PhysicsRayQueryParameters3D.create(Vector3(point.x,height+1.0,point.y),Vector3(point.x,height-3.0,point.y),1,[rover.get_rid()])
		var floor_hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if floor_hit.is_empty() or (floor_hit.normal as Vector3).y < .7: continue
		var candidate: Vector3 = floor_hit.position+Vector3.UP*.08
		if _resume_space_clear(candidate,heading): return candidate
	return null

func load_expedition() -> bool:
	var parsed: Dictionary = ExpeditionSave.read(save_path)
	if parsed.is_empty():
		if phase == "menu": ui.set_saved_available(false,true)
		return false
	var point: Dictionary = parsed["position"]
	var position := Vector3(float(point.x),float(point.y),float(point.z))
	# Accept known old terrain within the authored revision area, without relaxing
	# validation elsewhere or changing any saved progression.
	var ground_y: float = world.height_at(position.x,position.z)
	var changed_terrain: bool = world.environment_terrain_changed_at(position.x,position.z)
	var valid_height := absf(position.y-ground_y) <= 5.0
	if changed_terrain:
		valid_height = valid_height or absf(position.y-world.legacy_height_at(position.x,position.z)) <= 5.0
	if not valid_height:
		if phase == "menu": ui.set_saved_available(false,true)
		return false
	if changed_terrain:
		# Find support at/below the old feet, without lifting a valid under-canopy
		# save onto its roof. New solids at this position use the clearance fallback.
		var from := Vector3(position.x,maxf(position.y,ground_y)+0.25,position.z)
		var to := Vector3(position.x,ground_y-3.0,position.z)
		var query := PhysicsRayQueryParameters3D.create(from,to,1,[rover.get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): ground_y = maxf(ground_y,(hit.position as Vector3).y)
		position.y = ground_y + 0.08
	var safe_position: Variant = _free_resume_position(position,float(parsed["heading"]))
	if safe_position == null: return false
	position = safe_position
	var restored_activities: RefCounted=ActivityScript.new()
	if not restored_activities.restore(parsed["activities"]): return false
	var restored_network: RefCounted=RootScript.new()
	if not restored_activities.root_network_state.is_empty():
		if not restored_network.restore(restored_activities.root_network_state): return false
	var restored_passage: RefCounted=PassageScript.new()
	if not restored_passage.configure(world.passage_route()): return false
	if not restored_activities.passage_state.is_empty():
		if not restored_passage.restore(restored_activities.passage_state): return false
	var restored_thermal: RefCounted=ThermalScript.new()
	if not restored_thermal.restore(restored_activities.thermal_state): return false
	var restored_escort: RefCounted=EscortScript.new()
	restored_escort.configure(_escort_route(restored_thermal.route))
	if restored_activities.escort_state.is_empty():
		restored_escort.reset(restored_activities.escort_complete)
	else:
		var saved_escort: Dictionary=restored_activities.escort_state
		var origin:=Vector2(saved_escort.origin.x,saved_escort.origin.z)
		var point_escort:=Vector2(saved_escort.position.x,saved_escort.position.z)
		if absf(point_escort.x)>94.0 or point_escort.y < -670.0 or point_escort.y>180.0: return false
		if saved_escort.phase not in ["idle","complete"] and origin.distance_to(_escort_route(restored_thermal.route)[0])>24.0: return false
		if not restored_escort.restore(saved_escort): return false
	rover.set_driving_enabled(false)
	rover.reset()
	world.reset()
	contact.reset()
	audio.reset()
	observed_ecology = parsed["observedEcology"].duplicate(true)
	activities=restored_activities
	world.set_wetland_study_state(_wetland_world_state(),true)
	resonance.reset(activities.resonance_complete)
	root_network=restored_network
	world.set_root_network_state(root_network.snapshot(),true)
	passage=restored_passage
	world.set_passage_state(passage.snapshot(),0.0,true)
	thermal=restored_thermal
	world.set_thermal_state(thermal.snapshot(),true)
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
	_boot_timing_mark_once("first_playable")
	_publish_boot_timings()
	return true

func clear_saved_expedition() -> bool:
	var cleared:=ExpeditionSave.clear(save_path)
	if not cleared:
		_save_available=has_saved_expedition()
		if is_instance_valid(ui):
			ui.set_clear_failed(_save_available)
			ui.set_write_failed(not _save_available)
		_survey_message_seconds=6.0
		if is_instance_valid(ui): ui.set_message("save_clear_failed" if _save_available else "save_write_failed")
		return false
	_save_available=false
	if is_instance_valid(ui):
		ui.set_clear_failed(false)
		ui.set_write_failed(false)
	return true

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
	if target_distance() <= 9.5 and _target_visible(contact.global_position+Vector3(0,2,0),contact):
		return "contact"
	var survey_id:=_nearby_survey()
	if not survey_id.is_empty(): return "survey:"+survey_id
	if _resonance_near() and not resonance.solved: return "resonance"
	if _thermal_near():
		if thermal.vent_observed: return "thermal_route"
		if world.thermal_pulse()>=0.75: return "thermal_observe"
	if _escort_can_start(): return "escort"
	if _passage_can_start(): return "passage"
	var root_target:=_root_network_interaction()
	if root_target!="none": return root_target
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
	if target.begins_with("root_relay:"):
		var index:=int(target.trim_prefix("root_relay:"))
		if root_network.turn(index): _root_network_changed(false,index)
		return
	if target=="root_pulse":
		if root_network.pulse(): _root_network_changed(true,0)
		return
	if target == "passage":
		if not passage.start(): return
		audio.play_transmit()
		save_expedition()
		_update_survey_readout()
		return
	if target in ["thermal_observe","thermal_route"]:
		var changed: bool=thermal.observe(world.thermal_pulse()) if target=="thermal_observe" else thermal.toggle_route()
		if changed:
			escort.configure(_escort_route())
			world.set_thermal_state(thermal.snapshot())
			audio.play_resonance(1 if thermal.route=="cool" else 0)
			_survey_message_seconds=4.0
			ui.set_message("thermal_read" if target=="thermal_observe" else "thermal_"+thermal.route)
			save_expedition()
			_update_survey_readout()
		return
	if target == "escort":
		var origin: Vector3=world._ecology_nodes[0].global_position
		if not escort.start(Vector2(origin.x,origin.z)): return
		thermal.lock_route()
		world.set_thermal_state(thermal.snapshot())
		save_expedition()
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
			var study_event: String=activities.wetland_study.observe(str(observed.get("kind","")),float(world._ecology_reactions[int(observed.index)].alert))
			ui.set_message("study_"+study_event if not study_event.is_empty() else "ecology_observed")
			if not study_event.is_empty():
				_survey_message_seconds=4.0
				audio.play_resonance(0 if study_event=="startled" else 2)
				save_expedition()
				_update_survey_readout()
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
	save_expedition()
	_set_phase("ending")

func _continue_exploring() -> void:
	if phase != "ending": return
	contact.reset()
	world.set_paused(false)
	audio.set_paused(false)
	rover.set_driving_enabled(true)
	_set_phase("exploring")
	save_expedition()

func _on_locale(value: String) -> void:
	settings["locale"] = value
	_publish_snapshot()

func _on_settings(value: Dictionary) -> void:
	settings = value.duplicate()
	rover.reduced_motion = bool(settings.get("reduced_motion",false))
	rover.set_low_quality(bool(settings.get("low_quality",false)))
	world.set_low_quality(bool(settings.get("low_quality",false)))
	audio.set_mix(float(settings.get("volume",0.5)))
	_publish_snapshot()

func snapshot() -> Dictionary:
	if not ready_for_play: return {"ready":false,"phase":phase}
	return {"ready":true,"touchEnabled":touch_enabled,"phase":phase,"position":{"x":rover.global_position.x,"y":rover.global_position.y,"z":rover.global_position.z},"heading":rover.heading,"speed":rover.speed,"speedMps":rover.current_speed_mps(),"speedKph":rover.current_speed_mps()*3.6,"maxSpeedMps":rover.max_speed_mps(),"boosting":rover.is_boosting(),"distance":rover.distance_travelled,"targetDistance":target_distance(),"elapsed":elapsed,"contactProgress":contact.progress,"transmitCount":transmit_count,"resetCount":reset_count,"view":rover.camera_mode,"camera":rover.camera_snapshot(),"ecology":ecology_snapshot(),"observedEcology":observed_ecology.duplicate(true),"activities":activities.snapshot(),"wetlandStudy":activities.wetland_study.snapshot(),"resonance":resonance.snapshot(),"escort":escort.snapshot(),"thermal":thermal.snapshot(),"thermalPulse":world.thermal_pulse(),"passage":passage.snapshot(),"rootNetwork":root_network.snapshot(),"activityCount":activities.count(),"floor":rover.is_on_floor(),"collisions":rover.last_collision_count,"settings":settings.duplicate(true),"saveAvailable":_save_available}

func ecology_snapshot() -> Dictionary:
	return {"veyra": world.ecology_state("veyra", rover.global_position), "aeral": world.ecology_state("aeral", rover.global_position), "rootChoir": world.ecology_state("root_choir", rover.global_position)}

func metrics() -> Dictionary:
	var ordered := frames.duplicate()
	ordered.sort()
	var count := ordered.size()
	return {"sampleFrames":count,"fps":Engine.get_frames_per_second(),"p50ms":ordered[int((count-1)*0.5)] if count else 0,"p95ms":ordered[int((count-1)*0.95)] if count else 0,"p99ms":ordered[int((count-1)*0.99)] if count else 0,"worstMs":ordered[count-1] if count else 0,"drawCalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"worldBuild":world.build_stats.duplicate(true),"viewport":str(get_viewport().get_visible_rect().size),"activityCount":activities.count(),"optionalCount":activities.optional_count(),"fieldCount":activities.field_count()}

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

func _escort_route(route_choice: String = "") -> Array[Vector2]:
	var selected: String=thermal.route if route_choice.is_empty() else route_choice
	if selected=="cool":
		return [Vector2(world.path_x(-105),-105),Vector2(-20,-95),Vector2(-48,-55),Vector2(-72,-65),Vector2(-74,-112),Vector2(-63,-145),Vector2(-60,-145)]
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
	data["route"]=thermal.route
	return data

func _update_escort(delta: float) -> void:
	if escort.tick(Vector2(rover.position.x,rover.position.z),rover.speed,delta):
		activities.escort_complete=true
		audio.play_transmit()
		_survey_message_seconds=4.0
		ui.set_message("escort_complete_cool" if thermal.route=="cool" else "escort_complete")
		save_expedition()
	world.set_escort_state(escort.snapshot())

func _passage_can_start() -> bool:
	if passage.phase!="idle" or absf(rover.speed)>=1.5: return false
	var gate: Node3D=world.get_node("QuietPassageGate0")
	return Vector2(rover.position.x-gate.position.x,rover.position.z-gate.position.z).length()<=14.0 and _target_visible(gate.position+Vector3(0,2,0),gate)

func _passage_context() -> Dictionary:
	if phase!="exploring" or world.region_at(rover.position)!="veil_marsh": return {}
	var data: Dictionary=passage.snapshot()
	var route: Array[Vector2]=world.passage_route()
	var target: Vector2=route[mini(passage.gate,route.size()-1)]
	var offset:=target-Vector2(rover.position.x,rover.position.z)
	data.distance=offset.length()
	data.bearing=wrapf(atan2(offset.x,-offset.y)-rover.heading,-PI,PI)
	return data

func _update_passage(delta: float) -> void:
	var event: String=passage.tick(Vector2(rover.position.x,rover.position.z),rover.speed,delta)
	if not event.is_empty():
		if event=="complete": activities.passage_complete=true
		if event in ["gate","complete"]: audio.play_resonance(2 if event=="complete" else 1)
		if event=="scattered": audio.play_resonance(0)
		_survey_message_seconds=3.0
		ui.set_message("passage_"+("complete" if event=="complete" else "scattered" if event=="scattered" else "gate"))
		save_expedition()
	world.set_passage_state(passage.snapshot())

func _root_network_interaction() -> String:
	if root_network.complete or absf(rover.speed)>=1.5: return "none"
	for index in 4:
		var landmark: Node3D=world.get_node("RootRelay"+str(index) if index<3 else "RootTerminal")
		var offset:=Vector2(landmark.position.x-rover.position.x,landmark.position.z-rover.position.z)
		if offset.length()<=8.0 and _target_visible(landmark.position+Vector3(0,2,0),landmark):
			if index<3: return "root_relay:"+str(index)
			if root_network.powered_count()==3: return "root_pulse"
	return "none"

func _root_network_context() -> Dictionary:
	if phase!="exploring" or world.region_at(rover.position)!="pale_decay": return {}
	var data: Dictionary=root_network.snapshot()
	var points: Array[Vector2]=world.root_network_points()
	var target: Vector2=points[root_network.powered_count()]
	var offset:=target-Vector2(rover.position.x,rover.position.z)
	data.distance=offset.length()
	data.bearing=wrapf(atan2(offset.x,-offset.y)-rover.heading,-PI,PI)
	data.near=-1
	for i in 3:
		if points[i].distance_to(Vector2(rover.position.x,rover.position.z))<=10: data.near=i
	return data

func _root_network_changed(complete: bool, index: int) -> void:
	world.set_root_network_state(root_network.snapshot())
	audio.play_resonance(2 if complete else root_network.ports[index])
	_survey_message_seconds=4.0
	ui.set_message("root_complete" if complete else "root_changed")
	save_expedition()
	_update_survey_readout()
	_publish_snapshot()

func _encounter_complete(region: String) -> bool:
	match region:
		"aurora_shelf": return resonance.solved
		"ember_rift": return escort.phase=="complete"
		"veil_marsh": return passage.phase=="complete"
		"pale_decay": return root_network.complete
	return false

func _encounter_point(region: String) -> Vector2:
	match region:
		"aurora_shelf": return ActivityScript.point("aurora_echo")
		"ember_rift":
			if observed_ecology.get("veyra",false) and not activities.completed.ember_rift: return ActivityScript.point("ember_rift")
			var animal: Vector3=world._ecology_nodes[0].global_position
			return Vector2(animal.x,animal.z)
		"veil_marsh": return world.passage_route()[mini(passage.gate,4)]
		"pale_decay": return world.root_network_points()[root_network.powered_count()]
	return Vector2.ZERO

func _on_encounter_selected(region: String) -> void:
	if phase!="paused": return
	if region!="" and (region not in ActivityScript.REGIONS or not activities.discovered.get(region,false) or _encounter_complete(region)): return
	activities.tracked_encounter=region
	resume_expedition()
	save_expedition()
	_update_survey_readout()

func _thermal_near() -> bool:
	if thermal.locked or escort.phase!="idle" or absf(rover.speed)>=1.5: return false
	var point: Vector3=world.survey_position("ember_vent")
	return Vector2(point.x-rover.position.x,point.z-rover.position.z).length()<=8.0 and _target_visible(point+Vector3(0,2,0),world.get_node("Survey_ember_vent"))

func _thermal_context() -> Dictionary:
	if phase!="exploring" or world.region_at(rover.position)!="ember_rift": return {}
	var data: Dictionary=thermal.snapshot()
	var offset: Vector2=ActivityScript.point("ember_vent")-Vector2(rover.position.x,rover.position.z)
	data.distance=offset.length()
	data.bearing=wrapf(atan2(offset.x,-offset.y)-rover.heading,-PI,PI)
	data.pulse=world.thermal_pulse()
	data.near=_thermal_near()
	return data

func _wetland_world_state() -> Dictionary:
	var data: Dictionary=activities.wetland_study.snapshot()
	data.complete=activities.field.marsh_pool
	return data

func _wetland_context() -> Dictionary:
	if phase!="exploring" or world.region_at(rover.position)!="veil_marsh": return {}
	var data:=_wetland_world_state()
	data.phase="complete" if data.complete else "return" if data.recovered else "quiet" if data.startled else "alarm" if data.prepared else "prepare"
	return data
