@tool
## Web Publish Plugin — Publish VG forms and games to the web
##
## Two export modes:
##   📋 Form → Web : Convert VisualGasic Form Designer forms to responsive HTML/CSS/JS
##   🎮 Game → Web : Publish AGCK games with Flash-successor features (preloader,
##                   fullscreen, context menu, embed code, portal page)
##
## This is a standalone VG plugin — it works with or without AGCK enabled.
extends "res://addons/visual_gasic/vg_plugin_base.gd"

const WP_DIR = "res://addons/visual_gasic/plugins/web_publish/"

# ─── Theme ───────────────────────────────────────────────────
const BG_COLOR    = Color(0.11, 0.12, 0.16)
const CARD_BG     = Color(0.14, 0.15, 0.20)
const HEADER_BG   = Color(0.08, 0.09, 0.13)
const ACCENT      = Color(0.35, 0.60, 0.95)
const ACCENT_FORM = Color(0.30, 0.75, 0.55)
const WHITE       = Color(1.0, 1.0, 1.0)
const DIM         = Color(0.55, 0.55, 0.60)
const GOLD        = Color(1.0, 0.82, 0.35)

# ─── Mode ────────────────────────────────────────────────────
enum Mode { FORM, GAME }
var _mode: int = Mode.FORM

# ─── Shared UI ───────────────────────────────────────────────
var _mode_tabs: TabBar = null
var _form_panel: Control = null
var _game_panel: Control = null
var _log_output: RichTextLabel = null
var _status_label: Label = null

# ─── Form Mode UI ───────────────────────────────────────────
var _form_path_edit: LineEdit = null
var _form_browse_btn: Button = null
var _form_theme_opt: OptionButton = null
var _form_responsive_chk: CheckButton = null
var _form_layout_opt: OptionButton = null
var _form_include_js_chk: CheckButton = null
var _form_title_edit: LineEdit = null

# ─── Game Mode UI ───────────────────────────────────────────
var _game_loading_opt: OptionButton = null
var _game_quality_opt: OptionButton = null
var _game_scale_opt: OptionButton = null
var _game_bg_btn: ColorPickerButton = null
var _game_loading_color_btn: ColorPickerButton = null
var _game_fullscreen_chk: CheckButton = null
var _game_rightclick_chk: CheckButton = null
var _game_watermark_chk: CheckButton = null
var _game_embed_chk: CheckButton = null
var _game_splash_chk: CheckButton = null
var _game_desc_edit: LineEdit = null
var _game_title_edit: LineEdit = null
var _game_width_spin: SpinBox = null
var _game_height_spin: SpinBox = null

# ─── Settings persistence ───────────────────────────────────
var _settings: Dictionary = {}
const SETTINGS_PATH = "user://vg_web_publish_settings.cfg"


# ─── Plugin Identity ─────────────────────────────────────────

func get_plugin_name() -> String:
	return "Web Publish"

func get_toolbar_icon() -> String:
	return "🌐"

func get_toolbar_color() -> Color:
	return Color(0.20, 0.40, 0.75)

func get_toolbar_tooltip() -> String:
	return "Publish forms & games to the web (Flash successor)"


# ─── UI Construction ─────────────────────────────────────────

