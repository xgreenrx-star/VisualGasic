@tool
## AGCK Game Builder — build / preview dashboard
##
## Big action buttons with build log output panel.
extends VBoxContainer

signal build_requested()
signal preview_requested()
signal template_requested(template_name: String)
signal web_publish_requested(web_config: Dictionary)

# ─── Theme ───────────────────────────────────────────────────
const BG_COLOR   = Color(0.13, 0.13, 0.16)
const HEADER_BG  = Color(0.10, 0.10, 0.13)
const CARD_BG    = Color(0.15, 0.16, 0.20)
const WHITE      = Color(1.0, 1.0, 1.0)
const LABEL_CLR  = Color(0.88, 0.86, 0.80)
const ACCENT     = Color(1.0, 0.82, 0.35)
const DIM        = Color(0.50, 0.50, 0.55)
const GREEN      = Color(0.30, 0.80, 0.35)
const BLUE       = Color(0.35, 0.55, 0.95)
const RED        = Color(0.85, 0.25, 0.25)

# ─── Data ────────────────────────────────────────────────────
var build_data: Dictionary = {}

# ─── UI Refs ─────────────────────────────────────────────────
var _log_output: RichTextLabel = null
var _target_opt: OptionButton = null
var _mode_opt: OptionButton = null
var _start_level_opt: OptionButton = null
var _path_edit: LineEdit = null
var _debug_chk: CheckButton = null
var _auto_run_chk: CheckButton = null

# ─── Web Delegation Panel (web export moved to Web Publish plugin) ──
var _web_panel: PanelContainer = null


func _ls(size: int, color: Color) -> LabelSettings:
	var s = LabelSettings.new()
	s.font_size = size
	s.font_color = color
	return s


func _style_option(opt: OptionButton) -> void:
	var nb = StyleBoxFlat.new()
	nb.bg_color = Color(0.18, 0.18, 0.22)
	nb.set_corner_radius_all(3)
	nb.content_margin_left = 6
	nb.content_margin_right = 6
	nb.content_margin_top = 3
	nb.content_margin_bottom = 3
	opt.add_theme_stylebox_override("normal", nb)
	var hb = nb.duplicate()
	hb.bg_color = Color(0.22, 0.22, 0.28)
	opt.add_theme_stylebox_override("hover", hb)
	opt.add_theme_stylebox_override("pressed", hb)
	opt.add_theme_stylebox_override("focus", hb)
	opt.add_theme_color_override("font_color", LABEL_CLR)
	opt.add_theme_color_override("font_hover_color", WHITE)
	opt.add_theme_color_override("font_pressed_color", WHITE)
	opt.add_theme_color_override("font_focus_color", LABEL_CLR)
	# Dark popup — OPAQUE window (transparent=true breaks Linux X11 compositors)
	# See POPUP_THEME_FIX.md for the full explanation.
	var popup := opt.get_popup()
	_apply_dark_popup(popup)
	if not popup.has_meta("_agck_popup_styled"):
		popup.set_meta("_agck_popup_styled", true)
		popup.about_to_popup.connect(func():
			_apply_dark_popup(popup)
			_apply_dark_popup.call_deferred(popup)
		)
		popup.visibility_changed.connect(func():
			if popup.visible:
				_apply_dark_popup(popup)
		)


