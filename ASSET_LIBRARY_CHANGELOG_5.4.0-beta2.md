# VisualGasic 5.4.0-beta2 — Asset Library Changelog

Copy the **plain text block** below into the Godot Asset Library version changelog field.

---

## Plain text (paste into Asset Library)

```
VisualGasic 5.4.0-beta2 — September 2026
Requires Godot 4.6+ · Linux / Windows / macOS binaries included

WHAT'S NEW

Language (M5)
• Buffer type: Dim mem As Buffer — byte-level access with VM fast paths (emulation, I/O)
• Optimizer hints: @fast_loop, @accumulator, @pure, etc. (safe metadata for future optimizer work)
• Let x As Type — block-scoped variables inside For / If / While
• Godot constructors (Vector2i, Rect2i, Color) fixed on AST fallback paths

Python bridge and async
• Typed msgpack protocol (opt-in: vg/python/use_typed_protocol) keeps integer types on PyBridge
• PyCallAsync / Await improvements and demo suite
• Causal-chain API for code navigation and Narcea

Narcea AI Pair
• Golden-path validation: Tier A form scaffold + Tier B platformer replay

Reliability
• GDExtension loads reliably on fresh clones and CI runners
• 916/916 regression tests · 57 corpus examples

Still from 5.4.0-beta1
• 12/12 compute + 9/9 draw faster than GDScript (published benchmarks)
• Beta Showcase demo in repo: https://youtu.be/FUw8zgbn_tU

Upgrade: replace addons/visual_gasic/ or re-run installer. No breaking syntax changes from beta1.

Release notes: https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_NOTES_v5.4.0-beta2.md
Changelog: https://github.com/xgreenrx-star/VisualGasic/blob/main/CHANGELOG.md
```

---

## Plain Markdown (reference)

**Release date:** September 2026  
**Requires:** Godot 4.6+  
**Platforms:** Linux, Windows, macOS (GDExtension binaries included)

See [RELEASE_NOTES_v5.4.0-beta2.md](RELEASE_NOTES_v5.4.0-beta2.md) for full details.
