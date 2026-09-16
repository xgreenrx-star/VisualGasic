@tool
extends Control
## CircularProgress — determinate ring progress (cooldowns, capture
## meters, downloads). Set `value` 0..max_value. Optional center label.

@export var value: float = 75.0 : set = _set_value
@export var max_value: float = 100.0 : set = _set_max
@export var ring_color: Color = Color(0.30, 0.85, 0.45)
@export var track_color: Color = Color(0.25, 0.25, 0.25)
@export var thickness: float = 6.0
@export var show_label: bool = true

func _ready() -> void:
	custom_minimum_size = Vector2(64, 64)

func _set_value(v: float) -> void:
	value = clampf(v, 0.0, max_value)
	queue_redraw()

func _set_max(v: float) -> void:
	max_value = max(1.0, v)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius: float = min(size.x, size.y) * 0.5 - thickness
	if radius <= 0 or max_value <= 0:
		return
	draw_arc(center, radius, 0.0, TAU, 64, track_color, thickness, true)
	var pct: float = clampf(value / max_value, 0.0, 1.0)
	if pct > 0.0:
		var start_angle: float = -PI * 0.5  # 12 o'clock
		draw_arc(center, radius, start_angle, start_angle + TAU * pct, 64, ring_color, thickness, true)
	if show_label:
		var pct_text := str(int(round(pct * 100.0))) + "%"
		var font := ThemeDB.fallback_font
		var fs := int(min(size.x, size.y) * 0.28)
		var tw := font.get_string_size(pct_text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(font, center + Vector2(-tw * 0.5, fs * 0.35), pct_text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color.WHITE)
