@tool
extends HBoxContainer
## Alignment Toolbar for Form Designer
##
## Provides VB6-style alignment buttons for selected controls:
## - Align Left/Center/Right
## - Align Top/Middle/Bottom
## - Distribute Horizontally/Vertically
## - Make Same Width/Height/Size
## - Snap to Grid

signal alignment_applied(action: String)

var _plugin: EditorPlugin = null
var _grid_arrange_dialog = null  # GridArrangeDialog instance

func _ready() -> void:
	_setup_ui()

func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin

func _setup_ui() -> void:
	# Compact layout — no text labels, small icon-only buttons
	# Total width target: ~220px (was ~500px)
	
	# Grid snap toggle (compact CheckButton, no label)
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
	grid_size.custom_minimum_size = Vector2(60, 0)  # Compact
	grid_size.value_changed.connect(_on_grid_size_changed)
	add_child(grid_size)
	
	add_child(VSeparator.new())
	
	# Alignment buttons — icon only, no "Align:" label
	_add_icon_button("⬅", "Align Left", _align_left)
	_add_icon_button("↔", "Center H", _align_center_h)
	_add_icon_button("➡", "Align Right", _align_right)
	_add_icon_button("⬆", "Align Top", _align_top)
	_add_icon_button("↕", "Center V", _align_center_v)
	_add_icon_button("⬇", "Align Bottom", _align_bottom)
	
	add_child(VSeparator.new())
	
	# Distribute + Size — icon only, no labels
	_add_icon_button("⇔", "Distribute H", _distribute_h)
	_add_icon_button("⇕", "Distribute V", _distribute_v)
	_add_icon_button("↔W", "Same Width", _make_same_width)
	_add_icon_button("↕H", "Same Height", _make_same_height)
	_add_icon_button("⬜", "Same Size", _make_same_size)
	_add_icon_button("⊞", "Center in Parent", _center_in_parent)
	
	add_child(VSeparator.new())
	
	# Grid Arrange tool
	var grid_btn = _add_icon_button("⊞▦", "Arrange in Grid (select 2+ controls)", _open_grid_arrange)
	grid_btn.tooltip_text = "Arrange selected controls in a grid pattern"

