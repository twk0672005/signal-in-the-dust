extends CharacterBody3D

var terrain: Node3D
var heading: float = 0.0
var speed: float = 0.0
var distance_travelled: float = 0.0
var driving: bool = false
var reduced_motion: bool = false
var camera: Camera3D
var camera_rig: Node3D
var third_rig: Node3D
var third_arm: SpringArm3D
var third_camera: Camera3D
var camera_mode: String = "first_person"
var model: Node3D
var wheels: Array[Node3D] = []
var look_offset := Vector2.ZERO
var motion_clock: float = 0.0
var last_collision_count: int = 0
const CRUISE_SPEED: float = 24.0
const REVERSE_SPEED: float = 9.0
const OFF_PATH_SPEED: float = 16.5
const ACCELERATION: float = 9.0
const COAST_DECELERATION: float = 12.0
const BRAKE_DECELERATION: float = 60.0

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
	camera_rig.position = Vector3(0, 1.48, -0.43)
	add_child(camera_rig)
	camera = Camera3D.new()
	camera.name = "FirstPersonCamera"
	camera.fov = 72
	camera.near = 0.06
	camera.far = 650
	camera.rotation.x = -0.10
	camera_rig.add_child(camera)
	third_rig = Node3D.new()
	third_rig.name = "ThirdPersonRig"
	third_rig.position = Vector3(0, 1.9, 0.75)
	add_child(third_rig)
	third_arm = SpringArm3D.new()
	third_arm.name = "ThirdPersonCollisionArm"
	third_arm.spring_length = 7.0
	third_arm.margin = 0.35
	third_arm.collision_mask = 1
	third_arm.rotation_degrees = Vector3(-11.0, 0.0, 0.0)
	third_rig.add_child(third_arm)
	third_arm.add_excluded_object(get_rid())
	third_camera = Camera3D.new()
	third_camera.name = "ThirdPersonCamera"
	third_camera.fov = 68
	third_camera.near = 0.08
	third_camera.far = 650
	third_arm.add_child(third_camera)
	reset()

func reset() -> void:
	heading = 0.0
	speed = 0.0
	velocity = Vector3.ZERO
	distance_travelled = 0.0
	look_offset = Vector2.ZERO
	motion_clock = 0.0
	third_rig.rotation = Vector3.ZERO
	third_arm.rotation.x = -0.18
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

func set_camera_mode(mode: String) -> void:
	if mode not in ["first_person", "third_person"]:
		return
	camera_mode = mode
	if is_instance_valid(camera): camera.current = camera_mode == "first_person"
	if is_instance_valid(third_camera): third_camera.current = camera_mode == "third_person"

func toggle_camera_mode() -> String:
	set_camera_mode("third_person" if camera_mode == "first_person" else "first_person")
	return camera_mode

func current_speed_mps() -> float:
	return speed

func max_speed_mps() -> float:
	return CRUISE_SPEED if absf(global_position.x - terrain.path_x(global_position.z)) < 4.5 else OFF_PATH_SPEED

func brake_intensity() -> float:
	return clampf(absf(speed) / CRUISE_SPEED, 0.0, 1.0)

func _physics_process(delta: float) -> void:
	if not driving: return
	var throttle := Input.get_axis("drive_reverse", "drive_forward")
	var braking := Input.is_action_pressed("brake")
	if braking: throttle = 0.0
	var steer := Input.get_axis("turn_left", "turn_right")
	var limit: float = max_speed_mps() if throttle >= 0.0 else REVERSE_SPEED
	var target_speed := throttle * limit
	var opposing := absf(speed) > 0.1 and throttle * speed < 0.0
	var rate := BRAKE_DECELERATION if braking or opposing else (ACCELERATION if absf(throttle) > 0.01 else COAST_DECELERATION)
	if opposing: target_speed = 0.0
	speed = move_toward(speed, target_speed, delta * rate)
	var steering_factor := lerpf(1.0, 0.58, clampf(absf(speed) / CRUISE_SPEED, 0.0, 1.0))
	heading += steer * delta * 1.55 * steering_factor * (-1.0 if speed < -0.1 else 1.0)
	rotation.y = -heading
	var direction := Vector3(sin(heading), 0, -cos(heading))
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor(): velocity.y -= 24.0 * delta
	else: velocity.y = -0.5
	var before := global_position
	move_and_slide()
	# Wall response must reduce the driven speed rather than accumulate hidden thrust.
	for hit_index in get_slide_collision_count():
		var hit := get_slide_collision(hit_index)
		if absf(hit.get_normal().y) < 0.65:
			speed = Vector2(velocity.x,velocity.z).dot(Vector2(direction.x,direction.z))
	global_position.x = clampf(global_position.x, -94.0, 94.0)
	global_position.z = clampf(global_position.z, -670.0, 180.0)
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
	if camera_mode == "first_person":
		camera.rotation.y = look_offset.x
		camera.rotation.x = -0.10 + look_offset.y
	else:
		# The parent body already supplies heading; only relative look belongs here.
		third_rig.rotation.y = lerp_angle(third_rig.rotation.y,look_offset.x,1.0-exp(-delta*8.0))
		third_arm.rotation.x = clampf(-0.18 + look_offset.y, -0.75, 0.35)
	var bob: float = sin(motion_clock*7.0)*0.008 if driving and not reduced_motion else 0.0
	if camera_mode == "first_person": camera.position.y = bob
	else:
		third_rig.position.y = 1.9 + bob * 0.35
		var lead := 0.75 - clampf(speed/CRUISE_SPEED,-1.0,1.0)*1.25
		third_rig.position.z = lerpf(third_rig.position.z,lead,1.0-exp(-delta*5.0))

func _unhandled_input(event: InputEvent) -> void:
	if driving and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		look_offset.x = clampf(look_offset.x-event.relative.x*0.003,-1.25,1.25)
		look_offset.y = clampf(look_offset.y-event.relative.y*0.003,-0.55,0.65)

func get_active_camera() -> Camera3D:
	return camera if camera_mode == "first_person" else third_camera

func view_direction() -> Vector3:
	return -get_active_camera().global_transform.basis.z

func camera_snapshot() -> Dictionary:
	return {"mode": camera_mode, "yaw": look_offset.x, "pitch": look_offset.y, "springLength": third_arm.spring_length if is_instance_valid(third_arm) else 0.0}


