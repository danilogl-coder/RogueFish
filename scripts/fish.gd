extends CharacterBody2D

signal health_changed(current_health, maximum_health)
signal died

@export var maximum_speed := 265.0
@export var world_scroll_factor := 0.8
@export var sprite_scale := 0.60
@export var max_health := 10.0
@export var hit_invulnerability_time := 0.55
@export var bite_damage := 1
@export var bite_rate := 0.12
@export var attack_range := 30.0
@export var attack_height := 60.0
@export var attack_offset := 52.0
@export var attack_flash_time := 0.12
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
var attack_visual_time := 0.0
var predator_affinity := 0
var prey_affinity := 0
var rogue_affinity := 0
var coactive_affinity := 0
var swim_sound_player: AudioStreamPlayer
var eating_sound_player: AudioStreamPlayer
var swim_sound_amount := 0.0
var health := max_health
var invulnerability_timer := 0.0
var hit_flash_time := 0.0
var is_dead := false
var floating_damage_numbers: Array[Dictionary] = []

const BLINK_FRAME_TIME := 0.075
const BLINK_SEQUENCE := [0, 1, 2, 1, 0]
const EAT_FRAME_TIME := 0.12
const EAT_FRAME_SEQUENCE := [0, 1, 2, 1]
const EATING_VISUAL_HOLD := 0.18
const MAX_STATUS_RANK := 5
const PLAYER_HEALTH_BAR_SIZE := Vector2(54.0, 6.0)
const HIT_FLASH_HOLD := 0.16
const DAMAGE_NUMBER_TIME := 0.65
const TAIL_ATTACH_RATIO := Vector2(0.15, 0.0)
const TAIL_TEXTURE_ORIGIN_RATIO := Vector2(-0.30, -0.50)
const SWIM_SOUND_STREAM := preload("res://assets/audio/swim.wav")
const EATING_SOUND_STREAM := preload("res://assets/audio/fish_eating.mp3")
const DAMAGE_FONT: Font = preload("res://assets/fonts/PressStart2P-Regular.ttf")
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
	health = max_health
	if ResourceLoader.exists("res://assets/fish_tail.png"):
		tail_texture = load("res://assets/fish_tail.png") as Texture2D
	_setup_swim_sound()
	health_changed.emit(health, max_health)


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


func get_vertical_world_scroll_speed() -> float:
	return velocity.y * world_scroll_factor


func can_bite() -> bool:
	return bite_cooldown <= 0.0


func can_attack() -> bool:
	return not is_dead and can_bite()


func is_alive() -> bool:
	return not is_dead and health > 0.0


func get_hurt_rect() -> Rect2:
	var hurt_size := Vector2(58.0, 48.0) * float(sprite_scale) * 0.55
	return Rect2(global_position - hurt_size * 0.5, hurt_size)


func take_damage(amount: float, _hit_origin := Vector2.ZERO) -> void:
	if is_dead or invulnerability_timer > 0.0:
		return

	var final_damage := maxf(amount - float(resistance) * 0.25, 0.25)
	health = maxf(health - final_damage, 0.0)
	invulnerability_timer = hit_invulnerability_time
	hit_flash_time = HIT_FLASH_HOLD
	_spawn_damage_number(final_damage)
	health_changed.emit(health, max_health)

	if health <= 0.0:
		is_dead = true
		control_vector = Vector2.ZERO
		velocity = Vector2.ZERO
		_stop_eating_sound()
		if swim_sound_player != null and swim_sound_player.playing:
			swim_sound_player.stop()
		died.emit()
	queue_redraw()


func bite() -> Dictionary:
	bite_cooldown = bite_rate
	start_eating_animation()
	var is_critical := randf() <= critical_chance
	var final_damage := float(bite_damage)
	if is_critical:
		final_damage *= critical_multiplier
	return {
		"damage": final_damage,
		"is_critical": is_critical
	}


func attack() -> Dictionary:
	attack_visual_time = attack_flash_time
	return bite()


func get_attack_rect() -> Rect2:
	var direction := get_attack_direction()
	var center := global_position + direction * attack_offset
	return Rect2(center - Vector2(attack_range, attack_height) * 0.5, Vector2(attack_range, attack_height))


