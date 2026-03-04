@tool
extends PopupPanel
## Grid Arrange Dialog — Arrange selected controls in a grid pattern
##
## Features:
## - Live preview as spinners change
## - Auto-detect columns from spatial layout
## - Drag handle to adjust spacing interactively
## - Sort order: by position, by name, or by selection order
## - Optional "Make Same Size" before arranging
## - Apply / Cancel with full undo support

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
var _controls: Array = []           # The controls being arranged
var _original_positions: Dictionary = {}  # {control_instance_id: Vector2}
var _original_sizes: Dictionary = {}      # {control_instance_id: Vector2}
var _is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_start_h_spacing: float = 0.0
var _drag_start_v_spacing: float = 0.0
var _plugin: EditorPlugin = null

# Sort modes
enum SortMode { BY_POSITION, BY_NAME }

func _ready() -> void:
	# Don't show title bar clutter — PopupPanel is clean
	size = Vector2(280, 340)
	transparent_bg = false
	_build_ui()

func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin

## Opens the dialog for the given set of controls
func open_for_controls(controls: Array, anchor_pos: Vector2 = Vector2.ZERO) -> void:
	_controls = controls
	_save_original_state()
	
	# Auto-detect columns from spatial layout
	var detected_cols = _detect_columns(controls)
	_columns_spin.value = detected_cols
	
	# Set reasonable default spacing
	_h_spacing_spin.value = 4
	_v_spacing_spin.value = 4
	
	# Update status
	_update_status()
	
	# Position near the toolbar or mouse
	if anchor_pos != Vector2.ZERO:
		position = Vector2i(anchor_pos)
	else:
		# Center on screen
		var screen_size = DisplayServer.screen_get_size()
		position = Vector2i((Vector2(screen_size) - Vector2(size)) / 2)
	
	print("[VisualGasic] Grid Arrange: popup() with %d controls, pos=%s, size=%s" % [controls.size(), str(position), str(size)])
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
	
	# Add margins
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
	# Draw a crosshair icon so user knows it's draggable
	var center = handle.size / 2
	var arrow_color = Color(0.7, 0.8, 1.0, 0.8)
	var bg_color = Color(0.15, 0.15, 0.2, 0.6)
	
	# Background
	handle.draw_rect(Rect2(Vector2.ZERO, handle.size), bg_color)
	
	# Crosshair
	var arm = 14.0
	handle.draw_line(center - Vector2(arm, 0), center + Vector2(arm, 0), arrow_color, 2.0)
	handle.draw_line(center - Vector2(0, arm), center + Vector2(0, arm), arrow_color, 2.0)
	
	# Arrow tips
	var tip = 5.0
	# Right
	handle.draw_line(center + Vector2(arm, 0), center + Vector2(arm - tip, -tip), arrow_color, 2.0)
	handle.draw_line(center + Vector2(arm, 0), center + Vector2(arm - tip, tip), arrow_color, 2.0)
	# Left
	handle.draw_line(center - Vector2(arm, 0), center - Vector2(arm - tip, -tip), arrow_color, 2.0)
	handle.draw_line(center - Vector2(arm, 0), center - Vector2(arm - tip, tip), arrow_color, 2.0)
	# Down
	handle.draw_line(center + Vector2(0, arm), center + Vector2(-tip, arm - tip), arrow_color, 2.0)
	handle.draw_line(center + Vector2(0, arm), center + Vector2(tip, arm - tip), arrow_color, 2.0)
	# Up
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
		# Horizontal drag → H spacing, Vertical drag → V spacing
		# Scale: 1px mouse = 0.5px spacing for fine control
		var new_h = clampf(_drag_start_h_spacing + delta.x * 0.5, 0, 200)
		var new_v = clampf(_drag_start_v_spacing + delta.y * 0.5, 0, 200)
		_h_spacing_spin.value = round(new_h)
		_v_spacing_spin.value = round(new_v)
		# Spinners fire value_changed → _on_setting_changed → _apply_preview
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
	# Positions are already set by live preview — just close
	# Wrap in undo action if we have a plugin
	if _plugin:
		var undo_redo = _plugin.get_undo_redo()
		if undo_redo:
			undo_redo.create_action("Arrange in Grid")
			for ctrl in _controls:
				if ctrl is Control:
					var cid = ctrl.get_instance_id()
					var orig_pos = _original_positions.get(cid, ctrl.position)
					var orig_size = _original_sizes.get(cid, ctrl.size)
					var new_pos = ctrl.position
					var new_size = ctrl.size
					undo_redo.add_do_property(ctrl, "position", new_pos)
					undo_redo.add_do_property(ctrl, "size", new_size)
					undo_redo.add_undo_property(ctrl, "position", orig_pos)
					undo_redo.add_undo_property(ctrl, "size", orig_size)
			undo_redo.commit_action(false)
	
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
# CORE GRID ALGORITHM
# =============================================================================

