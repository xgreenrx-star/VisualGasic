@tool
extends HSplitContainer
## Full-screen numeric tile grid editor for DataFile CSV / .vgd level maps.

signal back_to_code_requested
signal grid_saved(path: String)
signal goto_source_line(file: String, line: int)
signal source_fixes_applied(files: PackedStringArray)

const GridIO := preload("res://addons/visual_gasic/vg_datafile_grid_io.gd")
const Sniff := preload("res://addons/visual_gasic/vg_datafile_sniff.gd")
const UsageAnalyzer := preload("res://addons/visual_gasic/vg_datafile_usage_analyzer.gd")
const ResizeDialogScript := preload("res://addons/visual_gasic/vg_datafile_resize_dialog.gd")

const BASE_CELL_PX := 16
const MIN_ZOOM := 0.5
const MAX_ZOOM := 4.0
const MAX_UNDO := 50
const MAX_PALETTE := 16

const CREAM_BG := Color(0.941, 0.929, 0.910)
const PANEL_BORDER := Color(0.72, 0.71, 0.68)
const TEXT_DARK := Color(0.1, 0.1, 0.1)
const LABEL_MUTED := Color(0.35, 0.35, 0.5)
const INPUT_BG := Color(1.0, 1.0, 1.0)
const PALETTE_CELL_W := 38
const RULER_PX := 22

var _path_label: Label
var _status_label: Label
var _zoom_lbl: Label
var _canvas: Control
var _scroll: ScrollContainer
var _palette_box: GridContainer
var _save_btn: Button
var _resize_w_spin: SpinBox
var _resize_h_spin: SpinBox
var _lock_aspect: CheckBox
var _aspect_ratio := 1.0
var _syncing_resize_spins := false
var _dirty := false

var _abs_path := ""
var _res_path := ""
var _label := ""
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
var _hover_col := -1
var _hover_row := -1


func _ready() -> void:
	split_offset = 180
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	set_process_input(true)
	_build_ui()


