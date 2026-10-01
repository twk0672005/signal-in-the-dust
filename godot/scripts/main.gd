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
const RuntimeSurface = preload("res://scripts/runtime_surface.gd")
signal _boot_browser_resumed
var _boot_yield_callback: JavaScriptObject
var _boot_completed_steps := 0
var _boot_work_started_usec := 0
var _touch_callback: JavaScriptObject
var _web_launch_callback: JavaScriptObject
var _web_boot = ShowcaseBoot.new()
var _web_launch_pending := false
var _boot_timing_origin_usec: int = 0
var _boot_timing_timestamps_usec: Dictionary = {}
var _boot_timing_durations_usec: Dictionary = {}
var _boot_preparation: Dictionary = {}
var _runtime_surface: Node
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
var _save_state := "unknown"
var _save_write_failed := false
var _shown_interaction: Dictionary = {}
var _interaction_options: Array[Dictionary] = []
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
	_boot_work_started_usec = _boot_timing_origin_usec
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

func _set_boot_preparation(value: String, completed: int = -1, total: int = -1) -> void:
	if value not in ["world", "materials", "first-view"]: return
	_boot_preparation = {"version":1, "phase":value}
	if completed >= 0 and total >= completed:
		_boot_preparation["completed"] = completed
		_boot_preparation["total"] = total
	if OS.has_feature("web"):
		JavaScriptBridge.eval("Object.defineProperty(window, '__EXPEDITION_PREPARATION__', {value:Object.freeze(" + JSON.stringify(_boot_preparation) + "), writable:false, configurable:true, enumerable:true});", true)

func boot_browser_yield() -> void:
	if not OS.has_feature("web"):
		await get_tree().process_frame
		return
	if _boot_yield_callback == null:
		_boot_yield_callback = JavaScriptBridge.create_callback(func(_args): _boot_browser_resumed.emit())
		JavaScriptBridge.get_interface("window").expeditionBootYield = _boot_yield_callback
	_boot_completed_steps += 1
	JavaScriptBridge.eval("window.__EXPEDITION_BOOT_PROGRESS__=%d;" % _boot_completed_steps, true)
	# A zero-delay continuation can outrun already-due input/paint timers after a
	# slow shader compile. Leave a real idle interval only after expensive work.
	var idle_ms := 60 if Time.get_ticks_usec()-_boot_work_started_usec >= 500000 else 0
	JavaScriptBridge.eval("setTimeout(() => window.expeditionBootYield(), %d);" % idle_ms, true)
	await _boot_browser_resumed
	_boot_work_started_usec = Time.get_ticks_usec()

func _ready() -> void:
	_begin_boot_timings()
	_set_boot_preparation("world")
	var local_review := WorldReview.enabled_in_browser()
	if local_review: save_path = "user://world-review-expedition.json"
	# Every native evidence run uses its own disposable save, never the player's slot.
	if save_path == SAVE_PATH:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--evidence-dir="):
				var directory := arg.trim_prefix("--evidence-dir=")
				DirAccess.make_dir_recursive_absolute(directory)
				save_path = directory.path_join("fixture-expedition.json")
	_save_state = ExpeditionSave.status(save_path)
	_save_available = _save_state == "valid"
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
	world.staged_boot = OS.has_feature("web")
	world.boot_frame_yield = boot_browser_yield
	add_child(world)
	_boot_timing_span("world_add_child", world_add_child_started_usec)
	if world.staged_boot:
		var build_started := Time.get_ticks_usec()
		await world.build_world()
		_boot_timing_span("world_incremental_build", build_started)
		_boot_timing_durations_usec["world_max_cpu_slice"] = int(world.build_stats.get("boot_max_cpu_slice_ms", 0.0)*1000.0)
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
	var initial_settings: Dictionary = ui.get_settings()
	initial_settings.merge(_read_web_launch_request().get("settings", {}), true)
	_on_settings(initial_settings)
	ui.show_state("menu")
	audio.set_paused(true)
	var surface_started := Time.get_ticks_usec()
	_runtime_surface = RuntimeSurface.new()
	add_child(_runtime_surface)
	_runtime_surface.bind_scene(self)
	_boot_timing_span("shared_surface_adaptation",surface_started)
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

