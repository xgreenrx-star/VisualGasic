# VG IDE shell & Form Designer — experimental (Alpha)

**Status (2026):** The **Visual Gasic standalone IDE layout** (main **Visual Gasic IDE** screen, VB6-style docked Toolbox/Project Explorer, embedded form canvas, and **View → Code** center stack) and the **legacy Form Designer** entry point are **experimental Alpha**. They are **not** on the v6.0 stable (EOY) critical path.

## What ships for v6.0

| Surface | Status |
|--------|--------|
| Godot **Script** editor + `.vg` tabs | **Supported** — autocomplete, Code Navigator, native Enter/indent, dual-buffer sync |
| **UI Forms** (2D viewport placement) | **Experimental** — opt-in via `vg/plugins/ui_forms` |
| Floating **VG Help**, **Properties**, **Toolbox**, **AI Pair** panels | **Supported** on Godot 2D/3D/Script screens |
| **Visual Gasic IDE** main screen + legacy **Form Designer** plugin | **Alpha** — `vg/enable_experimental_plugins` |

Focus until **VG 6.0 stable** is **language quality** and **Godot editor integration** (Navigator, Narcea, debugging, scene editing). Do not expect the standalone VB6 shell or legacy form canvas to reach production parity by EOY.

## VGasic workspace (default)

Click **VGasic** on the top toolbar. By default (without `vg/enable_experimental_plugins`) this **does not** open the legacy full-screen form shell. It tiles floating panels across the **center editor** (between Godot docks):

**VG Help** · **VG Code Editor** · **Project Explorer** · **Toolbox** · **Properties**

The layout tracks the Script editor area and resize. Save or reset it under **Project → VGasic Tools → Save VG Window Layout** / **Reset VG Window Layout to Default** (stored in Editor Settings under `visual_gasic/workspace/*`).

## Legacy Alpha IDE shell (experimental)

1. **Project → Project Settings → Vg → Enable Experimental Plugins** (`vg/enable_experimental_plugins`) = **On**
2. Optional: **Project → Tools → Toggle VG IDE Layout** (VB6 dock mode)
3. Open the **VGasic** main-screen tab (legacy) — the embedded form/canvas shell replaces the floating workspace. A yellow **EXPERIMENTAL** banner appears at the top of that shell.

Without experimental plugins, the Form Designer sub-plugin stays **registered but not loaded** (see `addons/visual_gasic/vg_plugin_manager.gd`).

## Legacy Form Designer vs UI Forms

| Component | Location | Intent |
|-----------|----------|--------|
| **`form_designer/`** sub-plugin | `addons/visual_gasic/plugins/form_designer/` | Legacy Alpha entry; opens host `_show_form_view()` |
| **`ui_forms/`** sub-plugin | `addons/visual_gasic/plugins/ui_forms/` | Forward path — design on Godot’s **2D** viewport |

**Standalone repo:** Form Designer **extraction to a separate repository is planned** (see root `README.md` “Deferred”). There is **no** separate public Form Designer repo under the VisualGasic org yet; the source of truth remains this monorepo until extraction lands.

## Floating VG Code Editor (Godot Script tab)

When you prefer the full **VG Code Editor** (Context Rail, bottom tabs, VB6 nav bar) while staying on Godot’s **Script** screen:

**Project → Project Settings → Vg → Editor → Floating Vg Code Editor On Script** (`vg/editor/floating_vg_code_editor_on_script`) = **On**

Opening a `.vg` in the Script editor shows the embedded editor in a **floating panel** over the script area (same pattern as VG Help and AI Pair). Geometry is saved in **Editor Settings** under `visual_gasic/code_float/*`.

**Multi-monitor / free placement:** **Vg → Editor → Floating Panels Allow Extended Bounds** (`vg/editor/floating_panels_allow_extended_bounds`) = **On** (default) disables clamping VG floats to the inner editor rect so you can park panels at the edge of a large or multi-monitor desktop. Panels remain **children of the Godot editor window**; moving Godot to another display moves VG floats with it. Fully detached OS windows are a possible future step.

## Related docs

- [ide_tools.md](ide_tools.md) — active Godot integration tools
- [CODE_EDITOR.md](CODE_EDITOR.md) — embedded editor features
- [plugins/README.md](../../addons/visual_gasic/plugins/README.md) — sub-plugin status table
