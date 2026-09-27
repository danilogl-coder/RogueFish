extends Control
## Title screen: animated ocean, logo, play / species / meta-upgrade shop /
## how to play / options / credits.

const VERSION := "v1.0.0"

var _bg_t := 0.0
var _fish: Array = []
var _layers: Array = []
var _screen: Control
var _main: Control
var _pearls_label: Label
var _video_btn: Button
var _video_hint: Label
var _video_t := 0.0


func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	Engine.time_scale = 1.0
	_build_background()
	_build_main()
	Sfx.play_music("menu")
	Billing.purchased.connect(func(_id: String):
		Sfx.play_stinger("fusion")
		if _screen != null and _store_cat == "iap":
			_show_store())
	if Profile.daily_available() > 0 and not Array(OS.get_cmdline_user_args()).any(func(a): return a.begins_with("--menu") or a.begins_with("--sp-") or a.begins_with("--store")):
		_show_daily.call_deferred()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--menu="):
			match a.substr(7):
				"species": _show_species()
				"shop": _show_shop()
				"guide": _show_guide()
				"options": _show_options()
				"credits": _show_credits()
				"missions": _show_missions()
				"bestiary": _show_bestiary()
				"store": _show_store()
				"collection": _show_collection()
		if a.begins_with("--sp-view="):
			_sp_view = a.substr(10)
			_sp_group = DB.SPECIES[_sp_view].group
			_show_species()
		if a.begins_with("--store-cat="):
			_store_cat = a.substr(12)
			_show_store()
		if a.begins_with("--menu-shot="):
			# debug: save a screenshot of the menu and quit
			var path := a.substr(12)
			await get_tree().create_timer(1.2).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path)
			get_tree().quit()


# ------------------------------------------------------------- background
func _refresh_video_btn() -> void:
	if _video_btn == null:
		return
	_video_btn.disabled = not Ads.can_show("pearls")
	_video_btn.text = ("VÍDEO +%d" if not Profile.vip else "VIP +%d") % int(Offers.VIDEOS.pearls.reward)
	_video_hint.text = Ads.status_text("pearls")


func _build_background() -> void:
	var bg := TextureRect.new()
	bg.texture = Art.tex("env/bg_backdrop")
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	for d in [["env/bg_far", 6.0, 40.0], ["env/bg_mid", 12.0, 20.0], ["env/bg_near", 22.0, -10.0]]:
		var layer := Control.new()
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(layer)
		for i in 3:
			var t := TextureRect.new()
			t.texture = Art.tex(d[0])
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.add_child(t)
		_layers.append({"node": layer, "speed": d[1], "y": d[2], "tex": Art.tex(d[0])})
	var seabed := TextureRect.new()
	seabed.texture = Art.tex("terrain/menu_strip")
	seabed.stretch_mode = TextureRect.STRETCH_TILE
	seabed.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	seabed.offset_top = -52
	seabed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(seabed)
	var fish_holder := Control.new()
	fish_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fish_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fish_holder)
	var kinds := ["sardine", "sardine", "sardine", "shrimp", "piranha", "jellyfish", "turtle", "golden", "shark"]
	for i in 14:
		var k: String = kinds[randi() % kinds.size()]
		var s := Sprite2D.new()
		s.texture = Art.tex("creatures/" + k)
		s.hframes = Art.frames("creatures/" + k)
		s.set_meta("swim", Art.anim("creatures/" + k).x)
		var dir := 1.0 if randf() < 0.5 else -1.0
		s.flip_h = dir < 0
		s.modulate = Color(0.55, 0.7, 0.85, 0.8) if k != "golden" else Color.WHITE
		fish_holder.add_child(s)
		_fish.append({"s": s, "dir": dir, "speed": randf_range(14, 40), "y": randf_range(150, 320), "x": randf_range(0, 700), "k": k})


func _process(delta: float) -> void:
	_bg_t += delta
	var w := size.x
	for l in _layers:
		var tw: float = l.tex.get_width()
		var off: float = fmod(_bg_t * l.speed, tw)
		var i := 0
		for t in l.node.get_children():
			t.position = Vector2(roundf(-off + i * tw), size.y - t.texture.get_height() + l.y)
			i += 1
	for f in _fish:
		f.x += f.dir * f.speed * delta
		if f.x > w + 60:
			f.x = -60
		elif f.x < -60:
			f.x = w + 60
		var s: Sprite2D = f.s
		s.position = Vector2(roundf(f.x), roundf(f.y + sin(_bg_t + f.x * 0.02) * 3.0))
		var swim: int = s.get_meta("swim", 4)
		s.frame = int(_bg_t * 8.0 * swim / 4.0 + f.y) % swim
	if _pearls_label:
		_pearls_label.text = str(Profile.pearls)
	_video_t -= delta
	if _video_t <= 0.0:
		_video_t = 1.0
		_refresh_video_btn()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()


func _back() -> void:
	if _screen:
		_close_screen()
		_main.visible = true
	else:
		get_tree().quit()