func open_ref(ref: Dictionary) -> void:
	var abs_path: String = str(ref.get("abs_path", ""))
	var res_path: String = str(ref.get("res_path", abs_path))
	_label = str(ref.get("label", ""))
	open_file(res_path if not res_path.is_empty() else abs_path)
	if _label.is_empty() and not _res_path.is_empty():
		_label = UsageAnalyzer.find_label_for_path(_res_path)


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
	_aspect_ratio = float(_width) / maxf(1.0, float(_height))
	_dirty = false
	_undo_stack.clear()
	_selected_tile = 1
	_tool = "paint"
	_zoom = _fit_zoom()
	_sync_resize_spins()
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
	var left_panel := _cream_panel()
	left_panel.custom_minimum_size.x = 168
	add_child(left_panel)
	var left := VBoxContainer.new()
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	left_panel.add_child(left)

	var back := Button.new()
	back.text = "← Back to Code"
	_style_tool_button(back)
	back.pressed.connect(func() -> void: back_to_code_requested.emit())
	left.add_child(back)

	_path_label = Label.new()
	_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_path_label.add_theme_font_size_override("font_size", 10)
	_style_label(_path_label, true)
	left.add_child(_path_label)

	var tools := HBoxContainer.new()
	var paint_btn := Button.new()
	paint_btn.text = "Paint"
	paint_btn.toggle_mode = true
	paint_btn.button_pressed = true
	_style_tool_button(paint_btn)
	paint_btn.pressed.connect(func() -> void: _set_tool("paint"))
	tools.add_child(paint_btn)
	var fill_btn := Button.new()
	fill_btn.text = "Fill"
	fill_btn.toggle_mode = true
	_style_tool_button(fill_btn)
	fill_btn.pressed.connect(func() -> void: _set_tool("fill"))
	tools.add_child(fill_btn)
	var erase_btn := Button.new()
	erase_btn.text = "Erase"
	erase_btn.toggle_mode = true
	_style_tool_button(erase_btn)
	erase_btn.pressed.connect(func() -> void: _set_tool("erase"))
	tools.add_child(erase_btn)
	left.add_child(tools)
	_tools = [paint_btn, fill_btn, erase_btn]

	var size_hdr := Label.new()
	size_hdr.text = "Grid size (columns × rows)"
	size_hdr.add_theme_font_size_override("font_size", 11)
	_style_label(size_hdr)
	left.add_child(size_hdr)
	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 6)
	var w_box := VBoxContainer.new()
	var w_lbl := Label.new()
	w_lbl.text = "Cols"
	w_lbl.add_theme_font_size_override("font_size", 9)
	_style_label(w_lbl, true)
	w_box.add_child(w_lbl)
	_resize_w_spin = _make_spinbox()
	_resize_w_spin.tooltip_text = "Width in tiles (columns)"
	w_box.add_child(_resize_w_spin)
	size_row.add_child(w_box)
	var x_lbl := Label.new()
	x_lbl.text = "×"
	x_lbl.add_theme_color_override("font_color", TEXT_DARK)
	x_lbl.add_theme_font_size_override("font_size", 14)
	size_row.add_child(x_lbl)
	var h_box := VBoxContainer.new()
	var h_lbl := Label.new()
	h_lbl.text = "Rows"
	h_lbl.add_theme_font_size_override("font_size", 9)
	_style_label(h_lbl, true)
	h_box.add_child(h_lbl)
	_resize_h_spin = _make_spinbox()
	_resize_h_spin.tooltip_text = "Height in tiles (rows)"
	h_box.add_child(_resize_h_spin)
	size_row.add_child(h_box)
	left.add_child(size_row)
	_lock_aspect = CheckBox.new()
	_lock_aspect.text = "Lock aspect ratio"
	_lock_aspect.tooltip_text = "Keep columns:rows proportional when changing either dimension"
	_style_checkbox(_lock_aspect)
	left.add_child(_lock_aspect)
	_resize_w_spin.value_changed.connect(_on_resize_w_changed)
	_resize_h_spin.value_changed.connect(_on_resize_h_changed)
	var resize_btn := Button.new()
	resize_btn.text = "Resize…"
	_style_tool_button(resize_btn)
	resize_btn.tooltip_text = "Apply new dimensions and review PeekData / constant impact in code"
	resize_btn.pressed.connect(_on_resize_pressed)
	left.add_child(resize_btn)
	var size_hint := Label.new()
	size_hint.text = "Cols/rows update the preview immediately. Click Resize… to rewrite the file."
	size_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	size_hint.add_theme_font_size_override("font_size", 9)
	_style_label(size_hint, true)
	left.add_child(size_hint)

	var pal_hdr := Label.new()
	pal_hdr.text = "Tile ID"
	pal_hdr.add_theme_font_size_override("font_size", 10)
	_style_label(pal_hdr)
	left.add_child(pal_hdr)

	var pal_scroll := ScrollContainer.new()
	pal_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pal_scroll.custom_minimum_size = Vector2(0, 120)
	left.add_child(pal_scroll)
	_palette_box = GridContainer.new()
	_palette_box.columns = 4
	_palette_box.add_theme_constant_override("h_separation", 4)
	_palette_box.add_theme_constant_override("v_separation", 4)
	_palette_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pal_scroll.add_child(_palette_box)

	_save_btn = Button.new()
	_save_btn.text = "Save"
	_style_tool_button(_save_btn)
	_save_btn.pressed.connect(_on_save_pressed)
	left.add_child(_save_btn)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(right)

	var top_panel := _cream_panel()
	top_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(top_panel)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top_panel.add_child(top)
	var zoom_title := Label.new()
	zoom_title.text = "Zoom"
	zoom_title.add_theme_font_size_override("font_size", 10)
	_style_label(zoom_title, true)
	top.add_child(zoom_title)
	_zoom_lbl = Label.new()
	_zoom_lbl.text = "100%"
	_zoom_lbl.add_theme_font_size_override("font_size", 12)
	_style_label(_zoom_lbl)
	top.add_child(_zoom_lbl)
	var z_out := Button.new()
	z_out.text = "−"
	_style_tool_button(z_out)
	z_out.pressed.connect(func() -> void: _set_zoom(_zoom - 0.25))
	top.add_child(z_out)
	var z_in := Button.new()
	z_in.text = "+"
	_style_tool_button(z_in)
	z_in.pressed.connect(func() -> void: _set_zoom(_zoom + 0.25))
	top.add_child(z_in)
	var fit := Button.new()
	fit.text = "Fit"
	_style_tool_button(fit)
	fit.pressed.connect(func() -> void: _set_zoom(_fit_zoom()))
	top.add_child(fit)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	right.add_child(_scroll)

	_canvas = Control.new()
	_canvas.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_canvas.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.gui_input.connect(_on_canvas_input)
	_canvas.draw.connect(_on_canvas_draw)
	_scroll.add_child(_canvas)

	var status_panel := _cream_panel()
	status_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(status_panel)
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 10)
	_style_label(_status_label)
	status_panel.add_child(_status_label)

	call_deferred("_style_spinbox_internals", _resize_w_spin)
	call_deferred("_style_spinbox_internals", _resize_h_spin)


