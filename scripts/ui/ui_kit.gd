class_name UIKit
extends RefCounted
## Builds the pixel-art Theme and small widget helpers used by every menu.

const WHITE := Color("f0f4f8")
const DIM := Color("8a9ab0")
const GOLD := Color("ffbf45")
const CYAN := Color("5ee0ff")
const GREEN := Color("a4dc4c")
const RED := Color("ff5c4c")
const PURPLE := Color("cc7ee0")
const DARK := Color("07101e")
const RARITY_COLOR := {
	"common": Color("d4dae6"), "rare": Color("5ee0ff"), "epic": Color("e39be6"),
	"legend": Color("ffbf45"), "mutation": Color("a4dc4c"),
}

static var _theme: Theme


## Layout sizes are written in "design units" (8 = body, 16 = heading,
## 24 = banner) and mapped to the UI font's pixel sizes here.
static func px(size: int) -> int:
	match size:
		8:
			return 12
		16:
			return 20
		24:
			return 30
	return size


static func sb(path: String, margin := 6, content := Vector4(6, 4, 6, 4)) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = Art.tex(path)
	s.texture_margin_left = margin
	s.texture_margin_right = margin
	s.texture_margin_top = margin
	s.texture_margin_bottom = margin
	s.content_margin_left = content.x
	s.content_margin_top = content.y
	s.content_margin_right = content.z
	s.content_margin_bottom = content.w
	return s


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = Art.font
	t.default_font_size = 12
	# Buttons
	t.set_stylebox("normal", "Button", sb("ui/btn_normal", 5, Vector4(8, 5, 8, 7)))
	t.set_stylebox("hover", "Button", sb("ui/btn_hover", 5, Vector4(8, 5, 8, 7)))
	t.set_stylebox("pressed", "Button", sb("ui/btn_pressed", 5, Vector4(8, 6, 8, 6)))
	t.set_stylebox("disabled", "Button", sb("ui/btn_disabled", 5, Vector4(8, 5, 8, 7)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color("c8fbff"))
	t.set_color("font_disabled_color", "Button", DIM)
	t.set_color("font_outline_color", "Button", DARK)
	t.set_constant("outline_size", "Button", 3)
	t.set_constant("h_separation", "Button", 4)
	# Gold variation
	t.set_type_variation("GoldButton", "Button")
	t.set_stylebox("normal", "GoldButton", sb("ui/btn_gold", 5, Vector4(8, 5, 8, 7)))
	t.set_stylebox("hover", "GoldButton", sb("ui/btn_gold", 5, Vector4(8, 5, 8, 7)))
	t.set_stylebox("pressed", "GoldButton", sb("ui/btn_gold_pressed", 5, Vector4(8, 6, 8, 6)))
	t.set_type_variation("RedButton", "Button")
	t.set_stylebox("normal", "RedButton", sb("ui/btn_red", 5, Vector4(8, 5, 8, 7)))
	t.set_stylebox("hover", "RedButton", sb("ui/btn_red", 5, Vector4(8, 5, 8, 7)))
	t.set_stylebox("pressed", "RedButton", sb("ui/btn_red", 5, Vector4(8, 6, 8, 6)))
	# Panels
	t.set_stylebox("panel", "PanelContainer", sb("ui/panel", 7, Vector4(8, 8, 8, 8)))
	t.set_stylebox("panel", "Panel", sb("ui/panel", 7, Vector4(8, 8, 8, 8)))
	t.set_type_variation("LightPanel", "PanelContainer")
	t.set_stylebox("panel", "LightPanel", sb("ui/panel_light", 7, Vector4(6, 6, 6, 6)))
	for r in RARITY_COLOR:
		var v: String = "Card_" + r
		t.set_type_variation(v, "PanelContainer")
		t.set_stylebox("panel", v, sb("ui/" + DB.RARITY_FRAME[r], 9, Vector4(7, 9, 7, 7)))
	# Labels
	t.set_color("font_color", "Label", WHITE)
	t.set_color("font_outline_color", "Label", DARK)
	t.set_constant("outline_size", "Label", 3)
	t.set_constant("line_spacing", "Label", 0)
	# Slider
	var slider := StyleBoxFlat.new()
	slider.bg_color = Color("0a1628")
	slider.border_color = Color("3a6a94")
	slider.set_border_width_all(1)
	slider.content_margin_top = 3
	slider.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", slider)
	var area := StyleBoxFlat.new()
	area.bg_color = Color("1ca8b0")
	area.content_margin_top = 3
	area.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", area)
	t.set_stylebox("grabber_area_highlight", "HSlider", area)
	t.set_icon("grabber", "HSlider", Art.icon("star"))
	t.set_icon("grabber_highlight", "HSlider", Art.icon("star"))
	# Scroll
	var sc := StyleBoxFlat.new()
	sc.bg_color = Color("0a1628")
	t.set_stylebox("scroll", "VScrollBar", sc)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color("3a6a94")
	grab.content_margin_left = 3
	grab.content_margin_right = 3
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	# Tooltip-free, no focus rings anywhere
	_theme = t
	return t


static func label(text: String, size := 8, color := WHITE, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px(size))
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if size >= 16:
		l.add_theme_constant_override("outline_size", 5)
	return l


static func wrap_label(text: String, size := 8, color := WHITE, width := 100.0) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


static func button(text: String, variation := "", min_w := 0.0, icon_name := "") -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(min_w, 22)
	b.focus_mode = Control.FOCUS_NONE
	if icon_name != "":
		b.icon = Art.icon(icon_name)
	b.pressed.connect(func(): Sfx.play("click", -4.0, 0.05))
	return b


static func icon_rect(name: String, px := 16.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = Art.icon(name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func tex_rect(tex: Texture2D, size: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func bar(fill: String, min_size := Vector2(80, 8)) -> TextureProgressBar:
	var b := TextureProgressBar.new()
	b.nine_patch_stretch = true
	b.texture_under = Art.tex("ui/bar_frame")
	b.stretch_margin_left = 2
	b.stretch_margin_right = 2
	b.stretch_margin_top = 2
	b.stretch_margin_bottom = 2
	b.texture_progress = Art.tex("ui/" + fill)
	b.texture_progress_offset = Vector2(2, 2)
	b.custom_minimum_size = min_size
	b.max_value = 1.0
	b.step = 0.0
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


static func hbox(sep := 4) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep := 4) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func center_panel(parent: Control, min_size: Vector2, variation := "") -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variation
	p.custom_minimum_size = min_size
	parent.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	return p


static func dim_background(parent: Control, alpha := 0.6) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0.01, 0.03, 0.07, alpha)
	parent.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	return c


static func pop_in(node: Control, delay := 0.0) -> void:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(0.6, 0.6)
	node.modulate.a = 0.0
	var t := node.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector2.ONE, 0.28).set_delay(delay)
	t.tween_property(node, "modulate:a", 1.0, 0.18).set_delay(delay)
