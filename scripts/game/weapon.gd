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
# ---- archetype weapons (see scripts/data/arsenal.gd)
var kind := ""                 # archetype of data-driven weapons ("" = core weapon)
var _orb: Array = []           # generic orbiters: [{s: Sprite2D, st: {...}}]
var _aura_t := 0.0
var _drops := 0
var _spiral := 0.0
var _shoot_t := 0.0


func level_up() -> void:
	level = mini(level + 1, DB.weapon_max(id))
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
	return tr(DB.EVOLUTIONS[evo].name) if evo != "" else tr(DB.WEAPONS[id].name)


func is_fusion() -> bool:
	return DB.WEAPONS[id].get("fusion", false)


func icon_name() -> String:
	return DB.EVOLUTIONS[evo].icon if evo != "" else DB.WEAPONS[id].icon


func _ready() -> void:
	kind = str(DB.WEAPONS[id].get("kind", ""))
	_rebuild_orbiters()
	if kind != "":
		queue_redraw()


func v(key: String, fallback = 0.0):
	return DB.weapon_value(id, key, level, fallback)


func _physics_process(delta: float) -> void:
	if not player.alive:
		return
	_t += delta
	if id == "pilot":
		_update_orbiters(delta)
	if kind != "":
		_kind_tick(delta)
	if evo == "black_tide":
		_trail_t -= delta
		if _trail_t <= 0.0:
			_trail_t = 0.45
			var a: AreaEffect = AreaEffect.new().setup_cloud("fx/ink_cloud", player.position, 30.0 * player.st.area_mult, 3.0 * player.st.duration_mult, 9.0, 0.45, true)
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
	if kind != "" and evo == "":
		_fire_kind()
		return
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
		var p: Projectile = Projectile.new().setup("fx/bubble", dir * 210.0 * player.st.proj_speed_mult, v("damage", 9.0), 1.4, 4.5 * player.st.area_mult)
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
		var p: Projectile = Projectile.new().setup("fx/torpedo", dir * 170.0 * player.st.proj_speed_mult, 24.0, 2.2, 6.0)
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
		var p: Projectile = Projectile.new().setup("fx/ink_ball", dir * 190.0, 0.0, 2.0, 4.0)
		p.position = player.position
		p.target_point = dest
		var radius_px: float = 26.0 * float(v("area", 1.0)) * player.st.area_mult
		var dur: float = float(v("duration", 3.0)) * player.st.duration_mult
		var dps: float = v("damage", 5.0)
		if evo == "black_tide":
			dps *= 1.8
			radius_px *= 1.3
		p.on_arrive = func(pos: Vector2):
			var a: AreaEffect = AreaEffect.new().setup_cloud("fx/ink_cloud", pos, radius_px, dur, dps, 0.4, true)
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
		var p: Projectile = Projectile.new().setup(sheet, dir * 200.0 * player.st.proj_speed_mult, dmg, 0.9 * player.st.duration_mult, 4.0 * player.st.area_mult)
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
	if kind == "orbit":
		_rebuild_orb()
		return
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
		var ang: float = _t * spd + TAU * i / n
		var home: Vector2 = player.position + Vector2(cos(ang), sin(ang) * 0.8) * r
		var st: Dictionary = _orbit_state[i]
		var pos: Vector2 = s.global_position
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
		var dirv: Vector2 = pos - s.global_position
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
	var ring: RingFx = RingFx.new().setup(radius_px, 0.5, Color("9474e2") if evolved else Color("5ee0ff"))
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
		var a: AreaEffect = AreaEffect.new().setup_whirl(pos, 34.0 * float(v("area", 1.0)) * player.st.area_mult, float(v("duration", 3.0)) * player.st.duration_mult, v("damage", 5.0), 60.0)
		a.source = "whirl"
		game.spawn_area(a)
	Sfx.play("whirl", -6.0)


func _exit_tree() -> void:
	for o in _orb:
		if is_instance_valid(o.s):
			o.s.queue_free()
	for o in _orbiters:
		if is_instance_valid(o):
			o.queue_free()



