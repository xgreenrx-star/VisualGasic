@tool
extends PopupPanel
## Grid Arrange Dialog — Arrange selected controls in a grid pattern
##
## Works with the C++ VisualGasicFormDesigner API:
##   get_control_count(), get_control_info(i), set_control_property(i, key, val)
##
## Features:
## - Live preview as spinners change
## - Auto-detect columns from spatial layout
## - Drag handle to adjust spacing interactively
## - Sort order: by position or by name
## - Optional "Make Same Size" before arranging
## - Cancel restores original positions

signal grid_applied()
signal grid_cancelled()

# --- Controls ---
var _columns_spin: SpinBox
var _h_spacing_spin: SpinBox
var _v_spacing_spin: SpinBox
var _same_size_check: CheckBox
var _sort_option: OptionButton
var _apply_btn: Button
var _cancel_btn: Button
var _status_label: Label
var _drag_handle: Control  # Interactive spacing adjuster

# --- State ---
var _form_designer = null           # VisualGasicFormDesigner C++ instance
var _selected_indices: Array = []   # Indices of selected controls
var _original_rects: Dictionary = {}  # {index: {x, y, width, height}}
var _is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_start_h_spacing: float = 0.0
var _drag_start_v_spacing: float = 0.0

# Sort modes
enum SortMode { BY_POSITION, BY_NAME }

func _ready() -> void:
	size = Vector2(280, 340)
	transparent_bg = false
	_build_ui()

## Set the form designer reference (called from alignment_toolbar)
func setup(form_designer) -> void:
	_form_designer = form_designer

## Opens the dialog for the currently selected controls on the form designer.
## canvas_rect: the global rect of the form canvas — dialog positions beside it.
func open_for_controls(anchor_pos: Vector2 = Vector2.ZERO, canvas_rect: Rect2 = Rect2()) -> void:
	if not _form_designer:
		push_error("[VisualGasic] Grid Arrange: no form designer reference")
		return
	
	# Gather selected control indices from the C++ form designer
	_selected_indices.clear()
	_original_rects.clear()
	var count = _form_designer.get_control_count()
	for i in range(count):
		var info = _form_designer.get_control_info(i)
		if info.get("selected", false):
			_selected_indices.append(i)
			_original_rects[i] = {
				"x": info.get("x", 0.0),
				"y": info.get("y", 0.0),
				"width": info.get("width", 80.0),
				"height": info.get("height", 24.0),
			}
	
	if _selected_indices.size() < 2:
		push_warning("[VisualGasic] Grid Arrange: need 2+ selected controls, got %d" % _selected_indices.size())
		return
	
	# Auto-detect columns from spatial layout
	var detected_cols = _detect_columns()
	_columns_spin.value = detected_cols
	
	# Set reasonable default spacing
	_h_spacing_spin.value = 4
	_v_spacing_spin.value = 4
	
	_update_status()
	
	# Position to the RIGHT of the form canvas so the dialog doesn't block it.
	# If canvas_rect is provided, dock to its right edge.  Otherwise, use the
	# right third of the screen so it's out of the way.
	var dialog_size = Vector2(size)
	var screen_size = Vector2(DisplayServer.screen_get_size())
	var target_pos := Vector2.ZERO
	
	if canvas_rect.size.x > 0:
		# Place flush with the right edge of the canvas, vertically centered
		target_pos.x = canvas_rect.position.x + canvas_rect.size.x - dialog_size.x - 8
		target_pos.y = canvas_rect.position.y + 8
	elif anchor_pos != Vector2.ZERO:
		target_pos = anchor_pos
	else:
		target_pos = (screen_size - dialog_size) / 2
	
	# Clamp to screen bounds
	target_pos.x = clampf(target_pos.x, 0, screen_size.x - dialog_size.x)
	target_pos.y = clampf(target_pos.y, 0, screen_size.y - dialog_size.y)
	
	position = Vector2i(target_pos)
	
	print("[VisualGasic] Grid Arrange: opening for %d controls at %s" % [_selected_indices.size(), str(position)])
	popup(Rect2i(position, Vector2i(size)))
	
	# Apply initial preview
	_apply_preview()

# =============================================================================
# UI CONSTRUCTION
# =============================================================================

