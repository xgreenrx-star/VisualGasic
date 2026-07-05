# VisualGasic Plugin System

The VisualGasic IDE supports **plugins** — self-contained editor extensions that register their own toolbar button and full-screen view inside the IDE.  Plugins are discovered automatically at startup from the `plugins/` directory and integrate seamlessly with the existing Form, Code, 3D, 2D, and Sprite Editor views.

Official plugins:

| Plugin | Toolbar button | Description |
|---|---|---|
| **AGCK** | 🕹️ AGCK | Arcade Game Construction Kit — 5 retro game sub-editors |
| **Bosca Ceoil** | 🎵 Bosca Ceoil | Chiptune / music tracker — WAV, OGG, and MML export |

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Directory Layout](#directory-layout)
3. [Plugin Configuration (plugin.cfg)](#plugin-configuration)
4. [The Plugin Base Class](#the-plugin-base-class)
5. [The Plugin Manager](#the-plugin-manager)
6. [View Switching & Lifecycle](#view-switching--lifecycle)
7. [Creating a Plugin — Step by Step](#creating-a-plugin--step-by-step)
8. [Complete Example: AGCK](#complete-example-agck)
9. [Serialization & Project Files](#serialization--project-files)
10. [API Reference](#api-reference)

> See also: [Bosca Ceoil Manual](../manual/BOSCA_CEOIL_MANUAL.md) for full usage of the built-in music tracker.


```
┌─────────────────────────────────────────────────────────────┐
│  visual_gasic_plugin.gd  (host IDE)                         │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  vg_plugin_manager.gd  (RefCounted)                  │   │
│  │                                                      │   │
│  │   ┌─────────────┐  ┌─────────────┐  ┌───────────┐  │   │
│  │   │ Plugin A     │  │ Plugin B     │  │ Plugin C  │  │   │
│  │   │ (AGCK)       │  │ (future)     │  │ (future)  │  │   │
│  │   │              │  │              │  │           │  │   │
│  │   │ extends      │  │ extends      │  │ extends   │  │   │
│  │   │ vg_plugin_   │  │ vg_plugin_   │  │ vg_plugin │  │   │
│  │   │ base.gd      │  │ base.gd      │  │ _base.gd  │  │   │
│  │   └─────────────┘  └─────────────┘  └───────────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                             │
│  Toolbar:  [Form] [Code] [3D] [2D] [Sprite] [🕹️ AGCK] ··· │
│  Canvas:   CanvasRightSplit  (one view visible at a time)   │
└─────────────────────────────────────────────────────────────┘
```

**Key design principles:**

| Principle | Description |
|-----------|-------------|
| **One tab per plugin** | Each plugin adds exactly one toolbar button.  Sub-editors live *inside* the plugin's view (e.g. AGCK uses a `TabContainer` with 5 tabs). |
| **RefCounted lifecycle** | Plugins extend `RefCounted`, not `Node`.  Their view `Control` is parented to `CanvasRightSplit` by the manager. |
| **Auto-discovery** | Drop a folder with a `plugin.cfg` into `plugins/` — the manager finds it at startup. |
| **Mutual exclusion** | Only one view is visible at a time.  Activating a plugin hides all built-in editors (Form, Code, 3D, 2D, Sprite) and vice versa. |
| **Clean separation** | Plugins know nothing about each other.  The manager handles all coordination. |

---

## Directory Layout

```
addons/visual_gasic/
├── vg_plugin_base.gd          ← base class (extend this)
├── vg_plugin_manager.gd       ← discovery & lifecycle manager
├── plugins/
│   ├── agck/                  ← one folder per plugin
│   │   ├── plugin.cfg         ← INI config (required)
│   │   ├── agck_plugin.gd     ← main plugin script (extends vg_plugin_base.gd)
│   │   ├── agck_game_settings.gd
│   │   ├── agck_actor_editor.gd
│   │   ├── agck_sound_editor.gd
│   │   ├── agck_level_editor.gd
│   │   └── agck_game_builder.gd
│   └── my_plugin/             ← your custom plugin
│       ├── plugin.cfg
│       └── my_plugin.gd
└── visual_gasic_plugin.gd     ← host IDE (integrates the manager)
```

Each plugin lives in its own subfolder under `plugins/`.  The folder name becomes the **plugin ID** used internally (e.g. `"agck"`).

---

## Plugin Configuration

Every plugin requires a `plugin.cfg` file in its folder.  This is a standard Godot `ConfigFile` (INI format):

```ini
[plugin]
name=AGCK
description=Arcade Game Construction Kit — build retro arcade games with visual editors
script=agck_plugin.gd
enabled=true
```

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `name` | String | Yes | Display name shown in the toolbar button |
| `description` | String | No | Tooltip / description text |
| `script` | String | Yes | Filename of the main plugin GDScript (relative to the plugin folder) |
| `enabled` | bool | No | Set to `false` to permanently disable (e.g. incomplete/deprecated). Defaults to `true`. |
| `experimental` | bool | No | If `true`, the plugin is hidden unless `vg/enable_experimental_plugins=true` in Project Settings. |
| `ignore_dirs` | Array | No | Subdirectories (relative to the plugin folder) to `.gdignore` when the plugin is disabled. Use this for any directory whose scripts reference an autoload that the plugin registers — prevents GDScript parse errors on every project open when the plugin is off. |

### Autoloads

If your plugin needs a GDScript autoload (a global singleton), declare it in a `[autoloads]` section.  The VG plugin manager registers and unregisters these automatically.

```ini
[autoloads]

MyGlobal="my_globals.gd"
```

> **Important:** Autoloads are only wired into GDScript's global scope at engine startup.  After enabling a plugin that adds a new autoload, VisualGasic must be restarted once before the autoload is accessible.  The manager warns the user about this automatically.

If many scripts inside your plugin reference the autoload identifier at the top level, combine `[autoloads]` with `ignore_dirs` to suppress the parse errors that appear while the plugin is disabled:

```ini
[plugin]
name=My Music Tool
script=my_music_plugin.gd
enabled=false
ignore_dirs=["src"]

[autoloads]

MyController="src/globals/MyController.gd"
```

When the plugin is disabled the VG plugin manager writes an empty `.gdignore` into each listed directory, telling Godot's resource scanner to skip those files.  When the plugin is enabled the `.gdignore` files are removed so the scripts load normally.

---

## The Plugin Base Class

**File:** `addons/visual_gasic/vg_plugin_base.gd`

All plugins extend this class.  It provides lifecycle management, a root `Control` view, and virtual methods for customization.

### Signals

| Signal | Description |
|--------|-------------|
| `back_to_form_requested` | Emit this (via `request_back_to_form()`) to return to the Form view |

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `_view` | `Control` | Root container added to `CanvasRightSplit`.  Created automatically as an `HSplitContainer`. |
| `_host_plugin` | `Variant` | Reference to `visual_gasic_plugin.gd` (the main IDE plugin) |
| `_manager` | `Variant` | Reference to `vg_plugin_manager.gd` |
| `_is_active` | `bool` | Whether this plugin's view is currently visible |

### Virtual Methods (Override These)

```gdscript
## Return the display name for the toolbar button.
func get_plugin_name() -> String:
    return "My Plugin"

## Return an emoji or icon prefix for the toolbar button.
func get_toolbar_icon() -> String:
    return "🔧"

## Return the background color of the toolbar button.
func get_toolbar_color() -> Color:
    return Color(0.35, 0.35, 0.4)

## Return the tooltip for the toolbar button.
func get_toolbar_tooltip() -> String:
    return "Switch to My Plugin"

## Build your UI here.  Add children to _view.
func _build_ui() -> void:
    pass

## Called every time the plugin becomes visible.
func _on_activated() -> void:
    pass

## Called every time the plugin becomes hidden.
func _on_deactivated() -> void:
    pass

## Called when the host IDE exits the tree (final cleanup).
func _on_cleanup() -> void:
    pass
```

### Lifecycle Methods (Do Not Override)

| Method | Called By | Description |
|--------|-----------|-------------|
| `initialize(host, manager) -> Control` | Plugin Manager | Creates the view, calls `_build_ui()`, returns the root `Control` |
| `activate()` | Plugin Manager | Shows the view, sets `_is_active = true`, calls `_on_activated()` |
| `deactivate()` | Plugin Manager | Hides the view, sets `_is_active = false`, calls `_on_deactivated()` |
| `cleanup()` | Plugin Manager | Calls `_on_cleanup()`, frees the view |
| `request_back_to_form()` | Your code | Convenience: emits `back_to_form_requested` |

---

## The Plugin Manager

**File:** `addons/visual_gasic/vg_plugin_manager.gd`

The manager is instantiated by the host IDE during `_enter_tree()`.  It handles discovery, toolbar button creation, and view switching coordination.

### Signals

| Signal | Description |
|--------|-------------|
| `plugin_activated(plugin_id: String)` | A plugin view is now active — host should hide built-in editors |
| `all_plugins_deactivated` | No plugin is active — host should return to Form view |

### Key Methods

| Method | Description |
|--------|-------------|
| `setup(host, toolbar_row, canvas_right_split)` | Initialize with references to the host IDE's toolbar and canvas |
| `discover_plugins()` | Scan `plugins/` directory, load each valid plugin |
| `activate_plugin(plugin_id)` | Show a specific plugin's view (deactivates any current one) |
| `deactivate_all()` | Hide all plugin views |
| `has_active_plugin() -> bool` | Check if any plugin is currently active |
| `get_active_plugin_id() -> String` | Get the ID of the currently active plugin |
| `get_plugin(plugin_id) -> Variant` | Get a loaded plugin instance by ID |
| `get_plugin_ids() -> Array` | List all loaded plugin IDs |
| `cleanup()` | Destroy all plugins and their toolbar buttons |

### Toolbar Button Placement

The manager automatically creates a styled toolbar button for each plugin and inserts it **before the spacer widget** in the toolbar row.  This ensures plugin buttons appear alongside the built-in view buttons (Form, Code, 3D, 2D, Sprite) while the "↩ Godot Editor" button stays at the far right.

```
[📝 Form] [💻 Code] [🎲 3D] [🎮 2D] [🎨 Sprite] [🕹️ AGCK]  ←spacer→  [↩ Godot Editor]
```

Button styling (background color, hover/pressed states) is derived from the plugin's `get_toolbar_color()` return value.

---

## View Switching & Lifecycle

The IDE maintains mutual exclusion across all views:

```
Built-in views                        Plugin views
─────────────                         ────────────
_showing_code_view                    _showing_plugin_view
_showing_3d_view
_showing_2d_view
_showing_sprite_view
(form view = none of the above)
```

When a plugin is activated:
1. The manager emits `plugin_activated(id)`
2. The host IDE receives the signal and:
   - Saves any dirty code editor content
   - Sets all `_showing_X_view` booleans to `false`, sets `_showing_plugin_view = true`
   - Hides the canvas scroll, code editor, 3D editor, 2D editor, and sprite editor
   - Hides the left toolbox panel
   - Updates the status bar
3. The manager calls `plugin.activate()` → the plugin's view becomes visible

When switching back to a built-in view (Form, Code, 3D, 2D, Sprite):
1. The host IDE calls `_vg_plugin_manager.deactivate_all()`
2. The manager calls `plugin.deactivate()` on the active plugin
3. The host IDE shows the appropriate built-in editor

When a plugin requests returning to Form (e.g. via a "↩ Back" button):
1. Plugin calls `request_back_to_form()`
2. Base class emits `back_to_form_requested`
3. Manager receives it, calls `deactivate_all()`, emits `all_plugins_deactivated`
4. Host IDE calls `_show_form_view()`

---

## Creating a Plugin — Step by Step

### Step 1: Create the Plugin Folder

```
addons/visual_gasic/plugins/my_tool/
```

### Step 2: Create plugin.cfg

```ini
[plugin]
name=My Tool
description=A custom tool for VisualGasic
script=my_tool_plugin.gd
enabled=true
# ignore_dirs=["vendor"]  # uncomment if vendor/ scripts reference an autoload
```

### Step 3: Create the Plugin Script

```gdscript
@tool
extends "res://addons/visual_gasic/vg_plugin_base.gd"

func get_plugin_name() -> String:
    return "My Tool"

func get_toolbar_icon() -> String:
    return "🛠️"

func get_toolbar_color() -> Color:
    return Color(0.3, 0.5, 0.7)

func _build_ui() -> void:
    # _view is an HSplitContainer — add your UI here
    var panel = VBoxContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

    var title = Label.new()
    title.text = "🛠️  MY TOOL"
    title.add_theme_font_size_override("font_size", 18)
    panel.add_child(title)

    var info = Label.new()
    info.text = "This is a custom VG IDE plugin!"
    panel.add_child(info)

    var back_btn = Button.new()
    back_btn.text = "↩ Back to Form"
    back_btn.pressed.connect(request_back_to_form)
    panel.add_child(back_btn)

    _view.add_child(panel)

func _on_activated() -> void:
    print("My Tool: activated!")

func _on_deactivated() -> void:
    print("My Tool: deactivated")
```

### Step 4: Deploy

Copy your plugin folder to every project that uses VisualGasic:

```
my_project/addons/visual_gasic/plugins/my_tool/
    plugin.cfg
    my_tool_plugin.gd
```

The plugin will be discovered automatically when Godot loads the editor.

---

## GDAI / AI Provider Integration

VisualGasic includes a reusable AI integration layer under `addons/visual_gasic/gdai.gd`.
This singleton exposes a normalized provider abstraction, project settings persistence,
and a small provider registry so plugins and IDE features can all call the same AI API.

### Core `GDAI` API

The singleton is designed for plugin and tool authors who want to consume or extend
VisualGasic's AI assistant support.

- `GDAI.initialize(config: Dictionary)`
  - Validates the configuration and instantiates the configured provider.
- `GDAI.initialize_from_project_settings()`
  - Loads saved project settings from `vg/gdai/*` and initializes the provider.
- `GDAI.save_project_settings(config: Dictionary)`
  - Writes `vg/gdai/*` settings back into `ProjectSettings`.
- `GDAI.is_enabled()`
  - Returns `true` when AI is enabled and a provider is ready.
- `GDAI.complete(prompt: String, options: Dictionary = {})`
  - Async completion API.
- `GDAI.chat(messages: Array, options: Dictionary = {})`
  - Async chat-style interaction API.
- `GDAI.embed(text: String, options: Dictionary = {})`
  - Async embedding API.
- `GDAI.generate_image(prompt: String, options: Dictionary = {})`
  - Async image generation API.
- `GDAI.register_provider(provider_id: String, script_path: String, metadata: Dictionary = {})`
  - Registers a custom provider implementation.
- `GDAI.supported_providers()`
  - Returns the list of registered provider IDs.
- `GDAI.get_provider_info(provider_id: String)`
  - Returns metadata for a provider.
- `GDAI.get_last_error()` / `GDAI.has_error()`
  - Read the last validation or provider error.

### Provider contract

Custom providers should extend `res://addons/visual_gasic/gdai_provider.gd` and
implement the provider interface:

```gdscript
@tool
extends "res://addons/visual_gasic/gdai_provider.gd"

func initialize(config: Dictionary) -> void:
    pass

func complete(prompt: String, options: Dictionary = {}) -> String:
    return ""

func chat(messages: Array, options: Dictionary = {}) -> String:
    return ""

func embed(text: String, options: Dictionary = {}) -> Array:
    return []

func generate_image(prompt: String, options: Dictionary = {}) -> Dictionary:
    return {}
```

### Built-in providers

The default registry includes two providers:

- `openai` — hosted OpenAI-compatible API endpoint.
- `local` — local OpenAI-compatible endpoint for private/offline deployments.

### Project settings

The AI integration stores configuration under `vg/gdai/`.
The supported keys are:

- `enabled`
- `provider`
- `api_key`
- `endpoint`
- `model`
- `embedding_model`
- `temperature`
- `max_tokens`
- `top_p`
- `n`
- `timeout_ms`

Use `GDAI.initialize_from_project_settings()` during plugin startup to read the
current project configuration, or call `GDAI.load_project_settings()` directly.
A dedicated **Project Properties → GDAI** tab is also available in the IDE.

### Registering a custom provider

```gdscript
GDAI.register_provider("my_local", "res://addons/visual_gasic/gdai_my_local_provider.gd", {
    "display_name": "My Local LLM",
    "description": "Local OpenAI-compatible provider",
    "requires_api_key": false,
    "default_endpoint": "http://127.0.0.1:8000/v1",
    "default_model": "gpt-4o-mini",
    "help_url": ""
})
```

Then initialize the integration with your provider:

```gdscript
GDAI.initialize({
    "enabled": true,
    "provider": "my_local",
    "endpoint": "http://127.0.0.1:8000/v1",
    "model": "gpt-4o-mini",
})
```

Provider IDs are case-insensitive.

### Plugin capabilities

If your plugin exposes AI-related features, declare them in `plugin.cfg`:

```ini
[capabilities]
provides = ["ai.assistant", "ai.prompt"]
handles_extensions = []
priority = 5
```

This makes it easy for the host and other plugins to discover and route AI helpers.

---

## Complete Example: AGCK

The **Arcade Game Construction Kit** is the reference implementation for the plugin system.  It demonstrates how to build a complex, multi-tab plugin with five sub-editors.

### File Structure

```
plugins/agck/
├── plugin.cfg              ← Discovery config
├── agck_plugin.gd          ← Main plugin (TabContainer with 5 tabs)
├── agck_game_settings.gd   ← ⚙️ Game Settings (environment editor)
├── agck_actor_editor.gd    ← 👾 Actors (actor definition editor)
├── agck_sound_editor.gd    ← 🔊 Sounds (waveform synthesizer)
├── agck_level_editor.gd    ← 🗺️ Levels (tile-based screen painter)
└── agck_game_builder.gd    ← 🏗️ Build (game assembly & export)
```

### Main Plugin (agck_plugin.gd)

The main plugin extends `vg_plugin_base.gd` and creates a `TabContainer` with 5 tabs in `_build_ui()`:

```gdscript
@tool
extends "res://addons/visual_gasic/vg_plugin_base.gd"

func get_plugin_name() -> String:   return "AGCK"
func get_toolbar_icon() -> String:  return "🕹️"
func get_toolbar_color() -> Color:  return Color(0.85, 0.55, 0.2)

func _build_ui() -> void:
    _tab_container = TabContainer.new()
    _tab_container.tab_alignment = TabBar.ALIGNMENT_CENTER
    # ... load and instantiate each sub-editor ...
    _tab_container.add_child(_game_settings)  # Tab 1
    _tab_container.add_child(_actor_editor)   # Tab 2
    _tab_container.add_child(_sound_editor)   # Tab 3
    _tab_container.add_child(_level_editor)   # Tab 4
    _tab_container.add_child(_game_builder)   # Tab 5
    _view.add_child(_tab_container)
```

### Data Flow Between Sub-Editors

AGCK demonstrates cross-editor communication:

- When actors are added/renamed in the **Actor Editor**, the plugin syncs actor names to the **Level Editor** so the actor placement dropdown stays current.
- The **Game Builder** collects data from all four other editors via their `get_data()` methods when the user clicks Build.
- All sub-editors implement `get_data()` / `set_data()` for serialization.

### Save/Load (.agck Project Files)

The main plugin provides `save_project(path)` and `load_project(path)` methods that serialize all sub-editor data into a single JSON file:

```json
{
    "settings": { "game_title": "Space Blaster", "gravity_strength": 50, ... },
    "actors": [ { "name": "Hero", "type": "Player", "speed": 60, ... }, ... ],
    "sounds": [ { "name": "Laser", "tempo": 50, "voice1_notes": [...], ... }, ... ],
    "levels": [ { "name": "Level 1", "grid": [[0,1,0,...], ...], "actors": [...] }, ... ],
    "build": { "target": 0, "splash_text": "Made with AGCK", ... }
}
```

---

## Serialization & Project Files

Plugins are responsible for their own serialization.  The recommended pattern:

1. Each sub-editor implements `get_data()` → returns a `Dictionary` or `Array`
2. Each sub-editor implements `set_data(data)` → restores from a `Dictionary` or `Array`
3. The main plugin collects all data into one `Dictionary` and saves as JSON

```gdscript
func save_project(path: String) -> bool:
    var data = {
        "editor_a": _editor_a.get_data(),
        "editor_b": _editor_b.get_data(),
    }
    var file = FileAccess.open(path, FileAccess.WRITE)
    file.store_string(JSON.new().stringify(data, "\t"))
    file.close()
    return true
```

---

## API Reference

### vg_plugin_base.gd

| Member | Type | Description |
|--------|------|-------------|
| `back_to_form_requested` | Signal | Emitted to request Form view |
| `_view` | `Control` | Root view (HSplitContainer) |
| `_host_plugin` | `Variant` | Host IDE reference |
| `_manager` | `Variant` | Plugin Manager reference |
| `_is_active` | `bool` | Current visibility state |
| `get_plugin_name()` | Virtual | Display name |
| `get_toolbar_icon()` | Virtual | Emoji/icon for button |
| `get_toolbar_color()` | Virtual | Button background color |
| `get_toolbar_tooltip()` | Virtual | Button tooltip |
| `_build_ui()` | Virtual | Populate `_view` with UI |
| `_on_activated()` | Virtual | Shown callback |
| `_on_deactivated()` | Virtual | Hidden callback |
| `_on_cleanup()` | Virtual | Exit-tree cleanup |
| `initialize(host, mgr)` | Lifecycle | Create view, returns `Control` |
| `activate()` | Lifecycle | Show + activate |
| `deactivate()` | Lifecycle | Hide + deactivate |
| `cleanup()` | Lifecycle | Destroy everything |
| `request_back_to_form()` | Convenience | Emit `back_to_form_requested` |

### vg_plugin_manager.gd

| Member | Type | Description |
|--------|------|-------------|
| `plugin_activated(id)` | Signal | A plugin view is now active |
| `all_plugins_deactivated` | Signal | All plugins hidden |
| `setup(host, toolbar, canvas)` | Method | Initialize with IDE references |
| `discover_plugins()` | Method | Scan and load from `plugins/` |
| `activate_plugin(id)` | Method | Show a plugin |
| `deactivate_all()` | Method | Hide all plugins |
| `has_active_plugin()` | Method | Returns `bool` |
| `get_active_plugin_id()` | Method | Returns `String` |
| `get_plugin(id)` | Method | Returns plugin instance |
| `get_plugin_ids()` | Method | Returns `Array` of IDs |
| `cleanup()` | Method | Destroy all plugins |

---

## ▶ Play Menu Integration  *(new in 5.1.0)*

Plugins can surface their own actions in the unified **▶ Play**
MenuButton that lives in the top toolbar, and can also intercept the
**F5 / Ctrl+F5 / Shift+F5** keyboard shortcut when their view is
active. This is the recommended way for a plugin to expose a "Run"
action — the user gets one consistent entry point instead of a
per-plugin run button hidden inside each view.

### Adding Entries to the Play Menu

Call `form_preview_toolbar.add_menu_item(label, callback)` from your
plugin's `_on_activated()` (or any post-setup hook) and
`remove_menu_item(id)` from `_on_cleanup()`:

```gdscript
var _play_menu_ids: Array[int] = []

func _get_play_toolbar():
    if _host_plugin and "form_preview_toolbar" in _host_plugin:
        return _host_plugin.form_preview_toolbar
    return null

func _register_play_menu_entries() -> void:
    var tb = _get_play_toolbar()
    if tb == null:
        return
    _play_menu_ids.append(tb.add_menu_item("Run Graph   F5", _run_graph))
    _play_menu_ids.append(tb.add_menu_item("Run Graph Headless", _run_graph_headless))

func _on_cleanup() -> void:
    var tb = _get_play_toolbar()
    if tb:
        for id in _play_menu_ids:
            tb.remove_menu_item(id)
    _play_menu_ids.clear()
```

IDs returned by `add_menu_item` are always ≥ 1000 so they cannot
collide with the built-in entries (100 – 104).

### Intercepting F5 / Ctrl+F5 / Shift+F5

Override the optional `on_play_shortcut(ctrl: bool, shift: bool) -> bool`
method on your plugin. Return `true` to consume the event; return
`false` (or don't implement it at all) to let the toolbar fall through
to the default `Run Current Scene` behavior:

```gdscript
## Called by the host when the user presses F5 / Ctrl+F5 / Shift+F5
## while this plugin's view is active. Return true to consume.
func on_play_shortcut(ctrl: bool, shift: bool) -> bool:
    if ctrl:
        return false              # Let Run Main Scene fall through
    if shift:
        _run_graph_headless()
    else:
        _run_graph()
    return true
```

The host checks `vg_plugin_manager.get_active_plugin_id()` and only
dispatches to the active plugin — inactive plugins never receive the
shortcut.

---

## Form Designer as a Toggleable Plugin  *(new in 5.1.0)*

The legacy VB6-style Form Designer now appears as a row in the
**Plugin Settings** dialog (⚙ icon in the plugin strip) and can be
disabled per-project via `ProjectSettings` path
`vg/form_designer_enabled`. When disabled:

- The "🎨 Form Designer" plugin-strip button is removed.
- The legacy top-toolbar `▣ Form` mode-toggle button is hidden.
- Form-specific widgets (alignment toolbar, color palette, Indexes
  toggle, Live/Freeze toggle) are hidden in every view.
- The startup auto-open-first-form behavior is skipped — projects
  start in the code editor.

New projects created by the `install.sh` bootstrap installer set
`vg/default_mode = "code"`, matching the code-first default.

---

## Tips & Best Practices

- **Use `@tool`** on all sub-editor scripts so they run in the Godot editor.
- **Extend `VBoxContainer` or `HSplitContainer`** for sub-editors — they size correctly inside `TabContainer`.
- **Set `size_flags_horizontal = SIZE_EXPAND_FILL`** and `size_flags_vertical = SIZE_EXPAND_FILL` on all top-level children to fill the available space.
- **Follow the VG theme colors** (background `Color(0.16, 0.16, 0.19)`, section headers `Color(0.22, 0.26, 0.35)`, label text `Color(0.75, 0.8, 0.85)`) for visual consistency.
- **Implement `get_data()` / `set_data()`** on every sub-editor for clean serialization.
- **Use signals** for cross-editor communication instead of direct method calls.
- **Test with headless Godot** to catch parse errors before deployment:

```bash
./Godot --headless --path your_project --check-only --script res://addons/visual_gasic/plugins/my_plugin/my_plugin.gd
```
