@tool
extends Control
## SegmentedProgressBar — chunky multi-segment bar (5-10 wide segments
## with rounded edges). Reads as "stages" or "ammo clips" — common in
## modern action games.

@export var value: float = 60.0 : set = _set_value
@export var max_value: float = 100.0 : set = _set_max
@export var segments: int = 6
@export var fill_color: Color = Color(0.95, 0.70, 0.20)
@export var empty_color: Color = Color(0.18, 0.18, 0.18)
@export var corner_radius: float = 4.0
@export var gap: float = 4.0

func _ready() -> void:
	custom_minimum_size = Vector2(180, 14)

func _set_value(v: float) -> void:
	value = clampf(v, 0.0, max_value)
	queue_redraw()

func _set_max(v: float) -> void:
	max_value = max(1.0, v)
	queue_redraw()

func _draw() -> void:
	if segments <= 0 or max_value <= 0:
		return
	var seg_w := (size.x - gap * (segments - 1)) / segments
	var seg_value := max_value / segments
	for i in range(segments):
		var x := i * (seg_w + gap)
		var rect := Rect2(x, 0, seg_w, size.y)
		var seg_low := i * seg_value
		var fill_amt := clampf((value - seg_low) / seg_value, 0.0, 1.0)
		# Empty backing for this segment.
		_draw_round_rect(rect, empty_color)
		if fill_amt > 0.0:
			var filled := Rect2(x, 0, seg_w * fill_amt, size.y)
			_draw_round_rect(filled, fill_color)

func _draw_round_rect(r: Rect2, color: Color) -> void:
	# Cheap rounded rect: middle bar + two side circles.
	var radius: float = min(corner_radius, min(r.size.x * 0.5, r.size.y * 0.5))
	if radius <= 0.5:
		draw_rect(r, color, true)
		return
	draw_rect(Rect2(r.position.x + radius, r.position.y, r.size.x - radius * 2.0, r.size.y), color, true)
	draw_rect(Rect2(r.position.x, r.position.y + radius, r.size.x, r.size.y - radius * 2.0), color, true)
	draw_circle(r.position + Vector2(radius, radius), radius, color)
	draw_circle(r.position + Vector2(r.size.x - radius, radius), radius, color)
	draw_circle(r.position + Vector2(radius, r.size.y - radius), radius, color)
	draw_circle(r.position + Vector2(r.size.x - radius, r.size.y - radius), radius, color)
