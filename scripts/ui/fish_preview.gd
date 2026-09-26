class_name FishPreview
extends Control
## Draws an animated player fish (with mutations) inside UI.

var species := "dourado"
var stage := 1
var mutations: Dictionary = {}
var pixel_scale := 2.0
var animate := true
var flip := false
var _t := 0.0


func setup(p_species: String, p_stage: int, p_mutations := {}, p_scale := 2.0) -> FishPreview:
	species = p_species
	stage = p_stage
	mutations = p_mutations
	pixel_scale = p_scale
	var m := Art.player_meta(species, stage)
	custom_minimum_size = Vector2(float(m.get("frame_w", 46)), float(m.get("frame_h", 32))) * pixel_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()
	return self


func _process(delta: float) -> void:
	if animate and is_visible_in_tree():
		_t += delta
		queue_redraw()


func _draw() -> void:
	var m := Art.player_meta(species, stage)
	if m.is_empty():
		return
	var tex := Art.player_tex(species, stage)
	var fw := float(m.frame_w) * pixel_scale
	var fh := float(m.frame_h) * pixel_scale
	var frame := int(_t * 7.0) % 4
	var bob := roundf(sin(_t * 2.2) * pixel_scale) if animate else 0.0
	var pos := (size - Vector2(fw, fh)) * 0.5 + Vector2(0, bob)
	if flip:
		draw_set_transform(Vector2(size.x, 0), 0.0, Vector2(-1, 1))
	for layer in Art.player_layers(mutations):
		var region := Art.player_region(species, stage, layer, frame)
		draw_texture_rect_region(tex, Rect2(pos, Vector2(fw, fh)), region)
