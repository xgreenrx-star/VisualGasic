@tool
extends Control
## Game UI — Radial / pie menu for quick item or ability selection.
## Draws wedge segments in a circle with icons and labels.

signal item_clicked(index: int)
signal item_hovered(index: int)
signal menu_opened
signal menu_closed

# ── VB6-style properties ──────────────────────────────────────

@export var ItemCount: int = 6:
	set(v):
		ItemCount = clampi(v, 2, 12)
		queue_redraw()

@export var Radius: float = 80.0:
	set(v):
		Radius = v
		queue_redraw()

@export var ItemLabels: String = "Attack,Defend,Magic,Items,Flee,Status":
	set(v):
		ItemLabels = v
		queue_redraw()

@export var CenterRadius: float = 20.0
@export var SelectedIndex: int = -1:
	set(v):
		SelectedIndex = v
		queue_redraw()

@export_enum("FadeIn", "ScaleUp", "None") var ShowAnimation: int = 1
@export var TransitionSpeed: float = 0.25
@export var WedgeColor: Color = Color(0.15, 0.18, 0.25, 0.9)
@export var SelectedColor: Color = Color(0.3, 0.5, 0.8, 0.9)
@export var BorderColor: Color = Color(0.4, 0.5, 0.7, 0.6)

var _tween: Tween
var _hovered_index: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(Radius * 2 + 20, Radius * 2 + 20)
	if Engine.is_editor_hint():
		visible = true
		modulate = Color(1, 1, 1, 1)

func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var idx := _get_wedge_at(event.position)
			if idx >= 0:
				select_item(idx)
				accept_event()
	elif event is InputEventMouseMotion:
		var idx := _get_wedge_at(event.position)
		if idx != _hovered_index:
			_hovered_index = idx
			if idx >= 0:
				item_hovered.emit(idx)
			queue_redraw()

## Returns the wedge index at the given local position, or -1 if outside the ring.
func _get_wedge_at(pos: Vector2) -> int:
	var center := size * 0.5
	var offset := pos - center
	var dist := offset.length()
	if dist < CenterRadius or dist > Radius:
		return -1
	var angle := atan2(offset.y, offset.x)
	# Normalize: wedges start from top (-PI/2)
	angle += PI / 2.0
	if angle < 0.0:
		angle += TAU
	var step := TAU / float(ItemCount)
	return int(angle / step) % ItemCount

func _draw() -> void:
	var center := size * 0.5
	var labels := ItemLabels.split(",")
	var angle_step := TAU / float(ItemCount)

	for i in range(ItemCount):
		var start_angle := -PI / 2.0 + angle_step * i
		var end_angle := start_angle + angle_step
		var is_selected := (i == SelectedIndex)
		var is_hovered := (i == _hovered_index and not is_selected)
		var color := SelectedColor if is_selected else (WedgeColor.lightened(0.15) if is_hovered else WedgeColor)

		# Draw wedge as polygon
		var points := PackedVector2Array()
		points.append(center + Vector2(cos(start_angle), sin(start_angle)) * CenterRadius)
		var steps := 16
		for s in range(steps + 1):
			var a := start_angle + (end_angle - start_angle) * float(s) / float(steps)
			points.append(center + Vector2(cos(a), sin(a)) * Radius)
		points.append(center + Vector2(cos(end_angle), sin(end_angle)) * CenterRadius)
		draw_colored_polygon(points, color)

		# Draw border lines
		draw_line(center + Vector2(cos(start_angle), sin(start_angle)) * CenterRadius,
				  center + Vector2(cos(start_angle), sin(start_angle)) * Radius, BorderColor, 1.0)

		# Draw label at midpoint
		var mid_angle := (start_angle + end_angle) * 0.5
		var label_pos := center + Vector2(cos(mid_angle), sin(mid_angle)) * (Radius * 0.6)
		var font := get_theme_default_font()
		if font and i < labels.size():
			var lbl: String = labels[i].strip_edges()
			var tw := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_CENTER, -1, 10).x
			draw_string(font, label_pos - Vector2(tw * 0.5, -4), lbl,
						HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.9, 0.9, 0.95))

	# Center circle
	draw_circle(center, CenterRadius, Color(0.1, 0.1, 0.15, 0.95))
	draw_arc(center, CenterRadius, 0, TAU, 32, BorderColor, 1.0)
	draw_arc(center, Radius, 0, TAU, 64, BorderColor, 1.0)

func show_menu() -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	visible = true
	match ShowAnimation:
		0:
			modulate.a = 0.0
			_tween.tween_property(self, "modulate:a", 1.0, TransitionSpeed)
		1:
			scale = Vector2(0.3, 0.3)
			modulate.a = 0.0
			pivot_offset = size * 0.5
			_tween.tween_property(self, "scale", Vector2.ONE, TransitionSpeed).set_trans(Tween.TRANS_BACK)
			_tween.parallel().tween_property(self, "modulate:a", 1.0, TransitionSpeed * 0.5)
		_:
			modulate.a = 1.0
	menu_opened.emit()

func hide_menu() -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, TransitionSpeed * 0.5)
	_tween.tween_callback(func(): visible = false)
	menu_closed.emit()

func select_item(index: int) -> void:
	SelectedIndex = index
	item_clicked.emit(index)
