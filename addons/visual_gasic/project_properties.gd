# project_properties.gd
# VB6-style Project Properties dialog.
# Exposes common Godot project settings (app name, version, icon, main scene)
# in a familiar tabbed interface like VB6's Project > Properties.
@tool
extends AcceptDialog

const VGTheme = preload("res://addons/visual_gasic/vg_theme_utils.gd")
const GDAI = preload("res://addons/visual_gasic/gdai.gd")

# VB6 theme palette (match visual_gasic_plugin.gd)
const VB6_PANEL_BG       = Color(0.941, 0.929, 0.910)   # #F0EDE8  cream
const VB6_PANEL_BORDER   = Color(0.72, 0.71, 0.68)
const VB6_HEADER_BG      = Color(0.58, 0.58, 0.62)
const VB6_HEADER_BORDER  = Color(0.4, 0.4, 0.4)
const VB6_HEADER_TEXT    = Color(1.0, 1.0, 1.0)
const VB6_TEXT           = Color(0.0, 0.0, 0.0)
const VB6_LIST_BG        = Color(1.0, 1.0, 1.0)
const VB6_BTN_FACE       = Color("#D4D0C8")
const VB6_BTN_HOVER_BG   = Color(0.95, 0.94, 0.92)
const VB6_BTN_PRESSED_BG = Color(0.88, 0.87, 0.85)
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

var _gdai_enabled_checkbox: CheckBox
var _gdai_provider_edit: LineEdit
var _gdai_api_key_edit: LineEdit
var _gdai_endpoint_edit: LineEdit
var _gdai_model_edit: LineEdit
var _gdai_embedding_model_edit: LineEdit
var _gdai_temperature_edit: LineEdit
var _gdai_max_tokens_edit: LineEdit
var _gdai_top_p_edit: LineEdit
var _gdai_n_edit: LineEdit

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

	# ── GDAI tab ──
	var gdai_tab = _build_gdai_tab()
	gdai_tab.name = "GDAI"
	tabs.add_child(gdai_tab)

	confirmed.connect(_on_ok)
	canceled.connect(queue_free)

func _ready():
	# Apply the full VB6 theme so nothing inherits the dark editor theme
	theme = _build_vb6_dialog_theme()
	_load_settings()

