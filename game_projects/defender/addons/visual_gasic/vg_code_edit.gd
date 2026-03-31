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
signal set_next_statement_requested(line: int)  ## Emitted when user drags the yellow arrow
signal run_to_cursor_requested(line: int)       ## Emitted for Run to Cursor (Ctrl+F10)
signal tracepoint_set(line: int, message: String) ## Emitted when user sets/changes a tracepoint log message
signal edit_and_continue_requested()             ## Emitted for Edit & Continue (Ctrl+Shift+Enter)
signal pin_inline_value_requested(line: int, variable: String) ## Emitted when user pins an inline value
signal bookmark_toggled(line: int, enabled: bool)              ## Emitted when user toggles a bookmark

# =============================================================================
# VARIABLES
# =============================================================================

var _intellisense: VGIntelliSense
var _known_controls: Array[String] = []
var _known_variables: Array[String] = []
var _control_info_list: Array[Dictionary] = []  ## Full control info from form designer (name, type, rect, etc.)
var _variable_types: Dictionary = {}             ## Variable name → declared type (from Dim x As Type)
var _known_enums: Dictionary = {}                ## Enum name → Array[String] of member names
var _known_udts: Dictionary = {}                 ## Type name → Array[Dictionary] of {name, type} fields
var _known_functions: Dictionary = {}            ## Function name (lower) → return type (String)
var _imported_modules: Array[Dictionary] = []    ## [{name, path, subs, variables, constants}]
var _form_name: String = ""                       ## Current form name (e.g. "Form1") — treated like Me
var _completion_active: bool = false
var _last_word: String = ""
var _prev_caret_line: int = -1  # Track line changes for auto-capitalize
var _snippet_regex: RegEx = null  # Lazy-init for snippet placeholder expansion
var _prev_line_count: int = 0    # Track line count for auto-indent on real Enter

# VB6-style yellow arrow (Set Next Statement) state
var _executing_line: int = -1         # Current executing line (0-based), -1 = none
var _is_debug_paused: bool = false    # Whether the debugger is currently paused
var _arrow_dragging: bool = false     # True while user is dragging the yellow arrow
var _arrow_drag_line: int = -1        # Line being dragged to (0-based)
var _arrow_hover: bool = false        # True when mouse is over the arrow gutter area
var _arrow_overlay: Control = null    # Overlay drawn ON TOP of CodeEdit for the arrow

# Data Tips — hover-to-inspect variables during debugging
var _data_tips_ref = null              # Reference to VGDataTips (set by plugin)

# Tracepoints (log points) — breakpoints that log instead of pausing
var _tracepoints: Dictionary = {}     # line_number → log message string
var _tp_dialog: AcceptDialog = null
var _tp_input: LineEdit = null
var _tp_line: int = -1

# Pinned Inline Values — show live variable values next to code lines
var _pinned_values: Dictionary = {}   # line_number(0-based) → variable_name
var _pinned_data: Dictionary = {}     # variable_name → last known value (String)
var _pin_overlay: Control = null      # Overlay drawn ON TOP of CodeEdit for pins

# Bookmarks — VB6-style code bookmarks (Ctrl+B to toggle)
var _bookmarks: Dictionary = {}       # line_number(0-based) → true
var _bookmark_overlay: Control = null  # Overlay drawn in gutter for bookmark icons

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

var _context_menu: PopupMenu

func _ready() -> void:
	_setup_syntax_highlighter()
	_setup_code_completion()
	_setup_auto_indent()
	_setup_context_menu()
	_connect_signals()
	_prev_line_count = get_line_count()

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
	
	# Built-in constants (magenta-pink — distinct from variables, keywords, and functions)
	for const_info in VGIntelliSense.VB6_CONSTANTS:
		highlighter.add_keyword_color(const_info["name"], Color(0.85, 0.55, 0.85))
	
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
	# Explicit pairs — omit "\"": "\"" to prevent completions being wrapped in quotes
	auto_brace_completion_pairs = {
		"(": ")",
		"[": "]",
	}
	
	# ── Fix VB6 delimiter semantics ──
	# Godot's CodeEdit constructor registers both " and ' as *string* delimiters.
	# In VB6, ' is a *comment* prefix, NOT a string delimiter.  Leaving the
	# default causes is_in_string() to return true after any ' comment, which
	# confuses the code-completion filter and can wrap completions in quotes.
	clear_string_delimiters()
	clear_comment_delimiters()
	add_string_delimiter("\"", "\"", false)   # "..." = string literal
	add_comment_delimiter("'", "", true)       # '    = line comment
	
	# Enable line numbers in the gutter
	gutters_draw_line_numbers = true
	
	# Enable code folding (indent-based) — property names vary by Godot version
	set("line_folding_enabled", true)
	set("gutters_draw_folding", true)
	
	# Enable built-in breakpoint gutter (VB6 F9 behavior)
	gutters_draw_breakpoints_gutter = true
	
	# Disable built-in executing line gutter — we draw our own yellow arrow overlay
	gutters_draw_executing_lines = false

## IDs for the right-click context menu items.
enum ContextMenuItem {
	CUT,
	COPY,
	PASTE,
	SELECT_ALL,
	FIX_INDENTATION,
	COMMENT_TOGGLE,
	GOTO_LINE,
	TOGGLE_BREAKPOINT,
	TOGGLE_BOOKMARK,
}

func _setup_context_menu() -> void:
	_context_menu = PopupMenu.new()
	_context_menu.name = "VGContextMenu"
	_context_menu.add_item("Cut                     Ctrl+X", ContextMenuItem.CUT)
	_context_menu.add_item("Copy                    Ctrl+C", ContextMenuItem.COPY)
	_context_menu.add_item("Paste                   Ctrl+V", ContextMenuItem.PASTE)
	_context_menu.add_separator()
	_context_menu.add_item("Select All              Ctrl+A", ContextMenuItem.SELECT_ALL)
	_context_menu.add_separator()
	_context_menu.add_item("Fix Indentation       Ctrl+Shift+I", ContextMenuItem.FIX_INDENTATION)
	_context_menu.add_item("Comment/Uncomment     Ctrl+'", ContextMenuItem.COMMENT_TOGGLE)
	_context_menu.add_separator()
	_context_menu.add_item("Go To Line...           Ctrl+G", ContextMenuItem.GOTO_LINE)
	_context_menu.add_item("Toggle Breakpoint       F9", ContextMenuItem.TOGGLE_BREAKPOINT)
	_context_menu.add_item("Toggle Bookmark         Ctrl+B", ContextMenuItem.TOGGLE_BOOKMARK)
	_context_menu.id_pressed.connect(_on_context_menu_item)
	add_child(_context_menu)

func _on_context_menu_item(id: int) -> void:
	match id:
		ContextMenuItem.CUT:
			cut()
		ContextMenuItem.COPY:
			copy()
		ContextMenuItem.PASTE:
			paste()
		ContextMenuItem.SELECT_ALL:
			select_all()
		ContextMenuItem.FIX_INDENTATION:
			fix_indentation()
		ContextMenuItem.COMMENT_TOGGLE:
			toggle_comment_selection()
		ContextMenuItem.GOTO_LINE:
			_show_goto_line_dialog()
		ContextMenuItem.TOGGLE_BREAKPOINT:
			toggle_breakpoint(get_caret_line())
		ContextMenuItem.TOGGLE_BOOKMARK:
			toggle_bookmark(get_caret_line())

func _show_context_menu(at_position: Vector2) -> void:
	# Enable/disable items based on context
	var sel_active := has_selection()
	_context_menu.set_item_disabled(_context_menu.get_item_index(ContextMenuItem.CUT), not sel_active)
	_context_menu.set_item_disabled(_context_menu.get_item_index(ContextMenuItem.COPY), not sel_active)
	_context_menu.position = Vector2i(global_position + at_position)
	_context_menu.popup()

# =============================================================================
# FIX INDENTATION — VB6-aware whole-document re-indenter
# =============================================================================

## Re-indent the entire document (or selection) according to VB6 block structure.
## Walks each line, tracking indent depth by recognising block openers/closers.
func fix_indentation() -> void:
	var from_line := 0
	var to_line := get_line_count() - 1
	
	# If there is a selection, only reindent the selected lines
	if has_selection():
		from_line = get_selection_from_line()
		to_line = get_selection_to_line()
	
	begin_complex_operation()
	
	var indent_level := 0
	
	# If reindenting a partial selection, start with the indent of the line
	# before the selection so nested blocks stay correct
	if from_line > 0:
		indent_level = _get_line_indent(from_line - 1)
		var prev_stripped := get_line(from_line - 1).strip_edges()
		if _is_indent_opener(prev_stripped):
			indent_level += 1
	
	for i in range(from_line, to_line + 1):
		var raw_line := get_line(i)
		var stripped := raw_line.strip_edges()
		
		# Skip completely blank lines — don't add whitespace
		if stripped.is_empty():
			if raw_line != "":
				_set_line_indent_raw(i, "")
			continue
		
		# Check if this line is a dedent trigger (closer or mid-block keyword)
		var is_closer := _is_indent_closer(stripped)
		var is_mid_block := _is_mid_block_keyword(stripped)
		
		# Dedent BEFORE writing this line for closers/mid-block
		if is_closer or is_mid_block:
			indent_level = maxi(0, indent_level - 1)
		
		# Apply indent
		_set_line_indent(i, indent_level)
		
		# Re-indent AFTER for mid-block keywords (Else, Case, etc.)
		if is_mid_block:
			indent_level += 1
		
		# If this line opens a block, increase indent for following lines
		if _is_indent_opener(stripped):
			indent_level += 1
	
	end_complex_operation()

