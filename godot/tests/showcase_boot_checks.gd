extends SceneTree
const Boot = preload("res://scripts/showcase_boot.gd")
var checks: Dictionary = {}

func _initialize() -> void:
	var flow := Boot.new()
	var initial := {"version": 1, "requestId": "start-1", "action": "new", "settings": {}}
	var first: Dictionary = flow.begin(initial)
	checks.empty_overrides_preserve_saved_preferences = first.settings.is_empty()
	checks.new_begins_validation_not_playing = flow.snapshot(true).stage == "validating" and not flow.first_frame_ready
	checks.duplicate_click_consumed_once = flow.begin(initial).is_empty()
	flow.set_stage("confirm-new")
	checks.confirmation_waits_for_render = not flow.snapshot(true).firstFrameReady
	checks.actual_matching_frame_allows_confirmation = flow.rendered("start-1", "confirm-new")
	flow.set_stage("home")
	checks.cancel_returns_home_without_claiming_frame = flow.snapshot(true).stage == "home" and not flow.first_frame_ready
	var next := {"version": 1, "requestId": "new-2", "action": "new", "settings": {"locale": "zh_TW", "volume": 0.4, "low_quality": true, "reduced_motion": true}}
	var second: Dictionary = flow.begin(next)
	next.settings.volume = 0.9
	checks.overrides_copied_without_caller_mutation = second.settings.volume == 0.4
	flow.set_stage("playing")
	checks.old_action_frame_cannot_enter_game = not flow.rendered("start-1", "playing")
	checks.old_modal_frame_cannot_enter_game = not flow.rendered("new-2", "confirm-new")
	checks.matching_play_frame_enters_game = flow.rendered("new-2", "playing")
	checks.continue_intent_rejected = flow.begin({"version":1,"requestId":"legacy","action":"continue"}).is_empty()
	var invalid: Array = [null, [], {}, {"version": true, "requestId": "bad", "action": "new"}, {"version": 1, "requestId": "", "action": "new"}, {"version": 1, "requestId": "bad", "action": "reset"}, {"version": 1, "requestId": "bad", "action": "new", "settings": []}, {"version": 1, "requestId": "bad", "action": "new", "settings": {"volume": NAN}}, {"version": 1, "requestId": "bad", "action": "new", "settings": {"volume": 2.0}}, {"version": 1, "requestId": "bad", "action": "new", "settings": {"low_quality": "false"}}, {"version": 1, "requestId": "bad", "action": "new", "settings": {"locale": "arbitrary"}}, {"version": 1, "requestId": "bad", "action": "new", "settings": {"save_path": "unexpected"}}]
	var rejected := true
	for value in invalid:
		rejected = flow.begin(value).is_empty() and rejected
	checks.invalid_inputs_leave_current_request_unchanged = rejected and flow.request_id == "new-2" and flow.stage == "playing"
	var passed := true
	for result in checks.values(): passed = passed and result
	print(JSON.stringify({"kind": "homepage_intent_state_unit_checks_not_runtime", "passed": passed, "checks": checks}))
	quit(0 if passed else 1)
