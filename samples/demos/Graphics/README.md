# Graphics

Graphics rendering, visual effects, and shader examples.

## Overview

Demonstrations of Godot graphics capabilities via VisualGasic: particle effects, custom shaders, screen-space effects, procedural animation, and real-time rendering.

## Projects

| Project | Type | Focus |
|---------|------|-------|
| **VGPaint** | Interactive Canvas | Real-time drawing with brush effects, undo/redo |
| **VGMovie** | Animation Player | Frame-by-frame animation, timing, transitions |
| **Screensaver** | Visual Demo | Procedural patterns, animation loops, particle effects |
| **Screen_Space_Shaders** | Shader Effects | Post-processing: bloom, blur, color grading |
| **Sky_Shaders** | Procedural Skybox | Dynamic sky rendering, time-of-day, weather |

## Quick Start

1. Open project in Godot editor
2. Run the main scene (F5)
3. Interact with demo (draw, rotate, etc. as applicable)
4. Examine `.vg` script and associated `.gdshader` files

## Shader Concepts Covered

- Vertex/fragment shader basics
- Texture sampling and blending
- Screen-space effects (post-processing)
- Procedural generation (noise, fractals)
- Time-based animation in shaders

## Canvas & Drawing

- Real-time pixel manipulation
- Brush stroke rendering
- Layer compositing
- Undo/redo implementation

## Notes

- Shaders use Godot 4.6+ GLSL (GDShader language)
- Some effects require HDR or specific texture formats
- Performance varies by GPU; demos include optimization tips
- VGPaint demonstrates user interaction patterns for drawing applications
