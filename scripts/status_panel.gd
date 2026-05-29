extends Control

signal status_selected(status_id: String)

var pixel_font: Font = preload("res://assets/fonts/PressStart2P-Regular.ttf")
var pending_level := 1
var status_ranks: Dictionary = {}
var row_rects: Array[Rect2] = []
var hovered_index := -1

const MAX_STATUS_RANK := 5
const PANEL_DARK := Color("#031929")
const PANEL_BLUE := Color("#083553")
const PANEL_INNER := Color("#0a2c46")
const LINE_BLUE := Color("#126083")
const TEXT_LIGHT := Color("#d6d9df")
const TEXT_SHADOW := Color("#04111b")
const CORNER_GOLD := Color("#d59126")
const STATUS_ICONS := {
	"predator": preload("res://assets/status_icons/shark.png"),
	"prey": preload("res://assets/status_icons/fish.png"),
	"rogue": preload("res://assets/status_icons/jellyfish.png"),
	"coactive": preload("res://assets/status_icons/whale.png"),
	"social": preload("res://assets/status_icons/shrimp.png")
}

const OPTIONS := [
	{
		"id": "predator",
		"title": "PREDATOR",
		"color": Color("#e34a35"),
		"description": "Prioritizes physical damage and predator affinity."
	},
	{
		"id": "prey",
		"title": "PREY",
		"color": Color("#19b8bb"),
		"description": "Prioritizes dodge, speed and prey affinity."
	},
	{
		"id": "rogue",
		"title": "ROGUE",
		"color": Color("#9a5cff"),
		"description": "Prioritizes skill damage and rogue affinity."
	},
	{
		"id": "coactive",
		"title": "COACTIVE",
		"color": Color("#9aa6ad"),
		"description": "Prioritizes damage resistance and coactive affinity."
	},
	{
		"id": "social",
		"title": "SOCIAL",
		"color": Color("#f0a62f"),
		"description": "Prioritizes social skills, perception and social affinity."
	}
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func apply_layout(_screen_size: Vector2) -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	queue_redraw()


func open(new_level: int, new_status_ranks := {}) -> void:
	pending_level = new_level
	status_ranks = new_status_ranks.duplicate()
	visible = true
	hovered_index = -1
	queue_redraw()


func close() -> void:
	visible = false
	hovered_index = -1
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseMotion:
		_update_hover(event.position)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pick_option(event.position)
	if event is InputEventScreenTouch and event.pressed:
		_pick_option(event.position)


func _update_hover(pointer_position: Vector2) -> void:
	var new_hover := -1
	for index in row_rects.size():
		if row_rects[index].has_point(pointer_position):
			new_hover = index
			break
	if new_hover != hovered_index:
		hovered_index = new_hover
		queue_redraw()


func _pick_option(pointer_position: Vector2) -> void:
	for index in row_rects.size():
		if row_rects[index].has_point(pointer_position):
			var status_id: String = OPTIONS[index]["id"]
			if _get_status_rank(status_id) >= MAX_STATUS_RANK:
				return
			close()
			status_selected.emit(status_id)
			return


func _draw() -> void:
	if not visible:
		return

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.45))
	var pixel := maxf(3.0, roundf(size.y / 180.0))
	var panel_width := clampf(size.x * 0.72, 360.0, 560.0)
	var panel_height := clampf(size.y * 0.82, 430.0, 620.0)
	var panel := Rect2((size - Vector2(panel_width, panel_height)) * 0.5, Vector2(panel_width, panel_height))
	_draw_panel(panel, pixel)

	var title_size := int(clampf(panel_height * 0.04, 14.0, 14.0))
	_draw_pixel_text("Level %d - Choose a status" % pending_level, panel.position + Vector2(pixel * 7.0, pixel * 12.0), title_size, Color("#ffd65a"))

	var list := panel.grow(-pixel * 7.0)
	list.position.y += pixel * 13.0
	list.size.y -= pixel * 15.0
	_draw_rows(list, pixel)


func _draw_panel(rect: Rect2, pixel: float) -> void:
	draw_rect(rect, PANEL_DARK)
	draw_rect(rect.grow(-pixel), PANEL_BLUE)
	draw_rect(rect.grow(-pixel * 3.0), PANEL_INNER)
	draw_rect(Rect2(rect.position + Vector2(pixel * 4.0, pixel * 4.0), Vector2(rect.size.x - pixel * 8.0, pixel)), LINE_BLUE)
	draw_rect(Rect2(rect.position + Vector2(pixel * 4.0, rect.size.y - pixel * 5.0), Vector2(rect.size.x - pixel * 8.0, pixel)), LINE_BLUE)
	_draw_corner_marks(rect, pixel)


