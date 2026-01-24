@tool
extends Control
## Form Canvas - Visual editing surface for form designer
## Handles grid display, control selection, and drag-drop

signal control_selected(controls: Array)
signal control_moved(ctrl: Control, old_pos: Vector2, new_pos: Vector2)
signal control_resized(ctrl: Control, old_size: Vector2, new_size: Vector2)
signal edit_form_menu_requested()

# Grid properties
var grid_enabled: bool = true
var grid_size: int = 8
var grid_color: Color = Color(0.5, 0.5, 0.5, 0.3)
var snap_to_grid: bool = true

# Selection
var selected_controls: Array[Control] = []
var selection_rect: Rect2
var is_dragging_selection: bool = false
var drag_start_pos: Vector2

# Control handles
var control_handles: Dictionary = {} # Control -> ControlHandle

# Current form
var current_form: Node

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(800, 600)
	clip_contents = true

func _draw() -> void:
	if grid_enabled:
		_draw_grid()
	
	# Draw selection rectangle if dragging
	if is_dragging_selection:
		draw_rect(selection_rect, Color(0.4, 0.6, 1.0, 0.3), true)
		draw_rect(selection_rect, Color(0.4, 0.6, 1.0, 0.8), false, 2.0)

func _draw_grid() -> void:
	var canvas_size = size
	
	# Vertical lines
	var x = grid_size
	while x < canvas_size.x:
		draw_line(Vector2(x, 0), Vector2(x, canvas_size.y), grid_color, 1.0)
		x += grid_size
	
	# Horizontal lines
	var y = grid_size
	while y < canvas_size.y:
		draw_line(Vector2(0, y), Vector2(canvas_size.x, y), grid_color, 1.0)
		y += grid_size

func set_form(form: Node) -> void:
	current_form = form
	_clear_handles()
	
	# Create handles for all controls in the form
	for child in form.get_children():
		if child is Control:
			_create_handle_for_control(child)

func add_design_control(ctrl: Control) -> void:
	if not control_handles.has(ctrl):
		_create_handle_for_control(ctrl)

func _create_handle_for_control(ctrl: Control) -> void:
	var handle = load("res://addons/visual_gasic/control_handle.gd").new()
	handle.target_control = ctrl
	handle.snap_to_grid = snap_to_grid
	handle.grid_size = grid_size
	handle.control_moved.connect(_on_handle_moved)
	handle.control_resized.connect(_on_handle_resized)
	handle.selected.connect(_on_handle_selected)
	add_child(handle)
	control_handles[ctrl] = handle

func _clear_handles() -> void:
	for handle in control_handles.values():
		handle.queue_free()
	control_handles.clear()
	selected_controls.clear()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start selection rectangle
				drag_start_pos = event.position
				is_dragging_selection = true
				selection_rect = Rect2(drag_start_pos, Vector2.ZERO)
				
				# Clear selection if clicking on empty area
				if not _is_over_control(event.position):
					_clear_selection()
			else:
				# End selection rectangle
				if is_dragging_selection:
					is_dragging_selection = false
					_select_controls_in_rect()
					queue_redraw()
		
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				# Show context menu
				_show_context_menu(event.global_position)
				accept_event()
	
	elif event is InputEventMouseMotion:
		if is_dragging_selection:
			# Update selection rectangle
			selection_rect = Rect2(drag_start_pos, event.position - drag_start_pos)
			if selection_rect.size.x < 0:
				selection_rect.position.x += selection_rect.size.x
				selection_rect.size.x = abs(selection_rect.size.x)
			if selection_rect.size.y < 0:
				selection_rect.position.y += selection_rect.size.y
				selection_rect.size.y = abs(selection_rect.size.y)
			queue_redraw()
	
	elif event is InputEventKey:
		if event.pressed:
			_handle_keyboard_shortcut(event)

func _show_context_menu(pos: Vector2) -> void:
	"""Show right-click context menu"""
	var popup = PopupMenu.new()
	popup.add_item("Edit Form Menu...", 0)
	popup.add_separator()
	popup.add_item("Properties", 1)
	
	add_child(popup)
	
	popup.id_pressed.connect(func(id):
		match id:
			0: # Edit Form Menu
				edit_form_menu_requested.emit()
			1: # Properties
				pass # TODO: Show properties
		popup.queue_free()
	)
	
	popup.position = Vector2i(pos)
	popup.popup()

