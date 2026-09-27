class_name Stomach
extends Node2D
## The Titanacon's stomach, seen through an "x-ray" cut-away of its body while
## it keeps swimming around the ocean. This node is a child of the boss, so the
## cavity follows every move; the player, the organs and the parasites inside
## are carried along each frame and kept inside the cavity ellipse.

const PIXEL := 2.0                        ## same pixel scale as the boss sprite
const CENTER := Vector2(-8, 12)           ## cavity centre relative to the boss (facing right)
const RADII := Vector2(156, 80)
const ACID_Y := 44.0                      ## below this (relative to the centre) is acid

var game
var boss                                  # the Titanacon
var organs: Array = []                    # [{node, offset}]
var parasites: Array = []
var _spawn_t := 1.2
var _digest_t := 2.5
var _acid_t := 0.0
var _t := 0.0
var _last_pos := Vector2.ZERO
var _last_facing := 1.0
var _inside: Sprite2D


func _ready() -> void:
	z_index = 1
	_inside = Sprite2D.new()
	_inside.texture = Art.tex("creatures/titan_inside")
	_inside.scale = Vector2(PIXEL, PIXEL)
	add_child(_inside)
	_last_pos = boss.position
	_last_facing = boss.facing
	_place()
	_add_organ("organ_heart", Vector2(6, -34), 26.0, 2.4, 1.4)
	_add_organ("organ_gland", Vector2(-112, 18), 18.0, 1.6, 1.2)
	_add_organ("organ_gland", Vector2(104, 10), 18.0, 1.6, 1.2)
	for i in 3:
		_spawn_parasite()


# ------------------------------------------------------------- geometry
func _place() -> void:
	position = Vector2(CENTER.x * boss.facing, CENTER.y)
	_inside.scale.x = PIXEL * boss.facing


## World position of a point given relative to the cavity centre (facing right).
func to_world(rel: Vector2) -> Vector2:
	return boss.position + Vector2((CENTER.x + rel.x) * boss.facing, CENTER.y + rel.y)


func to_rel(world: Vector2) -> Vector2:
	var l: Vector2 = world - boss.position
	return Vector2(l.x * boss.facing - CENTER.x, l.y - CENTER.y)


## Keeps a body of radius r inside the cavity ellipse.
func clamp_point(world: Vector2, r: float) -> Vector2:
	var rel := to_rel(world)
	var rx := maxf(8.0, RADII.x - r)
	var ry := maxf(8.0, RADII.y - r)
	var k := (rel.x / rx) * (rel.x / rx) + (rel.y / ry) * (rel.y / ry)
	if k > 1.0:
		rel /= sqrt(k)
	return to_world(rel)


func acid_line() -> float:
	return to_world(Vector2(0, ACID_Y + sin(_t * 1.3) * 3.0)).y


# --------------------------------------------------------------- contents
func _add_organ(sheet: String, rel: Vector2, r: float, share: float, sc: float) -> void:
	var og := Organ.new()
	og.game = game
	og.owner_boss = boss
	og.sheet = sheet
	og.sprite_scale = sc
	og.radius = r
	og.damage_share = share
	og.z_index = 2
	og.position = to_world(rel)
	game.layer_creatures.add_child(og)
	game.creatures.append(og)
	boss.parts.append(og)
	organs.append({"node": og, "rel": rel})


func organ_nodes() -> Array:
	return organs.map(func(o): return o.node).filter(func(n): return is_instance_valid(n))


func max_parasites() -> int:
	return 7 if boss.enraged else 5


func _spawn_parasite() -> void:
	var o: Dictionary = organs[randi() % organs.size()]
	var rel: Vector2 = o.rel + Vector2.from_angle(randf() * TAU) * 50.0
	var c: Creature = game.spawn_creature("parasite", clamp_point(to_world(rel), 10.0), {"wave": true, "force": true})
	if c:
		c.container = self
		c.guard = o.node
		c.inside_titan = true
		c.z_index = 2
		parasites.append(c)
		game.burst(c.position, [2, 6], 5, 40.0, 0.5)


# ------------------------------------------------------------------ tick
func _physics_process(delta: float) -> void:
	_t += delta
	var p: Player = game.player
	# carry everything inside along with the titan (and mirror it when it turns)
	var d: Vector2 = boss.position - _last_pos
	var turned: bool = boss.facing != _last_facing
	var bodies: Array = [p]
	parasites = parasites.filter(func(c): return is_instance_valid(c) and not c.dead)
	bodies.append_array(parasites)
	for b in bodies:
		b.position += d
		if turned:
			b.position.x = boss.position.x - (b.position.x - boss.position.x)
	_last_pos = boss.position
	_last_facing = boss.facing
	_place()
	for o in organs:
		if is_instance_valid(o.node):
			o.node.position = to_world(o.rel)
	if not p.alive:
		return
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = 3.2 if boss.enraged else 4.2
		if parasites.size() < max_parasites():
			_spawn_parasite()
	# acid pool in the belly
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
	# acid bubbles rising from the pool (local space follows the flip)
	for i in 10:
		var x := -RADII.x * 0.8 + fmod(i * 37.0 + _t * 8.0 * (1 + i % 3), RADII.x * 1.6)
		var ph := fmod(_t * 0.6 + i * 0.37, 1.0)
		var y := ACID_Y + 20.0 - ph * 50.0
		draw_circle(Vector2(x * boss.facing, y), 1.5 + (i % 2), Color(0.75, 0.95, 0.35, 0.8 * (1.0 - ph)))


## Frees everything that lives in here (the player was spat out).
func teardown() -> void:
	for c in parasites:
		if is_instance_valid(c):
			c.dead = true
			c.queue_free()
	for o in organs:
		if is_instance_valid(o.node):
			o.node.dead = true
			o.node.queue_free()
			boss.parts.erase(o.node)
	queue_free()
