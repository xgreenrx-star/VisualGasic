@tool
extends VBoxContainer
## VB6-Style Project Explorer for Visual Gasic
##
## Displays project files in a tree view matching the VB6 IDE layout:
## - Project name at root
## - Forms (.vg scripts with VB6 form structure)
## - Components (.vg scripts attached to visual scenes)
## - Modules (.vg code-only scripts)
## - Resources (other project assets)
##
## Toolbar: View Code | View Object | Toggle Folders | Refresh

# =============================================================================
# CONSTANTS
# =============================================================================

const FOLDER_FORMS := "Forms"
const FOLDER_COMPONENTS := "Components"
const FOLDER_MODULES := "Modules"
const FOLDER_CLASSES := "Class Modules"
const FOLDER_RESOURCES := "Resources"

# =============================================================================
# MEMBER VARIABLES
# =============================================================================

var editor_plugin: EditorPlugin
var tree: Tree
var _toolbar: HBoxContainer
var _btn_view_code: Button
var _btn_view_object: Button
var _btn_toggle_folders: Button
var _btn_refresh: Button
var _show_folders: bool = true
var _project_name: String = "Project1"
var _context_menu: PopupMenu
var _confirm_delete_dialog: ConfirmationDialog

# =============================================================================
# INITIALIZATION
# =============================================================================

