# VisualGasic Language Reference

VisualGasic supports standard BASIC syntax along with Game Development specifics.

## Core Keywords
Standard flow control and declaration.

| Keyword | Description |
| :--- | :--- |
| `Dim` | Declare a variable. |
| `Global` | Declare a global variable accessible across scripts. |
| `Set` | Assign an object reference (Node) to a variable. |
| `If ... Then ... Else ... End If` | Conditional logic. |
| `For ... To ... Next` | Counting loops. |
| `Do ... Loop` | Condition loops. |
| `Sub ... End Sub` | Define a subroutine (void function). |
| `Function ... End Function` | Define a function returning a value. |

## Built-in Functions

### Game Engine
| Function | Description |
| :--- | :--- |
| `SetScreenSize(w, h)` | Set the logical window size. |
| `ScreenSize` | Access the screen dimensions (e.g. `ScreenSize.x`). |
| `ChangeScene(path)` | Switch to another `.tscn` or `.bas` file. |
| `HasCollided(node)` | Check if a node has collided. |
| `GetCollider()` | Get the object involved in the last collision. |
| `IsKeyPressed(key)` | Check raw key input. |
| `IsActionPressed(action)` | Check input map action. |

### Drawing & Audio
| Function | Description |
| :--- | :--- |
| `DrawText(x, y, text)` | Draw text on screen immediately. |
| `DrawLine(x1, y1, x2, y2)` | Draw a line. |
| `DrawRect(x, y, w, h)` | Draw a rectangle. |
| `DrawCircle(x, y, r)` | Draw a circle. |
| `PlaySound(path)` | Play a sound file. |
| `PlayTone(hz, duration)` | Generate a synthetic tone. |

### Utilities
| Function | Description |
| :--- | :--- |
| `Print val` | Print to Debug Console. |
| `Randomize` | Seed the random number generator. |
| `Rnd()` | Get random float 0.0-1.0. |
| `RandRange(min, max)` | Get random integer in range. |
| `Clamp(val, min, max)` | Constrain a value. |
| `Lerp(from, to, weight)` | Linear interpolation. |
| `MsgBox(text)` | Show a standard alert dialog. |
| `Shell(cmd)` | Execute global OS commands. |
| `Sleep(ms)` | Pause execution. |

### AI
| Function | Description |
| :--- | :--- |
| `AI_Wander(node)` | Make a node wander randomly. |
| `AI_Patrol(node, points)` | Make a node patrol a path. |
| `AI_Stop(node)` | Stop AI movement. |

### System / IO
| Function | Description |
| :--- | :--- |
| `MkDir(path)` | Create a directory. |
| `SaveSetting(app, section, key, val)` | Save persistent data. |
| `GetSetting(app, section, key)` | Load persistent data. |
| `LoadPicture(path)` | Load a texture resource. |
