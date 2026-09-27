class_name Projectile
extends Node2D
## Generic projectile for both the player (hostile=false) and enemies.

var game
var vel := Vector2.ZERO
var damage := 5.0
var pierce := 1
var life := 1.5
var radius := 4.0
var hostile := false
var crit := false
var homing := 0.0
var explode_radius := 0.0
var explode_sheet := "fx/explosion"
var poison := 0.0
var slow := 0.0
var stun := 0.0
var bleed := 0.0
var knockback := 60.0
var source := "proj"
var target_point = null
var on_arrive: Callable
var rotate_to_vel := true
var spin := 0.0
var fps := 8.0
var color := Color.WHITE
var sprite: Sprite2D
# archetype extras
var boomerang := 0.0          ## > 0: flies this far, then returns to owner_node
var owner_node: Node2D
var bounces := 0              ## ricochets to the next enemy after a hit
var chain := 0                ## lightning jumps from each hit
var pearls := false           ## kills may drop pearls
var arc_height := 0.0         ## lobbed throw: sprite rises and falls on the way
var _start := Vector2.ZERO
var _returning := false
var _travel := 0.0
var _hits: Dictionary = {}
var _t := 0.0
var _home_target: Creature
var _retarget := 0.0


func setup(sheet: String, p_vel: Vector2, p_damage: float, p_life := 1.5, p_radius := 4.0) -> Projectile:
	sprite = Art.sprite(sheet)
	add_child(sprite)
	vel = p_vel
	damage = p_damage
	life = p_life
	radius = p_radius
	return self


func _physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	if life <= 0.0:
		_finish()
		return
	if homing > 0.0 and not hostile:
		_retarget -= delta
		if _retarget <= 0.0 or not is_instance_valid(_home_target) or _home_target.dead:
			_retarget = 0.25
			_home_target = game.nearest_creature(position, 200.0)
		if _home_target:
			var want := (_home_target.position - position).normalized() * vel.length()
			vel = vel.lerp(want, clampf(homing * delta, 0.0, 1.0))
	elif homing > 0.0 and hostile:
		var want2: Vector2 = (game.player.position - position).normalized() * vel.length()
		vel = vel.lerp(want2, clampf(homing * delta, 0.0, 1.0))
	if _t <= delta:
		_start = position
	if boomerang > 0.0:
		_travel += vel.length() * delta
		if not _returning and _travel >= boomerang:
			_returning = true
			_hits.clear()
		if _returning and owner_node and is_instance_valid(owner_node):
			var back := owner_node.position - position
			vel = vel.lerp(back.normalized() * maxf(vel.length(), 220.0), clampf(8.0 * delta, 0.0, 1.0))
			if back.length() < 12.0:
				queue_free()
				return
	if arc_height > 0.0 and target_point != null:
		var total := maxf(1.0, _start.distance_to(target_point))
		var k := clampf(1.0 - position.distance_to(target_point) / total, 0.0, 1.0)
		sprite.position.y = -sin(k * PI) * arc_height
	position += vel * delta
	if rotate_to_vel:
		rotation = vel.angle()
	elif spin != 0.0:
		rotation += spin * delta
	if sprite.hframes > 1:
		sprite.frame = int(_t * fps) % sprite.hframes
	if target_point != null and position.distance_to(target_point) < maxf(6.0, vel.length() * delta):
		if on_arrive.is_valid():
			on_arrive.call(position)
		queue_free()
		return
	if (position.y > DB.floor_at(position.x) + 4 and boomerang <= 0.0) or position.y < 0 or position.x < -20 or position.x > DB.WORLD_W + 20:
		_finish()
		return
	if hostile:
		var p: Player = game.player
		if p.alive and position.distance_to(p.position) < radius + p.radius:
			p.take_damage(damage, null)
			if slow > 0.0:
				p.apply_slow(slow, 1.5)
			_finish()
		return
	if target_point != null:
		return
	for c in game.grid.query(position, radius):
		var key: int = c.get_instance_id()
		if _hits.has(key) or c.dead:
			continue
		_hits[key] = true
		_hit(c)
		pierce -= 1
		if bounces > 0:
			bounces -= 1
			var nxt: Creature = null
			var bd := 150.0 * 150.0
			for o in game.creatures_in_radius(position, 150.0, false):
				if o.dead or _hits.has(o.get_instance_id()):
					continue
				var d: float = o.position.distance_squared_to(position)
				if d < bd:
					bd = d
					nxt = o
			if nxt:
				vel = (nxt.position - position).normalized() * vel.length()
				life = maxf(life, 0.8)
		if pierce <= 0:
			_finish()
			return


func _hit(c: Creature) -> void:
	var r: Array = game.roll_damage(damage)
	var info := {"crit": r[1], "source": source, "hit_id": get_instance_id(), "knockback": vel.normalized() * knockback}
	if poison > 0.0:
		info.poison = poison * game.player.st.poison_mult
	if slow > 0.0:
		info.slow = slow
	if stun > 0.0:
		info.stun = stun
	if bleed > 0.0:
		info.bleed = bleed
	c.take_damage(r[0], info)
	if chain > 0 and not c.dead:
		game.player._chain_from(c, chain, r[0] * 0.5)
	if pearls and c.dead and randf() < 0.1:
		game.spawn_pickup("pearl", c.position, 1)
	game.fx("fx/hit_spark", position, 24.0)
	if explode_radius > 0.0:
		_explode()


func _explode() -> void:
	game.fx(explode_sheet, position, 18.0, explode_radius / 16.0)
	Sfx.play("explosion", -8.0, 0.1, 0.08)
	for c in game.grid.query(position, explode_radius):
		if c.dead:
			continue
		var r: Array = game.roll_damage(damage * 0.8)
		c.take_damage(r[0], {"crit": r[1], "source": source + "_x", "hit_id": get_instance_id(), "knockback": (c.position - position).normalized() * 90.0})
	explode_radius = 0.0


func _finish() -> void:
	if explode_radius > 0.0 and not hostile:
		_explode()
	queue_free()
