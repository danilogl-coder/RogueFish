extends Creature
## Lamprey-like parasite living inside the Titanacon. Guards a vital organ,
## circling it, and lunges at the player when they come close.

var container                # Stomach while living inside the Titanacon (null = open ocean)
var guard: Node2D           # organ to protect
var _orbit := 0.0
var _lunge_cd := 0.0


func _setup() -> void:
	anim_fps = 11.0
	sprite.scale = Vector2(1.5, 1.5)
	radius = 9.0
	_orbit = randf() * TAU
	_lunge_cd = randf_range(0.4, 1.2)


func think(delta: float) -> void:
	_lunge_cd -= delta
	var p: Player = game.player
	var near_player := p.alive and position.distance_to(p.position) < (190.0 if container != null else 260.0)
	var guarding := guard != null and is_instance_valid(guard) and not near_player
	if guarding:
		_orbit += delta * 1.6
		var want: Vector2 = guard.position + Vector2.from_angle(_orbit) * 44.0
		seek(want, speed * 0.8, 300.0, delta)
		return
	if not p.alive:
		wander(delta, speed * 0.5)
		return
	var d := position.distance_to(p.position)
	if d < 46.0 and _lunge_cd <= 0.0:
		_lunge_cd = randf_range(0.8, 1.3)
		vel = (p.position - position).normalized() * speed * 2.7
		attack_anim = 0.3
	else:
		seek(p.position, speed, 340.0, delta)


func _clamp() -> void:
	if container != null and is_instance_valid(container):
		position = container.clamp_point(position, radius)
	else:
		super._clamp()
