class_name Stomach
extends Node2D
## Inside the Titanacon. A closed arena far from the ocean map: the heart and
## two acid glands are the only targets that hurt the titan, parasites guard
## them, the acid pool at the bottom burns and slow digestion wears you down.

const ACID_DEPTH := 38.0

var game
var boss                 # the Titanacon (Creature)
var rect := Rect2()
var organs: Array = []
var parasites: Array = []
var _spawn_t := 1.2
var _digest_t := 2.5
var _acid_t := 0.0
var _t := 0.0


func _ready() -> void:
	z_index = -30
	z_as_relative = false
	var bg := Sprite2D.new()
	bg.texture = Art.tex("env/stomach")
	bg.centered = false
	bg.position = rect.position
	add_child(bg)
	var o := rect.position
	_add_organ("organ_heart", o + Vector2(320, 112), 30.0, 2.4, 1.6)
	_add_organ("organ_gland", o + Vector2(92, 226), 20.0, 1.6, 1.4)
	_add_organ("organ_gland", o + Vector2(550, 206), 20.0, 1.6, 1.4)
	for i in 3:
		_spawn_parasite()


func _add_organ(sheet: String, pos: Vector2, r: float, share: float, sc: float) -> void:
	var og := Organ.new()
	og.game = game
	og.owner_boss = boss
	og.sheet = sheet
	og.sprite_scale = sc
	og.radius = r
	og.damage_share = share
	og.position = pos
	game.layer_creatures.add_child(og)
	game.creatures.append(og)
	boss.parts.append(og)
	organs.append(og)


func max_parasites() -> int:
	return 7 if boss.enraged else 5


func _spawn_parasite() -> void:
	# they crawl out of the stomach wall around the organs they protect
	var guard: Node2D = organs[randi() % organs.size()]
	var a := randf() * TAU
	var pos: Vector2 = guard.position + Vector2.from_angle(a) * 60.0
	pos.x = clampf(pos.x, rect.position.x + 20, rect.end.x - 20)
	pos.y = clampf(pos.y, rect.position.y + 20, rect.end.y - ACID_DEPTH - 20)
	var c: Creature = game.spawn_creature("parasite", pos, {"wave": true, "force": true})
	if c:
		c.arena = rect.grow(-6)
		c.guard = guard
		parasites.append(c)
		game.burst(pos, [2, 6], 5, 40.0, 0.5)


func acid_line() -> float:
	return rect.end.y - ACID_DEPTH + sin(_t * 1.3) * 3.0


func _physics_process(delta: float) -> void:
	_t += delta
	var p: Player = game.player
	if not p.alive:
		return
	parasites = parasites.filter(func(c): return is_instance_valid(c) and not c.dead)
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = 3.2 if boss.enraged else 4.2
		if parasites.size() < max_parasites():
			_spawn_parasite()
	# acid pool at the bottom
	if p.position.y > acid_line():
		_acid_t -= delta
		if _acid_t <= 0.0:
			_acid_t = 0.5
			p.take_damage(9.0 * boss.dmg_mult, boss)
			game.burst(p.position, [6], 3, 30.0, 0.4)
	# slow digestion: the longer you stay, the more it hurts
	_digest_t -= delta
	if _digest_t <= 0.0:
		_digest_t = 2.5
		p.take_damage(2.0 + boss.dmg_mult, boss)
	queue_redraw()


func _draw() -> void:
	# acid bubbles rising from the pool
	for i in 14:
		var x := rect.position.x + fmod(i * 47.0 + _t * 9.0 * (1 + i % 3), rect.size.x)
		var ph := fmod(_t * 0.6 + i * 0.37, 1.0)
		var y := rect.end.y - 8.0 - ph * 70.0
		draw_circle(Vector2(x, y), 1.5 + (i % 2), Color(0.75, 0.95, 0.35, 0.8 * (1.0 - ph)))


## Frees everything that lives in here (the player was spat out).
func teardown() -> void:
	for c in parasites:
		if is_instance_valid(c):
			c.dead = true
			c.queue_free()
	for og in organs:
		if is_instance_valid(og):
			og.dead = true
			og.queue_free()
			boss.parts.erase(og)
	for pk in game.pickups:
		# loot dropped inside is flushed out with you
		if is_instance_valid(pk) and rect.has_point(pk.position):
			pk.position = game.player.position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	queue_free()
