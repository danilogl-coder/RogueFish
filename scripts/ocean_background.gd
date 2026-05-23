extends Node2D

var viewport_size := Vector2(1280.0, 720.0)
var swim_speed := 155.0
var offsets := [0.0, 0.0, 0.0]
var textures: Array[Texture2D] = []

const IMAGE_PATHS := [
	"res://assets/backgrounds/layer_1.png",
	"res://assets/backgrounds/layer_2.png",
	"res://assets/backgrounds/layer_3.png"
]
const LAYER_SPEEDS := [0.12, 0.37, 0.78]


func _ready() -> void:
	for path in IMAGE_PATHS:
		textures.append(load(path) as Texture2D if ResourceLoader.exists(path) else null)
	queue_redraw()


func set_viewport_size(new_size: Vector2) -> void:
	viewport_size = new_size
	queue_redraw()


func _process(delta: float) -> void:
	for index in offsets.size():
		offsets[index] += swim_speed * LAYER_SPEEDS[index] * delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color("#075789"))
	draw_rect(Rect2(0.0, viewport_size.y * 0.28, viewport_size.x, viewport_size.y * 0.72), Color("#086c99"))
	_draw_light_rays()
	for index in textures.size():
		if textures[index] != null:
			_draw_image_layer(textures[index], offsets[index])
		elif index == 0:
			_draw_far_layer(offsets[index])
		elif index == 1:
			_draw_middle_layer(offsets[index])
		else:
			_draw_front_layer(offsets[index])


func _draw_light_rays() -> void:
	var ray_color := Color(0.27, 0.81, 0.92, 0.075)
	draw_colored_polygon(PackedVector2Array([
		Vector2(viewport_size.x * 0.14, 0.0),
		Vector2(viewport_size.x * 0.27, 0.0),
		Vector2(viewport_size.x * 0.52, viewport_size.y),
		Vector2(viewport_size.x * 0.34, viewport_size.y)
	]), ray_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(viewport_size.x * 0.62, 0.0),
		Vector2(viewport_size.x * 0.69, 0.0),
		Vector2(viewport_size.x * 0.89, viewport_size.y),
		Vector2(viewport_size.x * 0.79, viewport_size.y)
	]), ray_color)


func _draw_image_layer(texture: Texture2D, offset: float) -> void:
	var scale_factor: float = ceil(viewport_size.y / maxf(texture.get_height(), 1.0))
	var image_size := texture.get_size() * scale_factor
	var width: float = image_size.x
	var snapped_offset := snappedf(offset, scale_factor)
	var x: float = -fposmod(snapped_offset, width)
	while x < viewport_size.x:
		draw_texture_rect(texture, Rect2(Vector2(x, 0.0), image_size), false)
		x += width


func _draw_far_layer(offset: float) -> void:
	var spacing := viewport_size.x * 0.28
	for index in range(-1, 6):
		var x := index * spacing - fposmod(offset, spacing)
		var y := viewport_size.y * (0.25 + 0.08 * (index % 3))
		draw_circle(Vector2(x, y), viewport_size.y * 0.045, Color(0.05, 0.37, 0.56, 0.30))
		draw_circle(Vector2(x + 42.0, y - 14.0), viewport_size.y * 0.026, Color(0.05, 0.37, 0.56, 0.30))


func _draw_middle_layer(offset: float) -> void:
	var base_y := viewport_size.y * 0.79
	var spacing := viewport_size.x * 0.22
	for index in range(-1, 8):
		var x := index * spacing - fposmod(offset, spacing)
		var height := viewport_size.y * (0.12 + 0.035 * (index % 3))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 18.0, base_y),
			Vector2(x - 7.0, base_y - height * 0.56),
			Vector2(x + 17.0, base_y - height),
			Vector2(x + 9.0, base_y - height * 0.42),
			Vector2(x + 28.0, base_y)
		]), Color("#087483"))
		draw_circle(Vector2(x + 42.0, base_y - 8.0), 22.0, Color("#075b75"))


func _draw_front_layer(offset: float) -> void:
	var bottom := viewport_size.y
	var spacing := viewport_size.x * 0.16
	draw_rect(Rect2(0.0, viewport_size.y * 0.84, viewport_size.x, viewport_size.y * 0.16), Color("#06475e"))
	for index in range(-1, 10):
		var x := index * spacing - fposmod(offset, spacing)
		var top := viewport_size.y * (0.72 - 0.025 * (index % 2))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, bottom),
			Vector2(x + 16.0, top + 26.0),
			Vector2(x + 8.0, top),
			Vector2(x + 40.0, top + 51.0),
			Vector2(x + 45.0, bottom)
		]), Color(0.02, 0.30, 0.36, 0.86))
