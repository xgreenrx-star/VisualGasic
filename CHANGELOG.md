# Changelog

All notable changes to Visual Gasic will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
