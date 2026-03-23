@tool
extends CodeEdit
## VisualGasic CodeEdit with IntelliSense support
##
## Custom CodeEdit for .vg files that provides:
## - VB6 syntax highlighting
## - Auto-completion via VGIntelliSense
## - Bracket matching
## - Auto-indentation
## - Parameter hints

class_name VGCodeEdit

# =============================================================================
# SIGNALS
# =============================================================================

signal code_changed(text: String)
signal parse_requested()

# =============================================================================
# VARIABLES
# =============================================================================

var _intellisense: VGIntelliSense
var _known_controls: Array[String] = []
var _known_variables: Array[String] = []
var _completion_active: bool = false
var _last_word: String = ""
var _prev_caret_line: int = -1  # Track line changes for auto-capitalize
var _snippet_regex: RegEx = null  # Lazy-init for snippet placeholder expansion

# VB6 keywords with correct casing (for auto-capitalize on line leave)
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
	"iif": "IIf",
}

# Cross-language keyword translations (modern languages → VB6 equivalents)
# Applied in _auto_capitalize_line() when the user leaves a line.
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

# Auto-indent settings
# These are checked against the *stripped* previous line.  The matching logic
# in _handle_auto_indent uses _line_starts_block() which handles optional
# access modifiers (Public/Private/Static/Friend) before the keyword.
var _block_start_keywords: Array[String] = [
	"Sub", "Function", "Property", "Class", "Type", "Enum",
	"For", "While", "Do", "Select Case", "With", "Try", "Whenever"
]
var _dedent_triggers: Array[String] = [
	"End Sub", "End Function", "End If", "Next", "Wend", "Loop",
	"End Select", "End Class", "End Try", "End Whenever", "End With",
	"End Property", "End Type", "End Enum",
	"Else", "ElseIf", "Case", "Catch", "Finally"
]

# CBM two-letter abbreviation mappings (Commodore-style shortcuts)
# Unambiguous: always expand.  Ambiguous: show completion menu.
const CBM_UNAMBIGUOUS: Dictionary = {
	"IF": "If", "TH": "Then", "WE": "Wend", "LO": "Loop",
	"DO": "Do", "NE": "Next", "AS": "As", "TO": "To",
	"ST": "Step", "GO": "GoTo", "GS": "GoSub", "CA": "Case",
	"TR": "Try", "FI": "Finally", "EX": "Exit", "CO": "Continue",
	"IS": "Is", "OF": "Of", "ME": "Me", "BY": "ByVal",
	"BR": "ByRef", "OP": "Option", "MO": "Module", "US": "Using",
	"NA": "Namespace", "IM": "Implements", "IN": "Inherits",
	"OV": "Overrides", "MU": "MustOverride", "NO": "NotOverridable",
	"SH": "Shared", "PA": "Parallel", "AW": "Await",
	"TA": "Task", "MA": "Match",
}
const CBM_AMBIGUOUS: Dictionary = {
	"PR": ["Print", "Private", "Property"],
	"FO": ["For", "Format"],
	"FU": ["Function"],
	"SU": ["Sub"],
	"EN": ["End", "Enum"],
	"WH": ["While", "With", "When"],
	"SE": ["Select", "Set"],
	"DI": ["Dim"],
	"RE": ["Return", "ReDim"],
	"EL": ["Else", "ElseIf"],
	"CL": ["Class"],
	"PU": ["Public"],
	"FR": ["Friend"],
	"EA": ["Each"],
	"GE": ["Get"],
	"UN": ["Until"],
	"TY": ["TypeOf", "Type"],
	"CH": ["Catch"],
	"TW": ["Throw"],
	"SR": ["Static", "String", "Structure"],
	"AN": ["And", "AndAlso"],
	"OR": ["Or", "OrElse"],
	"NT": ["Not"],
	"XO": ["Xor"],
}

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_setup_syntax_highlighter()
	_setup_code_completion()
	_setup_auto_indent()
	_connect_signals()

