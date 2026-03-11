@tool
extends TextureButton
## Game UI — Button with radial cooldown overlay.
## Shows a sweeping arc that counts down before the button
## becomes clickable again.

signal cooldown_finished

# ── VB6-style properties ──────────────────────────────────────

@export var CooldownTime: float = 3.0   ## Seconds
@export var OverlayColor: Color = Color(0.0, 0.0, 0.0, 0.55)
@export var ReadyColor: Color = Color(1.0, 1.0, 1.0, 0.0)
@export var ShowCountdown: bool = true   ## Show remaining seconds
@export var FontSize: int = 14

@export_enum("FadeIn", "ScaleUp", "None") var ShowAnimation: int = 0
@export_enum("FadeOut", "None") var HideAnimation: int = 0
@export var TransitionSpeed: float = 0.25

# ── Internal ──────────────────────────────────────────────────

var _cooldown_remaining: float = 0.0
var _is_cooling: bool = false
var _label: Label
var _tween: Tween

func _ready() -> void:
	custom_minimum_size = Vector2(48, 48)
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.add_theme_font_size_override("font_size", FontSize)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.visible = false
	add_child(_label)

func _process(delta: float) -> void:
	if not _is_cooling: return
	_cooldown_remaining -= delta
	if _cooldown_remaining <= 0:
		_cooldown_remaining = 0.0
		_is_cooling = false
		disabled = false
		_label.visible = false
		cooldown_finished.emit()
	else:
		if ShowCountdown:
			_label.text = str(ceili(_cooldown_remaining))
	queue_redraw()

func _draw() -> void:
	if not _is_cooling: return
	# Radial sweep overlay
	var center := size / 2.0
	var radius := maxf(size.x, size.y) * 0.72
	var ratio := _cooldown_remaining / CooldownTime
	var start_angle := -PI / 2.0
	var end_angle := start_angle + TAU * ratio
	var points := PackedVector2Array()
	points.append(center)
	var segments := 32
	for i in range(segments + 1):
		var angle := lerpf(start_angle, end_angle, float(i) / segments)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, OverlayColor)

# ── Public API ────────────────────────────────────────────────

## Start a cooldown. Button is disabled until it finishes.
func StartCooldown(duration: float = -1.0) -> void:
	if duration > 0: CooldownTime = duration
	_cooldown_remaining = CooldownTime
	_is_cooling = true
	disabled = true
	_label.visible = ShowCountdown
	queue_redraw()

## Cancel the cooldown early.
func CancelCooldown() -> void:
	_cooldown_remaining = 0.0
	_is_cooling = false
	disabled = false
	_label.visible = false
	queue_redraw()

## True if the button is currently cooling down.
func IsCooling() -> bool:
	return _is_cooling

## Remaining seconds.
func GetRemaining() -> float:
	return _cooldown_remaining

func Show() -> void: _animate_show()
func Hide() -> void: _animate_hide()

# ── Show/Hide ────────────────────────────────────────────────

func _animate_show() -> void:
	if _tween: _tween.kill()
	_tween = create_tween(); visible = true
	match ShowAnimation:
		0: modulate.a = 0.0; _tween.tween_property(self, "modulate:a", 1.0, TransitionSpeed)
		1:
			scale = Vector2(0.6, 0.6); modulate.a = 0.0
			_tween.set_parallel(true)
			_tween.tween_property(self, "scale", Vector2.ONE, TransitionSpeed) \
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
