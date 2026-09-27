extends Boss
## Leviatã Elétrico: a giant serpent. Its body is made of segments that hurt on
## contact; it sweeps across the arena, dives at the player, spits volt balls
## and periodically electrifies its whole body.

const SEG_N := 14
const SEG_GAP := 30.0
var _trail: Array = []
var _segs: Array = []
var _seg_tex: Texture2D
var _target := Vector2.ZERO
var _dive_dir := Vector2.RIGHT
var _elec_t := 6.0
var _elec_on := 0.0
var _zap_t := 0.0
var _spit_t := 3.0


func _setup() -> void:
	sprite = Art.sprite("creatures/leviathan_head")
	add_child(sprite)
	scale = Vector2(2, 2)
	radius = 30.0
	speed = 180.0
	anim_fps = 6.0
	_seg_tex = Art.tex("creatures/leviathan_segment")
	for i in SEG_N:
		_segs.append(add_part(21.0 if i < SEG_N - 1 else 16.0, contact_damage * 0.6))
	for i in SEG_N * 20:
		_trail.append(position)
	state = "sweep"
	_pick_target()
	z_index = 1


func _pick_target() -> void:
	var p: Player = game.player
	_target = p.position + Vector2(randf_range(-260, 260), randf_range(-140, 140))
	_target.x = clampf(_target.x, 60, DB.WORLD_W - 60)
	_target.y = clampf(_target.y, 80, DB.floor_at(_target.x) - 40)


func think(delta: float) -> void:
	var p: Player = game.player
	var spd := speed * (1.25 if enraged else 1.0)
	if lost_player():
		state = "sweep"
		if position.distance_to(_target) < 60.0 or state_t > 4.0:
			_target = Vector2(clampf(position.x + randf_range(-400, 400), 60, DB.WORLD_W - 60), randf_range(120, DB.floor_at(position.x) - 80))
			state_t = 0.0
	_elec_t -= delta
	_elec_on -= delta
	_spit_t -= delta
	match state:
		"sweep":
			var desired := (_target - position).normalized() * spd
			vel = vel.lerp(desired, 1.0 - pow(0.2, delta))
			if position.distance_to(_target) < 40.0:
				_pick_target()
			if state_t > (4.0 if not enraged else 3.0):
				_dive_dir = (p.position - position).normalized()
				telegraph_line(position, _dive_dir, 380.0, 30.0, 0.7)
				_go("aim")
		"aim":
			vel *= pow(0.05, delta)
			if state_t > 0.7:
				_go("dive")
				attack_anim = 0.8
				Sfx.play("dash")
		"dive":
			vel = _dive_dir * spd * 2.6
			if state_t > 0.75:
				_pick_target()
				_go("sweep")
	if _spit_t <= 0.0 and not lost_player():
		_spit_t = 3.2 if not enraged else 2.2
		for i in 3:
			var a := (p.position - position).angle() + (i - 1) * 0.25
			var pr := Projectile.new().setup("fx/volt_ball", Vector2.from_angle(a) * 150.0, 12.0 * dmg_mult, 3.0, 5.0)
			pr.hostile = true
			pr.rotate_to_vel = false
			pr.position = position
			game.spawn_projectile(pr)
		Sfx.play("zap", -2.0)
	if _elec_t <= 0.0:
		_elec_t = 9.0 if not enraged else 6.5
		_elec_on = 2.6 if not enraged else 3.4
		Sfx.play("warning", -2.0)
	if _elec_on > 0.0:
		_zap_t -= delta
		if _zap_t <= 0.0:
			_zap_t = 0.5
			for bp in _segs:
				if bp.position.distance_to(p.position) < 110.0:
					game.zap(bp.position, p.position, Color("b8f4ff"))
					p.take_damage(9.0 * dmg_mult, null)
					break
	for bp in _segs:
		bp.contact_damage = contact_damage * (1.2 if _elec_on > 0.0 else 0.6)
	# body follows trail
	_trail.push_front(position)
	if _trail.size() > SEG_N * 20:
		_trail.pop_back()
	var acc := 0.0
	var idx := 0
	var prev: Vector2 = _trail[0]
	for k in range(1, _trail.size()):
		acc += prev.distance_to(_trail[k])
		prev = _trail[k]
		if acc >= SEG_GAP * (idx + 1):
			if idx < SEG_N:
				_segs[idx].position = _trail[k]
			idx += 1
			if idx >= SEG_N:
				break
	queue_redraw()


func _go(s: String) -> void:
	state = s
	state_t = 0.0


func _animate(delta: float) -> void:
	anim_t += delta
	if absf(vel.x) > 4.0:
		facing = signf(vel.x)
	sprite.flip_h = false
	sprite.rotation = vel.angle()
	sprite.flip_v = vel.x < 0.0
	_sync_anim()
	if attack_anim > 0.0:
		attack_anim = maxf(0.0, attack_anim - delta)
		sprite.frame = _swim_n + Art.act_frame(attack_progress(), _act_n) if _act_n > 0 else 0
	else:
		sprite.frame = int(anim_t * anim_fps * _swim_n / 4.0) % _swim_n


func _draw() -> void:
	var glow := _elec_on > 0.0 and int(anim_t * 12.0) % 2 == 0
	for i in range(_segs.size() - 1, -1, -1):
		var bp: BossPart = _segs[i]
		var lp := to_local(bp.position)
		var fr := 2 if i == _segs.size() - 1 else (1 if glow else 0)
		var nxt: Vector2 = to_local(_segs[i - 1].position) if i > 0 else Vector2.ZERO
		var ang := (nxt - lp).angle()
		var sc := lerpf(1.0, 0.7, float(i) / SEG_N)
		draw_set_transform(lp, ang, Vector2(sc, sc))
		draw_texture_rect_region(_seg_tex, Rect2(-15, -15, 30, 30), Rect2(fr * 30, 0, 30, 30), Color(1.5, 1.5, 1.2) if glow else Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
