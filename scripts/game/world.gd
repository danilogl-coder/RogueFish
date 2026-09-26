class_name World
extends Node2D
## Builds the static ocean: backdrop, parallax, surface, seabed, decorations,
## plants (kelp), hideouts, eel rocks. Keeps lists used by AI and the director.

var game
var kelps: Array = []
var hideouts: Array = []
var eel_rocks: Array = []
var pois: Array = []
var lights: Array = []  # [{node, radius, power}]
var _parallax: Array = []
var _backdrop: TextureRect
var _backdrop_layer: CanvasLayer
var _anim_sprites: Array = []
var _anim_t := 0.0


func build() -> void:
	z_index = -20
	_build_backdrop()
	_build_parallax()
	_build_surface()
	_build_seabed()
	_build_hideouts()
	_build_kelp()
	_build_decor()
	add_child(Ambient.new())


# ---------------------------------------------------------------- backdrop
func _build_backdrop() -> void:
	_backdrop_layer = CanvasLayer.new()
	_backdrop_layer.layer = -20
	add_child(_backdrop_layer)
	_backdrop = TextureRect.new()
	_backdrop.texture = Art.tex("env/bg_backdrop")
	_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop_layer.add_child(_backdrop)


func _build_parallax() -> void:
	# [texture, factor (0 = sticks to camera, 1 = world locked), bottom y offset, z]
	var defs := [["env/bg_far", 0.12, 150.0, -60], ["env/bg_mid", 0.3, 90.0, -55], ["env/bg_near", 0.55, 30.0, -50]]
	for d in defs:
		var holder := Node2D.new()
		holder.z_index = d[3]
		holder.z_as_relative = false
		add_child(holder)
		var tex: Texture2D = Art.tex(d[0])
		for i in 4:
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			holder.add_child(s)
		_parallax.append({"node": holder, "f": d[1], "tex": tex, "bottom": d[2]})


func _build_surface() -> void:
	var sky := ColorRect.new()
	sky.color = Color("8ee8f0")
	sky.position = Vector2(-100, -300)
	sky.size = Vector2(DB.WORLD_W + 200, 302)
	sky.z_index = -45
	sky.z_as_relative = false
	add_child(sky)
	var tex := Art.tex("env/surface")
	var x := -64.0
	while x < DB.WORLD_W + 64:
		var s := Sprite2D.new()
		s.texture = tex
		s.hframes = 4
		s.centered = false
		s.position = Vector2(x, 0)
		s.z_index = -44
		s.z_as_relative = false
		add_child(s)
		_anim_sprites.append({"s": s, "fps": 5.0, "n": 4, "off": 0})
		x += 64


func _build_seabed() -> void:
	var tex := Art.tex("env/seabed")
	var x := -160.0
	while x < DB.WORLD_W + 160:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.position = Vector2(x, DB.FLOOR_Y - 13)
		s.z_index = -30
		s.z_as_relative = false
		add_child(s)
		x += 320
	var under := ColorRect.new()
	under.color = Color("2a1c24")
	under.position = Vector2(-200, DB.FLOOR_Y + 80)
	under.size = Vector2(DB.WORLD_W + 400, 400)
	under.z_index = -30
	under.z_as_relative = false
	add_child(under)