## Returns true if `stripped_line` opens a new indentation block.
## Handles: Sub, Function, Property, For, While, Do, Select Case, With, Try,
## Whenever, Class, Type, Enum, If...Then (multi-line).
func _is_indent_opener(stripped_line: String) -> bool:
	# First check multi-line If...Then (line begins with If, ends with Then)
	var sl := stripped_line.to_lower()
	if sl.begins_with("if ") and sl.ends_with(" then"):
		return true
	# Use existing _line_starts_block (handles access modifiers)
	return _line_starts_block(stripped_line)

## Returns true if `stripped_line` is a block closer that should decrease indent.
func _is_indent_closer(stripped_line: String) -> bool:
	var sl := stripped_line.to_lower()
	for trigger in ["end sub", "end function", "end if", "next", "wend", "loop",
					 "end select", "end class", "end try", "end whenever",
					 "end with", "end property", "end type", "end enum"]:
		if sl == trigger or sl.begins_with(trigger + " "):
			return true
	return false

## Returns true if `stripped_line` is a mid-block keyword (Else, ElseIf, Case, Catch, Finally).
## These lines dedent to match the parent, then re-indent for the following block.
func _is_mid_block_keyword(stripped_line: String) -> bool:
	var sl := stripped_line.to_lower()
	if sl == "else":
		return true
	if sl.begins_with("elseif "):
		return true
	if sl.begins_with("case ") or sl == "case else":
		return true
	if sl == "catch" or sl.begins_with("catch "):
		return true
	if sl == "finally":
		return true
	return false

## Low-level: replace a line's leading whitespace with an exact string.
func _set_line_indent_raw(line_idx: int, indent_str: String) -> void:
	var line := get_line(line_idx)
	# Find first non-whitespace character
	var first_non_ws := 0
	for c in line:
		if c == "\t" or c == " ":
			first_non_ws += 1
		else:
			break
	var content := line.substr(first_non_ws)
	var new_line := indent_str + content
	if new_line != line:
		select(line_idx, 0, line_idx, line.length())
		insert_text_at_caret(new_line)

# =============================================================================
# TOGGLE COMMENT — VB6 ' prefix
# =============================================================================

## Toggle line comments (' prefix) on the current line or selected lines.
func toggle_comment_selection() -> void:
	var from_line := get_caret_line()
	var to_line := from_line
	
	if has_selection():
		from_line = get_selection_from_line()
		to_line = get_selection_to_line()
	
	begin_complex_operation()
	
	# Determine whether to comment or uncomment: if ALL lines are commented, uncomment.
	var all_commented := true
	for i in range(from_line, to_line + 1):
		var stripped := get_line(i).strip_edges()
		if stripped.is_empty():
			continue
		if not stripped.begins_with("'"):
			all_commented = false
			break
	
	for i in range(from_line, to_line + 1):
		var line := get_line(i)
		if all_commented:
			# Uncomment: remove first ' (and optional trailing space)
			var idx := line.find("'")
			if idx >= 0:
				var remove_len := 1
				if idx + 1 < line.length() and line[idx + 1] == " ":
					remove_len = 2
				var new_line := line.substr(0, idx) + line.substr(idx + remove_len)
				select(i, 0, i, line.length())
				insert_text_at_caret(new_line)
		else:
			# Comment: insert ' after leading whitespace
			var indent_end := 0
			for c in line:
				if c == "\t" or c == " ":
					indent_end += 1
				else:
					break
			if line.strip_edges().is_empty():
				continue  # skip blank lines
			var new_line := line.substr(0, indent_end) + "' " + line.substr(indent_end)
			select(i, 0, i, line.length())
			insert_text_at_caret(new_line)
	
	end_complex_operation()

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
	if "." in before_cursor and _is_dot_in_current_expr(before_cursor):
		# ── With block context: bare .Property inside With...End With ──
		# If the text before cursor is just a dot or starts with a dot-chain
		# (e.g. ".Text1."), resolve the enclosing With object.
		var stripped_bc := before_cursor.strip_edges()
		if stripped_bc == "." or stripped_bc.begins_with("."):
			var _bc_no_ws := before_cursor.lstrip(" \t")
			if _bc_no_ws.begins_with("."):
				var with_type := _resolve_with_context()
				if not with_type.is_empty():
					# Count dots to determine depth: bare "." → 1st level,
					# ".Text1." → chained resolution needed
					var dot_expr := _bc_no_ws.substr(1)  # Strip leading dot
					if dot_expr.is_empty() or not "." in dot_expr:
						# Simple bare .  or  .partial — show With object members
						_show_member_completions_for_type(with_type)
						return
					else:
						# Chained: .Text1.  → resolve With_type.Text1
						# Strip trailing dot and split the chain
						if dot_expr.ends_with("."):
							dot_expr = dot_expr.substr(0, dot_expr.length() - 1)
						var chain_parts := dot_expr.split(".")
						# Walk from with_type through each member
						var cur_type := with_type
						for part in chain_parts:
							if part.is_empty():
								continue
							var member_clean := part
							if "(" in member_clean:
								member_clean = member_clean.get_slice("(", 0).strip_edges()
							if cur_type == "Form" and member_clean in _known_controls:
								cur_type = _get_control_type(member_clean)
							else:
								var resolved := VGIntelliSense.resolve_member_type(cur_type, member_clean)
								if resolved.is_empty() or resolved == "void":
									cur_type = "Variant"
									break
								cur_type = resolved
						_show_member_completions_for_type(cur_type)
						return
		# Extract the dot-chain expression before cursor.
		# e.g. "  Me.Text1." → ["Me", "Text1"]
		#      "  x = obj.Method." → ["obj", "Method"]
		#      "  Text1." → ["Text1"]
		var parts = before_cursor.rsplit(".", true, 1)
		if parts.size() > 0:
			# Get the full expression before the last dot
			# Note: get_slice() doesn't support negative indices, use split()[-1]
			var stripped_lhs := parts[0].strip_edges()
			var expr := stripped_lhs.split(" ")[-1] if " " in stripped_lhs else stripped_lhs
			# Also strip away any leading = or ( for cases like "x = obj."
			for strip_char in ["=", "(", ",", "+", "-", "*", "/", "&"]:
				if strip_char in expr:
					expr = expr.rsplit(strip_char, true, 1)[-1].strip_edges()
			
			# ── Array element dot: arr(0). or col(key). ──
			# If expr ends with ), extract the base and resolve element type
			if expr.ends_with(")"):
				var paren_pos := expr.rfind("(")
				if paren_pos > 0:
					var arr_name := expr.substr(0, paren_pos).strip_edges()
					# Strip leading operators from arr_name too
					for sc in ["=", "(", ",", "+", "-", "*", "/", "&"]:
						if sc in arr_name:
							arr_name = arr_name.rsplit(sc, true, 1)[-1].strip_edges()
					var elem_type := _infer_array_element_type(arr_name)
					if not elem_type.is_empty() and elem_type != "Variant" and elem_type != "Object":
						_show_member_completions_for_type(elem_type)
						return
			
			# ── Function return type dot: GetName(). ──
			# If expr ends with ) and is a known function, resolve its return type
			if expr.ends_with(")"):
				var paren_pos := expr.rfind("(")
				if paren_pos > 0:
					var func_name := expr.substr(0, paren_pos).strip_edges()
					for sc in ["=", "(", ",", "+", "-"]:
						if sc in func_name:
							func_name = func_name.rsplit(sc, true, 1)[-1].strip_edges()
					var ret_type := _get_function_return_type(func_name)
					if not ret_type.is_empty() and ret_type != "Variant":
						_show_member_completions_for_type(ret_type)
						return
			
			# Handle chained dots: Me.Text1. → resolve Me → get Text1's type
			if "." in expr:
				var chain := expr.split(".")
				var resolved_type := _resolve_dot_chain(chain)
				_show_member_completions_for_type(resolved_type)
			elif not expr.is_empty():
				_show_member_completions(expr)
			else:
				# Empty expr after stripping operators — could be With context
				# e.g. "x = .Text" or "If .Visible Then" inside a With block
				var with_type := _resolve_with_context()
				if not with_type.is_empty():
					_show_member_completions_for_type(with_type)
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
	
	# ── GoTo / GoSub label completion ──
	# If the text before cursor ends with  GoTo <partial>  or  GoSub <partial>,
	# offer only labels defined in the current script.
	var _goto_re := RegEx.new()
	_goto_re.compile("(?i)\\b(goto|gosub)\\s+(\\w*)$")
	var goto_match := _goto_re.search(before_cursor)
	if goto_match:
		var label_prefix := goto_match.get_string(2).to_lower()
		var labels := _scan_labels()
		# Collect labels that match the typed prefix
		var matching_labels: Array[String] = []
		for lbl in labels:
			if label_prefix.is_empty() or lbl.to_lower().begins_with(label_prefix):
				matching_labels.append(lbl)
		# If the only match is an exact match for what's already typed the
		# user has finished the label — don't re-pop the completion list
		# (otherwise Enter / Tab get swallowed by the popup forever).
		var already_complete := false
		if not label_prefix.is_empty() and matching_labels.size() == 1 \
				and matching_labels[0].to_lower() == label_prefix:
			already_complete = true
		if not already_complete and not matching_labels.is_empty():
			for lbl in matching_labels:
				add_code_completion_option(
					CodeEdit.KIND_PLAIN_TEXT,
					lbl + "  (Label)",
					lbl,
					Color(1.0, 0.85, 0.4),  # gold tint for labels
					null, null, 0
				)
			update_code_completion_options(true)
			return
		# Already complete or no labels — fall through to regular completions
		# so the user still gets keyword / variable suggestions.
	
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
	# ── 1. VB6 Global Objects: App., Screen., Clipboard., Err., Debug., Printer. ──
	var global_members := VGIntelliSense.get_global_object_members(obj_name)
	if not global_members.is_empty():
		for member in global_members:
			add_code_completion_option(
				_convert_kind(member.get("kind", "method")),
				member["text"],
				member["text"],
				Color(0.9, 0.85, 0.6),  # gold tint for global objects
				null, null, 0
			)
		update_code_completion_options(true)
		return
	
	# ── 2. Enum members: MyEnum. → show enum values ──
	if _known_enums.has(obj_name):
		var members: Array = _known_enums[obj_name]
		for member_name in members:
			add_code_completion_option(
				CodeEdit.KIND_CONSTANT,
				member_name,
				member_name,
				Color(0.7, 0.9, 0.7),  # green tint for enum members
				null, null, 0
			)
		update_code_completion_options(true)
		return
	
	# ── 2b. UDT/Type members: Dim p As Player → p. shows x, y, score ──
	var udt_type := _variable_types.get(obj_name.to_lower(), "")
	if not udt_type.is_empty() and _known_udts.has(udt_type):
		var udt_fields: Array = _known_udts[udt_type]
		for field in udt_fields:
			add_code_completion_option(
				CodeEdit.KIND_MEMBER,
				field["name"],
				field["name"],
				Color(0.7, 0.85, 1.0),  # light blue for UDT fields
				null, null, 0
			)
		update_code_completion_options(true)
		return
	# Also check if obj_name itself is a UDT type name (static member access)
	if _known_udts.has(obj_name):
		var udt_fields: Array = _known_udts[obj_name]
		for field in udt_fields:
			add_code_completion_option(
				CodeEdit.KIND_MEMBER,
				field["name"],
				field["name"],
				Color(0.7, 0.85, 1.0),
				null, null, 0
			)
		update_code_completion_options(true)
		return
	
	# ── 2c. Module dot-completion: Module1. → show public subs/vars/consts ──
	for mod_info in _imported_modules:
		if mod_info.get("name", "").nocasecmp_to(obj_name) == 0:
			# Subs/Functions
			if mod_info.has("subs"):
				for sub_name in mod_info["subs"]:
					add_code_completion_option(
						CodeEdit.KIND_FUNCTION,
						sub_name,
						sub_name,
						Color(0.6, 0.9, 0.6),  # green for module functions
						null, null, 0
					)
			# Variables
			if mod_info.has("variables"):
				for var_name in mod_info["variables"]:
					add_code_completion_option(
						CodeEdit.KIND_VARIABLE,
						var_name,
						var_name,
						Color(0.8, 0.8, 0.6),  # warm for module variables
						null, null, 0
					)
			# Constants
			if mod_info.has("constants"):
				for const_name in mod_info["constants"]:
					add_code_completion_option(
						CodeEdit.KIND_CONSTANT,
						const_name,
						const_name,
						Color(0.9, 0.7, 0.5),  # orange for constants
						null, null, 0
					)
			update_code_completion_options(true)
			return
	
	# ── 3. Me. / Form. / Form1. — show form controls + form-level properties/methods ──
	var _is_form_ref := (obj_name.nocasecmp_to("Me") == 0
		or obj_name.nocasecmp_to("Form") == 0
		or (not _form_name.is_empty() and obj_name.nocasecmp_to(_form_name) == 0))
	if _is_form_ref:
		# Form's own controls
		for ctrl_name in _known_controls:
			var ctrl_type := _get_control_type(ctrl_name)
			add_code_completion_option(
				CodeEdit.KIND_MEMBER,
				ctrl_name,
				ctrl_name,
				Color(0.6, 0.9, 1.0),  # cyan tint for controls
				null, null, 0
			)
		# Form-level members (Caption, Width, Height, Show, Hide, etc.)
		for member in VGIntelliSense.get_form_members():
			add_code_completion_option(
				_convert_kind(member.get("kind", "property")),
				member["text"],
				member["text"],
				Color(0.85, 0.85, 1.0),  # light blue for form members
				null, null, 0
			)
		update_code_completion_options(true)
		return
	
	# ── 3. Resolve the object's type ──
	var obj_type := _infer_type(obj_name)
	
	# ── 5. VB6 String members ──
	if obj_type == "String":
		for member in VGIntelliSense.get_string_members():
			add_code_completion_option(
				_convert_kind(member.get("kind", "method")),
				member["text"],
				member["text"],
				Color(0.9, 0.8, 0.5),
				null, null, 0
			)
		update_code_completion_options(true)
		return
	
	# ── 6. VB6 Collection / Dictionary members ──
	if obj_type == "Collection":
		for member in VGIntelliSense.get_collection_members():
			add_code_completion_option(
				_convert_kind(member.get("kind", "method")),
				member["text"],
				member["text"],
				Color(0.9, 0.8, 0.5),
				null, null, 0
			)
		update_code_completion_options(true)
		return
	if obj_type == "Dictionary":
		for member in VGIntelliSense.get_dictionary_members():
			add_code_completion_option(
				_convert_kind(member.get("kind", "method")),
				member["text"],
				member["text"],
				Color(0.9, 0.8, 0.5),
				null, null, 0
			)
		update_code_completion_options(true)
		return
	
	# ── 7. Resolve VB6 control type → Godot class for ClassDB lookup ──
	var godot_type := VGIntelliSense.resolve_control_type(obj_type)
	
	# ── 8. VB6-friendly property aliases (Caption, Value, Text, etc.) ──
	# Show these first so VB6 users see familiar names at the top.
	var vb6_aliases := VGIntelliSense.get_vb6_property_aliases(godot_type)
	for alias in vb6_aliases:
		add_code_completion_option(
			_convert_kind(alias.get("kind", "property")),
			alias["text"],
			alias["text"],
			Color(1.0, 0.95, 0.7),  # warm yellow for VB6 aliases
			null, null, 0
		)
	
	# ── 9. ClassDB / Variant methods + properties ──
	var methods := VGIntelliSense.get_method_completions(godot_type)
	for method in methods:
		add_code_completion_option(
			_convert_kind(method.get("kind", "method")),
			method["text"],
			method["text"],
			Color.WHITE,
			null, null, 0
		)
	
	var properties := VGIntelliSense.get_property_completions(godot_type)
	for prop in properties:
		add_code_completion_option(
			_convert_kind(prop.get("kind", "property")),
			prop["text"],
			prop["text"],
			Color.WHITE,
			null, null, 0
		)
	
	update_code_completion_options(true)

