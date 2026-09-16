# VGSFX — Editor dock UI.
#
# Top: 12 wave-type buttons (radio-style)
# Middle: preset buttons (Pickup, Laser, Explosion, Powerup, Hit, Jump, Blip, Random, Mutate)
# Below that: scrollable list of parameter sliders (with lock checkbox + numeric value)
# Bottom: ▶ Play / 💾 Export WAV / 📂 Load .bfxr / 💾 Save .bfxr

@tool
extends VBoxContainer

const VGSFXSynth_ := preload("res://addons/visual_gasic/plugins/vgsfx/vgsfx_synth.gd")
const VGSFXDSP_ := preload("res://addons/visual_gasic/plugins/vgsfx/vgsfx_dsp.gd")

# Process-wide bus — used to announce wav/bfxr writes so the file
# browser and any other open audio editor can refresh on save.
const _AssetBus := preload("res://addons/visual_gasic/vg_asset_bus.gd")
const _ASSET_PLUGIN_ID := "vgsfx"

# Emitted after a successful WAV export. Listeners can pipe the path
# into their own tooling (e.g. AGCK sound editor's custom_wav slot).
signal wav_exported(path: String)

const BG := Color(0.831, 0.816, 0.784)        # VB sys_button_face #D4D0C8
const PANEL_BG := Color(0.941, 0.929, 0.910)  # VB panel_background #F0EDE8
const ACCENT := Color(0.0, 0.0, 0.5)          # VB sys_active_title (navy)
const TXT := Color(0.0, 0.0, 0.0)             # VB sys_window_text
const TXT_DIM := Color(0.4, 0.4, 0.4)         # darker gray for hints
const BTN_BG := Color(0.831, 0.816, 0.784)    # sys_button_face
const BTN_HI := Color(1.0, 1.0, 1.0)          # sys_button_highlight (top/left)
const BTN_SH := Color(0.51, 0.51, 0.51)       # sys_button_shadow (bot/right)
const BTN_DSH := Color(0.25, 0.25, 0.25)      # sys_3d_dark_shadow
const BTN_HOVER := Color(0.91, 0.95, 1.0)     # toolbox hover blue tint
const BTN_PRESS := Color(0.26, 0.59, 0.98)    # toolbox pressed blue
const LOCK_ON := Color(0.85, 0.45, 0.20)
const HEADER_BG := Color(0.0, 0.0, 0.5)       # navy title-bar background
const HEADER_TXT := Color(1.0, 1.0, 1.0)

var _synth = null
var _player: AudioStreamPlayer = null
var _file_dlg: FileDialog = null
var _file_dlg_mode: String = ""  # "export_wav" / "save_bfxr" / "load_bfxr"

# UI refs (built in code)
var _wave_btns: Array = []  # Array of [Button, wave_index]
var _param_rows: Array = [] # Array of {name, slider, label, value_label, lock}
var _status_lbl: Label = null


func _init() -> void:
	_synth = VGSFXSynth_.new()
	custom_minimum_size = Vector2(360, 600)


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)

	_file_dlg = FileDialog.new()
	_file_dlg.access = FileDialog.ACCESS_FILESYSTEM
	_file_dlg.use_native_dialog = false
	_file_dlg.file_selected.connect(_on_file_dialog)
	add_child(_file_dlg)

	_build_ui()
	_refresh_all_from_synth()


