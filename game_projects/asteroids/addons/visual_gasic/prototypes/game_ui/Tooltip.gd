@tool
extends PanelContainer
## Game UI — Animated tooltip popup with optional icon, title, and description.
## Follows the mouse or anchors to a parent control.

signal tooltip_shown
signal tooltip_hidden

# ── VB6-style properties ──────────────────────────────────────

@export var Title: String = "Tooltip":
	set(v):
		Title = v
		if _title_label: _title_label.text = v

@export var Description: String = "Hover text goes here":
	set(v):
		Description = v
		if _desc_label: _desc_label.text = v

@export var IconTexture: Texture2D = null:
	set(v):
		IconTexture = v
		if _icon: _icon.texture = v

@export var ShowDelay: float = 0.3
@export var HideDelay: float = 0.1
@export_enum("FadeIn", "ScaleUp", "SlideDown", "None") var ShowAnimation: int = 0
@export var TransitionSpeed: float = 0.2
@export var FollowMouse: bool = true

# ── Internal ──────────────────────────────────────────────────

var _icon: TextureRect
var _title_label: Label
var _desc_label: Label
var _tween: Tween

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	for c in get_children(): c.queue_free()

	custom_minimum_size = Vector2(180, 60)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16, 0.95)
	style.border_color = Color(0.5, 0.6, 0.8, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(24, 24)
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if IconTexture:
		_icon.texture = IconTexture
	else:
		_icon.visible = false
	hbox.add_child(_icon)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = Title
	_title_label.add_theme_font_size_override("font_size", 13)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	vbox.add_child(_title_label)

	_desc_label = Label.new()
	_desc_label.text = Description
	_desc_label.add_theme_font_size_override("font_size", 11)
	_desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_desc_label)

	if Engine.is_editor_hint():
		visible = true
		modulate = Color(1, 1, 1, 1)

func show_tooltip() -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	visible = true
	match ShowAnimation:
		0: # FadeIn
			modulate.a = 0.0
			_tween.tween_property(self, "modulate:a", 1.0, TransitionSpeed)
		1: # ScaleUp
			scale = Vector2(0.8, 0.8)
			modulate.a = 0.0
			_tween.tween_property(self, "scale", Vector2.ONE, TransitionSpeed).set_trans(Tween.TRANS_BACK)
			_tween.parallel().tween_property(self, "modulate:a", 1.0, TransitionSpeed * 0.5)
		2: # SlideDown
			var target_y := position.y
			position.y -= 10
			modulate.a = 0.0
			_tween.tween_property(self, "position:y", target_y, TransitionSpeed)
			_tween.parallel().tween_property(self, "modulate:a", 1.0, TransitionSpeed)
		_:
			modulate.a = 1.0
	tooltip_shown.emit()

func hide_tooltip() -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, TransitionSpeed * 0.5)
	_tween.tween_callback(func(): visible = false)
	tooltip_hidden.emit()
