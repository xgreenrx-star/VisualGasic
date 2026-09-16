# Repository layout

Visual Gasic is a **language + Godot addon + sample projects**. This map is for contributors and release packaging.

## Core (product)

| Path | Purpose |
|------|---------|
| `src/` | C++ tokenizer, compiler, VM (GDExtension) |
| `addons/visual_gasic/` | Godot editor plugin + shipped GDExtension binaries |
| `test_proj/` | Regression test harness (`test_suite/*.vg`) |
| `corpus/` | Small `.vg` teaching snippets (not full Godot projects) |
| `docs/` | Manual, guides, reference |
| `scripts/` | Build, CI, addon sync, benchmarks |

## Samples (user-facing Godot projects)

| Path | Purpose |
|------|---------|
| `samples/games/` | Finished or WIP games |
| `samples/apps/` | Utilities and tools |
| `samples/showcases/` | Tours, reels, marketing builds |
| `samples/demos/` | Feature demos by category |
| `samples/internal/` | Narcea/AGCK/CI host projects |

## Engine lab (developer harness)

| Path | Purpose |
|------|---------|
| `engine_lab/` | Benchmarks, fuzz, bytecode tests, form prototypes |

Formerly `demo/`. Symlink `demo` → `engine_lab` kept for one release cycle.

## Local archive (not shipped)

| Path | Purpose |
|------|---------|
| `archive/examples_mirror/` | Former top-level `examples/` (~1.2 GB accidental mirror; gitignored) |

## Compatibility symlinks (deprecated)

| Legacy | Points to |
|--------|-----------|
| `projects/<name>` | `samples/{games,apps,showcases,internal}/<name>` |
| `demos/` | `samples/demos/` |
| `demo/` | `engine_lab/` |

Remove these symlinks after downstream docs and CI no longer reference them.

## Not in git / local only

| Path | Notes |
|------|-------|
| `archive/examples_mirror/` | Old accidental full-repo copy under `examples/` — do not use |
| `Godot_v4.*` binaries | Download locally; gitignored |
| `.godot/` | Per-project editor cache |

## Addon policy

One canonical tree: `addons/visual_gasic/`. All sample projects use relative symlinks via `scripts/sync_addons.sh convert`.

## Release checklist

1. `scripts/sync_addons.sh check`
2. `scripts/ci_smoke.sh --all` (or spot-check key samples)
3. Update `samples/README.md` when adding projects
4. Package from `samples/` paths, not legacy `projects/`
