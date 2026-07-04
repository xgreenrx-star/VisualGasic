# Changelog

All notable changes to Visual Gasic will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [5.3.0-Beta1] - 2026-07-03

### ✨ Added — 2D Canvas Toolbar Buttons (Jul 3, 2026)

- **🖼 Add VG Control** — opens the floating Toolbox window; select a control type, then click the 2D canvas to place it with VB6 naming (`Command1`, `Text1`, etc.)
- **📋 VG Properties** — opens the floating Properties window to inspect/edit VB6-style properties of the selected control
- **⚡ Wire Event** — creates the primary VB6 event stub (e.g. `Command1_Click`) for the selected control in the associated `.vg` script and opens the code editor at that location
- All three actions also available via **right-click context menu** on the 2D canvas

### ✨ Added — Plugin Opt-In via Project Settings (Jul 1, 2026)

- VG sub-plugins (AGCK, Working Nodes, UI Forms, VGMusic, etc.) are now **disabled by default**
- Enable per-project via `vg/plugins/<id>/enabled = true` in Project Settings
- The VG IDE layout no longer auto-opens on startup — switch to it via the "Visual Gasic IDE" toolbar button
- **Live reload** — toggling a plugin in Project Settings takes effect immediately (no editor restart)

### ✨ Added — Compact Plugins Dropdown (Jul 4, 2026)

- Per-plugin toolbar buttons replaced with a single **"Plugins ▾"** MenuButton on the 2D canvas toolbar
- Selecting a plugin from the dropdown activates it directly — no need to switch to the VG IDE first

### ✨ Added — Code Completion in Godot's Native Script Editor (Jul 4, 2026)

- Full VB6-aware autocomplete when editing `.vg` files in Godot's built-in Script editor
- **Dot-completion**: `TextBox1.` shows VB6-style properties (Text, Enabled, MaxLength, BackColor, etc.) first, then Godot ClassDB properties/methods below
- **`Me.`** shows all form controls plus form-level members (Caption, Width, Show, Hide, etc.)
- Control names, VB6 keywords, and `Dim`-declared variables all appear in regular completions
- Godot's own native completions preserved alongside VG items

### ✨ Added — Code Navigator Upgrade (Jul 1, 2026)

- Left dropdown (Object): lists `(General)` plus every control on the form
- Right dropdown (Procedure): shows only standalone procedures for `(General)`, or control-specific events when a control is selected
- `(General)` no longer shows control event handlers — matching VB6 behavior

### 🐛 Fixed (Jun 30–Jul 4, 2026)

- `dict.Count` / `dict.Keys` / `dict.Items` without parens — property access now works
- `arr.Count` / `arr.Length` without parens — VB6-style property on all array types
- `Join()` integer formatting — no `.0` suffix on integer arrays
- ByRef default parameters in recursive calls — no longer corrupts locals
- Removed dead `_on_vg_ctrl_chosen` referencing deleted `_vg_ctrl_popup`
- Fixed `project_properties.gd` — `.pressed` is a signal in Godot 4.6, use `.button_pressed`
- Fixed `gdai_local_provider.gd` — return types now match parent class signatures
- Removed duplicate shortcut handler block in `_input()`
- Code Navigator null class crash — fixed null `get_class()` in scene tree iteration
- Bosca "Controller not declared" errors — directories `.gdignore`d when vgmusic plugin is disabled

## [5.2.0-Beta3] - 2026-06-01

### 🧩 New — 2D Scene Editor: Instance Child Scene
Right-click the scene tree → **Instance Child Scene…** (or click the 🔗
button in the tree action row) to add an existing `.tscn` as a nested
scene under the selected node. The instance is parented to the selected
Node2D (or scene root), positioned at the view center, and uniquified by
name. `_save_scene` was hardened to preserve instance references on save
— `Node.duplicate()` now uses `DUPLICATE_USE_INSTANTIATION` and ownership
is set non-recursively so the saver writes `[node ... instance=ExtResource(…)]`
instead of flattening the instance into editable overrides.

### 🛠️ New — 2D Scene Editor: Drag-and-Drop Reparent + Change Type
The scene tree now accepts drag-and-drop reparenting. Drop **onto** a row
makes the dragged node a child of that row; drop **between** rows makes
it a sibling at that index. Global transforms are preserved when both
source and new parent are `Node2D`, so visuals don't jump. Cycle guard
prevents dropping a node onto itself or its descendants; name collisions
auto-uniquify.

A new **Change Type…** context-menu entry converts the selected node
between common 2D classes (`Node2D`, `Sprite2D`, `AnimatedSprite2D`,
`Area2D`, `StaticBody2D`, `RigidBody2D`, `CharacterBody2D`, `Camera2D`,
`Path2D`, `PathFollow2D`, `Marker2D`) by copying the common
Node2D/CanvasItem properties and re-parenting all children onto the new
node at the same tree index.

### 📦 Improved — Make EXE preserves presets across platforms
`File → Make EXE…` previously rewrote `export_presets.cfg` from scratch
on every build, wiping any preset for a different platform. Other
presets are now parsed out, preserved, and renumbered after the active
preset so building Linux then Web (or vice-versa) keeps both
configurations.

### 🛠️ New — Tweak Overlay: Source write-back (D3 MVP)
A new **→ Source** button in the tweak overlay writes runtime color
changes (`color`, `fill_color`, `modulate`, `self_modulate`) back into
the originating `.vg` source file via `VGTweakSource.patch_property`.
Supports both `Color(r, g, b[, a])` and named `Color.RED` forms. Other
properties continue to persist in the JSON tweak bag. Failure is
non-destructive — the runtime tweak is retained regardless.

### 🐛 Fixed
- **Tweak Overlay: asteroid / multi-command ghosting.** When a clicked
  draw command belonged to a `BeginGroup`/`EndGroup` block (e.g. an
  asteroid built from a fill polygon **plus** an outline polyline), the
  overlay would only move the topmost sibling — the other commands
  stayed at their original positions, leaving "ghost" geometry behind
  and a stretched selection rectangle covering both. Clicks on a
  grouped command now select the **whole group** so dragging moves
  every sibling together. Hold `Alt` to address one sibling individually
  (e.g. recolor just the outline). `VectorCanvas.get_target_bounds()`
  was added so group-target selection rectangles also track live
  position overrides.
- Two pre-existing `Cannot infer the type` parse errors in
  `vg_tweak_overlay.gd` and `vg_tweak/vg_tweak_inspector.gd` (loop-var
  type inference under Godot 4.6.1 strict mode).

## [5.2.0-Beta2] - 2026-05-18

### 🌐 New — Browser Dashboard
Embedded HTTP server serving a browser-based project dashboard with live
build logs, file explorer, multi-project switcher, headless launcher, and
system tray icon mode.

### 🎙️ New — Full-duplex realtime voice (Tier 2.5)
OpenAI Realtime API + Gemini Live full-duplex voice; VAD auto-stop; streaming
TTS sentence queue.

### 🔗 Improved — Working Nodes
Collapsible left panel, decluttered toolbar, Get Property output port, value
ports (orange Math sockets), scene-node/property pickers, quick-add buttons,
merged On Input nodes, invisible-caret fix, popup styling fixes.

### 🤖 Improved — AI Pair
Two-row toolbar (overflow fix), streaming performance pass, cross-plugin tools
(WN/AGCK/Forms/2D/3D), IDE self-modification with addon backup, Claude
max_tokens fix, real error message display.

### 🏗️ Improved — AGCK
Phase 4 behavior `.vg` files with `{{TOKEN}}` substitution; Save/Load Template;
fleshed-out Top-Down RPG and Endless Runner templates.

### 📦 Improved — Make EXE
Platform picker, missing template detection + download prompt, Web export
validation, dialog polish.

### 🏁 Improved — First-run & installer
2-step first-run wizard, Godot 4.6.1 auto-detect in installer, `vg new`
auto-launches Godot after project creation.

### 🧩 New — MCP Server
`apply_diff` tool; VG play/stop/read/write tools exposed to MCP clients.

### 🛠️ Improved — Form Designer
Promoted to proper sub-plugin; VB6 type names (TextBox, CommandButton); WN
node/property picker integration.

### 🐛 Fixed
- SIGSEGV crash creating a blank code-mode project
- Toolbox blank tabs and scrollbar styling
- GDScript parse errors (explicit types for calls/fenced/ok)
- Working Nodes settings popup exclusive-window crash
- plugin.cfg version corrected to 5.2.0-Beta1

### ⚠️ Known issue
VGMusic (Bosca Ceoil) shows a blank tab on first load; a VG restart fixes it.

### 🌐 New — VG⇄Godot coverage roadmap (Pass 1-5, ~140 plain-English verbs)
Five-pass rollout of namespace wrappers so VG programs can reach the full
Godot 4.6 capability surface in plain-English BASIC, no `get_node()` chains.
All passes smoke-verified; suite 700/700 VG assertions, 289/289 GDScript — all pass.

- **Pass 1 — math / utility** (commit `56416637`): `Quaternion`, `Basis`,
  `Transform2D` / `Transform3D`, `Plane`, `AABB` constructors;
  `Random.Int/Float/Range`, `Noise.Value/Seed`, `Curve` sampler; `Slerp`,
  `Color.HSV`, `Color.ToHSV`.
- **Pass 2 — `Camera` / `Sound` / `Speaker` namespaces** (commit `72fc322a`):
  flat namespace dispatch via `detect_namespace_call()` in the compiler.
  `Camera.Shake/Zoom/PanTo/Follow`, polyphonic `Sound.Play(name, volume_pct)`,
  `Speaker.Bus(name).Volume = pct`, percent volumes throughout.
- **Pass 3 — `Animation` / `Physics` / `Ray` / `Cell` / `Nav`** (commit
  `0196bbcd`): game-completeness verbs — `Animation.Play/Stop/Speed`,
  `Physics.Gravity/Bounce`, `Ray.Cast2D/Cast3D`, `Cell.Get/Set` (TileMap),
  `Nav.PathTo/Reached`, plus `Push`/`Pull`/`Spin` global aliases. Auto-signal
  wiring extended to `AnimationPlayer`, `Area2D/3D`, `RigidBody2D/3D`,
  `NavigationAgent2D/3D` so `Sub Hero_AnimationFinished()` /
  `Sub Goal_BodyEntered(body)` Just Work.
- **Pass 4 — `Screen` / `Joypad` / `Touch` / `Sensor` / `Permission` /
  `GPS` / `Steps`** (commit `4452e2e6`): phone & desktop runtime —
  `Screen.Width/Height/DPI/Orientation/IsFullScreen`, `Joypad.Stick/Button`,
  `Touch.Count/Position`, `Sensor.Accel/Gyro/Tilt` with
  `Sensor.Units("game" | "metric")` (default `"game"` = Gs and degrees per
  second), `Permission.Request/Status`, `Vibrate(ms)`. `GPS.*` /
  `Steps.*` reserved (Android plugin to follow).
- **Pass 5 — `Crypto` / `Theme` / `JS` / `Shader` / `Material` /
  `Skeleton` / `Bone` / `Video`** (commit `2065cb28`): power-user surface —
  `Crypto.SHA256/SHA1/MD5/Hex/Base64/HMAC`, `Theme.Set/Get` font/color
  overrides on Controls, `JS.Eval` (web export), `Shader.Set/Get` uniforms
  via `ShaderMaterial`, `Skeleton.Bone(name).Pose/Rest`,
  `Video.Play/Stop/IsPlaying`.

- **Bare-property syntax** (commit `74de0eda`): namespace members can now be
  read without parens. `Print Screen.Width` is the same `OP_CALL` as
  `Print Screen.Width()`. Reads like English, parens still work.

Total: 9 new namespaces, ~140 verbs, 20 files, +2,939 lines. See
`docs/coverage_roadmap.md` (todo) and the `_pass{1..5}_smoke.vg` test
programs under `test_proj/` for examples of every verb.

## [5.2.0-Beta1] - 2026-05-11

First beta on the 5.2 line. Linux x86_64 + Windows x64. macOS paused for
this line.

### 🤖 AI

- AI Help panel with 5 personas (general/coder/reviewer/gamedev/teacher)
  and preset commands (*Explain Error*, *Explain Code*, *Translate*,
  *Generate Tests*).
- Pluggable providers: Ollama (local), OpenAI, Claude, Gemini, all behind
  a single dropdown.
- Whisper-powered push-to-talk voice mode for the AI panel
  (`scripts/install_whisper.{sh,ps1}`).
- Narcea project scaffolder on the VG Welcome launcher: AI emits a full
  multi-file VG project from a chat prompt.
- AI Diff dialog — per-hunk accept/reject before any AI edit lands.
- AI-correctness harness shows VG ties Python at frontier scale (Sonnet
  4.5: 100/100) and **outperforms Python on a 7B local model**
  (qwen2.5-coder:7b: VG 100% vs GDScript 68%). See
  [`bench/ai_correctness/REPORT.md`](bench/ai_correctness/REPORT.md).

### 📱 Android (preview)

- `VGAndroidPlugin` scaffold (`addons/visual_gasic/plugins/`) — minimal
  Java/Kotlin Android plugin auto-enabled when the
  `Android - VGAndroidPlugin` Project Setting is on.
- New `GPS.*` namespace: `Lat`, `Lng`, `Alt`, `Speed`, `Accuracy` with
  auto-wired `GPS_Updated(lat, lng)` Sub.
- New `Steps.*` namespace: `Today`, `Total`, `Reset` with auto-wired
  `Steps_Detected(count)` Sub.
- New `Permission.*` namespace: `Has`, `Request`, `All` with auto-wired
  `Permission_Granted(name)` / `Permission_Denied(name)` Subs.
- Mobile showcase demos under `demos/Mobile/`: **TiltMaze** (accelerometer
  steering) and **Pedometer** (step counter with `Vibrate` haptics).

### 🌐 Pass 6 — namespace gap-fillers (commit `018c3315`)

Adds the verbs people asked for after Pass 1–5 shipped:

- `Camera.PanTo`, `Camera.Bounce`, `Camera.FlashColor`
- `Animation.Loop`
- `Physics.Gravity`, `Physics.GravityV2`, `Physics.GravityV3`, `Physics.Bounce`
- `Ray.Cast2D`, `Ray.Cast3D` (one-shot raycasts, no `RayCast2D/3D` node needed)
- `Joypad.IsConnected`, `Joypad.Stick`
- `Sensor.Magnetometer` (alias of `Sensor.Magnet`)
- `Crypto.Hex`, `Crypto.FromHex`, `Crypto.Base64`
- `Theme.Get`, `Theme.Set` (generic), plus `Shader.Set`/`Shader.Get` aliases
- `Speaker.Bus` namespace alias

### 🛠️ IDE / docs

- Command Help DB grew from 292 → **358** keyword entries — every Pass 1-6
  verb now has syntax, description, example, see-also neighbors, and a
  manual line-number deep-link (commit `dabcff2e`).
- Dot-completion IntelliSense for all Pass 1-5 namespaces, ~140 verbs
  (commit `d5d8bb42`).
- "v4.x–v5.1 Godot Namespace Wrappers" reference section added to
  `docs/VisualGasic_Language_Reference.md`, plus matching Pass-grouped
  summary in `docs/reference/GODOT_FUNCTIONS_REFERENCE.md` (commit
  `d93c2709`).
- 10 short namespace tutorials added under `tutorials/` (commit
  `9c44017d`).

### 🐛 Fixes (commit `f42f52c4`)

Three long-standing pre-existing test failures fixed:

- `test_file_permissions.vg` (13/13): added bytecode-VM `Kill` opcode
  with POSIX `unlink()` / Win32 `DeleteFileA()` fallback so symlinks
  actually get removed; previously silently no-op-ed.
- `test_stress_arrays.vg` (5/5): renamed reserved-keyword collision
  (`Cycle` was being parsed as a Cycle Through loop).
- `test_vg_routing.gd` (15/15): added the `RESULTS: x/y passed`
  sentinel line that `run_test_suite.sh` sniffs for.

### 🧪 Tests

**700/700** VG + **289/289** GDScript assertions, 0 failures on Linux
x86_64.

### ⚡ Speed (unchanged from v5.1)

VG still **2–92× faster than GDScript** on the published microbenchmarks
and **5× faster than C++** on StringConcat. See README "VG vs GDScript vs
C++" table or `demo/bench_output.txt`.

## [5.1.0-rc.2] - 2026-05-03

### 🪟 New — Welcome shell loading experience overhaul
- **Welcome shell opens fullscreen** ([`welcome_shell/welcome.gd`](welcome_shell/welcome.gd)) — `_ready()` sets `Window.MODE_FULLSCREEN` so the picker takes the screen on launch. No more half-painted Godot Project Manager flashing up before our UI does.
- **Always-on-top fullscreen cover during Godot startup** — when the user picks a project, the welcome window flips to `borderless = true` + `always_on_top = true` + `MODE_FULLSCREEN` *before* spawning the editor process. The cover stays painted until the IDE plugin clears `launching.flag`. This replaces two earlier failed approaches (post-spawn minimize, and `--position 30000,30000 --resolution 1x1` off-screen spawn) — both let the editor's first paint bleed onto the screen for several frames.
- **Custom-drawn modern circular spinner** — replaces the `ProgressBar` widget with a 48 px rotating-arc spinner (`draw_arc` track + leading 110° arc, ~0.9 rev/sec, blue while running → solid green ring on `set_meta("done", true)`). Sits in a `VBoxContainer` 40 px below the "Loading <project>…" label.
- **1.5 s tail-wait** — after `launching.flag` clears, the cover lingers an extra 1.5 s so Godot's first editor frame doesn't race the welcome shell's `quit()` and flash a sliver of the editor uncovered.
- **Named `_on_quit_pressed` handler** — the Quit button's lambda was extracted to a real method so it survives parse-error rebuilds and prints a diagnostic line (`[VG Welcome] Quit pressed`). Drops `always_on_top` + fullscreen before calling `get_tree().quit()` so the cover doesn't ghost above the desktop.

