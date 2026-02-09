# VisualGasic v2.3.0 — Quality, Performance & Developer Tooling

**Release Date:** February 9, 2026  
**Godot Compatibility:** 4.3+ (built with 4.5.1 stable)  
**Platforms:** Linux x86_64, Windows x86_64

---

## 🔥 Highlights

- **6 critical bug fixes** in the interpreter core (For loops, recursion, EOF, error codes)
- **7 new editor plugins** (IntelliSense, Go To Definition, Linter, Snippets, Themes, Formatter, Recent Projects)
- **Comprehensive test infrastructure** — 264-item checklist at **95.1% pass rate**, 243+ automated tests
- **Write # statement** — full VB6-compatible comma-delimited file output

---

## 🐛 Critical Bug Fixes

### For Loop Safety Limit (was silently capping at 1,000 iterations!)
The interpreter's For loop had a safety counter of `1,000` — meaning any loop from `For i = 1 To 5000` would silently stop at iteration 1,000. **Increased to 10,000,000.**

### Recursive Function Variable Scoping
Recursive functions (like Fibonacci) were corrupting local variables because all call frames shared a single `variables` Dictionary. Fixed with a **DimScanner** that identifies all local variables (Dim'd, For loop vars, parameters, return var) and saves/restores them at function boundaries.

### EOF Off-by-One Error
`EOF()` was using `eof_reached()` which triggered one byte too late, causing `Line Input` to read an extra empty line. Changed to `get_position() >= get_length()`.

### Error Code Standardization
- Array out-of-bounds now raises **error code 9** (Subscript out of range)
- File not found now raises **error code 53**
- `raise_error()` properly passes the source parameter in all code paths

---

## ✨ New Features

### Write # Statement
Full VB6-compatible `Write #` support for comma-delimited output:
```vb
Open "data.csv" For Output As #1
Write #1, "Alice", 30, "Engineer"   ' Outputs: "Alice",30,"Engineer"
Close #1
```

### Editor Plugin Suite (7 new tools)
| Plugin | Description |
|--------|-------------|
| **IntelliSense** | Code completion: 70+ keywords, 80+ built-in functions, Godot types, snippets |
| **Go To Definition** | F12 / Ctrl+Click navigation to Sub, Function, Variable, Class definitions |
| **Linter** | Static analysis: unused vars, missing End, deprecated syntax, empty blocks |
| **Snippet Manager** | 30+ templates with tab stops (if, for, sub, class, try, async, etc.) |
| **Theme Manager** | 5 themes: VB6 Classic, Modern Dark/Light, High Contrast, Solarized Dark |
| **Code Formatter** | Auto-indent, keyword capitalization, operator spacing |
| **Recent Projects** | Track last 10 projects with pin support |

---

## 🧪 Test Infrastructure

### Test Checklist (264 items across 9 sections)
| Section | Items | Pass Rate |
|---------|-------|-----------|
| 1. Core Language | 33 | 100% |
| 2. Data Types & Variables | 17 | 100% |
| 3. Operators & Expressions | 9 | 100% |
| 4. Built-in Functions | 72 | 91.7% |
| 5. Control Structures | 22 | 100% |
| 6. Error Handling | 21 | 100% |
| 7. File I/O | 22 | 100% |
| 8. Performance | 40 | 100% |
| 9. Regression | 28 | 100% |
| **Total** | **264** | **95.1%** |

### Automated Test Files
- `test_performance.vg` — 6 benchmarks (loop 1M, string 1K, array 1K, dict 1K, Fibonacci(20), Factorial(12))
- `test_regression.vg` — 28 regression tests across all core features
- `test_error_handling.vg` — 14 error handling scenarios
- `test_fileio_output.vg` — 12 file I/O tests (Open, Print #, Line Input, EOF, Write #)
- `test_modern_features.vg` — 19 modern feature tests (Struct, Dictionary, ForEach, Interpolation)

---

## 📦 Binaries

### Linux x86_64
- `libvisualgasic.linux.template_debug.x86_64.so`
- `libvisualgasic.linux.template_release.x86_64.so`
- `libvisualgasic.linux.editor.x86_64.so`

### Windows x86_64
- `libvisualgasic.windows.template_debug.x86_64.dll`
- `libvisualgasic.windows.template_release.x86_64.dll`
- `libvisualgasic.windows.editor.x86_64.dll`

---

## 📋 Full Changelog

See [CHANGELOG.md](CHANGELOG.md) for the complete history.
