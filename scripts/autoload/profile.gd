extends Node
## Persistent player profile: meta currency, upgrades, unlocks, settings, records.

signal changed

const SAVE_PATH := "user://roguefish_save.json"
const VERSION := 1

var pearls := 0
var upgrades: Dictionary = {}
var unlocked: Array = ["dourado"]
var selected_species := "dourado"
var settings := {
	"music": 0.7, "sfx": 0.8, "vibration": true, "shake": true, "damage_numbers": true,
}
var records := {
	"runs": 0, "wins": 0, "best_time": 0.0, "best_level": 0, "best_cycle": 0,
	"kills": 0, "bosses": 0, "pearls_total": 0,
}
var seen_tutorial := false


func _ready() -> void:
	load_game()
	_apply_audio()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	pearls = int(data.get("pearls", 0))
	upgrades = data.get("upgrades", {})
	unlocked = data.get("unlocked", ["dourado"])
	selected_species = data.get("selected_species", "dourado")
	seen_tutorial = bool(data.get("seen_tutorial", false))
	var s: Dictionary = data.get("settings", {})
	for k in s:
		settings[k] = s[k]
	var r: Dictionary = data.get("records", {})
	for k in r:
		records[k] = r[k]
	if not unlocked.has(selected_species):
		selected_species = "dourado"


func save_game() -> void:
	var data := {
		"version": VERSION, "pearls": pearls, "upgrades": upgrades, "unlocked": unlocked,
		"selected_species": selected_species, "settings": settings, "records": records,
		"seen_tutorial": seen_tutorial,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
	changed.emit()


func upgrade_level(id: String) -> int:
	return int(upgrades.get(id, 0))


func upgrade_cost(id: String) -> int:
	var d: Dictionary = DB.META[id]
	var lvl := upgrade_level(id)
	if lvl >= int(d.max):
		return -1
	return int(d.cost[lvl])


func buy_upgrade(id: String) -> bool:
	var cost := upgrade_cost(id)
	if cost < 0 or pearls < cost:
		return false
	pearls -= cost
	upgrades[id] = upgrade_level(id) + 1
	save_game()
	return true


func buy_species(id: String) -> bool:
	var price := int(DB.SPECIES[id].price)
	if unlocked.has(id) or pearls < price:
		return false
	pearls -= price
	unlocked.append(id)
	selected_species = id
	save_game()
	return true


func add_pearls(n: int) -> void:
	pearls += n
	records.pearls_total = int(records.pearls_total) + n


func set_setting(key: String, value) -> void:
	settings[key] = value
	_apply_audio()
	save_game()


func _apply_audio() -> void:
	var music_bus := AudioServer.get_bus_index("Music")
	var sfx_bus := AudioServer.get_bus_index("SFX")
	if music_bus >= 0:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(maxf(0.0001, float(settings.music))))
	if sfx_bus >= 0:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(maxf(0.0001, float(settings.sfx))))


func record_run(result: Dictionary) -> void:
	records.runs = int(records.runs) + 1
	if result.get("won", false):
		records.wins = int(records.wins) + 1
	records.best_time = maxf(float(records.best_time), float(result.get("time", 0.0)))
	records.best_level = maxi(int(records.best_level), int(result.get("level", 0)))
	records.best_cycle = maxi(int(records.best_cycle), int(result.get("cycle", 0)))
	records.kills = int(records.kills) + int(result.get("kills", 0))
	records.bosses = int(records.bosses) + int(result.get("bosses", 0))
	save_game()


func vibrate(ms: int) -> void:
	if settings.get("vibration", true) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