## Shows member completions for an already-resolved type name (used for chained dots).
func _show_member_completions_for_type(type_name: String) -> void:
	# UDT/Type members: if the type is a known UDT, show its fields
	if _known_udts.has(type_name):
		var udt_fields: Array = _known_udts[type_name]
		for field in udt_fields:
			add_code_completion_option(
				CodeEdit.KIND_MEMBER,
				field["name"], field["name"],
				Color(0.7, 0.85, 1.0), null, null, 0)
		update_code_completion_options(true)
		return
	# String type
	if type_name == "String":
		for member in VGIntelliSense.get_string_members():
			add_code_completion_option(
				_convert_kind(member.get("kind", "method")),
				member["text"], member["text"],
				Color(0.9, 0.8, 0.5), null, null, 0)
		update_code_completion_options(true)
		return
	# Collection / Dictionary
	if type_name == "Collection":
		for member in VGIntelliSense.get_collection_members():
			add_code_completion_option(
				_convert_kind(member.get("kind", "method")),
				member["text"], member["text"],
				Color(0.9, 0.8, 0.5), null, null, 0)
		update_code_completion_options(true)
		return
	if type_name == "Dictionary":
		for member in VGIntelliSense.get_dictionary_members():
			add_code_completion_option(
				_convert_kind(member.get("kind", "method")),
				member["text"], member["text"],
				Color(0.9, 0.8, 0.5), null, null, 0)
		update_code_completion_options(true)
		return
	# Global objects (App, Screen, Clipboard, Err, Debug, Printer)
	if type_name.begins_with("GlobalObject:"):
		var obj_name := type_name.substr(len("GlobalObject:"))
		for member in VGIntelliSense.get_global_object_members(obj_name):
			add_code_completion_option(
				_convert_kind(member.get("kind", "property")),
				member["text"], member["text"],
				Color(0.95, 0.85, 0.6), null, null, 0)
		update_code_completion_options(true)
		return
	# Resolve to Godot type
	var godot_type := VGIntelliSense.resolve_control_type(type_name)
	# VB6 aliases first
	var vb6_aliases := VGIntelliSense.get_vb6_property_aliases(godot_type)
	for alias in vb6_aliases:
		add_code_completion_option(
			_convert_kind(alias.get("kind", "property")),
			alias["text"], alias["text"],
			Color(1.0, 0.95, 0.7), null, null, 0)
	# ClassDB / Variant methods + properties
	for method in VGIntelliSense.get_method_completions(godot_type):
		add_code_completion_option(
			_convert_kind(method.get("kind", "method")),
			method["text"], method["text"],
			Color.WHITE, null, null, 0)
	for prop in VGIntelliSense.get_property_completions(godot_type):
		add_code_completion_option(
			_convert_kind(prop.get("kind", "property")),
			prop["text"], prop["text"],
			Color.WHITE, null, null, 0)
	update_code_completion_options(true)

