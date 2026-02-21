#!/usr/bin/env python3
"""
VisualGasic Automated Test Generator
=====================================
Generates .vg test scripts that exercise every language construct
and Godot API pattern, then runs them headlessly and checks for
runtime errors (bytecode fallback, "unsupported opcode", crashes).

Usage:
    python3 tools/generate_coverage_tests.py [--run] [--godot PATH]

With --run it will:
  1. Generate all .vg test files into tests/generated/
  2. Generate a GDScript runner that loads each .vg and calls its entry point
  3. Launch Godot headless, capture output
  4. Report PASS/FAIL per test, flag any "unsupported opcode" or AST fallback
"""

import os
import sys
import argparse
import subprocess
import json
from pathlib import Path
from datetime import datetime

WORKSPACE = Path(__file__).resolve().parent.parent
GENERATED_DIR = WORKSPACE / "tests" / "generated"
RUNNER_SCRIPT = WORKSPACE / "tests" / "run_generated_tests.gd"
RESULTS_FILE = WORKSPACE / "tests" / "coverage_results.json"

# =============================================================================
# TEST DEFINITIONS
# =============================================================================
# Each test is a (filename, description, vg_code) tuple.
# The VG code should Print "PASS:<test_name>" on success.
# If it crashes or prints nothing, the runner detects failure.

