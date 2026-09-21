extends SceneTree
var game: Node3D
var output:=""
var checks: Dictionary={}
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output=arg.trim_prefix("--evidence-dir=")
	if output.is_empty(): quit(2);return
	run.call_deferred()
func tap(code: int) -> void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true;Input.parse_input_event(e)
	await process_frame
	e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=false;Input.parse_input_event(e)
	await create_timer(0.25).timeout
func click(button: Button) -> void:
	var position:=button.get_global_rect().get_center()
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=position;e.global_position=position;e.pressed=true;root.push_input(e,true)
	await process_frame
	e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=position;e.global_position=position;e.pressed=false;root.push_input(e,true)
	await create_timer(0.3).timeout
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	checks["capture_"+name]=root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://main.tscn").instantiate();root.add_child(game);await create_timer(0.5).timeout
	await tap(KEY_ENTER)
	var deadline:=Time.get_ticks_msec()+10000
	while game.phase!="exploring" and Time.get_ticks_msec()<deadline: await process_frame
	checks.start=game.phase=="exploring"
	await tap(KEY_J)
	checks.journal_pauses=game.phase=="paused" and game.ui._state=="journal"
	var elapsed: float=game.elapsed
	var position: Vector3=game.rover.position
	await create_timer(0.4).timeout
	checks.journal_freezes=game.elapsed==elapsed and game.rover.position==position
	checks.visited_only=game.activities.discovered.aurora_shelf and not game.activities.discovered.ember_rift
	checks.unknown_untrackable=game.ui._root.find_child("JournalTrack_ember_rift",true,false)==null
	game.ui._config.locale="zh_TW";game.ui._build();await create_timer(0.3).timeout
	await capture("journal-zh")
	var button: Button=game.ui._root.find_child("JournalTrack_aurora_shelf",true,false)
	if button==null: checks.track_button=false;finish();return
	await click(button)
	checks.real_click_tracks=game.phase=="exploring" and game.activities.tracked_encounter=="aurora_shelf"
	checks.compass_targets_encounter=game.ui._activity_context.target=="encounter_aurora_shelf"
	await capture("journal-compass")
	await tap(KEY_ESCAPE)
	game.queue_free();await create_timer(0.4).timeout
	game=load("res://main.tscn").instantiate();root.add_child(game);await create_timer(0.5).timeout
	await tap(KEY_ENTER)
	checks.continue_restores=game.phase=="exploring" and game.activities.tracked_encounter=="aurora_shelf" and game.activities.discovered.aurora_shelf
	await tap(KEY_J)
	game.ui._config.locale="en";game.ui._build();await create_timer(0.3).timeout
	await capture("journal-en")
	root.size=Vector2i(960,600);await create_timer(0.5).timeout
	await capture("journal-small")
	# Resume from keyboard, reopen full size, then choose the main-survey button.
	await tap(KEY_ESCAPE)
	checks.escape_resumes=game.phase=="exploring"
	root.size=Vector2i(1280,720);await tap(KEY_J)
	button=game.ui._root.find_child("JournalTrackSurveys",true,false)
	if button==null: checks.survey_button=false;finish();return
	# Scroll the fixed-height journal panel so the chosen button receives an actual click.
	for container in game.ui._root.find_children("*","ScrollContainer",true,false): container.scroll_vertical=10000
	await process_frame;await click(button)
	checks.cancel_tracking=game.phase=="exploring" and game.activities.tracked_encounter==""
	finish()
func finish() -> void:
	var passed:=true
	for v in checks.values(): passed=passed and bool(v)
	var f:=FileAccess.open(output.path_join("journal.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":passed,"checks":checks,"kind":"native_keyboard_mouse_journal_navigation_and_isolated_save; locale switched in fixture memory without overwriting user settings"},"  "));f.close()
	print("JOURNAL_CHECKS "+JSON.stringify(checks))
	game.queue_free();await create_timer(0.5).timeout;quit(0 if passed else 1)
