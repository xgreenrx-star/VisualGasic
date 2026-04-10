@tool
extends PanelContainer
## Game UI — Slide-in notification toast for achievements,
## pickups, quest updates, or system messages.

signal dismissed

# ── VB6-style properties ──────────────────────────────────────

@export var Message: String = "":
	set(v):
		Message = v
		if _label: _label.text = v

@export var Duration: float = 3.0  ## Seconds before auto-dismiss
@export var FontSize: int = 14:
	set(v):
		FontSize = v
		if _label: _label.add_theme_font_size_override("font_size", v)

@export var FontColor: Color = Color.WHITE:
	set(v):
		FontColor = v
		if _label: _label.add_theme_color_override("font_color", v)

@export var IconTexture: Texture2D = null:
	set(v):
		IconTexture = v
		if _icon: _icon.texture = v; _icon.visible = v != null

@export_enum("SlideFromTop", "SlideFromBottom", "SlideFromRight", "FadeIn") var ShowAnimation: int = 0
@export var TransitionSpeed: float = 0.35
@export var MaxVisible: int = 3   ## Stack limit before oldest is dismissed

# ── Internal ──────────────────────────────────────────────────

var _icon: TextureRect
var _label: Label
var _timer: Timer
var _tween: Tween

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	for c in get_children(): c.queue_free()
	custom_minimum_size = Vector2(250, 40)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(24, 24)
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.visible = IconTexture != null
	if IconTexture: _icon.texture = IconTexture
	hbox.add_child(_icon)

	_label = Label.new()
	_label.text = Message
	_label.add_theme_font_size_override("font_size", FontSize)
	_label.add_theme_color_override("font_color", FontColor)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hbox.add_child(_label)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = Duration
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)

	visible = false

# ── Public API ────────────────────────────────────────────────

## Show a toast notification. Stacks on top of previous toasts.
func ShowMessage(text: String = "", icon: Texture2D = null) -> void:
	if text != "": Message = text
	if icon: IconTexture = icon
	_animate_in()
	_timer.wait_time = Duration
	_timer.start()

## Dismiss immediately.
func Dismiss() -> void:
	_animate_out()

# ── Timer ────────────────────────────────────────────────────

func _on_timeout() -> void:
	_animate_out()

# ── Animations ───────────────────────────────────────────────

func _animate_in() -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	visible = true; modulate.a = 1.0
	match ShowAnimation:
		0: # SlideFromTop
			var ty := position.y
			position.y -= 50; modulate.a = 0.0
			_tween.set_parallel(true)
			_tween.tween_property(self, "position:y", ty, TransitionSpeed) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			_tween.tween_property(self, "modulate:a", 1.0, TransitionSpeed * 0.5)
		1: # SlideFromBottom
			var ty := position.y
			position.y += 50; modulate.a = 0.0
			_tween.set_parallel(true)
			_tween.tween_property(self, "position:y", ty, TransitionSpeed) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			_tween.tween_property(self, "modulate:a", 1.0, TransitionSpeed * 0.5)
		2: # SlideFromRight
			var tx := position.x
			position.x += 80; modulate.a = 0.0
			_tween.set_parallel(true)
			_tween.tween_property(self, "position:x", tx, TransitionSpeed) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			_tween.tween_property(self, "modulate:a", 1.0, TransitionSpeed * 0.5)
		3: # FadeIn
			modulate.a = 0.0
			_tween.tween_property(self, "modulate:a", 1.0, TransitionSpeed)

func _animate_out() -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, TransitionSpeed * 0.6)
	_tween.tween_callback(func():
		visible = false
		dismissed.emit()
	)
