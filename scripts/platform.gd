extends StaticBody2D

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var platform_size := Vector2.ZERO
var platform_texture: Texture2D
var scroll_speed := 0.0
var scroll_offset := 0.0

const SPRITE_VISIBLE_REGION := Rect2(0.0, 107.0, 320.0, 13.0)
const SPRITE_SCALE := 3.0
const SCROLL_FACTOR := 1.15


func _ready() -> void:
	if ResourceLoader.exists("res://assets/platform.png"):
		platform_texture = load("res://assets/platform.png") as Texture2D


func configure(rect: Rect2) -> void:
	position = rect.position
	platform_size = rect.size
	var shape := RectangleShape2D.new()
	shape.size = platform_size
	collision_shape.shape = shape
	collision_shape.position = platform_size * 0.5
	queue_redraw()


func _process(delta: float) -> void:
	scroll_offset += scroll_speed * SCROLL_FACTOR * delta
	queue_redraw()


func get_visual_scroll_offset() -> float:
	return snappedf(scroll_offset, SPRITE_SCALE)


func _draw() -> void:
	if platform_texture != null:
		_draw_sprite_platform()
		return
	draw_rect(Rect2(Vector2.ZERO, platform_size), Color("#053949"))
	draw_rect(Rect2(0.0, 0.0, platform_size.x, 13.0), Color("#21af99"))
	draw_rect(Rect2(0.0, 13.0, platform_size.x, 9.0), Color("#14786f"))


func _draw_sprite_platform() -> void:
	var tile_size := SPRITE_VISIBLE_REGION.size * SPRITE_SCALE
	draw_rect(Rect2(0.0, tile_size.y, platform_size.x, platform_size.y - tile_size.y), Color("#03131c"))

	var snapped_offset := get_visual_scroll_offset()
	var x := -fposmod(snapped_offset, tile_size.x)
	while x < platform_size.x:
		draw_texture_rect_region(
			platform_texture,
			Rect2(x, 0.0, tile_size.x, tile_size.y),
			SPRITE_VISIBLE_REGION
		)
		x += tile_size.x
