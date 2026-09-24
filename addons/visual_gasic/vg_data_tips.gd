@tool
extends Node
## VB6-style Data Tips — hover over variables during debugging to see their values.
##
## When debugging is active and the user hovers over a variable name in the
## code editor, a tooltip popup appears showing the variable's current value,
## just like VB6's Data Tips feature. If hover is awkward, placing the caret
## on an identifier shows the same tip immediately.

# NOTE: No class_name here — loaded dynamically via load(), class_name causes
# "hides a global script class" errors when multiple copies exist in the project.

const HOVER_DELAY_SEC := 0.35

var editor_plugin: EditorPlugin
var _tip_popup: PopupPanel
var _tip_label: RichTextLabel
var _hover_timer: Timer
var _last_hover_word: String = ""
var _last_caret_word: String = ""
var _is_debugging: bool = false
var _debug_variables: Dictionary = {}  # variable_name -> value

func _init():
	# Create the floating tooltip popup
	_tip_popup = PopupPanel.new()
	_tip_popup.transparent_bg = false
	_tip_popup.size = Vector2(250, 30)
	# Don't grab focus
	_tip_popup.exclusive = false
	
	_tip_label = RichTextLabel.new()
	_tip_label.bbcode_enabled = true
	_tip_label.fit_content = true
	_tip_label.scroll_active = false
	_tip_label.custom_minimum_size = Vector2(100, 20)
	_tip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 0.88)  # Light yellow (classic tooltip color)
	style.set_border_width_all(1)
	style.border_color = Color(0, 0, 0)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	_tip_popup.add_theme_stylebox_override("panel", style)
	
	_tip_label.add_theme_color_override("default_color", Color(0, 0, 0))
	_tip_label.add_theme_font_size_override("normal_font_size", 12)
	_tip_popup.add_child(_tip_label)
	
	# Hover timer (delay before showing tip, like VB6)
	_hover_timer = Timer.new()
	_hover_timer.one_shot = true
	_hover_timer.wait_time = HOVER_DELAY_SEC
	_hover_timer.timeout.connect(_on_hover_timeout)
	add_child(_hover_timer)

func setup(plugin: EditorPlugin):
	editor_plugin = plugin
	# Add popup to editor base (needs to be in the tree)
	if editor_plugin and is_instance_valid(editor_plugin):
		editor_plugin.get_editor_interface().get_base_control().add_child(_tip_popup)

func cleanup():
	if is_instance_valid(_tip_popup):
		_tip_popup.queue_free()
	if is_instance_valid(_hover_timer):
		_hover_timer.queue_free()

func get_debug_variables() -> Dictionary:
	return _debug_variables.duplicate()

## Called by the debugger when break is hit — provides current variables
func set_debug_variables(variables: Dictionary):
	_debug_variables = variables
	_is_debugging = true
	# Variables may arrive after the user already hovered / placed the caret.
	if not _last_hover_word.is_empty() and _lookup_variable(_last_hover_word) != null:
		if _hover_timer.is_stopped():
			_show_tip(_last_hover_word, _lookup_variable(_last_hover_word))
		else:
			_hover_timer.start()
	if not _last_caret_word.is_empty():
		var cv = _lookup_variable(_last_caret_word)
		if cv != null:
			_show_tip(_last_caret_word, cv)

## Merge frame locals (e.g. from call stack) into the data-tip lookup table.
func merge_debug_variables(extra: Dictionary) -> void:
	if extra.is_empty():
		return
	for k in extra.keys():
		_debug_variables[k] = extra[k]
	_is_debugging = true

## Called when debugging ends
func clear_debug_state():
	_is_debugging = false
	_debug_variables.clear()
	_last_caret_word = ""
	hide_tip()

## Try to show a data tip for the word under the mouse in a CodeEdit
func check_hover(code_edit: CodeEdit, mouse_pos: Vector2):
	if not _is_debugging:
		return
	
	# Hide if mouse is outside the editor text area (e.g. in gutter or off-control)
	var gutter_w := code_edit.get_total_gutter_width() if code_edit.has_method("get_total_gutter_width") else 48.0
	if mouse_pos.x < gutter_w or mouse_pos.x > code_edit.size.x \
		or mouse_pos.y < 0 or mouse_pos.y > code_edit.size.y:
		hide_tip()
		return
	
	var word := _get_word_at_mouse(code_edit, mouse_pos)
	if word.is_empty():
		hide_tip()
		return
	
	if word != _last_hover_word:
		_last_hover_word = word
		_hover_timer.stop()
	
	if _lookup_variable(word) == null:
		hide_tip()
		return
	
	if not _tip_popup.visible:
		_hover_timer.start()

## Caret on an identifier — show immediately (no hover delay).
func check_caret(code_edit: CodeEdit):
	if not _is_debugging or code_edit == null:
		return
	var word := ""
	if code_edit.has_method("get_symbol_under_caret"):
		word = code_edit.get_symbol_under_caret()
	if word.is_empty():
		_last_caret_word = ""
		if _tip_popup.visible and _hover_timer.is_stopped():
			hide_tip()
		return
	_last_caret_word = word
	var value = _lookup_variable(word)
	if value == null:
		if _tip_popup.visible and _hover_timer.is_stopped():
			hide_tip()
		return
	_hover_timer.stop()
	_last_hover_word = word
	_show_tip(word, value)

func _on_hover_timeout():
	if _last_hover_word.is_empty():
		return
	var value = _lookup_variable(_last_hover_word)
	if value != null:
		_show_tip(_last_hover_word, value)

func _show_tip(var_name: String, value):
	var type_name = _get_type_name(value)
	var val_str = str(value)
	if val_str.length() > 80:
		val_str = val_str.substr(0, 77) + "..."
	
	_tip_label.text = "[b]" + var_name + "[/b] = " + val_str + "  [i](" + type_name + ")[/i]"
	
	# Position near mouse
	var mouse = DisplayServer.mouse_get_position()
	_tip_popup.position = Vector2i(mouse.x + 16, mouse.y + 16)
	_tip_popup.size = Vector2(0, 0)  # Auto-size
	_tip_popup.popup()

func hide_tip():
	_last_hover_word = ""
	if is_instance_valid(_hover_timer):
		_hover_timer.stop()
	if is_instance_valid(_tip_popup) and _tip_popup.visible:
		_tip_popup.hide()

func _lookup_variable(word: String):
	if word.is_empty():
		return null
	if _debug_variables.has(word):
		return _debug_variables[word]
	var lower := word.to_lower()
	for k in _debug_variables.keys():
		if str(k).to_lower() == lower:
			return _debug_variables[k]
	return null

func _get_word_at_mouse(code_edit: CodeEdit, mouse_pos: Vector2) -> String:
	"""Extract the identifier word under the mouse position in a CodeEdit."""
	# mouse_pos is local to the CodeEdit (from gui_input / _gui_input).
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
