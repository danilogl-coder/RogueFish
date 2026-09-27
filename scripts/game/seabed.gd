class_name Seabed
extends Node2D
## Draws the seafloor from the baked terrain chunks (tools/art/terrain.py).
## The chunk textures follow the same heightmap as DB.floor_at(), and a thin
## front strip (the lit lip of the sand, pebbles and tufts) is drawn by a
## second node in front of props so their bases sit *in* the ground.

var front := false


func _ready() -> void:
	z_index = -10 if front else -30
	z_as_relative = false


func _draw() -> void:
	var chunks: Array = DB.terrain.get("chunks", [])
	if chunks.is_empty():
		_draw_fallback()
		return
	var deep := Color(String(DB.terrain.get("deep", "#161120")))
	for i in chunks.size():
		var c: Dictionary = chunks[i]
		var x := float(c.x)
		if front:
			draw_texture(Art.tex("terrain/front_%02d" % i), Vector2(x, float(c.fy)))
		else:
			draw_texture(Art.tex("terrain/back_%02d" % i), Vector2(x, float(c.y)))
			var bottom := float(c.y) + float(c.h)
			draw_rect(Rect2(x, bottom - 1.0, float(c.w), DB.WORLD_H + 400.0 - bottom), deep)


func _draw_fallback() -> void:
	if front:
		return
	var deep := Color("2a1c24")
	var x := -80.0
	while x < DB.WORLD_W + 80.0:
		var y := roundf(DB.floor_at(x + 2.0))
		draw_rect(Rect2(x, y, 4.0, DB.WORLD_H + 400.0 - y), deep)
		x += 4.0
