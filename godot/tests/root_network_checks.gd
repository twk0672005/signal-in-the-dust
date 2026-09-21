extends SceneTree

const RootNetwork = preload("res://scripts/root_network.gd")

var checks: Dictionary = {}
var output: String = ""


func _initialize() -> void:
	output = _read_evidence_dir()
	if output.is_empty() or not output.is_absolute_path():
		printerr("root_network_checks requires --evidence-dir=<absolute-path>")
		quit(2)
		return
	run()


func run() -> void:
	var network = RootNetwork.new()
	checks.initial_state = network is RefCounted and network.snapshot() == {
		"version": 1,
		"ports": [0, 0, 0],
		"powered": 0,
		"complete": false,
	}

	var normal: bool = network.turn(0) and network.powered_count() == 1
	normal = normal and network.turn(1) and network.powered_count() == 1
	normal = normal and network.turn(1) and network.powered_count() == 2
	normal = normal and network.turn(2) and network.powered_count() == 3
	checks.normal_sequential_propagation = normal and network.ports == [1, 2, 1]

	checks.wrong_upstream_disconnects_downstream = network.turn(0) and network.ports == [2, 2, 1] and network.powered_count() == 0
	network.turn(0)
	checks.still_disconnected_until_upstream_matches = network.ports == [0, 2, 1] and network.powered_count() == 0
	network.turn(0)
	checks.reconnects_existing_downstream = network.ports == [1, 2, 1] and network.powered_count() == 3

	network = RootNetwork.new()
	var arbitrary_order: bool = network.turn(2) and network.ports == [0, 0, 1] and network.powered_count() == 0
	arbitrary_order = arbitrary_order and network.turn(1) and network.turn(1) and network.ports == [0, 2, 1] and network.powered_count() == 0
	arbitrary_order = arbitrary_order and network.turn(0) and network.powered_count() == 3
	checks.arbitrary_relay_order_does_not_fake_propagation = arbitrary_order

	network = RootNetwork.new()
	var before_premature := network.snapshot()
	var premature: bool = not network.pulse() and network.snapshot() == before_premature
	premature = premature and network.turn(0) and network.powered_count() == 1
	var partial_before_pulse := network.snapshot()
	checks.premature_pulse_is_atomic = premature and not network.pulse() and network.snapshot() == partial_before_pulse

	network.turn(1)
	network.turn(1)
	network.turn(2)
	var first_pulse: bool = network.pulse()
	var completed := network.snapshot()
	checks.pulse_is_one_shot = first_pulse and completed.complete and completed.powered == 3 and not network.pulse() and network.snapshot() == completed
	checks.complete_freezes_turns = not network.turn(0) and not network.turn(-1) and not network.turn(3) and network.snapshot() == completed

	network = RootNetwork.new()
	var invalid_before := network.snapshot()
	checks.invalid_turn_indices_are_atomic = not network.turn(-1) and not network.turn(3) and network.snapshot() == invalid_before

	network.turn(0)
	network.turn(1)
	network.turn(1)
	var saved := network.snapshot()
	var restored = RootNetwork.new()
	var restore_ok: bool = restored.restore(saved) and restored.snapshot() == saved
	var saved_ports: Array = saved.ports
	saved_ports[0] = 2
	checks.restore_round_trip_and_input_detachment = restore_ok and restored.ports == [1, 2, 0] and restored.powered_count() == 2

	var json_state: Variant = JSON.parse_string(JSON.stringify(restored.snapshot()))
	var restored_from_json = RootNetwork.new()
	checks.json_round_trip_restore = json_state is Dictionary and json_state.version is float and json_state.ports[0] is float and restored_from_json.restore(json_state) and restored_from_json.snapshot() == {
		"version": 1,
		"ports": [1, 2, 0],
		"powered": 2,
		"complete": false,
	}

	var detached_snapshot := restored.snapshot()
	var detached_ports: Array = detached_snapshot.ports
	detached_ports[1] = 0
	checks.snapshot_ports_are_detached = restored.ports == [1, 2, 0] and restored.powered_count() == 2

	var normalization_input := {
		"version": 1,
		"ports": [1, 2, 1],
		"powered": 3,
		"complete": false,
	}
	var normalized := RootNetwork.normalized(normalization_input)
	var normalized_ports: Array = normalized.ports
	normalized_ports[0] = 0
	checks.normalized_ports_are_detached = normalization_input.ports == [1, 2, 1]

	var stable_before_bad := restored.snapshot()
	var malformed: Array = [
		null,
		{},
		{"version": true, "ports": [1, 2, 0], "powered": 2, "complete": false},
		{"version": 2, "ports": [1, 2, 0], "powered": 2, "complete": false},
		{"version": 1, "ports": [1, 2], "powered": 2, "complete": false},
		{"version": 1, "ports": [1, 2, 0, 0], "powered": 2, "complete": false},
		{"version": 1, "ports": [true, 2, 0], "powered": 0, "complete": false},
		{"version": 1, "ports": [0.5, 2, 0], "powered": 0, "complete": false},
		{"version": 1, "ports": [NAN, 2, 0], "powered": 0, "complete": false},
		{"version": 1, "ports": [INF, 2, 0], "powered": 0, "complete": false},
		{"version": 1, "ports": [-1, 2, 0], "powered": 0, "complete": false},
		{"version": 1, "ports": [3, 2, 0], "powered": 0, "complete": false},
		{"version": 1, "ports": [1, 2, 0], "powered": true, "complete": false},
		{"version": 1, "ports": [1, 2, 0], "powered": 0.5, "complete": false},
		{"version": 1, "ports": [1, 2, 0], "powered": NAN, "complete": false},
		{"version": 1, "ports": [1, 2, 0], "powered": 1, "complete": false},
		{"version": 1, "ports": [1, 2, 0], "powered": 2, "complete": 1},
		{"version": 1, "ports": [1, 2, 0], "powered": 2, "complete": true},
	]
	var malformed_atomic: bool = true
	for candidate in malformed:
		malformed_atomic = malformed_atomic and RootNetwork.normalized(candidate).is_empty()
		malformed_atomic = malformed_atomic and not restored.restore(candidate)
		malformed_atomic = malformed_atomic and restored.snapshot() == stable_before_bad
	checks.malformed_restore_rejects_atomically = malformed_atomic

	var ready_not_complete := {
		"version": 1,
		"ports": [1, 2, 1],
		"powered": 3,
		"complete": false,
	}
	checks.ready_state_restores_before_pulse = restored.restore(ready_not_complete) and restored.powered_count() == 3 and not restored.complete and restored.pulse()

	restored.reset()
	checks.reset_returns_fresh_state = restored.snapshot() == {
		"version": 1,
		"ports": [0, 0, 0],
		"powered": 0,
		"complete": false,
	} and restored.turn(0)

	var passed := true
	for value in checks.values():
		passed = passed and bool(value)
	var result := {
		"passed": passed,
		"checks": checks,
		"kind": "pure_refcounted_root_network_rules_no_world_loaded",
	}
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(1)
		return
	var file := FileAccess.open(output.path_join("root-network-checks.json"), FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print("ROOT_NETWORK_CHECKS " + JSON.stringify(result))
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
