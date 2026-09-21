extends SceneTree

const QuietPassage = preload("res://scripts/quiet_passage.gd")
const ROUTE: Array[Vector2] = [
	Vector2(-30.0, -200.0),
	Vector2(-10.0, -220.0),
	Vector2(12.0, -245.0),
]

var checks: Dictionary = {}
var output: String = ""


func _initialize() -> void:
	output = _read_evidence_dir()
	if output.is_empty() or not output.is_absolute_path():
		printerr("quiet_passage_checks requires --evidence-dir=<absolute-path>")
		quit(2)
		return
	run()


func run() -> void:
	var passage = QuietPassage.new()
	var authored := ROUTE.duplicate()
	var configured := passage.configure(authored)
	authored[0] = Vector2(90.0, -340.0)
	checks.route_is_defensively_copied = configured and passage.snapshot().route[0] == {"x": -30.0, "z": -200.0} and not passage.configure(ROUTE)
	checks.normal_ordered_path = passage.start() and passage.tick(ROUTE[0], 5.5, 10.0) == "gate" and passage.gate == 1
	checks.one_gate_per_tick = passage.tick(ROUTE[1], 0.0, 0.0) == "gate" and passage.gate == 2
	checks.completes_once = passage.tick(ROUTE[2], 0.0, 0.0) == "complete" and passage.tick(ROUTE[2], 0.0, 1.0) == "" and passage.phase == "complete"

	passage = QuietPassage.new()
	passage.configure(ROUTE)
	passage.start()
	var wrong_before := passage.snapshot()
	checks.wrong_order_has_no_progress = passage.tick(ROUTE[1], 0.0, 0.25) == "" and passage.snapshot() == wrong_before

	passage = QuietPassage.new()
	passage.configure(ROUTE)
	passage.start()
	checks.fast_entry_scatters = passage.tick(ROUTE[0] + Vector2(11.9, 0.0), -5.51, 100.0) == "scattered" and passage.phase == "scattered" and passage.gate == 0 and passage.alarm == 2.0 and not passage.armed
	checks.repeated_fast_tick_has_no_event = passage.tick(ROUTE[0] + Vector2(11.9, 0.0), 6.0, 0.25) == "" and passage.phase == "scattered" and passage.gate == 0 and passage.alarm == 2.0 and not passage.armed
	passage.tick(ROUTE[0], 0.0, 100.0)
	checks.alarm_decay_is_bounded = passage.alarm == 1.75 and passage.gate == 0 and not passage.armed
	for index in 7:
		passage.tick(ROUTE[0], 0.0, 0.25)
	checks.cannot_rearm_inside = passage.alarm == 0.0 and not passage.armed and passage.phase == "scattered" and passage.tick(ROUTE[0], 0.0, 0.25) == "" and passage.gate == 0
	checks.exit_rearms_without_progress = passage.tick(ROUTE[0] + Vector2(8.01, 0.0), 0.0, 0.25) == "" and passage.armed and passage.phase == "crossing" and passage.gate == 0
	checks.reentry_progresses = passage.tick(ROUTE[0] + Vector2(6.0, 0.0), 5.5, 0.25) == "gate" and passage.gate == 1

	passage = QuietPassage.new()
	passage.configure(ROUTE)
	passage.start()
	passage.tick(ROUTE[0], 0.0, 0.0)
	passage.tick(ROUTE[1] + Vector2(4.0, 0.0), 6.0, 0.1)
	var paused := passage.snapshot()
	var still_paused := passage.snapshot()
	checks.caller_pause_without_ticks_freezes = paused == still_paused and paused.alarm == 2.0 and paused.phase == "scattered"
	passage.tick(ROUTE[1] + Vector2(9.0, 0.0), 0.0, 0.25)
	var mid_state := passage.snapshot()
	var restored = QuietPassage.new()
	restored.configure(ROUTE)
	checks.mid_crossing_restore = restored.restore(mid_state) and restored.snapshot() == mid_state

	var before_bad := restored.snapshot()
	var corrupt := mid_state.duplicate(true)
	corrupt.route[1].x += 0.5
	checks.route_identity_rejected_atomically = not restored.restore(corrupt) and restored.snapshot() == before_bad
	corrupt = mid_state.duplicate(true)
	corrupt.gate = 1.5
	checks.fractional_gate_rejected = QuietPassage.normalized(corrupt).is_empty() and not restored.restore(corrupt) and restored.snapshot() == before_bad
	corrupt = mid_state.duplicate(true)
	corrupt.alarm = NAN
	checks.nan_rejected = QuietPassage.normalized(corrupt).is_empty() and not restored.restore(corrupt) and restored.snapshot() == before_bad
	corrupt = mid_state.duplicate(true)
	corrupt.phase = "crossing"
	checks.invalid_phase_combo_rejected = QuietPassage.normalized(corrupt).is_empty() and not restored.restore(corrupt) and restored.snapshot() == before_bad
	corrupt = mid_state.duplicate(true)
	corrupt.complete = true
	checks.invalid_complete_combo_rejected = QuietPassage.normalized(corrupt).is_empty() and not restored.restore(corrupt) and restored.snapshot() == before_bad
	corrupt = mid_state.duplicate(true)
	corrupt.armed = "yes"
	checks.invalid_armed_type_rejected = QuietPassage.normalized(corrupt).is_empty() and not restored.restore(corrupt) and restored.snapshot() == before_bad

	var invalid_route = QuietPassage.new()
	var too_short: Array[Vector2] = [ROUTE[0]]
	var too_close: Array[Vector2] = [ROUTE[0], ROUTE[0] + Vector2(12.99, 0.0)]
	var outside: Array[Vector2] = [Vector2(95.0, -200.0), ROUTE[1]]
	var non_finite: Array[Vector2] = [Vector2(NAN, -200.0), ROUTE[1]]
	checks.invalid_routes_rejected_without_mutation = not invalid_route.configure(too_short) and not invalid_route.configure(too_close) and not invalid_route.configure(outside) and not invalid_route.configure(non_finite) and invalid_route.snapshot().total == 0

	restored.reset(true)
	var complete_reset := restored.snapshot()
	var complete_ok: bool = complete_reset.phase == "complete" and complete_reset.gate == ROUTE.size() and complete_reset.complete and complete_reset.alarm == 0.0 and not complete_reset.armed and not restored.start()
	restored.reset(false)
	var idle_reset := restored.snapshot()
	checks.reset_states = complete_ok and idle_reset.phase == "idle" and idle_reset.gate == 0 and not idle_reset.complete and idle_reset.alarm == 0.0 and not idle_reset.armed and restored.start()

	var started_at_first = QuietPassage.new()
	started_at_first.configure(ROUTE)
	checks.first_gate_is_immediately_eligible = started_at_first.start() and started_at_first.armed and started_at_first.tick(ROUTE[0], 0.0, 0.0) == "gate"

	var invalid_tick = QuietPassage.new()
	invalid_tick.configure(ROUTE)
	invalid_tick.start()
	var tick_before := invalid_tick.snapshot()
	var invalid_ticks := invalid_tick.tick(Vector2(NAN, 0.0), 0.0, 0.25) == "" and invalid_tick.snapshot() == tick_before
	invalid_ticks = invalid_ticks and invalid_tick.tick(ROUTE[0], NAN, 0.25) == "" and invalid_tick.snapshot() == tick_before
	invalid_ticks = invalid_ticks and invalid_tick.tick(ROUTE[0], 0.0, -0.1) == "" and invalid_tick.snapshot() == tick_before
	checks.invalid_ticks_are_atomic = invalid_ticks

	var passed := true
	for value in checks.values():
		passed = passed and bool(value)
	var result := {
		"passed": passed,
		"checks": checks,
		"kind": "pure_refcounted_quiet_passage_rules_no_world_loaded",
	}
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(1)
		return
	var file := FileAccess.open(output.path_join("quiet-passage-checks.json"), FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print("QUIET_PASSAGE_CHECKS " + JSON.stringify(result))
	quit(0 if passed else 1)


func _read_evidence_dir() -> String:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		var arg := String(args[index])
		if arg.begins_with("--evidence-dir="):
			return arg.trim_prefix("--evidence-dir=")
		if arg == "--evidence-dir" and index + 1 < args.size():
			return String(args[index + 1])
	return ""
