# Godot Asset Library — VisualGasic

Status of the VisualGasic listing on the [Godot Asset Library](https://godotengine.org/asset-library/asset/visual-gasic/visual-gasic/).

---

## Current status (v5.5.0-beta2.1)

| Field | Value |
|-------|--------|
| **Version submitted** | 5.5.0-beta2.1 (pending submit) |
| **Godot version** | 4.6+ |
| **License** | GPL v3.0 |
| **Download source** | GitHub Release — `VisualGasic_AssetLibrary_v5.5.0-beta2.1.zip` |
| **Listing state** | **Live** (store) — submit version update for moderator approval |

Changelog copy for the Asset Library version field: [`ASSET_LIBRARY_CHANGELOG_5.5.0-beta2.1.md`](../../ASSET_LIBRARY_CHANGELOG_5.5.0-beta2.1.md) (**Markdown** for store.godotengine.org — `-` lists, `**bold**`, `` `code` ``; do **not** use BBCode or `•`).

User-facing install steps: [Installation Guide — Method 0](../guides/INSTALLATION.md#-method-0-godot-asset-library-recommended-if-you-already-have-godot)

---

## Submission checklist (5.4.0-beta2)

- [x] Plugin metadata in `addons/visual_gasic/plugin.cfg` (version **5.4.0-beta2**)
- [x] Asset library metadata in `.assetlib.json`
- [x] Installation documentation — [`docs/guides/INSTALLATION.md`](../guides/INSTALLATION.md)
- [x] GitHub release **v5.4.0-beta2** with Asset Library zip attached
- [x] GPL v3.0 license
- [x] Asset Library listing live (store.godotengine.org)
- [ ] Moderator approval for **5.4.0-beta2** version update
- [ ] Post-approval: verify search/install from Godot AssetLib tab

---

## Asset information (reference)

Use these values when submitting updates:

| Field | Recommended value |
|-------|-------------------|
| **Title** | VisualGasic |
| **Category** | Scripts |
| **Godot Version** | 4.6 |
| **Repository URL** | https://github.com/xgreenrx-star/VisualGasic |
| **Issues URL** | https://github.com/xgreenrx-star/VisualGasic/issues |
| **Download URL** | `https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.5.0-beta2.1/VisualGasic_AssetLibrary_v5.5.0-beta2.1.zip` |
| **Version** | 5.5.0-beta2.1 |
| **Icon URL** | https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/addons/visual_gasic/icon.svg |
| **Download Method** | GitHub Release |

**Description (short — paste into Asset Library summary; ≤500 characters):**

VisualGasic brings a modern Basic programming model to Godot 4.6: VB6-inspired syntax on Godot's scene and node system. Write .vg game logic with Sub, Function, Dim, and event handlers—build 2D/3D without learning GDScript. Familiar to VB6, VBA, and BASIC. Godot editor integration: IntelliSense, VGasic panels, UI Forms (experimental), debugger, Narcea, AGCK. Manual port from VB6; bulk .vbp import is optional community plugin, not v6.0 core. Linux, Windows, macOS, HTML5. GPL v3.

**Description (long — optional store body / README lead):**

Godot is a free, open-source game engine with a scene-based architecture that fits VisualGasic’s familiar, object-oriented approach.

**Why VisualGasic for Godot?** VisualGasic extends Godot with modern Basic syntax and readability: meaningful keywords (`End If`, `Next`, `Loop`), natural control flow (`For i = 1 To 10`), and English-like statements (`If health <= 0 Then`) instead of making GDScript a prerequisite. You leverage Godot’s node system, maintain simplicity, and access engine features through `.vg` scripts wired the VB6 way—`Sub Form_Load()`, timers, and controls using names like `Caption` and `Interval`, not raw Godot property paths.

**Development environment:** Integrated script editor with syntax highlighting and IntelliSense, Visual Gasic IDE (40+ controls, live preview), Immediate Window, Toolbox, Property Inspector, and Project Explorer—plus debugger, Narcea AI assist, Arcade Game Construction Kit, and Working Nodes visual scripting.

**Legacy VB6:** Rewrite as `.vg` with familiar syntax; optional community VB6 importer plugin (see docs)—or start from demos and templates.

Requires Godot 4.6+. See the in-repo *Godot Programming Manual* (Chapter 1) for the full introduction.

**Screenshots to include:**
1. Code editor with `.vg` file and Command Help
2. Beta Showcase title screen (12/12 compute HUD)
3. IDE debugger or Immediate Window / DataFile sidecar
4. Running demo (Pong or Beta Showcase)

---

## After approval — user install flow

1. Open Godot 4.6.1+
2. **AssetLib** tab → search **VisualGasic**
3. **Download** → **Install** (installs to `addons/visual_gasic/`)
4. **Project → Project Settings → Plugins** → enable **VisualGasic**
5. Restart Godot
6. Switch to the **Visual Gasic IDE** tab or attach a `.vg` script to a node

Verify with the repo smoke script (optional):

```bash
./scripts/run_asset_library_smoke.sh
```

---

## Submitting a future version update

1. Bump `VERSION`, `addons/visual_gasic/plugin.cfg`, and `.assetlib.json`
2. Build and attach `VisualGasic_AssetLibrary_v<version>.zip` to a GitHub release
3. Write changelog — copy from `ASSET_LIBRARY_CHANGELOG_<version>.md`
4. Visit https://godotengine.org/asset-library/asset — edit listing → new version
5. Wait for moderator approval (typically 1–3 days)
6. Update this document and [`INSTALLATION.md`](../guides/INSTALLATION.md) download links

---

## Other install methods

| Method | Doc |
|--------|-----|
| One-click installer (AppImage / exe) | [INSTALLATION.md — Method 1](../guides/INSTALLATION.md) |
| `vg` CLI / curl install | [INSTALLATION.md — Method 2](../guides/INSTALLATION.md) |
| Manual GitHub release ZIP | [INSTALLATION.md — Method 4](../guides/INSTALLATION.md) |
| Build from source | [INSTALLATION.md — Method 5](../guides/INSTALLATION.md) |

---

*Maintainer notes: do not use absolute paths like `/home/...` in user-facing submission docs.*
