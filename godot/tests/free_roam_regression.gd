extends SceneTree
const Save = preload("res://scripts/expedition_save.gd")
var game: Node3D
var checks: Dictionary = {}
var detail: Dictionary = {}
var output := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output = arg.trim_prefix("--evidence-dir=")
	if output.is_empty(): quit(2); return
	run.call_deferred()

func frames(count: int) -> void:
	for i in count: await physics_frame
	await process_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func near(point: Vector3, distance: float = 10.0) -> void:
	game.rover.set_driving_enabled(false)
	game.rover.global_position = Vector3(point.x, game.world.height_at(point.x, point.z + distance) + 0.1, point.z + distance)
	game.rover.heading = 0.0
	game.rover.rotation.y = 0.0
	game.rover.look_offset = Vector2.ZERO
	game.rover.set_camera_mode("first_person")
	game.rover.set_driving_enabled(true)
	game.observation_cooldown = 0.0
	await frames(8)
	game._update_survey_readout()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://main.tscn").instantiate()
	game.save_path = output.path_join("free-roam-fixture.json")
	root.add_child(game)
	await frames(8)
	checks.ready = game.ready_for_play
	if not game.ready_for_play:
		quit(1)
		return
	game.start_expedition()
	checks.no_arrival_lock = game.phase == "exploring" and game.rover.driving
	checks.no_target = not game.ui._map_context.has_target
	var initial_heading: float = game.rover.heading
	key(KEY_D, true)
	await frames(60)
	key(KEY_D, false)
	checks.stationary_steering_no_slide = is_equal_approx(initial_heading, game.rover.heading) and absf(game.rover.speed) < 0.01
	game.rover.look(180.0, 40.0)
	var look: Vector2 = game.rover.look_offset
	await frames(75)
	checks.parked_view_is_retained = game.rover.look_offset.is_equal_approx(look)
	key(KEY_V, true); key(KEY_V, false)
	await frames(6)
	checks.view_switch_preserves_look = game.rover.camera_mode == "third_person" and game.rover.look_offset.is_equal_approx(look)
	checks.camera_yaw_matches = is_equal_approx(game.rover.third_rig.rotation.y, game.rover.camera.rotation.y)
	game.pause_expedition()
	await frames(8)
	game.resume_expedition()
	checks.pause_preserves_look = game.rover.look_offset.is_equal_approx(look)
	game.rover.look_offset = Vector2.ZERO
	game.rover.set_camera_mode("first_person")
	var observed: Dictionary = {}
	for i in [0, 4, 9]:
		var subject: Vector3 = game.world._ecology_nodes[i].global_position
		await near(subject)
		var c: Dictionary = game.interaction_context()
		if c.kind == "ecology" and c.eligible:
			var kind: String = c.subject
			key(KEY_E, true); key(KEY_E, false)
			await frames(2)
			observed[kind] = game.observed_ecology.get(kind, false)
			checks["observation_keeps_control_" + kind] = game.phase == "exploring" and game.rover.driving and root.get_camera_3d() == game.rover.camera
		else: detail["unavailable_ecology_" + str(i)] = c
	checks.ecology_observed_by_input = observed.size() == 3
	await near(game.world.survey_position("aurora_lode"), 7.0)
	var site: Dictionary = game.interaction_context()
	checks.landmark_concrete_target = site.eligible and site.subject == "aurora_lode"
	key(KEY_E, true); key(KEY_E, false)
	await frames(2)
	checks.landmark_visible_response = game.world._observation_pulses.has("aurora_lode") and game.observed_landmarks.get("aurora_lode", false)
	var tree: Vector3 = game.contact.tree_root.global_position
	await near(tree, 28.0)
	checks.tree_without_missions = game.activities.count() == 0 and game.phase == "exploring" and game.rover.driving
	var tree_context: Dictionary = game.interaction_context()
	detail.tree_context = tree_context
	checks.tree_interaction_available = tree_context.eligible and tree_context.subject == "world_tree"
	key(KEY_E, true); key(KEY_E, false)
	await frames(4)
	checks.tree_pulse_without_camera_takeover = game.contact.reply_elapsed >= 0.0 and game.phase == "exploring" and root.get_camera_3d() == game.rover.camera and game.rover.driving
	checks.no_contact_progression = game.transmit_count == 0 and not game.contact_completed
	game.contact_completed = true
	game.transmit_count = 4
	checks.save_with_legacy_fields = game.save_expedition()
	var saved: Dictionary = Save.read(game.save_path)
	checks.optional_observations_saved = saved.get("observedLandmarks", {}).get("world_tree", false)
	game.pause_expedition()
	game._on_menu_requested()
	checks.title_keeps_save = game.phase == "menu" and game.has_saved_expedition() and game.ui._root.find_child("ContinueSaved", true, false) != null
	checks.old_completion_resumes_freely = game.load_expedition() and game.phase == "exploring" and game.rover.driving and game.contact_completed and game.transmit_count == 4
	checks.loaded_landmarks = game.observed_landmarks.get("world_tree", false)
	checks.no_hidden_objective_after_load = not game.ui._map_context.has_target
	var legacy: Dictionary = Save.read(game.save_path)
	legacy.erase("observedLandmarks")
	legacy.activities.field_notes.aurora_lode = true
	game.save_path = output.path_join("legacy-v2.json")
	checks.legacy_fixture_valid = Save.write(game.save_path, legacy)
	checks.legacy_observations_migrate = game.load_expedition() and game.observed_landmarks.get("aurora_lode", false) and game.observed_landmarks.get("world_tree", false)
	checks.legacy_progress_retained = game.activities.field.aurora_lode and game.transmit_count == 4
	var body: StaticBody3D = game.contact.get_node("SignalCollision")
	checks.tree_collision_matches_trunk = is_equal_approx(body.get_child(0).position.z, game.contact.tree_root.position.z)
	var passed := true
	for value in checks.values(): passed = passed and bool(value)
	var file := FileAccess.open(output.path_join("free-roam.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed, "kind":"native_fixture_regression_not_player_journey", "checks":checks, "detail":detail}, "\t"))
	file.close()
	print("FREE_ROAM_CHECKS ", JSON.stringify(checks))
	game.queue_free()
	game = null
	await create_timer(0.2).timeout
	quit(0 if passed else 1)