# -------------------------------------------------------------------- main
func _build_main() -> void:
	_main = Control.new()
	_main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_main)
	var v := UIKit.vbox(6)
	v.set_anchors_preset(Control.PRESET_CENTER_TOP)
	v.offset_left = -190
	v.offset_right = 190
	v.offset_top = 14
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	_main.add_child(v)
	var logo := UIKit.tex_rect(Art.tex("ui/logo"), Vector2(358, 134))
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo.stretch_mode = TextureRect.STRETCH_SCALE
	v.add_child(logo)
	var tw := logo.create_tween().set_loops()
	tw.tween_property(logo, "position:y", 3.0, 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(logo, "position:y", 0.0, 1.4).set_trans(Tween.TRANS_SINE)
	v.add_child(UIKit.label("um roguelike de sobrevivência nas profundezas", 8, Color("c8fbff"), HORIZONTAL_ALIGNMENT_CENTER))
	var buttons := UIKit.vbox(5)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(buttons)
	var play := UIKit.button("JOGAR", "GoldButton", 170, "play")
	play.custom_minimum_size.y = 28
	play.add_theme_font_size_override("font_size", UIKit.px(16))
	play.pressed.connect(_show_species)
	buttons.add_child(play)
	var row0 := UIKit.hbox(5)
	buttons.add_child(row0)
	var shop := UIKit.button("EVOLUÇÃO", "", 0, "dna")
	shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop.pressed.connect(_show_shop)
	row0.add_child(shop)
	var store := UIKit.button("LOJA", "GoldButton", 0, "chest")
	store.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	store.pressed.connect(_show_store)
	row0.add_child(store)
	var row2 := UIKit.hbox(5)
	buttons.add_child(row2)
	var mis := UIKit.button("MISSÕES", "", 0, "target")
	mis.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mis.pressed.connect(_show_missions)
	row2.add_child(mis)
	var bes := UIKit.button("BESTIÁRIO", "", 0, "book")
	bes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bes.pressed.connect(_show_bestiary)
	row2.add_child(bes)
	var row := UIKit.hbox(5)
	buttons.add_child(row)
	var col := UIKit.button("COLEÇÃO", "", 0, "trophy")
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.pressed.connect(_show_collection)
	row.add_child(col)
	var how := UIKit.button("GUIA", "", 0, "eye")
	how.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	how.pressed.connect(_show_guide)
	row.add_child(how)
	var opt := UIKit.button("", "", 26, "gear")
	opt.pressed.connect(_show_options)
	row.add_child(opt)
	var cred := UIKit.button("", "", 26, "star")
	cred.pressed.connect(_show_credits)
	row.add_child(cred)
	UIKit.pop_in(buttons, 0.1)
	# pearls
	var pr := UIKit.hbox(4)
	pr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pr.offset_left = -120
	pr.offset_right = -8
	pr.offset_top = 8
	pr.alignment = BoxContainer.ALIGNMENT_END
	add_child(pr)
	pr.add_child(UIKit.icon_rect("pearl", 16))
	_pearls_label = UIKit.label(str(Profile.pearls), 16, UIKit.WHITE)
	pr.add_child(_pearls_label)
	# rewarded video: free pearls
	var reward := int(Offers.VIDEOS.pearls.reward)
	_video_btn = UIKit.button("+%d" % reward, "GoldButton", 0, "play")
	_video_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_video_btn.offset_left = -120
	_video_btn.offset_right = -8
	_video_btn.offset_top = 30
	_video_btn.tooltip_text = "Veja um vídeo e ganhe %d pérolas" % reward
	_video_btn.pressed.connect(func():
		Ads.show_rewarded("pearls", func():
			Profile.add_pearls(reward)
			Profile.save_game()
			Sfx.play("level_up")
			_refresh_video_btn()))
	_main.add_child(_video_btn)
	_video_hint = UIKit.label("", 8, Color("c8fbff"), HORIZONTAL_ALIGNMENT_RIGHT)
	_video_hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_video_hint.offset_left = -160
	_video_hint.offset_right = -8
	_video_hint.offset_top = 56
	_main.add_child(_video_hint)
	_refresh_video_btn()
	# records
	var rec := UIKit.label("RECORDE %s  |  VITÓRIAS %d  |  CHEFES %d" % [DB.format_time(float(Profile.records.best_time)), int(Profile.records.wins), int(Profile.records.bosses)], 8, Color("c8fbff"))
	rec.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	rec.offset_left = 8
	rec.offset_top = -16
	_main.add_child(rec)
	var ver := UIKit.label(VERSION, 8, Color(1, 1, 1, 0.5))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_left = -60
	ver.offset_top = -16
	_main.add_child(ver)


func _open_screen(title: String, min_size := Vector2(600, 320)) -> VBoxContainer:
	_close_screen()
	_main.visible = false
	_screen = Control.new()
	add_child(_screen)
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIKit.dim_background(_screen, 0.5)
	var panel := UIKit.center_panel(_screen, min_size)
	var v := UIKit.vbox(6)
	panel.add_child(v)
	var top := UIKit.hbox(6)
	v.add_child(top)
	var back := UIKit.button("", "", 26, "back")
	back.pressed.connect(func():
		_close_screen()
		_main.visible = true)
	top.add_child(back)
	top.add_child(UIKit.label(title, 16, UIKit.GOLD))
	UIKit.pop_in(panel)
	return v


func _close_screen() -> void:
	if _screen:
		_screen.queue_free()
		_screen = null


# ---------------------------------------------------------------- species
var _sp_group := ""
var _sp_view := ""
var _sp_stage_t := 0.0


## Character select: groups on top, a grid of characters, and a detail panel
## with the animated look (cycling through every growth stage), the trait,
## the unique item and how to unlock it.
func _show_species() -> void:
	if _sp_view == "" or not DB.SPECIES.has(_sp_view):
		_sp_view = Profile.selected_species
	if _sp_group == "":
		_sp_group = DB.SPECIES[_sp_view].group
	var v := _open_screen("PERSONAGENS  %d/%d" % [Profile.unlocked.filter(func(x): return DB.SPECIES.has(x)).size(), DB.SPECIES.size()], Vector2(612, 0))
	var body := UIKit.hbox(8)
	v.add_child(body)
	# ---- left: tabs + grid
	var left := UIKit.vbox(4)
	left.custom_minimum_size = Vector2(300, 0)
	body.add_child(left)
	var tabs := UIKit.hbox(3)
	left.add_child(tabs)
	for g in Roster.GROUPS:
		var gid: String = g[0]
		var tb := UIKit.button(g[1], "GoldButton" if gid == _sp_group else "", 0)
		tb.add_theme_font_size_override("font_size", 9)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.pressed.connect(func():
			_sp_group = gid
			_show_species())
		tabs.add_child(tb)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	left.add_child(grid)
	for sp in DB.SPECIES:
		if DB.SPECIES[sp].group != _sp_group:
			continue
		grid.add_child(_species_tile(sp))
	# ---- right: details
	body.add_child(_species_details(_sp_view))


func _species_tile(sp: String) -> Control:
	var unlocked := Profile.unlocked.has(sp)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(56, 52)
	b.theme_type_variation = "Card_legend" if sp == Profile.selected_species else ("Card_rare" if sp == _sp_view else "Card_common")
	var prev := FishPreview.new().setup(sp, 2, {}, 1.0).fit(Vector2(52, 38), 2.0)
	prev.animate = sp == _sp_view
	prev.position = Vector2(2, 2)
	if not unlocked:
		prev.modulate = Color(0.08, 0.1, 0.18)
	b.add_child(prev)
	if not unlocked:
		var lk := UIKit.icon_rect("lock", 12)
		lk.position = Vector2(40, 36)
		b.add_child(lk)
	elif sp == Profile.selected_species:
		var ck := UIKit.icon_rect("check", 12)
		ck.position = Vector2(40, 36)
		b.add_child(ck)
	b.pressed.connect(func():
		_sp_view = sp
		Sfx.play("click", -6.0)
		_show_species())
	return b


func _species_details(sp: String) -> Control:
	var d: Dictionary = DB.SPECIES[sp]
	var unlocked := Profile.unlocked.has(sp)
	var p := PanelContainer.new()
	p.theme_type_variation = "Card_legend" if unlocked else "Card_common"
	p.custom_minimum_size = Vector2(290, 0)
	var v := UIKit.vbox(3)
	p.add_child(v)
	var head := UIKit.hbox(6)
	v.add_child(head)
	head.add_child(UIKit.label(d.name.to_upper(), 8, UIKit.GOLD))
	var stage_lbl := UIKit.label("", 8, UIKit.DIM)
	stage_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(stage_lbl)
	# animated look, cycling through the five growth stages
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(270, 58)
	v.add_child(holder)
	var shown := [-1]
	var refresh := func():
		var st := int(Time.get_ticks_msec() / 1600) % DB.STAGE_NAMES.size()
		if st == shown[0]:
			return
		shown[0] = st
		for c in holder.get_children():
			c.queue_free()
		var pv := FishPreview.new().setup(sp, st, {}, 1.0).fit(Vector2(270, 58), 3.0)
		if not unlocked:
			pv.modulate = Color(0.1, 0.12, 0.22)
		holder.add_child(pv)
		stage_lbl.text = "%s · %s" % [Evolutions.stage_name(sp, st).to_upper(), String(Evolutions.move(sp, st).name).to_upper()]
		holder.tooltip_text = Evolutions.stage_desc(sp, st)
	refresh.call()
	var timer := Timer.new()
	timer.wait_time = 0.2
	timer.autostart = true
	timer.timeout.connect(refresh)
	holder.add_child.call_deferred(timer)
	# trait
	var tr := UIKit.hbox(4)
	tr.add_child(UIKit.icon_rect("dna", 12))
	tr.add_child(UIKit.label("TRAÇO: " + d.trait.name.to_upper(), 8, UIKit.GREEN))
	v.add_child(tr)
	v.add_child(UIKit.wrap_label(d.trait.desc, 8, Color("b8c6d8"), 280))
	# unique item
	var w: Dictionary = DB.WEAPONS[d.weapon]
	var ir := UIKit.hbox(4)
	ir.add_child(UIKit.icon_rect(w.icon, 16))
	ir.add_child(UIKit.label("ITEM ÚNICO: " + w.name.to_upper(), 8, UIKit.CYAN))
	v.add_child(ir)
	v.add_child(UIKit.wrap_label(DB.weapon_desc(d.weapon, 0), 8, Color("b8c6d8"), 280))
	# stats
	var s: Dictionary = d.stats
	var stats := UIKit.hbox(8)
	v.add_child(stats)
	for stat in [["VIDA", s.max_hp / 180.0, UIKit.RED], ["VELOC", s.speed / 140.0, UIKit.CYAN], ["MORD", s.bite_damage / 24.0, UIKit.GOLD], ["ARMAD", s.armor / 3.0, UIKit.PURPLE]]:
		var col := UIKit.vbox(1)
		col.add_child(UIKit.label(stat[0], 8, UIKit.DIM))
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(60, 5)
		var k: float = clampf(stat[1], 0.0, 1.0)
		var c: Color = stat[2]
		bar.draw.connect(func():
			bar.draw_rect(Rect2(0, 0, 60, 5), Color(0.02, 0.05, 0.1))
			bar.draw_rect(Rect2(1, 1, 58 * k, 3), c))
		col.add_child(bar)
		stats.add_child(col)
	# unlock / select
	var u: Dictionary = d.unlock
	var b: Button
	if unlocked:
		var sel := Profile.selected_species == sp
		b = UIKit.button("SELECIONADO" if sel else "ESCOLHER", "" , 0, "check" if sel else "")
		b.pressed.connect(func():
			Profile.selected_species = sp
			Profile.save_game()
			Sfx.play("card")
			_show_species())
	elif u.type == "boss":
		b = UIKit.button("DERROTE: " + DB.BOSSES[u.boss].name.to_upper(), "", 0, "lock")
		b.disabled = true
	elif u.type == "stat":
		var pr: Array = Profile.species_progress(sp)
		b = UIKit.button("%s  %d/%d" % [u.desc.to_upper(), pr[0], pr[1]], "", 0, "target")
		b.disabled = true
	elif u.type == "pack" and not Profile.owns(u.pack):
		b = UIKit.button("REQUER: " + Shop.ITEMS[u.pack].name.to_upper(), "", 0, "lock")
		b.disabled = true
	else:
		b = UIKit.button("%d PÉROLAS" % int(d.price), "GoldButton" if Profile.pearls >= int(d.price) else "", 0, "pearl")
		b.disabled = Profile.pearls < int(d.price)
		b.pressed.connect(func():
			if Profile.buy_species(sp):
				Sfx.play_stinger("fusion")
				_show_species())
	b.add_theme_font_size_override("font_size", 9)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UIKit.hbox(4)
	row.add_child(b)
	var go := UIKit.button("MERGULHAR!", "GoldButton", 0, "play")
	go.pressed.connect(_start_game)
	go.disabled = not Profile.unlocked.has(Profile.selected_species)
	row.add_child(go)
	v.add_child(row)
	return p


# ------------------------------------------------------------- collection
var _col_tab := "items"


## Every item (and who brings it into the game) and every fusion recipe.
func _show_collection() -> void:
	var have := 0
	for id in DB.WEAPONS:
		if not DB.WEAPONS[id].get("fusion", false) and DB.item_unlocked(id):
			have += 1
	var total := DB.WEAPONS.size() - DB.FUSIONS.size()
	var v := _open_screen("COLEÇÃO  %d/%d ITENS" % [have, total], Vector2(612, 0))
	var tabs := UIKit.hbox(4)
	v.add_child(tabs)
	for t in [["items", "ITENS"], ["fusions", "FUSÕES (%d)" % DB.FUSIONS.size()]]:
		var tid: String = t[0]
		var b := UIKit.button(t[1], "GoldButton" if tid == _col_tab else "", 0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			_col_tab = tid
			_show_collection())
		tabs.add_child(b)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 250)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)
	if _col_tab == "items":
		for id in DB.WEAPONS:
			var w: Dictionary = DB.WEAPONS[id]
			if w.get("fusion", false):
				continue
			var ok := DB.item_unlocked(id)
			var owner: String = DB.ITEM_OWNER.get(id, "")
			var p := PanelContainer.new()
			p.theme_type_variation = "Card_rare" if ok else "Card_common"
			p.custom_minimum_size = Vector2(194, 44)
			var h := UIKit.hbox(4)
			p.add_child(h)
			var ic := UIKit.icon_rect(w.icon, 16)
			if not ok:
				ic.modulate = Color(0.15, 0.18, 0.25)
			h.add_child(ic)
			var col := UIKit.vbox(0)
			h.add_child(col)
			col.add_child(UIKit.label(w.name.to_upper() if ok else "???", 8, UIKit.WHITE if ok else UIKit.DIM))
			var src: String = "Item básico" if owner == "" else ("Item de " + DB.SPECIES[owner].name if ok else "Libere: " + DB.SPECIES[owner].name)
			col.add_child(UIKit.label(src, 8, UIKit.CYAN if ok else UIKit.DIM))
			grid.add_child(p)
	else:
		for fid in DB.FUSIONS:
			var f: Dictionary = DB.FUSIONS[fid]
			var known: bool = DB.item_unlocked(f.from[0]) and DB.item_unlocked(f.from[1])
			var p2 := PanelContainer.new()
			p2.theme_type_variation = "Card_legend" if Profile.stat("fused_" + fid) > 0 else ("Card_rare" if known else "Card_common")
			p2.custom_minimum_size = Vector2(194, 54)
			var v2 := UIKit.vbox(1)
			p2.add_child(v2)
			var h2 := UIKit.hbox(4)
			v2.add_child(h2)
			h2.add_child(UIKit.icon_rect(f.icon, 16))
			h2.add_child(UIKit.label(f.name.to_upper() if known else "FUSÃO ???", 8, Color("ff8ae0") if known else UIKit.DIM))
			var r := UIKit.hbox(2)
			v2.add_child(r)
			for wid in f.from:
				r.add_child(UIKit.icon_rect(DB.WEAPONS[wid].icon, 12))
			r.add_child(UIKit.label("%s + %s" % [DB.WEAPONS[f.from[0]].name, DB.WEAPONS[f.from[1]].name] if known else "itens ainda bloqueados", 8, Color("b8c6d8")))
			grid.add_child(p2)


