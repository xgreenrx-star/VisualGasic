# VB6 legacy projects — language vs importer

VisualGasic’s **`.vg` language** is the supported path for ex-VB6 developers: familiar `Sub`/`Function`, `Dim … As`, handler names like `btnOK_Click()`, and many classic builtins.

**Bulk import** of `.vbp` / `.frm` / `.bas` / `.cls` trees is **not part of the v6.0 core product**. The VB6 importer was **retired from the main distribution** (see [ROADMAP.md](../../ROADMAP.md)). Ongoing work is intended as an optional **community plugin**, documented in [VB6 Importer Plugin Manual](../community_plugins/VB6_IMPORTER_PLUGIN_MANUAL.md).

If you still see **Import VB6 Project...** or **Import VB6 Form...** in an old build, treat that as **legacy / unsupported** on the stable Godot integration path—not a shipped v6.0 feature.

## Recommended workflow (v6.0)

1. **Manual port** — Rewrite forms as Godot scenes (or **UI Forms** on the 2D viewport when enabled) and logic as `.vg`. Use [Migration Guide](MIGRATION_GUIDE.md) for syntax mapping.
2. **Templates & demos** — Start from `demos/` and samples instead of one-click migration.
3. **Optional community importer** — If you maintain or install the separate plugin, follow [VB6 Importer Plugin Manual](../community_plugins/VB6_IMPORTER_PLUGIN_MANUAL.md) for mapping tables and API (`VB6Importer.import_project`, etc.).

## Control mapping (reference)

When porting by hand or using the community plugin, common VB6 controls map roughly as follows:

| VB6 Control | VisualGasic / Godot |
| :--- | :--- |
| `Form` | `Window` or scene root (see [WINFORMS_FORM_GUIDE.md](../WINFORMS_FORM_GUIDE.md)) |
| `CommandButton` | `Button` |
| `TextBox` | `LineEdit` / `TextEdit` |
| `Label` | `Label` |
| `CheckBox` | `CheckBox` |
| `OptionButton` | `CheckBox` (radio) or `OptionButton` |
| `ListBox` | `ItemList` |
| `PictureBox` | `TextureRect` |
| `Frame` | `Panel` |
| `Timer` | `Timer` (`Interval` in ms) |

Twips-to-pixels (15:1) applies when converting legacy layout numbers by hand.

## Related docs

- [Migration Guide](MIGRATION_GUIDE.md) — syntax and architecture differences
- [VB6 Importer Plugin Manual](../community_plugins/VB6_IMPORTER_PLUGIN_MANUAL.md) — optional plugin scope
- [VG IDE Alpha](../manual/VG_IDE_ALPHA.md) — legacy Form Designer vs Godot-first v6.0 path
- [Godot Programming Manual § Legacy VB6](../GODOT_PROGRAMMING_MANUAL.md) — same importer policy in the long manual
