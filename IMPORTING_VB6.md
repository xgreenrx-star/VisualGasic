# Importing VB6 Projects into VisualGasic

VisualGasic includes a built-in importer for legacy Visual Basic 6.0 projects (`.vbp`) and forms (`.frm`).

## How to Import

The import tools are located in the **VisualGasic Toolbox** (usually docked in the bottom-left or part of the Scene dock).

### Import a Full Project

1.  Locate the **Toolbox** panel.
2.  Click the **Import VB6 Project...** button.
3.  Browse and select your `.vbp` file (e.g., `calculate.vbp`).

**What happens:**
*   **Forms**: Evaluated and converted to Godot Scenes (`.tscn`) in `res://start_forms/`.
*   **Code**: Extracted logic is saved as `.bas` files in `res://mixed/`.
*   **Modules**: Standard `.bas` modules are copied to `res://mixed/`.
*   **Signals**: Button clicks (`Command_Click`) and text changes (`Text_Change`) are automatically wired up to the generated script.

### Import a Single Form

1.  Click the **Import VB6 Form...** button in the **Toolbox**.
2.  Select a `.frm` file.
3.  The specific form is converted to a Scene and its code extracted.

## Supported Controls

The importer currently maps the following VB6 controls to VisualGasic widgets:

| VB6 Control | VisualGasic/Godot Node |
| :--- | :--- |
| `VB.Form` | `Control` (Root) |
| `VB.CommandButton` | `Button` |
| `VB.TextBox` | `LineEdit` |
| `VB.Label` | `Label` |
| `VB.CheckBox` | `CheckBox` |
| `VB.OptionButton` | `OptionButton` (ComboBox behavior) |
| `VB.ListBox` | `ItemList` |
| `VB.PictureBox` | `TextureRect` |
| `VB.Frame` | `Panel` (or `Frame` wrapper) |
| `VB.Timer` | `Timer` |

*Note: Dimensions are automatically converted from Twips to Pixels (15:1 ratio).*
