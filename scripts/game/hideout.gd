class_name Hideout
extends Node2D
## Cave or kelp thicket. The front layer is drawn above the player and fades
## when the player is inside, where predators lose track of them.

var game
var kind := "cave"
var half_width := 50.0
var back: Sprite2D
var front: Sprite2D
var _inside := false
var _t := 0.0


func _ready() -> void:
	if kind == "cave":
		half_width = 62.0
		back = _mk("env/cave_back", -26)
		front = _mk("env/cave_front", 14)
		back.position = Vector2(0, -36 + 2)
		front.position = Vector2(0, -36 + 2)
	else:
		half_width = 40.0
		front = _mk("env/thicket", 14)
		front.hframes = 2
		front.position = Vector2(0, -32 + 3)


func _mk(path: String, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Art.tex(path)
	s.z_index = z
	s.z_as_relative = false
	add_child(s)
	return s


func contains(p: Vector2) -> bool:
	var local := p - position
	if kind == "cave":
		var dx := local.x / 44.0
		var dy := (local.y + 2.0) / 46.0
		return local.y <= 4.0 and dx * dx + dy * dy <= 1.0
	return absf(local.x) < 38.0 and local.y > -56.0 and local.y < 6.0


func _process(delta: float) -> void:
	_t += delta
	var inside: bool = game != null and game.player != null and contains(game.player.position)
	var target := 0.45 if inside else 1.0
	front.modulate.a = lerpf(front.modulate.a, target, 1.0 - pow(0.02, delta))
	if kind == "thicket":
		front.frame = int(_t * 1.6) % 2
		front.skew = sin(_t * 1.3) * 0.04
