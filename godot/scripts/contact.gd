extends Node3D

signal completed
var active: bool = false
var paused: bool = false
var elapsed: float = 0.0
var progress: float = 0.0
var ribs: Array[Node3D] = []
var base_rotations: Array[Vector3] = []
var light: OmniLight3D
var ring: MeshInstance3D
var ring_material: StandardMaterial3D
var clock: float = 0.0
const DURATION: float = 24.0

func _ready() -> void:
	var packed = load("res://assets/models/signal.glb")
	if packed is PackedScene:
		var model: Node3D = packed.instantiate()
		model.scale = Vector3.ONE*1.65
		add_child(model)
		for part in model.find_children("rib_*", "Node3D",true,false):
			ribs.append(part)
			base_rotations.append(part.rotation)
	var body := StaticBody3D.new()
	body.name = "SignalCollision"
	var collision := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 1.1
	cylinder.height = 7.0
	collision.shape = cylinder
	collision.position.y = 3.5
	body.add_child(collision)
	add_child(body)
	light = OmniLight3D.new()
	light.position.y = 4.0
	light.light_color = Color("65d5d0")
	light.light_energy = 0.9
	light.omni_range = 15.0
	add_child(light)
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
	ring_material.albedo_color = Color(0.32,0.82,0.78,0.0)
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
	light.light_energy = 0.85 + sin(clock*(1.0+progress*2.0))*0.12 + progress*1.7
