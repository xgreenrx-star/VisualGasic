# VisualGasic v3.5.0-beta4 Release Notes

## Desktop Readiness — Language Features (Items 5–8)

This release completes the remaining desktop readiness audit items, bringing VB6
language feature parity closer to full coverage.

---

### New Features

#### RaiseEvent Bytecode Support
RaiseEvent previously only worked in the AST interpreter path. It is now fully
compiled to bytecode (`OP_RAISE_EVENT`), so modules using bytecode execution can
emit Godot signals with up to 5 arguments.

**Files changed:** `visual_gasic_bytecode.h`, `visual_gasic_compiler.cpp`,
`visual_gasic_instance_bytecode_vm.cpp`, `visual_gasic_optimizer.cpp`,
`visual_gasic_jit_tier2.cpp`

#### WithEvents Keyword
`Dim WithEvents obj As ClassName` is now parsed and stored in the AST. At
runtime, when a WithEvents variable is assigned an object (via `Set obj = ...`),
all matching `obj_EventName` subs in the module are automatically connected to
the source object's Godot signals.

```vb
Dim WithEvents tmr As Timer

Sub tmr_Timeout()
    Print "Timer fired!"
End Sub

Sub Form_Load()
    Set tmr = GetNode("Timer1")   ' auto-wires tmr_Timeout to Timer.timeout
End Sub
```

#### Implements Runtime Verification
`Implements InterfaceName` is now captured at module level (not just as a
statement). At script load, the runtime checks that at least one
`InterfaceName_MethodName` sub exists and logs a warning if none are found.

#### Printer Built-in Object
A full `Printer` object is available with the standard VB6 API surface:

| Method / Property | Description |
|---|---|
| `Printer.Print text` | Output text (logs to console) |
| `Printer.EndDoc` | End print job (stub) |
| `Printer.NewPage` | Start new page (stub) |
| `Printer.KillDoc` | Cancel print job (stub) |
| `Printer.Font` | Returns "Arial" |
| `Printer.FontSize` | Returns 12 |
| `Printer.Orientation` | Returns 1 (Portrait) |
| `Printer.Copies` | Returns 1 |
| `Printer.ScaleWidth` / `ScaleHeight` | Default page dimensions in twips |

#### PrintForm Statement
`PrintForm` captures the current Godot viewport to a PNG image saved at
`user://PrintForm_<timestamp>.png`.

### Confirmed Working (No Changes Needed)
- **Optional parameters** — `call_internal()` already fills `default_value` for
  any omitted Optional arguments in both AST and bytecode paths
- **Enum declarations** — fully working with `.Parse()`, `.Values()`, `.ToString()`
- **Type/UDT** — fully working across parser, compiler, and runtime

---

### Build

```bash
scons platform=linux target=editor -j$(nproc)
```

### Compatibility
- Godot 4.6.1 stable
- godot-cpp 4.5.1
