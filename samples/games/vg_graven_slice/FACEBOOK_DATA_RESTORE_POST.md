# Facebook post — DATA/RESTORE + recent VG improvements (v5.5.0-beta1)

**Screenshot to attach:** `docs/screenshots/Screenshot at 2026-09-13 09-36-43.png`
(shows `R12Map:` in the code editor — the exact `Data` block quoted in the post below, so the image and the pasted code match up.)

Optional second image if Facebook lets you add more than one: `docs/screenshots/Screenshot at 2026-09-13 09-37-12.png` (shows the per-room `Restore` labels for spawn point, gravity mass, hint text, etc. — good if someone asks "wait, is that ALL you can store this way?").

---

## Post copy (paste into Facebook)

We've been heads-down on Visual Gasic and just shipped **v5.5.0-beta1**, and I want to show off my favorite little trick in the language: the **`Data` / `Restore` / `Read`** statements.

If you never touched old-school BASIC, here's the idea in one sentence: **`Data` lets you type your game's content straight into your code, like a drawing made of text** — no external file, no level editor, no JSON. Just type it, and it's there.

Here's a real room from our new game slice, **GRAVEN** (a little gravity-flip cave explorer, built entirely in VG, running on Godot 4.6):

```basic
R12Map:
Data "########################################"
Data "#E......################################"
Data "#.......################################"
Data "#.......################################"
Data "#.......################################"
Data "#.......################################"
Data "#.......################################"
Data "#.......################################"
Data "#.......################################"
Data "#................................#######"
Data "#................................#######"
Data "#................................#######"
Data "#................................#######"
Data "#................................#######"
Data "#......................................#"
Data "#####..................................#"
Data "####################...................#"
Data "####################...................#"
Data "####################...................#"
Data "########################################"
Data "########################################"
Data "########################################"
```

Look at that for two seconds and you already know what the room looks like. `#` is solid rock, `.` is open space you can fly through, `E` is the exit. You're not imagining a grid from a list of numbers — **you're looking right at the shape of the cave.** That's the whole pitch: it's readable by a human, not just a computer.

Getting it back into the game is one line:

```basic
Restore "R12Map"
For ty = 0 To ROWS - 1
    Read row
    Call ParseRoomRow(row, ty)
Next ty
```

`Restore` jumps to the labeled block by name, `Read` pulls the rows out one at a time. Every one of our 17 rooms in GRAVEN is stored exactly this way — swap the label, get a whole new room. No custom file format, no importer, no build step. Type a new room, and it exists.

**Other things that landed recently in VG:**
- The GRAVEN slice itself — 17 rooms, gravity-well physics, sonar pulses, tow mechanics, all written in `.vg` files you can actually read top to bottom
- `Restore` now works correctly even when it's called from a helper `Sub` (a real bug we squashed — level data loading is rock solid now)
- The code editor got a built-in panel for editing these `Data` blocks visually, if typing grids by hand isn't your thing
- Multi-file VG projects can now `Include` each other using relative paths, so bigger games stay organized

Small language, honest tools, and a real game to prove it. That's Visual Gasic.

#VisualGasic #IndieDev #GameDev #VB6 #GodotEngine #RetroGaming #Coding

---

## Shorter variant (if you want less text)

Visual Gasic v5.5.0-beta1 is out, and here's the feature I'm proudest of: `Data` statements.

You can literally draw a game level using text characters, right inside your code:

```basic
Data "########################################"
Data "#E......################################"
Data "#.......################################"
```

`#` = wall, `.` = floor, `E` = exit. No level editor, no JSON — you can see the room just by reading the code. One `Restore "RoomName"` + a `Read` loop and it's loaded into the game.

Every one of the 17 rooms in our new game slice, **GRAVEN**, is built this way. Simple to write, simple to read, simple to change.

#VisualGasic #GameDev #VB6 #GodotEngine