## Resolves a chained dot expression like ["Me", "Text1"] to a final type.
## Me.Text1. → resolve "Me" finds "Text1" is a control → return its Godot type.
func _resolve_dot_chain(chain: Array) -> String:
	if chain.is_empty():
		return "Object"
	
	# Start with the first element
	var current_name: String = chain[0]
	var current_type := ""
	
	# Strip parentheses from first element too (e.g. GetName().ToUpper.)
	var first_clean := current_name
	var first_had_parens := false
	if "(" in first_clean:
		first_clean = first_clean.get_slice("(", 0).strip_edges()
		first_had_parens = true
	
	# Is first element Me/Form/Form1?
	if (first_clean.nocasecmp_to("Me") == 0
		or first_clean.nocasecmp_to("Form") == 0
		or (not _form_name.is_empty() and first_clean.nocasecmp_to(_form_name) == 0)):
		current_type = "Form"
	elif VGIntelliSense.is_global_object(first_clean):
		current_type = "GlobalObject:" + first_clean
	elif first_had_parens:
		# First element is a function call — resolve its return type
		var ret := _get_function_return_type(first_clean)
		if not ret.is_empty() and ret != "Variant":
			current_type = ret
		else:
			current_type = _infer_type(first_clean)
	else:
		current_type = _infer_type(first_clean)
	
	# Walk the rest of the chain, resolving each member's return type
	for i in range(1, chain.size()):
		var member_name: String = chain[i]
		if member_name.is_empty():
			continue
		
		# Strip parentheses from method calls in chains:
		# e.g. "get_parent()" → "get_parent",  "Item(1)" → "Item"
		var member_clean := member_name
		if "(" in member_clean:
			member_clean = member_clean.get_slice("(", 0).strip_edges()
		
		# If current context is a Form, the member might be a control name
		if current_type == "Form":
			if member_clean in _known_controls:
				current_type = _get_control_type(member_clean)
				continue
			# Check Form members (Show, Hide, Caption, etc.)
			var form_resolved := VGIntelliSense.resolve_member_type("Form", member_clean)
			if not form_resolved.is_empty() and form_resolved != "void":
				current_type = form_resolved
			else:
				current_type = "Variant"
		elif _known_udts.has(current_type):
			# UDT chain: player.pos → look up "pos" field → get its type
			var udt_fields: Array = _known_udts[current_type]
			var found := false
			for field in udt_fields:
				if field["name"].nocasecmp_to(member_clean) == 0:
					current_type = field.get("type", "Variant")
					found = true
					break
			if not found:
				current_type = "Variant"
		else:
			# Resolve member return type via VGIntelliSense (ClassDB, VB6 aliases, etc.)
			var resolved := VGIntelliSense.resolve_member_type(current_type, member_clean)
			if resolved.is_empty() or resolved == "void":
				current_type = "Variant"
			else:
				current_type = resolved
	
	return current_type

## Scans the entire script text for VB6-style labels.
## A label is an identifier followed by a colon at the start of a line
## (with optional leading whitespace), e.g.  MyLabel:
## Returns an Array[String] of unique label names (preserving original casing).
func _scan_labels() -> Array[String]:
	var labels: Array[String] = []
	var seen := {}  # lowercase → true, to avoid duplicates
	var label_re := RegEx.new()
	# Match:  optional whitespace, then an identifier, then a colon.
	# Negative lookahead avoids matching  Sub Foo():  or  Function Bar():
	# by requiring the colon to come right after the identifier (with
	# optional whitespace), NOT after parentheses.
	label_re.compile("^[ \\t]*([A-Za-z_]\\w*)\\s*:")
	
	# Keywords that might appear with a colon in other contexts
	var excluded := {
		"sub": true, "function": true, "property": true, "end": true,
		"private": true, "public": true, "friend": true, "static": true,
		"dim": true, "redim": true, "const": true, "type": true,
		"enum": true, "class": true, "if": true, "elseif": true,
		"else": true, "select": true, "case": true, "for": true,
		"do": true, "while": true, "with": true, "get": true,
		"set": true, "let": true, "default": true, "rem": true,
	}
	
	for i in range(get_line_count()):
		var line_text := get_line(i)
		var m := label_re.search(line_text)
		if m:
			var name := m.get_string(1)
			var lower := name.to_lower()
			if lower not in excluded and lower not in seen:
				seen[lower] = true
				labels.append(name)
	return labels

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

func _is_dot_in_current_expr(before_cursor: String) -> bool:
	## Check whether the last dot in before_cursor belongs to the current
	## sub-expression.  If an expression-breaking operator (=, +, (, etc.)
	## appears *after* the last dot, the dot is in a previous sub-expression
	## and we should fall through to global completions instead.
	## Example: "me.BackColor=vb" → dot is before '=' → return false
	##          "Me."            → dot at end        → return true
	var last_dot_pos := before_cursor.rfind(".")
	if last_dot_pos < 0:
		return false
	var text_after_dot := before_cursor.substr(last_dot_pos + 1)
	for bc in ["=", "(", ")", ",", "+", "-", "*", "/", "&", "<", ">"]:
		if bc in text_after_dot:
			return false
	return true

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
	# 0. Form name reference (Form1 → Form type, same as Me)
	if not _form_name.is_empty() and var_name.nocasecmp_to(_form_name) == 0:
		return "Form"
	
	# 1. Check the parsed variable type map first (Dim x As Type)
	var lower_name := var_name.to_lower()
	if _variable_types.has(lower_name):
		return _variable_types[lower_name]
	
	# 2. Check if it's a known control — resolve to its actual type
	if var_name in _known_controls:
		return _get_control_type(var_name)
	
	# 3. Try Dim regex as fallback for dynamically typed vars
	var text = get_text()
	var regex = RegEx.new()
	regex.compile("(?i)(?:Dim|Private|Public|Static)\\s+" + var_name + "\\s+As\\s+(\\w+)")
	var match = regex.search(text)
	if match:
		return match.get_string(1)
	
	# 4. Check if it's a Godot type name (for static member access like Vector2.ZERO)
	if ClassDB.class_exists(var_name):
		return var_name
	
	return "Object"

## Returns the Godot-equivalent type name for a form control by looking up
## its "type" field from the control info list.
func _get_control_type(ctrl_name: String) -> String:
	for info in _control_info_list:
		if info.get("name", "") == ctrl_name:
			var vb6_type: String = info.get("type", "")
			if not vb6_type.is_empty():
				return VGIntelliSense.resolve_control_type(vb6_type)
	return "Control"

## Resolves the With context at the cursor position by walking backwards
## through lines to find the enclosing With <expression> statement.
## Returns the type of the With object, or "" if not inside a With block.
func _resolve_with_context() -> String:
	var caret_line := get_caret_line()
	var with_depth := 0  # Track nested With/End With
	
	for i in range(caret_line, -1, -1):
		var line_stripped := get_line(i).strip_edges().to_lower()
		# Count End With (increases nesting when walking backwards)
		if line_stripped == "end with":
			with_depth += 1
			continue
		# Found a With statement
		if line_stripped.begins_with("with "):
			if with_depth > 0:
				with_depth -= 1  # This With is paired with an End With we saw
				continue
			# This is our enclosing With — extract the object expression
			var with_line := get_line(i).strip_edges()
			var with_expr := with_line.substr(5).strip_edges()  # Skip "With "
			# Resolve the With expression to a type
			if with_expr.nocasecmp_to("Me") == 0:
				return "Form"
			# Check if it's a known variable
			var with_type := _infer_type(with_expr)
			if with_type != "Object":
				return with_type
			# Check if it's a known control
			if with_expr in _known_controls:
				return _get_control_type(with_expr)
			# Could be a chained expression: With Me.Text1
			if "." in with_expr:
				var chain := with_expr.split(".")
				return _resolve_dot_chain(chain)
			return with_type
	
	return ""  # Not inside a With block

## Returns the element type for an array or collection variable.
## e.g. Dim arr() As String → "String", Dim items As Collection → "Variant"
func _infer_array_element_type(var_name: String) -> String:
	var lower_name := var_name.to_lower()
	# Check parsed variable types first — arrays declared as Dim arr() As Type
	# store the element type directly
	if _variable_types.has(lower_name):
		return _variable_types[lower_name]
	# Fallback: scan for Dim arr(...) As Type
	var text := get_text()
	var regex := RegEx.new()
	regex.compile("(?i)(?:Dim|Private|Public|Static)\\s+" + var_name + "\\s*\\([^)]*\\)\\s+As\\s+(\\w+)")
	var m := regex.search(text)
	if m:
		return m.get_string(1)
	return "Variant"

## Returns the return type of a Function by scanning declarations.
## e.g. Function GetName() As String → "String"
func _get_function_return_type(func_name: String) -> String:
	var lower_name := func_name.to_lower()
	# Check the parsed function return types cache
	if _known_functions.has(lower_name):
		return _known_functions[lower_name]
	# Fallback: regex scan
	var text := get_text()
	var regex := RegEx.new()
	regex.compile("(?i)(?:Public\\s+|Private\\s+|Static\\s+|Friend\\s+)?Function\\s+" + func_name + "\\s*\\([^)]*\\)\\s+As\\s+(\\w+)")
	var m := regex.search(text)
	if m:
		return m.get_string(1)
	# Check for Property Get with return type
	regex.compile("(?i)(?:Public\\s+|Private\\s+)?Property\\s+Get\\s+" + func_name + "\\s*\\([^)]*\\)\\s+As\\s+(\\w+)")
	m = regex.search(text)
	if m:
		return m.get_string(1)
	return ""

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
	var cur_line_count := get_line_count()
	# Detect a real Enter press (exactly +1 line).  Multi-line snippet
	# insertions add >1 line and already include closing keywords.
	if cur_line_count == _prev_line_count + 1:
		call_deferred("_handle_auto_indent")
	_prev_line_count = cur_line_count
	
	_parse_variables()
	code_changed.emit(get_text())
	# Explicitly request code completion — the built-in prefix auto-trigger
	# is unreliable in @tool / embedded editor contexts.  Deferred so the
	# caret position has settled after the text change.
	call_deferred("_request_completion_deferred")

