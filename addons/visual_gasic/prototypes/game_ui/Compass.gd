@tool
extends Control
## Game UI — Horizontal strip compass showing N/S/E/W bearings.

signal bearing_changed(degrees: float)

# ── VB6-style properties ──────────────────────────────────────

@export_range(0.0, 360.0, 0.1) var Bearing: float = 0.0:
	set(v):
		Bearing = fmod(v, 360.0)
		if Bearing < 0: Bearing += 360.0
		queue_redraw()
		bearing_changed.emit(Bearing)

@export var StripWidth: float = 200.0:
	set(v):
		StripWidth = maxf(v, 80.0)
		custom_minimum_size.x = StripWidth
		queue_redraw()

@export var StripHeight: float = 28.0:
	set(v):
		StripHeight = maxf(v, 16.0)
		custom_minimum_size.y = StripHeight
		queue_redraw()

@export var BackgroundColor: Color = Color(0.08, 0.08, 0.12, 0.85)
@export var TickColor: Color = Color(0.6, 0.6, 0.7)
@export var CardinalColor: Color = Color(1.0, 0.9, 0.4)
@export var CenterMarkerColor: Color = Color(1.0, 0.3, 0.2)

@export var ShowMarkers: bool = true:
	set(v):
		ShowMarkers = v
		queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(StripWidth, StripHeight)
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y

	# Background
	draw_rect(Rect2(Vector2.ZERO, size), BackgroundColor)
	draw_rect(Rect2(Vector2.ZERO, size), TickColor.lerp(Color.TRANSPARENT, 0.7), false, 1.0)

	# Compass strip — 180° visible range
	var degrees_visible := 180.0
	var px_per_deg := w / degrees_visible
	var font := ThemeDB.fallback_font
	var fsize := 10

	var cardinals := {"N": 0.0, "NE": 45.0, "E": 90.0, "SE": 135.0, "S": 180.0, "SW": 225.0, "W": 270.0, "NW": 315.0}

	for label in cardinals:
		var deg: float = cardinals[label]
		var diff := fmod(deg - Bearing + 540.0, 360.0) - 180.0
		if abs(diff) > degrees_visible * 0.5: continue
		var px := w * 0.5 + diff * px_per_deg
		var is_cardinal := (label.length() == 1)
		var col: Color = CardinalColor if is_cardinal else TickColor
		var tick_h := h * 0.5 if is_cardinal else h * 0.3
		draw_line(Vector2(px, 0), Vector2(px, tick_h), col, 1.5 if is_cardinal else 1.0)
		if font:
			var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize)
			draw_string(font, Vector2(px - ts.x * 0.5, h - 4), label, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize, col)

	# Minor ticks every 15 degrees
	for i in range(24):
		var deg := float(i) * 15.0
		var diff := fmod(deg - Bearing + 540.0, 360.0) - 180.0
		if abs(diff) > degrees_visible * 0.5: continue
		var px := w * 0.5 + diff * px_per_deg
		draw_line(Vector2(px, 0), Vector2(px, h * 0.15), TickColor.lerp(Color.TRANSPARENT, 0.5), 1.0)

	# Center marker
	if ShowMarkers:
		var cx := w * 0.5
		draw_line(Vector2(cx, 0), Vector2(cx, 6), CenterMarkerColor, 2.0)
		var tri := PackedVector2Array([Vector2(cx - 4, 0), Vector2(cx + 4, 0), Vector2(cx, 6)])
		draw_colored_polygon(tri, CenterMarkerColor)

func set_bearing(degrees: float) -> void:
	Bearing = degrees
