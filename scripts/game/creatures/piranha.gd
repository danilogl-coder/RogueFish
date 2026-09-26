extends Creature
## Piranha: fast pack hunter. Lunges at the player or at smaller prey.

var _lunge_cd := 0.0
var _jitter := Vector2.ZERO
var _prey: Creature


func _setup() -> void:
	anim_fps = 12.0
	_lunge_cd = randf() * 1.0


func think(delta: float) -> void:
	_lunge_cd -= delta
	if state == "retreat":
		if state_t > 0.35:
			state = "hunt"
		return
	if fears_player() and player_dist() < 120.0:
		flee(game.player.position, speed * 1.2, 300.0, delta)
		return
	var target_pos := Vector2.INF
	if is_wave or player_visible(170.0):
		target_pos = game.player.position
	else:
		if _prey == null or not is_instance_valid(_prey) or _prey.dead or state_t > 6.0:
			_prey = find_prey(150.0)
			state_t = 0.0
		if _prey:
			target_pos = _prey.position
	if target_pos == Vector2.INF:
		wander(delta, speed * 0.5)
		return
	if randf() < delta * 2.0:
		_jitter = Vector2(randf_range(-14, 14), randf_range(-14, 14))
	var d := position.distance_to(target_pos)
	if d < 34.0 and _lunge_cd <= 0.0:
		_lunge_cd = randf_range(0.9, 1.4)
		vel = (target_pos - position).normalized() * speed * 2.6
		attack_anim = 0.25
	else:
		seek(target_pos + _jitter, speed, 320.0, delta)
	if _prey and is_instance_valid(_prey) and not _prey.dead and position.distance_to(_prey.position) < radius + _prey.radius:
		_prey.die({"eaten": true})
		_prey = null
		attack_anim = 0.25
		state = "retreat"
		state_t = 0.0


func on_touch_player(p: Player) -> void:
	super.on_touch_player(p)
	state = "retreat"
	state_t = 0.0
	vel = (position - p.position).normalized() * speed
