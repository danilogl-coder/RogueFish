class_name Ecosystem
extends Node
## Nutrient cycle and population dynamics.
##
##   nutrients -> kelp / phytoplankton (producers) -> herbivores -> carnivores
##   -> predators -> mega predator.  Every death leaves a carcass; carcasses and
##   excretions become detritus (marine snow) eaten by detritivores, which
##   release nutrients back into the water. Hydrothermal vents add nutrients in
##   the dark abyss (chemosynthesis) and the continental slope has upwelling.

const COLS := 24
const MAX_PLANKTON := 90
const MAX_DETRITUS := 160

var game
var nutrients := PackedFloat32Array()
var col_w := 200.0
var species_counts: Dictionary = {}
var stats := {"births": 0, "starved": 0, "eaten": 0, "recycled": 0.0}
var _t := 0.0


func _ready() -> void:
	col_w = DB.WORLD_W / COLS
	nutrients.resize(COLS)
	for i in COLS:
		var b: Dictionary = DB.biome_at((i + 0.5) * col_w)
		nutrients[i] = {"reef": 45.0, "kelp": 60.0, "slope": 35.0, "abyss": 25.0}[b.id]


func col_of(x: float) -> int:
	return clampi(int(x / col_w), 0, COLS - 1)


func nutrient_at(x: float) -> float:
	return nutrients[col_of(x)]


func add_nutrients(x: float, amount: float) -> void:
	var c := col_of(x)
	nutrients[c] = minf(nutrients[c] + amount, 140.0)
	stats.recycled += amount


func take_nutrients(x: float, amount: float) -> bool:
	var c := col_of(x)
	if nutrients[c] < amount:
		return false
	nutrients[c] -= amount
	return true


func average_nutrients(biome_id: String) -> float:
	var total := 0.0
	var n := 0
	for i in COLS:
		if DB.biome_at((i + 0.5) * col_w).id == biome_id:
			total += nutrients[i]
			n += 1
	return total / maxf(1.0, n)


func spawn_detritus(pos: Vector2, count := 1) -> void:
	if game.detritus.size() >= MAX_DETRITUS:
		add_nutrients(pos.x, 0.8 * count)
		return
	for i in count:
		game.spawn_pickup("detritus", pos + Vector2(randf_range(-6, 6), randf_range(-4, 4)), 1)


func spawn_carcass(pos: Vector2, food: int) -> void:
	if food <= 0:
		return
	if game.carcasses.size() >= 45:
		spawn_detritus(pos, mini(food, 2))
		return
	var c := Carcass.new()
	c.game = game
	c.position = pos
	c.setup(food)
	game.layer_pickups.add_child(c)
	game.carcasses.append(c)


func _physics_process(delta: float) -> void:
	_t += delta
	if _t < 0.5:
		return
	var dt := _t
	_t = 0.0
	# chemosynthesis at vents + upwelling on the slope
	for v in game.world.vents:
		add_nutrients(v.x, 1.2 * dt)
		if randf() < 0.12 and game.detritus.size() < MAX_DETRITUS * 0.6:
			spawn_detritus(v + Vector2(randf_range(-20, 20), randf_range(-10, 10)))
	# the whale fall keeps shedding food for scavengers
	for w in game.world.whale_falls:
		if randf() < 0.25 and game.detritus.size() < MAX_DETRITUS * 0.6:
			spawn_detritus(w + Vector2(randf_range(-50, 50), randf_range(-6, 4)))
	# upwelling: deep, nutrient-rich water rises along the slope and feeds the
	# shallows; rivers bring a little runoff to the coast (reef side).
	var deep := 0.0
	var deep_cols := []
	var shallow_cols := []
	for i in COLS:
		var id: String = DB.biome_at((i + 0.5) * col_w).id
		if id == "abyss" or id == "slope":
			deep_cols.append(i)
			deep += nutrients[i]
		else:
			shallow_cols.append(i)
			nutrients[i] = minf(nutrients[i] + (0.12 if id == "reef" else 0.08) * dt, 140.0)
	var flux := deep * 0.015 * dt
	for i in deep_cols:
		nutrients[i] -= nutrients[i] * 0.015 * dt
	for i in shallow_cols:
		nutrients[i] = minf(nutrients[i] + flux / shallow_cols.size(), 140.0)
	# diffusion between neighbouring columns
	var copy := nutrients.duplicate()
	for i in COLS:
		var l := copy[maxi(0, i - 1)]
		var r := copy[mini(COLS - 1, i + 1)]
		nutrients[i] = copy[i] + ((l + r) * 0.5 - copy[i]) * 0.1
	# phytoplankton blooms need light (near the surface) and nutrients
	for k in 3:
		if game.plankton.size() >= MAX_PLANKTON:
			break
		var x := randf_range(40, 3700)
		if nutrient_at(x) > 12.0 and take_nutrients(x, 1.2):
			game.spawn_pickup("phyto", Vector2(x, randf_range(40, 280)), 1)
	# marine snow: dead plankton drifting down near the action
	if randf() < 0.5 and game.player:
		var px: float = game.player.position.x + randf_range(-400, 400)
		spawn_detritus(Vector2(clampf(px, 20, DB.WORLD_W - 20), randf_range(30, 200)))
	_count_species()


func _count_species() -> void:
	species_counts.clear()
	for c in game.creatures:
		if is_instance_valid(c) and not c.dead and not c.is_boss:
			species_counts[c.id] = int(species_counts.get(c.id, 0)) + 1


## Called by a well-fed animal. Births are capped per species so the web stays
## balanced; starvation and predation remove the surplus.
func try_breed(c) -> bool:
	if c.is_wave or c.elite or c.id in ["golden", "orca", "moray", "otter"]:
		return false
	if game.creatures.size() > game.MAX_CREATURES * 0.85:
		return false
	var pop: Dictionary = DB.POPULATION[mini(game.director.cycle - 1, DB.POPULATION.size() - 1)]
	var cap := int(ceil(float(pop.get(c.id, 0)) * 1.6))
	if int(species_counts.get(c.id, 0)) >= cap:
		return false
	var baby: Creature = game.spawn_creature(c.id, c.position + Vector2(randf_range(-10, 10), randf_range(-6, 6)), {"baby": true})
	if baby == null:
		return false
	species_counts[c.id] = int(species_counts.get(c.id, 0)) + 1
	stats.births += 1
	return true


## Snapshot for the pause-menu ecosystem panel.
func trophic_counts() -> Dictionary:
	var out := {"producer": 0, "detritivore": 0, "herbivore": 0, "carnivore": 0, "predator": 0, "mega": 0}
	for k in game.world.kelps:
		out.producer += k.segments
	out.producer += game.plankton.size()
	for c in game.creatures:
		if is_instance_valid(c) and not c.dead and not c.is_boss and c.trophic != "":
			out[c.trophic] = int(out.get(c.trophic, 0)) + 1
	return out
