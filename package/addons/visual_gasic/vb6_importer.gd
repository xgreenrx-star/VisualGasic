@tool
extends Node

# VB6 Importer - Enhanced Version
# Parses .frm and .vbp files with comprehensive control and property support
# Supports control arrays, fonts, extended properties, and code transformation

const TWIPS_PER_PIXEL = 15.0

# =============================================================================
# VB6 CONTROL TO GODOT NODE MAPPING
# =============================================================================

## Extended mapping from VB6 Class to Godot Class/Scene
const CONTROL_MAP: Dictionary = {
	# Standard Controls
	"VB.Form": "Control",
	"VB.MDIForm": "Control",
	"VB.CommandButton": "Button",
	"VB.TextBox": "LineEdit",  # Will switch to TextEdit if MultiLine
	"VB.Label": "Label",
	"VB.CheckBox": "CheckBox",
	"VB.OptionButton": "CheckBox",  # Radio button behavior
	"VB.ComboBox": "OptionButton",
	"VB.ListBox": "ItemList",
	"VB.PictureBox": "TextureRect",
	"VB.Image": "TextureRect",
	"VB.Frame": "Panel",
	"VB.Timer": "Timer",
	"VB.Menu": "PopupMenu",
	
	# Scrollbars
	"VB.HScrollBar": "HScrollBar",
	"VB.VScrollBar": "VScrollBar",
	
	# Shapes and Lines
	"VB.Shape": "ColorRect",
	"VB.Line": "Line2D",
	
	# File System Controls
	"VB.DriveListBox": "OptionButton",
	"VB.DirListBox": "ItemList",
	"VB.FileListBox": "ItemList",
	
	# OLE/Data Controls
	"VB.Data": "Node",  # Placeholder - no direct equivalent
	"VB.OLE": "Node",
	
	# Common Dialog (comdlg32.ocx)
	"MSComDlg.CommonDialog": "FileDialog",
	"ComDlg.CommonDialog": "FileDialog",
	
	# Rich Text (richtx32.ocx)
	"RichText.RichTextBox": "RichTextLabel",
	"RICHTEXT.RichTextCtrl": "RichTextLabel",
	
	# Progress and Slider (comctl32.ocx / mscomctl.ocx)
	"MSComctlLib.ProgressBar": "ProgressBar",
	"MSComctlLib.Slider": "HSlider",
	"ComctlLib.ProgressBar": "ProgressBar",
	"ComctlLib.Slider": "HSlider",
	
	# Tab Control
	"MSComctlLib.TabStrip": "TabContainer",
	"SSTab.SSTab": "TabContainer",
	"TabDlg.SSTab": "TabContainer",
	
	# Tree and List Views
	"MSComctlLib.TreeView": "Tree",
	"MSComctlLib.ListView": "Tree",
	"MSComctlLib.ImageList": "Node",  # Store references
	"ComctlLib.TreeView": "Tree",
	"ComctlLib.ListView": "Tree",
	
	# Status Bar and Toolbar
	"MSComctlLib.StatusBar": "Panel",
	"MSComctlLib.Toolbar": "HBoxContainer",
	"MSComctlLib.CoolBar": "HBoxContainer",
	"ComctlLib.StatusBar": "Panel",
	"ComctlLib.Toolbar": "HBoxContainer",
	
	# Date/Time Picker (mscomct2.ocx)
	"MSComCtl2.DTPicker": "SpinBox",
	"MSComCtl2.MonthView": "Control",
	"MSComCtl2.UpDown": "SpinBox",
	"DTPicker.DTPicker": "SpinBox",
	
	# Animation Control
	"MSComctlLib.Animation": "AnimatedSprite2D",
	"ComctlLib.Animation": "AnimatedSprite2D",
	
	# Internet Transfer Control (inet.ocx)
	"InetCtlsObjects.Inet": "HTTPRequest",
	"Inet.Inet": "HTTPRequest",
	
	# WinSock Control (mswinsck.ocx)
	"MSWinsockLib.Winsock": "StreamPeerTCP",
	"Winsock.Winsock": "StreamPeerTCP",
	
	# Masked Edit (msmask32.ocx)
	"MaskEdBox.MaskEdBox": "LineEdit",
	"MSMask.MaskedEdit": "LineEdit",
	
	# Multimedia Control (mci32.ocx)
	"MCI.MMControl": "AudioStreamPlayer",
	"MMControl.MMControl": "AudioStreamPlayer",
	
	# Chart Control (mschrt20.ocx)
	"MSChartLib.MSChart": "Control",
	"MSChart20Lib.MSChart": "Control",
	
	# FlexGrid (msflxgrd.ocx)
	"MSFlexGridLib.MSFlexGrid": "Tree",
	"FlexGrid.FlexGrid": "Tree",
	
	# DataGrid
	"MSDataGridLib.DataGrid": "Tree",
	"DataGrid.DataGrid": "Tree",
	
	# Crystal Reports
	"CrystalReportControl.CrystalReport": "Node",
	
	# Third-party common controls
	"Threed.SSPanel": "Panel",
	"Threed.SSFrame": "Panel",
	"Threed.SSCommand": "Button",
	"Threed.SSCheck": "CheckBox",
	"Threed.SSOption": "CheckBox",
}

# =============================================================================
# EVENT MAPPING
# =============================================================================

## VB6 event to Godot signal mapping
const EVENT_MAP: Dictionary = {
	"Button": {
		"Click": "pressed",
		"MouseDown": "button_down",
		"MouseUp": "button_up",
	},
	"LineEdit": {
		"Change": "text_changed",
		"KeyPress": "text_submitted",
		"GotFocus": "focus_entered",
		"LostFocus": "focus_exited",
	},
	"TextEdit": {
		"Change": "text_changed",
		"GotFocus": "focus_entered",
		"LostFocus": "focus_exited",
	},
	"CheckBox": {
		"Click": "toggled",
	},
	"OptionButton": {
		"Click": "item_selected",
		"Change": "item_selected",
	},
	"ItemList": {
		"Click": "item_selected",
		"DblClick": "item_activated",
	},
	"Timer": {
		"Timer": "timeout",
	},
	"HScrollBar": {
		"Change": "value_changed",
		"Scroll": "value_changed",
	},
	"VScrollBar": {
		"Change": "value_changed",
		"Scroll": "value_changed",
	},
	"HSlider": {
		"Change": "value_changed",
	},
	"Tree": {
		"Click": "item_selected",
		"DblClick": "item_activated",
		"NodeSelected": "item_selected",
	},
}

# =============================================================================
# DIRECTORY UTILITIES
# =============================================================================

static func _ensure_dir(path: String):
	var dir = DirAccess.open("res://")
	if dir and not dir.dir_exists(path):
		var err = dir.make_dir_recursive(path)
		if err != OK:
			push_error("Error creating directory: " + path)

# =============================================================================
# PROJECT IMPORT
# =============================================================================

