extends Creature
## Bottom recyclers (sea cucumber, giant isopod): crawl the seabed eating
## detritus and carcasses, then release nutrients that feed the plants.

var _target: Node2D


func _setup() -> void:
	anim_fps = 4.0 if id == "sea_cucumber" else 9.0
	on_floor = true
	wander_dir = Vector2(1 if randf() < 0.5 else -1, 0)


func hostile_now() -> bool:
	return provoked


func think(delta: float) -> void:
	position.y = DB.floor_at(position.x) - radius * 0.6
	if HerbUtil.scavenge(self, delta, 380.0):
		return
	if energy > 1.15:
		_crawl(delta)
		return
	if _target == null or not is_instance_valid(_target) or state_t > 8.0:
		state_t = 0.0
		_target = _floor_detritus(300.0)
	if _target:
		var dx := _target.position.x - position.x
		if absf(dx) > 4.0:
			vel = Vector2(signf(dx) * speed, 0)
		else:
			vel = Vector2.ZERO
			if can_hit("eat", 1.0):
				(_target as Pickup).consume()
				_target = null
				attack_anim = 0.3
				feed(0.22)
				# the recycler's gift: nutrients for kelp and plankton
				game.ecosystem.add_nutrients(position.x, 2.2 if id == "sea_cucumber" else 1.4)
	else:
		_crawl(delta)


func _crawl(delta: float) -> void:
	wander_t -= delta
	if wander_t <= 0.0:
		wander_t = randf_range(3.0, 6.0)
		wander_dir.x = -wander_dir.x if randf() < 0.5 else wander_dir.x
	vel = Vector2(wander_dir.x * speed * 0.6, 0)
	if position.x < 30 or position.x > DB.WORLD_W - 30:
		wander_dir.x = -wander_dir.x


func _floor_detritus(max_d: float) -> Pickup:
	var best: Pickup = null
	var bd := max_d
	for d in game.detritus:
		if not is_instance_valid(d):
			continue
		if d.position.y < DB.floor_at(d.position.x) - 14.0:
			continue
		var dist := absf(d.position.x - position.x)
		if dist < bd:
			bd = dist
			best = d
	return best
