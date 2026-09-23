@tool
extends Control
## Three-quarter preview of a wire model. Drag a vertex to move it in x/y.

signal vertex_moved(index: int, point: Vector3)

const _YAW := 0.7
const _PITCH := 0.45

var _verts: PackedVector3Array = PackedVector3Array()
var _edges: PackedInt32Array = PackedInt32Array()
var _screen: PackedVector2Array = PackedVector2Array()
var _label := ""
var _drag := -1
var _scale := 1.0
var _origin := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	custom_minimum_size = Vector2(0, 180)
	draw.connect(_on_draw)
	gui_input.connect(_on_gui_input)


func set_model(label: String, verts: PackedVector3Array, edges: PackedInt32Array) -> void:
	_label = label
	_verts = verts
	_edges = edges
	queue_redraw()


func clear_model() -> void:
	_label = ""
	_verts = PackedVector3Array()
	_edges = PackedInt32Array()
	queue_redraw()


func _on_draw() -> void:
	var bg := Color(0.07, 0.07, 0.09)
	draw_rect(Rect2(Vector2.ZERO, size), bg)
	if _verts.is_empty() or _edges.size() < 2:
		return
	_screen = PackedVector2Array()
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for v in _verts:
		var p := _project(v)
		_screen.append(p)
		min_p.x = minf(min_p.x, p.x)
		min_p.y = minf(min_p.y, p.y)
		max_p.x = maxf(max_p.x, p.x)
		max_p.y = maxf(max_p.y, p.y)
	var span := max_p - min_p
	if span.x < 0.001:
		span.x = 1.0
	if span.y < 0.001:
		span.y = 1.0
	var pad := 16.0
	var avail := size - Vector2(pad * 2.0, pad * 2.0)
	if avail.x < 8.0 or avail.y < 8.0:
		return
	_scale = minf(avail.x / span.x, avail.y / span.y)
	_origin = Vector2(pad, pad) - min_p * _scale
	_origin += (avail - span * _scale) * 0.5
	var col := Color(0.95, 0.95, 0.95)
	var i := 0
	while i + 1 < _edges.size():
		var a: int = _edges[i]
		var b: int = _edges[i + 1]
		i += 2
		if a < 0 or b < 0 or a >= _screen.size() or b >= _screen.size():
			continue
		draw_line(_to_screen(_screen[a]), _to_screen(_screen[b]), col, 1.5, true)
	for vi in _screen.size():
		var handle := _to_screen(_screen[vi])
		draw_circle(handle, 3.5, Color(1, 0.85, 0.4) if vi == _drag else Color(0.85, 0.9, 1))
	var font := ThemeDB.fallback_font
	if font != null and not _label.is_empty():
		draw_string(font, Vector2(8, 16), _label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.8, 0.9))


func _to_screen(projected: Vector2) -> Vector2:
	return projected * _scale + _origin


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_drag = _hit_vertex(mb.position)
		else:
			_drag = -1
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and _drag >= 0:
		var mm := event as InputEventMouseMotion
		var moved := _move_vertex(_drag, mm.relative)
		vertex_moved.emit(_drag, moved)
		queue_redraw()
		accept_event()


func _hit_vertex(at: Vector2) -> int:
	var best := -1
	var best_d := 10.0
	for i in _screen.size():
		var d := _to_screen(_screen[i]).distance_to(at)
		if d < best_d:
			best_d = d
			best = i
	return best


func _move_vertex(index: int, screen_delta: Vector2) -> Vector3:
	var v := _verts[index]
	var dx1 := screen_delta.x / _scale
	var dy1 := -screen_delta.y / _scale
	var cy := cos(_YAW)
	var sy := sin(_YAW)
	var cp := cos(_PITCH)
	var sp := sin(_PITCH)
	var dvx := dx1 / cy if absf(cy) > 0.2 else 0.0
	var dvy := (dy1 - dvx * sy * sp) / cp
	v.x += dvx
	v.y += dvy
	_verts[index] = v
	return v


func _project(v: Vector3) -> Vector2:
	var cy := cos(_YAW)
	var sy := sin(_YAW)
	var x := v.x * cy + v.z * sy
	var z := -v.x * sy + v.z * cy
	var cp := cos(_PITCH)
	var sp := sin(_PITCH)
	var y := v.y * cp - z * sp
	return Vector2(x, -y)
