# Introduction to VisualGasic

## What is VisualGasic?

**VisualGasic** is a modern programming language and **Godot 4.6.1+ extension** with VB6-style `.vg` scripting, a JIT-compiled bytecode engine, and rich **editor integration** (Code Navigator, Narcea Vibe Code, debugging). A **legacy Form Designer / standalone VG IDE layout** remains available as **experimental Alpha** — see [VG IDE Alpha](../manual/VG_IDE_ALPHA.md). For v6.0, the supported path is **Godot’s editor** plus optional **UI Forms** on the 2D viewport.

> **VisualGasic is not a VB6 clone.** It is a modern, forward-looking language that draws inspiration from VB6's approachable syntax and ease of learning, while introducing advanced features that go well beyond what VB6 ever offered. If you know VB6, you'll feel at home in minutes. If you're new to programming, you'll find VG one of the easiest languages to learn.

> **Forms status (v5.6 → v6.0):** Prefer **Godot’s editor** with floating VG panels (Toolbox, Code Navigator, Properties, Vibe Code). The classic **Form Designer** / standalone shell is **experimental Alpha** ([VG IDE Alpha](../manual/VG_IDE_ALPHA.md)). **UI Forms** (WYSIWYG on the 2D viewport) is also experimental via **Project Settings → `vg/enable_experimental_plugins`**. Hybrid pattern: menu/UI scene + separate Node2D game scene — [Menu Form + Node2D Game](../guides/MENU_FORM_AND_2D_GAME.md).

---

## Why VisualGasic?

### Godot editor integration (supported path)

VisualGasic extends **Godot 4.6.1+** instead of replacing it:

- **VGasic workspace** — Floating **Code Navigator**, **Properties**, **Toolbox**, and **Vibe Code (Narcea)** over the Script / 2D / 3D editors
- **`.vg` code editor** — Syntax highlighting, IntelliSense (80+ function completions, 62+ VB6 property completions), snippets, Go To Definition — see [CODE_EDITOR.md](../manual/CODE_EDITOR.md)
- **Immediate Window & debugger** — Breakpoints, Watch, Call Stack, Step Over/Into/Out, REPL while paused
- **Narcea Vibe Code** — VG-aware assistant; optional **Live Debug Capture** while a game is running (local-only snapshots)
- **Forms** — **UI Forms** on the 2D viewport (experimental) or the legacy **Form Designer** ([VG IDE Alpha](../manual/VG_IDE_ALPHA.md)); 40+ toolbox controls and VB6-style event handlers (`Sub btnPlay_Click()`)

### ⚡ Performance

VisualGasic compiles to a **JIT-optimized bytecode engine** that outperforms GDScript in many benchmarks:

- O(1) **StringName HashMap** dispatch for all 62 VB6 property aliases
- **Computed-goto threaded interpreter** for the bytecode VM
- **GPU computing** with 19 SIMD methods (vector math, reduction, element-wise ops)
- **Real multithreading** with `Task.RunAsync`, `Parallel For`, and worker pools

### 🚀 Rapid Application Development

VisualGasic is built for **speed of development**:

- **Event-driven programming** — Write `Sub btnSave_Click()` and you're done. No signal wiring, no boilerplate.
- **One-line controls** — `CreateButton "Play", 100, 50, "OnPlay"` creates a button at (100, 50) and wires `pressed` to `Sub OnPlay()` in one call.
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

- **Port VB6-style logic** by rewriting as `.vg` (familiar syntax); bulk `.vbp`/`.frm` import is **not v6.0 core** — see [VB6 legacy import policy](../guides/IMPORTING_VB6.md) and optional [community importer manual](../community_plugins/VB6_IMPORTER_PLUGIN_MANUAL.md)
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

0. **[Quick Start](QUICK_START.md)** — Forms, 2D, and Narcea in one guide
1. **[Installation](installation.md)** — Set up VisualGasic in under 2 minutes
2. **[Nodes and Scenes](nodes_and_scenes.md)** — Understand Godot's building blocks
3. **[Scripting](scripting.md)** — Write your first VisualGasic code
4. **[Signals](signals.md)** — Handle events and user input

Also: [Get Started Guide](../guides/GET_STARTED.md) (installers + learning paths) · [Language Reference](../VisualGasic_Language_Reference.md).