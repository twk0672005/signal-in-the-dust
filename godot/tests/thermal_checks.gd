extends SceneTree
const Rules=preload("res://scripts/thermal_route.gd")
func _initialize() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output=arg.trim_prefix("--evidence-dir=")
	if output.is_empty(): quit(2);return
	var t=Rules.new();var checks: Dictionary={}
	checks.warm_default=t.route=="warm" and not t.locked
	checks.requires_observation=not t.toggle_route()
	checks.low_pulse_rejected=not t.observe(0.74)
	checks.invalid_pulse_rejected=not t.observe(NAN) and not t.observe(INF) and not t.observe(1.1)
	checks.bright_observed=t.observe(0.75) and not t.observe(0.9)
	checks.cool_selected=t.toggle_route() and t.route=="cool"
	var original: Dictionary=t.snapshot()
	var u=Rules.new()
	checks.json_restore=u.restore(JSON.parse_string(JSON.stringify(original))) and u.route=="cool"
	checks.toggle_back=u.toggle_route() and u.route=="warm"
	checks.lock_once=t.lock_route() and not t.lock_route()
	checks.locked_no_change=not t.toggle_route() and not t.observe(0.9) and t.route=="cool"
	var bad: Dictionary=t.snapshot();bad.vent_observed=false
	checks.invalid_cool_rejected=not t.restore(bad) and t.route=="cool"
	bad=t.snapshot();bad.route="bogus";checks.unknown_route_rejected=not t.restore(bad)
	bad=t.snapshot();bad.locked="true";checks.bad_lock_rejected=not t.restore(bad)
	t.reset();checks.reset_warm=not t.vent_observed and not t.locked and t.route=="warm"
	checks.direct_warm_choice=t.lock_route() and t.route=="warm" and not t.vent_observed
	var passed:=true
	for v in checks.values(): passed=passed and bool(v)
	DirAccess.make_dir_recursive_absolute(output)
	var f:=FileAccess.open(output.path_join("thermal-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"passed":passed,"checks":checks,"kind":"pure_thermal_observation_route_choice_not_player_journey"},"  "));f.close()
	print("THERMAL_RULES "+JSON.stringify(checks));quit(0 if passed else 1)
