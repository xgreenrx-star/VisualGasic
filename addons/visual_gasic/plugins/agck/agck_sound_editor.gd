@tool
## AGCK Sound Editor — bar-graph synth painter
##
## Big bar-graph canvas as hero element. Voice/filter toggle strip
## across the top. Sound selector as compact dropdown.
extends VBoxContainer

signal sound_changed(sound_id: int)

# ─── Theme ───────────────────────────────────────────────────
const BG_COLOR   = Color(0.13, 0.13, 0.16)
const HEADER_BG  = Color(0.10, 0.10, 0.13)
const TOOLBAR_BG = Color(0.11, 0.11, 0.14)
const WHITE      = Color(1.0, 1.0, 1.0)
const LABEL_CLR  = Color(0.88, 0.86, 0.80)
const ACCENT     = Color(1.0, 0.82, 0.35)
const DIM        = Color(0.50, 0.50, 0.55)
const V1_COLOR   = Color(0.30, 0.85, 0.40)   # Voice 1 — green
const V2_COLOR   = Color(0.35, 0.55, 0.95)   # Voice 2 — blue
const FLT_COLOR  = Color(0.95, 0.60, 0.20)   # Filter — orange
const CANVAS_BG  = Color(0.06, 0.06, 0.08)

const MAX_SOUNDS   = 8
const NUM_NOTES    = 32
const MAX_NOTE_VAL = 48
const WAVEFORMS    = ["Square", "Triangle", "Sawtooth", "Noise"]
const FILTER_TYPES = ["None", "LowPass", "HighPass", "BandPass"]

# ─── Audio Synthesis ─────────────────────────────────────────
const SAMPLE_RATE   = 22050
const NOTE_BASE_HZ  = 65.41  # C2 base frequency
const ENVELOPE_MS   = 5      # ms attack/release to prevent clicks

# ─── Data ────────────────────────────────────────────────────
var sounds: Array = []
var selected_sound: int = 0
var active_voice: int = 0  # 0=Voice1, 1=Voice2, 2=Filter
var is_painting: bool = false
var _undo_stack: Array = []   # Array of {sound_idx, voice1, voice2, filter}
var _redo_stack: Array = []
var _stroke_snapshot = null
const MAX_UNDO = 30

# ─── UI Refs ─────────────────────────────────────────────────
var _bar_canvas: Control = null
var _sound_opt: OptionButton = null
var _wave_opt1: OptionButton = null
var _wave_opt2: OptionButton = null
var _filt_opt: OptionButton = null
var _filt_q_slider: HSlider = null
var _tempo_slider: HSlider = null
var _voice_btns: Array = []
var _status_lbl: Label = null
var _audio_player: AudioStreamPlayer = null
var _name_edit: LineEdit = null
var _vol1_slider: HSlider = null
var _vol2_slider: HSlider = null
var _import_btn: Button = null
var _vgsfx_btn: Button = null
var _vgsfx_window: Window = null
var _clear_wav_btn: Button = null
var _wav_label: Label = null
var _file_dialog: FileDialog = null


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
	_init_sounds()
	_build_ui()


func _init_sounds() -> void:
	sounds.clear()
	# Pre-load 8 retro game sound presets
	sounds.append(_preset_jump())
	sounds.append(_preset_coin())
	sounds.append(_preset_hit())
	sounds.append(_preset_hero_death())
	sounds.append(_preset_enemy_death())
	sounds.append(_preset_shoot())
	sounds.append(_preset_powerup())
	sounds.append(_preset_game_over())


# ─── Sound Presets ────────────────────────────────────────────

func _preset_jump() -> Dictionary:
	var d = _make_empty_sound(1)
	d["name"] = "Jump"
	d["tempo"] = 240
	d["voice1_wave"] = 1  # Triangle
	d["voice1_enabled"] = true
	d["voice1_volume"] = 75
	# Rising chirp: quick ascending notes
	var n = d["voice1_notes"]
	n[0] = 12; n[1] = 18; n[2] = 24; n[3] = 30; n[4] = 36; n[5] = 40; n[6] = 44; n[7] = 48
	return d

func _preset_coin() -> Dictionary:
	var d = _make_empty_sound(2)
	d["name"] = "Coin"
	d["tempo"] = 280
	d["voice1_wave"] = 0  # Square
	d["voice1_enabled"] = true
	d["voice1_volume"] = 70
	# Two-note ascending chime
	var n = d["voice1_notes"]
	n[0] = 30; n[1] = 30; n[2] = 0; n[3] = 42; n[4] = 42
	d["voice2_enabled"] = true
	d["voice2_wave"] = 1  # Triangle
	d["voice2_volume"] = 40
	var n2 = d["voice2_notes"]
	n2[0] = 18; n2[1] = 18; n2[2] = 0; n2[3] = 30; n2[4] = 30
	return d

func _preset_hit() -> Dictionary:
	var d = _make_empty_sound(3)
	d["name"] = "Hit"
	d["tempo"] = 260
	d["voice1_wave"] = 3  # Noise
	d["voice1_enabled"] = true
	d["voice1_volume"] = 80
	# Short noise burst
	var n = d["voice1_notes"]
	n[0] = 36; n[1] = 28; n[2] = 16; n[3] = 8
	d["filter_enabled"] = true
	d["filter_type"] = 1  # LowPass
	d["filter_q"] = 40
	var fn = d["filter_notes"]
	fn[0] = 30; fn[1] = 20; fn[2] = 12; fn[3] = 6
	return d

func _preset_hero_death() -> Dictionary:
	var d = _make_empty_sound(4)
	d["name"] = "Hero Death"
	d["tempo"] = 160
	d["voice1_wave"] = 0  # Square
	d["voice1_enabled"] = true
	d["voice1_volume"] = 80
	# Descending tone sweep
	var n = d["voice1_notes"]
	n[0] = 36; n[1] = 34; n[2] = 32; n[3] = 30; n[4] = 28; n[5] = 26
	n[6] = 24; n[7] = 22; n[8] = 20; n[9] = 18; n[10] = 16; n[11] = 14
	n[12] = 12; n[13] = 10; n[14] = 8; n[15] = 6
	d["voice2_enabled"] = true
	d["voice2_wave"] = 3  # Noise
	d["voice2_volume"] = 30
	var n2 = d["voice2_notes"]
	n2[0] = 20; n2[1] = 18; n2[2] = 16; n2[3] = 14; n2[4] = 12; n2[5] = 10
	n2[6] = 8; n2[7] = 6; n2[8] = 4
	return d

