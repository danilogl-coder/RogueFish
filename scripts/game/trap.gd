class_name Trap
extends Node2D
## A sticky trap left by the player: bursts into goo when an enemy touches it.

var game
var sheet := "fx/guts"
var damage := 18.0
var radius := 26.0
var slow := 0.6
var life := 9.0
var source := "trap"
var _t := 0.0
var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Art.sprite(sheet)
	add_child(_sprite)
	z_index = -1
	scale = Vector2.ZERO


func _physics_process(delta: float) -> void:
	_t += delta
	scale = Vector2.ONE * minf(1.0, _t / 0.2)
	if _sprite.hframes > 1:
		_sprite.frame = int(_t * 4.0) % _sprite.hframes
	if _t >= life:
		_burst()
		return
	for c in game.grid.query(position, 10.0):
		if not c.dead and c.hostile_now():
			_burst()
			return


func _burst() -> void:
	game.fx("fx/poison_cloud", position, 12.0, radius / 16.0, Color(0.9, 0.7, 0.8, 0.9))
	for c in game.creatures_in_radius(position, radius):
		if c.dead:
			continue
		var r: Array = game.roll_damage(damage)
		c.take_damage(r[0], {"crit": r[1], "source": source, "slow": slow, "slow_time": 2.0})
	var a := AreaEffect.new().setup_cloud("fx/mucus", position, radius * 0.8, 2.0, damage * 0.15, slow, false)
	a.source = source
	game.spawn_area(a)
	Sfx.play("ink", -8.0)
	queue_free()
