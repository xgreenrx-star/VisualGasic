@tool
extends Control
## Game UI — Segmented experience bar with level badge.

signal level_up(new_level: int)
signal xp_changed(current: int, max_xp: int)

# ── VB6-style properties ──────────────────────────────────────

@export var CurrentXP: int = 350:
	set(v):
		CurrentXP = maxi(v, 0)
		if CurrentXP >= MaxXP and MaxXP > 0:
			var overflow := CurrentXP - MaxXP
			Level += 1
			CurrentXP = overflow
			level_up.emit(Level)
		xp_changed.emit(CurrentXP, MaxXP)
		queue_redraw()

@export var MaxXP: int = 1000:
	set(v):
		MaxXP = maxi(v, 1)
		queue_redraw()

@export var Level: int = 5:
	set(v):
		Level = maxi(v, 1)
		queue_redraw()

@export_range(1, 20) var Segments: int = 10:
	set(v):
		Segments = clampi(v, 1, 20)
		queue_redraw()

@export var BarHeight: float = 20.0:
	set(v):
		BarHeight = maxf(v, 8.0)
		custom_minimum_size.y = BarHeight
		queue_redraw()

@export var BarWidth: float = 220.0:
	set(v):
		BarWidth = maxf(v, 60.0)
		custom_minimum_size.x = BarWidth + 40
		queue_redraw()

@export var FillColor: Color = Color(0.3, 0.75, 1.0)
@export var EmptyColor: Color = Color(0.15, 0.15, 0.22)
@export var SegmentBorderColor: Color = Color(0.08, 0.08, 0.12)
@export var ShowLevel: bool = true:
	set(v):
		ShowLevel = v
		queue_redraw()

@export var LevelBadgeColor: Color = Color(1.0, 0.85, 0.3)

func _ready() -> void:
	custom_minimum_size = Vector2(BarWidth + 40, BarHeight)
	queue_redraw()

func _draw() -> void:
	var badge_w := 32.0 if ShowLevel else 0.0
	var bar_x := badge_w + 4.0
	var bar_w := size.x - bar_x
	var bar_h := size.y
	var progress: float = clampf(float(CurrentXP) / MaxXP, 0.0, 1.0) if MaxXP > 0 else 0.0

	# Background
	draw_rect(Rect2(Vector2(bar_x, 0), Vector2(bar_w, bar_h)), EmptyColor)

	# Filled portion
	var fill_w := bar_w * progress
	draw_rect(Rect2(Vector2(bar_x, 0), Vector2(fill_w, bar_h)), FillColor)

	# Segment dividers
	if Segments > 1:
		var seg_w := bar_w / Segments
		for i in range(1, Segments):
			var sx := bar_x + seg_w * i
			draw_line(Vector2(sx, 0), Vector2(sx, bar_h), SegmentBorderColor, 2.0)

	# Border
	draw_rect(Rect2(Vector2(bar_x, 0), Vector2(bar_w, bar_h)), Color(0.4, 0.4, 0.5, 0.5), false, 1.0)

	# Level badge
	if ShowLevel:
		var bcx := badge_w * 0.5
		var bcy := bar_h * 0.5
		var br := min(badge_w, bar_h) * 0.45
		draw_circle(Vector2(bcx, bcy), br, LevelBadgeColor.lerp(Color(0.1, 0.1, 0.15), 0.3))
		draw_arc(Vector2(bcx, bcy), br, 0, TAU, 32, LevelBadgeColor, 1.5)
		var font := ThemeDB.fallback_font
		if font:
			var lvl_str := str(Level)
			var fsize := 11
			var ts := font.get_string_size(lvl_str, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize)
			draw_string(font, Vector2(bcx - ts.x * 0.5, bcy + ts.y * 0.3), lvl_str, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize, Color.WHITE)

	# XP text overlay
	var font := ThemeDB.fallback_font
	if font:
		var xp_str := "%d / %d" % [CurrentXP, MaxXP]
		var fsize := 9
		var ts := font.get_string_size(xp_str, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize)
		var tx := bar_x + (bar_w - ts.x) * 0.5
		var ty := (bar_h + ts.y) * 0.5 - 1
		draw_string(font, Vector2(tx, ty), xp_str, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize, Color(1, 1, 1, 0.8))

func add_xp(amount: int) -> void:
	CurrentXP += amount