func _floor_sprite(path: String, x: float, z := -28, frames := 1, fps := 0.0, y_off := 0.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Art.tex(path)
	s.hframes = frames
	s.centered = false
	var h := float(Art.sheet_info(path).h)
	var w := float(Art.sheet_info(path).w)
	s.position = Vector2(roundf(x - w * 0.5), roundf(DB.FLOOR_Y - h + 3 + y_off))
	s.z_index = z
	s.z_as_relative = false
	add_child(s)
	if frames > 1:
		_anim_sprites.append({"s": s, "fps": fps, "n": frames, "off": randi() % frames})
	return s


func _free_x(x: float, margin: float) -> bool:
	for h in hideouts:
		if absf(h.position.x - x) < h.half_width + margin:
			return false
	for e in eel_rocks:
		if absf(e.position.x - x) < 34 + margin:
			return false
	return true


func _build_hideouts() -> void:
	var caves := [DB.WORLD_W * 0.16, DB.WORLD_W * 0.52, DB.WORLD_W * 0.86]
	for cx in caves:
		var h := Hideout.new()
		h.game = game
		h.kind = "cave"
		h.position = Vector2(cx + randf_range(-60, 60), DB.FLOOR_Y)
		add_child(h)
		hideouts.append(h)
	var thickets := [DB.WORLD_W * 0.07, DB.WORLD_W * 0.34, DB.WORLD_W * 0.68, DB.WORLD_W * 0.95]
	for tx in thickets:
		var t := Hideout.new()
		t.game = game
		t.kind = "thicket"
		t.position = Vector2(tx + randf_range(-40, 40), DB.FLOOR_Y)
		add_child(t)
		hideouts.append(t)
	for ex in [DB.WORLD_W * 0.25, DB.WORLD_W * 0.6, DB.WORLD_W * 0.78]:
		var rock := Sprite2D.new()
		rock.texture = Art.tex("env/eel_rock")
		rock.position = Vector2(ex + randf_range(-30, 30), DB.FLOOR_Y - 15)
		rock.z_index = -25
		rock.z_as_relative = false
		add_child(rock)
		eel_rocks.append(rock)


func _build_kelp() -> void:
	var n := 22
	for i in n:
		var x := (i + 0.5) / n * DB.WORLD_W + randf_range(-50, 50)
		if not _free_x(x, 10):
			x += 90
		var k := Kelp.new()
		k.game = game
		k.position = Vector2(x, DB.FLOOR_Y + 2)
		k.z_index = -12
		k.z_as_relative = false
		add_child(k)
		kelps.append(k)


func _build_decor() -> void:
	var items := ["coral_branch", "coral_branch2", "coral_fan", "coral_brain", "rock_big", "rock_mid", "rock_small",
		"starfish", "shell", "anemone", "seagrass", "seagrass", "rock_small", "coral_brain"]
	var x := 20.0
	while x < DB.WORLD_W - 20:
		x += randf_range(18, 60)
		if not _free_x(x, 12):
			continue
		var it: String = items[randi() % items.size()]
		var path := "env/" + it
		var frames := Art.frames(path)
		var s := _floor_sprite(path, x, -28 if randf() < 0.8 else 12, frames, 5.0 + randf() * 2.0)
		if it.begins_with("rock") and randf() < 0.4:
			s.flip_h = true
	# a few foreground seagrass tufts for depth
	for i in 26:
		var fx := randf() * DB.WORLD_W
		var s2 := _floor_sprite("env/seagrass", fx, 16, 4, 4.0, 4.0)
		s2.modulate = Color(0.55, 0.75, 0.8)
	# glowing anemone lights in the deep
	for i in 6:
		var ax := randf_range(100, DB.WORLD_W - 100)
		if not _free_x(ax, 10):
			continue
		var a := _floor_sprite("env/anemone", ax, -27, 4, 6.0)
		a.modulate = Color(0.8, 1.4, 1.4)
		lights.append({"node": a, "radius": 36.0, "power": 0.7})


func spawn_boss_chest(pos: Vector2) -> void:
	var p := Poi.new()
	p.game = game
	p.kind = "chest"
	p.boss_reward = true
	p.position = Vector2(clampf(pos.x, 80, DB.WORLD_W - 80), clampf(pos.y, 80, DB.FLOOR_Y - 20))
	game.layer_back.add_child(p)
	pois.append(p)


func spawn_poi(kind: String, near: Vector2) -> Poi:
	var p := Poi.new()
	p.game = game
	p.kind = kind
	var x := clampf(near.x + randf_range(260, 520) * (1 if randf() < 0.5 else -1), 120, DB.WORLD_W - 120)
	var y := DB.FLOOR_Y - 12.0
	if kind == "golden":
		y = randf_range(200, 700)
	p.position = Vector2(x, y)
	game.layer_back.add_child(p)
	pois.append(p)
	return p


func hideout_at(pos: Vector2) -> Hideout:
	for h in hideouts:
		if h.contains(pos):
			return h
	return null


func nearest_kelp(pos: Vector2, max_d := 400.0) -> Kelp:
	var best: Kelp = null
	var bd := max_d * max_d
	for k in kelps:
		if k.segments < 2:
			continue
		var d: float = k.food_pos().distance_squared_to(pos)
		if d < bd:
			bd = d
			best = k
	return best


func _process(delta: float) -> void:
	_anim_t += delta
	for a in _anim_sprites:
		var s: Sprite2D = a.s
		s.frame = (int(_anim_t * a.fps) + a.off) % a.n
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	var center := cam.get_screen_center_position()
	var vs := get_viewport_rect().size / cam.zoom
	var cam_bottom := DB.WORLD_H + 40.0 - vs.y * 0.5
	for p in _parallax:
		var node: Node2D = p.node
		var f: float = p.f
		var tw := float(p.tex.get_width())
		var th := float(p.tex.get_height())
		var base_x := center.x * (1.0 - f)
		var left := center.x - vs.x * 0.5
		var k0 := floorf((left - base_x) / tw)
		var y := DB.FLOOR_Y - th + float(p.bottom) + (center.y - cam_bottom) * (1.0 - f)
		var i := 0
		for s in node.get_children():
			s.position = Vector2(roundf(base_x + (k0 + i) * tw), roundf(y))
			i += 1
	# backdrop gets darker/bluer with depth
	var depth := clampf(center.y / DB.FLOOR_Y, 0.0, 1.0)
	_backdrop.modulate = Color(1.0, 1.0, 1.0).lerp(Color(0.45, 0.55, 0.75), depth)
