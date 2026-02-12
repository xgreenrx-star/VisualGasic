# VisualGasic v2.4.1 Release Notes

**Release Date**: 2025  
**Codename**: Optimizer & Tooling  
**Tag**: v2.4.1

---

## 🎮 Galactic Defender — Showpiece Game Demo

A full-featured tower defense game showcasing every major VisualGasic feature in a single script:

- **~1,600 lines** of pure VisualGasic code
- **13 classes** with 3-level inheritance chains (`Entity → Tower → Blaster/Cannon/Tesla/Missile`, `Entity → Enemy → Scout/Soldier/Tank/Flyer/Boss`)
- **7 `Whenever` sections** — event-driven game logic (wave spawning, collisions, scoring, particles, input, game-over, victory)
- **4 Lambda expressions** — inline damage multipliers and selection filters
- **`Parallel For`** — concurrent projectile updates
- **`Dictionary` stats tracking** — per-tower kill/damage/DPS analytics
- **DATA/READ** — declarative wave definitions (12 waves + boss battles)
- **Software renderer** — full `_Draw()` with towers, enemies, projectiles, particles, HUD, and path rendering
- **960×640 window** — standalone playable project

Located in `demos/2D_Games/Galactic_Defender/`.

---

## ⚡ Bytecode Peephole Optimizer

A new post-compilation optimization pass (`visual_gasic_optimizer.h/.cpp`) that transforms emitted bytecode before execution:

### 9 Optimization Passes
| Pass | Description |
|------|-------------|
| **Constant Folding** | `CONST a; CONST b; ADD` → `CONST (a+b)` — folds numeric arithmetic and string concatenation at bytecode level |
| **Dead Pop** | `PUSH x; POP` → removed — eliminates useless push-immediately-pop sequences |
| **Redundant Load/Store** | `GET_LOCAL x; POP` and `GET_GLOBAL x; POP` → removed |
| **Dead Code Elimination** | Bytes after unconditional `JUMP`/`RETURN` that aren't jump targets → stripped |
| **Jump Threading** | `JUMP → JUMP → target` → `JUMP → target` — follows chains up to 10 hops |
| **Identity Operations** | `x + 0`, `x - 0`, `x * 1`, `x / 1` → eliminated |
| **Double Negation** | `NOT NOT x` and `NEGATE NEGATE x` → removed |
| **Strength Reduction** | `x * -1` → `NEGATE x` |
| **Debug Line Stripping** | `OP_DEBUG_LINE` removal for release builds |

### Architecture
- **Fixed-point iteration** — runs up to 8 passes until no transformations remain
- **NOP-based patching** with jump-offset-aware compaction
- **Zero overhead** — runs once at compilation time, no runtime cost
- **Safe** — preserves line mappings, handles all 90+ opcodes, fixes jump offsets

### Integration
The optimizer runs automatically in `VisualGasicScript::get_bytecode_for()` after successful compilation. Logs optimizations when transforms occur:
```
[VG Optimizer] Factorial: 41 → 40 bytes (1 transforms: 0 const-fold, 0 dead-pop, 1 dead-code, ...)
```

---

## 🔍 Static Analysis & Linting

New linter integrated into Godot's `_validate()` pipeline for real-time warnings:

### 6 Warning Types
| Code | Warning | Description |
|------|---------|-------------|
| 100 | `WARN_UNUSED_VARIABLE` | Variable declared but never read |
| 101 | `WARN_UNUSED_SUB` | Sub/Function defined but never called (skips builtins like `_Ready`, `_Process`, `_Draw`) |
| 102 | `WARN_EMPTY_SUB` | Sub/Function with no statements |
| 103 | `WARN_SHADOWED_VARIABLE` | Local `Dim` shadows a module-level `Dim` |
| 104 | `WARN_UNREACHABLE_CODE` | Statements after `Exit Sub`, `Return`, or `GoTo` |
| 106 | `WARN_UNUSED_PARAMETER` | Sub/Function parameter never referenced in body |

### Implementation
- **3-phase analysis**: collect definitions → collect references (full AST walk) → run checks
- **AST-aware**: traverses class methods, properties, lambdas, `Whenever` sections, `ForEach`, nested calls
- **Zero false positives** on Godot callbacks — skips `_Ready`, `_Process`, `_Draw`, `_Input`, `_PhysicsProcess`, `_EnterTree`, `_ExitTree`

---

## 🧩 Snippet Browser (Tool Menu)

New `Project > Tools > VG: Snippet Browser` dialog:

- **3-pane layout**: categories → snippet list → preview panel
- **32+ built-in snippets** from VGSnippetManager (Control Flow, Classes, Forms, Functions, etc.)
- **Search**: real-time filtering by name and description
- **Custom snippets**: add your own with `${1:placeholder}` tab-stop support
- **Insert**: double-click or button — inserts at caret position in the current `.vg` editor

---

## 🎨 Theme Picker (Tool Menu)

New `Project > Tools > VG: Theme Picker` dialog:

- **5 built-in themes**: VB6 Classic, Dark Modern, Monokai, Solarized, High Contrast
- **Live preview**: 40+ line VG code sample rendered with each theme's colors
- **Color-coded list**: each theme shows its background color in the list
- **Auto-apply**: themes automatically applied when opening `.vg` files

---

## 🧬 Class Inheritance

Full OOP inheritance support added in v2.4.0, now fully tested (22/22 tests):

```vb
Class Animal
    Public Name As String
    Public Sub Speak()
        Print Name & " makes a sound"
    End Sub
End Class

Class Dog
    Inherits Animal
    
    Public Overrides Sub Speak()
        Print Name & " barks!"
    End Sub
End Class

Dim d As New Dog
d.Name = "Rex"
d.Speak()    ' → "Rex barks!"
```

### Features
- `Inherits` keyword for single inheritance
- `MyBase.Method()` for calling parent methods
- `Overrides` keyword for method overriding
- `MustOverride` for abstract methods
- Multi-level inheritance chains (3+ levels tested)
- Property inheritance with override support

---

## 📊 Summary

| Component | Files | Lines |
|-----------|-------|-------|
| Bytecode Optimizer | `visual_gasic_optimizer.h/.cpp` | ~600 |
| Static Linter | `visual_gasic_linter.h/.cpp` | ~530 |
| Snippet Browser | `vg_snippet_browser.gd` | ~220 |
| Theme Picker | `vg_theme_picker.gd` | ~150 |
| Galactic Defender | `galactic_defender.vg` + scaffolding | ~1,700 |
| Plugin Wiring | `visual_gasic_plugin.gd` changes | ~60 |
| **Total New Code** | | **~3,260 lines** |

### Test Results
- **268/268** language test checklist (100%)
- **22/22** inheritance tests
- **0 parse errors** on Galactic Defender
- **All existing tests pass** with optimizer enabled
