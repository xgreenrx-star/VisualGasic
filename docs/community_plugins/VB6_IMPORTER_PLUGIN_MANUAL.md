# VB6 Importer Plugin Manual

This document contains VB6 importer details moved out of the core VisualGasic language manual.

## Scope

The VB6 importer is a plugin-oriented migration tool for legacy VB6 projects. It is not part of the core language runtime reference.

## Importing VB6 Projects

Use the importer to convert:
- `.vbp` project files (complete projects)
- `.frm` form files with controls and code
- `.bas` module files
- `.cls` class files

Controls are mapped to Godot equivalents, event handlers are wired to signals, and source is transformed to VisualGasic syntax.

## Supported VB6 Controls (Importer Mapping)

| VB6 Control | Godot Equivalent |
|-------------|------------------|
| CommandButton | Button |
| TextBox | LineEdit / TextEdit |
| Label | Label |
| CheckBox | CheckBox |
| OptionButton | CheckBox (radio mode) |
| ComboBox | OptionButton |
| ListBox | ItemList |
| PictureBox / Image | TextureRect |
| Frame | Panel |
| Timer | Timer |
| HScrollBar / VScrollBar | HScrollBar / VScrollBar |
| Shape | ColorRect |
| Line | Line2D |
| ProgressBar | ProgressBar |
| Slider | HSlider |
| TreeView / ListView | Tree |
| TabStrip | TabContainer |
| StatusBar | Panel |
| Toolbar | HBoxContainer |
| CommonDialog | FileDialog |
| RichTextBox | RichTextLabel |
| DTPicker | SpinBox |
| Winsock | StreamPeerTCP |
| Inet | HTTPRequest |
| MMControl | AudioStreamPlayer |
| FlexGrid / DataGrid | Tree |

## Third-Party OCX Controls (Import-Mapped)

- MSComctlLib controls (comctl32.ocx, mscomctl.ocx)
- MSComDlg controls (comdlg32.ocx)
- RichText controls (richtx32.ocx)
- MSFlexGrid (msflxgrd.ocx)
- Threed controls (3D panels, buttons)
- And many more

Compatibility note:
These OCX types are recognized by the importer and mapped to Godot/VG equivalents. This does not guarantee 1:1 runtime OCX behavior for every property, method, and event. Some controls require manual porting for advanced features. See `docs/vb6_ocx_porting.md`.

## VB6 Menu Support

Menus are converted as follows:
- Menu bars become `MenuBar` nodes
- Menu items become `PopupMenu` entries
- Separators (`Caption = "-"`) are preserved
- Shortcuts, checked, and enabled states are maintained
- Menu event handlers are wired to signals

## Property Mapping

### Position and Size
- Left, Top, Width, Height (TWIPS to pixels at 15:1)
- ClientLeft, ClientTop, ClientWidth, ClientHeight
- ScaleWidth, ScaleHeight

### Text and Appearance
- Caption, Text, Alignment
- Font properties (Name, Size, Bold, Italic, Underline)
- ForeColor, BackColor (including system colors)
- ToolTipText, Tag

### Control-Specific
- MultiLine, ScrollBars, PasswordChar, MaxLength (TextBox)
- Min, Max, Value, SmallChange, LargeChange (range controls)
- Interval (Timer)
- Visible, Enabled, Locked

### Form and Window
- WindowState, StartUpPosition
- ControlBox, MaxButton, MinButton
- BorderStyle, Moveable, ShowInTaskbar
- KeyPreview, Icon

## Control Arrays

Control arrays are handled with index-aware naming and access translation:
- `Num(0)` becomes `Num_0`
- `Num(Index).Caption` becomes `Num_Index.Caption`
- Event handlers with `Index` parameter are preserved

## Code Transformation

### Automatic Transformations
- `Let x = 5` -> `x = 5`
- `Set obj = New Class` -> `obj = New Class`
- `Debug.Print` -> `Print`
- `Me.Control` -> `Control`
- Type suffixes (for example `Dim x$`) -> explicit type declarations

### Error Handling Notes
- `On Error GoTo label` becomes a TODO comment for Try/Catch migration
- `On Error Resume Next` becomes a TODO comment for Try/Catch migration
- Standalone `End` is rewritten to safer exit forms

## VB6 Functions and Constants

The importer expects broad compatibility with standard VB6 function and constant families (string, conversion, math, date/time, type checks, file helpers, MsgBox constants, key constants, and related values).

## Import Report

After import, a report summarizes forms/modules imported, warnings, and manual follow-up actions.

## Programmatic Import API (Plugin)

Example API surface:

```vb
Dim result As Dictionary = VB6Importer.import_project("C:/Projects/MyApp.vbp")
Dim formResult As Dictionary = VB6Importer.import_form_file("C:/Projects/MainForm.frm")
Dim report As String = VB6Importer.generate_import_report(result)
VB6Importer.save_import_report(report, "MyApp")

If VB6Importer.is_control_supported("MSComctlLib.ProgressBar") Then
    Print "ProgressBar is import-mapped"
End If

Dim godotType As String = VB6Importer.get_godot_equivalent("VB.CommandButton")
```

## Ownership and Repository

This manual is intended for the community VB6 importer plugin repository.
