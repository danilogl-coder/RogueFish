class_name Player
extends Node2D
## The player's fish: movement, bite attack, growth stages, mutations,
## inventory (weapons/passives), attributes, synergies and stats.

signal hp_changed
signal inventory_changed
signal stage_changed

var game
var species := "dourado"
var stage := 0
var mutations: Dictionary = {}          # slot -> mutation id
var weapons: Dictionary = {}            # id -> Weapon node
var passives: Dictionary = {}           # id -> level
var attributes := {"str": 0, "vit": 0, "agi": 0, "ins": 0}
var st: Dictionary = {}
var flags: Dictionary = {}
var tag_counts: Dictionary = {}
var active_combos: Array = []
var buffs: Dictionary = {}              # name -> seconds left

var hp := 100.0
var alive := true
var vel := Vector2.ZERO
var input_dir := Vector2.ZERO
var facing := 1.0
var radius := 7.0
var is_hidden := false
var stealth := 1.0
var revives := 0
var hit_log: Array = []  # recent hits (debug / analytics)
var diet := {"plant": 0.0, "meat": 0.0, "scavenge": 0.0}
var dash_charges := 2
var dash_max := 2
var _dash_t := 0.0
var _dash_recharge := 0.0
var _diet_dirty := 0.0
var _diet_type := ""

var visual: PlayerVisual
var _t := 0.0
var _invuln := 0.0
var _bite_cd := 0.0
var _bite_anim := 0.0
var _lunge_t := 0.0
var _since_attack := 9.0
var _slow_t := 0.0
var _slow_amt := 0.0
var _aura_t := 0.0
var _volt_t := 0.0
var _sting_t := 0.0
var _current_t := 0.0
var _regen_acc := 0.0
var _trail_t := 0.0


func setup(p_species: String) -> void:
	species = p_species
	visual = PlayerVisual.new()
	add_child(visual)
	revives = Profile.upgrade_level("revive")
	recalc()
	hp = st.max_hp
	visual.set_look(species, stage, mutations)
	add_weapon(DB.SPECIES[species].weapon)


