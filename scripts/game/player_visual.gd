class_name PlayerVisual
extends Node2D
## Layered player sprite: each mutation slot is its own Sprite2D sharing the
## species/stage atlas, all animated on the same frame.

var species := "dourado"
var stage := 0
var mutations: Dictionary = {}
var sprites: Array[Sprite2D] = []
var glow: Sprite2D
var lure_glow: Sprite2D
var frame := 0
var swim_frames := 6
var act_frames := 4
var _meta: Dictionary
var _center := Vector2.ZERO


func set_look(p_species: String, p_stage: int, p_mutations: Dictionary) -> void:
	species = p_species
	stage = p_stage
	mutations = p_mutations.duplicate()
	for s in sprites:
		s.queue_free()
	sprites.clear()
	_meta = Art.player_meta(species, stage)
	var an := Art.player_anim(species, stage)
	swim_frames = an.x
	act_frames = an.y
	var tex := Art.player_tex(species, stage)
	var center := Vector2(_meta.center[0], _meta.center[1])
	_center = center
	for layer in Art.player_layers(mutations):
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.region_enabled = true
		s.offset = -center.round()
		s.set_meta("layer", layer)
		add_child(s)
		sprites.append(s)
	_update_glows(center)
	set_frame(frame)


func _update_glows(center: Vector2) -> void:
	if lure_glow:
		lure_glow.queue_free()
		lure_glow = null
	if glow:
		glow.queue_free()
		glow = null
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	if mutations.get("head", "") == "head_lure":
		lure_glow = Sprite2D.new()
		lure_glow.texture = Art.tex("fx/glow")
		lure_glow.material = add_mat
		lure_glow.modulate = Color(0.5, 1.0, 0.9, 0.55)
		lure_glow.scale = Vector2(0.35, 0.35)
		add_child(lure_glow)
		_place_lure()
	if mutations.get("skin", "") == "skin_glow":
		glow = Sprite2D.new()
		glow.texture = Art.tex("fx/glow")
		glow.material = add_mat
		glow.modulate = Color(0.3, 0.9, 0.9, 0.25)
		glow.scale = Vector2(1.0, 0.6) * (0.5 + stage * 0.12)
		add_child(glow)
		move_child(glow, 0)


func set_frame(f: int) -> void:
	frame = f
	if _meta.is_empty():
		return
	for s in sprites:
		s.region_rect = Art.player_region(species, stage, s.get_meta("layer"), f)
	_place_lure()


## The lure bulb sways with the swim cycle; its glow follows the baked frame.
func _place_lure() -> void:
	if lure_glow == null or _meta.is_empty():
		return
	var lures: Array = _meta.get("lure", [])
	if lures.is_empty():
		return
	var p: Array = lures[clampi(frame, 0, lures.size() - 1)]
	lure_glow.position = Vector2(p[0], p[1]) - _center


func flash(on: bool) -> void:
	modulate = Color(6, 6, 6) if on else Color.WHITE


func pulse_glows(t: float) -> void:
	if lure_glow:
		lure_glow.modulate.a = 0.45 + 0.2 * sin(t * 4.0)
	if glow:
		glow.modulate.a = 0.18 + 0.1 * sin(t * 2.5)
