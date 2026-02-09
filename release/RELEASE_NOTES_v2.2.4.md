# VisualGasic v2.2.4 Release Notes

**Release Date:** February 8, 2026  
**Type:** Bugfix & Feature Release

## Overview

This release completes **Section 4.1 Godot Integration** and **Section 4.2 Game-Specific Keywords** from the VG_TEST_CHECKLIST, adding comprehensive game development features including the reactive `Whenever` event system, sprite/sound creation, collision detection, and enhanced input handling.

---

## ✨ New Features

### Section 4.1: Godot Integration (Complete)

Full integration with Godot's node system is now verified and working:

| Feature | Status | Description |
|---------|--------|-------------|
| ✅ Node Properties | Complete | Access `Me.name`, `Me.position`, `Me.visible`, `Me.modulate` |
| ✅ Method Calls | Complete | Call `Me.get_class()`, `Me.has_method()`, `Me.queue_redraw()` |
| ✅ GetNode() | Complete | Navigate scene tree with `GetNode("path/to/node")` |
| ✅ Signal Connections | Complete | `Connect(node, "signal", "method")` for runtime connections |
| ✅ _Process() | Complete | Frame callback with `delta` parameter and `GetDelta()` |
| ✅ _Ready() | Complete | Initialization callback auto-called |
| ✅ Input System | Complete | Full Input singleton access (see below) |

### Section 4.2: Game-Specific Keywords (Complete)

#### Whenever Event System

The reactive `Whenever` system allows declarative event-driven programming:

```vb
Dim health As Integer = 100
Dim score As Integer = 0

' Declare reactive event blocks
Whenever Section Changes(health) Call OnHealthChange
Whenever Section Exceeds(score, 1000) Call OnHighScore

Sub OnHealthChange()
    Print "Health changed to: " & health
    If health <= 0 Then
        Print "Game Over!"
    End If
End Sub

Sub OnHighScore()
    Print "You reached 1000 points!"
End Sub

' Control whenever blocks at runtime
Suspend Whenever "Changes(health)"
Resume Whenever "Changes(health)"

' Query status
Dim count As Integer
count = ActiveWheneverCount()
Print WheneverStatus("Changes(health)")  ' Returns "active" or "suspended"
```

#### Sprite & Animation Support

```vb
' Create sprites
Dim mySprite As Object
Set mySprite = CreateNode("Sprite2D")
mySprite.position = Vector2(100, 100)

' Animated sprites
Dim animSprite As Object
Set animSprite = CreateNode("AnimatedSprite2D")
```

#### Sound & Audio

```vb
' Create audio player
Dim sound As Object
Set sound = CreateNode("AudioStreamPlayer")
sound.volume_db = -10

' Play sounds
PlaySound("res://sounds/explosion.wav")
```

#### Collision Detection

```vb
' Check collisions
If HasCollided() Then
    Print "Collision detected!"
End If

' Create trigger areas
Dim trigger As Object
Set trigger = CreateTrigger()

' Get collision info
Dim collisionCount As Integer
collisionCount = GetCollisionCount()
```

#### Keyboard Input

```vb
' Check key state
If IsKeyDown(KEY_SPACE) Then
    Jump()
End If

' Use Input singleton
If Input.IsKeyPressed(KEY_A) Then
    MoveLeft()
End If

' Get last key pressed (like VB6 KeyPress event)
Dim key As String
key = Inkey()

' All KEY_* constants available:
' KEY_A through KEY_Z, KEY_0 through KEY_9
' KEY_SPACE, KEY_ENTER, KEY_ESCAPE, KEY_TAB
' KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN
' KEY_SHIFT, KEY_CTRL, KEY_ALT, etc.
```

#### Mouse Input

```vb
' Check mouse button state
If IsMouseButtonDown(1) Then  ' 1 = left button
    Shoot()
End If

' Get mouse position
Dim mx As Integer, my As Integer
mx = GetMouseX()
my = GetMouseY()

' Or use Vector2
Dim mousePos As Variant
mousePos = Input.GetMousePosition()

' Check for mouse click (VB6-style)
If MouseClick() Then
    HandleClick()
End If
```

