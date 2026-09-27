class_name DamageNumber
extends Node2D
## Floating damage number / text.

var text := ""
var color := Color.WHITE
var size := 8
var _t := 0.0
var _life := 0.7
var _vel := Vector2(0, -38)


func setup(amount: float, crit: bool, p_color: Color) -> void:
	text = str(int(round(amount)))
	color = p_color
	if crit:
		text += "!"
		color = Color("ffbf45")
		size = 16
		_life = 0.9
	z_index = 30


func setup_text(p_text: String, p_color: Color, p_size := 8) -> void:
	text = tr(p_text)
	color = p_color
	size = p_size
	_life = 1.2
	_vel = Vector2(0, -22)


func _process(delta: float) -> void:
	_t += delta
	position += _vel * delta
	_vel *= pow(0.1, delta)
	if _t >= _life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - clampf((_t - _life * 0.6) / (_life * 0.4), 0.0, 1.0)
	var pop := 1.0 + maxf(0.0, 0.25 - _t) * 2.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(pop, pop) * 0.5)
	var font: Font = Art.num_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size * 2).x
	var pos := Vector2(-w * 0.5, 0)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size * 2, 6, Color(0.03, 0.05, 0.1, a))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size * 2, Color(color, a))
