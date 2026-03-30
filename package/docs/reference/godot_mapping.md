# Godot API Mapping

Visual Gasic is designed to feel familiar to Visual Basic 6 users, who are used to **PascalCase** properties (e.g., `Text`, `Left`, `Caption`). Godot, however, uses **snake_case** (e.g., `text`, `position`, `rotation`).

To bridge this gap, Visual Gasic automatically attempts to map your property accesses to the correct Godot property.

## Property Name Resolution

When you access a property on an object (e.g., `Player.Velocity`), the interpreter performs the following steps:

1.  **Direct Match**: Checks if the object has a property exactly matching the name (`Velocity`).
2.  **Snake Case Conversion**: If not found, it converts the name to snake_case (`velocity`) and checks again.
3.  **Standard Aliases**: Checks a specialized alias map for common VB6 terms.

### Common Aliases

| Visual Gasic | Godot Property | Description |
| :--- | :--- | :--- |
| `.Left` | `.position.x` | Horizontal position. |
| `.Top` | `.position.y` | Vertical position. |
| `.Width` | `.size.x` | Width (for Controls). |
| `.Height` | `.size.y` | Height (for Controls). |
| `.Caption` | `.text` | Text content (Labels/Buttons). |
| `.Text` | `.text` | Text content. |
| `.Visible` | `.visible` | Visibility boolean. |

## Sub-Properties

You can chain properties just like in GDScript or C++.

```basic
' Accessing position.x via alias
Player.Left = 100

' Accessing via direct sub-property
Player.Position.x = 100
```

## Signals and Events

Signals are mapped to subroutines using the format `_On_NodeName_SignalName`.

*   **Node**: `Button1`
*   **Signal**: `pressed`
*   **Subroutine**: `Sub _On_Button1_Pressed()`

Ensure the Node Name in the scene tree matches the name in your subroutine.