func _warm_material_key(material: Material) -> String:
	if material == null: return "default"
	if material is ShaderMaterial: return str(material.shader.get_instance_id()) if material.shader != null else "default"
	# StandardMaterial shader features are flags/enums and texture presence.
	# Uniform colors/scalars do not need a separate compile for every authored tint.
	var features: Array = [material.get_class()]
	for property in material.get_property_list():
		if not (int(property.usage) & PROPERTY_USAGE_STORAGE): continue
		var value: Variant = material.get(property.name)
		if value is bool or value is int: features.append([property.name,value])
		elif value is Texture2D: features.append([property.name,true])
	return str(features)

func _warm_material_plan() -> Array[Dictionary]:
	var groups: Dictionary = {}
	var material_keys: Dictionary = {}
	var omni_lights := find_children("*", "OmniLight3D", true, false)
	for raw in find_children("*", "GeometryInstance3D", true, false):
		var node := raw as GeometryInstance3D
		var materials: Array[Material] = []
		if node.material_override != null: materials.append(node.material_override)
		elif node is MeshInstance3D and node.mesh != null:
			for surface in node.mesh.get_surface_count(): materials.append(node.get_active_material(surface))
		elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
			for surface in node.multimesh.mesh.get_surface_count(): materials.append(node.multimesh.mesh.surface_get_material(surface))
		elif node is CPUParticles3D and node.mesh != null:
			for surface in node.mesh.get_surface_count(): materials.append(node.mesh.surface_get_material(surface))
		if node.material_overlay != null: materials.append(node.material_overlay)
		var seen: Dictionary = {}
		while not materials.is_empty():
			var material: Material = materials.pop_back()
			var id := material.get_instance_id() if material != null else 0
			if seen.has(id): continue
			seen[id] = true
			if not material_keys.has(id): material_keys[id] = _warm_material_key(material)
			var key: String = material_keys[id]
			if not groups.has(key): groups[key] = {"material":material,"mesh":false,"instanced":false,"omni":false}
			groups[key]["instanced" if node is MultiMeshInstance3D or node is CPUParticles3D else "mesh"] = true
			if not groups[key].omni: groups[key].omni = _warm_omni_reachable(node, omni_lights)
			if material != null and material.next_pass != null: materials.append(material.next_pass)
	var plan: Array[Dictionary] = []
	for group in groups.values(): plan.append(group)
	return plan

func _warm_omni_reachable(node: GeometryInstance3D, lights: Array[Node]) -> bool:
	if lights.is_empty(): return false
	# Moving actors and unknown instance bounds retain every local-light variant.
	if not node.is_inside_tree() or not node is MeshInstance3D or node.mesh == null: return true
	if is_instance_valid(rover) and rover.is_ancestor_of(node): return true
	if is_instance_valid(world):
		for actor in world._ecology_nodes:
			if actor == node or actor.is_ancestor_of(node): return true
	var local_bounds: AABB = node.custom_aabb if node.custom_aabb.size != Vector3.ZERO else node.mesh.get_aabb()
	if local_bounds.size == Vector3.ZERO: return true
	var bounds: AABB = node.global_transform * local_bounds.grow(node.extra_cull_margin)
	for raw in lights:
		var light := raw as OmniLight3D
		if (node.layers & light.light_cull_mask) == 0: continue
		# GLES3 pairs the light's transformed range cube, including its dark corners.
		var reach := Vector3.ONE * light.omni_range
		if bounds.intersects((light.global_transform * AABB(-reach, reach * 2.0)).grow(.001)): return true
	return false