func _setup_syntax_highlighter() -> void:
	var highlighter = CodeHighlighter.new()
	
	# Keywords (blue)
	for keyword in VGIntelliSense.VB6_KEYWORDS:
		highlighter.add_keyword_color(keyword, Color(0.4, 0.6, 1.0))
	
	# Types (cyan)
	for type_name in VGIntelliSense.VB6_TYPES:
		highlighter.add_keyword_color(type_name, Color(0.4, 0.8, 0.8))
	
	for type_name in VGIntelliSense.GODOT_TYPES:
		highlighter.add_keyword_color(type_name, Color(0.4, 0.8, 0.8))
	
	# Built-in functions (yellow)
	for func_info in VGIntelliSense.BUILTIN_FUNCTIONS:
		highlighter.add_keyword_color(func_info["name"], Color(0.9, 0.8, 0.4))
	
	# String color (orange)
	highlighter.add_color_region("\"", "\"", Color(0.9, 0.6, 0.4))
	
	# Comment color (green)
	highlighter.add_color_region("'", "", Color(0.5, 0.7, 0.5), true)
	highlighter.add_color_region("REM ", "", Color(0.5, 0.7, 0.5), true)
	
	# Number color
	highlighter.number_color = Color(0.7, 0.9, 0.7)
	
	# Symbol color
	highlighter.symbol_color = Color(0.8, 0.8, 0.8)
	
	# Function color
	highlighter.function_color = Color(0.9, 0.8, 0.4)
	
	# Member color
	highlighter.member_variable_color = Color(0.8, 0.7, 0.9)
	
	syntax_highlighter = highlighter

func _setup_code_completion() -> void:
	# Enable code completion
	code_completion_enabled = true
	# Trigger on dot (member access), space (after keywords), and all letters
	# so completion fires as the user types identifiers/keywords/CBM abbreviations
	var prefixes: Array[String] = [".", " "]
	for ch_code in range("a".unicode_at(0), "z".unicode_at(0) + 1):
		prefixes.append(String.chr(ch_code))
	for ch_code in range("A".unicode_at(0), "Z".unicode_at(0) + 1):
		prefixes.append(String.chr(ch_code))
	code_completion_prefixes = prefixes
	
	# Set up auto-complete delay (lower = faster response)
	# auto_brace_completion_enabled = true
	# auto_brace_completion_pairs = {
	# 	"(": ")",
	# 	"[": "]",
	# 	"\"": "\"",
	# }

func _setup_auto_indent() -> void:
	# NOTE: Do NOT set indent_automatic = true — Godot's built-in auto-indent
	# fires on Enter *before* our _handle_auto_indent runs via call_deferred,
	# causing double-indentation.  We handle it ourselves in _handle_auto_indent.
	indent_automatic = false
	indent_size = 4
	indent_use_spaces = false  # VB6 traditionally uses tabs
	auto_brace_completion_enabled = true
	
	# Enable line numbers in the gutter
	gutters_draw_line_numbers = true
	
	# Enable code folding (indent-based) — property names vary by Godot version
	set("line_folding_enabled", true)
	set("gutters_draw_folding", true)
	
	# Enable built-in breakpoint gutter (VB6 F9 behavior)
	gutters_draw_breakpoints_gutter = true

func _connect_signals() -> void:
	text_changed.connect(_on_text_changed)
	code_completion_requested.connect(_on_code_completion_requested)
	caret_changed.connect(_on_caret_changed)
	breakpoint_toggled.connect(_on_breakpoint_toggled)

# =============================================================================
# CODE COMPLETION
# =============================================================================

func _on_code_completion_requested() -> void:
	var line = get_line(get_caret_line())
	var column = get_caret_column()
	var word = _get_word_at_position(line, column)
	
	# Get context for completions
	var context = {
		"controls": _known_controls,
		"variables": _known_variables,
		"line": line,
		"column": column
	}
	
	# Check if we're after a dot (member access)
	var before_cursor = line.substr(0, column)
	if "." in before_cursor:
		var parts = before_cursor.rsplit(".", true, 1)
		if parts.size() > 0:
			var obj_name = parts[0].strip_edges().get_slice(" ", -1)
			_show_member_completions(obj_name)
			return
	
	# ── CBM abbreviation check ──
	# If the user typed exactly 2 uppercase letters at a statement boundary,
	# offer CBM expansion(s) before regular completions.
	if word.length() == 2 and word == word.to_upper() and _is_cbm_boundary(line, column):
		var upper_word = word.to_upper()
		if CBM_UNAMBIGUOUS.has(upper_word):
			var expansion: String = CBM_UNAMBIGUOUS[upper_word]
			add_code_completion_option(
				CodeEdit.KIND_PLAIN_TEXT,
				expansion + " (CBM: " + upper_word + ")",
				expansion,
				Color(0.5, 1.0, 0.5),  # green tint for CBM
				null, null, 0
			)
			update_code_completion_options(true)
			return
		if CBM_AMBIGUOUS.has(upper_word):
			var options: Array = CBM_AMBIGUOUS[upper_word]
			for opt in options:
				add_code_completion_option(
					CodeEdit.KIND_PLAIN_TEXT,
					opt + " (CBM: " + upper_word + ")",
					opt,
					Color(0.5, 1.0, 0.5),
					null, null, 0
				)
			update_code_completion_options(true)
			return
	
	# Regular completions
	var completions = VGIntelliSense.get_completions(word, context)
	
	for completion in completions:
		var kind = _convert_kind(completion.get("kind", "text"))
		var insert_text = completion.get("insert_text", completion["text"])
		
		# Expand snippet placeholders (${N:default} → default, ${0} → "")
		if completion.get("kind", "") == "snippet":
			insert_text = _expand_snippet_text(insert_text)
		
		add_code_completion_option(
			kind,
			completion["text"],
			insert_text,
			Color.WHITE,
			null,
			null,
			0
		)
	
	update_code_completion_options(true)