func _request_completion_deferred() -> void:
	if not has_focus():
		return
	# Trigger when the caret is at the end of a word OR right after a dot
	# (dot triggers member-access completion even with no partial word typed yet)
	var line := get_line(get_caret_line())
	var col := get_caret_column()
	if col > 0:
		var last_char := line[col - 1]
		if _is_word_char(last_char) or last_char == ".":
			request_code_completion(true)

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
	_variable_types.clear()
	
	var text = get_text()
	var regex = RegEx.new()
	
	# Match Dim/Private/Public/Static declarations, capturing optional As Type
	# Also handles array declarations: Dim arr(10) As Integer, Dim arr() As String
	regex.compile("(?i)(?:Dim|Private|Public|Static)\\s+(\\w+)(?:\\s*\\([^)]*\\))?(?:\\s+As\\s+(?:New\\s+)?(\\w+))?")
	var matches = regex.search_all(text)
	
	for m in matches:
		var var_name = m.get_string(1)
		if var_name not in _known_variables:
			_known_variables.append(var_name)
		# Store the declared type if present
		var type_str := m.get_string(2)
		if not type_str.is_empty():
			_variable_types[var_name.to_lower()] = type_str
	
	# Also catch "Set x = New Type" patterns for type inference
	var set_regex := RegEx.new()
	set_regex.compile("(?i)Set\\s+(\\w+)\\s*=\\s*New\\s+(\\w+)")
	var set_matches := set_regex.search_all(text)
	for sm in set_matches:
		var var_name := sm.get_string(1)
		var type_str := sm.get_string(2)
		if not var_name.is_empty() and not type_str.is_empty():
			_variable_types[var_name.to_lower()] = type_str
	
	# ── Scan for Enum blocks: _known_enums[EnumName] = [Member1, Member2, ...] ──
	_known_enums.clear()
	var lines := text.split("\n")
	var in_enum := false
	var enum_name := ""
	var enum_members: Array[String] = []
	for line_text in lines:
		var stripped := line_text.strip_edges()
		var sl := stripped.to_lower()
		if not in_enum:
			if sl.begins_with("enum ") or (sl.begins_with("public enum ") or sl.begins_with("private enum ")):
				in_enum = true
				var enum_re := RegEx.new()
				enum_re.compile("(?i)(?:Public\\s+|Private\\s+)?Enum\\s+(\\w+)")
				var em := enum_re.search(stripped)
				if em:
					enum_name = em.get_string(1)
					enum_members = []
		else:
			if sl == "end enum":
				if not enum_name.is_empty():
					_known_enums[enum_name] = enum_members.duplicate()
				in_enum = false
				enum_name = ""
			elif not stripped.is_empty() and not sl.begins_with("'"):
				var member := stripped.get_slice("=", 0).get_slice(" ", 0).strip_edges()
				if not member.is_empty():
					enum_members.append(member)
	
	# ── Scan for Type/Struct (UDT) blocks: _known_udts[TypeName] = [{name, type}] ──
	_known_udts.clear()
	var in_type := false
	var type_name := ""
	var type_fields: Array[Dictionary] = []
	for line_text in lines:
		var stripped := line_text.strip_edges()
		var sl := stripped.to_lower()
		if not in_type:
			if sl.begins_with("type ") or sl.begins_with("public type ") or sl.begins_with("private type "):
				in_type = true
				var type_re := RegEx.new()
				type_re.compile("(?i)(?:Public\\s+|Private\\s+)?Type\\s+(\\w+)")
				var tm := type_re.search(stripped)
				if tm:
					type_name = tm.get_string(1)
					type_fields = []
		else:
			if sl == "end type":
				if not type_name.is_empty():
					_known_udts[type_name] = type_fields.duplicate()
				in_type = false
				type_name = ""
			elif not stripped.is_empty() and not sl.begins_with("'"):
				# UDT field: "fieldName As Type" or just "fieldName"
				var field_re := RegEx.new()
				field_re.compile("(?i)(\\w+)(?:\\s+As\\s+(\\w+))?")
				var fm := field_re.search(stripped)
				if fm:
					type_fields.append({
						"name": fm.get_string(1),
						"type": fm.get_string(2) if not fm.get_string(2).is_empty() else "Variant"
					})
	
	# ── Scan for Function return types: _known_functions[name_lower] = ReturnType ──
	_known_functions.clear()
	var func_re := RegEx.new()
	func_re.compile("(?i)(?:Public\\s+|Private\\s+|Static\\s+|Friend\\s+)?Function\\s+(\\w+)\\s*\\([^)]*\\)\\s+As\\s+(\\w+)")
	var func_matches := func_re.search_all(text)
	for fm in func_matches:
		var fn_name := fm.get_string(1)
		var fn_ret := fm.get_string(2)
		if not fn_name.is_empty() and not fn_ret.is_empty():
			_known_functions[fn_name.to_lower()] = fn_ret
	# Also scan Property Get return types
	var prop_re := RegEx.new()
	prop_re.compile("(?i)(?:Public\\s+|Private\\s+)?Property\\s+Get\\s+(\\w+)\\s*\\([^)]*\\)\\s+As\\s+(\\w+)")
	var prop_matches := prop_re.search_all(text)
	for pm in prop_matches:
		var pn := pm.get_string(1)
		var pt := pm.get_string(2)
		if not pn.is_empty() and not pt.is_empty():
			_known_functions[pn.to_lower()] = pt
	
	# ── Scan for Import directives and parse imported module symbols ──
	_scan_imported_modules(lines)

## Sets the current form name (e.g. "Form1") so Form1. works like Me.
func set_form_name(form_name: String) -> void:
	_form_name = form_name

## Sets the known form controls for IntelliSense
func set_known_controls(controls: Array[String]) -> void:
	_known_controls = controls

## Sets the full control info list (name, type, rect, etc.) from the form designer.
## This enables type-aware dot-completion: Text1. → LineEdit properties.
func set_control_info(info_list: Array[Dictionary]) -> void:
	_control_info_list = info_list

## Adds a known control for IntelliSense
func add_known_control(control_name: String) -> void:
	if control_name not in _known_controls:
		_known_controls.append(control_name)

## Gets the current list of known variables
func get_known_variables() -> Array[String]:
	return _known_variables

## Sets pre-parsed imported module info (from plugin).
## Each entry: {name: String, path: String, subs: Array, variables: Array, constants: Array}
func set_imported_modules(modules: Array[Dictionary]) -> void:
	_imported_modules = modules

## Scans Import directives in the current file and parses the referenced .vg
## files to extract their public symbols for Module. dot-completion.
func _scan_imported_modules(lines: PackedStringArray) -> void:
	_imported_modules.clear()
	var import_re := RegEx.new()
	import_re.compile("(?i)^\\s*Import\\s+(?:\"([^\"]+)\"|([\\w]+))")
	
	for line_text in lines:
		var m := import_re.search(line_text)
		if not m:
			continue
		var import_path := m.get_string(1)  # Import "path/module.vg"
		var import_name := m.get_string(2)  # Import ModuleName
		
		# Determine the module name and the file path to parse
		var mod_name := ""
		var mod_path := ""
		if not import_path.is_empty():
			mod_path = import_path
			mod_name = import_path.get_file().get_basename()
		elif not import_name.is_empty():
			mod_name = import_name
			mod_path = import_name + ".vg"
		
		if mod_name.is_empty():
			continue
		
		# Try to resolve the path relative to res://
		var try_paths: Array[String] = [
			"res://" + mod_path,
			"res://" + mod_path.get_file(),
		]
		# If the current file has a path, also try relative to it
		# (but we don't have direct access to file path in CodeEdit, so use res://)
		
		var resolved_path := ""
		for tp in try_paths:
			if FileAccess.file_exists(tp):
				resolved_path = tp
				break
		
		if resolved_path.is_empty():
			# Even without the file, still register the module name so
			# at least it shows up as a recognizable identifier
			_imported_modules.append({"name": mod_name, "subs": [], "variables": [], "constants": []})
			continue
		
		# Parse the imported file to extract public symbols
		var mod_info := _parse_module_symbols(resolved_path, mod_name)
		_imported_modules.append(mod_info)
	
	# Also scan for Module...End Module blocks within the current file
	var in_module := false
	var current_mod_name := ""
	var mod_subs: Array[String] = []
	var mod_vars: Array[String] = []
	var mod_consts: Array[String] = []
	for line_text in lines:
		var stripped := line_text.strip_edges()
		var sl := stripped.to_lower()
		if not in_module:
			if sl.begins_with("module ") or sl.begins_with("public module ") or sl.begins_with("private module "):
				in_module = true
				var mod_re := RegEx.new()
				mod_re.compile("(?i)(?:Public\\s+|Private\\s+)?Module\\s+(\\w+)")
				var mm := mod_re.search(stripped)
				if mm:
					current_mod_name = mm.get_string(1)
					mod_subs = []
					mod_vars = []
					mod_consts = []
		else:
			if sl == "end module":
				if not current_mod_name.is_empty():
					_imported_modules.append({
						"name": current_mod_name,
						"subs": mod_subs.duplicate(),
						"variables": mod_vars.duplicate(),
						"constants": mod_consts.duplicate()
					})
				in_module = false
				current_mod_name = ""
			elif not stripped.is_empty() and not sl.begins_with("'"):
				# Extract sub/function/variable/const from inside the Module block
				var sub_re := RegEx.new()
				sub_re.compile("(?i)(?:Public\\s+|Private\\s+)?(?:Sub|Function)\\s+(\\w+)")
				var sm := sub_re.search(stripped)
				if sm:
					mod_subs.append(sm.get_string(1))
					continue
				var const_re := RegEx.new()
				const_re.compile("(?i)(?:Public\\s+)?Const\\s+(\\w+)")
				var cm := const_re.search(stripped)
				if cm:
					mod_consts.append(cm.get_string(1))
					continue
				var dim_re := RegEx.new()
				dim_re.compile("(?i)(?:Public\\s+|Dim\\s+)(\\w+)")
				var dm := dim_re.search(stripped)
				if dm:
					mod_vars.append(dm.get_string(1))

