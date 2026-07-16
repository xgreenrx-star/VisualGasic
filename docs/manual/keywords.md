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
| `Oscillate var = from To to [Step s] [Cycles n] ... Loop` | Ping-pong loop — bounces a variable back and forth between two bounds. |
| `Repeat N Times [As counter] ... End Repeat` | Executes a block exactly N times with optional 1-based counter. |
| `Cycle Through collection For N As var ... End Cycle` | Takes N items from a collection with automatic wrap-around. |
| `Every N Frames ... End Every` | Conditional guard — runs body once every N frames inside `_Process`. |
| `Every N Seconds ... End Every` | Conditional guard — runs body once every N seconds inside `_Process`. |
| `Tween target.Property To value Over duration` | One-liner animation that tweens a property to a target value over time. |
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


### Bit Manipulation
| Function | Description |
| :--- | :--- |
| `BitAnd(a, b)` | Bitwise AND |
| `BitOr(a, b)` | Bitwise OR |
| `BitXor(a, b)` | Bitwise XOR |
| `BitNot(a)` | Bitwise NOT |
| `BitClr(val, bit...)` | Clear specified bits |
| `BitSet(val, bit...)` | Set specified bits |
| `BitTst(val, bit)` | Test a bit (returns Boolean) |
| `BitGet(val, bit)` | Get a bit value (0 or 1) |
| `LeftShift(val, n)` / `Shl(val, n)` | Logical left shift |
| `RightShift(val, n)` / `Shr(val, n)` | Logical right shift |
| `RotateLeft(val, n)` / `Rol(val, n)` | Rotate left (64-bit) |
| `RotateRight(val, n)` / `Ror(val, n)` | Rotate right (64-bit) |
| `Swap(val)` | Swap high/low 32-bit halves |
| `NumBits(val)` | Count set bits (population count) |


### String Constants (reserved, no Dim required)
| Constant | Value |
| :--- | :--- |
| `vbCrLf` | `Chr(13) + Chr(10)` — carriage return + line feed |
| `vbCr` | `Chr(13)` — carriage return |
| `vbLf` | `Chr(10)` — line feed |
| `vbTab` | `Chr(9)` — horizontal tab |
| `vbNullString` | `""` — empty string |
| `vbNewLine` | Platform newline |
| `vbNullChar` | `Chr(0)` — null character |

### Math Constants (reserved, no Dim required)
| Constant | Value |
| :--- | :--- |
| `Pi` | 3.141592653589793 |
| `Math_Tau` | 6.283185307179586 |


### SoundGen — Real-time Audio Synthesis
| Function | Description |
| :--- | :--- |
| `SoundGen.Open(mix_rate, buf_len)` | Create audio generator, returns handle |
| `SoundGen.Close(handle)` | Stop and free generator |
| `SoundGen.Available(handle)` | Get available stereo frames to fill |
| `SoundGen.PushMono(handle, sample)` | Push one mono sample |
| `SoundGen.PushStereo(handle, left, right)` | Push one stereo pair |
| `SoundGen.PushMonoBuffer(handle, samples)` | Push PackedFloat32Array as mono (~100× faster) |
| `SoundGen.PushStereoBuffer(handle, samples)` | Push interleaved PackedFloat32Array as stereo |
| `SoundGen.FillVoices(h, sr, arpPh, arpF, kickOn, kickT, kickDur, noiseOn, noiseT, noiseDecay)` | 3-voice synthesizer (square arp + kick + noise) — all native C++, returns updated phases |
| `SoundGen.FillVoices4(h, sr, leadF, leadPh, bassF, bassPh, arpF, arpPh, hhOn, hhT, hhInvSr [, kickOn, kickT, kickDur [, noteAge]])` | 4/5-voice chiptune engine (pulse lead + sine bass + square arp + noise hi-hat + optional 808 kick) — all native C++ |

See `docs/BUILTINS.md` for full API details and worked examples.

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
