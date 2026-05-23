extends Node2D

@onready var ocean = $OceanBackground
@onready var platform = $Platform
@onready var seaweed_field = $SeaweedField
@onready var player = $Player

@onready var joystick = $Interface/Joystick
@onready var camera: Camera2D = $Player/Camera

var previous_size := Vector2.ZERO


func _ready() -> void:
	get_viewport().size_changed.connect(_layout_game)
	_layout_game()


func _physics_process(_delta: float) -> void:
	var keyboard := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) -
			float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) -
			float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	).normalized()
	player.control_vector = keyboard if keyboard != Vector2.ZERO else joystick.direction
	var world_scroll_speed: float = player.get_world_scroll_speed()
	ocean.swim_speed = world_scroll_speed
	platform.scroll_speed = world_scroll_speed


func _layout_game() -> void:
	var screen_size := get_viewport_rect().size
	var previous_ratio := Vector2(0.39, 0.48)
	if previous_size.x > 0.0 and previous_size.y > 0.0:
		previous_ratio = player.position / previous_size

	ocean.set_viewport_size(screen_size)
	platform.configure(Rect2(0.0, screen_size.y * 0.90, screen_size.x, screen_size.y * 0.60))
	
	player.set_swim_area(Rect2(
		screen_size.x * 0.26,
		screen_size.y * 0.30,
		screen_size.x * 0.48,
		screen_size.y * 0.72
	))
	player.position = Vector2(
		clamp(screen_size.x * previous_ratio.x, screen_size.x * 0.30, screen_size.x * 0.70),
		clamp(screen_size.y * previous_ratio.y, screen_size.y * 0.34, screen_size.y * 0.86)
	)
	joystick.apply_layout(screen_size)
	seaweed_field.configure(screen_size, screen_size.y * 0.90, camera, platform)
	
	previous_size = screen_size
