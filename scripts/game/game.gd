class_name Game
extends Node2D
## Run orchestrator: builds the world, owns entity layers, resolves combat,
## experience, level-ups, the director timeline and end of run.

signal xp_changed
signal level_changed
signal kills_changed
signal pearls_changed
signal boss_changed(boss)

const CreatureScripts := {
	"shrimp": preload("res://scripts/game/creatures/shrimp.gd"),
	"sardine": preload("res://scripts/game/creatures/sardine.gd"),
	"snail": preload("res://scripts/game/creatures/snail.gd"),
	"puffer": preload("res://scripts/game/creatures/puffer.gd"),
	"turtle": preload("res://scripts/game/creatures/turtle.gd"),
	"piranha": preload("res://scripts/game/creatures/piranha.gd"),
	"barracuda": preload("res://scripts/game/creatures/barracuda.gd"),
	"jellyfish": preload("res://scripts/game/creatures/jellyfish.gd"),
	"moray": preload("res://scripts/game/creatures/moray.gd"),
	"shark": preload("res://scripts/game/creatures/shark.gd"),
	"angler": preload("res://scripts/game/creatures/angler.gd"),
	"crab": preload("res://scripts/game/creatures/crab.gd"),
	"squid": preload("res://scripts/game/creatures/squid.gd"),
	"detritivore": preload("res://scripts/game/creatures/detritivore.gd"),
	"urchin": preload("res://scripts/game/creatures/urchin.gd"),
	"otter": preload("res://scripts/game/creatures/otter.gd"),
	"orca": preload("res://scripts/game/creatures/orca.gd"),
	"boss_shark": preload("res://scripts/game/bosses/boss_shark.gd"),
	"boss_kraken": preload("res://scripts/game/bosses/boss_kraken.gd"),
	"boss_angler": preload("res://scripts/game/bosses/boss_angler.gd"),
	"boss_leviathan": preload("res://scripts/game/bosses/boss_leviathan.gd"),
	"boss_titanacon": preload("res://scripts/game/bosses/boss_titanacon.gd"),
	"parasite": preload("res://scripts/game/creatures/parasite.gd"),
	"bobbit": preload("res://scripts/game/creatures/bobbit.gd"),
	"louse": preload("res://scripts/game/creatures/louse.gd"),
}
const MAX_CREATURES := 240
const MAX_PICKUPS := 260

var world: World
var player: Player
var director: Director
var camera: GameCamera
var hud: Hud
var menus: CanvasLayer
var darkness: Darkness

var layer_back: Node2D
var layer_pickups: Node2D
var layer_creatures: Node2D
var layer_player: Node2D
var layer_fx: Node2D
var layer_front: Node2D
var layer_text: Node2D

var grid := SpatialGrid.new()
var creatures: Array = []
var pickups: Array = []
var plankton: Array = []
var detritus: Array = []
var carcasses: Array = []
var ecosystem: Ecosystem
var boss: Creature = null

var time := 0.0
var level := 1
var xp := 0
var xp_next := 7
var kills := 0
var pearls_run := 0
var bosses_killed := 0
var rerolls := 0
var status_points := 0
var pending_levels := 0
var pending_mutation := false
var run_over := false
var won := false
var _menu_open := false
var _hitstop_busy := false
var _dn_budget := 0
# engagement: kill combo, xp chime streak, bestiary discovery
var combo := 0
var best_combo := 0
var _combo_t := 0.0
var _chime_chain := 0
var _chime_t := 0.0
var _seen_t := 0.0
var _boss_evade := 0.0


func _ready() -> void:
	randomize()
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_layers()
	world = World.new()
	world.game = self
	add_child(world)
	move_child(world, 0)
	world.build()
	ecosystem = Ecosystem.new()
	ecosystem.game = self
	add_child(ecosystem)

	player = Player.new()
	player.game = self
	player.position = Vector2(2350.0, 420.0)
	layer_player.add_child(player)
	var sp := Profile.selected_species
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--species=") and DB.SPECIES.has(a.substr(10)):
			sp = a.substr(10)  # debug / screenshots
	player.setup(sp)

	camera = GameCamera.new()
	camera.target = player
	add_child(camera)
	camera.global_position = player.position

	darkness = Darkness.new()
	darkness.game = self
	add_child(darkness)

	hud = Hud.new()
	hud.game = self
	add_child(hud)

	menus = CanvasLayer.new()
	menus.layer = 20
	menus.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(menus)

	director = Director.new()
	director.game = self
	add_child(director)

	rerolls = Profile.upgrade_level("reroll")
	xp_next = DB.xp_to_next(level)
	world.biome_entered.connect(_on_biome_entered)
	Profile.bump("runs_started")
	Sfx.play_music("game")
	director.start()
	if OS.get_cmdline_user_args().has("--autotest"):
		var bot: Node = load("res://scripts/debug/autopilot.gd").new()
		bot.set("game", self)
		add_child(bot)


