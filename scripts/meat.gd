extends Node2D

signal depleted(meat)

@export var max_health := 3.0
@export var xp_per_health := 0.34
@export var golden_xp_per_health := 1.0
@export var sprite_scale := 0.15
@export var animation_speed := 4.0

var health := max_health
var xp_pool := 0.0
var is_depleted := false
var ground_y := INF
var float_time := 0.0
var meat_texture: Texture2D
var golden_meat_texture: Texture2D
var visual_scale := 1.0
var visual_flip := 1.0
var animation_offset := 0.0
var is_golden := false
var carried_xp_per_health := 0.0

const MEAT_TEXTURE_PATH := "res://assets/meat/meat1.png"
const GOLDEN_DARK := Color("#8f5a00")
const GOLDEN_MID := Color("#ffb320")
const GOLDEN_LIGHT := Color("#ffe27a")


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(MEAT_TEXTURE_PATH):
		meat_texture = load(MEAT_TEXTURE_PATH) as Texture2D


func setup(new_position: Vector2, new_ground_y := INF, new_angle := 0.0, new_is_golden := false, carried_xp := 0.0, drop_scale_multiplier := 1.0) -> void:
	position = new_position
	ground_y = new_ground_y
	rotation = new_angle
	is_golden = new_is_golden
	carried_xp_per_health = carried_xp / maxf(max_health, 1.0)
	if is_golden:
		_setup_golden_texture()
	visual_scale = randf_range(0.88, 1.12) * maxf(drop_scale_multiplier, 0.2)
	visual_flip = -1.0 if randf() < 0.5 else 1.0
	animation_offset = randf_range(0.0, 10.0)
	health = max_health
	is_depleted = false
	_apply_ground_limit()
	queue_redraw()


func _process(delta: float) -> void:
	float_time += delta
	queue_redraw()


func take_damage(amount: float, _is_critical := false) -> int:
	if is_depleted:
		return 0

	var damage := minf(health, amount)
	health -= damage
	var active_xp_per_health := golden_xp_per_health if is_golden else xp_per_health
	xp_pool += damage * (active_xp_per_health + carried_xp_per_health)
	var gained_xp := int(floorf(xp_pool))
	xp_pool -= float(gained_xp)

	if health <= 0.0:
		_deplete()
	return gained_xp


func is_consumable() -> bool:
	return not is_depleted


func get_interaction_rect() -> Rect2:
	var visual_size := _get_visual_size()
	return Rect2(global_position - visual_size * 0.5, visual_size)


func _deplete() -> void:
	if is_depleted:
		return
	is_depleted = true
	depleted.emit(self)
	queue_free()


func _apply_ground_limit() -> void:
	if ground_y >= INF:
		return
	position.y = minf(position.y, ground_y - _get_visual_size().y * 0.25)


func _draw() -> void:
	if is_depleted:
		return
	var frame := int((float_time + animation_offset) * animation_speed) % 4
	var bob_values: Array[float] = [-1.0, 0.0, 1.0, 0.0]
	var pulse_values: Array[float] = [1.0, 1.06, 0.98, 1.03]
	var bob: float = bob_values[frame]
	var pulse: float = pulse_values[frame]
	var visual_size: Vector2 = (_get_visual_size() * pulse).round()
	var texture := _get_current_texture()
	if texture == null:
		draw_rect(Rect2(Vector2(-visual_size.x * 0.5, -visual_size.y * 0.5 + bob), visual_size), Color("#d92d2d"))
		return
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2(visual_flip, 1.0))
	draw_texture_rect(texture, Rect2(Vector2(-visual_size.x * 0.5, -visual_size.y * 0.5), visual_size), false)


func _get_current_texture() -> Texture2D:
	if is_golden:
		if golden_meat_texture == null:
			_setup_golden_texture()
		return golden_meat_texture
	return meat_texture


func _get_visual_size() -> Vector2:
	if meat_texture == null:
		return Vector2(38.0, 25.0) * sprite_scale * visual_scale
	return meat_texture.get_size() * sprite_scale * visual_scale


func _setup_golden_texture() -> void:
	if golden_meat_texture != null:
		return
	if meat_texture == null:
		if ResourceLoader.exists(MEAT_TEXTURE_PATH):
			meat_texture = load(MEAT_TEXTURE_PATH) as Texture2D
	if meat_texture == null:
		return
	golden_meat_texture = _make_golden_texture(meat_texture)


func _make_golden_texture(source_texture: Texture2D) -> Texture2D:
	var image := source_texture.get_image()
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			if _is_meat_red_pixel(color):
				image.set_pixel(x, y, _red_to_gold(color))
	return ImageTexture.create_from_image(image)


func _is_meat_red_pixel(color: Color) -> bool:
	return color.r > color.g * 1.25 and color.r > color.b * 1.25 and color.r > 0.16


func _red_to_gold(color: Color) -> Color:
	var brightness := maxf(color.r, maxf(color.g, color.b))
	var gold := GOLDEN_DARK.lerp(GOLDEN_MID, clampf(brightness * 1.35, 0.0, 1.0))
	if brightness > 0.68:
		gold = gold.lerp(GOLDEN_LIGHT, clampf((brightness - 0.68) / 0.32, 0.0, 1.0))
	gold.a = color.a
	return gold
