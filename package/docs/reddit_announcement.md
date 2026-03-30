# REDDIT POST — VisualGasic Announcement
# ==================================================
# INSTRUCTIONS:
# 1. On Reddit's post editor, click "Markdown Mode" (toggle at the bottom)
# 2. Copy everything BETWEEN the two "--- COPY BELOW ---" lines
# 3. Paste into the Reddit markdown editor
# 4. For screenshots: use Reddit's image upload button to attach them
#    (external image URLs don't work on most subreddits)
#
# STRONGLY RECOMMENDED: Include screenshots or a short GIF!
#   - Visual Gasic IDE with a form open (Toolbox + canvas + Properties panel)
#   - The code editor showing a .vg file with IntelliSense
#   - A running demo (Pong or the calculator)
#   On r/godot especially, image/video posts get 5-10x the engagement of text posts.
#   Consider making this an IMAGE post with the text as the first comment.
#
# SUGGESTED TITLES (pick one):
#   r/godot:       I built a VB6-inspired language for Godot with a Visual Gasic IDE, JIT compiler, and 66 demos
#   r/visualbasic: VisualGasic — A VB6-inspired modern language for the Godot game engine (Visual Gasic IDE, custom controls, JIT)
#   r/gamedev:     VisualGasic — A RAD language for Godot 4 with the Visual Gasic IDE, auto event binding, and 66 demos
#   r/programming: VisualGasic — A modern VB6-inspired language for Godot with JIT compilation, async/await, and the Visual Gasic IDE
# ==================================================

--- COPY BELOW THIS LINE ---

Design a form, double-click a button, write code. If you've ever used VB6, you know the workflow. I built that for Godot.

**VisualGasic** (VG) is a modern, event-driven language that runs as a GDExtension for Godot 4.5+. Yes, the name is a pun — but the language is serious. It draws inspiration from Visual Basic 6's approachable syntax and RAD workflow, but it's designed to look forwards, not backwards. Think of it less as "VB6 for Godot" and more as "what if someone designed a new language with VB6's simplicity but modern features?"

&nbsp;

# What does it look like?

    ' A simple game script in VisualGasic
    Dim ballX As Single = 400
    Dim ballSpeedX As Single = 5

    Sub _Process(delta As Single)
        ballX = ballX + ballSpeedX * delta * 60
        If ballX > 780 Or ballX < 20 Then
            ballSpeedX = -ballSpeedX
        End If
    End Sub

    ' This event handler is wired AUTOMATICALLY by name
    Sub btnStart_Click()
        Print "Game started!"
    End Sub

No `connect()` calls, no signal boilerplate. Name a Sub `btnStart_Click()` and it's wired to the button's `pressed` signal automatically. Name it `tmrSpawn_Timer()` and it fires on the timer. Name it `Player_AreaEntered(area)` and it hooks the Godot signal. This is the core workflow idea — **event-driven programming** like classic RAD tools, but running natively inside Godot.

&nbsp;

# What makes it different from GDScript?

Feature | **VisualGasic** | **GDScript**
---|---|---
Event binding | Automatic by naming convention | Manual `connect()` or `@onready`
Visual Gasic IDE | Full WYSIWYG with 40+ controls | —
Custom Controls | Build your own .tscn controls, drag onto forms | —
Lambdas | `Lambda(x) => x * 2` | `func(x): return x * 2`
Null safety | `??` and `?.` operators | Type hints help, but no operators
Error handling | `Try/Catch/Finally` | `push_error` (no structured handling)
Async | `Async/Await` + `Parallel For` | Coroutines
String interpolation | `$"Hello, {name}!"` | `"Hello, %s" % name`
GPU computing | Built-in SIMD + compute shaders | Manual setup
Pattern matching | `Select Match` with destructuring | `match` (basic)
VB6 import | Direct `.frm`/`.vbp` import | —

VG also includes a **JIT compiler** that compiles hot loops to native x86-64. On microbenchmarks (tight loops, math, branching) it ranges from **2x to 118x faster than GDScript** depending on the workload. The benchmark scripts are included in the repo so you can verify on your own machine.

&nbsp;

# Visual Gasic IDE

VG ships with a **full VB6-style Visual Gasic IDE** inside Godot's editor:

- **Toolbox** with 40+ built-in controls (buttons, text boxes, list views, tab strips, timers, and more)
- **Drag-and-drop canvas** with snap grid, alignment guides, and multi-select
- **Properties panel** with 30+ properties per control (appearance, behavior, font, position, effects like rotation/opacity/scale, layout, and type-specific settings)
- **Live preview window** that renders your form in real-time as you design
- **Project Explorer** for managing forms and modules
- **Custom Controls** — build your own reusable .tscn controls and they appear in the Toolbox alongside the built-ins

Double-click any control to jump straight to its event handler. It's the RAD workflow that Visual Basic made famous.

&nbsp;

# What's included?

- **66 demo projects** — 2D games (Pong, Snake, Space Shooter, Platformer), 3D (Squash the Creeps), shaders, audio, UI apps, threading, networking, and more
- **4 ported official Godot demos** — proving real Godot projects run naturally in VG
- **Custom Controls system** — create your own .tscn controls with a wizard, preview them in the designer, and share them across projects
- **IntelliSense** with 80+ function completions, 62+ VB6 property completions, snippets, and Godot type awareness
- **Debugger** with conditional breakpoints, watch window, call stack, and time-travel debugging
- **108 built-in functions** (string, math, file I/O, date/time, collections, and more)
- **Linux, Windows, and macOS binaries** — drop into your project and go
- **646 tests passing** (82 test files)

&nbsp;

# Who is this for?

- **VB6/VB.NET veterans** who want to make games with a familiar workflow
- **Beginners** looking for a readable, low-ceremony language
- **RAD developers** who miss the "design a form, double-click a button, write code" workflow
- **Anyone curious** about an alternative to GDScript with modern language features
- **Hobbyists porting old VB6 projects** — VG can import `.frm` and `.vbp` files directly

&nbsp;

# Get it

- **GitHub**: [https://github.com/xgreenrx-star/VisualGasic](https://github.com/xgreenrx-star/VisualGasic)
- **Download**: [v3.4.1 release](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v3.4.1) (includes all platform binaries and 66 demos)
- **License**: MIT

**Install:** copy `addons/visual_gasic/` into your Godot project → enable the plugin → create `.vg` files.

This is a solo project and still early — I'd love feedback, bug reports, and feature requests. Thanks for checking it out!

--- COPY ABOVE THIS LINE ---
