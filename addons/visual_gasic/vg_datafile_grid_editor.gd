@tool
extends HSplitContainer
## Full-screen numeric tile grid editor for DataFile CSV / .vgd level maps.

signal back_to_code_requested
signal grid_saved(path: String)

const GridIO := preload("res://addons/visual_gasic/vg_datafile_grid_io.gd")
const Sniff := preload("res://addons/visual_gasic/vg_datafile_sniff.gd")

const BASE_CELL_PX := 16
const MIN_ZOOM := 0.5
const MAX_ZOOM := 4.0
const MAX_UNDO := 50
const MAX_PALETTE := 16

var _path_label: Label
var _status_label: Label
var _zoom_lbl: Label
var _canvas: Control
var _scroll: ScrollContainer
var _palette_box: HFlowContainer
var _save_btn: Button
var _dirty := false

var _abs_path := ""
var _res_path := ""
var _format := "csv"
var _width := 0
var _height := 0
var _cells := PackedByteArray()
var _selected_tile := 1
var _zoom := 1.0
var _tool := "paint"
var _undo_stack: Array[PackedByteArray] = []
var _paint_drag := false
var _stroke_undo_pushed := false


func _ready() -> void:
	split_offset = 168
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	set_process_input(true)
	_build_ui()


func open_ref(ref: Dictionary) -> void:
	var abs_path: String = str(ref.get("abs_path", ""))
	var res_path: String = str(ref.get("res_path", abs_path))
	open_file(res_path if not res_path.is_empty() else abs_path)


func open_file(path: String) -> void:
	var res_path := path
	if path.begins_with("/"):
		res_path = _abs_to_res(path)
	var abs_path := ProjectSettings.globalize_path(res_path) if res_path.begins_with("res://") else path
	if not FileAccess.file_exists(abs_path):
		push_warning("GridEditor: file not found " + abs_path)
		return
	var loaded := GridIO.load_path(abs_path)
	if not bool(loaded.get("ok", false)):
		push_warning("GridEditor: " + str(loaded.get("error", "load failed")))
		return
	_abs_path = abs_path
	_res_path = res_path
	_format = str(loaded.get("format", "csv"))
	_width = int(loaded.get("width", 0))
	_height = int(loaded.get("height", 0))
	_cells = loaded.get("cells", PackedByteArray())
	_dirty = false
	_undo_stack.clear()
	_selected_tile = 1
	_tool = "paint"
	_zoom = _fit_zoom()
	_update_palette()
	_refresh_ui()
	_canvas.queue_redraw()


func save() -> bool:
	if _abs_path.is_empty() or _width <= 0 or _height <= 0:
		return false
	var ok := false
	if _format == "vgd" or _abs_path.get_extension().to_lower() == "vgd":
		ok = GridIO.save_vgd_u8(_abs_path, _width, _height, _cells)
	else:
		ok = GridIO.save_csv(_abs_path, _width, _height, _cells)
	if ok:
		_dirty = false
		_save_btn.text = "Save"
		grid_saved.emit(_res_path)
	return ok


