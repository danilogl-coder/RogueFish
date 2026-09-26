class_name Telegraph
extends Node2D
## Red warning shape shown before a heavy attack lands.

var shape := "circle"
var radius := 30.0
var size_v := Vector2(100, 20)
var duration := 0.8
var _t := 0.0


func circle(p_radius: float, p_duration: float) -> Telegraph:
	shape = "circle"
	radius = p_radius
	duration = p_duration
	return self


func line(length: float, width: float, p_duration: float) -> Telegraph:
	shape = "line"
	size_v = Vector2(length, width)
	duration = p_duration
	return self


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / duration, 0.0, 1.0)
	var blink := 0.5 + 0.5 * sin(_t * 30.0)
	var c := Color(1.0, 0.25, 0.2, 0.18 + 0.2 * blink)
	var edge := Color(1.0, 0.4, 0.3, 0.8)
	if shape == "circle":
		draw_circle(Vector2.ZERO, radius, c)
		draw_circle(Vector2.ZERO, radius * k, Color(1, 0.3, 0.2, 0.25))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 40, edge, 1.5)
	else:
		var r := Rect2(Vector2(0, -size_v.y * 0.5), size_v)
		draw_rect(r, c)
		draw_rect(Rect2(r.position, Vector2(size_v.x * k, size_v.y)), Color(1, 0.3, 0.2, 0.22))
		draw_rect(r, edge, false, 1.5)