func _preset_enemy_death() -> Dictionary:
	var d = _make_empty_sound(5)
	d["name"] = "Enemy Death"
	d["tempo"] = 280
	d["voice1_wave"] = 3  # Noise
	d["voice1_enabled"] = true
	d["voice1_volume"] = 75
	# Quick noise pop
	var n = d["voice1_notes"]
	n[0] = 40; n[1] = 30; n[2] = 18; n[3] = 8; n[4] = 4
	d["voice2_enabled"] = true
	d["voice2_wave"] = 0  # Square
	d["voice2_volume"] = 50
	var n2 = d["voice2_notes"]
	n2[0] = 32; n2[1] = 24; n2[2] = 16; n2[3] = 8
	return d

func _preset_shoot() -> Dictionary:
	var d = _make_empty_sound(6)
	d["name"] = "Shoot"
	d["tempo"] = 300
	d["voice1_wave"] = 0  # Square
	d["voice1_enabled"] = true
	d["voice1_volume"] = 65
	# Short blip
	var n = d["voice1_notes"]
	n[0] = 38; n[1] = 32; n[2] = 24; n[3] = 16
	d["voice2_enabled"] = true
	d["voice2_wave"] = 3  # Noise
	d["voice2_volume"] = 35
	var n2 = d["voice2_notes"]
	n2[0] = 24; n2[1] = 16; n2[2] = 8
	return d

func _preset_powerup() -> Dictionary:
	var d = _make_empty_sound(7)
	d["name"] = "Powerup"
	d["tempo"] = 260
	d["voice1_wave"] = 1  # Triangle
	d["voice1_enabled"] = true
	d["voice1_volume"] = 75
	# Rising arpeggio
	var n = d["voice1_notes"]
	n[0] = 12; n[1] = 16; n[2] = 19; n[3] = 24; n[4] = 28; n[5] = 31
	n[6] = 36; n[7] = 40; n[8] = 43; n[9] = 48
	d["voice2_enabled"] = true
	d["voice2_wave"] = 0  # Square
	d["voice2_volume"] = 40
	var n2 = d["voice2_notes"]
	n2[2] = 12; n2[3] = 16; n2[4] = 19; n2[5] = 24; n2[6] = 28; n2[7] = 31
	return d

func _preset_game_over() -> Dictionary:
	var d = _make_empty_sound(8)
	d["name"] = "Game Over"
	d["tempo"] = 120
	d["voice1_wave"] = 0  # Square
	d["voice1_enabled"] = true
	d["voice1_volume"] = 80
	# Slow descending sad tones
	var n = d["voice1_notes"]
	n[0] = 24; n[1] = 24; n[2] = 0; n[3] = 22; n[4] = 22; n[5] = 0
	n[6] = 19; n[7] = 19; n[8] = 0; n[9] = 17; n[10] = 17; n[11] = 0
	n[12] = 12; n[13] = 12; n[14] = 12; n[15] = 12
	d["voice2_enabled"] = true
	d["voice2_wave"] = 1  # Triangle
	d["voice2_volume"] = 50
	var n2 = d["voice2_notes"]
	n2[0] = 12; n2[1] = 12; n2[2] = 0; n2[3] = 10; n2[4] = 10; n2[5] = 0
	n2[6] = 7; n2[7] = 7; n2[8] = 0; n2[9] = 5; n2[10] = 5; n2[11] = 0
	n2[12] = 1; n2[13] = 1; n2[14] = 1; n2[15] = 1
	return d


func _make_empty_sound(num: int) -> Dictionary:
	var v1_notes: Array = []
	var v2_notes: Array = []
	var flt_notes: Array = []
	v1_notes.resize(NUM_NOTES); v1_notes.fill(0)
	v2_notes.resize(NUM_NOTES); v2_notes.fill(0)
	flt_notes.resize(NUM_NOTES); flt_notes.fill(0)
	return {
		"name": "Sound " + str(num),
		"tempo": 120,
		"voice1_wave": 0,
		"voice1_notes": v1_notes,
		"voice2_wave": 1,
		"voice2_notes": v2_notes,
		"filter_type": 0,
		"filter_q": 50,
		"filter_notes": flt_notes,
		"voice1_enabled": true,
		"voice2_enabled": false,
		"filter_enabled": false,
		"voice1_volume": 80,
		"voice2_volume": 60,
		"custom_wav": "",
	}


