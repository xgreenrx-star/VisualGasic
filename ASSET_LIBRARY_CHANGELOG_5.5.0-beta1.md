# VisualGasic 5.5.0-beta1 — Asset Library Changelog

Copy the **plain text block** below into the Godot Asset Library version changelog field.

---

## Plain text (paste into Asset Library)

```
VisualGasic 5.5.0-beta1 — September 13, 2026
Requires Godot 4.6+ · Linux / Windows / macOS binaries included

WHAT'S NEW

GRAVEN v6 slice (developer preview — in repo, not in this zip)
• First playable Thrust-style gravity explorer: pulse rings, tow, mass wells, 17-room graph
• Open projects/vg_graven_slice/project.godot → F5 · F1 dev terminal (warp rooms 1–17)
• Early preview only — grid-based rooms, gameplay WIP; vector rework planned for a later v6 cut

Engine fixes
• Restore "R" + CStr(n) + "Mass" — dynamic Restore labels work on AST tree-walk path
• Shader.Param / builtin namespace dispatch fixed on AST fallback (pod movement no longer crashes)
• Relative Include resolution for multi-file .vg modules
• Owner-relative Godot builtins (position, GlobalPosition) in cross-module helpers
• Include errors map to the correct source file and line

IDE
• Context Rail vector DATA editor — inline Data/Restore blocks and .vgv sidecar panel
• Reference audit gate keeps command help synced with compiler surface

Python bridge and tools (carried forward)
• Typed msgpack protocol (opt-in: vg/python/use_typed_protocol)
• Causal-chain API for Code Navigator and Narcea

Quality
• 57 corpus examples · regression suite green including test_graven_mass_restore.vg
• Still 12/12 compute + 9/9 draw vs GDScript from 5.4.0-beta1

Upgrade: replace addons/visual_gasic/ or re-run installer. No breaking syntax changes from 5.4.0-beta2.

Release notes: https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_NOTES_v5.5.0-beta1.md
Changelog: https://github.com/xgreenrx-star/VisualGasic/blob/main/CHANGELOG.md
Download: https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.5.0-beta1/VisualGasic_AssetLibrary_v5.5.0-beta1.zip
```

---

## Plain Markdown (reference)

**Release date:** September 13, 2026  
**Requires:** Godot 4.6+  
**Platforms:** Linux, Windows, macOS (GDExtension binaries included)

See [RELEASE_NOTES_v5.5.0-beta1.md](RELEASE_NOTES_v5.5.0-beta1.md) for full details.
