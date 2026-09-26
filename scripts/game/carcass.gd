class_name Carcass
extends Node2D
## Remains of a dead animal. Sinks to the floor and is eaten piece by piece by
## scavengers (isopods, crabs, shrimps, sharks...) and by the player. It slowly
## rots into detritus that detritivores recycle into nutrients.

var game
var food := 3
var max_food := 3
var radius := 7.0
var sprite: Sprite2D
var _life := 55.0
var _rot_t := 11.0
var _vel_y := 14.0
var _t := 0.0


func setup(p_food: int) -> void:
	food = p_food
	max_food = p_food
	var big := food >= 6
	sprite = Art.sprite("fx/carcass_big" if big else "fx/carcass")
	add_child(sprite)
	radius = 10.0 if big else 7.0
	sprite.flip_h = randf() < 0.5
	sprite.rotation = randf_range(-0.3, 0.3)


func bite(amount := 1) -> int:
	var eaten := mini(amount, food)
	food -= eaten
	scale = Vector2.ONE * (0.6 + 0.4 * float(food) / maxf(1.0, max_food))
	if food <= 0:
		_remove(false)
	return eaten


func _physics_process(delta: float) -> void:
	_t += delta
	var floor_y := DB.floor_at(position.x) - 5.0
	if position.y < floor_y:
		position.y = minf(position.y + _vel_y * delta, floor_y)
		rotation += sin(_t * 2.0) * 0.2 * delta
	_life -= delta
	_rot_t -= delta
	if _rot_t <= 0.0:
		_rot_t = 11.0
		if food > 1:
			food -= 1
			game.ecosystem.spawn_detritus(position + Vector2(0, -3))
	if _life < 8.0:
		modulate.a = 0.5 + 0.5 * absf(sin(_t * 6.0))
	if _life <= 0.0:
		_remove(true)


func _remove(rot: bool) -> void:
	if rot and food > 0:
		game.ecosystem.spawn_detritus(position, mini(food, 3))
	game.carcasses.erase(self)
	queue_free()
