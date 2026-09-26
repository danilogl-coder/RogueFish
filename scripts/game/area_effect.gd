class_name AreaEffect
extends Node2D
## Persistent zones: ink/poison clouds, whirlpools. Damages on ticks,
## can slow and pull. hostile=true zones hurt the player instead.

var game
var radius := 24.0
var duration := 3.0
var dps := 5.0
var slow := 0.0
var poison := 0.0
var pull := 0.0
var pull_pickups := false
var hostile := false
var follow: Node2D
var follow_lag := 3.0
var source := "area"
var sprite: Sprite2D
var tick := 0.4
var alpha := 0.9
var _tick_t := 0.0
var _t := 0.0
var _base_scale := 1.0


func setup_cloud(sheet: String, pos: Vector2, p_radius: float, p_duration: float, p_dps: float, p_slow: float, p_poison := false) -> AreaEffect:
	position = pos
	radius = p_radius
	duration = p_duration
	dps = p_dps
	slow = p_slow
	poison = p_dps if p_poison else 0.0
	sprite = Art.sprite(sheet)
	add_child(sprite)
	if sheet == "fx/ink_cloud":
		alpha = 0.62
	_base_scale = radius * 2.2 / float(Art.sheet_info(sheet).w)
	sprite.scale = Vector2.ZERO
	return self


func setup_whirl(pos: Vector2, p_radius: float, p_duration: float, p_dps: float, p_pull: float) -> AreaEffect:
	setup_cloud("fx/whirlpool", pos, p_radius, p_duration, p_dps, 0.0)
	pull = p_pull
	_base_scale = radius * 2.1 / 48.0
	return self


func _physics_process(delta: float) -> void:
	_t += delta
	if duration > 0.0 and _t >= duration:
		queue_free()
		return
	if follow and is_instance_valid(follow):
		position = position.lerp(follow.position, 1.0 - pow(0.5, delta * follow_lag))
	var grow := clampf(_t / 0.25, 0.0, 1.0)
	var fade := clampf((duration - _t) / 0.4, 0.0, 1.0) if duration > 0.0 else 1.0
	sprite.scale = Vector2.ONE * _base_scale * grow * (0.8 + 0.2 * fade)
	sprite.modulate.a = fade * alpha
	sprite.frame = int(_t * 8.0) % sprite.hframes
	if pull > 0.0:
		sprite.rotation -= delta * 3.0
		for c in game.grid.query(position, radius * 1.4):
			if c.is_boss or c.dead:
				continue
			var d: Vector2 = position - c.position
			if d.length() > 4.0:
				c.knock += d.normalized() * pull * delta * 6.0
		if pull_pickups:
			for pk in game.pickups:
				if is_instance_valid(pk) and pk.kind == "xp" and pk.position.distance_to(position) < radius * 1.5:
					pk.attracted = true
	_tick_t -= delta
	if _tick_t > 0.0:
		return
	_tick_t = tick
	if hostile:
		var p: Player = game.player
		if p.position.distance_to(position) < radius + p.radius:
			if dps > 0.0:
				p.take_damage(dps * tick * 2.0, null)
			if slow > 0.0:
				p.apply_slow(slow, 0.6)
		return
	for c in game.grid.query(position, radius):
		if c.dead:
			continue
		var info := {"source": source, "hit_id": get_instance_id(), "dot": true, "color": Color("a4dc4c") if poison > 0.0 else Color("8ee8f0")}
		if slow > 0.0:
			info.slow = slow
			info.slow_time = 0.6
		if poison > 0.0:
			info.poison = poison * game.player.st.poison_mult
		if dps > 0.0:
			c.take_damage(dps * tick * game.player.st.damage_mult, info)
		elif slow > 0.0:
			c.slow_amt = slow
			c.slow_t = 0.6