func _build_ui() -> void:
	# Root container (fills the HSplitContainer _view)
	var root = PanelContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var root_style = StyleBoxFlat.new()
	root_style.bg_color = BG_COLOR
	root.add_theme_stylebox_override("panel", root_style)
	_view.add_child(root)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	root.add_child(main_vbox)

	# ── Header ──
	var header = PanelContainer.new()
	var h_style = StyleBoxFlat.new()
	h_style.bg_color = HEADER_BG
	h_style.content_margin_left = 16
	h_style.content_margin_right = 16
	h_style.content_margin_top = 10
	h_style.content_margin_bottom = 6
	header.add_theme_stylebox_override("panel", h_style)
	main_vbox.add_child(header)

	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	header.add_child(header_hbox)

	var title_lbl = Label.new()
	title_lbl.text = "🌐  Web Publish"
	title_lbl.label_settings = _ls(16, WHITE)
	header_hbox.add_child(title_lbl)

	var subtitle = Label.new()
	subtitle.text = "— The Flash Successor Pipeline"
	subtitle.label_settings = _ls(11, DIM)
	subtitle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_hbox.add_child(subtitle)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)

	# Back button
	var back_btn = Button.new()
	back_btn.text = "← Back to IDE"
	back_btn.add_theme_font_size_override("font_size", 11)
	back_btn.pressed.connect(request_back_to_form)
	header_hbox.add_child(back_btn)

	# ── Mode Tab Bar ──
	_mode_tabs = TabBar.new()
	_mode_tabs.add_tab("📋  Form → Web")
	_mode_tabs.add_tab("🎮  Game → Web")
	_mode_tabs.add_theme_font_size_override("font_size", 13)
	_mode_tabs.tab_changed.connect(_on_mode_changed)
	main_vbox.add_child(_mode_tabs)

	# ── Content area (ScrollContainer for both panels) ──
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	var content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 0)
	scroll.add_child(content_vbox)

	# Form Mode Panel
	_form_panel = _build_form_panel()
	content_vbox.add_child(_form_panel)

	# Game Mode Panel
	_game_panel = _build_game_panel()
	content_vbox.add_child(_game_panel)

	# ── Log Output ──
	var log_header = Label.new()
	log_header.text = "  📝 Output Log"
	log_header.label_settings = _ls(11, DIM)
	main_vbox.add_child(log_header)

	_log_output = RichTextLabel.new()
	_log_output.bbcode_enabled = true
	_log_output.scroll_following = true
	_log_output.custom_minimum_size = Vector2(0, 120)
	_log_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var log_style = StyleBoxFlat.new()
	log_style.bg_color = Color(0.06, 0.06, 0.08)
	log_style.content_margin_left = 8
	log_style.content_margin_right = 8
	log_style.content_margin_top = 4
	log_style.content_margin_bottom = 4
	_log_output.add_theme_stylebox_override("normal", log_style)
	_log_output.add_theme_font_size_override("normal_font_size", 11)
	main_vbox.add_child(_log_output)

	# ── Status Bar ──
	_status_label = Label.new()
	_status_label.text = "  Ready — select a mode above to get started"
	_status_label.label_settings = _ls(10, DIM)
	main_vbox.add_child(_status_label)

	# Apply initial state
	_load_settings()
	_on_mode_changed(0)

	_log("[color=#8888cc]🌐 Web Publish plugin ready.[/color]")
	_log("  [color=#88bb88]📋 Form → Web[/color] : Convert VG forms to HTML/CSS/JS")
	_log("  [color=#8888dd]🎮 Game → Web[/color] : Publish AGCK games with preloader & embed code")


# ─── Form Mode Panel ─────────────────────────────────────────