func _show_member_completions(obj_name: String) -> void:
	# Try to determine the type of the object
	var obj_type = _infer_type(obj_name)
	
	# Get method + signal completions
	var methods = VGIntelliSense.get_method_completions(obj_type)
	for method in methods:
		add_code_completion_option(
			_convert_kind(method.get("kind", "method")),
			method["text"],
			method["text"],
			Color.WHITE,
			null,
			null,
			0
		)
	
	# Get property completions
	var properties = VGIntelliSense.get_property_completions(obj_type)
	for prop in properties:
		add_code_completion_option(
			_convert_kind(prop.get("kind", "property")),
			prop["text"],
			prop["text"],
			Color.WHITE,
			null,
			null,
			0
		)
	
	update_code_completion_options(true)

func _convert_kind(kind_string: String) -> int:
	match kind_string:
		"keyword": return CodeEdit.KIND_PLAIN_TEXT  # No specific keyword kind
		"function": return CodeEdit.KIND_FUNCTION
		"type": return CodeEdit.KIND_CLASS
		"variable": return CodeEdit.KIND_VARIABLE
		"field": return CodeEdit.KIND_MEMBER
		"snippet": return CodeEdit.KIND_PLAIN_TEXT
		"method": return CodeEdit.KIND_FUNCTION
		"property": return CodeEdit.KIND_MEMBER
		"signal": return CodeEdit.KIND_SIGNAL
		"constant": return CodeEdit.KIND_CONSTANT
		"module": return CodeEdit.KIND_CLASS
		_: return CodeEdit.KIND_PLAIN_TEXT

func _get_word_at_position(line: String, column: int) -> String:
	if column == 0:
		return ""
	
	var start = column - 1
	while start > 0 and _is_word_char(line[start - 1]):
		start -= 1
	
	return line.substr(start, column - start)

func _is_word_char(c: String) -> bool:
	return c.is_valid_identifier() or c == "_"

func _infer_type(var_name: String) -> String:
	# Try to find the variable declaration in the code
	var text = get_text()
	var regex = RegEx.new()
	regex.compile("Dim\\s+" + var_name + "\\s+As\\s+(\\w+)")
	var match = regex.search(text)
	
	if match:
		return match.get_string(1)
	
	# Check if it's a known control
	if var_name in _known_controls:
		# Could be more sophisticated - for now assume Control
		return "Control"
	
	return "Object"

# =============================================================================
# SNIPPET EXPANSION
# =============================================================================

## Expands snippet template placeholders into clean VB6 code.
## ${N:default} → default, ${0} → removed.
## Adds the current line's indentation to continuation lines.
func _expand_snippet_text(code: String) -> String:
	if _snippet_regex == null:
		_snippet_regex = RegEx.new()
		_snippet_regex.compile("\\$\\{\\d+:([^}]*)\\}")
	var result := _snippet_regex.sub(code, "$1", true)
	result = result.replace("${0}", "")
	# Strip trailing whitespace left by ${0} removal
	var lines := result.split("\n")
	if lines.size() <= 1:
		return result
	# Add current line's indentation to continuation lines
	var base_indent := "\t".repeat(_get_line_indent(get_caret_line()))
	var indented: PackedStringArray = []
	for i in range(lines.size()):
		if i == 0:
			indented.append(lines[i])
		else:
			indented.append(base_indent + lines[i])
	return "\n".join(indented)

