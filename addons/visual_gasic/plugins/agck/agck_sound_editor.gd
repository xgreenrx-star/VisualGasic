@tool
## AGCK Sound Editor
##
## Retro waveform synthesizer inspired by AGCK's Sound Editor.
## 2 voices + 1 filter per sound, 4 waveforms (square/triangle/sawtooth/noise),
## bar-graph note editor, tempo control, 8 sound slots.
extends HSplitContainer

signal sound_changed(sound_id: int)

# ─── Constants ───────────────────────────────────────────────
const BG_COLOR = Color(0.16, 0.16, 0.19)
const SECTION_COLOR = Color(0.22, 0.26, 0.35)
const HEADER_COLOR = Color(0.85, 0.9, 1.0)
const LABEL_COLOR = Color(0.75, 0.8, 0.85)
const VALUE_COLOR = Color(0.5, 0.85, 0.55)
const ACCENT_COLOR = Color(0.65, 0.4, 0.85)
const BAR_COLOR_V1 = Color(0.3, 0.7, 0.4)
const BAR_COLOR_V2 = Color(0.3, 0.4, 0.7)
const BAR_COLOR_FLT = Color(0.7, 0.4, 0.3)
const BAR_BG = Color(0.1, 0.1, 0.12)
const GRID_COLOR = Color(0.2, 0.2, 0.22)

const WAVEFORMS = ["Square", "Triangle", "Sawtooth", "Noise"]
const WAVEFORM_ICONS = ["⬜", "🔺", "🔶", "〰️"]
const FILTER_TYPES = ["Low Pass", "Band Pass", "High Pass", "Notch"]
const FILTER_Q = ["Zero Q", "Low Q", "Med Q", "High Q"]
const MAX_SOUNDS = 8
const MAX_NOTES = 32
const MAX_NOTE_VAL = 48   # 4 octaves

# ─── Sound Data ──────────────────────────────────────────────
var sounds: Array = []
var selected_sound: int = 0
var selected_voice: int = 0  # 0=Voice1, 1=Voice2, 2=Filter

# ─── UI ──────────────────────────────────────────────────────
var _sound_list: ItemList = null
var _bar_graph: Control = null
var _waveform_btns: Array = []
var _voice_btns: Array = []
var _tempo_slider: HSlider = null
var _name_edit: LineEdit = null
var _filter_type_opt: OptionButton = null
var _filter_q_opt: OptionButton = null
var _filter_v1_check: CheckButton = null
var _filter_v2_check: CheckButton = null
var _is_playing: bool = false


func _ready() -> void:
	_init_sounds()
	_build_ui()


func _init_sounds() -> void:
	sounds.clear()
	for i in range(MAX_SOUNDS):
		sounds.append({
			"name": "Sound " + str(i + 1),
			"tempo": 50,
			"voice1_waveform": 0,  # Square
			"voice1_notes": _make_empty_notes(),
			"voice2_waveform": 1,  # Triangle
			"voice2_notes": _make_empty_notes(),
			"filter_type": 0,      # Low Pass
			"filter_q": 1,         # Low Q
			"filter_notes": _make_empty_notes(),
			"filter_voice1": true,
			"filter_voice2": false,
		})
	# Pre-populate Sound 1 with a simple laser blast pattern
	var snd = sounds[0]
	snd["name"] = "Laser"
	for i in range(8):
		snd["voice1_notes"][i] = MAX_NOTE_VAL - i * 5


func _make_empty_notes() -> Array:
	var arr: Array = []
	arr.resize(MAX_NOTES)
	arr.fill(0)
	return arr


