@tool
extends Panel
## Form Editor Helper - Enables drag-resize and provides design-time tools
## 
## Features:
## - Drag-resize of the parent Window in the editor
## - Snap-to-grid for control placement
## - Alignment toolbar for precise positioning
## - Smart guides when controls align
## - Intercepts custom vg_control drops to avoid MenuBar issues

signal form_resized(new_size: Vector2)

# Grid settings
var grid_enabled: bool = true
var grid_size: int = 8  # Default 8px grid
var show_grid: bool = true
var grid_color: Color = Color(0.3, 0.3, 0.3, 0.5)

# Resize tracking
var _last_size := Vector2.ZERO
var _updating := false

# Alignment toolbar (created in editor)
var _alignment_toolbar: Control = null

func _ready() -> void:
	# Use MOUSE_FILTER_PASS to allow receiving drop data while letting clicks through
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	if Engine.is_editor_hint():
		# Initialize size tracking from parent Window
		var parent_window = get_parent()
		if parent_window is Window:
			size = Vector2(parent_window.size)
		_last_size = size
		
		# Request redraw for grid
		queue_redraw()

## Check if we can accept this drop data (vg_control custom type)
func _can_drop_data(at_position: Vector2, data) -> bool:
	if not Engine.is_editor_hint():
		return false
	if data is Dictionary and data.get("type") == "vg_control":
		return true
	return false

## Handle the drop - instance the scene and add to form root
func _drop_data(at_position: Vector2, data) -> void:
	if not Engine.is_editor_hint():
		return
	if not data is Dictionary or data.get("type") != "vg_control":
		return
	
	var scene_path = data.get("scene_path", "")
	if scene_path.is_empty():
		return
	
	# Get the form root (parent Window)
	var form_root = get_parent()
	if not form_root:
		return
	
	# Load and instance the scene
	var scene = load(scene_path)
	if not scene:
		printerr("VisualGasic: Could not load scene: ", scene_path)
		return
	
	var instance = scene.instantiate()
	if not instance:
		printerr("VisualGasic: Could not instantiate scene: ", scene_path)
		return
	
	# Add to form root (NOT to _FormBackground)
	form_root.add_child(instance, true)  # force_readable_name
	instance.owner = form_root
	
	# Position at drop location, snapped to grid
	if instance is Control:
		var snapped_pos = snap_to_grid(at_position)
		instance.position = snapped_pos
	
	# Set button/label text to match the node name
	var control_name = scene_path.get_file().get_basename()
	if control_name in ["Button", "Label", "CheckBox", "OptionButton"] and "text" in instance:
		instance.text = instance.name
	
	# CRITICAL: Remove the drag meta so _process() doesn't ALSO fire
	# _handle_vg_drop_delayed, which would create a duplicate control
	if Engine.has_meta("_vg_active_drag"):
		Engine.remove_meta("_vg_active_drag")
	
	print("VisualGasic: Dropped ", instance.name, " at ", at_position)
	
	# Select the new node in the editor
	var editor = EditorInterface
	if editor:
		var selection = editor.get_selection()
		if selection:
			selection.clear()
			selection.add_node(instance)

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if _updating:
		return
		
	var parent_window = get_parent()
	if parent_window is Window:
		# Check if our size changed (user dragged resize handles)
		if size != _last_size and size != Vector2.ZERO:
			_updating = true
			# Update the Window's size to match
			parent_window.size = Vector2i(size)
			emit_signal("form_resized", size)
			_last_size = size
			_updating = false
		# Check if Window size changed (via inspector)
		elif Vector2(parent_window.size) != _last_size:
			_last_size = Vector2(parent_window.size)
			size = _last_size

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	if not show_grid or not grid_enabled:
		return
	
	# Draw grid
	var rect_size = size
	for x in range(0, int(rect_size.x), grid_size):
		draw_line(Vector2(x, 0), Vector2(x, rect_size.y), grid_color)
	for y in range(0, int(rect_size.y), grid_size):
		draw_line(Vector2(0, y), Vector2(rect_size.x, y), grid_color)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not get_parent() is Window:
		warnings.append("FormEditorHelper should be a child of a Window node")
	return warnings

# =============================================================================
# SNAP-TO-GRID FUNCTIONS
# =============================================================================

## Snaps a position to the nearest grid point
func snap_to_grid(pos: Vector2) -> Vector2:
	if not grid_enabled:
		return pos
	return Vector2(
		round(pos.x / grid_size) * grid_size,
		round(pos.y / grid_size) * grid_size
	)

## Snaps a control's position to the grid
func snap_control_to_grid(control: Control) -> void:
	if not grid_enabled:
		return
	control.position = snap_to_grid(control.position)

## Snaps all controls in the form to the grid
func snap_all_to_grid() -> void:
	var parent = get_parent()
	if not parent:
		return
	for child in parent.get_children():
		if child is Control and child != self:
			snap_control_to_grid(child)

# =============================================================================
# ALIGNMENT FUNCTIONS
# =============================================================================

## Aligns selected controls to the left edge of the leftmost control
static func align_left(controls: Array) -> void:
	if controls.size() < 2:
		return
	var min_x = INF
	for ctrl in controls:
		if ctrl is Control:
			min_x = min(min_x, ctrl.position.x)
	for ctrl in controls:
		if ctrl is Control:
			ctrl.position.x = min_x