func _build_ui() -> void:
	add_theme_constant_override("separation", 0)

	# ══════════════════════════════════════════════════════════
	# TOP BAR: Sound selector + voice toggles
	# ══════════════════════════════════════════════════════════
	var top_bar = PanelContainer.new()
	var tb_style = StyleBoxFlat.new()
	tb_style.bg_color = TOOLBAR_BG
	tb_style.content_margin_left = 8
	tb_style.content_margin_right = 8
	tb_style.content_margin_top = 6
	tb_style.content_margin_bottom = 6
	top_bar.add_theme_stylebox_override("panel", tb_style)
	top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(top_bar)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	top_bar.add_child(hbox)

	# Sound dropdown
	var snd_lbl = Label.new()
	snd_lbl.text = "🔊 Sound:"
	snd_lbl.label_settings = _ls(12, LABEL_CLR)
	hbox.add_child(snd_lbl)

	_sound_opt = OptionButton.new()
	_sound_opt.add_theme_font_size_override("font_size", 11)
	_sound_opt.custom_minimum_size.x = 130
	_sound_opt.item_selected.connect(_on_sound_selected)
	hbox.add_child(_sound_opt)
	_style_option(_sound_opt)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Sound name"
	_name_edit.tooltip_text = "Give this sound a name so you remember what it is"
	_name_edit.custom_minimum_size.x = 100
	_name_edit.add_theme_font_size_override("font_size", 11)
	var ne_style = StyleBoxFlat.new()
	ne_style.bg_color = Color(0.12, 0.12, 0.15)
	ne_style.set_corner_radius_all(3)
	ne_style.content_margin_left = 6; ne_style.content_margin_right = 6
	ne_style.content_margin_top = 2;  ne_style.content_margin_bottom = 2
	ne_style.border_width_bottom = 1; ne_style.border_color = Color(0.30, 0.30, 0.35)
	_name_edit.add_theme_stylebox_override("normal", ne_style)
	_name_edit.add_theme_color_override("font_color", WHITE)
	_name_edit.text_changed.connect(_on_name_changed)
	hbox.add_child(_name_edit)

	# 📂 Import WAV button
	_import_btn = Button.new()
	_import_btn.text = "📂"
	_import_btn.tooltip_text = "Import a .wav file for this sound slot"
	_import_btn.add_theme_font_size_override("font_size", 13)
	_import_btn.pressed.connect(_on_import_wav)
	var imp_s = StyleBoxFlat.new()
	imp_s.bg_color = Color(0.18, 0.18, 0.22)
	imp_s.set_corner_radius_all(3)
	imp_s.content_margin_left = 4; imp_s.content_margin_right = 4
	imp_s.content_margin_top = 2;  imp_s.content_margin_bottom = 2
	_import_btn.add_theme_stylebox_override("normal", imp_s)
	var imp_h = imp_s.duplicate()
	imp_h.bg_color = Color(0.25, 0.25, 0.30)
	_import_btn.add_theme_stylebox_override("hover", imp_h)
	_import_btn.add_theme_color_override("font_color", LABEL_CLR)
	hbox.add_child(_import_btn)

	# 🎛 VGSFX synthesizer button (opens VGSFX dock in a popup)
	_vgsfx_btn = Button.new()
	_vgsfx_btn.text = "\ud83c\udf9b"  # 🎛
	_vgsfx_btn.tooltip_text = "Open VGSFX synthesizer (port of bfxr2)\nExporting a WAV will fill this slot."
	_vgsfx_btn.add_theme_font_size_override("font_size", 13)
	_vgsfx_btn.pressed.connect(_on_open_vgsfx)
	var gx_s = imp_s.duplicate()
	gx_s.bg_color = Color(0.20, 0.28, 0.20)
	_vgsfx_btn.add_theme_stylebox_override("normal", gx_s)
	var gx_h = gx_s.duplicate()
	gx_h.bg_color = Color(0.30, 0.40, 0.30)
	_vgsfx_btn.add_theme_stylebox_override("hover", gx_h)
	_vgsfx_btn.add_theme_color_override("font_color", LABEL_CLR)
	hbox.add_child(_vgsfx_btn)

	# ✕ Clear WAV button (only visible when custom wav is set)
	_clear_wav_btn = Button.new()
	_clear_wav_btn.text = "✕"
	_clear_wav_btn.tooltip_text = "Remove imported WAV — revert to synth"
	_clear_wav_btn.add_theme_font_size_override("font_size", 11)
	_clear_wav_btn.pressed.connect(_on_clear_wav)
	var clr_s = StyleBoxFlat.new()
	clr_s.bg_color = Color(0.55, 0.20, 0.20)
	clr_s.set_corner_radius_all(3)
	clr_s.content_margin_left = 4; clr_s.content_margin_right = 4
	clr_s.content_margin_top = 2;  clr_s.content_margin_bottom = 2
	_clear_wav_btn.add_theme_stylebox_override("normal", clr_s)
	var clr_h = clr_s.duplicate()
	clr_h.bg_color = Color(0.70, 0.25, 0.25)
	_clear_wav_btn.add_theme_stylebox_override("hover", clr_h)
	_clear_wav_btn.add_theme_color_override("font_color", WHITE)
	_clear_wav_btn.visible = false
	hbox.add_child(_clear_wav_btn)

	# WAV file indicator label
	_wav_label = Label.new()
	_wav_label.text = ""
	_wav_label.label_settings = _ls(10, Color(0.55, 0.85, 0.55))
	_wav_label.visible = false
	hbox.add_child(_wav_label)

	hbox.add_child(VSeparator.new())

	# Voice toggle buttons — color-coded
	var voice_data = [
		{"label": "🎵 Voice 1", "color": V1_COLOR},
		{"label": "🎶 Voice 2", "color": V2_COLOR},
		{"label": "🔧 Filter", "color": FLT_COLOR},
	]
	for i in range(voice_data.size()):
		var vd = voice_data[i]
		var btn = Button.new()
		btn.text = vd.label
		btn.toggle_mode = true
		btn.button_pressed = (i == active_voice)
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(_on_voice_btn.bind(i))

		var ns = StyleBoxFlat.new()
		ns.bg_color = vd.color.darkened(0.6)
		ns.set_corner_radius_all(4)
		ns.content_margin_left = 8
		ns.content_margin_right = 8
		ns.content_margin_top = 3
		ns.content_margin_bottom = 3
		btn.add_theme_stylebox_override("normal", ns)

		var ps = ns.duplicate()
		ps.bg_color = vd.color
		ps.border_width_bottom = 3
		ps.border_color = WHITE
		btn.add_theme_stylebox_override("pressed", ps)

		var hs = ns.duplicate()
		hs.bg_color = vd.color.darkened(0.3)
		btn.add_theme_stylebox_override("hover", hs)

		btn.add_theme_color_override("font_color", WHITE)
		btn.add_theme_color_override("font_pressed_color", WHITE)
		btn.add_theme_color_override("font_hover_color", WHITE)
		hbox.add_child(btn)
		_voice_btns.append(btn)

	# Spacer
	var spc = Control.new()
	spc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spc)

	# Tempo
	var t_lbl = Label.new()
	t_lbl.text = "Tempo:"
	t_lbl.label_settings = _ls(11, DIM)
	hbox.add_child(t_lbl)
	_tempo_slider = HSlider.new()
	_tempo_slider.min_value = 40
	_tempo_slider.max_value = 300
	_tempo_slider.value = 120
	_tempo_slider.custom_minimum_size.x = 80
	_tempo_slider.value_changed.connect(_on_tempo_changed)
	hbox.add_child(_tempo_slider)

	hbox.add_child(VSeparator.new())

	# ▶ Play button
	var play_btn = Button.new()
	play_btn.text = "▶ Play"
	play_btn.add_theme_font_size_override("font_size", 12)
	play_btn.pressed.connect(_on_play_sound)
	var play_s = StyleBoxFlat.new()
	play_s.bg_color = Color(0.25, 0.65, 0.35)
	play_s.set_corner_radius_all(4)
	play_s.content_margin_left = 10
	play_s.content_margin_right = 10
	play_s.content_margin_top = 3
	play_s.content_margin_bottom = 3
	play_btn.add_theme_stylebox_override("normal", play_s)
	var play_h = play_s.duplicate()
	play_h.bg_color = Color(0.30, 0.75, 0.40)
	play_btn.add_theme_stylebox_override("hover", play_h)
	play_btn.add_theme_color_override("font_color", WHITE)
	play_btn.add_theme_color_override("font_hover_color", WHITE)
	hbox.add_child(play_btn)

	# ⏹ Stop button
	var stop_btn = Button.new()
	stop_btn.text = "⏹ Stop"
	stop_btn.add_theme_font_size_override("font_size", 12)
	stop_btn.pressed.connect(_on_stop_sound)
	var stop_s = StyleBoxFlat.new()
	stop_s.bg_color = Color(0.65, 0.25, 0.25)
	stop_s.set_corner_radius_all(4)
	stop_s.content_margin_left = 10
	stop_s.content_margin_right = 10
	stop_s.content_margin_top = 3
	stop_s.content_margin_bottom = 3
	stop_btn.add_theme_stylebox_override("normal", stop_s)
	var stop_h = stop_s.duplicate()
	stop_h.bg_color = Color(0.75, 0.30, 0.30)
	stop_btn.add_theme_stylebox_override("hover", stop_h)
	stop_btn.add_theme_color_override("font_color", WHITE)
	stop_btn.add_theme_color_override("font_hover_color", WHITE)
	hbox.add_child(stop_btn)

	# ══════════════════════════════════════════════════════════
	# WAVEFORM / FILTER ROW
	# ══════════════════════════════════════════════════════════
	var wave_bar = PanelContainer.new()
	var wbs = StyleBoxFlat.new()
	wbs.bg_color = Color(0.09, 0.09, 0.11)
	wbs.content_margin_left = 8
	wbs.content_margin_right = 8
	wbs.content_margin_top = 4
	wbs.content_margin_bottom = 4
	wave_bar.add_theme_stylebox_override("panel", wbs)
	wave_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(wave_bar)

	var w_hbox = HBoxContainer.new()
	w_hbox.add_theme_constant_override("separation", 8)
	wave_bar.add_child(w_hbox)

	var w1_lbl = Label.new()
	w1_lbl.text = "V1 Wave:"
	w1_lbl.label_settings = _ls(11, V1_COLOR)
	w_hbox.add_child(w1_lbl)
	_wave_opt1 = OptionButton.new()
	_wave_opt1.add_theme_font_size_override("font_size", 11)
	for w in WAVEFORMS:
		_wave_opt1.add_item(w)
	_wave_opt1.item_selected.connect(_on_wave1_changed)
	w_hbox.add_child(_wave_opt1)
	_style_option(_wave_opt1)

	w_hbox.add_child(VSeparator.new())

	var w2_lbl = Label.new()
	w2_lbl.text = "V2 Wave:"
	w2_lbl.label_settings = _ls(11, V2_COLOR)
	w_hbox.add_child(w2_lbl)
	_wave_opt2 = OptionButton.new()
	_wave_opt2.add_theme_font_size_override("font_size", 11)
	for w in WAVEFORMS:
		_wave_opt2.add_item(w)
	_wave_opt2.selected = 1
	_wave_opt2.item_selected.connect(_on_wave2_changed)
	w_hbox.add_child(_wave_opt2)
	_style_option(_wave_opt2)

	w_hbox.add_child(VSeparator.new())

	var fl_lbl = Label.new()
	fl_lbl.text = "Filter:"
	fl_lbl.label_settings = _ls(11, FLT_COLOR)
	w_hbox.add_child(fl_lbl)
	_filt_opt = OptionButton.new()
	_filt_opt.add_theme_font_size_override("font_size", 11)
	for ft in FILTER_TYPES:
		_filt_opt.add_item(ft)
	_filt_opt.item_selected.connect(_on_filt_changed)
	w_hbox.add_child(_filt_opt)
	_style_option(_filt_opt)

	var fq_lbl = Label.new()
	fq_lbl.text = "Q:"
	fq_lbl.label_settings = _ls(11, DIM)
	w_hbox.add_child(fq_lbl)
	_filt_q_slider = HSlider.new()
	_filt_q_slider.min_value = 0
	_filt_q_slider.max_value = 100
	_filt_q_slider.value = 50
	_filt_q_slider.custom_minimum_size.x = 60
	_filt_q_slider.value_changed.connect(_on_filt_q_changed)
	w_hbox.add_child(_filt_q_slider)

	w_hbox.add_child(VSeparator.new())

	var v1v_lbl = Label.new()
	v1v_lbl.text = "V1 Vol:"
	v1v_lbl.label_settings = _ls(10, V1_COLOR)
	w_hbox.add_child(v1v_lbl)
	_vol1_slider = HSlider.new()
	_vol1_slider.min_value = 0; _vol1_slider.max_value = 100
	_vol1_slider.value = 80; _vol1_slider.custom_minimum_size.x = 50
	_vol1_slider.tooltip_text = "Volume for Voice 1"
	_vol1_slider.value_changed.connect(func(v): sounds[selected_sound]["voice1_volume"] = int(v); sound_changed.emit(selected_sound))
	w_hbox.add_child(_vol1_slider)

	var v2v_lbl = Label.new()
	v2v_lbl.text = "V2 Vol:"
	v2v_lbl.label_settings = _ls(10, V2_COLOR)
	w_hbox.add_child(v2v_lbl)
	_vol2_slider = HSlider.new()
	_vol2_slider.min_value = 0; _vol2_slider.max_value = 100
	_vol2_slider.value = 60; _vol2_slider.custom_minimum_size.x = 50
	_vol2_slider.tooltip_text = "Volume for Voice 2"
	_vol2_slider.value_changed.connect(func(v): sounds[selected_sound]["voice2_volume"] = int(v); sound_changed.emit(selected_sound))
	w_hbox.add_child(_vol2_slider)

	# ══════════════════════════════════════════════════════════
	# BAR GRAPH CANVAS — the hero element
	# ══════════════════════════════════════════════════════════
	_bar_canvas = Control.new()
	_bar_canvas.custom_minimum_size = Vector2(NUM_NOTES * 16, 200)
	_bar_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bar_canvas.draw.connect(_draw_bars)
	_bar_canvas.gui_input.connect(_on_bar_input)
	add_child(_bar_canvas)

	# ══════════════════════════════════════════════════════════
	# BOTTOM STATUS
	# ══════════════════════════════════════════════════════════
	var bot = PanelContainer.new()
	var bot_s = StyleBoxFlat.new()
	bot_s.bg_color = TOOLBAR_BG
	bot_s.content_margin_left = 10
	bot_s.content_margin_right = 10
	bot_s.content_margin_top = 3
	bot_s.content_margin_bottom = 3
	bot.add_theme_stylebox_override("panel", bot_s)
	bot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(bot)

	_status_lbl = Label.new()
	_status_lbl.text = "Click and drag to paint notes · Switch voices with the color buttons above"
	_status_lbl.label_settings = _ls(10, LABEL_CLR)
	bot.add_child(_status_lbl)

	_refresh_sound_list()
	_refresh_ui()