static func import_project(path: String) -> Dictionary:
	"""Import a VB6 project file (.vbp) and all its forms/modules."""
	print("VB6 Importer: Importing Project: " + path)
	
	var result = {
		"success": false,
		"forms": [],
		"modules": [],
		"errors": [],
		"warnings": []
	}
	
	var f = FileAccess.open(path, FileAccess.READ)
	if !f:
		result.errors.append("Failed to open project file: " + path)
		return result

	_ensure_dir("res://start_forms")
	_ensure_dir("res://mixed")
	_ensure_dir("res://resources")
		
	var base_dir = path.get_base_dir()
	var forms: Array = []
	var modules: Array = []
	var classes: Array = []
	var startup = ""
	var project_name = path.get_file().get_basename()
	
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
				
		elif line.begins_with("Class="):
			# Class=ClassName; File.cls
			var parts = line.split(";")
			if parts.size() > 1:
				var cls_file = parts[1].strip_edges()
				classes.push_back(base_dir + "/" + cls_file)
				
		elif line.begins_with("Startup="):
			startup = line.replace("Startup=", "").replace('"', "")
			
		elif line.begins_with("Name="):
			project_name = line.replace("Name=", "").replace('"', "")
			
	print("VB6 Importer: Found ", forms.size(), " forms, ", modules.size(), " modules, ", classes.size(), " classes")
	
	# Import Forms
	for frm_path in forms:
		print("VB6 Importer: Importing Form: ", frm_path)
		var form_result = import_form_file(frm_path)
		if form_result.success:
			result.forms.append(form_result)
		else:
			result.errors.append_array(form_result.errors)
			
	# Import Modules
	for mod_path in modules:
		print("VB6 Importer: Importing Module: ", mod_path)
		var mod_result = import_module(mod_path)
		if mod_result.success:
			result.modules.append(mod_result)
		else:
			result.errors.append_array(mod_result.errors)
			
	# Import Classes
	for cls_path in classes:
		print("VB6 Importer: Importing Class: ", cls_path)
		var cls_result = import_class(cls_path)
		if cls_result.success:
			result.modules.append(cls_result)
		else:
			result.errors.append_array(cls_result.errors)
	
	result.success = result.errors.size() == 0
	print("VB6 Importer: Project Import Complete. ", 
		  result.forms.size(), " forms, ", 
		  result.modules.size(), " modules imported.")
	
	return result

# =============================================================================
# FORM IMPORT
# =============================================================================

static func import_form_file(path: String) -> Dictionary:
	"""Import a single VB6 form file (.frm)."""
	var result = {
		"success": false,
		"name": "",
		"scene_path": "",
		"code_path": "",
		"errors": [],
		"warnings": [],
		"control_arrays": {}
	}
	
	var file = FileAccess.open(path, FileAccess.READ)
	if !file:
		result.errors.append("Could not open file: " + path)
		return result
	
	var form_name = path.get_file().get_basename()
	result.name = form_name
	
	# Create root node (no anchors preset - size set by ClientWidth/ClientHeight)
	var root = Control.new()
	root.name = form_name
	
	# Parse the form
	var parse_result = _parse_form_content(file, root)
	result.control_arrays = parse_result.control_arrays
	result.warnings.append_array(parse_result.warnings)
	
	# Post-process: swap MultiLine TextBoxes from LineEdit to TextEdit
	_post_process_multiline(root)
	
	# Post-process: group VB.OptionButton radio buttons within same parent
	_post_process_radio_groups(root)
	
	# Post-process: extract .frx embedded images if available
	var frx_path = path.get_basename() + ".frx"
	if FileAccess.file_exists(frx_path):
		_extract_frx_images(frx_path, root, result)
	
	# Save the scene
	_ensure_dir("res://start_forms")
	var packed = PackedScene.new()
	packed.pack(root)
	var scene_path = "res://start_forms/" + form_name + ".tscn"
	var save_err = ResourceSaver.save(packed, scene_path)
	if save_err != OK:
		result.errors.append("Failed to save scene: " + scene_path)
	else:
		result.scene_path = scene_path
	
	# Transform and save the code
	if parse_result.code != "":
		_ensure_dir("res://mixed")
		var transformed_code = _transform_vb6_code(parse_result.code, form_name, parse_result.control_arrays)
		var code_path = "res://mixed/" + form_name + ".vg"
		var bf = FileAccess.open(code_path, FileAccess.WRITE)
		if bf:
			bf.store_string(transformed_code)
			bf.close()
			result.code_path = code_path
		else:
			result.errors.append("Failed to save code: " + code_path)
	
	root.free()
	result.success = result.errors.size() == 0
	return result

static func _parse_form_content(file: FileAccess, root: Control) -> Dictionary:
	"""Parse the content of a VB6 form file."""
	var result = {
		"code": "",
		"control_arrays": {},  # name -> [indices]
		"warnings": []
	}
	
	var current_parent: Node = root
	var parent_stack: Array = []
	var code_mode = false
	var in_font_block = false
	var in_menu_block = false
	var current_font: Dictionary = {}
	var current_control_name = ""
	var current_control_index = -1
	var pending_properties: Array = []
	var menu_items_tree: Array = []  # Collected menu item tree structure
	var menu_item_stack: Array = []  # Stack for tracking nesting during parse
	var in_menu_depth: int = 0  # Current menu nesting depth
	
	while !file.eof_reached():
		var line = file.get_line()
		var trim = line.strip_edges()
		
		# Skip version line
		if trim.begins_with("VERSION "):
			continue
		
		# Detect code section start
		if trim.begins_with("Attribute VB_"):
			code_mode = true
			continue
			
		if code_mode:
			# Skip Attribute lines in code section
			if not trim.begins_with("Attribute "):
				result.code += line + "\n"
			continue
		
		# Handle font property blocks
		if trim.begins_with("BeginProperty Font"):
			in_font_block = true
			current_font = {}
			continue
			
		if trim == "EndProperty" and in_font_block:
			in_font_block = false
			# Apply font to current control
			if current_parent and current_parent != root:
				_apply_font(current_parent, current_font)
			continue
			
		if in_font_block:
			var parts = trim.split("=", true, 1)
			if parts.size() == 2:
				var key = parts[0].strip_edges()
				var val = parts[1].strip_edges()
				current_font[key] = val
			continue
		
		# Handle VB6 Menu blocks (tree-based: collect items, build after parsing)
		if trim.begins_with("Begin VB.Menu "):
			var parts = trim.split(" ", false)
			if parts.size() >= 3:
				var menu_name = parts[2]
				var menu_item = {"name": menu_name, "caption": "", "shortcut": "", "checked": false, "enabled": true, "visible": true, "children": []}
				
				# Nest under parent or add to top-level tree
				if menu_item_stack.size() > 0:
					menu_item_stack.back().children.append(menu_item)
				else:
					menu_items_tree.append(menu_item)
				menu_item_stack.push_back(menu_item)
				in_menu_block = true
				in_menu_depth += 1
			continue
		
		if in_menu_block and trim == "End":
			menu_item_stack.pop_back()
			in_menu_depth -= 1
			if menu_item_stack.size() == 0:
				in_menu_block = false
			continue
		
		if in_menu_block and trim.contains("="):
			var parts = trim.split("=", true, 1)
			var key = parts[0].strip_edges()
			var val = parts[1].strip_edges() if parts.size() > 1 else ""
			
			# Remove quotes
			if val.begins_with('"') and val.ends_with('"'):
				val = val.substr(1, val.length() - 2)
			
			var cur_item = menu_item_stack.back() if menu_item_stack.size() > 0 else null
			if cur_item:
				match key:
					"Caption":
						cur_item.caption = val
					"Shortcut":
						cur_item.shortcut = val
					"Checked":
						cur_item.checked = (val == "-1" or val.to_lower() == "true")
					"Enabled":
						cur_item.enabled = (val == "-1" or val.to_lower() == "true" or val == "1")
					"Visible":
						cur_item.visible = (val == "-1" or val.to_lower() == "true" or val == "1")
			continue
		
		# Begin block - new control
		if trim.begins_with("Begin "):
			var parts = trim.split(" ", false)
			if parts.size() >= 3:
				var vb_class = parts[1]
				var vb_name = parts[2]
				
				# Check for control array index
				current_control_index = -1
				current_control_name = vb_name
				
				var new_node: Node = null
				
				# Special handling for Form
				if vb_class == "VB.Form" or vb_class == "VB.MDIForm":
					new_node = root
					new_node.name = vb_name
				else:
					new_node = _create_control(vb_class, vb_name)
					if new_node:
						current_parent.add_child(new_node)
						new_node.owner = root
					else:
						result.warnings.append("Unknown control type: " + vb_class)
						new_node = Control.new()
						new_node.name = vb_name
						new_node.set_meta("vb6_class", vb_class)
						current_parent.add_child(new_node)
						new_node.owner = root
				
				parent_stack.push_back(current_parent)
				current_parent = new_node
				
		elif trim.begins_with("End") and not trim.begins_with("EndProperty"):
			# Handle control array registration
			if current_control_index >= 0 and current_control_name != "":
				if not result.control_arrays.has(current_control_name):
					result.control_arrays[current_control_name] = []
				result.control_arrays[current_control_name].append(current_control_index)
				
				# Rename control to include index
				if current_parent:
					current_parent.name = current_control_name + "_" + str(current_control_index)
			
			current_control_name = ""
			current_control_index = -1
			
			if parent_stack.size() > 0:
				current_parent = parent_stack.pop_back()
				
		elif trim.contains("=") and not code_mode:
			# Property setting
			var split = trim.split("=", true, 1)
			var key = split[0].strip_edges()
			var val = split[1].strip_edges() if split.size() > 1 else ""
			
			# Handle Index property for control arrays
			if key == "Index":
				current_control_index = val.to_int()
				
			if current_parent:
				_apply_property(current_parent, key, val, root)
	
	# Build menu bar from collected menu tree (after parsing)
	if menu_items_tree.size() > 0:
		var mb = MenuBar.new()
		mb.name = "MenuBar"
		root.add_child(mb)
		mb.owner = root
		mb.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_build_menu_tree(mb, menu_items_tree, root)
	
	return result

