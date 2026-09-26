class_name Burst
extends Node2D
## Lightweight particle burst drawn from the particles sheet (no GPU particles
## so it batches well on low-end phones).
## kinds: 0 bubble,1 tiny bubble,2 red chunk,3 white chunk,4 spark,5 ink,6 poison,7 glow

var parts: Array = []
var _tex: Texture2D


func emit(kinds: Array, amount: int, speed: float, life: float) -> void:
	_tex = Art.tex("fx/particles")
	for i in amount:
		var k: int = kinds[i % kinds.size()]
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * speed * randf_range(0.4, 1.0)
		if k <= 1:
			v.y -= speed * 0.4
		parts.append({"k": k, "p": Vector2.ZERO, "v": v, "t": 0.0, "life": life * randf_range(0.6, 1.2)})


func _process(delta: float) -> void:
	var any := false
	for p in parts:
		p.t += delta
		if p.t < p.life:
			any = true
			p.v *= pow(0.08, delta)
			if p.k <= 1:
				p.v.y -= 40.0 * delta
			elif p.k <= 3:
				p.v.y += 30.0 * delta
			p.p += p.v * delta
	if not any:
		queue_free()
	queue_redraw()


func _draw() -> void:
	for p in parts:
		if p.t >= p.life:
			continue
		var a: float = 1.0 - clampf((p.t - p.life * 0.6) / (p.life * 0.4), 0.0, 1.0)
		draw_texture_rect_region(_tex, Rect2(p.p.round() - Vector2(3, 3), Vector2(6, 6)), Rect2(p.k * 6, 0, 6, 6), Color(1, 1, 1, a))