# ─── Bar Graph Drawing ──────────────────────────────────────

func _draw_bars() -> void:
	if not is_instance_valid(_bar_canvas):
		return
	var sz = _bar_canvas.size
	if sz.x < 10 or sz.y < 10:
		return

	# Background
	_bar_canvas.draw_rect(Rect2(Vector2.ZERO, sz), CANVAS_BG)

	var snd = sounds[selected_sound]
	var bar_w: float = sz.x / float(NUM_NOTES)
	var gap: float = 2.0

	# Draw all three layers (back to front: filter, voice2, voice1)
	var layers = [
		{"notes": snd["filter_notes"], "color": FLT_COLOR.darkened(0.3), "enabled": snd.get("filter_enabled", false)},
		{"notes": snd["voice2_notes"], "color": V2_COLOR.darkened(0.2), "enabled": snd.get("voice2_enabled", false)},
		{"notes": snd["voice1_notes"], "color": V1_COLOR.darkened(0.1), "enabled": snd.get("voice1_enabled", true)},
	]

	for layer in layers:
		if not layer.enabled:
			continue
		var notes: Array = layer.notes
		var color: Color = layer.color
		for i in range(NUM_NOTES):
			if i >= notes.size():
				continue
			var val: int = notes[i]
			if val <= 0:
				continue
			var h: float = (float(val) / float(MAX_NOTE_VAL)) * sz.y
			var rect = Rect2(i * bar_w + gap, sz.y - h, bar_w - gap * 2, h)
			_bar_canvas.draw_rect(rect, color)

	# Active voice bars on top with full brightness
	var active_colors = [V1_COLOR, V2_COLOR, FLT_COLOR]
	var active_keys = ["voice1_notes", "voice2_notes", "filter_notes"]
	var a_notes: Array = snd[active_keys[active_voice]]
	var a_color: Color = active_colors[active_voice]
	for i in range(NUM_NOTES):
		if i >= a_notes.size():
			continue
		var val: int = a_notes[i]
		if val <= 0:
			continue
		var h: float = (float(val) / float(MAX_NOTE_VAL)) * sz.y
		var rect = Rect2(i * bar_w + gap, sz.y - h, bar_w - gap * 2, h)
		_bar_canvas.draw_rect(rect, a_color)

	# Grid lines
	for i in range(NUM_NOTES + 1):
		var x: float = i * bar_w
		_bar_canvas.draw_line(Vector2(x, 0), Vector2(x, sz.y), Color(0.2, 0.2, 0.24), 1.0)
	for j in range(0, MAX_NOTE_VAL + 1, 8):
		var y: float = sz.y - (float(j) / float(MAX_NOTE_VAL)) * sz.y
		_bar_canvas.draw_line(Vector2(0, y), Vector2(sz.x, y), Color(0.18, 0.18, 0.22), 1.0)


