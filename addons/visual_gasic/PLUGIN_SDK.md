# VisualGasic Plugin SDK

VisualGasic plugins extend the IDE with new editors, generators, panels, and
commands. The runtime is **plugin-type-agnostic**: the core never special-cases
a plugin by name. Instead, plugins declare *capabilities* in their
`plugin.cfg`, and the host routes events/opens through three singletons:

| Singleton              | Purpose                                                  |
|------------------------|----------------------------------------------------------|
| `VGAssetBus`           | Process-wide signal bus for asset lifecycle events.      |
| `VGContextBroker`      | Tracks the currently active asset / project / selection. |
| `VGPluginRegistry`     | Capability + extension routing, default-provider config. |

A plugin that implements the contracts on this page will participate in:

- File-browser double-click → opens in the right editor.
- Command palette (Ctrl+P / Ctrl+Shift+P) quick-open + commands.
- Default-editor preferences UI (Plugin Settings → Default Editors).
- Recent-files MRU keyed by capability.
- File-system / external-change refresh.

…with **zero core changes**.

---

## 1. Plugin layout

```
addons/visual_gasic/plugins/<your_plugin>/
    plugin.cfg          # required, see §2
    <your_plugin>.gd    # required, extends VGPluginBase
    ...                 # any other resources your plugin uses
```

The script field in `plugin.cfg` is resolved relative to the plugin folder.

---

## 2. `plugin.cfg` schema

```ini
[plugin]
name        = "Friendly Display Name"
description = "One-line summary shown in Plugin Settings."
author      = "You"
version     = "1.0.0"
script      = "your_plugin.gd"

[capabilities]
provides           = ["asset_editor.sprite", "asset_editor.image"]
handles_extensions = ["png", "vgsprite"]
priority           = 50
```

### `[plugin]` (required)

| Key           | Type   | Notes                                                   |
|---------------|--------|---------------------------------------------------------|
| `name`        | String | Display name in toolbar / settings.                     |
| `description` | String | Tooltip in Plugin Settings.                             |
| `author`      | String | Free text.                                              |
| `version`     | String | Free text; SemVer recommended.                          |
| `script`      | String | Plugin entry-point script, must extend `VGPluginBase`.  |

### `[capabilities]` (optional but strongly recommended)

| Key                  | Type     | Notes                                                                  |
|----------------------|----------|------------------------------------------------------------------------|
| `provides`           | String[] | Capability ids you implement. See §3 for the namespace.                |
| `handles_extensions` | String[] | Lowercase, no leading dot (`["png", "vgsprite"]`, **not** `[".png"]`). |
| `priority`           | int      | Tie-break for capability lookup. Built-ins use 1–10. Plugins use 50.   |

Tie-break rule when two providers claim the same capability or extension:
**priority desc, then plugin_id asc**. The user can pin a default per
capability via Plugin Settings → Default Editors, which overrides priority.

---

## 3. Capability namespace

Use these prefixes — the host knows how to humanize and route them. Anything
else still works (your plugin can invent its own namespace) but won't be
auto-labelled in the UI.

| Prefix                | Meaning                                            | Example                       |
|-----------------------|----------------------------------------------------|-------------------------------|
| `asset_editor.<kind>` | Edits asset of *kind*. Implements `open_asset`.    | `asset_editor.sprite`         |
| `asset_generator.<k>` | Creates new asset of *k* on demand.                | `asset_generator.tilemap`     |
| `game_builder.<kind>` | Compiles/exports a runnable game.                  | `game_builder.platformer`     |
| `panel.<location>`    | Provides a dockable panel.                         | `panel.right_dock`            |
| `command.<id>`        | Adds a command-palette entry.                      | `command.open_release_notes`  |

**Subcapabilities** (`asset_editor.scene.2d`) are valid — the registry
treats them as opaque strings, so dotted hierarchy is purely a convention.

---

## 4. Plugin script contract

Your plugin script extends `VGPluginBase` (`res://addons/visual_gasic/vg_plugin_base.gd`).

```gdscript
@tool
extends "res://addons/visual_gasic/vg_plugin_base.gd"

func _on_activated() -> void:
    # Optional: build UI, attach to host, etc.
    pass

func _on_deactivated() -> void:
    # Optional: tear down UI.
    pass

# REQUIRED if you provide any asset_editor.* capability:
func open_asset(path: String) -> bool:
    # Load `path`, show your editor, focus it. Return true on success.
    if not _load(path):
        return false
    activate()
    return true
```

When the host (or another plugin) calls
`VGPluginRegistry.get_instance().open_asset(some_path)`:

1. Registry picks the highest-priority enabled provider whose
   `handles_extensions` matches, with the user's default winning if set.
2. Calls `inst.open_asset(path)` on that provider's instance.
3. If the call returns `true`, registry emits `VGAssetBus.asset_opened` and
   sets `VGContextBroker.current_asset`.
4. If `open_asset` is absent, registry falls back to `inst.activate()` (so
   capability-only providers like panels still work).

If you save user-visible asset data, **emit on the bus** so file-browser,
command-palette MRU, and external watchers stay in sync:

```gdscript
const _AssetBus := preload("res://addons/visual_gasic/vg_asset_bus.gd")

func _save_to_disk(path: String) -> void:
    # ... write file ...
    _AssetBus.get_instance().emit_saved(path, "<your_plugin_id>")
```

---

## 5. Singletons reference

