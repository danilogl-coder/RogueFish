class_name TouchControls
extends Control
## Floating virtual joystick (left side) + hold-to-bite button (right side).
## Uses raw touch events so both thumbs work at once. Mouse works on desktop
## through "emulate touch from mouse".

signal bite_pressed
signal dash_pressed

const DEAD_ZONE := 0.18
var direction := Vector2.ZERO
var joy_radius := 26.0
var _joy_touch := -1
var _joy_center := Vector2.ZERO
var _joy_knob := Vector2.ZERO
var _btn_touch := -1
var _btn_center := Vector2.ZERO
var _btn_radius := 30.0
var _hold_t := 0.0
var _base_tex: Texture2D
var _knob_tex: Texture2D
var _btn_tex: Texture2D
var _btn_tex_p: Texture2D
var cooldown := 0.0
var dash_charges := 2
var dash_max := 2
var _dash_touch := -1
var _dash_tex: Texture2D
var _dash_tex_p: Texture2D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base_tex = Art.tex("ui/joy_base")
	_knob_tex = Art.tex("ui/joy_knob")
	_btn_tex = Art.tex("ui/btn_attack")
	_btn_tex_p = Art.tex("ui/btn_attack_pressed")
	_dash_tex = Art.tex("ui/btn_dash")
	_dash_tex_p = Art.tex("ui/btn_dash_pressed")


func _screen() -> Vector2:
	return get_viewport_rect().size


func _rest_joy() -> Vector2:
	return Vector2(58, _screen().y - 62)


func _btn_pos() -> Vector2:
	return Vector2(_screen().x - 56, _screen().y - 58)


func _dash_pos() -> Vector2:
	return _btn_pos() + Vector2(-58, 16)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var pos: Vector2 = event.position
		pos = get_global_transform_with_canvas().affine_inverse() * pos
		if event.pressed:
			if pos.y < 56.0:
				return
			if pos.distance_to(_dash_pos()) < 24.0 and _dash_touch == -1:
				_dash_touch = event.index
				dash_pressed.emit()
				get_viewport().set_input_as_handled()
			elif pos.distance_to(_btn_pos()) < _btn_radius + 18.0 or (pos.x > _screen().x * 0.62 and _btn_touch == -1):
				_btn_touch = event.index
				_hold_t = 0.0
				bite_pressed.emit()
				get_viewport().set_input_as_handled()
			elif pos.x < _screen().x * 0.5 and _joy_touch == -1:
				_joy_touch = event.index
				_joy_center = pos
				_joy_knob = pos
				direction = Vector2.ZERO
				get_viewport().set_input_as_handled()
		else:
			if event.index == _joy_touch:
				_joy_touch = -1
				direction = Vector2.ZERO
			if event.index == _btn_touch:
				_btn_touch = -1
			if event.index == _dash_touch:
				_dash_touch = -1
		queue_redraw()
	elif event is InputEventScreenDrag and event.index == _joy_touch:
		var pos2: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var d := pos2 - _joy_center
		if d.length() > joy_radius * 1.6:
			# drag the base along so the stick never "sticks"
			_joy_center = pos2 - d.normalized() * joy_radius * 1.6
			d = pos2 - _joy_center
		_joy_knob = _joy_center + d.limit_length(joy_radius)
		var v := d / joy_radius
		direction = v.limit_length(1.0) if v.length() > DEAD_ZONE else Vector2.ZERO
		queue_redraw()


func _process(delta: float) -> void:
	if _btn_touch != -1:
		_hold_t += delta
		if _hold_t > 0.12:
			bite_pressed.emit()
	queue_redraw()


func release_all() -> void:
	_joy_touch = -1
	_btn_touch = -1
	_dash_touch = -1
	direction = Vector2.ZERO


func _draw() -> void:
	var active := _joy_touch != -1
	var c := _joy_center if active else _rest_joy()
	var k := _joy_knob if active else c
	var a := 1.0 if active else 0.45
	draw_texture(_base_tex, (c - Vector2(32, 32)).round(), Color(1, 1, 1, a))
	draw_texture(_knob_tex, (k - Vector2(13, 13)).round(), Color(1, 1, 1, a))
	var bp := _btn_pos()
	var pressed := _btn_touch != -1
	draw_texture(_btn_tex_p if pressed else _btn_tex, (bp - Vector2(28, 28)).round(), Color(1, 1, 1, 0.9))
	if cooldown > 0.01:
		draw_arc(bp, 22.0, -PI * 0.5, -PI * 0.5 + TAU * cooldown, 32, Color(0.02, 0.04, 0.08, 0.7), 5.0)
	var dp := _dash_pos()
	var ready := dash_charges > 0
	draw_set_transform(dp, 0.0, Vector2(0.62, 0.62))
	draw_texture(_dash_tex_p if _dash_touch != -1 else _dash_tex, Vector2(-28, -28), Color(1, 1, 1, 0.9 if ready else 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in dash_max:
		var pip := Color("5ee0ff") if i < dash_charges else Color(1, 1, 1, 0.2)
		draw_rect(Rect2(dp + Vector2(-dash_max * 4.0 + i * 8.0, 20), Vector2(6, 3)), pip)
