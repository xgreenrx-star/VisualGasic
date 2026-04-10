@tool
extends HBoxContainer
## Game UI — Animated HUD counter (score, gold, ammo, etc.)
## with counting animation and optional icon.

signal count_finished

# ── VB6-style properties ──────────────────────────────────────

@export var Value: int = 0:
	set(v):
		var old := Value
		Value = v
		if is_inside_tree() and old != v: _animate_count(old, v)

@export var Prefix: String = "":
	set(v):
		Prefix = v
		_update_display()

@export var Suffix: String = "":
	set(v):
		Suffix = v
		_update_display()

@export var IconTexture: Texture2D = null:
	set(v):
		IconTexture = v
		if _icon: _icon.texture = v; _icon.visible = v != null

@export var FontSize: int = 18:
	set(v):
		FontSize = v
		if _label: _label.add_theme_font_size_override("font_size", v)

@export var FontColor: Color = Color.WHITE:
	set(v):
		FontColor = v
		if _label: _label.add_theme_color_override("font_color", v)

@export var CountSpeed: float = 0.5  ## Seconds for the counting animation
@export var PunchScale: bool = true   ## Brief scale-up on change

@export_enum("FadeIn", "SlideRight", "None") var ShowAnimation: int = 0
@export_enum("FadeOut", "None") var HideAnimation: int = 0
@export var TransitionSpeed: float = 0.25

# ── Internal ──────────────────────────────────────────────────

var _icon: TextureRect
var _label: Label
var _display_value: int = 0  # Currently displayed (during counting)
var _count_tween: Tween
var _punch_tween: Tween
var _tween: Tween

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	for c in get_children(): c.queue_free()
	add_theme_constant_override("separation", 6)
	alignment = BoxContainer.ALIGNMENT_CENTER

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(24, 24)
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.visible = IconTexture != null
	if IconTexture: _icon.texture = IconTexture
	add_child(_icon)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", FontSize)
	_label.add_theme_color_override("font_color", FontColor)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)

	_display_value = Value
	_update_display()

# ── Public API ────────────────────────────────────────────────

## Set value with counting animation.
func SetValue(v: int) -> void:
	Value = v

## Set value instantly (no animation).
func SetValueImmediate(v: int) -> void:
	Value = v
	_display_value = v
	_update_display()

## Add to current value.
func AddValue(delta: int) -> void:
	Value = Value + delta

func Show() -> void: _animate_show()
func Hide() -> void: _animate_hide()

# ── Counting animation ──────────────────────────────────────

func _animate_count(from: int, to: int) -> void:
	if _count_tween: _count_tween.kill()
	_display_value = from
	_count_tween = create_tween()
	_count_tween.tween_method(_set_display, float(from), float(to), CountSpeed) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_count_tween.tween_callback(func(): count_finished.emit())

	# Punch effect
	if PunchScale and _label:
		if _punch_tween: _punch_tween.kill()
		_punch_tween = create_tween()
		_label.scale = Vector2(1.3, 1.3)
		_punch_tween.tween_property(_label, "scale", Vector2.ONE, 0.2) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _set_display(v: float) -> void:
	_display_value = int(v)
	_update_display()

func _update_display() -> void:
	if not _label: return
	_label.text = Prefix + str(_display_value) + Suffix

# ── Show/Hide ────────────────────────────────────────────────

func _animate_show() -> void:
	if _tween: _tween.kill()
	_tween = create_tween(); visible = true
	match ShowAnimation:
		0: modulate.a = 0.0; _tween.tween_property(self, "modulate:a", 1.0, TransitionSpeed)
		1:
			var tx := position.x; position.x -= 40; modulate.a = 0.0
			_tween.set_parallel(true)
			_tween.tween_property(self, "position:x", tx, TransitionSpeed) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			_tween.tween_property(self, "modulate:a", 1.0, TransitionSpeed * 0.5)
		_: modulate.a = 1.0

func _animate_hide() -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	match HideAnimation:
		0: _tween.tween_property(self, "modulate:a", 0.0, TransitionSpeed)
		_: modulate.a = 0.0
	_tween.tween_callback(func(): visible = false)