func _on_bar_input(event: InputEvent) -> void:
	# Keyboard shortcuts: Ctrl+Z = Undo, Ctrl+Y = Redo
	if event is InputEventKey and event.pressed:
		if event.ctrl_pressed and event.keycode == KEY_Z and not event.shift_pressed:
			_bar_undo()
			return
		if event.ctrl_pressed and (event.keycode == KEY_Y or (event.keycode == KEY_Z and event.shift_pressed)):
			_bar_redo()
			return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_begin_bar_stroke()
				is_painting = true
				_paint_bar(event.position)
			else:
				is_painting = false
				_end_bar_stroke()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_begin_bar_stroke()
			_erase_bar(event.position)
			_end_bar_stroke()
	elif event is InputEventMouseMotion and is_painting:
		_paint_bar(event.position)


func _paint_bar(pos: Vector2) -> void:
	var sz = _bar_canvas.size
	var bar_w: float = sz.x / float(NUM_NOTES)
	var idx: int = int(pos.x / bar_w)
	if idx < 0 or idx >= NUM_NOTES:
		return
	var val: int = int((1.0 - pos.y / sz.y) * MAX_NOTE_VAL)
	val = clampi(val, 0, MAX_NOTE_VAL)

	var keys = ["voice1_notes", "voice2_notes", "filter_notes"]
	sounds[selected_sound][keys[active_voice]][idx] = val
	_bar_canvas.queue_redraw()
	sound_changed.emit(selected_sound)


func _erase_bar(pos: Vector2) -> void:
	var sz = _bar_canvas.size
	var bar_w: float = sz.x / float(NUM_NOTES)
	var idx: int = int(pos.x / bar_w)
	if idx < 0 or idx >= NUM_NOTES:
		return
	var keys = ["voice1_notes", "voice2_notes", "filter_notes"]
	sounds[selected_sound][keys[active_voice]][idx] = 0
	_bar_canvas.queue_redraw()
	sound_changed.emit(selected_sound)


# ─── Undo/Redo for bar painting ──────────────────────────────

func _begin_bar_stroke() -> void:
	var snd = sounds[selected_sound]
	_stroke_snapshot = {
		"idx": selected_sound,
		"v1": snd["voice1_notes"].duplicate(),
		"v2": snd["voice2_notes"].duplicate(),
		"flt": snd["filter_notes"].duplicate(),
	}


func _end_bar_stroke() -> void:
	if _stroke_snapshot == null:
		return
	var snd = sounds[selected_sound]
	if snd["voice1_notes"] != _stroke_snapshot["v1"] or snd["voice2_notes"] != _stroke_snapshot["v2"] or snd["filter_notes"] != _stroke_snapshot["flt"]:
		_undo_stack.append(_stroke_snapshot)
		if _undo_stack.size() > MAX_UNDO:
			_undo_stack.pop_front()
		_redo_stack.clear()
	_stroke_snapshot = null


