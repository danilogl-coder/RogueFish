extends Node2D
# Spawn da Alga
@export_range(0.0, 1.0, 0.01) var spawn_chance := 0.10
# -------------
@export var slot_spacing := 100.0
@export var spawn_buffer := 220.0
@export_range(0, 3, 1) var max_shrimp_per_seaweed := 3

var viewport_size := Vector2(1280.0, 720.0)
var platform_top_y := 0.0
var traveled_distance := 0.0
var camera: Camera2D
var platform
var has_seeded_start := false
var checked_slots: Dictionary = {}
var weeds_by_slot: Dictionary = {}
var shrimps_by_slot: Dictionary = {}
var orphan_shrimps: Array[Node2D] = []
var meats: Array[Node2D] = []
var previous_traveled_distance := 0.0
var has_traveled_snapshot := false
var previous_platform_y := 0.0
var has_platform_y_snapshot := false

const SEAWEED_SCENE := preload("res://scenes/seaweed.tscn")
const SHRIMP_SCENE := preload("res://scenes/shrimp.tscn")
const MEAT_SCENE := preload("res://scenes/meat.tscn")
const FISH_INTERACTION_SIZE := Vector2(90.0, 62.0)
const SHRIMP_COLLISION_PASSES := 3
const MEAT_DROP_COUNT := 3
const MEAT_DROP_MIN_DISTANCE := 10.0
const MEAT_DROP_MAX_DISTANCE := 26.0


func configure(new_viewport_size: Vector2, new_platform_top_y: float, active_camera: Camera2D, active_platform) -> void:
	viewport_size = new_viewport_size
	platform_top_y = new_platform_top_y
	camera = active_camera
	platform = active_platform
	if not has_seeded_start:
		_mark_starting_view_as_empty()
		_generate_frontier()
		has_seeded_start = true
	for weed in weeds_by_slot.values():
		weed.position.y = platform.position.y + 8.0 if platform != null else platform_top_y
	_update_shrimp_sound_listeners()
	_update_positions()


func _process(_delta: float) -> void:
	var travel_delta := 0.0
	var vertical_delta := 0.0
	if platform != null:
		var new_traveled_distance: float = platform.get_visual_scroll_offset()
		if not has_traveled_snapshot:
			previous_traveled_distance = new_traveled_distance
			has_traveled_snapshot = true
		travel_delta = new_traveled_distance - previous_traveled_distance
		previous_traveled_distance = new_traveled_distance
		traveled_distance = platform.get_visual_scroll_offset()
		if not has_platform_y_snapshot:
			previous_platform_y = platform.position.y
			has_platform_y_snapshot = true
		vertical_delta = platform.position.y - previous_platform_y
		previous_platform_y = platform.position.y
		_update_entity_ground_y(platform.position.y)
	_generate_frontier()
	_update_positions()
	_update_meat_positions(travel_delta, vertical_delta)
	_assign_orphan_shrimps()


func _mark_starting_view_as_empty() -> void:
	var half_width := _visible_half_width()
	var route_center := _route_center()
	var first_slot := floori((route_center - half_width) / slot_spacing)
	var last_slot := ceili((route_center + half_width) / slot_spacing)
	for slot in range(first_slot, last_slot + 1):
		checked_slots[slot] = true


func _generate_frontier() -> void:
	var half_width := _visible_half_width()
	var route_center := _route_center()
	var first_slot := floori((route_center - half_width - spawn_buffer) / slot_spacing)
	var last_slot := ceili((route_center + half_width + spawn_buffer) / slot_spacing)
	for slot in range(first_slot, last_slot + 1):
		_check_slot(slot)


func _check_slot(slot: int) -> void:
	if checked_slots.has(slot):
		return
	checked_slots[slot] = true
	if randf() > spawn_chance:
		return

	var weed := SEAWEED_SCENE.instantiate() as Node2D
	add_child(weed)
	weeds_by_slot[slot] = weed
	if weed.has_signal("depleted"):
		weed.connect("depleted", _on_weed_depleted.bind(slot))
	weed.position.y = platform.position.y + 8.0 if platform != null else platform_top_y + 8.0
	weed.position.x = platform.position.x + float(slot) * slot_spacing - traveled_distance
	_spawn_shrimps_for_weed(slot, weed)


