class_name Infestation
extends Node2D
## A colony of fish lice (Cymothoa-like) living inside the player.
##
## Biology the game follows:
##  * every louse enters through the gills as a MALE;
##  * with two or more males and no female, one male slowly turns into a
##    FEMALE (protandric hermaphrodite) - unless a real female arrives first;
##  * a female plus a male mate: she broods eggs in her pouch, the eggs hatch
##    into new males and the colony grows;
##  * a parasite needs a living host: the colony heals a dying host and, if it
##    must, sacrifices part of itself to keep them alive;
##  * cleaner shrimp eat parasites (eating shrimp cleans you).
##
## Gameplay: the colony slows you and eats part of your XP, but it keeps you
## alive, and when it grows full it bursts out of you as a swarm that
## infests (and eats) nearby enemies. Clean it or farm it: your call.

const MAX_COLONY := 24
const MORPH_TIME := 9.0        ## male -> female, when there is no female
const BROOD_TIME := 6.5        ## female + male: a brood every N seconds
const HATCH_TIME := 4.0
const SAVE_MIN := 4            ## lice needed to pull the host back from death

var game
var player
## Lice: {sex: "m"/"f", pos: Vector2 in [-1, 1] body space, dir, born: float}
var lice: Array = []
## Eggs: {t: time to hatch, pos}
var eggs: Array = []
var morph := 0.0               # progress of a male turning female (0..1)
var brood := 0.0               # progress of the next brood (0..1)
var total_born := 0
var _t := 0.0
var _heal_acc := 0.0
var _events: Array = []        # recent visual events for the x-ray panel: {kind, pos, t}


func count() -> int:
	return lice.size()


func males() -> int:
	return lice.filter(func(l): return l.sex == "m").size()


func females() -> int:
	return lice.filter(func(l): return l.sex == "f").size()


func full() -> bool:
	return lice.size() + eggs.size() >= MAX_COLONY


func active() -> bool:
	return not lice.is_empty() or not eggs.is_empty()


## A louse enters the host (from `from`, world position).
func add(sex: String, from: Vector2, msg: String) -> void:
	if full() or (player.traits and player.traits.parasite_immune()):
		return
	var was_empty := lice.is_empty()
	lice.append(_new_louse(sex))
	_event("enter", lice[-1].pos)
	game.burst(from, [2, 6], 4, 30.0, 0.4)
	Sfx.play("hurt", -10.0)
	if was_empty:
		game.hud.banner("INFESTADO!", "Um piolho-do-mar entrou pelas brânquias", Color("e89aa8"))
		Profile.bump("infested")
	elif sex == "f":
		game.hud.toast("Uma FÊMEA entrou! A colônia vai cruzar", Color("ff8ab0"))
	elif msg != "":
		game.hud.toast(msg, Color("e89aa8"))
	player.recalc()


func _new_louse(sex: String) -> Dictionary:
	var a := randf() * TAU
	return {"sex": sex, "pos": Vector2(cos(a), sin(a)) * randf_range(0.2, 0.8), "dir": Vector2.from_angle(randf() * TAU), "born": _t}


func _event(kind: String, pos: Vector2) -> void:
	_events.append({"kind": kind, "pos": pos, "t": 0.0})
	if _events.size() > 16:
		_events.pop_front()


func events() -> Array:
	return _events


