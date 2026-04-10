@tool
extends PanelContainer
## Game UI — Animated confirmation dialog with Yes/No buttons.

signal confirmed
signal cancelled

# ── VB6-style properties ──────────────────────────────────────

@export var DialogTitle: String = "Confirm":
	set(v):
		DialogTitle = v
		if _title_label: _title_label.text = v

@export var Message: String = "Are you sure?":
	set(v):
		Message = v
		if _message_label: _message_label.text = v

@export var YesText: String = "Yes":
	set(v):
		YesText = v
		if _yes_btn: _yes_btn.text = v

@export var NoText: String = "No":
	set(v):
		NoText = v
		if _no_btn: _no_btn.text = v

@export_enum("FadeIn", "ScaleUp", "PopBounce", "None") var ShowAnimation: int = 2
@export var TransitionSpeed: float = 0.25
@export var DimBackground: bool = true

var _title_label: Label
var _message_label: Label
var _yes_btn: Button
var _no_btn: Button
var _tween: Tween

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	for c in get_children(): c.queue_free()
	custom_minimum_size = Vector2(280, 140)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.border_color = Color(0.5, 0.55, 0.7, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = DialogTitle
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_message_label = Label.new()
	_message_label.text = Message
	_message_label.add_theme_font_size_override("font_size", 12)
	_message_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_message_label)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	_yes_btn = Button.new()
	_yes_btn.text = YesText
	_yes_btn.custom_minimum_size = Vector2(80, 30)
	if not Engine.is_editor_hint():
		_yes_btn.pressed.connect(func(): confirmed.emit(); hide_dialog())
	btn_row.add_child(_yes_btn)

	_no_btn = Button.new()
	_no_btn.text = NoText
	_no_btn.custom_minimum_size = Vector2(80, 30)
	if not Engine.is_editor_hint():
		_no_btn.pressed.connect(func(): cancelled.emit(); hide_dialog())
	btn_row.add_child(_no_btn)

	if Engine.is_editor_hint():
		visible = true
		modulate = Color(1, 1, 1, 1)

func show_dialog() -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	visible = true
	pivot_offset = size * 0.5
	match ShowAnimation:
		0:
			modulate.a = 0.0
			_tween.tween_property(self, "modulate:a", 1.0, TransitionSpeed)
		1:
			scale = Vector2(0.7, 0.7); modulate.a = 0.0
			_tween.tween_property(self, "scale", Vector2.ONE, TransitionSpeed).set_trans(Tween.TRANS_BACK)
			_tween.parallel().tween_property(self, "modulate:a", 1.0, TransitionSpeed * 0.5)
		2:
			scale = Vector2(0.5, 0.5); modulate.a = 0.0
			_tween.tween_property(self, "scale", Vector2(1.05, 1.05), TransitionSpeed * 0.6).set_trans(Tween.TRANS_BACK)
			_tween.tween_property(self, "scale", Vector2.ONE, TransitionSpeed * 0.4)
			_tween.parallel().tween_property(self, "modulate:a", 1.0, TransitionSpeed * 0.3)
		_:
			modulate.a = 1.0

func hide_dialog() -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, TransitionSpeed * 0.4)
	_tween.tween_callback(func(): visible = false)
