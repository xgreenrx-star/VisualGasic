@tool
extends Control
## Game UI — Node-based skill/talent tree with unlock paths.

signal skill_selected(index: int)
signal skill_unlocked(index: int)

# ── VB6-style properties ──────────────────────────────────────

@export_range(3, 20) var NodeCount: int = 9:
	set(v):
		NodeCount = clampi(v, 3, 20)
		queue_redraw()

@export_range(1, 6) var Columns: int = 3:
	set(v):
		Columns = clampi(v, 1, 6)
		queue_redraw()

@export var NodeRadius: float = 16.0:
	set(v):
		NodeRadius = v
		queue_redraw()

@export var SkillNames: String = "Slash,Block,Heal,Fireball,Ice,Thunder,Regen,Fury,Ultima":
	set(v):
		SkillNames = v
		queue_redraw()

@export var UnlockedColor: Color = Color(0.3, 0.85, 0.4)
@export var LockedColor: Color = Color(0.4, 0.4, 0.5)
@export var LineColor: Color = Color(0.3, 0.35, 0.45)
@export var SelectedIndex: int = -1:
	set(v):
		SelectedIndex = v
		queue_redraw()

var _unlocked: Array[bool] = []

func _ready() -> void:
	custom_minimum_size = Vector2(240, 240)
	_unlocked.resize(NodeCount)
	for i in NodeCount:
		_unlocked[i] = (i == 0)
	queue_redraw()

func _draw() -> void:
	var names := SkillNames.split(",")
	var cols := Columns
	var rows := ceili(float(NodeCount) / cols)
	var cell_w: float = size.x / cols
	var cell_h: float = size.y / rows

	# Draw connection lines first
	for i in range(NodeCount):
		var row_i := i / cols
		var col_i := i % cols
		var cx := cell_w * col_i + cell_w * 0.5
		var cy := cell_h * row_i + cell_h * 0.5
		# connect to node above
		if row_i > 0:
			var parent := (row_i - 1) * cols + col_i
			if parent < NodeCount:
				var pcx := cell_w * col_i + cell_w * 0.5
				var pcy := cell_h * (row_i - 1) + cell_h * 0.5
				draw_line(Vector2(pcx, pcy + NodeRadius), Vector2(cx, cy - NodeRadius), LineColor, 2.0)
		# connect to left sibling in same row
		if col_i > 0 and i - 1 >= 0:
			var lcx := cell_w * (col_i - 1) + cell_w * 0.5
			draw_line(Vector2(lcx + NodeRadius, cy), Vector2(cx - NodeRadius, cy), LineColor.lerp(Color.TRANSPARENT, 0.5), 1.0)

	# Draw nodes
	for i in range(NodeCount):
		var row_i := i / cols
		var col_i := i % cols
		var cx := cell_w * col_i + cell_w * 0.5
		var cy := cell_h * row_i + cell_h * 0.5
		var center := Vector2(cx, cy)
		var unlocked: bool = _unlocked[i] if i < _unlocked.size() else false
		var col: Color = UnlockedColor if unlocked else LockedColor

		# Circle fill
		draw_circle(center, NodeRadius, col.lerp(Color(0.1, 0.1, 0.15), 0.4))
		# Circle border
		draw_arc(center, NodeRadius, 0, TAU, 32, col, 2.0)

		# Selection ring
		if i == SelectedIndex:
			draw_arc(center, NodeRadius + 4, 0, TAU, 32, Color(1.0, 0.9, 0.3), 2.0)

		# Label
		var label: String = names[i].strip_edges() if i < names.size() else str(i + 1)
		var font := ThemeDB.fallback_font
		var fsize := 9
		if font:
			var tsize := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize)
			draw_string(font, center - Vector2(tsize.x * 0.5, -tsize.y * 0.25), label, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize, Color.WHITE)

func unlock_skill(index: int) -> void:
	if index >= 0 and index < _unlocked.size():
		_unlocked[index] = true
		skill_unlocked.emit(index)
		queue_redraw()

func select_skill(index: int) -> void:
	SelectedIndex = index
	skill_selected.emit(index)