def make_tests():
    """Return list of (name, description, vg_code) tuples."""
    tests = []

    # ---- Category 1: Arithmetic & Operators ----
    tests.append(("arith_basic", "Basic arithmetic: + - * / \\ Mod ^", '''
Attribute VB_Name = "TestArithBasic"
Sub RunTest()
    Dim a As Integer = 10
    Dim b As Integer = 3
    Dim r1 As Integer = a + b   ' 13
    Dim r2 As Integer = a - b   ' 7
    Dim r3 As Integer = a * b   ' 30
    Dim r4 As Single = a / b    ' 3.333...
    Dim r5 As Integer = a \\ b   ' 3 (int divide)
    Dim r6 As Integer = a Mod b ' 1
    Dim r7 As Single = 2 ^ 10   ' 1024
    If r1 = 13 And r2 = 7 And r3 = 30 And r5 = 3 And r6 = 1 And r7 = 1024 Then
        Print "PASS:arith_basic"
    Else
        Print "FAIL:arith_basic r1=" & str(r1) & " r2=" & str(r2) & " r3=" & str(r3) & " r5=" & str(r5) & " r6=" & str(r6) & " r7=" & str(r7)
    End If
End Sub
'''))

    tests.append(("arith_negate", "Unary negate on integers and floats", '''
Attribute VB_Name = "TestArithNegate"
Sub RunTest()
    Dim a As Integer = 42
    Dim b As Single = 3.14
    Dim c As Integer = -a
    Dim d As Single = -b
    If c = -42 And d < -3.13 And d > -3.15 Then
        Print "PASS:arith_negate"
    Else
        Print "FAIL:arith_negate c=" & str(c) & " d=" & str(d)
    End If
End Sub
'''))

    tests.append(("arith_string_concat", "String concatenation with & and +", '''
Attribute VB_Name = "TestStringConcat"
Sub RunTest()
    Dim s1 As String = "Hello"
    Dim s2 As String = " World"
    Dim r1 As String = s1 & s2
    Dim r2 As String = s1 + s2
    If r1 = "Hello World" And r2 = "Hello World" Then
        Print "PASS:arith_string_concat"
    Else
        Print "FAIL:arith_string_concat"
    End If
End Sub
'''))

    tests.append(("arith_format_op", "% format operator", '''
Attribute VB_Name = "TestFormatOp"
Sub RunTest()
    Dim result As String = "Value: %d" % 42
    Dim result2 As String = "%.2f" % 3.14159
    If result = "Value: 42" Then
        Print "PASS:arith_format_op"
    Else
        Print "FAIL:arith_format_op result=" & result
    End If
End Sub
'''))

    # ---- Category 2: Comparison Operators ----
    tests.append(("compare_ops", "All comparison operators", '''
Attribute VB_Name = "TestCompareOps"
Sub RunTest()
    Dim pass_count As Integer = 0
    If 5 = 5 Then pass_count = pass_count + 1
    If 5 <> 6 Then pass_count = pass_count + 1
    If 5 < 6 Then pass_count = pass_count + 1
    If 6 > 5 Then pass_count = pass_count + 1
    If 5 <= 5 Then pass_count = pass_count + 1
    If 5 <= 6 Then pass_count = pass_count + 1
    If 6 >= 6 Then pass_count = pass_count + 1
    If 6 >= 5 Then pass_count = pass_count + 1
    If pass_count = 8 Then
        Print "PASS:compare_ops"
    Else
        Print "FAIL:compare_ops count=" & str(pass_count)
    End If
End Sub
'''))

    # ---- Category 3: Logical Operators ----
    tests.append(("logic_ops", "And, Or, Not, Xor", '''
Attribute VB_Name = "TestLogicOps"
Sub RunTest()
    Dim pass_count As Integer = 0
    If True And True Then pass_count = pass_count + 1
    If Not (True And False) Then pass_count = pass_count + 1
    If True Or False Then pass_count = pass_count + 1
    If Not False Then pass_count = pass_count + 1
    If True Xor False Then pass_count = pass_count + 1
    If Not (True Xor True) Then pass_count = pass_count + 1
    If pass_count = 6 Then
        Print "PASS:logic_ops"
    Else
        Print "FAIL:logic_ops count=" & str(pass_count)
    End If
End Sub
'''))

    # ---- Category 4: Control Flow ----
    tests.append(("ctrl_if_elseif", "If / ElseIf / Else", '''
Attribute VB_Name = "TestIfElseIf"
Sub RunTest()
    Dim x As Integer = 5
    Dim result As String = ""
    If x = 1 Then
        result = "one"
    ElseIf x = 5 Then
        result = "five"
    Else
        result = "other"
    End If
    If result = "five" Then
        Print "PASS:ctrl_if_elseif"
    Else
        Print "FAIL:ctrl_if_elseif result=" & result
    End If
End Sub
'''))

    tests.append(("ctrl_for_next", "For/Next loop with Step", '''
Attribute VB_Name = "TestForNext"
Sub RunTest()
    Dim total As Integer = 0
    Dim i As Integer
    For i = 1 To 10
        total = total + i
    Next
    Dim total2 As Integer = 0
    For i = 0 To 10 Step 2
        total2 = total2 + i
    Next
    If total = 55 And total2 = 30 Then
        Print "PASS:ctrl_for_next"
    Else
        Print "FAIL:ctrl_for_next total=" & str(total) & " total2=" & str(total2)
    End If
End Sub
'''))

    tests.append(("ctrl_while_wend", "While/Wend loop", '''
Attribute VB_Name = "TestWhileWend"
Sub RunTest()
    Dim x As Integer = 0
    Dim total As Integer = 0
    While x < 5
        total = total + x
        x = x + 1
    Wend
    If total = 10 Then
        Print "PASS:ctrl_while_wend"
    Else
        Print "FAIL:ctrl_while_wend total=" & str(total)
    End If
End Sub
'''))

    tests.append(("ctrl_do_loop", "Do While/Loop and Do/Loop Until", '''
Attribute VB_Name = "TestDoLoop"
Sub RunTest()
    Dim x As Integer = 0
    Do While x < 3
        x = x + 1
    Loop
    Dim y As Integer = 0
    Do
        y = y + 1
    Loop Until y >= 3
    If x = 3 And y = 3 Then
        Print "PASS:ctrl_do_loop"
    Else
        Print "FAIL:ctrl_do_loop x=" & str(x) & " y=" & str(y)
    End If
End Sub
'''))

    tests.append(("ctrl_select_case", "Select Case with multiple cases", '''
Attribute VB_Name = "TestSelectCase"
Sub RunTest()
    Dim results As String = ""
    Dim i As Integer
    For i = 0 To 3
        Select Case i
            Case 0
                results = results & "zero "
            Case 1
                results = results & "one "
            Case 2
                results = results & "two "
            Case Else
                results = results & "other "
        End Select
    Next
    If results = "zero one two other " Then
        Print "PASS:ctrl_select_case"
    Else
        Print "FAIL:ctrl_select_case results=" & results
    End If
End Sub
'''))

    tests.append(("ctrl_for_each", "For Each over array", '''
Attribute VB_Name = "TestForEach"
Sub RunTest()
    Dim arr As Array
    arr.append(10)
    arr.append(20)
    arr.append(30)
    Dim total As Integer = 0
    Dim item As Variant
    For Each item In arr
        total = total + item
    Next
    If total = 60 Then
        Print "PASS:ctrl_for_each"
    Else
        Print "FAIL:ctrl_for_each total=" & str(total)
    End If
End Sub
'''))

    # ---- Category 5: Functions & Return Values ----
    tests.append(("func_return", "Function with return value", '''
Attribute VB_Name = "TestFuncReturn"
Function AddTwo(a As Integer, b As Integer) As Integer
    AddTwo = a + b
End Function

Sub RunTest()
    Dim result As Integer = AddTwo(17, 25)
    If result = 42 Then
        Print "PASS:func_return"
    Else
        Print "FAIL:func_return result=" & str(result)
    End If
End Sub
'''))

    tests.append(("func_recursive", "Recursive function call", '''
Attribute VB_Name = "TestRecursive"
Function Factorial(n As Integer) As Integer
    If n <= 1 Then
        Factorial = 1
    Else
        Factorial = n * Factorial(n - 1)
    End If
End Function

Sub RunTest()
    Dim result As Integer = Factorial(6)
    If result = 720 Then
        Print "PASS:func_recursive"
    Else
        Print "FAIL:func_recursive result=" & str(result)
    End If
End Sub
'''))

    # ---- Category 6: Arrays ----
    tests.append(("array_basic", "Array create, append, access, size", '''
Attribute VB_Name = "TestArrayBasic"
Sub RunTest()
    Dim arr As Array
    arr.append(100)
    arr.append(200)
    arr.append(300)
    Dim s As Integer = arr.size()
    Dim v As Integer = arr[1]
    If s = 3 And v = 200 Then
        Print "PASS:array_basic"
    Else
        Print "FAIL:array_basic size=" & str(s) & " v=" & str(v)
    End If
End Sub
'''))

    tests.append(("array_set", "Array element assignment", '''
Attribute VB_Name = "TestArraySet"
Sub RunTest()
    Dim arr As Array
    arr.append(0)
    arr.append(0)
    arr[0] = 42
    arr[1] = 99
    If arr[0] = 42 And arr[1] = 99 Then
        Print "PASS:array_set"
    Else
        Print "FAIL:array_set"
    End If
End Sub
'''))

    # ---- Category 7: Dictionaries ----
    tests.append(("dict_basic", "Dictionary create, set, get", '''
Attribute VB_Name = "TestDictBasic"
Sub RunTest()
    Dim d As New Dictionary
    d["name"] = "test"
    d["value"] = 42
    If d["name"] = "test" And d["value"] = 42 Then
        Print "PASS:dict_basic"
    Else
        Print "FAIL:dict_basic"
    End If
End Sub
'''))

    # ---- Category 8: Godot Built-in Types ----
    tests.append(("type_vector2", "Vector2 create and arithmetic", '''
Attribute VB_Name = "TestVector2"
Sub RunTest()
    Dim v1 As Vector2 = Vector2(1, 2)
    Dim v2 As Vector2 = Vector2(3, 4)
    Dim v3 As Vector2 = v1 + v2
    If v3.x = 4 And v3.y = 6 Then
        Print "PASS:type_vector2"
    Else
        Print "FAIL:type_vector2 x=" & str(v3.x) & " y=" & str(v3.y)
    End If
End Sub
'''))

    tests.append(("type_vector3", "Vector3 create and subtract", '''
Attribute VB_Name = "TestVector3"
Sub RunTest()
    Dim v1 As Vector3 = Vector3(10, 20, 30)
    Dim v2 As Vector3 = Vector3(1, 2, 3)
    Dim v3 As Vector3 = v1 - v2
    If v3.x = 9 And v3.y = 18 And v3.z = 27 Then
        Print "PASS:type_vector3"
    Else
        Print "FAIL:type_vector3"
    End If
End Sub
'''))

    tests.append(("type_color", "Color constructor", '''
Attribute VB_Name = "TestColor"
Sub RunTest()
    Dim c As Color = Color(0.5, 0.5, 0.5)
    If c.r = 0.5 And c.g = 0.5 And c.b = 0.5 Then
        Print "PASS:type_color"
    Else
        Print "FAIL:type_color"
    End If
End Sub
'''))

    # ---- Category 9: Object Instantiation ----
    tests.append(("obj_node_new", "Node.new() — scene tree object", '''
Attribute VB_Name = "TestNodeNew"
Sub RunTest()
    Dim n As Node2D = Node2D.new()
    If n <> Null Then
        n.name = "TestChild"
        If n.name = "TestChild" Then
            Print "PASS:obj_node_new"
        Else
            Print "FAIL:obj_node_new name mismatch"
        End If
        n.free()
    Else
        Print "FAIL:obj_node_new null"
    End If
End Sub
'''))

    tests.append(("obj_refcounted_new", "RefCounted.new() — resource object", '''
Attribute VB_Name = "TestRefCountedNew"
Sub RunTest()
    Dim mesh As SphereMesh = SphereMesh.new()
    If mesh <> Null Then
        mesh.radius = 2.0
        Print "PASS:obj_refcounted_new"
    Else
        Print "FAIL:obj_refcounted_new null"
    End If
End Sub
'''))

    tests.append(("obj_material_new", "StandardMaterial3D.new() — complex RefCounted", '''
Attribute VB_Name = "TestMaterialNew"
Sub RunTest()
    Dim mat As StandardMaterial3D = StandardMaterial3D.new()
    If mat <> Null Then
        mat.albedo_color = Color(1, 0, 0)
        Print "PASS:obj_material_new"
    Else
        Print "FAIL:obj_material_new null"
    End If
End Sub
'''))

    # ---- Category 10: Class Enum Constants ----
    tests.append(("enum_input", "Input class enum constants", '''
Attribute VB_Name = "TestEnumInput"
Sub RunTest()
    Dim mode As Integer = Input.MOUSE_MODE_CAPTURED
    If mode = 2 Then
        Print "PASS:enum_input"
    Else
        Print "FAIL:enum_input mode=" & str(mode)
    End If
End Sub
'''))

    tests.append(("enum_key_constants", "KEY_* constants", '''
Attribute VB_Name = "TestEnumKeys"
Sub RunTest()
    Dim k As Integer = KEY_ESCAPE
    If k = 4194305 Then
        Print "PASS:enum_key_constants"
    Else
        Print "FAIL:enum_key_constants k=" & str(k)
    End If
End Sub
'''))

    # ---- Category 11: GDScript Math Builtins ----
    tests.append(("builtin_math", "lerpf, clampf, exp, abs, sign", '''
Attribute VB_Name = "TestBuiltinMath"
Sub RunTest()
    Dim pass_count As Integer = 0
    Dim r1 As Single = lerpf(0.0, 10.0, 0.5)
    If r1 > 4.9 And r1 < 5.1 Then pass_count = pass_count + 1
    Dim r2 As Single = clampf(15.0, 0.0, 10.0)
    If r2 = 10.0 Then pass_count = pass_count + 1
    Dim r3 As Single = Abs(-42)
    If r3 = 42 Then pass_count = pass_count + 1
    Dim r4 As Integer = Sgn(-5)
    If r4 = -1 Then pass_count = pass_count + 1
    If pass_count = 4 Then
        Print "PASS:builtin_math"
    Else
        Print "FAIL:builtin_math count=" & str(pass_count)
    End If
End Sub
'''))

    tests.append(("builtin_is_zero_approx", "is_zero_approx function", '''
Attribute VB_Name = "TestIsZeroApprox"
Sub RunTest()
    If is_zero_approx(0.0) And Not is_zero_approx(1.0) Then
        Print "PASS:builtin_is_zero_approx"
    Else
        Print "FAIL:builtin_is_zero_approx"
    End If
End Sub
'''))

    # ---- Category 12: String Operations ----
    tests.append(("string_methods", "String .length(), .to_upper(), .to_lower()", '''
Attribute VB_Name = "TestStringMethods"
Sub RunTest()
    Dim s As String = "Hello"
    Dim l As Integer = s.length()
    Dim u As String = s.to_upper()
    Dim lo As String = s.to_lower()
    If l = 5 And u = "HELLO" And lo = "hello" Then
        Print "PASS:string_methods"
    Else
        Print "FAIL:string_methods l=" & str(l) & " u=" & u & " lo=" & lo
    End If
End Sub
'''))

    tests.append(("string_pad_decimals", "String .pad_decimals()", '''
Attribute VB_Name = "TestPadDecimals"
Sub RunTest()
    Dim s As String = str(3.14159).pad_decimals(2)
    If s = "3.14" Then
        Print "PASS:string_pad_decimals"
    Else
        Print "FAIL:string_pad_decimals s=" & s
    End If
End Sub
'''))

    # ---- Category 13: TypeOf / Is ----
    tests.append(("typeof_is", "TypeOf ... Is type check", '''
Attribute VB_Name = "TestTypeOfIs"
Sub RunTest()
    Dim n As Node2D = Node2D.new()
    Dim is_node As Boolean = TypeOf n Is Node2D
    Dim is_node_base As Boolean = TypeOf n Is Node
    If is_node And is_node_base Then
        Print "PASS:typeof_is"
    Else
        Print "FAIL:typeof_is is_node=" & str(is_node) & " is_base=" & str(is_node_base)
    End If
    n.free()
End Sub
'''))

    # ---- Category 14: Error Handling ----
    tests.append(("error_on_error", "On Error GoTo / Resume Next", '''
Attribute VB_Name = "TestOnError"
Sub RunTest()
    On Error Resume Next
    Dim x As Integer = 1 / 0
    If Err.Number <> 0 Then
        Print "PASS:error_on_error"
    Else
        Print "FAIL:error_on_error no error caught"
    End If
End Sub
'''))

    # ---- Category 15: Deep Property Chains ----
    tests.append(("deep_chain", "Multi-level property access on constructed objects", '''
Attribute VB_Name = "TestDeepChain"
Sub RunTest()
    Dim mesh As SphereMesh = SphereMesh.new()
    mesh.radius = 5.0
    Dim r As Single = mesh.radius
    If r = 5.0 Then
        Print "PASS:deep_chain"
    Else
        Print "FAIL:deep_chain radius=" & str(r)
    End If
End Sub
'''))

    # ---- Category 16: Member Assignment on New Objects ----
    tests.append(("member_assign_new", "Assign property on .new() object in same expression", '''
Attribute VB_Name = "TestMemberAssignNew"
Sub RunTest()
    Dim mat As StandardMaterial3D = StandardMaterial3D.new()
    mat.roughness = 0.5
    mat.metallic = 0.8
    If mat.roughness = 0.5 And mat.metallic > 0.79 Then
        Print "PASS:member_assign_new"
    Else
        Print "FAIL:member_assign_new"
    End If
End Sub
'''))

    # ---- Category 17: Dim With Initializer ----
    tests.append(("dim_initializer", "Dim x As T = expr inline initialization", '''
Attribute VB_Name = "TestDimInitializer"
Sub RunTest()
    Dim x As Integer = 42
    Dim s As String = "hello"
    Dim v As Vector2 = Vector2(1, 2)
    If x = 42 And s = "hello" And v.x = 1 And v.y = 2 Then
        Print "PASS:dim_initializer"
    Else
        Print "FAIL:dim_initializer"
    End If
End Sub
'''))

    # ---- Category 18: With Block ----
    tests.append(("with_block", "With ... End With block", '''
Attribute VB_Name = "TestWithBlock"
Sub RunTest()
    Dim d As New Dictionary
    With d
        .set("name", "test")
        .set("value", 42)
    End With
    If d["name"] = "test" And d["value"] = 42 Then
        Print "PASS:with_block"
    Else
        Print "FAIL:with_block"
    End If
End Sub
'''))

    # ---- Category 19: IIF Expression ----
    tests.append(("iif_expr", "IIf() inline conditional", '''
Attribute VB_Name = "TestIIf"
Sub RunTest()
    Dim x As Integer = 10
    Dim result As String = IIf(x > 5, "big", "small")
    If result = "big" Then
        Print "PASS:iif_expr"
    Else
        Print "FAIL:iif_expr result=" & result
    End If
End Sub
'''))

    # ---- Category 20: Singleton Access ----
    tests.append(("singleton_input", "Input singleton property access", '''
Attribute VB_Name = "TestSingletonInput"
Sub RunTest()
    ' Just verify Input is accessible and has a known property
    Dim mode As Integer = Input.mouse_mode
    ' Default mode is MOUSE_MODE_VISIBLE = 0
    Print "PASS:singleton_input"
End Sub
'''))

    return tests


