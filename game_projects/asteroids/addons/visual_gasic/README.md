# VisualGasic — VB6-Style Programming for Godot 4

> **⚠️ EARLY BETA** — v3.2.0-beta1. This is an early beta release for testing and feedback.

## What is VisualGasic?

VisualGasic brings **Visual Basic 6–style event-driven programming** to Godot 4.
Write game logic in `.vg` files using familiar VB6 syntax with full IDE integration.

## Features

- **Event-Driven Programming** — Double-click a control, get a `Sub Button1_Click()` handler automatically
- **WYSIWYG Visual Gasic IDE** — Drag-and-drop UI builder with 40+ controls
- **JIT Compiler** — x86-64 native code generation, 2×–118× faster than GDScript
- **Full IDE** — IntelliSense, syntax highlighting, auto-indent, debugging, profiler
- **Three-Tier Toolbox** — 25 C++ defaults + 17 GDScript extended + unlimited custom components
- **Cross-Platform** — Linux, Windows, and macOS (x86_64)

## Quick Start

1. Copy this `addons/visual_gasic/` folder into your project's `addons/` directory
2. Go to **Project → Project Settings → Plugins** and enable **VisualGasic**
3. Create a new `.vg` file or use **File → New Form** to start with the Visual Gasic IDE

## Example

```vb
' Calculator.vg — event-driven calculator
Dim display As String

Sub Button1_Click()
    display = display & "1"
    Label1.Text = display
End Sub

Sub BtnEquals_Click()
    Dim result As Double
    result = Eval(display)
    Label1.Text = Str(result)
End Sub

Sub Form_Load()
    display = ""
    Label1.Text = "0"
End Sub
```

## Supported Platforms

| Platform | Architecture | Status |
|----------|-------------|--------|
| Linux    | x86_64      | ✅     |
| Windows  | x86_64      | ✅     |
| macOS    | x86_64      | ✅     |

## Requirements

- Godot 4.5 or later (4.6.1 recommended)

## License

GPLv3 — See [LICENSE](LICENSE) for details.

## Links

- **GitHub**: https://github.com/xgreenrx-star/VisualGasic
- **Tutorials**: See `docs/tutorials/` in the main repository
- **Issues**: https://github.com/xgreenrx-star/VisualGasic/issues
