extends RefCounted
## Validated, idempotent homepage intent. Save authority remains in main/ExpeditionSave.

const STAGES := ["initializing", "validating", "confirm-new", "playing", "home", "error"]
const SETTINGS := ["locale", "volume", "reduced_motion", "low_quality"]
var request_id := ""
var stage := "initializing"
var first_frame_ready := false
var _consumed: Array[String] = []

static func validate(value: Variant) -> Dictionary:
	if not value is Dictionary: return {}
	if typeof(value.get("version")) not in [TYPE_INT, TYPE_FLOAT] or value.version != 1: return {}
	if not value.get("requestId") is String or not value.get("action") is String: return {}
	var id: String = value.requestId
	if id.is_empty() or id.length() > 128 or id != id.strip_edges(): return {}
	if value.action != "new": return {}
	var settings: Variant = value.get("settings", {})
	if not settings is Dictionary: return {}
	for key in settings:
		if key not in SETTINGS: return {}
		var setting: Variant = settings[key]
		match key:
			"locale":
				if not setting is String or setting not in ["en", "zh_TW"]: return {}
			"volume":
				if typeof(setting) not in [TYPE_INT, TYPE_FLOAT]: return {}
				if not is_finite(float(setting)) or float(setting) < 0.0 or float(setting) > 1.0: return {}
			_:
				if not setting is bool: return {}
	return {"version": 1, "requestId": id, "action": value.action, "settings": settings.duplicate(true)}

func begin(value: Variant) -> Dictionary:
	var request := validate(value)
	if request.is_empty() or request.requestId in _consumed: return {}
	request_id = request.requestId
	_consumed.append(request_id)
	# Bound session memory without ever retaining caller-owned objects.
	if _consumed.size() > 128: _consumed.pop_front()
	stage = "validating"
	first_frame_ready = false
	return request

func set_stage(value: String) -> void:
	if value not in STAGES: return
	stage = value
	first_frame_ready = false

func rendered(id: String, expected_stage: String) -> bool:
	# A frame from a previous action or modal must not release the current loader.
	if id != request_id or expected_stage != stage or stage not in ["playing", "confirm-new"]: return false
	first_frame_ready = true
	return true

func snapshot(saved_available: bool) -> Dictionary:
	return {"version": 1, "requestId": request_id, "stage": stage, "firstFrameReady": first_frame_ready, "savedAvailable": saved_available}
