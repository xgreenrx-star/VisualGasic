# Climatist POC (James weather project)

Visual Gasic port of **Now** + **Pattern** + **Discussion (POC)** from [`scratch/James_Weather_Project.txt`](../../../scratch/James_Weather_Project.txt):

| James screen / item | POC status |
|---------------------|------------|
| **Now** — headline temp (HRRR CONUS / ECMWF elsewhere) | Yes |
| **Now** — next six hours (hourly precip % labeled as hourly) | Yes |
| **Now** — seven-day hi/lo + daily precip % | Yes |
| **Now** — NWS 12-hour period PoP | Yes — CONUS only |
| **Pattern** — 30-day temp vs 1991–2020 ERA5 normal (~25 km grid) | Yes — Open-Meteo archive |
| **Pattern** — soil 7–28 cm percentile (same calendar window) | Yes — archive daily mean |
| **Pattern** — US Drought Monitor | Missing — endpoint TBD, labeled on screen |
| **Pattern** — CPC outlooks + issue dates | Missing — MapServer TBD |
| **Pattern** — ECMWF ensemble tercile share | Missing — API TBD |
| **Discussion** — NWS Area Forecast Discussion (local WFO) | Yes — CONUS |
| **Discussion** — CPC 6–14 / monthly discussions | Missing — labeled |
| Settings (lat/lon) + fetch log | Yes |
| Detail / Record / learning | Not yet |

**Rules:** direct GET to Open-Meteo and NWS (no proxy). Missing sources are shown as failed/missing, not invented.

## Run

Open **`samples/apps/climatist_poc/project.godot`** in Godot 4.6+ with Visual Gasic enabled. **F5** to run (not the repo root — that project has no `Main.vg` game).

After editing `.vg` files, run **F5** again so scripts recompile; the Now title bar should read **“Now (Tab → Pattern)”**.

| Input | Action |
|-------|--------|
| **Click bottom bar** | Now / Pattern / Settings / Refresh (always works) |
| **1** / **2** / **3** / **4** | Jump to Now / Pattern / Discussion / Settings |
| **R** / **Enter** / **Space** | Refresh Now or Pattern (on that screen) |
| **P** / **Tab** / **Home** | Cycle Now → Pattern → Discussion → Settings |
| **Esc** | Back from Settings |
| **Arrows** | Nudge lat/lon in Settings |
| **Enter** (Settings) | Save settings + refresh |
| **Page Down** (Settings) | Backup fetch log to `user://climatist_fetch_backup.txt` |

## Web

HTML5 export works with Web WASM and `VGHttpRequest` (see [WEB_EXPORT.md](../../../docs/manual/WEB_EXPORT.md)). NWS may be unreliable in the browser because custom `User-Agent` is restricted; desktop is the reference for NWS.

## Files

Each `.vg` file starts with a header comment (James spec mapping, architecture, platform caveats). Section comments inside mark CONUS vs NWS vs Open-Meteo boundaries.

| File | Role |
|------|------|
| `WeatherApi.vg` | URLs, HTTP, Open-Meteo parse, NWS 12 h periods |
| `PatternApi.vg` | ERA5 archive Pattern fetches + temp/soil math |
| `ClimatistStore.vg` | `user://` settings + fetch audit log |
| `DiscussionApi.vg` | NWS AFD fetch + CPC missing block |
| `Main.vg` | Now + Pattern + Discussion + Settings UI (`_Draw`) |