# =================================================== archetype weapons
## Shared helpers --------------------------------------------------------
func _w(key: String, fallback = 0.0):
	return v(key, DB.WEAPONS[id].get(key, fallback))


func _amount() -> int:
	return int(_w("amount", 1)) + int(player.st.amount)


func _area() -> float:
	return float(_w("area", 1.0)) * player.st.area_mult


func _hit_info(extra := {}) -> Dictionary:
	var info: Dictionary = {"source": id}
	for k in ["stun", "slow", "bleed"]:
		var val: float = float(_w(k, 0.0))
		if val > 0.0:
			info[k] = val
	var poison: float = float(_w("poison", 0.0))
	if poison > 0.0:
		info.poison = poison * player.st.poison_mult
	if _w("mark", 0.0) > 0.0:
		info.mark = float(_w("mark", 0.0))
	info.merge(extra, true)
	return info


func _damage(c: Creature, dmg: float, extra := {}) -> void:
	var r: Array = game.roll_damage(dmg)
	var info: Dictionary = _hit_info(extra)
	info.crit = r[1]
	c.take_damage(r[0], info)
	if int(_w("chain", 0)) > 0 and not c.dead:
		player._chain_from(c, int(_w("chain", 0)), r[0] * 0.5)


func _color() -> Color:
	return Color(str(DB.WEAPONS[id].get("color", "ffffff")))


func _sfx(fallback: String, vol := -8.0) -> void:
	Sfx.play(str(DB.WEAPONS[id].get("sfx", fallback)), vol)


## Continuous archetypes --------------------------------------------------
func _kind_tick(delta: float) -> void:
	match kind:
		"orbit":
			_tick_orb(delta)
		"aura":
			_aura_t -= delta
			if _aura_t <= 0.0:
				_aura_t = float(_w("tick", 0.5))
				_aura_pulse()
			queue_redraw()
		"sweep":
			_tick_sweep()
			queue_redraw()


func _fire_kind() -> void:
	match kind:
		"shot": _k_shot()
		"nova": _k_nova()
		"lash": _k_lash()
		"beam": _k_beam()
		"mine": _k_mine()
		"boomerang": _k_boomerang()
		"bounce": _k_bounce()
		"strike": _k_strike()
		"slam": _k_slam()
		"summon": _k_summon()
		"trail": _k_trail()
		"lob": _k_lob()
		"tentacle": _k_tentacle(float(_w("radius", 70.0)) * _area(), _amount())
		"vortex": _k_vortex()


func _proj(sheet: String, dir: Vector2, dmg: float) -> Projectile:
	var spd: float = float(_w("speed", 220.0)) * player.st.proj_speed_mult
	var p: Projectile = Projectile.new().setup(sheet, dir * spd, dmg, float(_w("life", 1.4)), float(_w("size", 4.0)) * sqrt(_area()))
	p.position = player.position + dir * player.radius
	p.source = id
	p.pierce = int(_w("pierce", 1))
	p.stun = float(_w("stun", 0.0))
	p.slow = float(_w("slow", 0.0))
	p.bleed = float(_w("bleed", 0.0))
	p.knockback = float(_w("knock", 60.0))
	p.chain = int(_w("chain", 0))
	var ex: float = float(_w("explode", 0.0))
	if ex > 0.0:
		p.explode_radius = ex * _area()
		p.explode_sheet = "fx/cavitation_pop" if id.begins_with("cavitation") else "fx/explosion"
	var sp: float = float(DB.WEAPONS[id].get("spin", 0.0))
	if sp != 0.0:
		p.rotate_to_vel = false
		p.spin = sp
	return p


