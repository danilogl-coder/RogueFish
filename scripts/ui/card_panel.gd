class_name CardPanel
extends Control
## Vampire-Survivors style card choice. Modes:
##  level    - weapons / passives / evolutions + attribute points
##  mutation - growth stage reached: pick a visual mutation
##  treasure - chest reward (evolution guaranteed when available)

signal closed

var game
var mode := "level"
var extra := {}
var offers: Array = []
var _cards_row: HBoxContainer
var _title: Label
var _subtitle: Label
var _reroll_btn: Button
var _attr_row: HBoxContainer
var _points_label: Label
var _ready_t := 0.35
var _done := false
var _banish_btn: Button
var _banish_mode := false


func open(p_mode: String, p_extra := {}) -> void:
	mode = p_mode
	extra = p_extra
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIKit.dim_background(self, 0.72)
	var v := UIKit.vbox(8)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_top = 14
	v.offset_bottom = -8
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(v)
	_title = UIKit.label("", 16, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_title)
	_subtitle = UIKit.label("", 8, UIKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_subtitle)
	_cards_row = UIKit.hbox(8)
	_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_cards_row)
	var bottom := UIKit.hbox(10)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(bottom)
	if mode == "level":
		_points_label = UIKit.label("", 8, UIKit.GOLD)
		bottom.add_child(_points_label)
		_attr_row = UIKit.hbox(4)
		bottom.add_child(_attr_row)
	_reroll_btn = UIKit.button("", "", 0, "reroll")
	_reroll_btn.pressed.connect(_reroll)
	bottom.add_child(_reroll_btn)
	if game.banishes > 0 and mode == "level":
		_banish_btn = UIKit.button("BANIR %d" % game.banishes, "", 0, "skull")
		_banish_btn.pressed.connect(func():
			_banish_mode = not _banish_mode
			_banish_btn.text = ("TOQUE NA CARTA" if _banish_mode else "BANIR %d" % game.banishes))
		bottom.add_child(_banish_btn)
	match mode:
		"level":
			_title.text = "SUBIU DE NÍVEL!"
			_subtitle.text = "Nível %d  -  escolha uma melhoria" % game.level
		"mutation":
			_title.text = "CRESCIMENTO!"
			_title.add_theme_color_override("font_color", UIKit.GREEN)
			_subtitle.text = "Você virou %s. Escolha uma mutação:" % DB.STAGE_NAMES[game.player.stage].to_upper()
			if extra.get("boss_food", false):
				_title.text = "ALIMENTO DO CHEFE!"
				_subtitle.text = "Uma mutação rara aguarda. Escolha:"
		"treasure":
			_title.text = "TESOURO!"
			_subtitle.text = "Escolha sua recompensa"
	_build_offers()
	_refresh_attrs()
	_update_reroll()


func _process(delta: float) -> void:
	_ready_t -= delta


# ------------------------------------------------------------------ offers
func _build_offers() -> void:
	var n := 3 + (1 if Profile.upgrade_level("choice") > 0 else 0)
	if mode == "mutation":
		offers = _mutation_offers(3)
	elif mode == "treasure":
		offers = []
		if extra.get("evolution", false):
			for e in _available_evolutions():
				offers.append(e)
			for f in available_fusions(game.player):
				offers.append(f)
		var rest := _level_pool().filter(func(o): return o.kind != "evolution" or offers.is_empty())
		offers.append_array(_pick_weighted(rest, 3 - offers.size()))
		for o in offers:
			if o.rarity == "common":
				o.rarity = "rare"
		offers = offers.slice(0, 3)
	else:
		offers = _pick_weighted(_level_pool(), n)
	while offers.size() < (3 if mode != "level" else n):
		offers.append(_filler(offers.size()))
	_show_cards()