func _apply_preview() -> void:
	if _controls.is_empty():
		return
	
	var cols = int(_columns_spin.value)
	if cols < 1:
		cols = 1
	
	var h_spacing = _h_spacing_spin.value
	var v_spacing = _v_spacing_spin.value
	var make_same = _same_size_check.button_pressed
	
	# Sort controls
	var sorted_controls = _get_sorted_controls()
	
	# Determine cell size
	var cell_w: float = 0.0
	var cell_h: float = 0.0
	
	if make_same and sorted_controls.size() > 0:
		# Use the first control's size for all
		cell_w = sorted_controls[0].size.x
		cell_h = sorted_controls[0].size.y
		for ctrl in sorted_controls:
			if ctrl is Control:
				ctrl.size = Vector2(cell_w, cell_h)
	else:
		# Use max size across all controls so they don't overlap
		for ctrl in sorted_controls:
			if ctrl is Control:
				cell_w = max(cell_w, ctrl.size.x)
				cell_h = max(cell_h, ctrl.size.y)
	
	# Start position: use the top-left of the bounding box of original positions
	var start_x: float = INF
	var start_y: float = INF
	for ctrl in sorted_controls:
		if ctrl is Control:
			var cid = ctrl.get_instance_id()
			var orig = _original_positions.get(cid, ctrl.position)
			start_x = min(start_x, orig.x)
			start_y = min(start_y, orig.y)
	
	if start_x == INF:
		start_x = 0
	if start_y == INF:
		start_y = 0
	
	# Place each control
	for i in range(sorted_controls.size()):
		var ctrl = sorted_controls[i]
		if not ctrl is Control:
			continue
		var row = i / cols
		var col = i % cols
		ctrl.position = Vector2(
			start_x + col * (cell_w + h_spacing),
			start_y + row * (cell_h + v_spacing)
		)

func _get_sorted_controls() -> Array:
	var sorted = _controls.duplicate()
	var mode = _sort_option.selected if _sort_option else 0
	
	match mode:
		SortMode.BY_POSITION:
			# Sort top-to-bottom, left-to-right using ORIGINAL positions
			sorted.sort_custom(func(a, b):
				var a_pos = _original_positions.get(a.get_instance_id(), a.position)
				var b_pos = _original_positions.get(b.get_instance_id(), b.position)
				# Row-major: compare Y first (with tolerance), then X
				var row_tolerance = 20.0  # Controls within 20px Y are "same row"
				if abs(a_pos.y - b_pos.y) < row_tolerance:
					return a_pos.x < b_pos.x
				return a_pos.y < b_pos.y
			)
		SortMode.BY_NAME:
			sorted.sort_custom(func(a, b):
				return a.name.naturalnocasecmp_to(b.name) < 0
			)
	
	return sorted

# =============================================================================
# STATE MANAGEMENT
# =============================================================================

func _save_original_state() -> void:
	_original_positions.clear()
	_original_sizes.clear()
	for ctrl in _controls:
		if ctrl is Control:
			var cid = ctrl.get_instance_id()
			_original_positions[cid] = ctrl.position
			_original_sizes[cid] = ctrl.size

func _restore_original_state() -> void:
	for ctrl in _controls:
		if ctrl is Control:
			var cid = ctrl.get_instance_id()
			if cid in _original_positions:
				ctrl.position = _original_positions[cid]
			if cid in _original_sizes:
				ctrl.size = _original_sizes[cid]

func _update_status() -> void:
	var count = _controls.size()
	var cols = int(_columns_spin.value)
	if cols < 1:
		cols = 1
	var rows = ceili(float(count) / cols)
	_status_label.text = "%d controls → %d×%d grid (%d cols × %d rows)" % [count, cols, rows, cols, rows]

# =============================================================================
# AUTO-DETECT COLUMNS
# =============================================================================

func _detect_columns(controls: Array) -> int:
	"""Detect the number of columns by analyzing the spatial layout of controls.
	Groups controls into rows by Y-coordinate proximity, then returns the
	most common row width."""
	if controls.size() <= 1:
		return 1
	if controls.size() <= 3:
		return controls.size()
	
	# Collect Y positions
	var y_positions: Array = []
	for ctrl in controls:
		if ctrl is Control:
			y_positions.append(ctrl.position.y)
	
	if y_positions.is_empty():
		return 1
	
	y_positions.sort()
	
	# Group into rows using a tolerance (controls within 20px Y = same row)
	var tolerance = 20.0
	var rows: Array = []  # Array of Arrays
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
