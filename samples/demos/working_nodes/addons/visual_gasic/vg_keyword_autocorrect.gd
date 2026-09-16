@tool
extends RefCounted
class_name VGKeywordAutocorrect
## Shared VB6-style keyword auto-correct: lowercase recognized words → proper casing.
## Used by VGCodeEdit and Godot's native Script editor CodeEdit tabs.

const VB6_KEYWORD_CASING: Dictionary = {
	"dim": "Dim", "sub": "Sub", "function": "Function", "end": "End",
	"if": "If", "then": "Then", "else": "Else", "elseif": "ElseIf",
	"select": "Select", "case": "Case", "for": "For", "to": "To",
	"step": "Step", "next": "Next", "each": "Each", "in": "In",
	"do": "Do", "loop": "Loop", "while": "While", "wend": "Wend",
	"until": "Until", "with": "With", "exit": "Exit", "goto": "GoTo",
	"gosub": "GoSub", "call": "Call", "return": "Return",
	"and": "And", "or": "Or", "not": "Not", "xor": "Xor",
	"mod": "Mod", "is": "Is", "like": "Like", "as": "As",
	"new": "New", "set": "Set", "let": "Let", "get": "Get",
	"private": "Private", "public": "Public", "static": "Static",
	"const": "Const", "redim": "ReDim", "preserve": "Preserve",
	"byval": "ByVal", "byref": "ByRef", "optional": "Optional",
	"paramarray": "ParamArray", "property": "Property",
	"true": "True", "false": "False", "nothing": "Nothing",
	"null": "Null", "empty": "Empty", "me": "Me",
	"on": "On", "error": "Error", "resume": "Resume",
	"print": "Print", "debug": "Debug",
	"try": "Try", "catch": "Catch", "finally": "Finally",
	"throw": "Throw", "raise": "Raise",
	"type": "Type", "enum": "Enum", "struct": "Struct",
	"class": "Class", "inherits": "Inherits", "implements": "Implements",
	"whenever": "Whenever", "section": "Section",
	"suspend": "Suspend", "local": "Local",
	"option": "Option", "explicit": "Explicit",
	"open": "Open", "close": "Close", "input": "Input",
	"output": "Output", "append": "Append", "line": "Line",
	"write": "Write", "read": "Read",
	"doevents": "DoEvents", "erase": "Erase",
	"integer": "Integer", "long": "Long", "single": "Single",
	"double": "Double", "string": "String", "boolean": "Boolean",
	"byte": "Byte", "date": "Date", "variant": "Variant",
	"object": "Object", "dictionary": "Dictionary",
	"iif": "IIf", "import": "Import", "restore": "Restore", "data": "Data",
}

const CROSS_LANG_TRANSLATIONS: Dictionary = {
	"var": "Dim",
	"func": "Function",
	"def": "Function",
	"void": "Sub",
	"elif": "ElseIf",
	"elsif": "ElseIf",
	"switch": "Select Case",
	"foreach": "For Each",
	"none": "Nothing",
	"undefined": "Nothing",
	"nil": "Nothing",
}


static func attach(code_edit: CodeEdit) -> void:
	if code_edit.has_meta(&"_vg_keyword_autocorrect_hooked"):
		return
	if code_edit is VGCodeEdit:
		return
	code_edit.set_meta(&"_vg_keyword_autocorrect_hooked", true)
	code_edit.set_meta(&"_vg_prev_caret_line_ac", code_edit.get_caret_line())
	if not code_edit.caret_changed.is_connected(_on_caret_changed):
		code_edit.caret_changed.connect(_on_caret_changed.bind(code_edit))


static func _on_caret_changed(code_edit: CodeEdit) -> void:
	if not is_instance_valid(code_edit):
		return
	var current_line := code_edit.get_caret_line()
	var prev_line: int = code_edit.get_meta(&"_vg_prev_caret_line_ac", current_line)
	code_edit.set_meta(&"_vg_prev_caret_line_ac", current_line)
	if prev_line >= 0 and prev_line != current_line:
		autocorrect_line_in_editor(code_edit, prev_line)


static func autocorrect_line_in_editor(code_edit: CodeEdit, line_idx: int) -> void:
	if not is_instance_valid(code_edit):
		return
	if line_idx < 0 or line_idx >= code_edit.get_line_count():
		return
	var orig := code_edit.get_line(line_idx)
	var corrected := autocorrect_line(orig)
	if corrected != orig:
		code_edit.set_line(line_idx, corrected)


static func autocorrect_line(line_text: String) -> String:
	if line_text.strip_edges().is_empty():
		return line_text

	var orig_line := line_text
	var stripped_cmnt := line_text.strip_edges(true, false)
	if stripped_cmnt.begins_with("//"):
		var ws := line_text.substr(0, line_text.length() - stripped_cmnt.length())
		return ws + "'" + stripped_cmnt.substr(2)
	if stripped_cmnt.begins_with("# ") or stripped_cmnt == "#":
		var ws := line_text.substr(0, line_text.length() - stripped_cmnt.length())
		return ws + "'" + stripped_cmnt.substr(1)

	var stripped := line_text.strip_edges()
	if stripped.begins_with("'") or stripped.to_upper().begins_with("REM "):
		return line_text

	var new_line := ""
	var i := 0
	var in_string := false
	var line_len := line_text.length()

	while i < line_len:
		var ch: String = line_text[i]

		if ch == "\"":
			in_string = not in_string
			new_line += ch
			i += 1
			continue

		if ch == "'" and not in_string:
			new_line += line_text.substr(i)
			break

		if in_string:
			new_line += ch
			i += 1
			continue

		if _is_ident_char(ch):
			var word_start := i
			while i < line_len and _is_ident_char(line_text[i]):
				i += 1
			var word: String = line_text.substr(word_start, i - word_start)
			var lower_word := word.to_lower()
			if CROSS_LANG_TRANSLATIONS.has(lower_word):
				new_line += CROSS_LANG_TRANSLATIONS[lower_word]
			elif VB6_KEYWORD_CASING.has(lower_word):
				new_line += VB6_KEYWORD_CASING[lower_word]
			else:
				var matched_builtin := false
				var VGIntelliSense = load("res://addons/visual_gasic/vg_intellisense.gd")
				if VGIntelliSense:
					for func_info in VGIntelliSense.BUILTIN_FUNCTIONS:
						if func_info["name"].to_lower() == lower_word:
							new_line += func_info["name"]
							matched_builtin = true
							break
				if not matched_builtin:
					new_line += word
		else:
			new_line += ch
			i += 1

	new_line = new_line.replace("Else If ", "ElseIf ")
	if new_line.ends_with("Else If"):
		new_line = new_line.substr(0, new_line.length() - 7) + "ElseIf"

	return new_line if new_line != orig_line else line_text


static func _is_ident_char(ch: String) -> bool:
	var code := ch.unicode_at(0)
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122) \
		or (code >= 48 and code <= 57) or ch == "_"
