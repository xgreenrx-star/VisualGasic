# VisualGasic v4.2.0 Beta 4 — GDScript Parity, Game UI Form Designer, Property System & Modern Language

**Release Date**: March 13, 2026  
**Platforms**: Linux x86_64, Windows x86_64, macOS Universal (x86_64 + arm64)  
**Godot**: 4.5+ (tested on 4.6.1)  
**Tag**: `v4.2.0-beta4`  
**Commits since Beta 3**: 33  
**CI**: All 3 platforms built automatically via GitHub Actions on tag push

---

## What is VisualGasic?

**VisualGasic** is a modern, event-driven programming language for the Godot Engine inspired by Visual Basic 6's legendary approachability. It features the Visual Gasic IDE with a full WYSIWYG form designer, JIT compiler, auto event wiring, and 220+ demo projects.

---

> ## ⚠️ BETA — READ THIS FIRST
>
> This is a **beta release** with a massive feature payload — 8 version jumps
> (v3.5.0-beta4 → v4.2.0) encompassing the Game UI Form Designer, a full
> property system overhaul, and GDScript parity features.
>
> The core language, compiler, JIT, and Form Designer are stable. The test suite
> passes **609 of 611 assertions** (99.7%) — the 2 failures are environment-only
> (`test_file_permissions.vg` symlink tests on certain Linux configurations).
>
> **This is not production-ready software.** Please use it to experiment, learn,
> build prototypes, and help us find bugs.

---

## What's New Since Beta 3

Beta 4 is the largest beta release yet — **33 commits** covering 8 internal
version milestones. Here's everything that shipped:

---

### 🎮 v4.0.0 — Game UI Form Designer (Tier 1 Animated Controls)

Seven fully animated, game-ready UI controls with built-in Tween animations,
complete Properties panel integration, and design-time preview:

| Control | Description |
|---------|-------------|
| **DialogPanel** | Animated dialog box with portrait, speaker name, typewriter text, and branching choices |
| **InventoryGrid** | N×M slot grid with per-slot textures, selection, hover highlight, and click/double-click events |
| **StatBar** | Animated HP/MP/XP bar with damage trail, value flash, and label formatting (`{value} / {max}`) |
| **HUDCounter** | Animated score/gold/ammo counter with counting animation and punch-scale effect |
| **CooldownButton** | Texture button with radial cooldown overlay sweep and countdown text |
| **NotificationToast** | Slide-in/out notification messages with auto-dismiss timer and icon support |
| **GameMenu** | Full-screen pause/settings overlay with dim background and configurable button list |

**Architecture:**
- Each control is a dedicated `.tscn` prototype + `.gd` backing script in `prototypes/game_ui/`
- All controls support `ShowAnimation`, `HideAnimation`, `TransitionSpeed` properties
- Registered in the **Game UI** toolbox tab with proper icons and default sizes
- Legacy alias controls preserved for backward compatibility

---

### 🎨 v4.1.0 — Property System Overhaul

Complete rewrite of the form designer's property pipeline — from design-time
live preview through runtime serialization and round-trip parsing:

- **70+ VB6→Godot runtime property translations** — 62 simple 1:1 mappings plus context-dependent (`Value`), composite (`PasswordChar`, `Opacity`, `ScaleX`/`ScaleY`), and metadata (`Tag`) translations
- **Font sub-resources** — `FontName`, `FontBold`, `FontItalic` serialize as per-control `SystemFont` sub-resources
- **BackColor sub-resources** — `BackColor` serializes as per-control `StyleBoxFlat` with `bg_color`
- **ForeColor support** — `theme_override_colors/font_color` for text controls
- **ShapeColor support** — Direct `color` property for ColorRect controls
- **BorderStyle support** — `0` (None) = no border, `1` (Fixed Single) = 1px dark border
- **Complete live preview** — Rewrote `_sync_live_preview_properties()` (~500 lines) for all control types
- **Full round-trip parser** — 60+ reverse Godot→VB6 translations in `_parse_tscn()` for save→load→save fidelity

---

### 🚀 v4.2.0 — GDScript Parity (Export, Await, Import, ClassName, $NodeName)

Closes the four biggest feature gaps between VisualGasic and GDScript:

#### `Export` — Inspector Integration
```vb
Export Dim speed As Single = 5.0
Export Public maxHealth As Integer = 100
```
Marks module-level variables for the Godot Inspector panel. Supports `Color`, `Vector2`, `Vector3`, `NodePath`, `Float`, and more.

#### `Await` — Coroutine Support
```vb
Await $AnimationPlayer.animation_finished
Await 2.5   ' Wait 2.5 seconds
```
Real signal/timer suspend with `OP_AWAIT` bytecode, coroutine state save/restore, and synchronous fallback.

#### `Import` — Cross-File Module System
```vb
Import "helpers/math_utils.vg"
Import GameConfig
```
Parser stores imports in `ModuleNode::imports`. Instance constructor loads, parses, and registers Public symbols in `module_registry`.

#### `ClassName` + `$NodeName` Shorthand
```vb
ClassName PlayerController
Dim sprite = $AnimatedSprite2D
Dim ui = $%HealthBar   ' unique name
```

---

### 🔧 v3.5.0-beta4 — Desktop Readiness (Items 5–8)

