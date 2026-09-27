class_name Stomach
extends Node2D
## The Titanacon's stomach, seen through an "x-ray" cut-away of its body while
## it keeps swimming around the ocean. This node is a child of the boss, so the
## cavity follows every move; the player, the organs and the parasites inside
## are carried along each frame and kept inside the cavity ellipse.

const PIXEL := 2.0                        ## same pixel scale as the boss sprite
const CENTER := Vector2(-8, 12)           ## cavity centre relative to the boss (facing right)
const RADII := Vector2(292, 152)   ## the inside is bigger than it looks: the wall hides the body
const ACID_Y := 84.0                      ## below this (relative to the centre) is acid

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
# perspective layers: the gullet (far), ribs + acid floor (mid) and the wall
# folds drawn over the player (near). They slide at different rates as you
# swim, so the inside reads as a deep tube and not a flat window.
var _far: Sprite2D
var _mid: Sprite2D
var _near: Sprite2D
var _wall: Node2D
const PARALLAX_FAR := Vector2(30, 14)
const PARALLAX_MID := Vector2(15, 7)
const PARALLAX_NEAR := Vector2(-12, -6)


func _mk_layer(sheet: String) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = Art.tex("creatures/" + sheet)
	sp.scale = Vector2(PIXEL, PIXEL)
	add_child(sp)
	return sp


func _ready() -> void:
	z_index = 1
	_far = _mk_layer("titan_far")
	_mid = _mk_layer("titan_mid")
	# the body wall around the cavity: you are inside, the ocean is only a glow through the flesh
	_wall = Node2D.new()
	_wall.z_as_relative = false
	_wall.z_index = 3
	_wall.draw.connect(_draw_wall)
	add_child(_wall)
	_near = _mk_layer("titan_near")
	_near.z_as_relative = false
	_near.z_index = 5
	_last_pos = boss.position
	_last_facing = boss.facing
	_place()
	_add_organ("organ_heart", Vector2(12, -66), 30.0, 2.4, 2.0)
	_add_organ("organ_gland", Vector2(-205, 30), 22.0, 1.6, 1.6)
	_add_organ("organ_gland", Vector2(195, 20), 22.0, 1.6, 1.6)
	for i in 3:
		_spawn_parasite()


# ------------------------------------------------------------- geometry
func _place() -> void:
	position = Vector2(CENTER.x * boss.facing, CENTER.y)
	var f: float = boss.facing
	var rel := Vector2.ZERO
	if game.player and game.player.swallowed:
		rel = to_rel(game.player.position) / RADII
	for pair in [[_far, PARALLAX_FAR], [_mid, PARALLAX_MID], [_near, PARALLAX_NEAR]]:
		var sp: Sprite2D = pair[0]
		var k: Vector2 = pair[1]
		sp.scale.x = PIXEL * f
		sp.position = Vector2(-rel.x * k.x * f, -rel.y * k.y).round()


func _draw_wall() -> void:
	# ring between the cavity and far beyond the screen, darker near the cavity
	var beat := 0.5 + 0.5 * sin(_t * (2.0 + 3.0 * (1.0 - boss.hp / maxf(boss.max_hp, 1.0))) * PI)
	var inner_c := Color(0.2, 0.02, 0.07, 0.9 + 0.05 * beat)
	var outer_c := Color(0.1, 0.01, 0.04, 0.62)
	var n := 64
	var rin := RADII * 0.96
	var rout := Vector2(1100, 800)
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := Vector2(cos(a0) * rin.x, sin(a0) * rin.y)
		var p1 := Vector2(cos(a1) * rin.x, sin(a1) * rin.y)
		var q1 := Vector2(cos(a1) * rout.x, sin(a1) * rout.y)
		var q0 := Vector2(cos(a0) * rout.x, sin(a0) * rout.y)
		_wall.draw_polygon(PackedVector2Array([p0, p1, q1, q0]), PackedColorArray([inner_c, inner_c, outer_c, outer_c]))
	# a few veins crawling through the wall
	for k in 6:
		var a := k * 1.05 + 0.4
		var base := Vector2(cos(a) * rin.x, sin(a) * rin.y)
		var pts := PackedVector2Array([base])
		var d := base.normalized()
		for j in 5:
			d = d.rotated(sin(k * 3.1 + j) * 0.5)
			pts.append(pts[pts.size() - 1] + d * 60.0)
		_wall.draw_polyline(pts, Color(0.42, 0.12, 0.3, 0.55), 2.0)


## World position of a point given relative to the cavity centre (facing right).
func to_world(rel: Vector2) -> Vector2:
	return boss.position + Vector2((CENTER.x + rel.x) * boss.facing, CENTER.y + rel.y)


func to_rel(world: Vector2) -> Vector2:
	var l: Vector2 = world - boss.position
	return Vector2(l.x * boss.facing - CENTER.x, l.y - CENTER.y)


## Keeps a body of radius r inside the cavity ellipse.
func clamp_point(world: Vector2, r: float) -> Vector2:
	var rel := to_rel(world)
	var rx := maxf(8.0, RADII.x * 0.9 - r * 1.6)
	var ry := maxf(8.0, RADII.y * 0.88 - r * 1.3)
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
		var y := ACID_Y + 30.0 - ph * 80.0
		draw_circle(Vector2(x * boss.facing, y), 1.5 + (i % 2), Color(0.75, 0.95, 0.35, 0.8 * (1.0 - ph)))
	_wall.queue_redraw()


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
