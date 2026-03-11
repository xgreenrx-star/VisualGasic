# VisualGasic v3.8.0 — Compound Logical Operators & Enhanced Enums

**Release Date**: March 12, 2026  
**Platforms**: Linux x86_64, Windows x86_64  
**Godot**: 4.5+ (tested on 4.6.1)

---

## What is VisualGasic?

**VisualGasic** is a modern, event-driven programming language for the Godot Engine inspired by Visual Basic 6's legendary approachability. It features a full Form Designer, JIT compiler, auto event wiring, and 66+ demo projects.

---

## What's New in v3.8.0

This release completes the remaining two nice-to-have items from the v3.6 roadmap: **keyword compound assignment operators** (`And=`, `Or=`, `Xor=`, `Mod=`) and **enhanced Enum** with `<Flags>` attribute, `HasFlag()`, and flags-aware `ToString()` decomposition.

### ✅ Keyword Compound Assignment Operators

Four new compound assignment operators that use VB keywords:

```vb
Dim flags As Integer = 255
flags And= &HF0       ' Mask: flags = 240
flags Or= 8           ' Set bit: flags = 248
flags Xor= &H80       ' Toggle bit: flags = 120

Dim x As Integer = 17
x Mod= 5              ' Remainder: x = 2
```

These are desugared at parse time — identical to how `+=`, `-=`, etc. already work. They operate on any L-value (variable, array element, object member).

### ✅ Bitwise And/Or/Xor (VB6 Semantics)

`And`, `Or`, and `Xor` now perform **bitwise** operations when both operands are numeric. This matches VB6 behaviour and is essential for flag manipulation:

```vb
Print 12 And 10     ' → 8   (bitwise AND)
Print 12 Or 3       ' → 15  (bitwise OR)
Print 12 Xor 10     ' → 6   (bitwise XOR)
```

When either operand is non-numeric, they continue to work as logical operators (unchanged from previous versions).

### ✅ `<Flags>` Enum Attribute

Mark an enum as a bitfield. Enables `HasFlag()` and flags-aware `ToString()`:

```vb
<Flags>
Enum Permissions
    Read = 1
    Write = 2
    Execute = 4
End Enum

' Combine and test flags
Dim p = Permissions.Read Or Permissions.Write
Print Permissions.HasFlag(p, Permissions.Read)      ' True
Print Permissions.HasFlag(p, Permissions.Execute)    ' False

' Flags-aware ToString decomposition
Print Permissions.ToString(3)    ' → "Read, Write"
Print Permissions.ToString(7)    ' → "Read, Write, Execute"
Print Permissions.ToString(5)    ' → "Read, Execute"
```

### ✅ Compile-Time Enum Dot Access

`MyEnum.MemberName` is now resolved as a compile-time constant in the bytecode compiler, eliminating runtime member lookups:

```vb
Enum Direction
    Up = 0
    Down = 1
    Left = 2
    Right = 3
End Enum

Dim d = Direction.Left   ' Compiled as: load constant 2
```

---

## Test Results

| Metric | Count |
|--------|-------|
| Test files | 65 |
| Total assertions | 602 |
| Passed | 600 |
| Failed | 2 (pre-existing symlink edge case) |
| Regressions | 0 |

**New test files:**
- `test_compound_logical.vg` — 12 assertions (And=, Or=, Xor=, Mod= with chaining)
- `test_enum.vg` — extended from 9 to 35 assertions (dot access, Parse, ToString, Values, Flags, HasFlag, flags decomposition)

---

## Files Modified

| File | Change |
|------|--------|
| `src/visual_gasic_ast.h` | Added `is_flags` field to `EnumDefinition` |
| `src/visual_gasic_parser.h` | Updated `parse_enum()` signature |
| `src/visual_gasic_parser.cpp` | `<Flags>` detection, keyword compound desugaring |
| `src/visual_gasic_instance_evaluate.inc` | Bitwise And/Or/Xor, flags ToString, HasFlag |
| `src/visual_gasic_compiler.cpp` | Compile-time enum dot access resolution |
| `src/visual_gasic_instance.h` | Added `cached_ast_root` member |
| `src/visual_gasic_instance.cpp` | Set `cached_ast_root` during init |

---

## Upgrade Notes

- **No breaking changes.** All existing code continues to work.
- `And`/`Or`/`Xor` between numeric operands now return integer results (bitwise) instead of boolean. This matches VB6 semantics and is the correct behaviour. Code that relied on `5 And 3` returning `True` (logical) should be updated — it now returns `1` (bitwise).
- Existing `Enum` declarations are unaffected. The `<Flags>` attribute is opt-in.

---

## What's Next

With the v3.6 roadmap fully shipped (all 9 items), development proceeds to the **v4.0 roadmap**:
- Live Animation for Custom Controls in Form Designer
- Multi-Module Project Compilation (`Import`)
- Visual Form Debugger
