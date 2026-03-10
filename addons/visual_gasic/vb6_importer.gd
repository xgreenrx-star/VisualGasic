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
	"RichText.RichTextBox": "TextEdit",
	"RICHTEXT.RichTextCtrl": "TextEdit",
	"RichTextLib.RichTextBox": "TextEdit",  # richtx32.ocx v6
	
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
		"GotFocus": "focus_entered",
		"LostFocus": "focus_exited",
		"KeyDown": "gui_input",
		"KeyUp": "gui_input",
	},
	"LinkButton": {
		"Click": "pressed",
		"GotFocus": "focus_entered",
		"LostFocus": "focus_exited",
	},
	"LineEdit": {
		"Change": "text_changed",
		"KeyPress": "text_submitted",
		"KeyDown": "gui_input",
		"KeyUp": "gui_input",
		"GotFocus": "focus_entered",
		"LostFocus": "focus_exited",
		"DblClick": "gui_input",
	},
	"TextEdit": {
		"Change": "text_changed",
		"KeyDown": "gui_input",
		"KeyUp": "gui_input",
		"KeyPress": "gui_input",
		"GotFocus": "focus_entered",
		"LostFocus": "focus_exited",
	},
	"CheckBox": {
		"Click": "toggled",
		"GotFocus": "focus_entered",
		"LostFocus": "focus_exited",
	},
	"OptionButton": {
		"Click": "item_selected",
		"Change": "item_selected",
		"GotFocus": "focus_entered",
		"LostFocus": "focus_exited",
	},
	"ItemList": {
		"Click": "item_selected",
		"DblClick": "item_activated",
		"KeyDown": "gui_input",
		"KeyUp": "gui_input",
		"GotFocus": "focus_entered",
		"LostFocus": "focus_exited",
		"ItemCheck": "item_selected",
		"Scroll": "gui_input",
	},
	"Timer": {
		"Timer": "timeout",
	},
	"HScrollBar": {
		"Change": "value_changed",
		"Scroll": "value_changed",
		"GotFocus": "focus_entered",
		"LostFocus": "focus_exited",
	},
	"VScrollBar": {
		"Change": "value_changed",
		"Scroll": "value_changed",
		"GotFocus": "focus_entered",
		"LostFocus": "focus_exited",
	},
	"HSlider": {
		"Change": "value_changed",
		"GotFocus": "focus_entered",
		"LostFocus": "focus_exited",
	},
	"VSlider": {
		"Change": "value_changed",
		"GotFocus": "focus_entered",
		"LostFocus": "focus_exited",
	},
	"ProgressBar": {
		"Change": "value_changed",
	},
	"SpinBox": {
		"Change": "value_changed",
		"GotFocus": "focus_entered",
		"LostFocus": "focus_exited",
	},
	"Tree": {
		"Click": "item_selected",
		"DblClick": "item_activated",
		"NodeSelected": "item_selected",
		"Expand": "item_collapsed",
		"Collapse": "item_collapsed",
		"KeyDown": "gui_input",
		"GotFocus": "focus_entered",
		"LostFocus": "focus_exited",
	},
	"TabContainer": {
		"Click": "tab_changed",
		"GotFocus": "focus_entered",
		"LostFocus": "focus_exited",
	},
	"Label": {
		"Click": "gui_input",
		"DblClick": "gui_input",
	},
	"TextureRect": {
		"Click": "gui_input",
		"DblClick": "gui_input",
		"MouseDown": "gui_input",
		"MouseUp": "gui_input",
		"MouseMove": "gui_input",
	},
	"Panel": {
		"Click": "gui_input",
		"DblClick": "gui_input",
		"MouseDown": "gui_input",
		"MouseUp": "gui_input",
		"Resize": "resized",
	},
	"RichTextLabel": {
		"Click": "gui_input",
		"GotFocus": "focus_entered",
		"LostFocus": "focus_exited",
	},
	"ColorRect": {
		"Click": "gui_input",
		"MouseDown": "gui_input",
		"MouseUp": "gui_input",
		"MouseMove": "gui_input",
	},
	"RadioButton": {
		"Click": "pressed",
		"Change": "toggled",
		"GotFocus": "focus_entered",
		"LostFocus": "focus_exited",
	},
	"MenuBar": {
		# MenuBar events are wired per-child PopupMenu
	},
	"PopupMenu": {
		"Click": "id_pressed",
		"MenuClick": "id_pressed",
	},
	"StatusBar": {
		"Click": "gui_input",
		"DblClick": "gui_input",
		"PanelClick": "gui_input",
	},
	"Toolbar": {
		"ButtonClick": "gui_input",
	},
	"ListView": {
		"Click": "item_selected",
		"DblClick": "item_activated",
		"ColumnClick": "gui_input",
		"KeyDown": "gui_input",
		"KeyUp": "gui_input",
		"GotFocus": "focus_entered",
		"LostFocus": "focus_exited",
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
# ENCODING DETECTION & CONVERSION
# =============================================================================

static func _detect_encoding(data: PackedByteArray) -> String:
	"""Detect encoding from BOM or heuristic analysis of raw bytes."""
	if data.size() == 0:
		return "utf-8"
	
	# UTF-8 BOM: EF BB BF
	if data.size() >= 3 and data[0] == 0xEF and data[1] == 0xBB and data[2] == 0xBF:
		return "utf-8-bom"
	
	# UTF-16 LE BOM: FF FE
	if data.size() >= 2 and data[0] == 0xFF and data[1] == 0xFE:
		return "utf-16-le"
	
	# UTF-16 BE BOM: FE FF
	if data.size() >= 2 and data[0] == 0xFE and data[1] == 0xFF:
		return "utf-16-be"
	
	# Heuristic: check for non-UTF-8 high bytes (Windows-1252 / Latin-1 range)
	# VB6 .frm files are almost always Windows-1252 (ANSI)
	var has_high_bytes = false
	var is_valid_utf8 = true
	var i = 0
	while i < data.size():
		var b = data[i]
		if b >= 0x80:
			has_high_bytes = true
			# Check if this is valid UTF-8 multi-byte sequence
			if b >= 0xC0 and b <= 0xDF:
				if i + 1 < data.size() and (data[i + 1] & 0xC0) == 0x80:
					i += 2
					continue
				else:
					is_valid_utf8 = false
			elif b >= 0xE0 and b <= 0xEF:
				if i + 2 < data.size() and (data[i + 1] & 0xC0) == 0x80 and (data[i + 2] & 0xC0) == 0x80:
					i += 3
					continue
				else:
					is_valid_utf8 = false
			else:
				# Byte 0x80-0xBF without preceding lead byte, or 0xF0+ (rare)
				is_valid_utf8 = false
		i += 1
	
	if has_high_bytes and not is_valid_utf8:
		return "windows-1252"
	
	return "utf-8"

static func _decode_to_utf8(data: PackedByteArray, encoding: String) -> String:
	"""Decode raw bytes to a UTF-8 string based on detected encoding."""
	
	if encoding == "utf-8-bom":
		# Strip the 3-byte BOM and decode normally
		return data.slice(3).get_string_from_utf8()
	
	if encoding == "utf-16-le":
		# Convert UTF-16 LE (with BOM) to UTF-8
		return data.slice(2).get_string_from_utf16()
	
	if encoding == "utf-16-be":
		# Swap bytes to LE then decode
		var swapped = PackedByteArray()
		swapped.resize(data.size() - 2)
		for idx in range(0, data.size() - 2, 2):
			swapped[idx] = data[idx + 3]      # low byte
			swapped[idx + 1] = data[idx + 2]  # high byte
		return swapped.get_string_from_utf16()
	
	if encoding == "windows-1252":
		# Windows-1252 superset of Latin-1 (ISO 8859-1)
		# Bytes 0x80-0x9F have special mappings, 0xA0-0xFF match Unicode directly
		# Map the Windows-1252 specific range (0x80-0x9F) to Unicode codepoints
		var cp1252_map: Dictionary = {
			0x80: 0x20AC,  # €
			0x82: 0x201A,  # ‚
			0x83: 0x0192,  # ƒ
			0x84: 0x201E,  # „
			0x85: 0x2026,  # …
			0x86: 0x2020,  # †
			0x87: 0x2021,  # ‡
			0x88: 0x02C6,  # ˆ
			0x89: 0x2030,  # ‰
			0x8A: 0x0160,  # Š
			0x8B: 0x2039,  # ‹
			0x8C: 0x0152,  # Œ
			0x8E: 0x017D,  # Ž
			0x91: 0x2018,  # '
			0x92: 0x2019,  # '
			0x93: 0x201C,  # "
			0x94: 0x201D,  # "
			0x95: 0x2022,  # •
			0x96: 0x2013,  # –
			0x97: 0x2014,  # —
			0x98: 0x02DC,  # ˜
			0x99: 0x2122,  # ™
			0x9A: 0x0161,  # š
			0x9B: 0x203A,  # ›
			0x9C: 0x0153,  # œ
			0x9E: 0x017E,  # ž
			0x9F: 0x0178,  # Ÿ
		}
		
		var text = ""
		for idx in data.size():
			var b = data[idx]
			if b < 0x80:
				text += char(b)
			elif cp1252_map.has(b):
				text += char(cp1252_map[b])
			else:
				# 0xA0-0xFF map directly to Unicode (Latin-1 supplement)
				text += char(b)
		return text
	
	# Fallback
	return data.get_string_from_utf8()

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
		
		# Object= lines reference ActiveX OCX controls used by the project
		elif line.begins_with("Object="):
			var obj_info = line.replace("Object=", "").strip_edges()
			result.warnings.append("ActiveX reference (OCX): " + obj_info + " — not available in Godot; controls mapped to built-in equivalents where possible")
		
		# Reference= lines reference COM type libraries (.tlb, .olb, .dll)
		elif line.begins_with("Reference="):
			var ref_info = line.replace("Reference=", "").strip_edges()
			result.warnings.append("COM type library reference: " + ref_info + " — COM not supported; API calls will need manual replacement")
		
		# UserControl= lines reference .ctl user control files
		elif line.begins_with("UserControl="):
			var ctl_parts = line.replace("UserControl=", "").split(";")
			if ctl_parts.size() > 1:
				var ctl_file = ctl_parts[1].strip_edges()
				result.warnings.append("UserControl (.ctl) skipped: " + ctl_file + " — import UserControls manually as custom scenes")
			else:
				result.warnings.append("UserControl (.ctl) skipped: " + line)
		
		# UserDocument= lines (ActiveX documents - very rare)
		elif line.begins_with("UserDocument="):
			result.warnings.append("UserDocument skipped: " + line + " — not supported")
		
		# PropertyPage= lines (property pages for controls - rare)
		elif line.begins_with("PropertyPage="):
			result.warnings.append("PropertyPage skipped: " + line + " — not supported")
			
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
	
	# ---- Encoding detection & conversion ----
	# VB6 .frm files are typically Windows-1252 (ANSI) or sometimes UTF-16LE.
	# Godot's FileAccess assumes UTF-8. We read raw bytes, detect encoding,
	# and convert to a temp UTF-8 file if necessary.
	var raw = FileAccess.get_file_as_bytes(path)
	if raw.size() == 0:
		result.errors.append("Could not open file: " + path)
		return result
	
	var encoding = _detect_encoding(raw)
	var actual_path = path
	if encoding != "utf-8":
		# Convert and write a temp UTF-8 file
		var utf8_text = _decode_to_utf8(raw, encoding)
		if utf8_text != "":
			var tmp_path = path + ".utf8.tmp"
			var tmp_f = FileAccess.open(tmp_path, FileAccess.WRITE)
			if tmp_f:
				tmp_f.store_string(utf8_text)
				tmp_f.close()
				actual_path = tmp_path
				result.warnings.append("Converted %s encoding to UTF-8" % encoding)
	
	var file = FileAccess.open(actual_path, FileAccess.READ)
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
		# Auto-wire signals: append [connection] entries to the saved .tscn
		_auto_wire_signals_to_tscn(scene_path, root, parse_result.code)
	
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
	
	# Clean up temp encoding-converted file
	if actual_path != path and FileAccess.file_exists(actual_path):
		DirAccess.remove_absolute(actual_path)
	
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
		
		# Parse Object= lines (OCX references at top of .frm file)
		# Format: Object = "{GUID}#version#lcid"; "filename.ocx"
		if trim.begins_with("Object = ") or trim.begins_with("Object="):
			result.warnings.append("Form requires ActiveX OCX: " + trim.replace("Object = ", "").replace("Object=", "").strip_edges())
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
		
		# Handle BeginProperty blocks (Font, Picture, Icon, etc.)
		if trim.begins_with("BeginProperty "):
			var prop_name = trim.substr(len("BeginProperty ")).strip_edges()
			if prop_name.begins_with("Font"):
				in_font_block = true
				current_font = {}
			else:
				# Non-Font BeginProperty — store as metadata dict
				in_font_block = false
				_skip_or_store_property_block(file, prop_name, current_parent)
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
		# Store menu tree as metadata for signal wiring
		mb.set_meta("vb6_menu_items", menu_items_tree)
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
			else:
				# Root form Caption - store as metadata (Control has no .text)
				node.set_meta("title", val)
		
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

static func _skip_or_store_property_block(file: FileAccess, prop_name: String, node: Node):
	"""Read through a non-Font BeginProperty...EndProperty block, storing key=value pairs as metadata."""
	var props: Dictionary = {}
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "EndProperty":
			break
		var parts = line.split("=", true, 1)
		if parts.size() == 2:
			props[parts[0].strip_edges()] = parts[1].strip_edges()
	if props.size() > 0 and node:
		node.set_meta("vb6_prop_" + prop_name.to_lower().replace(" ", "_"), props)

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
	
	# Encoding-aware read
	var raw = FileAccess.get_file_as_bytes(path)
	if raw.size() == 0:
		result.errors.append("Could not read module: " + path)
		return result
	var encoding = _detect_encoding(raw)
	var content = _decode_to_utf8(raw, encoding) if encoding != "utf-8" else raw.get_string_from_utf8()
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
	
	# Encoding-aware read
	var raw = FileAccess.get_file_as_bytes(path)
	if raw.size() == 0:
		result.errors.append("Could not read class: " + path)
		return result
	var encoding = _detect_encoding(raw)
	var content = _decode_to_utf8(raw, encoding) if encoding != "utf-8" else raw.get_string_from_utf8()
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
	# Join line continuations: lines ending with " _" continue on the next line
	var raw_lines = code.split("\n")
	var joined_lines: Array = []
	var accum = ""
	for raw_line in raw_lines:
		var trimmed = raw_line.rstrip(" \t\r")
		if trimmed.ends_with(" _") or trimmed.ends_with("\t_"):
			# Strip the trailing " _" and accumulate
			accum += trimmed.substr(0, trimmed.length() - 1)
		else:
			if accum != "":
				joined_lines.append(accum + raw_line)
				accum = ""
			else:
				joined_lines.append(raw_line)
	if accum != "":
		joined_lines.append(accum)
	
	var lines = joined_lines
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
		
		# Split multi-statement lines (a = 1 : b = 2 → two separate lines)
		# But don't split inside strings or label definitions (word:)
		if ":" in trim and not trim.begins_with("'") and not trim.ends_with(":"):
			var stmts = _split_multi_statement(trim)
			if stmts.size() > 1:
				var indent = line.substr(0, line.length() - line.lstrip(" \t").length())
				for stmt in stmts:
					var transformed = _transform_line(indent + stmt, control_arrays)
					result_lines.append(transformed)
				continue
		
		# Transform the line
		var transformed = _transform_line(line, control_arrays)
		result_lines.append(transformed)
	
	# Post-pass: expand VB6 multi-variable Dim lines
	# VB6: "Dim Number, Operator As Integer" means Number=Variant, Operator=Integer
	# VisualGasic: each variable needs its own explicit type
	var expanded_lines: Array = []
	for rline in result_lines:
		var exp = _expand_multi_var_dim(rline)
		expanded_lines.append_array(exp)
	result_lines = expanded_lines
	
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
	
	# Declare Function/Sub (Win32 API calls) – not supported in VisualGasic
	if trim.begins_with("Declare Function ") or trim.begins_with("Declare Sub ") \
		or trim.begins_with("Private Declare Function ") or trim.begins_with("Private Declare Sub ") \
		or trim.begins_with("Public Declare Function ") or trim.begins_with("Public Declare Sub "):
		return result.replace(trim, "' [VB6 API] " + trim + "  ' TODO: Replace with Godot equivalent")
	
	# =========================================================================
	# CONDITIONAL COMPILATION DIRECTIVES (#If / #Else / #End If / #Const)
	# =========================================================================
	if trim.begins_with("#If ") or trim.begins_with("#ElseIf "):
		return result.replace(trim, "' [VB6 CC] " + trim)
	if trim == "#Else":
		return result.replace(trim, "' [VB6 CC] " + trim)
	if trim == "#End If":
		return result.replace(trim, "' [VB6 CC] " + trim)
	if trim.begins_with("#Const "):
		return result.replace(trim, "' [VB6 CC] " + trim)
	
	# =========================================================================
	# RAISEEVENT / WITHEVENTS / EVENT DECLARATIONS
	# =========================================================================
	
	# RaiseEvent EventName(args) -> emit_signal("EventName", args) (approximate)
	var raiseevent_regex = RegEx.new()
	raiseevent_regex.compile("^(\\s*)RaiseEvent\\s+(\\w+)\\((.*)\\)")
	var raiseevent_match = raiseevent_regex.search(result)
	if raiseevent_match:
		var indent_re = raiseevent_match.get_string(1)
		var event_name = raiseevent_match.get_string(2)
		var args = raiseevent_match.get_string(3)
		if args.strip_edges() != "":
			result = indent_re + 'emit_signal("' + event_name + '", ' + args + ')  ' + "' VB6: RaiseEvent"
		else:
			result = indent_re + 'emit_signal("' + event_name + '")  ' + "' VB6: RaiseEvent"
		return result
	
	# Simple RaiseEvent without parens: RaiseEvent EventName
	if trim.begins_with("RaiseEvent "):
		var event_name = trim.substr(len("RaiseEvent ")).strip_edges()
		var indent_re = result.substr(0, result.length() - result.lstrip(" \t").length())
		result = indent_re + 'emit_signal("' + event_name + '")  ' + "' VB6: RaiseEvent"
		return result
	
	# WithEvents declaration -> comment with note
	if "WithEvents " in trim and (trim.begins_with("Private ") or trim.begins_with("Public ") or trim.begins_with("Dim ")):
		return result.replace(trim, "' [VB6] " + trim + "  ' TODO: Use Godot signals instead of WithEvents")
	
	# Event declaration (Public Event / Private Event)
	if trim.begins_with("Public Event ") or trim.begins_with("Private Event ") or trim.begins_with("Event "):
		return result.replace(trim, "' [VB6] " + trim + "  ' TODO: Define as signal in VisualGasic")
	
	# =========================================================================
	# ERR OBJECT TRANSFORMS
	# =========================================================================
	
	# Err.Raise -> comment with TODO
	if "Err.Raise " in result:
		var err_raise_regex = RegEx.new()
		err_raise_regex.compile("Err\\.Raise\\s+(.+)")
		var err_match = err_raise_regex.search(result)
		if err_match:
			result = result.replace(err_match.get_string(), "' Err.Raise " + err_match.get_string(1) + "  ' TODO: Use Throw or push_error()")
	
	# Err.Clear -> comment
	if "Err.Clear" in result:
		result = result.replace("Err.Clear", "' Err.Clear  ' Error state cleared")
	
	# Err.Number -> 0 with comment (in expressions)
	if "Err.Number" in result and not result.strip_edges().begins_with("'"):
		result = result.replace("Err.Number", "0  ' VB6: Err.Number")
	
	# Err.Description -> "" with comment (in expressions)
	if "Err.Description" in result and not result.strip_edges().begins_with("'"):
		result = result.replace("Err.Description", '"" ' + " ' VB6: Err.Description")
	
	# Property Let -> Property Set (VisualGasic uses Set for value setters)
	if trim.begins_with("Property Let ") or trim.begins_with("Public Property Let ") \
		or trim.begins_with("Private Property Let "):
		result = result.replace("Property Let ", "Property Set ")
	
	# Transform standalone End statement (VB6 End = terminate app)
	if trim == "End":
		result = result.replace("End", "get_tree().quit()  ' VB6: End")
	
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
	
	# =========================================================================
	# VB6 PROPERTY NAME TRANSLATIONS
	# =========================================================================
	
	# .Caption -> .text (Button, Label, CheckBox, etc.)
	var caption_regex = RegEx.new()
	caption_regex.compile("\\.Caption\\b")
	result = caption_regex.sub(result, ".text", true)
	
	# .Value -> .value (ScrollBar, Slider, ProgressBar) or .button_pressed (CheckBox)
	# Only translate when not in a Val() function call
	var value_regex = RegEx.new()
	value_regex.compile("\\.Value\\b")
	result = value_regex.sub(result, ".value", true)
	
	# .Visible -> .visible
	var visible_regex = RegEx.new()
	visible_regex.compile("\\.Visible\\b")
	result = visible_regex.sub(result, ".visible", true)
	
	# .Enabled -> .disabled (inverted logic)
	# Ctrl.Enabled = False -> Ctrl.disabled = True
	# Ctrl.Enabled = True  -> Ctrl.disabled = False
	var enabled_assign_regex = RegEx.new()
	enabled_assign_regex.compile("(\\w+)\\.Enabled\\s*=\\s*(True|False|true|false)")
	var enabled_match = enabled_assign_regex.search(result)
	if enabled_match:
		var ctrl = enabled_match.get_string(1)
		var val_str = enabled_match.get_string(2)
		var inverted = "True" if val_str.to_lower() == "false" else "False"
		result = enabled_assign_regex.sub(result, ctrl + ".disabled = " + inverted)
	else:
		# Non-assignment usage (e.g. If ctrl.Enabled Then) — just rename
		var enabled_regex = RegEx.new()
		enabled_regex.compile("\\.Enabled\\b")
		result = enabled_regex.sub(result, ".disabled", true)
	
	# .Left -> .position.x, .Top -> .position.y
	var left_regex = RegEx.new()
	left_regex.compile("(?<![A-Za-z0-9_])(\\w+)\\.Left\\b")
	result = left_regex.sub(result, "$1.position.x", true)
	var top_regex = RegEx.new()
	top_regex.compile("(?<![A-Za-z0-9_])(\\w+)\\.Top\\b")
	result = top_regex.sub(result, "$1.position.y", true)
	
	# .Width -> .size.x, .Height -> .size.y
	var width_regex = RegEx.new()
	width_regex.compile("(?<![A-Za-z0-9_])(\\w+)\\.Width\\b")
	result = width_regex.sub(result, "$1.size.x", true)
	var height_regex = RegEx.new()
	height_regex.compile("(?<![A-Za-z0-9_])(\\w+)\\.Height\\b")
	result = height_regex.sub(result, "$1.size.y", true)
	
	# .BackColor -> .modulate (approximate)
	var backcolor_regex = RegEx.new()
	backcolor_regex.compile("\\.BackColor\\b")
	result = backcolor_regex.sub(result, ".modulate", true)
	
	# .ForeColor -> .add_theme_color_override("font_color", ...) — leave as comment
	# Too complex for auto-translate; keep as-is with note
	
	# =========================================================================
	# VB6 METHOD TRANSFORMS
	# =========================================================================
	
	# .SetFocus -> .grab_focus()
	var setfocus_regex = RegEx.new()
	setfocus_regex.compile("\\.SetFocus\\b")
	result = setfocus_regex.sub(result, ".grab_focus()", true)
	
	# .Refresh -> .queue_redraw()
	var refresh_regex = RegEx.new()
	refresh_regex.compile("\\.Refresh\\b")
	result = refresh_regex.sub(result, ".queue_redraw()", true)
	
	# .AddItem -> .add_item()
	var additem_regex = RegEx.new()
	additem_regex.compile("\\.AddItem\\b")
	result = additem_regex.sub(result, ".add_item", true)
	
	# .RemoveItem -> .remove_item()
	var removeitem_regex = RegEx.new()
	removeitem_regex.compile("\\.RemoveItem\\b")
	result = removeitem_regex.sub(result, ".remove_item", true)
	
	# .Clear -> .clear()
	var clear_regex = RegEx.new()
	clear_regex.compile("\\.Clear\\b")
	result = clear_regex.sub(result, ".clear()", true)
	
	# .ZOrder -> .z_index (approximate — VB6 ZOrder 0=front, 1=back)
	var zorder_regex = RegEx.new()
	zorder_regex.compile("\\.ZOrder\\b")
	result = zorder_regex.sub(result, ".z_index", true)
	
	# .SelText -> .get_selected_text()  (read context)
	var seltext_assign = RegEx.new()
	seltext_assign.compile("(\\w+)\\.SelText\\s*=")
	if seltext_assign.search(result):
		result = seltext_assign.sub(result, "$1.insert_text_at_caret(")
		result += ")"  # close the paren
	else:
		var seltext_regex = RegEx.new()
		seltext_regex.compile("\\.SelText\\b")
		result = seltext_regex.sub(result, ".get_selected_text()", true)
	
	# .SelStart -> .caret_column
	var selstart_regex = RegEx.new()
	selstart_regex.compile("\\.SelStart\\b")
	result = selstart_regex.sub(result, ".caret_column", true)
	
	# .SelLength -> selection length (approximate)
	var sellength_regex = RegEx.new()
	sellength_regex.compile("\\.SelLength\\b")
	result = sellength_regex.sub(result, ".get_selection_to_column() - .get_selection_from_column()  ' VB6: SelLength", true)
	
	# .ListIndex -> .get_selected_items()[0] (for ListBox/ComboBox)
	var listindex_regex = RegEx.new()
	listindex_regex.compile("\\.ListIndex\\b")
	result = listindex_regex.sub(result, ".get_selected_items()[0]", true)
	
	# .Text -> .text (case sensitivity — most VB6 controls have .Text)
	var text_prop_regex = RegEx.new()
	text_prop_regex.compile("\\.Text\\b")
	result = text_prop_regex.sub(result, ".text", true)
	
	# =========================================================================
	# VB6 FORM/CONTROL MANAGEMENT
	# =========================================================================
	
	# Load FormName -> FormName.show() (approximate)
	var load_regex = RegEx.new()
	load_regex.compile("^(\\s*)Load\\s+(\\w+)\\s*$")
	var load_match = load_regex.search(result)
	if load_match:
		var indent = load_match.get_string(1)
		var form_name = load_match.get_string(2)
		result = indent + form_name + ".show()  ' VB6: Load " + form_name
	
	# Unload FormName -> FormName.hide() (approximate)
	var unload_regex = RegEx.new()
	unload_regex.compile("^(\\s*)Unload\\s+(\\w+)\\s*$")
	var unload_match = unload_regex.search(result)
	if unload_match:
		var indent = unload_match.get_string(1)
		var form_name = unload_match.get_string(2)
		result = indent + form_name + ".hide()  ' VB6: Unload " + form_name
	
	# .Show -> .show()
	var show_regex = RegEx.new()
	show_regex.compile("\\.Show\\b")
	result = show_regex.sub(result, ".show()", true)
	
	# .Hide -> .hide()
	var hide_regex = RegEx.new()
	hide_regex.compile("\\.Hide\\b")
	result = hide_regex.sub(result, ".hide()", true)
	
	# .Move left, top, width, height -> position/size assignment (comment)
	var move_regex = RegEx.new()
	move_regex.compile("(\\w+)\\.Move\\s+(.+)")
	var move_match = move_regex.search(result)
	if move_match:
		var ctrl = move_match.get_string(1)
		var args = move_match.get_string(2)
		result = result + "  ' TODO: " + ctrl + ".position = Vector2(left, top) ; " + ctrl + ".size = Vector2(width, height)"

	# .ListCount -> .get_item_count(), .ListIndex -> .get_selected_items()[0]
	var listcount_regex = RegEx.new()
	listcount_regex.compile("\\.ListCount\\b")
	result = listcount_regex.sub(result, ".get_item_count()", true)
	
	# .Count -> .get_child_count() (for collections)
	# Leave as-is — too ambiguous without context
	
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
	
	# DoEvents -> OS.delay_usec(0) (yield to OS)
	if trim == "DoEvents":
		result = result.replace("DoEvents", "' DoEvents  ' TODO: Godot handles this via coroutines / await")
	
	# Implements keyword (interface declaration) - comment out, VG doesn't have Implements
	if trim.begins_with("Implements "):
		result = result.replace(trim, "' [VB6] " + trim + "  ' TODO: Use Class inheritance instead")
	
	# DefType statements (DefInt, DefLng, DefStr, etc.) - legacy, comment out
	var deftype_regex = RegEx.new()
	deftype_regex.compile("^\\s*Def(Int|Lng|Sng|Dbl|Cur|Str|Bool|Byte|Date|Obj|Var)\\s+")
	if deftype_regex.search(result):
		result = result.replace(trim, "' [VB6] " + trim + "  ' Default type declarations not needed")
	
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

static func _split_multi_statement(line: String) -> Array:
	"""Split a VB6 multi-statement line on ':' separators, respecting strings."""
	var stmts: Array = []
	var current = ""
	var in_string = false
	for i in line.length():
		var c = line[i]
		if c == '"':
			in_string = not in_string
			current += c
		elif c == ':' and not in_string:
			var trimmed = current.strip_edges()
			if trimmed != "":
				stmts.append(trimmed)
			current = ""
		else:
			current += c
	var trimmed = current.strip_edges()
	if trimmed != "":
		stmts.append(trimmed)
	return stmts

static func _expand_multi_var_dim(line: String) -> Array:
	"""Expand VB6 multi-variable Dim statements into separate lines.
	
	In VB6, 'Dim A, B, C As Integer' means A=Variant, B=Variant, C=Integer.
	Only the LAST variable gets the type. This expands each to its own Dim line
	so VisualGasic correctly assigns types.
	
	Examples:
	  'Dim Number, Operator As Integer' →
	    'Dim Number'
	    'Dim Operator As Integer'
	  'Dim a As String, b As Integer, c' →
	    'Dim a As String'
	    'Dim b As Integer'
	    'Dim c'
	"""
	var trim = line.strip_edges()
	
	# Only process Dim/Private/Public/Static variable declarations
	var keyword = ""
	for kw in ["Dim ", "Private ", "Public ", "Static "]:
		if trim.begins_with(kw):
			keyword = kw
			break
	if keyword == "":
		return [line]
	
	# Skip if this is a Sub/Function/Property declaration
	var after_kw = trim.substr(keyword.length()).strip_edges()
	for skip_kw in ["Sub ", "Function ", "Property ", "Declare ", "Event ", "Enum ", "Type ", "Const "]:
		if after_kw.begins_with(skip_kw):
			return [line]
	
	# If no comma, nothing to expand
	if "," not in after_kw:
		return [line]
	
	# Get leading whitespace from original line
	var indent = line.substr(0, line.length() - line.lstrip(" \t").length())
	
	# Split on commas, respecting parentheses (for array dims like Dim arr(10), b As Integer)
	var parts: Array = []
	var current = ""
	var paren_depth = 0
	for i in after_kw.length():
		var c = after_kw[i]
		if c == '(':
			paren_depth += 1
			current += c
		elif c == ')':
			paren_depth -= 1
			current += c
		elif c == ',' and paren_depth == 0:
			parts.append(current.strip_edges())
			current = ""
		else:
			current += c
	if current.strip_edges() != "":
		parts.append(current.strip_edges())
	
	# If only 1 part, no expansion needed
	if parts.size() <= 1:
		return [line]
	
	# Check if this is the simple VB6 pattern: "A, B, C As Type"
	# where only the last part has "As Type" and the others are bare names
	# vs. the explicit pattern: "A As String, B As Integer"
	var result: Array = []
	for part in parts:
		result.append(indent + keyword + part)
	
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
# AUTO SIGNAL WIRING (baked into .tscn)
# =============================================================================

static func _auto_wire_signals_to_tscn(scene_path: String, root: Node, raw_code: String):
	"""Scan VB6 event handlers in code and append [connection] entries to .tscn file."""
	# Parse out all Sub declarations to find event handlers
	# Pattern: Private Sub ControlName_EventName(...)
	var handler_regex = RegEx.new()
	handler_regex.compile("(?:Private |Public )?Sub (\\w+)_(\\w+)\\s*\\(")
	var handlers = handler_regex.search_all(raw_code)
	if handlers.size() == 0:
		return
	
	# Build a lookup: node_name -> Godot node class
	var node_map: Dictionary = {}  # node_name -> godot_class
	_build_node_map(root, node_map)
	
	# Form-level event mapping (Form_Load → ready, etc.)
	var form_event_map: Dictionary = {
		"Load": "ready",
		"Unload": "tree_exiting",
		"QueryUnload": "tree_exiting",
		"Resize": "resized",
		"Activate": "visibility_changed",
		"Deactivate": "visibility_changed",
		"GotFocus": "focus_entered",
		"LostFocus": "focus_exited",
	}
	
	# Build menu name set (menu items stored in PopupMenu, not as child nodes)
	var menu_names: Dictionary = {}  # menu_name -> true
	_collect_menu_names(root, menu_names)
	
	# Collect connection lines
	var connections: Array = []
	for m in handlers:
		var ctrl_name = m.get_string(1)
		var vb_event = m.get_string(2)
		var handler_name = ctrl_name + "_" + vb_event
		
		# Handle Form-level events (Form_Load, Form_Resize, etc.)
		if ctrl_name == "Form":
			if form_event_map.has(vb_event):
				var godot_signal = form_event_map[vb_event]
				var conn_line = '[connection signal="%s" from="." to="." method="%s"]' % [godot_signal, handler_name]
				if conn_line not in connections:
					connections.append(conn_line)
			continue
		
		# Handle menu item events (mnuXxx_Click → MenuBar dispatch)
		if menu_names.has(ctrl_name) and vb_event == "Click":
			# Menu items are wired via MenuBar's PopupMenu children
			# Connect MenuBar's popup id_pressed if not already done
			if node_map.has("MenuBar"):
				# Add a metadata annotation so the runtime can dispatch
				var conn_line = '[connection signal="pressed" from="MenuBar" to="." method="%s"]' % [handler_name]
				# Note: actual menu dispatch is handled by metadata; skip invalid connection
				pass
			continue
		
		# Find the node's Godot class
		var godot_class = ""
		var node_path = ""
		
		# Check for control array nodes (e.g. Num -> Num_0, Num_1, ...)
		var is_array = false
		for nname in node_map:
			if nname == ctrl_name:
				godot_class = node_map[nname]
				node_path = ctrl_name
				break
			elif nname.begins_with(ctrl_name + "_") and nname.substr(ctrl_name.length() + 1).is_valid_int():
				godot_class = node_map[nname]
				is_array = true
		
		if godot_class == "" and not is_array:
			continue
		
		# Look up the Godot signal for this VB6 event
		var godot_signal = _lookup_signal(godot_class, vb_event)
		if godot_signal == "":
			continue
		
		if is_array:
			# Wire all array elements to the same handler, binding the Index
			for nname in node_map:
				if nname.begins_with(ctrl_name + "_") and nname.substr(ctrl_name.length() + 1).is_valid_int():
					var idx_str = nname.substr(ctrl_name.length() + 1)
					var conn_line = '[connection signal="%s" from="%s" to="." method="%s" binds=[%s]]' % [godot_signal, nname, handler_name, idx_str]
					if conn_line not in connections:
						connections.append(conn_line)
		else:
			var conn_line = '[connection signal="%s" from="%s" to="." method="%s"]' % [godot_signal, node_path, handler_name]
			if conn_line not in connections:
				connections.append(conn_line)
	
	if connections.size() == 0:
		return
	
	# Append connections to the .tscn file
	var tscn_path = ProjectSettings.globalize_path(scene_path)
	var file = FileAccess.open(scene_path, FileAccess.READ)
	if not file:
		return
	var content = file.get_as_text()
	file.close()
	
	# Append connection lines
	content += "\n" + "\n".join(connections) + "\n"
	
	var out = FileAccess.open(scene_path, FileAccess.WRITE)
	if out:
		out.store_string(content)
		out.close()

static func _build_node_map(node: Node, map: Dictionary, path_prefix: String = ""):
	"""Build a map of node_name -> Godot class for all children."""
	for child in node.get_children():
		map[child.name] = child.get_class()
		# Recurse for nested containers
		if child.get_child_count() > 0:
			_build_node_map(child, map, str(child.name) + "/")

static func _collect_menu_names(root: Node, menu_names: Dictionary):
	"""Collect all VB6 menu item names stored in metadata across the scene tree."""
	for child in root.get_children():
		if child.has_meta("vb6_class") and str(child.get_meta("vb6_class")) == "VB.Menu":
			menu_names[child.name] = true
		# Check PopupMenu items: menu names stored as metadata on MenuBar's PopupMenu children
		if child is MenuBar:
			for i in child.get_menu_count():
				var popup = child.get_menu_popup(i)
				if popup:
					for j in popup.item_count:
						var item_name = popup.get_item_metadata(j)
						if item_name is String and item_name != "":
							menu_names[item_name] = true
		# Also scan metadata/vb6_menu_items stored during form parsing
		if child.has_meta("vb6_menu_items"):
			var items = child.get_meta("vb6_menu_items")
			if items is Array:
				for item in items:
					if item is Dictionary and item.has("name"):
						menu_names[item.name] = true
						# Also recurse into children
						_collect_menu_items_recursive(item, menu_names)
		# Recurse
		if child.get_child_count() > 0:
			_collect_menu_names(child, menu_names)

static func _collect_menu_items_recursive(item: Dictionary, menu_names: Dictionary):
	"""Recursively collect menu item names from nested menu tree structures."""
	if item.has("children"):
		for child_item in item.children:
			if child_item is Dictionary and child_item.has("name"):
				menu_names[child_item.name] = true
				_collect_menu_items_recursive(child_item, menu_names)

static func _lookup_signal(godot_class: String, vb_event: String) -> String:
	"""Find the Godot signal name for a VB6 event on a given node class."""
	# Check direct class match
	if EVENT_MAP.has(godot_class):
		var events = EVENT_MAP[godot_class]
		if events.has(vb_event):
			return events[vb_event]
	
	# Check parent classes (Button -> Control, etc.)
	var class_hierarchy = {
		"Button": ["Button"],
		"LinkButton": ["Button"],
		"CheckBox": ["CheckBox", "Button"],
		"LineEdit": ["LineEdit"],
		"TextEdit": ["TextEdit"],
		"OptionButton": ["OptionButton"],
		"ItemList": ["ItemList"],
		"Tree": ["Tree"],
		"Timer": ["Timer"],
		"HScrollBar": ["HScrollBar", "Range"],
		"VScrollBar": ["VScrollBar", "Range"],
		"HSlider": ["HSlider", "Range"],
		"VSlider": ["VSlider", "Range"],
		"ProgressBar": ["ProgressBar", "Range"],
		"SpinBox": ["SpinBox", "Range"],
		"TabContainer": ["TabContainer"],
		"MenuBar": ["MenuBar"],
		"Label": ["Label"],
		"RichTextLabel": ["RichTextLabel"],
		"ColorRect": ["ColorRect"],
		"Panel": ["Panel"],
		"TextureRect": ["TextureRect"],
	}
	
	# Try hierarchy lookup
	if class_hierarchy.has(godot_class):
		for parent_class in class_hierarchy[godot_class]:
			if EVENT_MAP.has(parent_class):
				if EVENT_MAP[parent_class].has(vb_event):
					return EVENT_MAP[parent_class][vb_event]
	
	# Fallback: try the event name directly for common events
	var common_events = {
		"Click": "pressed",
		"Change": "text_changed",
		"DblClick": "item_activated",
		"GotFocus": "focus_entered",
		"LostFocus": "focus_exited",
		"MouseDown": "button_down",
		"MouseUp": "button_up",
	}
	return common_events.get(vb_event, "")

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
						# GIF (starts with "GIF")
						elif img_data.size() >= 3 and img_data[0] == 0x47 and img_data[1] == 0x49 and img_data[2] == 0x46:
							# Save GIF to disk and load as texture (Godot can't load GIF from buffer directly)
							var gif_path = "res://resources/" + node.name + "_frx.gif"
							_ensure_dir("res://resources")
							var gif_file = FileAccess.open(gif_path, FileAccess.WRITE)
							if gif_file:
								gif_file.store_buffer(img_data)
								gif_file.close()
								result.warnings.append("Saved GIF to %s (manual import may be needed)" % gif_path)
							continue
						# ICO (starts with 00 00 01 00)
						elif img_data.size() >= 4 and img_data[0] == 0x00 and img_data[1] == 0x00 and img_data[2] == 0x01 and img_data[3] == 0x00:
							# Save ICO to disk (used for form icons)
							var ico_path = "res://resources/" + node.name + "_icon.ico"
							_ensure_dir("res://resources")
							var ico_file = FileAccess.open(ico_path, FileAccess.WRITE)
							if ico_file:
								ico_file.store_buffer(img_data)
								ico_file.close()
								result.warnings.append("Saved ICO to %s (convert to .png for Godot)" % ico_path)
							continue
						
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
