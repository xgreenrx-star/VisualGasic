# Visual Gasic v3.7.0 Release Notes

**Release Date:** March 11, 2026  
**Codename:** "OOP Power-Up"

---

## 🚀 What's New

### Method Overloading

Define multiple `Sub` or `Function` with the same name but different parameter counts. The runtime automatically selects the best match based on argument count.

```vb
Sub Spawn(x As Single, y As Single)
    Spawn x, y, 100, 0
End Sub

Sub Spawn(x As Single, y As Single, speed As Single, angle As Single)
    CreateBullet x, y, speed, angle
End Sub

Spawn 10, 20         ' → calls 2-arg version
Spawn 10, 20, 50, 90 ' → calls 4-arg version
```

Works with module-level functions, class methods, and Optional parameter matching.

### Parameterized Constructors

Pass arguments directly to `Class_Initialize` when creating objects:

```vb
Class Bullet
    Public speed As Double, angle As Double, damage As Integer
    Sub Class_Initialize(s As Double, a As Double, d As Integer)
        speed = s : angle = a : damage = d
    End Sub
End Class

Dim b = New Bullet(300, 45, 10)
Dim b2 As New Bullet(200, 90, 25)
```

### Generics Phase 1 — Collection(Of T)

Type-safe collections with runtime validation:

```vb
Dim scores As New Collection(Of Integer)
scores.Add 100   ' OK
scores.Add 200   ' OK

Dim names As New Collection(Of String)
names.Add "Alice"

' Auto-instantiation (no New required)
Dim items As Collection(Of Double)
items.Add 3.14
```

### Game UI Mode for Form Designer

Build game HUD overlays directly in the Form Designer:

- Set `GameUIMode = True` to switch from desktop-form to game-overlay mode
- Dark canvas with crosshair guides and safe area rectangle
- Exports `CanvasLayer` (layer 10) with full-rect `Control` child
- 11 new Game UI toolbox controls: HealthBar, ScoreLabel, DialogBox, MiniMap, Inventory, ActionButton, AmmoCounter, BossBar, Crosshair, Tooltip, Pointer

---

## 📊 Test Results

| Metric | Value |
|--------|-------|
| Test files | 64 |
| Total assertions | 564 |
| Passed | 562 |
| Failed | 2 (pre-existing symlink tests) |
| New test files | 3 |
| New assertions | 31 |

---

## 📁 Files Modified

### New Files
- `test_proj/test_suite/test_method_overloading.vg` — 11 assertions
- `test_proj/test_suite/test_parameterized_constructors.vg` — 8 assertions
- `test_proj/test_suite/test_generics.vg` — 12 assertions

### Modified Source Files
| File | Changes |
|------|---------|
| `visual_gasic_parser.cpp` | 2nd New path args, Dim As New args, `(Of T)` generic parsing |
| `visual_gasic_compiler.cpp` | Entry point arity suffix, call-site arity matching |
| `visual_gasic_instance_call.inc` | Arity-based overload resolution, mangled bytecode cache key |
| `visual_gasic_instance_class.cpp` | `find_method_in_hierarchy` arity-aware dispatch |
| `visual_gasic_instance_execute.inc` | Generic type param wiring, Collection auto-instantiation |
| `visual_gasic_ast.h` | `generic_type_param` field on `DimStatement` |
| `visual_gasic_collection.h/cpp` | `set_element_type`/`get_element_type`, type validation in `add()` |
| `visual_gasic_form_designer.h/cpp` | Game UI mode draw/serialize, `GameUIMode` property |
| `visual_gasic_toolbox.h/cpp` | Game UI tab, 11 game UI controls |
| `visual_gasic_instance.h` | Updated `find_method_in_hierarchy` signature |

---

## ⬆️ Upgrade Notes

- **Fully backward compatible** — all existing code continues to work unchanged
- Method overloading falls back to first-match when no arity match found
- Untyped `Collection` (without `Of T`) works exactly as before
- Form Designer defaults to standard desktop mode; Game UI Mode is opt-in
