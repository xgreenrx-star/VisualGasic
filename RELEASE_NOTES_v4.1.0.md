# VisualGasic v4.1.0 Release Notes

**Release Date**: March 13, 2026  
**Previous Release**: v4.0.0 (March 11, 2026)

---

## 🎨 Form Designer Property System Overhaul

This release makes the Form Designer's property system fully functional end-to-end. Previously, most VB6 properties only worked at design-time in the live preview — now they serialize properly to .tscn and work at **runtime** when the user presses F5.

### Property Runtime Wiring (70+ properties)

The serializer (`_serialize_to_tscn`) now translates 70+ VB6 PascalCase property names to proper Godot snake_case names. Previously only ~10 properties (Text, Visible, MaxLength, etc.) were translated — everything else was written verbatim and silently ignored by Godot at runtime.

**Simple 1:1 translations** (62 entries):
`Flat`, `ClipText`, `PlaceholderText`, `ClearButton`, `SelectAllOnFocus`, `Prefix`, `Suffix`, `Editable`, `ShowPercentage`, `Indeterminate`, `FillMode`, `TickCount`, `TicksOnBorders`, `Scrollable`, `HideRoot`, `HideFolding`, `AllowReselect`, `AllowRmbSelect`, `SelectMode`, `Columns`, `ColumnTitlesVisible`, `ScrollHorizontalEnabled`, `ScrollVerticalEnabled`, `ClipTabs`, `DragToRearrangeEnabled`, `TabAlignment`, `FitToLongestItem`, `AutoHeight`, `SameColumnWidth`, `MaxColumns`, `FixedColumnWidth`, `BbcodeEnabled`, `FitContent`, `ScrollActive`, `SelectionEnabled`, `FlipH`, `FlipV`, `StretchMode`, `IgnoreTextureSize`, `SwitchOnHover`, `PreferGlobalMenu`, `VerticalAlignment`, `ClipContents`, `SizeFlagsHorizontal`, `SizeFlagsVertical`, `GrowHorizontal`, `GrowVertical`, `LayoutDirection`, `VirtualKeyboardEnabled`, `KeepPressedOutside`, `ActionMode`, `UpdateOnTextChanged`, `TextOverrunBehavior`, `MaxLinesVisible`, `CurrentTab`, `Page`, `CustomStep`, `ShowBehindParent`, `Min`, `Max`, `Step`, `AllowGreater`, `AllowLesser`, `Rounded`

**Context-dependent translations**:
- `Value` → `button_pressed` (CheckBox/CheckButton/RadioButton) or `value` (Range/Slider/ScrollBar)
- `Rotation` → `rotation_degrees`
- `RightToLeft` → `text_direction` (0=auto, 2=RTL)
- `MultiSelect` → `select_mode`
- `IconMode` → `icon_mode`

**Composite property translations**:
- `PasswordChar` → `secret = true` + `secret_character = "●"`
- `Opacity` → `modulate = Color(1, 1, 1, alpha)`
- `ScaleX`/`ScaleY` → `scale = Vector2(sx, sy)`
- `PivotOffsetX`/`PivotOffsetY` → `pivot_offset = Vector2(px, py)`
- `MinWidth`/`MinHeight` → `custom_minimum_size = Vector2(w, h)`
- `Tag` → `metadata/Tag`

### Font Support (FontName, FontBold, FontItalic)

Font properties now work at both design-time and runtime:

- **Serializer**: Generates a `[sub_resource type="SystemFont"]` per control with `font_names`, `font_weight=700`, `font_italic=true`. Referenced via `theme_override_fonts/font = SubResource("ctrl_font_XXX")`.
- **Live preview**: Instantiates `SystemFont` and applies via `add_theme_font_override("font", sf)`.
- **Parser**: Reads SystemFont sub_resources back to restore `FontName`/`FontBold`/`FontItalic` for round-tripping.

Supported font names: MS Sans Serif (default), Arial, Courier New, Comic Sans MS, Georgia, Impact, Lucida Console, Segoe UI, Tahoma, Times New Roman, Trebuchet MS, Verdana, Consolas, Calibri, Cambria, Palatino Linotype, Franklin Gothic Medium, Book Antiqua, Garamond, Century Gothic, Fixedsys, Terminal, System.

### Color Support (BackColor, ForeColor, ShapeColor)

- **ForeColor** → `theme_override_colors/font_color = Color(r, g, b, a)` — simple property, no sub-resource needed.
- **BackColor** → `[sub_resource type="StyleBoxFlat"]` with `bg_color`. Applied as `theme_override_styles/normal`. Works on Button, LineEdit, TextEdit, Label, Panel, and all other controls that support the "normal" or "panel" style slot.
- **ShapeColor** → `color = Color(r, g, b, a)` for ColorRect controls.

### Border Support (BorderStyle)

- **BorderStyle = 0 (None)** → StyleBoxFlat with `border_width = 0`
- **BorderStyle = 1 (Fixed Single)** → StyleBoxFlat with `border_width = 1` and dark border color
- Combined with BackColor in a single per-control StyleBoxFlat sub_resource when both are set.

### Live Preview Enhancements

ALL control properties now sync to the design-time live preview canvas. Previously only `text` and `visible` were synced. This release added:

- **All control-specific properties**: Flat, ClipText, PlaceholderText, ShowPercentage, HideRoot, Editable, TickCount, Scrollable, ClipTabs, BbcodeEnabled, FlipH/V, StretchMode, and 50+ more
- **Universal layout/effects**: Rotation, Scale, PivotOffset, MinSize, ClipContents, LayoutDirection, SelfModulate, ShowBehindParent
- **Font styling**: FontName, FontBold, FontItalic (via SystemFont)
- **Color styling**: ForeColor (font_color), BackColor (StyleBoxFlat)
- **Border styling**: BorderStyle (StyleBoxFlat border_width)

### Full Round-Trip Parser

The .tscn parser now reads back all the new properties for proper save → load → save round-tripping:
- 60+ simple reverse mappings (snake_case → PascalCase)
- Sub_resource parsing pass for `ctrl_font_*` (SystemFont) and `ctrl_bg_*` (StyleBoxFlat) blocks
- Composite Vector2 decomposition (scale → ScaleX/ScaleY, pivot_offset → PivotOffsetX/Y, custom_minimum_size → MinWidth/MinHeight)
- Modulate alpha → Opacity, text_direction → RightToLeft, secret_character → PasswordChar

---

## Test Results

| Metric | Value |
|--------|-------|
| Test Files | 65 |
| Assertions | 603 |
| Passed | 601 |
| Failed | 2 (pre-existing: symlink tests on non-root) |

---

## Commits

| Hash | Description |
|------|-------------|
| `3277d99` | Wire ALL properties to live preview (complete rewrite of `_sync_live_preview_properties`) |
| `67f4820` | Second pass: Slider, ScrollBar, Tree, universal layout/effects |
| `08eee98` | Fix run-time property wiring: serializer + parser full translation table (70+) |
| `f9d5391` | Font, BackColor, ForeColor, BorderStyle, ShapeColor sub-resource generation |
