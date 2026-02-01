# VGFormBase.gd - WinForms-style Form Base Class for Visual Gasic
# Provides proper Form lifecycle and WinForms compatibility
extends Window

# Form properties (WinForms-compatible)
var Text: String:
	get: return title
	set(value): 
		title = value
		_update_title_bar()

var FormBorderStyle: int = FormBorderStyleEnum.Sizable:
	set(value):
		FormBorderStyle = value
		_apply_border_style()

var WindowState: int = FormWindowStateEnum.Normal:
	set(value):
		WindowState = value
		_apply_window_state()

var StartPosition: int = FormStartPositionEnum.WindowsDefaultLocation
var ControlBox: bool = true
var MinimizeBox: bool = true
var MaximizeBox: bool = true
var ShowIcon: bool = true
var ShowInTaskbar: bool = true
var TopMost: bool = false
var AcceptButton: Button = null
var CancelButton: Button = null

# Form state tracking
var _form_loaded: bool = false
var _form_shown: bool = false
var _is_modal: bool = false
var _dialog_result: int = DialogResultEnum.None
var _restore_bounds: Rect2
var _auto_scale_base_size: Vector2 = Vector2(5, 13)

# Enums (WinForms-compatible)
enum FormBorderStyleEnum {
	None = 0,
	FixedSingle = 1,
	Fixed3D = 2,
	FixedDialog = 3,
	Sizable = 4,
	FixedToolWindow = 5,
	SizableToolWindow = 6
}

enum FormWindowStateEnum {
	Normal = 0,
	Minimized = 1,
	Maximized = 2
}

enum FormStartPositionEnum {
	Manual = 0,
	CenterScreen = 1,
	WindowsDefaultLocation = 2,
	WindowsDefaultBounds = 3,
	CenterParent = 4
}

enum DialogResultEnum {
	None = 0,
	OK = 1,
	Cancel = 2,
	Abort = 3,
	Retry = 4,
	Ignore = 5,
	Yes = 6,
	No = 7
}

func _init():
	# Initialize window properties
	close_requested.connect(_on_close_requested)
	size_changed.connect(_on_size_changed)
	visibility_changed.connect(_on_visibility_changed)
	
func _ready():
	# Apply initial settings
	_apply_start_position()
	_apply_border_style()
	
	# Call Form_Load if not already called
	if not _form_loaded:
		_form_loaded = true
		if has_method("Form_Load"):
			call("Form_Load")
		_raise_load_event()
	
	# CRITICAL: Wire up control events after InitializeComponent() has run
	# This ensures controls added in InitializeComponent() get their events connected
	call_deferred("_wire_control_events")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_closing()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and visible and not _form_shown:
		_form_shown = true
		if has_method("Form_Shown"):
			call("Form_Shown")
		_raise_shown_event()

# WinForms-style event methods (override in Visual Gasic forms)
func Form_Load():
	pass # Override in derived forms

func Form_Shown():
	pass # Override in derived forms

func Form_Closing(evt):
	pass # Override in derived forms - set evt.Cancel = true to prevent close

func Form_Closed():
	pass # Override in derived forms

func Form_Resize():
	pass # Override in derived forms

# Event raising (for consistency with WinForms)
func _raise_load_event():
	if has_method("OnLoad"):
		call("OnLoad")

func _raise_shown_event():
	if has_method("OnShown"):
		call("OnShown")

func _raise_closing_event() -> bool:
	var evt = {"Cancel": false}
	if has_method("Form_Closing"):
		call("Form_Closing", evt)
	return not evt.Cancel

func _raise_closed_event():
	if has_method("Form_Closed"):
		call("Form_Closed")

# Close handling
func _on_close_requested():
	Close()

func _on_closing():
	var can_close = _raise_closing_event()
	if can_close:
		if _is_modal:
			_dialog_result = DialogResultEnum.Cancel if _dialog_result == DialogResultEnum.None else _dialog_result
		_raise_closed_event()
		queue_free()

# Modal dialog support
func ShowDialog(parent = null) -> int:
	_is_modal = true
	_dialog_result = DialogResultEnum.None
	
	if parent:
		transient = true
		if parent is Window:
			transient_to_focused = parent
	
	show()
	
	# Wait for dialog to close
	while _dialog_result == DialogResultEnum.None and is_inside_tree():
		await get_tree().process_frame
	
	return _dialog_result