## Linux X11 popup fix — DO NOT use transparent viewports for popups.
## Transparent ARGB visuals cause font rendering to break on X11 compositors
## (text becomes invisible or unreadable). Instead, use an opaque window with
## a dark Theme covering PopupMenu + Window + Panel type names, plus direct
## theme_override calls for highest priority.
func _apply_dark_popup(popup: PopupMenu) -> void:
	if not is_instance_valid(popup):
		return
	popup.transparent = false
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.15, 0.15, 0.19, 1.0)
	ps.set_corner_radius_all(0)
	ps.content_margin_left = 6; ps.content_margin_right = 6
	ps.content_margin_top = 4;  ps.content_margin_bottom = 4
	ps.border_width_bottom = 1; ps.border_width_top = 1
	ps.border_width_left = 1;   ps.border_width_right = 1
	ps.border_color = Color(0.30, 0.30, 0.35)
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color(0.25, 0.35, 0.55)
	hs.set_corner_radius_all(3)
	hs.content_margin_left = 6; hs.content_margin_right = 6
	hs.content_margin_top = 2;  hs.content_margin_bottom = 2
	var t := Theme.new()
	for type_name in ["PopupMenu", "PopupPanel", "Panel", "Control", "Window"]:
		t.set_stylebox("panel", type_name, ps)
	t.set_stylebox("hover", "PopupMenu", hs)
	t.set_color("font_color", "PopupMenu", LABEL_CLR)
	t.set_color("font_hover_color", "PopupMenu", WHITE)
	t.set_color("font_disabled_color", "PopupMenu", DIM)
	t.set_color("font_separator_color", "PopupMenu", DIM)
	t.set_color("font_accelerator_color", "PopupMenu", DIM)
	t.set_color("font_outline_color", "PopupMenu", Color.TRANSPARENT)
	popup.theme = t
	popup.add_theme_stylebox_override("panel", ps)
	popup.add_theme_stylebox_override("hover", hs)
	popup.add_theme_color_override("font_color", LABEL_CLR)
	popup.add_theme_color_override("font_hover_color", WHITE)
	popup.add_theme_color_override("font_disabled_color", DIM)
	popup.add_theme_color_override("font_separator_color", DIM)
	popup.add_theme_color_override("font_accelerator_color", DIM)
	popup.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	for c in popup.get_children(true):
		if c is Control:
			c.add_theme_stylebox_override("panel", ps)
			c.queue_redraw()


func _ready() -> void:
	_init_data()
	_build_ui()


func _init_data() -> void:
	build_data = {
		"target": "Desktop",
		"screen_mode": "Windowed",
		"output_path": "res://build/",
		"debug": true,
		"auto_run": true,
		"splash_enabled": true,
		"splash_duration": 2.0,
		"compress_assets": false,
		"start_level": 1,
		# Web-specific options (Flash-successor features)
		"web_loading_style": "Bar",
		"web_quality": "High",
		"web_scale_mode": "Fit",
		"web_bg_color": "#0d0d14",
		"web_loading_color": "#ffd159",
		"web_fullscreen_button": true,
		"web_right_click_menu": true,
		"web_watermark": true,
		"web_embed_ready": true,
		"web_splash_enabled": true,
		"web_description": "",
	}


