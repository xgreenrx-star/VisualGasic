# VisualGasic v3.5.0 Beta 3 — VB6 Compatibility & Performance Release

**Release Date**: March 8, 2026  
**Platforms**: Linux x86_64, Windows x86_64, macOS Universal (x86_64 + arm64)  
**Godot**: 4.5+ (tested on 4.6.1)

---

## What is VisualGasic?

**VisualGasic** is a modern, event-driven programming language for the Godot Engine inspired by Visual Basic 6's legendary approachability. It features a full Form Designer, JIT compiler, auto event wiring, and 220+ demo projects.

---

> ## ⚠️ BETA — READ THIS FIRST
>
> This is a **beta release** focused on VB6 language compatibility, IDE authenticity,
> and cross-platform binary availability.
> The core language, compiler, and JIT are stable. The IDE and Form Designer continue
> to be polished based on real-world testing.
>
> **This is not production-ready software.** Please use it to experiment, learn, build
> prototypes, and help us find bugs.

---

## What's New in v3.5.0-beta3

### 🚀 4 Language Bug Fixes — VB6 Compatibility

Critical language compatibility improvements that bring VisualGasic closer to real VB6 behavior:

- **Hex Literal Support** — `&HFF`, `&H1A2B`, `&HFFFF&` now parse correctly. Supports `&` (Long) and no suffix (Integer) forms.
- **Negative `For…Step`** — `For i = 10 To 1 Step -1` now decrements correctly instead of skipping the loop body.
- **`Print #N` File I/O** — `Print #1, expr` now writes to file handles, matching VB6's file output syntax.
- **`Err.Raise`** — `Err.Raise number, source, description` now triggers the runtime error handler correctly.

### 🎨 14 IDE Improvements — VB6 Authenticity

![Form Designer IDE](docs/screenshots/form_designer_ide.png)
*Full VB6-style IDE with Edit menu, Format menu, Code Editor with procedure separators*

#### Edit Menu (New)

