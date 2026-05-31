extends Node2D

signal died(shrimp)

@export var sprite_scale := 0.35
@export var move_radius := 34.0
@export var move_speed := 7.0
@export var eat_damage := 0.6
@export var eat_interval := 0.85
@export var eat_range := 42.0
@export var max_health := 3.0
@export_range(0.0, 1.0, 0.01) var hit_sound_volume := 0.75
@export var hit_sound_pitch := 1.0
@export var hit_sound_audible_radius := 520.0
@export var shared_hit_sound_cooldown := 0.08
@export var hunger_drain_rate := 3.0
@export var hunger_gain_per_bite := 16.0
@export var hungry_threshold := 30.0
@export var collision_radius := 20.0
@export var push_force := 360.0
@export var push_damping := 9.0
@export var return_speed := 48.0
@export var turn_smoothing := 4.0
@export var shrimp_separation_force := 70.0
@export var ground_padding := 3.0
@export var push_recover_delay := 0.25
@export_range(0.0, 1.0, 0.01) var golden_chance := 0.05
@export var flee_duration := 1.6
@export var flee_speed := 210.0
@export var flee_keep_distance := 105.0
@export var flee_keep_player_speed := 45.0
@export var algae_xp_carry_multiplier := 1.0

var target_weed: Node2D
var sound_listener: Node2D
var home_offset := Vector2.ZERO
var ground_y := INF
var last_target_position := Vector2.ZERO
var wander_time := 0.0
var eat_cooldown := 0.0
var hunger := 100.0
var is_eating := false
var move_decision_timer := 0.0
var chosen_move_direction := Vector2.RIGHT
var facing_direction := -1.0
var last_position := Vector2.ZERO
var movement_amount := 0.0
var swim_velocity := Vector2.ZERO
var push_velocity := Vector2.ZERO
var is_initial_position_ready := false
var desired_position_cache := Vector2.ZERO
var is_being_pushed := false
var push_recover_timer := 0.0
var flee_timer := 0.0
var flee_direction := Vector2.ZERO
var is_golden := false
var stored_algae_xp := 0.0
var health := max_health
var damage_flash_time := 0.0
var health_bar_time := 0.0
var is_dying := false
var floating_numbers: Array[Dictionary] = []
var death_particles: Array[Dictionary] = []
var hit_sound_player: AudioStreamPlayer
var golden_idle_texture: Texture2D
var golden_move_frames: Array[Texture2D] = []

static var last_shared_hit_sound_time := -999.0

const MOVE_FRAME_TIME := 0.90
const FACING_DEADZONE := 1.5
const RETURN_WHEN_PUSH_BELOW := 35.0
const DAMAGE_FLASH_HOLD := 0.12
const HEALTH_BAR_HOLD := 0.8
const HEALTH_BAR_SIZE := Vector2(28.0, 5.0)
const DAMAGE_NUMBER_TIME := 0.65
const DEATH_PARTICLE_TIME := 0.42
const GOLDEN_DARK := Color("#8f5a00")
const GOLDEN_MID := Color("#ffb320")
const GOLDEN_LIGHT := Color("#ffe27a")
const SPARKLE_COLOR := Color("#fff3a6")
const DAMAGE_FONT: Font = preload("res://assets/fonts/PressStart2P-Regular.ttf")
const HIT_SOUND_STREAM := preload("res://assets/audio/shrimp_hit.mp3")
const IDLE_TEXTURE := preload("res://assets/shrimp/shrimp_idle.png")
const MOVE_FRAMES: Array[Texture2D] = [
	preload("res://assets/shrimp/shrimp_move_1.png"),
	preload("res://assets/shrimp/shrimp_move_2.png"),
	preload("res://assets/shrimp/shrimp_move_3.png"),
	preload("res://assets/shrimp/shrimp_move_4.png"),
	preload("res://assets/shrimp/shrimp_move_5.png")
]


