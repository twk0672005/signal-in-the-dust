extends SceneTree
const Whispers = preload("res://scripts/showcase_whispers.gd")
const Map = preload("res://scripts/showcase_minimap.gd")
var checks: Dictionary = {}
func _initialize() -> void:
	var guide := Whispers.new()
	checks.first_context_is_shown = guide.offer("marsh", "Watch the wings.", 20, 6.0, 60.0)
	checks.repeated_context_has_no_extra_chime = not guide.offer("marsh", "Watch the wings.", 20)
	checks.equal_idle_hint_cannot_replace_active_hint = not guide.offer("idle", "Drive onward.", 20)
	checks.warning_preempts_flavor = guide.offer("alarm", "Give them room.", 60, 5.0, 20.0)
	checks.flavor_cannot_hide_warning = not guide.offer("other", "Look up.", 20)
	guide.advance(5.1)
	checks.expired_message_disappears = guide.key.is_empty() and guide.message.is_empty()
	checks.cooldown_blocks_repeat_after_expiry = not guide.offer("alarm", "Give them room.", 60)
	checks.encounter_can_take_focus = guide.offer("answer", "Reply 1 / 2 / 3", 80, 2.0, 0.0, true)
	guide.advance(1.0)
	checks.same_encounter_update_does_not_chime = not guide.offer("answer", "Reply 1 / 2 / 3 · 1/3", 80, 2.0, 0.0, true)
	guide.advance(1.1)
	checks.active_encounter_refresh_retains_instructions = guide.key == "answer" and guide.message.ends_with("1/3")
	guide.advance(NAN)
	checks.invalid_delta_does_not_corrupt_clock = is_finite(guide.clock)
	guide.reset()
	checks.new_journey_can_show_context_again = guide.offer("marsh", "Watch the wings.", 20)
	var map := Map.new()
	map.size = Vector2(168, 168)
	map.set_navigation(Vector2(10, -100), 0.0, Vector2.ZERO, false)
	var origin: Vector2 = map.projected(Vector2(10, -100))
	checks.rover_stays_centered = origin.is_equal_approx(Vector2(84,84))
	checks.north_world_z_projects_up = map.projected(Vector2(10,-110)).y < origin.y
	checks.east_world_x_projects_right = map.projected(Vector2(20,-100)).x > origin.x
	map.free()
	var passed := true
	for value in checks.values(): passed = passed and value
	print(JSON.stringify({"kind":"guidance_priority_and_map_projection_unit_checks_not_gameplay", "passed":passed,"checks":checks}))
	quit(0 if passed else 1)
