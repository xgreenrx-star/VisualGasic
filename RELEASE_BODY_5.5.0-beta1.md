🚀 **VisualGasic 5.5.0-beta1** — first playable **GRAVEN (VG6 slice)** preview, **Restore string expressions**, **Shader** namespace fixes, **Include** resolution for multi-file games, and the **Context Rail vector DATA editor**.

![GRAVEN — pulse room gameplay](https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/docs/screenshots/Screenshot%20at%202026-09-13%2009-50-28.png)

### Highlights

- **GRAVEN v6 slice (dev preview)** — 17-room Thrust-style explorer: pulse rings, tow, mass wells, hub navigation (`projects/vg_graven_slice/`)
- **Restore + Include fixes** — dynamic `Restore "R" + CStr(n) + "Mass"` works on AST path; relative `Include` for multi-module projects
- **Shader post-FX** — `Shader.Param` no longer crashes when moving the pod on AST fallback paths
- **Context Rail DATA editor** — inline vector `Data`/`Restore` blocks and `.vgv` sidecar panel
- **Owner-relative Godot builtins** — cross-module helpers see the correct node/control owner
- **57** corpus examples · regression suite green including `test_graven_mass_restore.vg`

> **GRAVEN is an early preview**, not a showcase build — rooms are still grid-based and gameplay is WIP. A vector-first rework is planned for a future v6 release.

![GRAVEN — hub room with gravity well](https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/docs/screenshots/Screenshot%20at%202026-09-13%2010-07-38.png)

![GRAVEN — tow the ring](https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/docs/screenshots/Screenshot%20at%202026-09-13%2010-05-15.png)

![GRAVEN — mass well survey log](https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/docs/screenshots/Screenshot%20at%202026-09-13%2010-09-45.png)

![IDE — GravenRooms Restore tables in Context Rail](https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/docs/screenshots/Screenshot%20at%202026-09-13%2009-36-43.png)

Full details: [RELEASE_NOTES_v5.5.0-beta1.md](https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_NOTES_v5.5.0-beta1.md)

### Documentation

- [Documentation Hub](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/DOCS.md)
- [Getting Started](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/guides/GET_STARTED.md)
- [Installation Guide](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/guides/INSTALLATION.md)
- **[Godot Programming Manual v3.0.0](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/GODOT_PROGRAMMING_MANUAL.md)** — Key Sections (links open in Code view and scroll/highlight the exact line):
  - [Chapter 1: Introduction](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/GODOT_PROGRAMMING_MANUAL.md?plain=1#L100)
  - [Chapter 40: Python Bridge](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/GODOT_PROGRAMMING_MANUAL.md?plain=1#L3926) (M7)
  - [Chapter 45: Narcea Vibe Code](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/GODOT_PROGRAMMING_MANUAL.md?plain=1#L4103) (M5)
  - [Chapter 49: Causal Chains](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/GODOT_PROGRAMMING_MANUAL.md?plain=1#L4232) (M6)
  - [Chapter 51: Exception Handling & Modern Syntax](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/GODOT_PROGRAMMING_MANUAL.md?plain=1#L4303) (M8)
  - **Note:** GitHub shows `.md` files in rendered **Preview** by default, where line-number links don't scroll. The links above use `?plain=1` to force **Code** view, where `#L<N>` reliably jumps to and highlights that line. For general reading, use the **Table of Contents** at the top of the manual instead.
- [Changelog](https://github.com/xgreenrx-star/VisualGasic/blob/main/CHANGELOG.md)
- [GRAVEN v6 design doc](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/proposals/GRAVEN_V6_FLAGSHIP.md)

### Downloads

> **Portable platform zips** (`VisualGasic_v*_linux_x86_64.zip` / `*_windows_x86_64.zip`) are **no longer provided** — they exceeded GitHub’s 2 GB limit. Install **Godot 4.6.1+**, then use a one-click installer, offline bundle, **Asset Library zip**, or minimal **addon zip**.

| Platform | Asset |
|----------|-------|
| **Linux** | `VisualGasic-Installer-v5.5.0-beta1-x86_64.AppImage` (recommended) |
| **Windows** | `VisualGasic-Installer-v5.5.0-beta1-x86_64.exe` (recommended) |
| **Offline** | `VisualGasic-Installer-Offline-v5.5.0-beta1-linux-x86_64.zip` · `VisualGasic-Installer-Offline-v5.5.0-beta1-windows-x86_64.zip` |
| **Asset Library** | `VisualGasic_AssetLibrary_v5.5.0-beta1.zip` · [store listing](https://store.godotengine.org/asset/visual-gasic/visual-gasic/) |
| **Manual (BYO Godot)** | `VisualGasic-v5.5.0-beta1.zip` — extract `addons/visual_gasic/` into your project |

**Requires Godot 4.6.1+** · Mark as **Pre-release**

**Try GRAVEN:** clone the repo → open `projects/vg_graven_slice/project.godot` → **F5** · **F1** dev terminal (warp rooms 1–17)

### What's Fixed

- ✅ AST `Restore` with string expressions — `LoadRoomMasses()` and dynamic labels work on tree-walk path
- ✅ `Shader.Param` / builtin namespace dispatch on AST fallback
- ✅ Relative `Include` resolution for nested `.vg` modules
- ✅ Include errors map to the correct source file and line

### Known Notes

- GRAVEN gameplay and room layout are **WIP** — grid maps remain from the pixel prototype; vector-first rework planned
- Python `int`↔`float` on bridge return paths — partial (decode path fixed, outgoing-arg typing still pending)
- Causal chain visual panel deferred to v6.1; text-mode analysis available in Code Navigator
