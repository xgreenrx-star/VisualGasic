extends Node

# =============================================================================
# VB6 Importer Automated Test Suite
# Tests code transformation, encoding detection, property mapping, and parsing
# using Calculator-vb6-main/calculate.frm as a real-world reference.
# =============================================================================

const VB6Importer = preload("res://addons/visual_gasic/vb6_importer.gd")

var total := 0
var passed := 0
var failed := 0
var fail_details: Array = []

func _ready():
	print("=" .repeat(60))
	print("VB6 IMPORTER TEST SUITE")
	print("=" .repeat(60))
	
	run_all_tests()
	
	print("\n" + "=" .repeat(60))
	print("RESULTS: %d/%d passed, %d failed" % [passed, total, failed])
	if fail_details.size() > 0:
		print("\nFAILURES:")
		for d in fail_details:
			print("  ✗ " + d)
	print("=" .repeat(60))
	
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()

# --------------- Assertion helpers ---------------

func assert_eq(actual, expected, label: String):
	total += 1
	if actual == expected:
		passed += 1
		print("  ✓ " + label)
	else:
		failed += 1
		var msg = "%s: expected '%s' but got '%s'" % [label, str(expected), str(actual)]
		fail_details.append(msg)
		print("  ✗ " + msg)

func assert_true(cond: bool, label: String):
	total += 1
	if cond:
		passed += 1
		print("  ✓ " + label)
	else:
		failed += 1
		fail_details.append(label + ": expected true")
		print("  ✗ " + label + ": expected true")

func assert_contains(haystack: String, needle: String, label: String):
	total += 1
	if needle in haystack:
		passed += 1
		print("  ✓ " + label)
	else:
		failed += 1
		var msg = "%s: '%s' not found in output" % [label, needle]
		fail_details.append(msg)
		print("  ✗ " + msg)

func assert_not_contains(haystack: String, needle: String, label: String):
	total += 1
	if needle not in haystack:
		passed += 1
		print("  ✓ " + label)
	else:
		failed += 1
		var msg = "%s: '%s' should not be in output" % [label, needle]
		fail_details.append(msg)
		print("  ✗ " + msg)

# --------------- All tests ---------------

func run_all_tests():
	test_transform_line_basic()
	test_transform_vb6_code()
	test_property_translations()
	test_control_array_transform()
	test_declare_function_commented()
	test_property_let_to_set()
	test_doevents_transform()
	test_implements_transform()
	test_type_suffixes()
	test_multi_statement_split()
	test_line_continuation()
	test_enabled_inversion()
	test_encoding_detection()
	test_windows_1252_decode()
	test_calculator_form_import()
	test_method_transforms()
	test_conditional_compilation()
	test_raiseevent_transform()
	test_withevents_transform()
	test_err_object_transforms()
	test_load_unload_transforms()
	test_event_map_coverage()
	test_show_hide_transforms()

# --------------- Individual test functions ---------------

func test_transform_line_basic():
	print("\n--- Transform Line: Basic ---")
	var ca: Dictionary = {}
	
	# Standalone End -> quit
	var line = VB6Importer._transform_line("End", ca)
	assert_contains(line, "get_tree().quit()", "End -> get_tree().quit()")
	
	# Let removal
	line = VB6Importer._transform_line("    Let x = 5", ca)
	assert_not_contains(line, "Let ", "Let keyword removed")
	
	# Set removal
	line = VB6Importer._transform_line("    Set obj = CreateObject(\"Excel\")", ca)
	assert_not_contains(line, "Set ", "Set keyword removed")
	
	# Debug.Print -> Print
	line = VB6Importer._transform_line("    Debug.Print \"Hello\"", ca)
	assert_contains(line, "Print ", "Debug.Print -> Print")
	assert_not_contains(line, "Debug.", "Debug. prefix removed")
	
	# On Error GoTo
	line = VB6Importer._transform_line("On Error GoTo ErrHandler", ca)
	assert_contains(line, "'", "On Error commented out")
	
	# On Error Resume Next
	line = VB6Importer._transform_line("On Error Resume Next", ca)
	assert_contains(line, "'", "On Error Resume Next commented")
	
	# Me. removal
	line = VB6Importer._transform_line("    Me.Caption = \"Hello\"", ca)
	assert_not_contains(line, "Me.", "Me. prefix removed")

