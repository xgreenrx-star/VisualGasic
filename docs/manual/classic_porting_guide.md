# Classic porting guide (.BAS → .vg)

This guide is for developers bringing **QuickBASIC / QBasic / QB64-style** programs into Visual Gasic. Visual Gasic is **Godot-first**; the QB layer (`SCREEN`, `PSET`, …) is an **optional classic lane**, not full DOS or PC hardware emulation.

**Related docs**

- [Classic games graphics](classic_games_graphics.md) — SCREEN profiles, split modes, queries (`ScreenMode`, `GfxWidth`, …)
- [QuickBASIC graphics mode (SCREEN)](qb_graphics_mode.md) — command reference
- [QB64-style layer — limits](qb64_compat_roadmap.md) — what we deliberately omit
- **Showcase:** [QB ABC](../../samples/showcases/qb_abc_showcase/) — main menu **`.`** opens the **Classic systems SCREEN mode gallery**

---

## What “port” means here

| Goal | Approach |
|------|----------|
| Same **gameplay** and **feel** | Rewrite logic in `.vg`; mark edits with `' VG:` or a **VG CHANGES** block at the top |
| Same **source file unchanged** | Not supported — no `DEF SEG`, no binary PC memory model |
| Ship on desktop / web | Use Godot export; QB overlay is letterboxed inside the window |

Treat ports as **translations**, not paste-and-run. The [QB ABC showcase](../../samples/showcases/qb_abc_showcase/) is the style reference: original listings reimplemented in `.vg`, with credits and notes in source.

---

## Choose your lane: SCREEN vs canvas

Use **one primary drawing path** per game unless you plan the handoff (e.g. menu on canvas, playfield on SCREEN).

### Use QuickBASIC `SCREEN` when

- You want **fixed resolution** and **palette indices** (320×200 mode **13**, narrow **100**, split **111**, etc.).
- The original used **`PSET` / `LINE` / `CIRCLE` / `PAINT` / `GET` / `PUT`** and you want to keep that structure.
- You are **learning or demoing** retro QB syntax inside VG.
- You accept **letterboxing** in the Godot window (chunky pixels, not necessarily full-monitor stretch).

**Size and mode queries (after `Screen n`):**

```vb
Dim m As Integer
m = ScreenMode()          ' 0 when overlay hidden (Screen 0)
Dim w As Integer
w = GfxWidth()            ' logical buffer width — not Screen.Width
```

Project setting **`vg/classic/enabled`** tells Narcea to prefer this lane for the project. **`vg/classic/clip_playfield`** blocks drawing below the split line on modes **111** / **112** (use `Print` / `Locate` in the text band).

### Use canvas / Node2D (`_Draw`, `DrawRect`, …) when

- You want **resolution-independent UI**, anchors, or modern HUD (scores, touch-friendly buttons).
- You need **Color8 / vector text**, smooth scaling, or mixing with Godot nodes.
- The game is a **shipping Godot product** first and “QB look” is optional.
- You hit QB layer limits (stretch blit, TTF text, window resize) — see [qb64_compat_roadmap.md](qb64_compat_roadmap.md).

**Rule of thumb:** ABC-era arcade clones and gallery demos → **`Screen 13`**. Menus, tools, and climatist-style apps → **canvas** on the scene root.

### Hybrid pattern (common in the showcase)

```vb
Sub ShowMenu()
    Screen 0              ' hide QB sprite
    QueueRedraw           ' canvas _Draw runs again
End Sub

Sub StartLevel()
    Screen 13
    Cls
    ' ... PSET / LINE game ...
End Sub
```

Attach the `.vg` script to a **Node2D** root so `_Draw` and `SCREEN` can coexist; return to **`Screen 0`** before drawing menu chrome with `DrawString` / `DrawRect`.

---

## Porting workflow (checklist)

1. **Pick lane** — SCREEN-only, canvas-only, or hybrid (menu canvas + game SCREEN).
2. **Pick mode** — default **`Screen 13`** unless the design needs a [classic profile](classic_games_graphics.md) (e.g. **9** for 640×350, **111** for Atari-style split).
3. **Strip unsupported DOS** — remove or rewrite `DEF SEG`, `PEEK`/`POKE`, `CALL ABSOLUTE`, `INTERRUPT`, `BSAVE`/`BLOAD` (see below).
4. **Modernize structure** — `Sub`/`Function` instead of bare `GOSUB` where needed; module-level `Dim` instead of `DIM SHARED`; document any **engine bugs** you hit (do not silent-workaround undocumented VM issues).
5. **Input** — keep `INKEY$` for faithful ports; prefer **`IsKeyJustPressed`** or **`_Input`** + `keycode` for new code (embedded Godot game view).
6. **Test** — `Point(x, y)` for pixel tests; run `test_qb_screen.vg` after engine changes:
   ```bash
   VG_TEST_SUITE_VG_ONLY=1 ./run_test_suite.sh test_qb_screen.vg
   ```
7. **Document** — header comment: inspiration, URL, **VG CHANGES**, license note if derived from published `.BAS`.

---

## Replace `PEEK` / `POKE` / `DEF SEG`

The QB layer **does not** implement DOS segment registers or video RAM at `&HA000`. Faking a full PC address space creates false compatibility expectations and does not help real type-ins that depend on BIOS or timing.

### Instead: variables and arrays

Most BASIC “memory hacks” are really **game state**:

```vb
' Was: POKE offset, value  /  x = PEEK(offset)
Dim playerX As Integer
Dim playerY As Integer
playerX = 100
```

Use **`Dim` arrays** for tables the original stored in memory:

```vb
Dim map(0 To 24, 0 To 79) As Integer
map(row, col) = 1
```

### Instead: `VGMemoryBuffer`

When the original used **`PEEK`/`POKE` for a binary blob** (packet layout, record file, sprite bytes), use **`New VGMemoryBuffer`** — typed peek/poke at **offsets**, no segments:

```vb
Dim buf As Object
buf = New VGMemoryBuffer
buf.Allocate 256

buf.PokeByte 0, &HFF
buf.PokeInt32 4, score

Dim b As Integer
b = buf.PeekByte(0)

buf.Free
```

Available methods include `PeekByte`, `PokeByte`, `PeekInt16`, `PokeInt32`, `PeekFloat`, `CopyFrom`, `ToByteArray`, `HexDump`, etc. Full list: [Language Reference — VGMemoryBuffer](../VisualGasic_Language_Reference.md#vgmemorybuffer-raw-memory).

**Do not** map `VGMemoryBuffer` to fake `&HB800` / `&HA000` unless you are writing a **self-contained tutorial** with a documented, frozen map. Production ports should use **named variables** or **arrays**, not emulated DOS.

### Graphics bytes

| Old habit | VG approach |
|-----------|-------------|
| POKE into video memory for scrolling | `PSET`/`LINE`, or **`Scroll`** (QB layer); rewrite algorithm |
| BLOAD screen | `LoadPcx`, `_LoadImage`, or Godot resources |
| GET/PUT arrays | **`GET (x1,y1)-(x2,y2), arr`** / **`PUT (x,y), arr`** still supported on SCREEN |

---

## Common statement substitutions

| QBasic / QB64 | Visual Gasic |
|---------------|--------------|
| `SCREEN 13` | Same (or classic **100–199** profiles) |
| `SCREEN 0` | Hides QB overlay; use for canvas menu |
| `WIDTH`, `LOCATE`, `PRINT` (in graphics mode) | Supported on active SCREEN (8×8 cell text) |
| `INKEY$` | Supported; extended keys use Chr(0) + scan byte |
| `PLAY "..."` | Supported (MML / SiON when available) |
| `SOUND` / `BEEP` | Supported (simple tones) |
| `_PUTIMAGE` stretch / dest rect | **Not implemented** — use 1:1 `_PutImage` or canvas `DrawTexture` |
| `$Resize`, `_RESIZE` | **Not implemented** — Godot window / stretch settings |
| `DEF SEG`, `PEEK`, `POKE` | **`VGMemoryBuffer`** or **`Dim` / arrays** |
| `CHAIN` | Multiple `.vg` modules + `Import`, or `ChangeScene` for Godot scenes |
| `DATA` / `READ` | Supported; prefer files or arrays for large data |

Details and deferred features: [qb64_compat_roadmap.md](qb64_compat_roadmap.md).

---

## Input and timing

- **Game loop:** use **`Sub _Process(delta)`** on the script owner; QB drawing can happen every frame; texture upload is batched once per frame while SCREEN is active.
- **Keyboard:** `INKEY$` needs input on the owner node; for digit keys in the editor view, **`_Input`** with `InputEventKey` is often more reliable than action names on raw events.
- **Mouse in QB space:** `_MouseX`, `_MouseY`, `_MouseButton(1)` after SCREEN is active — not the same as Godot global mouse on canvas.

---

## Pixel look (crisp scaling)

Classic games usually want **nearest-neighbor** scaling, not blurry stretch:

- QB sprite uses nearest filtering in the engine; keep the **Godot window** stretch mode sensible for your project (see project **Display** settings).
- Game logic should use **`GfxWidth` / `GfxHeight`**, not **`Screen.Width` / `Screen.Height`** (those are the **monitor / window** size).

---

## Where to put your project

| Layout | When |
|--------|------|
| `samples/showcases/qb_abc_showcase/games/YourGame.vg` | Demo aligned with ABC pack; wire from `Main.vg` if appropriate |
| New folder under `samples/showcases/` or `samples/games/` | Standalone classic project |
| `vg/classic/enabled=true` in `project.godot` | Narcea defaults to SCREEN-first advice |

Enable **Project Settings → Vg → classic → enabled** when the whole project is retro QB style.

---

## When to ask for engine work

Add or extend regression tests in `test_proj/test_suite/` when you need new **language** or **SCREEN** behavior. Do not paper over compiler/VM bugs in game code — fix in `src/` per project rules.

Reasons to open an engine issue:

- A **documented** QB command behaves wrong (include minimal `.vg` + `Point` checks).
- A **real port** is blocked by a row in [qb64_compat_roadmap.md](qb64_compat_roadmap.md) (e.g. scaled `_PUTIMAGE`).

Reasons **not** to extend the engine:

- Single listing needs **`PEEK` at &Hxxxx`** for authenticity — rewrite with arrays or `VGMemoryBuffer`.
- Full **QB64 Phoenix** parity — out of product scope.

## See also

- [Classic games graphics](classic_games_graphics.md)
- [QB64 samples vs showcase](../showcase/QB64_SAMPLES_AND_SHOWCASE.md)
- [2D rendering](2d_rendering.md) — canvas path
- [Colors](colors.md) — `Color8` vs `Color()` on canvas
