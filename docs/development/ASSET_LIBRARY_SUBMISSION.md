# Godot Asset Library — VisualGasic

Status of the VisualGasic listing on the [Godot Asset Library](https://godotengine.org/asset-library/asset/visual-gasic/visual-gasic/).

---

## Current status (v5.4.0-beta2)

| Field | Value |
|-------|--------|
| **Version submitted** | 5.4.0-beta2 |
| **Godot version** | 4.6+ |
| **License** | GPL v3.0 |
| **Download source** | GitHub Release — `VisualGasic_AssetLibrary_v5.4.0-beta2.zip` |
| **Listing state** | **Live** — update pending moderator approval for 5.4.0-beta2 |

Changelog copy for the Asset Library version field: [`ASSET_LIBRARY_CHANGELOG_5.4.0-beta2.md`](../../ASSET_LIBRARY_CHANGELOG_5.4.0-beta2.md) (plain text — paste into Godot Asset Library).

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
| **Download URL** | `https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.4.0-beta2/VisualGasic_AssetLibrary_v5.4.0-beta2.zip` |
| **Version** | 5.4.0-beta2 |
| **Icon URL** | https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/addons/visual_gasic/icon.svg |
| **Download Method** | GitHub Release |

**Description (short):** VB6-style programming language and full IDE for Godot 4.6 — Form Designer, JIT bytecode, debugger, Narcea AI pair, and 122+ built-in functions. **12/12 compute + 9/9 draw** vs GDScript (Aug 2026). GDExtension binaries for Linux, Windows, and macOS included.

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
