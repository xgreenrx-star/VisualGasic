extends Node2D

const CYAN := Color(0.2, 0.92, 1.0)
const AMBER := Color(1.0, 0.45, 0.15)
const INK := Color(0.005, 0.018, 0.025)

var buggy := false
var time := 0.0
var speed := 0.0
var heading := 0.0
var altitude := 0.0
var warning := 0.0
var progress := 0.0
var range_end := 368.0
var max_speed := 16.0

func update_readings(t: float, velocity: float, bearing: float, height: float, alert: float, distance: float, destination := 368.0, top_speed := 16.0) -> void:
	time = t
	speed = velocity
	heading = bearing
	altitude = height
	warning = alert
	progress = distance
	range_end = destination
	max_speed = top_speed
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	if buggy:
		draw_rect(Rect2(219, 372, 121, 58), INK)
		draw_rect(Rect2(359, 359, 242, 75), INK)
		draw_rect(Rect2(620, 372, 121, 58), INK)
		draw_string(font, Vector2(229, 384), "DRIVE / km/h", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, CYAN)
		draw_string(font, Vector2(229, 410), "%02d" % roundi(absf(speed) * 3.6), HORIZONTAL_ALIGNMENT_LEFT, -1, 23, CYAN)
		for i in 10:
			draw_rect(Rect2(229 + i * 10, 419, 7, 4), CYAN if i < absf(speed) / max_speed * 10 else CYAN * 0.18)
		draw_string(font, Vector2(372, 373), "MERIDIAN / YARD TELEMETRY", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, CYAN)
		var bearing := fposmod(rad_to_deg(heading), 360.0)
		draw_string(font, Vector2(372, 392), "HDG %03d    RANGE %03dm" % [roundi(bearing), roundi(maxf(0, range_end - progress))], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, CYAN)
		_wave(Rect2(373, 402, 132, 20), 2.0 + absf(speed) * 0.3)
		for i in 5:
			draw_rect(Rect2(521, 402 + i * 5, 62 * (0.4 + 0.4 * sin(time * 2 + i)), 2), CYAN)
		_dial(Vector2(653, 407), 24, absf(speed) / max_speed)
		draw_string(font, Vector2(679, 392), "MOTOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, CYAN)
		draw_string(font, Vector2(680, 412), "%02d%%" % roundi(clampf(absf(speed) / max_speed, 0, 1) * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, CYAN)
	else:
		draw_rect(Rect2(219, 343, 139, 88), INK)
		draw_rect(Rect2(379, 343, 202, 76), INK)
		draw_rect(Rect2(602, 343, 139, 88), INK)
		_dial(Vector2(289, 386), 36, fposmod(time * 0.12, 1))
		draw_line(Vector2(253, 386), Vector2(325, 386), CYAN * 0.4)
		draw_line(Vector2(289, 350), Vector2(289, 422), CYAN * 0.4)
		var blip := Vector2(289, 386) + Vector2(sin(time * 0.3), cos(time * 0.2)) * 23
		draw_circle(blip, 2, CYAN)
		draw_string(font, Vector2(391, 358), "ASH / FLIGHT SYSTEMS", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, CYAN)
		draw_string(font, Vector2(391, 376), "VEL %03d  ALT %03d" % [roundi(speed), roundi(altitude)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, CYAN)
		_wave(Rect2(391, 384, 174, 20), 6 + warning * 8)
		draw_string(font, Vector2(391, 415), "COUPLER FAULT" if warning > 0.5 else "APPROACH LOCK", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, AMBER if warning > 0.5 else CYAN)
		for i in 3:
			var level := clampf(0.55 + sin(time * (0.6 + i * 0.2)) * 0.22 - warning * i * 0.08, 0.1, 1)
			draw_rect(Rect2(638 + i * 30, 351, 19, 70), CYAN * 0.15)
			draw_rect(Rect2(638 + i * 30, 421 - 70 * level, 19, 70 * level), AMBER if i == 2 and warning > 0.5 else CYAN)

func _dial(center: Vector2, radius: float, value: float) -> void:
	draw_arc(center, radius, -PI * 1.2, PI * 0.2, 36, CYAN, 1.5, true)
	for i in 11:
		var angle := -PI * 1.2 + i * PI * 1.4 / 10
		draw_line(center + Vector2.from_angle(angle) * (radius - 4), center + Vector2.from_angle(angle) * radius, CYAN, 1, true)
	draw_line(center, center + Vector2.from_angle(-PI * 1.2 + value * PI * 1.4) * (radius - 5), CYAN, 2, true)

func _wave(rect: Rect2, amplitude: float) -> void:
	var points := PackedVector2Array()
	for i in 48:
		points.append(Vector2(rect.position.x + i * rect.size.x / 47, rect.get_center().y + sin(i * 0.55 + time * 5) * minf(amplitude, rect.size.y * 0.45)))
	draw_polyline(points, CYAN, 1, true)