func _build_ui() -> void:
	# LEFT: Sound slot list
	var left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size.x = 160
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var left_bg_style = StyleBoxFlat.new()
	left_bg_style.bg_color = Color(0.13, 0.13, 0.16)
	var left_wrap = PanelContainer.new()
	left_wrap.add_theme_stylebox_override("panel", left_bg_style)
	left_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var header = Label.new()
	header.text = "🔊  SOUNDS"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", HEADER_COLOR)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(header)

	_sound_list = ItemList.new()
	_sound_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sound_list.add_theme_font_size_override("font_size", 12)
	_sound_list.item_selected.connect(_on_sound_selected)
	left_panel.add_child(_sound_list)

	left_wrap.add_child(left_panel)
	add_child(left_wrap)

	# RIGHT: Sound editor
	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var right_bg_style = StyleBoxFlat.new()
	right_bg_style.bg_color = BG_COLOR
	var right_wrap = PanelContainer.new()
	right_wrap.add_theme_stylebox_override("panel", right_bg_style)
	right_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Sound name
	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	var name_lbl = Label.new()
	name_lbl.text = "Name:"
	name_lbl.add_theme_color_override("font_color", LABEL_COLOR)
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_row.add_child(name_lbl)
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.add_theme_font_size_override("font_size", 12)
	_name_edit.text_changed.connect(_on_name_changed)
	name_row.add_child(_name_edit)
	right_panel.add_child(name_row)

	# Voice selector tabs
	var voice_row = HBoxContainer.new()
	voice_row.add_theme_constant_override("separation", 4)
	var voice_names = ["♩ Voice 1", "♫ Voice 2", "🎛️ Filter"]
	var voice_colors = [BAR_COLOR_V1, BAR_COLOR_V2, BAR_COLOR_FLT]
	for i in range(3):
		var btn = Button.new()
		btn.text = voice_names[i]
		btn.add_theme_font_size_override("font_size", 11)
		btn.toggle_mode = true
		btn.button_pressed = (i == 0)
		btn.pressed.connect(_on_voice_selected.bind(i))
		var style = StyleBoxFlat.new()
		style.bg_color = voice_colors[i].darkened(0.4)
		style.set_corner_radius_all(3)
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		btn.add_theme_stylebox_override("normal", style)
		var pressed_s = style.duplicate()
		pressed_s.bg_color = voice_colors[i]
		btn.add_theme_stylebox_override("pressed", pressed_s)
		voice_row.add_child(btn)
		_voice_btns.append(btn)
	right_panel.add_child(voice_row)

	# Bar graph (custom draw)
	_bar_graph = Control.new()
	_bar_graph.custom_minimum_size = Vector2(0, 200)
	_bar_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bar_graph.draw.connect(_draw_bar_graph)
	_bar_graph.gui_input.connect(_on_bar_graph_input)
	right_panel.add_child(_bar_graph)

	# Waveform buttons (for voices) / Filter type (for filter)
	var wave_row = HBoxContainer.new()
	wave_row.add_theme_constant_override("separation", 4)
	var wave_lbl = Label.new()
	wave_lbl.text = "Waveform:"
	wave_lbl.add_theme_color_override("font_color", LABEL_COLOR)
	wave_lbl.add_theme_font_size_override("font_size", 12)
	wave_row.add_child(wave_lbl)
	for i in range(WAVEFORMS.size()):
		var btn = Button.new()
		btn.text = WAVEFORM_ICONS[i] + " " + WAVEFORMS[i]
		btn.add_theme_font_size_override("font_size", 11)
		btn.toggle_mode = true
		btn.button_pressed = (i == 0)
		btn.pressed.connect(_on_waveform_selected.bind(i))
		_waveform_btns.append(btn)
		wave_row.add_child(btn)
	right_panel.add_child(wave_row)

	# Filter options
	var filter_row = HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 8)
	var ft_lbl = Label.new()
	ft_lbl.text = "Filter:"
	ft_lbl.add_theme_color_override("font_color", LABEL_COLOR)
	ft_lbl.add_theme_font_size_override("font_size", 12)
	filter_row.add_child(ft_lbl)
	_filter_type_opt = OptionButton.new()
	_filter_type_opt.add_theme_font_size_override("font_size", 11)
	for ft in FILTER_TYPES:
		_filter_type_opt.add_item(ft)
	_filter_type_opt.item_selected.connect(_on_filter_type_changed)
	filter_row.add_child(_filter_type_opt)
	_filter_q_opt = OptionButton.new()
	_filter_q_opt.add_theme_font_size_override("font_size", 11)
	for fq in FILTER_Q:
		_filter_q_opt.add_item(fq)
	_filter_q_opt.selected = 1
	_filter_q_opt.item_selected.connect(_on_filter_q_changed)
	filter_row.add_child(_filter_q_opt)
	_filter_v1_check = CheckButton.new()
	_filter_v1_check.text = "V1"
	_filter_v1_check.button_pressed = true
	_filter_v1_check.add_theme_font_size_override("font_size", 11)
	_filter_v1_check.toggled.connect(_on_filter_v1_toggled)
	filter_row.add_child(_filter_v1_check)
	_filter_v2_check = CheckButton.new()
	_filter_v2_check.text = "V2"
	_filter_v2_check.add_theme_font_size_override("font_size", 11)
	_filter_v2_check.toggled.connect(_on_filter_v2_toggled)
	filter_row.add_child(_filter_v2_check)
	right_panel.add_child(filter_row)

	# Tempo + transport
	var tempo_row = HBoxContainer.new()
	tempo_row.add_theme_constant_override("separation", 8)
	var tempo_lbl = Label.new()
	tempo_lbl.text = "Tempo:"
	tempo_lbl.add_theme_color_override("font_color", LABEL_COLOR)
	tempo_lbl.add_theme_font_size_override("font_size", 12)
	tempo_row.add_child(tempo_lbl)
	_tempo_slider = HSlider.new()
	_tempo_slider.min_value = 1
	_tempo_slider.max_value = 100
	_tempo_slider.value = 50
	_tempo_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tempo_slider.value_changed.connect(_on_tempo_changed)
	tempo_row.add_child(_tempo_slider)

	# Transport buttons
	var play_btn = Button.new()
	play_btn.text = "▶ Listen"
	play_btn.add_theme_font_size_override("font_size", 11)
	play_btn.pressed.connect(_on_play_pressed)
	tempo_row.add_child(play_btn)
	var clear_btn = Button.new()
	clear_btn.text = "✕ Clear"
	clear_btn.add_theme_font_size_override("font_size", 11)
	clear_btn.pressed.connect(_on_clear_pressed)
	tempo_row.add_child(clear_btn)
	right_panel.add_child(tempo_row)

	right_wrap.add_child(right_panel)
	add_child(right_wrap)

	_refresh_sound_list()
	_refresh_ui()


