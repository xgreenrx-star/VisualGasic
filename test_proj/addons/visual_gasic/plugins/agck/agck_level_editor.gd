@tool
## AGCK Level Editor
##
## Tile-based screen painter with scenery blocks, actor placement,
## building materials, and sentry path tracing.  Up to 50 levels per game.
extends HSplitContainer

signal level_changed(level_id: int)

# ─── Constants ───────────────────────────────────────────────
const BG_COLOR = Color(0.16, 0.16, 0.19)
const SECTION_COLOR = Color(0.22, 0.26, 0.35)
const HEADER_COLOR = Color(0.85, 0.9, 1.0)
const LABEL_COLOR = Color(0.75, 0.8, 0.85)
const GRID_COLOR = Color(0.25, 0.25, 0.28)
const CURSOR_COLOR = Color(1.0, 1.0, 0.3, 0.6)

const BLOCK_EMPTY = 0
const BLOCK_BARRIER = 1
const BLOCK_LADDER = 2
const BLOCK_DEADLY = 3
const BLOCK_BACKGROUND = 4
const BLOCK_TELEPORT = 5
const BLOCK_SWITCH = 6

const BLOCK_NAMES = ["Empty", "Barrier", "Ladder", "Deadly", "Background", "Teleport", "Switch"]
const BLOCK_COLORS = [
	Color(0.1, 0.1, 0.12),       # Empty
	Color(0.5, 0.5, 0.55),       # Barrier
	Color(0.3, 0.7, 0.3),        # Ladder
	Color(0.8, 0.2, 0.2),        # Deadly
	Color(0.25, 0.35, 0.5),      # Background
	Color(0.6, 0.3, 0.8),        # Teleport
	Color(0.9, 0.8, 0.2),        # Switch
]
const BLOCK_ICONS = ["⬜", "🧱", "🪜", "💀", "🟦", "🌀", "⚡"]

const MAX_LEVELS = 50
const GRID_W = 20
const GRID_H = 12
const CELL_SIZE = 24

# ─── Level Data ──────────────────────────────────────────────
var levels: Array = []
var selected_level: int = 0
var selected_block: int = BLOCK_BARRIER
var selected_actor: int = -1  # -1 = painting blocks
var is_painting: bool = false

# ─── Actor Placement ─────────────────────────────────────────
var actor_names: Array = ["Hero", "Enemy 1", "Bullet"]  # synced from actor editor

# ─── Sentry Paths ────────────────────────────────────────────
var is_tracing_path: bool = false
var trace_actor: int = -1
var trace_points: Array = []

# ─── UI ──────────────────────────────────────────────────────
var _level_list: ItemList = null
var _grid_canvas: Control = null
var _block_btns: Array = []
var _actor_list_opt: OptionButton = null
var _status_lbl: Label = null
var _material_friction: HSlider = null
var _material_elasticity: HSlider = null
var _name_edit: LineEdit = null


func _ready() -> void:
	_init_levels()
	_build_ui()


func _init_levels() -> void:
	levels.clear()
	for i in range(MAX_LEVELS):
		levels.append(_make_empty_level(i + 1))


func _make_empty_level(num: int) -> Dictionary:
	var grid: Array = []
	for _y in range(GRID_H):
		var row: Array = []
		row.resize(GRID_W)
		row.fill(BLOCK_EMPTY)
		grid.append(row)
	return {
		"name": "Level " + str(num),
		"grid": grid,
		"actors": [],  # Array of {actor_id, x, y, path:[]}
		"material_friction": 50,
		"material_elasticity": 50,
	}