func test_transform_vb6_code():
	print("\n--- Transform VB6 Code ---")
	var code = """Attribute VB_Name = "Test"
VERSION 5.00
Dim x As Integer

Private Sub Form_Load()
    x = 5
    MsgBox "Hello"
End Sub
"""
	var result = VB6Importer._transform_vb6_code(code, "TestForm", {})
	
	# Header should be present
	assert_contains(result, "' VisualGasic - Imported from VB6", "Header comment present")
	assert_contains(result, "' Form: TestForm", "Form name in header")
	assert_contains(result, "Option Explicit", "Option Explicit added")
	
	# Attribute lines should be stripped
	assert_not_contains(result, "Attribute VB_Name", "Attribute lines stripped")
	assert_not_contains(result, "VERSION 5.00", "VERSION line stripped")
	
	# Actual code should be present
	assert_contains(result, "Dim x As Integer", "Variable declaration preserved")
	assert_contains(result, "Private Sub Form_Load()", "Sub declaration preserved")

func test_property_translations():
	print("\n--- Property Translations ---")
	var ca: Dictionary = {}
	
	# .Caption -> .text
	var line = VB6Importer._transform_line("    Label1.Caption = \"Hello\"", ca)
	assert_contains(line, ".text", ".Caption -> .text")
	
	# .Visible -> .visible
	line = VB6Importer._transform_line("    Button1.Visible = True", ca)
	assert_contains(line, ".visible", ".Visible -> .visible")
	
	# .Left -> .position.x
	line = VB6Importer._transform_line("    Button1.Left = 100", ca)
	assert_contains(line, ".position.x", ".Left -> .position.x")
	
	# .Top -> .position.y
	line = VB6Importer._transform_line("    Button1.Top = 200", ca)
	assert_contains(line, ".position.y", ".Top -> .position.y")
	
	# .Width -> .size.x
	line = VB6Importer._transform_line("    Panel1.Width = 300", ca)
	assert_contains(line, ".size.x", ".Width -> .size.x")
	
	# .Height -> .size.y
	line = VB6Importer._transform_line("    Panel1.Height = 400", ca)
	assert_contains(line, ".size.y", ".Height -> .size.y")
	
	# .BackColor -> .modulate
	line = VB6Importer._transform_line("    Form1.BackColor = &HFF0000&", ca)
	assert_contains(line, ".modulate", ".BackColor -> .modulate")
	
	# .ListCount -> .get_item_count()
	line = VB6Importer._transform_line("    n = List1.ListCount", ca)
	assert_contains(line, ".get_item_count()", ".ListCount -> .get_item_count()")
	
	# .Value -> .value
	line = VB6Importer._transform_line("    v = Slider1.Value", ca)
	assert_contains(line, ".value", ".Value -> .value")

func test_control_array_transform():
	print("\n--- Control Array Transform ---")
	var ca: Dictionary = {"Num": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]}
	
	# Literal index: Num(5) -> Num_5
	var line = VB6Importer._transform_line("    Num(5).text = \"5\"", ca)
	assert_contains(line, "Num_5", "Num(5) -> Num_5 literal index")
	
	# Variable index: Num(i) -> FindControl("Num_" & CStr(i))
	line = VB6Importer._transform_line("    Num(i).text = str(i)", ca)
	assert_contains(line, "FindControl", "Num(i) -> FindControl for variable index")
	assert_contains(line, "CStr(i)", "CStr wrapping of variable index")
	
	# FindControl helper added when control arrays present
	var code = "Dim x As Integer"
	var result = VB6Importer._transform_vb6_code(code, "Test", ca)
	assert_contains(result, "Private Function FindControl", "FindControl helper added")

func test_declare_function_commented():
	print("\n--- Declare Function Commented Out ---")
	var ca: Dictionary = {}
	
	# Private Declare Function
	var line = VB6Importer._transform_line("Private Declare Function GetTickCount Lib \"kernel32\" () As Long", ca)
	assert_contains(line, "' [VB6 API]", "Declare Function commented out")
	assert_contains(line, "TODO", "TODO note added")
	
	# Public Declare Sub
	line = VB6Importer._transform_line("Public Declare Sub Sleep Lib \"kernel32\" (ByVal ms As Long)", ca)
	assert_contains(line, "' [VB6 API]", "Declare Sub commented out")
	
	# Plain Declare Function
	line = VB6Importer._transform_line("Declare Function SendMessage Lib \"user32\" () As Long", ca)
	assert_contains(line, "' [VB6 API]", "Plain Declare Function commented out")

