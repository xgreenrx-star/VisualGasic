@tool
extends VBoxContainer
## Inline pixel grid for labeled *Sprite Data blocks. Live-writes Data rows on edit.

signal section_focused(section: Dictionary)

const Resolver := preload("res://addons/visual_gasic/vg_sprite_data_resolver.gd")
const Sync := preload("res://addons/visual_gasic/vg_sprite_data_sync.gd")
const Palettes := preload("res://addons/visual_gasic/vg_sprite_data_palettes.gd")

var _code_edit: CodeEdit
var _section: Dictionary = {}
var _pixels: PackedInt32Array = PackedInt32Array()
var _palette_id: int = 0
var _transparent: int = 0
var _brush: int = 1
var _grid: Control
var _status: Label
var _brush_label: Label
var _palette_row: HBoxContainer
var _swatch_frames: Array[PanelContainer] = []
var _debounce: Timer
var _sync_pending := false
var _zoom := 12
var _painting := false
var _data_fingerprint: String = ""


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_status = Label.new()
	_status.text = "Move the caret into a *Sprite: Data block."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 10)
	_status.add_theme_color_override("font_color", Color(0.25, 0.25, 0.35))
	add_child(_status)

	_brush_label = Label.new()
	_brush_label.add_theme_font_size_override("font_size", 10)
	_brush_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.45))
	add_child(_brush_label)

	_palette_row = HBoxContainer.new()
	_palette_row.visible = false
	_palette_row.add_theme_constant_override("separation", 2)
	add_child(_palette_row)

	_grid = Control.new()
	_grid.name = "PixelGrid"
	_grid.mouse_filter = Control.MOUSE_FILTER_STOP
	_grid.gui_input.connect(_on_grid_input)
	_grid.draw.connect(_on_grid_draw)
	_grid.tooltip_text = "Left-click paint · Shift+click erase · Right-click pick color"
	add_child(_grid)

	_debounce = Timer.new()
	_debounce.one_shot = true
	_debounce.wait_time = 0.15
	_debounce.timeout.connect(_flush_sync)
	add_child(_debounce)


func bind_code_edit(code_edit: CodeEdit) -> void:
	_code_edit = code_edit


func clear_section() -> void:
	_section = {}
	_data_fingerprint = ""
	_pixels = PackedInt32Array()
	_swatch_frames.clear()
	_palette_row.visible = false
	for c in _palette_row.get_children():
		c.queue_free()
	_grid.custom_minimum_size = Vector2.ZERO
	_grid.size = Vector2.ZERO
	_grid.visible = false
	_grid.queue_redraw()
	_brush_label.text = ""
	_status.text = "Move the caret into a *Sprite: Data block."


func update_for_caret(source: String, caret_line: int) -> void:
	if _code_edit != null and Sync.is_sync_guarded(_code_edit):
		return
	var sec := Resolver.resolve_at_line(source, caret_line)
	if sec.is_empty():
		if not _section.is_empty():
			clear_section()
		return
	var fp := _data_fingerprint_for(sec, source)
	if _sections_equal(sec, _section) and fp == _data_fingerprint:
		return
	_load_section(sec, fp)
	section_focused.emit(sec)


func _sections_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	return a.get("label", "") == b.get("label", "") \
		and a.get("header_line", -1) == b.get("header_line", -1) \
		and a.get("w", -1) == b.get("w", -1) \
		and a.get("h", -1) == b.get("h", -1) \
		and a.get("data_end_line", -1) == b.get("data_end_line", -1)


func _data_fingerprint_for(sec: Dictionary, source: String) -> String:
	var start: int = sec.get("data_start_line", -1)
	var end_line: int = sec.get("data_end_line", -1)
	if start < 0 or end_line < start:
		return ""
	var lines := source.split("\n")
	var parts: PackedStringArray = PackedStringArray()
	for i in range(start, end_line + 1):
		if i < lines.size():
			parts.append(lines[i])
	return "|".join(parts)


func _load_section(sec: Dictionary, fingerprint: String = "") -> void:
	_section = sec.duplicate(true)
	_data_fingerprint = fingerprint
	_pixels = (sec["pixels"] as PackedInt32Array).duplicate()
	_palette_id = int(sec.get("palette_id", 0))
	_transparent = int(sec.get("transparent", 0))
	if _brush >= Palettes.colors_for_id(_palette_id).size():
		_brush = 1 if _transparent == 0 else mini(1, Palettes.colors_for_id(_palette_id).size() - 1)
	var w: int = sec["w"]
	var h: int = sec["h"]
	_zoom = clampi(int(floor(192.0 / float(maxi(w, h)))), 4, 20)
	var grid_size := Vector2(w * _zoom, h * _zoom)
	_grid.custom_minimum_size = grid_size
	_grid.size = grid_size
	_grid.visible = true
	_grid.queue_redraw()
	_rebuild_palette_row()
	_update_status_line()


func _rebuild_palette_row() -> void:
	for c in _palette_row.get_children():
		c.queue_free()
	_swatch_frames.clear()
	_palette_row.visible = true
	var cols := Palettes.colors_for_id(_palette_id)
	for i in cols.size():
		var frame := PanelContainer.new()
		frame.custom_minimum_size = Vector2(18, 18)
		var frame_sb := StyleBoxFlat.new()
		frame_sb.bg_color = Color.TRANSPARENT
		frame_sb.set_border_width_all(1)
		frame_sb.border_color = Color(0.55, 0.55, 0.58)
		frame_sb.set_corner_radius_all(2)
		frame.add_theme_stylebox_override("panel", frame_sb)

		var swatch := _make_swatch_control(i, cols[i])
		frame.add_child(swatch)

		var idx := i
		frame.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_set_brush(idx)
		)
		_palette_row.add_child(frame)
		_swatch_frames.append(frame)

	_update_brush_highlight()