func _build_ui() -> void:
	# LEFT PANEL: Level list + block palette
	var left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size.x = 170
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var left_style = StyleBoxFlat.new()
	left_style.bg_color = Color(0.13, 0.13, 0.16)
	var left_wrap = PanelContainer.new()
	left_wrap.add_theme_stylebox_override("panel", left_style)
	left_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Level list header
	var hdr = Label.new()
	hdr.text = "🗺️  LEVELS"
	hdr.add_theme_font_size_override("font_size", 14)
	hdr.add_theme_color_override("font_color", HEADER_COLOR)
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(hdr)

	# Level list
	_level_list = ItemList.new()
	_level_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_level_list.custom_minimum_size.y = 180
	_level_list.add_theme_font_size_override("font_size", 11)
	_level_list.item_selected.connect(_on_level_selected)
	left_panel.add_child(_level_list)

	# Level buttons
	var lv_btn_row = HBoxContainer.new()
	lv_btn_row.add_theme_constant_override("separation", 2)
	var add_btn = Button.new()
	add_btn.text = "+"
	add_btn.tooltip_text = "Initialize next empty level"
	add_btn.add_theme_font_size_override("font_size", 12)
	add_btn.pressed.connect(_on_add_level)
	lv_btn_row.add_child(add_btn)
	var dup_btn = Button.new()
	dup_btn.text = "⧉"
	dup_btn.tooltip_text = "Duplicate current level"
	dup_btn.add_theme_font_size_override("font_size", 12)
	dup_btn.pressed.connect(_on_dup_level)
	lv_btn_row.add_child(dup_btn)
	var clr_btn = Button.new()
	clr_btn.text = "✕"
	clr_btn.tooltip_text = "Clear current level"
	clr_btn.add_theme_font_size_override("font_size", 12)
	clr_btn.pressed.connect(_on_clear_level)
	lv_btn_row.add_child(clr_btn)
	left_panel.add_child(lv_btn_row)

	# Separator
	left_panel.add_child(HSeparator.new())

	# Block palette header
	var pal_hdr = Label.new()
	pal_hdr.text = "BLOCKS"
	pal_hdr.add_theme_font_size_override("font_size", 12)
	pal_hdr.add_theme_color_override("font_color", HEADER_COLOR)
	pal_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(pal_hdr)

	for i in range(BLOCK_NAMES.size()):
		var btn = Button.new()
		btn.text = BLOCK_ICONS[i] + " " + BLOCK_NAMES[i]
		btn.add_theme_font_size_override("font_size", 11)
		btn.toggle_mode = true
		btn.button_pressed = (i == selected_block)
		btn.pressed.connect(_on_block_selected.bind(i))
		var style = StyleBoxFlat.new()
		style.bg_color = BLOCK_COLORS[i].darkened(0.4)
		style.set_corner_radius_all(2)
		style.content_margin_left = 4
		style.content_margin_right = 4
		btn.add_theme_stylebox_override("normal", style)
		var pressed_s = style.duplicate()
		pressed_s.bg_color = BLOCK_COLORS[i]
		btn.add_theme_stylebox_override("pressed", pressed_s)
		left_panel.add_child(btn)
		_block_btns.append(btn)

	# Actor placement
	left_panel.add_child(HSeparator.new())
	var actor_hdr = Label.new()
	actor_hdr.text = "ACTORS"
	actor_hdr.add_theme_font_size_override("font_size", 12)
	actor_hdr.add_theme_color_override("font_color", HEADER_COLOR)
	actor_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(actor_hdr)
	_actor_list_opt = OptionButton.new()
	_actor_list_opt.add_theme_font_size_override("font_size", 11)
	_actor_list_opt.add_item("(Blocks mode)")
	for aname in actor_names:
		_actor_list_opt.add_item("👾 " + aname)
	_actor_list_opt.item_selected.connect(_on_actor_tool_selected)
	left_panel.add_child(_actor_list_opt)

	left_wrap.add_child(left_panel)
	add_child(left_wrap)

	# RIGHT PANEL: Grid canvas + properties
	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var right_style = StyleBoxFlat.new()
	right_style.bg_color = BG_COLOR
	var right_wrap = PanelContainer.new()
	right_wrap.add_theme_stylebox_override("panel", right_style)
	right_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Level name
	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	var name_lbl = Label.new()
	name_lbl.text = "Level:"
	name_lbl.add_theme_color_override("font_color", LABEL_COLOR)
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_row.add_child(name_lbl)
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.add_theme_font_size_override("font_size", 12)
	_name_edit.text_changed.connect(_on_name_changed)
	name_row.add_child(_name_edit)
	right_panel.add_child(name_row)

	# Grid canvas
	_grid_canvas = Control.new()
	_grid_canvas.custom_minimum_size = Vector2(GRID_W * CELL_SIZE + 2, GRID_H * CELL_SIZE + 2)
	_grid_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_canvas.draw.connect(_draw_grid)
	_grid_canvas.gui_input.connect(_on_grid_input)
	right_panel.add_child(_grid_canvas)

	# Material properties
	var mat_row = HBoxContainer.new()
	mat_row.add_theme_constant_override("separation", 8)
	var fric_lbl = Label.new()
	fric_lbl.text = "Friction:"
	fric_lbl.add_theme_color_override("font_color", LABEL_COLOR)
	fric_lbl.add_theme_font_size_override("font_size", 11)
	mat_row.add_child(fric_lbl)
	_material_friction = HSlider.new()
	_material_friction.min_value = 0
	_material_friction.max_value = 100
	_material_friction.value = 50
	_material_friction.custom_minimum_size.x = 80
	_material_friction.value_changed.connect(_on_friction_changed)
	mat_row.add_child(_material_friction)
	var elast_lbl = Label.new()
	elast_lbl.text = "Elasticity:"
	elast_lbl.add_theme_color_override("font_color", LABEL_COLOR)
	elast_lbl.add_theme_font_size_override("font_size", 11)
	mat_row.add_child(elast_lbl)
	_material_elasticity = HSlider.new()
	_material_elasticity.min_value = 0
	_material_elasticity.max_value = 100
	_material_elasticity.value = 50
	_material_elasticity.custom_minimum_size.x = 80
	_material_elasticity.value_changed.connect(_on_elasticity_changed)
	mat_row.add_child(_material_elasticity)
	right_panel.add_child(mat_row)

	# Status bar
	_status_lbl = Label.new()
	_status_lbl.text = "Click grid to paint blocks — select block type on the left"
	_status_lbl.add_theme_font_size_override("font_size", 10)
	_status_lbl.add_theme_color_override("font_color", LABEL_COLOR)
	right_panel.add_child(_status_lbl)

	right_wrap.add_child(right_panel)
	add_child(right_wrap)

	_refresh_level_list()
	_refresh_ui()