# ─────────────────────────────────────────────────────────────
# UI construction
# ─────────────────────────────────────────────────────────────
func _make_btn(text: String, tooltip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	if tooltip != "":
		b.tooltip_text = tooltip

	# VB6-style raised button: light highlight on top/left, dark shadow on
	# bottom/right (achieved with asymmetric border colors).
	var s := StyleBoxFlat.new()
	s.bg_color = BTN_BG
	s.border_color = BTN_HI       # all four sides (overridden per-edge below)
	s.border_width_top = 1
	s.border_width_left = 1
	s.border_width_right = 2      # thicker dark edge for 3D feel
	s.border_width_bottom = 2
	# StyleBoxFlat only supports one border_color, so use an overlay via
	# corner_radius=0 with a contrasting expand_margin to fake a bevel.
	s.set_corner_radius_all(0)
	s.content_margin_left = 8; s.content_margin_right = 8
	s.content_margin_top = 3; s.content_margin_bottom = 3
	b.add_theme_stylebox_override("normal", s)

	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = BTN_HOVER
	h.border_color = Color(0.55, 0.73, 0.95)  # toolbox_btn_hover_border
	b.add_theme_stylebox_override("hover", h)

	# Pressed: invert bevel — dark on top/left, light on bottom/right —
	# and use accent fill so toggle_mode buttons (wave types) clearly
	# show the active selection.
	var p := s.duplicate() as StyleBoxFlat
	p.bg_color = BTN_PRESS
	p.border_color = BTN_DSH
	b.add_theme_stylebox_override("pressed", p)

	# In Godot 4, toggle_mode buttons stay pressed via the same "pressed"
	# stylebox, so no separate "checked" state is required.

	b.add_theme_color_override("font_color", TXT)
	b.add_theme_color_override("font_hover_color", TXT)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_font_size_override("font_size", 11)
	return b


func _section_label(text: String) -> Label:
	# VB6 group-box header strip: navy bar with white bold text.
	var l := Label.new()
	l.text = "  " + text
	var ls := LabelSettings.new()
	ls.font_size = 11
	ls.font_color = HEADER_TXT
	l.label_settings = ls
	# Wrap in a styled PanelContainer? No — just use a stylebox override
	# on the Label by drawing a background via a sibling. Simpler: use
	# Label.add_theme_stylebox_override("normal", ...) — Labels honor a
	# "normal" stylebox if present.
	var sb := StyleBoxFlat.new()
	sb.bg_color = HEADER_BG
	sb.content_margin_left = 4; sb.content_margin_right = 4
	sb.content_margin_top = 2; sb.content_margin_bottom = 2
	l.add_theme_stylebox_override("normal", sb)
	return l


func _build_ui() -> void:
	add_theme_constant_override("separation", 6)

	# Apply panel background so the dock doesn't show through to whatever
	# ancestor container's color it lands on. The wrapper plugin sets its
	# own dark-themed background, so we explicitly paint VB warm-gray here.
	# (VBoxContainer doesn't accept a stylebox directly — wrap children in
	# a PanelContainer instead. We do that by sandwiching the entire UI in
	# a PanelContainer at the top.)

	add_child(_section_label("Wave Type"))

	# Wave-type buttons (4-column grid)
	var wave_grid := GridContainer.new()
	wave_grid.columns = 4
	wave_grid.add_theme_constant_override("h_separation", 3)
	wave_grid.add_theme_constant_override("v_separation", 3)
	add_child(wave_grid)
	# Names in display order, mapping back to indices
	var name_by_index := {}
	for k in VGSFXSynth_.WAVE_NAMES.keys():
		name_by_index[VGSFXSynth_.WAVE_NAMES[k]] = k
	for idx in VGSFXSynth_.WAVE_DISPLAY_ORDER:
		var nm: String = name_by_index[idx]
		var b := _make_btn(nm, "Wave type %d: %s" % [idx, nm])
		b.toggle_mode = true
		b.pressed.connect(_on_wave_pressed.bind(idx))
		wave_grid.add_child(b)
		_wave_btns.append([b, idx])

	# Generators
	add_child(_section_label("Generators"))
	var gen_grid := GridContainer.new()
	gen_grid.columns = 3
	gen_grid.add_theme_constant_override("h_separation", 3)
	gen_grid.add_theme_constant_override("v_separation", 3)
	add_child(gen_grid)
	for tpl in VGSFXSynth_.TEMPLATES:
		var disp: String = tpl[0]
		var method: String = tpl[1]
		var b := _make_btn(disp)
		b.pressed.connect(_on_generator_pressed.bind(method))
		gen_grid.add_child(b)

	add_child(_section_label("Parameters"))

	# Parameter sliders inside a scroll
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 280)
	add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	scroll.add_child(col)

	for info in VGSFXSynth_.PARAM_INFO:
		if info["kind"] != "RANGE":
			continue
		if info["name"] == "masterVolume":
			continue  # hidden, permalocked
		_build_param_row(col, info)

	# Bottom buttons
	add_child(_section_label("Playback / Export"))
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	add_child(btn_row)
	var play_btn := _make_btn("▶ Play", "Generate and play the current sound")
	play_btn.pressed.connect(_on_play)
	play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(play_btn)
	var export_btn := _make_btn("💾 Export WAV", "Export current sound as a 16-bit mono .wav")
	export_btn.pressed.connect(_on_export_wav)
	export_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(export_btn)

	var btn_row2 := HBoxContainer.new()
	btn_row2.add_theme_constant_override("separation", 4)
	add_child(btn_row2)
	var save_btn := _make_btn("💾 Save .bfxr", "Save current parameters as a .bfxr (JSON) preset")
	save_btn.pressed.connect(_on_save_bfxr)
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row2.add_child(save_btn)
	var load_btn := _make_btn("📂 Load .bfxr", "Load a .bfxr preset")
	load_btn.pressed.connect(_on_load_bfxr)
	load_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row2.add_child(load_btn)

	_status_lbl = Label.new()
	_status_lbl.text = "Ready"
	var sls := LabelSettings.new()
	sls.font_size = 10
	sls.font_color = TXT_DIM
	_status_lbl.label_settings = sls
	add_child(_status_lbl)


