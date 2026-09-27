class_name World
extends Node2D
## Builds the ocean: backdrop, parallax, surface, a variable-depth seabed across
## four biomes (reef, kelp forest, continental slope, abyssal trench), their
## decor, plants, hideouts, eel rocks, hydrothermal vents and a whale fall.

signal biome_entered(biome: Dictionary)

var game
var kelps: Array = []
var hideouts: Array = []
var eel_rocks: Array = []
var vents: Array = []          # hydrothermal vents (nutrient sources)
var whale_falls: Array = []    # big carcass that feeds the abyss
var pois: Array = []
var lights: Array = []  # [{node, radius, power}]
var _parallax: Array = []
var _backdrop: TextureRect
var _backdrop_layer: CanvasLayer
var _anim_sprites: Array = []
var _anim_t := 0.0
var _biome_id := ""
var _tint := Color.WHITE


func build() -> void:
	z_index = -20
	_build_backdrop()
	_build_parallax()
	_build_surface()
	var bed := Seabed.new()
	add_child(bed)
	# the lip of the sand is drawn in front of props, planting their bases
	var lip := Seabed.new()
	lip.front = true
	add_child(lip)
	_build_hideouts()
	_build_kelp()
	_build_decor()
	_build_abyss()
	add_child(Ambient.new())


func floor_at(x: float) -> float:
	return DB.floor_at(x)


# ---------------------------------------------------------------- backdrop
func _build_backdrop() -> void:
	_backdrop_layer = CanvasLayer.new()
	_backdrop_layer.layer = -20
	add_child(_backdrop_layer)
	_backdrop = TextureRect.new()
	_backdrop.texture = Art.tex("env/bg_backdrop")
	_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop_layer.add_child(_backdrop)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE


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


