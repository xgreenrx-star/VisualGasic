# Introduction to VisualGasic

## What is VisualGasic?

**VisualGasic** is a modern programming language and **complete RAD (Rapid Application Development) IDE** for the Godot 4.6.1+ engine. It combines the legendary approachability of Visual Basic 6.0 with modern language features, a built-in visual form designer, and a JIT-compiled bytecode engine — all inside a dedicated IDE that feels like classic VB6.

> **VisualGasic is not a VB6 clone.** It is a modern, forward-looking language that draws inspiration from VB6's approachable syntax and ease of learning, while introducing advanced features that go well beyond what VB6 ever offered. If you know VB6, you'll feel at home in minutes. If you're new to programming, you'll find VG one of the easiest languages to learn.

> **Form Designer status (v5.3.0-Beta7):** The classic **Form Designer** (VB6-style WYSIWYG canvas) ships today and is the primary way to build menu forms and dialogs. It has known bugs and is being replaced by **UI Forms** — experimental WYSIWYG editing in Godot's 2D viewport, enabled via **Project Settings → `vg/enable_experimental_plugins`**. Until UI Forms reaches parity, use the Form Designer for forms and attach Node2D game scenes separately; see [Menu Form + Node2D Game](../guides/MENU_FORM_AND_2D_GAME.md).

---

## Why VisualGasic?

### 🖥️ A Dedicated IDE — Not Just a Plugin

Unlike GDScript, which uses the standard Godot script editor, VisualGasic includes its own **full-featured IDE** built in C++:

- **Visual Form Designer** — Drag-and-drop controls (Button, Label, TextBox, ListBox, etc.) onto a WYSIWYG canvas, just like VB6
- **40+ Control Toolbox** — Standard controls, extended controls, 2D/3D game controls, and Game UI controls
- **Property Sheet** — Edit control properties visually with the Properties panel
- **Auto-Wiring** — Click a control and its event handler (`Sub btnPlay_Click()`) is created automatically
- **Code Editor** with syntax highlighting, IntelliSense (80+ function completions, 62+ VB6 property completions), code snippets, and auto-indent
- **Immediate Window** — Execute code live, inspect variables, evaluate expressions at runtime
- **Integrated Debugger** — Breakpoints, Watch Window, Call Stack, Step Over/Into/Out, time-travel debugging

### ⚡ Performance

VisualGasic compiles to a **JIT-optimized bytecode engine** that outperforms GDScript in many benchmarks:

- O(1) **StringName HashMap** dispatch for all 62 VB6 property aliases
- **Computed-goto threaded interpreter** for the bytecode VM
- **GPU computing** with 19 SIMD methods (vector math, reduction, element-wise ops)
- **Real multithreading** with `Task.RunAsync`, `Parallel For`, and worker pools

### 🚀 Rapid Application Development

VisualGasic is built for **speed of development**:

- **Event-driven programming** — Write `Sub btnSave_Click()` and you're done. No signal wiring, no boilerplate.
- **One-line controls** — `CreateButton "Play", 100, 50, "OnPlay"` creates a button, positions it, and wires its click handler in one line.
- **VB6 property aliases** — Use familiar names like `.Caption`, `.Text`, `.BackColor`, `.Visible` instead of memorizing Godot's API.
- **122+ built-in functions** — String, math, file I/O, date/time, collections, JSON, regex, and more — all available without imports.

### 📖 Easy to Learn

VisualGasic uses **English-like syntax** that reads almost like pseudocode:

```vb
If score > 100 Then
    MsgBox "You win!"
End If

For Each enemy In enemies
    enemy.Health = enemy.Health - 10
Next
```

No curly braces, no semicolons, no indentation rules. Keywords like `Sub`, `End Sub`, `If`, `Then`, `For`, `Next` make the structure self-documenting.

### 🔄 VB6 Compatibility

Already know VB6, VBA, or VB.NET? Your existing knowledge transfers directly:

- **Port VB6 projects** using the built-in VB6 importer (`.frm`, `.bas`, `.cls`, `.vbp` files)
- **VB6 syntax** works out of the box: `Dim`, `Sub`/`Function`, `If`/`Select Case`/`For`/`Do`, `Class`, `Enum`, `With`, `GoSub`/`Return`
- **VB6 global objects**: `App`, `Screen`, `Err`, `Printer`, `Clipboard`, `Debug`
- **VB6 constants**: `vbCrLf`, `vbRed`, `vbOKCancel`, `vbYes`, `True`/`False`

### 🔮 Modern Features Beyond VB6

VisualGasic goes far beyond VB6 with features modern developers expect:

- **Lambda expressions**: `Dim doubled = Map(arr, Function(x) x * 2)`
- **Pattern matching**: `Match value: Case Is > 100: ...`
- **Null-safe operators**: `result = obj?.Property ?? "default"`
- **Async/Await**: `Dim data = Await FetchDataAsync()`
- **Generics**: `Dim scores As New Collection(Of Integer)`
- **GPU computing**: `GPUVectorAdd result(), a(), b()`
- **Entity Component System**: Built-in ECS for game development
- **String interpolation**: `Print $"Hello {name}, your score is {score}"`

---

## Project Structure

A VisualGasic project contains:

| File Type | Purpose |
|-----------|---------|
| `project.godot` | Godot project configuration |
| `.vg` files | Your VisualGasic source code |
| `.tscn` files | Scenes (forms, levels, characters, UI) |
| `addons/visual_gasic/` | The VisualGasic engine (GDExtension) |
| Assets | Images (`.png`, `.svg`), Audio (`.wav`, `.ogg`), Fonts |

## Your First Script

```vb
' Member variables
Dim Speed As Integer
Dim PlayerName As String

' Called when the node enters the scene tree
Sub _Ready()
    Speed = 400
    PlayerName = "Hero"
    Print "Ready to play!"
End Sub

' Called every frame
Sub _Process(delta)
    If Input.IsKeyPressed(KEY_RIGHT) Then
        Me.Position = Me.Position + Vector2(Speed * delta, 0)
    End If
End Sub
```

## Getting Started

Ready to dive in? Here's your path:

1. **[Installation](installation.md)** — Set up VisualGasic in under 2 minutes
2. **[Nodes and Scenes](nodes_and_scenes.md)** — Understand Godot's building blocks
3. **[Scripting](scripting.md)** — Write your first VisualGasic code
4. **[Signals](signals.md)** — Handle events and user input

For the complete language reference, see the [VisualGasic Language Reference](../VisualGasic_Language_Reference.md).