## shot: aimed projectiles (nearest / random target) -----------------------
func _k_shot() -> void:
	var n: int = _amount()
	var how: String = str(DB.WEAPONS[id].get("target", "nearest"))
	var targets: Array = game.nearest_n(player.position, n if how == "nearest" else 10, 260.0)
	if how == "random":
		targets.shuffle()
	for i in n:
		var dir: Vector2
		if not targets.is_empty():
			var t: Creature = targets[i % targets.size()]
			dir = (t.position - player.position).normalized().rotated(0.0 if i < targets.size() else randf_range(-0.3, 0.3))
		else:
			dir = Vector2(player.facing, 0).rotated(randf_range(-0.5, 0.5))
		game.spawn_projectile(_proj(str(DB.WEAPONS[id].sheet), dir, float(_w("damage", 8.0))))
	_sfx("bubble")


## nova: ring of projectiles (spiral variant rotates each volley) ----------
func _k_nova() -> void:
	var n: int = _amount()
	var spiral: bool = DB.WEAPONS[id].get("spiral", false)
	for ring in (2 if spiral else 1):
		var off: float = _spiral + ring * PI / n
		for i in n:
			var dir: Vector2 = Vector2.from_angle(off + TAU * i / n)
			game.spawn_projectile(_proj(str(DB.WEAPONS[id].sheet), dir, float(_w("damage", 5.0))))
	_spiral += 0.35 if spiral else PI / n
	Sfx.play("spine", -8.0)


## lash: melee arc in front (and behind with amount 2) ---------------------
func _k_lash() -> void:
	var reach: float = float(_w("reach", 32.0)) * _area() + player.radius
	var arc: float = float(_w("arc", 1.4))
	var dirs: Array = [Vector2(player.facing, 0)]
	if _amount() >= 2:
		dirs.append(Vector2(-player.facing, 0))
	var tgt: Creature = game.nearest_creature(player.position, reach * 1.6)
	if tgt and absf((tgt.position - player.position).angle_to(dirs[0])) < 1.2:
		dirs[0] = (tgt.position - player.position).normalized()
	for d in dirs:
		var fx: OneShotFx = OneShotFx.new()
		fx.setup(str(DB.WEAPONS[id].sheet), 22.0)
		fx.position = player.position + d * reach * 0.55
		fx.rotation = d.angle()
		fx.scale = Vector2.ONE * (reach / 34.0)
		if DB.WEAPONS[id].has("tint"):
			fx.modulate = Color(str(DB.WEAPONS[id].tint))
		game.layer_fx.add_child(fx)
		for c in game.creatures_in_radius(player.position, reach):
			if c.dead:
				continue
			var to: Vector2 = c.position - player.position
			if to.length() < 6.0 or absf(to.angle_to(d)) <= arc * 0.5:
				_damage(c, float(_w("damage", 14.0)), {"knockback": to.normalized() * float(_w("knock", 150.0))})
	_sfx("dash", -6.0)


## beam: instant piercing line toward the nearest enemy -------------------
func _k_beam() -> void:
	var length: float = float(_w("length", 150.0)) * _area()
	var width: float = float(_w("width", 6.0))
	var n: int = _amount()
	var tgt: Creature = game.nearest_creature(player.position, length)
	var base: Vector2 = (tgt.position - player.position).normalized() if tgt else Vector2(player.facing, 0)
	for i in n:
		var dir: Vector2 = base.rotated((i - (n - 1) * 0.5) * 0.35)
		var from: Vector2 = player.position
		var to: Vector2 = from + dir * length
		var fx: BeamFx = BeamFx.new().setup(from, to, width, _color(), 0.28, true)
		game.layer_fx.add_child(fx)
		for c in game.creatures_in_radius(from + dir * length * 0.5, length * 0.5 + 10.0):
			if c.dead:
				continue
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(c.position, from, to)
			if q.distance_to(c.position) <= c.radius + width:
				_damage(c, float(_w("damage", 16.0)), player.shock_info(false) if kind == "beam" else {})
	_sfx("zap", -6.0)


