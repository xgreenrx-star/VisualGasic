# Circuit Breaker (VG showcase)

Minimal **roguelite trace runner** for Visual Gasic 6: vector art only, gameplay in `.vg`.

## Fantasy

You are a probe on a live circuit board. **SIGNAL** is your battery — it drains constantly while you move along the **blue bus**. Reach the **goal pin** before SIGNAL hits zero.

## Loop

| Element | Role |
|--------|------|
| **Blue trace** | Walkable path (WASD / arrows, hold to chain steps). |
| **SIGNAL bar** | Timer / HP; empty = **FUSED** (death). |
| **Resistor pickup** (north branch) | Optional zigzag symbol in the side room; slows drain and refills signal. |
| **SHORT** (red spark on vertical shortcut) | Environmental hazard — pulses and **moves** along the choke wire; touch = **FUSED**, nearby = extra drain. |
| **GOAL PIN** (south-east) | Win when you step on it with signal left → **PIN LOCKED**. |

There are no walking “enemies” — only the moving short-circuit hazard and the signal clock.

## Files

- `Main.vg` — scene root, input, `_Process`
- `scripts/Play.vg` — movement, signal, pickups, hazard
- `scripts/Grid.vg` — demo layout (prefab before procgen)
- `scripts/Render.vg` — static board + FX/HUD layers

Run: open this folder in Godot (VG plugin enabled), F5 `main.tscn`.