# ------------------------------------------------------------------- stats
func recalc() -> void:
	var ratio: float = hp / st.max_hp if st.has("max_hp") and st.max_hp > 0.0 else 1.0
	var base: Dictionary = DB.SPECIES[species].stats
	var s := {
		"max_hp": base.max_hp, "speed": base.speed, "bite_damage": base.bite_damage, "armor": base.armor,
		"regen": 0.0, "damage_mult": 1.0, "area_mult": 1.0, "cooldown_mult": base.get("cooldown_mult", 1.0),
		"proj_speed_mult": 1.0, "duration_mult": 1.0, "amount": 0, "crit_chance": 0.05, "crit_mult": 2.0,
		"magnet": 42.0, "xp_mult": 1.0, "luck": 0.0, "thorns": 0.0, "poison_mult": 1.0, "bite_cd": 0.5,
		"bite_reach": 1.0, "lunge": 1.0, "light": 70.0, "chain_bonus": 0, "pearl_mult": 1.0,
		"bite_crit": 0.0, "kill_heal": 0.0,
	}
	flags = {}
	# meta progression
	s.max_hp += 10.0 * Profile.upgrade_level("vitality")
	s.damage_mult += 0.06 * Profile.upgrade_level("might")
	s.speed *= 1.0 + 0.04 * Profile.upgrade_level("swift")
	s.armor += Profile.upgrade_level("scales")
	s.magnet *= 1.0 + 0.15 * Profile.upgrade_level("magnet")
	s.xp_mult += 0.06 * Profile.upgrade_level("wisdom")
	s.luck += 0.1 * Profile.upgrade_level("luck")
	s.regen += 0.2 * Profile.upgrade_level("regen")
	s.pearl_mult += 0.15 * Profile.upgrade_level("greed")
	# growth
	s.max_hp += stage * 22.0
	s.bite_damage *= 1.0 + 0.4 * stage
	s.light += stage * 10.0
	s.magnet += stage * 4.0
	radius = DB.STAGE_RADIUS[stage]
	# attributes
	var a := attributes
	s.damage_mult += 0.08 * a.str
	s.bite_damage += a.str
	s.max_hp += 12.0 * a.vit
	s.regen += 0.15 * a.vit
	s.speed *= 1.0 + 0.04 * a.agi
	s.cooldown_mult *= 1.0 - 0.03 * a.agi
	s.crit_chance += 0.03 * a.ins
	s.magnet *= 1.0 + 0.12 * a.ins
	# passives
	for id in passives:
		var l: int = passives[id]
		match id:
			"gills": s.area_mult += 0.1 * l
			"heart":
				s.max_hp += 20.0 * l
				s.regen += 0.2 * l
			"fins": s.speed *= 1.0 + 0.07 * l
			"teeth": s.damage_mult += 0.1 * l
			"venom": s.poison_mult += 0.2 * l
			"battery": s.cooldown_mult *= 1.0 - 0.07 * l
			"eyes":
				s.crit_chance += 0.05 * l
				s.crit_mult += 0.15 * l
			"shell": s.armor += l
			"magnet": s.magnet *= 1.0 + 0.3 * l
			"luck": s.luck += 0.15 * l
			"brain": s.xp_mult += 0.08 * l
	# mutations
	for slot in mutations:
		match mutations[slot]:
			"head_piranha":
				s.bite_damage *= 1.4
				flags.bleed = true
			"head_sword":
				s.bite_reach *= 1.6
				s.lunge *= 1.5
				flags.pierce_bite = true
			"head_lure":
				s.magnet *= 1.5
				s.crit_chance += 0.08
				s.light += 90.0
			"fins_spiky":
				s.thorns += 10.0
				s.armor += 1
			"fins_wing":
				s.speed *= 1.22
				s.bite_cd *= 0.85
			"fins_volt": flags.volt_fins = true
			"skin_armor":
				s.armor += 3
				s.max_hp += 25.0
			"skin_toxic": flags.toxic_aura = true
			"skin_glow":
				s.crit_chance += 0.1
				s.regen += 0.6
				s.light += 50.0
			"tail_fork":
				s.speed *= 1.12
				s.lunge *= 1.8
			"tail_sting": flags.sting = true
			"tail_eel": flags.eel_chain = true
	# synergies
	tag_counts = {}
	var items: Array = []
	for w in weapons:
		items.append(DB.WEAPONS[w].tag)
	for p in passives:
		items.append(DB.PASSIVES[p].tag)
	for slot in mutations:
		items.append(DB.MUTATIONS[mutations[slot]].tag)
	for t in items:
		if t != "":
			tag_counts[t] = int(tag_counts.get(t, 0)) + 1
	var tc := tag_counts
	if tc.get("volt", 0) >= 2:
		s.chain_bonus += 1
		flags.volt_dmg = 1.15
	if tc.get("volt", 0) >= 4:
		flags.shock_stun = true
	if tc.get("poison", 0) >= 2:
		s.poison_mult += 0.3
	if tc.get("poison", 0) >= 4:
		flags.toxic_explode = true
	if tc.get("abyss", 0) >= 2:
		s.crit_chance += 0.08
	if tc.get("abyss", 0) >= 4:
		s.crit_mult = maxf(s.crit_mult, 2.5) + 0.25
		flags.crit_heal = true
	if tc.get("coral", 0) >= 2:
		s.armor += 2
	if tc.get("coral", 0) >= 4:
		s.thorns += 15.0
		s.regen += 1.0
		flags.thorns_reflect = true
	if tc.get("predator", 0) >= 2:
		s.bite_damage *= 1.25
	if tc.get("predator", 0) >= 4:
		s.kill_heal += 2.0
		s.bite_cd *= 0.75
	if tc.get("current", 0) >= 2:
		s.speed *= 1.1
		s.proj_speed_mult += 0.2
	if tc.get("current", 0) >= 4:
		flags.current_wave = true
	active_combos = []
	for cid in DB.COMBOS:
		var ok := true
		for t in DB.COMBOS[cid].tags:
			if tc.get(t, 0) < 2:
				ok = false
		if ok:
			active_combos.append(cid)
	if active_combos.has("storm_toxin"):
		flags.shock_poison = true
	if active_combos.has("abyss_hunter"):
		s.bite_crit += 0.25
	if active_combos.has("living_reef"):
		s.regen += 1.0
		s.area_mult += 0.1
	# diet (Everything-is-Crab style: what you eat shapes you)
	_diet_type = diet_type()
	match _diet_type:
		"plant":
			s.regen += 0.8
			s.xp_mult += 0.15
		"meat":
			s.damage_mult += 0.12
			s.bite_damage *= 1.15
		"scavenge":
			s.armor += 2
			s.magnet *= 1.3
		"omni":
			s.damage_mult += 0.06
			s.regen += 0.4
			s.xp_mult += 0.08
	dash_max = 2 + (1 if mutations.get("tail", "") == "tail_fork" else 0) + (1 if mutations.get("fins", "") == "fins_wing" else 0)
	# temporary buffs
	if buffs.has("vent"):
		s.damage_mult *= 1.3
	if buffs.has("frenzy"):
		s.speed *= 1.2
		s.damage_mult *= 1.15
		s.bite_cd *= 0.8
	s.cooldown_mult = maxf(s.cooldown_mult, 0.35)
	s.crit_chance = minf(s.crit_chance, 0.9)
	st = s
	hp = clampf(ratio * st.max_hp, 1.0, st.max_hp)
	hp_changed.emit()
	var best_syn := 0
	for t in tag_counts:
		best_syn = maxi(best_syn, int(tag_counts[t]))
	Profile.set_max("max_synergy", best_syn)
	Profile.set_max("max_mutations", mutations.size())


