extends Creature
## Sea turtle: peaceful grazer, tanky. Charges whoever hurts it for a while.

var _kelp: Kelp
var _graze_t := 0.0
var _anger := 0.0


func _setup() -> void:
	anim_fps = 5.0
	swallowable = true


func hostile_now() -> bool:
	return _anger > 0.0


func think(delta: float) -> void:
	_anger -= delta
	if _anger > 0.0:
		var p: Player = game.player
		seek(p.position, speed * 1.9, 160.0, delta)
		if player_dist() < radius + 20.0:
			attack_anim = 0.25
		return
	provoked = false
	if _kelp == null or _kelp.segments < 3:
		_kelp = game.world.nearest_kelp(position, 700.0)
	if _kelp:
		var target := _kelp.food_pos() + Vector2(-14.0 * facing, 0)
		if position.distance_to(target) > 10.0:
			seek(target, speed, 60.0, delta)
		else:
			vel *= pow(0.2, delta)
			_graze_t += delta
			if _graze_t > 2.0:
				_graze_t = 0.0
				attack_anim = 0.25
				_kelp.graze()
	else:
		wander(delta, speed * 0.6)


func on_hurt(_info: Dictionary) -> void:
	if _anger <= 0.0:
		game.float_text(position + Vector2(0, -radius - 6), "!", Color("ff5c4c"), 16)
	_anger = 4.0
	provoked = true