func _build_ui() -> void:
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 156
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(left)

	var back := Button.new()
	back.text = "← Back to Code"
	back.pressed.connect(func() -> void: back_to_code_requested.emit())
	left.add_child(back)

	_path_label = Label.new()
	_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_path_label.add_theme_font_size_override("font_size", 10)
	left.add_child(_path_label)

	var tools := HBoxContainer.new()
	var paint_btn := Button.new()
	paint_btn.text = "Paint"
	paint_btn.toggle_mode = true
	paint_btn.button_pressed = true
	paint_btn.pressed.connect(func() -> void: _set_tool("paint"))
	tools.add_child(paint_btn)
	var fill_btn := Button.new()
	fill_btn.text = "Fill"
	fill_btn.toggle_mode = true
	fill_btn.pressed.connect(func() -> void: _set_tool("fill"))
	tools.add_child(fill_btn)
	var erase_btn := Button.new()
	erase_btn.text = "Erase"
	erase_btn.toggle_mode = true
	erase_btn.pressed.connect(func() -> void: _set_tool("erase"))
	tools.add_child(erase_btn)
	left.add_child(tools)
	_tools = [paint_btn, fill_btn, erase_btn]

	var pal_hdr := Label.new()
	pal_hdr.text = "Tile ID"
	pal_hdr.add_theme_font_size_override("font_size", 10)
	left.add_child(pal_hdr)

	var pal_scroll := ScrollContainer.new()
	pal_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pal_scroll.custom_minimum_size = Vector2(0, 120)
	left.add_child(pal_scroll)
	_palette_box = HFlowContainer.new()
	_palette_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pal_scroll.add_child(_palette_box)

	_save_btn = Button.new()
	_save_btn.text = "Save"
	_save_btn.pressed.connect(_on_save_pressed)
	left.add_child(_save_btn)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(right)

	var top := HBoxContainer.new()
	_zoom_lbl = Label.new()
	_zoom_lbl.text = "100%"
	top.add_child(_zoom_lbl)
	var z_out := Button.new()
	z_out.text = "−"
	z_out.pressed.connect(func() -> void: _set_zoom(_zoom - 0.25))
	top.add_child(z_out)
	var z_in := Button.new()
	z_in.text = "+"
	z_in.pressed.connect(func() -> void: _set_zoom(_zoom + 0.25))
	top.add_child(z_in)
	var fit := Button.new()
	fit.text = "Fit"
	fit.pressed.connect(func() -> void: _set_zoom(_fit_zoom()))
	top.add_child(fit)
	right.add_child(top)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	right.add_child(_scroll)

	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.gui_input.connect(_on_canvas_input)
	_canvas.draw.connect(_on_canvas_draw)
	_scroll.add_child(_canvas)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 10)
	right.add_child(_status_label)


var _tools: Array = []


func _set_tool(name: String) -> void:
	_tool = name
	for i in _tools.size():
		var b: Button = _tools[i]
		var n: String = ["paint", "fill", "erase"][i]
		b.button_pressed = n == name
	if _tool == "erase":
		_selected_tile = 0


func _update_palette() -> void:
	for c in _palette_box.get_children():
		c.queue_free()
	for tid in MAX_PALETTE:
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(28, 28)
		swatch.color = Sniff.tile_preview_color(tid)
		swatch.tooltip_text = "Tile %d" % tid
		var btn := Button.new()
		btn.flat = true
		btn.custom_minimum_size = Vector2(32, 32)
		btn.tooltip_text = "Tile %d" % tid
		if tid == _selected_tile:
			btn.add_theme_color_override("font_color", Color(0.1, 0.3, 0.9))
		btn.text = str(tid)
		btn.pressed.connect(func() -> void:
			_selected_tile = tid
			_tool = "paint"
			_set_tool("paint")
			_update_palette()
		)
		var wrap := PanelContainer.new()
		var inner := VBoxContainer.new()
		inner.add_child(swatch)
		inner.add_child(btn)
		wrap.add_child(inner)
		_palette_box.add_child(wrap)


func _refresh_ui() -> void:
	_path_label.text = _res_path.get_file() if not _res_path.is_empty() else "(no file)"
	var cell_px := int(BASE_CELL_PX * _zoom)
	_canvas.custom_minimum_size = Vector2(_width * cell_px + 2, _height * cell_px + 2)
	_canvas.size = _canvas.custom_minimum_size
	_zoom_lbl.text = "%d%%" % int(_zoom * 100.0)
	_status_label.text = "%d×%d  ·  %s  ·  tile %d" % [_width, _height, _format, _selected_tile]
	_save_btn.text = "Save *" if _dirty else "Save"
	_canvas.queue_redraw()


