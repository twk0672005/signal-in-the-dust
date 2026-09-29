extends SceneTree
const Study=preload("res://scripts/wetland_study.gd")
func _initialize() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):output=arg.trim_prefix("--evidence-dir=")
	if output.is_empty():quit(2);return
	var t=Study.new();var c: Dictionary={}
	c.unprepared_ignored=t.observe("aeral",1.0)=="" and not t.startled
	c.prepare_once=t.prepare() and not t.prepare()
	var calm=Study.new();calm.prepare()
	c.calm_observation_valid=calm.observe("aeral",0.0)=="quiet" and calm.recovered and not calm.startled
	var calm_restore=Study.new()
	c.quiet_roundtrip=calm_restore.restore(calm.snapshot()) and calm_restore.recovered and not calm_restore.startled
	c.other_species_ignored=t.observe("veyra",1.0)=="" and not t.startled
	c.invalid_rejected=t.observe("aeral",NAN)=="" and t.observe("aeral",1.1)=="" and t.observe("aeral",-1)==""
	c.partial_alarm_not_recorded=t.observe("aeral",0.64)==""
	c.alarm_recorded=t.observe("aeral",0.65)=="startled" and t.startled
	c.repeated_alarm_no_event=t.observe("aeral",0.9)==""
	var u=Study.new();c.json_roundtrip=u.restore(JSON.parse_string(JSON.stringify(t.snapshot()))) and u.startled and not u.recovered
	c.wait_for_recovery=t.observe("aeral",0.11)=="" and not t.recovered
	c.recovery_recorded=t.observe("aeral",0.1)=="recovered" and t.recovered
	c.one_shot=t.observe("aeral",0)==""
	var before: Dictionary=t.snapshot();var bad: Dictionary=before.duplicate(true);bad.startled=false;bad.version=1
	c.invalid_order_atomic=not t.restore(bad) and t.snapshot()==before
	bad=before.duplicate(true);bad.prepared="true";c.bad_type_rejected=not t.restore(bad)
	t.reset();c.reset=not t.prepared and not t.startled and not t.recovered
	var ok:=true
	for v in c.values():ok=ok and bool(v)
	DirAccess.make_dir_recursive_absolute(output);var f:=FileAccess.open(output.path_join("study-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"passed":ok,"checks":c,"kind":"pure_ordered_wetland_observation_rules"},"  "));f.close();print("WETLAND_RULES "+JSON.stringify(c));quit(0 if ok else 1)
