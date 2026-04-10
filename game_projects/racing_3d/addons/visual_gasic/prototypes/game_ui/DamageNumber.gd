@tool
extends Label
## Game UI — Floating damage/heal number that pops up and fades out.

signal pop_finished

# ── VB6-style properties ──────────────────────────────────────

@export var Amount: int = 42:
	set(v):
		Amount = v
		text = str(v)

@export var NumberColor: Color = Color(1.0, 0.3, 0.2):
	set(v):
		NumberColor = v
		add_theme_color_override("font_color", v)

@export var FontSize: int = 22:
	set(v):
		FontSize = v
		add_theme_font_size_override("font_size", v)

@export_enum("FloatUp", "FloatUpRight", "Bounce", "ScaleDown") var PopStyle: int = 0
@export var FloatDistance: float = 60.0
@export var Duration: float = 0.8
@export var ShowCriticalEffect: bool = false:
	set(v):
		ShowCriticalEffect = v
		if v:
			add_theme_font_size_override("font_size", int(FontSize * 1.5))
		else:
			add_theme_font_size_override("font_size", FontSize)

var _tween: Tween

func _ready() -> void:
	text = str(Amount)
	add_theme_color_override("font_color", NumberColor)
	add_theme_font_size_override("font_size", FontSize if not ShowCriticalEffect else int(FontSize * 1.5))
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	custom_minimum_size = Vector2(60, 28)
	if Engine.is_editor_hint():
		modulate.a = 1.0

func pop(value: int = -1, col: Color = Color(-1, -1, -1)) -> void:
	if value >= 0: Amount = value
	if col.r >= 0.0: NumberColor = col
	if _tween: _tween.kill()
	_tween = create_tween()
	modulate.a = 1.0
	scale = Vector2.ONE
	var origin := position
	pivot_offset = size * 0.5
	match PopStyle:
		0: # FloatUp
			_tween.tween_property(self, "position:y", position.y - FloatDistance, Duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(self, "modulate:a", 0.0, Duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		1: # FloatUpRight
			_tween.tween_property(self, "position:y", position.y - FloatDistance, Duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(self, "position:x", position.x + FloatDistance * 0.5, Duration)
			_tween.parallel().tween_property(self, "modulate:a", 0.0, Duration * 0.8)
		2: # Bounce
			scale = Vector2(1.3, 1.3)
			_tween.tween_property(self, "scale", Vector2.ONE, Duration * 0.3).set_trans(Tween.TRANS_BACK)
			_tween.tween_property(self, "position:y", position.y - FloatDistance, Duration * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(self, "modulate:a", 0.0, Duration * 0.6)
		3: # ScaleDown
			scale = Vector2(1.5, 1.5)
			_tween.tween_property(self, "scale", Vector2(0.5, 0.5), Duration)
			_tween.parallel().tween_property(self, "modulate:a", 0.0, Duration)
	_tween.tween_callback(func():
		pop_finished.emit()
		position = origin
	)
