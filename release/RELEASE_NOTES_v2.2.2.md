# VisualGasic v2.2.2 Release Notes

**Release Date:** February 6, 2026  
**Type:** Bugfix Release

## Summary

This bugfix release resolves a critical crash that occurred when double-clicking controls in the Form Designer to generate event handlers.

## Bug Fixes

### 🔧 Critical: Form Designer Double-Click Crash Fixed

**Issue:** Double-clicking a button or control in the Form Designer caused Godot to crash with signal 11 (SIGSEGV).

**Root Cause:** The `_apply_vg_syntax_highlighting()` function was assigning a `CodeHighlighter` to the script editor's `CodeEdit` widget. This conflicted with Godot 4.5.1's internal handling of `ScriptLanguageExtension` scripts, causing a memory access violation when the editor tried to use both the custom highlighter and the extension's built-in highlighting methods simultaneously.

**Resolution:** Removed the custom GDScript-based syntax highlighting. The C++ extension already provides syntax highlighting through its native `_get_comment_delimiters()` and `_get_string_delimiters()` methods, which Godot uses automatically for custom script languages.

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
