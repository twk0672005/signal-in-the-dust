extends Node
## Local inspection adapter. Fixed views prove appearance, never player travel.
## Enabled only by an explicit loopback ?review=1 URL, or a native test harness.
var game: Node3D
var camera: Camera3D
var command_poll_clock := 0.0
var last_error := ""
var view_id := "play"
var revision := 0
var measuring := false
var measured_ms: Array[float] = []
var measure_seconds := 0.0
var measure_limit := 30.0
var measure_started_usec: int = 0
var measure_last_usec: int = 0
var report: Dictionary = {}
var ecology_inspection: Dictionary = {}
var material_comparison: Dictionary = {}
var review_frozen := false
var diagnostic_id := ""
const REGION_Z := {"aurora_shelf":125.0,"ember_rift":-100.0,"veil_marsh":-275.0,"pale_decay":-495.0}

static func enabled_in_browser() -> bool:
	return OS.has_feature("web") and bool(JavaScriptBridge.eval("['localhost','127.0.0.1','[::1]'].includes(location.hostname) && new URLSearchParams(location.search).get('review') === '1'", true))

func setup(value: Node3D) -> void:
	game = value
	camera = Camera3D.new()
	camera.name = "LocalReviewCamera"
	camera.fov = 62.0
	camera.far = 800.0
	add_child(camera)
	if OS.has_feature("web"):
		# Consume bounded inspection requests on the engine's own frame, avoiding
		# browser -> WASM callback re-entry while Godot publishes readback state.
		JavaScriptBridge.eval("window.__WORLD_REVIEW_COMMANDS__=[]; window.expeditionReview=function(text){ if(typeof text!=='string'||text.length>1024||window.__WORLD_REVIEW_COMMANDS__.length>=16)return false; window.__WORLD_REVIEW_COMMANDS__.push(text); return true; };", true)
	_publish()

func _poll_command() -> void:
	var serialized: Variant = JavaScriptBridge.eval("window.__WORLD_REVIEW_COMMANDS__.length ? window.__WORLD_REVIEW_COMMANDS__.shift() : null", true)
	if not serialized is String or serialized.length() > 1024: return
	var data: Variant = JSON.parse_string(serialized)
	if not data is Dictionary: return
	_execute(data)

func _execute(data: Dictionary) -> void:
	last_error = ""
	match str(data.get("action", "")):
		"view":
			if not set_view(str(data.get("id", "play"))): last_error = "View not applied in current phase"
		"quality":
			var settings: Dictionary = game.settings.duplicate(true)
			settings.low_quality = bool(data.get("low", false))
			game._on_settings(settings)
		"measure": begin_measure(clampf(float(data.get("seconds", 30.0)), 5.0, 60.0))
		"freeze": _set_review_frozen(bool(data.get("enabled", true)))
		"material": _set_material_comparison(str(data.get("scope", "creature")), str(data.get("mode", "current")))
		"diagnostics": diagnostic_id = str(data.get("id", ""))
		"inspect_ecology":
			var creatures: Array = []
			for node in game.world._ecology_nodes:
				var visual: Node3D = node.get_node_or_null("DetailedVisual")
				if visual != null:
					creatures.append({"position":str(node.global_position),"visual":visual.debug_snapshot()})
			ecology_inspection = {"id":str(data.get("id","")),"creatures":creatures,"readOnly":true}
		_: last_error = "Unknown inspection command"
	_publish()

