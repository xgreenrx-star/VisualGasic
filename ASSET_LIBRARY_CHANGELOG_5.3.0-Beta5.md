# VisualGasic 5.3.0-beta5 — IDE Stability Update

**Release date:** August 16, 2026  
**Requires:** Godot 4.6+  
**Platforms:** Linux, Windows, macOS (GDExtension binaries included)

---

## What's New Since 5.3.0-beta4

### Fixed — Native Script Editor Crash

Fixed a crash (signal 11) when pressing **Enter** in Godot's built-in Script editor on `.vg` tabs. The GDScript code-completion overlay conflicted with the VisualGasic language extension; the overlay is now disabled on native Script tabs. The dedicated VG embedded editor retains full completion.

### Added — VB6 Enter / Block Closing

Native Script tabs now match the embedded VG editor:

- **Enter** preserves correct indentation
- **For** loops auto-insert **Next** (with loop variable when present)
- Block openers auto-insert matching closers: **End If**, **Wend**, **End Sub**, **End Function**, and similar

### Added — Keyword Auto-Correct

Lowercase BASIC keywords capitalize to proper VB6 casing on line leave — on both native Script tabs and the embedded code editor. Examples: `for` → **For**, `dim` → **Dim**, `if` → **If**, `then` → **Then**.

### Updated Binaries

All platform GDExtension binaries rebuilt for this release.

---

## Carried Forward From 5.3.0-beta4

No regressions — these Beta4 improvements remain in place:

- **81.8% faster function calls** (5.50× call overhead reduction)
- **Native 6502 CPU core** — C64 Emulator Turbo Mode boots to `READY.` at ~2.9× real hardware speed
- **Three silent miscompilation bugs fixed** (`OP_JUMP_TABLE`, `CONST + VAR` arithmetic, `ByRef` write-back)
- **Native JIT hang fix** and Narcea AI Pair agent-loop reliability fixes

---

## Quality

- **856/856** regression tests passing
- **54/54** corpus examples passing

---

## Links

- [Documentation Hub](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/DOCS.md)
- [Full Release Notes](https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_NOTES_5.3.0-Beta5.md)
- [Report Issues](https://github.com/xgreenrx-star/VisualGasic/issues)
