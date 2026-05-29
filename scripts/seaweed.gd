extends Node2D

@export var sprite_scale := 2.0
@export var max_health := 100.0
@export var xp_per_health := 0.2

var damage_font: Font = preload("res://assets/fonts/PressStart2P-Regular.ttf")
var animation_time := 0.0
var animation_offset := 0.0
var health := max_health
var xp_pool := 0.0
var damage_number_pool := 0.0
var damage_number_cooldown := 0.0
var particles: Array[Dictionary] = []
var floating_numbers: Array[Dictionary] = []
var is_depleted := false
var health_bar_time := 0.0

signal depleted(weed)

const FRAME_TIME := 0.18
const FRAME_SEQUENCE := [0, 1, 2, 1]
const SOURCE_REGION := Rect2(40.0, 50.0, 28.0, 70.0)
const HEALTH_BAR_SIZE := Vector2(46.0, 7.0)
const PARTICLE_TIME := 0.7
const DAMAGE_NUMBER_TIME := 0.65
const DAMAGE_NUMBER_INTERVAL := 0.12
const FRAMES: Array[Texture2D] = [
	preload("res://assets/seaweed/seaweed_1.png"),
	preload("res://assets/seaweed/seaweed_2.png"),
	preload("res://assets/seaweed/seaweed_3.png")
]


func _ready() -> void:
	animation_offset = randf_range(0.0, FRAME_TIME * FRAME_SEQUENCE.size())
	health = max_health


func _process(delta: float) -> void:
	animation_time += delta
	health_bar_time = maxf(health_bar_time - delta, 0.0)
	damage_number_cooldown = maxf(damage_number_cooldown - delta, 0.0)
	_update_floating_numbers(delta)
	if is_depleted:
		_update_particles(delta)
	queue_redraw()


func take_damage(amount: float, is_critical := false) -> int:
	if is_depleted:
		return 0

	health_bar_time = 0.45
	var damage := minf(health, amount)
	health -= damage
	_queue_damage_number(damage, is_critical)
	xp_pool += damage * xp_per_health
	var gained_xp := int(floorf(xp_pool))
	xp_pool -= float(gained_xp)

	if health <= 0.0:
		health = 0.0
		_deplete()
	return gained_xp


func is_consumable() -> bool:
	return not is_depleted


func get_interaction_rect() -> Rect2:
	var display_size := SOURCE_REGION.size * sprite_scale
	return Rect2(global_position + Vector2(-display_size.x * 0.5, -display_size.y), display_size)


func _draw() -> void:
	var display_size := SOURCE_REGION.size * sprite_scale
	if not is_depleted:
		var frame_step := int((animation_time + animation_offset) / FRAME_TIME) % FRAME_SEQUENCE.size()
		var frame := FRAMES[FRAME_SEQUENCE[frame_step]]
		draw_texture_rect_region(
			frame,
			Rect2(Vector2(-display_size.x * 0.5, -display_size.y), display_size),
			SOURCE_REGION
		)
		if health_bar_time > 0.0:
			_draw_health_bar(display_size)

	_draw_particles()
	_draw_floating_numbers()


func _draw_health_bar(display_size: Vector2) -> void:
	var bar_position := Vector2(-HEALTH_BAR_SIZE.x * 0.5, -display_size.y - 12.0)
	var fill_width := HEALTH_BAR_SIZE.x * clampf(health / maxf(max_health, 1.0), 0.0, 1.0)
	draw_rect(Rect2(bar_position - Vector2(2.0, 2.0), HEALTH_BAR_SIZE + Vector2(4.0, 4.0)), Color("#03131f"))
	draw_rect(Rect2(bar_position, HEALTH_BAR_SIZE), Color("#12324a"))
	draw_rect(Rect2(bar_position + Vector2(1.0, 1.0), Vector2(maxf(fill_width - 2.0, 0.0), HEALTH_BAR_SIZE.y - 2.0)), Color("#7bd84f"))


func _deplete() -> void:
	is_depleted = true
	_spawn_particles()
	depleted.emit(self)


func _spawn_particles() -> void:
	var colors := [Color("091704ff"), Color("#185c51"), Color("1e1600ff"), Color("#0d2d3c")]
	for index in 22:
		particles.append({
			"position": Vector2(randf_range(-18.0, 18.0), randf_range(-96.0, -12.0)),
			"velocity": Vector2(randf_range(-70.0, 70.0), randf_range(-130.0, -25.0)),
			"life": PARTICLE_TIME,
			"max_life": PARTICLE_TIME,
			"size": randf_range(3.0, 7.0),
			"color": colors.pick_random()
		})


func _queue_damage_number(damage: float, is_critical := false) -> void:
	damage_number_pool += damage
	if damage_number_pool < 1.0 or damage_number_cooldown > 0.0:
		return

	var amount := int(floorf(damage_number_pool))
	damage_number_pool -= float(amount)
	damage_number_cooldown = DAMAGE_NUMBER_INTERVAL
	_spawn_damage_number(amount, is_critical)


func _spawn_damage_number(amount: int, is_critical := false) -> void:
	floating_numbers.append({
		"text": str(amount),
		"is_critical": is_critical,
		"position": Vector2(randf_range(-18.0, 18.0), randf_range(-96.0, -72.0)),
		"velocity": Vector2(randf_range(-18.0, 18.0), randf_range(-125.0, -90.0) if is_critical else randf_range(-95.0, -70.0)),
		"life": DAMAGE_NUMBER_TIME,
		"max_life": DAMAGE_NUMBER_TIME,
		"scale": randf_range(1.35, 1.55) if is_critical else randf_range(0.95, 1.15)
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


func _update_particles(delta: float) -> void:
	for particle in particles:
		var velocity: Vector2 = particle["velocity"]
		var particle_position: Vector2 = particle["position"]
		particle_position += velocity * delta
		velocity.y += 240.0 * delta
		particle["position"] = particle_position
		particle["velocity"] = velocity
		particle["life"] -= delta
	particles = particles.filter(func(particle): return particle["life"] > 0.0)
	if particles.is_empty() and floating_numbers.is_empty():
		queue_free()


func _draw_particles() -> void:
	for particle in particles:
		var alpha: float = clampf(particle["life"] / particle["max_life"], 0.0, 1.0)
		var color: Color = particle["color"]
		color.a = alpha
		var pixel_size: float = particle["size"] * alpha
		draw_rect(Rect2(particle["position"] - Vector2.ONE * pixel_size * 0.5, Vector2.ONE * pixel_size), color)


func _draw_floating_numbers() -> void:
	for number in floating_numbers:
		var alpha: float = clampf(number["life"] / number["max_life"], 0.0, 1.0)
		var font_size := int(13.0 * number["scale"])
		var text: String = number["text"]
		var text_size := damage_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		var text_position: Vector2 = number["position"] - Vector2(text_size.x * 0.5, 0.0)
		var shadow_color := Color("#06121c", alpha)
		var text_color := Color("#ff4a3d", alpha) if number["is_critical"] else Color("#ffd65a", alpha)
		draw_string(damage_font, text_position + Vector2(2.0, 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, shadow_color)
		draw_string(damage_font, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, text_color)
