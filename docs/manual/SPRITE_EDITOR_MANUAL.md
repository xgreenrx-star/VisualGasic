# VisualGasic Sprite Editor Manual

> **Version**: 5.0.1 &nbsp;|&nbsp; **Last Updated**: April 2026

The VisualGasic Sprite Editor is a Piskel/Aseprite-inspired pixel art and animation editor embedded directly in the VG IDE. It's designed for creating 8-bit and 16-bit retro game graphics without ever leaving the editor.

![Sprite Editor Overview](../screenshots/sprite_editor_overview.png)
<!-- 📸 SCREENSHOT NEEDED: Full sprite editor window showing canvas, tool panel, palette, layers, and frame strip -->

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Interface Layout](#interface-layout)
3. [Drawing Tools](#drawing-tools)
4. [Color Management](#color-management)
5. [Retro Palettes](#retro-palettes)
6. [Layers](#layers)
7. [Animation Frames](#animation-frames)
8. [Selection & Clipboard](#selection--clipboard)
9. [Image Operations](#image-operations)
10. [Canvas Options & Toggles](#canvas-options--toggles)
11. [File Operations](#file-operations)
12. [Keyboard Shortcuts](#keyboard-shortcuts)
13. [Tips & Workflows](#tips--workflows)

---

## Getting Started

### Opening the Sprite Editor

The Sprite Editor can be opened from the VG IDE in several ways:

- Double-click a `.png`, `.webp`, or `.bmp` image file in the Project Explorer
- Select **Project → Tools → Sprite Editor** from the menu
- From the AGCK Builder, sprites open automatically when editing game assets

### Creating a New Sprite

Click **📄 New** in the toolbar (or press `Ctrl+N`) to create a new sprite. A dialog appears with preset sizes for common retro formats:

| Preset | Size |
|--------|------|
| 8×8 (tile) | 8 × 8 |
| 16×16 (NES) | 16 × 16 |
| 24×24 | 24 × 24 |
| 32×32 (SNES) | 32 × 32 |
| 48×48 | 48 × 48 |
| 64×64 | 64 × 64 |
| 128×128 | 128 × 128 |
| 256×256 | 256 × 256 |
| 16×32 (tall) | 16 × 32 |
| 32×64 (tall) | 32 × 64 |

You can also enter custom dimensions (up to 512×512).

![New Sprite Dialog](../screenshots/sprite_editor_new_dialog.png)
<!-- 📸 SCREENSHOT NEEDED: New Sprite dialog showing preset dropdown and width/height spinboxes -->

---

## Interface Layout

The editor uses an **HSplitContainer** layout with two main panels:

### Left Panel — Tools & Properties

The left panel is a scrollable sidebar containing:

1. **Drawing Tools** — grid of tool buttons
2. **Pen Size** — spinbox (1–32 px) with `[` / `]` shortcuts
3. **Mirror Toggles** — horizontal and vertical mirror drawing
4. **Option Toggles** — pixel grid, checker background, contiguous fill, tiled preview
5. **Ink Opacity** — slider (0%–100%) for partial-opacity drawing
6. **Colors** — primary/secondary swatches, swap button, recent colors, HSV picker, color ramp
7. **Palette** — retro palette selector with import/export and Lospec browser
8. **Layers** — layer list with add/delete/reorder/visibility/lock/merge/flatten/blend mode/opacity
9. **Preview** — live animation preview with play/pause, FPS, and onion skin toggle

### Right Panel — Canvas & Frames

1. **Toolbar** — file operations, undo/redo, resize, flip/rotate, outline, replace color, selection transforms, reference layer
2. **Canvas** — the main drawing surface with zoom/pan
3. **Frame Strip** — animation frame thumbnails with add/duplicate/delete/duration/tags

![Interface Layout](../screenshots/sprite_editor_layout.png)
<!-- 📸 SCREENSHOT NEEDED: Annotated screenshot showing left panel (tools, colors, layers) and right panel (toolbar, canvas, frames) -->

---

## Drawing Tools

The tool panel provides **19 drawing tools**, accessible via buttons or keyboard shortcuts.

![Drawing Tools Panel](../screenshots/sprite_editor_tools.png)
<!-- 📸 SCREENSHOT NEEDED: Close-up of the 4-column tool button grid -->

### Freehand Tools

| Tool | Icon | Shortcut | Description |
|------|------|----------|-------------|
| **Pen** | ✏️ | `P` | Draw pixels with the primary color (left-click) or secondary color (right-click). Respects pen size, mirror settings, and ink opacity. |
| **Eraser** | 🧹 | `E` | Erase pixels to transparent. |
| **Mirror Pen** | ↔️ | `H` | Draw with automatic horizontal symmetry. Combine with the Mirror V toggle for full 4-way symmetry. |
| **Dither Pen** | ▤ | `D` | Draw a checkerboard dither pattern — only fills pixels where `(x + y) % 2 == 0`. |
| **Lighten** | ☀ | `U` | Lighten existing pixels by 10% per stroke. |
| **Darken** | 🌑 | `J` | Darken existing pixels by 10% per stroke. |

### Shape Tools

| Tool | Icon | Shortcut | Description |
|------|------|----------|-------------|
| **Line** | 📏 | `L` | Click-drag to draw a straight line (Bresenham algorithm). Shows a real-time preview while dragging. |
| **Rectangle** | ▭ | `R` | Click-drag to draw a rectangle outline. |
| **Filled Rectangle** | ■ | `Shift+R` | Click-drag to draw a filled rectangle. |
| **Ellipse** | ○ | `O` | Click-drag to draw an ellipse outline. |
| **Filled Ellipse** | ● | `Shift+O` | Click-drag to draw a filled ellipse. |

### Fill & Picker Tools

| Tool | Icon | Shortcut | Description |
|------|------|----------|-------------|
| **Fill Bucket** | 🪣 | `G` | Flood-fill a region with the current color. Behavior depends on the **Contig Fill** toggle (see [Canvas Options](#canvas-options--toggles)). |
| **Color Picker** | 💉 | `I` | Click a pixel to sample its color and set it as the primary color. Samples the composite (all visible layers). |

### Selection Tools

| Tool | Icon | Shortcut | Description |
|------|------|----------|-------------|
| **Select** | ⬚ | `S` | Click-drag to create a rectangular selection. |
| **Lasso Select** | ⛏ | `Shift+S` | Freehand polygon selection — click and drag to draw a shape, release to select the bounding box. |
| **Magic Wand** | 🪄 | `W` | Click to select all contiguous pixels of the same color (within ~5% tolerance per channel). |
| **Move** | ✥ | `M` | Move a floating selection by dragging. |

### Special Tools

| Tool | Icon | Shortcut | Description |
|------|------|----------|-------------|
| **Outline** | 🔲 | `Shift+L` | Click to draw a 1px outline around all non-transparent pixels using the primary color. |
| **Gradient** | 🌈 | `Shift+G` | Click-drag to draw a linear gradient from primary color to secondary color. Works within the selection if one is active, otherwise fills the entire canvas. |

### Pen Size

Adjust the brush diameter (1–32 pixels) with the **Size** spinbox, or use the bracket keys:

- `[` — Decrease pen size
- `]` — Increase pen size

### Mirror Drawing

Two toggles below the tool grid:

- **↔ Mirror H** — Horizontal mirror (draws on both sides of the vertical center axis)
- **↕ Mirror V** — Vertical mirror (draws on both sides of the horizontal center axis)

When both are enabled, you get 4-way symmetry.

![Mirror Drawing Example](../screenshots/sprite_editor_mirror.png)
<!-- 📸 SCREENSHOT NEEDED: Example of 4-way mirror symmetry drawing a spaceship or butterfly -->

---

## Color Management

### Primary & Secondary Colors

The color panel shows two large swatches:

- **Primary** (left-click color) — default: black
- **Secondary** (right-click color) — default: white

Click either swatch to open Godot's built-in color picker. Press `X` to swap colors.

![Color Panel](../screenshots/sprite_editor_colors.png)
<!-- 📸 SCREENSHOT NEEDED: Color panel showing primary/secondary swatches, swap button, and recent colors -->

### Recent Colors

The 8 most recently used colors are shown in a row below the swatches. Left-click to set as primary, right-click to set as secondary.

### HSV Color Picker

Click **🎨 HSV** to open a dedicated HSV/HSL color picker dialog with:

- Color mode toggles (RGB, HSV, Raw)
- Sliders for each channel
- Hex input field
- Large color wheel/square

![HSV Picker](../screenshots/sprite_editor_hsv_picker.png)
<!-- 📸 SCREENSHOT NEEDED: HSV color picker dialog -->

### Color Ramp Generator

Click **🌈 Ramp** to generate a smooth gradient palette between the primary and secondary colors:

1. Set your start color as primary and end color as secondary
2. Click **🌈 Ramp**
3. Choose the number of steps (2–64)
4. Click **OK** — the ramp replaces the palette grid

![Color Ramp](../screenshots/sprite_editor_color_ramp.png)
<!-- 📸 SCREENSHOT NEEDED: Color ramp dialog and resulting palette -->

### Ink Opacity

The **Ink** slider (0%–100%) controls pen opacity. At less than 100%, pen strokes blend with existing pixels rather than replacing them outright. This is useful for:

- Soft shading passes
- Building up color gradually
- Transparent overlays

---

## Retro Palettes

The palette panel includes **9 built-in retro palettes**:

| Palette | Colors | Description |
|---------|--------|-------------|
| **NES** | 56 | Full NES PPU palette (4 rows of 14) |
| **GameBoy** | 4 | Classic green-tint DMG palette |
| **GameBoy Pocket** | 4 | Gray-scale GBP palette |
| **C64** | 16 | Commodore 64 palette |
| **CGA** | 16 | IBM CGA 16-color palette |
| **SNES** | 16 | Super Nintendo base palette |
| **PICO-8** | 16 | PICO-8 fantasy console palette |
| **Endesga 32** | 32 | Popular pixel art palette by Endesga |
| **Grayscale** | 16 | 16-step grayscale ramp |

Select a palette from the dropdown to load it into the swatch grid. Left-click a swatch to set primary color, right-click for secondary.

![Palette Panel](../screenshots/sprite_editor_palette.png)
<!-- 📸 SCREENSHOT NEEDED: Palette dropdown expanded showing palette names, with NES palette swatches visible -->

### Import & Export Palettes

- **📂 Import Palette** — Load palettes from `.gpl` (GIMP), `.hex`, `.pal` (Paint.NET), or `.txt` files
- **💾 Export Palette** — Save the current palette as a GIMP `.gpl` file

### Browse Lospec (Online Palette Library)

Click **🌐 Browse Lospec (4000+ palettes)** to open the Lospec palette browser. This connects to [lospec.com](https://lospec.com) — the largest community-curated collection of pixel art palettes.

**Features:**
- **Tag search** — Filter by tags like `gameboy`, `retro`, `fantasy`, `pastel`, `warm`, `endesga`, etc.
- **Sort** — Popular (most downloaded), Newest, or Default
- **Paginated browsing** — Navigate pages of 10 results at a time
- **One-click install** — Double-click a palette or select it and click **✅ Install Selected Palette**

Each result shows the palette name, color count, download count, and a mini swatch preview. When installed, the palette replaces the current swatch grid.

> **Note:** Requires an internet connection. Palette data is fetched live from the Lospec API.

---

## Layers

The Layers panel provides a full compositing layer system for non-destructive editing.

![Layers Panel](../screenshots/sprite_editor_layers.png)
<!-- 📸 SCREENSHOT NEEDED: Layer panel showing multiple layers, lock icon, visibility icons, and button row -->

### Layer Controls

| Button | Icon | Description |
|--------|------|-------------|
| Add | `+` | Add a new transparent layer above the current one |
| Delete | `−` | Delete the selected layer (minimum 1 layer) |
| Move Up | `▲` | Move the selected layer up in the stack |
| Move Down | `▼` | Move the selected layer down in the stack |
| Visibility | `👁` | Toggle layer visibility on/off |
| Merge Down | `⊞` | Merge the selected layer into the one below it |
| Lock | `🔒` | Toggle layer lock — prevents drawing, filling, or editing on the locked layer |
| Flatten | `≡` | Flatten all visible layers into a single layer |

### Layer Properties

Each layer has:

- **Name** — auto-assigned as "Layer 1", "Layer 2", etc.
- **Visibility** — hidden layers are excluded from compositing and export
- **Opacity** — per-layer opacity slider (0%–100%) in the layer panel
- **Locked** — locked layers show a 🔒 icon and reject all edits
- **Blend Mode** — dropdown with 6 blend modes

### Blend Modes

| Mode | Description |
|------|-------------|
| **Normal** | Standard alpha blending (default) |
| **Multiply** | Darkens — multiplies RGB channels (`dst × src`) |
| **Screen** | Lightens — inverse multiply (`1 − (1−dst)(1−src)`) |
| **Overlay** | Multiply for darks, Screen for lights — increases contrast |
| **Add** | Additive blending — clamped to white |
| **Subtract** | Subtractive blending — clamped to black |

### Layer Compositing Order

Layers are composited **bottom to top** (the last layer in the list draws first). This matches the convention in Photoshop, Aseprite, and GIMP.

---

## Animation Frames

The frame strip at the bottom of the canvas area provides sprite sheet animation support.

![Frame Strip](../screenshots/sprite_editor_frames.png)
<!-- 📸 SCREENSHOT NEEDED: Frame strip showing 4-5 frame thumbnails with the active frame highlighted in blue -->

### Frame Controls

| Button | Icon | Description |
|--------|------|-------------|
| Add Frame | `+` | Add a new blank frame after the current one |
| Duplicate Frame | `⊡` | Duplicate the current frame (all layers) |
| Delete Frame | `−` | Delete the current frame (minimum 1 frame) |
| Frame Duration | `⏱` | Set per-frame duration in milliseconds (shortcut: `F`) |
| Animation Tags | `🏷` | Manage named frame range groups |

### Per-Frame Duration

Each frame can have its own duration (in milliseconds), independent of the global FPS setting. This is useful for:

- Hold frames (longer duration for emphasis)
- Variable-speed walk cycles
- Dramatic pauses in cutscene animations

Press `F` or click `⏱` to set the duration for the current frame.

### Animation Tags

Animation tags let you organize frames into named groups (e.g., "Idle", "Walk", "Attack"). Click `🏷` to open the tag manager:

1. Enter a tag name
2. Set the **From** and **To** frame numbers
3. Click **+ Add Tag**

Tags are stored with the sprite data and can be used to reference animation ranges in your game code.

![Animation Tags](../screenshots/sprite_editor_tags.png)
<!-- 📸 SCREENSHOT NEEDED: Animation Tags dialog showing a list of tags with From/To frame numbers -->

### Animation Preview

The Preview panel on the left sidebar shows a live animation preview:

- **▶ / ⏸** — Play / Pause the animation
- **FPS** — Global frames per second (1–60, default 8)
- **Onion** — Toggle onion skinning (see below)

### Onion Skinning

When enabled, onion skinning overlays neighboring frames on the canvas:

- **Previous frames** — shown in <span style="color:red">red</span> tint (1 frame back by default)
- **Next frames** — shown in <span style="color:blue">blue</span> tint (1 frame forward by default)

This helps you align movement between frames for smooth animation.

![Onion Skinning](../screenshots/sprite_editor_onion_skin.png)
<!-- 📸 SCREENSHOT NEEDED: Canvas with onion skin showing red previous frame and blue next frame overlaid -->

---

## Selection & Clipboard

### Creating Selections

| Method | Description |
|--------|-------------|
| **Rectangle Select** (`S`) | Click-drag to select a rectangular region |
| **Lasso Select** (`Shift+S`) | Freehand polygon selection (bounding box) |
| **Magic Wand** (`W`) | Select contiguous same-color pixels |
| **Select All** (`Ctrl+A`) | Select the entire canvas |

Selections are shown with a white dashed border.

### Clipboard Operations

| Action | Shortcut | Description |
|--------|----------|-------------|
| **Copy** | `Ctrl+C` | Copy selection (or entire canvas) to clipboard. Also pushes to the **system clipboard** for pasting into external apps. |
| **Cut** | `Ctrl+X` | Copy selection to clipboard, then clear the selected region to transparent. |
| **Paste** | `Ctrl+V` | Paste from clipboard. Always checks the **system clipboard** first (for pasting from external apps), then falls back to the internal clipboard. |
| **Delete** | `Delete` | Clear the selected region to transparent (no clipboard copy). |

### System Clipboard Integration

The sprite editor supports **cross-application copy/paste** of images:

- **Copy to external**: When you copy in the sprite editor, the image is saved as a temporary PNG and pushed to the system clipboard via `xclip` (Linux), `osascript` (macOS), or `PowerShell` (Windows).
- **Paste from external**: When you paste, the editor first checks the system clipboard for an image. If found, it's imported and pasted onto the active layer.

> **Linux requirement**: `xclip` must be installed (`sudo apt install xclip`).

### Selection Transforms

The toolbar provides three buttons for transforming just the selected region:

| Button | Description |
|--------|-------------|
| **↔ Sel** | Flip the selected pixels horizontally |
| **↕ Sel** | Flip the selected pixels vertically |
| **↻ Sel** | Rotate the selected pixels 90° clockwise |

Additional transforms available via code: `rot180`, `scale_2x`, `scale_half`.

### Brush Stamps

You can capture a selection as a reusable brush stamp:

1. Make a selection around the pixels you want to use as a brush
2. The brush stamp is captured from the selection
3. Paint with the stamp — it blends onto the canvas centered at the cursor

This is useful for repeating patterns, decorative elements, or custom-shaped brushes.

---

## Image Operations

The toolbar provides quick access to whole-image operations:

![Toolbar](../screenshots/sprite_editor_toolbar.png)
<!-- 📸 SCREENSHOT NEEDED: Close-up of the toolbar showing all buttons from ← Form through Ref -->

| Button | Description |
|--------|-------------|
| **↔ Flip H** | Flip the active layer horizontally |
| **↕ Flip V** | Flip the active layer vertically |
| **↻ Rot90** | Rotate the active layer 90° clockwise (swaps canvas dimensions if non-square) |
| **🔲 Outline** | Draw a 1px outline around all non-transparent pixels using the primary color |
| **🔄 Replace** | Replace all pixels of the **primary color** with the **secondary color** on the active layer |
| **📎 Ref** | Load a reference image (see below) |
| **⊞ Resize** | Open the Resize Canvas dialog |

### Outline

The outline operation scans every transparent pixel and checks its 4-connected neighbors. If any neighbor is non-transparent, the pixel is set to the primary color. This is a fast way to add borders to sprites.

### Replace Color

Replaces **every pixel** matching the primary color with the secondary color on the active layer. To use:

1. Pick the color you want to replace (use the Color Picker tool `I` to sample it)
2. Set the replacement color as the secondary color
3. Click **🔄 Replace**

### Reference Layer

Click **📎 Ref** to load any image file as a non-exportable reference layer. The reference:

- Is displayed behind the canvas at 40% opacity
- Is automatically resized to fit the canvas dimensions
- Is **not** included in exports or saves
- Useful for tracing concept art, rotoscoping, or matching proportions

### Resize Canvas

Click **⊞ Resize** (or use the toolbar button) to change the canvas dimensions. The existing artwork is placed at the top-left corner of the new canvas — pixels outside the new bounds are cropped, and new space is filled with transparency.

![Resize Dialog](../screenshots/sprite_editor_resize.png)
<!-- 📸 SCREENSHOT NEEDED: Resize Canvas dialog showing current size and width/height spinboxes -->

---

## Canvas Options & Toggles

The tool panel includes several toggles that control canvas display and tool behavior:

![Canvas Options](../screenshots/sprite_editor_options.png)
<!-- 📸 SCREENSHOT NEEDED: Close-up of the toggle buttons row: Grid, Checker, Contig Fill, Tiled -->

### Pixel Grid

**Toggle**: `Grid` checkbox

When enabled (default), a subtle pixel grid is drawn over the canvas when zoomed to 4× or higher. This helps you see individual pixel boundaries.

### Checker Background

**Toggle**: `Checker` checkbox

When enabled (default), transparent areas are shown as a light/dark checkerboard pattern. When disabled, transparent areas appear as a flat dark gray — useful for working with sprites that have light-colored edges.

### Contiguous Fill

**Toggle**: `Contig Fill` checkbox

Controls the behavior of the **Fill Bucket** tool:

- **On** (default): Only fills contiguous pixels of the same color (flood fill)
- **Off**: Replaces **all** pixels of the same color across the entire canvas (global replace)

### Tiled Preview

**Toggle**: `Tiled` checkbox

When enabled, the canvas shows 8 ghost copies of the sprite surrounding the main canvas at 40% opacity. This is essential for:

- Creating seamless tileable textures
- Verifying that tile edges match up
- Designing wallpapers and background patterns

![Tiled Preview](../screenshots/sprite_editor_tiled.png)
<!-- 📸 SCREENSHOT NEEDED: Canvas with tiled preview enabled showing 9 copies of a tile pattern -->

### Ink Opacity

**Slider**: `Ink` (0%–100%)

Controls the opacity of pen strokes. At 100% (default), strokes fully replace existing pixels. At lower values, strokes blend with the existing content:

- 50% opacity pen strokes build up color gradually
- Useful for soft shading and transparent overlays
- Applies to all pen-based tools (Pen, Mirror Pen, Dither Pen)

---

## File Operations

### Save (`Ctrl+S`)

Saves the composited sprite as PNG to the current file path. If no path has been set, opens the Export dialog.

### Open (`Ctrl+O`)

Opens a file dialog to load an existing image (`.png`, `.webp`, `.bmp`). The image is imported as a single layer at its native resolution.

### Export (`Ctrl+E`)

Opens a file dialog to export the sprite:

- **Single frame** — exports the composited image as PNG
- **Multiple frames** — exports a **horizontal spritesheet** with all frames side by side

### New (`Ctrl+N`)

Creates a new blank sprite with the selected preset or custom dimensions.

---

## Keyboard Shortcuts

### File & Edit

| Shortcut | Action |
|----------|--------|
| `Ctrl+N` | New Sprite |
| `Ctrl+O` | Open Image |
| `Ctrl+S` | Save |
| `Ctrl+E` | Export Spritesheet |
| `Ctrl+Z` | Undo (up to 100 levels) |
| `Ctrl+Y` | Redo |
| `Ctrl+A` | Select All |
| `Ctrl+C` | Copy |
| `Ctrl+X` | Cut |
| `Ctrl+V` | Paste |
| `Delete` | Clear selection to transparent |

### Tools

| Shortcut | Tool |
|----------|------|
| `P` | Pen |
| `E` | Eraser |
| `L` | Line |
| `Shift+L` | Outline |
| `R` | Rectangle |
| `Shift+R` | Filled Rectangle |
| `O` | Ellipse |
| `Shift+O` | Filled Ellipse |
| `G` | Fill Bucket |
| `Shift+G` | Gradient |
| `I` | Color Picker |
| `S` | Rectangle Select |
| `Shift+S` | Lasso Select |
| `M` | Move |
| `H` | Mirror Pen |
| `D` | Dither Pen |
| `U` | Lighten |
| `J` | Darken |
| `W` | Magic Wand |

### Miscellaneous

| Shortcut | Action |
|----------|--------|
| `X` | Swap primary/secondary colors |
| `[` | Decrease pen size |
| `]` | Increase pen size |
| `F` | Set frame duration |
| `Mouse Wheel Up` | Zoom in |
| `Mouse Wheel Down` | Zoom out |
| `Middle Mouse Drag` | Pan the canvas |
| `Right-Click` | Draw with secondary color |

---

## Tips & Workflows

### Pixel Art Best Practices

1. **Start small** — 16×16 or 32×32 sprites are easier to iterate on
2. **Use a limited palette** — the built-in retro palettes enforce good color discipline
3. **Work in layers** — separate body, outline, shading, and effects onto different layers
4. **Use mirror drawing** — great for symmetrical characters, spaceships, and UI elements

### Animation Workflow

1. Create your first frame (idle pose)
2. **Duplicate Frame** (`⊡`) to use the previous frame as a starting point
3. Enable **Onion Skinning** to see the previous/next frames while editing
4. Use **Per-Frame Duration** (`F`) for hold frames or variable timing
5. **Animation Tags** help organize walk cycles, attacks, and idle animations
6. Export as a horizontal spritesheet for use in Godot's `AnimatedSprite2D`

### Tile Creation Workflow

1. Enable **Tiled Preview** to see how your tile repeats
2. Draw your base pattern
3. Focus on the edges — make sure they match seamlessly
4. Use the **Gradient** tool for smooth sky or ground tiles
5. Export at native resolution for crisp pixel-perfect tiles

### Color Workflow

1. Pick a base palette (NES, PICO-8, or Endesga 32 are popular choices)
2. Use the **Color Ramp** generator to create smooth shading ramps
3. The **HSV Picker** gives precise control for custom colors
4. **Replace Color** is a fast way to re-skin sprites or try different color schemes

### Using Reference Layers

1. Click **📎 Ref** and load your concept art or reference sketch
2. The reference appears at 40% opacity behind your canvas
3. Trace over it on your working layers
4. The reference is never exported — it's purely a visual guide

### Non-Destructive Editing

- Use **layers** to keep elements separate
- The **Lock** button prevents accidental edits to finished layers
- **Blend modes** let you experiment with lighting effects (Add for glow, Multiply for shadows)
- **Flatten** only when you're ready to finalize
- **Undo** supports up to 100 levels

---

## Canvas Navigation

| Action | Control |
|--------|---------|
| **Zoom In** | Mouse wheel up (up to 64×) |
| **Zoom Out** | Mouse wheel down (down to 1×) |
| **Pan** | Middle-mouse drag |
| **Default Zoom** | 12× (fits most sprite sizes comfortably) |

The current zoom level and canvas size are displayed in the toolbar:

```
32×32    12×
```

---

## Export Formats

| Format | When |
|--------|------|
| **PNG** (single frame) | Sprites with 1 frame export as a standard PNG |
| **PNG Spritesheet** (multi-frame) | Sprites with 2+ frames export as a horizontal strip (`width × frames`, `height`) |

All exports use **RGBA8** format with full transparency support.

---

## Screenshot Checklist

The following screenshots are needed for this manual. Save them to `docs/screenshots/` with the specified filenames:

| Filename | Description |
|----------|-------------|
| `sprite_editor_overview.png` | Full editor window with a sample sprite |
| `sprite_editor_new_dialog.png` | New Sprite dialog with preset dropdown |
| `sprite_editor_layout.png` | Annotated layout showing all panels |
| `sprite_editor_tools.png` | Close-up of the drawing tools grid |
| `sprite_editor_mirror.png` | Example of 4-way mirror symmetry |
| `sprite_editor_colors.png` | Color panel with swatches and recent colors |
| `sprite_editor_hsv_picker.png` | HSV color picker dialog |
| `sprite_editor_color_ramp.png` | Color ramp dialog and resulting palette |
| `sprite_editor_palette.png` | Palette dropdown with NES swatches |
| `sprite_editor_layers.png` | Layer panel with multiple layers |
| `sprite_editor_frames.png` | Frame strip with multiple thumbnails |
| `sprite_editor_tags.png` | Animation Tags dialog |
| `sprite_editor_onion_skin.png` | Onion skin overlay example |
| `sprite_editor_toolbar.png` | Full toolbar close-up |
| `sprite_editor_resize.png` | Resize Canvas dialog |
| `sprite_editor_options.png` | Canvas toggle buttons |
| `sprite_editor_tiled.png` | Tiled preview mode example |
