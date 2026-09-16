# gdsfx — disabled

This plugin's runtime depends on three GDScript files that were never
committed to this repository:

  - gdsfx_dsp.gd          (Bfxr-style DSP engine)
  - gdsfx_pd.gd           (PureData-style functional DSP helpers)
  - gdsfx_pd_modules.gd   (PD module presets)

Without them the remaining files (gdsfx_dock.gd, gdsfx_synth.gd,
gdsfx_pd_compile.gd, gdsfx_footsteppr.gd, gdsfx_transfxr.gd) fail
to parse and pollute the editor log.

The directory was renamed from `gdsfx/` to `_disabled.gdsfx/` so
Godot's plugin manager (which scans for `plugins/<name>/plugin.cfg`)
does not discover it. The "🔊 VGSFX" toolbar button is consequently
hidden.

To re-enable: write the three missing files (port from bfxr2 or
similar), then `mv _disabled.gdsfx gdsfx`.
