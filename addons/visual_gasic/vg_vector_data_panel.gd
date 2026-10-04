@tool
extends VBoxContainer
## Inline vector grid for labeled *Vector Data blocks. Live-writes Data rows on edit.

signal section_focused(section: Dictionary)
signal edit_in_vector_editor_requested(section: Dictionary)

const Resolver := preload("res://addons/visual_gasic/vg_vector_data_resolver.gd")
const WireResolver := preload("res://addons/visual_gasic/vg_wire_model_resolver.gd")
const Sync := preload("res://addons/visual_gasic/vg_vector_data_sync.gd")
const CanvasScript := preload("res://addons/visual_gasic/vg_vector_edit_canvas.gd")
const WirePreviewScript := preload("res://addons/visual_gasic/vg_wire_model_preview.gd")
const WireSync := preload("res://addons/visual_gasic/vg_wire_model_sync.gd")

var _code_edit: CodeEdit
var _section: Dictionary = {}
var _shapes: Array = []
var _canvas: Control
var _canvas_clip: PanelContainer
var _wire_preview: Control
var _status: Label
var _hint: Label
var _debounce: Timer
var _sync_pending := false
var _data_fingerprint: String = ""
var _btn_row: HBoxContainer
var _new_btn: Button
var _edit_btn: Button
var _new_dialog: AcceptDialog = null


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_btn_row = HBoxContainer.new()
	_btn_row.add_theme_constant_override("separation", 4)
	add_child(_btn_row)

	_new_btn = Button.new()
	_new_btn.text = "New Vector…"
	_new_btn.tooltip_text = "Insert a labeled *Vector Data block and edit it (or open the Vector Editor)"
	_new_btn.pressed.connect(_on_new_vector_pressed)
	_btn_row.add_child(_new_btn)

	_edit_btn = Button.new()
	_edit_btn.text = "Edit in Vector Editor…"
	_edit_btn.tooltip_text = "Open the full Vector Editor on this Data block (Save writes back to Data)"
	_edit_btn.visible = false
	_edit_btn.pressed.connect(_on_edit_in_editor_pressed)
	_btn_row.add_child(_edit_btn)

	_status = Label.new()
	_status.text = "Move the caret into a *Vector: block or a 3D wire model, or click New Vector…"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 10)
	_status.add_theme_color_override("font_color", Color(0.25, 0.25, 0.35))
	add_child(_status)

	_hint = Label.new()
	_hint.text = "Drag points · Shift+click append · Right-click remove · Wheel zoom · Middle-drag pan"
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 9)
	_hint.add_theme_color_override("font_color", Color(0.35, 0.35, 0.5))
	add_child(_hint)

	_canvas_clip = PanelContainer.new()
	_canvas_clip.name = "VectorCanvasClip"
	_canvas_clip.clip_contents = true
	_canvas_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas_clip.custom_minimum_size = Vector2(0, 160)
	add_child(_canvas_clip)

	_canvas = CanvasScript.new()
	_canvas.name = "VectorCanvas"
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.custom_minimum_size = Vector2(0, 160)
	_canvas.visible = false
	if _canvas.has_signal("shapes_edited"):
		_canvas.shapes_edited.connect(_on_shapes_edited)
	_canvas_clip.add_child(_canvas)

	_wire_preview = WirePreviewScript.new()
	_wire_preview.name = "WireModelPreview"
	_wire_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wire_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_wire_preview.visible = false
	if _wire_preview.has_signal("vertex_moved"):
		_wire_preview.vertex_moved.connect(_on_wire_vertex_moved)
	_canvas_clip.add_child(_wire_preview)

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
	_shapes = []
	if _canvas.has_method("clear_model"):
		_canvas.clear_model()
	if _wire_preview and _wire_preview.has_method("clear_model"):
		_wire_preview.clear_model()
	_canvas.visible = false
	if _wire_preview:
		_wire_preview.visible = false
	_canvas_clip.visible = false
	if is_instance_valid(_edit_btn):
		_edit_btn.visible = false
	_hint.text = "Drag points · Shift+click append · Right-click remove · Wheel zoom · Middle-drag pan"
	_status.text = "Move the caret into a *Vector: block or a 3D wire model, or click New Vector…"


