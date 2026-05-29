extends Node2D

@export_range(0.0, 1.0, 0.01) var background_music_volume := 0.10

@onready var ocean = $OceanBackground
@onready var platform = $Platform
@onready var seaweed_field = $SeaweedField
@onready var player = $Player

@onready var joystick = $Interface/Joystick
@onready var level_bar = $Interface/LevelBar
@onready var status_panel = $Interface/StatusPanel
@onready var camera: Camera2D = $Player/Camera

var previous_size := Vector2.ZERO
var pending_status_points := 0
var background_music_player: AudioStreamPlayer

const BACKGROUND_MUSIC_STREAM := preload("res://assets/audio/background_music.mp3")


func _ready() -> void:
	get_viewport().size_changed.connect(_layout_game)
	level_bar.level_up.connect(_on_level_up)
	status_panel.status_selected.connect(_on_status_selected)
	_setup_background_music()
	_layout_game()


func _exit_tree() -> void:
	get_tree().paused = false
	if background_music_player != null:
		background_music_player.stop()
		background_music_player.stream = null


func _physics_process(delta: float) -> void:
	if status_panel.visible:
		player.control_vector = Vector2.ZERO
		ocean.swim_speed = 0.0
		platform.scroll_speed = 0.0
		return

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
	seaweed_field.push_shrimps_near(player)
	var gained_xp: int = seaweed_field.consume_near(player, delta)
	level_bar.add_experience(gained_xp)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_open_debug_status_panel()


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
	level_bar.apply_layout(screen_size)
	status_panel.apply_layout(screen_size)
	seaweed_field.configure(screen_size, screen_size.y * 0.90, camera, platform)
	
	previous_size = screen_size


func _on_level_up(new_level: int) -> void:
	if not player.can_upgrade_any_status():
		return
	pending_status_points += 1
	if not status_panel.visible:
		_open_status_panel(new_level)


func _on_status_selected(status_id: String) -> void:
	if not player.apply_status_choice(status_id):
		if pending_status_points > 0 and player.can_upgrade_any_status():
			_open_status_panel(level_bar.level)
		return

	pending_status_points = maxi(pending_status_points - 1, 0)
	if pending_status_points > 0 and player.can_upgrade_any_status():
		_open_status_panel(level_bar.level)
	else:
		_close_status_panel()
	if not player.can_upgrade_any_status():
		pending_status_points = 0
		_close_status_panel()


func _open_debug_status_panel() -> void:
	if status_panel.visible or not player.can_upgrade_any_status():
		return
	pending_status_points += 1
	_open_status_panel(level_bar.level)


func _open_status_panel(panel_level: int) -> void:
	player.control_vector = Vector2.ZERO
	ocean.swim_speed = 0.0
	platform.scroll_speed = 0.0
	status_panel.open(panel_level, player.get_status_ranks())
	get_tree().paused = true


func _close_status_panel() -> void:
	status_panel.close()
	get_tree().paused = false


func _setup_background_music() -> void:
	background_music_player = AudioStreamPlayer.new()
	background_music_player.name = "BackgroundMusic"
	background_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	background_music_player.stream = BACKGROUND_MUSIC_STREAM
	background_music_player.bus = "Master"
	background_music_player.volume_db = linear_to_db(background_music_volume)
	add_child(background_music_player)

	if background_music_player.stream is AudioStreamWAV:
		var music_stream := background_music_player.stream as AudioStreamWAV
		music_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

	background_music_player.finished.connect(_restart_background_music)
	background_music_player.play()


func _restart_background_music() -> void:
	if background_music_player != null:
		background_music_player.play()
