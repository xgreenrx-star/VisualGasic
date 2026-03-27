# VisualGasic v4.4.0-rc3 Release Notes — IntelliSense Chaining & Test Fixes

**Release Date**: March 27, 2026  
**Previous Version**: 4.4.0-rc2  
**Status**: **Release Candidate 3** — IntelliSense dot-chain fixes, parser fix, 23 new test assertions

---

## 🏁 Release Candidate 3 — What Changed

RC3 is a **code-completion and test-quality release** with 6 focused fixes since RC2. The headline improvements are correct dot-completion inside With blocks, GlobalObject chained resolution (e.g. `App.Path.Length`), and a parser fix that lets keyword-named Subs (`Sub Reset`) work inside classes.

**Upgrade from RC2:** Drop-in replacement — copy `addons/visual_gasic/` over the RC2 version and restart Godot. No migration steps needed.

---

## 🆕 New Features

### 🔗 With-Block Chained Dot-Completion

Dot-completion inside `With` blocks now correctly resolves multi-level chains.

**Before (RC2):** Typing `.Text1.` inside a `With Me` block always showed first-level Form members instead of TextBox members.

**After (RC3):** The editor detects chained dots (`.Text1.`), walks the member chain from the With object type through each member, and shows the correct completions for the final type.

```vb
With Me
    .Text1.Text = "hello"    ' Text1 → TextBox → .Text shows String members
    .Text1.Text.Length        ' .Text → String → .Length shows Integer
End With
```

### 🌐 GlobalObject Dot-Chain Resolution

Global VB6 objects (`App`, `Screen`, `Clipboard`, `Err`, `Debug`, `Printer`) now support chained dot-completion beyond the first level.

**Before (RC2):** `App.` showed App members, but `App.Path.` showed nothing.

**After (RC3):** `App.Path.` resolves Path → String and shows String members (Length, ToUpper, Contains, etc.).

```vb
Debug.Print App.Path.Length          ' App.Path → String → .Length
Debug.Print Err.Description.ToUpper  ' Err.Description → String → .ToUpper
```

---

## 🐛 Bug Fixes

### Parser: Keyword-Named Subs in Classes

`Sub Reset` and other procedures whose names match VB6 keywords (Reset, Stop, etc.) now parse correctly inside Class modules. Previously, `parse_sub()` only accepted `TOKEN_IDENTIFIER` for procedure names, causing a silent parse failure when the name was tokenized as `TOKEN_KEYWORD`.

**Impact:** Fixes 2 previously failing tests in `test_method_overloading.vg` — overloaded `Reset` methods on Calculator class instances now dispatch correctly.

### Runtime: Global Builtin Guard for Object Method Calls

Added an `if (!s->base_object)` guard to prevent global builtin functions (like the file `Reset` statement) from intercepting object method calls. `calc.Reset` now always dispatches to the object's `Reset` method, not the VB6 file-reset builtin.

---

## 🧪 Test Suite Improvements

### 3 Previously Empty Test Files Now Have Assertions

| Test File | Assertions | Coverage |
|-----------|-----------|----------|
| `test_error_handling.vg` | 5 | Try/Catch basics, variable preservation, Finally, combined, nested |
| `test_integ_collections.vg` | 10 | Dictionary creation, Add/Remove/Count, String concatenation, Array + For Each |
| `test_math_lib.vg` | 8 | Abs, Int, Sgn, Sqr, Round, Min/Max, Mod, exponentiation |

### Test Suite Totals

| Metric | RC2 | RC3 | Change |
|--------|-----|-----|--------|
| Test files | 75 | 75 | — |
| Assertions | 555 | 578 | +23 |
| Passed | 553 | 576 | +23 |
| Failed | 2 | 2 | — (symlink tests) |
| Errors | 0 | 0 | — |

The 2 remaining failures are in `test_file_permissions.vg` (symlink creation requires elevated privileges on some systems) and are pre-existing since v4.3.0.

---

## 📁 Files Changed

### C++ Runtime
- `src/visual_gasic_parser.cpp` — Accept `TOKEN_KEYWORD` as procedure name in `parse_sub()`
- `src/visual_gasic_instance_execute.inc` — Guard `call_builtin` with `if (!s->base_object)` at STMT_CALL

### GDScript Addon
- `addons/visual_gasic/vg_code_edit.gd` — With-block chained resolution, GlobalObject completion popup
- `addons/visual_gasic/vg_intellisense.gd` — `resolve_member_type()` handles `GlobalObject:` prefix

### Tests & Docs
- `test_proj/test_suite/test_error_handling.vg` — Rewritten with 5 Try/Catch assertions
- `test_proj/test_suite/test_integ_collections.vg` — Rewritten with 10 Collection/Array assertions
- `test_proj/test_suite/test_math_lib.vg` — Added 8 math function assertions (keeps utility exports)
- `TEST_COVERAGE.md` — Updated header stats and version history table

---

## ⬆️ Upgrade Instructions

1. Copy the `addons/visual_gasic/` folder over your existing installation
2. Copy the platform-specific `.so` / `.dll` / `.dylib` from `bin/` to `addons/visual_gasic/bin/`
3. Restart Godot
4. No migration or project changes needed

---

## 🔮 What's Next

- **v4.4.0 stable** — pending final community testing of RC3
- Remaining roadmap items tracked in [ROADMAP.md](ROADMAP.md)
