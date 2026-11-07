# VisualGasic 5.7.0 Beta 4 - Asset Library submission copy

**Title:** VisualGasic
**Version:** 5.7.0-beta.4
**Godot:** 4.6.1 baseline
**License:** GPLv3
**Download:** https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.4/VisualGasic_AssetLibrary_v5.7.0-beta.4.zip
**Repository:** https://github.com/xgreenrx-star/VisualGasic

## Version Changelog

Copy this Markdown block into the store's Version Changelog field. Do not
add BBCode or heading markers.

```markdown
**VisualGasic 5.7.0-beta.4 - bug-fix beta**

- Optimized local/module lambda calls preserve nested block bodies and early returns
- Numeric and dynamically typed dictionary keys retain their identity
- Packed Vector3 subtraction/append works on the engine-backed path
- VG namespace methods such as Array.RemoveAt precede Godot static dispatch
- Optimized error-handler labels and Resume Next boundaries remain valid
- Rect/indexed value-type member edits write back and evaluate indices once
- Basis columns and Projection members/constants work in bytecode
- AST geometry constructors share bytecode overloads; For Each declares its loop variables
- StringBuilder Append is no longer miscompiled as array append
- Explicit VG-to-VG lifecycle calls no longer disappear behind the duplicate engine-notification guard
- Dictionary returns, iteration and nested control-flow escape analysis preserve ordinary Dictionary values
- Dead-store analysis keeps assignments used by indexed dictionary reads
- Append and packed-loop optimizations no longer confuse function calls or dictionary keys with array indexing
- Tier-2 JIT repairs mixed integer/float local storage across branches
- Scaled vector accumulation preserves vector types
- Module variables/constants shadow engine enum names correctly
- Null object values compare correctly with Nothing on affected AST paths
- AABB and Plane constructors preserve Vector3 arguments

**Upgrade**

- Close Godot, back up your project and replace the entire addon folder; new native binaries are required
- Includes Linux x86-64, Windows x64, universal macOS Intel/Apple Silicon, and Web binaries
- Public beta, not stable VG6. Godot 4.6.1 baseline. Mac downloads are not notarized

Release notes: https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.7.0-beta.4
Issues: https://github.com/xgreenrx-star/VisualGasic/issues
```

## Short description

VB6-style BASIC for Godot: .vg scripts, autocomplete, debugging, Immediate
window, DATA sprite editing, JIT compilation and reactive Whenever statements.
Optional Narcea AI assistance. Public beta; UI Forms and legacy IDE are opt-in.

The addon ZIP does not contain sample games. Store publication is separate
from uploading the ZIP to GitHub and remains subject to moderator approval.
