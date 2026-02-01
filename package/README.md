# VisualGasic Project Template

Welcome to VisualGasic - Visual Basic 6 style development for Godot Engine!

## Quick Start

1. **Open this project in Godot 4.5+**
2. The VisualGasic plugin is already enabled
3. Look for the **Toolbox** panel on the left side
4. Click **"New Form"** to create your first form

## Creating Forms

1. Click "New Form" in the Toolbox
2. Enter a form name (e.g., "MainForm")
3. Choose a template (Blank, With Menu, Dialog, etc.)
4. Click Create

Your form will have:
- A `.tscn` scene file
- A `.vg` VisualGasic script file

## Adding Controls

1. Open your form's `.tscn` file
2. Drag controls from the Toolbox to your form
3. Double-click a control to add event handlers
4. Write BASIC code in the `.vg` file

## Example Code

```basic
' Form1.vg
Option Explicit

Private Sub Form_Load()
    Me.Caption = "Hello VisualGasic!"
End Sub

Private Sub Button1_Click()
    MsgBox "You clicked the button!"
End Sub

Private Sub btnQuit_Click()
    Unload Me
End Sub
```

## Features

- **VB6-style syntax** - Familiar BASIC programming
- **Auto-wiring** - Event handlers connect automatically
- **Immediate Window** - Test code interactively (bottom panel)
- **VB6 Import** - Import existing .frm files
- **Forms & Controls** - Windows, Buttons, Labels, TextBoxes, etc.

## Folder Structure

```
project/
├── addons/visual_gasic/    # The addon (don't modify)
├── forms/                   # Your form files
│   ├── MainForm.tscn
│   └── MainForm.vg
└── project.godot
```

## Tips

- Press **F5** to run your project
- Use `Debug.Print` to output to the Immediate Window
- Set a form as the main scene to start with it

## Documentation

See the full documentation at:
https://github.com/YourRepo/VisualGasic

## Troubleshooting

**Toolbox not showing?**
- Go to Project → Project Settings → Plugins
- Make sure "VisualGasic" is enabled

**Scripts not running?**
- Ensure your form's script is a `.vg` file (not `.gd`)
- Check the Output panel for errors

Enjoy coding with VisualGasic! 🚀
