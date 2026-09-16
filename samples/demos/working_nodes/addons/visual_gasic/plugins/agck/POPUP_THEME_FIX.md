# AGCK OptionButton Popup Theme Fix — Linux X11

## The Problem

On **Linux X11**, OptionButton dropdown popups show **unreadable text**
(invisible/low-contrast font against the background). This happens because
Godot creates a separate native X11 window for each popup, and the X11
compositor interferes with our custom dark theme.

## Root Cause

Setting `popup.transparent = true` + `RenderingServer.viewport_set_transparent_background()`
tells Godot to request an ARGB visual from the X11 server. This causes:

1. The X11 compositor paints behind the transparent window, breaking our dark background
2. Font anti-aliasing changes when rendering against a transparent viewport
3. The dark StyleBox may not fully cover the native window area
4. Theme color overrides can get lost during the viewport swap

## The Fix (KEEP THIS — do NOT revert)

In all 4 AGCK editor files that have `_style_option` / `_apply_dark_popup`:

### 1. DO NOT use transparent viewports

```gdscript
popup.transparent = false   # ← MUST be false, NEVER true on Linux X11
# Do NOT call RenderingServer.viewport_set_transparent_background()
```

### 2. Use opaque StyleBoxFlat with explicit alpha

```gdscript
ps.bg_color = Color(0.15, 0.15, 0.19, 1.0)  # ← explicit alpha 1.0
```

### 3. Include "Window" in Theme type names

```gdscript
for type_name in ["PopupMenu", "PopupPanel", "Panel", "Control", "Window"]:
    t.set_stylebox("panel", type_name, ps)
```

The `"Window"` type covers the native window's own panel background, which
on X11 is separate from the PopupMenu panel.

### 4. Override font_outline_color

```gdscript
t.set_color("font_outline_color", "PopupMenu", Color.TRANSPARENT)
popup.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
```

Some Linux desktop themes add font outlines that reduce readability.

### 5. Keep the about_to_popup + visibility_changed hooks

Godot may reset the popup theme on show. The hooks re-apply our dark theme:

```gdscript
popup.about_to_popup.connect(func():
    _apply_dark_popup(popup)
    _apply_dark_popup.call_deferred(popup)  # ← deferred catches late resets
)
popup.visibility_changed.connect(func():
    if popup.visible:
        _apply_dark_popup(popup)
)
```

## Files That Need This Fix

All **5** files with `_style_option` / `_apply_dark_popup`:

- `agck_actor_editor.gd`
- `agck_level_editor.gd`
- `agck_game_settings.gd`
- `agck_sound_editor.gd`
- `agck_game_builder.gd`  ← **easy to miss — the Build tab also has dropdowns**

### Standalone PopupMenu instances (NOT from OptionButton)

These are created via `PopupMenu.new()` and must ALSO call `_apply_dark_popup()`:

- `agck_actor_editor.gd` → `_on_anim_add_pressed()` (animation presets popup)
  - Call `_apply_dark_popup(popup)` right after creating it
  - Call `_apply_dark_popup(popup)` AGAIN after `add_child()` (Linux X11 resets on reparent)

**Search pattern to find all popups:**
```
grep -rn 'PopupMenu.new\|_style_option\|_apply_dark_popup' addons/visual_gasic/plugins/agck/*.gd
```

## Color Reference

| Override | Value | Visual |
|----------|-------|--------|
| Panel bg | `Color(0.15, 0.15, 0.19, 1.0)` | Dark blue-grey |
| Panel border | `Color(0.30, 0.30, 0.35)` | Subtle grey border |
| Hover bg | `Color(0.25, 0.35, 0.55)` | Medium blue |
| font_color | `LABEL_CLR` = `Color(0.88, 0.86, 0.80)` | Light cream |
| font_hover_color | `WHITE` = `Color(1.0, 1.0, 1.0)` | Pure white |
| font_disabled_color | `DIM` = `Color(0.50, 0.50, 0.55)` | Grey |
| font_outline_color | `Color.TRANSPARENT` | No outline |

## History

This bug has recurred multiple times. **DO NOT** reintroduce `transparent = true`
on popups, even if it looks correct on Wayland or macOS. It breaks on X11.
