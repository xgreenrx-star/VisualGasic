# Popup / Dropdown Theming in Godot 4 Editor Plugins

> **Status:** Confirmed working — April 2026

## The Problem

`PopupMenu` in Godot 4 is a native OS window (on Linux X11 this is a
real X11 window).  Two things conspire to make dark theming difficult:

1. **Editor theme override** — the popup inherits the Godot editor's theme
   from its root window parent, silently overwriting your overrides every
   time it opens.
2. **Native window background** — on Linux X11 (without a compositor), the
   OS paints the window background **white** before Godot renders anything.
   Even if your StyleBoxFlat is applied, the white native background bleeds
   through unless you explicitly make the viewport transparent.

## What Does NOT Work

```gdscript
# ❌ Theme.new() alone — editor theme on the Window parent still overrides
var t = Theme.new()
t.set_stylebox("panel", "PopupMenu", my_style)
popup.theme = t

# ❌ One-shot add_theme_*_override at build time — editor re-applies on show
popup.add_theme_stylebox_override("panel", my_style)

# ❌ popup.transparent = true alone — not enough on Linux X11 without a
#    compositor; need RenderingServer.viewport_set_transparent_background too

# ❌ RenderingServer.viewport_set_clear_color() — DOES NOT EXIST in Godot 4
#    (was a Godot 3 API; do not use)
```

## What DOES Work  (The Proven Pattern)

The fix uses **four mechanisms together**:

1. **`popup.transparent = true`** — tells Godot the popup window should be
   transparent (necessary but not sufficient on Linux X11).
2. **`RenderingServer.viewport_set_transparent_background(vp_rid, true)`** —
   forces the viewport's clear color to transparent at the rendering level,
   eliminating the native white window background.
3. **Theme resource + local overrides** — a `Theme.new()` covering type
   names PopupMenu, PopupPanel, Panel, and Control, PLUS
   `add_theme_*_override()` calls (highest priority) to guarantee our dark
   colors win over the editor theme.
4. **Triple-hook: `about_to_popup` + `visibility_changed` + `call_deferred`**
   — re-applies everything after the editor theme has been set, on every
   open, with a deferred pass to catch late theme overrides.

### Reference Implementation (dark theme for AGCK)

```gdscript
func _style_option(opt: OptionButton) -> void:
    # --- Style the OptionButton itself (works at build time) ---
    var nb = StyleBoxFlat.new()
    nb.bg_color = Color(0.18, 0.18, 0.22)
    nb.set_corner_radius_all(3)
    # ... content margins ...
    opt.add_theme_stylebox_override("normal", nb)
    # ... hover, pressed, focus variants ...
    opt.add_theme_color_override("font_color", LABEL_CLR)

    # --- Dark popup ---
    var popup := opt.get_popup()
    popup.transparent = true
    _apply_dark_popup(popup)
    if not popup.has_meta("_agck_popup_styled"):
        popup.set_meta("_agck_popup_styled", true)
        popup.about_to_popup.connect(func():
            popup.transparent = true
            _apply_dark_popup(popup)
            _apply_dark_popup.call_deferred(popup)
        )
        popup.visibility_changed.connect(func():
            if popup.visible:
                _apply_dark_popup(popup)
        )


func _apply_dark_popup(popup: PopupMenu) -> void:
    if not is_instance_valid(popup):
        return
    var dark_bg := Color(0.15, 0.15, 0.19)
    popup.transparent = true

    # KEY FIX: force viewport transparency at rendering level
    var vp_rid := popup.get_viewport_rid()
    if vp_rid.is_valid():
        RenderingServer.viewport_set_transparent_background(vp_rid, true)

    # Panel stylebox
    var ps := StyleBoxFlat.new()
    ps.bg_color = dark_bg
    ps.set_corner_radius_all(0)
    ps.content_margin_left = 6;  ps.content_margin_right = 6
    ps.content_margin_top = 4;   ps.content_margin_bottom = 4
    ps.border_width_bottom = 1;  ps.border_width_top = 1
    ps.border_width_left = 1;    ps.border_width_right = 1
    ps.border_color = Color(0.30, 0.30, 0.35)

    # Hover stylebox
    var hs := StyleBoxFlat.new()
    hs.bg_color = Color(0.25, 0.35, 0.55)
    hs.set_corner_radius_all(3)
    hs.content_margin_left = 6;  hs.content_margin_right = 6
    hs.content_margin_top = 2;   hs.content_margin_bottom = 2

    # Theme resource — covers multiple type names
    var t := Theme.new()
    for type_name in ["PopupMenu", "PopupPanel", "Panel", "Control"]:
        t.set_stylebox("panel", type_name, ps)
    t.set_stylebox("hover", "PopupMenu", hs)
    t.set_color("font_color",            "PopupMenu", LABEL_CLR)
    t.set_color("font_hover_color",      "PopupMenu", WHITE)
    t.set_color("font_disabled_color",   "PopupMenu", DIM)
    t.set_color("font_separator_color",  "PopupMenu", DIM)
    t.set_color("font_accelerator_color","PopupMenu", DIM)
    popup.theme = t

    # Local overrides — highest priority
    popup.add_theme_stylebox_override("panel", ps)
    popup.add_theme_stylebox_override("hover", hs)
    popup.add_theme_color_override("font_color",            LABEL_CLR)
    popup.add_theme_color_override("font_hover_color",      WHITE)
    popup.add_theme_color_override("font_disabled_color",   DIM)
    popup.add_theme_color_override("font_separator_color",  DIM)
    popup.add_theme_color_override("font_accelerator_color",DIM)

    # Also override internal children (some Godot versions wrap content)
    for c in popup.get_children(true):
        if c is Control:
            c.add_theme_stylebox_override("panel", ps)
            c.queue_redraw()
```