# ─── Drawing ─────────────────────────────────────────────────

func _draw_grid() -> void:
	if not is_instance_valid(_grid_canvas):
		return
	var lvl = levels[selected_level]
	var grid: Array = lvl["grid"]

	# Draw cells
	for y in range(GRID_H):
		for x in range(GRID_W):
			var block_id: int = grid[y][x]
			var rect = Rect2(x * CELL_SIZE, y * CELL_SIZE, CELL_SIZE, CELL_SIZE)
			_grid_canvas.draw_rect(rect, BLOCK_COLORS[block_id])

	# Grid lines
	for x in range(GRID_W + 1):
		_grid_canvas.draw_line(Vector2(x * CELL_SIZE, 0), Vector2(x * CELL_SIZE, GRID_H * CELL_SIZE), GRID_COLOR, 1.0)
	for y in range(GRID_H + 1):
		_grid_canvas.draw_line(Vector2(0, y * CELL_SIZE), Vector2(GRID_W * CELL_SIZE, y * CELL_SIZE), GRID_COLOR, 1.0)

	# Actor markers
	for actor_data in lvl["actors"]:
		var ax: int = actor_data.get("x", 0)
		var ay: int = actor_data.get("y", 0)
		var aid: int = actor_data.get("actor_id", 0)
		var actor_rect = Rect2(ax * CELL_SIZE + 2, ay * CELL_SIZE + 2, CELL_SIZE - 4, CELL_SIZE - 4)
		_grid_canvas.draw_rect(actor_rect, Color(1, 0.8, 0.2, 0.7))
		# Draw actor number
		# (Godot 4 draw_string is complex — use a colored rect + label overlay approach)
		_grid_canvas.draw_rect(Rect2(ax * CELL_SIZE + 4, ay * CELL_SIZE + 4, CELL_SIZE - 8, CELL_SIZE - 8), Color(0, 0, 0, 0.5))

		# Sentry paths
		var path: Array = actor_data.get("path", [])
		if path.size() > 1:
			for i in range(path.size() - 1):
				var p1 = Vector2(path[i].x * CELL_SIZE + CELL_SIZE / 2, path[i].y * CELL_SIZE + CELL_SIZE / 2)
				var p2 = Vector2(path[i + 1].x * CELL_SIZE + CELL_SIZE / 2, path[i + 1].y * CELL_SIZE + CELL_SIZE / 2)
				_grid_canvas.draw_line(p1, p2, Color(1, 0.5, 0, 0.8), 2.0)

	# Trace in progress
	if is_tracing_path and trace_points.size() > 1:
		for i in range(trace_points.size() - 1):
			var p1 = Vector2(trace_points[i].x * CELL_SIZE + CELL_SIZE / 2, trace_points[i].y * CELL_SIZE + CELL_SIZE / 2)
			var p2 = Vector2(trace_points[i + 1].x * CELL_SIZE + CELL_SIZE / 2, trace_points[i + 1].y * CELL_SIZE + CELL_SIZE / 2)
			_grid_canvas.draw_line(p1, p2, Color(1, 1, 0, 0.9), 2.0)


