extends "res://cockpit_art.gd"

func _draw() -> void:
	plate([Vector2(0, 0), Vector2(960, 0), Vector2(960, 88), Vector2(0, 88)])
	for side in [-1.0, 1.0]:
		var edge: float = 480 + side * 480
		plate([Vector2(edge, 0), Vector2(480 + side * 240, 74),
			Vector2(480 + side * 218, 63), Vector2(480 + side * 405, 0)])
		plate([Vector2(edge, 92), Vector2(480 + side * 432, 95),
			Vector2(480 + side * 220, 323), Vector2(480 + side * 249, 342)])
		for rib in 3:
			path([Vector2(480 + side * (440 + rib * 7), 96),
				Vector2(480 + side * (237 + rib * 7), 324)], PINK, 2)
		plate([Vector2(edge, 297), Vector2(480 + side * 376, 300),
			Vector2(480 + side * 290, 351), Vector2(edge, 416)])
		arc(Vector2(480 + side * 422, 342), Vector2(87, 37), PI, TAU, PINK, 2)
		plate([Vector2(edge, 405), Vector2(480 + side * 294, 344),
			Vector2(480 + side * 262, 393), Vector2(edge, 481)])
		plate([Vector2(edge, 461), Vector2(480 + side * 268, 399),
			Vector2(480 + side * 204, 540), Vector2(edge, 540)])
	path([Vector2(61, 95), Vector2(899, 95)], PINK, 2.2)
	path([Vector2(97, 103), Vector2(863, 103), Vector2(720, 307),
		Vector2(240, 307), Vector2(97, 103)], PINK)
	plate([Vector2(176, 417), Vector2(206, 363), Vector2(337, 349),
		Vector2(367, 337), Vector2(593, 337), Vector2(623, 349),
		Vector2(754, 363), Vector2(784, 417), Vector2(731, 464), Vector2(229, 464)])
	path([Vector2(181, 414), Vector2(211, 367), Vector2(340, 354),
		Vector2(370, 343), Vector2(590, 343), Vector2(620, 354),
		Vector2(749, 367), Vector2(779, 414)], CYAN, 2)
	screen(Rect2(219, 372, 121, 58))
	screen(Rect2(359, 359, 242, 75))
	screen(Rect2(620, 372, 121, 58))
	for side in [-1.0, 1.0]:
		plate([Vector2(480 + side * 277, 419), Vector2(480 + side * 239, 412),
			Vector2(480 + side * 209, 441), Vector2(480 + side * 225, 471),
			Vector2(480 + side * 271, 465), Vector2(480 + side * 288, 441)])
		plate([Vector2(480 + side * 269, 424), Vector2(480 + side * 240, 420),
			Vector2(480 + side * 220, 442), Vector2(480 + side * 232, 459),
			Vector2(480 + side * 264, 453)], CYAN)
		path([Vector2(480 + side * 250, 471), Vector2(480 + side * 248, 502),
			Vector2(480 + side * 159, 509)], PINK, 3)
		for i in 3:
			path([Vector2(480 + side * 256, 433 + i * 5),
				Vector2(480 + side * 246, 431 + i * 5)], CYAN)
	plate([Vector2(300, 540), Vector2(323, 466), Vector2(375, 449),
		Vector2(585, 449), Vector2(637, 466), Vector2(660, 540)])
	plate([Vector2(365, 540), Vector2(391, 482), Vector2(569, 482), Vector2(595, 540)], CYAN)
	path([Vector2(394, 540), Vector2(413, 496), Vector2(547, 496), Vector2(566, 540)], CYAN, 2)
	for side in [-1.0, 1.0]:
		for row in 4:
			path([Vector2(480 + side * 131, 475 + row * 7),
				Vector2(480 + side * 153, 478 + row * 7)], CYAN)
