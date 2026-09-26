class_name Director
extends Node
## Run timeline: EXPLORE (ecosystem + timed points of interest) -> WAVE (horde)
## -> BOSS. Four cycles win the run; endless mode continues afterwards.

signal phase_changed(phase: String)
signal poi_spawned(poi)

const POI_KINDS := ["chest", "clam", "vent", "golden"]

var game
var cycle := 1
var phase := "explore"
var phase_t := 0.0
var phase_len := 70.0
var endless := false
var _pop_t := 0.0
var _wave_t := 0.0
var _poi_schedule: Array = []
var _warned := false


func start() -> void:
	# initial population spread around the whole map
	var pop: Dictionary = DB.POPULATION[0]
	for id in pop:
		var n: int = int(pop[id])
		var i := 0
		while i < n:
			var group := _group_size(id)
			_spawn_eco(id, group, true)
			i += group
	_enter("explore")


func difficulty() -> Dictionary:
	var c := float(cycle - 1)
	var t: float = game.time if game else 0.0
	var hp := 1.0 + 0.5 * c + t / 900.0
	var dmg := 1.0 + 0.22 * c
	var boss_hp := 1.0 + 0.12 * c
	if endless:
		hp *= 1.35
		dmg *= 1.2
		boss_hp *= 1.6
	return {"hp": hp, "dmg": dmg, "boss_hp": boss_hp}


func time_left() -> float:
	return maxf(0.0, phase_len - phase_t)


func _enter(p: String) -> void:
	phase = p
	phase_t = 0.0
	_warned = false
	var ci := mini(cycle - 1, 3)
	match p:
		"explore":
			phase_len = DB.EXPLORE_TIME[ci]
			_poi_schedule = [12.0, phase_len * 0.55]
			game.darkness.extra = 0.0
			game.darkness.tint_target = Color(0.01, 0.02, 0.07)
			game.hud.banner("CICLO %d" % cycle, "Explore, coma e cresça", Color("5ee0ff"))
			Sfx.play_music("game")
		"wave":
			phase_len = DB.WAVE_TIME
			_wave_t = 0.0
			game.darkness.extra = 0.12
			game.darkness.tint_target = Color(0.14, 0.0, 0.03)
			game.hud.banner("ONDA %d!" % cycle, "Sobreviva à horda", Color("ff5c4c"))
			Sfx.play("wave")
			game.shake(4.0)
		"boss":
			phase_len = 0.0
			var bid: String = DB.BOSS_ORDER[(cycle - 1) % DB.BOSS_ORDER.size()]
			var p2: Vector2 = game.player.position
			var side := -1.0 if p2.x > DB.WORLD_W * 0.5 else 1.0
			var pos := Vector2(clampf(p2.x + side * 380.0, 60, DB.WORLD_W - 60), clampf(p2.y - 40.0, 90, DB.FLOOR_Y - 90))
			game.spawn_boss(bid, pos)
			game.darkness.extra = maxf(game.darkness.extra, 0.15)
			game.darkness.tint_target = Color(0.06, 0.0, 0.08)
			game.hud.banner("CHEFE", DB.BOSSES[bid].name, Color("cc7ee0"))
			Sfx.play("boss_roar")
			Sfx.play_music("boss")
			game.shake(8.0)
	phase_changed.emit(phase)


func _physics_process(delta: float) -> void:
	if game.run_over:
		return
	phase_t += delta
	match phase:
		"explore":
			_maintain_population(delta)
			if not _poi_schedule.is_empty() and phase_t >= _poi_schedule[0]:
				_poi_schedule.pop_front()
				_spawn_poi()
			if not _warned and time_left() <= 5.0:
				_warned = true
				game.hud.toast("A horda se aproxima!", Color("ff5c4c"))
				Sfx.play("warning")
			if phase_t >= phase_len:
				_enter("wave")
		"wave":
			_maintain_population(delta * 0.3)
			_spawn_wave(delta)
			if phase_t >= phase_len:
				_enter("boss")
		"boss":
			_maintain_population(delta * 0.2)


func on_boss_killed() -> void:
	game.hud.banner("VITÓRIA!", "Chefe derrotado", Color("ffbf45"))
	if cycle >= DB.BOSS_ORDER.size() and not endless:
		game.on_victory()
		return
	phase = "rest"
	await get_tree().create_timer(3.5, false).timeout
	next_cycle()


func next_cycle() -> void:
	cycle += 1
	_enter("explore")


# -------------------------------------------------------------- ecosystem
func _group_size(id: String) -> int:
	match id:
		"sardine":
			return randi_range(5, 8)
		"piranha":
			return randi_range(2, 4)
	return 1


