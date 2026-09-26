extends Creature
## Shark: patrols, circles its target, then charges through it.

var _target: Node2D
var _orbit_a := 0.0
var _charge_dir := Vector2.RIGHT
var _circle_len := 2.0


func _setup() -> void:
	anim_fps = 6.0
	state = "patrol"
	swallowable = true


func think(delta: float) -> void:
	match state:
		"patrol":
			if HerbUtil.scavenge(self, delta, 220.0):
				return
			wander(delta, speed * 0.7)
			if is_wave or player_visible(250.0):
				_target = game.player
			else:
				_target = find_prey(220.0)
			if _target:
				_orbit_a = (position - _target.position).angle()
				_circle_len = randf_range(1.4, 2.8)
				_go("circle")
		"circle":
			if not is_instance_valid(_target) or (_target is Creature and _target.dead):
				_go("patrol")
				return
			if _target == game.player and not is_wave and not player_visible(320.0):
				_go("patrol")
				return
			_orbit_a += delta * 1.1
			var want: Vector2 = _target.position + Vector2.from_angle(_orbit_a) * 105.0
			seek(want, speed * 1.4, 220.0, delta)
			if state_t > _circle_len:
				_charge_dir = (_target.position - position).normalized()
				_go("charge")
				attack_anim = 0.8
				Sfx.play("dash", -4.0)
		"charge":
			vel = vel.move_toward(_charge_dir * 300.0, 900.0 * delta)
			for c in game.grid.query(position + _charge_dir * radius, radius):
				if can_eat(c) and (hungry() or is_wave):
					eat_prey(c)
			if state_t > 0.8:
				_go("recover")
		"recover":
			vel *= pow(0.2, delta)
			if state_t > 1.0:
				_go("circle" if _target and is_instance_valid(_target) else "patrol")


func _go(s: String) -> void:
	state = s
	state_t = 0.0
