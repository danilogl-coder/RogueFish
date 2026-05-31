extends Control

signal attack_pressed

var radius := 56.0
var active_touch := -1
var pressed_amount := 0.0


func apply_layout(screen_size: Vector2) -> void:
	radius = clamp(minf(screen_size.x, screen_size.y) * 0.085, 46.0, 68.0)
	size = Vector2.ONE * radius * 2.0
	position = Vector2(screen_size.x - size.x - screen_size.x * 0.06, screen_size.y - size.y - screen_size.y * 0.075)
	queue_redraw()


func _process(delta: float) -> void:
	pressed_amount = lerpf(pressed_amount, 0.0, 1.0 - exp(-12.0 * delta))
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch == -1 and _contains_point(event.position):
			active_touch = event.index
			_press()
			accept_event()
		elif not event.pressed and event.index == active_touch:
			active_touch = -1
			accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _contains_point(event.position):
			_press()
			accept_event()


func _contains_point(global_point: Vector2) -> bool:
	return (global_point - (global_position + size * 0.5)).length() <= radius


func _press() -> void:
	pressed_amount = 1.0
	attack_pressed.emit()
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var press_scale := lerpf(1.0, 0.88, pressed_amount)
	draw_circle(center, radius * press_scale, Color(0.36, 0.08, 0.16, 0.64))
	draw_arc(center, radius * press_scale, 0.0, TAU, 42, Color(1.0, 0.82, 0.62, 0.82), 3.0, true)
	draw_circle(center, radius * 0.46 * press_scale, Color(1.0, 0.32, 0.24, 0.72))
	draw_arc(center + Vector2(radius * 0.08, -radius * 0.05), radius * 0.28 * press_scale, -0.8, 0.85, 18, Color(1.0, 0.96, 0.78, 0.9), 4.0, true)
