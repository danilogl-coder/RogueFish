class_name Chimney
extends Node2D
## Hydrothermal chimney of the "Fontes Hidrotermais" biome: it rumbles, glows
## and then erupts a column of superheated water that burns anything inside
## (creatures and the player alike). Characters born here are immune.

var game
var _t := 0.0
var _cd := 0.0
var _state := "idle"
const COLUMN_H := 150.0
const COLUMN_W := 26.0


func _ready() -> void:
	z_index = 2
	_cd = randf_range(2.0, 7.0)


func _physics_process(delta: float) -> void:
	_t += delta
	_cd -= delta
	match _state:
		"idle":
			if _cd <= 0.0:
				_state = "rumble"
				_cd = 1.2
		"rumble":
			if int(_t * 12.0) % 3 == 0:
				game.burst(position + Vector2(randf_range(-6, 6), -4), [1], 1, 20.0, 0.6)
			if _cd <= 0.0:
				_state = "erupt"
				_cd = 1.6
				if position.distance_to(game.player.position) < 360.0:
					game.shake(3.0)
					Sfx.play("explosion", -12.0)
		"erupt":
			var rect := Rect2(position.x - COLUMN_W * 0.5, position.y - COLUMN_H, COLUMN_W, COLUMN_H)
			if int(_t * 20.0) % 2 == 0:
				game.burst(position + Vector2(randf_range(-8, 8), -randf_range(10, COLUMN_H)), [5, 2, 1], 2, 50.0, 0.7)
				for c in game.creatures_in_radius(rect.get_center(), COLUMN_H * 0.6):
					if not c.dead and rect.has_point(c.position) and c.can_hit("chimney", 0.5) and c.def.get("biomes", []) != ["vents"]:
						c.take_damage(8.0, {"source": "", "color": Color("ff9a3c")})
			var p: Player = game.player
			if p.alive and rect.has_point(p.position) and not (p.traits and p.traits.heat_immune()):
				p.take_damage(10.0 * game.director.difficulty().dmg, null)
			if _cd <= 0.0:
				_state = "idle"
				_cd = randf_range(5.0, 9.0)
	queue_redraw()


func _draw() -> void:
	if _state == "rumble":
		var a := 0.3 + 0.3 * sin(_t * 30.0)
		draw_circle(Vector2(0, -4), 10.0, Color(1.0, 0.55, 0.2, a))
	elif _state == "erupt":
		var k := clampf(1.0 - _cd / 1.6, 0.0, 1.0)
		var hgt := COLUMN_H * minf(1.0, k * 4.0)
		var fade := clampf(_cd / 0.4, 0.0, 1.0)
		draw_rect(Rect2(-COLUMN_W * 0.5, -hgt, COLUMN_W, hgt), Color(0.95, 0.45, 0.15, 0.16 * fade))
		for i in 7:
			var y := -fmod(_t * 160.0 + i * 23.0, hgt)
			var w := COLUMN_W * (0.4 + 0.6 * (-y / COLUMN_H))
			draw_rect(Rect2(Vector2(-w * 0.5 + sin(_t * 9.0 + i) * 3.0, y - 6.0).round(), Vector2(w, 6).round()), Color(0.12, 0.08, 0.1, 0.5 * fade))
		draw_rect(Rect2(-4, -hgt, 8, hgt), Color(1.0, 0.8, 0.4, 0.22 * fade))
