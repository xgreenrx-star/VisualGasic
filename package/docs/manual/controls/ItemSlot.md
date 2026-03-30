# ItemSlot

> Game UI Tier 3 control — Single inventory/equipment slot with icon and count badge.

## Toolbox

| Label | Tab | Icon |
|-------|-----|------|
| ItemSlot | Game UI | GridContainer |

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| ItemName | String | `""` | Name of the item in this slot |
| ItemCount | int | `1` | Stack count |
| ShowCount | bool | `true` | Display count badge when > 1 |
| RarityColor | Color | `(0.5, 0.5, 0.6)` | Border color indicating rarity |
| SlotSize | int (24–128) | `48` | Width and height in pixels |
| IsEmpty | bool | `true` | Whether slot contains an item |

## Signals

| Signal | Description |
|--------|-------------|
| `slot_clicked` | Emitted on left-click |
| `slot_right_clicked` | Emitted on right-click |
| `item_dropped(data)` | Emitted when an item is dropped onto this slot |

## Methods

| Method | Description |
|--------|-------------|
| `set_item(name, count, rarity)` | Fill slot with an item |
| `clear_slot()` | Empty the slot |

## VB6-Style Example

```vb
Sub ItemSlot1_slot_clicked()
    If Not ItemSlot1.IsEmpty Then
        Player.UseItem ItemSlot1.ItemName
    End If
End Sub

Sub PickupItem(name, count, rarity)
    ItemSlot1.set_item name, count, rarity
End Sub
```

## Design-Time Appearance

- Color: dark slate `(0.12, 0.12, 0.18, 0.9)`
- Label: **Itm**
- Default size: 48 × 48
