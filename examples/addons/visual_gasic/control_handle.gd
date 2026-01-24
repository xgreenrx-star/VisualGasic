@tool
extends Control
## Control Handle - Selection and resize handles for form designer

signal control_moved(ctrl: Control, old_pos: Vector2, new_pos: Vector2)
signal control_resized(ctrl: Control, old_size: Vector2, new_size: Vector2)
signal selected(ctrl: Control, add_to_selection: bool)

var target_control: Control
var is_selected: bool = false
var snap_to_grid: bool = true
var grid_size: int = 8

# Resize handles
enum HandlePosition {
	TOP_LEFT, TOP_CENTER, TOP_RIGHT,
	CENTER_LEFT, CENTER_RIGHT,
	BOTTOM_LEFT, BOTTOM_CENTER, BOTTOM_RIGHT
}

var handle_size: int = 8
var handle_color: Color = Color(0.4, 0.6, 1.0)
var handle_hover_color: Color = Color(0.6, 0.8, 1.0)
var selection_color: Color = Color(0.4, 0.6, 1.0, 0.5)

var handles: Array[Rect2] = []
var hovering_handle: int = -1
var dragging_handle: int = -1
var dragging_control: bool = false
var drag_start_pos: Vector2
var drag_start_control_pos: Vector2
var drag_start_control_size: Vector2

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_PASS
	_update_handles()

func _process(_delta: float) -> void:
	if target_control:
		# Keep handles synchronized with control
		position = target_control.position
		size = target_control.size
		_update_handles()
		queue_redraw()

func _draw() -> void:
	if not is_selected or not target_control:
		return
	
	# Draw selection border
	draw_rect(Rect2(Vector2.ZERO, size), selection_color, false, 2.0)
	
	# Draw resize handles
	for i in handles.size():
		var handle_rect = handles[i]
		var color = handle_hover_color if i == hovering_handle else handle_color
		draw_rect(handle_rect, color, true)
		draw_rect(handle_rect, Color.WHITE, false, 1.0)

func _update_handles() -> void:
	if not target_control:
		return
	
	var w = size.x
	var h = size.y
	var hs = handle_size
	
	handles.clear()
	
	# Top row
	handles.append(Rect2(-hs/2, -hs/2, hs, hs)) # TOP_LEFT
	handles.append(Rect2(w/2 - hs/2, -hs/2, hs, hs)) # TOP_CENTER
	handles.append(Rect2(w - hs/2, -hs/2, hs, hs)) # TOP_RIGHT
	
	# Middle row
	handles.append(Rect2(-hs/2, h/2 - hs/2, hs, hs)) # CENTER_LEFT
	handles.append(Rect2(w - hs/2, h/2 - hs/2, hs, hs)) # CENTER_RIGHT
	
	# Bottom row
	handles.append(Rect2(-hs/2, h - hs/2, hs, hs)) # BOTTOM_LEFT
	handles.append(Rect2(w/2 - hs/2, h - hs/2, hs, hs)) # BOTTOM_CENTER
	handles.append(Rect2(w - hs/2, h - hs/2, hs, hs)) # BOTTOM_RIGHT

func set_selected(selected: bool) -> void:
	is_selected = selected
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not target_control:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if clicking on a handle
				var local_pos = event.position
				dragging_handle = _get_handle_at_position(local_pos)
				
				if dragging_handle >= 0:
					# Start resizing
					drag_start_pos = event.global_position
					drag_start_control_size = target_control.size
					accept_event()
				else:
					# Start moving
					dragging_control = true
					drag_start_pos = event.global_position
					drag_start_control_pos = target_control.position
					accept_event()
					
					# Select control
					selected.emit(target_control, event.shift_pressed)
			else:
				# End drag/resize
				if dragging_control:
					dragging_control = false
					var new_pos = target_control.position
					if new_pos != drag_start_control_pos:
						control_moved.emit(target_control, drag_start_control_pos, new_pos)
				elif dragging_handle >= 0:
					var new_size = target_control.size
					if new_size != drag_start_control_size:
						control_resized.emit(target_control, drag_start_control_size, new_size)
					dragging_handle = -1
	
	elif event is InputEventMouseMotion:
		if dragging_control:
			# Move control
			var delta = event.global_position - drag_start_pos
			var new_pos = drag_start_control_pos + delta
			
			if snap_to_grid:
				new_pos = _snap_position(new_pos)
			
			target_control.position = new_pos
			accept_event()
		
		elif dragging_handle >= 0:
			# Resize control
			var delta = event.global_position - drag_start_pos
			_resize_from_handle(dragging_handle, delta)
			accept_event()
		
		else:
			# Update hover state
			var old_hover = hovering_handle
			hovering_handle = _get_handle_at_position(event.position)
			if old_hover != hovering_handle:
				queue_redraw()
				_update_cursor(hovering_handle)

func _get_handle_at_position(pos: Vector2) -> int:
	for i in handles.size():
		if handles[i].has_point(pos):
			return i
	return -1

func _resize_from_handle(handle_idx: int, delta: Vector2) -> void:
	var new_pos = drag_start_control_pos
	var new_size = drag_start_control_size
	
	match handle_idx:
		HandlePosition.TOP_LEFT:
			new_pos += delta
			new_size -= delta
		HandlePosition.TOP_CENTER:
			new_pos.y += delta.y
			new_size.y -= delta.y
		HandlePosition.TOP_RIGHT:
			new_pos.y += delta.y
			new_size.x += delta.x
			new_size.y -= delta.y
		HandlePosition.CENTER_LEFT:
			new_pos.x += delta.x
			new_size.x -= delta.x
		HandlePosition.CENTER_RIGHT:
			new_size.x += delta.x
		HandlePosition.BOTTOM_LEFT:
			new_pos.x += delta.x
			new_size.x -= delta.x
			new_size.y += delta.y
		HandlePosition.BOTTOM_CENTER:
			new_size.y += delta.y
		HandlePosition.BOTTOM_RIGHT:
			new_size += delta
	
	# Enforce minimum size
	new_size.x = max(new_size.x, 10)
	new_size.y = max(new_size.y, 10)
	
	if snap_to_grid:
		new_pos = _snap_position(new_pos)
		new_size = _snap_size(new_size)
	
	target_control.position = new_pos
	target_control.size = new_size

func _snap_position(pos: Vector2) -> Vector2:
	if not snap_to_grid:
		return pos
	return Vector2(
		round(pos.x / grid_size) * grid_size,
		round(pos.y / grid_size) * grid_size
	)

func _snap_size(sz: Vector2) -> Vector2:
	if not snap_to_grid:
		return sz
	return Vector2(
		round(sz.x / grid_size) * grid_size,
		round(sz.y / grid_size) * grid_size
	)

func _update_cursor(handle_idx: int) -> void:
	match handle_idx:
		HandlePosition.TOP_LEFT, HandlePosition.BOTTOM_RIGHT:
			mouse_default_cursor_shape = CURSOR_FDIAGSIZE
		HandlePosition.TOP_RIGHT, HandlePosition.BOTTOM_LEFT:
			mouse_default_cursor_shape = CURSOR_BDIAGSIZE
		HandlePosition.TOP_CENTER, HandlePosition.BOTTOM_CENTER:
			mouse_default_cursor_shape = CURSOR_VSIZE
		HandlePosition.CENTER_LEFT, HandlePosition.CENTER_RIGHT:
			mouse_default_cursor_shape = CURSOR_HSIZE
		_:
			if dragging_control:
				mouse_default_cursor_shape = CURSOR_MOVE
			else:
				mouse_default_cursor_shape = CURSOR_ARROW