func _init():
	name = "Project"
	size_flags_vertical = SIZE_EXPAND_FILL
	size_flags_horizontal = SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(100, 80)

	# --- Toolbar (VB6-style: dark text on warm off-white) ---
	_toolbar = HBoxContainer.new()
	_toolbar.custom_minimum_size.y = 26
	var tb_sb = StyleBoxFlat.new()
	tb_sb.bg_color = Color("#E8E5E0")  # slightly darker than panel bg
	tb_sb.content_margin_left = 4
	tb_sb.content_margin_right = 4
	tb_sb.content_margin_top = 1
	tb_sb.content_margin_bottom = 1
	_toolbar.add_theme_stylebox_override("panel", tb_sb)

	_btn_view_code = Button.new()
	_btn_view_code.text = "Code"
	_btn_view_code.tooltip_text = "View Code"
	_btn_view_code.flat = true
	_btn_view_code.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	_btn_view_code.add_theme_color_override("font_hover_color", Color(0.0, 0.0, 0.5))
	_btn_view_code.pressed.connect(_on_view_code)
	_toolbar.add_child(_btn_view_code)

	_btn_view_object = Button.new()
	_btn_view_object.text = "Design"
	_btn_view_object.tooltip_text = "View Object (Visual Gasic IDE)"
	_btn_view_object.flat = true
	_btn_view_object.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	_btn_view_object.add_theme_color_override("font_hover_color", Color(0.0, 0.0, 0.5))
	_btn_view_object.pressed.connect(_on_view_object)
	_toolbar.add_child(_btn_view_object)

	_toolbar.add_child(VSeparator.new())

	_btn_toggle_folders = Button.new()
	_btn_toggle_folders.text = "Folders"
	_btn_toggle_folders.tooltip_text = "Toggle Folders"
	_btn_toggle_folders.flat = true
	_btn_toggle_folders.toggle_mode = true
	_btn_toggle_folders.button_pressed = true
	_btn_toggle_folders.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	_btn_toggle_folders.add_theme_color_override("font_hover_color", Color(0.0, 0.0, 0.5))
	_btn_toggle_folders.toggled.connect(_on_toggle_folders)
	_toolbar.add_child(_btn_toggle_folders)

	_btn_refresh = Button.new()
	_btn_refresh.text = "↻"
	_btn_refresh.tooltip_text = "Refresh"
	_btn_refresh.flat = true
	_btn_refresh.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	_btn_refresh.pressed.connect(refresh)
	_toolbar.add_child(_btn_refresh)

	add_child(_toolbar)

	# --- Tree View (dark text on off-white background) ---
	tree = Tree.new()
	tree.size_flags_vertical = SIZE_EXPAND_FILL
	tree.size_flags_horizontal = SIZE_EXPAND_FILL
	tree.hide_root = false
	tree.allow_reselect = true
	tree.item_activated.connect(_on_item_activated)
	tree.item_selected.connect(_on_item_selected)
	# Dark text + warm off-white background for the tree
	var tree_sb = StyleBoxFlat.new()
	tree_sb.bg_color = Color("#F0EDE8")
	tree_sb.content_margin_left = 4
	tree_sb.content_margin_right = 4
	tree_sb.content_margin_top = 2
	tree_sb.content_margin_bottom = 2
	tree.add_theme_stylebox_override("panel", tree_sb)
	tree.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	tree.add_theme_color_override("font_selected_color", Color(1, 1, 1))
	tree.add_theme_color_override("title_button_color", Color(0.1, 0.1, 0.1))
	# VB6-style tree connector lines (dotted gray lines between parent/child)
	tree.add_theme_color_override("relationship_line_color", Color(0.5, 0.5, 0.5, 0.8))
	tree.add_theme_color_override("parent_hl_line_color", Color(0.5, 0.5, 0.5, 0.8))
	tree.add_theme_color_override("children_hl_line_color", Color(0.5, 0.5, 0.5, 0.8))
	tree.add_theme_constant_override("draw_relationship_lines", 1)
	tree.add_theme_constant_override("relationship_line_width", 1)
	tree.add_theme_constant_override("parent_hl_line_width", 1)
	tree.add_theme_constant_override("children_hl_line_width", 1)
	# Selected item highlight: blue selection bar
	var sel_sb = StyleBoxFlat.new()
	sel_sb.bg_color = Color(0.26, 0.59, 0.98, 1.0)
	tree.add_theme_stylebox_override("selected", sel_sb)
	tree.add_theme_stylebox_override("selected_focus", sel_sb)
	add_child(tree)

	# --- Right-click context menu ---
	_context_menu = PopupMenu.new()
	_context_menu.add_item("Add Form...", 0)
	_context_menu.add_item("Add Module...", 1)
	_context_menu.add_separator()
	_context_menu.add_item("Delete", 3)
	_context_menu.add_separator()
	_context_menu.add_item("Refresh", 2)
	_context_menu.id_pressed.connect(_on_context_menu_selected)
	# Style popup for readability on the light-themed IDE
	var ctx_panel = StyleBoxFlat.new()
	ctx_panel.bg_color = Color(0.96, 0.95, 0.93)
	ctx_panel.border_width_top = 1
	ctx_panel.border_width_bottom = 1
	ctx_panel.border_width_left = 1
	ctx_panel.border_width_right = 1
	ctx_panel.border_color = Color(0.55, 0.54, 0.52)
	ctx_panel.content_margin_left = 4
	ctx_panel.content_margin_right = 4
	ctx_panel.content_margin_top = 4
	ctx_panel.content_margin_bottom = 4
	_context_menu.add_theme_stylebox_override("panel", ctx_panel)
	_context_menu.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	_context_menu.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	_context_menu.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.55))
	_context_menu.add_theme_color_override("font_separator_color", Color(0.4, 0.4, 0.4))
	var ctx_hover = StyleBoxFlat.new()
	ctx_hover.bg_color = Color(0.0, 0.47, 0.84)
	ctx_hover.corner_radius_top_left = 2
	ctx_hover.corner_radius_top_right = 2
	ctx_hover.corner_radius_bottom_left = 2
	ctx_hover.corner_radius_bottom_right = 2
	_context_menu.add_theme_stylebox_override("hover", ctx_hover)
	add_child(_context_menu)
	tree.gui_input.connect(_on_tree_gui_input)

	# --- Delete confirmation dialog ---
	_confirm_delete_dialog = ConfirmationDialog.new()
	_confirm_delete_dialog.title = "DELETE"
	_confirm_delete_dialog.ok_button_text = "Delete"
	_confirm_delete_dialog.min_size = Vector2i(380, 0)
	_confirm_delete_dialog.confirmed.connect(_on_delete_confirmed)
	# VB6/Win95 light styling so text is readable on dark editor themes
	var dlg_panel = StyleBoxFlat.new()
	dlg_panel.bg_color = Color("#F0F0F0")
	dlg_panel.border_color = Color("#808080")
	dlg_panel.border_width_top = 2
	dlg_panel.border_width_bottom = 2
	dlg_panel.border_width_left = 2
	dlg_panel.border_width_right = 2
	dlg_panel.content_margin_left = 16
	dlg_panel.content_margin_right = 16
	dlg_panel.content_margin_top = 12
	dlg_panel.content_margin_bottom = 12
	_confirm_delete_dialog.add_theme_stylebox_override("panel", dlg_panel)
	# Dark text on light background
	_confirm_delete_dialog.add_theme_color_override("font_color", Color("#1A1A1A"))
	# Style the OK (Delete) and Cancel buttons
	for btn_name in ["ok_button", "cancel_button"]:
		var btn: Button
		if btn_name == "ok_button":
			btn = _confirm_delete_dialog.get_ok_button()
		else:
			btn = _confirm_delete_dialog.get_cancel_button()
		if btn:
			var btn_normal = StyleBoxFlat.new()
			btn_normal.bg_color = Color("#D4D0C8")
			btn_normal.border_color = Color("#808080")
			btn_normal.border_width_top = 1
			btn_normal.border_width_bottom = 2
			btn_normal.border_width_left = 1
			btn_normal.border_width_right = 2
			btn_normal.content_margin_left = 16
			btn_normal.content_margin_right = 16
			btn_normal.content_margin_top = 4
			btn_normal.content_margin_bottom = 4
			btn.add_theme_stylebox_override("normal", btn_normal)
			var btn_hover = btn_normal.duplicate()
			btn_hover.bg_color = Color("#E0DCD4")
			btn.add_theme_stylebox_override("hover", btn_hover)
			var btn_pressed = btn_normal.duplicate()
			btn_pressed.bg_color = Color("#C0BCB4")
			btn.add_theme_stylebox_override("pressed", btn_pressed)
			btn.add_theme_color_override("font_color", Color("#1A1A1A"))
			btn.add_theme_color_override("font_hover_color", Color("#000000"))
			btn.add_theme_color_override("font_pressed_color", Color("#000000"))
	add_child(_confirm_delete_dialog)