## mine: traps that burst when an enemy touches them ----------------------
func _k_mine() -> void:
	for i in _amount():
		var t: Trap = Trap.new()
		t.game = game
		t.sheet = str(DB.WEAPONS[id].sheet)
		t.damage = float(_w("damage", 18.0))
		t.radius = float(_w("radius", 26.0)) * _area()
		t.slow = float(_w("slow", 0.6))
		t.life = float(_w("life", 9.0)) * player.st.duration_mult
		t.source = id
		t.position = player.position + Vector2.from_angle(randf() * TAU) * randf_range(10.0, 40.0)
		game.layer_fx.add_child(t)
	Sfx.play("ink", -10.0)


## boomerang: flies out, comes back, pierces everything --------------------
func _k_boomerang() -> void:
	var n: int = _amount()
	var tgt: Creature = game.nearest_creature(player.position, 200.0)
	var base: Vector2 = (tgt.position - player.position).normalized() if tgt else Vector2(player.facing, 0)
	for i in n:
		var dir: Vector2 = base.rotated((i - (n - 1) * 0.5) * 0.6)
		var p: Projectile = _proj(str(DB.WEAPONS[id].sheet), dir, float(_w("damage", 12.0)))
		p.boomerang = float(_w("range", 120.0)) * _area()
		p.owner_node = player
		p.pierce = 9999
		p.life = 4.0
		if not DB.WEAPONS[id].has("spin"):
			p.rotate_to_vel = false
			p.spin = 12.0
		game.spawn_projectile(p)
	_sfx("dash", -8.0)


## bounce: ricochets between enemies ---------------------------------------
func _k_bounce() -> void:
	var n: int = _amount()
	var targets: Array = game.nearest_n(player.position, n, 220.0)
	for i in n:
		var dir: Vector2 = (targets[i].position - player.position).normalized() if i < targets.size() else Vector2.from_angle(randf() * TAU)
		var p: Projectile = _proj(str(DB.WEAPONS[id].sheet), dir, float(_w("damage", 8.0)))
		p.bounces = int(_w("bounces", 2))
		p.pierce = p.bounces + 1
		p.life = 2.5
		p.pearls = DB.WEAPONS[id].get("pearls", false)
		game.spawn_projectile(p)
	_sfx("bubble", -6.0)


## strike: something springs out at enemies around you ---------------------
func _k_strike() -> void:
	var r: float = float(_w("radius", 170.0))
	var pool: Array = game.nearest_n(player.position, 12, r)
	pool.shuffle()
	var vis: String = str(DB.WEAPONS[id].get("visual", "coin"))
	var n: int = _amount()
	for i in n:
		var tgt: Creature = pool[i] if i < pool.size() else null
		var pos: Vector2 = tgt.position if tgt else player.position + Vector2.from_angle(randf() * TAU) * randf_range(40.0, r)
		var sfx: StrikeFx = StrikeFx.new()
		sfx.game = game
		sfx.visual = "jaws" if (id == "deadly_ambush" and i % 2 == 1) else vis
		sfx.target = tgt
		sfx.position = pos
		sfx.on_hit = _strike_hit.bind(float(_w("explode", 0.0)))
		game.layer_fx.add_child(sfx)


func _strike_hit(pos: Vector2, tgt, ex: float) -> void:
	var dmg: float = float(_w("damage", 20.0))
	if ex > 0.0:
		game.fx("fx/explosion", pos, 20.0, ex / 16.0, Color("ffd76a"))
		for c in game.creatures_in_radius(pos, ex):
			if not c.dead:
				_damage(c, dmg)
				if id == "gold_rain" and level >= 5 and c.dead and randf() < 0.12:
					game.spawn_pickup("pearl", c.position, 1)
	elif tgt != null and is_instance_valid(tgt) and not tgt.dead:
		_damage(tgt, dmg)


