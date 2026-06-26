# Vector Graphics File Format (.vgvec)

**Purpose**: Efficient storage for vector drawings + animations. Delta-encoding for frame sequences saves 50-80% space vs. full snapshots.

---

## File Structure Overview

```
.vgvec file (JSON/JSONL hybrid)
├── metadata
│   ├── version: "1.0"
│   ├── width, height (canvas dimensions)
│   ├── fps: 24
│   ├── total_frames: 120
│   └── frame_list: ["Frame 0", "Frame 1", ...] (quick seek)
├── assets
│   ├── colors: {id -> {r,g,b,a}}
│   ├── gradients: {id -> gradient_def}
│   ├── fonts: {id -> font_name}
│   └── patterns: {id -> pattern_data}
├── Frame 0 (COMPLETE SNAPSHOT)
│   ├── shapes: [...]
│   └── paths: [...]
├── Frame 1 (DELTA from Frame 0)
│   ├── modified_ids: [shape_id1, shape_id2, ...]
│   └── changes: {shape_id -> {properties changed}}
├── Frame 2 (DELTA from Frame 1)
├── ...
└── Animation (metadata: loop, play_speed, triggers)
```

---

## Frame 0: Complete Snapshot

Stored as a full vector document. Every shape, path, and property is explicit.

```json
{
  "frame": 0,
  "timestamp": 0,
  "shapes": [
    {
      "id": "shape_0",
      "type": "rect",
      "x": 100,
      "y": 50,
      "width": 200,
      "height": 150,
      "fill": {
        "type": "solid",
        "color_id": "color_primary"
      },
      "stroke": {
        "color_id": "color_outline",
        "width": 2,
        "dasharray": null
      },
      "opacity": 1.0,
      "rotation": 0,
      "transform": null
    },
    {
      "id": "shape_1",
      "type": "circle",
      "cx": 300,
      "cy": 150,
      "r": 50,
      "fill": {"type": "solid", "color_id": "color_accent"},
      "stroke": null,
      "opacity": 1.0
    },
    {
      "id": "path_0",
      "type": "path",
      "d": "M 50 50 L 100 100 Q 150 50 200 100",
      "fill": null,
      "stroke": {"color_id": "color_outline", "width": 3},
      "opacity": 1.0
    },
    {
      "id": "text_0",
      "type": "text",
      "content": "Hello World",
      "x": 100,
      "y": 200,
      "font_id": "font_default",
      "font_size": 24,
      "fill": {"type": "solid", "color_id": "color_text"},
      "opacity": 1.0
    }
  ],
  "asset_refs": {
    "color_primary": "color_0",
    "color_outline": "color_1",
    "color_accent": "color_2",
    "color_text": "color_3",
    "font_default": "font_0"
  }
}
```

**Size estimate**: Full frame ~3-5 KB depending on complexity.

---

## Frame N≥1: Delta Encoding

Only store what **changed** from the previous frame.

```json
{
  "frame": 1,
  "timestamp": 0.04166,
  "base_frame": 0,
  "deltas": [
    {
      "id": "shape_0",
      "changes": {
        "x": {"from": 100, "to": 110},
        "opacity": {"from": 1.0, "to": 0.9}
      }
    },
    {
      "id": "shape_1",
      "changes": {
        "cx": {"from": 300, "to": 320},
        "fill": {
          "from": {"type": "solid", "color_id": "color_accent"},
          "to": {"type": "gradient", "gradient_id": "grad_0"}
        }
      }
    },
    {
      "id": "text_0",
      "changes": {
        "content": {"from": "Hello World", "to": "Hello VG!"}
      }
    }
  ],
  "added": [],
  "removed": []
}
```

**Size estimate**: Delta frame ~200-800 bytes (95% smaller than full snapshot).

---

## Handling Shape Add/Remove in Frame N

```json
{
  "frame": 5,
  "timestamp": 0.208,
  "base_frame": 0,
  "deltas": [...existing changes...],
  "added": [
    {
      "id": "shape_2",
      "type": "rect",
      "x": 250,
      "y": 100,
      "width": 100,
      "height": 100,
      "fill": {"type": "solid", "color_id": "color_primary"},
      "stroke": null,
      "opacity": 0.8
    }
  ],
  "removed": ["shape_1"]
}
```