# ------------------------------------------------------------------ store
var _store_cat := "pack"


## Pearl store: expansions, relics, tides and modes.
func _show_store() -> void:
	var v := _open_screen("LOJA DO RECIFE", Vector2(612, 0))
	var tabs := UIKit.hbox(4)
	v.add_child(tabs)
	for c in Shop.CATEGORIES:
		var cid: String = c[0]
		var tb := UIKit.button(c[1], "GoldButton" if cid == _store_cat else "", 0)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.pressed.connect(func():
			_store_cat = cid
			_show_store())
		tabs.add_child(tb)
	var hint := {"iap": "Pérolas, o Pacote Inicial e o Passe VIP. Tudo também pode ser ganho jogando.", "pack": "Novos conteúdos para o oceano. Bichos de expansão entram na lista de personagens.",
		"relic": "Relíquias mudam para sempre como as partidas funcionam.",
		"tide": "Equipe UMA maré: ela vale para todas as partidas (requer Rosa-dos-Ventos).",
		"mode": "Ligue quantos modos quiser: mais difícil, mais pérolas."}
	v.add_child(UIKit.wrap_label(hint[_store_cat], 8, Color("c8d4e4"), 590))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 214)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	if _store_cat == "iap":
		for id in Offers.PRODUCTS:
			if id == "starter" and Billing.owned(id):
				continue
			grid.add_child(_offer_card(id))
		return
	for id in Shop.ITEMS:
		if Shop.ITEMS[id].cat == _store_cat:
			grid.add_child(_store_card(id))