func update_for_caret(source: String, caret_line: int) -> void:
	if _code_edit != null and (Sync.is_sync_guarded(_code_edit) or WireSync.is_sync_guarded(_code_edit)):
		return
	var sec := Resolver.resolve_at_line(source, caret_line)
	if sec.is_empty():
		var wire := WireResolver.resolve_at_line(source, caret_line)
		if wire.is_empty():
			if not _section.is_empty():
				clear_section()
			return
		var wfp := _data_fingerprint_for(wire, source)
		if _sections_equal(wire, _section) and wfp == _data_fingerprint:
			return
		_load_wire(wire, wfp)
		section_focused.emit(wire)
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
		and a.get("view_w", -1) == b.get("view_w", -1) \
		and a.get("view_h", -1) == b.get("view_h", -1) \
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


func _load_wire(sec: Dictionary, fingerprint: String) -> void:
	_section = sec.duplicate(true)
	_data_fingerprint = fingerprint
	_shapes = []
	_canvas.visible = false
	if _canvas.has_method("clear_model"):
		_canvas.clear_model()
	_wire_preview.visible = true
	_canvas_clip.visible = true
	if is_instance_valid(_edit_btn):
		_edit_btn.visible = false
	if _wire_preview.has_method("set_model"):
		_wire_preview.set_model(
			str(sec.get("label", "")),
			sec.get("verts", PackedVector3Array()),
			sec.get("edges", PackedInt32Array())
		)
	_hint.text = "Drag a point to move that vertex. Its Data line is rewritten."
	_status.text = "%s  %d verts  %d edges" % [
		sec.get("label", "?"),
		int(sec.get("vert_count", 0)),
		int(sec.get("edge_count", 0)),
	]


func _on_wire_vertex_moved(index: int, point: Vector3) -> void:
	if _code_edit == null or str(_section.get("kind", "")) != "wire":
		return
	WireSync.apply_vertex(_code_edit, _section, index, point)


func _load_section(sec: Dictionary, fingerprint: String = "") -> void:
	_section = sec.duplicate(true)
	_data_fingerprint = fingerprint
	_shapes = (sec.get("shapes", []) as Array).duplicate(true)
	if _wire_preview:
		_wire_preview.visible = false
		if _wire_preview.has_method("clear_model"):
			_wire_preview.clear_model()
	_hint.text = "Drag points · Shift+click append · Right-click remove · Wheel zoom · Middle-drag pan"
	var vw: int = int(sec.get("view_w", 64))
	var vh: int = int(sec.get("view_h", 64))
	var step: int = int(sec.get("grid_step", 0))
	if _canvas.has_method("set_model"):
		_canvas.set_model(vw, vh, step, _shapes)
	_canvas.visible = true
	_canvas_clip.visible = true
	if is_instance_valid(_edit_btn):
		_edit_btn.visible = true
	_update_status_line()


func _update_status_line() -> void:
	if _section.is_empty():
		return
	_status.text = "%s  %d×%d  grid=%d  shapes=%d" % [
		_section.get("label", "?"),
		int(_section.get("view_w", 0)),
		int(_section.get("view_h", 0)),
		int(_section.get("grid_step", 0)),
		_shapes.size(),
	]


func _on_shapes_edited(new_shapes: Array) -> void:
	_shapes = new_shapes
	_update_status_line()
	_queue_sync()


func _queue_sync() -> void:
	_sync_pending = true
	_debounce.start()


func _flush_sync() -> void:
	if not _sync_pending or _code_edit == null or _section.is_empty():
		_sync_pending = false
		return
	_sync_pending = false
	if not Sync.apply_shapes(_code_edit, _section, _shapes):
		return
	var sec2 := Resolver.resolve_at_line(_code_edit.text, _code_edit.get_caret_line())
	if not sec2.is_empty():
		_section = sec2.duplicate(true)
		_data_fingerprint = _data_fingerprint_for(sec2, _code_edit.text)
		_shapes = (sec2.get("shapes", []) as Array).duplicate(true)


