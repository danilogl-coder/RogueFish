extends Node
## Debug-only bot used for automated smoke tests:
##   godot --path . res://scenes/game.tscn -- --autotest [--god] [--shots=DIR] [--speed=N] [--minutes=N]
## Plays by itself, picks cards, logs progress and optionally saves screenshots.

var game
var god := false
var shots_dir := ""
var minutes := 10.0
var speed := 4.0
var _bite_t := 0.0
var _log_t := 0.0
var _shot_t := 0.0
var _shot_n := 0
var _wander := Vector2.RIGHT
var _wander_t := 0.0
var _card_shots := 0
var shot_every := 2.5
var idle := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a == "--god":
			god = true
		elif a.begins_with("--shots="):
			shots_dir = a.split("=")[1]
		elif a.begins_with("--minutes="):
			minutes = float(a.split("=")[1])
		elif a.begins_with("--shot-every="):
			shot_every = float(a.split("=")[1])
		elif a.begins_with("--x="):
			var x := float(a.split("=")[1])
			game.player.position = Vector2(x, DB.floor_at(x) * float(a.split("=")[2]) if a.split("=").size() > 2 else DB.floor_at(x) - 80.0)
			game.camera.global_position = game.player.position
			game.camera.reset_smoothing()
		elif a.begins_with("--idle"):
			idle = true
		elif a.begins_with("--speed="):
			speed = float(a.split("=")[1])
	Engine.time_scale = speed
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--open="):
			_open_debug(a.substr(7))
		if a.begins_with("--boss="):
			var n := int(a.split("=")[1])
			await get_tree().process_frame
			game.director.cycle = n
			for i in 8 + n * 5:
				game.level += 1
				game.status_points += 1
			game.player.grow_to(DB.stage_for_level(game.level))
			for w in ["pulse", "spines", "sonar"]:
				game.player.add_weapon(w)
			game.director._enter("boss")
	Engine.physics_ticks_per_second = 60
	Engine.max_physics_steps_per_frame = 16
	print("[autotest] start god=%s speed=%s minutes=%s" % [god, speed, minutes])


func _process(delta: float) -> void:
	if game == null:
		return
	var real := delta / maxf(Engine.time_scale, 0.001)
	# auto-pick menus
	if Array(OS.get_cmdline_user_args()).any(func(x): return x.begins_with("--open=")):
		return
	for m in game.menus.get_children():
		if m is CardPanel and m._ready_t <= 0.0 and not m._done and not m.has_meta("shot") and shots_dir != "" and _card_shots < 5:
			m.set_meta("shot", true)
			_card_shots += 1
			_screenshot("card_%d_%s" % [_card_shots, m.mode])
			return
		if m is CardPanel and m._ready_t <= 0.0 and not m._done:
			if game.status_points > 0 and m._attr_row:
				var keys := DB.ATTRIBUTES.keys()
				game.player.add_attribute(keys[randi() % keys.size()])
				game.status_points -= 1
			var best := 0
			for i in m.offers.size():
				if m.offers[i].kind in ["evolution", "mutation", "weapon_new"]:
					best = i
			m._choose(best)
			print("[autotest] t=%.0f picked %s %s" % [game.time, m.offers[best].kind, m.offers[best].id])
		elif m is ChestPanel and m._btn.visible:
			if shots_dir != "" and not m.has_meta("shot"):
				m.set_meta("shot", true)
				_screenshot("chest_%d" % _shot_n)
				_shot_n += 1
				return
			print("[autotest] t=%.0f chest x%d" % [game.time, m._rewards.size()])
			m._close()
		elif m is GameOverMenu:
			print("[autotest] run ended won=%s t=%.0f level=%d kills=%d cycle=%d hits=%s" % [game.won, game.time, game.level, game.kills, game.director.cycle, str(game.player.hit_log)])
			_screenshot("end")
			get_tree().quit()
			return
	if game.time > minutes * 60.0:
		print("[autotest] time limit reached t=%.0f" % game.time)
		_screenshot("final")
		get_tree().quit()
		return
	if shots_dir != "":
		_shot_t -= real
		if _shot_t <= 0.0:
			_shot_t = shot_every
			_screenshot("%03d" % _shot_n)
			_shot_n += 1


