@tool
extends VBoxContainer

var editor_plugin: EditorPlugin
var object_list: OptionButton
var event_list: OptionButton
var refresh_button: Button
var _debugger_plugin: EditorDebuggerPlugin = null
var _current_break_file: String = ""
var _current_break_line: int = 0
const REFRESH_TEXT = "Refresh Object List"
const REFRESH_TEXT_THRESHOLD := 220

# Standard VB6 Events
const EVENTS_COMMON = ["Click", "DblClick", "MouseDown", "MouseUp", "MouseMove", "KeyDown", "KeyUp", "KeyPress"]
const EVENTS_BUTTON = ["Click", "MouseDown", "MouseUp", "MouseMove", "KeyDown", "KeyUp", "KeyPress"] # Buttons often don't DoubleClick easily
const EVENTS_TEXT = ["Change", "Click", "MouseDown", "MouseUp", "MouseMove", "KeyDown", "KeyUp", "KeyPress"]
const EVENTS_TIMER = ["Timer"]
const EVENTS_SCROLL = ["Change", "Scroll"]
const EVENTS_FORM = ["Load", "Unload", "Click", "MouseDown", "MouseUp", "MouseMove", "KeyDown", "KeyUp", "KeyPress", "Resize"]

func _init():
	name = "Code Navigator"
	custom_minimum_size = Vector2(0, 80)
	
	# Object Row
	var hbox_obj = HBoxContainer.new()
	var lbl_obj = Label.new()
	lbl_obj.text = "Object:"
	lbl_obj.custom_minimum_size.x = 50
	object_list = OptionButton.new()
	object_list.size_flags_horizontal = SIZE_EXPAND_FILL
	object_list.item_selected.connect(_on_object_selected)
	
	hbox_obj.add_child(lbl_obj)
	hbox_obj.add_child(object_list)
	add_child(hbox_obj)
	
	# Event Row
	var hbox_evt = HBoxContainer.new()
	var lbl_evt = Label.new()
	lbl_evt.text = "Event:"
	lbl_evt.custom_minimum_size.x = 50
	event_list = OptionButton.new()
	event_list.size_flags_horizontal = SIZE_EXPAND_FILL
	event_list.item_selected.connect(_on_event_selected)
	
	hbox_evt.add_child(lbl_evt)
	hbox_evt.add_child(event_list)
	add_child(hbox_evt)
	
	# Refresh Button (Optional, but useful)
	refresh_button = Button.new()
	refresh_button.tooltip_text = REFRESH_TEXT
	refresh_button.size_flags_horizontal = SIZE_SHRINK_CENTER
	refresh_button.custom_minimum_size = Vector2(28, 28)
	refresh_button.clip_text = true
	refresh_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	refresh_button.pressed.connect(refresh_objects)
	_set_refresh_icon()
	_update_refresh_mode()
	add_child(refresh_button)

func _notification(what):
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_READY:
		_set_refresh_icon()
		_update_refresh_mode()
	elif what == NOTIFICATION_RESIZED:
		_update_refresh_mode()

func _set_refresh_icon():
	if not refresh_button:
		return
	var icon = refresh_button.get_theme_icon("Reload", "EditorIcons")
	if icon:
		refresh_button.icon = icon
	else:
		refresh_button.icon = null

func _update_refresh_mode():
	if not refresh_button:
		return
	var available_width = get_size().x
	if available_width >= REFRESH_TEXT_THRESHOLD:
		refresh_button.text = REFRESH_TEXT
		refresh_button.size_flags_horizontal = SIZE_EXPAND_FILL
		refresh_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		refresh_button.expand_icon = false
	else:
		refresh_button.text = ""
		refresh_button.size_flags_horizontal = SIZE_SHRINK_CENTER
		refresh_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		refresh_button.expand_icon = true

func setup(plugin: EditorPlugin):
	editor_plugin = plugin
	
	# Try to get the debugger plugin from the main plugin
	if plugin.has_method("get") and plugin.get("debugger_plugin"):
		set_debugger_plugin(plugin.debugger_plugin)
	
	refresh_objects()

