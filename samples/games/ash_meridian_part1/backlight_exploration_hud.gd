extends Node2D

var city: Node
const CYAN := Color(0.4, 0.85, 1.0)
const AMBER := Color(1.0, 0.65, 0.22)
const PINK := Color(1.0, 0.3, 0.65)

func _text(at: Vector2, text: String, size := 14, color := CYAN) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func glyph(at: Vector2, digit: int, scale := 1.0, color := AMBER) -> void:
	# An original stroke alphabet; keyboard numerals are controls, not the display.
	var patterns := [0b001111, 0b010101, 0b100110, 0b111000, 0b101001,
		0b011010, 0b110100, 0b100011, 0b011101, 0b110011]
	var paths := [
		PackedVector2Array([Vector2(0, 0), Vector2(7, 6), Vector2(14, 0)]),
		PackedVector2Array([Vector2(0, 18), Vector2(7, 12), Vector2(14, 18)]),
		PackedVector2Array([Vector2(0, 2), Vector2(0, 16)]),
		PackedVector2Array([Vector2(14, 2), Vector2(14, 16)]),
		PackedVector2Array([Vector2(3, 9), Vector2(11, 9)]),
		PackedVector2Array([Vector2(7, -3), Vector2(7, 21)])]
	for i in paths.size():
		if patterns[digit] & (1 << i):
			var points := PackedVector2Array()
			for p in paths[i]:
				points.append(at + p * scale)
			draw_polyline(points, color, 1.7 * scale, true)

func glyph_string(at: Vector2, text: String, scale := 1.0, color := AMBER) -> void:
	for i in text.length():
		glyph(at + Vector2(i * 23 * scale, 0), int(text.substr(i, 1)), scale, color)

func _draw() -> void:
	var driving: bool = city.driving and city.place == "surface" and city.inspection == 0
	draw_rect(Rect2(0, 0, 960, 64), Color(0.005, 0.015, 0.025, 0.87))
	var title := "BACKLIGHT CITY / SURFACE" if city.place == "surface" else (
		str(city.buildings[city.building_index].label) if city.place == "building" else (
			"DEEP TRANSIT / LIFT" if city.place == "lift" else "DEEP STRATUM"))
	_text(Vector2(22, 24), title, 18)
	if city.place == "floor":
		glyph_string(Vector2(240, 10), city.floor_code, 0.65)
	_text(Vector2(22, 47), "SHIP: " + ("PRESSURE OK" if city.inventory.has("regulator") else "PRESSURE --") + " / " +
		("IGNITION OK" if city.inventory.has("ignition") else "IGNITION --") + " / " +
		("COUPLER OK" if city.inventory.has("coupler") else "COUPLER --") + "    SUIT %d" % city.shield, 12)
	if not driving:
		draw_rect(Rect2(0, 495, 960, 45), Color(0.005, 0.015, 0.025, 0.9))
		_text(Vector2(20, 520), city.prompt(), 14)
	else:
		_text(Vector2(225, 86), "F EXIT / E USE / V INSPECT", 12)
	if city.message_left > 0:
		draw_rect(Rect2(14, 72, 932, 38), Color(0.005, 0.01, 0.02, 0.87))
		_text(Vector2(24, 96), city.message, 13, AMBER)
	if not driving:
		draw_rect(Rect2(14, 126, 170, 121), Color(0.005, 0.01, 0.02, 0.8))
		_text(Vector2(26, 148), "DESCENT JOURNAL", 12)
		for i in 5:
			var at := Vector2(27 + i * 29, 165)
			draw_rect(Rect2(at - Vector2(4, 4), Vector2(25, 31)), CYAN * 0.3, false)
			if city.discovered.has(i):
				glyph(at, int(city.discovered[i]), 1.0)
		_text(Vector2(25, 226), "Search the five archives.", 11)
	if city.awakening:
		draw_rect(Rect2(725, 120, 220, 82), Color(0.025, 0.005, 0.018, 0.92))
		_text(Vector2(744, 142), "PURGE / ZEN ONLINE", 12, PINK)
		glyph_string(Vector2(756, 157), "%03d" % ceili(city.countdown), 1.5, PINK)
		if fmod(city.alarm_elapsed, 1.0) < 0.3:
			draw_rect(Rect2(0, 0, 960, 540), Color(1, 0.03, 0.2, 0.055))
		if city.alarm_elapsed < 8:
			_text(Vector2(360, 330), "ZEN: RUN!", 38, PINK)
	if city.keypad:
		draw_rect(Rect2(220, 140, 520, 330), Color(0.01, 0.025, 0.04, 0.98))
		_text(Vector2(247, 171), "DEEP TRANSIT / FIVE-SYMBOL ADDRESS", 17)
		glyph_string(Vector2(363, 198), city.sequence, 1.7)
		for digit in 10:
			var at := Vector2(260 + (digit % 5) * 94, 263 + (digit / 5) * 68)
			draw_rect(Rect2(at - Vector2(12, 7), Vector2(70, 55)), CYAN * 0.25, false)
			glyph(at, digit, 1.3)
			_text(at + Vector2(32, 22), str(digit), 12, CYAN * 0.8)
		_text(Vector2(244, 420), "0-9 choose / Backspace erase / Enter descend", 14)
		_text(Vector2(244, 446), "F cancel. Journal order is left to right.", 13)
	if city.transit_left > 0:
		draw_rect(Rect2(250, 212, 460, 120), Color(0.005, 0.015, 0.025, 0.94))
		_text(Vector2(283, 246), "ASCENDING" if city.lift_target == "surface" else "DESCENDING TO STRATUM", 20)
		if city.lift_target != "surface":
			glyph_string(Vector2(366, 272), city.lift_target, 1.4)
	if city.failed or city.completed:
		draw_rect(Rect2(150, 220, 660, 150), Color(0.005, 0.015, 0.025, 0.97))
		_text(Vector2(210, 258), "THE ASH IS AWAY" if city.completed else "ESCAPE FAILED", 28, AMBER)
		_text(Vector2(210, 295), "Enter: restart prototype" if city.completed else "Enter: retry from the FEB chamber", 18)
		_text(Vector2(210, 332), "Chapter save unchanged. This is the exploration prototype.", 13)