func setup(weed: Node2D, initial_home_offset := Vector2.INF, new_ground_y := INF) -> void:
	_setup_hit_sound()
	is_golden = randf() < golden_chance
	health = max_health
	stored_algae_xp = 0.0
	is_dying = false
	floating_numbers.clear()
	death_particles.clear()
	if is_golden:
		_setup_golden_textures()
	target_weed = weed
	ground_y = new_ground_y
	wander_time = randf_range(0.0, TAU)
	home_offset = initial_home_offset
	if home_offset == Vector2.INF:
		home_offset = Vector2(randf_range(-move_radius, move_radius), randf_range(-26.0, -12.0))
	var orbit := _get_soft_motion_offset()
	position = target_weed.position + home_offset + orbit
	last_target_position = target_weed.position
	_apply_ground_limit()
	last_position = position
	is_initial_position_ready = true
	eat_cooldown = randf_range(0.0, eat_interval)
	_choose_new_move_direction()


func _exit_tree() -> void:
	if hit_sound_player != null:
		hit_sound_player.stop()
		hit_sound_player.stream = null


func set_target_weed(weed: Node2D) -> void:
	target_weed = weed
	if is_instance_valid(target_weed):
		last_target_position = target_weed.position
		home_offset = Vector2(randf_range(-move_radius, move_radius), randf_range(-26.0, -12.0))
		is_eating = hunger <= hungry_threshold


func set_sound_listener(listener: Node2D) -> void:
	sound_listener = listener


func take_damage(amount: float, _is_critical := false, attacker_position := Vector2.INF) -> int:
	if is_dying or health <= 0.0:
		return 0

	var damage := minf(health, amount)
	health -= damage
	_start_fleeing_from(attacker_position)
	damage_flash_time = DAMAGE_FLASH_HOLD
	health_bar_time = HEALTH_BAR_HOLD
	_spawn_damage_number(damage, _is_critical)
	_play_hit_sound()
	if health > 0.0:
		queue_redraw()
		return 0

	health = 0.0
	is_dying = true
	died.emit(self)
	_spawn_death_particles()
	queue_redraw()
	return 0


func is_alive() -> bool:
	return health > 0.0 and not is_dying and not is_queued_for_deletion()


func get_interaction_rect() -> Rect2:
	var visual_size := _get_visual_size()
	return Rect2(global_position + Vector2(-visual_size.x * 0.5, -visual_size.y), visual_size)


func _process(delta: float) -> void:
	damage_flash_time = maxf(damage_flash_time - delta, 0.0)
	health_bar_time = maxf(health_bar_time - delta, 0.0)
	flee_timer = maxf(flee_timer - delta, 0.0)
	_update_floating_numbers(delta)
	_update_death_particles(delta)
	if is_dying:
		queue_redraw()
		if floating_numbers.is_empty() and death_particles.is_empty():
			queue_free()
		return
	if not is_instance_valid(target_weed):
		target_weed = null
		is_eating = false
		last_position = position
		_update_free_swim_without_weed(delta)
		_update_push(delta)
		_apply_ground_limit()
		_update_facing_from_movement()
		queue_redraw()
		return
	if target_weed.has_method("is_consumable") and not target_weed.is_consumable():
		target_weed = null
		is_eating = false
		return

	wander_time += delta * move_speed
	hunger = maxf(hunger - hunger_drain_rate * delta, 0.0)
	eat_cooldown = maxf(eat_cooldown - delta, 0.0)
	move_decision_timer = maxf(move_decision_timer - delta, 0.0)
	push_recover_timer = maxf(push_recover_timer - delta, 0.0)
	last_position = position
	is_being_pushed = false
	_update_hunger_state()
	if flee_timer > 0.0:
		is_eating = false
		_follow_world_scroll()
		_update_flee(delta)
	else:
		_follow_weed(delta)
	_update_push(delta)
	_apply_ground_limit()
	_update_facing_from_movement()
	_try_eat_weed()
	queue_redraw()


func _update_free_swim_without_weed(delta: float) -> void:
	wander_time += delta * move_speed
	hunger = maxf(hunger - hunger_drain_rate * delta, 0.0)
	move_decision_timer = maxf(move_decision_timer - delta, 0.0)
	push_recover_timer = maxf(push_recover_timer - delta, 0.0)
	is_being_pushed = false
	if move_decision_timer <= 0.0:
		_choose_new_move_direction()
	var desired_position := position + chosen_move_direction * return_speed
	desired_position.y += sin(wander_time * 1.7) * 7.0
	desired_position_cache = desired_position
	if push_velocity.length() < RETURN_WHEN_PUSH_BELOW and push_recover_timer <= 0.0:
		_update_curved_return(desired_position, delta)


