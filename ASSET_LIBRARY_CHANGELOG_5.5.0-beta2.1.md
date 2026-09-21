# VisualGasic 5.5.0-beta2.1 — Asset Library Changelog

Copy the block below into **Version Changelog** on [store.godotengine.org](https://store.godotengine.org) (Markdown preview — **do not** use BBCode or `•` bullets).

Tips: blank line before each list; each line starts with `-` + space; use `**bold**` and `` `code` `` for code.

**Download URL for this version:**  
`https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.5.0-beta2.1/VisualGasic_AssetLibrary_v5.5.0-beta2.1.zip`

---

## Paste into Asset Library (Markdown)

```markdown
**VisualGasic 5.5.0-beta2.1** — September 19, 2026  
Patch on [5.5.0-beta2](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.5.0-beta2) · Godot 4.6+ · **Same** Linux / Windows GDExtension binaries as beta2

**What changed**

Addon-only hotfix (GDScript). No C++ / VM rebuild — drop-in over **5.5.0-beta2**.

**VG code editor**

- **VG Help** — Caret on a user symbol (e.g. `Dim code As Integer`) shows type, scope, definition line, and **Go to Definition** in the floating Command Help panel (not only built-in keywords like `Dim` or `If`)
- **Find / Replace** — **Ctrl+F**, **Ctrl+H**, **F3** / **Shift+F3**, Edit menu, and right-click **Find…** / **Replace…**; find bar stays attached in the floating VG Code Editor
- **Go To Definition** — Shared Import / module resolution for cross-file navigation in the addon

**Unchanged from 5.5.0-beta2**

- Narcea Live Debug Capture, runtime fixes (`Connect`, lambdas, `RemoveAt`, autoload globals), benchmarks (**12/12** compute · **9/9** draw vs GDScript)
- Same `.so` / `.dll` in this zip as beta2 (Sep 19 builds)

**Upgrade**

- Replace your project’s `addons/visual_gasic/` with this zip (or wait for AssetLib to offer **5.5.0-beta2.1** after moderator approval)
- From **5.5.0-beta2**: overwrite addon folder only — no extension rebuild required
- From **5.5.0-beta1** or **5.4.x**: use this zip as a full addon install

**Links**

- Release notes: https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_NOTES_v5.5.0-beta2.1.md
- Changelog: https://github.com/xgreenrx-star/VisualGasic/blob/main/CHANGELOG.md#550-beta21---2026-09-19
- Download: https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.5.0-beta2.1/VisualGasic_AssetLibrary_v5.5.0-beta2.1.zip
```

---

## Editor note (Godot AssetLib dock)

The in-editor changelog view may show lists with extra spacing (known Godot backend quirk). The **web store Preview** is the source of truth for moderator review. If a list looks broken in-editor only, the web preview is still acceptable.

---

## BBCode (legacy — do not use on store.godotengine.org)

Older docs used `[b]` / `[ul]` for the editor RichTextLabel. The **new Asset Store manage UI renders Markdown** and shows BBCode tags as literal text.
