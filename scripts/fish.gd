extends CharacterBody2D

@export var maximum_speed := 265.0
@export var world_scroll_factor := 0.8
@export var sprite_scale := 2
@export var bite_damage := 1
@export var bite_rate := 0.12
@export_range(0.0, 1.0, 0.01) var critical_chance := 0.10
@export var critical_multiplier := 2.0
@export var resistance := 0
@export var social_affinity := 0
@export_range(0.0, 1.0, 0.01) var swim_sound_volume := 1.12
@export var swim_sound_pitch := 1.0
@export_range(0.0, 1.0, 0.01) var eating_sound_volume := 0.65
@export var eating_sound_pitch := 0.10

var control_vector := Vector2.ZERO
var swim_area := Rect2(80.0, 80.0, 880.0, 470.0)
var animation_time := 0.0
var tail_texture: Texture2D
var facing_direction := -1.0
var blink_time := 0.0
var next_blink_time := 2.6
var bite_cooldown := 0.0
var eating_visual_time := 0.0
var predator_affinity := 0
var prey_affinity := 0
var rogue_affinity := 0
var coactive_affinity := 0
var swim_sound_player: AudioStreamPlayer
var eating_sound_player: AudioStreamPlayer
var swim_sound_amount := 0.0

const BLINK_FRAME_TIME := 0.075
const BLINK_SEQUENCE := [0, 1, 2, 1, 0]
const EAT_FRAME_TIME := 0.12
const EAT_FRAME_SEQUENCE := [0, 1, 2, 1]
const EATING_VISUAL_HOLD := 0.18
const MAX_STATUS_RANK := 5
const SWIM_SOUND_STREAM := preload("res://assets/audio/swim.wav")
const EATING_SOUND_STREAM := preload("res://assets/audio/fish_eating.mp3")
const BODY_FRAMES: Array[Texture2D] = [
	preload("res://assets/fish_blink_1.png"),
	preload("res://assets/fish_blink_2.png"),
	preload("res://assets/fish_blink_3.png")
]
const EAT_FRAMES: Array[Texture2D] = [
	preload("res://assets/fish_eat_1.png"),
	preload("res://assets/fish_eat_2.png"),
	preload("res://assets/fish_eat_3.png")
]


func _ready() -> void:
	if ResourceLoader.exists("res://assets/fish_tail.png"):
		tail_texture = load("res://assets/fish_tail.png") as Texture2D
	_setup_swim_sound()
	_setup_eating_sound()


func _exit_tree() -> void:
	if swim_sound_player != null:
		swim_sound_player.stop()
		swim_sound_player.stream = null
	if eating_sound_player != null:
		eating_sound_player.stop()
		eating_sound_player.stream = null


func set_swim_area(area: Rect2) -> void:
	swim_area = area


func get_world_scroll_speed() -> float:
	return velocity.x * world_scroll_factor


func can_bite() -> bool:
	return bite_cooldown <= 0.0


func bite() -> Dictionary:
	bite_cooldown = bite_rate
	start_eating_animation()
	_play_eating_sound()
	var is_critical := randf() <= critical_chance
	var final_damage := float(bite_damage)
	if is_critical:
		final_damage *= critical_multiplier
	return {
		"damage": final_damage,
		"is_critical": is_critical
	}


func start_eating_animation() -> void:
	eating_visual_time = EATING_VISUAL_HOLD


func get_status_ranks() -> Dictionary:
	return {
		"predator": predator_affinity,
		"prey": prey_affinity,
		"rogue": rogue_affinity,
		"coactive": coactive_affinity,
		"social": social_affinity
	}


func get_status_rank(status_id: String) -> int:
	return int(get_status_ranks().get(status_id, 0))


func can_upgrade_status(status_id: String) -> bool:
	return get_status_rank(status_id) < MAX_STATUS_RANK


func can_upgrade_any_status() -> bool:
	for rank in get_status_ranks().values():
		if int(rank) < MAX_STATUS_RANK:
			return true
	return false


func apply_status_choice(status_id: String) -> bool:
	if not can_upgrade_status(status_id):
		return false

	match status_id:
		"predator":
			predator_affinity += 1
			bite_damage += 1
		"prey":
			prey_affinity += 1
			maximum_speed += 15.0
		"rogue":
			rogue_affinity += 1
			critical_chance = minf(critical_chance + 0.03, 0.75)
			critical_multiplier += 0.10
		"coactive":
			coactive_affinity += 1
			resistance += 1
		"social":
			social_affinity += 1
		_:
			return false
	return true


func _physics_process(delta: float) -> void:
	animation_time += delta
	blink_time += delta
	bite_cooldown = maxf(bite_cooldown - delta, 0.0)
	var was_eating := eating_visual_time > 0.0
	eating_visual_time = maxf(eating_visual_time - delta, 0.0)
	if was_eating and eating_visual_time <= 0.0:
		_stop_eating_sound()
	if blink_time > next_blink_time + BLINK_FRAME_TIME * BLINK_SEQUENCE.size():
		blink_time = 0.0
		next_blink_time = randf_range(2.2, 4.5)
	var target_velocity := control_vector * maximum_speed
	velocity = velocity.lerp(target_velocity, 1.0 - exp(-9.0 * delta))
	if absf(control_vector.x) > 0.05:
		facing_direction = -signf(control_vector.x)
	move_and_slide()
	position.x = clamp(position.x, swim_area.position.x, swim_area.end.x)
	position.y = clamp(position.y, swim_area.position.y, swim_area.end.y)
	var target_rotation := velocity.y / maximum_speed * 0.14 * -facing_direction
	rotation = lerp_angle(rotation, target_rotation, 1.0 - exp(-7.0 * delta))
	_update_swim_sound(delta)
	queue_redraw()


