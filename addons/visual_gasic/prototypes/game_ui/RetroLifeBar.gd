@tool
extends Control
## RetroLifeBar — classic green→yellow→red hue shift as health drops,
## with a thick black outline. Evokes Zelda / NES-era RPG HP bars.

@export var value: float = 100.0 : set = _set_value
@export var max_value: float = 100.0 : set = _set_max
@export var border_color: Color = Color(0, 0, 0)
@export var border_width: float = 3.0
@export var bg_color: Color = Color(0.20, 0.05, 0.05)

func _ready() -> void:
	custom_minimum_size = Vector2(180, 18)

func _set_value(v: float) -> void:
	value = clampf(v, 0.0, max_value)
	queue_redraw()

func _set_max(v: float) -> void:
	max_value = max(1.0, v)
	queue_redraw()

func _draw() -> void:
	# Outer black outline.
	draw_rect(Rect2(Vector2.ZERO, size), border_color, false, border_width)
	var inner_pos := Vector2(border_width, border_width)
	var inner_size := size - inner_pos * 2.0
	draw_rect(Rect2(inner_pos, inner_size), bg_color, true)
	if max_value <= 0:
		return
	var pct: float = clampf(value / max_value, 0.0, 1.0)
	# Hue shift: green (120°) → yellow (60°) → red (0°).
	var hue: float = lerp(0.0, 120.0, pct) / 360.0
	var fill_color := Color.from_hsv(hue, 0.85, 0.95)
	var fill_w := inner_size.x * pct
	draw_rect(Rect2(inner_pos, Vector2(fill_w, inner_size.y)), fill_color, true)
	# Highlight strip on top half for a subtle 3D feel.
	var hl := fill_color.lightened(0.25)
	hl.a = 0.6
	draw_rect(Rect2(inner_pos, Vector2(fill_w, inner_size.y * 0.4)), hl, true)