func _warm_proxy(instanced: bool) -> GeometryInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(.6,.6,.6)
	var node: GeometryInstance3D
	if instanced:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.use_custom_data = true
		multimesh.mesh = mesh
		multimesh.instance_count = 1
		multimesh.set_instance_transform(0,Transform3D.IDENTITY)
		multimesh.set_instance_color(0,Color.WHITE)
		multimesh.set_instance_custom_data(0,Color(0,0,0,0))
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = multimesh
		node = batch
	else:
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		node = instance
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func _warm_web_renderer() -> void:
	# Godot 4.7.2 initializes all base color/depth/instancing variants together.
	# Prepare one material family on tiny geometry, including the actual local-light
	# combinations, rather than redrawing every family in every region and quality.
	var warm_started := Time.get_ticks_usec()
	var original_camera := get_viewport().get_camera_3d()
	var original_paused: bool = world._paused
	var original_low := bool(settings.get("low_quality", false))
	world.set_paused(true)
	var plan := _warm_material_plan()
	var instances: Array[Dictionary] = []
	for raw in find_children("*", "GeometryInstance3D", true, false):
		var node := raw as GeometryInstance3D
		instances.append({"node":node,"layers":node.layers})
		node.layers = 0
	var reflection := world.get_node_or_null("PairedMarshStudy/LocalShoreReflection") as ReflectionProbe
	if reflection != null: reflection.visible = false
	var stage := Node3D.new()
	stage.name = "StartupMaterialSamples"
	stage.position = Vector3(0,1000,0)
	add_child(stage)
	var warm_camera := Camera3D.new()
	warm_camera.name = "StartupMaterialWarmup"
	warm_camera.fov = 68.0
	warm_camera.far = 40.0
	warm_camera.near = 0.06
	add_child(warm_camera)
	warm_camera.current = true
	warm_camera.position = Vector3(0,1001,7)
	warm_camera.look_at(stage.position)
	var samples: Array[GeometryInstance3D] = []
	for layer in [1,2]:
		for instanced in [false,true]:
			var sample := _warm_proxy(instanced)
			sample.layers = layer
			sample.position = Vector3(-1.0 if layer == 1 else 1.0,0,-.4 if instanced else .4)
			sample.visible = false
			stage.add_child(sample)
			samples.append(sample)
	var omni := OmniLight3D.new()
	omni.position = Vector3(0,1,0)
	omni.omni_range = 12.0
	omni.visible = false
	stage.add_child(omni)
	var spot := SpotLight3D.new()
	spot.position = Vector3(0,1,4)
	spot.spot_range = 12.0
	spot.spot_angle = 60.0
	spot.visible = false
	stage.add_child(spot)
	spot.look_at(stage.position)
	_set_boot_preparation("materials",0,plan.size())
	# Compile the sky separately before the first spatial material.
	await RenderingServer.frame_post_draw
	await boot_browser_yield()
	var material_index := 0
	var submissions := 0
	for family in plan:
		var material_started := Time.get_ticks_usec()
		for sample in samples:
			sample.material_override = family.material
			sample.visible = family.instanced if sample is MultiMeshInstance3D else family.mesh
			sample.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Fixed mesh bounds outside every authored Omni need only no-light/spot.
		# Instance batches and moving actors keep all four light-presence combinations.
		for lighting in (3 if family.omni else 2):
			omni.visible = lighting > 0 and family.omni
			spot.visible = lighting > 0
			omni.light_cull_mask = 3 if lighting == 2 else 1
			spot.light_cull_mask = 3 if lighting == 2 or not family.omni else 2
			if lighting == (2 if family.omni else 1):
				for sample in samples: sample.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			await RenderingServer.frame_post_draw
			await boot_browser_yield()
			submissions += 1
		_boot_timing_span("renderer_material_initialize_%d" % material_index, material_started)
		material_index += 1
		_set_boot_preparation("materials",material_index,plan.size())
		_publish_boot_timings()
	stage.visible = false
	stage.queue_free()
	_set_boot_preparation("first-view",0,7)
	# Restore authored geometry once. Real region/camera draws cover buffers and
	# textures as well as the ready view; no gameplay or ecology time has advanced.
	for entry in instances:
		entry.node.layers = entry.layers
	warm_camera.far = 650.0
	var views := 0
	for z in [125.0,-100.0,-275.0,-495.0]:
		var x: float = world.path_x(z)
		var h: float = world.height_at(x,z)
		warm_camera.position = Vector3(x+5.5,h+3.5,z+8.0)
		warm_camera.look_at(Vector3(world.path_x(z-24.0),h+2.6,z-24.0))
		await RenderingServer.frame_post_draw
		await boot_browser_yield()
		views += 1
		_set_boot_preparation("first-view",views,7)
	for camera in [rover.camera,rover.third_camera]:
		camera.current = true
		await RenderingServer.frame_post_draw
		await boot_browser_yield()
		views += 1
		_set_boot_preparation("first-view",views,7)
	if is_instance_valid(original_camera): original_camera.current = true
	else: exterior.current = true
	warm_camera.queue_free()
	if reflection != null and not original_low:
		# UPDATE_ONCE does not notice restored geometry. A transform change dirties it.
		# Keep it hidden for the offset frame, then restore the exact authored transform.
		var reflection_position := reflection.position
		reflection.visible = false
		reflection.position += Vector3(0.001,0,0)
		await RenderingServer.frame_post_draw
		await boot_browser_yield()
		reflection.position = reflection_position
		reflection.visible = true
	# UPDATE_ONCE radiance generation spans six subsequent frames.
	for frame in (7 if reflection != null and not original_low else 1):
		await RenderingServer.frame_post_draw
		await boot_browser_yield()
	views += 1
	_set_boot_preparation("first-view",views,7)
	world.set_paused(original_paused)
	_boot_timing_span("renderer_first_use_warmup", warm_started)
	_boot_timing_durations_usec["renderer_warmup_views"] = views
	_boot_timing_durations_usec["renderer_warmup_material_groups"] = plan.size()
	_boot_timing_durations_usec["renderer_warmup_material_initializations"] = material_index
	_boot_timing_durations_usec["renderer_warmup_omni_families"] = plan.filter(func(family): return family.omni).size()
	_boot_timing_durations_usec["renderer_warmup_sample_submissions"] = submissions
	_boot_timing_durations_usec["renderer_warmup_capped"] = 0

