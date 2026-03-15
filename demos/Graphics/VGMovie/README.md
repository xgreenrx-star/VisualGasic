# VG Movie — Vector Animation Player

A dedicated player for `.VGV` (VisualGasic Vector) animation files created with VG Vector. Renders coordinate-based vector graphics frame-by-frame — no bitmaps, only mathematical shapes.

## Features

- **Plays .VGV Files** — Full support for the VGV1 format
- **Transport Controls** — Play, Pause, Stop, Next Frame, Previous Frame, Go to Start
- **Loop Mode** — Continuous playback with toggle
- **Timeline Scrubber** — Click anywhere on the timeline to jump to that frame
- **Zoom** — 1×, 2×, or Fit to Window
- **Frame Counter Overlay** — Shows current frame / total frames
- **Built-in Demo Animation** — 60-frame bouncing shapes demo loads on first run
- **Keyboard Shortcuts** — Space=Play/Pause, Escape=Stop, Arrow keys=Step

## How It Works

All rendering is pure vector — the player reads coordinate data from `.VGV` files and draws shapes using Godot's drawing primitives:

- `LINE` → DrawLine
- `RECT` → DrawRect + DrawLine edges
- `ELLIPSE` → Segmented DrawLine circle/ellipse
- `POLYGON` / `POLYLINE` → Connected DrawLine vertices
- `TEXT` → DrawString

Shapes are scaled and offset to fit the viewport, with smooth zooming and centering.

## OS Integration Demonstrated

| Feature | VG API |
|---------|--------|
| File I/O | FreeFile, Open, Line Input #, Close |
| Preferences | SaveSetting, GetSetting |
| Dialogs | MsgBox, InputBox |

## Files

- `VGMovie.tscn` — Form layout with menus (File, Playback, View, Help)
- `VGMovie.vg` — All player logic (~500 lines of VG code)
- `main.tscn` — Scene launcher

## How to Run

Open `main.tscn` in Godot and run, or open `VGMovie.tscn` in the VG Form Editor.

## Workflow

1. Create an animation in **VG Vector** → save as `.vgv`
2. Open the `.vgv` file in **VG Movie** → play it back

## Platforms

Linux • Windows • Android • Apple • HTML5
