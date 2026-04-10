@tool
## AGCK Game Settings Editor
##
## Environment editor inspired by AGCK's Environment Editor.
## Configure global game physics, screen behavior, controls, lives, and scoring.
## These settings apply to ALL levels in the game.
extends VBoxContainer

signal settings_changed(key: String, value: Variant)

# ─── Constants ───────────────────────────────────────────────
const BG_COLOR = Color(0.16, 0.16, 0.19)
const SECTION_COLOR = Color(0.22, 0.26, 0.35)
const HEADER_COLOR = Color(0.85, 0.9, 1.0)
const LABEL_COLOR = Color(0.75, 0.8, 0.85)
const VALUE_COLOR = Color(0.5, 0.85, 0.55)
const ACCENT_COLOR = Color(0.4, 0.6, 0.9)

# ─── Game Settings Data ─────────────────────────────────────
var game_data: Dictionary = {
	# Identity
	"game_title": "My AGCK Game",
	"author": "Player",
	# World / Physics
	"gravity_enabled": true,
	"gravity_direction": "down",   # up, down, left, right
	"gravity_strength": 50,        # 0..100
	"inertia_enabled": true,
	"friction": 50,                # 0..100
	"elasticity": 20,              # 0..100
	# Screen
	"screen_edge_mode": "reflect", # wrap, reflect, continual
	"screen_width": 320,
	"screen_height": 240,
	"map_width": 5,                # screens wide (continual mode)
	"map_height": 10,              # screens tall (continual mode)
	"scrolling_enabled": true,     # Modern upgrade: AGCK didn't have this!
	# Player
	"start_lives": 3,
	"max_lives": 9,
	"extra_life_score": 10000,
	"joystick_horizontal": 50,     # 0..100
	"joystick_vertical": 50,       # 0..100
	"jump_height": 50,             # 0..100
	# Display
	"actors_above_scenery": true,
	"score_color": Color(1, 1, 1),
	"bg_color": Color(0, 0, 0),
	# Effects
	"fx_channel_a_duration": 50,   # 0..100
	"fx_channel_b_duration": 50,
	"fx_channel_c_duration": 50,
	"fx_channel_d_duration": 50,
	# Players
	"max_players": 1,              # 1..4
}

# ─── UI References ───────────────────────────────────────────
var _title_edit: LineEdit = null
var _author_edit: LineEdit = null
var _scroll_area: ScrollContainer = null

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Root styling
	var bg = StyleBoxFlat.new()
	bg.bg_color = BG_COLOR
	add_theme_stylebox_override("panel", bg)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Header
	var header = Label.new()
	header.text = "🎮  GAME SETTINGS"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", HEADER_COLOR)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(header)

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	add_child(sep)

	# Scrollable content
	_scroll_area = ScrollContainer.new()
	_scroll_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_area.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll_area)

	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	_scroll_area.add_child(content)

	# ── Identity Section ──
	_add_section_header(content, "📋 IDENTITY")
	_title_edit = _add_line_edit(content, "Game Title:", game_data["game_title"], "_on_title_changed")
	_author_edit = _add_line_edit(content, "Author:", game_data["author"], "_on_author_changed")

	# ── Physics Section ──
	_add_section_header(content, "⚡ WORLD PHYSICS")
	_add_toggle(content, "Gravity:", game_data["gravity_enabled"], "_on_gravity_toggled")
	_add_option(content, "Gravity Direction:", ["down", "up", "left", "right"], game_data["gravity_direction"], "_on_gravity_dir_changed")
	_add_slider(content, "Gravity Strength:", game_data["gravity_strength"], "_on_gravity_strength_changed")
	_add_toggle(content, "Inertia:", game_data["inertia_enabled"], "_on_inertia_toggled")
	_add_slider(content, "Friction:", game_data["friction"], "_on_friction_changed")
	_add_slider(content, "Elasticity:", game_data["elasticity"], "_on_elasticity_changed")

	# ── Screen Section ──
	_add_section_header(content, "🖥️ SCREEN")
	_add_option(content, "Edge Mode:", ["wrap", "reflect", "continual"], game_data["screen_edge_mode"], "_on_edge_mode_changed")
	_add_spin(content, "Screen Width:", game_data["screen_width"], 160, 1920, "_on_screen_w_changed")
	_add_spin(content, "Screen Height:", game_data["screen_height"], 120, 1080, "_on_screen_h_changed")
	_add_spin(content, "Map Width (screens):", game_data["map_width"], 1, 50, "_on_map_w_changed")
	_add_spin(content, "Map Height (screens):", game_data["map_height"], 1, 50, "_on_map_h_changed")
	_add_toggle(content, "Scrolling:", game_data["scrolling_enabled"], "_on_scrolling_toggled")

	# ── Player Section ──
	_add_section_header(content, "🎮 PLAYER")
	_add_spin(content, "Start Lives:", game_data["start_lives"], 1, 99, "_on_start_lives_changed")
	_add_spin(content, "Max Lives:", game_data["max_lives"], 1, 99, "_on_max_lives_changed")
	_add_spin(content, "Extra Life Score:", game_data["extra_life_score"], 100, 999999, "_on_extra_life_changed")
	_add_slider(content, "Horizontal Control:", game_data["joystick_horizontal"], "_on_joy_h_changed")
	_add_slider(content, "Vertical Control:", game_data["joystick_vertical"], "_on_joy_v_changed")
	_add_slider(content, "Jump Height:", game_data["jump_height"], "_on_jump_changed")
	_add_spin(content, "Max Players:", game_data["max_players"], 1, 4, "_on_max_players_changed")

	# ── Display Section ──
	_add_section_header(content, "🎨 DISPLAY")
	_add_toggle(content, "Actors Above Scenery:", game_data["actors_above_scenery"], "_on_priority_toggled")

	# ── FX Channels ──
	_add_section_header(content, "✨ SPECIAL EFFECTS CHANNELS")
	_add_slider(content, "Channel A Duration:", game_data["fx_channel_a_duration"], "_on_fx_a_changed")
	_add_slider(content, "Channel B Duration:", game_data["fx_channel_b_duration"], "_on_fx_b_changed")
	_add_slider(content, "Channel C Duration:", game_data["fx_channel_c_duration"], "_on_fx_c_changed")
	_add_slider(content, "Channel D Duration:", game_data["fx_channel_d_duration"], "_on_fx_d_changed")


