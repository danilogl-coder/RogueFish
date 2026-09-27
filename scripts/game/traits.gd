class_name Traits
extends Node
## Each character's special effect (the "trait" in scripts/data/roster.gd).
## The Player and Creature call these hooks; every hook is a no-op for
## characters that don't use it.

var player
var game
var sp := ""                    # species id
var _cd := 0.0                  # generic trait cooldown
var _still := 0.0               # seconds standing still
var _hits := 0                  # neon spark counter
var _bites := 0                 # otter tool counter
var _blood := 0                 # shark stacks
var _blood_t := 0.0
var _was_hidden := false        # moray: next bite after hiding
var _primed := false            # bobbit / otter: next bite is empowered
var _crit_cd := 0.0


func setup(p) -> Traits:
	player = p
	game = p.game
	sp = p.species
	return self


# ------------------------------------------------------------------ stats
func modify(s: Dictionary) -> void:
	match sp:
		"dourado":
			s.xp_mult += 0.1
		"sardinha":
			s.speed *= 1.08
		"camarao":
			s.regen += 0.5
		"lanterna":
			s.xp_mult += 0.2
		"ourico":
			s.thorns += 12.0
		"piranha":
			s.bite_cd *= 0.75
		"isopode":
			s.armor += 1.0
		"dourado_raro":
			s.pearl_mult += 0.4
			s.luck += 0.2
		"caranguejo_yeti":
			s.regen += 1.0
		"tubarao":
			s.damage_mult *= 1.0 + 0.03 * _blood
		"megalodonte":
			if player.hp < player.st.get("max_hp", 999.0) * 0.5:
				s.damage_mult *= 1.3
				s.speed *= 1.15
	if player.buffs.has("concha"):
		s.armor += 5.0
		s.regen += 2.0
	if player.buffs.has("inflado"):
		s.thorns += 15.0


func flags(f: Dictionary) -> void:
	if sp == "piranha":
		f["bleed"] = true


func dash_bonus() -> int:
	return 1 if sp == "lula" else 0


func run_start() -> void:
	if sp == "dourado":
		game.rerolls += 1
	if sp == "piolho" and player.infest:
		player.infest.add("m", player.position, "")
		player.infest.add("m", player.position, "")
		player.infest.add("f", player.position, "")


# ------------------------------------------------------------------- tick
func tick(delta: float) -> void:
	_cd -= delta
	_crit_cd -= delta
	var still: bool = player.input_dir.length() < 0.15 and player.vel.length() < 20.0
	_still = _still + delta if still else 0.0
	match sp:
		"caramujo":
			if _still >= 1.0:
				player.add_buff("concha", 0.3)
		"caranguejo_yeti":
			# the vents feed its bacteria garden: extra regeneration there
			if player.position.x > DB.BASE_WORLD_W and player.hp < player.st.max_hp:
				player.heal(2.0 * delta, false)
		"minhoca":
			if _still >= 1.5 and not _primed:
				_primed = true
				game.float_text(player.position + Vector2(0, -16), "BOTE PRONTO", Color("e8a0ff"), 8)
		"moreia":
			if player.is_hidden and not player.swallowed:
				_was_hidden = true
		"tubarao":
			if _blood > 0:
				_blood_t -= delta
				if _blood_t <= 0.0:
					_blood = 0
					player.recalc()
		"megalodonte":
			var low: bool = player.hp < player.st.max_hp * 0.5
			if low != player.has_meta("frenzy_on"):
				if low:
					player.set_meta("frenzy_on", true)
					game.float_text(player.position + Vector2(0, -18), "FRENESI ANCESTRAL!", Color("ff5c4c"), 10)
				else:
					player.remove_meta("frenzy_on")
				player.recalc()
		"garoupa":
			if _cd <= 0.0 and not player.has_meta("block_ready"):
				player.set_meta("block_ready", true)


# ------------------------------------------------------ incoming damage
## Returns the damage the player actually takes (0 = avoided).
func incoming(amount: float, source) -> float:
	match sp:
		"sardinha":
			if randf() < 0.15:
				game.float_text(player.position + Vector2(0, -16), "DESVIOU!", Color("c8e8ff"), 8)
				return 0.0
		"caranguejo":
			if randf() < 0.2:
				game.float_text(player.position + Vector2(0, -16), "APARADO!", Color("ffbf45"), 8)
				if source is Creature and not source.dead:
					source.take_damage(amount, {"source": "parry", "stun": 0.4})
				return 0.0
		"garoupa":
			if player.has_meta("block_ready"):
				player.remove_meta("block_ready")
				_cd = 10.0
				game.float_text(player.position + Vector2(0, -16), "BLOQUEADO!", Color("a4dc4c"), 8)
				game.fx("fx/hit_spark", player.position, 20.0, 1.4, Color("a4dc4c"))
				return 0.0
		"tartaruga":
			amount *= 0.75
		"baiacu":
			if player.buffs.has("inflado"):
				amount *= 0.5
			elif _cd <= 0.0:
				_cd = 8.0
				player.add_buff("inflado", 2.0)
				Sfx.play("inflate", -2.0)
				game.float_text(player.position + Vector2(0, -16), "INFLOU!", Color("ffd76a"), 8)
				amount *= 0.5
	if source is Creature and not source.dead:
		match sp:
			"agua_viva":
				source.take_damage(6.0 * player.st.damage_mult, {"source": "sting", "poison": 3.0, "slow": 0.5, "slow_time": 1.5, "color": Color("e0a8ff")})
			"leviata":
				source.take_damage(15.0 * player.st.damage_mult, player.shock_info(false))
				game.zap(player.position, source.position, Color("7ae0ff"))
	return amount


