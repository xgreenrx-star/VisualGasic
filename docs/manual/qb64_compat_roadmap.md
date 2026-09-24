# QB64-style layer — what is in, and what is left out

Visual Gasic’s QuickBASIC layer (`src/visual_gasic_qb_screen.cpp`) covers classic `SCREEN` drawing plus a **small QB64-shaped subset**: 32-bit pages, mouse in buffer space, file audio, and desktop size queries. It is **not** a QB64 Phoenix (`libqb`) port.

The gaps below are **recorded on purpose**. They stay out of the QB layer unless there is a concrete port that needs them. Visual Gasic already has other ways to do the same jobs (canvas drawing, Godot audio, `_Input`).

Regression tests: `test_proj/test_suite/test_qb_screen.vg`.

## In the QB layer today

| Area | Commands |
|------|----------|
| Classic buffer | `SCREEN` 0–13, `PSET`, `LINE`, `CIRCLE`, `PAINT`, `GET`/`PUT`, `PALETTE`, `PCOPY`, `VIEW`, `WINDOW`, `DRAW`, `LOCATE`/`PRINT` 8×8, `Point`, `InKey$`, `SOUND`/`BEEP`/`PLAY`, `LoadPcx` |
| 32-bit pages | `_NewImage`, `SCREEN handle`, `_Dest`, `_Source`, `_PutImage (x, y), src`, `_Display`, `_FreeImage`, `_LoadImage`, `_RGB32`, `_RGBA32`, `_Width`, `_Height` |
| Desktop size | `_DesktopWidth`, `_DesktopHeight` (monitor; if the OS reports 0×0, the Godot viewport, then 640×480). The buffer stays **letterboxed**. It does not resize the OS window. |
| Mouse | `_MouseX`, `_MouseY`, `_MouseButton(1\|2\|3)`, `_MouseInput` in QB pixel space |
| File audio | `_SndOpen`, `_SndPlay`, `_SndStop`, `_SndClose`, `_SndPlaying` (WAV/OGG Godot can load) |

Handles from `_NewImage` / `_LoadImage` are **negative**. `SCREEN 13` is unchanged.

Zero-argument names may omit parentheses: `_DesktopWidth`, `_DesktopHeight`, `_MouseX`, `_MouseY`, `_MouseInput`, `_Width`, `_Height`.

## Limitations (deferred)

These QB64 behaviors are **not** implemented. Use the VG path in the last column. Revisit a row only if a real program cannot be written the other way.

| QB64 behavior | QB layer today | Use instead |
|---------------|----------------|-------------|
| `_PUTIMAGE` with a destination rectangle (stretch / scale) | `_PutImage (x, y), source` copies **1:1** | `DrawTexture` / `DrawTextureRect` in `_Draw`, or draw into a page that is already the right size |
| `$Resize`, `_RESIZE`, window follows the desktop | Buffer is letterboxed inside the current Godot viewport | Godot window / project viewport; `Screen.Width` and `Screen.Height` for the host window |
| `_MOUSEWHEEL`, `_MOUSEMOVEMENTX` / `Y` | Button 1–3 and position only | `_Input` with `InputEventMouseButton` (wheel) and `InputEventMouseMotion` (`relative`) |
| MIDI, `_SNDBAL`, `_SNDVOL`, `_SNDPLAYCOPY`, `_SNDLOOP` | One `AudioStreamPlayer` per `_SndOpen`; `SOUND` / `PLAY` for tones | Godot `AudioStreamPlayer` (pitch, volume, several players); `PLAY` for MML-style tones |
| `_LOADIMAGE` hardware flag, GIF animation | PNG/JPG/WebP into one RGBA page; `LoadPcx` for 8-bit PCX | Godot `AnimatedSprite2D` / `Image` for GIF-style frames |
| `_PRINTSTRING`, TrueType, font files | 8×8 `PRINT` on the buffer after `LOCATE` or `COLOR` | `DrawString` in `_Draw` |
| `_NewImage(..., 256)` as a second palette surface | Only **32**-bit pages are RGBA. Palette drawing stays on `SCREEN` modes | `SCREEN 13` (or 1, 2, 7–12) for indexed color |
| Several hardware pages beyond QB `PCOPY` 0/1 | Two palette pages (`PCOPY`). 32-bit pages are separate handles | Extra `_NewImage` handles and `_PutImage` |
| `DEF SEG`, `PEEK`/`POKE`, `CALL ABSOLUTE`, `INTERRUPT`, `BSAVE`, `BLOAD` | Not implemented | VG variables or `MemoryBuffer`; image load via `_LoadImage` / `LoadPcx` |

`_RGBA32` stores alpha in the page pixel. There is no QB64-style full-screen fade or blend mode. Per-pixel alpha is the stored channel; a fade across the whole frame is a Godot modulate or a loop of `_RGBA32` writes.

## Showcase note

QB64 gallery programs in `samples/showcases/qb_abc_showcase/` are **original `.vg` rewrites**, not copied `.BAS`. Where a sample needs stretch blit, MIDI, or a resizable desktop window, the showcase stays on `SCREEN 13` or the subset above. See [QB64_SAMPLES_AND_SHOWCASE.md](../showcase/QB64_SAMPLES_AND_SHOWCASE.md).
