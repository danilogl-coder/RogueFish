class_name Hud
extends CanvasLayer
## In-game HUD: XP/HP bars, phase timer, counters, inventory, synergies,
## boss bar, banners, toasts, off-screen indicators and touch controls.

var game
var root: Control
var controls: TouchControls
var xp_bar: TextureProgressBar
var hp_bar: TextureProgressBar
var hp_label: Label
var level_label: Label
var phase_label: Label
var phase_bar: TextureProgressBar
var kills_label: Label
var pearls_label: Label
var stage_label: Label
var points_btn: Button
var inv_box: HBoxContainer
var syn_box: HBoxContainer
var stealth_bar: TextureProgressBar
var stealth_icon: TextureRect
var boss_box: VBoxContainer
var boss_bar: TextureProgressBar
var boss_label: Label
var banner_box: VBoxContainer
var banner_title: Label
var banner_sub: Label
var toast_label: Label
var indicators: Control
var debug_dir := Vector2.ZERO
var combo_box: VBoxContainer
var combo_label: Label
var combo_sub: Label
var combo_bar: TextureProgressBar
var diet_icon: TextureRect
var biome_lbl: Label
var evade_bar: TextureProgressBar
var stomach_bar: TextureProgressBar
var _combo_seen := 0
var _biome_tween: Tween
var _banner_tween: Tween
var _toast_tween: Tween


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIKit.theme()
	add_child(root)

	indicators = Control.new()
	indicators.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	indicators.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicators.draw.connect(_draw_indicators)
	root.add_child(indicators)

	controls = TouchControls.new()
	root.add_child(controls)
	controls.bite_pressed.connect(func(): game.player.try_bite())
	controls.dash_pressed.connect(func(): game.player.try_dash())

	# XP bar across the top
	xp_bar = UIKit.bar("bar_xp", Vector2(100, 8))
	root.add_child(xp_bar)
	xp_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	xp_bar.offset_left = 44
	xp_bar.offset_right = -6
	xp_bar.offset_top = 4
	xp_bar.offset_bottom = 12
	level_label = UIKit.label("NV 1", 8, UIKit.CYAN)
	level_label.position = Vector2(6, 4)
	root.add_child(level_label)

	# HP / stage / inventory block (top-left)
	var tl := UIKit.vbox(3)
	tl.position = Vector2(6, 16)
	root.add_child(tl)
	var hp_row := UIKit.hbox(3)
	tl.add_child(hp_row)
	hp_row.add_child(UIKit.icon_rect("heart", 12))
	hp_bar = UIKit.bar("bar_hp", Vector2(96, 10))
	hp_row.add_child(hp_bar)
	hp_label = UIKit.label("100", 8)
	hp_row.add_child(hp_label)
	var stage_row := UIKit.hbox(4)
	tl.add_child(stage_row)
	stage_label = UIKit.label("ALEVINO", 8, UIKit.GOLD)
	stage_row.add_child(stage_label)
	diet_icon = UIKit.icon_rect("leaf", 12)
	diet_icon.visible = false
	stage_row.add_child(diet_icon)
	stealth_icon = UIKit.icon_rect("hidden", 12)
	stage_row.add_child(stealth_icon)
	stealth_bar = UIKit.bar("bar_stealth", Vector2(40, 7))
	stage_row.add_child(stealth_bar)
	inv_box = UIKit.hbox(2)
	tl.add_child(inv_box)
	points_btn = UIKit.button("+0", "GoldButton")
	points_btn.custom_minimum_size = Vector2(0, 18)
	points_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	points_btn.pressed.connect(func(): game.open_pause())
	tl.add_child(points_btn)

	# phase (center)
	var center := UIKit.vbox(2)
	center.set_anchors_preset(Control.PRESET_CENTER_TOP)
	center.offset_top = 15
	center.offset_left = -70
	center.offset_right = 70
	center.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(center)
	phase_label = UIKit.label("EXPLORAR 1:00", 8, UIKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	center.add_child(phase_label)
	phase_bar = UIKit.bar("bar_wave", Vector2(120, 6))
	phase_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(phase_bar)
	toast_label = UIKit.label("", 8, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	toast_label.modulate.a = 0.0
	center.add_child(toast_label)

	# right counters
	var right := UIKit.hbox(4)
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.offset_left = -170
	right.offset_right = -6
	right.offset_top = 15
	right.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(right)
	right.add_child(UIKit.icon_rect("skull", 12))
	kills_label = UIKit.label("0", 8)
	right.add_child(kills_label)
	right.add_child(UIKit.icon_rect("pearl", 12))
	pearls_label = UIKit.label("0", 8, UIKit.WHITE)
	right.add_child(pearls_label)
	var pause := UIKit.button("", "", 0, "pause")
	pause.custom_minimum_size = Vector2(22, 20)
	pause.pressed.connect(func(): game.open_pause())
	right.add_child(pause)

	syn_box = UIKit.hbox(3)
	syn_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	syn_box.offset_left = -200
	syn_box.offset_right = -6
	syn_box.offset_top = 40
	syn_box.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(syn_box)

	# boss bar
	boss_box = UIKit.vbox(1)
	boss_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	boss_box.offset_left = -130
	boss_box.offset_right = 130
	boss_box.offset_top = -30
	boss_box.offset_bottom = -6
	boss_box.visible = false
	root.add_child(boss_box)
	boss_label = UIKit.label("", 8, UIKit.PURPLE, HORIZONTAL_ALIGNMENT_CENTER)
	boss_box.add_child(boss_label)
	boss_bar = UIKit.bar("bar_boss", Vector2(260, 10))
	boss_box.add_child(boss_bar)

	# boss evasion meter (hide to make the boss give up)
	evade_bar = UIKit.bar("bar_stealth", Vector2(120, 6))
	evade_bar.visible = false
	boss_box.add_child(evade_bar)
	# inside the Titanacon: how close you are to being spat out
	stomach_bar = UIKit.bar("bar_hp", Vector2(160, 6))
	stomach_bar.visible = false
	boss_box.add_child(stomach_bar)

	# combo meter (right side)
	combo_box = UIKit.vbox(0)
	combo_box.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	combo_box.offset_left = -110
	combo_box.offset_right = -8
	combo_box.offset_top = -60
	combo_box.alignment = BoxContainer.ALIGNMENT_END
	combo_box.modulate.a = 0.0
	root.add_child(combo_box)
	combo_label = UIKit.label("x0", 24, UIKit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	combo_box.add_child(combo_label)
	combo_sub = UIKit.label("COMBO", 8, UIKit.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	combo_box.add_child(combo_sub)
	combo_bar = UIKit.bar("bar_wave", Vector2(90, 5))
	combo_bar.size_flags_horizontal = Control.SIZE_SHRINK_END
	combo_box.add_child(combo_bar)

	# biome name
	biome_lbl = UIKit.label("", 16, Color("c8fbff"), HORIZONTAL_ALIGNMENT_CENTER)
	biome_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	biome_lbl.offset_left = -200
	biome_lbl.offset_right = 200
	biome_lbl.offset_top = -86
	biome_lbl.modulate.a = 0.0
	root.add_child(biome_lbl)

	# banner
	banner_box = UIKit.vbox(6)
	banner_box.set_anchors_preset(Control.PRESET_CENTER)
	banner_box.offset_left = -200
	banner_box.offset_right = 200
	banner_box.offset_top = -60
	banner_box.offset_bottom = -10
	banner_box.modulate.a = 0.0
	root.add_child(banner_box)
	banner_title = UIKit.label("", 24, UIKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	banner_box.add_child(banner_title)
	banner_sub = UIKit.label("", 8, UIKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	banner_box.add_child(banner_sub)

	game.player.inventory_changed.connect(_refresh_inventory)
	game.player.stage_changed.connect(_refresh_inventory)
	game.boss_changed.connect(_on_boss_changed)
	Profile.mission_completed.connect(_on_mission)
	_refresh_inventory()


func move_vector() -> Vector2:
	var k := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
	if k != Vector2.ZERO:
		return k.normalized()
	var pad := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if pad.length() > 0.2:
		return pad
	if debug_dir != Vector2.ZERO:
		return debug_dir
	return controls.direction


func _process(_delta: float) -> void:
	var p: Player = game.player
	xp_bar.value = float(game.xp) / float(maxi(1, game.xp_next))
	level_label.text = "NV %d" % game.level
	hp_bar.value = p.hp / p.st.max_hp
	hp_label.text = "%d/%d" % [int(ceil(p.hp)), int(p.st.max_hp)]
	kills_label.text = str(game.kills)
	pearls_label.text = str(game.pearls_run)
	var d: Director = game.director
	match d.phase:
		"explore":
			phase_label.text = "EXPLORAR %s" % DB.format_time(d.time_left())
			phase_bar.value = d.phase_t / d.phase_len
			phase_label.add_theme_color_override("font_color", UIKit.CYAN)
		"wave":
			phase_label.text = "ONDA %d  %s" % [d.cycle, DB.format_time(d.time_left())]
			phase_bar.value = 1.0 - d.phase_t / d.phase_len
			phase_label.add_theme_color_override("font_color", UIKit.RED)
		"rest":
			phase_label.text = "VITÓRIA!"
			phase_bar.value = 1.0
			phase_label.add_theme_color_override("font_color", UIKit.GOLD)
		"boss":
			phase_label.text = "CHEFE!"
			phase_bar.value = 1.0
			phase_label.add_theme_color_override("font_color", UIKit.PURPLE)
	stealth_icon.visible = p.is_hidden or p.stealth < 0.98
	stealth_bar.visible = stealth_icon.visible
	stealth_bar.value = p.stealth
	stealth_icon.modulate = Color.WHITE if p.is_hidden else Color(1, 1, 1, 0.4)
	points_btn.visible = game.status_points > 0
	points_btn.text = "+%d PONTOS" % game.status_points
	controls.cooldown = p.bite_cooldown_ratio()
	controls.dash_charges = p.dash_charges
	controls.dash_max = p.dash_max
	# combo
	if game.combo >= 3:
		combo_box.modulate.a = minf(1.0, combo_box.modulate.a + _delta * 6.0)
		if game.combo != _combo_seen:
			_combo_seen = game.combo
			combo_label.text = "x%d" % game.combo
			combo_label.pivot_offset = combo_label.size * Vector2(1.0, 0.5)
			combo_label.scale = Vector2(1.35, 1.35)
			var hue := clampf(game.combo / 150.0, 0.0, 1.0)
			combo_label.add_theme_color_override("font_color", UIKit.GOLD.lerp(UIKit.RED, hue))
		combo_label.scale = combo_label.scale.lerp(Vector2.ONE, 1.0 - pow(0.001, _delta))
		combo_bar.value = clampf(game._combo_t / 2.6, 0.0, 1.0)
		combo_sub.text = "COMBO  XP x%.2f" % game.combo_mult()
	else:
		combo_box.modulate.a = maxf(0.0, combo_box.modulate.a - _delta * 3.0)
		_combo_seen = 0
	# diet
	var dt: String = p.diet_type()
	diet_icon.visible = dt != ""
	if dt != "":
		diet_icon.texture = Art.icon(DB.DIETS[dt].icon)
	# boss evasion
	evade_bar.visible = game.boss != null and game.boss_evade_ratio() > 0.0
	evade_bar.value = game.boss_evade_ratio()
	stomach_bar.visible = game.stomach != null
	if stomach_bar.visible:
		stomach_bar.value = game.stomach_ratio()
	if game.boss and is_instance_valid(game.boss):
		boss_bar.value = game.boss.hp / game.boss.max_hp
		boss_label.text = ("DENTRO DO TITÃ: ÓRGÃOS %d%%" % int(game.stomach_ratio() * 100.0)) if game.stomach != null else game.boss.boss_name()
	indicators.queue_redraw()


func _refresh_inventory() -> void:
	var p: Player = game.player
	stage_label.text = DB.STAGE_NAMES[p.stage].to_upper()
	for c in inv_box.get_children():
		c.queue_free()
	for id in p.weapons:
		var w: Weapon = p.weapons[id]
		inv_box.add_child(_inv_icon(w.icon_name(), w.level, w.evo != ""))
	for id in p.passives:
		inv_box.add_child(_inv_icon(DB.PASSIVES[id].icon, p.passives[id], false, true))
	for c in syn_box.get_children():
		c.queue_free()
	for tag in DB.TAGS:
		var n: int = p.tag_counts.get(tag, 0)
		if n <= 0:
			continue
		var chip := UIKit.hbox(1)
		var ic := UIKit.icon_rect(DB.TAGS[tag].icon, 12)
		chip.add_child(ic)
		var l := UIKit.label(str(n), 8, DB.TAGS[tag].color if n >= 2 else UIKit.DIM)
		chip.add_child(l)
		if n < 2:
			ic.modulate = Color(1, 1, 1, 0.45)
		syn_box.add_child(chip)


func _inv_icon(icon: String, level: int, evolved: bool, small := false) -> Control:
	var box := Control.new()
	var s := 12.0 if small else 14.0
	box.custom_minimum_size = Vector2(s, s + 3)
	var r := UIKit.icon_rect(icon, s)
	box.add_child(r)
	if evolved:
		r.modulate = Color(1.2, 1.1, 0.7)
	var pips := Control.new()
	pips.position = Vector2(0, s)
	pips.custom_minimum_size = Vector2(s, 2)
	pips.draw.connect(func():
		for i in DB.MAX_LEVEL:
			pips.draw_rect(Rect2(i * (s / DB.MAX_LEVEL), 0, maxf(1.0, s / DB.MAX_LEVEL - 1.0), 2), UIKit.GOLD if (evolved or i < level) else Color(1, 1, 1, 0.18)))
	box.add_child(pips)
	return box


func _on_boss_changed(b) -> void:
	boss_box.visible = b != null
	if b:
		boss_label.text = b.boss_name()


func banner(title: String, sub: String, color: Color) -> void:
	banner_title.text = title
	banner_title.add_theme_color_override("font_color", color)
	banner_sub.text = sub
	if _banner_tween:
		_banner_tween.kill()
	banner_box.pivot_offset = banner_box.size * 0.5
	banner_box.scale = Vector2(1.6, 1.6)
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner_box, "modulate:a", 1.0, 0.2)
	_banner_tween.parallel().tween_property(banner_box, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(1.8)
	_banner_tween.tween_property(banner_box, "modulate:a", 0.0, 0.5)


func toast(text: String, color := Color.WHITE) -> void:
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", color)
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(2.6)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.6)


func _draw_indicators() -> void:
	var xf := root.get_viewport().get_canvas_transform()
	var rect := Rect2(Vector2.ZERO, indicators.size).grow(-18)
	var targets := []
	for p in game.world.pois:
		if is_instance_valid(p) and p.is_active():
			targets.append([p.global_position, Color("ffbf45")])
	if game.boss and is_instance_valid(game.boss):
		targets.append([game.boss.global_position, Color("cc7ee0")])
	for c in game.creatures:
		if is_instance_valid(c) and c.id == "orca" and c.position.distance_to(game.player.position) < 700.0:
			targets.append([c.global_position, Color("ff5c4c")])
	var arrow := Art.icon("arrow")
	for t in targets:
		var sp: Vector2 = xf * t[0]
		if Rect2(Vector2.ZERO, indicators.size).has_point(sp):
			continue
		var c := rect.get_center()
		var dir := (sp - c).normalized()
		var edge := c
		var tx := (rect.size.x * 0.5) / maxf(absf(dir.x), 0.001)
		var ty := (rect.size.y * 0.5) / maxf(absf(dir.y), 0.001)
		edge = c + dir * minf(tx, ty)
		var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() / 150.0)
		indicators.draw_set_transform(edge, dir.angle(), Vector2.ONE)
		indicators.draw_texture(arrow, Vector2(-8, -8), Color(t[1], pulse))
		indicators.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func combo_milestone(n: int, label: String) -> void:
	banner("%s" % label, "COMBO x%d" % n, UIKit.GOLD.lerp(UIKit.RED, clampf(n / 150.0, 0.0, 1.0)))


func biome_label(text: String) -> void:
	biome_lbl.text = "~ %s ~" % text
	if _biome_tween:
		_biome_tween.kill()
	_biome_tween = create_tween()
	_biome_tween.tween_property(biome_lbl, "modulate:a", 1.0, 0.5)
	_biome_tween.tween_interval(2.2)
	_biome_tween.tween_property(biome_lbl, "modulate:a", 0.0, 0.8)


func _on_mission(m: Dictionary) -> void:
	var extra := ""
	if m.has("unlock"):
		extra = "  |  Desbloqueado: %s" % DB.WEAPONS[m.unlock].name
	toast("MISSÃO: %s  +%d pérolas%s" % [m.name, m.pearls, extra], UIKit.GREEN)
	Sfx.play("level_up", -2.0)
