# VG Speed Race

Side-by-side Visual Gasic (`.vg`) vs GDScript (`.gd`) races for particles,
arithmetic, array scans, dictionary reads, branching, string building, and
function calls.

## Fair run (this is the important part)

| How you launch | Window may say `(DEBUG)`? | Script debugger? | Fair race? |
|----------------|---------------------------:|------------------:|:----------:|
| **Project Manager → Run** | often yes | **no** | **yes** |
| **`./scripts/run_speed_race.sh`** | often yes | **no** | **yes** |
| **Editor Play / F5 / Ctrl+F5** | yes | **usually yes** | **no** |

`(DEBUG)` in the title only means you are using Godot’s **debug/editor binary**.
It does **not** mean the script debugger is off. **Ctrl+F5 does not remove
`(DEBUG)`** and often still leaves the debugger attached when the project is
open for editing — that is why VG looks slow in the editor but fast from the
Project Manager.

```bash
# from Visual Gasic repo root — recommended
./scripts/run_speed_race.sh
```

Or: open Godot → **Project Manager** (do not open the project for edit) →
**VG Speed Race** → **Run**.

The in-game banner turns **red** when `EngineDebugger.is_active()` is true.

## What to click for a clear VG win

1. **Budget** race  
2. **1 · Calls** (not Inline)  
3. **N=500 ★**  
4. Watch the **green** bar pull ahead  

Inline particles + size 3k is a near-tie / noisy — that is expected.

Use the **Race** selector to switch between workloads. **Calls / Inline** is
available for the particle and function-call races. **Work size** scales each
batch; each selected race keeps the VG and GDScript operations matched.

## About and published results

The **About & results** button explains the live race workloads and shows the
repository's latest VG/GDScript VM-gap results alongside the dated, published
three-language compute and drawing suites. The live race itself compares VG
with GDScript; C++ results are from separate benchmark workloads and are
labeled with their source dates and units. Drawing benchmarks remain separate
because they measure rendered workloads rather than script-side CPU time.

## Headless smoke

```bash
godot --headless --path samples/apps/vg_speed_race --audio-driver Dummy \
  --script res://run_headless_race.gd
godot --headless --path samples/apps/vg_speed_race --audio-driver Dummy \
  --script res://test_workload_races.gd
godot --headless --path samples/apps/vg_speed_race --audio-driver Dummy \
  --script res://test_about_window.gd
```
