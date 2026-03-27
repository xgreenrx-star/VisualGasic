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

# ClassDB completion cache { type_name → Array[Dictionary] }
static var _method_cache: Dictionary = {}
static var _property_cache: Dictionary = {}

# =============================================================================
# VB6 CONTROL TYPE → GODOT TYPE MAPPING
# =============================================================================

## Maps VB6-style control type names (from the Form Designer) to their
## underlying Godot class names for ClassDB lookup.
const VB6_CONTROL_TYPE_MAP: Dictionary = {
	# Standard VB6 controls → Godot equivalents
	"CommandButton": "Button", "Button": "Button",
	"TextBox": "LineEdit", "LineEdit": "LineEdit", "TextEdit": "TextEdit",
	"Label": "Label", "RichTextLabel": "RichTextLabel",
	"CheckBox": "CheckBox", "CheckButton": "CheckButton",
	"OptionButton": "OptionButton", "RadioButton": "CheckBox",
	"ListBox": "ItemList", "ItemList": "ItemList",
	"ComboBox": "OptionButton",
	"PictureBox": "TextureRect", "TextureRect": "TextureRect",
	"Image": "TextureRect",
	"Frame": "PanelContainer", "Panel": "Panel", "PanelContainer": "PanelContainer",
	"Timer": "Timer",
	"HScrollBar": "HScrollBar", "VScrollBar": "VScrollBar",
	"HSlider": "HSlider", "VSlider": "VSlider",
	"ProgressBar": "ProgressBar",
	"TabContainer": "TabContainer", "TabBar": "TabBar",
	"Tree": "Tree",
	"MenuBar": "MenuBar",
	"FileDialog": "FileDialog",
	"ColorPicker": "ColorPicker", "ColorPickerButton": "ColorPickerButton",
	"SpinBox": "SpinBox",
	"ScrollContainer": "ScrollContainer",
	"MarginContainer": "MarginContainer",
	"HBoxContainer": "HBoxContainer", "VBoxContainer": "VBoxContainer",
	"GridContainer": "GridContainer", "FlowContainer": "FlowContainer",
	"Sprite2D": "Sprite2D", "AnimatedSprite2D": "AnimatedSprite2D",
	"Camera2D": "Camera2D", "Camera3D": "Camera3D",
	"AudioStreamPlayer": "AudioStreamPlayer",
	"Area2D": "Area2D", "Area3D": "Area3D",
	"CharacterBody2D": "CharacterBody2D", "CharacterBody3D": "CharacterBody3D",
	"RigidBody2D": "RigidBody2D", "RigidBody3D": "RigidBody3D",
	"Line": "Line2D",
	"DriveListBox": "OptionButton",
	# Custom controls → base Control
	"WobblyButton": "Button",
}

# =============================================================================
# VB6-STYLE PROPERTY ALIASES — friendly names shown alongside Godot properties
# =============================================================================

## Extra VB6-friendly property names to show for controls.
## These are appended to the ClassDB results so VB6 users see familiar names.
const VB6_CONTROL_PROPERTIES: Dictionary = {
	"Button": [
		{"text": "Caption", "kind": "property", "detail": "String — Button text (alias for .text)"},
		{"text": "Enabled", "kind": "property", "detail": "Boolean — Whether the button is enabled (alias for .disabled inverted)"},
		{"text": "Visible", "kind": "property", "detail": "Boolean — Whether visible"},
		{"text": "ToolTipText", "kind": "property", "detail": "String — Tooltip on hover (alias for .tooltip_text)"},
		{"text": "Flat", "kind": "property", "detail": "Boolean — Flat style with no background"},
	],
	"Label": [
		{"text": "Caption", "kind": "property", "detail": "String — Label text (alias for .text)"},
		{"text": "Alignment", "kind": "property", "detail": "Integer — Text alignment"},
		{"text": "AutoSize", "kind": "property", "detail": "Boolean — Auto-size to fit text (alias for .autowrap_mode)"},
		{"text": "Visible", "kind": "property", "detail": "Boolean — Whether visible"},
	],
	"LineEdit": [
		{"text": "Text", "kind": "property", "detail": "String — Current text content"},
		{"text": "MaxLength", "kind": "property", "detail": "Integer — Maximum text length (alias for .max_length)"},
		{"text": "ReadOnly", "kind": "property", "detail": "Boolean — Prevent editing (alias for .editable inverted)"},
		{"text": "PasswordChar", "kind": "property", "detail": "String — Mask character (alias for .secret)"},
		{"text": "PlaceholderText", "kind": "property", "detail": "String — Placeholder text"},
		{"text": "Visible", "kind": "property", "detail": "Boolean — Whether visible"},
	],
	"TextEdit": [
		{"text": "Text", "kind": "property", "detail": "String — Full text content"},
		{"text": "ReadOnly", "kind": "property", "detail": "Boolean — Prevent editing (alias for .editable inverted)"},
		{"text": "WordWrap", "kind": "property", "detail": "Boolean — Wrap long lines (alias for .wrap_mode)"},
		{"text": "Visible", "kind": "property", "detail": "Boolean — Whether visible"},
		{"text": "SelectAll", "kind": "method", "detail": "select_all() — Select all text"},
	],
	"CheckBox": [
		{"text": "Caption", "kind": "property", "detail": "String — Checkbox label text (alias for .text)"},
		{"text": "Value", "kind": "property", "detail": "Boolean — Checked state (alias for .button_pressed)"},
		{"text": "Checked", "kind": "property", "detail": "Boolean — Whether checked (alias for .button_pressed)"},
		{"text": "Visible", "kind": "property", "detail": "Boolean — Whether visible"},
	],
	"OptionButton": [
		{"text": "ListIndex", "kind": "property", "detail": "Integer — Selected index (alias for .selected)"},
		{"text": "ListCount", "kind": "property", "detail": "Integer — Number of items (alias for .item_count)"},
		{"text": "Text", "kind": "property", "detail": "String — Text of selected item"},
		{"text": "AddItem", "kind": "method", "detail": "add_item(label: String) — Add an item"},
		{"text": "Clear", "kind": "method", "detail": "clear() — Remove all items"},
		{"text": "RemoveItem", "kind": "method", "detail": "remove_item(idx: Integer) — Remove item at index"},
		{"text": "Visible", "kind": "property", "detail": "Boolean — Whether visible"},
	],
	"ItemList": [
		{"text": "ListCount", "kind": "property", "detail": "Integer — Number of items (alias for .item_count)"},
		{"text": "ListIndex", "kind": "property", "detail": "Integer — Selected index"},
		{"text": "AddItem", "kind": "method", "detail": "add_item(text: String) — Add an item"},
		{"text": "Clear", "kind": "method", "detail": "clear() — Remove all items"},
		{"text": "RemoveItem", "kind": "method", "detail": "remove_item(idx: Integer) — Remove item by index"},
		{"text": "Visible", "kind": "property", "detail": "Boolean — Whether visible"},
	],
	"TextureRect": [
		{"text": "Picture", "kind": "property", "detail": "Texture2D — The image (alias for .texture)"},
		{"text": "Stretch", "kind": "property", "detail": "Integer — Stretch mode (alias for .stretch_mode)"},
		{"text": "Visible", "kind": "property", "detail": "Boolean — Whether visible"},
	],
	"Timer": [
		{"text": "Interval", "kind": "property", "detail": "Double — Seconds between ticks (alias for .wait_time)"},
		{"text": "Enabled", "kind": "property", "detail": "Boolean — Whether running (alias for .autostart / is stopped)"},
		{"text": "Start", "kind": "method", "detail": "start([time]) — Start the timer"},
		{"text": "Stop", "kind": "method", "detail": "stop() — Stop the timer"},
	],
	"ProgressBar": [
		{"text": "Value", "kind": "property", "detail": "Double — Current value"},
		{"text": "Min", "kind": "property", "detail": "Double — Minimum value (alias for .min_value)"},
		{"text": "Max", "kind": "property", "detail": "Double — Maximum value (alias for .max_value)"},
		{"text": "Visible", "kind": "property", "detail": "Boolean — Whether visible"},
	],
	"HSlider": [
		{"text": "Value", "kind": "property", "detail": "Double — Current value"},
		{"text": "Min", "kind": "property", "detail": "Double — Minimum value (alias for .min_value)"},
		{"text": "Max", "kind": "property", "detail": "Double — Maximum value (alias for .max_value)"},
		{"text": "Step", "kind": "property", "detail": "Double — Step size (alias for .step)"},
	],
	"VSlider": [
		{"text": "Value", "kind": "property", "detail": "Double — Current value"},
		{"text": "Min", "kind": "property", "detail": "Double — Minimum value (alias for .min_value)"},
		{"text": "Max", "kind": "property", "detail": "Double — Maximum value (alias for .max_value)"},
		{"text": "Step", "kind": "property", "detail": "Double — Step size (alias for .step)"},
	],
	"SpinBox": [
		{"text": "Value", "kind": "property", "detail": "Double — Current value"},
		{"text": "Min", "kind": "property", "detail": "Double — Minimum value (alias for .min_value)"},
		{"text": "Max", "kind": "property", "detail": "Double — Maximum value (alias for .max_value)"},
		{"text": "Step", "kind": "property", "detail": "Double — Step size (alias for .step)"},
	],
	"RichTextLabel": [
		{"text": "Text", "kind": "property", "detail": "String — BBCode text content"},
		{"text": "Clear", "kind": "method", "detail": "clear() — Remove all text"},
		{"text": "AppendText", "kind": "method", "detail": "append_text(bbcode: String) — Append BBCode text"},
		{"text": "Visible", "kind": "property", "detail": "Boolean — Whether visible"},
	],
}