func _build_layers() -> void:
	var defs := [["Back", -8], ["Pickups", -2], ["Creatures", 0], ["PlayerLayer", 4], ["Fx", 8], ["Front", 14], ["Text", 30]]
	var made := []
	for d in defs:
		var n := Node2D.new()
		n.name = d[0]
		n.z_index = d[1]
		add_child(n)
		made.append(n)
	layer_back = made[0]
	layer_pickups = made[1]
	layer_creatures = made[2]
	layer_player = made[3]
	layer_fx = made[4]
	layer_front = made[5]
	layer_text = made[6]


func _physics_process(delta: float) -> void:
	_dn_budget = 6
	grid.clear()
	var alive := []
	for c in creatures:
		if is_instance_valid(c) and not c.dead:
			grid.insert(c)
			alive.append(c)
	creatures = alive
	if not run_over:
		time += delta
		player.input_dir = hud.move_vector()
		_tick_engagement(delta)
		_music_intensity()


func _unhandled_input(event: InputEvent) -> void:
	if run_over:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P):
		open_pause()
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_J):
		player.try_bite()
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SHIFT or event.keycode == KEY_K):
		player.try_dash()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		open_pause()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if not run_over and not get_tree().paused:
			open_pause()


# ----------------------------------------------------------------- spawning
func spawn_creature(id: String, pos: Vector2, opts := {}) -> Creature:
	if creatures.size() >= MAX_CREATURES and not opts.get("force", false):
		return null
	var def: Dictionary = DB.CREATURES[id]
	var script: GDScript = CreatureScripts[def.script]
	var c: Creature = script.new()
	c.game = self
	c.position = pos
	c.configure(id, def, opts)
	layer_creatures.add_child(c)
	creatures.append(c)
	return c


func spawn_boss(id: String, pos: Vector2) -> Creature:
	var def: Dictionary = DB.BOSSES[id]
	var script: GDScript = CreatureScripts[def.script]
	var b: Creature = script.new()
	b.game = self
	b.position = pos
	b.configure_boss(id, def, director.difficulty())
	layer_creatures.add_child(b)
	creatures.append(b)
	boss = b
	boss_changed.emit(b)
	return b


func spawn_pickup(kind: String, pos: Vector2, value := 1) -> Pickup:
	if kind == "xp" and pickups.size() >= MAX_PICKUPS:
		# merge into an existing orb far from the player instead
		for p in pickups:
			if is_instance_valid(p) and p.kind == "xp" and not p.attracted:
				p.set_value(p.value + value)
				return p
	var p := Pickup.new()
	p.game = self
	p.position = pos
	p.setup(kind, value)
	layer_pickups.add_child(p)
	if p.kind == "plankton":
		plankton.append(p)
	elif kind == "detritus":
		detritus.append(p)
	else:
		pickups.append(p)
	return p


func spawn_projectile(p: Projectile) -> Projectile:
	p.game = self
	layer_fx.add_child(p)
	return p


func spawn_area(a: AreaEffect) -> AreaEffect:
	a.game = self
	layer_fx.add_child(a)
	return a


func fx(sheet: String, pos: Vector2, fps := 16.0, scale_f := 1.0, tint := Color.WHITE, z := 0) -> void:
	var e := OneShotFx.new()
	e.setup(sheet, fps)
	e.position = pos
	e.scale = Vector2(scale_f, scale_f)
	e.modulate = tint
	e.z_index = z
	layer_fx.add_child(e)


func burst(pos: Vector2, kinds: Array, amount := 8, speed := 60.0, life := 0.6) -> void:
	var b := Burst.new()
	b.position = pos
	layer_fx.add_child(b)
	b.emit(kinds, amount, speed, life)


func damage_number(pos: Vector2, amount: float, crit := false, color := Color.WHITE) -> void:
	if not Profile.settings.get("damage_numbers", true):
		return
	if _dn_budget <= 0 and not crit:
		return
	_dn_budget -= 1
	var d := DamageNumber.new()
	d.setup(amount, crit, color)
	d.position = pos + Vector2(randf_range(-4, 4), 0)
	layer_text.add_child(d)


