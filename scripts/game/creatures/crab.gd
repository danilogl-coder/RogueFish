extends Creature
## Crab: walks the seabed and leaps at anything swimming right above it.

var _jump_cd := 0.0


func _setup() -> void:
	anim_fps = 8.0
	state = "walk"
	on_floor = true
	wander_dir = Vector2(1 if randf() < 0.5 else -1, 0)


func think(delta: float) -> void:
	_jump_cd -= delta
	var floor_y := DB.FLOOR_Y - radius * 0.6
	if state == "air":
		vel.y += 520.0 * delta
		attack_anim = 0.2
		if position.y >= floor_y - 0.5 and vel.y > 0.0:
			state = "walk"
			state_t = 0.0
			vel = Vector2.ZERO
		return
	position.y = floor_y
	wander_t -= delta
	if wander_t <= 0.0:
		wander_t = randf_range(2.0, 5.0)
		wander_dir.x = -wander_dir.x if randf() < 0.5 else wander_dir.x
	vel = Vector2(wander_dir.x * speed * (0.6 + 0.4 * sin(anim_t * 3.0)), 0)
	if position.x < 30 or position.x > DB.WORLD_W - 30:
		wander_dir.x = -wander_dir.x
	var p: Player = game.player
	var dx := p.position.x - position.x
	var dy := position.y - p.position.y
	if _jump_cd <= 0.0 and p.alive and not p.is_hidden and absf(dx) < 70.0 and dy > 0.0 and dy < 150.0:
		state = "air"
		_jump_cd = 3.0
		vel = Vector2(dx * 1.3, -sqrt(2.0 * 520.0 * minf(dy + 10.0, 160.0)))
		Sfx.play("dash", -10.0)


func _animate(delta: float) -> void:
	anim_t += delta
	if absf(vel.x) > 3.0:
		facing = signf(vel.x)
	if attack_anim > 0.0:
		attack_anim -= delta
		sprite.frame = 4 if int(anim_t * 8.0) % 2 == 0 else 5
	else:
		sprite.frame = int(anim_t * anim_fps) % 4 if absf(vel.x) > 2.0 else 0
