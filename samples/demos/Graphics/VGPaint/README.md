# VG Paint — MS Paint Clone

A pixel-based paint application inspired by Microsoft Paint, written entirely in VisualGasic.

## Features

- **640×480 Pixel Canvas** — Full-resolution drawing surface
- **9 Drawing Tools** — Pencil, Brush, Eraser, Line, Rectangle, Ellipse, Flood Fill, Color Picker, Text
- **28-Color Palette** — Classic paint application color selection
- **Bresenham Line Algorithm** — Smooth lines and shape outlines
- **Stack-Based Flood Fill** — Fill enclosed regions (100K iteration safety limit)
- **Zoom** — 1×, 2×, 4× magnification
- **Custom .VGP Format** — Save and load paintings as CSV RGB data
- **Foreground/Background Colors** — Left/right click to select

## OS Integration Demonstrated

| Feature | VG API |
|---------|--------|
| File I/O | FreeFile, Open, Print #, Line Input #, Close |
| Preferences | SaveSetting, GetSetting |
| Dialogs | MsgBox, InputBox |

## Files

- `VGPaint.tscn` — Form layout with menus (File, Edit, Image, Help)
- `VGPaint.vg` — All paint logic (~600 lines of VG code)
- `main.tscn` — Scene launcher

## How to Run

Open `main.tscn` in Godot and run, or open `VGPaint.tscn` in the VG Form Editor.

## Platforms

Linux • Windows • Android • Apple • HTML5