# ─── Drawing ─────────────────────────────────────────────────

func _draw_bar_graph() -> void:
	if not is_instance_valid(_bar_graph):
		return
	var size = _bar_graph.size
	if size.x < 10 or size.y < 10:
		return

	# Background
	_bar_graph.draw_rect(Rect2(Vector2.ZERO, size), BAR_BG)

	# Grid lines (octave markers)
	var octave_height: float = size.y / 4.0
	for i in range(1, 4):
		var y_pos: float = size.y - octave_height * float(i)
		_bar_graph.draw_line(Vector2(0, y_pos), Vector2(size.x, y_pos), GRID_COLOR, 1.0)

	# Get current notes
	var notes: Array = _get_current_notes()
	var bar_w: float = size.x / float(MAX_NOTES)
	var bar_colors = [BAR_COLOR_V1, BAR_COLOR_V2, BAR_COLOR_FLT]
	var bar_color: Color = bar_colors[selected_voice]

	for i in range(MAX_NOTES):
		if notes[i] > 0:
			var h: float = (float(notes[i]) / float(MAX_NOTE_VAL)) * size.y
			var x: float = float(i) * bar_w
			var rect = Rect2(x + 1, size.y - h, bar_w - 2, h)
			_bar_graph.draw_rect(rect, bar_color)
			# Highlight outline
			_bar_graph.draw_rect(rect, bar_color.lightened(0.3), false, 1.0)

	# Vertical grid (every 8 notes)
	for i in range(1, 4):
		var x_pos: float = float(i * 8) * bar_w
		_bar_graph.draw_line(Vector2(x_pos, 0), Vector2(x_pos, size.y), GRID_COLOR, 1.0)


func _on_bar_graph_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	if event is InputEventMouseButton:
		if not event.pressed:
			return
	elif event is InputEventMouseMotion:
		if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			return

	var size = _bar_graph.size
	if size.x < 10 or size.y < 10:
		return

	var pos: Vector2 = event.position
	var bar_w: float = size.x / float(MAX_NOTES)
	var note_idx: int = int(pos.x / bar_w)
	note_idx = clampi(note_idx, 0, MAX_NOTES - 1)

	var note_val: int = int((1.0 - pos.y / size.y) * float(MAX_NOTE_VAL))
	note_val = clampi(note_val, 0, MAX_NOTE_VAL)

	var notes: Array = _get_current_notes()
	notes[note_idx] = note_val
	_bar_graph.queue_redraw()
	sound_changed.emit(selected_sound)