## Called after damage was applied (hp already reduced).
func after_hurt() -> void:
	if sp == "lula_vampira" and _cd <= 0.0 and player.alive:
		_cd = 6.0
		player.add_buff("trevas", 1.5)
		game.burst(player.position, [5, 5, 7], 14, 60.0, 0.8)
		game.float_text(player.position + Vector2(0, -16), "CAPA DE TREVAS", Color("b070ff"), 8)
	if sp == "pepino" and player.hp < player.st.max_hp * 0.3 and player.hp > 0.0 and not player.has_meta("gut_cd"):
		player.set_meta("gut_cd", true)
		get_tree().create_timer(60.0, false).timeout.connect(func(): player.remove_meta("gut_cd"))
		player.heal(player.st.max_hp * 0.35)
		game.float_text(player.position + Vector2(0, -20), "EVISCERAÇÃO!", Color("ff8a9a"), 10)
		game.burst(player.position, [2, 6, 2], 16, 80.0, 0.8)
		for c in game.creatures_in_radius(player.position, 50.0, false):
			c.take_damage(20.0 * player.st.damage_mult, {"source": "guts", "slow": 0.7, "slow_time": 2.0})


# ------------------------------------------------------ outgoing damage
## Adjusts damage the player deals to a creature (any source).
func outgoing(c: Creature, amount: float, info: Dictionary) -> float:
	match sp:
		"barracuda":
			if not c.has_meta("ambushed"):
				c.set_meta("ambushed", true)
				if not info.get("crit", false):
					info.crit = true
					amount *= player.st.crit_mult
		"orca":
			if c.is_boss or c.tier >= 3:
				amount *= 1.25
		"neon":
			if not info.get("dot", false) and info.get("source", "") != "spark":
				_hits += 1
				if _hits >= 6:
					_hits = 0
					player.call_deferred("_chain_from", c, 2, 8.0 * player.st.damage_mult)
		"pescadora":
			if info.get("crit", false) and _crit_cd <= 0.0:
				_crit_cd = 0.3
				player.heal(1.0, false)
				for pk in game.pickups:
					if is_instance_valid(pk) and pk.kind == "xp" and pk.position.distance_to(player.position) < 110.0:
						pk.attracted = true
	return amount


func on_kill(_c: Creature) -> void:
	if sp == "verme_tubo":
		_bites += 1
		if _bites % 8 == 0:
			player.heal(player.st.max_hp * 0.08)
	if sp == "tubarao":
		_blood = mini(_blood + 1, 10)
		_blood_t = 4.0
		player.recalc()


# ------------------------------------------------------------------ bite
## Multiplier for the bite about to land.
func bite_mult() -> float:
	var k := 1.0
	match sp:
		"moreia":
			if _was_hidden:
				k *= 2.0
		"minhoca":
			if _primed:
				k *= 3.0
		"lontra":
			if _primed:
				k *= 2.0
	return k


## After a bite: extra reach, devour, counters.
func after_bite(hits: Array, dmg: float, mouth: Vector2, reach: float) -> void:
	match sp:
		"moreia":
			_was_hidden = false
		"minhoca":
			if _primed:
				_primed = false
				game.burst(mouth, [3, 2], 8, 60.0, 0.5)
		"lontra":
			_bites += 1
			if _primed:
				_primed = false
				for c in hits:
					if is_instance_valid(c) and not c.dead:
						c.take_damage(0.0, {"source": "tool", "stun": 0.8})
				game.fx("fx/explosion", mouth, 20.0, 0.8, Color("d8c8a8"))
			elif _bites % 5 == 0:
				_primed = true
		"kraken":
			var extra := 0
			for c in game.creatures_in_radius(mouth, reach * 2.2, false):
				if extra >= 3 or hits.has(c) or c.dead:
					continue
				extra += 1
				game.zap(mouth, c.position, Color("ff8a9a"))
				c.take_damage(dmg * 0.6, {"source": "bite", "knockback": (c.position - mouth).normalized() * 120.0})
		"vibora":
			var landed := hits.filter(func(c): return is_instance_valid(c)).size()
			if landed > 0:
				player.heal(dmg * 0.15 * landed, false)
		"titanacon":
			for c in hits:
				if is_instance_valid(c) and not c.dead and not c.is_boss and c.hp < c.max_hp * 0.2:
					game.float_text(c.position, "DEVORADO!", Color("ff5c4c"), 8)
					c.swallow()
					player.heal(3.0, false)


func carcass_mult() -> float:
	return 2.0 if sp == "isopode" else 1.0


func carcass_xp_mult() -> float:
	return 1.5 if sp == "isopode" else 1.0


# ------------------------------------------------------------------ misc
func on_dash() -> void:
	if sp == "lula":
		var a := AreaEffect.new().setup_cloud("fx/ink_cloud", player.position, 30.0 * player.st.area_mult, 3.0, 6.0, 0.5, true)
		a.source = "ink"
		game.spawn_area(a)


func parasite_immune() -> bool:
	return sp == "camarao"


func heat_immune() -> bool:
	return sp in ["caranguejo_yeti", "verme_tubo"]


func colony_slows() -> bool:
	return sp != "piolho"


func scares_predators() -> bool:
	return sp == "orca"
