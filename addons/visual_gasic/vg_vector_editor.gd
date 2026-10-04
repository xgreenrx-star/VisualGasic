@tool
## VG Vector Editor — full-panel editor for inline *Vector Data and .vgv files.
## Parity with the Sprite Editor: toolbar New/Open/Save, tool palette, Data mode
## write-back into CodeEdit, and return-to-code when editing from a .vg buffer.
extends HSplitContainer

signal back_to_form_requested
signal vector_saved(path: String)
signal vector_data_saved(section: Dictionary)

const _ASSET_PLUGIN_ID := "vector_editor"
const _AssetBus := preload("res://addons/visual_gasic/vg_asset_bus.gd")
const _ContextBroker := preload("res://addons/visual_gasic/vg_context_broker.gd")
const _DataSync := preload("res://addons/visual_gasic/vg_vector_data_sync.gd")
const _DataResolver := preload("res://addons/visual_gasic/vg_vector_data_resolver.gd")
const _VgvResolver := preload("res://addons/visual_gasic/vg_vgv_resolver.gd")
const _CanvasScript := preload("res://addons/visual_gasic/vg_vector_edit_canvas.gd")

const PRESET_SIZES := {
	"64×64": Vector2i(64, 64),
	"128×128": Vector2i(128, 128),
	"160×120": Vector2i(160, 120),
	"320×240": Vector2i(320, 240),
	"640×480": Vector2i(640, 480),
	"960×540": Vector2i(960, 540),
}

var _file_path := ""
var _dirty := false
var _view_w := 64
var _view_h := 64
var _grid_step := 4
var _shapes: Array = []

var _data_code_edit: CodeEdit = null
var _data_section: Dictionary = {}
var _bridge_code_edit: CodeEdit = null

var _canvas: Control = null
var _save_btn: Button = null
var _status_label: Label = null
var _shape_list: ItemList = null
var _tool_buttons: Dictionary = {}
var _stroke_w_spin: SpinBox = null
var _grid_spin: SpinBox = null
var _view_w_spin: SpinBox = null
var _view_h_spin: SpinBox = null
var _color_rect: ColorRect = null
var _color_picker: ColorPicker = null
var _color_popup: PopupPanel = null
var _stroke_color := Color(1, 1, 1, 1)

var _open_dialog: FileDialog = null
var _export_dialog: FileDialog = null
var _new_dialog: AcceptDialog = null


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_offset = 240
	_build_ui()
	_new_document(64, 64, 4)


