# Vector Crypt

First-person **vector** prototype for a **gravity / portal puzzle** game (Murderbot-adjacent cyborg HUD, Overseer AI, Portal-like chambers). Visual Gasic + Godot 4.6 — no bitmap art.

**Watch:** [Vector Crypt on YouTube](https://youtu.be/ntpOTNflE_M)

## How to run

1. Open this folder in Godot **4.6.1+** with Visual Gasic enabled.
2. Run **Main.tscn** (F5).
3. Controls: **WASD** move · mouse look · **Space** jump · **Q/E** strafe · **Esc** pause. **Enter** during the intro skips to the corridor.

Optional: install [Piper](https://github.com/rhasspy/piper) + a voice under `~/.local/share/piper/voices/` for Overseer TTS.

## How the pieces fit together (beginner map)

```
Main.tscn
  VectorCrypt          ← Main.vg  (game logic, camera, level, draws)
    DepthView          ← depth_view.gd  (3D SubViewport for neon walls)
    VectorMonitor      ← vector_monitor.gdshader  (CRT bloom over everything)
    Steps              ← steps.gd  (footstep beeps)
  Autoload VoiceOver   ← voice_over.gd  (TTS)
```

| File | Role |
|------|------|
| `Main.vg` | Heart of the demo: phases, input, collision, `BuildFacility`, each-frame draw |
| `HudHelmet.vg` | 2D visor / captions drawn on top |
| `IntroAwake.vg` | Phase-0 hospital bed wake-up |
| `WallPatterns.vg` | `NeonFace` / `NeonStrip` — black fill + neon edge coats |
| `depth_view.gd` | Shows `BuildDepthMesh` result with a real depth buffer |
| `vector_depth.gdshader` | Material on that mesh (emit neon, keep fills black) |
| `vector_monitor.gdshader` | Full-screen vector-monitor look |

**Each frame (corridor phase), simplified:**

1. Move the player (`TickLook` / `TickBody`).
2. Update doors / puzzles (`TickLevel`).
3. Ensure static neon geometry is recorded (`BuildWorld` → `BuildFacility`).
4. Draw moving bits (`DrawLevelDynamics`).
5. `PresentDepth` → mesh into `DepthView`.
6. Draw HUD + gun in 2D on top.

Start reading at the big comment block at the top of `Main.vg`.

## Other notes

- East of the vault, through the glass, is the **garden court** (plants, fountain, waterfall).
- Design notes: [DESIGN.md](DESIGN.md).
- Separate from **Vector Fathom** (`samples/apps/vector_fathom`).
