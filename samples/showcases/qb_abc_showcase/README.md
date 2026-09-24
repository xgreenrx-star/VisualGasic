# QB ABC Showcase

**Nineteen** recognizable classics from the [ABC / BasicGuru archive](https://basicguru.com/abc/games.htm) era, reimplemented in **Visual Gasic** to demo the QuickBASIC graphics layer (`SCREEN`, `PSET`, `LINE`, `CIRCLE`, `GET`/`PUT`, `InKey$`, `PLAY`, …).

These are **spirit successors** (same gameplay feel, VG idioms)—not byte-for-byte dumps of PostIt-encoded `.bas` files. Each game shows an **intro screen** (controls + credit) before play.

## Run

Open this folder in Godot 4.6+ with Visual Gasic enabled, press **F5**.

Headless input smoke (from repo root, after `scons`):

```bash
scripts/run_qb_abc_headless.sh
```

| Key | Action |
|-----|--------|
| **1–7** | Tier A demos (intro → Enter/Space to start) |
| **B** | Tier B menu (7 moderate games) |
| **C** | Tier C menu (5 expanded games) |
| **8** | About, sources, disclaimer |
| **Esc** | Back (intro → submenu; in-game → submenu or main menu) |

### Tier A (1–7)

| # | Game |
|---|------|
| **1** | Bagels (Mastermind-style) |
| **2** | Super Star Trek (short session) |
| **3** | Space Invaders |
| **4** | Breakout |
| **5** | Lunar Lander |
| **6** | Sokoban (mini) |
| **7** | Nibbles (snake) |

### Tier B (menu **B**, keys 1–7)

Gorillas, Haunted House, Hunt the Wumpus, Blackjack, Minesweeper, Tower of Hanoi, mini dungeon.

### Tier C (menu **C**, keys 1–5)

Super Star Trek (expanded), Jetpack, Defender-style scroller, Sokoban (multi-level), Nibbles (walls + growth).

Attribution text lives in `games/ShowcaseMeta.vg` (per-game credits + global disclaimer).

## Further ports

Tier B/C games are **playable demos**, not full archive ports. For the complexity ladder and future candidates, see [`docs/showcase/QB_ABC_COMPLEX_CANDIDATES.md`](../../../docs/showcase/QB_ABC_COMPLEX_CANDIDATES.md).

## Screenshots (for social posts)

With the game running, capture the window (or Godot screenshot). Suggested shots:

1. Menu (`Main.vg` title screen + disclaimer footer)
2. **Intro screen** for any game (controls + credit)
3. **Space Invaders** mid-wave (`SCREEN 13`)
4. **Breakout** with bricks + paddle
5. **Lunar Lander** near surface
6. **About (8)** screen

Save under `screenshots/` for the Facebook asset pack.

## Docs

- Draft post: [`docs/showcase/FACEBOOK_QB_CLASSIC_CODERS.md`](../../../docs/showcase/FACEBOOK_QB_CLASSIC_CODERS.md)
- Complexity ladder: [`docs/showcase/QB_ABC_COMPLEX_CANDIDATES.md`](../../../docs/showcase/QB_ABC_COMPLEX_CANDIDATES.md)
- QB commands: [`docs/manual/qb_graphics_mode.md`](../../../docs/manual/qb_graphics_mode.md)
