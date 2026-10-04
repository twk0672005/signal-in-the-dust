extends Node3D

signal completed
var active: bool = false
var paused: bool = false
var elapsed: float = 0.0
var progress: float = 0.0
var ribs: Array[Node3D] = []
var base_rotations: Array[Vector3] = []
var light: OmniLight3D
var gold_lights: Array[OmniLight3D] = []
var tree_root: Node3D
var tree_glow_materials: Array[StandardMaterial3D] = []
var ring: MeshInstance3D
var ring_material: StandardMaterial3D
var clock: float = 0.0
const DURATION: float = 24.0

func _ready() -> void:
	var packed = load("res://assets/world_tree_v6/world_tree.glb")
	if packed is PackedScene:
		var model: Node3D = packed.instantiate()
		model.name = "GoldenWorldTree"
		model.scale = Vector3.ONE
		# Keep the interaction beacon on the road while staging the authored
		# root mass beyond it, so a close third-person camera still sees the full
		# trunk silhouette and the surrounding landscape.
		model.position = Vector3(0.0, 0.0, -26.0)
		add_child(model)
		tree_root = model
		# The tree is the endpoint landmark, not a wall of opaque foliage. Keep
		# the authored gaps and disable leaf shadows for Compatibility Web cost.
		for node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := node as MeshInstance3D
			if mesh_node == null or mesh_node.mesh == null: continue
			var material_name := mesh_node.name.to_lower()
			# Duplicate the imported GLB material instead of replacing it.  This
			# preserves the baked bark/branch/leaf albedo texture and UV detail;
			# only the runtime tint, emission and shadow policy are tuned here.
			var imported_material: Material = mesh_node.get_active_material(0)
			var tree_material: StandardMaterial3D
			if imported_material is StandardMaterial3D:
				tree_material = (imported_material as StandardMaterial3D).duplicate()
			else:
				tree_material = StandardMaterial3D.new()
			tree_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			tree_material.roughness = 0.82
			if material_name.contains("leaves"):
				tree_material.albedo_color = Color(1.00, 0.86, 0.52, 1.0)
				tree_material.roughness = 0.74
				tree_material.emission_enabled = true
				tree_material.emission = Color("d6ad57")
				tree_material.emission_energy_multiplier = 0.24
				mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			elif material_name.contains("luminous") or material_name.contains("vein"):
				tree_material.albedo_color = Color(1.02, 1.00, 0.94, 1.0)
				tree_material.roughness = 0.52
				tree_material.emission_enabled = true
				tree_material.emission = Color("fff8dc")
				tree_material.emission_energy_multiplier = 2.10
				tree_glow_materials.append(tree_material)
			elif material_name.contains("branch"):
				tree_material.albedo_color = Color(1.46, 1.38, 1.20, 1.0)
				tree_material.emission_enabled = true
				tree_material.emission = Color("ead9a8")
				tree_material.emission_energy_multiplier = 0.26
			else:
				tree_material.albedo_color = Color(1.58, 1.45, 1.22, 1.0)
				tree_material.emission_enabled = true
				tree_material.emission = Color("d8bf80")
				tree_material.emission_energy_multiplier = 0.18
			mesh_node.material_override = tree_material
		for part in model.find_children("rib_*", "Node3D",true,false):
			ribs.append(part)
			base_rotations.append(part.rotation)
	var body := StaticBody3D.new()
	body.name = "SignalCollision"
	var collision := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	# Match the authored trunk base so ordinary physics cannot enter the
	# silhouette; the interaction and contact presentation envelopes handle the
	# larger cinematic reveal distance without blocking the road.
	cylinder.radius = 7.5
	cylinder.height = 8.0
	collision.shape = cylinder
	collision.position.y = 4.0
	body.add_child(collision)
	add_child(body)
	light = OmniLight3D.new()
	light.position = Vector3(0.0, 8.0, -24.0)
	light.light_color = Color("e7bd61")
	light.light_energy = 1.05
	light.omni_range = 42.0
	light.shadow_enabled = false
	add_child(light)
	for spec in [
		{"position":Vector3(-15.0, 24.0, -32.0), "energy":1.15, "range":64.0},
		{"position":Vector3(18.0, 62.0, -40.0), "energy":0.92, "range":90.0}
	]:
		var gold := OmniLight3D.new()
		gold.position = spec["position"]
		gold.light_color = Color("f1c96b")
		gold.light_energy = spec["energy"]
		gold.omni_range = spec["range"]
		gold.shadow_enabled = false
		add_child(gold)
		gold_lights.append(gold)
	ring = MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.97
	mesh.outer_radius = 1.03
	mesh.rings = 64
	mesh.ring_segments = 6
	ring.mesh = mesh
	ring_material = StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.albedo_color = Color(0.91,0.64,0.20,0.0)
	ring.material_override = ring_material
	ring.position.y = 0.12
	add_child(ring)

func begin() -> void:
	if active or progress >= 1.0: return
	active = true
	elapsed = 0.0

func reset() -> void:
	active = false
	paused = false
	elapsed = 0.0
	progress = 0.0
	clock = 0.0
	for i in range(ribs.size()): ribs[i].rotation = base_rotations[i]
	if is_instance_valid(tree_root): tree_root.scale = Vector3.ONE
	if is_instance_valid(ring): ring.visible = false

func _process(delta: float) -> void:
	if paused: return
	clock += delta
	if active:
		elapsed += delta
		progress = minf(elapsed/DURATION,1.0)
		var opening: float = smoothstep(0.16,0.78,progress)
		for i in range(ribs.size()):
			var angle: float = float(i)*TAU/maxi(1,ribs.size())
			ribs[i].rotation = base_rotations[i]+Vector3(cos(angle)*opening*0.38,0,sin(angle)*opening*0.38)
		ring.visible = elapsed > 3.0 and elapsed < 21.0
		var wave: float = fmod(maxf(0.0,elapsed-3.0),6.0)/6.0
		ring.scale = Vector3.ONE*(1.0+wave*30.0)
		ring_material.albedo_color.a = (1.0-wave)*0.38
		if progress >= 1.0:
			active = false
			completed.emit()
	var pulse := 1.0 + sin(clock*1.4)*0.08 + progress*0.32
	light.light_energy = 1.05*pulse
	for i in gold_lights.size():
		gold_lights[i].light_energy = (1.50 if i == 0 else 1.20) * (0.94 + sin(clock*(1.05 + i*.22))*0.06 + progress*.24)
	for material in tree_glow_materials:
		material.emission_energy_multiplier = 1.00 + sin(clock*1.7)*0.08 + progress*.14
	if is_instance_valid(tree_root): tree_root.scale = Vector3.ONE * (1.0 + sin(clock*.24)*.0025)






