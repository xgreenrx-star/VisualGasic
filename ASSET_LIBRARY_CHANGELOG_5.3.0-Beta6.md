# VisualGasic 5.3.0-beta6 — Language Correctness & Asset Library Hardening

**Release date:** August 18, 2026  
**Requires:** Godot 4.6+  
**Platforms:** Linux, Windows, macOS (GDExtension binaries included)

---

## What's New Since 5.3.0-beta5

### Fixed — `End` Command (Critical)

Standalone `End` now terminates the application. Fixes `Sub or Function not defined: End` on Exit buttons.

### Fixed — Language & Builtin Gaps

- VB6 doubled-quote string escapes
- Explicit conversion builtins (`CInt`, `CSng`, …)
- `Deg2Rad` / `Rad2Deg`
- Godot 4.6 OptionButton popup compatibility

### Added — Quality Gates

- Programmer's Reference runtime harness (CI)
- Asset Library install smoke script

---

## Quality

- **856/856** regression tests passing
- **332/332** reference examples parse-clean

---

## Links

- [Documentation Hub](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/DOCS.md)
- [Full Release Notes](https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_NOTES_5.3.0-Beta6.md)