# Public methods (WinForms-compatible)
func Show(owner = null):
	if owner and owner is Window:
		transient_to_focused = owner
	show()

func Hide():
	hide()

func Close():
	_on_closing()

func Activate():
	grab_focus()
	move_to_foreground()

func CenterToScreen():
	if DisplayServer.get_screen_count() > 0:
		var screen_size = DisplayServer.screen_get_size()
		position = (screen_size - size) / 2

func CenterToParent():
	var parent_window = get_parent()
	if parent_window and parent_window is Window:
		var parent_pos = parent_window.position
		var parent_size = parent_window.size
		position = parent_pos + (parent_size - size) / 2

# StartPosition handling
func _apply_start_position():
	match StartPosition:
		FormStartPositionEnum.Manual:
			pass # User has set position manually
		FormStartPositionEnum.CenterScreen:
			CenterToScreen()
		FormStartPositionEnum.WindowsDefaultLocation:
			position = Vector2(100, 100) # Default offset
		FormStartPositionEnum.WindowsDefaultBounds:
			position = Vector2(100, 100)
			size = Vector2(300, 300)
		FormStartPositionEnum.CenterParent:
			CenterToParent()

# BorderStyle handling
func _apply_border_style():
	match FormBorderStyle:
		FormBorderStyleEnum.None:
			borderless = true
			unresizable = true
		FormBorderStyleEnum.FixedSingle:
			borderless = false
			unresizable = true
		FormBorderStyleEnum.Fixed3D:
			borderless = false
			unresizable = true
		FormBorderStyleEnum.FixedDialog:
			borderless = false
			unresizable = true
		FormBorderStyleEnum.Sizable:
			borderless = false
			unresizable = false
		FormBorderStyleEnum.FixedToolWindow:
			borderless = false
			unresizable = true
		FormBorderStyleEnum.SizableToolWindow:
			borderless = false
			unresizable = false

# WindowState handling
func _apply_window_state():
	match WindowState:
		FormWindowStateEnum.Normal:
			if _restore_bounds:
				position = _restore_bounds.position
				size = _restore_bounds.size
			mode = Window.MODE_WINDOWED
		FormWindowStateEnum.Minimized:
			mode = Window.MODE_MINIMIZED
		FormWindowStateEnum.Maximized:
			_restore_bounds = Rect2(position, size)
			mode = Window.MODE_MAXIMIZED

# Size changed handling
func _on_size_changed():
	if has_method("Form_Resize"):
		call("Form_Resize")

func _on_visibility_changed():
	if visible and not _form_shown:
		_form_shown = true
		_raise_shown_event()

func _update_title_bar():
	pass # For custom title bars if needed

# CRITICAL: Auto-wire control events (VB6-style)
# This recursively connects signals for all controls based on naming patterns
func _wire_control_events():
	_wire_node_recursive(self)

func _wire_node_recursive(node: Node):
	# Get the node's name for event handler lookup
	var node_name = node.name
	
	# Skip the form itself
	if node == self:
		for child in node.get_children():
			_wire_node_recursive(child)
		return
	
	# Determine signal and event suffix based on node type
	var signal_name = ""
	var event_suffix = ""
	
	if node is BaseButton:
		signal_name = "pressed"
		event_suffix = "Click"
	elif node is LineEdit or node is TextEdit:
		signal_name = "text_changed"
		event_suffix = "Change"
	elif node is Range: # Sliders, ScrollBar, etc.
		signal_name = "value_changed"
		event_suffix = "Change"
	elif node is Timer:
		signal_name = "timeout"
		event_suffix = "Timer"
	elif node is ItemList or node is OptionButton:
		signal_name = "item_selected"
		event_suffix = "Click"
	
	# If we found a signal to connect
	if not signal_name.is_empty() and not event_suffix.is_empty():
		# Build the expected handler name: NodeName_EventSuffix
		var handler_name = node_name + "_" + event_suffix
		
		# Check if the script has this method
		if has_method(handler_name):
			# Connect the signal to the handler
			if node.has_signal(signal_name):
				var callable = Callable(self, handler_name)
				if not node.is_connected(signal_name, callable):
					node.connect(signal_name, callable)
					print("VGFormBase: Auto-wired ", node_name, ".", signal_name, " -> ", handler_name, "()")
	
	# Recurse to children
	for child in node.get_children():
		_wire_node_recursive(child)
