@tool
extends VBoxContainer
## VB6-Style Project Explorer for Visual Gasic
##
## Displays project files in a tree view matching the VB6 IDE layout:
## - Project name at root
## - Forms (scenes with .vg scripts)
## - Modules (.vg code-only scripts)
## - Resources (other project assets)
##
## Toolbar: View Code | View Object | Toggle Folders | Refresh

# =============================================================================
# CONSTANTS
# =============================================================================

const FOLDER_FORMS := "Forms"
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

# =============================================================================
# INITIALIZATION
# =============================================================================

func _init():
	name = "Project"
	size_flags_vertical = SIZE_EXPAND_FILL
	size_flags_horizontal = SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(220, 200)  # Wide enough for project tree; resizable via dock splitter

	# --- Title Bar (VB6-style dark blue) ---
	var title = Label.new()
	title.text = "Project Explorer"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.4)  # VB6 Title Bar Blue
	title.add_theme_stylebox_override("normal", style)
	add_child(title)

	# --- Toolbar ---
	_toolbar = HBoxContainer.new()
	_toolbar.custom_minimum_size.y = 26

	_btn_view_code = Button.new()
	_btn_view_code.text = "Code"
	_btn_view_code.tooltip_text = "View Code"
	_btn_view_code.flat = true
	_btn_view_code.pressed.connect(_on_view_code)
	_toolbar.add_child(_btn_view_code)

	_btn_view_object = Button.new()
	_btn_view_object.text = "Design"
	_btn_view_object.tooltip_text = "View Object (Form Designer)"
	_btn_view_object.flat = true
	_btn_view_object.pressed.connect(_on_view_object)
	_toolbar.add_child(_btn_view_object)

	_toolbar.add_child(VSeparator.new())

	_btn_toggle_folders = Button.new()
	_btn_toggle_folders.text = "Folders"
	_btn_toggle_folders.tooltip_text = "Toggle Folders"
	_btn_toggle_folders.flat = true
	_btn_toggle_folders.toggle_mode = true
	_btn_toggle_folders.button_pressed = true
	_btn_toggle_folders.toggled.connect(_on_toggle_folders)
	_toolbar.add_child(_btn_toggle_folders)

	_btn_refresh = Button.new()
	_btn_refresh.text = "↻"
	_btn_refresh.tooltip_text = "Refresh"
	_btn_refresh.flat = true
	_btn_refresh.pressed.connect(refresh)
	_toolbar.add_child(_btn_refresh)

	add_child(_toolbar)

	# --- Tree View ---
	tree = Tree.new()
	tree.size_flags_vertical = SIZE_EXPAND_FILL
	tree.size_flags_horizontal = SIZE_EXPAND_FILL
	tree.hide_root = false
	tree.allow_reselect = true
	tree.item_activated.connect(_on_item_activated)
	tree.item_selected.connect(_on_item_selected)
	add_child(tree)

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
	var modules: Array[Dictionary] = []
	var resources: Array[Dictionary] = []

	_scan_directory("res://", forms, modules, resources)

	if _show_folders:
		_populate_with_folders(root, forms, modules, resources)
	else:
		_populate_flat(root, forms, modules, resources)

	root.set_collapsed(false)

## Recursively scan a directory for project files.
func _scan_directory(path: String, forms: Array[Dictionary], modules: Array[Dictionary], resources: Array[Dictionary]):
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
				_scan_directory(full_path, forms, modules, resources)
		else:
			if file_name.ends_with(".vg"):
				# Determine if it's a Form or Module
				# Forms typically have a corresponding .tscn or contain Form-level keywords
				var is_form = _is_form_script(full_path)
				if is_form:
					forms.append({"name": file_name.get_basename(), "path": full_path})
				else:
					modules.append({"name": file_name.get_basename(), "path": full_path})
			elif file_name.ends_with(".tscn") or file_name.ends_with(".scn"):
				# Only add scenes not already represented by a .vg form
				resources.append({"name": file_name.get_basename(), "path": full_path, "type": "scene"})
			elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
				resources.append({"name": file_name.get_basename(), "path": full_path, "type": "resource"})
		file_name = dir.get_next()
	dir.list_dir_end()

## Check if a .vg script is a Form (has a corresponding scene or Form keywords).
func _is_form_script(path: String) -> bool:
	# Check for corresponding .tscn
	var scene_path = path.get_basename() + ".tscn"
	if FileAccess.file_exists(scene_path):
		return true
	# Check script content for Form-level markers
	var f = FileAccess.open(path, FileAccess.READ)
	if f:
		var content = f.get_as_text()
		f.close()
		# Heuristic: forms usually have "Sub Form_Load" or control event handlers
		if content.find("Sub Form_Load") != -1 or content.find("Sub Form_") != -1:
			return true
		# Check for VB6 form header
		if content.begins_with("VERSION ") or content.find("Begin VB.Form") != -1:
			return true
	return false

