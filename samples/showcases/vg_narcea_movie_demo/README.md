# Narcea × Cursor Movie Demo

Scripted **Narcea panel** + **preview pane** (640×480, full frame visible). Disclaimer: real Cursor output, not a live IDE recording.

## Quick start

```bash
# Preview in editor (Space = play movie, Esc = quit)
# Open projects/vg_narcea_movie_demo/project.godot → F5

# Record frame-perfect video (~2–3 min)
scripts/record_narcea_movie_demo.sh
# → projects/vg_narcea_movie_demo/vg_narcea_movie.avi
# → vg_narcea_movie.mp4 (repo root, when ffmpeg installed)
```

## Segments

| # | Prompt | Preview app |
|---|--------|-------------|
| 1 | VB6 calculator form | `generated/calculator/` |
| 2 | Shader art reel (Beta Showcase shaders) | `generated/shader_art/` |
| 3 | 2D platformer (Godot + Kenney refs) | `generated/platformer/` |
| 4 | DOOM-style 3D maze | `generated/doom_maze/` |

Manifest timings: `movie_data/manifest.json`

## Real Cursor generation (optional)

Bundled apps and transcripts ship so recording works offline. To regenerate with **real Cursor Composer** API calls:

```bash
export CURSOR_API_KEY=your_key
scripts/narcea_movie_generate.sh
# or one segment:
scripts/narcea_movie_generate.sh --segment platformer
```

The agent runs with `cwd=<repo root>` and updates `generated/<segment>/` plus `movie_data/transcripts/<segment>.txt`.

**Requires:** `cursor-sdk` in `~/.config/visual_gasic/vg_cursor_venv` (AI Pair ⚙️ installer).

## Architecture

- `main.tscn` — IDE screenshot background (`movie_data/assets/ide_background.png`) + preview + Narcea overlay
- `narcea_movie_director.gd` — phase machine (title → prompt → refs → stream → apply → demo)
- `narcea_movie_ui.gd` — prompt/response overlay on the AI Pair region
- `narcea_movie_embed.gd` — SubViewport loader for generated scenes
- `movie_mode` = `OS.has_feature("movie")` — auto-starts and quits after end card

Generated apps set `autopilot` when embedded in SubViewport or in Movie Maker.

## Note on Ollama

This demo uses **Cursor (Composer)** for real generation, not Ollama. The movie UI always shows the Cursor provider badge.
