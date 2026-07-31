# GitHub Release Template (v5.3.0-Beta3)

## Release Title
**VisualGasic v5.3.0-Beta3 — C64/GBA Emulator Demos, Cross-Module Bytecode, Buffer Type**

## Tag
`v5.3.0-Beta3`

## Release Body (copy everything below into the GitHub Release description)

---

🎉 **VisualGasic 5.3.0-Beta3** ships two brand-new hardware emulator demos — a full **Commodore 64** (6510 CPU, VIC-II, real KERNAL/BASIC ROMs) and a **Game Boy Advance** (ARM7TDMI) — plus cross-module bytecode compilation, a new Buffer Type, a `Global` keyword, cross-file class `Import`, `Exit While`, and a measured ~21-40% reduction in call/hot-path overhead.

**777/777 regression assertions · 54 corpus examples · 2 new full hardware emulator demos · 0 known critical bugs**

### 🎮 New Demo: Commodore 64 Emulator

A from-scratch software C64 running the **real, unmodified KERNAL and BASIC V2 ROMs** — full 6510 CPU (151 opcodes), VIC-II graphics chip, CIA1/CIA2 I/O. Boots all the way to the `**** COMMODORE 64 BASIC V2 ****` banner and a working `READY.` prompt.

Building it found and fixed a chain of real bugs: a `BlitImage` silent no-op (Rect2 vs Rect2i), a VIC-II frame-render race, a 38-column border gap, a viewport-scaling mismatch, and — the standout bug of the release — a boot-stub stack-corruption bug where a missing `LDX #$FF : TXS` reset sequence let the KERNAL's own RAM-init routine silently overwrite a `JSR` return address, skipping the startup banner via a bogus warm-start.

### 🕹️ Demo Fixes: Game Boy Advance Emulator

Thumb opcode bit-field decoding fixes, ARM CPU core bugs, class-instance field-visibility bugs, and a new Load ROM... button, found via real-ROM testing.

### ⚡ Cross-Module Bytecode Compilation

Subs/Functions in `Import`'d `.vg` files now compile to bytecode instead of falling back to the slower AST tree-walk interpreter, with full cross-module `MemoryBuffer` global support.

### ✨ Buffer Type + Optimizer Hints (#4, #5)

```vg
Dim buf As New MemoryBuffer(1024)   ' 10 dedicated opcodes, direct PackedByteArray access
buf(0) = 255
```

### ✨ `Global` Keyword, Cross-File Class `Import`, `Exit While`

```vg
Global Const MAX_PLAYERS As Integer = 4

Import "shapes.vg"
Dim s As New Square()               ' Class defined in shapes.vg now works
```

### 🚀 Performance

- `call_internal()` call-site caching: ~21% reduction in call overhead
- Hot-path cleanup in emulator CPU step loop: ~40% throughput gain
- New `FunctionCall` micro-benchmark added

### 🤖 New AI Provider

DeepSeek joins Ollama, OpenAI, Claude, Gemini, Codeium, and Amazon Q as a Narcea AI Pair provider.

Full details, GDScript comparison, and complete changelog: [RELEASE_NOTES_5.3.0-Beta3.md](https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_NOTES_5.3.0-Beta3.md)

---

### 📦 Downloads

| Platform | Package |
|---|---|
| **Windows** | `VisualGasic_v5.3.0-Beta3_windows_x86_64.zip` (or the `.exe` installer) |
| **Linux** | `VisualGasic_v5.3.0-Beta3_linux_x86_64.zip` |

Manual install: extract into your project's `addons/` folder, enable in **Project → Project Settings → Plugins**.

### 🧪 Testing

```bash
./run_test_suite.sh   # === ALL TESTS PASSED === (777/777)
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

- ☑️ Mark as **pre-release**
- Target branch: `main`
- Attach: Windows zip/installer, Linux zip (see build output for exact filenames)

## Post-Release Checklist

- [ ] Verify both zip downloads extract and load in a fresh Godot 4.6.1 project
- [ ] Update README.md "Current Release" badge/section to v5.3.0-Beta3
- [ ] Update website "Latest Release" section/download links
- [ ] Post Facebook release message (see FACEBOOK_RELEASE_MESSAGE.md)
- [ ] Post to Discord #announcements
- [ ] Create GitHub Discussion "5.3.0-Beta3 Feedback Thread"