func _spawn_shrimps_for_weed(slot: int, weed: Node2D) -> void:
	var shrimp_count := randi_range(0, max_shrimp_per_seaweed)
	var shrimp_list: Array[Node2D] = []
	for index in shrimp_count:
		var shrimp := SHRIMP_SCENE.instantiate() as Node2D
		shrimp.z_index = 1
		add_child(shrimp)
		if shrimp.has_signal("died"):
			shrimp.connect("died", _on_shrimp_died)
		var spread := 0.0 if shrimp_count <= 1 else lerpf(-28.0, 28.0, float(index) / float(shrimp_count - 1))
		var home_offset := Vector2(spread + randf_range(-8.0, 8.0), randf_range(-28.0, -12.0))
		if shrimp.has_method("setup"):
			shrimp.setup(weed, home_offset, platform_top_y)
		if shrimp.has_method("set_sound_listener"):
			shrimp.set_sound_listener(camera)
		shrimp_list.append(shrimp)
	shrimps_by_slot[slot] = shrimp_list


func attack_near(player: Node2D) -> int:
	var gained_xp := consume_meats_near(player)
	if not player.has_method("can_attack") or not player.has_method("attack") or not player.can_attack():
		return gained_xp

	var bite_data: Dictionary = player.attack()
	gained_xp += apply_attack(player, bite_data)
	return gained_xp


func apply_attack(player: Node2D, bite_data: Dictionary) -> int:
	var gained_xp := 0
	for weed in weeds_by_slot.values():
		if not is_instance_valid(weed):
			continue
		if weed.has_method("is_consumable") and not weed.is_consumable():
			continue
		if weed.has_method("get_interaction_rect") and _player_attack_hits_rect(player, weed.get_interaction_rect()):
			gained_xp += weed.take_damage(bite_data["damage"], bite_data["is_critical"])
	for shrimp_list in shrimps_by_slot.values():
		gained_xp += _attack_shrimp_group(player, shrimp_list, bite_data)
	gained_xp += _attack_shrimp_group(player, orphan_shrimps, bite_data)
	_cleanup_shrimp_lists()
	return gained_xp


func consume_meats_near(player: Node2D) -> int:
	var gained_xp := 0
	if not player.has_method("can_bite") or not player.has_method("bite") or not player.can_bite():
		return gained_xp

	var fish_rect := Rect2(player.global_position - FISH_INTERACTION_SIZE * 0.5, FISH_INTERACTION_SIZE)
	for meat in meats:
		if not is_instance_valid(meat):
			continue
		if meat.has_method("is_consumable") and not meat.is_consumable():
			continue
		if not meat.has_method("get_interaction_rect") or not meat.has_method("take_damage"):
			continue
		if fish_rect.intersects(meat.get_interaction_rect()):
			var bite_data: Dictionary = player.bite()
			gained_xp += meat.take_damage(bite_data["damage"], bite_data["is_critical"])
			break
	_cleanup_meats()
	return gained_xp


func get_active_shrimps() -> Array[Node2D]:
	_cleanup_shrimp_lists()
	var active_shrimps: Array[Node2D] = []
	for shrimp_list in shrimps_by_slot.values():
		for shrimp in shrimp_list:
			if _is_active_shrimp(shrimp):
				active_shrimps.append(shrimp)
	for shrimp in orphan_shrimps:
		if _is_active_shrimp(shrimp):
			active_shrimps.append(shrimp)
	return active_shrimps


func get_consumable_meats() -> Array[Node2D]:
	_cleanup_meats()
	var consumable_meats: Array[Node2D] = []
	for meat in meats:
		if not is_instance_valid(meat):
			continue
		if meat.has_method("is_consumable") and not meat.is_consumable():
			continue
		consumable_meats.append(meat)
	return consumable_meats


func _attack_shrimp_group(player: Node2D, shrimp_list: Array, bite_data: Dictionary) -> int:
	var gained_xp := 0
	for shrimp in shrimp_list:
		if not is_instance_valid(shrimp):
			continue
		if shrimp.has_method("is_alive") and not shrimp.is_alive():
			continue
		if not shrimp.has_method("get_interaction_rect") or not shrimp.has_method("take_damage"):
			continue
		if _player_attack_hits_rect(player, shrimp.get_interaction_rect()):
			gained_xp += shrimp.take_damage(bite_data["damage"], bite_data["is_critical"], player.global_position)
	return gained_xp


func _player_attack_hits_rect(player: Node2D, target_rect: Rect2) -> bool:
	if player.has_method("attack_hits_rect"):
		return player.attack_hits_rect(target_rect)
	if player.has_method("get_attack_rect"):
		return player.get_attack_rect().intersects(target_rect)
	return Rect2(player.global_position - FISH_INTERACTION_SIZE * 0.5, FISH_INTERACTION_SIZE).intersects(target_rect)


