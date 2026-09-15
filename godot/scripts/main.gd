extends Node3D

const HOME := Vector3(-24, 0, 22)
const HABITAT := Vector3(15, 0, -13)
const BEACON := Vector3(-12, 0, -25)
const TARGETS: Array[Vector3] = [HABITAT, BEACON, HOME]
const CYAN := Color("67e7eb")
const AMBER := Color("e6a15e")
const INK := Color("091621")
var phase: String = "menu"
var mission_stage: int = 0
var time_remaining: float = 90.0
var distance_travelled: float = 0.0
var elapsed: float = 0.0
var rover_speed: float = 0.0
var heading: float = 0.78
var rover_position: Vector3 = HOME
var rover: Node3D
var camera: Camera3D
var lifeforms: Array[Node3D] = []
var wheel_nodes: Array[Node3D] = []
var beacon_core: MeshInstance3D
var world_time: float = 0.0
var ui_clock: float = 0.0
var frames: int = 0
var frame_ms: Array[float] = []
var menu: Control
var hud: Control
var overlay: Control
var overlay_title: Label
var overlay_copy: Label
var overlay_button: Button
var objective: Label
var objective_copy: Label
var distance_label: Label
var timer_label: Label
var speed_label: Label
var action_button: Button
var progress_label: Label
var field_note: Label
var toast_label: Label
var reticle: Label
var toast_seconds: float = 0.0
var material_cache: Dictionary = {}
var rng := RandomNumberGenerator.new()
var evidence_directory: String = ""
const FIRST_PERSON_CAMERA_POSITION := Vector3(0, 3.15, 0.72)
const FIRST_PERSON_CAMERA_PITCH := deg_to_rad(3.5)

func _ready() -> void:
	rng.seed = 4819
	evidence_directory = ProjectSettings.globalize_path("res://evidence")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="):
			evidence_directory = argument.trim_prefix("--evidence-dir=")
	_install_inputs()
	_build_environment()
	_build_terrain()
	_build_rocks()
	_build_lander()
	_build_habitat()
	_build_beacon()
	rover = _build_rover()
	_build_ui()
	_sync_rover()
	_update_ui()
	print("GODOT_RUNTIME_READY " + JSON.stringify(snapshot()))
	if "--smoke" in OS.get_cmdline_user_args():
		_run_smoke.call_deferred()