func test_property_let_to_set():
	print("\n--- Property Let -> Property Set ---")
	var ca: Dictionary = {}
	
	var line = VB6Importer._transform_line("Property Let Name(ByVal v As String)", ca)
	assert_contains(line, "Property Set ", "Property Let -> Property Set")
	assert_not_contains(line, "Property Let", "Property Let removed")
	
	line = VB6Importer._transform_line("Public Property Let Value(ByVal v As Integer)", ca)
	assert_contains(line, "Property Set ", "Public Property Let -> Property Set")
	
	# Property Get should remain unchanged
	line = VB6Importer._transform_line("Property Get Name() As String", ca)
	assert_contains(line, "Property Get", "Property Get unchanged")

func test_doevents_transform():
	print("\n--- DoEvents Transform ---")
	var ca: Dictionary = {}
	
	var line = VB6Importer._transform_line("DoEvents", ca)
	assert_contains(line, "'", "DoEvents commented out")
	assert_contains(line, "TODO", "DoEvents has TODO note")

func test_implements_transform():
	print("\n--- Implements Transform ---")
	var ca: Dictionary = {}
	
	var line = VB6Importer._transform_line("Implements IComparable", ca)
	assert_contains(line, "' [VB6]", "Implements commented out")
	assert_contains(line, "TODO", "Implements has TODO note")

func test_type_suffixes():
	print("\n--- Type Suffix Transforms ---")
	
	# $ -> String
	var line = VB6Importer._transform_type_suffixes("Dim name$ As String")
	# Already has As String, but the suffix should be handled
	
	line = VB6Importer._transform_type_suffixes("Dim msg$")
	assert_contains(line, "As String", "$ suffix -> As String")
	
	# % -> Integer
	line = VB6Importer._transform_type_suffixes("Dim count%")
	assert_contains(line, "As Integer", "% suffix -> As Integer")
	
	# & -> Long
	line = VB6Importer._transform_type_suffixes("Dim bigNum&")
	assert_contains(line, "As Long", "& suffix -> As Long")
	
	# Non-declaration lines should be unchanged
	line = VB6Importer._transform_type_suffixes("x$ = \"hello\"")
	assert_not_contains(line, "As String", "Non-declaration unchanged")

func test_multi_statement_split():
	print("\n--- Multi-Statement Split ---")
	
	# Basic split
	var stmts = VB6Importer._split_multi_statement("a = 1 : b = 2 : c = 3")
	assert_eq(stmts.size(), 3, "Three statements split")
	assert_eq(stmts[0], "a = 1", "First statement correct")
	assert_eq(stmts[1], "b = 2", "Second statement correct")
	assert_eq(stmts[2], "c = 3", "Third statement correct")
	
	# Colon inside string should NOT split
	stmts = VB6Importer._split_multi_statement("MsgBox \"Time: 12:00\" : x = 1")
	assert_eq(stmts.size(), 2, "String colon not split")
	assert_contains(stmts[0], "12:00", "String preserved with colon")
	
	# Single statement (no colons)
	stmts = VB6Importer._split_multi_statement("x = 42")
	assert_eq(stmts.size(), 1, "Single statement no split")

func test_line_continuation():
	print("\n--- Line Continuation ---")
	
	# Lines ending with " _" should be joined
	var code = "Dim x As _\n    Integer"
	var result = VB6Importer._transform_vb6_code(code, "Test", {})
	assert_contains(result, "Dim x As     Integer", "Line continuation joined")

func test_enabled_inversion():
	print("\n--- .Enabled Inversion ---")
	var ca: Dictionary = {}
	
	# Enabled = False -> disabled = True
	var line = VB6Importer._transform_line("    Button1.Enabled = False", ca)
	assert_contains(line, ".disabled = True", "Enabled=False -> disabled=True")
	
	# Enabled = True -> disabled = False
	line = VB6Importer._transform_line("    Button1.Enabled = True", ca)
	assert_contains(line, ".disabled = False", "Enabled=True -> disabled=False")

