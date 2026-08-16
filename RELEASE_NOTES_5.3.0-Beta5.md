# VisualGasic 5.3.0-Beta5 Release Notes

**Release Date:** August 16, 2026
**Status:** Beta (Feature Complete, Early Adopter Testing)
**Previous Release:** [5.3.0-Beta4](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.3.0-Beta4) (August 7, 2026)
**Target Engine:** Godot 4.6.1
**Platforms:** Linux x86_64, Windows x86_64 (desktop)

---

## Overview

VisualGasic 5.3.0-Beta5 is an **IDE stability and ergonomics** release. The native Godot Script editor no longer crashes when you press Enter in a `.vg` tab, Enter now behaves like VB6 (indent + `Next`/block closers), and lowercase keywords auto-correct to proper VB6 casing on both the embedded VG editor and native Script tabs. All Beta4 performance and correctness wins (81.8% faster calls, native 6502 core, miscompilation fixes) carry forward unchanged.

**Key numbers:** 856/856 regression assertions passing · 54 corpus examples passing · native Script editor segfault fixed · shared keyword auto-correct on all editor surfaces.

---

## What's New Since 5.3.0-Beta4

### 🛠 Fixed — Native Godot Script Editor Crash on `.vg` Tabs

Opening a `.vg` file in Godot's built-in Script editor and pressing **Enter** after typing a loop header (e.g. `For i = 1 To 10`) previously crashed the editor with signal 11 inside `_on_native_code_completion_requested`. Root cause: the GDScript code-completion overlay conflicted with the C++ `ScriptLanguageExtension` completion path. The overlay is now disabled on native Script tabs; completion continues to work in the dedicated VG embedded editor.

### ⌨️ Added — Native Enter / Block Closing (VB6-style)

New `vg_native_editor_indent.gd` hooks Godot's native CodeEdit on `.vg` Script tabs:

- **Enter** preserves indentation and inserts `Next` after `For` loops (with loop variable when present).
- **Enter** after `If`, `While`, `Sub`, `Function`, `Select Case`, and similar block openers inserts the matching closer stub (`End If`, `Wend`, `End Sub`, etc.) on the next line, cursor positioned inside the block.

The embedded `VGCodeEdit` already had this behavior; native tabs now match.

### ✏️ Added — VB6 Keyword Auto-Correct (Native + Embedded)

New shared module `vg_keyword_autocorrect.gd` capitalizes BASIC keywords on line leave:

- `for` → `For`, `dim` → `Dim`, `if` → `If`, `then` → `Then`, `end` → `End`, and the full VB6 keyword set.
- Applies to both the embedded VG code editor and native Godot Script tabs.

### 🔜 Coming Next (M5 — October 2026)

This beta lays groundwork while M5 work continues on the roadmap:

| Area | What's coming |
|---|---|
| **Buffer Type** | `Dim mem As Buffer` with `BufRead`/`BufWrite` fast paths — 10–100× faster than `Array(As Byte)` for emulation and I/O |
| **Optimizer Hints** | `@fast_loop`, `@accumulator`, `@simd_candidate` — user-tunable hot-path hints without waiting for compiler pattern-matching |
| **Speed improvements** | Unboxed typed operand stack redesign (target: 3–4× call overhead reduction), additional VM fast paths |
| **Narcea AI Pair** | Agent-loop reliability fixes, provider routing polish, end-to-end "describe a form → working VG code" demo |

Full timeline: [RELEASE_SCHEDULE.md](RELEASE_SCHEDULE.md) · roadmap: [ROADMAP.md](ROADMAP.md)

---

## Recap: What Shipped in 5.3.0-Beta4 (August 7, 2026)

For context, Beta4 shipped:
- **−81.8% function-call overhead** (45,785 → 8,323 instructions/call)
- Native **6502/6510 CPU core** — C64 Emulator Turbo Mode boots to `READY.` at ~2.9× real hardware speed
- Three silent miscompilation bugs fixed (`OP_JUMP_TABLE`, `CONST + VAR`, `ByRef` write-back)
- Native JIT hang fix, Narcea AI Pair agent-loop fixes

