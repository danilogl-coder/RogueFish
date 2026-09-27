extends Boss
## Megalodonte, o Ancestral (expansion boss): a colossal ancient shark.
##  * stalk  : circles far away, fading into the dark (only the eye glows)
##  * ambush : bursts from off-screen along a telegraphed line
##  * frenzy : three quick lunges in a row
##  * slam   : tail shockwave that knocks the player away
##  Enraged: faster ambushes, two in a row, and it calls barracudas.

var _dir := Vector2.RIGHT
var _lunges := 0
var _next := 0
var _summon_t := 8.0
var _fade := 1.0
var _head: BossPart
var _tail: BossPart
const SCALE := 1.7            ## drawn bigger than any other shark


func _setup() -> void:
	sprite = Art.sprite("creatures/megalodon")
	sprite.scale = Vector2(SCALE, SCALE)
	add_child(sprite)
	radius = 52.0
	speed = 150.0
	anim_fps = 5.0
	state = "enter"
	_head = add_part(40.0, contact_damage)
	_tail = add_part(30.0, contact_damage * 0.5)


func think(delta: float) -> void:
	var p: Player = game.player
	if lost_player():
		search(delta)
		_place_parts()
		return
	_summon_t -= delta
	var spd := speed * (1.25 if enraged else 1.0)
	match state:
		"enter":
			seek(p.position, spd, 260.0, delta)
			if player_dist() < 300.0 or state_t > 3.0:
				_go("stalk")
		"stalk":
			# circle wide in the dark
			var a := state_t * 0.7 + (PI if int(state_t) % 2 == 0 else 0.0) * 0.0
			var want := p.position + Vector2.from_angle(a) * Vector2(360, 200)
			seek(want, spd * 1.1, 260.0, delta)
			_fade = move_toward(_fade, 0.25, delta * 0.8)
			if enraged and _summon_t <= 0.0:
				_summon_t = 9.0
				summon("barracuda", 2)
				game.hud.toast("O Megalodonte chama barracudas!", Color("ff5c4c"))
			if state_t > (2.4 if enraged else 3.2):
				_next = (_next + 1) % 3
				match _next:
					0:
						_start_ambush()
					1:
						_lunges = 3
						_start_lunge()
					_:
						_go("slam_wind")
						telegraph_circle(position, 150.0, 0.8)
		"ambush_aim":
			vel *= pow(0.02, delta)
			_fade = move_toward(_fade, 1.0, delta * 2.0)
			if state_t > 0.75:
				_go("ambush")
				attack_anim = 1.0
				Sfx.play("boss_roar", -6.0)
		"ambush":
			vel = _dir * (620.0 if enraged else 540.0)
			attack_anim = 0.3
			if state_t > 1.1:
				if enraged and _lunges == 0:
					_lunges = -1
					_start_ambush()
				else:
					_lunges = 0
					_go("recover")
		"lunge_aim":
			vel *= pow(0.05, delta)
			_fade = move_toward(_fade, 1.0, delta * 3.0)
			facing = signf(_dir.x) if absf(_dir.x) > 0.1 else facing
			if state_t > 0.4:
				_go("lunge")
				attack_anim = 0.8
				Sfx.play("bite")
		"lunge":
			vel = _dir * 420.0
			attack_anim = 0.3
			if state_t > 0.35:
				_lunges -= 1
				if _lunges > 0:
					_start_lunge()
				else:
					_go("recover")
		"slam_wind":
			vel *= pow(0.05, delta)
			_fade = move_toward(_fade, 1.0, delta * 3.0)
			if state_t > 0.8:
				_slam()
				_go("recover")
		"recover":
			vel *= pow(0.2, delta)
			if state_t > 1.0:
				_go("stalk")
	_place_parts()


func _start_ambush() -> void:
	var p: Player = game.player
	var rect: Rect2 = game.visible_rect()
	var side := -1.0 if randf() < 0.5 else 1.0
	position = Vector2(p.position.x + side * (rect.size.x * 0.5 + 60.0), clampf(p.position.y + randf_range(-60, 60), 80, DB.floor_at(p.position.x) - 60))
	_dir = (p.position - position).normalized()
	facing = signf(_dir.x)
	telegraph_line(position, _dir, 900.0, 60.0, 0.75)
	_go("ambush_aim")


func _start_lunge() -> void:
	_dir = (game.player.position - position).normalized()
	telegraph_line(position, _dir, 180.0, 40.0, 0.4)
	_go("lunge_aim")


func _slam() -> void:
	var ring := RingFx.new().setup(170.0, 0.5, Color("ff8a6a"), 4.0)
	game.layer_fx.add_child(ring)
	ring.global_position = global_position
	game.shake(7.0)
	Sfx.play("explosion", -2.0)
	var p: Player = game.player
	if p.alive and position.distance_to(p.position) < 170.0:
		p.take_damage(contact_damage * dmg_mult * 0.9, self)
		p.vel += (p.position - position).normalized() * 380.0


func hostile_now() -> bool:
	return state in ["ambush", "lunge", "enter"] and super.hostile_now()


func _place_parts() -> void:
	var biting := state in ["ambush", "lunge"]
	_head.contact_damage = contact_damage if biting else 0.0
	_tail.contact_damage = contact_damage * 0.4 if biting else 0.0
	_head.position = position + Vector2(facing * 58.0 * SCALE, 8.0 * SCALE)
	_tail.position = position + Vector2(-facing * 60.0 * SCALE, 0.0)


func _go(s: String) -> void:
	state = s
	state_t = 0.0


func _animate(delta: float) -> void:
	super._animate(delta)
	if state in ["ambush", "ambush_aim", "lunge", "lunge_aim"]:
		facing = -1.0 if _dir.x < 0.0 else 1.0
	sprite.flip_h = facing < 0.0
	sprite.modulate.a = _fade
	rotation = clampf(vel.y / 700.0, -0.25, 0.25) * facing
