class_name BeamFx
extends Node2D
## A straight beam (lightning lance / light ray) that flashes and fades.

var from := Vector2.ZERO
var to := Vector2.ZERO
var width := 6.0
var color := Color.WHITE
var duration := 0.25
var jagged := true
var _t := 0.0
var _pts := PackedVector2Array()


func setup(p_from: Vector2, p_to: Vector2, p_width: float, p_color: Color, p_duration := 0.25, p_jagged := true) -> BeamFx:
	from = p_from
	to = p_to
	width = p_width
	color = p_color
	duration = p_duration
	jagged = p_jagged
	z_index = 4
	_build()
	return self


func _build() -> void:
	_pts.clear()
	var n := maxi(2, int(from.distance_to(to) / 10.0))
	var nrm := (to - from).normalized().orthogonal()
	for i in n + 1:
		var k := float(i) / n
		var off := 0.0 if (i == 0 or i == n or not jagged) else randf_range(-4.0, 4.0)
		_pts.append((from.lerp(to, k) + nrm * off).round())


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	if jagged and int(_t * 30.0) % 2 == 0:
		_build()
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - _t / duration
	draw_polyline(_pts, Color(color.r, color.g, color.b, 0.28 * a), width * 1.8)
	draw_polyline(_pts, Color(color.r, color.g, color.b, 0.9 * a), maxf(1.0, width * 0.5))
	draw_polyline(_pts, Color(1, 1, 1, a), 1.0)
	draw_circle(to, width * 0.6 * a, Color(1, 1, 1, 0.8 * a))