Full details in [CHANGELOG.md](CHANGELOG.md#530-beta4---2026-08-07) and [RELEASE_NOTES_5.3.0-Beta4.md](RELEASE_NOTES_5.3.0-Beta4.md).

---

## GDScript Differences

VisualGasic is a GDExtension, not a fork of GDScript — the two languages coexist in the same project and can call into each other. If you're coming from GDScript, these resources cover the practical differences:

| Resource | What it covers |
|---|---|
| [GDScript ↔ VisualGasic Quick Reference](docs/GODOT_PROGRAMMING_MANUAL.md#gdscript-vs-vg) | Side-by-side syntax tables: script structure, variable declarations, node access ($Node vs GetNode), functions/subs, signals, control flow, and more |
| [Why VisualGasic — Advantages Over GDScript](docs/guides/VG_ADVANTAGES_OVER_GDSCRIPT.md) | 19 capability categories GDScript does not have at all or only partially |
| [Competitive Advantages — Godot-Rejected Features We Ship](docs/COMPETITIVE_ADVANTAGES.md) | The strategic story behind features like exception handling and abstract classes |

**Performance:** VG's bytecode engine beats GDScript on all 11 published micro-benchmarks (30–119× on hot paths) while keeping BASIC-style readability — see [performance.md](docs/manual/performance.md) for full methodology.

---

## Known Limitations

### 🔴 AST Evaluator Missing Godot Type-Constructor Dispatch

Calling `Vector2i(...)`, `Rect2i(...)`, `Color(...)`, etc. from a Sub that has fallen back to AST interpretation throws `Sub or Function not defined` — the bytecode compiler's type-constructor table has no AST-evaluator equivalent yet. Not yet fixed; see `.github/copilot-instructions.md`.

### 🔴 Outgoing PyCall Argument Typing

VG bare numeric literals inside `Array(...)` still arrive in Python as `float`, not `int`. Workaround: `Array(CInt(0), CInt(5))`. Tracked as v6.1 Polish.

### 🟡 `Print` with `;` Separator Drops Everything After the First Item

`Print "label: "; someVar` prints only `label: ` — `someVar` is silently dropped even when it holds a real value. Workaround: use `&` string concatenation (`Print "label: " & someVar`) instead of the semicolon-separated form. Not yet root-caused.

### 🟡 C64 Emulator: Default (Non-Turbo) Boot Speed

Without Turbo Mode, the pure-VG-interpreted CPU core still runs at only ~600–9,000 cycles/sec vs. real hardware's ~985,000 — enable Turbo Mode for real-time viewing.

### 🧪 UI Forms — Experimental

The Form Designer, Properties Inspector, and Immediate Window remain **mothballed pending v6.0 stability** and are opt-in only (`vg/enable_experimental_plugins = true`).

---

## Installation

### Linux

**Option 1: AppImage (Recommended)**
```bash
wget https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.3.0-Beta5/VisualGasic-Installer-v5.3.0-Beta5-x86_64.AppImage
chmod +x VisualGasic-Installer-v5.3.0-Beta5-x86_64.AppImage
./VisualGasic-Installer-v5.3.0-Beta5-x86_64.AppImage
```

**Option 2: Bootstrap Script**
```bash
curl -sSL https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/scripts/bootstrap_install.sh | bash
```

### Windows

```powershell
Invoke-WebRequest -Uri "https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.3.0-Beta5/VisualGasic-Installer-v5.3.0-Beta5-x86_64.exe" -OutFile installer.exe
.\installer.exe
```

### Manual (any platform)

1. Extract `VisualGasic_v5.3.0-Beta5_<platform>_x86_64.zip` into your project's `addons/` folder
2. **Project → Project Settings → Plugins → VisualGasic** → Enable
3. Restart Godot

Full setup guide: [docs/getting_started/installation.md](docs/getting_started/installation.md) · [Documentation Hub](docs/DOCS.md) · [Getting Started](docs/guides/GET_STARTED.md) · [Language Reference](docs/VisualGasic_Language_Reference.md)

---
