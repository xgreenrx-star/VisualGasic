@tool
extends SceneTree
## Regression test for the "nested Sub/Function" guard in vg_ai_tools.gd.
##
## VG has NO nested procedures -- a Sub/Function declared inside another
## Sub/Function's body compiles (sort of) but fails at RUNTIME with
## "Sub or Function not defined" the moment Godot tries to call the outer
## callback (e.g. _Process/_Input), because VG's parser has no concept of
## nesting and just flattens/misroutes the declarations.
##
## This exact mistake was made TWICE by Narcea while "fixing" the C64
## Emulator's clipboard-paste routine (demos/C64_Emulator/c64_main.vg) --
## once nesting _Input/ProcessPaste/InjectCharacter/AscToPetscii inside
## UpdateKeyboard(), and a second time nesting a duplicate ProcessPaste/
## AscToPetscii pair inside the original AscToPetscii's own body, which
## additionally ate Sub _Process()'s declaration entirely.
##
## The fix has two layers:
##   1. Prompt-level: KNOWLEDGE + response-policy text in vg_ai_narcea.gd
##      tells the model never to do this.
##   2. Code-level (this test targets this layer): _find_nested_procedure_line()
##      in vg_ai_tools.gd statically scans the RESULTING buffer text before
##      ANY mutating tool commits it, and REFUSES the write if nesting is
##      detected. This is the layer that actually holds even if the model
##      ignores its instructions -- which is the whole point, since layer 1
##      alone already failed twice.
##
## Run: godot --headless --script tests/test_nested_procedure_guard.gd

var _failed := 0
var _passed := 0
var _tools = null