func _build_ui() -> void:
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 6)
	
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	margin.add_child(main_vbox)
	
	# --- Title ---
	var title = Label.new()
	title.text = "⊞ Arrange in Grid"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(title)
	
	main_vbox.add_child(HSeparator.new())
	
	# --- Columns ---
	var col_row = _make_row("Columns:", 1, 50, 4)
	_columns_spin = col_row.get_meta("spinbox")
	_columns_spin.value_changed.connect(_on_setting_changed)
	main_vbox.add_child(col_row)
	
	# --- H Spacing ---
	var h_row = _make_row("H Spacing:", 0, 200, 4, "px")
	_h_spacing_spin = h_row.get_meta("spinbox")
	_h_spacing_spin.value_changed.connect(_on_setting_changed)
	main_vbox.add_child(h_row)
	
	# --- V Spacing ---
	var v_row = _make_row("V Spacing:", 0, 200, 4, "px")
	_v_spacing_spin = v_row.get_meta("spinbox")
	_v_spacing_spin.value_changed.connect(_on_setting_changed)
	main_vbox.add_child(v_row)
	
	main_vbox.add_child(HSeparator.new())
	
	# --- Sort Order ---
	var sort_row = HBoxContainer.new()
	var sort_label = Label.new()
	sort_label.text = "Sort:"
	sort_label.custom_minimum_size = Vector2(75, 0)
	sort_row.add_child(sort_label)
	
	_sort_option = OptionButton.new()
	_sort_option.add_item("By Position", SortMode.BY_POSITION)
	_sort_option.add_item("By Name", SortMode.BY_NAME)
	_sort_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sort_option.item_selected.connect(_on_sort_changed)
	sort_row.add_child(_sort_option)
	main_vbox.add_child(sort_row)
	
	# --- Make Same Size checkbox ---
	_same_size_check = CheckBox.new()
	_same_size_check.text = "Make Same Size (use first selected)"
	_same_size_check.button_pressed = false
	_same_size_check.toggled.connect(_on_same_size_toggled)
	main_vbox.add_child(_same_size_check)
	
	main_vbox.add_child(HSeparator.new())
	
	# --- Drag Handle ---
	var drag_label = Label.new()
	drag_label.text = "Drag below to adjust spacing:"
	drag_label.add_theme_font_size_override("font_size", 11)
	drag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(drag_label)
	
	_drag_handle = _build_drag_handle()
	main_vbox.add_child(_drag_handle)
	
	main_vbox.add_child(HSeparator.new())
	
	# --- Status label ---
	_status_label = Label.new()
	_status_label.text = "0 controls → 0×0 grid"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	main_vbox.add_child(_status_label)
	
	# --- Apply / Cancel buttons ---
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 10)
	
	_apply_btn = Button.new()
	_apply_btn.text = "  Apply  "
	_apply_btn.pressed.connect(_on_apply)
	btn_row.add_child(_apply_btn)
	
	_cancel_btn = Button.new()
	_cancel_btn.text = "  Cancel  "
	_cancel_btn.pressed.connect(_on_cancel)
	btn_row.add_child(_cancel_btn)
	
	main_vbox.add_child(btn_row)

func _make_row(label_text: String, min_val: float, max_val: float, default_val: float, suffix: String = "") -> HBoxContainer:
	var row = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(75, 0)
	row.add_child(label)
	
	var spin = SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.value = default_val
	spin.step = 1
	if suffix != "":
		spin.suffix = suffix
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spin)
	
	row.set_meta("spinbox", spin)
	return row

# =============================================================================
# DRAG HANDLE — interactive spacing adjustment
# =============================================================================

func _build_drag_handle() -> Control:
	var handle = Control.new()
	handle.custom_minimum_size = Vector2(0, 40)
	handle.mouse_default_cursor_shape = Control.CURSOR_MOVE
	handle.gui_input.connect(_on_drag_input)
	handle.draw.connect(_on_drag_draw.bind(handle))
	handle.tooltip_text = "Drag: horizontal = H spacing, vertical = V spacing"
	return handle

