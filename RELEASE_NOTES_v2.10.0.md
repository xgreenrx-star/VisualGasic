# VisualGasic v2.10.0 Release Notes

## Overview
Major feature release adding 10 new VB6/VBScript-compatible system classes, built-in objects, language features, and bytecode opcodes.

## New System Classes

### VGHttpRequest
MSXML2.XMLHTTP emulation wrapping Godot HTTPClient. Supports `open`, `send`, `setRequestHeader`, `getResponseText`, `getStatus`, and `getAllResponseHeaders`. Compatible with `CreateObject("MSXML2.XMLHTTP")`.

### VGCollection
VB6 ordered Collection with string keys. API: `Add(item, key, before, after)`, `Remove`, `Item`, `Count`, `HasKey`, `Clear`, `ToArray`. 1-based indexing. Instantiate with `Dim col As New Collection`.

### VGRegEx + VGRegExMatch
VBScript.RegExp emulation wrapping Godot RegEx (PCRE2). Supports `Pattern`, `Global`, `IgnoreCase`, `Test`, `Execute`, `Replace`. Compatible with `CreateObject("VBScript.RegExp")`.

### VGTimer
Poll-based timer control. Properties: `Interval` (ms), `Enabled`. Static `Timer()` function returns seconds since midnight. Instantiate with `Dim tmr As New VBTimer`.

## Built-in Virtual Objects

### App Object
VB6 `App` global object with properties: `Path`, `EXEName`, `Title`, `Major`, `Minor`, `Revision`, `PrevInstance`, `ProductName`, `CompanyName`. Works in both bytecode VM and AST interpreter.

### Screen Object
VB6 `Screen` global object with properties: `Width`, `Height`, `TwipsPerPixelX`, `TwipsPerPixelY`, `MousePointer`.

### Err Object
VB6 `Err` global object with `Number`, `Description`, `Source` properties. Supports `Err.Raise(number, source, description)` and `Err.Clear`. Integrates with `On Error Resume Next`.

## Language Features

### GoSub / Return
Classic VB6 `GoSub label` / `Return` with gosub return stack. Bare `Return` checks the gosub stack first, falls back to `Exit Sub` if empty.

### Implements (Interfaces)
`Implements InterfaceName` keyword parsing and stub runtime handler. Foundation for interface-based polymorphism.

## Bytecode VM Enhancements

### File I/O Opcodes
8 new bytecode opcodes: `OP_OPEN_FILE`, `OP_CLOSE_FILE`, `OP_PRINT_FILE`, `OP_WRITE_FILE`, `OP_INPUT_FILE`, `OP_LINE_INPUT`, `OP_GOSUB`, `OP_RETURN_GOSUB`.

### Compiler Improvements
- `App`, `Screen`, `Err` marked as `non_local_names` so the compiler routes them through `OP_GET_GLOBAL` for proper virtual object resolution.
- New emit cases: `STMT_OPEN`, `STMT_CLOSE`, `STMT_INPUT`, `STMT_WRITE`, `STMT_GOSUB`, `STMT_RETURN_GOSUB`, `STMT_IMPLEMENTS`.

### COM Interop Expansion
New supported ProgIDs: `MSXML2.XMLHTTP`, `MSXML2.ServerXMLHTTP`, `Microsoft.XMLHTTP`, `VBScript.RegExp`, `VB6.Collection`, `VBA.Collection`.

## Test Results
- 16/16 new feature tests pass
- All existing regression tests pass
- Both bytecode VM and AST interpreter paths verified

## Files Changed
- **New**: `visual_gasic_http.h/.cpp`, `visual_gasic_collection.h/.cpp`, `visual_gasic_regex.h/.cpp`, `visual_gasic_timer.h/.cpp`
- **Modified**: `register_types.cpp`, `visual_gasic_ast.h`, `visual_gasic_builtins.cpp`, `visual_gasic_bytecode.h`, `visual_gasic_com_interop.cpp`, `visual_gasic_compiler.cpp`, `visual_gasic_instance.cpp`, `visual_gasic_instance.h`, `visual_gasic_instance_bytecode_vm.cpp`, `visual_gasic_parser.cpp`