## Real-money product card.
func _offer_card(id: String) -> Control:
	var d: Dictionary = Offers.PRODUCTS[id]
	var owned := Billing.owned(id)
	var p := PanelContainer.new()
	p.theme_type_variation = "Card_legend" if id in ["vip", "starter"] else "Card_rare"
	p.custom_minimum_size = Vector2(192, 102)
	var v := UIKit.vbox(2)
	p.add_child(v)
	var h := UIKit.hbox(4)
	v.add_child(h)
	h.add_child(UIKit.icon_rect(d.icon, 16))
	h.add_child(UIKit.label(String(d.name).to_upper(), 8, UIKit.GOLD))
	if String(d.tag) != "":
		var tag := UIKit.label(d.tag, 8, UIKit.GREEN)
		tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(tag)
	var desc := UIKit.wrap_label(d.desc, 8, Color("b8c6d8"), 180)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(desc)
	var b: Button
	if owned and not bool(d.consumable):
		b = UIKit.button("ADQUIRIDO", "", 0, "check")
		b.disabled = true
	else:
		b = UIKit.button(Billing.price_text(id), "GoldButton", 0, "")
		b.disabled = not Billing.can_buy(id)
		b.pressed.connect(func(): Billing.buy(id))
	b.add_theme_font_size_override("font_size", 9)
	v.add_child(b)
	return p


