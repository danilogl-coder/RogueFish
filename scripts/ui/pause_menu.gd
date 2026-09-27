class_name PauseMenu
extends Control
## Pause: resume, status (attributes, stats, synergies), options, quit.

signal closed

var game
var _content: Control
var _tabs: HBoxContainer


func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIKit.dim_background(self, 0.7)
	var panel := UIKit.center_panel(self, Vector2(560, 318))
	var v := UIKit.vbox(6)
	panel.add_child(v)
	var top := UIKit.hbox(6)
	v.add_child(top)
	top.add_child(UIKit.label("PAUSA", 16, UIKit.GOLD))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(UIKit.label("%s  NV %d  %s" % [DB.format_time(game.time), game.level, Evolutions.stage_name(game.player.species, game.player.stage).to_upper()], 8, UIKit.DIM))
	_tabs = UIKit.hbox(4)
	v.add_child(_tabs)
	for t in [["STATUS", "_show_status"], ["ARSENAL", "_show_arsenal"], ["SINERGIAS", "_show_synergies"], ["ECOSSISTEMA", "_show_ecosystem"], ["OPÇÕES", "_show_options"]]:
		var b := UIKit.button(t[0])
		b.pressed.connect(Callable(self, t[1]))
		_tabs.add_child(b)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.add_child(sp2)
	var quit := UIKit.button("DESISTIR", "RedButton")
	quit.pressed.connect(_confirm_quit)
	_tabs.add_child(quit)
	var resume := UIKit.button("CONTINUAR", "GoldButton", 0, "play")
	resume.pressed.connect(_resume)
	_tabs.add_child(resume)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540, 240)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_content = UIKit.vbox(6)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	UIKit.pop_in(panel)
	_show_status()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_resume()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_resume()
		get_viewport().set_input_as_handled()


func _clear() -> void:
	for c in _content.get_children():
		c.queue_free()


func _show_status() -> void:
	_clear()
	var p: Player = game.player
	var cols := UIKit.hbox(16)
	_content.add_child(cols)
	# attributes
	var left := UIKit.vbox(5)
	cols.add_child(left)
	left.add_child(UIKit.label("ATRIBUTOS  (pontos: %d)" % game.status_points, 8, UIKit.GOLD))
	for key in DB.ATTRIBUTES:
		var a: Dictionary = DB.ATTRIBUTES[key]
		var h := UIKit.hbox(4)
		h.add_child(UIKit.icon_rect(a.icon, 16))
		var l := UIKit.label("%s %d/%d" % [a.full.to_upper(), p.attributes[key], DB.ATTRIBUTE_MAX], 8)
		l.custom_minimum_size.x = 118
		h.add_child(l)
		var b := UIKit.button("+", "GoldButton", 24)
		b.disabled = game.status_points <= 0 or p.attributes[key] >= DB.ATTRIBUTE_MAX
		b.pressed.connect(func():
			if game.status_points > 0 and p.add_attribute(key):
				game.status_points -= 1
				_show_status())
		h.add_child(b)
		left.add_child(h)
		left.add_child(UIKit.label("   " + a.desc, 8, UIKit.DIM))
	# stats
	var right := UIKit.vbox(3)
	cols.add_child(right)
	right.add_child(UIKit.label("ESTATÍSTICAS", 8, UIKit.GOLD))
	var s: Dictionary = p.st
	var rows := [
		["Vida", "%d/%d" % [p.hp, s.max_hp]], ["Regeneração", "%.1f/s" % s.regen],
		["Armadura", "%d" % s.armor], ["Mordida", "%d" % (s.bite_damage * s.damage_mult)],
		["Dano", "+%d%%" % ((s.damage_mult - 1.0) * 100.0)], ["Crítico", "%d%% x%.1f" % [s.crit_chance * 100.0, s.crit_mult]],
		["Velocidade", "%d" % s.speed], ["Recarga", "-%d%%" % ((1.0 - s.cooldown_mult) * 100.0)],
		["Área", "+%d%%" % ((s.area_mult - 1.0) * 100.0)], ["Coleta", "%d" % s.magnet],
		["Experiência", "+%d%%" % ((s.xp_mult - 1.0) * 100.0)], ["Sorte", "+%d%%" % (s.luck * 100.0)],
	]
	for r in rows:
		var h2 := UIKit.hbox(4)
		var k := UIKit.label(r[0], 8, UIKit.DIM)
		k.custom_minimum_size.x = 110
		h2.add_child(k)
		h2.add_child(UIKit.label(r[1], 8))
		right.add_child(h2)
	# mutations
	var mut := UIKit.vbox(4)
	cols.add_child(mut)
	mut.add_child(UIKit.label("MUTAÇÕES", 8, UIKit.GREEN))
	mut.add_child(FishPreview.new().setup(p.species, p.stage, p.mutations, 1.0 if p.stage >= 3 else 2.0))
	for slot in DB.MUTATION_SLOTS:
		var mid: String = p.mutations.get(slot, "")
		mut.add_child(UIKit.wrap_label(Families.mutation_name(p.species, mid) if mid != "" else "- vazio -", 8, UIKit.WHITE if mid != "" else UIKit.DIM, 130))


