extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func yield_frame() -> void:
	await process_frame

func counts(world: Node3D) -> Dictionary:
	var result := {}
	for key in world.build_stats:
		if not str(key).begins_with("build_ms_") and not str(key).begins_with("boot_"):
			result[key] = world.build_stats[key]
	return result

func placements(world: Node3D) -> PackedByteArray:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	for raw in world.find_children("*", "MultiMeshInstance3D", true, false):
		var node := raw as MultiMeshInstance3D
		digest.update(var_to_bytes(node.transform))
		for i in node.multimesh.instance_count:
			digest.update(var_to_bytes(node.multimesh.get_instance_transform(i)))
	return digest.finish()

func run() -> void:
	var script = load("res://scripts/world.gd")
	var synchronous: Node3D = script.new()
	root.add_child(synchronous)
	synchronous.set_paused(true)
	var expected := counts(synchronous)
	var expected_placements := placements(synchronous)
	var staged: Node3D = script.new()
	staged.staged_boot = true
	staged.boot_frame_yield = yield_frame
	root.add_child(staged)
	var initially_empty: bool = staged.build_stats.is_empty()
	await staged.build_world()
	var checks := {
		"explicit_build_barrier": initially_empty,
		"all_world_counts_identical": expected == counts(staged),
		"all_multimesh_placements_identical": expected_placements == placements(staged),
		"staged_world_remains_paused": staged._paused,
		"complete_ecology_arrays": staged._ecology_nodes.size() == staged._ecology_reactions.size()
	}
	var passed := true
	for value in checks.values(): passed = passed and value
	print("STAGED_WORLD_CHECKS " + JSON.stringify({"passed": passed, "checks": checks, "counts": expected}))
	synchronous.free()
	staged.free()
	quit(0 if passed else 1)