func _init() -> void:
	print("=== Nested Sub/Function Guard Regression Test ===")
	print("")

	var script = load("res://addons/visual_gasic/vg_ai_tools.gd")
	if script == null:
		print("FATAL: could not load vg_ai_tools.gd")
		quit(1)
		return
	_tools = script.new()

	_test_clean_sources()
	_test_directly_nested_sub()
	_test_directly_nested_function()
	_test_cross_nested()
	_test_siblings_not_flagged()
	_test_comments_and_strings_not_flagged()
	_test_access_modifiers_recognized()
	_test_real_c64_corruption_pattern_1()
	_test_real_c64_corruption_pattern_2()
	_test_guard_wired_into_all_mutating_tools()

	print("")
	print("=== Results: %d passed, %d failed ===" % [_passed, _failed])
	print("RESULTS: %d/%d passed, %d failed" % [_passed, _passed + _failed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		_passed += 1
		print("  [PASS] %s" % label)
	else:
		_failed += 1
		print("  [FAIL] %s  %s" % [label, detail])


func _test_clean_sources() -> void:
	print("-- Clean top-level sources (must NOT be flagged) --")
	var src1 := """Sub Foo()
	Print "hi"
End Sub

Function Bar() As Integer
	Return 1
End Function
"""
	_check("two clean top-level procedures", _tools._find_nested_procedure_line(src1) == -1)

	var src2 := """Dim x As Integer

Sub A()
End Sub
Sub B()
End Sub
Function C() As Integer
	Return 0
End Function
"""
	_check("three siblings, no blank separation before Sub B", _tools._find_nested_procedure_line(src2) == -1)


func _test_directly_nested_sub() -> void:
	print("-- Sub nested directly inside Sub --")
	var src := """Sub Outer()
	Dim x As Integer
	Sub Inner()
		Print "bad"
	End Sub
End Sub
"""
	var line: int = _tools._find_nested_procedure_line(src)
	_check("detects Sub nested in Sub", line == 3, "got line %d" % line)


func _test_directly_nested_function() -> void:
	print("-- Function nested directly inside Function --")
	var src := """Function Outer() As Integer
	Function Inner() As Integer
		Return 1
	End Function
	Return 0
End Function
"""
	var line: int = _tools._find_nested_procedure_line(src)
	_check("detects Function nested in Function", line == 2, "got line %d" % line)


func _test_cross_nested() -> void:
	print("-- Sub inside Function, Function inside Sub --")
	var src_a := """Function Outer() As Integer
	Sub Inner()
	End Sub
	Return 0
End Function
"""
	_check("Sub nested inside Function detected", _tools._find_nested_procedure_line(src_a) == 2)

	var src_b := """Sub Outer()
	Function Inner() As Integer
		Return 1
	End Function
End Sub
"""
	_check("Function nested inside Sub detected", _tools._find_nested_procedure_line(src_b) == 2)


func _test_siblings_not_flagged() -> void:
	print("-- Properly closed siblings must NOT be flagged --")
	var src := """Sub A()
	Print "a"
End Sub

Sub B()
	Print "b"
End Sub

Function C() As Integer
	Sub_helper_call_not_a_decl()
	Return 1
End Function
"""
	var line: int = _tools._find_nested_procedure_line(src)
	_check("siblings after End Sub/End Function are clean", line == -1, "got line %d" % line)


func _test_comments_and_strings_not_flagged() -> void:
	print("-- Comments/strings mentioning Sub/Function must NOT false-positive --")
	var src := """Sub Outer()
	' This Sub does the thing
	Print "Function successful"
	Dim s As String = "Sub Inner() looks like code but isn't"
End Sub
"""
	var line: int = _tools._find_nested_procedure_line(src)
	_check("comment/string mentions of Sub/Function are ignored", line == -1, "got line %d" % line)


func _test_access_modifiers_recognized() -> void:
	print("-- Public/Private/Static modifiers on both outer and inner --")
	var src := """Public Sub Outer()
	Private Sub Inner()
	End Sub
End Sub
"""
	var line: int = _tools._find_nested_procedure_line(src)
	_check("modifier-prefixed nested Sub detected", line == 2, "got line %d" % line)

	var src_clean := """Public Sub A()
End Sub
Private Function B() As Integer
	Return 1
End Function
"""
	_check("modifier-prefixed siblings are clean", _tools._find_nested_procedure_line(src_clean) == -1)


## Reconstructs the FIRST real corruption: _Input/ProcessPaste/InjectCharacter/
## AscToPetscii nested inside UpdateKeyboard()'s body (found/fixed Aug 2026).
func _test_real_c64_corruption_pattern_1() -> void:
	print("-- Regression: original UpdateKeyboard() nesting incident --")
	var src := """Sub UpdateKeyboard()
	Dim col0 As Integer = 255

	Sub _Input(Event As Variant)
		If Not bLoaded Then Return
	End Sub

	Mem_SetKeyCol 0, col0
End Sub
"""
	var line: int = _tools._find_nested_procedure_line(src)
	_check("catches the original _Input-in-UpdateKeyboard incident", line == 4, "got line %d" % line)


## Reconstructs the SECOND real corruption: a duplicate nested
## ProcessPaste/AscToPetscii pair wedged inside the original AscToPetscii's
## own body (found/fixed Aug 2026), which also ate Sub _Process()'s header.
func _test_real_c64_corruption_pattern_2() -> void:
	print("-- Regression: duplicate ProcessPaste/AscToPetscii nesting incident --")
	var src := """Function AscToPetscii(ch As String) As Integer
	Dim code As Integer = Asc(ch)
	If code = 61 Then Return 61

	Sub ProcessPaste()
		InjectCharacter ch
	End Sub
	Function AscToPetscii(ch As String) As Integer
		Return -1
	End Function
End Function
"""
	var line: int = _tools._find_nested_procedure_line(src)
	_check("catches the duplicate ProcessPaste/AscToPetscii incident", line == 5, "got line %d" % line)


## Static/textual verification that every mutating tool actually calls the
## guard -- a whole-source grep rather than a live plugin round-trip, since
## _do_insert_text/_do_replace_range/_do_replace_in_buffer/_do_set_buffer_text
## all require a live EditorInterface + embedded editor (real plugin window)
## to exercise end-to-end, which isn't available in a headless SceneTree.
func _test_guard_wired_into_all_mutating_tools() -> void:
	print("-- Static check: guard is wired into every mutating buffer tool --")
	var f := FileAccess.open("res://addons/visual_gasic/vg_ai_tools.gd", FileAccess.READ)
	if f == null:
		_check("could not open vg_ai_tools.gd for static check", false)
		return
	var text := f.get_as_text()
	f.close()

	var funcs := ["_do_insert_text", "_do_replace_range", "_do_replace_in_buffer",
		"_do_set_buffer_text", "_do_save_file", "_do_write_file"]
	for fn in funcs:
		var start := text.find("func %s(" % fn)
		if start < 0:
			_check("%s exists" % fn, false)
			continue
		var next_func := text.find("\nfunc ", start + 1)
		if next_func < 0:
			next_func = text.length()
		var body := text.substr(start, next_func - start)
		var has_guard: bool = body.find("_check_nested_if_vg(") != -1 or body.find("_find_nested_procedure_line(") != -1
		_check("%s calls the nested-procedure guard" % fn, has_guard)
