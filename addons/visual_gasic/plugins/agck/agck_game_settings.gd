@tool
## AGCK Game Settings — streamlined essential settings
##
## Clean card-based layout with categorized settings.
extends VBoxContainer

signal settings_changed(key: String, value: Variant)

# ─── Theme ───────────────────────────────────────────────────
const BG_COLOR  = Color(0.13, 0.13, 0.16)
const HEADER_BG = Color(0.10, 0.10, 0.13)
const CARD_BG   = Color(0.15, 0.16, 0.20)
const WHITE     = Color(1.0, 1.0, 1.0)
const LABEL_CLR = Color(0.88, 0.86, 0.80)
const ACCENT    = Color(1.0, 0.82, 0.35)
const DIM       = Color(0.50, 0.50, 0.55)

# ─── Data ────────────────────────────────────────────────────
var game_data: Dictionary = {}

# ─── UI Refs ─────────────────────────────────────────────────
var _content: VBoxContainer = null
var _res_width_spin: SpinBox = null
var _res_height_spin: SpinBox = null
var _bg_color_btn: ColorPickerButton = null


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
	game_data = {
		"game_title": "My AGCK Game",
		"author": "",
		"version": "1.0",
		"gravity": 980,
		"friction": 50,
		"elasticity": 50,
		"screen_width": 640,
		"screen_height": 480,
		# Fullscreen overrides screen_width/height at runtime when true. We keep
		# the W/H values around so toggling fullscreen off restores the user's
		# windowed resolution; in builder backend we emit window/size/mode.
		"fullscreen": false,
		"background_color": "#1a1a2e",
		"lives": 3,
		"max_score": 0,
		"difficulty": "Normal",
		"joystick_enabled": true,
		"keyboard_enabled": true,
		"mouse_enabled": false,
		"touch_enabled": false,
		"music_volume": 80,
		"sfx_volume": 100,
		"fx_channels": 4,
		"start_level": 1,
		"level_order": "Sequential",
		"wrap_screen": true,
		"show_score": true,
		"show_lives": true,
		"debug_overlay": false,
		"show_fps": false,
		"auto_save": true,
		"deadly_damage": 25,
		"camera_zoom": 1.0,
		# ── Screens ──
		"game_menu_style": "Default",
		"game_menu_custom_scene": "",
		"game_over_style": "Default",
		"game_over_custom_scene": "",
		# ── Splash Screen ──
		"splash_enabled": false,
		"splash_image": "",
		"splash_duration": 3.0,
		# ── Animation Triggers ──
		"hero_death_anim": "(None)",
		"hero_hit_anim": "(None)",
		"hero_power_loss_anim": "(None)",
		"hero_item_loss_anim": "(None)",
	}


