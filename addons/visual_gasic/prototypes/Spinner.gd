@tool
extends Control
## Spinner — modern circular loading indicator.
## A thin rotating arc on a faint full-circle track. Set `done = true` to
## freeze it as a complete ring (e.g., when the operation succeeds).

@export var arc_color: Color = Color(0.30, 0.65, 1.0)
@export var track_color: Color = Color(1, 1, 1, 0.15)
@export var done_color: Color = Color(0.30, 0.85, 0.45)
@export var thickness: float = 3.0
@export_range(0.0, 1.0, 0.01) var sweep_fraction: float = 0.30  ## of full circle
@export var revs_per_sec: float = 0.9
@export var done: bool = false : set = _set_done

var _angle: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(48, 48)

func _process(delta: float) -> void:
	if done:
		return
	_angle = fmod(_angle + delta * TAU * revs_per_sec, TAU)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius: float = min(size.x, size.y) * 0.5 - thickness
	if radius <= 0:
		return
	draw_arc(center, radius, 0.0, TAU, 64, track_color, thickness, true)
	if done:
		draw_arc(center, radius, 0.0, TAU, 64, done_color, thickness, true)
	else:
		var sweep := TAU * sweep_fraction
		draw_arc(center, radius, _angle, _angle + sweep, 32, arc_color, thickness, true)

func _set_done(v: bool) -> void:
	done = v
	queue_redraw()