# =============================================================================
# AUTO-INDENTATION
# =============================================================================

func _on_text_changed() -> void:
	_parse_variables()
	code_changed.emit(get_text())
	# Explicitly request code completion — the built-in prefix auto-trigger
	# is unreliable in @tool / embedded editor contexts.  Deferred so the
	# caret position has settled after the text change.
	call_deferred("_request_completion_deferred")

func _request_completion_deferred() -> void:
	if not has_focus():
		return
	# Only trigger when the caret is at the end of a word (not after delete/space)
	var line := get_line(get_caret_line())
	var col := get_caret_column()
	if col > 0 and _is_word_char(line[col - 1]):
		request_code_completion(true)

func _input(event: InputEvent) -> void:
	if not has_focus():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		# Handle auto-indent on Enter
		call_deferred("_handle_auto_indent")

func _handle_auto_indent() -> void:
	var line_idx = get_caret_line()
	if line_idx == 0:
		return
	
	var prev_line = get_line(line_idx - 1).strip_edges()
	var current_indent = _get_line_indent(line_idx - 1)
	
	# Check if previous line should increase indent
	if _line_starts_block(prev_line):
		_set_line_indent(line_idx, current_indent + 1)
		# Auto-insert closing keyword (End Sub, Next, Wend, etc.)
		var closer := _get_block_closer(prev_line)
		if not closer.is_empty() and _should_insert_closer(line_idx, current_indent, closer):
			_insert_block_closer(line_idx, current_indent, closer)
		return
	
	# Check If...Then on same line (single-line If — no indent increase)
	# Multi-line If ends with "Then" and nothing after → indent
	var pl = prev_line.to_lower()
	if pl.begins_with("if ") and pl.ends_with(" then"):
		_set_line_indent(line_idx, current_indent + 1)
		if _should_insert_closer(line_idx, current_indent, "End If"):
			_insert_block_closer(line_idx, current_indent, "End If")
		return
	if pl == "else" or pl.begins_with("elseif ") or pl.begins_with("case ") or pl == "case else":
		_set_line_indent(line_idx, current_indent + 1)
		return
	
	# Check if current line should decrease indent
	var current_line = get_line(line_idx).strip_edges()
	for trigger in _dedent_triggers:
		if current_line.begins_with(trigger):
			_set_line_indent(line_idx, maxi(0, current_indent - 1))
			return
	
	# Keep same indent
	_set_line_indent(line_idx, current_indent)

## Returns true if `line` is a block-opening statement, handling optional
## access modifiers: Public Sub, Private Function, Static Property Get, etc.
func _line_starts_block(line: String) -> bool:
	var work := line
	# Strip optional access modifier prefix
	for prefix in ["Public ", "Private ", "Static ", "Friend "]:
		if work.begins_with(prefix):
			work = work.substr(prefix.length())
			break  # only one modifier
	# Now check against block keywords
	for kw in _block_start_keywords:
		if work.begins_with(kw + " ") or work.begins_with(kw + "(") or work == kw:
			return true
	return false

## Check if a two-letter abbreviation is at a valid CBM expansion point
func _is_cbm_boundary(line: String, col: int) -> bool:
	if col < 2:
		return false
	# Must be at start of statement (start of line, after space, after Then/Else/:)
	var before = line.substr(0, col - 2).strip_edges()
	if before.is_empty():
		return true
	var last_char = before[-1]
	if last_char == ":" or last_char == " ":
		return true
	var bl = before.to_lower()
	if bl.ends_with("then") or bl.ends_with("else"):
		return true
	return false

func _get_line_indent(line_idx: int) -> int:
	var line = get_line(line_idx)
	var indent = 0
	for c in line:
		if c == "\t":
			indent += 1
		elif c == " ":
			# Count spaces as partial tabs
			indent += 1.0 / indent_size
		else:
			break
	return int(indent)

func _set_line_indent(line_idx: int, indent_level: int) -> void:
	var line = get_line(line_idx)
	var content = line.strip_edges(true, false)  # Keep trailing whitespace
	var new_line = "\t".repeat(indent_level) + content
	
	# Replace the line
	select(line_idx, 0, line_idx, line.length())
	insert_text_at_caret(new_line)