## Setup with the editor plugin reference.
func setup(plugin: EditorPlugin):
	editor_plugin = plugin
	# Read project name from ProjectSettings
	var pname = ProjectSettings.get_setting("application/config/name", "")
	if pname != "":
		_project_name = pname
	# Initial population
	call_deferred("refresh")

# =============================================================================
# TREE POPULATION
# =============================================================================

## Refresh the entire project tree by scanning the filesystem.
func refresh():
	if not is_instance_valid(tree):
		return
	tree.clear()

	var root = tree.create_item()
	root.set_text(0, _project_name)
	root.set_tooltip_text(0, "Project: " + _project_name)
	root.set_selectable(0, true)

	# Scan for .vg and .tscn files
	var forms: Array[Dictionary] = []
	var components: Array[Dictionary] = []
	var modules: Array[Dictionary] = []
	var resources: Array[Dictionary] = []

	_scan_directory("res://", forms, components, modules, resources)

	if _show_folders:
		_populate_with_folders(root, forms, components, modules, resources)
	else:
		_populate_flat(root, forms, components, modules, resources)

	root.set_collapsed(false)

## Recursively scan a directory for project files.
func _scan_directory(path: String, forms: Array[Dictionary], components: Array[Dictionary], modules: Array[Dictionary], resources: Array[Dictionary]):
	var dir = DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = path.path_join(file_name)
		if dir.current_is_dir():
			# Skip hidden dirs, addons, .godot
			if not file_name.begins_with(".") and file_name != "addons" and file_name != ".godot":
				_scan_directory(full_path, forms, components, modules, resources)
		else:
			if file_name.ends_with(".vg"):
				# Skip stray files with empty basename (e.g. literally ".vg")
				var base_name := file_name.get_basename()
				if base_name.is_empty():
					continue
				# Three-way classification:
				#   Form      = has VB6 form content (Form_Load, Begin VB.Form, etc.)
				#   Component = has a visual scene (.tscn) but no form markers
				#   Module    = standalone code with no visual counterpart
				var has_form = _has_form_content(full_path)
				var has_scene = FileAccess.file_exists(full_path.get_basename() + ".tscn")
				if has_form:
					forms.append({"name": base_name, "path": full_path})
				elif has_scene:
					components.append({"name": base_name, "path": full_path})
				else:
					modules.append({"name": base_name, "path": full_path})
			elif file_name.ends_with(".tscn") or file_name.ends_with(".scn"):
				# Only add scenes that do NOT have a paired .vg file —
				# those are already shown under Forms or Components.
				var vg_sibling := full_path.get_basename() + ".vg"
				if not FileAccess.file_exists(vg_sibling):
					resources.append({"name": file_name.get_basename(), "path": full_path, "type": "scene"})
			elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
				resources.append({"name": file_name.get_basename(), "path": full_path, "type": "resource"})
		file_name = dir.get_next()
	dir.list_dir_end()