static func _build_menu_tree(menu_bar: MenuBar, items: Array, owner: Node):
	"""Build Godot MenuBar structure from collected VB6 menu tree."""
	for item in items:
		var caption = item.get("caption", "").replace("&", "")
		var menu_name = item.get("name", "")
		var children = item.get("children", [])
		
		# Every top-level item creates a PopupMenu on the MenuBar
		var popup = PopupMenu.new()
		popup.name = menu_name + "_Popup"
		menu_bar.add_child(popup)
		popup.owner = owner
		var idx = menu_bar.get_menu_count() - 1
		menu_bar.set_menu_title(idx, caption)
		
		# Add children as items in this popup
		if children.size() > 0:
			_build_popup_items(popup, children, owner)

static func _build_popup_items(popup: PopupMenu, items: Array, owner: Node):
	"""Recursively build PopupMenu items, handling submenus at any depth."""
	for item in items:
		var caption = item.get("caption", "").replace("&", "")
		var menu_name = item.get("name", "")
		var children = item.get("children", [])
		
		# Separator
		if caption == "-":
			popup.add_separator()
			continue
		
		if children.size() > 0:
			# Sub-submenu: create a child PopupMenu
			var sub_popup = PopupMenu.new()
			sub_popup.name = menu_name + "_Popup"
			popup.add_child(sub_popup)
			sub_popup.owner = owner
			popup.add_submenu_item(caption, sub_popup.name)
			_build_popup_items(sub_popup, children, owner)
		else:
			# Leaf item
			var item_id = popup.item_count
			popup.add_item(caption, item_id)
			
			if not item.get("enabled", true):
				popup.set_item_disabled(item_id, true)
			if item.get("checked", false):
				popup.set_item_checked(item_id, true)
			if not item.get("visible", true):
				# Store as metadata since PopupMenu doesn't have per-item visibility
				popup.set_item_metadata(item_id, {"name": menu_name, "hidden": true})
			else:
				popup.set_item_metadata(item_id, menu_name)

static func _create_control(vb_class: String, vb_name: String) -> Node:
	"""Create a Godot node from a VB6 control class."""
	var godot_type = CONTROL_MAP.get(vb_class, "")
	
	if godot_type == "":
		return null
	
	var new_node: Node = null
	
	# Check for custom widget scenes first
	var custom_path = "res://custom_widgets/" + godot_type + ".tscn"
	if ResourceLoader.exists(custom_path):
		new_node = load(custom_path).instantiate()
	elif ClassDB.class_exists(godot_type):
		new_node = ClassDB.instantiate(godot_type)
	else:
		new_node = Control.new()
	
	if new_node:
		new_node.name = vb_name
		new_node.set_meta("vb6_class", vb_class)
	
	return new_node

# =============================================================================
# PROPERTY APPLICATION
# =============================================================================

