extends SceneTree

var game: Node3D
var results: Dictionary = {"checks":{},"kind":"native_behavior_fixtures_not_browser_journey"}
var output: String = ""
var graphical: bool = false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output=arg.trim_prefix("--evidence-dir=")
		if arg=="--graphical": graphical=true
	if output.is_empty(): output=ProjectSettings.globalize_path("user://checks")
	DirAccess.make_dir_recursive_absolute(output)
	run.call_deferred()

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func capture(label: String) -> void:
	if not graphical: return
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+".png"))

func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	results.checks.ready=game.snapshot().ready
	await capture("menu")
	game.start_expedition()
	await create_timer(6.0).timeout
	results.checks.first_person=game.phase=="exploring" and game.rover.camera.current
	results.checks.four_regions=game.world.region_at(Vector3(0,0,50)) != game.world.region_at(Vector3(0,0,-100)) and game.world.region_at(Vector3(0,0,-100)) != game.world.region_at(Vector3(0,0,-260)) and game.world.region_at(Vector3(0,0,-260)) != game.world.region_at(Vector3(0,0,-480))
	key(KEY_V,true)
	key(KEY_V,false)
	await process_frame
	results.checks.third_person=game.rover.camera_mode=="third_person" and game.rover.third_camera.current
	await capture("third-person")
	key(KEY_V,true)
	key(KEY_V,false)
	await process_frame
	results.checks.camera_toggle_back=game.rover.camera_mode=="first_person" and game.rover.camera.current
	await capture("first-person")
	var before: Vector3=game.rover.global_position
	key(KEY_W,true)
	await create_timer(1.5).timeout
	key(KEY_W,false)
	await create_timer(0.5).timeout
	results.checks.forward=game.rover.global_position.z<before.z-0.5
	results.checks.acceleration=game.rover.speed>2.0 and game.rover.max_speed_mps()>=8.0
	results.checks.on_floor=game.rover.is_on_floor()
	var heading: float=game.rover.heading
	key(KEY_A,true)
	await create_timer(0.3).timeout
	key(KEY_A,false)
	results.checks.left=game.rover.heading<heading-0.1
	heading=game.rover.heading
	key(KEY_D,true)
	await create_timer(0.3).timeout
	key(KEY_D,false)
	results.checks.right=game.rover.heading>heading+0.1
	before=game.rover.global_position
	var reverse_axis := Vector3(sin(game.rover.heading),0,-cos(game.rover.heading))
	key(KEY_S,true)
	await create_timer(1.5).timeout
	key(KEY_S,false)
	await create_timer(0.5).timeout
	results.checks.reverse=(game.rover.global_position-before).dot(reverse_axis)<-0.5
	game.pause_expedition()
	var clock: float=game.elapsed
	key(KEY_W,true)
	await create_timer(0.3).timeout
	results.checks.pause_freezes=game.elapsed==clock and game.rover.speed==0.0
	game.resume_expedition()
	results.checks.resume_clears_keys=not Input.is_action_pressed("drive_forward")
	# Optional ecology observation fixture: the player must stop near an organism and receive world feedback.
	var ecology_node: Node3D = game.world._ecology_nodes[0]
	game.rover.global_position=ecology_node.global_position+Vector3(0,0.1,4.0)
	game.rover.speed=0
	game.rover.velocity=Vector3.ZERO
	await physics_frame
	game.world.set_player_state(game.rover.global_position,0.0)
	var ecology_before: int = game.observed_ecology.size()
	game.interact()
	results.checks.ecology_observation=game.observed_ecology.size()>ecology_before
	game.interact()
	results.checks.remote_interact_rejected=game.phase=="exploring" and game.transmit_count==0
	var center: Vector3=game.world.signal_origin()
	game.rover.global_position=center+Vector3(0,0.1,8.0)
	game.rover.heading=0
	game.rover.rotation.y=0
	game.rover.speed=0
	game.rover.velocity=Vector3.ZERO
	await physics_frame
	await capture("signal-near")
	results.checks.near_interaction=game.can_interact()
	game.interact()
	results.checks.contact_started=game.phase=="contact" and game.transmit_count==1
	game.interact()
	results.checks.no_double_transmit=game.transmit_count==1
	await create_timer(10.0).timeout
	await capture("contact")
	game.pause_expedition()
	clock=game.contact.elapsed
	await create_timer(0.4).timeout
	results.checks.contact_pause=game.contact.elapsed==clock
	game.resume_expedition()
	await create_timer(15.0).timeout
	results.contact_debug={"elapsed":game.contact.elapsed,"progress":game.contact.progress,"active":game.contact.active,"paused":game.contact.paused,"phase":game.phase}
	results.checks.ending=game.phase=="ending" and game.contact.progress==1.0
	await capture("ending")
	results.metrics=game.metrics()
	game.reset_expedition()
	results.checks.reset=game.phase=="arrival" and game.transmit_count==0 and game.contact.progress==0 and game.rover.speed==0
	results.passed=true
	for value in results.checks.values():
		if not value: results.passed=false
	var file:=FileAccess.open(output.path_join("runtime.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"  "))
	file.close()
	print("RUNTIME_CHECKS "+JSON.stringify(results))
	game.audio.set_paused(true)
	game.queue_free()
	await create_timer(0.4).timeout
	quit(0 if results.passed else 1)
