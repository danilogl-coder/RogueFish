class_name RunMods
extends Node
## Everything bought in the shop that changes a run: relics, the chosen Maré
## (tide) and the active modes. Owned by Game; Creature / Player call hooks.

var game
var tide := ""                  ## active Maré id ("" = none)
var modes: Array = []           ## active mode ids
var _storm_t := 2.5
var _hourglass_used := false
var _slowmo := 0.0


func setup(g) -> RunMods:
	game = g
	var t: String = str(Profile.settings.get("tide", ""))
	if t != "" and Profile.owns(t) and Profile.owns("relic_compass"):
		tide = t
	for m in Profile.settings.get("modes", []):
		if Profile.owns(m):
			modes.append(m)
	return self


func relic(id: String) -> bool:
	return Profile.owns(id)


func mode(id: String) -> bool:
	return modes.has(id)


## Extra pearls earned at the end of the run (sum of mode bonuses).
func pearl_bonus() -> float:
	var b := 0.0
	for m in modes:
		b += float(Shop.ITEMS[m].get("bonus", 0.0))
	return b


# ------------------------------------------------------------ run start
func run_start() -> void:
	var p: Player = game.player
	if mode("mode_hyper"):
		Engine.time_scale = 1.3
	if relic("relic_amber"):
		var ids := DB.MUTATIONS.keys()
		ids.shuffle()
		p.add_mutation(ids[0])
		game.hud.toast("Âmbar Ancestral: %s" % Families.mutation_name(p.species, ids[0]), Color("ffbf45"))
	if tide != "":
		game.hud.toast(Shop.ITEMS[tide].name.to_upper() + " ativa", Color("7ae0ff"))


func cycle_start() -> void:
	_hourglass_used = false
	if relic("relic_bottle"):
		game.world.spawn_poi("chest", game.player.position)
		game.hud.toast("Uma garrafa trouxe um baú!", Color("ffbf45"))


func stats(s: Dictionary) -> void:
	if tide == "tide_silver":
		s.xp_mult += 0.25
		s.magnet *= 2.0
	if tide == "tide_gold":
		s.pearl_mult += 1.0
	if mode("mode_hyper"):
		s.xp_mult += 0.3


func elite_mult() -> float:
	return 2.0 if relic("relic_pearl") else 1.0


func wave_mult() -> float:
	return 1.3 if mode("mode_hyper") else 1.0


# ------------------------------------------------------------ creatures
func on_spawn(c: Creature) -> void:
	if c.is_boss:
		if mode("mode_inverse"):
			c.max_hp *= 1.5
			c.hp = c.max_hp
		return
	if tide == "tide_gold":
		c.max_hp *= 1.3
	if mode("mode_inverse"):
		c.max_hp *= 2.0
		c.speed *= 1.0 + minf(0.6, game.time / 600.0)
	c.hp = c.max_hp
	if mode("mode_mutant") and c.faction in ["pred", "hazard"] and c.id not in ["louse", "louse_f", "parasite"] and randf() < 0.3:
		var keys := Shop.MUTANT_VARIANTS.keys()
		c.set_variant(keys[randi() % keys.size()])


func on_death(c: Creature, info: Dictionary) -> void:
	if info.get("eaten", false) or info.get("starved", false):
		return
	if tide == "tide_life":
		game.player.heal(1.0, false)
	if tide == "tide_black" and c.poison_t > 0.0:
		var a := AreaEffect.new().setup_cloud("fx/poison_cloud", c.position, 26.0, 2.5, 5.0, 0.3, true)
		a.source = "tide_black"
		game.spawn_area(a)
	match c.variant:
		"toxic":
			var h := AreaEffect.new().setup_cloud("fx/poison_cloud", c.position, 30.0, 3.0, 5.0 * c.dmg_mult, 0.0, true)
			h.hostile = true
			h.source = "mutant"
			game.spawn_area(h)
		"treasure":
			for i in 3:
				game.spawn_pickup("pearl", c.position + Vector2(randf_range(-10, 10), randf_range(-8, 8)), 1)


## Critical hits under the Red Tide explode.
func on_crit(c: Creature, dmg: float) -> void:
	if tide != "tide_red":
		return
	game.fx("fx/explosion", c.position, 20.0, 0.9, Color("ff7060"))
	for o in game.creatures_in_radius(c.position, 34.0, false):
		if o != c and not o.dead:
			o.take_damage(dmg * 0.4, {"source": "tide_red_x", "color": Color("ff7060")})


func food_mult() -> float:
	return 2.0 if tide == "tide_life" else 1.0


# ----------------------------------------------------------------- tick
func tick(delta: float) -> void:
	var p: Player = game.player
	if mode("mode_inverse"):
		game.darkness.extra = maxf(game.darkness.extra, 0.3)
	if tide == "tide_storm":
		_storm_t -= delta
		if _storm_t <= 0.0:
			_storm_t = 2.5
			var best: Creature = null
			for c in game.creatures_in_radius(p.position, 300.0, false):
				if not c.dead and (best == null or c.hp > best.hp):
					best = c
			if best:
				game.zap(best.position + Vector2(randf_range(-20, 20), -160), best.position, Color("fff060"))
				best.take_damage(30.0 * p.st.damage_mult, p.shock_info(false))
				Sfx.play("zap", -6.0)
	if relic("relic_hourglass") and not _hourglass_used and p.alive and p.hp < p.st.max_hp * 0.25:
		_hourglass_used = true
		_slowmo = 3.0
		p.grant_invuln(3.0)
		Engine.time_scale = 0.45
		game.hud.banner("AMPULHETA!", "O tempo desacelera", Color("7ae0ff"))
	if _slowmo > 0.0:
		_slowmo -= delta / maxf(Engine.time_scale, 0.1)
		if _slowmo <= 0.0:
			Engine.time_scale = 1.3 if mode("mode_hyper") else 1.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0
