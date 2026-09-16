@tool
extends Button
## WobblyButton — An animated button that wobbles, pulses, and glows on hover.
## Demonstrates VisualGasic custom control pipeline:
##   Tools → New Custom Control → design → drag onto forms.

## How much the button rotates back and forth (degrees).
@export var wobble_amount: float = 3.0
## Speed of the wobble oscillation.
@export var wobble_speed: float = 4.0
## How much the button scales up/down (breathing effect).
@export var pulse_amount: float = 0.04
## Speed of the pulse oscillation.
@export var pulse_speed: float = 2.5
## Glow color when hovered.
@export var hover_glow_color: Color = Color(0.3, 0.6, 1.0, 0.25)

var _time: float = 0.0
var _is_hovered: bool = false
var _hover_t: float = 0.0  # 0→1 blend for smooth hover transition

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pivot_offset = size / 2.0
	# Give it a nice default style if none is set
	if text.is_empty():
		text = "Wobbly!"

func _process(delta: float) -> void:
	_time += delta

	# Smooth hover blend (0→1 over 0.2s)
	if _is_hovered:
		_hover_t = minf(_hover_t + delta * 5.0, 1.0)
	else:
		_hover_t = maxf(_hover_t - delta * 5.0, 0.0)

	# Wobble rotation — stronger when hovered
	var wobble_mult := lerpf(0.3, 1.0, _hover_t)
	rotation_degrees = sin(_time * wobble_speed) * wobble_amount * wobble_mult

	# Breathing pulse scale
	var pulse := 1.0 + sin(_time * pulse_speed) * pulse_amount
	var hover_scale := lerpf(1.0, 1.08, _hover_t)
	scale = Vector2.ONE * pulse * hover_scale

	# Keep pivot centered (in case button resizes)
	pivot_offset = size / 2.0

	# Glow modulation on hover
	if _hover_t > 0.01:
		modulate = Color(1, 1, 1, 1).lerp(
			Color(hover_glow_color.r + 0.7, hover_glow_color.g + 0.4, hover_glow_color.b + 0.4, 1.0),
			_hover_t * 0.4
		)
	else:
		modulate = Color(1, 1, 1, 1)

func _on_mouse_entered() -> void:
	_is_hovered = true

func _on_mouse_exited() -> void:
	_is_hovered = false