func push_shrimps_near(player: CharacterBody2D) -> void:
	_cleanup_shrimp_lists()
	for pass_index in SHRIMP_COLLISION_PASSES:
		for shrimp_list in shrimps_by_slot.values():
			for shrimp in shrimp_list:
				if not _is_active_shrimp(shrimp):
					continue
				if shrimp.has_method("handle_player_collision"):
					shrimp.handle_player_collision(player, player.velocity)
			_separate_shrimp_group(shrimp_list)
		for shrimp in orphan_shrimps:
			if not _is_active_shrimp(shrimp):
				continue
			if shrimp.has_method("handle_player_collision"):
				shrimp.handle_player_collision(player, player.velocity)
		_separate_shrimp_group(orphan_shrimps)


func _separate_shrimp_group(shrimp_list: Array) -> void:
	for first_index in shrimp_list.size():
		var first_shrimp = shrimp_list[first_index]
		if not _is_active_shrimp(first_shrimp):
			continue
		for second_index in range(first_index + 1, shrimp_list.size()):
			var second_shrimp = shrimp_list[second_index]
			if not _is_active_shrimp(second_shrimp):
				continue
			if first_shrimp.has_method("separate_from"):
				first_shrimp.separate_from(second_shrimp)
			if second_shrimp.has_method("separate_from"):
				second_shrimp.separate_from(first_shrimp)


func _cleanup_shrimp_lists() -> void:
	for slot in shrimps_by_slot.keys():
		shrimps_by_slot[slot] = _get_active_shrimps(shrimps_by_slot[slot])
	orphan_shrimps = _get_active_shrimps(orphan_shrimps)
	_cleanup_meats()


func _get_active_shrimps(shrimp_list: Array) -> Array[Node2D]:
	var active_shrimps: Array[Node2D] = []
	for shrimp in shrimp_list:
		if _is_active_shrimp(shrimp):
			active_shrimps.append(shrimp)
	return active_shrimps


func _is_active_shrimp(shrimp) -> bool:
	if not is_instance_valid(shrimp):
		return false
	if shrimp.has_method("is_alive") and not shrimp.is_alive():
		return false
	return true


func _update_positions() -> void:
	if platform == null:
		return
	for slot in weeds_by_slot:
		var weed: Node2D = weeds_by_slot[slot]
		if not is_instance_valid(weed):
			continue
		weed.position.x = platform.position.x + float(slot) * slot_spacing - traveled_distance
		weed.position.y = platform.position.y + 8.0


func _update_meat_positions(travel_delta: float, vertical_delta := 0.0) -> void:
	if is_zero_approx(travel_delta) and is_zero_approx(vertical_delta):
		return
	for meat in meats:
		if is_instance_valid(meat):
			meat.position.x -= travel_delta
			meat.position.y += vertical_delta


func _update_entity_ground_y(active_ground_y: float) -> void:
	for shrimp_list in shrimps_by_slot.values():
		for shrimp in shrimp_list:
			if is_instance_valid(shrimp):
				shrimp.set("ground_y", active_ground_y)
	for shrimp in orphan_shrimps:
		if is_instance_valid(shrimp):
			shrimp.set("ground_y", active_ground_y)
	for meat in meats:
		if is_instance_valid(meat):
			meat.set("ground_y", active_ground_y)


func _cleanup_meats() -> void:
	meats = meats.filter(func(meat): return is_instance_valid(meat))


func _on_shrimp_died(shrimp: Node2D) -> void:
	if not is_instance_valid(shrimp):
		return
	var should_drop_golden_meat := bool(shrimp.get("is_golden"))
	var carried_xp := float(shrimp.get("stored_algae_xp"))
	_spawn_meat_drops(shrimp.position, should_drop_golden_meat, carried_xp)


func spawn_meat_drops(drop_position: Vector2, is_golden_drop := false, carried_xp := 0.0, drop_scale_multiplier := 1.0) -> void:
	_spawn_meat_drops(drop_position, is_golden_drop, carried_xp, drop_scale_multiplier)


