extends CharacterBody3D

var terrain: Node3D
var heading: float = 0.0
var speed: float = 0.0
var distance_travelled: float = 0.0
var driving: bool = false
var reduced_motion: bool = false
var camera: Camera3D
var camera_rig: Node3D
var model: Node3D
var wheels: Array[Node3D] = []
var look_offset := Vector2.ZERO
var motion_clock: float = 0.0
var last_collision_count: int = 0
const CRUISE_SPEED: float = 1.65

func configure(value: Node3D) -> void:
	terrain = value

func _ready() -> void:
	name = "SurveyRover"
	floor_max_angle = deg_to_rad(38.0)
	floor_snap_length = 0.8
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 1.0, 2.3)
	shape.shape = box
	shape.position.y = 0.52
	add_child(shape)
	var packed = load("res://assets/models/rover.glb")
	if packed is PackedScene:
		model = packed.instantiate()
		add_child(model)
		for part in model.find_children("wheel_*", "Node3D", true, false):
			wheels.append(part)
	camera_rig = Node3D.new()
	camera_rig.name = "SensorMount"
	camera_rig.position = Vector3(0, 1.40, -0.43)
	add_child(camera_rig)
	camera = Camera3D.new()
	camera.name = "FirstPersonCamera"
	camera.fov = 72
	camera.near = 0.06
	camera.far = 650
	camera.rotation.x = -0.10
	camera_rig.add_child(camera)
	reset()

func reset() -> void:
	heading = 0.0
	speed = 0.0
	velocity = Vector3.ZERO
	distance_travelled = 0.0
	look_offset = Vector2.ZERO
	motion_clock = 0.0
	global_position = terrain.spawn_origin() + Vector3(0, 0.08, 0)
	rotation = Vector3.ZERO
	if is_instance_valid(model): model.rotation = Vector3.ZERO
	for wheel in wheels: wheel.rotation.x = 0.0
	clear_inputs()

func clear_inputs() -> void:
	for action in ["drive_forward", "drive_reverse", "turn_left", "turn_right", "brake"]:
		Input.action_release(action)

func set_driving_enabled(value: bool) -> void:
	driving = value
	clear_inputs()
	if not value:
		speed = 0.0
		velocity = Vector3.ZERO
		clear_inputs()

func _physics_process(delta: float) -> void:
	if not driving: return
	var throttle := Input.get_axis("drive_reverse", "drive_forward")
	var braking := Input.is_action_pressed("brake")
	if braking: throttle = 0.0
	var steer := Input.get_axis("turn_left", "turn_right")
	var on_path: bool = absf(global_position.x - terrain.path_x(global_position.z)) < 4.5
	var limit: float = CRUISE_SPEED if on_path else 1.0
	speed = move_toward(speed, throttle * limit, delta * (8.0 if braking else (1.8 if throttle != 0 else 3.8)))
	heading += steer * delta * 1.1 * (-1.0 if speed < -0.1 else 1.0)
	rotation.y = -heading
	var direction := Vector3(sin(heading), 0, -cos(heading))
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor(): velocity.y -= 24.0 * delta
	else: velocity.y = -0.5
	var before := global_position
	move_and_slide()
	global_position.x = clampf(global_position.x, -94.0, 94.0)
	global_position.z = clampf(global_position.z, -164.0, 124.0)
	var travelled := Vector2(global_position.x-before.x, global_position.z-before.z).length()
	distance_travelled += travelled
	last_collision_count = get_slide_collision_count()
	for wheel in wheels: wheel.rotate_x(-signf(speed) * travelled / 0.36)
	if is_instance_valid(model):
		var p := global_position
		var front: Vector3 = p + direction
		var back: Vector3 = p - direction
		var right := Vector3(cos(heading),0,sin(heading))
		var pitch: float = atan2(terrain.height_at(front.x,front.z)-terrain.height_at(back.x,back.z),2.0)
		var roll: float = atan2(terrain.height_at(p.x+right.x,p.z+right.z)-terrain.height_at(p.x-right.x,p.z-right.z),2.0)
		model.rotation.x = lerp_angle(model.rotation.x,pitch,1.0-exp(-delta*5))
		model.rotation.z = lerp_angle(model.rotation.z,roll,1.0-exp(-delta*5))
	motion_clock += delta * absf(speed)

func _process(delta: float) -> void:
	if not is_instance_valid(camera): return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or not driving:
		look_offset = look_offset.lerp(Vector2.ZERO,1.0-exp(-delta*3.5))
	camera.rotation.y = look_offset.x
	camera.rotation.x = -0.10 + look_offset.y
	var bob: float = sin(motion_clock*7.0)*0.008 if driving and not reduced_motion else 0.0
	camera.position.y = bob

func _unhandled_input(event: InputEvent) -> void:
	if driving and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		look_offset.x = clampf(look_offset.x-event.relative.x*0.003,-1.25,1.25)
		look_offset.y = clampf(look_offset.y-event.relative.y*0.003,-0.55,0.65)

func view_direction() -> Vector3:
	return -camera.global_transform.basis.z
