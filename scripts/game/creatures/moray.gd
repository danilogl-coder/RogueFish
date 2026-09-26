extends Creature
## Moray eel: ambush predator hiding in a rock hole. Strikes when prey or the
## player swims by, then retreats. Immune while hidden.

var _strike_dir := Vector2.RIGHT
var _cd := 0.0


func _setup() -> void:
	anim_fps = 7.0
	state = "hide"
	home = position
	sprite.visible = false
	armor_mult = 0.0
	swallowable = false


func hostile_now() -> bool:
	return state != "hide"


func think(delta: float) -> void:
	_cd -= delta
	match state:
		"hide":
			position = position.move_toward(home, 60.0 * delta)
			vel = Vector2.ZERO
			queue_redraw()
			if _cd > 0.0:
				return
			var p: Player = game.player
			var target := Vector2.INF
			if player_visible(95.0) or (is_wave and player_visible(160.0)):
				target = p.position
			else:
				var prey := find_prey(80.0)
				if prey:
					target = prey.position
			if target != Vector2.INF:
				_strike_dir = (target - position).normalized()
				state = "strike"
				state_t = 0.0
				sprite.visible = true
				armor_mult = 1.0
				attack_anim = 0.4
				Sfx.play("bite", -4.0)
		"strike":
			vel = _strike_dir * 330.0
			for c in game.grid.query(position, radius):
				if can_eat(c) and (hungry() or is_wave):
					eat_prey(c)
			if state_t > 0.35:
				state = "return"
				state_t = 0.0
		"return":
			seek(home, speed * 1.6, 500.0, delta)
			if position.distance_to(home) < 6.0 or state_t > 3.0:
				state = "hide"
				_cd = randf_range(1.0, 2.0)
				sprite.visible = false
				armor_mult = 0.0


func _animate(delta: float) -> void:
	super._animate(delta)
	if state == "strike":
		sprite.flip_h = _strike_dir.x < 0.0


func _draw() -> void:
	super._draw()
	if state == "hide":
		var blink := int(anim_t * 1.5) % 5 != 0
		if blink:
			draw_rect(Rect2(-3, -2, 1, 1), Color("fff060"))
			draw_rect(Rect2(2, -2, 1, 1), Color("fff060"))