# ------------------------------------------------------------------- loop
func _physics_process(delta: float) -> void:
	if not alive:
		return
	_t += delta
	_invuln -= delta
	_bite_cd -= delta
	_bite_anim -= delta
	_lunge_t -= delta
	_since_attack += delta
	_slow_t -= delta
	_dash_t -= delta
	_tick_buffs(delta)
	if dash_charges < dash_max:
		_dash_recharge += delta
		if _dash_recharge >= 2.4:
			_dash_recharge = 0.0
			dash_charges += 1
	if _diet_dirty > 0.0:
		_diet_dirty -= delta
		if _diet_dirty <= 0.0 and diet_type() != _diet_type:
			recalc()
			game.hud.toast("Dieta: %s (%s)" % [DB.DIETS[_diet_type].name, DB.DIETS[_diet_type].desc], Color("a4dc4c"))
	# movement
	var spd: float = st.speed * (1.0 - _slow_amt if _slow_t > 0.0 else 1.0)
	if _dash_t > 0.0:
		pass
	elif _lunge_t <= 0.0:
		var target_v := input_dir * spd
		var accel := 820.0 if input_dir != Vector2.ZERO else 420.0
		vel = vel.move_toward(target_v, accel * delta)
	position += vel * delta
	position.x = clampf(position.x, radius, DB.WORLD_W - radius)
	position.y = clampf(position.y, DB.SURFACE_Y + radius, DB.floor_at(position.x) - radius)
	if absf(input_dir.x) > 0.15 and _lunge_t <= 0.0:
		facing = signf(input_dir.x)
	# visuals
	visual.scale.x = facing
	var tilt := clampf(vel.y / maxf(st.speed, 1.0), -1.0, 1.0) * 0.32
	visual.rotation = lerpf(visual.rotation, tilt * facing, 1.0 - pow(0.001, delta))
	var frame := 0
	if _bite_anim > 0.0:
		frame = 4 if _bite_anim > 0.1 else 5
	else:
		var swim_fps := 5.0 + vel.length() / maxf(st.speed, 1.0) * 7.0
		frame = int(_t * swim_fps) % 4
	visual.set_frame(frame)
	visual.flash(_invuln > 0.45 and _invuln < 0.8)
	if buffs.has("frenzy"):
		visual.modulate = Color(1.3, 1.1, 0.6) if int(_t * 10.0) % 2 == 0 else Color(1.1, 1.0, 0.8)
	visual.modulate.a = 0.5 if is_hidden else (0.55 if _invuln > 0.0 and int(_t * 20.0) % 2 == 0 else 1.0)
	visual.pulse_glows(_t)
	_regen(delta)
	_hide_logic(delta)
	_mutation_effects(delta)
	# swim trail bubbles
	_trail_t -= delta
	if _trail_t <= 0.0 and vel.length() > st.speed * 0.6:
		_trail_t = 0.18
		game.burst(position - Vector2(facing * radius, 0), [1], 1, 12.0, 0.8)


