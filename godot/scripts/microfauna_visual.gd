extends Node3D
## Small visual fauna use terrain and player readback only; never change gameplay.
const BIO_SHADER = preload("res://shaders/bioceramic.gdshader")
var terrain: Node3D
var animals: Array[Dictionary] = []
var clock := 0.0
var low := false
var paused := false
var _pool := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _materials: Dictionary = {}

func build(world: Node3D, pool: Vector2) -> void:
	for child in get_children(): child.queue_free()
	animals.clear()
	terrain = world
	_pool = pool
	_rng.seed = 26092026
	var flier := load("res://assets/visual_microfauna/shore_flier.glb") as PackedScene
	var crawler := load("res://assets/visual_microfauna/shore_crawler.glb") as PackedScene
	if flier == null or crawler == null:
		push_error("Authored microfauna resource missing")
		return
	# Fliers feed beside the actual pool rim; crawlers occupy damp banks, not water.
	for i in 8:
		var angle:float=[1.58,3.05,4.57][i%3]+_rng.randf_range(-.22,.22)
		var anchor: Vector2 = terrain.wetland_shore_point(angle,_rng.randf_range(0.3,1.2))
		_add_animal(flier, anchor, true, i, "wetland_rim")
	for i in 8:
		var angle:float=[1.72,3.12,4.64][i%3]+_rng.randf_range(-.17,.17)
		var anchor: Vector2 = terrain.wetland_shore_point(angle,_rng.randf_range(1.1,2.2))
		_add_animal(crawler, anchor, false, i + 8, "wetland_bank")
	# Loose ground colonies are anchored beside encounter regions and clear the road.
	for cluster in 4:
		var z: float = [104.0, -96.0, -280.0, -481.0][cluster]
		var x: float = terrain.path_x(z) + (8.2 if cluster % 2 else -9.0)
		for i in 3:
			var anchor := Vector2(x + _rng.randf_range(-1.1, 1.1), z + _rng.randf_range(-2.0, 2.0))
			_add_animal(crawler, anchor, false, animals.size(), "encounter_ground")
	if terrain.get("build_stats") is Dictionary:
		terrain.build_stats["microfauna_authored_count"] = animals.size()
		terrain.build_stats["microfauna_species"] = 2

func _add_animal(packed: PackedScene, anchor: Vector2, flying: bool, index: int, habitat: String) -> void:
	var node := packed.instantiate() as Node3D
	node.name = ("RimFlier_" if flying else "BankCrawler_") + str(index)
	var size := _rng.randf_range(0.72, 1.16) if flying else _rng.randf_range(1.1, 1.7)
	node.scale = Vector3.ONE * size
	add_child(node)
	var wings: Array[Dictionary] = []
	var paddles: Array[Dictionary] = []
	for item in node.find_children("*", "Node3D", true, false):
		if item.name == "Wing_L" or item.name == "Wing_R":
			wings.append({"node": item, "side": -1.0 if item.name == "Wing_L" else 1.0})
		elif str(item.name).begins_with("Paddle_") and not str(item.name).ends_with("Geometry"):
			paddles.append({"node":item,"side":-1.0 if "_L_" in str(item.name) else 1.0,"index":int(str(item.name).right(1))})
		if item is MeshInstance3D:
			var part := item as MeshInstance3D
			for surface in part.mesh.get_surface_count():
				var source := part.get_active_material(surface)
				var label := source.resource_name.to_lower() if source != null else "skin"
				if not _materials.has(label):
					var material := ShaderMaterial.new()
					material.shader = BIO_SHADER
					var tint := Color("46594f")
					if "membrane" in label: tint = Color("718c7e")
					elif "mineral" in label: tint = Color("756d51")
					elif "signal" in label: tint = Color("a77d48")
					material.set_shader_parameter("specular_amount", 0.40 if "membrane" in label else 0.28)
					var role := "frond" if "membrane" in label else "scute" if "mineral" in label else "dermis"
					if "signal" not in label:
						material.set_shader_parameter("structure_enabled", true)
						material.set_shader_parameter("dermal_projection", role == "dermis")
						material.set_shader_parameter("normal_strength", 0.35)
						material.set_shader_parameter("structure_map", load("res://assets/visual_fauna/surface_maps/" + role + "_structure.png"))
						material.set_shader_parameter("surface_normal", load("res://assets/visual_fauna/surface_maps/" + role + "_normal.png"))
					material.set_shader_parameter("tint", tint)
					material.set_shader_parameter("roughness", 0.58 if "membrane" in label else 0.78)
					material.set_shader_parameter("membrane", 1.0 if "membrane" in label else 0.0)
					material.set_shader_parameter("shell", 0.6 if "mineral" in label else 0.0)
					_materials[label] = material
				part.set_surface_override_material(surface, _materials[label])
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			part.visibility_range_end = 55.0
	var floor_y: float = terrain.height_at(anchor.x, anchor.y)
	node.position = Vector3(anchor.x, floor_y + (0.9 if flying else -0.012 * size), anchor.y)
	animals.append({"node": node, "anchor": anchor, "flying": flying, "wings": wings, "paddles":paddles,
		"phase": _rng.randf() * TAU, "alarm": 0.0, "offset": Vector2.ZERO,
		"index": index, "habitat": habitat, "rest_height": floor_y})