func _bar_undo() -> void:
	if _undo_stack.is_empty():
		_status_lbl.text = "Nothing to undo"
		return
	var snap = _undo_stack.pop_back()
	var si: int = snap["idx"]
	_redo_stack.append({
		"idx": si,
		"v1": sounds[si]["voice1_notes"].duplicate(),
		"v2": sounds[si]["voice2_notes"].duplicate(),
		"flt": sounds[si]["filter_notes"].duplicate(),
	})
	sounds[si]["voice1_notes"] = snap["v1"]
	sounds[si]["voice2_notes"] = snap["v2"]
	sounds[si]["filter_notes"] = snap["flt"]
	if si == selected_sound:
		_bar_canvas.queue_redraw()
	_status_lbl.text = "Undo (" + str(_undo_stack.size()) + " remaining)"


func _bar_redo() -> void:
	if _redo_stack.is_empty():
		_status_lbl.text = "Nothing to redo"
		return
	var snap = _redo_stack.pop_back()
	var si: int = snap["idx"]
	_undo_stack.append({
		"idx": si,
		"v1": sounds[si]["voice1_notes"].duplicate(),
		"v2": sounds[si]["voice2_notes"].duplicate(),
		"flt": sounds[si]["filter_notes"].duplicate(),
	})
	sounds[si]["voice1_notes"] = snap["v1"]
	sounds[si]["voice2_notes"] = snap["v2"]
	sounds[si]["filter_notes"] = snap["flt"]
	if si == selected_sound:
		_bar_canvas.queue_redraw()
	_status_lbl.text = "Redo (" + str(_redo_stack.size()) + " remaining)"

# ─── Callbacks ───────────────────────────────────────────────

func _on_name_changed(new_text: String) -> void:
	sounds[selected_sound]["name"] = new_text
	_refresh_sound_list()

func _on_sound_selected(idx: int) -> void:
	selected_sound = idx
	_refresh_ui()

func _on_voice_btn(idx: int) -> void:
	active_voice = idx
	# Enable the selected voice so it will be drawn and heard
	var enable_keys = ["voice1_enabled", "voice2_enabled", "filter_enabled"]
	sounds[selected_sound][enable_keys[idx]] = true
	for i in range(_voice_btns.size()):
		_voice_btns[i].button_pressed = (i == idx)
	_bar_canvas.queue_redraw()
	var names = ["Voice 1", "Voice 2", "Filter"]
	_status_lbl.text = "Editing: " + names[idx]

func _on_tempo_changed(val: float) -> void:
	sounds[selected_sound]["tempo"] = int(val)
	sound_changed.emit(selected_sound)

func _on_wave1_changed(idx: int) -> void:
	sounds[selected_sound]["voice1_wave"] = idx
	sound_changed.emit(selected_sound)

func _on_wave2_changed(idx: int) -> void:
	sounds[selected_sound]["voice2_wave"] = idx
	sound_changed.emit(selected_sound)

func _on_filt_changed(idx: int) -> void:
	sounds[selected_sound]["filter_type"] = idx
	sound_changed.emit(selected_sound)

func _on_filt_q_changed(val: float) -> void:
	sounds[selected_sound]["filter_q"] = int(val)
	sound_changed.emit(selected_sound)


# ─── Audio Playback ──────────────────────────────────────────

func _on_play_sound() -> void:
	if not is_instance_valid(_audio_player):
		_audio_player = AudioStreamPlayer.new()
		_audio_player.finished.connect(_on_playback_finished)
		add_child(_audio_player)
	_audio_player.stop()
	var snd = sounds[selected_sound]
	var wav_path: String = snd.get("custom_wav", "")
	var stream: AudioStream = null
	if not wav_path.is_empty():
		stream = _load_wav_file(wav_path)
		if stream == null:
			_status_lbl.text = "⚠ Cannot load WAV: " + wav_path.get_file()
			return
	else:
		stream = _generate_audio_stream()
	if stream:
		_audio_player.stream = stream
		_audio_player.play()
		_status_lbl.text = "▶ Playing Sound " + str(selected_sound + 1) + "…"
	else:
		_status_lbl.text = "⚠ No notes to play — paint some bars first!"


func _on_stop_sound() -> void:
	if is_instance_valid(_audio_player) and _audio_player.playing:
		_audio_player.stop()
	_status_lbl.text = "⏹ Stopped"


func _on_playback_finished() -> void:
	_status_lbl.text = "✓ Playback complete"


## Load a WAV file from disk and return an AudioStreamWAV.
func _load_wav_file(path: String) -> AudioStreamWAV:
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var riff = f.get_buffer(4)
	if riff.size() < 4 or riff.get_string_from_ascii() != "RIFF":
		return null
	var _file_size = f.get_32()
	var wave = f.get_buffer(4)
	if wave.size() < 4 or wave.get_string_from_ascii() != "WAVE":
		return null
	var sample_rate := 44100
	var bits_per_sample := 16
	var channels := 1
	var pcm_data := PackedByteArray()
	while f.get_position() < f.get_length():
		var chunk_id_buf = f.get_buffer(4)
		if chunk_id_buf.size() < 4:
			break
		var chunk_id = chunk_id_buf.get_string_from_ascii()
		var chunk_size = f.get_32()
		if chunk_id == "fmt ":
			var _audio_format = f.get_16()  # 1 = PCM
			channels = f.get_16()
			sample_rate = f.get_32()
			var _byte_rate = f.get_32()
			var _block_align = f.get_16()
			bits_per_sample = f.get_16()
			if chunk_size > 16:
				f.get_buffer(chunk_size - 16)
		elif chunk_id == "data":
			pcm_data = f.get_buffer(chunk_size)
		else:
			f.get_buffer(chunk_size)
		# WAV chunks are word-aligned
		if chunk_size % 2 != 0 and f.get_position() < f.get_length():
			f.get_8()
	if pcm_data.is_empty():
		return null
	var stream = AudioStreamWAV.new()
	stream.data = pcm_data
	stream.format = AudioStreamWAV.FORMAT_16_BITS if bits_per_sample >= 16 else AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = channels >= 2
	return stream


func _on_import_wav() -> void:
	if _file_dialog == null:
		_file_dialog = FileDialog.new()
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_file_dialog.filters = PackedStringArray(["*.wav ; WAV Audio Files"])
		_file_dialog.title = "Import WAV Sound"
		_file_dialog.size = Vector2i(700, 450)
		_file_dialog.file_selected.connect(_on_wav_selected)
		add_child(_file_dialog)
	_file_dialog.popup_centered()


