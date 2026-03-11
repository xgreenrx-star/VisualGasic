# Release Notes — Visual Gasic v4.0.0

**Release Date**: March 11, 2026  
**Codename**: *Game UI Form Designer*

---

## 🎮 Headline: Animated Game UI Controls

v4.0.0 transforms the Game UI tab from simple aliases into **7 dedicated, animated controls** purpose-built for game interfaces. Each control ships with:

- A `.tscn` prototype scene + `.gd` backing script
- Built-in **Tween animations** (Show/Hide with configurable easing)
- Full **Properties panel** integration with VB6-style defaults
- Standard **ControlName_EventType()** auto-wiring

---

## New Controls (Tier 1)

### 🗨️ DialogPanel
Animated dialog box for RPGs, visual novels, and adventure games.

- Portrait, speaker name, rich-text body, branching choice buttons
- **Typewriter effect** with configurable speed
- Events: `dialog_finished`, `choice_selected(index)`
- Animations: SlideUp, FadeIn, ScaleUp, PopBounce

### 📦 InventoryGrid
N×M slot grid for inventory, crafting, and equipment screens.

- Configurable Rows, Columns, SlotSize, SlotSpacing
- Per-slot icon textures via `SetSlotIcon(row, col, texture)`
- Hover highlighting and selection tracking
- Events: `slot_clicked(row, col)`, `slot_double_clicked(row, col)`

### 📊 StatBar
Animated HP / MP / XP bar with damage trail.

- Smooth value transitions with configurable speed
- **Damage flash** (white flash on value decrease)
- **Trail bar** (red ghost that follows with delay)
- Customizable label format: `{value} / {max}` or `{percent}%`
- Events: `value_changed(new_value)`, `depleted`

### 🔢 HUDCounter
Animated score / gold / ammo counter.

- **Counting animation** from old value to new value
- **Punch-scale effect** on change
- Optional prefix/suffix text and icon
- Events: `count_finished`

### ⏳ CooldownButton
Texture button with radial cooldown overlay.

- Radial sweep arc drawn via `_draw()` — no extra textures needed
- Auto-disables during cooldown, re-enables when ready
- Optional countdown text overlay
- Events: `cooldown_finished`

### 📢 NotificationToast
Slide-in/out notification for achievements, pickups, and system messages.

- Configurable duration and auto-dismiss timer
- Icon + text layout with word wrap
- Animations: SlideFromTop, SlideFromBottom, SlideFromRight, FadeIn
- Events: `dismissed`

### ⏸️ GameMenu
Full-screen pause / settings overlay.

- Dim background with configurable alpha
- Centered title + dynamic button list
- `ToggleMenu()` for easy pause integration
- Events: `button_clicked(index)`, `menu_opened`, `menu_closed`

---

## Animation Properties (All Tier 1 Controls)

Every Game UI control exposes these in the Properties panel:

| Property | Description |
|----------|-------------|
| **ShowAnimation** | Entrance effect (SlideUp, FadeIn, ScaleUp, PopBounce, None) |
| **HideAnimation** | Exit effect (SlideDown, FadeOut, ScaleDown, None) |
| **TransitionSpeed** | Duration in seconds (default: 0.25–0.4) |

Animations use Godot's built-in Tween system — no external dependencies.

---

## VB Code Example

```vb
' RPG HUD — Game UI Mode form
Option Explicit

Dim playerHP As Integer
Dim score As Integer

Sub Form_Load()
    playerHP = 100
    score = 0
    StatBar1.MaxValue = 100
    StatBar1.Value = 100
    HUDCounter1.Prefix = "Score: "
    HUDCounter1.Value = 0
End Sub

Sub ActionButton1_Click()
    ' Player attacks — take 15 damage
    playerHP = playerHP - 15
    StatBar1.SetValue playerHP
    
    ' Award 100 points
    score = score + 100
    HUDCounter1.AddValue 100
    
    ' Show notification
    NotificationToast1.ShowMessage "+100 XP!"
    
    If playerHP <= 0 Then
        DialogPanel1.ShowDialog "System", "Game Over!", Array("Retry", "Quit")
    End If
End Sub

Sub DialogPanel1_ChoiceSelected(index As Integer)
    If index = 0 Then
        playerHP = 100
        StatBar1.SetValueImmediate 100
        DialogPanel1.HideDialog
    Else
        Me.Close
    End If
End Sub

Sub CooldownButton1_Click()
    CooldownButton1.StartCooldown 5.0
End Sub
```

---

## Toolbox Changes

| Change | Details |
|--------|---------|
| **Added** | 7 new dedicated controls with custom prototypes |
| **Kept** | HealthBar, ScoreLabel, ActionButton, Crosshair (legacy aliases) |
| **Removed** | DialogBox, Inventory, Tooltip, AmmoCounter, BossBar, MiniMap (superseded by Tier 1) |
| **Total** | 11 → 11 Game UI controls (7 new + 4 legacy) |

---

## Files Changed

### New Files (14)
- `addons/visual_gasic/prototypes/game_ui/DialogPanel.gd` + `.tscn`
- `addons/visual_gasic/prototypes/game_ui/InventoryGrid.gd` + `.tscn`
- `addons/visual_gasic/prototypes/game_ui/StatBar.gd` + `.tscn`
- `addons/visual_gasic/prototypes/game_ui/HUDCounter.gd` + `.tscn`
- `addons/visual_gasic/prototypes/game_ui/CooldownButton.gd` + `.tscn`
- `addons/visual_gasic/prototypes/game_ui/NotificationToast.gd` + `.tscn`
- `addons/visual_gasic/prototypes/game_ui/GameMenu.gd` + `.tscn`

### Modified Files
- `src/visual_gasic_toolbox.cpp` — Replaced alias registrations with Tier 1 prototypes
- `src/visual_gasic_form_designer.cpp` — Default sizes, design-time colors, display labels, VB6 property defaults
- `VERSION` — 3.8.0 → 4.0.0
- `CHANGELOG.md`, `ROADMAP.md`, `PROJECT_STATUS.md`, `package/README.md`, `package/ROADMAP.md`, `examples/ROADMAP.md`

---

## Test Results

```
Files:      65
Assertions: 602
Passed:     600
Failed:     2 (pre-existing)
```

No regressions.

---

## What's Next (Tier 2 — v4.1)

Planned for the next release cycle:

- **MiniMap** — SubViewport-based mini-map with player marker
- **QuestTracker** — Vertical objective list with check-off animation
- **RadialMenu** — Circular selection wheel (weapons, items)
- **TabMenu** — Tabbed panel for settings / character sheets
- **LootPopup** — Animated loot reveal with rarity glow
- **Subtitles** — Timed subtitle display with speaker colors

Plus: **Game Form Templates** (File → New Form → "RPG HUD", "FPS Overlay", etc.)
