# Game UI Controls Tutorial

> A step-by-step guide to using the 23 Game UI controls in VisualGasic.

## Overview

The **Game UI** tab in the toolbox provides drag-and-drop controls purpose-built
for games. Each control has:

- A **live preview** in the form designer (WYSIWYG)
- **VB6-style properties** in the Properties panel
- **Signals** you wire up with `Sub ControlName_signal_name()`
- **Animation methods** like `show_popup()` / `hide_dialog()`

---

## Quick Start

1. Open a form in the designer
2. Click the **Game UI** tab on the left toolbox
3. Click a control (e.g., **Tooltip**) then click-drag on the form
4. Set properties in the Properties panel on the right
5. Double-click the control to open the code editor and write event handlers

---

## Tier 1 Controls (v4.0)

| Control | Purpose |
|---------|---------|
| DialogPanel | RPG dialog box with speaker name and typewriter effect |
| InventoryGrid | Grid of item slots with drag-and-drop |
| StatBar | HP/MP/Stamina bar with animated fill |
| HUDCounter | Score / coin counter with icon + label |
| CooldownButton | Ability button with radial cooldown sweep |
| NotificationToast | Slide-in notification banner |
| GameMenu | Full-screen pause/settings overlay |

---

## Tier 2 Controls (v4.1)

### Tooltip
Hover popup with icon, title, and description. Three show animations.

```vb
Sub Enemy_MouseEnter()
    Tooltip1.Title = "Goblin"
    Tooltip1.Description = "A sneaky creature."
    Tooltip1.show_tooltip
End Sub
```

### RadialMenu
Pie/wheel menu drawn with wedge segments. Great for quick ability selection.

```vb
Sub Form_KeyDown(KeyCode, Shift)
    If KeyCode = 9 Then RadialMenu1.show_menu
End Sub

Sub RadialMenu1_item_selected(index)
    Print "You chose wedge " & Str(index)
End Sub
```

### MiniMap
Corner viewport with optional round shape, player dot, and compass lines.

```vb
MiniMap1.MapShape = 1   ' Round
MiniMap1.add_marker "enemy", Vector2(0.7, 0.3), Color(1, 0, 0)
```

### QuestTracker
Sidebar quest list with titles and objectives.

```vb
QuestTracker1.add_quest "Find the Key"
QuestTracker1.complete_quest 0
```

### SettingsPanel
Full options screen with audio, video, and controls sections. Emits a
dictionary of values when the player clicks Apply.

```vb
Sub SettingsPanel1_settings_applied(data)
    AudioServer.SetBusVolume 0, data["master_volume"]
End Sub
```

### ConfirmDialog
"Are you sure?" popup with animated appearance and Yes/No buttons.

```vb
ConfirmDialog1.Message = "Delete save file?"
ConfirmDialog1.show_dialog

Sub ConfirmDialog1_confirmed()
    DeleteSave
End Sub
```

### LoadingScreen
Full-screen overlay with progress bar and rotating tip text.

```vb
LoadingScreen1.set_progress 0.5
LoadingScreen1.TipText = "Almost there..."
```

### DamageNumber
Floating pop-up number that rises and fades. Four animation styles.

```vb
DamageNumber1.pop 150, Color(1, 0.3, 0.2)  ' Red 150
DamageNumber1.ShowCriticalEffect = True
DamageNumber1.pop 999                        ' Big yellow crit
```

---

## Tier 3 Controls (v4.1)

### SkillTree
Grid of skill nodes connected by lines. Nodes unlock on click.

```vb
Sub SkillTree1_skill_selected(index)
    SkillTree1.unlock_skill index
End Sub
```

### ChatBox
Scrollable BBCode chat log with text input. Supports colored names.

```vb
ChatBox1.add_message "Alice", "Hello!", Color(0.3, 0.8, 1.0)
ChatBox1.add_system_message "Server restarting in 5 minutes"
```

### ItemSlot
Single inventory cell with item name, stack count, and rarity border color.

```vb
ItemSlot1.set_item "Potion", 5, Color(0.5, 0.5, 0.6)
ItemSlot1.clear_slot   ' empty
```

### TabPanel
Game-styled tab container. Wire `tab_changed` to swap content.

```vb
Sub TabPanel1_tab_changed(index)
    Select Case index
        Case 0: ShowInventory
        Case 1: ShowSkills
    End Select
End Sub
```

### GamePopup
Animated modal popup for level-up alerts, loot drops, etc.

```vb
GamePopup1.PopupTitle = "Level Up!"
GamePopup1.BodyText = "You reached level 10."
GamePopup1.show_popup
```

### Compass
Horizontal strip compass showing N/S/E/W. Feed it the player bearing.

```vb
Sub _Process(delta)
    Compass1.set_bearing Player.RotationDegrees
End Sub
```

### AmmoCounter
Clip / reserve display. Turns red when ammo is low.

```vb
AmmoCounter1.fire 1
AmmoCounter1.reload
```

### XPBar
Segmented experience bar with auto level-up and level badge.

```vb
XPBar1.add_xp 50
Sub XPBar1_level_up(new_level)
    Print "Level " & Str(new_level) & "!"
End Sub
```

---

## Property Table — All Game UI Controls

| Control | Default Size | Label | Design Color |
|---------|-------------|-------|-------------|
| DialogPanel | 320×120 | Dlg | dark slate |
| InventoryGrid | 220×220 | Inv | dark gray |
| StatBar | 200×24 | Sta | green |
| HUDCounter | 120×28 | HUD | gold |
| CooldownButton | 48×48 | CDb | blue |
| NotificationToast | 250×40 | Tst | dark gray |
| GameMenu | 300×250 | Mnu | black |
| Tooltip | 180×60 | Tip | dark slate |
| RadialMenu | 200×200 | Rad | dark blue |
| MiniMap | 140×140 | Map | dark green |
| QuestTracker | 200×160 | Qst | dark purple |
| SettingsPanel | 320×280 | Set | dark slate |
| ConfirmDialog | 280×140 | Cfm | dark slate |
| LoadingScreen | 320×180 | Lod | near-black |
| DamageNumber | 60×28 | Dmg | red |
| SkillTree | 240×240 | Skl | dark navy |
| ChatBox | 260×180 | Cht | dark charcoal |
| ItemSlot | 48×48 | Itm | dark slate |
| TabPanel | 300×200 | TPn | dark |
| GamePopup | 260×160 | Pop | dark violet |
| Compass | 200×28 | Cmp | dark |
| AmmoCounter | 110×28 | Amo | white |
| XPBar | 260×20 | XPB | cyan |

---

## Tips

- All controls work at **design time** — you'll see a live preview on the form
- Invisible controls show a **ghost outline** with hatch lines
- Properties sync to the live preview in real-time
- Use **ShowAnimation** properties to pick entrance/exit effects
- Combine controls: e.g., put an `XPBar` inside a `TabPanel`, or show a
  `DamageNumber` when the `StatBar` value drops
