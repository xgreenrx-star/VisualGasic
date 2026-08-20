# Narcea video demo — Asteroids (2-turn script)

Use this script for **test runs** and the **recorded demo**. Prompts are word-for-word in [`prompts/asteroids_create.txt`](prompts/asteroids_create.txt) and [`prompts/asteroids_iterate.txt`](prompts/asteroids_iterate.txt).

## Why Asteroids (not Pac-Man)

- More motion on screen (rotate, thrust, shoot, split rocks)
- Shows **web reference chips** (`Use Asteroids as reference`)
- Clean **iterate** beat (UFO + hyperspace) without maze/pathfinding fragility

## Pre-flight

1. Open `projects/vg_narcea_test` in Godot with Visual Gasic enabled.
2. Delete any stale demo folder: `res://ai_projects/asteroids_demo/` (or rename for backup).
3. AI Pair → pick **Gemini** (or your best provider from the matrix).
4. Optional: Project Settings → **vg/ai/allow_web_fetch** = on.

## Turn 1 — Create (video ~0:00–0:45)

1. Paste the create prompt (or type naturally and tighten):

   ```text
   cat tests/narcea_golden/prompts/asteroids_create.txt
   ```

2. When the chip appears, click **Use Asteroids as reference** (Wikipedia fetch).
3. **Send** → wait for `vg-project-spec` → **Apply**.
4. Click **▶ Run** — ship should thrust, shoot, and asteroids should move/split.

**Pass criteria:** game window opens (not a blank editor), no immediate SCRIPT ERROR in AI Pair output.

## Turn 2 — Iterate (video ~0:45–1:30)

1. Paste [`prompts/asteroids_iterate.txt`](prompts/asteroids_iterate.txt).
2. **Send** → **Apply** → **▶ Run** again.

**Pass criteria:** same project folder updated; UFO and Shift hyperspace visible in gameplay or code.

## Automated test runs

### Live Gemini (full HTTP, 2 turns)

```bash
cd /path/to/VisualGasic
NARCEA_LIVE=1 NARCEA_GEMINI_KEY=your_key \
  ./Godot_v4.6.1-stable_linux.x86_64 --headless --path projects/vg_narcea_test \
  -s tests/test_narcea_live_asteroids_iterate.gd
```

Optional: `NARCEA_GEMINI_MODEL=gemini-2.0-flash`

### Live suite — create turn only

```bash
NARCEA_LIVE=1 NARCEA_LIVE_SKIP_API=0 NARCEA_SCENARIO=asteroids_2d \
  NARCEA_PROVIDER=gemini NARCEA_GEMINI_KEY=your_key \
  bash scripts/run_narcea_live_suite.sh
```

### Offline intent smoke (no HTTP)

```bash
./Godot_v4.6.1-stable_linux.x86_64 --headless --path projects/vg_narcea_test \
  -s tests/test_narcea_live_asteroids_iterate.gd
```

(Skips live calls unless `NARCEA_LIVE=1`.)

## Video shot list (~90–120 s)

| Time | Shot |
|------|------|
| 0:00 | Type prompt; **Use Asteroids as reference** chip |
| 0:15 | Reference attached row; Send |
| 0:30 | Apply dialog → Apply |
| 0:40 | **▶ Run** — gameplay |
| 0:55 | Iterate prompt (UFO + hyperspace) |
| 1:10 | Apply → Run again |
| 1:25 | Optional: Explain Last Error or 🌐 Ref if you want a recovery beat |

## Files

| File | Purpose |
|------|---------|
| [`prompts/asteroids_create.txt`](prompts/asteroids_create.txt) | Turn 1 — copy into AI Pair |
| [`prompts/asteroids_iterate.txt`](prompts/asteroids_iterate.txt) | Turn 2 — copy into AI Pair |
| [`rubrics/asteroids_2d.json`](rubrics/asteroids_2d.json) | Live suite rubric (turn 1) |
| [`rubrics/asteroids_iterate.json`](rubrics/asteroids_iterate.json) | Multi-turn rubric |
| [`../test_narcea_live_asteroids_iterate.gd`](../test_narcea_live_asteroids_iterate.gd) | Headless live dry-run |

## After a good run

Record only after **two clean back-to-back runs** (create + iterate, both Run OK).