# ─── UI Builder Helpers ──────────────────────────────────────

func _add_section_header(parent: Control, text: String) -> void:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = SECTION_COLOR
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", ACCENT_COLOR)
	panel.add_child(lbl)
	parent.add_child(panel)

func _add_line_edit(parent: Control, label_text: String, initial: String, callback: String) -> LineEdit:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 140
	lbl.add_theme_color_override("font_color", LABEL_COLOR)
	lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(lbl)
	var edit = LineEdit.new()
	edit.text = initial
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", 12)
	edit.text_changed.connect(Callable(self, callback))
	row.add_child(edit)
	parent.add_child(row)
	return edit

func _add_toggle(parent: Control, label_text: String, initial: bool, callback: String) -> CheckButton:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 140
	lbl.add_theme_color_override("font_color", LABEL_COLOR)
	lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(lbl)
	var cb = CheckButton.new()
	cb.button_pressed = initial
	cb.toggled.connect(Callable(self, callback))
	row.add_child(cb)
	parent.add_child(row)
	return cb

func _add_slider(parent: Control, label_text: String, initial: int, callback: String) -> HSlider:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 140
	lbl.add_theme_color_override("font_color", LABEL_COLOR)
	lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(lbl)
	var slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 120
	slider.value_changed.connect(Callable(self, callback))
	row.add_child(slider)
	var val_lbl = Label.new()
	val_lbl.text = str(initial)
	val_lbl.custom_minimum_size.x = 32
	val_lbl.add_theme_color_override("font_color", VALUE_COLOR)
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.name = "ValueLabel"
	row.add_child(val_lbl)
	parent.add_child(row)
	return slider

func _add_option(parent: Control, label_text: String, options: Array, initial: String, callback: String) -> OptionButton:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 140
	lbl.add_theme_color_override("font_color", LABEL_COLOR)
	lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(lbl)
	var opt = OptionButton.new()
	opt.add_theme_font_size_override("font_size", 12)
	var sel_idx: int = 0
	for i in range(options.size()):
		opt.add_item(options[i])
		if options[i] == initial:
			sel_idx = i
	opt.selected = sel_idx
	opt.item_selected.connect(Callable(self, callback))
	row.add_child(opt)
	parent.add_child(row)
	return opt

func _add_spin(parent: Control, label_text: String, initial: int, min_val: int, max_val: int, callback: String) -> SpinBox:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 140
	lbl.add_theme_color_override("font_color", LABEL_COLOR)
	lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(lbl)
	var spin = SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.value = initial
	spin.add_theme_font_size_override("font_size", 12)
	spin.value_changed.connect(Callable(self, callback))
	row.add_child(spin)
	parent.add_child(row)
	return spin


