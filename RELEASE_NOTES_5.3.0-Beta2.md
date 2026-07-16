# VisualGasic 5.3.0-Beta2 Release Notes

**Release Date:** July 15, 2026
**Status:** Beta (Feature Complete, Early Adopter Testing)
**Previous Release:** [5.3.0-Beta1](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.3.0-Beta1) (July 3, 2026)
**Target Engine:** Godot 4.6.1
**Platforms:** Linux x86_64, Windows x86_64 (desktop)

---

## Overview

VisualGasic 5.3.0-Beta2 builds on Beta1's 2D toolbar and plugin opt-in work with a **critical Python bridge fix**, the `IsNot` operator, a ByRef write-back bug fix, expanded AI provider support, and new Python/FFI interop demos. This release closes out Milestones **M1–M4** (language stability + Code Navigator + experimental UI Forms).

**Key numbers:** 763/763 regression assertions passing · 44/44 corpus examples passing · 6/6 new Python bridge decode tests passing · 0 known critical bugs.

---

## What's New Since 5.3.0-Beta1

### 🔧 Critical Fix — Python Bridge Int/Float Decode Bug (Jul 15)

**The problem:** The Python worker process returns correct Python integers (e.g. `math.floor(5.7)` → `5`), but Godot's built-in `JSON::parse_string()` silently collapses **every** JSON number to `float` — there is no int branch in Godot's JSON tokenizer at all. This destroyed every Python `int` (numpy int arrays, `range()`, `random.randint`, dict counts) the moment it crossed back into VG.

**The fix:** A new self-contained recursive-descent JSON decoder, [`src/python_bridge/vg_json_typed.h/.cpp`](src/python_bridge/vg_json_typed.h), that mirrors Python's own `json.loads()` semantics — a numeric token with no `.`/`e`/`E` decodes to `int64`, otherwise to `double`. Wired into both real decode call sites in the facade (`send_request_binary()` and `py_call_many()`). Validates int64 bounds textually against `INT64_MAX`/`MIN` and falls back to float with a warning on overflow. Rejects JSON nesting deeper than 64 levels.

```vg
result = PyCall(math, "floor", Array(5.7))
' Before: result = 5.0  (Double) — wrong
' After:  result = 5    (Integer) — correct
```

**Verified via** [`demo/test_python_int_float.vg`](demo/test_python_int_float.vg): scalar int, negative int, float regression, and nested dict/array with mixed types — all 6 assertions pass.

**Known limitation (documented, not fixed this release):** the *outgoing* direction still has a separate bug — VG bare numeric literals inside `Array(...)` sent as PyCall arguments arrive in Python as `float`, not `int` (e.g. `PyCall(builtins, "range", Array(0, 5))` fails with `TypeError`). Root cause is VG's own literal tokenizer defaulting untyped numbers to `Double`. Tracked as a **v6.1 Polish** candidate — see [ROADMAP.md](ROADMAP.md#numpy-support--phased-plan-within-m7-scope). Workaround: `CInt(0)` to force integer typing on literals passed to `Array()`.

### ✨ Added — `IsNot` Operator (Jul 15)

Full VB.NET-style negated reference/type comparison, implemented end-to-end:
- Parser: `parse_comparison()` builds a `BinaryOpNode` with `op = "IsNot"`
- Bytecode compiler: class type-check via `OP_IS_CLASS` + `OP_NOT`; general case via `OP_NOT_EQUAL`; constant-folding supported
- Both evaluator paths (tree-walk and `VisualGasicExpressionEvaluator`) handle class type-check negation, `Is Not Nothing`, string class-name resolution, and reference-inequality fallback

```vg
If obj IsNot Nothing Then
    obj.DoSomething()
End If
```