func _on_wav_selected(path: String) -> void:
	# Verify it's a valid WAV file
	var test_stream = _load_wav_file(path)
	if test_stream == null:
		_status_lbl.text = "⚠ Invalid WAV file — must be PCM format"
		return
	sounds[selected_sound]["custom_wav"] = path
	_status_lbl.text = "📎 Imported: " + path.get_file()
	sound_changed.emit(selected_sound)
	_refresh_sound_list()
	_refresh_ui()


func _on_clear_wav() -> void:
	sounds[selected_sound]["custom_wav"] = ""
	_status_lbl.text = "✓ Custom WAV removed — using synth"
	sound_changed.emit(selected_sound)
	_refresh_sound_list()
	_refresh_ui()


func _on_open_vgsfx() -> void:
	# Open VGSFX (port of bfxr2) in a popup window. When the user
	# exports a WAV from inside VGSFX, the path is automatically piped
	# into the currently selected sound slot's custom_wav field.
	var dock_script_path := "res://addons/visual_gasic/plugins/vgsfx/vgsfx_dock.gd"
	if not ResourceLoader.exists(dock_script_path):
		_status_lbl.text = "⚠ VGSFX plugin not installed (addons/visual_gasic/plugins/vgsfx)"
		return
	if _vgsfx_window != null and is_instance_valid(_vgsfx_window):
		_vgsfx_window.popup_centered()
		return
	_vgsfx_window = Window.new()
	_vgsfx_window.title = "VGSFX — Synthesizer (Bfxr2 port)"
	_vgsfx_window.size = Vector2i(420, 720)
	_vgsfx_window.exclusive = false
	_vgsfx_window.close_requested.connect(func() -> void:
		if _vgsfx_window:
			_vgsfx_window.hide()
	)
	var dock_script: GDScript = load(dock_script_path)
	var dock = dock_script.new()
	# The dock targets a specific sound slot at the moment of opening.
	var target_idx: int = selected_sound
	dock.wav_exported.connect(func(path: String) -> void:
		if target_idx >= 0 and target_idx < sounds.size():
			sounds[target_idx]["custom_wav"] = path
			_status_lbl.text = "🎛 VGSFX → slot %d: %s" % [target_idx + 1, path.get_file()]
			sound_changed.emit(target_idx)
			_refresh_sound_list()
			if target_idx == selected_sound:
				_refresh_ui()
	)
	_vgsfx_window.add_child(dock)
	add_child(_vgsfx_window)
	_vgsfx_window.popup_centered()


func _note_to_freq(val: int) -> float:
	if val <= 0:
		return 0.0
	# Chromatic scale: C2 (65 Hz) up 48 semitones to C6 (1047 Hz)
	return NOTE_BASE_HZ * pow(2.0, float(val - 1) / 12.0)


func _wave_sample(phase: float, waveform: int) -> float:
	match waveform:
		0:  # Square
			return 1.0 if phase < 0.5 else -1.0
		1:  # Triangle
			if phase < 0.25:
				return phase * 4.0
			elif phase < 0.75:
				return 2.0 - phase * 4.0
			else:
				return phase * 4.0 - 4.0
		2:  # Sawtooth
			return 2.0 * phase - 1.0
		3:  # Noise
			return randf_range(-1.0, 1.0)
	return 0.0


func _generate_audio_stream() -> AudioStreamWAV:
	var snd = sounds[selected_sound]
	var tempo: int = snd.get("tempo", 120)
	var beats_per_sec: float = float(tempo) / 60.0
	var note_dur: float = 1.0 / beats_per_sec
	var samples_per_note: int = int(float(SAMPLE_RATE) * note_dur)
	var total_samples: int = samples_per_note * NUM_NOTES
	var env_samples: int = maxi(1, int(float(SAMPLE_RATE) * float(ENVELOPE_MS) / 1000.0))

	var v1_notes: Array = snd["voice1_notes"]
	var v2_notes: Array = snd["voice2_notes"]
	var flt_notes: Array = snd["filter_notes"]
	var v1_wave: int = snd.get("voice1_wave", 0)
	var v2_wave: int = snd.get("voice2_wave", 1)
	var flt_type: int = snd.get("filter_type", 0)
	var flt_q_pct: int = snd.get("filter_q", 50)

	# Auto-detect which voices have content (play anything with painted bars)
	var v1_active: bool = false
	var v2_active: bool = false
	var flt_active: bool = false
	for i in range(NUM_NOTES):
		if v1_notes[i] > 0:
			v1_active = true
		if v2_notes[i] > 0:
			v2_active = true
		if flt_notes[i] > 0:
			flt_active = true

	if not v1_active and not v2_active:
		return null

	var pcm = PackedByteArray()
	pcm.resize(total_samples * 2)  # 16-bit mono

	var v1_phase: float = 0.0
	var v2_phase: float = 0.0
	var v1_vol: float = float(snd.get("voice1_volume", 80)) / 100.0
	var v2_vol: float = float(snd.get("voice2_volume", 60)) / 100.0
	var flt_prev: float = 0.0  # one-pole filter state

	for ni in range(NUM_NOTES):
		var v1_freq: float = _note_to_freq(v1_notes[ni]) if v1_active else 0.0
		var v2_freq: float = _note_to_freq(v2_notes[ni]) if v2_active else 0.0
		var flt_cutoff: float = 0.0
		if flt_active and flt_type > 0 and ni < flt_notes.size() and flt_notes[ni] > 0:
			flt_cutoff = _note_to_freq(flt_notes[ni])

		for s in range(samples_per_note):
			var sample: float = 0.0

			if v1_freq > 0.0:
				sample += _wave_sample(v1_phase, v1_wave) * 0.45 * v1_vol
				v1_phase = fmod(v1_phase + v1_freq / float(SAMPLE_RATE), 1.0)

			if v2_freq > 0.0:
				sample += _wave_sample(v2_phase, v2_wave) * 0.35 * v2_vol
				v2_phase = fmod(v2_phase + v2_freq / float(SAMPLE_RATE), 1.0)

			# One-pole filter (when filter voice has content)
			if flt_cutoff > 0.0:
				var rc: float = 1.0 / (TAU * flt_cutoff)
				var dt: float = 1.0 / float(SAMPLE_RATE)
				var alpha: float = dt / (rc + dt)
				var lp: float = flt_prev + alpha * (sample - flt_prev)
				flt_prev = lp
				match flt_type:
					1:  sample = lp                                     # LowPass
					2:  sample = sample - lp                              # HighPass
					3:                                                     # BandPass
						var res: float = 0.1 + float(flt_q_pct) / 100.0 * 4.0
						sample = clampf((sample - lp) * res, -1.0, 1.0)
			else:
				flt_prev = sample

			# Envelope — short attack/release to avoid clicks
			var env: float = 1.0
			if s < env_samples:
				env = float(s) / float(env_samples)
			elif s > samples_per_note - env_samples:
				env = float(samples_per_note - s) / float(env_samples)
			sample *= env

			# 16-bit PCM little-endian signed
			var pcm_val: int = int(clampf(sample, -1.0, 1.0) * 32767.0)
			var off: int = (ni * samples_per_note + s) * 2
			pcm[off] = pcm_val & 0xFF
			pcm[off + 1] = (pcm_val >> 8) & 0xFF

	var stream = AudioStreamWAV.new()
	stream.data = pcm
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	return stream