func _make_swatch_control(index: int, color: Color) -> Control:
	if index == _transparent:
		var c := Control.new()
		c.custom_minimum_size = Vector2(14, 14)
		c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		c.tooltip_text = "Transparent key (index %d) — pixels with this index are see-through" % index
		c.draw.connect(func():
			_draw_checker(c, c.size)
		)
		c.resized.connect(func(): c.queue_redraw())
		return c
	var rect := ColorRect.new()
	rect.custom_minimum_size = Vector2(14, 14)
	rect.color = color
	rect.tooltip_text = "Color index %d" % index
	return rect


func _draw_checker(host: Control, area: Vector2) -> void:
	var step := 4
	for y in range(0, int(area.y), step):
		for x in range(0, int(area.x), step):
			var light := ((x / step) + (y / step)) % 2 == 0
			host.draw_rect(
				Rect2(x, y, step, step),
				Color(0.82, 0.82, 0.85) if light else Color(0.68, 0.68, 0.72)
			)


func _set_brush(index: int) -> void:
	_brush = index
	_update_brush_highlight()
	_update_status_line()


func _update_brush_highlight() -> void:
	for i in _swatch_frames.size():
		var frame := _swatch_frames[i]
		if not is_instance_valid(frame):
			continue
		var base := frame.get_theme_stylebox("panel")
		var sb: StyleBoxFlat = base.duplicate() if base else StyleBoxFlat.new()
		if i == _brush:
			sb.set_border_width_all(2)
			sb.border_color = Color(0.05, 0.05, 0.55)
		else:
			sb.set_border_width_all(1)
			sb.border_color = Color(0.55, 0.55, 0.58)
		frame.add_theme_stylebox_override("panel", sb)


func _update_status_line() -> void:
	if _section.is_empty():
		return
	var w: int = _section["w"]
	var h: int = _section["h"]
	var brush_note := "transparent" if _brush == _transparent else str(_brush)
	_status.text = "%s  %d×%d  palette %s" % [
		_section.get("label", "?"),
		w,
		h,
		Palettes.palette_name_for_id(_palette_id),
	]
	_brush_label.text = "Brush: index %s  (transparent key = %d)" % [brush_note, _transparent]


func _pixel_color_for_draw(index: int) -> Color:
	if index == _transparent:
		return Color(0.75, 0.75, 0.78, 0.45)
	return Palettes.color_for_index(_palette_id, index)


func _on_grid_draw() -> void:
	if _section.is_empty() or _pixels.is_empty():
		return
	var w: int = _section["w"]
	var h: int = _section["h"]
	# Neutral backdrop so transparent pixels read clearly.
	_draw_checker(_grid, Vector2(w * _zoom, h * _zoom))
	for y in h:
		for x in w:
			var idx := _pixels[y * w + x]
			var col := _pixel_color_for_draw(idx)
			var alpha := 1.0 if idx != _transparent else 0.55
			_grid.draw_rect(Rect2(x * _zoom, y * _zoom, _zoom, _zoom), Color(col.r, col.g, col.b, alpha))
			_grid.draw_rect(Rect2(x * _zoom, y * _zoom, _zoom, _zoom), Color(0.2, 0.2, 0.25, 0.35), false)


func _cell_at_mouse() -> Vector2i:
	var local := _grid.get_local_mouse_position()
	return Vector2i(int(local.x / _zoom), int(local.y / _zoom))


func _paint_at_mouse(erase: bool) -> void:
	if _section.is_empty():
		return
	var cell := _cell_at_mouse()
	var x := cell.x
	var y := cell.y
	var w: int = _section["w"]
	var h: int = _section["h"]
	if x < 0 or y < 0 or x >= w or y >= h:
		return
	var pi := y * w + x
	var new_idx := _transparent if erase else _brush
	if _pixels[pi] == new_idx:
		return
	_pixels[pi] = new_idx
	_grid.queue_redraw()
	_queue_sync()


func _pick_at_mouse() -> void:
	if _section.is_empty():
		return
	var cell := _cell_at_mouse()
	var w: int = _section["w"]
	var h: int = _section["h"]
	if cell.x < 0 or cell.y < 0 or cell.x >= w or cell.y >= h:
		return
	var idx := _pixels[cell.y * w + cell.x]
	_set_brush(idx)


func _on_grid_input(event: InputEvent) -> void:
	if _section.is_empty() or _code_edit == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_pick_at_mouse()
			_grid.accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_painting = true
				_paint_at_mouse(mb.shift_pressed)
			else:
				_painting = false
				_flush_sync()
	elif event is InputEventMouseMotion and _painting:
		var ev := event as InputEventMouseMotion
		if ev.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_paint_at_mouse(ev.shift_pressed)


func _queue_sync() -> void:
	_sync_pending = true
	_debounce.start()


func _flush_sync() -> void:
	if not _sync_pending or _code_edit == null or _section.is_empty():
		_sync_pending = false
		return
	_sync_pending = false
	Sync.apply_pixels(_code_edit, _section, _pixels)