func _cream_panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = CREAM_BG
	sb.border_color = PANEL_BORDER
	sb.set_border_width_all(1)
	sb.set_content_margin_all(6)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _style_label(l: Label, muted: bool = false) -> void:
	l.add_theme_color_override("font_color", LABEL_MUTED if muted else TEXT_DARK)


func _style_checkbox(cb: CheckBox) -> void:
	cb.add_theme_color_override("font_color", TEXT_DARK)
	cb.add_theme_color_override("font_hover_color", TEXT_DARK)
	cb.add_theme_color_override("font_pressed_color", TEXT_DARK)


func _style_tool_button(btn: Button) -> void:
	btn.add_theme_color_override("font_color", TEXT_DARK)
	btn.add_theme_color_override("font_hover_color", TEXT_DARK)
	btn.add_theme_color_override("font_pressed_color", TEXT_DARK)
	var normal := StyleBoxFlat.new()
	normal.bg_color = CREAM_BG
	normal.border_color = PANEL_BORDER
	normal.set_border_width_all(1)
	normal.content_margin_left = 6
	normal.content_margin_right = 6
	normal.content_margin_top = 3
	normal.content_margin_bottom = 3
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.95, 0.94, 0.92)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.88, 0.87, 0.85)
	btn.add_theme_stylebox_override("pressed", pressed)


func _style_spinbox_internals(sp: SpinBox) -> void:
	if sp == null or not is_instance_valid(sp):
		return
	sp.add_theme_color_override("font_color", TEXT_DARK)
	var sb := StyleBoxFlat.new()
	sb.bg_color = INPUT_BG
	sb.border_color = PANEL_BORDER
	sb.set_border_width_all(1)
	sb.set_content_margin_all(3)
	sp.add_theme_stylebox_override("normal", sb)
	var le := sp.get_line_edit()
	if le:
		le.add_theme_color_override("font_color", TEXT_DARK)
		le.add_theme_stylebox_override("normal", sb.duplicate())
		le.add_theme_stylebox_override("focus", sb.duplicate())
	for child in sp.get_children():
		if child is Button:
			_style_tool_button(child)


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
		var cell := _make_palette_cell(tid)
		_palette_box.add_child(cell)