func _is_over_control(pos: Vector2) -> bool:
	for ctrl in control_handles.keys():
		var rect = Rect2(ctrl.position, ctrl.size)
		if rect.has_point(pos):
			return true
	return false

func _select_controls_in_rect() -> void:
	selected_controls.clear()
	
	for ctrl in control_handles.keys():
		var ctrl_rect = Rect2(ctrl.position, ctrl.size)
		if selection_rect.intersects(ctrl_rect):
			selected_controls.append(ctrl)
			control_handles[ctrl].set_selected(true)
		else:
			control_handles[ctrl].set_selected(false)
	
	control_selected.emit(selected_controls)

func _clear_selection() -> void:
	selected_controls.clear()
	for handle in control_handles.values():
		handle.set_selected(false)
	control_selected.emit([])

func _handle_keyboard_shortcut(event: InputEventKey) -> void:
	if not event.pressed or selected_controls.is_empty():
		return
	
	var shift = event.shift_pressed
	var ctrl = event.ctrl_pressed
	var delta = 10 if shift else 1
	
	match event.keycode:
		KEY_DELETE:
			_delete_selected_controls()
		KEY_LEFT:
			_move_selected_controls(Vector2(-delta, 0))
		KEY_RIGHT:
			_move_selected_controls(Vector2(delta, 0))
		KEY_UP:
			_move_selected_controls(Vector2(0, -delta))
		KEY_DOWN:
			_move_selected_controls(Vector2(0, delta))
		KEY_C:
			if ctrl:
				_copy_selected_controls()
		KEY_V:
			if ctrl:
				_paste_controls()
		KEY_X:
			if ctrl:
				_cut_selected_controls()

func _delete_selected_controls() -> void:
	for ctrl in selected_controls:
		if ctrl.get_parent():
			ctrl.get_parent().remove_child(ctrl)
			ctrl.queue_free()
		if control_handles.has(ctrl):
			control_handles[ctrl].queue_free()
			control_handles.erase(ctrl)
	selected_controls.clear()

func _move_selected_controls(delta: Vector2) -> void:
	for ctrl in selected_controls:
		var old_pos = ctrl.position
		var new_pos = old_pos + delta
		if snap_to_grid:
			new_pos = _snap_position(new_pos)
		ctrl.position = new_pos
		control_moved.emit(ctrl, old_pos, new_pos)

var clipboard: Array = []

func _copy_selected_controls() -> void:
	clipboard.clear()
	for ctrl in selected_controls:
		clipboard.append({
			"type": ctrl.get_class(),
			"position": ctrl.position,
			"size": ctrl.size,
			"text": ctrl.get("text") if ctrl.has_method("get") else ""
		})
	print("Copied ", clipboard.size(), " controls")

func _paste_controls() -> void:
	# TODO: Create new controls from clipboard
	print("Paste not yet implemented")

func _cut_selected_controls() -> void:
	_copy_selected_controls()
	_delete_selected_controls()

func _snap_position(pos: Vector2) -> Vector2:
	if not snap_to_grid:
		return pos
	return Vector2(
		round(pos.x / grid_size) * grid_size,
		round(pos.y / grid_size) * grid_size
	)

## Signals from handles
func _on_handle_moved(ctrl: Control, old_pos: Vector2, new_pos: Vector2) -> void:
	control_moved.emit(ctrl, old_pos, new_pos)

func _on_handle_resized(ctrl: Control, old_size: Vector2, new_size: Vector2) -> void:
	control_resized.emit(ctrl, old_size, new_size)

func _on_handle_selected(ctrl: Control, add_to_selection: bool) -> void:
	if add_to_selection:
		if not selected_controls.has(ctrl):
			selected_controls.append(ctrl)
			control_handles[ctrl].set_selected(true)
	else:
		selected_controls.clear()
		selected_controls.append(ctrl)
		for c in control_handles.keys():
			control_handles[c].set_selected(c == ctrl)
	
	control_selected.emit(selected_controls)
