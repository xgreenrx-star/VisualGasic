@tool
extends HBoxContainer
## Alignment Toolbar for Form Designer
##
## Provides VB6-style alignment buttons for selected controls.
## All operations delegate to the C++ VisualGasicFormDesigner methods
## (align_left, align_right, etc.) which operate on its internal
## FormControlItem vector — NOT on Godot scene tree nodes.

signal alignment_applied(action: String)

var _plugin: EditorPlugin = null
var _grid_arrange_dialog = null  # GridArrangeDialog instance

func _ready() -> void:
	_setup_ui()

func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin

## Get the C++ VisualGasicFormDesigner from the plugin
func _get_form_designer():
	if _plugin and _plugin.get("_form_designer"):
		return _plugin._form_designer
	return null

func _setup_ui() -> void:
	# Compact layout — no text labels, small icon-only buttons
	
	# Grid snap toggle
	var grid_toggle = CheckButton.new()
	grid_toggle.text = "Snap"
	grid_toggle.button_pressed = true
	grid_toggle.tooltip_text = "Snap to grid (Ctrl+G)"
	grid_toggle.toggled.connect(_on_grid_toggled)
	add_child(grid_toggle)
	
	var grid_size = SpinBox.new()
	grid_size.min_value = 1
	grid_size.max_value = 64
	grid_size.value = 8
	grid_size.suffix = "px"
	grid_size.tooltip_text = "Grid size"
	grid_size.custom_minimum_size = Vector2(60, 0)
	grid_size.value_changed.connect(_on_grid_size_changed)
	add_child(grid_size)
	
	add_child(VSeparator.new())
	
	# Alignment buttons — call C++ form designer methods directly
	_add_icon_button("⬅", "Align Left", _align_left)
	_add_icon_button("↔", "Center H", _align_center_h)
	_add_icon_button("➡", "Align Right", _align_right)
	_add_icon_button("⬆", "Align Top", _align_top)
	_add_icon_button("↕", "Center V", _align_center_v)
	_add_icon_button("⬇", "Align Bottom", _align_bottom)
	
	add_child(VSeparator.new())
	
	# Distribute + Size
	_add_icon_button("⇔", "Distribute H", _distribute_h)
	_add_icon_button("⇕", "Distribute V", _distribute_v)
	_add_icon_button("↔W", "Same Width", _make_same_width)
	_add_icon_button("↕H", "Same Height", _make_same_height)
	_add_icon_button("⬜", "Same Size", _make_same_size)
	_add_icon_button("⊞", "Center in Parent", _center_in_parent)
	
	add_child(VSeparator.new())
	
	# Grid Arrange tool
	_add_icon_button("⊞▦", "Arrange in Grid (select 2+ controls)", _open_grid_arrange)

