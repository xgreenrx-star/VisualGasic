# Using Signals

In Godot, nodes emit **signals** when something interesting happens. Examples include a button being pressed, a timer finishing, or a body entering an area.

In Visual Gasic, these are handled similarly to VB6 events.

## Connecting Signals in the Editor

1.  Select a Node (e.g., a Timer) in the Scene dock.
2.  Go to the **Node** tab (next to Inspector).
3.  Double-click the signal (e.g., `timeout()`).
4.  In the connection dialog, verify the method name (usually `_on_Timer_timeout`) and connect it.

## Handling Signals in Code

When you connect a signal to your Visual Gasic script, you must define a Subroutine with the matching name.

```bas
' Connected from Timer -> timeout
Sub _on_Timer_timeout()
    Print "Timer finished!"
End Sub

' Connected from Button -> pressed
Sub _on_Button_pressed()
    Print "Button clicked!"
End Sub
```

## Connecting Signals via Code

You can also connect signals dynamically. Currently, this relies on finding the native node method.

> **Note**: Creating controls via code (e.g., `CreateButton`) automatically handles this for you by asking for a callback name.

```bas
' Example using CreateButton helper
CreateButton "Click Me", 100, 100, "OnMyClick"

Sub OnMyClick()
    Print "Code-connected signal worked!"
End Sub
```
