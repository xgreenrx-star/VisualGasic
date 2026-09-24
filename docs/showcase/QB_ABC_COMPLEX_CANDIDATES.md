# ABC / QBasic-era games — complexity ladder for VG showcase

The [`qb_abc_showcase`](../../samples/showcases/qb_abc_showcase/) pack has **Tier A** (keys 1–7), **Tier B** (menu **B**, seven moderate demos), and **Tier C** (menu **C**, five expanded demos). Use this doc for **what’s in each tier** and **future flagship ports** beyond the current menus.

**Source hub:** [BasicGuru ABC games index](https://basicguru.com/abc/games.htm) (PostIt-encoded `.bas`; decode before porting).

## Already in showcase (simple demos)

| Key | Title | Why it stays “demo” |
|-----|--------|---------------------|
| 1 | Bagels | One mechanic, text UI |
| 2 | Star Trek | Abbreviated command set, no full galaxy map |
| 3–7 | Arcade mini-clones | Single screen, few states |

## Tier B — in showcase (menu **B**, keys 1–7)

Demo-scale ports in `games/*.vg` — same spirit as Tier A, more mechanics.

| Menu | Module | Notes |
|------|--------|--------|
| 1 | `Gorillas.vg` | Turn artillery, wind, `SCREEN 13` |
| 2 | `HauntedHouse.vg` | Room graph, `InKey$` / N S E W T U |
| 3 | `Wumpus.vg` | Cave adjacency, move/shoot |
| 4 | `Blackjack.vg` | Hit/stand, simple card bars |
| 5 | `Minesweeper.vg` | Grid reveal / flag |
| 6 | `Hanoi.vg` | Peg select + move |
| 7 | `Dungeon.vg` | Mini tile dungeon |

## Tier C — in showcase (menu **C**, keys 1–5)

| Menu | Module | Notes |
|------|--------|--------|
| 1 | `TrekFull.vg` | Expanded command Trek (text HUD) |
| 2 | `JetpackLite.vg` | Thrust platformer |
| 3 | `DefenderLite.vg` | Horizontal shooter |
| 4 | `SokobanFull.vg` | Multiple boxes / level |
| 5 | `NibblesFull.vg` | Walls + snake growth |

## Tier D — future flagship ports (not in menu yet)

| Candidate | Complexity | Blockers |
|-----------|------------|----------|
| **Full galaxy Star Trek** (many sectors, detailed LRS) | Very large | TrekFull is the menu slot; deeper port = new sample |
| **Gorillas 2-player hotseat polish** | UX + terrain | Current Gorillas is P1/P2 turns on one keyboard |
| **Mouse-driven Minesweeper** | Input | Grid logic exists; add Godot mouse later |
| **Level packs + undo (Sokoban)** | Data + state | SokobanFull is one level loop |
| **Scrolling platformers with tile maps** | Assets + camera | JetpackLite is single-screen |

## What to avoid for “first complex” ports

- **AdLib/SoundBlaster-only** music unless using VG `PLAY` / SiON path only  
- **BLOAD** binary assets without converting to VG `Data` / PNG  
- **Trademark-heavy names** in marketing (use “Star Trek–style”, “Invaders-style” in credits—already done in showcase intros)

## Showcase UX (implemented in project)

- **Intro screen** before each game: title, controls, per-game credit, global disclaimer  
- **About (8)** on menu: archive note + “not affiliated” text  
- See `games/ShowcaseMeta.vg` and `Main.vg` `MODE_INTRO` / `MODE_ABOUT`

When adding a **new menu game**, extend `ShowcaseMeta.vg`, wire `Main.vg` (`LaunchPendingGame`, `PollGame`, `RefreshHud`, tier menus), and add a regression note here if the port needs new VG/QB features.