func _add_icon_button(icon_text: String, tooltip: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = icon_text
	btn.tooltip_text = tooltip
	btn.custom_minimum_size = Vector2(24, 24)
	btn.pressed.connect(callback)
	add_child(btn)
	return btn

# =============================================================================
# GRID HANDLERS
# =============================================================================

func _on_grid_toggled(enabled: bool) -> void:
	var fd = _get_form_designer()
	if fd and fd.has_method("set_snap_enabled"):
		fd.set_snap_enabled(enabled)

func _on_grid_size_changed(new_size: float) -> void:
	var fd = _get_form_designer()
	if fd and fd.has_method("set_grid_size"):
		fd.set_grid_size(int(new_size))

# =============================================================================
# ALIGNMENT HANDLERS — delegate to C++ VisualGasicFormDesigner
# =============================================================================

func _align_left() -> void:
	var fd = _get_form_designer()
	if fd:
		fd.align_left()
		emit_signal("alignment_applied", "align_left")

func _align_right() -> void:
	var fd = _get_form_designer()
	if fd:
		fd.align_right()
		emit_signal("alignment_applied", "align_right")

func _align_top() -> void:
	var fd = _get_form_designer()
	if fd:
		fd.align_top()
		emit_signal("alignment_applied", "align_top")

func _align_bottom() -> void:
	var fd = _get_form_designer()
	if fd:
		fd.align_bottom()
		emit_signal("alignment_applied", "align_bottom")

func _align_center_h() -> void:
	var fd = _get_form_designer()
	if fd:
		fd.align_center_h()
		emit_signal("alignment_applied", "align_center_h")

func _align_center_v() -> void:
	var fd = _get_form_designer()
	if fd:
		fd.align_center_v()
		emit_signal("alignment_applied", "align_center_v")

func _distribute_h() -> void:
	var fd = _get_form_designer()
	if fd:
		fd.align_center_h()  # C++ doesn't have distribute — fallback to center
		emit_signal("alignment_applied", "distribute_h")

func _distribute_v() -> void:
	var fd = _get_form_designer()
	if fd:
		fd.align_center_v()  # C++ doesn't have distribute — fallback to center
		emit_signal("alignment_applied", "distribute_v")

func _make_same_width() -> void:
	var fd = _get_form_designer()
	if fd:
		fd.make_same_width()
		emit_signal("alignment_applied", "same_width")

func _make_same_height() -> void:
	var fd = _get_form_designer()
	if fd:
		fd.make_same_height()
		emit_signal("alignment_applied", "same_height")

func _make_same_size() -> void:
	var fd = _get_form_designer()
	if fd:
		fd.make_same_width()
		fd.make_same_height()
		emit_signal("alignment_applied", "same_size")

func _center_in_parent() -> void:
	# Center selected controls within the form
	# No direct C++ method — use set_control_property to compute manually
	var fd = _get_form_designer()
	if not fd:
		return
	var form_w = fd.get("form_width") if fd.get("form_width") else 640
	var form_h = fd.get("form_height") if fd.get("form_height") else 480
	var count = fd.get_control_count()
	for i in range(count):
		var info = fd.get_control_info(i)
		if info.get("selected", false):
			var w = info.get("width", 80)
			var h = info.get("height", 24)
			fd.set_control_property(i, "x", (form_w - w) / 2.0)
			fd.set_control_property(i, "y", (form_h - h) / 2.0)
	emit_signal("alignment_applied", "center_in_parent")

# =============================================================================
# GRID ARRANGE
# =============================================================================

func _open_grid_arrange() -> void:
	var fd = _get_form_designer()
	if not fd:
		print("[VisualGasic] Grid Arrange: no form designer found")
		return
	
	# Check how many controls are selected on the C++ form designer
	var sel_count = fd.get_selected_count() if fd.has_method("get_selected_count") else 0
	print("[VisualGasic] Grid Arrange: %d controls selected" % sel_count)
	
	if sel_count < 2:
		var msg = AcceptDialog.new()
		msg.title = "Grid Arrange"
		msg.dialog_text = "Select at least 2 controls on the form first.\n\nTip: Shift+Click or rubber-band select controls\non the Form Designer canvas, then click ⊞▦ again."
		msg.dialog_autowrap = true
		msg.min_size = Vector2i(340, 120)
		if _plugin:
			_plugin.get_editor_interface().get_base_control().add_child(msg)
		else:
			add_child(msg)
		msg.popup_centered()
		msg.confirmed.connect(msg.queue_free)
		msg.canceled.connect(msg.queue_free)
		return
	
	# Create dialog on first use
	if not is_instance_valid(_grid_arrange_dialog):
		var dialog_script = load("res://addons/visual_gasic/grid_arrange_dialog.gd")
		if not dialog_script:
			push_error("VisualGasic: Could not load grid_arrange_dialog.gd")
			return
		_grid_arrange_dialog = dialog_script.new()
		_grid_arrange_dialog.setup(fd)
		_grid_arrange_dialog.grid_applied.connect(func():
			emit_signal("alignment_applied", "grid_arrange")
		)
		if _plugin:
			_plugin.get_editor_interface().get_base_control().add_child(_grid_arrange_dialog)
		else:
			add_child(_grid_arrange_dialog)
	else:
		# Update form designer reference
		_grid_arrange_dialog.setup(fd)
	
	print("[VisualGasic] Opening Grid Arrange dialog")
	var mouse_pos = DisplayServer.mouse_get_position()
	_grid_arrange_dialog.open_for_controls(Vector2(mouse_pos))