## Items of this run: levels, fusion recipes in reach, the character's trait
## and the shop modifiers that are active.
func _show_arsenal() -> void:
	_clear()
	var p: Player = game.player
	var cols := UIKit.hbox(14)
	_content.add_child(cols)
	var left := UIKit.vbox(4)
	left.custom_minimum_size.x = 300
	cols.add_child(left)
	left.add_child(UIKit.label("ITENS", 8, UIKit.GOLD))
	for wid in p.weapons:
		var w: Weapon = p.weapons[wid]
		var h := UIKit.hbox(4)
		h.add_child(UIKit.icon_rect(w.icon_name(), 16))
		var fused := w.is_fusion()
		var txt := "%s  NV %d/%d" % [w.display_name(), w.level, DB.weapon_max(wid)]
		if w.evo != "":
			txt = "%s  EVOLUÍDA" % w.display_name()
		h.add_child(UIKit.label(txt, 8, Color("ff8ae0") if fused else (UIKit.GOLD if w.evo != "" else UIKit.WHITE)))
		left.add_child(h)
	left.add_child(UIKit.label("FUSÕES POSSÍVEIS", 8, Color("ff8ae0")))
	var any := false
	for fid in DB.FUSIONS:
		var f: Dictionary = DB.FUSIONS[fid]
		var a: String = f.from[0]
		var b: String = f.from[1]
		if p.weapons.has(fid) or not (p.weapons.has(a) or p.weapons.has(b)):
			continue
		var need := []
		for wid2 in f.from:
			if not p.weapons.has(wid2):
				need.append("pegar " + DB.WEAPONS[wid2].name)
			elif p.weapons[wid2].level < DB.MAX_LEVEL:
				need.append("%s nv %d" % [DB.WEAPONS[wid2].name, DB.MAX_LEVEL])
		var row := UIKit.hbox(4)
		row.add_child(UIKit.icon_rect(f.icon, 16))
		row.add_child(UIKit.wrap_label("%s: %s" % [f.name, "PRONTA! (escolha nas cartas)" if need.is_empty() else "falta " + ", ".join(need)], 8, UIKit.GREEN if need.is_empty() else UIKit.DIM, 270))
		left.add_child(row)
		any = true
	if not any:
		left.add_child(UIKit.wrap_label("Pegue as duas armas de uma receita (veja COLEÇÃO no menu) e leve ambas ao nível 5.", 8, UIKit.DIM, 280))
	var right := UIKit.vbox(4)
	cols.add_child(right)
	var sp: Dictionary = DB.SPECIES[p.species]
	right.add_child(UIKit.label(sp.name.to_upper(), 8, UIKit.GOLD))
	right.add_child(UIKit.label("TRAÇO: " + sp.trait.name.to_upper(), 8, UIKit.GREEN))
	right.add_child(UIKit.wrap_label(sp.trait.desc, 8, Color("b8c6d8"), 210))
	if game.mods.tide != "":
		right.add_child(UIKit.label("MARÉ: " + Shop.ITEMS[game.mods.tide].name.to_upper(), 8, UIKit.CYAN))
		right.add_child(UIKit.wrap_label(Shop.ITEMS[game.mods.tide].desc, 8, Color("b8c6d8"), 210))
	for m in game.mods.modes:
		right.add_child(UIKit.label("MODO: " + Shop.ITEMS[m].name.to_upper(), 8, UIKit.RED))
	var relics := []
	for id in Shop.ITEMS:
		if Shop.ITEMS[id].cat == "relic" and Profile.owns(id):
			relics.append(id)
	if not relics.is_empty():
		right.add_child(UIKit.label("RELÍQUIAS", 8, UIKit.PURPLE))
		var rr := UIKit.hbox(2)
		for id in relics:
			rr.add_child(UIKit.icon_rect(Shop.ITEMS[id].icon, 16))
		right.add_child(rr)
	if game.banishes > 0:
		right.add_child(UIKit.label("BANIMENTOS: %d" % game.banishes, 8, UIKit.DIM))


