@tool
extends VBoxContainer

# Simplified VB6-Style Property Inspector
# Shows only high-level properties relevant to Visual Gasic users

var editor_plugin: EditorPlugin
var property_grid: GridContainer
var current_node: Node

# VB6 Property Mapping
const PROP_MAP = {
	"text": "Caption", # Or Text
	"name": "Name",
	"visible": "Visible",
	"modulate": "ForeColor", # Using Modulate as ForeColor is common shortcut in Godot 2D
	"self_modulate": "BackColor", # Rough mapping
	"position": "Position",
	"size": "Size",
	"scale": "Scale"
}

func _init():
	name = "Properties"
	size_flags_vertical = SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(200, 150)
	
	var title = Label.new()
	title.text = "Properties"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Style box for VB6 look?
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.4) # VB6 Title Bar Blue
	title.add_theme_stylebox_override("normal", style)
	add_child(title)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(scroll)
	
	property_grid = GridContainer.new()
	property_grid.columns = 2
	property_grid.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(property_grid)

func setup(plugin: EditorPlugin):
	editor_plugin = plugin
	# Connect to selection
	editor_plugin.get_editor_interface().get_selection().selection_changed.connect(_on_selection_changed)

func _on_selection_changed():
	var sel = editor_plugin.get_editor_interface().get_selection().get_selected_nodes()
	if sel.size() == 1:
		update_properties(sel[0])
	else:
		clear_properties()

func clear_properties():
	current_node = null
	for c in property_grid.get_children():
		c.queue_free()

func update_properties(node: Node):
	clear_properties()
	current_node = node
	
	# Header
	_add_prop_row("Name", node.name, true) # Name is special
	
	# Common Properties
	if "text" in node:
		_add_prop_row("Caption/Text", node.text)
		
	if "visible" in node:
		_add_prop_row("Visible", node.visible)
		
	if node is Control or node is Node2D:
		_add_prop_row("Left", node.position.x)
		_add_prop_row("Top", node.position.y)
		
	if node is Control:
		_add_prop_row("Width", node.size.x)
		_add_prop_row("Height", node.size.y)
		# TabStop Mapping
		var can_focus = (node.focus_mode != Control.FOCUS_NONE)
		_add_prop_row("TabStop", can_focus)
		
	# Specifics
	if node is BaseButton:
		_add_prop_row("Enabled", !node.disabled)
		
	# Add custom script properties?
	# TODO: Reflection

func _add_prop_row(label_text, value, is_name=false):
	var lbl = Label.new()
	lbl.text = label_text
	property_grid.add_child(lbl)
	
	if value is bool:
		var chk = CheckBox.new()
		chk.button_pressed = value
		chk.toggled.connect(func(v): _apply_prop(label_text, v))
		property_grid.add_child(chk)
	elif value is String:
		var txt = LineEdit.new()
		txt.text = value
		if is_name:
			txt.text_submitted.connect(func(v): _apply_name(v))
		else:
			txt.text_submitted.connect(func(v): _apply_prop(label_text, v))
		property_grid.add_child(txt)
	elif value is float or value is int:
		var spin = SpinBox.new()
		spin.allow_greater = true
		spin.allow_lesser = true
		spin.value = value
		spin.max_value = 10000
		spin.min_value = -10000
		spin.value_changed.connect(func(v): _apply_prop(label_text, v))
		property_grid.add_child(spin)

func _apply_name(v):
	if current_node:
		current_node.name = v
		# Force scene tree update? Godot handles unique naming usually

func _apply_prop(p_name, v):
	if not current_node: return
	
	if p_name == "Caption/Text" and "text" in current_node:
		current_node.text = v
	elif p_name == "Visible":
		current_node.visible = v
	elif p_name == "Enabled" and current_node is BaseButton:
		current_node.disabled = !v
	elif p_name == "Left":
		current_node.position.x = v
	elif p_name == "Top":
		current_node.position.y = v
	elif p_name == "Width" and current_node is Control:
		current_node.size.x = v
	elif p_name == "Height" and current_node is Control:
		current_node.size.y = v
	elif p_name == "TabStop" and current_node is Control:
		if v:
			current_node.focus_mode = Control.FOCUS_ALL # or FOCUS_CLICK
		else:
			current_node.focus_mode = Control.FOCUS_NONE
