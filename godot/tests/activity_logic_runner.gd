extends SceneTree
const Tracker = preload("res://scripts/expedition_activities.gd")
const Save = preload("res://scripts/expedition_save.gd")
func _initialize() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output=arg.trim_prefix("--evidence-dir=")
	if output.is_empty(): quit(2); return
	var t=Tracker.new()
	var checks: Dictionary={}
	var p: Vector2=Tracker.point("aurora_shelf")
	t.tick("aurora_shelf",0,{},2.99,Vector3(p.x,0,p.y)); checks["three_seconds_required"]=t.count()==0
	t.tick("aurora_shelf",24,{},0.1,Vector3(p.x,0,p.y)); checks["moving_breaks_timer"]=t.stillness==0.0
	t.tick("aurora_shelf",0,{},3.0,Vector3(p.x,0,p.y)); checks["aurora_completed"]=t.completed.aurora_shelf
	checks["field_starts_empty"]=t.field_count()==0
	var observations={"veyra":true,"aeral":true,"root_choir":true}
	for id in Tracker.OPTIONAL:
		var site: Dictionary=Tracker.SITES[id]; var q: Vector2=Tracker.point(id); var pos:=Vector3(q.x,0,q.y)
		checks[id+"_recorded"]=t.record(id,site.region,pos,0,observations)
	checks["four_optionals"]=t.optional_count()==4
	for region in Tracker.REGIONS:
		if not t.completed[region]: t.completed[region]=true
	for id in Tracker.FIELD:
		var site: Dictionary=Tracker.SITES[id]; var q: Vector2=Tracker.point(id); var pos:=Vector3(q.x,0,q.y)
		checks[id+"_recorded"]=t.record(id,site.region,pos,0,observations)
	checks["eight_field_notes"]=t.field_count()==8
	var saved: Dictionary=t.snapshot(); var restored=Tracker.new()
	checks["version_four_roundtrip"]=restored.restore(saved) and restored.snapshot()==saved
	var invalid: Dictionary=saved.duplicate(true); invalid.field_notes.aurora_lode="bad"
	checks["invalid_field_rejected_without_mutation"]=not restored.restore(invalid) and restored.snapshot()==saved
	var legacy={"version":1,"completed":t.completed.duplicate(true),"stillness":999.0}
	var legacy_tracker=Tracker.new(); checks["legacy_activity_migrates"]=legacy_tracker.restore(legacy) and legacy_tracker.field_count()==0 and legacy_tracker.optional_count()==0
	var payload={"version":2,"phase":"exploring","position":{"x":0,"y":0,"z":150},"heading":0,"elapsed":1,"distance":0,"observedEcology":{},"transmitCount":0,"activities":invalid}
	checks["save_rejects_invalid_field"]=not Save.valid(payload)
	var ok:=true
	for value in checks.values(): ok=ok and bool(value)
	DirAccess.make_dir_recursive_absolute(output)
	var file:=FileAccess.open(output.path_join("field-activity-logic.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":ok,"checks":checks,"kind":"pure_field_activity_and_save_migration"},"  ")); file.close()
	print("FIELD_ACTIVITY_LOGIC "+JSON.stringify({"passed":ok,"checks":checks}))
	quit(0 if ok else 1)
