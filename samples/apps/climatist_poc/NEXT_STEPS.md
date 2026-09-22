# Climatist POC — follow-up work

**Status (Sep 2026):** Now, Pattern (ERA5 temp/soil + timer load), Discussion (NWS AFD), Settings + fetch log. HTML5 demo at site `/play/climatist/` (secondary; desktop F5 is reference).

**Spec:** [`scratch/James_Weather_Project.txt`](../../../scratch/James_Weather_Project.txt)  
**Architecture map:** [`README.md`](README.md) (file roles + James table)

Rules for all new work: direct GET to public APIs (no proxy); missing sources stay **missing/failed on screen**, never invented. Fix VG engine bugs in `src/` + tests — no workarounds in `.vg`.

---

## Ordered steps (suggested)

### 1. Pattern — remaining sources

| Source | James requirement | Suggested approach |
|--------|-------------------|-------------------|
| US Drought Monitor | Category at point | Find stable public GeoJSON/API; add `PatternApi` fetch + parse; extend `patternMissingBlock` until wired |
| CPC outlooks | 6–10 / 8–14 / monthly / seasonal + issue dates | CPC MapServer or API (document URL policy); polygon lookup from lat/lon |
| ECMWF ensemble terciles | Share below / in / above climatology for outlook window | Open-Meteo or ECMWF open data — label as raw model distribution |

**Touch:** `PatternApi.vg`, `Main.vg` (`DrawPattern`, `PatternLoadTick` if new HTTP), `ClimatistStore.LogFetch`.  
**Test:** extend `scripts/run_climatist_headless.sh` / `test_pattern_parse.vg` with offline JSON fixtures where possible.

### 2. Discussion — CPC discussions

Wire CPC 6–14 day and monthly outlook **text** (not just NWS AFD).  
**Touch:** `DiscussionApi.vg` (`MissingSourcesBlock`, fetch helpers), `Main.vg` `DrawDiscussion`.

### 3. Detail screen (new)

James: three global models side by side, IFS ensemble mean/spread, NWS grid, Open-Meteo blend reference, ECMWF run-to-run table.  
**Touch:** new module(s) e.g. `DetailApi.vg`, new `SCREEN_DETAIL` in `Main.vg`, nav button + key.

### 4. Record screen (new)

James: verification ledger — log forecast bodies, ingest nearest NWS station reports, skill tables, daily hi/lo and 12 h rain scoring.  
**Touch:** extend `ClimatistStore.vg` (or `RecordStore.vg`), folding/archival per James spec (60-day fold, packed days).  
**Note:** POC today only logs fetch metadata (URL, status, byte count), not full forecast bodies.

### 5. Settings polish

Location search or opt-in GPS, units, backup **import**, re-fold archive button.  
**Touch:** `ClimatistStore.vg`, `Main.vg` `DrawSettings` / input handlers.

### 6. Web export (optional maintenance)

- Republish: `bash scripts/publish_climatist_web_to_website.sh` then commit `website/temporary-placeholder-site/play/climatist/`.
- NWS User-Agent often fails in browser; Open-Meteo + Pattern archive usually work.
- First load ~45 MB WASM — COI service worker required on GitHub Pages (`patch_godot_web_github_pages.py`).

### 7. Explicitly later (James “aiming to build”)

Confidence indicator, learning/correction loop, UI consolidation, authored explainers, installable PWA — **inactive** until Record + enough verified days exist.

---

## Verification before merge

```bash
# Desktop: open project.godot, F5
scripts/run_climatist_headless.sh

# After addon GDScript edits (if any)
scripts/ci_smoke.sh projects/vg_narcea_test
```

---

## Handoff notes

- Pattern climatology: **one HTTP per year** 1991–2020 in `PatternLoadTick` (do not block main thread with 30+ sync calls).
- NWS products: use `@id` URL from `@graph`, not bare UUID (`DiscussionApi.NwsProductFetchUrl`).
- Narcea context: `addons/visual_gasic/vg_ai_narcea.gd` (climatist paragraph).