func _install_inputs() -> void:
	var bindings := {"drive_forward": [KEY_W, KEY_UP], "drive_reverse": [KEY_S, KEY_DOWN], "turn_left": [KEY_A, KEY_LEFT], "turn_right": [KEY_D, KEY_RIGHT], "interact": [KEY_E, KEY_SPACE], "pause_mission": [KEY_ESCAPE, KEY_P], "restart_mission": [KEY_R]}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: int in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("081321")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7ba8ba")
	environment.ambient_light_energy = 0.52
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("182937")
	environment.fog_density = 0.004
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffd5a2")
	sun.light_energy = 1.05
	sun.rotation_degrees = Vector3(-42, -28, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("64b7d4")
	rim.light_energy = 0.8
	rim.rotation_degrees = Vector3(-25, 145, 0)
	add_child(rim)
	camera = Camera3D.new()
	camera.name = "RoverFirstPersonCamera"
	camera.fov = 74
	camera.near = 0.05
	camera.far = 300
	camera.position = Vector3(43, 39, 59)
	add_child(camera)
	camera.look_at(Vector3(-2, 0, -3))
	var planet := _sphere(self, Vector3(-90, 72, -190), Vector3(24, 24, 24), _material("planet", Color("253f56"), 0.94))
	planet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in range(180):
		var star_pos := Vector3(rng.randf_range(-140, 140), rng.randf_range(45, 120), rng.randf_range(-150, -70))
		_sphere(self, star_pos, Vector3.ONE * rng.randf_range(0.045, 0.12), _material("star", Color("86a5b7"), 1.0, Color("86a5b7"), 0.4))

func height_at(x: float, z: float) -> float:
	var d := Vector2(x - 1.0, z - 1.0).length()
	return sin(x * 0.085 + z * 0.023) * 1.15 + cos(z * 0.12) * 0.7 + sin(x * 0.19 - z * 0.14) * 0.3 - 3.1 * exp(-d * d / 75.0) + 1.05 * exp(-pow((d - 12.0) / 2.5, 2)) + 2.4 * exp(-pow((z + 28.0) / 7.0, 2))

func _build_terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments: int = 70
	var step: float = 130.0 / segments
	var color_noise := FastNoiseLite.new()
	color_noise.seed = 4820
	color_noise.frequency = 0.12
	for z in range(segments):
		for x in range(segments):
			var x0: float = -65 + x * step
			var z0: float = -65 + z * step
			var a := Vector3(x0, height_at(x0, z0), z0)
			var b := Vector3(x0 + step, height_at(x0 + step, z0), z0)
			var c := Vector3(x0, height_at(x0, z0 + step), z0 + step)
			var d := Vector3(x0 + step, height_at(x0 + step, z0 + step), z0 + step)
			for point: Vector3 in [a, c, b, b, c, d]:
				var point_tint := Color("746b58").darkened(0.18 + color_noise.get_noise_2d(point.x, point.z) * 0.18)
				var crater_mix := clampf(1.0 - Vector2(point.x, point.z).length() / 12.0, 0, 1)
				surface.set_color(point_tint.lerp(Color("263943"), crater_mix))
				var normal := Vector3(height_at(point.x - 0.2, point.z) - height_at(point.x + 0.2, point.z), 0.4, height_at(point.x, point.z - 0.2) - height_at(point.x, point.z + 0.2)).normalized()
				surface.set_normal(normal)
				surface.add_vertex(point)
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	var material := _material("terrain", Color.WHITE, 1.0)
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material
	add_child(mesh)

func _build_rocks() -> void:
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 1.0
	rock_mesh.height = 1.8
	rock_mesh.radial_segments = 5
	rock_mesh.rings = 2
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = rock_mesh
	multi.instance_count = 90
	for i in range(90):
		var x := rng.randf_range(-58, 58)
		var z := rng.randf_range(-58, 58)
		for target: Vector3 in TARGETS:
			if Vector2(x - target.x, z - target.z).length() < 8:
				x += 12
		var scale_value := rng.randf_range(0.35, 2.7)
		var basis := Basis.from_euler(Vector3(rng.randf() * 0.5, rng.randf() * TAU, 0)).scaled(Vector3(scale_value, scale_value * rng.randf_range(0.5, 1.2), scale_value * 0.9))
		multi.set_instance_transform(i, Transform3D(basis, Vector3(x, height_at(x, z) + scale_value * 0.35, z)))
		multi.set_instance_color(i, Color("34454e").lightened(rng.randf_range(0, 0.15)))
	var rocks := MultiMeshInstance3D.new()
	rocks.multimesh = multi
	var rock_material := _material("rock", Color("263e48"), 0.98)
	rock_material.vertex_color_use_as_albedo = true
	rocks.material_override = rock_material
	add_child(rocks)
	for i in range(14):
		var angle := i * TAU / 14.0
		var position_value := Vector3(sin(angle) * 66, 0, cos(angle) * 66)
		position_value.y = height_at(position_value.x, position_value.z) + 5
		var ridge := _mesh(self, position_value, rock_mesh, _material("ridge", Color("21323d"), 1))
		ridge.scale = Vector3(rng.randf_range(8, 13), rng.randf_range(8, 15), rng.randf_range(7, 11))
		ridge.rotation = Vector3(rng.randf_range(-0.2, 0.2), angle, rng.randf_range(-0.25, 0.25))

func _build_rover() -> Node3D:
	var group := Node3D.new()
	group.name = "RoverR04"
	add_child(group)
	var ivory := _material("ivory", Color("dcd8c8"), 0.6)
	var dark := _material("dark", Color("12242d"), 0.85)
	var metal := _material("metal", Color("66858e"), 0.38)
	_box(group, Vector3(0, 1.1, 0), Vector3(2.8, 0.55, 3.2), dark)
	_box(group, Vector3(0, 1.7, 0), Vector3(2.55, 0.75, 2.85), ivory)
	_box(group, Vector3(0, 2.11, 0), Vector3(2.65, 0.1, 2.95), _material("amber", AMBER, 0.55))
	_box(group, Vector3(0, 2.45, 0.3), Vector3(1.6, 0.55, 1.25), ivory)
	_box(group, Vector3(0, 2.45, -0.35), Vector3(1.2, 0.28, 0.06), dark)
	for side in [-1, 1]:
		for z in [-1.15, 0.0, 1.15]:
			var pivot := Node3D.new()
			group.add_child(pivot)
			pivot.position = Vector3(side * 1.65, 0.72, z)
			var tire := _cylinder(pivot, Vector3.ZERO, 0.65, 0.65, 0.5, dark, 14)
			tire.rotation.z = PI / 2
			var hub := _cylinder(pivot, Vector3.ZERO, 0.28, 0.28, 0.54, metal, 10)
			hub.rotation.z = PI / 2
			wheel_nodes.append(pivot)
			_rod(group, Vector3(side * 1.1, 1.1, z), Vector3(side * 1.65, 0.72, z), 0.09, metal)
		_box(group, Vector3(side * 0.9, 1.75, -1.45), Vector3(0.35, 0.14, 0.08), _material("light", CYAN, 0.3, CYAN, 1.5))
	for i in range(4):
		_box(group, Vector3(-0.6 + i * 0.4, 2.76, 0.3), Vector3(0.32, 0.03, 0.95), dark)
	_rod(group, Vector3(0.8, 2.3, 0.8), Vector3(0.8, 3.8, 0.8), 0.05, metal)
	var dish := _sphere(group, Vector3(0.8, 3.75, 0.8), Vector3(0.5, 0.12, 0.5), ivory)
	dish.rotation.z = 0.6
	return group

func _build_lander() -> void:
	var group := Node3D.new()
	group.position = Vector3(HOME.x - 4, height_at(HOME.x - 4, HOME.z), HOME.z)
	add_child(group)
	var ivory := _material("ivory", Color("dcd8c8"), 0.6)
	var dark := _material("dark", Color("12242d"), 0.85)
	_cylinder(group, Vector3(0, 2.5, 0), 1.55, 1.9, 3.6, ivory, 8)
	_cylinder(group, Vector3(0, 4.4, 0), 1.2, 1.55, 0.35, _material("amber", AMBER, 0.55), 8)
	_sphere(group, Vector3(0, 4.7, 0), Vector3(1.2, 0.8, 1.2), _material("metal", Color("66858e"), 0.38))
	for side in [-1, 1]:
		_box(group, Vector3(side * 3, 3.3, 0), Vector3(2.8, 0.08, 2.1), dark)
		for i in range(4):
			_box(group, Vector3(side * 3 - 1.05 + i * 0.7, 3.37, 0), Vector3(0.035, 0.05, 2.1), ivory)
	for i in range(4):
		var angle := i * PI / 2 + 0.7
		_rod(group, Vector3(sin(angle) * 1.3, 2, cos(angle) * 1.3), Vector3(sin(angle) * 3, 0.2, cos(angle) * 3), 0.1, ivory)
	_ring(self, HOME, 5.5, AMBER)

func _build_habitat() -> void:
	var center := Node3D.new()
	center.position = Vector3(HABITAT.x, height_at(HABITAT.x, HABITAT.z), HABITAT.z)
	add_child(center)
	var shell := _material("shell", Color("244f55"), 0.35)
	var leg := _material("leg", Color("cfbc86"), 0.6)
	var glow := _material("bio", CYAN, 0.28, CYAN, 0.7)
	for i in range(7):
		var angle := i * TAU / 7.0
		var crystal := _cylinder(center, Vector3(sin(angle) * 0.8, 1.2, cos(angle) * 0.8), 0.02, 0.38, rng.randf_range(1.7, 3.1), glow, 5)
		crystal.rotation.z = sin(angle) * 0.2
	for i in range(3):
		var animal := Node3D.new()
		var angle := i * TAU / 3.0 + 0.4
		animal.position = Vector3(cos(angle) * 3.4, 0.75, sin(angle) * 3.4)
		animal.set_meta("base", animal.position)
		animal.set_meta("phase", i * 2.1)
		center.add_child(animal)
		_sphere(animal, Vector3(0, 0.25, 0), Vector3(1.05, 0.65, 1.4), shell)
		_sphere(animal, Vector3(0, 0.16, -1.0), Vector3(0.6, 0.43, 0.55), shell)
		_sphere(animal, Vector3(0, 0.73, 0.05), Vector3(0.33, 0.2, 0.65), glow)
		for side in [-1, 1]:
			_sphere(animal, Vector3(side * 0.25, 0.35, -1.47), Vector3.ONE * 0.105, _material("eyes", AMBER, 0.4, AMBER, 1.2))
			_rod(animal, Vector3(side * 0.3, 0.45, -1.1), Vector3(side * 0.55, 1.22, -1.4), 0.025, leg)
			_sphere(animal, Vector3(side * 0.55, 1.22, -1.4), Vector3.ONE * 0.075, glow)
			for j in range(3):
				var z: float = -0.75 + j * 0.7
				var knee := Vector3(side * 1.2, 0.1, z)
				_rod(animal, Vector3(side * 0.6, 0.1, z), knee, 0.055, leg)
				_rod(animal, knee, Vector3(side * 1.55, -0.7, z + 0.25), 0.04, leg)
		lifeforms.append(animal)
	_ring(self, HABITAT, 5.7, CYAN)
	var beam := _cylinder(center, Vector3(0, 8, 0), 0.035, 0.07, 14, glow, 8)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_beacon() -> void:
	var group := Node3D.new()
	group.position = Vector3(BEACON.x, height_at(BEACON.x, BEACON.z), BEACON.z)
	add_child(group)
	_cylinder(group, Vector3(0, 0.25, 0), 2, 2.6, 0.45, _material("metal", Color("66858e"), 0.38), 10)
	_cylinder(group, Vector3(0, 1.8, 0), 0.45, 0.7, 2.7, _material("dark", Color("12242d"), 0.85), 8)
	beacon_core = _cylinder(group, Vector3(0, 4, 0), 0.18, 0.18, 2, _material("light", CYAN, 0.3, CYAN, 1.5), 10)
	beacon_core.visible = false
	_ring(self, BEACON, 4.5, CYAN)

func _material(key: String, color: Color, roughness: float, emission: Color = Color.BLACK, energy: float = 0.0) -> StandardMaterial3D:
	if material_cache.has(key):
		return material_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if energy > 0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	material_cache[key] = material
	return material

func _box(parent: Node3D, position_value: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return _mesh(parent, position_value, mesh, material)

func _sphere(parent: Node3D, position_value: Vector3, scale_value: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1
	mesh.height = 2
	mesh.radial_segments = 16
	mesh.rings = 8
	var instance := _mesh(parent, position_value, mesh, material)
	instance.scale = scale_value
	return instance

func _cylinder(parent: Node3D, position_value: Vector3, top: float, bottom: float, height: float, material: Material, sides: int = 12) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	return _mesh(parent, position_value, mesh, material)

func _mesh(parent: Node3D, position_value: Vector3, mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position_value
	parent.add_child(instance)
	return instance

func _rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var instance := _cylinder(parent, (a + b) * 0.5, radius, radius, a.distance_to(b), material, 6)
	instance.quaternion = Quaternion(Vector3.UP, (b - a).normalized())

func _ring(parent: Node3D, location: Vector3, radius: float, color: Color) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.035
	mesh.outer_radius = radius + 0.035
	mesh.rings = 48
	mesh.ring_segments = 6
	_mesh(parent, Vector3(location.x, height_at(location.x, location.z) + 0.08, location.z), mesh, _material("ring" + color.to_html(), color, 0.5, color, 0.45))

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var header := _label(root, "↗  DEEP SPACE / ROVER PROGRAM", 18, Vector2(42, 32), Vector2(520, 40))
	header.modulate = CYAN
	_label(root, "FIRST CONTACT  /  KEPLER–186F", 12, Vector2(980, 42), Vector2(410, 28))
	_label(root, "LOCAL EXPEDITION  ·  GODOT 4.7.2", 10, Vector2(42, 862), Vector2(400, 24))
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	var menu_shade := ColorRect.new()
	menu_shade.color = Color(0.012, 0.035, 0.052, 0.58)
	menu_shade.position = Vector2(70, 210)
	menu_shade.size = Vector2(700, 560)
	menu_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(menu_shade)
	var archive_shade := ColorRect.new()
	archive_shade.color = Color(0.012, 0.035, 0.052, 0.65)
	archive_shade.position = Vector2(1005, 235)
	archive_shade.size = Vector2(370, 485)
	archive_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(archive_shade)
	_label(menu, "EXPEDITION 04   /   ALIEN LIFE SURVEY", 13, Vector2(105, 238), Vector2(620, 30)).modulate = CYAN
	_label(menu, "SIGNAL\nIN THE DUST.", 78, Vector2(100, 290), Vector2(700, 200))
	_label(menu, "A living signal. A closing storm.\nOne small rover. A whole new form of life.", 20, Vector2(105, 510), Vector2(680, 74)).modulate = Color("adc1c9")
	var start_button := _button(menu, "BEGIN EXPEDITION   ↗", Vector2(105, 620), Vector2(320, 64))
	start_button.pressed.connect(start_mission)
	start_button.grab_focus()
	_label(menu, "WASD / ARROWS  DRIVE      E  OBSERVE      ESC  PAUSE", 12, Vector2(105, 713), Vector2(700, 26)).modulate = Color("87a6b4")
	var archive := TextureRect.new()
	archive.texture = load("res://assets/first-contact-v3.png")
	archive.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	archive.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	archive.position = Vector2(1030, 264)
	archive.size = Vector2(320, 180)
	menu.add_child(archive)
	_label(menu, "01   FIND THE LIFE\n\n02   PROTECT THE HABITAT\n\n03   BRING THE DATA HOME", 17, Vector2(1030, 480), Vector2(330, 220))
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	hud.hide()
	reticle = Label.new()
	reticle.text = "＋"
	reticle.set_anchors_preset(Control.PRESET_CENTER)
	reticle.position = Vector2(-16, -18)
	reticle.size = Vector2(32, 32)
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle.add_theme_font_size_override("font_size", 22)
	reticle.add_theme_color_override("font_color", CYAN)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(reticle)
	progress_label = _label(hud, "CURRENT OBJECTIVE  /  01 OF 03", 12, Vector2(42, 142), Vector2(410, 28))
	progress_label.modulate = CYAN
	objective = _label(hud, "Find the life", 28, Vector2(42, 188), Vector2(520, 52))
	objective_copy = _label(hud, "Follow the cyan marker.", 16, Vector2(42, 244), Vector2(410, 74))
	objective_copy.modulate = Color("a0bbc8")
	distance_label = _label(hud, "58 m", 36, Vector2(42, 330), Vector2(250, 60))
	distance_label.modulate = CYAN
	timer_label = _label(hud, "STORM  01:30", 28, Vector2(1070, 142), Vector2(330, 55))
	speed_label = _label(hud, "0.0 M/S", 15, Vector2(1070, 202), Vector2(310, 35))
	field_note = _label(hud, "", 14, Vector2(42, 470), Vector2(370, 190))
	field_note.modulate = Color("a9c8c8")
	_label(hud, "WASD / ARROWS  DRIVE      E  INTERACT      ESC  PAUSE", 13, Vector2(42, 807), Vector2(760, 35)).modulate = Color("8cacba")
	action_button = _button(hud, "OBSERVE LIFE   [E]", Vector2(560, 735), Vector2(330, 64))
	action_button.pressed.connect(interact)
	toast_label = _label(root, "", 15, Vector2(400, 95), Vector2(700, 42))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.modulate = CYAN
	overlay = ColorRect.new()
	(overlay as ColorRect).color = Color(0.015, 0.04, 0.065, 0.93)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	overlay_title = _label(overlay, "", 55, Vector2(380, 260), Vector2(760, 90))
	overlay_copy = _label(overlay, "", 21, Vector2(380, 375), Vector2(680, 175))
	overlay_copy.modulate = Color("adc7ce")
	overlay_button = _button(overlay, "CONTINUE   ↗", Vector2(380, 620), Vector2(420, 70))
	overlay_button.pressed.connect(_overlay_continue)
	overlay.hide()

func _label(parent: Control, text: String, font_size: int, position_value: Vector2, dimensions: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position_value
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e5f0ee"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Control, text: String, position_value: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = position_value
	button.size = dimensions
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", INK)
	var style := StyleBoxFlat.new()
	style.bg_color = CYAN
	style.content_margin_left = 20
	style.content_margin_right = 20
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("acf8ee")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	parent.add_child(button)
	return button

func _activate_first_person_camera() -> void:
	if camera.get_parent() != rover:
		camera.reparent(rover)
	camera.position = FIRST_PERSON_CAMERA_POSITION
	camera.rotation = Vector3(FIRST_PERSON_CAMERA_PITCH, 0, 0)
	camera.current = true

func start_mission() -> void:
	phase = "playing"
	_activate_first_person_camera()
	mission_stage = 0
	time_remaining = 90
	elapsed = 0
	distance_travelled = 0
	rover_position = HOME
	rover_speed = 0
	heading = 0.78
	menu.hide()
	hud.show()
	overlay.hide()
	beacon_core.hide()
	field_note.text = ""
	_toast("SURFACE LINK ESTABLISHED · FOLLOW THE LIVING SIGNAL")
	_update_ui()

func _physics_process(delta: float) -> void:
	if phase != "playing":
		return
	var forward := Input.get_axis("drive_reverse", "drive_forward")
	var steer := Input.get_axis("turn_left", "turn_right")
	var hazard := Vector2(rover_position.x - 1, rover_position.z - 1).length() < 10
	var max_speed: float = 6.0 if hazard else 12.0
	rover_speed = move_toward(rover_speed, forward * max_speed, delta * (18.0 if forward != 0 else 24.0))
	heading += steer * delta * 1.65 * (-1 if rover_speed < -0.1 else 1)
	var old_position := rover_position
	rover_position += Vector3(sin(heading), 0, -cos(heading)) * rover_speed * delta
	rover_position.x = clampf(rover_position.x, -47, 47)
	rover_position.z = clampf(rover_position.z, -47, 47)
	distance_travelled += old_position.distance_to(rover_position)
	time_remaining = maxf(0, time_remaining - delta * (1.6 if hazard else 1.0))
	elapsed += delta
	_sync_rover()
	if time_remaining <= 0:
		phase = "failure"
		_show_overlay("Lost to the dust.", "The storm reached the habitat before you could return.\nTry the outer ridge to keep your traction.", "TRY AGAIN   ↗")

func _process(delta: float) -> void:
	world_time += delta
	frames += 1
	if delta > 0 and delta < 0.5:
		frame_ms.append(delta * 1000)
		if frame_ms.size() > 600:
			frame_ms.pop_front()
	for life: Node3D in lifeforms:
		var base: Vector3 = life.get_meta("base")
		var offset: float = life.get_meta("phase")
		life.position = base + Vector3(sin(world_time * 0.32 + offset) * 0.2, sin(world_time * 1.8 + offset) * 0.08, cos(world_time * 0.32 + offset) * 0.2)
		life.rotation.y = offset + sin(world_time * 0.35 + offset) * 0.35
	if phase == "menu":
		var destination := Vector3(43, 39, 59)
		var focus := Vector3(-2, 0, -3)
		camera.position = camera.position.lerp(destination, 1.0 - exp(-delta * 2.5))
		camera.look_at(focus)
	elif camera.get_parent() == rover:
		var movement_ratio := clampf(absf(rover_speed) / 12.0, 0.0, 1.0)
		var bob := sin(elapsed * 8.0) * 0.018 * movement_ratio
		var camera_target := FIRST_PERSON_CAMERA_POSITION + Vector3(0, bob, 0)
		camera.position = camera.position.lerp(camera_target, 1.0 - exp(-delta * 9.0))
		camera.rotation.x = lerp_angle(camera.rotation.x, FIRST_PERSON_CAMERA_PITCH + sin(elapsed * 8.0) * 0.004 * movement_ratio, 1.0 - exp(-delta * 9.0))
	ui_clock += delta
	if ui_clock > 0.1:
		_update_ui()
		ui_clock = 0
	if toast_seconds > 0:
		toast_seconds -= delta
		if toast_seconds <= 0:
			toast_label.text = ""

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		interact()
	if event.is_action_pressed("pause_mission"):
		if phase == "playing":
			phase = "paused"
			_show_overlay("Take a breath.", "Your rover is holding position.\nThe storm clock is paused.", "RESUME EXPEDITION   ↗")
		elif phase == "paused":
			_overlay_continue()
	if event.is_action_pressed("restart_mission") and phase in ["success", "failure"]:
		start_mission()

func _sync_rover() -> void:
	rover.position = rover_position + Vector3(0, height_at(rover_position.x, rover_position.z) + 0.03, 0)
	rover.rotation.y = -heading
	for wheel: Node3D in wheel_nodes:
		wheel.rotation.x = -distance_travelled / 0.65

func target_distance() -> float:
	var target := TARGETS[mission_stage]
	return Vector2(rover_position.x - target.x, rover_position.z - target.z).length()

func interact() -> void:
	if phase != "playing" or target_distance() > 6:
		return
	if mission_stage == 0:
		mission_stage = 1
		phase = "discovery"
		field_note.text = "LIFE ARCHIVE / 001\nVITRA\nGlassy shell · Six limbs\nLight-sensitive · Non-aggressive"
		_show_overlay("First contact: Vitra.", "Three glass-shelled organisms gather around a living crystal bloom. Their cyan pulse follows your rover's light.\n\nObserve without disturbing. Protect their habitat before the storm arrives.", "PROTECT THE HABITAT   ↗")
	elif mission_stage == 1:
		mission_stage = 2
		beacon_core.show()
		_toast("HABITAT BEACON ONLINE · BRING THE LIFE DATA HOME")
	else:
		phase = "success"
		_show_overlay("We are not alone.", "The habitat is protected. Vitra is the first entry in humanity's living-world archive.\n\n%d metres travelled · %d seconds · 1 lifeform documented" % [int(distance_travelled), int(elapsed)], "EXPLORE AGAIN   ↗")
	_update_ui()

func _update_ui() -> void:
	if not is_instance_valid(objective):
		return
	var titles := ["Find the life", "Protect the habitat", "Bring the data home"]
	var copies := ["Follow the cyan marker.\nSomething living is moving in the dust.", "The Vitra colony is real.\nReach the ridge protection beacon.", "Habitat protected.\nReturn to the amber lander ring."]
	objective.text = titles[mission_stage]
	objective_copy.text = copies[mission_stage]
	progress_label.text = "CURRENT OBJECTIVE  /  0%d OF 03" % (mission_stage + 1)
	distance_label.text = "%d METRES" % int(target_distance())
	var seconds := int(ceil(time_remaining))
	timer_label.text = "STORM  %02d:%02d" % [seconds / 60, seconds % 60]
	speed_label.text = "%.1f M/S  ·  ROVER R–04" % absf(rover_speed)
	action_button.text = ["OBSERVE LIFE   [E]", "DEPLOY BEACON   [E]", "RETURN TO LANDER   [E]"][mission_stage]
	action_button.visible = phase == "playing" and target_distance() <= 6
	timer_label.modulate = Color("ff9673") if time_remaining < 20 else Color.WHITE

func _show_overlay(title: String, copy: String, button_text: String) -> void:
	rover_speed = 0
	overlay_title.text = title
	overlay_copy.text = copy
	overlay_button.text = button_text
	overlay.show()
	overlay_button.grab_focus()

func _overlay_continue() -> void:
	if phase in ["paused", "discovery"]:
		phase = "playing"
		overlay.hide()
	else:
		start_mission()

func _toast(text: String) -> void:
	toast_label.text = text
	toast_seconds = 4

func snapshot() -> Dictionary:
	return {"phase":phase,"stage":mission_stage,"position":{"x":rover_position.x,"z":rover_position.z},"heading":heading,"view":"first_person" if camera.get_parent() == rover else "menu_overview","time":time_remaining,"distance":distance_travelled,"lifeforms":lifeforms.size(),"frames":frames,"targetDistance":target_distance()}

func metrics() -> Dictionary:
	var ordered := frame_ms.duplicate()
	ordered.sort()
	var count := ordered.size()
	return {"fps":Engine.get_frames_per_second(),"sampleFrames":count,"p50ms":ordered[int((count - 1) * 0.5)] if count else 0,"p95ms":ordered[int((count - 1) * 0.95)] if count else 0,"p99ms":ordered[int((count - 1) * 0.99)] if count else 0,"drawCalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"staticMemoryBytes":Performance.get_monitor(Performance.MEMORY_STATIC),"display":DisplayServer.get_name(),"viewport":str(get_viewport().get_visible_rect().size)}

func _run_smoke() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(evidence_directory.path_join("menu.png"))
	start_mission()
	var before := snapshot()
	var first_person_ok: bool = before.view == "first_person"
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().create_timer(0.7).timeout
	key = InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = false
	Input.parse_input_event(key)
	var moved := snapshot()
	var heading_before := heading
	var steer_key := InputEventKey.new()
	steer_key.physical_keycode = KEY_A
	steer_key.pressed = true
	Input.parse_input_event(steer_key)
	await get_tree().create_timer(0.2).timeout
	steer_key = InputEventKey.new()
	steer_key.physical_keycode = KEY_A
	steer_key.pressed = false
	Input.parse_input_event(steer_key)
	var heading_after_left := heading
	steer_key = InputEventKey.new()
	steer_key.physical_keycode = KEY_D
	steer_key.pressed = true
	Input.parse_input_event(steer_key)
	await get_tree().create_timer(0.2).timeout
	steer_key = InputEventKey.new()
	steer_key.physical_keycode = KEY_D
	steer_key.pressed = false
	Input.parse_input_event(steer_key)
	var heading_after_right := heading
	var steering_ok: bool = heading_after_left < heading_before and heading_after_right > heading_after_left
	rover_position = HABITAT + Vector3(0, 0, 4)
	_sync_rover()
	interact()
	var observed := snapshot()
	_overlay_continue()
	rover_position = BEACON + Vector3(0, 0, 4)
	interact()
	var protected := snapshot()
	rover_position = HOME + Vector3(0, 0, 4)
	interact()
	var returned := snapshot()
	start_mission()
	time_remaining = 0.01
	await get_tree().create_timer(0.15).timeout
	var failure := snapshot()
	var passed: bool = first_person_ok and float(moved.distance) > 0.5 and steering_ok and observed.phase == "discovery" and protected.stage == 2 and returned.phase == "success" and failure.phase == "failure"
	var result := {"passed":passed,"firstPerson":first_person_ok,"before":before,"moved":moved,"steering":{"before":heading_before,"afterLeft":heading_after_left,"afterRight":heading_after_right,"ok":steering_ok},"observed":observed,"protected":protected,"returned":returned,"failure":failure,"engine":Engine.get_version_info()}
	var file := FileAccess.open(evidence_directory.path_join("smoke.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print("GODOT_SMOKE " + JSON.stringify(result))
	if DisplayServer.get_name() != "headless":
		start_mission()
		rover_position = HABITAT + Vector3(0, 0, 6)
		_sync_rover()
		await get_tree().create_timer(1.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(evidence_directory.path_join("life-runtime.png"))
		var performance_data := metrics()
		var performance_file := FileAccess.open(evidence_directory.path_join("performance.json"), FileAccess.WRITE)
		performance_file.store_string(JSON.stringify(performance_data, "  "))
		performance_file.close()
		print("GODOT_GRAPHICAL_METRICS " + JSON.stringify(performance_data))
		interact()
		await get_tree().create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(evidence_directory.path_join("discovery.png"))
	get_tree().quit(0 if passed else 1)
