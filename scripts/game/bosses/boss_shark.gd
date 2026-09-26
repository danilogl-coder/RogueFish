extends Boss
## Mandíbula: circles the player, telegraphs and charges; summons piranhas.
## Enraged: double charges, faster.

var _orbit_a := 0.0
var _charge_dir := Vector2.RIGHT
var _charges_left := 0
var _summon_t := 3.0
var _head: BossPart
var _tail: BossPart


func _setup() -> void:
	sprite = Art.sprite("creatures/boss_shark")
	add_child(sprite)
	radius = 22.0
	speed = 150.0
	anim_fps = 6.0
	state = "enter"
	_head = add_part(16.0, contact_damage)
	_tail = add_part(14.0, contact_damage * 0.6)


func think(delta: float) -> void:
	if lost_player():
		search(delta)
		_head.position = position + Vector2(facing * 42.0, 4.0)
		_tail.position = position + Vector2(-facing * 44.0, 0.0)
		return
	var p: Player = game.player
	var spd := speed * (1.25 if enraged else 1.0)
	_summon_t -= delta
	match state:
		"enter":
			seek(p.position, spd, 300.0, delta)
			if player_dist() < 220.0 or state_t > 3.0:
				_go("circle")
		"circle":
			_orbit_a += delta * (1.2 if enraged else 0.9)
			var want := p.position + Vector2.from_angle(_orbit_a) * Vector2(170, 110)
			seek(want, spd * 1.2, 400.0, delta)
			if _summon_t <= 0.0:
				_summon_t = 7.0 if not enraged else 5.0
				summon("piranha", 3 if not enraged else 4)
			if state_t > (2.6 if enraged else 3.4):
				_charges_left = 2 if enraged else 1
				_aim()
		"aim":
			vel *= pow(0.01, delta)
			facing = signf(_charge_dir.x)
			if state_t > 0.7:
				_go("charge")
				attack_anim = 1.0
				Sfx.play("dash")
		"charge":
			vel = _charge_dir * (520.0 if enraged else 460.0)
			attack_anim = 0.3
			if state_t > 0.85:
				_charges_left -= 1
				if _charges_left > 0:
					_aim()
				else:
					_go("recover")
		"recover":
			vel *= pow(0.1, delta)
			if state_t > 1.0:
				_go("circle")
	# parts follow body
	_head.position = position + Vector2(facing * 42.0, 4.0)
	_tail.position = position + Vector2(-facing * 44.0, 0.0)


func _aim() -> void:
	_charge_dir = (game.player.position - position).normalized()
	telegraph_line(position, _charge_dir, 420.0, 34.0, 0.7)
	_go("aim")


func _go(s: String) -> void:
	state = s
	state_t = 0.0


func _animate(delta: float) -> void:
	super._animate(delta)
	if state == "aim" or state == "charge":
		sprite.flip_h = _charge_dir.x < 0.0
		facing = -1.0 if sprite.flip_h else 1.0
	rotation = clampf(vel.y / 600.0, -0.3, 0.3) * facing