func tick(delta: float, is_paused: bool) -> void:
	if paused or is_paused or terrain == null: return
	clock += delta
	var player: Vector3 = terrain._player_position
	var speed: float = absf(terrain._player_speed)
	var player_xz := Vector2(player.x, player.z)
	for entry in animals:
		var node: Node3D = entry.node
		var anchor: Vector2 = entry.anchor
		var distance := player_xz.distance_to(Vector2(node.position.x, node.position.z))
		node.visible = distance < (34.0 if low else 62.0) and (not low or int(entry.index) % 2 == 0)
		if not node.visible: continue
		var stimulus := (1.0 - smoothstep(2.2, 8.0 + speed * 0.35, distance)) * (0.35 + minf(speed / 5.0, 0.65))
		entry.alarm = move_toward(float(entry.alarm), stimulus, delta * (2.3 if stimulus > float(entry.alarm) else 0.34))
		var alarm: float = entry.alarm
		var phase: float = entry.phase
		var away := (anchor - player_xz).normalized()
		if away.is_zero_approx(): away = Vector2.RIGHT
		var target_offset := away * alarm * (1.8 if entry.flying else 1.15)
		entry.offset = (entry.offset as Vector2).lerp(target_offset, 1.0 - exp(-delta * 3.0))
		var wander := Vector2(sin(clock * 0.46 + phase), cos(clock * 0.33 + phase)) * (0.62 if entry.flying else 0.20)
		var point: Vector2 = anchor + entry.offset + wander
		# Damp-bank walkers never drift into the pool bowl or onto the central road.
		if entry.habitat == "wetland_bank" or entry.habitat == "wetland_rim":
			if terrain.height_at(point.x,point.y) < terrain.wetland_water_level()+0.04:
				point = terrain.wetland_shore_point((point-_pool).angle(),0.45 if entry.flying else 0.9)
		var floor_y: float = terrain.height_at(point.x, point.y)
		var old := node.position
		var ground_alignment := 1.0
		if entry.flying:
			var settle := smoothstep(0.65, 0.97, sin(clock * 0.17 + phase)) * (1.0 - alarm)
			# A resting flier holds its landing spot instead of skating with the wander.
			if settle > 0.95:
				if not entry.has("perch_point"): entry["perch_point"] = point
				point = entry.perch_point
				floor_y = terrain.height_at(point.x, point.y)
			else: entry.erase("perch_point")
			ground_alignment = settle
			var altitude := lerpf(0.85 + sin(clock * 1.4 + phase) * 0.18 + alarm * 1.25, 0.08 * node.scale.y, settle)
			node.position = Vector3(point.x, floor_y + altitude, point.y)
			for wing in entry.wings:
				wing.node.rotation.z = float(wing.side) * (0.14 + settle * 0.85 + sin(clock * (21.0 + alarm * 8.0) + phase) * 0.48 * (1.0-settle))
			node.rotation.x = sin(clock * 1.1 + phase) * 0.055 - alarm * 0.13
		else:
			# Authored planted paddle tips are +0.012m from the asset origin.
			node.position = Vector3(point.x, floor_y - 0.012 * node.scale.y, point.y)
			for paddle in entry.paddles:
				var step_phase: float = clock * (4.5 + alarm * 6.0) + float(paddle.index)*PI + (PI if float(paddle.side)<0 else 0.0)
				paddle.node.rotation.y = sin(step_phase)*0.19
				paddle.node.rotation.z = float(paddle.side)*maxf(0.0,cos(step_phase))*0.11
		var direction := node.position - old
		if Vector2(direction.x, direction.z).length_squared() > 0.0000001:
			node.rotation.y = lerp_angle(node.rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-delta * 4.0))
		# Apply terrain alignment after heading, so Euler yaw cannot undo the foot plane.
		if ground_alignment > 0.001:
			var hx: float = terrain.height_at(point.x + 0.13, point.y) - terrain.height_at(point.x - 0.13, point.y)
			var hz: float = terrain.height_at(point.x, point.y + 0.13) - terrain.height_at(point.x, point.y - 0.13)
			var up := Vector3(-hx / 0.26, 1.0, -hz / 0.26).normalized()
			var forward := Vector3(-sin(node.rotation.y),0,-cos(node.rotation.y))
			var right := forward.cross(up).normalized()
			var retained_scale := node.scale
			var ground_rotation := Basis(right,up,right.cross(up)).get_rotation_quaternion()
			node.quaternion = node.quaternion.slerp(ground_rotation, ground_alignment)
			node.scale = retained_scale

func set_paused(value: bool) -> void:
	paused = value

func set_low_quality(value: bool) -> void:
	low = value
	for entry in animals:
		if value and int(entry.index) % 2 != 0: entry.node.visible = false

func debug_snapshot() -> Dictionary:
	var samples: Array = []
	for entry in animals:
		samples.append({"name": str(entry.node.name), "habitat": entry.habitat, "flying": entry.flying,
			"anchor": str(entry.anchor), "position": str(entry.node.position), "alarm": entry.alarm,
			"visible": entry.node.visible})
	return {"time": clock, "paused": paused, "low": low, "count": animals.size(), "animals": samples}