## Check if a .vg script has VB6 form content (content-based only, not scene existence).
func _has_form_content(path: String) -> bool:
	var f = FileAccess.open(path, FileAccess.READ)
	if f:
		var content = f.get_as_text()
		f.close()
		# Heuristic: forms have "Sub Form_Load" or form-level event handlers
		if content.find("Sub Form_Load") != -1 or content.find("Sub Form_") != -1:
			return true
		# Check for VB6 form header
		if content.begins_with("VERSION ") or content.find("Begin VB.Form") != -1:
			return true
	return false

## Populate tree with folder grouping (like VB6).
func _populate_with_folders(root: TreeItem, forms: Array[Dictionary], components: Array[Dictionary], modules: Array[Dictionary], resources: Array[Dictionary]):
	# Forms folder — VB6-style forms with Form_Load, event handlers, etc.
	if forms.size() > 0:
		var folder = tree.create_item(root)
		folder.set_text(0, FOLDER_FORMS + " (" + str(forms.size()) + ")")
		folder.set_tooltip_text(0, "Form files (.vg with VB6 form structure)")
		folder.set_selectable(0, true)
		folder.set_metadata(0, {"type": "folder", "folder": FOLDER_FORMS})
		for entry in forms:
			var item = tree.create_item(folder)
			item.set_text(0, entry.name)
			item.set_tooltip_text(0, entry.path)
			item.set_metadata(0, {"type": "form", "path": entry.path})

	# Components folder — .vg files paired with a visual scene (game entities, etc.)
	if components.size() > 0:
		var folder = tree.create_item(root)
		folder.set_text(0, FOLDER_COMPONENTS + " (" + str(components.size()) + ")")
		folder.set_tooltip_text(0, "Component files (.vg with visual scene)")
		folder.set_selectable(0, true)
		folder.set_metadata(0, {"type": "folder", "folder": FOLDER_COMPONENTS})
		for entry in components:
			var item = tree.create_item(folder)
			item.set_text(0, entry.name)
			item.set_tooltip_text(0, entry.path)
			item.set_metadata(0, {"type": "component", "path": entry.path})

	# Modules folder — expanded by default so standalone code files are easy to find
	if modules.size() > 0:
		var folder = tree.create_item(root)
		folder.set_text(0, FOLDER_MODULES + " (" + str(modules.size()) + ")")
		folder.set_tooltip_text(0, "Module files (.vg code-only) — double-click to edit")
		folder.set_selectable(0, true)
		folder.set_metadata(0, {"type": "folder", "folder": FOLDER_MODULES})
		folder.set_collapsed(false)  # Always show modules
		for entry in modules:
			var item = tree.create_item(folder)
			item.set_text(0, entry.name)
			item.set_tooltip_text(0, entry.path + "  (double-click to edit)")
			item.set_metadata(0, {"type": "module", "path": entry.path})

	# Resources folder — expanded by default like VB6 so items are visible
	if resources.size() > 0:
		var folder = tree.create_item(root)
		folder.set_text(0, FOLDER_RESOURCES + " (" + str(resources.size()) + ")")
		folder.set_tooltip_text(0, "Scene and resource files")
		folder.set_selectable(0, true)
		folder.set_metadata(0, {"type": "folder", "folder": FOLDER_RESOURCES})
		folder.set_collapsed(false)  # Expanded like VB6 Project Explorer
		for entry in resources:
			var item = tree.create_item(folder)
			item.set_text(0, entry.name)
			item.set_tooltip_text(0, entry.path)
			item.set_metadata(0, {"type": entry.get("type", "resource"), "path": entry.path})