# ─── Resolution Presets ──────────────────────────────────────
const RES_PRESETS = [
	{"label": "640 × 480  (4:3)", "w": 640, "h": 480},
	{"label": "800 × 600  (4:3)", "w": 800, "h": 600},
	{"label": "1024 × 768  (4:3)", "w": 1024, "h": 768},
	{"label": "1280 × 720  (16:9 HD)", "w": 1280, "h": 720},
	{"label": "1920 × 1080  (16:9 FHD)", "w": 1920, "h": 1080},
	{"label": "Custom…", "w": 0, "h": 0},
]


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
	# header added to _content below (inside scroll) so everything scrolls

	var h_hbox = HBoxContainer.new()
	h_hbox.add_theme_constant_override("separation", 8)
	header.add_child(h_hbox)

	var title = Label.new()
	title.text = "⚙️ Game Settings"
	title.label_settings = _ls(14, ACCENT)
	h_hbox.add_child(title)

	var spc = Control.new()
	spc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_hbox.add_child(spc)

	var hint = Label.new()
	hint.text = "Configure your game's global properties"
	hint.label_settings = _ls(10, DIM)
	h_hbox.add_child(hint)

	# ══════════════════════════════════════════════════════════
	# SCROLLABLE CONTENT
	# ══════════════════════════════════════════════════════════
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)

	# Header goes inside scroll content so everything scrolls together
	_content.add_child(header)

	# Build settings cards in a 2-column grid
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(grid)

	# ── Project card
	var proj = _card("📁 Project")
	grid.add_child(proj)
	var pg = _card_body(proj)
	_row_edit(pg, "Game Title", "game_title")
	_row_edit(pg, "Author", "author")
	_row_edit(pg, "Version", "version")

	# ── Display card (resolution preset + color picker)
	var disp = _card("🖥️ Display")
	grid.add_child(disp)
	var dg = _card_body(disp)
	_row_resolution(dg)
	_row_toggle(dg, "Fullscreen", "fullscreen")
	_row_color_picker(dg, "BG Color", "background_color")

	# ── Physics card
	var phys = _card("🌍 Physics")
	grid.add_child(phys)
	var phg = _card_body(phys)
	_row_labeled_slider(phg, "Gravity", "gravity", 0, 3000, 10)
	_row_labeled_slider(phg, "Friction", "friction", 0, 100, 1, "%")
	_row_labeled_slider(phg, "Elasticity", "elasticity", 0, 100, 1, "%")

	# ── Gameplay card
	var gp = _card("🎮 Gameplay")
	grid.add_child(gp)
	var gpg = _card_body(gp)
	_row_spin(gpg, "Lives", "lives", 0, 99, 1)
	_row_spin(gpg, "Start Level", "start_level", 1, 50, 1)
	_row_option(gpg, "Level Order", "level_order", ["Sequential", "Random", "Selection"])
	_row_option(gpg, "Difficulty", "difficulty", ["Easy", "Normal", "Hard", "Custom"])
	_row_toggle(gpg, "Wrap Screen", "wrap_screen")
	_row_labeled_slider(gpg, "Deadly Dmg", "deadly_damage", 0, 200, 1, " HP")

	# ── Camera card
	var cam = _card("📷 Camera")
	grid.add_child(cam)
	var cg = _card_body(cam)
	_row_labeled_slider(cg, "Zoom", "camera_zoom", 0.25, 4.0, 0.25, "×")

	# ── Input card
	var inp = _card("🕹️ Input")
	grid.add_child(inp)
	var ig = _card_body(inp)
	_row_toggle(ig, "Keyboard", "keyboard_enabled")
	_row_toggle(ig, "Joystick", "joystick_enabled")
	_row_toggle(ig, "Mouse", "mouse_enabled")
	_row_toggle(ig, "Touch", "touch_enabled")

	# ── Audio card
	var aud = _card("🔈 Audio")
	grid.add_child(aud)
	var ag = _card_body(aud)
	_row_labeled_slider(ag, "Music Vol", "music_volume", 0, 100, 1, "%")
	_row_labeled_slider(ag, "SFX Vol", "sfx_volume", 0, 100, 1, "%")
	_row_spin(ag, "FX Channels", "fx_channels", 1, 16, 1)

	# ── HUD card
	var hud = _card("📊 HUD")
	grid.add_child(hud)
	var hg = _card_body(hud)
	_row_toggle(hg, "Show Score", "show_score")
	_row_toggle(hg, "Show Lives", "show_lives")
	_row_toggle(hg, "Debug Overlay", "debug_overlay")
	_row_toggle(hg, "Show FPS", "show_fps")
	_row_toggle(hg, "Auto Save", "auto_save")

	# ── Screens card (Game Menu & Game Over)
	var scr = _card("🖼️ Screens")
	grid.add_child(scr)
	var sg = _card_body(scr)
	_row_option(sg, "Game Menu", "game_menu_style", ["Default", "Custom", "None"])
	_row_edit(sg, "Custom Menu", "game_menu_custom_scene")
	_row_option(sg, "Game Over", "game_over_style", ["Default", "Custom"])
	_row_edit(sg, "Custom GO", "game_over_custom_scene")
	_row_toggle(sg, "Splash Screen", "splash_enabled")
	_row_edit(sg, "Splash Image", "splash_image")
	_row_spin_float(sg, "Splash Duration", "splash_duration", 0.5, 10.0, 0.5)

	# ── Animation Triggers card
	var atrg = _card("🎬 Animation Triggers")
	grid.add_child(atrg)
	var atg = _card_body(atrg)
	_row_anim_option(atg, "On Death", "hero_death_anim")
	_row_anim_option(atg, "On Hit", "hero_hit_anim")
	_row_anim_option(atg, "Power Loss", "hero_power_loss_anim")
	_row_anim_option(atg, "Item Loss", "hero_item_loss_anim")

	# ── Keyboard Shortcuts help card (read-only)
	var keys_card = _card("⌨️ Keyboard Shortcuts")
	grid.add_child(keys_card)
	var kg = _card_body(keys_card)
	var shortcuts = [
		["Ctrl + 1-6", "Switch tabs"],
		["Ctrl + Z", "Undo"],
		["Ctrl + Y", "Redo"],
		["Ctrl + S", "Save project"],
		["Delete", "Remove actor/waypoint"],
		["Right-click (sprite)", "Eyedropper"],
		["Double-click (tile)", "Edit tile"],
	]
	for pair in shortcuts:
		var kl = Label.new()
		kl.text = pair[0]
		kl.label_settings = _ls(10, ACCENT)
		kg.add_child(kl)
		var vl = Label.new()
		vl.text = pair[1]
		vl.label_settings = _ls(10, LABEL_CLR)
		kg.add_child(vl)

	# ── Reset Defaults button
	var reset_btn = Button.new()
	reset_btn.text = "Reset All Settings to Defaults"
	reset_btn.tooltip_text = "Restore every setting to its original value"
	reset_btn.add_theme_font_size_override("font_size", 12)
	var rb_s = StyleBoxFlat.new()
	rb_s.bg_color = Color(0.55, 0.25, 0.25)
	rb_s.set_corner_radius_all(4)
	rb_s.content_margin_left = 12; rb_s.content_margin_right = 12
	rb_s.content_margin_top = 6;  rb_s.content_margin_bottom = 6
	reset_btn.add_theme_stylebox_override("normal", rb_s)
	var rb_h = rb_s.duplicate()
	rb_h.bg_color = Color(0.65, 0.30, 0.30)
	reset_btn.add_theme_stylebox_override("hover", rb_h)
	reset_btn.add_theme_color_override("font_color", WHITE)
	reset_btn.pressed.connect(_on_reset_defaults)
	_content.add_child(reset_btn)


