@tool
extends Node

# VB6 Importer
# Parses .frm and .vbp files

const TWIPS_PER_PIXEL = 15.0

static func _ensure_dir(path: String):
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(path):
		var err = dir.make_dir_recursive(path)
		if err != OK:
			print("Error creating directory: " + path)

static func import_project(path: String):
	print("Importing Project: " + path)
	var f = FileAccess.open(path, FileAccess.READ)
	if !f:
		print("Failed to open project file")
		return

	_ensure_dir("res://start_forms")
	_ensure_dir("res://mixed")
		
	var base_dir = path.get_base_dir()
	var forms = []
	var modules = []
	var startup = ""
	
	while !f.eof_reached():
		var line = f.get_line().strip_edges()
		if line.begins_with("Form="):
			var form_file = line.replace("Form=", "")
			forms.push_back(base_dir + "/" + form_file)
		elif line.begins_with("Module="):
			# Module=ModName; File.bas
			var parts = line.split(";")
			if parts.size() > 1:
				var mod_file = parts[1].strip_edges()
				modules.push_back(base_dir + "/" + mod_file)
		elif line.begins_with("Startup="):
			startup = line.replace("Startup=", "").replace('"', "")
			
	print("Found ", forms.size(), " forms and ", modules.size(), " modules.")
	
	# Import Forms
	for frm_path in forms:
		print("Importing Form: ", frm_path)
		var root = Control.new()
		root.name = frm_path.get_file().get_basename()
		var code = import_form(frm_path, root, root)
		
		# Save Packed Scene
		var packed = PackedScene.new()
		packed.pack(root)
		var save_path = "res://start_forms/" + root.name + ".tscn"
		ResourceSaver.save(packed, save_path)
		
		# Save Code
		if code != "":
			var bas_path = "res://mixed/" + root.name + ".bas"
			var bf = FileAccess.open(bas_path, FileAccess.WRITE)
			bf.store_string(code)
			bf.close()
			
		root.free()
			
	# Import Modules (Just Copy)
	for mod_path in modules:
		print("Importing Module: ", mod_path)
		var content = FileAccess.get_file_as_string(mod_path)
		var save_path = "res://mixed/" + mod_path.get_file()
		var bf = FileAccess.open(save_path, FileAccess.WRITE)
		bf.store_string(content)
		bf.close()
		
	print("Project Import Complete.")

static func import_form(path: String, parent_node: Node, owner_node: Node = null):
	var file = FileAccess.open(path, FileAccess.READ)
	if !file:
		print("Error: Could not open file " + path)
		return

	var current_parent = parent_node
	var parent_stack = []
	var code_mode = false
	var code_content = ""
	
	# Mapping from VB6 Class to Godot Class/Scene
	# Using standard Godot nodes where possible, or Custom Wrappers
	var map = {
		"VB.Form": "Control", # Functions as root container
		"VB.CommandButton": "Button",
		"VB.TextBox": "LineEdit",
		"VB.Label": "Label",
		"VB.CheckBox": "CheckBox",
		"VB.OptionButton": "OptionButton", # Combo
		"VB.ComboBox": "OptionButton",
		"VB.ListBox": "ItemList",
		"VB.PictureBox": "TextureRect",
		"VB.Frame": "Panel", # Or our Custom Frame wrapper
		"VB.Timer": "Timer"
	}

	while !file.eof_reached():
		var line = file.get_line()
		var trim = line.strip_edges()
		
		if trim.begins_with("Attribute VB_Name"):
			# End of layout definition usually
			code_mode = true
			continue
			
		if code_mode:
			code_content += line + "\n"
			continue
			
		if trim.begins_with("Begin "):
			# Format: Begin Library.Class ControlName 
			var parts = trim.split(" ", false)
			if parts.size() >= 3:
				var vb_class = parts[1]
				var vb_name = parts[2]
				
				var new_node = null
				
				# Special handling for Form (it's the root matching parent_node usually)
				if vb_class == "VB.Form":
					new_node = parent_node # Assume parent is the form root provided
					new_node.name = vb_name
				else:
					if map.has(vb_class):
						var type = map[vb_class]
						if type == "Panel" and ResourceLoader.exists("res://custom_widgets/Frame.tscn"):
							new_node = load("res://custom_widgets/Frame.tscn").instantiate()
						elif type == "OptionButton" and ResourceLoader.exists("res://custom_widgets/OptionButton.tscn"):
							new_node = load("res://custom_widgets/OptionButton.tscn").instantiate()
						else:
							if ClassDB.class_exists(type):
								new_node = ClassDB.instantiate(type)
							else:
								new_node = Control.new()
						
						new_node.name = vb_name
						current_parent.add_child(new_node)
						new_node.owner = owner_node # Ensure persistence in Editor

						# --- Auto-Connect Signals ---
						# Connects standard VB6 events (Click, Change) to their handler names (Name_Click)
						# The runtime script must implement these Subs.
						if owner_node:
							if new_node is Button:
								# Command_Click
								new_node.connect("pressed", Callable(owner_node, vb_name + "_Click"))
							elif new_node is LineEdit:
								# Text_Change
								new_node.connect("text_changed", Callable(owner_node, vb_name + "_Change"))
							elif new_node is CheckBox:
								new_node.connect("toggled", Callable(owner_node, vb_name + "_Click"))
							elif new_node is Timer:
								# Timer_Timer
								new_node.connect("timeout", Callable(owner_node, vb_name + "_Timer"))
					else:
						print("Unknown VB6 Control: " + vb_class)
						# Create placeholder
						new_node = Control.new()
						new_node.name = vb_name
						current_parent.add_child(new_node)
						new_node.owner = owner_node
				
				parent_stack.push_back(current_parent)
				current_parent = new_node
				
		elif trim.begins_with("End"):
			if parent_stack.size() > 0:
				current_parent = parent_stack.pop_back()
				
		elif trim.contains("=") and !code_mode:
			# Property setting
			var split = trim.split("=", true, 1)
			var key = split[0].strip_edges()
			var val = split[1].strip_edges()
			
			if current_parent:
				apply_property(current_parent, key, val)

	return code_content