### 🧰 New — Form Designer toolbox expansion (15 controls)
Wired up in [`addons/visual_gasic/visual_gasic_plugin.gd::_register_extra_tools()`](addons/visual_gasic/visual_gasic_plugin.gd) (GDScript wrapper around `VisualGasicToolbox.add_tool(name, godot_class, icon, scene, category)` — no C++ rebuild required).

**Standard 2D tab — 10 new controls:**
- **Spinner** ([`prototypes/Spinner.tscn`](addons/visual_gasic/prototypes/Spinner.tscn)) — `@tool` rotating-arc indeterminate indicator, runs live in the designer.
- **BusyDots** — three dots bouncing in sequence; cleaner than a spinner for inline "thinking" states.
- **ToggleSwitch** — slide toggle that emits `toggled(pressed)`. Stand-in for the missing iOS-style switch in stock Godot.
- **ColorPickerButton** — Godot's `ColorPickerButton` exposed as a Toolbox tool.
- **LinkButton** — hyperlink-style label-button with underline-on-hover.
- **HSplit** / **VSplit** — pre-populated `HSplitContainer` / `VSplitContainer` with named Left/Right (or Top/Bottom) `Panel` children so dropping it on the canvas gives you something visible immediately.
- **VideoPlayer** — `VideoStreamPlayer` wrapped as a draggable tool.
- **Expander** — collapsible header + content panel (`@tool`, fold animation runs in the editor).
- **Breadcrumbs** — `LinkButton` chain with `▸` separators; `set_path([...])` API.