func _follow_weed(delta: float) -> void:
	_follow_world_scroll()

	var desired_position := _get_desired_position()
	if ground_y < INF:
		desired_position.y = minf(desired_position.y, ground_y - ground_padding)
	desired_position_cache = desired_position
	if not is_initial_position_ready:
		position = desired_position
		is_initial_position_ready = true
	elif push_velocity.length() < RETURN_WHEN_PUSH_BELOW and push_recover_timer <= 0.0:
		_update_curved_return(desired_position, delta)


func _follow_world_scroll() -> void:
	if not is_instance_valid(target_weed):
		return
	var target_delta := target_weed.position - last_target_position
	position += target_delta
	last_target_position = target_weed.position


func _update_curved_return(desired_position: Vector2, delta: float) -> void:
	var to_target := desired_position - position
	if to_target.length() < 2.0:
		swim_velocity = swim_velocity.lerp(Vector2.ZERO, 1.0 - exp(-turn_smoothing * delta))
	else:
		var desired_velocity := to_target.normalized() * return_speed
		var curve_angle := sin(wander_time * 1.7) * 0.45
		desired_velocity = desired_velocity.rotated(curve_angle)
		swim_velocity = swim_velocity.lerp(desired_velocity, 1.0 - exp(-turn_smoothing * delta))
	position += swim_velocity * delta


func _start_fleeing_from(attacker_position: Vector2) -> void:
	if attacker_position == Vector2.INF:
		return
	var away := global_position - attacker_position
	if away.length_squared() <= 0.01:
		away = Vector2.RIGHT.rotated(randf() * TAU)
	flee_direction = away.normalized()
	flee_timer = flee_duration
	chosen_move_direction = flee_direction
	move_decision_timer = flee_duration
	is_eating = false


func _update_flee(delta: float) -> void:
	var desired_velocity := flee_direction * flee_speed
	var curve_angle := sin(wander_time * 2.4) * 0.25
	desired_velocity = desired_velocity.rotated(curve_angle)
	swim_velocity = swim_velocity.lerp(desired_velocity, 1.0 - exp(-turn_smoothing * delta))
	position += swim_velocity * delta
	desired_position_cache = position + flee_direction * flee_speed


func _update_hunger_state() -> void:
	if is_eating:
		if hunger >= 100.0:
			is_eating = false
			_choose_new_move_direction()
		return

	if hunger <= hungry_threshold:
		is_eating = true


func _get_desired_position() -> Vector2:
	if is_eating:
		return target_weed.position + Vector2(0.0, -34.0)

	if move_decision_timer <= 0.0:
		_choose_new_move_direction()
	var free_swim_target := position + chosen_move_direction * return_speed
	free_swim_target.y += sin(wander_time * 1.7) * 7.0
	return free_swim_target


func _choose_new_move_direction() -> void:
	move_decision_timer = randf_range(2.0, 5.0)
	chosen_move_direction = Vector2.RIGHT.rotated(randf() * TAU)
	if randf() < 0.22:
		chosen_move_direction = Vector2.ZERO


func handle_player_collision(player: Node2D, player_velocity: Vector2) -> void:
	if not is_alive():
		return
	_keep_fleeing_if_player_chases(player.global_position, player_velocity)
	var push_data := _get_player_shape_push(player)
	if push_data.is_empty():
		return

	var push_direction: Vector2 = push_data["direction"]
	var overlap: float = push_data["overlap"]
	var movement_boost := clampf(player_velocity.length() / 260.0, 0.65, 1.65)
	var overlap_strength := clampf(overlap / collision_radius, 0.0, 1.0)
	push_velocity += push_direction * push_force * movement_boost * overlap_strength
	push_recover_timer = push_recover_delay
	if flee_timer > 0.0:
		flee_direction = (flee_direction + push_direction * 0.8).normalized()
		global_position += push_direction * minf(overlap * 0.25, 3.0)
	else:
		global_position += push_direction * overlap * 0.6
	_apply_ground_limit()


func _keep_fleeing_if_player_chases(player_position: Vector2, player_velocity: Vector2) -> void:
	if flee_timer <= 0.0:
		return
	var from_player := global_position - player_position
	var distance := from_player.length()
	if distance > flee_keep_distance:
		return
	if player_velocity.length() < flee_keep_player_speed:
		return
	var player_is_moving_toward_shrimp := player_velocity.normalized().dot(from_player.normalized()) > 0.25
	if not player_is_moving_toward_shrimp:
		return
	flee_direction = from_player.normalized()
	flee_timer = flee_duration
	chosen_move_direction = flee_direction