func set_debugger_plugin(debugger: EditorDebuggerPlugin) -> void:
	"""Connect to debugger plugin to receive break notifications."""
	if _debugger_plugin:
		# Disconnect old signals
		if _debugger_plugin.has_signal("debug_break_hit") and _debugger_plugin.debug_break_hit.is_connected(_on_debug_break_hit):
			_debugger_plugin.debug_break_hit.disconnect(_on_debug_break_hit)
	
	_debugger_plugin = debugger
	if _debugger_plugin and _debugger_plugin.has_signal("debug_break_hit"):
		_debugger_plugin.debug_break_hit.connect(_on_debug_break_hit)

func _on_debug_break_hit(file: String, line: int) -> void:
	"""Called when a breakpoint or step is hit - navigate to the line."""
	print("[CodeNav] _on_debug_break_hit: file=", file, " line=", line)
	_current_break_file = file
	_current_break_line = line
	navigate_to_line(file, line)

func navigate_to_line(file_path: String, line: int) -> void:
	"""Navigate the script editor to a specific file and line."""
	print("[CodeNav] navigate_to_line: file=", file_path, " line=", line)
	if not editor_plugin:
		print("[CodeNav] No editor_plugin!")
		return
	
	if file_path.is_empty() or line <= 0:
		print("[CodeNav] Invalid file_path or line")
		return
	
	# Load the script resource
	if not ResourceLoader.exists(file_path):
		print("[CodeNav] File not found: ", file_path)
		return
	
	var script = load(file_path)
	if not script:
		print("[CodeNav] Could not load: ", file_path)
		return
	print("[CodeNav] Loaded script, switching to Script editor")
	var ed_int = editor_plugin.get_editor_interface()
	
	# Switch to Script editor main screen first
	ed_int.set_main_screen_editor("Script")
	
	# Open script in editor and navigate to line
	ed_int.edit_script(script, line, 0)
	
	# Center the viewport on that line after a short delay
	call_deferred("_center_on_line", line)

func _center_on_line(line: int) -> void:
	"""Center the code editor viewport on the specified line."""
	if not editor_plugin:
		return
	
	var script_editor = editor_plugin.get_editor_interface().get_script_editor()
	if not script_editor:
		return
	
	var current_editor = script_editor.get_current_editor()
	if not current_editor:
		return
	
	var code_edit = current_editor.get_base_editor() as CodeEdit
	if code_edit:
		# Line numbers in CodeEdit are 0-based
		code_edit.set_caret_line(line - 1)
		code_edit.set_caret_column(0)
		code_edit.center_viewport_to_caret()
		code_edit.grab_focus()

func refresh_objects():
	if not editor_plugin: 
		# print("CodeNavigator: No editor_plugin set.")
		return
	
	# Remember selection
	var current_node_name = ""
	if object_list.item_count > 0 and object_list.selected >= 0:
		var meta = object_list.get_item_metadata(object_list.selected)
		if meta and is_instance_valid(meta):
			current_node_name = meta.name
	
	object_list.clear()
	
	var root = editor_plugin.get_editor_interface().get_edited_scene_root()
	if not root:
		# Try fallback to open scenes
		var scenes = editor_plugin.get_editor_interface().get_open_scenes()
		if scenes.size() > 0:
			# If we have open scenes, maybe the active one is just not "edited_scene_root"?
			# In Script view, sometimes this happens.
			# Let's verify if the first one is valid.
			var maybe_root = scenes[scenes.size()-1] # Last one usually?
			# Actually, let's just create a timer to retry? 
			# Or just show (No Active Scene)
			object_list.add_item("(No Active Scene)")
		else:
			object_list.add_item("(No Scene Open)")
		return
		
	# Add Objects recursively
	_add_node_recursive(root)
	
	# Restore Selection
	var found = false
	if current_node_name != "":
		for i in object_list.item_count:
			var meta = object_list.get_item_metadata(i)
			if meta and meta.name == current_node_name:
				object_list.select(i)
				_on_object_selected(i)
				found = true
				break
	
	# Select Form (Root) by default if nothing selected and nothing found
	if not found and object_list.item_count > 0:
		object_list.select(0)
		_on_object_selected(0)

