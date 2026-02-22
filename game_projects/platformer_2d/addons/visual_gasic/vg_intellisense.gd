@tool
extends RefCounted
## VisualGasic IntelliSense Provider
##
## Provides code completion for .vg files:
## - VB6 Keywords (Dim, Sub, Function, If, For, etc.)
## - Built-in Functions (Print, MsgBox, InputBox, etc.)
## - Control names from the current form
## - Godot types and methods
## - Snippet templates

class_name VGIntelliSense

# =============================================================================
# VB6 KEYWORDS
# =============================================================================

const VB6_KEYWORDS: Array[String] = [
	# Declaration
	"Dim", "Global", "Private", "Public", "Static", "Const", "ReDim", "Preserve",
	"As", "New", "Set", "Let", "Get", "Property", "Type", "End Type", "Enum", "End Enum",
	
	# Procedures
	"Sub", "End Sub", "Function", "End Function", "ByVal", "ByRef", "Optional",
	"ParamArray", "Exit Sub", "Exit Function", "Return", "Call",
	
	# Control Flow
	"If", "Then", "Else", "ElseIf", "Elif", "End If",
	"Select Case", "Case", "Case Else", "End Select",
	"For", "To", "Step", "Next", "For Each", "In",
	"Do", "Loop", "While", "Wend", "Until",
	"GoTo", "GoSub", "On Error", "Resume", "Resume Next",
	"Exit For", "Exit Do", "Exit While", "Continue", "Pass",
	
	# Classes/Objects
	"Class", "End Class", "Me", "MyBase", "MyClass",
	"Implements", "Interface", "End Interface",
	"Inherits", "Extends", "With", "End With",
	"WithEvents", "RaiseEvent", "Event", "Handles",
	
	# Operators/Misc
	"And", "Or", "Not", "Xor", "Mod", "Is", "IsNot", "Like",
	"AndAlso", "OrElse",
	"True", "False", "Nothing", "Null", "Empty",
	"Option Explicit", "Option Compare",
	
	# Error Handling
	"Try", "Catch", "Finally", "End Try", "Throw",
	
	# Debugging
	"Stop",
	
	# Modern Extensions - Async/Parallel
	"Async", "Await", "Task", "Parallel",
	
	# Modern Extensions - Pattern Matching
	"Select Match", "Match", "When", "Where",
	"TypeOf", "HasValue", "Value",
	
	# Modern Extensions - Other
	"Lambda", "Of", "IIf",
	"Using", "End Using", "Yield", "Iterator",
	
	# Reactive Programming (Whenever)
	"Whenever", "End Whenever", "Section", "Local",
	"Changes", "Becomes", "Exceeds", "Below", "Between", "Contains",
	"Suspend",
	
	# File Operations
	"Open", "Close", "Input", "Output", "Append", "Line",
	
	# Data Processing
	"Data", "Read", "Restore", "DoEvents", "Include",
	
	# Collections
	"Dictionary",
]

# =============================================================================
# VB6 DATA TYPES
# =============================================================================

const VB6_TYPES: Array[String] = [
	"Integer", "Long", "Single", "Double", "String", "Boolean", "Byte",
	"Date", "Currency", "Variant", "Object", "Any",
	# Modern types
	"List", "Dictionary", "Array", "Task", "Optional",
]

# =============================================================================
# BUILT-IN FUNCTIONS
# =============================================================================