func _make_palette_cell(tid: int) -> PanelContainer:
	var wrap := PanelContainer.new()
	wrap.custom_minimum_size = Vector2(PALETTE_CELL_W, 46)
	var cell_sb := StyleBoxFlat.new()
	cell_sb.bg_color = INPUT_BG
	cell_sb.border_color = PANEL_BORDER if tid != _selected_tile else Color(0.1, 0.3, 0.9)
	cell_sb.set_border_width_all(2 if tid == _selected_tile else 1)
	cell_sb.set_content_margin_all(2)
	wrap.add_theme_stylebox_override("panel", cell_sb)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 2)
	inner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrap.add_child(inner)
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(PALETTE_CELL_W - 8, 24)
	swatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	swatch.color = Sniff.tile_preview_color(tid)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(swatch)
	var num := Label.new()
	num.text = str(tid)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.custom_minimum_size.x = PALETTE_CELL_W - 4
	num.add_theme_font_size_override("font_size", 10)
	num.add_theme_color_override("font_color", Color(0.1, 0.3, 0.9) if tid == _selected_tile else TEXT_DARK)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(num)
	var pick := Button.new()
	pick.flat = true
	pick.set_anchors_preset(Control.PRESET_FULL_RECT)
	pick.mouse_filter = Control.MOUSE_FILTER_STOP
	pick.tooltip_text = "Tile %d" % tid
	pick.pressed.connect(func() -> void:
		_selected_tile = tid
		_tool = "paint"
		_set_tool("paint")
		_update_palette()
	)
	wrap.add_child(pick)
	pick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return wrap


func _refresh_ui() -> void:
	var label_txt := ("  ·  " + _label) if not _label.is_empty() else ""
	_path_label.text = (_res_path.get_file() if not _res_path.is_empty() else "(no file)") + label_txt
	_zoom_lbl.text = "%d%%" % int(_zoom * 100.0)
	_update_status_text()
	_save_btn.text = "Save *" if _dirty else "Save"
	_refresh_canvas_layout()


func _display_width() -> int:
	if _resize_w_spin != null:
		return maxi(1, int(_resize_w_spin.value))
	return _width


func _display_height() -> int:
	if _resize_h_spin != null:
		return maxi(1, int(_resize_h_spin.value))
	return _height


func _has_pending_resize() -> bool:
	return _display_width() != _width or _display_height() != _height


func _update_status_text() -> void:
	var dw := _display_width()
	var dh := _display_height()
	var dim_txt := "%d×%d" % [_width, _height]
	if _has_pending_resize():
		dim_txt += " → preview %d×%d" % [dw, dh]
	var base := "%s  ·  %s  ·  tile %d" % [dim_txt, _format, _selected_tile]
	if _hover_col >= 0 and _hover_row >= 0:
		base += "  ·  cell (%d, %d)" % [_hover_col, _hover_row]
	_status_label.text = base


func _cell_px() -> int:
	return maxi(1, int(BASE_CELL_PX * _zoom))


func _grid_origin() -> Vector2:
	return Vector2(float(_ruler_size()), float(_ruler_size()))


func _ruler_size() -> int:
	return RULER_PX


func _grid_pixel_size(cell_px: int, grid_w: int = -1, grid_h: int = -1) -> Vector2:
	var w := grid_w if grid_w > 0 else _display_width()
	var h := grid_h if grid_h > 0 else _display_height()
	return Vector2(float(w * cell_px + 2), float(h * cell_px + 2))


func _canvas_pixel_size(cell_px: int) -> Vector2:
	var grid_sz := _grid_pixel_size(cell_px)
	return Vector2(grid_sz.x + float(_ruler_size()), grid_sz.y + float(_ruler_size()))


func _refresh_canvas_layout() -> void:
	if _canvas == null:
		return
	var cell_px := _cell_px()
	var sz := _canvas_pixel_size(cell_px)
	_canvas.custom_minimum_size = sz
	_canvas.reset_size()
	_canvas.size = sz
	_canvas.queue_redraw()
	if is_instance_valid(_scroll):
		_scroll.update_minimum_size()
		_scroll.queue_sort()


func _sync_resize_spins() -> void:
	if _resize_w_spin == null or _resize_h_spin == null:
		return
	_syncing_resize_spins = true
	_resize_w_spin.set_value_no_signal(_width)
	_resize_h_spin.set_value_no_signal(_height)
	_syncing_resize_spins = false


