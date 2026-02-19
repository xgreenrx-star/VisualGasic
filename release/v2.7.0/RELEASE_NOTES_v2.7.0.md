# VisualGasic v2.7.0 Release Notes

**Release Date:** February 19, 2026
**Godot Version:** 4.5.1 (stable)
**Platforms:** Linux x86_64, Windows x86_64

---

## 🎯 Highlights

This release focuses on **Godot API completeness** and **robustness**, driven by a new automated ClassDB fuzzer that tests every corner of the Godot integration. Three real bugs were found and fixed, and the language now provides universal access to all 37 Godot engine singletons.

### ✅ 2421 Tests — Zero Failures

The expanded ClassDB fuzzer now runs **2421 automated tests** across 210 `.vg` files covering 854 instantiable Godot classes, all 37 singletons, and 11 different test categories — with **zero failures and zero VG errors**.

```
================================================================
  CLASSDB FUZZ RESULTS
================================================================
  ✅ PASSED:          2421
  ❌ FAILED:          0
  💥 VG ERRORS:       0
  ⚠  GODOT WARNINGS:  34  (engine-level, not VG bugs)
  ⏭  SKIPPED:         0
  📁 LOAD FAILURES:   0
  ⚙  UNSUPPORTED OPS: 0
  🔄 AST FALLBACKS:   0
```

---

## 🔧 Bug Fixes

### Universal Godot Singleton Resolution
Previously only `Input` and `Godot` were recognized as singletons. Now **all 37 registered Godot singletons** are accessible by name:

```vb
' Engine — performance monitoring
Dim fps As Integer = Engine.get_frames_per_second()
Dim isEditor As Boolean = Engine.is_editor_hint()

' OS — system information
Dim osName As String = OS.get_name()
Dim cpus As Integer = OS.get_processor_count()
Dim isDebug As Boolean = OS.is_debug_build()

' Time — timing
Dim ms As Integer = Time.get_ticks_msec()
Dim unix As Double = Time.get_unix_time_from_system()

' DisplayServer, AudioServer, and 30+ more
Dim mixRate As Double = AudioServer.get_mix_rate()
```

**Supported singletons:** Engine, OS, Time, Input, DisplayServer, AudioServer, RenderingServer, PhysicsServer2D, PhysicsServer3D, NavigationServer2D, NavigationServer3D, ProjectSettings, ResourceLoader, ResourceSaver, ClassDB, Performance, IP, Geometry2D, Geometry3D, ThemeDB, TranslationServer, Marshalls, InputMap, CameraServer, ResourceUID, TextServerManager, WorkerThreadPool, and more.

### Fix Method Call on Null Objects
`On Error Resume Next` now properly catches method calls on Null objects instead of silently pushing Null:

```vb
Sub SafeProcess()
    On Error Resume Next
    Dim obj As Variant = Nothing
    
    ' Previously: silently returned Null (bug)
    ' Now: raises "Method call on Null object" error, caught by On Error
    Dim result = obj.SomeMethod()
    
    If Err.Number <> 0 Then
        Print "Caught: " & Err.Description  ' "Method call on Null object: .SomeMethod"
        Err.Clear
    End If
End Sub
```

### Fix Enum Constants with Keyword Names
Godot enum constants whose names match VG keywords (like `READ`, `WRITE`) now resolve correctly:

```vb
' Previously: FileAccess.READ returned Null (bug)
' Now: correctly returns 1
Dim mode As Integer = FileAccess.READ       ' = 1
Dim rw As Integer = FileAccess.READ_WRITE   ' = 3
Dim wr As Integer = FileAccess.WRITE_READ   ' = 7
```

**Root cause:** The tokenizer normalized `READ` → `Read` (keyword form), but ClassDB expects `READ` (all caps). All four enum constant lookup paths now fall back to `.to_upper()` when the as-is name isn't found.

### Fix Singleton Instantiation Crash
Calling `.new()` on singleton classes like `ProjectSettings` no longer causes a SIGILL crash:

```vb
' Previously: SIGILL crash
' Now: returns the existing singleton instance
Dim ps = ProjectSettings.new()  ' Returns ProjectSettings singleton
```

### Fix RefCounted Object Lifetime
RefCounted subclasses (SphereMesh, StandardMaterial3D, etc.) are no longer freed immediately after creation. Objects now stay alive for the duration of their scope.

### Fix Bytecode Singleton Resolution
`Input`, `Godot`, `Me`, and `Super` in the bytecode VM were being resolved as nil local variables instead of their proper singleton/owner objects. Fixed in the compiler's `non_local_names` set.

### Fix Bytecode Dim-with-Initializer
`Dim x As Integer = expr` now compiles to bytecode instead of falling back to the AST interpreter.

---

## 🧪 Testing Improvements

### Expanded ClassDB Fuzzer

The fuzzer now includes **11 test categories** (up from 4):