## Parses a .vg module file and extracts its public Subs, Functions, Variables, and Constants.
func _parse_module_symbols(file_path: String, mod_name: String) -> Dictionary:
	var result := {"name": mod_name, "path": file_path, "subs": [], "variables": [], "constants": []}
	
	var f := FileAccess.open(file_path, FileAccess.READ)
	if not f:
		return result
	var content := f.get_as_text()
	f.close()
	
	# Extract public Sub/Function names
	var sub_re := RegEx.new()
	sub_re.compile("(?i)(?:Public\\s+)?(?:Sub|Function)\\s+(\\w+)")
	for m in sub_re.search_all(content):
		var name := m.get_string(1)
		if name not in result["subs"]:
			result["subs"].append(name)
	
	# Extract public variables (Public x As Type, or Dim at module level)
	var var_re := RegEx.new()
	var_re.compile("(?i)Public\\s+(\\w+)(?:\\s+As\\s+\\w+)?")
	for m in var_re.search_all(content):
		var name := m.get_string(1)
		# Skip if it's a Sub/Function/Const/Enum/Type keyword
		var lower := name.to_lower()
		if lower in ["sub", "function", "const", "enum", "type", "property", "module", "class"]:
			continue
		if name not in result["variables"]:
			result["variables"].append(name)
	
	# Extract constants
	var const_re := RegEx.new()
	const_re.compile("(?i)(?:Public\\s+)?Const\\s+(\\w+)")
	for m in const_re.search_all(content):
		var name := m.get_string(1)
		if name not in result["constants"]:
			result["constants"].append(name)
	
	return result

# =============================================================================
# BRACKET MATCHING
# =============================================================================

func _gui_input(event: InputEvent) -> void:
	# ── Yellow arrow drag handling (Set Next Statement) ──
	if _is_debug_paused and _executing_line >= 0:
		# Handle ongoing drag first — release and motion anywhere on the control
		if _arrow_dragging:
			if event is InputEventMouseButton:
				var mb := event as InputEventMouseButton
				if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
					# Release — commit the Set Next Statement
					var target_line := _arrow_drag_line
					_arrow_dragging = false
					mouse_default_cursor_shape = Control.CURSOR_IBEAM
					if target_line >= 0 and target_line != _executing_line:
						# VB6 rule: can only Set Next Statement within the current procedure
						var exec_range := _get_enclosing_procedure_range(_executing_line)
						var target_range := _get_enclosing_procedure_range(target_line)
						if exec_range != target_range:
							push_warning("Set Next Statement: can only move within the current procedure.")
						else:
							var target_line_1based := target_line + 1
							set_executing_line(target_line)
							set_next_statement_requested.emit(target_line_1based)
					_arrow_drag_line = -1
					queue_redraw()
					if _arrow_overlay:
						_arrow_overlay.queue_redraw()
					accept_event()
					return
			if event is InputEventMouseMotion:
				var mm := event as InputEventMouseMotion
				_arrow_drag_line = _get_line_at_y(mm.position.y)
				queue_redraw()
				if _arrow_overlay:
					_arrow_overlay.queue_redraw()
				accept_event()
				return
		
		# Start drag when clicking on the executing-line arrow in the gutter.
		# Only intercept clicks on the actual arrow line — clicks on other
		# lines must pass through so users can still toggle breakpoints (F9
		# behaviour / gutter click) while paused.
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			var gutter_width := get_total_gutter_width() if has_method("get_total_gutter_width") else 48.0
			if mb.position.x < gutter_width and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				var clicked_line := _get_line_at_y(mb.position.y)
				if clicked_line == _executing_line:
					_arrow_dragging = true
					_arrow_drag_line = clicked_line
					mouse_default_cursor_shape = Control.CURSOR_DRAG
					_ensure_arrow_overlay()
					queue_redraw()
					if _arrow_overlay:
						_arrow_overlay.queue_redraw()
					accept_event()
					return
	
	# ── Right-click context menu ──
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_show_context_menu(mb.position)
			accept_event()
			return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_PARENLEFT:
				_show_parameter_hint()
			KEY_I:
				if event.ctrl_pressed and event.shift_pressed and not event.alt_pressed:
					# Ctrl+Shift+I = Fix Indentation
					fix_indentation()
					accept_event()
			KEY_APOSTROPHE:
				if event.ctrl_pressed and not event.shift_pressed and not event.alt_pressed:
					# Ctrl+' = Toggle Comment
					toggle_comment_selection()
					accept_event()
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
			KEY_F10:
				if event.ctrl_pressed and event.shift_pressed and _is_debug_paused:
					# Ctrl+Shift+F10 = Set Next Statement (VB6 shortcut)
					var target_line_0 := get_caret_line()
					var exec_range := _get_enclosing_procedure_range(_executing_line)
					var target_range := _get_enclosing_procedure_range(target_line_0)
					if exec_range != target_range:
						push_warning("Set Next Statement: can only move within the current procedure.")
					else:
						var target := target_line_0 + 1  # 1-based
						set_executing_line(target_line_0)
						set_next_statement_requested.emit(target)
					accept_event()
				elif event.ctrl_pressed and not event.shift_pressed and _is_debug_paused:
					# Ctrl+F10 = Run to Cursor
					var target := get_caret_line() + 1  # 1-based
					run_to_cursor_requested.emit(target)
					accept_event()
			KEY_F11:
				if event.ctrl_pressed and event.shift_pressed:
					# Ctrl+Shift+F11 = Set/Edit Tracepoint (Log Point)
					set_tracepoint(get_caret_line())
					accept_event()
			KEY_ENTER:
				if event.ctrl_pressed and event.shift_pressed and _is_debug_paused:
					# Ctrl+Shift+Enter = Edit and Continue (VB6 signature)
					edit_and_continue_requested.emit()
					accept_event()
			KEY_P:
				if event.ctrl_pressed and event.shift_pressed and event.alt_pressed and _is_debug_paused:
					# Ctrl+Shift+Alt+P = Pin inline value at current line
					_pin_variable_at_caret()
					accept_event()
			KEY_B:
				if event.ctrl_pressed and not event.shift_pressed and not event.alt_pressed:
					# Ctrl+B = Toggle Bookmark
					toggle_bookmark(get_caret_line())
					accept_event()
				elif event.ctrl_pressed and event.shift_pressed and not event.alt_pressed:
					# Ctrl+Shift+B = Go to Next Bookmark
					goto_next_bookmark()
					accept_event()
				elif event.ctrl_pressed and not event.shift_pressed and event.alt_pressed:
					# Ctrl+Alt+B = Go to Previous Bookmark
					goto_prev_bookmark()
					accept_event()

# ── Data Tips: forward mouse motion to VGDataTips for hover-to-inspect ──
	if event is InputEventMouseMotion and _is_debug_paused and _data_tips_ref and not _arrow_dragging:
		var mm := event as InputEventMouseMotion
		_data_tips_ref.check_hover(self, mm.position)

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
			# get_pos_at_line_column returns the BOTTOM of the line; subtract
			# row_height to get the TOP (which is where the separator goes).
			var row_height: float = get_line_height()
			var sep_pos := get_pos_at_line_column(line_idx, 0)
			if sep_pos.y < 0:
				continue
			var y_offset: float = float(sep_pos.y) - row_height
			# Draw the separator line across the full width
			var from_x: float = get_total_gutter_width() if has_method("get_total_gutter_width") else 48.0
			var to_x: float = size.x
			draw_line(Vector2(from_x, y_offset), Vector2(to_x, y_offset), separator_color, line_width)
	
	# ── Keep overlay in sync with scrolling / redraws ──
	if _arrow_overlay and (_is_debug_paused or _arrow_dragging):
		_arrow_overlay.queue_redraw()
	if _bookmark_overlay and not _bookmarks.is_empty():
		_bookmark_overlay.queue_redraw()
	if _pin_overlay and not _pinned_values.is_empty():
		_pin_overlay.queue_redraw()

## Create the arrow overlay Control (draws ON TOP of CodeEdit gutters/text).
func _ensure_arrow_overlay() -> void:
	if _arrow_overlay != null:
		return
	_arrow_overlay = Control.new()
	_arrow_overlay.name = "ArrowOverlay"
	_arrow_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_arrow_overlay)
	_arrow_overlay.draw.connect(_on_arrow_overlay_draw)

