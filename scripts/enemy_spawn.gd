extends Node2D

@export_range(0.0, 1.0, 0.01) var spawn_chance := 1.0
@export var spawn_interval := 7.5
@export var spawn_buffer := 140.0
@export var max_active_enemies := 12
@export_range(0.0, 1.0, 0.01) var normal_enemy_chance := 0.30
@export var blue_enemy_weight := 50.0
@export var orange_school_weight := 40.0
@export var red_enemy_weight := 15.0
@export var golden_enemy_weight := 5.0
@export var orange_school_size := 5

var viewport_size := Vector2(1280.0, 720.0)
var platform_top_y := 648.0
var player: Node2D
var platform
var seaweed_field
var spawn_timer := 0.0
var previous_traveled_distance := 0.0
var has_traveled_snapshot := false
var previous_platform_y := 0.0
var has_platform_y_snapshot := false
var enemies: Array[Node2D] = []

const ENEMY_SCENE := preload("res://scenes/enemy_fish1.tscn")
const NORMAL_VARIANT := {
	"id": "normal",
	"count": 1,
	"sprite_scale": 0.60,
	"health_multiplier": 1.0,
	"damage_multiplier": 1.0,
	"xp_multiplier": 1.0,
	"color": Color.WHITE,
	"is_golden": false
}
const BLUE_VARIANT := {
	"id": "blue",
	"count": 1,
	"sprite_scale": 0.80,
	"health_multiplier": 2.0,
	"damage_multiplier": 2.0,
	"xp_multiplier": 2.0,
	"color": Color("#28a7ff"),
	"is_golden": false
}
const ORANGE_VARIANT := {
	"id": "orange",
	"count": 5,
	"sprite_scale": 0.40,
	"health_multiplier": 0.5,
	"damage_multiplier": 0.5,
	"xp_multiplier": 1.0,
	"color": Color("#ff8a20"),
	"is_golden": false
}
const RED_VARIANT := {
	"id": "red",
	"count": 1,
	"sprite_scale": 2.0,
	"health_multiplier": 5.0,
	"damage_multiplier": 5.0,
	"xp_multiplier": 2.0,
	"attack_range_multiplier": 0.65,
	"color": Color("#e33125"),
	"is_golden": false
}
const GOLDEN_VARIANT := {
	"id": "golden",
	"count": 1,
	"sprite_scale": 0.60,
	"health_multiplier": 1.0,
	"damage_multiplier": 1.0,
	"xp_multiplier": 5.0,
	"color": Color("#ffb320"),
	"is_golden": true
}


func configure(new_viewport_size: Vector2, new_platform_top_y: float, active_player: Node2D, active_platform, active_seaweed_field = null) -> void:
	viewport_size = new_viewport_size
	platform_top_y = new_platform_top_y
	player = active_player
	platform = active_platform
	seaweed_field = active_seaweed_field
	if spawn_timer <= 0.0:
		spawn_timer = 1.0


func attack_near(attacker: Node2D) -> int:
	var gained_xp := 0
	if not attacker.has_method("can_attack") or not attacker.has_method("attack") or not attacker.can_attack():
		return gained_xp

	var bite_data: Dictionary = attacker.attack()
	return apply_attack(attacker, bite_data)


func apply_attack(attacker: Node2D, bite_data: Dictionary) -> int:
	var gained_xp := 0
	for enemy in enemies:
		if not _is_active_enemy(enemy):
			continue
		if not enemy.has_method("get_interaction_rect") or not enemy.has_method("take_damage"):
			continue
		if _player_attack_hits_rect(attacker, enemy.get_interaction_rect()):
			gained_xp += enemy.take_damage(bite_data["damage"], bite_data["is_critical"], attacker.global_position)
	_cleanup_enemies()
	return gained_xp


func _process(delta: float) -> void:
	var travel_delta := _get_travel_delta()
	var vertical_delta := _get_vertical_delta()
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("apply_world_scroll"):
			enemy.apply_world_scroll(travel_delta)
			enemy.position.y += vertical_delta
			if platform != null:
				enemy.set("ground_y", platform.position.y)
	_resolve_enemy_collisions()
	_resolve_accidental_enemy_hits()
	spawn_timer = maxf(spawn_timer - delta, 0.0)
	if spawn_timer <= 0.0:
		_try_spawn_enemy()
		spawn_timer = spawn_interval
	_cleanup_enemies()


func _get_travel_delta() -> float:
	if platform == null:
		return 0.0
	var new_traveled_distance: float = platform.get_visual_scroll_offset()
	if not has_traveled_snapshot:
		previous_traveled_distance = new_traveled_distance
		has_traveled_snapshot = true
		return 0.0
	var travel_delta := new_traveled_distance - previous_traveled_distance
	previous_traveled_distance = new_traveled_distance
	return travel_delta


func _get_vertical_delta() -> float:
	if platform == null:
		return 0.0
	if not has_platform_y_snapshot:
		previous_platform_y = platform.position.y
		has_platform_y_snapshot = true
		return 0.0
	var vertical_delta: float = platform.position.y - previous_platform_y
	previous_platform_y = platform.position.y
	return vertical_delta