func _build_ui() -> void:
	# ── Left panel ──
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(220, 0)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	add_child(left)

	var back_btn := Button.new()
	back_btn.text = "← Back"
	back_btn.tooltip_text = "Return to previous view"
	back_btn.pressed.connect(func() -> void: back_to_form_requested.emit())
	left.add_child(back_btn)

	var title := Label.new()
	title.text = "Vector Editor"
	title.add_theme_font_size_override("font_size", 16)
	left.add_child(title)

	# Toolbar row
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 4)
	left.add_child(toolbar)

	var new_btn := Button.new()
	new_btn.text = "New"
	new_btn.pressed.connect(_show_new_dialog)
	toolbar.add_child(new_btn)

	var open_btn := Button.new()
	open_btn.text = "Open"
	open_btn.tooltip_text = "Open .vgv file"
	open_btn.pressed.connect(_show_open_dialog)
	toolbar.add_child(open_btn)

	_save_btn = Button.new()
	_save_btn.text = "Save"
	_save_btn.pressed.connect(_save)
	toolbar.add_child(_save_btn)

	var export_btn := Button.new()
	export_btn.text = "Export"
	export_btn.tooltip_text = "Export .vgv"
	export_btn.pressed.connect(_show_export_dialog)
	toolbar.add_child(export_btn)

	var data_btn := Button.new()
	data_btn.text = "⇄ Data"
	data_btn.tooltip_text = "Save canvas as *Vector Data block in the open .vg file"
	data_btn.pressed.connect(_on_data_bridge_pressed)
	toolbar.add_child(data_btn)

	left.add_child(HSeparator.new())

	var tools_lbl := Label.new()
	tools_lbl.text = "Tools"
	left.add_child(tools_lbl)

	var tools_grid := GridContainer.new()
	tools_grid.columns = 2
	tools_grid.add_theme_constant_override("h_separation", 4)
	tools_grid.add_theme_constant_override("v_separation", 4)
	left.add_child(tools_grid)

	_add_tool_btn(tools_grid, "Select", _CanvasScript.Tool.SELECT)
	_add_tool_btn(tools_grid, "Line", _CanvasScript.Tool.LINE)
	_add_tool_btn(tools_grid, "Rect", _CanvasScript.Tool.RECT)
	_add_tool_btn(tools_grid, "Polyline", _CanvasScript.Tool.POLYLINE)
	_add_tool_btn(tools_grid, "Delete", _CanvasScript.Tool.DELETE)

	left.add_child(HSeparator.new())

	var stroke_lbl := Label.new()
	stroke_lbl.text = "Stroke"
	left.add_child(stroke_lbl)

	var color_row := HBoxContainer.new()
	left.add_child(color_row)
	_color_rect = ColorRect.new()
	_color_rect.custom_minimum_size = Vector2(36, 24)
	_color_rect.color = _stroke_color
	_color_rect.gui_input.connect(_on_color_rect_input)
	color_row.add_child(_color_rect)
	var color_btn := Button.new()
	color_btn.text = "Color…"
	color_btn.pressed.connect(_popup_color_picker)
	color_row.add_child(color_btn)

	var w_row := HBoxContainer.new()
	left.add_child(w_row)
	var w_lbl := Label.new()
	w_lbl.text = "Width"
	w_row.add_child(w_lbl)
	_stroke_w_spin = SpinBox.new()
	_stroke_w_spin.min_value = 0
	_stroke_w_spin.max_value = 32
	_stroke_w_spin.step = 0.5
	_stroke_w_spin.value = 2
	_stroke_w_spin.value_changed.connect(_on_stroke_w_changed)
	w_row.add_child(_stroke_w_spin)

	left.add_child(HSeparator.new())

	var doc_lbl := Label.new()
	doc_lbl.text = "Document"
	left.add_child(doc_lbl)

	var vw_row := HBoxContainer.new()
	left.add_child(vw_row)
	vw_row.add_child(_make_spin_label("W"))
	_view_w_spin = SpinBox.new()
	_view_w_spin.min_value = 8
	_view_w_spin.max_value = _DataResolver.MAX_VIEW
	_view_w_spin.value = 64
	_view_w_spin.value_changed.connect(_on_view_size_changed)
	vw_row.add_child(_view_w_spin)

	var vh_row := HBoxContainer.new()
	left.add_child(vh_row)
	vh_row.add_child(_make_spin_label("H"))
	_view_h_spin = SpinBox.new()
	_view_h_spin.min_value = 8
	_view_h_spin.max_value = _DataResolver.MAX_VIEW
	_view_h_spin.value = 64
	_view_h_spin.value_changed.connect(_on_view_size_changed)
	vh_row.add_child(_view_h_spin)

	var g_row := HBoxContainer.new()
	left.add_child(g_row)
	g_row.add_child(_make_spin_label("Grid"))
	_grid_spin = SpinBox.new()
	_grid_spin.min_value = 0
	_grid_spin.max_value = 64
	_grid_spin.value = 4
	_grid_spin.value_changed.connect(_on_grid_changed)
	g_row.add_child(_grid_spin)

	left.add_child(HSeparator.new())

	var shapes_lbl := Label.new()
	shapes_lbl.text = "Shapes"
	left.add_child(shapes_lbl)

	_shape_list = ItemList.new()
	_shape_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shape_list.custom_minimum_size = Vector2(0, 120)
	_shape_list.item_selected.connect(_on_shape_list_selected)
	left.add_child(_shape_list)

	var del_shape := Button.new()
	del_shape.text = "Delete selected shape"
	del_shape.pressed.connect(_delete_selected_shape)
	left.add_child(del_shape)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 10)
	left.add_child(_status_label)

	# ── Right canvas ──
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(right)

	var hint := Label.new()
	hint.text = "Line/Rect: drag · Polyline: click points, right-click finish · Select: drag handles · Wheel zoom · Middle-drag pan"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	right.add_child(hint)

	var clip := PanelContainer.new()
	clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip.clip_contents = true
	right.add_child(clip)

	_canvas = _CanvasScript.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.shapes_edited.connect(_on_shapes_edited)
	if _canvas.has_signal("selection_changed"):
		_canvas.selection_changed.connect(_on_canvas_selection_changed)
	clip.add_child(_canvas)

	_color_popup = PopupPanel.new()
	_color_picker = ColorPicker.new()
	_color_picker.color_changed.connect(_on_picker_color)
	_color_popup.add_child(_color_picker)
	add_child(_color_popup)

	_set_tool(_CanvasScript.Tool.SELECT)