# ─── Card Helpers ────────────────────────────────────────────

func _card(title: String) -> PanelContainer:
	var pc = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	pc.add_theme_stylebox_override("panel", style)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	pc.add_child(vbox)

	var hdr = Label.new()
	hdr.text = title
	hdr.label_settings = _ls(12, ACCENT)
	vbox.add_child(hdr)

	var sep = HSeparator.new()
	vbox.add_child(sep)
	return pc


func _card_body(card: PanelContainer) -> GridContainer:
	var vbox = card.get_child(0) as VBoxContainer
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid)
	return grid


func _prop_label(text: String) -> Label:
	var l = Label.new()
	l.text = text
	l.label_settings = _ls(11, DIM)
	l.custom_minimum_size.x = 80
	return l


func _row_edit(grid: GridContainer, label: String, key: String) -> void:
	grid.add_child(_prop_label(label))
	var edit = LineEdit.new()
	edit.text = str(game_data.get(key, ""))
	edit.add_theme_font_size_override("font_size", 11)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(func(t): game_data[key] = t; settings_changed.emit(key, t))
	grid.add_child(edit)


# ─── Color Picker Row ────────────────────────────────────────
func _row_color_picker(grid: GridContainer, label: String, key: String) -> void:
	grid.add_child(_prop_label(label))
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var btn = ColorPickerButton.new()
	btn.custom_minimum_size = Vector2(40, 28)
	var hex_str = str(game_data.get(key, "#1a1a2e"))
	btn.color = Color(hex_str)
	btn.edit_alpha = false

	var hex_label = Label.new()
	hex_label.text = "  " + hex_str
	hex_label.add_theme_font_size_override("font_size", 11)
	hex_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	btn.color_changed.connect(func(c: Color):
		var h = "#" + c.to_html(false)
		game_data[key] = h
		hex_label.text = "  " + h
		settings_changed.emit(key, h)
	)

	hbox.add_child(btn)
	hbox.add_child(hex_label)
	grid.add_child(hbox)
	_bg_color_btn = btn


