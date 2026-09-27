extends Node
## Persistent player profile: meta currency, upgrades, unlocks, settings, records.

signal changed
signal mission_completed(mission: Dictionary)

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
var stats: Dictionary = {}          # lifetime counters / maxima used by missions
var missions_done: Array = []
var bestiary: Dictionary = {}       # id -> {"seen": bool, "kills": int}
var unlocked_weapons: Array = []
var daily := {"last": "", "streak": 0}
var ad_log := {"date": "", "counts": {}, "last": {}}   ## rewarded videos watched (see Ads)
var purchases: Array = []       ## non-consumable products bought (see Billing)
var vip := false


func _ready() -> void:
	load_game()
	_apply_audio()


## Reads a save file; returns {} when missing or corrupt.
func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func load_game() -> void:
	var data := _read(SAVE_PATH)
	if data.is_empty():
		# the main file is missing or was cut by a crash: use the backup
		data = _read(SAVE_PATH + ".bak")
	if data.is_empty():
		return
	pearls = maxi(0, int(data.get("pearls", 0)))
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
	stats = data.get("stats", {})
	missions_done = data.get("missions_done", [])
	bestiary = data.get("bestiary", {})
	unlocked_weapons = data.get("unlocked_weapons", [])
	owned = data.get("owned", [])
	var al: Dictionary = data.get("ad_log", {})
	if not al.is_empty():
		ad_log = al
	purchases = data.get("purchases", [])
	vip = bool(data.get("vip", false)) or purchases.has("vip")
	var d: Dictionary = data.get("daily", {})
	if not d.is_empty():
		daily = d
	_retro_unlock_boss_species()
	check_stat_unlocks()
	if not DB.SPECIES.has(selected_species) or not unlocked.has(selected_species):
		selected_species = "dourado"


func save_game() -> void:
	var data := {
		"version": VERSION, "pearls": pearls, "upgrades": upgrades, "unlocked": unlocked,
		"selected_species": selected_species, "settings": settings, "records": records,
		"seen_tutorial": seen_tutorial, "stats": stats, "missions_done": missions_done,
		"bestiary": bestiary, "unlocked_weapons": unlocked_weapons, "daily": daily,
		"owned": owned, "ad_log": ad_log, "purchases": purchases, "vip": vip,
	}
	# write to a temp file first, then swap it in: a crash or the OS killing
	# the app mid-write can never leave a half-written save behind
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()
		var dir := DirAccess.open("user://")
		if dir:
			# keep the last good save as backup (never back up a broken one)
			if not _read(SAVE_PATH).is_empty():
				dir.copy(SAVE_PATH, SAVE_PATH + ".bak")
			if dir.rename(tmp, SAVE_PATH) != OK:
				dir.remove(SAVE_PATH)
				dir.rename(tmp, SAVE_PATH)
	changed.emit()


func _notification(what: int) -> void:
	# Android may kill the app at any time once it is in the background
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


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
	if unlocked.has(id) or pearls < price or not species_buyable(id):
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


# ---------------------------------------------------------------- missions
func stat(key: String) -> float:
	return float(stats.get(key, 0))


## Adds to a lifetime counter and checks missions. Saved at the end of runs.
## Defeating a boss unlocks it as a playable species. Returns the species id
## when it was just unlocked, "" otherwise.
func unlock_boss_species(boss_id: String) -> String:
	for sp in DB.SPECIES:
		if DB.SPECIES[sp].get("boss", "") == boss_id and not unlocked.has(sp):
			unlocked.append(sp)
			save_game()
			return sp
	return ""


## Saves from before this feature: bosses already beaten unlock their species.
func _retro_unlock_boss_species() -> void:
	for sp in DB.SPECIES:
		var b: String = DB.SPECIES[sp].get("boss", "")
		if b != "" and stat("boss_" + b) >= 1 and not unlocked.has(sp):
			unlocked.append(sp)


signal species_unlocked(id: String)