const BUILTIN_FUNCTIONS: Array[Dictionary] = [
	# I/O Functions
	{"name": "Print", "signature": "Print(text As String)", "description": "Outputs text to the console"},
	{"name": "MsgBox", "signature": "MsgBox(prompt As String, [buttons], [title]) As Integer", "description": "Displays a message dialog"},
	{"name": "InputBox", "signature": "InputBox(prompt As String, [title], [default]) As String", "description": "Shows input dialog"},
	{"name": "Debug.Print", "signature": "Debug.Print(text As String)", "description": "Outputs to the Immediate Window"},
	
	# String Functions
	{"name": "Len", "signature": "Len(str As String) As Integer", "description": "Returns string length"},
	{"name": "Left", "signature": "Left(str As String, n As Integer) As String", "description": "Returns leftmost n characters"},
	{"name": "Right", "signature": "Right(str As String, n As Integer) As String", "description": "Returns rightmost n characters"},
	{"name": "Mid", "signature": "Mid(str As String, start As Integer, [length]) As String", "description": "Returns substring"},
	{"name": "Trim", "signature": "Trim(str As String) As String", "description": "Removes leading/trailing whitespace"},
	{"name": "LTrim", "signature": "LTrim(str As String) As String", "description": "Removes leading whitespace"},
	{"name": "RTrim", "signature": "RTrim(str As String) As String", "description": "Removes trailing whitespace"},
	{"name": "UCase", "signature": "UCase(str As String) As String", "description": "Converts to uppercase"},
	{"name": "LCase", "signature": "LCase(str As String) As String", "description": "Converts to lowercase"},
	{"name": "InStr", "signature": "InStr([start], str1 As String, str2 As String) As Integer", "description": "Finds substring position"},
	{"name": "Replace", "signature": "Replace(str As String, find As String, replace As String) As String", "description": "Replaces occurrences"},
	{"name": "Split", "signature": "Split(str As String, [delimiter]) As String()", "description": "Splits string into array"},
	{"name": "Join", "signature": "Join(arr As String(), [delimiter]) As String", "description": "Joins array into string"},
	{"name": "StrComp", "signature": "StrComp(str1 As String, str2 As String) As Integer", "description": "Compares strings"},
	{"name": "String", "signature": "String(n As Integer, char As String) As String", "description": "Creates repeated character string"},
	{"name": "Space", "signature": "Space(n As Integer) As String", "description": "Creates string of n spaces"},
	{"name": "Chr", "signature": "Chr(code As Integer) As String", "description": "Returns character from ASCII code"},
	{"name": "Asc", "signature": "Asc(str As String) As Integer", "description": "Returns ASCII code of first character"},
	{"name": "Format", "signature": "Format(value, formatStr As String) As String", "description": "Formats a value"},
	
	# Math Functions
	{"name": "Abs", "signature": "Abs(n As Double) As Double", "description": "Returns absolute value"},
	{"name": "Int", "signature": "Int(n As Double) As Integer", "description": "Returns integer portion"},
	{"name": "Fix", "signature": "Fix(n As Double) As Integer", "description": "Truncates to integer"},
	{"name": "Sgn", "signature": "Sgn(n As Double) As Integer", "description": "Returns sign (-1, 0, 1)"},
	{"name": "Sqr", "signature": "Sqr(n As Double) As Double", "description": "Returns square root"},
	{"name": "Exp", "signature": "Exp(n As Double) As Double", "description": "Returns e^n"},
	{"name": "Log", "signature": "Log(n As Double) As Double", "description": "Returns natural logarithm"},
	{"name": "Sin", "signature": "Sin(angle As Double) As Double", "description": "Returns sine"},
	{"name": "Cos", "signature": "Cos(angle As Double) As Double", "description": "Returns cosine"},
	{"name": "Tan", "signature": "Tan(angle As Double) As Double", "description": "Returns tangent"},
	{"name": "Atn", "signature": "Atn(n As Double) As Double", "description": "Returns arctangent"},
	{"name": "Rnd", "signature": "Rnd([seed]) As Double", "description": "Returns random number 0-1"},
	{"name": "Round", "signature": "Round(n As Double, [decimals]) As Double", "description": "Rounds to nearest"},
	{"name": "Min", "signature": "Min(a, b) As Variant", "description": "Returns minimum value"},
	{"name": "Max", "signature": "Max(a, b) As Variant", "description": "Returns maximum value"},
	{"name": "Clamp", "signature": "Clamp(value, min, max) As Variant", "description": "Clamps value to range"},
	
	# Conversion Functions
	{"name": "CInt", "signature": "CInt(value) As Integer", "description": "Converts to Integer"},
	{"name": "CLng", "signature": "CLng(value) As Long", "description": "Converts to Long"},
	{"name": "CSng", "signature": "CSng(value) As Single", "description": "Converts to Single"},
	{"name": "CDbl", "signature": "CDbl(value) As Double", "description": "Converts to Double"},
	{"name": "CStr", "signature": "CStr(value) As String", "description": "Converts to String"},
	{"name": "CBool", "signature": "CBool(value) As Boolean", "description": "Converts to Boolean"},
	{"name": "Val", "signature": "Val(str As String) As Double", "description": "Converts string to number"},
	{"name": "Str", "signature": "Str(n As Double) As String", "description": "Converts number to string"},
	{"name": "Hex", "signature": "Hex(n As Integer) As String", "description": "Converts to hexadecimal"},
	{"name": "Oct", "signature": "Oct(n As Integer) As String", "description": "Converts to octal"},
	
	# Type Checking
	{"name": "IsNumeric", "signature": "IsNumeric(value) As Boolean", "description": "Checks if value is numeric"},
	{"name": "IsDate", "signature": "IsDate(value) As Boolean", "description": "Checks if value is a date"},
	{"name": "IsEmpty", "signature": "IsEmpty(value) As Boolean", "description": "Checks if value is Empty"},
	{"name": "IsNull", "signature": "IsNull(value) As Boolean", "description": "Checks if value is Null"},
	{"name": "IsObject", "signature": "IsObject(value) As Boolean", "description": "Checks if value is an object"},
	{"name": "IsArray", "signature": "IsArray(value) As Boolean", "description": "Checks if value is an array"},
	{"name": "TypeName", "signature": "TypeName(value) As String", "description": "Returns type name"},
	{"name": "VarType", "signature": "VarType(value) As Integer", "description": "Returns variant type code"},
	
	# Array Functions
	{"name": "Array", "signature": "Array(...) As Variant()", "description": "Creates array from arguments"},
	{"name": "UBound", "signature": "UBound(arr, [dimension]) As Integer", "description": "Returns upper bound"},
	{"name": "LBound", "signature": "LBound(arr, [dimension]) As Integer", "description": "Returns lower bound"},
	{"name": "Erase", "signature": "Erase arr", "description": "Clears array contents"},
	
	# Date/Time Functions
	{"name": "Now", "signature": "Now() As Date", "description": "Returns current date/time"},
	{"name": "Date", "signature": "Date() As Date", "description": "Returns current date"},
	{"name": "Time", "signature": "Time() As Date", "description": "Returns current time"},
	{"name": "Timer", "signature": "Timer() As Single", "description": "Returns seconds since midnight"},
	{"name": "Year", "signature": "Year(d As Date) As Integer", "description": "Returns year component"},
	{"name": "Month", "signature": "Month(d As Date) As Integer", "description": "Returns month component"},
	{"name": "Day", "signature": "Day(d As Date) As Integer", "description": "Returns day component"},
	{"name": "Hour", "signature": "Hour(d As Date) As Integer", "description": "Returns hour component"},
	{"name": "Minute", "signature": "Minute(d As Date) As Integer", "description": "Returns minute component"},
	{"name": "Second", "signature": "Second(d As Date) As Integer", "description": "Returns second component"},
	{"name": "DateAdd", "signature": "DateAdd(interval As String, n As Integer, d As Date) As Date", "description": "Adds interval to date"},
	{"name": "DateDiff", "signature": "DateDiff(interval As String, d1 As Date, d2 As Date) As Long", "description": "Returns difference between dates"},
	{"name": "Weekday", "signature": "Weekday(date, [firstDayOfWeek]) As Integer", "description": "Returns day of week (1=Sunday..7=Saturday)"},
	{"name": "WeekdayName", "signature": "WeekdayName(day As Integer, [abbreviate As Boolean]) As String", "description": "Returns name for day-of-week number"},
	{"name": "MonthName", "signature": "MonthName(month As Integer, [abbreviate As Boolean]) As String", "description": "Returns name for month number"},
	
	# File Functions
	{"name": "Dir", "signature": "Dir([path], [attributes]) As String", "description": "Returns matching filename"},
	{"name": "FileExists", "signature": "FileExists(path As String) As Boolean", "description": "Checks if file exists"},
	{"name": "Kill", "signature": "Kill path As String", "description": "Deletes a file"},
	{"name": "FileCopy", "signature": "FileCopy source As String, dest As String", "description": "Copies a file"},
	{"name": "MkDir", "signature": "MkDir path As String", "description": "Creates directory"},
	{"name": "RmDir", "signature": "RmDir path As String", "description": "Removes directory"},
	{"name": "ChDir", "signature": "ChDir path As String", "description": "Changes current directory"},
	{"name": "CurDir", "signature": "CurDir() As String", "description": "Returns current directory"},
	
	# Color Functions
	{"name": "RGB", "signature": "RGB(red As Integer, green As Integer, blue As Integer) As Color", "description": "Creates color from 0-255 RGB values"},
	{"name": "QBColor", "signature": "QBColor(index As Integer) As Long", "description": "Returns color from classic VB6 16-color palette (0-15)"},
	
	# System Functions
	{"name": "Environ", "signature": "Environ(varName As String) As String", "description": "Returns the value of an OS environment variable"},
	{"name": "Beep", "signature": "Beep", "description": "Produces a system beep sound"},
	
	# Godot Integration
	{"name": "get_node", "signature": "get_node(path As String) As Node", "description": "Gets node by path"},
	{"name": "preload", "signature": "preload(path As String) As Resource", "description": "Preloads a resource"},
	{"name": "load", "signature": "load(path As String) As Resource", "description": "Loads a resource"},
	{"name": "instance", "signature": "instance() As Node", "description": "Instances a PackedScene"},
]

