extends RefCounted

const MAX_ROUTE_POINTS: int = 64
const MAX_TICK_DELTA: float = 0.25
const FOLLOW_DISTANCE_MAX: float = 24.0
const FOLLOW_DISTANCE_MIN: float = 4.0
const NOISY_SPEED: float = 8.0
const ALARM_THRESHOLD: float = 0.2
const ALARM_RISE_RATE: float = 0.9
const ALARM_DECAY_RATE: float = 0.35
const TRAVEL_SPEED: float = 2.8
const POINT_EPSILON: float = 0.00001

var phase: String = "idle"
var position: Vector2 = Vector2.ZERO
var waypoint: int = 0
var alarm: float = 0.0
var travelled: float = 0.0

var _route: Array[Vector2] = []
var _origin: Vector2 = Vector2.ZERO


func configure(points: Array[Vector2]) -> bool:
	if phase != "idle" or points.is_empty() or points.size() > MAX_ROUTE_POINTS:
		return false
	var candidate: Array[Vector2] = []
	for point in points:
		if not _finite_vector(point):
			return false
		candidate.append(point)
	_route = candidate
	position=_route[0]
	_origin=position
	return true


func start(origin: Vector2) -> bool:
	if phase != "idle" or _route.is_empty() or not _finite_vector(origin):
		return false
	phase = "travelling"
	position = origin
	_origin = origin
	waypoint = 0
	alarm = 0.0
	travelled = 0.0
	return true


func reset(complete: bool = false) -> void:
	phase = "complete" if complete else "idle"
	alarm = 0.0
	travelled = 0.0
	waypoint = _route.size() if complete else 0
	if _route.is_empty():
		position = Vector2.ZERO
	else:
		position = _route[-1] if complete else _route[0]
	_origin=position


func tick(player: Vector2, speed: float, delta: float) -> bool:
	if phase == "idle" or phase == "complete":
		return false
	if not _finite_vector(player) or not is_finite(speed) or not is_finite(delta) or delta < 0.0:
		return false

	var step_delta := minf(delta, MAX_TICK_DELTA)
	var player_distance := position.distance_to(player)
	if player_distance > FOLLOW_DISTANCE_MAX:
		alarm = maxf(0.0, alarm - ALARM_DECAY_RATE * step_delta)
		phase = "waiting"
		return false

	var startled := absf(speed) > NOISY_SPEED or player_distance < FOLLOW_DISTANCE_MIN
	if startled:
		alarm = minf(1.0, alarm + ALARM_RISE_RATE * step_delta)
	else:
		alarm = maxf(0.0, alarm - ALARM_DECAY_RATE * step_delta)
	if startled or alarm >= ALARM_THRESHOLD:
		phase = "alarmed"
		return false

	phase = "travelling"
	var remaining := TRAVEL_SPEED * step_delta
	while waypoint < _route.size():
		var target := _route[waypoint]
		var separation := position.distance_to(target)
		if separation <= POINT_EPSILON:
			position = target
			waypoint += 1
			continue
		if remaining <= 0.0:
			break
		var advance := minf(remaining, separation)
		position = position.move_toward(target, advance)
		travelled += advance
		remaining -= advance
		if advance >= separation - POINT_EPSILON:
			position = target
			waypoint += 1
	if waypoint == _route.size():
		phase = "complete"
		return true
	return false


func snapshot() -> Dictionary:
	return {
		"phase": phase,
		"origin": {"x":_origin.x,"z":_origin.y},
		"position": {"x": position.x, "z": position.y},
		"waypoint": waypoint,
		"total": _route.size(),
		"alarm": alarm,
		"travelled": travelled,
		"complete": phase == "complete",
	}


static func _finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value)>=low and float(value)<=high

static func normalized(data: Variant) -> Dictionary:
	if not data is Dictionary: return {}
	var state: Variant=data.get("phase")
	if state not in ["idle","travelling","alarmed","waiting","complete"]: return {}
	var count: Variant=data.get("total")
	if not _number(count,1,64) or float(count)!=floorf(float(count)): return {}
	var cursor: Variant=data.get("waypoint")
	if not _number(cursor,0,float(count)) or float(cursor)!=floorf(float(cursor)): return {}
	var point: Variant=data.get("position")
	if not point is Dictionary or not _number(point.get("x"),-10000,10000) or not _number(point.get("z"),-10000,10000): return {}
	var origin: Variant=data.get("origin")
	if not origin is Dictionary or not _number(origin.get("x"),-10000,10000) or not _number(origin.get("z"),-10000,10000): return {}
	if not _number(data.get("alarm"),0,1) or not _number(data.get("travelled"),0,1000000): return {}
	if not data.get("complete") is bool or bool(data.complete)!=(state=="complete"): return {}
	if (state=="complete" and int(cursor)!=int(count)) or (state!="complete" and int(cursor)>=int(count)): return {}
	if state=="idle" and (int(cursor)!=0 or float(data.travelled)!=0.0 or float(data.alarm)!=0.0): return {}
	return {"phase":state,"origin":{"x":float(origin.x),"z":float(origin.z)},"position":{"x":float(point.x),"z":float(point.z)},"waypoint":int(cursor),"total":int(count),"alarm":float(data.alarm),"travelled":float(data.travelled),"complete":bool(data.complete)}

func restore(data: Variant) -> bool:
	var incoming:=normalized(data)
	if incoming.is_empty() or incoming.total!=_route.size(): return false
	var point:=Vector2(incoming.position.x,incoming.position.z)
	var origin:=Vector2(incoming.origin.x,incoming.origin.z)
	var bounds:=Rect2(origin,Vector2.ZERO)
	for mark in _route: bounds=bounds.expand(mark)
	if not bounds.grow(24.0).has_point(point): return false
	if incoming.phase=="complete" and point.distance_to(_route[-1])>0.01: return false
	if incoming.phase=="idle" and point.distance_to(_route[0])>0.01: return false
	if incoming.phase not in ["idle","complete"]:
		var closest:=Geometry2D.get_closest_point_to_segment(point,_route[incoming.waypoint-1] if incoming.waypoint>0 else origin,_route[incoming.waypoint])
		if point.distance_to(closest)>0.01: return false
	_origin=origin
	phase=incoming.phase;position=point;waypoint=incoming.waypoint
	alarm=incoming.alarm;travelled=incoming.travelled
	return true
