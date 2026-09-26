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


func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	Engine.time_scale = 1.0
	_build_background()
	_build_main()
	Sfx.play_music("menu")
	if Profile.daily_available() > 0 and not Array(OS.get_cmdline_user_args()).any(func(a): return a.begins_with("--menu=")):
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


# ------------------------------------------------------------- background
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
	seabed.texture = Art.tex("env/seabed")
	seabed.stretch_mode = TextureRect.STRETCH_TILE
	seabed.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	seabed.offset_top = -40
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
		s.frame = int(_bg_t * 8.0 + f.y) % mini(4, s.hframes)
	if _pearls_label:
		_pearls_label.text = str(Profile.pearls)


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
	var shop := UIKit.button("EVOLUÇÃO", "", 170, "dna")
	shop.pressed.connect(_show_shop)
	buttons.add_child(shop)
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
func _show_species() -> void:
	var v := _open_screen("ESCOLHA SEU PEIXE", Vector2(600, 0))
	var row := UIKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for sp in DB.SPECIES:
		row.add_child(_species_card(sp))
	var go := UIKit.button("MERGULHAR!", "GoldButton", 200, "play")
	go.custom_minimum_size.y = 26
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(_start_game)
	v.add_child(go)


func _species_card(sp: String) -> Control:
	var d: Dictionary = DB.SPECIES[sp]
	var unlocked := Profile.unlocked.has(sp)
	var selected := Profile.selected_species == sp
	var p := PanelContainer.new()
	p.theme_type_variation = "Card_legend" if selected else ("Card_rare" if unlocked else "Card_common")
	p.custom_minimum_size = Vector2(186, 0)
	var v := UIKit.vbox(4)
	p.add_child(v)
	v.add_child(UIKit.label(d.name.to_upper(), 8, UIKit.GOLD if selected else UIKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var prev := FishPreview.new().setup(sp, 1, {}, 2.0)
	prev.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if not unlocked:
		prev.modulate = Color(0.1, 0.12, 0.2)
	v.add_child(prev)
	v.add_child(UIKit.wrap_label(d.desc, 8, Color("b8c6d8"), 170))
	var s: Dictionary = d.stats
	for stat in [["VIDA", s.max_hp / 140.0, UIKit.RED], ["VELOC.", s.speed / 140.0, UIKit.CYAN], ["MORDIDA", s.bite_damage / 18.0, UIKit.GOLD]]:
		var h := UIKit.hbox(4)
		var l := UIKit.label(stat[0], 8, UIKit.DIM)
		l.custom_minimum_size.x = 64
		h.add_child(l)
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(96, 6)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var k: float = clampf(stat[1], 0.0, 1.0)
		var c: Color = stat[2]
		bar.draw.connect(func():
			bar.draw_rect(Rect2(0, 0, 96, 6), Color(0.02, 0.05, 0.1))
			bar.draw_rect(Rect2(1, 1, 94 * k, 4), c))
		h.add_child(bar)
		v.add_child(h)
	var wrow := UIKit.hbox(4)
	wrow.add_child(UIKit.icon_rect(DB.WEAPONS[d.weapon].icon, 16))
	wrow.add_child(UIKit.label(DB.WEAPONS[d.weapon].name, 8, UIKit.WHITE))
	v.add_child(wrow)
	var b: Button
	if unlocked:
		b = UIKit.button("SELECIONADO" if selected else "ESCOLHER", "GoldButton" if selected else "")
		b.pressed.connect(func():
			Profile.selected_species = sp
			Profile.save_game()
			_show_species())
	else:
		b = UIKit.button("%d PÉROLAS" % d.price, "", 0, "lock")
		b.disabled = Profile.pearls < int(d.price)
		b.pressed.connect(func():
			if Profile.buy_species(sp):
				Sfx.play("evolve")
				_show_species())
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
		["clock", "CICLOS", "Explore -> a ONDA chega -> o CHEFE aparece. Vença 4 chefes para dominar o oceano."],
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
	for id in DB.CREATURES:
		if id != "golden" and Profile.bestiary.get(id, {}).get("seen", false):
			seen += 1
	v.add_child(UIKit.label("Espécies descobertas: %d/%d" % [seen, DB.CREATURES.size() - 1], 8, UIKit.DIM))
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
	var ids := DB.CREATURES.keys().filter(func(i): return i != "golden")
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
		v.add_child(UIKit.wrap_label(d.desc, 8, Color("b8c6d8"), 170))
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
	var b := UIKit.button("RESGATAR +%d" % amount, "GoldButton", 200, "gift")
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		Profile.claim_daily()
		Sfx.play("level_up")
		_close_screen()
		_main.visible = true)
	v.add_child(b)
