extends Creature
## Jellyfish: drifting hazard. Pulses upward, sinks slowly, stings on contact
## and catches small prey in its tentacles.

var _pulse_t := 0.0


func _setup() -> void:
	anim_fps = 6.0
	swallowable = false
	_pulse_t = randf() * 2.0


func think(delta: float) -> void:
	_pulse_t -= delta
	if _pulse_t <= 0.0:
		_pulse_t = randf_range(1.6, 2.6)
		var up := -speed * 2.6 if position.y > y_min + 20 else speed * 0.5
		vel = Vector2(randf_range(-10, 10), up)
		state_t = 0.0
	vel.y = move_toward(vel.y, 9.0, 40.0 * delta)
	vel.x = move_toward(vel.x, 0.0, 6.0 * delta)
	if position.y > y_max:
		_pulse_t = 0.0
	for c in game.grid.query(position + Vector2(0, 6), radius, 10.0):
		if c != self and c.faction == "herb" and c.tier == 0 and not c.dead:
			c.die({"eaten": true})
			attack_anim = 0.3


func _animate(delta: float) -> void:
	anim_t += delta
	if attack_anim > 0.0:
		attack_anim -= delta
		sprite.frame = 4 + int(anim_t * 10.0) % 2
	elif state_t < 0.6:
		sprite.frame = mini(3, int(state_t * 7.0))
	else:
		sprite.frame = 0


func light_pos() -> Vector2:
	return global_position + Vector2(0, -2)


func on_touch_player(p: Player) -> void:
	super.on_touch_player(p)
	p.apply_slow(0.4, 1.2)
	attack_anim = 0.4
	Sfx.play("zap", -8.0)
