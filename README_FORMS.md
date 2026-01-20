# Application Support: GasicForm

The `GasicForm` class has been added to the project. This allows you to create VB6-style applications where UI events are automatically wired to your BASIC subroutines.

## How to use

1. **Create a Scene**: In Godot, create a new scene and use `GasicForm` as the root node.
2. **Add Controls**: Add child nodes like `Button`, `LineEdit`, `CheckBox`, etc.
3. **Name Controls**: Give them meaningul names (e.g., `cmdOK`, `txtInput`).
4. **Attach Script**: Attach a `.bas` script to the `GasicForm` node.
5. **Write Events**: In your BASIC script, define subroutines using the naming convention `ControlName_SignalName`.

### Supported Automations

| Control Type | Godot Signal | BASIC Subroutine | Arguments |
|--------------|--------------|------------------|-----------|
| **Button**   | `pressed`    | `Button1_Click`  | None      |
| **LineEdit** | `text_changed`| `Text1_Change`   | `txt`     |
| **Timer**    | `timeout`    | `Timer1_Timer`   | None      |

### Auto-Binding Controls

All child controls are automatically available as variables in your BASIC script.
For example, if you have a Button named `cmdOK`, you can access it directly:

```basic
Sub cmdOK_Click()
    ' Change the button's text directly
    cmdOK.text = "Clicked!"
    
    ' Show a message box
    MsgBox "You clicked the button!", 0, "Info"
End Sub

Sub Timer1_Timer()
    Print "Tick..."
    ' Stop the timer after one tick
    Timer1.stop()
End Sub
```