func _physics_process(delta: float) -> void:
	if game == null or game.run_over or get_tree().paused:
		return
	var p: Player = game.player
	if god:
		p.hp = p.st.max_hp
	# kite: move away from nearby dangerous things, otherwise hunt edible prey
	var danger := Vector2.ZERO
	var target := Vector2.INF
	var best := 280.0 * 280.0
	for c in game.creatures:
		if not is_instance_valid(c) or c.dead:
			continue
		var d: float = c.position.distance_squared_to(p.position)
		var threat: bool = c.hostile_now() and c.contact_damage > 0.0 and (c.tier >= p.stage or c.is_boss)
		if threat and d < 70.0 * 70.0:
			danger += (p.position - c.position).normalized() * (1.0 - sqrt(d) / 70.0)
		var edible: bool = not c.is_boss and (c.tier <= p.stage or (c.faction == "pred" and c.tier <= p.stage + 1)) and c.id != "turtle" and c.id != "jellyfish"
		if edible and d < best:
			best = d
			target = c.position
	for poi in game.world.pois:
		if is_instance_valid(poi) and poi.is_active():
			target = poi.position + Vector2(0, -12)
	var dir := Vector2.ZERO
	if danger.length() > 0.25:
		dir = danger
	elif target != Vector2.INF:
		dir = (target - p.position)
		if dir.length() < 10.0:
			dir = Vector2.ZERO
	else:
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = 3.0
			_wander = Vector2.from_angle(randf() * TAU)
		dir = _wander
	if idle:
		dir = Vector2(sin(game.time * 0.4), cos(game.time * 0.3) * 0.3) * 0.3
	game.hud.debug_dir = dir.normalized() * (0.4 if idle else 1.0)
	_bite_t -= delta
	if _bite_t <= 0.0:
		_bite_t = 0.25
		p.try_bite()
	_log_t -= delta
	if _log_t <= 0.0:
		_log_t = 30.0
		print("[autotest] t=%.0f phase=%s cycle=%d lvl=%d stage=%d hp=%d/%d creatures=%d pickups=%d fps=%d weapons=%s" % [
			game.time, game.director.phase, game.director.cycle, game.level, p.stage, p.hp, p.st.max_hp,
			game.creatures.size(), game.pickups.size(), Engine.get_frames_per_second(), str(p.weapons.keys())])
		var eco = game.ecosystem
		var nut := []
		for b in DB.BIOMES:
			nut.append(int(eco.average_nutrients(b.id)))
		print("[eco] trophic=%s nutrients=%s stats=%s plankton=%d detritus=%d carcass=%d kelp_seg=%d species=%s" % [
			str(eco.trophic_counts()), str(nut), str(eco.stats), game.plankton.size(), game.detritus.size(), game.carcasses.size(),
			eco.trophic_counts().producer - game.plankton.size(), str(eco.species_counts)])


func _open_debug(what: String) -> void:
	await get_tree().create_timer(3.0, true, false, true).timeout
	Engine.time_scale = 1.0
	match what:
		"pause":
			game.status_points = 2
			game.player.add_mutation("skin_armor")
			game.open_pause()
		"mutation":
			for i in 5:
				game.add_xp(game.xp_next)
			for k in 8:
				await get_tree().create_timer(0.6, true, false, true).timeout
				for m in game.menus.get_children():
					if m is CardPanel and m.mode != "mutation" and not m._done:
						m._ready_t = 0.0
						m._choose(0)
		"gameover":
			god = false
			game.player.revives = 0
			game.player._invuln = 0.0
			game.player.take_damage(99999.0, null)
	await get_tree().create_timer(2.5, true, false, true).timeout
	for m in game.menus.get_children():
		if m is CardPanel and what == "mutation" and m.mode != "mutation":
			m._choose(0)
	await get_tree().create_timer(1.2, true, false, true).timeout
	_screenshot("open_" + what)
	get_tree().quit()


func _screenshot(tag: String) -> void:
	if shots_dir == "":
		return
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("%s/shot_%s.png" % [shots_dir, tag])