func set_view(id: String) -> bool:
	if not game.phase in ["exploring", "arrival"]: return false
	if review_frozen: _set_review_frozen(false)
	if id == "play":
		camera.current = false
		game.rover.set_camera_mode(game.rover.camera_mode)
		game.rover.set_driving_enabled(true)
		game.save_clock = 0.0
		view_id = id
		revision += 1
		_publish()
		return true
	var position := Vector3.ZERO
	var target := Vector3.ZERO
	var point := Vector3.ZERO
	var region := id.trim_suffix("_reverse").trim_suffix("_side")
	if REGION_Z.has(region):
		var z: float = REGION_Z[region]
		var x: float = game.world.path_x(z)
		var h: float = game.world.height_at(x,z)
		point = Vector3(x,h+0.1,z)
		position = Vector3(x+5.5,h+3.5,z+8.0)
		target = Vector3(game.world.path_x(z-24.0),h+2.6,z-24.0)
		if id.ends_with("_reverse"):
			position = Vector3(x-3.5,h+2.8,z-6.0)
			target = Vector3(game.world.path_x(z+30.0),h+2.3,z+30.0)
		elif id.ends_with("_side"):
			position = Vector3(x,h+2.0,z)
			target = Vector3(x+27.0,game.world.height_at(x+27.0,z)+2.0,z-10.0)
	elif id == "rock_material":
		var best := INF
		for family: Array in game.world._rock_transforms:
			for placement: Transform3D in family:
				var score: float = absf(placement.origin.z - 125.0) + absf(placement.origin.x - game.world.path_x(placement.origin.z)) * 0.4
				if score < best:
					best = score
					target = placement.origin + Vector3.UP * 0.6
		if best == INF: return false
		position = target + Vector3(3.7,2.2,4.5)
		point = Vector3(game.world.path_x(target.z),game.world.height_at(game.world.path_x(target.z),target.z)+0.1,target.z)
	elif id == "flora_material":
		var pool: Vector2 = game.world._wetland_center()
		var best := INF
		for pair: Dictionary in game.world._living_habitat._material_pairs:
			var batch: MultiMeshInstance3D = pair.node
			if not str(batch.name).begins_with("cups_habitat"): continue
			for i in batch.multimesh.instance_count:
				var placement: Transform3D = batch.global_transform * batch.multimesh.get_instance_transform(i)
				var score := Vector2(placement.origin.x,placement.origin.z).distance_squared_to(pool)
				if score < best:
					best = score
					target = placement.origin + Vector3.UP * 0.6
		if best == INF: return false
		position = target + Vector3(2.3,1.3,2.8)
		point = Vector3(game.world.path_x(target.z),game.world.height_at(game.world.path_x(target.z),target.z)+0.1,target.z)
	elif id in ["veyra","aeral","morrow","veyra_close","aeral_close","morrow_close"]:
		var species:=id.trim_suffix("_close")
		var index := 0 if species == "veyra" else 4 if species == "aeral" else 9
		var node: Node3D = game.world._ecology_nodes[index]
		target = node.global_position + Vector3(0,0.5 if species != "aeral" else 0.0,0)
		position = target + (Vector3(6.5,2.5,7.5) if species != "aeral" else Vector3(8.5,2.0,10.0))
		if id.ends_with("_close"): position=target+(Vector3(3.2,1.4,3.8) if species!="aeral" else Vector3(4.0,1.2,4.8))
		point = Vector3(game.world.path_x(target.z),game.world.height_at(game.world.path_x(target.z),target.z)+0.1,target.z)
	elif id in ["veil_approach","veil_shore_detail","veil_profile","veil_lookback"]:
		var pool: Vector2 = game.world._wetland_center()
		var eye_xz := pool+Vector2(15.0,14.0)
		var aim_xz := pool+Vector2(-17.0,-5.0)
		var eye_height := 1.8
		if id == "veil_shore_detail":
			eye_xz = game.world.wetland_shore_point(0.75,1.2)
			eye_height = 0.55
		elif id == "veil_profile":
			eye_xz = pool+Vector2(-42.0,2.0)
			aim_xz = pool+Vector2(3.0,-14.0)
			eye_height = 2.0
		elif id == "veil_lookback":
			eye_xz = pool+Vector2(-42.0,-17.0)
			aim_xz = pool+Vector2(7.0,12.0)
		position = Vector3(eye_xz.x,game.world.height_at(eye_xz.x,eye_xz.y)+eye_height,eye_xz.y)
		target = Vector3(aim_xz.x,game.world.wetland_water_level()+1.0,aim_xz.y)
		var parked_xz := eye_xz-(aim_xz-eye_xz).normalized()*6.0
		parked_xz.x = clampf(parked_xz.x,-94.0,94.0)
		point = Vector3(parked_xz.x,game.world.height_at(parked_xz.x,parked_xz.y)+0.1,parked_xz.y)
	elif id in ["shore","shore_side","shore_reverse","shore_near","microfauna"]:
		var pool: Vector2 = game.world._wetland_center()
		var h: float = game.world.height_at(pool.x,pool.y)
		target = Vector3(pool.x,h+1.2,pool.y)
		position = target + (Vector3(8.0,3.5,9.0) if id == "shore" else Vector3(4.0,2.4,5.0))
		if id == "shore_side": position = target + Vector3(-11.0,2.2,1.5)
		elif id == "shore_reverse": position = target + Vector3(-3.0,2.8,-12.0)
		elif id == "shore_near": position = target + Vector3(3.0,0.7,4.0)
		point = Vector3(pool.x+12.0,game.world.height_at(pool.x+12.0,pool.y)+0.1,pool.y)
	else:
		return false
	game._set_phase("exploring")
	game.rover.set_driving_enabled(false)
	game.rover.speed = 0.0
	game.rover.velocity = Vector3.ZERO
	game.rover.global_position = point
	game.world.set_player_state(point,0.0)
	game.world.set_region_mood(game.world.region_at(point),10.0)
	game.save_clock = -3600.0
	camera.position = position
	camera.look_at(target)
	camera.current = true
	view_id = id
	revision += 1
	_publish()
	return true


func _set_review_frozen(enabled: bool) -> void:
	review_frozen = enabled
	game.set_process(not enabled)
	game.world.process_mode = Node.PROCESS_MODE_DISABLED if enabled else Node.PROCESS_MODE_INHERIT
	game.rover.set_process(not enabled)
	# Runtime shaders use world_time / pose uniforms; freezing their owners
	# holds time without relying on an unavailable global RenderingServer API.