# =============================================================================
# BLOCK AUTO-CLOSE HELPERS
# =============================================================================

## Returns the matching closing keyword for a block-opening statement.
func _get_block_closer(line: String) -> String:
	var work := line
	# Strip optional access modifier prefix
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

## Returns true if a block closer should be auto-inserted (not already present).
func _should_insert_closer(from_line: int, parent_indent: int, closer: String) -> bool:
	for i in range(from_line + 1, get_line_count()):
		var lt := get_line(i)
		var line_stripped := lt.strip_edges()
		if line_stripped.is_empty():
			continue
		var line_indent := _get_line_indent(i)
		# Found matching closer at same indent — don't duplicate
		if line_indent == parent_indent and line_stripped.nocasecmp_to(closer) == 0:
			return false
		# Hit content at same or lower indent that isn't the closer — block is unclosed
		if line_indent <= parent_indent:
			break
	return true

## Inserts a closing keyword below the current cursor line.
func _insert_block_closer(cursor_line: int, parent_indent: int, closer: String) -> void:
	var close_text := "\t".repeat(parent_indent) + closer
	var save_col := get_line(cursor_line).length()
	set_caret_line(cursor_line)
	set_caret_column(save_col)
	insert_text_at_caret("\n" + close_text)
	# Restore cursor to the middle line (between opener and closer)
	set_caret_line(cursor_line)
	set_caret_column(save_col)

# =============================================================================
# VARIABLE PARSING
# =============================================================================

func _parse_variables() -> void:
	_known_variables.clear()
	
	var text = get_text()
	var regex = RegEx.new()
	
	# Match Dim statements
	regex.compile("(?:Dim|Private|Public|Static)\\s+(\\w+)")
	var matches = regex.search_all(text)
	
	for match in matches:
		var var_name = match.get_string(1)
		if var_name not in _known_variables:
			_known_variables.append(var_name)

## Sets the known form controls for IntelliSense
func set_known_controls(controls: Array[String]) -> void:
	_known_controls = controls

## Adds a known control for IntelliSense
func add_known_control(control_name: String) -> void:
	if control_name not in _known_controls:
		_known_controls.append(control_name)

## Gets the current list of known variables
func get_known_variables() -> Array[String]:
	return _known_variables

# =============================================================================
# BRACKET MATCHING
# =============================================================================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_PARENLEFT:
				_show_parameter_hint()
			KEY_G:
				if event.ctrl_pressed and not event.shift_pressed:
					_show_goto_line_dialog()
					accept_event()
			KEY_F9:
				if not event.ctrl_pressed and not event.shift_pressed:
					toggle_breakpoint(get_caret_line())
					accept_event()
				elif event.ctrl_pressed and event.shift_pressed:
					set_conditional_breakpoint(get_caret_line())
					accept_event()