func _show_synergies() -> void:
	_clear()
	var p: Player = game.player
	_content.add_child(UIKit.label("Junte itens da mesma afinidade para ativar bônus (2 e 4 itens).", 8, UIKit.DIM))
	for tag in DB.TAGS:
		var n: int = p.tag_counts.get(tag, 0)
		var h := UIKit.hbox(6)
		h.add_child(UIKit.icon_rect(DB.TAGS[tag].icon, 16))
		var name_l := UIKit.label("%s  %d" % [DB.TAGS[tag].name.to_upper(), n], 8, DB.TAGS[tag].color)
		name_l.custom_minimum_size.x = 104
		h.add_child(name_l)
		var v := UIKit.vbox(1)
		var bonus: Array = DB.SYNERGIES[tag]
		v.add_child(UIKit.label(("[2] " if n >= 2 else "( 2) ") + bonus[0], 8, UIKit.WHITE if n >= 2 else UIKit.DIM))
		v.add_child(UIKit.label(("[4] " if n >= 4 else "( 4) ") + bonus[1], 8, UIKit.WHITE if n >= 4 else UIKit.DIM))
		h.add_child(v)
		_content.add_child(h)
	_content.add_child(UIKit.label("COMBINAÇÕES (2 + 2)", 8, UIKit.GOLD))
	for cid in DB.COMBOS:
		var c: Dictionary = DB.COMBOS[cid]
		var on: bool = p.active_combos.has(cid)
		var names := []
		for t in c.tags:
			names.append(DB.TAGS[t].name)
		_content.add_child(UIKit.label("%s %s (%s): %s" % ["[*]" if on else "[ ]", c.name, " + ".join(names), c.desc], 8, UIKit.GREEN if on else UIKit.DIM))


func _show_ecosystem() -> void:
	_clear()
	var eco: Ecosystem = game.ecosystem
	var counts: Dictionary = eco.trophic_counts()
	_content.add_child(UIKit.label("CADEIA ALIMENTAR (agora)", 8, UIKit.GOLD))
	var order := ["mega", "predator", "carnivore", "herbivore", "detritivore", "producer"]
	var colors := {"mega": UIKit.RED, "predator": Color("ff9a5c"), "carnivore": UIKit.GOLD, "herbivore": UIKit.GREEN, "detritivore": Color("d2a672"), "producer": UIKit.CYAN}
	var mx := 1
	for k in order:
		mx = maxi(mx, int(counts.get(k, 0)))
	for k in order:
		var h := UIKit.hbox(6)
		var l := UIKit.label(DB.TROPHIC_NAMES[k], 8, colors[k])
		l.custom_minimum_size.x = 120
		h.add_child(l)
		var n: int = counts.get(k, 0)
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(260, 8)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var w := 258.0 * sqrt(float(n) / mx)
		var c: Color = colors[k]
		bar.draw.connect(func():
			bar.draw_rect(Rect2(0, 0, 260, 8), Color(0.02, 0.05, 0.1))
			bar.draw_rect(Rect2(1, 1, w, 6), c))
		h.add_child(bar)
		h.add_child(UIKit.label(str(n), 8))
		_content.add_child(h)
	_content.add_child(UIKit.label("NUTRIENTES POR BIOMA", 8, UIKit.GOLD))
	var nh := UIKit.hbox(14)
	for b in DB.BIOMES:
		nh.add_child(UIKit.label("%s: %d" % [b.name, int(eco.average_nutrients(b.id))], 8, UIKit.WHITE))
	_content.add_child(nh)
	var s: Dictionary = eco.stats
	_content.add_child(UIKit.label("Nascimentos %d   |   Predações %d   |   Mortes de fome %d   |   Nutrientes reciclados %d" % [s.births, s.eaten, s.starved, int(s.recycled)], 8, UIKit.DIM))
	_content.add_child(UIKit.wrap_label("Ciclo: nutrientes alimentam kelp e fitoplâncton -> herbívoros -> carnívoros -> predadores -> orca. Toda morte vira carcaça; carcaças e fezes viram detritos (neve marinha) que isópodes, pepinos-do-mar e camarões reciclam em nutrientes. No abismo, fontes hidrotermais criam vida sem sol. Poucas lontras? Os ouriços devoram o kelp!", 8, Color("b8c6d8"), 530))
	var p: Player = game.player
	var dt: String = p.diet_type()
	var diet_txt := "Dieta: %s (plantas %d%%, carne %d%%, carniça %d%%)" % [DB.DIETS[dt].name + " - " + DB.DIETS[dt].desc if dt != "" else "indefinida", p.diet_share("plant") * 100, p.diet_share("meat") * 100, p.diet_share("scavenge") * 100]
	_content.add_child(UIKit.wrap_label(diet_txt, 8, UIKit.GREEN, 530))


func _show_options() -> void:
	_clear()
	_content.add_child(SettingsView.new())


func _confirm_quit() -> void:
	_clear()
	_content.add_child(UIKit.label("Desistir da partida? As pérolas coletadas serão mantidas.", 8, UIKit.WHITE))
	var h := UIKit.hbox(8)
	var yes := UIKit.button("SIM, DESISTIR", "RedButton")
	yes.pressed.connect(func():
		queue_free()
		game.player.alive = false
		game.run_over = true
		game._end_run(false))
	h.add_child(yes)
	var no := UIKit.button("VOLTAR")
	no.pressed.connect(_show_status)
	h.add_child(no)
	_content.add_child(h)


func _resume() -> void:
	game.hud.controls.release_all()
	closed.emit()
	queue_free()