# =============================================================================
# VB6 GLOBAL OBJECTS — App, Screen, Clipboard, Err, Debug, Printer
# =============================================================================

## Members available via dot-access on VB6 global objects.
const VB6_GLOBAL_OBJECTS: Dictionary = {
	"App": [
		{"text": "Title", "kind": "property", "detail": "String — Application title"},
		{"text": "Path", "kind": "property", "detail": "String — Application executable path"},
		{"text": "EXEName", "kind": "property", "detail": "String — Executable filename"},
		{"text": "Major", "kind": "property", "detail": "Integer — Major version number"},
		{"text": "Minor", "kind": "property", "detail": "Integer — Minor version number"},
		{"text": "Revision", "kind": "property", "detail": "Integer — Revision number"},
		{"text": "ProductName", "kind": "property", "detail": "String — Product name"},
		{"text": "CompanyName", "kind": "property", "detail": "String — Company name"},
		{"text": "LegalCopyright", "kind": "property", "detail": "String — Copyright text"},
		{"text": "Comments", "kind": "property", "detail": "String — Application comments"},
	],
	"Screen": [
		{"text": "Width", "kind": "property", "detail": "Integer — Screen width in pixels"},
		{"text": "Height", "kind": "property", "detail": "Integer — Screen height in pixels"},
		{"text": "TwipsPerPixelX", "kind": "property", "detail": "Double — Twips per pixel (horizontal)"},
		{"text": "TwipsPerPixelY", "kind": "property", "detail": "Double — Twips per pixel (vertical)"},
		{"text": "MousePointer", "kind": "property", "detail": "Integer — Current mouse cursor shape"},
		{"text": "ActiveForm", "kind": "property", "detail": "Form — Currently active form"},
		{"text": "ActiveControl", "kind": "property", "detail": "Control — Currently focused control"},
		{"text": "FontCount", "kind": "property", "detail": "Integer — Number of available fonts"},
		{"text": "Fonts", "kind": "property", "detail": "String() — Array of font names"},
	],
	"Clipboard": [
		{"text": "Clear", "kind": "method", "detail": "Clear() — Clears the clipboard"},
		{"text": "GetText", "kind": "method", "detail": "GetText() As String — Gets text from clipboard"},
		{"text": "SetText", "kind": "method", "detail": "SetText(text As String) — Sets text to clipboard"},
		{"text": "GetData", "kind": "method", "detail": "GetData(format) As Variant — Gets data in format"},
		{"text": "SetData", "kind": "method", "detail": "SetData(format, data) — Sets data in format"},
		{"text": "GetFormat", "kind": "method", "detail": "GetFormat(format) As Boolean — Checks if format available"},
	],
	"Err": [
		{"text": "Number", "kind": "property", "detail": "Integer — Error number (0 = no error)"},
		{"text": "Description", "kind": "property", "detail": "String — Error description text"},
		{"text": "Source", "kind": "property", "detail": "String — Source of the error"},
		{"text": "HelpFile", "kind": "property", "detail": "String — Help file for the error"},
		{"text": "HelpContext", "kind": "property", "detail": "Integer — Help context ID"},
		{"text": "Clear", "kind": "method", "detail": "Clear() — Clears the current error"},
		{"text": "Raise", "kind": "method", "detail": "Raise(number, [source], [description]) — Raises an error"},
	],
	"Debug": [
		{"text": "Print", "kind": "method", "detail": "Print(text As String) — Output to Immediate Window"},
		{"text": "Assert", "kind": "method", "detail": "Assert(condition As Boolean, [message]) — Break if false"},
	],
	"Printer": [
		{"text": "Print", "kind": "method", "detail": "Print(text As String) — Print text"},
		{"text": "NewPage", "kind": "method", "detail": "NewPage() — Start a new page"},
		{"text": "EndDoc", "kind": "method", "detail": "EndDoc() — Finish printing"},
		{"text": "KillDoc", "kind": "method", "detail": "KillDoc() — Cancel print job"},
	],
}

# =============================================================================
# VB6 STRING MEMBERS — for String variable dot-completion
# =============================================================================

const VB6_STRING_MEMBERS: Array[Dictionary] = [
	{"text": "Length", "kind": "property", "detail": "Integer — Number of characters (alias for Len())"},
	{"text": "ToUpper", "kind": "method", "detail": "ToUpper() As String — Convert to uppercase"},
	{"text": "ToLower", "kind": "method", "detail": "ToLower() As String — Convert to lowercase"},
	{"text": "Trim", "kind": "method", "detail": "Trim() As String — Remove leading/trailing whitespace"},
	{"text": "Contains", "kind": "method", "detail": "Contains(substr As String) As Boolean — Check if contains substring"},
	{"text": "StartsWith", "kind": "method", "detail": "StartsWith(prefix As String) As Boolean — Check if starts with prefix"},
	{"text": "EndsWith", "kind": "method", "detail": "EndsWith(suffix As String) As Boolean — Check if ends with suffix"},
	{"text": "Replace", "kind": "method", "detail": "Replace(find As String, replacement As String) As String — Replace occurrences"},
	{"text": "Split", "kind": "method", "detail": "Split(delimiter As String) As String() — Split into array"},
	{"text": "Substring", "kind": "method", "detail": "Substring(start As Integer, [length]) As String — Extract portion"},
	{"text": "IndexOf", "kind": "method", "detail": "IndexOf(substr As String) As Integer — Find position of substring"},
	{"text": "PadLeft", "kind": "method", "detail": "PadLeft(totalWidth As Integer, [padChar]) As String — Pad from left"},
	{"text": "PadRight", "kind": "method", "detail": "PadRight(totalWidth As Integer, [padChar]) As String — Pad from right"},
	{"text": "Insert", "kind": "method", "detail": "Insert(index As Integer, value As String) As String — Insert at position"},
	{"text": "Remove", "kind": "method", "detail": "Remove(start As Integer, [count]) As String — Remove characters"},
	{"text": "Chars", "kind": "method", "detail": "Chars(index As Integer) As String — Character at index"},
]

