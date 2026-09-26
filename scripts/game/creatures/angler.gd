extends Creature
## Anglerfish: deep ambusher. Its lure attracts small prey; snaps at anything
## that swims close, including the player.

var _snap_cd := 0.0
var _snap_dir := Vector2.RIGHT


func _setup() -> void:
	anim_fps = 4.0
	state = "lurk"


func light_pos() -> Vector2:
	return global_position + Vector2(facing * 16.0, -14.0) * scale.x


func think(delta: float) -> void:
	_snap_cd -= delta
	if state == "snap":
		vel = _snap_dir * 240.0
		if state_t > 0.25:
			state = "lurk"
			state_t = 0.0
		return
	# slow hover with bob
	var p: Player = game.player
	if fears_player() and player_dist() < 110.0:
		flee(p.position, speed * 1.5, 120.0, delta)
		return
	wander(delta, speed * 0.4)
	vel.y += sin(anim_t * 1.2) * 6.0 * delta
	if is_wave and player_visible(260.0):
		seek(p.position, speed * 1.8, 100.0, delta)
	var lure := light_pos()
	for c in game.grid.query(lure, 120.0, 10.0):
		if can_eat(c) and (hungry() or is_wave):
			c.knock += (lure - c.position).normalized() * 30.0 * delta * 10.0
			if c.position.distance_to(position) < radius + c.radius + 4.0:
				eat_prey(c)
				attack_anim = 0.3
	if _snap_cd <= 0.0 and player_visible(56.0 + p.radius):
		_snap_dir = (p.position - position).normalized()
		facing = signf(_snap_dir.x)
		state = "snap"
		state_t = 0.0
		_snap_cd = 1.6
		attack_anim = 0.35
		Sfx.play("bite", -3.0)