# ─── Refresh ─────────────────────────────────────────────────

func _refresh_sound_list() -> void:
	_sound_opt.clear()
	for i in range(sounds.size()):
		var snd_name: String = sounds[i].get("name", "Sound")
		var prefix: String = "📎 " if not sounds[i].get("custom_wav", "").is_empty() else ""
		_sound_opt.add_item(str(i + 1) + ": " + prefix + snd_name)
	if selected_sound >= 0 and selected_sound < sounds.size():
		_sound_opt.selected = selected_sound


func _refresh_ui() -> void:
	if selected_sound < 0 or selected_sound >= sounds.size():
		return
	var snd = sounds[selected_sound]
	_tempo_slider.value = snd.get("tempo", 120)
	_wave_opt1.selected = snd.get("voice1_wave", 0)
	_wave_opt2.selected = snd.get("voice2_wave", 1)
	_filt_opt.selected = snd.get("filter_type", 0)
	_filt_q_slider.value = snd.get("filter_q", 50)
	if is_instance_valid(_name_edit):
		_name_edit.text = snd.get("name", "Sound")
	if is_instance_valid(_vol1_slider):
		_vol1_slider.value = snd.get("voice1_volume", 80)
	if is_instance_valid(_vol2_slider):
		_vol2_slider.value = snd.get("voice2_volume", 60)
	# Custom WAV indicator
	var wav_path: String = snd.get("custom_wav", "")
	if is_instance_valid(_wav_label):
		if wav_path.is_empty():
			_wav_label.visible = false
			_wav_label.text = ""
		else:
			_wav_label.visible = true
			_wav_label.text = "📎 " + wav_path.get_file()
	if is_instance_valid(_clear_wav_btn):
		_clear_wav_btn.visible = not wav_path.is_empty()
	if is_instance_valid(_bar_canvas):
		_bar_canvas.queue_redraw()


# ─── Public API for other editors ────────────────────────────

## Returns an array of sound names, e.g. ["(None)", "Jump", "Coin", "Hit", ...]
## Includes every sound that has at least one note painted OR has a
## non-generic name (i.e. a preset name like "Jump" rather than "Sound 1").
func get_sound_names(include_none: bool = true) -> Array:
	var result: Array = []
	if include_none:
		result.append("(None)")
	for si in range(sounds.size()):
		var snd = sounds[si]
		var snd_name: String = snd.get("name", "Sound " + str(si + 1))
		var has_content: bool = not snd.get("custom_wav", "").is_empty()
		if not has_content:
			for n in snd.get("voice1_notes", []):
				if n > 0:
					has_content = true
					break
		if not has_content:
			for n in snd.get("voice2_notes", []):
				if n > 0:
					has_content = true
					break
		# Include if it has notes/wav, OR if it has a real (non-generic) name
		var is_generic := snd_name == "Sound " + str(si + 1) or snd_name == "Sound_" + str(si + 1) or snd_name.is_empty()
		if has_content or not is_generic:
			result.append(snd_name)
	return result


## Play a sound by name (for actor editor preview).
func play_sound_by_name(snd_name: String) -> void:
	for si in range(sounds.size()):
		if sounds[si].get("name", "") == snd_name:
			var prev_selected = selected_sound
			selected_sound = si
			_on_play_sound()
			selected_sound = prev_selected
			return
	# Fallback: try case-insensitive match
	var lower_name := snd_name.to_lower()
	for si in range(sounds.size()):
		if sounds[si].get("name", "").to_lower() == lower_name:
			var prev_selected = selected_sound
			selected_sound = si
			_on_play_sound()
			selected_sound = prev_selected
			return


# ─── Serialization ───────────────────────────────────────────

## The 8 preset factory methods, indexed 0–7.
func _get_preset(idx: int) -> Dictionary:
	match idx:
		0: return _preset_jump()
		1: return _preset_coin()
		2: return _preset_hit()
		3: return _preset_hero_death()
		4: return _preset_enemy_death()
		5: return _preset_shoot()
		6: return _preset_powerup()
		7: return _preset_game_over()
	return _make_empty_sound(idx + 1)


func get_data() -> Array:
	return sounds.duplicate(true)


func set_data(data: Array) -> void:
	sounds = data.duplicate(true)
	while sounds.size() < MAX_SOUNDS:
		sounds.append(_make_empty_sound(sounds.size() + 1))
	# ── Restore presets for empty / generic-named slots ──────────
	# Generic names ("Sound 1" … "Sound 8") are always upgraded:
	#   • No notes → full preset replacement (notes + name)
	#   • Has notes → rename to preset name, keep user's notes/wav
	# This ensures actor sound references ("Jump", "Coin"…) resolve.
	for i in range(mini(sounds.size(), MAX_SOUNDS)):
		var snd: Dictionary = sounds[i]
		var snd_name: String = snd.get("name", "")
		var is_generic := snd_name == "Sound " + str(i + 1) or snd_name == "Sound_" + str(i + 1) or snd_name.is_empty()
		if not is_generic:
			continue
		# Check whether ANY notes are painted or custom WAV is set
		var has_content: bool = not snd.get("custom_wav", "").is_empty()
		if not has_content:
			for n in snd.get("voice1_notes", []):
				if n > 0:
					has_content = true
					break
		if not has_content:
			for n in snd.get("voice2_notes", []):
				if n > 0:
					has_content = true
					break
		if not has_content:
			# Empty slot → restore full preset
			sounds[i] = _get_preset(i)
		else:
			# Has user content but generic name → rename to preset name
			var preset = _get_preset(i)
			sounds[i]["name"] = preset["name"]
	selected_sound = 0
	_refresh_sound_list()
	_refresh_ui()