# =============================================================================
# GODOT TYPES
# =============================================================================

const GODOT_TYPES: Array[String] = [
	# Core
	"Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Vector4i",
	"Rect2", "Rect2i", "Transform2D", "Transform3D",
	"Color", "Plane", "Quaternion", "Basis", "AABB",
	"RID", "Callable", "Signal", "NodePath", "StringName",
	
	# Nodes
	"Node", "Node2D", "Node3D", "Control", "Window",
	"Sprite2D", "Sprite3D", "AnimatedSprite2D", "AnimatedSprite3D",
	"Camera2D", "Camera3D", "Light2D", "Light3D",
	"AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D",
	"Area2D", "Area3D", "CharacterBody2D", "CharacterBody3D",
	"RigidBody2D", "RigidBody3D", "StaticBody2D", "StaticBody3D",
	"Timer", "AnimationPlayer", "Tween",
	
	# UI Controls
	"Button", "Label", "LineEdit", "TextEdit", "RichTextLabel",
	"CheckBox", "CheckButton", "OptionButton", "SpinBox",
	"HSlider", "VSlider", "HScrollBar", "VScrollBar",
	"ProgressBar", "TextureRect", "Panel", "PanelContainer",
	"TabContainer", "TabBar", "ScrollContainer", "MarginContainer",
	"HBoxContainer", "VBoxContainer", "GridContainer", "FlowContainer",
	"MenuBar", "PopupMenu", "FileDialog", "ColorPicker", "ColorPickerButton",
	"Tree", "ItemList", "GraphEdit", "GraphNode",
]

