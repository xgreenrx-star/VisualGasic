@tool
## AGCK Actor Editor
##
## Define and configure game actors inspired by AGCK's Actor Editor.
## 5 actor types: Player, Drone, Missile, Sentry, Computer (AI).
## Each actor has: animation frames, collision rules, death/rebirth,
## mutate, auto-shoot, sound triggers, and special effects scripts.
extends HSplitContainer

signal actor_changed(actor_id: int)

# ─── Constants ───────────────────────────────────────────────
const BG_COLOR = Color(0.16, 0.16, 0.19)
const SECTION_COLOR = Color(0.22, 0.26, 0.35)
const HEADER_COLOR = Color(0.85, 0.9, 1.0)
const LABEL_COLOR = Color(0.75, 0.8, 0.85)
const VALUE_COLOR = Color(0.5, 0.85, 0.55)
const ACCENT_COLOR = Color(0.9, 0.6, 0.3)
const SELECTED_COLOR = Color(0.3, 0.45, 0.65)
const LIST_BG = Color(0.13, 0.13, 0.16)

const ACTOR_TYPES = ["Player", "Drone", "Missile", "Sentry", "Computer"]
const MOVEMENT_STATES = ["Stand", "Left", "Right", "Up", "Down", "Jump", "Jump Left", "Jump Right", "Fall", "Hit"]
const COLLISION_MODES = ["Kill None", "Kill Other", "Kill Player", "Kill All", "Invincible"]
const DEATH_MODES = ["Stunned", "Falling", "Both"]
const BUTTON_MODES = ["Off", "Jump", "Shoot"]
const AI_STRATEGIES = ["Open", "Maze"]

const MAX_ACTORS = 16

# ─── Actor Data ──────────────────────────────────────────────
var actors: Array = []  # Array of dictionaries
var selected_actor_idx: int = -1

# ─── UI References ───────────────────────────────────────────
var _actor_list: ItemList = null
var _detail_scroll: ScrollContainer = null
var _detail_content: VBoxContainer = null
var _name_edit: LineEdit = null
var _type_option: OptionButton = null


func _ready() -> void:
	_init_default_actors()
	_build_ui()
	if actors.size() > 0:
		_select_actor(0)


func _init_default_actors() -> void:
	actors.clear()
	# Start with a default Player and one enemy
	actors.append(_create_actor("Hero", "Player"))
	actors.append(_create_actor("Enemy 1", "Computer"))
	actors.append(_create_actor("Bullet", "Missile"))


func _create_actor(actor_name: String, actor_type: String) -> Dictionary:
	return {
		"name": actor_name,
		"type": actor_type,
		"max_speed": 50,
		# Collision
		"collision_mode": "Kill None",
		"detect_barrier": true,
		"detect_deadly": true,
		"detect_teleport": true,
		"detect_ladder": true,
		# Death
		"death_mode": "Falling",
		"rebirth": true,
		"rebirth_delay": 30,
		"end_of_level": "Normal",  # Normal, Countdown, End Level
		"mutate_on_death": false,
		"mutate_target": -1,
		# Awards
		"award_points": 100,
		"award_lives": 0,
		# Entrance
		"entrance_mode": "Immediately",  # Immediately, After Delay, Random
		"entrance_delay": 0,
		"entrance_location": "Original",  # Original, Random
		# Player-specific
		"button_mode": "Shoot",
		"fall_height": 50,
		# AI-specific
		"ai_strategy": "Open",
		"ai_iq": 50,
		# Auto-shoot
		"auto_shoot": false,
		"auto_shoot_freq": 30,
		"auto_shoot_aim": "At Player",
		# Sound effects
		"sound_bounce": "",
		"sound_death": "",
		"sound_entrance": "",
		"sound_jump": "",
		"sound_fall": "",
		"sound_move": "",
		# FX Scripts
		"fx_a_script": "None",
		"fx_b_script": "None",
		"fx_c_cue": "Off",
		"fx_d_cue": "Off",
		# Animation (stub — links to sprite editor frames)
		"animations": {},
	}


