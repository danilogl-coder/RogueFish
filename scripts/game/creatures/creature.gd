class_name Creature
extends Node2D
## Base for every living thing in the ocean (ecosystem creatures and bosses).
## Subclasses implement think(delta) and may override hooks.

var game
var id := ""
var def: Dictionary = {}
var tier := 0
var max_hp := 10.0
var hp := 10.0
var speed := 50.0
var radius := 6.0
var contact_damage := 0.0
var xp := 1
var faction := "herb"
var pearl_chance := 0.0
var is_boss := false
var boss_id := ""
var is_wave := false
var elite := false
var provoked := false
var swallowable := true
var armor_mult := 1.0
var light_radius := 0.0
var dmg_mult := 1.0

var vel := Vector2.ZERO
var knock := Vector2.ZERO
var facing := 1.0
var sprite: Sprite2D
var anim_t := 0.0
var anim_fps := 8.0
var attack_anim := 0.0
var state := "idle"
var state_t := 0.0
var home := Vector2.ZERO
var wander_dir := Vector2.RIGHT
var wander_t := 0.0
var y_min := 40.0
var y_max := 900.0
var on_floor := false

var poison_t := 0.0
var poison_dps := 0.0
var bleed_t := 0.0
var bleed_dps := 0.0
var slow_t := 0.0
var slow_amt := 0.0
var stun_t := 0.0
var mark_t := 0.0
var flash_t := 0.0
var hp_bar_t := 0.0
var dead := false
var hit_cd: Dictionary = {}
var _dot_tick := 0.0
var _sep_frame := 0
var _contact_cd := 0.0
var _last_flash := 0


func configure(p_id: String, p_def: Dictionary, opts := {}) -> void:
	id = p_id
	def = p_def
	tier = int(def.tier)
	var diff: Dictionary = game.director.difficulty() if game and game.director else {"hp": 1.0, "dmg": 1.0}
	max_hp = float(def.hp) * float(diff.hp)
	speed = float(def.speed)
	radius = float(def.radius)
	contact_damage = float(def.dmg)
	dmg_mult = float(diff.dmg)
	xp = int(def.xp)
	faction = def.faction
	pearl_chance = float(def.get("pearl", 0.0))
	light_radius = float(def.get("light", 0.0))
	is_wave = opts.get("wave", false)
	elite = opts.get("elite", false)
	if elite:
		max_hp *= 4.0
		xp *= 4
		radius *= 1.3
		pearl_chance = maxf(pearl_chance, 0.5)
		scale = Vector2(1.3, 1.3)
	hp = max_hp
	var depth: Array = def.get("depth", [0.1, 0.9])
	y_min = maxf(DB.SURFACE_Y + 20.0, float(depth[0]) * DB.FLOOR_Y)
	y_max = minf(DB.FLOOR_Y - radius, float(depth[1]) * DB.FLOOR_Y)
	on_floor = float(depth[0]) >= 1.0
	home = position
	wander_dir = Vector2.from_angle(randf() * TAU)
	sprite = Art.sprite("creatures/" + def.sheet)
	add_child(sprite)
	if elite:
		sprite.modulate = Color(1.25, 1.0, 0.75)
	anim_t = randf() * 2.0
	_setup()


func configure_boss(p_id: String, p_def: Dictionary, diff: Dictionary) -> void:
	id = p_id
	boss_id = p_id
	def = p_def
	is_boss = true
	swallowable = false
	tier = 9
	max_hp = float(def.hp) * float(diff.boss_hp)
	hp = max_hp
	contact_damage = float(def.dmg)
	dmg_mult = float(diff.dmg)
	xp = int(def.xp)
	faction = "boss"
	radius = 30.0
	y_min = 60.0
	y_max = DB.FLOOR_Y - 30.0
	_setup()


## Override for per-type initialisation.
func _setup() -> void:
	pass


## Override: AI step. Should set vel.
func think(_delta: float) -> void:
	wander(_delta, speed * 0.5)


func hostile_now() -> bool:
	return faction == "pred" or faction == "hazard" or faction == "boss" or provoked


func light_pos() -> Vector2:
	return global_position


# --------------------------------------------------------------------- loop
func _physics_process(delta: float) -> void:
	if dead:
		return
	_tick_status(delta)
	if dead:
		return
	state_t += delta
	if stun_t > 0.0:
		stun_t -= delta
		vel *= pow(0.02, delta)
	else:
		think(delta)
	var slow := 1.0 - slow_amt if slow_t > 0.0 else 1.0
	position += (vel * slow + knock) * delta
	knock *= pow(0.004, delta)
	_separate()
	_clamp()
	_animate(delta)
	_contact(delta)
	if hp_bar_t > 0.0 or flash_t > 0.0:
		queue_redraw()