static func _apply_property(node: Node, key: String, val: String, owner: Node):
	"""Apply a VB6 property to a Godot node."""
	# Remove quotes from string values
	if val.begins_with('"') and val.ends_with('"'):
		val = val.substr(1, val.length() - 2)
	
	# Remove VB6 comment suffixes like "'False" -> just the value before
	if val.contains("'"):
		val = val.split("'")[0].strip_edges()
	
	match key:
		# Text/Caption
		"Caption", "Text":
			if node.has_method("set_text"):
				node.text = val
			elif "text" in node:
				node.text = val
		
		# Position (in twips)
		"Left":
			if node is Control:
				node.position.x = int(val) / TWIPS_PER_PIXEL
		"Top":
			if node is Control:
				node.position.y = int(val) / TWIPS_PER_PIXEL
		"ClientLeft":
			if node is Control:
				node.position.x = int(val) / TWIPS_PER_PIXEL
		"ClientTop":
			if node is Control:
				node.position.y = int(val) / TWIPS_PER_PIXEL
				
		# Size (in twips)
		"Width", "ClientWidth", "ScaleWidth":
			if node is Control:
				node.custom_minimum_size.x = int(val) / TWIPS_PER_PIXEL
				node.size.x = int(val) / TWIPS_PER_PIXEL
		"Height", "ClientHeight", "ScaleHeight":
			if node is Control:
				node.custom_minimum_size.y = int(val) / TWIPS_PER_PIXEL
				node.size.y = int(val) / TWIPS_PER_PIXEL
		
		# Visibility
		"Visible":
			if node is CanvasItem:
				node.visible = (val == "-1" or val.to_lower() == "true" or val == "1")
		
		# Enabled state
		"Enabled":
			var enabled = (val == "-1" or val.to_lower() == "true" or val == "1")
			if "disabled" in node:
				node.disabled = not enabled
			if "editable" in node:
				node.editable = enabled
		
		# Tab order
		"TabIndex":
			if node is Control:
				node.set_meta("tab_index", int(val))
		
		# Alignment
		"Alignment":
			var align_val = int(val)
			if node is Label:
				match align_val:
					0: node.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
					1: node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
					2: node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			elif node is LineEdit:
				match align_val:
					0: node.alignment = HORIZONTAL_ALIGNMENT_LEFT
					1: node.alignment = HORIZONTAL_ALIGNMENT_RIGHT
					2: node.alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		# MultiLine TextBox
		"MultiLine":
			if val == "-1" or val.to_lower() == "true":
				node.set_meta("multiline", true)
		
		# ScrollBars for TextBox
		"ScrollBars":
			node.set_meta("scrollbars", int(val))
		
		# Password char
		"PasswordChar":
			if node is LineEdit and val != "":
				node.secret = true
				node.secret_character = val
		
		# MaxLength
		"MaxLength":
			if node is LineEdit:
				node.max_length = int(val)
		
		# Locked/ReadOnly
		"Locked":
			if node is LineEdit:
				node.editable = not (val == "-1" or val.to_lower() == "true")
		
		# WordWrap
		"WordWrap":
			if node is Label:
				node.autowrap_mode = TextServer.AUTOWRAP_WORD if (val == "-1" or val.to_lower() == "true") else TextServer.AUTOWRAP_OFF
		
		# AutoSize
		"AutoSize":
			if node is Label and (val == "-1" or val.to_lower() == "true"):
				node.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		
		# ToolTip
		"ToolTipText":
			if node is Control:
				node.tooltip_text = val
		
		# Timer Interval
		"Interval":
			if node is Timer:
				node.wait_time = float(val) / 1000.0  # ms to seconds
				node.one_shot = false
		
		# Scrollbar values
		"Min":
			if node is Range:
				node.min_value = float(val)
		"Max":
			if node is Range:
				node.max_value = float(val)
		"Value":
			if node is Range:
				node.value = float(val)
			elif node is CheckBox:
				node.button_pressed = (int(val) != 0)
		"SmallChange":
			if node is Range:
				node.step = float(val)
		"LargeChange":
			if node is Range:
				node.page = float(val)
		
		# Style properties
		"Style":
			node.set_meta("vb6_style", int(val))
		"Appearance":
			node.set_meta("vb6_appearance", int(val))
		"BorderStyle":
			node.set_meta("vb6_borderstyle", int(val))
		
		# Colors
		"BackColor":
			_apply_back_color(node, val)
		"ForeColor":
			_apply_fore_color(node, val)
		
		# Picture/Image
		"Picture":
			node.set_meta("vb6_picture", val)
		
		# Tag (custom data)
		"Tag":
			node.set_meta("tag", val)
		
		# List items
		"List":
			if node is ItemList and val != "":
				node.add_item(val)
		
		# Default/Cancel buttons
		"Default":
			if val == "-1" or val.to_lower() == "true":
				node.set_meta("is_default", true)
		"Cancel":
			if val == "-1" or val.to_lower() == "true":
				node.set_meta("is_cancel", true)
		
		# =================================================================
		# Form/Window Properties (for root form node)
		# =================================================================
		
		# Window state
		"WindowState":
			# 0=Normal, 1=Minimized, 2=Maximized
			node.set_meta("window_state", int(val))
		
		# Startup position
		"StartUpPosition":
			# 0=Manual, 1=CenterOwner, 2=CenterScreen, 3=WindowsDefault
			node.set_meta("startup_position", int(val))
		
		# Control box (close button)
		"ControlBox":
			node.set_meta("has_control_box", val == "-1" or val.to_lower() == "true")
		
		# Max/Min buttons
		"MaxButton":
			node.set_meta("has_max_button", val == "-1" or val.to_lower() == "true")
		"MinButton":
			node.set_meta("has_min_button", val == "-1" or val.to_lower() == "true")
		
		# Moveable
		"Moveable":
			node.set_meta("is_moveable", val == "-1" or val.to_lower() == "true")
		
		# ShowInTaskbar
		"ShowInTaskbar":
			node.set_meta("show_in_taskbar", val == "-1" or val.to_lower() == "true")
		
		# KeyPreview
		"KeyPreview":
			node.set_meta("key_preview", val == "-1" or val.to_lower() == "true")
		
		# Icon
		"Icon":
			node.set_meta("vb6_icon", val)
		
		# LinkTopic (DDE - deprecated but store for reference)
		"LinkTopic":
			node.set_meta("link_topic", val)
		
		# MDI properties
		"MDIChild":
			node.set_meta("is_mdi_child", val == "-1" or val.to_lower() == "true")
		
		# Picture alignment
		"PictureAlignment":
			node.set_meta("picture_alignment", int(val))
		
		# =================================================================
		# ComboBox/ListBox Properties
		# =================================================================
		
		"Sorted":
			node.set_meta("is_sorted", val == "-1" or val.to_lower() == "true")
		"ItemData":
			node.set_meta("item_data", val)
		"ListIndex":
			if node is ItemList:
				node.select(int(val))
		"IntegralHeight":
			node.set_meta("integral_height", val == "-1" or val.to_lower() == "true")
		
		# =================================================================
		# Shape Properties
		# =================================================================
		
		"Shape":
			# 0=Rectangle, 1=Square, 2=Oval, 3=Circle, 4=RoundedRect, 5=RoundedSquare
			node.set_meta("vb6_shape", int(val))
		"FillStyle":
			node.set_meta("fill_style", int(val))
		"FillColor":
			node.set_meta("fill_color", vb_color_to_godot(val))
		"DrawWidth":
			node.set_meta("draw_width", int(val))
		"DrawMode":
			node.set_meta("draw_mode", int(val))
		"DrawStyle":
			node.set_meta("draw_style", int(val))

static func _apply_font(node: Node, font_props: Dictionary):
	"""Apply font properties to a control."""
	if not node is Control:
		return
	
	var font_name = font_props.get("Name", "").replace('"', "")
	var font_size = font_props.get("Size", "12").to_float()
	var bold = font_props.get("Weight", "400").to_int() >= 700
	var italic = font_props.get("Italic", "0") == "-1"
	var underline = font_props.get("Underline", "0") == "-1"
	var strikethrough = font_props.get("Strikethrough", "0") == "-1"
	
	# Apply font size
	if font_size > 0:
		node.add_theme_font_size_override("font_size", int(font_size * 1.33))  # Points to pixels
	
	# Store font info as metadata for later use
	node.set_meta("font_name", font_name)
	node.set_meta("font_bold", bold)
	node.set_meta("font_italic", italic)
	node.set_meta("font_underline", underline)

static func _apply_back_color(node: Node, val: String):
	"""Apply background color to a control."""
	var c = vb_color_to_godot(val)
	
	if node is Panel:
		var sb = node.get_theme_stylebox("panel")
		if not sb or not (sb is StyleBoxFlat):
			sb = StyleBoxFlat.new()
		sb.bg_color = c
		node.add_theme_stylebox_override("panel", sb)
	elif node is Button:
		var sb = StyleBoxFlat.new()
		sb.bg_color = c
		node.add_theme_stylebox_override("normal", sb)
	elif node is LineEdit:
		var sb = StyleBoxFlat.new()
		sb.bg_color = c
		node.add_theme_stylebox_override("normal", sb)
	elif "color" in node:
		node.color = c
	elif node is Control:
		node.set_meta("back_color", c)

