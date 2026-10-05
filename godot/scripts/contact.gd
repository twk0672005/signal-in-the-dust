extends Node3D

signal completed
var active: bool = false
var paused: bool = false
var elapsed: float = 0.0
var progress: float = 0.0
var linked: bool = false
var light: OmniLight3D
var gold_lights: Array[OmniLight3D] = []
var tree_root: Node3D
var ring: MeshInstance3D
var ring_material: StandardMaterial3D
var clock: float = 0.0
var reply_elapsed: float = -1.0
var signal_material: ShaderMaterial
const DURATION: float = 24.0
const RESPONSE_SECONDS: float = 6.0
const REPLY_SECONDS: float = 3.0

func _ready() -> void:
	var packed = load("res://assets/world_tree_v6/world_tree.glb")
	if packed is PackedScene:
		var model: Node3D = packed.instantiate()
		model.name = "GoldenWorldTree"
		model.position = Vector3(0.0, 0.0, -26.0)
		add_child(model)
		tree_root = model
		for raw in model.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := raw as MeshInstance3D
			if mesh_node == null or mesh_node.mesh == null: continue
			var material_name := mesh_node.name.to_lower()
			if material_name.contains("luminous") or material_name.contains("vein"):
				# The current model has merged vein geometry, not the old rib pivots.
				# Sweep the actual branches with a visible travelling reply.
				signal_material = ShaderMaterial.new()
				signal_material.shader = preload("res://shaders/contact_signal.gdshader")
				mesh_node.material_override = signal_material
				mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				continue
			var imported_material := mesh_node.get_active_material(0)
			var material: StandardMaterial3D
			if imported_material is StandardMaterial3D:
				material = imported_material.duplicate()
			else:
				material = StandardMaterial3D.new()
			material.roughness = 0.82
			material.emission_enabled = true
			if material_name.contains("leaves"):
				material.albedo_color = Color(0.82, 0.69, 0.38, 1.0)
				material.roughness = 0.74
				material.emission = Color("d6ad57")
				material.emission_energy_multiplier = 0.08
				mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			elif material_name.contains("branch"):
				material.albedo_color = Color(0.70, 0.65, 0.48, 1.0)
				material.emission = Color("ead9a8")
				material.emission_energy_multiplier = 0.035
			else:
				material.albedo_color = Color(0.63, 0.59, 0.45, 1.0)
				material.emission = Color("d8bf80")
				material.emission_energy_multiplier = 0.025
			mesh_node.material_override = material
	var body := StaticBody3D.new()
	body.name = "SignalCollision"
	var collision := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 7.5
	cylinder.height = 8.0
	collision.shape = cylinder
	collision.position = Vector3(0.0, 4.0, -26.0)
	body.add_child(collision)
	add_child(body)
	light = OmniLight3D.new()
	light.position = Vector3(0.0, 8.0, -24.0)
	light.light_color = Color("e7bd61")
	light.light_energy = 1.05
	light.omni_range = 42.0
	add_child(light)
	for position in [Vector3(-15,24,-32), Vector3(18,62,-40)]:
		var gold := OmniLight3D.new()
		gold.position = position
		gold.light_color = Color("f1c96b")
		gold.light_energy = 1.15
		gold.omni_range = 90.0
		add_child(gold)
		gold_lights.append(gold)
	ring = MeshInstance3D.new()
	ring.name = "ContactPulseWave"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.90
	mesh.outer_radius = 1.10
	mesh.rings = 64
	mesh.ring_segments = 6
	ring.mesh = mesh
	ring_material = StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.albedo_color = Color(1.0, 0.87, 0.51, 0.0)
	ring.material_override = ring_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.visible = false

func begin() -> void:
	if active or linked: return
	active = true
	elapsed = 0.0
	progress = 0.0
	reply_elapsed = -1.0

func observe() -> bool:
	if reply_elapsed >= 0.0: return false
	reply_elapsed = 0.0
	return true

func can_confirm() -> bool:
	return active and elapsed >= RESPONSE_SECONDS

func feedback_stage() -> int:
	return 2 if linked or can_confirm() else (1 if elapsed >= 2.0 else 0)

func confirm_response() -> bool:
	if not can_confirm(): return false
	_finish()
	return true

func _finish() -> void:
	active = false
	linked = true
	elapsed = DURATION
	progress = 1.0
	reply_elapsed = 0.0
	completed.emit()

func reply() -> bool:
	if not linked or active or reply_elapsed >= 0.0: return false
	reply_elapsed = 0.0
	return true

func restore_completion(value: bool) -> void:
	active = false
	paused = false
	linked = value
	elapsed = DURATION if value else 0.0
	progress = 1.0 if value else 0.0
	reply_elapsed = -1.0
	if is_instance_valid(ring): ring.visible = false
	if is_instance_valid(signal_material):
		signal_material.set_shader_parameter("linked", 1.0 if linked else 0.0)
		signal_material.set_shader_parameter("front_strength", 0.0)
		signal_material.set_shader_parameter("responding", 1.0 if linked else 0.0)

func reset() -> void:
	restore_completion(false)
	clock = 0.0

func _process(delta: float) -> void:
	if paused: return
	clock += delta
	if active:
		elapsed += delta
		progress = minf(elapsed / DURATION, 1.0)
		if progress >= 1.0: _finish()
	if reply_elapsed >= 0.0:
		reply_elapsed += delta
		if reply_elapsed >= REPLY_SECONDS: reply_elapsed = -1.0
	var pulse_time := elapsed if active else reply_elapsed
	var pulsing := active or reply_elapsed >= 0.0
	if is_instance_valid(signal_material):
		var front := -40.0
		if active:
			front = lerpf(-20.0, 255.0, elapsed / 2.0) if elapsed < 2.0 else (lerpf(255.0, 0.0, clampf((elapsed - 2.0) / 4.0, 0.0, 1.0)) if elapsed < RESPONSE_SECONDS else lerpf(255.0, 0.0, fmod(elapsed-RESPONSE_SECONDS, 4.0)/4.0))
		elif reply_elapsed >= 0.0:
			front = lerpf(0.0, 255.0, reply_elapsed / REPLY_SECONDS)
		signal_material.set_shader_parameter("front_height", front)
		signal_material.set_shader_parameter("front_strength", 1.0 if pulsing else 0.0)
		signal_material.set_shader_parameter("linked", 1.0 if linked else 0.0)
		signal_material.set_shader_parameter("responding", 1.0 if linked or (active and elapsed >= 2.0) else 0.0)
	if is_instance_valid(ring):
		ring.visible = pulsing
		if pulsing:
			var wave := fmod(maxf(0.0, pulse_time), REPLY_SECONDS) / REPLY_SECONDS
			ring.position = Vector3(0.0, 9.0 + wave * 24.0, -26.0)
			ring.scale = Vector3(8.0 + wave * 160.0, 2.0, 8.0 + wave * 160.0)
			var responding := linked or (active and elapsed >= 2.0)
			ring_material.albedo_color = Color(0.12, 0.94, 0.84, (1.0 - wave) * 0.82) if responding else Color(1.0, 0.72, 0.28, (1.0 - wave) * 0.82)
	var pulse := 1.0 + (0.40 if linked else 0.0) + (sin(clock * 3.0) * 0.25 + 0.35 if pulsing else 0.0)
	light.light_energy = 1.05 * pulse
	for gold in gold_lights: gold.light_energy = 1.15 * pulse
