class_name Weapon
extends Node2D
## One automatic weapon owned by the player. Behaviour is chosen by id; once
## evolved (evo != "") it switches to its evolved behaviour.

var id := "bubble"
var evo := ""
var level := 1
var player
var game
var _cd := 0.6
var _t := 0.0
var _orbiters: Array = []      # pilot / frenzy fish sprites
var _orbit_state: Array = []   # per fish dictionaries for frenzy
var _follower: AreaEffect      # maelstrom
var _trail_t := 0.0


func level_up() -> void:
	level = mini(level + 1, DB.MAX_LEVEL)
	_rebuild_orbiters()


func evolve(evo_id: String) -> void:
	evo = evo_id
	level = DB.MAX_LEVEL
	_rebuild_orbiters()
	if evo == "maelstrom" and _follower == null:
		_follower = AreaEffect.new().setup_whirl(player.position, 70.0, 0.0, 12.0, 90.0)
		_follower.follow = player
		_follower.follow_lag = 2.0
		_follower.pull_pickups = true
		_follower.source = "maelstrom"
		game.spawn_area(_follower)


func display_name() -> String:
	return DB.EVOLUTIONS[evo].name if evo != "" else DB.WEAPONS[id].name


func icon_name() -> String:
	return DB.EVOLUTIONS[evo].icon if evo != "" else DB.WEAPONS[id].icon


func _ready() -> void:
	_rebuild_orbiters()


func v(key: String, fallback = 0.0):
	return DB.weapon_value(id, key, level, fallback)


func _physics_process(delta: float) -> void:
	if not player.alive:
		return
	_t += delta
	if id == "pilot":
		_update_orbiters(delta)
	if evo == "black_tide":
		_trail_t -= delta
		if _trail_t <= 0.0:
			_trail_t = 0.45
			var a := AreaEffect.new().setup_cloud("fx/ink_cloud", player.position, 30.0 * player.st.area_mult, 3.0 * player.st.duration_mult, 9.0, 0.45, true)
			a.source = "ink"
			game.spawn_area(a)
	var base_cd: float = v("cooldown", 1.0)
	if evo == "storm":
		base_cd = 0.55
	elif evo == "torpedo":
		base_cd = 1.0
	elif evo == "coral_crown":
		base_cd = 1.4
	if base_cd <= 0.0:
		return
	_cd -= delta
	if _cd <= 0.0:
		_cd = base_cd * player.st.cooldown_mult
		_fire()


func _fire() -> void:
	match evo if evo != "" else id:
		"bubble": _fire_bubble()
		"torpedo": _fire_torpedo()
		"ink": _fire_ink()
		"black_tide": _fire_ink()
		"pulse": _fire_pulse(int(v("amount", 2)), v("damage", 12.0), v("range", 110.0))
		"storm": _fire_storm()
		"spines": _fire_spines(int(v("amount", 6)) + player.st.amount, v("damage", 7.0), int(v("pierce", 1)), "fx/spine", 0.0)
		"coral_crown": _fire_crown()
		"sonar": _fire_sonar(110.0 * float(v("area", 1.0)), v("damage", 11.0), false)
		"abyss_call": _fire_sonar(210.0, 26.0, true)
		"whirl": _fire_whirl()
		"maelstrom": _fire_whirl()


# ------------------------------------------------------------------ bubble
func _fire_bubble() -> void:
	var n: int = int(v("amount", 1)) + player.st.amount
	var targets: Array = game.nearest_n(player.position, n, 230.0)
	for i in n:
		var dir: Vector2
		if i < targets.size():
			dir = (targets[i].position - player.position).normalized()
		else:
			dir = Vector2(player.facing, 0).rotated(randf_range(-0.4, 0.4))
		var p := Projectile.new().setup("fx/bubble", dir * 210.0 * player.st.proj_speed_mult, v("damage", 9.0), 1.4, 4.5 * player.st.area_mult)
		p.pierce = int(v("pierce", 1))
		p.position = player.position + dir * player.radius
		p.rotate_to_vel = false
		p.source = "bubble"
		p.scale = Vector2.ONE * player.st.area_mult
		game.spawn_projectile(p)
	Sfx.play("bubble", -6.0)


func _fire_torpedo() -> void:
	for i in 3 + player.st.amount:
		var dir := Vector2(player.facing, 0).rotated((i - 1) * 0.5)
		var p := Projectile.new().setup("fx/torpedo", dir * 170.0 * player.st.proj_speed_mult, 24.0, 2.2, 6.0)
		p.homing = 5.0
		p.explode_radius = 34.0 * player.st.area_mult
		p.position = player.position
		p.source = "torpedo"
		p.fps = 12.0
		game.spawn_projectile(p)
	Sfx.play("bubble", -2.0)