func _tick_status(delta: float) -> void:
	flash_t -= delta
	hp_bar_t -= delta
	slow_t -= delta
	mark_t -= delta
	_contact_cd -= delta
	if poison_t > 0.0 or bleed_t > 0.0:
		poison_t -= delta
		bleed_t -= delta
		_dot_tick -= delta
		if _dot_tick <= 0.0:
			_dot_tick = 0.5
			var dot := 0.0
			if poison_t > 0.0:
				dot += poison_dps * 0.5
			if bleed_t > 0.0:
				dot += bleed_dps * 0.5
			if dot > 0.0:
				take_damage(dot, {"dot": true, "color": Color("a4dc4c") if poison_t > 0.0 else Color("ff5c4c")})
	var tint := Color.WHITE
	if elite:
		tint = Color(1.25, 1.0, 0.75)
	if poison_t > 0.0:
		tint *= Color(0.75, 1.0, 0.7)
	if slow_t > 0.0:
		tint *= Color(0.7, 0.85, 1.1)
	if stun_t > 0.0:
		tint *= Color(1.2, 1.2, 0.7)
	if flash_t > 0.0:
		tint = Color(2.2, 2.2, 2.2) if is_boss else Color(6, 6, 6)
	if sprite:
		sprite.modulate = tint


func _separate() -> void:
	_sep_frame += 1
	if (_sep_frame + get_instance_id()) % 3 != 0 or is_boss:
		return
	for o in game.grid.query(position, radius, 20.0):
		if o == self or o.is_boss:
			continue
		var d: Vector2 = position - o.position
		var l := d.length()
		var min_d: float = radius + o.radius
		if l < min_d and l > 0.01:
			position += d / l * (min_d - l) * 0.35


func _clamp() -> void:
	position.x = clampf(position.x, radius, DB.WORLD_W - radius)
	var bottom := DB.FLOOR_Y - (radius * 0.6 if on_floor else radius)
	position.y = clampf(position.y, DB.SURFACE_Y + radius, bottom)


func _animate(delta: float) -> void:
	if absf(vel.x) > 4.0:
		facing = signf(vel.x)
	if sprite:
		sprite.flip_h = facing < 0.0
	anim_t += delta
	var n: int = sprite.hframes if sprite else 1
	if attack_anim > 0.0 and n >= 6:
		attack_anim -= delta
		sprite.frame = 4 if attack_anim > 0.1 else 5
	elif sprite and n > 1:
		var fps := anim_fps * clampf(0.6 + vel.length() / maxf(speed, 1.0), 0.6, 2.0)
		sprite.frame = int(anim_t * fps) % mini(4, n)


func _contact(_delta: float) -> void:
	if not hostile_now() or contact_damage <= 0.0 or _contact_cd > 0.0:
		return
	var p: Player = game.player
	if not p.alive:
		return
	var lim := radius + p.radius
	if position.distance_squared_to(p.position) <= lim * lim:
		_contact_cd = 0.5
		on_touch_player(p)


## Default touch: damage the player.
func on_touch_player(p: Player) -> void:
	p.take_damage(contact_damage * dmg_mult, self)
	attack_anim = 0.2


func _draw() -> void:
	if hp_bar_t > 0.0 and not is_boss and hp < max_hp:
		var w := clampf(radius * 2.2, 12.0, 34.0)
		var y := -radius - 7.0
		draw_rect(Rect2(-w * 0.5 - 1, y - 1, w + 2, 4), Color(0.02, 0.04, 0.08, 0.85))
		draw_rect(Rect2(-w * 0.5, y, w * clampf(hp / max_hp, 0.0, 1.0), 2), Color("ff5c4c") if hostile_now() else Color("a4dc4c"))


