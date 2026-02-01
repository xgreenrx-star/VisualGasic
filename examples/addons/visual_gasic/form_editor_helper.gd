@tool
extends Panel
## Helper panel that enables drag-resize of the parent Window in the editor.
## When this panel is resized in the 2D editor, it updates the parent Window's size.

signal form_resized(new_size: Vector2)

var _last_size := Vector2.ZERO
var _updating := false

func _ready() -> void:
	# Don't set anchors - we want custom sizing for editor drag-resize
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if Engine.is_editor_hint():
		# Initialize size tracking from parent Window
		var parent_window = get_parent()
		if parent_window is Window:
			size = Vector2(parent_window.size)
		_last_size = size

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

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not get_parent() is Window:
		warnings.append("FormEditorHelper should be a child of a Window node")
	return warnings