func test_encoding_detection():
	print("\n--- Encoding Detection ---")
	
	# Plain ASCII / UTF-8
	var ascii_data = "Hello World".to_utf8_buffer()
	assert_eq(VB6Importer._detect_encoding(ascii_data), "utf-8", "ASCII detected as UTF-8")
	
	# UTF-8 BOM
	var bom_data = PackedByteArray([0xEF, 0xBB, 0xBF]) + "Hello".to_utf8_buffer()
	assert_eq(VB6Importer._detect_encoding(bom_data), "utf-8-bom", "UTF-8 BOM detected")
	
	# UTF-16 LE BOM
	var utf16le_data = PackedByteArray([0xFF, 0xFE, 0x48, 0x00])
	assert_eq(VB6Importer._detect_encoding(utf16le_data), "utf-16-le", "UTF-16 LE detected")
	
	# UTF-16 BE BOM
	var utf16be_data = PackedByteArray([0xFE, 0xFF, 0x00, 0x48])
	assert_eq(VB6Importer._detect_encoding(utf16be_data), "utf-16-be", "UTF-16 BE detected")
	
	# Windows-1252 (non-UTF-8 high bytes)
	var cp1252_data = PackedByteArray([0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x20, 0x93, 0x57, 0x6F, 0x72, 0x6C, 0x64, 0x94])
	# 0x93 and 0x94 are left/right double quote in CP1252, not valid UTF-8
	assert_eq(VB6Importer._detect_encoding(cp1252_data), "windows-1252", "Windows-1252 detected")

func test_windows_1252_decode():
	print("\n--- Windows-1252 Decode ---")
	
	# Test the euro sign (0x80 -> U+20AC)
	var data = PackedByteArray([0x80])
	var decoded = VB6Importer._decode_to_utf8(data, "windows-1252")
	assert_eq(decoded, "€", "Euro sign decoded from CP1252")
	
	# Smart quotes (0x93 = left double quote, 0x94 = right double quote)
	data = PackedByteArray([0x93, 0x48, 0x69, 0x94])
	decoded = VB6Importer._decode_to_utf8(data, "windows-1252")
	assert_eq(decoded, "\u201CHi\u201D", "Smart quotes decoded from CP1252")
	
	# Latin characters 0xA0-0xFF map directly
	data = PackedByteArray([0xE9])  # é
	decoded = VB6Importer._decode_to_utf8(data, "windows-1252")
	assert_eq(decoded, "é", "Latin é decoded from CP1252")
	
	# UTF-8 BOM stripping
	data = PackedByteArray([0xEF, 0xBB, 0xBF]) + "Test".to_utf8_buffer()
	decoded = VB6Importer._decode_to_utf8(data, "utf-8-bom")
	assert_eq(decoded, "Test", "UTF-8 BOM stripped correctly")

