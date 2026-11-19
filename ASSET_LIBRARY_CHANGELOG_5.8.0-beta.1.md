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

- Dated quiet-pair VM snapshot reached GDScript parity with JIT on and VG_JIT=0; later runs vary and do not establish universal parity
- Largest quiet-pair wins (JIT): function calls ~30×, Integer globals ~14×, locals ~5× — see BENCHMARK_PUBLISHED_RESULTS.md
- Side-by-side VG vs GDScript races: particles, arithmetic, arrays, Dictionary reads, branching, strings and calls; includes scripts/check_vm_gap.sh gate
- Live-race verification publishes wins and losses: generic-array scan takes 1.33× GD time and short-string building 2.14× in the dated local snapshot
- Tier-2 JIT safely declines AndAlso/OrElse expression joins that need a stack phi (issue #25); bytecode results stay correct
- AST Len matches bytecode for containers, packed arrays, and strings (issue #24)
- AST and bytecode agree on mixed Variant arithmetic: numeric String coercion; left-hand Nothing stays Nothing; numeric left plus Nothing coerces like to_double (issue #24)
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
