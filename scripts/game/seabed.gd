class_name Seabed
extends Node2D
## Draws the seafloor following DB.floor_at(x) with 4 px texture slices, so the
## terrain can rise into the reef and plunge into the abyssal trench.

const SLICE := 4.0


func _ready() -> void:
	z_index = -30
	z_as_relative = false


func _draw() -> void:
	var tex := Art.tex("env/seabed")
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var deep := Color("2a1c24")
	var x := -80.0
	while x < DB.WORLD_W + 80.0:
		var y := roundf(DB.floor_at(x + SLICE * 0.5)) - 13.0
		var sx := fposmod(x, tw)
		draw_texture_rect_region(tex, Rect2(x, y, SLICE, th), Rect2(sx, 0, SLICE, th))
		draw_rect(Rect2(x, y + th - 1.0, SLICE, DB.WORLD_H + 400.0 - y), deep)
		x += SLICE
