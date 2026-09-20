extends SceneTree

var game: Node3D
var checks: Dictionary = {}
var detail: Dictionary = {}
var output: String = ""

func _initialize() -> void:
	root.size = Vector2i(1440, 900)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="):
			output = argument.trim_prefix("--evidence-dir=")
	if output.is_empty():
		push_error("Evidence directory required")
		quit(2)
		return
	run.call_deferred()

func frames(count: int) -> void:
	for index in count:
		await physics_frame
	await process_frame

func press(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func place(position: Vector3, yaw: float) -> void:
	game.rover.set_driving_enabled(false)
	game.rover.global_position = position + Vector3(0, 0.12, 0)
	game.rover.heading = yaw
	game.rover.rotation.y = -yaw
	game.rover.look_offset = Vector2.ZERO
	game.rover.set_driving_enabled(true)
	await frames(15)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(15)
	checks.ready = game.ready_for_play
	checks.menu_owns_camera = root.get_camera_3d() == game.exterior
	var ground: MeshInstance3D = game.world.get_node("CollidableDustBasin")
	var arrays := ground.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var clockwise: float = (verts[indices[1]]-verts[indices[0]]).cross(verts[indices[2]]-verts[indices[0]]).y
	checks.clockwise_upward_faces = clockwise < 0.0
	detail.first_face_cross_y = clockwise
	var missing: Array = []
	for z in [175.0, 150.0, 90.0, 20.0, -30.0, -100.0, -180.0, -260.0, -340.0, -420.0, -500.0, -580.0, -620.0, -665.0, -680.0]:
		var x: float = game.world.path_x(z)
		var y: float = game.world.height_at(x,z)
		var query := PhysicsRayQueryParameters3D.create(Vector3(x,y+6,z),Vector3(x,y-6,z))
		query.exclude = [game.rover.get_rid()]
		query.hit_back_faces = false
		if game.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): missing.append(z)
	checks.entire_route_has_frontface_floor = missing.is_empty()
	detail.missing_ground_z = missing
	game.start_expedition()
	await frames(30)
	checks.arrival_owns_camera = root.get_camera_3d() == game.exterior
	await frames(360)
	checks.driving_starts_after_arrival = game.phase == "exploring"
	checks.spawn_grounded = game.rover.is_on_floor()
	detail.spawn_position = str(game.rover.global_position)
	game.rover.set_driving_enabled(false)
	game.rover.heading = 0.7
	game.rover.rotation.y = -0.7
	game.rover.set_camera_mode("third_person")
	await frames(15)
	var camera_forward: Vector3 = -game.rover.third_camera.global_basis.z
	camera_forward.y = 0
	var body_forward := Vector3(sin(0.7),0,-cos(0.7))
	var alignment := camera_forward.normalized().dot(body_forward)
	checks.third_person_heading_applied_once = alignment > 0.99
	checks.third_person_selected = root.get_camera_3d() == game.rover.third_camera
	detail.third_person_alignment = alignment
	checks.spring_arm_clear_of_own_rover = game.rover.third_arm.get_hit_length() > 5.0
	var obstacle := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3,6,1)
	collision.shape = box
	obstacle.add_child(collision)
	root.add_child(obstacle)
	obstacle.rotation.y = -0.7
	obstacle.position = game.rover.global_position-body_forward*3.5+Vector3(0,2,0)
	await frames(15)
	checks.spring_arm_retracts_for_obstacle = game.rover.third_arm.get_hit_length() < 4.5
	detail.spring_arm_blocked_length = game.rover.third_arm.get_hit_length()
	obstacle.queue_free()
	await frames(15)
	game.rover.set_camera_mode("first_person")
	checks.switch_back_to_first_person = root.get_camera_3d() == game.rover.camera
	var origin: Vector3 = game.world.spawn_origin()
	await place(origin,0.32)
	press(KEY_W,true)
	await frames(175)
	checks.reaches_cruise_in_three_seconds = game.rover.speed > 23.5 and game.rover.speed <= 24.1
	detail.speed_after_2_9_seconds = game.rover.speed
	press(KEY_W,false)
	await frames(1)
	checks.coasting_retains_momentum = game.rover.speed > 20.0
	await frames(123)
	checks.coasting_stops_after_two_seconds = absf(game.rover.speed) < 0.15
	detail.coast_terminal_speed = game.rover.speed
	await place(origin,0.32)
	press(KEY_W,true)
	await frames(175)
	press(KEY_W,false)
	press(KEY_SPACE,true)
	await frames(29)
	checks.full_speed_brake_under_half_second = absf(game.rover.speed) < 0.15
	press(KEY_SPACE,false)
	await place(origin,PI/2)
	var before: Vector3 = game.rover.global_position
	press(KEY_S,true)
	await frames(80)
	var displacement: Vector3 = game.rover.global_position-before
	checks.reverse_follows_vehicle_axis = displacement.dot(Vector3.RIGHT) < -1.0 and game.rover.speed < -0.5
	detail.reverse_displacement = str(displacement)
	press(KEY_S,false)
	game.pause_expedition()
	press(KEY_W,true)
	game.resume_expedition()
	checks.resume_clears_inputs = not Input.is_action_pressed("drive_forward")
	checks.no_fallthrough = game.rover.global_position.y > -3.0
	var passed: bool = true
	for value in checks.values():
		if not value: passed = false
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("physics-camera.json"),FileAccess.WRITE)
	var report := {"passed":passed,"kind":"native_fixture_regression_not_full_journey","engine":Engine.get_version_info().string,"checks":checks,"detail":detail}
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("PHYSICS_CAMERA "+JSON.stringify(report))
	game.queue_free()
	await create_timer(0.4).timeout
	quit(0 if passed else 1)

