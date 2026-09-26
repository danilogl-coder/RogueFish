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
	top.add_child(UIKit.label("%s  NV %d  %s" % [DB.format_time(game.time), game.level, DB.STAGE_NAMES[game.player.stage].to_upper()], 8, UIKit.DIM))
	_tabs = UIKit.hbox(4)
	v.add_child(_tabs)
	for t in [["STATUS", "_show_status"], ["SINERGIAS", "_show_synergies"], ["OPÇÕES", "_show_options"]]:
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
		mut.add_child(UIKit.wrap_label(DB.MUTATIONS[mid].name if mid != "" else "- vazio -", 8, UIKit.WHITE if mid != "" else UIKit.DIM, 130))


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