# ─── Resolution Preset Row ───────────────────────────────────
func _row_resolution(grid: GridContainer) -> void:
	grid.add_child(_prop_label("Resolution"))
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var opt = OptionButton.new()
	opt.add_theme_font_size_override("font_size", 11)
	for p in RES_PRESETS:
		opt.add_item(p["label"])
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(opt)
	_style_option(opt)

	# W / H spin boxes (shown always, synced from preset)
	var spin_row = HBoxContainer.new()
	spin_row.add_theme_constant_override("separation", 6)
	var lw = Label.new()
	lw.text = "W:"
	lw.add_theme_font_size_override("font_size", 11)
	spin_row.add_child(lw)
	var sw = SpinBox.new()
	sw.min_value = 160; sw.max_value = 3840; sw.step = 1
	sw.value = game_data.get("screen_width", 1280)
	sw.add_theme_font_size_override("font_size", 11)
	sw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin_row.add_child(sw)
	var lh = Label.new()
	lh.text = " H:"
	lh.add_theme_font_size_override("font_size", 11)
	spin_row.add_child(lh)
	var sh = SpinBox.new()
	sh.min_value = 120; sh.max_value = 2160; sh.step = 1
	sh.value = game_data.get("screen_height", 720)
	sh.add_theme_font_size_override("font_size", 11)
	sh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin_row.add_child(sh)
	vbox.add_child(spin_row)

	_res_width_spin = sw
	_res_height_spin = sh

	# Sync preset dropdown to current values
	_sync_resolution_preset(opt)

	# Preset selection → update spinboxes + data
	opt.item_selected.connect(func(idx):
		var p = RES_PRESETS[idx]
		if p["w"] > 0:
			sw.value = p["w"]
			sh.value = p["h"]
			game_data["screen_width"] = p["w"]
			game_data["screen_height"] = p["h"]
			settings_changed.emit("screen_width", p["w"])
			settings_changed.emit("screen_height", p["h"])
	)

	# Spinbox changes → update data + re-sync preset
	sw.value_changed.connect(func(v):
		game_data["screen_width"] = int(v)
		settings_changed.emit("screen_width", int(v))
		_sync_resolution_preset(opt)
	)
	sh.value_changed.connect(func(v):
		game_data["screen_height"] = int(v)
		settings_changed.emit("screen_height", int(v))
		_sync_resolution_preset(opt)
	)

	grid.add_child(vbox)


func _sync_resolution_preset(opt: OptionButton) -> void:
	var cw = game_data.get("screen_width", 1280)
	var ch = game_data.get("screen_height", 720)
	for i in range(RES_PRESETS.size()):
		var p = RES_PRESETS[i]
		if p["w"] == cw and p["h"] == ch:
			opt.selected = i
			return
	# No match → select "Custom…"
	opt.selected = RES_PRESETS.size() - 1


# ─── Labeled Slider Row (value readout) ──────────────────────
func _row_labeled_slider(grid: GridContainer, label: String, key: String, lo: float, hi: float, step: float, suffix: String = "") -> void:
	grid.add_child(_prop_label(label))
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sl = HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = game_data.get(key, lo)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size.x = 80

	var val_label = Label.new()
	val_label.add_theme_font_size_override("font_size", 11)
	val_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	val_label.custom_minimum_size.x = 52
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_label.text = _format_value(sl.value, step) + suffix

	sl.value_changed.connect(func(v):
		game_data[key] = v
		val_label.text = _format_value(v, step) + suffix
		settings_changed.emit(key, v)
	)

	hbox.add_child(sl)
	hbox.add_child(val_label)
	grid.add_child(hbox)


