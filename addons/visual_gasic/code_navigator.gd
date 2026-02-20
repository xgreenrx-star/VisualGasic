@tool
extends HBoxContainer
## Code Navigator — VB6-style Object/Event dropdowns above the code editor.
## In VB6, this bar sits directly above the code window with two dropdowns:
##   [Object ▼]  |  [Event ▼]
## Selecting an object populates the event list; selecting an event navigates
## to (or creates) the corresponding Sub handler in the .vg script.

var editor_plugin: EditorPlugin
var object_list: OptionButton
var event_list: OptionButton
var refresh_button: Button
var _separator: VSeparator
var _debugger_plugin: EditorDebuggerPlugin = null
var _current_break_file: String = ""
var _current_break_line: int = 0

# Standard VB6 Events
const EVENTS_COMMON = ["Click", "DblClick", "MouseDown", "MouseUp", "MouseMove", "KeyDown", "KeyUp", "KeyPress"]
const EVENTS_BUTTON = ["Click", "MouseDown", "MouseUp", "MouseMove", "KeyDown", "KeyUp", "KeyPress"]
const EVENTS_TEXT = ["Change", "Click", "MouseDown", "MouseUp", "MouseMove", "KeyDown", "KeyUp", "KeyPress"]
const EVENTS_TIMER = ["Timer"]
const EVENTS_SCROLL = ["Change", "Scroll"]
const EVENTS_FORM = ["Load", "Unload", "Click", "MouseDown", "MouseUp", "MouseMove", "KeyDown", "KeyUp", "KeyPress", "Resize"]

func _init():
	name = "Code Navigator"
	# Horizontal bar that spans the full width above the code editor
	size_flags_horizontal = SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 30)
	
	# --- Object Dropdown (left half) ---
	object_list = OptionButton.new()
	object_list.size_flags_horizontal = SIZE_EXPAND_FILL
	object_list.custom_minimum_size.x = 120
	object_list.clip_text = true
	object_list.item_selected.connect(_on_object_selected)
	add_child(object_list)
	
	# --- Vertical Separator (VB6-style divider between the two dropdowns) ---
	_separator = VSeparator.new()
	add_child(_separator)
	
	# --- Event Dropdown (right half) ---
	event_list = OptionButton.new()
	event_list.size_flags_horizontal = SIZE_EXPAND_FILL
	event_list.custom_minimum_size.x = 120
	event_list.clip_text = true
	event_list.item_selected.connect(_on_event_selected)
	add_child(event_list)
	
	# --- Refresh Button (compact icon button) ---
	refresh_button = Button.new()
	refresh_button.tooltip_text = "Refresh Object List"
	refresh_button.custom_minimum_size = Vector2(28, 28)
	refresh_button.pressed.connect(refresh_objects)
	_set_refresh_icon()
	add_child(refresh_button)
	
	# Enable type-ahead letter-jump on both dropdowns (like VB6 ComboBox behavior)
	object_list.get_popup().allow_search = true
	event_list.get_popup().allow_search = true

func _notification(what):
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_READY:
		_set_refresh_icon()

func _set_refresh_icon():
	if not refresh_button:
		return
	var icon = refresh_button.get_theme_icon("Reload", "EditorIcons")
	if icon:
		refresh_button.icon = icon
	else:
		refresh_button.icon = null

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
	_current_break_file = file
	_current_break_line = line
	navigate_to_line(file, line)

func navigate_to_line(file_path: String, line: int) -> void:
	"""Navigate the script editor to a specific file and line."""
	if not editor_plugin:
		return
	
	if file_path.is_empty() or line <= 0:
		return
	
	# Load the script resource
	if not ResourceLoader.exists(file_path):
		return
	
	var script = load(file_path)
	if not script:
		return
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
		
	# Add (General) entry — VB6-style module-level declarations
	var general_idx = object_list.item_count
	object_list.add_item("(General)")
	object_list.set_item_metadata(general_idx, "(General)")
	
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

