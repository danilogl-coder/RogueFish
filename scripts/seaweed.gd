extends Node2D

@export var sprite_scale := 2.0

var animation_time := 0.0
var animation_offset := 0.0

const FRAME_TIME := 0.18
const FRAME_SEQUENCE := [0, 1, 2, 1]
const SOURCE_REGION := Rect2(40.0, 50.0, 28.0, 70.0)
const FRAMES: Array[Texture2D] = [
	preload("res://assets/seaweed/seaweed_1.png"),
	preload("res://assets/seaweed/seaweed_2.png"),
	preload("res://assets/seaweed/seaweed_3.png")
]


func _ready() -> void:
	animation_offset = randf_range(0.0, FRAME_TIME * FRAME_SEQUENCE.size())


func _process(delta: float) -> void:
	animation_time += delta
	queue_redraw()


func _draw() -> void:
	var frame_step := int((animation_time + animation_offset) / FRAME_TIME) % FRAME_SEQUENCE.size()
	var frame := FRAMES[FRAME_SEQUENCE[frame_step]]
	var display_size := SOURCE_REGION.size * sprite_scale
	draw_texture_rect_region(
		frame,
		Rect2(Vector2(-display_size.x * 0.5, -display_size.y), display_size),
		SOURCE_REGION
	)
