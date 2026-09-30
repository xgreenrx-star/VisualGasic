@tool
extends Node
## VB6-style Data Tips — hover over identifiers in the code editor.
##
## Cream panel + black text (VG IDE chrome), never Godot's dark TooltipPanel.
## Implemented as a top-level Control overlay (not PopupPanel/Window) so it
## does not steal mouse focus or re-popup on every motion event.

const VGTheme = preload("res://addons/visual_gasic/vg_theme_utils.gd")

const HOVER_DELAY_SEC := 0.35

var editor_plugin: EditorPlugin
var _tip_panel: PanelContainer
var _tip_label: Label
var _hover_timer: Timer
var _last_hover_word: String = ""
var _last_caret_word: String = ""
var _last_tip_text: String = ""
var _is_debugging: bool = false
var _debug_variables: Dictionary = {}  # variable_name -> value

func _init():
	_tip_panel = PanelContainer.new()
	_tip_panel.visible = false
	_tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_panel.top_level = true
	_tip_panel.z_index = 128
	_tip_panel.add_theme_stylebox_override("panel", VGTheme.tooltip_stylebox())

	_tip_label = Label.new()
	_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	VGTheme.style_tooltip_label(_tip_label)
	_tip_panel.add_child(_tip_label)

	_hover_timer = Timer.new()
	_hover_timer.one_shot = true
	_hover_timer.wait_time = HOVER_DELAY_SEC
	_hover_timer.timeout.connect(_on_hover_timeout)
	add_child(_hover_timer)

func setup(plugin: EditorPlugin):
	editor_plugin = plugin
	if editor_plugin and is_instance_valid(editor_plugin):
		editor_plugin.get_editor_interface().get_base_control().add_child(_tip_panel)

func cleanup():
	if is_instance_valid(_tip_panel):
		_tip_panel.queue_free()
	if is_instance_valid(_hover_timer):
		_hover_timer.queue_free()

func get_debug_variables() -> Dictionary:
	return _debug_variables.duplicate()

func set_debug_variables(variables: Dictionary):
	_debug_variables = variables
	_is_debugging = true
	if _tip_panel.visible and not _last_hover_word.is_empty():
		var shown := _format_tip(_last_hover_word)
		if not shown.is_empty():
			_set_tip_text(shown)
			return
	if not _last_hover_word.is_empty() and _lookup_variable(_last_hover_word) != null:
		if _hover_timer.is_stopped() and not _tip_panel.visible:
			_show_tip(_last_hover_word)
		elif not _hover_timer.is_stopped():
			_hover_timer.start()
	if not _last_caret_word.is_empty():
		var cv = _lookup_variable(_last_caret_word)
		if cv != null:
			_show_tip(_last_caret_word)

func merge_debug_variables(extra: Dictionary) -> void:
	if extra.is_empty():
		return
	for k in extra.keys():
		_debug_variables[k] = extra[k]
	_is_debugging = true
	if _tip_panel.visible and not _last_hover_word.is_empty():
		var shown := _format_tip(_last_hover_word)
		if not shown.is_empty():
			_set_tip_text(shown)

func clear_debug_state():
	_is_debugging = false
	_debug_variables.clear()
	_last_caret_word = ""
	hide_tip()

## Hover — debug values when paused, otherwise declared type (Dim / ByVal).
func check_hover(code_edit: CodeEdit, mouse_pos: Vector2):
	var gutter_w := code_edit.get_total_gutter_width() if code_edit.has_method("get_total_gutter_width") else 48.0
	if mouse_pos.x < gutter_w or mouse_pos.x > code_edit.size.x \
		or mouse_pos.y < 0 or mouse_pos.y > code_edit.size.y:
		hide_tip()
		return

	var word := _get_word_at_mouse(code_edit, mouse_pos)
	if word.is_empty():
		hide_tip()
		return

	var type_hint := _type_hint_from_editor(code_edit, word)
	var text := _format_tip(word, type_hint)
	if text.is_empty():
		hide_tip()
		return

	if word == _last_hover_word and _tip_panel.visible:
		_position_tip()
		return

	if word != _last_hover_word:
		_last_hover_word = word
		_hover_timer.stop()
		if _tip_panel.visible:
			hide_tip()
			_last_hover_word = word

	if not _tip_panel.visible:
		_hover_timer.start()

func check_caret(code_edit: CodeEdit):
	if code_edit == null:
		return
	var word := ""
	if code_edit.has_method("get_symbol_under_caret"):
		word = code_edit.get_symbol_under_caret()
	if word.is_empty():
		_last_caret_word = ""
		return
	_last_caret_word = word
	var type_hint := _type_hint_from_editor(code_edit, word)
	if _format_tip(word, type_hint).is_empty():
		return
	if not _is_debugging and _lookup_builtin_constant(word) == null:
		return
	_hover_timer.stop()
	_last_hover_word = word
	_show_tip(word, type_hint)