func _build_param_row(parent: VBoxContainer, info: Dictionary) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	parent.add_child(row)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	row.add_child(top)

	# Lock checkbox
	var lock := CheckBox.new()
	lock.text = "🔒"
	lock.tooltip_text = "Lock this parameter — won't change on Randomize / Mutate / generators"
	lock.toggled.connect(_on_lock_toggled.bind(info["name"]))
	top.add_child(lock)

	# Display name
	var lbl := Label.new()
	lbl.text = info["display"]
	if info.has("tooltip"):
		lbl.tooltip_text = info["tooltip"]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lls := LabelSettings.new()
	lls.font_size = 10
	lls.font_color = TXT
	lbl.label_settings = lls
	top.add_child(lbl)

	var value_lbl := Label.new()
	value_lbl.text = "0.00"
	value_lbl.custom_minimum_size.x = 50
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var vls := LabelSettings.new()
	vls.font_size = 10
	vls.font_color = TXT_DIM
	value_lbl.label_settings = vls
	top.add_child(value_lbl)

	var sl := HSlider.new()
	sl.min_value = info["min"]
	sl.max_value = info["max"]
	sl.step = 0.001
	sl.value = info["default"]
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.value_changed.connect(_on_slider_changed.bind(info["name"]))
	row.add_child(sl)

	_param_rows.append({
		"name": info["name"],
		"slider": sl,
		"label": lbl,
		"value_label": value_lbl,
		"lock": lock,
	})


# ─────────────────────────────────────────────────────────────
# Sync UI ↔ synth
# ─────────────────────────────────────────────────────────────
func _refresh_all_from_synth() -> void:
	# Wave buttons
	var current_wave := int(_synth.get_param("waveType"))
	for entry in _wave_btns:
		var b: Button = entry[0]
		var idx: int = entry[1]
		b.button_pressed = (idx == current_wave)

	# Sliders
	for row in _param_rows:
		var name: String = row["name"]
		var sl: HSlider = row["slider"]
		var vl: Label = row["value_label"]
		sl.set_block_signals(true)
		sl.value = _synth.get_param(name)
		sl.set_block_signals(false)
		vl.text = "%.3f" % _synth.get_param(name)
		# Disabled state
		var disabled = _synth.param_is_disabled(name)
		sl.editable = not disabled
		row["label"].modulate = Color(1, 1, 1, 0.4 if disabled else 1.0)


func _on_wave_pressed(idx: int) -> void:
	_synth.set_param("waveType", idx, true)
	_refresh_all_from_synth()


func _on_slider_changed(value: float, name: String) -> void:
	_synth.set_param(name, value, false)
	# Refresh value label only (avoid full UI churn)
	for row in _param_rows:
		if row["name"] == name:
			row["value_label"].text = "%.3f" % value
			break
	# squareDuty / frequency_slide changes can re-enable/disable other params
	if name == "frequency_slide" or name == "frequency_acceleration":
		_refresh_all_from_synth()