func _get_current_vg_path() -> String:
	"""Get the .vg file path for the current scene."""
	if not editor_plugin:
		return ""
	# First try: get the currently edited script directly from the script editor
	var script_editor = editor_plugin.get_editor_interface().get_script_editor()
	if script_editor:
		var current_script = script_editor.get_current_script()
		if current_script and current_script.resource_path.ends_with(".vg"):
			return current_script.resource_path
	# Fallback: derive from scene path
	var root = editor_plugin.get_editor_interface().get_edited_scene_root()
	if not root:
		return ""
	var scene_path = root.scene_file_path
	if scene_path.is_empty():
		return ""
	var bas_path = scene_path.get_basename() + ".vg"
	if FileAccess.file_exists(bas_path):
		return bas_path
	return ""

func _get_current_vg_text() -> String:
	"""Get the text content of the current .vg file from the editor buffer."""
	if not editor_plugin:
		return ""
	var script_editor = editor_plugin.get_editor_interface().get_script_editor()
	if script_editor:
		var current_editor = script_editor.get_current_editor()
		if current_editor:
			var code_edit = current_editor.get_base_editor()
			if code_edit:
				return code_edit.text
	# Fallback: read from disk
	var path = _get_current_vg_path()
	if path != "" and FileAccess.file_exists(path):
		return FileAccess.get_file_as_string(path)
	return ""

func _parse_procedures(text: String) -> Array:
	"""Parse all Sub/Function/Property definitions from a .vg file.
	Returns an array of dictionaries: {name, kind, line, full_sig}
	   kind: 'Sub', 'Function', 'Property Get', 'Property Let', 'Property Set'
	"""
	var procedures: Array = []
	if text.is_empty():
		return procedures
	var lines = text.split("\n")
	# Regex patterns for procedure headers
	# Matches: [Public|Private] Sub|Function|Property Get|Let|Set  Name(...)
	for i in lines.size():
		var stripped = lines[i].strip_edges()
		var lower = stripped.to_lower()
		# Skip empty/comment lines
		if stripped.is_empty() or stripped.begins_with("'") or stripped.begins_with("REM "):
			continue
		# Strip access modifier
		var sig = stripped
		var sig_lower = lower
		if sig_lower.begins_with("public "):
			sig = sig.substr(7)
			sig_lower = sig_lower.substr(7)
		elif sig_lower.begins_with("private "):
			sig = sig.substr(8)
			sig_lower = sig_lower.substr(8)
		# Match procedure kinds
		var kind = ""
		var proc_name = ""
		if sig_lower.begins_with("sub "):
			kind = "Sub"
			proc_name = _extract_proc_name(sig.substr(4))
		elif sig_lower.begins_with("function "):
			kind = "Function"
			proc_name = _extract_proc_name(sig.substr(9))
		elif sig_lower.begins_with("property get "):
			kind = "Property Get"
			proc_name = _extract_proc_name(sig.substr(13))
		elif sig_lower.begins_with("property let "):
			kind = "Property Let"
			proc_name = _extract_proc_name(sig.substr(13))
		elif sig_lower.begins_with("property set "):
			kind = "Property Set"
			proc_name = _extract_proc_name(sig.substr(13))
		if kind != "" and proc_name != "":
			procedures.append({
				"name": proc_name,
				"kind": kind,
				"line": i,
				"full_sig": stripped
			})
	# Sort alphabetically by name (case-insensitive), then by kind
	procedures.sort_custom(func(a, b):
		var na = a["name"].to_lower()
		var nb = b["name"].to_lower()
		if na != nb:
			return na < nb
		return a["kind"] < b["kind"]
	)
	return procedures

func _extract_proc_name(after_keyword: String) -> String:
	"""Extract the procedure name from text after 'Sub '/'Function '/etc."""
	var s = after_keyword.strip_edges()
	# Name ends at '(' or space or end of string
	var end = s.length()
	for j in s.length():
		if s[j] == "(" or s[j] == " " or s[j] == "\t":
			end = j
			break
	var name = s.substr(0, end).strip_edges()
	if name.is_empty():
		return ""
	return name

