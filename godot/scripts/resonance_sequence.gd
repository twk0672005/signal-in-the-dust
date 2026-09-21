extends RefCounted

const PATTERNS := [
	[0, 2, 1],
	[1, 0, 2, 1],
	[2, 1, 0, 2, 0],
]
const FIRST_TONE_TIME := 0.7
const TONE_INTERVAL := 0.8

var phase: String = "idle"
var round_index: int = 0
var matched: int = 0
var clock: float = 0.0
var solved: bool = false

func start() -> bool:
	if solved:
		return false
	phase = "listening"
	matched = 0
	clock = 0.0
	return true

func tick(delta: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if phase != "listening" or not is_finite(delta) or delta < 0.0:
		return events
	var previous := clock
	clock += delta
	var pattern: Array = PATTERNS[round_index]
	for index in pattern.size():
		var cue_time := FIRST_TONE_TIME + float(index) * TONE_INTERVAL
		if previous < cue_time and clock >= cue_time:
			events.append({"kind": "tone", "band": int(pattern[index])})
	var answer_time := FIRST_TONE_TIME + float(pattern.size()) * TONE_INTERVAL
	if previous < answer_time and clock >= answer_time:
		phase = "answer"
		events.append({"kind": "answer"})
	return events

func respond(band: int) -> String:
	if phase != "answer" or band < 0 or band > 2:
		return "ignored"
	var pattern: Array = PATTERNS[round_index]
	if int(pattern[matched]) != band:
		start()
		return "retry"
	matched += 1
	if matched < pattern.size():
		return "matched"
	if round_index == PATTERNS.size() - 1:
		solved = true
		phase = "solved"
		return "solved"
	round_index += 1
	phase = "listening"
	matched = 0
	clock = 0.0
	return "round_complete"

func reset(complete: bool = false) -> void:
	solved = complete
	if complete:
		round_index = PATTERNS.size() - 1
		matched = PATTERNS[round_index].size()
		phase = "solved"
	else:
		round_index = 0
		matched = 0
		phase = "idle"
	clock = 0.0

func snapshot() -> Dictionary:
	return {
		"phase": phase,
		"round_index": round_index,
		"matched": matched,
		"length": PATTERNS[round_index].size(),
		"solved": solved,
	}