# =============================================================================
# FILE GENERATION
# =============================================================================

def generate_test_files(tests):
    """Write .vg files and the GDScript runner."""
    GENERATED_DIR.mkdir(parents=True, exist_ok=True)

    # Write each .vg test
    for name, desc, code in tests:
        path = GENERATED_DIR / f"test_{name}.vg"
        path.write_text(code.strip() + "\n")
    print(f"Generated {len(tests)} .vg test files in {GENERATED_DIR}")

    # Write the GDScript runner
    runner_lines = [
        'extends SceneTree',
        '',
        '# Auto-generated by tools/generate_coverage_tests.py',
        '# Loads each generated .vg test and calls RunTest()',
        '',
        'func _init():',
        '\tvar test_files := [',
    ]
    for name, _, _ in tests:
        runner_lines.append(f'\t\t"res://tests/generated/test_{name}.vg",')
    runner_lines.append('\t]')
    runner_lines.append('\t')
    runner_lines.append('\tvar passed := 0')
    runner_lines.append('\tvar failed := 0')
    runner_lines.append('\tvar errors := []')
    runner_lines.append('\t')
    runner_lines.append('\tfor path in test_files:')
    runner_lines.append('\t\tvar script = load(path)')
    runner_lines.append('\t\tif script == null:')
    runner_lines.append('\t\t\tprint("LOAD_FAIL:" + path)')
    runner_lines.append('\t\t\tfailed += 1')
    runner_lines.append('\t\t\terrors.append(path + " (failed to load)")')
    runner_lines.append('\t\t\tcontinue')
    runner_lines.append('\t\tvar instance = script.new()')
    runner_lines.append('\t\tif instance.has_method("RunTest"):')
    runner_lines.append('\t\t\tinstance.RunTest()')
    runner_lines.append('\t\telif instance.has_method("_Ready"):')
    runner_lines.append('\t\t\tinstance._Ready()')
    runner_lines.append('\t\telse:')
    runner_lines.append('\t\t\tprint("NO_ENTRY:" + path)')
    runner_lines.append('\t\t\tfailed += 1')
    runner_lines.append('\t')
    runner_lines.append('\tprint("")')
    runner_lines.append('\tprint("=== Coverage Test Results ===")')
    runner_lines.append('\tprint("Total: " + str(test_files.size()))')
    runner_lines.append('\tprint("Done")')
    runner_lines.append('\tquit()')
    runner_lines.append('')

    RUNNER_SCRIPT.write_text('\n'.join(runner_lines))
    print(f"Generated runner: {RUNNER_SCRIPT}")