func _store_card(id: String) -> Control:
	var d: Dictionary = Shop.ITEMS[id]
	var owned := Profile.owns(id)
	var p := PanelContainer.new()
	p.theme_type_variation = "Card_legend" if owned else "Card_common"
	p.custom_minimum_size = Vector2(192, 102)
	var v := UIKit.vbox(2)
	p.add_child(v)
	var h := UIKit.hbox(4)
	v.add_child(h)
	h.add_child(UIKit.icon_rect(d.icon, 16))
	h.add_child(UIKit.label(d.name.to_upper(), 8, UIKit.GOLD if owned else UIKit.WHITE))
	var desc := UIKit.wrap_label(d.desc, 8, Color("b8c6d8"), 180)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(desc)
	var b: Button
	var needs: String = d.get("needs", "")
	if not owned:
		if needs != "" and not Profile.owns(needs):
			b = UIKit.button("REQUER " + Shop.ITEMS[needs].name.to_upper(), "", 0, "lock")
			b.disabled = true
		else:
			b = UIKit.button("%d" % int(d.price), "GoldButton" if Profile.pearls >= int(d.price) else "", 0, "pearl")
			b.disabled = Profile.pearls < int(d.price)
			b.pressed.connect(func():
				if Profile.buy_item(id):
					Sfx.play_stinger("fusion")
					_show_store())
	elif d.cat == "tide":
		var on: bool = Profile.settings.get("tide", "") == id
		b = UIKit.button("EQUIPADA" if on else "EQUIPAR", "GoldButton" if on else "", 0, "check" if on else "")
		b.pressed.connect(func():
			Profile.set_setting("tide", "" if on else id)
			_show_store())
	elif d.cat == "mode":
		var modes: Array = Profile.settings.get("modes", []).duplicate()
		var on2 := modes.has(id)
		b = UIKit.button("LIGADO" if on2 else "DESLIGADO", "GoldButton" if on2 else "", 0, "check" if on2 else "")
		b.pressed.connect(func():
			if on2:
				modes.erase(id)
			else:
				modes.append(id)
			Profile.set_setting("modes", modes)
			_show_store())
	else:
		b = UIKit.button("ADQUIRIDO", "", 0, "check")
		b.disabled = true
	b.add_theme_font_size_override("font_size", 9)
	v.add_child(b)
	return p


