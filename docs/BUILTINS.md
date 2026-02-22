# Builtin Functions & Extension Points

This document describes the built-in functions and the public extension points introduced during the refactor that centralize expression evaluation and builtin handling.

## Overview
- Expression-level builtins are handled by `VisualGasicBuiltins::call_builtin_expr` and `call_builtin_expr_evaluated`.
- Statement-level builtins are handled by `VisualGasicBuiltins::call_builtin`.
- There are helper dispatch functions for base-specific behavior: `call_builtin_for_base_variable`, `call_builtin_for_base_object`, and `call_builtin_for_base_variant`.
- `VisualGasicInstance` exposes a small set of public wrappers used by the builtins module (see below).

## Notable Expression Builtins

String helpers:
- `Len(s)`, `Left(s,n)`, `Right(s,n)`, `Mid(s,start[,len])`
- `UCase(s)`, `LCase(s)`, `Asc(s)`, `Chr(n)`, `Space(n)`, `Str`, `Val`, `InStr`, `Replace`, `Trim`, `LTrim`, `RTrim`, `StrReverse`, `Hex`, `Oct`, `Split`, `Join`

Array helpers:
- `UBound(arr)`, `LBound(arr)`

Math helpers (some handled in `call_builtin_expr_evaluated` — they expect already-evaluated args):
- `Sin`, `Cos`, `Tan`, `Log`, `Exp`, `Atn`, `Sqr`, `Abs`, `Sgn`, `Int`, `Rnd`, `Round`, `RandRange`, `Lerp`, `Clamp`, `CInt`, `CDbl`, `CBool`

File/dir helpers (delegate to `VisualGasicInstance` wrappers):
- `LOF(fileHandle)`, `Loc(fileHandle)`, `EOF(fileHandle)`, `FreeFile([range])`, `FileLen(path)`, `Dir(...)`, `Randomize()`
- `Timer()` — Seconds since midnight as Double *(New in v2.10.0)*

Statement-level builtins (examples):
- `MsgBox(message[, buttons, title])` — shows a dialog with VB6-style button/icon constants
- `InputBox(prompt[, title, default])` — shows an input dialog and returns the result

### MsgBox Constants

VisualGasic supports all VB6 MsgBox constants:

**Button Constants (additive):**
| Constant | Value | Description |
|----------|-------|-------------|
| `vbOKOnly` | 0 | OK button only (default) |
| `vbOKCancel` | 1 | OK and Cancel buttons |
| `vbAbortRetryIgnore` | 2 | Abort, Retry, Ignore buttons |
| `vbYesNoCancel` | 3 | Yes, No, Cancel buttons |
| `vbYesNo` | 4 | Yes and No buttons |
| `vbRetryCancel` | 5 | Retry and Cancel buttons |

**Icon Constants (additive):**
| Constant | Value | Description |
|----------|-------|-------------|
| `vbCritical` | 16 | Critical/Error icon |
| `vbQuestion` | 32 | Question mark icon |
| `vbExclamation` | 48 | Warning/Exclamation icon |
| `vbInformation` | 64 | Information icon |

**Return Values:**
| Constant | Value | Description |
|----------|-------|-------------|
| `vbOK` | 1 | User clicked OK |
| `vbCancel` | 2 | User clicked Cancel |
| `vbAbort` | 3 | User clicked Abort |
| `vbRetry` | 4 | User clicked Retry |
| `vbIgnore` | 5 | User clicked Ignore |
| `vbYes` | 6 | User clicked Yes |
| `vbNo` | 7 | User clicked No |

**Example:**
```vb
' Simple message
MsgBox "Hello World!"

' With buttons and icon
Dim result As Integer
result = MsgBox("Save changes?", vbYesNoCancel + vbQuestion, "Confirm")

If result = vbYes Then
    ' Save...
ElseIf result = vbNo Then
    ' Don't save...
Else
    ' Cancel
End If
```

Base-specific handlers:
- `Clipboard.GetText()`, `Clipboard.SetText(text)`, `Clipboard.Clear()`
- `Tree.GetTextMatrix(row,col)`, `Tree.SetTextMatrix(row,col,text)`, `Tree.AddItem(text)`, `Tree.RemoveItem(index)`
- `Connect` helpers that simplify signal wiring
- `Err`-style dictionary helpers (`Clear`, `Raise`) which call back into the instance to raise runtime errors

### VB6 Global Objects *(New in v2.10.0)*

Three virtual objects are resolved automatically when referenced by name (no `Dim` required):