func float_text(pos: Vector2, text: String, color := Color.WHITE, size := 8) -> void:
	var d := DamageNumber.new()
	d.setup_text(text, color, size)
	d.position = pos
	layer_text.add_child(d)


func zap(from: Vector2, to: Vector2, color := Color("fff060")) -> void:
	var z := ZapFx.new()
	z.setup(from, to, color)
	layer_fx.add_child(z)


func shake(amount: float) -> void:
	if Profile.settings.get("shake", true):
		camera.add_shake(amount)


func hitstop(duration := 0.04) -> void:
	if _hitstop_busy:
		return
	_hitstop_busy = true
	var prev := Engine.time_scale
	Engine.time_scale = prev * 0.08
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = prev
	_hitstop_busy = false


# ------------------------------------------------------------------ queries
func creatures_in_radius(pos: Vector2, r: float, include_herb := true) -> Array:
	var res := grid.query(pos, r)
	if include_herb:
		return res
	return res.filter(func(c): return c.faction != "herb" or c.provoked)


func nearest_creature(pos: Vector2, max_r: float, prefer_hostile := true) -> Creature:
	var best: Creature = null
	var best_d := INF
	for c in grid.query(pos, max_r):
		if c.dead:
			continue
		var d: float = c.position.distance_squared_to(pos)
		if prefer_hostile and (c.faction == "herb" or c.faction == "gold") and not c.provoked:
			d *= 3.0
		if d < best_d:
			best_d = d
			best = c
	return best


func nearest_n(pos: Vector2, n: int, max_r: float) -> Array:
	var list := grid.query(pos, max_r).filter(func(c): return not c.dead)
	list.sort_custom(func(a, b): return a.position.distance_squared_to(pos) < b.position.distance_squared_to(pos))
	return list.slice(0, n)


func visible_rect() -> Rect2:
	var vs := get_viewport_rect().size / camera.zoom
	return Rect2(camera.get_screen_center_position() - vs * 0.5, vs)


func roll_damage(base: float) -> Array:
	var st: Dictionary = player.st
	var dmg: float = base * st.damage_mult
	var crit: bool = randf() < st.crit_chance
	if crit:
		dmg *= st.crit_mult
	return [dmg * randf_range(0.92, 1.08), crit]


# ------------------------------------------------------------------- events
func on_creature_killed(c: Creature, info: Dictionary) -> void:
	# --- deaths inside the food web (no rewards, but they feed the cycle)
	if info.get("eaten", false):
		burst(c.position, [2, 0], 4, 30.0, 0.4)
		ecosystem.stats.eaten += 1
		if c.tier >= 2:
			ecosystem.spawn_carcass(c.position, c.tier * 2 - 1)
		else:
			ecosystem.spawn_detritus(c.position)
		return
	if info.get("starved", false):
		ecosystem.spawn_carcass(c.position, maxi(1, (c.tier + 1) * 2))
		return
	kills += 1
	kills_changed.emit()
	Profile.bump("kills")
	Profile.bestiary_kill(c.id)
	_add_combo()
	if not info.get("swallow", false) and c.tier >= 2 and not c.is_boss and (not c.is_wave or randf() < 0.3):
		ecosystem.spawn_carcass(c.position, c.tier * 2)
	if c.elite and not c.is_boss:
		spawn_pickup("scale", c.position, 1)
		Profile.bump("alphas")
		float_text(c.position + Vector2(0, -20), "ALFA ABATIDO!", Color("ffbf45"), 16)
		shake(3.0)
	var pos := c.position
	var xp_value: int = c.xp
	if info.get("swallow", false):
		xp_value = int(ceil(xp_value * 1.5))
	if xp_value > 0:
		_drop_xp(pos, xp_value)
	var pearl_chance: float = c.pearl_chance * (1.0 + player.st.luck)
	if randf() < pearl_chance:
		spawn_pickup("pearl", pos, 1 + (1 if c.elite else 0))
	if c.faction == "pred" and randf() < 0.035 + (0.1 if c.elite else 0.0):
		spawn_pickup("food", pos, 18)
	if c.elite and randf() < 0.25:
		spawn_pickup("magnet", pos, 1)
	# synergy hooks
	player.on_kill(c, info)
	if player.flags.get("toxic_explode", false) and c.poison_t > 0.0:
		var a := AreaEffect.new()
		a.setup_cloud("fx/poison_cloud", pos, 24.0 * player.st.area_mult, 1.8, 6.0 * player.st.poison_mult, 0.0, true)
		spawn_area(a)
		fx("fx/explosion_toxic", pos, 18.0)
	# visuals
	var kinds := [2, 2, 0, 1] if c.faction != "hazard" else [6, 0, 1]
	burst(pos, kinds, 6 + int(c.radius * 0.6), 50.0 + c.radius * 3.0)
	if c.is_boss:
		_on_boss_killed(c)