func _install_web_launch() -> void:
	if not OS.has_feature("web"): return
	_web_launch_callback = JavaScriptBridge.create_callback(_on_web_launch)
	JavaScriptBridge.get_interface("window").expeditionLaunch = _web_launch_callback
	_begin_web_launch.call_deferred(_read_web_launch_request())

func _read_web_launch_request() -> Dictionary:
	if not OS.has_feature("web"): return {}
	var serialized: Variant = JavaScriptBridge.eval("JSON.stringify(window.__EXPEDITION_BOOT_REQUEST__ || null)", true)
	if serialized is String and serialized.length() <= 8192:
		return ShowcaseBoot.validate(JSON.parse_string(serialized))
	return {}

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
		JavaScriptBridge.eval("window.__EXPEDITION_BOOT_STATUS__=" + JSON.stringify(_web_status()) + ";", true)

func _web_status() -> Dictionary:
	var data: Dictionary = _web_boot.snapshot(_save_available)
	data["saveState"] = _save_state
	data["saveWriteFailed"] = _save_write_failed
	return data

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
	if action not in ["drive_forward","drive_reverse","turn_left","turn_right","brake","drive_boost","drive_crawl","toggle_camera","interact","expedition_journal","pause_mission","resonance_1","resonance_2","resonance_3"]: return
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
	var bindings := {"drive_forward":[KEY_W,KEY_UP],"drive_reverse":[KEY_S,KEY_DOWN],"turn_left":[KEY_A,KEY_LEFT],"turn_right":[KEY_D,KEY_RIGHT],"brake":[KEY_SPACE],"drive_boost":[KEY_SHIFT],"drive_crawl":[KEY_C],"toggle_camera":[KEY_V],"interact":[KEY_E],"expedition_journal":[KEY_J],"pause_mission":[KEY_ESCAPE],"restart_mission":[KEY_R],"resonance_1":[KEY_1],"resonance_2":[KEY_2],"resonance_3":[KEY_3]}
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
	_shown_interaction.clear()
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
	# Discover life before asking for a site record that requires that discovery.
	var species: String={"ember_rift":"veyra","veil_marsh":"aeral","pale_decay":"root_choir"}.get(region,"")
	if not species.is_empty() and not observed_ecology.get(species,false): target="life_"+species
	elif region=="aurora_shelf" and activities.completed.aurora_shelf and not resonance.solved: target="aurora_echo"
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
		elif target.begins_with("life_"):
			point=_life_point(target.trim_prefix("life_"))
		distance=Vector2(rover.position.x,rover.position.z).distance_to(point)
		var offset: Vector2=point-Vector2(rover.position.x,rover.position.z)
		bearing=wrapf(atan2(offset.x,-offset.y)-rover.heading,-PI,PI)
	ui.set_activity_progress(activities.count(),activities.optional_count(),activities.field_count(),region,target,distance,activities.stillness,bearing)
	# The same current investigation supplies both HUD distance and map marker.
	var map_target := _encounter_point(tracked) if not tracked.is_empty() else ActivityScript.point(target)
	if target=="study_aeral":
		var animal: Vector3=world._ecology_nodes[4].global_position
		map_target=Vector2(animal.x,animal.z)
	elif target.begins_with("life_"): map_target=_life_point(target.trim_prefix("life_"))
	ui.set_navigation(Vector2(rover.position.x, rover.position.z), rover.heading, map_target, not target.is_empty() and map_target.is_finite())
	ui.set_resonance_context(_resonance_context())
	ui.set_escort_context(_escort_context())
	ui.set_passage_context(_passage_context())
	ui.set_root_network_context(_root_network_context())
	ui.set_thermal_context(_thermal_context())
	ui.set_wetland_context(_wetland_context())
	var journal: Dictionary={"tracked":activities.tracked_encounter,"entries":{},"observedEcology":observed_ecology.duplicate(true)}
	for id in ActivityScript.REGIONS:
		journal.entries[id]={"discovered":activities.discovered[id],"complete":_encounter_complete(id)}
	ui.set_journal_context(journal)
	_shown_interaction = interaction_context()
	ui.set_interaction_kind(_shown_interaction.kind if _shown_interaction.eligible else "none")
	if ui.has_method("set_interaction_context"): ui.set_interaction_context(_shown_interaction)