---

## 🐛 Bug Fixes

### Whenever System Fixes

1. **Module-level Whenever Sections now register correctly**
   - `Whenever Section` declarations at module level are now properly parsed and added to global statements
   - Previously, they were parsed but not executed during initialization

2. **Dim initializers now execute at module level**
   - `Dim x As Integer = 5` now correctly initializes `x` to `5`
   - Previously, variables with initializers were set to `0`

3. **Case-insensitive variable comparison in Whenever conditions**
   - Variable names are now compared case-insensitively in `check_whenever_conditions`
   - Matches VB6 behavior where `Health` and `health` are the same variable

### Parser Improvements

- Added `STMT_WHENEVER_SECTION` handling to global statements execution loop
- Module-level `Whenever Section` statements now added to `global_statements` during parsing
- `Dim` statements with initializers now properly added to `global_statements`

---

## 📝 Technical Details

### Files Modified

- **src/visual_gasic_instance.cpp**
  - Added game-specific functions: `ActiveWheneverCount()`, `WheneverStatus()`, `Inkey()`, `MouseClick()`, `MouseX()`, `MouseY()`
  - Added `STMT_WHENEVER_SECTION` handling in global statements execution (~line 1136)
  - Fixed case-insensitive variable comparison in `check_whenever_conditions` (~line 6676)
  - Modified `read_local` bytecode operation for better variable sync (~line 7375)

- **src/visual_gasic_parser.cpp**
  - Added module-level `Whenever Section` parsing (~lines 131-141)
  - Fixed `Dim` statements with initializers to add to `global_statements` (~lines 180-193)

- **tests/VG_TEST_CHECKLIST.md**
  - Updated Section 4.2 to mark all Game-Specific Keywords as complete

### New Test Files

- `demo/test_game_section42.vg` - Comprehensive test for Section 4.2 (22 tests)
- `demo/run_game_section.gd` - SceneTree-based test runner

### Known Issue

There is a bytecode compiler bug where very simple callback functions (single assignment) may not properly write to global variables. **Workaround**: Add a variable read before the assignment in callbacks:

```vb
Sub OnHealthChange()
    Dim x As Boolean = wheneverTriggered  ' Forces proper bytecode sync
    wheneverTriggered = True
End Sub
```

This will be investigated and fixed in a future release.

---

## 📊 Test Results

**Section 4.2 Game-Specific Keywords: 22/22 tests passing**

```
RESULTS: 22.0 passed, 0 failed
- [PASS] Whenever sections registered (count=2)
- [PASS] Whenever Changes trigger works
- [PASS] Whenever Exceeds trigger works
- [PASS] Suspend Whenever works
- [PASS] Resume Whenever works
- [PASS] CreateNode('Sprite2D') works
- [PASS] Sprite position property works
- [PASS] CreateNode('AnimatedSprite2D') works
- [PASS] CreateNode('AudioStreamPlayer') works
- [PASS] Sound volume_db property works
- [PASS] PlaySound function available
- [PASS] HasCollided() function works
- [PASS] CreateTrigger() function works
- [PASS] GetCollisionCount() function works
- [PASS] IsKeyDown(KEY_SPACE) callable
- [PASS] Input.IsKeyPressed(KEY_A) callable
- [PASS] KEY_* constants defined
- [PASS] Inkey() function callable
- [PASS] IsMouseButtonDown(1) callable
- [PASS] GetMouseX/Y() callable
- [PASS] Input.GetMousePosition() returns Vector2
- [PASS] MouseClick() function callable
```

---

## 📥 Downloads

| Platform | File | Size |
|----------|------|------|
| Linux x86_64 | `VisualGasic_v2.2.4_linux_x86_64.zip` | ~15 MB |
| Windows x86_64 | `VisualGasic_v2.2.4_windows_x86_64.zip` | ~15 MB |

---

## 🔄 Upgrade Notes

This is a backwards-compatible release. Existing projects should work without modification.

To use the new `Whenever` system, simply add `Whenever Section` declarations at module level and implement the callback functions.

---

## 🙏 Contributors

Thanks to all contributors and testers who helped make this release possible!
