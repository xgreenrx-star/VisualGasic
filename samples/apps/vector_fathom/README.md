# Vector Fathom

**Vector Fathom** is a Visual Gasic HTML5 demo: pseudo-3D wireframe racing on the **Neon Ring** circuit, with a **cockpit** view and **top-down** map (`V` to toggle). Flow: **splash → track → car → race → garage** (engine / tires / turbo upgrades between runs). Traffic cars and UFOs are placeholders; **Skyline City** and **Coastal Loop** tracks are reserved for future scenery (buildings, coast, sun/moon/stars).

## Setup

From the repo root:

```bash
bash scripts/setup_emsdk.sh
source thirdparty/emsdk/emsdk_env.sh
bash scripts/build_web_gdextension.sh
```

Link the addon (same as [web_hello](../web_hello/README.md)):

```bash
ln -sf ../../../../addons/visual_gasic samples/apps/vector_fathom/addons/visual_gasic
```

Open `project.godot` in Godot 4.6+ with Visual Gasic enabled.

## Layout

| File | Role |
|------|------|
| `VectorFathom.vg` | Main loop, input, canvases |
| `scripts/Course.vg` | Neon Ring segment table + track sampling (top-down / lap) |
| `scripts/RoadProject.vg` | Cockpit projection math |
| `VectorFathom.vg` (bottom) | **Editable `RoadCurveData:` Data** — 128 curve integers |
| `scripts/RoadDraw.vg` | Cockpit road + top-down wireframe |
| `scripts/Entities.vg` | Cars / UFOs — extend spawns and behavior here |
| `scripts/GameFlow.vg` | Splash, track/car select, garage menus |
| `scripts/Garage.vg` | Credits + engine / tires / turbo levels |
| `main.tscn` | Background + optional post-process layer |

## Controls

- **W / Up** — throttle  
- **S / Down** — brake  
- **A D / Left Right** — steer  
- **V** — cockpit ↔ top-down  

## Web export

```bash
bash scripts/vg_make_web_export.sh samples/apps/vector_fathom Web build/web
python3 scripts/serve_web_export.py build/web/vector_fathom
```

Open `http://127.0.0.1:8080/index.html` (use the COOP/COEP helper; plain `python -m http.server` may hang on WASM GDExtension).

See [docs/manual/WEB_EXPORT.md](../../../docs/manual/WEB_EXPORT.md).

## Extending

- **Cockpit road shape:** edit the 128 integers under `RoadCurveData:` at the **bottom of `VectorFathom.vg`**. Positive = bend right, negative = left, `0` = straight. Keep exactly **128** values or `Read` raises **Runtime Error 5 (Out of Data)**. `Restore RoadCurveData` runs once in `InitCockpitRoadData()` — do not call `Read` from multiple imported modules on the same tape.
- **Neon Ring (top-down / distance):** edit `InitNeonRingCourse()` in `scripts/Course.vg`.
- **More opponents:** `_SpawnCar` / `_SpawnUfo` in `scripts/Entities.vg`.
- **Career upgrades:** pattern similar to arcade titles (e.g. [Grand Prix Hero](https://sonsaur.com/g/grand-prix-hero) — engine / tires / turbo between races; [Super Arcade Racing](https://play.google.com/store/apps/details?id=com.outofthebit.superarcaderacing) — exhaust, brakes, tires, engine).
- **Track variety (planned):** city skyline with wireframe buildings, coastal loops, night/day with sun and moon, tunnels and elevation — see locked entries in track select.

## See also

- **[Elite Wire Slice](../../games/elite_wire_slice/)** — minimal Elite-style combat view using `DrawRawWireMesh` (trader + asteroids, not Oolite/TNK ports).