## Builds a VB6-style Theme for the entire dialog tree.
func _build_vb6_dialog_theme() -> Theme:
	var t = Theme.new()

	# ── Window chrome (embedded title-bar) ──
	var win_sb = StyleBoxFlat.new()
	win_sb.bg_color = VB6_HEADER_BG
	win_sb.border_color = VB6_HEADER_BORDER
	win_sb.set_border_width_all(2)
	win_sb.content_margin_left = 4; win_sb.content_margin_right = 4
	win_sb.content_margin_top = 4; win_sb.content_margin_bottom = 4
	t.set_stylebox("embedded_border", "Window", win_sb)
	var win_unfocus = win_sb.duplicate()
	win_unfocus.bg_color = Color(0.50, 0.50, 0.50)
	t.set_stylebox("embedded_unfocused_border", "Window", win_unfocus)
	t.set_color("title_color", "Window", VB6_HEADER_TEXT)
	t.set_color("title_outline_modulate", "Window", Color.TRANSPARENT)

	# ── AcceptDialog panel (cream background) ──
	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = VB6_PANEL_BG
	panel_sb.border_color = VB6_PANEL_BORDER
	panel_sb.set_border_width_all(1)
	panel_sb.set_content_margin_all(10)
	t.set_stylebox("panel", "AcceptDialog", panel_sb)

	# ── TabContainer ──
	# Tab panel (the content area below the tab bar)
	var tab_panel = StyleBoxFlat.new()
	tab_panel.bg_color = VB6_PANEL_BG
	tab_panel.border_color = VB6_PANEL_BORDER
	tab_panel.set_border_width_all(1)
	tab_panel.set_content_margin_all(10)
	t.set_stylebox("panel", "TabContainer", tab_panel)

	# Selected tab
	var tab_sel = StyleBoxFlat.new()
	tab_sel.bg_color = VB6_PANEL_BG
	tab_sel.border_color = VB6_PANEL_BORDER
	tab_sel.border_width_top = 1; tab_sel.border_width_left = 1; tab_sel.border_width_right = 1
	tab_sel.border_width_bottom = 0
	tab_sel.content_margin_left = 10; tab_sel.content_margin_right = 10
	tab_sel.content_margin_top = 4; tab_sel.content_margin_bottom = 4
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)

	# Unselected tab
	var tab_unsel = StyleBoxFlat.new()
	tab_unsel.bg_color = VB6_BTN_FACE
	tab_unsel.border_color = VB6_PANEL_BORDER
	tab_unsel.set_border_width_all(1)
	tab_unsel.content_margin_left = 10; tab_unsel.content_margin_right = 10
	tab_unsel.content_margin_top = 4; tab_unsel.content_margin_bottom = 4
	t.set_stylebox("tab_unselected", "TabContainer", tab_unsel)

	# Hovered tab
	var tab_hov = tab_unsel.duplicate()
	tab_hov.bg_color = VB6_BTN_HOVER_BG
	t.set_stylebox("tab_hovered", "TabContainer", tab_hov)

	# Tab text colors
	t.set_color("font_selected_color", "TabContainer", VB6_TEXT)
	t.set_color("font_unselected_color", "TabContainer", VB6_TEXT)
	t.set_color("font_hovered_color", "TabContainer", VB6_TEXT)

	# ── Label ──
	t.set_color("font_color", "Label", VB6_TEXT)

	# ── LineEdit ──
	var le_sb = StyleBoxFlat.new()
	le_sb.bg_color = VB6_LIST_BG
	le_sb.border_color = VB6_PANEL_BORDER
	le_sb.set_border_width_all(1)
	le_sb.content_margin_left = 4; le_sb.content_margin_right = 4
	t.set_stylebox("normal", "LineEdit", le_sb)
	t.set_stylebox("focus", "LineEdit", le_sb)
	t.set_color("font_color", "LineEdit", VB6_TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Color(0.5, 0.5, 0.5))

	# ── TextEdit ──
	var te_sb = StyleBoxFlat.new()
	te_sb.bg_color = VB6_LIST_BG
	te_sb.border_color = VB6_PANEL_BORDER
	te_sb.set_border_width_all(1)
	te_sb.content_margin_left = 4; te_sb.content_margin_right = 4
	t.set_stylebox("normal", "TextEdit", te_sb)
	t.set_stylebox("focus", "TextEdit", te_sb)
	t.set_color("font_color", "TextEdit", VB6_TEXT)

	# ── Button (raised VB6 look) ──
	var btn_sb = StyleBoxFlat.new()
	btn_sb.bg_color = VB6_PANEL_BG
	btn_sb.border_color = VB6_PANEL_BORDER
	btn_sb.set_border_width_all(1)
	btn_sb.content_margin_left = 8; btn_sb.content_margin_right = 8
	btn_sb.content_margin_top = 3; btn_sb.content_margin_bottom = 3
	t.set_stylebox("normal", "Button", btn_sb)
	var btn_hov = StyleBoxFlat.new()
	btn_hov.bg_color = VB6_BTN_HOVER_BG
	btn_hov.border_color = VB6_PANEL_BORDER
	btn_hov.set_border_width_all(1)
	btn_hov.content_margin_left = 8; btn_hov.content_margin_right = 8
	btn_hov.content_margin_top = 3; btn_hov.content_margin_bottom = 3
	t.set_stylebox("hover", "Button", btn_hov)
	var btn_pre = StyleBoxFlat.new()
	btn_pre.bg_color = VB6_BTN_PRESSED_BG
	btn_pre.border_color = VB6_PANEL_BORDER
	btn_pre.set_border_width_all(1)
	btn_pre.content_margin_left = 8; btn_pre.content_margin_right = 8
	btn_pre.content_margin_top = 3; btn_pre.content_margin_bottom = 3
	t.set_stylebox("pressed", "Button", btn_pre)
	t.set_color("font_color", "Button", VB6_TEXT)
	t.set_color("font_hover_color", "Button", VB6_TEXT)
	t.set_color("font_pressed_color", "Button", VB6_TEXT)

	return t

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
	VGTheme.hook_line_edit(_name_edit)
	vbox.add_child(_name_edit)

	# Project Description
	vbox.add_child(_make_label("Project Description:"))
	_desc_edit = TextEdit.new()
	_desc_edit.custom_minimum_size = Vector2(400, 60)
	VGTheme.hook_text_edit(_desc_edit)
	vbox.add_child(_desc_edit)

	# Startup Form
	vbox.add_child(_make_label("Startup Object:"))
	var startup_hbox = HBoxContainer.new()
	_main_scene_edit = LineEdit.new()
	_main_scene_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	VGTheme.hook_line_edit(_main_scene_edit)
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
	VGTheme.hook_line_edit(_version_edit)
	vbox.add_child(_version_edit)

	# Application Icon
	vbox.add_child(_make_label("Application Icon:"))
	var icon_hbox = HBoxContainer.new()
	_icon_edit = LineEdit.new()
	_icon_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	VGTheme.hook_line_edit(_icon_edit)
	icon_hbox.add_child(_icon_edit)
	_icon_browse = Button.new()
	_icon_browse.text = "..."
	_icon_browse.custom_minimum_size.x = 30
	_icon_browse.pressed.connect(_browse_icon)
	icon_hbox.add_child(_icon_browse)
	vbox.add_child(icon_hbox)

	return vbox

