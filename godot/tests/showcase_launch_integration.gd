extends SceneTree
const Save = preload("res://scripts/expedition_save.gd")
var checks: Dictionary = {}
var output := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output = arg.trim_prefix("--evidence-dir=")
	if output.is_empty(): quit(2); return
	run.call_deferred()

func intent(id: String, action: String, settings: Dictionary = {}) -> Dictionary:
	return {"version": 1, "requestId": id, "action": action, "settings": settings}

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var game: Node3D = load("res://main.tscn").instantiate()
	game.save_path = output.path_join("isolated-showcase-save.json")
	Save.clear(game.save_path)
	root.add_child(game)
	await physics_frame
	checks.native_menu_preserved = game.phase == "menu" and game.ui.current_state() == "menu"
	checks.whisper_is_short_and_non_looping = game.ui._whisper_chime.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED and game.ui._whisper_chime.stream.get_length() < 0.5
	game._begin_web_launch(intent("missing", "continue"))
	checks.legacy_continue_is_rejected = game.phase == "menu" and game._web_boot.request_id.is_empty()
	checks.failed_continue_does_not_start_new = game.elapsed == 0.0 and not game.has_saved_expedition()
	game._begin_web_launch(intent("new-first", "new", {"locale": "zh_TW", "volume": 0.35}))
	checks.new_intent_uses_existing_arrival = game.phase == "arrival" and game._web_boot.stage == "playing"
	checks.headless_does_not_claim_a_rendered_frame = not game._web_boot.first_frame_ready
	checks.explicit_settings_reach_game = game.settings.locale == "zh_TW" and is_equal_approx(game.settings.volume, 0.35)
	game._set_phase("exploring")
	game.elapsed = 85.0
	checks.save_baseline = game.save_expedition()
	game._set_phase("menu")
	game._begin_web_launch(intent("ask-new", "new"))
	checks.saved_new_requires_confirmation = game.phase == "menu" and game.ui.current_state() == "confirm_new" and game._web_boot.stage == "confirm-new"
	checks.no_continue_button = game.ui._root.find_child("ContinueSaved", true, false) == null
	checks.invitation_is_used = game.ui._root.find_child("BeginJourney", true, false) != null and game.ui._root.find_child("BackHome", true, false) != null
	checks.confirmation_did_not_clear_save = is_equal_approx(float(Save.read(game.save_path).get("elapsed", -1)), 85.0)
	game.ui._cancel_new()
	checks.cancel_returns_home_and_preserves_save = game._web_boot.stage == "home" and not Save.read(game.save_path).is_empty()
	game.load_expedition() # Internal save recovery remains tested; no player-facing Continue action.
	checks.internal_recovery_restores_existing_progress = game.phase == "exploring" and is_equal_approx(game.elapsed, 85.0)
	game.elapsed = 86.0
	game._begin_web_launch(intent("resume", "continue"))
	checks.disabled_continue_does_not_reload_progress = is_equal_approx(game.elapsed, 86.0)
	game._set_phase("contact")
	game.transmit_count = 1
	game._on_contact_completed()
	checks.optional_ending_preserves_exploration = game.phase == "ending" and not Save.read(game.save_path).is_empty()
	game.ui.explore_requested.emit()
	checks.ending_returns_to_exploration_without_reset = game.phase == "exploring" and game.transmit_count == 1 and game.elapsed == 86.0 and game.reset_count == 0
	game._set_phase("menu")
	game._begin_web_launch(intent("confirm-again", "new"))
	game.ui.reset_requested.emit()
	checks.confirmed_new_resets_through_existing_path = game.phase == "arrival" and game.reset_count == 1 and not game.has_saved_expedition()
	checks.confirmed_new_keeps_settings = game.settings.locale == "zh_TW" and is_equal_approx(game.settings.volume, 0.35)
	game._set_phase("exploring")
	game._update_survey_readout()
	checks.one_current_investigation_is_visible = game.ui._activity_label.visible and not game.ui._activity_label.text.is_empty() and game.ui._activity_context.target=="aurora_shelf"
	checks.minimap_is_present = game.ui._root.find_child("ExplorerMinimap", true, false) != null
	game.pause_expedition()
	var contacts: Array = game.ui._root.find_children("*", "LinkButton", true, false)
	checks.pause_contact_uses_requested_mailto = contacts.size() == 1 and contacts[0].uri == "mailto:TWK0672005@gmail.com"
	game.ui.show_state("settings")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	game._input(escape)
	checks.settings_escape_returns_to_pause = game.phase == "paused" and game.ui.current_state() == "paused"
	game.resume_expedition()
	game.rover.set_driving_enabled(false)
	game.rover.global_position = game.contact.global_position + Vector3(0, 0, 5)
	game.rover.heading = 0.0
	game.rover.rotation.y = 0.0
	game.rover.set_camera_mode("first_person")
	await physics_frame
	await physics_frame
	checks.contact_does_not_require_old_task_chain = game.activities.count() == 0 and game.activities.field_count() == 0 and game.interaction_target() == "contact"
	var passed := true
	for value in checks.values(): passed = passed and value
	var report := {"kind": "native_headless_launch_and_save_integration_not_Web_or_render_proof", "passed": passed, "checks": checks}
	var file := FileAccess.open(output.path_join("launch-integration.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ")); file.close()
	print(JSON.stringify(report))
	# Let the audio thread drain this rapid fixture's start/reset/stop sequence before exit.
	game.set_process(false)
	for player in game.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	await create_timer(0.15).timeout
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.1).timeout
	quit(0 if passed else 1)
