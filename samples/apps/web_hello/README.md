# Web Hello (HTML5 sample)

Minimal Visual Gasic project for Godot **Web** export: draws status text and fetches current weather from [Open-Meteo](https://open-meteo.com/) via `VGHttpRequest`.

## Setup

From the repo root:

```bash
bash scripts/setup_emsdk.sh
source thirdparty/emsdk/emsdk_env.sh
bash scripts/build_web_gdextension.sh
```

Ensure `addons/visual_gasic` is linked (this sample uses `addons/visual_gasic → ../../../../addons/visual_gasic`).

## Run in editor

Open `project.godot` in Godot 4.6+ with the Visual Gasic addon enabled.

**Scene note:** `Main.vg` must live on a **Node2D** (or other `CanvasItem`) so `_Draw` / `QueueRedraw` target the canvas. Do not use the form-style **VGASIC** child `Node` pattern here — that layout is for UI forms, not canvas games.

## Export

Install Web export templates, then:

```bash
bash scripts/vg_make_web_export.sh samples/apps/web_hello Web build/web
```

Serve `build/web/web_hello/` over HTTP and open `index.html`.

See [docs/manual/WEB_EXPORT.md](../../../docs/manual/WEB_EXPORT.md) for limitations (no `Shell`, no SQLite in WASM build, CORS, etc.).