## slam: shockwave around you ---------------------------------------------
func _k_slam() -> void:
	var r: float = float(_w("radius", 70.0)) * _area()
	var ring: RingFx = RingFx.new().setup(r, 0.45, Color("bfefff"))
	ring.follow = player
	game.layer_fx.add_child(ring)
	ring.global_position = player.global_position
	game.fx(str(DB.WEAPONS[id].get("sheet", "fx/splash_ring")), player.position, 14.0, r / 32.0, Color(1, 1, 1, 0.9))
	game.shake(4.0)
	Sfx.play("explosion", -4.0)
	for c in game.creatures_in_radius(player.position, r):
		if c.dead:
			continue
		var to: Vector2 = c.position - player.position
		_damage(c, float(_w("damage", 26.0)), {"knockback": to.normalized() * float(_w("knock", 300.0))})
	if DB.WEAPONS[id].get("pull_xp", false):
		for pk in game.pickups:
			if is_instance_valid(pk) and pk.kind == "xp" and pk.position.distance_to(player.position) < r * 1.8:
				pk.attracted = true


## summon: minions hunt and gnaw enemies ----------------------------------
func _k_summon() -> void:
	for i in _amount():
		var m: Minion = Minion.new()
		m.game = game
		m.sheet = str(DB.WEAPONS[id].sheet)
		m.damage = float(_w("damage", 5.0))
		m.speed = float(_w("speed", 160.0))
		m.life = float(_w("duration", 6.0)) * player.st.duration_mult
		m.latch = DB.WEAPONS[id].get("latch", false)
		m.source = id
		m.position = player.position + Vector2.from_angle(randf() * TAU) * 8.0
		m.vel = Vector2.from_angle(randf() * TAU) * 120.0
		game.layer_fx.add_child(m)
	Sfx.play("bubble", -10.0)


## trail: sticky puddles left behind (slime marsh also drops mines) --------
func _k_trail() -> void:
	var rad: float = float(_w("radius", 16.0)) * _area()
	var a: AreaEffect = AreaEffect.new().setup_cloud(str(DB.WEAPONS[id].sheet), player.position, rad, float(_w("duration", 3.0)) * player.st.duration_mult, float(_w("damage", 3.0)), float(_w("slow", 0.5)), true)
	a.source = id
	game.spawn_area(a)
	_drops += 1
	var every: int = int(DB.WEAPONS[id].get("mine_every", 0))
	if every > 0 and _drops % every == 0:
		var t: Trap = Trap.new()
		t.game = game
		t.sheet = "fx/guts"
		t.damage = float(_w("damage", 8.0)) * 2.5
		t.radius = 30.0 * _area()
		t.slow = 0.7
		t.life = 8.0
		t.source = id
		t.position = player.position
		game.layer_fx.add_child(t)


## lob: heavy arcing throw that stuns where it lands -----------------------
func _k_lob() -> void:
	var n: int = _amount()
	var targets: Array = game.nearest_n(player.position, n, 200.0)
	for i in n:
		var dest: Vector2 = targets[i].position if i < targets.size() else player.position + Vector2(player.facing * randf_range(60, 120), randf_range(-30, 30))
		var p: Projectile = Projectile.new().setup(str(DB.WEAPONS[id].sheet), (dest - player.position).normalized() * float(_w("speed", 190.0)), 0.0, 3.0, 4.0)
		p.position = player.position
		p.target_point = dest
		p.arc_height = clampf(player.position.distance_to(dest) * 0.35, 14.0, 50.0)
		p.rotate_to_vel = false
		p.spin = 10.0
		var dmg: float = float(_w("damage", 18.0))
		var ex: float = float(_w("explode", 20.0)) * _area()
		p.on_arrive = func(pos: Vector2):
			game.fx("fx/explosion", pos, 18.0, ex / 16.0, Color("d8c8a8"))
			game.shake(1.5)
			Sfx.play("crunch", -4.0)
			for c in game.creatures_in_radius(pos, ex):
				if not c.dead:
					_damage(c, dmg, {"knockback": (c.position - pos).normalized() * 120.0})
		game.spawn_projectile(p)


## tentacle: stinging lines to the nearest enemies -------------------------
func _k_tentacle(r: float, n: int) -> void:
	var targets: Array = game.nearest_n(player.position, n, r)
	var leech: float = float(_w("leech", 0.0))
	for t in targets:
		var fx: TentacleFx = TentacleFx.new().setup(player, t, _color())
		game.layer_fx.add_child(fx)
		_damage(t, float(_w("damage", 6.0)))
		if leech > 0.0:
			player.heal(leech, false)
	if not targets.is_empty():
		Sfx.play("zap", -12.0)


