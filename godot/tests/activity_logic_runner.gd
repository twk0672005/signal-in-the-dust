extends SceneTree
var output := ""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output=arg.trim_prefix("--evidence-dir=")
	if output.is_empty(): quit(2); return
	var tracker=load("res://scripts/expedition_activities.gd").new()
	var checks: Dictionary = {}
	for i in 15: tracker.tick("aurora_shelf",0.0,{},0.2)
	checks["aurora_three_second_stillness"] = tracker.completed["aurora_shelf"]
	tracker.tick("aurora_shelf",4.0,{},0.1)
	checks["speed_interrupts_stillness"] = tracker.stillness == 0.0
	tracker.tick("ember_rift",0.0,{"veyra":true},0.1)
	tracker.tick("veil_marsh",0.0,{"aeral":true},0.1)
	tracker.tick("pale_decay",0.0,{"root_choir":true},0.1)
	checks["observations_complete_three_regions"] = tracker.count() == 4
	var saved: Dictionary = tracker.snapshot()
	var restored=load("res://scripts/expedition_activities.gd").new()
	checks["valid_snapshot_restores"] = restored.restore(saved) and restored.completed == tracker.completed
	checks["invalid_snapshot_rejected"] = not restored.restore({"version":99}) and restored.completed == tracker.completed
	restored.reset()
	checks["reset_clears_progress"] = restored.count() == 0 and restored.stillness == 0.0
	var passed := true
	for value in checks.values(): passed = passed and bool(value)
	DirAccess.make_dir_recursive_absolute(output)
	var result={"passed":passed,"checks":checks,"kind":"pure_activity_logic_not_scene_fixture"}
	var file=FileAccess.open(output.path_join("activity-logic.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
	print("ACTIVITY_LOGIC "+JSON.stringify(result))
	quit(0 if passed else 1)
