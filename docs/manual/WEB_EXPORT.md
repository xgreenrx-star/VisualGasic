# HTML5 / Web export

Release builds and the Asset Library zip **include** Web WASM when produced via `scripts/build_release.sh` (see [PLATFORM_SUPPORT.md](PLATFORM_SUPPORT.md)).

Visual Gasic can run in the browser when the project includes a **Web (WASM) GDExtension** build and you export with Godot **4.6+** HTML5 templates.

Use the **standard (non-Mono) Godot editor** for Web export. The Mono/C# build cannot export to HTML5 in Godot 4.

## Status

| Item | Notes |
|------|--------|
| **Bytecode VM, UI, HTTP (`VGHttpRequest`)** | Supported in web builds (browser XHR in WASM; desktop uses `HTTPClient`) |
| **Editor addon in export** | Use `scripts/strip_tweak_overlay.py` before export (dev overlays removed) |
| **Asset Library zip (desktop `.so`/`.dll`)** | Does not include WASM; build web binaries from source or a release that ships them |
| **Not in web builds** | `Shell()`, `CreateObject()`, SQLite/ODBC, raw `VGSocket`, JIT tiers 2/3, Python bridge, `VGTask`, FFI, systray, IPC, process fork |

CORS applies to browser `fetch`/HTTP: APIs must allow your site origin (or use a proxy you control).

## One-time: Emscripten

**Pin the same Emscripten version Godot used for export templates** (4.6.1 → **4.0.20**). Building the GDExtension with `emsdk latest` (e.g. 6.x) produces WASM that loads forever on the Godot splash screen with no obvious error.

```bash
bash scripts/setup_emsdk.sh          # installs/activates 4.0.20
source thirdparty/emsdk/emsdk_env.sh   # each new shell — verify emcc reports 4.0.20
```

## Build WASM GDExtension

From the repo root (with `emcc` on `PATH`):

```bash
bash scripts/build_web_gdextension.sh
```

Outputs (also mirrored under `addons/visual_gasic/bin/`):

- `libvisualgasic.web.template_release.wasm32.nothreads.wasm`
- `libvisualgasic.web.template_debug.wasm32.nothreads.wasm`

`visual_gasic.gdextension` already maps `web.release.wasm32` / `web.debug.wasm32` to those files.

SCons flags: `platform=web target=template_release arch=wasm32 threads=no` (single-threaded export; no COOP/COEP requirement).

## Export a project

1. Install **Export templates** for your Godot version (Editor → Manage Export Templates).
2. Ensure the project’s `addons/visual_gasic/bin/` contains the WASM files above (symlink or copy from repo root).
3. Add a **Web** export preset (see `samples/apps/web_hello/export_presets.cfg`). Enable **Extensions Support** (`variant/extensions_support=true`) — required for the VG GDExtension WASM.
4. Export:

```bash
bash scripts/vg_make_web_export.sh samples/apps/web_hello Web build/web
```

The wrapper runs `strip_tweak_overlay.py`, then headless `--export-release`.

Serve the output folder over HTTP with **Cross-Origin-Opener-Policy**, **Cross-Origin-Embedder-Policy**, and **Cross-Origin-Resource-Policy** on every file (WASM/PCK/JS included). Godot enables `ensureCrossOriginIsolationHeaders` when GDExtension is used. From the repo:

```bash
python3 scripts/serve_web_export.py build/web/web_hello
```

Plain `python3 -m http.server` often leaves the export stuck on the Godot splash. Opening `index.html` via `file://` usually fails for WASM.

## Sample

`samples/apps/web_hello/` — minimal canvas UI + Open-Meteo HTTP GET (Climatist-style data fetch, browser-safe).

## Verify before export

```bash
bash scripts/verify_web_gdextension.sh
```

Web Publish in the editor runs the same check and strips dev overlay preloads automatically.

## Troubleshooting

- **Missing extension / load error** — Re-run `build_web_gdextension.sh`; confirm preset platform is Web and GDExtension paths match.
- **Link errors when building web** — Desktop-only sources are excluded in `SConstruct`; report regressions if a desktop API is referenced without `#ifndef VG_WEB_BUILD`.
- **HTTP fails in browser only** — Check CORS and HTTPS mixed-content rules. On HTML5, sync `VGHttpRequest` uses same-origin/CORS-friendly **XHR** from the extension (not `HTTPClient` polling). Do not enable Asyncify on the GDExtension WASM for HTTP—it breaks `loadDylibs` (WASM size).
- **Regression check** — After export: `bash scripts/run_web_hello_headless.sh` (Chrome + `serve_web_export.py`). CI runs the same via `ci_web_export_smoke.sh` when `VG_WEB_HEADLESS_VERIFY=1` (default).