func _build_form_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = CARD_BG
	p_style.set_corner_radius_all(6)
	p_style.border_width_top = 2
	p_style.border_color = ACCENT_FORM
	p_style.content_margin_left = 16
	p_style.content_margin_right = 16
	p_style.content_margin_top = 12
	p_style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", p_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "📋 Form → HTML  (VB6-style form to web page)"
	title.label_settings = _ls(13, ACCENT_FORM)
	vbox.add_child(title)

	var desc = Label.new()
	desc.text = "Convert a VisualGasic form into a standalone responsive web page.\nControls map directly to HTML elements — the true Flash successor for apps."
	desc.label_settings = _ls(10, DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	vbox.add_child(HSeparator.new())

	# Options Grid
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid)

	# Form File
	_add_label(grid, "Form File:", "Select a .tscn form created in the Form Designer")
	var path_hbox = HBoxContainer.new()
	path_hbox.add_theme_constant_override("separation", 4)
	path_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form_path_edit = LineEdit.new()
	_form_path_edit.placeholder_text = "res://forms/Form1.tscn"
	_form_path_edit.add_theme_font_size_override("font_size", 11)
	_form_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_hbox.add_child(_form_path_edit)
	_form_browse_btn = Button.new()
	_form_browse_btn.text = "📂"
	_form_browse_btn.add_theme_font_size_override("font_size", 11)
	_form_browse_btn.pressed.connect(_on_form_browse)
	path_hbox.add_child(_form_browse_btn)
	grid.add_child(path_hbox)

	# Page Title
	_add_label(grid, "Page Title:", "HTML <title> for the page")
	_form_title_edit = LineEdit.new()
	_form_title_edit.placeholder_text = "My App"
	_form_title_edit.add_theme_font_size_override("font_size", 11)
	_form_title_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_form_title_edit)

	# CSS Theme
	_add_label(grid, "Theme:", "Visual style for the generated HTML")
	_form_theme_opt = OptionButton.new()
	_form_theme_opt.add_theme_font_size_override("font_size", 11)
	for t in ["Classic VB6", "Modern Flat", "Dark Mode", "Bootstrap-like", "Minimal"]:
		_form_theme_opt.add_item(t)
	grid.add_child(_form_theme_opt)

	# Layout Mode
	_add_label(grid, "Layout:", "How controls are arranged in the HTML")
	_form_layout_opt = OptionButton.new()
	_form_layout_opt.add_theme_font_size_override("font_size", 11)
	for l in ["Absolute (pixel-perfect)", "Responsive (flex/grid)", "Centered Card"]:
		_form_layout_opt.add_item(l)
	grid.add_child(_form_layout_opt)

	# Responsive
	_form_responsive_chk = CheckButton.new()
	_form_responsive_chk.text = "📱 Responsive"
	_form_responsive_chk.tooltip_text = "Scale form to fit mobile screens"
	_form_responsive_chk.add_theme_font_size_override("font_size", 11)
	_form_responsive_chk.button_pressed = true
	grid.add_child(_form_responsive_chk)

	# Include JS event stubs
	_form_include_js_chk = CheckButton.new()
	_form_include_js_chk.text = "📜 JS Event Stubs"
	_form_include_js_chk.tooltip_text = "Generate JavaScript event handler functions for each control"
	_form_include_js_chk.add_theme_font_size_override("font_size", 11)
	_form_include_js_chk.button_pressed = true
	grid.add_child(_form_include_js_chk)

	# Filler cells
	grid.add_child(Control.new())
	grid.add_child(Control.new())

	# ── Export Button ──
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 8)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)

	var export_btn = _styled_button("📋  EXPORT FORM TO HTML", ACCENT_FORM, Vector2(260, 42))
	export_btn.pressed.connect(_on_form_export)
	btn_hbox.add_child(export_btn)

	var hint = Label.new()
	hint.text = "Generates a standalone HTML page from your VG form"
	hint.label_settings = _ls(10, DIM)
	btn_hbox.add_child(hint)

	return panel


# ─── Game Mode Panel ──────────────────────────────────────────

