# VisualGasic 5.5.0-beta3 Release Notes

**Release date:** September 26, 2026  
**Status:** Public beta  
**Previous:** [5.5.0-beta2.1](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.5.0-beta2.1)  
**Requires:** Godot **4.6.1+** (Mono not required)

---

## What’s new (in plain terms)

**Visual Gasic** is still what it’s always been: VB6-flavored `.vg` scripts inside Godot, with Narcea in the editor when you want help. **5.5.0-beta3** adds two big buckets of “try this” content and the engine support behind them:

1. **A retro game pack + pixel canvas** — Dozens of small games and demos (Invaders, Gorillas, Nibbles, …) plus extra screen sizes if you like chunky, fixed-resolution art. Good for learning, ports, and “just let me draw pixels” prototypes.
2. **Wireframe 3D sample** — **Elite Wire Slice** shows vector ships, a cockpit HUD, and a tiny trade loop — early work, but a real end-to-end game sample.

Nothing here replaces Godot’s normal 2D/3D path. Modern projects can ignore the pixel canvas entirely.

### Install in a minute

1. Download **`VisualGasic_AssetLibrary_v5.5.0-beta3.zip`** from [Releases](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.5.0-beta3).
2. Unzip into your project’s `addons/visual_gasic/` (merge/replace the folder).
3. **Project → Project Settings → Plugins** → enable **VisualGasic**.

**Quick demos**

| Try | Open in Godot → F5 |
|-----|---------------------|
| Game pack menu | `samples/showcases/qb_abc_showcase/` — press **8** for Gorillas, **.** for screen-size gallery |
| Wireframe space | `samples/games/elite_wire_slice/` |
| Twin-pane tools UI | `samples/apps/vg_twinpane/` |

Full changelog: [CHANGELOG.md](CHANGELOG.md#550-beta3---2026-09-26)

---

## Screenshots

### Elite Wire Slice — wireframe flight sample (work in progress)

![Elite Wire Slice — cockpit, scanner, and wireframe station](https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/docs/screenshots/beta3_elite_wire_slice.png)

`samples/games/elite_wire_slice/` — expect rough edges; see the sample README for known drawing quirks on some GPUs.

### Gorillas — from the QB ABC showcase

![Gorillas running in Visual Gasic](https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/docs/screenshots/beta3_gorillas.png)

`samples/showcases/qb_abc_showcase/` — press **8** on the main menu. Reimplementation in `.vg`, not a pasted `.BAS` file.

---

## Highlights

### Retro pack & pixel canvas

- **`samples/showcases/qb_abc_showcase/`** — one menu, many small games and QB64-style demos; main menu **`.`** opens a **screen mode gallery** (DOS sizes + classic-inspired layouts).
- **Standalone gallery project:** `samples/showcases/classic_screen_modes/`.
- **Engine:** extended `SCREEN` modes (including split playfield layouts), `ScreenMode()` / `GfxWidth()` / `GfxHeight()` / `GfxPlayfieldBottom()`, project settings **`vg/classic/enabled`** and **`vg/classic/clip_playfield`**.
- **Docs:** [Classic porting guide](docs/manual/classic_porting_guide.md), [Classic games graphics](docs/manual/classic_games_graphics.md), [QuickBASIC graphics mode](docs/manual/qb_graphics_mode.md).
- **Narcea** prefers the pixel canvas when classic mode is enabled for the project.

### Elite Wire Slice + vector canvas

- New sample **`samples/games/elite_wire_slice/`** — `DrawRawWireMesh`, layered `VGVectorCanvas2D`, docking/trade loop (demo scope).
- **Vector fixes:** batched line dispatch, `GetMouseX` / `GetMouseY` / `GetMousePosition` compat, module-level `Dim` defaults for imported mesh modules.
- **Plugin docs:** vector graphics README + `DrawRawWireMesh` / `DrawLinesColored` helpers.

### Tests

- `test_qb_screen.vg`, `test_raw_wire_mesh.vg`, `test_module_packed_dim.vg`, `test_reference_input_smoke.vg`.

---

## Upgrade notes

- **From 5.5.0-beta2 / beta2.1:** Replace `addons/visual_gasic/` with this zip. **GDExtension binaries changed** — do not mix old `.so` / `.dll` with new GDScript.
- **Asset Library:** submit changelog in [ASSET_LIBRARY_CHANGELOG_5.5.0-beta3.md](ASSET_LIBRARY_CHANGELOG_5.5.0-beta3.md) when moderators catch up.

---

## Known issues

- **Elite Wire Slice:** incomplete demo; line/HUD artifacts possible on OpenGL compatibility (Intel Mesa). See sample README.
- **Gorillas / showcase:** some Tier B ports remain roadmap items; menu lists what’s in-tree today.
- **Installers on the website** may still point at an older one-click build; **this beta’s engine is the Asset Library zip above** until the next installer cut.