- **`RaiseEvent` bytecode** — `OP_RAISE_EVENT` opcode with full compiler/VM/optimizer/JIT support
- **`WithEvents` keyword** — Auto-wires event handler subs when a WithEvents variable is assigned
- **`Implements` verification** — Runtime warning if interface methods are missing
- **`Printer` built-in object** — Full VB6 Printer API surface (Print, EndDoc, NewPage, Circle, Line, etc.)
- **`PrintForm` statement** — Captures viewport to `user://PrintForm_<timestamp>.png`

---

### 🚀 v3.6.0 — Modern Language Features

- **Compound assignment** — `+=`, `-=`, `*=`, `/=`, `&=`, `\=`, `^=`, `<<=`, `>>=`
- **Bit-shift operators** — `<<` and `>>` with VB.NET-compatible precedence
- **`LongLong` type** — 64-bit integer alias with `CLngLng()` conversion

---

### 🚀 v3.7.0 — OOP Power-Up

- **Method overloading** — Multiple signatures with arity-based dispatch
- **Parameterized constructors** — `New Bullet(speed, angle, damage)`
- **Generics Phase 1** — `Collection(Of T)` with runtime type validation
- **Game UI Mode** — `CanvasLayer` root with crosshair guides and 11 game UI toolbox controls

---

### 🚀 v3.8.0 — Enhanced Enums & Compound Logical Operators

- **Keyword compound operators** — `And=`, `Or=`, `Xor=`, `Mod=`
- **Bitwise semantics** — `And`/`Or`/`Xor` now bitwise-when-numeric (VB6 semantics)
- **`<Flags>` enum attribute** — Bitfield enums with `HasFlag()` and flags-aware `ToString()`
- **Compile-time enum dot access** — `MyEnum.Member` resolved at compile time

---

### 📖 Documentation — "Why VisualGasic"

New comprehensive documentation explaining the 19 capabilities VisualGasic has that GDScript does not:

- **`docs/guides/VG_ADVANTAGES_OVER_GDSCRIPT.md`** — ~900-line standalone guide with code examples, benchmarks, and comparison tables
- **Chapter 39** added to the Godot Programming Manual — "Why VisualGasic — Advantages Over GDScript"
- **Documentation Index** updated with ⭐ "Why VisualGasic?" quick link at the top

---

## Test Suite

```
Files tested:   69
Assertions:     611
Passed:         609   (99.7%)
Failed:         2     (environment-only — symlink tests)
```

The 2 failures are in `test_file_permissions.vg` and relate to symlink handling
on certain Linux configurations. All language, compiler, bytecode, JIT, OOP,
and Form Designer tests pass.

---

## Known Issues (7 Open)

| # | Issue | Severity | Workaround |
|---|-------|----------|------------|
| 4 | `On Error GoTo` partial in bytecode VM | ⚠️ Partial | AST interpreter mode works correctly |
| 6 | Dictionary `.Count` property in bytecode | Medium | Use `.Count()` with parentheses |
| 7 | Dictionary `Keys()` indexing | Medium | Use `For Each k In d.Keys()` |
| 8 | `ToByteArray()` returns Godot type | Medium | Use `PeekByte`/`PokeByte` |
| 10 | Task scope cloning (by design) | Medium | Read results via `task.Result` |
| 11 | Thread + scene-tree crash | Medium | Don't call scene-tree API from workers |
| 16 | `"Task"` reserved word conflict | Low | Use `TaskObj` or `MyTask` as variable name |

---

## Cumulative Statistics Since Beta 1

| Metric | Beta 1 | Beta 4 |
|--------|--------|--------|
| Test files | 48 | 69 |
| Assertions | ~400 | 611 |
| Pass rate | ~98% | 99.7% |
| Language features | ~120 | 180+ |
| Form Designer controls | 25 | 50+ |
| VB6 property translations | 0 | 70+ |
| Game UI controls | 0 | 7 animated + 16 basic |
| Commits | — | 161 since beta 1, 33 since beta 3 |

---

## Upgrade Notes

1. **No breaking changes** — All existing `.vg` scripts continue to work
2. **New keywords** — `Export`, `Await`, `Import`, `ClassName` are now reserved. Rename any variables using these names
3. **`$NodeName` syntax** — The `$` prefix is now a node-path shorthand. If you used `$` for other purposes in string literals, no change is needed (only affects bare `$Identifier`)
4. **Form Designer** — Existing `.tscn` forms will gain access to the new property pipeline. Re-save forms in the Visual Gasic IDE to get Font/BackColor sub-resources

---

## Installation

1. Download the release ZIP for your platform
2. Extract `addons/visual_gasic/` into your Godot project
3. Enable the plugin: **Project → Project Settings → Plugins → VisualGasic → Enable**
4. Click the **Visual Gasic IDE** button in the toolbar

See the [Calculator Tutorial](docs/tutorials/calculator_form_designer.md) for a complete beginner walkthrough.

---

## What's Next

See the [v4.0 Roadmap](ROADMAP.md#-v40-roadmap--next-generation) for planned features:

- 🔴 **Live Animation** for custom controls in the Form Designer
- 🔴 **Multi-Module Project Compilation** with cross-file symbol resolution
- 🔴 **Visual Form Debugger** — click running controls to inspect live values
- 🟡 **Database Controls** (Data, DBGrid, DBCombo) with SQLite
- 🟡 **Package Manager** — `vg install <package>`
- 🟡 **Migration Wizard v2** — full `.vbp` project import

---

*Thank you to everyone testing the betas and filing issues. Your feedback shapes VisualGasic.*
