@tool
extends PanelContainer
## Game UI — Animated dialog panel with portrait, speaker name,
## typewriter text, and branching choices.

signal dialog_finished
signal choice_selected(index: int)

# ── VB6-style properties ──────────────────────────────────────

@export var SpeakerName: String = "":
	set(v):
		SpeakerName = v
		if _name_label: _name_label.text = v

@export var DialogText: String = "":
	set(v):
		DialogText = v
		if _text_label: _text_label.text = v

@export var PortraitTexture: Texture2D = null:
	set(v):
		PortraitTexture = v
		if _portrait: _portrait.texture = v

@export_enum("SlideUp", "FadeIn", "ScaleUp", "PopBounce", "None") var ShowAnimation: int = 0
@export_enum("SlideDown", "FadeOut", "ScaleDown", "None") var HideAnimation: int = 0
@export var TransitionSpeed: float = 0.3
@export var TypewriterSpeed: float = 0.03

# ── Internal ──────────────────────────────────────────────────

var _portrait: TextureRect
var _name_label: Label
var _text_label: RichTextLabel
var _choices_vbox: VBoxContainer
var _tween: Tween
var _typewriter_tween: Tween

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	for c in get_children(): c.queue_free()

	custom_minimum_size = Vector2(320, 120)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Header row: portrait + speaker name
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(48, 48)
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if PortraitTexture:
		_portrait.texture = PortraitTexture
	header.add_child(_portrait)

	_name_label = Label.new()
	_name_label.text = SpeakerName
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_name_label)

	# Dialog body
	_text_label = RichTextLabel.new()
	_text_label.text = DialogText
	_text_label.bbcode_enabled = true
	_text_label.fit_content = true
	_text_label.custom_minimum_size = Vector2(0, 40)
	_text_label.scroll_active = false
	vbox.add_child(_text_label)

	# Choices (hidden until needed)
	_choices_vbox = VBoxContainer.new()
	_choices_vbox.add_theme_constant_override("separation", 4)
	_choices_vbox.visible = false
	vbox.add_child(_choices_vbox)

# ── Public API ────────────────────────────────────────────────

## Show the dialog with optional speaker, text, and choices array.
func ShowDialog(speaker: String = "", text: String = "",
		choices: Array = []) -> void:
	if speaker != "": SpeakerName = speaker
	if text != "":    DialogText  = text
	_set_choices(choices)
	_animate_show()
	if TypewriterSpeed > 0 and _text_label:
		_run_typewriter()

## Hide with the configured animation.
func HideDialog() -> void:
	_animate_hide()

## Clear choices and text.
func Clear() -> void:
	DialogText = ""
	_set_choices([])

# ── Typewriter ────────────────────────────────────────────────

func _run_typewriter() -> void:
	if _typewriter_tween: _typewriter_tween.kill()
	_text_label.visible_ratio = 0.0
	_typewriter_tween = create_tween()
	var duration := DialogText.length() * TypewriterSpeed
	_typewriter_tween.tween_property(_text_label, "visible_ratio", 1.0, duration)
	_typewriter_tween.tween_callback(func(): dialog_finished.emit())

# ── Choices ───────────────────────────────────────────────────

func _set_choices(choices: Array) -> void:
	if not _choices_vbox: return
	for c in _choices_vbox.get_children(): c.queue_free()
	if choices.size() > 0:
		_choices_vbox.visible = true
		for i in choices.size():
			var btn := Button.new()
			btn.text = str(choices[i])
			var idx := i
			btn.pressed.connect(func(): choice_selected.emit(idx))
			_choices_vbox.add_child(btn)
	else:
		_choices_vbox.visible = false

# ── Animations ────────────────────────────────────────────────

func _animate_show() -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	visible = true
	match ShowAnimation:
		0: # SlideUp
			var target_y := position.y
			position.y += 60
			modulate.a = 0.0
			_tween.set_parallel(true)
			_tween.tween_property(self, "position:y", target_y, TransitionSpeed) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			_tween.tween_property(self, "modulate:a", 1.0, TransitionSpeed * 0.6)
		1: # FadeIn
			modulate.a = 0.0
			_tween.tween_property(self, "modulate:a", 1.0, TransitionSpeed)
		2: # ScaleUp
			scale = Vector2(0.8, 0.8); modulate.a = 0.0
			_tween.set_parallel(true)
			_tween.tween_property(self, "scale", Vector2.ONE, TransitionSpeed) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			_tween.tween_property(self, "modulate:a", 1.0, TransitionSpeed * 0.6)
		3: # PopBounce
			scale = Vector2(0.5, 0.5); modulate.a = 0.0
			_tween.set_parallel(true)
			_tween.tween_property(self, "scale", Vector2.ONE, TransitionSpeed) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
			_tween.tween_property(self, "modulate:a", 1.0, TransitionSpeed * 0.5)
		_: modulate.a = 1.0  # None

func _animate_hide() -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	match HideAnimation:
		0: # SlideDown
			_tween.set_parallel(true)
			_tween.tween_property(self, "position:y", position.y + 60, TransitionSpeed) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
			_tween.tween_property(self, "modulate:a", 0.0, TransitionSpeed)
		1: # FadeOut
			_tween.tween_property(self, "modulate:a", 0.0, TransitionSpeed)
		2: # ScaleDown
			_tween.set_parallel(true)
			_tween.tween_property(self, "scale", Vector2(0.8, 0.8), TransitionSpeed)
			_tween.tween_property(self, "modulate:a", 0.0, TransitionSpeed)
		_: modulate.a = 0.0  # None
	_tween.tween_callback(func(): visible = false)