func _floor_sprite(path: String, x: float, z := -28, frames := 1, fps := 0.0, y_off := 0.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Art.tex(path)
	s.hframes = frames
	s.centered = false
	var h := float(Art.sheet_info(path).h)
	var w := float(Art.sheet_info(path).w)
	# rest on the lowest point under the footprint: no corner hangs in the water
	var gy := DB.ground_under(x, w * 0.4)
	s.position = Vector2(roundf(x - w * 0.5), roundf(gy - h + 3 + y_off))
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
	for v in vents:
		if absf(v.x - x) < 30 + margin:
			return false
	for w in whale_falls:
		if absf(w.x - x) < 75 + margin:
			return false
	for r in DB.terrain.get("rocks", []):
		if absf(float(r[0]) - x) < float(r[1]) * 0.5 + margin * 0.5:
			return false
	return true


func _add_hideout(kind: String, x: float) -> void:
	var h := Hideout.new()
	h.game = game
	h.kind = kind
	h.position = Vector2(x, floor_at(x))
	add_child(h)
	hideouts.append(h)


func _build_hideouts() -> void:
	# hideouts and eel rocks sit on flat shelves carved into the terrain
	for x in _sites("cave", [260.0, 1050.0, 3452.0, 4050.0, 4620.0]):
		if x < DB.WORLD_W - 40.0:
			_add_hideout("cave", x)
	for x in _sites("thicket", [700.0, 1700.0, 2150.0, 2600.0, 3000.0]):
		_add_hideout("thicket", x)
	for ex in _sites("eel_rock", [520.0, 830.0, 1310.0]):
		var rock := Sprite2D.new()
		rock.texture = Art.tex("env/eel_rock")
		var x2: float = ex
		var eh := float(Art.sheet_info("env/eel_rock").h)
		rock.position = Vector2(x2, roundf(DB.ground_under(x2, 20.0) - eh * 0.5 + 3.0))
		rock.z_index = -25
		rock.z_as_relative = false
		add_child(rock)
		eel_rocks.append(rock)


func _sites(kind: String, fallback: Array) -> Array:
	var got: Array = DB.sites(kind)
	return got if not got.is_empty() else fallback


func _add_kelp(x: float) -> void:
	if not _free_x(x, 6):
		return
	var k := Kelp.new()
	k.game = game
	k.position = Vector2(x, floor_at(x) + 2)
	k.z_index = -12
	k.z_as_relative = false
	add_child(k)
	kelps.append(k)


func _build_kelp() -> void:
	# kelp forest: dense; reef: sparse
	var x := 1500.0
	while x < 3100.0:
		_add_kelp(x + randf_range(-12, 12))
		x += randf_range(38, 70)
	for i in 7:
		_add_kelp(randf_range(120, 1400))


func _build_decor() -> void:
	# rocks, shells, pebbles and bacterial mats are baked into the terrain;
	# living decor stays as sprites
	var by_biome := {
		"reef": ["coral_branch", "coral_branch2", "coral_fan", "coral_brain", "anemone", "coral_branch", "coral_fan", "anemone", "seagrass"],
		"kelp": ["seagrass", "seagrass", "seagrass", "coral_brain", "anemone"],
		"slope": ["seagrass", "anemone", "coral_fan"],
		"abyss": ["glow_mushroom", "tube_worms", "glow_mushroom", "anemone"],
		"vents": ["tube_worms", "tube_worms", "glow_mushroom"],
	}
	var x := 20.0
	while x < DB.WORLD_W - 20:
		var b: Dictionary = DB.biome_at(x)
		x += randf_range(14, 40) if b.id == "reef" else randf_range(22, 64)
		if not _free_x(x, 12):
			continue
		var items: Array = by_biome[b.id]
		var it: String = items[randi() % items.size()]
		var path := "env/" + it
		# only on level ground: a prop on a cliff face would look glued to it
		if DB.ground_unevenness(x, Art.sheet_info(path).w * 0.4) > 5.0:
			continue
		var frames := Art.frames(path)
		var s := _floor_sprite(path, x, -28 if randf() < 0.82 else 12, frames, 5.0 + randf() * 2.0)
		if randf() < 0.5 and not it.begins_with("coral_branch"):
			s.flip_h = true
		if it == "glow_mushroom" or it == "anemone" and b.id == "abyss":
			lights.append({"node": s, "radius": 34.0, "power": 0.75})
	# foreground seagrass tufts for depth (shallow biomes only)
	for i in 34:
		var fx := randf_range(0, 3150)
		if DB.ground_unevenness(fx, 7.0) > 5.0:
			continue
		var s2 := _floor_sprite("env/seagrass", fx, 16, 4, 4.0, 4.0)
		s2.modulate = Color(0.55, 0.75, 0.8)


func _build_abyss() -> void:
	# hydrothermal vents: chemosynthesis feeds the dark food web
	for vx in _sites("vent", [3930.0, 4480.0, 4740.0]):
		var x: float = vx
		if x >= DB.WORLD_W - 20.0:
			continue
		var s := _floor_sprite("env/black_smoker", x, -26)
		if x > DB.BASE_WORLD_W:
			# the hydrothermal field's chimneys erupt
			var ch := Chimney.new()
			ch.game = game
			ch.position = Vector2(x, floor_at(x) - float(Art.sheet_info("env/black_smoker").h) + 4.0)
			add_child(ch)
			s.modulate = Color(1.1, 0.9, 0.85)
		vents.append(Vector2(x, floor_at(x) - 60))
		lights.append({"node": s, "radius": 70.0, "power": 0.85})
		for k in 3:
			var tw := _floor_sprite("env/tube_worms", x + (18.0 + randf_range(0, 26)) * (1 if k % 2 == 0 else -1), -27, 4, 4.0)
			tw.modulate = Color(1.1, 1.0, 1.0)
	# whale fall: an enormous carcass that feeds scavengers for decades
	var wx: float = _sites("whale", [4300.0])[0]
	var bones := _floor_sprite("env/whale_bones", wx, -26)
	bones.modulate = Color(0.85, 0.85, 0.9)
	whale_falls.append(Vector2(wx, floor_at(wx) - 16))


func spawn_boss_chest(pos: Vector2) -> void:
	var p := Poi.new()
	p.game = game
	p.kind = "chest"
	p.boss_reward = true
	var x := clampf(pos.x, 80, DB.WORLD_W - 80)
	p.position = Vector2(x, clampf(pos.y, 80, floor_at(x) - 20))
	game.layer_back.add_child(p)
	pois.append(p)


func spawn_poi(kind: String, near: Vector2) -> Poi:
	var p := Poi.new()
	p.game = game
	p.kind = kind
	var x := clampf(near.x + randf_range(260, 520) * (1 if randf() < 0.5 else -1), 120, DB.WORLD_W - 120)
	# POI sprites are drawn from their origin up, so the origin rests on the sand
	var y := DB.ground_under(x, 18.0) + 1.0
	if kind == "golden":
		y = randf_range(200, minf(700.0, floor_at(x) - 60.0))
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
	var local_floor := floor_at(center.x)
	var cam_bottom := local_floor + 92.0 - vs.y * 0.5
	for p in _parallax:
		var node: Node2D = p.node
		var f: float = p.f
		var tw := float(p.tex.get_width())
		var th := float(p.tex.get_height())
		var base_x := center.x * (1.0 - f)
		var left := center.x - vs.x * 0.5
		var k0 := floorf((left - base_x) / tw)
		var y := local_floor - th + float(p.bottom) + (center.y - cam_bottom) * (1.0 - f)
		var i := 0
		for s in node.get_children():
			s.position = Vector2(roundf(base_x + (k0 + i) * tw), roundf(y))
			i += 1
	# biome tint blended with depth darkening
	var b: Dictionary = DB.biome_at(center.x)
	_tint = _tint.lerp(b.tint, 1.0 - pow(0.3, delta))
	var depth := clampf(center.y / 1450.0, 0.0, 1.0)
	_backdrop.modulate = _tint.lerp(Color(0.35, 0.4, 0.6), depth * 0.8)
	var p2: Vector2 = game.player.position if game and game.player else center
	var pb: Dictionary = DB.biome_at(p2.x)
	if pb.id != _biome_id:
		_biome_id = pb.id
		biome_entered.emit(pb)
