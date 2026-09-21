extends SceneTree

const ResonanceSequence = preload("res://scripts/resonance_sequence.gd")
const PATTERNS := [
	[0, 2, 1],
	[1, 0, 2, 1],
	[2, 1, 0, 2, 0],
]

var output := ""
var checks: Dictionary = {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):
			output = arg.trim_prefix("--evidence-dir=")
	if output.is_empty() or not output.is_absolute_path():
		quit(2)
		return
	run()

func expected_events(pattern: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for band in pattern:
		result.append({"kind": "tone", "band": int(band)})
	result.append({"kind": "answer"})
	return result

func complete_round(sequence: RefCounted, pattern: Array, final_round: bool) -> bool:
	var ok: bool = sequence.tick(100.0) == expected_events(pattern)
	for index in pattern.size():
		var expected := "solved" if final_round and index == pattern.size() - 1 else ("round_complete" if index == pattern.size() - 1 else "matched")
		ok = ok and sequence.respond(int(pattern[index])) == expected
	return ok

func run() -> void:
	var sequence = ResonanceSequence.new()
	var all_rounds := sequence is RefCounted and sequence.start()
	for round_number in PATTERNS.size():
		all_rounds = all_rounds and complete_round(sequence, PATTERNS[round_number], round_number == PATTERNS.size() - 1)
		if round_number < PATTERNS.size() - 1:
			all_rounds = all_rounds and sequence.phase == "listening" and sequence.round_index == round_number + 1 and sequence.matched == 0
	checks.correct_all_rounds = all_rounds and sequence.solved and sequence.phase == "solved"

	sequence = ResonanceSequence.new()
	sequence.start()
	sequence.tick(100.0)
	var retry_round := sequence.respond(0) == "matched"
	retry_round = retry_round and sequence.respond(0) == "retry"
	retry_round = retry_round and sequence.phase == "listening" and sequence.round_index == 0 and sequence.matched == 0
	retry_round = retry_round and complete_round(sequence, PATTERNS[0], false)
	checks.wrong_retries_current_round = retry_round and sequence.round_index == 1 and not sequence.solved

	sequence = ResonanceSequence.new()
	sequence.start()
	sequence.tick(100.0)
	var waiting_snapshot: Dictionary = sequence.snapshot()
	checks.invalid_input_ignored = sequence.respond(-1) == "ignored" and sequence.respond(3) == "ignored" and sequence.snapshot() == waiting_snapshot
	checks.no_input_cannot_solve = sequence.tick(100.0).is_empty() and sequence.phase == "answer" and not sequence.solved and sequence.matched == 0

	sequence = ResonanceSequence.new()
	sequence.start()
	sequence.tick(0.5)
	var paused_snapshot: Dictionary = sequence.snapshot()
	var still_paused: Dictionary = sequence.snapshot()
	var pause_events := sequence.tick(0.2)
	checks.pause_without_tick = paused_snapshot == still_paused and pause_events == [{"kind": "tone", "band": 0}]

	sequence = ResonanceSequence.new()
	sequence.start()
	var before_invalid_delta: Dictionary = sequence.snapshot()
	var rejects_delta := sequence.tick(-1.0).is_empty() and sequence.snapshot() == before_invalid_delta
	rejects_delta = rejects_delta and sequence.tick(NAN).is_empty() and sequence.snapshot() == before_invalid_delta
	rejects_delta = rejects_delta and sequence.tick(INF).is_empty() and sequence.snapshot() == before_invalid_delta
	var large_events := sequence.tick(1.0e100)
	checks.delta_validation_and_large_tick = rejects_delta and large_events == expected_events(PATTERNS[0]) and sequence.phase == "answer" and not sequence.solved and sequence.tick(1.0e100).is_empty()

	sequence = ResonanceSequence.new()
	var repeated_start := sequence.start()
	repeated_start = repeated_start and sequence.tick(0.8) == [{"kind": "tone", "band": 0}]
	repeated_start = repeated_start and sequence.start() and sequence.clock == 0.0 and sequence.matched == 0 and sequence.phase == "listening"
	repeated_start = repeated_start and sequence.tick(0.7) == [{"kind": "tone", "band": 0}]
	sequence.tick(100.0)
	repeated_start = repeated_start and sequence.respond(0) == "matched" and sequence.start() and sequence.matched == 0 and sequence.phase == "listening"
	checks.repeated_start_replays_round = repeated_start

	sequence.tick(100.0)
	sequence.respond(0)
	sequence.reset()
	var partial_reset: Dictionary = sequence.snapshot()
	checks.partial_reset_starts_idle = partial_reset == {"phase": "idle", "round_index": 0, "matched": 0, "length": 3, "solved": false} and sequence.clock == 0.0
	sequence.reset(true)
	var complete_reset: Dictionary = sequence.snapshot()
	checks.complete_reset_restores_solved_only = complete_reset == {"phase": "solved", "round_index": 2, "matched": 5, "length": 5, "solved": true} and sequence.clock == 0.0 and not sequence.start() and sequence.respond(0) == "ignored"
	sequence.reset(false)
	checks.reset_clears_solved = not sequence.solved and sequence.phase == "idle" and sequence.round_index == 0

	var detached_snapshot: Dictionary = sequence.snapshot()
	detached_snapshot.phase = "tampered"
	detached_snapshot.round_index = 99
	checks.snapshot_is_detached = sequence.phase == "idle" and sequence.round_index == 0 and sequence.snapshot().keys().size() == 5

	var passed := true
	for value in checks.values():
		passed = passed and bool(value)
	DirAccess.make_dir_recursive_absolute(output)
	var result := {
		"passed": passed,
		"checks": checks,
		"kind": "pure_refcounted_resonance_rules_no_scene_instantiated",
	}
	var file := FileAccess.open(output.path_join("resonance-logic.json"), FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print("RESONANCE_LOGIC " + JSON.stringify(result))
	quit(0 if passed else 1)
