# VisualGasic Test Coverage Report

**Test Suite**: 28 files · **233 assertions** · **100% pass rate**

Run with: `bash run_test_suite.sh`

---

## Test File → Feature Matrix

| Test File | Assertions | Features Covered |
|-----------|:---:|---|
| **test_array_funcs.vg** | 8 | `Range()`, `Join()`, `Split()`, `Filter()`, `Array()`, `UBound()`, `LBound()`, `ReDim` |
| **test_arrays.vg** | 9 | `Dim arr(N)`, indexed access, `UBound`, `ReDim`, `ReDim Preserve`, multi-dim arrays, dynamic resize, iteration |
| **test_byref_byval.vg** | 7 | `ByRef` params (default), `ByVal` params, ByRef mutation, ByRef with function return expressions, swap via ByRef |
| **test_class_basic.vg** | 3 | `Class...End Class`, properties, methods, `Set obj = New ClassName`, member access |
| **test_conditional_funcs.vg** | 7 | `IIf()`, `Choose()`, `Switch()`, `TypeName()` in conditions, nested conditionals |
| **test_constants.vg** | 6 | `Const`, string/numeric/boolean constants, `vbCrLf`, `vbTab`, `vbNullString` built-in constants |
| **test_continue.vg** | 3 | `Continue For`, `Continue Do`, loop continuation semantics |
| **test_data_read.vg** | 7 | `Data`, `Read`, sequential reads, string/numeric data, `Restore`, multiple data lines |
| **test_dictionary.vg** | 8 | `New Dictionary`, `.Add`, `.Item()`, `.Exists()`, `.Remove`, `.Count`, `.Keys`, `.Items` |
| **test_do_loop.vg** | 8 | `Do While...Loop`, `Do Until...Loop`, `Do...Loop While`, `Do...Loop Until`, `Exit Do`, counter patterns |
| **test_enum.vg** | 9 | `Enum...End Enum`, auto-increment values, explicit values, mixed values, enum comparison, enum in expressions |
| **test_error_handling.vg** | 5 | `On Error Resume Next`, `On Error GoTo 0`, `Err.Number`, `Err.Description`, `Err.Clear` |
| **test_for_each.vg** | 3 | `For Each...Next` with arrays, dictionaries, string iteration |
| **test_for_loop.vg** | 8 | `For...Next`, `Step`, negative step, `Exit For`, nested loops, counter after loop |
| **test_goto.vg** | 3 | `GoTo label`, label definitions, forward jumps, skip-over patterns |
| **test_if_then.vg** | 9 | `If...Then`, `ElseIf`, `Else`, `End If`, single-line If, nested If, `And`/`Or` in conditions |
| **test_lambda.vg** | 5 | `Lambda` expressions, lambda with parameters, lambda assignment, lambda call, lambda in expressions |
| **test_math_funcs.vg** | 18 | `Abs`, `Int`, `Fix`, `Sgn`, `Sqr`, `Round`, `Log`, `Exp`, `Sin`, `Cos`, `Tan`, `Atn`, `Rnd`, `Hex`, `Oct`, `Min`, `Max`, `Clamp` |
| **test_operators.vg** | 23 | `+`, `-`, `*`, `/`, `\` (int div), `Mod`, `^`, `&` (concat), `=`, `<>`, `<`, `>`, `<=`, `>=`, `And`, `Or`, `Not`, `Xor`, `Is`, `Like`, string comparison, type coercion in ops |
| **test_optional_params.vg** | 4 | `Optional` parameters, default values, mixed required/optional params, `IsMissing()` |
| **test_process.vg** | 4 | `_Process(delta)` callback, frame counting, delta timing, multi-frame execution |
| **test_scope.vg** | 6 | Module-level `Dim`, local `Dim`, variable shadowing, scope isolation, module variables persist across subs |
| **test_select_case.vg** | 7 | `Select Case`, `Case value`, `Case Else`, `Case Is >`, `Case a To b` (range), multiple values per case, string cases |
| **test_string_funcs.vg** | 23 | `Len`, `Left`, `Right`, `Mid`, `InStr`, `InStrRev`, `Trim`, `LTrim`, `RTrim`, `UCase`, `LCase`, `Replace`, `StrReverse`, `Space`, `String()`, `Asc`, `Chr`, `Val`, `Str`, `CStr`, `Format`, `Split`, `Join` |
| **test_sub_function.vg** | 9 | `Sub...End Sub`, `Function...End Function`, `Return` keyword, function return via name assignment, `Call` statement, parameter passing, recursion, `Exit Sub`, `Exit Function` |
| **test_type_conversion.vg** | 16 | `CInt`, `CLng`, `CDbl`, `CSng`, `CStr`, `CBool`, `CByte`, `Val`, `Str`, `Int`, `Fix`, `Hex`, `Oct`, `TypeName`, `VarType`, implicit conversions |
| **test_variables.vg** | 13 | `Dim`, `As Integer/Long/Double/Single/String/Boolean/Variant`, variant reassignment across types, string concatenation, boolean logic, type preservation |
| **test_variant_debug.vg** | 2 | Variant cross-type reassignment (numeric → string), `TypeName()` on variants |

---

## Language Feature Coverage Summary

### ✅ Fully Tested
- **Control Flow**: If/ElseIf/Else, For/Next, For Each, Do/Loop (While/Until), Select Case, GoTo, Continue, Exit
- **Data Types**: Integer, Long, Double, Single, String, Boolean, Variant, Byte
- **Procedures**: Sub, Function, Return, Optional params, ByRef/ByVal, Lambda
- **OOP**: Class, Properties, Methods, New
- **Data Structures**: Arrays (static, dynamic, ReDim), Dictionary, Enum
- **Error Handling**: On Error Resume Next/GoTo 0, Err object
- **Operators**: Arithmetic, Comparison, Logical, String concatenation, Is, Like
- **Built-in Functions**: 50+ math, string, type conversion, conditional, and array functions
- **Constants**: Const declarations, built-in VB constants (vbCrLf, vbTab, etc.)
- **Other**: Data/Read/Restore, Scope rules, _Process callback, Module-level variables

### ⚠️ Not Testable (Headless)
- **Whenever** (reactive event system) — requires `_Process()` frame loop with scene tree
- **UI/Form keywords** — `Form`, `Command`, `Label`, `TextBox`, `PictureBox` etc.
- **Audio** — `PlaySound`, `StopSound`
- **Graphics** — `DrawLine`, `DrawCircle`, `DrawRect`, `Cls`, `PSet`
- **Input** — `KeyDown`, `MouseClick`, `MouseMove`
- **Timer** — `SetTimer`, `KillTimer`
- **File I/O** — `Open`, `Close`, `Print #`, `Input #`, `Write #` (sandboxed)

---

## Bugs Fixed by Test Suite

| Bug | Test | Root Cause | Fix |
|-----|------|-----------|-----|
| #15 | test_sub_function | Compiler emitted `OP_RETURN` (bare) for `Return <expr>` | Emit `OP_RETURN_VALUE` when return value exists |
| #16 | test_enum | "Enum" missing from tokenizer keywords + no module-level parse handler | Added keyword + module-level `parse_enum()` call |
| #17 | test_array_funcs | `Range()` used exclusive upper bound (`i < end`) | Changed to inclusive (`i <= end`) |
| #18 | test_variables | `assign_variable()` forced type coercion across incompatible types | Smart family-based coercion only |
| #19 | test_type_conversion | `TypeName()` returned Godot names ("float", "int") | Returns VB-style names ("Double", "Integer") |
| #20 | test_byref_byval | Expression-level `call_internal()` skipped ByRef write-back | Added ByRef write-back after expression-level calls |
