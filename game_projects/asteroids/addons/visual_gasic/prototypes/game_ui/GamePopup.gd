@tool
extends PanelContainer
## Game UI — Animated modal popup with title, body text, and close button.

signal popup_closed

# ── VB6-style properties ──────────────────────────────────────

@export var PopupTitle: String = "Notice":
	set(v):
		PopupTitle = v
		if _title_label: _title_label.text = v

@export_multiline var BodyText: String = "Something happened!":
	set(v):
		BodyText = v
		if _body_label: _body_label.text = v

@export var ShowCloseButton: bool = true:
	set(v):
		ShowCloseButton = v
		if _close_btn: _close_btn.visible = v

@export var CloseButtonText: String = "OK":
	set(v):
		CloseButtonText = v
		if _close_btn: _close_btn.text = v

@export_enum("FadeIn", "ScaleUp", "SlideDown", "None") var ShowAnimation: int = 1
@export var AnimationSpeed: float = 0.25
@export var TitleColor: Color = Color(1.0, 0.85, 0.4)

var _title_label: Label
var _body_label: Label
var _close_btn: Button
var _tween: Tween

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	for c in get_children(): c.queue_free()
	custom_minimum_size = Vector2(260, 160)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.16, 0.95)
	style.border_color = Color(0.5, 0.45, 0.6, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = PopupTitle
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", TitleColor)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Body
	_body_label = Label.new()
	_body_label.text = BodyText
	_body_label.add_theme_font_size_override("font_size", 12)
	_body_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_body_label)

	# Close button
	_close_btn = Button.new()
	_close_btn.text = CloseButtonText
	_close_btn.custom_minimum_size = Vector2(80, 28)
	_close_btn.visible = ShowCloseButton
	_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if not Engine.is_editor_hint():
		_close_btn.pressed.connect(func(): close_popup())
	vbox.add_child(_close_btn)

func show_popup() -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	visible = true
	pivot_offset = size * 0.5
	match ShowAnimation:
		0: # FadeIn
			modulate.a = 0.0
			_tween.tween_property(self, "modulate:a", 1.0, AnimationSpeed)
		1: # ScaleUp
			scale = Vector2(0.7, 0.7); modulate.a = 0.0
			_tween.tween_property(self, "scale", Vector2.ONE, AnimationSpeed).set_trans(Tween.TRANS_BACK)
			_tween.parallel().tween_property(self, "modulate:a", 1.0, AnimationSpeed * 0.5)
		2: # SlideDown
			var target_y := position.y
			position.y -= 40; modulate.a = 0.0
			_tween.tween_property(self, "position:y", target_y, AnimationSpeed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(self, "modulate:a", 1.0, AnimationSpeed * 0.5)
		_:
			modulate.a = 1.0

func close_popup() -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, AnimationSpeed * 0.4)
	_tween.tween_callback(func():
		visible = false
		popup_closed.emit()
	)
