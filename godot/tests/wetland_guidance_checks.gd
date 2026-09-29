extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):output=arg.trim_prefix("--evidence-dir=")
	if output.is_empty():quit(2);return
	var game=load("res://main.tscn").instantiate();root.add_child(game);await physics_frame
	game.start_expedition();game._set_phase("exploring");game.rover.set_driving_enabled(false)
	game.rover.position=Vector3(game.world.path_x(-285),game.world.height_at(game.world.path_x(-285),-285),-285)
	var checks: Dictionary={}
	game._update_survey_readout();checks.life_before_locked_survey=game.ui._activity_context.target=="life_aeral"
	game.activities.field.marsh_reed=true;game.activities.wetland_study.prepare()
	game._update_survey_readout();checks.prepared_guides_to_aeral=game.ui._activity_context.target=="study_aeral"
	game.observed_ecology.aeral=true
	game.activities.wetland_study.observe("aeral",0.9);game._update_survey_readout();checks.alarm_still_guides_to_aeral=game.ui._activity_context.target=="study_aeral"
	game.activities.wetland_study.observe("aeral",0.0);game._update_survey_readout();checks.recovered_guides_to_pool=game.ui._activity_context.target=="marsh_pool"
	var expected: float=Vector2(game.rover.position.x,game.rover.position.z).distance_to(game.activities.point("marsh_pool"))
	checks.correct_pool_distance=absf(game.ui._activity_context.distance-expected)<0.001
	game.activities.tracked_encounter="veil_marsh";game._update_survey_readout();checks.manual_choice_respected=game.ui._activity_context.target=="encounter_veil_marsh"
	game.activities.tracked_encounter="";game.activities.field.marsh_pool=true;game._update_survey_readout();checks.completed_returns_to_main=game.ui._activity_context.target=="veil_marsh"
	var passed:=true
	for v in checks.values():passed=passed and bool(v)
	DirAccess.make_dir_recursive_absolute(output);var f:=FileAccess.open(output.path_join("guidance.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"passed":passed,"checks":checks,"kind":"navigation_state_fixture_not_a_player_journey"},"  "));f.close();print("GUIDANCE "+JSON.stringify(checks));game.queue_free();await process_frame;quit(0 if passed else 1)
