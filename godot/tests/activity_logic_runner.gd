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
		if id=="marsh_pool":
			t.wetland_study.observe("aeral",0.9);t.wetland_study.observe("aeral",0.0)
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
	var escort_data: Dictionary=t.snapshot();escort_data.escort_complete=true;escort_data.thermal_state.locked=true
	var escort_restore=Tracker.new()
	checks.escort_saved=escort_restore.restore(escort_data) and escort_restore.escort_complete
	escort_data.escort_complete="bad"
	checks.bad_escort_rejected=not escort_restore.restore(escort_data) and escort_restore.escort_complete
	escort_data=t.snapshot();escort_data.version=5;escort_data.erase("escort_complete")
	checks.v5_escort_default=escort_restore.restore(escort_data) and not escort_restore.escort_complete
	escort_restore.escort_complete=true;escort_restore.reset()
	checks.escort_reset=not escort_restore.escort_complete
	var passage_rules=preload("res://scripts/quiet_passage.gd").new()
	passage_rules.configure([Vector2(0,-235),Vector2(0,-260)])
	passage_rules.start();passage_rules.tick(Vector2(0,-235),3,0.1)
	var passage_data: Dictionary=t.snapshot()
	passage_data.passage_state=passage_rules.snapshot()
	checks.passage_mid_restore=u.restore(passage_data) and u.passage_state.gate==1
	var preserved: Dictionary=u.snapshot()
	passage_data.passage_state.gate=1.5
	checks.passage_bad_progress_rejected=not u.restore(passage_data) and u.snapshot()==preserved
	passage_data=t.snapshot();passage_data.passage_complete=true
	checks.passage_completion_requires_state=not u.restore(passage_data)
	passage_data=t.snapshot();passage_data.version=6;passage_data.erase("passage_complete");passage_data.erase("passage_state")
	checks.v6_passage_migrates=u.restore(passage_data) and not u.passage_complete and u.passage_state.is_empty()
	u.reset();checks.passage_reset=u.passage_state.is_empty() and not u.passage_complete
	var root_rules=preload("res://scripts/root_network.gd").new()
	root_rules.turn(0)
	var root_data: Dictionary=t.snapshot();root_data.root_network_state=root_rules.snapshot()
	checks.root_mid_restore=u.restore(root_data) and u.root_network_state.powered==1
	var root_preserved: Dictionary=u.snapshot()
	root_data.root_network_state.ports=[1,1.5,0]
	checks.root_fractional_rejected=not u.restore(root_data) and u.snapshot()==root_preserved
	root_data=t.snapshot();root_data.root_network_state=[]
	checks.root_malformed_rejected=not u.restore(root_data)
	root_data=t.snapshot();root_data.version=7;root_data.erase("root_network_state")
	checks.v7_root_default=u.restore(root_data) and u.root_network_state.is_empty()
	u.reset();checks.root_reset=u.root_network_state.is_empty()
	u.reset();u.tick("ember_rift",0,{},0,Vector3.ZERO)
	checks.entered_region_discovered=u.discovered.ember_rift and not u.discovered.pale_decay
	u.tracked_encounter="ember_rift"
	var journal_data: Dictionary=JSON.parse_string(JSON.stringify(u.snapshot()))
	checks.tracked_journal_roundtrip=u.restore(journal_data) and u.tracked_encounter=="ember_rift"
	var journal_before: Dictionary=u.snapshot()
	journal_data.tracked_encounter="pale_decay"
	checks.unknown_region_not_trackable=not u.restore(journal_data) and u.snapshot()==journal_before
	journal_data=journal_before.duplicate(true);journal_data.discovered_regions.ember_rift="bad"
	checks.bad_discovery_rejected=not u.restore(journal_data)
	journal_data=journal_before.duplicate(true);journal_data.version=8;journal_data.erase("discovered_regions");journal_data.erase("tracked_encounter")
	checks.v8_journal_migrates=u.restore(journal_data) and u.discovered.ember_rift and u.tracked_encounter==""
	u.reset();checks.journal_reset=u.tracked_encounter=="" and not u.discovered.ember_rift
	var thermal_data: Dictionary=t.snapshot()
	thermal_data.thermal_state={"version":1,"vent_observed":true,"route":"cool","locked":false}
	checks.thermal_choice_restores=u.restore(thermal_data) and u.thermal_state.route=="cool"
	thermal_data.thermal_state.locked=true
	checks.thermal_lock_requires_started_escort=not u.restore(thermal_data)
	thermal_data=t.snapshot();thermal_data.version=9;thermal_data.erase("thermal_state")
	checks.v9_default_warm=u.restore(thermal_data) and u.thermal_state.route=="warm" and not u.thermal_state.locked
	thermal_data=t.snapshot();thermal_data.version=9;thermal_data.escort_complete=true;thermal_data.erase("thermal_state")
	checks.v9_completed_warm_locked=u.restore(thermal_data) and u.thermal_state.locked and u.thermal_state.route=="warm"
	var study_data: Dictionary=t.snapshot()
	study_data.wetland_study.recovered=false
	checks.finished_pool_requires_recovered=not u.restore(study_data)
	study_data=t.snapshot();study_data.version=10;study_data.erase("wetland_study")
	checks.legacy_complete_fields_preserved=u.restore(study_data) and u.field.marsh_pool and u.wetland_study.recovered
	study_data.field_notes.marsh_reed=false
	checks.legacy_pool_before_reed_preserved=u.restore(study_data) and u.wetland_study.recovered and not u.field.marsh_reed
	u.reset();var pool_point: Vector2=Tracker.point("marsh_pool")
	checks.pool_locked_without_study=not u.can_record("marsh_pool","veil_marsh",Vector3(pool_point.x,0,pool_point.y),0,{})
	var reed_point: Vector2=Tracker.point("marsh_reed")
	checks.reed_arms_sampler=u.record("marsh_reed","veil_marsh",Vector3(reed_point.x,0,reed_point.y),0,{}) and u.wetland_study.prepared
	u.wetland_study.observe("aeral",0.9)
	checks.pool_still_requires_recovery=not u.can_record("marsh_pool","veil_marsh",Vector3(pool_point.x,0,pool_point.y),0,{})
	u.wetland_study.observe("aeral",0)
	checks.pool_after_pair=u.record("marsh_pool","veil_marsh",Vector3(pool_point.x,0,pool_point.y),0,{})
	var ok:=true
	for value in checks.values(): ok=ok and bool(value)
	DirAccess.make_dir_recursive_absolute(output)
	var f:=FileAccess.open(output.path_join("survey-logic.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":ok,"checks":checks,"kind":"pure_spatial_rules_and_save_migration_not_playthrough"},"  "));f.close()
	print("SURVEY_LOGIC "+JSON.stringify({"passed":ok,"checks":checks}))
	quit(0 if ok else 1)
