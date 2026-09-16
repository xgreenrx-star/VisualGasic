# Custom Widgets

Pre-built UI widget scenes and components for rapid Godot UI prototyping.

## Overview

Collection of reusable Godot scenes (`.tscn` files) representing common UI elements: buttons, dialogs, forms, lists, text input, and progress indicators. Pairs with supporting GDScript code (`.gd` files).

## Widget Categories

### Dialog & Window Widgets
| Widget | File | Purpose |
|--------|------|---------|
| Common Dialog | `CommonDialog.tscn` + `common_dialog.gd` | Modal dialog box with OK/Cancel buttons |
| Frame | `Frame.tscn` + `frame.gd` | Titled container/panel |

### Input Widgets
| Widget | File | Purpose |
|--------|------|---------|
| Line (Text Input) | `Line.tscn` | Single-line text field |
| Memo | `Memo.tscn` | Multi-line text editor |
| Option | `Option.tscn` | Dropdown selector |
| OptionButton | `OptionButton.tscn` | Button-style dropdown |

### Display Widgets
| Widget | File | Purpose |
|--------|------|---------|
| ColorBtn | `ColorBtn.tscn` | Colored button with custom styling |
| RedButton | `RedButton.tscn` | Red accent button variant |
| ProgressBar | `ProgressBar.tscn` | Progress indicator bar |
| ItemList | `ItemList.tscn` | Scrollable list of items |
| RichText | `RichText.tscn` | Rich text display with formatting |

### Layout Widgets
| Widget | File | Purpose |
|--------|------|---------|
| Form | `Form.tscn` | Multi-field form container |
| FlexGrid | `FlexGrid.tscn` | Flexible grid layout |
| Line | `Line.tscn` | Visual separator line |
| Shape | `Shape.tscn` | Geometric shape display |

### 3D Widgets
See `3d/` subdirectory for 3D visualization components.

## Usage

1. Open Godot scene editor
2. Drag `.tscn` file into your scene
3. Connect signals and customize properties
4. Reference associated `.gd` file for scripting API

## Notes

- All widgets follow VB6-style naming conventions where applicable
- Designed for educational use and rapid prototyping
- Production use should evaluate performance and customize styling for brand consistency