func _life_point(kind: String) -> Vector2:
	var point := Vector2.ZERO
	var nearest := INF
	for i in world._ecology_nodes.size():
		if world._ecology_meta[i].kind!=kind: continue
		var position: Vector3=world._ecology_nodes[i].global_position
		var distance:=rover.global_position.distance_to(position)
		if distance<nearest:
			nearest=distance;point=Vector2(position.x,position.z)
	return point

func _nearby_survey() -> String:
	for id in ActivityScript.SITES:
		if activities.can_record(id,world.region_at(rover.position),rover.position,rover.speed,observed_ecology):
			if _target_visible(world.survey_position(id)+Vector3(0,1,0),world.get_node("Survey_"+id)): return id
	return ""


func _input(event: InputEvent) -> void:
	if not ready_for_play or event.is_echo(): return
	if event.is_action_pressed("pause_mission"):
		if phase == "menu" and ui.current_state() == "confirm_new": ui._cancel_new()
		elif phase == "paused" and ui.current_state() == "settings": ui.show_state("paused")
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
	if phase == "menu" and (has_saved_expedition() or ExpeditionSave.exists(save_path)):
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
	_save_write_failed = not success
	if success:
		_save_available = true
		_save_state = "valid"
	elif is_instance_valid(ui):
		_survey_message_seconds=6.0
		ui.set_message("save_write_failed")
	_publish_web_boot()
	return success

func has_saved_expedition() -> bool:
	_save_state = ExpeditionSave.status(save_path)
	_save_available = _save_state == "valid"
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

func _resume_terrain(position: Vector3) -> Dictionary:
	var ground_y: float = world.height_at(position.x,position.z)
	var changed := false
	var valid_height := absf(position.y-ground_y) <= 5.0
	if world.environment_terrain_changed_at(position.x,position.z):
		var known_heights: Array[float] = [world.legacy_height_at(position.x,position.z)]
		for method in ["previous_height_at","revision_3_height_at","revision_4_height_at","revision_5_height_at","revision_6_height_at"]:
			if world.has_method(method): known_heights.append(world.call(method,position.x,position.z))
		for height in known_heights: changed = changed or absf(ground_y-height) > .001
		# Bounding areas include unchanged roads/clearances. Keep their exact feet;
		# accept historical heights only where an authored surface actually changed.
		if changed:
			for height in known_heights: valid_height = valid_height or absf(position.y-height) <= 5.0
	return {"height":ground_y,"changed":changed,"valid":valid_height}

func load_expedition() -> bool:
	var parsed: Dictionary = ExpeditionSave.read(save_path)
	if parsed.is_empty():
		_save_state = ExpeditionSave.status(save_path)
		_save_available = false
		if phase == "menu": ui.set_saved_available(false,true)
		return false
	var point: Dictionary = parsed["position"]
	var position := Vector3(float(point.x),float(point.y),float(point.z))
	# Accept known old terrain within the authored revision area, without relaxing
	# validation elsewhere or changing any saved progression.
	var terrain := _resume_terrain(position)
	var ground_y: float = terrain.height
	if not terrain.valid:
		_save_state = "unreadable"
		_save_available = false
		if phase == "menu": ui.set_saved_available(false,true)
		return false
	if terrain.changed:
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
	_save_state="absent"
	_save_write_failed=false
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

