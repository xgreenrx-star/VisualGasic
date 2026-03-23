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