func _on_lock_toggled(pressed: bool, name: String) -> void:
	_synth.set_locked_param(name, pressed)


func _on_generator_pressed(method: String) -> void:
	if not _synth.has_method(method):
		_status("⚠ Unknown generator: " + method)
		return
	_synth.call(method)
	_refresh_all_from_synth()
	_play_current()
	_status("Generated: " + method.replace("generate_", "").replace("_", " "))


func _on_play() -> void:
	_play_current()


func _play_current() -> void:
	var stream = _synth.to_audio_stream_wav()
	_player.stream = stream
	_player.play()
	_status("Playing — %d samples (%.2fs)" % [_synth.last_buffer.size(), _synth.last_buffer.size() / float(VGSFXDSP_.SAMPLE_RATE)])


func _status(msg: String) -> void:
	if _status_lbl:
		_status_lbl.text = msg


# ─────────────────────────────────────────────────────────────
# File dialog plumbing
# ─────────────────────────────────────────────────────────────
func _on_export_wav() -> void:
	_file_dlg_mode = "export_wav"
	_file_dlg.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_file_dlg.filters = PackedStringArray(["*.wav ; WAV audio"])
	_file_dlg.current_file = "sfx.wav"
	_file_dlg.popup_centered_ratio(0.6)


func _on_save_bfxr() -> void:
	_file_dlg_mode = "save_bfxr"
	_file_dlg.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_file_dlg.filters = PackedStringArray(["*.bfxr ; Bfxr preset (JSON)"])
	_file_dlg.current_file = "sound.bfxr"
	_file_dlg.popup_centered_ratio(0.6)


func _on_load_bfxr() -> void:
	_file_dlg_mode = "load_bfxr"
	_file_dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dlg.filters = PackedStringArray(["*.bfxr ; Bfxr preset (JSON)"])
	_file_dlg.popup_centered_ratio(0.6)


func _on_file_dialog(path: String) -> void:
	match _file_dlg_mode:
		"export_wav":
			_export_wav(path)
		"save_bfxr":
			_save_bfxr(path)
		"load_bfxr":
			_load_bfxr(path)


func _export_wav(path: String) -> void:
	# Make sure we have a fresh buffer
	_synth.generate_sound()
	var n = _synth.last_buffer.size()
	if n == 0:
		_status("⚠ Empty buffer; nothing to export")
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if not f:
		_status("⚠ Cannot write: " + path)
		return
	var sr := VGSFXDSP_.SAMPLE_RATE
	var byte_rate := sr * 2
	var data_size = n * 2
	# RIFF header
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + data_size)
	f.store_buffer("WAVE".to_ascii_buffer())
	f.store_buffer("fmt ".to_ascii_buffer())
	f.store_32(16)            # fmt chunk size
	f.store_16(1)             # PCM
	f.store_16(1)             # mono
	f.store_32(sr)
	f.store_32(byte_rate)
	f.store_16(2)             # block align
	f.store_16(16)            # bits per sample
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data_size)
	for i in range(n):
		var s = clamp(_synth.last_buffer[i], -1.0, 1.0)
		f.store_16(int(round(s * 32767.0)) & 0xFFFF)
	f.close()
	_status("Exported: " + path.get_file())
	wav_exported.emit(path)
	_AssetBus.get_instance().emit_saved(path, _ASSET_PLUGIN_ID)


func _save_bfxr(path: String) -> void:
	var d = _synth.save_to_dictionary()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if not f:
		_status("⚠ Cannot write: " + path)
		return
	f.store_string(JSON.stringify(d, "  "))
	f.close()
	_status("Saved preset: " + path.get_file())
	_AssetBus.get_instance().emit_saved(path, _ASSET_PLUGIN_ID)


func _load_bfxr(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		_status("⚠ Cannot read: " + path)
		return
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_status("⚠ Invalid .bfxr (not a JSON object)")
		return
	_synth.load_from_dictionary(parsed)
	_refresh_all_from_synth()
	_status("Loaded preset: " + path.get_file())
