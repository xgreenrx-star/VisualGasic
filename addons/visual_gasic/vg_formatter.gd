@tool
extends RefCounted
## VisualGasic Code Formatter
##
## Automatic code formatting for .vg files in VB6 style:
## - Auto-indent based on blocks (Sub/End Sub, If/End If, etc.)
## - Consistent spacing around operators
## - Keyword capitalization (configurable)
## - Blank line normalization
## - Format on save option
## - Format selection only

class_name VGFormatter

# =============================================================================
# CONFIGURATION
# =============================================================================

## Formatting options
class FormatOptions:
	## Indent size in spaces (0 = use tabs)
	var indent_size: int = 4
	## Use tabs instead of spaces
	var use_tabs: bool = true
	## Capitalize VB6 keywords
	var capitalize_keywords: bool = true
	## Add space around operators
	var space_around_operators: bool = true
	## Add space after commas
	var space_after_comma: bool = true
	## Max consecutive blank lines
	var max_blank_lines: int = 2
	## Remove trailing whitespace
	var trim_trailing_whitespace: bool = true
	## Ensure newline at end of file
	var ensure_final_newline: bool = true
	
	func to_dict() -> Dictionary:
		return {
			"indent_size": indent_size,
			"use_tabs": use_tabs,
			"capitalize_keywords": capitalize_keywords,
			"space_around_operators": space_around_operators,
			"space_after_comma": space_after_comma,
			"max_blank_lines": max_blank_lines,
			"trim_trailing_whitespace": trim_trailing_whitespace,
			"ensure_final_newline": ensure_final_newline
		}
	
	static func from_dict(data: Dictionary) -> FormatOptions:
		var opts = FormatOptions.new()
		opts.indent_size = data.get("indent_size", 4)
		opts.use_tabs = data.get("use_tabs", true)
		opts.capitalize_keywords = data.get("capitalize_keywords", true)
		opts.space_around_operators = data.get("space_around_operators", true)
		opts.space_after_comma = data.get("space_after_comma", true)
		opts.max_blank_lines = data.get("max_blank_lines", 2)
		opts.trim_trailing_whitespace = data.get("trim_trailing_whitespace", true)
		opts.ensure_final_newline = data.get("ensure_final_newline", true)
		return opts

# =============================================================================
# KEYWORD LISTS
# =============================================================================

const INDENT_KEYWORDS: Array[String] = [
	"Sub", "Function", "Property", "Class", "Type", "Enum",
	"If", "ElseIf", "Else", "For", "While", "Do", "Select Case", "Case",
	"Try", "Catch", "Finally", "With", "Whenever"
]

const DEDENT_KEYWORDS: Array[String] = [
	"End Sub", "End Function", "End Property", "End Class", "End Type", "End Enum",
	"End If", "Next", "Wend", "Loop", "End Select",
	"End Try", "End With", "End Whenever", "End Class"
]

const DEDENT_BEFORE_KEYWORDS: Array[String] = [
	"ElseIf", "Else", "Case", "Catch", "Finally"
]