func _spawn_meat_drops(drop_position: Vector2, is_golden_drop := false, carried_xp := 0.0, drop_scale_multiplier := 1.0) -> void:
	var base_angle := randf() * TAU
	var carried_xp_per_meat := carried_xp / float(MEAT_DROP_COUNT)
	for index in MEAT_DROP_COUNT:
		var meat := MEAT_SCENE.instantiate() as Node2D
		meat.z_index = 2
		add_child(meat)
		var angle_step := TAU / float(MEAT_DROP_COUNT)
		var direction := Vector2.RIGHT.rotated(base_angle + angle_step * float(index) + randf_range(-0.55, 0.55))
		var offset := direction * randf_range(MEAT_DROP_MIN_DISTANCE, MEAT_DROP_MAX_DISTANCE)
		offset.x += randf_range(-6.0, 6.0)
		offset.y = offset.y * 0.65 + randf_range(-8.0, 8.0)
		var angle := randf_range(-0.9, 0.9) + float(index) * 0.35
		if meat.has_method("setup"):
			var active_ground_y: float = platform.position.y if platform != null else platform_top_y
			meat.setup(drop_position + offset, active_ground_y, angle, is_golden_drop, carried_xp_per_meat, drop_scale_multiplier)
		if meat.has_signal("depleted"):
			meat.connect("depleted", _on_meat_depleted)
		meats.append(meat)


func _on_meat_depleted(meat: Node2D) -> void:
	meats.erase(meat)


func _on_weed_depleted(weed: Node2D, slot: int) -> void:
	if weeds_by_slot.get(slot) == weed:
		weeds_by_slot.erase(slot)
	if shrimps_by_slot.has(slot):
		var shrimp_list: Array = shrimps_by_slot[slot]
		shrimps_by_slot.erase(slot)
		for shrimp in shrimp_list:
			if is_instance_valid(shrimp):
				_assign_shrimp_to_new_weed(shrimp)


func _assign_shrimp_to_new_weed(shrimp: Node2D) -> void:
	var new_weed := _find_nearest_consumable_weed(shrimp.global_position)
	if new_weed == null:
		_store_orphan_shrimp(shrimp)
		return
	var new_slot: Variant = _find_slot_for_weed(new_weed)
	if new_slot == null:
		_store_orphan_shrimp(shrimp)
		return
	if shrimp.has_method("set_target_weed"):
		shrimp.set_target_weed(new_weed)
	if shrimp.has_method("set_sound_listener"):
		shrimp.set_sound_listener(camera)
	if not shrimps_by_slot.has(new_slot):
		shrimps_by_slot[new_slot] = []
	shrimps_by_slot[new_slot].append(shrimp)


func _store_orphan_shrimp(shrimp: Node2D) -> void:
	if not is_instance_valid(shrimp):
		return
	if not orphan_shrimps.has(shrimp):
		orphan_shrimps.append(shrimp)


func _assign_orphan_shrimps() -> void:
	if orphan_shrimps.is_empty():
		return
	var still_orphan: Array[Node2D] = []
	for shrimp in orphan_shrimps:
		if not is_instance_valid(shrimp):
			continue
		var new_weed := _find_nearest_consumable_weed(shrimp.global_position)
		var new_slot: Variant = _find_slot_for_weed(new_weed) if new_weed != null else null
		if new_weed == null or new_slot == null:
			still_orphan.append(shrimp)
			continue
		if shrimp.has_method("set_target_weed"):
			shrimp.set_target_weed(new_weed)
		if shrimp.has_method("set_sound_listener"):
			shrimp.set_sound_listener(camera)
		if not shrimps_by_slot.has(new_slot):
			shrimps_by_slot[new_slot] = []
		shrimps_by_slot[new_slot].append(shrimp)
	orphan_shrimps = still_orphan


func _update_shrimp_sound_listeners() -> void:
	for shrimp_list in shrimps_by_slot.values():
		for shrimp in shrimp_list:
			if is_instance_valid(shrimp) and shrimp.has_method("set_sound_listener"):
				shrimp.set_sound_listener(camera)
	for shrimp in orphan_shrimps:
		if is_instance_valid(shrimp) and shrimp.has_method("set_sound_listener"):
			shrimp.set_sound_listener(camera)


func _find_nearest_consumable_weed(origin: Vector2) -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := INF
	for weed in weeds_by_slot.values():
		if not is_instance_valid(weed):
			continue
		if weed.has_method("is_consumable") and not weed.is_consumable():
			continue
		var distance := origin.distance_squared_to(weed.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = weed
	return nearest


func _find_slot_for_weed(target: Node2D):
	for slot in weeds_by_slot:
		if weeds_by_slot[slot] == target:
			return slot
	return null


func _visible_half_width() -> float:
	if camera == null:
		return viewport_size.x * 0.5
	return viewport_size.x / camera.zoom.x * 0.5


func _route_center() -> float:
	if camera == null or platform == null:
		return traveled_distance
	return camera.global_position.x - platform.position.x + traveled_distance
