extends Creature
## Minhoca-do-mar (bobbit worm, Eunice aphroditois): buried in the sand with
## only its antennae showing. When something swims over it, it springs out and
## snaps its scissor jaws. Its bite can leave a fish-louse larva in the victim.
## The creature's position is the HEAD; the sprite stays anchored at the burrow.

const LENGTH := 55.0          ## head height above the burrow when fully out
const INFECT_CHANCE := 0.45

var _ext := 0.12              # 0 = buried, 1 = fully out
var _lean := 0.0
var _target := Vector2.ZERO
var _cd := 0.0
var _bit := false


func _setup() -> void:
	anim_fps = 5.0
	home = Vector2(position.x, DB.floor_at(position.x) + 2.0)
	state = "hide"
	# the worm is revealed by cropping the frame (never stretched): it slides
	# out of the burrow with its real pixels
	sprite.hframes = 1
	sprite.region_enabled = true
	sprite.centered = false
	swallowable = false
	armor_mult = 0.3
	_attack_len = 0.3


func hostile_now() -> bool:
	return state == "strike" and _ext > 0.6


func think(delta: float) -> void:
	_cd -= delta
	# recycled / newborn worms dig in where they are
	if absf(home.x - position.x) > 80.0 and state == "hide":
		home = Vector2(position.x, DB.floor_at(position.x) + 2.0)
	vel = Vector2.ZERO
	match state:
		"hide":
			_ext = move_toward(_ext, 0.12, delta * 2.5)
			_lean = move_toward(_lean, 0.0, delta)
			if _cd <= 0.0:
				var p: Player = game.player
				var t := Vector2.INF
				if p.alive and not p.swallowed and _in_reach(p.position, 1.0 if not p.is_hidden else 0.5):
					t = p.position
				else:
					var prey := find_prey(80.0)
					if prey and _in_reach(prey.position, 1.0):
						t = prey.position
				if t != Vector2.INF:
					_target = t
					state = "strike"
					state_t = 0.0
					_bit = false
					attack_anim = 0.3
					armor_mult = 1.0
					Sfx.play("bite", -4.0)
					game.burst(home, [3, 3, 1], 6, 40.0, 0.6)
		"strike":
			var want := clampf((_target.x - home.x) / 70.0, -0.75, 0.75)
			_lean = move_toward(_lean, want, delta * 8.0)
			_ext = move_toward(_ext, 1.0, delta * 9.0)
			if _ext > 0.85 and not _bit:
				_bit = true
				for c in game.grid.query(position, radius + 8.0):
					if can_eat(c) and (hungry() or is_wave):
						eat_prey(c)
						break
			if state_t > 0.35:
				state = "hold"
				state_t = 0.0
		"hold":
			_lean = move_toward(_lean, sin(anim_t * 2.0) * 0.2, delta)
			if state_t > 1.3:
				state = "retract"
				state_t = 0.0
		"retract":
			_ext = move_toward(_ext, 0.12, delta * 3.0)
			if _ext <= 0.13:
				state = "hide"
				armor_mult = 0.3
				_cd = randf_range(1.2, 2.2)
	position = home + Vector2(0, -LENGTH * _ext).rotated(_lean)


func _in_reach(pos: Vector2, k: float) -> bool:
	var d := pos - home
	return d.y < 0.0 and d.y > -LENGTH * 1.25 * k and absf(d.x) < 48.0 * k


func _clamp() -> void:
	pass


func on_touch_player(p: Player) -> void:
	p.take_damage(contact_damage * dmg_mult, self)
	attack_anim = 0.25
	if p.infest and randf() < INFECT_CHANCE:
		p.infest.add("m", position, "LARVA DE PIOLHO!")


const FW := 28.0
const FH := 72.0
const HEAD_Y := 17.0          ## head centre inside the frame


func _animate(delta: float) -> void:
	anim_t += delta
	if attack_anim > 0.0:
		attack_anim = maxf(0.0, attack_anim - delta)
	var f := 4 + Art.act_frame(attack_progress(), 2) if attack_anim > 0.0 else int(anim_t * anim_fps) % 4
	# show only the part of the worm that is out of the sand
	var out := roundf(HEAD_Y + 6.0 + (LENGTH) * _ext)
	out = clampf(out, 10.0, FH)
	sprite.region_rect = Rect2(f * FW, 0, FW, out)
	sprite.offset = Vector2(-FW * 0.5, -out)
	sprite.position = (home - position).round()
	sprite.rotation = _lean
	sprite.flip_h = false
	queue_redraw()


func _draw() -> void:
	super._draw()
	# sand mound around the burrow (always visible) so sharp players can spot it
	var b := home - position
	draw_rect(Rect2(b + Vector2(-6, -1), Vector2(12, 2)), Color(0.83, 0.72, 0.5, 0.85))
	draw_rect(Rect2(b + Vector2(-3, -2), Vector2(6, 1)), Color(0.9, 0.8, 0.58, 0.9))