const VB6_KEYWORDS_PROPER_CASE: Dictionary = {
	# Declaration
	"dim": "Dim", "global": "Global", "private": "Private", "public": "Public", "static": "Static",
	"const": "Const", "redim": "ReDim", "preserve": "Preserve",
	"as": "As", "new": "New", "set": "Set", "let": "Let", "get": "Get",
	"property": "Property", "type": "Type", "end type": "End Type", "enum": "Enum", "end enum": "End Enum",
	
	# Procedures
	"sub": "Sub", "function": "Function", "byval": "ByVal", "byref": "ByRef",
	"optional": "Optional", "paramarray": "ParamArray", "return": "Return", "call": "Call",
	"end sub": "End Sub", "end function": "End Function",
	"exit sub": "Exit Sub", "exit function": "Exit Function",
	
	# Control Flow
	"if": "If", "then": "Then", "else": "Else", "elseif": "ElseIf", "elif": "Elif", "end if": "End If",
	"select case": "Select Case", "select match": "Select Match", "case": "Case", "case else": "Case Else",
	"end select": "End Select",
	"for": "For", "to": "To", "step": "Step", "next": "Next",
	"for each": "For Each", "in": "In",
	"do": "Do", "loop": "Loop", "while": "While", "wend": "Wend", "until": "Until",
	"exit for": "Exit For", "exit do": "Exit Do", "exit while": "Exit While",
	"continue": "Continue", "pass": "Pass",
	"goto": "GoTo", "gosub": "GoSub", "on error": "On Error",
	"resume": "Resume", "resume next": "Resume Next",
	
	# OOP
	"class": "Class", "end class": "End Class", "me": "Me",
	"mybase": "MyBase", "myclass": "MyClass",
	"implements": "Implements", "interface": "Interface", "end interface": "End Interface",
	"inherits": "Inherits", "extends": "Extends",
	"withevents": "WithEvents", "raiseevent": "RaiseEvent",
	"event": "Event", "handles": "Handles",
	
	# Try/Catch
	"try": "Try", "catch": "Catch", "finally": "Finally", "end try": "End Try",
	"throw": "Throw",
	
	# Modern - Async/Parallel
	"async": "Async", "await": "Await", "task": "Task", "parallel": "Parallel",
	
	# Modern - Pattern Matching
	"match": "Match", "when": "When", "where": "Where",
	"typeof": "TypeOf", "hasvalue": "HasValue", "value": "Value",
	
	# Modern - Whenever/Reactive
	"whenever": "Whenever", "end whenever": "End Whenever",
	"section": "Section", "local": "Local",
	"changes": "Changes", "becomes": "Becomes", "exceeds": "Exceeds",
	"below": "Below", "between": "Between", "contains": "Contains",
	"suspend": "Suspend",
	
	# Modern - Other
	"with": "With", "end with": "End With",
	"using": "Using", "end using": "End Using",
	"yield": "Yield", "iterator": "Iterator",
	"lambda": "Lambda", "fn": "Fn", "of": "Of", "iif": "IIf",
	
	# Operators
	"and": "And", "or": "Or", "not": "Not", "xor": "Xor", "mod": "Mod",
	"is": "Is", "isnot": "IsNot", "like": "Like",
	"andalso": "AndAlso", "orelse": "OrElse",
	
	# Literals
	"true": "True", "false": "False", "nothing": "Nothing",
	"null": "Null", "empty": "Empty",
	
	# File Operations
	"open": "Open", "close": "Close", "input": "Input", "output": "Output",
	"append": "Append", "line": "Line",
	
	# Data/Other
	"data": "Data", "read": "Read", "restore": "Restore",
	"doevents": "DoEvents", "include": "Include",
	"dictionary": "Dictionary",
	
	# Options
	"option explicit": "Option Explicit", "option compare": "Option Compare",
	
	# Print
	"print": "Print", "debug.print": "Debug.Print",
}

# =============================================================================
# OPERATORS FOR SPACING
# =============================================================================

const OPERATORS: Array[String] = [
	"=", "<>", "<=", ">=", "<", ">",
	"+", "-", "*", "/", "\\", "^", "&",
]

# =============================================================================
# FORMATTING METHODS
# =============================================================================