func _build_ui() -> void:
	add_theme_constant_override("separation", 0)

	# ══════════════════════════════════════════════════════════
	# HEADER
	# ══════════════════════════════════════════════════════════
	var header = PanelContainer.new()
	var h_style = StyleBoxFlat.new()
	h_style.bg_color = HEADER_BG
	h_style.content_margin_left = 10
	h_style.content_margin_right = 10
	h_style.content_margin_top = 6
	h_style.content_margin_bottom = 6
	header.add_theme_stylebox_override("panel", h_style)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(header)

	var h_hbox = HBoxContainer.new()
	h_hbox.add_theme_constant_override("separation", 8)
	header.add_child(h_hbox)

	var title = Label.new()
	title.text = "🚀 Build & Play"
	title.label_settings = _ls(14, ACCENT)
	h_hbox.add_child(title)

	var spc = Control.new()
	spc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_hbox.add_child(spc)

	var hint = Label.new()
	hint.text = "Build your game or launch a preview"
	hint.label_settings = _ls(10, DIM)
	h_hbox.add_child(hint)

	# ══════════════════════════════════════════════════════════
	# ACTION BUTTONS — big, colorful, center stage
	# ══════════════════════════════════════════════════════════
	var action_panel = PanelContainer.new()
	var ap_style = StyleBoxFlat.new()
	ap_style.bg_color = Color(0.09, 0.09, 0.11)
	ap_style.content_margin_left = 20
	ap_style.content_margin_right = 20
	ap_style.content_margin_top = 16
	ap_style.content_margin_bottom = 16
	action_panel.add_theme_stylebox_override("panel", ap_style)
	action_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(action_panel)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 16)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	action_panel.add_child(btn_hbox)

	# ▶ PLAY button
	var play_btn = Button.new()
	play_btn.text = "▶  PLAY PREVIEW"
	play_btn.add_theme_font_size_override("font_size", 16)
	play_btn.custom_minimum_size = Vector2(200, 52)
	play_btn.pressed.connect(_on_play)
	var play_s = StyleBoxFlat.new()
	play_s.bg_color = BLUE
	play_s.set_corner_radius_all(8)
	play_s.content_margin_left = 16
	play_s.content_margin_right = 16
	play_s.content_margin_top = 8
	play_s.content_margin_bottom = 8
	play_btn.add_theme_stylebox_override("normal", play_s)
	var play_h = play_s.duplicate()
	play_h.bg_color = BLUE.lightened(0.15)
	play_btn.add_theme_stylebox_override("hover", play_h)
	var play_p = play_s.duplicate()
	play_p.bg_color = BLUE.darkened(0.2)
	play_btn.add_theme_stylebox_override("pressed", play_p)
	play_btn.add_theme_color_override("font_color", WHITE)
	play_btn.add_theme_color_override("font_hover_color", WHITE)
	play_btn.add_theme_color_override("font_pressed_color", WHITE)
	btn_hbox.add_child(play_btn)

	# 🔨 BUILD button
	var build_btn = Button.new()
	build_btn.text = "🔨  BUILD GAME"
	build_btn.add_theme_font_size_override("font_size", 16)
	build_btn.custom_minimum_size = Vector2(200, 52)
	build_btn.pressed.connect(_on_build)
	var build_s = StyleBoxFlat.new()
	build_s.bg_color = GREEN
	build_s.set_corner_radius_all(8)
	build_s.content_margin_left = 16
	build_s.content_margin_right = 16
	build_s.content_margin_top = 8
	build_s.content_margin_bottom = 8
	build_btn.add_theme_stylebox_override("normal", build_s)
	var build_h = build_s.duplicate()
	build_h.bg_color = GREEN.lightened(0.15)
	build_btn.add_theme_stylebox_override("hover", build_h)
	var build_p = build_s.duplicate()
	build_p.bg_color = GREEN.darkened(0.2)
	build_btn.add_theme_stylebox_override("pressed", build_p)
	build_btn.add_theme_color_override("font_color", WHITE)
	build_btn.add_theme_color_override("font_hover_color", WHITE)
	build_btn.add_theme_color_override("font_pressed_color", WHITE)
	btn_hbox.add_child(build_btn)

	# ══════════════════════════════════════════════════════════
	# PROJECT TEMPLATES — one-click starter kits
	# ══════════════════════════════════════════════════════════
	var tmpl_panel = PanelContainer.new()
	var tp_style = StyleBoxFlat.new()
	tp_style.bg_color = Color(0.11, 0.11, 0.14)
	tp_style.content_margin_left = 12
	tp_style.content_margin_right = 12
	tp_style.content_margin_top = 6
	tp_style.content_margin_bottom = 6
	tmpl_panel.add_theme_stylebox_override("panel", tp_style)
	tmpl_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(tmpl_panel)

	var tmpl_vbox = VBoxContainer.new()
	tmpl_vbox.add_theme_constant_override("separation", 4)
	tmpl_panel.add_child(tmpl_vbox)

	var tmpl_title = Label.new()
	tmpl_title.text = "📋 Quick Start Templates"
	tmpl_title.label_settings = _ls(11, ACCENT)
	tmpl_vbox.add_child(tmpl_title)

	var tmpl_hbox = HBoxContainer.new()
	tmpl_hbox.add_theme_constant_override("separation", 8)
	tmpl_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tmpl_vbox.add_child(tmpl_hbox)

	var templates = [
		{"name": "Platformer", "icon": "🏃", "color": Color(0.35, 0.55, 0.95), "tip": "Side-scrolling platformer with player, enemies, coins"},
		{"name": "Space Shooter", "icon": "🚀", "color": Color(0.85, 0.30, 0.30), "tip": "Vertical scrolling shooter with bullets and enemy waves"},
		{"name": "Maze Game", "icon": "🧩", "color": Color(0.30, 0.75, 0.30), "tip": "Top-down maze with keys, doors, and collectibles"},
		{"name": "Top-Down RPG", "icon": "⚔️", "color": Color(0.55, 0.35, 0.75), "tip": "Top-down adventure with hero, NPCs, monsters, treasure"},
		{"name": "Side Shmup", "icon": "✈️", "color": Color(0.75, 0.55, 0.20), "tip": "Horizontal scrolling shoot-'em-up"},
		{"name": "Match-3", "icon": "💎", "color": Color(0.95, 0.55, 0.85), "tip": "Grid-aligned puzzle with collectible gems"},
		{"name": "Asteroids", "icon": "☄️", "color": Color(0.45, 0.45, 0.55), "tip": "Score-attack arcade with drifting hazards"},
		{"name": "Endless Runner", "icon": "🏁", "color": Color(0.30, 0.85, 0.75), "tip": "Auto-scrolling runner with obstacles to dodge"},
	]
	for tmpl in templates:
		var tbtn = Button.new()
		tbtn.text = tmpl["icon"] + " " + tmpl["name"]
		tbtn.tooltip_text = tmpl["tip"]
		tbtn.add_theme_font_size_override("font_size", 12)
		tbtn.custom_minimum_size = Vector2(140, 34)
		var ts = StyleBoxFlat.new()
		ts.bg_color = tmpl["color"].darkened(0.3)
		ts.set_corner_radius_all(6)
		ts.content_margin_left = 10; ts.content_margin_right = 10
		ts.content_margin_top = 4;   ts.content_margin_bottom = 4
		tbtn.add_theme_stylebox_override("normal", ts)
		var th = ts.duplicate()
		th.bg_color = tmpl["color"].darkened(0.1)
		tbtn.add_theme_stylebox_override("hover", th)
		tbtn.add_theme_color_override("font_color", WHITE)
		tbtn.add_theme_color_override("font_hover_color", WHITE)
		var tname: String = tmpl["name"]
		tbtn.pressed.connect(func(): template_requested.emit(tname))
		tmpl_hbox.add_child(tbtn)

	# ══════════════════════════════════════════════════════════
	# BUILD OPTIONS — compact card
	# ══════════════════════════════════════════════════════════
	var opts_panel = PanelContainer.new()
	var op_style = StyleBoxFlat.new()
	op_style.bg_color = CARD_BG
	op_style.set_corner_radius_all(6)
	op_style.content_margin_left = 12
	op_style.content_margin_right = 12
	op_style.content_margin_top = 8
	op_style.content_margin_bottom = 8
	opts_panel.add_theme_stylebox_override("panel", op_style)
	opts_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(opts_panel)

	var opts_vbox = VBoxContainer.new()
	opts_vbox.add_theme_constant_override("separation", 4)
	opts_panel.add_child(opts_vbox)

	var opts_title = Label.new()
	opts_title.text = "Build Options"
	opts_title.label_settings = _ls(12, ACCENT)
	opts_vbox.add_child(opts_title)
	opts_vbox.add_child(HSeparator.new())

	var opts_grid = GridContainer.new()
	opts_grid.columns = 4
	opts_grid.add_theme_constant_override("h_separation", 12)
	opts_grid.add_theme_constant_override("v_separation", 4)
	opts_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opts_vbox.add_child(opts_grid)

	# Target
	var t_lbl = Label.new()
	t_lbl.text = "Target:"
	t_lbl.label_settings = _ls(11, DIM)
	opts_grid.add_child(t_lbl)
	_target_opt = OptionButton.new()
	_target_opt.add_theme_font_size_override("font_size", 11)
	for t in ["Desktop", "Web", "Mobile", "Console"]:
		_target_opt.add_item(t)
	_target_opt.item_selected.connect(func(i): build_data["target"] = _target_opt.get_item_text(i))
	opts_grid.add_child(_target_opt)
	_style_option(_target_opt)

	# Screen Mode
	var m_lbl = Label.new()
	m_lbl.text = "Screen:"
	m_lbl.label_settings = _ls(11, DIM)
	opts_grid.add_child(m_lbl)
	_mode_opt = OptionButton.new()
	_mode_opt.add_theme_font_size_override("font_size", 11)
	for m in ["Windowed", "Fullscreen", "Borderless"]:
		_mode_opt.add_item(m)
	_mode_opt.item_selected.connect(func(i): build_data["screen_mode"] = _mode_opt.get_item_text(i))
	opts_grid.add_child(_mode_opt)
	_style_option(_mode_opt)

	# Output Path
	var p_lbl = Label.new()
	p_lbl.text = "Output:"
	p_lbl.label_settings = _ls(11, DIM)
	opts_grid.add_child(p_lbl)
	_path_edit = LineEdit.new()
	_path_edit.text = build_data.get("output_path", "res://build/")
	_path_edit.add_theme_font_size_override("font_size", 11)
	_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_edit.text_changed.connect(func(t): build_data["output_path"] = t)
	opts_grid.add_child(_path_edit)

	# Start Level
	var sl_lbl = Label.new()
	sl_lbl.text = "Start Level:"
	sl_lbl.label_settings = _ls(11, DIM)
	opts_grid.add_child(sl_lbl)
	_start_level_opt = OptionButton.new()
	_start_level_opt.add_theme_font_size_override("font_size", 11)
	_start_level_opt.add_item("Level 1")
	_start_level_opt.item_selected.connect(func(i): build_data["start_level"] = i + 1)
	opts_grid.add_child(_start_level_opt)
	_style_option(_start_level_opt)

	# Debug + Auto-run
	_debug_chk = CheckButton.new()
	_debug_chk.text = "Debug"
	_debug_chk.add_theme_font_size_override("font_size", 11)
	_debug_chk.button_pressed = build_data.get("debug", true)
	_debug_chk.toggled.connect(func(v): build_data["debug"] = v)
	opts_grid.add_child(_debug_chk)
	_auto_run_chk = CheckButton.new()
	_auto_run_chk.text = "Auto-Run"
	_auto_run_chk.add_theme_font_size_override("font_size", 11)
	_auto_run_chk.button_pressed = build_data.get("auto_run", true)
	_auto_run_chk.toggled.connect(func(v): build_data["auto_run"] = v)
	opts_grid.add_child(_auto_run_chk)

	# ══════════════════════════════════════════════════════════
	# WEB DELEGATION — web export now lives in the Web Publish plugin
	# Shows only when target is "Web"
	# ══════════════════════════════════════════════════════════
	_web_panel = PanelContainer.new()
	var wp_style = StyleBoxFlat.new()
	wp_style.bg_color = Color(0.12, 0.14, 0.20)
	wp_style.set_corner_radius_all(6)
	wp_style.border_width_top = 2
	wp_style.border_color = Color(0.35, 0.55, 0.95)
	wp_style.content_margin_left = 16
	wp_style.content_margin_right = 16
	wp_style.content_margin_top = 12
	wp_style.content_margin_bottom = 12
	_web_panel.add_theme_stylebox_override("panel", wp_style)
	_web_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_web_panel.visible = (build_data.get("target", "Desktop") == "Web")
	add_child(_web_panel)

	var web_vbox = VBoxContainer.new()
	web_vbox.add_theme_constant_override("separation", 8)
	_web_panel.add_child(web_vbox)

	var web_title = Label.new()
	web_title.text = "🌐 Web Publishing"
	web_title.label_settings = _ls(13, Color(0.35, 0.55, 0.95))
	web_vbox.add_child(web_title)

	var web_info = Label.new()
	web_info.text = "Web export is now handled by the standalone Web Publish plugin.\nClick the 🌐 Web Publish button in the toolbar, or use Quick Publish below."
	web_info.label_settings = _ls(11, DIM)
	web_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	web_vbox.add_child(web_info)

	web_vbox.add_child(HSeparator.new())

	# Quick-publish button (delegates to web_publish plugin backend)
	var pub_hbox = HBoxContainer.new()
	pub_hbox.add_theme_constant_override("separation", 12)
	pub_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	web_vbox.add_child(pub_hbox)

	var pub_btn = Button.new()
	pub_btn.text = "🌐  QUICK PUBLISH TO WEB"
	pub_btn.add_theme_font_size_override("font_size", 14)
	pub_btn.custom_minimum_size = Vector2(260, 42)
	pub_btn.tooltip_text = "Publish with default web settings via the Web Publish plugin"
	pub_btn.pressed.connect(_on_web_publish)
	var pub_s = StyleBoxFlat.new()
	pub_s.bg_color = Color(0.20, 0.40, 0.80)
	pub_s.set_corner_radius_all(8)
	pub_s.content_margin_left = 16
	pub_s.content_margin_right = 16
	pub_s.content_margin_top = 6
	pub_s.content_margin_bottom = 6
	pub_btn.add_theme_stylebox_override("normal", pub_s)
	var pub_h = pub_s.duplicate()
	pub_h.bg_color = Color(0.25, 0.50, 0.95)
	pub_btn.add_theme_stylebox_override("hover", pub_h)
	var pub_p = pub_s.duplicate()
	pub_p.bg_color = Color(0.15, 0.30, 0.65)
	pub_btn.add_theme_stylebox_override("pressed", pub_p)
	pub_btn.add_theme_color_override("font_color", WHITE)
	pub_btn.add_theme_color_override("font_hover_color", WHITE)
	pub_btn.add_theme_color_override("font_pressed_color", WHITE)
	pub_hbox.add_child(pub_btn)

	var pub_hint = Label.new()
	pub_hint.text = "Uses default settings — for full control\nuse the 🌐 Web Publish plugin"
	pub_hint.label_settings = _ls(10, DIM)
	pub_hbox.add_child(pub_hint)

	# Hook target change to show/hide web panel
	_target_opt.item_selected.connect(func(i): _toggle_web_panel(_target_opt.get_item_text(i) == "Web"))

	# ══════════════════════════════════════════════════════════
	# BUILD LOG — fills remaining space
	# ══════════════════════════════════════════════════════════
	var log_panel = PanelContainer.new()
	var lp_style = StyleBoxFlat.new()
	lp_style.bg_color = Color(0.06, 0.06, 0.08)
	lp_style.set_corner_radius_all(4)
	lp_style.content_margin_left = 8
	lp_style.content_margin_right = 8
	lp_style.content_margin_top = 6
	lp_style.content_margin_bottom = 6
	log_panel.add_theme_stylebox_override("panel", lp_style)
	log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(log_panel)

	var log_vbox = VBoxContainer.new()
	log_vbox.add_theme_constant_override("separation", 4)
	log_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_panel.add_child(log_vbox)

	var log_hdr = HBoxContainer.new()
	log_hdr.add_theme_constant_override("separation", 8)
	log_vbox.add_child(log_hdr)
	var log_title = Label.new()
	log_title.text = "📋 Build Log"
	log_title.label_settings = _ls(11, DIM)
	log_hdr.add_child(log_title)
	var clear_btn = Button.new()
	clear_btn.text = "Clear"
	clear_btn.add_theme_font_size_override("font_size", 10)
	clear_btn.pressed.connect(func(): _log_output.clear())
	log_hdr.add_child(clear_btn)

	_log_output = RichTextLabel.new()
	_log_output.bbcode_enabled = true
	_log_output.scroll_following = true
	_log_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_output.add_theme_font_size_override("normal_font_size", 11)
	log_vbox.add_child(_log_output)

	log_msg("[color=#aaa]AGCK Build System ready.[/color]")