func _tick_buffs(delta: float) -> void:
	var changed := false
	for k in buffs.keys():
		buffs[k] -= delta
		if buffs[k] <= 0.0:
			buffs.erase(k)
			changed = true
	if changed:
		recalc()


func add_buff(buff_name: String, seconds: float) -> void:
	var had := buffs.has(buff_name)
	buffs[buff_name] = seconds
	if not had:
		recalc()


func _regen(delta: float) -> void:
	var r: float = st.regen
	if is_hidden:
		r += 2.0
	if r <= 0.0 or hp >= st.max_hp:
		return
	_regen_acc += r * delta
	if _regen_acc >= 1.0:
		var amt := floorf(_regen_acc)
		_regen_acc -= amt
		heal(amt, false)


func _hide_logic(delta: float) -> void:
	var inside: bool = game.world.hideout_at(position) != null
	var danger: bool = game.director.phase != "explore"
	if inside and _since_attack > 0.8 and stealth > 0.0:
		is_hidden = true
		stealth -= delta * (0.12 if danger else 0.05)
	else:
		is_hidden = false
		stealth = minf(1.0, stealth + delta * 0.14)
	if stealth <= 0.0:
		is_hidden = false


func _mutation_effects(delta: float) -> void:
	if flags.get("toxic_aura", false):
		_aura_t -= delta
		if _aura_t <= 0.0:
			_aura_t = 0.5
			var r: float = (26.0 + radius) * st.area_mult
			for c in game.creatures_in_radius(position, r, false):
				c.take_damage(3.0 * st.damage_mult * st.poison_mult, {"dot": true, "poison": 3.0 * st.poison_mult, "color": Color("a4dc4c"), "source": "aura"})
	if flags.get("volt_fins", false):
		_volt_t -= delta
		if _volt_t <= 0.0:
			_volt_t = 1.2 * st.cooldown_mult
			var t: Creature = game.nearest_creature(position, 90.0)
			if t:
				game.zap(position, t.position)
				var r2: Array = game.roll_damage(10.0 + stage * 3.0)
				t.take_damage(r2[0], shock_info(r2[1]))
				Sfx.play("zap", -10.0)
	if flags.get("sting", false):
		_sting_t -= delta
		if _sting_t <= 0.0:
			_sting_t = 0.9
			var behind := position - Vector2(facing * (radius + 14.0), 0)
			var hit := false
			for c in game.creatures_in_radius(behind, 16.0 + radius * 0.5, false):
				var r3: Array = game.roll_damage(12.0 + stage * 4.0)
				c.take_damage(r3[0], {"crit": r3[1], "poison": 4.0 * st.poison_mult, "source": "sting"})
				hit = true
			if hit:
				Sfx.play("thorn", -6.0)
	if flags.get("current_wave", false):
		_current_t -= delta
		if _current_t <= 0.0:
			_current_t = 6.0
			var ring := RingFx.new().setup(110.0 * st.area_mult, 0.45, Color("4ee0d8"))
			ring.position = position
			game.layer_fx.add_child(ring)
			for c in game.creatures_in_radius(position, 110.0 * st.area_mult, false):
				c.take_damage(10.0 * st.damage_mult, {"knockback": (c.position - position).normalized() * 260.0, "source": "current"})