func _start_game() -> void:
	if not Profile.seen_tutorial:
		Profile.seen_tutorial = true
		Profile.save_game()
		_show_guide(true)
		return
	Sfx.play("card")
	get_tree().change_scene_to_file("res://scenes/game.tscn")


# ------------------------------------------------------------------- shop
func _show_shop() -> void:
	var v := _open_screen("EVOLUÇÃO ANCESTRAL")
	var info := UIKit.hbox(6)
	v.add_child(info)
	info.add_child(UIKit.label("Melhorias permanentes compradas com pérolas.", 8, UIKit.DIM))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(584, 262)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	for id in DB.META:
		grid.add_child(_shop_entry(id))


func _shop_entry(id: String) -> Control:
	var d: Dictionary = DB.META[id]
	var lvl := Profile.upgrade_level(id)
	var cost := Profile.upgrade_cost(id)
	var p := PanelContainer.new()
	p.theme_type_variation = "LightPanel"
	p.custom_minimum_size = Vector2(186, 74)
	var v := UIKit.vbox(3)
	p.add_child(v)
	var h := UIKit.hbox(4)
	h.add_child(UIKit.icon_rect(d.icon, 16))
	h.add_child(UIKit.wrap_label(d.name, 8, UIKit.WHITE, 150))
	v.add_child(h)
	v.add_child(UIKit.label(d.desc, 8, UIKit.DIM))
	var h2 := UIKit.hbox(4)
	var pips := Control.new()
	var mx: int = d.max
	pips.custom_minimum_size = Vector2(70, 8)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pips.draw.connect(func():
		for i in mx:
			pips.draw_rect(Rect2(i * 12, 0, 10, 6), UIKit.GOLD if i < lvl else Color(1, 1, 1, 0.15)))
	h2.add_child(pips)
	var b: Button
	if cost < 0:
		b = UIKit.button("MÁX", "", 90)
		b.disabled = true
	else:
		b = UIKit.button(str(cost), "GoldButton" if Profile.pearls >= cost else "", 90, "pearl")
		b.disabled = Profile.pearls < cost
		b.pressed.connect(func():
			if Profile.buy_upgrade(id):
				Sfx.play("level_up")
				_show_shop())
	h2.add_child(b)
	v.add_child(h2)
	return p


# ------------------------------------------------------------------ guide
func _show_guide(start_after := false) -> void:
	var v := _open_screen("COMO JOGAR")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(584, 236)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := UIKit.vbox(6)
	scroll.add_child(list)
	var tips := [
		["wave", "MOVER", "Arraste o polegar no lado esquerdo da tela (ou WASD)."],
		["fang", "MORDER", "Botão vermelho (ou ESPAÇO). Segure para morder sem parar. Criaturas menores que você são engolidas inteiras!"],
		["dash", "INVESTIDA", "Botão azul (ou SHIFT): arrancada rápida com cargas, ideal para fugir de predadores."],
		["star", "CRESCER", "Coma para ganhar XP. A cada nível escolha uma carta; em certos níveis você CRESCE e ganha uma MUTAÇÃO que muda sua aparência."],
		["cycle", "CADEIA ALIMENTAR", "Nutrientes fazem o kelp e o plâncton crescerem; herbívoros comem plantas, carnívoros comem herbívoros, a orca come todos. Carcaças viram detritos que os pequenos recicladores transformam em nutrientes."],
		["leaf", "DIETA", "Morda kelp e plâncton (herbívoro), cace (carnívoro) ou coma carcaças (necrófago). Sua dieta dá bônus próprios."],
		["dna", "SINERGIAS", "Cada arma, passiva e mutação tem uma afinidade. Junte 2 ou 4 da mesma para bônus poderosos."],
		["torpedo", "EVOLUÇÕES", "Arma no nível 5 + sua passiva parceira = carta de EVOLUÇÃO lendária."],
		["skull", "COMBO", "Abates seguidos aumentam o combo e o XP. Com combo 50 você entra em FRENESI."],
		["crown", "ALFAS", "Inimigos com coroa são Alfas: derrote-os para ganhar Escamas (rerrolagens)."],
		["hidden", "ESCONDERIJOS", "Cavernas e moitas escondem você e regeneram vida. Fique escondido tempo suficiente e até um CHEFE desiste, deixando seu alimento."],
		["clock", "CICLOS", "Explore -> a ONDA chega -> o CHEFE aparece. Vença 5 chefes para dominar o oceano; cada chefe vencido vira uma espécie jogável."],
		["target", "TITANACON", "O último chefe engole você! Lá dentro, ataque o coração e as glândulas, derrote os parasitas e fuja do ácido no fundo até ele te cuspir."],
		["dna", "PARASITAS", "Piolhos-do-mar entram pelas brânquias (a Investida os espanta). Com uma fêmea, eles cruzam e a colônia cresce no seu corpo: ela te deixa lento e come XP, mas te salva da morte e, cheia, explode num ENXAME que devora inimigos. Coma camarões-limpadores para se livrar deles."],
		["skull", "MINHOCA-DO-MAR", "Montinhos de areia com antenas escondem o verme-de-bobbit: ele salta, morde e pode deixar uma larva de piolho em você."],
		["fish", "PERSONAGENS", "28 bichos jogáveis: compre com pérolas, cumpra metas ou vença chefes. Cada um tem um TRAÇO único e traz um ITEM único que passa a aparecer nas cartas de todas as partidas."],
		["dna", "FUSÃO", "Leve duas armas de uma receita ao nível 5: surge a carta de FUSÃO. A arma fundida libera um espaço e sobe até o nível 10! Veja as receitas em COLEÇÃO."],
		["chest", "LOJA", "Gaste pérolas em expansões (bioma novo, bichos, chefe), relíquias, marés e modos de jogo com bônus de pérolas."],
		["chest", "EVENTOS", "Baús (1, 3 ou 5 prêmios!), ostras gigantes, fendas térmicas e cardumes dourados surgem por tempo limitado."],
		["pearl", "PÉROLAS", "Guarde pérolas entre partidas: evoluções ancestrais, novas espécies, missões e recompensa diária."],
	]
	for t in tips:
		var h := UIKit.hbox(8)
		h.add_child(UIKit.icon_rect(t[0], 16))
		var l := UIKit.label(t[1], 8, UIKit.GOLD)
		l.custom_minimum_size.x = 100
		h.add_child(l)
		h.add_child(UIKit.wrap_label(t[2], 8, UIKit.WHITE, 440))
		list.add_child(h)
	if start_after:
		var go := UIKit.button("ENTENDI, MERGULHAR!", "GoldButton", 220, "play")
		go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		go.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game.tscn"))
		v.add_child(go)


