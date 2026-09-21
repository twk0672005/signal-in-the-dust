extends SceneTree
const Tracker = preload("res://scripts/expedition_activities.gd")
const Save = preload("res://scripts/expedition_save.gd")
func _initialize() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output=arg.trim_prefix("--evidence-dir=")
	if output.is_empty(): quit(2);return
	var t=Tracker.new()
	var checks: Dictionary={}
	t.tick("aurora_shelf",0,{},30,Vector3(0,0,150))
	checks.spawn_idle_never_completes=t.count()==0
	var p: Vector2=Tracker.point("aurora_shelf")
	t.tick("aurora_shelf",0,{},2.99,Vector3(p.x,0,p.y))
	checks.requires_full_three_seconds=t.count()==0
	t.tick("aurora_shelf",24,{},0.1,Vector3(p.x,0,p.y))
	checks.driving_breaks_measurement=t.stillness==0
	t.tick("aurora_shelf",0,{},3,Vector3(p.x,0,p.y))
	checks.actual_survey_location_completes=t.completed.aurora_shelf
	t.tick("aurora_shelf",0,{},500,Vector3(p.x,0,p.y))
	checks.quiet_timer_capped=t.stillness==3.0
	checks.optional_not_automatic=t.optional_count()==0
	var observations={"veyra":true,"aeral":true,"root_choir":true}
	for id in Tracker.SITES:
		if id=="aurora_shelf": continue
		var site: Dictionary=Tracker.SITES[id]
		var point: Vector2=Tracker.point(id)
		var position:=Vector3(point.x,0,point.y)
		checks[id+"_remote_rejected"]=not t.record(id,site.region,position+Vector3(20,0,0),0,observations)
		checks[id+"_fast_rejected"]=not t.record(id,site.region,position,24,observations)
		if not str(site.kind).is_empty(): checks[id+"_requires_observation"]=not t.record(id,site.region,position,0,{})
		checks[id+"_real_site_recorded"]=t.record(id,site.region,position,0,observations)
		checks[id+"_one_shot"]=not t.record(id,site.region,position,0,observations)
	var saved: Dictionary=t.snapshot()
	var u=Tracker.new()
	checks.complete_sixteen_sites=t.count()==4 and t.optional_count()==4 and t.field_count()==8
	checks.roundtrip=u.restore(saved) and u.snapshot()==saved
	var invalid: Dictionary=saved.duplicate(true)
	invalid.completed_regions.aurora_shelf=false
	invalid.quiet_seconds="bad"
	checks.invalid_does_not_partially_mutate=not u.restore(invalid) and u.snapshot()==saved
	invalid=saved.duplicate(true);invalid.optional_observations=[]
	checks.invalid_optional_rejected=not u.restore(invalid) and u.snapshot()==saved
	var legacy={"version":1,"completed":t.completed.duplicate(),"stillness":999.0}
	checks.old_activity_migrates=u.restore(legacy) and u.count()==4 and u.optional_count()==0 and u.stillness==0
	var payload={"version":2,"phase":"exploring","position":{"x":0,"y":0,"z":150},"heading":0,"elapsed":1,"distance":0,"observedEcology":{},"transmitCount":0,"activities":invalid}
	checks.save_rejects_invalid_nested_activity=not Save.valid(payload)
	payload.version=1;payload.erase("activities")
	checks.legacy_outer_save_valid=Save.valid(payload)
	var migrated: Dictionary=Save.migrate(payload)
	checks.legacy_outer_migrates_empty=migrated.version==2 and Tracker.normalized(migrated.activities).completed_regions.aurora_shelf==false
	invalid=saved.duplicate(true);invalid.version=3.5
	checks.fractional_version_rejected=not u.restore(invalid)
	invalid=legacy.duplicate(true);invalid.optional=[]
	checks.malformed_legacy_optional_rejected=not u.restore(invalid)
	invalid=saved.duplicate(true);invalid.field_notes.pale_sink="bad"
	checks.malformed_field_rejected=not u.restore(invalid)
	var v3: Dictionary=saved.duplicate(true);v3.version=3;v3.erase("field_notes")
	checks.v3_migrates_empty_fields=u.restore(v3) and u.field_count()==0
	checks.fields_before_optional=u.target("aurora_shelf")=="aurora_lode"
	checks.missing_earlier_region_guidance=u.target("pale_decay")=="pale_bone"
	for id in Tracker.FIELD: u.field[id]=true
	u.field.aurora_lode=false
	checks.guides_back_to_missing_field=u.target("pale_decay")=="aurora_lode"
	u.reset();checks.reset=u.count()==0 and u.optional_count()==0 and u.field_count()==0 and u.stillness==0
	var resonance_data: Dictionary=t.snapshot()
	resonance_data.resonance_complete=true
	var resonance_restore=Tracker.new()
	checks.resonance_saved=resonance_restore.restore(resonance_data) and resonance_restore.resonance_complete
	resonance_data.resonance_complete="bad"
	checks.bad_resonance_rejected=not resonance_restore.restore(resonance_data) and resonance_restore.resonance_complete
	resonance_data=t.snapshot();resonance_data.version=4;resonance_data.erase("resonance_complete")
	checks.v4_resonance_default=resonance_restore.restore(resonance_data) and not resonance_restore.resonance_complete
	resonance_restore.resonance_complete=true;resonance_restore.reset()
	checks.resonance_reset=not resonance_restore.resonance_complete
	var ok:=true
	for value in checks.values(): ok=ok and bool(value)
	DirAccess.make_dir_recursive_absolute(output)
	var f:=FileAccess.open(output.path_join("survey-logic.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":ok,"checks":checks,"kind":"pure_spatial_rules_and_save_migration_not_playthrough"},"  "));f.close()
	print("SURVEY_LOGIC "+JSON.stringify({"passed":ok,"checks":checks}))
	quit(0 if ok else 1)
