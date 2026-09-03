# VisualGasic Programmer's Reference

*The classic Super Bible-style command reference for the VisualGasic BASIC language.*

This manual has two parts:

* **Part I — Language Tutorials** explains the language and major subsystems in a tutorial voice.
* **Part II — Command Reference (A–Z)** has one dedicated page for every built-in keyword, function, and namespace verb in alphabetical order.

## Table of Contents

- [Getting Started](#getting-started)
- [Language Basics](#language-basics)
- [Control Flow](#control-flow)
- [Procedures and Functions](#procedures-and-functions)
- [Object-Oriented Features](#object-oriented-features)
- [VB6 Global Objects](#vb6-global-objects)
- [COM-Style Objects](#com-style-objects)
- [System Integration](#system-integration)
- [System-Level Programming](#system-level-programming)
- [Modern Language Features](#modern-language-features)
- [Godot Integration](#godot-integration)
- [Part II — Command Reference (A–Z)](#command-reference)

## Part I — Language Tutorials


These chapters explain the language and major subsystems end-to-end. 

For a per-command alphabetical reference, see 

[Part II — Command Reference](#command-reference).


## Getting Started

### Introduction

VisualGasic is a modern, forward-looking programming language designed for application and game development on the Godot 4.6.1+ platform. The name "Gasic" stands for **G**odot **A**ll-purpose **S**ymbolic **C**ode (when used within Godot) or **G**eneral **A**ll-purpose **S**ymbolic **C**ode (for standalone applications), representing its versatility as both a game development language and a general-purpose programming solution.

> **VisualGasic is not a VB6 clone.** It is a distinct, modern language that takes inspiration from VB6's legendary approachability — the simple syntax, the ease of learning, the RAD workflow — and builds something new on that foundation. If you know VB6, you'll feel at home in minutes. But VisualGasic goes far beyond VB6 with features like lambda expressions, async/await, pattern matching, null-safe operators, GPU computing, generics, and a JIT-compiled bytecode engine. VG is VB6-*compatible* where it makes sense, but it is designed to look forwards, not backwards.

VisualGasic provides an intuitive BASIC-style language environment with powerful language features, seamless Godot integration, and cross-platform capabilities for both applications and games.

Whether you're creating desktop applications, mobile apps, web software, or interactive games, VisualGasic provides the tools and cross-platform flexibility you need for professional development.

**Key Features:**
- Clean, intuitive syntax — familiar to VB6 developers, accessible to everyone
- Modern language features: lambdas, async/await, pattern matching, null-safety, generics
- Full Godot 4.6.1+ integration for applications and games
- Cross-platform development support
- Object-oriented programming with classes, inheritance, and interfaces
- JIT-compiled bytecode engine — faster than GDScript, competitive with native C++
- Built-in functions for game and application development
- Type safety with optional explicit typing

> **Platform note (runtime engine):** VisualGasic runs on Windows, macOS, Linux, Android, and Web targets. Native JIT tiers are platform-dependent and fall back to interpreter/bytecode execution where executable-memory JIT is not available.

### Visual Basic Heritage
VisualGasic takes its inspiration from **Visual Basic 6.0** (VB6), one of the most successful programming languages in history. If you have experience with VB6, VBA (Visual Basic for Applications), or any BASIC dialect, you'll feel right at home with VisualGasic.

However, **VisualGasic is not a VB6 clone or reimplementation**. It is its own language. VB6's genius was its simplicity — anyone could learn it, and you could build real software in minutes. VisualGasic preserves that spirit while adding the features that modern developers expect: lambda expressions, async/await concurrency, pattern matching, null-safe operators (`??`, `?.`), generics, GPU computing, and a JIT-compiled bytecode engine. VB6 code will often run in VisualGasic with minimal changes, but VisualGasic code can do things VB6 never could.

#### What is BASIC?

BASIC (**B**eginner's **A**ll-purpose **S**ymbolic **I**nstruction **C**ode) was created in 1964 at Dartmouth College to make programming accessible to everyone. Visual Basic, introduced by Microsoft in 1991, added a graphical IDE and drag-and-drop form designer, revolutionizing Windows application development.

#### VB6 Compatibility

VisualGasic supports a large subset of VB6 syntax for easy porting and familiarity, including:

**Variables and Data Types:**
```vb
' VB6-style variable declarations
Dim playerName As String
Dim score As Integer
Dim isActive As Boolean
Dim position As Single

' Type suffixes (classic BASIC style)
Dim count%          ' Integer
Dim price#          ' Double
Dim message$        ' String
```

**Control Structures:**
```vb
' If/Then/Else (VB6 style)
If score > 100 Then
    Print "High score!"
ElseIf score > 50 Then
    Print "Good job!"
Else
    Print "Keep trying!"
End If

' Select Case (VB6's switch statement)
Select Case playerClass
    Case "Warrior"
        strength = 10
    Case "Mage"
        intelligence = 10
    Case Else
        charisma = 10
End Select

' For/Next loops
For i = 1 To 10
    Print i
Next i

' Do/Loop variations
Do While health > 0
    TakeDamage()
Loop

Do
    ProcessInput()
Loop Until gameOver

' Oscillate (ping-pong loop)
' Bounces a variable back and forth between two values.
' Great for patrol paths, wave effects, and animations.
Oscillate x = 0 To 10 Cycles 3
    Print x   ' 0,1,2,...,10,9,8,...,0,1,...,10
Loop

' Oscillate with Step
Oscillate alpha = 0 To 1 Step 0.25 Cycles 2
    SetOpacity(alpha)
Loop

' Exit Oscillate - break out early
Oscillate i = 1 To 100 Cycles 5
    If EnemyDefeated() Then Exit Oscillate
    MoveEnemy(i)
Loop

' Continue Oscillate - skip to next iteration
Oscillate frame = 0 To 30 Cycles 2
    If frame = 15 Then Continue Oscillate
    DrawFrame(frame)
Loop

' Repeat N Times - execute a block exactly N times
Repeat 5 Times
    Print "Hello!"
End Repeat

' Repeat with a 1-based counter variable
Repeat 10 Times As i
    Print "Iteration " & Str(i)   ' 1, 2, 3, ..., 10
End Repeat

' Cycle Through - take N items from a collection with wrap-around
Dim colors() As String
colors = Array("Red", "Green", "Blue")
Cycle Through colors For 7 As c
    Print c   ' Red, Green, Blue, Red, Green, Blue, Red
End Cycle

' Every N Frames/Seconds - conditional guard for _Process
' Fires body once every N frames or N seconds
Sub _Process(delta As Single)
    Every 3 Frames
        UpdateParticles()   ' Called every 3rd frame
    End Every

    Every 0.5 Seconds
        CheckSpawns()       ' Called every half second
    End Every
End Sub

' Tween - one-liner property animation
' Tweens a node property to a target value over time
Tween sprite.Position To Vector2(400, 300) Over 2.0

' Tween with starting value
Tween panel.Position From Vector2(0, -200) To Vector2(0, 50) Over 0.8

' Tween with easing and transition curve
Tween label.Modulate.A To 0.0 Over 0.5 Ease Out Trans Sine

' Tween with all options
Tween btn.Position From Vector2(0, 0) To Vector2(200, 100) Over 1.0 Ease InOut Trans Cubic

' VB6 property aliases work with Tween
Tween ctrl.Left To 100 Over 0.3 Ease Out Trans Back
```

**Subroutines and Functions:**
```vb
' Subroutines (no return value)
Sub UpdateScore(points As Integer)
    score = score + points
    UpdateDisplay()
End Sub

' Functions (return a value)
Function CalculateDamage(baseAttack As Integer) As Integer
    Dim damage As Integer
    damage = baseAttack * Rnd() * 2
    CalculateDamage = damage   ' VB6 style return
End Function

' Or use Return statement (modern style)
Function GetPlayerName() As String
    Return "Player One"
End Function
```

**Built-in VB6 Functions:**
```vb
' String functions
Dim s As String
s = Left("Hello", 3)        ' Returns "Hel"
s = Right("Hello", 2)       ' Returns "lo"
s = Mid("Hello", 2, 3)      ' Returns "ell"
s = UCase("hello")          ' Returns "HELLO"
s = LCase("HELLO")          ' Returns "hello"
s = Trim("  hi  ")          ' Returns "hi"
x = Len("Hello")            ' Returns 5
x = InStr("Hello", "l")     ' Returns 3

' Math functions
x = Abs(-5)                 ' Returns 5
x = Sqr(16)                 ' Returns 4 (square root)
x = Int(3.7)                ' Returns 3
x = Rnd()                   ' Returns random 0-1
x = Round(3.567, 2)         ' Returns 3.57

' Conversion functions
s = CStr(42)                ' Convert to string
x = CInt("42")              ' Convert to integer
x = CLng("123456")          ' Convert to long integer
x = CDbl("3.14")            ' Convert to double
x = CSng("3.14")            ' Convert to single
b = CBool("Yes")            ' Convert to boolean
x = Val("123abc")           ' Returns 123

' Date/Time functions
Print Now                   ' Current date/time
Print Timer                 ' Seconds since midnight
Print Year(Now)             ' Current year
Print Month(Now)            ' Current month
Print Day(Now)              ' Current day
```

**Event-Driven Programming:**
```vb
' Classic VB6 event handlers
Private Sub Form_Load()
    ' Runs when form loads
    InitializeGame()
End Sub

Private Sub Command1_Click()
    ' Runs when button is clicked
    StartGame()
End Sub

Private Sub Timer1_Timer()
    ' Runs on timer interval
    UpdateGame()
End Sub
```

#### VB6 Importer (Community Plugin)

The VB6 importer documentation has moved out of the core language manual.

See `docs/community_plugins/VB6_IMPORTER_PLUGIN_MANUAL.md` for:
- supported VB6/OCX mapping tables
- importer compatibility notes and caveats
- import report format and programmatic API

**Cross-Platform Development:**
VisualGasic applications run on all platforms supported by Godot:
- **Desktop**: Windows, macOS, Linux
- **Mobile**: iOS, Android  
- **Web**: HTML5/WebAssembly
- **Console**: Nintendo Switch, PlayStation, Xbox (with appropriate licensing)

**Application Types:**
- Desktop applications and utilities
- Mobile apps and games
- Web applications
- Educational software
- Business tools and productivity apps
- Interactive media and presentations

### Installation

VisualGasic is provided as a Godot extension (GDExtension). To install:

1. Download the latest release from the project repository
2. Extract to your Godot project's `addons/` folder
3. Enable the VisualGasic plugin in Project Settings > Plugins
4. Files with `.vg` or `.bas` extension will now use VisualGasic syntax

---



> **Scope note:** The standalone VG IDE shell is mothballed for current releases; this reference focuses on language and Godot editor integration.

---

## Language Basics

### Syntax Overview

VisualGasic features an intuitive syntax with case-insensitive keywords and end-of-line statement termination.

Each logical statement ends at a newline. Multiple statements on one line are separated by `:`.

```vb
Dim x As Integer : Dim y As Integer = 10
```

### Line Continuation

Long logical lines can span multiple physical lines in two ways.

#### Explicit continuation with `_`

A `_` at the end of a line (preceded by a space) joins the next line, as in VB6. No newline token is emitted, so the parser sees the two physical lines as one.

```vb
If userName = "admin" _
    Or userName = "root" _
    Or userName = "superuser" Then
    MsgBox "Access granted"
End If

Dim result As Integer = someVeryLongFunctionName(arg1, arg2) _
    + anotherFunction(arg3)
```

> VB6 compatibility note: `_` must be preceded by at least one space. A trailing `_` with no space before it (e.g. `x_`) starts an identifier, not a continuation.

#### Implicit continuation with a leading boolean operator

In `If`, `ElseIf`, `While`, `Do While`, and `Do Until` conditions, a boolean operator (`Or`, `And`, `Xor`, `OrElse`, `AndAlso`, `Eqv`, `Imp`) at the start of the next line automatically continues the condition. No `_` is required.

```vb
If userName = "admin"
    Or userName = "root"
    Or userName = "superuser" Then
    MsgBox "Access granted"
End If

While retries < maxRetries
    Or lastError = ERROR_RETRY Then
    Call TryAgain()
Wend

Do While queue.Count > 0
    Or processingActive = True
    Call ProcessNext()
Loop
```

This style — operator at the start of the continuation line — is recommended for readability in new VG code. It makes the structure of compound conditions immediately visible.

> **Plain `Do` (no condition):** implicit continuation does not apply. A `Do` loop with no `While`/`Until` has no condition to continue, so `Or` appearing in the body is treated as a statement.

#### Comparison with VB.NET

VB.NET also supports trailing-operator continuation (the operator ends the current line). VG does not support this form — the parser cannot determine intent unambiguously when a boolean operator ends a line outside of a condition context.

| Style | Example | Supported |
|---|---|---|
| VB6 explicit `_` | `If a = 1 _`⏎`    Or b = 2 Then` | ✅ |
| Leading operator | `If a = 1`⏎`    Or b = 2 Then` | ✅ VG extension |
| Trailing operator | `If a = 1 Or`⏎`    b = 2 Then` | ❌ not supported |


## Control Flow

### Conditional Statements

#### If-Then-Else
```vb
If score > highScore Then
    highScore = score
    Print "New high score!"
ElseIf score > 0 Then
    Print "Good job!"
Else
    Print "Try again!"
End If

' Single-line If
If health <= 0 Then gameOver = True
```

#### IIf Function (Ternary Operator)
```vb
message = IIf(score > 100, "Excellent!", "Keep trying!")
```

**See Also:** [If-Then-Else](#if-then-else) - Full conditional statements for more complex branching logic.

### Loops

#### For-Next Loop
```vb
' Basic for loop
For i = 1 To 10
    Print i
Next i

' Variable after Next is optional
For i = 1 To 10
    Print i
Next

' With step
For i = 0 To 100 Step 5
    Print i
Next i

' Backwards
For i = 10 To 1 Step -1
    Print i
Next
```

#### For-Each Loop
```vb
Dim items As Array = ["apple", "banana", "cherry"]
For Each item In items
    Print item
Next item

' Variable after Next is optional for For-Each too
For Each item In items
    Print item
Next
```

#### While-Wend Loop
```vb
While health > 0
    TakeDamage()
    If health <= 0 Then Exit While
Wend
```

**See Also:** [Do-Loop](#do-loop) - Alternative loop syntax with `Do While` for similar functionality.

#### Do-Loop
```vb
' Do While
Do While player.IsAlive
    ProcessTurn()
Loop

' Do Until
Do Until gameOver
    UpdateGame()
Loop

' Do-Loop While (executes at least once)
Do
    GetInput()
Loop While input <> "quit"
```

**See Also:** [While-Wend Loop](#while-wend-loop) - Alternative loop syntax with similar `While` condition syntax.

#### Repeat N Times

Executes a block exactly N times. Simpler than a `For` loop when you just need repetition without managing a counter variable. An optional `As counter` clause provides a 1-based iteration variable.

**Syntax:**
```
Repeat <count> Times [As <counter>]
    ' body
End Repeat
```

**Basic usage:**
```vb
' Fire three bullets in a burst
Repeat 3 Times
    SpawnBullet()
End Repeat
```

**With a counter variable (1-based):**
```vb
' Spawn 5 enemies at increasing heights
Repeat 5 Times As i
    Dim y As Single = i * 64.0
    SpawnEnemy(0, y)
    Print "Spawned enemy #" & Str(i) & " at y=" & Str(y)
Next
```
Output:
```
Spawned enemy #1 at y=64
Spawned enemy #2 at y=128
Spawned enemy #3 at y=192
Spawned enemy #4 at y=256
Spawned enemy #5 at y=320
```

**Expression as count:**
```vb
Dim difficulty As Integer = 3
Repeat difficulty * 2 Times As wave
    Print "Wave " & Str(wave)
End Repeat
' Prints: Wave 1, Wave 2, Wave 3, Wave 4, Wave 5, Wave 6
```

**Exit Repeat — break out early:**
```vb
Repeat 100 Times As attempt
    Dim roll As Integer = Int(Rnd() * 6) + 1
    If roll = 6 Then
        Print "Rolled a 6 on attempt " & Str(attempt) & "!"
        Exit Repeat
    End If
End Repeat
```

**Continue Repeat — skip to next iteration:**
```vb
Repeat 10 Times As n
    If n Mod 2 = 0 Then Continue Repeat
    Print n   ' Prints only odd numbers: 1, 3, 5, 7, 9
End Repeat
```

**Nested Repeat:**
```vb
Repeat 3 Times As row
    Dim line As String = ""
    Repeat 4 Times As col
        line = line & "[" & Str(row) & "," & Str(col) & "] "
    End Repeat
    Print line
End Repeat
```
Output:
```
[1,1] [1,2] [1,3] [1,4]
[2,1] [2,2] [2,3] [2,4]
[3,1] [3,2] [3,3] [3,4]
```

**Zero count — body never executes:**
```vb
Repeat 0 Times
    Print "This never prints"
End Repeat
```

**See Also:** [For-Next Loop](#for-next-loop) - Use `For` when you need a custom start/end range or step value.

---

#### Cycle Through

Takes N items from a collection, wrapping around automatically when the end is reached. Ideal for repeating patterns, color cycling, tile assignment, or round-robin distribution.

**Syntax:**
```
Cycle Through <collection> For <count> As <element>
    ' body — element holds the current item
End Cycle
```

**Basic — repeating a color pattern:**
```vb
Dim colors As Array = ["Red", "Green", "Blue"]
Cycle Through colors For 7 As c
    Print c
End Cycle
' Output: Red, Green, Blue, Red, Green, Blue, Red
```

**Round-robin team assignment:**
```vb
Dim teams As Array = ["Alpha", "Bravo", "Charlie"]
Dim players As Array = ["Alice", "Bob", "Carol", "Dave", "Eve", "Frank", "Grace", "Hank"]

Cycle Through teams For Len(players) As team
    ' Each player gets the next team in rotation
    Print players(i) & " → " & team
End Cycle
```

**Tile pattern for a game board:**
```vb
Dim tiles As Array = ["grass", "dirt", "stone"]
Cycle Through tiles For 12 As t
    PlaceTile(t)   ' grass, dirt, stone, grass, dirt, stone, ...
End Cycle
```

**Exit Cycle — break out early:**
```vb
Dim notes As Array = ["C", "E", "G"]
Cycle Through notes For 20 As note
    PlayNote(note)
    If PlayerPressedStop() Then Exit Cycle
End Cycle
```

**Continue Cycle — skip an iteration:**
```vb
Dim items As Array = ["sword", "shield", "potion"]
Cycle Through items For 9 As item
    If item = "shield" Then Continue Cycle
    Print item   ' Prints: sword, potion, sword, potion, sword, potion
End Cycle
```

**Single-element collection:**
```vb
Dim only As Array = ["echo"]
Cycle Through only For 5 As word
    Print word   ' echo, echo, echo, echo, echo
End Cycle
```

**See Also:** [For-Each Loop](#for-each-loop) - Use `For Each` when you want to iterate a collection exactly once without wrap-around.

---

#### Every N Frames / Every N Seconds

A conditional guard for use inside `_Process`. Executes its body once every N frames or once every N seconds, skipping all other calls. Eliminates the boilerplate of manual frame counters or elapsed-time accumulators.

**Syntax:**
```
Every <N> Frames
    ' body — runs once every N frames
End Every

Every <N> Seconds
    ' body — runs once every N seconds
End Every
```

> **Note:** `Every` blocks must be placed inside a `_Process(delta)` subroutine. Each `Every` block maintains its own internal counter automatically.

**Frame-based — update particles every 3 frames:**
```vb
Sub _Process(delta As Single)
    Every 3 Frames
        UpdateParticles()
    End Every
End Sub
```

**Time-based — check for spawns every half second:**
```vb
Sub _Process(delta As Single)
    Every 0.5 Seconds
        CheckSpawns()
    End Every
End Sub
```

**Multiple guards in the same `_Process`:**
```vb
Sub _Process(delta As Single)
    ' Fast update: every other frame
    Every 2 Frames
        UpdateAnimations()
    End Every

    ' Medium update: every 10 frames
    Every 10 Frames
        UpdateMinimap()
    End Every

    ' Slow update: once per second
    Every 1.0 Seconds
        AutoSave()
    End Every
End Sub
```

**Game HUD refresh — update score display every 5 frames:**
```vb
Sub _Process(delta As Single)
    Every 5 Frames
        lblScore.Text = "Score: " & Str(score)
    End Every
End Sub
```

**Network sync — send position to server every 100ms:**
```vb
Sub _Process(delta As Single)
    Every 0.1 Seconds
        SendPositionToServer(Me.Position)
    End Every
End Sub
```

**Enemy AI — re-evaluate target once per second:**
```vb
Sub _Process(delta As Single)
    ' Pathfinding is expensive — only run once per second
    Every 1.0 Seconds
        target = FindNearestPlayer()
        path = NavigationServer.GetPath(Me.Position, target.Position)
    End Every

    ' Movement runs every frame as usual
    MoveAlongPath(path, delta)
End Sub
```

**See Also:** [Timer Node](https://docs.godotengine.org/en/stable/classes/class_timer.html) - For one-shot or independently scheduled timers outside `_Process`.

---

#### Tween (One-Liner Animation)

Animates a node property from its current value (or a specified starting value) to a target value over a duration, with optional easing and transition curves. Compiles to Godot's `SceneTreeTween` chain (`create_tween → tween_property → set_ease → set_trans`).

**Syntax:**
```
Tween <target.Property> To <value> Over <duration>
Tween <target.Property> From <start> To <end> Over <duration> [Ease <type>] [Trans <type>]
```

**Basic — slide a sprite to a position:**
```vb
Tween sprite.Position To Vector2(400, 300) Over 2.0
```

**With starting value — slide a panel in from off-screen:**
```vb
Tween panel.Position From Vector2(0, -200) To Vector2(0, 50) Over 0.8
```

**Fade out a label:**
```vb
Tween label.Modulate:a To 0.0 Over 0.5
```

**Easing and transition curves:**
```vb
' Smooth deceleration
Tween enemy.Position To Vector2(100, 200) Over 1.0 Ease Out Trans Sine

' Overshoot bounce
Tween button.Scale To Vector2(1.2, 1.2) Over 0.3 Ease Out Trans Back

' Smooth start and end
Tween camera.Position To target Over 0.6 Ease InOut Trans Cubic
```

**Full example — all options:**
```vb
Tween healthBar.Size From Vector2(200, 20) To Vector2(50, 20) Over 1.5 Ease InOut Trans Cubic
```

**VB6 property aliases:**

Classic VB6 property names are automatically translated to their Godot equivalents:

```vb
Tween ctrl.Left To 100 Over 0.3              ' → position:x
Tween ctrl.Top To 200 Over 0.3               ' → position:y
Tween ctrl.Width To 400 Over 0.5             ' → size:x
Tween ctrl.Height To 300 Over 0.5            ' → size:y
Tween ctrl.Visible To True Over 0.2          ' → visible
Tween ctrl.BackColor To Color.RED Over 1.0   ' → modulate
```

**Practical game examples:**

```vb
' Damage flash — tween to red and back
Sub TakeDamage(amount As Integer)
    health = health - amount
    Tween sprite.Modulate To Color.RED Over 0.1
    Tween sprite.Modulate From Color.RED To Color.WHITE Over 0.3
End Sub

' UI pop-in animation
Sub ShowDialog()
    dialog.Scale = Vector2(0, 0)
    dialog.Visible = True
    Tween dialog.Scale From Vector2(0, 0) To Vector2(1, 1) Over 0.4 Ease Out Trans Back
End Sub

' Smooth camera follow
Sub _Process(delta As Single)
    Every 2 Frames
        Tween camera.Position To player.Position Over 0.3 Ease Out Trans Quad
    End Every
End Sub

' Coin collect — float up and fade out
Sub CollectCoin(coin As Node2D)
    score = score + 10
    Tween coin.Position To coin.Position - Vector2(0, 50) Over 0.5 Ease Out Trans Quad
    Tween coin.Modulate:a To 0.0 Over 0.5
End Sub
```

**Ease Types:**
| Ease | Description |
| :--- | :--- |
| `In` | Starts slow, accelerates |
| `Out` | Starts fast, decelerates |
| `InOut` | Smooth start and end |
| `OutIn` | Fast start and end, slow middle |

**Trans Types (Transition Curves):**
| Trans | Description |
| :--- | :--- |
| `Linear` | Constant speed (no curve) |
| `Sine` | Gentle sine-wave curve |
| `Quad` | Quadratic (power of 2) |
| `Cubic` | Cubic (power of 3) |
| `Quart` | Quartic (power of 4) |
| `Quint` | Quintic (power of 5) |
| `Expo` | Exponential |
| `Circ` | Circular |
| `Elastic` | Springy overshoot |
| `Bounce` | Bouncing ball effect |
| `Back` | Slight overshoot and return |
| `Spring` | Damped spring oscillation |

**See Also:** [Godot Tween Documentation](https://docs.godotengine.org/en/stable/classes/class_tween.html) - Underlying Godot Tween API for advanced chaining and callbacks.

---

### Select Case

```vb
Select Case playerClass
    Case "Warrior"
        strength = strength + 10
        health = health + 5
    Case "Mage"
        intelligence = intelligence + 10
        mana = mana + 15
    Case "Rogue"
        dexterity = dexterity + 10
        stealth = stealth + 5
    Case Else
        Print "Unknown class!"
End Select

' Multiple values
Select Case level
    Case 1, 2, 3
        difficulty = "Easy"
    Case 4, 5, 6
        difficulty = "Medium"
    Case 7, 8, 9, 10
        difficulty = "Hard"
End Select
```

**See Also:** [Pattern Matching](#pattern-matching) - The `Match` statement provides similar functionality with enhanced pattern matching capabilities.

### Error Handling

```vb
On Error GoTo ErrorHandler
    ' Code that might cause an error
    result = 10 / 0
    Print "This won't execute"
    Exit Sub
    
ErrorHandler:
    Print "Error occurred: " & Err.Description
    Resume Next
```

#### On Error Resume Next

`On Error Resume Next` catches runtime errors inline without jumping to a handler. This includes **method calls on Null objects** — a common scenario with optional object references:

```vb
Sub SafeProcess()
    On Error Resume Next
    
    Dim obj As Variant = Nothing
    
    ' This would normally crash — but On Error Resume Next catches it
    Dim result As Variant = obj.SomeMethod()
    
    ' Check if an error occurred
    If Err.Number <> 0 Then
        Print "Error caught: " & Err.Description
        Err.Clear
    End If
    
    ' Execution continues safely
    Print "Continuing after error"
End Sub
```

The `Err` object provides:
- `Err.Number` — Error code (0 = no error)
- `Err.Description` — Human-readable error message
- `Err.Source` — Source of the error
- `Err.Clear` — Reset the error state
- `Err.Raise number, source, description` — Raise a custom error

```vb
' Raise a custom error
On Error Resume Next
Err.Raise 1001, "MyModule", "Custom validation failed"
If Err.Number = 1001 Then
    Print "Source: " & Err.Source       ' "MyModule"
    Print "Error: " & Err.Description   ' "Custom validation failed"
    Err.Clear
End If
On Error GoTo 0
```

#### GoSub / Return

Classic VB6 `GoSub` jumps to a label within the current Sub/Function, then `Return` jumps back to the statement after the `GoSub`. This is useful for reusable code blocks without creating separate subroutines:

```vb
Sub ProcessData()
    Dim x As Integer
    x = 10
    GoSub DoubleIt
    Print x            ' 20
    x = 50
    GoSub DoubleIt
    Print x            ' 100
    Exit Sub

DoubleIt:
    x = x * 2
    Return
End Sub
```

> **Note:** `Return` checks the GoSub return stack first. If no GoSub is pending, bare `Return` acts as `Exit Sub`.

#### Try-Catch-Finally (Modern Error Handling)

Modern exception handling with `Try/Catch/Finally` provides structured error recovery without label jumps.

```vb
Function ParseInteger(str As String) As Integer
    Try
        Return CInt(str)
    Catch ex As Exception
        Print "Invalid integer: " & str
        Return 0
    Finally
        Print "Parse attempt complete"  ' Always runs
    End Try
End Function

Sub ProcessWithFallback()
    Try
        Dim value As Integer = ParseInteger("abc")
        Print "Parsed: " & CStr(value)
    Catch ex As Exception
        Print "Caught error: " & ex.Message
    Finally
        Print "Cleanup complete"
    End Try
End Sub
```

**Key points:**
- `Try` wraps code that might raise an exception
- `Catch` handles exceptions (optionally typed, defaults to all)
- `Finally` runs regardless of success or failure — use for cleanup
- Multiple `Catch` blocks handle different exception types
- Nested `Try/Catch` blocks are allowed for granular error handling
- `Throw` re-raises the current exception or throws a new one

**For comprehensive examples of nested handlers, multiple catch blocks, and defensive patterns, see** [corpus/01_basics/07_exception_patterns.vg](../corpus/01_basics/07_exception_patterns.vg).

---


## Procedures and Functions

### Subroutines

```vb
' Simple subroutine
Sub ShowMessage()
    Print "Hello from subroutine!"
End Sub

' Subroutine with parameters
Sub MovePlayer(ByVal deltaX As Integer, ByVal deltaY As Integer)
    Player.Position.x = Player.Position.x + deltaX
    Player.Position.y = Player.Position.y + deltaY
End Sub

' Calling subroutines
Call ShowMessage()
ShowMessage()  ' 'Call' keyword is optional
MovePlayer(10, 5)
```

### Functions

```vb
' Function returning a value
Function CalculateDistance(x1 As Double, y1 As Double, x2 As Double, y2 As Double) As Double
    Dim dx As Double = x2 - x1
    Dim dy As Double = y2 - y1
    CalculateDistance = Sqr(dx * dx + dy * dy)
End Function

' Using the function
Dim distance As Double = CalculateDistance(0, 0, 3, 4) ' Returns 5.0
```

### Parameters

```vb
' ByVal (pass by value) - default
Sub ModifyValue(ByVal x As Integer)
    x = x + 10  ' Original variable unchanged
End Sub

' ByRef (pass by reference)
Sub ModifyReference(ByRef x As Integer)
    x = x + 10  ' Original variable is modified
End Sub

' Optional parameters
Sub CreateEnemy(name As String, Optional level As Integer = 1, Optional boss As Boolean = False)
    Print "Creating " & name & " at level " & level
    If boss Then Print "This is a boss enemy!"
End Sub

CreateEnemy("Goblin")           ' Uses defaults
CreateEnemy("Dragon", 50, True) ' All parameters specified
```

### Scope and Lifetime

```vb
' Module-level (Global) scope
Dim globalCounter As Integer = 0  ' Accessible throughout the module

Sub IncrementCounter()
    globalCounter = globalCounter + 1  ' Can access module-level variable
End Sub

' Procedure-level (Local) scope
Sub ProcessData()
    Dim localVar As Integer = 10  ' Only accessible within this Sub
    
    ' Block-level scope
    For i = 1 To 5
        Dim blockVar As Integer = i * 2  ' Only accessible within For loop
    Next
    
    ' blockVar is not accessible here
End Sub

' Static variables (persist between calls)
Sub CountCalls()
    Static callCount As Integer = 0  ' Initialized once, value persists
    callCount = callCount + 1
    Print "This function has been called " & callCount & " times"
End Sub
```

**Scope Rules:**
- `Dim` inside a procedure → Local scope
- `Dim` at module level → Module scope
- `Public` → Accessible from other modules
- `Private` → Only accessible within the module
- `Static` → Local variable that retains value between calls

---


## Object-Oriented Features

### Method Overloading
Define multiple `Sub` or `Function` with the same name but different parameter counts.
The runtime selects the best match based on the number of arguments passed (arity-based dispatch).

```vb
' Module-level overloads
Sub Spawn(x As Single, y As Single)
    ' 2-arg version: uses default speed/angle
    Spawn x, y, 100, 0
End Sub

Sub Spawn(x As Single, y As Single, speed As Single, angle As Single)
    ' 4-arg version: full control
    CreateBullet x, y, speed, angle
End Sub

' Class method overloads
Class Calculator
    Function Add(a As Integer) As Integer
        Return a
    End Function
    Function Add(a As Integer, b As Integer) As Integer
        Return a + b
    End Function
    Function Add(a As Integer, b As Integer, c As Integer) As Integer
        Return a + b + c
    End Function
End Class

Dim calc = New Calculator
Print calc.Add(5)       ' → 5
Print calc.Add(3, 4)    ' → 7
Print calc.Add(1, 2, 3) ' → 6
```

**Rules:**
- Overloads are resolved by argument count only (no type-based overloading yet)
- If no exact arity match exists, Optional parameters are considered
- Falls back to first-match if no arity match is found (backward compatibility)
- Works in module-level subs/functions, class methods, and bytecode-compiled code

### Parameterized Constructors
Pass arguments to `Class_Initialize` when creating new objects.

```vb
Class Bullet
    Public speed As Double
    Public angle As Double
    Public damage As Integer

    Sub Class_Initialize(s As Double, a As Double, d As Integer)
        speed = s
        angle = a
        damage = d
    End Sub
End Class

' Both syntaxes work:
Dim b1 = New Bullet(300, 45, 10)
Dim b2 As New Bullet(200, 90, 25)
```

**Notes:**
- `New ClassName` with no parentheses still calls zero-arg `Class_Initialize`
- Arguments are passed directly to `Class_Initialize` parameters
- Works with `Dim x = New Class(args)` and `Dim x As New Class(args)` forms

### Generics Phase 1 — Collection(Of T)
Type-safe collections with runtime type validation on `.Add()`.

```vb
' Typed collection — only accepts integers
Dim scores As New Collection(Of Integer)
scores.Add 100     ' OK
scores.Add 200     ' OK
' scores.Add "hi" ' ERROR: Type mismatch

' Typed collection of strings
Dim names As New Collection(Of String)
names.Add "Alice"
names.Add "Bob"

' Auto-instantiation (no New required)
Dim items As Collection(Of Double)
items.Add 3.14    ' Collection created automatically

' Untyped collection still works
Dim anything As New Collection
anything.Add 42
anything.Add "mixed"
anything.Add 3.14
```

**Supported type parameters:** `Integer`, `Long`, `LongLong`, `Double`, `Single`, `Float`,
`String`, `Boolean`, `Variant` (any type), and any class name.

### Generic Classes — Class(Of T)

Define your own generic classes using the `Class ClassName(Of T)` syntax. This allows a single class definition to work safely with any type parameter.

```vb
Class Container(Of T)
    Private _value As T
    Private _isEmpty As Boolean
    
    Sub New()
        _isEmpty = True
    End Sub
    
    Sub Set(val As T)
        _value = val
        _isEmpty = False
    End Sub
    
    Function Get() As T
        If _isEmpty Then
            Throw New Exception("Container is empty")
        End If
        Return _value
    End Function
End Class

Sub Main()
    ' Create a container for integers
    Dim intBox As Variant = New Container(Of Integer)
    intBox.Set(42)
    Print CStr(intBox.Get())  ' 42
    
    ' Create a container for strings
    Dim strBox As Variant = New Container(Of String)
    strBox.Set("Hello, Generics!")
    Print strBox.Get()  ' Hello, Generics!
End Sub
```

**Key points:**
- Type parameter `T` acts as a placeholder for any type
- Type safety is enforced — `Container(Of Integer)` can only hold integers
- Methods using `T` work transparently with any type
- Multiple type parameters are supported: `Class Pair(Of T, U)`

**For a working example with more patterns, see** [corpus/06_classes/06_class_generics.vg](../corpus/06_classes/06_class_generics.vg).

### Optional Types — Nullable Values

Optional types can hold either a real value or `Nothing` (null). Use the `Optional(T)` syntax to declare a variable that may not contain a value.

```vb
Function LookupUser(id As Integer) As Optional(String)
    If id = 1 Then
        Return "Alice"
    Else
        Return Nothing  ' User not found
    End If
End Function

Sub Main()
    Dim user As Optional(String) = LookupUser(1)
    
    ' Check if the optional has a value
    If Not (user Is Nothing) Then
        Print "Found: " & user
    Else
        Print "User not found"
    End If
    
    ' Provide a default value
    Dim userName As String = IIf(user Is Nothing, "Guest", user)
    Print "Welcome, " & userName
End Sub
```

**Key points:**
- `Optional(T)` variables can be `Nothing` or contain a value of type `T`
- Always check `Is Nothing` before using the value to avoid runtime errors
- Default return value for `Optional` with no explicit return is `Nothing`
- Pairs well with `IIf()` for concise null-coalescing patterns
- Safer alternative to using `Variant` for optional references

**For a complete example with defensive programming patterns, see** [corpus/01_basics/06_optional_types.vg](../corpus/01_basics/06_optional_types.vg).

### Classes and Types

```vb
' Define a custom type
Type PlayerStats
    Health As Integer
    Mana As Integer
    Level As Integer
End Type

' Using the type
Dim stats As PlayerStats
stats.Health = 100
stats.Mana = 50
stats.Level = 5
```

### Inheritance

```vb
' Base class (inherits from Node)
Class Character Inherits Node2D
    Public Health As Integer = 100
    Public Name As String
    
    Sub New(playerName As String)
        Name = playerName
    End Sub
    
    Sub TakeDamage(amount As Integer)
        Health = Health - amount
        If Health <= 0 Then Die()
    End Sub
    
    Virtual Sub Die()
        Print Name & " has died!"
    End Sub
End Class

' Derived class
Class Player Inherits Character
    Public Experience As Integer = 0
    
    Sub New(playerName As String)
        MyBase.New(playerName)  ' Call base constructor
    End Sub
    
    Override Sub Die()
        MyBase.Die()  ' Call base method
        Print "Game Over!"
    End Sub
End Class
```

### Interfaces

```vb
Interface IDamageable
    Sub TakeDamage(amount As Integer)
    Function IsAlive() As Boolean
End Interface

Class Enemy Implements IDamageable
    Private health As Integer = 50
    
    Sub TakeDamage(amount As Integer) Implements IDamageable.TakeDamage
        health = health - amount
    End Sub
    
    Function IsAlive() As Boolean Implements IDamageable.IsAlive
        Return health > 0
    End Function
End Class
```

> **Implements Runtime Verification:** When a module declares `Implements IFoo`, VisualGasic checks at load time that at least one `IFoo_*` method exists in the module. If none is found, a warning is printed to the console so you can catch unimplemented interfaces early.

### Events (WithEvents / RaiseEvent)
VisualGasic supports VB6-style custom events with `Event`, `RaiseEvent`, and `WithEvents`.

#### Declaring and Raising Events

```vb
' Declare an event in a class module
Event ProgressChanged(percent As Integer)
Event Completed()

Sub DoWork()
    Dim i As Integer
    For i = 1 To 100
        ' ... work ...
        RaiseEvent ProgressChanged(i)
    Next
    RaiseEvent Completed()
End Sub
```

`RaiseEvent` compiles to a dedicated bytecode opcode (`OP_RAISE_EVENT`) that emits a Godot signal with the same name, supporting up to 5 arguments.

#### WithEvents — Automatic Event Wiring

Declare a variable with `WithEvents` to automatically connect its events to handler subs in the current module. Handlers are named `VariableName_EventName`:

```vb
Dim WithEvents worker As Worker

Sub StartJob()
    Set worker = New Worker
    worker.DoWork   ' Events fire automatically
End Sub

' Handler — auto-connected when "worker" is assigned
Sub worker_ProgressChanged(percent As Integer)
    ProgressBar1.Value = percent
End Sub

Sub worker_Completed()
    MsgBox "Job finished!"
End Sub
```

When you `Set` a WithEvents variable, VisualGasic scans the module for subs matching the `varname_SignalName` pattern and connects them via Godot's signal system. Reassigning the variable disconnects old handlers automatically.

#### Event Wiring at a Glance

| Feature | Syntax | Notes |
|---------|--------|-------|
| Declare event | `Event Name(params)` | Compiles to Godot signal |
| Fire event | `RaiseEvent Name(args)` | Emits the signal (up to 5 args) |
| Auto-connect | `Dim WithEvents x As T` | Handlers: `x_EventName(...)` |
| Manual connect | `Connect obj, "signal", "handler"` | Standard Godot approach |

### Properties and Methods

```vb
' Properties with Get/Set
Class Player
    Private _health As Integer
    Private _name As String
    
    ' Read-write property
    Property Health As Integer
        Get
            Return _health
        End Get
        Set(value As Integer)
            _health = Clamp(value, 0, 100)  ' Validate on set
        End Set
    End Property
    
    ' Read-only property
    ReadOnly Property Name As String
        Get
            Return _name
        End Get
    End Property
    
    ' Auto-implemented property (simple)
    Property Score As Integer  ' Automatically creates backing field
    
    ' Methods
    Sub TakeDamage(amount As Integer)
        Health = Health - amount
        If Health <= 0 Then Die()
    End Sub
    
    Function IsAlive() As Boolean
        Return Health > 0
    End Function
End Class

' Using properties
Dim player As New Player()
player.Health = 100       ' Calls Set
Print player.Health       ' Calls Get
player.Score = 500        ' Auto property
```

---


## VB6 Global Objects
These virtual objects emulate VB6's built-in global objects. They are resolved automatically when referenced by name — no `Dim` or `New` required.

### App Object
The `App` object provides information about the running application, mirroring VB6's `App` global.

| Property | Type | Description |
|----------|------|-------------|
| `App.Path` | String | Directory containing the executable |
| `App.EXEName` | String | Executable filename (without extension) |
| `App.Title` | String | Application title from project settings |
| `App.Major` | Integer | Major version number |
| `App.Minor` | Integer | Minor version number |
| `App.Revision` | Integer | Revision number |
| `App.PrevInstance` | Boolean | Always `False` (reserved) |
| `App.ProductName` | String | Same as Title |
| `App.CompanyName` | String | Company name (empty by default) |

```vb
Print "Running from: " & App.Path
Print "Application: " & App.Title & " v" & CStr(App.Major) & "." & CStr(App.Minor)
```

### Screen Object
The `Screen` object provides display information, mirroring VB6's `Screen` global.

| Property | Type | Description |
|----------|------|-------------|
| `Screen.Width` | Integer | Screen width in pixels |
| `Screen.Height` | Integer | Screen height in pixels |
| `Screen.TwipsPerPixelX` | Integer | Always 1 (pixels, not twips) |
| `Screen.TwipsPerPixelY` | Integer | Always 1 (pixels, not twips) |
| `Screen.MousePointer` | Integer | Mouse cursor type (0 = default) |

```vb
Print "Resolution: " & CStr(Screen.Width) & "x" & CStr(Screen.Height)
```

### Err Object
The `Err` object is also documented under [Error Handling](#error-handling). It provides runtime error information and supports `Err.Raise` and `Err.Clear`:

```vb
On Error Resume Next
Err.Raise 5, "MyModule", "Invalid argument"
Print Err.Number         ' 5
Print Err.Source         ' "MyModule"
Print Err.Description    ' "Invalid argument"
Err.Clear
On Error GoTo 0
```

### Printer Object
The `Printer` object emulates VB6's global `Printer` object for generating printed output. It is resolved automatically by name — no `Dim` required.

#### Methods

| Method | Description |
|--------|-------------|
| `Printer.Print text` | Sends text to the output buffer |
| `Printer.EndDoc` | Finishes the print job and flushes output |
| `Printer.NewPage` | Starts a new page (increments `Page`) |
| `Printer.KillDoc` | Cancels the current print job |
| `Printer.Circle x, y, r` | Draws a circle (stub — logs parameters) |
| `Printer.Line x1, y1, x2, y2` | Draws a line (stub — logs parameters) |
| `Printer.PaintPicture pic, x, y` | Paints an image (stub — logs parameters) |
| `Printer.PSet x, y` | Sets a pixel (stub — logs parameters) |

#### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Printer.Font` | String | `"Arial"` | Current font name |
| `Printer.FontSize` | Integer | `12` | Font size in points |
| `Printer.FontBold` | Boolean | `False` | Bold flag |
| `Printer.FontItalic` | Boolean | `False` | Italic flag |
| `Printer.Orientation` | Integer | `1` | 1 = Portrait, 2 = Landscape |
| `Printer.Copies` | Integer | `1` | Number of copies |
| `Printer.Page` | Integer | `1` | Current page number (read-only, incremented by `NewPage`) |
| `Printer.CurrentX` | Integer | `0` | Horizontal print position |
| `Printer.CurrentY` | Integer | `0` | Vertical print position |
| `Printer.ScaleWidth` | Integer | `8500` | Logical page width |
| `Printer.ScaleHeight` | Integer | `11000` | Logical page height |
| `Printer.hDC` | Integer | `0` | Device context handle (stub) |
| `Printer.ColorMode` | Integer | `1` | 1 = Monochrome, 2 = Color |
| `Printer.PaperSize` | Integer | `1` | Paper size constant |

```vb
' Basic printing example
Printer.Font = "Courier New"
Printer.FontSize = 10
Printer.Print "Invoice #1234"
Printer.Print "Date: " & Format(Now, "yyyy-mm-dd")
Printer.NewPage
Printer.Print "Page 2 content"
Printer.EndDoc
```

### PrintForm Statement
`PrintForm` captures the current viewport to a PNG image file, emulating VB6's `PrintForm` statement.

```vb
' Capture the current form/viewport to an image
PrintForm
```

The image is saved to `user://printform_output.png` in the Godot user data directory. A confirmation message is printed to the console.

---


## COM-Style Objects
These classes emulate common VB6/VBScript COM objects. Instantiate with `Dim obj As New ClassName` or via `CreateObject("ProgID")`.

### VGCollection
A VB6-compatible ordered collection with optional string keys and **1-based indexing**.

**Aliases:** `New Collection` · `CreateObject("VB6.Collection")` · `CreateObject("VBA.Collection")`

| Method/Property | Description |
|-----------------|-------------|
| `Add item [, key] [, Before n] [, After n]` | Add an item with optional key and position |
| `Remove index_or_key` | Remove by 1-based index or key |
| `Item(index_or_key)` | Retrieve by 1-based index or key |
| `Count` | Number of items |
| `HasKey(key)` | Check if a key exists |
| `Clear` | Remove all items |
| `ToArray` | Return all items as an Array |

```vb
Dim col As New Collection
col.Add "Apple", "a"
col.Add "Banana", "b"
col.Add "Cherry", "c"

Print col.Count              ' 3
Print col.Item(1)            ' "Apple"
Print col.Item("b")          ' "Banana"

col.Remove 2                 ' Remove "Banana"
Print col.Count              ' 2

col.Clear
```

### VGRegEx
VBScript.RegExp emulation wrapping Godot's PCRE2-based RegEx engine.

**Aliases:** `New RegExp` · `CreateObject("VBScript.RegExp")`

| Property/Method | Description |
|-----------------|-------------|
| `Pattern` | The regular expression pattern |
| `Global` | Boolean — match all occurrences (default: False) |
| `IgnoreCase` | Boolean — case-insensitive matching |
| `Test(string)` | Returns True if the pattern matches |
| `Execute(string)` | Returns an Array of VGRegExMatch objects |
| `Replace(string, replacement)` | Replace matched text |

```vb
Dim re As New RegExp
re.Pattern = "\d+"
re.Global = True

If re.Test("abc123def") Then
    Print "Found digits!"
End If

Dim result As String = re.Replace("abc123def456", "NUM")
Print result    ' "abcNUMdefNUM"
```

### VGHttpRequest
MSXML2.XMLHTTP emulation wrapping Godot HTTPClient. Suitable for REST API calls.

**Aliases:** `New HttpRequest` · `New XMLHTTP` · `CreateObject("MSXML2.XMLHTTP")`

| Method/Property | Description |
|-----------------|-------------|
| `open method, url` | Initialize a request ("GET", "POST", etc.) |
| `setRequestHeader name, value` | Set a request header |
| `send [body]` | Send the request |
| `responseText` | The response body as a string |
| `status` | HTTP status code (200, 404, etc.) |
| `getAllResponseHeaders` | All response headers as a string |

```vb
Dim http As New HttpRequest
http.open "GET", "https://api.example.com/data"
http.setRequestHeader "Accept", "application/json"
http.send
If http.status = 200 Then
    Print http.responseText
End If
```

### VGTimer
A poll-based timer control for periodic events. Also provides the `Timer()` function.

**Aliases:** `New VBTimer` · `New Timer`

| Property | Description |
|----------|-------------|
| `Interval` | Timer interval in milliseconds |
| `Enabled` | Boolean — whether the timer is active |

**Timer() Function:** Returns the number of seconds since midnight as a Double.

```vb
' Timer function
Dim t As Double = Timer()
Print "Seconds since midnight: " & CStr(t)

' Timer class
Dim tmr As New VBTimer
tmr.Interval = 1000    ' Fire every second
tmr.Enabled = True
```

---


## System Integration
These classes provide C#-level system integration: native FFI, ODBC databases, cryptography, XML, ZIP, async threading, and package management. All classes use VB6-style PascalCase aliases for a familiar BASIC feel.

> **See also:** [docs/SYSTEM_INTEGRATION.md](SYSTEM_INTEGRATION.md) for the full API reference with extended examples.

### NativeLibrary (FFI)
Load any shared library (`.so`, `.dll`, `.dylib`) and call its C functions — the cross-platform equivalent of VB6's `Declare Function`.

**Aliases:** `New NativeLibrary`

| Method/Property | Description |
|-----------------|-------------|
| `Load(path)` | Load a shared library. Returns `True` on success |
| `Unload()` | Unload the library |
| `QuickCall(name, ...)` | Convenience alias for simple calls; prefer `CallFunction(...)` when the return type matters |
| `CallFunction(name, returnType, argTypes, args)` | Full-signature call |
| `CallSimple(name, args)` | Array-based call |
| `CreateCallback(callable, returnType, argTypes)` | Create a C callback |
| `.IsLoaded` | Whether a library is loaded |
| `.Path` | The loaded library path |
| `.LastError` | Last error message |

```vb
Dim lib As New NativeLibrary
lib.Load "libm.so.6"

' Quick call — auto-detects types
Dim result As Variant
result = lib.CallFunction("sqrt", "double", Array("double"), Array(144.0))
Print "sqrt(144) = " & CStr(result)       ' 12.0

' Full call with explicit types
result = lib.CallFunction("pow", "double", Array("double", "double"), Array(2.0, 10.0))
Print "pow(2,10) = " & CStr(result)       ' 1024.0

lib.Unload
```

**Supported FFI Types:** `void`, `int`, `uint`, `long`, `ulong`, `float`, `double`, `pointer`, `string`, `int8`, `uint8`, `int16`, `uint16`, `int32`, `uint32`, `int64`, `uint64`

> **C++ example:** [demos/Utilities/FFI/demo_ffi_cpp_lib.vg](../demos/Utilities/FFI/demo_ffi_cpp_lib.vg) shows how to build and call a Vec2 C++ class via C ABI wrappers (create, get/set, math, normalize, string representation).

### NativeStruct
Describe C struct memory layouts and allocate/read/write fields.

**Aliases:** `New NativeStruct`

| Method/Property | Description |
|-----------------|-------------|
| `AddField(name, type)` | Add a field to the struct layout |
| `Create()` | Allocate a new struct instance → handle |
| `Destroy(handle)` | Free a struct instance |
| `SetField(handle, name, value)` | Write a field |
| `GetField(handle, name)` | Read a field |
| `GetPointer(handle)` | Get raw memory address |
| `.Size` | Struct size in bytes |
| `.FieldCount` | Number of fields |
| `.FieldNames` | Array of field name strings |

```vb
Dim s As New NativeStruct

' Define: struct Point { int x; int y; }
s.AddField "x", "int"
s.AddField "y", "int"

Print "Size: " & CStr(s.Size) & " bytes"   ' 8

Dim h As Integer = s.Create()
s.SetField h, "x", 100
s.SetField h, "y", 200
Print s.GetField(h, "x")                    ' 100
s.Destroy h
```

### VGOdbc (Database)
Connect to any ODBC database — PostgreSQL, MySQL, SQL Server, SQLite, Oracle, and more. The ODBC driver is loaded dynamically at runtime.

**Aliases:** `New VGOdbc`

| Method/Property | Description |
|-----------------|-------------|
| `Open()` | Connect using `.ConnectionString` |
| `OpenWithString(cs)` | Connect with a specified connection string |
| `Close()` | Disconnect |
| `Execute(sql)` | Run INSERT/UPDATE/DELETE |
| `ExecuteParams(sql, params)` | Parameterized execute (safe from injection) |
| `Query(sql)` | SELECT → `Array` of `Dictionary` rows |
| `QueryParams(sql, params)` | Parameterized query |
| `BeginTransaction()` | Start a transaction |
| `CommitTransaction()` | Commit |
| `RollbackTransaction()` | Rollback |
| `ListTables()` | List table names |
| `TableExists(name)` | Check if a table exists |
| `ListDrivers()` | List installed ODBC drivers |
| `.ConnectionString` | Get/set connection string |
| `.IsOpen` | Connection state |
| `.LastError` | Last error message |

```vb
Dim db As New VGOdbc
db.ConnectionString = "Driver={PostgreSQL};Server=localhost;Database=myapp;"
db.Open

' Query → Array of Dictionary
Dim rows As Variant
rows = db.Query("SELECT name, email FROM users ORDER BY name")
For i = 0 To rows.size() - 1
    Print rows[i]["name"] & " — " & rows[i]["email"]
Next i

' Parameterized query (safe)
rows = db.QueryParams("SELECT * FROM users WHERE age > ?", Array(18))

' Transactions
db.BeginTransaction
db.Execute "UPDATE accounts SET balance = balance - 100 WHERE id = 1"
db.Execute "UPDATE accounts SET balance = balance + 100 WHERE id = 2"
db.CommitTransaction

db.Close
```

### VGCrypto (Cryptography)
Static utility class for hashing, encoding, encryption, and random generation.

| Method | Description |
|--------|-------------|
| `MD5(text)` / `SHA1(text)` / `SHA256(text)` | Hash a string → hex |
| `MD5Bytes(data)` / `SHA1Bytes(data)` / `SHA256Bytes(data)` | Hash bytes → hex |
| `base64_encode(data)` / `base64_decode(b64)` | Base64 encode/decode |
| `hex_encode(data)` / `hex_decode(hex)` | Hex encode/decode |
| `encrypt_aes(data, key)` | AES-256-CBC encrypt |
| `decrypt_aes(data, key)` | AES-256-CBC decrypt |
| `random_bytes(count)` | Random byte array |
| `generate_uuid()` | RFC 4122 v4 UUID string |
| `hmac_sha256(data, key)` | HMAC-SHA256 hex signature |

```vb
' Hashing
Print VGCrypto.MD5("hello")        ' "5d41402abc4b2a76b9719d911017c592"
Print VGCrypto.SHA256("hello")     ' 64-char hex

' AES Encryption
Dim key As String = "MySecretKey12345MySecretKey12345"   ' 32 bytes
Dim encrypted As Variant
encrypted = VGCrypto.encrypt_aes("top secret".to_utf8_buffer(), key.to_utf8_buffer())
Dim decrypted As Variant
decrypted = VGCrypto.decrypt_aes(encrypted, key.to_utf8_buffer())
Print decrypted.get_string_from_utf8()    ' "top secret"

' UUID
Dim id As String = VGCrypto.generate_uuid()
Print id   ' "550e8400-e29b-41d4-a716-446655440000"
```

### VGXml (XML Processing)
Read, write, parse, and query XML documents.

**Aliases:** `New VGXml`

| Method/Property | Description |
|-----------------|-------------|
| `LoadFile(path)` | Load XML from a file |
| `LoadString(xml)` | Load XML from a string |
| `SaveFile(path)` | Save to file |
| `ToString()` | Get XML as a string |
| `Parse()` | Parse into a Dictionary tree |
| `SelectNodes(path)` | XPath query → Array of nodes |
| `SelectSingleNode(path)` | XPath query → first match |
| `.XmlContent` | Property — raw XML string |
| `.LastError` | Property — last error |

```vb
Dim xml As New VGXml
xml.LoadString "<catalog><book>Title A</book><book>Title B</book></catalog>"

' Parse to Dictionary tree
Dim tree As Variant = xml.Parse()
Print tree["tag"]                       ' "catalog"
Print tree["children"][0]["text"]       ' "Title A"

' XPath-style queries
Dim books As Variant = xml.SelectNodes("catalog/book")
Print "Found " & CStr(books.size()) & " books"

' Save
xml.SaveFile "user://output.xml"
```

### VGZip (ZIP Archives)
Create, read, and extract ZIP archives.

**Aliases:** `New VGZip`

| Method/Property | Description |
|-----------------|-------------|
| `OpenRead(path)` | Open for reading |
| `OpenWrite(path)` | Create/open for writing |
| `Close()` | Close the archive |
| `AddText(name, text)` | Add a text file to archive |
| `AddFile(name, data)` | Add a binary file (PackedByteArray) |
| `ListFiles()` | List file names → Array |
| `read_text(name)` | Read a file as String |
| `read_file(name)` | Read a file as PackedByteArray |
| `file_exists(name)` | Check if file exists |
| `extract_to(dir)` | Extract all files to a directory |
| `extract_file(name, dest)` | Extract a single file |
| `.FileCount` | Number of files |
| `.IsOpen` | Whether the archive is open |
| `.ArchivePath` | File path |
| `.LastError` | Last error |

```vb
' Create a ZIP
Dim zip As New VGZip
zip.OpenWrite "user://backup.zip"
zip.AddText "readme.txt", "Hello World!"
zip.AddText "data/config.ini", "[Settings]" & vbCrLf & "Theme=Dark"
zip.Close

' Read a ZIP
Dim reader As New VGZip
reader.OpenRead "user://backup.zip"
Print "Files: " & CStr(reader.FileCount)
Print reader.read_text("readme.txt")      ' "Hello World!"
reader.extract_to "user://restored/"
reader.Close
```

### VGTask (Async Tasks)
Run work on a background thread without freezing the game. Wraps `std::thread` with Godot-safe signalling.

**Aliases:** `New VGTask`

| Method/Property | Description |
|-----------------|-------------|
| `RunAsync(callable)` | Run a Callable on a background thread |
| `RunAsyncWithArgs(callable, args)` | Run with arguments |
| `RunDelayed(callable, seconds)` | Run after a delay |
| `Cancel()` | Cancel the task |
| `WaitForResult()` | Block until the result is ready |
| `.IsComplete` | Whether the task finished |
| `.IsRunning` | Whether it's currently running |
| `.IsFailed` | Whether an error occurred |
| `.IsCancelled` | Whether it was cancelled |
| `.Status` | String — `"pending"`, `"running"`, `"completed"`, `"failed"`, `"cancelled"` |
| `.Result` | The return value |
| `.ErrorMessage` | Error text (if failed) |

```vb
Dim task As New VGTask
task.RunAsync Callable(Me, "HeavyWork")

' ... do other things ...

Dim result As Variant = task.WaitForResult()
Print "Done: " & CStr(result)

' Delayed execution
Dim later As New VGTask
later.RunDelayed Callable(Me, "Greet"), 2.0   ' Run after 2 seconds

' Cancellation
task.Cancel
Print task.IsCancelled   ' True
```

### VGTaskRunner (Parallel)
Run multiple tasks in parallel and collect their results.

**Aliases:** `New VGTaskRunner`

| Method/Property | Description |
|-----------------|-------------|
| `AddTask(callable)` | Add a task to the queue |
| `RunAll()` | Run all tasks in parallel, wait for completion |
| `RunAllLimited(max)` | Run with a maximum thread count |
| `get_all_results()` | Get all results → Array |
| `.TaskCount` | Number of tasks |
| `.CompletedCount` | Number finished |
| `.Progress` | 0.0 – 1.0 progress float |

```vb
Dim runner As New VGTaskRunner

runner.AddTask Callable(Me, "Worker1")
runner.AddTask Callable(Me, "Worker2")
runner.AddTask Callable(Me, "Worker3")

Print "Running " & CStr(runner.TaskCount) & " tasks..."
runner.RunAll

Dim results As Variant = runner.get_all_results()
For i = 0 To results.size() - 1
    Print "Task " & CStr(i) & ": " & CStr(results[i])
Next i
```

### VisualGasicPackage (Package Manager)
Manage project dependencies with semantic versioning, registries, and `vgpkg.json` manifests.

**Aliases:** `New VisualGasicPackage`

| Method | Description |
|--------|-------------|
| `Initialize(workspace)` | Initialize the package manager |
| `Shutdown()` | Shut down cleanly |
| `InstallPackage(name, version)` | Install a package → Dictionary result |
| `UninstallPackage(name)` | Remove a package |
| `update_package(name)` | Update a package |
| `update_all_packages()` | Update everything |
| `AddRegistry(name, url [, token])` | Add a package registry |
| `search_packages(query)` | Search for packages |
| `get_installed_packages()` | List installed packages |
| `initialize_project(path)` | Create a `vgpkg.json` manifest |
| `add_dependency(name, constraint)` | Add a dependency |
| `remove_dependency(name)` | Remove a dependency |
| `get_project_dependencies()` | List dependencies |
| `create_package_template(name, type)` | Scaffold a new package |
| `build_package(path)` | Build a package for distribution |
| `publish_package(path, registry)` | Publish to a registry |
| `clear_cache()` | Clear download cache |

**Version constraints:** `^1.2.0` (compatible), `~1.2.0` (patch only), `>=2.0.0` (at least), `1.5.0` (exact).

```vb
Dim pkg As New VisualGasicPackage
pkg.Initialize "res://"

' Add a registry
pkg.AddRegistry "official", "https://packages.visualgasic.org"

' Install a package
Dim result As Variant = pkg.InstallPackage("vg-math", "^1.0.0")
Print result["message"]

' Project dependencies
pkg.initialize_project "res://"
pkg.add_dependency "vg-ui", ">=2.0.0"

Dim deps As Variant = pkg.get_project_dependencies()
Print "Dependencies: " & CStr(deps.size())

pkg.Shutdown
```

### Cross-Platform System Classes

The following system classes are OS-level integrations. Support differs by target platform:

| Class | Linux | macOS | Windows | Android | Web |
|-------|-------|-------|---------|---------|-----|
| `VGProcess` (`New Process`) | ✅ fork/exec/pipe | ✅ fork/exec/pipe | ✅ CreateProcess/CreatePipe | ❌ | ❌ |
| `VGSocket` (`New WinSock`) | ✅ POSIX sockets | ✅ POSIX sockets | ✅ WinSock2 | ❌ | ❌ |
| `VGFileWatcher` (`New FileSystemWatcher`) | ✅ inotify | ❌ (not implemented) | ✅ FindFirstChangeNotification | ❌ | ❌ |
| `VGSysTray` (`New SysTray`) | ⚠️ stub | ⚠️ stub | ✅ Shell_NotifyIcon + HWND_MESSAGE | ❌ | ❌ |

`❌` means not currently implemented in the runtime backend for that target.

### Real COM Interop (Windows)

`CreateObject()` now falls through to the real COM subsystem on Windows when the requested ProgID isn't a built-in emulated object. This lets you automate Excel, Word, Outlook, or any installed COM server:

**Platform support:**
- ✅ Windows: real COM fallback via native COM automation
- ⚠️ macOS/Linux/Android/Web: built-in emulated ProgIDs only (no native COM subsystem)

```vb
' Built-in objects — work on all platforms
Dim dict As Object = CreateObject("Scripting.Dictionary")

' Real COM — Windows only
Dim xl As Object = CreateObject("Excel.Application")
xl.Visible = True
xl.Workbooks.Add
xl.Cells(1, 1).Value = "Hello from VisualGasic!"
```


### PyBridgeFacade (Python Integration)
Call Python 3 modules and functions from VisualGasic using an out-of-process worker (Tier A). No compile-time flag required.

**Prerequisite:** Python 3 must be installed and on PATH.

**Aliases:** `New PyBridgeFacade`

| Method/Property | Description |
|-----------------|-------------|
| `InitializeBridge()` | Launch worker, return success |
| `IsAvailable()` | Static — check if Python 3 is on PATH |
| `GetStatus()` | Current bridge status string |
| `PyImport(module)` | Import a Python module |
| `PyCall(handle, method, args)` | Call a function |
| `PyCallAsync(module, method, args)` | Async call path (v6 currently runs synchronously) |
| `PyProcessBuffer(handle, method, buffer)` | Bulk data processing |
| `shutdown()` | Graceful worker termination |

**Project setting — typed wire protocol (C2, opt-in):**

| Setting | Default | Description |
|---------|---------|-------------|
| `vg/python/use_typed_protocol` | `false` | When `true`, IPC uses msgpack instead of JSON so integer arguments (`Array(0, 5)`) reach Python as `int`. Enable for numpy integer-arg APIs. Test: `test_py_msgpack_typed.vg`. |

```vb
Dim bridge As New PyBridgeFacade

If Not bridge.InitializeBridge() Then
    Print "Failed: " & bridge.GetStatus()
    Exit Sub
End If

Dim mathMod As Variant
mathMod = bridge.PyImport("math")

Dim result As Variant
result = bridge.PyCall(mathMod, "sqrt", Array(144.0))
Print "sqrt(144) = " & CStr(result)       ' 12.0

bridge.shutdown()
```

> **See also:** [demos/Utilities/PythonBridge/demo_python_bridge.vg](../demos/Utilities/PythonBridge/demo_python_bridge.vg) and [docs/SYSTEM_INTEGRATION.md](SYSTEM_INTEGRATION.md#17-python-bridge-pybridgefacade).


### VisualGasicLanguage (GDExtension static API)

Static methods on the registered `VisualGasicLanguage` class. Callable from GDScript plugins and editor tools when the GDExtension is loaded.

| Method | Returns | Description |
|--------|---------|-------------|
| `vg_analyze_causal_graph(code, roots)` | `Dictionary` | Static AST walk of VG source. Keys: `ok` (`bool`), `report` (`String` — indented causal chain). `roots` is an optional `Array` of Sub names to start from (e.g. `["btnOK_Click"]`); empty = all event handlers. Used by `VGCausalChain.generate()` and the Code Navigator **Show Causal Chain** button. |
| `vg_profiler_enable(enabled)` | — | Enable/disable bytecode profiler |
| `vg_profiler_get_report()` | `Dictionary` | Hot-path timing report |
| `vg_profiler_clear()` | — | Reset profiler counters |

**Causal chain from GDScript:**

```gdscript
var result := VisualGasicLanguage.vg_analyze_causal_graph(vg_source, ["btnSubmit_Click"])
if result.get("ok"):
    print(result.get("report"))
```

Prefer `VGCausalChain.new().generate(text, roots)` in editor code — it falls back to a regex walker when the C++ path is unavailable or hits known AST gaps.

> **See also:** [IDE Tools — Causal Chain](manual/ide_tools.md#causal-chain-static-analysis-v54), [tests/test_vg_causal_chain.gd](../tests/test_vg_causal_chain.gd).


---


## System-Level Programming
These classes provide system-level APIs for Linux, Windows, macOS, and Android. On Web targets, OS-level operations are limited by browser sandbox constraints.

> **See also:** [docs/SYSTEM_INTEGRATION.md](SYSTEM_INTEGRATION.md) for the full API reference with extended examples.

### VGSystem (System Info)
Cross-platform system information queries — hostname, CPU, RAM, disk, OS, uptime, environment variables, and locale.

| Method | Returns | Description |
|--------|---------|-------------|
| `Hostname` | String | Machine hostname |
| `Username` | String | Current user name |
| `ProcessId` | int | Current process ID |
| `CpuCount` | int | Number of logical CPU cores |
| `CpuName` | String | CPU model name |
| `Architecture` | String | CPU architecture (x86_64, aarch64, etc.) |
| `TotalMemory` | int64 | Total RAM in bytes |
| `FreeMemory` | int64 | Free RAM in bytes |
| `UsedMemory` | int64 | Used RAM in bytes |
| `MemoryUsagePercent` | double | RAM usage as percentage |
| `FreeDiskSpace(path)` | int64 | Free disk space in bytes |
| `TotalDiskSpace(path)` | int64 | Total disk space in bytes |
| `DiskUsagePercent(path)` | double | Disk usage as percentage |
| `OsName` | String | Operating system name |
| `OsVersion` | String | OS version/release |
| `OsFull` | String | OS name + version combined |
| `Endianness` | String | "little" or "big" |
| `Uptime` | double | System uptime in seconds |
| `GetEnv(name)` | String | Get environment variable |
| `SetEnv(name, value)` | void | Set environment variable |
| `HasEnv(name)` | bool | Check if env var exists |
| `GetAllEnv()` | Dictionary | All environment variables |
| `GetLocale()` | String | System locale (e.g. "en_US.UTF-8") |
| `GetLanguage()` | String | Two-letter language code |
| `GetTimezone()` | String | Timezone name |
| `GetTimezoneOffset()` | int | UTC offset in seconds |
| `GetSystemInfo()` | Dictionary | Everything in one call |

```vb
Dim sys As Object = New VGSystem
Print "Host: " & sys.Hostname
Print "CPU: " & sys.CpuName & " (" & CStr(sys.CpuCount) & " cores)"
Print "RAM: " & CStr(sys.TotalMemory / 1073741824) & " GB"
Print "OS: " & sys.OsFull
Print "Uptime: " & CStr(CInt(sys.Uptime / 3600)) & " hours"
Print "Locale: " & sys.GetLocale()
Print "HOME=" & sys.GetEnv("HOME")
```

### VGSignalHandler (OS Signals)
Handle OS-level signals (SIGINT, SIGTERM, SIGHUP) and atexit cleanup. On Windows, maps to `SetConsoleCtrlHandler` events.

| Method | Description |
|--------|-------------|
| `OnInterrupt(handler)` | Register SIGINT (Ctrl+C) handler |
| `OnTerminate(handler)` | Register SIGTERM handler |
| `OnHangup(handler)` | Register SIGHUP handler |
| `OnUser1(handler)` | Register SIGUSR1 handler |
| `OnUser2(handler)` | Register SIGUSR2 handler |
| `OnExit(handler)` | Register atexit cleanup |
| `SetHandler(name, handler)` | Generic signal handler by name |
| `RemoveHandler(name)` | Remove a registered handler |
| `HasHandler(name)` | Check if handler is registered |
| `GetRegisteredSignals()` | List all registered signal names |
| `RaiseSignal(name)` | Send signal to self |
| `LastSignal` | Name of last received signal |
| `IsInstalled` | Whether any handlers are installed |

```vb
Dim sh As Object = New VGSignalHandler
sh.OnInterrupt(Lambda() => Print("Caught Ctrl+C!"))
sh.OnExit(Lambda() => Print("Cleaning up..."))
sh.OnTerminate(Lambda() => Print("Shutting down gracefully"))
```

### VGFilePermissions (Permissions & Links)
UNIX file permissions, ownership, symbolic links, file locking, and VB6-style file attributes.

| Method | Returns | Description |
|--------|---------|-------------|
| `Chmod(path, mode)` | bool | Set UNIX permissions (e.g. `&o755`) |
| `GetPermissions(path)` | int | Get permission bits |
| `GetPermissionsString(path)` | String | "rwxr-xr-x" format |
| `IsReadable(path)` | bool | Check read access |
| `IsWritable(path)` | bool | Check write access |
| `IsExecutable(path)` | bool | Check execute access |
| `Chown(path, owner, group)` | bool | Change ownership |
| `GetOwner(path)` | String | Get file owner name |
| `GetGroup(path)` | String | Get file group name |
| `CreateSymlink(link, target)` | bool | Create symbolic link |
| `CreateHardlink(link, target)` | bool | Create hard link |
| `IsSymlink(path)` | bool | Test for symlink |
| `ReadSymlink(path)` | String | Read symlink target |
| `LockFile(path)` | bool | Exclusive file lock (blocking) |
| `TryLockFile(path)` | bool | Non-blocking lock attempt |
| `UnlockFile(path)` | bool | Release file lock |
| `IsLocked(path)` | bool | Check if currently locked |
| `GetAttr(path)` | int | VB6-style attributes (1=ReadOnly, 2=Hidden, 4=System, 16=Dir, 32=Archive) |
| `SetAttr(path, flags)` | bool | Set VB6-style attributes |
| `GetFileInfo(path)` | Dictionary | Full stat info (size, created, modified, mode, etc.) |
| `FileLen(path)` | int64 | File size in bytes |
| `FileType(path)` | String | "file", "directory", "symlink", etc. |

```vb
Dim fp As Object = New VGFilePermissions
fp.Chmod "/tmp/script.sh", &o755
Print fp.GetPermissionsString("/tmp/script.sh")    ' "rwxr-xr-x"
fp.CreateSymlink "/tmp/link", "/tmp/script.sh"
Print "Owner: " & fp.GetOwner("/tmp/script.sh")

' VB6-style attributes
Dim attr As Integer = fp.GetAttr("C:\data.txt")
If attr And 1 Then Print "Read-only"

' File locking
If fp.TryLockFile("/tmp/data.lock") Then
    ' ... critical section ...
    fp.UnlockFile "/tmp/data.lock"
End If
```

### VGMemoryBuffer (Raw Memory)
Raw byte-level memory buffer with Peek/Poke access — the VB6 equivalent of `CopyMemory` / `RtlMoveMemory`. Useful for binary protocols, FFI interop, and system programming.

| Method | Description |
|--------|-------------|
| `Allocate(size)` | Allocate buffer (bytes) |
| `Resize(size)` | Resize preserving content |
| `Free()` | Release memory |
| `IsAllocated` | Check if allocated |
| `Size` | Current buffer size |
| `Fill(byte)` / `FillRange(off, len, byte)` | Fill with value |
| `Clear()` | Zero-fill |
| `PeekByte/Int16/UInt16/Int32/Int64(offset)` | Read typed value |
| `PeekFloat/Double(offset)` | Read floating point |
| `PeekString(offset, length)` | Read UTF-8 string |
| `PokeByte/Int16/UInt16/Int32/Int64(offset, value)` | Write typed value |
| `PokeFloat/Double(offset, value)` | Write floating point |
| `PokeString(offset, value)` | Write UTF-8 string |
| `CopyTo(dest, srcOff, dstOff, len)` | Copy to another buffer |
| `CopyFrom(src, srcOff, dstOff, len)` | Copy from another buffer |
| `ToByteArray()` / `ToByteArrayRange(off, len)` | Export to PackedByteArray |
| `FromByteArray(arr)` | Import from PackedByteArray |
| `FindByte(value, start)` | Search for byte |
| `FindPattern(bytes, start)` | Search for byte pattern |
| `HexDump(offset, length)` | Debug hex dump string |
| `GetPointer()` | Raw int64 address for FFI |

```vb
Dim buf As Object = New VGMemoryBuffer
buf.Allocate 1024

' Write a C-style struct: int32 id, float x, float y
buf.PokeInt32 0, 42
buf.PokeFloat 4, 3.14
buf.PokeFloat 8, 2.71

' Read it back
Print "ID: " & CStr(buf.PeekInt32(0))
Print "X: " & CStr(buf.PeekFloat(4))
Print "Y: " & CStr(buf.PeekFloat(8))

' Pass to FFI
Dim lib As Object = New NativeLibrary
lib.Load "mylib.so"
lib.CallFunction "process_data", "void", Array("pointer", "int"), Array(buf.GetPointer(), buf.Size)

Print buf.HexDump(0, 16)
buf.Free
```

### VGIPC (Inter-Process Communication)
Named pipes, UNIX domain sockets, and POSIX shared memory for communicating between processes.

#### Named Pipes

| Method | Description |
|--------|-------------|
| `CreateNamedPipe(path)` | Create a FIFO (mkfifo / CreateNamedPipe) |
| `OpenPipe(path, mode)` | Open pipe for "read" or "write" |
| `ReadPipe(maxBytes)` | Read string from pipe |
| `ReadPipeBytes(maxBytes)` | Read raw bytes from pipe |
| `WritePipe(data)` | Write string to pipe |
| `WritePipeBytes(data)` | Write raw bytes to pipe |
| `ClosePipe()` | Close pipe fd |
| `DeleteNamedPipe(path)` | Remove FIFO from filesystem |

#### UNIX Domain Sockets

| Method | Description |
|--------|-------------|
| `CreateDomainSocket(path)` | Create, bind, and listen |
| `ConnectDomainSocket(path)` | Connect as client |
| `AcceptConnection()` | Accept incoming connection |
| `ReadSocket(maxBytes)` | Read string |
| `ReadSocketBytes(maxBytes)` | Read raw bytes |
| `WriteSocket(data)` | Write string |
| `WriteSocketBytes(data)` | Write raw bytes |
| `CloseSocket()` | Close socket and unlink |

#### Shared Memory

| Method | Description |
|--------|-------------|
| `CreateSharedMemory(name, size)` | Create new shared segment (shm_open + mmap) |
| `OpenSharedMemory(name, size)` | Attach to existing segment |
| `WriteSharedMemory(offset, data)` | Write string at offset |
| `WriteSharedMemoryBytes(offset, data)` | Write bytes at offset |
| `ReadSharedMemory(offset, length)` | Read string |
| `ReadSharedMemoryBytes(offset, length)` | Read bytes |
| `CloseSharedMemory()` | Detach and unlink |

```vb
' === Named Pipe Example ===
Dim ipc As Object = New VGIPC
ipc.CreateNamedPipe "/tmp/myapp.pipe"
ipc.OpenPipe "/tmp/myapp.pipe", "write"
ipc.WritePipe "Hello from VG!"
ipc.ClosePipe

' === Shared Memory Example ===
Dim shm As Object = New VGIPC
shm.CreateSharedMemory "myapp_data", 4096
shm.WriteSharedMemory 0, "Shared state"
Dim data As String = shm.ReadSharedMemory(0, 12)
Print data  ' "Shared state"
shm.CloseSharedMemory

' === Domain Socket Server ===
Dim srv As Object = New VGIPC
srv.CreateDomainSocket "/tmp/myapp.sock"
srv.AcceptConnection
Dim msg As String = srv.ReadSocket(1024)
srv.WriteSocket "ACK: " & msg
srv.CloseSocket
```

### VGAndroidBridge (Android Platform)
JNI bridge for Android platform APIs. All methods return safe defaults on non-Android platforms (Linux, Windows, macOS, Web).

**Platform support:**
- ✅ Android: full JNI-backed behavior
- ⚠️ Windows/macOS/Linux/Web: safe no-op/default return behavior

| Method | Returns | Description |
|--------|---------|-------------|
| `SdkVersion` | int | Android SDK version (e.g. 34) |
| `DeviceModel` | String | Device model name |
| `DeviceManufacturer` | String | Device manufacturer |
| `AndroidVersion` | String | Android version string |
| `PackageName` | String | App package name |
| `AppVersion` | String | App version string |
| `DeviceId` | String | Device identifier |
| `HasPermission(perm)` | bool | Check if permission granted |
| `RequestPermission(perm)` | void | Request single permission |
| `RequestPermissions(perms)` | void | Request multiple permissions |
| `GetGrantedPermissions()` | Array | List granted permissions |
| `OpenUrl(url)` | void | Open URL in browser |
| `ShareText(text, title)` | void | Share text via intent |
| `SendEmail(to, subject, body)` | void | Send email via intent |
| `OpenAppSettings()` | void | Open app settings page |
| `ShowToast(message, duration)` | void | Show Android toast |
| `Vibrate(ms)` | void | Vibrate device |
| `ExternalStoragePath` | String | External storage path |
| `CacheDir` | String | App cache directory |
| `FilesDir` | String | App files directory |
| `GetBatteryInfo()` | Dictionary | Battery level, status, charging |
| `IsAndroid()` | bool | True on Android, false elsewhere |
| `KeepScreenOn(enabled)` | void | Prevent screen timeout |

```vb
Dim android As Object = New VGAndroidBridge

If android.IsAndroid() Then
    Print "Device: " & android.DeviceManufacturer & " " & android.DeviceModel
    Print "Android " & android.AndroidVersion & " (SDK " & CStr(android.SdkVersion) & ")"
    
    ' Check and request permissions
    If Not android.HasPermission("android.permission.CAMERA") Then
        android.RequestPermission "android.permission.CAMERA"
    End If
    
    ' UI
    android.ShowToast "Welcome to VisualGasic!", 1
    android.Vibrate 200
    
    ' Battery
    Dim batt As Dictionary = android.GetBatteryInfo()
    Print "Battery: " & CStr(batt("level")) & "%"
    
    ' Share
    android.ShareText "Check out VisualGasic!", "Share"
End If
```

---


## Modern Language Features

### Lambda Expressions

```vb
' Simple lambda
Dim square = Lambda(x) x * x
Dim result = square(5)  ' 25

' Lambda with multiple parameters
Dim add = Lambda(a, b) a + b
Dim sum = add(3, 4)     ' 7

' Using lambdas with collections
Dim numbers = [1, 2, 3, 4, 5]
Dim doubled = numbers.Map(Lambda(x) x * 2)  ' [2, 4, 6, 8, 10]
```

### Pattern Matching

```vb
' Match statement
Match playerInput
    Case "north", "n"
        MoveNorth()
    Case "south", "s"
        MoveSouth()
    Case "inventory", "i"
        ShowInventory()
    Case Else
        Print "Unknown command"
End Match

' Pattern matching with conditions
Match score
    Case Is > 1000
        Print "Legendary!"
    Case 500 To 999
        Print "Expert!"
    Case Is < 100
        Print "Beginner"
End Match
```

**See Also:** [Select Case](#select-case) - Classic conditional branching with similar syntax.

### Null-Safe Operations

```vb
' Null-safe member access
Dim length = player?.Name?.Length  ' Returns Nothing if player or Name is null

' Null coalescing
Dim displayName = player?.Name ?? "Unknown Player"
```

### Type Inference

```vb
' Compiler infers types
Dim count = 42           ' Integer
Dim message = "Hello"    ' String  
Dim active = True        ' Boolean
Dim position = Vector2(100, 200)  ' Vector2
```

---


## Godot Integration

### Node Interaction

```vb
' Getting node references
Dim player = GetNode("Player")
Dim ui = GetNode("UI/HealthBar")

' Creating nodes dynamically
Dim newSprite = CreateNode("Sprite2D")
newSprite.Texture = Load("res://player.png")
AddChild(newSprite)
```

### Signal System

```vb
' Declare signals
Signal HealthChanged(newHealth As Integer)
Signal PlayerDied()

' Emit signals
Emit HealthChanged(currentHealth)
Emit PlayerDied()

' Connect signals
Connect(player, "health_changed", "OnHealthChanged")

' Signal handler
Sub OnHealthChanged(newHealth As Integer)
    healthBar.Value = newHealth
End Sub
```

### Scene Management

```vb
' Change scenes
ChangeScene("res://levels/Level2.tscn")

' Get current scene
Dim currentScene = GetTree().CurrentScene
```

### Resource Loading

```vb
' Load resources
Dim texture = Load("res://sprites/player.png")
Dim sound = Load("res://audio/jump.wav")
Dim scene = Load("res://enemies/Goblin.tscn")

' Instantiate scenes
Dim enemy = scene.Instantiate()
AddChild(enemy)
```

### Inline Sprite Data (*Sprite blocks)

Small pixel-art sprites can live **inline in `.vg` source** as labeled `Data` sections. The IDE **Context Rail** shows a live pixel grid when the caret is inside a valid block (label name must end with `Sprite`, e.g. `PlayerSprite:`, `CloudSprite:`).

**Block layout**

1. **Label line** — `NameSprite:` (identifier + colon; optional trailing comment).
2. **Header row** — first `Data` line after the label with **exactly four integers**:

        Data w, h, transparentIdx, paletteId

   | Field | Meaning |
   |-------|---------|
   | `w` | Width in pixels (1–32 for inline editor) |
   | `h` | Height in pixels (1–32 for inline editor) |
   | `transparentIdx` | Palette index treated as transparent when drawing (usually `0`) |
   | `paletteId` | Which built-in 16-color palette to use when painting in the IDE (see table below) |

3. **Pixel rows** — exactly **`h` more `Data` lines**, each with **`w` comma-separated palette indices** (0–15), one row per scanline, top to bottom.

The **next label** (e.g. `PlatformData:`) ends the sprite section.

**Example (8×8, NES palette, index 0 transparent)**

```vb
PlayerSprite:
Data 8, 8, 0, 0
Data 0, 0, 1, 1, 0, 0, 0, 0
Data 0, 1, 2, 2, 1, 0, 0, 0
Data 0, 1, 2, 2, 1, 0, 0, 0
Data 0, 1, 2, 2, 1, 0, 0, 0
Data 0, 0, 1, 1, 0, 0, 0, 0
Data 0, 0, 0, 0, 0, 0, 0, 0
Data 0, 0, 0, 0, 0, 0, 0, 0
Data 0, 0, 0, 0, 0, 0, 0, 0
```

**Built-in palettes (`paletteId`)**

| ID | Name | Notes |
|----|------|-------|
| 0 | **NES** | Default; classic 16-color NES-like set |
| 1 | **GameBoy** | Green handheld + extra accent slots |
| 2 | **C64** | Commodore 64 |
| 3 | **CGA** | IBM CGA 16-color |

Each palette has **16 indices (0–15)**. Index `0` is often used as transparent in `transparentIdx`, but any index 0–15 may be chosen.

**NES palette (paletteId = 0)** — index → color:

| Idx | Color | Idx | Color |
|-----|-------|-----|-------|
| 0 | `#7C7C7C` gray | 8 | `#503000` brown |
| 1 | `#0000FC` blue | 9 | `#007800` green |
| 2 | `#0000BC` dark blue | 10 | `#006800` dark green |
| 3 | `#4428BC` purple | 11 | `#005800` forest |
| 4 | `#940084` magenta | 12 | `#004058` teal |
| 5 | `#A80020` red | 13 | `#000000` black |
| 6 | `#A81000` dark red | 14 | `#BCBCBC` light gray |
| 7 | `#881400` orange | 15 | `#0078F8` sky blue |

Palettes **GameBoy**, **C64**, and **CGA** use the same index range (0–15); see [Sprite Data](#sprite-data) in Part II for full hex tables.

**Reading at runtime**

```vb
Dim raw As Variant
raw = DataToArray("PlayerSprite")
' raw(0)=w, raw(1)=h, raw(2)=transparentIdx, raw(3)=paletteId
' raw(4) .. raw(4 + w*h - 1) = pixel indices, row-major (left→right, top→bottom)

' Load once in _Ready — do NOT call DataToArray inside _Draw every frame.
```

For custom RGB (not palette indices), use a separate labeled block such as `PaletteData:` with RGB triplets and map indices yourself — see platformer demos that call `PalColor(index)`.

**See also:** [Sprite Data](#sprite-data), [Data](#data), [DataToArray](#datatoarray)

### Godot Singleton Access

VisualGasic provides **universal access to all 37 Godot engine singletons** directly by name. Any registered Godot singleton can be used without imports or special setup:

```vb
' Engine singleton — performance monitoring
Dim fps As Integer = Engine.get_frames_per_second()
Dim physTicks As Integer = Engine.get_physics_ticks_per_second()
Dim isEditor As Boolean = Engine.is_editor_hint()

' OS singleton — system information
Dim osName As String = OS.get_name()
Dim cpuCount As Integer = OS.get_processor_count()
Dim cpuName As String = OS.get_processor_name()
Dim isDebug As Boolean = OS.is_debug_build()

' Time singleton — timing
Dim ms As Integer = Time.get_ticks_msec()
Dim us As Integer = Time.get_ticks_usec()
Dim unixTime As Double = Time.get_unix_time_from_system()

' Input singleton — input state
Dim mouseMode As Integer = Input.get_mouse_mode()
Dim joypads As Variant = Input.get_connected_joypads()

' DisplayServer — display info
Dim displayName As String = DisplayServer.get_name()

' AudioServer — audio info
Dim busCount As Integer = AudioServer.get_bus_count()
Dim mixRate As Double = AudioServer.get_mix_rate()
```

All 37 Godot singletons are supported, including `Engine`, `OS`, `Time`, `Input`, `DisplayServer`, `AudioServer`, `RenderingServer`, `PhysicsServer2D`, `PhysicsServer3D`, `NavigationServer2D`, `NavigationServer3D`, `ProjectSettings`, `ResourceLoader`, `ResourceSaver`, `ClassDB`, `Performance`, `IP`, `Geometry2D`, `Geometry3D`, `ThemeDB`, `TranslationServer`, `Marshalls`, and more.

### Godot Class Enum Constants

Access Godot class enum constants using `ClassName.CONSTANT_NAME` syntax:

```vb
' FileAccess mode flags
Dim mode As Integer = FileAccess.READ          ' = 1
Dim rw As Integer = FileAccess.READ_WRITE      ' = 3

' Input mouse modes
Dim captured As Integer = Input.MOUSE_MODE_CAPTURED  ' = 2

' Sky processing modes
Dim quality As Integer = Sky.PROCESS_MODE_QUALITY    ' = 1

' Node process modes
Dim inherit As Integer = Node.PROCESS_MODE_INHERIT   ' = 0
Dim always As Integer = Node.PROCESS_MODE_ALWAYS     ' = 1
```

Enum constants work with all Godot classes, including constants whose names match VG keywords (e.g., `FileAccess.READ` and `FileAccess.WRITE` work correctly even though `Read` and `Write` are VG keywords).

### Event-Driven Programming with Whenever

VisualGasic's **Whenever System** represents one of the most advanced reactive programming implementations available in any modern language, providing declarative, efficient, and memory-safe event-driven capabilities that surpass traditional reactive frameworks found in other programming ecosystems.

The Whenever system enables developers to create sophisticated, responsive applications by monitoring variables and automatically executing procedures when specific conditions are met, all while maintaining code clarity and preventing common pitfalls like callback hell or memory leaks.

#### Core Whenever Concepts

The Whenever system operates on **declarative sections** that monitor program state and react to changes:

```vb
' Basic syntax: Whenever Section [Local] SectionName variable|expression condition [value] callback[,callback...]
Whenever Section HealthMonitor playerHealth Changes UpdateHealthDisplay
Whenever Section GameOver playerLives Becomes 0 ShowGameOverScreen
Whenever Section HighScore score Exceeds 10000 CelebrationEffect
```

#### Comparison Operators

VisualGasic supports six powerful comparison operators for different monitoring scenarios:

| Operator | Description | Example |
|----------|-------------|---------|
| `Changes` | Triggers on any value change | `health Changes UpdateUI` |
| `Becomes` | Triggers when value equals target | `lives Becomes 0 GameOver` |
| `Exceeds` | Triggers when value surpasses threshold | `score Exceeds 1000 Bonus` |
| `Below` | Triggers when value falls under threshold | `health Below 25 LowHealthWarning` |
| `Between` | Triggers when value is within range | `temp Between 32 And 100 NormalTemp` |
| `Contains` | Triggers when string/array contains value | `name Contains "admin" AdminMode` |

```vb
' Comprehensive operator examples
Whenever Section HealthCritical health Below 20 ShowCriticalWarning
Whenever Section OptimalRange temperature Between 68 And 72 MaintainClimate
Whenever Section SecurityAlert username Contains "root" LogSecurityEvent
Whenever Section ScoreThreshold points Exceeds 5000 UnlockLevel
Whenever Section StatusChange gameState Changes UpdateInterface
Whenever Section Victory enemiesRemaining Becomes 0 ShowVictoryScreen
```

#### Multiple Callback Execution

Execute multiple procedures in sequence for sophisticated event handling:

```vb
' Multiple callbacks - executed in order
Whenever Section PlayerDeath health Becomes 0 SaveProgress, ShowDeathScreen, PlayDeathSound, ResetLevel

' Complex multi-step responses
Whenever Section LevelComplete enemiesKilled Exceeds targetKills UpdateScore, ShowLevelComplete, SaveProgress, LoadNextLevel

Sub SaveProgress()
    WriteFile("save.dat", gameState)
    Print "Progress saved"
End Sub

Sub ShowDeathScreen()
    FadeToBlack()
    DisplayUI("game_over")
End Sub
```

#### Advanced Complex Expressions

Monitor multiple variables simultaneously with boolean expressions that rival advanced reactive frameworks:

```vb
' Multi-variable complex conditions
Whenever Section EmergencyMode (health < 15 And mana < 10 And enemiesNear > 2) ActivateEmergencyProtocols
Whenever Section PowerUpMode (score > 1000 And level >= 3 And hasSpecialKey = True) EnablePowerMode
Whenever Section ComboSystem (consecutiveHits > 5 And timeSinceLastHit < 2.0) TriggerComboBonus
Whenever Section CriticalState (playerHealth <= 10 Or shieldEnergy <= 5) And Not invulnerable CriticalAlert

' Complex game state monitoring
Whenever Section BossPhase (bossHealth < 500 And phaseNumber < 3 And playerLevel >= 10) TriggerBossPhaseTransition
Whenever Section AchievementUnlock (totalScore >= 50000 And secretsFound >= 10 And timeCompleted < 1800) UnlockSpeedrunAchievement

Sub ActivateEmergencyProtocols()
    Print "EMERGENCY: Multiple critical conditions detected!"
    ActivateShields(True)
    SlowTime(0.5)
    HighlightEnemies(True)
End Sub

Sub TriggerComboBonus()
    comboMultiplier = comboMultiplier * 1.5
    ShowComboEffect(consecutiveHits)
    PlayComboSound()
End Sub
```

#### Scoped Sections with Automatic Cleanup

Prevent memory leaks and maintain clean code with automatic scope-based cleanup:

```vb
Sub BossEncounterPhase()
    Print "Entering boss encounter..."
    
    ' Local sections - automatically cleaned up when Sub ends
    Whenever Section Local BossRageMode bossHealth Below 30 ActivateBossRage
    Whenever Section Local BossStunned (bossHealth < 10 And bossStamina > 80) BossStunRecovery
    Whenever Section Local PlayerAdvantage (playerHealth > 50 And bossHealth < 25) PlayerAdvantageBonus
    
    ' Complex local monitoring
    Whenever Section Local CriticalMoment (bossHealth < 5 And playerHealth < 15) FinalShowdown
    
    ' Boss fight logic here...
    ExecuteBossFight()
    
    Print "Boss defeated - all local Whenever sections automatically cleaned up"
End Sub ' All Local sections automatically removed

Class GameLevel
    Sub EnterLevel()
        ' Member-scoped sections (cleaned up when object is destroyed)  
        Whenever Section Member LevelTimer gameTime Exceeds levelTimeLimit ShowTimeWarning
        Whenever Section Member ObjectiveComplete objectivesCompleted Becomes totalObjectives LevelComplete
    End Sub
End Class
```

#### Debouncing and Performance Control

Prevent callback storms and optimize performance with built-in timing controls:

```vb
' Debouncing prevents rapid-fire execution
Whenever Section UIUpdate score Changes UpdateScoreDisplay Debounce 100ms
Whenever Section NetworkSync playerPosition Changes SendPositionUpdate Throttle 50ms

' High-frequency monitoring with controlled execution
Whenever Section InputProcessor mousePosition Changes ProcessMouseInput Debounce 16ms ' ~60 FPS
```

#### Suspend and Resume Control

Dynamically control monitoring for sophisticated state management:

```vb
Sub EnterCutscene()
    ' Temporarily disable game monitoring during cutscenes
    Suspend Whenever HealthMonitor
    Suspend Whenever InputProcessor
    Suspend Whenever GameLogic
    
    PlayCutscene("intro_scene.mp4")
End Sub

Sub ExitCutscene()
    ' Re-enable monitoring
    Resume Whenever HealthMonitor
    Resume Whenever InputProcessor  
    Resume Whenever GameLogic
End Sub

Sub EnterPauseMenu()
    ' Selective suspension - keep UI active but pause game logic
    Suspend Whenever GameTimer
    Suspend Whenever EnemyAI
    ' Keep UI monitoring active
End Sub
```

#### Debugging and Monitoring Tools

Professional debugging capabilities for complex applications:

```vb
Sub DiagnoseWheneverSystem()
    ' Comprehensive system status
    Print WheneverStatus()
    ' Output:
    ' Whenever System Status:
    ' Total Sections: 8
    ' - HealthMonitor (health Changes) -> UpdateHealthBar [Active]
    ' - GameOver (lives Becomes 0) -> ShowGameOver, ResetLevel [Active] 
    ' - BossRage (bossHealth Below 30) -> ActivateBossRage [Local - BossEncounter]
    ' Active Sections: 7
    
    ' Performance monitoring
    Dim activeCount = ActiveWheneverCount()
    Print "Currently monitoring: " & activeCount & " sections"
    
    ' Cleanup for testing
    ClearWheneverSections()
    Print "All sections cleared for testing"
End Sub

Sub PerformanceAnalysis()
    ' Monitor callback execution times
    For Each section In GetWheneverSections()
        Print section.name & " - Last execution: " & section.lastExecutionTime & "ms"
    Next
End Sub
```

#### Advanced Patterns and Best Practices

**1. State Machine Implementation**
```vb
' Elegant state machine using Whenever
Whenever Section StateIdle gameState Becomes "idle" OnEnterIdle
Whenever Section StateRunning gameState Becomes "running" OnEnterRunning  
Whenever Section StatePaused gameState Becomes "paused" OnEnterPaused
Whenever Section StateGameOver gameState Becomes "gameover" OnEnterGameOver

Sub OnEnterRunning()
    EnableGameInput(True)
    StartGameTimer()
    ResumeEnemyAI()
End Sub
```

**2. Resource Management**
```vb
' Automatic resource monitoring
Whenever Section LowMemory availableMemory Below 100MB FreeResources
Whenever Section NetworkLatency pingTime Exceeds 200 SwitchToOfflineMode
Whenever Section BatteryLow batteryLevel Below 15 EnablePowerSaveMode
```

**3. Game Logic Patterns**
```vb
' Sophisticated game mechanics
Whenever Section ComboSystem (hitStreak >= 3 And timeBetweenHits < 1.0) IncrementCombo
Whenever Section DifficultyAdjust (playerDeaths > 5 And currentDifficulty > 1) ReduceDifficulty
Whenever Section AchievementSystem totalPlayTime Exceeds 3600 UnlockTimeBasedAchievement
```

**4. Safety and Performance Guidelines**

- **Avoid Recursion**: Never modify watched variables inside their callbacks
- **Use Local Scope**: Prefer `Whenever Section Local` for temporary monitoring
- **Implement Debouncing**: Add timing controls for high-frequency events  
- **Descriptive Naming**: Use clear, intention-revealing section names
- **Callback Efficiency**: Keep callback procedures fast and focused

```vb
' Good: Safe callback design
Whenever Section HealthMonitor health Changes OnHealthChanged

Sub OnHealthChanged()
    Suspend Whenever HealthMonitor  ' Prevent recursion
    
    If health <= 0 Then
        lives = lives - 1
        health = 100  ' Safe to modify now
    End If
    
    UpdateHealthBar(health)
    Resume Whenever HealthMonitor
End Sub

' Better: Use different variables to avoid recursion entirely
Whenever Section HealthMonitor health Changes UpdateHealthDisplay
Sub UpdateHealthDisplay()
    healthBarValue = health  ' Update display variable instead
End Sub
```

#### Implementation Notes

The Whenever system is fully compiled to bytecode for optimal performance:

**Bytecode Opcodes:**
- `OP_REGISTER_WHENEVER` - Registers a section with packed data Dictionary
- `OP_SUSPEND_WHENEVER` - Suspends monitoring by section name
- `OP_RESUME_WHENEVER` - Resumes monitoring of a suspended section

**Runtime Behavior:**
- Whenever sections are registered during function initialization
- The runtime monitors watched variables on each frame
- Conditions are evaluated efficiently using bytecode execution
- Local sections are automatically cleaned up when their scope ends

**Debugging Support:**
- All active sections visible in Immediate Window's "Whenever" tab
- Real-time status updates (Active/Paused)
- Right-click to pause/resume sections during gameplay
- Go to Definition to jump to section code

#### Performance and Architecture

The VisualGasic Whenever system provides:

- **Zero-Overhead Abstraction**: Compiled to efficient native code with minimal runtime cost
- **Memory Safety**: Automatic cleanup prevents memory leaks in long-running applications
- **Scalability**: Handles thousands of concurrent monitoring sections efficiently
- **Thread Safety**: Safe for multi-threaded applications and game engines
- **Integration**: Seamless integration with Godot's scene system and signals

#### Comparison with Other Frameworks

VisualGasic's Whenever system provides capabilities that exceed many established reactive frameworks:

| Feature | VisualGasic Whenever | RxJS | MobX | Vue.js Reactivity |
|---------|---------------------|------|------|------------------|
| Declarative Syntax | ✅ | ✅ | ✅ | ✅ |
| Multiple Callbacks | ✅ | ❌ | ❌ | ❌ |
| Complex Expressions | ✅ | ⚠️ | ❌ | ⚠️ |
| Automatic Cleanup | ✅ | ❌ | ❌ | ✅ |
| Built-in Debouncing | ✅ | ✅ | ❌ | ❌ |
| Memory Safety | ✅ | ❌ | ⚠️ | ✅ |
| Performance Debugging | ✅ | ❌ | ⚠️ | ⚠️ |

The Whenever system elevates VisualGasic to the forefront of reactive programming languages, providing developers with unprecedented power and safety for creating responsive, maintainable applications.

### Multitasking and Concurrency

VisualGasic's **Multitasking System** provides world-class asynchronous programming, parallel processing, and concurrency capabilities that rival and often surpass those found in modern languages like C#, TypeScript, and Kotlin. The system combines the simplicity of VB.NET async/await with the power of advanced parallel programming frameworks.

As of v3.1, all multitasking primitives are backed by **real `std::thread`** with per-thread scope cloning:

- **`Task.Run`** — spawns a real OS thread; variable scope is cloned via `Dictionary.duplicate(true)` so each thread gets independent state
- **`Parallel For`** — partitions the iteration space across `hardware_concurrency()` worker threads; falls back to serial execution for ≤4 iterations to avoid thread overhead
- **`Parallel Section`** — uses an atomic work-stealing pattern with `std::atomic<int>` next-item counter, spawning up to max-cores threads

#### Async/Await Programming

Create responsive applications with non-blocking asynchronous operations using familiar async/await syntax:

```vb
' Async function declaration
Async Function LoadPlayerDataAsync() As Task(Of PlayerData)
    ' Non-blocking database query
    Dim result = Await DatabaseQuery("SELECT * FROM players WHERE id = ?", playerId)
    
    ' Process result asynchronously
    Dim processed = Await ProcessPlayerStats(result)
    
    ' Async validation
    Dim validated = Await ValidatePlayerData(processed)
    
    Return validated
End Function

' Calling async functions
Sub GameInitialization()
    ' Start loading player data
    Dim playerTask = LoadPlayerDataAsync()
    
    ' Continue with other initialization
    LoadUIElements()
    InitializeAudio()
    SetupGameWorld()
    
    ' Wait for player data when needed
    Dim playerData = Await playerTask
    Print "Player loaded: " & playerData.Name
End Sub

' Multiple async operations
Async Sub LoadGameAssets()
    ' Parallel async operations
    Dim textureTask = LoadTexturesAsync()
    Dim soundTask = LoadSoundsAsync()
    Dim modelTask = LoadModelsAsync()
    
    ' Wait for all to complete
    Dim textures = Await textureTask
    Dim sounds = Await soundTask
    Dim models = Await modelTask
    
    Print "All assets loaded!"
End Sub
```

#### Background Task Processing

Execute long-running operations in background threads without blocking the main thread:

```vb
' Background data processing
Task.Run BackgroundAnalytics
    For i = 1 To 1000000
        ProcessAnalyticsEvent(events(i))
        
        ' Periodic progress update to main thread
        If i Mod 10000 = 0 Then
            UpdateProgressBar(i / 10000)
        End If
    Next
    
    SaveAnalyticsResults()
    NotifyCompletion()
End Task

' Named tasks for coordination
Task.Run SaveGameTask
    SerializeGameState()
    CompressGameData() 
    WriteToStorage()
    Print "Game saved successfully"
End Task

Task.Run BackupTask
    CreateBackupCopy()
    UploadToCloud()
    Print "Backup completed"
End Task

' Wait for both tasks
Task.WaitAll(SaveGameTask, BackupTask)
Print "All save operations completed"
```

#### Parallel Processing

Leverage multi-core processors with parallel loops and sections:

```vb
' Parallel For loops - automatic work distribution
Parallel For i = 0 To enemies.Count - 1
    enemies(i).UpdateAI()
    enemies(i).ProcessCollisions()
    enemies(i).UpdateAnimation()
Next

' Parallel processing with custom work distribution
Dim particleSystems(1000) As ParticleSystem
Parallel For particle = 0 To 999
    particleSystems(particle).Update(deltaTime)
    particleSystems(particle).CheckBounds()
    particleSystems(particle).ApplyPhysics()
Next

' Parallel sections for different operations
Parallel Section HighPriority
    ProcessPlayerInput()
    UpdateCameraSystem()
    ProcessAudio()
    
    ' Nested parallel processing
    Parallel For effect = 0 To activeEffects.Count - 1
        activeEffects(effect).Update()
    Next
End Section
```

#### Task Coordination and Synchronization

Coordinate multiple tasks with advanced synchronization:

```vb
' Task coordination example
Sub ComplexGameOperation()
    ' Start multiple related tasks
    Task.Run PhysicsTask
        UpdateRigidBodies()
        ProcessCollisions()
        ApplyForces()
    End Task
    
    Task.Run RenderingTask
        CullObjects()
        UpdateShaders()
        ProcessLighting()
    End Task
    
    Task.Run AITask
        For Each npc In gameWorld.NPCs
            npc.ProcessBehavior()
            npc.UpdateDecisionTree()
        Next
    End Task
    
    ' Wait for critical tasks before proceeding
    Task.WaitAll(PhysicsTask, RenderingTask)
    
    ' Continue with tasks that depend on physics/rendering
    Task.Run PostProcessingTask
        ApplyScreenEffects()
        ProcessParticles() 
        UpdateUI()
    End Task
    
    ' Wait for any single task to complete (first-wins scenario)
    Dim completedTask = Task.WaitAny(AITask, PostProcessingTask)
    
    If completedTask = AITask Then
        Print "AI processing completed first"
    Else
        Print "Post-processing completed first"
    End If
End Sub
```

#### Thread-Safe Reactive Programming

Combine multitasking with the Whenever system for concurrent reactive programming:

```vb
' Thread-safe Whenever monitoring across parallel tasks
Whenever Section Parallel SystemMonitor
    cpuUsage Changes LogPerformance, CheckCriticalLevels
    memoryUsage Exceeds 80 TriggerGarbageCollection
    frameRate Below 30 ReduceQualitySettings
End Whenever

' Parallel tasks updating monitored variables safely
Task.Run MonitoringTask1
    For i = 1 To 100
        cpuUsage = GetCPUUsage()
        memoryUsage = GetMemoryUsage()
        frameRate = Engine.GetFramesPerSecond()
        
        ' Whenever callbacks triggered thread-safely
        Thread.Sleep(100)
    Next
End Task

Task.Run MonitoringTask2
    For i = 1 To 50
        cpuUsage = cpuUsage + GetAdditionalLoad()
        
        ' Complex concurrent conditions
        If memoryUsage > 75 And frameRate < 45 Then
            OptimizeResources()
        End If
    Next
End Task

' Both tasks can safely trigger Whenever callbacks
Task.WaitAll(MonitoringTask1, MonitoringTask2)
```

#### Error Handling in Async Context

Robust error handling across asynchronous operations:

```vb
Async Function RobustAsyncOperation() As Task(Of String)
    Try
        ' Parallel async operations with error handling
        Dim dataTask = LoadDataAsync()
        Dim configTask = LoadConfigAsync()
        
        ' Wait with timeout
        Dim result = Await dataTask.WithTimeout(5000)
        Dim config = Await configTask.WithTimeout(3000)
        
        Return ProcessResultAndConfig(result, config)
        
    Catch timeoutEx As TimeoutException
        Print "Operation timed out: " & timeoutEx.Message
        Return GetCachedData()
        
    Catch networkEx As NetworkException
        Print "Network error: " & networkEx.Message
        Return GetOfflineData()
        
    Catch ex As Exception
        Print "Unexpected error: " & ex.Message
        Throw ' Re-throw for higher-level handling
        
    Finally
        ' Always cleanup resources
        CleanupNetworkConnections()
        CleanupTempFiles()
    End Try
End Function

' Task error handling
Task.Run RiskyOperation
    Try
        ProcessRiskyData()
    Catch ex As Exception
        LogError(ex)
        NotifyUser("Background operation failed")
    End Try
End Task
```

#### Performance Optimizations

Advanced multitasking patterns for maximum performance:

```vb
' CPU-intensive parallel processing
Sub OptimizedParallelProcessing()
    Dim dataChunks = SplitDataIntoChunks(bigDataSet, Environment.ProcessorCount)
    
    Parallel For chunk = 0 To dataChunks.Count - 1
        ProcessDataChunk(dataChunks(chunk))
    Next
End Sub

' Memory-efficient async streaming
Async Function StreamLargeFile() As Task
    Using fileStream = New FileStream("large_file.dat")
        Dim buffer(8192) As Byte
        
        While Not fileStream.AtEnd
            Dim bytesRead = Await fileStream.ReadAsync(buffer)
            Await ProcessBufferAsync(buffer, bytesRead)
        End While
    End Using
End Function

' Lock-free concurrent data structures
Sub ConcurrentDataProcessing()
    Dim concurrentQueue As New ConcurrentQueue(Of GameEvent)
    Dim concurrentDict As New ConcurrentDictionary(Of String, PlayerData)
    
    ' Producer tasks
    Task.Run EventProducer
        For i = 1 To 1000
            concurrentQueue.Enqueue(CreateGameEvent(i))
        Next
    End Task
    
    ' Consumer tasks  
    Task.Run EventConsumer1
        While Not concurrentQueue.IsEmpty
            Dim gameEvent
            If concurrentQueue.TryDequeue(gameEvent) Then
                ProcessGameEvent(gameEvent)
            End If
        End While
    End Task
    
    Task.Run EventConsumer2
        While Not concurrentQueue.IsEmpty
            Dim gameEvent
            If concurrentQueue.TryDequeue(gameEvent) Then
                ProcessGameEvent(gameEvent)
            End If  
        End While
    End Task
End Sub
```

#### Real-World Example: Game Engine Integration

Complete example integrating all multitasking features:

```vb
' Advanced game loop with multitasking
Async Sub GameLoop()
    ' Initialize concurrent systems
    Whenever Section Parallel PerformanceMonitor
        frameRate Below 30 ReduceQuality
        memoryUsage Exceeds 512 TriggerGC
    End Whenever
    
    While gameRunning
        ' Parallel frame processing
        Parallel Section GameUpdate
            ' Physics runs on dedicated thread
            Task.Run PhysicsUpdate
                physicsWorld.Step(deltaTime)
                ProcessCollisions()
            End Task
            
            ' AI processing in parallel
            Task.Run AIUpdate  
                Parallel For i = 0 To activeAI.Count - 1
                    activeAI(i).Update(deltaTime)
                Next
            End Task
            
            ' Audio processing
            Task.Run AudioUpdate
                audioEngine.Update()
                ProcessSpatialAudio()
            End Task
        End Section
        
        ' Wait for critical systems
        Task.WaitAll(PhysicsUpdate, AIUpdate)
        
        ' Render frame (main thread)
        RenderFrame()
        
        ' Async operations that don't block frame
        Dim saveTask = SaveGameStateAsync()
        Dim analyticsTask = SendAnalyticsAsync()
        
        ' Don't wait - let them complete in background
        
        frameCount += 1
        Await NextFrame() ' Yield until next frame
    End While
End Sub
```

#### Multitasking Capabilities Summary

**🚀 Advanced Features:**
- **Async/Await**: Modern asynchronous programming with familiar syntax
- **Task Management**: Background task execution with coordination
- **Parallel Processing**: Automatic multi-core utilization
- **Thread-Safe Reactive**: Concurrent Whenever system monitoring
- **WorkerThreadPool Integration**: Godot's optimized threading system

**🔥 Performance Benefits:**
- **Multi-Core Scaling**: Automatic work distribution across CPU cores
- **Non-Blocking I/O**: Responsive UI during long operations
- **Memory Efficiency**: Lock-free data structures and minimal overhead
- **Godot Integration**: Native engine thread pool utilization

**🛡️ Safety and Reliability:**
- **Exception Handling**: Robust error propagation in async context
- **Resource Management**: Automatic cleanup and disposal
- **Deadlock Prevention**: Safe task coordination patterns
- **Memory Safety**: Garbage collection integration

#### Framework Comparison

VisualGasic's multitasking capabilities compare favorably with industry leaders:

| Feature | VisualGasic | C# async/await | TypeScript Promises | Kotlin Coroutines |
|---------|-------------|----------------|-------------------|------------------|
| Async/Await Syntax | ✅ | ✅ | ✅ | ✅ |
| Parallel Processing | ✅ | ✅ | ❌ | ⚠️ |
| Task Coordination | ✅ | ✅ | ⚠️ | ✅ |
| Thread Safety | ✅ | ⚠️ | ❌ | ✅ |
| Reactive Integration | ✅ | ❌ | ❌ | ❌ |
| Game Engine Integration | ✅ | ❌ | ❌ | ❌ |
| Zero-Copy Optimization | ✅ | ⚠️ | ❌ | ⚠️ |

**Most Advanced**: VisualGasic surpasses traditional async frameworks by seamlessly integrating reactive programming, parallel processing, and game engine optimization into a unified, safe, and performant multitasking system.

---


---

<a id="part-ii"></a>
<a id="command-reference"></a>

## Part II — Command Reference (A–Z)

Every one of the 350 built-in keywords, statements, functions, and namespace verbs documented by the Command Help panel gets a dedicated page below. Pages follow the classic *Visual Basic 5 Super Bible* layout: **Purpose**, **Syntax**, **Parameters**, **Description**, **Example**, and **See Also**.


### Symbols

## _draw

**Purpose** — Called when the CanvasItem needs to be redrawn.

**Syntax**

    Sub _Draw()

**Description**

Called when the CanvasItem needs to be redrawn. Use draw_* methods inside. Call [b]queue_redraw[/b] to trigger.

**Example**

    Sub _Draw()
        DrawCircle 100, 100, 50, RGB(255, 0, 0)
        DrawLine 0, 0, 200, 200, RGB(0, 255, 0)
    End Sub

**Godot Mapping** — [`CanvasItem._draw()`](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem-method-_draw)

**See Also** — [_ready](#_ready), [_process](#_process), [_physics_process](#_physics_process), [_input](#_input)

---

## _input

**Purpose** — Called when any input event occurs (keyboard, mouse, touch, gamepad).

**Syntax**

    Sub _Input(event As InputEvent)

**Parameters**

- `event`

**Description**

Called when any input event occurs (keyboard, mouse, touch, gamepad). Consume with [b]set_input_as_handled[/b].

**Example**

    Sub _Input(event As InputEvent)
        If event.is_action_pressed("jump") Then
            velocity.y = -400
        End If
    End Sub

**Godot Mapping** — [`Node._input()`](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-_input)

**See Also** — [_ready](#_ready), [_process](#_process), [_physics_process](#_physics_process), [_draw](#_draw)

---

## _physics_process

**Purpose** — Called every physics frame (default 60 fps).

**Syntax**

    Sub _PhysicsProcess(delta As Single)

**Parameters**

- `delta`

**Description**

Called every physics frame (default 60 fps). Use for physics-based movement and collision detection.

**Example**

    Sub _PhysicsProcess(delta As Single)
        velocity.y += gravity * delta
        move_and_slide
    End Sub

**Godot Mapping** — [`Node._physics_process()`](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-_physics_process)

**See Also** — [move_and_slide](#move_and_slide), [velocity](#command-reference), [is_on_floor](#is_on_floor), [is_on_wall](#is_on_wall), [delta](#delta), [_ready](#_ready), [_process](#_process), [_input](#_input), [_draw](#_draw)

---

## _process

**Purpose** — Called every frame.

**Syntax**

    Sub _Process(delta As Single)

**Parameters**

- `delta`

**Description**

Called every frame. [b]delta[/b] is the elapsed time in seconds. Use for game logic, animation, and non-physics movement.

**Example**

    Sub _Process(delta As Single)
        rotation_degrees += 90 * delta
    End Sub

**Godot Mapping** — [`Node._process()`](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-_process)

**See Also** — [_ready](#_ready), [_physics_process](#_physics_process), [_input](#_input), [_draw](#_draw)

---

## _ready

**Purpose** — Called when the node and all its children have entered the scene tree.

**Syntax**

    Sub _Ready()

**Description**

Called when the node and all its children have entered the scene tree. Use for initialization.

**Example**

    Sub _Ready()
        Dim startPos As Vector2 = position
        visible = True
    End Sub

**Godot Mapping** — [`Node._ready()`](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-_ready)

**See Also** — [_process](#_process), [_physics_process](#_physics_process), [_input](#_input), [_draw](#_draw)

---


### A

## AABB

**Purpose** — Axis-aligned bounding box in 3D.

**Syntax**

    AABB() | AABB(positionVec3, sizeVec3)

**Description**

Axis-aligned bounding box in 3D. Used for visibility culling, region tests. Methods: .HasPoint(p), .Intersects(other), .GetCenter(), .Grow(by), .Encloses(other), .GetVolume().

**Example**

    Dim region = AABB(Vector3(-5, 0, -5), Vector3(10, 4, 10))
    If region.HasPoint(enemy.position) Then
        enemy.Aggro()
    End If

**See Also** — [Quaternion](#quaternion), [QuaternionFromEuler](#quaternionfromeuler), [Basis](#basis), [Transform2D](#transform2d), [Transform3D](#transform3d), [Plane](#plane), [Slerp](#slerp)

---

## Abs

**Purpose** — Returns the absolute value of a number.

**Syntax**

    Abs(number)

**Parameters**

- `number`

**Description**

Returns the absolute value of a number.

**Example**

    Print Abs(-5)    ' 5
    Print Abs(3.14)  ' 3.14

**See Also** — [Int](#int), [Sqr](#sqr), [Rnd](#rnd), [Randomize](#randomize), [RandRange](#randrange), [Round](#round), [Clamp](#clamp), [Lerp](#lerp), [Mod](#mod)

---

## add_child

**Purpose** — Adds a child node to this node.

**Syntax**

    add_child(node As Node)

**Parameters**

- `node`

**Description**

Adds a child node to this node. The child will appear in the scene tree under this node.

**Example**

    Dim bullet As Node2D = preload("res://Bullet.tscn").instantiate()
    add_child bullet

**Godot Mapping** — [`Node.add_child()`](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-add_child)

**See Also** — [get_node](#get_node), [remove_child](#remove_child), [queue_free](#queue_free), [get_tree](#get_tree), [instantiate](#instantiate)

---

## And

**Purpose** — Logical AND; also performs bitwise AND on numeric operands.

**Syntax**

    expression1 And expression2

**Parameters**

- `And expression2`

**Description**

When both operands are boolean or non-numeric: performs logical AND — returns True only if both expressions are True.

When both operands are numeric: performs bitwise AND — each bit position is True only if both operand bits are 1. This follows VB6 semantics.

**Logical Example**

    If health > 0 And ammo > 0 Then
        Fire()
    End If

**Bitwise Example**

    Dim flags As Integer = 12      ' Binary: 1100
    Dim mask As Integer = 10       ' Binary: 1010
    Dim result = flags And mask    ' Result: 8 (Binary: 1000)
    
    Dim isAdmin = userFlags And &H100   ' Extract bit 8
    flags And= &HFF                ' Bitwise AND assignment

**See Also** — [Or](#or), [Not](#not), [Xor](#xor), [<<](#command-reference), [>>](#command-reference)

---

## Animation.Current

**Purpose** — Returns the name of the currently playing animation, or empty string if none.

**Syntax**

    Animation.Current(player) As String

**Parameters**

- `player`

**Description**

Returns the name of the currently playing animation, or empty string if none.

**Example**

    If Animation.Current(playerAnim) = "die" Then
        GameOver()
    End If

**See Also** — [Animation.Play](#animationplay), [Animation.Stop](#animationstop), [Animation.Pause](#animationpause), [Animation.Resume](#animationresume), [Animation.Seek](#animationseek), [Animation.Speed](#animationspeed), [Animation.IsPlaying](#animationisplaying), [Animation.Length](#animationlength), [Animation.Loop](#animationloop)

---

## Animation.IsPlaying

**Purpose** — Returns True if the player is currently playing an animation.

**Syntax**

    Animation.IsPlaying(player) As Boolean

**Parameters**

- `player`

**Description**

Returns True if the player is currently playing an animation.

**Example**

    If Not Animation.IsPlaying(playerAnim) Then
        Animation.Play playerAnim, "idle"
    End If

**See Also** — [Animation.Play](#animationplay), [Animation.Stop](#animationstop), [Animation.Pause](#animationpause), [Animation.Resume](#animationresume), [Animation.Seek](#animationseek), [Animation.Speed](#animationspeed), [Animation.Current](#animationcurrent), [Animation.Length](#animationlength), [Animation.Loop](#animationloop)

---

## Animation.Length

**Purpose** — Returns the length in seconds of an animation.

**Syntax**

    Animation.Length(player [, name]) As Double

**Parameters**

- `player`
- `name`

**Description**

Returns the length in seconds of an animation. With no name, returns the current animation's length.

**Example**

    Dim total = Animation.Length(playerAnim, "walk")
    Print "Walk is " & total & "s long"

**See Also** — [Animation.Play](#animationplay), [Animation.Stop](#animationstop), [Animation.Pause](#animationpause), [Animation.Resume](#animationresume), [Animation.Seek](#animationseek), [Animation.Speed](#animationspeed), [Animation.Current](#animationcurrent), [Animation.IsPlaying](#animationisplaying), [Animation.Loop](#animationloop)

---

## Animation.Loop

**Purpose** — Sets whether the named animation should loop.

**Syntax**

    Animation.Loop(name, looped [, player])

**Parameters**

- `name`
- `looped`
- `player`

**Description**

Sets whether the named animation should loop. Persisted on the underlying Animation resource, so it survives stop/play.

**Example**

    Animation.Loop "idle", True
    Animation.Loop "jump", False

**See Also** — [Animation.Play](#animationplay), [Animation.Stop](#animationstop), [Animation.Pause](#animationpause), [Animation.Resume](#animationresume), [Animation.Seek](#animationseek), [Animation.Speed](#animationspeed), [Animation.Current](#animationcurrent), [Animation.IsPlaying](#animationisplaying), [Animation.Length](#animationlength)

---

## Animation.Pause

**Purpose** — Pauses the current animation without resetting it.

**Syntax**

    Animation.Pause(player)

**Parameters**

- `player`

**Description**

Pauses the current animation without resetting it. Resume with Animation.Resume.

**Example**

    Animation.Pause playerAnim

**See Also** — [Animation.Play](#animationplay), [Animation.Stop](#animationstop), [Animation.Resume](#animationresume), [Animation.Seek](#animationseek), [Animation.Speed](#animationspeed), [Animation.Current](#animationcurrent), [Animation.IsPlaying](#animationisplaying), [Animation.Length](#animationlength), [Animation.Loop](#animationloop)

---

## Animation.Play

**Purpose** — Plays a named animation on an AnimationPlayer node.

**Syntax**

    Animation.Play(player, name [, speed])

**Parameters**

- `player`
- `name`
- `speed`

**Description**

Plays a named animation on an AnimationPlayer node. Optional speed scale (1.0 = normal, 2.0 = double).

**Example**

    Animation.Play playerAnim, "walk"
    Animation.Play playerAnim, "sprint", 1.5

**See Also** — [Animation.Stop](#animationstop), [Animation.Pause](#animationpause), [Animation.Resume](#animationresume), [Animation.Seek](#animationseek), [Animation.Speed](#animationspeed), [Animation.Current](#animationcurrent), [Animation.IsPlaying](#animationisplaying), [Animation.Length](#animationlength), [Animation.Loop](#animationloop)

---

## Animation.Resume

**Purpose** — Resumes a paused animation from its current position.

**Syntax**

    Animation.Resume(player)

**Parameters**

- `player`

**Description**

Resumes a paused animation from its current position.

**Example**

    Animation.Resume playerAnim

**See Also** — [Animation.Play](#animationplay), [Animation.Stop](#animationstop), [Animation.Pause](#animationpause), [Animation.Seek](#animationseek), [Animation.Speed](#animationspeed), [Animation.Current](#animationcurrent), [Animation.IsPlaying](#animationisplaying), [Animation.Length](#animationlength), [Animation.Loop](#animationloop)

---

## Animation.Seek

**Purpose** — Jumps to a specific time in the current animation.

**Syntax**

    Animation.Seek(player, seconds [, update])

**Parameters**

- `player`
- `seconds`
- `update`

**Description**

Jumps to a specific time in the current animation. update=True applies the change immediately.

**Example**

    Animation.Seek playerAnim, 1.5

**See Also** — [Animation.Play](#animationplay), [Animation.Stop](#animationstop), [Animation.Pause](#animationpause), [Animation.Resume](#animationresume), [Animation.Speed](#animationspeed), [Animation.Current](#animationcurrent), [Animation.IsPlaying](#animationisplaying), [Animation.Length](#animationlength), [Animation.Loop](#animationloop)

---

## Animation.Speed

**Purpose** — Sets playback speed for all animations on this player.

**Syntax**

    Animation.Speed(player, scale)

**Parameters**

- `player`
- `scale`

**Description**

Sets playback speed for all animations on this player. 1.0 = normal, 0.5 = slow-mo, 2.0 = fast.

**Example**

    Animation.Speed playerAnim, 0.5   ' slow motion

**See Also** — [Animation.Play](#animationplay), [Animation.Stop](#animationstop), [Animation.Pause](#animationpause), [Animation.Resume](#animationresume), [Animation.Seek](#animationseek), [Animation.Current](#animationcurrent), [Animation.IsPlaying](#animationisplaying), [Animation.Length](#animationlength), [Animation.Loop](#animationloop)

---

## Animation.Stop

**Purpose** — Stops the current animation.

**Syntax**

    Animation.Stop(player [, keepState])

**Parameters**

- `player`
- `keepState`

**Description**

Stops the current animation. Pass True for keepState to leave the animated properties at their current values (don't reset).

**Example**

    Animation.Stop playerAnim

**See Also** — [Animation.Play](#animationplay), [Animation.Pause](#animationpause), [Animation.Resume](#animationresume), [Animation.Seek](#animationseek), [Animation.Speed](#animationspeed), [Animation.Current](#animationcurrent), [Animation.IsPlaying](#animationisplaying), [Animation.Length](#animationlength), [Animation.Loop](#animationloop)

---

## Array

**Purpose** — Creates and returns an array containing the specified values.

**Syntax**

    Array(value1, value2, ...)

**Parameters**

- `value1`
- `value2`
- `...`

**Description**

Creates and returns an array containing the specified values.

**Example**

    Dim colors As Variant = Array("Red", "Green", "Blue")
    Print colors(0)  ' "Red"

**See Also** — [Integer](#integer), [Long](#long), [Single](#single), [Double](#double), [String](#string), [Boolean](#boolean), [Variant](#variant), [ReDim](#redim), [LBound](#lbound), [UBound](#ubound)

---

## Async

**Purpose** — Marks a procedure as asynchronous, allowing the use of Await inside it.

**Syntax**

    Async Sub ProcedureName()
    Async Function FuncName() As Task(Of Type)

**Description**

Marks a procedure as asynchronous, allowing the use of Await inside it.

**Example**

    Async Sub LoadLevel()
        Dim data As String = Await ReadFileAsync("level.dat")
        ParseLevel(data)
    End Sub

**See Also** — [Await](#await), [DoEvents](#doevents)

---

## Await

**Purpose** — Pauses execution until an asynchronous operation completes, then returns its result.

**Syntax**

    Await asyncExpression

**Parameters**

- `asyncExpression`

**Description**

Pauses execution until an asynchronous operation completes, then returns its result.

**Example**

    Async Sub FetchData()
        Dim response As String = Await Http.Get("https://api.example.com/data")
        Print response
    End Sub

**See Also** — [Async](#async), [DoEvents](#doevents)

---


### B

## Basis

**Purpose** — Creates a 3x3 rotation/scale matrix used inside Transform3D.

**Syntax**

    Basis() | Basis(quaternion)

**Description**

Creates a 3x3 rotation/scale matrix used inside Transform3D. Pass a Quaternion to build a rotation-only Basis. Methods like .Scaled(v), .Rotated(axis, angle), .Inverse(), .Orthonormalized() are available on the result.

**Example**

    Dim b = Basis(QuaternionFromEuler(0, 0.5, 0))
    Dim b2 = b.Scaled(Vector3(2, 2, 2))

**See Also** — [Quaternion](#quaternion), [QuaternionFromEuler](#quaternionfromeuler), [Transform2D](#transform2d), [Transform3D](#transform3d), [Plane](#plane), [AABB](#aabb), [Slerp](#slerp)

---

## BlitImage

**Purpose** — Copies a rectangular region of pixels from a source Image to a destination Image.

**Syntax**

    BlitImage destImage, srcImage, srcRect, destPos

**Parameters**

- `destImage`
- `srcImage`
- `srcRect`
- `destPos`

**Description**

Copies a rectangular region of pixels from a source Image to a destination Image. srcRect is a Rect2i defining the source region, destPos is a Vector2i for the destination top-left corner.

**Example**

    Dim canvas = CreateImage(640, 480, Color.White)
    Dim stamp = CreateImage(32, 32, Color.Red)

    ' Stamp the red square onto the canvas at (100, 100)
    BlitImage canvas, stamp, Rect2i(0, 0, 32, 32), Vector2i(100, 100)

    ' Copy part of canvas to another location
    BlitImage canvas, canvas, Rect2i(0, 0, 100, 100), Vector2i(200, 200)

**See Also** — [CreateImage](#createimage), [FillImage](#fillimage), [FillImageRect](#fillimagerect), [GetImagePixel](#getimagepixel), [SetImagePixel](#setimagepixel), [ImageWidth](#imagewidth), [ImageHeight](#imageheight)

---

## Bone.Find

**Purpose** — Looks up a bone by name.

**Syntax**

    Bone.Find(skeleton, name) As Long

**Parameters**

- `skeleton`
- `name`

**Description**

Looks up a bone by name. Returns -1 if not found.

**Example**

    Dim head = Bone.Find(skel, "head")

**See Also** — [Skeleton.Count](#skeletoncount), [Skeleton.Name](#skeletonname), [Skeleton.Reset](#skeletonreset), [Bone.Pos](#bonepos), [Bone.Rot](#bonerot), [Bone.Scale](#bonescale), [Bone.SetPos](#bonesetpos), [Bone.SetRot](#bonesetrot), [Bone.SetScale](#bonesetscale), [Bone.LookAt](#bonelookat)

---

## Bone.LookAt

**Purpose** — Rotates the bone so its +Y axis points at targetPos (world space).

**Syntax**

    Bone.LookAt(skeleton, idx, targetPos)

**Parameters**

- `skeleton`
- `idx`
- `targetPos`

**Description**

Rotates the bone so its +Y axis points at targetPos (world space). Simple IK for heads/eyes.

**Example**

    Bone.LookAt skel, headIdx, player.GlobalPosition

**See Also** — [Skeleton.Count](#skeletoncount), [Skeleton.Name](#skeletonname), [Skeleton.Reset](#skeletonreset), [Bone.Find](#bonefind), [Bone.Pos](#bonepos), [Bone.Rot](#bonerot), [Bone.Scale](#bonescale), [Bone.SetPos](#bonesetpos), [Bone.SetRot](#bonesetrot), [Bone.SetScale](#bonesetscale)

---

## Bone.Pos

**Purpose** — Returns the bone's current pose position (relative to its rest).

**Syntax**

    Bone.Pos(skeleton, idx) As Vector3

**Parameters**

- `skeleton`
- `idx`

**Description**

Returns the bone's current pose position (relative to its rest).

**Example**

    Print Bone.Pos(skel, head)

**See Also** — [Skeleton.Count](#skeletoncount), [Skeleton.Name](#skeletonname), [Skeleton.Reset](#skeletonreset), [Bone.Find](#bonefind), [Bone.Rot](#bonerot), [Bone.Scale](#bonescale), [Bone.SetPos](#bonesetpos), [Bone.SetRot](#bonesetrot), [Bone.SetScale](#bonesetscale), [Bone.LookAt](#bonelookat)

---

## Bone.Rot

**Purpose** — Returns the bone's current pose rotation.

**Syntax**

    Bone.Rot(skeleton, idx) As Quaternion

**Parameters**

- `skeleton`
- `idx`

**Description**

Returns the bone's current pose rotation.

**Example**

    Dim q = Bone.Rot(skel, head)

**See Also** — [Skeleton.Count](#skeletoncount), [Skeleton.Name](#skeletonname), [Skeleton.Reset](#skeletonreset), [Bone.Find](#bonefind), [Bone.Pos](#bonepos), [Bone.Scale](#bonescale), [Bone.SetPos](#bonesetpos), [Bone.SetRot](#bonesetrot), [Bone.SetScale](#bonesetscale), [Bone.LookAt](#bonelookat)

---

## Bone.Scale

**Purpose** — Returns the bone's current pose scale.

**Syntax**

    Bone.Scale(skeleton, idx) As Vector3

**Parameters**

- `skeleton`
- `idx`

**Description**

Returns the bone's current pose scale.

**Example**

    Print Bone.Scale(skel, head)

**See Also** — [Skeleton.Count](#skeletoncount), [Skeleton.Name](#skeletonname), [Skeleton.Reset](#skeletonreset), [Bone.Find](#bonefind), [Bone.Pos](#bonepos), [Bone.Rot](#bonerot), [Bone.SetPos](#bonesetpos), [Bone.SetRot](#bonesetrot), [Bone.SetScale](#bonesetscale), [Bone.LookAt](#bonelookat)

---

## Bone.SetPos

**Purpose** — Sets the bone's pose position.

**Syntax**

    Bone.SetPos(skeleton, idx, pos)

**Parameters**

- `skeleton`
- `idx`
- `pos`

**Description**

Sets the bone's pose position.

**Example**

    Bone.SetPos skel, head, Vector3(0, 0.1, 0)

**See Also** — [Skeleton.Count](#skeletoncount), [Skeleton.Name](#skeletonname), [Skeleton.Reset](#skeletonreset), [Bone.Find](#bonefind), [Bone.Pos](#bonepos), [Bone.Rot](#bonerot), [Bone.Scale](#bonescale), [Bone.SetRot](#bonesetrot), [Bone.SetScale](#bonesetscale), [Bone.LookAt](#bonelookat)

---

## Bone.SetRot

**Purpose** — Sets the bone's pose rotation.

**Syntax**

    Bone.SetRot(skeleton, idx, quat)

**Parameters**

- `skeleton`
- `idx`
- `quat`

**Description**

Sets the bone's pose rotation. Use Quaternion(axis, angle) to build one.

**Example**

    Bone.SetRot skel, head, Quaternion(Vector3(0,1,0), Deg2Rad(45))

**See Also** — [Skeleton.Count](#skeletoncount), [Skeleton.Name](#skeletonname), [Skeleton.Reset](#skeletonreset), [Bone.Find](#bonefind), [Bone.Pos](#bonepos), [Bone.Rot](#bonerot), [Bone.Scale](#bonescale), [Bone.SetPos](#bonesetpos), [Bone.SetScale](#bonesetscale), [Bone.LookAt](#bonelookat)

---

## Bone.SetScale

**Purpose** — Sets the bone's pose scale.

**Syntax**

    Bone.SetScale(skeleton, idx, vec)

**Parameters**

- `skeleton`
- `idx`
- `vec`

**Description**

Sets the bone's pose scale.

**Example**

    Bone.SetScale skel, head, Vector3(1.2, 1.2, 1.2)

**See Also** — [Skeleton.Count](#skeletoncount), [Skeleton.Name](#skeletonname), [Skeleton.Reset](#skeletonreset), [Bone.Find](#bonefind), [Bone.Pos](#bonepos), [Bone.Rot](#bonerot), [Bone.Scale](#bonescale), [Bone.SetPos](#bonesetpos), [Bone.SetRot](#bonesetrot), [Bone.LookAt](#bonelookat)

---

## Boolean

**Purpose** — A True/False value.

**Syntax**

    Dim varName As Boolean

**Parameters**

- `varName`

**Description**

A True/False value. Used for flags, conditions, and toggles.

**Example**

    Dim gameOver As Boolean = False
    Dim isVisible As Boolean = True
    If gameOver Then EndGame()

**See Also** — [Integer](#integer), [Long](#long), [Single](#single), [Double](#double), [String](#string), [Variant](#variant), [Array](#array)

---

## ByRef

**Purpose** — Passes an argument by reference — the procedure can modify the caller's original variable.

**Syntax**

    Sub ProcName(ByRef paramName As DataType)

**Parameters**

- `ByRef paramName`

**Description**

Passes an argument by reference — the procedure can modify the caller's original variable. This is the default if neither ByVal nor ByRef is specified.

**Example**

    Sub SwapValues(ByRef a As Integer, ByRef b As Integer)
        Dim temp As Integer = a
        a = b
        b = temp
    End Sub

**See Also** — [Sub](#sub), [Function](#function), [End Sub](#end-sub), [End Function](#end-function), [Call](#call), [Return](#return), [ByVal](#byval), [Optional](#optional), [Lambda](#lambda)

---

## ByVal

**Purpose** — Passes an argument by value — the procedure gets a copy, so changes don't affect the caller's variable.

**Syntax**

    Sub ProcName(ByVal paramName As DataType)

**Parameters**

- `ByVal paramName`

**Description**

Passes an argument by value — the procedure gets a copy, so changes don't affect the caller's variable.

**Example**

    Sub DoubleIt(ByVal x As Integer)
        x = x * 2  ' Only changes local copy
        Print x
    End Sub

**See Also** — [Sub](#sub), [Function](#function), [End Sub](#end-sub), [End Function](#end-function), [Call](#call), [Return](#return), [ByRef](#byref), [Optional](#optional), [Lambda](#lambda)

---


### C

## Call

**Purpose** — Explicitly calls a Sub or Function.

**Syntax**

    Call procedureName([arguments])
    procedureName [arguments]

**Description**

Explicitly calls a Sub or Function. The Call keyword is optional — you can call procedures by name alone.

**Example**

    Call UpdateScore(10)
    UpdateScore 10       ' Same thing without Call
    Call Form2.Show()

**See Also** — [Sub](#sub), [Function](#function), [End Sub](#end-sub), [End Function](#end-function), [Return](#return), [ByRef](#byref), [ByVal](#byval), [Optional](#optional), [Lambda](#lambda)

---

## Camera.Bounce

**Purpose** — One-shot recoil pulse — pushes the camera in `direction` by `strength` and snaps back.

**Syntax**

    Camera.Bounce(direction, strength [, h])

**Parameters**

- `direction`
- `strength`
- `h`

**Description**

One-shot recoil pulse — pushes the camera in `direction` by `strength` and snaps back. Good for explosions, weapon kick, or hit-stop reactions.

**Example**

    ' Shotgun recoil
    Camera.Bounce Vector2(-1, 0), 18

**See Also** — [Camera.Position](#cameraposition), [Camera.Zoom](#camerazoom), [Camera.Rotation](#camerarotation), [Camera.FOV](#camerafov), [Camera.Follow](#camerafollow), [Camera.Shake](#camerashake), [Camera.Limits](#cameralimits), [Camera.MakeCurrent](#cameramakecurrent), [Camera.PanTo](#camerapanto), [Camera.FlashColor](#cameraflashcolor)

---

## Camera.FlashColor

**Purpose** — Briefly fills the viewport with `color`, then fades it out over `duration`.

**Syntax**

    Camera.FlashColor(color, duration [, h])

**Parameters**

- `color`
- `duration`
- `h`

**Description**

Briefly fills the viewport with `color`, then fades it out over `duration`. Use for hit flashes, lightning, screen blanks.

**Example**

    ' Damage flash
    Camera.FlashColor RGB(255, 0, 0), 0.15

**See Also** — [Camera.Position](#cameraposition), [Camera.Zoom](#camerazoom), [Camera.Rotation](#camerarotation), [Camera.FOV](#camerafov), [Camera.Follow](#camerafollow), [Camera.Shake](#camerashake), [Camera.Limits](#cameralimits), [Camera.MakeCurrent](#cameramakecurrent), [Camera.PanTo](#camerapanto), [Camera.Bounce](#camerabounce)

---

## Camera.Follow

**Purpose** — Continuously follow a target node.

**Syntax**

    Camera.Follow(target [, h])

**Parameters**

- `target`
- `h`

**Description**

Continuously follow a target node. Internally adds a RemoteTransform that mirrors target.Position to the camera every frame — zero per-frame code on your side. Pass Nothing to stop following. Camera.Position(...) called inside Sub _Process() takes precedence for the frame it runs.

**Example**

    Sub _Ready()
        Camera.Follow player    ' auto-track player forever
    End Sub

    Sub OnPlayerDied()
        Camera.Follow Nothing   ' stop following
    End Sub

**See Also** — [Camera.Position](#cameraposition), [Camera.Zoom](#camerazoom), [Camera.Rotation](#camerarotation), [Camera.FOV](#camerafov), [Camera.Shake](#camerashake), [Camera.Limits](#cameralimits), [Camera.MakeCurrent](#cameramakecurrent), [Camera.PanTo](#camerapanto), [Camera.Bounce](#camerabounce), [Camera.FlashColor](#cameraflashcolor)

---

## Camera.FOV

**Purpose** — Sets Camera3D field of view in degrees.

**Syntax**

    Camera.FOV(degrees [, h])

**Parameters**

- `degrees`
- `h`

**Description**

Sets Camera3D field of view in degrees. 75 is the default. Smaller = telephoto/zoomed; larger = wide-angle.

**Example**

    Camera.FOV 90    ' wide cinematic
    Camera.FOV 45    ' sniper scope

**See Also** — [Camera.Position](#cameraposition), [Camera.Zoom](#camerazoom), [Camera.Rotation](#camerarotation), [Camera.Follow](#camerafollow), [Camera.Shake](#camerashake), [Camera.Limits](#cameralimits), [Camera.MakeCurrent](#cameramakecurrent), [Camera.PanTo](#camerapanto), [Camera.Bounce](#camerabounce), [Camera.FlashColor](#cameraflashcolor)

---

## Camera.Limits

**Purpose** — Sets Camera2D pan limits in pixels.

**Syntax**

    Camera.Limits(left, top, right, bottom [, h])

**Parameters**

- `left`
- `top`
- `right`
- `bottom`
- `h`

**Description**

Sets Camera2D pan limits in pixels. The camera will refuse to scroll past these edges — perfect for keeping the view inside your level.

**Example**

    ' Lock view to a 1920x1080 level
    Camera.Limits 0, 0, 1920, 1080

**See Also** — [Camera.Position](#cameraposition), [Camera.Zoom](#camerazoom), [Camera.Rotation](#camerarotation), [Camera.FOV](#camerafov), [Camera.Follow](#camerafollow), [Camera.Shake](#camerashake), [Camera.MakeCurrent](#cameramakecurrent), [Camera.PanTo](#camerapanto), [Camera.Bounce](#camerabounce), [Camera.FlashColor](#cameraflashcolor)

---

## Camera.MakeCurrent

**Purpose** — Makes a camera the active one — useful when you have multiple cameras (e.g., gameplay vs cutscene) and want to switch which one renders.

**Syntax**

    Camera.MakeCurrent([h])

**Parameters**

- `h`

**Description**

Makes a camera the active one — useful when you have multiple cameras (e.g., gameplay vs cutscene) and want to switch which one renders.

**Example**

    Camera.MakeCurrent cutsceneCam
    ' ... play cutscene ...
    Camera.MakeCurrent gameplayCam

**See Also** — [Camera.Position](#cameraposition), [Camera.Zoom](#camerazoom), [Camera.Rotation](#camerarotation), [Camera.FOV](#camerafov), [Camera.Follow](#camerafollow), [Camera.Shake](#camerashake), [Camera.Limits](#cameralimits), [Camera.PanTo](#camerapanto), [Camera.Bounce](#camerabounce), [Camera.FlashColor](#cameraflashcolor)

---

## Camera.PanTo

**Purpose** — Tween-pans the active camera to pos over duration seconds.

**Syntax**

    Camera.PanTo(pos, duration [, h])

**Parameters**

- `pos`
- `duration`
- `h`

**Description**

Tween-pans the active camera to pos over duration seconds. Smoother than setting Camera.Position directly. Works for Camera2D (Vector2) or Camera3D (Vector3).

**Example**

    ' Cinematic reveal
    Camera.PanTo Vector2(800, 400), 1.5

**See Also** — [Camera.Position](#cameraposition), [Camera.Zoom](#camerazoom), [Camera.Rotation](#camerarotation), [Camera.FOV](#camerafov), [Camera.Follow](#camerafollow), [Camera.Shake](#camerashake), [Camera.Limits](#cameralimits), [Camera.MakeCurrent](#cameramakecurrent), [Camera.Bounce](#camerabounce), [Camera.FlashColor](#cameraflashcolor)

---

## Camera.Position

**Purpose** — Sets the active camera's position.

**Syntax**

    Camera.Position(pos [, h])

**Parameters**

- `pos`
- `h`

**Description**

Sets the active camera's position. Use Vector2 for Camera2D, Vector3 for Camera3D. Optional h overrides which camera is targeted.

Called inside Sub _Process() it tracks any target — Camera.Position(player.Position) for instant follow.

**Example**

    ' Snap to player every frame
    Sub _Process(delta)
        Camera.Position(player.Position)
    End Sub

**See Also** — [Camera.Zoom](#camerazoom), [Camera.Rotation](#camerarotation), [Camera.FOV](#camerafov), [Camera.Follow](#camerafollow), [Camera.Shake](#camerashake), [Camera.Limits](#cameralimits), [Camera.MakeCurrent](#cameramakecurrent), [Camera.PanTo](#camerapanto), [Camera.Bounce](#camerabounce), [Camera.FlashColor](#cameraflashcolor)

---

## Camera.Rotation

**Purpose** — Rotates the camera.

**Syntax**

    Camera.Rotation(angle [, h])

**Parameters**

- `angle`
- `h`

**Description**

Rotates the camera. For Camera2D pass a number in radians; for Camera3D pass a Vector3 of Euler angles in radians.

**Example**

    ' Quick screen tilt (Camera2D)
    Camera.Rotation 0.1   ' ~6 degrees

**See Also** — [Camera.Position](#cameraposition), [Camera.Zoom](#camerazoom), [Camera.FOV](#camerafov), [Camera.Follow](#camerafollow), [Camera.Shake](#camerashake), [Camera.Limits](#cameralimits), [Camera.MakeCurrent](#cameramakecurrent), [Camera.PanTo](#camerapanto), [Camera.Bounce](#camerabounce), [Camera.FlashColor](#cameraflashcolor)

---

## Camera.Shake

**Purpose** — Quick screen shake.

**Syntax**

    Camera.Shake(intensity, duration [, h])

**Parameters**

- `intensity`
- `duration`
- `h`

**Description**

Quick screen shake. Intensity is offset in pixels (2D) or units (3D). Duration is seconds. Camera settles back to its original offset when done.

**Example**

    ' Boom!
    Camera.Shake 12, 0.4

**See Also** — [Camera.Position](#cameraposition), [Camera.Zoom](#camerazoom), [Camera.Rotation](#camerarotation), [Camera.FOV](#camerafov), [Camera.Follow](#camerafollow), [Camera.Limits](#cameralimits), [Camera.MakeCurrent](#cameramakecurrent), [Camera.PanTo](#camerapanto), [Camera.Bounce](#camerabounce), [Camera.FlashColor](#cameraflashcolor)

---

## Camera.Zoom

**Purpose** — Sets Camera2D zoom level.

**Syntax**

    Camera.Zoom(zoom [, h])

**Parameters**

- `zoom`
- `h`

**Description**

Sets Camera2D zoom level. Pass a Vector2 for non-uniform zoom, or a scalar for uniform. Bigger numbers = closer in. (Camera3D uses FOV instead — see Camera.FOV.)

**Example**

    Camera.Zoom Vector2(2, 2)       ' 2x zoom in
    Camera.Zoom 0.5                  ' zoom out to half

**See Also** — [Camera.Position](#cameraposition), [Camera.Rotation](#camerarotation), [Camera.FOV](#camerafov), [Camera.Follow](#camerafollow), [Camera.Shake](#camerashake), [Camera.Limits](#cameralimits), [Camera.MakeCurrent](#cameramakecurrent), [Camera.PanTo](#camerapanto), [Camera.Bounce](#camerabounce), [Camera.FlashColor](#cameraflashcolor)

---

## Case

**Purpose** — Specifies a value or range to match in a Select Case block.

**Syntax**

    Case value [, value2] [To value3]

**Parameters**

- `value`
- `value2 To value3`

**Description**

Specifies a value or range to match in a Select Case block. Supports comma lists, ranges with To, and comparisons with Is.

**Example**

    Case 1, 2, 3     ' Match any of these
    Case 10 To 20    ' Match range
    Case Is > 100    ' Match comparison
    Case Else        ' Default case

**See Also** — [Select](#select), [Select Case](#select-case), [End Select](#end-select)

---

## Catch

**Purpose** — Catches an exception thrown in the Try block.

**Syntax**

    Catch [variableName As Exception]

**Parameters**

- `variableName`

**Description**

Catches an exception thrown in the Try block. The exception object provides Description and Number properties.

**Example**

    Try
        riskyOperation()
    Catch ex As Exception
        Print "Error #" & ex.Number & ": " & ex.Description
    End Try

**See Also** — [On Error](#on-error), [Try](#try), [Finally](#finally), [Throw](#throw)

---

## Cell.Clear

**Purpose** — Erases a single tile.

**Syntax**

    Cell.Clear(layer, x, y)

**Parameters**

- `layer`
- `x`
- `y`

**Description**

Erases a single tile. Shortcut for Cell.Set with source = -1.

**Example**

    Cell.Clear world, 5, 10

**See Also** — [Cell.Get](#cellget), [Cell.Set](#cellset), [Cell.ClearAll](#cellclearall), [Cell.Used](#cellused)

---

## Cell.ClearAll

**Purpose** — Erases all tiles in a TileMapLayer.

**Syntax**

    Cell.ClearAll(layer)

**Parameters**

- `layer`

**Description**

Erases all tiles in a TileMapLayer.

**Example**

    Cell.ClearAll world

**See Also** — [Cell.Get](#cellget), [Cell.Set](#cellset), [Cell.Clear](#cellclear), [Cell.Used](#cellused)

---

## Cell.Get

**Purpose** — Reads a tile at cell coords (x, y) on a TileMapLayer.

**Syntax**

    Cell.Get(layer, x, y) As Dictionary

**Parameters**

- `layer`
- `x`
- `y`

**Description**

Reads a tile at cell coords (x, y) on a TileMapLayer. Returns Dictionary: Source, AtlasX, AtlasY, Alt. Empty cells return Source = -1.

**Example**

    Dim c = Cell.Get(world, 5, 10)
    If c.Source >= 0 Then
        Print "Tile from source " & c.Source
    End If

**See Also** — [Cell.Set](#cellset), [Cell.Clear](#cellclear), [Cell.ClearAll](#cellclearall), [Cell.Used](#cellused)

---

## Cell.Set

**Purpose** — Writes a tile at cell coords (x, y).

**Syntax**

    Cell.Set(layer, x, y, source, atlasX, atlasY [, alt])

**Parameters**

- `layer`
- `x`
- `y`
- `source`
- `atlasX`
- `atlasY`
- `alt`

**Description**

Writes a tile at cell coords (x, y). source = -1 erases. atlasX/Y picks the tile within the source's atlas.

**Example**

    ' Place a grass tile from source 0, atlas (3, 1)
    Cell.Set world, 5, 10, 0, 3, 1

**See Also** — [Cell.Get](#cellget), [Cell.Clear](#cellclear), [Cell.ClearAll](#cellclearall), [Cell.Used](#cellused)

---

## Cell.Used

**Purpose** — Returns an Array of Vector2 cell coordinates that contain a tile (non-empty).

**Syntax**

    Cell.Used(layer) As Array

**Parameters**

- `layer`

**Description**

Returns an Array of Vector2 cell coordinates that contain a tile (non-empty).

**Example**

    Dim cells = Cell.Used(world)
    For Each c In cells
        Print c.x & "," & c.y
    Next

**See Also** — [Cell.Get](#cellget), [Cell.Set](#cellset), [Cell.Clear](#cellclear), [Cell.ClearAll](#cellclearall)

---

## ChangeScene

**Purpose** — Changes the current game scene to the specified .tscn file.

**Syntax**

    ChangeScene(scenePath)

**Parameters**

- `scenePath`

**Description**

Changes the current game scene to the specified .tscn file.

**Example**

    ChangeScene "res://levels/Level2.tscn"

    ' Or using GetTree:
    GetTree().change_scene_to_file("res://MainMenu.tscn")

**See Also** — [IsActionPressed](#isactionpressed), [IsKeyPressed](#iskeypressed), [PlaySound](#playsound), [CreateActor2D](#createactor2d)

---

## CBool

**Purpose** — Converts an expression to a Boolean value.

**Syntax**

    CBool(expression)

**Parameters**

- `expression` — Number, string, or other value to convert.

**Description**

Converts an expression to `True` or `False`. Zero (`0`), empty strings, and the string `"false"` (case-insensitive) convert to `False`. Non-zero numbers and non-empty strings convert to `True`.

**Example**

    Print CBool(0)       ' False
    Print CBool(1)       ' True
    Print CBool(-1)      ' True
    Print CBool("")      ' False
    Print CBool("Yes")   ' True

**See Also** — [CInt](#cint), [CStr](#cstr), [Val](#val)

---

## CDate

**Purpose** — Converts an expression to a date/time serial value (Unix timestamp).

**Syntax**

    CDate(expression)

**Parameters**

- `expression` — Date string (for example `"2026-08-23"`), numeric timestamp, or other coercible value.

**Description**

Converts a date or time expression to a numeric serial value. VG stores the result as a **Unix timestamp** (seconds since 1970-01-01 UTC). ISO-style date strings such as `"YYYY-MM-DD"` are parsed when possible; invalid strings fall back to the current system time. Numeric inputs are treated as existing timestamps.

**Example**

    Dim when As Double
    when = CDate("2026-08-23")
    Print when

**See Also** — [CInt](#cint), [CDbl](#cdbl), [DateValue](#datevalue), [DatePart](#datepart)

---

## CDbl

**Purpose** — Converts an expression to a Double-precision floating-point number.

**Syntax**

    CDbl(expression)

**Parameters**

- `expression` — Number, numeric string, or Boolean to convert.

**Description**

Converts an expression to a `Double`. String input must be a valid integer or decimal; invalid strings raise a catchable type mismatch error. Boolean `True` becomes `1.0`, `False` becomes `0.0`.

**Example**

    Dim d As Double = CDbl("3.14")  ' 3.14
    Dim x As Double = CDbl(42)       ' 42.0
    Dim t As Double = CDbl(True)     ' 1.0

**See Also** — [CSng](#csng), [CInt](#cint), [CLng](#clng), [CStr](#cstr), [Val](#val)

---

## CInt

**Purpose** — Converts an expression to an Integer, rounding if necessary.

**Syntax**

    CInt(expression)

**Parameters**

- `expression`

**Description**

Converts an expression to an Integer, rounding if necessary.

**Example**

    Dim n As Integer = CInt(3.7)   ' 4
    Dim m As Integer = CInt("42")  ' 42

**See Also** — [CLng](#clng), [CDbl](#cdbl), [CSng](#csng), [CStr](#cstr), [CBool](#cbool), [Val](#val), [Str](#str), [Int](#int), [Fix](#fix), [Round](#round)

---

## CLng

**Purpose** — Converts an expression to a Long integer.

**Syntax**

    CLng(expression)

**Parameters**

- `expression` — Number or numeric string to convert.

**Description**

Converts an expression to a Long integer (`Long` / 64-bit). Like `CInt`, fractional values are rounded. String input must parse as a number; invalid strings raise a catchable type mismatch error. `CLngLng` is an alias with the same behavior.

**Example**

    Dim n As Long = CLng(3.7)          ' 4
    Dim big As Long = CLng("123456")   ' 123456
    Dim m As Long = CLng(99.5)         ' 100

**See Also** — [CInt](#cint), [CDbl](#cdbl), [CSng](#csng), [CStr](#cstr), [Int](#int), [Fix](#fix)

---

## CSng

**Purpose** — Converts an expression to a Single-precision floating-point number.

**Syntax**

    CSng(expression)

**Parameters**

- `expression` — Number, numeric string, or Boolean to convert.

**Description**

Converts an expression to a `Single`. Less precise than `Double` but useful when memory or performance matters. String input must be a valid number; invalid strings raise a catchable type mismatch error.

**Example**

    Dim s As Single = CSng("3.14")   ' 3.14
    Dim t As Single = CSng(42)        ' 42.0
    Dim d As Double = 3.14159265358979
    Dim r As Single = CSng(d)         ' reduced precision

**See Also** — [CDbl](#cdbl), [CInt](#cint), [CLng](#clng), [CStr](#cstr), [Val](#val)

---

## Fix

**Purpose** — Truncates a number toward zero to its integer portion.

**Syntax**

    Fix(number)

**Parameters**

- `number` — Numeric expression.

**Description**

Returns the integer part of a number, truncating toward zero. Unlike `Int`, which rounds toward negative infinity, `Fix(-2.9)` returns `-2` (not `-3`).

**Example**

    Print Fix(3.7)   ' 3
    Print Fix(-2.9)  ' -2
    Print Int(-2.9)  ' -3

**See Also** — [Int](#int), [CInt](#cint), [Round](#round)

---

## Hex

**Purpose** — Returns the uppercase hexadecimal string for a number (no `&H` prefix).

**Syntax**

    Hex(number)

**Parameters**

- `number` — Integer expression.

**Description**

Converts an integer to a hex string using uppercase `A`–`F` digits. Useful alongside VB6 `&H…` literals in the Convert sidecar.

**Example**

    Print Hex(255)   ' FF
    Print Hex(16)    ' 10

**See Also** — [Oct](#oct), [Val](#val), [CInt](#cint)

---

## IsNumeric

**Purpose** — Tests whether an expression can be evaluated as a number.

**Syntax**

    IsNumeric(expression)

**Parameters**

- `expression` — Value to test.

**Description**

Returns `True` when the expression is numeric or a string that parses as a number. Use before `Val`, `CInt`, or `CDbl` on user input.

**Example**

    If IsNumeric(userInput) Then
        score = Val(userInput)
    End If

**See Also** — [Val](#val), [CInt](#cint), [CDbl](#cdbl), [CStr](#cstr)

---

## Oct

**Purpose** — Returns the octal string for a number.

**Syntax**

    Oct(number)

**Parameters**

- `number` — Integer expression.

**Description**

Converts an integer to base-8 text without an `&O` prefix.

**Example**

    Print Oct(8)     ' 10
    Print Oct(64)    ' 100

**See Also** — [Hex](#hex), [Val](#val)

---

## Clamp

**Purpose** — Constrains a value to the range [min, max].

**Syntax**

    Clamp(value, min, max)

**Parameters**

- `value`
- `min`
- `max`

**Description**

Constrains a value to the range [min, max].

**Example**

    health = Clamp(health, 0, maxHealth)
    speed = Clamp(speed, 0.0, maxSpeed)

**See Also** — [Abs](#abs), [Int](#int), [Sqr](#sqr), [Rnd](#rnd), [Randomize](#randomize), [RandRange](#randrange), [Round](#round), [Lerp](#lerp), [Mod](#mod)

---

## Class

**Purpose** — Declares a new class type.

**Syntax**

    Class ClassName
        [Inherits BaseClass]
        ' fields, methods, properties
    End Class

**Description**

Declares a new class type. Classes support inheritance, interfaces, properties, and methods.

**Example**

    Class Player
        Public Name As String
        Public Health As Integer = 100

        Sub TakeDamage(amount As Integer)
            Health = Health - amount
            If Health <= 0 Then Die()
        End Sub
    End Class

**See Also** — [End Class](#end-class), [New](#new), [Set](#set), [Me](#me), [Implements](#implements), [Inherits](#inherits), [Interface](#interface), [Property](#property)

---

## Close

**Purpose** — Closes one or more open files.

**Syntax**

    Close [#fileNumber [, #fileNumber ...]]

**Parameters**

- `#fileNumber`
- `#fileNumber ...`

**Description**

Closes one or more open files. Always close files when done to flush data to disk.

**Example**

    Open "data.txt" For Input As #1
    ' ... read data ...
    Close #1

    Close  ' Close all open files

**See Also** — [Open](#open), [Line Input](#line-input), [Data](#data), [Read](#read), [Restore](#restore)

---

## CLS

**Purpose** — Clears the screen/canvas.

**Syntax**

    CLS
    CLS()

**Description**

Clears the screen/canvas. Removes all dynamically created child nodes and triggers a redraw. VB6 classic command.

**Example**

    CLS  ' Clear everything

    ' Typical usage: clear before redrawing
    Sub _Draw()
        ' CLS is implicit in _Draw — each frame starts clean
        DrawRect 0, 0, 640, 480, Color.Black   ' Background
        DrawString GetThemeDefaultFont(), Vector2(10, 20), "Game Over", Color.White
    End Sub

**See Also** — [DrawLine](#drawline), [DrawRect](#drawrect), [DrawCircle](#drawcircle), [DrawArc](#drawarc), [DrawPixel](#drawpixel), [DrawPolygon](#drawpolygon), [DrawPolyline](#drawpolyline), [PSet](#pset), [QueueRedraw](#queueredraw)

---

## ColorFromHSV

**Purpose** — Builds a Color from Hue/Saturation/Value (each 0..1).

**Syntax**

    ColorFromHSV(h, s, v [, a])

**Parameters**

- `h`
- `s`
- `v`
- `a`

**Description**

Builds a Color from Hue/Saturation/Value (each 0..1). Use when you want rainbow effects, palette cycling, or to tint by hue without RGB math.

**Example**

    ' Animate the rainbow
    For i = 0 To 60
        Dim c = ColorFromHSV(i / 60.0, 0.8, 1.0)
        DrawRect i * 10, 0, 10, 100, c
    Next

**See Also** — [ColorToHSV](#colortohsv), [Lighten](#lighten), [Darken](#darken), [RGB](#rgb)

---

## ColorToHSV

**Purpose** — Splits a Color into its Hue, Saturation, Value, Alpha components.

**Syntax**

    ColorToHSV(color)

**Parameters**

- `color`

**Description**

Splits a Color into its Hue, Saturation, Value, Alpha components. Returns a Dictionary with keys h, s, v, a (each 0..1).

**Example**

    Dim parts = ColorToHSV(Color.Red)
    Print parts.h  ' 0.0  (red is hue 0)
    Print parts.s  ' 1.0

**See Also** — [ColorFromHSV](#colorfromhsv), [Lighten](#lighten), [Darken](#darken), [RGB](#rgb)

---

## connect

**Purpose** — Connects a signal to a callback method.

**Syntax**

    connect(signal_name As String, callable As Callable)

**Parameters**

- `signal_name`
- `callable`

**Description**

Connects a signal to a callback method. Use Godot 4 Callable syntax.

**Example**

    connect("body_entered", _on_body_entered)
    timer.connect("timeout", _on_timeout)

**Godot Mapping** — [`Object.connect()`](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-connect)

**See Also** — [emit_signal](#emit_signal)

---

## Const

**Purpose** — Declares a named constant whose value cannot be changed after initialization.

**Syntax**

    Const CONSTANT_NAME As DataType = value

**Parameters**

- `CONSTANT_NAME`

**Description**

Declares a named constant whose value cannot be changed after initialization.

**Example**

    Const MAX_PLAYERS As Integer = 4
    Const PI As Double = 3.14159
    Const GAME_TITLE As String = "My Game"

**See Also** — [Dim](#dim), [Private](#private), [Public](#public), [Global](#global), [Static](#static), [ReDim](#redim), [Type](#type)

---

## Continue

**Purpose** — Skips the rest of the current loop iteration and continues with the next iteration.

**Syntax**

    Continue For | Continue Do | Continue While

**Parameters**

- `For | Continue Do | Continue While`

**Description**

Skips the rest of the current loop iteration and continues with the next iteration.

**Example**

    For i = 0 To 99
        If scores(i) < 0 Then Continue For
        total = total + scores(i)
    Next

**See Also** — [For](#for), [Next](#next), [For Each](#for-each), [Exit](#exit)

---

## Cos

**Purpose** — Returns the cosine of an angle (in radians).

**Syntax**

    Cos(angle)

**Parameters**

- `angle`

**Description**

Returns the cosine of an angle (in radians).

**Example**

    Dim x As Single = Cos(0)  ' 1.0
    ' Circular motion
    x = Cos(angle) * radius

**See Also** — [Sin](#sin)

---

## CreateActor2D

**Purpose** — Creates a 2D game actor (sprite) at the specified position.

**Syntax**

    CreateActor2D(name, x, y [, texturePath])

**Parameters**

- `name`
- `x`
- `y`
- `texturePath`

**Description**

Creates a 2D game actor (sprite) at the specified position.

**Example**

    CreateActor2D "Player", 100, 200, "res://player.png"
    CreateActor2D "Enemy", 400, 200

**See Also** — [IsActionPressed](#isactionpressed), [IsKeyPressed](#iskeypressed), [PlaySound](#playsound), [ChangeScene](#changescene)

---

## CreateImage

**Purpose** — Creates a new RGBA8 Image object with the specified dimensions (1-4096 pixels).

**Syntax**

    CreateImage(width, height [, fillColor]) As Image

**Parameters**

- `width`
- `height`
- `fillColor`

**Description**

Creates a new RGBA8 Image object with the specified dimensions (1-4096 pixels). The optional fillColor sets all pixels to that color (default is transparent black). Images are in-memory pixel buffers — use SetImagePixel to draw on them, then CreateTexture or UpdateTexture to display them.

**Example**

    ' Create a white 640x480 canvas
    Dim img As Variant = CreateImage(640, 480, Color(1, 1, 1, 1))

    ' Create a transparent 256x256 sprite sheet
    Dim sheet As Variant = CreateImage(256, 256)

    ' Draw on it
    SetImagePixel img, 100, 100, Color.Red
    SetImagePixel img, 101, 100, Color.Red

    ' Display it
    Dim tex As Variant = CreateTexture(img)
    DrawTexture tex, 0, 0

**See Also** — [FillImage](#fillimage), [FillImageRect](#fillimagerect), [GetImagePixel](#getimagepixel), [SetImagePixel](#setimagepixel), [BlitImage](#blitimage), [ImageWidth](#imagewidth), [ImageHeight](#imageheight)

---

## CreateTexture

**Purpose** — Creates an ImageTexture for display with DrawTexture.

**Syntax**

    CreateTexture(image) As ImageTexture
    CreateTexture(width, height [, fillColor]) As ImageTexture

**Description**

Creates an ImageTexture for display with DrawTexture. Can accept an existing Image, or width/height to create both an Image and Texture in one call. ImageTextures live on the GPU and are fast to render.

**Example**

    ' From an existing Image
    Dim img = CreateImage(320, 240, Color.White)
    Dim tex = CreateTexture(img)

    ' Quick one-liner: create texture directly
    Dim tex2 = CreateTexture(64, 64, Color.Blue)

    ' Display in _Draw()
    Sub _Draw()
        DrawTexture tex, 0, 0
    End Sub

**See Also** — [ImageToTexture](#imagetotexture), [UpdateTexture](#updatetexture), [GetTextureImage](#gettextureimage), [TextureWidth](#texturewidth), [TextureHeight](#textureheight)

---

## Crypto.Base64

**Purpose** — Short form of Crypto.Base64Encode — encodes bytes to a standard Base64 string.

**Syntax**

    Crypto.Base64(bytes) As String

**Parameters**

- `bytes`

**Description**

Short form of Crypto.Base64Encode — encodes bytes to a standard Base64 string.

**Example**

    Print Crypto.Base64("hello world")   ' "aGVsbG8gd29ybGQ="

**See Also** — [Crypto.MD5](#cryptomd5), [Crypto.SHA1](#cryptosha1), [Crypto.SHA256](#cryptosha256), [Crypto.HMAC](#cryptohmac), [Crypto.RandomBytes](#cryptorandombytes), [Crypto.Hex](#cryptohex), [Crypto.FromHex](#cryptofromhex), [Crypto.Base64Encode](#cryptobase64encode), [Crypto.Base64Decode](#cryptobase64decode)

---

## Crypto.Base64Decode

**Purpose** — Decodes Base64.

**Syntax**

    Crypto.Base64Decode(b64 [, raw]) As String/Bytes

**Parameters**

- `b64`
- `raw`

**Description**

Decodes Base64. By default returns UTF-8 String. Pass True for raw PackedByteArray. Alias: Base64Decode.

**Example**

    Print Base64Decode("aGVsbG8=")  ' hello
    Dim bin = Base64Decode(encoded, True)

**See Also** — [Crypto.MD5](#cryptomd5), [Crypto.SHA1](#cryptosha1), [Crypto.SHA256](#cryptosha256), [Crypto.HMAC](#cryptohmac), [Crypto.RandomBytes](#cryptorandombytes), [Crypto.Hex](#cryptohex), [Crypto.FromHex](#cryptofromhex), [Crypto.Base64](#cryptobase64), [Crypto.Base64Encode](#cryptobase64encode)

---

## Crypto.Base64Encode

**Purpose** — Encodes input as Base64.

**Syntax**

    Crypto.Base64Encode(text_or_bytes) As String

**Parameters**

- `text_or_bytes`

**Description**

Encodes input as Base64. String → UTF-8 → Base64. PackedByteArray → Base64 directly. Alias: Base64Encode.

**Example**

    Print Base64Encode("hello world")  ' aGVsbG8gd29ybGQ=

**See Also** — [Crypto.MD5](#cryptomd5), [Crypto.SHA1](#cryptosha1), [Crypto.SHA256](#cryptosha256), [Crypto.HMAC](#cryptohmac), [Crypto.RandomBytes](#cryptorandombytes), [Crypto.Hex](#cryptohex), [Crypto.FromHex](#cryptofromhex), [Crypto.Base64](#cryptobase64), [Crypto.Base64Decode](#cryptobase64decode)

---

## Crypto.FromHex

**Purpose** — Parses a hex string back into raw bytes.

**Syntax**

    Crypto.FromHex(hexString) As PackedByteArray

**Parameters**

- `hexString`

**Description**

Parses a hex string back into raw bytes. Whitespace is ignored; case-insensitive.

**Example**

    Dim raw = Crypto.FromHex("deadbeef")

**See Also** — [Crypto.MD5](#cryptomd5), [Crypto.SHA1](#cryptosha1), [Crypto.SHA256](#cryptosha256), [Crypto.HMAC](#cryptohmac), [Crypto.RandomBytes](#cryptorandombytes), [Crypto.Hex](#cryptohex), [Crypto.Base64](#cryptobase64), [Crypto.Base64Encode](#cryptobase64encode), [Crypto.Base64Decode](#cryptobase64decode)

---

## Crypto.Hex

**Purpose** — Converts a PackedByteArray (or hashable input) to a lowercase hex string.

**Syntax**

    Crypto.Hex(bytes) As String

**Parameters**

- `bytes`

**Description**

Converts a PackedByteArray (or hashable input) to a lowercase hex string. Inverse of Crypto.FromHex.

**Example**

    Print Crypto.Hex(Crypto.RandomBytes(8))   ' e.g. "a1b2c3d4e5f60718"

**See Also** — [Crypto.MD5](#cryptomd5), [Crypto.SHA1](#cryptosha1), [Crypto.SHA256](#cryptosha256), [Crypto.HMAC](#cryptohmac), [Crypto.RandomBytes](#cryptorandombytes), [Crypto.FromHex](#cryptofromhex), [Crypto.Base64](#cryptobase64), [Crypto.Base64Encode](#cryptobase64encode), [Crypto.Base64Decode](#cryptobase64decode)

---

## Crypto.HMAC

**Purpose** — Keyed-hash message auth code.

**Syntax**

    Crypto.HMAC(key, msg [, algorithm]) As String

**Parameters**

- `key`
- `msg`
- `algorithm`

**Description**

Keyed-hash message auth code. algorithm = "sha256" (default), "sha1", or "md5".

**Example**

    Dim sig = Crypto.HMAC(secretKey, payload, "sha256")

**See Also** — [Crypto.MD5](#cryptomd5), [Crypto.SHA1](#cryptosha1), [Crypto.SHA256](#cryptosha256), [Crypto.RandomBytes](#cryptorandombytes), [Crypto.Hex](#cryptohex), [Crypto.FromHex](#cryptofromhex), [Crypto.Base64](#cryptobase64), [Crypto.Base64Encode](#cryptobase64encode), [Crypto.Base64Decode](#cryptobase64decode)

---

## Crypto.MD5

**Purpose** — Returns the MD5 hash as lowercase hex.

**Syntax**

    Crypto.MD5(text_or_bytes) As String

**Parameters**

- `text_or_bytes`

**Description**

Returns the MD5 hash as lowercase hex. (MD5 is fast but not secure for passwords — use SHA256.) Alias: MD5.

**Example**

    Print MD5(fileContent)

**See Also** — [Crypto.SHA1](#cryptosha1), [Crypto.SHA256](#cryptosha256), [Crypto.HMAC](#cryptohmac), [Crypto.RandomBytes](#cryptorandombytes), [Crypto.Hex](#cryptohex), [Crypto.FromHex](#cryptofromhex), [Crypto.Base64](#cryptobase64), [Crypto.Base64Encode](#cryptobase64encode), [Crypto.Base64Decode](#cryptobase64decode)

---

## Crypto.RandomBytes

**Purpose** — Returns n cryptographically secure random bytes.

**Syntax**

    Crypto.RandomBytes(n) As PackedByteArray

**Parameters**

- `n`

**Description**

Returns n cryptographically secure random bytes. Alias: RandomBytes.

**Example**

    Dim token = RandomBytes(32)
    Dim hex = Base64Encode(token)

**See Also** — [Crypto.MD5](#cryptomd5), [Crypto.SHA1](#cryptosha1), [Crypto.SHA256](#cryptosha256), [Crypto.HMAC](#cryptohmac), [Crypto.Hex](#cryptohex), [Crypto.FromHex](#cryptofromhex), [Crypto.Base64](#cryptobase64), [Crypto.Base64Encode](#cryptobase64encode), [Crypto.Base64Decode](#cryptobase64decode)

---

## Crypto.SHA1

**Purpose** — Returns the SHA-1 hash as lowercase hex.

**Syntax**

    Crypto.SHA1(text_or_bytes) As String

**Parameters**

- `text_or_bytes`

**Description**

Returns the SHA-1 hash as lowercase hex. Alias: SHA1.

**Example**

    Print SHA1("hello")

**See Also** — [Crypto.MD5](#cryptomd5), [Crypto.SHA256](#cryptosha256), [Crypto.HMAC](#cryptohmac), [Crypto.RandomBytes](#cryptorandombytes), [Crypto.Hex](#cryptohex), [Crypto.FromHex](#cryptofromhex), [Crypto.Base64](#cryptobase64), [Crypto.Base64Encode](#cryptobase64encode), [Crypto.Base64Decode](#cryptobase64decode)

---

## Crypto.SHA256

**Purpose** — Returns the SHA-256 hash as lowercase hex.

**Syntax**

    Crypto.SHA256(text_or_bytes) As String

**Parameters**

- `text_or_bytes`

**Description**

Returns the SHA-256 hash as lowercase hex. Accepts a String (UTF-8) or PackedByteArray. Alias: SHA256.

**Example**

    Dim h = SHA256("password")
    Print h

**See Also** — [Crypto.MD5](#cryptomd5), [Crypto.SHA1](#cryptosha1), [Crypto.HMAC](#cryptohmac), [Crypto.RandomBytes](#cryptorandombytes), [Crypto.Hex](#cryptohex), [Crypto.FromHex](#cryptofromhex), [Crypto.Base64](#cryptobase64), [Crypto.Base64Encode](#cryptobase64encode), [Crypto.Base64Decode](#cryptobase64decode)

---

## CStr

**Purpose** — Explicitly converts any expression to a String.

**Syntax**

    CStr(expression)

**Parameters**

- `expression`

**Description**

Explicitly converts any expression to a String.

**Example**

    Dim s As String = CStr(42)    ' "42"
    Dim t As String = CStr(True)  ' "True"

**See Also** — [CInt](#cint), [CLng](#clng), [CDbl](#cdbl), [CSng](#csng), [CBool](#cbool), [Val](#val), [Str](#str), [Int](#int)

---


### D

## Darken

**Purpose** — Returns a darker shade of the color.

**Syntax**

    Darken(color, amount)

**Parameters**

- `color`
- `amount`

**Description**

Returns a darker shade of the color. Amount is 0..1 (0=unchanged, 1=black).

**Example**

    shadow = Darken(skinColor, 0.4)

**See Also** — [ColorFromHSV](#colorfromhsv), [ColorToHSV](#colortohsv), [Lighten](#lighten), [RGB](#rgb)

---

## Data

**Purpose** — Stores inline data values that can be read sequentially with Read.

**Syntax**

    Data value1, value2, value3, ...
    Data "string", 42, 3.14

**Description**

Stores inline data values that can be read sequentially with Read. Supports strings, numbers, and empty slots (consecutive commas).

**Example**

    Data "Sword", 10, 50
    Data "Shield", 5, 30
    Data "Potion", 0, 15

    Dim itemName As String, atk As Integer, cost As Integer
    Read itemName, atk, cost

**See Also** — [Open](#open), [Close](#close), [Line Input](#line-input), [Read](#read), [Restore](#restore), [Sprite Data](#sprite-data), [DataFile](#datafile), [DataToArray](#datatoarray)

---

## DataFile

**Purpose** — Include data from an external file at **parse time** (module level), under a label.

**Syntax**

    LabelName:
    DataFile "path/to/file"

**Description**

- **Text / CSV** — file contents are parsed like inline `Data` values and merged onto the same DATA tape as `Data` statements under that label.
- **Binary `.vgd`** — file is loaded into a labeled `MemoryBuffer` section. Use `DataBuffer("LabelName")`, `DataCount("LabelName")`, and `PeekData("LabelName", offset)` at runtime. See [`.vgd` format](manual/vg_data_format.md).

Paths are Godot `res://` or `user://` strings (same as `LoadData`).

**Example**

    WorldTiles:
    DataFile "levels/world.vgd"

    SpawnTable:
    DataFile "data/spawns.csv"

    Dim n As Integer
    n = DataCount("WorldTiles")
    Dim tile As Integer
    tile = PeekData("WorldTiles", 0)

**See Also** — [Data](#data), [DataBuffer](#databuffer), [LoadData](#loaddata), [PeekData](#peekdata), [Sprite Data](#sprite-data)

---

## DataBuffer

**Purpose** — Returns the `MemoryBuffer` for a labeled `DataFile` section loaded from a binary `.vgd` file.

**Syntax**

    DataBuffer("sectionLabel")

**Description**

Only available when the label’s `DataFile` pointed at a valid `.vgd` grid or blob section. Use `PeekByte`, `PeekUInt16`, etc. on the returned buffer for bulk reads.

**Example**

    WorldTiles:
    DataFile "levels/world.vgd"

    Dim tiles As Object
    tiles = DataBuffer("WorldTiles")
    Print tiles.Size

**See Also** — [DataFile](#datafile), [MemoryBuffer](#memorybuffer), [PeekData](#peekdata)

---

## Sprite Data

**Purpose** — Inline pixel-art sprites stored as labeled `*Sprite:` `Data` blocks in `.vg` source (editable in the IDE Context Rail).

**Syntax**

    LabelSprite:
    Data w, h, transparentIdx, paletteId
    Data …                    ' row 0: w palette indices
    Data …                    ' row 1
    ' … exactly h pixel rows …

**Header row (first `Data` line)**

The four integers on the first `Data` line after the label define the grid:

| Value | Range | Meaning |
|-------|-------|---------|
| `w` | 1–32 | Sprite width in pixels |
| `h` | 1–32 | Sprite height in pixels |
| `transparentIdx` | 0–15 | Palette index skipped when blitting (checkerboard in editor) |
| `paletteId` | 0–3 | Built-in palette for IDE paint preview (see below) |

**Pixel rows**

- Provide exactly **`h` lines** after the header.
- Each line: `Data` followed by **`w` integers** (palette indices 0–15), comma-separated.
- Order: row 0 = top scanline, left to right; then row 1, … row h−1.
- The next `LabelName:` line ends the section (same rules as any labeled `Data` block).

**Label naming**

- Label must end with **`Sprite`** (case-insensitive): `PlayerSprite:`, `CloudSprite:`, `Icon_MenuSprite:`.
- Blocks without the `Sprite` suffix are ordinary data tables, not sprite grids.

**Built-in palettes (`paletteId`)**

| ID | Name | Description |
|----|------|-------------|
| 0 | NES | Default 16-color NES-like palette |
| 1 | GameBoy | 4-shade green base + extended accents |
| 2 | C64 | Commodore 64 colors |
| 3 | CGA | IBM CGA 16-color |

**NES (paletteId = 0)**

| 0 `#7C7C7C` | 1 `#0000FC` | 2 `#0000BC` | 3 `#4428BC` |
| 4 `#940084` | 5 `#A80020` | 6 `#A81000` | 7 `#881400` |
| 8 `#503000` | 9 `#007800` | 10 `#006800` | 11 `#005800` |
| 12 `#004058` | 13 `#000000` | 14 `#BCBCBC` | 15 `#0078F8` |

**GameBoy (paletteId = 1)**

| 0 `#0F380F` | 1 `#306230` | 2 `#8BAC0F` | 3 `#9BBC0F` |
| 4 `#000000` | 5 `#545454` | 6 `#A9A9A9` | 7 `#FFFFFF` |
| 8 `#7C7C7C` | 9 `#0000FC` | 10 `#0000BC` | 11 `#4428BC` |
| 12 `#940084` | 13 `#A80020` | 14 `#A81000` | 15 `#881400` |

**C64 (paletteId = 2)**

| 0 `#000000` | 1 `#FFFFFF` | 2 `#880000` | 3 `#AAFFEE` |
| 4 `#CC44CC` | 5 `#00CC55` | 6 `#0000AA` | 7 `#EEEE77` |
| 8 `#DD8855` | 9 `#664400` | 10 `#FF7777` | 11 `#333333` |
| 12 `#777777` | 13 `#AAFF66` | 14 `#0088FF` | 15 `#BBBBBB` |

**CGA (paletteId = 3)**

| 0 `#000000` | 1 `#0000AA` | 2 `#00AA00` | 3 `#00AAAA` |
| 4 `#AA0000` | 5 `#AA00AA` | 6 `#AA5500` | 7 `#AAAAAA` |
| 8 `#555555` | 9 `#5555FF` | 10 `#55FF55` | 11 `#55FFFF` |
| 12 `#FF5555` | 13 `#FF55FF` | 14 `#FFFF55` | 15 `#FFFFFF` |

**`DataToArray` layout for a sprite section**

    Dim raw As Variant = DataToArray("PlayerSprite")
    ' raw(0) = w
    ' raw(1) = h
    ' raw(2) = transparentIdx
    ' raw(3) = paletteId
    ' raw(4) .. raw(4 + w*h - 1) = pixel indices (row-major)

When drawing, skip indices equal to `transparentIdx`. Call `DataToArray` **once** at load time; cache the `Variant` for `_Draw` helpers.

**Example — minimal 4×4**

    CloudSprite:
    Data 4, 4, 0, 0
    Data 0, 15, 15, 0
    Data 15, 15, 15, 15
    Data 15, 15, 15, 15
    Data 0, 15, 15, 0

    Sub LoadSprites()
        cloudRaw = DataToArray("CloudSprite")
    End Sub

**IDE**

- Caret inside the block → **Context Rail → Sprite data** shows palette swatches and a paint grid.
- Right-click in the code editor → **Edit Sprite Data as Image…** (native Script editor).
- Max **32×32** for inline editing; larger art → PNG + `LoadPicture` / AGCK Sprite Editor.

**See Also** — [Data](#data), [DataToArray](#datatoarray), [PeekData](#peekdata), [DrawRect](#drawrect), [QueueRedraw](#queueredraw)

---

## delta

**Purpose** — The elapsed time since the previous frame (in seconds).

**Syntax**

    delta As Single

**Parameters**

- `As Single`

**Description**

The elapsed time since the previous frame (in seconds). Passed to [b]_Process[/b] and [b]_PhysicsProcess[/b]. Use it to make movement frame-rate independent.

**Example**

    Sub _Process(delta As Single)
        position.x += speed * delta
    End Sub

**Godot Mapping** — [`Node._process()`](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-_process)

**See Also** — [move_and_slide](#move_and_slide), [velocity](#command-reference), [is_on_floor](#is_on_floor), [is_on_wall](#is_on_wall), [_physics_process](#_physics_process)

---

## Dim

**Purpose** — Declares a local variable with an optional type and initial value.

**Syntax**

    Dim variableName As DataType [= initialValue]

**Parameters**

- `variableName`

**Description**

Declares a local variable with an optional type and initial value. Variables declared with Dim are local to the procedure they appear in.

**Example**

    Dim score As Integer = 0
    Dim playerName As String = "Hero"
    Dim items() As String
    Dim health As Single = 100.0

**See Also** — [Private](#private), [Public](#public), [Global](#global), [Static](#static), [Const](#const), [ReDim](#redim), [Type](#type)

---

## Do

**Purpose** — Repeats a block while or until a condition is met.

**Syntax**

    Do [While|Until condition]
        statements
    Loop [While|Until condition]

**Description**

Repeats a block while or until a condition is met. The condition can appear at the top (Do While) or bottom (Loop Until) of the loop.

**Example**

    ' Pre-check loop
    Do While health > 0
        ProcessTurn()
    Loop

    ' Post-check loop (runs at least once)
    Do
        answer = InputBox("Guess?")
    Loop Until answer = secretWord

**See Also** — [Loop](#loop), [While](#while), [Wend](#wend), [Until](#until), [Exit](#exit)

---

## DoEvents

**Purpose** — Yields control to the engine to process pending events (UI updates, input, etc.).

**Syntax**

    DoEvents

**Description**

Yields control to the engine to process pending events (UI updates, input, etc.). Use sparingly in long-running loops.

**Example**

    For i = 1 To 10000
        ProcessItem(i)
        If i Mod 100 = 0 Then DoEvents  ' Keep UI responsive
    Next

**See Also** — [Async](#async), [Await](#await)

---

## Double

**Purpose** — A double-precision floating-point number (64-bit).

**Syntax**

    Dim varName As Double

**Parameters**

- `varName`

**Description**

A double-precision floating-point number (64-bit). More precision than Single.

**Example**

    Dim pi As Double = 3.14159265358979
    Dim distance As Double

**See Also** — [Integer](#integer), [Long](#long), [Single](#single), [String](#string), [Boolean](#boolean), [Variant](#variant), [Array](#array)

---

## DrawArc

**Purpose** — Draws an arc (partial circle outline) centered at (x,y).

**Syntax**

    DrawArc x, y, radius, startAngle, endAngle [, pointCount] [, color] [, width]

**Parameters**

- `x`
- `y`
- `radius`
- `startAngle`
- `endAngle`
- `pointCount`
- `color`
- `width`

**Description**

Draws an arc (partial circle outline) centered at (x,y). Angles are in radians (0 = right, PI/2 = down). pointCount controls smoothness (default 32).

**Example**

    Sub _Draw()
        ' Half circle (0 to PI)
        DrawArc 200, 200, 80, 0, 3.14159, 32, Color.Red, 2
        ' Quarter circle
        DrawArc 400, 200, 60, 0, 1.5708, 16, Color.Blue, 3
        ' Full circle outline
        DrawArc 300, 300, 100, 0, 6.28318, 64, Color.White, 1
    End Sub

**See Also** — [DrawLine](#drawline), [DrawRect](#drawrect), [DrawCircle](#drawcircle), [DrawPixel](#drawpixel), [DrawPolygon](#drawpolygon), [DrawPolyline](#drawpolyline), [PSet](#pset), [CLS](#cls), [QueueRedraw](#queueredraw)

---

## DrawCircle

**Purpose** — Draws a filled circle at the specified center position with the given radius and color.

**Syntax**

    DrawCircle x, y, radius, color
    DrawCircle Vector2(x, y), radius, color

**Description**

Draws a filled circle at the specified center position with the given radius and color.

**Example**

    Sub _Draw()
        DrawCircle 200, 150, 50, Color(0, 1, 0)        ' Green circle
        DrawCircle Vector2(400, 300), 30, Color.Red      ' Godot-style
    End Sub

**See Also** — [DrawLine](#drawline), [DrawRect](#drawrect), [DrawArc](#drawarc), [DrawPixel](#drawpixel), [DrawPolygon](#drawpolygon), [DrawPolyline](#drawpolyline), [PSet](#pset), [CLS](#cls), [QueueRedraw](#queueredraw)

---

## DrawLine

**Purpose** — Draws a line between two points with an optional width.

**Syntax**

    DrawLine x1, y1, x2, y2, color [, width]
    DrawLine Vector2(x1,y1), Vector2(x2,y2), color [, width]

**Description**

Draws a line between two points with an optional width.

**Example**

    Sub _Draw()
        DrawLine 0, 0, 100, 100, Color(1, 1, 0), 2     ' Yellow 2px line
        DrawLine Vector2(50, 50), Vector2(200, 100), Color.White
    End Sub

**See Also** — [DrawRect](#drawrect), [DrawCircle](#drawcircle), [DrawArc](#drawarc), [DrawPixel](#drawpixel), [DrawPolygon](#drawpolygon), [DrawPolyline](#drawpolyline), [PSet](#pset), [CLS](#cls), [QueueRedraw](#queueredraw)

---

## DrawPixel

**Purpose** — Draws a single pixel at the specified position.

**Syntax**

    DrawPixel x, y, color

**Parameters**

- `x`
- `y`
- `color`

**Description**

Draws a single pixel at the specified position. Equivalent to PSet. For per-pixel rendering, consider using CreateImage + SetImagePixel + DrawTexture instead for much better performance.

**Example**

    Sub _Draw()
        DrawPixel 100, 50, Color(1, 0, 0)   ' Red pixel
        PSet 101, 50, Color(0, 1, 0)         ' Green pixel (alias)
    End Sub

    ' For heavy pixel work, use Image APIs:
    Dim img = CreateImage(320, 240)
    SetImagePixel img, 100, 50, Color(1, 0, 0)

**See Also** — [DrawLine](#drawline), [DrawRect](#drawrect), [DrawCircle](#drawcircle), [DrawArc](#drawarc), [DrawPolygon](#drawpolygon), [DrawPolyline](#drawpolyline), [PSet](#pset), [CLS](#cls), [QueueRedraw](#queueredraw)

---

## DrawPolygon

**Purpose** — Draws a filled polygon from an array of Vector2 points.

**Syntax**

    DrawPolygon points, color

**Parameters**

- `points`
- `color`

**Description**

Draws a filled polygon from an array of Vector2 points. Points should be in order (clockwise or counter-clockwise). Use for triangles, custom shapes, filled regions.

**Example**

    Sub _Draw()
        ' Triangle
        Dim tri As Variant = Array(Vector2(100,200), Vector2(200,50), Vector2(300,200))
        DrawPolygon tri, Color.Green
        ' Pentagon
        Dim pent As Variant = Array( _
            Vector2(200,50), Vector2(300,120), Vector2(260,230), _
            Vector2(140,230), Vector2(100,120))
        DrawPolygon pent, Color(0.5, 0.2, 0.8)
    End Sub

**See Also** — [DrawLine](#drawline), [DrawRect](#drawrect), [DrawCircle](#drawcircle), [DrawArc](#drawarc), [DrawPixel](#drawpixel), [DrawPolyline](#drawpolyline), [PSet](#pset), [CLS](#cls), [QueueRedraw](#queueredraw)

---

## DrawPolyline

**Purpose** — Draws a multi-segment line through an array of Vector2 points.

**Syntax**

    DrawPolyline points, color [, width]

**Parameters**

- `points`
- `color`
- `width`

**Description**

Draws a multi-segment line through an array of Vector2 points. Unlike DrawPolygon, this draws open lines (not filled). Great for graphs, paths, vector shapes.

**Example**

    Sub _Draw()
        ' Zigzag line
        Dim pts As Variant = Array( _
            Vector2(10,100), Vector2(50,50), Vector2(90,100), _
            Vector2(130,50), Vector2(170,100))
        DrawPolyline pts, Color.Yellow, 2
    End Sub

**See Also** — [DrawLine](#drawline), [DrawRect](#drawrect), [DrawCircle](#drawcircle), [DrawArc](#drawarc), [DrawPixel](#drawpixel), [DrawPolygon](#drawpolygon), [PSet](#pset), [CLS](#cls), [QueueRedraw](#queueredraw)

---

## DrawRect

**Purpose** — Draws a rectangle on screen in _Draw().

**Syntax**

    DrawRect x, y, width, height, color [, filled]
    DrawRect Rect2(x, y, w, h), color

**Description**

Draws a rectangle on screen in _Draw(). Can use VB-style (x, y, w, h) or Godot-style (Rect2) arguments. If filled is False, draws only the outline.

**Example**

    Sub _Draw()
        DrawRect 10, 10, 200, 100, Color(1, 0, 0)     ' Filled red rect
        DrawRect 10, 10, 200, 100, Color(0, 0, 0), False  ' Black outline
        DrawRect Rect2(50, 50, 100, 80), Color(0, 0, 1)   ' Godot-style
    End Sub

**See Also** — [DrawLine](#drawline), [DrawCircle](#drawcircle), [DrawArc](#drawarc), [DrawPixel](#drawpixel), [DrawPolygon](#drawpolygon), [DrawPolyline](#drawpolyline), [PSet](#pset), [CLS](#cls), [QueueRedraw](#queueredraw)

---

## DrawString

**Purpose** — Draws text using a Godot Font object at the specified position.

**Syntax**

    DrawString font, position, text, color [, fontSize]

**Parameters**

- `font`
- `position`
- `text`
- `color`
- `fontSize`

**Description**

Draws text using a Godot Font object at the specified position. Use GetThemeDefaultFont() to get the default font.

**Example**

    Sub _Draw()
        Dim f As Variant = GetThemeDefaultFont()
        DrawString f, Vector2(10, 20), "Hello World!", Color.White
        DrawString f, Vector2(10, 40), "Score: " & score, Color.Yellow
    End Sub

**See Also** — [DrawTexture](#drawtexture), [DrawTextureRect](#drawtexturerect)

---

## DrawTexture

**Purpose** — Draws a Texture2D at the given position.

**Syntax**

    DrawTexture texture, x, y [, modulate]
    DrawTexture texture, Vector2(x, y) [, modulate]

**Description**

Draws a Texture2D at the given position. Use with LoadPicture, CreateTexture, or ImageToTexture. The modulate parameter tints the texture with a color.

**Example**

    ' Load and draw a texture
    Dim tex As Variant = LoadPicture("res://icon.png")
    Sub _Draw()
        DrawTexture tex, 100, 100
        DrawTexture tex, 300, 100, Color(1, 0.5, 0.5, 0.8)  ' Tinted
    End Sub

    ' Draw from an Image
    Dim img = CreateImage(64, 64, Color.Red)
    Dim tex2 = CreateTexture(img)
    DrawTexture tex2, 0, 0

**See Also** — [DrawString](#drawstring), [DrawTextureRect](#drawtexturerect)

---

## DrawTextureRect

**Purpose** — Draws a texture stretched or tiled into a rectangular area.

**Syntax**

    DrawTextureRect texture, Rect2(x, y, w, h), tile [, modulate]
    DrawTextureRect texture, x, y, w, h [, tile] [, modulate]

**Description**

Draws a texture stretched or tiled into a rectangular area. Set tile=True to tile the texture instead of stretching. Essential for rendering Image-based canvases at a display scale.

**Example**

    ' Stretch a texture to fill a region
    Dim tex = LoadPicture("res://icon.png")
    Sub _Draw()
        DrawTextureRect tex, Rect2(0, 0, 640, 480), False
    End Sub

    ' Image-based canvas with scaled display:
    Dim img = CreateImage(160, 120)   ' Small canvas
    Dim tex = CreateTexture(img)
    Sub _Draw()
        UpdateTexture tex, img
        DrawTextureRect tex, Rect2(0, 0, 640, 480), False  ' 4x scale
    End Sub

**See Also** — [DrawString](#drawstring), [DrawTexture](#drawtexture)

---


### E

## Else

**Purpose** — Specifies code to execute when the If condition (and all ElseIf conditions) are False.

**Syntax**

    Else
        statements

**Description**

Specifies code to execute when the If condition (and all ElseIf conditions) are False.

**Example**

    If IsKeyPressed("space") Then
        Jump()
    Else
        Fall()
    End If

**See Also** — [If](#if), [Then](#then), [ElseIf](#elseif), [End If](#end-if), [Select Case](#select-case), [IIf](#iif)

---

## ElseIf

**Purpose** — Provides an additional condition to test when the preceding If or ElseIf was False.

**Syntax**

    ElseIf condition Then
        statements

**Description**

Provides an additional condition to test when the preceding If or ElseIf was False.

**Example**

    If score >= 90 Then
        grade = "A"
    ElseIf score >= 80 Then
        grade = "B"
    ElseIf score >= 70 Then
        grade = "C"
    Else
        grade = "F"
    End If

**See Also** — [If](#if), [Then](#then), [Else](#else), [End If](#end-if), [Select Case](#select-case), [IIf](#iif)

---

## emit_signal

**Purpose** — Emits the given signal, optionally passing arguments to connected callbacks.

**Syntax**

    emit_signal(signal_name As String, ...)

**Parameters**

- `signal_name`
- `...`

**Description**

Emits the given signal, optionally passing arguments to connected callbacks.

**Example**

    emit_signal("health_changed", currentHP)
    emit_signal("died")

**Godot Mapping** — [`Object.emit_signal()`](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-emit_signal)

**See Also** — [connect](#connect)

---

## End

**Purpose** — Terminates a block or ends program execution.

**Syntax**

    End [Sub|Function|If|Select|Class|Type|With|Enum|Try|Using|Whenever]

**Parameters**

- `Sub|Function|If|Select|Class|Type|With|Enum|Try|Using|Whenever`

**Description**

Terminates a block or ends program execution. When used alone, terminates the application.

**Example**

    End Sub
    End Function
    End If
    End Select
    End Class
    End  ' Terminate program

---

## End Class

**Purpose** — Terminates a Class definition.

**Syntax**

    End Class

**Parameters**

- `Class`

**Description**

Terminates a Class definition.

**Example**

    Class Enemy
        Public Speed As Single = 1.0
    End Class

**See Also** — [Class](#class), [New](#new), [Set](#set), [Me](#me), [Implements](#implements), [Inherits](#inherits), [Interface](#interface), [Property](#property)

---

## End Function

**Purpose** — Terminates a Function definition.

**Syntax**

    End Function

**Parameters**

- `Function`

**Description**

Terminates a Function definition.

**Example**

    Function Square(x As Integer) As Integer
        Square = x * x
    End Function

**See Also** — [Sub](#sub), [Function](#function), [End Sub](#end-sub), [Call](#call), [Return](#return), [ByRef](#byref), [ByVal](#byval), [Optional](#optional), [Lambda](#lambda)

---

## End If

**Purpose** — Terminates a multi-line If...Then...Else block.

**Syntax**

    End If

**Parameters**

- `If`

**Description**

Terminates a multi-line If...Then...Else block.

**Example**

    If score > 100 Then
        Print "Winner!"
    End If

**See Also** — [If](#if), [Then](#then), [Else](#else), [ElseIf](#elseif), [Select Case](#select-case), [IIf](#iif)

---

## End Select

**Purpose** — Terminates a Select Case block.

**Syntax**

    End Select

**Parameters**

- `Select`

**Description**

Terminates a Select Case block.

**Example**

    Select Case x
        Case 1
            Print "One"
    End Select

**See Also** — [Select](#select), [Select Case](#select-case), [Case](#case)

---

## End Sub

**Purpose** — Terminates a Sub procedure definition.

**Syntax**

    End Sub

**Parameters**

- `Sub`

**Description**

Terminates a Sub procedure definition.

**Example**

    Sub Form_Load()
        Print "Ready!"
    End Sub

**See Also** — [Sub](#sub), [Function](#function), [End Function](#end-function), [Call](#call), [Return](#return), [ByRef](#byref), [ByVal](#byval), [Optional](#optional), [Lambda](#lambda)

---

## End With

**Purpose** — Terminates a With block.

**Syntax**

    End With

**Parameters**

- `With`

**Description**

Terminates a With block.

**Example**

    With player
        .Health = 100
        .Score = 0
    End With

**See Also** — [With](#with), [Using](#using)

---

## Enum

**Purpose** — Declares an enumeration — a set of named integer constants.

**Syntax**

    Enum EnumName
        Value1 [= number]
        Value2
        ...
    End Enum

**Description**

Declares an enumeration — a set of named integer constants.

**Example**

    Enum GameState
        Menu = 0
        Playing = 1
        Paused = 2
        GameOver = 3
    End Enum

    Dim state As GameState = GameState.Playing

---

## Event

**Purpose** — Declares a custom event that can be raised with RaiseEvent.

**Syntax**

    Event EventName([parameters])

**Parameters**

- `parameters`

**Description**

Declares a custom event that can be raised with RaiseEvent.

**Example**

    Class Timer
        Event Tick()
        Event Elapsed(seconds As Integer)
    End Class

**See Also** — [RaiseEvent](#raiseevent), [WithEvents](#withevents)

---

## Exit

**Purpose** — Immediately exits the current procedure or loop.

**Syntax**

    Exit Sub | Exit Function | Exit For | Exit Do | Exit While

**Parameters**

- `Sub | Exit Function | Exit For | Exit Do | Exit While`

**Description**

Immediately exits the current procedure or loop. Control passes to the statement after the End Sub/Next/Loop.

**Example**

    For i = 1 To 100
        If items(i) = target Then
            foundAt = i
            Exit For
        End If
    Next

**See Also** — [For](#for), [Next](#next), [For Each](#for-each), [Continue](#continue), [Do](#do), [Loop](#loop), [While](#while), [Wend](#wend), [Until](#until)

---


### F

## False

**Purpose** — Boolean literal representing a false/off state.

**Syntax**

    False

**Description**

Boolean literal representing a false/off state.

**Example**

    Dim gameOver As Boolean = False
    Enabled = False

**See Also** — [True](#true), [Nothing](#nothing)

---

## FillImage

**Purpose** — Fills the entire Image with a solid color.

**Syntax**

    FillImage image, color

**Parameters**

- `image`
- `color`

**Description**

Fills the entire Image with a solid color. Much faster than looping over every pixel with SetImagePixel. Use for clearing a canvas or setting a background.

**Example**

    Dim img = CreateImage(640, 480)

    ' Clear to white
    FillImage img, Color(1, 1, 1, 1)

    ' Clear to black
    FillImage img, Color(0, 0, 0, 1)

    ' Using Color8
    FillImage img, Color8(100, 150, 200, 255)

**See Also** — [CreateImage](#createimage), [FillImageRect](#fillimagerect), [GetImagePixel](#getimagepixel), [SetImagePixel](#setimagepixel), [BlitImage](#blitimage), [ImageWidth](#imagewidth), [ImageHeight](#imageheight)

---

## FillImageRect

**Purpose** — Fills a rectangular region of an Image with a color.

**Syntax**

    FillImageRect image, Rect2i(x, y, w, h), color
    FillImageRect image, x, y, w, h, color

**Description**

Fills a rectangular region of an Image with a color. Faster than per-pixel loops for rectangular fills.

**Example**

    Dim img = CreateImage(320, 240, Color.White)

    ' Draw a green rectangle
    FillImageRect img, Rect2i(10, 10, 100, 50), Color(0, 1, 0, 1)

    ' VB-style arguments
    FillImageRect img, 50, 80, 200, 30, Color.Blue

**See Also** — [CreateImage](#createimage), [FillImage](#fillimage), [GetImagePixel](#getimagepixel), [SetImagePixel](#setimagepixel), [BlitImage](#blitimage), [ImageWidth](#imagewidth), [ImageHeight](#imageheight)

---

## Finally

**Purpose** — Code in the Finally block always executes, whether or not an error occurred.

**Syntax**

    Finally
        cleanup statements

**Description**

Code in the Finally block always executes, whether or not an error occurred. Use for cleanup (closing files, etc.).

**Example**

    Try
        Open "log.txt" For Output As #1
        Print #1, "Log entry"
    Finally
        Close #1  ' Always closes the file
    End Try

**See Also** — [On Error](#on-error), [Try](#try), [Catch](#catch), [Throw](#throw)

---

## For

**Purpose** — Repeats a block of code a specific number of times.

**Syntax**

    For counter = start To end [Step increment]
        statements
    Next [counter]

**Description**

Repeats a block of code a specific number of times. The Step clause controls the increment (default is 1). Use Exit For to leave early.

**Example**

    For i = 1 To 10
        Print i
    Next i

    For i = 10 To 0 Step -1
        Print "Countdown: " & i
    Next

    For i = 0 To 100 Step 5
        Print i
    Next

**See Also** — [Next](#next), [For Each](#for-each), [Continue](#continue), [Exit](#exit)

---

## For Each

**Purpose** — Iterates over every element in an array, list, or collection.

**Syntax**

    For Each element In collection
        statements
    Next [element]

**Description**

Iterates over every element in an array, list, or collection.

**Example**

    Dim names() As String = {"Alice", "Bob", "Carol"}
    For Each name In names
        Print "Hello, " & name
    Next

**See Also** — [For](#for), [Next](#next), [Continue](#continue), [Exit](#exit)

---

## Format

**Purpose** — Formats a number, date, or string according to the format pattern.

**Syntax**

    Format(expression, formatString)

**Parameters**

- `expression`
- `formatString`

**Description**

Formats a number, date, or string according to the format pattern.

**Example**

    Print Format(1234.5, "#,##0.00")  ' "1,234.50"
    Print Format(0.75, "0%")          ' "75%"

**See Also** — [Left](#left), [Right](#right), [Mid](#mid), [Trim](#trim), [LCase](#lcase), [UCase](#ucase), [Len](#len), [InStr](#instr), [Replace](#replace), [Split](#split), [Join](#join)

---

## Function

**Purpose** — Declares a function that returns a value.

**Syntax**

    [Public|Private] Function name([params]) As ReturnType
        statements
        Function = returnValue  ' or: Return returnValue
    End Function

**Description**

Declares a function that returns a value. Set the return value by assigning to the function name or using Return.

**Example**

    Function AddScore(points As Integer) As Integer
        score = score + points
        AddScore = score  ' Return value
    End Function

    Function GetGrade(score As Integer) As String
        If score >= 90 Then Return "A"
        If score >= 80 Then Return "B"
        Return "C"
    End Function

**See Also** — [Sub](#sub), [End Sub](#end-sub), [End Function](#end-function), [Call](#call), [Return](#return), [ByRef](#byref), [ByVal](#byval), [Optional](#optional), [Lambda](#lambda)

---


### G

## get_global_mouse_position

**Purpose** — Returns the mouse position in global coordinates.

**Syntax**

    get_global_mouse_position() As Vector2

**Description**

Returns the mouse position in global coordinates.

**Example**

    Dim mouse As Vector2 = get_global_mouse_position()
    look_at(mouse)

**Godot Mapping** — [`CanvasItem.get_global_mouse_position()`](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem-method-get_global_mouse_position)

---

## get_node

**Purpose** — Returns the node at the given path relative to this node.

**Syntax**

    get_node(path As NodePath) As Node

**Parameters**

- `path`

**Description**

Returns the node at the given path relative to this node. Also available via the [b]$[/b] shorthand.

**Example**

    Dim player As Node = get_node("Player")
    Dim label As Node = get_node("UI/ScoreLabel")

**Godot Mapping** — [`Node.get_node()`](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-get_node)

**See Also** — [add_child](#add_child), [remove_child](#remove_child), [queue_free](#queue_free), [get_tree](#get_tree), [instantiate](#instantiate)

---

## get_tree

**Purpose** — Returns the SceneTree this node belongs to.

**Syntax**

    get_tree() As SceneTree

**Description**

Returns the SceneTree this node belongs to. Used for scene management, groups, and timers.

**Example**

    get_tree().change_scene_to_file("res://GameOver.tscn")
    get_tree().quit()

**Godot Mapping** — [`Node.get_tree()`](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-get_tree)

**See Also** — [get_node](#get_node), [add_child](#add_child), [remove_child](#remove_child), [queue_free](#queue_free), [instantiate](#instantiate)

---

## GetImagePixel

**Purpose** — Returns the color of a pixel from an Image.

**Syntax**

    GetImagePixel(image, x, y) As Color

**Parameters**

- `image`
- `x`
- `y`

**Description**

Returns the color of a pixel from an Image. The returned Color has .r, .g, .b, .a properties (0.0 to 1.0 range). Multiply by 255 for integer RGB values.

**Example**

    Dim img = CreateImage(100, 100, Color.Red)
    Dim c As Variant = GetImagePixel(img, 50, 50)
    Print "R=" & Str(c.r)   ' 1.0
    Print "G=" & Str(c.g)   ' 0.0

    ' Get as integer 0-255
    Dim r As Integer = Int(c.r * 255)
    Dim g As Integer = Int(c.g * 255)
    Dim b As Integer = Int(c.b * 255)

**See Also** — [CreateImage](#createimage), [FillImage](#fillimage), [FillImageRect](#fillimagerect), [SetImagePixel](#setimagepixel), [BlitImage](#blitimage), [ImageWidth](#imagewidth), [ImageHeight](#imageheight)

---

## GetTextureImage

**Purpose** — Extracts the Image data from an ImageTexture.

**Syntax**

    GetTextureImage(texture) As Image

**Parameters**

- `texture`

**Description**

Extracts the Image data from an ImageTexture. Useful for reading pixel data from a loaded texture. The returned Image can be modified and pushed back with UpdateTexture.

**Example**

    Dim tex = LoadPicture("res://icon.png")
    Dim img = GetTextureImage(tex)
    Dim c = GetImagePixel(img, 0, 0)  ' Read top-left pixel
    Print "Top-left color: R=" & Str(Int(c.r * 255))

**See Also** — [ImageToTexture](#imagetotexture), [CreateTexture](#createtexture), [UpdateTexture](#updatetexture), [TextureWidth](#texturewidth), [TextureHeight](#textureheight)

---

## Global

**Purpose** — Declares a module-level global variable accessible from any procedure in the form or module.

**Syntax**

    Global variableName As DataType

**Parameters**

- `variableName`

**Description**

Declares a module-level global variable accessible from any procedure in the form or module.

**Example**

    Global highScore As Integer
    Global currentLevel As Integer = 1

**See Also** — [Dim](#dim), [Private](#private), [Public](#public), [Static](#static), [Const](#const), [ReDim](#redim), [Type](#type)

---

## GoSub

**Purpose** — Jumps to a labeled subroutine within the same procedure, then returns to the statement after GoSub.

**Syntax**

    GoSub labelName
    ...
    labelName:
        statements
    Return

**Description**

Jumps to a labeled subroutine within the same procedure, then returns to the statement after GoSub. Classic VB6 feature.

**Example**

    Sub ProcessData()
        GoSub ValidateInput
        GoSub CalculateResult
        Exit Sub

    ValidateInput:
        If data = "" Then Print "No data"
        Return

    CalculateResult:
        result = data * 2
        Return
    End Sub

**See Also** — [GoTo](#goto), [Return](#return)

---

## GoTo

**Purpose** — Transfers execution to the specified label.

**Syntax**

    GoTo labelName

**Parameters**

- `labelName`

**Description**

Transfers execution to the specified label. Primarily used in error handling (On Error GoTo). Avoid for general flow control.

**Example**

    On Error GoTo ErrorHandler
    ' ... code ...
    Exit Sub

    ErrorHandler:
        Print "An error occurred"
        Resume Next

**See Also** — [GoSub](#gosub), [Return](#return)

---

## GPS.Accuracy

**Purpose** — Returns horizontal accuracy in meters.

**Syntax**

    GPS.Accuracy() As Double

**Description**

Returns horizontal accuracy in meters. -1 means unknown / no fix yet.

**Platform support**

- ✅ Android: uses `VGAndroidPlugin` GPS bridge
- ⚠️ Windows/macOS/Linux/Web: returns `-1` (unknown)

**Example**

    If GPS.Accuracy() > 0 And GPS.Accuracy() < 20 Then UpdateMap()

**See Also** — [GPS.Lat](#gpslat), [GPS.Lng](#gpslng), [GPS.Alt](#gpsalt), [GPS.Speed](#gpsspeed)

---

## GPS.Alt

**Purpose** — Returns altitude in meters above sea level.

**Syntax**

    GPS.Alt() As Double

**Description**

Returns altitude in meters above sea level. Stub returns 0.

**Platform support**

- ✅ Android: uses `VGAndroidPlugin` GPS bridge
- ⚠️ Windows/macOS/Linux/Web: returns `0`

**Example**

    Print GPS.Alt() & " m"

**See Also** — [GPS.Lat](#gpslat), [GPS.Lng](#gpslng), [GPS.Accuracy](#gpsaccuracy), [GPS.Speed](#gpsspeed)

---

## GPS.Lat

**Purpose** — Returns latitude in decimal degrees.

**Syntax**

    GPS.Lat() As Double

**Description**

Returns latitude in decimal degrees. Returns 0 until a platform plugin publishes real values.

**Platform support**

- ✅ Android: uses `VGAndroidPlugin` GPS bridge
- ⚠️ Windows/macOS/Linux/Web: returns `0`

**Example**

    Print "Lat: " & GPS.Lat()

**See Also** — [GPS.Lng](#gpslng), [GPS.Alt](#gpsalt), [GPS.Accuracy](#gpsaccuracy), [GPS.Speed](#gpsspeed)

---

## GPS.Lng

**Purpose** — Returns longitude in decimal degrees.

**Syntax**

    GPS.Lng() As Double

**Description**

Returns longitude in decimal degrees. Returns 0 until a platform plugin publishes real values.

**Platform support**

- ✅ Android: uses `VGAndroidPlugin` GPS bridge
- ⚠️ Windows/macOS/Linux/Web: returns `0`

**Example**

    Print "Lng: " & GPS.Lng()

**See Also** — [GPS.Lat](#gpslat), [GPS.Alt](#gpsalt), [GPS.Accuracy](#gpsaccuracy), [GPS.Speed](#gpsspeed)

---

## GPS.Speed

**Purpose** — Returns ground speed in m/s.

**Syntax**

    GPS.Speed() As Double

**Description**

Returns ground speed in m/s. Stub returns 0.

**Platform support**

- ✅ Android: uses `VGAndroidPlugin` GPS bridge
- ⚠️ Windows/macOS/Linux/Web: returns `0`

**Example**

    Print (GPS.Speed() * 3.6) & " km/h"

**See Also** — [GPS.Lat](#gpslat), [GPS.Lng](#gpslng), [GPS.Alt](#gpsalt), [GPS.Accuracy](#gpsaccuracy)

---


### H

## hide

**Purpose** — Makes this node invisible.

**Syntax**

    hide()

**Description**

Makes this node invisible. Equivalent to setting [b]visible = False[/b].

**Example**

    hide   ' make invisible

**Godot Mapping** — [`CanvasItem.hide()`](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem-method-hide)

**See Also** — [visible](#command-reference), [show](#show), [modulate](#command-reference)

---


### I

## If

**Purpose** — Executes code conditionally.

**Syntax**

    If condition Then
        statements
    [ElseIf condition Then]
        statements
    [Else]
        statements
    End If

**Description**

Executes code conditionally. Supports multi-line blocks with ElseIf and Else branches, or single-line form.

**Example**

    If score > highScore Then
        highScore = score
        Print "New high score!"
    ElseIf score > 0 Then
        Print "Good job!"
    Else
        Print "Try again!"
    End If

    ' Single-line form:
    If health <= 0 Then gameOver = True

**See Also** — [Then](#then), [Else](#else), [ElseIf](#elseif), [End If](#end-if), [Select Case](#select-case), [IIf](#iif)

---

## IIf

**Purpose** — Inline If — returns one of two values based on a condition.

**Syntax**

    IIf(condition, trueValue, falseValue)

**Parameters**

- `condition`
- `trueValue`
- `falseValue`

**Description**

Inline If — returns one of two values based on a condition. Similar to the ternary operator in other languages.

**Example**

    message = IIf(score > 100, "Excellent!", "Keep trying!")
    color = IIf(health < 20, "Red", "Green")

**See Also** — [If](#if), [Then](#then), [Else](#else), [ElseIf](#elseif), [End If](#end-if), [Select Case](#select-case)

---

## ImageHeight

**Purpose** — Returns the height of an Image in pixels.

**Syntax**

    ImageHeight(image) As Integer

**Parameters**

- `image`

**Description**

Returns the height of an Image in pixels.

**Example**

    Dim img = CreateImage(320, 240)
    Print ImageHeight(img)  ' 240

    ' Iterate all pixels
    For y = 0 To ImageHeight(img) - 1
        For x = 0 To ImageWidth(img) - 1
            SetImagePixel img, x, y, Color(x/320.0, y/240.0, 0.5, 1)
        Next
    Next

**See Also** — [CreateImage](#createimage), [FillImage](#fillimage), [FillImageRect](#fillimagerect), [GetImagePixel](#getimagepixel), [SetImagePixel](#setimagepixel), [BlitImage](#blitimage), [ImageWidth](#imagewidth)

---

## ImageToTexture

**Purpose** — Converts an Image object to a new ImageTexture.

**Syntax**

    ImageToTexture(image) As ImageTexture

**Parameters**

- `image`

**Description**

Converts an Image object to a new ImageTexture. Similar to CreateTexture(image) but always creates a new texture object.

**Example**

    Dim img = CreateImage(100, 100, Color.Green)
    Dim tex = ImageToTexture(img)
    DrawTexture tex, 50, 50

**See Also** — [CreateTexture](#createtexture), [UpdateTexture](#updatetexture), [GetTextureImage](#gettextureimage), [TextureWidth](#texturewidth), [TextureHeight](#textureheight)

---

## ImageWidth

**Purpose** — Returns the width of an Image in pixels.

**Syntax**

    ImageWidth(image) As Integer

**Parameters**

- `image`

**Description**

Returns the width of an Image in pixels.

**Example**

    Dim img = CreateImage(320, 240)
    Print ImageWidth(img)   ' 320
    Print ImageHeight(img)  ' 240

**See Also** — [CreateImage](#createimage), [FillImage](#fillimage), [FillImageRect](#fillimagerect), [GetImagePixel](#getimagepixel), [SetImagePixel](#setimagepixel), [BlitImage](#blitimage), [ImageHeight](#imageheight)

---

## Implements

**Purpose** — Declares that a class implements an interface and must provide all of its methods.

**Syntax**

    Class MyClass
        Implements InterfaceName

**Description**

Declares that a class implements an interface and must provide all of its methods.

**Example**

    Interface IDamageable
        Sub TakeDamage(amount As Integer)
    End Interface

    Class Player
        Implements IDamageable
        Sub TakeDamage(amount As Integer)
            health = health - amount
        End Sub
    End Class

**See Also** — [Class](#class), [End Class](#end-class), [New](#new), [Set](#set), [Me](#me), [Inherits](#inherits), [Interface](#interface), [Property](#property)

---

## Inherits

**Purpose** — Specifies that a class inherits from a base class, gaining its fields, properties, and methods.

**Syntax**

    Class ChildClass
        Inherits ParentClass

**Description**

Specifies that a class inherits from a base class, gaining its fields, properties, and methods.

**Example**

    Class Boss
        Inherits Enemy
        Public Phase As Integer = 1

        Sub Attack()
            MyBase.Attack()  ' Call parent method
            ' Boss-specific attack
        End Sub
    End Class

**See Also** — [Class](#class), [End Class](#end-class), [New](#new), [Set](#set), [Me](#me), [Implements](#implements), [Interface](#interface), [Property](#property)

---

## InputBox

**Purpose** — Displays a dialog with a text input field and returns the user's text.

**Syntax**

    result = InputBox(prompt [, title] [, default])

**Parameters**

- `prompt`
- `title`
- `default`

**Description**

Displays a dialog with a text input field and returns the user's text.

**Example**

    Dim name As String
    name = InputBox("Enter your name:", "Player Setup", "Player 1")
    If name <> "" Then Print "Welcome, " & name

**See Also** — [MsgBox](#msgbox), [LoadForm](#loadform)

---

## instantiate

**Purpose** — Creates an instance of a PackedScene.

**Syntax**

    instantiate() As Node

**Description**

Creates an instance of a PackedScene. Load the scene first with [b]preload[/b] or [b]load[/b].

**Example**

    Dim scene As PackedScene = preload("res://Bullet.tscn")
    Dim bullet As Node = scene.instantiate()
    add_child bullet

**Godot Mapping** — [`PackedScene.instantiate()`](https://docs.godotengine.org/en/stable/classes/class_packedscene.html#class-packedscene-method-instantiate)

**See Also** — [get_node](#get_node), [add_child](#add_child), [remove_child](#remove_child), [queue_free](#queue_free), [get_tree](#get_tree)

---

## InStr

**Purpose** — Returns the position of the first occurrence of search within string (1-based).

**Syntax**

    InStr([start,] string, search)

**Parameters**

- `start`
- `string`
- `search`

**Description**

Returns the position of the first occurrence of search within string (1-based). Returns 0 if not found.

**Example**

    Dim pos As Integer
    pos = InStr("Hello World", "World")  ' 7
    pos = InStr("Hello", "xyz")  ' 0

**See Also** — [Left](#left), [Right](#right), [Mid](#mid), [Trim](#trim), [LCase](#lcase), [UCase](#ucase), [Len](#len), [Replace](#replace), [Split](#split), [Join](#join), [Format](#format)

---

## Int

**Purpose** — Returns the integer portion of a number (truncates toward negative infinity).

**Syntax**

    Int(number)

**Parameters**

- `number`

**Description**

Returns the integer portion of a number (truncates toward negative infinity).

**Example**

    Print Int(3.7)   ' 3
    Print Int(-3.7)  ' -4

**See Also** — [CInt](#cint), [CStr](#cstr), [Val](#val), [Str](#str), [Abs](#abs), [Sqr](#sqr), [Rnd](#rnd), [Randomize](#randomize), [RandRange](#randrange), [Round](#round), [Clamp](#clamp), [Lerp](#lerp), [Mod](#mod)

---

## Integer

**Purpose** — A 32-bit signed integer type.

**Syntax**

    Dim varName As Integer

**Parameters**

- `varName`

**Description**

A 32-bit signed integer type. Range: -2,147,483,648 to 2,147,483,647.

**Example**

    Dim score As Integer = 0
    Dim lives As Integer = 3

**See Also** — [Long](#long), [Single](#single), [Double](#double), [String](#string), [Boolean](#boolean), [Variant](#variant), [Array](#array)

---

## Interface

**Purpose** — Declares an interface — a contract that implementing classes must fulfill.

**Syntax**

    Interface InterfaceName
        Sub MethodName([params])
        Function FuncName([params]) As Type
    End Interface

**Description**

Declares an interface — a contract that implementing classes must fulfill.

**Example**

    Interface ISerializable
        Function Serialize() As String
        Sub Deserialize(data As String)
    End Interface

**See Also** — [Class](#class), [End Class](#end-class), [New](#new), [Set](#set), [Me](#me), [Implements](#implements), [Inherits](#inherits), [Property](#property)

---

## Is

**Purpose** — Type or null comparison operator. Tests if an object is of a given type or is Nothing.

**Syntax**

    result = [TypeOf] object Is TypeName
    result = object Is Nothing

**Parameters**

- `object` — The object to test
- `TypeName` — A Godot class name (e.g., `Sprite2D`, `Label`, etc.)
- `Nothing` — A null reference keyword

**Description**

The `Is` operator tests whether an object is an instance of a given type (including inheritance chain) or is a null reference. When used with `TypeOf`, it provides explicit type checking. Returns `True` if the test passes, `False` otherwise.

The operator supports:
- **Type checking** — `TypeOf object Is ClassName` checks inheritance
- **Null checking** — `object Is Nothing` tests for null references
- **Reference equality** — Compares object identity without evaluation

**Example**

    ' Type checking with TypeOf
    If TypeOf node Is Sprite2D Then
        Print "It is a sprite"
    End If

    ' Type checking (implicit TypeOf)
    If scene Is Node Then
        Print "Scene is a Node"
    End If

    ' Null checking
    If player Is Nothing Then
        Print "Player not found"
    End If

    ' In Control Flow
    If TypeOf event Is InputEventMouseMotion Then
        HandleMouseMove(event)
    End If

**See Also** — [IsNot](#isnot), [TypeOf](#typeof), [Nothing](#nothing), [Implements](#implements), [Inherits](#inherits)

---

## IsNot

**Purpose** — Negative type or null comparison operator. Tests if an object is NOT of a given type or is NOT Nothing.

**Syntax**

    result = [TypeOf] object IsNot TypeName
    result = object IsNot Nothing

**Parameters**

- `object` — The object to test
- `TypeName` — A Godot class name (e.g., `Sprite2D`, `Label`, etc.)
- `Nothing` — A null reference keyword

**Description**

The `IsNot` operator is the logical negation of `Is`. It tests whether an object is not an instance of a given type (including inheritance chain) or is not a null reference. Returns `True` if the test passes, `False` otherwise.

Equivalent to `Not (object Is TypeName)` or `Not (object Is Nothing)`.

**Example**

    ' Verify object is not null before using
    If node IsNot Nothing Then
        node.QueueFree()
    End If

    ' Type exclusion
    If TypeOf actor IsNot CharacterBody2D Then
        Print "Actor is not a CharacterBody"
    End If

    ' Defensive check
    If player IsNot Nothing And player IsNot Nothing Then
        player.TakeDamage(10)
    End If

    ' Skip processing if wrong type
    If shape IsNot CollisionShape2D Then
        Return
    End If

**See Also** — [Is](#is), [TypeOf](#typeof), [Nothing](#nothing), [Not](#not)

---

## is_action_just_pressed

**Purpose** — Returns True only on the frame the action was first pressed.

**Syntax**

    Input.is_action_just_pressed(action As String) As Boolean

**Parameters**

- `action`

**Description**

Returns True only on the frame the action was first pressed.

**Example**

    If Input.is_action_just_pressed("jump") And is_on_floor() Then
        velocity.y = -jump_force
    End If

**Godot Mapping** — [`Input.is_action_just_pressed()`](https://docs.godotengine.org/en/stable/classes/class_input.html#class-input-method-is_action_just_pressed)

**See Also** — [is_action_pressed](#isactionpressed), [is_action_just_released](#is_action_just_released)

---

## is_action_just_released

**Purpose** — Returns True only on the frame the action was released.

**Syntax**

    Input.is_action_just_released(action As String) As Boolean

**Parameters**

- `action`

**Description**

Returns True only on the frame the action was released.

**Example**

    If Input.is_action_just_released("shoot") Then
        ' fire charged shot
    End If

**Godot Mapping** — [`Input.is_action_just_released()`](https://docs.godotengine.org/en/stable/classes/class_input.html#class-input-method-is_action_just_released)

**See Also** — [is_action_pressed](#isactionpressed), [is_action_just_pressed](#is_action_just_pressed)

---

## is_action_pressed

**Purpose** — Returns True while the specified input action is held down.

**Syntax**

    Input.is_action_pressed(action As String) As Boolean

**Parameters**

- `action`

**Description**

Returns True while the specified input action is held down. Defined in Project → Input Map.

**Example**

    If Input.is_action_pressed("move_left") Then
        velocity.x = -speed
    End If

**Godot Mapping** — [`Input.is_action_pressed()`](https://docs.godotengine.org/en/stable/classes/class_input.html#class-input-method-is_action_pressed)

**See Also** — [is_action_just_pressed](#is_action_just_pressed), [is_action_just_released](#is_action_just_released)

---

## is_on_floor

**Purpose** — Returns True if the CharacterBody was on the floor during the last [b]move_and_slide[/b] call.

**Syntax**

    is_on_floor() As Boolean

**Description**

Returns True if the CharacterBody was on the floor during the last [b]move_and_slide[/b] call.

**Example**

    If is_on_floor() Then
        velocity.y = -jump_force
    End If

**Godot Mapping** — [`CharacterBody2D.is_on_floor()`](https://docs.godotengine.org/en/stable/classes/class_characterbody2d.html#class-characterbody2d-method-is_on_floor)

**See Also** — [move_and_slide](#move_and_slide), [velocity](#command-reference), [is_on_wall](#is_on_wall), [_physics_process](#_physics_process), [delta](#delta)

---

## is_on_wall

**Purpose** — Returns True if the CharacterBody was touching a wall during the last [b]move_and_slide[/b] call.

**Syntax**

    is_on_wall() As Boolean

**Description**

Returns True if the CharacterBody was touching a wall during the last [b]move_and_slide[/b] call.

**Example**

    If is_on_wall() Then
        ' wall slide or wall jump
    End If

**Godot Mapping** — [`CharacterBody2D.is_on_wall()`](https://docs.godotengine.org/en/stable/classes/class_characterbody2d.html#class-characterbody2d-method-is_on_wall)

**See Also** — [move_and_slide](#move_and_slide), [velocity](#command-reference), [is_on_floor](#is_on_floor), [_physics_process](#_physics_process), [delta](#delta)

---

## IsActionPressed

**Purpose** — Returns True if the specified input action (defined in Project Settings) is active.

**Syntax**

    IsActionPressed(actionName) As Boolean

**Parameters**

- `actionName`

**Description**

Returns True if the specified input action (defined in Project Settings) is active.

**Example**

    If IsActionPressed("ui_accept") Then
        SelectMenuItem()
    End If

**See Also** — [IsKeyPressed](#iskeypressed), [PlaySound](#playsound), [ChangeScene](#changescene), [CreateActor2D](#createactor2d)

---

## IsKeyPressed

**Purpose** — Returns True if the specified keyboard key is currently held down.

**Syntax**

    IsKeyPressed(keyName) As Boolean

**Parameters**

- `keyName`

**Description**

Returns True if the specified keyboard key is currently held down.

**Example**

    If IsKeyPressed("space") Then
        Jump()
    End If

    If IsKeyPressed("left") Then x = x - speed
    If IsKeyPressed("right") Then x = x + speed

**See Also** — [IsActionPressed](#isactionpressed), [PlaySound](#playsound), [ChangeScene](#changescene), [CreateActor2D](#createactor2d)

---


### J

## Join

**Purpose** — Joins an array of strings into a single string with a delimiter between each element.

**Syntax**

    Join(array, delimiter)

**Parameters**

- `array`
- `delimiter`

**Description**

Joins an array of strings into a single string with a delimiter between each element.

**Example**

    Dim arr() As String = {"Red", "Green", "Blue"}
    Print Join(arr, ", ")  ' "Red, Green, Blue"

**See Also** — [Left](#left), [Right](#right), [Mid](#mid), [Trim](#trim), [LCase](#lcase), [UCase](#ucase), [Len](#len), [InStr](#instr), [Replace](#replace), [Split](#split), [Format](#format)

---

## Joypad.Axis

**Purpose** — Returns the analog axis value (-1.0 to 1.0).

**Syntax**

    Joypad.Axis(device, axisIndex) As Double

**Parameters**

- `device`
- `axisIndex`

**Description**

Returns the analog axis value (-1.0 to 1.0). Axis 0/1 = left stick, 2/3 = right stick, 4/5 = triggers.

**Example**

    ' Move with left stick
    Dim mx = Joypad.Axis(0, 0)
    Dim my = Joypad.Axis(0, 1)
    position += Vector2(mx, my) * 200 * delta

**See Also** — [Joypad.Connected](#joypadconnected), [Joypad.IsConnected](#joypadisconnected), [Joypad.Name](#joypadname), [Joypad.Button](#joypadbutton), [Joypad.Stick](#joypadstick)

---

## Joypad.Button

**Purpose** — Returns True if the given button is currently held down.

**Syntax**

    Joypad.Button(device, buttonIndex) As Boolean

**Parameters**

- `device`
- `buttonIndex`

**Description**

Returns True if the given button is currently held down. 0=A/Cross, 1=B/Circle, 2=X/Square, 3=Y/Triangle, 6=Start.

**Example**

    If Joypad.Button(0, 0) Then Jump()

**See Also** — [Joypad.Connected](#joypadconnected), [Joypad.IsConnected](#joypadisconnected), [Joypad.Name](#joypadname), [Joypad.Axis](#joypadaxis), [Joypad.Stick](#joypadstick)

---

## Joypad.Connected

**Purpose** — Returns True if a joypad is connected at the given device index (0-based).

**Syntax**

    Joypad.Connected(device) As Boolean

**Parameters**

- `device`

**Description**

Returns True if a joypad is connected at the given device index (0-based).

**Example**

    If Joypad.Connected(0) Then Print "Player 1 controller ready"

**See Also** — [Joypad.IsConnected](#joypadisconnected), [Joypad.Name](#joypadname), [Joypad.Axis](#joypadaxis), [Joypad.Button](#joypadbutton), [Joypad.Stick](#joypadstick)

---

## Joypad.IsConnected

**Purpose** — Returns True if a joypad/gamepad is currently connected at the given device index.

**Syntax**

    Joypad.IsConnected(index) As Boolean

**Parameters**

- `index`

**Description**

Returns True if a joypad/gamepad is currently connected at the given device index. Companion to Joypad.Connected (which returns the count).

**Example**

    If Joypad.IsConnected(0) Then ShowPlayerJoinedIcon()

**See Also** — [Joypad.Connected](#joypadconnected), [Joypad.Name](#joypadname), [Joypad.Axis](#joypadaxis), [Joypad.Button](#joypadbutton), [Joypad.Stick](#joypadstick)

---

## Joypad.Name

**Purpose** — Returns the joypad's name (e.g.

**Syntax**

    Joypad.Name(device) As String

**Parameters**

- `device`

**Description**

Returns the joypad's name (e.g. "Xbox Wireless Controller"). Empty string if not connected.

**Example**

    Print "P1: " & Joypad.Name(0)

**See Also** — [Joypad.Connected](#joypadconnected), [Joypad.IsConnected](#joypadisconnected), [Joypad.Axis](#joypadaxis), [Joypad.Button](#joypadbutton), [Joypad.Stick](#joypadstick)

---

## Joypad.Stick

**Purpose** — Returns the analog stick position as a Vector2 (-1..1 per axis).

**Syntax**

    Joypad.Stick(index, side) As Vector2

**Parameters**

- `index`
- `side`

**Description**

Returns the analog stick position as a Vector2 (-1..1 per axis). `side` is 0 for left stick, 1 for right.

**Example**

    Dim move = Joypad.Stick(0, 0)
    player.Velocity = move * speed

**See Also** — [Joypad.Connected](#joypadconnected), [Joypad.IsConnected](#joypadisconnected), [Joypad.Name](#joypadname), [Joypad.Axis](#joypadaxis), [Joypad.Button](#joypadbutton)

---

## JS.Call

**Purpose** — Calls a JavaScript function in global scope.

**Syntax**

    JS.Call(funcName, args...) As Variant

**Parameters**

- `funcName`
- `args...`

**Description**

Calls a JavaScript function in global scope. String args are quoted automatically.

**Platform support**

- ✅ Web (HTML5 export): executes via `JavaScriptBridge`
- ⚠️ Windows/macOS/Linux/Android: returns empty `Variant`

**Example**

    JS.Call "console.log", "VG says hi"

**See Also** — [JS.Eval](#jseval), [JS.Get](#jsget)

---

## JS.Eval

**Purpose** — Evaluates a JavaScript expression and returns the result.

**Syntax**

    JS.Eval(code [, useGlobal]) As Variant

**Parameters**

- `code`
- `useGlobal`

**Description**

Evaluates a JavaScript expression and returns the result. useGlobal=True runs in the global scope (window).

**Platform support**

- ✅ Web (HTML5 export): executes via `JavaScriptBridge`
- ⚠️ Windows/macOS/Linux/Android: returns empty `Variant`

**Example**

    Dim t = JS.Eval("document.title", True)
    JS.Eval "alert('hi from VG')"

**See Also** — [JS.Call](#jscall), [JS.Get](#jsget)

---

## JS.Get

**Purpose** — Reads a JavaScript value by path (e.g.

**Syntax**

    JS.Get(path) As Variant

**Parameters**

- `path`

**Description**

Reads a JavaScript value by path (e.g. "window.location.href"). Shortcut for JS.Eval with useGlobal=True.

**Platform support**

- ✅ Web (HTML5 export): executes via `JavaScriptBridge`
- ⚠️ Windows/macOS/Linux/Android: returns empty `Variant`

**Example**

    Print JS.Get("navigator.userAgent")

**See Also** — [JS.Eval](#jseval), [JS.Call](#jscall)

---


### L

## Lambda

**Purpose** — Creates an anonymous function (closure) that can be stored in a variable or passed as an argument.

**Syntax**

    Lambda(params) expression
    Lambda(params)
        statements
    End Lambda

**Description**

Creates an anonymous function (closure) that can be stored in a variable or passed as an argument.

**Example**

    Dim double As Function = Lambda(x) x * 2
    Print double(5)  ' 10

    Dim greet As Function = Lambda(name)
        Print "Hello, " & name
    End Lambda
    greet("World")

**See Also** — [Sub](#sub), [Function](#function), [End Sub](#end-sub), [End Function](#end-function), [Call](#call), [Return](#return), [ByRef](#byref), [ByVal](#byval), [Optional](#optional)

---

## LBound

**Purpose** — Returns the lowest valid index of an array (usually 0).

**Syntax**

    LBound(arrayName [, dimension])

**Parameters**

- `arrayName`
- `dimension`

**Description**

Returns the lowest valid index of an array (usually 0).

**Example**

    For i = LBound(arr) To UBound(arr)
        Print arr(i)
    Next

**See Also** — [Array](#array), [ReDim](#redim), [UBound](#ubound)

---

## LCase

**Purpose** — Converts a string to lowercase.

**Syntax**

    LCase(string)

**Parameters**

- `string`

**Description**

Converts a string to lowercase.

**Example**

    Print LCase("HELLO")  ' "hello"

**See Also** — [Left](#left), [Right](#right), [Mid](#mid), [Trim](#trim), [UCase](#ucase), [Len](#len), [InStr](#instr), [Replace](#replace), [Split](#split), [Join](#join), [Format](#format)

---

## Left

**Purpose** — Returns the specified number of characters from the beginning of a string.

**Syntax**

    Left(string, length)

**Parameters**

- `string`
- `length`

**Description**

Returns the specified number of characters from the beginning of a string.

**Example**

    Print Left("Hello World", 5)  ' "Hello"

**See Also** — [Right](#right), [Mid](#mid), [Trim](#trim), [LCase](#lcase), [UCase](#ucase), [Len](#len), [InStr](#instr), [Replace](#replace), [Split](#split), [Join](#join), [Format](#format)

---

## Len

**Purpose** — Returns the number of characters in a string.

**Syntax**

    Len(string)

**Parameters**

- `string`

**Description**

Returns the number of characters in a string.

**Example**

    Dim s As String = "Hello"
    Print Len(s)  ' 5

**See Also** — [Left](#left), [Right](#right), [Mid](#mid), [Trim](#trim), [LCase](#lcase), [UCase](#ucase), [InStr](#instr), [Replace](#replace), [Split](#split), [Join](#join), [Format](#format)

---

## Lerp

**Purpose** — Linearly interpolates between a and b by factor t (0.0 to 1.0).

**Syntax**

    Lerp(a, b, t)

**Parameters**

- `a`
- `b`
- `t`

**Description**

Linearly interpolates between a and b by factor t (0.0 to 1.0).

**Example**

    ' Smooth camera follow
    cameraX = Lerp(cameraX, playerX, 0.1)

    ' Fade color
    alpha = Lerp(0.0, 1.0, fadeProgress)

**See Also** — [Abs](#abs), [Int](#int), [Sqr](#sqr), [Rnd](#rnd), [Randomize](#randomize), [RandRange](#randrange), [Round](#round), [Clamp](#clamp), [Mod](#mod)

---

## Lighten

**Purpose** — Returns a lighter shade of the color.

**Syntax**

    Lighten(color, amount)

**Parameters**

- `color`
- `amount`

**Description**

Returns a lighter shade of the color. Amount is 0..1 (0=unchanged, 1=white).

**Example**

    buttonHover = Lighten(buttonNormal, 0.2)

**See Also** — [ColorFromHSV](#colorfromhsv), [ColorToHSV](#colortohsv), [Darken](#darken), [RGB](#rgb)

---

## Line Input

**Purpose** — Reads an entire line of text from a file (up to the newline character).

**Syntax**

    Line Input #fileNumber, variableName

**Parameters**

- `Input #fileNumber`
- `variableName`

**Description**

Reads an entire line of text from a file (up to the newline character).

**Example**

    Open "names.txt" For Input As #1
    Do While Not EOF(1)
        Line Input #1, currentLine
        Print currentLine
    Loop
    Close #1

**See Also** — [Open](#open), [Close](#close), [Data](#data), [Read](#read), [Restore](#restore)

---

## LoadData

**Purpose** — Appends values from a text file onto the DATA tape at **runtime** (dynamic path).

**Syntax**

    LoadData pathExpression

**Description**

- Opens the file when `LoadData` executes (not at parse time).
- File body is parsed as comma-separated values, same rules as inline `Data`.
- Subsequent `Read` statements consume the appended values after any prior tape content.
- Contrast with **`DataFile`**, which is **parse-time only** and lives under a module-level label.

**Example**

    Dim difficulty As String
    difficulty = "hard"
    LoadData "res://data/enemies_" & difficulty & ".csv"
    Dim count As Integer
    Read count

**See Also** — [Data](#data), [DataFile](#datafile), [Read](#read), [Restore](#restore)

---

## LoadForm

**Purpose** — Loads and displays a form by name.

**Syntax**

    LoadForm formName

**Parameters**

- `formName`

**Description**

Loads and displays a form by name.

**Example**

    LoadForm "SettingsForm"
    LoadForm "HighScores"

**See Also** — [MsgBox](#msgbox), [InputBox](#inputbox)

---

## LoadImage

**Purpose** — Loads an image file (PNG, JPG, BMP, etc.) and returns it as an RGBA8 Image object.

**Syntax**

    LoadImage(path) As Image

**Parameters**

- `path`

**Description**

Loads an image file (PNG, JPG, BMP, etc.) and returns it as an RGBA8 Image object. Unlike LoadPicture (which returns a Texture2D), LoadImage gives you direct pixel access via GetImagePixel.

**Example**

    Dim img = LoadImage("user://painting.png")
    Print "Size: " & Str(ImageWidth(img)) & "x" & Str(ImageHeight(img))

    ' Read a pixel
    Dim c = GetImagePixel(img, 0, 0)
    Print "R=" & Str(Int(c.r * 255))

    ' Convert to texture for display
    Dim tex = ImageToTexture(img)
    DrawTexture tex, 0, 0

**See Also** — [LoadPicture](#loadpicture), [SaveImage](#saveimage), [RGB](#rgb)

---

## LoadPicture

**Purpose** — Loads an image file from the given resource path and returns a Texture2D for use with DrawTexture.

**Syntax**

    LoadPicture(path) As Texture2D

**Parameters**

- `path`

**Description**

Loads an image file from the given resource path and returns a Texture2D for use with DrawTexture. The classic VB6-style way to load images.

**Example**

    Dim tex As Variant = LoadPicture("res://icon.png")
    Sub _Draw()
        DrawTexture tex, 100, 100
    End Sub

**See Also** — [LoadImage](#loadimage), [SaveImage](#saveimage), [RGB](#rgb)

---

## Long

**Purpose** — A 64-bit signed integer type for very large numbers.

**Syntax**

    Dim varName As Long

**Parameters**

- `varName`

**Description**

A 64-bit signed integer type for very large numbers.

**Example**

    Dim bigNumber As Long = 9999999999

**See Also** — [Integer](#integer), [Single](#single), [Double](#double), [String](#string), [Boolean](#boolean), [Variant](#variant), [Array](#array)

---

## look_at

**Purpose** — Rotates the node so it points toward the target position.

**Syntax**

    look_at(target As Vector2)

**Parameters**

- `target`

**Description**

Rotates the node so it points toward the target position.

**Example**

    look_at(get_global_mouse_position())

**Godot Mapping** — [`Node2D.look_at()`](https://docs.godotengine.org/en/stable/classes/class_node2d.html#class-node2d-method-look_at)

**See Also** — [position](#command-reference), [global_position](#command-reference), [rotation](#command-reference), [rotation_degrees](#command-reference), [scale](#command-reference)

---

## Loop

**Purpose** — Terminates a Do loop.

**Syntax**

    Loop [While|Until condition]

**Parameters**

- `While|Until condition`

**Description**

Terminates a Do loop. Optionally tests a condition after each iteration.

**Example**

    Do
        x = x + 1
    Loop Until x >= 10

**See Also** — [Do](#do), [While](#while), [Wend](#wend), [Until](#until), [Exit](#exit)

---


### M

## Material.New

**Purpose** — Compiles a shader from inline GLSL-like code and wraps it in a ShaderMaterial.

**Syntax**

    Material.New(shader_code) As ShaderMaterial

**Parameters**

- `shader_code`

**Description**

Compiles a shader from inline GLSL-like code and wraps it in a ShaderMaterial. Assign the result to a node's material property.

**Example**

    Dim m = Material.New("shader_type canvas_item;\
    uniform float glow = 0.5;\
    void fragment() { COLOR = vec4(glow, 0.0, 0.0, 1.0); }")
    sprite.Material = m

**See Also** — [Material.SetShader](#materialsetshader), [Shader.Param](#shaderparam), [Shader.GetParam](#shadergetparam), [Shader.Set](#shaderset), [Shader.Get](#shaderget)

---

## Material.SetShader

**Purpose** — Replaces the Shader resource of an existing ShaderMaterial.

**Syntax**

    Material.SetShader(material, shader)

**Parameters**

- `material`
- `shader`

**Description**

Replaces the Shader resource of an existing ShaderMaterial.

**Example**

    Material.SetShader sprite.Material, glowShader

**See Also** — [Material.New](#materialnew), [Shader.Param](#shaderparam), [Shader.GetParam](#shadergetparam), [Shader.Set](#shaderset), [Shader.Get](#shaderget)

---

## Me

**Purpose** — Refers to the current object instance.

**Syntax**

    Me.PropertyName
    Me.MethodName()

**Description**

Refers to the current object instance. Similar to 'this' in C# or 'self' in Python.

**Example**

    Class Player
        Public Name As String
        Sub Introduce()
            Print "I am " & Me.Name
        End Sub
    End Class

**See Also** — [Class](#class), [End Class](#end-class), [New](#new), [Set](#set), [Implements](#implements), [Inherits](#inherits), [Interface](#interface), [Property](#property)

---

## Mid

**Purpose** — Returns a substring starting at position start (1-based).

**Syntax**

    Mid(string, start [, length])

**Parameters**

- `string`
- `start`
- `length`

**Description**

Returns a substring starting at position start (1-based). If length is omitted, returns the rest of the string.

**Example**

    Print Mid("Hello World", 7)     ' "World"
    Print Mid("Hello World", 1, 5)  ' "Hello"

**See Also** — [Left](#left), [Right](#right), [Trim](#trim), [LCase](#lcase), [UCase](#ucase), [Len](#len), [InStr](#instr), [Replace](#replace), [Split](#split), [Join](#join), [Format](#format)

---

## Mod

**Purpose** — Modulo operator — returns the remainder after integer division.

**Syntax**

    number1 Mod number2

**Parameters**

- `Mod number2`

**Description**

Modulo operator — returns the remainder after integer division.

**Example**

    If i Mod 2 = 0 Then
        Print i & " is even"
    End If

    frame = frame Mod maxFrames

**See Also** — [Abs](#abs), [Int](#int), [Sqr](#sqr), [Rnd](#rnd), [Randomize](#randomize), [RandRange](#randrange), [Round](#round), [Clamp](#clamp), [Lerp](#lerp)

---

## move_and_slide

**Purpose** — Moves the body based on [b]velocity[/b], sliding along collisions.

**Syntax**

    move_and_slide() As Boolean

**Description**

Moves the body based on [b]velocity[/b], sliding along collisions. Call in [b]_PhysicsProcess[/b]. Returns True if a collision occurred.

**Example**

    Sub _PhysicsProcess(delta As Single)
        velocity.y += 980 * delta   ' gravity
        move_and_slide
    End Sub

**Godot Mapping** — [`CharacterBody2D.move_and_slide()`](https://docs.godotengine.org/en/stable/classes/class_characterbody2d.html#class-characterbody2d-method-move_and_slide)

**See Also** — [velocity](#command-reference), [is_on_floor](#is_on_floor), [is_on_wall](#is_on_wall), [_physics_process](#_physics_process), [delta](#delta)

---

## MsgBox

**Purpose** — Displays a message dialog box.

**Syntax**

    MsgBox prompt [, buttons] [, title]
    result = MsgBox(prompt, buttons, title)

**Description**

Displays a message dialog box. Can include OK/Cancel/Yes/No buttons and return the user's choice.

**Example**

    MsgBox "Game Over!"
    MsgBox "Save game?", vbYesNo, "Save"

    Dim answer As Integer
    answer = MsgBox("Quit?", vbYesNo + vbQuestion, "Exit")
    If answer = vbYes Then End

**See Also** — [InputBox](#inputbox), [LoadForm](#loadform)

---


### N

## Nav.Distance

**Purpose** — Returns the remaining distance to the target along the path.

**Syntax**

    Nav.Distance(agent) As Double

**Parameters**

- `agent`

**Description**

Returns the remaining distance to the target along the path.

**Example**

    If Nav.Distance(enemyNav) < 50 Then Attack()

**See Also** — [Nav.SetTarget](#navsettarget), [Nav.NextPos](#navnextpos), [Nav.Reached](#navreached), [Nav.Path](#navpath)

---

## Nav.NextPos

**Purpose** — Returns the next step along the path.

**Syntax**

    Nav.NextPos(agent) As Vector

**Parameters**

- `agent`

**Description**

Returns the next step along the path. Call inside _PhysicsProcess to drive movement toward this point.

**Example**

    Sub _PhysicsProcess(delta)
        Dim step = Nav.NextPos(enemyNav)
        velocity = (step - Position).Normalized() * 200
        MoveAndSlide Me
    End Sub

**See Also** — [Nav.SetTarget](#navsettarget), [Nav.Distance](#navdistance), [Nav.Reached](#navreached), [Nav.Path](#navpath)

---

## Nav.Path

**Purpose** — Returns the full computed path as an Array of Vector positions.

**Syntax**

    Nav.Path(agent) As Array

**Parameters**

- `agent`

**Description**

Returns the full computed path as an Array of Vector positions.

**Example**

    For Each pt In Nav.Path(enemyNav)
        DrawCircle pt, 3, Color.Yellow
    Next

**See Also** — [Nav.SetTarget](#navsettarget), [Nav.NextPos](#navnextpos), [Nav.Distance](#navdistance), [Nav.Reached](#navreached)

---

## Nav.Reached

**Purpose** — Returns True if the agent has finished navigating (arrived at target or path is invalid).

**Syntax**

    Nav.Reached(agent) As Boolean

**Parameters**

- `agent`

**Description**

Returns True if the agent has finished navigating (arrived at target or path is invalid).

**Example**

    If Nav.Reached(enemyNav) Then PickNewTarget()

**See Also** — [Nav.SetTarget](#navsettarget), [Nav.NextPos](#navnextpos), [Nav.Distance](#navdistance), [Nav.Path](#navpath)

---

## Nav.SetTarget

**Purpose** — Sets the destination for a NavigationAgent.

**Syntax**

    Nav.SetTarget(agent, pos)

**Parameters**

- `agent`
- `pos`

**Description**

Sets the destination for a NavigationAgent. The agent computes a path and starts moving when you read NextPos each frame.

**Example**

    Nav.SetTarget enemyNav, player.Position

**See Also** — [Nav.NextPos](#navnextpos), [Nav.Distance](#navdistance), [Nav.Reached](#navreached), [Nav.Path](#navpath)

---

## New

**Purpose** — Creates a new instance of a class or object type.

**Syntax**

    Dim obj As New ClassName
    Set obj = New ClassName([args])

**Description**

Creates a new instance of a class or object type.

**Example**

    Dim player As New Player
    Dim enemies As New Collection

    Set boss = New Boss("Dragon", 500)

**See Also** — [Class](#class), [End Class](#end-class), [Set](#set), [Me](#me), [Implements](#implements), [Inherits](#inherits), [Interface](#interface), [Property](#property)

---

## NewCurve

**Purpose** — Creates an editable Curve resource for animation/easing.

**Syntax**

    NewCurve()

**Description**

Creates an editable Curve resource for animation/easing. Use .AddPoint(Vector2(x, y)) to add control points then .Sample(t) — where t is 0..1 — to read the interpolated value. Great for designer-tunable shapes (jump arc, damage falloff).

**Example**

    Dim arc = NewCurve()
    arc.AddPoint(Vector2(0, 0))
    arc.AddPoint(Vector2(0.5, 1.0))
    arc.AddPoint(Vector2(1.0, 0))
    Dim height = arc.Sample(t) * jumpMax

**See Also** — [NewRNG](#newrng), [NewNoise](#newnoise), [Rnd](#rnd), [Randomize](#randomize), [RandRange](#randrange)

---

## NewNoise

**Purpose** — Creates a FastNoiseLite generator for procedural content (terrain heightmaps, cloud patterns, perlin/simplex noise).

**Syntax**

    NewNoise([seed])

**Parameters**

- `seed`

**Description**

Creates a FastNoiseLite generator for procedural content (terrain heightmaps, cloud patterns, perlin/simplex noise). Set .Seed, .Frequency, .NoiseType. Sample with .GetNoise2D(x, y), .GetNoise3D(x, y, z) — returns -1..1.

**Example**

    Dim n = NewNoise(1337)
    n.Frequency = 0.05
    For x = 0 To 99
        For y = 0 To 99
            Dim h = (n.GetNoise2D(x, y) + 1) * 0.5  ' 0..1
            heightmap(x, y) = h * 64
        Next
    Next

**See Also** — [NewRNG](#newrng), [NewCurve](#newcurve), [Rnd](#rnd), [Randomize](#randomize), [RandRange](#randrange)

---

## NewRNG

**Purpose** — Creates a per-stream RandomNumberGenerator.

**Syntax**

    NewRNG([seed])

**Parameters**

- `seed`

**Description**

Creates a per-stream RandomNumberGenerator. Unlike global Rnd(), each NewRNG has its own seed for reproducible sequences. Access via .Randf(), .RandiRange(lo, hi), .RandfRange(lo, hi), .Randfn(mean, deviation).

**Example**

    Dim rng = NewRNG(42)            ' fixed seed
    Dim damage = rng.RandiRange(5, 10)
    Dim spread = rng.Randfn(0, 0.2)  ' normal distribution

**See Also** — [NewNoise](#newnoise), [NewCurve](#newcurve), [Rnd](#rnd), [Randomize](#randomize), [RandRange](#randrange)

---

## Next

**Purpose** — Marks the end of a For or For Each loop.

**Syntax**

    Next [counter]

**Parameters**

- `counter`

**Description**

Marks the end of a For or For Each loop. The counter variable name is optional.

**Example**

    For i = 1 To 5
        Print i
    Next i

**See Also** — [For](#for), [For Each](#for-each), [Continue](#continue), [Exit](#exit)

---

## Not

**Purpose** — Logical NOT; also performs bitwise NOT on numeric operands.

**Syntax**

    Not expression

**Parameters**

- `expression`

**Description**

When the operand is boolean or non-numeric: performs logical NOT — inverts a Boolean value.

When the operand is numeric: performs bitwise NOT (one's complement) — each bit is inverted (0→1, 1→0). This follows VB6 semantics.

**Logical Example**

    If Not gameOver Then
        UpdateGame()
    End If

    Visible = Not Visible  ' Toggle

**Bitwise Example**

    Dim flags As Integer = 12       ' Binary: 1100
    Dim result = Not flags          ' Result: -13 (one's complement)
    
    Dim isActive = Not (flags And &H01)  ' Check if bit 0 is clear

**See Also** — [And](#and), [Or](#or), [Xor](#xor), [<<](#command-reference), [>>](#command-reference)

---

## Nothing

**Purpose** — Represents a null object reference.

**Syntax**

    Set obj = Nothing
    If obj Is Nothing Then ...

**Description**

Represents a null object reference. Use to release object references or test if an object is unset.

**Example**

    Set player = Nothing

    If currentEnemy Is Nothing Then
        Print "No enemy nearby"
    End If

**See Also** — [True](#true), [False](#false)

---


### O

## On Error

**Purpose** — Sets up error handling.

**Syntax**

    On Error GoTo labelName
    On Error Resume Next
    On Error GoTo 0

**Description**

Sets up error handling. GoTo sends errors to a label. Resume Next skips errors. GoTo 0 disables the handler.

**Example**

    Sub LoadData()
        On Error GoTo HandleError
        Open "data.txt" For Input As #1
        ' ... read data ...
        Close #1
        Exit Sub

    HandleError:
        Print "Error: " & Err.Description
        Resume Next
    End Sub

**See Also** — [Try](#try), [Catch](#catch), [Finally](#finally), [Throw](#throw)

---

## Open

**Purpose** — Opens a file for reading, writing, or appending.

**Syntax**

    Open filename For mode As #fileNumber

**Parameters**

- `filename For mode As #fileNumber`

**Description**

Opens a file for reading, writing, or appending. Modes: Input, Output, Append, Binary, Random.

**Example**

    ' Read a file
    Open "scores.txt" For Input As #1
    Line Input #1, firstLine
    Close #1

    ' Write a file
    Open "log.txt" For Output As #2
    Print #2, "Game started"
    Close #2

**See Also** — [Close](#close), [Line Input](#line-input), [Data](#data), [Read](#read), [Restore](#restore)

---

## Option Explicit

**Purpose** — Requires all variables to be declared with Dim before use.

**Syntax**

    Option Explicit

**Parameters**

- `Explicit`

**Description**

Requires all variables to be declared with Dim before use. Helps catch typos. Place at the top of your module.

**Example**

    Option Explicit

    Sub Form_Load()
        Dim score As Integer  ' Required with Option Explicit
        score = 100
    End Sub

---

## Optional

**Purpose** — Declares a parameter that the caller may omit.

**Syntax**

    Sub ProcName(Optional paramName As Type = defaultValue)

**Parameters**

- `Optional paramName`

**Description**

Declares a parameter that the caller may omit. A default value is provided.

**Example**

    Sub ShowMessage(msg As String, Optional title As String = "Info")
        MsgBox msg, title
    End Sub

    ShowMessage "Hello"         ' Uses default title
    ShowMessage "Error", "Oops"  ' Custom title

**See Also** — [Sub](#sub), [Function](#function), [End Sub](#end-sub), [End Function](#end-function), [Call](#call), [Return](#return), [ByRef](#byref), [ByVal](#byval), [Lambda](#lambda)

---

## Or

**Purpose** — Logical OR; also performs bitwise OR on numeric operands.

**Syntax**

    expression1 Or expression2

**Parameters**

- `Or expression2`

**Description**

When both operands are boolean or non-numeric: performs logical OR — returns True if either expression is True.

When both operands are numeric: performs bitwise OR — each bit position is True if either operand bit is 1. This follows VB6 semantics.

**Logical Example**

    If key = "escape" Or key = "q" Then
        QuitGame()
    End If

**Bitwise Example**

    Dim flags As Integer = 12       ' Binary: 1100
    Dim mask As Integer = 2         ' Binary: 0010
    Dim result = flags Or mask      ' Result: 14 (Binary: 1110)
    
    flags Or= &H100                 ' Set bit 8

**See Also** — [And](#and), [Not](#not), [Xor](#xor), [<<](#command-reference), [>>](#command-reference)

---


### P

## Permission.All

**Purpose** — Returns an Array of all currently-granted permission strings.

**Syntax**

    Permission.All() As Array

**Description**

Returns an Array of all currently-granted permission strings.

**Platform support**

- ✅ Android/iOS: returns runtime-granted permission list
- ⚠️ Windows/macOS/Linux/Web: typically empty or platform-default permissions

**Example**

    For Each p In Permission.All()
        Print p
    Next

**See Also** — [Permission.Has](#permissionhas), [Permission.Request](#permissionrequest)

---

## Permission.Has

**Purpose** — Returns True if the permission is currently granted.

**Syntax**

    Permission.Has(name) As Boolean

**Parameters**

- `name`

**Description**

Returns True if the permission is currently granted. On desktop always True.

**Platform support**

- ✅ Android/iOS: checks runtime permission state
- ✅ Windows/macOS/Linux/Web: returns `True` (no mobile runtime permission gate)

**Example**

    If Not Permission.Has("camera") Then Permission.Request "camera"

**See Also** — [Permission.Request](#permissionrequest), [Permission.All](#permissionall)

---

## Permission.Request

**Purpose** — Prompts the OS to ask the user for a permission.

**Syntax**

    Permission.Request(name)

**Parameters**

- `name`

**Description**

Prompts the OS to ask the user for a permission. Resolves async — check Permission.Has next frame, or define Sub Permission_Granted(name).

**Platform support**

- ✅ Android/iOS: runtime prompt path (async)
- ⚠️ Windows/macOS/Linux/Web: usually no-op or immediately resolved by platform policy

**Example**

    Permission.Request "location"

**See Also** — [Permission.Has](#permissionhas), [Permission.All](#permissionall)

---

## Physics.Bounce

**Purpose** — Sets the restitution (bounciness) of a RigidBody, 0.0 = dead, 1.0 = full energy return.

**Syntax**

    Physics.Bounce(value, body)

**Parameters**

- `value`
- `body`

**Description**

Sets the restitution (bounciness) of a RigidBody, 0.0 = dead, 1.0 = full energy return.

**Example**

    Physics.Bounce 0.8, ball   ' rubber ball

**See Also** — [Physics.Gravity](#physicsgravity), [Physics.GravityV2](#physicsgravityv2), [Physics.GravityV3](#physicsgravityv3), [Physics.Force](#physicsforce), [Physics.Impulse](#physicsimpulse), [Physics.Torque](#physicstorque), [Physics.Ray](#physicsray), [Push](#push), [Pull](#pull), [Spin](#spin)

---

## Physics.Force

**Purpose** — Applies a continuous force to a RigidBody (call every frame for sustained push).

**Syntax**

    Physics.Force(body, vec [, pos])

**Parameters**

- `body`
- `vec`
- `pos`

**Description**

Applies a continuous force to a RigidBody (call every frame for sustained push). Alias: Pull.

**Example**

    Sub _PhysicsProcess(delta)
        Physics.Force rocket, Vector2(0, -800)   ' constant thrust
    End Sub

**See Also** — [Physics.Gravity](#physicsgravity), [Physics.GravityV2](#physicsgravityv2), [Physics.GravityV3](#physicsgravityv3), [Physics.Bounce](#physicsbounce), [Physics.Impulse](#physicsimpulse), [Physics.Torque](#physicstorque), [Physics.Ray](#physicsray), [Push](#push), [Pull](#pull), [Spin](#spin)

---

## Physics.Gravity

**Purpose** — Sets the world gravity.

**Syntax**

    Physics.Gravity(vector [, body])

**Parameters**

- `vector`
- `body`

**Description**

Sets the world gravity. Pass a scalar for default-direction gravity, or a Vector2/Vector3 for arbitrary direction. With `body`, sets per-body gravity scale.

**Example**

    Physics.Gravity 980        ' classic down
    Physics.Gravity Vector2(0, -980)  ' anti-gravity zone

**See Also** — [Physics.GravityV2](#physicsgravityv2), [Physics.GravityV3](#physicsgravityv3), [Physics.Bounce](#physicsbounce), [Physics.Force](#physicsforce), [Physics.Impulse](#physicsimpulse), [Physics.Torque](#physicstorque), [Physics.Ray](#physicsray), [Push](#push), [Pull](#pull), [Spin](#spin)

---

## Physics.GravityV2

**Purpose** — Explicit Vector2 form of Physics.Gravity — avoids overload guessing when you need 2D.

**Syntax**

    Physics.GravityV2(Vector2 [, body])

**Parameters**

- `Vector2`
- `body`

**Description**

Explicit Vector2 form of Physics.Gravity — avoids overload guessing when you need 2D.

**Example**

    Physics.GravityV2 Vector2(0, 1200)

**See Also** — [Physics.Gravity](#physicsgravity), [Physics.GravityV3](#physicsgravityv3), [Physics.Bounce](#physicsbounce), [Physics.Force](#physicsforce), [Physics.Impulse](#physicsimpulse), [Physics.Torque](#physicstorque), [Physics.Ray](#physicsray), [Push](#push), [Pull](#pull), [Spin](#spin)

---

## Physics.GravityV3

**Purpose** — Explicit Vector3 form of Physics.Gravity for 3D worlds.

**Syntax**

    Physics.GravityV3(Vector3 [, body])

**Parameters**

- `Vector3`
- `body`

**Description**

Explicit Vector3 form of Physics.Gravity for 3D worlds.

**Example**

    Physics.GravityV3 Vector3(0, -9.8, 0)

**See Also** — [Physics.Gravity](#physicsgravity), [Physics.GravityV2](#physicsgravityv2), [Physics.Bounce](#physicsbounce), [Physics.Force](#physicsforce), [Physics.Impulse](#physicsimpulse), [Physics.Torque](#physicstorque), [Physics.Ray](#physicsray), [Push](#push), [Pull](#pull), [Spin](#spin)

---

## Physics.Impulse

**Purpose** — Applies an instant impulse (one-frame push) to a RigidBody.

**Syntax**

    Physics.Impulse(body, vec [, pos])

**Parameters**

- `body`
- `vec`
- `pos`

**Description**

Applies an instant impulse (one-frame push) to a RigidBody. Optional pos is the offset from body center where the force is applied. Alias: Push.

**Example**

    Physics.Impulse ball, Vector2(500, -200)   ' kick the ball

**See Also** — [Physics.Gravity](#physicsgravity), [Physics.GravityV2](#physicsgravityv2), [Physics.GravityV3](#physicsgravityv3), [Physics.Bounce](#physicsbounce), [Physics.Force](#physicsforce), [Physics.Torque](#physicstorque), [Physics.Ray](#physicsray), [Push](#push), [Pull](#pull), [Spin](#spin)

---

## Physics.Ray

**Purpose** — Casts an instant ray from one point to another and returns what it hit.

**Syntax**

    Physics.Ray(from, to [, collisionMask]) As Dictionary

**Parameters**

- `from`
- `to`
- `collisionMask`

**Description**

Casts an instant ray from one point to another and returns what it hit. Returns Dictionary with keys: Hit (Boolean), Collider (Object), Point (Vector), Normal (Vector), Distance (Double). Pass Vector2 for 2D, Vector3 for 3D.

**Example**

    Dim hit = Physics.Ray(player.Position, mouse.Position)
    If hit.Hit Then
        Print "Hit " & hit.Collider.Name & " at " & hit.Distance & " px"
    End If

**See Also** — [Physics.Gravity](#physicsgravity), [Physics.GravityV2](#physicsgravityv2), [Physics.GravityV3](#physicsgravityv3), [Physics.Bounce](#physicsbounce), [Physics.Force](#physicsforce), [Physics.Impulse](#physicsimpulse), [Physics.Torque](#physicstorque), [Push](#push), [Pull](#pull), [Spin](#spin)

---

## Physics.Torque

**Purpose** — Applies a rotational impulse to a RigidBody.

**Syntax**

    Physics.Torque(body, amount)

**Parameters**

- `body`
- `amount`

**Description**

Applies a rotational impulse to a RigidBody. For 2D pass a number, for 3D pass a Vector3. Alias: Spin.

**Example**

    Physics.Torque wheel, 50

**See Also** — [Physics.Gravity](#physicsgravity), [Physics.GravityV2](#physicsgravityv2), [Physics.GravityV3](#physicsgravityv3), [Physics.Bounce](#physicsbounce), [Physics.Force](#physicsforce), [Physics.Impulse](#physicsimpulse), [Physics.Ray](#physicsray), [Push](#push), [Pull](#pull), [Spin](#spin)

---

## Plane

**Purpose** — Infinite plane defined by a normal vector and signed distance from origin.

**Syntax**

    Plane() | Plane(normalVec3) | Plane(normalVec3, d) | Plane(a, b, c, d)

**Description**

Infinite plane defined by a normal vector and signed distance from origin. Used for clipping, side-of-plane tests, and raycast results. Methods include .IsPointOver(p), .DistanceTo(p), .Intersect3(plane2, plane3).

**Example**

    Dim floor = Plane(Vector3(0, 1, 0), 0)  ' ground plane (y=0)
    If floor.IsPointOver(actor.position) Then
        Print "actor is above the floor"
    End If

**See Also** — [Quaternion](#quaternion), [QuaternionFromEuler](#quaternionfromeuler), [Basis](#basis), [Transform2D](#transform2d), [Transform3D](#transform3d), [AABB](#aabb), [Slerp](#slerp)

---

## PlaySound

**Purpose** — Plays a sound effect from the specified resource path.

**Syntax**

    PlaySound(path [, volume] [, pitch])

**Parameters**

- `path`
- `volume`
- `pitch`

**Description**

Plays a sound effect from the specified resource path.

**Example**

    PlaySound "res://sounds/explosion.wav"
    PlaySound "res://sounds/jump.ogg", 0.8, 1.2

**See Also** — [IsActionPressed](#isactionpressed), [IsKeyPressed](#iskeypressed), [ChangeScene](#changescene), [CreateActor2D](#createactor2d)

---

## Print

**Purpose** — Outputs text to the debug console (or to a file when used with a file number).

**Syntax**

    Print expression [; expression ...]
    Print #fileNumber, expression

**Description**

Outputs text to the debug console (or to a file when used with a file number). Semicolons suppress the newline between items.

**Example**

    Print "Score: " & score
    Print "X="; x; " Y="; y
    Print #1, "Log entry: " & message

---

## Private

**Purpose** — Declares a private variable or procedure only accessible within the current module.

**Syntax**

    Private variableName As DataType
    Private Sub ProcedureName()

**Description**

Declares a private variable or procedure only accessible within the current module.

**Example**

    Private lives As Integer = 3
    Private Sub ResetLevel()
        lives = 3
    End Sub

**See Also** — [Dim](#dim), [Public](#public), [Global](#global), [Static](#static), [Const](#const), [ReDim](#redim), [Type](#type)

---

## Property

**Purpose** — Declares a class property with Get (read) and Let/Set (write) accessors.

**Syntax**

    Property Get Name() As Type
        Name = internalValue
    End Property

    Property Let Name(value As Type)
        internalValue = value
    End Property

**Description**

Declares a class property with Get (read) and Let/Set (write) accessors.

**Example**

    Class Circle
        Private _radius As Single

        Property Get Radius() As Single
            Radius = _radius
        End Property

        Property Let Radius(value As Single)
            If value > 0 Then _radius = value
        End Property
    End Class

**See Also** — [Class](#class), [End Class](#end-class), [New](#new), [Set](#set), [Me](#me), [Implements](#implements), [Inherits](#inherits), [Interface](#interface)

---

## PSet

**Purpose** — Draws a single pixel (VB6-style name).

**Syntax**

    PSet x, y, color

**Parameters**

- `x`
- `y`
- `color`

**Description**

Draws a single pixel (VB6-style name). Alias for DrawPixel.

**Example**

    PSet 100, 50, Color(1, 0, 0)   ' Red pixel
    PSet 101, 50, RGB(0, 255, 0)   ' Green pixel

**See Also** — [DrawLine](#drawline), [DrawRect](#drawrect), [DrawCircle](#drawcircle), [DrawArc](#drawarc), [DrawPixel](#drawpixel), [DrawPolygon](#drawpolygon), [DrawPolyline](#drawpolyline), [CLS](#cls), [QueueRedraw](#queueredraw)

---

## Public

**Purpose** — Declares a public variable or procedure accessible from other modules and forms.

**Syntax**

    Public variableName As DataType
    Public Sub ProcedureName()

**Description**

Declares a public variable or procedure accessible from other modules and forms.

**Example**

    Public userName As String
    Public Sub SaveGame()
        ' Save logic here
    End Sub

**See Also** — [Dim](#dim), [Private](#private), [Global](#global), [Static](#static), [Const](#const), [ReDim](#redim), [Type](#type)

---

## Pull

**Purpose** — Continuous force — call each frame to keep applying.

**Syntax**

    Pull(body, vec [, pos])

**Parameters**

- `body`
- `vec`
- `pos`

**Description**

Continuous force — call each frame to keep applying. Plain-English alias for Physics.Force.

**Example**

    Pull magnet, towardPlayer * 800

**See Also** — [Physics.Gravity](#physicsgravity), [Physics.GravityV2](#physicsgravityv2), [Physics.GravityV3](#physicsgravityv3), [Physics.Bounce](#physicsbounce), [Physics.Force](#physicsforce), [Physics.Impulse](#physicsimpulse), [Physics.Torque](#physicstorque), [Physics.Ray](#physicsray), [Push](#push), [Spin](#spin)

---

## Push

**Purpose** — Instant impulse — kicks a RigidBody once.

**Syntax**

    Push(body, vec [, pos])

**Parameters**

- `body`
- `vec`
- `pos`

**Description**

Instant impulse — kicks a RigidBody once. Plain-English alias for Physics.Impulse.

**Example**

    Push enemy, Vector2(-300, 0)

**See Also** — [Physics.Gravity](#physicsgravity), [Physics.GravityV2](#physicsgravityv2), [Physics.GravityV3](#physicsgravityv3), [Physics.Bounce](#physicsbounce), [Physics.Force](#physicsforce), [Physics.Impulse](#physicsimpulse), [Physics.Torque](#physicstorque), [Physics.Ray](#physicsray), [Pull](#pull), [Spin](#spin)

---


### Q

## Quaternion

**Purpose** — Creates a Quaternion — 3D rotation as four numbers.

**Syntax**

    Quaternion() | Quaternion(x, y, z, w)

**Description**

Creates a Quaternion — 3D rotation as four numbers. Identity rotation by default. Use Slerp to blend two rotations smoothly. Multiply two Quaternions to combine rotations.

**Example**

    Dim qIdentity = Quaternion()
    Dim q = Quaternion(0, 0, 0, 1)  ' identity in (x,y,z,w)

    ' Rotate halfway between two orientations
    Dim qHalf = Slerp(qStart, qEnd, 0.5)

**See Also** — [QuaternionFromEuler](#quaternionfromeuler), [Basis](#basis), [Transform2D](#transform2d), [Transform3D](#transform3d), [Plane](#plane), [AABB](#aabb), [Slerp](#slerp)

---

## QuaternionFromEuler

**Purpose** — Builds a Quaternion from Euler angles (pitch, yaw, roll) in radians.

**Syntax**

    QuaternionFromEuler(xRad, yRad, zRad)

**Parameters**

- `xRad`
- `yRad`
- `zRad`

**Description**

Builds a Quaternion from Euler angles (pitch, yaw, roll) in radians. Easier than constructing the four components directly.

**Example**

    ' 90-degree yaw (turn right)
    Dim qTurn = QuaternionFromEuler(0, 1.5707963, 0)
    player.quaternion = qTurn

**See Also** — [Quaternion](#quaternion), [Basis](#basis), [Transform2D](#transform2d), [Transform3D](#transform3d), [Plane](#plane), [AABB](#aabb), [Slerp](#slerp)

---

## queue_free

**Purpose** — Queues this node for deletion at the end of the current frame.

**Syntax**

    queue_free()

**Description**

Queues this node for deletion at the end of the current frame. Safer than calling [b]free()[/b] directly.

**Example**

    Sub _on_body_entered(body)
        body.queue_free   ' destroy the other node
    End Sub

**Godot Mapping** — [`Node.queue_free()`](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-queue_free)

**See Also** — [get_node](#get_node), [add_child](#add_child), [remove_child](#remove_child), [get_tree](#get_tree), [instantiate](#instantiate)

---

## queue_redraw

**Purpose** — Queues a redraw of this CanvasItem.

**Syntax**

    queue_redraw()

**Description**

Queues a redraw of this CanvasItem. This triggers [b]_Draw[/b] to be called again.

**Example**

    score += 1
    queue_redraw   ' refresh the display

**Godot Mapping** — [`CanvasItem.queue_redraw()`](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem-method-queue_redraw)

---

## QueueRedraw

**Purpose** — Requests the node to redraw on the next frame.

**Syntax**

    QueueRedraw

**Description**

Requests the node to redraw on the next frame. Call this after changing any visual state that should be reflected in _Draw(). Useful in _Process() or event handlers to trigger a visual update.

**Example**

    Sub _Process(delta)
        If stateChanged Then
            QueueRedraw  ' Triggers _Draw() next frame
        End If
    End Sub

    ' Or simply call every frame:
    Sub _Process(delta)
        QueueRedraw
    End Sub

**See Also** — [DrawLine](#drawline), [DrawRect](#drawrect), [DrawCircle](#drawcircle), [DrawArc](#drawarc), [DrawPixel](#drawpixel), [DrawPolygon](#drawpolygon), [DrawPolyline](#drawpolyline), [PSet](#pset), [CLS](#cls)

---


### R

## RaiseEvent

**Purpose** — Fires a declared Event, notifying all handlers connected with WithEvents.

**Syntax**

    RaiseEvent EventName([arguments])

**Parameters**

- `arguments`

**Description**

Fires a declared Event, notifying all handlers connected with WithEvents.

**Example**

    Class GameManager
        Event ScoreChanged(newScore As Integer)

        Sub AddPoints(pts As Integer)
            score = score + pts
            RaiseEvent ScoreChanged(score)
        End Sub
    End Class

**See Also** — [Event](#event), [WithEvents](#withevents)

---

## Randomize

**Purpose** — Seeds the random number generator.

**Syntax**

    Randomize [seed]

**Parameters**

- `seed`

**Description**

Seeds the random number generator. Call once at program start for unpredictable sequences.

**Example**

    Randomize
    Print Rnd()  ' Different each run

    Randomize 42  ' Reproducible sequence

**See Also** — [Abs](#abs), [Int](#int), [Sqr](#sqr), [Rnd](#rnd), [RandRange](#randrange), [Round](#round), [Clamp](#clamp), [Lerp](#lerp), [Mod](#mod), [NewRNG](#newrng), [NewNoise](#newnoise), [NewCurve](#newcurve)

---

## RandRange

**Purpose** — Returns a random number between min and max (inclusive).

**Syntax**

    RandRange(min, max)

**Parameters**

- `min`
- `max`

**Description**

Returns a random number between min and max (inclusive).

**Example**

    Dim damage As Integer = RandRange(5, 20)
    Dim x As Single = RandRange(0.0, 1.0)

**See Also** — [Abs](#abs), [Int](#int), [Sqr](#sqr), [Rnd](#rnd), [Randomize](#randomize), [Round](#round), [Clamp](#clamp), [Lerp](#lerp), [Mod](#mod), [NewRNG](#newrng), [NewNoise](#newnoise), [NewCurve](#newcurve)

---

## Ray.Cast2D

**Purpose** — One-shot 2D raycast through PhysicsDirectSpaceState — no RayCast2D node required.

**Syntax**

    Ray.Cast2D(from, to [, mask]) As Dictionary

**Parameters**

- `from`
- `to`
- `mask`

**Description**

One-shot 2D raycast through PhysicsDirectSpaceState — no RayCast2D node required. Returns a Dictionary { position, normal, collider, … } or empty if nothing hit.

**Example**

    Dim hit = Ray.Cast2D(player.Position, Mouse.Position)
    If Not hit.is_empty() Then Print hit.collider.name

**See Also** — [Ray.Cast3D](#raycast3d), [Ray.Target](#raytarget), [Ray.Enable](#rayenable), [Ray.ForceUpdate](#rayforceupdate), [Ray.Hit](#rayhit), [Ray.Collider](#raycollider), [Ray.Point](#raypoint), [Ray.Normal](#raynormal)

---

## Ray.Cast3D

**Purpose** — One-shot 3D raycast — see Ray.Cast2D.

**Syntax**

    Ray.Cast3D(from, to [, mask]) As Dictionary

**Parameters**

- `from`
- `to`
- `mask`

**Description**

One-shot 3D raycast — see Ray.Cast2D. Useful for shooter logic without permanent RayCast3D nodes.

**Example**

    Dim hit = Ray.Cast3D(cam.GlobalPosition, cam.GlobalPosition + cam.Basis.z * -100)

**See Also** — [Ray.Cast2D](#raycast2d), [Ray.Target](#raytarget), [Ray.Enable](#rayenable), [Ray.ForceUpdate](#rayforceupdate), [Ray.Hit](#rayhit), [Ray.Collider](#raycollider), [Ray.Point](#raypoint), [Ray.Normal](#raynormal)

---

## Ray.Collider

**Purpose** — Returns the node the ray is currently hitting, or Nothing if no hit.

**Syntax**

    Ray.Collider(rayNode) As Object

**Parameters**

- `rayNode`

**Description**

Returns the node the ray is currently hitting, or Nothing if no hit.

**Example**

    If Ray.Hit(aimRay) Then
        target = Ray.Collider(aimRay)
    End If

**See Also** — [Ray.Cast2D](#raycast2d), [Ray.Cast3D](#raycast3d), [Ray.Target](#raytarget), [Ray.Enable](#rayenable), [Ray.ForceUpdate](#rayforceupdate), [Ray.Hit](#rayhit), [Ray.Point](#raypoint), [Ray.Normal](#raynormal)

---

## Ray.Enable

**Purpose** — Enables or disables a RayCast node.

**Syntax**

    Ray.Enable(rayNode, on)

**Parameters**

- `rayNode`
- `on`

**Description**

Enables or disables a RayCast node. Disabled rays don't query the physics world.

**Example**

    Ray.Enable scanner, True

**See Also** — [Ray.Cast2D](#raycast2d), [Ray.Cast3D](#raycast3d), [Ray.Target](#raytarget), [Ray.ForceUpdate](#rayforceupdate), [Ray.Hit](#rayhit), [Ray.Collider](#raycollider), [Ray.Point](#raypoint), [Ray.Normal](#raynormal)

---

## Ray.ForceUpdate

**Purpose** — Forces an immediate raycast update (don't wait for next physics frame).

**Syntax**

    Ray.ForceUpdate(rayNode)

**Parameters**

- `rayNode`

**Description**

Forces an immediate raycast update (don't wait for next physics frame). Useful right after moving the ray.

**Example**

    Ray.Target groundRay, Vector2(0, 50)
    Ray.ForceUpdate groundRay
    If Ray.Hit(groundRay) Then Print "floor below"

**See Also** — [Ray.Cast2D](#raycast2d), [Ray.Cast3D](#raycast3d), [Ray.Target](#raytarget), [Ray.Enable](#rayenable), [Ray.Hit](#rayhit), [Ray.Collider](#raycollider), [Ray.Point](#raypoint), [Ray.Normal](#raynormal)

---

## Ray.Hit

**Purpose** — Returns True if the RayCast2D/3D node is currently colliding with something.

**Syntax**

    Ray.Hit(rayNode) As Boolean

**Parameters**

- `rayNode`

**Description**

Returns True if the RayCast2D/3D node is currently colliding with something.

**Example**

    If Ray.Hit(groundRay) Then
        Print "On the ground"
    End If

**See Also** — [Ray.Cast2D](#raycast2d), [Ray.Cast3D](#raycast3d), [Ray.Target](#raytarget), [Ray.Enable](#rayenable), [Ray.ForceUpdate](#rayforceupdate), [Ray.Collider](#raycollider), [Ray.Point](#raypoint), [Ray.Normal](#raynormal)

---

## Ray.Normal

**Purpose** — Returns the surface normal at the hit point — useful for bouncing or aligning to surfaces.

**Syntax**

    Ray.Normal(rayNode) As Vector

**Parameters**

- `rayNode`

**Description**

Returns the surface normal at the hit point — useful for bouncing or aligning to surfaces.

**Example**

    ' Bounce projectile
    velocity = velocity.Bounce(Ray.Normal(hitRay))

**See Also** — [Ray.Cast2D](#raycast2d), [Ray.Cast3D](#raycast3d), [Ray.Target](#raytarget), [Ray.Enable](#rayenable), [Ray.ForceUpdate](#rayforceupdate), [Ray.Hit](#rayhit), [Ray.Collider](#raycollider), [Ray.Point](#raypoint)

---

## Ray.Point

**Purpose** — Returns the world-space hit point of the ray, or Vector.Zero if no hit.

**Syntax**

    Ray.Point(rayNode) As Vector

**Parameters**

- `rayNode`

**Description**

Returns the world-space hit point of the ray, or Vector.Zero if no hit.

**Example**

    DrawCircle Ray.Point(aimRay), 5, Color.Red

**See Also** — [Ray.Cast2D](#raycast2d), [Ray.Cast3D](#raycast3d), [Ray.Target](#raytarget), [Ray.Enable](#rayenable), [Ray.ForceUpdate](#rayforceupdate), [Ray.Hit](#rayhit), [Ray.Collider](#raycollider), [Ray.Normal](#raynormal)

---

## Ray.Target

**Purpose** — Sets the ray's target_position (relative to the ray's own position).

**Syntax**

    Ray.Target(rayNode, pos)

**Parameters**

- `rayNode`
- `pos`

**Description**

Sets the ray's target_position (relative to the ray's own position). Use to redirect the ray.

**Example**

    Ray.Target aimRay, mousePos - aimRay.Position

**See Also** — [Ray.Cast2D](#raycast2d), [Ray.Cast3D](#raycast3d), [Ray.Enable](#rayenable), [Ray.ForceUpdate](#rayforceupdate), [Ray.Hit](#rayhit), [Ray.Collider](#raycollider), [Ray.Point](#raypoint), [Ray.Normal](#raynormal)

---

## Read

**Purpose** — Reads the next value(s) from the Data tape into variables.

**Syntax**

    Read variable1 [, variable2, ...]
    Read variable As Type

**Description**

Reads the next value(s) from the Data tape into variables. Supports typed Read for automatic conversion.

**Example**

    Data 100, 200, 300

    Dim x As Integer, y As Integer, z As Integer
    Read x, y, z
    Print x  ' 100

    ' Typed read
    Read score As Integer

**See Also** — [Open](#open), [Close](#close), [Line Input](#line-input), [Data](#data), [Restore](#restore)

---

## ReDim

**Purpose** — Resizes a dynamic array.

**Syntax**

    ReDim [Preserve] arrayName(newSize)

**Parameters**

- `newSize`

**Description**

Resizes a dynamic array. Use Preserve to keep existing data when resizing.

**Example**

    Dim scores() As Integer
    ReDim scores(10)
    scores(0) = 100
    ReDim Preserve scores(20)  ' Keeps old data

**See Also** — [Dim](#dim), [Private](#private), [Public](#public), [Global](#global), [Static](#static), [Const](#const), [Type](#type), [Array](#array), [LBound](#lbound), [UBound](#ubound)

---

## remove_child

**Purpose** — Removes a child node from this node without freeing it.

**Syntax**

    remove_child(node As Node)

**Parameters**

- `node`

**Description**

Removes a child node from this node without freeing it.

**Example**

    remove_child(oldNode)
    oldNode.queue_free

**Godot Mapping** — [`Node.remove_child()`](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-remove_child)

**See Also** — [get_node](#get_node), [add_child](#add_child), [queue_free](#queue_free), [get_tree](#get_tree), [instantiate](#instantiate)

---

## Replace

**Purpose** — Returns a string with all occurrences of find replaced by replaceWith.

**Syntax**

    Replace(string, find, replaceWith)

**Parameters**

- `string`
- `find`
- `replaceWith`

**Description**

Returns a string with all occurrences of find replaced by replaceWith.

**Example**

    Dim s As String = Replace("Hello World", "World", "VB")
    Print s  ' "Hello VB"

**See Also** — [Left](#left), [Right](#right), [Mid](#mid), [Trim](#trim), [LCase](#lcase), [UCase](#ucase), [Len](#len), [InStr](#instr), [Split](#split), [Join](#join), [Format](#format)

---

## ResetDrawTransform

**Purpose** — Resets the drawing transform to identity (no translation, rotation, or scale).

**Syntax**

    ResetDrawTransform

**Description**

Resets the drawing transform to identity (no translation, rotation, or scale). Always call after SetDrawTransform to restore normal coordinates.

**Example**

    SetDrawTransform 100, 100, 0.5, 2.0, 2.0
    DrawCircle 0, 0, 30, Color.Red   ' Drawn transformed
    ResetDrawTransform                    ' Back to normal
    DrawCircle 50, 50, 10, Color.Blue ' Drawn at actual 50,50

**See Also** — [SetDrawTransform](#setdrawtransform)

---

## Restore

**Purpose** — Resets the Data read pointer to the beginning, or to a named data section.

**Syntax**

    Restore [labelName]

**Parameters**

- `labelName`

**Description**

Resets the Data read pointer to the beginning, or to a named data section.

**Example**

    Data "First", 1
    data_section2:
    Data "Second", 2

    Read a, b
    Restore data_section2
    Read c, d  ' Reads "Second", 2

**See Also** — [Open](#open), [Close](#close), [Line Input](#line-input), [Data](#data), [Read](#read)

---

## Return

**Purpose** — Returns from the current Sub or Function.

**Syntax**

    Return [value]

**Parameters**

- `value`

**Description**

Returns from the current Sub or Function. In a Function, optionally provides the return value.

**Example**

    Function IsPositive(n As Integer) As Boolean
        Return n > 0
    End Function

    Sub CheckHealth()
        If health > 0 Then Return  ' Early exit
        GameOver()
    End Sub

**See Also** — [Sub](#sub), [Function](#function), [End Sub](#end-sub), [End Function](#end-function), [Call](#call), [ByRef](#byref), [ByVal](#byval), [Optional](#optional), [Lambda](#lambda), [GoTo](#goto), [GoSub](#gosub)

---

## RGB

**Purpose** — Creates a Color from integer red, green, blue values (0-255).

**Syntax**

    RGB(red, green, blue) As Color

**Parameters**

- `red`
- `green`
- `blue`

**Description**

Creates a Color from integer red, green, blue values (0-255). VB6-compatible function.

**Example**

    Dim c As Variant = RGB(255, 0, 0)  ' Red
    DrawRect 0, 0, 100, 100, RGB(0, 128, 255)  ' Sky blue

**See Also** — [LoadImage](#loadimage), [LoadPicture](#loadpicture), [SaveImage](#saveimage), [ColorFromHSV](#colorfromhsv), [ColorToHSV](#colortohsv), [Lighten](#lighten), [Darken](#darken)

---

## Right

**Purpose** — Returns the specified number of characters from the end of a string.

**Syntax**

    Right(string, length)

**Parameters**

- `string`
- `length`

**Description**

Returns the specified number of characters from the end of a string.

**Example**

    Print Right("Hello World", 5)  ' "World"

**See Also** — [Left](#left), [Mid](#mid), [Trim](#trim), [LCase](#lcase), [UCase](#ucase), [Len](#len), [InStr](#instr), [Replace](#replace), [Split](#split), [Join](#join), [Format](#format)

---

## Rnd

**Purpose** — Returns a random floating-point number between 0 and 1 (or 0 and upperBound if specified).

**Syntax**

    Rnd([upperBound])

**Parameters**

- `upperBound`

**Description**

Returns a random floating-point number between 0 and 1 (or 0 and upperBound if specified).

**Example**

    Randomize
    Dim r As Single = Rnd()      ' 0.0 to 1.0
    Dim d As Integer = Int(Rnd(6)) + 1  ' Dice roll 1-6

**See Also** — [Abs](#abs), [Int](#int), [Sqr](#sqr), [Randomize](#randomize), [RandRange](#randrange), [Round](#round), [Clamp](#clamp), [Lerp](#lerp), [Mod](#mod), [NewRNG](#newrng), [NewNoise](#newnoise), [NewCurve](#newcurve)

---

## Round

**Purpose** — Rounds a number to the specified number of decimal places.

**Syntax**

    Round(number [, decimals])

**Parameters**

- `number`
- `decimals`

**Description**

Rounds a number to the specified number of decimal places.

**Example**

    Print Round(3.14159, 2)  ' 3.14
    Print Round(2.5)         ' 2 (banker's rounding)

**See Also** — [Abs](#abs), [Int](#int), [Sqr](#sqr), [Rnd](#rnd), [Randomize](#randomize), [RandRange](#randrange), [Clamp](#clamp), [Lerp](#lerp), [Mod](#mod)

---


### S

## SaveImage

**Purpose** — Saves an Image to a PNG file.

**Syntax**

    SaveImage(image, path) As Boolean

**Parameters**

- `image`
- `path`

**Description**

Saves an Image to a PNG file. Returns True on success. Use user:// paths for writable locations. Great for screenshots or saving user-created art.

**Example**

    Dim img = CreateImage(640, 480, Color.White)
    ' ... draw on img ...
    Dim ok As Boolean = SaveImage(img, "user://screenshot.png")
    If ok Then
        Print "Saved!"
    End If

**See Also** — [LoadImage](#loadimage), [LoadPicture](#loadpicture), [RGB](#rgb)

---

## Screen.DPI

**Purpose** — Returns the screen DPI (dots per inch).

**Syntax**

    Screen.DPI() As Long

**Description**

Returns the screen DPI (dots per inch). Useful for sizing UI on high-density displays.

**Example**

    Dim scale = Screen.DPI() / 96.0   ' 1.0 on standard displays

**See Also** — [Screen.Width](#screenwidth), [Screen.Height](#screenheight), [Screen.Orientation](#screenorientation), [Screen.KeepOn](#screenkeepon), [Screen.FullScreen](#screenfullscreen), [Screen.IsFullScreen](#screenisfullscreen)

---

## Screen.FullScreen

**Purpose** — Toggles fullscreen mode for the main window.

**Syntax**

    Screen.FullScreen(on)

**Parameters**

- `on`

**Description**

Toggles fullscreen mode for the main window.

**Example**

    Screen.FullScreen True

**See Also** — [Screen.Width](#screenwidth), [Screen.Height](#screenheight), [Screen.DPI](#screendpi), [Screen.Orientation](#screenorientation), [Screen.KeepOn](#screenkeepon), [Screen.IsFullScreen](#screenisfullscreen)

---

## Screen.Height

**Purpose** — Returns the screen height in pixels.

**Syntax**

    Screen.Height() As Long

**Description**

Returns the screen height in pixels.

**Example**

    Print Screen.Width() & "x" & Screen.Height()

**See Also** — [Screen.Width](#screenwidth), [Screen.DPI](#screendpi), [Screen.Orientation](#screenorientation), [Screen.KeepOn](#screenkeepon), [Screen.FullScreen](#screenfullscreen), [Screen.IsFullScreen](#screenisfullscreen)

---

## Screen.IsFullScreen

**Purpose** — Returns True if the window is currently fullscreen.

**Syntax**

    Screen.IsFullScreen() As Boolean

**Description**

Returns True if the window is currently fullscreen.

**Example**

    If Not Screen.IsFullScreen() Then Screen.FullScreen True

**See Also** — [Screen.Width](#screenwidth), [Screen.Height](#screenheight), [Screen.DPI](#screendpi), [Screen.Orientation](#screenorientation), [Screen.KeepOn](#screenkeepon), [Screen.FullScreen](#screenfullscreen)

---

## Screen.KeepOn

**Purpose** — Prevents the screen from auto-sleeping while True.

**Syntax**

    Screen.KeepOn(on)

**Parameters**

- `on`

**Description**

Prevents the screen from auto-sleeping while True. Critical for games and video apps.

**Example**

    Screen.KeepOn True

**See Also** — [Screen.Width](#screenwidth), [Screen.Height](#screenheight), [Screen.DPI](#screendpi), [Screen.Orientation](#screenorientation), [Screen.FullScreen](#screenfullscreen), [Screen.IsFullScreen](#screenisfullscreen)

---

## Screen.Orientation

**Purpose** — Returns "portrait" or "landscape".

**Syntax**

    Screen.Orientation() As String

**Description**

Returns "portrait" or "landscape".

**Example**

    If Screen.Orientation() = "portrait" Then
        UseVerticalLayout()
    End If

**See Also** — [Screen.Width](#screenwidth), [Screen.Height](#screenheight), [Screen.DPI](#screendpi), [Screen.KeepOn](#screenkeepon), [Screen.FullScreen](#screenfullscreen), [Screen.IsFullScreen](#screenisfullscreen)

---

## Screen.Width

**Purpose** — Returns the screen width in pixels.

**Syntax**

    Screen.Width() As Long

**Description**

Returns the screen width in pixels.

**Example**

    If Screen.Width() < 600 Then SetMobileUI()

**See Also** — [Screen.Height](#screenheight), [Screen.DPI](#screendpi), [Screen.Orientation](#screenorientation), [Screen.KeepOn](#screenkeepon), [Screen.FullScreen](#screenfullscreen), [Screen.IsFullScreen](#screenisfullscreen)

---

## Select

**Purpose** — Begins a Select Case block for multi-way branching based on an expression's value.

**Syntax**

    Select Case expression

**Parameters**

- `Case expression`

**Description**

Begins a Select Case block for multi-way branching based on an expression's value.

**Example**

    Select Case dayOfWeek
        Case 1
            Print "Monday"
        Case 7
            Print "Sunday"
    End Select

**See Also** — [Select Case](#select-case), [Case](#case), [End Select](#end-select)

---

## Select Case

**Purpose** — Evaluates an expression and branches to the matching Case block.

**Syntax**

    Select Case testExpression
        Case value1
            statements
        Case value2, value3
            statements
        Case Else
            statements
    End Select

**Description**

Evaluates an expression and branches to the matching Case block. Supports ranges (1 To 5), comparison (Is > 10), and comma-separated lists.

**Example**

    Select Case score
        Case 100
            Print "Perfect!"
        Case 80 To 99
            Print "Great!"
        Case Is >= 50
            Print "Passed"
        Case Else
            Print "Try again"
    End Select

**See Also** — [If](#if), [Then](#then), [Else](#else), [ElseIf](#elseif), [End If](#end-if), [IIf](#iif), [Select](#select), [Case](#case), [End Select](#end-select)

---

## Sensor.Accel

**Purpose** — Returns the accelerometer reading.

**Syntax**

    Sensor.Accel() As Vector3

**Description**

Returns the accelerometer reading. In game units, ~1.0 G on the Y axis when the phone is upright. Includes gravity.

**Example**

    Dim a = Sensor.Accel()
    If a.Length() > 2.0 Then Print "Shake detected!"

**See Also** — [Sensor.Units](#sensorunits), [Sensor.Gyro](#sensorgyro), [Sensor.Magnet](#sensormagnet), [Sensor.Magnetometer](#sensormagnetometer), [Sensor.Gravity](#sensorgravity), [Sensor.Tilt](#sensortilt)

---

## Sensor.Gravity

**Purpose** — Returns just the gravity component (low-pass filtered accelerometer).

**Syntax**

    Sensor.Gravity() As Vector3

**Description**

Returns just the gravity component (low-pass filtered accelerometer). In game units = Gs.

**Example**

    ' Use as level reference
    Dim down = Sensor.Gravity().Normalized()

**See Also** — [Sensor.Units](#sensorunits), [Sensor.Accel](#sensoraccel), [Sensor.Gyro](#sensorgyro), [Sensor.Magnet](#sensormagnet), [Sensor.Magnetometer](#sensormagnetometer), [Sensor.Tilt](#sensortilt)

---

## Sensor.Gyro

**Purpose** — Returns the gyroscope reading — angular velocity.

**Syntax**

    Sensor.Gyro() As Vector3

**Description**

Returns the gyroscope reading — angular velocity. In game units = degrees/sec.

**Example**

    Dim g = Sensor.Gyro()
    If Abs(g.y) > 90 Then Print "Fast spin!"

**See Also** — [Sensor.Units](#sensorunits), [Sensor.Accel](#sensoraccel), [Sensor.Magnet](#sensormagnet), [Sensor.Magnetometer](#sensormagnetometer), [Sensor.Gravity](#sensorgravity), [Sensor.Tilt](#sensortilt)

---

## Sensor.Magnet

**Purpose** — Returns the magnetometer reading in µT (microtesla).

**Syntax**

    Sensor.Magnet() As Vector3

**Description**

Returns the magnetometer reading in µT (microtesla). Useful for compass apps.

**Example**

    Dim m = Sensor.Magnet()
    Dim heading = Atan2(m.y, m.x) * 57.2958

**See Also** — [Sensor.Units](#sensorunits), [Sensor.Accel](#sensoraccel), [Sensor.Gyro](#sensorgyro), [Sensor.Magnetometer](#sensormagnetometer), [Sensor.Gravity](#sensorgravity), [Sensor.Tilt](#sensortilt)

---

## Sensor.Magnetometer

**Purpose** — Alias of Sensor.Magnet — returns the device magnetometer reading (µT).

**Syntax**

    Sensor.Magnetometer() As Vector3

**Description**

Alias of Sensor.Magnet — returns the device magnetometer reading (µT). Provided for naming consistency with platform docs.

**Example**

    Dim compass = Sensor.Magnetometer()

**See Also** — [Sensor.Units](#sensorunits), [Sensor.Accel](#sensoraccel), [Sensor.Gyro](#sensorgyro), [Sensor.Magnet](#sensormagnet), [Sensor.Gravity](#sensorgravity), [Sensor.Tilt](#sensortilt)

---

## Sensor.Tilt

**Purpose** — Returns device tilt in degrees (rotation around vertical axis).

**Syntax**

    Sensor.Tilt() As Double

**Description**

Returns device tilt in degrees (rotation around vertical axis). 0 = phone upright, ±90 = phone flat on its side.

**Example**

    player.Velocity.x = Sensor.Tilt() * 10   ' tilt-to-steer

**See Also** — [Sensor.Units](#sensorunits), [Sensor.Accel](#sensoraccel), [Sensor.Gyro](#sensorgyro), [Sensor.Magnet](#sensormagnet), [Sensor.Magnetometer](#sensormagnetometer), [Sensor.Gravity](#sensorgravity)

---

## Sensor.Units

**Purpose** — Sets the unit system for subsequent Sensor reads.

**Syntax**

    Sensor.Units(system)

**Parameters**

- `system`

**Description**

Sets the unit system for subsequent Sensor reads. "game" (default) = Gs and degrees/sec. "metric" = m/s² and rad/sec.

**Example**

    Sensor.Units "game"     ' default, easy mode
    Sensor.Units "metric"   ' physics-accurate

**See Also** — [Sensor.Accel](#sensoraccel), [Sensor.Gyro](#sensorgyro), [Sensor.Magnet](#sensormagnet), [Sensor.Magnetometer](#sensormagnetometer), [Sensor.Gravity](#sensorgravity), [Sensor.Tilt](#sensortilt)

---

## Set

**Purpose** — Assigns an object reference to a variable.

**Syntax**

    Set objectVariable = objectExpression
    Set objectVariable = New ClassName

**Description**

Assigns an object reference to a variable. Required for object types (not needed for simple types).

**Example**

    Dim player As Object
    Set player = New Player
    Set player = Nothing  ' Release reference

**See Also** — [Class](#class), [End Class](#end-class), [New](#new), [Me](#me), [Implements](#implements), [Inherits](#inherits), [Interface](#interface), [Property](#property)

---

## set_process

**Purpose** — Enables or disables [b]_Process[/b] for this node.

**Syntax**

    set_process(enable As Boolean)

**Parameters**

- `enable`

**Description**

Enables or disables [b]_Process[/b] for this node.

**Example**

    set_process(False)   ' pause processing
    set_process(True)    ' resume

**Godot Mapping** — [`Node.set_process()`](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-set_process)

---

## SetDrawTransform

**Purpose** — Sets a 2D transform for all subsequent draw calls.

**Syntax**

    SetDrawTransform x, y [, rotation] [, scaleX] [, scaleY]

**Parameters**

- `x`
- `y`
- `rotation`
- `scaleX`
- `scaleY`

**Description**

Sets a 2D transform for all subsequent draw calls. Translation (x,y), rotation in radians, and scale factors. Use to draw rotated or scaled groups of shapes.

**Example**

    Sub _Draw()
        ' Draw a rotated square
        SetDrawTransform 200, 200, 0.785  ' 45 degrees
        DrawRect -25, -25, 50, 50, Color.Red
        ResetDrawTransform

        ' Draw scaled UI
        SetDrawTransform 0, 0, 0, 2.0, 2.0  ' 2x scale
        DrawRect 0, 0, 50, 50, Color.Blue    ' Appears as 100x100
        ResetDrawTransform
    End Sub

**See Also** — [ResetDrawTransform](#resetdrawtransform)

---

## SetImagePixel

**Purpose** — Sets a pixel color on an Image object.

**Syntax**

    SetImagePixel image, x, y, color

**Parameters**

- `image`
- `x`
- `y`
- `color`

**Description**

Sets a pixel color on an Image object. After modifying pixels, call UpdateTexture to push changes to the display texture. Use Color() or Color8() to create the color value.

**Example**

    Dim img = CreateImage(100, 100)
    Dim tex = CreateTexture(img)

    ' Draw a red diagonal line
    For i = 0 To 99
        SetImagePixel img, i, i, Color(1, 0, 0, 1)
    Next
    UpdateTexture tex, img  ' Push changes to GPU

    ' Using Color8 (0-255 range)
    SetImagePixel img, 50, 50, Color8(0, 255, 0, 255)

**See Also** — [CreateImage](#createimage), [FillImage](#fillimage), [FillImageRect](#fillimagerect), [GetImagePixel](#getimagepixel), [BlitImage](#blitimage), [ImageWidth](#imagewidth), [ImageHeight](#imageheight)

---

## Shader.Get

**Purpose** — Alias of Shader.GetParam — reads a shader uniform.

**Syntax**

    Shader.Get(material, key) As Variant

**Parameters**

- `material`
- `key`

**Description**

Alias of Shader.GetParam — reads a shader uniform.

**Example**

    Print Shader.Get(sprite.Material, "hit_flash")

**See Also** — [Material.New](#materialnew), [Material.SetShader](#materialsetshader), [Shader.Param](#shaderparam), [Shader.GetParam](#shadergetparam), [Shader.Set](#shaderset)

---

## Shader.GetParam

**Purpose** — Reads the current value of a shader uniform.

**Syntax**

    Shader.GetParam(material, key) As Variant

**Parameters**

- `material`
- `key`

**Description**

Reads the current value of a shader uniform.

**Example**

    Print Shader.GetParam(sprite.Material, "glow")

**See Also** — [Material.New](#materialnew), [Material.SetShader](#materialsetshader), [Shader.Param](#shaderparam), [Shader.Set](#shaderset), [Shader.Get](#shaderget)

---

## Shader.Param

**Purpose** — Sets a shader uniform on a ShaderMaterial.

**Syntax**

    Shader.Param(material, key, value)

**Parameters**

- `material`
- `key`
- `value`

**Description**

Sets a shader uniform on a ShaderMaterial.

**Example**

    Shader.Param sprite.Material, "glow", 1.5

**See Also** — [Material.New](#materialnew), [Material.SetShader](#materialsetshader), [Shader.GetParam](#shadergetparam), [Shader.Set](#shaderset), [Shader.Get](#shaderget)

---

## Shader.Set

**Purpose** — Alias of Shader.Param — sets a shader uniform.

**Syntax**

    Shader.Set(material, key, value)

**Parameters**

- `material`
- `key`
- `value`

**Description**

Alias of Shader.Param — sets a shader uniform. Use whichever name reads better in your code.

**Example**

    Shader.Set sprite.Material, "hit_flash", 1.0

**See Also** — [Material.New](#materialnew), [Material.SetShader](#materialsetshader), [Shader.Param](#shaderparam), [Shader.GetParam](#shadergetparam), [Shader.Get](#shaderget)

---

## show

**Purpose** — Makes this node visible.

**Syntax**

    show()

**Description**

Makes this node visible. Equivalent to setting [b]visible = True[/b].

**Example**

    show   ' make visible

**Godot Mapping** — [`CanvasItem.show()`](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem-method-show)

**See Also** — [visible](#command-reference), [hide](#hide), [modulate](#command-reference)

---

## Sin

**Purpose** — Returns the sine of an angle (in radians).

**Syntax**

    Sin(angle)

**Parameters**

- `angle`

**Description**

Returns the sine of an angle (in radians).

**Example**

    Dim y As Single = Sin(3.14159 / 2)  ' 1.0
    ' Oscillating motion
    y = Sin(time * 2.0) * amplitude

**See Also** — [Cos](#cos)

---

## Single

**Purpose** — A single-precision floating-point number (32-bit).

**Syntax**

    Dim varName As Single

**Parameters**

- `varName`

**Description**

A single-precision floating-point number (32-bit). Use for positions, speeds, etc.

**Example**

    Dim speed As Single = 5.5
    Dim gravity As Single = 9.8

**See Also** — [Integer](#integer), [Long](#long), [Double](#double), [String](#string), [Boolean](#boolean), [Variant](#variant), [Array](#array)

---

## Skeleton.Count

**Purpose** — Returns the number of bones in the skeleton.

**Syntax**

    Skeleton.Count(skeleton) As Long

**Parameters**

- `skeleton`

**Description**

Returns the number of bones in the skeleton.

**Example**

    For i = 0 To Skeleton.Count(skel) - 1
        Print Skeleton.Name(skel, i)
    Next

**See Also** — [Skeleton.Name](#skeletonname), [Skeleton.Reset](#skeletonreset), [Bone.Find](#bonefind), [Bone.Pos](#bonepos), [Bone.Rot](#bonerot), [Bone.Scale](#bonescale), [Bone.SetPos](#bonesetpos), [Bone.SetRot](#bonesetrot), [Bone.SetScale](#bonesetscale), [Bone.LookAt](#bonelookat)

---

## Skeleton.Name

**Purpose** — Returns the name of the bone at the given index.

**Syntax**

    Skeleton.Name(skeleton, idx) As String

**Parameters**

- `skeleton`
- `idx`

**Description**

Returns the name of the bone at the given index.

**Example**

    Print Skeleton.Name(skel, 0)

**See Also** — [Skeleton.Count](#skeletoncount), [Skeleton.Reset](#skeletonreset), [Bone.Find](#bonefind), [Bone.Pos](#bonepos), [Bone.Rot](#bonerot), [Bone.Scale](#bonescale), [Bone.SetPos](#bonesetpos), [Bone.SetRot](#bonesetrot), [Bone.SetScale](#bonesetscale), [Bone.LookAt](#bonelookat)

---

## Skeleton.Reset

**Purpose** — Resets all bones back to their rest pose.

**Syntax**

    Skeleton.Reset(skeleton)

**Parameters**

- `skeleton`

**Description**

Resets all bones back to their rest pose.

**Example**

    Skeleton.Reset character

**See Also** — [Skeleton.Count](#skeletoncount), [Skeleton.Name](#skeletonname), [Bone.Find](#bonefind), [Bone.Pos](#bonepos), [Bone.Rot](#bonerot), [Bone.Scale](#bonescale), [Bone.SetPos](#bonesetpos), [Bone.SetRot](#bonesetrot), [Bone.SetScale](#bonesetscale), [Bone.LookAt](#bonelookat)

---

## Slerp

**Purpose** — Spherical interpolation.

**Syntax**

    Slerp(a, b, t)

**Parameters**

- `a`
- `b`
- `t`

**Description**

Spherical interpolation. Smoothly blends between two Quaternions, Vector3s, or Vector2s by factor t (0..1). Like Lerp but preserves length/rotation rate — use for camera orbits, rotation interpolation, smooth aim.

**Example**

    ' Rotate halfway from current to target
    player.quaternion = Slerp(player.quaternion, targetRot, 0.1)

    ' Smooth aim direction
    aim = Slerp(aim, desiredAim, 0.2)

**See Also** — [Quaternion](#quaternion), [QuaternionFromEuler](#quaternionfromeuler), [Basis](#basis), [Transform2D](#transform2d), [Transform3D](#transform3d), [Plane](#plane), [AABB](#aabb)

---

## Sound.IsPlaying

**Purpose** — Returns True if the sound is currently playing.

**Syntax**

    Sound.IsPlaying(h) As Boolean

**Parameters**

- `h`

**Description**

Returns True if the sound is currently playing.

**Example**

    If Not Sound.IsPlaying(music) Then
        music = Sound.Play("res://song.ogg")
    End If

**See Also** — [Sound.Play](#soundplay), [Sound.Stop](#soundstop), [Sound.Pause](#soundpause), [Sound.Resume](#soundresume), [Sound.Seek](#soundseek), [Sound.Volume](#soundvolume), [Sound.Pitch](#soundpitch), [Sound.Position](#soundposition)

---

## Sound.Pause

**Purpose** — Pauses a sound without stopping it.

**Syntax**

    Sound.Pause(h)

**Parameters**

- `h`

**Description**

Pauses a sound without stopping it. Resume with Sound.Resume(h).

**Example**

    Sound.Pause music

**See Also** — [Sound.Play](#soundplay), [Sound.Stop](#soundstop), [Sound.Resume](#soundresume), [Sound.Seek](#soundseek), [Sound.Volume](#soundvolume), [Sound.Pitch](#soundpitch), [Sound.IsPlaying](#soundisplaying), [Sound.Position](#soundposition)

---

## Sound.Pitch

**Purpose** — Changes playback speed/pitch of a sound.

**Syntax**

    Sound.Pitch(scale, h)

**Parameters**

- `scale`
- `h`

**Description**

Changes playback speed/pitch of a sound. 1.0 = normal, 2.0 = double speed (one octave up), 0.5 = half speed (one octave down).

**Example**

    Sound.Pitch 1.2, music   ' slightly faster/higher

**See Also** — [Sound.Play](#soundplay), [Sound.Stop](#soundstop), [Sound.Pause](#soundpause), [Sound.Resume](#soundresume), [Sound.Seek](#soundseek), [Sound.Volume](#soundvolume), [Sound.IsPlaying](#soundisplaying), [Sound.Position](#soundposition)

---

## Sound.Play

**Purpose** — Plays a sound and returns a handle (Integer).

**Syntax**

    Sound.Play(path [, busName]) As Long

**Parameters**

- `path`
- `busName`

**Description**

Plays a sound and returns a handle (Integer). Save the handle if you want to stop, pause, change volume, or seek the sound later. Optional busName routes the sound through a named speaker/bus (default "Master").

**Example**

    ' Fire and forget
    Sound.Play "res://blast.wav"

    ' Keep a handle to control it later
    Dim music = Sound.Play("res://song.ogg", "Music")
    Sound.Volume 60, music

**See Also** — [Sound.Stop](#soundstop), [Sound.Pause](#soundpause), [Sound.Resume](#soundresume), [Sound.Seek](#soundseek), [Sound.Volume](#soundvolume), [Sound.Pitch](#soundpitch), [Sound.IsPlaying](#soundisplaying), [Sound.Position](#soundposition)

---

## Sound.Position

**Purpose** — Returns the current playback position in seconds.

**Syntax**

    Sound.Position(h) As Double

**Parameters**

- `h`

**Description**

Returns the current playback position in seconds.

**Example**

    Dim t = Sound.Position(music)
    Print "At " & Round(t, 1) & " seconds"

**See Also** — [Sound.Play](#soundplay), [Sound.Stop](#soundstop), [Sound.Pause](#soundpause), [Sound.Resume](#soundresume), [Sound.Seek](#soundseek), [Sound.Volume](#soundvolume), [Sound.Pitch](#soundpitch), [Sound.IsPlaying](#soundisplaying)

---

## Sound.Resume

**Purpose** — Resumes a paused sound from where it left off.

**Syntax**

    Sound.Resume(h)

**Parameters**

- `h`

**Description**

Resumes a paused sound from where it left off.

**Example**

    Sound.Resume music

**See Also** — [Sound.Play](#soundplay), [Sound.Stop](#soundstop), [Sound.Pause](#soundpause), [Sound.Seek](#soundseek), [Sound.Volume](#soundvolume), [Sound.Pitch](#soundpitch), [Sound.IsPlaying](#soundisplaying), [Sound.Position](#soundposition)

---

## Sound.Seek

**Purpose** — Jumps to a position (in seconds) inside a playing sound.

**Syntax**

    Sound.Seek(h, seconds)

**Parameters**

- `h`
- `seconds`

**Description**

Jumps to a position (in seconds) inside a playing sound. Useful for skipping intros or implementing scrub bars.

**Example**

    Sound.Seek music, 30.0   ' jump to 30 seconds in

**See Also** — [Sound.Play](#soundplay), [Sound.Stop](#soundstop), [Sound.Pause](#soundpause), [Sound.Resume](#soundresume), [Sound.Volume](#soundvolume), [Sound.Pitch](#soundpitch), [Sound.IsPlaying](#soundisplaying), [Sound.Position](#soundposition)

---

## Sound.Stop

**Purpose** — Stops a sound that was started with Sound.Play and frees it.

**Syntax**

    Sound.Stop(h)

**Parameters**

- `h`

**Description**

Stops a sound that was started with Sound.Play and frees it.

**Example**

    Sound.Stop music

**See Also** — [Sound.Play](#soundplay), [Sound.Pause](#soundpause), [Sound.Resume](#soundresume), [Sound.Seek](#soundseek), [Sound.Volume](#soundvolume), [Sound.Pitch](#soundpitch), [Sound.IsPlaying](#soundisplaying), [Sound.Position](#soundposition)

---

## Sound.Volume

**Purpose** — Sets volume in percent (0..100).

**Syntax**

    Sound.Volume(pct [, h])

**Parameters**

- `pct`
- `h`

**Description**

Sets volume in percent (0..100). With a handle, changes that one sound. Without a handle, sets the master speaker volume — the global volume knob.

**Example**

    Sound.Volume 75           ' master at 75%
    Sound.Volume 50, music    ' just this song at 50%

**See Also** — [Sound.Play](#soundplay), [Sound.Stop](#soundstop), [Sound.Pause](#soundpause), [Sound.Resume](#soundresume), [Sound.Seek](#soundseek), [Sound.Pitch](#soundpitch), [Sound.IsPlaying](#soundisplaying), [Sound.Position](#soundposition)

---

## Speaker.Bus

**Purpose** — Alias of the Speaker namespace — same verbs (Volume, Mute, Solo, etc.) just spelled `Speaker.Bus.Volume`.

**Syntax**

    Speaker.Bus

**Description**

Alias of the Speaker namespace — same verbs (Volume, Mute, Solo, etc.) just spelled `Speaker.Bus.Volume`. Provided for readers who think "bus" first.

**Example**

    Speaker.Bus.Volume "Master", 75

**See Also** — [Speaker.Volume](#speakervolume), [Speaker.Mute](#speakermute), [Speaker.IsMuted](#speakerismuted), [Speaker.Solo](#speakersolo), [Speaker.Exists](#speakerexists), [Speaker.Count](#speakercount), [Speaker.Name](#speakername)

---

## Speaker.Count

**Purpose** — Returns the number of configured speakers/buses.

**Syntax**

    Speaker.Count() As Integer

**Description**

Returns the number of configured speakers/buses.

**Example**

    For i = 0 To Speaker.Count() - 1
        Print Speaker.Name(i)
    Next

**See Also** — [Speaker.Volume](#speakervolume), [Speaker.Mute](#speakermute), [Speaker.IsMuted](#speakerismuted), [Speaker.Solo](#speakersolo), [Speaker.Exists](#speakerexists), [Speaker.Name](#speakername), [Speaker.Bus](#speakerbus)

---

## Speaker.Exists

**Purpose** — Returns True if a speaker with this name exists in Project Settings → Audio → Buses.

**Syntax**

    Speaker.Exists(name) As Boolean

**Parameters**

- `name`

**Description**

Returns True if a speaker with this name exists in Project Settings → Audio → Buses.

**Example**

    If Speaker.Exists("Music") Then
        Speaker.Volume "Music", 50
    End If

**See Also** — [Speaker.Volume](#speakervolume), [Speaker.Mute](#speakermute), [Speaker.IsMuted](#speakerismuted), [Speaker.Solo](#speakersolo), [Speaker.Count](#speakercount), [Speaker.Name](#speakername), [Speaker.Bus](#speakerbus)

---

## Speaker.IsMuted

**Purpose** — Returns True if the named speaker is currently muted.

**Syntax**

    Speaker.IsMuted(name) As Boolean

**Parameters**

- `name`

**Description**

Returns True if the named speaker is currently muted.

**Example**

    If Speaker.IsMuted("Master") Then
        Print "Audio is off"
    End If

**See Also** — [Speaker.Volume](#speakervolume), [Speaker.Mute](#speakermute), [Speaker.Solo](#speakersolo), [Speaker.Exists](#speakerexists), [Speaker.Count](#speakercount), [Speaker.Name](#speakername), [Speaker.Bus](#speakerbus)

---

## Speaker.Mute

**Purpose** — Mutes or unmutes a speaker.

**Syntax**

    Speaker.Mute(name, muted)

**Parameters**

- `name`
- `muted`

**Description**

Mutes or unmutes a speaker. Pass True to mute, False to unmute.

**Example**

    Speaker.Mute "Music", True     ' silence music
    Speaker.Mute "Music", False    ' unmute

**See Also** — [Speaker.Volume](#speakervolume), [Speaker.IsMuted](#speakerismuted), [Speaker.Solo](#speakersolo), [Speaker.Exists](#speakerexists), [Speaker.Count](#speakercount), [Speaker.Name](#speakername), [Speaker.Bus](#speakerbus)

---

## Speaker.Name

**Purpose** — Returns the name of the speaker at the given index (0-based).

**Syntax**

    Speaker.Name(index) As String

**Parameters**

- `index`

**Description**

Returns the name of the speaker at the given index (0-based).

**Example**

    Print Speaker.Name(0)   ' usually "Master"

**See Also** — [Speaker.Volume](#speakervolume), [Speaker.Mute](#speakermute), [Speaker.IsMuted](#speakerismuted), [Speaker.Solo](#speakersolo), [Speaker.Exists](#speakerexists), [Speaker.Count](#speakercount), [Speaker.Bus](#speakerbus)

---

## Speaker.Solo

**Purpose** — Solos a speaker so only it is audible (others silent).

**Syntax**

    Speaker.Solo(name, soloed)

**Parameters**

- `name`
- `soloed`

**Description**

Solos a speaker so only it is audible (others silent). Pass False to unsolo.

**Example**

    Speaker.Solo "SFX", True   ' only sound effects audible

**See Also** — [Speaker.Volume](#speakervolume), [Speaker.Mute](#speakermute), [Speaker.IsMuted](#speakerismuted), [Speaker.Exists](#speakerexists), [Speaker.Count](#speakercount), [Speaker.Name](#speakername), [Speaker.Bus](#speakerbus)

---

## Speaker.Volume

**Purpose** — Get or set a speaker's volume in percent (0..100).

**Syntax**

    Speaker.Volume(name [, pct])

**Parameters**

- `name`
- `pct`

**Description**

Get or set a speaker's volume in percent (0..100). With one argument, returns current volume. With two, sets it. Works on any bus defined in Project Settings → Audio.

**Example**

    ' Build a music slider
    Speaker.Volume "Music", musicSlider.Value

    ' Read current
    lbl.Text = "Music: " & Round(Speaker.Volume("Music")) & "%"

**See Also** — [Speaker.Mute](#speakermute), [Speaker.IsMuted](#speakerismuted), [Speaker.Solo](#speakersolo), [Speaker.Exists](#speakerexists), [Speaker.Count](#speakercount), [Speaker.Name](#speakername), [Speaker.Bus](#speakerbus)

---

## SoundGen.Open

**Purpose** — Create a real-time PCM audio generator and start playback.

**Syntax**

    SoundGen.Open(mix_rate As Single, buffer_length As Single) As Long

**Parameters**

- `mix_rate` — samples per second (typically `44100.0`)
- `buffer_length` — ring-buffer size in seconds (`0.05`–`0.2` recommended; smaller = lower latency, higher CPU risk)

**Description**

Creates an `AudioStreamGenerator` resource and an `AudioStreamPlayer` node, attaches them to the current script's owner node, and starts playback. Returns a handle (`Long`) that must be passed to all other `SoundGen.*` verbs.

Declare the handle at module level (not inside a Sub) so it persists across frames.

**Example**

    Dim hum As Long

    Sub _Ready()
        hum = SoundGen.Open(44100.0, 0.1)
    End Sub

    Sub _Process(delta)
        Dim n As Integer = SoundGen.Available(hum)
        For i = 0 To n - 1
            phase += 440.0 / 44100.0 * 6.28318
            SoundGen.PushMono hum, Sin(phase) * 0.1
        Next
    End Sub

    Sub _ExitTree()
        SoundGen.Close hum
    End Sub

**See Also** — [SoundGen.Close](#soundgenclose), [SoundGen.Available](#soundgenavailable), [SoundGen.PushMono](#soundgenpushmono), [SoundGen.PushStereo](#soundgenpushstereo)

---

## SoundGen.Close

**Purpose** — Stop and free a real-time audio generator.

**Syntax**

    SoundGen.Close(h As Long)

**Parameters**

- `h` — handle returned by `SoundGen.Open`

**Description**

Stops playback and queues the underlying `AudioStreamPlayer` for deletion. Call this in `_ExitTree` or when switching eras to avoid orphaned audio nodes.

**Example**

    Sub _ExitTree()
        SoundGen.Close hum
    End Sub

**See Also** — [SoundGen.Open](#soundgenopen), [SoundGen.Available](#soundgenavailable), [SoundGen.PushMono](#soundgenpushmono), [SoundGen.PushStereo](#soundgenpushstereo)

---

## SoundGen.Available

**Purpose** — Number of stereo frames the buffer can accept right now.

**Syntax**

    SoundGen.Available(h As Long) As Integer

**Parameters**

- `h` — handle returned by `SoundGen.Open`

**Description**

Returns how many frames can be pushed to the buffer without blocking. Call once per `_Process()` and push exactly that many frames to keep the audio stream fed without overflow.

If you push fewer frames the buffer will underrun and you'll hear dropouts. If you push more the extras are dropped.

**Example**

    Dim n As Integer = SoundGen.Available(hum)
    For i = 0 To n - 1
        SoundGen.PushMono hum, Sin(phase) * 0.05
        phase += freq / 44100.0 * 6.28318
    Next

**See Also** — [SoundGen.Open](#soundgenopen), [SoundGen.PushMono](#soundgenpushmono), [SoundGen.PushStereo](#soundgenpushstereo)

---

## SoundGen.PushMono

**Purpose** — Push one mono PCM sample into the generator buffer.

**Syntax**

    SoundGen.PushMono(h As Long, sample As Single)

**Parameters**

- `h` — handle returned by `SoundGen.Open`
- `sample` — PCM value in the range `−1.0` to `+1.0`; values outside this range clip

**Description**

Pushes a single mono sample as a stereo frame with L = R = `sample`. Call inside a `For` loop after checking `SoundGen.Available(h)`.

**Example**

    ' 440 Hz sine wave
    phase += 440.0 / 44100.0 * 6.28318
    SoundGen.PushMono hum, Sin(phase) * 0.12

**See Also** — [SoundGen.Open](#soundgenopen), [SoundGen.Available](#soundgenavailable), [SoundGen.PushStereo](#soundgenpushstereo)

---

## SoundGen.PushStereo

**Purpose** — Push one stereo PCM frame into the generator buffer.

**Syntax**

    SoundGen.PushStereo(h As Long, left As Single, right As Single)

**Parameters**

- `h` — handle returned by `SoundGen.Open`
- `left` — left-channel sample (`−1.0` to `+1.0`)
- `right` — right-channel sample (`−1.0` to `+1.0`)

**Description**

Pushes a stereo frame with independent L and R samples. Use for panning effects or any synthesis where the two channels differ.

**Example**

    ' Ping-pong delay — alternate sides
    SoundGen.PushStereo hum, leftSample, rightSample

**See Also** — [SoundGen.Open](#soundgenopen), [SoundGen.Available](#soundgenavailable), [SoundGen.PushMono](#soundgenpushmono)

---

## Spin

**Purpose** — Rotational impulse.

**Syntax**

    Spin(body, amount)

**Parameters**

- `body`
- `amount`

**Description**

Rotational impulse. Plain-English alias for Physics.Torque.

**Example**

    Spin coin, 12.5

**See Also** — [Physics.Gravity](#physicsgravity), [Physics.GravityV2](#physicsgravityv2), [Physics.GravityV3](#physicsgravityv3), [Physics.Bounce](#physicsbounce), [Physics.Force](#physicsforce), [Physics.Impulse](#physicsimpulse), [Physics.Torque](#physicstorque), [Physics.Ray](#physicsray), [Push](#push), [Pull](#pull)

---

## Split

**Purpose** — Splits a string into an array of substrings based on a delimiter.

**Syntax**

    Split(string, delimiter)

**Parameters**

- `string`
- `delimiter`

**Description**

Splits a string into an array of substrings based on a delimiter.

**Example**

    Dim parts() As String
    parts = Split("A,B,C", ",")
    Print parts(0)  ' "A"
    Print parts(1)  ' "B"

**See Also** — [Left](#left), [Right](#right), [Mid](#mid), [Trim](#trim), [LCase](#lcase), [UCase](#ucase), [Len](#len), [InStr](#instr), [Replace](#replace), [Join](#join), [Format](#format)

---

## Sqr

**Purpose** — Returns the square root of a number.

**Syntax**

    Sqr(number)

**Parameters**

- `number`

**Description**

Returns the square root of a number.

**Example**

    Print Sqr(16)   ' 4
    Print Sqr(2.0)  ' 1.41421...

**See Also** — [Abs](#abs), [Int](#int), [Rnd](#rnd), [Randomize](#randomize), [RandRange](#randrange), [Round](#round), [Clamp](#clamp), [Lerp](#lerp), [Mod](#mod)

---

## Static

**Purpose** — Declares a variable that retains its value between procedure calls.

**Syntax**

    Static variableName As DataType

**Parameters**

- `variableName`

**Description**

Declares a variable that retains its value between procedure calls. Unlike Dim, static variables are not reset when the procedure exits.

**Example**

    Sub CountCalls()
        Static callCount As Integer
        callCount = callCount + 1
        Print "Called " & callCount & " times"
    End Sub

**See Also** — [Dim](#dim), [Private](#private), [Public](#public), [Global](#global), [Const](#const), [ReDim](#redim), [Type](#type)

---

## Steps.Reset

**Purpose** — Resets the step counter to zero.

**Syntax**

    Steps.Reset()

**Description**

Resets the step counter to zero. Plugin-dependent.

**Platform support**

- ✅ Android: uses `VGAndroidPlugin` pedometer bridge
- ⚠️ Windows/macOS/Linux/Web: no-op

**Example**

    Steps.Reset()

**See Also** — [Steps.Today](#stepstoday), [Steps.Total](#stepstotal)

---

## Steps.Today

**Purpose** — Returns step count for today (midnight rollover).

**Syntax**

    Steps.Today() As Long

**Description**

Returns step count for today (midnight rollover). Stub returns 0.

**Platform support**

- ✅ Android: uses `VGAndroidPlugin` pedometer bridge
- ⚠️ Windows/macOS/Linux/Web: returns `0`

**Example**

    goalProgress = Steps.Today() / 10000.0

**See Also** — [Steps.Total](#stepstotal), [Steps.Reset](#stepsreset)

---

## Steps.Total

**Purpose** — Returns total step count since boot (or since plugin install).

**Syntax**

    Steps.Total() As Long

**Description**

Returns total step count since boot (or since plugin install). Stub returns 0.

**Platform support**

- ✅ Android: uses `VGAndroidPlugin` pedometer bridge
- ⚠️ Windows/macOS/Linux/Web: returns `0`

**Example**

    Print "Today you walked " & Steps.Total() & " steps"

**See Also** — [Steps.Today](#stepstoday), [Steps.Reset](#stepsreset)

---

## Str

**Purpose** — Converts a number to its string representation.

**Syntax**

    Str(number)

**Parameters**

- `number`

**Description**

Converts a number to its string representation.

**Example**

    Dim s As String = Str(42)  ' " 42" (note leading space)
    Print "Score: " & Str(score)

**See Also** — [CInt](#cint), [CStr](#cstr), [Val](#val), [Int](#int)

---

## String

**Purpose** — A text string of any length.

**Syntax**

    Dim varName As String [= "text"]

**Parameters**

- `varName`

**Description**

A text string of any length. Concatenate with & or + operator.

**Example**

    Dim name As String = "Player 1"
    Dim greeting As String
    greeting = "Hello, " & name & "!"

**See Also** — [Integer](#integer), [Long](#long), [Single](#single), [Double](#double), [Boolean](#boolean), [Variant](#variant), [Array](#array)

---

## Sub

**Purpose** — Declares a subroutine — a procedure that performs an action but does not return a value.

**Syntax**

    [Public|Private] Sub procedureName([parameters])
        statements
    End Sub

**Description**

Declares a subroutine — a procedure that performs an action but does not return a value. Event handlers are Subs named ObjectName_EventName.

**Example**

    Sub btnStart_Click()
        StartGame()
    End Sub

    Private Sub ResetScore()
        score = 0
        UpdateDisplay()
    End Sub

**See Also** — [Function](#function), [End Sub](#end-sub), [End Function](#end-function), [Call](#call), [Return](#return), [ByRef](#byref), [ByVal](#byval), [Optional](#optional), [Lambda](#lambda)

---


### T

## TextureHeight

**Purpose** — Returns the height of a Texture2D in pixels.

**Syntax**

    TextureHeight(texture) As Integer

**Parameters**

- `texture`

**Description**

Returns the height of a Texture2D in pixels.

**Example**

    Dim tex = CreateTexture(256, 128)
    Print TextureWidth(tex)    ' 256
    Print TextureHeight(tex)   ' 128

**See Also** — [ImageToTexture](#imagetotexture), [CreateTexture](#createtexture), [UpdateTexture](#updatetexture), [GetTextureImage](#gettextureimage), [TextureWidth](#texturewidth)

---

## TextureWidth

**Purpose** — Returns the width of a Texture2D in pixels.

**Syntax**

    TextureWidth(texture) As Integer

**Parameters**

- `texture`

**Description**

Returns the width of a Texture2D in pixels.

**Example**

    Dim tex = LoadPicture("res://icon.png")
    Print TextureWidth(tex)   ' e.g. 128
    Print TextureHeight(tex)  ' e.g. 128

**See Also** — [ImageToTexture](#imagetotexture), [CreateTexture](#createtexture), [UpdateTexture](#updatetexture), [GetTextureImage](#gettextureimage), [TextureHeight](#textureheight)

---

## Theme.Color

**Purpose** — Reads a theme color override (or falls back to the inherited theme).

**Syntax**

    Theme.Color(control, key) As Color

**Parameters**

- `control`
- `key`

**Description**

Reads a theme color override (or falls back to the inherited theme). Common keys: "font_color", "font_disabled_color".

**Example**

    Print Theme.Color(myLabel, "font_color")

**See Also** — [Theme.Constant](#themeconstant), [Theme.Font](#themefont), [Theme.SetColor](#themesetcolor), [Theme.SetConstant](#themesetconstant), [Theme.SetFont](#themesetfont), [Theme.SetFontSize](#themesetfontsize), [Theme.SetStyle](#themesetstyle), [Theme.Get](#themeget), [Theme.Set](#themeset)

---

## Theme.Constant

**Purpose** — Reads a theme constant (e.g.

**Syntax**

    Theme.Constant(control, key) As Long

**Parameters**

- `control`
- `key`

**Description**

Reads a theme constant (e.g. "separation", "margin_left").

**Example**

    Print Theme.Constant(hbox, "separation")

**See Also** — [Theme.Color](#themecolor), [Theme.Font](#themefont), [Theme.SetColor](#themesetcolor), [Theme.SetConstant](#themesetconstant), [Theme.SetFont](#themesetfont), [Theme.SetFontSize](#themesetfontsize), [Theme.SetStyle](#themesetstyle), [Theme.Get](#themeget), [Theme.Set](#themeset)

---

## Theme.Font

**Purpose** — Reads the font assigned to a control for the given key (e.g.

**Syntax**

    Theme.Font(control, key) As Font

**Parameters**

- `control`
- `key`

**Description**

Reads the font assigned to a control for the given key (e.g. "font").

**Example**

    Dim f = Theme.Font(myLabel, "font")

**See Also** — [Theme.Color](#themecolor), [Theme.Constant](#themeconstant), [Theme.SetColor](#themesetcolor), [Theme.SetConstant](#themesetconstant), [Theme.SetFont](#themesetfont), [Theme.SetFontSize](#themesetfontsize), [Theme.SetStyle](#themesetstyle), [Theme.Get](#themeget), [Theme.Set](#themeset)

---

## Theme.Get

**Purpose** — Generic theme-item reader.

**Syntax**

    Theme.Get(control, kind, name) As Variant

**Parameters**

- `control`
- `kind`
- `name`

**Description**

Generic theme-item reader. `kind` is "color" | "constant" | "font" | "font_size" | "style". Returns the inherited value if the control has no override.

**Example**

    Dim panelBg = Theme.Get(myPanel, "color", "bg_color")

**See Also** — [Theme.Color](#themecolor), [Theme.Constant](#themeconstant), [Theme.Font](#themefont), [Theme.SetColor](#themesetcolor), [Theme.SetConstant](#themesetconstant), [Theme.SetFont](#themesetfont), [Theme.SetFontSize](#themesetfontsize), [Theme.SetStyle](#themesetstyle), [Theme.Set](#themeset)

---

## Theme.Set

**Purpose** — Generic theme-item writer.

**Syntax**

    Theme.Set(control, kind, name, value)

**Parameters**

- `control`
- `kind`
- `name`
- `value`

**Description**

Generic theme-item writer. Same kind values as Theme.Get. Convenience wrapper around the typed Theme.SetColor / SetConstant / SetFont / SetFontSize / SetStyle verbs.

**Example**

    Theme.Set lblTitle, "color", "font_color", RGB(255, 200, 0)
    Theme.Set lblTitle, "font_size", "font_size", 32

**See Also** — [Theme.Color](#themecolor), [Theme.Constant](#themeconstant), [Theme.Font](#themefont), [Theme.SetColor](#themesetcolor), [Theme.SetConstant](#themesetconstant), [Theme.SetFont](#themesetfont), [Theme.SetFontSize](#themesetfontsize), [Theme.SetStyle](#themesetstyle), [Theme.Get](#themeget)

---

## Theme.SetColor

**Purpose** — Overrides a theme color on a single control.

**Syntax**

    Theme.SetColor(control, key, color)

**Parameters**

- `control`
- `key`
- `color`

**Description**

Overrides a theme color on a single control. Persists until the control is freed.

**Example**

    Theme.SetColor warningLabel, "font_color", Color.Red

**See Also** — [Theme.Color](#themecolor), [Theme.Constant](#themeconstant), [Theme.Font](#themefont), [Theme.SetConstant](#themesetconstant), [Theme.SetFont](#themesetfont), [Theme.SetFontSize](#themesetfontsize), [Theme.SetStyle](#themesetstyle), [Theme.Get](#themeget), [Theme.Set](#themeset)

---

## Theme.SetConstant

**Purpose** — Overrides a theme integer constant (margins, spacings, etc.).

**Syntax**

    Theme.SetConstant(control, key, value)

**Parameters**

- `control`
- `key`
- `value`

**Description**

Overrides a theme integer constant (margins, spacings, etc.).

**Example**

    Theme.SetConstant hbox, "separation", 20

**See Also** — [Theme.Color](#themecolor), [Theme.Constant](#themeconstant), [Theme.Font](#themefont), [Theme.SetColor](#themesetcolor), [Theme.SetFont](#themesetfont), [Theme.SetFontSize](#themesetfontsize), [Theme.SetStyle](#themesetstyle), [Theme.Get](#themeget), [Theme.Set](#themeset)

---

## Theme.SetFont

**Purpose** — Overrides the font on a single control.

**Syntax**

    Theme.SetFont(control, key, font)

**Parameters**

- `control`
- `key`
- `font`

**Description**

Overrides the font on a single control. font is a Font resource.

**Example**

    Theme.SetFont titleLabel, "font", myCustomFont

**See Also** — [Theme.Color](#themecolor), [Theme.Constant](#themeconstant), [Theme.Font](#themefont), [Theme.SetColor](#themesetcolor), [Theme.SetConstant](#themesetconstant), [Theme.SetFontSize](#themesetfontsize), [Theme.SetStyle](#themesetstyle), [Theme.Get](#themeget), [Theme.Set](#themeset)

---

## Theme.SetFontSize

**Purpose** — Overrides the font size for a control.

**Syntax**

    Theme.SetFontSize(control, key, size)

**Parameters**

- `control`
- `key`
- `size`

**Description**

Overrides the font size for a control. key is usually "font_size".

**Example**

    Theme.SetFontSize titleLabel, "font_size", 48

**See Also** — [Theme.Color](#themecolor), [Theme.Constant](#themeconstant), [Theme.Font](#themefont), [Theme.SetColor](#themesetcolor), [Theme.SetConstant](#themesetconstant), [Theme.SetFont](#themesetfont), [Theme.SetStyle](#themesetstyle), [Theme.Get](#themeget), [Theme.Set](#themeset)

---

## Theme.SetStyle

**Purpose** — Overrides a theme StyleBox (backgrounds, borders).

**Syntax**

    Theme.SetStyle(control, key, stylebox)

**Parameters**

- `control`
- `key`
- `stylebox`

**Description**

Overrides a theme StyleBox (backgrounds, borders). Pass a StyleBox resource.

**Example**

    Theme.SetStyle myPanel, "panel", customStyleBox

**See Also** — [Theme.Color](#themecolor), [Theme.Constant](#themeconstant), [Theme.Font](#themefont), [Theme.SetColor](#themesetcolor), [Theme.SetConstant](#themesetconstant), [Theme.SetFont](#themesetfont), [Theme.SetFontSize](#themesetfontsize), [Theme.Get](#themeget), [Theme.Set](#themeset)

---

## Then

**Purpose** — Part of the If statement.

**Syntax**

    If condition Then statements

**Parameters**

- `condition Then statements`

**Description**

Part of the If statement. Follows the condition and precedes the code to execute.

**Example**

    If health <= 0 Then GameOver()
    If x > 10 Then x = 10

**See Also** — [If](#if), [Else](#else), [ElseIf](#elseif), [End If](#end-if), [Select Case](#select-case), [IIf](#iif)

---

## Throw

**Purpose** — Raises an exception.

**Syntax**

    Throw exceptionObject
    Throw "error message"

**Description**

Raises an exception. Can throw a string message or an Exception object.

**Example**

    If amount < 0 Then
        Throw "Amount cannot be negative"
    End If

    Sub Validate(age As Integer)
        If age < 0 Or age > 150 Then Throw "Invalid age: " & age
    End Sub

**See Also** — [On Error](#on-error), [Try](#try), [Catch](#catch), [Finally](#finally)

---

## Transform2D

**Purpose** — 2D transform (rotation + scale + skew + position).

**Syntax**

    Transform2D() | Transform2D(rotationRad, origin) | Transform2D(rotation, scale, skew, origin)

**Description**

2D transform (rotation + scale + skew + position). Defaults to identity. Useful for positioning Node2D children procedurally. Methods .Translated(v), .Rotated(rad), .Scaled(v), .AffineInverse() return new Transform2Ds.

**Example**

    Dim t = Transform2D(0.785, Vector2(100, 50))  ' 45 deg, at (100,50)
    Dim t2 = t.Translated(Vector2(10, 0)).Rotated(0.1)

**See Also** — [Quaternion](#quaternion), [QuaternionFromEuler](#quaternionfromeuler), [Basis](#basis), [Transform3D](#transform3d), [Plane](#plane), [AABB](#aabb), [Slerp](#slerp)

---

## Transform3D

**Purpose** — 3D transform combining a Basis (rotation+scale) with an origin Vector3.

**Syntax**

    Transform3D() | Transform3D(basis, origin)

**Description**

3D transform combining a Basis (rotation+scale) with an origin Vector3. Used for positioning Node3Ds. .LookingAt(target, up) is the easy way to face a point.

**Example**

    Dim tr = Transform3D(Basis(), Vector3(0, 2, 5))
    cam.transform = tr.LookingAt(player.position, Vector3(0, 1, 0))

**See Also** — [Quaternion](#quaternion), [QuaternionFromEuler](#quaternionfromeuler), [Basis](#basis), [Transform2D](#transform2d), [Plane](#plane), [AABB](#aabb), [Slerp](#slerp)

---

## Trim

**Purpose** — Removes leading and trailing spaces from a string.

**Syntax**

    Trim(string)

**Parameters**

- `string`

**Description**

Removes leading and trailing spaces from a string.

**Example**

    Print Trim("  Hello  ")  ' "Hello"

**See Also** — [Left](#left), [Right](#right), [Mid](#mid), [LCase](#lcase), [UCase](#ucase), [Len](#len), [InStr](#instr), [Replace](#replace), [Split](#split), [Join](#join), [Format](#format)

---

## True

**Purpose** — Boolean literal representing a true/on state.

**Syntax**

    True

**Description**

Boolean literal representing a true/on state.

**Example**

    Dim isReady As Boolean = True
    Visible = True

**See Also** — [False](#false), [Nothing](#nothing)

---

## Try

**Purpose** — Structured exception handling.

**Syntax**

    Try
        statements
    Catch [ex As Exception]
        error handling
    [Finally]
        cleanup
    End Try

**Description**

Structured exception handling. Code in Try is protected; if an error occurs, execution jumps to Catch. Finally always executes.

**Example**

    Try
        Dim result As Integer = 100 / divisor
        Print result
    Catch ex As Exception
        Print "Error: " & ex.Message
    Finally
        Print "Done"
    End Try

**See Also** — [On Error](#on-error), [Catch](#catch), [Finally](#finally), [Throw](#throw)

---

## Type

**Purpose** — Declares a user-defined type (structure) that groups related variables together.

**Syntax**

    Type TypeName
        field1 As DataType
        field2 As DataType
    End Type

**Description**

Declares a user-defined type (structure) that groups related variables together.

**Example**

    Type Vector2D
        X As Single
        Y As Single
    End Type

    Dim pos As Vector2D
    pos.X = 100
    pos.Y = 200

**See Also** — [Dim](#dim), [Private](#private), [Public](#public), [Global](#global), [Static](#static), [Const](#const), [ReDim](#redim)

---


### U

## UBound

**Purpose** — Returns the highest valid index of an array.

**Syntax**

    UBound(arrayName [, dimension])

**Parameters**

- `arrayName`
- `dimension`

**Description**

Returns the highest valid index of an array.

**Example**

    Dim arr(10) As Integer
    Print UBound(arr)  ' 10

    For i = 0 To UBound(arr)
        arr(i) = i * 2
    Next

**See Also** — [Array](#array), [ReDim](#redim), [LBound](#lbound)

---

## UCase

**Purpose** — Converts a string to uppercase.

**Syntax**

    UCase(string)

**Parameters**

- `string`

**Description**

Converts a string to uppercase.

**Example**

    Print UCase("hello")  ' "HELLO"

**See Also** — [Left](#left), [Right](#right), [Mid](#mid), [Trim](#trim), [LCase](#lcase), [Len](#len), [InStr](#instr), [Replace](#replace), [Split](#split), [Join](#join), [Format](#format)

---

## Until

**Purpose** — Loop continuation condition — the loop repeats until the condition becomes True.

**Syntax**

    Do ... Loop Until condition
    Do Until condition ... Loop

**Description**

Loop continuation condition — the loop repeats until the condition becomes True.

**Example**

    Do
        tries = tries + 1
    Loop Until success Or tries > 10

**See Also** — [Do](#do), [Loop](#loop), [While](#while), [Wend](#wend), [Exit](#exit)

---

## UpdateTexture

**Purpose** — Pushes updated Image pixel data to an existing ImageTexture.

**Syntax**

    UpdateTexture texture, image

**Parameters**

- `texture`
- `image`

**Description**

Pushes updated Image pixel data to an existing ImageTexture. Call this after modifying pixels with SetImagePixel, FillImage, or BlitImage to make the changes visible on screen. This is an essential step in the Image → Texture rendering pipeline.

**Example**

    Dim img = CreateImage(320, 240)
    Dim tex = CreateTexture(img)

    ' Modify pixels
    For x = 0 To 319
        SetImagePixel img, x, 120, Color.Red
    Next

    ' IMPORTANT: Push to GPU
    UpdateTexture tex, img

    ' Now DrawTexture will show the changes
    Sub _Draw()
        DrawTexture tex, 0, 0
    End Sub

**See Also** — [ImageToTexture](#imagetotexture), [CreateTexture](#createtexture), [GetTextureImage](#gettextureimage), [TextureWidth](#texturewidth), [TextureHeight](#textureheight)

---

## Using

**Purpose** — Ensures a resource is properly disposed/cleaned up when the block exits.

**Syntax**

    Using resource = expression
        statements
    End Using

**Description**

Ensures a resource is properly disposed/cleaned up when the block exits.

**Example**

    Using conn = OpenDatabase("game.db")
        conn.Execute "INSERT INTO scores VALUES(" & score & ")"
    End Using  ' Connection automatically closed

**See Also** — [With](#with), [End With](#end-with)

---


### V

## Val

**Purpose** — Converts the numeric portion of a string to a number.

**Syntax**

    Val(string)

**Parameters**

- `string`

**Description**

Converts the numeric portion of a string to a number.

**Example**

    Dim n As Integer = Val("42 cats")  ' 42
    Dim d As Double = Val("3.14")      ' 3.14

**See Also** — [CInt](#cint), [CStr](#cstr), [Str](#str), [Int](#int)

---

## Variant

**Purpose** — A flexible type that can hold any value — integer, string, object, array, etc.

**Syntax**

    Dim varName As Variant
    Dim varName  ' Also Variant by default

**Description**

A flexible type that can hold any value — integer, string, object, array, etc. Default type when no As clause is given.

**Example**

    Dim value As Variant
    value = 42
    value = "Hello"
    value = True

**See Also** — [Integer](#integer), [Long](#long), [Single](#single), [Double](#double), [String](#string), [Boolean](#boolean), [Array](#array)

---

## Vibrate

**Purpose** — Vibrates the device for the given milliseconds.

**Syntax**

    Vibrate ms [, amplitude]

**Parameters**

- `ms`
- `amplitude`

**Description**

Vibrates the device for the given milliseconds. Amplitude is 0.0–1.0 (default = full). No-op on desktop.

**Example**

    Vibrate 100           ' short buzz
    Vibrate 500, 0.3      ' half-second gentle

---

## Video.IsPlaying

**Purpose** — Returns True if the video is currently playing.

**Syntax**

    Video.IsPlaying(player) As Boolean

**Parameters**

- `player`

**Description**

Returns True if the video is currently playing.

**Example**

    If Not Video.IsPlaying(introVid) Then ShowMenu()

**See Also** — [Video.Play](#videoplay), [Video.Stop](#videostop), [Video.Pause](#videopause), [Video.Resume](#videoresume), [Video.Seek](#videoseek), [Video.Position](#videoposition), [Video.Length](#videolength), [Video.Volume](#videovolume)

---

## Video.Length

**Purpose** — Returns video length in seconds.

**Syntax**

    Video.Length(player) As Double

**Parameters**

- `player`

**Description**

Returns video length in seconds. Returns 0 if the stream doesn't report a length.

**Example**

    Print "Duration: " & Video.Length(introVid)

**See Also** — [Video.Play](#videoplay), [Video.Stop](#videostop), [Video.Pause](#videopause), [Video.Resume](#videoresume), [Video.Seek](#videoseek), [Video.Position](#videoposition), [Video.IsPlaying](#videoisplaying), [Video.Volume](#videovolume)

---

## Video.Pause

**Purpose** — Pauses without resetting position.

**Syntax**

    Video.Pause(player)

**Parameters**

- `player`

**Description**

Pauses without resetting position. Resume with Video.Resume.

**Example**

    Video.Pause introVid

**See Also** — [Video.Play](#videoplay), [Video.Stop](#videostop), [Video.Resume](#videoresume), [Video.Seek](#videoseek), [Video.Position](#videoposition), [Video.Length](#videolength), [Video.IsPlaying](#videoisplaying), [Video.Volume](#videovolume)

---

## Video.Play

**Purpose** — Starts video playback.

**Syntax**

    Video.Play(player)

**Parameters**

- `player`

**Description**

Starts video playback.

**Example**

    Video.Play introVid

**See Also** — [Video.Stop](#videostop), [Video.Pause](#videopause), [Video.Resume](#videoresume), [Video.Seek](#videoseek), [Video.Position](#videoposition), [Video.Length](#videolength), [Video.IsPlaying](#videoisplaying), [Video.Volume](#videovolume)

---

## Video.Position

**Purpose** — Returns current playback position in seconds.

**Syntax**

    Video.Position(player) As Double

**Parameters**

- `player`

**Description**

Returns current playback position in seconds.

**Example**

    Print Video.Position(introVid)

**See Also** — [Video.Play](#videoplay), [Video.Stop](#videostop), [Video.Pause](#videopause), [Video.Resume](#videoresume), [Video.Seek](#videoseek), [Video.Length](#videolength), [Video.IsPlaying](#videoisplaying), [Video.Volume](#videovolume)

---

## Video.Resume

**Purpose** — Resumes a paused video.

**Syntax**

    Video.Resume(player)

**Parameters**

- `player`

**Description**

Resumes a paused video.

**Example**

    Video.Resume introVid

**See Also** — [Video.Play](#videoplay), [Video.Stop](#videostop), [Video.Pause](#videopause), [Video.Seek](#videoseek), [Video.Position](#videoposition), [Video.Length](#videolength), [Video.IsPlaying](#videoisplaying), [Video.Volume](#videovolume)

---

## Video.Seek

**Purpose** — Jumps to a specific time in the video.

**Syntax**

    Video.Seek(player, seconds)

**Parameters**

- `player`
- `seconds`

**Description**

Jumps to a specific time in the video.

**Example**

    Video.Seek introVid, 30

**See Also** — [Video.Play](#videoplay), [Video.Stop](#videostop), [Video.Pause](#videopause), [Video.Resume](#videoresume), [Video.Position](#videoposition), [Video.Length](#videolength), [Video.IsPlaying](#videoisplaying), [Video.Volume](#videovolume)

---

## Video.Stop

**Purpose** — Stops playback and resets position to 0.

**Syntax**

    Video.Stop(player)

**Parameters**

- `player`

**Description**

Stops playback and resets position to 0.

**Example**

    Video.Stop introVid

**See Also** — [Video.Play](#videoplay), [Video.Pause](#videopause), [Video.Resume](#videoresume), [Video.Seek](#videoseek), [Video.Position](#videoposition), [Video.Length](#videolength), [Video.IsPlaying](#videoisplaying), [Video.Volume](#videovolume)

---

## Video.Volume

**Purpose** — Sets video audio volume (0-100%).

**Syntax**

    Video.Volume(player, percent)

**Parameters**

- `player`
- `percent`

**Description**

Sets video audio volume (0-100%). Same percent system as Speaker.Volume.

**Example**

    Video.Volume introVid, 75

**See Also** — [Video.Play](#videoplay), [Video.Stop](#videostop), [Video.Pause](#videopause), [Video.Resume](#videoresume), [Video.Seek](#videoseek), [Video.Position](#videoposition), [Video.Length](#videolength), [Video.IsPlaying](#videoisplaying)

---


### W

## Wend

**Purpose** — Terminates a While loop (legacy syntax).

**Syntax**

    Wend

**Description**

Terminates a While loop (legacy syntax).

**Example**

    While x < 100
        x = x + 1
    Wend

**See Also** — [Do](#do), [Loop](#loop), [While](#while), [Until](#until), [Exit](#exit)

---

## Whenever

**Purpose** — Reactive programming — automatically triggers code when a monitored condition changes.

**Syntax**

    Whenever condition [Changes|Becomes|Exceeds|Below value]
        statements
    End Whenever

**Description**

Reactive programming — automatically triggers code when a monitored condition changes.

**Example**

    Whenever health Below 20
        lblWarning.Visible = True
        lblWarning.Caption = "Low Health!"
    End Whenever

    Whenever score Changes
        lblScore.Caption = "Score: " & score
    End Whenever

---

## While

**Purpose** — Repeats a block as long as the condition is True.

**Syntax**

    While condition
        statements
    Wend

**Description**

Repeats a block as long as the condition is True. Legacy syntax; prefer Do...Loop for new code.

**Example**

    While Not gameOver
        Update()
        Draw()
    Wend

**See Also** — [Do](#do), [Loop](#loop), [Wend](#wend), [Until](#until), [Exit](#exit)

---

## With

**Purpose** — Executes a series of statements on a single object without repeating the object name.

**Syntax**

    With objectExpression
        .Property = value
        .Method()
    End With

**Description**

Executes a series of statements on a single object without repeating the object name.

**Example**

    With lblScore
        .Caption = "Score: " & score
        .ForeColor = IIf(score > 100, vbRed, vbBlack)
        .Visible = True
    End With

**See Also** — [End With](#end-with), [Using](#using)

---

## WithEvents

**Purpose** — Declares an object variable that can respond to the object's events through event handler Subs.

**Syntax**

    Dim WithEvents varName As ClassName

**Parameters**

- `WithEvents varName`

**Description**

Declares an object variable that can respond to the object's events through event handler Subs.

**Example**

    Dim WithEvents gameTimer As Timer

    Sub gameTimer_Tick()
        UpdateGame()
    End Sub

**See Also** — [Event](#event), [RaiseEvent](#raiseevent)

---


### X

## Xor

**Purpose** — Logical XOR; also performs bitwise XOR on numeric operands.

**Syntax**

    expression1 Xor expression2

**Parameters**

- `Xor expression2`

**Description**

When both operands are boolean or non-numeric: performs logical XOR — returns True if exactly one expression is True.

When both operands are numeric: performs bitwise XOR — each bit position is True if the operand bits differ. This follows VB6 semantics.

**Logical Example**

    If a Xor b Then
        Print "Exactly one is true"
    End If

**Bitwise Example**

    Dim flags As Integer = 12       ' Binary: 1100
    Dim mask As Integer = 10        ' Binary: 1010
    Dim result = flags Xor mask     ' Result: 6 (Binary: 0110)
    
    flags Xor= &H01                 ' Toggle bit 0

**See Also** — [And](#and), [Or](#or), [Not](#not), [<<](#command-reference), [>>](#command-reference)

---

### Shift Operators

## << (Shift Left)

**Purpose** — Left bit-shift operator — multiplies an integer by a power of 2.

**Syntax**

    expression1 << expression2

**Parameters**

- `expression1` — The value to shift (must be numeric)
- `expression2` — The number of positions to shift left (must be numeric)

**Description**

Shifts the bits of `expression1` left by `expression2` positions, filling with zeros on the right. Equivalent to multiplying by 2 raised to the power of `expression2`.

Matches VB.NET and TwinBASIC syntax.

**Example**

    Dim a As Integer = 1 << 8      ' 256 (1 shifted left 8 bits)
    Dim b As Integer = 5 << 3      ' 40  (5 * 2^3)
    Dim flags = value << 4         ' Shift by variable amount
    
    ' Compound assignment
    flags <<= 2                     ' flags = flags << 2

**See Also** — [>>](#command-reference), [And](#and), [Or](#or), [Xor](#xor)

---

## >> (Shift Right)

**Purpose** — Right bit-shift operator — divides an integer by a power of 2 (arithmetic shift).

**Syntax**

    expression1 >> expression2

**Parameters**

- `expression1` — The value to shift (must be numeric)
- `expression2` — The number of positions to shift right (must be numeric)

**Description**

Shifts the bits of `expression1` right by `expression2` positions. For signed integers, performs arithmetic shift (sign bit is preserved). For unsigned integers, performs logical shift (fills with zeros).

Equivalent to dividing by 2 raised to the power of `expression2` (with truncation).

Matches VB.NET and TwinBASIC syntax.

**Example**

    Dim a As Integer = 256 >> 4    ' 16 (256 / 2^4)
    Dim b As Integer = 40 >> 3     ' 5  (40 / 2^3)
    Dim value = flags >> n         ' Shift by variable amount
    
    ' Compound assignment
    flags >>= 2                     ' flags = flags >> 2

**See Also** — [<<](#command-reference), [And](#and), [Or](#or), [Xor](#xor)

---

### Documentation Backfill — Runtime Builtins (Phase 1)

The entries below document runtime builtins that were implemented but not yet covered in this reference. Names are case-insensitive at runtime.

## DataCount

**Purpose** — Returns the number of values in the DATA tape, or in one labeled section.

**Syntax**

    DataCount()
    DataCount("sectionLabel")

**Description**

- `DataCount()` — total items on the active DATA tape (inline `Data`, text `DataFile`, and `LoadData` append).
- `DataCount("WorldTiles")` — item count for that label (for `.vgd` grids, width × height).

**Example**

    If DataCount() = 0 Then Print "No data loaded"
    If DataCount("PlayerSprite") < 5 Then Print "Sprite header incomplete"

---

## DataLabels

**Purpose** — Returns available DATA labels for the current program/data tape.

**Syntax**

    DataLabels()

---

## DataPointer

**Purpose** — Returns the current read pointer index for DATA/READ operations.

**Syntax**

    DataPointer()

---

## DataRemain

**Purpose** — Returns how many DATA values remain unread.

**Syntax**

    DataRemain()

---

## DataSectionCount

**Purpose** — Returns the number of DATA sections currently loaded.

**Syntax**

    DataSectionCount()

---

## DataSectionName

**Purpose** — Returns the section name at a given DATA section index.

**Syntax**

    DataSectionName(index)

---

## DataSectionRemain

**Purpose** — Returns unread value count in a specific DATA section.

**Syntax**

    DataSectionRemain(sectionName)

---

## DataToArray

**Purpose** — Materializes DATA values into a 1-based Variant array. With a section label, returns all values in that labeled block (including sprite header + pixel indices for `*Sprite:` sections).

**Syntax**

    DataToArray()
    DataToArray("sectionLabel")
    DataToArray(count)

**Parameters**

- *(no args)* — entire active DATA tape as a flat array.
- `"sectionLabel"` — all values in the named section (case-insensitive label before the colon).
- `count` — read `count` values from the current DATA read pointer.

**Description**

For labeled sections, the compiler records label boundaries; `DataToArray("PlayerSprite")` returns every numeric literal in that section in order. For [Sprite Data](#sprite-data) blocks, element layout is:

- `(0)` = width `w`
- `(1)` = height `h`
- `(2)` = transparent palette index
- `(3)` = palette id (0=NES, 1=GameBoy, 2=C64, 3=CGA)
- `(4)` … `(4 + w×h − 1)` = pixel indices, row-major

Call once in `_Ready` or `LoadSprites` and reuse the cached array in draw code — do not call inside `_Draw` per sprite instance.

**Example**

    PlayerSprite:
    Data 4, 4, 0, 0
    Data 0, 1, 1, 0
    Data 1, 2, 2, 1
    Data 1, 2, 2, 1
    Data 0, 1, 1, 0

    Dim raw As Variant
    raw = DataToArray("PlayerSprite")
    Print raw(0)   ' 4 (width)
    Print raw(4)   ' first pixel index (top-left)

**See Also** — [Data](#data), [Sprite Data](#sprite-data), [DataCount](#datacount), [PeekData](#peekdata), [Restore](#restore)

---

## SetDataPointer

**Purpose** — Sets the active DATA read pointer.

**Syntax**

    SetDataPointer(index)

---

## GetSetting

**Purpose** — Reads a persisted application/user setting value.

**Syntax**

    GetSetting(section, key[, defaultValue])

---

## GetAllSettings

**Purpose** — Returns all settings in a section as key/value pairs.

**Syntax**

    GetAllSettings(section)

---

## SaveSetting

**Purpose** — Persists a setting value.

**Syntax**

    SaveSetting(section, key, value)

---

## DeleteSetting

**Purpose** — Deletes a saved setting key.

**Syntax**

    DeleteSetting(section, key)

---

## FormatNumber

**Purpose** — Returns a localized number string with standard numeric formatting.

**Syntax**

    FormatNumber(value[, decimals])

---

## FormatCurrency

**Purpose** — Returns a localized currency-formatted string.

**Syntax**

    FormatCurrency(value[, decimals])

---

## FormatPercent

**Purpose** — Returns a localized percentage-formatted string.

**Syntax**

    FormatPercent(value[, decimals])

---

## DatePart

**Purpose** — Extracts a part from a date/time value.

**Syntax**

    DatePart(partName, dateValue)

**Example**

    Print DatePart("yyyy", Now())

---

## DateValue

**Purpose** — Converts a date string/expression to a date value.

**Syntax**

    DateValue(value)

---

## TimeValue

**Purpose** — Converts a time string/expression to a time value.

**Syntax**

    TimeValue(value)

---

## FileDateTime

**Purpose** — Returns last-modified timestamp metadata for a file.

**Syntax**

    FileDateTime(path)

---

## Tracker.Open

**Purpose** — Opens/initializes tracker module playback context.

**Syntax**

    Tracker.Open(path)

---

## Tracker.Load

**Purpose** — Loads tracker module data into the active tracker context.

**Syntax**

    Tracker.Load(path)

---

## Tracker.Play

**Purpose** — Starts tracker playback.

**Syntax**

    Tracker.Play()

---

## Tracker.Stop

**Purpose** — Stops tracker playback.

**Syntax**

    Tracker.Stop()

---

## Tracker.SetTempo

**Purpose** — Sets tracker playback tempo.

**Syntax**

    Tracker.SetTempo(bpm)

---

## Tracker.Close

**Purpose** — Closes and frees tracker playback context. **[Linux/macOS only; Windows planned]**

**Syntax**

    Tracker.Close(handle)

---

## Tracker.Fill

**Purpose** — Fills audio buffer from tracker module (call per frame in _Process). **[Linux/macOS only; Windows planned]**

**Syntax**

    Tracker.Fill(handle)

---

## Tracker.GetPosition

**Purpose** — Returns current playback position in seconds. **[Linux/macOS only; Windows planned]**

**Syntax**

    Tracker.GetPosition(handle)

---

## Tracker.GetDuration

**Purpose** — Returns total tracker module duration in seconds. **[Linux/macOS only; Windows planned]**

**Syntax**

    Tracker.GetDuration(handle)

---

## Music.Close

**Purpose** — Closes music playback driver. **[Linux/macOS only; Windows planned]**

**Syntax**

    Music.Close(driver)

---

## Music.Pause

**Purpose** — Pauses music playback. **[Linux/macOS only; Windows planned]**

**Syntax**

    Music.Pause(driver)

---

## Music.Resume

**Purpose** — Resumes paused music. **[Linux/macOS only; Windows planned]**

**Syntax**

    Music.Resume(driver)

---

## Music.GetBPM

**Purpose** — Returns current playback BPM. **[Linux/macOS only; Windows planned]**

**Syntax**

    Music.GetBPM(driver)

---

## Music.SetBPM

**Purpose** — Sets music playback tempo in BPM. **[Linux/macOS only; Windows planned]**

**Syntax**

    Music.SetBPM(driver, bpm)

---

## Music.SetVolume

**Purpose** — Sets music playback volume (0.0–1.0). **[Linux/macOS only; Windows planned]**

**Syntax**

    Music.SetVolume(driver, volume)

---

## Music.IsPlaying

**Purpose** — Returns whether music is currently playing. **[Linux/macOS only; Windows planned]**

**Syntax**

    Music.IsPlaying(driver)

---

## Music.IsPaused

**Purpose** — Returns whether music is paused. **[Linux/macOS only; Windows planned]**

**Syntax**

    Music.IsPaused(driver)

---

## Music.NoteOn

**Purpose** — Triggers a note in real-time synthesis. **[Linux/macOS only; Windows planned]**

**Syntax**

    Music.NoteOn(driver, channel, note, velocity)

---

## Music.NoteOff

**Purpose** — Releases a note in real-time synthesis. **[Linux/macOS only; Windows planned]**

**Syntax**

    Music.NoteOff(driver, channel, note)

---

## SoundGen.FillVoices

**Purpose** — Generates real-time procedural audio from voice parameters. **[Linux/macOS only; Windows planned]**

**Syntax**

    SoundGen.FillVoices(handle, channels, phase, freq, duty, sweep, mod_phase, mod_freq, noise, depth)

---

## SoundGen.FillVoices4

**Purpose** — Generates 4-voice polyphonic audio synthesis. **[Linux/macOS only; Windows planned]**

**Syntax**

    SoundGen.FillVoices4(handle, channels, voices_array)

---

## SoundGen.PushMonoBuffer

**Purpose** — Pushes mono audio buffer into sound generator ring buffer. **[Linux/macOS only; Windows planned]**

**Syntax**

    SoundGen.PushMonoBuffer(handle, samples)

---

## SoundGen.PushStereoBuffer

**Purpose** — Pushes stereo audio buffer into sound generator ring buffer. **[Linux/macOS only; Windows planned]**

**Syntax**

    SoundGen.PushStereoBuffer(handle, samples_left, samples_right)

---

## AllocFillI64

**Purpose** — Allocates and fills a 64-bit integer array.

**Syntax**

    AllocFillI64(size, value)

---

## AllocFillI64Sum

**Purpose** — Allocates and fills a 64-bit integer array with cumulative sum.

**Syntax**

    AllocFillI64Sum(size, value)

---

## AscW

**Purpose** — Returns Unicode code point of character.

**Syntax**

    AscW(char)

---

## BenchFileIOFast

**Purpose** — Benchmark fast file I/O performance.

**Syntax**

    BenchFileIOFast(iterations)

---

## CallByName

**Purpose** — Dynamically invokes object method by string name.

**Syntax**

    CallByName(object, methodName [, args...])

---

## CByte

**Purpose** — Converts an expression to a byte value (0–255).

**Syntax**

    CByte(expression)

**Parameters**

- `expression` — Number or numeric string to convert.

**Description**

Converts an expression to an 8-bit unsigned byte. Values below 0 clamp to 0; values above 255 clamp to 255.

**Example**

    Dim b As Integer = CByte(128)   ' 128
    Dim hi As Integer = CByte(300)  ' 255
    Dim lo As Integer = CByte(-1)   ' 0

**See Also** — [CInt](#cint), [CLng](#clng), [CDbl](#cdbl), [CSng](#csng)

---

## ChrW

**Purpose** — Returns character from Unicode code point.

**Syntax**

    ChrW(codepoint)

---

## ClampF

**Purpose** — Clamps float value between min and max.

**Syntax**

    ClampF(value, min, max)

---

## ClngLng

**Purpose** — Converts value to long integer.

**Syntax**

    ClngLng(value)

---

## Erl

**Purpose** — Returns line number where error occurred.

**Syntax**

    Erl()

---

## ErrorDesc

**Purpose** — Returns description of last runtime error.

**Syntax**

    ErrorDesc()

---

## InputStr

**Purpose** — Reads string input from console/input stream.

**Syntax**

    InputStr([prompt])

---

## IsKeyDown

**Purpose** — Checks if keyboard key is currently pressed.

**Syntax**

    IsKeyDown(keycode)

---

## IsMissing

**Purpose** — Checks if optional parameter was provided.

**Syntax**

    IsMissing(param)

---

## IsMouseButtonDown

**Purpose** — Checks if mouse button is currently pressed.

**Syntax**

    IsMouseButtonDown(button)

---

## IsSQLiteAvailable

**Purpose** — Checks if SQLite database support is available.

**Syntax**

    IsSQLiteAvailable()

---

## IsZeroApprox

**Purpose** — Checks if value is approximately zero.

**Syntax**

    IsZeroApprox(value)

---

## LerpF

**Purpose** — Linear interpolation between two float values.

**Syntax**

    LerpF(a, b, t)

---

## LSet

**Purpose** — Left-aligns string within fixed-width field.

**Syntax**

    LSet(target, source)

---

## PeekData

**Purpose** — Reads a DATA value by absolute index or by labeled section + offset, without advancing the READ pointer.

**Syntax**

    PeekData(index)
    PeekData("sectionLabel", offset)

**Description**

- `PeekData(5)` — absolute 0-based index into the full DATA tape.
- `PeekData("PlayerSprite", 4)` — first pixel index in that sprite section (after the four header values).
- `PeekData("WorldTiles", 0)` — first cell of a `.vgd` grid loaded via `DataFile`.

**See Also** — [Data](#data), [DataFile](#datafile), [DataBuffer](#databuffer), [Sprite Data](#sprite-data), [DataToArray](#datatoarray)

---

## RSet

**Purpose** — Right-aligns string within fixed-width field.

**Syntax**

    RSet(target, source)

---

## SavePicture

**Purpose** — Saves image/picture to file.

**Syntax**

    SavePicture(image, path)

---

## StrComp

**Purpose** — Compares two strings lexicographically.

**Syntax**

    StrComp(str1, str2 [, compare_mode])

---

## StrConv

**Purpose** — Converts string case or encoding.

**Syntax**

    StrConv(string, conversion_type)

**Conversion types:** `vbUpperCase` (1), `vbLowerCase` (2), `vbProperCase` (3). `vbUnicode` (64) and `vbFromUnicode` (128) are accepted for VB6 source compatibility but are **no-ops** in Visual Gasic — strings and UI controls (`Caption`, `Text`, etc.) are already Unicode via Godot.

**VB6 note:** Classic VB6 native `TextBox`/`Label` controls downgrade text to ANSI when displaying, so CJK and emoji often show as `???` unless you use MSForms or Win32 Unicode APIs. **That limitation does not apply here.** Use UTF-8 `.vg` sources and a font that includes the glyphs you need.

---

## TextHeight

**Purpose** — Calculates rendered text height in pixels.

**Syntax**

    TextHeight(text [, font] [, font_size])

---

## TextWidth

**Purpose** — Calculates rendered text width in pixels.

**Syntax**

    TextWidth(text [, font] [, font_size])

---

## Legacy Coverage Appendix

This appendix preserves the high-level intent of legacy non-IDE chapters that are no longer separate top-level sections in this file.

### Keywords Reference (Consolidated)

Legacy `Keywords Reference` content is now consolidated into:
- [Language Basics](#language-basics) (core syntax, declarations, literals, operators)
- [Control Flow](#control-flow) (branching, loops, structured flow keywords)
- [Procedures and Functions](#procedures-and-functions) (Sub/Function signatures, params, returns)
- [Object-Oriented Features](#object-oriented-features) (Class/Interface/Event member keywords)
- [Part II — Command Reference (A–Z)](#command-reference) (keyword-level callable and statement coverage)

### Built-in Functions (Consolidated)

Legacy `Built-in Functions` chapter content is represented by:
- [Language Basics](#language-basics) (fundamental examples and usage patterns)
- [System Integration](#system-integration) (platform, IO, crypto, tasking, package APIs)
- [Part II — Command Reference (A–Z)](#command-reference) (complete built-in and callable index)

For command-level specifics, use [Part II — Command Reference (A–Z)](#command-reference).

---


## Alphabetical Index

This index lists command-reference entries grouped by first letter.

**Part I Quick Links**
- [Getting Started](#getting-started)
- [Language Basics](#language-basics)
- [Control Flow](#control-flow)
- [Procedures and Functions](#procedures-and-functions)
- [Object-Oriented Features](#object-oriented-features)
- [VB6 Global Objects](#vb6-global-objects)
- [COM-Style Objects](#com-style-objects)
- [System Integration](#system-integration)
- [System-Level Programming](#system-level-programming)
- [Modern Language Features](#modern-language-features)
- [Godot Integration](#godot-integration)
- [Part II — Command Reference (A–Z)](#command-reference)

### #
- [_draw](#_draw)
- [_input](#_input)
- [_physics_process](#_physics_process)
- [_process](#_process)
- [_ready](#_ready)
- [<<](#command-reference) (Shift Left)
- [>>](#command-reference) (Shift Right)

### A
- [AABB](#aabb)
- [Abs](#abs)
- [add_child](#add_child)
- [And](#and)
- [Animation.Current](#animationcurrent)
- [Animation.IsPlaying](#animationisplaying)
- [Animation.Length](#animationlength)
- [Animation.Loop](#animationloop)
- [Animation.Pause](#animationpause)
- [Animation.Play](#animationplay)
- [Animation.Resume](#animationresume)
- [Animation.Seek](#animationseek)
- [Animation.Speed](#animationspeed)
- [Animation.Stop](#animationstop)
- [Array](#array)
- [Async](#async)
- [Await](#await)
- [AllocFillI64](#allocfilli64)
- [AllocFillI64Sum](#allocfilli64sum)
- [AscW](#ascw)

### B
- [Basis](#basis)
- [BlitImage](#blitimage)
- [Bone.Find](#bonefind)
- [Bone.LookAt](#bonelookat)
- [Bone.Pos](#bonepos)
- [Bone.Rot](#bonerot)
- [Bone.Scale](#bonescale)
- [Bone.SetPos](#bonesetpos)
- [Bone.SetRot](#bonesetrot)
- [Bone.SetScale](#bonesetscale)
- [Boolean](#boolean)
- [ByRef](#byref)
- [ByVal](#byval)
- [BenchFileIOFast](#benchfileiofast)

### C
- [Call](#call)
- [Camera.Bounce](#camerabounce)
- [Camera.FlashColor](#cameraflashcolor)
- [Camera.Follow](#camerafollow)
- [Camera.FOV](#camerafov)
- [Camera.Limits](#cameralimits)
- [Camera.MakeCurrent](#cameramakecurrent)
- [Camera.PanTo](#camerapanto)
- [Camera.Position](#cameraposition)
- [Camera.Rotation](#camerarotation)
- [Camera.Shake](#camerashake)
- [Camera.Zoom](#camerazoom)
- [Case](#case)
- [Catch](#catch)
- [Cell.Clear](#cellclear)
- [Cell.ClearAll](#cellclearall)
- [Cell.Get](#cellget)
- [Cell.Set](#cellset)
- [Cell.Used](#cellused)
- [ChangeScene](#changescene)
- [CInt](#cint)
- [Clamp](#clamp)
- [Class](#class)
- [Close](#close)
- [CLS](#cls)
- [ColorFromHSV](#colorfromhsv)
- [ColorToHSV](#colortohsv)
- [connect](#connect)
- [Const](#const)
- [Continue](#continue)
- [Cos](#cos)
- [CreateActor2D](#createactor2d)
- [CreateImage](#createimage)
- [CreateTexture](#createtexture)
- [Crypto.Base64](#cryptobase64)
- [Crypto.Base64Decode](#cryptobase64decode)
- [Crypto.Base64Encode](#cryptobase64encode)
- [Crypto.FromHex](#cryptofromhex)
- [Crypto.Hex](#cryptohex)
- [Crypto.HMAC](#cryptohmac)
- [Crypto.MD5](#cryptomd5)
- [Crypto.RandomBytes](#cryptorandombytes)
- [Crypto.SHA1](#cryptosha1)
- [Crypto.SHA256](#cryptosha256)
- [CStr](#cstr)
- [CallByName](#callbyname)
- [CByte](#cbyte)
- [ChrW](#chrw)
- [ClampF](#clampf)
- [ClngLng](#clnglng)

### D
- [Darken](#darken)
- [Data](#data)
- [delta](#delta)
- [Dim](#dim)
- [Do](#do)
- [DoEvents](#doevents)
- [Double](#double)
- [DrawArc](#drawarc)
- [DrawCircle](#drawcircle)
- [DrawLine](#drawline)
- [DrawPixel](#drawpixel)
- [DrawPolygon](#drawpolygon)
- [DrawPolyline](#drawpolyline)
- [DrawRect](#drawrect)
- [DrawString](#drawstring)
- [DrawTexture](#drawtexture)
- [DrawTextureRect](#drawtexturerect)
- [DataCount](#datacount)
- [DataLabels](#datalabels)
- [DataPointer](#datapointer)
- [DataRemain](#dataremain)
- [DataSectionCount](#datasectioncount)
- [DataSectionName](#datasectionname)
- [DataSectionRemain](#datasectionremain)
- [DataToArray](#datatoarray)
- [DeleteSetting](#deletesetting)
- [DatePart](#datepart)
- [DateValue](#datevalue)

### E
- [Else](#else)
- [ElseIf](#elseif)
- [emit_signal](#emit_signal)
- [End](#end)
- [End Class](#end-class)
- [End Function](#end-function)
- [End If](#end-if)
- [End Select](#end-select)
- [End Sub](#end-sub)
- [End With](#end-with)
- [Enum](#enum)
- [Event](#event)
- [Exit](#exit)
- [Erl](#erl)
- [ErrorDesc](#errordesc)

### F
- [False](#false)
- [FillImage](#fillimage)
- [FillImageRect](#fillimagerect)
- [Finally](#finally)
- [For](#for)
- [For Each](#for-each)
- [Format](#format)
- [Function](#function)
- [FormatNumber](#formatnumber)
- [FormatCurrency](#formatcurrency)
- [FormatPercent](#formatpercent)
- [FileDateTime](#filedatetime)

### G
- [get_global_mouse_position](#get_global_mouse_position)
- [get_node](#get_node)
- [get_tree](#get_tree)
- [GetImagePixel](#getimagepixel)
- [GetTextureImage](#gettextureimage)
- [Global](#global)
- [GoSub](#gosub)
- [GoTo](#goto)
- [GPS.Accuracy](#gpsaccuracy)
- [GPS.Alt](#gpsalt)
- [GPS.Lat](#gpslat)
- [GPS.Lng](#gpslng)
- [GPS.Speed](#gpsspeed)
- [GetSetting](#getsetting)
- [GetAllSettings](#getallsettings)

### H
- [hide](#hide)

### I
- [If](#if)
- [IIf](#iif)
- [ImageHeight](#imageheight)
- [ImageToTexture](#imagetotexture)
- [ImageWidth](#imagewidth)
- [Implements](#implements)
- [Inherits](#inherits)
- [InputBox](#inputbox)
- [instantiate](#instantiate)
- [InStr](#instr)
- [Int](#int)
- [Integer](#integer)
- [Interface](#interface)
- [is_action_just_pressed](#is_action_just_pressed)
- [is_action_just_released](#is_action_just_released)
- [is_action_pressed](#is_action_pressed)
- [is_on_floor](#is_on_floor)
- [is_on_wall](#is_on_wall)
- [IsActionPressed](#isactionpressed)
- [IsKeyPressed](#iskeypressed)
- [InputStr](#inputstr)
- [IsKeyDown](#iskeydown)
- [IsMissing](#ismissing)
- [IsMouseButtonDown](#ismousebuttondown)
- [IsSQLiteAvailable](#issqliteavailable)
- [IsZeroApprox](#iszeroapprox)

### J
- [Join](#join)
- [Joypad.Axis](#joypadaxis)
- [Joypad.Button](#joypadbutton)
- [Joypad.Connected](#joypadconnected)
- [Joypad.IsConnected](#joypadisconnected)
- [Joypad.Name](#joypadname)
- [Joypad.Stick](#joypadstick)
- [JS.Call](#jscall)
- [JS.Eval](#jseval)
- [JS.Get](#jsget)

### L
- [Lambda](#lambda)
- [LBound](#lbound)
- [LCase](#lcase)
- [Left](#left)
- [Len](#len)
- [Lerp](#lerp)
- [Lighten](#lighten)
- [Line Input](#line-input)
- [LoadForm](#loadform)
- [LoadImage](#loadimage)
- [LoadPicture](#loadpicture)
- [Long](#long)
- [look_at](#look_at)
- [Loop](#loop)
- [LerpF](#lerpf)
- [LSet](#lset)

### M
- [Material.New](#materialnew)
- [Material.SetShader](#materialsetshader)
- [Me](#me)
- [Mid](#mid)
- [Mod](#mod)
- [move_and_slide](#move_and_slide)
- [MsgBox](#msgbox)
- [Music.Close](#musicclose)
- [Music.Pause](#musicpause)
- [Music.Resume](#musicresume)
- [Music.GetBPM](#musicgetbpm)
- [Music.SetBPM](#musicsetbpm)
- [Music.SetVolume](#musicsetvolume)
- [Music.IsPlaying](#musicisplaying)
- [Music.IsPaused](#musicispaused)
- [Music.NoteOn](#musicnoteon)
- [Music.NoteOff](#musicnoteoff)

### N
- [Nav.Distance](#navdistance)
- [Nav.NextPos](#navnextpos)
- [Nav.Path](#navpath)
- [Nav.Reached](#navreached)
- [Nav.SetTarget](#navsettarget)
- [New](#new)
- [NewCurve](#newcurve)
- [NewNoise](#newnoise)
- [NewRNG](#newrng)
- [Next](#next)
- [Not](#not)
- [Nothing](#nothing)

### O
- [On Error](#on-error)
- [Open](#open)
- [Option Explicit](#option-explicit)
- [Optional](#optional)
- [Or](#or)

### P
- [Permission.All](#permissionall)
- [Permission.Has](#permissionhas)
- [Permission.Request](#permissionrequest)
- [Physics.Bounce](#physicsbounce)
- [Physics.Force](#physicsforce)
- [Physics.Gravity](#physicsgravity)
- [Physics.GravityV2](#physicsgravityv2)
- [Physics.GravityV3](#physicsgravityv3)
- [Physics.Impulse](#physicsimpulse)
- [Physics.Ray](#physicsray)
- [Physics.Torque](#physicstorque)
- [Plane](#plane)
- [PlaySound](#playsound)
- [Print](#print)
- [Private](#private)
- [Property](#property)
- [PSet](#pset)
- [Public](#public)
- [Pull](#pull)
- [Push](#push)
- [PeekData](#peekdata)

### Q
- [Quaternion](#quaternion)
- [QuaternionFromEuler](#quaternionfromeuler)
- [queue_free](#queue_free)
- [queue_redraw](#queue_redraw)
- [QueueRedraw](#queueredraw)

### R
- [RaiseEvent](#raiseevent)
- [Randomize](#randomize)
- [RandRange](#randrange)
- [Ray.Cast2D](#raycast2d)
- [Ray.Cast3D](#raycast3d)
- [Ray.Collider](#raycollider)
- [Ray.Enable](#rayenable)
- [Ray.ForceUpdate](#rayforceupdate)
- [Ray.Hit](#rayhit)
- [Ray.Normal](#raynormal)
- [Ray.Point](#raypoint)
- [Ray.Target](#raytarget)
- [Read](#read)
- [ReDim](#redim)
- [remove_child](#remove_child)
- [Replace](#replace)
- [ResetDrawTransform](#resetdrawtransform)
- [Restore](#restore)
- [Return](#return)
- [RGB](#rgb)
- [Right](#right)
- [Rnd](#rnd)
- [Round](#round)
- [RSet](#rset)

### S
- [SaveImage](#saveimage)
- [Screen.DPI](#screendpi)
- [Screen.FullScreen](#screenfullscreen)
- [Screen.Height](#screenheight)
- [Screen.IsFullScreen](#screenisfullscreen)
- [Screen.KeepOn](#screenkeepon)
- [Screen.Orientation](#screenorientation)
- [Screen.Width](#screenwidth)
- [Select](#select)
- [Select Case](#select-case)
- [Sensor.Accel](#sensoraccel)
- [Sensor.Gravity](#sensorgravity)
- [Sensor.Gyro](#sensorgyro)
- [Sensor.Magnet](#sensormagnet)
- [Sensor.Magnetometer](#sensormagnetometer)
- [Sensor.Tilt](#sensortilt)
- [Sensor.Units](#sensorunits)
- [Set](#set)
- [set_process](#set_process)
- [SetDrawTransform](#setdrawtransform)
- [SetImagePixel](#setimagepixel)
- [Shader.Get](#shaderget)
- [Shader.GetParam](#shadergetparam)
- [Shader.Param](#shaderparam)
- [Shader.Set](#shaderset)
- [show](#show)
- [Sin](#sin)
- [Single](#single)
- [Skeleton.Count](#skeletoncount)
- [Skeleton.Name](#skeletonname)
- [Skeleton.Reset](#skeletonreset)
- [Slerp](#slerp)
- [Sound.IsPlaying](#soundisplaying)
- [Sound.Pause](#soundpause)
- [Sound.Pitch](#soundpitch)
- [Sound.Play](#soundplay)
- [Sound.Position](#soundposition)
- [Sound.Resume](#soundresume)
- [Sound.Seek](#soundseek)
- [Sound.Stop](#soundstop)
- [Sound.Volume](#soundvolume)
- [Speaker.Bus](#speakerbus)
- [Speaker.Count](#speakercount)
- [Speaker.Exists](#speakerexists)
- [Speaker.IsMuted](#speakerismuted)
- [Speaker.Mute](#speakermute)
- [Speaker.Name](#speakername)
- [Speaker.Solo](#speakersolo)
- [Speaker.Volume](#speakervolume)
- [SoundGen.Open](#soundgenopen)
- [SoundGen.Close](#soundgenclose)
- [SoundGen.Available](#soundgenavailable)
- [SoundGen.PushMono](#soundgenpushmono)
- [SoundGen.PushStereo](#soundgenpushstereo)
- [Spin](#spin)
- [Split](#split)
- [Sprite Data](#sprite-data)
- [Sqr](#sqr)
- [Static](#static)
- [Steps.Reset](#stepsreset)
- [Steps.Today](#stepstoday)
- [Steps.Total](#stepstotal)
- [Str](#str)
- [String](#string)
- [Sub](#sub)
- [SetDataPointer](#setdatapointer)
- [SaveSetting](#savesetting)
- [SoundGen.FillVoices](#soundgenfillvoices)
- [SoundGen.FillVoices4](#soundgenfillvoices4)
- [SoundGen.PushMonoBuffer](#soundgenpushmonobuffer)
- [SoundGen.PushStereoBuffer](#soundgenpushstereobuffer)
- [SavePicture](#savepicture)
- [StrComp](#strcomp)
- [StrConv](#strconv)

### T
- [TextureHeight](#textureheight)
- [TextureWidth](#texturewidth)
- [Theme.Color](#themecolor)
- [Theme.Constant](#themeconstant)
- [Theme.Font](#themefont)
- [Theme.Get](#themeget)
- [Theme.Set](#themeset)
- [Theme.SetColor](#themesetcolor)
- [Theme.SetConstant](#themesetconstant)
- [Theme.SetFont](#themesetfont)
- [Theme.SetFontSize](#themesetfontsize)
- [Theme.SetStyle](#themesetstyle)
- [Then](#then)
- [Throw](#throw)
- [Transform2D](#transform2d)
- [Transform3D](#transform3d)
- [Trim](#trim)
- [True](#true)
- [Try](#try)
- [Type](#type)
- [TimeValue](#timevalue)
- [Tracker.Open](#trackeropen)
- [Tracker.Load](#trackerload)
- [Tracker.Play](#trackerplay)
- [Tracker.Stop](#trackerstop)
- [Tracker.SetTempo](#trackersettempo)
- [Tracker.Close](#trackerclose)
- [Tracker.Fill](#trackerfill)
- [Tracker.GetPosition](#trackergetposition)
- [Tracker.GetDuration](#trackergetduration)
- [TextHeight](#textheight)
- [TextWidth](#textwidth)

### U
- [UBound](#ubound)
- [UCase](#ucase)
- [Until](#until)
- [UpdateTexture](#updatetexture)
- [Using](#using)

### V
- [Val](#val)
- [Variant](#variant)
- [Vibrate](#vibrate)
- [Video.IsPlaying](#videoisplaying)
- [Video.Length](#videolength)
- [Video.Pause](#videopause)
- [Video.Play](#videoplay)
- [Video.Position](#videoposition)
- [Video.Resume](#videoresume)
- [Video.Seek](#videoseek)
- [Video.Stop](#videostop)
- [Video.Volume](#videovolume)

### W
- [Wend](#wend)
- [Whenever](#whenever)
- [While](#while)
- [With](#with)
- [WithEvents](#withevents)

### X
- [Xor](#xor)
