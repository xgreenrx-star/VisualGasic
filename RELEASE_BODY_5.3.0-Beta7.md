🎉 **VisualGasic 5.3.0-Beta7** fixes **bracket array indexing** (`arr[i]` — a silent bug that broke 3D mob AI), hardens **ByRef array slot write-back**, runs the full **`.vg` regression suite in CI**, and ships **Narcea** reference/web-scaffold improvements.

### Highlights

- **`players[0]` works** — bracket subscripts no longer return the whole array
- **871/871** regression assertions · **117** test files
- **CI gate** — `run_test_suite.sh --vg-only` on every PR
- **Narcea** — reference offer on Send, web references for clones, platformer/3D prompts, Cursor SDK fixes
- **ByRef** — array slot write-back on bytecode path

Full details: [RELEASE_NOTES_5.3.0-Beta7.md](https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_NOTES_5.3.0-Beta7.md)

### Documentation

- [Documentation Hub](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/DOCS.md)
- [Getting Started](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/guides/GET_STARTED.md)
- [Installation Guide](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/guides/INSTALLATION.md)
- [Changelog](https://github.com/xgreenrx-star/VisualGasic/blob/main/CHANGELOG.md)

### Downloads

| Platform | File |
| --- | --- |
| **Linux** | `VisualGasic-Installer-v5.3.0-Beta7-x86_64.AppImage` (recommended) or `VisualGasic_v5.3.0-Beta7_linux_x86_64.zip` |
| **Windows** | `VisualGasic-Installer-v5.3.0-Beta7-x86_64.exe` (recommended) or `VisualGasic_v5.3.0-Beta7_windows_x86_64.zip` |
| **Offline** | `VisualGasic-Installer-Offline-v5.3.0-Beta7-linux-x86_64.zip` · `VisualGasic-Installer-Offline-v5.3.0-Beta7-windows-x86_64.zip` |
| **Asset Library** | `VisualGasic_AssetLibrary_v5.3.0-Beta7.zip` |

**Requires Godot 4.6.1+**
