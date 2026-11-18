# VisualGasic 5.8.0 Beta 1 - Asset Library submission copy

**Title:** VisualGasic
**Version:** 5.8.0-beta.1
**Godot:** 4.6.1 baseline
**License:** GPLv3
**Download:** https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.8.0-beta.1/VisualGasic_AssetLibrary_v5.8.0-beta.1.zip
**Repository:** https://github.com/xgreenrx-star/VisualGasic

## Version Changelog

Copy this Markdown block into the store's Version Changelog field. Do not
add BBCode or heading markers.

```markdown
**VisualGasic 5.8.0-beta.1 - core performance and correctness beta**

- Quiet-pair VM gap microbench: every published run_gap case at or under GDScript parity (vg/gd ≤ 1.00) with JIT on and with VG_JIT=0
- Largest quiet-pair wins (JIT): function calls ~30×, Integer globals ~14×, locals ~5× — see BENCHMARK_PUBLISHED_RESULTS.md
- New side-by-side demo: samples/apps/vg_speed_race (VG vs GDScript particle integrate) plus scripts/check_vm_gap.sh gate
- Tier-2 JIT safely declines AndAlso/OrElse expression joins that need a stack phi (issue #25); bytecode results stay correct
- AST Len matches bytecode for containers, packed arrays, and strings (issue #24)
- AST and bytecode agree on mixed Variant arithmetic with numeric String and Nothing (issue #24)
- Missing Dictionary keys evaluate to Nothing without setting Err.Number (issue #26)
- Unhandled lifecycle errors report procedure/line and continue later frames; Try/Finally rethrows after Finally

**Upgrade**

- Close Godot, back up your project and replace the entire addon folder; new native binaries are required
- Includes Linux x86-64, Windows x64, universal macOS Intel/Apple Silicon, and Web binaries
- Public beta, not stable VG6. Godot 4.6.1 baseline. Mac downloads are not notarized
- Microbenchmarks are not a claim that every VG game is faster than GDScript

Release notes: https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.8.0-beta.1
Issues: https://github.com/xgreenrx-star/VisualGasic/issues
```

## Short description

VB6-style BASIC for Godot: .vg scripts, autocomplete, debugging, Immediate
window, DATA sprite editing, JIT compilation and reactive Whenever statements.
Optional Narcea AI assistance. Public beta; UI Forms and legacy IDE are opt-in.

The addon ZIP does not contain sample games. Store publication is separate
from uploading the ZIP to GitHub and remains subject to moderator approval.