func _get_player_shape_push(player: Node2D) -> Dictionary:
	var shape_node := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var shrimp_collision_center := _get_collision_center()
	if shape_node == null or shape_node.disabled or shape_node.shape == null:
		return _get_fallback_player_push(player.global_position, shrimp_collision_center)

	var shape := shape_node.shape
	var local_position := shape_node.to_local(shrimp_collision_center)
	if shape is CapsuleShape2D:
		return _get_capsule_push(shape_node, shape, local_position)
	if shape is CircleShape2D:
		return _get_circle_push(shape_node, shape, local_position)
	if shape is RectangleShape2D:
		return _get_rectangle_push(shape_node, shape, local_position)
	return _get_fallback_player_push(player.global_position, shrimp_collision_center)


func _get_capsule_push(shape_node: CollisionShape2D, shape: CapsuleShape2D, local_position: Vector2) -> Dictionary:
	var segment_half_height := maxf(shape.height * 0.5 - shape.radius, 0.0)
	var closest_on_segment := Vector2(0.0, clampf(local_position.y, -segment_half_height, segment_half_height))
	var from_capsule := local_position - closest_on_segment
	var distance := from_capsule.length()
	var minimum_distance := shape.radius + collision_radius
	if distance >= minimum_distance:
		return {}
	var local_direction := Vector2.RIGHT if distance <= 0.01 else from_capsule / distance
	return _make_push_data(shape_node, local_direction, minimum_distance - distance)


func _get_circle_push(shape_node: CollisionShape2D, shape: CircleShape2D, local_position: Vector2) -> Dictionary:
	var distance := local_position.length()
	var minimum_distance := shape.radius + collision_radius
	if distance >= minimum_distance:
		return {}
	var local_direction := Vector2.RIGHT if distance <= 0.01 else local_position / distance
	return _make_push_data(shape_node, local_direction, minimum_distance - distance)


func _get_rectangle_push(shape_node: CollisionShape2D, shape: RectangleShape2D, local_position: Vector2) -> Dictionary:
	var half_size := shape.size * 0.5
	var closest_point := Vector2(
		clampf(local_position.x, -half_size.x, half_size.x),
		clampf(local_position.y, -half_size.y, half_size.y)
	)
	var from_rectangle := local_position - closest_point
	var distance := from_rectangle.length()
	if distance > 0.01:
		if distance >= collision_radius:
			return {}
		return _make_push_data(shape_node, from_rectangle / distance, collision_radius - distance)

	var distance_to_edge := Vector2(half_size.x - absf(local_position.x), half_size.y - absf(local_position.y))
	if distance_to_edge.x < distance_to_edge.y:
		return _make_push_data(shape_node, Vector2(signf(local_position.x), 0.0), collision_radius + distance_to_edge.x)
	return _make_push_data(shape_node, Vector2(0.0, signf(local_position.y)), collision_radius + distance_to_edge.y)


func _make_push_data(shape_node: CollisionShape2D, local_direction: Vector2, overlap: float) -> Dictionary:
	var global_direction := shape_node.global_transform.basis_xform(local_direction).normalized()
	return {
		"direction": global_direction,
		"overlap": overlap
	}


func _get_collision_center() -> Vector2:
	return global_position + Vector2(0.0, -_get_visual_size().y * 0.5)


func _get_fallback_player_push(player_position: Vector2, shrimp_collision_center: Vector2) -> Dictionary:
	var from_player := shrimp_collision_center - player_position
	var distance := from_player.length()
	var fallback_radius := 36.0
	var minimum_distance := collision_radius + fallback_radius
	if distance >= minimum_distance:
		return {}
	var push_direction := Vector2.RIGHT if distance <= 0.01 else from_player / distance
	return {
		"direction": push_direction,
		"overlap": minimum_distance - distance
	}


