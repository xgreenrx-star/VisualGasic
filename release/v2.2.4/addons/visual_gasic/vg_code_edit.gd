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

# Auto-indent settings
var _indent_triggers: Array[String] = [
	"Sub", "Function", "If", "For", "While", "Do", "Select Case",
	"Class", "Try", "Whenever", "With", "Property"
]
var _dedent_triggers: Array[String] = [
	"End Sub", "End Function", "End If", "Next", "Wend", "Loop",
	"End Select", "End Class", "End Try", "End Whenever", "End With",
	"End Property", "Else", "ElseIf", "Case", "Catch", "Finally"
]

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
	code_completion_prefixes = [".", " "]
	
	# Set up auto-complete delay (lower = faster response)
	# auto_brace_completion_enabled = true
	# auto_brace_completion_pairs = {
	# 	"(": ")",
	# 	"[": "]",
	# 	"\"": "\"",
	# }

func _setup_auto_indent() -> void:
	indent_automatic = true
	indent_size = 4
	indent_use_spaces = false  # VB6 traditionally uses tabs
	auto_brace_completion_enabled = true

func _connect_signals() -> void:
	text_changed.connect(_on_text_changed)
	code_completion_requested.connect(_on_code_completion_requested)

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
	
	# Regular completions
	var completions = VGIntelliSense.get_completions(word, context)
	
	for completion in completions:
		var kind = _convert_kind(completion.get("kind", "text"))
		var insert_text = completion.get("insert_text", completion["text"])
		
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
	
	# Get method completions
	var methods = VGIntelliSense.get_method_completions(obj_type)
	for method in methods:
		add_code_completion_option(
			CodeEdit.KIND_FUNCTION,
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
			CodeEdit.KIND_MEMBER,
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
# AUTO-INDENTATION
# =============================================================================

func _on_text_changed() -> void:
	_parse_variables()
	code_changed.emit(get_text())

func _input(event: InputEvent) -> void:
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
	for trigger in _indent_triggers:
		if prev_line.begins_with(trigger) or prev_line.ends_with(trigger):
			# Check it's not a single-line If
			if trigger == "If" and "Then" in prev_line and not prev_line.ends_with("Then"):
				continue
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
