class_name OneShotFx
extends Sprite2D
## Plays a horizontal sprite sheet once and frees itself.

var fps := 16.0
var _t := 0.0


func setup(sheet: String, p_fps := 16.0) -> void:
	texture = Art.tex(sheet)
	hframes = maxi(1, Art.frames(sheet))
	fps = p_fps


func _process(delta: float) -> void:
	_t += delta
	var f := int(_t * fps)
	if f >= hframes:
		queue_free()
		return
	frame = f