func bump(key: String, amount := 1) -> void:
	stats[key] = stat(key) + amount
	_check_missions(key)
	for sp in check_stat_unlocks():
		species_unlocked.emit(sp)


func set_max(key: String, value: float) -> void:
	if value > stat(key):
		stats[key] = value
		_check_missions(key)


func _check_missions(key: String) -> void:
	for m in DB.MISSIONS:
		if m.stat != key or missions_done.has(m.id):
			continue
		if stat(key) >= float(m.target):
			missions_done.append(m.id)
			pearls += int(m.pearls)
			records.pearls_total = int(records.pearls_total) + int(m.pearls)
			if m.has("unlock") and not unlocked_weapons.has(m.unlock):
				unlocked_weapons.append(m.unlock)
			mission_completed.emit(m)
			save_game()


func weapon_unlocked(id: String) -> bool:
	return DB.item_unlocked(id)


## Characters bought with pearls ("pack" ones need their expansion first).
func species_buyable(id: String) -> bool:
	var u: Dictionary = DB.SPECIES[id].unlock
	if u.type == "price":
		return true
	if u.type == "pack":
		return owns(u.pack)
	return false


## Progress of a character earned by playing: [current, target], or [] if n/a.
func species_progress(id: String) -> Array:
	var u: Dictionary = DB.SPECIES[id].unlock
	if u.type != "stat":
		return []
	return [mini(int(stat(u.stat)), int(u.target)), int(u.target)]


## Characters earned by playing unlock themselves when their goal is reached.
## Returns the ids unlocked by this check.
func check_stat_unlocks() -> Array:
	var out := []
	for sp in DB.SPECIES:
		var u: Dictionary = DB.SPECIES[sp].unlock
		if u.type == "stat" and not unlocked.has(sp) and stat(u.stat) >= float(u.target):
			unlocked.append(sp)
			out.append(sp)
	if not out.is_empty():
		save_game()
	return out


## Shop purchases (relics, modes, expansions...).
var owned: Array = []


func owns(id: String) -> bool:
	return owned.has(id)


func buy_item(id: String) -> bool:
	var d: Dictionary = Shop.ITEMS[id]
	if owns(id) or pearls < int(d.price):
		return false
	if d.has("needs") and not owns(d.needs):
		return false
	pearls -= int(d.price)
	owned.append(id)
	if d.cat == "tide" and str(settings.get("tide", "")) == "":
		settings["tide"] = id
	save_game()
	return true


# ---------------------------------------------------------------- bestiary
## Returns true the first time a species is seen.
func bestiary_see(id: String) -> bool:
	if not DB.CREATURES.has(id) or id == "golden":
		return false
	var e: Dictionary = bestiary.get(id, {})
	if e.get("seen", false):
		return false
	e["seen"] = true
	bestiary[id] = e
	var n := 0
	for k in bestiary:
		if bestiary[k].get("seen", false):
			n += 1
	set_max("species_seen", n)
	return true


func bestiary_kill(id: String) -> void:
	var e: Dictionary = bestiary.get(id, {"seen": true})
	e["kills"] = int(e.get("kills", 0)) + 1
	e["seen"] = true
	bestiary[id] = e


# ------------------------------------------------------------------- daily
const DAILY_REWARDS := [20, 30, 40, 60, 80, 100, 200]


## Returns the reward available today (0 if already claimed).
func daily_available() -> int:
	var today := Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()))
	if daily.last == today:
		return 0
	return DAILY_REWARDS[_next_streak() - 1]


func _next_streak() -> int:
	var yesterday := Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)
	var s := int(daily.streak) + 1 if daily.last == yesterday else 1
	return ((s - 1) % DAILY_REWARDS.size()) + 1


func claim_daily() -> int:
	var amount := daily_available()
	if amount <= 0:
		return 0
	daily.streak = _next_streak()
	daily.last = Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()))
	add_pearls(amount)
	save_game()
	return amount
