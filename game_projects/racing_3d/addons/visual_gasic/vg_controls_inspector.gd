@tool
extends VBoxContainer
## VB6-style Controls Inspector — shows all form controls and their live properties
## during debugging, similar to VB6's Me.Controls inspection at breakpoints.
##
## Features:
## - Tree view of all controls on the form with their types
## - Live property values updated when at a breakpoint
## - Click a control to highlight it / jump to its event handler
## - Search/filter controls by name
## - Expand a control to see all its properties

class_name VGControlsInspector

signal control_selected(control_name: String)
signal navigate_to_event(control_name: String, event_suffix: String)

var _tree: Tree
var _search_box: LineEdit
var _refresh_btn: Button
var _status_label: Label
var _debug_plugin = null  # VGEditorDebugger reference
var _current_instance_id: int = -1
var _controls_data: Array = []
var _is_debugging: bool = false

func _ready():
	# Search bar
	var hbox = HBoxContainer.new()
	_search_box = LineEdit.new()
	_search_box.placeholder_text = "Filter controls..."
	_search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_box.text_changed.connect(_on_filter_changed)
	hbox.add_child(_search_box)
	
	_refresh_btn = Button.new()
	_refresh_btn.text = "⟳"
	_refresh_btn.tooltip_text = "Refresh Controls"
	_refresh_btn.pressed.connect(_request_controls)
	hbox.add_child(_refresh_btn)
	add_child(hbox)
	
	# Status
	_status_label = Label.new()
	_status_label.text = "Run project and hit a breakpoint to inspect controls."
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	add_child(_status_label)
	
	# Tree
	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.columns = 3
	_tree.set_column_title(0, "Control")
	_tree.set_column_title(1, "Type")
	_tree.set_column_title(2, "Value")
	_tree.column_titles_visible = true
	_tree.set_column_expand(0, true)
	_tree.set_column_expand(1, false)
	_tree.set_column_expand(2, true)
	_tree.set_column_custom_minimum_width(1, 100)
	_tree.hide_root = true
	_tree.item_selected.connect(_on_item_selected)
	_tree.item_activated.connect(_on_item_activated)
	add_child(_tree)

func setup(debug_plugin) -> void:
	_debug_plugin = debug_plugin

func set_debugging(active: bool) -> void:
	_is_debugging = active
	if active:
		_status_label.text = "Debugging active. Click Refresh to inspect controls."
	else:
		_status_label.text = "Run project and hit a breakpoint to inspect controls."
		_controls_data.clear()
		_rebuild_tree()

func set_instance_id(instance_id: int) -> void:
	_current_instance_id = instance_id

func _request_controls() -> void:
	if not _is_debugging or _current_instance_id < 0:
		_status_label.text = "No active debug session or instance selected."
		return
	if _debug_plugin and _debug_plugin._active_session:
		_debug_plugin._active_session.send_message("visualgasic:get_form_controls", [_current_instance_id])
		_status_label.text = "Requesting controls..."

func receive_controls(controls: Array) -> void:
	"""Called when we receive the control list from the game process."""
	_controls_data = controls
	_status_label.text = "%d controls on form" % controls.size()
	_rebuild_tree()

func _rebuild_tree() -> void:
	_tree.clear()
	var root = _tree.create_item()
	var filter = _search_box.text.to_lower() if _search_box else ""
	
	for ctrl in _controls_data:
		var ctrl_name: String = ctrl.get("name", "?")
		var ctrl_type: String = ctrl.get("type", "Control")
		
		if not filter.is_empty() and filter not in ctrl_name.to_lower():
			continue
		
		var item = _tree.create_item(root)
		item.set_text(0, ctrl_name)
		item.set_text(1, ctrl_type)
		item.set_text(2, "")  # Summary
		
		# Icon hint by type
		var icon_color = _type_color(ctrl_type)
		item.set_custom_color(1, icon_color)
		
		# Store metadata
		item.set_metadata(0, ctrl_name)
		
		# Add property children
		var props: Dictionary = ctrl.get("properties", {})
		var summary_parts: Array = []
		
		# Show key properties in the summary column
		if props.has("text") or props.has("Text"):
			var t = props.get("text", props.get("Text", ""))
			summary_parts.append('Text="%s"' % str(t))
		if props.has("visible") or props.has("Visible"):
			var v = props.get("visible", props.get("Visible", true))
			if not v:
				summary_parts.append("Hidden")
		if props.has("enabled") or props.has("Enabled"):
			var e = props.get("enabled", props.get("Enabled", true))
			if not e:
				summary_parts.append("Disabled")
		
		if summary_parts.size() > 0:
			item.set_text(2, ", ".join(summary_parts))
		
		# Expand: add all properties as children
		var sorted_keys = props.keys()
		sorted_keys.sort()
		for key in sorted_keys:
			var prop_item = _tree.create_item(item)
			prop_item.set_text(0, "  " + str(key))
			prop_item.set_text(2, str(props[key]))
			prop_item.set_custom_color(0, Color(0.5, 0.7, 1.0))
		
		item.collapsed = true  # Start collapsed

func _on_filter_changed(_text: String) -> void:
	_rebuild_tree()

func _on_item_selected() -> void:
	var item = _tree.get_selected()
	if item and item.get_metadata(0):
		control_selected.emit(item.get_metadata(0))

func _on_item_activated() -> void:
	"""Double-click → navigate to default event handler."""
	var item = _tree.get_selected()
	if not item:
		return
	var ctrl_name = item.get_metadata(0)
	if ctrl_name and ctrl_name is String and not ctrl_name.is_empty():
		var ctrl_type = item.get_text(1)
		var event_suffix = _default_event_for_type(ctrl_type)
		navigate_to_event.emit(ctrl_name, event_suffix)

func _default_event_for_type(type_name: String) -> String:
	"""Return the default VB6 event suffix for a given control type."""
	match type_name.to_lower():
		"button", "commandbutton", "basebutton":
			return "Click"
		"textbox", "lineedit", "textedit":
			return "Change"
		"checkbox", "optionbutton":
			return "Change"
		"listbox", "itemlist":
			return "Click"
		"combobox", "optionbutton":
			return "Click"
		"timer":
			return "Timer"
		"picturebox", "texturerect":
			return "Click"
		"hscrollbar", "vscrollbar":
			return "Scroll"
		"label":
			return "Click"
		_:
			return "Click"

func _type_color(type_name: String) -> Color:
	"""Color hint for control type."""
	match type_name.to_lower():
		"button", "commandbutton", "basebutton":
			return Color(0.4, 0.8, 0.4)
		"textbox", "lineedit", "textedit":
			return Color(0.8, 0.8, 0.4)
		"label":
			return Color(0.6, 0.6, 0.8)
		"timer":
			return Color(0.8, 0.5, 0.5)
		"picturebox", "texturerect":
			return Color(0.5, 0.8, 0.8)
		_:
			return Color(0.7, 0.7, 0.7)