**Game UI tab — 5 new controls** (kept separate from Standard tab so the retro/HUD aesthetics don't clutter regular OS-form work):
- **PixelProgressBar** — 8-bit pixel-cell progress bar with configurable cell count and gap (`@tool`, designer-live).
- **SegmentedProgressBar** — rounded multi-chunk bar for stamina / shield gauges.
- **RetroLifeBar** — health bar that HSV-shifts green → yellow → red as `value` drops, with thick black outline and highlight strip. Drop-in for top-down RPGs.
- **CircularProgress** — determinate ring (`draw_arc`) with center `%` label.
- **Badge** — pill / circle count overlay (notification dot). Hides at 0, displays "99+" at overflow.

### 🛠 Fixes (rc.2)
- **`launching.flag` handoff race** — `_clear_vg_launching_flag` was deferred from `_enter_tree`, but earlier rc.1 builds also tried to minimize / move the editor window after the plugin was up, which fought the welcome cover. The whole minimize-after-spawn path is gone; the cover handles concealment instead.
- **Spinner lambda scope clash** — `_make_circular_spinner` had a local `center` variable that collided with `Control.center` in the `_draw` callback, throwing a parse error on plugin reload. Renamed to `center_box`.
- **`recent_projects.cfg` re-seed support** — `_record_recent_vg_project` now survives a missing-file read cleanly so users who deleted the cfg (or upgraded across the JSON-vs-Array format change) get a fresh `[recent]` section instead of a silent no-op.

### 🚪 New — VG Welcome launcher (skip Godot's Project Manager)
- **VG Welcome shell** ([`welcome_shell/`](welcome_shell/)) — a tiny Godot app that replaces Godot's stock Project Manager with a VG-branded picker. Reads the cross-project recent list, shows per-project icon thumbnails (`icon.svg`/`png`/`webp`), live free-text search, auto-derived tag chips with counts, **Forget Selected**, and **Ask Narcea to Make a Project** which scaffolds `~/Documents/VisualGasic_Projects/<name>/` and drops a `narcea_seed.txt` the IDE picks up on first open to pre-fill the AI panel.
- **`./vg-ide` (Linux / macOS) and `.\vg-ide.ps1` (Windows)** — dependency-free launcher scripts that skip the Godot PM and open the welcome shell by default. Flags: `--last` / `-Last` (or `VG_OPEN_LAST=1`) to jump into the most-recent project; pass an explicit project dir to bypass the picker. `VG_GODOT` overrides binary discovery; macOS resolves `Godot.app` bundles, Windows resolves Program Files / LOCALAPPDATA install layouts.
- **File → Exit to VG Welcome** — new menu item in the VG IDE saves dirty work, spawns the welcome shell, and quits the current editor instance. Welcome resolver checks `$VG_WELCOME_DIR`, sibling/bundled/parent of current project, the Godot binary's own directory (walks out of `Godot.app/Contents/MacOS/` on macOS), `/opt/visual_gasic/`, `~/.local/share/visual_gasic/`, and `~/Documents/VisualGasic/`.
- **Loading splash with handoff marker** — when launching a project from the welcome shell, a modal "Loading <project>…" splash sits on top while Godot inits. The IDE plugin clears `~/.config/visual_gasic/launching.flag` from a deferred call in `_enter_tree`; the shell polls (max 20s) and adds a 0.4s tail-wait so the splash matches actual IDE-ready time, not a fixed timer. Stale flags older than 60s are swept on next welcome startup.
- **Cross-project recent list** — IDE plugin records every opened VG project into a per-platform ini (`~/.config/visual_gasic/recent_projects.cfg` on Linux, `~/Library/Application Support/VisualGasic/recent_projects.cfg` on macOS, `%APPDATA%\VisualGasic\recent_projects.cfg` on Windows). Move-to-front, capped at 16, used by both the launcher and the welcome shell.
- **`scripts/sync_addon.sh`** — bash helper that rsyncs the canonical addon into one or more project dirs (`--all` walks the recent list). Dereferences the canonical `bin/` symlink so each target gets real `.so`/`.dll` binaries; refuses to sync into the repo itself to avoid clobbering the symlink.

### 🛠 Fixes
- **`_create_new_vg_project`** — new VG projects now copy the canonical addon (resolved via `$VG_ADDON_SOURCE` → source-tree sibling → `/opt` → `~/.local/share`) instead of the running project's possibly-stale local copy. Lesson learned the hard way after several "stale addon" debugging rounds.
- **`vg_ai_help.gd` API Keys dialog** — fixed the dialog auto-stretching to fill tall viewports. `popup_centered(size)` treats its arg as a *minimum* and `Window.wrap_controls=true` (default) auto-grows, so the dialog now sets `wrap_controls=false` and pins `size`/`min_size`/`max_size` to (520, 360).
- **`vg_ai_repair.gd`** — annotated `_extract_json_blob` and `_apply_patch_to_lines` callsites with `: Variant` to silence walrus-on-Variant parse errors that were spamming the editor log on every project load.
- **`addons/visual_gasic/plugins/_disabled.gdsfx/`** — renamed from `plugins/gdsfx/` and added an empty `.gdignore` (the only reliable way to hide a directory from Godot's GDScript class scanner). Suppresses parse-error spam from the never-shipped `gdsfx_dsp.gd` / `gdsfx_pd.gd` / `gdsfx_pd_modules.gd` dependencies.

### 🌿 New — Narcea AI persona (stepping-stone agent mode)
- **`🌿 Narcea` persona** ([`addons/visual_gasic/vg_ai_narcea.gd`](addons/visual_gasic/vg_ai_narcea.gd)) — VG-aware pair programmer that injects an active-context probe (current panel, open file), a baked-in VG knowledge block (control catalog, AGCK actor types, Working Nodes triggers, common gotchas, idioms), and the local tutorial index into the system prompt. Selectable from the AI Pair persona dropdown alongside Bob / Skippy / Orac / HAL.
- **🔨 Build form button** — when Narcea's reply contains a fenced ` ```vg-form-spec ``` ` JSON block, the toolbar button enables and one click materialises the form in the Form Designer via the bound `new_form` / `add_control` / `set_control_property` C++ API. Whitelist-validated control types / property keys keep the model from asking for arbitrary script execution. New module: [`addons/visual_gasic/vg_ai_form_spec.gd`](addons/visual_gasic/vg_ai_form_spec.gd).
- **TTS now skips code** — fenced code blocks are summarised ("see the panel for N lines of VG code") instead of read aloud line-by-line; markdown emphasis, inline backticks and URLs are stripped before speech. New module: [`addons/visual_gasic/vg_ai_speech_filter.gd`](addons/visual_gasic/vg_ai_speech_filter.gd).
- **⏹ Stop-Speaking button** — `vg_ai_voice.stop_speaking()` now also `OS.kill`s the system-TTS subprocess (espeak / SAPI), captured at `OS.create_process` time and emits `speech_finished` so the panel state stays consistent. Toolbar button auto-shows on `speech_started` and hides on `speech_finished`.
- **Form spec — containers, events, parent-relative coords** — `vg_ai_form_spec.gd` now whitelists `Frame` / `GroupBox` containers plus `backcolor` / `forecolor` / `borderstyle` / `appearance` / `parent` properties; resolves logical `parent: "<name>"` references to absolute pixel offsets (FormDesigner is flat-layout); and exposes `generate_event_stubs(spec, existing_source)` which emits `Sub <name>_<event>()` stubs based on per-control `events: [...]` arrays or a spec-level `auto_events: true` flag, idempotent against any source already containing the sub.
- **🤖 Make this button** — one-click chain in the AI panel: extract the spec → apply to designer → save the form (`save_form_as` if untitled, else `save_form`) → write event stubs into the matching `.vg` file → rescan filesystem → open the script in the embedded code editor. Stays opt-in (button click only); disabled until a valid `vg-form-spec` block is in the latest reply.
- **Persona-aware speech rate** — `vg_ai_voice.tts_speed_scale` is now plumbed through every TTS backend: OpenAI `speed` (clamped 0.25..4.0), Piper `--length-scale` (inverse), espeak `-s WPM` (175 × scale), macOS `say -r WPM`, SAPI `$s.Rate` (log2-mapped to ±10). Personas drive it from a new `speech_speed` field — Skippy 1.18× (manic), Orac 0.92×, HAL 0.85× (serene/ominous), everyone else 1.0×.

### 🤖 New — Narcea v2: chat-to-project agent mode
- **Safe-write chokepoint with audit log** — every AI-driven file write goes through [`addons/visual_gasic/vg_ai_safe_write.gd`](addons/visual_gasic/vg_ai_safe_write.gd). Refuses path traversal (`..`), out-of-root targets, and a forbidden-glob list (`*/.git/*`, `*/.godot/*`, `*/addons/visual_gasic/*`, `*/vg_ai_audit.log`). Auto-mkdirs parents, ring-tails an audit log at `user://vg_ai_audit.log` (`<ts>\t<action>\t<size>\t<path>\t<note>`).
- **📝 Make-code button + `vg-code-spec` schema** — Narcea can emit a fenced ` ```vg-code-spec ``` ` JSON block with multiple `{path, source}` entries. One click extracts → plans → diff-previews → applies. `.vg` files are run through `VGLinter` first; severity = error blocks apply when `strict` is set. New module: [`addons/visual_gasic/vg_ai_code_spec.gd`](addons/visual_gasic/vg_ai_code_spec.gd).
- **🆕 Make-project button + `vg-project-spec` schema** — Narcea can scaffold a whole sub-project (forms + loose code + manifest) sandboxed under `res://ai_projects/<project_name>/`. Steps: write `project.json` manifest → forms via designer + auto-generated event stubs → loose files via the code-spec applier (rebound to project root) → `README.md` → resolve main scene → rescan FS. New module: [`addons/visual_gasic/vg_ai_project_spec.gd`](addons/visual_gasic/vg_ai_project_spec.gd).
- **▶ Run / ⏹ Stop run buttons** — after Make-this / Make-project, the user can spawn the scene under the same Godot binary via `OS.execute_with_pipe`. Stdout / stderr stream back into the chat panel as system messages (grey / red). New module: [`addons/visual_gasic/vg_ai_run_session.gd`](addons/visual_gasic/vg_ai_run_session.gd).
- **Diff-preview dialog** — every Make-code / Make-project apply first opens [`addons/visual_gasic/vg_ai_diff_dialog.gd`](addons/visual_gasic/vg_ai_diff_dialog.gd) showing per-file create / update / unchanged / blocked actions with a colored line diff and lint summary. Apply button is disabled when nothing is applicable.
- **Run-output context probe** — Narcea's active-context block now includes the last 20 lines of stdout/stderr from the most recent run, so the next chat turn naturally closes the agent loop ("the script crashed at line 12 — fix it").
- **Headless smoke harness** — [`scripts/smoke_ai_specs.gd`](scripts/smoke_ai_specs.gd) exercises safe_writer rejection rules, code-spec round-trip, project-spec scaffolding, and VGLinter findings. Runs under `--headless --script` for CI.

## [5.1.0-rc.1] - 2026-04-29

### 🛠️ Fixed — Release pipeline
- `SConstruct::_mirror_to_addons` is now idempotent. The post-build action used to call `os.makedirs("addons/visual_gasic/bin", exist_ok=True)` directly, which raised `FileExistsError` on fresh CI clones because that path is committed as a *symlink* (`→ ../../bin`) but the target directory is gitignored and absent. The action now resolves the symlink first, materializes the real destination directory, and falls back to replacing dangling symlinks. This was the universal cause of every release CI failure since `v4.4.0-rc6`.

### 🚌 New — VGAssetBus / VGContextBroker / VGPluginRegistry
- Process-wide signal bus (`VGAssetBus`) for asset lifecycle events: `asset_opened`, `asset_modified`, `asset_saved`, `asset_deleted`, `asset_invalidated`, `asset_renamed(old, new, by)`. Editors and plugins subscribe instead of polling or hard-coding cross-references.
- `VGContextBroker` tracks the IDE's current asset / project / object / selection and emits `context_changed(kind, value)` with deduplication on equal values.
- `VGPluginRegistry` routes "open this asset" requests to the right editor by capability namespace (`asset_editor.code`, `asset_editor.scene.2d`, `asset_editor.scene.3d`, `asset_editor.binary`, `game_builder.*`, etc.), tie-broken by priority desc / plugin_id asc.
- File browser auto-refreshes on `asset_saved` / `asset_deleted` / `asset_renamed` / `asset_invalidated`.
- See [`addons/visual_gasic/PLUGIN_SDK.md`](addons/visual_gasic/PLUGIN_SDK.md) for the plugin author contract.

### 🧰 New — Default Editors UI
- **⚙ Plugin Settings** dialog now has two tabs: *Installed Plugins* (existing) and *Default Editors* (new). Each capability gets an OptionButton listing every registered provider; users can pin a non-default editor for any asset kind. Persisted under `ProjectSettings.vg/plugin_registry/defaults/*`.

### ⌨️ New — Command Palette MRU
- `Ctrl+P` with an empty query now lists up to 10 recently-opened files (🕘 prefix) at the top, separator, then the rest of the project. Recent list is captured by listening to `VGAssetBus.asset_opened` and persists across sessions in `user://vg_recent_files.cfg`.

### 🔭 New — External File Watcher & Reload Prompt
- `VGAssetWatcher` polls tracked files (those opened via the bus) every 2 s and emits `asset_invalidated` when a file's mtime changes outside the IDE.
- `VGExternalChangePrompt` listens for that signal and shows a non-modal "File Changed Externally — Reload from disk?" dialog. 5-second per-path cooldown suppresses bursty external writes.

### ✏️ New — Cross-Asset Reference Rewriter
- `VGRefRewriter` listens for `asset_renamed` and rewrites `res://` references in `.vg` / `.gd` / `.tscn` / `.tres` / `.vgsprite` / `.agck` / `.json` / `.cfg` / `.ini` / `.txt` / `.md` files across the project. Boundary-aware so `res://foo` doesn't corrupt `res://foo_bar`.

### 🎮 New — AGCK Game-Type Templates
- AGCK Build view template picker grew from 3 to 8 entries: **Top-Down RPG**, **Side Shmup**, **Match-3**, **Asteroids**, **Endless Runner** (in addition to Platformer, Space Shooter, Maze).

### 📜 New — Project Menu Gating
- *Add Form...*, *Add Module...*, *Components...* in the VB6-style Project menu are greyed out when Form Designer is disabled (they had no effect without it). *Project Properties...* remains available.

### 🧪 New — Plugin Capability Lint & Routing Tests
- [`scripts/lint_plugin_capabilities.py`](scripts/lint_plugin_capabilities.py) — CI-friendly Python 3 linter for `[capabilities]` blocks. `--strict` flag promotes warnings to errors.
- [`tests/test_vg_routing.gd`](tests/test_vg_routing.gd) — 12 routing tests for bus / broker / registry, runnable via [`scripts/run_routing_tests.sh`](scripts/run_routing_tests.sh).
- [`.github/workflows/plugin-lint.yml`](.github/workflows/plugin-lint.yml) — lightweight CI job runs both on every push/PR touching `addons/visual_gasic/`.

### 🔌 Migrated — Plugin Capability Schemas
- `vg3d`, `web_publish`, `working_nodes` plugin.cfg files now declare `[capabilities]` blocks. Lint passes with `--strict` cleanly across all 6 first-party plugins.

### 🐛 Fixed — AGCK polish
- **Deadly tile pass-through** (`fb3164d`): block_id 3 (spike) now joins 5/6 in the pass-through list so the outer 32×32 collision wall no longer blocks the player from reaching the inner DeadlyArea trigger. Spikes now actually kill instead of acting as solid walls.
- **Tightened deadly hitbox** (`6f6357c`): `DeadlyShape` reduced to 26×24 with `position = (0, +4)` so the trigger matches the visible spike pixels and doesn't fire on empty space at the top of the cell.
- **Settings persistence** (`48aba68`): `agck_game_settings.gd::set_data()` now rebuilds the UI after merging the dict so Fullscreen / Show FPS toggles survive save → reload (was updating the dict but leaving stale widgets bound).
- **Black-void layout fix** (`0e3baf6`): `CenterStack` MarginContainer is now hidden in `_on_vg_plugin_activated()` and re-shown in `_show_form_view()`, preventing the HSplit from allocating half the canvas to an empty parent on AGCK startup.

## [5.1.0-Beta1] - 2026-04-24

### 🎛️ New — Unified ▶ Play Menu
- Single `▶ Play` MenuButton in the top toolbar replaces the legacy `Preview` / `Preview (Debug)` / `Build` / `Run` button row.
- Visible in every view (Code, Form, 2D, 3D, Sprite, plugin views).
- Menu items: **Run Current Scene** (F5), **Run Main Scene** (Ctrl+F5), **Preview Current Form** (Shift+F5), **Preview (Debug)** (Ctrl+Shift+F5), **Build Project**.
- New plugin API: `form_preview_toolbar.add_menu_item(label, callback) -> int` / `remove_menu_item(id)`. Plugin action IDs are always ≥ 1000.

### ⌨️ New — F5 Dispatch Protocol for Plugins
- Plugins can optionally implement `on_play_shortcut(ctrl: bool, shift: bool) -> bool`. When their view is active, the toolbar offers them the F5 / Ctrl+F5 / Shift+F5 event first and falls through to Run Current Scene on `false`.
- Working Nodes consumes F5 (run graph) and Shift+F5 (run graph headless); Ctrl+F5 falls through to the host.

### 🧩 New — Form Designer as a Toggleable Plugin
- Form Designer appears as a row in the **⚙ Plugin Settings** dialog alongside community plugins.
- Toggle is persisted at `ProjectSettings.vg/form_designer_enabled`.
- When disabled: the plugin-strip "🎨 Form Designer" button, the legacy top-row `▣ Form` mode button, the alignment toolbar, the color palette, the `Indexes` toggle, and the `▶ Live` toggle are all hidden.
- When disabled the IDE skips auto-opening the first form on startup and launches in the code editor.
- Bootstrap installer sets `vg/default_mode = "code"` for new projects.

### 📥 New — Bootstrap Installer (Linux MVP)
- `install.sh` now downloads Godot 4.6.1, installs the VisualGasic addon globally, and creates a `~/.local/bin/vg` launcher. One-line curl-to-bash install.

### 🖱️ Fixed — Draggable Left-Sidebar Splitters (2D & 3D Editors)
- The VSplitContainer between the Object list and Scene Tree in `vg_2d_editor.gd` / `vg_3d_editor.gd` is now actually draggable. Child `ItemList` / `Tree` minimums are zeroed; the split container itself sets the combined minimum (520 px).

### 🐛 Fixed — IDE UX
- Right-side panel (`RightPanelSplit`) no longer disappears after switching back from a plugin view (Working Nodes / AGCK) to Code view. `_show_code_view()`, `_show_2d_view()`, `_show_3d_view()`, `_show_sprite_view()` now all restore panel visibility on both switch-in and same-view early-returns.
- `form_preview_toolbar._build_ui()` is idempotent — no more duplicate ▶ Play buttons when a plugin registers a menu item before `_ready()` fires.
- Form-specific toolbar widgets (alignment tools, color palette, `Indexes`, `▶ Live`) are hidden in Code/3D/2D/Sprite views (they did nothing in those modes but still took toolbar space).

### 🔌 Fixed — Working Nodes Plugin
- Typed scroll container + single-line Sub signatures in generated bytecode (fixes plugin load regression).
- `wn_runtime.vg` and visible scene generation so graphs can actually run.
- Run Graph is now surfaced through the unified Play menu + F5 instead of a plugin-local button.

### 🔧 Fixed — Profiler & AI Help
- Profiler panel wired to the C++ `VisualGasicProfiler` singleton via static class methods (previously the button did nothing).
- AI Help: speed options exposed, first-run model picker, general UI cleanup.

### 🛠️ Build & Housekeeping
- `build_release.sh` now copies the full `addons/visual_gasic/plugins/` tree into staging and strips nested demo/example `bin/` directories to keep zip size sane.
- Duplicated real-directory addon copies in `demos/`, `examples/`, `game_projects/`, `test_proj/` replaced with symlinks and a CI drift guard (`scripts/sync_addons.sh check`).
- Package registry: added a TODO noting the default registry URL is unwired.

## [5.0.1-beta5] - 2026-04-22

### 🆕 New — Working Nodes Visual Scripting Plugin
- Node-graph visual scripting editor shipped as a first-class VG plugin.
- Wire-based graph editor with ports, curved bezier connections, and zoom / pan / snap.
- Two-row toolbar (File / Edit / View / Run on row 1, node palette on row 2) that no longer overflows at narrow widths.
- **📖 Help** button opens the Working Nodes manual in the system viewer.
- Standard File dialog integration (Open / Save / Save As).

### ✨ Improved — Code Editor Save Semantics
- **Ctrl+S** in the Form Designer now always saves the active `.vg` code buffer (previously only the `.tscn` was saved).
- **Run Project** flushes the in-memory buffer to disk so the game runs the latest code — but does **not** clear the dirty indicator. Only Ctrl+S / File → Save formally saves.

### 🎛️ Fixed — IDE Layout (Form / 2D / 3D / Sprite views)
- New `CenterStack` `MarginContainer` wraps all center editors. Previously, six direct children were stacked under an `HSplitContainer`, which only lays out its first two children — causing 2D / 3D / Sprite views to render blank.
- Right-side panels (Project Explorer + Properties) remain visible when switching to 2D, 3D, or Sprite view. They no longer force-dock and hide Godot's own editors.
- `undock_vg_panels()` always runs its cleanup step (previously early-returned when the IDE was already built).

### 🕹️ Fixed — AGCK Game Engine
- **Level swapping** properly removes the old level's nodes from the scene tree before adding the new one. Fixes:
  - Level 2 blank screen (stale `Camera2D.current` from the previous level).
  - Lives counter going negative after death (stale level nodes still parented).
  - `NextLevel`, `GoToLevel`, and `LoseLife` (Case 0) codegen all emit the new pattern.
- **Hero invincibility blink** is now time-based (10 Hz) instead of per-physics-frame, so the sprite actually appears to flash during invincibility.

### 🧩 Fixed — FormDesigner C++
- Removed per-frame `"FormDesigner: Set preview texture for..."` debug `print()` that spammed the Output panel at ~15 fps.
- Live preview manager is frozen when the main screen is not the Form Designer.

### 📦 Fixed — Sample Project
- `game_projects/platformer_2d` — missing `vg_2d_editor.gd` / `vg_3d_editor.gd` in the shipped addon folder.

## [5.0.1-beta4] - 2026-04-19

### 🎨 Sprite Editor Enhancements

#### Added — VG Sprite Editor
- **Magic Wand tool** (shortcut `W`) — Flood-selects contiguous pixels of matching color with 5% per-channel tolerance, creating a bounding-box selection. Completes the Aseprite-like selection toolkit alongside rectangular Select and Move.
- **Import Palette** — Load palettes from `.gpl` (GIMP), `.hex` (Lospec/Aseprite), `.pal` (Paint.NET/JASC), and `.txt` files via file dialog. Parsed colors replace the active palette grid.
- **Export Palette** — Save the current palette swatches as a GIMP `.gpl` file for use in external editors.

#### Added — AGCK Actor Editor
- **FPS control SpinBox** (1–30, default 8) — Adjustable animation preview frame rate in the frame toolbar. Previously hardcoded at ~6.7 FPS (150ms). Updates the preview timer in real-time.
- **Frame clipboard** (previous beta) — Copy/Paste buttons for frame-level clipboard operations, replacing the old inline-only Duplicate behavior.

---

## [5.0.1-beta3] - 2026-04-18

### 🎮 VG 2D Editor & AGCK Fixes

#### Fixed — VG 2D Scene Editor
- **Viewport positioning** — Scene now opens at 100% zoom with origin in the upper-left, matching Godot's 2D editor default view. Previously the viewport was mispositioned due to deferred layout timing.
- **Viewport deferred layout** — `_fit_scene_in_view()` now defers via `call_deferred` when the SubViewport hasn't been laid out yet, preventing incorrect camera positioning on initial load.
- **Array type mismatch** — Fixed `Array` vs `Array[Node]` type mismatch in `_fit_scene_in_view()` that caused `_collect_pickable_nodes()` to silently fail in Godot 4.x, resulting in no nodes being collected for bounds computation.

#### Fixed — AGCK Plugin Activation
- **Single-click AGCK button** — AGCK plugin now activates on the first click. Previously required two clicks because `_auto_open_built_scene()` called `_on_2d_view_pressed()` during activation, which immediately switched away from the AGCK view and called `deactivate_all()`, leaving the plugin manager in a stale state.
- **Silent scene pre-load** — `_auto_open_built_scene()` now loads Main.tscn into the 2D editor in the background without switching views, so the scene is ready when the user manually navigates to the 2D editor.

#### Fixed — AGCK Handler Naming (VB6 Convention)
- **Standardized all AGCK handlers** to VB6 `ObjectName_EventName` convention:
  - `_on_hitbox_body_entered` → `Hitbox_BodyEntered`
  - `_on_hitbox_area_entered` → `Hitbox_AreaEntered`
  - `_on_teleport_touched` → `Teleport_BodyEntered`
  - `_on_deadly_touched` → `Deadly_BodyEntered`
  - `_on_switch_touched` → `Switch_BodyEntered`
  - `OnLevelComplete` → `LevelComplete`
  - `OnSplashDone` → `SplashTimer_Timeout`
  - Button handlers: `PlayBtn_Click`, `ExitBtn_Click`, `RestartBtn_Click`
- **Connect() regex scanner** — Double-click code navigation now scans `.vg` files for `Connect("signal", "HandlerName")` patterns to resolve handler locations.

---

## [5.0.1-beta2] - 2026-04-13

### 🔧 AGCK Polish & Web Publish & Major New Features

#### Added — Publish to Web (Flash-Successor Pipeline)
- **`agck_web_export.gd`** — Complete HTML5 publish backend (~500 lines) with Flash-era features:
  - **4 preloader styles**: Bar, Spinner, Retro, None (Flash's iconic loading screens)
  - **4 scale modes**: Fit (showAll), Fill (noBorder), Stretch (exactFit), Pixel-Perfect
  - **Fullscreen toggle**: F11 key + button (Flash's `Stage.displayState`)
  - **Custom right-click menu**: Replaces browser default (Flash's `ContextMenu` class)
  - **Quality control**: Low/Medium/High/Best (Flash's `_quality` property)
  - **Background color**: Configurable (Flash's `bgcolor` embed parameter)
  - **Embed code generator**: Modern `<iframe>` replacing Flash's `<object>/<embed>`
  - **Portal page generator**: Newgrounds-style game page with embed code display
  - **Splash screen**: VisualGasic branding with auto-hide
- **Build tab web options panel** — Appears when target is "Web": preloader, quality, scale, colors, toggles, description field
- **🌐 PUBLISH TO WEB button** — One-click pipeline: HTML wrapper → portal page → embed code

#### Added — Multi-Provider AI Help
- **Cloud AI providers**: OpenAI (GPT-4o/GPT-4o-mini), Anthropic Claude (Sonnet/Haiku), Google Gemini (Flash/Pro) alongside existing local Ollama
- **Provider selector dropdown** in AI Help toolbar — switch between Local (Ollama) and Cloud providers
- **API key settings dialog** (⚙️ button) — per-provider API key storage via `user://vg_ai_keys.cfg`
- **Streaming responses** for all cloud providers (SSE/chunked for OpenAI/Gemini, SSE for Claude)
- **Auto-detection**: Falls back to Ollama if no cloud API key is configured
- **Same VisualGasic system prompt** used across all providers for consistent responses

#### Added — Live Animation for Custom Controls
- **Live SubViewport rendering** — @tool custom controls now animate in real-time in the Form Designer
- **Per-instance SubViewport** — Each custom control gets its own viewport running the `.tscn` scene
- **`_process()` runs live** — Wobble, pulse, glow, particle, and shader animations visible at design time
- **Freeze toggle** — "❄ Freeze Previews" button to switch back to static snapshots for performance
- **15 FPS throttle** — Live viewports throttle when Form Designer tab is not focused

#### Added — WebSocket Controls
- **`VGWebSocketClient`** — Connect to WebSocket servers, send/receive text and binary messages
- **`VGWebSocketServer`** — Accept incoming WebSocket connections with client management
- **`VGWebSocketLobby`** — Game lobby with room creation, join/leave, ready states, player listing
- **`VGWebSocketChat`** — Chat control with message history, user list, system messages

#### Fixed — AGCK Level Editor
- **Tile shader Save button** — Save no longer closes the edit popup (was behaving identically to Cancel)
- **Shader change persistence** — Shader FX dropdown and parameter slider changes now call `_mark_dirty()` and emit `level_changed`

#### Improved — AGCK Settings Panel
- **Color picker** — BG Color field now uses a `ColorPickerButton` with live color wheel
- **Resolution presets** — Width/Height replaced with a preset dropdown
- **Slider value readouts** — All sliders now display their current value with appropriate suffixes

---

## [5.0.1-beta] - 2026-04-09

### 🚀 v5.0.1 Beta — Plugin System, AGCK, & Major Version Bump

Skipping the 4.x stable release — too many major features have landed since RC7 to call this a point release. VisualGasic jumps to **v5.0.1 Beta** with a full plugin system, the AGCK game construction kit, and comprehensive documentation.

#### Added — Plugin System
- **`vg_plugin_base.gd`** — RefCounted base class for VG IDE plugins with lifecycle signals, toolbar integration, and view management
- **`vg_plugin_manager.gd`** — Plugin discovery from `plugins/<name>/plugin.cfg`, activation/deactivation lifecycle, automatic toolbar button placement, mutual-exclusion view switching
- **Plugin architecture** — INI-based plugin.cfg, automatic Control view creation, signal-driven activation/deactivation

#### Added — AGCK (Adventure Game Construction Kit)
- **Game Settings Editor** — Game identity, world physics (gravity, friction, thrust, terminal velocity), screen behavior (wrap/bounce/block), player settings, display, FX channels
- **Actor Editor** — 5 actor types (Player, Enemy, Bullet, Pickup, Scenery), movement states, collision modes, death/rebirth, awards, entrance, AI, auto-shoot, sound effects, FX scripts
- **Sound Editor** — 4-voice polyphonic sound designer with bar graph note editor, 4 waveforms (Square, Sawtooth, Triangle, Noise), filter, tempo/transport controls
- **Level Editor** — 24×20 tile grid with 7 block types, painting tools, actor placement, material properties, sentry paths, level management
- **Game Builder** — Build targets (C64/Modern/HTML5), splash screen config, simulated build progress

#### Added — Documentation
- **Plugin System Developer Guide** (`docs/guides/PLUGIN_SYSTEM.md`) — Architecture, API reference, step-by-step plugin creation, AGCK example
- **AGCK User Manual** (`docs/manual/AGCK_MANUAL.md`) — All 5 sub-editors documented, saving/loading, C64 comparison table, keyboard reference
- **Documentation Index** updated with plugin system and AGCK entries

#### Changed — Version Bump
- Skipped v4.4.0 stable and all 4.x releases — jumped directly to v5.0.1-beta
- Updated VERSION, all 63 plugin.cfg files, README, ROADMAP, DOCS, package README

## [4.4.0-rc7] - 2026-04-07

### 🎮 Release Candidate 7 — 3D Game Self-Sufficiency

Six-phase implementation enabling full 3D game development without leaving the VisualGasic IDE. Import models, edit materials, set up environments, configure input, animate objects, and export — all from within VG.

#### Added — Phase 1: Asset Import System (`vg_3d_editor.gd`)
- **📦 Import toolbar button** — one-click model import from the 3D editor toolbar
- **FileDialog** for `.glb`, `.gltf`, `.obj`, `.fbx` model files
- Copies source files + sidecars (`.bin`, `.mtl`) to `res://models/`
- Triggers `EditorFileSystem.scan()` and awaits reimport before instantiation
- Instantiates imported model at the current orbit target position
- **Context menu** — "📦 Import Model..." item (id 20) in right-click menu

#### Added — Phase 2: 3D Properties Inspector (`simple_inspector.gd`)
- **7 new property categories**: 3D Position, 3D Rotation, 3D Scale, 3D Appearance, 3D Material, 3D Light, 3D Camera, 3D Physics
- **Node3D transform** — X/Y/Z position, rotation (degrees), and scale with live editing
- **MeshInstance3D** — CastShadow mode, Transparency, GI Mode, surface material properties
- **StandardMaterial3D** — Albedo Color, Metallic, Roughness, Emission (with unique material duplication)
- **CSGShape3D** — Material color/metallic/roughness for CSG primitives
- **Light3D** — Color, Energy, Range (Omni/Spot), Shadow toggle
- **Camera3D** — FOV, Near/Far clip planes, Current camera toggle
- **RigidBody3D** — Mass, Gravity Scale, Friction, Bounce (via PhysicsMaterial)
- **35 property descriptions** added to `PROPERTY_DESCRIPTIONS` dictionary
- **`_apply_mesh_material_prop()`** helper — ensures unique material before modifying shared resources

#### Added — Phase 3: Input Map Editor (`vg_input_map_editor.gd`)
- **New standalone dialog** — VB6-themed AcceptDialog accessible from Tools → Input Map Editor
- **Action management** — Add/remove input actions, reads existing `input/*` ProjectSettings (skips `ui_*` built-ins)
- **Key capture** — Press-a-key dialog for keyboard binding (InputEventKey)
- **Mouse binding popup** — Left/Right/Middle/Wheel Up/Wheel Down (InputEventMouseButton)
- **Gamepad binding popup** — A/B/X/Y/LB/RB/LT/RT/DPad directions (InputEventJoypadButton)
- **Deadzone slider** — Per-action deadzone configuration (0.0–1.0)
- **Auto-save** — All changes immediately saved to `ProjectSettings`

#### Added — Phase 4: Environment Presets (`vg_3d_editor.gd`)
- **🌍 Env toolbar MenuButton** — one-click environment setup from the 3D editor
- **4 presets**: Outdoor Day, Outdoor Night, Indoor, Space
- Each preset creates `WorldEnvironment` + `DirectionalLight3D` with full configuration:
  - ProceduralSkyMaterial with per-preset sky/ground colors
  - Ambient light source and energy
  - Tonemap mode (ACES/Filmic)
  - Post-processing (SSAO, Glow with intensity)
  - Sun direction, color, and energy
- **Remove Environment** option to clean up preset nodes
- **Context menu** — "🌍 Add Environment..." item (id 21)

#### Added — Phase 5: Animation Timeline (`vg_animation_editor.gd`)
- **New standalone dialog** — VB6-themed AcceptDialog accessible from Tools → Animation Editor
- **AnimationPlayer management** — finds or creates AnimationPlayer on target node
- **Animation list** — Create, delete, and select animations (skips RESET)
- **Track viewer** — TreeView showing all tracks with type and key count
- **Playback controls** — Play/Pause/Stop with speed control and loop toggle
- **Timeline slider** — Seek to any point in the animation with time display
- **Keyframe insertion** — Adds Position + Rotation + Scale tracks at current time
- **Import from .glb** — FileDialog to import animations from 3D model files, copies and extracts AnimationPlayer library

#### Added — Phase 6: Make EXE (`visual_gasic_plugin.gd`)
- **File → Make EXE...** menu item — one-click game export
- **Platform-aware FileDialog** — `.exe` on Windows, `.x86_64` on Linux, `.app` on macOS
- Auto-creates `export_presets.cfg` with correct platform preset if missing
- Invokes Godot's `--export-release` with the matching preset name
- Opens the output folder on successful export
- **Error reporting** — logs success/failure to the Output panel

#### Fixed — Formatter Word Boundary (`vg_formatter.gd`, `visual_gasic_language.cpp`)
- **`Do` keyword** no longer matches function names like `DoTurnOn`, `DoAttack` — added word boundary check after `begins_with()` match
- **`Try`, `Else`, `ElseIf`** keywords tightened with same boundary pattern in C++ formatter
- Prevents escalating indentation when procedures start with reserved-word prefixes

#### Fixed — Environment Enum Names (`vg_3d_editor.gd`)
- `TONE_MAP_ACES` → `TONE_MAPPER_ACES`, `TONE_MAP_FILMIC` → `TONE_MAPPER_FILMIC` — corrected for Godot 4.6 API

## [4.4.0-rc6] - 2026-03-30

### 🧹 Release Candidate 6 — Repository Cleanup

Massive repository cleanup: removed 150+ stale files, old release notes, backup directories, and archive cruft. Package directory now ships all 3 platform binaries (Linux, Windows, macOS), 69 documentation files, and install scripts.

#### Removed — 32 Old Release Notes
- Removed all `RELEASE_NOTES_v2.x` through `v4.4.0-rc4` — history lives in CHANGELOG.md and git tags
- Only the current `RELEASE_NOTES_v4.4.0-rc5.md` remains in-tree

#### Removed — Backup & Archive Directories
- `Calculator-vb6-main/` — External VB6 project (not part of VisualGasic)
- `vbnet_examples_backup/`, `vbnet_samples_backup/` — Old code backups
- `docs/archive/` — 31 stale status reports, gap analyses, and implementation summaries
- `community_support/`, `video_tutorials/` — Placeholder directories
- `perf_reports/`, `.rmv/` — Build logs and irrelevant config

#### Removed — Stale Root Files
- `PROJECT_STATUS.md`, `TEST_COVERAGE.md`, `COMMUNITY_HUB.md` — Outdated status docs
- `UPLOAD_TO_GITHUB.sh`, `Makefile.tests`, `performance_results.json` — One-off scripts and local data
- `VisualGasic` binary — Should never have been tracked
- Duplicate `PROJECT_STATUS.md` / `ROADMAP.md` in `package/` and `examples/`

#### Added — Complete Package Distribution
- **package/bin/** — All 9 binaries: Linux (.so), Windows (.dll), macOS (.framework) × editor/debug/release
- **package/docs/** — 69 documentation files: getting started, manual, guides, reference, tutorials
- **package/** — Install scripts: `install.sh` (Linux), `install.ps1` (Windows), `install.py` (cross-platform)

#### Updated — .gitignore
- Added entries for all removed directories to prevent re-introduction

## [4.4.0-rc5] - 2026-03-30

### 🏗️ Release Candidate 5 — Debugger Stability & Built-in Constants

Major debugger reliability pass: built-in constants separation, bytecode locals exposure, Break-when-idle, auto-connect, and Variables panel fixes. Plus a 17-file documentation overhaul.

#### Added — Built-in Constants Separation
- **`builtin_constants` Dictionary** — ~109 built-in constants (`vbRed`, `vbCrLf`, `KEY_SPACE`, `True`, `False`, etc.) moved out of `variables` into a dedicated protected Dictionary
- **`is_builtin_constant()` accessor** — Clean API for checking constant status
- Constants no longer appear in the debugger Variables panel, reducing clutter

#### Added — Documentation Overhaul
- **17 documentation files** updated across getting started guides, manual pages, tutorials, and API reference
- **`nodes_and_scenes.md`** — Expanded from 44 lines to a comprehensive guide with VB6 forms, property aliases, Me keyword, and complete working examples

#### Fixed — Built-in Constants Not Resolved in Bytecode VM
- Added `builtin_constants` fallback to **13 code paths** in the bytecode VM
- All VB6 color constants, key constants, and string constants now resolve correctly after the separation

#### Fixed — Debugger Locals Invisible in Variables Panel
- Added `debug_bc_locals` / `debug_bc_chunk` pointer members to instance
- Four debugger query functions now include bytecode locals

#### Fixed — Break Button Not Working When Idle
- **`idle_break()` C++ static method** — Checks break-request flag from GDScript
- **`_process()` in `vg_debug_handler.gd`** — Polls `vg_idle_break()` every frame
- **Auto-refresh** in `immediate_window.gd` — Retries connection to running game on launch

#### Fixed — Variables Panel Empty + Dark Filter Text
- `get_instance_variables()` now merges `get_debug_locals()` into globals
- Filter LineEdit has explicit `font_color` and `selection_color` overrides

## [4.4.0-rc4] - 2026-03-29

### 🏗️ Release Candidate 4 — VB6 Property System v2

Comprehensive property system upgrade: VB6-style formatting, StringName hashing, 7 new runtime properties, property change events, IntelliSense completions for 62+ properties, and Watch Window VB6 property evaluation.

#### Added — VB6-Style Output Formatting
- **`_vb6_format_variant()`** — Immediate Window and REPL output now uses VB6 conventions:
  - Booleans display as `True` / `False` (not `true` / `false`)
  - Whole-number floats display without decimals: `100` not `100.0`
  - Integers never show `.0` suffix

#### Added — IntelliSense Property Completions
- **62+ VB6 property completions** — Typing a dot after any control now suggests all VB6 property aliases (Name, Caption, Text, Visible, Enabled, Left, Top, Width, Height, BackColor, ForeColor, FontSize, FontBold, FontItalic, FontName, FontUnderline, FontStrikethrough, Tag, ToolTipText, TabStop, TabIndex, MousePointer, BorderStyle, Opacity, ZOrder, Rotation, hWnd, BackStyle, Appearance, Parent, Container, Index, DragMode, and more)
- **Type-specific properties** — LineEdit shows MaxLength/PasswordChar/SelStart, Timer shows Interval/OneShot/Autostart, Button shows Style/Flat/ClipText/Icon, etc.
- **Common methods** — Show, Hide, Move, SetFocus, Refresh appear in completions

#### Added — 7 New Runtime Properties
- `BackStyle` — 0 = Transparent, 1 = Opaque (meta `vg_backstyle`; adjusts `self_modulate` alpha)
- `Appearance` — 0 = Flat, 1 = 3D (meta `vg_appearance`)
- `TabIndex` — Tab order index (meta `vg_tabindex`)
- `Parent` — Returns the parent node (read-only)
- `Container` — Alias for Parent (read-only)
- `Index` — Control array index (meta `vg_index`)
- `DragMode` — 0 = Manual, 1 = Automatic (meta `vg_dragmode`)
- All 7 properties work in both AST interpreter and bytecode VM paths

#### Added — StringName HashMap for Property Dispatch
- **`_vb6_prop_id()` HashMap** — O(1) property name lookup using a static `HashMap<StringName, int>` with all 62 property identifiers
- **Fast-reject** — Unknown property names are rejected at the top of both `_vb6_read_property()` and `_vb6_write_property()` before any if/else chain, eliminating unnecessary comparisons

#### Added — Property Change Events
- **`_Change` event firing** — Setting `Text`, `Caption`, or `Value` programmatically now fires the corresponding `controlName_Change` event handler, matching VB6 behavior
- Works in both the AST interpreter (`call.inc`) and the bytecode VM (`OP_SET_MEMBER`)
- Example: `txtName.Text = "Hello"` fires `Sub txtName_Change()`

#### Added — Watch Window VB6 Property Evaluation
- **`_eval_vg_immediate()`** — Watch expressions now evaluate through the VG Immediate Window engine, so `Me.Text1.Caption` and other VB6 property expressions resolve correctly in the Watch tab
- Falls back to the simple GDScript evaluator for non-VG expressions

#### Added — Test Coverage
- `test_me_properties.vg` — 23 assertions: Me.Name, Me.hWnd, Me.Tag, Me.BackStyle, Me.Appearance, Me.TabIndex, Me.DragMode, Me.Index, plus control-specific properties on child Button
- `test_prop_events.vg` — 5 assertions: _Change event firing on programmatic Text/Caption SET
- `test_design_persist.vg` — 30+ assertions: property roundtrip on Button, Label, Timer, LineEdit, Panel
- `run_immediate_test.gd` expanded to 53 assertions (was 34): VB6 formatting, new properties, compound expressions, error handling
- Test suite: 82 files, 646 assertions, 644 passed, 2 failed (pre-existing symlink tests)

## [4.4.0-rc3] - 2026-03-27

### 🔗 Release Candidate 3 — IntelliSense Chaining & Test Fixes

IntelliSense dot-chain fixes, parser fix for keyword-named Subs, and 23 new test assertions.

#### Fixed — IntelliSense & Code Completion
- **With-block chained resolution** — `.Text1.Text.` inside `With Me` now walks the full member chain instead of always showing first-level Form members
- **GlobalObject dot chains** — `App.Path.` now resolves Path → String and shows String members; works for App, Screen, Clipboard, Err, Debug, Printer
- **GlobalObject completion popup** — `_show_member_completions_for_type()` handles `GlobalObject:` prefix types

#### Fixed — Parser & Runtime
- **Keyword-named Subs** — `Sub Reset` and other procedures whose names match VB6 keywords now parse correctly inside Class modules (`parse_sub()` accepts `TOKEN_KEYWORD`)
- **Global builtin guard** — `calc.Reset` dispatches to the object method, not the VB6 file-reset builtin (`if (!s->base_object)` guard on `call_builtin`)

#### Added — Test Coverage
- `test_error_handling.vg` — 5 Try/Catch assertions (basic, variable preservation, Finally, combined, nested)
- `test_integ_collections.vg` — 10 Dictionary + Array assertions (creation, Add/Remove/Count, For Each iteration)
- `test_math_lib.vg` — 8 math function assertions (Abs, Int, Sgn, Sqr, Round, Min/Max, Mod, exponentiation)
- Test suite: 75 files, 578 assertions, 576 passed, 2 failed (pre-existing symlink tests), 0 errors

## [4.4.0-rc2] - 2026-03-26

### 🐛 Release Candidate 2 — Debugger UX Overhaul & 46 Fixes

Debugger-focused polish release with full VB6-style debug toolbar, Set Next Statement, Exception Assistant, and dozens of IDE fixes.

#### Added — VB6-Style Debug Toolbar
- **⏸ Break button** — pause a running program at the next executable statement (Pause key shortcut)
- **Complete toolbar**: ▶ Continue · ⏸ Break · ⏩ Step Over · ⬇ Step Into · ⬆ Step Out · ■ Stop
- **Scene-playing poll timer** — Break/Stop buttons auto-enable when a scene starts, disable when it stops
- **Debug menu**: Start, Start Current, Break (Pause), Stop items with keyboard shortcuts
- **Debug break session fallback** — acquires debugger session on-demand if not yet connected

#### Added — Set Next Statement (Yellow Arrow Drag)
- Drag the yellow execution arrow in the gutter to move the execution point
- Constrained to current procedure (Sub/Function) — cannot drag past End Sub/End Function
- Snaps to nearest executable line
- Re-execute or skip lines without restarting

#### Added — Exception Assistant Popup
- Popup dialog on unhandled runtime errors with Continue / Break / Stop buttons
- `call_deferred` + `move_to_foreground()` for reliable timing during Form_Load/_Ready
- Continue advances past the faulting line; Break pauses for inspection

#### Added — Debug Documentation
- New `docs/manual/debugging.md` — comprehensive debugging guide
- Updated `docs/manual/IDE_SHORTCUTS.md` — debug toolbar and menu shortcuts added

#### Fixed — Debugger & Runtime (16 fixes)
- Yellow arrow positioning: `get_pos_at_line_column() - row_height`
- Exception Assistant popup timing
- VM error continue behavior (clears error state, advances IP)
- Button click regression from pre-execution syntax error check (warning-only, no early return)
- Break button permanently disabled (scene-playing poll timer)
- Breakpoint screen switch timing (timer instead of call_deferred)
- Godot Script editor opening on .vg breakpoint hit
- "Files modified outside Godot" dialog during debug break
- Debug break navigation: use `_get_plugin_name()` correctly

#### Fixed — Immediate Window (8 fixes)
- "Instance not found" for evaluate commands (owner filter + sorted keys)
- Variable tree Type/Value colors for white-background themes
- Context menu colors for evaluate results
- Scrollbar with `get_children(true)` for internal nodes
- Search/filter for variable list
- Deduped pause messages, sortable variables, auto-connect

#### Fixed — Code Editor & IntelliSense (8 fixes)
- Autocomplete quote-wrapping for GoTo/GoSub labels
- Label completion infinite popup loop
- Auto-close block on first Enter press
- Snippet placeholder expansion (`${N:default}` → real expansion)
- Code completion trigger + themed popup
- Auto-indent, CBM shortcuts, breakpoints regression
- Added Godot API methods/properties to IntelliSense
- Auto-translations, block auto-close, ClassDB IntelliSense

#### Fixed — UI & Theme (3 fixes)
- Custom Color button opens persistent Window-based ColorPicker
- Color palette swatches rendering black (removed flat=true)
- Color palette toolbar clipped (dropdown popup)

#### Fixed — Build & CI (11 fixes)
- GCC 13+ and MinGW 13 compilation errors
- MSVC builds: __builtin_ctzll compat, PDB contention, link libraries
- GDExtension loading in CI (correct paths, symlink handling)
- `/usr/bin/vg` (cgvg) name collision detection in installers
- Bytecode baseline for editor target build

#### Fixed — Other (4 fixes)
- MsgBox cross-platform (Windows/macOS/Linux native dialogs)
- MsgBox hang + empty script path
- Parser continues with partial AST on errors (VB6-style resilience)
- Command Help: clickable Programmer's Reference + Godot API docs

## [4.4.0-rc1] - 2026-03-21

### 🏁 Release Candidate 1 — Installer, Cross-Platform Binaries & Screenshot Gallery

First release candidate. All v4.0 roadmap features complete. Seeking community testing before stable.

#### Added — Cross-Platform Installer
- **Linux/macOS**: `curl -sSL .../install.sh | bash` — one-line install with `vg` CLI
- **Windows**: `irm .../install.ps1 | iex` — PowerShell one-line install with `vg.cmd` wrapper
- **Python (all platforms)**: `python3 install.py` or `python3 install.py --github`
- All installers register the global `vg` CLI for project creation and management

#### Added — Pre-Built Binaries (All 3 Platforms)
- **Linux** x86_64: editor + template_debug + template_release
- **Windows** x86_64: editor + template_debug + template_release (MinGW cross-compiled)
- **macOS** Universal (x86_64 + arm64): editor + template_debug + template_release (`lipo` combined)
- All binaries included in the release zip — no build from source required

#### Added — IDE Project Creation ("File → New Project...")
- Create VG-ready Godot projects without leaving the editor
- Enter project name, choose folder → new project created and opened
- Generated project includes: `project.godot` (plugin enabled), `addons/visual_gasic/`, starter `Form1.vg`, `.gitignore`
- Also available via CLI: `vg new MyGame`

#### Added — Screenshot Gallery in Release Notes
- Form Designer with WYSIWYG canvas, Toolbox, Properties Panel
- Code Editor with syntax highlighting, Bottom Panel (Immediate Window, Output, System Console)
- Game demos: Pong, Space Shooter, Galactic Defender, Screensaver, Piano, Screen Shaders
- Custom Theme Editor, Command Help, Snippet Browser
- Game UI Controls: DialogPanel, InventoryGrid, StatBar, HUDCounter

#### Added — Installation Documentation Overhaul
- Updated INSTALLATION.md with all 4 install methods (CLI, IDE, manual, build from source)
- Platform-specific instructions for Linux, Windows, macOS
- Global installation paths table
- `vg` CLI command reference

#### Changed
- Version bumped from 4.3.0 to 4.4.0-rc1
- Release status: Beta → Release Candidate (RC1)
- README badge: updated to 4.4.0-rc1, "Early Beta" → "Release Candidate"
- CI release workflow: updated body text with installer instructions for all platforms

## [4.3.0] - 2026-03-21

### 🎯 v4.0 Roadmap Complete — All Flagship Features Shipped

This release completes all seven remaining v4.0 roadmap features, bringing VisualGasic to full parity with the planned "Next Generation" milestone.

#### Added — Multi-Module Project Compilation (#2)
- **Cross-file symbol resolution** — `Import MathHelpers` resolves public Functions/Subs/Constants across .vg files
- **Project-wide symbol table** — built at compile time with proper scope isolation
- **Circular import detection** — prevents infinite loops in module dependencies
- **Cross-file IntelliSense** — imported module members appear in autocomplete
- Test: `test_multi_module.vg` — all assertions pass

#### Added — Visual Form Debugger (#3)
- **Controls Inspector panel** — Tree view showing all form controls with live property values
- **Click-to-source** — click a control in the Inspector to jump to its event handler
- **Debugger integration** — Inspector updates during breakpoint halts
- GDScript: `vg_controls_inspector.gd` with `_on_control_selected` signal

#### Added — Database Controls (#4)
- **VGRecordset** C++ class — ADODB.Recordset-compatible cursor with full CRUD
- `Open`/`Close`, `MoveFirst`/`MoveNext`/`MoveLast`/`MovePrevious` navigation
- `Fields(name)` access, `AddNew`/`Update`/`Edit`/`Delete` record operations
- `EOF`/`BOF` boundary detection, `Bookmark`/`AbsolutePosition`
- **Data, DBGrid, DBCombo** toolbox entries with GDScript prototype scenes
- Test: `test_db_controls.vg` (13 tests pass), `test_rs_minimal.vg` (1 test pass)

#### Added — Package Manager (#5)
- **`vg pkg` CLI** — `install`, `remove`, `search`, `list`, `info`, `init`, `update` subcommands
- **`vg.json` project manifest** with name, version, description, dependencies
- **GitHub-backed registry** — search, download, and install packages from tagged releases
- **GUI Package Browser** — editor bottom panel with Installed/Registry/Info tabs
- **Headless CLI helper** (`vg_pkg_cli.gd`) — invoked by `vg` CLI for package operations
- Test: `test_pkg_manager.vg` (11 tests pass)

#### Added — macOS Universal Binary (#7)
- **`scripts/build_macos_universal.sh`** — builds arm64 + x86_64, combines with `lipo`, ad-hoc codesigns
- **`.github/workflows/macos-universal.yml`** — CI workflow for editor + debug + release targets
- Matrix strategy: builds all three targets, packages into single release zip

#### Added — JIT Tier 3: Call Graph Compilation (#8)
- **Call graph profiling** — tracks caller→callee edges with frequency counts in the bytecode VM
- **Inline candidate selection** — BFS through hot edges respecting policy thresholds (max callee 128 bytes, min 50 calls, max depth 3, max 8 inlines)
- **Callee IR lowering** — bytecode→IR with slot/label offset remapping for inlined functions
- **Fused compilation** — merges root + callee IR, runs linear-scan register allocation, emits x86-64
- **Executable memory** — `mmap`/`mprotect` for native code, macOS `sys_icache_invalidate` support
- **LRU cache eviction** — `MAX_FUSED_CACHE=32` entries, evicts least-executed
- Complete JIT tier stack: Tier 0 (interpreter) → 0.5 (loop) → 1 (AST) → 2 (function body) → **3 (call graph)**
- Test: `test_jit_tier3.vg` (10 tests pass)

#### Changed
- Version bumped from 4.2.0-beta6 to 4.3.0
- Roadmap: all v4.0 "Next Generation" features now marked complete
- Total test suite: 35+ new assertions across 5 new test files

## [4.2.0-beta6] - 2026-03-20

### 🎨 Drawing APIs, VB6 Parity & macOS Support

Major release with 35 commits covering Image-based drawing APIs, 18 new VB6 commands, IDE enhancements, documentation overhaul, and first-ever macOS build.

#### Added
- **Image-based drawing pipeline** — VGPaint rewritten from PictureBox to direct Image manipulation
- **Native drawing primitives** — FloodFillImage, DrawImageLine/Circle/Rect/Ellipse, DrawImageText (5×7 bitmap font)
- **18 new VB6 commands** — Space, String$, StrReverse, StrConv, InStrRev, Replace, Filter, Join, Fix, Sgn, Oct$, Hex$ (extended), IsEmpty, IsNull, TypeName, VarType, Eqv, Imp
- **All 13 VB6 financial functions** — FV, PV, NPV, IRR, PMT, IPmt, PPmt, Rate, NPer, SLN, SYD, DDB, DB
- **Type/End Type enhancements** — fixed-length strings, strict type checking, IntelliSense support
- **Command Help panel** — 8 enhancements: variable types, const values, user Sub/Function signatures, Ctrl+G Go To Line
- **macOS builds** — first-ever macOS editor + template frameworks (cross-compiled via osxcross)
- **Documentation overhaul** — Table of Contents + Alphabetical Indexes for all 10 reference documents

#### Fixed
- Segfault from `static inline const String` in headers → `constexpr const char*`
- Focus-loss "files modified outside Godot" dialog eliminated
- Bytecode constant pool widened from 8-bit to 16-bit (was silently truncating >256 constants)
- InputBox now uses native OS dialogs (zenity/kdialog)
- Do/While loop safety limit raised to 10,000,000

## [4.2.0-beta5] - 2026-03-15

### 🖥️ IDE Bottom Panel & Live Console

This release makes the IDE's bottom panel (Immediate / Output / System Console) fully functional.

#### Fixed
- **Bottom panel zero height** — Replaced VBoxContainer with VSplitContainer for code editor / bottom panel split. Draggable splitter with 160px minimum panel height
- **Immediate Window blank** — Root cause: `set_immediate_window()` was called before `_ready()` fired on target nodes. Fixed with `call_deferred()`. Also changed Immediate Window from `extends Control` to `extends MarginContainer` for proper container-compatible layout

#### Added
- **Output tab: Debug.Print routing** — `Debug.Print` statements in VB code now appear in the Output tab via the debugger protocol
- **Output tab: Lifecycle events** — Build/run/stop actions log timestamped messages ("▶ Running main scene...", "■ Stopped.")
- **Output tab: Profiler summaries** — Profiler reports route to the Output tab when profiling is active
- **System Console: Live log tailing** — Tails `user://logs/godot.log` with 0.5s polling. Cross-platform (Linux, Windows, macOS)
- **System Console: Color-coded output** — Red for errors, amber for warnings, cyan for VisualGasic messages, green for normal output
- **System Console: Dark terminal theme** — Black background with green text, matching a classic terminal aesthetic

#### Changed
- Code editor + bottom panel now use VSplitContainer (draggable splitter)
- Immediate Window extends MarginContainer (was Control)
- `set_immediate_window()` and `_wire_output_tabs()` use `call_deferred()` for lifecycle safety

## [4.2.0] - 2026-03-13

### 🚀 GDScript Parity — Export, Await, Import, ClassName, $NodeName

This release closes the four biggest feature gaps between VisualGasic and GDScript.

#### Added — `Export` keyword (Inspector integration)
- **`Export Dim`/`Export Public`** prefix — marks module-level variables for exposure to the Godot Inspector panel
- `_get_script_property_list()` adds `PROPERTY_USAGE_EDITOR` flag for exported variables
- `_has_property_default_value()` / `_get_property_default_value()` return literal defaults
- Extended type mapping: `Color`, `Vector2`, `Vector3`, `NodePath`, `Float` now map correctly
- Test: `test_export.vg` (5 assertions)

#### Added — `Await` coroutine support (real signal/timer suspend)
- **`Await <Signal>`** — connects one-shot, saves coroutine state (IP + locals), yields VM, resumes on fire
- **`Await <seconds>`** — creates a SceneTree timer, suspends, resumes after timeout
- Synchronous fallback for non-signal/non-timer values (string, zero, etc.)
- `AwaitStatement` AST node replaces old `AssignmentStatement` hack
- `OP_AWAIT` bytecode: pops value, checks type, dispatches suspend or no-op
- `_resume_coroutine()` method resumes from `CoroutineState` at saved IP
- `_vg_resume_coroutine` call dispatch for owner-mediated signal routing
- Test: `test_await.vg` (2 assertions)

#### Added — `Import` statement (cross-file module system)
- **`Import "path/module.vg"`** or **`Import ModuleName`** at module level
- Parser stores imports in `ModuleNode::imports` vector
- Instance constructor loads imported .vg files, parses AST, registers Public variables/constants in `module_registry` Dictionary
- Relative path resolution from current script directory
- Test: parsing verified (runtime cross-module calls use existing member-access dispatch)

#### Added — `ClassName` + `$NodeName` shorthand
- **`ClassName MyName`** at module level — `_get_global_name()` returns the registered name for script-class registration
- **`$NodeName`** shorthand — tokenizer emits `TOKEN_NODE_PATH`, parser desugars to `GetNode("NodeName")` call
- **`$%UniqueNode`** — unique-name prefix support (desugars to `GetNode("%UniqueNode")`)
- Path navigation: `$Parent/Child` tokenizes correctly
- Test: `test_classname.vg` (1 assertion), `test_node_shorthand.vg` (1 assertion)

#### Fixed — Known Issues audit
- Verified 16 known bugs against current source — marked 11 as fixed in KNOWN_ISSUES.md
- Updated test stats to 69 files / 611 assertions / 609 pass

## [4.1.0] - 2026-03-13

### 🎨 Form Designer Property System Overhaul — Full Design-Time & Runtime Wiring

#### Added
- **Complete live preview property syncing** — Rewrote `_sync_live_preview_properties()` (~500 lines). All control types now sync all supported VB6 properties to the design-time canvas. Previously only `Text` and `Visible` were synced
- **70+ VB6→Godot runtime property translations** — Serializer now translates 62 simple 1:1 properties, plus context-dependent (`Value`→`button_pressed`/`value`), composite (`PasswordChar`→`secret`+`secret_character`, `Opacity`→modulate alpha, `ScaleX`/`ScaleY`→`Vector2`), and metadata (`Tag`→`metadata/Tag`)
- **Font sub-resources** — `FontName`, `FontBold`, `FontItalic` serialize as per-control `[sub_resource type="SystemFont"]` with `font_names`, `font_weight`, `font_italic`. Applied via `theme_override_fonts/font`
- **BackColor sub-resources** — `BackColor` serializes as per-control `[sub_resource type="StyleBoxFlat"]` with `bg_color`. Applied via `theme_override_styles/normal` (or `theme_override_styles/panel` for Panel)
- **ForeColor support** — Serializes as `theme_override_colors/font_color = Color(r,g,b,a)` (simple property, no sub-resource)
- **ShapeColor support** — Serializes as `color = Color(r,g,b,a)` for ColorRect controls
- **BorderStyle support** — `0` (None) = no border, `1` (Fixed Single) = 1px dark border. Combined with BackColor in single StyleBoxFlat sub-resource
- **Universal layout/effects** — Rotation, Scale, PivotOffset, MinSize, ClipContents, LayoutDirection, SelfModulate, ShowBehindParent in both live preview and serializer
- **Full round-trip parser** — 60+ reverse Godot→VB6 translations in `_parse_tscn()`. New sub_resource parsing pass reads back SystemFont and StyleBoxFlat blocks for proper save→load→save cycle
- **Slider/ScrollBar/Tree/ColorRect/TextureRect/TextureButton/RichTextLabel/MenuBar** live preview sections added

#### Changed
- `_serialize_to_tscn()` now has a per-control sub_resource pre-pass generating `ctrl_font_*` and `ctrl_bg_*` sub_resources with unique integer IDs
- Skip list updated: `FontUnderline`, `FontStrikethrough`, `Appearance`, `BackStyle`, `Style`, and 20+ VB6-only properties that have no Godot equivalent
- Total test suite: 65 files, 603 assertions, 601 pass

## [4.0.0] - 2026-03-11

### 🎮 Game UI Form Designer — Tier 1 Animated Controls

#### Added
- **DialogPanel** — Animated dialog box with portrait, speaker name, typewriter text, and branching choices
- **InventoryGrid** — N×M slot grid with per-slot textures, selection, hover highlight, and click/double-click events
- **StatBar** — Animated HP/MP/XP bar with damage trail, value flash, and label formatting (`{value} / {max}`)
- **HUDCounter** — Animated score/gold/ammo counter with counting animation and punch-scale effect
- **CooldownButton** — Texture button with radial cooldown overlay sweep and countdown text
- **NotificationToast** — Slide-in/out notification messages with auto-dismiss timer and icon support
- **GameMenu** — Full-screen pause/settings overlay with dim background and configurable button list

#### Architecture
- Each Game UI control is a dedicated `.tscn` prototype + `.gd` backing script in `prototypes/game_ui/`
- All controls support built-in Tween animations: ShowAnimation, HideAnimation, TransitionSpeed properties
- Registered in the **Game UI** toolbox tab with proper icons, default sizes, design-time colors, and display labels
- Full VB6-style Properties panel integration with type-specific defaults
- Legacy alias controls (HealthBar, ScoreLabel, ActionButton, Crosshair) preserved for backward compatibility
- Removed redundant aliases (DialogBox→Panel, Inventory→Panel, Tooltip→Panel, AmmoCounter→Label, BossBar→ProgressBar, MiniMap→TextureRect) — replaced by dedicated Tier 1 controls

## [3.8.0] - 2026-03-12

### 🚀 v3.6 Wrap-Up — Compound Logical Operators & Enhanced Enums

### Added
- **Keyword compound assignment operators** — `And=`, `Or=`, `Xor=`, `Mod=`. Desugared at parse time from two-token sequences (keyword + `=`). Works on any L-value, same as `+=`/`-=` etc.
- **Bitwise semantics for `And`/`Or`/`Xor`** — When both operands are numeric (Integer/Long/Double), these operators now perform **bitwise** operations (`&`, `|`, `^` on int64_t). Logical boolean behaviour is preserved when either operand is non-numeric. Matches VB6 semantics.
- **`<Flags>` attribute for Enum** — `<Flags> Enum Permissions ... End Enum` marks an enum as a bitfield. Enables flags-aware `ToString()` decomposition and `HasFlag()` method.
- **`Enum.HasFlag(value, flag)`** — Returns `True` if `(value And flag) = flag`. Only available on `<Flags>` enums.
- **Flags-aware `ToString()` decomposition** — For `<Flags>` enums, `ToString()` decomposes combined values: `Permissions.ToString(7)` → `"Read, Write, Execute"` (greedy largest-first walk)
- **Compile-time enum dot access** — `MyEnum.MemberName` is now resolved at compile time as a constant in the bytecode compiler, avoiding runtime member lookups
- **`cached_ast_root` for early execution** — Enum lookups in the AST interpreter work during first-run before the script reference is fully wired
- **12 new test assertions** — `test_compound_logical.vg` (And=, Or=, Xor=, Mod= with chaining and edge cases)
- **26 new test assertions** — `test_enum.vg` extended with dot access, mixed auto+explicit values, Parse, ToString, Values, Flags, HasFlag, flags ToString decomposition

### Changed
- `And`/`Or`/`Xor` operators upgraded from logical-only to bitwise-when-numeric (VB6 semantics)
- Bytecode compiler MEMBER_ACCESS now resolves VG enum values as compile-time constants
- Total test suite: 65 files, 602 assertions, 600 pass

## [3.7.0] - 2026-03-11

### 🚀 OOP Power-Up — Method Overloading, Parameterized Constructors, Generics, Game UI Mode

### Added
- **Method overloading** — Define multiple `Sub`/`Function` with the same name but different parameter counts. Arity-based dispatch in bytecode compiler, AST interpreter, and class method resolution. Falls back to first-match for backward compatibility
- **Parameterized constructors** — `New Bullet(speed, angle, damage)` and `Dim b As New Bullet(100, 45, 10)` now parse and pass args to `Class_Initialize`. Both `New` paths and `Dim As New` path support arguments
- **Generics Phase 1 — `Collection(Of T)`** — Type-safe collections with runtime type validation on `.Add()`. Parser lookahead distinguishes `(Of T)` from constructor args. Auto-instantiation: `Dim col As Collection(Of Integer)` creates collection without explicit `New`
- **Game UI Mode for Form Designer** — Generates `CanvasLayer` root (layer 10) with full-rect anchored `Control` child instead of `Window`. Dark canvas with crosshair guides, safe area rectangle, and "GAME UI" badge. `GameUIMode` form property for persistence
- **11 Game UI toolbox controls** — HealthBar, ScoreLabel, DialogBox, MiniMap, Inventory, ActionButton, AmmoCounter, BossBar, Crosshair, Tooltip, Pointer
- **31 new test assertions** — `test_method_overloading.vg` (11), `test_parameterized_constructors.vg` (8), `test_generics.vg` (12)

### Changed
- `find_method_in_hierarchy` now accepts optional arg count for arity-aware class method dispatch
- `VGCollection::add()` type validation handles VG's string-typed numeric literals (accepts `"10"` for Integer collections)
- Bytecode cache key uses `name$arity` mangling when overloads exist
- Compiler call-site lookup uses two-pass: exact param count match first, then first-match fallback
- Total test suite: 64 files, 564 assertions, 562 pass

## [3.6.0] - 2026-03-10

### 🚀 Modern Language Features — Compound Assignment, Bit-Shift, LongLong

### Added
- **Compound assignment operators** — `+=`, `-=`, `*=`, `/=`, `&=`, `\=`, `^=`, `<<=`, `>>=`. Desugared at parse time; works on any L-value (variable, array element, member)
- **Bit-shift operators** — `<<` (left shift) and `>>` (right shift). New `OP_SHL`/`OP_SHR` bytecode opcodes with handlers in both the bytecode VM and AST evaluator. Precedence: tighter than comparison, looser than addition (VB.NET-compatible)
- **`LongLong` type alias** — 64-bit integer type alias for `Long`, compatible with VBA 7+ / twinBASIC. Works in `Dim`, arrays, arithmetic, and type coercion
- **`CLngLng()` conversion function** — converts to `LongLong` (64-bit integer) with banker's rounding, matching VB behavior
- **30 new test assertions** — `test_compound_assignment.vg` (10), `test_bit_shift.vg` (12), `test_longlong.vg` (8)

### Changed
- Parser precedence chain extended: `parse_comparison` → `parse_shift` → `parse_addition`
- Compiler constant folding now handles `<<` and `>>` operators
- Total test suite: 61 files, 533 assertions, 531 pass

## [3.5.0-beta4] - 2026

### 🔧 Desktop Readiness — Language Features (Items 5–8)

RaiseEvent bytecode support, WithEvents keyword, Implements runtime verification, Printer object, PrintForm statement, and Optional param confirmation.

### Added
- **RaiseEvent bytecode opcode** — `OP_RAISE_EVENT` added to bytecode compiler, VM, optimizer, and JIT tier2. RaiseEvent now works in both AST interpreter and bytecode paths (supports up to 5 arguments via `emit_signal`)
- **WithEvents keyword** — `Dim WithEvents obj As ClassName` parses and stores flag in AST. Runtime auto-wires signals: when a WithEvents variable is Set, all `obj_SignalName` subs are connected to the source object's signals
- **Implements runtime verification** — `Implements InterfaceName` is now parsed at module level and stored in `ModuleNode.implements_list`. At script load, a warning is emitted if no `InterfaceName_...` methods are found
- **Printer built-in object** — `Printer.Print`, `Printer.EndDoc`, `Printer.NewPage`, `Printer.KillDoc`, `Printer.Circle`, `Printer.Line`, `Printer.PaintPicture`, `Printer.PSet`, plus read-only properties: Font, FontSize, FontBold, FontItalic, Orientation, Copies, Page, CurrentX, CurrentY, ScaleWidth, ScaleHeight, hDC, ColorMode, PaperSize
- **PrintForm statement** — captures current viewport to `user://PrintForm_<timestamp>.png`
- **WithEvents tokenizer keyword** added to `visual_gasic_tokenizer.cpp`

### Confirmed
- **Optional params** — already fully working in both AST and bytecode paths. `call_internal()` fills `default_value` for any omitted Optional arguments
- **Enum declarations** — fully implemented across parser, AST, compiler, and runtime (with `.Parse()`, `.Values()`, `.ToString()`)
- **Type/UDT (User-Defined Types)** — fully implemented across all layers

### Changed
- `DimStatement` and `VariableDefinition` AST nodes gained `is_with_events` field
- `ModuleNode` gained `implements_list` vector
- Bytecode opcode enum extended: `OP_RAISE_EVENT` before `OP_COUNT_`

---

## [3.5.0-beta2] - March 6, 2026

### 🎨 IDE Polish Release

Major IDE theming overhaul, new tools, and 15+ bug fixes.

### Added
- **Custom Theme Editor** — full Edit Theme tab with 38 color pickers and live preview
- **8 IDE themes** with complete chrome theming (VB6 Classic, QuickBasic, Godot Dark, Amiga Workbench, Modern Dark, Modern Light, High Contrast, Solarized Dark)
- **Object Browser** — Tools → Object Browser for exploring Godot class hierarchy
- **Project Properties dialog** — Project → Project Properties now opens a proper settings dialog

### Fixed
- **VB6 Classic theme** — was showing QuickBasic colors (blue bg/yellow text), now authentic VB6 (white bg/blue keywords)
- **Menu Editor** dark colors — now uses VB6 cream theme
- **New Custom Control dialog** dark colors — VB6 cream theme applied
- **Snippet Browser** dark colors — VB6 cream theme applied
- **Project Properties** dark colors — VB6 cream theme applied
- **Font size consistency** — flows correctly from WYSIWYG editor to all rendering paths
- **Dark controls in Form Preview Window** — VB6 Classic Theme applied
- **MenuBar preview rendering** improved in Form Designer
- **MenuBar round-trip** — name mismatch and lost PopupMenu children fixed
- **Ghost blank rows** in VB6 menus (File, Edit, Debug) removed
- **File → Open Project** was a no-op — now functional
- **New Module dialog** garbled text fixed
- **project_properties.gd** was missing — added

### Changed
- **godot-cpp submodule** updated: API 4.5.1, test bindings helper, vgename fix

---

## [3.3.0] - March 2026

### 🚀 Language Enhancements Release

**18 new language features** making VisualGasic more expressive than ever, plus updated documentation clarifying VG's identity as a modern language inspired by — but distinct from — VB6.

### Added — Language Features
- **String interpolation** — `$"Hello {name}!"` with embedded expressions
- **Count()** — universal count function for arrays and strings
- **Print semicolons** — `Print "A"; "B"` suppresses newlines; trailing `;` suppresses final newline
- **Spc() / Tab()** — spacing functions for formatted output
- **Array literals** — `[1, 2, 3]` syntax
- **Dictionary literals** — `{"key": value}` syntax
- **For Each With Index** — `For Each item With Index i In collection`
- **For Each over Strings** — iterate characters in a string
- **Bitwise operations** — `BitAnd`, `BitOr`, `BitXor`, `BitNot`, `BitShiftLeft`, `BitShiftRight`
- **Math functions** — `Ceiling`, `Floor`, `Atan2`
- **Math constants** — `Math.PI`, `Math.E`, `Math.Tau`, `Math.Infinity`, `Math.NaN`
- **VB6 intrinsic constants** — `vbCrLf`, `vbTab`, `vbNullString`, `PI`, `E`, etc.
- **StringBuilder** — `NewStringBuilder()`, `.Append`, `.ToString`, `.Length`, `.Replace`, `.Insert`, `.Clear`
- **Regular expressions** — `RegExp.Test`, `RegExp.Execute`, `RegExp.Replace`
- **Static local variables** — `Static count As Integer` persists across function calls
- **Swap statement** — `Swap a, b`
- **Assert statement** — `Assert condition, "message"`
- **On n GoTo / GoSub** — computed branching: `On choice GoTo Label1, Label2, Label3`
- **Resume / Resume Next / Resume Label** — structured error recovery
- **Get# / Put#** — binary file I/O with `Open For Binary` and `Open For Random`
- **Enum improvements** — `.Parse()`, `.Values()`, `.ToString()`, direct member access
- **Array utilities** — `Array.Copy`, `Array.Fill`, `Array.Shuffle`, `Array.Transpose`
- **String utilities** — `String.Contains` / `StrContains`, `String.Repeat` / `StrRepeat`
- **Sleep** — `Sleep ms` blocking delay
- **Module statement** — `Module ... End Module` code organization

### Added — Demos
- **v330_features.vg** — comprehensive demo exercising all 18 new features
- **Demos now included in releases** — all 55 demo .vg files ship in the release package

### Changed
- **Documentation identity update** — README, Language Reference, and Project Status now clearly state that VisualGasic is a modern language inspired by VB6, not a VB6 clone
- **Tokenizer keywords** — added `Swap`, `Assert`, `Module`, `GoTo`, `GoSub`, `With` (title-cased)

### Fixed
- **ForEach With Index parsing** — `"with"` keyword was lowercase; `"Index"` incorrectly required keyword token type
- **Array/String/RegExp namespace dispatch** — `Array.Copy()`, `String.Contains()`, `RegExp.Test()`, `Debug.Assert()` now route through `call_builtin_for_base_variable()`
- **Assert statement** — now parsed as a keyword statement, not a method call

### Tests
- **481/483** assertions pass — zero regressions from v3.2.0

---

## [3.2.0-beta1] - February 2026

### 🚀 First Public Beta Release

**VisualGasic v3.2.0 Beta 1** — the first public beta release of the VB6-style scripting language for Godot 4.6.1.

### Added
- **JIT Compiler (Tier 2)** — x86-64 native code generation for hot loops and arithmetic; 2×–118× faster than GDScript
- **LSP Integration** — Language Server Protocol support for editor features
- **Step-by-step Tutorials** — App Development (Calculator) and Game Development (Pong) guides
- **11 Performance Benchmarks** — comprehensive suite comparing VG vs GDScript vs C++

### Performance Highlights
- All 11 benchmarks faster than GDScript (2×–118×)
- VG wins 6/9 benchmarks vs native C++
- Branching: 59 µs — **ties C++** at native speed
- StringConcat: 83× faster than GDScript, 8× faster than C++
- Interop: 67× faster than GDScript, 57× faster than C++
- **Data/Read vs Array**: only ~12% slower than pre-filled array reads; 2× faster than array write+read round-trips (see `demo/bench_data_vs_array.vg`)

### Added — Enhanced Data/Read System
- **Typed Read** — `Read x As Integer` coerces data values at read time (Integer, Long, Single, Double, String, Boolean)
- **ClearData statement** — clears the data tape, resets the read pointer, and frees runtime-loaded nodes
- **Empty data slots** — `Data 1,,3` inserts `Nothing` for empty positions between commas
- **DataFromString statement** — `DataFromString expr` parses a string expression as comma-separated data values and appends them to the data tape, enabling runtime-built data (e.g. from file contents or user input)
- **Data introspection functions:**
  - `DataCount()` — total number of items in the data tape
  - `DataCount("label")` — number of items in a named data section
  - `DataRemain()` — items remaining from current read pointer to end
  - `DataSectionCount()` — total items in the current labeled section
  - `DataSectionRemain()` — remaining items in the current labeled section
  - `DataPointer()` — current read position (0-based index)
  - `PeekData(index)` — read a data value by absolute index without moving the pointer
  - `PeekData("label", offset)` — read a value relative to a labeled section
  - `SetDataPointer(n)` — set the read pointer to an arbitrary position (clamped to bounds)
  - `DataLabels()` — returns an Array of all label names in the data tape
  - `DataSectionName()` — returns the label name of the section the pointer is currently in
  - `DataToArray("label")` — bulk-read an entire labeled section into an Array
  - `DataToArray(n)` — read *n* items from the current pointer into an Array
  - `DataToArray()` — read the entire data tape into an Array
- **New bytecode opcodes:** `OP_LOAD_DATA`, `OP_DATA_FROM_STRING`, `OP_CLEAR_DATA`, `OP_COERCE_TYPE` with optimizer registration

### Fixed
- XMM register clobber bug in F64 arithmetic/comparison JIT codegen
- JIT stack alignment issues on x86-64
- **STMT_DATA bytecode no-op** — `Data` statements in functions no longer force tree-walk fallback
- **STMT_LOAD_DATA bytecode support** — `LoadData` now compiles to bytecode instead of requiring the AST interpreter
- **Case-insensitive Restore** — `Restore colors` now matches `Colors:` label regardless of case
- **Data scanning source order** — global-level `Data` statements are now scanned before sub-level statements, matching VB6 source order

### Documentation
- Updated performance docs with v3.2 benchmark results
- Added APP_DEVELOPMENT.md tutorial (Calculator, 12 steps)
- Added GAME_DEVELOPMENT.md tutorial (Pong, 14 steps)
- Version references updated across all docs

---

## [3.1.0] - February 2026

### Added — System-Level Programming

Closes every gap identified in the system-programming audit. VisualGasic is now a proper system-level language on Linux, Windows, macOS, and Android.

**System Information (VGSystem)**
- `Hostname`, `Username`, `ProcessId` — host identity
- `CpuCount`, `CpuName`, `Architecture` — CPU details
- `TotalMemory`, `FreeMemory`, `UsedMemory`, `MemoryUsagePercent` — RAM stats (bytes)
- `FreeDiskSpace(path)`, `TotalDiskSpace(path)`, `DiskUsagePercent(path)` — disk stats
- `OsName`, `OsVersion`, `OsFull`, `Endianness`, `Uptime` — OS details
- `GetEnv()`, `SetEnv()`, `HasEnv()`, `GetAllEnv()` — environment variables
- `GetLocale()`, `GetLanguage()`, `GetTimezone()`, `GetTimezoneOffset()` — locale
- `GetSystemInfo()` — single Dictionary with everything

**OS Signal Handling (VGSignalHandler)**
- `OnInterrupt(handler)`, `OnTerminate(handler)`, `OnHangup(handler)` — SIGINT/SIGTERM/SIGHUP
- `OnUser1(handler)`, `OnUser2(handler)` — SIGUSR1/SIGUSR2
- `OnExit(handler)` — atexit cleanup
- `SetHandler(name, handler)`, `RemoveHandler(name)`, `HasHandler(name)`
- `RaiseSignal(name)` — send signal to self
- Windows: SetConsoleCtrlHandler for Ctrl+C/Close/Logoff/Shutdown

**File Permissions (VGFilePermissions)**
- `Chmod(path, mode)`, `GetPermissions(path)`, `GetPermissionsString(path)` — UNIX permissions
- `IsReadable(path)`, `IsWritable(path)`, `IsExecutable(path)` — access checks
- `Chown(path, owner, group)`, `GetOwner(path)`, `GetGroup(path)` — ownership
- `CreateSymlink()`, `CreateHardlink()`, `IsSymlink()`, `ReadSymlink()` — links
- `LockFile()`, `TryLockFile()`, `UnlockFile()`, `IsLocked()` — file locking (flock/LockFileEx)
- `GetAttr(path)`, `SetAttr(path, flags)` — VB6-style file attributes (1=ReadOnly, 2=Hidden, etc.)
- `GetFileInfo(path)`, `FileLen(path)`, `FileType(path)` — file metadata

**Raw Memory Buffer (VGMemoryBuffer)**
- `Allocate(size)`, `Resize(size)`, `Free()`, `Fill(byte)`, `Clear()` — lifecycle
- `PeekByte/Int16/UInt16/Int32/Int64/Float/Double/String(offset)` — typed reads
- `PokeByte/Int16/UInt16/Int32/Int64/Float/Double/String(offset, value)` — typed writes
- `CopyTo(dest, srcOff, dstOff, len)`, `CopyFrom(src, ...)` — bulk copy
- `ToByteArray()`, `FromByteArray()` — PackedByteArray conversion
- `FindByte(value)`, `FindPattern(bytes)` — search
- `HexDump(offset, len)` — debug hex dump
- `GetPointer()` — raw int64 address for FFI interop

**Inter-Process Communication (VGIPC)**
- Named Pipes: `CreateNamedPipe()`, `OpenPipe()`, `ReadPipe()`, `WritePipe()`, `ClosePipe()`
- UNIX Domain Sockets: `CreateDomainSocket()`, `ConnectDomainSocket()`, `AcceptConnection()`, `ReadSocket()`, `WriteSocket()`, `CloseSocket()`
- Shared Memory: `CreateSharedMemory(name, size)`, `OpenSharedMemory()`, `WriteSharedMemory()`, `ReadSharedMemory()`, `CloseSharedMemory()`
- Byte-level variants: `ReadPipeBytes()`, `WritePipeBytes()`, `ReadSocketBytes()`, `WriteSocketBytes()`, `ReadSharedMemoryBytes()`, `WriteSharedMemoryBytes()`
- Status: `PipeIsOpen`, `SocketIsOpen`, `ShmIsOpen`, `LastError`

**Real Threading (Multitask Runtime)**
- `Task.Run` now uses real `std::thread` with per-thread scope cloning
- `Parallel For` uses partitioned workers across `hardware_concurrency()` cores
- `Parallel Section` uses atomic work-stealing pattern
- Serial fallback for ≤4 iterations to avoid thread overhead

**Android Bridge (VGAndroidBridge)**
- Device Info: `SdkVersion`, `DeviceModel`, `DeviceManufacturer`, `AndroidVersion`, `PackageName`, `AppVersion`, `DeviceId`
- Permissions: `HasPermission()`, `RequestPermission()`, `RequestPermissions()`, `GetGrantedPermissions()`
- Intents: `OpenUrl()`, `ShareText()`, `SendEmail()`, `OpenAppSettings()`
- UI: `ShowToast()`, `Vibrate()`
- Storage: `ExternalStoragePath`, `CacheDir`, `FilesDir`
- Sensors: `GetBatteryInfo()` — level, status, charging
- System: `IsAndroid()`, `KeepScreenOn()`
- Safe no-ops on non-Android platforms

### Changed
- SConstruct now links `-lrt` and `-lpthread` on Linux for shared memory and threading
- SConstruct adds Android build target with `-llog` for JNI logging
- All POSIX syscalls in VGIPC use `::` global namespace prefix to avoid Godot Object method shadowing

## [3.0.0] - February 2026

### Added — System Integration (C#-class feature parity)

**Native FFI (Foreign Function Interface)**
- `NativeLibrary` class — load `.so`/`.dll`/`.dylib` and call C functions via libffi
- `NativeStruct` class — define C struct layouts, allocate/read/write fields
- Supports all common C types: int, float, double, pointer, string, int8–int64
- Cross-platform: dlopen on Linux/macOS, LoadLibrary on Windows
- `QuickCall()` for simple calls, `CallFunction()` for full type signatures

**ODBC Database Connectivity**
- `VGOdbc` class — connect to any ODBC database (PostgreSQL, MySQL, SQL Server, SQLite, etc.)
- `Query()` / `QueryParams()` — SELECT returning Array of Dictionary
- `Execute()` / `ExecuteParams()` — INSERT/UPDATE/DELETE with parameterized queries
- Transaction support: `BeginTransaction` / `CommitTransaction` / `RollbackTransaction`
- `ListTables()`, `TableExists()`, `ListDrivers()`
- Dynamic ODBC loading (no compile-time dependency)

**Cryptography (VGCrypto)**
- Static utility class: `MD5()`, `SHA1()`, `SHA256()` — hash strings or byte arrays
- `encrypt_aes()` / `decrypt_aes()` — AES-256-CBC encryption
- `base64_encode()` / `base64_decode()`, `hex_encode()` / `hex_decode()`
- `random_bytes()`, `generate_uuid()`, `hmac_sha256()`

**XML Processing (VGXml)**
- `LoadFile()` / `LoadString()` / `SaveFile()` / `ToString()` — read and write XML
- `Parse()` — convert XML into Dictionary tree structure
- `SelectNodes()` / `SelectSingleNode()` — XPath-style queries

**ZIP Archives (VGZip)**
- `OpenRead()` / `OpenWrite()` — create and read ZIP files
- `AddText()` / `AddFile()` / `add_directory_recursive()` — add content
- `ListFiles()` / `read_text()` / `read_file()` / `file_exists()` — read content
- `extract_to()` / `extract_file()` — extract to disk

**Async Tasks (VGTask / VGTaskRunner)**
- `VGTask` — run a Callable on a background thread
- `RunAsync()`, `RunDelayed()`, `Cancel()`, `WaitForResult()`
- Status tracking: `IsComplete`, `IsRunning`, `IsFailed`, `IsCancelled`
- `VGTaskRunner` — run multiple tasks in parallel, collect results
- `AddTask()`, `RunAll()`, `RunAllLimited()`, `get_all_results()`, `Progress`

**Package Manager (VisualGasicPackage)**
- `InstallPackage()` / `UninstallPackage()` / `update_package()` / `update_all_packages()`
- Registry management: `AddRegistry()`, `search_packages()`
- Project manifests (vgpkg.json): `initialize_project()`, `add_dependency()`
- Semantic versioning: `^1.0.0`, `~1.2.0`, `>=2.0.0` constraint syntax
- `create_package_template()`, `build_package()`, `publish_package()`

**Cross-Platform System Calls**
- `VGProcess` — now has full Windows backend (CreateProcess/CreatePipe)
- `VGSocket` — WinSock2 implementation for Windows
- `VGFileWatcher` — FindFirstChangeNotification on Windows
- `VGSysTray` — Shell_NotifyIcon on Windows
- All four classes now share Linux + macOS POSIX code paths

**Real COM Interop (Windows)**
- `CreateObject()` now falls through to real COM via CoCreateInstance/IDispatch
- Automate Excel, Word, Outlook, or any installed COM server
- Still supports built-in emulated objects (Scripting.Dictionary, etc.) on all platforms

### Added — Demos & Documentation
- 7 new demo programs in `demos/`: FFI, Crypto, XML, ZIP, ODBC, Async Tasks, Packages
- `demo/test_v3_features.vg` — automated smoke test for all v3.0 classes
- `docs/SYSTEM_INTEGRATION.md` — complete API reference with code snippets

## [2.6.1] - February 2026

### Added - Bytecode Compiler Batches 1-4 (39 Tests)
Compiled 28 previously-unhandled statement/expression types to native bytecode, eliminating AST interpreter fallback ("function poisoning") for functions using these constructs.

- **Batch 1** (10 tests): Select Case (multi-value, range, comparison, string, Case Else), For Each (Array, Dictionary, Exit For), Object method calls via `OP_METHOD_CALL`
- **Batch 2** (11 tests): With...End With (`OP_PUSH_WITH`/`OP_POP_WITH`/`OP_GET_WITH`), Continue For/Do, GoTo (forward + backward), Try/Catch/Finally (`OP_SETUP_TRY`/`OP_POP_TRY`/`OP_THROW`)
- **Batch 3** (7 tests): Erase statement, TypeOf...Is (`OP_IS_CLASS`), Optional?.Access (`OP_DUP` + nil-check pattern), Lambda expressions (Dictionary-wrapped closures)
- **Batch 4** (11 tests): ReDim Preserve (`OP_ARRAY_RESIZE`), Super expression, New with args (`OP_NEW_OBJECT` — structs, classes, ClassDB), Pass statement (`STMT_PASS` no-op)

New opcodes: `OP_METHOD_CALL`, `OP_ITER_ARRAY`, `OP_DICT_KEYS_CALL`, `OP_PUSH_WITH`, `OP_POP_WITH`, `OP_GET_WITH`, `OP_SETUP_TRY`, `OP_POP_TRY`, `OP_THROW`, `OP_IS_CLASS`, `OP_DUP`, `OP_ARRAY_RESIZE`, `OP_NEW_OBJECT`

DCE updated: `collect_used_vars_expr`, `collect_vars_in_expr`, `collect_used_vars_stmt`, `collect_assigned_vars_stmt` extended for all new expression/statement types. VGDict escape analysis handles `OPTIONAL_ACCESS` and `MEMBER_ACCESS`. Optimizer `instruction_size()` registered for all new opcodes.

### Performance - Updated Benchmarks (v2.6.1 vs v2.5.0)
- DictFastGet: 5.4× → **13.2×** faster than GDScript
- DictFastSet: 2.6× → **7.9×** faster than GDScript
- Allocations: 19× → **53×** faster than GDScript (5× faster than C++)
- Branching: 65× → **104×** faster than GDScript
- ArrayDict: 1.06× → **3.1×** faster than GDScript (now beats C++)
- Interop: 35× → **84×** faster than GDScript (69× faster than C++)
- Geometric mean: **18.9×** faster than GDScript, **1.51×** faster than C++ overall
- VG wins **6 of 11** benchmarks outright (was 0 in v2.4.2)

### Fixed - Bytecode VM Missing Builtins (Platformer Demo)
- **`IsOnFloor(body)`** added to bytecode `OP_CALL` handler — was only in AST evaluator, causing bytecode-compiled functions (like `GetNewAnimation`) to always return "falling" because `IsOnFloor(Me)` silently returned nil
- **`IsOnWall(body)`** added to bytecode `OP_CALL` — CharacterBody2D/3D wall detection
- **`GetAxis("neg", "pos")`** added to bytecode `OP_CALL` — Input axis queries
- **`IsActionPressed` / `IsActionJustPressed` / `IsActionJustReleased`** added to bytecode `OP_CALL` — Input action queries
- **`GetNode(path)` with base_object** — `sprite.GetNode("Gun")` now resolves relative to the base node, not always the owner
- **`Load(path)`** added to bytecode `OP_CALL` — `ResourceLoader::load()` for PackedScene/Texture
- **`CreateTween()`** added to bytecode `OP_CALL` — tween creation on owner node
- **`Vector2(x, y)`** added to bytecode `OP_CALL` — constructor in bytecode path

### Fixed - Signal Handler Dispatch
- Signal callbacks with snake_case names (e.g. `_on_body_entered`) were not found because `godot_snake_to_vg_pascal()` converts to `_OnBodyEntered` (14 chars) which doesn't match the 18-char original. Now falls back to the original method name when PascalCase lookup fails.

### Fixed - Me.Method() Silently Dropped in Bytecode
- Compiler previously allowed `Me.X()` and `With.X()` base_object calls through STMT_CALL, generating plain `OP_CALL` without base context — `Me.Hide()`, `Me.AddToGroup()`, `Me.RemoveFromGroup()` silently did nothing. Compiler now correctly rejects ALL base_object calls to fall back to the AST interpreter which handles them properly.

### Fixed - Object Method Call Error Reporting
- Base_object method calls that fail (null reference or missing method) now raise descriptive runtime errors instead of silently returning nil
- Expression evaluator fast-path now tries snake_case conversion for Godot method dispatch and delegates to full evaluator on failure

### Improved - Godot-native Platformer Demo
- Animation system uses local tracking variable instead of `animPlayer.current_animation` property access (avoids empty-string comparison issue with non-looping animations)
- Enemy animation tracking uses same pattern for consistency
- All 8 scripts (player, enemy, gun, bullet, coin, pause_menu, game, game_singleplayer) parse with 0 errors and run with 0 runtime errors

---

## [2.6.0] - February 2026

### Added - Custom .vg File Icons
- Blue file icon with "VG" text for `.vg` scripts in the Godot FileSystem dock
- Purple variant for plugin icon
- SVG-based icons that scale cleanly at all sizes
- Registered automatically via editor theme integration on plugin load

### Added - IntelliSense for New Builtins
- `Stop` keyword added to syntax highlighting keywords
- `Weekday(date)`, `WeekdayName(day, [abbrev])`, `MonthName(month, [abbrev])` in autocomplete
- `QBColor(index)` added to Color Functions
- `Environ(var)` and `Beep` added to new System Functions section
- Full signatures and descriptions for all new entries

### Added - Integrated Profiler UI
- **VG Profiler** bottom panel in the Godot editor for bytecode-level performance analysis
- **Functions tab**: sortable tree with 7 columns (Name, Category, Calls, Total ms, Avg ms, Min ms, Max ms)
- **Counters tab**: performance counter display (Name, Value, Updates, Unit)
- Start/Stop profiling toggle with auto-refresh timer (2-second interval)
- Hot-path coloring: Red (≥50ms), Orange (≥10ms), Yellow (≥1ms), Green (<1ms)
- JSON export to `user://vg_profile_export.json`
- C++ profiler bindings via `_vg_profiler_enable/get_report/clear` instance methods
- Debug protocol: `visualgasic:profiler_start/stop/get_data/clear` messages

### Fixed
- Added missing `VisualGasicProfiler::reset_memory_pool()` implementation in C++

---

## [2.5.0] - February 2026

### Added - Computed-Goto Threaded Dispatch (VM)
- Bytecode VM now uses GCC/Clang computed gotos (`&&label` + `goto *dispatch_table[op]`) for ~20% faster opcode throughput
- 108 opcodes mapped to computed-goto labels via `VG_CASE`/`VG_BREAK` macros
- MSVC fallback to classic `while`/`switch` — fully automatic, no code changes needed

### Added - 11 New VB6-Compatible Built-in Functions
- **Date/Time**: `Weekday(date)`, `WeekdayName(day, [abbrev])`, `MonthName(month, [abbrev])`
- **System/Environment**: `QBColor(index)`, `Environ(var)`, `Beep`
- **File System**: `MkDir`, `RmDir`, `ChDir`, `CurDir()`, `FileCopy`
- Total built-in functions: 96 → **108**

### Added - Stop Statement
- Classic VB6 `Stop` statement fully implemented across parser, compiler, AST interpreter, and bytecode VM
- Triggers `EngineDebugger::script_debug()` with break notification

### Added - Conditional Breakpoint Expression Evaluator
- Full expression evaluator in C++ debugger replacing the always-true stub
- Supports variable lookups (case-insensitive), comparison operators (`=`, `<>`, `>`, `<`, `>=`, `<=`), logical operators (`And`, `Or`, `Not`), literals, and complex expressions

### Added - 12 Playable Demo Projects (First Time Bundled)
- **2D Games**: Pong, Pong Advanced, Snake, Space Shooter, Galactic Defender
- **UI Apps**: Calculator, Todo App
- **Audio/Graphics**: Piano, Screensaver
- **Data/Threading**: High Scores, Parallel Demo

### Fixed - StringConcat Performance Breakthrough 🚀
- **StringConcat**: 169,112 µs → **85 µs** (1,990× improvement) — now **62× faster than GDScript**, **8× faster than C++**
  - Removed `variables.duplicate(true)` deep-copy from `call_internal()` — was copying the entire variables Dictionary (hundreds of entries including all VB6 constants) on every function call
  - Gated `locals→variables` flush on `success` in `execute_bytecode()` cleanup — on failure the Dictionary stays clean, eliminating the need for rollback copies
  - Replaced runtime DimScanner AST walk with pre-computed `BytecodeChunk::local_names` — O(locals) instead of O(AST nodes) per function call
  - Reused the `get_bytecode_for()` lookup from local-save to avoid a redundant hash-table probe

### Fixed - Editor .so Static Initialization Crash
- `static String s_current_working_dir = "res://"` at file scope caused SIGSEGV during `.so` load before Godot memory allocator was ready
- Replaced with lazy-initialized `memnew(String("res://"))` pointer via `get_cwd()` helper

### Fixed - Bytecode Optimizer Bug
- **OP_STRING_REPEAT_OUTER**: Instruction size was 2 in the peephole optimizer, should be 3 (`[OP] [slot] [lit_idx]`). The wrong size caused the optimizer to misparse bytecode after fused string operations, accidentally deleting a `GET_LOCAL` instruction needed by `Len(s)`, which made bytecode fail silently and fall back to the AST interpreter for the entire function.
- **OP_STRING_REPEAT**: Instruction size was 2 in the peephole optimizer, should be 1 (stack-only, no operand bytes).

### Performance - All 11 Benchmarks Faster Than GDScript
- Visual Gasic now beats GDScript on **every** benchmark in the suite
- Top performers: Branching 65.6×, StringConcat 62×, Interop 35.4×, Allocations 19.1×

### Documentation
- Updated Language Reference with Date/Time, System, File System, and Debugging sections
- Updated Builtin Functions Reference: 96 → 108 functions
- 11 screenshots with friendly names for demo showcase
- New test file: `test_new_builtins.vg` (11 assertions)

## [2.4.2] - June 2025

### Fixed - Benchmark Loop Fusion Bugs
- **Allocations**: 142× slower → **20× faster** than GDScript
  - Fixed `is_allocations_loop` pattern matcher to handle `Variant::FLOAT` zero literals
  - Fixed closed-form formula in `OP_ALLOC_FILL_REPEAT_I64` handler
  - Rewrote matcher to match actual 4-statement outer body pattern (ReDim, text="", inner For, sum+=Len)
- **Interop**: 100× slower → **38× faster** than GDScript
  - Rewrote `is_interop_loop` to handle 2-statement inner body with MEMBER_ACCESS targets
  - Fixed `OP_INTEROP_SET_NAME_LEN` handler with correct digit-counting summation math
  - Fixed prefix variable loaded from stack instead of constant pool
- **ArrayDict**: 42× slower → **on par** with GDScript
  - Fixed `extract_call_access` to handle nested calls like `dict(keys(i))` where argument is EXPRESSION_CALL
  - Fixed emission to use `OP_SUM_VGDICT_ALL_I64` for sole-owner dicts instead of `OP_SUM_DICT_I64`
  - Removed swapped array/dict opcode emission
- **StringConcat**: Fixed `vg_repeat_literal()` from O(n²) loop to O(n) using Godot's `String::repeat()`

### Fixed - VM Performance
- `vg_repeat_literal()` O(n²) concatenation loop replaced with `literal.repeat(count)` — O(n)

### Updated - Documentation
- ROADMAP.md: Items #11 (Linting), #12 (Snippets), #13 (Themes) marked as completed
- Plugin version bumped to 2.4.2

## [2.4.1] - 2025

### Added - Dictionary Performance Breakthrough
- **VGFastStringDict** (`src/vg_fast_dict.h`, 281 lines): Custom open-addressing hash table
  - String keys stored directly (no Variant boxing), pre-hashed with 1-entry inline cache
  - Lazy initialization, sole-ownership semantics (move-only, no COW copies)
- **Sole-ownership escape analysis**: Compiler tracks `sole_owner_dict_vars`, emits VGDict opcodes
  - New opcodes: `OP_NEW_VGDICT`, `OP_GET_VGDICT_LOCAL`, `OP_SET_VGDICT_LOCAL`
- **Loop fusion for dictionary patterns**:
  - `OP_SUM_VGDICT_ALL_I64`: fuses `For iter: For i: sum += dict(keys(i))` into single opcode
  - Closed-form arithmetic for `dict(keys(i)) = iter+i; sum += iter+i` patterns
- **DictFastGet**: 49× slower → **5.2× faster** than GDScript (~285× improvement)
- **DictFastSet**: 227× slower → **2.2× faster** than GDScript (~613× improvement)

### Added - VM needs_var_sync fast-path
- Scripts without `Whenever` sections skip HashMap sync on every opcode
- Locals accessed directly via indexed array instead of Dictionary lookup

### Added - Bytecode Peephole Optimizer
- **9-pass optimizer** in `visual_gasic_optimizer.h/.cpp` (~600 lines)
- **Constant folding**: `CONST a; CONST b; ADD` → `CONST (a+b)` for numeric and string ops
- **Dead pop elimination**: `PUSH x; POP` sequences removed
- **Redundant load/store**: `GET_LOCAL x; POP` and `GET_GLOBAL x; POP` eliminated
- **Dead code elimination**: unreachable bytes after `JUMP`/`RETURN` stripped
- **Jump threading**: `JUMP → JUMP` chains shortened (up to 10 hops)
- **Identity operations**: `+0`, `-0`, `*1`, `/1` eliminated
- **Double negation**: `NOT NOT` and `NEGATE NEGATE` removed
- **Strength reduction**: `x * -1` → `NEGATE`
- **Debug line stripping**: `OP_DEBUG_LINE` removal for release builds
- Fixed-point iteration (max 8 passes), NOP-based patching with jump-aware compaction
- Integrated into `VisualGasicScript::get_bytecode_for()` — runs automatically after compilation

### Added - Static Analysis & Linting
- **6 warning types** in `visual_gasic_linter.h/.cpp` (~530 lines)
- `WARN_UNUSED_VARIABLE` (100), `WARN_UNUSED_SUB` (101), `WARN_EMPTY_SUB` (102)
- `WARN_SHADOWED_VARIABLE` (103), `WARN_UNREACHABLE_CODE` (104), `WARN_UNUSED_PARAMETER` (106)
- 3-phase analysis: collect definitions → collect references → run checks
- Full AST walk: classes, properties, lambdas, Whenever sections, ForEach
- Integrated into Godot's `_validate()` pipeline for real-time warnings in editor
- Skips Godot callbacks (`_Ready`, `_Process`, `_Draw`, etc.) to avoid false positives

### Added - Snippet Browser UI
- **3-pane dialog** accessible via `Project > Tools > VG: Snippet Browser`
- 32+ built-in snippets from VGSnippetManager (categories, triggers, descriptions)
- Real-time search filtering by name and description
- Custom snippet creation with `${1:placeholder}` tab-stop support
- Insert at caret position in current `.vg` editor

### Added - Theme Picker UI
- **2-pane dialog** accessible via `Project > Tools > VG: Theme Picker`
- 5 built-in themes: VB6 Classic, Dark Modern, Monokai, Solarized, High Contrast
- Live preview with 40+ line VG code sample
- Auto-apply: themes automatically applied when opening `.vg` files
- Connected to VGThemeManager for persistence

### Added - Class Inheritance (Runtime)
- **`Inherits`** keyword for single inheritance between classes
- **`MyBase.Method()`** for calling parent methods
- **`Overrides`** keyword for method overriding with dispatch
- **`MustOverride`** for abstract method declarations
- Multi-level inheritance chains (3+ levels, e.g. Entity → Tower → Blaster)
- Property inheritance with override support
- 22/22 inheritance tests passing

### Added - Galactic Defender Game Demo
- **~1,600 line** tower defense game in `demos/2D_Games/Galactic_Defender/`
- 13 classes with 3-level inheritance chains
- 7 Whenever sections, 4 Lambdas, Parallel For, Dictionary stats
- DATA/READ wave definitions (12 waves + boss battles)
- Full software renderer with `_Draw()` — towers, enemies, projectiles, particles, HUD
- Standalone playable project (960×640)

### Changed
- Plugin now wires VGSnippetManager and VGThemeManager into tool menu
- Optimizer logs transformations when optimizations occur
- README updated to v2.4.1 with new features documented

## [2.4.0] - 2026-02-12

### Added - Classes & Objects
- **`Class...End Class`**: Full VB6/VB.NET-style class definitions with members, methods, and events
- **`Property Get/Let/Set`**: Accessor properties with parameters and bodies
- **`New` Keyword**: `Dim obj = New ClassName` instantiates class instances with unique object IDs
- **`Class_Initialize`**: Constructor-style initialization method runs on `New`
- **`Class_Terminate`**: Destructor method (scaffolding)
- **Inheritance Keyword**: `Inherits BaseClass` syntax parsed (runtime pending)
- **Member Visibility**: `Public`/`Private` member and method declarations
- **Independent Instances**: Each `New` creates a separate object with its own state

### Added - Functional Programming Builtins
- **`Map(array, lambda)`**: Transform each element — `Map([1,2,3], Fn(x) x*2)` → `[2,4,6]`
- **`Filter(array, lambda)`**: Keep matching elements — `Filter([1,2,3,4], Fn(x) x>2)` → `[3,4]`
- **`Reduce(array, lambda [, init])`**: Fold to single value — `Reduce([1,2,3], Fn(a,b) a+b, 0)` → `6`
- **`Any(array, lambda)`**: Check if any element matches — `Any([1,2,3], Fn(x) x>2)` → `True`
- **`All(array, lambda)`**: Check if all elements match — `All([2,4,6], Fn(x) x Mod 2 = 0)` → `True`
- **`Find(array, lambda)`**: First matching element — `Find([1,2,3], Fn(x) x>1)` → `2`

### Added - Block Lambda (Multi-Statement) Support
- **Block `Function` Lambdas**: Multi-line lambda bodies with `Return` keyword
- **Block `Sub` Lambdas**: Multi-line statement lambdas invocable via `Call` or direct invocation
- **`invoke_lambda()`**: Consolidated lambda invocation with synthetic `SubDefinition` context
- **`Return` in Lambdas**: Block lambdas use `Return value` to return values (VB-style function-name assignment not required)

### Fixed - Runtime
- **Block Lambda Return Values**: `STMT_RETURN` now correctly captures return values in lambda context via synthetic `current_sub`
- **STMT_CALL Lambda Invocation**: `greet("Alice")` now works when `greet` is a lambda variable
- **Builtin Dispatch from Interpreter**: `call_builtin_expr_evaluated()` now called from interpreter's `CallExpression` handler (was only called from bytecode VM)
- **Parameter Keyword Names**: Parser now accepts keywords like `value`, `get`, `let` as parameter names

### Added - Tests
- `demo/test_block_lambda.vg`: 6 tests for block lambdas, Sub lambdas, IIf short-circuit
- `demo/test_functional.vg`: 11 tests for Map/Filter/Reduce/Any/All/Find with arrow and block lambdas
- `demo/test_classes.vg`: 7 tests for class members, methods, instances, initialize, state mutation

## [2.3.3] - 2026-02-11

### Added - Lambda Syntax Improvements
- **`Fn` Keyword**: Short-form lambda keyword — `Fn(x) x * 2`
- **`Function` Without Arrow**: VB.NET-style lambdas — `Function(x) x * 3`
- **`Sub` Lambdas**: Statement lambdas — `Sub(x) Print x`
- **Optional `=>`**: Arrow is now optional for all lambda keywords
- **Formatter Auto-Replace**: `Lambda(x) => expr` automatically normalized to `Function(x) expr`

### Added - 8 Lambda Syntax Tests
- `demo/test_lambda_syntax.vg`: Covers all 4 lambda forms, multi-param, mixed operators, combo with `??`

## [2.3.2] - 2026-02-10

### Added - Lambda Expressions & Erase Statement
- **Lambda Expressions**: Full runtime support — `Lambda(x) => x * 2` creates callable anonymous functions
- **Lambda Runtime**: Dictionary wrapper with `__vg_lambda` marker, `__vg_params`, `__vg_ast_ptr`
- **Lambda Invocation**: Save/restore variable scoping for proper execution
- **`Erase` Statement**: Clear/reset arrays to default values — `Erase myArray`

### Added - Null Safety Operators
- **Null-Coalescing `??`**: `value ?? "default"` — returns left if not null, else right
- **Null-Safe Navigation `?.`**: `obj?.Property?.Value` — returns null instead of error if base is null

## [2.3.1] - 2026-02-09

### Added - Modern Language Features
- **String Interpolation**: `$"Hello {name}"` with expression support
- **Range Operator**: `1..10` creates array of integers
- **Array Literals**: `[1, 2, 3]` inline array creation
- **Dictionary Literals**: `{"key": value}` inline dictionary creation
- **Using Statement**: `Using f = Open(...) ... End Using` for resource management

## [2.3.0] - 2026-02-09

### Added - Comprehensive Test Infrastructure
- **Performance Test Suite** (`test_performance.vg`): Loop 1M iterations, string concat 1K, array 1K, dictionary 1K, Fibonacci(20) recursion, Factorial(12)
- **Regression Test Suite** (`test_regression.vg`): 28 automated tests covering arithmetic (7), strings (10), control flow (5), functions (4), error handling (1), file I/O (1)
- **Test Checklist** (`VG_TEST_CHECKLIST.md`): Comprehensive 9-section checklist with 264 test items, 251 passing (95.1% completion), 243+ automated tests

### Added - Editor Plugin Features
- **VG IntelliSense Provider**: Full code completion with 70+ keywords, 80+ functions, Godot types, snippet templates
- **VG Go To Definition**: Navigate to Sub/Function/Variable/Class definitions across .vg files
- **VG Linter**: Static analysis - unused variables, missing End statements, deprecated syntax, empty blocks, implicit variants
- **VG Snippet Manager**: 30+ code templates with tab stops and categories (Control Flow, Loops, Procedures, etc.)
- **VG Theme Manager**: 5 built-in themes (VB6 Classic, Modern Dark/Light, High Contrast, Solarized Dark)
- **VG Code Formatter**: Auto-indent, keyword capitalization, operator spacing, format on save
- **VG Recent Projects**: Track and quickly access recent .vg/.vbp projects with pin support

### Added - Language Features
- **Write # Statement**: Full VB6-compatible `Write #` for comma-delimited output with quoted strings
- **Error Code Standardization**: `raise_error()` now passes source parameter through all error paths

### Fixed - Critical Bugs
- **For Loop Safety Limit**: Increased from 1,000 to 10,000,000 — loops were silently capping at 1K iterations
- **Recursive Function Variable Scoping**: Functions now properly save/restore local variables (Dim'd vars, For loop vars, parameters, return var) using DimScanner — fixes corruption in recursive calls like Fibonacci
- **EOF Off-by-One Error**: Changed from `eof_reached()` to `get_position() >= get_length()` — fixes premature EOF detection
- **Array Bounds Error Code**: Now correctly raises error code 9 (Subscript out of range) instead of generic error
- **File Not Found Error Code**: Now correctly raises error code 53 instead of generic error
- **Error Source Passthrough**: `raise_error()` properly propagates source parameter in all 3 code paths

### Changed
- Minimum For loop safety limit now 10,000,000 (was 1,000)
- DimScanner-based selective save/restore for function calls (efficient variable isolation)

## [2.2.4] - 2026-02-08

### Added - Game-Specific Keywords (Section 4.2 Complete)
- **Whenever Event System**: Reactive programming with `Whenever Section Changes(var)` and `Whenever Section Exceeds(var, threshold)`
- **Whenever Control**: `Suspend Whenever`, `Resume Whenever`, `ActiveWheneverCount()`, `WheneverStatus()`
- **Sprite Support**: `CreateNode("Sprite2D")`, `CreateNode("AnimatedSprite2D")`
- **Sound Support**: `CreateNode("AudioStreamPlayer")`, `PlaySound()`
- **Collision Detection**: `HasCollided()`, `CreateTrigger()`, `GetCollisionCount()`
- **Keyboard Input**: `IsKeyDown()`, `Inkey()`, all `KEY_*` constants
- **Mouse Input**: `IsMouseButtonDown()`, `GetMouseX()`, `GetMouseY()`, `MouseClick()`

### Added - Godot Integration (Section 4.1 Complete)
- Full `Input` singleton access: `Input.IsActionPressed()`, `Input.IsActionJustPressed()`, `Input.IsKeyPressed()`, `Input.GetMousePosition()`
- Verified: `Me.name`, `Me.position`, `Me.visible`, `Me.modulate` property access
- Verified: `Me.get_class()`, `Me.has_method()`, `Me.queue_redraw()` method calls
- Verified: `GetNode()`, `Connect()`, `_Process()`, `_Ready()`, `GetDelta()`

### Fixed
- Module-level `Whenever Section` declarations now register correctly during initialization
- `Dim` statements with initializers now execute at module level (e.g., `Dim x As Integer = 5`)
- Case-insensitive variable comparison in Whenever condition checking
- Bytecode `read_local` now re-syncs with `variables` dictionary for proper callback behavior

## [2.2.3] - 2026-02-07

### Added - VB6-Style Control Property Access
- Direct control manipulation: `txtTest.Text = "Hello"`, `lblStatus.Caption = "Ready"`
- VB6 property aliasing: Text, Caption, Visible, Enabled, Left, Top, Width, Height, Value

### Fixed
- `OP_GET_LOCAL` now searches for child controls when local slot is NIL
- `OP_GET_GLOBAL` also searches for child controls when variable not found

## [2.2.1] - 2026-02-05

### Added - Native Compiler Enhancements
- **Select Case Statement**: Full bytecode compilation with multi-value case matching (`Case 1, 2, 3`)
- **Do Loop Statement**: Complete Do While/Until with pre/post conditions
- **Return Statement**: Optional return value support for functions
- **Restore Statement**: DATA pointer manipulation for Read/Data operations
- **IIf Expression**: Ternary operator compilation (`IIf(condition, trueVal, falseVal)`)
- **New Binary Operators**: `Is` (object comparison), `Mod`, `Like` (pattern matching), `\\` (integer division)
- **New Opcodes**: `OP_JUMP_IF_TRUE`, `OP_RESTORE_DATA`, `OP_MOD`, `OP_INT_DIVIDE`, `OP_LIKE`

### Added - Editor Plugin Enhancements
- **VG IntelliSense Provider**: Full code completion with 70+ keywords, 80+ functions, Godot types
- **VG Go To Definition**: Navigate to Sub, Function, Variable declarations across .vg files
- **VG Linter**: Static analysis for unused variables, missing End statements, deprecated syntax
- **VG Snippet Manager**: 30+ code templates with tab stops (if, for, sub, class, etc.)
- **VG Theme Manager**: 5 built-in themes (VB6 Classic, Modern Dark/Light, High Contrast, Solarized)
- **VG Recent Projects**: Track and quickly access recent .vg/.vbp projects

### Fixed
- Unsupported statement type errors for Select Case, Do Loop, Return, Restore
- Unsupported binary operator "Is" causing compilation failures
- Expression type 25 (IIf) not recognized by compiler

## [2.2.0] - 2026-02-05

### Added
- **Components Dialog**: VB6-style dialog for managing optional and custom controls (Project > Visual Gasic Components...)
- **12 New Toolbox Controls**: ProgressBar, HSlider, VSlider, SpinBox, Shape, HLine, VLine, RichText, TabStrip, Files, and more
- **10 Optional Components**: StatusBar, Toolbar, Animation, Calendar, DatePicker, MaskedEdit, Winsock, UpDown, ListView, ImageCombo
- **Functional Calendar Control**: Full month/date picker with configurable properties and events
- **2D Game Controls**: Sprite, AnimatedSprite, Tilemap, RigidBody, CharacterBody, Area, Camera
- **3D Game Controls**: MeshInstance, RigidBody3D, CharacterBody3D, Camera3D, lights, WorldEnvironment, CSGBox
- **VB6 MsgBox Constants**: Full support for button constants (vbOKOnly, vbYesNo, etc.) and icon constants (vbCritical, vbQuestion, etc.)
- **Custom Control Support**: Browse and add your own .tscn prototypes to the Toolbox
- **VB6-Style Properties Panel**: Enhanced inspector with BackColor, ForeColor, Caption, TabIndex, etc.
- **Controls Reference Documentation**: Complete guide to all 40+ toolbox controls

### Changed
- **New Form Dialog**: Resized for better usability, shows 5-6 templates at once
- **Toolbox Organization**: Controls now properly categorized (Standard, Extended, 2D Game, 3D Game, Optional)
- **Components Persistence**: Custom components saved to `custom_components.cfg`

### Fixed
- ProgressBar icon not displaying correctly in toolbox
- VScrollBar default size too small
- Dock panels not resizing properly (removed forced minimum sizes)

## [2.1.0] - 2026-02-03

### Added
- **Vector Math Builtins**: `Vec2`, `Vec3`, `VAdd`, `VSub`, `VMul`, `VDot`, `VCross`, `VLen`, `VNormalize`, `VDistance`, `VLerp`
- **Utility Functions**: `SetProp`, `AddChild`
- **IntelliSense/Autocomplete**: Full code completion with 50+ keywords, 80+ functions, code snippets
- **Go to Definition**: Navigate to function/variable declarations
- **Find All References**: Search for all usages of a symbol
- **Code Formatter**: Auto-format VG code with configurable style
- **Code Linter**: Real-time syntax and style checking
- **Snippet Manager**: Insert common code patterns
- **Theme Manager**: Customizable editor themes
- **Watch Window**: Color-coded value changes, persistence, context menu
- **Snap-to-Grid**: Form designer grid snapping with alignment toolbar
- **Conditional Breakpoints**: Break on condition, hit count, log messages
- **Call Stack Panel**: Visual call stack during debugging
- **Recent Projects List**: Quick access to recent VG projects
- **Form Preview Toolbar**: Preview forms without running
- **Extended Form Templates**: VB6 Classic, Game Forms, Platform-specific, Custom templates
- **Login Form Template**: Pre-built authentication form

### Fixed
- Login Form creation crash (reserved keyword `pass` → `passwd`)
- Form controls not appearing (owner assignment timing)
- GDScript `match` keyword conflict in `vg_formatter.gd`
- `RegEx.sub()` Callable issue in `vg_snippet_manager.gd`

### Changed
- Merged all debugging features into main branch
- Reorganized documentation structure (`docs/reference/`, `docs/guides/`, etc.)
- Updated `.gitignore` to exclude binary files

## [2.0.0] - 2026-01-22

### Added
- **Debugging Support**: Breakpoints, step-through, variable inspection
- **Immediate Window**: REPL for testing expressions
- **Expression Evaluation**: Evaluate VG expressions at breakpoints
- **Data Breakpoints**: Break when variable values change
- **Phase 3 Debug Integration**: Full Godot debugger integration

### Changed
- Migrated from `.bas` files to `.vg` extension
- Updated parser for improved error messages

## [1.5.0] - 2026-01-15

### Added
- **Form Designer**: Visual form builder with drag-and-drop
- **Control Toolbox**: Button, Label, LineEdit, CheckBox, etc.
- **Property Inspector**: Edit control properties visually
- **WinForms-style API**: `Form`, `Me`, event handlers

## [1.0.0] - 2026-01-01

### Added
- Initial release of Visual Gasic
- VB6-compatible syntax parser
- Godot 4.x GDExtension integration
- 80+ built-in functions
- String, Math, Array, Dictionary operations
- File I/O support
- JSON parsing
- Basic error handling

---

## Legend

- **Added**: New features
- **Changed**: Changes to existing functionality
- **Deprecated**: Features to be removed in future
- **Removed**: Features removed in this release
- **Fixed**: Bug fixes
- **Security**: Security-related changes
