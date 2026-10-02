# Vector Crypt

First-person **vector** prototype for a **gravity / portal puzzle** game (Murderbot-adjacent cyborg HUD, Overseer AI, Portal-like chambers). Visual Gasic + Godot 4.6 — no bitmap art.

- Run **Main.tscn** — opens in a **Portal-style recovery vault** (fade in, sealed pod, PA voice). **Enter** after ~8s skips to the corridor sandbox; **WASD** / **A/D** there.
- TTS: install [Piper](https://github.com/rhasspy/piper) and a voice under `~/.local/share/piper/voices/` (e.g. `en_US-amy-medium.onnx`) for best quality.
- Helmet HUD: `HudHelmet.vg` (visor frame, reticle, status bars, ticker).
- East of the vault, through the glass, is the **garden court**: open wire floor, plants, a fountain, and a waterfall. The whole view sits under `vector_monitor.gdshader` (bloom plus a vector-monitor flicker).
- Design notes: [DESIGN.md](DESIGN.md).

Separate from **Vector Fathom** (`samples/apps/vector_fathom`).