# --------------------------------------------------------------------- ink
func _fire_ink() -> void:
	var n: int = int(v("amount", 1)) + player.st.amount
	var targets: Array = game.nearest_n(player.position, n, 190.0)
	for i in n:
		var dest: Vector2
		if i < targets.size():
			dest = targets[i].position
		else:
			dest = player.position + Vector2.from_angle(randf() * TAU) * randf_range(40, 90)
		var dir: Vector2 = (dest - player.position).normalized()
		var p := Projectile.new().setup("fx/ink_ball", dir * 190.0, 0.0, 2.0, 4.0)
		p.position = player.position
		p.target_point = dest
		var radius_px: float = 26.0 * float(v("area", 1.0)) * player.st.area_mult
		var dur: float = float(v("duration", 3.0)) * player.st.duration_mult
		var dps: float = v("damage", 5.0)
		if evo == "black_tide":
			dps *= 1.8
			radius_px *= 1.3
		p.on_arrive = func(pos: Vector2):
			var a := AreaEffect.new().setup_cloud("fx/ink_cloud", pos, radius_px, dur, dps, 0.4, true)
			a.source = "ink"
			game.spawn_area(a)
			Sfx.play("ink", -8.0)
		game.spawn_projectile(p)


# ------------------------------------------------------------------- pulse
func _fire_pulse(jumps: int, dmg: float, rng: float) -> void:
	var first: Creature = game.nearest_creature(player.position, rng)
	if first == null:
		return
	jumps += int(player.st.chain_bonus)
	var mult: float = player.flags.get("volt_dmg", 1.0)
	var from: Vector2 = player.position
	var cur: Creature = first
	var done := {}
	for i in jumps:
		if cur == null:
			break
		done[cur.get_instance_id()] = true
		game.zap(from, cur.position)
		var r: Array = game.roll_damage(dmg * mult)
		cur.take_damage(r[0], player.shock_info(r[1]))
		from = cur.position
		var nxt: Creature = null
		var bd := 85.0 * 85.0
		for o in game.creatures_in_radius(from, 85.0):
			if done.has(o.get_instance_id()) or o.dead:
				continue
			var d: float = o.position.distance_squared_to(from)
			if d < bd:
				bd = d
				nxt = o
		cur = nxt
	Sfx.play("zap", -5.0)


func _fire_storm() -> void:
	var rect: Rect2 = game.visible_rect()
	var pool: Array = game.creatures_in_radius(rect.get_center(), rect.size.length() * 0.5, false)
	pool.shuffle()
	var mult: float = player.flags.get("volt_dmg", 1.0)
	for i in mini(3 + player.st.amount, pool.size()):
		var c: Creature = pool[i]
		if c.dead:
			continue
		var top := Vector2(c.position.x + randf_range(-20, 20), rect.position.y - 10)
		game.zap(top, c.position, Color("b8f4ff"))
		for o in game.creatures_in_radius(c.position, 22.0 * player.st.area_mult):
			var r: Array = game.roll_damage(20.0 * mult)
			var info: Dictionary = player.shock_info(r[1])
			info.hit_id = c.get_instance_id()
			info.stun = maxf(info.get("stun", 0.0), 0.3)
			o.take_damage(r[0], info)
		game.fx("fx/hit_spark", c.position, 20.0, 2.0, Color("fff060"))
	if pool.size() > 0:
		Sfx.play("zap", -4.0)
		game.shake(1.0)


# ------------------------------------------------------------------ spines
func _fire_spines(n: int, dmg: float, pierce: int, sheet: String, offset: float) -> void:
	var rot := _t * 0.7 + offset
	for i in n:
		var dir := Vector2.from_angle(rot + TAU * i / n)
		var p := Projectile.new().setup(sheet, dir * 200.0 * player.st.proj_speed_mult, dmg, 0.9 * player.st.duration_mult, 4.0 * player.st.area_mult)
		p.pierce = pierce
		p.position = player.position + dir * player.radius
		p.source = "spines"
		p.knockback = 40.0
		game.spawn_projectile(p)
	Sfx.play("spine", -6.0)


func _fire_crown() -> void:
	_fire_spines(16, 15.0, 4, "fx/spine_coral", 0.0)
	await get_tree().create_timer(0.18, false).timeout
	if is_instance_valid(player) and player.alive:
		_fire_spines(16, 15.0, 4, "fx/spine_coral", PI / 16.0)


# ------------------------------------------------------------------- pilot
func _rebuild_orbiters() -> void:
	if id != "pilot" or game == null:
		return
	for o in _orbiters:
		if is_instance_valid(o):
			o.queue_free()
	_orbiters.clear()
	_orbit_state.clear()
	var n: int = 8 if evo == "frenzy" else int(v("amount", 2)) + player.st.amount
	for i in n:
		var s := Art.sprite("creatures/piranha" if evo == "frenzy" else "creatures/pilot")
		if evo == "frenzy":
			s.scale = Vector2(0.75, 0.75)
		game.layer_fx.add_child(s)
		s.global_position = player.global_position
		_orbiters.append(s)
		_orbit_state.append({"mode": "orbit", "target": null, "t": randf() * 0.8})


