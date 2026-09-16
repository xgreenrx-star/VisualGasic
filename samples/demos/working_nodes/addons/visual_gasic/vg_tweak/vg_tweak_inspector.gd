@tool
extends VBoxContainer
class_name VGTweakInspector

# Auto-generated property editor for a VGTweakTarget. Emits property_changed
# whenever the user edits a value through any of the spawned widgets.

signal property_changed(prop: String, value: Variant)
signal request_source_edit(prop: String)
signal request_ai_edit(prop: String, new_value: Variant)
signal request_swap()

var _target = null  # VGTweakTarget
var _editors: Dictionary = {}
var _suppress_emit: bool = false

const INSPECTOR_FONT_SIZE := 11
const COLOR_HISTORY_PATH := "user://vg_color_history.json"
const COLOR_HISTORY_MAX := 12
static var _color_history_cache: Array = []
static var _color_history_loaded: bool = false

func _ensure_compact_theme() -> void:
	if theme != null:
		return
	var t := Theme.new()
	t.default_font_size = INSPECTOR_FONT_SIZE
	theme = t

func set_target(target) -> void:
	_ensure_compact_theme()
	_target = target
	_rebuild()

func refresh_values() -> void:
	if _target == null:
		return
	_suppress_emit = true
	for prop in _editors.keys():
		var editor = _editors[prop]
		var value = _target.get_value(prop)
		_set_editor_value(editor, value)
	_suppress_emit = false

func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_editors.clear()
	if _target == null:
		var hint := Label.new()
		hint.text = "No target selected."
		hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		add_child(hint)
		return
	var title := Label.new()
	title.text = "%s  [%s]" % [_target.label, _target.kind]
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(1, 1, 0.7))
	add_child(title)

	var schema: Dictionary = _target.get_schema()
	if schema.is_empty():
		var none := Label.new()
		none.text = "(no editable properties)"
		add_child(none)
	else:
		for prop in schema.keys():
			_build_row(prop, schema[prop])

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	add_child(actions)

	var swap_btn := Button.new()
	swap_btn.text = "Swap…"
	swap_btn.disabled = not _target.can_swap()
	swap_btn.pressed.connect(func(): emit_signal("request_swap"))
	actions.add_child(swap_btn)

	var ai_btn := Button.new()
	ai_btn.text = "Edit with AI"
	ai_btn.tooltip_text = "Ask the AI to modify the source so this value is permanent"
	ai_btn.pressed.connect(func(): emit_signal("request_ai_edit", "", null))
	actions.add_child(ai_btn)