func _level_pool() -> Array:
	var p: Player = game.player
	var pool := []
	for id in DB.WEAPONS:
		var w: Dictionary = DB.WEAPONS[id]
		var fused: bool = w.get("fusion", false)
		if p.weapons.has(id):
			var wn: Weapon = p.weapons[id]
			if wn.evo == "" and wn.level < DB.weapon_max(id):
				pool.append(_offer("weapon_up", id, w.name, DB.weapon_desc(id, wn.level), w.icon, "epic" if fused else "common", w.tag, wn.level, 12.0 if fused else 10.0))
		elif fused or not DB.item_unlocked(id):
			continue
		elif p.weapons.size() < DB.MAX_WEAPONS:
			pool.append(_offer("weapon_new", id, w.name, DB.weapon_desc(id, 0), w.icon, "rare", w.tag, 0, 6.0))
	for id in DB.PASSIVES:
		var pd: Dictionary = DB.PASSIVES[id]
		var lvl: int = p.passives.get(id, 0)
		if lvl > 0 and lvl < DB.MAX_LEVEL:
			pool.append(_offer("passive_up", id, pd.name, pd.desc, pd.icon, "common", pd.tag, lvl, 7.0))
		elif lvl == 0 and p.passives.size() < DB.MAX_PASSIVES:
			pool.append(_offer("passive_new", id, pd.name, pd.desc, pd.icon, "common", pd.tag, 0, 5.0))
	for e in _available_evolutions():
		pool.append(e)
	for f in available_fusions(p):
		pool.append(f)
	pool = pool.filter(func(o): return not game.banished.has(o.id))
	# favour items that grow existing synergies
	for o in pool:
		if o.tag != "":
			o.weight *= 1.0 + 0.35 * float(p.tag_counts.get(o.tag, 0))
	return pool


func _available_evolutions() -> Array:
	var p: Player = game.player
	var out := []
	for evo in DB.EVOLUTIONS:
		var e: Dictionary = DB.EVOLUTIONS[evo]
		var from: String = e.from
		if p.weapons.has(from) and p.weapons[from].evo == "" and p.weapons[from].level >= DB.MAX_LEVEL and p.passives.has(DB.WEAPONS[from].pair):
			out.append(_offer("evolution", evo, e.name, e.desc, e.icon, "legend", DB.WEAPONS[from].tag, 5, 60.0))
	return out


## Two specific weapons at max level (not evolved) can fuse.
static func available_fusions(p) -> Array:
	var out := []
	for fid in DB.FUSIONS:
		var f: Dictionary = DB.FUSIONS[fid]
		var ok := true
		for wid in f.from:
			if not p.weapons.has(wid) or p.weapons[wid].evo != "" or p.weapons[wid].level < DB.MAX_LEVEL:
				ok = false
		if ok and not p.weapons.has(fid):
			var a: String = DB.WEAPONS[f.from[0]].name
			var b: String = DB.WEAPONS[f.from[1]].name
			var o := {"kind": "fusion", "id": fid, "title": f.name, "desc": "%s + %s\n%s" % [a, b, f.desc], "icon": f.icon,
				"rarity": "legend", "tag": f.tag, "level": 0, "weight": 80.0, "from": f.from}
			out.append(o)
	return out


func _mutation_offers(n: int) -> Array:
	var p: Player = game.player
	var free: Array = p.free_mutation_slots()
	var by_slot := {}
	for mid in DB.MUTATIONS:
		var m: Dictionary = DB.MUTATIONS[mid]
		if free.has(m.slot):
			if not by_slot.has(m.slot):
				by_slot[m.slot] = []
			by_slot[m.slot].append(mid)
	var picks := []
	var slots := by_slot.keys()
	slots.shuffle()
	# one per slot first for variety, then fill
	for s in slots:
		if picks.size() >= n:
			break
		var arr: Array = by_slot[s]
		picks.append(arr[randi() % arr.size()])
	var all := []
	for s in slots:
		for mid in by_slot[s]:
			if not picks.has(mid):
				all.append(mid)
	all.shuffle()
	while picks.size() < n and not all.is_empty():
		picks.append(all.pop_back())
	var out := []
	for mid in picks:
		var m: Dictionary = DB.MUTATIONS[mid]
		out.append(_offer("mutation", mid, m.name, m.desc, "dna", "mutation", m.tag, 0, 1.0))
	return out


