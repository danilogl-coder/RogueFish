class_name Ambient
extends Node2D
## Cheap atmosphere: drifting marine snow (camera space, only underwater) and
## distant fish schools (world depth, horizontal parallax). Purely visual.

const SNOW := 70
var _snow: Array = []
var _schools: Array = []
var _kinds: Array = []          # [{tex, w, h, swim}] distant school species
var _t := 0.0
const PARALLAX := 0.45          ## schools drift at 45% of the camera's horizontal motion


func _ready() -> void:
	z_index = -40
	z_as_relative = false
	for sheet in ["creatures/sardine", "creatures/lanternfish"]:
		var info := Art.sheet_info(sheet)
		_kinds.append({"tex": Art.tex(sheet), "w": float(info.w), "h": float(info.h), "swim": Art.anim(sheet).x})
	for i in SNOW:
		_snow.append({"p": Vector2(randf() * 800.0, randf() * 460.0), "s": randf_range(0.4, 1.0), "size": 1.0 if randf() < 0.8 else 2.0, "ph": randf() * TAU})
	for i in 4:
		var sc := {}
		_respawn(sc, true)
		_schools.append(sc)


## Schools live in the world (their depth never changes) but slide with
## parallax horizontally, so they never follow you above the surface.
func _respawn(sc: Dictionary, anywhere: bool) -> void:
	var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
	var c: Vector2 = cam.get_screen_center_position() if cam else Vector2(2350, 420)
	var dir := 1.0 if randf() < 0.5 else -1.0
	var bx := c.x * PARALLAX
	var off := randf_range(-420.0, 420.0) if anywhere else -dir * randf_range(420.0, 560.0)
	var wx := c.x + off
	var fl := DB.floor_at(clampf(wx, 0.0, DB.WORLD_W))
	var y := clampf(c.y + randf_range(-160.0, 160.0), DB.SURFACE_Y + 40.0, fl - 60.0)
	var deep := y > DB.WORLD_H * 0.5
	var fish := []
	for k in randi_range(5, 9):
		fish.append(Vector2(randf_range(-34, 34), randf_range(-14, 14)).round())
	sc.merge({"bx": bx + off, "y": y, "dir": dir, "speed": randf_range(10, 22), "fish": fish,
		"kind": 1 if deep and randf() < 0.7 else 0}, true)


func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_2d()
	if cam:
		var c := cam.get_screen_center_position()
		var vs := get_viewport_rect().size / cam.zoom
		for sc in _schools:
			sc.bx += sc.dir * sc.speed * delta
			var sx: float = sc.bx + c.x * (1.0 - PARALLAX)
			if absf(sx - c.x) > vs.x * 0.5 + 140.0 or absf(sc.y - c.y) > vs.y * 0.5 + 200.0:
				_respawn(sc, false)
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var c := cam.get_screen_center_position()
	var vs := get_viewport_rect().size / cam.zoom
	# distant schools: whole frames of the real sprite sheets, haze-tinted
	for sc in _schools:
		var k: Dictionary = _kinds[sc.kind]
		var w: float = k.w
		var h: float = k.h
		var base := Vector2(sc.bx + c.x * (1.0 - PARALLAX), sc.y)
		var depth := clampf(sc.y / DB.WORLD_H, 0.0, 1.0)
		var tint := Color(0.3, 0.5, 0.65, 0.5 - depth * 0.2)
		for off in sc.fish:
			var p: Vector2 = base + off + Vector2(0, sin(_t * 2.0 + off.x) * 2.0)
			if p.y < DB.SURFACE_Y + 16.0 or p.y > DB.floor_at(clampf(p.x, 0.0, DB.WORLD_W)) - 10.0:
				continue
			var fr := int(_t * 9.0 + off.y * 0.7) % int(k.swim)
			var tl := (p - Vector2(w, h) * 0.5).round()
			var dst := Rect2(tl, Vector2(w, h)) if sc.dir > 0.0 else Rect2(tl + Vector2(w, 0), Vector2(-w, h))
			draw_texture_rect_region(k.tex, dst, Rect2(fr * w, 0, w, h), tint)
	# marine snow
	var tl0 := c - vs * 0.5
	for s in _snow:
		var p2: Vector2 = s.p
		p2.y += _t * 6.0 * s.s
		p2.x += sin(_t * 0.6 + s.ph) * 6.0
		var px := Vector2(fposmod(p2.x - c.x * 0.3 * s.s, vs.x + 40.0) - 20.0, fposmod(p2.y - c.y * 0.3 * s.s, vs.y + 40.0) - 20.0)
		var wp := (tl0 + px).round()
		if wp.y < DB.SURFACE_Y + 6.0:
			continue  # no snow in the air above the surface
		draw_rect(Rect2(wp, Vector2(s.size, s.size)), Color(0.75, 0.9, 1.0, 0.25 + 0.3 * s.s))