# ------------------------------------------------------------------ tick
func _physics_process(delta: float) -> void:
	_t += delta
	for e in _events:
		e.t += delta
	_events = _events.filter(func(e): return e.t < 0.8)
	if not active() or not player.alive:
		queue_redraw()
		return
	# lice crawl around inside the body
	for l in lice:
		l.dir = l.dir.rotated(randf_range(-3.0, 3.0) * delta)
		l.pos += l.dir * delta * (0.25 if l.sex == "m" else 0.08)
		if l.pos.length() > 0.9:
			l.pos = l.pos.normalized() * 0.9
			l.dir = -l.dir
	var m: int = males()
	var f: int = females()
	# protandry: with no female, a male turns into one
	if f == 0 and m >= 2:
		morph += delta / MORPH_TIME
		if morph >= 1.0:
			morph = 0.0
			for l in lice:
				if l.sex == "m":
					l.sex = "f"
					_event("morph", l.pos)
					break
			game.hud.toast("Um macho virou FÊMEA dentro de você!", Color("ff8ab0"))
	else:
		morph = maxf(0.0, morph - delta * 0.2)
	# mating: each female with a male broods eggs
	if f > 0 and m > 0 and not full():
		brood += delta * (1.0 + 0.35 * (mini(f, m) - 1)) / BROOD_TIME
		if brood >= 1.0:
			brood = 0.0
			var mom: Dictionary = lice.filter(func(l): return l.sex == "f").pick_random()
			var n := randi_range(2, 4)
			for i in n:
				if full():
					break
				eggs.append({"t": HATCH_TIME * randf_range(0.8, 1.2), "pos": (mom.pos + Vector2(randf_range(-0.4, 0.4), randf_range(0.2, 0.5))).limit_length(0.95)})
			_event("brood", mom.pos)
	# eggs hatch into males
	var hatched := 0
	for e in eggs:
		e.t -= delta
	for e in eggs.filter(func(e): return e.t <= 0.0):
		eggs.erase(e)
		var nl: Dictionary = _new_louse("m")
		nl.pos = e.pos
		lice.append(nl)
		_event("hatch", e.pos)
		hatched += 1
	if hatched > 0:
		total_born += hatched
		Profile.set_max("max_colony", lice.size())
		player.recalc()
	# a parasite wants a LIVING host: the colony patches up a dying one
	if player.hp < player.st.max_hp * 0.3 and lice.size() >= 3:
		_heal_acc += delta * minf(3.0, lice.size() / 4.0)
		if _heal_acc >= 1.0:
			var amt := floorf(_heal_acc)
			_heal_acc -= amt
			player.heal(amt, false)
	# a full colony bursts out as a swarm
	if lice.size() >= MAX_COLONY:
		swarm()
	queue_redraw()


## Called by the player instead of dying. Returns true if the colony saved them.
func save_host() -> bool:
	if lice.size() < SAVE_MIN:
		return false
	var lost: int = int(ceil(lice.size() * 0.5))
	_remove(lost, true)
	player.hp = player.st.max_hp * 0.35
	player.grant_invuln(2.0)
	player.hp_changed.emit()
	game.float_text(player.position + Vector2(0, -22), "A COLÔNIA TE MANTÉM VIVO!", Color("ff8ab0"), 12)
	game.burst(player.position, [6, 2], 14, 70.0, 0.7)
	Sfx.play("evolve", -4.0)
	player.recalc()
	return true


## Cleaner shrimp eaten: removes parasites (eggs first, then males, the female last).
func clean(n: int) -> void:
	if not active():
		return
	var removed := 0
	while removed < n and not eggs.is_empty():
		eggs.pop_back()
		removed += 1
	if removed < n:
		removed += _remove(n - removed, false)
	game.float_text(player.position + Vector2(0, -18), tr("LIMPEZA -%d") % removed, Color("7ae0ff"), 10)
	if not active():
		morph = 0.0
		brood = 0.0
		game.hud.toast("Colônia eliminada! Você está limpo", Color("7ae0ff"))
	player.recalc()


func _remove(n: int, any_sex: bool) -> int:
	var removed := 0
	for pass_sex in (["m", "f"] if not any_sex else ["m", "f"]):
		for l in lice.duplicate():
			if removed >= n:
				return removed
			if l.sex == pass_sex:
				lice.erase(l)
				_event("die", l.pos)
				removed += 1
	return removed


## The colony overflows: all but one couple burst out of the host and go
## infest the nearest enemies, eating them from the inside.
func swarm() -> void:
	var keep_f := false
	var keep_m := false
	var out := 0
	for l in lice.duplicate():
		if l.sex == "f" and not keep_f:
			keep_f = true
			continue
		if l.sex == "m" and not keep_m:
			keep_m = true
			continue
		lice.erase(l)
		var s := SwarmLouse.new()
		s.game = game
		s.female = l.sex == "f"
		s.position = player.position + l.pos * player.radius
		s.vel = Vector2.from_angle(randf() * TAU) * randf_range(80.0, 160.0)
		game.layer_creatures.add_child(s)
		out += 1
	eggs.clear()
	brood = 0.0
	game.hud.banner("ENXAME!", tr("%d parasitas saíram para devorar seus inimigos") % out, Color("ff8ab0"))
	game.shake(5.0)
	Sfx.play("boss_roar", -10.0)
	game.burst(player.position, [6, 2, 6], 20, 110.0, 0.8)
	Profile.bump("swarms")
	player.recalc()