func _add_button(text: String, tooltip: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.tooltip_text = tooltip
	btn.pressed.connect(callback)
	add_child(btn)
	return btn

func _add_icon_button(icon_text: String, tooltip: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = icon_text
	btn.tooltip_text = tooltip
	btn.custom_minimum_size = Vector2(24, 24)
	btn.pressed.connect(callback)
	add_child(btn)
	return btn

func _get_selected_controls() -> Array:
	if not _plugin:
		return []
	var selection = _plugin.get_editor_interface().get_selection()
	var nodes = selection.get_selected_nodes()
	var controls: Array = []
	for node in nodes:
		if node is Control:
			controls.append(node)
	return controls

func _get_form_helper() -> Node:
	"""Find the FormEditorHelper in the current scene"""
	if not _plugin:
		return null
	var root = _plugin.get_editor_interface().get_edited_scene_root()
	if not root:
		return null
	for child in root.get_children():
		if child.name == "_FormBackground":
			return child
	return null

# =============================================================================
# GRID HANDLERS
# =============================================================================

func _on_grid_toggled(enabled: bool) -> void:
	var helper = _get_form_helper()
	if helper and helper.has_method("set_grid_enabled"):
		helper.set_grid_enabled(enabled)

func _on_grid_size_changed(new_size: float) -> void:
	var helper = _get_form_helper()
	if helper and helper.has_method("set_grid_size"):
		helper.set_grid_size(int(new_size))

# =============================================================================
# ALIGNMENT HANDLERS
# =============================================================================

func _align_left() -> void:
	var controls = _get_selected_controls()
	if controls.size() >= 2:
		var FormHelper = load("res://addons/visual_gasic/form_editor_helper.gd")
		FormHelper.align_left(controls)
		emit_signal("alignment_applied", "align_left")

func _align_right() -> void:
	var controls = _get_selected_controls()
	if controls.size() >= 2:
		var FormHelper = load("res://addons/visual_gasic/form_editor_helper.gd")
		FormHelper.align_right(controls)
		emit_signal("alignment_applied", "align_right")

func _align_top() -> void:
	var controls = _get_selected_controls()
	if controls.size() >= 2:
		var FormHelper = load("res://addons/visual_gasic/form_editor_helper.gd")
		FormHelper.align_top(controls)
		emit_signal("alignment_applied", "align_top")

func _align_bottom() -> void:
	var controls = _get_selected_controls()
	if controls.size() >= 2:
		var FormHelper = load("res://addons/visual_gasic/form_editor_helper.gd")
		FormHelper.align_bottom(controls)
		emit_signal("alignment_applied", "align_bottom")

func _align_center_h() -> void:
	var controls = _get_selected_controls()
	if controls.size() >= 2:
		var FormHelper = load("res://addons/visual_gasic/form_editor_helper.gd")
		FormHelper.align_center_h(controls)
		emit_signal("alignment_applied", "align_center_h")

func _align_center_v() -> void:
	var controls = _get_selected_controls()
	if controls.size() >= 2:
		var FormHelper = load("res://addons/visual_gasic/form_editor_helper.gd")
		FormHelper.align_center_v(controls)
		emit_signal("alignment_applied", "align_center_v")

func _distribute_h() -> void:
	var controls = _get_selected_controls()
	if controls.size() >= 3:
		var FormHelper = load("res://addons/visual_gasic/form_editor_helper.gd")
		FormHelper.distribute_horizontal(controls)
		emit_signal("alignment_applied", "distribute_h")

func _distribute_v() -> void:
	var controls = _get_selected_controls()
	if controls.size() >= 3:
		var FormHelper = load("res://addons/visual_gasic/form_editor_helper.gd")
		FormHelper.distribute_vertical(controls)
		emit_signal("alignment_applied", "distribute_v")

func _make_same_width() -> void:
	var controls = _get_selected_controls()
	if controls.size() >= 2:
		var FormHelper = load("res://addons/visual_gasic/form_editor_helper.gd")
		FormHelper.make_same_width(controls)
		emit_signal("alignment_applied", "same_width")

func _make_same_height() -> void:
	var controls = _get_selected_controls()
	if controls.size() >= 2:
		var FormHelper = load("res://addons/visual_gasic/form_editor_helper.gd")
		FormHelper.make_same_height(controls)
		emit_signal("alignment_applied", "same_height")

func _make_same_size() -> void:
	var controls = _get_selected_controls()
	if controls.size() >= 2:
		var FormHelper = load("res://addons/visual_gasic/form_editor_helper.gd")
		FormHelper.make_same_size(controls)
		emit_signal("alignment_applied", "same_size")

func _center_in_parent() -> void:
	var controls = _get_selected_controls()
	if controls.size() >= 1:
		var FormHelper = load("res://addons/visual_gasic/form_editor_helper.gd")
		for ctrl in controls:
			FormHelper.center_in_parent(ctrl)
		emit_signal("alignment_applied", "center_in_parent")

# =============================================================================
# GRID ARRANGE
# =============================================================================

func _open_grid_arrange() -> void:
	print("[VisualGasic] Grid Arrange button pressed")
	var controls = _get_selected_controls()
	print("[VisualGasic] Selected controls: ", controls.size())
	if controls.size() < 2:
		# Show a visible warning — printerr goes to the Output tab where nobody looks
		var msg = AcceptDialog.new()
		msg.title = "Grid Arrange"
		msg.dialog_text = "Select at least 2 controls on the form first.\n\nTip: Shift+Click or Ctrl+Click controls in the Scene tree,\nor drag-select on the form, then click ⊞▦ again."
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
		_grid_arrange_dialog.setup(_plugin)
		_grid_arrange_dialog.grid_applied.connect(func():
			emit_signal("alignment_applied", "grid_arrange")
		)
		# Add to the editor root so it appears above everything
		if _plugin:
			_plugin.get_editor_interface().get_base_control().add_child(_grid_arrange_dialog)
		else:
			add_child(_grid_arrange_dialog)
	
	print("[VisualGasic] Opening Grid Arrange dialog for ", controls.size(), " controls")
	# Open with the selected controls, positioned near the mouse
	var mouse_pos = DisplayServer.mouse_get_position()
	_grid_arrange_dialog.open_for_controls(controls, Vector2(mouse_pos))