func _on_resize_w_changed(value: float) -> void:
	if not _syncing_resize_spins and _lock_aspect != null and _lock_aspect.button_pressed:
		_syncing_resize_spins = true
		var nh := maxi(1, roundi(float(value) / maxf(0.001, _aspect_ratio)))
		_resize_h_spin.set_value_no_signal(nh)
		_syncing_resize_spins = false
	_refresh_canvas_layout()
	_update_status_text()


func _on_resize_h_changed(value: float) -> void:
	if not _syncing_resize_spins and _lock_aspect != null and _lock_aspect.button_pressed:
		_syncing_resize_spins = true
		var nw := maxi(1, roundi(float(value) * _aspect_ratio))
		_resize_w_spin.set_value_no_signal(nw)
		_syncing_resize_spins = false
	_refresh_canvas_layout()
	_update_status_text()


func _make_spinbox() -> SpinBox:
	var sp := SpinBox.new()
	sp.min_value = 1
	sp.max_value = 512
	sp.custom_minimum_size.x = 56
	return sp


func _on_resize_pressed() -> void:
	if _width <= 0 or _height <= 0:
		return
	var nw := int(_resize_w_spin.value)
	var nh := int(_resize_h_spin.value)
	if nw == _width and nh == _height:
		return
	var dlg: AcceptDialog = ResizeDialogScript.new()
	dlg.resize_confirmed.connect(_on_resize_confirmed, CONNECT_ONE_SHOT)
	dlg.goto_line_requested.connect(_on_goto_source_line)
	var host := get_tree().root if get_tree() else self
	host.add_child(dlg)
	dlg.open_for(_label, _width, _height, nw, nh)


func _on_goto_source_line(file: String, line: int) -> void:
	goto_source_line.emit(file, line)


func _on_resize_confirmed(new_w: int, new_h: int, fix_indices: Array, findings: Array) -> void:
	call_deferred("_apply_resize_deferred", new_w, new_h, fix_indices, findings)


func _apply_resize_deferred(new_w: int, new_h: int, fix_indices: Array, findings: Array) -> void:
	if new_w == _width and new_h == _height:
		return
	var to_fix: Array = fix_indices if not fix_indices.is_empty() else _auto_fix_indices(findings)
	if not to_fix.is_empty() and not findings.is_empty():
		var result := UsageAnalyzer.apply_selected_fixes(findings, to_fix)
		var fixed_files: PackedStringArray = result.get("files", PackedStringArray())
		if int(result.get("applied", 0)) > 0 and not fixed_files.is_empty():
			call_deferred("_emit_source_fixes_applied", fixed_files)
		if not bool(result.get("ok", true)):
			push_warning("GridEditor: some source fixes failed: " + str(result.get("errors", [])))
	_push_undo()
	_cells = GridIO.resize_cells(_cells, _width, _height, new_w, new_h, 0)
	_width = new_w
	_height = new_h
	_aspect_ratio = float(_width) / maxf(1.0, float(_height))
	_mark_dirty()
	_sync_resize_spins()
	_refresh_ui()
	save()
	call_deferred("_refresh_canvas_layout")


func _auto_fix_indices(findings: Array) -> Array:
	var out: Array = []
	for i in findings.size():
		if bool(findings[i].get("auto_fixable", false)):
			out.append(i)
	return out


func _emit_source_fixes_applied(files: PackedStringArray) -> void:
	source_fixes_applied.emit(files)


func _set_zoom(z: float) -> void:
	_zoom = clampf(z, MIN_ZOOM, MAX_ZOOM)
	_refresh_ui()


func _fit_zoom() -> float:
	var dw := _display_width()
	var dh := _display_height()
	if dw <= 0 or dh <= 0:
		return 1.0
	var view := _scroll.size if is_instance_valid(_scroll) and _scroll.size.x > 40 else Vector2(640, 480)
	var zx := (view.x - float(_ruler_size())) / float(dw * BASE_CELL_PX + 16)
	var zy := (view.y - float(_ruler_size())) / float(dh * BASE_CELL_PX + 16)
	return clampf(minf(zx, zy), MIN_ZOOM, MAX_ZOOM)