# =============================================================================
# VB6 COLLECTION / DICTIONARY MEMBERS
# =============================================================================

const VB6_COLLECTION_MEMBERS: Array[Dictionary] = [
	{"text": "Add", "kind": "method", "detail": "Add(item, [key], [before], [after]) — Add item to collection"},
	{"text": "Remove", "kind": "method", "detail": "Remove(index) — Remove item by index or key"},
	{"text": "Item", "kind": "method", "detail": "Item(index) As Variant — Get item by index or key"},
	{"text": "Count", "kind": "property", "detail": "Integer — Number of items"},
	{"text": "Clear", "kind": "method", "detail": "Clear() — Remove all items"},
]

const VB6_DICTIONARY_MEMBERS: Array[Dictionary] = [
	{"text": "Add", "kind": "method", "detail": "Add(key, item) — Add key-value pair"},
	{"text": "Remove", "kind": "method", "detail": "Remove(key) — Remove item by key"},
	{"text": "Item", "kind": "method", "detail": "Item(key) As Variant — Get/set item by key"},
	{"text": "Exists", "kind": "method", "detail": "Exists(key) As Boolean — Check if key exists"},
	{"text": "Count", "kind": "property", "detail": "Integer — Number of key-value pairs"},
	{"text": "Keys", "kind": "method", "detail": "Keys() As Variant() — Array of all keys"},
	{"text": "Items", "kind": "method", "detail": "Items() As Variant() — Array of all values"},
	{"text": "RemoveAll", "kind": "method", "detail": "RemoveAll() — Remove all items"},
	{"text": "CompareMode", "kind": "property", "detail": "Integer — Key comparison mode (0=Binary, 1=Text)"},
]

# =============================================================================
# VB6 FORM MEMBERS — shown for Me. and Form.
# =============================================================================

const VB6_FORM_MEMBERS: Array[Dictionary] = [
	{"text": "Caption", "kind": "property", "detail": "String — Form title bar text"},
	{"text": "BackColor", "kind": "property", "detail": "Color — Form background color"},
	{"text": "Width", "kind": "property", "detail": "Integer — Form width in pixels"},
	{"text": "Height", "kind": "property", "detail": "Integer — Form height in pixels"},
	{"text": "Left", "kind": "property", "detail": "Integer — Form left position"},
	{"text": "Top", "kind": "property", "detail": "Integer — Form top position"},
	{"text": "Visible", "kind": "property", "detail": "Boolean — Whether the form is visible"},
	{"text": "Enabled", "kind": "property", "detail": "Boolean — Whether the form accepts input"},
	{"text": "WindowState", "kind": "property", "detail": "Integer — 0=Normal, 1=Minimized, 2=Maximized"},
	{"text": "MousePointer", "kind": "property", "detail": "Integer — Mouse cursor shape"},
	{"text": "Name", "kind": "property", "detail": "String — Form name"},
	{"text": "ScaleWidth", "kind": "property", "detail": "Integer — Internal drawing width"},
	{"text": "ScaleHeight", "kind": "property", "detail": "Integer — Internal drawing height"},
	{"text": "Show", "kind": "method", "detail": "Show([modal]) — Display the form"},
	{"text": "Hide", "kind": "method", "detail": "Hide() — Hide the form"},
	{"text": "Refresh", "kind": "method", "detail": "Refresh() — Force repaint"},
	{"text": "Print", "kind": "method", "detail": "Print(text As String) — Print text on form surface"},
	{"text": "CLS", "kind": "method", "detail": "CLS() — Clear form drawing surface"},
	{"text": "Controls", "kind": "property", "detail": "Collection — All controls on the form"},
]

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
	
	# Drawing Commands — Primitives
	{"name": "DrawPixel", "signature": "DrawPixel(x As Double, y As Double, color As Color)", "description": "Draws a single pixel at the given position"},
	{"name": "PSet", "signature": "PSet(x As Double, y As Double, color As Color)", "description": "Draws a single pixel (VB6-style alias for DrawPixel)"},
	{"name": "DrawString", "signature": "DrawString(font As Font, position As Vector2, text As String, color As Color, [fontSize As Integer])", "description": "Draws text using a font object at the specified position"},
	{"name": "DrawTexture", "signature": "DrawTexture(texture As Texture2D, x As Double, y As Double, [modulate As Color])", "description": "Draws a texture at a position. Use with CreateTexture or LoadPicture"},
	{"name": "DrawTextureRect", "signature": "DrawTextureRect(texture As Texture2D, rect As Rect2, tile As Boolean, [modulate As Color])", "description": "Draws a texture stretched/tiled into a rectangle region"},
	{"name": "DrawArc", "signature": "DrawArc(x As Double, y As Double, radius As Double, startAngle As Double, endAngle As Double, [pointCount As Integer], [color As Color], [width As Double])", "description": "Draws an arc (partial circle outline) between two angles in radians"},
	{"name": "DrawPolygon", "signature": "DrawPolygon(points As Array, color As Color)", "description": "Draws a filled polygon from an array of Vector2 points"},
	{"name": "DrawPolyline", "signature": "DrawPolyline(points As Array, color As Color, [width As Double])", "description": "Draws a multi-segment line through an array of Vector2 points"},
	{"name": "SetDrawTransform", "signature": "SetDrawTransform(x As Double, y As Double, [rotation As Double], [scaleX As Double], [scaleY As Double])", "description": "Sets a 2D transform for all subsequent draw calls (translate, rotate, scale)"},
	{"name": "ResetDrawTransform", "signature": "ResetDrawTransform()", "description": "Resets the draw transform back to identity (no translation/rotation/scale)"},
	{"name": "QueueRedraw", "signature": "QueueRedraw()", "description": "Requests the node to redraw on the next frame. Call after changing visual state"},
	{"name": "CLS", "signature": "CLS()", "description": "Clears the screen / canvas. Removes dynamic child nodes and triggers redraw"},
	
	# Image Creation & Manipulation
	{"name": "CreateImage", "signature": "CreateImage(width As Integer, height As Integer, [fillColor As Color]) As Image", "description": "Creates a new RGBA8 Image object. Size clamped to 1-4096. Use with SetImagePixel/GetImagePixel"},
	{"name": "CreateTexture", "signature": "CreateTexture(imageOrWidth, [height As Integer], [fillColor As Color]) As ImageTexture", "description": "Creates an ImageTexture from an Image, or creates Image+Texture from width/height. Use with DrawTexture"},
	{"name": "ImageToTexture", "signature": "ImageToTexture(image As Image) As ImageTexture", "description": "Converts an Image object to an ImageTexture for rendering with DrawTexture"},
	{"name": "SetImagePixel", "signature": "SetImagePixel(image As Image, x As Integer, y As Integer, color As Color)", "description": "Sets a pixel color on an Image. Call UpdateTexture after to see changes on screen"},
	{"name": "GetImagePixel", "signature": "GetImagePixel(image As Image, x As Integer, y As Integer) As Color", "description": "Gets the color of a pixel from an Image. Returns Color with .r, .g, .b, .a (0.0-1.0)"},
	{"name": "FillImage", "signature": "FillImage(image As Image, color As Color)", "description": "Fills the entire Image with a solid color. Much faster than per-pixel SetImagePixel loops"},
	{"name": "FillImageRect", "signature": "FillImageRect(image As Image, rect As Rect2i, color As Color)", "description": "Fills a rectangular region of the Image with a color"},
	{"name": "BlitImage", "signature": "BlitImage(destImage As Image, srcImage As Image, srcRect As Rect2i, destPos As Vector2i)", "description": "Copies a rectangular region of pixels from one Image to another"},
	{"name": "UpdateTexture", "signature": "UpdateTexture(texture As ImageTexture, image As Image)", "description": "Pushes updated Image pixel data to an existing ImageTexture. Call after SetImagePixel changes"},
	{"name": "ImageWidth", "signature": "ImageWidth(image As Image) As Integer", "description": "Returns the width of an Image in pixels"},
	{"name": "ImageHeight", "signature": "ImageHeight(image As Image) As Integer", "description": "Returns the height of an Image in pixels"},
	{"name": "TextureWidth", "signature": "TextureWidth(texture As Texture2D) As Integer", "description": "Returns the width of a Texture2D in pixels"},
	{"name": "TextureHeight", "signature": "TextureHeight(texture As Texture2D) As Integer", "description": "Returns the height of a Texture2D in pixels"},
	{"name": "GetTextureImage", "signature": "GetTextureImage(texture As Texture2D) As Image", "description": "Extracts the Image data from an ImageTexture for pixel-level reading"},
	{"name": "SaveImage", "signature": "SaveImage(image As Image, path As String) As Boolean", "description": "Saves an Image to a PNG file. Returns True on success. Path should use user:// or res://"},
	{"name": "LoadImage", "signature": "LoadImage(path As String) As Image", "description": "Loads an image file (PNG, JPG, etc.) and returns it as an RGBA8 Image object"},
	
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
# GODOT API COMPLETIONS — common methods/properties used without dot-access
# =============================================================================