func get_attack_direction() -> Vector2:
	return Vector2(-facing_direction, 0.0)


func attack_hits_rect(target_rect: Rect2) -> bool:
	var cone_points := get_attack_cone_points()
	for point in _get_rect_points(target_rect):
		if _is_point_in_triangle(point, cone_points[0], cone_points[1], cone_points[2]):
			return true
	for point in cone_points:
		if target_rect.has_point(point):
			return true
	return _triangle_intersects_rect(cone_points, target_rect)


func get_attack_cone_points() -> PackedVector2Array:
	var direction := get_attack_direction()
	var side := Vector2(-direction.y, direction.x)
	var origin := global_position + direction * maxf(attack_offset - attack_range * 0.45, 8.0)
	var tip := global_position + direction * (attack_offset + attack_range * 0.55)
	var half_height := attack_height * 0.5
	return PackedVector2Array([
		origin,
		tip + side * half_height,
		tip - side * half_height
	])


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
	invulnerability_timer = maxf(invulnerability_timer - delta, 0.0)
	hit_flash_time = maxf(hit_flash_time - delta, 0.0)
	_update_floating_damage_numbers(delta)
	var was_eating := eating_visual_time > 0.0
	eating_visual_time = maxf(eating_visual_time - delta, 0.0)
	attack_visual_time = maxf(attack_visual_time - delta, 0.0)
	if was_eating and eating_visual_time <= 0.0:
		_stop_eating_sound()
	if blink_time > next_blink_time + BLINK_FRAME_TIME * BLINK_SEQUENCE.size():
		blink_time = 0.0
		next_blink_time = randf_range(2.2, 4.5)
	if is_dead:
		control_vector = Vector2.ZERO
		velocity = velocity.lerp(Vector2.ZERO, 1.0 - exp(-9.0 * delta))
		_update_swim_sound(delta)
		queue_redraw()
		return
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
	if attack_visual_time > 0.0:
		_draw_attack_flash(float_offset)
	if tail_texture != null:
		_draw_textured_fish(float_offset)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_player_health_bar()
		_draw_floating_damage_numbers()
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
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_player_health_bar()
	_draw_floating_damage_numbers()


func _draw_textured_fish(float_offset: Vector2) -> void:
	var tail_angle := sin(animation_time * 9.0) * 0.22
	var direction_scale := Vector2(facing_direction * sprite_scale, sprite_scale)
	var body_texture := _get_body_frame()
	var body_size := body_texture.get_size()
	var tail_size := tail_texture.get_size()
	var tail_pivot := _get_tail_pivot(body_size, float_offset)
	var draw_color := Color.WHITE
	if hit_flash_time > 0.0:
		draw_color = Color.WHITE.lerp(Color(3.5, 3.5, 3.5, 1.0), hit_flash_time / HIT_FLASH_HOLD)
	if is_dead:
		draw_color = Color("#6f7880")

	draw_set_transform(tail_pivot, tail_angle * facing_direction, direction_scale)
	draw_texture_rect(tail_texture, Rect2(tail_size * TAIL_TEXTURE_ORIGIN_RATIO, tail_size), false, draw_color)

	draw_set_transform(float_offset, 0.0, direction_scale)
	draw_texture_rect(body_texture, Rect2(Vector2(-31.0, -31.0), body_texture.get_size()), false, draw_color)


func _get_tail_pivot(body_size: Vector2, float_offset: Vector2) -> Vector2:
	return Vector2(
		body_size.x * TAIL_ATTACH_RATIO.x * sprite_scale * facing_direction,
		body_size.y * TAIL_ATTACH_RATIO.y * sprite_scale
	) + float_offset


