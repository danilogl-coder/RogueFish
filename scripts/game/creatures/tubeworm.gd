extends Creature
## Verme-Tubo Gigante: planted in the rock near the vents. Its red plume sways
## in the warm water and snaps back into the tube when something comes close
## (then it is almost impossible to hurt).

var _hidden := false


func _setup() -> void:
	anim_fps = 5.0
	home = Vector2(position.x, DB.ground_under(position.x, 6.0) + 1.0)
	position = home
	sprite.offset = Vector2(0, -float(Art.sheet_info("creatures/tube_worm").h) * 0.5 + 2.0)
	anim_t = randf() * 3.0


func think(_delta: float) -> void:
	vel = Vector2.ZERO
	position = home
	var near := false
	var p: Player = game.player
	if p.alive and position.distance_to(p.position) < 64.0:
		near = true
	else:
		for c in game.grid.query(position, 50.0):
			if c != self and c.hostile_now():
				near = true
				break
	if near != _hidden:
		_hidden = near
		armor_mult = 0.2 if _hidden else 1.0


func _clamp() -> void:
	pass


func _animate(delta: float) -> void:
	anim_t += delta
	sprite.frame = (4 + int(anim_t * 4.0) % 2) if _hidden else int(anim_t * anim_fps) % 4