const GODOT_API_COMPLETIONS: Array[Dictionary] = [
	# CharacterBody2D / CharacterBody3D — Movement
	{"name": "move_and_slide", "signature": "move_and_slide() As Boolean", "description": "Moves the body based on velocity, sliding along collisions (CharacterBody2D/3D)"},
	{"name": "is_on_floor", "signature": "is_on_floor() As Boolean", "description": "True if on the floor after last move_and_slide (CharacterBody2D/3D)"},
	{"name": "is_on_wall", "signature": "is_on_wall() As Boolean", "description": "True if touching a wall after last move_and_slide (CharacterBody2D/3D)"},
	{"name": "is_on_ceiling", "signature": "is_on_ceiling() As Boolean", "description": "True if touching the ceiling after last move_and_slide (CharacterBody2D/3D)"},
	{"name": "get_slide_collision", "signature": "get_slide_collision(idx As Integer) As KinematicCollision2D", "description": "Returns collision info from last move_and_slide"},
	{"name": "get_slide_collision_count", "signature": "get_slide_collision_count() As Integer", "description": "Returns number of collisions from last move_and_slide"},

	# Node — Lifecycle callbacks
	{"name": "_ready", "signature": "Sub _Ready()", "description": "Called when the node enters the scene tree for the first time"},
	{"name": "_process", "signature": "Sub _Process(delta As Single)", "description": "Called every frame. delta = seconds since last frame"},
	{"name": "_physics_process", "signature": "Sub _PhysicsProcess(delta As Single)", "description": "Called every physics frame (default 60fps). Use for physics movement"},
	{"name": "_input", "signature": "Sub _Input(event As InputEvent)", "description": "Called on any input event (keyboard, mouse, gamepad)"},
	{"name": "_unhandled_input", "signature": "Sub _UnhandledInput(event As InputEvent)", "description": "Called for input not handled by _input or GUI"},
	{"name": "_draw", "signature": "Sub _Draw()", "description": "Called when the CanvasItem needs redrawing. Use draw_* commands inside"},
	{"name": "_enter_tree", "signature": "Sub _EnterTree()", "description": "Called when node enters the scene tree"},
	{"name": "_exit_tree", "signature": "Sub _ExitTree()", "description": "Called when node exits the scene tree"},

	# Node — Scene tree
	{"name": "get_node", "signature": "get_node(path As NodePath) As Node", "description": "Returns the node at the given path relative to this node"},
	{"name": "get_parent", "signature": "get_parent() As Node", "description": "Returns this node's parent"},
	{"name": "get_child", "signature": "get_child(idx As Integer) As Node", "description": "Returns a child node by index"},
	{"name": "get_children", "signature": "get_children() As Array", "description": "Returns all child nodes as an Array"},
	{"name": "get_child_count", "signature": "get_child_count() As Integer", "description": "Returns the number of child nodes"},
	{"name": "add_child", "signature": "add_child(node As Node)", "description": "Adds a child node to this node"},
	{"name": "remove_child", "signature": "remove_child(node As Node)", "description": "Removes a child node without freeing it"},
	{"name": "queue_free", "signature": "queue_free()", "description": "Queues this node for deletion at end of frame"},
	{"name": "get_tree", "signature": "get_tree() As SceneTree", "description": "Returns the SceneTree this node belongs to"},
	{"name": "is_inside_tree", "signature": "is_inside_tree() As Boolean", "description": "True if this node is currently in the scene tree"},
	{"name": "get_index", "signature": "get_index() As Integer", "description": "Returns this node's index among its siblings"},

	# Node2D — Transform
	{"name": "look_at", "signature": "look_at(target As Vector2)", "description": "Rotates to point at the target position (Node2D)"},
	{"name": "get_global_mouse_position", "signature": "get_global_mouse_position() As Vector2", "description": "Returns mouse position in global coordinates"},
	{"name": "to_local", "signature": "to_local(global_point As Vector2) As Vector2", "description": "Converts global coordinates to local"},
	{"name": "to_global", "signature": "to_global(local_point As Vector2) As Vector2", "description": "Converts local coordinates to global"},

	# CanvasItem — Visibility
	{"name": "show", "signature": "show()", "description": "Makes this node visible"},
	{"name": "hide", "signature": "hide()", "description": "Makes this node invisible"},
	{"name": "queue_redraw", "signature": "queue_redraw()", "description": "Requests a redraw — triggers _Draw() again"},
	{"name": "is_visible", "signature": "is_visible() As Boolean", "description": "Returns whether this node is visible"},

	# Object — Signals
	{"name": "connect", "signature": "connect(signal_name As String, callable As Callable)", "description": "Connects a signal to a callback"},
	{"name": "disconnect", "signature": "disconnect(signal_name As String, callable As Callable)", "description": "Disconnects a signal from a callback"},
	{"name": "emit_signal", "signature": "emit_signal(signal_name As String, ...)", "description": "Emits the given signal with optional arguments"},
	{"name": "is_connected", "signature": "is_connected(signal_name As String, callable As Callable) As Boolean", "description": "True if signal is connected to the callable"},

	# Node — Processing control
	{"name": "set_process", "signature": "set_process(enable As Boolean)", "description": "Enables or disables _Process for this node"},
	{"name": "set_physics_process", "signature": "set_physics_process(enable As Boolean)", "description": "Enables or disables _PhysicsProcess for this node"},
	{"name": "set_input_as_handled", "signature": "set_input_as_handled()", "description": "Marks input event as handled (stops propagation)"},

	# Input singleton
	{"name": "Input.is_action_pressed", "signature": "Input.is_action_pressed(action As String) As Boolean", "description": "True while the input action is held down"},
	{"name": "Input.is_action_just_pressed", "signature": "Input.is_action_just_pressed(action As String) As Boolean", "description": "True only on the frame the action was first pressed"},
	{"name": "Input.is_action_just_released", "signature": "Input.is_action_just_released(action As String) As Boolean", "description": "True only on the frame the action was released"},
	{"name": "Input.get_axis", "signature": "Input.get_axis(neg As String, pos As String) As Single", "description": "Returns a value between -1 and 1 for two opposing actions"},
	{"name": "Input.get_vector", "signature": "Input.get_vector(negX As String, posX As String, negY As String, posY As String) As Vector2", "description": "Returns a 2D input vector from four actions"},

	# PackedScene
	{"name": "instantiate", "signature": "instantiate() As Node", "description": "Creates an instance of a PackedScene"},

	# Timer
	{"name": "start", "signature": "start([time As Single])", "description": "Starts or restarts the Timer"},
	{"name": "stop", "signature": "stop()", "description": "Stops the Timer"},

	# Common properties (used directly on self)
	{"name": "velocity", "signature": "velocity As Vector2", "description": "Current velocity of a CharacterBody2D/3D"},
	{"name": "position", "signature": "position As Vector2", "description": "Position relative to parent (Node2D/Control)"},
	{"name": "global_position", "signature": "global_position As Vector2", "description": "Position in world coordinates (Node2D)"},
	{"name": "rotation", "signature": "rotation As Single", "description": "Rotation in radians (Node2D/Node3D)"},
	{"name": "rotation_degrees", "signature": "rotation_degrees As Single", "description": "Rotation in degrees (Node2D/Node3D)"},
	{"name": "scale", "signature": "scale As Vector2", "description": "Scale of the node (Node2D/Node3D)"},
	{"name": "visible", "signature": "visible As Boolean", "description": "Whether the node is visible (CanvasItem/Node3D)"},
	{"name": "modulate", "signature": "modulate As Color", "description": "Color tint applied to this node and children"},
	{"name": "self_modulate", "signature": "self_modulate As Color", "description": "Color tint applied to this node only (not children)"},
	{"name": "z_index", "signature": "z_index As Integer", "description": "Drawing order. Higher = drawn on top"},
	{"name": "name", "signature": "name As String", "description": "The name of this node in the scene tree"},
	{"name": "process_mode", "signature": "process_mode As Integer", "description": "Controls when this node processes (inherit/pausable/always/disabled)"},
]