# ---------------------------------------------------------------- options
func _show_options() -> void:
	var v := _open_screen("OPÇÕES", Vector2(360, 220))
	v.add_child(SettingsView.new())
	var reset := UIKit.button("APAGAR PROGRESSO", "RedButton", 0, "skull")
	var armed := [false]
	reset.pressed.connect(func():
		if not armed[0]:
			armed[0] = true
			reset.text = "TEM CERTEZA?"
			return
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.SAVE_PATH))
		Profile.pearls = 0
		Profile.upgrades = {}
		Profile.unlocked = ["dourado"]
		Profile.selected_species = "dourado"
		Profile.records = {"runs": 0, "wins": 0, "best_time": 0.0, "best_level": 0, "best_cycle": 0, "kills": 0, "bosses": 0, "pearls_total": 0}
		Profile.seen_tutorial = false
		Profile.owned = []
		Profile.stats = {}
		Profile.missions_done = []
		Profile.settings.erase("tide")
		Profile.settings.erase("modes")
		Profile.save_game()
		reset.text = "APAGADO")
	v.add_child(reset)


func _show_credits() -> void:
	var v := _open_screen("CRÉDITOS", Vector2(420, 230))
	var lines := [
		["ROGUE FISH", UIKit.GOLD],
		["Design, código e pixel art procedural", UIKit.WHITE],
		["Feito com Godot Engine (MIT)", UIKit.DIM],
		["Fontes: Pixelify Sans e Press Start 2P (SIL OFL)", UIKit.DIM],
		["Efeitos e trilhas chiptune gerados por síntese", UIKit.DIM],
		["", UIKit.DIM],
		["Obrigado por jogar!", UIKit.CYAN],
	]
	for l in lines:
		v.add_child(UIKit.label(l[0], 8, l[1], HORIZONTAL_ALIGNMENT_CENTER))
	var fp := FishPreview.new().setup(Profile.selected_species, 4, {"head": "head_lure", "skin": "skin_glow", "tail": "tail_eel", "fins": "fins_volt"}, 1.0)
	fp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(fp)


# --------------------------------------------------------------- missions
func _show_missions() -> void:
	var v := _open_screen("MISSÕES")
	var done := Profile.missions_done.size()
	v.add_child(UIKit.label("Concluídas %d/%d  -  recompensas entregues automaticamente" % [done, DB.MISSIONS.size()], 8, UIKit.DIM))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(584, 262)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := UIKit.vbox(4)
	scroll.add_child(list)
	var sorted := DB.MISSIONS.duplicate()
	sorted.sort_custom(func(a, b): return int(Profile.missions_done.has(a.id)) < int(Profile.missions_done.has(b.id)))
	for m in sorted:
		var is_done: bool = Profile.missions_done.has(m.id)
		var p := PanelContainer.new()
		p.theme_type_variation = "LightPanel"
		p.custom_minimum_size = Vector2(570, 0)
		var h := UIKit.hbox(8)
		p.add_child(h)
		h.add_child(UIKit.icon_rect("check" if is_done else "target", 16))
		var col := UIKit.vbox(1)
		col.custom_minimum_size.x = 300
		col.add_child(UIKit.label(m.name, 8, UIKit.GREEN if is_done else UIKit.WHITE))
		var unlock: String = ("  -  desbloqueia " + DB.WEAPONS[m.unlock].name) if m.has("unlock") else ""
		col.add_child(UIKit.label(m.desc + unlock, 8, UIKit.DIM))
		h.add_child(col)
		var prog := clampf(Profile.stat(m.stat) / float(m.target), 0.0, 1.0)
		var bar := UIKit.bar("bar_xp", Vector2(120, 8))
		bar.value = 1.0 if is_done else prog
		h.add_child(bar)
		var r := UIKit.hbox(2)
		r.add_child(UIKit.icon_rect("pearl", 12))
		r.add_child(UIKit.label(str(m.pearls), 8, UIKit.GOLD))
		h.add_child(r)
		if is_done:
			p.modulate = Color(0.75, 0.9, 0.75)
		list.add_child(p)


