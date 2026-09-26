extends Boss
## Kraken: hovers above the player, slams tentacles on telegraphed spots and
## fires ink volleys. Enraged: double slams and summons squids.

const TENTACLES := 6
const SEGS := 11
var _tent: Array = []   # {root_off, tip, target, mode, t}
var _seg_tex: Texture2D
var _slam_t := 2.5
var _ink_t := 5.0
var _summon_t := 10.0


func _setup() -> void:
	sprite = Art.sprite("creatures/kraken_head")
	add_child(sprite)
	sprite.position = Vector2(0, -10)
	scale = Vector2(2, 2)
	radius = 52.0
	speed = 95.0
	anim_fps = 5.0
	_seg_tex = Art.tex("creatures/kraken_segment")
	for i in TENTACLES:
		var ox := lerpf(-22.0, 22.0, float(i) / (TENTACLES - 1))
		_tent.append({"root": Vector2(ox, 24.0) * 2.0, "tip": position + Vector2(ox * 4.0, 180.0), "target": Vector2.ZERO, "mode": "idle", "t": 0.0, "part": add_part(14.0, contact_damage * 0.5)})


func think(delta: float) -> void:
	var p: Player = game.player
	var want := p.position + Vector2(0, -150)
	want.y = clampf(want.y, 90.0, DB.FLOOR_Y - 200.0)
	seek(want, speed, 60.0, delta)
	_slam_t -= delta
	_ink_t -= delta
	_summon_t -= delta
	if _slam_t <= 0.0:
		_slam_t = 2.2 if not enraged else 1.6
		_start_slam(p.position + p.vel * 0.4)
		if enraged:
			_start_slam(p.position + Vector2(randf_range(-80, 80), randf_range(-40, 40)))
	if _ink_t <= 0.0:
		_ink_t = 4.5
		_ink_volley(7 if enraged else 5)
	if enraged and _summon_t <= 0.0:
		_summon_t = 12.0
		summon("squid", 2)
	_update_tentacles(delta)


func _start_slam(at: Vector2) -> void:
	var free := []
	for t in _tent:
		if t.mode == "idle":
			free.append(t)
	if free.is_empty():
		return
	free.sort_custom(func(a, b): return (position + a.root).distance_to(at) < (position + b.root).distance_to(at))
	var t: Dictionary = free[0]
	at.y = minf(at.y, DB.FLOOR_Y - 10.0)
	t.mode = "wind"
	t.t = 0.0
	t.target = at
	telegraph_circle(at, 30.0, 0.9)


func _ink_volley(n: int) -> void:
	var p: Player = game.player
	var base := (p.position - position).angle()
	for i in n:
		var a := base + (i - (n - 1) * 0.5) * 0.22
		var pr := Projectile.new().setup("fx/ink_ball", Vector2.from_angle(a) * 120.0, 9.0 * dmg_mult, 3.5, 5.0)
		pr.hostile = true
		pr.slow = 0.4
		pr.position = position + Vector2(0, 40)
		game.spawn_projectile(pr)
	attack_anim = 0.4
	Sfx.play("ink", -2.0)


func _update_tentacles(delta: float) -> void:
	var i := 0
	for t in _tent:
		t.t += delta
		var root: Vector2 = position + t.root
		var rest: Vector2 = root + Vector2(t.root.x * 1.6 + sin(anim_t * 1.5 + i) * 30.0, 150.0 + cos(anim_t * 1.2 + i * 0.7) * 20.0)
		match t.mode:
			"idle":
				t.tip = t.tip.lerp(rest, 1.0 - pow(0.05, delta))
			"wind":
				var back: Vector2 = root + (root - t.target).normalized() * 70.0 + Vector2(0, -30)
				t.tip = t.tip.lerp(back, 1.0 - pow(0.01, delta))
				if t.t > 0.9:
					t.mode = "slam"
					t.t = 0.0
			"slam":
				t.tip = t.tip.lerp(t.target, 1.0 - pow(0.0001, delta))
				if t.t > 0.12 and t.t - delta <= 0.12:
					hurt_player_in(t.target, 30.0, 26.0)
					game.shake(5.0)
					game.burst(t.target, [0, 1, 3], 10, 80.0, 0.6)
					Sfx.play("hit", 0.0)
				if t.t > 0.7:
					t.mode = "idle"
					t.t = 0.0
		t.part.position = t.tip
		i += 1
	queue_redraw()


func _draw() -> void:
	for t in _tent:
		var root: Vector2 = t.root / scale.x
		var tip: Vector2 = to_local(t.tip)
		var mid: Vector2 = (root + tip) * 0.5 + Vector2(sin(anim_t * 2.0 + root.x) * 16.0, 10.0)
		for k in SEGS:
			var u := float(k) / (SEGS - 1)
			var pt: Vector2 = root.lerp(mid, u).lerp(mid.lerp(tip, u), u)
			var sc := lerpf(1.2, 0.6, u)
			var fr := 3 if k == SEGS - 1 else k % 2
			var sz := Vector2(14, 14) * sc
			draw_texture_rect_region(_seg_tex, Rect2(pt - sz * 0.5, sz), Rect2(fr * 14, 0, 14, 14))
