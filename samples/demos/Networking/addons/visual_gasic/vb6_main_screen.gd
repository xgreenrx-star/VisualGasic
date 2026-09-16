@tool
extends Control
## VB6 Main Screen — center content panel for the VB6 editor tab.
##
## Registered as a main editor screen tab ("VB6") alongside 2D/3D/Script/AssetLib.
## Panels (Toolbox, Project Explorer, Properties) live in standard Godot docks
## and are available in ALL editor modes — they are NOT reparented into this
## main screen. This screen provides the center content area with:
##   - Project form/module listing
##   - Quick action buttons (New Form, New Module, Open 2D Designer)
##   - Design tips and status

# =============================================================================
# MEMBER VARIABLES
# =============================================================================

var editor_plugin: EditorPlugin

# Center content widgets
var _form_list_tree: Tree
var _status_label: Label
var _center_toolbar: HBoxContainer

const SETTINGS_SECTION := "VisualGasic"

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready():
	name = "VB6MainScreen"
	_build_layout()

func setup(plugin: EditorPlugin, _toolbox: Control, _proj_explorer: Control, _props_inspector: Control):
	editor_plugin = plugin
	# Note: panels are in Godot docks, not reparented here.
	# Extra args kept for API compatibility but unused.

func _build_layout():
	# Full-rect VBoxContainer as the main content
	var main_vbox = VBoxContainer.new()
	main_vbox.name = "VB6CenterContent"
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main_vbox)

	# Toolbar row
	_center_toolbar = HBoxContainer.new()
	_center_toolbar.name = "CenterToolbar"

	var title_label = Label.new()
	title_label.text = "  ⚡ Visual Gasic IDE"
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center_toolbar.add_child(title_label)

	var btn_new_form = Button.new()
	btn_new_form.text = "📄 New Form"
	btn_new_form.pressed.connect(_on_new_form)
	_center_toolbar.add_child(btn_new_form)

	var btn_new_module = Button.new()
	btn_new_module.text = "📦 New Module"
	btn_new_module.pressed.connect(_on_new_module)
	_center_toolbar.add_child(btn_new_module)

	var btn_switch_2d = Button.new()
	btn_switch_2d.text = "🎨 Open Form Designer"
	btn_switch_2d.tooltip_text = "Open the VB6-style Form Designer canvas"
	btn_switch_2d.pressed.connect(_on_switch_to_form_designer)
	_center_toolbar.add_child(btn_switch_2d)

	main_vbox.add_child(_center_toolbar)

	# Separator
	var sep = HSeparator.new()
	main_vbox.add_child(sep)

	# Form list tree
	var tree_label = Label.new()
	tree_label.text = "  Project Forms & Modules:"
	main_vbox.add_child(tree_label)

	_form_list_tree = Tree.new()
	_form_list_tree.name = "FormListTree"
	_form_list_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form_list_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_form_list_tree.item_activated.connect(_on_form_item_activated)
	main_vbox.add_child(_form_list_tree)

	# Status/tip
	_status_label = Label.new()
	_status_label.text = "  💡 Tip: Double-click a form to open it in the 2D designer. Use the Toolbox dock to drag controls onto forms."
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(_status_label)

# =============================================================================
# CENTER CONTENT — Form/Module listing
# =============================================================================

func refresh():
	"""Called when VB6 tab becomes visible to refresh the form list."""
	_refresh_form_list()

func _refresh_form_list():
	if not _form_list_tree:
		return
	_form_list_tree.clear()
	var root_item = _form_list_tree.create_item()
	root_item.set_text(0, ProjectSettings.get_setting("application/config/name", "Project"))

	var forms_folder = root_item.create_child()
	forms_folder.set_text(0, "📁 Forms")
	forms_folder.set_selectable(0, false)

	var modules_folder = root_item.create_child()
	modules_folder.set_text(0, "📁 Modules")
	modules_folder.set_selectable(0, false)

	_scan_project_files(forms_folder, modules_folder)

func _scan_project_files(forms_parent: TreeItem, modules_parent: TreeItem):
	var dir = DirAccess.open("res://")
	if not dir:
		return
	_scan_dir_recursive(dir, "res://", forms_parent, modules_parent)

func _scan_dir_recursive(dir: DirAccess, path: String, forms_parent: TreeItem, modules_parent: TreeItem):
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.begins_with(".") or file_name == "addons":
			file_name = dir.get_next()
			continue
		var full_path = path.path_join(file_name)
		if dir.current_is_dir():
			var sub_dir = DirAccess.open(full_path)
			if sub_dir:
				_scan_dir_recursive(sub_dir, full_path, forms_parent, modules_parent)
		elif file_name.ends_with(".tscn"):
			var vg_path = full_path.replace(".tscn", ".vg")
			if FileAccess.file_exists(vg_path):
				var item = forms_parent.create_child()
				item.set_text(0, "📋 " + file_name.get_basename())
				item.set_metadata(0, full_path)
				item.set_tooltip_text(0, full_path)
		elif file_name.ends_with(".vg"):
			var tscn_path = full_path.replace(".vg", ".tscn")
			if not FileAccess.file_exists(tscn_path):
				var item = modules_parent.create_child()
				item.set_text(0, "📄 " + file_name.get_basename())
				item.set_metadata(0, full_path)
				item.set_tooltip_text(0, full_path)
		file_name = dir.get_next()
	dir.list_dir_end()

func _on_form_item_activated():
	var selected = _form_list_tree.get_selected()
	if not selected:
		return
	var path = selected.get_metadata(0)
	if not path or path == "":
		return
	if path is String:
		if path.ends_with(".tscn"):
			if editor_plugin and editor_plugin.has_method("open_form_in_designer"):
				editor_plugin.open_form_in_designer(path)
			else:
				EditorInterface.open_scene_from_path(path)
				EditorInterface.set_main_screen_editor("Visual Gasic IDE")
		elif path.ends_with(".vg"):
			var script = load(path)
			if script:
				EditorInterface.edit_script(script)

# =============================================================================
# ACTIONS
# =============================================================================

func _on_new_form():
	if editor_plugin and editor_plugin.has_method("_on_new_form"):
		editor_plugin._on_new_form()

func _on_new_module():
	if editor_plugin and editor_plugin.has_method("_on_new_module"):
		editor_plugin._on_new_module()

func _on_switch_to_form_designer():
	EditorInterface.set_main_screen_editor("Visual Gasic IDE")

# =============================================================================
# LAYOUT PERSISTENCE (minimal — no splits to save)
# =============================================================================

func save_layout(_config: ConfigFile):
	pass

func restore_layout(_config: ConfigFile):
	pass