static func _apply_fore_color(node: Node, val: String):
	"""Apply foreground/text color to a control."""
	var c = vb_color_to_godot(val)
	
	if node is Control:
		node.add_theme_color_override("font_color", c)
		node.add_theme_color_override("font_pressed_color", c)
		node.add_theme_color_override("font_hover_color", c)

static func vb_color_to_godot(val: String) -> Color:
	"""Convert VB6 color value to Godot Color."""
	var hex = val.strip_edges()
	
	# Handle hex format: &H00C0C0C0& or &H8000000F&
	if hex.begins_with("&H"):
		hex = hex.substr(2)
		if hex.ends_with("&"):
			hex = hex.substr(0, hex.length() - 1)
		
		var int_val = hex.hex_to_int()
		
		# System Color Handling (High bit set)
		if int_val >= 0x80000000:
			var sys_idx = int_val & 0xFFFF
			return _get_system_color(sys_idx)
		
		# RGB Color (VB6 is BGR format: 0xBBGGRR)
		var r = (int_val & 0xFF) / 255.0
		var g = ((int_val >> 8) & 0xFF) / 255.0
		var b = ((int_val >> 16) & 0xFF) / 255.0
		return Color(r, g, b)
	
	# Decimal format
	if val.is_valid_int():
		var int_val = val.to_int()
		
		if int_val >= 0x80000000:
			var sys_idx = int_val & 0xFFFF
			return _get_system_color(sys_idx)
		
		var r = (int_val & 0xFF) / 255.0
		var g = ((int_val >> 8) & 0xFF) / 255.0
		var b = ((int_val >> 16) & 0xFF) / 255.0
		return Color(r, g, b)
	
	return Color.WHITE

static func _get_system_color(sys_idx: int) -> Color:
	"""Convert VB6 system color index to Godot color."""
	match sys_idx:
		0: return Color(0.0, 0.0, 0.0)        # Scrollbar
		1: return Color(0.0, 0.5, 0.5)        # Desktop
		2: return Color(0.0, 0.0, 0.5)        # ActiveTitle
		3: return Color(0.5, 0.5, 0.5)        # InactiveTitle
		4: return Color(0.75, 0.75, 0.75)     # Menu
		5: return Color(1.0, 1.0, 1.0)        # Window Background
		6: return Color(0.0, 0.0, 0.0)        # Window Frame
		7: return Color(0.0, 0.0, 0.0)        # MenuText
		8: return Color(0.0, 0.0, 0.0)        # WindowText
		9: return Color(1.0, 1.0, 1.0)        # TitleText
		10: return Color(0.75, 0.75, 0.75)    # ActiveBorder
		11: return Color(0.75, 0.75, 0.75)    # InactiveBorder
		12: return Color(0.5, 0.5, 0.5)       # AppWorkspace
		13: return Color(0.0, 0.0, 0.5)       # Highlight
		14: return Color(1.0, 1.0, 1.0)       # HighlightText
		15: return Color(0.82, 0.82, 0.82)    # ButtonFace (3D Objects)
		16: return Color(0.5, 0.5, 0.5)       # ButtonShadow
		17: return Color(0.5, 0.5, 0.5)       # GrayText
		18: return Color(0.0, 0.0, 0.0)       # ButtonText
		19: return Color(0.75, 0.75, 0.75)    # InactiveTitleText
		20: return Color(1.0, 1.0, 1.0)       # ButtonHighlight
		_: return Color(0.75, 0.75, 0.75)     # Default gray

# =============================================================================
# MODULE AND CLASS IMPORT
# =============================================================================

static func import_module(path: String) -> Dictionary:
	"""Import a VB6 module file (.bas)."""
	var result = {
		"success": false,
		"name": path.get_file().get_basename(),
		"path": "",
		"errors": []
	}
	
	var content = FileAccess.get_file_as_string(path)
	if content == "":
		result.errors.append("Could not read module: " + path)
		return result
	
	# Transform the code
	var transformed = _transform_vb6_code(content, result.name, {})
	
	# Save
	_ensure_dir("res://mixed")
	var save_path = "res://mixed/" + result.name + ".vg"
	var f = FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(transformed)
		f.close()
		result.path = save_path
		result.success = true
	else:
		result.errors.append("Could not save module: " + save_path)
	
	return result

static func import_class(path: String) -> Dictionary:
	"""Import a VB6 class file (.cls)."""
	var result = {
		"success": false,
		"name": path.get_file().get_basename(),
		"path": "",
		"errors": []
	}
	
	var content = FileAccess.get_file_as_string(path)
	if content == "":
		result.errors.append("Could not read class: " + path)
		return result
	
	# Transform the code, wrapping in a Class block
	var cls_name = result.name
	var transformed = "Class " + cls_name + "\n"
	transformed += _transform_vb6_code(content, cls_name, {})
	transformed += "End Class\n"
	
	# Save
	_ensure_dir("res://mixed")
	var save_path = "res://mixed/" + result.name + ".vg"
	var f = FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(transformed)
		f.close()
		result.path = save_path
		result.success = true
	else:
		result.errors.append("Could not save class: " + save_path)
	
	return result

# =============================================================================
# CODE TRANSFORMATION
# =============================================================================