## Populate tree flat (no folders) — alphabetical list.
func _populate_flat(root: TreeItem, forms: Array[Dictionary], components: Array[Dictionary], modules: Array[Dictionary], resources: Array[Dictionary]):
	var all_items: Array[Dictionary] = []
	for entry in forms:
		entry["type"] = "form"
		all_items.append(entry)
	for entry in components:
		entry["type"] = "component"
		all_items.append(entry)
	for entry in modules:
		entry["type"] = "module"
		all_items.append(entry)
	for entry in resources:
		all_items.append(entry)

	all_items.sort_custom(func(a, b): return a.name.to_lower() < b.name.to_lower())

	for entry in all_items:
		var item = tree.create_item(root)
		var suffix = ""
		match entry.get("type", ""):
			"form": suffix = " (Form)"
			"component": suffix = " (Component)"
			"module": suffix = " (Module)"
			"scene": suffix = " (Scene)"
			"resource": suffix = " (Resource)"
		item.set_text(0, entry.name + suffix)
		item.set_tooltip_text(0, entry.path)
		item.set_metadata(0, {"type": entry.get("type", ""), "path": entry.path})

# =============================================================================
# USER ACTIONS
# =============================================================================

## Double-click: open the file (code for .vg, scene for .tscn).
func _on_item_activated():
	var item = tree.get_selected()
	if not item:
		return
	var meta = item.get_metadata(0)
	if not meta or not meta is Dictionary:
		return

	var file_type = meta.get("type", "")
	var file_path = meta.get("path", "")
	if file_path == "":
		return

	match file_type:
		"form":
			# Double-clicking a form opens it in the Form Designer (like VB6).
			var scene_path = file_path.get_basename() + ".tscn"
			if FileAccess.file_exists(scene_path) and editor_plugin.has_method("open_form_in_designer"):
				editor_plugin.open_form_in_designer(scene_path)
			elif editor_plugin.has_method("open_module_in_embedded_editor"):
				editor_plugin.open_module_in_embedded_editor(file_path)
			else:
				_open_script(file_path)
		"component":
			# Double-clicking a component opens its scene in the 3D/2D editor.
			var scene_path = file_path.get_basename() + ".tscn"
			if FileAccess.file_exists(scene_path):
				_open_scene_in_editor(scene_path)
			elif editor_plugin.has_method("open_module_in_embedded_editor"):
				editor_plugin.open_module_in_embedded_editor(file_path)
			else:
				_open_script(file_path)
		"module":
			# Open standalone modules in the embedded VB6 code editor
			if editor_plugin.has_method("open_module_in_embedded_editor"):
				editor_plugin.open_module_in_embedded_editor(file_path)
			else:
				_open_script(file_path)
		"scene":
			_open_scene_in_editor(file_path)
		"resource":
			# Open in inspector
			var res = load(file_path)
			if res:
				editor_plugin.get_editor_interface().edit_resource(res)
		_:
			pass

