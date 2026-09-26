class_name Pickup
extends Node2D
## XP orbs, pearls, food, magnet shells and drifting plankton.

var game
var kind := "xp"
var value := 1
var radius := 4.0
var attracted := false
var vel := Vector2.ZERO
var sprite: Sprite2D
var _t := 0.0
var _life := 90.0
var _speed := 0.0


func setup(p_kind: String, p_value: int) -> void:
	kind = p_kind
	value = p_value
	sprite = Sprite2D.new()
	add_child(sprite)
	vel = Vector2(randf_range(-30, 30), randf_range(-50, -10))
	_t = randf() * 2.0
	match kind:
		"xp":
			_apply_xp_sheet()
		"pearl":
			_set_sheet("fx/pearl")
		"food":
			_set_sheet("fx/food")
		"magnet":
			_set_sheet("fx/magnet")
			_life = 60.0
		"plankton":
			_set_sheet("env/plankton")
			vel = Vector2(randf_range(-6, 6), randf_range(-8, -2))
			_life = 40.0


func set_value(v: int) -> void:
	value = v
	_apply_xp_sheet()


func _apply_xp_sheet() -> void:
	if value >= 80:
		_set_sheet("fx/xp_huge")
	elif value >= 20:
		_set_sheet("fx/xp_big")
	elif value >= 5:
		_set_sheet("fx/xp_mid")
	else:
		_set_sheet("fx/xp_small")


func _set_sheet(path: String) -> void:
	sprite.texture = Art.tex(path)
	sprite.hframes = maxi(1, Art.frames(path))


func _physics_process(delta: float) -> void:
	_t += delta
	if sprite.hframes > 1:
		sprite.frame = int(_t * 6.0) % sprite.hframes
	var p: Player = game.player
	var to := p.position - position
	var d := to.length()
	var magnet: float = p.st.magnet
	if kind == "plankton":
		magnet *= 0.5
	if not attracted and d < magnet and p.alive:
		attracted = true
	if attracted:
		_speed = minf(_speed + 900.0 * delta, 520.0)
		vel = to.normalized() * _speed
		if d < p.radius + 6.0:
			_collect()
			return
	else:
		_life -= delta
		if _life < 5.0:
			visible = int(_t * 8.0) % 2 == 0
		if _life <= 0.0:
			_remove()
			return
		if kind == "plankton":
			vel.x += sin(_t * 1.3) * 4.0 * delta
			vel.y = lerpf(vel.y, -4.0, delta)
		else:
			vel *= pow(0.05, delta)
			vel.y += (6.0 if position.y < DB.FLOOR_Y - 8 else -20.0) * delta
	position += vel * delta
	position.y = clampf(position.y, DB.SURFACE_Y, DB.FLOOR_Y - 4)


func _collect() -> void:
	match kind:
		"xp":
			game.add_xp(value)
			Sfx.play("pickup", -8.0, 0.15, 0.03)
		"plankton":
			game.add_xp(1)
			Sfx.play("pickup", -12.0, 0.2, 0.05)
		"pearl":
			game.add_pearls(value)
			Sfx.play("pearl", -3.0)
			game.float_text(position + Vector2(0, -8), "+%d" % value, Color("f0f4f8"))
		"food":
			game.player.heal(value)
			Sfx.play("gulp")
		"magnet":
			Sfx.play("pearl")
			for pk in game.pickups:
				if is_instance_valid(pk) and pk.kind == "xp":
					pk.attracted = true
	_remove()


## Eaten by a herbivore (plankton only).
func consume() -> void:
	_remove()


func _remove() -> void:
	if kind == "plankton":
		game.plankton.erase(self)
	else:
		game.pickups.erase(self)
	queue_free()