# ─── Helpers ─────────────────────────────────────────────────

func _get_current_notes() -> Array:
	var snd = sounds[selected_sound]
	match selected_voice:
		0: return snd["voice1_notes"]
		1: return snd["voice2_notes"]
		2: return snd["filter_notes"]
	return snd["voice1_notes"]

func _refresh_sound_list() -> void:
	_sound_list.clear()
	for i in range(sounds.size()):
		_sound_list.add_item(str(i + 1) + ": " + sounds[i]["name"])
	if selected_sound >= 0 and selected_sound < sounds.size():
		_sound_list.select(selected_sound)

func _refresh_ui() -> void:
	if selected_sound < 0 or selected_sound >= sounds.size():
		return
	var snd = sounds[selected_sound]
	_name_edit.text = snd["name"]
	_tempo_slider.value = snd["tempo"]

	# Update waveform buttons
	var wf_idx: int = snd["voice1_waveform"] if selected_voice == 0 else snd["voice2_waveform"]
	for i in range(_waveform_btns.size()):
		_waveform_btns[i].button_pressed = (i == wf_idx)

	# Filter options
	_filter_type_opt.selected = snd["filter_type"]
	_filter_q_opt.selected = snd["filter_q"]
	_filter_v1_check.button_pressed = snd["filter_voice1"]
	_filter_v2_check.button_pressed = snd["filter_voice2"]

	if is_instance_valid(_bar_graph):
		_bar_graph.queue_redraw()


# ─── Callbacks ───────────────────────────────────────────────

func _on_sound_selected(idx: int) -> void:
	selected_sound = idx
	_refresh_ui()

func _on_voice_selected(idx: int) -> void:
	selected_voice = idx
	for i in range(_voice_btns.size()):
		_voice_btns[i].button_pressed = (i == idx)
	if is_instance_valid(_bar_graph):
		_bar_graph.queue_redraw()

func _on_waveform_selected(idx: int) -> void:
	var snd = sounds[selected_sound]
	if selected_voice == 0:
		snd["voice1_waveform"] = idx
	elif selected_voice == 1:
		snd["voice2_waveform"] = idx
	for i in range(_waveform_btns.size()):
		_waveform_btns[i].button_pressed = (i == idx)

func _on_name_changed(new_text: String) -> void:
	sounds[selected_sound]["name"] = new_text
	_refresh_sound_list()

func _on_tempo_changed(val: float) -> void:
	sounds[selected_sound]["tempo"] = int(val)

func _on_filter_type_changed(idx: int) -> void:
	sounds[selected_sound]["filter_type"] = idx

func _on_filter_q_changed(idx: int) -> void:
	sounds[selected_sound]["filter_q"] = idx

func _on_filter_v1_toggled(pressed: bool) -> void:
	sounds[selected_sound]["filter_voice1"] = pressed

func _on_filter_v2_toggled(pressed: bool) -> void:
	sounds[selected_sound]["filter_voice2"] = pressed

func _on_play_pressed() -> void:
	# TODO: Generate AudioStreamWAV from bar-graph data using Godot's AudioServer
	print("AGCK Sound Editor: Play sound '", sounds[selected_sound]["name"], "' (audio synthesis TBD)")

func _on_clear_pressed() -> void:
	var notes: Array = _get_current_notes()
	notes.fill(0)
	if is_instance_valid(_bar_graph):
		_bar_graph.queue_redraw()


# ─── Serialization ───────────────────────────────────────────

func get_data() -> Array:
	return sounds.duplicate(true)

func set_data(data: Array) -> void:
	sounds = data.duplicate(true)
	while sounds.size() < MAX_SOUNDS:
		sounds.append({
			"name": "Sound " + str(sounds.size() + 1),
			"tempo": 50,
			"voice1_waveform": 0, "voice1_notes": _make_empty_notes(),
			"voice2_waveform": 1, "voice2_notes": _make_empty_notes(),
			"filter_type": 0, "filter_q": 1, "filter_notes": _make_empty_notes(),
			"filter_voice1": true, "filter_voice2": false,
		})
	selected_sound = 0
	_refresh_sound_list()
	_refresh_ui()