# ─── Actions ─────────────────────────────────────────────────

func _on_play() -> void:
	log_msg("[color=#5599ff]▶ Starting preview build…[/color]")
	preview_requested.emit()

func _on_build() -> void:
	log_msg("[color=#44cc55]🔨 Starting full build…[/color]")
	build_requested.emit()

func _toggle_web_panel(show: bool) -> void:
	if is_instance_valid(_web_panel):
		_web_panel.visible = show

func _on_web_publish() -> void:
	log_msg("[color=#5577cc]🌐 Publishing to web…[/color]")
	var web_cfg := {
		"game_title":       build_data.get("game_title", "My Game"),
		"bg_color":         build_data.get("web_bg_color", "#0d0d14"),
		"loading_style":    build_data.get("web_loading_style", "Bar"),
		"loading_color":    build_data.get("web_loading_color", "#ffd159"),
		"quality":          build_data.get("web_quality", "High"),
		"scale_mode":       build_data.get("web_scale_mode", "Fit"),
		"fullscreen_button": build_data.get("web_fullscreen_button", true),
		"right_click_menu": build_data.get("web_right_click_menu", true),
		"show_watermark":   build_data.get("web_watermark", true),
		"embed_ready":      build_data.get("web_embed_ready", true),
		"splash_enabled":   build_data.get("web_splash_enabled", true),
		"description":      build_data.get("web_description", ""),
		"canvas_width":     build_data.get("canvas_width", 1280),
		"canvas_height":    build_data.get("canvas_height", 720),
	}
	web_publish_requested.emit(web_cfg)