func _build_ui() -> void:
	# Left panel: Actor list
	var left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size.x = 200
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var left_bg = StyleBoxFlat.new()
	left_bg.bg_color = LIST_BG
	var left_wrap = PanelContainer.new()
	left_wrap.add_theme_stylebox_override("panel", left_bg)
	left_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var header = Label.new()
	header.text = "👾  ACTORS"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", HEADER_COLOR)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(header)

	# Actor list
	_actor_list = ItemList.new()
	_actor_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_actor_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actor_list.add_theme_font_size_override("font_size", 12)
	_actor_list.item_selected.connect(_on_actor_selected)
	left_panel.add_child(_actor_list)

	# Add/Remove buttons
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	var add_btn = Button.new()
	add_btn.text = "+ Add"
	add_btn.add_theme_font_size_override("font_size", 11)
	add_btn.pressed.connect(_on_add_actor)
	btn_row.add_child(add_btn)
	var dup_btn = Button.new()
	dup_btn.text = "⧉ Dup"
	dup_btn.add_theme_font_size_override("font_size", 11)
	dup_btn.pressed.connect(_on_dup_actor)
	btn_row.add_child(dup_btn)
	var del_btn = Button.new()
	del_btn.text = "✕ Del"
	del_btn.add_theme_font_size_override("font_size", 11)
	del_btn.pressed.connect(_on_del_actor)
	btn_row.add_child(del_btn)
	left_panel.add_child(btn_row)

	left_wrap.add_child(left_panel)
	add_child(left_wrap)

	# Right panel: Actor details
	var right_panel = PanelContainer.new()
	var right_bg = StyleBoxFlat.new()
	right_bg.bg_color = BG_COLOR
	right_panel.add_theme_stylebox_override("panel", right_bg)
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_detail_scroll = ScrollContainer.new()
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_detail_content = VBoxContainer.new()
	_detail_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_content.add_theme_constant_override("separation", 4)
	_detail_scroll.add_child(_detail_content)

	right_panel.add_child(_detail_scroll)
	add_child(right_panel)

	_refresh_actor_list()


func _refresh_actor_list() -> void:
	_actor_list.clear()
	for i in range(actors.size()):
		var a = actors[i]
		var icon = _type_icon(a["type"])
		_actor_list.add_item(icon + " " + a["name"])
	if selected_actor_idx >= 0 and selected_actor_idx < actors.size():
		_actor_list.select(selected_actor_idx)


func _type_icon(actor_type: String) -> String:
	match actor_type:
		"Player": return "🎮"
		"Drone": return "➡️"
		"Missile": return "💥"
		"Sentry": return "🛡️"
		"Computer": return "🤖"
	return "❓"


func _select_actor(idx: int) -> void:
	selected_actor_idx = idx
	_rebuild_detail_panel()