static func apply_property(node: Node, key: String, val: String):
	# Remove quotes
	if val.begins_with('"') and val.ends_with('"'):
		val = val.substr(1, val.length()-2)
		
	match key:
		"Caption":
			if "text" in node: node.text = val
			if node.has_method("set_title"): node.set_title(val) # Dialogs
		"Text":
			if "text" in node: node.text = val
		"Left":
			if node is Control: node.position.x = int(val) / TWIPS_PER_PIXEL
		"Top":
			if node is Control: node.position.y = int(val) / TWIPS_PER_PIXEL
		"Width":
			if node is Control: node.size.x = int(val) / TWIPS_PER_PIXEL
		"Height":
			if node is Control: node.size.y = int(val) / TWIPS_PER_PIXEL
		"Visible":
			if node is CanvasItem: node.visible = (val == "-1" or val == "True")
		"Enabled":
			if "disabled" in node: node.disabled = !(val == "-1" or val == "True")
		"Tag":
			node.set_meta("tag", val)
		"BackColor":
			var c = vb_color_to_godot(val)
			if node is Panel:
				var sb = node.get_theme_stylebox("panel")
				if not sb or not (sb is StyleBoxFlat):
					sb = StyleBoxFlat.new()
					node.add_theme_stylebox_override("panel", sb)
				sb.bg_color = c
			elif "color" in node: # ColorRect?
				node.color = c
			elif node is Control:
				# General modulation
				node.modulate = c
		"ForeColor":
			var c = vb_color_to_godot(val)
			if "font_color" in node: # Label argument? No, theme override
				node.add_theme_color_override("font_color", c)
			elif node.has_theme_color_override("font_color"):
				node.add_theme_color_override("font_color", c)
			else:
				node.modulate = c # Fallback

static func vb_color_to_godot(val: String) -> Color:
	# Value format: &H00C0C0C0& or &H8000000F& (System) or 16777215 (Decimal)
	var hex = val
	if hex.begins_with("&H"):
		hex = hex.substr(2)
		if hex.ends_with("&"): hex = hex.substr(0, hex.length()-1)
	
	var int_val = hex.hex_to_int()
	if !val.begins_with("&H"):
		int_val = val.to_int()
		
	# System Color Handling (High bit set)
	if int_val > 0x80000000:
		var sys_idx = int_val & 0xFFFF
		match sys_idx:
			15: return Color(0.94, 0.94, 0.94) # Button Face (Silver)
			5: return Color.WHITE # Window Background
			8: return Color.BLACK # Window Text
			12: return Color(0.2, 0.2, 0.2) # App Workspace
			_: return Color.GRAY
			
	# RGB Color (VB6 is BGR usually: 0xBBGGRR)
	var r = (int_val & 0xFF) / 255.0
	var g = ((int_val >> 8) & 0xFF) / 255.0
	var b = ((int_val >> 16) & 0xFF) / 255.0
	return Color(r, g, b)


