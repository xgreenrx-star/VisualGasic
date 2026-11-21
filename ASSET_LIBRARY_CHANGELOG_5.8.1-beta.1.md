# VisualGasic 5.8.1 Beta 1 - Asset Library submission copy

**Title:** VisualGasic
**Version:** 5.8.1-beta.1
**Godot:** 4.6.1 baseline
**License:** GPLv3
**Download:** https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.8.1-beta.1/VisualGasic_AssetLibrary_v5.8.1-beta.1.zip
**Repository:** https://github.com/xgreenrx-star/VisualGasic

## Version Changelog

Copy this Markdown block into the store's Version Changelog field. Do not
add BBCode or heading markers.

```markdown
**VisualGasic 5.8.1-beta.1 - correctness bug-fix beta**

- Exit Sub/Function/For/Do, Return and Continue inside Try now run Finally on bytecode, innermost first
- Constant AndAlso/OrElse expressions fold to Boolean instead of Nothing on bytecode
- Call arguments and indexed ByRef subscripts are evaluated exactly once
- Named ByRef arguments write back in parameter order
- Case -N and negative Case ranges parse; negative Integer literals stay Integer under bytecode/JIT
- All found by the new semantic fuzzer, which checks AST, interpreter, default and Tier-3 JIT against a reference model
- Includes all 5.8.0-beta.1 VM/JIT performance work

**Upgrade**

- Close Godot, back up your project and replace the entire addon folder; new native binaries are required
- Includes Linux x86-64, Windows x64, universal macOS Intel/Apple Silicon, and Web binaries
- Public beta, not stable VG6. Godot 4.6.1 baseline. Mac downloads are not notarized

Release notes: https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.8.1-beta.1
Issues: https://github.com/xgreenrx-star/VisualGasic/issues
```

## Short description

VB6-style BASIC for Godot: .vg scripts, autocomplete, debugging, Immediate
window, DATA sprite editing, JIT compilation and reactive Whenever statements.
Optional Narcea AI assistance. Public beta; UI Forms and legacy IDE are opt-in.

The addon ZIP does not contain sample games. Store publication is separate
from uploading the ZIP to GitHub and remains subject to moderator approval.