# ─── Callbacks ───────────────────────────────────────────────

func _on_title_changed(new_text: String) -> void:
	game_data["game_title"] = new_text
	settings_changed.emit("game_title", new_text)

func _on_author_changed(new_text: String) -> void:
	game_data["author"] = new_text
	settings_changed.emit("author", new_text)

func _on_gravity_toggled(pressed: bool) -> void:
	game_data["gravity_enabled"] = pressed
	settings_changed.emit("gravity_enabled", pressed)

func _on_gravity_dir_changed(idx: int) -> void:
	var dirs = ["down", "up", "left", "right"]
	game_data["gravity_direction"] = dirs[idx]
	settings_changed.emit("gravity_direction", dirs[idx])

func _on_gravity_strength_changed(val: float) -> void:
	game_data["gravity_strength"] = int(val)
	settings_changed.emit("gravity_strength", int(val))

func _on_inertia_toggled(pressed: bool) -> void:
	game_data["inertia_enabled"] = pressed
	settings_changed.emit("inertia_enabled", pressed)

func _on_friction_changed(val: float) -> void:
	game_data["friction"] = int(val)
	settings_changed.emit("friction", int(val))

func _on_elasticity_changed(val: float) -> void:
	game_data["elasticity"] = int(val)
	settings_changed.emit("elasticity", int(val))

func _on_edge_mode_changed(idx: int) -> void:
	var modes = ["wrap", "reflect", "continual"]
	game_data["screen_edge_mode"] = modes[idx]
	settings_changed.emit("screen_edge_mode", modes[idx])

func _on_screen_w_changed(val: float) -> void:
	game_data["screen_width"] = int(val)
	settings_changed.emit("screen_width", int(val))

func _on_screen_h_changed(val: float) -> void:
	game_data["screen_height"] = int(val)
	settings_changed.emit("screen_height", int(val))

func _on_map_w_changed(val: float) -> void:
	game_data["map_width"] = int(val)
	settings_changed.emit("map_width", int(val))

func _on_map_h_changed(val: float) -> void:
	game_data["map_height"] = int(val)
	settings_changed.emit("map_height", int(val))

func _on_scrolling_toggled(pressed: bool) -> void:
	game_data["scrolling_enabled"] = pressed
	settings_changed.emit("scrolling_enabled", pressed)

func _on_start_lives_changed(val: float) -> void:
	game_data["start_lives"] = int(val)
	settings_changed.emit("start_lives", int(val))

func _on_max_lives_changed(val: float) -> void:
	game_data["max_lives"] = int(val)
	settings_changed.emit("max_lives", int(val))

func _on_extra_life_changed(val: float) -> void:
	game_data["extra_life_score"] = int(val)
	settings_changed.emit("extra_life_score", int(val))

func _on_joy_h_changed(val: float) -> void:
	game_data["joystick_horizontal"] = int(val)
	settings_changed.emit("joystick_horizontal", int(val))

func _on_joy_v_changed(val: float) -> void:
	game_data["joystick_vertical"] = int(val)
	settings_changed.emit("joystick_vertical", int(val))

func _on_jump_changed(val: float) -> void:
	game_data["jump_height"] = int(val)
	settings_changed.emit("jump_height", int(val))

func _on_max_players_changed(val: float) -> void:
	game_data["max_players"] = int(val)
	settings_changed.emit("max_players", int(val))

func _on_priority_toggled(pressed: bool) -> void:
	game_data["actors_above_scenery"] = pressed
	settings_changed.emit("actors_above_scenery", pressed)

func _on_fx_a_changed(val: float) -> void:
	game_data["fx_channel_a_duration"] = int(val)
	settings_changed.emit("fx_channel_a_duration", int(val))

func _on_fx_b_changed(val: float) -> void:
	game_data["fx_channel_b_duration"] = int(val)
	settings_changed.emit("fx_channel_b_duration", int(val))

func _on_fx_c_changed(val: float) -> void:
	game_data["fx_channel_c_duration"] = int(val)
	settings_changed.emit("fx_channel_c_duration", int(val))

func _on_fx_d_changed(val: float) -> void:
	game_data["fx_channel_d_duration"] = int(val)
	settings_changed.emit("fx_channel_d_duration", int(val))


# ─── Serialization ───────────────────────────────────────────

func get_data() -> Dictionary:
	return game_data.duplicate()

func set_data(data: Dictionary) -> void:
	for key in data:
		if game_data.has(key):
			game_data[key] = data[key]
	# Refresh UI would go here in a future update
