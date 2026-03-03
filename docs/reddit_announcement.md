# REDDIT POST — VisualGasic Announcement
# ==================================================
# INSTRUCTIONS:
# 1. On Reddit's post editor, click "Markdown Mode" (toggle at the bottom)
# 2. Copy everything BETWEEN the two "--- COPY BELOW ---" lines
# 3. Paste into the Reddit markdown editor
# 4. For screenshots: use Reddit's image upload button to attach them
#    (external image URLs don't work on most subreddits)
#
# SUGGESTED TITLES (pick one):
#   r/godot:       I built a new programming language for Godot — VisualGasic: event-driven RAD with VB6-inspired syntax
#   r/visualbasic: VisualGasic — A VB6-inspired modern language for the Godot game engine
#   r/gamedev:     VisualGasic — A modern language for Godot 4 with automatic event binding, a form designer, and 66 demos
#   r/programming: VisualGasic — A modern VB6-inspired language for Godot with JIT compilation, async/await, and pattern matching
# ==================================================

--- COPY BELOW THIS LINE ---

Hey everyone! I've been building a new programming language for Godot and I'm finally ready to share it publicly.

**VisualGasic** (VG) is a modern, event-driven language that runs as a GDExtension for Godot 4.5+. It draws inspiration from Visual Basic 6's approachable syntax and RAD workflow — if you ever used VB6, you'll feel at home in minutes — but it's a modern language designed to look forwards, not backwards. Think of it less as "VB6 for Godot" and more as "what if someone designed a new language with VB6's simplicity but modern features?"

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
Form Designer | Full WYSIWYG with 40+ controls | None
Lambdas | `Lambda(x) => x * 2` | `func(x): return x * 2`
Null safety | `??` and `?.` operators | None built-in
Error handling | `Try/Catch/Finally` | None (just `push_error`)
Async | `Async/Await` + `Parallel For` | Coroutines only
String interpolation | `$"Hello, {name}!"` | `"Hello, %s" % name`
GPU computing | Built-in SIMD + compute shaders | Manual
Pattern matching | `Select Match` with destructuring | No
VB6 import | Direct `.frm`/`.vbp` import | N/A

VG also includes a **JIT compiler** that compiles hot loops to native x86-64, and in benchmarks it ranges from **2x to 118x faster than GDScript** depending on the workload, tying native C++ on some branching tasks.

&nbsp;

# Form Designer

VG ships with a **full VB6-style Form Designer** — a WYSIWYG editor with a Toolbox (40+ controls), a drag-and-drop canvas, a Properties panel, a Project Explorer, and a live preview window. You can design your UI visually and double-click any control to jump straight to its event handler. It's the RAD workflow that Visual Basic made famous, running inside Godot's editor.

&nbsp;

# What's included?

- **66 demo projects** across 12 categories: 2D games (Pong, Snake, Space Shooter, Platformer), 3D games (Squash the Creeps), graphics (screen-space shaders, volumetric sky shaders, screensaver), audio (piano), UI apps (calculator, todo list), threading, networking, and more
- **4 converted official Godot demos** — the 2D Platformer (9 VG scripts), Squash the Creeps, Screen Space Shaders (11 shader effects), and Sky Shaders — proving that real Godot projects run naturally in VG
- **IntelliSense** with 80+ function completions, snippet support, and Godot type awareness
- **Advanced debugger** with conditional breakpoints, watch window, call stack, time-travel debugging
- **108 built-in functions** (string, math, file I/O, date/time, formatting, collections, and more)
- **Platform binaries** for Linux, Windows, and macOS — just drop into your project and go
- **481 tests passing** in the test suite

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
- **Download**: [v3.3.0 release](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v3.3.0) (40 MB zip — includes all platform binaries and 66 demos)
- **License**: MIT

**Install:** copy `addons/visual_gasic/` into your Godot project → enable the plugin → create `.vg` files.

This is an early beta — the version number (3.3.0) reflects internal dev history, not maturity. I'd love feedback, bug reports, and feature requests. Thanks for checking it out!

--- COPY ABOVE THIS LINE ---