func _try_spawn_enemy() -> void:
	if _count_active_enemies() >= max_active_enemies:
		return
	if randf() > spawn_chance:
		return

	var variant := _pick_enemy_variant()
	var spawn_count := int(variant.get("count", 1))
	if _count_active_enemies() + spawn_count > max_active_enemies and variant.get("id", "normal") != "orange":
		return
	if variant.get("id", "normal") == "orange":
		spawn_count = orange_school_size

	var active_platform_y: float = platform.position.y if platform != null else platform_top_y
	var spawn_y := randf_range(viewport_size.y * 0.34, minf(active_platform_y - 80.0, viewport_size.y * 0.82))
	for index in spawn_count:
		_spawn_enemy_instance(variant, spawn_y, index, spawn_count, active_platform_y)


func _spawn_enemy_instance(variant: Dictionary, spawn_y: float, index: int, spawn_count: int, active_platform_y: float) -> void:
	var enemy := ENEMY_SCENE.instantiate() as Node2D
	enemy.z_index = 4
	add_child(enemy)
	if enemy.has_method("apply_variant"):
		enemy.apply_variant(variant)
	var group_center := (float(spawn_count) - 1.0) * 0.5
	var group_offset := Vector2(
		float(index - group_center) * randf_range(22.0, 34.0),
		randf_range(-18.0, 18.0)
	)
	enemy.position = Vector2(viewport_size.x + spawn_buffer, spawn_y) + group_offset
	if enemy.has_method("setup"):
		enemy.setup(player, active_platform_y, seaweed_field)
	if enemy.has_signal("died"):
		enemy.connect("died", _on_enemy_died)
	enemies.append(enemy)


func _pick_enemy_variant() -> Dictionary:
	if randf() < normal_enemy_chance:
		return NORMAL_VARIANT

	var total_weight := maxf(blue_enemy_weight + orange_school_weight + red_enemy_weight + golden_enemy_weight, 0.01)
	var roll := randf() * total_weight
	if roll < golden_enemy_weight:
		return GOLDEN_VARIANT
	roll -= golden_enemy_weight
	if roll < red_enemy_weight:
		return RED_VARIANT
	roll -= red_enemy_weight
	if roll < orange_school_weight:
		return ORANGE_VARIANT
	return BLUE_VARIANT


func _player_attack_hits_rect(attacker: Node2D, target_rect: Rect2) -> bool:
	if attacker.has_method("attack_hits_rect"):
		return attacker.attack_hits_rect(target_rect)
	if attacker.has_method("get_attack_rect"):
		return attacker.get_attack_rect().intersects(target_rect)
	return Rect2(attacker.global_position - Vector2(90.0, 62.0) * 0.5, Vector2(90.0, 62.0)).intersects(target_rect)


func _cleanup_enemies() -> void:
	enemies = enemies.filter(func(enemy): return _is_active_or_dying_enemy(enemy))


func _resolve_enemy_collisions() -> void:
	for first_index in enemies.size():
		var first_enemy = enemies[first_index]
		if not _is_active_enemy(first_enemy):
			continue
		for second_index in range(first_index + 1, enemies.size()):
			var second_enemy = enemies[second_index]
			if not _is_active_enemy(second_enemy):
				continue
			if first_enemy.has_method("separate_from_enemy"):
				first_enemy.separate_from_enemy(second_enemy)
			if second_enemy.has_method("separate_from_enemy"):
				second_enemy.separate_from_enemy(first_enemy)


func _resolve_accidental_enemy_hits() -> void:
	for attacker in enemies:
		if not _is_active_enemy(attacker) or not attacker.has_method("try_accidental_enemy_hit"):
			continue
		for target in enemies:
			if target == attacker or not _is_active_enemy(target):
				continue
			attacker.try_accidental_enemy_hit(target)


func _count_active_enemies() -> int:
	var count := 0
	for enemy in enemies:
		if _is_active_enemy(enemy):
			count += 1
	return count


func _is_active_enemy(enemy) -> bool:
	if not is_instance_valid(enemy):
		return false
	if enemy.has_method("is_alive") and not enemy.is_alive():
		return false
	return true


func _is_active_or_dying_enemy(enemy) -> bool:
	return is_instance_valid(enemy) and not enemy.is_queued_for_deletion()


func _on_enemy_died(enemy: Node2D) -> void:
	if seaweed_field == null or not seaweed_field.has_method("spawn_meat_drops"):
		return
	if not is_instance_valid(enemy):
		return
	var carried_xp := 0.0
	if enemy.has_method("get_meat_drop_xp"):
		carried_xp = enemy.get_meat_drop_xp()
	var is_golden_drop: bool = enemy.has_method("is_golden_variant") and enemy.is_golden_variant()
	var drop_scale_multiplier := 1.0
	if enemy.has_method("get_meat_drop_scale"):
		drop_scale_multiplier = enemy.get_meat_drop_scale()
	seaweed_field.spawn_meat_drops(enemy.position, is_golden_drop, carried_xp, drop_scale_multiplier)