func _drop_xp(pos: Vector2, value: int) -> void:
	var remaining := value
	var pieces := 0
	while remaining > 0 and pieces < 4:
		var v := remaining
		if remaining > 40 and pieces < 3:
			v = int(remaining / 2.0)
		spawn_pickup("xp", pos + Vector2(randf_range(-6, 6), randf_range(-6, 6)), v)
		remaining -= v
		pieces += 1


func _on_boss_killed(b: Creature) -> void:
	bosses_killed += 1
	Profile.bump("boss_" + b.boss_id)
	var new_species := Profile.unlock_boss_species(b.boss_id)
	if new_species != "":
		_announce_species.call_deferred(new_species)
	boss = null
	boss_changed.emit(null)
	Sfx.play("boss_die")
	Sfx.play_music("game")
	Sfx.play_stinger("victory", -2.0)
	shake(10.0)
	hitstop(0.25)
	var def: Dictionary = DB.BOSSES[b.boss_id]
	for i in 8:
		var p := b.position + Vector2(randf_range(-40, 40), randf_range(-30, 30))
		fx("fx/explosion", p, 14.0, randf_range(1.0, 2.0))
	var pearls: int = int(def.pearls)
	for i in mini(pearls, 12):
		spawn_pickup("pearl", b.position + Vector2(randf_range(-30, 30), randf_range(-20, 20)), maxi(1, pearls / 12))
	spawn_pickup("magnet", b.position, 1)
	player.heal(player.st.max_hp * 0.3)
	director.on_boss_killed()
	world.spawn_boss_chest(b.position)


# ------------------------------------------------------------ Titanacon
var stomach: Stomach = null


func swallow_player(b: Creature) -> void:
	if stomach != null or not player.alive:
		return
	# the stomach is part of the titan: it keeps swimming with you inside
	stomach = Stomach.new()
	stomach.game = self
	stomach.boss = b
	b.add_child(stomach)
	b.stomach = stomach
	player.swallowed = true
	player.container = stomach
	player.position = stomach.to_world(Vector2(stomach.RADII.x * 0.6, 0))
	player.vel = Vector2(-80.0 * b.facing, 0)
	player.grant_invuln(1.0)
	darkness.extra = 0.22
	darkness.tint_target = Color(0.14, 0.0, 0.03)
	hud.banner("ENGOLIDO!", "Destrua os órgãos vitais por dentro", Color("ff5c4c"))
	Sfx.play("boss_roar")
	shake(10.0)
	hitstop(0.2)
	Profile.bump("swallowed")


func spit_player(b: Creature, boss_died := false) -> void:
	if stomach == null:
		return
	player.swallowed = false
	player.container = null
	player.is_hidden = false
	var dir := Vector2(b.facing, -0.25).normalized()
	var out: Vector2 = b.mouth_pos() + dir * 70.0
	out.x = clampf(out.x, 40.0, DB.WORLD_W - 40.0)
	out.y = clampf(out.y, DB.SURFACE_Y + 30.0, DB.floor_at(out.x) - 30.0)
	player.position = out
	player.vel = dir * 340.0
	player.grant_invuln(1.6)
	stomach.teardown()
	stomach = null
	b.stomach = null
	darkness.extra = 0.15
	darkness.tint_target = Color(0.06, 0.0, 0.08)
	burst(out, [2, 6, 0], 18, 120.0, 0.8)
	if not boss_died:
		Sfx.play("hit")


func stomach_ratio() -> float:
	if stomach == null or not is_instance_valid(stomach.boss):
		return 0.0
	return stomach.boss.stomach_ratio()


func _announce_species(sp: String) -> void:
	await get_tree().create_timer(2.2, false).timeout
	hud.banner("NOVA ESPÉCIE!", "%s agora é jogável" % DB.SPECIES[sp].name, Color("ffbf45"))
	Sfx.play("evolve")