## vortex: poison whirlpools on enemies -----------------------------------
func _k_vortex() -> void:
	var targets: Array = game.nearest_n(player.position, 8, 220.0)
	targets.shuffle()
	var at_player: bool = DB.WEAPONS[id].get("at_player", false)
	for i in _amount():
		var pos: Vector2 = targets[i].position if i < targets.size() else player.position + Vector2.from_angle(randf() * TAU) * 70.0
		if at_player:
			pos = player.position + Vector2(player.facing * 44.0, 0).rotated(i * 0.8)
		var a: AreaEffect = AreaEffect.new().setup_whirl(pos, float(_w("radius", 40.0)) * _area(), float(_w("duration", 4.0)) * player.st.duration_mult, float(_w("damage", 9.0)), float(_w("pull", 70.0)))
		a.poison = 0.0 if at_player else float(_w("damage", 9.0))
		a.slow = float(_w("slow", 0.0))
		a.sprite.modulate = Color(str(DB.WEAPONS[id].get("tint", "8c59e6")))
		a.source = id
		game.spawn_area(a)
	Sfx.play("whirl", -6.0)


## aura: damaging field around you (venom garden adds tentacles) -----------
func _aura_radius() -> float:
	return float(_w("radius", 40.0)) * _area() + player.radius


func _aura_pulse() -> void:
	var r: float = _aura_radius()
	for c in game.creatures_in_radius(player.position, r):
		if not c.dead:
			_damage(c, float(_w("damage", 4.0)), {"dot": true})
	if DB.WEAPONS[id].get("tentacles", false) and int(_t * 2.0) % 2 == 0:
		_k_tentacle(r * 1.6, _amount())


## sweep: beams rotating around you --------------------------------------
func _tick_sweep() -> void:
	var n: int = _amount()
	var length: float = float(_w("length", 110.0)) * _area()
	var width: float = float(_w("width", 5.0))
	for i in n:
		var dir: Vector2 = Vector2.from_angle(_t * float(_w("speed", 1.6)) + TAU * i / n)
		var from: Vector2 = player.position
		var to: Vector2 = from + dir * length
		for c in game.creatures_in_radius(from + dir * length * 0.5, length * 0.5 + 10.0):
			if c.dead:
				continue
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(c.position, from, to)
			if q.distance_to(c.position) <= c.radius + width and c.can_hit(id + str(i), float(_w("hit_cd", 0.35))):
				_damage(c, float(_w("damage", 9.0)))


## orbit: things circling you (hunt / shoot variants) ----------------------
func _rebuild_orb() -> void:
	if game == null:
		return
	for o in _orb:
		if is_instance_valid(o.s):
			o.s.queue_free()
	_orb.clear()
	var sheet: String = str(DB.WEAPONS[id].sheet)
	for i in _amount():
		var s: Sprite2D = Art.sprite(sheet)
		if DB.WEAPONS[id].get("glow", false):
			var g: Sprite2D = Sprite2D.new()
			g.texture = Art.tex("fx/glow")
			var mat: CanvasItemMaterial = CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			g.material = mat
			g.modulate = Color(0.4, 1.0, 0.9, 0.45)
			g.scale = Vector2(0.35, 0.35)
			s.add_child(g)
		game.layer_fx.add_child(s)
		s.global_position = player.global_position
		_orb.append({"s": s, "mode": "orbit", "target": null, "t": randf() * 0.8})