Documented in the [Programmer's Reference](docs/VisualGasic_Language_Reference.md). Verified via `test_isnot_operator.vg` / `test_isnot_simple.vg` / `test_isnot_simple2.vg` (7/7 assertions).

### 🐛 Fixed — ByRef Write-Back in Expression-Level Function Calls (Jul 15)

Distinct from the June 29 ByRef-recursion fix. When a `ByRef` function was called as part of an expression (`result = DoubleAndReturn(val)`) rather than as a standalone `Call` statement, the caller's variable was never updated — `call_internal()` erases the callee's parameter slots after the call and stashes the real post-call value in `_last_byref_captures`, but the expression-evaluator write-back path was still reading the already-erased slot directly. Now matches the working `STMT_CALL` path. **763/763 assertions pass** (was 762/763 before this fix).

### 🤖 Added — Codeium (Windsurf) and Amazon Q Developer AI Providers (Jul 13)

Two new AI backends for the Narcea AI Pair / AI Help panel, alongside the existing Ollama, OpenAI, Claude, and Gemini providers. Configure API keys in **EditorSettings → visual_gasic/ai/***.

### 🐍 Added — Python Bridge and C++ FFI Demos (Jul 13)

- [`demos/Utilities/PythonBridge/demo_python_bridge.vg`](demos/Utilities/PythonBridge/demo_python_bridge.vg) — `PyImport`, `PyCall`, JSON serialization round-trip
- [`demos/Utilities/FFI/demo_ffi_cpp_lib.vg`](demos/Utilities/FFI/demo_ffi_cpp_lib.vg) — calling a custom C++ shared library (Vec2 math class) via C ABI wrappers: create/destroy, get/set, length, dot product, scale, add, normalize, string representation. All 7 test sections pass on Linux.
- Documentation: [`docs/SYSTEM_INTEGRATION.md`](docs/SYSTEM_INTEGRATION.md) §1, [`docs/VisualGasic_Language_Reference.md`](docs/VisualGasic_Language_Reference.md)

### 🎨 Added — Narcea AI Pair Floating Window (Jul 5, M5 early progress)

Narcea AI Pair is now a floating window (same pattern as the VG Toolbox/Properties windows):
- Opens via the 🤖 **Narcea AI** button next to the Visual Gasic IDE tab, `Ctrl+Shift+N`, or **Project → Tools** menu
- Window position/size persisted across sessions, with a **Reset Size & Position** button
- Resize handle supports both grow and shrink
- AI API keys migrated to `EditorSettings` (`visual_gasic/ai/*`) — single source of truth, no duplicate storage

### 🎮 Added — Thrust Tribute Demo

A new VG tribute demo to the 1986 classic *Thrust*: splash screen, BBC Micro–style scanline rock texture, solid rock cave fill, WASD controls, 3-level progression, tether physics, and a redesigned HUD. Demonstrates `_Draw`-based procedural rendering, physics, and multi-level state management in a real game.

### 📚 Documentation Overhaul

Substantial reference-documentation cleanup and expansion:
- Fixed internal anchor links across the Language Reference
- Reformatted the alphabetical command index to legacy-style linked lines
- Added a legacy-coverage appendix scoped to 6.0 features
- Removed the mothballed VG IDE chapter from the Language Reference and added a proper table of contents
- Moved the VB6 importer manual to community plugin docs (VB6 Importer is a separate, community-maintained plugin — see [ROADMAP.md](ROADMAP.md))
- Clarified planned Windows support in platform badges
- Added platform support notes to the A-Z command reference
- Documented the Godot 4.5 → 4.6 API compatibility migration

### 🌐 Website & Community

- Added a benchmark bar chart and updated the README results table
- Added C# to the AI-correctness benchmark suite (alongside existing language checks)
- Added a code-comparison example to the website's Auditing section
- Added GitHub Sponsors link and sponsor section
- Added funding materials and Copilot support documentation

### 🛠 Fixed — Miscellaneous

- Removed a call to a nonexistent `PopupMenu.move_item`; fixed a `Controller.gd` self-reference cascade
- Fixed VGasic Tools missing from the Project menu; fixed VB6 FRX image decode; fixed new-project binary copy; fixed GDAI provider return types
- Boolean `Or` regression marked fixed in the roadmap
- Removed an orphaned temporary AST header and unused `VGTheme` preloads

---

## Recap: What Shipped in 5.3.0-Beta1 (July 3, 2026)

For context, Beta1 shipped:
- **2D Canvas Toolbar** — Add VG Control, VG Properties, Wire Event buttons (+ right-click context menu)
- **Plugin opt-in via Project Settings** — VG sub-plugins disabled by default, enabled per-project with live reload
- **Compact Plugins dropdown** — single "Plugins ▾" menu button replacing per-plugin toolbar buttons
- **Native Script Editor code completion** — VB6-aware dot-completion (`TextBox1.` shows Text/Enabled/MaxLength/etc.), `Me.` completion, control names and `Dim` variables in regular completions
- **Code Navigator upgrade** — Object/Procedure dropdowns matching VB6 behavior
- Six bug fixes: `dict.Count`/`Keys`/`Items` without parens, `arr.Count`/`Length` without parens, `Join()` integer formatting, ByRef default parameters in recursion, dead code removal, Godot 4.6 signal API fixes

Full details in [CHANGELOG.md](CHANGELOG.md#530-beta1---2026-07-03).

---

## GDScript Differences

VisualGasic is a GDExtension, not a fork of GDScript — the two languages coexist in the same project and can call into each other. If you're coming from GDScript, these resources cover the practical differences:

| Resource | What it covers |
|---|---|
| [GDScript ↔ VisualGasic Quick Reference](docs/GODOT_PROGRAMMING_MANUAL.md#gdscript-vs-vg) | Side-by-side syntax tables: script structure, variable declarations, node access ($Node vs GetNode), functions/subs, signals, control flow, and more |
| [Why VisualGasic — Advantages Over GDScript](docs/guides/VG_ADVANTAGES_OVER_GDSCRIPT.md) | 19 capability categories GDScript does not have at all or only partially: Visual Form Designer, JIT compilation, GPU/SIMD compute, real OS threading, ECS, package manager, COM-style objects, reactive `Whenever` blocks, null-safety (`?.`), string interpolation, VB6 migration tooling |
| [Competitive Advantages — Godot-Rejected Features We Ship](docs/COMPETITIVE_ADVANTAGES.md) | The strategic story behind why Godot core resists features like exception handling and abstract classes, and how VG ships them safely |

**Quick taste — the same `_Ready` in both languages:**

```gdscript
# GDScript
func _ready() -> void:
    print("Ready!")

func take_damage(amount: int) -> void:
    health -= amount
```

```vb
' VisualGasic
Sub _Ready()
    Print "Ready!"
End Sub

Sub TakeDamage(amount As Integer)
    health = health - amount
End Sub
```

**Performance:** VG's bytecode/JIT engine beats GDScript on all 11 published micro-benchmarks (30–119× on hot paths) while keeping BASIC-style readability — see [performance.md](docs/manual/performance.md) for full methodology.

---

## Known Limitations

### 🔴 Outgoing PyCall Argument Typing

See "Critical Fix — Python Bridge" above. Workaround: `Array(CInt(0), CInt(5))` instead of `Array(0, 5)` when the receiving Python function requires actual `int` arguments (e.g. `range()`, `numpy.zeros()`, `numpy.eye()`).

### 🧪 UI Forms — Experimental

The Form Designer, Properties Inspector, and Immediate Window remain **mothballed pending v6.0 stability** and are opt-in only (`vg/enable_experimental_plugins = true`). Feedback welcome, but not recommended for production forms yet.

---

## Installation

### Linux

```bash
wget https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.3.0-Beta2/install.sh
chmod +x install.sh
./install.sh
```

### Windows

```powershell
Invoke-WebRequest -Uri "https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.3.0-Beta2/VisualGasic-Installer-v5.3.0-Beta2-x86_64.exe" -OutFile installer.exe
.\installer.exe
```

### Manual (any platform)

1. Extract `VisualGasic_v5.3.0-Beta2_<platform>_x86_64.zip` into your project's `addons/` folder
2. **Project → Project Settings → Plugins → VisualGasic** → Enable
3. Restart Godot

Full setup guide: [docs/getting_started/installation.md](docs/getting_started/installation.md)

---

## Documentation

- [Complete Language Reference](docs/VisualGasic_Language_Reference.md) — 7000+ lines, full syntax + Godot namespace wrappers
- [Documentation Index](docs/DOCUMENTATION_INDEX.md) — full map of every manual
- [Godot Programming Manual](docs/GODOT_PROGRAMMING_MANUAL.md) — includes GDScript quick reference and case studies
- [System Integration Reference](docs/SYSTEM_INTEGRATION.md) — FFI, ODBC, Crypto, XML, ZIP, Async, Packages, Python bridge
- [IDE Tools Guide](docs/manual/ide_tools.md) — Watch Window, Debugging, Profiler, Controls, Packages, AI Help panels
- [Migration Guide (from VB6/VBA)](docs/guides/MIGRATION_GUIDE.md)
- [Release Schedule](RELEASE_SCHEDULE.md) — upcoming 5.4-beta (Oct 15), 6.0 stable (Jan 1, 2027)

---

## Testing & Stability

| Test | Result |
|---|---|
| Regression suite | 763/763 assertions ✅ |
| Corpus examples | 44/44 ✅ |
| Python bridge decode tests | 6/6 ✅ |
| Platform validation | Linux x86_64, Windows x86_64 ✅ |

```bash
./run_test_suite.sh   # expect: === ALL TESTS PASSED === (763/763)
```

---

## What's Next

| Release | Target | Scope |
|---|---|---|
| **5.4-beta** | Oct 15, 2026 | M5: Narcea AI pair (full), async queue, structured error handling |
| **6.0-rc1** | Dec 1, 2026 | M6–M8: Causal Chain (text mode), Python bridge Phase 1 (typed binary protocol), Try/Catch/Lambda/AndAlso/OrElse parity, C++ FFI, `Let` keyword |
| **6.0-rc2** | Dec 15, 2026 | M9: Release readiness, Asset Library submission |
| **6.0 stable** | Jan 1, 2027 | 🎉 Production release |

Full timeline: [RELEASE_SCHEDULE.md](RELEASE_SCHEDULE.md)

---

## Support & Feedback

- **Report bugs:** [GitHub Issues](https://github.com/xgreenrx-star/VisualGasic/issues)
- **Discuss:** [GitHub Discussions](https://github.com/xgreenrx-star/VisualGasic/discussions)

Thanks to beta testers for feedback on M1–M4, and to DeepSeek for the initial int/float decoder draft (completed and wired in by the core team this release).

---

## License

[MIT License](LICENSE)

---

**Thanks for trying VisualGasic 5.3.0-Beta2! 🎉**