func _rebuild_detail_panel() -> void:
	# Clear old detail UI
	for child in _detail_content.get_children():
		child.queue_free()

	if selected_actor_idx < 0 or selected_actor_idx >= actors.size():
		var lbl = Label.new()
		lbl.text = "Select an actor to edit"
		lbl.add_theme_color_override("font_color", LABEL_COLOR)
		_detail_content.add_child(lbl)
		return

	var a = actors[selected_actor_idx]

	# Name
	_add_section_header(_detail_content, "📝 IDENTITY")
	_name_edit = _add_line_edit_row(_detail_content, "Name:", a["name"])
	_name_edit.text_changed.connect(_on_name_changed)

	# Type
	_type_option = OptionButton.new()
	_type_option.add_theme_font_size_override("font_size", 12)
	for t in ACTOR_TYPES:
		_type_option.add_item(t)
	_type_option.selected = ACTOR_TYPES.find(a["type"])
	_type_option.item_selected.connect(_on_type_changed)
	var type_row = HBoxContainer.new()
	type_row.add_theme_constant_override("separation", 8)
	var type_lbl = Label.new()
	type_lbl.text = "Type:"
	type_lbl.custom_minimum_size.x = 120
	type_lbl.add_theme_color_override("font_color", LABEL_COLOR)
	type_lbl.add_theme_font_size_override("font_size", 12)
	type_row.add_child(type_lbl)
	type_row.add_child(_type_option)
	_detail_content.add_child(type_row)

	# Speed
	_add_section_header(_detail_content, "💨 MOVEMENT")
	_add_slider_row(_detail_content, "Max Speed:", a["max_speed"], "_on_max_speed_changed")

	# Collision
	_add_section_header(_detail_content, "💢 COLLISION")
	_add_option_row(_detail_content, "Kill Mode:", COLLISION_MODES, a["collision_mode"], "_on_collision_changed")
	_add_toggle_row(_detail_content, "Detect Barriers:", a["detect_barrier"], "_on_detect_barrier")
	_add_toggle_row(_detail_content, "Detect Deadly:", a["detect_deadly"], "_on_detect_deadly")
	_add_toggle_row(_detail_content, "Detect Teleport:", a["detect_teleport"], "_on_detect_teleport")
	_add_toggle_row(_detail_content, "Detect Ladders:", a["detect_ladder"], "_on_detect_ladder")

	# Death
	_add_section_header(_detail_content, "💀 DEATH & REBIRTH")
	_add_option_row(_detail_content, "Death Mode:", DEATH_MODES, a["death_mode"], "_on_death_mode_changed")
	_add_toggle_row(_detail_content, "Rebirth:", a["rebirth"], "_on_rebirth_toggled")
	_add_slider_row(_detail_content, "Rebirth Delay:", a["rebirth_delay"], "_on_rebirth_delay")
	_add_spin_row(_detail_content, "Award Points:", a["award_points"], -9999, 99999, "_on_award_points")
	_add_spin_row(_detail_content, "Award Lives:", a["award_lives"], -9, 9, "_on_award_lives")

	# Player-specific
	if a["type"] == "Player":
		_add_section_header(_detail_content, "🎮 PLAYER CONTROLS")
		_add_option_row(_detail_content, "Button:", BUTTON_MODES, a["button_mode"], "_on_button_mode")
		_add_slider_row(_detail_content, "Max Fall Height:", a["fall_height"], "_on_fall_height")

	# Computer AI-specific
	if a["type"] == "Computer":
		_add_section_header(_detail_content, "🤖 AI SETTINGS")
		_add_option_row(_detail_content, "Strategy:", AI_STRATEGIES, a["ai_strategy"], "_on_ai_strategy")
		_add_slider_row(_detail_content, "IQ:", a["ai_iq"], "_on_ai_iq")

	# Auto-shoot
	_add_section_header(_detail_content, "🔫 AUTO SHOOT")
	_add_toggle_row(_detail_content, "Enabled:", a["auto_shoot"], "_on_auto_shoot_toggled")
	_add_slider_row(_detail_content, "Frequency:", a["auto_shoot_freq"], "_on_auto_shoot_freq")

	# Entrance
	_add_section_header(_detail_content, "🚪 ENTRANCE")
	_add_option_row(_detail_content, "Timing:", ["Immediately", "After Delay", "Random"], a["entrance_mode"], "_on_entrance_mode")
	_add_slider_row(_detail_content, "Delay:", a["entrance_delay"], "_on_entrance_delay")
	_add_option_row(_detail_content, "Location:", ["Original", "Random"], a["entrance_location"], "_on_entrance_loc")

	# FX Scripts
	_add_section_header(_detail_content, "✨ SPECIAL EFFECTS")
	var fx_options = ["None", "Mutate", "Invincible", "Freeze", "No Shoot", "Rev Button"]
	_add_option_row(_detail_content, "A Script:", fx_options, a["fx_a_script"], "_on_fx_a")
	_add_option_row(_detail_content, "B Script:", fx_options, a["fx_b_script"], "_on_fx_b")
	var cue_options = ["Off", "Death", "Entrance", "Bounce"]
	_add_option_row(_detail_content, "C Cue:", cue_options, a["fx_c_cue"], "_on_fx_c")
	_add_option_row(_detail_content, "D Cue:", cue_options, a["fx_d_cue"], "_on_fx_d")