func _build_gdai_tab() -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	vbox.add_child(_make_label("GDAI Enabled:"))
	_gdai_enabled_checkbox = CheckBox.new()
	vbox.add_child(_gdai_enabled_checkbox)

	vbox.add_child(_make_label("Provider:"))
	_gdai_provider_edit = LineEdit.new()
	_gdai_provider_edit.placeholder_text = "openai"
	VGTheme.hook_line_edit(_gdai_provider_edit)
	vbox.add_child(_gdai_provider_edit)

	vbox.add_child(_make_label("API Key:"))
	_gdai_api_key_edit = LineEdit.new()
	_gdai_api_key_edit.secret = true
	VGTheme.hook_line_edit(_gdai_api_key_edit)
	vbox.add_child(_gdai_api_key_edit)

	vbox.add_child(_make_label("Endpoint:"))
	_gdai_endpoint_edit = LineEdit.new()
	VGTheme.hook_line_edit(_gdai_endpoint_edit)
	vbox.add_child(_gdai_endpoint_edit)

	vbox.add_child(_make_label("Model:"))
	_gdai_model_edit = LineEdit.new()
	VGTheme.hook_line_edit(_gdai_model_edit)
	vbox.add_child(_gdai_model_edit)

	vbox.add_child(_make_label("Embedding model:"))
	_gdai_embedding_model_edit = LineEdit.new()
	VGTheme.hook_line_edit(_gdai_embedding_model_edit)
	vbox.add_child(_gdai_embedding_model_edit)

	vbox.add_child(_make_label("Temperature:"))
	_gdai_temperature_edit = LineEdit.new()
	_gdai_temperature_edit.placeholder_text = "0.7"
	VGTheme.hook_line_edit(_gdai_temperature_edit)
	vbox.add_child(_gdai_temperature_edit)

	vbox.add_child(_make_label("Max tokens:"))
	_gdai_max_tokens_edit = LineEdit.new()
	_gdai_max_tokens_edit.placeholder_text = "256"
	VGTheme.hook_line_edit(_gdai_max_tokens_edit)
	vbox.add_child(_gdai_max_tokens_edit)

	vbox.add_child(_make_label("Top P:"))
	_gdai_top_p_edit = LineEdit.new()
	_gdai_top_p_edit.placeholder_text = "1.0"
	VGTheme.hook_line_edit(_gdai_top_p_edit)
	vbox.add_child(_gdai_top_p_edit)

	vbox.add_child(_make_label("N responses:"))
	_gdai_n_edit = LineEdit.new()
	_gdai_n_edit.placeholder_text = "1"
	VGTheme.hook_line_edit(_gdai_n_edit)
	vbox.add_child(_gdai_n_edit)

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
	_load_gdai_settings()

func _load_gdai_settings() -> void:
	_gdai_enabled_checkbox.button_pressed = bool(ProjectSettings.get_setting("vg/gdai/enabled", true))
	_gdai_provider_edit.text = str(ProjectSettings.get_setting("vg/gdai/provider", "openai"))
	_gdai_api_key_edit.text = str(ProjectSettings.get_setting("vg/gdai/api_key", ""))
	_gdai_endpoint_edit.text = str(ProjectSettings.get_setting("vg/gdai/endpoint", "https://api.openai.com/v1"))
	_gdai_model_edit.text = str(ProjectSettings.get_setting("vg/gdai/model", "gpt-4.1-mini"))
	_gdai_embedding_model_edit.text = str(ProjectSettings.get_setting("vg/gdai/embedding_model", "text-embedding-3-large"))
	_gdai_temperature_edit.text = str(ProjectSettings.get_setting("vg/gdai/temperature", 0.7))
	_gdai_max_tokens_edit.text = str(ProjectSettings.get_setting("vg/gdai/max_tokens", 256))
	_gdai_top_p_edit.text = str(ProjectSettings.get_setting("vg/gdai/top_p", 1.0))
	_gdai_n_edit.text = str(ProjectSettings.get_setting("vg/gdai/n", 1))

func _save_gdai_settings() -> void:
	ProjectSettings.set_setting("vg/gdai/enabled", _gdai_enabled_checkbox.pressed)
	ProjectSettings.set_setting("vg/gdai/provider", _gdai_provider_edit.text.strip_edges())
	ProjectSettings.set_setting("vg/gdai/api_key", _gdai_api_key_edit.text.strip_edges())
	ProjectSettings.set_setting("vg/gdai/endpoint", _gdai_endpoint_edit.text.strip_edges())
	ProjectSettings.set_setting("vg/gdai/model", _gdai_model_edit.text.strip_edges())
	ProjectSettings.set_setting("vg/gdai/embedding_model", _gdai_embedding_model_edit.text.strip_edges())
	ProjectSettings.set_setting("vg/gdai/temperature", _parse_float(_gdai_temperature_edit.text.strip_edges(), 0.7))
	ProjectSettings.set_setting("vg/gdai/max_tokens", _parse_int(_gdai_max_tokens_edit.text.strip_edges(), 256))
	ProjectSettings.set_setting("vg/gdai/top_p", _parse_float(_gdai_top_p_edit.text.strip_edges(), 1.0))
	ProjectSettings.set_setting("vg/gdai/n", _parse_int(_gdai_n_edit.text.strip_edges(), 1))

func _parse_float(value: String, default_value: float) -> float:
	if value.strip_edges() == "":
		return default_value
	return String(value).to_float()

func _parse_int(value: String, default_value: int) -> int:
	if value.strip_edges() == "":
		return default_value
	return String(value).to_int()

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

	_save_gdai_settings()
	ProjectSettings.save()
	GDAI.initialize_from_project_settings()
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
	return lbl