## Formats an entire VG file
static func format_text(text: String, options: FormatOptions = null) -> String:
	if options == null:
		options = FormatOptions.new()
	
	var lines = text.split("\n")
	var result_lines: Array[String] = []
	var indent_level = 0
	var blank_count = 0
	
	for i in range(lines.size()):
		var line = lines[i]
		var stripped = line.strip_edges()
		
		# Handle blank lines
		if stripped.is_empty():
			blank_count += 1
			if blank_count <= options.max_blank_lines:
				result_lines.append("")
			continue
		
		blank_count = 0
		
		# Check for dedent before (ElseIf, Else, Case, Catch, Finally)
		var stripped_upper = stripped.to_upper()
		for keyword in DEDENT_BEFORE_KEYWORDS:
			if stripped_upper.begins_with(keyword.to_upper()):
				indent_level = maxi(0, indent_level - 1)
				break
		
		# Check for dedent (End statements)
		for keyword in DEDENT_KEYWORDS:
			if stripped_upper.begins_with(keyword.to_upper()):
				indent_level = maxi(0, indent_level - 1)
				break
		
		# Apply formatting to the line
		var formatted_line = _format_line(stripped, options)
		
		# Apply indentation
		var indent_str = "\t".repeat(indent_level) if options.use_tabs else " ".repeat(indent_level * options.indent_size)
		formatted_line = indent_str + formatted_line
		
		# Trim trailing whitespace
		if options.trim_trailing_whitespace:
			formatted_line = formatted_line.rstrip(" \t")
		
		result_lines.append(formatted_line)
		
		# Check for indent (Sub, If, For, etc.) - excluding single-line If
		for keyword in INDENT_KEYWORDS:
			var kw_upper = keyword.to_upper()
			if stripped_upper.begins_with(kw_upper):
				# Word boundary check: keyword must be the whole line,
				# or followed by a space/tab/paren — not part of an identifier
				var kw_len = kw_upper.length()
				if stripped_upper.length() > kw_len:
					var next_char = stripped_upper[kw_len]
					if next_char != " " and next_char != "\t" and next_char != "(":
						continue
				# Special case: single-line If (If x Then y)
				if keyword == "If" and "THEN" in stripped_upper:
					var after_then = stripped_upper.split("THEN", true, 1)
					if after_then.size() > 1 and not after_then[1].strip_edges().is_empty():
						# Single-line If, don't indent
						break
				indent_level += 1
				break
	
	var result = "\n".join(result_lines)
	
	# Ensure final newline
	if options.ensure_final_newline and not result.ends_with("\n"):
		result += "\n"
	
	return result

## Formats a single line
static func _format_line(line: String, options: FormatOptions) -> String:
	var result = line
	
	# Skip comments
	var comment_pos = _find_comment_start(result)
	var code_part = result.substr(0, comment_pos) if comment_pos >= 0 else result
	var comment_part = result.substr(comment_pos) if comment_pos >= 0 else ""
	
	# Capitalize keywords
	if options.capitalize_keywords:
		code_part = _capitalize_keywords(code_part)
	
	# Auto-replace Lambda(...) => with Function(...) for consistency
	code_part = _normalize_lambda_syntax(code_part)
	
	# Add spacing around operators
	if options.space_around_operators:
		code_part = _space_operators(code_part)
	
	# Add space after commas
	if options.space_after_comma:
		code_part = _space_commas(code_part)
	
	return code_part + comment_part

## Normalizes lambda syntax: Lambda/Fn(...) => expr → Function(...) expr
static func _normalize_lambda_syntax(line: String) -> String:
	var result = line
	# Replace Lambda(...) => with Function(...)
	var regex = RegEx.new()
	regex.compile("(?i)\\b(Lambda|Fn)\\s*(\\([^)]*\\))\\s*=>")
	var m = regex.search(result)
	while m:
		var start = m.get_start()
		if not _is_in_string(result, start):
			var params = m.get_string(2)
			var replacement = "Function" + params
			result = result.substr(0, start) + replacement + result.substr(m.get_end())
			m = regex.search(result, start + replacement.length())
		else:
			m = regex.search(result, m.get_end())
	
	# Also replace Lambda/Fn without arrow: Lambda(x) expr → Function(x) expr
	var regex2 = RegEx.new()
	regex2.compile("(?i)\\b(Lambda|Fn)\\s*(\\([^)]*\\))")
	var m2 = regex2.search(result)
	while m2:
		var start = m2.get_start()
		if not _is_in_string(result, start):
			var params = m2.get_string(2)
			var replacement = "Function" + params
			result = result.substr(0, start) + replacement + result.substr(m2.get_end())
			m2 = regex2.search(result, start + replacement.length())
		else:
			m2 = regex2.search(result, m2.get_end())
	
	return result

## Finds the start of a comment ('), considering string literals
static func _find_comment_start(line: String) -> int:
	var in_string = false
	for i in range(line.length()):
		var c = line[i]
		if c == '"':
			in_string = not in_string
		elif c == "'" and not in_string:
			return i
	return -1