func _build_game_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = CARD_BG
	p_style.set_corner_radius_all(6)
	p_style.border_width_top = 2
	p_style.border_color = ACCENT
	p_style.content_margin_left = 16
	p_style.content_margin_right = 16
	p_style.content_margin_top = 12
	p_style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", p_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "🎮 Game → Web  (Flash-Successor Pipeline)"
	title.label_settings = _ls(13, ACCENT)
	vbox.add_child(title)

	var desc = Label.new()
	desc.text = "Publish your game with Newgrounds-era features: preloader, fullscreen,\nright-click menu, embed code, and portal-ready landing page."
	desc.label_settings = _ls(10, DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	vbox.add_child(HSeparator.new())

	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid)

	# Game Title
	_add_label(grid, "Game Title:", "Title shown in the browser tab and portal page")
	_game_title_edit = LineEdit.new()
	_game_title_edit.text = "My Game"
	_game_title_edit.add_theme_font_size_override("font_size", 11)
	_game_title_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_game_title_edit)

	# Canvas Size
	_add_label(grid, "Canvas:", "Game canvas dimensions in pixels")
	var size_hbox = HBoxContainer.new()
	size_hbox.add_theme_constant_override("separation", 4)
	_game_width_spin = SpinBox.new()
	_game_width_spin.min_value = 160
	_game_width_spin.max_value = 3840
	_game_width_spin.value = 1280
	_game_width_spin.add_theme_font_size_override("font_size", 10)
	_game_width_spin.custom_minimum_size = Vector2(70, 0)
	size_hbox.add_child(_game_width_spin)
	var x_lbl = Label.new()
	x_lbl.text = "×"
	x_lbl.label_settings = _ls(11, DIM)
	size_hbox.add_child(x_lbl)
	_game_height_spin = SpinBox.new()
	_game_height_spin.min_value = 120
	_game_height_spin.max_value = 2160
	_game_height_spin.value = 720
	_game_height_spin.add_theme_font_size_override("font_size", 10)
	_game_height_spin.custom_minimum_size = Vector2(70, 0)
	size_hbox.add_child(_game_height_spin)
	grid.add_child(size_hbox)

	# Preloader (Flash tradition)
	_add_label(grid, "Preloader:", "Loading screen style (Flash's preloader tradition)")
	_game_loading_opt = OptionButton.new()
	_game_loading_opt.add_theme_font_size_override("font_size", 11)
	for s in ["Bar", "Spinner", "Retro", "None"]:
		_game_loading_opt.add_item(s)
	grid.add_child(_game_loading_opt)

	# Quality
	_add_label(grid, "Quality:", "Rendering quality (Flash's _quality: LOW, MEDIUM, HIGH, BEST)")
	_game_quality_opt = OptionButton.new()
	_game_quality_opt.add_theme_font_size_override("font_size", 11)
	for q in ["Low", "Medium", "High", "Best"]:
		_game_quality_opt.add_item(q)
	_game_quality_opt.selected = 2  # High
	grid.add_child(_game_quality_opt)

	# Scale Mode
	_add_label(grid, "Scale:", "Scale mode (Flash: showAll→Fit, noBorder→Fill, exactFit→Stretch)")
	_game_scale_opt = OptionButton.new()
	_game_scale_opt.add_theme_font_size_override("font_size", 11)
	for sm in ["Fit", "Fill", "Stretch", "Pixel-Perfect"]:
		_game_scale_opt.add_item(sm)
	grid.add_child(_game_scale_opt)

	# BG Color
	_add_label(grid, "BG Color:", "Background color (Flash's bgcolor embed parameter)")
	_game_bg_btn = ColorPickerButton.new()
	_game_bg_btn.color = Color.html("#0d0d14")
	_game_bg_btn.custom_minimum_size = Vector2(60, 22)
	grid.add_child(_game_bg_btn)

	# Loading Color
	_add_label(grid, "Load Color:", "Preloader accent color")
	_game_loading_color_btn = ColorPickerButton.new()
	_game_loading_color_btn.color = Color.html("#ffd159")
	_game_loading_color_btn.custom_minimum_size = Vector2(60, 22)
	grid.add_child(_game_loading_color_btn)

	# Feature Toggles
	_game_fullscreen_chk = CheckButton.new()
	_game_fullscreen_chk.text = "⛶ Fullscreen Btn"
	_game_fullscreen_chk.tooltip_text = "Show fullscreen toggle (Flash's Stage.displayState)"
	_game_fullscreen_chk.add_theme_font_size_override("font_size", 11)
	_game_fullscreen_chk.button_pressed = true
	grid.add_child(_game_fullscreen_chk)

	_game_rightclick_chk = CheckButton.new()
	_game_rightclick_chk.text = "🖱️ Context Menu"
	_game_rightclick_chk.tooltip_text = "Custom right-click menu (Flash's ContextMenu class)"
	_game_rightclick_chk.add_theme_font_size_override("font_size", 11)
	_game_rightclick_chk.button_pressed = true
	grid.add_child(_game_rightclick_chk)

	_game_watermark_chk = CheckButton.new()
	_game_watermark_chk.text = "🏷️ Watermark"
	_game_watermark_chk.tooltip_text = "\"Made with VisualGasic\" badge"
	_game_watermark_chk.add_theme_font_size_override("font_size", 11)
	_game_watermark_chk.button_pressed = true
	grid.add_child(_game_watermark_chk)

	_game_embed_chk = CheckButton.new()
	_game_embed_chk.text = "📋 Embed Code"
	_game_embed_chk.tooltip_text = "Generate embed snippet for game portals"
	_game_embed_chk.add_theme_font_size_override("font_size", 11)
	_game_embed_chk.button_pressed = true
	grid.add_child(_game_embed_chk)

	# Description
	_add_label(grid, "Description:", "Game description for portals and SEO")
	_game_desc_edit = LineEdit.new()
	_game_desc_edit.placeholder_text = "A fun game made with VisualGasic"
	_game_desc_edit.add_theme_font_size_override("font_size", 11)
	_game_desc_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_game_desc_edit)

	# Splash
	_game_splash_chk = CheckButton.new()
	_game_splash_chk.text = "✨ Splash Screen"
	_game_splash_chk.tooltip_text = "Show splash image during load"
	_game_splash_chk.add_theme_font_size_override("font_size", 11)
	_game_splash_chk.button_pressed = true
	grid.add_child(_game_splash_chk)

	# Filler
	grid.add_child(Control.new())

	# ── Publish Button ──
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 8)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)

	var pub_btn = _styled_button("🎮  PUBLISH GAME TO WEB", ACCENT, Vector2(260, 42))
	pub_btn.pressed.connect(_on_game_publish)
	btn_hbox.add_child(pub_btn)

	var hint = Label.new()
	hint.text = "Generate HTML wrapper, preloader, embed code, and portal page"
	hint.label_settings = _ls(10, DIM)
	btn_hbox.add_child(hint)

	return panel