func _make_spin_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size.x = 36
	return lbl


func _add_tool_btn(host: GridContainer, label: String, tool_id: int) -> void:
	var btn := Button.new()
	btn.text = label
	btn.toggle_mode = true
	btn.pressed.connect(func() -> void: _set_tool(tool_id))
	host.add_child(btn)
	_tool_buttons[tool_id] = btn


func _set_tool(tool_id: int) -> void:
	if _canvas and _canvas.has_method("set_tool"):
		_canvas.set_tool(tool_id)
	for tid in _tool_buttons:
		var b: Button = _tool_buttons[tid]
		b.button_pressed = (int(tid) == tool_id)


func _apply_stroke_to_canvas() -> void:
	if _canvas and _canvas.has_method("set_stroke"):
		_canvas.set_stroke(
			int(_stroke_color.r * 255.0),
			int(_stroke_color.g * 255.0),
			int(_stroke_color.b * 255.0),
			int(_stroke_color.a * 255.0),
			float(_stroke_w_spin.value) if _stroke_w_spin else 2.0
		)


func _on_stroke_w_changed(_v: float) -> void:
	_apply_stroke_to_canvas()


func _on_color_rect_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_popup_color_picker()


func _popup_color_picker() -> void:
	_color_picker.color = _stroke_color
	_color_popup.popup_centered(Vector2i(320, 400))


func _on_picker_color(c: Color) -> void:
	_stroke_color = c
	_color_rect.color = c
	_apply_stroke_to_canvas()


func _on_view_size_changed(_v: float) -> void:
	_view_w = int(_view_w_spin.value)
	_view_h = int(_view_h_spin.value)
	_refresh_canvas_model()
	_dirty = true
	_update_status()


func _on_grid_changed(_v: float) -> void:
	_grid_step = int(_grid_spin.value)
	_refresh_canvas_model()
	_dirty = true
	_update_status()


func _refresh_canvas_model() -> void:
	if _canvas and _canvas.has_method("set_model"):
		_canvas.set_model(_view_w, _view_h, _grid_step, _shapes)
	_apply_stroke_to_canvas()
	_rebuild_shape_list()


func _on_shapes_edited(new_shapes: Array) -> void:
	_shapes = new_shapes
	_dirty = true
	_rebuild_shape_list()
	_update_status()


func _on_canvas_selection_changed(shape_index: int) -> void:
	if shape_index >= 0 and shape_index < _shape_list.item_count:
		_shape_list.select(shape_index)


func _rebuild_shape_list() -> void:
	if _shape_list == null:
		return
	var sel := _shape_list.get_selected_items()
	_shape_list.clear()
	for i in _shapes.size():
		var s: Dictionary = _shapes[i]
		var typ := str(s.get("type", "?"))
		var pts: PackedVector2Array = s.get("points", PackedVector2Array())
		_shape_list.add_item("%d. %s (%d pts)" % [i + 1, typ, pts.size()])
	if sel.size() > 0 and int(sel[0]) < _shape_list.item_count:
		_shape_list.select(int(sel[0]))