# =============================================================================
# VARIANT TYPE MEMBERS (not in ClassDB)
# =============================================================================

const VARIANT_METHODS: Dictionary = {
	"Vector2": [
		{"text": "length", "kind": "method", "detail": "length() → Double"},
		{"text": "length_squared", "kind": "method", "detail": "length_squared() → Double"},
		{"text": "normalized", "kind": "method", "detail": "normalized() → Vector2"},
		{"text": "is_normalized", "kind": "method", "detail": "is_normalized() → Boolean"},
		{"text": "distance_to", "kind": "method", "detail": "distance_to(to: Vector2) → Double"},
		{"text": "angle", "kind": "method", "detail": "angle() → Double"},
		{"text": "angle_to", "kind": "method", "detail": "angle_to(to: Vector2) → Double"},
		{"text": "dot", "kind": "method", "detail": "dot(with: Vector2) → Double"},
		{"text": "cross", "kind": "method", "detail": "cross(with: Vector2) → Double"},
		{"text": "lerp", "kind": "method", "detail": "lerp(to: Vector2, weight: Double) → Vector2"},
		{"text": "slerp", "kind": "method", "detail": "slerp(to: Vector2, weight: Double) → Vector2"},
		{"text": "move_toward", "kind": "method", "detail": "move_toward(to: Vector2, delta: Double) → Vector2"},
		{"text": "rotated", "kind": "method", "detail": "rotated(angle: Double) → Vector2"},
		{"text": "abs", "kind": "method", "detail": "abs() → Vector2"},
		{"text": "sign", "kind": "method", "detail": "sign() → Vector2"},
		{"text": "floor", "kind": "method", "detail": "floor() → Vector2"},
		{"text": "ceil", "kind": "method", "detail": "ceil() → Vector2"},
		{"text": "round", "kind": "method", "detail": "round() → Vector2"},
		{"text": "clamp", "kind": "method", "detail": "clamp(min: Vector2, max: Vector2) → Vector2"},
		{"text": "snapped", "kind": "method", "detail": "snapped(step: Vector2) → Vector2"},
	],
	"Vector2i": [
		{"text": "length", "kind": "method", "detail": "length() → Double"},
		{"text": "abs", "kind": "method", "detail": "abs() → Vector2i"},
		{"text": "sign", "kind": "method", "detail": "sign() → Vector2i"},
		{"text": "clamp", "kind": "method", "detail": "clamp(min: Vector2i, max: Vector2i) → Vector2i"},
	],
	"Vector3": [
		{"text": "length", "kind": "method", "detail": "length() → Double"},
		{"text": "length_squared", "kind": "method", "detail": "length_squared() → Double"},
		{"text": "normalized", "kind": "method", "detail": "normalized() → Vector3"},
		{"text": "is_normalized", "kind": "method", "detail": "is_normalized() → Boolean"},
		{"text": "distance_to", "kind": "method", "detail": "distance_to(to: Vector3) → Double"},
		{"text": "dot", "kind": "method", "detail": "dot(with: Vector3) → Double"},
		{"text": "cross", "kind": "method", "detail": "cross(with: Vector3) → Vector3"},
		{"text": "lerp", "kind": "method", "detail": "lerp(to: Vector3, weight: Double) → Vector3"},
		{"text": "slerp", "kind": "method", "detail": "slerp(to: Vector3, weight: Double) → Vector3"},
		{"text": "move_toward", "kind": "method", "detail": "move_toward(to: Vector3, delta: Double) → Vector3"},
		{"text": "rotated", "kind": "method", "detail": "rotated(axis: Vector3, angle: Double) → Vector3"},
		{"text": "abs", "kind": "method", "detail": "abs() → Vector3"},
		{"text": "sign", "kind": "method", "detail": "sign() → Vector3"},
		{"text": "floor", "kind": "method", "detail": "floor() → Vector3"},
		{"text": "ceil", "kind": "method", "detail": "ceil() → Vector3"},
		{"text": "round", "kind": "method", "detail": "round() → Vector3"},
		{"text": "clamp", "kind": "method", "detail": "clamp(min: Vector3, max: Vector3) → Vector3"},
		{"text": "snapped", "kind": "method", "detail": "snapped(step: Vector3) → Vector3"},
	],
	"Vector3i": [
		{"text": "length", "kind": "method", "detail": "length() → Double"},
		{"text": "abs", "kind": "method", "detail": "abs() → Vector3i"},
		{"text": "sign", "kind": "method", "detail": "sign() → Vector3i"},
		{"text": "clamp", "kind": "method", "detail": "clamp(min: Vector3i, max: Vector3i) → Vector3i"},
	],
	"Color": [
		{"text": "to_html", "kind": "method", "detail": "to_html(with_alpha: Boolean) → String"},
		{"text": "lerp", "kind": "method", "detail": "lerp(to: Color, weight: Double) → Color"},
		{"text": "lightened", "kind": "method", "detail": "lightened(amount: Double) → Color"},
		{"text": "darkened", "kind": "method", "detail": "darkened(amount: Double) → Color"},
		{"text": "inverted", "kind": "method", "detail": "inverted() → Color"},
		{"text": "clamp", "kind": "method", "detail": "clamp(min: Color, max: Color) → Color"},
	],
	"Rect2": [
		{"text": "has_point", "kind": "method", "detail": "has_point(point: Vector2) → Boolean"},
		{"text": "intersects", "kind": "method", "detail": "intersects(b: Rect2) → Boolean"},
		{"text": "intersection", "kind": "method", "detail": "intersection(b: Rect2) → Rect2"},
		{"text": "merge", "kind": "method", "detail": "merge(b: Rect2) → Rect2"},
		{"text": "expand", "kind": "method", "detail": "expand(to: Vector2) → Rect2"},
		{"text": "grow", "kind": "method", "detail": "grow(amount: Double) → Rect2"},
		{"text": "abs", "kind": "method", "detail": "abs() → Rect2"},
		{"text": "get_area", "kind": "method", "detail": "get_area() → Double"},
		{"text": "has_area", "kind": "method", "detail": "has_area() → Boolean"},
	],
	"Rect2i": [
		{"text": "has_point", "kind": "method", "detail": "has_point(point: Vector2i) → Boolean"},
		{"text": "intersects", "kind": "method", "detail": "intersects(b: Rect2i) → Boolean"},
		{"text": "intersection", "kind": "method", "detail": "intersection(b: Rect2i) → Rect2i"},
		{"text": "merge", "kind": "method", "detail": "merge(b: Rect2i) → Rect2i"},
		{"text": "expand", "kind": "method", "detail": "expand(to: Vector2i) → Rect2i"},
		{"text": "grow", "kind": "method", "detail": "grow(amount: Integer) → Rect2i"},
		{"text": "get_area", "kind": "method", "detail": "get_area() → Integer"},
		{"text": "has_area", "kind": "method", "detail": "has_area() → Boolean"},
	],
	"Transform2D": [
		{"text": "affine_inverse", "kind": "method", "detail": "affine_inverse() → Transform2D"},
		{"text": "inverse", "kind": "method", "detail": "inverse() → Transform2D"},
		{"text": "rotated", "kind": "method", "detail": "rotated(angle: Double) → Transform2D"},
		{"text": "scaled", "kind": "method", "detail": "scaled(scale: Vector2) → Transform2D"},
		{"text": "translated", "kind": "method", "detail": "translated(offset: Vector2) → Transform2D"},
		{"text": "get_origin", "kind": "method", "detail": "get_origin() → Vector2"},
		{"text": "get_rotation", "kind": "method", "detail": "get_rotation() → Double"},
		{"text": "get_scale", "kind": "method", "detail": "get_scale() → Vector2"},
	],
	"NodePath": [
		{"text": "get_name", "kind": "method", "detail": "get_name(idx: Integer) → StringName"},
		{"text": "get_name_count", "kind": "method", "detail": "get_name_count() → Integer"},
		{"text": "get_subname", "kind": "method", "detail": "get_subname(idx: Integer) → StringName"},
		{"text": "get_subname_count", "kind": "method", "detail": "get_subname_count() → Integer"},
		{"text": "is_empty", "kind": "method", "detail": "is_empty() → Boolean"},
		{"text": "is_absolute", "kind": "method", "detail": "is_absolute() → Boolean"},
	],
	"AABB": [
		{"text": "has_point", "kind": "method", "detail": "has_point(point: Vector3) → Boolean"},
		{"text": "intersects", "kind": "method", "detail": "intersects(with: AABB) → Boolean"},
		{"text": "intersection", "kind": "method", "detail": "intersection(with: AABB) → AABB"},
		{"text": "merge", "kind": "method", "detail": "merge(with: AABB) → AABB"},
		{"text": "expand", "kind": "method", "detail": "expand(to: Vector3) → AABB"},
		{"text": "grow", "kind": "method", "detail": "grow(by: Double) → AABB"},
		{"text": "get_volume", "kind": "method", "detail": "get_volume() → Double"},
		{"text": "has_volume", "kind": "method", "detail": "has_volume() → Boolean"},
		{"text": "abs", "kind": "method", "detail": "abs() → AABB"},
	],
}

