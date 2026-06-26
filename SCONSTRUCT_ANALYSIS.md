# SConstruct Build System Analysis — Jun 22 2026

**Scope**: Map which SConstruct lines register IDE vs CORE sources for the split.

---

## Build Flow (196 lines total)

| Line | Purpose | CORE/IDE | Notes |
|---|---|---|---|
| 5-16 | Godot C++ environment setup + debug flags | SHARED | Use as-is for both |
| 20-28 | Source collection: `Glob("src/*.cpp")` + exclusions | **KEY SPLIT POINT** | Add IDE filenames to `exclude_files` list |
| 29-50 | Compiler flags (MSVC vs GCC, debug/release) | SHARED | Use as-is for both |
| 65-102 | System libraries (libffi, libopenmpt, POSIX, Windows, Android) | CORE | All needed by VM/runtime |
| 107-150 | SharedLibrary link + post-build mirror to `addons/visual_gasic/bin/` | **MODIFICATION NEEDED** | Change mirror path for VG Core |
| 151-196 | Post-build mirror function + commented tools | CORE | Mirror logic can be parameterized |

---

## CORE-Only Build Changes

**Change 1: Add IDE files to exclude list (lines 25-28)**

Current:
```python
exclude_files = [
    # All LSP binding issues resolved — LspPosition replaced with int params (v3.2)
]
```

For VG Core build, replace with:
```python
exclude_files = [
    "src/visual_gasic_editor_plugin.cpp",
    "src/visual_gasic_form_designer.cpp",
    "src/visual_gasic_debugger.cpp",
    "src/visual_gasic_toolbox.cpp",
    "src/gasic_ai_controller.cpp",
    "src/gasic_form.cpp",
    "src/visual_gasic_bracket_completion.cpp",
    "src/visual_gasic_cbm_completion.cpp",
    "src/visual_gasic_snippets.cpp",
    "src/visual_gasic_systray.cpp",
    "src/visual_gasic_common_dialog.cpp",
]
```

**Change 2: Mirror destination (line 133 in non-macOS case)**

Current:
```python
library = env.SharedLibrary(
    "demo/bin/visualgasic{}{}".format(env["suffix"], env["SHLIBSUFFIX"]),
    source=sources,
)
```

For VG Core: can keep same output, but change mirror destination below (line 161):

**Change 3: Mirror path (line 161)**

Current:
```python
dst = "addons/visual_gasic/bin"
```

For VG Core, parameterize:
```python
# Allow override via command-line: scons vg_core=1
import os as _os
if _os.environ.get("VG_CORE", "0") == "1" or ARGUMENTS.get("vg_core", "0") == "1":
    dst = "addons/vg_core/bin"
else:
    dst = "addons/visual_gasic/bin"
```

---

## Strategy

**For IDE build (current behavior)**: No changes. Build as-is. Mirror to `addons/visual_gasic/bin/`.

**For VG Core build** (July 1):
1. Create a `SConstruct.core` file (copy of SConstruct with exclude_files + mirror path already set), OR
2. Modify SConstruct to accept `scons vg_core=1` flag and conditionally exclude IDE files

**Recommendation**: Option 2 (single SConstruct, flag-based). Less duplication, future-proof.

---

## Day 1 Implementation

Step by step:

1. In SConstruct, replace exclude_files list with the 11 IDE files above.
2. Add conditional mirror path logic (lines ~160) to check for `VG_CORE` env var or `vg_core=1` ARGUMENT.
3. Test build:
   - Full IDE: `scons platform=linux target=editor`
   - VG Core only: `scons platform=linux target=editor vg_core=1`
4. Verify output:
   - IDE: `addons/visual_gasic/bin/libvisualgasic.linux.editor.so`
   - Core: `addons/vg_core/bin/libvisualgasic.linux.editor.so`

---

## Files to Exclude (Complete List)

From the C++ classification, these 11 files are IDE-only:

```
visual_gasic_editor_plugin.cpp
visual_gasic_form_designer.cpp
visual_gasic_debugger.cpp
visual_gasic_toolbox.cpp
gasic_ai_controller.cpp
gasic_form.cpp
visual_gasic_bracket_completion.cpp
visual_gasic_cbm_completion.cpp
visual_gasic_snippets.cpp
visual_gasic_systray.cpp
visual_gasic_common_dialog.cpp
```

All others (130+ files) are CORE.

