extends Control

@export var level := 1
@export var experience := 0
@export var experience_to_next := 20

var pixel_font: Font = preload("res://assets/fonts/PressStart2P-Regular.ttf")

signal level_up(new_level: int)


const OUTER_DARK := Color("#032033")
const OUTER_BLUE := Color("#083553")
const BAR_BACK := Color("#0a4164")
const BAR_INNER := Color("#0d5278")
const BAR_LINE := Color("#1e83a7")
const BAR_GLOW := Color("#125f88")
const CORNER_GOLD := Color("#e6a13a")
const TEXT_YELLOW := Color("#ffd65a")
const TEXT_WHITE := Color("#f7fbff")
const TEXT_SHADOW := Color("#06121c")


func add_experience(amount: int) -> void:
	if amount <= 0:
		return

	experience += amount
	while experience >= experience_to_next:
		experience -= experience_to_next
		level += 1
		experience_to_next = int(ceil(float(experience_to_next) * 1.35))
		level_up.emit(level)
	queue_redraw()


func apply_layout(screen_size: Vector2) -> void:
	var bar_width := clampf(screen_size.x * 0.82, 520.0, 960.0)
	var bar_height := clampf(screen_size.y * 0.095, 56.0, 86.0)
	size = Vector2(bar_width, bar_height)
	position = Vector2((screen_size.x - bar_width) * 0.5, screen_size.y * 0.055)
	queue_redraw()


func _draw() -> void:
	var pixel := maxf(3.0, roundf(size.y / 18.0))
	var outer_rect := Rect2(Vector2(size.y * 0.23, size.y * 0.12), Vector2(size.x - size.y * 0.26, size.y * 0.72))
	var track_rect := outer_rect.grow(-pixel * 2.0)
	track_rect.position.x += size.y * 0.58
	track_rect.size.x -= size.y * 0.72
	var progress := clampf(float(experience) / maxf(float(experience_to_next), 1.0), 0.0, 1.0)

	_draw_panel(outer_rect, pixel)
	_draw_track(track_rect, progress, pixel)
	

	var level_font_size := int(clampf(size.y * 0.30, 24.0, 32.0))
	var xp_font_size := int(clampf(size.y * 0.34, 18.0, 30.0))
	var level_box := Rect2(Vector2(size.y * 0.35, size.y * 0.20), Vector2(size.y * 0.42, size.y * 0.55))
	_draw_text_inside_rect(str(level), level_box, level_font_size, TEXT_WHITE)
	_draw_centered_pixel_text("%d/%d" % [experience, experience_to_next], outer_rect.get_center() + Vector2(0.0, xp_font_size * 0.40), xp_font_size, TEXT_YELLOW)


func _draw_panel(rect: Rect2, pixel: float) -> void:
	draw_rect(rect, OUTER_DARK)
	draw_rect(rect.grow(-pixel), OUTER_BLUE)
	draw_rect(Rect2(rect.position + Vector2(pixel * 2.0, pixel * 2.0), rect.size - Vector2(pixel * 4.0, pixel * 4.0)), BAR_BACK)
	draw_rect(Rect2(rect.position + Vector2(pixel * 3.0, pixel * 3.0), Vector2(rect.size.x - pixel * 6.0, pixel)), BAR_GLOW)
	draw_rect(Rect2(rect.position + Vector2(pixel * 2.0, rect.size.y - pixel * 3.0), Vector2(rect.size.x - pixel * 4.0, pixel)), OUTER_DARK)


func _draw_track(rect: Rect2, progress: float, pixel: float) -> void:
	draw_rect(rect.grow(pixel), OUTER_DARK)
	draw_rect(rect, BAR_INNER)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, pixel)), BAR_LINE)
	draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - pixel), Vector2(rect.size.x, pixel)), BAR_LINE)
	if progress > 0.0:
		var fill_rect := Rect2(rect.position + Vector2(pixel, pixel), Vector2((rect.size.x - pixel * 2.0) * progress, rect.size.y - pixel * 2.0))
		draw_rect(fill_rect, Color("#126f88"))
		draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, pixel)), Color("#2bb0c7"))
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




func _draw_pixel_text(text: String, text_position: Vector2, font_size: int, color: Color, shadow_offset := Vector2(2.0, 2.0)) -> void:
	draw_string(pixel_font, text_position + shadow_offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, TEXT_SHADOW)
	draw_string(pixel_font, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw_centered_pixel_text(text: String, center: Vector2, font_size: int, color: Color) -> void:
	var text_size := pixel_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	_draw_pixel_text(text, center - Vector2(text_size.x * 0.5, -text_size.y * 0.32), font_size, color, Vector2(3.0, 3.0))


func _draw_text_inside_rect(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var adjusted_size := font_size
	var text_size := pixel_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, adjusted_size)
	while text_size.x > rect.size.x and adjusted_size > 10:
		adjusted_size -= 1
		text_size = pixel_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, adjusted_size)

	var text_position := Vector2(
		rect.position.x + (rect.size.x - text_size.x) * 0.5,
		rect.position.y + rect.size.y * 0.5 + text_size.y * 0.32
	)
	_draw_pixel_text(text, text_position, adjusted_size, color, Vector2(4.0, 4.0))