func _on_shape_list_selected(index: int) -> void:
	# Selection is visual; canvas still owns handle selection.
	pass


func _delete_selected_shape() -> void:
	var sel := _shape_list.get_selected_items()
	if sel.is_empty():
		return
	var idx := int(sel[0])
	if idx < 0 or idx >= _shapes.size():
		return
	_shapes.remove_at(idx)
	_refresh_canvas_model()
	_dirty = true
	_update_status()


func _update_status() -> void:
	var mode := "Data: %s" % str(_data_section.get("label", "?")) if is_data_mode() \
		else (_file_path.get_file() if not _file_path.is_empty() else "Untitled")
	var dirty_mark := " *" if _dirty else ""
	_status_label.text = "%s%s  %d×%d  grid=%d  shapes=%d" % [
		mode, dirty_mark, _view_w, _view_h, _grid_step, _shapes.size()
	]
	if is_instance_valid(_save_btn):
		if is_data_mode():
			_save_btn.text = "Save Data"
			_save_btn.tooltip_text = "Write shapes back to *Vector Data (Ctrl+S)"
		else:
			_save_btn.text = "Save"
			_save_btn.tooltip_text = "Save .vgv (Ctrl+S)"


func is_data_mode() -> bool:
	return _data_code_edit != null and is_instance_valid(_data_code_edit) and not _data_section.is_empty()


func clear_vector_data_binding() -> void:
	_data_code_edit = null
	_data_section = {}
	_update_status()


func bind_code_edit_for_data_bridge(code_edit: CodeEdit) -> void:
	_bridge_code_edit = code_edit


func open_vector_data(code_edit: CodeEdit, section: Dictionary) -> bool:
	if code_edit == null or section.is_empty():
		return false
	var live := _DataResolver.resolve_at_line(
		code_edit.text, int(section.get("label_line", code_edit.get_caret_line()))
	)
	if live.is_empty():
		push_warning("[VG Vector Editor] Invalid vector Data section")
		return false
	_data_code_edit = code_edit
	_data_section = live.duplicate(true)
	_file_path = ""
	_view_w = int(live.get("view_w", 64))
	_view_h = int(live.get("view_h", 64))
	_grid_step = int(live.get("grid_step", 4))
	_shapes = (live.get("shapes", []) as Array).duplicate(true)
	_view_w_spin.value = _view_w
	_view_h_spin.value = _view_h
	_grid_spin.value = _grid_step
	_dirty = false
	_refresh_canvas_model()
	_update_status()
	return true


func open_file(path: String) -> void:
	var model := _VgvResolver.load_file(path)
	if model.is_empty():
		# Also accept res:// paths
		var abs := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
		model = _VgvResolver.load_file(abs)
		if not model.is_empty():
			path = abs
	if model.is_empty():
		push_warning("[VG Vector Editor] Could not load: " + path)
		return
	clear_vector_data_binding()
	_file_path = path
	_view_w = int(model.get("view_w", 320))
	_view_h = int(model.get("view_h", 240))
	_grid_step = int(model.get("grid_step", 8))
	_shapes = (model.get("shapes", []) as Array).duplicate(true)
	_view_w_spin.value = _view_w
	_view_h_spin.value = _view_h
	_grid_spin.value = _grid_step
	_dirty = false
	_refresh_canvas_model()
	_update_status()
	_AssetBus.get_instance().emit_opened(path, _ASSET_PLUGIN_ID)
	_ContextBroker.get_instance().set_current_asset(path, _ASSET_PLUGIN_ID)


func open_asset(path: String) -> bool:
	open_file(path)
	return _file_path == path or ProjectSettings.globalize_path(path) == _file_path


func _new_document(w: int, h: int, grid: int) -> void:
	clear_vector_data_binding()
	_file_path = ""
	_view_w = w
	_view_h = h
	_grid_step = grid
	_shapes = [_DataSync.default_shape(w, h)]
	if _view_w_spin:
		_view_w_spin.value = w
		_view_h_spin.value = h
		_grid_spin.value = grid
	_dirty = false
	_refresh_canvas_model()
	_update_status()


