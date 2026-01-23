@tool
extends VBoxContainer

# Dedicated Docker for Imports
# Guaranteed to be visible as it's separate from C++ Toolbox

func _init():
	name = "VB6 Imports"
	
	var lbl = Label.new()
	lbl.text = "Legacy Imports"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl)
	
	add_child(HSeparator.new())
	
	var btn_proj = Button.new()
	btn_proj.text = "Import Project (.vbp)"
	btn_proj.custom_minimum_size = Vector2(0, 40)
	btn_proj.pressed.connect(_on_import_project)
	add_child(btn_proj)
	
	var btn_form = Button.new()
	btn_form.text = "Import Form (.frm)"
	btn_form.custom_minimum_size = Vector2(0, 40)
	btn_form.pressed.connect(_on_import_form)
	add_child(btn_form)
	
	var info = Label.new()
	info.text = "Imports Forms to res://start_forms/\nExtracts code to res://mixed/"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.modulate = Color(0.7, 0.7, 0.7)
	add_child(info)

func _on_import_project():
	var plugin = get_plugin_instance()
	if plugin:
		plugin._on_import_vb6_project()
		
func _on_import_form():
	var plugin = get_plugin_instance()
	if plugin:
		plugin._on_import_vb6_form()

func get_plugin_instance():
	# Traverse tree to find Plugin? 
	# Actually, the plugin adds THIS control.
	# We can't access 'EditorPlugin' nicely unless passed.
	# HACK: We replicate logic or rely on signal.
	return EditorInterface.get_base_control().get_meta("visual_gasic_plugin_instance")
