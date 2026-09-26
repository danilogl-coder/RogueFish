class_name GameOverMenu
extends Control
## End of run: defeat / victory results, pearls earned, retry or menu.
## Victory first offers to keep playing in endless mode.

var game


func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIKit.dim_background(self, 0.78)


func show_victory_choice() -> void:
	var panel := UIKit.center_panel(self, Vector2(380, 180))
	var v := UIKit.vbox(10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)
	v.add_child(UIKit.label("VITÓRIA!", 24, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("O Leviatã caiu. O oceano é seu.", 8, UIKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("Continuar no MODO INFINITO? (mais difícil)", 8, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var h := UIKit.hbox(8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var cont := UIKit.button("INFINITO", "RedButton", 0, "wave")
	cont.pressed.connect(func():
		queue_free()
		game.continue_endless())
	h.add_child(cont)
	var fin := UIKit.button("FINALIZAR", "GoldButton", 0, "trophy")
	fin.pressed.connect(func():
		for c in get_children():
			if c is PanelContainer:
				c.queue_free()
		show_result(game.finalize_run(true)))
	h.add_child(fin)
	v.add_child(h)
	UIKit.pop_in(panel)
	Sfx.play("level_up")


func show_result(r: Dictionary) -> void:
	var panel := UIKit.center_panel(self, Vector2(400, 280))
	var v := UIKit.vbox(6)
	panel.add_child(v)
	var won: bool = r.get("won", false)
	v.add_child(UIKit.label("VITÓRIA!" if won else "VOCÊ FOI DEVORADO", 16, UIKit.GOLD if won else UIKit.RED, HORIZONTAL_ALIGNMENT_CENTER))
	var sub := "Lenda dos mares" if won else "O oceano é implacável..."
	v.add_child(UIKit.label(sub, 8, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var body := UIKit.hbox(14)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(body)
	var prev := FishPreview.new().setup(game.player.species, game.player.stage, game.player.mutations, 1.0 if game.player.stage >= 3 else 2.0)
	body.add_child(prev)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	body.add_child(grid)
	var rows := [
		["Tempo", DB.format_time(r.time)], ["Nível", str(r.level)], ["Fase", DB.STAGE_NAMES[r.stage]],
		["Ciclo", str(r.cycle)], ["Abates", str(r.kills)], ["Chefes", str(r.bosses)],
		["Pérolas", "+%d" % r.pearls], ["Bônus", "+%d" % r.bonus],
	]
	for row in rows:
		grid.add_child(UIKit.label(row[0], 8, UIKit.DIM))
		grid.add_child(UIKit.label(row[1], 8, UIKit.WHITE))
	var total := UIKit.hbox(4)
	total.alignment = BoxContainer.ALIGNMENT_CENTER
	total.add_child(UIKit.icon_rect("pearl", 16))
	total.add_child(UIKit.label("TOTAL: %d   (banco: %d)" % [r.pearls + r.bonus, Profile.pearls], 8, UIKit.GOLD))
	v.add_child(total)
	if r.time >= float(Profile.records.best_time) - 0.01 and r.time > 30.0:
		v.add_child(UIKit.label("NOVO RECORDE DE TEMPO!", 8, UIKit.GREEN, HORIZONTAL_ALIGNMENT_CENTER))
	var h := UIKit.hbox(8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var again := UIKit.button("JOGAR DE NOVO", "GoldButton", 0, "play")
	again.pressed.connect(func(): game.restart())
	h.add_child(again)
	var menu := UIKit.button("MENU", "", 0, "back")
	menu.pressed.connect(func(): game.quit_to_menu())
	h.add_child(menu)
	v.add_child(h)
	UIKit.pop_in(panel)
