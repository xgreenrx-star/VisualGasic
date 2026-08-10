# VisualGasic sub-plugins

This directory contains optional sub-plugins bundled with the VisualGasic
addon. **All of them are original components of the VisualGasic project**,
written by the same author/team as the rest of `addons/visual_gasic/`, and
are licensed under the same terms as the parent addon — see
[`../LICENSE`](../LICENSE) (GPLv3) — unless a sub-plugin's own folder
explicitly says otherwise below.

None of these are unrelated third-party plugins bundled without permission.
They ship together because they are all part of the single VisualGasic
product (form design, audio, art generation, game-builder tooling, etc.),
the same way a large IDE ships many built-in tools under one license.

> **Work in progress.** Everything in this folder is optional, additive
> tooling on top of the core VisualGasic language/compiler/IDE (a public
> beta — actively developed, not yet a finished 1.0 product — which lives
> one level up in `addons/visual_gasic/`). These sub-plugins range from
> functional-but-evolving to actively-in-development to
> experimental/incomplete — see the Status column below before relying on
> any of them for production work. None are required for VisualGasic itself
> to function; each can be disabled individually in Godot's Plugins settings
> if it isn't ready for your use case.

## Plugin index

| Folder | What it is | Status | License |
|---|---|---|---|
| `agck/` | "AGCK"-style rapid game builder (level/actor/shader/sound editors) | Maintenance-only, not actively expanded | Original VG code — GPLv3 (root LICENSE) |
| `form_designer/` | Legacy Form Designer plugin entrypoint | Legacy/frozen — superseded by `ui_forms/` going forward | Original VG code — GPLv3 (root LICENSE) |
| `gdai/` | GDAI provider bridge plugin entrypoint | Work in progress | Original VG code — GPLv3 (root LICENSE) |
| `ui_forms/` | Experimental 2D-viewport UI Forms designer | Experimental, active development | Original VG code — GPLv3 (root LICENSE) |
| `vector_graphics/` | Vector canvas / shape drawing tools | Work in progress | Original VG code — GPLv3 (root LICENSE) |
| `vg3d/` | 3D editor plugin entrypoint | Early/incomplete, minimal functionality | Original VG code — GPLv3 (root LICENSE) |
| `web_publish/` | Export a VG form to static HTML | Work in progress | Original VG code — GPLv3 (root LICENSE) |
| `working_nodes/` | Visual node-wiring code generator | Maintenance-only, not actively expanded | Original VG code — GPLv3 (root LICENSE) |
| `vgaiart/` | AI art generation (calls hosted third-party HTTP APIs; no vendored code) | Experimental (see its own `README.md`) | Original VG code — GPLv3 (root LICENSE) |
| `vgsfx/` | Sound-effects generator, ports parts of bfxr2/Sfxr/AKWF | Functional, ongoing polish | **Mixed** — see [`vgsfx/NOTICE.md`](vgsfx/NOTICE.md) for the vendored MIT/Apache-2.0/CC0 portions; original glue code (`vg_vgsfx_plugin.gd`, `vgsfx_dock.gd`, etc.) is GPLv3 (root LICENSE) |
| `vgmusic/` | Music tracker, vendors Bosca Ceoil Blue + GDSiON | Functional on Linux; other platforms need binaries built (see `vgmusic/README.md`) | **Mixed** — vendored code under [`vgmusic/bosca/`](vgmusic/bosca/) and [`vgmusic/bin/`](vgmusic/bin/) is MIT-licensed (see their own `LICENSE` files, also summarized in [`vgmusic/README.md`](vgmusic/README.md)); original glue code (`vg_vgmusic_plugin.gd`, `runtime/`) is GPLv3 (root LICENSE) |
| `_disabled.gdsfx/` | Superseded, incomplete precursor to `vgsfx/`. Has no `plugin.cfg`, so Godot never loads it as a plugin — kept only for reference. Not a separate distributable plugin. | Disabled/incomplete, not shipped in releases | Original VG code — GPLv3 (root LICENSE) |

## Third-party code summary

Only two sub-plugins vendor code from other authors, and both already
document it in-place:

- **`vgmusic/`** — Bosca Ceoil Blue and GDSiON, both by Yuri Sizov & contributors, both MIT. See `vgmusic/README.md`, `vgmusic/bosca/LICENSE`, `vgmusic/bin/LICENSE`.
- **`vgsfx/`** — bfxr2 (MIT), Sfxr DSP port (Apache-2.0), Adventure Kid Waveforms (CC0). See `vgsfx/NOTICE.md`.

Everything else in this directory is original code written for VisualGasic.