func _candidate(kind: String, subject: String, point: Vector3, radius: float, allowed: Node = null, speed_limit: float = 2.0) -> Dictionary:
	var distance := rover.global_position.distance_to(point)
	if kind!="ecology": distance=Vector2(rover.position.x-point.x,rover.position.z-point.z).length()
	var reason := "ready"
	if absf(rover.speed) >= speed_limit: reason = "slow"
	elif distance > radius: reason = "closer"
	else:
		var direction: Vector3 = point-rover.get_active_camera().global_position
		if direction.length_squared() > .001 and rover.view_direction().dot(direction.normalized()) < .55: reason = "look"
		elif not _target_visible(point,allowed): reason = "blocked"
	return {"key":kind,"kind":kind,"subject":subject,"distance":distance,"reason":reason,"eligible":reason=="ready"}

func interaction_context() -> Dictionary:
	var empty := {"key":"none","kind":"none","subject":"","reason":"none","distance":0.0,"eligible":false}
	_interaction_options.clear()
	if phase != "exploring": return empty
	var choices: Array[Dictionary] = []
	if target_distance() < 24.0:
		choices.append(_candidate("contact","contact",contact.global_position+Vector3(0,2,0),9.5,contact))
	for id in ActivityScript.SITES:
		if id == "aurora_shelf" or activities.done(id): continue
		var point: Vector3 = world.survey_position(id)+Vector3(0,1,0)
		if rover.global_position.distance_to(point)>20.0: continue
		var item := _candidate("survey:"+id,id,point,7.0,world.get_node("Survey_"+id),1.5)
		if not activities.ready(id,observed_ecology):
			item.reason="wait";item.eligible=false
		# Exact existing rule remains authoritative at the final action boundary.
		if item.eligible and not activities.can_record(id,world.region_at(rover.position),rover.position,rover.speed,observed_ecology): item.eligible=false;item.reason="closer"
		choices.append(item)
	var activity := "none"
	if _resonance_near() and not resonance.solved: activity="resonance"
	elif _thermal_near():
		if thermal.vent_observed: activity="thermal_route"
		elif world.thermal_pulse()>=.75: activity="thermal_observe"
	elif _escort_can_start(): activity="escort"
	elif _passage_can_start(): activity="passage"
	else: activity=_root_network_interaction()
	if activity!="none": choices.append({"key":activity,"kind":activity,"subject":activity,"reason":"ready","distance":0.0,"eligible":true})
	for i in world._ecology_nodes.size():
		var point: Vector3=world._ecology_nodes[i].global_position+Vector3(0,.3,0)
		if rover.global_position.distance_to(point)>28.0: continue
		var kind: String=world._ecology_meta[i].kind
		var item:=_candidate("ecology",kind,point,14.0)
		item.index=i;item.key="ecology:"+str(i)
		if i==0 and escort.phase in ["travelling","alarmed","waiting"]: item.eligible=false;item.reason="wait"
		if item.eligible and observed_ecology.get(kind,false): item.reason="recorded"
		choices.append(item)
	var best := empty
	_interaction_options=choices
	var best_score := INF
	for item in choices:
		var score: float=float(item.distance)+(0.0 if item.eligible else 1000.0)
		# Preserve the action contract: contact, unrecorded site, active encounter,
		# then life. An encounter at the same station cannot swallow its field record.
		if item.eligible:
			if item.kind=="contact": score-=300.0
			elif str(item.kind).begins_with("survey:"): score-=200.0
			elif item.kind!="ecology": score-=100.0
		if item.reason=="wait": score+=200.0
		if item.get("key","")==_shown_interaction.get("key","-"): score-=2.0
		if score<best_score: best=item;best_score=score
	return best

func interaction_target() -> String:
	var selected := interaction_context()
	return selected.kind if selected.eligible else "none"

func can_interact() -> bool:
	return interaction_target() != "none"

