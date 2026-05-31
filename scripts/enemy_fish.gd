extends Node2D

signal died(enemy)

@export var sprite_scale := 0.60
@export var max_health := 6.0
@export var xp_reward := 8
@export var swim_speed := 58.0
@export var turn_smoothing := 4.5
@export var vertical_follow_strength := 0.65
@export var collision_size := Vector2(58.0, 44.0)
@export var attack_damage := 1.0
@export var attack_range := 72.0
@export var attack_cooldown := 1.25
@export var attack_frame_time := 0.075
@export var attack_hit_frame := 6
@export var player_priority_range := 95.0
@export var meat_eat_range := 40.0
@export var meat_bite_interval := 0.45
@export var enemy_push_strength := 0.45
@export var enemy_separation_strength := 0.55
@export var fight_duration := 4.0
@export_range(0.0, 1.0, 0.01) var attack_sound_volume := 0.28
@export_range(0.0, 1.0, 0.01) var hit_sound_volume := 0.75
@export var sound_audible_radius := 520.0
@export var shared_attack_sound_cooldown := 0.28
@export var shared_hit_sound_cooldown := 0.12

var player: Node2D
var seaweed_field
var ground_y := INF
var animation_time := 0.0
var health := max_health
var facing_direction := 1.0
var swim_velocity := Vector2.ZERO
var damage_flash_time := 0.0
var health_bar_time := 0.0
var is_dying := false
var is_attacking := false
var attack_time := 0.0
var attack_cooldown_timer := 0.0
var attack_has_hit := false
var meat_bite_timer := 0.0
var current_target: Node2D
var current_target_type := ""
var rival_target: Node2D
var fight_timer := 0.0
var stored_meat_xp := 0
var variant_id := "normal"
var variant_color := Color.WHITE
var is_golden := false
var attack_sound_player: AudioStreamPlayer
var hit_sound_player: AudioStreamPlayer
var floating_numbers: Array[Dictionary] = []
var death_particles: Array[Dictionary] = []
var accidental_hit_targets: Array[Node2D] = []
var body_texture: Texture2D = BODY_TEXTURE
var tail_texture: Texture2D = TAIL_TEXTURE
var attack_frames: Array[Texture2D] = ATTACK_FRAMES.duplicate()

static var last_shared_attack_sound_time := -999.0
static var last_shared_hit_sound_time := -999.0

const DAMAGE_FLASH_HOLD := 0.12
const HEALTH_BAR_HOLD := 0.85
const HEALTH_BAR_SIZE := Vector2(36.0, 6.0)
const DAMAGE_NUMBER_TIME := 0.65
const DEATH_PARTICLE_TIME := 0.46
const TAIL_ATTACH_RATIO := Vector2(0.13, 0.03)
const TAIL_TEXTURE_ORIGIN_RATIO := Vector2(-0.22, -0.50)
const GOLDEN_DARK := Color("#8f5a00")
const GOLDEN_MID := Color("#ffb320")
const GOLDEN_LIGHT := Color("#ffe27a")
const SPARKLE_COLOR := Color("#fff3a6")
const BODY_TEXTURE := preload("res://assets/enemy/enemy1/Enemy1.png")
const TAIL_TEXTURE := preload("res://assets/enemy/enemy1/Enemy1_Tail.png")
const DAMAGE_FONT: Font = preload("res://assets/fonts/PressStart2P-Regular.ttf")
const ATTACK_SOUND_STREAM := preload("res://assets/audio/enemy_attack_hit_damage.wav")
const HIT_SOUND_STREAM := preload("res://assets/audio/enemy_hurt_boss_hit.wav")
const ATTACK_FRAMES: Array[Texture2D] = [
	preload("res://assets/enemy/enemy1/attack/Enemy1_atack1.png"),
	preload("res://assets/enemy/enemy1/attack/Enemy1_atack2.png"),
	preload("res://assets/enemy/enemy1/attack/Enemy1_atack3.png"),
	preload("res://assets/enemy/enemy1/attack/Enemy1_atack4.png"),
	preload("res://assets/enemy/enemy1/attack/Enemy1_atack5.png"),
	preload("res://assets/enemy/enemy1/attack/Enemy1_atack6.png"),
	preload("res://assets/enemy/enemy1/attack/Enemy1_atack7.png"),
	preload("res://assets/enemy/enemy1/attack/Enemy1_atack8.png"),
	preload("res://assets/enemy/enemy1/attack/Enemy1_atack9.png")
]


