extends SceneTree

const QuietEscort = preload("res://scripts/quiet_escort.gd")
const EPSILON: float = 0.0001

var checks: Dictionary = {}
var output: String = ""


func _initialize() -> void:
	output = _read_evidence_dir()
	if output.is_empty() or not output.is_absolute_path():
		printerr("escort_logic requires --evidence-dir=<absolute-path>")
		quit(2)
		return
	run()


func run() -> void:
	var escort = QuietEscort.new()
	var route: Array[Vector2] = [Vector2.ZERO, Vector2(10.0, 0.0)]
	checks.starts_only_when_ready = not escort.start(Vector2.ZERO) and escort.configure(route) and escort.start(Vector2.ZERO) and not escort.start(Vector2.ZERO)

	var before_noise: Dictionary = escort.snapshot()
	checks.noise_stops_movement = not escort.tick(Vector2(10.0, 0.0), -9.0, 0.25) and escort.position == Vector2.ZERO and escort.phase == "alarmed" and _near(escort.alarm, 0.225) and escort.travelled == 0.0 and before_noise.waypoint == escort.waypoint
	checks.quiet_recovery = not escort.tick(Vector2(10.0, 0.0), 0.0, 0.25) and escort.phase == "travelling" and _near(escort.alarm, 0.1375) and _near(escort.position.x, 0.7) and _near(escort.travelled, 0.7)

	escort = QuietEscort.new()
	escort.configure(route)
	escort.start(Vector2.ZERO)
	checks.distant_player_waits = not escort.tick(Vector2(24.01, 0.0), 100.0, 0.25) and escort.phase == "waiting" and escort.position == Vector2.ZERO and escort.alarm == 0.0 and escort.waypoint == 0

	escort = QuietEscort.new()
	escort.configure(route)
	escort.start(Vector2.ZERO)
	checks.too_close_alarms = not escort.tick(Vector2.ZERO, 0.0, 0.25) and escort.phase == "alarmed" and escort.position == Vector2.ZERO and _near(escort.alarm, 0.225)

	escort = QuietEscort.new()
	var duplicate_route: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2(1.0, 0.0), Vector2(1.0, 0.0)]
	escort.configure(duplicate_route)
	escort.start(Vector2.ZERO)
	var first_arrival := escort.tick(Vector2(10.0, 0.0), 0.0, 0.25)
	var second_arrival := escort.tick(Vector2(10.0, 0.0), 0.0, 0.25)
	var repeated_arrival := escort.tick(Vector2(10.0, 0.0), 0.0, 0.25)
	checks.correct_arrival_once = not first_arrival and second_arrival and not repeated_arrival and escort.phase == "complete" and escort.waypoint == duplicate_route.size() and escort.position == Vector2(1.0, 0.0) and _near(escort.travelled, 1.0)

	escort = QuietEscort.new()
	var empty: Array[Vector2] = []
	var too_many: Array[Vector2] = []
	for index in 65:
		too_many.append(Vector2(float(index), 0.0))
	var non_finite: Array[Vector2] = [Vector2(NAN, 0.0)]
	var invalid_configure := not escort.configure(empty) and not escort.configure(too_many) and not escort.configure(non_finite)
	var valid_after_rejections := escort.configure(route)
	var invalid_start: bool = not escort.start(Vector2(INF, 0.0)) and escort.phase == "idle"
	escort.start(Vector2.ZERO)
	var valid_snapshot: Dictionary = escort.snapshot()
	var invalid_ticks := not escort.tick(Vector2(NAN, 0.0), 0.0, 0.25) and escort.snapshot() == valid_snapshot
	invalid_ticks = invalid_ticks and not escort.tick(Vector2.ZERO, NAN, 0.25) and escort.snapshot() == valid_snapshot
	invalid_ticks = invalid_ticks and not escort.tick(Vector2.ZERO, INF, 0.25) and escort.snapshot() == valid_snapshot
	invalid_ticks = invalid_ticks and not escort.tick(Vector2.ZERO, 0.0, -0.1) and escort.snapshot() == valid_snapshot
	invalid_ticks = invalid_ticks and not escort.tick(Vector2.ZERO, 0.0, NAN) and escort.snapshot() == valid_snapshot
	invalid_ticks = invalid_ticks and not escort.tick(Vector2.ZERO, 0.0, INF) and escort.snapshot() == valid_snapshot
	checks.invalid_inputs_ignored = invalid_configure and valid_after_rejections and invalid_start and invalid_ticks

	escort = QuietEscort.new()
	escort.configure(route)
	escort.start(Vector2(2.0, 0.0))
	escort.tick(Vector2(10.0, 0.0), 9.0, 0.1)
	escort.reset(true)
	var complete_reset: Dictionary = escort.snapshot()
	var reset_complete_ok: bool = complete_reset.phase == "complete" and complete_reset.complete and complete_reset.position == {"x": 10.0, "z": 0.0} and complete_reset.waypoint == 2 and complete_reset.alarm == 0.0 and complete_reset.travelled == 0.0 and not escort.start(Vector2.ZERO)
	escort.reset(false)
	var idle_reset: Dictionary = escort.snapshot()
	checks.reset_complete_and_false = reset_complete_ok and idle_reset.phase == "idle" and not idle_reset.complete and idle_reset.position == {"x": 0.0, "z": 0.0} and idle_reset.waypoint == 0 and idle_reset.alarm == 0.0 and idle_reset.travelled == 0.0 and escort.start(Vector2.ZERO)

	escort = QuietEscort.new()
	var authored: Array[Vector2] = [Vector2.ZERO, Vector2(1.0, 0.0)]
	var configured := escort.configure(authored)
	authored[1] = Vector2(99.0, 0.0)
	var invalid_did_not_replace := not escort.configure(empty)
	escort.reset(true)
	checks.defensive_configure = configured and invalid_did_not_replace and escort.snapshot().total == 2 and escort.position == Vector2(1.0, 0.0)

	escort = QuietEscort.new()
	var long_route: Array[Vector2] = [Vector2(100.0, 0.0)]
	escort.configure(long_route)
	escort.start(Vector2.ZERO)
	checks.large_delta_bounded = not escort.tick(Vector2(10.0, 0.0), 0.0, 1000000.0) and escort.phase == "travelling" and _near(escort.position.x, 0.7) and _near(escort.travelled, 0.7) and escort.waypoint == 0

	var detached: Dictionary = escort.snapshot()
	var detached_position: Dictionary = detached.position
	detached.phase = "tampered"
	detached_position.x = 999.0
	checks.snapshot_detached = escort.phase == "travelling" and _near(escort.position.x, 0.7) and escort.snapshot().position.x != 999.0

	escort = QuietEscort.new()
	escort.configure(long_route);escort.start(Vector2.ZERO)
	for i in 100: escort.tick(Vector2(10,0),24.0,0.25)
	checks.alarm_is_bounded = escort.alarm == 1.0
	checks.active_route_cannot_change = not escort.configure(route)
	for i in 12: escort.tick(Vector2(10,0),0.0,0.25)
	checks.recovers_after_prolonged_noise = escort.alarm == 0.0 and escort.phase == "travelling"
	var progress: Dictionary=escort.snapshot()
	var resumed=QuietEscort.new();resumed.configure(long_route)
	checks.partial_restore=resumed.restore(progress) and resumed.snapshot()==progress
	var corrupt: Dictionary=progress.duplicate(true);corrupt.alarm=2.0
	checks.invalid_restore_is_atomic=not resumed.restore(corrupt) and resumed.snapshot()==progress
	corrupt=progress.duplicate(true);corrupt.position.x=9000.0
	checks.off_route_restore_rejected=not resumed.restore(corrupt) and resumed.snapshot()==progress
	corrupt=progress.duplicate(true);corrupt.total=2
	checks.route_length_mismatch_rejected=not resumed.restore(corrupt)
	var passed := true
	for value in checks.values():
		passed = passed and bool(value)
	var result := {
		"passed": passed,
		"checks": checks,
		"kind": "pure_refcounted_quiet_escort_rules_no_world_loaded",
	}
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(1)
		return
	var file := FileAccess.open(output.path_join("escort-logic.json"), FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print("ESCORT_LOGIC " + JSON.stringify(result))
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


func _near(actual: float, expected: float) -> bool:
	return absf(actual - expected) <= EPSILON
