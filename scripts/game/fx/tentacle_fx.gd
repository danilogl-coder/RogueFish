class_name TentacleFx
extends Node2D
## A stinging tentacle that whips from the player to a target and retracts.

var src: Node2D
var dst: Node2D
var color := Color("e0a8ff")
var _t := 0.0
var _end := Vector2.ZERO
const LIFE := 0.3


func setup(p_src: Node2D, p_dst: Node2D, p_color: Color) -> TentacleFx:
	src = p_src
	dst = p_dst
	color = p_color
	z_index = 3
	return self


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE or not is_instance_valid(src):
		queue_free()
		return
	if is_instance_valid(dst):
		_end = dst.position
	queue_redraw()


func _draw() -> void:
	var a: Vector2 = src.position
	var reach := sin(clampf(_t / LIFE, 0.0, 1.0) * PI)
	var b := a.lerp(_end, reach)
	var nrm := (b - a).normalized().orthogonal()
	var pts := PackedVector2Array()
	for i in 13:
		var k := i / 12.0
		var wave := sin(k * PI * 2.0 + _t * 30.0) * 4.0 * (1.0 - k) * k * 4.0
		pts.append((a.lerp(b, k) + nrm * wave).round())
	draw_polyline(pts, Color(color.r * 0.5, color.g * 0.4, color.b * 0.6, 0.9), 3.0)
	draw_polyline(pts, color, 1.0)
	for i in range(2, 12, 3):
		draw_rect(Rect2(pts[i] - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, 0.8))
