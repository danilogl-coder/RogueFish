class_name ZapFx
extends Node2D
## Jagged lightning segment that fades out quickly.

var points: PackedVector2Array = []
var color := Color("fff060")
var _t := 0.0
const LIFE := 0.18


func setup(from: Vector2, to: Vector2, p_color: Color) -> void:
	color = p_color
	var d := to - from
	var n := maxi(3, int(d.length() / 10.0))
	var perp := d.orthogonal().normalized()
	for i in n + 1:
		var t := float(i) / n
		var off := 0.0 if i == 0 or i == n else randf_range(-5, 5)
		points.append(from + d * t + perp * off)


func _process(delta: float) -> void:
	_t += delta
	if _t > LIFE:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - _t / LIFE
	draw_polyline(points, Color(color, a * 0.5), 4.0)
	draw_polyline(points, Color(1, 1, 1, a), 1.5)
