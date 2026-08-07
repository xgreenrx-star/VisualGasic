# GitHub Release Template (v5.3.0-Beta4)

## Release Title
**VisualGasic v5.3.0-Beta4 — 81.8% Faster Calls, Native 6502 Core, 3 Miscompilation Bugs Fixed**

## Tag
`v5.3.0-Beta4`

## Release Body (copy everything below into the GitHub Release description)

---

🎉 **VisualGasic 5.3.0-Beta4** is a deep performance-and-correctness release: an ~29-commit call-performance campaign cuts real function-call overhead by **81.8%** (5.50× faster), a new native C++ 6502/6510 CPU core lets the Commodore 64 Emulator boot to `READY.` at ~2.9× real hardware speed, and three separate silent-miscompilation bugs (`OP_JUMP_TABLE` sizing, `CONST + VAR` arithmetic, `ByRef`-vs-shadowed-builtin) are root-caused and fixed. The native JIT's long-standing hang bug is also fixed.

**856/856 regression assertions · 54 corpus examples · −81.8% call overhead · 0 known critical bugs**

### 🚀 Performance: −81.8% Call Overhead, 5.50× Faster Function Calls

A rigorously-measured campaign (`perf stat -e instructions:u`, two-point isolation, every step regression-tested) took VG's per-call interpreter overhead from 45,785 → **8,323 instructions/call**. Highlights: engaged a previously-dead `fast_params` fast path (a latent parser bug made it a no-op), per-call-site resolution memoization, a reusable locals-frame pool that eliminates the last per-call heap allocation, and a single-copy `OP_GET_LOCAL` fast path. Gap to GDScript's own call overhead narrowed from 34× to **6.22×**.

### 🎮 New: Native VGCpu6502 Core — C64 Emulator Boots to READY at ~2.9× Real Speed

`demos/C64_Emulator/` gains an opt-in **Turbo Mode**: a fully-native, reentrant C++ 6502/6510 core that boots the real, unmodified KERNAL/BASIC ROMs to `**** COMMODORE 64 BASIC V2 ****` / `READY.` at ~2.9× real PAL hardware speed — up from the VG-interpreted path's ~600-9,000 cycles/sec ceiling.

### 🐛 Three Silent Miscompilation Bugs, Fixed

- **`OP_JUMP_TABLE`** sized by case count instead of value range — silently mis-dispatched ~half the opcode space (the reason the C64 emulator never booted).
- **`CONST + VAR` / `CONST * VAR`** (e.g. `1024 + (srow * 40)`) silently computed `CONST + CONST` — fixed in all 4 codegen sites, safe in either operand order now.
- **`ByRef` write-back** nulled the caller's variable when a builtin is shadowed by a same-named user Sub — redesigned the opcode to no-op instead of writing `Nil`.

### 🛠 Native JIT No Longer Hangs

`VG_JIT=2`/`VG_JIT=3` (opt-in, off by default) used to hang on any non-trivial function — a missing `restore_vm()` on JIT return corrupted the caller's instruction pointer. Fixed, plus new bitwise/shift and trap-safe MOD/IDIV-by-constant IR coverage.

### ⚡ C64-Specific VM Caching (+47% cumulative)

`OP_CALL`/`OP_GET_GLOBAL` HashSet-gated caching specifically targeting the emulator's hot paths — general wins for any call-heavy or global-variable-heavy VG program.

### 🤖 Narcea AI Pair Fixes

Fixed a `write_file` over-stripping bug and an agent-loop re-entrancy bug (found via a new headless DeepSeek-backed eval harness) that was silently dropping mid-task context on every multi-hop turn.

Full details, GDScript comparison, and complete changelog: [RELEASE_NOTES_5.3.0-Beta4.md](https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_NOTES_5.3.0-Beta4.md)

---

### 📦 Downloads

| Platform | Package |
|---|---|
| **Windows** | `VisualGasic_v5.3.0-Beta4_windows_x86_64.zip` (or the `.exe` installer) |
| **Linux** | `VisualGasic_v5.3.0-Beta4_linux_x86_64.zip` |

Manual install: extract into your project's `addons/` folder, enable in **Project → Project Settings → Plugins**.

### 🧪 Testing

```bash
./run_test_suite.sh   # === ALL TESTS PASSED === (856/856)
```

### 🚀 What's Next

| Release | Target | Scope |
|---|---|---|
| 5.4-beta | Oct 15, 2026 | M5: Narcea AI pair (full), async queue |
| 6.0-rc1 | Dec 1, 2026 | M6–M8: Causal Chain, language parity, C++ FFI |
| 6.0 stable | Jan 1, 2027 | 🎉 Production release |

Full timeline: [RELEASE_SCHEDULE.md](https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_SCHEDULE.md)

---

## Release Settings

- ⬜ Mark as **pre-release** (leave UNCHECKED — this release becomes "Latest")
- Target branch: `main`
- Attach: Windows zip/installer, Linux zip (see build output for exact filenames)

## Post-Release Checklist

- [ ] Verify both zip downloads extract and load in a fresh Godot 4.6.1 project
- [ ] Update README.md "Current Release" badge/section to v5.3.0-Beta4
- [ ] Update website "Latest Release" section/download links
- [ ] Post Facebook release message (see FACEBOOK_RELEASE_MESSAGE.md)
- [ ] Post to Discord #announcements
- [ ] Create GitHub Discussion "5.3.0-Beta4 Feedback Thread"
