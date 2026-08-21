# VisualGasic 5.3.0-beta7 — Bracket Indexing & Regression Gates

**Release date:** August 21, 2026  
**Requires:** Godot 4.6+  
**Platforms:** Linux, Windows, macOS (GDExtension binaries included)

---

## What's New Since 5.3.0-beta6

### Fixed — Bracket Array Indexing (Critical)

`arr[i]` now parses and evaluates correctly. Previously `players[0]` silently returned the whole array, breaking 3D mob chase (`GlobalPosition` on Array → Nothing).

### Fixed — ByRef Array Slots

Bytecode path now write-backs to `arr(i)` slots passed ByRef.

### Added — CI & Regression Tests

- Full `.vg` test suite runs in CI (`run_test_suite.sh --vg-only`)
- New tests: bracket vs paren indexing, Vector3 subtract, `GetNodesInGroup` mob pattern, syntax parity

### Added — Narcea & IDE

- Reference offer on Send, user-assisted web references for game clones
- Canvas platformer / 3D scaffold prompts, Cursor SDK cross-platform fixes
- Visual AI audit agent run graphs via Working Nodes

---

## Quality

- **871/871** regression tests passing (117 files)
- **332/332** reference examples parse-clean

---

## Links

- [Documentation Hub](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/DOCS.md)
- [Full Release Notes](https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_NOTES_5.3.0-Beta7.md)
