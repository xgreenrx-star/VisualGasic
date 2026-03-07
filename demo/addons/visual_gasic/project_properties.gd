# project_properties.gd
# VB6-style Project Properties dialog.
# Exposes common Godot project settings (app name, version, icon, main scene)
# in a familiar tabbed interface like VB6's Project > Properties.
@tool
extends AcceptDialog

# VB6 theme palette (match visual_gasic_plugin.gd)
const VB6_PANEL_BG       = Color(0.941, 0.929, 0.910)   # #F0EDE8  cream
const VB6_PANEL_BORDER   = Color(0.72, 0.71, 0.68)
const VB6_HEADER_BG      = Color(0.58, 0.58, 0.62)
const VB6_HEADER_TEXT    = Color(1.0, 1.0, 1.0)
const VB6_TEXT           = Color(0.0, 0.0, 0.0)
const VB6_LIST_BG        = Color(1.0, 1.0, 1.0)
const VB6_BTN_FACE       = Color("#D4D0C8")
const VB6_ACTIVE_TITLE   = Color(0.0, 0.0, 0.5)

# ── Field references ──
var _name_edit: LineEdit
var _desc_edit: TextEdit
var _version_edit: LineEdit
var _icon_edit: LineEdit
var _icon_browse: Button
var _main_scene_edit: LineEdit
var _main_scene_browse: Button
var _startup_form_option: OptionButton

func _init():
	title = "Project Properties"
	size = Vector2i(500, 420)
	unresizable = false
	ok_button_text = "OK"
	dialog_hide_on_ok = false

	# Build UI
	var tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(460, 300)
	add_child(tabs)

	# ── General tab ──
	var general = _build_general_tab()
	general.name = "General"
	tabs.add_child(general)

	# ── Make tab ──
	var make = _build_make_tab()
	make.name = "Make"
	tabs.add_child(make)

	# Style the dialog background
	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = VB6_PANEL_BG
	panel_sb.border_width_top = 1
	panel_sb.border_width_bottom = 1
	panel_sb.border_width_left = 1
	panel_sb.border_width_right = 1
	panel_sb.border_color = VB6_PANEL_BORDER
	add_theme_stylebox_override("panel", panel_sb)

	confirmed.connect(_on_ok)
	canceled.connect(queue_free)

func _ready():
	_load_settings()

# ─────────────────────────────────────────────────────────
# TAB BUILDERS
# ─────────────────────────────────────────────────────────

func _build_general_tab() -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# Project Name
	vbox.add_child(_make_label("Project Name:"))
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size.x = 400
	_style_line_edit(_name_edit)
	vbox.add_child(_name_edit)

	# Project Description
	vbox.add_child(_make_label("Project Description:"))
	_desc_edit = TextEdit.new()
	_desc_edit.custom_minimum_size = Vector2(400, 60)
	var desc_sb = StyleBoxFlat.new()
	desc_sb.bg_color = VB6_LIST_BG
	desc_sb.border_width_top = 1
	desc_sb.border_width_bottom = 1
	desc_sb.border_width_left = 1
	desc_sb.border_width_right = 1
	desc_sb.border_color = VB6_PANEL_BORDER
	_desc_edit.add_theme_stylebox_override("normal", desc_sb)
	_desc_edit.add_theme_color_override("font_color", VB6_TEXT)
	_desc_edit.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_desc_edit)

	# Startup Form
	vbox.add_child(_make_label("Startup Object:"))
	var startup_hbox = HBoxContainer.new()
	_main_scene_edit = LineEdit.new()
	_main_scene_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_line_edit(_main_scene_edit)
	startup_hbox.add_child(_main_scene_edit)
	_main_scene_browse = Button.new()
	_main_scene_browse.text = "..."
	_main_scene_browse.custom_minimum_size.x = 30
	_main_scene_browse.pressed.connect(_browse_main_scene)
	startup_hbox.add_child(_main_scene_browse)
	vbox.add_child(startup_hbox)

	return vbox