func _maintain_population(delta: float) -> void:
	_pop_t -= delta
	if _pop_t > 0.0:
		return
	_pop_t = 1.0
	var counts := {}
	for c in game.creatures:
		if is_instance_valid(c) and not c.is_wave and not c.is_boss:
			counts[c.id] = int(counts.get(c.id, 0)) + 1
	var pop: Dictionary = DB.POPULATION[mini(cycle - 1, DB.POPULATION.size() - 1)]
	_recycle_far()
	for id in pop:
		var target: int = int(pop[id])
		if id == "moray":
			continue
		var have: int = int(counts.get(id, 0))
		if have < target and randf() < 0.6:
			_spawn_eco(id, mini(_group_size(id), target - have + 2), false)
	# morays live in their rocks
	var morays: int = int(counts.get("moray", 0))
	if morays < game.world.eel_rocks.size() and cycle >= 1 and randf() < 0.2:
		var rock: Node2D = game.world.eel_rocks[randi() % game.world.eel_rocks.size()]
		var occupied := false
		for c in game.creatures:
			if is_instance_valid(c) and c.id == "moray" and c.home.distance_to(rock.position) < 10.0:
				occupied = true
		if not occupied and not _on_screen(rock.position, 40.0):
			game.spawn_creature("moray", rock.position + Vector2(2, 6))


## Keeps the area around the player lively: creatures far away are quietly
## moved to an off-screen spot near the player.
func _recycle_far() -> void:
	var p: Vector2 = game.player.position
	var moved := 0
	for c in game.creatures:
		if moved >= 3:
			break
		if not is_instance_valid(c) or c.dead or c.is_wave or c.is_boss or c.id == "moray" or c.faction == "gold":
			continue
		if absf(c.position.x - p.x) > 1300.0 and randf() < 0.25:
			var nx := clampf(p.x + randf_range(420, 700) * (1.0 if randf() < 0.5 else -1.0), 60, DB.WORLD_W - 60)
			if not _on_screen(Vector2(nx, c.position.y), 40.0):
				c.position.x = nx
				c.home = c.position
				moved += 1


func _spawn_eco(id: String, count: int, anywhere: bool) -> void:
	var def: Dictionary = DB.CREATURES[id]
	var depth: Array = def.depth
	var pos := Vector2.ZERO
	var near: bool = not anywhere and randf() < 0.65
	for attempt in 12:
		if near:
			pos.x = game.player.position.x + randf_range(380, 720) * (1.0 if randf() < 0.5 else -1.0)
			pos.x = clampf(pos.x, 60, DB.WORLD_W - 60)
		else:
			pos.x = randf_range(60, DB.WORLD_W - 60)
		pos.y = randf_range(float(depth[0]), float(depth[1])) * DB.FLOOR_Y
		if anywhere and game.player.position.distance_to(pos) > 200.0:
			break
		if not _on_screen(pos, 60.0):
			break
	pos.y = clampf(pos.y, 40.0, DB.FLOOR_Y - 8.0)
	for i in count:
		var elite: bool = cycle >= 2 and randf() < 0.02 * cycle and def.faction == "pred"
		game.spawn_creature(id, pos + Vector2(randf_range(-20, 20), randf_range(-12, 12)), {"elite": elite})


func _spawn_wave(delta: float) -> void:
	_wave_t -= delta
	if _wave_t > 0.0:
		return
	var k := phase_t / phase_len
	_wave_t = lerpf(1.6, 0.55, k) / (1.0 + 0.15 * (cycle - 1))
	var table: Dictionary = DB.WAVES[mini(cycle - 1, DB.WAVES.size() - 1)]
	var id := _weighted(table)
	var group := randi_range(2, 4) + int(k * 3.0) + (cycle - 1)
	if id == "shark" or id == "angler":
		group = 1
	var p: Vector2 = game.player.position
	var rect: Rect2 = game.visible_rect()
	var dist := rect.size.length() * 0.5 + 30.0
	var ang := randf() * TAU
	var base := p + Vector2.from_angle(ang) * dist
	base.x = clampf(base.x, 30, DB.WORLD_W - 30)
	base.y = clampf(base.y, 40, DB.FLOOR_Y - 20)
	if id == "crab":
		base.y = DB.FLOOR_Y - 6
	for i in group:
		var elite := randf() < 0.03 * cycle
		game.spawn_creature(id, base + Vector2(randf_range(-24, 24), randf_range(-16, 16)), {"wave": true, "elite": elite})


func _weighted(table: Dictionary) -> String:
	var total := 0.0
	for k in table:
		total += float(table[k])
	var r := randf() * total
	for k in table:
		r -= float(table[k])
		if r <= 0.0:
			return k
	return table.keys()[0]


func _on_screen(pos: Vector2, margin: float) -> bool:
	return game.visible_rect().grow(margin).has_point(pos)


func _spawn_poi() -> void:
	var kind: String = POI_KINDS[randi() % POI_KINDS.size()]
	var poi = game.world.spawn_poi(kind, game.player.position)
	var names := {"chest": "Um baú naufragado surgiu!", "clam": "Uma ostra gigante se abriu!", "vent": "Uma fenda térmica despertou!", "golden": "Um cardume dourado passa!"}
	game.hud.toast(names[kind], Color("ffbf45"))
	Sfx.play("pearl")
	poi_spawned.emit(poi)
