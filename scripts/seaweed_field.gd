extends Node2D
# Spawn da Alga
@export_range(0.0, 1.0, 0.01) var spawn_chance := 0.20
# -------------
@export var slot_spacing := 170.0
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

const SEAWEED_SCENE := preload("res://scenes/seaweed.tscn")
const SHRIMP_SCENE := preload("res://scenes/shrimp.tscn")
const FISH_INTERACTION_SIZE := Vector2(90.0, 62.0)
const SHRIMP_COLLISION_PASSES := 3


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
		weed.position.y = platform_top_y 
	_update_positions()


func _process(_delta: float) -> void:
	if platform != null:
		traveled_distance = platform.get_visual_scroll_offset()
	_generate_frontier()
	_update_positions()
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
	weed.position.y = platform_top_y + 8.0
	weed.position.x = platform.position.x + float(slot) * slot_spacing - traveled_distance
	_spawn_shrimps_for_weed(slot, weed)


func _spawn_shrimps_for_weed(slot: int, weed: Node2D) -> void:
	var shrimp_count := randi_range(0, max_shrimp_per_seaweed)
	var shrimp_list: Array[Node2D] = []
	for index in shrimp_count:
		var shrimp := SHRIMP_SCENE.instantiate() as Node2D
		shrimp.z_index = 1
		add_child(shrimp)
		var spread := 0.0 if shrimp_count <= 1 else lerpf(-28.0, 28.0, float(index) / float(shrimp_count - 1))
		var home_offset := Vector2(spread + randf_range(-8.0, 8.0), randf_range(-28.0, -12.0))
		if shrimp.has_method("setup"):
			shrimp.setup(weed, home_offset, platform_top_y)
		shrimp_list.append(shrimp)
	shrimps_by_slot[slot] = shrimp_list


func consume_near(player: Node2D, _delta: float) -> int:
	var gained_xp := 0
	var fish_rect := Rect2(player.global_position - FISH_INTERACTION_SIZE * 0.5, FISH_INTERACTION_SIZE)
	for weed in weeds_by_slot.values():
		if not is_instance_valid(weed):
			continue
		if weed.has_method("is_consumable") and not weed.is_consumable():
			continue
		if weed.has_method("get_interaction_rect") and fish_rect.intersects(weed.get_interaction_rect()):
			if player.has_method("can_bite") and player.has_method("bite") and player.can_bite():
				var bite_data: Dictionary = player.bite()
				gained_xp += weed.take_damage(bite_data["damage"], bite_data["is_critical"])
	return gained_xp


func push_shrimps_near(player: CharacterBody2D) -> void:
	for pass_index in SHRIMP_COLLISION_PASSES:
		for shrimp_list in shrimps_by_slot.values():
			for shrimp in shrimp_list:
				if not is_instance_valid(shrimp):
					continue
				if shrimp.has_method("handle_player_collision"):
					shrimp.handle_player_collision(player, player.velocity)
			_separate_shrimp_group(shrimp_list)
		for shrimp in orphan_shrimps:
			if not is_instance_valid(shrimp):
				continue
			if shrimp.has_method("handle_player_collision"):
				shrimp.handle_player_collision(player, player.velocity)
		_separate_shrimp_group(orphan_shrimps)


func _separate_shrimp_group(shrimp_list: Array) -> void:
	for first_index in shrimp_list.size():
		var first_shrimp: Node2D = shrimp_list[first_index]
		if not is_instance_valid(first_shrimp):
			continue
		for second_index in range(first_index + 1, shrimp_list.size()):
			var second_shrimp: Node2D = shrimp_list[second_index]
			if not is_instance_valid(second_shrimp):
				continue
			if first_shrimp.has_method("separate_from"):
				first_shrimp.separate_from(second_shrimp)
			if second_shrimp.has_method("separate_from"):
				second_shrimp.separate_from(first_shrimp)


func _update_positions() -> void:
	if platform == null:
		return
	for slot in weeds_by_slot:
		var weed: Node2D = weeds_by_slot[slot]
		if not is_instance_valid(weed):
			continue
		weed.position.x = platform.position.x + float(slot) * slot_spacing - traveled_distance


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
		if not shrimps_by_slot.has(new_slot):
			shrimps_by_slot[new_slot] = []
		shrimps_by_slot[new_slot].append(shrimp)
	orphan_shrimps = still_orphan


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
