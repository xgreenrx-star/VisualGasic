# VisualGasic v2.2.2 Release Notes

**Release Date:** February 6, 2026  
**Type:** Bugfix Release

## Summary

This bugfix release resolves a critical crash in the Form Designer and fixes several language feature bugs discovered during comprehensive keyword testing. All 64 comprehensive tests now pass.

## Bug Fixes

### 🔧 Critical: Form Designer Double-Click Crash Fixed

**Issue:** Double-clicking a button or control in the Form Designer caused Godot to crash with signal 11 (SIGSEGV).

**Root Cause:** The `_apply_vg_syntax_highlighting()` function was assigning a `CodeHighlighter` to the script editor's `CodeEdit` widget. This conflicted with Godot 4.5.1's internal handling of `ScriptLanguageExtension` scripts, causing a memory access violation when the editor tried to use both the custom highlighter and the extension's built-in highlighting methods simultaneously.

**Resolution:** Removed the custom GDScript-based syntax highlighting. The C++ extension already provides syntax highlighting through its native `_get_comment_delimiters()` and `_get_string_delimiters()` methods, which Godot uses automatically for custom script languages.

### 🔧 Select Case Matching Fixed (including Range Support)

**Issue:** `Select Case` statements were not matching values correctly, and `Case X To Y` range syntax was not working.

**Root Cause:** The parser was not storing range end values, and the interpreter's STMT_SELECT handler wasn't checking for range comparisons.

**Resolution:** 
- Added `range_ends` vector to CaseBlock AST node
- Updated parser to detect "To" keyword and parse range end values
- Updated interpreter to perform `value >= low AND value <= high` comparison for ranges

### 🔧 Not Operator Fixed

**Issue:** The `Not` operator was not working correctly in boolean expressions.

**Root Cause:** The bytecode compiler's `eval_constant_expr()` function was missing handling for the "Not" operator during constant folding.

**Resolution:** Added proper Not operator handling: `if (u->op.nocasecmp_to("Not") == 0) return !vg_variant_truthy(v);`

### 🔧 Static Variables Fixed

**Issue:** `Static` variables inside subroutines were not persisting their values between calls.

**Root Cause:** The bytecode compiler didn't have proper fallback handling for static variable declarations.

**Resolution:** Added fallback to interpreter mode when static variables are encountered, ensuring proper persistence.

### 🔧 While/Wend Loop Fixed

**Issue:** `While...Wend` loops were logging "Unsupported statement type 5" errors.

**Root Cause:** The STMT_WHILE case was completely missing from the bytecode compiler's `compile_statement()` switch.

**Resolution:** Added complete STMT_WHILE case handler with proper loop structure and condition checking.

### 🔧 Arithmetic Operators Fixed (Mod, \, ^)

**Issue:** The `Mod` (modulo), `\` (integer division), and `^` (exponentiation) operators returned `<null>` instead of correct values.

**Root Cause:** Multiple issues:
1. Missing constant folding support in `eval_constant_expr()` for these operators
2. Missing `OP_POWER` opcode in the bytecode system
3. Parser changes not propagated to all evaluation paths

**Resolution:**
- Added `OP_POWER` opcode to bytecode enum and VM execution
- Added constant folding for `Mod`, `\`, and `^` in `eval_constant_expr()`
- Added `^` and `**` handling in bytecode compiler emission
- Now `17 Mod 5 = 2`, `17 \ 5 = 3`, and `3 ^ 2 = 9` work correctly

### 🔧 ByRef Parameter Write-Back Fixed

**Issue:** `ByRef` parameters in subroutine calls were not modifying the caller's variable.

**Root Cause:** The interpreter executed the called function but did not write back modified ByRef parameter values to the caller's variables after the function returned.

**Resolution:**
- Added ByRef write-back logic in STMT_CALL handler to copy modified parameter values back to caller variables
- Added bytecode compiler fallback for functions with ByRef parameters (these now use the interpreter path which supports ByRef correctly)

### 🔧 Minor: REM Comment Highlighting Error

**Issue:** The syntax highlighter logged an error: "color regions must start with a symbol" for REM comments.

**Root Cause:** `add_color_region("REM ", ...)` was invalid because Godot requires color regions to start with a symbol character, not a letter.

**Resolution:** This is now moot since custom highlighting was removed, but the fix was to use `add_keyword_color("REM", ...)` instead.

## Upgrade Instructions

1. Replace the following files in your project's `addons/visual_gasic/` folder:
   - `visual_gasic_plugin.gd`
   - All `.so` files (Linux) or `.dll` files (Windows)

2. Restart the Godot editor

## Compatibility

- **Godot Version:** 4.5.1 (stable)
- **Platforms:** Linux x86_64, Windows x86_64
- **Backward Compatible:** Yes, no API changes

## Files Included

### Linux
- `libvisualgasic.linux.template_debug.x86_64.so`
- `libvisualgasic.linux.template_release.x86_64.so`
- `libvisualgasic.linux.editor.x86_64.so`

### Windows
- `libvisualgasic.windows.template_debug.x86_64.dll`
- `libvisualgasic.windows.template_release.x86_64.dll`

### Plugin Files
- `visual_gasic_plugin.gd` (updated)
- `visual_gasic.gdextension`
- All other `.gd` support files

## Known Issues

None in this release.

---

**Full Changelog:** [v2.2.1...v2.2.2](https://github.com/user/VisualGasic/compare/v2.2.1...v2.2.2)