func add_xp(amount: int) -> void:
	if run_over:
		return
	xp += int(ceil(amount * player.st.xp_mult * combo_mult()))
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = DB.xp_to_next(level)
		pending_levels += 1
		status_points += 1
		var new_stage := DB.stage_for_level(level)
		if new_stage > player.stage:
			pending_mutation = true
	xp_changed.emit()
	if pending_levels > 0 and not _menu_open:
		_process_pending()


var _xp_frac := 0.0


## Small foods (plankton, kelp, carrion) give fractional XP.
func add_xp_f(amount: float) -> void:
	_xp_frac += amount
	if _xp_frac >= 1.0:
		var whole := int(_xp_frac)
		_xp_frac -= whole
		add_xp(whole)


func add_pearls(n: int) -> void:
	var gained := int(round(n * player.st.pearl_mult))
	pearls_run += maxi(1, gained)
	pearls_changed.emit()


func _process_pending() -> void:
	if run_over:
		return
	if pending_levels > 0:
		pending_levels -= 1
		level_changed.emit()
		Sfx.play_stinger("levelup", -3.0)
		fx("fx/hit_spark", player.position, 12.0, 3.0, Color("5ee0ff"))
		_level_shockwave()
		_open_cards("level")
	elif pending_mutation:
		pending_mutation = false
		var new_stage := DB.stage_for_level(level)
		player.grow_to(new_stage)
		Profile.set_max("max_stage", new_stage)
		if player.free_mutation_slots().size() > 0:
			_open_cards("mutation")


func _open_cards(mode: String, extra := {}) -> void:
	_menu_open = true
	hud.visible = false
	get_tree().paused = true
	var p := CardPanel.new()
	p.game = self
	menus.add_child(p)
	p.open(mode, extra)
	p.closed.connect(_on_menu_closed)


func open_treasure(guarantee_evolution := false) -> void:
	if _menu_open:
		return
	_menu_open = true
	hud.visible = false
	get_tree().paused = true
	var c := ChestPanel.new()
	c.game = self
	menus.add_child(c)
	c.closed.connect(_on_menu_closed)
	c.open(guarantee_evolution)


func _on_menu_closed() -> void:
	_menu_open = false
	hud.visible = true
	get_tree().paused = false
	if pending_levels > 0 or pending_mutation:
		_process_pending()


func open_pause() -> void:
	if _menu_open or run_over:
		return
	_menu_open = true
	hud.visible = false
	get_tree().paused = true
	var p := PauseMenu.new()
	p.game = self
	menus.add_child(p)
	p.closed.connect(_on_menu_closed)


## Adaptive music: the drive layer follows how dangerous and hot the run is.
func _music_intensity() -> void:
	var k := 0.0
	match director.phase:
		"wave":
			k = 1.0
		"rest":
			k = 0.35
		_:
			k = clampf(combo / 45.0, 0.0, 0.55)
			var near := 0
			for c in grid.query(player.position, 170.0):
				if c.hostile_now() and not c.dead:
					near += 1
			k = maxf(k, clampf(near / 6.0, 0.0, 0.7))
			if player.buffs.has("frenzy"):
				k = 1.0
	Sfx.intensity = k


func on_player_died() -> void:
	if run_over:
		return
	run_over = true
	Sfx.play("death")
	Sfx.play_music("")
	Sfx.play_stinger("defeat")
	Engine.time_scale = 0.35
	await get_tree().create_timer(0.9, true, false, true).timeout
	Engine.time_scale = 1.0
	_end_run(false)


func on_victory() -> void:
	if run_over:
		return
	won = true
	run_over = true
	await get_tree().create_timer(1.6, true, false, true).timeout
	_end_run(true)


func _end_run(victory: bool) -> void:
	get_tree().paused = true
	_menu_open = true
	hud.visible = false
	hud.controls.release_all()
	var g := GameOverMenu.new()
	g.game = self
	menus.add_child(g)
	if victory and not director.endless:
		g.show_victory_choice()
	else:
		g.show_result(finalize_run(won))


var _finalized := false


## Converts the run into pearls/records. Safe to call once.
func finalize_run(victory: bool) -> Dictionary:
	var bonus := int(time / 30.0) + level + bosses_killed * 10 + (50 if victory else 0)
	var result := {
		"won": victory, "time": time, "level": level, "kills": kills, "bosses": bosses_killed,
		"cycle": director.cycle, "pearls": pearls_run, "bonus": bonus, "stage": player.stage,
	}
	if not _finalized:
		_finalized = true
		Profile.set_max("max_time", int(time))
		Profile.set_max("max_combo", best_combo)
		Profile.add_pearls(pearls_run + bonus)
		Profile.record_run(result)
	return result