func _show_new_dialog() -> void:
	if is_instance_valid(_new_dialog):
		_new_dialog.queue_free()
	_new_dialog = AcceptDialog.new()
	_new_dialog.title = "New Vector"
	_new_dialog.size = Vector2i(320, 260)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_new_dialog.add_child(vb)
	var preset := OptionButton.new()
	var keys := PRESET_SIZES.keys()
	keys.sort()
	for k in keys:
		preset.add_item(str(k))
	vb.add_child(preset)
	var w_spin := SpinBox.new()
	w_spin.min_value = 8
	w_spin.max_value = _DataResolver.MAX_VIEW
	w_spin.value = 64
	vb.add_child(w_spin)
	var h_spin := SpinBox.new()
	h_spin.min_value = 8
	h_spin.max_value = _DataResolver.MAX_VIEW
	h_spin.value = 64
	vb.add_child(h_spin)
	preset.item_selected.connect(func(idx: int) -> void:
		var sz: Vector2i = PRESET_SIZES[preset.get_item_text(idx)]
		w_spin.value = sz.x
		h_spin.value = sz.y
	)
	var as_data := CheckBox.new()
	as_data.text = "Create as *Vector Data in open .vg"
	as_data.button_pressed = _bridge_code_edit != null or is_data_mode()
	vb.add_child(as_data)
	var label_edit := LineEdit.new()
	label_edit.placeholder_text = "ArtVector"
	var code_edit := _data_code_edit if is_data_mode() else _bridge_code_edit
	if code_edit:
		label_edit.text = _DataSync.suggest_label(code_edit.text)
	vb.add_child(label_edit)
	_new_dialog.confirmed.connect(func() -> void:
		if as_data.button_pressed:
			var ce := _data_code_edit if is_instance_valid(_data_code_edit) else _bridge_code_edit
			if ce == null:
				push_warning("[VG Vector Editor] Open a .vg file first for Data mode")
			else:
				var inserted := _DataSync.insert_new_block(
					ce, ce.get_caret_line(), label_edit.text,
					int(w_spin.value), int(h_spin.value), 4
				)
				if bool(inserted.get("ok", false)):
					open_vector_data(ce, inserted.get("section", {}))
				else:
					push_warning("[VG Vector Editor] " + str(inserted.get("error", "insert failed")))
		else:
			_new_document(int(w_spin.value), int(h_spin.value), 4)
		_new_dialog.queue_free()
	)
	_new_dialog.canceled.connect(func() -> void: _new_dialog.queue_free())
	add_child(_new_dialog)
	_new_dialog.popup_centered()


func _show_open_dialog() -> void:
	if is_instance_valid(_open_dialog):
		_open_dialog.queue_free()
	_open_dialog = FileDialog.new()
	_open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_open_dialog.access = FileDialog.ACCESS_RESOURCES
	_open_dialog.filters = PackedStringArray(["*.vgv;VG Vector"])
	_open_dialog.title = "Open Vector File"
	_open_dialog.file_selected.connect(func(path: String) -> void:
		open_file(path)
		_open_dialog.queue_free()
	)
	_open_dialog.canceled.connect(func() -> void: _open_dialog.queue_free())
	add_child(_open_dialog)
	_open_dialog.popup_centered(Vector2i(640, 420))


func _show_export_dialog() -> void:
	if is_instance_valid(_export_dialog):
		_export_dialog.queue_free()
	_export_dialog = FileDialog.new()
	_export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_export_dialog.access = FileDialog.ACCESS_RESOURCES
	_export_dialog.filters = PackedStringArray(["*.vgv;VG Vector"])
	_export_dialog.title = "Export Vector"
	_export_dialog.current_file = "art.vgv" if _file_path.is_empty() else _file_path.get_file()
	_export_dialog.file_selected.connect(func(path: String) -> void:
		_save_vgv(path)
		_export_dialog.queue_free()
	)
	_export_dialog.canceled.connect(func() -> void: _export_dialog.queue_free())
	add_child(_export_dialog)
	_export_dialog.popup_centered(Vector2i(640, 420))


