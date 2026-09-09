@tool
extends VBoxContainer
## Inline vector grid for labeled *Vector Data blocks. Live-writes Data rows on edit.

signal section_focused(section: Dictionary)

const Resolver := preload("res://addons/visual_gasic/vg_vector_data_resolver.gd")
const Sync := preload("res://addons/visual_gasic/vg_vector_data_sync.gd")
const CanvasScript := preload("res://addons/visual_gasic/vg_vector_edit_canvas.gd")

var _code_edit: CodeEdit
var _section: Dictionary = {}
var _shapes: Array = []
var _canvas: Control
var _status: Label
var _hint: Label
var _debounce: Timer
var _sync_pending := false
var _data_fingerprint: String = ""


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_status = Label.new()
	_status.text = "Move the caret into a *Vector: Data block."
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

	_canvas = CanvasScript.new()
	_canvas.name = "VectorCanvas"
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.custom_minimum_size = Vector2(0, 160)
	_canvas.visible = false
	if _canvas.has_signal("shapes_edited"):
		_canvas.shapes_edited.connect(_on_shapes_edited)
	add_child(_canvas)

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
	_canvas.visible = false
	_status.text = "Move the caret into a *Vector: Data block."


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


func _load_section(sec: Dictionary, fingerprint: String = "") -> void:
	_section = sec.duplicate(true)
	_data_fingerprint = fingerprint
	_shapes = (sec.get("shapes", []) as Array).duplicate(true)
	var vw: int = int(sec.get("view_w", 64))
	var vh: int = int(sec.get("view_h", 64))
	var step: int = int(sec.get("grid_step", 0))
	if _canvas.has_method("set_model"):
		_canvas.set_model(vw, vh, step, _shapes)
	_canvas.visible = true
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
