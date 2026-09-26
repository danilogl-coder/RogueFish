class_name Darkness
extends CanvasLayer
## Screen-space darkness overlay. Depth, phase (wave/boss) and bosses change it;
## registered light sources punch soft holes into it.

var game
var rect: ColorRect
var mat: ShaderMaterial
var target := 0.0
var current := 0.0
var extra := 0.0
var tint := Color(0.01, 0.02, 0.07)
var tint_target := Color(0.01, 0.02, 0.07)


func _ready() -> void:
	layer = 5
	rect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/darkness.gdshader")
	rect.material = mat
	add_child(rect)


func _process(delta: float) -> void:
	if game == null or game.player == null:
		return
	var cam: Camera2D = game.camera
	var cc := cam.get_screen_center_position()
	var depth := clampf((cc.y - 260.0) / (1420.0 - 260.0), 0.0, 1.0)
	var abyss := 0.12 if DB.biome_at(cc.x).id == "abyss" else 0.0
	target = clampf(depth * 0.66 + abyss * 0.8 + extra, 0.0, 0.95)
	current = lerpf(current, target, 1.0 - pow(0.1, delta))
	tint = tint.lerp(tint_target, 1.0 - pow(0.2, delta))
	var size := rect.size
	var xf := get_viewport().get_canvas_transform()
	var lights := []
	var p: Player = game.player
	lights.append(_light(xf, p.global_position, p.st.get("light", 70.0), 1.0))
	for c in game.creatures:
		if lights.size() >= 16:
			break
		if is_instance_valid(c) and c.light_radius > 0.0:
			var sp: Vector2 = xf * c.global_position
			if sp.x > -80 and sp.y > -80 and sp.x < size.x + 80 and sp.y < size.y + 80:
				lights.append(_light(xf, c.light_pos(), c.light_radius, 0.9))
	for l in game.world.lights:
		if lights.size() >= 16:
			break
		if is_instance_valid(l.node):
			var sp2: Vector2 = xf * l.node.global_position
			if sp2.x > -80 and sp2.y > -80 and sp2.x < size.x + 80 and sp2.y < size.y + 80:
				lights.append(_light(xf, l.node.global_position, l.radius, l.power))
	var arr := PackedVector4Array()
	arr.resize(16)
	for i in lights.size():
		arr[i] = lights[i]
	mat.set_shader_parameter("lights", arr)
	mat.set_shader_parameter("light_count", lights.size())
	mat.set_shader_parameter("darkness", current)
	mat.set_shader_parameter("rect_size", size)
	mat.set_shader_parameter("tint", tint)


func _light(xf: Transform2D, world_pos: Vector2, radius: float, power: float) -> Vector4:
	var sp := xf * world_pos
	var zoom := xf.get_scale().x
	return Vector4(sp.x, sp.y, radius * zoom, power)
