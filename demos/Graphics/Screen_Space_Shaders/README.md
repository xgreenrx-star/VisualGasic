# Screen Space Shaders — VisualGasic Demo

A port of the [Godot 2D Screen Space Shaders](https://github.com/godotengine/godot-demo-projects/tree/master/2d/screen_space_shaders) demo, rewritten in **VisualGasic** (VB6-style syntax for Godot 4.5+).

## What It Shows

Full-screen 2D post-processing shader effects applied over an animated scene drawn entirely in VG code. Cycle through **11 different effects** with a single keypress:

| # | Effect | Description |
|---|--------|-------------|
| 1 | **None** | Original scene — no shader |
| 2 | **Whirl** | Spiral distortion radiating from center |
| 3 | **Blur** | Mipmap-based gaussian-style blur |
| 4 | **Pixelize** | Retro mosaic / low-resolution effect |
| 5 | **Sepia** | Warm vintage photo tint |
| 6 | **Negative** | Full color inversion |
| 7 | **Mirage** | Animated heat-wave distortion |
| 8 | **BCS** | Brightness / Contrast / Saturation adjustment |
| 9 | **Normalized** | Mathematical color normalization |
| 10 | **Chromatic Aberration** | Radial RGB channel splitting *(custom)* |
| 11 | **CRT Scanlines** | Barrel distortion + scanlines + vignette *(custom)* |

## Controls

| Key | Action |
|-----|--------|
| ← / → | Cycle through shader effects |
| Space | Toggle help overlay |

## Running

1. Open this folder as a Godot 4.5+ project  
2. Make sure the VisualGasic addon is enabled (Project → Project Settings → Plugins)  
3. Run the **main.tscn** scene  

## How It Works

The VG script (`screen_shaders.vg`) draws a colorful animated landscape scene — sky gradient, sun with glow, floating clouds, layered mountains, animated water, swaying trees, and bouncing balls — entirely using `Sub _Draw()`.

A `CanvasLayer` with a full-screen `ColorRect` sits above the scene. When you switch effects, the VG script loads the corresponding `.gdshader` file into a `ShaderMaterial` and applies it to the rect. The GPU then processes the entire screen through the shader in real time.

> **Key insight:** The `.gdshader` files are pure GPU code (Godot's shading language, similar to GLSL) — they don't need porting. VisualGasic handles the CPU-side logic (animation, input, shader switching) while the GPU handles the visual effects.

## Files

```
screen_shaders.vg          ← Main VG script (animation + controls)
main.tscn                  ← Scene tree (Node2D + CanvasLayer + ColorRect)
project.godot              ← Project configuration
shaders/
  whirl.gdshader           ← Spiral distortion
  blur.gdshader            ← Gaussian-style blur
  pixelize.gdshader        ← Mosaic effect
  sepia.gdshader           ← Sepia tone
  negative.gdshader        ← Color inversion
  mirage.gdshader          ← Heat wave
  BCS.gdshader             ← Brightness/Contrast/Saturation
  normalized.gdshader      ← Color normalization
  contrasted.gdshader      ← Contrast shift
  chromatic_aberration.gdshader ← RGB split (custom)
  crt_scanlines.gdshader   ← CRT monitor (custom)
```

## VG Code Highlight

```vb
' Cycle through effects with arrow keys
If Input.IsActionJustPressed("ui_right") Then
    currentEffect = currentEffect + 1
    If currentEffect >= NUM_EFFECTS Then currentEffect = 0
    ApplyEffect
End If

' Load and apply a shader to the full-screen rect
Sub SetShader(rect As Object, shaderPath As String)
    Dim mat As Object
    Set mat = ShaderMaterial.New()
    Dim shd As Object
    Set shd = ResourceLoader.Load(shaderPath)
    mat.Shader = shd
    rect.Material = mat
End Sub
```

---

*Part of the VisualGasic demo collection — bringing VB6-style programming to Godot.*
