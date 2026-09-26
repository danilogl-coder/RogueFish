extends Creature
## Sea otter: floats at the surface of the kelp forest and dives to catch
## urchins, crabs and sea cucumbers, then eats them lying on its back.
## Peaceful towards the player unless attacked.

var _prey: Creature
var _eat_t := 0.0


func _setup() -> void:
	anim_fps = 6.0
	state = "float"


func think(delta: float) -> void:
	if provoked and player_visible(220.0):
		seek(game.player.position, speed * 1.2, 260.0, delta)
		if player_dist() < radius + 14.0:
			attack_anim = 0.25
		if state_t > 5.0:
			provoked = false
		return
	match state:
		"float":
			var target_y := 22.0 + sin(anim_t * 1.3) * 3.0
			vel.y = (target_y - position.y) * 2.0
			vel.x = move_toward(vel.x, sin(anim_t * 0.3) * 12.0, 20.0 * delta)
			_eat_t -= delta
			if _eat_t > 0.0:
				attack_anim = 0.2
			elif hungry():
				_prey = find_prey(520.0)
				if _prey:
					state = "dive"
					state_t = 0.0
		"dive":
			if _prey == null or not is_instance_valid(_prey) or _prey.dead or state_t > 9.0:
				state = "surface"
				return
			seek(_prey.position, speed * 1.3, 260.0, delta)
			if position.distance_to(_prey.position) < radius + _prey.radius + 2.0:
				eat_prey(_prey)
				_prey = null
				state = "surface"
				state_t = 0.0
		"surface":
			seek(Vector2(position.x, 24.0), speed * 1.2, 220.0, delta)
			if position.y < 32.0:
				state = "float"
				state_t = 0.0
				_eat_t = 3.0


func band_min() -> float:
	return DB.SURFACE_Y + 4.0


func band_max() -> float:
	return DB.floor_at(position.x) - radius


func on_hurt(_info: Dictionary) -> void:
	provoked = true
	state_t = 0.0
