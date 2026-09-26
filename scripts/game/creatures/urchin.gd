extends Creature
## Sea urchin: slow kelp grazer with venomous spines. Without otters keeping
## them in check, urchins overgraze and the kelp forest collapses.

var _kelp: Kelp


func _setup() -> void:
	anim_fps = 3.0
	on_floor = true


func hostile_now() -> bool:
	return true


func think(delta: float) -> void:
	position.y = DB.floor_at(position.x) - radius * 0.6
	if energy > 1.15:
		vel = Vector2.ZERO
		return
	if _kelp == null or _kelp.segments < 2:
		_kelp = game.world.nearest_kelp(position, 400.0)
	if _kelp:
		var dx := _kelp.position.x - position.x
		if absf(dx) > 5.0:
			vel = Vector2(signf(dx) * speed, 0)
		else:
			vel = Vector2.ZERO
			if can_hit("graze", 2.2) and _kelp.graze():
				attack_anim = 0.3
				feed(0.3)
	else:
		vel = Vector2.ZERO


func on_touch_player(p: Player) -> void:
	p.take_damage(contact_damage * dmg_mult, self)
