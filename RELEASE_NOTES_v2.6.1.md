# Visual Gasic v2.6.1 Release Notes

**Release Date**: February 2026  
**Codename**: Bytecode Builtins Fix  
**Godot Version**: 4.5.1

---

## Summary

v2.6.1 fixes a class of bugs where Godot engine builtins (`IsOnFloor`, `GetAxis`, `Load`, etc.) worked correctly in the AST interpreter but silently returned nil when called from bytecode-compiled functions. This was most visible in the Godot-native 2D Platformer demo where the player's animation was stuck on "falling" because `GetNewAnimation()` was bytecode-compiled but `IsOnFloor(Me)` had no bytecode handler.

Additionally fixes signal handler dispatch for snake_case callbacks and `Me.Method()` calls being silently dropped by the bytecode compiler.

---

## 🔧 Bytecode VM — 8 New Builtins in `OP_CALL`

The bytecode VM's `OP_CALL` handler now supports these builtins that were previously only available in the AST interpreter:

| Function | Description |
|----------|-------------|
| `IsOnFloor(body)` | CharacterBody2D/3D floor detection |
| `IsOnWall(body)` | CharacterBody2D/3D wall detection |
| `GetAxis("neg", "pos")` | Input axis query (-1..+1) |
| `IsActionPressed(action)` | Held input check |
| `IsActionJustPressed(action)` | Rising-edge input check |
| `IsActionJustReleased(action)` | Falling-edge input check |
| `Load(path)` | ResourceLoader for PackedScene/Texture |
| `CreateTween()` | Tween creation on owner node |
| `Vector2(x, y)` | Constructor (bytecode path) |
| `GetNode(path)` | Node lookup (bytecode path) |

**Why this matters**: When the bytecode compiler successfully compiles a function, the entire function runs through the bytecode VM. If a builtin is missing from the VM, it silently returns nil instead of raising an error — the function appears to work but produces wrong results. These builtins are now available in both the AST and bytecode paths.

---

## 🔌 Signal Handler Dispatch Fix

**Bug**: Signal callbacks written in snake_case (e.g. `Sub _on_body_entered`) were never called.

**Root cause**: `godot_snake_to_vg_pascal("_on_body_entered")` produces `"_OnBodyEntered"` (14 chars). The runtime then tried a case-insensitive compare against the actual sub name `"_on_body_entered"` (18 chars). Since the string *lengths* differ (underscores were stripped), the comparison failed immediately.

**Fix**: After the PascalCase lookup fails, the runtime now falls back to trying the original snake_case method name. This fixes all signal callbacks: `body_entered`, `area_entered`, button signals, etc.

---

## 🛡️ Me.Method() Compiler Fix

**Bug**: `Me.Hide()`, `Me.AddToGroup("players")`, and similar `Me.X()` calls silently did nothing when the enclosing sub was bytecode-compiled.

**Root cause**: The compiler had an exception that allowed `Me.` and `With.` base_object calls through `STMT_CALL`, but generated a plain `OP_CALL` without any base context. The bytecode VM dispatched the call as a standalone function, which didn't find `Hide` or `AddToGroup` and silently returned nil.

**Fix**: The compiler now rejects ALL base_object calls in `STMT_CALL`, forcing fallback to the AST interpreter which correctly dispatches `obj.method()` calls with the base object.

---

## 🎮 Platformer Demo Improvements

The Godot-native 2D Platformer demo (`demos/2D_Games/Platformer_Godot/`) now runs correctly:

- **Animations work**: Player correctly switches between idle, run, jumping, and falling animations
- **Enemy animations work**: Bug enemies animate walk/idle/destroy correctly
- **Bullet shooting works**: `Load("res://player/bullet.tscn")` loads in bytecode, bullets instantiate and destroy enemies
- **Coin collection works**: `_on_body_entered` signal fires correctly via the snake_case fallback
- **Pause menu works**: `OpenMenu`/`CloseMenu` called correctly, coin counter updates
- All 8 `.vg` scripts parse with 0 errors and produce 0 runtime errors

---

## Files Changed

### C++ Runtime
- `src/visual_gasic_instance.cpp` — 8 new bytecode OP_CALL builtins, signal handler fallback, GetNode base_object resolution, error reporting for failed method calls
- `src/visual_gasic_compiler.cpp` — Reject all base_object calls in STMT_CALL
- `src/visual_gasic_expression_evaluator.cpp` — snake_case fallback for Godot method dispatch, delegate to full evaluator on failure

### Demo Scripts
- `demos/2D_Games/Platformer_Godot/player/player.vg` — Local animation tracking, documented signal/movement system
- `demos/2D_Games/Platformer_Godot/enemy/enemy.vg` — Local animation tracking
- `demos/2D_Games/Platformer_Godot/gui/pause_menu.vg` — OpenMenu/CloseMenu (reserved keyword fix)
- `demos/2D_Games/Platformer_Godot/game.vg` — OpenMenu/CloseMenu
- `demos/2D_Games/Platformer_Godot/game_singleplayer.tscn` — Signal connection update
- `demos/2D_Games/Platformer_Godot/project.godot` — Collision layer names