func shock_info(crit: bool) -> Dictionary:
	var info := {"crit": crit, "source": "shock", "color": Color("fff060")}
	if flags.get("shock_stun", false):
		info.stun = 0.4
	if flags.get("shock_poison", false):
		info.poison = 4.0 * st.poison_mult
	return info


# ------------------------------------------------------------------- bite
func try_bite() -> void:
	if not alive or _bite_cd > 0.0 or game.get_tree().paused:
		return
	_bite_cd = st.bite_cd
	_bite_anim = 0.2
	_since_attack = 0.0
	var reach: float = (radius * 0.9 + 9.0) * st.bite_reach
	var dir := Vector2(facing, 0.0)
	var tgt: Creature = game.nearest_creature(position, reach * 3.0 + 24.0)
	if input_dir.length() > 0.2:
		dir = input_dir.normalized()
		if tgt and dir.dot((tgt.position - position).normalized()) > 0.4:
			dir = (tgt.position - position).normalized()
	elif tgt:
		dir = (tgt.position - position).normalized()
	if absf(dir.x) > 0.05:
		facing = signf(dir.x)
	vel = dir * st.speed * 1.9 * st.lunge
	_lunge_t = 0.13
	var mouth := position + dir * (radius + reach * 0.45)
	var hits: Array = game.creatures_in_radius(mouth, reach)
	if flags.get("pierce_bite", false):
		for c in game.creatures_in_radius(mouth + dir * reach, reach * 0.8):
			if not hits.has(c):
				hits.append(c)
	var landed := 0
	var swallowed := false
	for c in hits:
		if c.dead:
			continue
		landed += 1
		if c.swallowable and not c.is_boss and c.tier < stage:
			c.swallow()
			heal(2.0 + stage, false)
			swallowed = true
			continue
		var crit: bool = randf() < st.crit_chance + st.bite_crit
		var dmg: float = st.bite_damage * st.damage_mult * (st.crit_mult if crit else 1.0)
		var info := {"crit": crit, "source": "bite", "knockback": dir * 170.0}
		if flags.get("bleed", false):
			info.bleed = st.bite_damage * 0.25
		c.take_damage(dmg, info)
		if flags.get("eel_chain", false):
			_chain_from(c, 2, dmg * 0.45)
	for p in game.world.pois:
		if is_instance_valid(p) and p.kind == "chest" and p.position.distance_to(mouth) < reach + 16.0:
			p.bite()
			landed += 1
	# carcasses: scavenging heals and feeds the "necrófago" diet
	for cc in game.carcasses.duplicate():
		if is_instance_valid(cc) and cc.position.distance_to(mouth) < reach + cc.radius:
			var got: int = cc.bite(1 + stage / 2)
			if got > 0:
				heal(1.5 * got * (1.6 if _diet_type == "scavenge" else 1.0))
				game.add_xp_f(0.8 * got)
				eat_diet("scavenge", 2.0 * got)
				Profile.bump("carcass", got)
				landed += 1
	# kelp: grazing is the herbivore path
	if landed == 0:
		var k: Kelp = game.world.nearest_kelp(mouth, reach + 10.0)
		if k and k.graze():
			heal(1.0)
			game.add_xp_f(0.4)
			eat_diet("plant", 3.0)
			Profile.bump("kelp")
			game.burst(mouth, [6, 0], 5, 30.0, 0.5)
			landed += 1
	if swallowed:
		Sfx.play("gulp")
	if landed > 0:
		Sfx.play("crunch", -2.0)
		game.shake(1.5)
		game.hitstop(0.03)
		game.burst(mouth, [3, 0], 4, 40.0, 0.4)
	else:
		Sfx.play("bite", -4.0)
		game.burst(mouth, [0, 1], 3, 30.0, 0.5)