func test_calculator_form_import():
	print("\n--- Calculator Form Import (calculate.frm) ---")
	
	# Test code transformation using the calculator's VB6 code section
	var calc_code = """Attribute VB_Name = "Calculate"
Attribute VB_GlobalNameSpace = False

Dim Number, Operator As Integer


Private Sub Num_Click(Index As Integer) ' Numbers
TextBox.Text = TextBox.Text & Num(Index).Caption
End Sub

Private Sub Mul_Click() ' Multiplication
Number = Val(TextBox.Text)
TextBox.Text = ""
Operator = 1
End Sub
Private Sub Add_Click() ' Addition
Number = Val(TextBox.Text)
TextBox.Text = ""
Operator = 2
End Sub

Private Sub Sub_Click() ' Subtraction
Number = Val(TextBox.Text)
TextBox.Text = ""
Operator = 3
End Sub

Private Sub Div_Click() ' Division
Number = Val(TextBox.Text)
TextBox.Text = ""
Operator = 4
End Sub

Private Sub Pow_Click() ' Power
Number = Val(TextBox.Text)
TextBox.Text = ""
Operator = 5
End Sub

Private Sub Mod_Click() ' Modulus
Number = Val(TextBox.Text)
TextBox.Text = ""
Operator = 6
End Sub

Private Sub Result_Click() ' Result
If Operator = 1 Then TextBox.Text = Number * Val(TextBox.Text) ' Mul
If Operator = 2 Then TextBox.Text = Number + Val(TextBox.Text) ' Add
If Operator = 3 Then TextBox.Text = Number - Val(TextBox.Text) ' Sub
If Operator = 4 Then TextBox.Text = Number / Val(TextBox.Text) ' Div
If Operator = 5 Then TextBox.Text = Number ^ Val(TextBox.Text) ' Pow
If Operator = 6 Then TextBox.Text = Number Mod Val(TextBox.Text) ' Mod
End Sub

Private Sub Exit_Click() ' Exit
MsgBox "Baye"
End
End Sub
"""
	var control_arrays = {"Num": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]}
	var result = VB6Importer._transform_vb6_code(calc_code, "Calculate", control_arrays)
	
	# Attribute lines should be stripped
	assert_not_contains(result, "Attribute VB_Name", "Calculator: Attribute stripped")
	
	# Header present
	assert_contains(result, "' Form: Calculate", "Calculator: form name in header")
	
	# FindControl helper present (control array used)
	assert_contains(result, "Private Function FindControl", "Calculator: FindControl helper")
	
	# Control array literal access: Num(Index).Caption should use FindControl
	# since Index is a variable
	assert_contains(result, "FindControl", "Calculator: Num(Index) uses FindControl")
	
	# .Text -> .text via .Caption -> .text (TextBox.Text)
	assert_contains(result, "TextBox.text", "Calculator: .Text -> .text")
	
	# Exit_Click: End -> get_tree().quit()
	assert_contains(result, "get_tree().quit()", "Calculator: End -> quit")
	
	# Sub declarations preserved
	assert_contains(result, "Private Sub Num_Click(Index As Integer)", "Calculator: Num_Click preserved")
	assert_contains(result, "Private Sub Result_Click()", "Calculator: Result_Click preserved")
	assert_contains(result, "Private Sub Exit_Click()", "Calculator: Exit_Click preserved")
	
	# Dim line preserved
	assert_contains(result, "Dim Number, Operator As Integer", "Calculator: Dim preserved")
	
	# Operators preserved (^, Mod, *, /, +, -)
	assert_contains(result, "Number ^ Val(", "Calculator: Power operator preserved")
	assert_contains(result, "Number Mod Val(", "Calculator: Mod operator preserved")
	
	# VB6 color mapping test (not in code but verify the helper)
	var color = VB6Importer.vb_color_to_godot("&H8000000B&")
	assert_true(color.r < 1.0 or color.g < 1.0, "Calculator: System color 0x0B (InactiveBorder) resolved")
	
	# CONTROL_MAP has all needed controls
	assert_true(VB6Importer.is_control_supported("VB.CommandButton"), "CONTROL_MAP: VB.CommandButton supported")
	assert_true(VB6Importer.is_control_supported("VB.TextBox"), "CONTROL_MAP: VB.TextBox supported")
	assert_true(VB6Importer.is_control_supported("VB.Form"), "CONTROL_MAP: VB.Form supported")
	
	# Godot equivalents
	assert_eq(VB6Importer.get_godot_equivalent("VB.CommandButton"), "Button", "VB.CommandButton -> Button")
	assert_eq(VB6Importer.get_godot_equivalent("VB.TextBox"), "LineEdit", "VB.TextBox -> LineEdit")
	
	print("\n  Calculator code transform: %d lines output" % result.split("\n").size())

# ===============================================================================
# NEW TEST FUNCTIONS — Method Transforms, Conditional Compilation, etc.
# ===============================================================================

func test_method_transforms():
	print("\n--- Method Transforms ---")
	var ca: Dictionary = {}
	
	# .SetFocus -> .grab_focus()
	var line = VB6Importer._transform_line("    TextBox1.SetFocus", ca)
	assert_contains(line, ".grab_focus()", ".SetFocus -> .grab_focus()")
	
	# .Refresh -> .queue_redraw()
	line = VB6Importer._transform_line("    Picture1.Refresh", ca)
	assert_contains(line, ".queue_redraw()", ".Refresh -> .queue_redraw()")
	
	# .AddItem -> .add_item
	line = VB6Importer._transform_line("    List1.AddItem \"Hello\"", ca)
	assert_contains(line, ".add_item", ".AddItem -> .add_item")
	
	# .RemoveItem -> .remove_item
	line = VB6Importer._transform_line("    List1.RemoveItem 0", ca)
	assert_contains(line, ".remove_item", ".RemoveItem -> .remove_item")
	
	# .Clear -> .clear()
	line = VB6Importer._transform_line("    List1.Clear", ca)
	assert_contains(line, ".clear()", ".Clear -> .clear()")
	
	# .ZOrder -> .z_index
	line = VB6Importer._transform_line("    Picture1.ZOrder 0", ca)
	assert_contains(line, ".z_index", ".ZOrder -> .z_index")
	
	# .SelStart -> .caret_column
	line = VB6Importer._transform_line("    pos = Text1.SelStart", ca)
	assert_contains(line, ".caret_column", ".SelStart -> .caret_column")
	
	# .SelText (read) -> .get_selected_text()
	line = VB6Importer._transform_line("    s = Text1.SelText", ca)
	assert_contains(line, ".get_selected_text()", ".SelText -> .get_selected_text()")
	
	# .ListIndex -> .get_selected_items()[0]
	line = VB6Importer._transform_line("    idx = List1.ListIndex", ca)
	assert_contains(line, ".get_selected_items()", ".ListIndex -> .get_selected_items()")
	
	# .Text -> .text (case transform)
	line = VB6Importer._transform_line("    s = TextBox1.Text", ca)
	assert_contains(line, ".text", ".Text -> .text")