- **App** — `App.Path`, `App.EXEName`, `App.Title`, `App.Major`, `App.Minor`, `App.Revision`, `App.PrevInstance`, `App.ProductName`, `App.CompanyName`
- **Screen** — `Screen.Width`, `Screen.Height`, `Screen.TwipsPerPixelX`, `Screen.TwipsPerPixelY`, `Screen.MousePointer`
- **Err** — `Err.Number`, `Err.Description`, `Err.Source`, `Err.Clear`, `Err.Raise`

These are `Dictionary` instances initialized in the constructor and added to `non_local_names` in the compiler so they bypass local variable scoping.

### COM-Style Object Classes *(New in v2.10.0)*

Four C++ classes are registered with Godot ClassDB and instantiable via `New` or `CreateObject()`:

| Class | ProgIDs | Description |
|-------|---------|-------------|
| `VGCollection` | `VB6.Collection`, `VBA.Collection` | 1-based ordered collection with string keys |
| `VGRegEx` + `VGRegExMatch` | `VBScript.RegExp` | RegExp engine wrapping Godot PCRE2 |
| `VGHttpRequest` | `MSXML2.XMLHTTP` | HTTP client wrapping Godot HTTPClient |
| `VGTimer` | *(via New VBTimer)* | Poll-based timer with Interval/Enabled |

### File I/O Bytecode Opcodes *(New in v2.10.0)*

Four new bytecode opcodes for compiled file I/O:
- `OP_PRINT_FILE` — `Print #n, expr`
- `OP_WRITE_FILE` — `Write #n, expr`
- `OP_INPUT_FILE` — `Input #n, var`
- `OP_LINE_INPUT_FILE` — `Line Input #n, var`

### GoSub/Return *(New in v2.10.0)*

Intra-procedure branching compiled to bytecode:
- `OP_GOSUB` — Push return address and jump to label
- `OP_RETURN_GOSUB` — Pop and return to address
- Managed via a `gosub_stack` (Vector<int>) in the bytecode VM.

## VisualGasicInstance public wrappers
The builtins implementation uses a handful of instance helpers. These are documented here so extension authors know where to call into the runtime.

- `Variant evaluate_expression_for_builtins(ExpressionNode *expr)`
  - Evaluates an expression from the instance context; used by builtins that accept expressions as arguments.

- File/IO wrappers (renamed):
  - `Variant file_lof(int handle)`
  - `Variant file_loc(int handle)`
  - `Variant file_eof(int handle)`
  - `int file_free(int range)`
  - `Variant file_len(const String &path)`
  - `Variant file_dir(const Array &args)`
  - `void randomize_seed()`

- Error raising wrapper (renamed):
  - `void raise_runtime_error(const String &msg, int code)` — used by Err.Raise and similar flows.

These wrappers are intentionally small and stable to allow `visual_gasic_builtins.cpp` to be compiled in a separate translation unit while still using instance functionality.

## Extension points for third-party code

If you want to extend or override builtins:
- Implement a new dispatch in `visual_gasic_builtins.cpp` or add another translation unit that follows the same pattern.
- Use `call_builtin_expr` / `call_builtin_expr_evaluated` for expression-level functions. `call_builtin_expr` receives a `CallExpression*` and may evaluate arguments itself; `call_builtin_expr_evaluated` accepts already-evaluated `Array` of args.
- Use `call_builtin` for statement-level functions. Return `r_found = true` and set `r_ret` if returning a value.
- For base-object/variant-specific behavior, implement handling in `call_builtin_for_base_object` / `call_builtin_for_base_variant` / `call_builtin_for_base_variable` respectively.

## Examples

Simple BASIC usage:

```
Dim s
 s = Left("hello", 2)    ' returns "he"
 Print Len(s)             ' prints 2

Call MsgBox("Done")
```

Calling from C++ builtins (pseudo):

``cpp
bool r_handled = false;
Variant result = VisualGasicBuiltins::call_builtin_expr_evaluated(instance, "Len", {String("abc")}, r_handled);
if (r_handled) { /* use result */ }
```

## Tests

There is a small runtime test under `demo/test_builtins.bas` and a runner `tests/run_builtin_tests.py` that builds and executes the demo headless to validate core builtins.

## Notes and future work

- Add unit tests for `VisualGasicBuiltins` and `VisualGasicExpressionEvaluator` as C++/Godot tests to provide faster feedback than full headless runs.
- Consider moving more builtins behind a registration API to enable plugins to add builtins without editing core source files.
