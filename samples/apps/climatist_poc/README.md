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

**Follow-up roadmap:** [`NEXT_STEPS.md`](NEXT_STEPS.md) (Pattern/CPC/USDM, Detail, Record, Settings — for the next contributor).  
**Reference implementation:** [Agent139/climatist](https://github.com/Agent139/climatist) (full JS app; use its `src/` and docs when extending the POC).

## Run

Open **`samples/apps/climatist_poc/project.godot`** in Godot 4.6+ with Visual Gasic enabled. **F5** to run (not the repo root — that project has no `Main.vg` game).

After editing `.vg` files, run **F5** again so scripts recompile; the Now title bar should read **“Now (Tab, then Pattern)”** (ASCII on web).

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

## Web (secondary — on site under `/play/climatist/`)

From repo root (needs Emscripten + Godot 4.6 **non-Mono** export templates once):

```bash
bash scripts/publish_climatist_web_to_website.sh
python3 scripts/serve_web_export.py website/temporary-placeholder-site/play/climatist
```

Open `http://127.0.0.1:8080/index.html`. Commit `website/temporary-placeholder-site/play/climatist/` when you want GitHub Pages to update.

Open-Meteo (Now + Pattern) uses browser XHR. **NWS** (12 h rain + Discussion AFD) may fail in the browser; desktop F5 remains the reference. See [WEB_EXPORT.md](../../../docs/manual/WEB_EXPORT.md).

## Files

Each `.vg` file starts with a header comment (James spec mapping, architecture, platform caveats). Section comments inside mark CONUS vs NWS vs Open-Meteo boundaries.

| File | Role |
|------|------|
| `WeatherApi.vg` | URLs, HTTP, Open-Meteo parse, NWS 12 h periods |
| `PatternApi.vg` | ERA5 archive Pattern fetches + temp/soil math |
| `ClimatistStore.vg` | `user://` settings + fetch audit log |
| `DiscussionApi.vg` | NWS AFD fetch + CPC missing block |
| `Main.vg` | Now + Pattern + Discussion + Settings UI (`_Draw`) |
