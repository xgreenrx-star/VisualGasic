@tool
extends PanelContainer
## Game UI — Mini-map display. At design time shows a placeholder.
## At runtime, attach a SubViewport for real map rendering.

signal map_clicked(map_position: Vector2)

# ── VB6-style properties ──────────────────────────────────────

@export var MapSize: int = 140:
	set(v):
		MapSize = clampi(v, 60, 400)
		custom_minimum_size = Vector2(MapSize, MapSize)
		queue_redraw()

@export var ShowBorder: bool = true:
	set(v):
		ShowBorder = v
		queue_redraw()

@export var ShowPlayerDot: bool = true:
	set(v):
		ShowPlayerDot = v
		queue_redraw()

@export var PlayerDotColor: Color = Color(0.2, 1.0, 0.4)
@export var BackgroundColor: Color = Color(0.08, 0.12, 0.08, 0.9)
@export var BorderColor: Color = Color(0.4, 0.6, 0.4, 0.8)
@export_enum("Square", "Round") var Shape: int = 1

var _player_dot: ColorRect

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	for c in get_children(): c.queue_free()
	custom_minimum_size = Vector2(MapSize, MapSize)

	var style := StyleBoxFlat.new()
	style.bg_color = BackgroundColor
	style.border_color = BorderColor
	style.set_border_width_all(2 if ShowBorder else 0)
	if Shape == 1:
		style.set_corner_radius_all(MapSize / 2)
	else:
		style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	add_theme_stylebox_override("panel", style)

	# Player dot at center
	if ShowPlayerDot:
		var center_container := CenterContainer.new()
		center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(center_container)
		_player_dot = ColorRect.new()
		_player_dot.custom_minimum_size = Vector2(6, 6)
		_player_dot.color = PlayerDotColor
		center_container.add_child(_player_dot)

	if Engine.is_editor_hint():
		visible = true
		modulate = Color(1, 1, 1, 1)

func _draw() -> void:
	if not Engine.is_editor_hint(): return
	# Design-time: draw compass lines
	var center := size * 0.5
	var r: float = min(size.x, size.y) * 0.35
	var line_color := Color(0.3, 0.5, 0.3, 0.3)
	draw_line(center - Vector2(r, 0), center + Vector2(r, 0), line_color, 1.0)
	draw_line(center - Vector2(0, r), center + Vector2(0, r), line_color, 1.0)
	# N marker
	var font := get_theme_default_font()
	if font:
		draw_string(font, center - Vector2(4, r + 2), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.6, 0.8, 0.6, 0.5))
