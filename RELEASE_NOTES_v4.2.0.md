# Release Notes — VisualGasic v4.2.0

**Date**: March 13, 2026  
**Codename**: GDScript Parity  
**Theme**: Close the four biggest feature gaps between VisualGasic and GDScript

---

## 🚀 Headline Features

### 1. `Export` — Inspector Integration
```vb
Export Public Speed As Single        ' Shows in Godot Inspector!
Export Dim Health As Integer
Export Public PlayerName As String
```
Variables marked with `Export` are exposed to the Godot Inspector panel with full type mapping. Supports `Integer`, `Single`/`Double`/`Float`, `String`, `Boolean`, `Color`, `Vector2`, `Vector3`, and `NodePath`. Default literal values are provided to the editor.

### 2. `Await` — Real Coroutine Suspension
```vb
Await $AnimationPlayer.animation_finished   ' Signal await — suspends, resumes on fire
Await 2.0                                    ' Timer await — suspends for 2 seconds
Await SomeNonSignal                          ' Synchronous fallback — no-op
```
`Await` now performs actual coroutine suspension:
- **Signal**: Connects one-shot, saves IP + locals to `CoroutineState`, yields VM, resumes on signal fire
- **Timer**: Creates a `SceneTreeTimer`, saves state, resumes after timeout
- **Other**: Synchronous no-op fallback for non-signal/non-timer values

### 3. `Import` — Cross-File Module System
```vb
Import "utils/MathHelper.vg"
Import GameConfig                    ' Resolves to GameConfig.vg

Sub _Ready()
    Dim val = MathHelper.PI_APPROX   ' Access imported module's constants
End Sub
```
Imported modules are loaded, parsed, and their Public variables/constants are registered in the `module_registry` Dictionary. Paths resolve relative to the current script directory.

### 4. `ClassName` + `$NodeName` — Script Registration & Node Shorthand
```vb
ClassName MyPlayer                   ' Globally registered script class
```
```vb
Dim label = $ScoreLabel              ' Shorthand for GetNode("ScoreLabel")
Dim unique = $%UniqueNode            ' Unique-name: GetNode("%UniqueNode")
Dim deep = $UI/Panel/Button          ' Path navigation supported
```

---

## 🔧 Technical Changes

### Tokenizer
- Added `TOKEN_NODE_PATH` token type
- Added `Export`, `Import`, `ClassName` keywords
- `$identifier` / `$%identifier` / `$path/name` lexing before `$"` interpolation

### AST
- `DimStatement.is_export` and `VariableDefinition.is_export` flags
- `ModuleNode.imports` (Vector<String>) and `ModuleNode.class_name_vg` (String)
- New `AwaitStatement` struct (wraps expression, uses `STMT_AWAIT` type)

### Parser
- `Export` prefix handler at module level — consumes keyword, sets flag, falls through to Dim/Public/Private
- `Import` handler — accepts string literals or bare identifiers
- `ClassName` handler — stores identifier in `ModuleNode::class_name_vg`
- `TOKEN_NODE_PATH` in `parse_factor()` — desugars to `CallExpression("GetNode", [name])`
- `parse_await()` rewritten to produce `AwaitStatement` instead of `AssignmentStatement`

### Script
- `_get_global_name()` returns `class_name_vg` when set
- `_get_script_property_list()` adds `PROPERTY_USAGE_EDITOR` for exported vars
- `_has_property_default_value()` / `_get_property_default_value()` for literal defaults
- `_has_method("_vg_resume_coroutine")` returns true for coroutine dispatch

### Bytecode Compiler
- `STMT_AWAIT` now compiles expression + `OP_AWAIT` (was empty placeholder)

### Bytecode VM
- `OP_AWAIT` pops awaited value, checks `Signal`/`INT`/`FLOAT`/other
- Signal path: one-shot connect → save `CoroutineState` → `goto cleanup`
- Timer path: `SceneTreeTimer` → save state → yield
- Fallback: synchronous no-op (consumed, continue)

### Instance
- `_resume_coroutine()` — pops from `coroutine_stack`, restores locals, resumes `execute_bytecode()` at saved IP
- `_vg_resume_coroutine` call dispatch in `call()` method
- Import resolution in constructor: loads .vg files, parses, registers in `module_registry`

---

## 🐛 Known Issues Audit
Verified all 16 known bugs against source code:
- **11 fixed** (Negative For step, Print #N, Try/Catch, STMT_TASK_RUN, Variable shadowing, Local Const, 0x hex, Inline Sub() lambdas, Division by zero, On Error partial)
- **7 open** (Dict.Count, Keys() indexing, ToByteArray, Task scope cloning, Thread+scene-tree crash, Task reserved word, Implements runtime)

---

## 📊 Test Suite
| Metric | v4.1.0 | v4.2.0 |
|--------|--------|--------|
| Files | 65 | 69 |
| Assertions | 602 | 611 |
| Passed | 600 | 609 |
| Pass Rate | 99.7% | 99.7% |

New test files: `test_export.vg` (5), `test_await.vg` (2), `test_classname.vg` (1), `test_node_shorthand.vg` (1)

---

## Files Changed
- `src/visual_gasic_tokenizer.h` — TOKEN_NODE_PATH enum
- `src/visual_gasic_tokenizer.cpp` — keywords + $name lexing
- `src/visual_gasic_ast.h` — is_export, imports, class_name_vg, AwaitStatement
- `src/visual_gasic_parser.cpp` — Export/Import/ClassName/TOKEN_NODE_PATH/parse_await
- `src/visual_gasic_script.cpp` — _get_global_name, _get_script_property_list, _has_method
- `src/visual_gasic_compiler.cpp` — STMT_AWAIT expression compilation
- `src/visual_gasic_instance_bytecode_vm.cpp` — OP_AWAIT coroutine dispatch
- `src/visual_gasic_instance.h` — _resume_coroutine declaration
- `src/visual_gasic_instance_multitask.cpp` — _resume_coroutine implementation
- `src/visual_gasic_instance_call.inc` — _vg_resume_coroutine dispatch
- `src/visual_gasic_instance.cpp` — Import resolution in constructor
