class_name GameCamera
extends Camera2D
## Smooth follow with trauma-based screen shake.

var target: Node2D
var trauma := 0.0
var _noise_t := 0.0


func _ready() -> void:
	limit_left = 0
	limit_right = int(DB.WORLD_W)
	limit_top = -60
	limit_bottom = int(DB.WORLD_H) + 40
	position_smoothing_enabled = true
	position_smoothing_speed = 6.0
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	make_current()


func add_shake(amount: float) -> void:
	trauma = minf(trauma + amount * 0.08, 1.0)


func _physics_process(delta: float) -> void:
	if target and is_instance_valid(target):
		var lead: Vector2 = target.vel * 0.18 if "vel" in target else Vector2.ZERO
		var want: Vector2 = target.global_position + lead
		# never show much more than a strip of sediment below the local seafloor
		var half_h := get_viewport_rect().size.y * 0.5 / zoom.y
		want.y = minf(want.y, DB.floor_at(want.x) + 70.0 - half_h)
		global_position = want
	_noise_t += delta * 40.0
	trauma = maxf(trauma - delta * 1.6, 0.0)
	var s := trauma * trauma * 8.0
	offset = Vector2(sin(_noise_t * 1.1) , cos(_noise_t * 1.3)) * s
