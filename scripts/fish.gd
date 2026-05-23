extends CharacterBody2D

@export var maximum_speed := 265.0
@export var world_scroll_factor := 0.8
@export var sprite_scale := 2

var control_vector := Vector2.ZERO
var swim_area := Rect2(80.0, 80.0, 880.0, 470.0)
var animation_time := 0.0
var tail_texture: Texture2D
var facing_direction := -1.0
var blink_time := 0.0
var next_blink_time := 2.6

const BLINK_FRAME_TIME := 0.075
const BLINK_SEQUENCE := [0, 1, 2, 1, 0]
const BODY_FRAMES: Array[Texture2D] = [
	preload("res://assets/fish_blink_1.png"),
	preload("res://assets/fish_blink_2.png"),
	preload("res://assets/fish_blink_3.png")
]


func _ready() -> void:
	if ResourceLoader.exists("res://assets/fish_tail.png"):
		tail_texture = load("res://assets/fish_tail.png") as Texture2D


func set_swim_area(area: Rect2) -> void:
	swim_area = area


func get_world_scroll_speed() -> float:
	return velocity.x * world_scroll_factor


func _physics_process(delta: float) -> void:
	animation_time += delta
	blink_time += delta
	if blink_time > next_blink_time + BLINK_FRAME_TIME * BLINK_SEQUENCE.size():
		blink_time = 0.0
		next_blink_time = randf_range(2.2, 4.5)
	var target_velocity := control_vector * maximum_speed
	velocity = velocity.lerp(target_velocity, 1.0 - exp(-9.0 * delta))
	if absf(control_vector.x) > 0.05:
		facing_direction = -signf(control_vector.x)
	move_and_slide()
	position.x = clamp(position.x, swim_area.position.x, swim_area.end.x)
	position.y = clamp(position.y, swim_area.position.y, swim_area.end.y)
	var target_rotation := velocity.y / maximum_speed * 0.14 * -facing_direction
	rotation = lerp_angle(rotation, target_rotation, 1.0 - exp(-7.0 * delta))
	queue_redraw()


func _draw() -> void:
	var float_offset := Vector2(0.0, sin(animation_time * 4.5) * 3.5)
	if tail_texture != null:
		_draw_textured_fish(float_offset)
		return

	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-facing_direction, 1.0))
	var tail_swing := sin(animation_time * 9.0) * 8.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-45.0, 0.0) + float_offset,
		Vector2(-81.0, -27.0 + tail_swing) + float_offset,
		Vector2(-73.0, 2.0) + float_offset,
		Vector2(-81.0, 29.0 - tail_swing) + float_offset
	]), Color("#f39a43"))
	draw_ellipse(Vector2(-6.0, 0.0) + float_offset, Vector2(54.0, 31.0), Color("#ffbd52"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3.0, -19.0) + float_offset,
		Vector2(17.0, -44.0) + float_offset,
		Vector2(29.0, -18.0) + float_offset
	]), Color("#f3983e"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6.0, 19.0) + float_offset,
		Vector2(17.0, 41.0) + float_offset,
		Vector2(23.0, 17.0) + float_offset
	]), Color("#f3983e"))
	draw_circle(Vector2(28.0, -9.0) + float_offset, 6.5, Color.WHITE)
	draw_circle(Vector2(30.0, -9.0) + float_offset, 3.2, Color("#082e46"))
	draw_arc(Vector2(37.0, 6.0) + float_offset, 9.0, 0.3, 1.4, 10, Color("#c85e35"), 2.0, true)


func _draw_textured_fish(float_offset: Vector2) -> void:
	var tail_angle := sin(animation_time * 9.0) * 0.22
	var direction_scale := Vector2(facing_direction * sprite_scale, sprite_scale)
	var tail_pivot := Vector2(17.0 * facing_direction, 0.0) + float_offset
	var body_texture := BODY_FRAMES[_get_blink_frame()]

	draw_set_transform(tail_pivot, tail_angle * facing_direction, direction_scale)
	draw_texture(tail_texture, Vector2(-11.0, -24.0))

	draw_set_transform(float_offset, 0.0, direction_scale)
	draw_texture(body_texture, Vector2(-31.0, -31.0))


func _get_blink_frame() -> int:
	if blink_time < next_blink_time:
		return 0

	var sequence_index := int((blink_time - next_blink_time) / BLINK_FRAME_TIME)
	if sequence_index >= BLINK_SEQUENCE.size():
		return 0
	return BLINK_SEQUENCE[sequence_index]


func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 28:
		var angle := TAU * float(index) / 28.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