func _build_row(prop: String, spec: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	var lbl := Label.new()
	lbl.text = str(spec.get("label", prop))
	lbl.custom_minimum_size.x = 90
	row.add_child(lbl)

	var t: String = str(spec.get("type", "String"))
	var current = _target.get_value(prop)
	var editor: Control = _make_editor(t, spec, current, prop)
	if editor:
		editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(editor)
		_editors[prop] = editor

	if not _target.get_source(prop).is_empty():
		var src_btn := Button.new()
		src_btn.text = "→src"
		src_btn.tooltip_text = "Apply value to source code"
		src_btn.pressed.connect(func(): emit_signal("request_source_edit", prop))
		row.add_child(src_btn)

func _make_editor(t: String, spec: Dictionary, current: Variant, prop: String) -> Control:
	match t:
		"Vector2":
			return _make_vec2(current, prop)
		"Color":
			return _make_color(current, prop)
		"float":
			return _make_float(spec, current, prop)
		"int":
			return _make_int(spec, current, prop)
		"bool":
			return _make_bool(current, prop)
		"String":
			return _make_string(current, prop)
		"enum":
			return _make_enum(spec, current, prop)
	return _make_string(current, prop)

func _make_vec2(current: Variant, prop: String) -> Control:
	var box := HBoxContainer.new()
	var sx := SpinBox.new()
	var sy := SpinBox.new()
	for s in [sx, sy]:
		s.min_value = -100000
		s.max_value = 100000
		s.step = 1
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(s)
	var v: Vector2 = current if typeof(current) == TYPE_VECTOR2 else Vector2.ZERO
	sx.value = v.x
	sy.value = v.y
	var emit_change = func():
		if not _suppress_emit:
			emit_signal("property_changed", prop, Vector2(sx.value, sy.value))
	sx.value_changed.connect(func(_v): emit_change.call())
	sy.value_changed.connect(func(_v): emit_change.call())
	box.set_meta("kind", "vec2")
	box.set_meta("sx", sx)
	box.set_meta("sy", sy)
	return box

func _make_color(current: Variant, prop: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var swatches := HBoxContainer.new()
	swatches.add_theme_constant_override("separation", 2)
	box.add_child(swatches)
	var picker := ColorPickerButton.new()
	picker.color = current if typeof(current) == TYPE_COLOR else Color(1, 1, 1, 1)
	picker.custom_minimum_size.y = 24
	picker.color_changed.connect(func(c):
		_push_color_history(c)
		_rebuild_swatches(swatches, picker, prop)
		if not _suppress_emit:
			emit_signal("property_changed", prop, c)
	)
	box.add_child(picker)
	box.set_meta("kind", "color")
	box.set_meta("picker", picker)
	_rebuild_swatches(swatches, picker, prop)
	return box

func _rebuild_swatches(host: HBoxContainer, picker: ColorPickerButton, prop: String) -> void:
	_ensure_color_history_loaded()
	for c in host.get_children():
		c.queue_free()
	if _color_history_cache.is_empty():
		return
	for col in _color_history_cache:
		var b := Button.new()
		b.custom_minimum_size = Vector2(16, 16)
		b.tooltip_text = "#%s" % col.to_html()
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_border_width_all(1)
		sb.border_color = Color(1, 1, 1, 0.3)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		var cap: Color = col
		b.pressed.connect(func():
			picker.color = cap
			if not _suppress_emit:
				emit_signal("property_changed", prop, cap)
		)
		host.add_child(b)

static func _ensure_color_history_loaded() -> void:
	if _color_history_loaded:
		return
	_color_history_loaded = true
	if not FileAccess.file_exists(COLOR_HISTORY_PATH):
		return
	var f := FileAccess.open(COLOR_HISTORY_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_ARRAY:
		return
	for item in parsed:
		if typeof(item) == TYPE_STRING:
			_color_history_cache.append(Color.html(item))

static func _push_color_history(c: Color) -> void:
	_ensure_color_history_loaded()
	var key := c.to_html()
	var kept: Array = [c]
	for existing in _color_history_cache:
		if existing.to_html() != key:
			kept.append(existing)
		if kept.size() >= COLOR_HISTORY_MAX:
			break
	_color_history_cache = kept
	var f := FileAccess.open(COLOR_HISTORY_PATH, FileAccess.WRITE)
	if f == null:
		return
	var serial: Array = []
	for col in _color_history_cache:
		serial.append(col.to_html())
	f.store_string(JSON.stringify(serial))
	f.close()

func _make_float(spec: Dictionary, current: Variant, prop: String) -> Control:
	var s := SpinBox.new()
	s.min_value = float(spec.get("min", -100000.0))
	s.max_value = float(spec.get("max", 100000.0))
	s.step = float(spec.get("step", 0.1))
	s.value = float(current) if current != null else 0.0
	s.value_changed.connect(func(v):
		if not _suppress_emit:
			emit_signal("property_changed", prop, v)
	)
	s.set_meta("kind", "float")
	return s

func _make_int(spec: Dictionary, current: Variant, prop: String) -> Control:
	var s := SpinBox.new()
	s.min_value = float(spec.get("min", -100000))
	s.max_value = float(spec.get("max", 100000))
	s.step = 1
	s.rounded = true
	s.value = int(current) if current != null else 0
	s.value_changed.connect(func(v):
		if not _suppress_emit:
			emit_signal("property_changed", prop, int(v))
	)
	s.set_meta("kind", "int")
	return s

func _make_bool(current: Variant, prop: String) -> Control:
	var cb := CheckBox.new()
	cb.button_pressed = current == true
	cb.toggled.connect(func(p):
		if not _suppress_emit:
			emit_signal("property_changed", prop, p)
	)
	cb.set_meta("kind", "bool")
	return cb

func _make_string(current: Variant, prop: String) -> Control:
	var box := HBoxContainer.new()
	var le := LineEdit.new()
	le.text = str(current) if current != null else ""
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.text_submitted.connect(func(t):
		if not _suppress_emit:
			emit_signal("property_changed", prop, t)
	)
	le.focus_exited.connect(func():
		if not _suppress_emit:
			emit_signal("property_changed", prop, le.text)
	)
	box.add_child(le)
	var more := Button.new()
	more.text = "…"
	more.tooltip_text = "Open multi-line editor"
	more.custom_minimum_size = Vector2(22, 0)
	more.pressed.connect(func(): _open_multiline_editor(prop, le))
	box.add_child(more)
	box.set_meta("kind", "string")
	box.set_meta("le", le)
	return box

func _open_multiline_editor(prop: String, le: LineEdit) -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "Edit %s" % prop
	dlg.min_size = Vector2(480, 280)
	var te := TextEdit.new()
	te.text = le.text
	te.custom_minimum_size = Vector2(460, 220)
	dlg.add_child(te)
	dlg.confirmed.connect(func():
		le.text = te.text
		if not _suppress_emit:
			emit_signal("property_changed", prop, te.text)
		dlg.queue_free()
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()

func _make_enum(spec: Dictionary, current: Variant, prop: String) -> Control:
	var ob := OptionButton.new()
	var values: Array = spec.get("values", [])
	var idx := 0
	for i in range(values.size()):
		ob.add_item(str(values[i]))
		ob.set_item_metadata(i, values[i])
		if str(values[i]) == str(current):
			idx = i
	ob.select(idx)
	ob.item_selected.connect(func(i):
		if not _suppress_emit:
			emit_signal("property_changed", prop, ob.get_item_metadata(i))
	)
	ob.set_meta("kind", "enum")
	return ob

func _set_editor_value(editor: Control, value: Variant) -> void:
	var kind: String = str(editor.get_meta("kind", ""))
	match kind:
		"vec2":
			var v: Vector2 = value if typeof(value) == TYPE_VECTOR2 else Vector2.ZERO
			editor.get_meta("sx").value = v.x
			editor.get_meta("sy").value = v.y
		"color":
			var pk: ColorPickerButton = editor.get_meta("picker", null)
			if pk != null:
				pk.color = value if typeof(value) == TYPE_COLOR else pk.color
			elif "color" in editor:
				editor.color = value if typeof(value) == TYPE_COLOR else editor.color
		"float", "int":
			editor.value = float(value) if value != null else 0.0
		"bool":
			editor.button_pressed = value == true
		"string":
			var le2: LineEdit = editor.get_meta("le", null)
			if le2 != null:
				le2.text = str(value) if value != null else ""
			elif "text" in editor:
				editor.text = str(value) if value != null else ""
		"enum":
			for i in range(editor.get_item_count()):
				if str(editor.get_item_metadata(i)) == str(value):
					editor.select(i)
					break