## VB6 function to VisualGasic equivalents
const VB6_FUNCTION_MAP: Dictionary = {
	# String functions
	"Len(": "Len(",
	"Mid$(": "Mid(",
	"Mid(": "Mid(",
	"Left$(": "Left(",
	"Left(": "Left(",
	"Right$(": "Right(",
	"Right(": "Right(",
	"UCase$(": "UCase(",
	"UCase(": "UCase(",
	"LCase$(": "LCase(",
	"LCase(": "LCase(",
	"Trim$(": "Trim(",
	"Trim(": "Trim(",
	"LTrim$(": "LTrim(",
	"LTrim(": "LTrim(",
	"RTrim$(": "RTrim(",
	"RTrim(": "RTrim(",
	"InStr(": "InStr(",
	"InStrRev(": "InStrRev(",
	"Replace(": "Replace(",
	"Split(": "Split(",
	"Join(": "Join(",
	"Space$(": "Space(",
	"String$(": "String(",
	"StrComp(": "StrComp(",
	"Asc(": "Asc(",
	"Chr$(": "Chr(",
	"Chr(": "Chr(",
	
	# Conversion functions
	"Val(": "Val(",
	"Str$(": "Str(",
	"Str(": "Str(",
	"CStr(": "CStr(",
	"CInt(": "CInt(",
	"CLng(": "CLng(",
	"CDbl(": "CDbl(",
	"CSng(": "CSng(",
	"CBool(": "CBool(",
	"CDate(": "CDate(",
	"CByte(": "CByte(",
	"Hex$(": "Hex(",
	"Hex(": "Hex(",
	"Oct$(": "Oct(",
	"Oct(": "Oct(",
	
	# Math functions
	"Abs(": "Abs(",
	"Int(": "Int(",
	"Fix(": "Fix(",
	"Sgn(": "Sgn(",
	"Sqr(": "Sqr(",
	"Log(": "Log(",
	"Exp(": "Exp(",
	"Sin(": "Sin(",
	"Cos(": "Cos(",
	"Tan(": "Tan(",
	"Atn(": "Atn(",
	"Rnd(": "Rnd(",
	"Rnd": "Rnd()",
	"Round(": "Round(",
	
	# Array functions
	"UBound(": "UBound(",
	"LBound(": "LBound(",
	"Array(": "Array(",
	
	# Date/Time functions
	"Now": "Now()",
	"Date$": "Date()",
	"Date": "Date()",
	"Time$": "Time()",
	"Time": "Time()",
	"Timer": "Timer()",
	"Year(": "Year(",
	"Month(": "Month(",
	"Day(": "Day(",
	"Hour(": "Hour(",
	"Minute(": "Minute(",
	"Second(": "Second(",
	"Weekday(": "Weekday(",
	"DateSerial(": "DateSerial(",
	"TimeSerial(": "TimeSerial(",
	"DateAdd(": "DateAdd(",
	"DateDiff(": "DateDiff(",
	
	# Type checking
	"IsNumeric(": "IsNumeric(",
	"IsDate(": "IsDate(",
	"IsEmpty(": "IsEmpty(",
	"IsNull(": "IsNull(",
	"IsArray(": "IsArray(",
	"IsObject(": "IsObject(",
	"TypeName(": "TypeName(",
	"VarType(": "VarType(",
	
	# File functions
	"Dir(": "Dir(",
	"Dir$": "Dir()",
	"FileLen(": "FileLen(",
	"EOF(": "EOF(",
	"LOF(": "LOF(",
	"FreeFile": "FreeFile()",
	
	# Misc
	"IIf(": "IIf(",
	"Choose(": "Choose(",
	"Switch(": "Switch(",
	"Format$(": "Format(",
	"Format(": "Format(",
	"InputBox(": "InputBox(",
	"MsgBox(": "MsgBox(",
	"MsgBox ": "MsgBox ",
	"DoEvents": "DoEvents()",
	"Shell(": "Shell(",
	"Environ$(": "Environ(",
	"Environ(": "Environ(",
	"Command$": "Command()",
	"App.Path": "App.Path",
	"App.EXEName": "App.EXEName",
}

## VB6 constants to VisualGasic equivalents
const VB6_CONSTANTS: Dictionary = {
	# Boolean
	"True": "True",
	"False": "False",
	
	# MsgBox buttons
	"vbOKOnly": "vbOKOnly",
	"vbOKCancel": "vbOKCancel",
	"vbAbortRetryIgnore": "vbAbortRetryIgnore",
	"vbYesNoCancel": "vbYesNoCancel",
	"vbYesNo": "vbYesNo",
	"vbRetryCancel": "vbRetryCancel",
	"vbCritical": "vbCritical",
	"vbQuestion": "vbQuestion",
	"vbExclamation": "vbExclamation",
	"vbInformation": "vbInformation",
	
	# MsgBox return values
	"vbOK": "vbOK",
	"vbCancel": "vbCancel",
	"vbAbort": "vbAbort",
	"vbRetry": "vbRetry",
	"vbIgnore": "vbIgnore",
	"vbYes": "vbYes",
	"vbNo": "vbNo",
	
	# String constants
	"vbCrLf": "vbCrLf",
	"vbCr": "vbCr",
	"vbLf": "vbLf",
	"vbTab": "vbTab",
	"vbNewLine": "vbNewLine",
	"vbNullChar": "vbNullChar",
	"vbNullString": "vbNullString",
	
	# Comparison
	"vbBinaryCompare": "vbBinaryCompare",
	"vbTextCompare": "vbTextCompare",
	
	# Misc
	"vbEmpty": "vbEmpty",
	"vbNull": "vbNull",
	"Nothing": "Nothing",
}

static func _transform_vb6_code(code: String, form_name: String, control_arrays: Dictionary) -> String:
	"""Transform VB6 code to VisualGasic syntax."""
	var lines = code.split("\n")
	var result_lines: Array = []
	var in_attribute_section = true
	
	for line in lines:
		var trim = line.strip_edges()
		
		# Skip Attribute lines
		if trim.begins_with("Attribute "):
			continue
		
		# Skip VERSION line
		if trim.begins_with("VERSION "):
			continue
		
		in_attribute_section = false
		
		# Transform the line
		var transformed = _transform_line(line, control_arrays)
		result_lines.append(transformed)
	
	# Add header comment
	var header = "' VisualGasic - Imported from VB6\n"
	header += "' Form: " + form_name + "\n"
	header += "' Note: Some manual adjustments may be required\n"
	header += "Option Explicit\n\n"
	
	# Add FindControl helper if control arrays were used
	if control_arrays.size() > 0:
		header += "' Helper for control array access (auto-generated)\n"
		header += "Private Function FindControl(name As String) As Control\n"
		header += "    Return Me.FindChild(name)\n"
		header += "End Function\n\n"
	
	return header + "\n".join(result_lines)

