@tool
extends VBoxContainer
## Call Stack Panel for VisualGasic Debugger
##
## Displays the call stack when debugging is paused.
## Click on any frame to navigate to that location in the code.

signal frame_selected(file: String, line: int, function_name: String)

var _tree: Tree
var _debugger_plugin: EditorDebuggerPlugin = null
var _current_stack: Array = []
var _status_label: Label

func _ready() -> void:
	name = "Call Stack"
	_setup_ui()

func _setup_ui() -> void:
	# Header
	var header = HBoxContainer.new()
	add_child(header)
	
	var title = Label.new()
	title.text = "📚 Call Stack"
	header.add_child(title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	var refresh_btn = Button.new()
	refresh_btn.text = "🔄"
	refresh_btn.tooltip_text = "Refresh call stack"
	refresh_btn.pressed.connect(_refresh_stack)
	header.add_child(refresh_btn)
	
	# Status label
	_status_label = Label.new()
	_status_label.text = "Not paused"
	_status_label.add_theme_color_override("font_color", Color.GRAY)
	add_child(_status_label)
	
	# Tree
	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.columns = 3
	_tree.set_column_title(0, "#")
	_tree.set_column_title(1, "Function")
	_tree.set_column_title(2, "Location")
	_tree.column_titles_visible = true
	_tree.set_column_expand(0, false)
	_tree.set_column_custom_minimum_width(0, 30)
	_tree.set_column_expand(1, true)
	_tree.set_column_expand(2, true)
	_tree.select_mode = Tree.SELECT_ROW
	_tree.item_activated.connect(_on_frame_activated)
	add_child(_tree)

func set_debugger_plugin(plugin: EditorDebuggerPlugin) -> void:
	_debugger_plugin = plugin
	if _debugger_plugin:
		if _debugger_plugin.has_signal("call_stack_received"):
			_debugger_plugin.call_stack_received.connect(_on_call_stack_received)
		if _debugger_plugin.has_signal("debug_break_hit"):
			_debugger_plugin.debug_break_hit.connect(_on_debug_break_hit)

func _on_debug_break_hit(file: String, line: int) -> void:
	"""When we hit a breakpoint, request the call stack"""
	_status_label.text = "⏸ Paused at %s:%d" % [file.get_file(), line]
	_status_label.add_theme_color_override("font_color", Color.YELLOW)
	_refresh_stack()

func _refresh_stack() -> void:
	"""Request call stack from the running game"""
	if _debugger_plugin and _debugger_plugin.has_method("request_call_stack"):
		_debugger_plugin.request_call_stack()
	elif _debugger_plugin and _debugger_plugin._active_session:
		_debugger_plugin._active_session.send_message("visualgasic:get_call_stack", [])

func _on_call_stack_received(stack: Array) -> void:
	"""Update the display with the received call stack"""
	_current_stack = stack
	_update_display()

func _update_display() -> void:
	_tree.clear()
	
	if _current_stack.is_empty():
		_status_label.text = "No call stack (running)"
		_status_label.add_theme_color_override("font_color", Color.GRAY)
		return
	
	_status_label.text = "⏸ Paused - %d frames" % _current_stack.size()
	_status_label.add_theme_color_override("font_color", Color.YELLOW)
	
	var root = _tree.create_item()
	
	for i in range(_current_stack.size()):
		var frame = _current_stack[i]
		var item = _tree.create_item(root)
		
		# Frame number (0 = current)
		item.set_text(0, str(i))
		if i == 0:
			item.set_custom_color(0, Color.LIME_GREEN)
		
		# Function name
		var func_name = frame.get("function", "?")
		item.set_text(1, func_name)
		if i == 0:
			item.set_custom_color(1, Color.LIME_GREEN)
		
		# File:Line
		var file_path = frame.get("file", "")
		var line = frame.get("line", 0)
		var location = "%s:%d" % [file_path.get_file(), line] if not file_path.is_empty() else "?"
		item.set_text(2, location)
		if i == 0:
			item.set_custom_color(2, Color.LIME_GREEN)
		
		# Store metadata for navigation
		item.set_metadata(0, {
			"file": file_path,
			"line": line,
			"function": func_name,
			"index": i
		})
	
	# Select the first frame (current location)
	if _tree.get_root() and _tree.get_root().get_first_child():
		_tree.get_root().get_first_child().select(0)

func _on_frame_activated() -> void:
	"""Navigate to the selected stack frame"""
	var selected = _tree.get_selected()
	if not selected:
		return
	
	var meta = selected.get_metadata(0)
	if not meta:
		return
	
	var file_path = meta.get("file", "")
	var line = meta.get("line", 0)
	var func_name = meta.get("function", "")
	
	if not file_path.is_empty() and line > 0:
		_navigate_to_line(file_path, line)
		frame_selected.emit(file_path, line, func_name)

func _navigate_to_line(file_path: String, line: int) -> void:
	"""Navigate to a specific line in the script editor"""
	if file_path.is_empty() or line <= 0:
		return
	
	if not ResourceLoader.exists(file_path):
		return
	
	var script = load(file_path)
	if script:
		EditorInterface.set_main_screen_editor("Script")
		EditorInterface.edit_script(script, line, 0)
		
		# Center on line after a short delay
		call_deferred("_center_on_line", line)

func _center_on_line(line: int) -> void:
	var script_editor = EditorInterface.get_script_editor()
	if not script_editor:
		return
	
	var current_editor = script_editor.get_current_editor()
	if not current_editor:
		return
	
	var code_edit = current_editor.get_base_editor() as CodeEdit
	if code_edit:
		code_edit.set_caret_line(line - 1)
		code_edit.set_caret_column(0)
		code_edit.center_viewport_to_caret()
		code_edit.grab_focus()

func clear_stack() -> void:
	"""Clear the call stack display (when resuming)"""
	_current_stack.clear()
	_tree.clear()
	_status_label.text = "Running..."
	_status_label.add_theme_color_override("font_color", Color.LIME_GREEN)