**Note**: Remove by ID only. Add includes full shape definition (appears only once, in the frame where it's added).

---

## Compact Delta Format (SPACE OPTIMIZED)

For very tight files, compress delta format further:

```json
{
  "frame": 1,
  "base": 0,
  "d": {
    "shape_0": {"x": 110, "op": 0.9},
    "shape_1": {"cx": 320, "fill": "grad_0"}
  },
  "a": [],
  "r": []
}
```

Key names shortened: `deltas` → `d`, `added` → `a`, `removed` → `r`, `opacity` → `op`, `changes` → implicit.

---

## Asset Definitions (Shared Across All Frames)

Stored once at the top of the file.

```json
{
  "assets": {
    "colors": {
      "color_0": {"r": 255, "g": 0, "b": 0, "a": 255},
      "color_1": {"r": 0, "g": 0, "b": 0, "a": 255},
      "color_2": {"hex": "#FF00FF"}
    },
    "gradients": {
      "grad_0": {
        "type": "linear",
        "x1": 0,
        "y1": 0,
        "x2": 100,
        "y2": 100,
        "stops": [
          {"offset": 0, "color_id": "color_0"},
          {"offset": 1, "color_id": "color_1"}
        ]
      }
    },
    "fonts": {
      "font_0": {
        "name": "Arial",
        "variant": "bold",
        "fallback": "sans-serif"
      }
    },
    "patterns": {}
  }
}
```

---

## Animation Metadata

```json
{
  "animation": {
    "loop": true,
    "play_speed": 1.0,
    "reverse_playback": false,
    "frame_events": [
      {"frame": 10, "trigger": "sound_jump.ogg"},
      {"frame": 30, "trigger": "callback:on_impact"}
    ],
    "scenes": [
      {
        "name": "idle",
        "start_frame": 0,
        "end_frame": 20,
        "loop": true
      },
      {
        "name": "jump",
        "start_frame": 21,
        "end_frame": 40,
        "loop": false
      }
    ]
  }
}
```

---

## File Encoding Strategy

**PRIMARY FORMAT: Custom Binary (.vgvec)**
- **Real-time game performance**: 5-8ms parse + decompress within 16ms frame budget at 60 FPS
- **File size**: 12-15 KB for 120-frame animation (95% smaller than JSON)
- **Compression**: LZ4 (10-50× faster than GZIP; critical for games)
- **Streaming support**: Load frame-by-frame without parsing entire file
- **Zero-copy**: Memory-mapped reads for large files
- **Why**? Elite-style procedural vector graphics loaded live during gameplay need predictable fast loads. Msgpack/JSON parse times (15-20ms) cause frame drops; binary at 5-8ms maintains 60 FPS safely.

**FALLBACK/DEV FORMAT: Msgpack (.vgvec.msgpack)**
- 30-40% smaller than minified JSON
- Same schema as binary (easy bidirectional conversion)
- Used for git history, version control diffs, easy inspection
- Exported by editor for debugging
- Automatic fallback if .vgvec binary missing or corrupted

**DEBUG FORMAT: Minified JSON (.vgvec.json)**
- Human-readable for deep inspection
- Export-only (not shipped in game)
- Used for format validation, parser debugging
- Convertible back to binary via CLI tool

**Performance Reality Check**:
- Loading 1 vector asset: Msgpack = 15-20ms (risky at 60 FPS), **Binary = 5-8ms (safe)**
- Loading 5 vector assets simultaneously: Msgpack = 75-100ms (visible stutter), **Binary = 25-40ms (unnoticeable)**
- This is the difference between smooth gameplay and noticeable hitches.

---

## Loading & Playback

### Lazy Frame Reconstruction

When playing frame N, rebuild on-the-fly by walking from frame 0:

```
Frame 0 → load complete snapshot
Frame 1 → copy Frame 0 state, apply deltas from Frame 1
Frame 2 → copy Frame 1 state, apply deltas from Frame 2
Frame N → copy Frame N-1 state, apply deltas from Frame N
```

**Optimization**: Cache the last 3-5 frames in memory to avoid full replay.

### Random Access (Jump to Arbitrary Frame)

Two strategies:

1. **Full Replay** (simple, slow for large N):
   - Reconstruct from Frame 0 to target frame.
   - OK for files <1000 frames.

2. **Keyframe Chunks** (fast, adds file size):
   - Every 30 frames, store a full snapshot instead of delta.
   - Jump to nearest keyframe, then replay remaining deltas.
   - Size cost: ~1% overhead, massive speed win for long animations.

**Default**: Use keyframe chunks at 30-frame intervals (3.2 KB cost for 120-frame anim, 50× faster seek).

---

## Example: Full 120-Frame Animation File

```json
{
  "metadata": {
    "version": "1.0",
    "width": 800,
    "height": 600,
    "fps": 24,
    "total_frames": 120
  },
  "assets": {
    "colors": {
      "color_0": {"r": 255, "g": 100, "b": 50, "a": 255},
      "color_1": {"r": 0, "g": 0, "b": 0, "a": 255}
    },
    "fonts": {
      "font_0": {"name": "Arial", "variant": "regular"}
    }
  },
  "frame_0": {...full snapshot...},
  "frame_1": {
    "base": 0,
    "d": {
      "shape_0": {"x": 110, "y": 55}
    }
  },
  "frame_2": {
    "base": 1,
    "d": {
      "shape_0": {"x": 120, "y": 60}
    }
  },
  ... (frame_3 through frame_29: deltas)
  "frame_30": {...full snapshot (keyframe)...},
  ... (frame_31 through frame_119: deltas)
  "animation": {
    "loop": true,
    "scenes": [
      {"name": "walk_cycle", "start_frame": 0, "end_frame": 29},
      {"name": "jump", "start_frame": 30, "end_frame": 50}
    ]
  }
}
```

---

## File Size Comparison

**Scenario**: 120-frame animation, 5 shapes, 3 text elements per frame.

| Approach | Size | Notes |
|----------|------|-------|
| Full snapshots (no delta) | 400-600 KB | Baseline: every frame complete |
| Delta encoding (minified) | 80-120 KB | 80% smaller |
| Delta + GZIP | 15-25 KB | 95% smaller |
| Delta + Keyframes (every 30) | 100-140 KB | Slightly larger, 50× faster seek |
| Delta + Keyframes + GZIP | 20-30 KB | Best: size + speed |

---

## Export Formats

### To Animated PNG (.APNG)
- Decompose frames, encode each as PNG sub-image
- Metadata: duration per frame, loop mode
- Browser/OS support: Good (Chrome, Firefox, Safari 14+)
- Size: Lossless, larger than vgvec but universal

### To WebP Animation (.webp)
- Modern, excellent compression
- Browser support: Good (Chrome, Edge, Firefox 65+)
- VP8 codec, built-in animation support
- Size: ~50% smaller than APNG

### To GIF (.gif)
- Universal but limited (256 colors, large file)
- Fallback only
- Size: Large

### To Game Asset (Sprite Sheet + Timeline)
- Export as tiled PNG spritesheet + JSON manifest
- Manifest includes frame timings, layer structure, collision bounds
- Importable into AGCK or custom VG projects

---

## Implementation Roadmap

### Phase 1: Custom Binary Encoder/Decoder (~1-2 weeks)
- Byte-level format spec (below)
- C++ encoder (VG editor writes .vgvec binary)
- GDScript decoder (Godot game loads .vgvec binary)
- LZ4 integration for compression
- Unit tests: encode/decode roundtrip, edge cases
- **Target**: < 8ms parse time on reference hardware

### Phase 2: Msgpack Fallback (~3 days)
- Msgpack encoder (for version control, debugging)
- Fallback logic: if .vgvec fails, try .vgvec.msgpack
- CLI tool: convert between msgpack ↔ binary

### Phase 3: Vector Editor UI (~2-3 weeks)
- Drawing tools (pen, bezier, shapes, text)
- Selection, transform, boolean ops
- Auto-save as .vgvec.msgpack (dev format)
- Export to binary (.vgvec) with compression

### Phase 4: Animation Timeline (~1-2 weeks)
- Keyframe scrubber
- Onion-skin preview
- Frame add/delete
- Playback controls (test with binary format)

### Phase 5: Game Integration (~1 week)
- Export to APNG, WebP, GIF
- Game asset export: binary + metadata
- Undo/redo (leverages delta format)
- Performance profiling (ensure <8ms load times)

### Phase 6: Performance Optimization (~1 week)
- Lazy loading for long animations (stream frames from disk)
- Memory pooling for frame objects
- GPU-accelerated rendering (if bottleneck identified)

---

## Design Rationale

**Why custom binary (not JSON/Msgpack)?**
- Real-time game loading: **5-8ms binary parse << 15-20ms Msgpack parse**
- Frame budget at 60 FPS = 16.67ms; binary leaves safety margin, Msgpack eats it
- Loading 5 vector assets: binary = 25-40ms (unnoticeable), Msgpack = 75-100ms (stutter spike)
- Elite-style procedurally generated content needs predictable, fast loads
- Streaming unpacking: can load frame-by-frame instead of entire file at once

**Why LZ4 (not GZIP)?**
- GZIP: excellent compression (95%), but slow decompression (~50ms)
- LZ4: good compression (60-70%), 10-50× faster decompression (~1-5ms)
- For games: speed > size; LZ4 fits in frame budget, GZIP steals precious ms
- Decompression can be interruptible (decompress 1 frame at a time)

**Why delta encoding?**
- Vector animations smooth: most properties change slightly frame-to-frame
- Deltas capture this: store only changes, not full snapshots
- Dramatically reduces frame size (95%+ smaller when combined with sparse encoding)
- Natural fit with custom binary (easy to skip unchanged fields)

**Why keyframes?**
- Seeking frame 100 without keyframes = parse 100 frames from disk
- Keyframes every 30 frames cost ~1% file size, save 50× seek time
- Critical for streaming: load keyframe, then only needed deltas
- Sweet spot: 30 frames = ~1.25 sec at 24 FPS (typical scene duration)

**Why separate assets?**
- Colors, fonts, gradients are reused across many shapes/frames
- Reference by ID not value: "color_0" vs. full color definition
- Easier to edit (change color once, affects all frames)
- Smaller binary encoding (1-2 bytes ID vs. 8+ bytes color definition)

---

## Custom Binary Format Specification

```
.vgvec file format (little-endian)

[Header: 16 bytes]
  - Magic: "VGVC" (4 bytes)
  - Version: 1 (1 byte, u8)
  - Flags: 
    - bit 0: compression (0=none, 1=LZ4)
    - bit 1: keyframes (0=no, 1=yes)
    - bits 2-7: reserved
  - Keyframe interval (1 byte, u8) – every N frames store full snapshot (0=none, 30=typical)
  - Reserved (9 bytes)

[Metadata: variable]
  - Canvas width (2 bytes, u16)
  - Canvas height (2 bytes, u16)
  - FPS (1 byte, u8)
  - Total frames (2 bytes, u16)
  - Total animation duration in ms (4 bytes, u32)
  - Flags for animation (loop, reverse, etc.)

[Asset table: variable]
  - Color count (1 byte)
    - [For each color: r,g,b,a (4 bytes)]
  - Font count (1 byte)
    - [For each font: string length (1 byte) + name string]
  - Gradient count (1 byte)
    - [For each gradient: type (1 byte) + gradient definition (variable)]
  - Pattern count (1 byte)
    - [For each pattern: pattern definition (variable)]

[Frame index: 4 bytes × N]
  - For each frame: absolute file offset (4 bytes, u32)
  - Allows random access without parsing prior frames

[Compressed frame data: variable]
  - If compression=1: entire block is LZ4-compressed
  - If compression=0: uncompressed
  
  [Frame 0: full snapshot]
    - Shape count (2 bytes, u16)
    - [For each shape: type + all properties]
    - Path count (2 bytes, u16)
    - [For each path: data + properties]
    - Text count (1 byte, u8)
    - [For each text: content + properties]
  
  [Frame 1-N: deltas]
    - Modified shape IDs (varint-encoded count + list)
      - [For each: shape_id + property deltas]
    - Added shapes (varint count + full definitions)
    - Removed shape IDs (varint count + list)
    - Similar for paths and text
```

**Varint encoding** (space-efficient integers):
- 0-127: single byte (value)
- 128-16383: two bytes
- Larger: more bytes

**Property delta encoding**:
- Only store properties that changed
- Property ID (1 byte) + new value (variable size)
- Skip unchanged properties entirely

**Size estimate for 120-frame animation**:
- Header: ~50 bytes
- Assets: ~300 bytes (typical colors, fonts)
- Frame 0: ~800 bytes
- Frames 1-119: ~50 bytes each = 5,950 bytes
- Frame index: ~480 bytes
- **Total uncompressed**: ~8 KB
- **Total LZ4**: ~6 KB
- **Total LZ4+GZIP** (fallback distribution): ~4 KB

---

## Implementation Hints

- Use **varint encoding** for all counts/IDs: saves space on small values
- **Property IDs**: assign 0-255 to common properties (x, y, opacity, color, etc.)
- **Sparse storage**: only write properties that changed, reader fills in defaults
- **Lazy frame loading**: parse keyframe, then read individual frame deltas on demand
- **Memory mapping**: for large files, mmap the binary and parse in-place (zero-copy)
- **Streaming unpack**: can decompress one frame at a time with LZ4 frame format
- **Fallback cascade**: try to load .vgvec binary, fall back to .vgvec.msgpack if missing



