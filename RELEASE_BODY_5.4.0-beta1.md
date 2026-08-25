🚀 **VisualGasic 5.4.0-beta1** — VG beats GDScript on **every published benchmark**: **12/12 compute** + **9/9 draw** (Aug 2026).

### Highlights

- **Draw grid-loop fusion** — hot `_Draw` paths compile to native `OP_DRAW_*_GRID_LOOP` opcodes
- **FunctionCall fixed** — compiler inlining + nested-loop fusion (~60× faster than GDScript on FunctionCall)
- **CI benchmark gate** — `scripts/benchmark_regression_check.sh` blocks speed regressions
- **On the road to VG6** — 5.x betas now; **v6.0.0** stable targets January 2027

### Key numbers

| Suite | Result |
|-------|--------|
| Compute | **12/12** faster than GDScript (checksums verified) |
| Draw | **9/9** faster than GDScript |
| Regression | CI benchmark gate + 871+ `.vg` assertions |

Full details: [RELEASE_NOTES_v5.4.0-beta1.md](https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_NOTES_v5.4.0-beta1.md) · [BENCHMARK_PUBLISHED_RESULTS.md](https://github.com/xgreenrx-star/VisualGasic/blob/main/BENCHMARK_PUBLISHED_RESULTS.md)

### Downloads

| Platform | Asset |
|----------|-------|
| **Linux** | `VisualGasic-Installer-v5.4.0-beta1-x86_64.AppImage` or `VisualGasic_v5.4.0-beta1_linux_x86_64.zip` |
| **Windows** | `VisualGasic-Installer-v5.4.0-beta1-x86_64.exe` or `VisualGasic_v5.4.0-beta1_windows_x86_64.zip` |
| **Offline** | `VisualGasic-Installer-Offline-v5.4.0-beta1-linux-x86_64.zip` · `VisualGasic-Installer-Offline-v5.4.0-beta1-windows-x86_64.zip` |
| **Asset Library** | `VisualGasic_AssetLibrary_v5.4.0-beta1.zip` |

**Godot:** 4.6.1+ · **Mark as Pre-release**
