# Working Nodes — Trigger Showcase

A minimal `.wnodes` graph demonstrating 6 distinct trigger types in one linear chain.

## File

[trigger_showcase.wnodes](trigger_showcase.wnodes)

## What it shows

```
On Start  →  Spawn  →  Move  →  Rotate  →  Color  →  Pulse  →  Shake
            (group 1)  (right) (180°)   (magenta) (red flash) (camera)
```

Six trigger types, each one of a different category:

| Trigger        | Category   | What it does                                  |
|----------------|------------|-----------------------------------------------|
| `spawn`        | Lifecycle  | Activates Group 1 (Box A)                     |
| `move`         | Transform  | Slides the group 200 px right over 1.0 s     |
| `rotate`       | Transform  | Spins it 180° over 0.8 s                      |
| `color_trigger`| Visual     | Tints color-channel 1 to magenta              |
| `pulse`        | Visual     | Brief red flash (fade-in / hold / fade-out)   |
| `shake`        | Camera     | Shakes the camera for 0.6 s                   |

## How to run

1. Copy `trigger_showcase.wnodes` into any VisualGasic project (e.g. `test_proj/`).
2. Open the **Working Nodes** panel.
3. Use **File → Open…** and select the file.
4. Press **F5** (or click **▶ Run 2D**).
5. You should see Box A spawn, slide right, spin, change color, flash, and the
   view shakes briefly at the end.

## Why this exists

Working Nodes was end-to-end functional but had no discoverable example file
under `demos/`. This is the smallest graph that exercises five different runtime
subsystems (`WN_Spawn`, `WN_Move`, `WN_Rotate`, `WN_ColorTrigger`, `WN_Pulse`,
`WN_Shake`) and reads top-to-bottom in 30 seconds.

For a longer, real-game example see [`demo/demo_platformer.wnodes`](../../demo/demo_platformer.wnodes).