func _draw() -> void:
	var float_offset := Vector2(0.0, sin(animation_time * 4.5) * 3.5)
	if tail_texture != null:
		_draw_textured_fish(float_offset)
		return

	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-facing_direction, 1.0))
	var tail_swing := sin(animation_time * 9.0) * 8.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-45.0, 0.0) + float_offset,
		Vector2(-81.0, -27.0 + tail_swing) + float_offset,
		Vector2(-73.0, 2.0) + float_offset,
		Vector2(-81.0, 29.0 - tail_swing) + float_offset
	]), Color("#f39a43"))
	draw_ellipse(Vector2(-6.0, 0.0) + float_offset, Vector2(54.0, 31.0), Color("#ffbd52"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3.0, -19.0) + float_offset,
		Vector2(17.0, -44.0) + float_offset,
		Vector2(29.0, -18.0) + float_offset
	]), Color("#f3983e"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6.0, 19.0) + float_offset,
		Vector2(17.0, 41.0) + float_offset,
		Vector2(23.0, 17.0) + float_offset
	]), Color("#f3983e"))
	draw_circle(Vector2(28.0, -9.0) + float_offset, 6.5, Color.WHITE)
	draw_circle(Vector2(30.0, -9.0) + float_offset, 3.2, Color("#082e46"))
	draw_arc(Vector2(37.0, 6.0) + float_offset, 9.0, 0.3, 1.4, 10, Color("#c85e35"), 2.0, true)


func _draw_textured_fish(float_offset: Vector2) -> void:
	var tail_angle := sin(animation_time * 9.0) * 0.22
	var direction_scale := Vector2(facing_direction * sprite_scale, sprite_scale)
	var tail_pivot := Vector2(17.0 * facing_direction, 0.0) + float_offset
	var body_texture := _get_body_frame()

	draw_set_transform(tail_pivot, tail_angle * facing_direction, direction_scale)
	draw_texture(tail_texture, Vector2(-11.0, -24.0))

	draw_set_transform(float_offset, 0.0, direction_scale)
	draw_texture(body_texture, Vector2(-31.0, -31.0))


func _get_body_frame() -> Texture2D:
	if eating_visual_time > 0.0:
		var eat_index := int(animation_time / EAT_FRAME_TIME) % EAT_FRAME_SEQUENCE.size()
		return EAT_FRAMES[EAT_FRAME_SEQUENCE[eat_index]]
	return BODY_FRAMES[_get_blink_frame()]


func _get_blink_frame() -> int:
	if blink_time < next_blink_time:
		return 0

	var sequence_index := int((blink_time - next_blink_time) / BLINK_FRAME_TIME)
	if sequence_index >= BLINK_SEQUENCE.size():
		return 0
	return BLINK_SEQUENCE[sequence_index]


func _setup_swim_sound() -> void:
	swim_sound_player = AudioStreamPlayer.new()
	swim_sound_player.name = "SwimSound"
	swim_sound_player.stream = SWIM_SOUND_STREAM
	swim_sound_player.volume_db = linear_to_db(0.001)
	swim_sound_player.pitch_scale = swim_sound_pitch
	add_child(swim_sound_player)


func _setup_eating_sound() -> void:
	eating_sound_player = AudioStreamPlayer.new()
	eating_sound_player.name = "EatingSound"
	eating_sound_player.stream = EATING_SOUND_STREAM
	eating_sound_player.bus = "Master"
	eating_sound_player.volume_db = linear_to_db(clampf(eating_sound_volume, 0.0, 1.0))
	eating_sound_player.pitch_scale = eating_sound_pitch
	add_child(eating_sound_player)


func _play_eating_sound() -> void:
	if eating_sound_player == null:
		return
	eating_sound_player.stop()
	eating_sound_player.volume_db = linear_to_db(clampf(eating_sound_volume, 0.0, 1.0))
	eating_sound_player.pitch_scale = eating_sound_pitch
	eating_sound_player.play()


func _stop_eating_sound() -> void:
	if eating_sound_player != null and eating_sound_player.playing:
		eating_sound_player.stop()


func _update_swim_sound(delta: float) -> void:
	if swim_sound_player == null:
		return

	var target_amount := clampf(control_vector.length(), 0.0, 1.0)
	swim_sound_amount = lerpf(swim_sound_amount, target_amount, 1.0 - exp(-9.0 * delta))
	swim_sound_player.pitch_scale = swim_sound_pitch

	if swim_sound_amount > 0.03:
		if not swim_sound_player.playing:
			swim_sound_player.play()
		swim_sound_player.volume_db = linear_to_db(maxf(swim_sound_amount * swim_sound_volume, 0.001))
	elif swim_sound_player.playing:
		swim_sound_player.stop()


func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 28:
		var angle := TAU * float(index) / 28.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