## View Code button — open selected item's .vg script in the embedded code editor.
## If nothing is selected, opens the first available module.
func _on_view_code():
	var item = tree.get_selected()
	var file_path := ""
	if item:
		var meta = item.get_metadata(0)
		if meta is Dictionary:
			file_path = meta.get("path", "")

	# If nothing selected or selected item has no path, find the first .vg module
	if file_path.is_empty():
		var first_vg := _find_first_module_path()
		if not first_vg.is_empty():
			file_path = first_vg
		else:
			return

	if file_path.ends_with(".vg"):
		# Route through embedded editor
		if editor_plugin.has_method("open_module_in_embedded_editor"):
			editor_plugin.open_module_in_embedded_editor(file_path)
		else:
			_open_script(file_path)
	else:
		# For scenes, find attached .vg script
		var vg_path = file_path.get_basename() + ".vg"
		if FileAccess.file_exists(vg_path):
			if editor_plugin.has_method("open_module_in_embedded_editor"):
				editor_plugin.open_module_in_embedded_editor(vg_path)
			else:
				_open_script(vg_path)

## View Object button — open selected item's scene in the appropriate editor.
## For forms, opens in Form Designer. For components/scenes, opens in 2D/3D editor.
func _on_view_object():
	var item = tree.get_selected()
	if not item:
		return
	var meta = item.get_metadata(0)
	if not meta or not meta is Dictionary:
		return

	var file_type = meta.get("type", "")
	var file_path = meta.get("path", "")
	if file_path == "":
		return

	# Try to find the scene
	var scene_path = file_path
	if file_path.ends_with(".vg"):
		scene_path = file_path.get_basename() + ".tscn"

	if not FileAccess.file_exists(scene_path) or not (scene_path.ends_with(".tscn") or scene_path.ends_with(".scn")):
		return

	# Forms open in the Form Designer, components/scenes in the 3D/2D editor
	if file_type == "form":
		if editor_plugin.has_method("open_form_in_designer"):
			editor_plugin.open_form_in_designer(scene_path)
		else:
			editor_plugin.get_editor_interface().open_scene_from_path(scene_path)
	else:
		# Open in the 3D or 2D scene editor
		_open_scene_in_editor(scene_path)

## Toggle folder grouping on/off.
func _on_toggle_folders(toggled: bool):
	_show_folders = toggled
	refresh()

## Called when a tree item is selected (single click).
func _on_item_selected():
	var item = tree.get_selected()
	if not item:
		return
	var meta = item.get_metadata(0)
	if not meta or not meta is Dictionary:
		return
	# Could preview the file in inspector, etc.
	pass

## Right-click on tree — show VB6-style context menu.
func _on_tree_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		# Enable/disable Delete based on whether a deletable item is selected
		var can_delete := false
		var item = tree.get_selected()
		if item:
			var meta = item.get_metadata(0)
			if meta is Dictionary:
				var item_type = meta.get("type", "")
				can_delete = item_type in ["form", "component", "module", "scene", "resource"]
		# Find the Delete item index by id and set disabled state
		for i in _context_menu.item_count:
			if _context_menu.get_item_id(i) == 3:  # Delete
				_context_menu.set_item_disabled(i, not can_delete)
				break
		_context_menu.position = Vector2i(DisplayServer.mouse_get_position())
		_context_menu.popup()

## Context menu item selected.
func _on_context_menu_selected(id: int):
	match id:
		0:  # Add Form...
			if editor_plugin and editor_plugin.has_method("_on_add_form"):
				editor_plugin._on_add_form()
		1:  # Add Module...
			if editor_plugin and editor_plugin.has_method("_on_new_module"):
				editor_plugin._on_new_module()
		2:  # Refresh
			refresh()
		3:  # Delete
			_prompt_delete()