## Called when the overlay needs to repaint — draws arrows on top of everything.
func _on_arrow_overlay_draw() -> void:
	# get_pos_at_line_column() returns the BOTTOM of the line (caret baseline),
	# so we subtract row_height to obtain the TOP of the line for drawing.
	var rh: float = get_line_height()
	
	# ── Dragging: ghost at original + solid at drag target ──
	if _arrow_dragging and _arrow_drag_line >= 0:
		# Ghost arrow at the original executing line (dimmed)
		if _executing_line >= 0:
			var opos := get_pos_at_line_column(_executing_line, 0)
			var oy := float(opos.y) - rh
			if opos.y >= 0 and oy < size.y:
				_draw_yellow_arrow_on(oy, rh, Color(1.0, 0.85, 0.0, 0.3))
		# Full-opacity arrow + highlight at drag destination
		if _arrow_drag_line != _executing_line:
			var dpos := get_pos_at_line_column(_arrow_drag_line, 0)
			var dy := float(dpos.y) - rh
			if dpos.y >= 0 and dy < size.y:
				var gw: float = get_total_gutter_width() if has_method("get_total_gutter_width") else 48.0
				_arrow_overlay.draw_rect(Rect2(gw, dy, size.x - gw, rh),
					Color(1.0, 1.0, 0.0, 0.22))
				_draw_yellow_arrow_on(dy, rh, Color(1.0, 0.85, 0.0, 1.0))
	
	# ── Not dragging: solid arrow at executing line ──
	elif _is_debug_paused and _executing_line >= 0:
		var epos := get_pos_at_line_column(_executing_line, 0)
		var ey := float(epos.y) - rh
		if epos.y >= 0 and ey < size.y:
			_draw_yellow_arrow_on(ey, rh, Color(1.0, 0.85, 0.0, 1.0))

## Draw a VB6-style yellow right-pointing arrow on the overlay.
func _draw_yellow_arrow_on(y_pos: float, row_height: float, color: Color) -> void:
	var arrow_size: float = mini(row_height - 2, 16)
	var x_start: float = 4.0
	var y_center: float = y_pos + row_height * 0.5
	
	# Arrow body (rectangle)
	var body_width: float = arrow_size * 0.6
	var body_height: float = arrow_size * 0.5
	_arrow_overlay.draw_rect(Rect2(x_start, y_center - body_height * 0.5, body_width, body_height), color)
	
	# Arrow head (triangle pointing right)
	var head_x: float = x_start + body_width
	var head_half_h: float = arrow_size * 0.55
	var head_tip_x: float = head_x + arrow_size * 0.5
	var points := PackedVector2Array([
		Vector2(head_x, y_center - head_half_h),
		Vector2(head_tip_x, y_center),
		Vector2(head_x, y_center + head_half_h)
	])
	_arrow_overlay.draw_colored_polygon(points, color)
	
	# Dark outline for visibility
	var outline_color := Color(0.3, 0.25, 0.0, color.a)
	_arrow_overlay.draw_polyline(PackedVector2Array([
		Vector2(x_start, y_center - body_height * 0.5),
		Vector2(head_x, y_center - body_height * 0.5),
		Vector2(head_x, y_center - head_half_h),
		Vector2(head_tip_x, y_center),
		Vector2(head_x, y_center + head_half_h),
		Vector2(head_x, y_center + body_height * 0.5),
		Vector2(x_start, y_center + body_height * 0.5),
		Vector2(x_start, y_center - body_height * 0.5),
	]), outline_color, 1.0)

# =============================================================================
# SET NEXT STATEMENT — VB6-style yellow arrow helpers
# =============================================================================

## Convert a Y pixel position to a line index (0-based).
func _get_line_at_y(y: float) -> int:
	# Use Godot's built-in coordinate mapping which accounts for
	# StyleBox content margin and sub-line scroll offset.
	var lc := get_line_column_at_pos(Vector2i(0, int(y)), true)
	return clampi(lc.y, 0, get_line_count() - 1)

## Set the executing line indicator (0-based line index). Call with -1 to clear.
func set_executing_line(line: int) -> void:
	_executing_line = line
	if line >= 0:
		_ensure_arrow_overlay()
		if _arrow_overlay:
			_arrow_overlay.visible = true
	queue_redraw()
	if _arrow_overlay:
		_arrow_overlay.queue_redraw()

## Clear the executing line indicator and hide the arrow overlay.
func clear_executing_line() -> void:
	_executing_line = -1
	_is_debug_paused = false
	_arrow_dragging = false
	_arrow_drag_line = -1
	queue_redraw()
	if _arrow_overlay:
		_arrow_overlay.visible = false
		_arrow_overlay.queue_redraw()

## Set the debug paused state (enables/disables arrow dragging).
func set_debug_paused(paused: bool) -> void:
	_is_debug_paused = paused
	if not paused:
		clear_executing_line()

## Reset the yellow arrow back to the actual executing line (e.g. after a
## failed Set Next Statement attempt).  Called from the plugin when the VM
## reports that the target line was not found in the current bytecode chunk.
func reset_arrow_to_executing_line() -> void:
	if _executing_line >= 0:
		queue_redraw()
		if _arrow_overlay:
			_arrow_overlay.queue_redraw()

# =============================================================================
# PROCEDURE BOUNDARY DETECTION (for Set Next Statement guard)
# =============================================================================

## Returns true if `text` (stripped) is a Sub or Function declaration line.
func _is_procedure_start(text: String) -> bool:
	var lower := text.to_lower()
	# Strip optional Public/Private/Friend prefix
	for prefix in ["public ", "private ", "friend "]:
		if lower.begins_with(prefix):
			lower = lower.substr(prefix.length()).strip_edges()
			break
	# Strip optional Static prefix
	if lower.begins_with("static "):
		lower = lower.substr(7).strip_edges()
	return lower.begins_with("sub ") or lower.begins_with("function ")

## Returns true if `text` (stripped) is an End Sub or End Function line.
func _is_procedure_end(text: String) -> bool:
	var lower := text.to_lower().strip_edges()
	return lower == "end sub" or lower == "end function"

## Returns the 0-based line range [start, end] of the Sub/Function enclosing
## the given 0-based line, or Vector2i(-1, -1) if the line is outside any procedure.
func _get_enclosing_procedure_range(line_0based: int) -> Vector2i:
	var lc := get_line_count()
	if line_0based < 0 or line_0based >= lc:
		return Vector2i(-1, -1)
	# Scan backward to find the nearest Sub/Function declaration
	var proc_start := -1
	for i in range(line_0based, -1, -1):
		var stripped := get_line(i).strip_edges()
		if _is_procedure_start(stripped):
			proc_start = i
			break
		# If we hit End Sub/End Function before a start, we're between procedures
		if _is_procedure_end(stripped) and i < line_0based:
			return Vector2i(-1, -1)
	if proc_start < 0:
		return Vector2i(-1, -1)
	# Scan forward from proc_start to find the matching End Sub/End Function
	for i in range(proc_start + 1, lc):
		var stripped := get_line(i).strip_edges()
		if _is_procedure_end(stripped):
			return Vector2i(proc_start, i)
		# Another Sub/Function start means the first one wasn't closed properly
		if _is_procedure_start(stripped):
			return Vector2i(proc_start, i - 1)
	# Reached end of file without End Sub/Function
	return Vector2i(proc_start, lc - 1)

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

# =============================================================================
# TRACEPOINTS (LOG POINTS) — breakpoints that log a message instead of pausing
# =============================================================================

func set_tracepoint(line: int) -> void:
	## Opens a dialog to set/edit a tracepoint log message for this line.
	## If no breakpoint exists, creates one first.
	if not is_line_breakpointed(line):
		set_line_as_breakpoint(line, true)
	
	if not _tp_dialog:
		_tp_dialog = AcceptDialog.new()
		_tp_dialog.title = "Tracepoint — Log Message"
		_tp_dialog.min_size = Vector2i(450, 140)
		var vb = VBoxContainer.new()
		var lbl = Label.new()
		lbl.text = "Log message (use {variable} to interpolate values):"
		vb.add_child(lbl)
		_tp_input = LineEdit.new()
		_tp_input.placeholder_text = 'e.g. i = {i}, total = {total}'
		vb.add_child(_tp_input)
		var hint = Label.new()
		hint.text = "Leave empty to remove tracepoint (keeps breakpoint)."
		hint.add_theme_font_size_override("font_size", 11)
		hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		vb.add_child(hint)
		_tp_dialog.add_child(vb)
		_tp_dialog.confirmed.connect(_on_tp_confirmed)
		add_child(_tp_dialog)
	
	_tp_line = line
	_tp_input.text = _tracepoints.get(line, "")
	_tp_dialog.popup_centered()
	_tp_input.grab_focus()

func _on_tp_confirmed() -> void:
	if _tp_line >= 0:
		var msg = _tp_input.text.strip_edges()
		if msg.is_empty():
			_tracepoints.erase(_tp_line)
		else:
			_tracepoints[_tp_line] = msg
		tracepoint_set.emit(_tp_line, msg)

func is_tracepoint(line: int) -> bool:
	return _tracepoints.has(line)

func get_tracepoint_message(line: int) -> String:
	return _tracepoints.get(line, "")

func get_all_tracepoints() -> Dictionary:
	## Returns {line: log_message} for all tracepoints.
	return _tracepoints.duplicate()

