# VisualGasic 5.3.0-Beta4 Release Notes

**Release Date:** August 7, 2026
**Status:** Beta (Feature Complete, Early Adopter Testing)
**Previous Release:** [5.3.0-Beta3](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.3.0-Beta3) (July 31, 2026)
**Target Engine:** Godot 4.6.1
**Platforms:** Linux x86_64, Windows x86_64 (desktop)

---

## Overview

VisualGasic 5.3.0-Beta4 is a deep performance-and-correctness release. A dedicated call-performance campaign cut real interpreter function-call overhead by **81.8%** (5.50× faster), a from-scratch **native C++ 6502/6510 CPU core** now lets the Commodore 64 Emulator boot to `READY.` at ~2.9× real hardware speed as an opt-in Turbo Mode, and three separate silent-miscompilation bugs — an `OP_JUMP_TABLE` sizing bug, a `CONST + VAR` arithmetic codegen bug, and a `ByRef`-write-back-vs-shadowed-builtin bug — were root-caused and fixed. The native x86-64 JIT's long-standing "hangs on any real function" bug is also fixed. This release stays within Milestone **M1–M5** scope (M5 Narcea AI pair groundwork continues).

**Key numbers:** 856/856 regression assertions passing (110 files, up from 777/98) · 54 corpus examples passing (unchanged) · function-call overhead cut 81.8% (45,785 → 8,323 instructions/call) · new native 6502 CPU core.

---

## What's New Since 5.3.0-Beta3

### 🚀 Performance — Call-Overhead Campaign: −81.8%, 5.50× Faster Calls

A ~29-commit incremental campaign (Parts H through AG) measured and cut real per-call interpreter overhead from a legacy baseline of 45,785 instructions/call down to **8,323 instructions/call** — a cumulative **81.8% reduction**. Every step was validated with `perf stat -e instructions:u` two-point isolation (1M/100k calls, core-pinned) and the full 855-assertion suite (both default and `VG_JIT=2` paths) before committing. Highlights:

- Engaged the previously dead `fast_params` scalar-ByVal/return fast path (a latent parser bug had silently made it a no-op since it shipped) — 22.4% alone.
- Per-call-site `OP_CALL` resolution memoization, threaded callee resolution, precomputed arg-coercion codes, and a per-thread reusable locals-frame pool that eliminated the **last per-call heap allocation** in the hot path entirely.
- Typed shadow locals moved to raw `std::vector`/stack-SBO storage, raw bytecode pointer access, and a single-copy `OP_GET_LOCAL` fast path.

Full ledger of all 29 measured steps: `/memories/repo/vg_bytecode_perf.md`. The gap to GDScript's own call overhead (~1,338 instr/call) narrowed from 34× to **6.22×** — closing the remaining gap is architectural (Variant-boxed locals/stack) and is tracked as future work, not attempted this cycle.

### 🎮 New: Native VGCpu6502 Engine Primitive — C64 Emulator Boots to READY at ~2.9× Real Hardware Speed

`demos/C64_Emulator/` gains an opt-in **Turbo Mode**: a fully-native, reentrant C++ 6502/6510 CPU core (`VGC64Machine`) that replaces the VG-interpreted CPU-stepping loop for users who want real-time speed. With it enabled, the emulator boots the real, unmodified KERNAL/BASIC ROMs all the way to `**** COMMODORE 64 BASIC V2 ****` / `READY.` at roughly **2.9× real PAL hardware speed** — a dramatic jump from the VG-interpreted path's ~600–9,000 cycles/sec ceiling (see the perf notes above and in `vg_bytecode_perf.md` for the full interpreter-bound analysis that motivated this). Turbo Mode is opt-in; the pure-VG interpreted CPU core remains the default so the emulator continues to serve as a demonstration/stress-test of the language itself.

### 🐛 Fixed — Three Silent Miscompilation Bugs