## Public: called by the plugin to forward build log messages from the backend
func log_msg(bbcode: String) -> void:
	if is_instance_valid(_log_output):
		_log_output.append_text(bbcode + "\n")


## Update the Start Level dropdown to reflect the current number of levels.
## Called by the plugin when levels change.
func update_level_count(count: int) -> void:
	if not is_instance_valid(_start_level_opt):
		return
	var current: int = build_data.get("start_level", 1)
	_start_level_opt.clear()
	for i in range(maxi(count, 1)):
		_start_level_opt.add_item("Level " + str(i + 1))
	# Restore selection (clamp to valid range)
	var sel: int = clampi(current - 1, 0, maxi(count - 1, 0))
	_start_level_opt.selected = sel
	build_data["start_level"] = sel + 1


# ─── Serialization ───────────────────────────────────────────

func get_data() -> Dictionary:
	return build_data.duplicate(true)

func set_data(data: Dictionary) -> void:
	for key in data:
		build_data[key] = data[key]
	# Restore the start_level dropdown selection
	if is_instance_valid(_start_level_opt) and _start_level_opt.item_count > 0:
		var sel: int = clampi(build_data.get("start_level", 1) - 1, 0, _start_level_opt.item_count - 1)
		_start_level_opt.selected = sel

	# Restore target dropdown
	if is_instance_valid(_target_opt):
		var targets := ["Desktop", "Web", "Mobile", "Console"]
		var tidx := targets.find(build_data.get("target", "Desktop"))
		_target_opt.selected = maxi(tidx, 0)

	# Restore web delegation panel visibility
	_toggle_web_panel(build_data.get("target", "Desktop") == "Web")