# =============================================================================
# PINNED INLINE VALUES — show live variable values next to source lines
# =============================================================================

func _pin_variable_at_caret() -> void:
	## Pin the variable under/near the caret on the current line.
	## Extracts the word at the caret position and pins it.
	var line := get_caret_line()
	var col := get_caret_column()
	var line_text := get_line(line)
	if line_text.is_empty():
		return
	# Extract word at caret
	var start := col
	var end_pos := col
	while start > 0 and _is_ident_char(line_text[start - 1]):
		start -= 1
	while end_pos < line_text.length() and _is_ident_char(line_text[end_pos]):
		end_pos += 1
	var word := line_text.substr(start, end_pos - start).strip_edges()
	if word.is_empty():
		return
	_toggle_pin(line, word)

func _toggle_pin(line: int, variable: String) -> void:
	## Toggle a pinned inline value on/off for a line.
	if _pinned_values.has(line) and _pinned_values[line] == variable:
		_pinned_values.erase(line)
	else:
		_pinned_values[line] = variable
	_ensure_pin_overlay()
	if _pin_overlay:
		_pin_overlay.queue_redraw()
	pin_inline_value_requested.emit(line, variable)

func update_pinned_values(variables: Dictionary) -> void:
	## Called by the plugin when debug variables arrive.
	## variables is {name: value_string}.
	_pinned_data = variables
	if _pin_overlay:
		_pin_overlay.queue_redraw()

func get_pinned_variables() -> Dictionary:
	return _pinned_values.duplicate()

func clear_all_pins() -> void:
	_pinned_values.clear()
	if _pin_overlay:
		_pin_overlay.queue_redraw()

func _ensure_pin_overlay() -> void:
	if _pin_overlay and is_instance_valid(_pin_overlay):
		return
	_pin_overlay = Control.new()
	_pin_overlay.name = "PinOverlay"
	_pin_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pin_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pin_overlay.draw.connect(_draw_pinned_values)
	add_child(_pin_overlay)

func _draw_pinned_values() -> void:
	## Draw pinned variable values to the right of their source lines.
	if _pinned_values.is_empty() or not _pin_overlay:
		return
	var font := get_theme_font("font") if has_theme_font("font") else ThemeDB.fallback_font
	var font_size := get_theme_font_size("font_size") if has_theme_font_size("font_size") else 14
	var line_height := get_line_height()
	var scroll_v := get_v_scroll_bar().value if get_v_scroll_bar() else 0.0
	var first_visible := get_first_visible_line()
	var last_visible := first_visible + int(size.y / line_height) + 2

	var bg_color := Color(0.15, 0.15, 0.35, 0.85)   # Dark blue background
	var text_color := Color(0.7, 0.9, 1.0)            # Light cyan text
	var pin_color := Color(1.0, 0.85, 0.3)            # Gold pin icon
	var padding := 8.0

	for line_num in _pinned_values:
		if line_num < first_visible or line_num > last_visible:
			continue
		var var_name: String = _pinned_values[line_num]
		var value_str := "?"
		if var_name in _pinned_data:
			value_str = str(_pinned_data[var_name])
		elif var_name.to_lower() in _pinned_data:
			value_str = str(_pinned_data[var_name.to_lower()])
		var display := "📌 " + var_name + " = " + value_str

		# Position: to the right of the line text
		var line_text := get_line(line_num)
		var text_width := font.get_string_size(line_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var x_offset := _get_gutter_total_width() + text_width + 30.0
		var y_pos: float = float(line_num - first_visible) * line_height
		# Fallback y calculation is always used (CodeEdit doesn't have get_line_y_offset)

		var display_size := font.get_string_size(display, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var rect := Rect2(x_offset - padding, y_pos + 1, display_size.x + padding * 2, line_height - 2)

		# Draw background pill
		_pin_overlay.draw_rect(rect, bg_color, true)
		_pin_overlay.draw_rect(rect, pin_color * Color(1, 1, 1, 0.4), false, 1.0)
		# Draw text
		_pin_overlay.draw_string(font, Vector2(x_offset, y_pos + line_height * 0.75), display, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

## Utility: get total gutter width (accounts for all gutters).
func _get_gutter_total_width() -> float:
	var total := 0.0
	for i in get_gutter_count():
		total += get_gutter_width(i)
	return total

# =============================================================================
# BOOKMARKS — VB6-style code bookmarks
# =============================================================================

func toggle_bookmark(line: int) -> void:
	## Toggle a bookmark on the given line (0-based).
	if line < 0 or line >= get_line_count():
		return
	if _bookmarks.has(line):
		_bookmarks.erase(line)
		bookmark_toggled.emit(line, false)
	else:
		_bookmarks[line] = true
		bookmark_toggled.emit(line, true)
	_ensure_bookmark_overlay()
	if _bookmark_overlay:
		_bookmark_overlay.queue_redraw()

func goto_next_bookmark() -> void:
	## Navigate to the next bookmark after the caret line.
	if _bookmarks.is_empty():
		return
	var sorted_lines := _bookmarks.keys()
	sorted_lines.sort()
	var current := get_caret_line()
	for bm_line in sorted_lines:
		if bm_line > current:
			set_caret_line(bm_line)
			center_viewport_to_caret()
			return
	# Wrap around to first bookmark
	set_caret_line(sorted_lines[0])
	center_viewport_to_caret()

func goto_prev_bookmark() -> void:
	## Navigate to the previous bookmark before the caret line.
	if _bookmarks.is_empty():
		return
	var sorted_lines := _bookmarks.keys()
	sorted_lines.sort()
	var current := get_caret_line()
	for i in range(sorted_lines.size() - 1, -1, -1):
		if sorted_lines[i] < current:
			set_caret_line(sorted_lines[i])
			center_viewport_to_caret()
			return
	# Wrap around to last bookmark
	set_caret_line(sorted_lines[-1])
	center_viewport_to_caret()

func clear_all_bookmarks() -> void:
	## Clear all bookmarks.
	_bookmarks.clear()
	if _bookmark_overlay:
		_bookmark_overlay.queue_redraw()

func get_bookmarks() -> Dictionary:
	## Return the bookmarks dictionary (line → true).
	return _bookmarks.duplicate()

func set_bookmarks(bookmarks: Dictionary) -> void:
	## Restore bookmarks from a saved dictionary.
	_bookmarks = bookmarks
	_ensure_bookmark_overlay()
	if _bookmark_overlay:
		_bookmark_overlay.queue_redraw()

func _ensure_bookmark_overlay() -> void:
	if _bookmark_overlay and is_instance_valid(_bookmark_overlay):
		return
	_bookmark_overlay = Control.new()
	_bookmark_overlay.name = "BookmarkOverlay"
	_bookmark_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bookmark_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bookmark_overlay.draw.connect(_draw_bookmarks)
	add_child(_bookmark_overlay)

func _draw_bookmarks() -> void:
	## Draw bookmark icons (blue rectangles) in the gutter area.
	if _bookmarks.is_empty() or not _bookmark_overlay:
		return
	var line_height := get_line_height()
	var first_visible := get_first_visible_line()
	var last_visible := first_visible + int(size.y / line_height) + 2
	# Draw in the gutter area (left-most 6 pixels)
	var bm_color := Color(0.2, 0.5, 1.0, 0.8)  # Blue bookmark
	var bm_outline := Color(0.4, 0.7, 1.0, 0.6)
	var icon_x := 2.0
	var icon_w := 10.0
	for line_num in _bookmarks:
		if line_num < first_visible or line_num > last_visible:
			continue
		var y_pos := float(line_num - first_visible) * line_height
		if y_pos < 0.0 or y_pos > size.y:
			continue
		var icon_h := line_height - 4.0
		var rect := Rect2(icon_x, y_pos + 2, icon_w, icon_h)
		# Draw a filled rectangle with a flag shape
		_bookmark_overlay.draw_rect(rect, bm_color, true)
		_bookmark_overlay.draw_rect(rect, bm_outline, false, 1.0)
		# Small triangle notch on the right side for flag effect
		var tri_points := PackedVector2Array([
			Vector2(icon_x + icon_w, y_pos + 2 + icon_h * 0.3),
			Vector2(icon_x + icon_w + 4, y_pos + 2 + icon_h * 0.5),
			Vector2(icon_x + icon_w, y_pos + 2 + icon_h * 0.7),
		])
		_bookmark_overlay.draw_colored_polygon(tri_points, bm_color)

func save_bookmarks(file_path: String) -> void:
	## Save bookmarks to a sidecar file (.vg.bookmarks).
	var bm_path := file_path + ".bookmarks"
	if _bookmarks.is_empty():
		if FileAccess.file_exists(bm_path):
			DirAccess.remove_absolute(bm_path)
		return
	var lines: PackedInt32Array = PackedInt32Array()
	for line_num in _bookmarks:
		lines.append(line_num)
	var config := ConfigFile.new()
	config.set_value("bookmarks", "lines", lines)
	config.save(bm_path)

func load_bookmarks(file_path: String) -> void:
	## Load bookmarks from a sidecar file (.vg.bookmarks).
	var bm_path := file_path + ".bookmarks"
	_bookmarks.clear()
	var config := ConfigFile.new()
	if config.load(bm_path) == OK:
		var lines = config.get_value("bookmarks", "lines", PackedInt32Array())
		for line_num in lines:
			if line_num >= 0 and line_num < get_line_count():
				_bookmarks[line_num] = true
	_ensure_bookmark_overlay()
	if _bookmark_overlay:
		_bookmark_overlay.queue_redraw()
