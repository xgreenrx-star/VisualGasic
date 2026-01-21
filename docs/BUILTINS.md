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

Statement-level builtins (examples):
- `MsgBox(message[, buttons, title])` — shows a dialog
- `InputBox(prompt[, title, default])` — shows an input dialog and returns the result

Base-specific handlers:
- `Clipboard.GetText()`, `Clipboard.SetText(text)`, `Clipboard.Clear()`
- `Tree.GetTextMatrix(row,col)`, `Tree.SetTextMatrix(row,col,text)`, `Tree.AddItem(text)`, `Tree.RemoveItem(index)`
- `Connect` helpers that simplify signal wiring
- `Err`-style dictionary helpers (`Clear`, `Raise`) which call back into the instance to raise runtime errors

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
