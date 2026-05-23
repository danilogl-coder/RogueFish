extends Node2D
# Spawn da Alga
@export_range(0.0, 1.0, 0.01) var spawn_chance := 0.05
# -------------
@export var slot_spacing := 170.0
@export var spawn_buffer := 220.0

var viewport_size := Vector2(1280.0, 720.0)
var platform_top_y := 0.0
var traveled_distance := 0.0
var camera: Camera2D
var platform
var has_seeded_start := false
var checked_slots: Dictionary = {}
var weeds_by_slot: Dictionary = {}

const SEAWEED_SCENE := preload("res://scenes/seaweed.tscn")


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
	weed.position.y = platform_top_y + 8.0


func _update_positions() -> void:
	if platform == null:
		return
	for slot in weeds_by_slot:
		var weed: Node2D = weeds_by_slot[slot]
		weed.position.x = platform.position.x + float(slot) * slot_spacing - traveled_distance


func _visible_half_width() -> float:
	if camera == null:
		return viewport_size.x * 0.5
	return viewport_size.x / camera.zoom.x * 0.5


func _route_center() -> float:
	if camera == null or platform == null:
		return traveled_distance
	return camera.global_position.x - platform.position.x + traveled_distance
