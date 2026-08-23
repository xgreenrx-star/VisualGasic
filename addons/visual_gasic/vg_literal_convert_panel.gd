@tool
extends VBoxContainer
## Context Rail panel — alternate literal forms (copyable / replaceable).

signal replace_requested(lit: Dictionary, new_text: String)

const Resolver := preload("res://addons/visual_gasic/vg_literal_resolver.gd")

var _info: Label
var _swatch: ColorRect
var _rows_box: VBoxContainer
var _hint: Label
var _last_key: String = ""
var _current_lit: Dictionary = {}


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 10)
	_info.add_theme_color_override("font_color", Color(0.25, 0.25, 0.35))
	_info.text = "Place the caret on a literal, color, or numeric expression."
	add_child(_info)

	_swatch = ColorRect.new()
	_swatch.custom_minimum_size = Vector2(0, 18)
	_swatch.visible = false
	add_child(_swatch)

	_rows_box = VBoxContainer.new()
	_rows_box.name = "ConvertRows"
	_rows_box.add_theme_constant_override("separation", 2)
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_rows_box)

	_hint = Label.new()
	_hint.text = "Copy or Replace inserts another form. For special characters in strings, use vbCrLf, vbTab, etc."
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 9)
	_hint.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
	add_child(_hint)


func clear_section() -> void:
	_last_key = ""
	_current_lit = {}
	_info.text = "Place the caret on a literal, color, or numeric expression."
	_swatch.visible = false
	_clear_rows()
	_hint.visible = true


func update_for_caret(source: String, line_index: int, column: int) -> void:
	var lit := Resolver.resolve_at_caret(source, line_index, column)
	if lit.is_empty():
		if not _last_key.is_empty():
			clear_section()
		return
	var key := "%d:%d:%d:%s:%s" % [
		line_index,
		int(lit.get("start", 0)),
		int(lit.get("end", 0)),
		str(lit.get("source_text", "")),
		str(lit.get("kind", "")),
	]
	if key == _last_key:
		return
	_last_key = key
	_current_lit = lit.duplicate(true)
	_render(lit)


func _render(lit: Dictionary) -> void:
	_clear_rows()
	var kind: String = lit.get("kind", "")
	var src: String = lit.get("source_text", "")
	_info.text = "%s: %s" % [kind.capitalize(), src]
	var rows: Array = Resolver.format_conversions(lit)
	_swatch.visible = false
	for row in rows:
		if row.get("radix_id") == "color_preview" and row.has("color"):
			_swatch.color = row.get("color")
			_swatch.visible = true
	if rows.is_empty():
		_hint.visible = true
		return
	_hint.visible = false
	for row in rows:
		_rows_box.add_child(_make_row(row, lit))


func _make_row(row: Dictionary, lit: Dictionary) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label := Label.new()
	label.text = str(row.get("label", "")) + ":"
	label.custom_minimum_size.x = 78
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.5))
	if row.has("hint"):
		label.tooltip_text = str(row.get("hint"))
	h.add_child(label)

	var value := LineEdit.new()
	value.text = str(row.get("text", ""))
	value.editable = false
	value.selecting_enabled = true
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.add_theme_font_size_override("font_size", 10)
	if row.get("is_current", false):
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.88, 0.90, 0.96)
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		value.add_theme_stylebox_override("normal", sb)
	h.add_child(value)

	var text_to_copy := str(row.get("text", ""))
	if row.get("radix_id") == "color_preview":
		text_to_copy = _rows_fallback_hex(row)

	var copy := Button.new()
	copy.text = "Copy"
	copy.tooltip_text = "Copy this form to the clipboard"
	copy.add_theme_font_size_override("font_size", 9)
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(text_to_copy)
	)
	h.add_child(copy)

	if not row.get("is_current", false) and _can_replace(lit, row):
		var repl := Button.new()
		repl.text = "Replace"
		repl.tooltip_text = "Replace the literal in the editor with this form"
		repl.add_theme_font_size_override("font_size", 9)
		repl.pressed.connect(func() -> void:
			replace_requested.emit(lit.duplicate(true), text_to_copy)
		)
		h.add_child(repl)
	return h


func _rows_fallback_hex(row: Dictionary) -> String:
	if row.has("color"):
		var c: Color = row.color
		return "&H%02X%02X%02X" % [int(c.b * 255), int(c.g * 255), int(c.r * 255)]
	return str(row.get("text", ""))


func _can_replace(lit: Dictionary, row: Dictionary) -> bool:
	var kind: String = lit.get("kind", "")
	if kind in ["string", "expression"]:
		return false
	if row.get("radix_id") in ["color_preview", "bits", "bitidx", "nib_hi", "nib_lo", "timer_s", "timer_ms", "deg", "rad", "hint"]:
		return false
	return true


func _clear_rows() -> void:
	for c in _rows_box.get_children():
		c.queue_free()