## Show a confirmation dialog before deleting the selected item.
func _prompt_delete():
	var item = tree.get_selected()
	if not item:
		return
	var meta = item.get_metadata(0)
	if not meta is Dictionary:
		return
	var item_type = meta.get("type", "")
	var file_path = meta.get("path", "")
	if file_path.is_empty() or item_type not in ["form", "component", "module", "scene", "resource"]:
		return

	var display_name = item.get_text(0)
	var details := ""
	if item_type in ["form", "component"]:
		var scene_path = file_path.get_basename() + ".tscn"
		details = "This will permanently delete:\n• %s\n• %s" % [file_path, scene_path]
	else:
		details = "This will permanently delete:\n• %s" % file_path

	_confirm_delete_dialog.dialog_text = "Delete '%s'?\n\n%s\n\nThis cannot be undone." % [display_name, details]
	_confirm_delete_dialog.popup_centered()
	# Style internal labels so text is readable on the light background
	_style_dialog_labels(_confirm_delete_dialog)

## Recursively set dark font color on all Label children inside a dialog.
func _style_dialog_labels(node: Node) -> void:
	for child in node.get_children():
		if child is Label:
			child.add_theme_color_override("font_color", Color("#1A1A1A"))
		_style_dialog_labels(child)

## Actually delete the files after user confirmation.
func _on_delete_confirmed():
	var item = tree.get_selected()
	if not item:
		return
	var meta = item.get_metadata(0)
	if not meta is Dictionary:
		return
	var item_type = meta.get("type", "")
	var file_path: String = meta.get("path", "")
	if file_path.is_empty():
		return

	# Close the scene tab in the editor if it's currently open
	var scene_path_to_close := ""
	if item_type in ["form", "component"]:
		scene_path_to_close = file_path.get_basename() + ".tscn"
	elif file_path.ends_with(".tscn"):
		scene_path_to_close = file_path
	if not scene_path_to_close.is_empty() and editor_plugin:
		_close_scene_tab(scene_path_to_close)

	# Delete the primary file
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		print("VisualGasic: Deleted %s" % file_path)

	# For forms and components, also delete the companion .tscn
	if item_type in ["form", "component"]:
		var scene_path = file_path.get_basename() + ".tscn"
		if FileAccess.file_exists(scene_path):
			DirAccess.remove_absolute(scene_path)
			print("VisualGasic: Deleted %s" % scene_path)
		# Also remove any .uid file Godot may have created
		var uid_path = file_path + ".uid"
		if FileAccess.file_exists(uid_path):
			DirAccess.remove_absolute(uid_path)
		var scene_uid = scene_path + ".uid"
		if FileAccess.file_exists(scene_uid):
			DirAccess.remove_absolute(scene_uid)

	# Refresh the file system so Godot picks up the changes
	if editor_plugin:
		editor_plugin.get_editor_interface().get_resource_filesystem().scan()

	# Refresh the tree
	call_deferred("refresh")

# =============================================================================
# HELPERS
# =============================================================================

## Close an open scene tab in the editor by its file path.
## Finds Godot's internal scene TabBar and emits tab_close_pressed.
func _close_scene_tab(scene_path: String) -> void:
	var open_scenes: PackedStringArray = EditorInterface.get_open_scenes()
	var scene_idx := -1
	for i in range(open_scenes.size()):
		if open_scenes[i] == scene_path:
			scene_idx = i
			break
	if scene_idx == -1:
		return  # Scene is not open — nothing to close

	# If this is the currently edited scene, switch to another one first
	var edited_root = EditorInterface.get_edited_scene_root()
	if edited_root and edited_root.scene_file_path == scene_path:
		if open_scenes.size() > 1:
			var other_idx := 1 if scene_idx == 0 else scene_idx - 1
			EditorInterface.open_scene_from_path(open_scenes[other_idx])
			# Switching may have shifted indices — re-scan
			open_scenes = EditorInterface.get_open_scenes()
			scene_idx = -1
			for i in range(open_scenes.size()):
				if open_scenes[i] == scene_path:
					scene_idx = i
					break
			if scene_idx == -1:
				return  # Already gone after the switch

	# Find Godot's scene TabBar (named "scene_tabs" inside EditorNode)
	var scene_tabs: TabBar = _find_named_node(EditorInterface.get_base_control(), &"scene_tabs") as TabBar
	if scene_tabs and scene_idx < scene_tabs.tab_count:
		scene_tabs.tab_close_pressed.emit(scene_idx)
		print("VisualGasic: Closed editor tab for '%s'" % scene_path)

