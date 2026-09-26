# Facebook post — QB classic coders

Use with screenshots from `samples/showcases/qb_abc_showcase/` (main menu, **`.`** classic mode gallery, Space Invaders / Breakout / Nibbles on `SCREEN 13`). Attach 3–5 images. When the release is live, link the **GitHub Releases** page for Visual Gasic (AppImage / Windows installer as published).

---

**Post text (copy/edit):**

Remember `SCREEN 13`, `PSET`, and `LINE` until the monitor glowed?

**Visual Gasic’s classic QuickBASIC integration ships in the release going up this weekend.** Same repo you’ve been watching — download the installer when it’s on GitHub Releases (free, open source). The feature set for this lane is **mostly locked** now; we’ll still take **reasonable** requests (missing command, broken port step, doc gap), but we’re not re‑inventing the roadmap every week.

**What it’s for**

Visual Gasic is **BASIC on Godot 4** — export, scenes, modern tooling — with an optional **QB-style framebuffer** so classic game logic can live in `.vg` without faking DOS. It’s an **on‑ramp for QBasic / ABC / shareware-era coders**, not a replacement for everything Godot can do. New Godot-first games can ignore `SCREEN` entirely; retro ports and teaching demos can lean on it.

**What’s in this release**

• **SCREEN 0–14** — PC/QB modes (including **13** = 320×200×256, letterboxed in the window)  
• **Classic profiles 100–199** — Tandy, Atari-style, CoCo, Apple-inspired, C64-ish, Amiga-ish **layouts** (inspired sizes, not hardware emulation)  
• **Split playfields** — modes **111** / **112** (game pixels on top, text band below); optional clip via project setting  
• **Drawing** — `PSET`, `LINE` (B/BF), `CIRCLE`, `PAINT`, `GET`/`PUT`, `PALETTE`, `CLS` on the active buffer  
• **Input & sound** — `INKEY$`, `PLAY` (MML where SiON is available), classic `SOUND`/`BEEP`  
• **Queries** — `ScreenMode()`, `GfxWidth()`, `GfxHeight()`, `GfxPlayfieldBottom()` (use these for game size — **not** monitor `Screen.Width`)  
• **QB64-shaped helpers** — `_NewImage`, `_PutImage`, `_MouseX`/`_MouseY` in buffer space, `_DesktopWidth`/`Height`, file WAV/OGG via `_SndOpen` / `_SndPlay` (see docs for limits)  
• **AI (Narcea)** — turn on **Project Settings → Vg → classic → enabled** so Vibe Code prefers `SCREEN`/`PSET` for retro projects  

**How to try it**

1. Install **Visual Gasic** from the weekend release (Godot 4.6 + bundled addon).  
2. Open the sample: **`samples/showcases/qb_abc_showcase/`** in Godot, press **F5**.  
3. Main menu: **1–7** = ABC-style games (Bagels, Trek, Invaders, Breakout, Lander, Sokoban, Nibbles). **Q** = more games/demos/tools hub. **`.` (period)** = **Classic systems — SCREEN mode gallery** (three pages: DOS 1–14, profiles 100–112, 120–150).  
4. Read **`docs/manual/classic_porting_guide.md`** if you’re moving a `.BAS` to `.vg` (translation, not paste-and-run).  

**Examples in the repo**

| Sample | Path | Notes |
|--------|------|--------|
| **QB ABC showcase** | `samples/showcases/qb_abc_showcase/` | Full menu + games + **`.`** mode gallery |
| **Classic modes only** | `samples/showcases/classic_screen_modes/` | Same gallery demos, standalone project |
| **Galactic Defender** | `samples/demos/2D_Games/Galactic_Defender/` | Game using SCREEN in a real project |

Games in the showcase are **new reimplementations** in Visual Gasic (credits in source), inspired by [BasicGuru ABC](https://basicguru.com/abc/games.htm) and QB64 gallery ideas — not copied `.BAS` listings. Bigger ports (Gorillas, etc.) remain separate efforts; this release is the **engine lane + demo pack + docs**.

**Docs (on GitHub, same release tag)**

• [Classic games graphics](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/manual/classic_games_graphics.md) — mode table, splits  
• [Classic porting guide](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/manual/classic_porting_guide.md) — `.BAS` → `.vg` checklist  
• [QuickBASIC graphics mode](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/manual/qb_graphics_mode.md) — statement reference  

If you learned on QBasic, ABC archives, or BasicGuru — grab the build when it’s live, run the showcase, and tell us what breaks. We’re building toward a stable 6.0 line; classic BASIC belongs in the same language, not a dead fork.

#QuickBASIC #QBasic #RetroProgramming #IndieDev #VisualGasic #GodotEngine #BASIC

---

**Screenshot checklist**

1. Showcase title screen (keys 1–7, Q, `.`)  
2. **Classic systems** gallery after pressing **`.`** (mode name + resolution on screen)  
3. Space Invaders or Breakout on **`SCREEN 13`**  
4. Nibbles or Sokoban (keyboard + simple gfx)  
5. Optional: IDE with `Screen 13` / `PSet (160, 100), 15` in a `.vg` file  

**Where to run (from a clone):** `samples/showcases/qb_abc_showcase/` — Godot 4.6.1 + Visual Gasic enabled, **F5**.

**Release:** replace “this weekend” with the actual tag name and download link when `gh release create` is done (e.g. `VisualGasic v5.5.0-beta.3`).