- **`OP_JUMP_TABLE` sized by case count instead of value range** — `Select Case` compiled to an O(1) jump table (used by the C64 emulator's 151-opcode dispatch) was sized by the number of distinct `Case` values (~170) but the VM indexes it by the full value range (~255), so every opcode ≥170 (`BNE`, `BEQ`, `INX`, `CMP`, `SBC`, and ~80 more) silently fell through to `Case Else` — a 2-cycle no-op. This is why the C64 emulator could never execute branches/compares and never booted. One-line fix: size the table by `range`, not `case_count`.
- **`CONST + VAR` / `CONST * VAR` silently computed `CONST + CONST`** — a binary `+`/`*` whose LEFT operand is a literal and RIGHT operand is a variable/expression (e.g. `1024 + (srow * 40)`, `64 + c`) evaluated as if both sides were the same constant, because the `_CONST`-suffixed fast-path opcodes assume the literal is always the LAST value pushed. Removed the incorrect left-literal fallback in all 4 codegen sites; `CONST + VAR`/`CONST * VAR` are now safe in either operand order with no workaround needed.
- **`ByRef` write-back corrupted the caller's variable when a builtin is shadowed by a same-named user Sub** — if a project defines its own `Function FileExists(...)` (or any other name matching a VG builtin), the compiler's write-back resolution assumed the user function ran, but builtins always win at runtime dispatch — so the write-back opcode pushed `Nil` and silently nulled the caller's argument. Redesigned `OP_BYREF_LOAD`'s bytecode format so a missing capture re-reads the destination's own current value (a true no-op) instead of writing `Nil`, which self-corrects for any future compile-time-vs-runtime callee mismatch, not just this one case.

### 🛠 Fixed — Native JIT No Longer Hangs

The opt-in native x86-64 JIT (`VG_JIT=2`/`VG_JIT=3`, off by default) previously hung the process on any non-trivial function. Root cause: two JIT early-return paths skipped `restore_vm()`, leaving the shared VM instruction pointer at 0 after a JIT'd callee returned — the caller's interpreter loop then read `vm.ip=0` and restarted from the top forever. Fixed with one `restore_vm()` call added to each JIT return path. Also added Tier2 IR coverage for bitwise/shift ops (`AND`/`OR`/`XOR`/`SHL`/`SHR`) and trap-safe `MOD`/`INT_DIVIDE`-by-constant-divisor. Full suite now passes under both the default interpreter and `VG_JIT=2`. Still opt-in and not recommended for production — coverage remains a narrow numeric/control-flow subset.

### ⚡ Performance — C64-Specific VM Caching (Parts A–F, +47% cumulative)

Ahead of the general call-overhead campaign, a focused round of VM-level caching specifically targeted the C64 emulator's hot paths: gating the `OP_CALL` special-case cascade and engine-call dispatch behind `HashSet` lookups, and memoizing the `OP_GET_GLOBAL` special-identifier test per bytecode constant. Measured **+47% cumulative** C64 throughput (~120.5k → 177k emulated cycles/20s) via interleaved, core-pinned A/B testing — general wins that benefit any VG program making calls or reading module-level variables, not just this one demo.

### 🤖 Fixed — Narcea AI Pair Agent-Loop Bugs

Fixed a `write_file` class-wrapper over-stripping bug and an agent-loop stall/nudge bug found via a new headless evaluation harness (`ai_projects/NarceaTrainingGround/`) that drives the real production AI panel end-to-end against DeepSeek. The harness itself surfaced a re-entrancy bug in the agent's response-continuation logic that was silently dropping mid-task context on every multi-hop turn — now fixed.

### 🎮 Demo — C64 Emulator Cartridge Loading via Clipboard-Paste

`demos/C64_Emulator/` now supports loading a `.crt`/`.bin` cartridge at runtime by pasting its file path (real OS drag-and-drop was found unreliable in this dev environment; paste is now the documented primary method, alongside auto-load and drag-and-drop).

### 🛠 Fixed — Miscellaneous

- Fixed a local variable used ONLY as an array/buffer index inside another statement's assignment target being silently dead-store-eliminated, corrupting indexed writes with a stale/zero offset.
- Fixed a C64 emulator save-all corruption bug and a `&H` hex-literal formatter bug.
- Added `OP_GET_GLOBAL_BUF8`/`OP_SET_GLOBAL_BUF8` fast-path opcodes for indexed access to global/Public `MemoryBuffer` variables.
- Audited the engineering "Tier Master Plan": replaced an O(n²) `Sort` with a native implementation and added `StringFormat`.
- Added a permanent `FunctionCall`/`BenchCall` micro-benchmark to the canonical suite plus a new benchmark report with live 3-way GDScript/VG/C++ comparisons.
- New GitHub Sponsors funding configuration and a refreshed 1280×720 project icon for Asset Library submission.

---

## Recap: What Shipped in 5.3.0-Beta3 (July 31, 2026)

For context, Beta3 shipped:
- Two brand-new full hardware emulator demos — a **Commodore 64** and a **Game Boy Advance** — that surfaced a dense cluster of real interpreter bugs
- Cross-module bytecode compilation for imported Subs
- The `MemoryBuffer` buffer type, 3 new optimizer-hint opcodes, a `Global` keyword, cross-file class `Import`, and `Exit While`
- A measured ~21–40% reduction in call/hot-path overhead (the campaign this release builds on and dramatically extends)
- The DeepSeek AI provider for Narcea AI Pair

Full details in [CHANGELOG.md](CHANGELOG.md#530-beta3---2026-07-31).

---

## GDScript Differences

VisualGasic is a GDExtension, not a fork of GDScript — the two languages coexist in the same project and can call into each other. If you're coming from GDScript, these resources cover the practical differences:

| Resource | What it covers |
|---|---|
| [GDScript ↔ VisualGasic Quick Reference](docs/GODOT_PROGRAMMING_MANUAL.md#gdscript-vs-vg) | Side-by-side syntax tables: script structure, variable declarations, node access ($Node vs GetNode), functions/subs, signals, control flow, and more |
| [Why VisualGasic — Advantages Over GDScript](docs/guides/VG_ADVANTAGES_OVER_GDSCRIPT.md) | 19 capability categories GDScript does not have at all or only partially |
| [Competitive Advantages — Godot-Rejected Features We Ship](docs/COMPETITIVE_ADVANTAGES.md) | The strategic story behind features like exception handling and abstract classes |

**Performance:** VG's bytecode engine beats GDScript on all 11 published micro-benchmarks (30–119× on hot paths) while keeping BASIC-style readability — see [performance.md](docs/manual/performance.md) for full methodology. Pure function-call overhead — VG's one historically weak spot — is now 6.22× GDScript's after this release's campaign (was 458× at the start of the campaign, then 34×, now 6.22×); full ledger in `/memories/repo/vg_bytecode_perf.md`.

---

## Known Limitations

### 🔴 AST Evaluator Missing Godot Type-Constructor Dispatch

Calling `Vector2i(...)`, `Rect2i(...)`, `Color(...)`, etc. from a Sub that has fallen back to AST interpretation throws `Sub or Function not defined` — the bytecode compiler's type-constructor table has no AST-evaluator equivalent yet. Not yet fixed; see `.github/copilot-instructions.md`.

### 🔴 Outgoing PyCall Argument Typing

VG bare numeric literals inside `Array(...)` still arrive in Python as `float`, not `int`. Workaround: `Array(CInt(0), CInt(5))`. Tracked as v6.1 Polish.

### 🟡 `Print` with `;` Separator Drops Everything After the First Item

`Print "label: "; someVar` prints only `label: ` — `someVar` is silently dropped even when it holds a real value. Workaround: use `&` string concatenation (`Print "label: " & someVar`) instead of the semicolon-separated form. Not yet root-caused.

### 🟡 C64 Emulator: Default (Non-Turbo) Boot Speed

Without the new native Turbo Mode, the pure-VG-interpreted CPU core still runs at only ~600–9,000 cycles/sec vs. real hardware's ~985,000 — clearing the KERNAL RAM test at boot remains slow. This is expected/architectural (see `vg_bytecode_perf.md`) — enable Turbo Mode for real-time viewing.

### 🧪 UI Forms — Experimental

The Form Designer, Properties Inspector, and Immediate Window remain **mothballed pending v6.0 stability** and are opt-in only (`vg/enable_experimental_plugins = true`).

---

## Installation

### Linux

**Option 1: AppImage (Recommended)**
```bash
wget https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.3.0-Beta4/VisualGasic-Installer-v5.3.0-Beta4-x86_64.AppImage
chmod +x VisualGasic-Installer-v5.3.0-Beta4-x86_64.AppImage
./VisualGasic-Installer-v5.3.0-Beta4-x86_64.AppImage
```

**Option 2: Bootstrap Script**
```bash
curl -sSL https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/scripts/bootstrap_install.sh | bash
```

### Windows

```powershell
Invoke-WebRequest -Uri "https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.3.0-Beta4/VisualGasic-Installer-v5.3.0-Beta4-x86_64.exe" -OutFile installer.exe
.\installer.exe
```

### Manual (any platform)

1. Extract `VisualGasic_v5.3.0-Beta4_<platform>_x86_64.zip` into your project's `addons/` folder
2. **Project → Project Settings → Plugins → VisualGasic** → Enable
3. Restart Godot

Full setup guide: [docs/getting_started/installation.md](docs/getting_started/installation.md)

---