# =============================================================================
# CODE SNIPPETS
# =============================================================================

const SNIPPETS: Array[Dictionary] = [
	{"trigger": "sub", "code": "Sub ${1:Name}()\n\t${0}\nEnd Sub", "description": "Sub procedure"},
	{"trigger": "func", "code": "Function ${1:Name}(${2:params}) As ${3:Type}\n\t${0}\nEnd Function", "description": "Function"},
	{"trigger": "if", "code": "If ${1:condition} Then\n\t${0}\nEnd If", "description": "If statement"},
	{"trigger": "ifelse", "code": "If ${1:condition} Then\n\t${2}\nElse\n\t${0}\nEnd If", "description": "If-Else statement"},
	{"trigger": "for", "code": "For ${1:i} = ${2:1} To ${3:10}\n\t${0}\nNext", "description": "For loop"},
	{"trigger": "foreach", "code": "For Each ${1:item} In ${2:collection}\n\t${0}\nNext", "description": "For Each loop"},
	{"trigger": "while", "code": "While ${1:condition}\n\t${0}\nWend", "description": "While loop"},
	{"trigger": "dowhile", "code": "Do While ${1:condition}\n\t${0}\nLoop", "description": "Do While loop"},
	{"trigger": "select", "code": "Select Case ${1:expression}\n\tCase ${2:value}\n\t\t${0}\n\tCase Else\n\t\t\nEnd Select", "description": "Select Case"},
	{"trigger": "try", "code": "Try\n\t${0}\nCatch ex As Exception\n\t\nEnd Try", "description": "Try-Catch"},
	{"trigger": "class", "code": "Class ${1:Name}\n\tPrivate ${2:field} As ${3:Type}\n\t\n\tPublic Sub New()\n\t\t${0}\n\tEnd Sub\nEnd Class", "description": "Class definition"},
	{"trigger": "prop", "code": "Private _${1:name} As ${2:Type}\n\nPublic Property Get ${1:name}() As ${2:Type}\n\t${1:name} = _${1:name}\nEnd Property\n\nPublic Property Let ${1:name}(value As ${2:Type})\n\t_${1:name} = value\nEnd Property", "description": "Property with backing field"},
	{"trigger": "async", "code": "Async Function ${1:Name}() As Task\n\t${0}\nEnd Function", "description": "Async function"},
	{"trigger": "whenever", "code": "Whenever ${1:condition} Then\n\t${0}\nEnd Whenever", "description": "Whenever reactive block"},
]