func _on_object_selected(idx):
	event_list.clear()
	var meta = object_list.get_item_metadata(idx)
	
	# Handle (General) selection — VB6 shows (Declarations) + all Subs/Functions/Properties
	if meta is String and meta == "(General)":
		event_list.add_item("(Declarations)")
		event_list.set_item_metadata(0, {"type": "declarations"})
		# Parse the .vg file to find all procedures
		var text = _get_current_vg_text()
		var procedures = _parse_procedures(text)
		for proc in procedures:
			var display = proc["name"]
			# Show kind suffix like VB6 does for Property variants
			if proc["kind"].begins_with("Property"):
				display += " [" + proc["kind"] + "]"
			var eidx = event_list.item_count
			event_list.add_item(display)
			event_list.set_item_metadata(eidx, {"type": "procedure", "line": proc["line"], "name": proc["name"], "kind": proc["kind"]})
		return
	
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
	
	# Check which handlers already exist in the .vg file (VB6 shows these bold)
	var text = _get_current_vg_text()
	var handler_prefix = node.name + "_"
	
	for evt in events:
		var eidx = event_list.item_count
		var handler_name = "Sub " + node.name + "_" + evt
		var has_handler = text.contains(handler_name)
		event_list.add_item(evt)
		event_list.set_item_metadata(eidx, {"type": "event", "event": evt, "has_handler": has_handler})

func _on_event_selected(idx):
	if idx < 0: return
	var obj_idx = object_list.selected
	if obj_idx < 0: return
	
	var event_meta = event_list.get_item_metadata(idx)
	var obj_meta = object_list.get_item_metadata(obj_idx)
	
	# --- (General) section ---
	if obj_meta is String and obj_meta == "(General)":
		if event_meta and event_meta.has("type"):
			if event_meta["type"] == "declarations":
				_navigate_to_declarations()
				return
			elif event_meta["type"] == "procedure":
				# Navigate directly to the procedure's line
				_navigate_to_line_in_vg(event_meta["line"])
				return
		return
	
	# --- Control event handler ---
	if not is_instance_valid(obj_meta):
		refresh_objects()
		return
		
	var node = obj_meta as Node
	if not node: return
	
	var event_name = event_meta["event"] if event_meta and event_meta.has("event") else event_list.get_item_text(idx).strip_edges()
	_navigate_to_handler(node, event_name)

func _navigate_to_line_in_vg(line_number: int):
	"""Navigate to a specific line in the current .vg file."""
	if not editor_plugin:
		return
	var vg_path = _get_current_vg_path()
	if vg_path.is_empty():
		return
	var res = load(vg_path)
	if not res:
		return
	var ed_int = editor_plugin.get_editor_interface()
	ed_int.edit_resource(res)
	# Navigate to line in the editor buffer
	var script_editor = ed_int.get_script_editor()
	if not script_editor:
		return
	var current_editor = script_editor.get_current_editor()
	if not current_editor:
		return
	var code_edit = current_editor.get_base_editor()
	if code_edit:
		code_edit.set_caret_line(line_number)
		code_edit.set_caret_column(0)
		code_edit.center_viewport_to_caret()
		code_edit.grab_focus()

func _navigate_to_declarations():
	"""Navigate to the top of the .vg file (module-level declarations)."""
	if not editor_plugin:
		return
	var root = editor_plugin.get_editor_interface().get_edited_scene_root()
	if not root:
		return
	var scene_path = root.scene_file_path
	if scene_path.is_empty():
		return
	var bas_path = scene_path.get_basename() + ".vg"
	if not FileAccess.file_exists(bas_path):
		return
	
	# Open and go to the top
	var res = load(bas_path)
	if not res:
		return
	var ed_int = editor_plugin.get_editor_interface()
	ed_int.edit_resource(res)
	
	var script_editor = ed_int.get_script_editor()
	var current_editor = script_editor.get_current_editor()
	if current_editor:
		var code_edit = current_editor.get_base_editor()
		if code_edit:
			# Find the first line that is NOT inside a Sub/Function — i.e. the declarations area
			var text = code_edit.text
			var lines = text.split("\n")
			var target_line = 0
			# Find first non-empty, non-comment line in the declarations area (before first Sub/Function)
			for i in lines.size():
				var stripped = lines[i].strip_edges().to_lower()
				if stripped.begins_with("sub ") or stripped.begins_with("function ") or \
				   stripped.begins_with("private sub") or stripped.begins_with("public sub") or \
				   stripped.begins_with("private function") or stripped.begins_with("public function"):
					break
				target_line = i
			code_edit.set_caret_line(target_line)
			code_edit.set_caret_column(0)
			code_edit.center_viewport_to_caret()
			code_edit.grab_focus()

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