### 5.1 `VGAssetBus`

Process-wide signals. **Always go through the bus** — never call file-browser
methods directly.

```gdscript
signal asset_opened    (path: String, by_plugin_id: String)
signal asset_modified  (path: String, by_plugin_id: String)  # in-memory only
signal asset_saved     (path: String, by_plugin_id: String)
signal asset_deleted   (path: String, by_plugin_id: String)
signal asset_invalidated(path: String, by_plugin_id: String)  # external change
signal asset_renamed   (old_path: String, new_path: String, by_plugin_id: String)
```

Helpers (use these instead of `emit_signal`):

```gdscript
VGAssetBus.get_instance().emit_saved(path, "my_plugin")
VGAssetBus.get_instance().emit_renamed(old_p, new_p, "my_plugin")
```

The `by_plugin_id` argument lets subscribers ignore their own emissions and
prevent feedback loops.

### 5.2 `VGContextBroker`

Tracks the IDE's notion of "current thing".

```gdscript
signal context_changed(kind: String, value: Variant)
# kind ∈ {"asset", "project", "object_id", "selection"}

func set_current_asset(path: String, by_plugin_id: String) -> void
func set_current_project(path: String, by_plugin_id: String) -> void
func set_current_object_id(id: int, by_plugin_id: String) -> void
func set_current_selection(node_paths: Array, by_plugin_id: String) -> void

func get_current_asset() -> String
func get_current_project() -> String
func get_current_object_id() -> int
func get_current_selection() -> Array
```

Sets dedup on equal value (selection always emits because arrays mutate).

### 5.3 `VGPluginRegistry`

Capability registry. Read-mostly from plugin code; the plugin manager
populates it from `plugin.cfg`.

```gdscript
func register_provider(plugin_id: String, meta: Dictionary, instance = null) -> void
func attach_instance(plugin_id: String, instance) -> void
func unregister_provider(plugin_id: String) -> void
func set_enabled(plugin_id: String, enabled: bool) -> void

func find_providers(capability: String) -> Array  # plugin_ids, sorted
func find_providers_for_path(path: String) -> Array
func get_default_for(capability: String) -> String  # "" = none
func set_default_for(capability: String, plugin_id: String) -> void
func get_default_for_path(path: String) -> String

func get_all_providers() -> Dictionary  # full meta snapshot
func get_provider(plugin_id: String) -> Dictionary

func open_asset(path: String) -> bool  # routes to best provider

signal providers_changed
```

Defaults are persisted in `ProjectSettings` under
`vg/plugin_registry/defaults/<capability>` and `vg/plugin_registry/defaults/ext.<extension>`.

---

## 6. Command-palette integration

```gdscript
const _Palette := preload("res://addons/visual_gasic/vg_command_palette.gd")

_Palette.get_instance().register_command(
    "my_plugin.do_thing",
    "Do The Thing",
    func(): _do_the_thing(),
    "My Plugin"  # category, optional
)
```

Commands appear in the `>` (Ctrl+Shift+P) palette. Use the
`<plugin_id>.<verb>` convention for `id`.

---

## 7. Cross-reference patterns

**Never** use `class_name` to reference sibling singletons from inside an
editor source file — `class_name` resolution is unreliable during
`--check-only` parses and during plugin reload. Always:

```gdscript
const _AssetBus := preload("res://addons/visual_gasic/vg_asset_bus.gd")
const _ContextBroker := preload("res://addons/visual_gasic/vg_context_broker.gd")
const _Registry := preload("res://addons/visual_gasic/vg_plugin_registry.gd")
```

Then call `_AssetBus.get_instance().emit_saved(...)` etc.

---

## 8. Worked example

```gdscript
# addons/visual_gasic/plugins/my_anim_editor/my_anim_editor.gd
@tool
extends "res://addons/visual_gasic/vg_plugin_base.gd"

const _AssetBus := preload("res://addons/visual_gasic/vg_asset_bus.gd")

var _ui: Control
var _current_path: String

func _on_activated() -> void:
    if not is_instance_valid(_ui):
        _ui = preload("res://addons/visual_gasic/plugins/my_anim_editor/ui.tscn").instantiate()
        host_get_main_container().add_child(_ui)
    _ui.show()

func _on_deactivated() -> void:
    if is_instance_valid(_ui):
        _ui.hide()

func open_asset(path: String) -> bool:
    if not FileAccess.file_exists(path):
        return false
    _current_path = path
    if not is_instance_valid(_ui):
        _on_activated()
    _ui.load_animation(path)
    activate()
    return true

func _on_save_pressed() -> void:
    if _current_path.is_empty():
        return
    _ui.save_animation(_current_path)
    _AssetBus.get_instance().emit_saved(_current_path, "my_anim_editor")
```

`plugin.cfg`:

```ini
[plugin]
name        = "My Animation Editor"
description = "Frame-by-frame animation editor."
author      = "Me"
version     = "0.1.0"
script      = "my_anim_editor.gd"

[capabilities]
provides           = ["asset_editor.animation"]
handles_extensions = ["vganim"]
priority           = 50
```

That's it. The IDE will:

- Show "My Animation Editor" in Plugin Settings → Installed Plugins.
- Offer it in Plugin Settings → Default Editors → "Edit Animation".
- Route double-click on `*.vganim` files to `open_asset`.
- Auto-refresh the file browser when you call `emit_saved`.
- Surface `*.vganim` files in Ctrl+P quick-open.
