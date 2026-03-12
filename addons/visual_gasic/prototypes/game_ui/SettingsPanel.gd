@tool
extends PanelContainer
## Game UI — Settings/options panel with audio, video, and controls sections.

signal setting_changed(key: String, value: Variant)
signal settings_applied
signal settings_cancelled

# ── VB6-style properties ──────────────────────────────────────

@export var PanelTitle: String = "SETTINGS":
	set(v):
		PanelTitle = v
		if _title_label: _title_label.text = v

@export var ShowAudio: bool = true
@export var ShowVideo: bool = true
@export var ShowControls: bool = true
@export_enum("FadeIn", "ScaleUp", "SlideDown", "None") var ShowAnimation: int = 0
@export var TransitionSpeed: float = 0.3

var _title_label: Label
var _tween: Tween

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	for c in get_children(): c.queue_free()
	custom_minimum_size = Vector2(350, 300)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14, 0.95)
	style.border_color = Color(0.35, 0.4, 0.55, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = PanelTitle
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	if ShowAudio:
		_add_section(vbox, "Audio", [
			["Master Volume", "slider", 80],
			["Music Volume", "slider", 60],
			["SFX Volume", "slider", 70],
		])

	if ShowVideo:
		_add_section(vbox, "Video", [
			["Fullscreen", "check", true],
			["VSync", "check", true],
			["Resolution", "option", "1920x1080"],
		])

	if ShowControls:
		_add_section(vbox, "Controls", [
			["Mouse Sensitivity", "slider", 50],
			["Invert Y-Axis", "check", false],
		])

	# Buttons row
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var apply_btn := Button.new()
	apply_btn.text = "Apply"
	apply_btn.custom_minimum_size = Vector2(80, 28)
	btn_row.add_child(apply_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(80, 28)
	btn_row.add_child(cancel_btn)

	if Engine.is_editor_hint():
		visible = true
		modulate = Color(1, 1, 1, 1)

func _add_section(parent: VBoxContainer, title: String, items: Array) -> void:
	var section_label := Label.new()
	section_label.text = title
	section_label.add_theme_font_size_override("font_size", 13)
	section_label.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	parent.add_child(section_label)

	for item in items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		parent.add_child(row)

		var lbl := Label.new()
		lbl.text = item[0]
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		lbl.custom_minimum_size.x = 140
		row.add_child(lbl)

		match item[1]:
			"slider":
				var slider := HSlider.new()
				slider.min_value = 0
				slider.max_value = 100
				slider.value = item[2]
				slider.custom_minimum_size = Vector2(120, 20)
				slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(slider)
			"check":
				var check := CheckBox.new()
				check.button_pressed = item[2]
				row.add_child(check)
			"option":
				var opt := OptionButton.new()
				opt.add_item("1920x1080")
				opt.add_item("1280x720")
				opt.add_item("1024x768")
				opt.custom_minimum_size = Vector2(120, 24)
				row.add_child(opt)
