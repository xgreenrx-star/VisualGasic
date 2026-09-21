# VisualGasic 5.5.0-beta2 — Asset Library Changelog

> **Store submit:** Use **[ASSET_LIBRARY_CHANGELOG_5.5.0-beta2.1.md](ASSET_LIBRARY_CHANGELOG_5.5.0-beta2.1.md)** for the current Asset Library version (**5.5.0-beta2.1**). Keep this file for historical reference to the beta2 listing text.

Copy the block below into **Version Changelog** on [store.godotengine.org](https://store.godotengine.org) (Markdown preview — **do not** use BBCode or `•` bullets).

Tips: blank line before each list; each line starts with `-` + space; use `**bold**` and `backticks` for code.

---

## Paste into Asset Library (Markdown)

```markdown
**VisualGasic 5.5.0-beta2** — September 19, 2026  
Requires Godot 4.6+ · Linux / Windows GDExtension binaries in this zip

**Narcea Live Debug Capture (opt-in)**

- Project Settings → Vg → Narcea: enable `live_debug_capture`
- Vibe Code: **Live debug capture (this run)** while debugging
- Local-only viewport snapshots, UI tree, stack/locals — purged when the game stops
- Vision PNGs only if your AI provider supports images

**Godot game wiring**

- Bound `Connect`, lambda signal handlers, `RemoveAt`, autoload globals
- `Dim camera` can shadow `Camera.*` so 3D `LookAt` dispatches correctly

**IDE and debugging**

- Immediate tab: capture status + Clear capture
- Explain screen / Refresh snapshot / optional Drive mode (paused input)
- Narcea system prompt updated for live capture

**Performance (published benchmarks)**

- Tier A unchanged: **12/12 compute** and **9/9 draw** faster than GDScript (checksums verified)
- Sept 2026 gameplay rows: IntegerLoop ~65× · NodePropertyChurn ~170× · entity ticks / For Each ~3–8× vs GDScript (Linux snapshot)
- Full tables: https://github.com/xgreenrx-star/VisualGasic/blob/main/BENCHMARK_PUBLISHED_RESULTS.md

**Binaries**

Fresh Linux + Windows builds (Sep 19). Windows cross-compile fixed (MinGW `pascal` macro rename).

**Repository layout (clone GitHub — not in this zip)**

- Samples: `samples/games`, `samples/apps`, `samples/demos`, `samples/showcases`
- Harness: `engine_lab/` · legacy `projects/` symlinks kept briefly
- Try `samples/games/brotato3d/` or `samples/showcases/vg_beta_showcase/`

**Upgrade**

Replace `addons/visual_gasic/` from 5.5.0-beta1 or 5.4.x. No intentional breaking syntax changes.

**Links**

- Release notes: https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_NOTES_v5.5.0-beta2.md
- Changelog: https://github.com/xgreenrx-star/VisualGasic/blob/main/CHANGELOG.md
- Download: https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.5.0-beta2/VisualGasic_AssetLibrary_v5.5.0-beta2.zip
```

---

## Editor note (Godot AssetLib dock)

The in-editor changelog view may show lists with extra spacing (known Godot backend quirk). The **web store Preview** is the source of truth for moderator review. If a list looks broken in-editor only, the web preview is still acceptable.

---

## BBCode (legacy — do not use on store.godotengine.org)

Older docs used `[b]` / `[ul]` for the editor RichTextLabel. The **new Asset Store manage UI renders Markdown** and shows BBCode tags as literal text.
