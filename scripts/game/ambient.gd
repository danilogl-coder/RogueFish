class_name Ambient
extends Node2D
## Cheap atmosphere: drifting marine snow and distant fish schools rendered in
## camera space with parallax. Purely visual.

const SNOW := 70
var _snow: Array = []
var _schools: Array = []
var _fish_tex: Texture2D
var _t := 0.0


func _ready() -> void:
	z_index = -40
	z_as_relative = false
	_fish_tex = Art.tex("creatures/sardine")
	for i in SNOW:
		_snow.append({"p": Vector2(randf() * 800.0, randf() * 460.0), "s": randf_range(0.4, 1.0), "size": 1.0 if randf() < 0.8 else 2.0, "ph": randf() * TAU})
	for i in 4:
		_schools.append(_new_school())


func _new_school() -> Dictionary:
	var dir := 1.0 if randf() < 0.5 else -1.0
	var fish := []
	for k in randi_range(5, 9):
		fish.append(Vector2(randf_range(-30, 30), randf_range(-14, 14)))
	return {"x": randf_range(-400, 400), "y": randf_range(-140, 120), "dir": dir, "speed": randf_range(12, 26), "fish": fish, "f": randf_range(0.35, 0.6)}


func _process(delta: float) -> void:
	_t += delta
	for sc in _schools:
		sc.x += sc.dir * sc.speed * delta
		if absf(sc.x) > 520:
			var n := _new_school()
			sc.merge(n, true)
			sc.x = -sc.dir * 500.0
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var c := cam.get_screen_center_position()
	var vs := get_viewport_rect().size / cam.zoom
	var depth := clampf(c.y / 1400.0, 0.0, 1.0)
	# distant schools
	var fw := 18.0
	for sc in _schools:
		var base := c * 0.55 + Vector2(sc.x, sc.y) + c * 0.45
		for off in sc.fish:
			var p: Vector2 = base + off + Vector2(0, sin(_t * 2.0 + off.x) * 2.0)
			var fr := int(_t * 8.0 + off.y) % 4
			var rect := Rect2(p.round() - Vector2(9, 5), Vector2(18 * sc.dir, 11))
			draw_texture_rect_region(_fish_tex, rect, Rect2(fr * fw, 0, fw, 11), Color(0.12, 0.28, 0.42, 0.55 - depth * 0.25))
	# marine snow
	var tl := c - vs * 0.5
	for s in _snow:
		var p2: Vector2 = s.p
		p2.y += _t * 6.0 * s.s
		p2.x += sin(_t * 0.6 + s.ph) * 6.0
		var px := Vector2(fposmod(p2.x - c.x * 0.3 * s.s, vs.x + 40.0) - 20.0, fposmod(p2.y - c.y * 0.3 * s.s, vs.y + 40.0) - 20.0)
		draw_rect(Rect2((tl + px).round(), Vector2(s.size, s.size)), Color(0.75, 0.9, 1.0, 0.25 + 0.3 * s.s))
