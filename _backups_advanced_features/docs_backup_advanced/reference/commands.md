# Command Reference

This document lists all built-in commands and functions available in Visual Gasic.

## Control Flow

| Keyword | Description |
| :--- | :--- |
| `If ... Then ... Else ... EndIf` | Conditional execution. |
| `For ... To ... Step ... Next` | Loop with a counter. |
| `While ... Wend` | Loop while a condition is true. |
| `Sub ... End Sub` | Defines a subroutine (no return value). |
| `Function ... End Function` | Defines a function (returns a value). |
| `Call Name(Args)` | Executes a subroutine. |
| `Exit Sub/Function` | Exits the current scope immediately. |

## Variable Declarations

| Keyword | Description |
| :--- | :--- |
| `Dim Name [As Type] [= Value]` | Declares a local variable. |
| `Global Name [= Value]` | Declares a global variable accessible across subroutines. |

## Input & Output

| Function | Description |
| :--- | :--- |
| `Print Expression` | Prints output to the Godot console. |
| `Input("Prompt")` | *(Console only)* Reads a line from standard input. |
| `GetKey()` | Returns the scancode of the last key pressed. |
| `IsKeyDown(Params)` | Checks if a specific key is currently held down. |
| `GetMouseX()` / `GetMouseY()` | Global mouse coordinates. |
| `IsMouseButtonDown(Index)` | Checks mouse button state (1=Left, 2=Right). |

## UI & Object Creation

These helper functions create Godot Nodes dynamically and return a reference to them.

| Function | Description |
| :--- | :--- |
| `CreateButton(Text, X, Y, W, H)` | Creates a UI Button. |
| `CreateLabel(Text, X, Y)` | Creates a Text Label. |
| `CreateInput(Text, X, Y, W, H)` | Creates a LineEdit (Input Box). |

## Physics & Interaction

| Function | Description |
| :--- | :--- |
| `IsOnFloor(CharacterBody)` | Returns true if the body is on the floor (requires `MoveAndSlide`). |
| `IsColliding(RayCast)` | Returns true if a raycast is colliding. |
| `GetCollisionCount(Body)` | Returns number of collision contacts. |
| `GetCollisionObject(Body, Idx)` | Gets the specific collider object. |

## Math & Utility

| Function | Description |
| :--- | :--- |
| `Abs(Num)` | Absolute value. |
| `Sin(Rad)`, `Cos(Rad)` | Trigonometric functions. |
| `Sqrt(Num)` | Square root. |
| `Rnd()` | Returns a random float between 0.0 and 1.0. |
| `Int(Num)` | Truncates decimal part. |
| `Timer()` | Returns time since startup (milliseconds). |
| `Sleep(Ms)` | Pauses execution. |