func test_conditional_compilation():
	print("\n--- Conditional Compilation ---")
	var ca: Dictionary = {}
	
	# #If -> commented
	var line = VB6Importer._transform_line("#If VBA6 Then", ca)
	assert_contains(line, "' [VB6 CC]", "#If commented out")
	
	# #ElseIf -> commented
	line = VB6Importer._transform_line("#ElseIf Win32 Then", ca)
	assert_contains(line, "' [VB6 CC]", "#ElseIf commented out")
	
	# #Else -> commented
	line = VB6Importer._transform_line("#Else", ca)
	assert_contains(line, "' [VB6 CC]", "#Else commented out")
	
	# #End If -> commented
	line = VB6Importer._transform_line("#End If", ca)
	assert_contains(line, "' [VB6 CC]", "#End If commented out")
	
	# #Const -> commented
	line = VB6Importer._transform_line("#Const DEBUG_MODE = 1", ca)
	assert_contains(line, "' [VB6 CC]", "#Const commented out")

func test_raiseevent_transform():
	print("\n--- RaiseEvent Transform ---")
	var ca: Dictionary = {}
	
	# RaiseEvent with args -> emit_signal
	var line = VB6Importer._transform_line("    RaiseEvent StatusChanged(\"done\")", ca)
	assert_contains(line, 'emit_signal("StatusChanged"', "RaiseEvent -> emit_signal with args")
	assert_contains(line, '"done"', "RaiseEvent args preserved")
	
	# RaiseEvent without args
	line = VB6Importer._transform_line("    RaiseEvent DataReady", ca)
	assert_contains(line, 'emit_signal("DataReady")', "RaiseEvent no-args -> emit_signal")
	
	# Event declaration commented out
	line = VB6Importer._transform_line("Public Event StatusChanged(ByVal msg As String)", ca)
	assert_contains(line, "' [VB6]", "Public Event commented")
	assert_contains(line, "signal", "Event note mentions signal")

func test_withevents_transform():
	print("\n--- WithEvents Transform ---")
	var ca: Dictionary = {}
	
	# Private WithEvents -> commented
	var line = VB6Importer._transform_line("Private WithEvents mTimer As TimerState", ca)
	assert_contains(line, "' [VB6]", "WithEvents commented out")
	assert_contains(line, "signal", "WithEvents note mentions signals")
	
	# Dim WithEvents -> commented
	line = VB6Importer._transform_line("Dim WithEvents objConn As Connection", ca)
	assert_contains(line, "' [VB6]", "Dim WithEvents commented")

func test_err_object_transforms():
	print("\n--- Err Object Transforms ---")
	var ca: Dictionary = {}
	
	# Err.Raise -> commented with TODO
	var line = VB6Importer._transform_line("    Err.Raise vbObjectError + 1, \"MyClass\", \"Invalid\"", ca)
	assert_contains(line, "'", "Err.Raise commented")
	assert_contains(line, "TODO", "Err.Raise has TODO")
	
	# Err.Clear -> commented
	line = VB6Importer._transform_line("    Err.Clear", ca)
	assert_contains(line, "'", "Err.Clear commented")
	
	# Err.Number in expression -> 0
	line = VB6Importer._transform_line("    If Err.Number <> 0 Then", ca)
	assert_contains(line, "0", "Err.Number replaced with 0")
	assert_contains(line, "VB6", "Err.Number has VB6 comment")
	
	# Err.Description -> ""
	line = VB6Importer._transform_line("    msg = Err.Description", ca)
	assert_contains(line, "VB6", "Err.Description has VB6 comment")

