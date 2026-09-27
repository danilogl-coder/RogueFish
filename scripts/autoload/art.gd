extends Node
## Access to generated sprites (assets/art) and their metadata.

const META_PATH := "res://assets/art/art_meta.json"
## Bite timeline (fraction of the attack): anticipation, full gape, snap, recover.
const ACT_STEPS := [0.14, 0.52, 0.8]

var meta: Dictionary = {}
var _tex_cache: Dictionary = {}
var _icon_cache: Dictionary = {}
var font: FontFile      # UI text (Pixelify Sans, full PT-BR accents)
var num_font: FontFile  # numbers / damage (Press Start 2P)


func _ready() -> void:
	var f := FileAccess.open(META_PATH, FileAccess.READ)
	if f:
		meta = JSON.parse_string(f.get_as_text())
	font = load("res://assets/fonts/PixelifySans-SemiBold.ttf")
	num_font = load("res://assets/fonts/PressStart2P-Regular.ttf")
	for f2 in [font, num_font]:
		f2.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f2.hinting = TextServer.HINTING_NONE
		f2.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	_debug_screenshot()


## Debug: `-- --shot=/path.png --shot-delay=2` saves a screenshot and quits.
func _debug_screenshot() -> void:
	var path := ""
	var delay := 2.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			path = a.substr(7)
		elif a.begins_with("--shot-delay="):
			delay = float(a.substr(13))
	if path == "":
		return
	await get_tree().create_timer(delay, true, false, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


func tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = load("res://assets/art/%s.png" % path)
	_tex_cache[path] = t
	return t


func sheet_info(path: String) -> Dictionary:
	return meta.get("sheets", {}).get(path, {"frames": 1, "w": 16, "h": 16})


func frames(path: String) -> int:
	return int(sheet_info(path).frames)


## Swim / action frame split of a creature sheet: Vector2i(swim, act).
## Fish sheets have 6 swim + 4 bite frames; older sheets 4 + 2.
func anim(path: String) -> Vector2i:
	var info := sheet_info(path)
	var n := int(info.frames)
	if info.has("swim"):
		return Vector2i(int(info.swim), int(info.get("act", 0)))
	if n >= 6:
		return Vector2i(4, 2)
	return Vector2i(n, 0)


## Maps attack progress (0..1) to an action frame offset.
func act_frame(progress: float, act_count: int) -> int:
	if act_count <= 0:
		return 0
	if act_count == 2:
		return 0 if progress < 0.6 else 1
	var i := 0
	for step in ACT_STEPS:
		if progress >= step:
			i += 1
	return mini(i, act_count - 1)


## Creates a Sprite2D configured for a horizontal sheet.
func sprite(path: String, centered := true) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex(path)
	s.hframes = maxi(1, frames(path))
	s.centered = centered
	return s


func icon(name: String) -> Texture2D:
	if _icon_cache.has(name):
		return _icon_cache[name]
	var idx: int = int(meta.get("icons", {}).get(name, 0))
	var at := AtlasTexture.new()
	at.atlas = tex("ui/icons")
	at.region = Rect2((idx % 8) * 16, (idx / 8) * 16, 16, 16)
	_icon_cache[name] = at
	return at


func player_meta(species: String, stage: int) -> Dictionary:
	return meta.get("player", {}).get("%s_%d" % [species, stage], {})


func player_tex(species: String, stage: int) -> Texture2D:
	return tex("player/%s_%d" % [species, stage])


## Row of a layer inside a species/stage atlas (row names live in art_meta.json).
func layer_row(species: String, stage: int, layer: String) -> int:
	var rows: Array = player_meta(species, stage).get("layers", [])
	return maxi(0, rows.find(layer))


## Returns the atlas region of a player layer frame.
func player_region(species: String, stage: int, layer: String, frame: int) -> Rect2:
	var m := player_meta(species, stage)
	var fw := float(m.get("frame_w", 46))
	var fh := float(m.get("frame_h", 32))
	return Rect2(frame * fw, layer_row(species, stage, layer) * fh, fw, fh)


## Swim / bite frame split of the player atlases.
func player_anim(species: String, stage: int) -> Vector2i:
	var m := player_meta(species, stage)
	return Vector2i(int(m.get("swim", 4)), int(m.get("act", 2)))


## Ordered layers (back to front) for a given mutation set {slot: mutation_id}.
## Head and skin mutations are baked into the body row (the jaw, rostrum or
## lure are part of the head), tails and fins are separate rows.
func player_layers(mutations: Dictionary) -> Array:
	var tail := "tail"
	var fins_b := "fins_back"
	var fins_f := "fins_front"
	var t: String = mutations.get("tail", "")
	if t != "":
		tail = t
	var fi: String = mutations.get("fins", "")
	if fi != "":
		fins_b = fi + "_back"
		fins_f = fi + "_front"
	var body := "body"
	var head: String = mutations.get("head", "")
	var skin: String = mutations.get("skin", "")
	if head != "":
		body += "+" + head
	if skin != "":
		body += "+" + skin
	return [tail, fins_b, body, fins_f]