func _fit_zoom() -> float:
	if _width <= 0 or _height <= 0:
		return 1.0
	var view := _scroll.size if is_instance_valid(_scroll) and _scroll.size.x > 40 else Vector2(640, 480)
	var zx := view.x / float(_width * BASE_CELL_PX + 16)
	var zy := view.y / float(_height * BASE_CELL_PX + 16)
	return clampf(minf(zx, zy), MIN_ZOOM, MAX_ZOOM)


func _set_zoom(z: float) -> void:
	_zoom = clampf(z, MIN_ZOOM, MAX_ZOOM)
	_refresh_ui()


func _on_canvas_draw() -> void:
	if _width <= 0 or _height <= 0:
		return
	var cell_px := int(BASE_CELL_PX * _zoom)
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), Color(0.38, 0.40, 0.45), true)
	for y in _height:
		for x in _width:
			var idx := y * _width + x
			var tid := int(_cells[idx]) if idx < _cells.size() else 0
			var r := Rect2(x * cell_px + 1, y * cell_px + 1, cell_px - 1, cell_px - 1)
			_canvas.draw_rect(r, Sniff.tile_preview_color(tid), true)
			if cell_px >= 10:
				_canvas.draw_rect(r, Color(0, 0, 0, 0.15), false, 1.0)


func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.shift_pressed:
			_set_zoom(_zoom + 0.25)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.shift_pressed:
			_set_zoom(_zoom - 0.25)
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_stroke_undo_pushed = false
				_paint_at_event(event, true)
				_paint_drag = true
			else:
				_paint_drag = false
	elif event is InputEventMouseMotion and _paint_drag:
		_paint_at_event(event, false)


func _paint_at_event(event: InputEvent, push_undo: bool) -> void:
	if push_undo and not _stroke_undo_pushed:
		_push_undo()
		_stroke_undo_pushed = true
	var cell_px := maxi(1, int(BASE_CELL_PX * _zoom))
	var local := _canvas.get_local_mouse_position()
	var x := int(local.x / cell_px)
	var y := int(local.y / cell_px)
	if x < 0 or y < 0 or x >= _width or y >= _height:
		return
	var idx := y * _width + x
	var tile := 0 if _tool == "erase" else _selected_tile
	if _tool == "fill":
		_flood_fill(x, y, tile)
	else:
		_cells[idx] = tile
	_mark_dirty()
	_canvas.queue_redraw()


func _flood_fill(sx: int, sy: int, new_tile: int) -> void:
	var old := int(_cells[sy * _width + sx])
	if old == new_tile:
		return
	var stack: Array = [[sx, sy]]
	var seen := {}
	while not stack.is_empty():
		var p: Array = stack.pop_back()
		var x: int = p[0]
		var y: int = p[1]
		var key := "%d,%d" % [x, y]
		if seen.has(key):
			continue
		if x < 0 or y < 0 or x >= _width or y >= _height:
			continue
		var idx := y * _width + x
		if int(_cells[idx]) != old:
			continue
		seen[key] = true
		_cells[idx] = new_tile
		stack.append([x + 1, y])
		stack.append([x - 1, y])
		stack.append([x, y + 1])
		stack.append([x, y - 1])


func _push_undo() -> void:
	_undo_stack.append(_cells.duplicate())
	if _undo_stack.size() > MAX_UNDO:
		_undo_stack.pop_front()


func _mark_dirty() -> void:
	_dirty = true
	_save_btn.text = "Save *"


func _on_save_pressed() -> void:
	if not save():
		push_warning("GridEditor: save failed for " + _abs_path)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.ctrl_pressed:
		if event.keycode == KEY_S:
			_on_save_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Z:
			if _undo_stack.size() > 0:
				_cells = _undo_stack.pop_back()
				_mark_dirty()
				_canvas.queue_redraw()
			get_viewport().set_input_as_handled()


func _abs_to_res(abs_path: String) -> String:
	var proj := ProjectSettings.globalize_path("res://")
	if abs_path.begins_with(proj):
		return "res://" + abs_path.substr(proj.length())
	return abs_path