# ─── UI Builder Helpers ──────────────────────────────────────

func _add_section_header(parent: Control, text: String) -> void:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = SECTION_COLOR
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", style)
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", ACCENT_COLOR)
	panel.add_child(lbl)
	parent.add_child(panel)

func _add_line_edit_row(parent: Control, label_text: String, initial: String) -> LineEdit:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 120
	lbl.add_theme_color_override("font_color", LABEL_COLOR)
	lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(lbl)
	var edit = LineEdit.new()
	edit.text = initial
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", 12)
	row.add_child(edit)
	parent.add_child(row)
	return edit

func _add_toggle_row(parent: Control, label_text: String, initial: bool, callback: String) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 120
	lbl.add_theme_color_override("font_color", LABEL_COLOR)
	lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(lbl)
	var cb = CheckButton.new()
	cb.button_pressed = initial
	cb.toggled.connect(Callable(self, callback))
	row.add_child(cb)
	parent.add_child(row)

func _add_slider_row(parent: Control, label_text: String, initial: int, callback: String) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 120
	lbl.add_theme_color_override("font_color", LABEL_COLOR)
	lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(lbl)
	var slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 100
	slider.value_changed.connect(Callable(self, callback))
	row.add_child(slider)
	var val_lbl = Label.new()
	val_lbl.text = str(initial)
	val_lbl.custom_minimum_size.x = 30
	val_lbl.add_theme_color_override("font_color", VALUE_COLOR)
	val_lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(val_lbl)
	parent.add_child(row)

func _add_option_row(parent: Control, label_text: String, options: Array, initial: String, callback: String) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 120
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

func _add_spin_row(parent: Control, label_text: String, initial: int, min_val: int, max_val: int, callback: String) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 120
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


# ─── List Callbacks ──────────────────────────────────────────

func _on_actor_selected(idx: int) -> void:
	_select_actor(idx)

func _on_add_actor() -> void:
	if actors.size() >= MAX_ACTORS:
		return
	actors.append(_create_actor("Actor " + str(actors.size() + 1), "Drone"))
	_refresh_actor_list()
	_select_actor(actors.size() - 1)
	_actor_list.select(selected_actor_idx)

func _on_dup_actor() -> void:
	if selected_actor_idx < 0 or actors.size() >= MAX_ACTORS:
		return
	var dup = actors[selected_actor_idx].duplicate(true)
	dup["name"] = dup["name"] + " (copy)"
	actors.append(dup)
	_refresh_actor_list()
	_select_actor(actors.size() - 1)
	_actor_list.select(selected_actor_idx)

func _on_del_actor() -> void:
	if selected_actor_idx < 0 or selected_actor_idx >= actors.size():
		return
	actors.remove_at(selected_actor_idx)
	selected_actor_idx = mini(selected_actor_idx, actors.size() - 1)
	_refresh_actor_list()
	if selected_actor_idx >= 0:
		_select_actor(selected_actor_idx)
		_actor_list.select(selected_actor_idx)
	else:
		_rebuild_detail_panel()


# ─── Detail Callbacks ────────────────────────────────────────

func _cur() -> Dictionary:
	if selected_actor_idx >= 0 and selected_actor_idx < actors.size():
		return actors[selected_actor_idx]
	return {}

func _on_name_changed(new_text: String) -> void:
	var a = _cur()
	if a.is_empty(): return
	a["name"] = new_text
	_refresh_actor_list()
	actor_changed.emit(selected_actor_idx)

func _on_type_changed(idx: int) -> void:
	var a = _cur()
	if a.is_empty(): return
	a["type"] = ACTOR_TYPES[idx]
	_refresh_actor_list()
	_rebuild_detail_panel()
	actor_changed.emit(selected_actor_idx)

func _on_max_speed_changed(val: float) -> void:
	var a = _cur()
	if not a.is_empty(): a["max_speed"] = int(val)

