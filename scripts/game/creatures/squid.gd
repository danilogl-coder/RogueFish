extends Creature
## Squid: keeps its distance, spits ink bolts and jets away leaving ink clouds.

var _shoot_cd := 1.5
var _jet_cd := 0.0


func _setup() -> void:
	anim_fps = 8.0


func think(delta: float) -> void:
	_shoot_cd -= delta
	_jet_cd -= delta
	var p: Player = game.player
	if fears_player() and player_dist() < 150.0:
		flee(p.position, speed * 1.4, 200.0, delta)
		return
	if not (is_wave or player_visible(250.0)):
		var prey := find_prey(130.0)
		if prey:
			seek(prey.position, speed, 150.0, delta)
			if position.distance_to(prey.position) < radius + prey.radius:
				eat_prey(prey)
		else:
			wander(delta, speed * 0.5)
		return
	var to := p.position - position
	var d := to.length()
	if d < 70.0 and _jet_cd <= 0.0:
		_jet_cd = 3.0
		vel = -to.normalized() * speed * 3.5
		attack_anim = 0.4
		var cloud := AreaEffect.new().setup_cloud("fx/ink_cloud", position, 24.0, 2.5, 3.0, 0.45)
		cloud.hostile = true
		game.spawn_area(cloud)
		Sfx.play("ink", -6.0)
		return
	var want: Vector2
	if d > 170.0:
		want = to.normalized() * speed
	elif d < 120.0:
		want = -to.normalized() * speed
	else:
		want = to.normalized().orthogonal() * speed * 0.7
	steer(want, 160.0, delta)
	facing = signf(to.x)
	if _shoot_cd <= 0.0 and d < 240.0:
		_shoot_cd = randf_range(2.2, 3.0)
		var pr := Projectile.new().setup("fx/ink_ball", to.normalized() * 130.0, 7.0 * dmg_mult, 3.0, 4.0)
		pr.hostile = true
		pr.slow = 0.35
		pr.position = position
		game.spawn_projectile(pr)
		attack_anim = 0.3


func _animate(delta: float) -> void:
	super._animate(delta)
	sprite.flip_h = facing < 0.0
