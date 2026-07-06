# Custom Controls

Reusable Godot Control nodes written in VisualGasic.

## Overview

Extends Godot's built-in Control node with custom widgets: buttons, panels, input fields, and layout managers. Useful as reference implementations for Godot-integrated VisualGasic code.

## Files

| File | Purpose |
|------|---------|
| `CustomButton.tscn` / `CustomButton.vg` | VB6-style button with hover/press states |
| `CustomPanel.tscn` / `CustomPanel.vg` | Draggable panel with title bar |
| `StatusBar.vg` | Status bar display (message, progress, icons) |

## Usage

1. Load `.tscn` file into Godot scene editor
2. Instantiate in your scene
3. Connect signals and properties as documented in corresponding `.vg` file

## Notes

- All controls use VB6-style property naming (`BackColor`, `FontName`, etc.)
- Compatible with Godot 4.6+ UI system