func interact() -> void:
	var context := interaction_context()
	# Revalidate the displayed identity. A moving/occluded subject cannot silently
	# redirect E to a different animal between the prompt and the input event.
	if not _shown_interaction.is_empty() and _shown_interaction.get("eligible",false):
		var displayed: Dictionary={}
		for option in _interaction_options:
			if option.key==_shown_interaction.key and option.eligible: displayed=option;break
		if displayed.is_empty():
			_update_survey_readout()
			return
		context=displayed
	_shown_interaction = context
	if not context.eligible:
		_update_survey_readout()
		return
	var target: String = context.kind
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
		var observed: Dictionary = world.observe_ecology(rover.global_position, int(context.get("index",-1)))
		if not observed.is_empty():
			var first_discovery: bool = not observed_ecology.get(str(observed.kind),false)
			observed_ecology[str(observed.get("kind","unknown"))] = true
			if observed.kind == "aeral": activities.wetland_study.prepare()
			activities.tick(world.region_at(rover.global_position),rover.speed,observed_ecology,0.0,rover.global_position)
			_update_survey_readout()
			var study_event: String=activities.wetland_study.observe(str(observed.get("kind","")),float(world._ecology_reactions[int(observed.index)].alert))
			ui.set_message("study_"+study_event if not study_event.is_empty() else "discovered_"+str(observed.kind) if first_discovery else "ecology_observed")
			if not study_event.is_empty():
				_survey_message_seconds=4.0
				audio.play_resonance(0 if study_event=="startled" else 2)
				save_expedition()
				_update_survey_readout()
			save_expedition()
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
	_apply_display_quality(bool(settings.get("low_quality",false)))
	rover.reduced_motion = bool(settings.get("reduced_motion",false))
	rover.set_low_quality(bool(settings.get("low_quality",false)))
	world.set_low_quality(bool(settings.get("low_quality",false)))
	audio.set_mix(float(settings.get("volume",0.5)))
	_publish_snapshot()

func _apply_display_quality(low: bool) -> void:
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if low else Viewport.MSAA_2X

func snapshot() -> Dictionary:
	if not ready_for_play: return {"ready":false,"phase":phase}
	return {"ready":true,"touchEnabled":touch_enabled,"phase":phase,"position":{"x":rover.global_position.x,"y":rover.global_position.y,"z":rover.global_position.z},"heading":rover.heading,"speed":rover.speed,"speedMps":rover.current_speed_mps(),"speedKph":rover.current_speed_mps()*3.6,"maxSpeedMps":rover.max_speed_mps(),"boosting":rover.is_boosting(),"distance":rover.distance_travelled,"targetDistance":target_distance(),"elapsed":elapsed,"contactProgress":contact.progress,"transmitCount":transmit_count,"resetCount":reset_count,"view":rover.camera_mode,"camera":rover.camera_snapshot(),"ecology":ecology_snapshot(),"observedEcology":observed_ecology.duplicate(true),"activities":activities.snapshot(),"wetlandStudy":activities.wetland_study.snapshot(),"resonance":resonance.snapshot(),"escort":escort.snapshot(),"thermal":thermal.snapshot(),"thermalPulse":world.thermal_pulse(),"passage":passage.snapshot(),"rootNetwork":root_network.snapshot(),"activityCount":activities.count(),"floor":rover.is_on_floor(),"collisions":rover.last_collision_count,"settings":settings.duplicate(true),"saveAvailable":_save_available,"saveState":_save_state,"saveWriteFailed":_save_write_failed,"interaction":_shown_interaction.duplicate(true)}

func ecology_snapshot() -> Dictionary:
	return {"veyra": world.ecology_state("veyra", rover.global_position), "aeral": world.ecology_state("aeral", rover.global_position), "rootChoir": world.ecology_state("root_choir", rover.global_position)}

func metrics() -> Dictionary:
	var ordered := frames.duplicate()
	ordered.sort()
	var count := ordered.size()
	return {"sampleFrames":count,"fps":Engine.get_frames_per_second(),"p50ms":ordered[int((count-1)*0.5)] if count else 0,"p95ms":ordered[int((count-1)*0.95)] if count else 0,"p99ms":ordered[int((count-1)*0.99)] if count else 0,"worstMs":ordered[count-1] if count else 0,"drawCalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"worldBuild":world.build_stats.duplicate(true),"viewport":str(get_viewport().get_visible_rect().size),"display":{"msaa3d":get_viewport().msaa_3d},"activityCount":activities.count(),"optionalCount":activities.optional_count(),"fieldCount":activities.field_count(),"runtimeSurface":_runtime_surface.snapshot() if is_instance_valid(_runtime_surface) else {}}

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
	return world.escort_route_points(selected)

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
	data.phase="complete" if data.complete else "return" if data.recovered else "quiet" if data.prepared else "prepare"
	return data
