class_name RingFx
extends Node2D
## Expanding ring (sonar, currents, telegraphs).

var radius_to := 100.0
var duration := 0.5
var color := Color("5ee0ff")
var width := 3.0
var follow: Node2D
var _t := 0.0
var radius := 0.0


func setup(p_radius: float, p_duration: float, p_color: Color, p_width := 3.0) -> RingFx:
	radius_to = p_radius
	duration = p_duration
	color = p_color
	width = p_width
	return self


func _process(delta: float) -> void:
	_t += delta
	if follow and is_instance_valid(follow):
		global_position = follow.global_position
	radius = radius_to * ease(clampf(_t / duration, 0.0, 1.0), 0.5)
	if _t >= duration:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - clampf(_t / duration, 0.0, 1.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(color, a * 0.35), width + 4.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(color, a), width)