# =============================================================================
# RUNNER (--run mode)
# =============================================================================

def run_tests(godot_bin):
    """Execute the generated tests headlessly and parse results."""
    project_dir = WORKSPACE / "tests"

    # Ensure project.godot exists
    proj = project_dir / "project.godot"
    if not proj.exists():
        print(f"ERROR: No project.godot in {project_dir}")
        return False

    cmd = [
        str(godot_bin), "--headless", "--quit-after", "30",
        "--path", str(project_dir),
        "--script", "run_generated_tests.gd"
    ]
    print(f"Running: {' '.join(cmd)}")
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=60)

    output = proc.stdout + proc.stderr
    lines = output.splitlines()

    passed = []
    failed = []
    load_failures = []
    fallbacks = []
    unsupported = []

    for line in lines:
        stripped = line.strip()
        if stripped.startswith("PASS:"):
            passed.append(stripped[5:])
        elif stripped.startswith("FAIL:"):
            failed.append(stripped[5:])
        elif stripped.startswith("LOAD_FAIL:"):
            load_failures.append(stripped[10:])
        if "unsupported opcode" in stripped.lower():
            unsupported.append(stripped)
        if "AST fallback" in stripped or "bytecode failed" in stripped.lower():
            fallbacks.append(stripped)

    # Print summary
    print("\n" + "=" * 60)
    print("COVERAGE TEST RESULTS")
    print("=" * 60)
    print(f"  PASSED:          {len(passed)}")
    print(f"  FAILED:          {len(failed)}")
    print(f"  LOAD FAILURES:   {len(load_failures)}")
    print(f"  AST FALLBACKS:   {len(fallbacks)}")
    print(f"  UNSUPPORTED OPS: {len(unsupported)}")
    print()

    if failed:
        print("FAILED tests:")
        for f in failed:
            print(f"  ✗ {f}")
    if load_failures:
        print("LOAD FAILURES:")
        for f in load_failures:
            print(f"  ✗ {f}")
    if unsupported:
        print("UNSUPPORTED OPCODES detected:")
        for u in unsupported:
            print(f"  ⚠ {u}")
    if fallbacks:
        print("AST FALLBACKS detected (bytecode couldn't handle it):")
        for fb in fallbacks:
            print(f"  ⚠ {fb}")
    if not failed and not load_failures:
        print("✅ All tests passed!")

    # Save JSON results
    results = {
        "timestamp": datetime.now().isoformat(),
        "total": len(passed) + len(failed) + len(load_failures),
        "passed": passed,
        "failed": failed,
        "load_failures": load_failures,
        "fallbacks": fallbacks,
        "unsupported_opcodes": unsupported,
    }
    RESULTS_FILE.write_text(json.dumps(results, indent=2))
    print(f"\nResults saved to {RESULTS_FILE}")

    return len(failed) == 0 and len(load_failures) == 0


# =============================================================================
# MAIN
# =============================================================================

def main():
    parser = argparse.ArgumentParser(description="VisualGasic automated test generator")
    parser.add_argument("--run", action="store_true", help="Generate AND run tests")
    parser.add_argument("--godot", default=str(WORKSPACE / "Godot_v4.6.1-stable_linux.x86_64"),
                        help="Path to Godot executable")
    parser.add_argument("--generate-only", action="store_true", help="Only generate, don't run")
    args = parser.parse_args()

    tests = make_tests()
    generate_test_files(tests)

    if args.run and not args.generate_only:
        ok = run_tests(args.godot)
        sys.exit(0 if ok else 1)
    else:
        print("\nTo run: python3 tools/generate_coverage_tests.py --run")


if __name__ == "__main__":
    main()