func _save() -> void:
	if is_data_mode():
		_save_vector_data()
		return
	if _file_path.is_empty():
		_show_export_dialog()
		return
	_save_vgv(_file_path)


func _save_vgv(path: String) -> void:
	var model := {
		"view_w": _view_w,
		"view_h": _view_h,
		"grid_step": _grid_step,
		"shapes": _shapes,
	}
	var abs_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	if not _VgvResolver.save_file(abs_path, model):
		push_warning("[VG Vector Editor] Failed to save " + path)
		return
	_file_path = path
	_dirty = false
	vector_saved.emit(path)
	_AssetBus.get_instance().emit_saved(path, _ASSET_PLUGIN_ID)
	_update_status()
	print("[VG Vector Editor] Saved: ", path)


func _save_vector_data() -> void:
	if not is_data_mode():
		return
	var label_name := str(_data_section.get("label", ""))
	var caret_hint := int(_data_section.get("label_line", _data_code_edit.get_caret_line()))
	var live := _DataResolver.resolve_at_line(_data_code_edit.text, caret_hint)
	if live.is_empty() and not label_name.is_empty():
		for b in _DataResolver.enumerate_blocks(_data_code_edit.text):
			if str(b.get("label", "")) == label_name:
				live = _DataResolver.resolve_at_line(_data_code_edit.text, int(b.get("label_line", 0)))
				break
	if not live.is_empty():
		_data_section = live
	# Pull latest shapes from canvas
	if _canvas and _canvas.has_method("get_shapes"):
		_shapes = _canvas.get_shapes()
	if not _DataSync.apply_section(
		_data_code_edit, _data_section, _view_w, _view_h, _grid_step, _shapes
	):
		push_warning("[VG Vector Editor] Failed to write vector Data for " + label_name)
		return
	var refreshed := _DataResolver.resolve_at_line(
		_data_code_edit.text, int(_data_section.get("label_line", 0))
	)
	if not refreshed.is_empty():
		_data_section = refreshed
	_dirty = false
	vector_data_saved.emit(_data_section.duplicate(true))
	_update_status()
	print("[VG Vector Editor] Saved Data block: ", label_name)


func _on_data_bridge_pressed() -> void:
	if is_data_mode():
		_save_vector_data()
		return
	var code_edit := _bridge_code_edit
	if code_edit == null or not is_instance_valid(code_edit):
		push_warning("[VG Vector Editor] Open a .vg file first, then use ⇄ Data")
		return
	var dlg := AcceptDialog.new()
	dlg.title = "Save as Vector Data"
	var vb := VBoxContainer.new()
	dlg.add_child(vb)
	var label_edit := LineEdit.new()
	label_edit.text = _DataSync.suggest_label(code_edit.text)
	vb.add_child(label_edit)
	dlg.confirmed.connect(func() -> void:
		var inserted := _DataSync.insert_new_block(
			code_edit, code_edit.get_caret_line(), label_edit.text,
			_view_w, _view_h, _grid_step
		)
		if not bool(inserted.get("ok", false)):
			push_warning("[VG Vector Editor] " + str(inserted.get("error", "insert failed")))
			dlg.queue_free()
			return
		var sec: Dictionary = inserted.get("section", {})
		_DataSync.apply_section(code_edit, sec, _view_w, _view_h, _grid_step, _shapes)
		var refreshed := _DataResolver.resolve_at_line(code_edit.text, int(sec.get("label_line", 0)))
		open_vector_data(code_edit, refreshed if not refreshed.is_empty() else sec)
		vector_data_saved.emit(_data_section.duplicate(true))
		dlg.queue_free()
	)
	dlg.canceled.connect(func() -> void: dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.ctrl_pressed and event.keycode == KEY_S:
		_save()
		get_viewport().set_input_as_handled()