func continue_endless() -> void:
	hud.visible = true
	director.endless = true
	run_over = false
	_menu_open = false
	get_tree().paused = false
	director.next_cycle()


func revive_player() -> void:
	run_over = false
	_menu_open = false
	get_tree().paused = false
	player.revive()
	for c in creatures_in_radius(player.position, 140.0):
		if not c.is_boss:
			c.take_damage(9999.0, {"source": "revive"})
	fx("fx/explosion", player.position, 12.0, 3.0, Color("5ee0ff"))


func quit_to_menu() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func restart() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()


# ------------------------------------------------------------- engagement
func _tick_engagement(delta: float) -> void:
	if combo > 0:
		_combo_t -= delta
		if _combo_t <= 0.0:
			combo = 0
	_chime_t -= delta
	if _chime_t <= 0.0:
		_chime_chain = 0
	_seen_t -= delta
	if _seen_t <= 0.0:
		_seen_t = 0.5
		_discover_species()
	_boss_evasion(delta)


## XP chime whose pitch climbs while you keep collecting (Vampire-Survivors feel).
func pickup_chime(vol := -8.0) -> void:
	_chime_chain = mini(_chime_chain + 1, 30)
	_chime_t = 0.45
	Sfx.play_pitched("pickup", 0.9 + _chime_chain * 0.035, vol)


func _add_combo() -> void:
	combo += 1
	_combo_t = 2.6
	if combo > best_combo:
		best_combo = combo
	if DB.COMBO_MILESTONES.has(combo):
		var label: String = DB.COMBO_MILESTONES[combo]
		hud.combo_milestone(combo, label)
		Sfx.play("level_up", -4.0)
		add_pearls(1 + combo / 25)
		Profile.set_max("max_combo", combo)
		if combo >= 50:
			player.add_buff("frenzy", 8.0)
			player.heal(player.st.max_hp * 0.1)


func combo_mult() -> float:
	return 1.0 + minf(combo, 100) * 0.003


func _level_shockwave() -> void:
	var ring := RingFx.new().setup(120.0, 0.4, Color("5ee0ff"), 4.0)
	ring.position = player.position
	layer_fx.add_child(ring)
	for c in creatures_in_radius(player.position, 120.0, false):
		if not c.is_boss:
			c.knock += (c.position - player.position).normalized() * 260.0
			c.take_damage(8.0 + level, {"source": "levelup"})
	player.grant_invuln(0.4)


func _discover_species() -> void:
	var rect := visible_rect()
	for c in creatures:
		if is_instance_valid(c) and not c.is_boss and c.id != "" and rect.has_point(c.position):
			if Profile.bestiary_see(c.id):
				hud.toast("Nova espécie: %s!" % DB.CREATURES[c.id].name, Color("a4dc4c"))
				Sfx.play("pearl", -4.0)


func _on_biome_entered(b: Dictionary) -> void:
	hud.biome_label(b.name)
	if b.id == "abyss":
		Profile.set_max("reach_abyss", 1)


## Everything-is-Crab style: stay hidden long enough and the boss gives up,
## leaving its food behind (mutation reward) but no meat/XP.
func _boss_evasion(delta: float) -> void:
	if boss == null or not is_instance_valid(boss) or boss.dead:
		_boss_evade = 0.0
		return
	if player.is_hidden and not player.swallowed:
		_boss_evade += delta
		if _boss_evade >= 12.0 and boss.has_method("give_up"):
			boss.give_up()
			_boss_evade = 0.0
	else:
		_boss_evade = maxf(0.0, _boss_evade - delta * 0.25)


func boss_evade_ratio() -> float:
	return clampf(_boss_evade / 12.0, 0.0, 1.0)


func on_boss_gave_up(b: Creature) -> void:
	boss = null
	boss_changed.emit(null)
	Profile.bump("boss_evaded")
	hud.banner("O CHEFE DESISTIU!", "Você sobreviveu escondido", Color("a4dc4c"))
	spawn_pickup("boss_food", Vector2(b.position.x, clampf(b.position.y, 60, DB.floor_at(b.position.x) - 30)), 1)
	director.on_boss_killed()
