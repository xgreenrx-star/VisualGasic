@tool
extends Control
## BusyDots — three dots that bounce in sequence. Compact alternative to
## the circular Spinner; reads as "thinking" when space is tight.

@export var dot_color: Color = Color(0.30, 0.65, 1.0)
@export var dot_radius: float = 4.0
@export var spacing: float = 14.0
@export var bounce_height: float = 6.0
@export var period: float = 1.0  ## seconds per full bounce cycle

var _t: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(spacing * 3.0 + dot_radius * 2.0, dot_radius * 2.0 + bounce_height + 4.0)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var baseline := size.y - dot_radius - 2.0
	var total_w := spacing * 2.0 + dot_radius * 2.0
	var start_x := (size.x - total_w) * 0.5 + dot_radius
	for i in range(3):
		var phase := fmod(_t / period - i * 0.15, 1.0)
		var lift := 0.0
		if phase < 0.5:
			lift = sin(phase * PI) * bounce_height
		var px := start_x + i * spacing
		draw_circle(Vector2(px, baseline - lift), dot_radius, dot_color)
