@tool
extends Control
## Shared vector preview canvas: grid snap, point drag, zoom, pan.

signal shapes_edited(shapes: Array)

const HANDLE_R := 5.0
const MIN_ZOOM := 0.25
const MAX_ZOOM := 8.0

var view_w: int = 320
var view_h: int = 240
var grid_step: int = 8
var shapes: Array = []

var _zoom := 1.0
var _pan := Vector2.ZERO
var _selected := Vector2i(-1, -1)
var _dragging := false
var _panning := false
var _last_mouse := Vector2.ZERO
var _user_view_override := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_CLICK
	custom_minimum_size = Vector2(160, 120)
	# Without clipping, grid/shape draw calls can bleed into the Context Rail
	# when layout assigns a transient oversized size before the deferred refit.
	clip_contents = true
	resized.connect(_on_resized)
	draw.connect(_on_draw)
	gui_input.connect(_on_gui_input)


func set_model(vw: int, vh: int, step: int, model_shapes: Array) -> void:
	view_w = maxi(1, vw)
	view_h = maxi(1, vh)
	grid_step = maxi(0, step)
	shapes = _duplicate_shapes(model_shapes)
	_user_view_override = false
	_fit_view()
	queue_redraw()
	# Context-rail layout often assigns final width/height after set_model().
	call_deferred("_refit_if_auto")


func _on_resized() -> void:
	if not _user_view_override:
		_fit_view()
	queue_redraw()


func _refit_if_auto() -> void:
	if _user_view_override:
		return
	_fit_view()
	queue_redraw()


func get_shapes() -> Array:
	return _duplicate_shapes(shapes)


func clear_model() -> void:
	shapes = []
	_selected = Vector2i(-1, -1)
	queue_redraw()


func _fit_view() -> void:
	if view_w <= 0 or view_h <= 0:
		return
	var pad := 16.0
	var avail := size - Vector2(pad * 2.0, pad * 2.0)
	if avail.x < 8.0 or avail.y < 8.0:
		return
	_zoom = clampf(minf(avail.x / float(view_w), avail.y / float(view_h)), MIN_ZOOM, MAX_ZOOM)
	var doc_size := Vector2(view_w, view_h) * _zoom
	_pan = (size - doc_size) * 0.5


## Headless tests: fit zoom for a wide block inside a typical context-rail canvas.
func debug_fit_state() -> Dictionary:
	return {"zoom": _zoom, "pan": _pan, "size": size, "doc_size": Vector2(view_w, view_h) * _zoom}


func _duplicate_shapes(src: Array) -> Array:
	var out: Array = []
	for shape in src:
		if not shape is Dictionary:
			continue
		var copy: Dictionary = shape.duplicate(true)
		var pts: PackedVector2Array = shape.get("points", PackedVector2Array())
		copy["points"] = pts.duplicate()
		out.append(copy)
	return out


func _world_to_screen(p: Vector2) -> Vector2:
	return _pan + p * _zoom


func _screen_to_world(p: Vector2) -> Vector2:
	return (p - _pan) / _zoom


func _snap(v: Vector2) -> Vector2:
	if grid_step <= 0:
		return v
	return Vector2(
		roundf(v.x / float(grid_step)) * float(grid_step),
		roundf(v.y / float(grid_step)) * float(grid_step),
	)


func _stroke_color(shape: Dictionary) -> Color:
	return Color(
		int(shape.get("stroke_r", 255)) / 255.0,
		int(shape.get("stroke_g", 255)) / 255.0,
		int(shape.get("stroke_b", 255)) / 255.0,
		int(shape.get("stroke_a", 255)) / 255.0,
	)


func _on_draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.57, 0.62))
	if shapes.is_empty() and view_w <= 0:
		return
	var doc := Rect2(_world_to_screen(Vector2.ZERO), Vector2(view_w, view_h) * _zoom)
	var clip := doc.intersection(Rect2(Vector2.ZERO, size))
	if clip.size.x <= 0.0 or clip.size.y <= 0.0:
		return
	draw_rect(doc, Color(0.92, 0.93, 0.95))
	draw_rect(doc, Color(0.35, 0.38, 0.42), false, 1.0)
	if grid_step > 0:
		var col := Color(0.78, 0.80, 0.84, 0.55)
		for x in range(0, view_w + 1, grid_step):
			var sx := _world_to_screen(Vector2(x, 0)).x
			if sx < clip.position.x - 1.0 or sx > clip.end.x + 1.0:
				continue
			draw_line(Vector2(sx, clip.position.y), Vector2(sx, clip.end.y), col, 1.0)
		for y in range(0, view_h + 1, grid_step):
			var sy := _world_to_screen(Vector2(0, y)).y
			if sy < clip.position.y - 1.0 or sy > clip.end.y + 1.0:
				continue
			draw_line(Vector2(clip.position.x, sy), Vector2(clip.end.x, sy), col, 1.0)
	for si in shapes.size():
		_draw_shape(shapes[si], si, clip)


