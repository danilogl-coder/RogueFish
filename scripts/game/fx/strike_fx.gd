class_name StrikeFx
extends Node2D
## Animated strike on a spot: a moray lunging out of a crack, jaws springing
## from the sand, or a golden coin falling from above. Calls on_hit(pos, target)
## at the moment of impact.

var game
var visual := "coin"
var target
var on_hit: Callable
var _t := 0.0
var _sprite: Sprite2D
var _from := Vector2.ZERO
var _done := false
var _dur := 0.2


func _ready() -> void:
	z_index = 3
	match visual:
		"moray":
			_sprite = Art.sprite("creatures/moray")
			var side := -1.0 if randf() < 0.5 else 1.0
			_from = Vector2(side * 46.0, randf_range(-14.0, 14.0))
			_sprite.flip_h = side > 0.0
			_sprite.position = _from
			_sprite.frame = Art.anim("creatures/moray").x + 1
			_dur = 0.16
		"jaws":
			_sprite = Art.sprite("fx/jaws")
			_sprite.position = Vector2(0, 10)
			_dur = 0.22
		"megajaw":
			_sprite = Art.sprite("fx/megajaw")
			_sprite.modulate = Color(0.85, 0.95, 1.1, 0.9)
			_dur = 0.26
		_:
			_sprite = Art.sprite("fx/coin")
			_from = Vector2(randf_range(-12.0, 12.0), -90.0)
			_sprite.position = _from
			_dur = 0.35
	add_child(_sprite)
	game.fx("fx/hit_spark", position, 18.0, 0.6, Color(1, 1, 1, 0.5))


func _process(delta: float) -> void:
	_t += delta
	if target != null and is_instance_valid(target) and not target.dead and not _done:
		position = position.lerp(target.position, 0.4)
	var k := clampf(_t / _dur, 0.0, 1.0)
	match visual:
		"moray":
			_sprite.position = _from.lerp(Vector2.ZERO, ease(k, 0.4))
			if _done:
				_sprite.position = Vector2.ZERO.lerp(_from, clampf((_t - _dur) / 0.25, 0.0, 1.0))
				_sprite.modulate.a = 1.0 - clampf((_t - _dur) / 0.25, 0.0, 1.0)
		"megajaw":
			_sprite.frame = mini(int(k * 4.0), 3)
			if _done:
				_sprite.modulate.a = 0.9 * (1.0 - clampf((_t - _dur) / 0.3, 0.0, 1.0))
		"jaws":
			_sprite.frame = mini(int(k * 3.0), 2) if not _done else 3
			_sprite.position.y = lerpf(10.0, -2.0, ease(k, 0.3))
			if _done:
				_sprite.modulate.a = 1.0 - clampf((_t - _dur) / 0.3, 0.0, 1.0)
		_:
			_sprite.position = _from.lerp(Vector2.ZERO, k * k)
			_sprite.frame = int(_t * 12.0) % _sprite.hframes
			if _done:
				_sprite.visible = false
	if not _done and _t >= _dur:
		_done = true
		if on_hit.is_valid():
			on_hit.call(position, target)
		Sfx.play("bite" if visual != "coin" else "pickup", -6.0)
	if _t >= _dur + 0.35:
		queue_free()