## Show a small popup dialog to jump to a specific line number.
func _show_goto_line_dialog() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Go To Line"
	dialog.ok_button_text = "Go"
	dialog.min_size = Vector2i(260, 0)
	dialog.exclusive = true

	var vbox := VBoxContainer.new()
	var info_label := Label.new()
	info_label.text = "Line number (1 – %d):" % get_line_count()
	vbox.add_child(info_label)

	var line_edit := LineEdit.new()
	line_edit.placeholder_text = str(get_caret_line() + 1)
	line_edit.select_all_on_focus = true
	line_edit.text = str(get_caret_line() + 1)
	vbox.add_child(line_edit)
	dialog.add_child(vbox)

	# Accept on Enter key inside the LineEdit
	line_edit.text_submitted.connect(func(_t):
		dialog.emit_signal("confirmed")
	)

	dialog.confirmed.connect(func():
		var target := line_edit.text.strip_edges().to_int()
		if target < 1:
			target = 1
		elif target > get_line_count():
			target = get_line_count()
		set_caret_line(target - 1)
		set_caret_column(0)
		center_viewport_to_caret()
		dialog.queue_free()
	)

	dialog.canceled.connect(func():
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.popup_centered()
	line_edit.grab_focus()
	line_edit.select_all()

func _show_parameter_hint() -> void:
	var line = get_line(get_caret_line())
	var column = get_caret_column()
	
	# Find the function name before the paren
	var before_paren = line.substr(0, column - 1) if column > 0 else ""
	var func_name = _get_word_at_position(before_paren, before_paren.length())
	
	if func_name.is_empty():
		return
	
	# Look up function signature
	for func_info in VGIntelliSense.BUILTIN_FUNCTIONS:
		if func_info["name"].to_lower() == func_name.to_lower():
			# Show tooltip with signature
			tooltip_text = func_info["signature"] + "\n" + func_info["description"]
			return
	
	tooltip_text = ""

# =============================================================================
# AUTO-CAPITALIZE KEYWORDS ON LINE LEAVE
# =============================================================================

func _on_caret_changed() -> void:
	var current_line = get_caret_line()
	if _prev_caret_line >= 0 and _prev_caret_line != current_line:
		# Caret moved to a different line — capitalize keywords on the previous line
		_auto_capitalize_line(_prev_caret_line)
	_prev_caret_line = current_line

func _auto_capitalize_line(line_idx: int) -> void:
	if line_idx < 0 or line_idx >= get_line_count():
		return
	var line_text: String = get_line(line_idx)
	if line_text.strip_edges().is_empty():
		return
	
	# ── Comment syntax translation (pre-pass) ──
	# Translate // and # comment prefixes to VB6's ' prefix
	var orig_line: String = line_text
	var stripped_cmnt := line_text.strip_edges(true, false)
	if stripped_cmnt.begins_with("//"):
		var ws := line_text.substr(0, line_text.length() - stripped_cmnt.length())
		line_text = ws + "'" + stripped_cmnt.substr(2)
	elif stripped_cmnt.begins_with("# ") or stripped_cmnt == "#":
		var ws := line_text.substr(0, line_text.length() - stripped_cmnt.length())
		line_text = ws + "'" + stripped_cmnt.substr(1)
	
	# Skip comment lines (don't touch content after ')
	var stripped = line_text.strip_edges()
	if stripped.begins_with("'") or stripped.to_upper().begins_with("REM "):
		if line_text != orig_line:
			set_line(line_idx, line_text)
		return
	
	# Walk through the line replacing keywords with correct casing
	var new_line: String = ""
	var i: int = 0
	var in_string: bool = false
	var in_comment: bool = false
	var line_len: int = line_text.length()
	
	while i < line_len:
		var ch: String = line_text[i]
		
		# Toggle string mode
		if ch == "\"" and not in_comment:
			in_string = not in_string
			new_line += ch
			i += 1
			continue
		
		# Enter comment mode
		if ch == "'" and not in_string:
			# Append rest of line as-is
			new_line += line_text.substr(i)
			break
		
		# Inside a string literal — pass through unchanged
		if in_string:
			new_line += ch
			i += 1
			continue
		
		# Collect a word (identifier)
		if _is_ident_char(ch):
			var word_start: int = i
			while i < line_len and _is_ident_char(line_text[i]):
				i += 1
			var word: String = line_text.substr(word_start, i - word_start)
			var lower_word: String = word.to_lower()
			
			# Check cross-language translations first (var→Dim, func→Function, etc.)
			if CROSS_LANG_TRANSLATIONS.has(lower_word):
				new_line += CROSS_LANG_TRANSLATIONS[lower_word]
			# Check VB6 keyword casing
			elif VB6_KEYWORD_CASING.has(lower_word):
				new_line += VB6_KEYWORD_CASING[lower_word]
			else:
				# Also check builtin functions for proper casing
				var matched_builtin: bool = false
				for func_info in VGIntelliSense.BUILTIN_FUNCTIONS:
					if func_info["name"].to_lower() == lower_word:
						new_line += func_info["name"]
						matched_builtin = true
						break
				if not matched_builtin:
					new_line += word  # Keep original casing
		else:
			new_line += ch
			i += 1
	
	# Post-process: "Else If " → "ElseIf " (common cross-language pattern)
	new_line = new_line.replace("Else If ", "ElseIf ")
	if new_line.ends_with("Else If"):
		new_line = new_line.substr(0, new_line.length() - 7) + "ElseIf"
	
	# Only update the line if it actually changed (compare against original)
	if new_line != orig_line:
		# Save caret position — we're editing a line the caret is NOT on
		set_line(line_idx, new_line)

func _is_ident_char(ch: String) -> bool:
	var code: int = ch.unicode_at(0)
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122) \
		or (code >= 48 and code <= 57) or ch == "_"

# =============================================================================
# PROCEDURE SEPARATOR LINES
# =============================================================================