## Recursively searches for a node by name in the editor's UI tree.
func _find_named_node(node: Node, target: StringName) -> Node:
	if node.name == target:
		return node
	for child in node.get_children():
		var result = _find_named_node(child, target)
		if result:
			return result
	return null

## Open a script in the script editor.
func _open_script(path: String):
	var script = load(path)
	if script:
		editor_plugin.get_editor_interface().edit_script(script)

## Find the first module (.vg) path in the tree.  Used by the Code button
## when nothing is selected so the user can always get to code with one click.
func _find_first_module_path() -> String:
	if not is_instance_valid(tree):
		return ""
	var root = tree.get_root()
	if not root:
		return ""
	return _search_tree_for_type(root, "module")

## Recursively search tree items for one with the given type metadata.
func _search_tree_for_type(item: TreeItem, target_type: String) -> String:
	var meta = item.get_metadata(0)
	if meta is Dictionary and meta.get("type", "") == target_type:
		return meta.get("path", "")
	var child = item.get_first_child()
	while child:
		var result = _search_tree_for_type(child, target_type)
		if not result.is_empty():
			return result
		child = child.get_next()
	return ""

## Open a .tscn scene in the appropriate embedded editor (3D or 2D).
## Checks whether the scene contains 3D or 2D content and switches to the
## matching editor tab, loading the scene automatically.
func _open_scene_in_editor(scene_path: String) -> void:
	if not FileAccess.file_exists(scene_path):
		return
	# Determine if the scene is 3D or 2D by checking the root node type in the .tscn
	var is_3d := _scene_is_3d(scene_path)
	if is_3d:
		# Load into the 3D editor
		if editor_plugin.has_method("_on_3d_view_pressed"):
			editor_plugin._on_3d_view_pressed()
		var editor_3d = editor_plugin.get("_vg_3d_editor")
		if editor_3d and editor_3d.has_method("load_scene"):
			editor_3d.load_scene(scene_path)
	else:
		# Load into the 2D editor
		if editor_plugin.has_method("_on_2d_view_pressed"):
			editor_plugin._on_2d_view_pressed()
		var editor_2d = editor_plugin.get("_vg_2d_editor")
		if editor_2d and editor_2d.has_method("load_scene"):
			editor_2d.load_scene(scene_path)

## Check if a .tscn file contains a 3D scene (Node3D root or 3D children).
func _scene_is_3d(scene_path: String) -> bool:
	var f = FileAccess.open(scene_path, FileAccess.READ)
	if not f:
		return false
	var content = f.get_as_text()
	f.close()
	# Check for Node3D-based root type or 3D node types in the scene
	if content.find("type=\"Node3D\"") != -1:
		return true
	if content.find("type=\"CSGBox3D\"") != -1:
		return true
	if content.find("type=\"CSGSphere3D\"") != -1:
		return true
	if content.find("type=\"CSGCylinder3D\"") != -1:
		return true
	if content.find("type=\"MeshInstance3D\"") != -1:
		return true
	if content.find("type=\"Camera3D\"") != -1:
		return true
	if content.find("type=\"DirectionalLight3D\"") != -1:
		return true
	if content.find("type=\"CharacterBody3D\"") != -1:
		return true
	if content.find("type=\"RigidBody3D\"") != -1:
		return true
	if content.find("type=\"StaticBody3D\"") != -1:
		return true
	return false