func separate_from(other_shrimp: Node2D) -> void:
	if not is_alive():
		return
	if other_shrimp.has_method("is_alive") and not other_shrimp.is_alive():
		return
	var from_other := global_position - other_shrimp.global_position
	var distance := from_other.length()
	var other_radius := collision_radius
	if other_shrimp.get("collision_radius") != null:
		other_radius = other_shrimp.collision_radius
	var minimum_distance := collision_radius + other_radius
	if distance <= 0.01 or distance >= minimum_distance:
		return

	var push_direction := from_other / distance
	var overlap := minimum_distance - distance
	global_position += push_direction * overlap * 0.5
	push_velocity += push_direction * shrimp_separation_force * (overlap / minimum_distance)


func _update_push(delta: float) -> void:
	if push_velocity.length_squared() <= 0.01:
		push_velocity = Vector2.ZERO
		return
	is_being_pushed = true
	position += push_velocity * delta
	push_velocity = push_velocity.lerp(Vector2.ZERO, 1.0 - exp(-push_damping * delta))
	_apply_ground_limit()


func _try_eat_weed() -> void:
	if not is_eating:
		return
	if eat_cooldown > 0.0:
		return
	if not _is_close_enough_to_eat():
		return
	eat_cooldown = eat_interval
	if target_weed.has_method("take_damage"):
		var gained_xp := int(target_weed.take_damage(eat_damage, false))
		stored_algae_xp += float(gained_xp) * algae_xp_carry_multiplier
		hunger = minf(hunger + hunger_gain_per_bite, 100.0)


func _is_close_enough_to_eat() -> bool:
	var weed_bite_point := target_weed.position + Vector2(0.0, -34.0)
	return position.distance_to(weed_bite_point) <= eat_range


func _get_soft_motion_offset() -> Vector2:
	return Vector2(
		sin(wander_time) * move_radius * 0.28,
		cos(wander_time * 1.7) * 7.0
	)


func _apply_ground_limit() -> void:
	if ground_y >= INF:
		return
	var _bottom_offset := _get_visual_size().y
	var max_position_y := ground_y - ground_padding
	if position.y > max_position_y:
		position.y = max_position_y
		if push_velocity.y > 0.0:
			push_velocity.y = 0.0


func _get_visual_size() -> Vector2:
	return IDLE_TEXTURE.get_size() * sprite_scale


func _update_facing_from_movement() -> void:
	var movement := position - last_position
	movement_amount = movement.length()
	if is_being_pushed:
		return

	if not is_eating:
		if absf(chosen_move_direction.x) > 0.15:
			facing_direction = signf(chosen_move_direction.x)
		elif absf(swim_velocity.x) > FACING_DEADZONE:
			facing_direction = signf(swim_velocity.x)
		return

	var return_direction := desired_position_cache.x - position.x
	if absf(return_direction) > FACING_DEADZONE:
		facing_direction = signf(return_direction)