func _update_orbiters(delta: float) -> void:
	var n := _orbiters.size()
	if n == 0:
		return
	var r: float = 34.0 * float(v("area", 1.0)) * player.st.area_mult + player.radius
	var spd: float = float(v("speed", 2.6))
	var dmg: float = v("damage", 7.0)
	for i in n:
		var s: Sprite2D = _orbiters[i]
		if not is_instance_valid(s):
			continue
		var ang := _t * spd + TAU * i / n
		var home: Vector2 = player.position + Vector2(cos(ang), sin(ang) * 0.8) * r
		var st: Dictionary = _orbit_state[i]
		var pos := s.global_position
		if evo == "frenzy":
			st.t -= delta
			if st.mode == "orbit":
				pos = pos.lerp(home, 1.0 - pow(0.001, delta))
				if st.t <= 0.0:
					var tg: Creature = game.nearest_creature(pos, 170.0)
					if tg:
						st.mode = "hunt"
						st.target = tg
						st.t = 1.2
					else:
						st.t = 0.4
			else:
				var tgt = st.target
				if st.t <= 0.0 or tgt == null or not is_instance_valid(tgt) or tgt.dead:
					st.mode = "orbit"
					st.t = randf_range(0.3, 0.8)
				else:
					pos = pos.move_toward(tgt.position, 320.0 * delta)
					if pos.distance_to(tgt.position) < tgt.radius + 4.0:
						var rr: Array = game.roll_damage(16.0)
						tgt.take_damage(rr[0], {"crit": rr[1], "source": "frenzy", "bleed": 3.0})
						st.mode = "orbit"
						st.t = randf_range(0.5, 0.9)
			dmg = 10.0
		else:
			pos = home
		var dirv := pos - s.global_position
		if absf(dirv.x) > 0.2:
			s.flip_h = dirv.x < 0.0
		s.global_position = pos
		s.frame = int(_t * 10.0 + i) % 4
		for c in game.creatures_in_radius(pos, 5.0):
			if c.can_hit("pilot%d" % i, 0.45):
				var r2: Array = game.roll_damage(dmg)
				c.take_damage(r2[0], {"crit": r2[1], "source": "pilot", "hit_id": i, "knockback": dirv.normalized() * 60.0})


# ------------------------------------------------------------------- sonar
func _fire_sonar(radius_px: float, dmg: float, evolved: bool) -> void:
	radius_px *= player.st.area_mult
	var ring := RingFx.new().setup(radius_px, 0.5, Color("9474e2") if evolved else Color("5ee0ff"))
	ring.follow = player
	game.layer_fx.add_child(ring)
	ring.global_position = player.global_position
	Sfx.play("sonar", -6.0)
	var hit := {}
	var elapsed := 0.0
	while elapsed < 0.5:
		await get_tree().physics_frame
		if not is_instance_valid(ring) or not is_instance_valid(player):
			return
		elapsed += get_physics_process_delta_time()
		var cur: float = ring.radius
		for c in game.creatures_in_radius(player.position, cur):
			var k: int = c.get_instance_id()
			if hit.has(k) or c.dead:
				continue
			hit[k] = true
			var r: Array = game.roll_damage(dmg)
			var info := {"crit": r[1], "source": "sonar", "knockback": (c.position - player.position).normalized() * 140.0}
			if evolved:
				info.mark = 4.0
			c.take_damage(r[0], info)
	if evolved:
		for pk in game.pickups:
			if is_instance_valid(pk) and pk.kind == "xp" and pk.position.distance_to(player.position) < radius_px * 1.6:
				pk.attracted = true


# ------------------------------------------------------------------- whirl
func _fire_whirl() -> void:
	var n: int = int(v("amount", 1)) + player.st.amount
	var targets: Array = game.nearest_n(player.position, 8, 200.0)
	targets.shuffle()
	for i in n:
		var pos: Vector2 = targets[i].position if i < targets.size() else player.position + Vector2.from_angle(randf() * TAU) * 70.0
		var a := AreaEffect.new().setup_whirl(pos, 34.0 * float(v("area", 1.0)) * player.st.area_mult, float(v("duration", 3.0)) * player.st.duration_mult, v("damage", 5.0), 60.0)
		a.source = "whirl"
		game.spawn_area(a)
	Sfx.play("whirl", -6.0)


func _exit_tree() -> void:
	for o in _orbiters:
		if is_instance_valid(o):
			o.queue_free()