## Aligns selected controls to the right edge of the rightmost control
static func align_right(controls: Array) -> void:
	if controls.size() < 2:
		return
	var max_right = -INF
	for ctrl in controls:
		if ctrl is Control:
			max_right = max(max_right, ctrl.position.x + ctrl.size.x)
	for ctrl in controls:
		if ctrl is Control:
			ctrl.position.x = max_right - ctrl.size.x

## Aligns selected controls to the top edge of the topmost control
static func align_top(controls: Array) -> void:
	if controls.size() < 2:
		return
	var min_y = INF
	for ctrl in controls:
		if ctrl is Control:
			min_y = min(min_y, ctrl.position.y)
	for ctrl in controls:
		if ctrl is Control:
			ctrl.position.y = min_y

## Aligns selected controls to the bottom edge of the bottommost control
static func align_bottom(controls: Array) -> void:
	if controls.size() < 2:
		return
	var max_bottom = -INF
	for ctrl in controls:
		if ctrl is Control:
			max_bottom = max(max_bottom, ctrl.position.y + ctrl.size.y)
	for ctrl in controls:
		if ctrl is Control:
			ctrl.position.y = max_bottom - ctrl.size.y

## Centers selected controls horizontally
static func align_center_h(controls: Array) -> void:
	if controls.size() < 2:
		return
	var total_center = 0.0
	for ctrl in controls:
		if ctrl is Control:
			total_center += ctrl.position.x + ctrl.size.x / 2
	var center = total_center / controls.size()
	for ctrl in controls:
		if ctrl is Control:
			ctrl.position.x = center - ctrl.size.x / 2

## Centers selected controls vertically
static func align_center_v(controls: Array) -> void:
	if controls.size() < 2:
		return
	var total_center = 0.0
	for ctrl in controls:
		if ctrl is Control:
			total_center += ctrl.position.y + ctrl.size.y / 2
	var center = total_center / controls.size()
	for ctrl in controls:
		if ctrl is Control:
			ctrl.position.y = center - ctrl.size.y / 2

## Distributes controls evenly horizontally
static func distribute_horizontal(controls: Array) -> void:
	if controls.size() < 3:
		return
	# Sort by x position
	var sorted_controls = controls.duplicate()
	sorted_controls.sort_custom(func(a, b): return a.position.x < b.position.x)
	
	var first = sorted_controls[0]
	var last = sorted_controls[-1]
	var total_width = (last.position.x + last.size.x) - first.position.x
	var total_control_width = 0.0
	for ctrl in sorted_controls:
		total_control_width += ctrl.size.x
	
	var gap = (total_width - total_control_width) / (controls.size() - 1)
	var current_x = first.position.x
	
	for ctrl in sorted_controls:
		ctrl.position.x = current_x
		current_x += ctrl.size.x + gap

## Distributes controls evenly vertically
static func distribute_vertical(controls: Array) -> void:
	if controls.size() < 3:
		return
	# Sort by y position
	var sorted_controls = controls.duplicate()
	sorted_controls.sort_custom(func(a, b): return a.position.y < b.position.y)
	
	var first = sorted_controls[0]
	var last = sorted_controls[-1]
	var total_height = (last.position.y + last.size.y) - first.position.y
	var total_control_height = 0.0
	for ctrl in sorted_controls:
		total_control_height += ctrl.size.y
	
	var gap = (total_height - total_control_height) / (controls.size() - 1)
	var current_y = first.position.y
	
	for ctrl in sorted_controls:
		ctrl.position.y = current_y
		current_y += ctrl.size.y + gap

## Makes all selected controls the same width as the first selected
static func make_same_width(controls: Array) -> void:
	if controls.size() < 2:
		return
	var target_width = controls[0].size.x
	for ctrl in controls:
		if ctrl is Control:
			ctrl.size.x = target_width

## Makes all selected controls the same height as the first selected
static func make_same_height(controls: Array) -> void:
	if controls.size() < 2:
		return
	var target_height = controls[0].size.y
	for ctrl in controls:
		if ctrl is Control:
			ctrl.size.y = target_height

## Makes all selected controls the same size as the first selected
static func make_same_size(controls: Array) -> void:
	if controls.size() < 2:
		return
	var target_size = controls[0].size
	for ctrl in controls:
		if ctrl is Control:
			ctrl.size = target_size

## Centers a control within its parent
static func center_in_parent(control: Control) -> void:
	var parent = control.get_parent()
	if parent is Control:
		control.position = (parent.size - control.size) / 2
	elif parent is Window:
		control.position = (Vector2(parent.size) - control.size) / 2

# =============================================================================
# GRID SETTINGS
# =============================================================================

func set_grid_size(new_size: int) -> void:
	grid_size = max(1, new_size)
	queue_redraw()

func set_grid_enabled(enabled: bool) -> void:
	grid_enabled = enabled
	queue_redraw()

func set_show_grid(show: bool) -> void:
	show_grid = show
	queue_redraw()

func toggle_grid() -> void:
	grid_enabled = not grid_enabled
	queue_redraw()
