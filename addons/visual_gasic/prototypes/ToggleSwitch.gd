@tool
extends Control
## ToggleSwitch — slide-style boolean switch (iOS/Material).
## Emits `toggled(pressed: bool)` to match Godot's CheckBox API so it
## drops in as a Checkbox replacement.

signal toggled(pressed: bool)

@export var pressed: bool = false : set = _set_pressed
@export var on_color: Color = Color(0.30, 0.70, 0.45)
@export var off_color: Color = Color(0.45, 0.45, 0.45)
@export var thumb_color: Color = Color(1, 1, 1)
@export var animate_speed: float = 12.0

var _t: float = 0.0  # 0 off, 1 on (animated)

func _ready() -> void:
	custom_minimum_size = Vector2(46, 24)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_t = 1.0 if pressed else 0.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_pressed(not pressed)
		toggled.emit(pressed)

func _process(delta: float) -> void:
	var target := 1.0 if pressed else 0.0
	if abs(_t - target) > 0.001:
		_t = move_toward(_t, target, delta * animate_speed)
		queue_redraw()

func _draw() -> void:
	var radius: float = size.y * 0.5
	var bg := off_color.lerp(on_color, _t)
	# Track (rounded rect via two circles + middle bar).
	draw_circle(Vector2(radius, radius), radius, bg)
	draw_circle(Vector2(size.x - radius, radius), radius, bg)
	draw_rect(Rect2(radius, 0, size.x - radius * 2.0, size.y), bg)
	# Thumb.
	var thumb_r := radius - 3.0
	var cx := lerp(radius, size.x - radius, _t)
	draw_circle(Vector2(cx, radius), thumb_r, thumb_color)

func _set_pressed(v: bool) -> void:
	pressed = v
	queue_redraw()