## Capitalizes VB6 keywords in proper case
static func _capitalize_keywords(line: String) -> String:
	var result = line
	
	# Sort keywords by length (longest first) to avoid partial replacements
	var keywords_sorted: Array[String] = []
	for key in VB6_KEYWORDS_PROPER_CASE:
		keywords_sorted.append(key)
	keywords_sorted.sort_custom(func(a, b): return a.length() > b.length())
	
	for keyword in keywords_sorted:
		var proper = VB6_KEYWORDS_PROPER_CASE[keyword]
		var regex = RegEx.new()
		regex.compile("(?i)(?<![A-Za-z0-9_])" + keyword.replace(" ", "\\s+") + "(?![A-Za-z0-9_])")
		
		var regex_match = regex.search(result)
		while regex_match:
			var start = regex_match.get_start()
			var end = regex_match.get_end()
			
			# Don't replace inside strings
			if not _is_in_string(result, start):
				result = result.substr(0, start) + proper + result.substr(end)
			
			regex_match = regex.search(result, start + proper.length())
	
	return result

## Checks if a position is inside a string literal
static func _is_in_string(line: String, pos: int) -> bool:
	var in_string = false
	for i in range(mini(pos, line.length())):
		if line[i] == '"':
			in_string = not in_string
	return in_string

## Adds spaces around operators
static func _space_operators(line: String) -> String:
	var result = line
	
	# Handle multi-character operators first
	result = _space_operator(result, "<>")
	result = _space_operator(result, "<=")
	result = _space_operator(result, ">=")
	
	# Single character operators (be careful with context)
	result = _space_operator(result, "=")
	result = _space_operator(result, "<")
	result = _space_operator(result, ">")
	result = _space_operator(result, "+")
	result = _space_operator(result, "-")
	result = _space_operator(result, "*")
	result = _space_operator(result, "/")
	result = _space_operator(result, "&")
	
	# Clean up any double spaces
	while "  " in result:
		result = result.replace("  ", " ")
	
	return result

## Adds space around a specific operator
static func _space_operator(line: String, op: String) -> String:
	var result = ""
	var i = 0
	
	while i < line.length():
		# Check if we're at this operator
		if i + op.length() <= line.length() and line.substr(i, op.length()) == op:
			# Don't modify if inside a string
			if _is_in_string(line, i):
				result += op
				i += op.length()
				continue
			
			# Don't add space before if already has space
			if not result.is_empty() and not result.ends_with(" "):
				result += " "
			
			result += op
			
			# Don't add space after if already has space or at end
			if i + op.length() < line.length() and line[i + op.length()] != " ":
				result += " "
			
			i += op.length()
		else:
			result += line[i]
			i += 1
	
	return result

## Adds space after commas
static func _space_commas(line: String) -> String:
	var result = ""
	
	for i in range(line.length()):
		result += line[i]
		if line[i] == "," and not _is_in_string(line, i):
			if i + 1 < line.length() and line[i + 1] != " ":
				result += " "
	
	return result

## Formats only a selection of lines
static func format_selection(text: String, start_line: int, end_line: int, options: FormatOptions = null) -> String:
	if options == null:
		options = FormatOptions.new()
	
	var lines = text.split("\n")
	
	# Format only the selected lines
	var selected_text = "\n".join(lines.slice(start_line, end_line + 1))
	var formatted = format_text(selected_text, options)
	
	# Reconstruct the full text
	var result_lines: Array[String] = []
	for i in range(lines.size()):
		if i < start_line or i > end_line:
			result_lines.append(lines[i])
		elif i == start_line:
			# Insert all formatted lines
			var formatted_lines = formatted.split("\n")
			for fl in formatted_lines:
				result_lines.append(fl)
	
	return "\n".join(result_lines)

## Loads format options from a .vgformat file
static func load_options(path: String) -> FormatOptions:
	var options = FormatOptions.new()
	
	if not FileAccess.file_exists(path):
		return options
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return options
	
	var content = file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(content)
	if parsed is Dictionary:
		return FormatOptions.from_dict(parsed)
	
	return options

## Saves format options to a .vgformat file
static func save_options(path: String, options: FormatOptions) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(options.to_dict(), "\t"))
		file.close()