func _format_value(v: float, step: float) -> String:
	if step >= 1.0:
		return str(int(v))
	elif step >= 0.1:
		return "%.1f" % v
	else:
		return "%.2f" % v


func _row_slider(grid: GridContainer, label: String, key: String, lo: float, hi: float, step: float) -> void:
	grid.add_child(_prop_label(label))
	var sl = HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = game_data.get(key, lo)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size.x = 100
	sl.value_changed.connect(func(v): game_data[key] = v; settings_changed.emit(key, v))
	grid.add_child(sl)


func _row_spin(grid: GridContainer, label: String, key: String, lo: int, hi: int, step: int) -> void:
	grid.add_child(_prop_label(label))
	var sp = SpinBox.new()
	sp.min_value = lo
	sp.max_value = hi
	sp.step = step
	sp.value = game_data.get(key, lo)
	sp.add_theme_font_size_override("font_size", 11)
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.value_changed.connect(func(v): game_data[key] = int(v); settings_changed.emit(key, int(v)))
	grid.add_child(sp)


func _row_spin_float(grid: GridContainer, label: String, key: String, lo: float, hi: float, step: float) -> void:
	grid.add_child(_prop_label(label))
	var sp = SpinBox.new()
	sp.min_value = lo
	sp.max_value = hi
	sp.step = step
	sp.value = game_data.get(key, lo)
	sp.add_theme_font_size_override("font_size", 11)
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.suffix = "s"
	sp.value_changed.connect(func(v): game_data[key] = v; settings_changed.emit(key, v))
	grid.add_child(sp)


func _row_option(grid: GridContainer, label: String, key: String, options: Array) -> void:
	grid.add_child(_prop_label(label))
	var opt = OptionButton.new()
	opt.add_theme_font_size_override("font_size", 11)
	for o in options:
		opt.add_item(o)
	var idx = options.find(game_data.get(key, options[0]))
	opt.selected = idx if idx >= 0 else 0
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.item_selected.connect(func(i): game_data[key] = options[i]; settings_changed.emit(key, options[i]))
	grid.add_child(opt)
	_style_option(opt)


func _row_toggle(grid: GridContainer, label: String, key: String) -> void:
	grid.add_child(_prop_label(label))
	var chk = CheckButton.new()
	chk.button_pressed = game_data.get(key, false)
	chk.toggled.connect(func(v): game_data[key] = v; settings_changed.emit(key, v))
	grid.add_child(chk)


const ANIM_TRIGGER_OPTIONS = ["(None)", "Idle", "Walk", "Run", "Jump", "Fall", "Fly", "Hover", "Crouch", "Swim", "Attack", "Death", "Custom"]

func _row_anim_option(grid: GridContainer, label: String, key: String) -> void:
	grid.add_child(_prop_label(label))
	var opt = OptionButton.new()
	opt.add_theme_font_size_override("font_size", 11)
	for o in ANIM_TRIGGER_OPTIONS:
		opt.add_item(o)
	var idx = ANIM_TRIGGER_OPTIONS.find(game_data.get(key, "(None)"))
	opt.selected = idx if idx >= 0 else 0
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.item_selected.connect(func(i): game_data[key] = ANIM_TRIGGER_OPTIONS[i]; settings_changed.emit(key, ANIM_TRIGGER_OPTIONS[i]))
	grid.add_child(opt)
	_style_option(opt)


# ─── Serialization ───────────────────────────────────────────

func get_data() -> Dictionary:
	return game_data.duplicate(true)

func set_data(data: Dictionary) -> void:
	for key in data:
		game_data[key] = data[key]


func _on_reset_defaults() -> void:
	_init_data()
	# Rebuild the UI to reflect defaults
	for c in get_children():
		c.queue_free()
	_content = null
	_build_ui()
	settings_changed.emit("_all", null)