## Populate tree with folder grouping (like VB6).
func _populate_with_folders(root: TreeItem, forms: Array[Dictionary], modules: Array[Dictionary], resources: Array[Dictionary]):
	# Forms folder
	if forms.size() > 0:
		var folder = tree.create_item(root)
		folder.set_text(0, FOLDER_FORMS + " (" + str(forms.size()) + ")")
		folder.set_tooltip_text(0, "Form files (.vg with scene)")
		folder.set_selectable(0, true)
		folder.set_metadata(0, {"type": "folder", "folder": FOLDER_FORMS})
		for entry in forms:
			var item = tree.create_item(folder)
			item.set_text(0, entry.name)
			item.set_tooltip_text(0, entry.path)
			item.set_metadata(0, {"type": "form", "path": entry.path})

	# Modules folder
	if modules.size() > 0:
		var folder = tree.create_item(root)
		folder.set_text(0, FOLDER_MODULES + " (" + str(modules.size()) + ")")
		folder.set_tooltip_text(0, "Module files (.vg code-only)")
		folder.set_selectable(0, true)
		folder.set_metadata(0, {"type": "folder", "folder": FOLDER_MODULES})
		for entry in modules:
			var item = tree.create_item(folder)
			item.set_text(0, entry.name)
			item.set_tooltip_text(0, entry.path)
			item.set_metadata(0, {"type": "module", "path": entry.path})

	# Resources folder (scenes & resources without .vg)
	if resources.size() > 0:
		var folder = tree.create_item(root)
		folder.set_text(0, FOLDER_RESOURCES + " (" + str(resources.size()) + ")")
		folder.set_tooltip_text(0, "Scene and resource files")
		folder.set_selectable(0, true)
		folder.set_metadata(0, {"type": "folder", "folder": FOLDER_RESOURCES})
		for entry in resources:
			var item = tree.create_item(folder)
			item.set_text(0, entry.name)
			item.set_tooltip_text(0, entry.path)
			item.set_metadata(0, {"type": entry.get("type", "resource"), "path": entry.path})

## Populate tree flat (no folders) — alphabetical list.
func _populate_flat(root: TreeItem, forms: Array[Dictionary], modules: Array[Dictionary], resources: Array[Dictionary]):
	var all_items: Array[Dictionary] = []
	for entry in forms:
		entry["type"] = "form"
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
			# Open the corresponding scene in 2D editor
			var scene_path = file_path.get_basename() + ".tscn"
			if FileAccess.file_exists(scene_path):
				editor_plugin.get_editor_interface().open_scene_from_path(scene_path)
			else:
				# No scene — open the script
				_open_script(file_path)
		"module":
			_open_script(file_path)
		"scene":
			editor_plugin.get_editor_interface().open_scene_from_path(file_path)
		"resource":
			# Open in inspector
			var res = load(file_path)
			if res:
				editor_plugin.get_editor_interface().edit_resource(res)
		_:
			pass

## View Code button — open selected item's .vg script in the script editor.
func _on_view_code():
	var item = tree.get_selected()
	if not item:
		return
	var meta = item.get_metadata(0)
	if not meta or not meta is Dictionary:
		return

	var file_path = meta.get("path", "")
	if file_path == "":
		return

	if file_path.ends_with(".vg"):
		_open_script(file_path)
	else:
		# For scenes, find attached .vg script
		var vg_path = file_path.get_basename() + ".vg"
		if FileAccess.file_exists(vg_path):
			_open_script(vg_path)

## View Object button — open selected item's scene in the 2D editor.
func _on_view_object():
	var item = tree.get_selected()
	if not item:
		return
	var meta = item.get_metadata(0)
	if not meta or not meta is Dictionary:
		return

	var file_path = meta.get("path", "")
	if file_path == "":
		return

	# Try to find a scene
	var scene_path = file_path
	if file_path.ends_with(".vg"):
		scene_path = file_path.get_basename() + ".tscn"

	if FileAccess.file_exists(scene_path) and (scene_path.ends_with(".tscn") or scene_path.ends_with(".scn")):
		editor_plugin.get_editor_interface().open_scene_from_path(scene_path)

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

# =============================================================================
# HELPERS
# =============================================================================

## Open a script in the script editor.
func _open_script(path: String):
	var script = load(path)
	if script:
		editor_plugin.get_editor_interface().edit_script(script)