# Regex patterns for procedure boundaries
var _proc_separator_regex: RegEx = null

func _ready_separators() -> void:
	_proc_separator_regex = RegEx.new()
	# Match Sub, Function, Property declarations (with optional access modifier)
	_proc_separator_regex.compile("^\\s*(?:(?:Public|Private|Static)\\s+)?(?:Sub|Function|Property)\\s+")

func _draw() -> void:
	if _proc_separator_regex == null:
		_ready_separators()
	
	# Draw thin gray separator lines above each procedure declaration
	var first_visible: int = get_first_visible_line()
	var last_visible: int = first_visible + get_visible_line_count() + 1
	last_visible = mini(last_visible, get_line_count())
	
	var separator_color: Color = Color(0.35, 0.35, 0.4, 0.6)
	var line_width: float = 1.0
	
	for line_idx in range(first_visible, last_visible):
		var line_text: String = get_line(line_idx)
		if _proc_separator_regex.search(line_text):
			# Don't draw separator above the very first line
			if line_idx == 0:
				continue
			# Get the Y position for the top of this line
			var line_pos: Vector2i = get_line_column_at_pos(Vector2(0, 0))
			# Calculate Y offset relative to the editor viewport
			var row_height: float = get_line_height()
			var y_offset: float = (line_idx - first_visible) * row_height
			# Draw the separator line across the full width
			var from_x: float = get_total_gutter_width() if has_method("get_total_gutter_width") else 48.0
			var to_x: float = size.x
			draw_line(Vector2(from_x, y_offset), Vector2(to_x, y_offset), separator_color, line_width)

# =============================================================================
# BREAKPOINTS
# =============================================================================

## Breakpoint conditions: line_number → condition expression (empty = unconditional)
var _breakpoint_conditions: Dictionary = {}
## Conditional breakpoint dialog
var _bp_condition_dialog: AcceptDialog = null
var _bp_condition_input: LineEdit = null
var _bp_condition_line: int = -1

signal breakpoint_condition_set(line: int, condition: String)

func _on_breakpoint_toggled(line: int) -> void:
	# Emit for the debugger plugin to pick up
	if not is_line_breakpointed(line):
		# Breakpoint was removed — clean up condition
		_breakpoint_conditions.erase(line)

func toggle_breakpoint(line: int) -> void:
	set_line_as_breakpoint(line, not is_line_breakpointed(line))

func set_conditional_breakpoint(line: int) -> void:
	## Opens a dialog to set/edit a condition for a breakpoint on this line.
	## If no breakpoint exists, creates one first.
	if not is_line_breakpointed(line):
		set_line_as_breakpoint(line, true)
	
	if not _bp_condition_dialog:
		_bp_condition_dialog = AcceptDialog.new()
		_bp_condition_dialog.title = "Breakpoint Condition"
		_bp_condition_dialog.min_size = Vector2i(400, 120)
		var vb = VBoxContainer.new()
		var lbl = Label.new()
		lbl.text = "Break when this expression is True:"
		vb.add_child(lbl)
		_bp_condition_input = LineEdit.new()
		_bp_condition_input.placeholder_text = "e.g. counter > 10"
		vb.add_child(_bp_condition_input)
		_bp_condition_dialog.add_child(vb)
		_bp_condition_dialog.confirmed.connect(_on_bp_condition_confirmed)
		add_child(_bp_condition_dialog)
	
	_bp_condition_line = line
	_bp_condition_input.text = _breakpoint_conditions.get(line, "")
	_bp_condition_dialog.popup_centered()
	_bp_condition_input.grab_focus()

func _on_bp_condition_confirmed() -> void:
	if _bp_condition_line >= 0:
		var condition = _bp_condition_input.text.strip_edges()
		if condition.is_empty():
			_breakpoint_conditions.erase(_bp_condition_line)
		else:
			_breakpoint_conditions[_bp_condition_line] = condition
		breakpoint_condition_set.emit(_bp_condition_line, condition)

func get_breakpoint_condition(line: int) -> String:
	return _breakpoint_conditions.get(line, "")

func get_all_breakpoints() -> Dictionary:
	## Returns {line: condition} for all breakpoints. Unconditional = "".
	var result: Dictionary = {}
	for line in get_line_count():
		if is_line_breakpointed(line):
			result[line] = _breakpoint_conditions.get(line, "")
	return result
