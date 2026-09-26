extends Creature
## Sardine / golden fish: boids schooling, eats plankton, flees as a group.

func _setup() -> void:
	anim_fps = 12.0
	if faction == "gold":
		light_radius = 26.0


func think(delta: float) -> void:
	var sep := Vector2.ZERO
	var ali := Vector2.ZERO
	var coh := Vector2.ZERO
	var n := 0
	for o in game.grid.query(position, 42.0, 10.0):
		if o == self or o.id != id:
			continue
		var d: Vector2 = position - o.position
		var l := d.length()
		if l < 14.0 and l > 0.01:
			sep += d / l * (14.0 - l)
		ali += o.vel
		coh += o.position
		n += 1
	var desired := wander_dir * speed * 0.6
	var threat := find_threat(110.0 if faction != "gold" else 170.0)
	if threat != Vector2.INF:
		desired = (position - threat).normalized() * speed * 1.8
	else:
		wander_t -= delta
		if wander_t <= 0.0:
			wander_t = randf_range(2.0, 4.0)
			wander_dir = Vector2.from_angle(randf_range(-0.4, 0.4) + (0.0 if randf() < 0.5 else PI))
		var food: Pickup = HerbUtil.nearest_small_food(self, 90.0) if energy < 1.15 else null
		if food:
			desired = (food.position - position).normalized() * speed * 0.8
			if position.distance_to(food.position) < radius + 3.0:
				food.consume()
				feed(0.14)
	if n > 0:
		desired += (ali / n) * 0.5 + ((coh / n) - position) * 0.8 + sep * 6.0
	if position.y < band_min():
		desired.y += 40.0
	elif position.y > band_max():
		desired.y -= 40.0
	steer(desired.limit_length(speed * 1.9), 260.0, delta)
