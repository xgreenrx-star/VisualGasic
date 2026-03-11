@tool
extends Control
## Game UI — Animated stat bar (HP / MP / XP) with damage flash
## and smooth value transitions.

signal value_changed(new_value: float)
signal depleted

# ── VB6-style properties ──────────────────────────────────────

@export var Value: float = 75.0:
	set(v):
		var old := Value
		Value = clampf(v, 0.0, MaxValue)
		if is_inside_tree(): _animate_value(old)

@export var MaxValue: float = 100.0:
	set(v):
		MaxValue = maxf(v, 1.0)
		Value = minf(Value, MaxValue)
		if _fill_bar: _fill_bar.max_value = MaxValue
		if _trail_bar: _trail_bar.max_value = MaxValue

@export var BarColor: Color = Color(0.2, 0.8, 0.3):
	set(v):
		BarColor = v
		if _fill_style: _fill_style.bg_color = v

@export var TrailColor: Color = Color(0.9, 0.2, 0.2, 0.6)
@export var BackgroundColor: Color = Color(0.15, 0.15, 0.18)

@export var ShowLabel: bool = true:
	set(v):
		ShowLabel = v
		if _label: _label.visible = v

@export var LabelFormat: String = "{value} / {max}":
	set(v):
		LabelFormat = v
		_update_label()

@export var TransitionSpeed: float = 0.4
@export var TrailDelay: float = 0.5

@export_enum("SlideRight", "FadeIn", "None") var ShowAnimation: int = 0
@export_enum("FadeOut", "None") var HideAnimation: int = 0

# ── Internal ──────────────────────────────────────────────────

var _bg: ColorRect
var _trail_bar: ProgressBar
var _fill_bar: ProgressBar
var _label: Label
var _fill_style: StyleBoxFlat
var _trail_style: StyleBoxFlat
var _value_tween: Tween
var _trail_tween: Tween
var _flash_tween: Tween
var _tween: Tween

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	for c in get_children(): c.queue_free()
	custom_minimum_size = Vector2(200, 24)

	# Background
	_bg = ColorRect.new()
	_bg.color = BackgroundColor
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# Trail (damage ghost)
	_trail_bar = ProgressBar.new()
	_trail_bar.max_value = MaxValue
	_trail_bar.value = Value
	_trail_bar.show_percentage = false
	_trail_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_trail_style = StyleBoxFlat.new()
	_trail_style.bg_color = TrailColor
	_trail_bar.add_theme_stylebox_override("fill", _trail_style)
	var trail_bg := StyleBoxEmpty.new()
	_trail_bar.add_theme_stylebox_override("background", trail_bg)
	add_child(_trail_bar)

	# Fill (actual value)
	_fill_bar = ProgressBar.new()
	_fill_bar.max_value = MaxValue
	_fill_bar.value = Value
	_fill_bar.show_percentage = false
	_fill_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fill_style = StyleBoxFlat.new()
	_fill_style.bg_color = BarColor
	_fill_bar.add_theme_stylebox_override("fill", _fill_style)
	var fill_bg := StyleBoxEmpty.new()
	_fill_bar.add_theme_stylebox_override("background", fill_bg)
	add_child(_fill_bar)

	# Value label
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.visible = ShowLabel
	add_child(_label)
	_update_label()

# ── Public API ────────────────────────────────────────────────

## Smoothly set the bar value (triggers animation + flash on damage).
func SetValue(v: float) -> void:
	Value = v

## Instantly set without animation.
func SetValueImmediate(v: float) -> void:
	Value = clampf(v, 0.0, MaxValue)
	if _fill_bar: _fill_bar.value = Value
	if _trail_bar: _trail_bar.value = Value
	_update_label()

func Show() -> void:
	_animate_show()

func Hide() -> void:
	_animate_hide()

# ── Value animation ──────────────────────────────────────────

func _animate_value(old_value: float) -> void:
	if not _fill_bar: return

	# Flash red on damage
	if Value < old_value and _fill_style:
		if _flash_tween: _flash_tween.kill()
		_flash_tween = create_tween()
		var orig := BarColor
		_fill_style.bg_color = Color.WHITE
		_flash_tween.tween_property(_fill_style, "bg_color", orig, 0.2)

	# Animate fill bar
	if _value_tween: _value_tween.kill()
	_value_tween = create_tween()
	_value_tween.tween_property(_fill_bar, "value", Value, TransitionSpeed) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_value_tween.tween_callback(func():
		value_changed.emit(Value)
		_update_label()
		if Value <= 0: depleted.emit()
	)

	# Trail follows with delay
	if _trail_tween: _trail_tween.kill()
	_trail_tween = create_tween()
	_trail_tween.tween_interval(TrailDelay)
	_trail_tween.tween_property(_trail_bar, "value", Value, TransitionSpeed) \
		.set_ease(Tween.EASE_IN_OUT)

func _update_label() -> void:
	if not _label: return
	var txt := LabelFormat.replace("{value}", str(int(Value)))
	txt = txt.replace("{max}", str(int(MaxValue)))
	txt = txt.replace("{percent}", str(int(Value / MaxValue * 100)))
	_label.text = txt

# ── Show/Hide animations ────────────────────────────────────

func _animate_show() -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	visible = true
	match ShowAnimation:
		0: # SlideRight
			var target_x := position.x
			position.x -= size.x; modulate.a = 0.0
			_tween.set_parallel(true)
			_tween.tween_property(self, "position:x", target_x, TransitionSpeed) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			_tween.tween_property(self, "modulate:a", 1.0, TransitionSpeed * 0.5)
		1: # FadeIn
			modulate.a = 0.0
			_tween.tween_property(self, "modulate:a", 1.0, TransitionSpeed)
		_: modulate.a = 1.0

func _animate_hide() -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	match HideAnimation:
		0: _tween.tween_property(self, "modulate:a", 0.0, TransitionSpeed)
		_: modulate.a = 0.0
	_tween.tween_callback(func(): visible = false)
