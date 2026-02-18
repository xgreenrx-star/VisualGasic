# 3D Sky Shaders — VisualGasic Demo

A port of the [Godot 3D Sky Shaders](https://github.com/godotengine/godot-demo-projects/tree/master/3d/sky_shaders) demo, rewritten in **VisualGasic** (VB6-style syntax for Godot 4.5+).

## What It Shows

Real-time **volumetric clouds** with **physical atmospheric scattering** (Rayleigh + Mie), rendered entirely on the GPU. The VG script handles all CPU-side logic: camera movement, day/night cycle, sphere grid creation, and shader parameter control.

### Features

| Feature | Description |
|---------|-------------|
| **Physical Sky** | Rayleigh + Mie scattering — sky colors adjust automatically based on sun angle |
| **Volumetric Clouds** | Procedural clouds using fractal noise (fBm), raymarched on the GPU |
| **Day/Night Cycle** | Animated sun position drives sky color transitions (dawn → noon → dusk → night) |
| **Material Spheres** | 11×11 grid (121 spheres) with varying roughness (0.0–1.0) and metallic (0.0–1.0) |
| **Camera Controls** | First-person mouselook + FOV zoom |
| **Cloud Controls** | Real-time cloud coverage and density adjustment |

## Controls

| Key | Action |
|-----|--------|
| Mouse | Look around (when captured) |
| Escape | Toggle mouse capture |
| H | Toggle help overlay |
| S | Toggle material spheres |
| `[` / `]` | Slow down / speed up day cycle |
| ← / → | Adjust cloud coverage |
| ↑ / ↓ | Adjust cloud density |
| Scroll wheel | Zoom (FOV) |

## Running

1. Open this folder as a Godot 4.5+ project  
2. Make sure the VisualGasic addon is enabled (Project → Project Settings → Plugins)  
3. Run the **main.tscn** scene  

> **Note:** This demo uses the Forward+ renderer for best visual quality.

## How It Works

### Sky Shader (`sky_procedural_clouds.gdshader`)

The shader implements:
- **Analytic atmosphere** based on the Preetham model — Rayleigh scattering (blue sky) and Mie scattering (sun glow/haze)
- **Procedural clouds** using GPU-side hash-based 3D noise and fBm (fractal Brownian motion) — no external 3D texture assets needed
- **Cloud raymarching** — rays are cast from the camera through the cloud layer shell (6001.5 km – 6004 km altitude), accumulating density and lighting
- **Henyey-Greenstein phase function** for realistic cloud scattering

### VG Script (`sky_demo.vg`)

The VisualGasic script ports **both** `main.gd` and `spheres.gd` from the original demo into a single file:
- `Sub _Ready()` — initializes state, captures mouse, calls `CreateSpheres`
- `Sub CreateSpheres()` — nested `For` loops creating 121 `MeshInstance3D` spheres with `StandardMaterial3D` (roughness × metallic grid)
- `Sub _Process()` — smooth FOV lerp, day/night cycle advancement, sky shader parameter updates
- `Sub _Input()` — mouselook, mouse capture toggle, sphere toggle, FOV zoom, speed controls, cloud parameter adjustment

## Files

```
sky_demo.vg                      ← Main VG script (camera + spheres + controls)
sky_procedural_clouds.gdshader   ← GPU sky shader (atmosphere + clouds)
main.tscn                        ← Scene tree (Node3D + WorldEnvironment + Camera)
project.godot                    ← Project configuration
```

## VG Code Highlight

```vb
' Create 11x11 grid of material spheres
' Port of spheres.gd @tool script
Sub CreateSpheres()
    Dim r As Integer, m As Integer
    For r = 0 To SPHERE_GRID_SIZE - 1
        For m = 0 To SPHERE_GRID_SIZE - 1
            Dim sphere As Object
            Set sphere = MeshInstance3D.New()
            Dim mesh As Object
            Set mesh = SphereMesh.New()
            sphere.Mesh = mesh
            sphere.Position = Vector3(CSng(r) - 5.0, 0.0, CSng(m) - 5.0)

            Dim mat As Object
            Set mat = StandardMaterial3D.New()
            mat.AlbedoColor = Color(0.5, 0.5, 0.5)
            mat.Roughness = CSng(r) * 0.1
            mat.Metallic = CSng(m) * 0.1
            sphere.MaterialOverride = mat

            spheresNode.AddChild(sphere)
        Next m
    Next r
End Sub
```

## Technical Note

The original Godot demo uses 3D noise textures (`sampler3D`) loaded from binary assets for cloud rendering. This VG port replaces those with **procedural hash-based 3D noise** computed directly in the shader, making the demo fully self-contained — no external texture files needed.

---

*Part of the VisualGasic demo collection — bringing VB6-style programming to Godot.*
