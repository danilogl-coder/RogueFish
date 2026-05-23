extends Control

var direction := Vector2.ZERO
var radius := 70.0
var active_touch := -1
var mouse_active := false


func apply_layout(screen_size: Vector2) -> void:
	radius = clamp(minf(screen_size.x, screen_size.y) * 0.11, 54.0, 94.0)
	size = Vector2.ONE * radius * 2.4
	position = Vector2(screen_size.x * 0.045, screen_size.y - size.y - screen_size.y * 0.052)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch == -1 and get_global_rect().has_point(event.position):
			active_touch = event.index
			_update_direction(event.position)
		elif not event.pressed and event.index == active_touch:
			active_touch = -1
			_reset_direction()
	elif event is InputEventScreenDrag and event.index == active_touch:
		_update_direction(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and get_global_rect().has_point(event.position):
			mouse_active = true
			_update_direction(event.position)
		elif not event.pressed and mouse_active:
			mouse_active = false
			_reset_direction()
	elif event is InputEventMouseMotion and mouse_active:
		_update_direction(event.position)


func _update_direction(global_point: Vector2) -> void:
	var center := global_position + size * 0.5
	direction = ((global_point - center) / radius).limit_length(1.0)
	queue_redraw()


func _reset_direction() -> void:
	direction = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, radius, Color(0.03, 0.22, 0.32, 0.42))
	draw_arc(center, radius, 0.0, TAU, 40, Color(0.58, 0.91, 0.94, 0.48), 3.0, true)
	draw_circle(center + direction * radius, radius * 0.43, Color(0.22, 0.72, 0.78, 0.75))
	draw_arc(center + direction * radius, radius * 0.43, 0.0, TAU, 32, Color(0.79, 0.98, 0.98, 0.82), 2.0, true)