# =============================================================================
# COMPLETION GENERATION
# =============================================================================

## Generates completion items for a given prefix
## @param prefix: The text before the cursor
## @param context: Additional context (current line, file, etc.)
## @returns: Array of completion dictionaries
static func get_completions(prefix: String, context: Dictionary = {}) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var prefix_lower = prefix.to_lower()
	
	# Keywords
	for keyword in VB6_KEYWORDS:
		if keyword.to_lower().begins_with(prefix_lower):
			results.append({
				"text": keyword,
				"kind": "keyword",
				"detail": "VB6 Keyword"
			})
	
	# Types
	for type_name in VB6_TYPES:
		if type_name.to_lower().begins_with(prefix_lower):
			results.append({
				"text": type_name,
				"kind": "type",
				"detail": "VB6 Type"
			})
	
	# Godot Types
	for type_name in GODOT_TYPES:
		if type_name.to_lower().begins_with(prefix_lower):
			results.append({
				"text": type_name,
				"kind": "type",
				"detail": "Godot Type"
			})
	
	# Built-in Functions
	for func_info in BUILTIN_FUNCTIONS:
		if func_info["name"].to_lower().begins_with(prefix_lower):
			results.append({
				"text": func_info["name"],
				"kind": "function",
				"detail": func_info["signature"],
				"documentation": func_info["description"]
			})
	
	# Snippets
	for snippet in SNIPPETS:
		if snippet["trigger"].to_lower().begins_with(prefix_lower):
			results.append({
				"text": snippet["trigger"],
				"kind": "snippet",
				"detail": snippet["description"],
				"insert_text": snippet["code"]
			})
	
	# Control names from context (if provided)
	if context.has("controls"):
		for ctrl_name in context["controls"]:
			if ctrl_name.to_lower().begins_with(prefix_lower):
				results.append({
					"text": ctrl_name,
					"kind": "field",
					"detail": "Form Control"
				})
	
	# Variables from context
	if context.has("variables"):
		for var_name in context["variables"]:
			if var_name.to_lower().begins_with(prefix_lower):
				results.append({
					"text": var_name,
					"kind": "variable",
					"detail": "Variable"
				})
	
	return results

## Generates method completions for a given object type
static func get_method_completions(type_name: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	
	# Common Control methods
	if type_name in ["Button", "Label", "LineEdit", "TextEdit", "Control"]:
		results.append_array([
			{"text": "show", "kind": "method", "detail": "show()"},
			{"text": "hide", "kind": "method", "detail": "hide()"},
			{"text": "set_visible", "kind": "method", "detail": "set_visible(visible: bool)"},
			{"text": "grab_focus", "kind": "method", "detail": "grab_focus()"},
			{"text": "release_focus", "kind": "method", "detail": "release_focus()"},
		])
	
	# Node methods (always available)
	results.append_array([
		{"text": "add_child", "kind": "method", "detail": "add_child(node: Node)"},
		{"text": "remove_child", "kind": "method", "detail": "remove_child(node: Node)"},
		{"text": "get_child", "kind": "method", "detail": "get_child(idx: int) As Node"},
		{"text": "get_children", "kind": "method", "detail": "get_children() As Array"},
		{"text": "get_parent", "kind": "method", "detail": "get_parent() As Node"},
		{"text": "queue_free", "kind": "method", "detail": "queue_free()"},
	])
	
	return results

## Gets property completions for a given object type
static func get_property_completions(type_name: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	
	# Control properties
	if type_name in ["Button", "Label", "LineEdit", "TextEdit", "Control"]:
		results.append_array([
			{"text": "text", "kind": "property", "detail": "String - Display text"},
			{"text": "visible", "kind": "property", "detail": "bool - Visibility"},
			{"text": "position", "kind": "property", "detail": "Vector2 - Position"},
			{"text": "size", "kind": "property", "detail": "Vector2 - Size"},
			{"text": "modulate", "kind": "property", "detail": "Color - Tint color"},
			{"text": "tooltip_text", "kind": "property", "detail": "String - Tooltip"},
		])
	
	# Node properties
	results.append_array([
		{"text": "name", "kind": "property", "detail": "String - Node name"},
		{"text": "owner", "kind": "property", "detail": "Node - Scene owner"},
	])
	
	return results