func _build_make_tab() -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# Version
	vbox.add_child(_make_label("Version:"))
	_version_edit = LineEdit.new()
	_version_edit.placeholder_text = "1.0.0"
	_version_edit.custom_minimum_size.x = 200
	_style_line_edit(_version_edit)
	vbox.add_child(_version_edit)

	# Application Icon
	vbox.add_child(_make_label("Application Icon:"))
	var icon_hbox = HBoxContainer.new()
	_icon_edit = LineEdit.new()
	_icon_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_line_edit(_icon_edit)
	icon_hbox.add_child(_icon_edit)
	_icon_browse = Button.new()
	_icon_browse.text = "..."
	_icon_browse.custom_minimum_size.x = 30
	_icon_browse.pressed.connect(_browse_icon)
	icon_hbox.add_child(_icon_browse)
	vbox.add_child(icon_hbox)

	return vbox

# ─────────────────────────────────────────────────────────
# SETTINGS I/O
# ─────────────────────────────────────────────────────────

func _load_settings():
	_name_edit.text = ProjectSettings.get_setting("application/config/name", "")
	_desc_edit.text = ProjectSettings.get_setting("application/config/description", "")
	_version_edit.text = ProjectSettings.get_setting("application/config/version", "")
	_icon_edit.text = ProjectSettings.get_setting("application/config/icon", "")
	_main_scene_edit.text = ProjectSettings.get_setting("application/run/main_scene", "")

func _on_ok():
	var name_val = _name_edit.text.strip_edges()
	var desc_val = _desc_edit.text.strip_edges()
	var version_val = _version_edit.text.strip_edges()
	var icon_val = _icon_edit.text.strip_edges()
	var main_val = _main_scene_edit.text.strip_edges()

	if not name_val.is_empty():
		ProjectSettings.set_setting("application/config/name", name_val)
	if not desc_val.is_empty():
		ProjectSettings.set_setting("application/config/description", desc_val)
	else:
		# Allow clearing description
		ProjectSettings.set_setting("application/config/description", "")
	if not version_val.is_empty():
		ProjectSettings.set_setting("application/config/version", version_val)
	if not icon_val.is_empty():
		ProjectSettings.set_setting("application/config/icon", icon_val)
	if not main_val.is_empty():
		ProjectSettings.set_setting("application/run/main_scene", main_val)

	ProjectSettings.save()
	print("[VisualGasic] Project properties saved.")
	queue_free()

# ─────────────────────────────────────────────────────────
# BROWSE DIALOGS
# ─────────────────────────────────────────────────────────

func _browse_icon():
	var fd = FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_RESOURCES
	fd.add_filter("*.png, *.svg ; Image Files")
	fd.title = "Select Application Icon"
	fd.min_size = Vector2i(500, 350)
	if not _icon_edit.text.is_empty():
		fd.current_path = _icon_edit.text
	else:
		fd.current_dir = "res://"
	fd.file_selected.connect(func(path: String):
		_icon_edit.text = path
		fd.queue_free()
	)
	fd.canceled.connect(fd.queue_free)
	add_child(fd)
	fd.popup_centered()

func _browse_main_scene():
	var fd = FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_RESOURCES
	fd.add_filter("*.tscn ; Godot Scenes")
	fd.title = "Select Startup Form"
	fd.min_size = Vector2i(500, 350)
	if not _main_scene_edit.text.is_empty():
		fd.current_path = _main_scene_edit.text
	else:
		fd.current_dir = "res://"
	fd.file_selected.connect(func(path: String):
		_main_scene_edit.text = path
		fd.queue_free()
	)
	fd.canceled.connect(fd.queue_free)
	add_child(fd)
	fd.popup_centered()

# ─────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────

func _make_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", VB6_TEXT)
	lbl.add_theme_font_size_override("font_size", 12)
	return lbl

func _style_line_edit(le: LineEdit) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = VB6_LIST_BG
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_color = VB6_PANEL_BORDER
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	le.add_theme_stylebox_override("normal", sb)
	le.add_theme_color_override("font_color", VB6_TEXT)
	le.add_theme_font_size_override("font_size", 12)
