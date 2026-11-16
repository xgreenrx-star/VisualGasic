extends Node2D

var time := 0.0
var speed := 0.0
var heading := 0.0
var charge := 0

const BLUE := Color(0.28, 0.78, 1.0)
const TRIM := Color(0.12, 0.22, 0.30)
const PANEL := Color(0.035, 0.055, 0.08)

func _draw() -> void:
	for side in [-1.0, 1.0]:
		var x: float = 480 + side * 437
		draw_polygon(PackedVector2Array([Vector2(x - 32, 0), Vector2(x + 32, 0),
			Vector2(x + side * 5 + 22, 435), Vector2(x + side * 5 - 22, 435)]),
			PackedColorArray([TRIM, TRIM, PANEL, PANEL]))
		draw_line(Vector2(x - side * 26, 0), Vector2(x - side * 17, 422), BLUE * 0.7, 3, true)
	draw_rect(Rect2(0, 0, 960, 31), PANEL)
	draw_line(Vector2(88, 32), Vector2(872, 32), BLUE * 0.8, 3, true)
	draw_polygon(PackedVector2Array([Vector2(0, 450), Vector2(138, 401), Vector2(822, 401),
		Vector2(960, 450), Vector2(960, 540), Vector2(0, 540)]),
		PackedColorArray([TRIM, TRIM, TRIM, TRIM, PANEL, PANEL]))
	draw_polyline(PackedVector2Array([Vector2(0, 450), Vector2(138, 401), Vector2(822, 401), Vector2(960, 450)]), BLUE, 3, true)
	for x in [158.0, 392.0, 626.0]:
		draw_rect(Rect2(x, 417, 176, 76), PANEL)
		draw_rect(Rect2(x, 417, 176, 76), BLUE * 0.5, false, 1.5)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(175, 437), "GROUND SPEED", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BLUE)
	draw_string(font, Vector2(184, 479), "%02d" % roundi(absf(speed) * 3.6), HORIZONTAL_ALIGNMENT_LEFT, -1, 33, Color(0.68, 0.92, 1.0))
	draw_string(font, Vector2(257, 476), "KM/H", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BLUE)
	draw_string(font, Vector2(406, 437), "NAV / HEADING", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BLUE)
	draw_string(font, Vector2(419, 478), "%03d" % roundi(fposmod(rad_to_deg(heading), 360)), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.68, 0.92, 1.0))
	draw_string(font, Vector2(641, 437), "DRIVE / CELLS %d" % charge, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BLUE)
	for i in 12:
		var lit := float(i) < absf(speed) / 18 * 12
		draw_rect(Rect2(642 + i * 12, 456, 8, 22), BLUE if lit else BLUE * 0.15)
	for i in 44:
		var x := 174.0 + i * 14
		var y := 514 + sin(time * 3 + i * 0.32) * (2 + absf(speed) * 0.15)
		draw_line(Vector2(x, y), Vector2(x + 9, y), BLUE * 0.6, 1.5)