func apply_variant(config: Dictionary) -> void:
	var previous_scale := maxf(sprite_scale, 0.01)
	var scale_ratio := float(config.get("sprite_scale", sprite_scale)) / previous_scale
	var health_multiplier := float(config.get("health_multiplier", 1.0))
	var damage_multiplier := float(config.get("damage_multiplier", 1.0))
	var xp_multiplier := float(config.get("xp_multiplier", 1.0))
	var attack_range_multiplier := float(config.get("attack_range_multiplier", 1.0))

	variant_id = String(config.get("id", "normal"))
	variant_color = config.get("color", Color.WHITE)
	is_golden = bool(config.get("is_golden", false))
	sprite_scale = float(config.get("sprite_scale", sprite_scale))
	collision_size *= scale_ratio
	attack_range *= scale_ratio * attack_range_multiplier
	player_priority_range *= scale_ratio
	meat_eat_range *= scale_ratio
	max_health *= health_multiplier
	health = max_health
	attack_damage *= damage_multiplier
	xp_reward = int(roundi(float(xp_reward) * xp_multiplier))

	if variant_id == "normal":
		body_texture = BODY_TEXTURE
		tail_texture = TAIL_TEXTURE
		attack_frames = ATTACK_FRAMES.duplicate()
	else:
		body_texture = _make_variant_texture(BODY_TEXTURE, variant_color, is_golden)
		tail_texture = _make_variant_texture(TAIL_TEXTURE, variant_color, is_golden)
		attack_frames.clear()
		for frame in ATTACK_FRAMES:
			attack_frames.append(_make_variant_texture(frame, variant_color, is_golden))


func setup(new_player: Node2D, new_ground_y := INF, new_seaweed_field = null) -> void:
	player = new_player
	seaweed_field = new_seaweed_field
	ground_y = new_ground_y
	health = max_health
	is_dying = false
	is_attacking = false
	attack_time = 0.0
	attack_cooldown_timer = 0.0
	attack_has_hit = false
	meat_bite_timer = 0.0
	current_target = null
	current_target_type = ""
	rival_target = null
	fight_timer = 0.0
	stored_meat_xp = 0
	accidental_hit_targets.clear()
	floating_numbers.clear()
	death_particles.clear()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_setup_sounds()


func _exit_tree() -> void:
	if attack_sound_player != null:
		attack_sound_player.stop()
		attack_sound_player.stream = null
	if hit_sound_player != null:
		hit_sound_player.stop()
		hit_sound_player.stream = null


func apply_world_scroll(travel_delta: float) -> void:
	position.x -= travel_delta


func take_damage(amount: float, is_critical := false, _hit_origin := Vector2.ZERO) -> int:
	if is_dying or health <= 0.0:
		return 0

	var damage := minf(health, amount)
	health -= damage
	damage_flash_time = DAMAGE_FLASH_HOLD
	health_bar_time = HEALTH_BAR_HOLD
	_spawn_damage_number(damage, is_critical)
	_play_hit_sound()

	if health > 0.0:
		queue_redraw()
		return 0

	health = 0.0
	is_dying = true
	_spawn_death_particles()
	died.emit(self)
	queue_redraw()
	return 0


func is_alive() -> bool:
	return health > 0.0 and not is_dying and not is_queued_for_deletion()


func get_meat_drop_xp() -> float:
	return float(xp_reward + stored_meat_xp)


func get_meat_drop_scale() -> float:
	return clampf(sprite_scale / 0.60, 0.65, 2.8)


func is_golden_variant() -> bool:
	return is_golden


func get_interaction_rect() -> Rect2:
	return Rect2(global_position - collision_size * 0.5, collision_size)


func is_offscreen(viewport_size: Vector2) -> bool:
	var margin := 180.0
	return position.x < -margin or position.x > viewport_size.x + margin or position.y < -margin or position.y > viewport_size.y + margin


