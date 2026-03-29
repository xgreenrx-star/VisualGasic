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
| `GoSub label` | Jump to a label and push return address. |
| `Return` | Return from a `GoSub` call. |
| `Implements InterfaceName` | Declare interface implementation in a class. |

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
| `Timer()` | Seconds since midnight as Double. |

### VB6 Global Objects
| Object | Description |
| :--- | :--- |
| `App` | Application info: `App.Path`, `App.Title`, `App.Major`, etc. |
| `Screen` | Display info: `Screen.Width`, `Screen.Height`. |
| `Err` | Error state: `Err.Number`, `Err.Description`, `Err.Source`, `Err.Raise`, `Err.Clear`. |

### COM-Style Objects
| Class | ProgID | Description |
| :--- | :--- | :--- |
| `Collection` | `VB6.Collection` | 1-based ordered collection with keys. |
| `RegExp` | `VBScript.RegExp` | Regular expression engine. |
| `HttpRequest` | `MSXML2.XMLHTTP` | HTTP client for REST APIs. |
| `VBTimer` | — | Poll-based timer with Interval/Enabled. |

### File I/O Statements
| Statement | Description |
| :--- | :--- |
| `Print #n, expr` | Write formatted output to file. |
| `Write #n, expr` | Write CSV-style quoted output. |
| `Input #n, var` | Read delimited value from file. |
| `Line Input #n, var` | Read entire line from file. |

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