func _draw_corner_marks(rect: Rect2, pixel: float) -> void:
	var mark := pixel * 3.0
	draw_rect(Rect2(rect.position + Vector2(pixel, pixel), Vector2(mark, pixel)), CORNER_GOLD)
	draw_rect(Rect2(rect.position + Vector2(pixel, pixel), Vector2(pixel, mark)), CORNER_GOLD)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - mark - pixel, pixel), Vector2(mark, pixel)), CORNER_GOLD)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - pixel * 2.0, pixel), Vector2(pixel, mark)), CORNER_GOLD)
	draw_rect(Rect2(rect.position + Vector2(pixel, rect.size.y - pixel * 2.0), Vector2(mark, pixel)), CORNER_GOLD)
	draw_rect(Rect2(rect.position + Vector2(pixel, rect.size.y - mark - pixel), Vector2(pixel, mark)), CORNER_GOLD)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - mark - pixel, rect.size.y - pixel * 2.0), Vector2(mark, pixel)), CORNER_GOLD)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - pixel * 2.0, rect.size.y - mark - pixel), Vector2(pixel, mark)), CORNER_GOLD)


func _draw_rows(list: Rect2, pixel: float) -> void:
	row_rects.clear()
	var row_height := list.size.y / float(OPTIONS.size())
	for index in OPTIONS.size():
		var row := Rect2(list.position + Vector2(0.0, row_height * index), Vector2(list.size.x, row_height))
		row_rects.append(row)
		var option: Dictionary = OPTIONS[index]
		if index == hovered_index:
			var hovered_id: String = option["id"]
			if _get_status_rank(hovered_id) < MAX_STATUS_RANK:
				draw_rect(row.grow(-pixel), Color("#0d4264"))
		if index > 0:
			draw_rect(Rect2(row.position, Vector2(row.size.x, pixel)), LINE_BLUE)

		var option_color: Color = option["color"]
		var status_id: String = option["id"]
		var status_rank := _get_status_rank(status_id)
		if status_rank >= MAX_STATUS_RANK:
			option_color = option_color.darkened(0.45)

		var icon_size := minf(row_height * 0.62, 62.0)
		var icon_rect := Rect2(row.position + Vector2(pixel * 5.0, row_height * 0.16), Vector2(icon_size, icon_size))
		_draw_icon_box(icon_rect, pixel, option_color, status_id)
		_draw_rank_bar(icon_rect, pixel, option_color, status_rank)

		var title_size := int(clampf(row_height * 0.18, 13.0, 19.0))
		var desc_size := int(clampf(row_height * 0.14, 10.0, 15.0))
		var title_position := Vector2(icon_rect.end.x + pixel * 5.0, row.position.y + row_height * 0.38)
		_draw_pixel_text(option["title"], title_position, title_size, option_color)

		var desc_x := title_position.x + clampf(list.size.x * 0.28, 160.0, 130.0)
		var desc_width := row.end.x - desc_x - pixel * 3.0
		var lines := _wrap_text(option["description"], desc_width, desc_size)
		var line_y := row.position.y + row_height * 0.28
		for line in lines:
			_draw_pixel_text(line, Vector2(desc_x, line_y), desc_size, TEXT_LIGHT, Vector2(2.0, 2.0))
			line_y += desc_size + pixel * 1.6


func _draw_rank_bar(icon_rect: Rect2, pixel: float, color: Color, rank: int) -> void:
	var gap := pixel
	var square_size := floorf((icon_rect.size.x - gap * 4.0) / float(MAX_STATUS_RANK))
	var bar_y := icon_rect.end.y + pixel * 1.3
	for index in MAX_STATUS_RANK:
		var square := Rect2(
			Vector2(icon_rect.position.x + float(index) * (square_size + gap), bar_y),
			Vector2(square_size, square_size)
		)
		draw_rect(square, Color("#03121f"))
		draw_rect(square.grow(-pixel * 0.45), color if index < rank else Color("#12324a"))


func _draw_icon_box(rect: Rect2, pixel: float, color: Color, icon_id: String) -> void:
	draw_rect(rect, Color("#03121f"))
	draw_rect(rect.grow(-pixel), Color(color.r, color.g, color.b, 0.25))
	draw_rect(Rect2(rect.position + Vector2(pixel, pixel), Vector2(rect.size.x - pixel * 2.0, pixel)), color)
	draw_rect(Rect2(rect.position + Vector2(pixel, rect.size.y - pixel * 2.0), Vector2(rect.size.x - pixel * 2.0, pixel)), color)
	draw_rect(Rect2(rect.position + Vector2(pixel, pixel), Vector2(pixel, rect.size.y - pixel * 2.0)), color)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - pixel * 2.0, pixel), Vector2(pixel, rect.size.y - pixel * 2.0)), color)

	var icon_texture: Texture2D = STATUS_ICONS.get(icon_id)
	if icon_texture != null:
		draw_texture_rect(icon_texture, rect.grow(-pixel * 2.0), false)


func _wrap_text(text: String, max_width: float, font_size: int) -> Array[String]:
	var lines: Array[String] = []
	var current := ""
	for word in text.split(" "):
		var next_line := str(word) if current.is_empty() else current + " " + str(word)
		var next_width := pixel_font.get_string_size(next_line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		if next_width <= max_width or current.is_empty():
			current = next_line
		else:
			lines.append(current)
			current = str(word)
	if not current.is_empty():
		lines.append(current)
	return lines


func _draw_pixel_text(text: String, text_position: Vector2, font_size: int, color: Color, shadow_offset := Vector2(3.0, 3.0)) -> void:
	draw_string(pixel_font, text_position + shadow_offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, TEXT_SHADOW)
	draw_string(pixel_font, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _get_status_rank(status_id: String) -> int:
	return int(status_ranks.get(status_id, 0))
