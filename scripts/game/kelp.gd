class_name Kelp
extends Node2D
## A kelp plant: grows segments over time, is grazed by herbivores and
## releases plankton (food for herbivores, tiny XP for the player).

const MAX_SEG := 14
var game
var segments := 6
var max_segments := 10
var _grow_t := 0.0
var _spore_t := 0.0
var _t := 0.0
var _tex: Texture2D
var _seed := 0.0


func _ready() -> void:
	_tex = Art.tex("env/kelp")
	max_segments = randi_range(7, MAX_SEG)
	segments = randi_range(4, max_segments)
	_seed = randf() * TAU
	_spore_t = randf() * 4.0


func food_pos() -> Vector2:
	return position + Vector2(_sway(segments * 0.5), -segments * 8.0 * 0.5)


func _sway(i: float) -> float:
	return sin(_t * 1.4 + _seed + i * 0.35) * i * 0.55


func graze(amount := 1) -> bool:
	if segments <= 1:
		return false
	segments -= amount
	_grow_t = 0.0
	queue_redraw()
	return true


func _process(delta: float) -> void:
	_t += delta
	_grow_t += delta
	# growth needs light (shallow water) and dissolved nutrients
	if _grow_t > 4.0 and segments < max_segments:
		_grow_t = 0.0
		if game != null and game.ecosystem != null and game.ecosystem.take_nutrients(position.x, 1.5):
			segments += 1
	_spore_t -= delta
	if _spore_t <= 0.0:
		_spore_t = randf_range(4.0, 7.0)
		if segments >= 4 and game != null and game.plankton.size() < 70:
			var top := position + Vector2(_sway(segments), -segments * 8.0)
			game.spawn_pickup("plankton", top + Vector2(randf_range(-6, 6), randf_range(0, 20)), 1)
	queue_redraw()


func _draw() -> void:
	draw_texture_rect_region(_tex, Rect2(Vector2(-6, -9), Vector2(12, 10)), Rect2(36, 0, 12, 10))
	for i in segments:
		var x := roundf(_sway(i))
		var y := -8.0 * (i + 1) - 1.0
		var fr := 2 if i == segments - 1 else (i % 2)
		draw_texture_rect_region(_tex, Rect2(Vector2(x - 6, y), Vector2(12, 10)), Rect2(fr * 12, 0, 12, 10))
