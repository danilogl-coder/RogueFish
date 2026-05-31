extends Node2D

var viewport_size := Vector2(1280.0, 720.0)
var swim_speed := 155.0
var offsets := [0.0, 0.0, 0.0]
var vertical_offsets := [0.0, 0.0, 0.0]
var vertical_world_offset := 0.0
var back_texture: Texture2D
var textures: Array[Texture2D] = []
var water_time := 0.0
var bubble_scroll_offset := 0.0
var bubble_vertical_scroll_offset := 0.0
var follow_camera: Camera2D
var back_layer_origin := Vector2.ZERO

@export var bubble_effect_strength := 0.75

const IMAGE_PATHS := [
	"res://assets/backgrounds/layer_1_pixel_art.png",
	"res://assets/backgrounds/layer_2.png",
	"res://assets/backgrounds/layer_3.png"
]
const BACK_IMAGE_PATH := "res://assets/backgrounds/layer_4.png"
const LAYER_SPEEDS := [0.12, 0.37, 0.78]
const VERTICAL_LAYER_SPEEDS := [0.85, 1.00, 1.15]
const BUBBLE_COUNT := 12


func _ready() -> void:
	if ResourceLoader.exists(BACK_IMAGE_PATH):
		back_texture = load(BACK_IMAGE_PATH) as Texture2D
	for path in IMAGE_PATHS:
		textures.append(load(path) as Texture2D if ResourceLoader.exists(path) else null)
	queue_redraw()


func set_viewport_size(new_size: Vector2) -> void:
	viewport_size = new_size
	queue_redraw()


func set_follow_camera(camera: Camera2D) -> void:
	follow_camera = camera
	_update_back_layer_origin()


func set_vertical_world_offset(world_offset: float) -> void:
	var previous_vertical_offset := vertical_world_offset
	vertical_world_offset = maxf(world_offset, 0.0)
	bubble_vertical_scroll_offset += vertical_world_offset - previous_vertical_offset
	for index in vertical_offsets.size():
		vertical_offsets[index] = vertical_world_offset * VERTICAL_LAYER_SPEEDS[index]
	queue_redraw()


func _process(delta: float) -> void:
	_update_back_layer_origin()
	water_time += delta
	bubble_scroll_offset += swim_speed * delta
	for index in offsets.size():
		offsets[index] += swim_speed * LAYER_SPEEDS[index] * delta
	queue_redraw()


func _update_back_layer_origin() -> void:
	if follow_camera == null or not is_instance_valid(follow_camera):
		return
	back_layer_origin = to_local(follow_camera.get_screen_center_position()) - viewport_size * 0.5


func _draw() -> void:
	if back_texture != null:
		_draw_back_layer()
	else:
		draw_rect(Rect2(Vector2.ZERO, viewport_size), Color("#062f43"))
	for index in textures.size():
		if textures[index] != null:
			_draw_image_layer(textures[index], offsets[index], vertical_offsets[index])
		elif index == 0:
			_draw_far_layer(offsets[index])
		elif index == 1:
			_draw_middle_layer(offsets[index])
		else:
			_draw_front_layer(offsets[index])
	_draw_bubbles()


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


func _draw_bubbles() -> void:
	for index in BUBBLE_COUNT:
		var _seed := float(index)
		var bubble_speed := 10.0 + fmod(_seed * 11.0, 16.0)
		var x := fposmod(_seed * 97.0 + sin(water_time * 0.65 + _seed) * 18.0 - bubble_scroll_offset, viewport_size.x + 80.0) - 40.0
		var y := fposmod(viewport_size.y - water_time * bubble_speed + _seed * 97.0 + bubble_vertical_scroll_offset * 0.85, viewport_size.y + 220.0) - 100.0
		var size := 2.0 + fmod(_seed * 5.0, 4.0)
		var alpha := (0.055 + fmod(_seed * 0.011, 0.055)) * bubble_effect_strength
		draw_circle(Vector2(x, y), size, Color(0.65, 0.95, 1.0, alpha))
		draw_circle(Vector2(x - size * 0.25, y - size * 0.25), maxf(1.0, size * 0.35), Color(0.86, 1.0, 1.0, alpha * 0.75))


func _draw_back_layer() -> void:
	var scale_factor: float = maxf(viewport_size.x / maxf(back_texture.get_width(), 1.0), viewport_size.y / maxf(back_texture.get_height(), 1.0))
	var image_size := back_texture.get_size() * scale_factor
	var x := back_layer_origin.x - image_size.x
	while x < back_layer_origin.x + viewport_size.x + image_size.x:
		draw_texture_rect(back_texture, Rect2(Vector2(x, back_layer_origin.y), image_size), false)
		x += image_size.x


func _draw_image_layer(texture: Texture2D, offset: float, vertical_offset := 0.0) -> void:
	var scale_factor: float = ceil(viewport_size.y / maxf(texture.get_height(), 1.0))
	var image_size := texture.get_size() * scale_factor
	var width: float = image_size.x
	var snapped_offset := snappedf(offset, scale_factor)
	var snapped_vertical_offset := snappedf(vertical_offset, scale_factor)
	var x: float = -fposmod(snapped_offset, width)
	while x < viewport_size.x:
		draw_texture_rect(texture, Rect2(Vector2(x, snapped_vertical_offset), image_size), false)
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
