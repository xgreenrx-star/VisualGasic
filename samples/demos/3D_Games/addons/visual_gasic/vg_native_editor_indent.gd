@tool
extends RefCounted
class_name VGNativeEditorIndent
## Auto-indent + block closer insertion for Godot's native Script editor CodeEdit.
## VGCodeEdit already handles this; native CodeEdit tabs need the same Enter behavior.

const BLOCK_START_KEYWORDS: Array[String] = [
	"Sub", "Function", "Property", "Class", "Type", "Enum",
	"For", "While", "Do", "Select Case", "With", "Try", "Whenever",
]

const DEDENT_TRIGGERS: Array[String] = [
	"End Sub", "End Function", "End If", "Next", "Wend", "Loop",
	"End Select", "End Class", "End Try", "End Whenever", "End With",
	"End Property", "End Type", "End Enum",
	"Else", "ElseIf", "Case", "Catch", "Finally",
]


static func attach(code_edit: CodeEdit) -> void:
	if code_edit.has_meta(&"_vg_native_indent_hooked"):
		return
	if code_edit is VGCodeEdit:
		return
	code_edit.set_meta(&"_vg_native_indent_hooked", true)
	code_edit.set_meta(&"_vg_prev_line_count", code_edit.get_line_count())
	code_edit.indent_automatic = false
	code_edit.indent_size = 4
	code_edit.indent_use_spaces = false
	if not code_edit.text_changed.is_connected(_on_text_changed):
		code_edit.text_changed.connect(_on_text_changed.bind(code_edit), CONNECT_DEFERRED)
	var VGKeywordAutocorrect = load("res://addons/visual_gasic/vg_keyword_autocorrect.gd")
	if VGKeywordAutocorrect:
		VGKeywordAutocorrect.attach(code_edit)


static func _on_text_changed(code_edit: CodeEdit) -> void:
	if not is_instance_valid(code_edit):
		return
	var cur_line_count := code_edit.get_line_count()
	var prev_line_count: int = code_edit.get_meta(&"_vg_prev_line_count", cur_line_count)
	code_edit.set_meta(&"_vg_prev_line_count", cur_line_count)
	if cur_line_count == prev_line_count + 1:
		_handle_auto_indent.call_deferred(code_edit)


static func _handle_auto_indent(code_edit: CodeEdit) -> void:
	if not is_instance_valid(code_edit):
		return
	var line_idx := code_edit.get_caret_line()
	if line_idx <= 0:
		return

	# Capitalize keywords on the line the user just left (e.g. for → For).
	var VGKeywordAutocorrect = load("res://addons/visual_gasic/vg_keyword_autocorrect.gd")
	if VGKeywordAutocorrect:
		VGKeywordAutocorrect.autocorrect_line_in_editor(code_edit, line_idx - 1)

	var prev_line := code_edit.get_line(line_idx - 1).strip_edges()
	var current_indent := _get_line_indent(code_edit, line_idx - 1)

	if _line_starts_block(prev_line):
		_set_line_indent(code_edit, line_idx, current_indent + 1)
		var closer := _get_block_closer(prev_line)
		if not closer.is_empty() and _should_insert_closer(code_edit, line_idx, current_indent, closer):
			_insert_block_closer(code_edit, line_idx, current_indent, closer)
		return

	var pl := prev_line.to_lower()
	if pl.begins_with("if ") and pl.ends_with(" then"):
		_set_line_indent(code_edit, line_idx, current_indent + 1)
		if _should_insert_closer(code_edit, line_idx, current_indent, "End If"):
			_insert_block_closer(code_edit, line_idx, current_indent, "End If")
		return
	if pl == "else" or pl.begins_with("elseif ") or pl.begins_with("case ") or pl == "case else":
		_set_line_indent(code_edit, line_idx, current_indent + 1)
		return

	var current_line := code_edit.get_line(line_idx).strip_edges()
	for trigger in DEDENT_TRIGGERS:
		if current_line.begins_with(trigger):
			_set_line_indent(code_edit, line_idx, maxi(0, current_indent - 1))
			return

	_set_line_indent(code_edit, line_idx, current_indent)


static func _line_starts_block(line: String) -> bool:
	var work := line
	for prefix in ["Public ", "Private ", "Static ", "Friend "]:
		if work.begins_with(prefix):
			work = work.substr(prefix.length())
			break
	for kw in BLOCK_START_KEYWORDS:
		if work.begins_with(kw + " ") or work.begins_with(kw + "(") or work == kw:
			return true
	return false


static func _get_block_closer(line: String) -> String:
	var work := line
	for prefix in ["Public ", "Private ", "Static ", "Friend "]:
		if work.begins_with(prefix):
			work = work.substr(prefix.length())
			break
	if work.begins_with("Sub ") or work.begins_with("Sub(") or work == "Sub":
		return "End Sub"
	if work.begins_with("Function ") or work.begins_with("Function(") or work == "Function":
		return "End Function"
	if work.begins_with("Property "):
		return "End Property"
	if work.begins_with("Class ") or work == "Class":
		return "End Class"
	if work.begins_with("Type ") or work == "Type":
		return "End Type"
	if work.begins_with("Enum ") or work == "Enum":
		return "End Enum"
	if work.begins_with("For Each ") or work.begins_with("For "):
		return "Next"
	if work.begins_with("While ") or work == "While":
		return "Wend"
	if work.begins_with("Do ") or work == "Do":
		return "Loop"
	if work.begins_with("Select Case") or work.begins_with("Select Match"):
		return "End Select"
	if work.begins_with("With ") or work == "With":
		return "End With"
	if work == "Try" or work.begins_with("Try "):
		return "End Try"
	if work.begins_with("Whenever ") or work == "Whenever":
		return "End Whenever"
	return ""


static func _get_line_indent(code_edit: CodeEdit, line_idx: int) -> int:
	var line := code_edit.get_line(line_idx)
	var indent := 0
	for c in line:
		if c == "\t":
			indent += 1
		elif c == " ":
			indent += 1.0 / code_edit.indent_size
		else:
			break
	return int(indent)


static func _set_line_indent(code_edit: CodeEdit, line_idx: int, indent_level: int) -> void:
	var line := code_edit.get_line(line_idx)
	var content := line.strip_edges(true, false)
	var new_line := "\t".repeat(indent_level) + content
	code_edit.select(line_idx, 0, line_idx, line.length())
	code_edit.insert_text_at_caret(new_line)


static func _should_insert_closer(code_edit: CodeEdit, from_line: int, parent_indent: int, closer: String) -> bool:
	for i in range(from_line + 1, code_edit.get_line_count()):
		var lt := code_edit.get_line(i)
		var line_stripped := lt.strip_edges()
		if line_stripped.is_empty():
			continue
		var line_indent := _get_line_indent(code_edit, i)
		if line_indent == parent_indent and line_stripped.nocasecmp_to(closer) == 0:
			return false
		if line_indent <= parent_indent:
			break
	return true


static func _insert_block_closer(code_edit: CodeEdit, cursor_line: int, parent_indent: int, closer: String) -> void:
	var close_text := "\t".repeat(parent_indent) + closer
	var save_col := code_edit.get_line(cursor_line).length()
	code_edit.set_caret_line(cursor_line)
	code_edit.set_caret_column(save_col)
	code_edit.insert_text_at_caret("\n" + close_text)
	code_edit.set_caret_line(cursor_line)
	code_edit.set_caret_column(save_col)