func _on_collision_changed(idx: int) -> void:
	var a = _cur()
	if not a.is_empty(): a["collision_mode"] = COLLISION_MODES[idx]

func _on_detect_barrier(pressed: bool) -> void:
	var a = _cur()
	if not a.is_empty(): a["detect_barrier"] = pressed

func _on_detect_deadly(pressed: bool) -> void:
	var a = _cur()
	if not a.is_empty(): a["detect_deadly"] = pressed

func _on_detect_teleport(pressed: bool) -> void:
	var a = _cur()
	if not a.is_empty(): a["detect_teleport"] = pressed

func _on_detect_ladder(pressed: bool) -> void:
	var a = _cur()
	if not a.is_empty(): a["detect_ladder"] = pressed

func _on_death_mode_changed(idx: int) -> void:
	var a = _cur()
	if not a.is_empty(): a["death_mode"] = DEATH_MODES[idx]

func _on_rebirth_toggled(pressed: bool) -> void:
	var a = _cur()
	if not a.is_empty(): a["rebirth"] = pressed

func _on_rebirth_delay(val: float) -> void:
	var a = _cur()
	if not a.is_empty(): a["rebirth_delay"] = int(val)

func _on_award_points(val: float) -> void:
	var a = _cur()
	if not a.is_empty(): a["award_points"] = int(val)

func _on_award_lives(val: float) -> void:
	var a = _cur()
	if not a.is_empty(): a["award_lives"] = int(val)

func _on_button_mode(idx: int) -> void:
	var a = _cur()
	if not a.is_empty(): a["button_mode"] = BUTTON_MODES[idx]

func _on_fall_height(val: float) -> void:
	var a = _cur()
	if not a.is_empty(): a["fall_height"] = int(val)

func _on_ai_strategy(idx: int) -> void:
	var a = _cur()
	if not a.is_empty(): a["ai_strategy"] = AI_STRATEGIES[idx]

func _on_ai_iq(val: float) -> void:
	var a = _cur()
	if not a.is_empty(): a["ai_iq"] = int(val)

func _on_auto_shoot_toggled(pressed: bool) -> void:
	var a = _cur()
	if not a.is_empty(): a["auto_shoot"] = pressed

func _on_auto_shoot_freq(val: float) -> void:
	var a = _cur()
	if not a.is_empty(): a["auto_shoot_freq"] = int(val)

func _on_entrance_mode(idx: int) -> void:
	var a = _cur()
	if not a.is_empty(): a["entrance_mode"] = ["Immediately", "After Delay", "Random"][idx]

func _on_entrance_delay(val: float) -> void:
	var a = _cur()
	if not a.is_empty(): a["entrance_delay"] = int(val)

func _on_entrance_loc(idx: int) -> void:
	var a = _cur()
	if not a.is_empty(): a["entrance_location"] = ["Original", "Random"][idx]

func _on_fx_a(idx: int) -> void:
	var a = _cur()
	if not a.is_empty(): a["fx_a_script"] = ["None", "Mutate", "Invincible", "Freeze", "No Shoot", "Rev Button"][idx]

func _on_fx_b(idx: int) -> void:
	var a = _cur()
	if not a.is_empty(): a["fx_b_script"] = ["None", "Mutate", "Invincible", "Freeze", "No Shoot", "Rev Button"][idx]

func _on_fx_c(idx: int) -> void:
	var a = _cur()
	if not a.is_empty(): a["fx_c_cue"] = ["Off", "Death", "Entrance", "Bounce"][idx]

func _on_fx_d(idx: int) -> void:
	var a = _cur()
	if not a.is_empty(): a["fx_d_cue"] = ["Off", "Death", "Entrance", "Bounce"][idx]


# ─── Serialization ───────────────────────────────────────────

func get_data() -> Array:
	return actors.duplicate(true)

func set_data(data: Array) -> void:
	actors = data.duplicate(true)
	selected_actor_idx = 0 if actors.size() > 0 else -1
	_refresh_actor_list()
	if selected_actor_idx >= 0:
		_select_actor(selected_actor_idx)