func _on_drag_draw(handle: Control) -> void:
	var center = handle.size / 2
	var arrow_color = Color(0.7, 0.8, 1.0, 0.8)
	var bg_color = Color(0.15, 0.15, 0.2, 0.6)
	
	handle.draw_rect(Rect2(Vector2.ZERO, handle.size), bg_color)
	
	# Crosshair
	var arm = 14.0
	handle.draw_line(center - Vector2(arm, 0), center + Vector2(arm, 0), arrow_color, 2.0)
	handle.draw_line(center - Vector2(0, arm), center + Vector2(0, arm), arrow_color, 2.0)
	
	# Arrow tips
	var tip = 5.0
	handle.draw_line(center + Vector2(arm, 0), center + Vector2(arm - tip, -tip), arrow_color, 2.0)
	handle.draw_line(center + Vector2(arm, 0), center + Vector2(arm - tip, tip), arrow_color, 2.0)
	handle.draw_line(center - Vector2(arm, 0), center - Vector2(arm - tip, -tip), arrow_color, 2.0)
	handle.draw_line(center - Vector2(arm, 0), center - Vector2(arm - tip, tip), arrow_color, 2.0)
	handle.draw_line(center + Vector2(0, arm), center + Vector2(-tip, arm - tip), arrow_color, 2.0)
	handle.draw_line(center + Vector2(0, arm), center + Vector2(tip, arm - tip), arrow_color, 2.0)
	handle.draw_line(center - Vector2(0, arm), center - Vector2(-tip, arm - tip), arrow_color, 2.0)
	handle.draw_line(center - Vector2(0, arm), center - Vector2(tip, arm - tip), arrow_color, 2.0)
	
	# Label
	var h_val = int(_h_spacing_spin.value) if _h_spacing_spin else 0
	var v_val = int(_v_spacing_spin.value) if _v_spacing_spin else 0
	handle.draw_string(ThemeDB.fallback_font, center + Vector2(20, 4),
		"H:%d V:%d" % [h_val, v_val], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, arrow_color)

func _on_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_dragging = true
				_drag_start_pos = event.global_position
				_drag_start_h_spacing = _h_spacing_spin.value
				_drag_start_v_spacing = _v_spacing_spin.value
			else:
				_is_dragging = false
	
	elif event is InputEventMouseMotion and _is_dragging:
		var delta = event.global_position - _drag_start_pos
		var new_h = clampf(_drag_start_h_spacing + delta.x * 0.5, 0, 200)
		var new_v = clampf(_drag_start_v_spacing + delta.y * 0.5, 0, 200)
		_h_spacing_spin.value = round(new_h)
		_v_spacing_spin.value = round(new_v)
		_drag_handle.queue_redraw()

# =============================================================================
# CALLBACKS
# =============================================================================

func _on_setting_changed(_value: float = 0.0) -> void:
	_update_status()
	_apply_preview()
	_drag_handle.queue_redraw()

func _on_sort_changed(_idx: int) -> void:
	_apply_preview()

func _on_same_size_toggled(_pressed: bool) -> void:
	_apply_preview()

func _on_apply() -> void:
	# Positions are already set via set_control_property (which pushes C++ undo).
	# Just close — the form designer already has the new positions.
	print("[VisualGasic] Grid Arrange: applied to %d controls" % _selected_indices.size())
	emit_signal("grid_applied")
	hide()

func _on_cancel() -> void:
	_restore_original_state()
	emit_signal("grid_cancelled")
	hide()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_cancel()
		get_viewport().set_input_as_handled()

# =============================================================================
# CORE GRID ALGORITHM — operates on C++ form designer data
# =============================================================================

