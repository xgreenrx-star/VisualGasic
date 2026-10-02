# Vector Crypt — design sketch

Working title for a **first-person vector puzzle** game in Visual Gasic (no custom art; `VGVectorCanvas2D` + wire/tile world + helmet HUD).

## Inspirations (tone, not IP)

| Source | What we borrow |
|--------|----------------|
| **Murderbot-adjacent** | Reluctant cyborg POV, corporate rescue rig, dry system voice, helmet utilitarian HUD |
| **Portal** | Test chambers, gravity/play with space, clear readable puzzles |
| **The Matrix** | Layers of control; “Overseer” / big-brother AI revealed slowly |
| **Stock helmet HUD refs** | Visor vignette, corner brackets, side goggle arcs, scan sweep, center reticle, corner status bars ([example layout](https://www.magnific.com/premium-vector/hud-helmet-view-vr-dashboard-futuristic-glasses-spaceship-cockpit-virtual-tech-digital-interface-viewfinder-scanner-frame-race-auto-navigation-game-ui-vector-illustration-ui-game-interface_57154297.htm)) |

## Core loop

1. **Open (Portal-style beat)** — alone in a **recovery vault**: sterile grey pod, **orange facility stripe**, sealed foot door, observation slot, ceiling light ramp + **PA panel**. No movement; fade from black; slow sit-up; then Overseer: *“Good morning. … &lt;name&gt;? … I'm glad you are finally awake. … I need your help.”* (`VoiceOver`: Piper → system TTS). Tone homage only — **Median / Overseer**, not Aperture IP.
2. **Puzzle-first** — gravity fields, portal pairs, switches (Portal-like + **Graven Slice**-style mass/gravity play in 2D vector; **3D flight** chambers later).
3. **Combat secondary** — mutated humans (AI bio-attack) as pressure; wireframe mutants, not a horde FPS.
4. **Narrative drip** — Overseer starts helpful; later HUD/voice contradict what you see (Matrix-style reveal).

## Layers (render order)

1. World — tiles / chambers (current corridor lookdev).
2. Entities — mutants, props (minimal wire models).
3. **Helmet HUD** — `HudHelmet.vg` (visor frame, reticle, bars, Overseer ticker); always on in first-person.

## HUD elements (implemented v0)

- Vignette + left/right goggle bezels  
- Corner brackets, scan line  
- Reticle (portal/gravity aim later)  
- Bars: SUIT, LINK, GRAV, PORT (puzzle hooks)  
- HDG tape from yaw  
- Overseer ticker (time-gated placeholder lines)

## Next steps (when returning to gameplay)

- Rename project if we outgrow “Crypt” (e.g. chamber codenames only in fiction).  
- Portal/gravity verbs on top of chamber graph.  
- Mutant wire mesh + telegraph, not horde combat.  
- Story flags driving Overseer text and HUD “LINK” integrity.