# ------------------------------------------------------------------ combat
func take_damage(amount: float, info := {}) -> float:
	if dead:
		return 0.0
	var dmg := amount * armor_mult
	if mark_t > 0.0:
		dmg *= 1.25
	hp -= dmg
	var now := Time.get_ticks_msec()
	if now - _last_flash > 140:
		_last_flash = now
		flash_t = 0.06
	hp_bar_t = 2.5
	var col: Color = info.get("color", Color.WHITE)
	if not info.get("dot", false) or randf() < 0.5:
		game.damage_number(position + Vector2(0, -radius - 4), dmg, info.get("crit", false), col)
	if info.has("knockback") and not is_boss:
		knock += info.knockback / (1.0 + radius * 0.08)
	if info.get("poison", 0.0) > 0.0:
		apply_poison(info.poison, info.get("poison_time", 3.0))
	if info.get("bleed", 0.0) > 0.0:
		bleed_dps = maxf(bleed_dps, info.bleed)
		bleed_t = 3.0
	if info.get("slow", 0.0) > 0.0:
		slow_amt = maxf(slow_amt if slow_t > 0.0 else 0.0, info.slow)
		slow_t = maxf(slow_t, info.get("slow_time", 1.0))
	if info.get("stun", 0.0) > 0.0 and not is_boss:
		stun_t = maxf(stun_t, info.stun)
	if info.get("mark", 0.0) > 0.0:
		mark_t = info.mark
	if faction == "herb" and info.get("source", "") != "":
		provoked = true
	if hp <= 0.0:
		die(info)
	else:
		on_hurt(info)
	return dmg


func apply_poison(dps: float, duration: float) -> void:
	poison_dps = maxf(poison_dps if poison_t > 0.0 else 0.0, dps)
	poison_t = maxf(poison_t, duration)


## Hook for reacting to damage (flee, inflate, enrage...).
func on_hurt(_info: Dictionary) -> void:
	pass


## Can this weapon source hit now? Used by persistent hitters (orbits, auras).
func can_hit(source: String, cooldown: float) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(hit_cd.get(source, 0.0)):
		return false
	hit_cd[source] = now + cooldown
	return true


func swallow() -> void:
	die({"swallow": true, "source": "bite"})


func die(info := {}) -> void:
	if dead:
		return
	dead = true
	game.on_creature_killed(self, info)
	on_death()
	queue_free()


func on_death() -> void:
	pass


# ------------------------------------------------------------- steering
func steer(desired: Vector2, accel: float, delta: float) -> void:
	vel = vel.move_toward(desired, accel * delta)


func seek(target_pos: Vector2, spd: float, accel: float, delta: float) -> void:
	steer((target_pos - position).normalized() * spd, accel, delta)


func flee(from_pos: Vector2, spd: float, accel: float, delta: float) -> void:
	var away := position - from_pos
	if away.length_squared() < 0.01:
		away = Vector2.RIGHT
	steer(away.normalized() * spd, accel, delta)


func wander(delta: float, spd: float) -> void:
	wander_t -= delta
	if wander_t <= 0.0:
		wander_t = randf_range(1.5, 3.5)
		wander_dir = Vector2.from_angle(randf_range(-0.6, 0.6) + (0.0 if randf() < 0.5 else PI))
	# stay in depth band
	if position.y < y_min:
		wander_dir.y = absf(wander_dir.y) + 0.3
	elif position.y > y_max:
		wander_dir.y = -absf(wander_dir.y) - 0.3
	if position.x < 60:
		wander_dir.x = absf(wander_dir.x) + 0.3
	elif position.x > DB.WORLD_W - 60:
		wander_dir.x = -absf(wander_dir.x) - 0.3
	steer(wander_dir.normalized() * spd, 120.0, delta)


func player_dist() -> float:
	return position.distance_to(game.player.position)


func player_visible(range_px: float) -> bool:
	var p: Player = game.player
	if not p.alive:
		return false
	if p.is_hidden and not is_boss:
		return false
	return position.distance_squared_to(p.position) < range_px * range_px


## Should this predator avoid the (now much bigger) player?
func fears_player() -> bool:
	if is_wave or is_boss or provoked:
		return false
	return game.player.stage > tier + 1


## Closest prey among herbivores smaller than us (ecosystem hunting).
func find_prey(range_px: float) -> Creature:
	var best: Creature = null
	var bd := range_px * range_px
	for c in game.grid.query(position, range_px):
		if c == self or c.dead or c.faction != "herb" or c.tier >= tier:
			continue
		var d: float = c.position.distance_squared_to(position)
		if d < bd:
			bd = d
			best = c
	return best


## Nearest bigger threat (predators or the player when larger).
func find_threat(range_px: float) -> Vector2:
	var p: Player = game.player
	if p.alive and not p.is_hidden and p.stage >= tier and position.distance_squared_to(p.position) < range_px * range_px:
		return p.position
	for c in game.grid.query(position, range_px):
		if c != self and not c.dead and (c.faction == "pred" or c.faction == "boss") and c.tier > tier:
			return c.position
	return Vector2.INF
