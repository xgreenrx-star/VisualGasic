# VG GPS (sample)

Visual Gasic **client** for place search, driving routes with **avoid zones**, OSM **hazards**, and handoff to **OsmAnd** (or a browser maps URL).

This is not a port of OsmAnd/Organic Maps. VG owns UI + orchestration; open services do the heavy work.

## Stack

| Piece | Source | Role |
|-------|--------|------|
| Place search | [Photon](https://photon.komoot.io/) (Komoot / OSM) | Geocode typed queries |
| Routing + avoid | [Valhalla](https://valhalla1.openstreetmap.de/) public demo | `exclude_polygons` around avoid points |
| Hazards | [Overpass](https://overpass-api.de/) OSM tags | `highway=speed_camera`, `hazard=*`, `enforcement=*` |
| Turn-by-turn UI | OsmAnd (installed) or browser | `VGAndroidBridge.OpenUrl` → `osmand.net/map?end=…` |
| Device GPS | `GPS.Lat` / `GPS.Lng` + `Permission.Request("location")` | Android; desktop falls back to NYC |

**Not included:** live Waze “police ahead.” That feed is not a public API. DEMO hazards appear when Overpass returns nothing so Avoid still works.

## Run

1. Open `samples/apps/vg_gps/project.godot` in Godot 4.6.1+ with Visual Gasic enabled.
2. Press F5.
3. **Search** → pick Use #1/#2/#3 → **Route** → **Hazards** → select with **Haz </>** → **Avoid #** (re-routes) → **Navigate (OsmAnd)**.

Also: **Avoid mid-route** adds a Valhalla exclude box halfway to the destination; **Clear avoids** resets.

## Android

- Grant location when prompted.
- Install [OsmAnd](https://osmand.net/) for the best Navigate handoff; otherwise the URL opens in a browser.
- Export as an Android APK from Godot as usual (VG Android plugin / GPS namespace).

## Files

- `Main.vg` — UI, map sketch, buttons
- `PhotonSearch.vg` — geocoder
- `ValhallaRoute.vg` — route JSON, polyline decode, avoid polygons
- `Hazards.vg` — Overpass + DEMO seed
- `HttpUtil.vg` / `UrlUtil.vg` — HTTP + encoding

## Limits (honest)

- Public Photon / Valhalla / Overpass rate limits — fine for demos, not a product CDN.
- Map panel is a sketched polyline (no MapLibre tiles yet).
- OsmAnd Intent AIDL (markers, silent nav) can replace the HTTPS handoff later via Android plugin work.
- Self-host Valhalla + Photon for production and ToS control.

## VG notes

- **`Import` is not transitive** — `Main.vg` must list `HttpUtil`, `UrlUtil`, `PhotonSearch`, `ValhallaRoute`, `Hazards`.

## Test

```bash
./Godot_v4.6.1-stable_mono_linux.x86_64 --path samples/apps/vg_gps --headless \
  -s res://run_headless_vg_test.gd res://test_vg_gps_apis.vg
```

Expect `PASS vg_gps_apis` (Photon + Valhalla with one avoid polygon).
