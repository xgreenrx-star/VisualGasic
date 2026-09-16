@tool
extends Control
## Badge — small colored circle with a count number, used as an overlay
## for unread/notification indicators. Hides when `count` is 0.

@export var count: int = 3 : set = _set_count
@export var hide_when_zero: bool = true
@export var bg_color: Color = Color(0.85, 0.20, 0.25)
@export var text_color: Color = Color.WHITE
@export var max_display: int = 99  ## counts above this render as "99+"

func _ready() -> void:
	custom_minimum_size = Vector2(20, 20)

func _set_count(v: int) -> void:
	count = max(0, v)
	if hide_when_zero:
		visible = count > 0
	queue_redraw()

func _draw() -> void:
	if hide_when_zero and count <= 0:
		return
	var label: String
	if count > max_display:
		label = str(max_display) + "+"
	else:
		label = str(count)
	var font := ThemeDB.fallback_font
	var fs := int(size.y * 0.6)
	var text_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	var pad: float = 6.0
	var w: float = max(size.y, text_w + pad * 2.0)
	var h: float = size.y
	# Pill / circle backdrop.
	var radius: float = h * 0.5
	draw_circle(Vector2(radius, radius), radius, bg_color)
	if w > h:
		draw_circle(Vector2(w - radius, radius), radius, bg_color)
		draw_rect(Rect2(radius, 0, w - h, h), bg_color, true)
	# Centered text.
	draw_string(font, Vector2((w - text_w) * 0.5, h * 0.5 + fs * 0.35),
		label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, text_color)