func _on_grid_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_painting = event.pressed
			if event.pressed:
				_paint_at(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Right-click to place actor
			if selected_actor >= 0:
				_place_actor(event.position)
	elif event is InputEventMouseMotion:
		if is_painting:
			_paint_at(event.position)


func _paint_at(pos: Vector2) -> void:
	var gx: int = int(pos.x / float(CELL_SIZE))
	var gy: int = int(pos.y / float(CELL_SIZE))
	if gx < 0 or gx >= GRID_W or gy < 0 or gy >= GRID_H:
		return
	var lvl = levels[selected_level]
	lvl["grid"][gy][gx] = selected_block
	_grid_canvas.queue_redraw()
	_status_lbl.text = "Painted " + BLOCK_NAMES[selected_block] + " at (" + str(gx) + ", " + str(gy) + ")"
	level_changed.emit(selected_level)


func _place_actor(pos: Vector2) -> void:
	var gx: int = int(pos.x / float(CELL_SIZE))
	var gy: int = int(pos.y / float(CELL_SIZE))
	if gx < 0 or gx >= GRID_W or gy < 0 or gy >= GRID_H:
		return
	var lvl = levels[selected_level]
	lvl["actors"].append({"actor_id": selected_actor, "x": gx, "y": gy, "path": []})
	_grid_canvas.queue_redraw()
	var aname = actor_names[selected_actor] if selected_actor < actor_names.size() else "Actor"
	_status_lbl.text = "Placed " + aname + " at (" + str(gx) + ", " + str(gy) + ")"
	level_changed.emit(selected_level)


# ─── Callbacks ───────────────────────────────────────────────

func _on_level_selected(idx: int) -> void:
	selected_level = idx
	_refresh_ui()

func _on_block_selected(idx: int) -> void:
	selected_block = idx
	selected_actor = -1
	_actor_list_opt.selected = 0
	for i in range(_block_btns.size()):
		_block_btns[i].button_pressed = (i == idx)
	_status_lbl.text = "Block: " + BLOCK_NAMES[idx]

func _on_actor_tool_selected(idx: int) -> void:
	if idx == 0:
		selected_actor = -1
		_status_lbl.text = "Block painting mode"
	else:
		selected_actor = idx - 1
		_status_lbl.text = "Right-click grid to place actor — Left-click still paints blocks"

func _on_name_changed(new_text: String) -> void:
	levels[selected_level]["name"] = new_text
	_refresh_level_list()

func _on_friction_changed(val: float) -> void:
	levels[selected_level]["material_friction"] = int(val)

func _on_elasticity_changed(val: float) -> void:
	levels[selected_level]["material_elasticity"] = int(val)

func _on_add_level() -> void:
	# Find first empty level (all cells zero)
	for i in range(levels.size()):
		var all_empty = true
		for row in levels[i]["grid"]:
			for cell in row:
				if cell != BLOCK_EMPTY:
					all_empty = false
					break
			if not all_empty:
				break
		if all_empty and levels[i]["actors"].size() == 0:
			selected_level = i
			_level_list.select(i)
			_refresh_ui()
			_status_lbl.text = "Selected empty level " + str(i + 1)
			return
	_status_lbl.text = "All " + str(MAX_LEVELS) + " levels are in use!"

func _on_dup_level() -> void:
	var next = selected_level + 1
	if next >= MAX_LEVELS:
		_status_lbl.text = "Cannot duplicate — at max level"
		return
	levels[next] = levels[selected_level].duplicate(true)
	levels[next]["name"] = levels[selected_level]["name"] + " (copy)"
	selected_level = next
	_refresh_level_list()
	_level_list.select(selected_level)
	_refresh_ui()

func _on_clear_level() -> void:
	levels[selected_level] = _make_empty_level(selected_level + 1)
	_refresh_ui()
	_status_lbl.text = "Level cleared"

# ─── Refresh ─────────────────────────────────────────────────

func _refresh_level_list() -> void:
	_level_list.clear()
	for i in range(levels.size()):
		var has_content = false
		for row in levels[i]["grid"]:
			for cell in row:
				if cell != BLOCK_EMPTY:
					has_content = true
					break
			if has_content:
				break
		if not has_content and levels[i]["actors"].size() > 0:
			has_content = true
		var prefix = "● " if has_content else "○ "
		_level_list.add_item(prefix + str(i + 1) + ": " + levels[i]["name"])
	if selected_level >= 0 and selected_level < levels.size():
		_level_list.select(selected_level)

func _refresh_ui() -> void:
	if selected_level < 0 or selected_level >= levels.size():
		return
	var lvl = levels[selected_level]
	_name_edit.text = lvl["name"]
	_material_friction.value = lvl["material_friction"]
	_material_elasticity.value = lvl["material_elasticity"]
	if is_instance_valid(_grid_canvas):
		_grid_canvas.queue_redraw()


# ─── Actor Sync ──────────────────────────────────────────────

func set_actor_names(names: Array) -> void:
	actor_names = names.duplicate()
	if is_instance_valid(_actor_list_opt):
		_actor_list_opt.clear()
		_actor_list_opt.add_item("(Blocks mode)")
		for aname in actor_names:
			_actor_list_opt.add_item("👾 " + aname)

# ─── Serialization ───────────────────────────────────────────

func get_data() -> Array:
	return levels.duplicate(true)

func set_data(data: Array) -> void:
	levels = data.duplicate(true)
	while levels.size() < MAX_LEVELS:
		levels.append(_make_empty_level(levels.size() + 1))
	selected_level = 0
	_refresh_level_list()
	_refresh_ui()