# --------------------------------------------------------------- bestiary
func _show_bestiary() -> void:
	var v := _open_screen("BESTIÁRIO")
	var seen := 0
	var total := 0
	for id in DB.CREATURES:
		if id == "golden" or not DB.creature_available(id):
			continue
		total += 1
		if Profile.bestiary.get(id, {}).get("seen", false):
			seen += 1
	v.add_child(UIKit.label("Espécies descobertas: %d/%d" % [seen, total], 8, UIKit.DIM))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(584, 262)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	var order := ["producer", "detritivore", "herbivore", "carnivore", "predator", "mega"]
	var ids := DB.CREATURES.keys().filter(func(i): return i != "golden" and DB.creature_available(i))
	ids.sort_custom(func(a, b): return order.find(DB.CREATURES[a].trophic) < order.find(DB.CREATURES[b].trophic))
	for id in ids:
		grid.add_child(_bestiary_card(id))


func _bestiary_card(id: String) -> Control:
	var d: Dictionary = DB.CREATURES[id]
	var e: Dictionary = Profile.bestiary.get(id, {})
	var known: bool = e.get("seen", false)
	var p := PanelContainer.new()
	p.theme_type_variation = "LightPanel"
	p.custom_minimum_size = Vector2(186, 96)
	var v := UIKit.vbox(2)
	p.add_child(v)
	var path: String = "creatures/" + d.sheet
	var info := Art.sheet_info(path)
	var at := AtlasTexture.new()
	at.atlas = Art.tex(path)
	at.region = Rect2(0, 0, info.w, info.h)
	var sc := clampf(floorf(48.0 / maxf(info.w, info.h * 1.5)), 1.0, 3.0) if info.w < 100 else 0.5
	var pic := UIKit.tex_rect(at, Vector2(info.w, info.h) * sc)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if not known:
		pic.modulate = Color(0.05, 0.07, 0.12)
	v.add_child(pic)
	v.add_child(UIKit.label(d.name if known else "???", 8, UIKit.GOLD if known else UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label(DB.TROPHIC_NAMES[d.trophic], 8, UIKit.CYAN, HORIZONTAL_ALIGNMENT_CENTER))
	if known:
		v.add_child(UIKit.wrap_label(d.get("short", d.desc), 8, Color("b8c6d8"), 136))
		v.add_child(UIKit.label("Abatidos: %d" % int(e.get("kills", 0)), 8, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	return p


# ------------------------------------------------------------ daily reward
func _show_daily() -> void:
	var amount := Profile.daily_available()
	if amount <= 0:
		return
	var v := _open_screen("RECOMPENSA DIÁRIA", Vector2(440, 0))
	var next := Profile._next_streak()
	v.add_child(UIKit.label("Volte todo dia para aumentar o prêmio!", 8, UIKit.DIM))
	var row := UIKit.hbox(4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in Profile.DAILY_REWARDS.size():
		var box := PanelContainer.new()
		box.theme_type_variation = "Card_legend" if i + 1 == next else ("Card_rare" if i + 1 < next else "Card_common")
		box.custom_minimum_size = Vector2(56, 64)
		var bv := UIKit.vbox(2)
		box.add_child(bv)
		bv.add_child(UIKit.label("DIA %d" % (i + 1), 8, UIKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
		var ic := UIKit.icon_rect("gift" if i == 6 else "pearl", 16)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bv.add_child(ic)
		bv.add_child(UIKit.label(str(Profile.DAILY_REWARDS[i]), 8, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		row.add_child(box)
	v.add_child(row)
	var bh := UIKit.hbox(8)
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(bh)
	var b := UIKit.button("RESGATAR +%d" % amount, "", 150, "gift")
	b.pressed.connect(func():
		Profile.claim_daily()
		Sfx.play("level_up")
		_close_screen()
		_main.visible = true)
	bh.add_child(b)
	if Ads.can_show("daily_x2"):
		var b2 := UIKit.button("VÍDEO: +%d (x2)" % (amount * 2), "GoldButton", 150, "play")
		b2.pressed.connect(func():
			Ads.show_rewarded("daily_x2", func():
				Profile.claim_daily()
				Profile.add_pearls(amount)
				Profile.save_game()
				Sfx.play("level_up")
				_close_screen()
				_main.visible = true))
		bh.add_child(b2)
