extends Creature
## Sea snail: crawls on the seabed grazing kelp; hides in its shell when hurt.

var _kelp: Kelp
var _graze_t := 0.0
var _hide_t := 0.0


func _setup() -> void:
	anim_fps = 4.0
	on_floor = true


func think(delta: float) -> void:
	_hide_t -= delta
	if _hide_t > 0.0:
		vel = Vector2.ZERO
		attack_anim = 0.2
		armor_mult = 0.2
		return
	armor_mult = 1.0
	position.y = DB.floor_at(position.x) - radius * 0.6
	if _kelp == null or _kelp.segments < 2:
		_kelp = game.world.nearest_kelp(position, 500.0)
	if _kelp:
		var dx := _kelp.position.x - position.x
		if absf(dx) > 6.0:
			vel = Vector2(signf(dx) * speed, 0)
		else:
			vel = Vector2.ZERO
			_graze_t += delta
			if _graze_t > 3.0:
				_graze_t = 0.0
				if _kelp.graze():
					feed(0.35)
	else:
		vel = Vector2(wander_dir.x * speed, 0)


func on_hurt(_info: Dictionary) -> void:
	_hide_t = 2.0
