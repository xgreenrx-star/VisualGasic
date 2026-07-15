# Why VisualGasic — Advantages Over GDScript

*A comprehensive reference for Godot developers evaluating VisualGasic.*

Version 5.2.0-Beta1 — Updated July 2026

---

## Overview

VisualGasic and GDScript are both scripting languages for Godot Engine. GDScript is Godot's built-in language; VisualGasic is a GDExtension that brings a VB6-inspired syntax plus a large set of features that GDScript does not offer.

This document covers **19 major capability categories** where VisualGasic provides functionality that GDScript lacks entirely or supports only in a limited way. It is not a "GDScript is bad" document — GDScript is excellent for what it does. This is a factual inventory of what VG adds on top.

**Related reading**: [Competitive Advantages — Godot-Rejected Features We Ship (and Skip)](../COMPETITIVE_ADVANTAGES.md) covers the strategic story behind *why* Godot's core team resists features like exception handling and abstract classes, and why VG can ship them safely without compromising its own design philosophy.

---

## Table of Contents

0. [Strategic Positioning — Why Godot Rejected These Features](#0-strategic-positioning--why-godot-rejected-these-features)
1. [Visual Form Designer (VB6-Style IDE)](#1-visual-form-designer)
2. [Automatic Event Wiring](#2-automatic-event-wiring)
3. [Performance & JIT Compilation](#3-performance--jit-compilation)
4. [GPU Computing & SIMD](#4-gpu-computing--simd)
5. [System-Level Programming](#5-system-level-programming)
6. [Real Threading & Parallelism](#6-real-threading--parallelism)
7. [Entity Component System (ECS)](#7-entity-component-system)
8. [Language Syntax Unique to VG](#8-language-syntax-unique-to-vg)
9. [Advanced Type System](#9-advanced-type-system)
10. [Functional Programming](#10-functional-programming)
11. [Interactive REPL](#11-interactive-repl)
12. [Package Manager](#12-package-manager)
13. [COM-Style Objects & VB6 Globals](#13-com-style-objects--vb6-globals)
14. [Professional Development Tools](#14-professional-development-tools)
15. [System Integration Modules](#15-system-integration-modules)
16. [Reactive Programming (Whenever Blocks)](#16-reactive-programming)
17. [String Interpolation & Null Safety](#17-string-interpolation--null-safety)
18. [VB6 Compatibility & Migration](#18-vb6-compatibility--migration)
19. [Summary Scorecard](#19-summary-scorecard)
20. [What VG Deliberately Did NOT Ship](#20-what-vg-deliberately-did-not-ship)

---

## 0. Strategic Positioning — Why Godot Rejected These Features

GDScript developers frequently request advanced language features on GitHub and Reddit. The Godot core team **consistently rejects or delays** these requests because GDScript's design philosophy prioritizes staying a lightweight, engine-integrated scripting glue — not a general-purpose language. Adding high-level architecture would grow the binary, slow parsing, and complicate the engine backend.

VisualGasic is not bound by that constraint. Because VG is a separate GDExtension with its own bytecode VM, it can implement exactly the features Godot's team has publicly resisted — without touching Godot's core.

| Feature | GDScript Status | VG Status |
|---------|------------------|-----------|
| **Try/Catch/Finally exception handling** | ❌ Rejected ("fail-safe, keep running" philosophy) | ✅ Shipped v5.0+ |
| **Method overloading** | ❌ Rejected (ClassDB/Variant architecture) | ✅ Shipped v3.7.0 |
| **Abstract classes / real interfaces** | ❌ Rejected (dynamic typing workarounds only) | ✅ Shipping v6.1 (`MustOverride`/`MustInherit`) |
| **Namespaces** | ⏳ Blocked (global class name cache) | ✅ Shipping v6.5.1 |
| **Generics for custom types** | ⏳ Blocked (`Array[int]` only, no custom `Array[T]`) | ✅ Shipping v6.5.1 |
| **Set / Tuple collections** | ⏳ Missing (Dictionary-keys hack) | ✅ Shipping v6.1 |

See [Competitive Advantages](../COMPETITIVE_ADVANTAGES.md) for direct links to the GitHub issues and community threads behind each rejection, plus a companion section explaining which Godot-requested features **VG also deliberately declined to ship** (multiple inheritance, macros, GC control, AOT compilation, C-style ternary) and why.

---

## 1. Visual Form Designer

**GDScript equivalent: None.**

VisualGasic includes a complete VB6-style WYSIWYG IDE built in C++:

| Feature | Description |
|---------|-------------|
| **Drag-and-Drop Canvas** | Place controls visually — click Toolbox, click canvas, done |
| **40+ Control Toolbox** | Standard (Button, Label, TextBox, ListBox, ComboBox, Timer), Extended (ProgressBar, Slider, SpinBox, RichText, TreeView, TabStrip), 2D Game (Sprite, CharacterBody, Area, Camera), 3D Game (MeshInstance, RigidBody3D, Camera3D, Lights), Optional (StatusBar, Toolbar, Calendar, DatePicker, ListView), Game UI (DialogPanel, InventoryGrid, StatBar, HUDCounter, CooldownButton, NotificationToast, GameMenu) |
| **Properties Panel** | 70+ VB6→Godot property translations (BackColor, ForeColor, FontName, FontSize, BorderStyle, Alignment, Locked, TabIndex, etc.) with Font/Color/Border sub-resource generation |
| **Live Preview** | Property changes appear instantly on the design canvas |
| **23 Form Templates** | VB6 Classic (Blank, Dialog, MDI, Splash), Game Forms (HUD, Inventory, Pause Menu), Platform-specific, Login, Custom |
| **7 Game UI Controls** | Animated Tier 1 controls with built-in Tween effects, Godot theme integration, and 30+ prototype properties each |
| **Custom Theme Editor** | 38 adjustable color pickers with live preview across 8 built-in IDE chrome themes |
| **Alignment Toolbar** | Align Left/Right/Top/Bottom, Center Horizontal/Vertical, Same Width/Height, Distribute Horizontally/Vertically |
| **Snap-to-Grid** | Configurable grid snapping for precise control placement |
| **Resize Handles** | Drag form edges and corners to resize, status bar shows dimensions |
| **Components Dialog** | VB6-style optional component manager; load custom `.tscn` prototypes |
| **Menu Editor** | Visual menu bar designer |
| **Object Browser** | Tools → Object Browser for Godot class hierarchy exploration |

GDScript has **no** form designer, no visual UI builder, no properties panel, no toolbox. All UI must be built manually in the Godot scene editor or constructed entirely via code.

**Example workflow** (VG IDE):
1. Click **Button** in Toolbox
2. Click canvas to place it
3. Set **(Name)** = `btnSave`, **Caption** = `Save`
4. Double-click → event handler `Sub btnSave_Click()` is created and wired

**Equivalent in GDScript** (manual):
1. Switch to 2D editor
2. Add a Button node to the scene tree
3. Set its `text` property in the Inspector
4. Switch to Script editor
5. Write `$btnSave.pressed.connect(_on_btn_save_pressed)`
6. Write the `func _on_btn_save_pressed():` handler

---

## 2. Automatic Event Wiring

**GDScript equivalent: Explicit `signal.connect()` calls required for every signal.**

VisualGasic wires events by **naming convention** — no boilerplate:

| VG Feature | How It Works |
|-----------|-------------|
| **Control events** | Name a Sub `btnSave_Click()` and it connects to the `pressed` signal of the node named `btnSave` automatically |
| **Timer events** | `Sub tmrSpawn_Timer()` fires when the timer named `tmrSpawn` times out — no `connect()` needed |
| **Godot signals** | `Sub Player_AreaEntered(area)` connects to the `area_entered` signal of the `Player` node by naming convention |
| **WithEvents keyword** | `Dim WithEvents obj As SomeClass` — when you `Set obj = instance`, all matching `Sub obj_EventName()` handlers are wired automatically |
| **RaiseEvent** | `RaiseEvent MyEvent(args)` fires custom events to all WithEvents subscribers via `emit_signal` |
| **IDE double-click** | Double-click any control on the form canvas → handler Sub is created and wired instantly |

```vb
' VG — just name the Sub, it's wired automatically
Sub btnSave_Click()
    SaveDocument
End Sub

Sub tmrAutoSave_Timer()
    AutoSave
End Sub

Sub Player_AreaEntered(area)
    If TypeOf area Is Coin Then CollectCoin area
End Sub
```

```gdscript
# GDScript — you must wire every signal manually
func _ready():
    $btnSave.pressed.connect(_on_btn_save_pressed)
    $tmrAutoSave.timeout.connect(_on_tmr_auto_save_timeout)
    $Player.area_entered.connect(_on_player_area_entered)

func _on_btn_save_pressed():
    save_document()

func _on_tmr_auto_save_timeout():
    auto_save()

func _on_player_area_entered(area):
    if area is Coin:
        collect_coin(area)
```

VG eliminates **100%** of `signal.connect()` boilerplate. In a project with 50 signals, that's 50 fewer `connect()` calls to write and maintain.

---

## 3. Performance & JIT Compilation

**GDScript equivalent: Bytecode VM with no optimizer and no JIT.**

VisualGasic is compiled to bytecode like GDScript, but with significantly more optimization:

| VG Feature | Description | GDScript |
|-----------|-------------|----------|
| **108+ bytecode opcodes** | Rich instruction set including specialized dict/array ops | ~80 opcodes |
| **9-pass peephole optimizer** | Constant folding, dead code elimination, jump threading, strength reduction, identity ops, debug stripping | None |
| **Computed-goto dispatch** | GCC/Clang `&&label` + `goto *dispatch_table[op]` for ~20% faster VM loop | Standard switch-case |
| **JIT Compiler (Tier 2)** | x86-64 native code generation for hot loops and arithmetic | None |
| **Loop fusion** | Recognizes patterns and fuses entire loops into single opcodes | None |
| **VGFastStringDict** | Custom open-addressing hash table with pre-hashed keys, 1-entry inline cache | Uses Godot Dictionary |
| **Escape analysis** | Sole-ownership dictionary tracking to avoid copy-on-write overhead | None |

### Benchmark Results

All 11 benchmarks faster than GDScript. VG wins 6/9 head-to-head vs native C++:

| Benchmark | GDScript | VisualGasic | Speedup | vs C++ |
|-----------|----------|-------------|---------|--------|
| Arithmetic | 5,333 µs | 331 µs | **16×** | 0.2× |
| ArraySum | 4,644 µs | 130 µs | **36×** | 0.3× |
| StringConcat | 5,007 µs | 60 µs | **83×** 🚀 | **8× faster** 🔥 |
| Branching | 6,988 µs | 59 µs | **118×** 🚀 | **tied** 🔥 |
| ArrayDict | 11,441 µs | 3,834 µs | **3×** | **1.1× faster** |
| DictFastGet | 29,177 µs | 2,210 µs | **13×** | — |
| DictFastSet | 19,266 µs | 2,519 µs | **7.6×** | — |
| Interop | 8,096 µs | 120 µs | **67×** 🚀 | **57× faster** 🔥 |
| Allocations | 6,871 µs | 128 µs | **54×** 🚀 | **3.7× faster** 🔥 |
| AllocationsFast | 10,309 µs | 1,817 µs | **5.7×** | 0.2× |
| FileIO | 982 µs | 456 µs | **2.2×** | 0.8× |

**Bottom line:** VG runs 2×–118× faster than GDScript across every workload tested. Branching ties native C++ at 59 µs. String concatenation is 83× faster than GDScript and 8× faster than C++.

---

## 4. GPU Computing & SIMD

**GDScript equivalent: None. You must write GLSL compute shaders manually.**

VisualGasic provides a `VGGpu` class with 19 bound methods for GPU-accelerated vector math:

```vb
' VG — GPU-accelerated vector operations
Dim result() As Single
result = VGGpu.VectorAdd(arrayA, arrayB)
Dim dot As Single = VGGpu.DotProduct(vecA, vecB)
Dim normalized() As Single = VGGpu.Normalize(vec)
Dim avg As Single = VGGpu.Average(data)
Dim clamped() As Single = VGGpu.Clamp(data, 0.0, 1.0)
```

| Method | Description |
|--------|-------------|
| VectorAdd / VectorSub / VectorMul / VectorDiv | Element-wise operations |
| DotProduct | Dot product of two vectors |
| Length / Normalize / Scale | Vector utilities |
| Sum / Min / Max / Average | Reduction operations |
| Abs / Clamp / Lerp | Per-element math |

All operations use SIMD hardware when available, with automatic CPU fallback for headless/CI environments.

---

## 5. System-Level Programming

**GDScript equivalent: The `OS` singleton provides basic process launching and environment variable access. Nothing more.**

VisualGasic provides 7 dedicated system modules:

| Module | Capabilities | GDScript? |
|--------|-------------|-----------|
| **VGSystem** | Hostname, CPU name/count/architecture, RAM total/free/used, disk space, OS details, uptime, locale, timezone | ❌ |
| **VGSignalHandler** | Handle SIGINT, SIGTERM, SIGHUP, SIGUSR1/2, atexit; Windows `SetConsoleCtrlHandler` | ❌ |
| **VGFilePermissions** | chmod, chown, symlinks, hard links, file locking (flock/LockFileEx), VB6 GetAttr/SetAttr | ❌ |
| **VGMemoryBuffer** | Peek/Poke byte-level read/write (Int8–Int64, Float, Double, String), CopyMemory, HexDump, raw FFI pointer interop | ❌ |
| **VGIPC** | Named pipes (mkfifo/CreateNamedPipe), UNIX domain sockets, shared memory (shm_open/mmap) | ❌ |
| **VGAndroidBridge** | JNI: device info, permissions, intents, toast, vibrate, battery, storage | ❌ |
| **Native FFI** | `Declare Function ... Lib "..." Alias "..."` — call arbitrary C functions via dlopen + libffi | ❌ |

```vb
' VG — system-level programming
Print VGSystem.Hostname          ' "devbox"
Print VGSystem.CPUName           ' "AMD Ryzen 9 7950X"
Print VGSystem.TotalRAM          ' 67108864 (bytes)

VGSignalHandler.OnSigInt(AddressOf HandleCtrlC)

VGFilePermissions.Chmod "/tmp/data.txt", &o644

Dim buf As New VGMemoryBuffer(1024)
buf.PokeInt32 0, 42
Print buf.PeekInt32(0)          ' 42

Declare Function strlen Lib "libc.so.6" (ByVal s As String) As Long
Print strlen("Hello")           ' 5
```

---

## 6. Real Threading & Parallelism

**GDScript equivalent: `Thread.new()` with manual start/wait_to_finish. No parallel-for, no task coordination, no work-stealing.**

| VG Feature | Description | GDScript |
|-----------|-------------|----------|
| **Task.Run** | Run a Callable on a real `std::thread` with per-thread scope cloning | Manual `Thread.new()` only |
| **Parallel For** | Auto-partitioned loop across `hardware_concurrency()` cores; serial fallback for ≤4 iterations | ❌ |
| **Parallel Section** | Atomic work-stealing pattern for heterogeneous tasks | ❌ |
| **VGTask** | RunAsync, RunDelayed, Cancel, WaitForResult, Progress tracking | ❌ |
| **VGTaskRunner** | RunAllLimited — bounded concurrent task execution | ❌ |

```vb
' VG — parallel processing
Parallel For i = 0 To 999999
    ProcessChunk(i)
Next

Dim task = Task.Run(Lambda() = ExpensiveCalculation())
' ...do other work...
Dim result = task.WaitForResult()
```

```gdscript
# GDScript — manual threading
var thread = Thread.new()
thread.start(_expensive_calculation)
# ...do other work...
var result = thread.wait_to_finish()
# No parallel-for. You'd need to manually partition and manage N threads.
```

---

## 7. Entity Component System

**GDScript equivalent: None. Godot uses a scene-tree/node hierarchy, not ECS.**

VisualGasic's `VGEcs` class provides 18 methods for high-performance ECS:

```vb
Dim ecs As New VGEcs

' Create entities with components
Dim player = ecs.CreateEntity()
ecs.AddComponent player, "Position", {"x": 100, "y": 200}
ecs.AddComponent player, "Health", {"current": 100, "max": 100}
ecs.AddComponent player, "Velocity", {"dx": 0, "dy": 0}

' Query entities
Dim movers = ecs.Query(Array("Position", "Velocity"))
For Each entity In movers
    Dim pos = ecs.GetComponent(entity, "Position")
    Dim vel = ecs.GetComponent(entity, "Velocity")
    pos.x = pos.x + vel.dx
    pos.y = pos.y + vel.dy
Next

' Serialize/deserialize for save games
Dim saveData = ecs.Serialize()
ecs.Deserialize(saveData)
```

This is useful for games with thousands of entities (bullet-hell, RTS, simulation) where the scene-tree model becomes a bottleneck.

---

## 8. Language Syntax Unique to VG

GDScript's `match` statement, `for i in range()` loops, and basic type hints cover common needs. VisualGasic adds **30+ syntax features** that GDScript does not have:

### Control Flow

| VG Feature | Example | GDScript? |
|-----------|---------|-----------|
| **Select Case with ranges** | `Case 1 To 10` | ❌ (`match` has no ranges) |
| **Select Case multi-value** | `Case 1, 3, 5, 7` | ❌ |
| **Select Case comparisons** | `Case Is > 100` | ❌ |
| **Select Match with guards** | `Case Is String s When Len(s) > 5` | ❌ (no `When` guard clauses) |
| **With...End With** | `With obj : .X = 1 : .Y = 2 : End With` | ❌ |
| **GoTo / GoSub / Return** | `GoTo ErrorHandler` / `GoSub InitData` | ❌ |
| **On Error Resume Next** | `On Error Resume Next` — skip errors | ❌ |
| **On Error GoTo** | `On Error GoTo Handler` — structured recovery | ❌ |
| **Resume / Resume Next** | Continue after error at same line or next line | ❌ |
| **On n GoTo / GoSub** | `On index GoTo Label1, Label2, Label3` — computed branch | ❌ |
| **Try / Catch / Finally** | `Try ... Catch ex As NetworkException ... Finally ... End Try` — structured exception handling with typed catch clauses | ❌ (Godot rejected this; see [Competitive Advantages](../COMPETITIVE_ADVANTAGES.md)) |

### Data & Memory

| VG Feature | Example | GDScript? |
|-----------|---------|-----------|
| **ReDim Preserve** | `ReDim Preserve arr(newSize)` — resize keeping data | ❌ |
| **Erase** | `Erase arr` — reset array to empty/default | ❌ |
| **Data / Read / Restore** | Embedded data tables with labeled sections and typed reads | ❌ |
| **Static local variables** | `Static count As Integer` — persists across calls | ❌ |
| **Using...End Using** | `Using f = Open("file") ... End Using` — auto-cleanup | ❌ |
| **Swap** | `Swap a, b` — swap two variables | ❌ |

### Parameters & Operators

| VG Feature | Example | GDScript? |
|-----------|---------|-----------|
| **ByRef parameters** | `Sub Increment(ByRef x As Integer)` — pass primitives by reference | ❌ |
| **Optional + IsMissing** | `Sub Log(Optional msg)` / `If IsMissing(msg) Then` | ⚠️ (default args only) |
| **Bit-shift operators** | `x << 3` / `x >> 2` — native operators with bytecode opcodes | ❌ |
| **Extended compound assignments** | `And=`, `Or=`, `Xor=`, `Mod=`, `\=`, `^=`, `<<=`, `>>=` | ❌ (GDScript has `+=` `-=` `*=` `/=` only) |

### Code Organization

| VG Feature | Example | GDScript? |
|-----------|---------|-----------|
| **Module...End Module** | Code organization blocks | ❌ |
| **Implements** | `Implements ISerializable` — interface verification | ❌ |
| **Friend visibility** | Module-level visibility between project files | ❌ |
| **Import** | `Import "utils.vg"` — pull in definitions from another file | ⚠️ (`preload` loads scripts but different mechanism) |
| **ClassName** | `ClassName MyPlayer` — register a global class name | ✅ (`class_name`) |

---

## 9. Advanced Type System

**GDScript equivalent: Basic type hints (`var x: int`), `enum`, and `class_name`.**

| VG Feature | Example | GDScript? |
|-----------|---------|-----------|
| **Generics** | `Function Process(Of T)(data As T) As T` | ❌ |
| **Generic constraints** | `Where T Implements IComparable` | ❌ |
| **Optional types** | `Dim name As String?` with `.HasValue` / `.Value` | ❌ |
| **Union types** | `Dim value As Integer \| String \| Boolean` | ❌ |
| **`<Flags>` Enum** | Bitfield enums with `HasFlag()` and `ToString()` decomposition | ❌ |
| **Enum methods** | `.Parse()`, `.Values()`, `.ToString()`, compile-time dot access | ❌ |
| **Method overloading** | Same name, different parameter counts — arity-based dispatch | ❌ |
| **Parameterized constructors** | `Dim b = New Bullet(speed, angle, damage)` | ❌ (GDScript constructors take no args) |

```vb
' VG — generics
Function Max(Of T)(a As T, b As T) As T
    If a > b Then Max = a Else Max = b
End Function

Print Max(Of Integer)(10, 20)   ' 20
Print Max(Of String)("A", "Z")  ' Z

' VG — union types
Dim result As Integer | String
result = 42
result = "hello"   ' both valid

' VG — optional types
Dim name As String?
If name.HasValue Then Print name.Value
```

---

## 10. Functional Programming

**GDScript equivalent: Lambdas exist (`func(x): return x * 2`) but no built-in higher-order collection functions.**

| VG Feature | Example | GDScript? |
|-----------|---------|-----------|
| **Map** | `Map(arr, Fn(x) x * 2)` | ❌ |
| **Filter** | `Filter(arr, Fn(x) x > 10)` | ❌ |
| **Reduce** | `Reduce(arr, Fn(a, b) a + b, 0)` | ❌ |
| **Any** | `Any(arr, Fn(x) x > 100)` | ❌ |
| **All** | `All(arr, Fn(x) x > 0)` | ❌ |
| **Find** | `Find(arr, Fn(x) x.name = "Player")` | ❌ |
| **4 lambda syntaxes** | `Lambda`, `Fn`, `Function`, `Sub` with optional `=>` | 1 syntax only |
| **Block lambdas** | Multi-statement `Function(x) ... Return ... End Function` | ❌ |
| **StringBuilder** | `.Append()`, `.ToString()`, `.Replace()`, `.Insert()` | ❌ |

```vb
' VG — functional pipeline
Dim scores() = Array(85, 92, 67, 45, 98, 73, 88)
Dim topScores = Filter(scores, Fn(s) s >= 80)
Dim doubled = Map(topScores, Fn(s) s * 2)
Dim total = Reduce(doubled, Fn(a, b) a + b, 0)
Print total   ' (85+92+98+88)*2 = 726
```

```gdscript
# GDScript — manual loops required
var scores = [85, 92, 67, 45, 98, 73, 88]
var top_scores = []
for s in scores:
    if s >= 80:
        top_scores.append(s)
var total = 0
for s in top_scores:
    total += s * 2
print(total)
```

---

## 11. Interactive REPL

**GDScript equivalent: None.**

VisualGasic provides an interactive Read-Eval-Print Loop:

| Feature | Description |
|---------|-------------|
| **Immediate Window** | In-editor bottom panel — type VG expressions, see instant results |
| **Variable inspection** | `:vars` lists all variables with types and values |
| **Session save/load** | Persist REPL state across editor restarts |
| **Data breakpoints** | `:wp add health` — break when a variable changes |
| **Remote debugging** | Connect to a running game instance, evaluate expressions live |
| **Refactoring** | Ctrl+R rename in scope / script / project-wide |

GDScript's closest equivalent is the expression evaluator in Godot's debugger, which only works when paused at a breakpoint and cannot define variables or persist state.

---

## 12. Package Manager

**GDScript equivalent: None. The Godot Asset Library is GUI-only and project-scoped.**

| VG Feature | Description |
|-----------|-------------|
| **InstallPackage** | Install packages from registries |
| **search_packages** | Search available packages by keyword |
| **publish_package** | Publish your own packages |
| **Semantic versioning** | `^1.0.0`, `~1.2.0`, `>=2.0.0` constraints |
| **vgpkg.json** | Project manifest with `add_dependency` |
| **AddRegistry** | Add custom package registries |

```vb
' VG — package management
VGPackage.InstallPackage "json-utils", "^2.0.0"
VGPackage.InstallPackage "math-extra", "~1.5.0"

Dim results = VGPackage.SearchPackages("physics")
For Each pkg In results
    Print pkg.name & " v" & pkg.version
Next
```

---

## 13. COM-Style Objects & VB6 Globals

**GDScript equivalent: None.**

VisualGasic emulates VB6's global object model and COM-style programming:

### Global Objects

| Object | Properties/Methods |
|--------|-------------------|
| **App** | Path, EXEName, Title, Major, Minor, Revision |
| **Screen** | Width, Height, TwipsPerPixelX/Y |
| **Err** | Number, Description, Source, Clear, Raise |
| **Printer** | Print, EndDoc, NewPage, Circle, Line, PaintPicture, PSet |

### COM and ProgID

| Feature | Description |
|---------|-------------|
| **CreateObject()** | `CreateObject("VBScript.RegExp")` — ProgID-based object creation |
| **VGRegEx** | VBScript.RegExp emulation: Test, Execute, Replace |
| **VGHttpRequest** | MSXML2.XMLHTTP emulation: Open, Send, responseText, Status |
| **VGCollection** | 1-based ordered collection with string keys |
| **Real COM (Windows)** | `CreateObject("Excel.Application")` via CoCreateInstance/IDispatch |

```vb
' VG — VB6-style global objects
Print App.Path                  ' Project directory
Print App.Title                 ' Application name
Print Screen.Width              ' Display width

' VG — COM-style objects
Dim re = CreateObject("VBScript.RegExp")
re.Pattern = "\d+"
re.Global = True
Dim matches = re.Execute("abc123def456")
For Each m In matches
    Print m.Value               ' "123", "456"
Next

' VG — error handling
On Error Resume Next
Dim x = 1 / 0
If Err.Number <> 0 Then
    Print "Error: " & Err.Description
    Err.Clear
End If
```

---

## 14. Professional Development Tools

GDScript has basic code completion, go-to-definition, and a debugger. VisualGasic adds:

| VG Tool | Description | GDScript? |
|---------|-------------|-----------|
| **Time-travel debugging** | Step backwards through execution history | ❌ |
| **Data breakpoints** | Break when a variable's value changes | ❌ |
| **Conditional breakpoint expressions** | `health < 10 And enemy_count > 5` | ❌ (basic breakpoints only) |
| **Watch Window** | Color-coded variable watching with change highlighting, persistence across sessions | ⚠️ (basic inspector) |
| **Snippet Manager** | 40+ built-in snippets + custom snippet creation | ❌ |
| **Code Linter** | 10 issue codes (VG001–VG010): unused variables, unreachable code, shadowing, etc. | ⚠️ (basic warnings) |
| **Integrated Profiler UI** | Hot-path coloring, per-function timing, JSON export | ❌ (separate Godot profiler) |
| **8 IDE Themes** | Ocean, Forest, Sunset, Midnight, Classic VB6, Monokai, Solarized, Nord | ❌ |
| **Custom Theme Editor** | 38 adjustable colors with live preview | ❌ |
| **Object Browser** | Browse all Godot classes, methods, properties, signals | ❌ |
| **Code Formatter** | Auto-indent, keyword capitalization, line spacing | ⚠️ (external `gdformat`) |
| **Refactoring** | Ctrl+R rename in scope / script / project-wide | ❌ |
| **Find All References** | Show every usage of a symbol across all .vg files | ⚠️ (basic) |

---

## 15. System Integration Modules

**GDScript equivalent: `HTTPRequest` node, basic `FileAccess`, and limited `Crypto`. Nothing else.**

| Module | Capabilities | GDScript? |
|--------|-------------|-----------|
| **VGOdbc** | ODBC database connectivity — PostgreSQL, MySQL, SQL Server, SQLite; parameterized queries, transactions | ❌ |
| **VGCrypto** | MD5, SHA1, SHA256, AES-256-CBC, HMAC, Base64, UUID | ⚠️ (limited Crypto class) |
| **VGXml** | XML load/save/parse with XPath-style queries | ❌ |
| **VGZip** | Create, read, extract ZIP archives | ❌ |
| **VGProcess** | Full cross-platform process spawning (Linux + Windows) | ⚠️ (`OS.execute` only) |
| **VGSocket** | Cross-platform POSIX + WinSock2 sockets | ❌ |
| **VGFileWatcher** | File change notification (inotify / FindFirstChangeNotification) | ❌ |
| **VGSysTray** | System tray icon (Shell_NotifyIcon on Windows) | ❌ |

```vb
' VG — database access
Dim db As New VGOdbc
db.Connect "Driver={PostgreSQL};Server=localhost;Database=mydb;Uid=user;Pwd=pass;"
Dim rs = db.Execute("SELECT name, score FROM players WHERE score > ?", Array(100))
Do While Not rs.EOF
    Print rs("name") & ": " & rs("score")
    rs.MoveNext
Loop
db.Disconnect

' VG — ZIP archive
Dim zip As New VGZip
zip.Create "backup.zip"
zip.AddFile "save1.dat"
zip.AddFile "save2.dat"
zip.Close

' VG — XML processing
Dim xml As New VGXml
xml.Load "config.xml"
Dim title = xml.SelectSingleNode("//game/title").text
```

---

## 16. Reactive Programming

**GDScript equivalent: None.**

VisualGasic's `Whenever` blocks provide declarative reactive programming:

```vb
' VG — reactive variable watching
Whenever Section Changes(health)
    UpdateHealthBar
    If health <= 0 Then GameOver
End Whenever

Whenever Section Exceeds(score, 1000)
    UnlockAchievement "High Score"
End Whenever

Whenever Section Below(fuel, 10)
    ShowWarning "Low Fuel!"
End Whenever
```

These blocks fire **automatically** when the monitored variable meets the condition. You can control them at runtime:

```vb
Suspend Whenever       ' Pause all reactive blocks
Resume Whenever        ' Resume all reactive blocks
Print ActiveWheneverCount()  ' Number of active blocks
Print WheneverStatus("health")  ' Status of a specific block
```

GDScript has signals and `@tool` scripts that react to inspector changes, but no declarative variable-watching blocks that fire automatically at runtime.

---

## 17. String Interpolation & Null Safety

**GDScript equivalent: None for either feature.**

### String Interpolation

```vb
' VG — embedded expressions in strings
Dim name = "World"
Dim count = 42
Print $"Hello {name}, you have {count} items!"
Print $"Total: {price * quantity}"
Print $"Upper: {UCase(name)}"
```

```gdscript
# GDScript — manual concatenation
var name = "World"
var count = 42
print("Hello " + name + ", you have " + str(count) + " items!")
print("Total: " + str(price * quantity))
print("Upper: " + name.to_upper())
```

### Null Safety

```vb
' VG — null-coalescing operator
Dim displayName = username ?? "Anonymous"

' VG — null-safe navigation
Dim city = user?.Address?.City
If city <> Nothing Then Print city

' Chained null-safe access
Dim hp = game?.Player?.Stats?.Health ?? 100
```

GDScript has no `??` operator and no `?.` navigation. You must write explicit null checks:

```gdscript
# GDScript — verbose null checking
var display_name = username if username != null else "Anonymous"
var city = null
if user != null and user.address != null:
    city = user.address.city
```

---

## 18. VB6 Compatibility & Migration

**GDScript equivalent: Not applicable.**

VisualGasic can run and port existing VB6 code:

| Feature | Description |
|---------|-------------|
| **VB6 syntax** | Dim, If/Then/Else, For/Next, Do/Loop, Select Case, GoTo, GoSub, On Error |
| **VB6 file I/O** | `Open For Binary/Random/Append`, `Print #`, `Write #`, `Input #`, `Line Input #`, `Get #`, `Put #` with mode/access/lock keywords |
| **108+ VB6 functions** | MkDir, RmDir, ChDir, CurDir, FileCopy, Environ, QBColor, Weekday, MonthName, and many more |
| **VB6 constants** | `vbCrLf`, `vbTab`, `vbNullString`, `vbQuote`, `vbSpace`, `vbComma`, `vbPipe`, `PI`, `E`, `vbOKOnly`, `vbYesNo`, `KEY_*` |
| **Data/Read/Restore** | Embedded data tables with labeled sections, typed reads, 14 introspection functions |
| **VB6 project import** | `.vbp` / `.frm` / `.bas` file parsing and migration |
| **VB6-style error handling** | `On Error GoTo`, `On Error Resume Next`, `Err.Number`, `Err.Description`, `Resume` |

If you have existing VB6 projects, VisualGasic can import them. See the [Migration Guide](MIGRATION_GUIDE.md) and [Importing VB6](IMPORTING_VB6.md) for details.

---

## 19. Summary Scorecard

| # | Capability | VG | GDScript |
|---|-----------|:---:|:--------:|
| 1 | Visual Form Designer (40+ controls) | ✅ | ❌ |
| 2 | Automatic Event Wiring | ✅ | ❌ |
| 3 | JIT Compilation | ✅ | ❌ |
| 4 | 9-Pass Peephole Optimizer | ✅ | ❌ |
| 5 | GPU Computing / SIMD | ✅ | ❌ |
| 6 | System-Level Programming (7 modules) | ✅ | ❌ |
| 7 | Real Threading (Parallel For) | ✅ | ❌ |
| 8 | Entity Component System | ✅ | ❌ |
| 9 | Interactive REPL | ✅ | ❌ |
| 10 | Package Manager | ✅ | ❌ |
| 11 | Generics / Union Types / Optional Types | ✅ | ❌ |
| 12 | String Interpolation `$""` | ✅ | ❌ |
| 13 | Null Safety (`??` / `?.`) | ✅ | ❌ |
| 14 | FFI / COM / Native Calls | ✅ | ❌ |
| 15 | ODBC / Crypto / XML / ZIP | ✅ | ❌ |
| 16 | Reactive Whenever Blocks | ✅ | ❌ |
| 17 | Time-Travel Debugging | ✅ | ❌ |
| 18 | Custom Theme Editor (38 colors) | ✅ | ❌ |
| 19 | VB6 Migration Tools | ✅ | N/A |
| 20 | Try/Catch/Finally Exception Handling | ✅ | ❌ (rejected by Godot) |
| 21 | Method Overloading (arity-based) | ✅ | ❌ (rejected by Godot) |
| 22 | Abstract Classes (`MustOverride`/`MustInherit`) | 🔹 v6.1 | ❌ (rejected by Godot) |

**19 major capability categories** where VisualGasic provides functionality that GDScript does not — plus 3 additional Godot-rejected features tracked separately since they are a strategic, not just technical, differentiator (see [Strategic Positioning](#0-strategic-positioning--why-godot-rejected-these-features) above).

---

## When to Choose VG Over GDScript

| Scenario | Recommendation |
|----------|----------------|
| You want visual drag-and-drop UI design | **VG** — Form Designer + Toolbox |
| You need maximum scripting performance | **VG** — 2×–118× faster, JIT compiled |
| You have existing VB6 code to port | **VG** — native VB6 syntax + import tools |
| You want zero-boilerplate event handling | **VG** — automatic wiring by naming |
| You need database access (ODBC) | **VG** — VGOdbc module |
| You need FFI / native library calls | **VG** — Declare statement + libffi |
| You need parallel processing | **VG** — Parallel For, Task.Run |
| You want reactive variable watching | **VG** — Whenever blocks |
| You prefer functional Map/Filter/Reduce | **VG** — built-in collection functions |
| You need GPU-accelerated math | **VG** — VGGpu class |
| You want an interactive REPL | **VG** — Immediate Window |
| You need null-safe navigation | **VG** — `??` and `?.` operators |

## When GDScript May Be Preferred

| Scenario | Reason |
|----------|--------|
| Smallest possible learning curve | GDScript is Godot's native language with the most tutorials |
| Maximum community support | Larger GDScript community and more StackOverflow answers |
| Shader language similarity | GDScript's Python-like syntax is closer to GLSL |
| You only need basic scripting | GDScript covers simple game logic well |

---

## 20. What VG Deliberately Did NOT Ship

Not every feature Godot rejected is a feature VG chose to add. Some requests — multiple inheritance, macros/metaprogramming, manual garbage collection control, AOT compilation to native code, and the C-style ternary operator — were reviewed and **deliberately declined** for readability, transparency, or performance reasons that align with VG's own design philosophy, not just Godot's.

The short version: VG ships what Godot rejected **on principle** (Try/Catch, overloading, abstract classes) and skips what Godot rejected **for good reason** (multiple inheritance, macros). One exception is nuanced: VG skips C-style ternary syntax but ships `IIf(condition, true, false)` as a short-circuit AST node — safer than both C-style ternary and classic VB6's `IIf` (which evaluates both branches). See the full breakdown, rationale, and code examples in [Competitive Advantages — What We Deliberately Did NOT Ship](../COMPETITIVE_ADVANTAGES.md#-what-vg-deliberately-did-not-ship-and-why).

---

## Further Reading

- [Competitive Advantages — Godot-Rejected Features We Ship (and Skip)](../COMPETITIVE_ADVANTAGES.md) — the strategic narrative, GitHub issue references, and "what we didn't ship" rationale
- [GDScript ↔ VisualGasic Quick Reference](../GODOT_PROGRAMMING_MANUAL.md#gdscript-vs-vg) — side-by-side syntax mapping
- [Modern Features Guide](MODERN_FEATURES_README.md) — deep dive into VG's modern extensions
- [System Integration Reference](../SYSTEM_INTEGRATION.md) — FFI, ODBC, Crypto, XML, ZIP, IPC, Threading
- [Visual Gasic IDE Tools](../manual/ide_tools.md) — complete IDE tools guide
- [Performance Benchmarks](../manual/performance.md) — detailed benchmark methodology and results