func _on_hover_timeout():
	if _last_hover_word.is_empty():
		return
	_show_tip(_last_hover_word)

func _show_tip(var_name: String, type_hint: String = ""):
	var text := _format_tip(var_name, type_hint)
	if text.is_empty():
		hide_tip()
		return
	_set_tip_text(text)
	_position_tip()
	_tip_panel.visible = true

func _set_tip_text(text: String) -> void:
	if text == _last_tip_text and _tip_label.text == text:
		return
	_last_tip_text = text
	_tip_label.text = text
	_tip_panel.reset_size()

func _position_tip() -> void:
	if not is_instance_valid(_tip_panel) or not _tip_panel.is_inside_tree():
		return
	var parent := _tip_panel.get_parent() as Control
	var pos: Vector2
	if parent:
		pos = parent.get_global_mouse_position()
	else:
		pos = _tip_panel.get_global_mouse_position()
	_tip_panel.global_position = pos + Vector2(18, 22)
	_tip_panel.reset_size()

func hide_tip():
	_last_hover_word = ""
	_last_tip_text = ""
	if is_instance_valid(_hover_timer):
		_hover_timer.stop()
	if is_instance_valid(_tip_panel) and _tip_panel.visible:
		_tip_panel.visible = false

func _format_tip(word: String, type_hint: String = "") -> String:
	var value = _lookup_identifier_value(word)
	if value != null:
		var val_str := str(value)
		if val_str.length() > 80:
			val_str = val_str.substr(0, 77) + "..."
		var kind := "Variable"
		if _lookup_debug_variable(word) == null and _lookup_builtin_constant(word) != null:
			kind = "Constant"
		return word + " = " + val_str + "  (" + kind + ", " + _get_type_name(value) + ")"
	if type_hint.is_empty():
		return ""
	return word + " As " + type_hint

func _type_hint_from_editor(code_edit: CodeEdit, word: String) -> String:
	if code_edit == null or word.is_empty():
		return ""
	if "_variable_types" in code_edit:
		var types: Dictionary = code_edit._variable_types
		return str(types.get(word.to_lower(), ""))
	return ""

func _lookup_debug_variable(word: String):
	if word.is_empty():
		return null
	if _debug_variables.has(word):
		return _debug_variables[word]
	var lower := word.to_lower()
	for k in _debug_variables.keys():
		if str(k).to_lower() == lower:
			return _debug_variables[k]
	return null


func _lookup_builtin_constant(word: String):
	if word.is_empty():
		return null
	if not ClassDB.class_has_method("VisualGasicLanguage", "vg_lookup_builtin_constant"):
		return null
	var result = ClassDB.class_call_static("VisualGasicLanguage", "vg_lookup_builtin_constant", word)
	if result == null:
		return null
	if typeof(result) == TYPE_NIL:
		return null
	return result


func _lookup_identifier_value(word: String):
	var v = _lookup_debug_variable(word)
	if v != null:
		return v
	return _lookup_builtin_constant(word)


func _lookup_variable(word: String):
	return _lookup_identifier_value(word)

func _get_word_at_mouse(code_edit: CodeEdit, mouse_pos: Vector2) -> String:
	var line_col := code_edit.get_line_column_at_pos(mouse_pos)
	var line_idx := line_col.y
	var col_idx := line_col.x
	if line_idx < 0 or line_idx >= code_edit.get_line_count():
		return ""
	var line := code_edit.get_line(line_idx)
	if col_idx < 0 or col_idx >= line.length():
		return ""
	return _word_at_column(line, col_idx)

func _word_at_column(line: String, col_idx: int) -> String:
	var start := col_idx
	var end_pos := col_idx
	while start > 0 and _is_ident_char(line[start - 1]):
		start -= 1
	while end_pos < line.length() and _is_ident_char(line[end_pos]):
		end_pos += 1
	if start == end_pos:
		return ""
	return line.substr(start, end_pos - start)

func _is_ident_char(c: String) -> bool:
	var code = c.unicode_at(0)
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122) \
		or (code >= 48 and code <= 57) or c == "_"

func _get_type_name(value) -> String:
	if value is int:
		return "Integer"
	elif value is float:
		return "Double"
	elif value is String:
		return "String"
	elif value is bool:
		return "Boolean"
	elif value is Array:
		return "Array"
	elif value is Dictionary:
		return "Dictionary"
	elif value == null:
		return "Nothing"
	else:
		return "Variant"
