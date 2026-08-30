🚀 **VisualGasic 5.4.0-beta1** — VG beats GDScript on **every published benchmark** (**12/12 compute** + **9/9 draw**) plus the **VG Beta Showcase** tour project.

![Beta Showcase title — 5.4.0-BETA1](https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/docs/screenshots/Screenshot%20at%202026-08-25%2013-59-02.png)

### Highlights

- **12/12 compute + 9/9 draw** — draw grid-loop fusion + FunctionCall inlining (~60× faster on FunctionCall)
- **VG Beta Showcase** — Backrooms hub → shaders → About VG → Squash → Neon Runner → Vector Storm ([README](https://github.com/xgreenrx-star/VisualGasic/blob/main/projects/vg_beta_showcase/README.md) · [YouTube](https://youtu.be/FUw8zgbn_tU))
- **Movie Maker recording** — `scripts/record_vg_beta_showcase.sh` for promo video capture
- **891/891** regression assertions · CI benchmark regression gate
- **On the road to VG6** — 5.x betas now; **v6.0.0** stable targets January 2027

![IDE — DataFile, context rail, AI Pair](https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/docs/screenshots/Screenshot%20at%202026-08-25%2010-50-34.png)

### Key numbers

| Suite | Result |
|-------|--------|
| Compute | **12/12** faster than GDScript (checksums verified) |
| Draw | **9/9** faster than GDScript |
| Regression | **891/891** `.vg` assertions + CI benchmark gate |

Full details: [RELEASE_NOTES_v5.4.0-beta1.md](https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_NOTES_v5.4.0-beta1.md) · [BENCHMARK_PUBLISHED_RESULTS.md](https://github.com/xgreenrx-star/VisualGasic/blob/main/BENCHMARK_PUBLISHED_RESULTS.md) · [Website](https://xgreenrx-star.github.io/VisualGasic/)

### Downloads

> **Portable platform zips** (`VisualGasic_v*_linux_x86_64.zip` / `*_windows_x86_64.zip`) are **no longer provided** — they exceeded GitHub’s 2 GB limit. Install **Godot 4.6.1+**, then use a one-click installer, offline bundle, **Asset Library zip**, or minimal **addon zip**.

| Platform | Asset |
|----------|-------|
| **Linux** | [`VisualGasic-Installer-v5.4.0-beta1-x86_64.AppImage`](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.4.0-beta1/VisualGasic-Installer-v5.4.0-beta1-x86_64.AppImage) |
| **Windows** | [`VisualGasic-Installer-v5.4.0-beta1-x86_64.exe`](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.4.0-beta1/VisualGasic-Installer-v5.4.0-beta1-x86_64.exe) |
| **Offline** | [`VisualGasic-Installer-Offline-v5.4.0-beta1-linux-x86_64.zip`](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.4.0-beta1/VisualGasic-Installer-Offline-v5.4.0-beta1-linux-x86_64.zip) · [`VisualGasic-Installer-Offline-v5.4.0-beta1-windows-x86_64.zip`](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.4.0-beta1/VisualGasic-Installer-Offline-v5.4.0-beta1-windows-x86_64.zip) |
| **Asset Library** | [`VisualGasic_AssetLibrary_v5.4.0-beta1.zip`](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.4.0-beta1/VisualGasic_AssetLibrary_v5.4.0-beta1.zip) · [store listing](https://store.godotengine.org/asset/visual-gasic/visual-gasic/) |
| **Manual (BYO Godot)** | [`VisualGasic-v5.4.0-beta1.zip`](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.4.0-beta1/VisualGasic-v5.4.0-beta1.zip) — extract `addons/visual_gasic/` into your project |

**Godot:** 4.6.1+ · **Mark as Pre-release**

**Try the showcase:** clone the repo → open `projects/vg_beta_showcase/project.godot` → **F5**
