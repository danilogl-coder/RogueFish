class_name Minion
extends Node2D
## A summoned critter: swims to the nearest enemy and gnaws it (or latches on).

var game
var sheet := "creatures/isopod"
var damage := 5.0
var speed := 160.0
var life := 6.0
var latch := false
var source := "minion"
var vel := Vector2.ZERO
var target: Creature
var _offset := Vector2.ZERO
var _attached := false
var _tick := 0.0
var _retarget := 0.0
var _sprite: Sprite2D
var _swim := 4


func _ready() -> void:
	_sprite = Art.sprite(sheet)
	_swim = Art.anim(sheet).x
	add_child(_sprite)
	z_index = 2


func _find() -> void:
	var best: Creature = null
	var bd := 260.0 * 260.0
	for c in game.creatures_in_radius(position, 260.0, false):
		if c.dead or c.inside_titan:
			continue
		var d := position.distance_squared_to(c.position)
		if d < bd:
			bd = d
			best = c
	target = best


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_vanish()
		return
	if target == null or not is_instance_valid(target) or target.dead:
		_attached = false
		target = null
		_retarget -= delta
		if _retarget <= 0.0:
			_retarget = 0.3
			_find()
	_tick -= delta
	if _attached and target:
		position = target.position + _offset
		_sprite.frame = _swim + int(life * 8.0) % 2
		if _tick <= 0.0:
			_tick = 0.5
			_bite()
		return
	if target:
		var to := target.position - position
		vel = vel.move_toward(to.normalized() * speed, 600.0 * delta)
		if to.length() < target.radius + 3.0:
			if latch:
				_attached = true
				_offset = Vector2.from_angle(randf() * TAU) * target.radius * 0.7
			elif _tick <= 0.0:
				_tick = 0.45
				_bite()
				vel = -to.normalized() * speed * 0.6
	else:
		vel = vel.move_toward(Vector2.ZERO, 200.0 * delta)
	position += vel * delta
	_sprite.flip_h = vel.x < 0.0
	_sprite.frame = int(life * 10.0) % maxi(1, _swim)


func _bite() -> void:
	var r: Array = game.roll_damage(damage)
	target.take_damage(r[0], {"crit": r[1], "source": source, "dot": latch})


func _vanish() -> void:
	set_physics_process(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