func _process(delta: float) -> void:
	animation_time += delta
	damage_flash_time = maxf(damage_flash_time - delta, 0.0)
	health_bar_time = maxf(health_bar_time - delta, 0.0)
	attack_cooldown_timer = maxf(attack_cooldown_timer - delta, 0.0)
	meat_bite_timer = maxf(meat_bite_timer - delta, 0.0)
	fight_timer = maxf(fight_timer - delta, 0.0)
	_update_floating_numbers(delta)
	_update_death_particles(delta)
	if is_dying:
		queue_redraw()
		if floating_numbers.is_empty() and death_particles.is_empty():
			queue_free()
		return

	if is_attacking:
		_update_attack(delta)
	else:
		_select_priority_target()
		_update_movement(delta)
		_try_start_attack()
	_resolve_collisions()
	queue_redraw()


func _update_movement(delta: float) -> void:
	if not is_instance_valid(player):
		position.x -= swim_speed * delta
		return

	var desired_direction := Vector2(-1.0, 0.0)
	if is_instance_valid(current_target):
		var to_target := current_target.global_position - global_position
		if to_target.length_squared() > 1.0:
			desired_direction = Vector2(
				clampf(to_target.normalized().x, -1.0, 1.0),
				clampf(to_target.normalized().y, -vertical_follow_strength, vertical_follow_strength)
			).normalized()
	var desired_velocity := desired_direction * swim_speed
	swim_velocity = swim_velocity.lerp(desired_velocity, 1.0 - exp(-turn_smoothing * delta))
	position += swim_velocity * delta
	_update_facing_from_target_or_velocity()
	if ground_y < INF:
		position.y = minf(position.y, ground_y - collision_size.y * 0.65)
	if current_target_type == "meat":
		_try_eat_meat()


func _select_priority_target() -> void:
	current_target = null
	current_target_type = ""
	if fight_timer > 0.0 and _is_active_enemy_target(rival_target):
		current_target = rival_target
		current_target_type = "enemy"
		return
	rival_target = null
	if _player_should_be_priority():
		current_target = player
		current_target_type = "player"
		return

	var nearest_shrimp := _find_nearest_from_list(_get_active_shrimps())
	if nearest_shrimp != null:
		current_target = nearest_shrimp
		current_target_type = "shrimp"
		return

	var nearest_meat := _find_nearest_from_list(_get_consumable_meats())
	if nearest_meat != null:
		current_target = nearest_meat
		current_target_type = "meat"
		return

	if is_instance_valid(player):
		current_target = player
		current_target_type = "player"


func _player_should_be_priority() -> bool:
	if not is_instance_valid(player):
		return false
	if player.has_method("is_alive") and not player.is_alive():
		return false
	return global_position.distance_to(player.global_position) <= player_priority_range


func _get_active_shrimps() -> Array[Node2D]:
	if seaweed_field != null and seaweed_field.has_method("get_active_shrimps"):
		return seaweed_field.get_active_shrimps()
	return []


func _get_consumable_meats() -> Array[Node2D]:
	if seaweed_field != null and seaweed_field.has_method("get_consumable_meats"):
		return seaweed_field.get_consumable_meats()
	return []


