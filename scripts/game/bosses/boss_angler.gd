extends Boss
## Rainha Abissal: darkens the ocean. Vanishes and reappears next to the
## player to lunge, fires rings of homing light orbs, summons anglers.

var _lunge_dir := Vector2.RIGHT
var _orb_t := 4.0
var _summon_t := 8.0


func _setup() -> void:
	sprite = Art.sprite("creatures/boss_angler")
	add_child(sprite)
	radius = 34.0
	speed = 55.0
	anim_fps = 4.0
	light_radius = 90.0
	state = "stalk"
	game.darkness.extra = 0.45
	game.darkness.tint_target = Color(0.03, 0.0, 0.06)


func light_pos() -> Vector2:
	return global_position + Vector2(facing * 57.0, -42.0)


func think(delta: float) -> void:
	var p: Player = game.player
	_orb_t -= delta
	_summon_t -= delta
	match state:
		"stalk":
			seek(p.position, speed * (1.3 if enraged else 1.0), 80.0, delta)
			if _orb_t <= 0.0:
				_orb_t = 5.0 if not enraged else 3.5
				_orb_ring(8 if not enraged else 12)
			if _summon_t <= 0.0:
				_summon_t = 14.0
				summon("angler", 2)
			if state_t > (4.0 if not enraged else 3.0):
				_go("vanish")
		"vanish":
			vel *= pow(0.05, delta)
			sprite.modulate.a = clampf(1.0 - state_t / 0.6, 0.0, 1.0)
			if state_t > 0.7:
				var side := -1.0 if randf() < 0.5 else 1.0
				position = p.position + Vector2(side * 130.0, randf_range(-40, 40))
				position.y = clampf(position.y, 80.0, DB.FLOOR_Y - 60.0)
				_lunge_dir = (p.position - position).normalized()
				facing = signf(_lunge_dir.x)
				telegraph_line(position, _lunge_dir, 260.0, 50.0, 0.65)
				_go("appear")
		"appear":
			sprite.modulate.a = clampf(state_t / 0.4, 0.0, 1.0)
			vel = Vector2.ZERO
			if state_t > 0.65:
				_go("lunge")
				attack_anim = 0.6
				Sfx.play("bite")
		"lunge":
			vel = _lunge_dir * 420.0
			if state_t > 0.55:
				_go("stalk")


func _orb_ring(n: int) -> void:
	for i in n:
		var d := Vector2.from_angle(TAU * i / n)
		var pr := Projectile.new().setup("fx/light_orb", d * 70.0, 10.0 * dmg_mult, 4.5, 4.0)
		pr.hostile = true
		pr.homing = 0.8
		pr.rotate_to_vel = false
		pr.position = light_pos()
		game.spawn_projectile(pr)
	Sfx.play("sonar", -4.0)


func _go(s: String) -> void:
	state = s
	state_t = 0.0


func hostile_now() -> bool:
	return state != "vanish"


func on_death() -> void:
	super.on_death()
	game.darkness.extra = 0.15
	game.darkness.tint_target = Color(0.01, 0.02, 0.07)
