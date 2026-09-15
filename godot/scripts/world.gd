extends Node3D
## Authored geological basin. Coordinates and height queries are shared with driving.
const ROCKS_PATH := "res://assets/models/rocks.glb"
const TERRAIN_SHADER = preload("res://shaders/terrain.gdshader")
const SKY_SHADER = preload("res://shaders/storm_sky.gdshader")
const ROOT_SHADER = preload("res://shaders/response_roots.gdshader")
const STRATA_SHADER = preload("res://shaders/geological_strata.gdshader")
var _environment: Environment
var _roots_material: ShaderMaterial
var _small_dressing: Array[MultiMeshInstance3D] = []
var _dust: CPUParticles3D
var _rng := RandomNumberGenerator.new()
var _terrain_material: ShaderMaterial
var _strata_material: ShaderMaterial
var _rock_meshes: Array[Mesh] = []
var _low_meshes: Array[Mesh] = []
var _rock_transforms: Array[Array] = []
var _bank_transforms: Array[Array] = []
var _small_transforms: Array[Array] = []
var _low_quality := false
var build_stats: Dictionary = {}

func path_x(z: float) -> float:
	return 14.0 * sin((100.0 - z) * 0.02)

func height_at(x: float, z: float) -> float:
	var d := absf(x - path_x(z))
	var banks := smoothstep(5.5, 33.0, d)
	var base := 0.8 * sin(z * 0.023) + 0.38 * sin(z * 0.064)
	var shelf := 1.8 + 2.2 * sin(z * 0.039 + x * 0.018) + 1.4 * sin(x * 0.087 + z * 0.022)
	var broken := sin(x * 0.31 + sin(z * 0.09)) * sin(z * 0.26) * 0.35
	var flank := smoothstep(65.0, 170.0, d) * (9.0 + 4.0 * sin(z * 0.021 + x * 0.026))
	var signal_clear := 1.0 - smoothstep(11.0, 24.0, Vector2(x - path_x(-140.0), z + 140.0).length())
	return base + (banks * (shelf + broken) + flank) * (1.0 - signal_clear)

func spawn_origin() -> Vector3:
	return Vector3(path_x(100.0), height_at(path_x(100.0), 100.0), 100.0)

func signal_origin() -> Vector3:
	return Vector3(path_x(-140.0), height_at(path_x(-140.0), -140.0), -140.0)

func _ready() -> void:
	_rng.seed = 20260915
	_build_atmosphere()
	_build_material()
	_build_terrain()
	_build_horizon()
	_build_landmarks()
	_build_rocks()
	_build_response()
	_build_dust()
	reset()

func _build_atmosphere() -> void:
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.43, 0.47, 0.59)
	_environment.ambient_light_energy = 0.62
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.tonemap_exposure = 1.05
	_environment.fog_enabled = true
	_environment.fog_mode = Environment.FOG_MODE_DEPTH
	_environment.fog_light_color = Color(0.215, 0.225, 0.31)
	_environment.fog_light_energy = 0.72
	_environment.fog_depth_begin = 95.0
	_environment.fog_depth_end = 1400.0
	_environment.fog_depth_curve = 1.15
	_environment.fog_sky_affect = 0.08
	var world_environment := WorldEnvironment.new()
	world_environment.name = "BasinAtmosphere"
	world_environment.environment = _environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "LowWarmSun"
	sun.rotation_degrees = Vector3(-15.0, -55.0, 0.0)
	sun.light_color = Color(1.0, 0.84, 0.68)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_bias = 0.06
	add_child(sun)

func _build_material() -> void:
	_terrain_material = ShaderMaterial.new()
	_terrain_material.shader = TERRAIN_SHADER
	_terrain_material.set_shader_parameter("basalt_map", load("res://assets/terrain/basalt_albedo.png"))
	_terrain_material.set_shader_parameter("dust_map", load("res://assets/terrain/dust_albedo.png"))
	_terrain_material.set_shader_parameter("normal_map", load("res://assets/terrain/geology_normal.png"))
	_terrain_material.set_shader_parameter("rough_map", load("res://assets/terrain/geology_roughness.png"))
	_strata_material = ShaderMaterial.new()
	_strata_material.shader = STRATA_SHADER
	_strata_material.set_shader_parameter("basalt_map", load("res://assets/terrain/basalt_albedo.png"))
	_strata_material.set_shader_parameter("rough_map", load("res://assets/terrain/geology_roughness.png"))