const VARIANT_PROPERTIES: Dictionary = {
	"Vector2": [
		{"text": "x", "kind": "property", "detail": "Double — X component"},
		{"text": "y", "kind": "property", "detail": "Double — Y component"},
	],
	"Vector2i": [
		{"text": "x", "kind": "property", "detail": "Integer — X component"},
		{"text": "y", "kind": "property", "detail": "Integer — Y component"},
	],
	"Vector3": [
		{"text": "x", "kind": "property", "detail": "Double — X component"},
		{"text": "y", "kind": "property", "detail": "Double — Y component"},
		{"text": "z", "kind": "property", "detail": "Double — Z component"},
	],
	"Vector3i": [
		{"text": "x", "kind": "property", "detail": "Integer — X component"},
		{"text": "y", "kind": "property", "detail": "Integer — Y component"},
		{"text": "z", "kind": "property", "detail": "Integer — Z component"},
	],
	"Vector4": [
		{"text": "x", "kind": "property", "detail": "Double — X component"},
		{"text": "y", "kind": "property", "detail": "Double — Y component"},
		{"text": "z", "kind": "property", "detail": "Double — Z component"},
		{"text": "w", "kind": "property", "detail": "Double — W component"},
	],
	"Color": [
		{"text": "r", "kind": "property", "detail": "Double — Red (0.0–1.0)"},
		{"text": "g", "kind": "property", "detail": "Double — Green (0.0–1.0)"},
		{"text": "b", "kind": "property", "detail": "Double — Blue (0.0–1.0)"},
		{"text": "a", "kind": "property", "detail": "Double — Alpha (0.0–1.0)"},
		{"text": "r8", "kind": "property", "detail": "Integer — Red (0–255)"},
		{"text": "g8", "kind": "property", "detail": "Integer — Green (0–255)"},
		{"text": "b8", "kind": "property", "detail": "Integer — Blue (0–255)"},
		{"text": "a8", "kind": "property", "detail": "Integer — Alpha (0–255)"},
		{"text": "h", "kind": "property", "detail": "Double — Hue"},
		{"text": "s", "kind": "property", "detail": "Double — Saturation"},
		{"text": "v", "kind": "property", "detail": "Double — Value"},
	],
	"Rect2": [
		{"text": "position", "kind": "property", "detail": "Vector2 — Top-left corner"},
		{"text": "size", "kind": "property", "detail": "Vector2 — Width and height"},
		{"text": "end", "kind": "property", "detail": "Vector2 — Bottom-right corner"},
	],
	"Rect2i": [
		{"text": "position", "kind": "property", "detail": "Vector2i — Top-left corner"},
		{"text": "size", "kind": "property", "detail": "Vector2i — Width and height"},
		{"text": "end", "kind": "property", "detail": "Vector2i — Bottom-right corner"},
	],
	"Transform2D": [
		{"text": "origin", "kind": "property", "detail": "Vector2 — Translation"},
		{"text": "x", "kind": "property", "detail": "Vector2 — X basis vector"},
		{"text": "y", "kind": "property", "detail": "Vector2 — Y basis vector"},
	],
	"AABB": [
		{"text": "position", "kind": "property", "detail": "Vector3 — Origin"},
		{"text": "size", "kind": "property", "detail": "Vector3 — Size"},
		{"text": "end", "kind": "property", "detail": "Vector3 — End point"},
	],
}

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
	
	# Godot API methods/properties (common game-dev calls)
	for api_info in GODOT_API_COMPLETIONS:
		if api_info["name"].to_lower().begins_with(prefix_lower):
			results.append({
				"text": api_info["name"],
				"kind": "function" if "(" in api_info["signature"] else "property",
				"detail": api_info["signature"],
				"documentation": api_info["description"]
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
	
	# Imported module names and their public symbols (v4.3.0)
	if context.has("imported_modules"):
		for mod_info in context["imported_modules"]:
			var mod_name: String = mod_info.get("name", "")
			if mod_name.to_lower().begins_with(prefix_lower):
				results.append({
					"text": mod_name,
					"kind": "module",
					"detail": "Imported Module"
				})
			# Also add public subs/functions directly (unqualified)
			if mod_info.has("subs"):
				for sub_name in mod_info["subs"]:
					if sub_name.to_lower().begins_with(prefix_lower):
						results.append({
							"text": sub_name,
							"kind": "function",
							"detail": "From " + mod_name
						})
	
	# Dot-completion for imported modules: ModuleName.
	if context.has("imported_modules") and context.has("dot_base"):
		var dot_base: String = context["dot_base"]
		for mod_info in context["imported_modules"]:
			if mod_info.get("name", "").nocasecmp_to(dot_base) == 0:
				if mod_info.has("subs"):
					for sub_name in mod_info["subs"]:
						results.append({
							"text": sub_name,
							"kind": "function",
							"detail": mod_info["name"] + "." + sub_name + "()"
						})
				if mod_info.has("variables"):
					for var_name in mod_info["variables"]:
						results.append({
							"text": var_name,
							"kind": "property",
							"detail": mod_info["name"] + "." + var_name
						})
				if mod_info.has("constants"):
					for const_name in mod_info["constants"]:
						results.append({
							"text": const_name,
							"kind": "constant",
							"detail": mod_info["name"] + "." + const_name
						})
	
	return results

## Generates method completions for a given object type.
## Uses ClassDB for Godot Object-derived types, hardcoded data for Variant types.
static func get_method_completions(type_name: String) -> Array[Dictionary]:
	# Check cache first
	if _method_cache.has(type_name):
		return _method_cache[type_name]
	
	var results: Array[Dictionary] = []
	
	# Variant types (not in ClassDB)
	if VARIANT_METHODS.has(type_name):
		results.append_array(VARIANT_METHODS[type_name])
		_method_cache[type_name] = results
		return results
	
	# ClassDB for Object-derived types (Node, Control, Sprite2D, etc.)
	if ClassDB.class_exists(type_name):
		var methods := ClassDB.class_get_method_list(type_name, false)
		for method in methods:
			var mname: String = method["name"]
			if mname.begins_with("_"):
				continue
			var args_str := _format_method_args(method)
			var ret: Dictionary = method.get("return", {})
			var ret_type: String = _type_id_to_name(ret.get("type", 0), ret.get("class_name", ""))
			var detail := mname + "(" + args_str + ")"
			if ret_type != "void":
				detail += " → " + ret_type
			results.append({"text": mname, "kind": "method", "detail": detail})
		
		# Signals
		var signals := ClassDB.class_get_signal_list(type_name, false)
		for sig in signals:
			var sname: String = sig["name"]
			if sname.begins_with("_"):
				continue
			results.append({"text": sname, "kind": "signal", "detail": "Signal: " + sname})
	else:
		# Unknown type — fallback to basic Node methods
		results.append_array([
			{"text": "add_child", "kind": "method", "detail": "add_child(node: Node)"},
			{"text": "remove_child", "kind": "method", "detail": "remove_child(node: Node)"},
			{"text": "get_child", "kind": "method", "detail": "get_child(idx: Integer) → Node"},
			{"text": "get_children", "kind": "method", "detail": "get_children() → Array"},
			{"text": "get_parent", "kind": "method", "detail": "get_parent() → Node"},
			{"text": "queue_free", "kind": "method", "detail": "queue_free()"},
		])
	
	_method_cache[type_name] = results
	return results

## Formats ClassDB method arguments into a readable string.
static func _format_method_args(method: Dictionary) -> String:
	var args: Array = method.get("args", [])
	var parts: PackedStringArray = []
	for arg in args:
		var aname: String = arg.get("name", "")
		var atype: String = _type_id_to_name(arg.get("type", 0), arg.get("class_name", ""))
		parts.append(aname + ": " + atype)
	return ", ".join(parts)

## Converts a Variant type id + class_name to a VB6-friendly display name.
static func _type_id_to_name(type_id: int, class_name_str: String) -> String:
	if not class_name_str.is_empty():
		return class_name_str
	match type_id:
		TYPE_NIL: return "void"
		TYPE_BOOL: return "Boolean"
		TYPE_INT: return "Integer"
		TYPE_FLOAT: return "Double"
		TYPE_STRING: return "String"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR2I: return "Vector2i"
		TYPE_VECTOR3: return "Vector3"
		TYPE_VECTOR3I: return "Vector3i"
		TYPE_VECTOR4: return "Vector4"
		TYPE_VECTOR4I: return "Vector4i"
		TYPE_RECT2: return "Rect2"
		TYPE_RECT2I: return "Rect2i"
		TYPE_TRANSFORM2D: return "Transform2D"
		TYPE_TRANSFORM3D: return "Transform3D"
		TYPE_COLOR: return "Color"
		TYPE_NODE_PATH: return "NodePath"
		TYPE_STRING_NAME: return "StringName"
		TYPE_OBJECT: return "Object"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_ARRAY: return "Array"
		TYPE_CALLABLE: return "Callable"
		TYPE_SIGNAL: return "Signal"
		TYPE_PACKED_BYTE_ARRAY: return "Array(Byte)"
		TYPE_PACKED_INT32_ARRAY: return "Array(Integer)"
		TYPE_PACKED_FLOAT32_ARRAY: return "Array(Single)"
		TYPE_PACKED_STRING_ARRAY: return "Array(String)"
		TYPE_PACKED_VECTOR2_ARRAY: return "Array(Vector2)"
		TYPE_PACKED_VECTOR3_ARRAY: return "Array(Vector3)"
		TYPE_PACKED_COLOR_ARRAY: return "Array(Color)"
		_: return "Variant"

## Gets property completions for a given object type.
## Uses ClassDB for Godot Object-derived types, hardcoded data for Variant types.
static func get_property_completions(type_name: String) -> Array[Dictionary]:
	# Check cache first
	if _property_cache.has(type_name):
		return _property_cache[type_name]
	
	var results: Array[Dictionary] = []
	
	# Variant types (not in ClassDB)
	if VARIANT_PROPERTIES.has(type_name):
		results.append_array(VARIANT_PROPERTIES[type_name])
		_property_cache[type_name] = results
		return results
	
	# ClassDB for Object-derived types
	if ClassDB.class_exists(type_name):
		var props := ClassDB.class_get_property_list(type_name, false)
		for prop in props:
			var pname: String = prop.get("name", "")
			if pname.is_empty() or pname.begins_with("_") or "/" in pname:
				continue
			var usage: int = prop.get("usage", 0)
			# Skip category/group/subgroup headers
			if usage & PROPERTY_USAGE_CATEGORY or usage & PROPERTY_USAGE_GROUP or usage & PROPERTY_USAGE_SUBGROUP:
				continue
			var ptype: String = _type_id_to_name(prop.get("type", 0), prop.get("class_name", ""))
			results.append({"text": pname, "kind": "property", "detail": ptype + " — " + pname})
	else:
		# Unknown type — fallback
		results.append_array([
			{"text": "name", "kind": "property", "detail": "String — Node name"},
			{"text": "owner", "kind": "property", "detail": "Node — Scene owner"},
		])
	
	_property_cache[type_name] = results
	return results

# =============================================================================
# VB6 DOT-COMPLETION HELPERS
# =============================================================================

## Resolves a VB6 form-designer control type to a Godot class name.
## e.g. "CommandButton" → "Button", "TextBox" → "LineEdit"
static func resolve_control_type(vb6_type: String) -> String:
	if VB6_CONTROL_TYPE_MAP.has(vb6_type):
		return VB6_CONTROL_TYPE_MAP[vb6_type]
	# Try direct — already a Godot class name
	if ClassDB.class_exists(vb6_type):
		return vb6_type
	return "Control"  # safe fallback

## Returns VB6-friendly property aliases for a Godot control type.
## These are shown at the top of the completion list with VB6-style names.
static func get_vb6_property_aliases(godot_type: String) -> Array:
	if VB6_CONTROL_PROPERTIES.has(godot_type):
		return VB6_CONTROL_PROPERTIES[godot_type]
	return []

## Returns members for a VB6 global object (App, Screen, Err, etc.)
## Returns empty array if name is not a known global object.
static func get_global_object_members(obj_name: String) -> Array:
	# Case-insensitive lookup
	for key in VB6_GLOBAL_OBJECTS:
		if key.nocasecmp_to(obj_name) == 0:
			return VB6_GLOBAL_OBJECTS[key]
	return []

## Returns true if the name is a VB6 global object.
static func is_global_object(name: String) -> bool:
	for key in VB6_GLOBAL_OBJECTS:
		if key.nocasecmp_to(name) == 0:
			return true
	return false

## Returns form-level members (for Me. completion).
static func get_form_members() -> Array[Dictionary]:
	return VB6_FORM_MEMBERS

## Returns String type members (for String variable dot-completion).
static func get_string_members() -> Array[Dictionary]:
	return VB6_STRING_MEMBERS

## Returns Collection members.
static func get_collection_members() -> Array[Dictionary]:
	return VB6_COLLECTION_MEMBERS

## Returns Dictionary members.
static func get_dictionary_members() -> Array[Dictionary]:
	return VB6_DICTIONARY_MEMBERS

## Resolves the return type of a member (property or method) on a given type.
## This powers chained dot-completion: Text1.Text. → String members.
## Returns "" if the member is not found, "void" for methods with no return.
static func resolve_member_type(type_name: String, member_name: String) -> String:
	var member_lower := member_name.to_lower()
	
	# ── 0. GlobalObject: prefix (e.g. "GlobalObject:App") ──
	if type_name.begins_with("GlobalObject:"):
		var obj_name := type_name.substr(len("GlobalObject:"))
		var members := get_global_object_members(obj_name)
		for m in members:
			if m["text"].to_lower() == member_lower:
				return _extract_type_from_detail(m["detail"])
		return ""
	
	# ── 1. VB6 String members ──
	if type_name == "String":
		for m in VB6_STRING_MEMBERS:
			if m["text"].to_lower() == member_lower:
				return _extract_type_from_detail(m["detail"])
		return ""
	
	# ── 2. VB6 Collection members ──
	if type_name == "Collection":
		for m in VB6_COLLECTION_MEMBERS:
			if m["text"].to_lower() == member_lower:
				return _extract_type_from_detail(m["detail"])
		return ""
	
	# ── 3. VB6 Dictionary members ──
	if type_name == "Dictionary":
		for m in VB6_DICTIONARY_MEMBERS:
			if m["text"].to_lower() == member_lower:
				return _extract_type_from_detail(m["detail"])
		return ""
	
	# ── 4. VB6 Form members ──
	for m in VB6_FORM_MEMBERS:
		if m["text"].to_lower() == member_lower:
			return _extract_type_from_detail(m["detail"])
	
	# ── 5. Resolve VB6 type → Godot type for ClassDB ──
	var godot_type := type_name
	if VB6_CONTROL_TYPE_MAP.has(type_name):
		godot_type = VB6_CONTROL_TYPE_MAP[type_name]
	
	# ── 6. VB6 control property aliases ──
	if VB6_CONTROL_PROPERTIES.has(godot_type):
		for alias in VB6_CONTROL_PROPERTIES[godot_type]:
			if alias["text"].to_lower() == member_lower:
				return _extract_type_from_detail(alias["detail"])
	
	# ── 7. Variant type methods (Vector2, Color, Rect2, etc.) ──
	if VARIANT_METHODS.has(godot_type):
		for m in VARIANT_METHODS[godot_type]:
			if m["text"].to_lower() == member_lower:
				return _extract_return_from_method_detail(m["detail"])
	
	# ── 8. Variant type properties ──
	if VARIANT_PROPERTIES.has(godot_type):
		for p in VARIANT_PROPERTIES[godot_type]:
			if p["text"].to_lower() == member_lower:
				return _extract_type_from_detail(p["detail"])
	
	# ── 9. ClassDB method return types ──
	if ClassDB.class_exists(godot_type):
		var methods := ClassDB.class_get_method_list(godot_type, true)
		for method in methods:
			var mname: String = method["name"]
			if mname.to_lower() == member_lower:
				var ret: Dictionary = method.get("return", {})
				var ret_class: String = ret.get("class_name", "")
				var ret_type_id: int = ret.get("type", 0)
				var ret_type := _type_id_to_name(ret_type_id, ret_class)
				if ret_type == "void":
					return "void"
				return ret_type
		
		# ── 10. ClassDB property types ──
		var props := ClassDB.class_get_property_list(godot_type, true)
		for prop in props:
			var pname: String = prop.get("name", "")
			if pname.to_lower() == member_lower:
				var pclass: String = prop.get("class_name", "")
				var ptype_id: int = prop.get("type", 0)
				return _type_id_to_name(ptype_id, pclass)
	
	return ""

## Extracts the type name from a VB6-style detail string.
## "String — Button text"     → "String"
## "Integer — Number of items" → "Integer"
## "Boolean — Whether visible" → "Boolean"
## "Collection — All controls" → "Collection"
static func _extract_type_from_detail(detail: String) -> String:
	# VB6 property details use "Type — Description" format
	if " — " in detail:
		var type_part := detail.get_slice(" — ", 0).strip_edges()
		# Handle parenthesized array types: "Variant()" → "Array"
		if type_part.ends_with("()"):
			return "Array"
		return type_part
	# Method details: "method() As ReturnType — desc" or just "ReturnType — desc"
	return "Variant"

## Extracts the return type from a method detail signature.
## "ToUpper() As String — Convert to uppercase" → "String"
## "Split(delimiter As String) As String() — ..." → "Array"
## "add_child(node: Node)" → "void"
## "get_child(idx: Integer) → Node" → "Node"
static func _extract_return_from_method_detail(detail: String) -> String:
	# Check for " As " return type (VB6-style)
	if " As " in detail:
		var after_as := detail.rsplit(" As ", true, 1)
		if after_as.size() > 1:
			var ret_part := after_as[1].strip_edges()
			# Strip description after " — "
			if " — " in ret_part:
				ret_part = ret_part.get_slice(" — ", 0).strip_edges()
			if ret_part.ends_with("()"):
				return "Array"
			return ret_part
	# Check for " → " return type (Godot-style)
	if " → " in detail:
		var after_arrow := detail.rsplit(" → ", true, 1)
		if after_arrow.size() > 1:
			return after_arrow[1].strip_edges()
	return "void"
