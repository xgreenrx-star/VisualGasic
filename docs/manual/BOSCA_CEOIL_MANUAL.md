# Bosca Ceoil Blue — Music Tracker Manual

Bosca Ceoil Blue is the built-in **chiptune / music tracker** embedded in the VisualGasic IDE.  It lets you compose retro-style music directly inside your VG project without leaving the editor, then export the result in a format your game can play.

---

## Table of Contents

1. [Opening the Tracker](#opening-the-tracker)
2. [Interface Overview](#interface-overview)
3. [Composing a Song](#composing-a-song)
4. [Export to Game Project](#export-to-game-project)
   - [WAV Export](#wav-export)
   - [OGG Export](#ogg-export)
   - [MML Export (dynamic synthesis)](#mml-export-dynamic-synthesis)
   - [.ceol Source File](#ceol-source-file)
5. [Playing Music in Your Game](#playing-music-in-your-game)
   - [Static Audio (WAV / OGG)](#static-audio-wav--ogg)
   - [Dynamic Synthesis (VGMusicPlayer)](#dynamic-synthesis-vgmusicplayer)
6. [VGMusicPlayer Node Reference](#vgmusicplayer-node-reference)
7. [Tips & Limitations](#tips--limitations)

---

## Opening the Tracker

Click the **🎵 Bosca Ceoil** button in the VG toolbar at the top of the IDE.

The panel loads on first activation (Bosca initialises its audio driver at that point — this takes a second or two the first time).

---

## Interface Overview

```
┌────────────────────────────────────────────────────────┐
│  Export to game:  [WAV]  [OGG]  [.ceol ⚠]  │  [MML]   │  ← VG export toolbar
├────────────────────────────────────────────────────────┤
│                                                        │
│   ┌──────────────────────────────────────────────────┐ │
│   │  Bosca Ceoil Blue embedded editor               │ │
│   │  (full chiptune tracker UI)                     │ │
│   └──────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────┘
```

The **Export to game** toolbar at the top is added by VisualGasic.  Everything below it is the standard Bosca Ceoil Blue interface.

### Bosca keyboard shortcuts (inside the tracker)

| Shortcut | Action |
|---|---|
| Space | Play / Pause |
| Ctrl+S | Save .ceol project file |
| Ctrl+Shift+S | Save .ceol As… |
| Ctrl+Z / Ctrl+Y | Undo / Redo |
| Ctrl+N | New song |
| Ctrl+O | Open .ceol file |

---

## Composing a Song

Bosca Ceoil uses a **pattern-based** composition model:

1. **Instruments** — pick from FM synths, chiptune waveforms, MIDI GM instruments, and more.  Select the key and scale for each pattern.
2. **Pattern Editor** — a piano-roll grid.  Click cells to add notes.  Each row is one pitch; each column is one beat subdivision.
3. **Arrangement** — drag patterns into the timeline at the bottom to build the full song structure.

Refer to the [Bosca Ceoil Blue documentation](https://github.com/YuriSizov/boscaceoil-blue) for a complete guide to its composition features.

---

## Export to Game Project

The **Export to game** toolbar handles getting your music into a format your Godot game can use.

### WAV Export

Click **WAV** → choose a save path.

- Exports a 44 100 Hz, 16-bit stereo PCM WAV file.
- Works on every Godot export target with no extra dependencies.
- A `.ceol` source file is automatically saved alongside the WAV with the same base name.

> **Tip:** In Godot's import settings for the WAV, set *Compression Mode → Vorbis* to get OGG-level file sizes without needing ffmpeg.

---

### OGG Export

Click **OGG** → choose a save path.

- Requires **ffmpeg** to be installed and on your system PATH.
- If ffmpeg is not found, the button is disabled and shows a tooltip explaining how to install it.
- Internally exports to a temporary WAV, converts with `ffmpeg -q:a 4` (VBR ~128 kbps), then deletes the temp WAV.
- A `.ceol` source file is automatically saved alongside the OGG.

**Installing ffmpeg:**

| Platform | Command |
|---|---|
| Ubuntu / Debian | `sudo apt install ffmpeg` |
| Fedora | `sudo dnf install ffmpeg` |
| macOS (Homebrew) | `brew install ffmpeg` |
| Windows | Download from [ffmpeg.org](https://ffmpeg.org/download.html) and add to PATH |

---

### MML Export (dynamic synthesis)

Click **MML** → choose a save path.

Exports the song as a **SiON MML** text file.  MML can be played back at runtime using the `VGMusicPlayer` node (see below) via the GDSiON GDExtension.  This enables features like tempo that reacts to gameplay.

A `.ceol` source file is automatically saved alongside the MML.

---

### .ceol Source File

Click **.ceol ⚠** to manually save the Bosca project file via a Save-As dialog.

> **Note:** A `.ceol` file is saved automatically alongside every WAV, OGG, and MML export.  You only need this button if you want to save the project file to a different location or under a different name.

The `.ceol` format is not playable at runtime — it is the **editable project file**.  To play music in your game you need a WAV, OGG, or MML export.

#### ⚠ Runtime playback warning

If you attempt to use `.ceol` files for runtime playback, a warning dialog is shown.  Runtime playback requires:

- GDSiON GDExtension binaries shipped with every game export (~2–5 MB per platform).
- Platforms without a GDSiON binary will silently fail to play music.
- Audio runs on the CPU synthesiser and does **not** pass through Godot's AudioServer (bus effects like reverb/compressor will not apply).

For maximum compatibility, use WAV or OGG export.

---

## Playing Music in Your Game

### Static Audio (WAV / OGG)

1. Export your song as **WAV** or **OGG** using the toolbar.
2. In the Godot editor, select the exported file and set its import type to `AudioStream`.
3. Add an `AudioStreamPlayer` node to your scene.
4. Assign the imported stream to the node's **Stream** property.
5. Call `$AudioStreamPlayer.play()` in your script.

```gdscript
# Play background music on scene start
func _ready():
    $AudioStreamPlayer.play()

# Stop music
func stop_music():
    $AudioStreamPlayer.stop()
```

This approach works on **all** Godot export targets and has no extra runtime dependencies.

---

### Dynamic Synthesis (VGMusicPlayer)

Use this when you need the music to react to gameplay (e.g. tempo changes, adaptive intensity).

**Setup:**

1. Export your song as **MML** using the toolbar.
2. Copy `addons/visual_gasic/plugins/vgmusic/bin/` and `addons/visual_gasic/plugins/vgmusic/libgdsion.gdextension` into your game project.
3. Add a `VGMusicPlayer` node to your scene, or attach [VGMusicPlayer.gd](../../addons/visual_gasic/plugins/vgmusic/runtime/VGMusicPlayer.gd) to a Node.
4. Set the `mml_file` export property to your `.mml` path (e.g. `res://music/theme.mml`).
5. Call `$VGMusicPlayer.play()`.

```gdscript
# Play the song
$VGMusicPlayer.play()

# Change tempo mid-game
$VGMusicPlayer.set_bpm(140.0)

# Pause during a cutscene
$VGMusicPlayer.pause()
$VGMusicPlayer.resume()
```

---

## VGMusicPlayer Node Reference

Script location: `addons/visual_gasic/plugins/vgmusic/runtime/VGMusicPlayer.gd`

### Export Properties

| Property | Type | Default | Description |
|---|---|---|---|
| `mml_file` | `String` | `""` | Path to the `.mml` file exported from Bosca Ceoil. |
| `loop` | `bool` | `true` | Loop the song indefinitely. |
| `auto_play` | `bool` | `false` | Start playing as soon as the node enters the scene tree. |
| `buffer_size` | `int` | `2048` | SiON audio buffer size in samples.  Increase if you hear glitches. |

### Methods

| Method | Description |
|---|---|
| `play()` | Start (or restart) playback. |
| `stop()` | Stop playback and reset to the beginning. |
| `pause()` | Pause playback. |
| `resume()` | Resume after `pause()`. |
| `is_playing() → bool` | Returns `true` while playing. |
| `load_song(path: String) → bool` | Load a different `.mml` file at runtime. |
| `set_bpm(bpm: float)` | Change the playback tempo. |

---

## Tips & Limitations

- **Always keep the `.ceol` file.** It is your editable source.  WAV, OGG, and MML are baked exports — you cannot re-edit them in Bosca.  VG saves `.ceol` automatically alongside every export.
- **OGG is preferred over WAV** for music in shipped games — it is ~10× smaller with near-identical quality.  Use `apt install ffmpeg` to enable OGG export in VG.
- **GDSiON is not needed** for WAV/OGG playback.  Only use `VGMusicPlayer` if you specifically need real-time synthesis.
- **Web export + GDSiON**: GDSiON provides a WebAssembly build; include the `.wasm32` binary if targeting HTML5.
- **Mobile**: CPU synthesis on low-end Android devices may cause audio lag.  Test early if targeting mobile with `VGMusicPlayer`.
- The Bosca Ceoil Blue editor is vendored under `addons/visual_gasic/plugins/vgmusic/bosca/` and is provided under the MIT licence.  See its [GitHub repository](https://github.com/YuriSizov/boscaceoil-blue) for full documentation.