static func _transform_line(line: String, control_arrays: Dictionary) -> String:
	"""Transform a single line of VB6 code."""
	var result = line
	var trim = result.strip_edges()
	
	# Skip empty lines and comments
	if trim == "" or trim.begins_with("'"):
		return result
	
	# Handle control array access
	for ctrl_name in control_arrays.keys():
		var pattern = ctrl_name + "("
		if result.contains(pattern):
			# First pass: replace literal indices: Num(5) -> Num_5
			var lit_regex = RegEx.new()
			lit_regex.compile(ctrl_name + "\\((\\d+)\\)")
			var lit_matches = lit_regex.search_all(result)
			for m in lit_matches:
				var full_match = m.get_string()
				var index = m.get_string(1)
				result = result.replace(full_match, ctrl_name + "_" + index)
			
			# Second pass: replace variable indices: Num(expr) -> FindControl("Num_" & CStr(expr))
			if result.contains(pattern):
				var var_regex = RegEx.new()
				var_regex.compile(ctrl_name + "\\(([^)]+)\\)")
				var var_matches = var_regex.search_all(result)
				for m in var_matches:
					var full_match = m.get_string()
					var expr = m.get_string(1)
					result = result.replace(full_match, 'FindControl("' + ctrl_name + '_" & CStr(' + expr + '))')
	
	# =========================================================================
	# VB6-SPECIFIC SYNTAX TRANSFORMATIONS
	# =========================================================================
	
	# Transform standalone End statement
	if trim == "End":
		result = result.replace("End", "Exit Sub  ' VB6: End")
	
	# Remove explicit Let keyword
	if trim.begins_with("Let "):
		result = result.replace("Let ", "")
	
	# Transform On Error statements to comments with Try/Catch suggestion
	if "On Error GoTo 0" in result:
		result = result.replace("On Error GoTo 0", "' On Error GoTo 0  ' Clear error handler")
	elif "On Error Resume Next" in result:
		result = result.replace("On Error Resume Next", "' On Error Resume Next  ' TODO: Use Try/Catch")
	elif "On Error GoTo" in result:
		var regex = RegEx.new()
		regex.compile("On Error GoTo (\\w+)")
		var m = regex.search(result)
		if m:
			var label = m.get_string(1)
			result = result.replace(m.get_string(), "' On Error GoTo " + label + "  ' TODO: Use Try/Catch")
	
	# Transform Set statement (object assignment)
	if trim.begins_with("Set "):
		result = result.replace("Set ", "")
	
	# Transform Debug.Print -> Print (or Debug.Print if you want to keep it)
	if "Debug.Print " in result:
		result = result.replace("Debug.Print ", "Print ")
	
	# Transform Print # (file output)
	var print_regex = RegEx.new()
	print_regex.compile("Print #(\\d+),")
	var print_match = print_regex.search(result)
	if print_match:
		var file_num = print_match.get_string(1)
		result = result.replace(print_match.get_string(), "Print #" + file_num + ",")
	
	# Transform property access with default properties
	# TextBox.Text -> TextBox.Text (usually same, but Me. prefix)
	if "Me." in result:
		result = result.replace("Me.", "")  # VisualGasic uses implicit self
	
	# Transform Exit Sub/Function/For/Do (these are the same in VisualGasic)
	# No changes needed - Exit Sub, Exit Function, Exit For, Exit Do work
	
	# Transform GoSub...Return (legacy, add warning)
	if trim.begins_with("GoSub "):
		result = result + "  ' WARNING: GoSub is deprecated, consider using Sub/Function"
	if trim == "Return" and not "Return " in trim:
		# Standalone Return (from GoSub) vs Return value
		result = result + "  ' WARNING: GoSub Return - verify this is not a function return"
	
	# Transform With...End With (VisualGasic supports this)
	# No changes needed
	
	# Transform line continuation character (_ at end of line)
	# VisualGasic also supports this, no change needed
	
	# Transform line numbers (old BASIC style)
	var linenum_regex = RegEx.new()
	linenum_regex.compile("^(\\s*)(\\d+)(\\s+)")
	var linenum_match = linenum_regex.search(result)
	if linenum_match:
		var indent = linenum_match.get_string(1)
		var linenum = linenum_match.get_string(2)
		result = indent + "' Line " + linenum + ": " + result.substr(linenum_match.get_end())
	
	# Transform label definitions (for GoTo targets)
	var label_regex = RegEx.new()
	label_regex.compile("^(\\s*)(\\w+):$")
	var label_match = label_regex.search(trim)
	if label_match and not trim.begins_with("'"):
		# This is a label, keep it as-is (VisualGasic supports labels)
		pass
	
	# Transform type declaration suffix characters
	# Dim x$ -> Dim x As String, etc.
	result = _transform_type_suffixes(result)
	
	return result

static func _transform_type_suffixes(line: String) -> String:
	"""Transform VB6 type suffix characters to explicit types."""
	var result = line
	
	# Only process Dim/Private/Public/Static declarations
	var trim = result.strip_edges()
	if not (trim.begins_with("Dim ") or trim.begins_with("Private ") or 
			trim.begins_with("Public ") or trim.begins_with("Static ")):
		return result
	
	# Type suffixes: $ = String, % = Integer, & = Long, ! = Single, # = Double, @ = Currency
	var type_suffixes = {
		"$": "String",
		"%": "Integer",
		"&": "Long",
		"!": "Single",
		"#": "Double",
		"@": "Currency"
	}
	
	for suffix in type_suffixes:
		var type_name = type_suffixes[suffix]
		# Match variable name ending with suffix (before comma or As or end of line)
		var regex = RegEx.new()
		regex.compile("(\\w+)\\" + suffix + "(?=\\s*[,\\s]|$)")
		var matches = regex.search_all(result)
		for m in matches:
			var var_name = m.get_string(1)
			result = result.replace(var_name + suffix, var_name + " As " + type_name)
	
	return result

# =============================================================================
# LEGACY COMPATIBILITY
# =============================================================================

static func import_form(path: String, parent_node: Node, owner_node: Node = null) -> String:
	"""Legacy import function for backward compatibility."""
	var file = FileAccess.open(path, FileAccess.READ)
	if !file:
		push_error("Could not open file: " + path)
		return ""
	
	var result = _parse_form_content(file, parent_node)
	
	# Connect signals for the imported controls
	_auto_connect_signals(parent_node, owner_node)
	
	return result.code

static func _auto_connect_signals(node: Node, owner: Node):
	"""Recursively connect VB6-style signals to handlers."""
	if not owner:
		return
	
	var vb_name = node.name
	var node_class = node.get_class()
	
	# Get event mapping for this node type
	if EVENT_MAP.has(node_class):
		var events = EVENT_MAP[node_class]
		for vb_event in events:
			var godot_signal = events[vb_event]
			var handler_name = vb_name + "_" + vb_event
			
			if owner.has_method(handler_name) and node.has_signal(godot_signal):
				if not node.is_connected(godot_signal, Callable(owner, handler_name)):
					node.connect(godot_signal, Callable(owner, handler_name))
	
	# Recurse to children
	for child in node.get_children():
		_auto_connect_signals(child, owner)

# =============================================================================
# IMPORT REPORT GENERATION
# =============================================================================

static func generate_import_report(project_result: Dictionary) -> String:
	"""Generate a detailed import report for a VB6 project import."""
	var report = ""
	report += "=" .repeat(60) + "\n"
	report += "VB6 PROJECT IMPORT REPORT\n"
	report += "=" .repeat(60) + "\n\n"
	
	# Summary
	report += "SUMMARY\n"
	report += "-" .repeat(40) + "\n"
	report += "Forms Imported:   %d\n" % project_result.get("forms", []).size()
	report += "Modules Imported: %d\n" % project_result.get("modules", []).size()
	report += "Errors:           %d\n" % project_result.get("errors", []).size()
	report += "Warnings:         %d\n" % project_result.get("warnings", []).size()
	report += "\n"
	
	# Forms
	var forms = project_result.get("forms", [])
	if forms.size() > 0:
		report += "IMPORTED FORMS\n"
		report += "-" .repeat(40) + "\n"
		for form in forms:
			report += "  [OK] %s\n" % form.get("name", "Unknown")
			report += "       Scene: %s\n" % form.get("scene_path", "N/A")
			report += "       Code:  %s\n" % form.get("code_path", "N/A")
			
			var ctrl_arrays = form.get("control_arrays", {})
			if ctrl_arrays.size() > 0:
				report += "       Control Arrays: %s\n" % str(ctrl_arrays.keys())
			
			var form_warnings = form.get("warnings", [])
			for warn in form_warnings:
				report += "       [WARN] %s\n" % warn
		report += "\n"
	
	# Modules
	var modules = project_result.get("modules", [])
	if modules.size() > 0:
		report += "IMPORTED MODULES\n"
		report += "-" .repeat(40) + "\n"
		for mod in modules:
			report += "  [OK] %s\n" % mod.get("name", "Unknown")
			report += "       Path: %s\n" % mod.get("path", "N/A")
		report += "\n"
	
	# Errors
	var errors = project_result.get("errors", [])
	if errors.size() > 0:
		report += "ERRORS\n"
		report += "-" .repeat(40) + "\n"
		for err in errors:
			report += "  [ERROR] %s\n" % err
		report += "\n"
	
	# Warnings
	var warnings = project_result.get("warnings", [])
	if warnings.size() > 0:
		report += "WARNINGS\n"
		report += "-" .repeat(40) + "\n"
		for warn in warnings:
			report += "  [WARN] %s\n" % warn
		report += "\n"
	
	# Manual steps needed
	report += "MANUAL STEPS REQUIRED\n"
	report += "-" .repeat(40) + "\n"
	report += "1. Review and fix any 'On Error' statements (convert to Try/Catch)\n"
	report += "2. Replace VB6 'End' statements with appropriate exit commands\n"
	report += "3. Check control array access patterns\n"
	report += "4. Update any database/data control references\n"
	report += "5. Review menu shortcut key bindings\n"
	report += "6. Test signal connections for event handlers\n"
	report += "7. Adjust form sizes/positions for Godot coordinate system\n"
	report += "\n"
	
	report += "=" .repeat(60) + "\n"
	report += "Import Complete\n"
	
	return report

