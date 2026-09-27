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


## Offer a revive for a video, with a countdown that gives up on its own.
func show_continue(on_revive: Callable, on_give_up: Callable) -> void:
	var panel := UIKit.center_panel(self, Vector2(340, 170))
	var v := UIKit.vbox(8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)
	v.add_child(UIKit.label("CONTINUAR?", 24, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("Volte com metade da vida e uma onda que limpa os inimigos.", 8, UIKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var timer_bar := UIKit.bar("bar_hp", Vector2(220, 8))
	timer_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	timer_bar.value = 1.0
	v.add_child(timer_bar)
	var h := UIKit.hbox(8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	var decided := [false]
	var watch := UIKit.button("VÍDEO: REVIVER" if not Profile.vip else "REVIVER (VIP)", "GoldButton", 0, "play")
	var give := UIKit.button("DESISTIR", "", 0, "back")
	h.add_child(watch)
	h.add_child(give)
	var tw := create_tween()
	tw.tween_property(timer_bar, "value", 0.0, 8.0)
	tw.finished.connect(func():
		if not decided[0]:
			decided[0] = true
			on_give_up.call())
	watch.pressed.connect(func():
		if decided[0]:
			return
		decided[0] = true
		tw.kill()
		Ads.show_rewarded("revive", on_revive, on_give_up))
	give.pressed.connect(func():
		if decided[0]:
			return
		decided[0] = true
		tw.kill()
		on_give_up.call())
	UIKit.pop_in(panel)


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
		["Tempo", DB.format_time(r.time)], ["Nível", str(r.level)], ["Fase", Evolutions.stage_name(game.player.species, r.stage)],
		["Ciclo", str(r.cycle)], ["Abates", str(r.kills)], ["Chefes", str(r.bosses)],
		["Pérolas", "+%d" % r.pearls], [tr("Bônus"), "+%d" % r.bonus],
	]
	if float(r.get("mode_mult", 1.0)) > 1.0:
		rows.append(["Modos", "x%.1f" % float(r.mode_mult)])
	for row in rows:
		grid.add_child(UIKit.label(row[0], 8, UIKit.DIM))
		grid.add_child(UIKit.label(row[1], 8, UIKit.WHITE))
	var total := UIKit.hbox(4)
	total.alignment = BoxContainer.ALIGNMENT_CENTER
	total.add_child(UIKit.icon_rect("pearl", 16))
	var total_lbl := UIKit.label(tr("TOTAL: %d   (banco: %d)") % [r.pearls + r.bonus, Profile.pearls], 8, UIKit.GOLD)
	total.add_child(total_lbl)
	v.add_child(total)
	# rewarded video: double what this run earned
	var earned: int = int(r.pearls) + int(r.bonus)
	if earned > 0 and Ads.remaining("double") > 0:
		var dbl := UIKit.button(tr("VÍDEO: DOBRAR +%d PÉROLAS") % earned if not Profile.vip else tr("VIP: DOBRAR +%d PÉROLAS") % earned, "GoldButton", 0, "pearl")
		dbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		dbl.pressed.connect(func():
			dbl.disabled = true
			Ads.show_rewarded("double", func():
				Profile.add_pearls(earned)
				Profile.save_game()
				Sfx.play("level_up")
				total_lbl.text = tr("TOTAL: %d   (banco: %d)") % [earned * 2, Profile.pearls]
				dbl.text = "PÉROLAS DOBRADAS!", func(): dbl.disabled = false))
		v.add_child(dbl)
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
