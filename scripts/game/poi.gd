class_name Poi
extends Node2D
## Timed points of interest: treasure chest, giant clam (heal), thermal vent
## (damage buff, guarded by crabs), golden school (XP + pearls).

var game
var kind := "chest"
var boss_reward := false
var life := 40.0
var opened := false
var progress := 0.0
var radius := 16.0
var sprite: Sprite2D
var _hits := 0
var _t := 0.0
var _fish: Array = []
var _light := {}


func _ready() -> void:
	match kind:
		"chest":
			sprite = Art.sprite("env/chest")
			sprite.position = Vector2(0, -10)
			radius = 16.0
			life = 999.0 if boss_reward else 40.0
		"clam":
			sprite = Art.sprite("env/clam")
			sprite.position = Vector2(0, -12)
			radius = 34.0
		"vent":
			sprite = Art.sprite("env/vent")
			sprite.position = Vector2(0, -11)
			radius = 42.0
			for i in 3:
				game.spawn_creature("crab", position + Vector2(randf_range(-60, 60), -4), {"force": true})
		"golden":
			life = 26.0
			for i in 8:
				var c: Creature = game.spawn_creature("golden", position + Vector2(randf_range(-30, 30), randf_range(-20, 20)), {"force": true})
				if c:
					_fish.append(c)
	if sprite:
		add_child(sprite)
		_light = {"node": self, "radius": 50.0, "power": 0.7}
		game.world.lights.append(_light)


func bite() -> void:
	if opened or kind != "chest":
		return
	_hits += 1
	game.shake(2.0)
	Sfx.play("hit")
	var tw := create_tween()
	tw.tween_property(sprite, "rotation", 0.2, 0.05)
	tw.tween_property(sprite, "rotation", -0.2, 0.05)
	tw.tween_property(sprite, "rotation", 0.0, 0.05)
	if _hits >= 3:
		opened = true
		sprite.frame = 1
		Sfx.play("chest")
		game.burst(position + Vector2(0, -12), [4, 7, 0], 16, 80.0, 0.8)
		game.add_pearls(5 if not boss_reward else 15)
		game.open_treasure(boss_reward)
		life = 3.0


func _physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	var p: Player = game.player
	var near := p.alive and p.position.distance_to(position + Vector2(0, -10)) < radius + p.radius
	match kind:
		"clam":
			if not opened:
				if near:
					progress += delta
				else:
					progress = maxf(0.0, progress - delta * 0.5)
				sprite.frame = 1 if progress > 0.0 else 0
				if progress >= 2.5:
					opened = true
					sprite.frame = 2
					p.heal(p.st.max_hp * 0.4)
					game.add_pearls(8)
					Sfx.play("heal")
					game.burst(position + Vector2(0, -14), [7, 0, 1], 14, 60.0, 0.8)
					life = 3.0
		"vent":
			if _t > 0.25:
				game.burst(position + Vector2(randf_range(-4, 4), -22), [0, 1], 1, 20.0, 1.2)
				_t = 0.0
			if not opened:
				if near:
					progress += delta
				if progress >= 2.0:
					opened = true
					p.add_buff("vent", 30.0)
					game.float_text(p.position + Vector2(0, -24), "FÚRIA TÉRMICA +30%", Color("ff9a5c"), 8)
					Sfx.play("evolve")
					life = 4.0
		"golden":
			var any := false
			for f in _fish:
				if is_instance_valid(f) and not f.dead:
					any = true
			if not any:
				life = 0.0
	if life <= 0.0:
		if kind == "golden":
			for f in _fish:
				if is_instance_valid(f) and not f.dead:
					f.dead = true
					f.queue_free()
		game.world.pois.erase(self)
		game.world.lights.erase(_light)
		queue_free()
	elif life < 5.0 and sprite:
		sprite.visible = int(life * 8.0) % 2 == 0
	queue_redraw()


func is_active() -> bool:
	return not opened and life > 0.0


func _draw() -> void:
	if opened or kind == "golden":
		return
	if kind != "chest" or not boss_reward:
		var w := 26.0
		var k := clampf(life / 40.0, 0.0, 1.0)
		draw_rect(Rect2(-w * 0.5 - 1, 8, w + 2, 4), Color(0.02, 0.04, 0.08, 0.8))
		draw_rect(Rect2(-w * 0.5, 9, w * k, 2), Color("ffbf45"))
	if progress > 0.0:
		var need := 2.5 if kind == "clam" else 2.0
		draw_arc(Vector2(0, -12), radius * 0.6, -PI * 0.5, -PI * 0.5 + TAU * progress / need, 24, Color("a4dc4c"), 2.0)
	if kind == "clam" or kind == "vent":
		draw_arc(Vector2(0, -10), radius, 0, TAU, 32, Color(1, 1, 1, 0.15 + 0.1 * sin(_t * 4.0)), 1.0)
	if kind == "chest" and _hits < 3:
		var s := tr("MORDA x%d") % (3 - _hits)
		var f: Font = Art.num_font
		var tw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x * 0.5
		draw_set_transform(Vector2(-tw * 0.5, -30), 0, Vector2(0.5, 0.5))
		draw_string_outline(f, Vector2.ZERO, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 6, Color(0.02, 0.04, 0.08))
		draw_string(f, Vector2.ZERO, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ffbf45"))
