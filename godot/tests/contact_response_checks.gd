extends SceneTree
const Save = preload("res://scripts/expedition_save.gd")
var checks: Dictionary = {}
var output: String
func _initialize() -> void:
	call_deferred("run")
func check(key: String, value: bool) -> void:
	checks[key] = value
func run() -> void:
	output = "user://contact-response-evidence"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="): output = argument.trim_prefix("--evidence-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	while not game.ready_for_play: await process_frame
	game.save_path = output.path_join("isolated-contact-save.json")
	game.start_expedition()
	game.rover.set_driving_enabled(false)
	game._set_phase("exploring")
	check("legacy_baseline_saved", game.save_expedition())
	var payload: Dictionary = Save.read(game.save_path)
	payload.erase("contactCompleted")
	payload.transmitCount = 7
	check("legacy_save_accepted", Save.valid(payload))
	check("legacy_transmission_is_not_completion", Save.migrate(payload).contactCompleted == false)
	var malformed := payload.duplicate(true)
	malformed.contactCompleted = "true"
	check("non_boolean_completion_rejected", not Save.valid(malformed))
	game.transmit_count = 1
	game.contact.begin()
	game._set_phase("contact")
	game.contact._process(1.0)
	check("early_confirmation_rejected", not game.contact.confirm_response() and not game.contact_completed)
	game.pause_expedition()
	var at: float = game.contact.elapsed
	game.contact._process(3.0)
	check("paused_response_freezes", game.contact.elapsed == at)
	check("interrupted_save_is_not_completion", not Save.read(game.save_path).contactCompleted)
	game.resume_expedition()
	game.contact._process(5.1)
	check("response_can_be_confirmed", game.contact.can_confirm() and game.interaction_target() == "contact_confirm")
	check("confirmation_succeeds", game.contact.confirm_response())
	check("discovery_and_ending", game.contact_completed and game.phase == "ending" and game.contact.linked)
	check("completion_saved", Save.read(game.save_path).contactCompleted)
	game._continue_exploring()
	check("continue_keeps_world_response", game.phase == "exploring" and game.contact.linked and game.contact.progress == 1.0)
	check("journal_has_discovery", game.ui._journal_context.get("contactCompleted", false))
	check("reload_restores_discovery", game.load_expedition() and game.contact_completed and game.contact.linked and game.contact.progress == 1.0)
	check("reply_succeeds_without_cutscene", game.contact.reply() and game.phase == "exploring")
	check("reply_cooldown_prevents_spam", not game.contact.reply())
	game.contact._process(3.1)
	check("reply_finishes_but_connection_remains", game.contact.reply_elapsed < 0.0 and game.contact.linked)
	game.reset_expedition()
	check("new_expedition_clears_discovery", not game.contact_completed and not game.contact.linked and game.contact.progress == 0.0)
	game.rover.set_driving_enabled(false)
	game.contact.begin()
	game._set_phase("contact")
	game.contact._process(24.1)
	check("original_automatic_ending_retained", game.phase == "ending" and game.contact_completed)
	var passed := true
	for value in checks.values(): passed = passed and value
	var receipt := {"kind":"native_contact_state_and_save_fixture_not_browser_visual_proof","checks":checks,"pass":passed}
	var file := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt,"  "))
	file.close()
	print(JSON.stringify(receipt))
	game.set_process(false)
	game.audio.set_paused(true)
	for player in game.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	await create_timer(0.15).timeout
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	quit(0 if passed else 1)