func _draw_shape(shape: Dictionary, shape_idx: int, clip: Rect2 = Rect2()) -> void:
	var typ: String = str(shape.get("type", "LINE")).to_upper()
	var pts: PackedVector2Array = shape.get("points", PackedVector2Array())
	if pts.is_empty():
		return
	var col := _stroke_color(shape)
	var stroke_w := float(shape.get("stroke_w", 1.0))
	var w := maxf(1.0, stroke_w * _zoom)
	if typ == "RECT" and pts.size() >= 2:
		var a := _world_to_screen(pts[0])
		var b := _world_to_screen(pts[1])
		var tl := Vector2(minf(a.x, b.x), minf(a.y, b.y))
		var rect := Rect2(tl, Vector2(absf(b.x - a.x), absf(b.y - a.y)))
		if stroke_w <= 0.0:
			draw_rect(rect, col, true)
		else:
			draw_rect(rect, col, false, w)
	elif typ == "LINE" and pts.size() >= 2:
		draw_line(_world_to_screen(pts[0]), _world_to_screen(pts[1]), col, w)
	else:
		for i in pts.size() - 1:
			draw_line(_world_to_screen(pts[i]), _world_to_screen(pts[i + 1]), col, w)
	for pi in pts.size():
		var sel := shape_idx == _selected.x and pi == _selected.y
		var hp := _world_to_screen(pts[pi])
		if clip.size.x > 0.0 and clip.size.y > 0.0 and not clip.has_point(hp):
			continue
		draw_circle(hp, HANDLE_R if sel else HANDLE_R - 1.5, Color(0.95, 0.95, 1.0) if sel else Color(1, 1, 1))
		draw_arc(hp, HANDLE_R if sel else HANDLE_R - 1.5, 0, TAU, 16, Color(0.1, 0.1, 0.45), 1.5)


func _hit_handle(at: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := HANDLE_R * 2.5
	for si in shapes.size():
		var pts: PackedVector2Array = shapes[si].get("points", PackedVector2Array())
		for pi in pts.size():
			var d := at.distance_to(_world_to_screen(pts[pi]))
			if d <= best_d:
				best_d = d
				best = Vector2i(si, pi)
	return best


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_user_view_override = true
			_zoom = clampf(_zoom * 1.1, MIN_ZOOM, MAX_ZOOM)
			queue_redraw()
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_user_view_override = true
			_zoom = clampf(_zoom / 1.1, MIN_ZOOM, MAX_ZOOM)
			queue_redraw()
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				_user_view_override = true
			_panning = mb.pressed
			_last_mouse = mb.position
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var hit := _hit_handle(mb.position)
			if hit.x >= 0:
				_remove_point(hit.x, hit.y)
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var hit := _hit_handle(mb.position)
				if hit.x >= 0:
					_selected = hit
					_dragging = true
				elif mb.shift_pressed:
					_append_point(_screen_to_world(mb.position))
				else:
					_selected = Vector2i(-1, -1)
				queue_redraw()
			else:
				if _dragging:
					shapes_edited.emit(get_shapes())
				_dragging = false
			accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _panning:
			_pan += mm.position - _last_mouse
			_last_mouse = mm.position
			queue_redraw()
			accept_event()
			return
		if _dragging and _selected.x >= 0:
			var shape: Dictionary = shapes[_selected.x]
			var pts: PackedVector2Array = shape.get("points", PackedVector2Array())
			if _selected.y < pts.size():
				pts[_selected.y] = _snap(_screen_to_world(mm.position))
				shape["points"] = pts
				shapes[_selected.x] = shape
				queue_redraw()
			accept_event()


func _remove_point(shape_idx: int, point_idx: int) -> void:
	var shape: Dictionary = shapes[shape_idx]
	var typ: String = str(shape.get("type", "LINE")).to_upper()
	var pts: PackedVector2Array = shape.get("points", PackedVector2Array())
	var min_pts := 2
	if typ in ["LINE", "RECT"]:
		min_pts = 2
	if pts.size() <= min_pts:
		return
	var next := PackedVector2Array()
	for i in pts.size():
		if i != point_idx:
			next.append(pts[i])
	shape["points"] = next
	shapes[shape_idx] = shape
	_selected = Vector2i(-1, -1)
	queue_redraw()
	shapes_edited.emit(get_shapes())


func _append_point(world: Vector2) -> void:
	if shapes.is_empty():
		var p := _snap(world)
		shapes.append({
			"type": "POLYLINE",
			"points": PackedVector2Array([p, p + Vector2(grid_step if grid_step > 0 else 8, 0)]),
			"stroke_r": 255, "stroke_g": 255, "stroke_b": 255, "stroke_a": 255, "stroke_w": 2.0,
		})
		_selected = Vector2i(shapes.size() - 1, 0)
		queue_redraw()
		shapes_edited.emit(get_shapes())
		return
	var si := _selected.x if _selected.x >= 0 else shapes.size() - 1
	var shape: Dictionary = shapes[si]
	var typ: String = str(shape.get("type", "LINE")).to_upper()
	if typ in ["LINE", "RECT"]:
		return
	var pts: PackedVector2Array = shape.get("points", PackedVector2Array())
	pts.append(_snap(world))
	shape["points"] = pts
	shapes[si] = shape
	_selected = Vector2i(si, pts.size() - 1)
	queue_redraw()
	shapes_edited.emit(get_shapes())