### Light-theme version (VB6 Properties panel)

Already lives in `vg_theme_utils.gd` — uses cream/white colors that
naturally match the OS window background, so does NOT need the
`viewport_set_transparent_background` fix:

```gdscript
VGTheme.hook_option_button(my_opt)   # defers + hooks about_to_popup
VGTheme.style_popup(my_popup)        # immediate + hooks sub-menus
VGTheme.hook_line_edit(my_line)      # hooks right-click context menu
VGTheme.hook_text_edit(my_edit)      # hooks right-click context menu
```

## Key Takeaways

| Approach | Works? | Why |
|----------|--------|-----|
| `Theme.new()` alone | ❌ | Editor theme on the Window parent overrides it |
| One-shot `add_theme_*_override` | ❌ | Editor re-applies its theme on popup show |
| `popup.transparent = true` alone | ❌ | Not enough on Linux X11 without compositor |
| Theme + overrides + `about_to_popup` | ⚠️ | Dark hover works, but panel bg stays white |
| **All four: transparent + viewport + Theme + triple-hook** | ✅ | **Confirmed working** |

## Important: Project Locations

The AGCK plugin exists in multiple project copies. The **canonical source**
is at:

```
addons/visual_gasic/plugins/agck/   ← EDIT HERE FIRST
```

All other copies are deployed from the canonical source:

```
demos/2D_Games/Platformer_Godot/addons/visual_gasic/plugins/agck/
game_projects/platformer_2d/addons/visual_gasic/plugins/agck/
game_projects/asteroids/addons/visual_gasic/plugins/agck/
game_projects/defender/addons/visual_gasic/plugins/agck/
game_projects/racing_3d/addons/visual_gasic/plugins/agck/
game_projects/zork/addons/visual_gasic/plugins/agck/
demo/addons/visual_gasic/plugins/agck/
package/addons/visual_gasic/plugins/agck/
test_proj/addons/visual_gasic/plugins/agck/
```

⚠️ **Always edit the canonical source first, then copy to all others.**
The Godot Project Manager project "Platformer 2D (VisualGasic)" opens
from `demos/2D_Games/Platformer_Godot/`, NOT `game_projects/platformer_2d/`.

## Files Using This Pattern

- `agck_level_editor.gd` — `_style_option` + `_apply_dark_popup`
- `agck_actor_editor.gd` — `_style_option` + `_apply_dark_popup`
- `agck_game_settings.gd` — `_style_option` + `_apply_dark_popup`
- `agck_sound_editor.gd` — `_style_option` + `_apply_dark_popup`
- `agck_game_builder.gd` — `_style_option` + `_apply_dark_popup`
- `vg_theme_utils.gd` — `hook_option_button` + `style_popup` (light theme, no viewport fix needed)
- `simple_inspector.gd` — `_style_option_button` + `_style_context_menu`
- `visual_gasic_plugin.gd` — `_style_popup_menu` + `_apply_vb6_popup_theme`

## When Adding New Popups

**Always** use the `about_to_popup` re-apply pattern. Never rely on
one-shot styling at construction time. Copy the `_style_option` /
`_apply_dark_popup` pair from any AGCK file, or use `VGTheme.hook_*`
for the light VB6 theme.
