@tool
extends Control
## PixelProgressBar — chunky 8-bit pixel-block style progress bar.
## Each filled cell is a single pixel block. Use for retro game HUDs.

@export var value: float = 50.0 : set = _set_value
@export var max_value: float = 100.0 : set = _set_max
@export var cell_count: int = 20
@export var cell_color: Color = Color(0.20, 0.95, 0.30)
@export var empty_color: Color = Color(0.10, 0.15, 0.10)
@export var border_color: Color = Color(0.0, 0.0, 0.0)
@export var border_width: float = 2.0
@export var cell_gap: float = 1.0

func _ready() -> void:
	custom_minimum_size = Vector2(160, 16)

func _set_value(v: float) -> void:
	value = clampf(v, 0.0, max_value)
	queue_redraw()

func _set_max(v: float) -> void:
	max_value = max(1.0, v)
	queue_redraw()

func _draw() -> void:
	# Border (1-px-style, bw thick).
	draw_rect(Rect2(Vector2.ZERO, size), border_color, false, border_width)
	# Inner area.
	var inner_pos := Vector2(border_width, border_width)
	var inner_size := size - inner_pos * 2.0
	draw_rect(Rect2(inner_pos, inner_size), empty_color, true)
	if cell_count <= 0 or max_value <= 0:
		return
	var filled_cells: int = int(round(cell_count * (value / max_value)))
	var cell_w := (inner_size.x - cell_gap * (cell_count - 1)) / cell_count
	for i in range(filled_cells):
		var x := inner_pos.x + i * (cell_w + cell_gap)
		draw_rect(Rect2(x, inner_pos.y, cell_w, inner_size.y), cell_color, true)