func _geometry_signature() -> Dictionary:
	var rows: Array = []
	var mesh_count := 0
	var instance_count := 0
	for node in game.world.find_children("*", "GeometryInstance3D", true, false):
		if node is MeshInstance3D and node.mesh != null:
			rows.append([str(node.get_path()),str(node.mesh.get_rid()),str(node.global_transform),node.mesh.get_surface_count(),node.visible])
			mesh_count += 1
		elif node is MultiMeshInstance3D and node.multimesh != null:
			rows.append([str(node.get_path()),str(node.multimesh.get_rid()),str(node.global_transform),node.multimesh.instance_count,node.visible])
			instance_count += node.multimesh.instance_count
	return {"hash":hash(rows),"meshes":mesh_count,"multimesh_instances":instance_count}

func _set_material_comparison(scope: String, mode: String) -> void:
	if not review_frozen:
		last_error = "Material comparison requires frozen scene"
		return
	var results: Array = []
	if scope == "world" and game.world.has_method("debug_set_material_variant"):
		results.append(game.world.debug_set_material_variant(mode))
	elif scope == "creature":
		for node in game.world._ecology_nodes:
			var visual: Node3D = node.get_node_or_null("DetailedVisual")
			if visual != null and visual.has_method("debug_set_material_mode"):
				results.append(visual.debug_set_material_mode(mode))
	else:
		last_error = "Material comparison interface unavailable"
	material_comparison = {"scope":scope,"mode":mode,"results":results,"geometry":_geometry_signature(),"frozen":review_frozen,"world_clock":game.world_clock}

func _diagnostics() -> Dictionary:
	return {"id":diagnostic_id,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"texture_memory_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"buffer_memory_bytes":Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED),
		"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),
		"limits":"Engine counters; zero/unsupported Web monitors are not total browser/WASM/GPU memory"}

func begin_measure(seconds: float) -> void:
	measured_ms.clear()
	measure_seconds = 0.0
	measure_limit = seconds
	measure_started_usec = 0
	measure_last_usec = 0
	measuring = true
	report = {"status":"measuring","view":view_id,"seconds":seconds}
	_publish()

func _process(delta: float) -> void:
	if OS.has_feature("web"):
		command_poll_clock += delta
		if command_poll_clock >= 0.25:
			command_poll_clock = 0.0
			_poll_command()
			var probe := {"region":game.world.region_at(game.rover.global_position),"interactionTarget":game.interaction_target()}
			JavaScriptBridge.eval("window.__WORLD_REVIEW_PROBE__="+JSON.stringify(probe)+";",true)
	if not measuring: return
	# Measure actual callback intervals, including stalls. Engine delta can be
	# smoothed/clamped and is a simulation clock rather than a wall-clock profile.
	var now_usec := Time.get_ticks_usec()
	if measure_last_usec == 0:
		measure_started_usec = now_usec
		measure_last_usec = now_usec
		return
	measured_ms.append(float(now_usec-measure_last_usec)/1000.0)
	measure_last_usec = now_usec
	measure_seconds = float(now_usec-measure_started_usec)/1000000.0
	if measure_seconds < measure_limit: return
	measuring = false
	var ordered := measured_ms.duplicate()
	ordered.sort()
	var n := ordered.size()
	report = {"status":"complete","view":view_id,"frames":n,"seconds":measure_seconds,"clock":"monotonic wall microseconds; no dropped intervals",
		"meanFps":n/measure_seconds,"p50ms":ordered[int((n-1)*0.5)],"p95ms":ordered[int((n-1)*0.95)],
		"p99ms":ordered[int((n-1)*0.99)],"worstMs":ordered[-1],"rawFrameMs":measured_ms,
		"low":bool(game.settings.get("low_quality",false)),"viewport":str(get_viewport().get_visible_rect().size),
		"drawCalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"videoMemoryBytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"engine":Engine.get_version_info().string,
		"device":RenderingServer.get_video_adapter_name(),"fixedViewNotJourney":view_id != "play"}
	_publish()

func _publish() -> void:
	if not OS.has_feature("web"): return
	var state := {"enabled":true,"view":view_id,"revision":revision,"cameraPosition":str(camera.global_position),
		"cameraRotation":str(camera.global_rotation),"fov":camera.fov,"measurement":report,"lastError":last_error,"ecologyInspection":ecology_inspection,"frozen":review_frozen,"materialComparison":material_comparison,"diagnostics":_diagnostics()}
	if is_instance_valid(game.world._environment):
		var environment: Environment = game.world._environment
		state["atmosphere"] = {"mode":environment.fog_mode,"density":environment.fog_density,
			"begin":environment.fog_depth_begin,"end":environment.fog_depth_end}
	JavaScriptBridge.eval("window.__WORLD_REVIEW__="+JSON.stringify(state)+";",true)
