### 7. Helper Functions
The following helper functions are now available:

*   **`Int(n)`**: Returns the integer part of a number (floor).
*   **`Abs(n)`**: Returns the absolute value.
*   **`Rnd()`**: Returns a random float between 0 and 1.
*   **`Format(val, format_string)`**: Formats a value using a string pattern.
    *   Supports standard C-style flags (e.g. `Format(123, "%04d")` -> "0123")
    *   Supports basic "Percent" and "Currency" flags.
*   **`LoadPicture(path)`**: Loads an image resource (e.g. `.png`, `.jpg`) for use in `TextureRect` controls.

```basic
Sub Form_Load()
    ' Randomize seed
    Randomize
    
    ' Helper Math
    Dim n
    n = Int(Rnd() * 100)
    Print "Random Number: " & n
    
    ' Formatting
    Label1.text = "Score: " & Format(n, "%06d")
    
    ' Load Image
    Picture1.texture = LoadPicture("res://icon.svg")
End Sub
```