func _chain_from(c: Creature, jumps: int, dmg: float) -> void:
	var from := c.position
	var done := {c.get_instance_id(): true}
	for i in jumps + int(st.chain_bonus):
		var best: Creature = null
		var bd := 80.0 * 80.0
		for o in game.creatures_in_radius(from, 80.0, false):
			if done.has(o.get_instance_id()) or o.dead:
				continue
			var d: float = o.position.distance_squared_to(from)
			if d < bd:
				bd = d
				best = o
		if best == null:
			break
		done[best.get_instance_id()] = true
		game.zap(from, best.position)
		best.take_damage(dmg, shock_info(false))
		from = best.position
	Sfx.play("zap", -8.0)


func bite_cooldown_ratio() -> float:
	return clampf(_bite_cd / maxf(st.bite_cd, 0.01), 0.0, 1.0)


# ----------------------------------------------------------------- damage
func take_damage(amount: float, source) -> void:
	if not alive or _invuln > 0.0:
		return
	var dmg := maxf(1.0, amount - st.armor)
	hp -= dmg
	if hit_log.size() > 12:
		hit_log.pop_front()
	hit_log.append("%s:%d" % [(source.id if source.id != "" else "boss_part") if source is Creature else "proj", int(dmg)])
	_invuln = 0.75
	is_hidden = false
	stealth = maxf(0.0, stealth - 0.2)
	game.damage_number(position + Vector2(0, -radius - 6), dmg, false, Color("ff5c4c"))
	game.shake(4.0)
	Sfx.play("hurt", -2.0)
	Profile.vibrate(35)
	hp_changed.emit()
	if source is Creature and st.thorns > 0.0 and not source.dead:
		var t: float = st.thorns + (amount * 0.5 if flags.get("thorns_reflect", false) else 0.0)
		source.take_damage(t, {"source": "thorns", "color": Color("f07c7c")})
		Sfx.play("thorn", -6.0)
	if hp <= 0.0:
		_die()


func apply_slow(amount: float, seconds: float) -> void:
	_slow_amt = amount
	_slow_t = maxf(_slow_t, seconds)


func heal(amount: float, show := true) -> void:
	if not alive:
		return
	var before := hp
	hp = minf(st.max_hp, hp + amount)
	if show and hp - before >= 1.0:
		game.float_text(position + Vector2(0, -radius - 8), "+%d" % int(hp - before), Color("a4dc4c"))
	hp_changed.emit()


func _die() -> void:
	if revives > 0:
		revives -= 1
		hp = st.max_hp * 0.5
		_invuln = 2.5
		game.float_text(position + Vector2(0, -20), "SEGUNDA CHANCE!", Color("5ee0ff"), 16)
		Sfx.play("evolve")
		for c in game.creatures_in_radius(position, 140.0):
			if not c.is_boss:
				c.take_damage(9999.0, {"source": "revive"})
		game.fx("fx/explosion", position, 12.0, 3.0, Color("5ee0ff"))
		hp_changed.emit()
		return
	alive = false
	hp = 0.0
	hp_changed.emit()
	visual.modulate = Color(0.6, 0.6, 0.7, 0.8)
	var t := create_tween()
	t.tween_property(visual, "rotation", PI * facing, 0.8)
	t.parallel().tween_property(self, "position:y", position.y - 30.0, 1.5)
	game.burst(position, [2, 2, 0, 3], 18, 90.0, 0.9)
	game.on_player_died()


func revive() -> void:
	alive = true
	hp = st.max_hp * 0.5
	_invuln = 2.5
	visual.rotation = 0.0
	visual.modulate = Color.WHITE
	hp_changed.emit()