func _paint_cell_from_local(local: Vector2) -> Vector2i:
	var cell_px := _cell_px()
	var origin := _grid_origin()
	var gx := local.x - origin.x
	var gy := local.y - origin.y
	if gx < 0 or gy < 0:
		return Vector2i(-1, -1)
	var x := int(gx / float(cell_px))
	var y := int(gy / float(cell_px))
	var dw := _display_width()
	var dh := _display_height()
	if x < 0 or y < 0 or x >= dw or y >= dh:
		return Vector2i(-1, -1)
	return Vector2i(x, y)


func _on_canvas_draw() -> void:
	var dw := _display_width()
	var dh := _display_height()
	if dw <= 0 or dh <= 0:
		return
	var cell_px := _cell_px()
	var origin := _grid_origin()
	var grid_sz := _grid_pixel_size(cell_px, dw, dh)
	var ruler_bg := Color(0.28, 0.30, 0.34)
	var ruler_text := Color(0.92, 0.93, 0.95)
	var font := ThemeDB.fallback_font
	var font_size := clampi(mini(cell_px - 2, 11), 8, 11)
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), Color(0.32, 0.34, 0.38), true)
	_canvas.draw_rect(Rect2(0, 0, _canvas.size.x, float(_ruler_size())), ruler_bg, true)
	_canvas.draw_rect(Rect2(0, 0, float(_ruler_size()), _canvas.size.y), ruler_bg, true)
	var step := 1
	if cell_px < 14:
		step = 5
	elif cell_px < 20:
		step = 2
	for x in range(0, dw, step):
		var cx := origin.x + float(x * cell_px) + float(cell_px) * 0.5
		var label := str(x)
		var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		_canvas.draw_string(font, Vector2(cx - ts.x * 0.5, float(_ruler_size()) - 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ruler_text)
	for y in range(0, dh, step):
		var row_label := str(y)
		var rts := font.get_string_size(row_label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var cy := origin.y + float(y * cell_px) + (float(cell_px) + rts.y) * 0.5 - 2.0
		_canvas.draw_string(font, Vector2(float(_ruler_size()) * 0.5 - rts.x * 0.5, cy), row_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ruler_text)
	_canvas.draw_rect(Rect2(origin, grid_sz), Color(0.38, 0.40, 0.45), true)
	var preview := _has_pending_resize()
	for y in dh:
		for x in dw:
			var tid := 0
			if x < _width and y < _height:
				var idx := y * _width + x
				tid = int(_cells[idx]) if idx < _cells.size() else 0
			var r := Rect2(origin.x + float(x * cell_px) + 1.0, origin.y + float(y * cell_px) + 1.0, float(cell_px - 1), float(cell_px - 1))
			var col := Sniff.tile_preview_color(tid)
			if preview and (x >= _width or y >= _height):
				col = Color(col.r, col.g, col.b, 0.45)
			_canvas.draw_rect(r, col, true)
			if cell_px >= 10:
				_canvas.draw_rect(r, Color(0, 0, 0, 0.15), false, 1.0)
			if x == _hover_col and y == _hover_row:
				_canvas.draw_rect(r, Color(1.0, 1.0, 1.0, 0.22), true)
				_canvas.draw_rect(r, Color(1.0, 1.0, 1.0, 0.55), false, 1.0)


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
	elif event is InputEventMouseMotion:
		var cell := _paint_cell_from_local(_canvas.get_local_mouse_position())
		var hc := cell.x
		var hr := cell.y
		if hc != _hover_col or hr != _hover_row:
			_hover_col = hc
			_hover_row = hr
			_update_status_text()
			_canvas.queue_redraw()
		if _paint_drag:
			_paint_at_event(event, false)


func _paint_at_event(event: InputEvent, push_undo: bool) -> void:
	if push_undo and not _stroke_undo_pushed:
		_push_undo()
		_stroke_undo_pushed = true
	var local := _canvas.get_local_mouse_position()
	var cell := _paint_cell_from_local(local)
	var x := cell.x
	var y := cell.y
	if x < 0 or y < 0:
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