func _offer(kind: String, id: String, title: String, desc: String, icon: String, rarity: String, tag: String, lvl: int, weight: float) -> Dictionary:
	return {"kind": kind, "id": id, "title": title, "desc": desc, "icon": icon, "rarity": rarity, "tag": tag, "level": lvl, "weight": weight}


func _filler(i: int) -> Dictionary:
	if i % 2 == 0:
		return _offer("heal", "heal", "Petisco", "Recupera 40% da vida.", "heart", "common", "", 0, 1.0)
	return _offer("pearls", "pearls", "Pérolas", "+10 pérolas.", "pearl", "common", "", 0, 1.0)


func _pick_weighted(pool: Array, n: int) -> Array:
	var out := []
	var items := pool.duplicate()
	while out.size() < n and not items.is_empty():
		var total := 0.0
		for it in items:
			total += it.weight
		var r := randf() * total
		for i in items.size():
			r -= items[i].weight
			if r <= 0.0:
				out.append(items[i])
				items.remove_at(i)
				break
	return out


# -------------------------------------------------------------------- UI
func _show_cards() -> void:
	for c in _cards_row.get_children():
		c.queue_free()
	var n := offers.size()
	var w := clampf((get_viewport_rect().size.x - 40.0 - (n - 1) * 8.0) / n, 110.0, 150.0)
	for i in n:
		var card := _make_card(offers[i], w)
		_cards_row.add_child(card)
		card.pressed.connect(_choose.bind(i))
		UIKit.pop_in(card, 0.06 * i)


func _make_card(o: Dictionary, w: float) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, 204 if o.kind == "mutation" else 176)
	var sb: StyleBoxTexture = UIKit.sb("ui/" + DB.RARITY_FRAME[o.rarity], 9, Vector4(7, 9, 7, 7))
	for s in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, sb)
	var v := UIKit.vbox(4)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 7
	v.offset_right = -7
	v.offset_top = 10
	v.offset_bottom = -7
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var col: Color = UIKit.RARITY_COLOR[o.rarity]
	var head := ""
	match o.kind:
		"weapon_new", "passive_new":
			head = "NOVO!"
		"weapon_up", "passive_up":
			head = "NV %d > %d" % [o.level, o.level + 1]
		"evolution":
			head = "EVOLUÇÃO"
		"fusion":
			head = "FUSÃO!"
		"mutation":
			head = "MUTAÇÃO"
		_:
			head = "EXTRA"
	v.add_child(UIKit.label(head, 8, col, HORIZONTAL_ALIGNMENT_CENTER))
	if o.kind == "mutation":
		var p: Player = game.player
		var muts: Dictionary = p.mutations.duplicate()
		muts[DB.MUTATIONS[o.id].slot] = o.id
		var meta := Art.player_meta(p.species, p.stage)
		var sc := clampf(floorf((w - 14.0) / float(meta.frame_w)), 1.0, 2.0)
		var prev := FishPreview.new().setup(p.species, p.stage, muts, sc)
		prev.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		prev.custom_minimum_size.y = minf(prev.custom_minimum_size.y, 64)
		v.add_child(prev)
	else:
		var ic := UIKit.icon_rect(o.icon, 32)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
	var t := UIKit.wrap_label(o.title, 8, UIKit.GOLD if o.rarity == "legend" else UIKit.WHITE, w - 16)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var d := UIKit.wrap_label(o.desc, 8, Color("b8c6d8"), w - 16)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(d)
	if o.tag != "":
		var chip := UIKit.hbox(3)
		chip.alignment = BoxContainer.ALIGNMENT_CENTER
		chip.add_child(UIKit.icon_rect(DB.TAGS[o.tag].icon, 12))
		chip.add_child(UIKit.label(DB.TAGS[o.tag].name, 8, DB.TAGS[o.tag].color))
		v.add_child(chip)
		var have: int = game.player.tag_counts.get(o.tag, 0)
		var adds: bool = o.kind in ["weapon_new", "passive_new", "mutation"]
		if adds and (have + 1 == 2 or have + 1 == 4):
			var syn := UIKit.label("SINERGIA %d!" % (have + 1), 8, UIKit.GREEN, HORIZONTAL_ALIGNMENT_CENTER)
			v.add_child(syn)
	b.mouse_entered.connect(func():
		b.pivot_offset = b.size * 0.5
		b.create_tween().tween_property(b, "scale", Vector2(1.04, 1.04), 0.08))
	b.mouse_exited.connect(func(): b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.08))
	return b


