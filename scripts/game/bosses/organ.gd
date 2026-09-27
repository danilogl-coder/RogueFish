class_name Organ
extends BossPart
## A vital organ inside the Titanacon. It never dies by itself: every hit is
## forwarded to the Titanacon (marked as an inside hit) with a multiplier.

var sheet := "organ_heart"
var sprite_scale := 1.5
var _t := 0.0
var _frames := 4


func _ready() -> void:
	contact_damage = 0.0
	light_radius = 70.0
	sprite = Art.sprite("creatures/" + sheet)
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	_frames = sprite.hframes
	add_child(sprite)


func take_damage(amount: float, info := {}) -> float:
	if owner_boss == null or owner_boss.dead:
		return 0.0
	flash_t = 0.08
	var i2: Dictionary = info.duplicate()
	i2["organ"] = true
	var d: float = owner_boss.take_damage(amount * damage_share, i2)
	if d > 0.0:
		game.damage_number(position + Vector2(0, -radius - 4), d, info.get("crit", false), Color("ff8a9a"))
	return d


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if dead:
		return
	_t += delta
	# beats faster as the Titanacon weakens
	var bpm := 1.6 + (1.0 - owner_boss.hp / maxf(owner_boss.max_hp, 1.0)) * 2.5
	sprite.frame = int(_t * bpm * _frames) % _frames
	flash_t -= delta
	sprite.modulate = Color(3, 3, 3) if flash_t > 0.0 else Color.WHITE
