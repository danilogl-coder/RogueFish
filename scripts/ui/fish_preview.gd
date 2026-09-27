class_name FishPreview
extends Control
## Draws an animated player fish (with mutations) inside UI.

var species := "dourado"
var stage := 1
var mutations: Dictionary = {}
var pixel_scale := 2.0
var animate := true
var flip := false
var box := Vector2.ZERO        ## fit mode: fixed box, integer scale, centred on the body
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


## Fits the character inside a fixed box (thumbnails, detail panels).
func fit(p_box: Vector2, max_scale := 4.0) -> FishPreview:
	box = p_box
	custom_minimum_size = box
	var m := Art.player_meta(species, stage)
	var L := maxf(8.0, float(m.get("length", m.get("frame_w", 46))))
	var H := maxf(6.0, float(m.get("height", m.get("frame_h", 32))) * 1.4)
	pixel_scale = clampf(floorf(minf(box.x * 0.82 / L, box.y * 0.8 / H) * 2.0) / 2.0, 0.5, max_scale)
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
	var swim := Art.player_anim(species, stage).x
	var frame := int(_t * 7.0 * swim / 4.0) % swim
	var bob := roundf(sin(_t * 2.2) * pixel_scale) if animate else 0.0
	var pos := (size - Vector2(fw, fh)) * 0.5 + Vector2(0, bob)
	if box != Vector2.ZERO:
		var c := Vector2(m.center[0], m.center[1]) * pixel_scale
		pos = (size * 0.5 - c + Vector2(0, bob)).round()
	if flip:
		draw_set_transform(Vector2(size.x, 0), 0.0, Vector2(-1, 1))
	for layer in Art.player_layers(mutations):
		var region := Art.player_region(species, stage, layer, frame)
		draw_texture_rect_region(tex, Rect2(pos, Vector2(fw, fh)), region)