func _add_node_recursive(node: Node):
	if not node: return
	
	# Include Type in label? "Button1 (Button)"
	var label = node.name + " (" + node.get_class() + ")"
	var idx = object_list.item_count
	object_list.add_item(label, idx)
	object_list.set_item_metadata(idx, node)
	
	for i in node.get_child_count():
		_add_node_recursive(node.get_child(i))

func _on_object_selected(idx):
	event_list.clear()
	var meta = object_list.get_item_metadata(idx)
	if not is_instance_valid(meta):
		# Object might have been deleted
		return
		
	var node = meta as Node
	if not node: return
	
	# Populate based on type
	var events = []
	if node == editor_plugin.get_editor_interface().get_edited_scene_root():
		events = EVENTS_FORM
	elif node is BaseButton:
		events = EVENTS_BUTTON
	elif node is LineEdit or node is TextEdit:
		events = EVENTS_TEXT
	elif node is ScrollBar or node is Slider:
		events = EVENTS_SCROLL
	elif node is Timer:
		events = EVENTS_TIMER
	else:
		events = EVENTS_COMMON # Fallback
		
	for evt in events:
		event_list.add_item(evt)

func _on_event_selected(idx):
	if idx < 0: return
	var event_name = event_list.get_item_text(idx)
	var obj_idx = object_list.selected
	if obj_idx < 0: return
	
	var meta = object_list.get_item_metadata(obj_idx)
	if not is_instance_valid(meta):
		# Object deleted, refresh list
		refresh_objects()
		return
		
	var node = meta as Node
	if not node: return
	
	_navigate_to_handler(node, event_name)

func _navigate_to_handler(node: Node, event: String):
	if not editor_plugin: return
	
	var root = editor_plugin.get_editor_interface().get_edited_scene_root()
	if not root: return
	
	# Logic similar to plugin
	var scene_path = root.scene_file_path
	if scene_path.is_empty(): 
		print("Save scene first.")
		return
		
	var bas_path = scene_path.get_basename() + ".vg"
	# Ensure file exists
	if not FileAccess.file_exists(bas_path):
		var f = FileAccess.open(bas_path, FileAccess.WRITE)
		f.store_string("' Visual Gasic Form Script\nOption Explicit\n\n")
		f.close()
	
	# Check content
	var content = FileAccess.get_file_as_string(bas_path)
	var sub_name = "Sub " + node.name + "_" + event
	
	# Open/Edit
	_edit_and_goto(bas_path, sub_name, node.name, event)

func _edit_and_goto(path: String, sub_name: String, obj_name: String, event_name: String):
	# 1. Open in Godot Editor
	if not ResourceLoader.exists(path):
		editor_plugin.get_editor_interface().get_resource_filesystem().scan()
		
	var res = load(path)
	if not res: return
	
	var ed_int = editor_plugin.get_editor_interface()
	ed_int.edit_resource(res)
	
	# 2. Modify Editor Buffer directly to avoid disk reload conflicts
	# This ensures the user sees the code immediately without "Reload from disk?"
	var script_editor = ed_int.get_script_editor()
	var current_editor = script_editor.get_current_editor()
	
	if current_editor:
		var code_edit = current_editor.get_base_editor()
		if code_edit:
			var text = code_edit.text
			
			if text.find(sub_name) == -1:
				# Append Handler
				var new_code = "\n" + sub_name + "()\n    Print \"" + obj_name + " " + event_name + "\"\nEnd Sub\n"
				# Append to buffer
				code_edit.text += new_code
				
				# Get fresh text
				text = code_edit.text
			
			# Find line number
			var lines = text.split("\n")
			var line_no = -1
			for i in lines.size():
				if lines[i].strip_edges().begins_with(sub_name):
					line_no = i
					break
			
			if line_no != -1:
				code_edit.set_caret_line(line_no + 1)
				code_edit.set_caret_column(4)
				code_edit.center_viewport_to_caret()
				code_edit.grab_focus()
