extends Control
const Habitats = preload("res://scripts/expedition_activities.gd")
## North-up local map. Receives world-space data; never moves the rover or owns game state.

var _road := PackedVector2Array()
var _position := Vector2.ZERO
var _heading := 0.0
var _target := Vector2.ZERO
var _has_target := false
var _range := 85.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)

func set_road(points: PackedVector2Array) -> void:
	_road = points
	queue_redraw()

func set_navigation(point: Vector2, heading: float, target: Vector2, has_target: bool) -> void:
	_position = point
	_heading = heading
	_target = target
	_has_target = has_target
	queue_redraw()

func projected(point: Vector2) -> Vector2:
	var radius := minf(size.x, size.y) * 0.5 - 17.0
	return size * 0.5 + (point - _position) * (radius / _range)

func _draw() -> void:
	if size.x < 40.0 or size.y < 40.0: return
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 9.0
	draw_circle(center, radius, Color(0.025, 0.055, 0.085, 0.80))
	draw_arc(center, radius, 0.0, TAU, 64, Color(0.5, 0.77, 0.84, 0.38), 1.0, true)
	draw_arc(center, radius * 0.5, 0.0, TAU, 48, Color(0.45, 0.65, 0.74, 0.13), 1.0, true)
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(center + direction * (radius - 5.0), center + direction * radius, Color(0.65, 0.8, 0.85, 0.55), 1.0, true)
	for i in range(1, _road.size()):
		var a: Vector2 = projected(_road[i - 1]) - center
		var b: Vector2 = projected(_road[i]) - center
		if minf(a.length(), b.length()) > radius - 3.0: continue
		a = a.limit_length(radius - 4.0)
		b = b.limit_length(radius - 4.0)
		draw_line(center + a, center + b, Color(0.29, 0.45, 0.49, 0.8), 5.0, true)
		draw_line(center + a, center + b, Color(0.7, 0.86, 0.84, 0.8), 1.3, true)
	if _has_target:
		var offset := (projected(_target) - center).limit_length(radius - 8.0)
		draw_circle(center + offset, 3.0, Color(0.97, 0.77, 0.43))
		draw_arc(center + offset, 5.5, 0.0, TAU, 16, Color(0.97, 0.77, 0.43, 0.4), 1.0, true)
	# Static local landmarks are orientation references, never assigned objectives.
	for id in Habitats.SITES:
		var point := projected(Habitats.point(id))
		if point.distance_to(center) < radius - 6.0:
			draw_rect(Rect2(point - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.65, 0.79, 0.74, 0.60))
	var forward := Vector2(sin(_heading), -cos(_heading))
	var side := Vector2(-forward.y, forward.x)
	var arrow := PackedVector2Array([center + forward * 8.0, center - forward * 5.0 + side * 5.0, center - forward * 2.0, center - forward * 5.0 - side * 5.0])
	draw_colored_polygon(arrow, Color(0.78, 0.95, 0.96))
	draw_string(ThemeDB.fallback_font, Vector2(center.x - 4.0, center.y - radius + 14.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.78, 0.9, 0.94))
