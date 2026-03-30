# Signals and Events

In Godot, nodes emit **signals** when something happens — a button is pressed, a timer finishes, a body enters an area. VisualGasic handles signals using **VB6-style auto-wiring**, making event handling as easy as naming a subroutine.

## VB6-Style Auto-Wiring (Recommended)

The simplest way to handle events in VisualGasic is **auto-wiring**: name your subroutine `ControlName_EventName()` and it's automatically connected.

```vb
' Button click — just name it btnPlay_Click and it works
Sub btnPlay_Click()
    StartGame
End Sub

' Timer event
Sub Timer1_Timer()
    UpdateScore
End Sub

' TextBox change
Sub txtName_Change()
    Print "Name changed to: " & txtName.Text
End Sub
```

No signal wiring, no connection dialogs — just name the Sub and it's connected. This is how classic VB6 handles events, and VisualGasic brings the same approach to Godot.

### Common Event Patterns

| Sub Name | When Fired |
|----------|------------|
| `btnName_Click()` | Button is clicked |
| `btnName_MouseEnter()` | Mouse enters button area |
| `btnName_MouseExit()` | Mouse leaves button area |
| `Timer1_Timer()` | Timer interval fires |
| `txtName_Change()` | TextBox content changes |
| `lstItems_Click()` | ListBox item is selected |
| `cboOptions_Change()` | ComboBox selection changes |
| `Form_Load()` | Form/scene is loaded |
| `Form_Resize()` | Form/scene is resized |

## Creating Controls with Code

You can create controls dynamically with a single line. The callback is auto-wired:

```vb
' Create a button and wire its click handler in one line
CreateButton "Play", 100, 50, "OnPlayClicked"

Sub OnPlayClicked()
    Print "Let's go!"
End Sub
```

## Connecting Godot Signals

For standard Godot nodes (not VG controls), you can connect signals in two ways:

### In the Editor

1. Select a node (e.g., Timer) in the Scene dock.
2. Go to the **Node** tab (next to Inspector).
3. Double-click the signal (e.g., `timeout()`).
4. Connect it to your VisualGasic script.

### In Code

```vb
Sub _Ready()
    ' Connect a Godot node's signal to a handler
    $Timer.Connect("timeout", Callable(self, "OnTimerDone"))
End Sub

Sub OnTimerDone()
    Print "Timer finished!"
End Sub
```

## Next Steps

- **[VisualGasic Language Reference](../VisualGasic_Language_Reference.md)** — Complete language manual
- **[Controls Reference](../reference/CONTROLS_REFERENCE.md)** — All 40+ controls and their events
- **[Builtin Functions Reference](../reference/BUILTIN_FUNCTIONS_REFERENCE.md)** — 122+ built-in functions
