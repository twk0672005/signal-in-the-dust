extends RefCounted

const MIN_ROUTE_POINTS: int = 2
const MAX_ROUTE_POINTS: int = 16
const MIN_GATE_SEPARATION: float = 13.0
const MAX_TICK_DELTA: float = 0.25
const MAX_QUIET_SPEED: float = 5.5
const GATE_RADIUS: float = 6.0
const REARM_RADIUS: float = 8.0
const SCATTER_RADIUS: float = 12.0
const SCATTER_SECONDS: float = 2.0
const MIN_X: float = -94.0
const MAX_X: float = 94.0
const MIN_Z: float = -350.0
const MAX_Z: float = -170.0
const EPSILON: float = 0.00001

var phase: String = "idle"
var gate: int = 0
var alarm: float = 0.0
var armed: bool = false

var _route: Array[Vector2] = []


func configure(points: Array[Vector2]) -> bool:
	if phase != "idle" or not _route.is_empty() or not _valid_route(points):
		return false
	var candidate: Array[Vector2] = []
	for point in points:
		candidate.append(point)
	_route = candidate
	return true


func start() -> bool:
	if phase != "idle" or _route.is_empty():
		return false
	phase = "crossing"
	gate = 0
	alarm = 0.0
	armed = true
	return true


func tick(player: Vector2, speed: float, delta: float) -> String:
	if phase == "idle" or phase == "complete":
		return ""
	if not _finite_vector(player) or not is_finite(speed) or not is_finite(delta) or delta < 0.0:
		return ""

	var distance := player.distance_to(_route[gate])
	if absf(speed) > MAX_QUIET_SPEED and distance <= SCATTER_RADIUS:
		var first_scatter := phase != "scattered"
		phase = "scattered"
		alarm = SCATTER_SECONDS
		armed = false
		return "scattered" if first_scatter else ""

	var step_delta := minf(delta, MAX_TICK_DELTA)
	alarm = maxf(0.0, alarm - step_delta)
	if phase == "scattered":
		if not armed and distance > REARM_RADIUS:
			armed = true
		if armed and alarm <= EPSILON:
			alarm = 0.0
			phase = "crossing"

	if not armed or alarm > EPSILON or distance > GATE_RADIUS:
		return ""

	gate += 1
	if gate == _route.size():
		phase = "complete"
		alarm = 0.0
		armed = false
		return "complete"
	return "gate"


func reset(complete: bool = false) -> void:
	alarm = 0.0
	armed = false
	if complete and not _route.is_empty():
		phase = "complete"
		gate = _route.size()
	else:
		phase = "idle"
		gate = 0


func snapshot() -> Dictionary:
	var saved_route: Array[Dictionary] = []
	for point in _route:
		saved_route.append({"x": point.x, "z": point.y})
	return {
		"phase": phase,
		"route": saved_route,
		"gate": gate,
		"total": _route.size(),
		"alarm": alarm,
		"armed": armed,
		"complete": phase == "complete",
	}


static func normalized(data: Variant) -> Dictionary:
	if not data is Dictionary:
		return {}
	var state: Variant = data.get("phase")
	if state not in ["idle", "crossing", "scattered", "complete"]:
		return {}
	var raw_route: Variant = data.get("route")
	if not raw_route is Array or raw_route.size() < MIN_ROUTE_POINTS or raw_route.size() > MAX_ROUTE_POINTS:
		return {}
	var route: Array[Vector2] = []
	for raw_point in raw_route:
		if not raw_point is Dictionary:
			return {}
		if not _number(raw_point.get("x"), MIN_X, MAX_X) or not _number(raw_point.get("z"), MIN_Z, MAX_Z):
			return {}
		route.append(Vector2(float(raw_point.x), float(raw_point.z)))
	if not _valid_route(route):
		return {}

	var total: Variant = data.get("total")
	if not _integer(total, MIN_ROUTE_POINTS, MAX_ROUTE_POINTS) or int(total) != route.size():
		return {}
	var cursor: Variant = data.get("gate")
	if not _integer(cursor, 0, route.size()):
		return {}
	if not _number(data.get("alarm"), 0.0, SCATTER_SECONDS):
		return {}
	if not data.get("armed") is bool or not data.get("complete") is bool:
		return {}

	var cursor_value := int(cursor)
	var alarm_value := float(data.alarm)
	var armed_value := bool(data.armed)
	var complete_value := bool(data.complete)
	if complete_value != (state == "complete"):
		return {}
	match state:
		"idle":
			if cursor_value != 0 or alarm_value != 0.0 or armed_value:
				return {}
		"crossing":
			if cursor_value >= route.size() or alarm_value != 0.0 or not armed_value:
				return {}
		"scattered":
			if cursor_value >= route.size() or (armed_value and alarm_value == 0.0):
				return {}
		"complete":
			if cursor_value != route.size() or alarm_value != 0.0 or armed_value:
				return {}

	var saved_route: Array[Dictionary] = []
	for point in route:
		saved_route.append({"x": point.x, "z": point.y})
	return {
		"phase": String(state),
		"route": saved_route,
		"gate": cursor_value,
		"total": route.size(),
		"alarm": alarm_value,
		"armed": armed_value,
		"complete": complete_value,
	}


func restore(data: Variant) -> bool:
	var incoming := normalized(data)
	if incoming.is_empty() or incoming.total != _route.size():
		return false
	for index in _route.size():
		var saved: Dictionary = incoming.route[index]
		if _route[index] != Vector2(saved.x, saved.z):
			return false
	phase = incoming.phase
	gate = incoming.gate
	alarm = incoming.alarm
	armed = incoming.armed
	return true


static func _valid_route(points: Array[Vector2]) -> bool:
	if points.size() < MIN_ROUTE_POINTS or points.size() > MAX_ROUTE_POINTS:
		return false
	for index in points.size():
		var point := points[index]
		if not _finite_vector(point) or point.x < MIN_X or point.x > MAX_X or point.y < MIN_Z or point.y > MAX_Z:
			return false
		for earlier in index:
			if point.distance_to(points[earlier]) < MIN_GATE_SEPARATION:
				return false
	return true


static func _finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)


static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= low and float(value) <= high


static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value, float(low), float(high)) and float(value) == floorf(float(value))