## Stat penalties: the colony eats your food (XP) and weighs you down.
func modify(s: Dictionary) -> void:
	var n := lice.size()
	if n == 0:
		return
	if player.traits == null or player.traits.colony_slows():
		s.speed *= 1.0 - minf(0.28, 0.012 * n)
	s.xp_mult *= 1.0 - minf(0.5, 0.022 * n)


# -------------------------------------------------------- body overlay
func _draw() -> void:
	if not active() or not player.alive:
		return
	# lice crawling on / under the scales (up to 14 visible)
	var rx: float = player.radius * 1.25
	var ry: float = player.radius * 0.6
	var shown := 0
	for l in lice:
		if shown >= 14:
			break
		shown += 1
		var p: Vector2 = Vector2(l.pos.x * rx * player.facing, l.pos.y * ry)
		if l.sex == "f":
			draw_rect(Rect2(p + Vector2(-2, -1), Vector2(4, 2)), Color("e89aa8"))
			draw_rect(Rect2(p + Vector2(-1, 1), Vector2(2, 1)), Color("f0d060"))
		else:
			draw_rect(Rect2(p + Vector2(-1, -1), Vector2(2, 1)), Color("b8aa98"))
			draw_rect(Rect2(p + Vector2(-1, 0), Vector2(1, 1)), Color("5a4a48"))


## Allied louse that left the host: seeks an enemy, latches on and eats it.
class SwarmLouse extends Node2D:
	var game
	var female := false
	var vel := Vector2.ZERO
	var target: Creature
	var attached := false
	var _offset := Vector2.ZERO
	var _life := 9.0
	var _eat := 4.5
	var _tick := 0.0
	var _sprite: Sprite2D

	func _ready() -> void:
		_sprite = Art.sprite("creatures/" + ("louse_f" if female else "louse"))
		add_child(_sprite)
		z_index = 3

	func _find() -> void:
		var best: Creature = null
		var bd := 280.0 * 280.0
		for c in game.creatures:
			if not is_instance_valid(c) or c.dead or c.inside_titan or c.id in ["louse", "louse_f"]:
				continue
			if not (c.hostile_now() or c.faction == "boss" or c.faction == "pred"):
				continue
			var d: float = position.distance_squared_to(c.position)
			if d < bd:
				bd = d
				best = c
		target = best

	func _physics_process(delta: float) -> void:
		_life -= delta
		_sprite.frame = int(_life * 10.0) % 4
		if target == null or not is_instance_valid(target) or target.dead:
			attached = false
			target = null
			if int(_life * 10.0) % 3 == 0:
				_find()
		if attached:
			position = target.position + _offset
			_sprite.frame = 4 + int(_life * 8.0) % 2
			_eat -= delta
			_tick -= delta
			if _tick <= 0.0:
				_tick = 0.5
				var dmg: float = (5.0 if not female else 9.0) * game.player.st.damage_mult
				target.take_damage(dmg, {"source": "swarm", "dot": true, "color": Color("ff8ab0")})
			if _eat <= 0.0:
				_vanish()
			return
		if target != null:
			var to: Vector2 = target.position - position
			vel = vel.move_toward(to.normalized() * 230.0, 700.0 * delta)
			if to.length() < target.radius + 3.0:
				attached = true
				_offset = Vector2.from_angle(randf() * TAU) * target.radius * 0.7
		else:
			vel *= pow(0.3, delta)
		position += vel * delta
		_sprite.flip_h = vel.x < 0.0
		if _life <= 0.0:
			_vanish()

	func _vanish() -> void:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.3)
		tw.tween_callback(queue_free)
		set_physics_process(false)