func _draw() -> void:
	if is_dying:
		_draw_death_particles()
		_draw_floating_numbers()
		return

	var texture := _get_current_texture()
	var texture_size := texture.get_size()
	var draw_size := texture_size * sprite_scale
	var draw_color := Color.WHITE.lerp(Color(2.2, 2.2, 2.2, 1.0), clampf(damage_flash_time / DAMAGE_FLASH_HOLD, 0.0, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-facing_direction, 1.0))
	draw_texture_rect(texture, Rect2(Vector2(-draw_size.x * 0.5, -draw_size.y), draw_size), false, draw_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if is_golden:
		_draw_golden_sparkles(draw_size)
	if health_bar_time > 0.0 and max_health > 0.0:
		_draw_health_bar(draw_size)
	_draw_floating_numbers()


func _draw_golden_sparkles(draw_size: Vector2) -> void:
	for index in 4:
		var phase := wander_time * 1.2 + float(index) * TAU * 0.25
		var sparkle_position := Vector2(
			cos(phase) * draw_size.x * 0.55,
			-draw_size.y * 0.55 + sin(phase * 1.3) * draw_size.y * 0.28
		)
		var sparkle_size := 2.0 + sin(phase * 2.0) * 0.8
		var sparkle_color := SPARKLE_COLOR
		sparkle_color.a = 0.55 + sin(phase * 1.7) * 0.25
		_draw_pixel_sparkle(sparkle_position.round(), sparkle_size, sparkle_color)


func _draw_pixel_sparkle(center: Vector2, sparkle_size: float, color: Color) -> void:
	var size := maxf(1.0, roundf(sparkle_size))
	draw_rect(Rect2(center - Vector2(size * 0.5, size * 0.5), Vector2(size, size)), color)
	draw_rect(Rect2(center + Vector2(-size * 1.4, -0.5), Vector2(size * 2.8, 1.0)), Color(color.r, color.g, color.b, color.a * 0.55))
	draw_rect(Rect2(center + Vector2(-0.5, -size * 1.4), Vector2(1.0, size * 2.8)), Color(color.r, color.g, color.b, color.a * 0.55))


func _draw_health_bar(draw_size: Vector2) -> void:
	var bar_position := Vector2(-HEALTH_BAR_SIZE.x * 0.5, -draw_size.y - 8.0)
	var fill_width := HEALTH_BAR_SIZE.x * clampf(health / max_health, 0.0, 1.0)
	draw_rect(Rect2(bar_position - Vector2.ONE, HEALTH_BAR_SIZE + Vector2.ONE * 2.0), Color("#03131f"))
	draw_rect(Rect2(bar_position, HEALTH_BAR_SIZE), Color("#12324a"))
	draw_rect(Rect2(bar_position + Vector2.ONE, Vector2(maxf(fill_width - 2.0, 0.0), HEALTH_BAR_SIZE.y - 2.0)), Color("#ff5f5a"))


func _spawn_damage_number(damage: float, is_critical := false) -> void:
	var amount := int(ceilf(damage))
	floating_numbers.append({
		"text": str(amount),
		"is_critical": is_critical,
		"position": Vector2(randf_range(-10.0, 10.0), -_get_visual_size().y - 12.0),
		"velocity": Vector2(randf_range(-16.0, 16.0), randf_range(-90.0, -65.0)),
		"life": DAMAGE_NUMBER_TIME,
		"max_life": DAMAGE_NUMBER_TIME,
		"scale": 1.15 if is_critical else 0.9
	})


func _update_floating_numbers(delta: float) -> void:
	for number in floating_numbers:
		var velocity: Vector2 = number["velocity"]
		var number_position: Vector2 = number["position"]
		number_position += velocity * delta
		velocity.y += 170.0 * delta
		number["position"] = number_position
		number["velocity"] = velocity
		number["life"] -= delta
	floating_numbers = floating_numbers.filter(func(number): return number["life"] > 0.0)


func _draw_floating_numbers() -> void:
	for number in floating_numbers:
		var alpha: float = clampf(number["life"] / number["max_life"], 0.0, 1.0)
		var font_size := int(10.0 * number["scale"])
		var text: String = number["text"]
		var text_size := DAMAGE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		var text_position: Vector2 = number["position"] - Vector2(text_size.x * 0.5, 0.0)
		var text_color := Color("#ff4a3d", alpha) if number["is_critical"] else Color("#ffd65a", alpha)
		draw_string(DAMAGE_FONT, text_position + Vector2.ONE, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color("#06121c", alpha))
		draw_string(DAMAGE_FONT, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, text_color)


func _spawn_death_particles() -> void:
	var visual_size := _get_visual_size()
	var colors := [Color("#ff7658"), Color("#f13b32"), Color("#ffd15a"), Color("#3b1b19")]
	if is_golden:
		colors = [GOLDEN_DARK, GOLDEN_MID, GOLDEN_LIGHT, Color("#fff0a4")]
	for index in 18:
		death_particles.append({
			"position": Vector2(randf_range(-visual_size.x * 0.35, visual_size.x * 0.35), randf_range(-visual_size.y, -visual_size.y * 0.25)),
			"velocity": Vector2(randf_range(-85.0, 85.0), randf_range(-110.0, -28.0)),
			"life": DEATH_PARTICLE_TIME,
			"max_life": DEATH_PARTICLE_TIME,
			"size": randf_range(2.0, 5.0),
			"color": colors.pick_random()
		})


func _update_death_particles(delta: float) -> void:
	for particle in death_particles:
		var velocity: Vector2 = particle["velocity"]
		var particle_position: Vector2 = particle["position"]
		particle_position += velocity * delta
		velocity.y += 260.0 * delta
		particle["position"] = particle_position
		particle["velocity"] = velocity
		particle["life"] -= delta
	death_particles = death_particles.filter(func(particle): return particle["life"] > 0.0)


func _draw_death_particles() -> void:
	for particle in death_particles:
		var alpha: float = clampf(particle["life"] / particle["max_life"], 0.0, 1.0)
		var color: Color = particle["color"]
		color.a = alpha
		var pixel_size: float = particle["size"] * alpha
		draw_rect(Rect2(particle["position"] - Vector2.ONE * pixel_size * 0.5, Vector2.ONE * pixel_size), color)


func _setup_hit_sound() -> void:
	if hit_sound_player != null:
		return
	hit_sound_player = AudioStreamPlayer.new()
	hit_sound_player.name = "HitSound"
	hit_sound_player.stream = HIT_SOUND_STREAM
	hit_sound_player.bus = "Master"
	add_child(hit_sound_player)


func _play_hit_sound() -> void:
	if not _can_play_hit_sound():
		return
	if hit_sound_player == null:
		_setup_hit_sound()
	hit_sound_player.stop()
	hit_sound_player.volume_db = linear_to_db(_get_hit_sound_volume())
	hit_sound_player.pitch_scale = hit_sound_pitch
	hit_sound_player.play()
	last_shared_hit_sound_time = _get_sound_time()


func _can_play_hit_sound() -> bool:
	if not _is_close_enough_for_sound():
		return false
	return _get_sound_time() - last_shared_hit_sound_time >= shared_hit_sound_cooldown


func _is_close_enough_for_sound() -> bool:
	if not is_instance_valid(sound_listener):
		return true
	return global_position.distance_to(sound_listener.global_position) <= hit_sound_audible_radius


func _get_hit_sound_volume() -> float:
	if not is_instance_valid(sound_listener):
		return maxf(clampf(hit_sound_volume, 0.0, 1.0), 0.001)
	var distance := global_position.distance_to(sound_listener.global_position)
	var distance_factor := clampf(1.0 - distance / maxf(hit_sound_audible_radius, 1.0), 0.0, 1.0)
	var softened_factor := lerpf(0.25, 1.0, distance_factor)
	return maxf(clampf(hit_sound_volume, 0.0, 1.0) * softened_factor, 0.001)


func _get_sound_time() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _get_current_texture() -> Texture2D:
	if is_dying:
		return golden_idle_texture if is_golden and golden_idle_texture != null else IDLE_TEXTURE
	if is_golden:
		return _get_current_golden_texture()
	if is_eating and _is_close_enough_to_eat():
		return IDLE_TEXTURE
	if movement_amount < 0.08:
		return IDLE_TEXTURE
	var frame_index := int(wander_time / MOVE_FRAME_TIME) % MOVE_FRAMES.size()
	return MOVE_FRAMES[frame_index]


func _get_current_golden_texture() -> Texture2D:
	if golden_idle_texture == null or golden_move_frames.is_empty():
		_setup_golden_textures()
	if is_eating and _is_close_enough_to_eat():
		return golden_idle_texture
	if movement_amount < 0.08:
		return golden_idle_texture
	var frame_index := int(wander_time / MOVE_FRAME_TIME) % golden_move_frames.size()
	return golden_move_frames[frame_index]


func _setup_golden_textures() -> void:
	if golden_idle_texture != null and not golden_move_frames.is_empty():
		return
	golden_idle_texture = _make_golden_texture(IDLE_TEXTURE)
	golden_move_frames.clear()
	for frame in MOVE_FRAMES:
		golden_move_frames.append(_make_golden_texture(frame))


func _make_golden_texture(source_texture: Texture2D) -> Texture2D:
	var image := source_texture.get_image()
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			if _is_shrimp_red_pixel(color):
				image.set_pixel(x, y, _red_to_gold(color))
	return ImageTexture.create_from_image(image)


func _is_shrimp_red_pixel(color: Color) -> bool:
	return color.r > color.g * 1.35 and color.r > color.b * 1.35 and color.r > 0.18


func _red_to_gold(color: Color) -> Color:
	var brightness := maxf(color.r, maxf(color.g, color.b))
	var gold := GOLDEN_DARK.lerp(GOLDEN_MID, clampf(brightness * 1.4, 0.0, 1.0))
	if brightness > 0.72:
		gold = gold.lerp(GOLDEN_LIGHT, clampf((brightness - 0.72) / 0.28, 0.0, 1.0))
	gold.a = color.a
	return gold
