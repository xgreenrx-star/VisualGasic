# Platform support (v6.0 target)

Visual Gasic ships **GDExtension binaries** per platform. Export/runtime behavior follows **Godot 4.6+** for each target.

## Godot 4.7.2 validation

The existing Linux x86_64 editor and template_debug extensions load on
`4.7.2.stable.official.ed1daf0bf` without rebuilding or changing the extension's
minimum version. The language differential suite passed 210 fixtures after
updating GDScript `SceneTree._process()` callbacks to return `bool`.

This is **runtime compatibility evidence, not blanket editor/export certification**.
Cold-import and debugger-shutdown concerns remain, and several samples already
fail on 4.6.1. Windows, macOS, Web and mobile exports were not tested in this
upgrade audit. See the [full report and evidence](../compatibility/GODOT_4_7_2.md).

| Platform | GDExtension in release zip | Typical use |
|----------|----------------------------|-------------|
| **Linux** (x86_64) | `.so` editor + template_debug + template_release | Editor + desktop export |
| **Windows** (x86_64) | `.dll` | Desktop export |
| **macOS** | `.framework` (universal when built on macOS) | Desktop export |
| **Web** (HTML5) | `.wasm` (single-thread / `nothreads`) | Browser export via Godot Web preset |
| **Android** | Not in `visual_gasic.gdextension` yet | Code exists (`VGAndroidBridge`); release packaging TBD |

## Web (HTML5)

**User flow (target, same idea as desktop):**

1. Install Visual Gasic (Asset Library or release zip) — includes **Web WASM**.
2. Use **standard Godot** (not Mono) with **Web export templates** installed.
3. Export project → Web, or use **Web Publish** in the editor.

**Build from source:** [WEB_EXPORT.md](WEB_EXPORT.md)

**Supported on Web (test focus for v6.0):** bytecode VM, UI/`_Draw`, timers, signals, `VGHttpRequest`, Godot `user://` I/O, `JS.*` / JavaScriptBridge where Godot allows.

**Not on Web (by design, like most browser games):** `Shell()`, COM/`CreateObject()`, ODBC, raw `VGSocket`, FFI, embedded Python, `VGTask`/JIT tiers, systray, IPC, SQLite (`VGDatabase`) in current WASM build.

## CI

- **WASM build:** `.github/workflows/build-web-gdextension.yml`
- **Export smoke:** `scripts/ci_web_export_smoke.sh` (WASM + export `samples/apps/web_hello`)

## Release

`scripts/build_release.sh` builds Web WASM (unless `VG_SKIP_WEB_BUILD=1`).  
`scripts/build_asset_library_zip.sh` **requires** release Web WASM in `addons/visual_gasic/bin/`.