func _find_nearest_from_list(targets: Array[Node2D]) -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := INF
	for target in targets:
		if not is_instance_valid(target):
			continue
		var distance := global_position.distance_squared_to(target.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = target
	return nearest


func _try_start_attack() -> void:
	if attack_cooldown_timer > 0.0 or not is_instance_valid(current_target):
		return
	if current_target_type == "meat":
		return
	if current_target.has_method("is_alive") and not current_target.is_alive():
		return
	if global_position.distance_to(current_target.global_position) > attack_range:
		return

	is_attacking = true
	attack_time = 0.0
	attack_has_hit = false
	accidental_hit_targets.clear()
	swim_velocity = swim_velocity * 0.25
	if absf(current_target.global_position.x - global_position.x) > 8.0:
		facing_direction = -signf(current_target.global_position.x - global_position.x)
	_play_attack_sound()


func _update_attack(delta: float) -> void:
	attack_time += delta
	swim_velocity = swim_velocity.lerp(Vector2.ZERO, 1.0 - exp(-10.0 * delta))

	var current_frame := int(attack_time / maxf(attack_frame_time, 0.01))
	if not attack_has_hit and current_frame >= attack_hit_frame:
		attack_has_hit = true
		_hit_current_target_if_in_range()

	if current_frame >= attack_frames.size():
		is_attacking = false
		attack_cooldown_timer = attack_cooldown


func _hit_current_target_if_in_range() -> void:
	if not is_instance_valid(current_target) or not current_target.has_method("take_damage"):
		return
	var target_rect := _get_target_rect(current_target)
	if _get_attack_rect().intersects(target_rect):
		if current_target_type == "player":
			current_target.take_damage(attack_damage, global_position)
		elif current_target_type == "enemy":
			current_target.start_fight_with(self)
			current_target.take_damage(attack_damage, false, global_position)
		else:
			current_target.take_damage(attack_damage, false, global_position)


func _try_eat_meat() -> void:
	if meat_bite_timer > 0.0 or not is_instance_valid(current_target):
		return
	if not current_target.has_method("get_interaction_rect") or not current_target.has_method("take_damage"):
		return
	if not get_interaction_rect().grow(meat_eat_range * 0.25).intersects(current_target.get_interaction_rect()):
		return
	meat_bite_timer = meat_bite_interval
	stored_meat_xp += current_target.take_damage(attack_damage, false)
	_play_attack_sound()


func _get_attack_rect() -> Rect2:
	var direction := Vector2(-facing_direction, 0.0)
	var center := global_position + direction * (collision_size.x * 0.45)
	var attack_size := Vector2(attack_range, collision_size.y * 1.05)
	return Rect2(center - attack_size * 0.5, attack_size)


func start_fight_with(enemy) -> void:
	if not _is_active_enemy_target(enemy):
		return
	rival_target = enemy
	fight_timer = fight_duration


func separate_from_enemy(other_enemy) -> void:
	if not is_alive() or not _is_active_enemy_target(other_enemy):
		return
	_push_self_out_of_rect(other_enemy.get_interaction_rect(), enemy_separation_strength)


func try_accidental_enemy_hit(other_enemy) -> void:
	if not is_attacking or not attack_has_hit:
		return
	if not _is_active_enemy_target(other_enemy) or other_enemy == current_target:
		return
	if accidental_hit_targets.has(other_enemy):
		return
	if not _get_attack_rect().intersects(other_enemy.get_interaction_rect()):
		return
	accidental_hit_targets.append(other_enemy)
	start_fight_with(other_enemy)
	other_enemy.start_fight_with(self)
	other_enemy.take_damage(attack_damage, false, global_position)


func _get_target_rect(target: Node2D) -> Rect2:
	if target.has_method("get_hurt_rect"):
		return target.get_hurt_rect()
	if target.has_method("get_interaction_rect"):
		return target.get_interaction_rect()
	return Rect2(target.global_position - Vector2(54.0, 44.0) * 0.5, Vector2(54.0, 44.0))


func _resolve_collisions() -> void:
	_resolve_player_collision()
	for shrimp in _get_active_shrimps():
		if not is_instance_valid(shrimp):
			continue
		if shrimp.has_method("handle_player_collision"):
			shrimp.handle_player_collision(self, swim_velocity)
		_push_self_out_of_rect(shrimp.get_interaction_rect() if shrimp.has_method("get_interaction_rect") else Rect2(shrimp.global_position - Vector2.ONE * 14.0, Vector2.ONE * 28.0))


func _resolve_player_collision() -> void:
	if not is_instance_valid(player):
		return
	var player_rect: Rect2 = player.get_hurt_rect() if player.has_method("get_hurt_rect") else Rect2(player.global_position - Vector2(54.0, 44.0) * 0.5, Vector2(54.0, 44.0))
	_push_self_out_of_rect(player_rect)


func _push_self_out_of_rect(target_rect: Rect2, push_strength := -1.0) -> void:
	var my_rect := get_interaction_rect()
	if not my_rect.intersects(target_rect):
		return
	var my_center := my_rect.get_center()
	var target_center := target_rect.get_center()
	var overlap_x := minf(my_rect.end.x, target_rect.end.x) - maxf(my_rect.position.x, target_rect.position.x)
	var overlap_y := minf(my_rect.end.y, target_rect.end.y) - maxf(my_rect.position.y, target_rect.position.y)
	if overlap_x <= 0.0 or overlap_y <= 0.0:
		return
	if overlap_x < overlap_y:
		var direction_x := signf(my_center.x - target_center.x)
		if is_zero_approx(direction_x):
			direction_x = 1.0
		position.x += direction_x * overlap_x * _get_push_strength(push_strength)
		swim_velocity.x = maxf(absf(swim_velocity.x), 16.0) * direction_x
	else:
		var direction_y := signf(my_center.y - target_center.y)
		if is_zero_approx(direction_y):
			direction_y = -1.0
		position.y += direction_y * overlap_y * _get_push_strength(push_strength)
		swim_velocity.y = maxf(absf(swim_velocity.y), 16.0) * direction_y
	if ground_y < INF:
		position.y = minf(position.y, ground_y - collision_size.y * 0.65)


func _get_push_strength(push_strength: float) -> float:
	return enemy_push_strength if push_strength < 0.0 else push_strength


func _update_facing_from_target_or_velocity() -> void:
	if is_instance_valid(current_target):
		var target_delta_x := current_target.global_position.x - global_position.x
		if absf(target_delta_x) > 10.0:
			facing_direction = -signf(target_delta_x)
			return
	if absf(swim_velocity.x) > 18.0:
		facing_direction = -signf(swim_velocity.x)


func _is_active_enemy_target(enemy) -> bool:
	if not is_instance_valid(enemy) or enemy == self:
		return false
	if enemy.has_method("is_alive") and not enemy.is_alive():
		return false
	return enemy.has_method("get_interaction_rect") and enemy.has_method("take_damage")


func _draw() -> void:
	if is_dying:
		_draw_death_particles()
		_draw_floating_numbers()
		return

	var float_offset := Vector2(0.0, sin(animation_time * 4.5) * 2.4)
	if is_attacking:
		_draw_attack_frame(float_offset)
	else:
		_draw_textured_enemy(float_offset)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if health_bar_time > 0.0:
		_draw_health_bar()
	_draw_floating_numbers()


func _draw_textured_enemy(float_offset: Vector2) -> void:
	var body_size := body_texture.get_size()
	var tail_size := tail_texture.get_size()
	var visual_scale := Vector2(facing_direction * sprite_scale, sprite_scale)
	var tail_angle := sin(animation_time * 9.0) * 0.28
	var tail_pivot := _get_tail_pivot(body_size, float_offset)
	var draw_color := Color.WHITE.lerp(Color(2.2, 2.2, 2.2, 1.0), clampf(damage_flash_time / DAMAGE_FLASH_HOLD, 0.0, 1.0))

	draw_set_transform(tail_pivot, tail_angle * facing_direction, visual_scale)
	draw_texture_rect(tail_texture, Rect2(tail_size * TAIL_TEXTURE_ORIGIN_RATIO, tail_size), false, draw_color)

	draw_set_transform(float_offset, 0.0, visual_scale)
	draw_texture_rect(body_texture, Rect2(-body_size * 0.5, body_size), false, draw_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if is_golden:
		_draw_golden_sparkles(body_size * sprite_scale)


func _draw_attack_frame(float_offset: Vector2) -> void:
	var frame_index := clampi(int(attack_time / maxf(attack_frame_time, 0.01)), 0, attack_frames.size() - 1)
	var attack_texture := attack_frames[frame_index]
	var frame_size := attack_texture.get_size()
	var body_size := body_texture.get_size()
	var tail_size := tail_texture.get_size()
	var visual_scale := Vector2(facing_direction * sprite_scale, sprite_scale)
	var tail_angle := sin(animation_time * 12.0) * 0.34
	var tail_pivot := _get_tail_pivot(body_size, float_offset)
	var draw_color := Color.WHITE.lerp(Color(2.2, 2.2, 2.2, 1.0), clampf(damage_flash_time / DAMAGE_FLASH_HOLD, 0.0, 1.0))

	draw_set_transform(tail_pivot, tail_angle * facing_direction, visual_scale)
	draw_texture_rect(tail_texture, Rect2(tail_size * TAIL_TEXTURE_ORIGIN_RATIO, tail_size), false, draw_color)

	draw_set_transform(float_offset, 0.0, visual_scale)
	draw_texture_rect(attack_texture, Rect2(-frame_size * 0.5, frame_size), false, draw_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if is_golden:
		_draw_golden_sparkles(frame_size * sprite_scale)


func _get_tail_pivot(body_size: Vector2, float_offset: Vector2) -> Vector2:
	return Vector2(
		body_size.x * TAIL_ATTACH_RATIO.x * sprite_scale * facing_direction,
		body_size.y * TAIL_ATTACH_RATIO.y * sprite_scale
	) + float_offset


func _draw_golden_sparkles(draw_size: Vector2) -> void:
	for index in 4:
		var phase := animation_time * 1.7 + float(index) * TAU * 0.25
		var sparkle_position := Vector2(
			cos(phase) * draw_size.x * 0.58,
			sin(phase * 1.3) * draw_size.y * 0.36
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


func _draw_health_bar() -> void:
	var bar_position := Vector2(-HEALTH_BAR_SIZE.x * 0.5, -collision_size.y * 0.7)
	var fill_width := HEALTH_BAR_SIZE.x * clampf(health / maxf(max_health, 1.0), 0.0, 1.0)
	draw_rect(Rect2(bar_position - Vector2.ONE, HEALTH_BAR_SIZE + Vector2.ONE * 2.0), Color("#03131f"))
	draw_rect(Rect2(bar_position, HEALTH_BAR_SIZE), Color("#12324a"))
	draw_rect(Rect2(bar_position + Vector2.ONE, Vector2(maxf(fill_width - 2.0, 0.0), HEALTH_BAR_SIZE.y - 2.0)), Color("#ff5f5a"))


func _spawn_damage_number(damage: float, is_critical := false) -> void:
	floating_numbers.append({
		"text": str(int(ceilf(damage))),
		"is_critical": is_critical,
		"position": Vector2(randf_range(-12.0, 12.0), -collision_size.y * 0.85),
		"velocity": Vector2(randf_range(-18.0, 18.0), randf_range(-95.0, -70.0)),
		"life": DAMAGE_NUMBER_TIME,
		"max_life": DAMAGE_NUMBER_TIME,
		"scale": 1.15 if is_critical else 0.95
	})


func _update_floating_numbers(delta: float) -> void:
	for number in floating_numbers:
		var velocity: Vector2 = number["velocity"]
		var number_position: Vector2 = number["position"]
		number_position += velocity * delta
		velocity.y += 180.0 * delta
		number["position"] = number_position
		number["velocity"] = velocity
		number["life"] -= delta
	floating_numbers = floating_numbers.filter(func(number): return number["life"] > 0.0)


func _draw_floating_numbers() -> void:
	for number in floating_numbers:
		var alpha: float = clampf(number["life"] / number["max_life"], 0.0, 1.0)
		var font_size := int(11.0 * number["scale"])
		var text: String = number["text"]
		var text_size := DAMAGE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		var text_position: Vector2 = number["position"] - Vector2(text_size.x * 0.5, 0.0)
		var text_color := Color("#ff4a3d", alpha) if number["is_critical"] else Color("#ffd65a", alpha)
		draw_string(DAMAGE_FONT, text_position + Vector2.ONE, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color("#06121c", alpha))
		draw_string(DAMAGE_FONT, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, text_color)


func _spawn_death_particles() -> void:
	var colors := [Color("#1a5a21"), Color("#39a837"), Color("#fdde53"), Color("#0b2410")]
	if variant_id != "normal":
		colors = [variant_color.darkened(0.35), variant_color, variant_color.lightened(0.25), Color("#0b2410")]
	if is_golden:
		colors = [GOLDEN_DARK, GOLDEN_MID, GOLDEN_LIGHT, Color("#fff0a4")]
	for index in 26:
		death_particles.append({
			"position": Vector2(randf_range(-collision_size.x * 0.35, collision_size.x * 0.35), randf_range(-collision_size.y * 0.35, collision_size.y * 0.35)),
			"velocity": Vector2(randf_range(-95.0, 95.0), randf_range(-120.0, 35.0)),
			"life": DEATH_PARTICLE_TIME,
			"max_life": DEATH_PARTICLE_TIME,
			"size": randf_range(2.5, 6.0),
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


func _setup_sounds() -> void:
	if attack_sound_player == null:
		attack_sound_player = AudioStreamPlayer.new()
		attack_sound_player.name = "AttackSound"
		attack_sound_player.stream = ATTACK_SOUND_STREAM
		attack_sound_player.bus = "Master"
		add_child(attack_sound_player)
	if hit_sound_player == null:
		hit_sound_player = AudioStreamPlayer.new()
		hit_sound_player.name = "HitSound"
		hit_sound_player.stream = HIT_SOUND_STREAM
		hit_sound_player.bus = "Master"
		add_child(hit_sound_player)


func _play_attack_sound() -> void:
	if not _can_play_shared_sound(true):
		return
	if attack_sound_player == null:
		_setup_sounds()
	attack_sound_player.stop()
	attack_sound_player.volume_db = linear_to_db(_get_distance_volume(attack_sound_volume))
	attack_sound_player.pitch_scale = randf_range(0.92, 1.08)
	attack_sound_player.play()
	last_shared_attack_sound_time = _get_sound_time()


func _play_hit_sound() -> void:
	if not _can_play_shared_sound(false):
		return
	if hit_sound_player == null:
		_setup_sounds()
	hit_sound_player.stop()
	hit_sound_player.volume_db = linear_to_db(_get_distance_volume(hit_sound_volume))
	hit_sound_player.pitch_scale = 1.0
	hit_sound_player.play()
	last_shared_hit_sound_time = _get_sound_time()


func _can_play_shared_sound(is_attack_sound: bool) -> bool:
	if not _is_close_enough_for_sound():
		return false
	var now := _get_sound_time()
	if is_attack_sound:
		return now - last_shared_attack_sound_time >= shared_attack_sound_cooldown
	return now - last_shared_hit_sound_time >= shared_hit_sound_cooldown


func _is_close_enough_for_sound() -> bool:
	if not is_instance_valid(player):
		return false
	return global_position.distance_to(player.global_position) <= sound_audible_radius


func _get_distance_volume(base_volume: float) -> float:
	if not is_instance_valid(player):
		return 0.001
	var distance := global_position.distance_to(player.global_position)
	var distance_factor := clampf(1.0 - distance / maxf(sound_audible_radius, 1.0), 0.0, 1.0)
	var softened_factor := lerpf(0.25, 1.0, distance_factor)
	return maxf(clampf(base_volume, 0.0, 1.0) * softened_factor, 0.001)


func _get_sound_time() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _make_variant_texture(source_texture: Texture2D, target_color: Color, golden := false) -> Texture2D:
	var image := source_texture.get_image()
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if not _is_fish_recolor_pixel(color):
				continue
			image.set_pixel(x, y, _fish_color_to_variant(color, target_color, golden))
	return ImageTexture.create_from_image(image)


func _is_fish_recolor_pixel(color: Color) -> bool:
	if color.a <= 0.0:
		return false
	var brightness := maxf(color.r, maxf(color.g, color.b))
	if brightness < 0.16:
		return false
	if color.r > color.g * 1.45 and color.r > color.b * 1.45 and color.g < 0.35:
		return false
	return true


func _fish_color_to_variant(color: Color, target_color: Color, golden := false) -> Color:
	var brightness := maxf(color.r, maxf(color.g, color.b))
	var shaded_color := target_color.darkened(0.42).lerp(target_color, clampf(brightness * 1.35, 0.0, 1.0))
	if golden:
		shaded_color = GOLDEN_DARK.lerp(GOLDEN_MID, clampf(brightness * 1.4, 0.0, 1.0))
		if brightness > 0.72:
			shaded_color = shaded_color.lerp(GOLDEN_LIGHT, clampf((brightness - 0.72) / 0.28, 0.0, 1.0))
	shaded_color.a = color.a
	return shaded_color
