@tool
extends Panel
class_name VBForm

## VB6-style Form with proper window behavior
## Handles MenuBar display and window dragging

var _dragging := false
var _drag_offset := Vector2.ZERO

func _ready():
	if not Engine.is_editor_hint():
		# At runtime, ensure form fills the window
		set_anchors_preset(Control.PRESET_FULL_RECT)
		
		# Setup MenuBar if it exists  
		_setup_menubar()
		
		# Enable mouse filter to allow dragging
		mouse_filter = Control.MOUSE_FILTER_PASS

func _setup_menubar():
	"""Ensure MenuBar is properly configured for display"""
	for child in get_children():
		if child is MenuBar:
			# MenuBar should be at top and fill width
			child.set_anchors_preset(Control.PRESET_TOP_WIDE)
			child.offset_left = 0
			child.offset_right = 0
			child.offset_top = 0
			# Move child to be first in order
			move_child(child, 0)
			print("VBForm: MenuBar configured - ", child.get_menu_count(), " menus")
			break

func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	
	# Only allow dragging from empty areas (not on controls)
	var mouse_pos = get_local_mouse_position()
	var clicked_control = _get_control_at_position(mouse_pos)
	
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and not clicked_control:
				_dragging = true
				var window = get_window()
				if window:
					_drag_offset = get_global_mouse_position() - Vector2(window.position)
			else:
				_dragging = false
	
	elif event is InputEventMouseMotion and _dragging:
		var window = get_window()
		if window and window != get_tree().root:
			var new_pos = get_global_mouse_position() - _drag_offset
			window.position = Vector2i(new_pos)

func _get_control_at_position(pos: Vector2) -> Control:
	"""Check if there's a control at this position"""
	for child in get_children():
		if child is Control and child.visible:
			var rect = Rect2(child.position, child.size)
			if rect.has_point(pos):
				return child
	return null

func get_window() -> Window:
	"""Get the Window this form is in"""
	return get_viewport() as Window if get_viewport() else null
