# Climatist POC (James weather project)

Minimal **Visual Gasic** proof for the [Climatist](https://github.com/) direction described in `scratch/James_Weather_Project.txt`:

- **Direct GET** to [Open-Meteo](https://open-meteo.com/) from the client (same rule as James: no proxy).
- **“Now” slice only:** current `temperature_2m`, WMO `weather_code`, humidity, and today’s daily max/min + precip probability.
- **No** ledger, NWS grid, Pattern/Discussion screens, storage, or styling pass yet.

## Run

Open `project.godot` in Godot 4.6+ with Visual Gasic enabled. Press **Enter** or **Page Down** to refresh.

Edit default coordinates in `Main.vg` (`SiteLat` / `SiteLon` in `_Ready`).

## Web

HTML5 export works once the project has Web WASM in `addons/visual_gasic/bin/` (see [docs/manual/WEB_EXPORT.md](../../../docs/manual/WEB_EXPORT.md)). Open-Meteo allows browser CORS; full Climatist still needs many more APIs and on-device storage.

## Files

| File | Role |
|------|------|
| `WeatherApi.vg` | URL builder, `VGHttpRequest` GET, tiny JSON number parser |
| `Main.vg` | UI (`_Draw`) + refresh |
