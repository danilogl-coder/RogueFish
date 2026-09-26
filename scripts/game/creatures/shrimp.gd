extends Creature
## Shrimp: grazes plankton near the bottom; escapes threats with tail-flick hops.

var _hop_cd := 0.0
var _food: Pickup


func _setup() -> void:
	anim_fps = 10.0


func think(delta: float) -> void:
	_hop_cd -= delta
	var threat := find_threat(75.0)
	if threat != Vector2.INF:
		if _hop_cd <= 0.0:
			_hop_cd = randf_range(0.7, 1.1)
			vel = (position - threat).normalized().rotated(randf_range(-0.6, 0.6)) * speed * 3.4
			attack_anim = 0.3
			facing = -signf(vel.x)
		else:
			vel *= pow(0.15, delta)
		return
	if HerbUtil.scavenge(self, delta, 140.0):
		return
	if energy > 1.15:
		wander(delta, speed * 0.4)
		return
	if _food == null or not is_instance_valid(_food) or state_t > 7.0:
		_food = HerbUtil.nearest_small_food(self, 150.0)
		state_t = 0.0
	if _food:
		seek(_food.position, speed, 140.0, delta)
		if position.distance_to(_food.position) < radius + 3.0:
			_food.consume()
			_food = null
			feed(0.16)
	else:
		wander(delta, speed * 0.45)


func _animate(delta: float) -> void:
	super._animate(delta)
	# shrimps swim backwards when hopping
	if attack_anim > 0.0:
		sprite.flip_h = vel.x > 0.0