| Item | Shortcut | Description |
|------|----------|-------------|
| Find… | Ctrl+F | Open Find dialog in code editor |
| Replace… | Ctrl+H | Open Find & Replace dialog |
| Comment Block | Ctrl+' | Prefix selected lines with `'` |
| Uncomment Block | Ctrl+Shift+' | Remove `'` prefix from selected lines |
| Indent | Ctrl+] | Indent selected lines one tab stop |
| Outdent | Ctrl+[ | Outdent selected lines one tab stop |
| Bookmarks → | | Full submenu: Toggle (Ctrl+F2), Next (F2), Previous (Shift+F2), Clear All |

#### Format Menu (5 New Items)

| Item | Description |
|------|-------------|
| Space Equally Horizontal | Distribute 3+ selected controls with even horizontal spacing |
| Space Equally Vertical | Distribute 3+ selected controls with even vertical spacing |
| Size to Grid | Snap selected control positions and sizes to the grid |
| Center in Form Horizontal | Center selected controls horizontally within the form |
| Center in Form Vertical | Center selected controls vertically within the form |

#### Code Editor Enhancements

- **Procedure Separator Lines** — horizontal rule above each `Sub` / `Function` / `Property` header, just like VB6
- **Parameter Info Popup** — typing inside function parentheses shows the signature with the current parameter highlighted
- **Pretty Listing** — on save, keywords are auto-capitalized, operators are spaced, indentation is normalized
- **Breakpoints (F9)** — click the gutter or press F9 to toggle breakpoints; Ctrl+Shift+F9 for conditional breakpoints with expression dialog

#### Other IDE Improvements

- **Toolbox Reorganized** — controls grouped by type (Common, Container, Data, Dialog, Advanced) matching VB6's Toolbox tabs
- **Control Arrays** — paste/duplicate a control to automatically create indexed arrays (`Command1(0)`, `Command1(1)`, …)

### 🌍 macOS Universal Binary (NEW)

For the first time, this release includes a **macOS Universal binary** supporting both Intel (x86_64) and Apple Silicon (arm64) Macs. Cross-compiled with osxcross + macOS 14.5 SDK.

---

## 🏎️ Performance Benchmarks

All benchmarks run on the same machine with Godot 4.6.1 headless. Checksums verified to ensure identical computation.

| Benchmark | GDScript | VisualGasic | C++ | VG vs GDScript | Winner |
|-----------|----------|-------------|-----|----------------|--------|
| Arithmetic (100K ops) | 5,317 μs | 326 μs | 59 μs | **16.3× faster** | C++ |
| Array Sum (100K) | 4,364 μs | 120 μs | 58 μs | **36.4× faster** | C++ |
| String Concat (10K) | 5,022 μs | 69 μs | 508 μs | **72.8× faster** | 🏆 **VG** |
| Branching (100K) | 6,997 μs | 66 μs | 52 μs | **106× faster** | C++ |
| Array+Dict (10K) | 11,302 μs | 3,899 μs | 3,450 μs | **2.9× faster** | C++ |
| Dict Get (100K) | 28,978 μs | 2,265 μs | — | **12.8× faster** | 🏆 **VG** |
| Dict Set (100K) | 19,253 μs | 2,530 μs | — | **7.6× faster** | 🏆 **VG** |
| Interop (1K calls) | 8,174 μs | 114 μs | 6,874 μs | **71.7× faster** | 🏆 **VG** |
| Allocations (10K) | 6,966 μs | 145 μs | 483 μs | **48× faster** | 🏆 **VG** |
| Alloc Fast (10K) | 9,958 μs | 1,893 μs | 273 μs | **5.3× faster** | C++ |
| File I/O (1K) | 921 μs | 470 μs | 386 μs | **1.96× faster** | C++ |

**Highlights:**
- VisualGasic **beats C++** in String Concat (7.4×), Interop (60×), and Allocations (3.3×)
- Average speedup over GDScript: **~35× across all benchmarks**
- Branching is **106× faster** than GDScript thanks to JIT-compiled branch elimination

---

## 🧪 Test Results

```
Test Suite: 54 files, 483 assertions
Passed:     481 ✅
Failed:       2 ❌ (test_file_permissions.vg — sandbox-related, not a code bug)
Pass Rate:  99.6%
```

---

## All Changes Since v3.5.0-beta2

### Language Fixes
- **Hex literals** (`&HFF`, `&H1A2B`, `&HFFFF&`) now parse and evaluate correctly
- **Negative `For…Step`** — `For i = 10 To 1 Step -1` works correctly
- **`Print #N`** — `Print #1, expr` writes to file handles as per VB6
- **`Err.Raise`** — triggers runtime error handler with number, source, description

### IDE — Edit Menu
- **Find** (Ctrl+F) and **Replace** (Ctrl+H) dialogs wired to code editor
- **Comment Block** (Ctrl+') and **Uncomment Block** (Ctrl+Shift+')
- **Indent** (Ctrl+]) and **Outdent** (Ctrl+[)
- **Bookmarks submenu**: Toggle (Ctrl+F2), Next (F2), Previous (Shift+F2), Clear All

### IDE — Format Menu
- **Space Equally Horizontal/Vertical** — even distribution of 3+ controls
- **Size to Grid** — snap positions and sizes to grid
- **Center in Form Horizontal/Vertical** — center controls within the form

### IDE — Code Editor
- **Procedure separator lines** — horizontal rule above Sub/Function/Property headers
- **Parameter Info popup** — shows function signatures while typing inside parentheses
- **Pretty Listing** — auto-format on save (keyword capitalization, operator spacing, indentation)
- **Breakpoint gutter** — click or F9 to toggle, Ctrl+Shift+F9 for conditional breakpoints

### IDE — Toolbox & Controls
- **Toolbox reorganized** by control type: Common, Container, Data, Dialog, Advanced
- **Control Arrays** — copy/paste automatically creates indexed control arrays

### VB6 Import
- **Import result dialog** — shows summary of imported forms/modules/controls
- **Form Designer auto-open** — imported forms open immediately in the designer
- **FileDialog leak fix** — dialogs are properly freed after import
- **Multi-variable Dim expansion** — `Dim a, b, c As Integer` splits into separate declarations

### Documentation
- **IDE_SHORTCUTS.md** updated with all new Edit menu, Format menu, breakpoint, and automatic feature shortcuts

### Build
- **macOS Universal binary** — x86_64 + arm64 combined with lipo (osxcross + macOS 14.5 SDK)
- **Windows cross-compiled** with MinGW-w64

---

## Platform Binaries

| Platform | Architecture | Size | File |
|----------|-------------|------|------|
| Linux | x86_64 | 77 MB | `libvisualgasic.linux.template_debug.x86_64.so` |
| Windows | x86_64 | 133 MB | `libvisualgasic.windows.template_debug.x86_64.dll` |
| macOS | Universal (x86_64 + arm64) | 42 MB | `libvisualgasic.macos.template_debug.framework/` |

---

## What's Included

- **220+ demo projects** — 2D games, 3D, shaders, audio, UI apps, threading, networking
- **4 ported official Godot demos** — Screen Space Shaders, Sky Shaders, 2D Platformer, Squash the Creeps
- **Custom Controls system** — build your own .tscn controls and drag them onto forms
- **Form Designer** — full VB6-style WYSIWYG with 40+ controls, Properties panel, Toolbox, live preview
- **JIT Compiler** — hot loops compile to native x86-64 (2×–106× faster than GDScript)
- **IntelliSense** with 80+ completions, snippets, and Godot type awareness
- **Debugger** with conditional breakpoints, watch window, call stack, and time-travel debugging
- **Theme Editor** with 8 built-in themes and custom theme creation
- **Object Browser** for exploring the Godot class hierarchy
- **108 built-in functions** (string, math, file I/O, date/time, collections)
- **481 tests passing** (99.6% pass rate)
- **Linux, Windows, and macOS binaries** included

---

## Install

1. Download the release ZIP for your platform
2. Extract and copy `addons/visual_gasic/` into your Godot project folder
3. Copy the binary for your platform into `your_project/bin/`
4. Open **Project → Project Settings → Plugins** → Enable **"Visual Gasic"**
5. Create `.vg` files and start coding — or use **File → New Form** in the Form Designer

---

## Upgrade from v3.5.0-beta2

1. Back up your project
2. Delete your existing `addons/visual_gasic/` folder and `bin/` folder
3. Copy the new `addons/visual_gasic/` and binary from the release ZIP
4. Re-enable the plugin if needed
5. Your `.vg` files and `.tscn` forms are fully compatible — no migration needed

---

## Known Issues

- macOS binary is cross-compiled and not code-signed — you may need to right-click → Open on first launch
- Theme Editor font settings (font name, size, bold keywords) are stored in VGTheme but not yet exposed in the editor UI
- Custom themes are saved per-project, not globally
- `test_file_permissions.vg` fails in sandboxed environments (not a code bug)

---

## Links

- **GitHub**: https://github.com/xgreenrx-star/VisualGasic
- **License**: MIT
- **Previous Release**: [v3.5.0-beta2 Release Notes](RELEASE_NOTES_v3.5.0-beta2.md)
- **First Beta**: [v3.2.0-beta1 Release Notes](RELEASE_NOTES_v3.2.0-beta1.md)