| Category | Tests | Description |
|----------|-------|-------------|
| Instantiation | ~740 | Create objects from 854 Godot classes |
| Property Get/Set | ~460 | Read/write properties on instantiated objects |
| Enum Constants | ~280 | Verify ClassName.ENUM_VALUE for all class enums |
| Singleton Access | ~25 | Access 37 Godot singletons by name |
| Method Calls | ~480 | Call zero-arg getter methods on 80 classes |
| Setter Calls | ~160 | Call one-arg setter methods with safe defaults |
| Inheritance Chains | ~31 | Call ancestor methods on game-relevant classes |
| With Blocks | ~10 | With obj...End With on Godot objects |
| TypeOf/Is Tests | ~16 | TypeOf operator on Godot objects |
| Singleton Methods | ~20 | Engine/OS/Time/Input/DisplayServer/AudioServer methods |
| VG Language Features | ~4 | For Each, error handling, strings, vectors |

### Godot Warning Separation

Engine-level validation messages (orientation constraints, empty container index, physics null state, etc.) are now properly separated from VG errors in the fuzzer report. The 34 Godot warnings are displayed as informational, not counted as failures.

### Automated Bug-Finding Tools

New tools added to `tools/`:
- **`classdb_fuzzer.py`** — Full Godot API fuzzer (2421 tests)
- **`static_bug_finder.py`** — Static analysis of VG source code
- **`generate_coverage_tests.py`** — Auto-generate coverage tests (37 tests)

---

## 📊 Performance

Performance remains at **18.9× geometric mean faster than GDScript** across 11 benchmarks, beating C++ on 6 of 11 tests. No performance regressions in this release.

---

## 📸 Screenshots

### Fuzzer Results — 2421/0/0 Clean
![Fuzzer Results](docs/screenshots/Screenshot%20at%202026-02-17%2016-42-53.png)

### Singleton Access in Action
```vb
' All these singleton calls work out-of-the-box:
Print "OS: " & OS.get_name()                    ' "Linux"
Print "CPUs: " & str(OS.get_processor_count())   ' "12"
Print "FPS: " & str(Engine.get_frames_per_second())
Print "Time: " & str(Time.get_ticks_msec()) & "ms"
Print "Mix Rate: " & str(AudioServer.get_mix_rate())
```

### Demo Games
![Pong Demo](docs/screenshots/pong_demo.png)
![Galactic Defender](docs/screenshots/galactic_defender_demo.png)

---

## 📦 Release Contents

### Linux
- `libvisualgasic.linux.template_debug.x86_64.so` — Debug build
- `libvisualgasic.linux.template_release.x86_64.so` — Release build

### Windows
- `libvisualgasic.windows.template_debug.x86_64.dll` — Debug build
- `libvisualgasic.windows.template_release.x86_64.dll` — Release build

### Demos Included
- **2D Games:** Pong, Pong Advanced, Snake, Platformer, Space Shooter, Galactic Defender
- **3D Games:** Squash the Creeps
- **UI:** Calculator, Todo App
- **Audio:** Piano
- **Graphics:** Screen Space Shaders, Screensaver, Sky Shaders
- **Data:** High Scores
- **Threading:** Parallel Demo

### Addon Plugin
- `addons/visual_gasic/` — Drop-in Godot plugin with editor integration

---

## 📋 Full Changelog (since v2.4.2)

### v2.7.0
- Fix enum constants with keyword names (FileAccess.READ, .WRITE)
- Fuzzer: separate Godot engine warnings from VG errors
- Expand ClassDB fuzzer: 11 test types, 2421 passing tests
- Add universal Godot singleton resolution (37 singletons)
- Fix method call on Null objects (On Error Resume Next)
- Add ClassDB fuzzer + fix singleton instantiation crash
- Add static bug finder + coverage test generator
- Docs: Sky Shaders case study
- Fix RefCounted object lifetime (SphereMesh, StandardMaterial3D, etc.)
- Bytecode: fix singletons resolved as nil locals
- Bytecode: compile Dim x As T = expr
- Fix _Input dispatch: Is operator TypeOf check
- Fix AST evaluator: Godot class enum constants in MEMBER_ACCESS
- Fix Godot class enum constants + add mouse constants
- Fix parser/compiler for Input.xxx, function call bytecode, GDScript builtins
- Add GDScript-style % format operator

### v2.6.1
- Fix bytecode VM builtins (IsOnFloor, signals, Me.Method)
- Add Godot-native 2D Platformer demo

### v2.6.0
- Custom .vg file icons
- IntelliSense for new builtins
- Integrated profiler UI

### v2.5.0
- Computed-goto threaded dispatch (~20% faster VM)
- 11 new VB6 builtins
- Stop statement, conditional breakpoints
- 12 demo projects

---

## 🚀 Installation

1. Copy the `addons/visual_gasic/` folder into your Godot project
2. Enable the plugin in Project → Project Settings → Plugins
3. Create `.vg` files and start coding in VB6 syntax!

See the [Getting Started Guide](docs/getting_started/) for detailed instructions.

---

## 🙏 Acknowledgments

- The Godot Engine team
- The GDExtension / godot-cpp community
- All contributors, testers, and fuzzer-found-bug reporters
