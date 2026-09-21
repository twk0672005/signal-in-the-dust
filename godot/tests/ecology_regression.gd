extends SceneTree
var output := ""
var checks: Dictionary = {}
var samples: Array[Dictionary] = []
var world: Node3D

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output = arg.trim_prefix("--evidence-dir=")
	if output.is_empty(): quit(2); return
	run.call_deferred()

func advance(seconds: float) -> void:
	for i in int(round(seconds * 60.0)): world._process(1.0 / 60.0)

func run() -> void:
	world = load("res://scripts/world.gd").new()
	root.add_child(world)
	world.set_process(false)
	await physics_frame
	if not world.has_method("reaction_snapshot"):
		checks.responses_exist = false
		finish(); return
	for kind: String in ["veyra", "aeral", "root_choir"]:
		world.reset()
		var index := -1
		for i in world._ecology_meta.size():
			if world._ecology_meta[i]["kind"] == kind: index = i; break
		var node: Node3D = world._ecology_nodes[index]
		var base: Vector3 = world._ecology_meta[index]["base"]
		var observer := base + Vector3(0, 0, 8)
		world.set_player_state(observer, 8.0)
		advance(2.0)
		var frightened: Dictionary = world.reaction_snapshot()[index]
		checks[kind + "_responds_to_throttle"] = frightened.alert > 0.95
		if kind == "veyra":
			checks.veyra_retreats = node.position.z < base.z - 1.5
			checks.veyra_stays_on_terrain = absf(node.position.y - world.height_at(node.position.x, node.position.z) - 0.35) < 0.2
		elif kind == "aeral": checks.aeral_rises = node.position.y > base.y + 2.0
		else: checks.shell_contracts = node.scale.y < 0.6
		var distant_index := 4 if index == 0 else 0
		checks[kind + "_does_not_alert_distant_species"] = world.reaction_snapshot()[distant_index].alert == 0.0
		world.set_player_state(observer, 0.0)
		advance(1.0)
		checks[kind + "_retains_short_term_alarm"] = world.reaction_snapshot()[index].alert > 0.95
		advance(7.0)
		checks[kind + "_recovers_after_quiet"] = world.reaction_snapshot()[index].alert < 0.01
		world.set_player_state(node.position, 0.0)
		var observed: Dictionary = world.observe_ecology(node.position)
		advance(1.0)
		checks[kind + "_visible_observation_pulse"] = not observed.is_empty() and node.scale.x > 1.09 and world.reaction_snapshot()[index].pulse > 0.0
		world.set_paused(true)
		var paused: Dictionary = world.reaction_snapshot()[index]
		var pose := node.transform
		advance(2.0)
		checks[kind + "_pause_freezes_response"] = world.reaction_snapshot()[index] == paused and node.transform == pose
		world.set_paused(false)
		samples.append({"kind": kind, "stimulated": frightened, "recovered": paused})
	world.reset()
	var clean := true
	for record: Dictionary in world.reaction_snapshot():
		clean = clean and record.alert == 0.0 and record.pulse == 0.0 and record.recovery == 0.0
	for node: Node3D in world._ecology_nodes: clean = clean and node.scale == Vector3.ONE
	checks.reset_clears_reactions_and_pose = clean and world._observed_regions.is_empty()
	var road_clear:=true
	var opening_clear:=true
	for gate: Node3D in world._passage_gates:
		for body in gate.get_children():
			if not body is StaticBody3D: continue
			var shape: CollisionShape3D=body.get_child(0)
			var half: Vector3=shape.shape.size*0.5
			for x in [-half.x,half.x]:
				for z in [-half.z,half.z]:
					var corner: Vector3=shape.global_transform*Vector3(x,0,z)
					road_clear=road_clear and absf(corner.x-world.path_x(corner.z))>=6.5
					opening_clear=opening_clear and Vector2(corner.x-gate.position.x,corner.z-gate.position.z).length()>=6.0
	checks.membrane_banks_leave_main_road_clear=road_clear
	checks.membrane_banks_leave_activity_openings_clear=opening_clear
	finish()

func finish() -> void:
	var passed := true
	for value in checks.values(): passed = passed and bool(value)
	DirAccess.make_dir_recursive_absolute(output)
	var result := {"passed": passed, "checks": checks, "samples": samples, "kind": "deterministic_native_ecology_fixture_not_player_journey"}
	var file := FileAccess.open(output.path_join("ecology.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  ")); file.close()
	print("ECOLOGY_REGRESSION " + JSON.stringify(result))
	world.queue_free()
	await process_frame
	quit(0 if passed else 1)