func _draw_player_health_bar() -> void:
	if health >= max_health and not is_dead:
		return
	var bar_position := Vector2(-PLAYER_HEALTH_BAR_SIZE.x * 0.5, -48.0)
	var fill_width := PLAYER_HEALTH_BAR_SIZE.x * clampf(health / maxf(max_health, 1.0), 0.0, 1.0)
	draw_rect(Rect2(bar_position - Vector2.ONE, PLAYER_HEALTH_BAR_SIZE + Vector2.ONE * 2.0), Color("#03131f"))
	draw_rect(Rect2(bar_position, PLAYER_HEALTH_BAR_SIZE), Color("#11314a"))
	draw_rect(Rect2(bar_position + Vector2.ONE, Vector2(maxf(fill_width - 2.0, 0.0), PLAYER_HEALTH_BAR_SIZE.y - 2.0)), Color("#ff5f5a"))


func _spawn_damage_number(damage: float) -> void:
	floating_damage_numbers.append({
		"text": str(int(ceilf(damage))),
		"position": Vector2(randf_range(-12.0, 12.0), -42.0),
		"velocity": Vector2(randf_range(-18.0, 18.0), randf_range(-105.0, -78.0)),
		"life": DAMAGE_NUMBER_TIME,
		"max_life": DAMAGE_NUMBER_TIME,
		"scale": randf_range(0.95, 1.12)
	})


func _update_floating_damage_numbers(delta: float) -> void:
	for number in floating_damage_numbers:
		var number_velocity: Vector2 = number["velocity"]
		var number_position: Vector2 = number["position"]
		number_position += number_velocity * delta
		number_velocity.y += 185.0 * delta
		number["position"] = number_position
		number["velocity"] = number_velocity
		number["life"] -= delta
	floating_damage_numbers = floating_damage_numbers.filter(func(number): return number["life"] > 0.0)


func _draw_floating_damage_numbers() -> void:
	for number in floating_damage_numbers:
		var alpha: float = clampf(number["life"] / number["max_life"], 0.0, 1.0)
		var font_size := int(10.0 * number["scale"])
		var text: String = number["text"]
		var text_size := DAMAGE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		var text_position: Vector2 = number["position"] - Vector2(text_size.x * 0.5, 0.0)
		draw_string(DAMAGE_FONT, text_position + Vector2.ONE, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color("#06121c", alpha))
		draw_string(DAMAGE_FONT, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color("#ff4a3d", alpha))


func _draw_attack_flash(float_offset: Vector2) -> void:
	var direction := get_attack_direction()
	var side := Vector2(-direction.y, direction.x)
	var progress := 1.0 - attack_visual_time / maxf(attack_flash_time, 0.01)
	var alpha := 0.01 * (1.0 - progress)
	var origin := direction * maxf(attack_offset - attack_range * 0.45, 8.0) + float_offset
	var tip := direction * (attack_offset + attack_range * (0.55 + progress * 0.08)) + float_offset
	var half_height := attack_height * (0.5 + progress * 0.08)
	var edge_a := tip + side * half_height
	var edge_b := tip - side * half_height
	draw_colored_polygon(PackedVector2Array([origin, edge_a, edge_b]), Color(Color.RED, alpha))


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


func _get_rect_points(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	])


func _triangle_intersects_rect(triangle: PackedVector2Array, rect: Rect2) -> bool:
	var rect_points := _get_rect_points(rect)
	for triangle_index in triangle.size():
		var triangle_start := triangle[triangle_index]
		var triangle_end := triangle[(triangle_index + 1) % triangle.size()]
		for rect_index in rect_points.size():
			var rect_start := rect_points[rect_index]
			var rect_end := rect_points[(rect_index + 1) % rect_points.size()]
			if Geometry2D.segment_intersects_segment(triangle_start, triangle_end, rect_start, rect_end) != null:
				return true
	return false


func _is_point_in_triangle(point: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var side_ab := _triangle_sign(point, a, b)
	var side_bc := _triangle_sign(point, b, c)
	var side_ca := _triangle_sign(point, c, a)
	var has_negative := side_ab < 0.0 or side_bc < 0.0 or side_ca < 0.0
	var has_positive := side_ab > 0.0 or side_bc > 0.0 or side_ca > 0.0
	return not (has_negative and has_positive)


func _triangle_sign(point: Vector2, a: Vector2, b: Vector2) -> float:
	return (point.x - b.x) * (a.y - b.y) - (a.x - b.x) * (point.y - b.y)