func _apply_preview() -> void:
	if _selected_indices.is_empty() or not _form_designer:
		return
	
	var cols = int(_columns_spin.value)
	if cols < 1:
		cols = 1
	
	var h_spacing = _h_spacing_spin.value
	var v_spacing = _v_spacing_spin.value
	var make_same = _same_size_check.button_pressed
	
	# Get sorted indices
	var sorted_indices = _get_sorted_indices()
	
	# Determine cell size from ORIGINAL rects
	var cell_w: float = 0.0
	var cell_h: float = 0.0
	
	if make_same and sorted_indices.size() > 0:
		# Use the first selected control's original size
		var first = _original_rects[sorted_indices[0]]
		cell_w = first["width"]
		cell_h = first["height"]
		# Resize all to match
		for idx in sorted_indices:
			_form_designer.set_control_property(idx, "width", cell_w)
			_form_designer.set_control_property(idx, "height", cell_h)
	else:
		# Use max size across all selected so they don't overlap
		for idx in sorted_indices:
			var orig = _original_rects[idx]
			cell_w = max(cell_w, orig["width"])
			cell_h = max(cell_h, orig["height"])
	
	# Start position: top-left of bounding box of ORIGINAL positions
	var start_x: float = INF
	var start_y: float = INF
	for idx in sorted_indices:
		var orig = _original_rects[idx]
		start_x = min(start_x, orig["x"])
		start_y = min(start_y, orig["y"])
	if start_x == INF: start_x = 0
	if start_y == INF: start_y = 0
	
	# Place each control in the grid
	for i in range(sorted_indices.size()):
		var idx = sorted_indices[i]
		var row = i / cols
		var col = i % cols
		var new_x = start_x + col * (cell_w + h_spacing)
		var new_y = start_y + row * (cell_h + v_spacing)
		_form_designer.set_control_property(idx, "x", new_x)
		_form_designer.set_control_property(idx, "y", new_y)

func _get_sorted_indices() -> Array:
	var sorted = _selected_indices.duplicate()
	var mode = _sort_option.selected if _sort_option else 0
	
	match mode:
		SortMode.BY_POSITION:
			sorted.sort_custom(func(a, b):
				var a_r = _original_rects[a]
				var b_r = _original_rects[b]
				var row_tolerance = 20.0
				if abs(a_r["y"] - b_r["y"]) < row_tolerance:
					return a_r["x"] < b_r["x"]
				return a_r["y"] < b_r["y"]
			)
		SortMode.BY_NAME:
			sorted.sort_custom(func(a, b):
				var a_info = _form_designer.get_control_info(a)
				var b_info = _form_designer.get_control_info(b)
				return a_info.get("name", "").naturalnocasecmp_to(b_info.get("name", "")) < 0
			)
	
	return sorted

# =============================================================================
# STATE MANAGEMENT
# =============================================================================

func _restore_original_state() -> void:
	if not _form_designer:
		return
	for idx in _original_rects:
		var orig = _original_rects[idx]
		_form_designer.set_control_property(idx, "x", orig["x"])
		_form_designer.set_control_property(idx, "y", orig["y"])
		_form_designer.set_control_property(idx, "width", orig["width"])
		_form_designer.set_control_property(idx, "height", orig["height"])

func _update_status() -> void:
	var count = _selected_indices.size()
	var cols = int(_columns_spin.value)
	if cols < 1:
		cols = 1
	var rows = ceili(float(count) / cols)
	_status_label.text = "%d controls → %d×%d grid (%d cols × %d rows)" % [count, cols, rows, cols, rows]

# =============================================================================
# AUTO-DETECT COLUMNS
# =============================================================================

func _detect_columns() -> int:
	if _selected_indices.size() <= 1:
		return 1
	if _selected_indices.size() <= 3:
		return _selected_indices.size()
	
	# Collect Y positions from original rects
	var y_positions: Array = []
	for idx in _selected_indices:
		var orig = _original_rects[idx]
		y_positions.append(orig["y"])
	
	if y_positions.is_empty():
		return 1
	
	y_positions.sort()
	
	# Group into rows using a tolerance (controls within 20px Y = same row)
	var tolerance = 20.0
	var rows: Array = []
	var current_row: Array = [y_positions[0]]
	
	for i in range(1, y_positions.size()):
		if abs(y_positions[i] - current_row[0]) < tolerance:
			current_row.append(y_positions[i])
		else:
			rows.append(current_row)
			current_row = [y_positions[i]]
	rows.append(current_row)
	
	if rows.is_empty():
		return 1
	
	# Most common row size = likely column count
	var row_sizes: Dictionary = {}
	for row in rows:
		var s = row.size()
		row_sizes[s] = row_sizes.get(s, 0) + 1
	
	var best_cols = 1
	var best_count = 0
	for col_count in row_sizes:
		if row_sizes[col_count] > best_count:
			best_count = row_sizes[col_count]
			best_cols = col_count
	
	return max(1, best_cols)
