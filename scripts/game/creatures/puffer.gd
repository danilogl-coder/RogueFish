extends Creature
## Pufferfish: harmless until approached, then inflates into a spiky ball.

var inflated := false
var _inflate_t := 0.0
var _small_tex: Texture2D
var _big_tex: Texture2D
var _base_radius := 7.0


func _setup() -> void:
	anim_fps = 6.0
	_small_tex = sprite.texture
	_big_tex = Art.tex("creatures/puffer_big")
	_base_radius = radius


func hostile_now() -> bool:
	return inflated or provoked


func think(delta: float) -> void:
	if inflated:
		_inflate_t -= delta
		vel *= pow(0.2, delta)
		vel.y += sin(anim_t * 2.0) * 4.0 * delta
		if _inflate_t <= 0.0:
			_set_inflated(false)
		return
	var p: Player = game.player
	if p.alive and not p.is_hidden and player_dist() < 58.0 + p.radius:
		_set_inflated(true)
		return
	var food := HerbUtil.nearest_plankton(self, 120.0)
	if food:
		seek(food.position, speed, 60.0, delta)
		if position.distance_to(food.position) < radius + 3.0:
			food.consume()
	else:
		wander(delta, speed * 0.5)


func _set_inflated(on: bool) -> void:
	if on == inflated:
		return
	inflated = on
	if on:
		_inflate_t = 3.2
		sprite.texture = _big_tex
		sprite.hframes = 4
		radius = _base_radius * 1.8
		armor_mult = 0.5
		contact_damage = float(def.dmg) * 1.4
		Sfx.play("inflate", -6.0)
	else:
		sprite.texture = _small_tex
		sprite.hframes = 6
		radius = _base_radius
		armor_mult = 1.0
		contact_damage = float(def.dmg)
	sprite.frame = 0


func on_hurt(_info: Dictionary) -> void:
	if not inflated:
		_set_inflated(true)