# ─── Mode Switching ──────────────────────────────────────────

func _on_mode_changed(idx: int) -> void:
	_mode = idx
	if is_instance_valid(_form_panel):
		_form_panel.visible = (idx == Mode.FORM)
	if is_instance_valid(_game_panel):
		_game_panel.visible = (idx == Mode.GAME)
	if is_instance_valid(_status_label):
		if idx == Mode.FORM:
			_status_label.text = "  📋 Form Mode — select a .tscn form to export as HTML"
		else:
			_status_label.text = "  🎮 Game Mode — configure Flash-successor options and publish"


# ─── Form Export ─────────────────────────────────────────────

func _on_form_browse() -> void:
	# Use Godot's EditorFileDialog to pick a .tscn file
	if not _host_plugin:
		_log("[color=#ff5555]✗ No host plugin — cannot open file dialog[/color]")
		return
	var dlg = EditorFileDialog.new()
	dlg.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dlg.access = EditorFileDialog.ACCESS_RESOURCES
	dlg.add_filter("*.tscn", "VG Form Scene")
	dlg.title = "Select a VisualGasic Form"
	dlg.file_selected.connect(func(path):
		if is_instance_valid(_form_path_edit):
			_form_path_edit.text = path
		dlg.queue_free()
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	_host_plugin.get_editor_interface().get_base_control().add_child(dlg)
	dlg.popup_centered(Vector2i(700, 500))

func _on_form_export() -> void:
	var form_path: String = _form_path_edit.text.strip_edges() if is_instance_valid(_form_path_edit) else ""
	if form_path.is_empty():
		_log("[color=#ff5555]✗ No form file selected. Use the 📂 button to browse.[/color]")
		return

	if not FileAccess.file_exists(form_path):
		_log("[color=#ff5555]✗ File not found: " + form_path + "[/color]")
		return

	_log("[color=#88bb88]📋 Exporting form to HTML…[/color]")
	_log("  Source: " + form_path)

	# Gather options
	var options := {
		"title": _form_title_edit.text if is_instance_valid(_form_title_edit) and _form_title_edit.text != "" else "My App",
		"theme": _form_theme_opt.get_item_text(_form_theme_opt.selected) if is_instance_valid(_form_theme_opt) else "Modern Flat",
		"layout": _form_layout_opt.get_item_text(_form_layout_opt.selected) if is_instance_valid(_form_layout_opt) else "Responsive (flex/grid)",
		"responsive": _form_responsive_chk.button_pressed if is_instance_valid(_form_responsive_chk) else true,
		"include_js": _form_include_js_chk.button_pressed if is_instance_valid(_form_include_js_chk) else true,
	}

	# Load the Form → HTML converter
	var FormToHTML = load(WP_DIR + "vg_form_to_html.gd")
	if not FormToHTML:
		_log("[color=#ff5555]✗ Cannot load vg_form_to_html.gd[/color]")
		return

	var output_dir := "res://build/web/"
	var log_fn := Callable(self, "_log")
	var result: Dictionary = FormToHTML.export_form(form_path, output_dir, options, log_fn)

	if result.get("ok", false):
		_log("[color=#8f8]✓ Form exported! Files are in " + output_dir + "[/color]")
		_log("  → " + result.get("html_file", ""))
		if result.has("css_file"):
			_log("  → " + result.get("css_file", ""))
		_status_label.text = "  ✅ Form exported to " + output_dir
	else:
		_log("[color=#ff5555]✗ Export failed: " + result.get("error", "unknown") + "[/color]")

	# Trigger filesystem scan
	if Engine.is_editor_hint():
		var efs = EditorInterface.get_resource_filesystem()
		if efs:
			efs.scan()


# ─── Game Export ─────────────────────────────────────────────

func _on_game_publish() -> void:
	_log("[color=#5577cc]🎮 Publishing game to web…[/color]")

	# Load the game web export backend
	var WebExport = load(WP_DIR + "vg_web_export.gd")
	if not WebExport:
		_log("[color=#ff5555]✗ Cannot load vg_web_export.gd[/color]")
		return

	var config = WebExport.WebConfig.new()
	config.game_title       = _game_title_edit.text if is_instance_valid(_game_title_edit) and _game_title_edit.text != "" else "My Game"
	config.bg_color         = _game_bg_btn.color if is_instance_valid(_game_bg_btn) else Color.html("#0d0d14")
	config.loading_style    = _game_loading_opt.get_item_text(_game_loading_opt.selected) if is_instance_valid(_game_loading_opt) else "Bar"
	config.loading_color    = _game_loading_color_btn.color if is_instance_valid(_game_loading_color_btn) else Color.html("#ffd159")
	config.quality          = _game_quality_opt.get_item_text(_game_quality_opt.selected) if is_instance_valid(_game_quality_opt) else "High"
	config.scale_mode       = _game_scale_opt.get_item_text(_game_scale_opt.selected) if is_instance_valid(_game_scale_opt) else "Fit"
	config.fullscreen_button = _game_fullscreen_chk.button_pressed if is_instance_valid(_game_fullscreen_chk) else true
	config.right_click_menu = _game_rightclick_chk.button_pressed if is_instance_valid(_game_rightclick_chk) else true
	config.show_watermark   = _game_watermark_chk.button_pressed if is_instance_valid(_game_watermark_chk) else true
	config.canvas_width     = int(_game_width_spin.value) if is_instance_valid(_game_width_spin) else 1280
	config.canvas_height    = int(_game_height_spin.value) if is_instance_valid(_game_height_spin) else 720
	config.embed_ready      = _game_embed_chk.button_pressed if is_instance_valid(_game_embed_chk) else true
	config.splash_enabled   = _game_splash_chk.button_pressed if is_instance_valid(_game_splash_chk) else true
	config.description      = _game_desc_edit.text if is_instance_valid(_game_desc_edit) else ""

	var output_dir := "res://build/web/"
	var log_fn := Callable(self, "_log")
	var result: Dictionary = WebExport.publish_to_web(config, output_dir, false, log_fn)

	if result.get("ok", false):
		_log("[color=#8f8]🌐 Game published! Files are in " + output_dir + "[/color]")
		_log("  Deploy: upload the entire folder to any web server")
		_log("  Preview: cd build/web/ && python3 -m http.server 8000")
		_status_label.text = "  ✅ Game published to " + output_dir
	else:
		_log("[color=#ff5555]✗ Publish failed[/color]")

	# Trigger filesystem scan
	if Engine.is_editor_hint():
		var efs = EditorInterface.get_resource_filesystem()
		if efs:
			efs.scan()


## Public API — called by AGCK's Build tab when Target = Web.
## Accepts the same web_cfg Dictionary that AGCK previously used internally.
func publish_game_from_config(web_cfg: Dictionary, log_fn: Callable = Callable()) -> Dictionary:
	var WebExport = load(WP_DIR + "vg_web_export.gd")
	if not WebExport:
		return {"ok": false, "error": "Cannot load vg_web_export.gd"}

	var config = WebExport.WebConfig.new()
	config.game_title       = web_cfg.get("game_title", "My Game")
	config.bg_color         = web_cfg.get("bg_color", "#0d0d14")
	config.loading_style    = web_cfg.get("loading_style", "Bar")
	config.loading_color    = web_cfg.get("loading_color", "#ffd159")
	config.quality          = web_cfg.get("quality", "High")
	config.scale_mode       = web_cfg.get("scale_mode", "Fit")
	config.fullscreen_button = web_cfg.get("fullscreen_button", true)
	config.right_click_menu = web_cfg.get("right_click_menu", true)
	config.show_watermark   = web_cfg.get("show_watermark", true)
	config.canvas_width     = web_cfg.get("canvas_width", 1280)
	config.canvas_height    = web_cfg.get("canvas_height", 720)
	config.embed_ready      = web_cfg.get("embed_ready", true)
	config.splash_enabled   = web_cfg.get("splash_enabled", true)
	config.description      = web_cfg.get("description", "")

	var output_dir := "res://build/web/"
	return WebExport.publish_to_web(config, output_dir, false, log_fn)


# ─── Settings Persistence ───────────────────────────────────

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		_settings = json.data if json.data is Dictionary else {}
	file.close()

	# Restore form settings
	if is_instance_valid(_form_path_edit) and _settings.has("form_path"):
		_form_path_edit.text = _settings["form_path"]
	if is_instance_valid(_form_title_edit) and _settings.has("form_title"):
		_form_title_edit.text = _settings["form_title"]
	if is_instance_valid(_form_theme_opt) and _settings.has("form_theme"):
		var idx: int = _find_option_idx(_form_theme_opt, _settings["form_theme"])
		if idx >= 0:
			_form_theme_opt.selected = idx

	# Restore game settings
	if is_instance_valid(_game_title_edit) and _settings.has("game_title"):
		_game_title_edit.text = _settings["game_title"]
	if is_instance_valid(_game_width_spin) and _settings.has("canvas_width"):
		_game_width_spin.value = _settings["canvas_width"]
	if is_instance_valid(_game_height_spin) and _settings.has("canvas_height"):
		_game_height_spin.value = _settings["canvas_height"]

func _save_settings() -> void:
	_settings["form_path"] = _form_path_edit.text if is_instance_valid(_form_path_edit) else ""
	_settings["form_title"] = _form_title_edit.text if is_instance_valid(_form_title_edit) else ""
	_settings["form_theme"] = _form_theme_opt.get_item_text(_form_theme_opt.selected) if is_instance_valid(_form_theme_opt) else "Modern Flat"
	_settings["game_title"] = _game_title_edit.text if is_instance_valid(_game_title_edit) else "My Game"
	_settings["canvas_width"] = int(_game_width_spin.value) if is_instance_valid(_game_width_spin) else 1280
	_settings["canvas_height"] = int(_game_height_spin.value) if is_instance_valid(_game_height_spin) else 720

	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_settings, "\t"))
		file.close()