func test_load_unload_transforms():
	print("\n--- Load/Unload Transforms ---")
	var ca: Dictionary = {}
	
	# Load FormName -> .show()
	var line = VB6Importer._transform_line("    Load Form2", ca)
	assert_contains(line, "Form2.show()", "Load Form2 -> Form2.show()")
	
	# Unload FormName -> .hide()
	line = VB6Importer._transform_line("    Unload Form1", ca)
	assert_contains(line, "Form1.hide()", "Unload Form1 -> Form1.hide()")
	
	# .Show -> .show()
	line = VB6Importer._transform_line("    frmMain.Show", ca)
	assert_contains(line, ".show()", ".Show -> .show()")
	
	# .Hide -> .hide()
	line = VB6Importer._transform_line("    frmMain.Hide", ca)
	assert_contains(line, ".hide()", ".Hide -> .hide()")

func test_event_map_coverage():
	print("\n--- EVENT_MAP Coverage ---")
	
	# Verify expanded EVENT_MAP has expected control types
	assert_true(VB6Importer.EVENT_MAP.has("Button"), "EVENT_MAP has Button")
	assert_true(VB6Importer.EVENT_MAP.has("LineEdit"), "EVENT_MAP has LineEdit")
	assert_true(VB6Importer.EVENT_MAP.has("TextEdit"), "EVENT_MAP has TextEdit")
	assert_true(VB6Importer.EVENT_MAP.has("CheckBox"), "EVENT_MAP has CheckBox")
	assert_true(VB6Importer.EVENT_MAP.has("Timer"), "EVENT_MAP has Timer")
	assert_true(VB6Importer.EVENT_MAP.has("Label"), "EVENT_MAP has Label")
	assert_true(VB6Importer.EVENT_MAP.has("TextureRect"), "EVENT_MAP has TextureRect")
	assert_true(VB6Importer.EVENT_MAP.has("Panel"), "EVENT_MAP has Panel")
	assert_true(VB6Importer.EVENT_MAP.has("RichTextLabel"), "EVENT_MAP has RichTextLabel")
	assert_true(VB6Importer.EVENT_MAP.has("ColorRect"), "EVENT_MAP has ColorRect")
	assert_true(VB6Importer.EVENT_MAP.has("VSlider"), "EVENT_MAP has VSlider")
	assert_true(VB6Importer.EVENT_MAP.has("ProgressBar"), "EVENT_MAP has ProgressBar")
	assert_true(VB6Importer.EVENT_MAP.has("SpinBox"), "EVENT_MAP has SpinBox")
	assert_true(VB6Importer.EVENT_MAP.has("TabContainer"), "EVENT_MAP has TabContainer")
	assert_true(VB6Importer.EVENT_MAP.has("LinkButton"), "EVENT_MAP has LinkButton")
	
	# Verify Button has KeyDown/KeyUp events
	assert_true(VB6Importer.EVENT_MAP["Button"].has("KeyDown"), "Button has KeyDown event")
	assert_true(VB6Importer.EVENT_MAP["Button"].has("KeyUp"), "Button has KeyUp event")
	
	# Verify TextureRect has MouseMove
	assert_true(VB6Importer.EVENT_MAP["TextureRect"].has("MouseMove"), "TextureRect has MouseMove")
	
	# Verify Panel has Resize
	assert_true(VB6Importer.EVENT_MAP["Panel"].has("Resize"), "Panel has Resize event")
	
	# Count total events mapped
	var total_events = 0
	for ctrl_type in VB6Importer.EVENT_MAP:
		total_events += VB6Importer.EVENT_MAP[ctrl_type].size()
	print("  Total event mappings: %d across %d control types" % [total_events, VB6Importer.EVENT_MAP.size()])

func test_show_hide_transforms():
	print("\n--- Show/Hide/Move Transforms ---")
	var ca: Dictionary = {}
	
	# .Move with args -> position/size comment
	var line = VB6Importer._transform_line("    Picture1.Move 100, 200, 300, 400", ca)
	assert_contains(line, "TODO", ".Move has TODO for manual conversion")
