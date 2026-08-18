# Godot Asset Library — VisualGasic

Status of the VisualGasic listing on the [Godot Asset Library](https://godotengine.org/asset-library/asset).

---

## Current status (v5.3.0-Beta6)

| Field | Value |
|-------|--------|
| **Version submitted** | 5.3.0-Beta6 |
| **Godot version** | 4.6+ |
| **License** | GPL v3.0 |
| **Download source** | GitHub Release — `VisualGasic_AssetLibrary_v5.3.0-Beta6.zip` |
| **Listing state** | **Submitted — awaiting moderator approval** |

Changelog copy for the Asset Library version field: [`ASSET_LIBRARY_CHANGELOG_5.3.0-Beta6.md`](../ASSET_LIBRARY_CHANGELOG_5.3.0-Beta6.md) (BBCode variant available in release notes workflow).

User-facing install steps: [Installation Guide — Method 0](../guides/INSTALLATION.md#-method-0-godot-asset-library-recommended-if-you-already-have-godot)

---

## Submission checklist (completed)

- [x] Plugin metadata in `addons/visual_gasic/plugin.cfg` (version **5.3.0-Beta6**)
- [x] Asset library metadata in `.assetlib.json`
- [x] Installation documentation — [`docs/guides/INSTALLATION.md`](../guides/INSTALLATION.md)
- [x] GitHub release **v5.3.0-Beta6** with Asset Library zip attached
- [x] GPL v3.0 license
- [x] Asset Library submission uploaded (August 2026)
- [ ] Moderator approval
- [ ] Post-approval: verify search/install from Godot AssetLib tab
- [ ] Post-approval: update README badge if AssetLib download stats are available

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
| **Download URL** | `https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.3.0-Beta6/VisualGasic_AssetLibrary_v5.3.0-Beta6.zip` |
| **Version** | 5.3.0-Beta6 |
| **Icon URL** | https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/addons/visual_gasic/icon.svg |
| **Download Method** | GitHub Release |

**Description (short):** VB6-style programming language and full IDE for Godot 4.6 — Form Designer, JIT bytecode, debugger, Narcea AI pair, and 122+ built-in functions. GDExtension binaries for Linux, Windows, and macOS included.

**Screenshots to include:**
1. Code editor with `.vg` file and Command Help
2. Form Designer / Narcea menu form
3. IDE debugger or Immediate Window
4. Running demo (Pong or calculator)

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