func _build_terrain() -> void:
	const NX := 155
	const NZ := 193
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tangents := PackedFloat32Array()
	var indices := PackedInt32Array()
	vertices.resize(NX * NZ)
	normals.resize(NX * NZ)
	uvs.resize(NX * NZ)
	tangents.resize(NX * NZ * 4)
	for iz in NZ:
		for ix in NX:
			var x := -192.0 + ix * (384.0 / float(NX - 1))
			var z := -240.0 + iz * 2.5
			var i := iz * NX + ix
			vertices[i] = Vector3(x, height_at(x, z), z)
			var dx := (height_at(x + 0.15, z) - height_at(x - 0.15, z)) / 0.3
			var dz := (height_at(x, z + 0.15) - height_at(x, z - 0.15)) / 0.3
			normals[i] = Vector3(-dx, 1.0, -dz).normalized()
			uvs[i] = Vector2(x, z) * 0.11
			var tangent := Vector3(1.0, dx, 0.0).normalized()
			tangents[i * 4] = tangent.x
			tangents[i * 4 + 1] = tangent.y
			tangents[i * 4 + 2] = tangent.z
			tangents[i * 4 + 3] = 1.0
	for iz in NZ - 1:
		for ix in NX - 1:
			var a := iz * NX + ix
			indices.append_array(PackedInt32Array([a, a + 1, a + NX, a + 1, a + NX + 1, a + NX]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var terrain := MeshInstance3D.new()
	terrain.name = "CollidableDustBasin"
	terrain.mesh = mesh
	terrain.material_override = _terrain_material
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(terrain)
	terrain.create_trimesh_collision()
	build_stats["terrain_triangles"] = indices.size() / 3

func _build_horizon() -> void:
	# A continuous asymmetrical crater ring; four authored high sectors flank a low signal gap.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS := 256
	const RINGS := 17
	for r in RINGS - 1:
		for a in SEGMENTS:
			var p0 := _horizon_point(a, r)
			var p1 := _horizon_point(a + 1, r)
			var p2 := _horizon_point(a, r + 1)
			var p3 := _horizon_point(a + 1, r + 1)
			for p: Vector3 in [p0, p2, p1, p1, p2, p3]:
				st.set_uv(Vector2(p.x, p.z) * 0.008)
				st.add_vertex(p)
	st.generate_normals()
	st.generate_tangents()
	var rim := MeshInstance3D.new()
	rim.name = "AuthoredDistantCaldera"
	rim.mesh = st.commit()
	rim.material_override = _strata_material
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rim)
	build_stats["horizon_triangles"] = SEGMENTS * (RINGS - 1) * 2

func _horizon_point(a: int, r: int) -> Vector3:
	var angle := float(a) / 256.0 * TAU
	var radial := float(r) / 16.0
	var radius := 180.0 + pow(radial, 1.25) * 1250.0
	var x := cos(angle) * radius * 1.12
	var z := sin(angle) * radius
	var foothill := height_at(x, z)
	var peak := 130.0 + 58.0 * sin(angle * 3.0 + 0.4) + 32.0 * sin(angle * 7.0) + 21.0 * sin(angle * 13.0 + 1.0) + 11.0 * sin(angle * 47.0) + 7.0 * sin(angle * 73.0)
	# Signal corridor points north; the far gap frames the mineral silhouette.
	peak *= 1.0 - 0.64 * exp(-pow((angle - 4.71) / 0.24, 2.0))
	var ridge := exp(-pow((radial - 0.37) / 0.19, 2.0)) * peak
	var fissures := absf(sin(angle * 35.0 + sin(radial * 13.0))) * 0.13 + absf(sin(angle * 61.0 + radial * 17.0)) * 0.07
	ridge *= 1.0 - fissures
	# Unequal lava benches interrupt the continuous soft cone profile.
	ridge += sin(radial * 61.0 + angle * 4.0) * 5.5 * smoothstep(0.08, 0.25, radial)
	var height := lerpf(foothill - 3.0, ridge + 10.0, smoothstep(0.0, 0.18, radial))
	return Vector3(x, height, z)

func _build_landmarks() -> void:
	# Three eroded wall fins form an offset cleft; the path remains open for its full 10 m width.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cleft_x := path_x(30.0)
	_append_fault_fin(st, Vector3(cleft_x - 13.5, 0, 31), Vector3(5.5, 14, 9), -0.15, 1)
	_append_fault_fin(st, Vector3(cleft_x - 19.5, 0, 27), Vector3(5.0, 11.5, 11), -0.22, 2)
	_append_fault_fin(st, Vector3(cleft_x + 12.5, 0, 22), Vector3(4.5, 11, 8), 0.16, 3)
	# The second landmark has three mismatched fracture blades and a collapsed foot slab.
	var split_x := path_x(-70.0)
	_append_fault_fin(st, Vector3(split_x + 16.0, 0, -69), Vector3(3.3, 17, 5), 0.25, 4)
	_append_fault_fin(st, Vector3(split_x + 21.7, 0, -72), Vector3(2.8, 13, 4.2), -0.2, 5)
	_append_fault_fin(st, Vector3(split_x + 25.8, 0, -76), Vector3(3.9, 9, 6), -0.35, 6)
	_append_fault_fin(st, Vector3(split_x + 18.8, 0, -65), Vector3(7, 3.0, 7), 0.4, 7)
	st.generate_normals()
	st.generate_tangents()
	var landmark := MeshInstance3D.new()
	landmark.name = "CleftAndFractureLandmarks"
	landmark.mesh = st.commit()
	landmark.material_override = _strata_material
	add_child(landmark)
	landmark.create_trimesh_collision()
	build_stats["landmark_triangles"] = _triangle_count(landmark.mesh)

func _append_fault_fin(st: SurfaceTool, center: Vector3, size: Vector3, yaw: float, salt: int) -> void:
	const SIDES := 11
	const LEVELS := 12
	var points: Array[Vector3] = []
	var base_y := height_at(center.x, center.z) - 0.5
	for ring in LEVELS:
		var t := float(ring) / float(LEVELS - 1)
		var profile := [1.12, 1.05, 0.97, 0.8, 0.91, 0.7, 0.78, 0.63, 0.72, 0.53, 0.59, 0.38]
		var taper: float = profile[ring] + sin(t * 16.0 + salt) * 0.085
		var lean := t * t * size.y * 0.07 * (-1.0 if salt % 2 == 0 else 1.0)
		for side in SIDES:
			var angle := float(side) / SIDES * TAU
			var jagged := 1.0 + sin(side * 2.31 + salt * 1.7 + t * 0.6) * 0.23
			var p := Vector3(cos(angle) * size.x * 0.5 * taper * jagged + lean, t * size.y, sin(angle) * size.z * 0.5 * taper * jagged)
			if ring == LEVELS - 1:
				p.y += sin(side * 3.71 + salt) * size.y * 0.065
			p = p.rotated(Vector3.UP, yaw) + Vector3(center.x, base_y, center.z)
			points.append(p)
	for ring in LEVELS - 1:
		for side in SIDES:
			var a := ring * SIDES + side
			var b := ring * SIDES + (side + 1) % SIDES
			for i: int in [a, b, a + SIDES, b, b + SIDES, a + SIDES]:
				st.set_uv(Vector2(points[i].x + points[i].z, points[i].y) * 0.12)
				st.add_vertex(points[i])
	for side in range(1, SIDES - 1):
		for i: int in [(LEVELS - 1) * SIDES, (LEVELS - 1) * SIDES + side, (LEVELS - 1) * SIDES + side + 1]:
			st.set_uv(Vector2(points[i].x, points[i].z) * 0.12)
			st.add_vertex(points[i])

func _collect_rock_meshes(node: Node, target: Array[Mesh]) -> void:
	if node is MeshInstance3D:
		# Model material islands are collapsed because world rocks share one triplanar material.
		var original: Mesh = (node as MeshInstance3D).mesh
		var combined := SurfaceTool.new()
		combined.begin(Mesh.PRIMITIVE_TRIANGLES)
		for s in original.get_surface_count():
			combined.append_from(original, s, Transform3D.IDENTITY)
		target.append(combined.commit())
	for child in node.get_children():
		_collect_rock_meshes(child, target)

func _build_rocks() -> void:
	if not ResourceLoader.exists(ROCKS_PATH):
		push_warning("WORLD_ROCK_ASSET_PENDING: " + ROCKS_PATH)
		return
	var packed := load(ROCKS_PATH) as PackedScene
	var source := packed.instantiate()
	_collect_rock_meshes(source, _rock_meshes)
	source.free()
	if _rock_meshes.is_empty():
		push_error("WORLD_ROCK_ASSET_EMPTY")
		return
	if ResourceLoader.exists("res://assets/models/rocks_low.glb"):
		var low_source: Node = (load("res://assets/models/rocks_low.glb") as PackedScene).instantiate()
		_collect_rock_meshes(low_source, _low_meshes)
		low_source.free()
	if _low_meshes.size() != _rock_meshes.size():
		_low_meshes = _rock_meshes
	for i in _rock_meshes.size():
		_rock_transforms.append([])
		_bank_transforms.append([])
		_small_transforms.append([])
	# Designed sight-line anchors: asymmetrical gates, split outcrops and long horizontal shelves.
	var anchors := [Vector3(-23, 15, 49), Vector3(36, 12, 17), Vector3(-33, 19, -29), Vector3(30, 14, -86), Vector3(-44, 16, -123), Vector3(43, 22, -169), Vector3(-65, 25, -179), Vector3(82, 19, -51)]
	for anchor: Vector3 in anchors:
		for j in 4:
			var x := anchor.x + j * 3.0 - 5.0
			var z := anchor.z + _rng.randf_range(-5.0, 5.0)
			var size := Vector3(_rng.randf_range(5.0, 10.0), anchor.y * _rng.randf_range(0.45, 1.0), _rng.randf_range(4.0, 8.0))
			_place_rock(x, z, size, false, true, true)
	# Bedrock slabs emerge from bank crests. Placement avoids the entire clear driving corridor.
	for i in 72:
		var z := _rng.randf_range(-180.0, 121.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := path_x(z) + side * _rng.randf_range(10.0, 74.0)
		var size := Vector3(_rng.randf_range(1.6, 5.0), _rng.randf_range(0.5, 2.9), _rng.randf_range(1.5, 4.5))
		_place_rock(x, z, size, false, true)
	for i in 44:
		var z := _rng.randf_range(-170.0, 122.0)
		var x := path_x(z) + _rng.randf_range(6.5, 80.0) * (-1.0 if i % 2 == 0 else 1.0)
		var s := _rng.randf_range(0.12, 0.58)
		_place_rock(x, z, Vector3(s * 1.7, s * 0.7, s), true, false)
	var rock_material := StandardMaterial3D.new()
	rock_material.albedo_color = Color(0.64, 0.59, 0.56)
	rock_material.albedo_texture = load("res://assets/terrain/basalt_albedo.png")
	rock_material.normal_enabled = true
	rock_material.normal_texture = load("res://assets/terrain/geology_normal.png")
	rock_material.normal_scale = 0.75
	rock_material.roughness_texture = load("res://assets/terrain/geology_roughness.png")
	rock_material.roughness = 0.95
	rock_material.uv1_triplanar = true
	rock_material.uv1_scale = Vector3(1.7, 1.7, 1.7)
	var rock_triangles := 0
	for i in _rock_meshes.size():
		_make_multimesh(_rock_meshes[i], _rock_transforms[i], rock_material, false)
		_make_multimesh(_low_meshes[i], _bank_transforms[i], rock_material, false)
		_make_multimesh(_low_meshes[i], _small_transforms[i], rock_material, true)
		rock_triangles += _triangle_count(_rock_meshes[i]) * _rock_transforms[i].size()
		rock_triangles += _triangle_count(_low_meshes[i]) * (_bank_transforms[i].size() + _small_transforms[i].size())
	build_stats["rock_triangles_all_instances"] = rock_triangles
	build_stats["rock_batches"] = _rock_meshes.size() * 3

func _triangle_count(mesh: Mesh) -> int:
	var triangles := 0
	for s in mesh.get_surface_count():
		var array := mesh.surface_get_arrays(s)
		triangles += array[Mesh.ARRAY_INDEX].size() / 3 if array[Mesh.ARRAY_INDEX] != null and array[Mesh.ARRAY_INDEX].size() > 0 else array[Mesh.ARRAY_VERTEX].size() / 3
	return triangles

func _place_rock(x: float, z: float, size: Vector3, small: bool, collidable: bool, hero: bool = false) -> void:
	var footprint := maxf(size.x, size.z) * 0.55
	if absf(x - path_x(z)) < 5.5 + footprint:
		return
	if Vector2(x - signal_origin().x, z + 140.0).length() < 12.0 + footprint:
		return
	var type := _rng.randi_range(0, _rock_meshes.size() - 1)
	var yaw := _rng.randf_range(-PI, PI)
	var basis := Basis.from_euler(Vector3(_rng.randf_range(-0.13, 0.13), yaw, _rng.randf_range(-0.12, 0.12))).scaled(size)
	var bounds := _rock_meshes[type].get_aabb()
	var position := Vector3(x, height_at(x, z) - bounds.position.y * size.y - size.y * 0.12, z)
	var transform := Transform3D(basis, position)
	if small:
		_small_transforms[type].append(transform)
	elif hero:
		_rock_transforms[type].append(transform)
	else:
		_bank_transforms[type].append(transform)
	if collidable and absf(x) < 96.0 and z > -166.0 and z < 126.0:
		var body := StaticBody3D.new()
		body.name = "BedrockCollision"
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = bounds.size * size * Vector3(0.78, 0.82, 0.78)
		shape.shape = box
		shape.position = bounds.get_center() * size
		body.position = position
		body.rotation.y = yaw
		body.add_child(shape)
		add_child(body)

func _make_multimesh(mesh: Mesh, transforms: Array, material: Material, small: bool) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = "SmallBasaltDressing" if small else "AuthoredBasaltClusters"
	instance.multimesh = mm
	instance.material_override = material
	if small:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_small_dressing.append(instance)
	add_child(instance)

func _build_response() -> void:
	_roots_material = ShaderMaterial.new()
	_roots_material.shader = ROOT_SHADER
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var origin := signal_origin()
	for branch in 17:
		var angle := float(branch) / 17.0 * TAU + _rng.randf_range(-0.12, 0.12)
		var length := _rng.randf_range(38.0, 95.0)
		for i in 70:
			var t0 := float(i) / 70.0
			var t1 := float(i + 1) / 70.0
			var points: Array[Vector3] = []
			for t: float in [t0, t1]:
				var bend := angle + sin(t * 13.0 + branch) * 0.085 + sin(t * 31.0) * 0.025
				var center := origin + Vector3(cos(bend), 0.0, sin(bend)) * (1.1 + t * length)
				var width := lerpf(0.12, 0.018, t)
				for side: float in [-1.0, 1.0]:
					var point := center + Vector3(-sin(bend), 0, cos(bend)) * width * side
					point.y = height_at(point.x, point.z) + 0.085
					points.append(point)
			var uv := [Vector2(t0, 0), Vector2(t0, 1), Vector2(t1, 0), Vector2(t1, 1)]
			for index: int in [0, 1, 2, 1, 3, 2]:
				st.set_uv(uv[index])
				st.add_vertex(points[index])
	st.generate_normals()
	var roots := MeshInstance3D.new()
	roots.name = "SubsurfaceResponseRoots"
	roots.mesh = st.commit()
	roots.material_override = _roots_material
	roots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(roots)
	build_stats["response_triangles"] = 17 * 70 * 2

func _build_dust() -> void:
	_dust = CPUParticles3D.new()
	_dust.name = "LowDriftingDust"
	_dust.amount = 64
	_dust.lifetime = 18.0
	_dust.preprocess = 8.0
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(75.0, 0.7, 135.0)
	_dust.position = Vector3(0, 1.3, -25)
	_dust.direction = Vector3(1, 0.01, 0.2)
	_dust.spread = 8.0
	_dust.gravity = Vector3.ZERO
	_dust.initial_velocity_min = 0.5
	_dust.initial_velocity_max = 1.4
	_dust.scale_amount_min = 0.4
	_dust.scale_amount_max = 1.4
	var quad := QuadMesh.new()
	quad.size = Vector2(2.6, 0.18)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.51, 0.37, 0.25, 0.055)
	mat.albedo_texture = load("res://assets/terrain/dust_mask.png")
	quad.material = mat
	_dust.mesh = quad
	add_child(_dust)

func set_response(progress: float, elapsed: float) -> void:
	if _roots_material:
		_roots_material.set_shader_parameter("progress", clampf(progress, 0.0, 1.0))
		_roots_material.set_shader_parameter("elapsed", elapsed)

func set_low_quality(value: bool) -> void:
	_low_quality = value
	for instance in _small_dressing:
		instance.visible = not value
	if _dust:
		_dust.emitting = not value
		_dust.visible = not value

func reset() -> void:
	set_response(0.0, 0.0)
	set_low_quality(_low_quality)
