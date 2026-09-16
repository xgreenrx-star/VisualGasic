@tool
extends Panel
## WobblyPanel — An animated panel that wobbles, breathes, and ripples.
## Use as a form background replacement or decorative container.
## Demonstrates the VisualGasic custom control pipeline for Panel-based controls.

## How much the panel rotates back and forth (degrees).
@export var wobble_amount: float = 1.5
## Speed of the wobble oscillation.
@export var wobble_speed: float = 2.0
## How much the panel scales up/down (breathing effect).
@export var pulse_amount: float = 0.02
## Speed of the pulse oscillation.
@export var pulse_speed: float = 1.5
## Whether the wobble is always active or only when hovered.
@export var always_animate: bool = true
## Tint color when hovered.
@export var hover_tint: Color = Color(0.9, 0.95, 1.0, 1.0)

var _time: float = 0.0
var _is_hovered: bool = false
var _hover_t: float = 0.0  # 0→1 blend for smooth hover transition

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pivot_offset = size / 2.0
	# Ensure the panel passes mouse events to children
	mouse_filter = Control.MOUSE_FILTER_PASS

func _process(delta: float) -> void:
	_time += delta

	# Smooth hover blend (0→1 over 0.2s)
	if _is_hovered:
		_hover_t = minf(_hover_t + delta * 5.0, 1.0)
	else:
		_hover_t = maxf(_hover_t - delta * 5.0, 0.0)

	# Determine animation strength
	var anim_strength: float
	if always_animate:
		anim_strength = lerpf(0.6, 1.0, _hover_t)
	else:
		anim_strength = _hover_t

	# Wobble rotation
	rotation_degrees = sin(_time * wobble_speed) * wobble_amount * anim_strength

	# Breathing pulse scale
	var pulse := 1.0 + sin(_time * pulse_speed) * pulse_amount * anim_strength
	scale = Vector2.ONE * pulse

	# Keep pivot centered (in case panel resizes)
	pivot_offset = size / 2.0

	# Hover tint
	if _hover_t > 0.01:
		modulate = Color(1, 1, 1, 1).lerp(hover_tint, _hover_t * 0.5)
	else:
		modulate = Color(1, 1, 1, 1)

func _on_mouse_entered() -> void:
	_is_hovered = true

func _on_mouse_exited() -> void:
	_is_hovered = false
