class_name HerbUtil
extends RefCounted
## Shared helpers for herbivores (food search).


static func nearest_plankton(c: Creature, max_d: float) -> Pickup:
	var best: Pickup = null
	var bd := max_d * max_d
	for p in c.game.plankton:
		if not is_instance_valid(p):
			continue
		var d: float = p.position.distance_squared_to(c.position)
		if d < bd:
			bd = d
			best = p
	return best
