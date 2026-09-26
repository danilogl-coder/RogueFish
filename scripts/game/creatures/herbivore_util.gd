class_name HerbUtil
extends RefCounted
## Shared food-search helpers for the food web.


static func _nearest(list: Array, pos: Vector2, max_d: float):
	var best = null
	var bd := max_d * max_d
	for p in list:
		if not is_instance_valid(p):
			continue
		var d: float = p.position.distance_squared_to(pos)
		if d < bd:
			bd = d
			best = p
	return best


static func nearest_plankton(c: Creature, max_d: float) -> Pickup:
	return _nearest(c.game.plankton, c.position, max_d)


static func nearest_detritus(c: Creature, max_d: float) -> Pickup:
	return _nearest(c.game.detritus, c.position, max_d)


static func nearest_carcass(c: Creature, max_d: float) -> Carcass:
	return _nearest(c.game.carcasses, c.position, max_d)


## Best small food item for this diet (plankton / detritus).
static func nearest_small_food(c: Creature, max_d: float) -> Pickup:
	var best: Pickup = null
	if c.diet.has("plankton"):
		best = nearest_plankton(c, max_d)
	if c.diet.has("detritus"):
		var d := nearest_detritus(c, max_d)
		if d and (best == null or d.position.distance_squared_to(c.position) < best.position.distance_squared_to(c.position)):
			best = d
	return best


## Scavenging step: walk/swim to a carcass and tear off pieces. Returns true
## while busy so the caller skips its normal behaviour.
static func scavenge(c: Creature, delta: float, max_d := 180.0) -> bool:
	if not c.diet.has("carcass") or not c.hungry():
		return false
	var cc := nearest_carcass(c, max_d)
	if cc == null:
		return false
	if c.on_floor:
		var dx := cc.position.x - c.position.x
		c.vel = Vector2(signf(dx) * c.speed, 0) if absf(dx) > 4.0 else Vector2.ZERO
	else:
		c.seek(cc.position, c.speed, 200.0, delta)
	if c.position.distance_to(cc.position) < c.radius + cc.radius + 2.0:
		c.vel *= 0.5
		if c.can_hit("carcass", 0.8):
			if cc.bite(1) > 0:
				c.feed(0.22)
				c.attack_anim = 0.2
	return true
