# Documentation Generator Example

A demo project showing how to use **Tools → Generate Documentation...** to
auto-generate API reference pages from well-documented `.vg` source files.

## What's Inside

| File | Description |
|------|-------------|
| `InventorySystem.vg` | RPG inventory with Enum, Type, Constants, Functions |
| `MathHelpers.vg` | Pure math utilities (Clamp, Lerp, Remap, Distance2D…) |
| `StringUtils.vg` | String padding, repeat, reverse, template engine |
| `Main.vg` | Entry point that demos all three modules |

## Doc-Comment Syntax

VisualGasic uses triple-apostrophe (`'''`) comments placed *directly above*
a declaration.  Supported tags:

```vb
''' Brief description of the function.
'''
''' Longer description that can span multiple lines.
'''
''' @param paramName  What this parameter does
''' @return What the function returns
''' @example
'''   Dim result As Integer
'''   result = MyFunc(42)
Function MyFunc(paramName As Integer) As Integer
    ...
End Function
```

## Pre-Generated Output

The `docs/api/` folder contains the **pre-generated Markdown** that the
Documentation Generator produces when you click OK with the default settings.

Browse the output:

- [docs/api/index.md](docs/api/index.md) — Module index
- [docs/api/InventorySystem.md](docs/api/InventorySystem.md) — Inventory API
- [docs/api/MathHelpers.md](docs/api/MathHelpers.md) — Math utilities API
- [docs/api/StringUtils.md](docs/api/StringUtils.md) — String utilities API
- [docs/api/Main.md](docs/api/Main.md) — Main entry point

## Try It Yourself

1. Open this project in Godot 4.6+
2. Enable the VisualGasic plugin (**Project → Project Settings → Plugins**)
3. Switch to the **Form Designer**
4. Click **Tools → Generate Documentation...**
5. Choose an output folder and format (Markdown, HTML, or Both)
6. Click **OK**

The generator scans every `.vg` file (excluding `addons/`) and produces
an index page plus one detail page per module.

## Options

| Option | Effect |
|--------|--------|
| **Output Folder** | Where to write the docs (default `res://docs/api`) |
| **Format** | Markdown (`.md`), HTML (`.html`), or Both |
| **Include Private** | Also document `Private` Subs/Functions/Dims |
| **Include Event Handlers** | Include `btn1_Click`-style handlers (on by default) |
