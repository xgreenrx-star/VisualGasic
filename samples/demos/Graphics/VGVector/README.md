# VG Vector — Vector Graphics Editor with Animation

A coordinate-based vector graphics editor with a full animation timeline, written entirely in VisualGasic. Creates `.VGV` (VisualGasic Vector) animation files that can be played back in VG Movie.

## Features

- **7 Drawing Tools** — Select, Line, Rectangle, Ellipse, Polygon, Polyline, Text
- **Pure Vector Graphics** — All shapes stored as mathematical coordinates (no bitmaps)
- **Animation Timeline** — Up to 120 frames with add/delete/clone frame controls
- **Onion Skinning** — See previous frame ghosted for animation reference
- **Play/Pause Preview** — Watch animations in the editor
- **Shape Selection & Dragging** — Click to select, drag to move shapes
- **Polygon Support** — Multi-vertex polygons with click-to-add vertices
- **Custom .VGV Format** — Text-based vector animation file format

## .VGV File Format

The `.VGV` format is a human-readable text file:

```
VGV1                          ← Format identifier
800,500                       ← Canvas width,height
60,24                         ← Frame count, FPS
FRAMES
FRAME 0
SHAPE LINE,x1,y1,x2,y2,sR,sG,sB,sA,sW,fR,fG,fB,fA
SHAPE RECT,x1,y1,x2,y2,...
SHAPE TEXT,x1,y1,x2,y2,...
TEXTDATA Hello World
SHAPE POLYGON,x1,y1,x2,y2,...
POINTS 3,x1,y1,x2,y2,x3,y3
ENDFRAME
ENDVGV
```

Shape types: `LINE`, `RECT`, `ELLIPSE`, `POLYGON`, `POLYLINE`, `TEXT`

## OS Integration Demonstrated

| Feature | VG API |
|---------|--------|
| File I/O | FreeFile, Open, Print #, Line Input #, Close |
| Preferences | SaveSetting, GetSetting |
| Dialogs | MsgBox, InputBox |
| Timer | Animation playback timing |

## Files

- `VGVector.tscn` — Form layout with menus (File, Edit, Animation, Help)
- `VGVector.vg` — All vector editor logic (~700 lines of VG code)
- `main.tscn` — Scene launcher

## How to Run

Open `main.tscn` in Godot and run, or open `VGVector.tscn` in the VG Form Editor.

## Platforms

Linux • Windows • Android • Apple • HTML5
