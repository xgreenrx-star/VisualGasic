@tool
extends ColorRect
## Game UI — Full-screen game menu overlay (pause, settings, quit)
## with dim background and animated button list.

signal button_clicked(index: int)
signal menu_opened
signal menu_closed

# ── VB6-style properties ──────────────────────────────────────

@export var Title: String = "PAUSED":
	set(v):
		Title = v
		if _title_label: _title_label.text = v

@export var Buttons: PackedStringArray = ["Resume", "Settings", "Quit"]:
	set(v):
		Buttons = v
		if is_inside_tree(): _rebuild_buttons()

@export var DimColor: Color = Color(0.0, 0.0, 0.0, 0.6):
	set(v):
		DimColor = v
		color = v

@export var TitleFontSize: int = 28:
	set(v):
		TitleFontSize = v
		if _title_label: _title_label.add_theme_font_size_override("font_size", v)

@export var ButtonFontSize: int = 18
@export var ButtonMinWidth: int = 200

@export_enum("FadeIn", "ScaleUp", "None") var ShowAnimation: int = 0
@export_enum("FadeOut", "ScaleDown", "None") var HideAnimation: int = 0
@export var TransitionSpeed: float = 0.3

# ── Internal ──────────────────────────────────────────────────

var _center: CenterContainer
var _vbox: VBoxContainer
var _title_label: Label
var _buttons_vbox: VBoxContainer
var _tween: Tween

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	for c in get_children(): c.queue_free()

	# Full-screen dim overlay
	color = DimColor
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_center)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 20)
	_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_center.add_child(_vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = Title
	_title_label.add_theme_font_size_override("font_size", TitleFontSize)
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(_title_label)

	# Button container
	_buttons_vbox = VBoxContainer.new()
	_buttons_vbox.add_theme_constant_override("separation", 10)
	_buttons_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_child(_buttons_vbox)

	_rebuild_buttons()
	visible = false

func _rebuild_buttons() -> void:
	if not _buttons_vbox: return
	for c in _buttons_vbox.get_children(): c.queue_free()

	for i in Buttons.size():
		var btn := Button.new()
		btn.text = Buttons[i]
		btn.custom_minimum_size.x = ButtonMinWidth
		btn.add_theme_font_size_override("font_size", ButtonFontSize)
		var idx := i
		btn.pressed.connect(func(): button_clicked.emit(idx))
		_buttons_vbox.add_child(btn)

# ── Public API ────────────────────────────────────────────────

## Open the menu overlay.
func ShowMenu() -> void:
	_animate_show()
	menu_opened.emit()

## Close the menu overlay.
func HideMenu() -> void:
	_animate_hide()

## Toggle open/close.
func ToggleMenu() -> void:
	if visible: HideMenu()
	else:        ShowMenu()

# ── Animations ────────────────────────────────────────────────

func _animate_show() -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	visible = true
	match ShowAnimation:
		0: # FadeIn
			modulate.a = 0.0
			_tween.tween_property(self, "modulate:a", 1.0, TransitionSpeed)
		1: # ScaleUp
			if _vbox:
				_vbox.scale = Vector2(0.8, 0.8)
				_vbox.modulate.a = 0.0
			modulate.a = 0.0
			_tween.set_parallel(true)
			_tween.tween_property(self, "modulate:a", 1.0, TransitionSpeed * 0.5)
			if _vbox:
				_tween.tween_property(_vbox, "scale", Vector2.ONE, TransitionSpeed) \
					.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
				_tween.tween_property(_vbox, "modulate:a", 1.0, TransitionSpeed * 0.6)
		_: modulate.a = 1.0

func _animate_hide() -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	match HideAnimation:
		0: _tween.tween_property(self, "modulate:a", 0.0, TransitionSpeed)
		1:
			_tween.set_parallel(true)
			_tween.tween_property(self, "modulate:a", 0.0, TransitionSpeed)
			if _vbox:
				_tween.tween_property(_vbox, "scale", Vector2(0.8, 0.8), TransitionSpeed)
		_: modulate.a = 0.0
	_tween.tween_callback(func():
		visible = false
		menu_closed.emit()
	)