func _on_cleanup() -> void:
	_save_settings()


# ─── Helpers ─────────────────────────────────────────────────

func _ls(size: int, color: Color) -> LabelSettings:
	var s = LabelSettings.new()
	s.font_size = size
	s.font_color = color
	return s

func _add_label(parent: Control, text: String, tip: String = "") -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.label_settings = _ls(11, DIM)
	lbl.tooltip_text = tip
	parent.add_child(lbl)

func _styled_button(text: String, color: Color, min_size: Vector2 = Vector2(200, 36)) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 14)
	btn.custom_minimum_size = min_size
	var s = StyleBoxFlat.new()
	s.bg_color = Color(color.r * 0.6, color.g * 0.6, color.b * 0.6)
	s.set_corner_radius_all(8)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", s)
	var h = s.duplicate()
	h.bg_color = Color(color.r * 0.75, color.g * 0.75, color.b * 0.75)
	btn.add_theme_stylebox_override("hover", h)
	var p = s.duplicate()
	p.bg_color = Color(color.r * 0.45, color.g * 0.45, color.b * 0.45)
	btn.add_theme_stylebox_override("pressed", p)
	btn.add_theme_color_override("font_color", WHITE)
	btn.add_theme_color_override("font_hover_color", WHITE)
	btn.add_theme_color_override("font_pressed_color", WHITE)
	return btn

func _find_option_idx(opt: OptionButton, text: String) -> int:
	for i in range(opt.item_count):
		if opt.get_item_text(i) == text:
			return i
	return -1

func _log(bbcode: String) -> void:
	if is_instance_valid(_log_output):
		_log_output.append_text(bbcode + "\n")
	else:
		print("[WebPublish] ", bbcode.replace("[color=", "").replace("[/color]", ""))
