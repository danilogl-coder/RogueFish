class_name ChestPanel
extends Control
## Treasure chest jackpot: a slot machine spins through item icons, slows down
## and lands on 1, 3 or 5 rewards (luck and boss chests raise the odds).
## Rewards are applied automatically, like Vampire Survivors chests.

signal closed

var game
var _slot: TextureRect
var _slot_frame: PanelContainer
var _title: Label
var _list: VBoxContainer
var _btn: Button
var _rewards: Array = []
var _icons: Array = []
var _done := false


func open(boss_reward: bool) -> void:
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIKit.dim_background(self, 0.78)
	var panel := UIKit.center_panel(self, Vector2(320, 250))
	var v := UIKit.vbox(6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)
	_title = UIKit.label("TESOURO!", 24, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_title)
	_slot_frame = PanelContainer.new()
	_slot_frame.theme_type_variation = "Card_legend"
	_slot_frame.custom_minimum_size = Vector2(76, 76)
	_slot_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_slot_frame)
	_slot = UIKit.icon_rect("chest", 48)
	_slot_frame.add_child(_slot)
	_list = UIKit.vbox(3)
	v.add_child(_list)
	_btn = UIKit.button("PEGAR!", "GoldButton", 140, "check")
	_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_btn.visible = false
	_btn.pressed.connect(_close)
	v.add_child(_btn)
	UIKit.pop_in(panel)
	_roll(boss_reward)
	_spin()


func _roll(boss_reward: bool) -> void:
	var luck: float = game.player.st.luck
	var r := randf() / (1.0 + luck * 0.6)
	var n := 1
	if boss_reward:
		n = 5 if r < 0.35 else 3
	elif r < 0.07:
		n = 5
	elif r < 0.35:
		n = 3
	var helper := CardPanel.new()
	helper.game = game
	var evos: Array = helper._available_evolutions()
	if not evos.is_empty() and (boss_reward or randf() < 0.5):
		_rewards.append(evos[0])
	var pool: Array = helper._level_pool().filter(func(o): return o.kind != "evolution")
	pool.shuffle()
	var used := {}
	for o in pool:
		if _rewards.size() >= n:
			break
		if used.has(o.id):
			continue
		used[o.id] = true
		_rewards.append(o)
	while _rewards.size() < n:
		_rewards.append(helper._filler(_rewards.size()))
	helper.free()
	for id in DB.WEAPONS:
		_icons.append(DB.WEAPONS[id].icon)
	for id in DB.PASSIVES:
		_icons.append(DB.PASSIVES[id].icon)


func _spin() -> void:
	Profile.bump("chests")
	var steps := 26
	for i in steps:
		_slot.texture = Art.icon(_icons[randi() % _icons.size()])
		Sfx.play_pitched("click", 0.8 + i * 0.03, -6.0)
		var wait := 0.04 + pow(float(i) / steps, 3.0) * 0.28
		await get_tree().create_timer(wait, true, false, true).timeout
	var n := _rewards.size()
	_slot.texture = Art.icon(_rewards[0].icon)
	var labels := {1: "TESOURO!", 3: "TRIPLO!!", 5: "JACKPOT!!!"}
	_title.text = labels.get(n, "TESOURO!")
	_title.add_theme_color_override("font_color", UIKit.GOLD if n < 5 else UIKit.RED)
	Sfx.play("chest")
	if n >= 3:
		Sfx.play("level_up")
	game.shake(2.0 + n)
	var pearls := 4 * n
	game.add_pearls(pearls)
	for i in n:
		var o: Dictionary = _rewards[i]
		CardPanel.apply_offer(game, o)
		var row := UIKit.hbox(6)
		row.add_child(UIKit.icon_rect(o.icon, 16))
		var suffix := ""
		match o.kind:
			"weapon_up", "passive_up":
				suffix = "  NV %d" % (o.level + 1)
			"weapon_new", "passive_new":
				suffix = "  NOVO!"
			"evolution":
				suffix = "  EVOLUÇÃO!"
		row.add_child(UIKit.label(o.title + suffix, 8, UIKit.RARITY_COLOR.get(o.rarity, UIKit.WHITE)))
		_list.add_child(row)
		UIKit.pop_in(row)
		Sfx.play_pitched("pearl", 1.0 + i * 0.12, -4.0)
		await get_tree().create_timer(0.22, true, false, true).timeout
	var pr := UIKit.hbox(4)
	pr.alignment = BoxContainer.ALIGNMENT_CENTER
	pr.add_child(UIKit.icon_rect("pearl", 12))
	pr.add_child(UIKit.label("+%d pérolas" % pearls, 8, UIKit.WHITE))
	_list.add_child(pr)
	_btn.visible = true
	UIKit.pop_in(_btn)


func _close() -> void:
	if _done:
		return
	_done = true
	closed.emit()
	queue_free()
