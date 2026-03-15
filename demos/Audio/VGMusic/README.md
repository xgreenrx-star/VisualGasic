# VG Music — Live Coding Music Synthesizer

A Strudel-inspired live coding music environment that uses plain English BASIC commands instead of cryptic notation. Write music in the code editor, hit Play, and hear it in real time.

## Concept

Where Strudel uses mini-notation like `"bd sd [hh hh]"`, VG Music uses readable BASIC:

```basic
Tempo 120
Wave Sine
Volume 75

Play C4, Quarter
Play E4, Quarter
Play G4, Half
Rest Quarter
PlayDrum Kick, Eighth
```

## Features

- **Live Code Editor** — Write music commands with syntax highlighting
- **Real-Time Audio** — Plays via PlayTone waveform synthesis
- **Note Visualizer** — Scrolling display showing notes as they play
- **6 Example Songs** — Twinkle Twinkle, Drum Pattern, Bass Line, Layered Beat, Ambient Pad, Arpeggio
- **Multi-Layer Support** — Up to 8 simultaneous voices
- **Repeat Blocks** — Loop sections of music
- **Save/Load .VGS Files** — Custom song file format
- **Built-in Language Reference** — Full command help overlay
- **Panic Button** — Emergency silence (Escape key)

## Music Language Reference

### Commands
| Command | Description | Example |
|---------|-------------|---------|
| `Play <note>, <duration>` | Play a musical note | `Play C4, Quarter` |
| `PlayDrum <drum>, <duration>` | Play percussion | `PlayDrum Kick, Eighth` |
| `Rest <duration>` | Silent pause | `Rest Half` |
| `Tempo <bpm>` | Set speed (40-300) | `Tempo 120` |
| `Wave <type>` | Set waveform | `Wave Sine` |
| `Volume <0-100>` | Set volume | `Volume 75` |
| `Layer <name>` | New simultaneous voice | `Layer Bass` |
| `Repeat <n>` / `EndRepeat` | Loop a section | `Repeat 4` |

### Notes
`C`, `C#`, `D`, `D#`, `E`, `F`, `F#`, `G`, `G#`, `A`, `A#`, `B` — Octaves 1-7

### Durations
`Whole` (4 beats), `Half` (2), `Quarter` (1), `Eighth` (0.5), `Sixteenth` (0.25), `Triplet` (⅓)

### Drums
`Kick`, `Snare`, `HiHat`, `Clap`, `Tom`, `Rim`, `Cowbell`

### Waveforms
`Sine` (smooth), `Square` (retro), `Saw` (bright), `Triangle` (soft)

## OS Integration Demonstrated

| Feature | VG API |
|---------|--------|
| Audio | PlayTone (waveform synthesis) |
| File I/O | FreeFile, Open, Print #, Line Input #, Close |
| Preferences | SaveSetting, GetSetting |
| Dialogs | MsgBox, InputBox |
| Timer | Sequencer clock via _Process |

## Files

- `VGMusic.tscn` — Form layout with menus (File, Playback, Examples, Help)
- `VGMusic.vg` — All music logic (~650 lines of VG code)
- `main.tscn` — Scene launcher

## How to Run

Open `main.tscn` in Godot and run, or open `VGMusic.tscn` in the VG Form Editor.

## Platforms

Linux • Windows • Android • Apple • HTML5