func on_kill(c: Creature, info: Dictionary) -> void:
	eat_diet("meat", 1.0 + c.tier)
	if st.kill_heal > 0.0 and c.faction != "herb":
		heal(st.kill_heal, false)
	if flags.get("crit_heal", false) and info.get("crit", false):
		heal(1.0, false)


# -------------------------------------------------------------- inventory
func add_weapon(id: String) -> void:
	if weapons.has(id):
		weapons[id].level_up()
	else:
		var w := Weapon.new()
		w.id = id
		w.player = self
		w.game = game
		add_child(w)
		weapons[id] = w
	recalc()
	inventory_changed.emit()


func evolve_weapon(evo_id: String) -> void:
	Profile.bump("evolutions")
	var from: String = DB.EVOLUTIONS[evo_id].from
	if weapons.has(from):
		weapons[from].evolve(evo_id)
		Sfx.play("evolve")
		game.fx("fx/explosion", position, 14.0, 2.0, Color("ffbf45"))
	inventory_changed.emit()


func add_passive(id: String) -> void:
	passives[id] = int(passives.get(id, 0)) + 1
	recalc()
	inventory_changed.emit()


func add_mutation(mid: String) -> void:
	var slot: String = DB.MUTATIONS[mid].slot
	mutations[slot] = mid
	recalc()
	visual.set_look(species, stage, mutations)
	Sfx.play("evolve")
	game.fx("fx/hit_spark", position, 10.0, 4.0, Color("a4dc4c"))
	game.burst(position, [7, 0, 4], 20, 90.0, 0.9)
	inventory_changed.emit()


func add_attribute(key: String) -> bool:
	if attributes[key] >= DB.ATTRIBUTE_MAX:
		return false
	attributes[key] += 1
	recalc()
	inventory_changed.emit()
	return true


func grow_to(new_stage: int) -> void:
	if new_stage <= stage:
		return
	stage = new_stage
	recalc()
	hp = minf(st.max_hp, hp + st.max_hp * 0.25)
	visual.set_look(species, stage, mutations)
	game.float_text(position + Vector2(0, -30), DB.STAGE_NAMES[stage].to_upper() + "!", Color("ffbf45"), 16)
	game.fx("fx/explosion", position, 12.0, 2.5, Color("5ee0ff"))
	game.shake(5.0)
	Sfx.play("evolve")
	stage_changed.emit()
	inventory_changed.emit()


func free_mutation_slots() -> Array:
	var out := []
	for s in DB.MUTATION_SLOTS:
		if not mutations.has(s):
			out.append(s)
	return out


func weapon_level(id: String) -> int:
	return weapons[id].level if weapons.has(id) else 0


# ------------------------------------------------------------------- diet
func eat_diet(kind: String, amount: float) -> void:
	diet[kind] = float(diet[kind]) + amount
	_diet_dirty = 1.5


## Dominant diet (>= 50% of what you ate) or omnivore when balanced.
func diet_type() -> String:
	var total: float = diet.plant + diet.meat + diet.scavenge
	if total < 25.0:
		return ""
	for k in ["plant", "meat", "scavenge"]:
		if diet[k] / total >= 0.5:
			return k
	return "omni"


func diet_share(kind: String) -> float:
	var total: float = diet.plant + diet.meat + diet.scavenge
	return diet[kind] / total if total > 0.0 else 0.0


# ------------------------------------------------------------------- dash
## Deeeep.io-style boost: quick burst with brief invulnerability.
func try_dash() -> void:
	if not alive or dash_charges <= 0 or game.get_tree().paused or _dash_t > -0.15:
		return
	dash_charges -= 1
	_dash_t = 0.2
	var dir := input_dir.normalized() if input_dir.length() > 0.2 else Vector2(facing, 0)
	vel = dir * st.speed * 3.4
	grant_invuln(0.25)
	Sfx.play("dash", -2.0)
	game.burst(position, [0, 1, 1], 8, 60.0, 0.6)


func grant_invuln(seconds: float) -> void:
	_invuln = maxf(_invuln, seconds)
