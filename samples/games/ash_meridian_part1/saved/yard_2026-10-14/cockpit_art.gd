extends Node2D

const PINK := Color(1.0, 0.29, 0.85)
const CYAN := Color(0.2, 0.92, 1.0)
const METAL := Color(0.018, 0.009, 0.028)

func path(points: Array, color := PINK, width := 1.2, glow := true) -> void:
	var packed := PackedVector2Array()
	for point in points:
		packed.append(point)
	if glow:
		draw_polyline(packed, Color(color, 0.045), width + 9.0, true)
		draw_polyline(packed, Color(color, 0.12), width + 4.0, true)
	draw_polyline(packed, color, width, true)

func plate(points: Array, color := PINK) -> void:
	draw_colored_polygon(PackedVector2Array(points), METAL)
	path(points + [points[0]], color)

func arc(center: Vector2, radius: Vector2, start: float, finish: float, color := PINK, width := 1.2) -> void:
	var points := []
	for i in 65:
		var angle := lerpf(start, finish, i / 64.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	path(points, color, width)

func screen(rect: Rect2) -> void:
	draw_style_box(_panel_style(), rect.grow(6))
	draw_rect(rect, Color(0.005, 0.018, 0.025))
	path([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end,
		rect.position + Vector2(0, rect.size.y), rect.position], PINK)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = METAL
	style.border_color = Color(0.6, 0.16, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style

func _draw() -> void:
	# The windscreen is deliberately clear; the reference's flight rings are not canopy geometry.
	for i in 5:
		arc(Vector2(480, 389), Vector2(468 + i * 8, 345 + i * 6), PI * 1.04, PI * 1.96, PINK, 1.0)
	for side in [-1.0, 1.0]:
		for rib in 4:
			var offset: float = side * rib * 5
			path([Vector2(480 + side * 470 + offset, -12), Vector2(480 + side * 298 + offset, 106),
				Vector2(480 + side * 219 + offset, 190), Vector2(480 + side * 158 + offset, 300)], PINK)
		path([Vector2(480 + side * 482, 0), Vector2(480 + side * 468, 350),
			Vector2(480 + side * 328, 309), Vector2(480 + side * 152, 286)], PINK, 2)
		plate([Vector2(480 + side * 478, 356), Vector2(480 + side * 312, 315),
			Vector2(480 + side * 241, 434), Vector2(480 + side * 334, 540), Vector2(480 + side * 480, 540)])
		for i in 3:
			var x: float = 480 + side * (350 + i * 28)
			plate([Vector2(x, 389), Vector2(x + side * 19, 383), Vector2(x + side * 19, 397), Vector2(x, 403)], CYAN if i % 2 == 0 else PINK)
		plate([Vector2(480 + side * 310, 442), Vector2(480 + side * 379, 523),
			Vector2(480 + side * 462, 493), Vector2(480 + side * 367, 419)])
		for row in 4:
			var y := 449 + row * 15
			var x: float = 480 + side * (357 + row * 10)
			path([Vector2(x, y), Vector2(x + side * 35, y - 9)], CYAN, 1.3)
	plate([Vector2(180, 435), Vector2(197, 325), Vector2(335, 301), Vector2(357, 278),
		Vector2(603, 278), Vector2(625, 301), Vector2(763, 325), Vector2(780, 435)])
	plate([Vector2(194, 439), Vector2(207, 329), Vector2(340, 311), Vector2(362, 288),
		Vector2(598, 288), Vector2(620, 311), Vector2(753, 329), Vector2(766, 439)])
	screen(Rect2(371, 294, 218, 36))
	path([Vector2(384, 319), Vector2(384, 302), Vector2(398, 303), Vector2(425, 320), Vector2(442, 320)], CYAN)
	for i in 5:
		path([Vector2(461 + i * 19, 301), Vector2(471 + i * 19, 301)], CYAN)
	arc(Vector2(555, 314), Vector2(9, 9), 0, TAU, CYAN)
	for i in 8:
		var angle := i * TAU / 8
		path([Vector2(555, 314) + Vector2.from_angle(angle) * 12, Vector2(555, 314) + Vector2.from_angle(angle) * 16], CYAN)
	screen(Rect2(219, 343, 139, 88))
	screen(Rect2(379, 343, 202, 88))
	screen(Rect2(602, 343, 139, 88))
	var radar := Vector2(289, 388)
	arc(radar, Vector2(40, 40), 0, TAU, CYAN)
	arc(radar, Vector2(19, 19), 0, TAU, CYAN)
	path([radar + Vector2(-40, 0), radar + Vector2(40, 0)], CYAN)
	path([radar + Vector2(0, -40), radar + Vector2(0, 40)], CYAN)
	draw_arc(radar, 29, -PI * 0.5, 0, 24, Color(0.12, 0.5, 0.58, 0.7), 17, true)
	arc(Vector2(480, 385), Vector2(47, 34), 0, TAU, CYAN)
	arc(Vector2(480, 385), Vector2(67, 29), 0, TAU, CYAN)
	path([Vector2(480, 349), Vector2(467, 371), Vector2(439, 405), Vector2(470, 399),
		Vector2(480, 424), Vector2(490, 399), Vector2(521, 405), Vector2(493, 371), Vector2(480, 349)], CYAN)
	path([Vector2(480, 351), Vector2(480, 421)], CYAN)
	for i in 6:
		var y := 358 + i * 12
		path([Vector2(387, y), Vector2(396 + (i % 2) * 8, y)], CYAN)
		path([Vector2(564, y), Vector2(573, y)], CYAN)
	for i in 3:
		var x := 652 + i * 25
		path([Vector2(x, 351), Vector2(x + 15, 351), Vector2(x + 15, 422), Vector2(x, 422), Vector2(x, 351)], CYAN)
		for j in range(3 + i * 2):
			draw_rect(Rect2(x + 3, 416 - j * 5, 9, 3), CYAN)
	for i in 4:
		path([Vector2(611, 353 + i * 10), Vector2(630 - (i % 2) * 8, 353 + i * 10)], CYAN)
	# Low yoke grips leave all three instruments readable.
	plate([Vector2(385, 420), Vector2(402, 425), Vector2(390, 468), Vector2(406, 480),
		Vector2(554, 480), Vector2(570, 468), Vector2(558, 425), Vector2(575, 420),
		Vector2(592, 477), Vector2(576, 497), Vector2(384, 497), Vector2(368, 477)])
	for side in [-1.0, 1.0]:
		arc(Vector2(480 + side * 94, 421), Vector2(14, 7), 0, TAU, PINK, 1.6)
		for rib in 3:
			path([Vector2(480 + side * 105, 426 + rib * 4), Vector2(480 + side * 85, 431 + rib * 4)], PINK)
	plate([Vector2(450, 436), Vector2(510, 436), Vector2(538, 507), Vector2(422, 507)])
	for rib in 4:
		path([Vector2(449 - rib * 4, 445 + rib * 12), Vector2(511 + rib * 4, 445 + rib * 12)], PINK)
	plate([Vector2(450, 511), Vector2(510, 511), Vector2(510, 540), Vector2(450, 540)])