func _tick_orb(delta: float) -> void:
	if _orb.size() != _amount():
		_rebuild_orb()
	var n := _orb.size()
	var r: float = float(_w("radius", 34.0)) * _area() + player.radius
	var spd: float = float(_w("speed", 2.4))
	var dmg: float = float(_w("damage", 5.0))
	var hunt: bool = DB.WEAPONS[id].get("hunt", false)
	var anim: bool = DB.WEAPONS[id].get("animated", false)
	for i in n:
		var o: Dictionary = _orb[i]
		var s: Sprite2D = o.s
		if not is_instance_valid(s):
			continue
		var ang: float = _t * spd + TAU * i / n
		var home: Vector2 = player.position + Vector2(cos(ang), sin(ang) * 0.8) * r
		var pos: Vector2 = s.global_position
		if hunt:
			o.t -= delta
			if o.mode == "orbit":
				pos = pos.lerp(home, 1.0 - pow(0.001, delta))
				if o.t <= 0.0:
					var tg: Creature = game.nearest_creature(pos, 170.0)
					o.t = 0.4
					if tg:
						o.mode = "hunt"
						o.target = tg
						o.t = 1.1
			else:
				var tgt = o.target
				if o.t <= 0.0 or tgt == null or not is_instance_valid(tgt) or tgt.dead:
					o.mode = "orbit"
					o.t = randf_range(0.3, 0.8)
				else:
					pos = pos.move_toward(tgt.position, 330.0 * delta)
		else:
			pos = home
		var dirv: Vector2 = pos - s.global_position
		if absf(dirv.x) > 0.2:
			s.flip_h = dirv.x < 0.0
		s.global_position = pos
		if anim or s.hframes > 1:
			var swim: int = Art.anim(str(DB.WEAPONS[id].sheet)).x if anim else s.hframes
			s.frame = int(_t * 10.0 + i) % maxi(1, swim)
		for c in game.creatures_in_radius(pos, 6.0):
			if c.can_hit(id + str(i), float(_w("hit_cd", 0.45))):
				_damage(c, dmg, {"knockback": (c.position - player.position).normalized() * float(_w("knock", 60.0))})
				if hunt and o.mode == "hunt":
					o.mode = "orbit"
					o.t = randf_range(0.5, 0.9)
	# tide ring: orbiters fire arrows outward
	var shoot: String = str(DB.WEAPONS[id].get("shoot", ""))
	if shoot != "":
		_shoot_t -= delta
		if _shoot_t <= 0.0:
			_shoot_t = 1.4 * player.st.cooldown_mult
			for o in _orb:
				if is_instance_valid(o.s):
					var dir: Vector2 = (o.s.global_position - player.position).normalized()
					var p: Projectile = Projectile.new().setup(shoot, dir * 380.0, dmg * 0.8, 0.8, 4.0)
					p.position = o.s.global_position
					p.pierce = 3
					p.source = id
					game.spawn_projectile(p)


## Weapon-level drawing (aura ring / rotating beams), in player space -------
func _draw() -> void:
	if kind == "aura":
		var r: float = _aura_radius()
		var c: Color = _color()
		var pulse: float = 0.5 + 0.5 * sin(_t * 4.0)
		draw_circle(Vector2.ZERO, r, Color(c.r, c.g, c.b, 0.07 + 0.04 * pulse))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(c.r, c.g, c.b, 0.35 + 0.2 * pulse), 1.0)
		for i in 10:
			var a: float = _t * 0.8 + TAU * i / 10.0
			var rr: float = r * (0.55 + 0.4 * fmod(_t * 0.5 + i * 0.37, 1.0))
			draw_rect(Rect2(Vector2(cos(a), sin(a)) * rr, Vector2(2, 2)), Color(c.r, c.g, c.b, 0.6))
	elif kind == "sweep":
		var n: int = _amount()
		var length: float = float(_w("length", 110.0)) * _area()
		var c2: Color = _color()
		for i in n:
			var dir: Vector2 = Vector2.from_angle(_t * float(_w("speed", 1.6)) + TAU * i / n)
			draw_line(Vector2.ZERO, dir * length, Color(c2.r, c2.g, c2.b, 0.25), 7.0)
			draw_line(Vector2.ZERO, dir * length, Color(c2.r, c2.g, c2.b, 0.8), 3.0)
			draw_line(Vector2.ZERO, dir * length, Color(1, 1, 1, 0.9), 1.0)