func _choose(i: int) -> void:
	if _done or _ready_t > 0.0:
		return
	if _banish_mode and game.banishes > 0 and offers[i].kind not in ["heal", "pearls"]:
		# Âncora do Banimento: the item leaves this run's pool, a new card takes its place
		game.banishes -= 1
		game.banished[offers[i].id] = true
		_banish_mode = false
		_banish_btn.text = "BANIR %d" % game.banishes
		_banish_btn.disabled = game.banishes <= 0
		var ids := offers.map(func(o): return o.id)
		var pool := _level_pool().filter(func(o): return not ids.has(o.id))
		var pick := _pick_weighted(pool, 1)
		offers[i] = pick[0] if not pick.is_empty() else _filler(i)
		Sfx.play("hurt", -6.0)
		_show_cards()
		return
	_done = true
	var o: Dictionary = offers[i]
	CardPanel.apply_offer(game, o)
	Sfx.play("card")
	var card: Control = _cards_row.get_child(i)
	var t := create_tween().set_parallel(true)
	t.tween_property(card, "scale", Vector2(1.15, 1.15), 0.15)
	for j in _cards_row.get_child_count():
		if j != i:
			t.tween_property(_cards_row.get_child(j), "modulate:a", 0.0, 0.15)
	t.chain().tween_property(self, "modulate:a", 0.0, 0.15)
	t.chain().tween_callback(_close)


static func apply_offer(g, o: Dictionary) -> void:
	var p: Player = g.player
	match o.kind:
		"weapon_new", "weapon_up":
			p.add_weapon(o.id)
		"passive_new", "passive_up":
			p.add_passive(o.id)
		"evolution":
			p.evolve_weapon(o.id)
		"fusion":
			p.fuse_weapons(o.id)
		"mutation":
			p.add_mutation(o.id)
		"heal":
			p.heal(p.st.max_hp * 0.4)
		"pearls":
			g.add_pearls(10)


func _close() -> void:
	closed.emit()
	queue_free()


func _reroll() -> void:
	if game.rerolls <= 0 or _done:
		return
	game.rerolls -= 1
	_build_offers()
	_update_reroll()


func _update_reroll() -> void:
	_reroll_btn.text = "REROLAR (%d)" % game.rerolls
	_reroll_btn.visible = game.rerolls > 0


# ------------------------------------------------------------- attributes
func _refresh_attrs() -> void:
	if _attr_row == null:
		return
	for c in _attr_row.get_children():
		c.queue_free()
	_points_label.text = "PONTOS: %d" % game.status_points
	for key in DB.ATTRIBUTES:
		var a: Dictionary = DB.ATTRIBUTES[key]
		var val: int = game.player.attributes[key]
		var b := UIKit.button("%s %d" % [a.name, val], "", 0, a.icon)
		b.disabled = game.status_points <= 0 or val >= DB.ATTRIBUTE_MAX
		b.tooltip_text = a.desc
		b.pressed.connect(func():
			if game.status_points > 0 and game.player.add_attribute(key):
				game.status_points -= 1
				Sfx.play("card", -6.0)
				_refresh_attrs())
		_attr_row.add_child(b)