static func save_import_report(report: String, project_name: String) -> bool:
	"""Save the import report to a file."""
	_ensure_dir("res://import_reports")
	var path = "res://import_reports/" + project_name + "_import_report.txt"
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(report)
		f.close()
		print("VB6 Importer: Report saved to ", path)
		return true
	return false

# =============================================================================
# UTILITY: Check if a control type is supported
# =============================================================================

static func is_control_supported(vb_class: String) -> bool:
	"""Check if a VB6 control type is supported for import."""
	return CONTROL_MAP.has(vb_class)

static func get_supported_controls() -> Array:
	"""Get list of all supported VB6 control types."""
	return CONTROL_MAP.keys()

static func get_godot_equivalent(vb_class: String) -> String:
	"""Get the Godot equivalent for a VB6 control type."""
	return CONTROL_MAP.get(vb_class, "")

# =============================================================================
# POST-PROCESSING: MULTILINE TEXTBOX SWAP
# =============================================================================

static func _post_process_multiline(root: Node):
	"""Swap LineEdit nodes marked as multiline to TextEdit after parsing."""
	var to_swap: Array = []
	_find_multiline_nodes(root, to_swap)
	
	for old_node in to_swap:
		var new_node = TextEdit.new()
		new_node.name = old_node.name
		if old_node is Control:
			new_node.position = old_node.position
			new_node.size = old_node.size
			new_node.custom_minimum_size = old_node.custom_minimum_size
		new_node.text = old_node.text
		new_node.tooltip_text = old_node.tooltip_text
		new_node.visible = old_node.visible
		
		# Copy metadata
		for meta_key in old_node.get_meta_list():
			new_node.set_meta(meta_key, old_node.get_meta(meta_key))
		
		# Copy theme overrides
		if old_node.has_theme_font_size_override("font_size"):
			new_node.add_theme_font_size_override("font_size", old_node.get_theme_font_size("font_size"))
		if old_node.has_theme_color_override("font_color"):
			new_node.add_theme_color_override("font_color", old_node.get_theme_color("font_color"))
		
		# Handle scrollbars: 0=None, 1=Horizontal, 2=Vertical, 3=Both
		var scrollbars = old_node.get_meta("scrollbars", 0)
		if scrollbars == 0:
			new_node.scroll_fit_content_height = true
		
		# Handle editable/locked
		new_node.editable = old_node.editable if old_node is LineEdit else true
		
		# Replace in parent
		var parent = old_node.get_parent()
		var idx = old_node.get_index()
		parent.remove_child(old_node)
		parent.add_child(new_node)
		parent.move_child(new_node, idx)
		new_node.owner = root
		old_node.free()

static func _find_multiline_nodes(node: Node, result: Array):
	"""Recursively find LineEdit nodes with multiline metadata."""
	if node is LineEdit and node.get_meta("multiline", false):
		result.append(node)
	for child in node.get_children():
		_find_multiline_nodes(child, result)

# =============================================================================
# POST-PROCESSING: OPTIONBUTTON RADIO GROUPS
# =============================================================================

static func _post_process_radio_groups(root: Node):
	"""Group VB.OptionButton controls (imported as CheckBox) within the same parent into ButtonGroups."""
	_group_radio_buttons_in(root)

static func _group_radio_buttons_in(parent: Node):
	"""Find CheckBoxes from VB.OptionButton in this parent and group them."""
	var radio_buttons: Array = []
	for child in parent.get_children():
		if child is CheckBox and child.get_meta("vb6_class", "") == "VB.OptionButton":
			radio_buttons.append(child)
		# Recurse into containers/panels
		if child.get_child_count() > 0:
			_group_radio_buttons_in(child)
	
	if radio_buttons.size() > 1:
		var group = ButtonGroup.new()
		for btn in radio_buttons:
			btn.button_group = group

# =============================================================================
# POST-PROCESSING: .FRX IMAGE EXTRACTION
# =============================================================================

static func _extract_frx_images(frx_path: String, root: Node, result: Dictionary):
	"""Extract embedded images from a .frx binary file."""
	var file = FileAccess.open(frx_path, FileAccess.READ)
	if not file:
		result.warnings.append("Could not open .frx file: " + frx_path)
		return
	
	var data = file.get_buffer(file.get_length())
	file.close()
	
	if data.size() == 0:
		return
	
	# .frx files contain binary data for pictures, icons, and other resources.
	# Each resource is referenced by offset in the .frm file:
	#   Picture = "Form1.frx":0000
	# Format: at each offset, a 4-byte LE length prefix followed by image data.
	
	var nodes_with_pics: Array = []
	_find_nodes_with_meta(root, "vb6_picture", nodes_with_pics)
	
	for node in nodes_with_pics:
		var pic_ref: String = node.get_meta("vb6_picture", "")
		if ":" in pic_ref:
			var parts = pic_ref.split(":")
			if parts.size() >= 2:
				var offset_hex = parts[parts.size() - 1].replace('"', "").strip_edges()
				var offset = offset_hex.hex_to_int()
				
				if offset >= 0 and offset + 4 < data.size():
					# Read 4-byte little-endian length
					var length = data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16) | (data[offset + 3] << 24)
					
					if length > 0 and offset + 4 + length <= data.size():
						var img_data = data.slice(offset + 4, offset + 4 + length)
						
						# Detect format and load
						var img = Image.new()
						var err = ERR_FILE_UNRECOGNIZED
						
						# BMP (starts with "BM")
						if img_data.size() >= 2 and img_data[0] == 0x42 and img_data[1] == 0x4D:
							err = img.load_bmp_from_buffer(img_data)
						# PNG (starts with 0x89 PNG)
						elif img_data.size() >= 4 and img_data[0] == 0x89 and img_data[1] == 0x50:
							err = img.load_png_from_buffer(img_data)
						# JPG (starts with 0xFF 0xD8)
						elif img_data.size() >= 2 and img_data[0] == 0xFF and img_data[1] == 0xD8:
							err = img.load_jpg_from_buffer(img_data)
						
						if err == OK:
							var tex = ImageTexture.create_from_image(img)
							if node is TextureRect:
								node.texture = tex
							else:
								node.set_meta("imported_texture", tex)
						else:
							result.warnings.append("Could not decode image at offset %04X for %s" % [offset, node.name])

static func _find_nodes_with_meta(node: Node, meta_key: String, result: Array):
	"""Recursively find nodes with a specific metadata key."""
	if node.has_meta(meta_key):
		result.append(node)
	for child in node.get_children():
		_find_nodes_with_meta(child, meta_key, result)