func _on_edit_in_editor_pressed() -> void:
	if _section.is_empty() or str(_section.get("kind", "")) == "wire":
		return
	_flush_sync()
	edit_in_vector_editor_requested.emit(_section.duplicate(true))


func _on_new_vector_pressed() -> void:
	if _code_edit == null or not is_instance_valid(_code_edit):
		_status.text = "Open a .vg file first, then create a vector."
		return
	_show_new_vector_dialog()


func _show_new_vector_dialog() -> void:
	if is_instance_valid(_new_dialog):
		_new_dialog.queue_free()

	_new_dialog = AcceptDialog.new()
	_new_dialog.title = "New Vector Data"
	_new_dialog.ok_button_text = "Create"
	_new_dialog.size = Vector2i(360, 300)
	_new_dialog.dialog_hide_on_ok = false

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_new_dialog.add_child(vbox)

	var hint := Label.new()
	hint.text = "Inserts a labeled Data block (max %d×%d) into the open .vg file." % [
		Resolver.MAX_VIEW, Resolver.MAX_VIEW
	]
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.25, 0.25, 0.35))
	vbox.add_child(hint)

	var label_row := HBoxContainer.new()
	label_row.add_theme_constant_override("separation", 6)
	vbox.add_child(label_row)
	var label_lbl := Label.new()
	label_lbl.text = "Label:"
	label_lbl.custom_minimum_size.x = 72
	label_row.add_child(label_lbl)
	var label_edit := LineEdit.new()
	label_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_edit.text = Sync.suggest_label(_code_edit.text)
	label_edit.placeholder_text = "ShipOutlineVector"
	label_row.add_child(label_edit)

	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 6)
	vbox.add_child(size_row)
	var w_lbl := Label.new()
	w_lbl.text = "Width:"
	w_lbl.custom_minimum_size.x = 72
	size_row.add_child(w_lbl)
	var w_spin := SpinBox.new()
	w_spin.min_value = 1
	w_spin.max_value = Resolver.MAX_VIEW
	w_spin.value = 64
	w_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_row.add_child(w_spin)
	var h_lbl := Label.new()
	h_lbl.text = "Height:"
	size_row.add_child(h_lbl)
	var h_spin := SpinBox.new()
	h_spin.min_value = 1
	h_spin.max_value = Resolver.MAX_VIEW
	h_spin.value = 64
	h_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_row.add_child(h_spin)

	var grid_row := HBoxContainer.new()
	grid_row.add_theme_constant_override("separation", 6)
	vbox.add_child(grid_row)
	var grid_lbl := Label.new()
	grid_lbl.text = "Grid:"
	grid_lbl.custom_minimum_size.x = 72
	grid_row.add_child(grid_lbl)
	var grid_spin := SpinBox.new()
	grid_spin.min_value = 0
	grid_spin.max_value = 64
	grid_spin.value = 4
	grid_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_row.add_child(grid_spin)

	var open_check := CheckBox.new()
	open_check.text = "Open in Vector Editor after create"
	open_check.button_pressed = true
	vbox.add_child(open_check)

	var err_lbl := Label.new()
	err_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	err_lbl.add_theme_color_override("font_color", Color(0.75, 0.15, 0.15))
	err_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(err_lbl)

	_new_dialog.confirmed.connect(func():
		err_lbl.text = ""
		var result := Sync.insert_new_block(
			_code_edit,
			_code_edit.get_caret_line(),
			label_edit.text,
			int(w_spin.value),
			int(h_spin.value),
			int(grid_spin.value)
		)
		if not bool(result.get("ok", false)):
			err_lbl.text = str(result.get("error", "Create failed"))
			return
		var sec: Dictionary = result.get("section", {})
		if not sec.is_empty():
			_load_section(sec, _data_fingerprint_for(sec, _code_edit.text))
			section_focused.emit(sec)
			if open_check.button_pressed:
				edit_in_vector_editor_requested.emit(sec.duplicate(true))
		_new_dialog.hide()
		_new_dialog.queue_free()
	)
	_new_dialog.canceled.connect(func(): _new_dialog.queue_free())

	var host: Node = get_tree().root if get_tree() else self
	host.add_child(_new_dialog)
	_new_dialog.popup_centered()
	label_edit.grab_focus()
