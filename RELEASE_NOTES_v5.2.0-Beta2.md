# VisualGasic v5.2.0-Beta2 — Release Notes

**Released:** May 18 2026  
**Status:** Public beta (Linux x86_64 + Windows x64)  
**Codename:** *The One That Actually Launched Godot*

This is the second beta on the 5.2 line. It is a significant drop — 69
commits in 7 days — covering a complete browser-based dashboard, full-duplex
realtime voice, a reworked Working Nodes editor, smarter Make EXE, AGCK
template expansion, and a pile of bug fixes and polish.

Performance numbers are unchanged from Beta1: VG is still **2–92× faster
than GDScript** on the published microbenchmarks.

> 🍏 **macOS:** unchanged from Beta1 — Linux + Windows only for 5.2.
> Open an issue if you need a macOS build.

---

## ⚠️ Known issues

- **VGMusic (Bosca Ceoil) requires a restart to work.** When the VGMusic
  plugin is first loaded inside a project, the Bosca editor tab may appear
  blank. **Workaround: close VisualGasic and reopen it — Bosca works
  correctly on the second launch.** This is a Godot 4.6.1 plugin
  initialization order issue and is being investigated.
  If you can reproduce it (or can't), please report in the issue tracker.

---

## 🌐 Browser Dashboard (new)

A built-in lightweight HTTP server now serves a browser-based project
dashboard. Start it from the `vg-dashboard` launcher or let it autostart
in the background.

- **Phase 1–2** — embedded HTTP server, POST endpoint with CSRF token,
  settings persistence, build runner.
- **Phase 3** — live streaming build logs (server-sent events).
- **Phase 4** — read-only project file explorer.
- **Phase 5** — multi-project switcher.
- **Phase 5b** — headless launcher: open a VG project from the browser tab
  without an open IDE window.
- **Phase 5c** — system tray icon mode (`vg-dashboard-tray`): dashboard
  runs silently in the tray and can be opened on demand.

> This is a preview. The dashboard requires the VG server process to be
> running; there is no authentication beyond the CSRF token, so keep it
> on localhost.

---

## 🎙️ Realtime Voice (Tier 2.5)

Voice interaction is now full-duplex, not just push-to-talk transcription.

- **Phase 2.5b** — VAD (voice activity detection): recording stops
  automatically after a pause in speech — no button release required.
- **Phase 2.5c** — streaming TTS with sentence queue: the AI response
  is spoken as it is generated, sentence by sentence.
- **Phase 2.5d** — **full-duplex realtime voice** via OpenAI Realtime API
  and Google Gemini Live. Interrupt the AI mid-sentence; it hears you.

> Requires an API key for OpenAI or Gemini. Local Ollama voice is still
> push-to-talk only.

---

## 🔗 Working Nodes — overhauled

Working Nodes received the most attention this beta:

- **Collapsible left panel** — the node-type browser can be hidden to give
  the canvas more space.
- **Decluttered toolbar** — redundant buttons removed; Export and Run
  consolidated into MenuButtons.
- **Get Property output port** — the Get Property node now has an output
  port so you can wire its value directly into another node.
- **Value ports (orange Math sockets)** — math/value ports are visually
  distinct from control-flow ports; code generation resolves wire values
  correctly.
- **Scene-node and property pickers** — Set/Get Property nodes show a
  dropdown of nodes and properties from the current scene, with a "no scene"
  fallback hint.
- **Quick-add buttons** — common node types are one click away on the
  canvas toolbar.
- **Merge "On Input" nodes** — separate On Input nodes are merged into a
  single `Sub Form_KeyDown` event, matching the rest of the VG event model.
- **Invisible-caret fix** — the text caret in node labels was invisible on
  dark themes.
- **Popup styling** — context menus and OptionButton dropdowns now use
  readable colours.
- **Settings popup** exclusive-window crash fixed.
- **Code-mode simplification** — node-type and export toolbar rows 2–4
  are hidden when you are in code-only mode.

---

## 🤖 AI Pair — improvements

- **Two-row toolbar** — the AI Pair toolbar no longer overflows off-screen
  on narrower IDE windows.
- **Streaming performance pass** — lower latency between tokens; the panel
  no longer freezes during long responses.
- **Cross-plugin tools** — Narcea can now read and write Working Nodes
  graphs, AGCK templates, Forms, 2D scenes, and 3D scenes from a single
  conversation.
- **IDE self-modification** — Narcea can propose patches to VG's own addon
  scripts; a backup is created before any change is applied.
- **Claude HTTP 400 fix** — `max_tokens` is now coerced to `int` after
  JSON re-parsing to prevent a type error that caused every Claude call to
  fail on re-open.
- **Real error messages** — the error response body is read and shown in
  full instead of a generic HTTP error code.
- **Persona whitelists, prompt doc fixes, reload + restore gaps** fixed.
- **VGMusic tools** — Narcea can query and modify Bosca patterns via the
  plugin tool interface.

---

## 🏗️ AGCK — game template expansion

- **Phase 4** — behavior `.vg` files with `{{TOKEN}}` substitution:
  each AGCK actor can have its own behaviour script with typed placeholder
  tokens replaced at runtime.
- **Save/Load Template** — AGCK configurations can be saved as reusable
  `.agck` template files.
- **Top-Down RPG template** fleshed out: 3-room dungeon crawl with enemies,
  doors, and a chest.
- **Endless Runner template** fleshed out: 3-level coin chase with
  obstacles and a score.

---

## 📦 Make EXE — smarter export

- **Platform picker** — choose Linux, Windows, or Web without editing
  project settings.
- **Missing template check** — if export templates are not installed, VG
  shows a prompt with a direct download link.
- **Template install progress** — a progress bar and "Show in Files"
  button appear while templates download.
- **Web export validation** — the HTML5 export path is validated before
  attempting the export.
- **Dialog polish** — result dialog height is clamped; duplicate
  `game_ui_mode` bindings removed.

---

## 🏁 First-run & installer

- **First-run wizard** — new 2-step mode picker (code / form / game /
  music) with optional plugin checkboxes. VG configures itself on first
  launch instead of starting blank.
- **Godot 4.6.1 auto-detect** — the installer detects whether Godot 4.6.1
  is present and offers to download it if not.
- **`vg new` auto-launch** — `vg new <project>` now opens Godot
  automatically after creating the project, without requiring a separate
  step.

---

## 🧩 MCP Server

- New `apply_diff` tool — external MCP clients (Cursor, Windsurf, etc.)
  can apply unified diffs to VG project files directly.
- VG's built-in tools (play, stop, read/write code, build) are exposed to
  any MCP-compatible client.

---

## 🛠️ Form Designer

- Promoted to a proper Godot **sub-plugin** — it is now loaded and
  unloaded independently, reducing editor startup time when the plugin is
  not active.
- **VB6 type name support** — form spec files now accept `TextBox`,
  `CommandButton`, `Label` (etc.) in addition to the internal VG names.
- **WN integration** — Form Designer controls are exposed to Working Nodes'
  node and property pickers.

---

## � Documentation & manuals

All docs live in the repo and are kept up to date with the code.

| Document | What it covers |
|---|---|
| [Language Reference](docs/VisualGasic_Language_Reference.md) | Complete A–Z reference for every keyword, statement, function, and namespace verb — 350 entries with Purpose, Syntax, Parameters, Description, Example, See Also |
| [Documentation Index](docs/DOCUMENTATION_INDEX.md) | Navigable index of all docs, guides, and tutorials |
| [Getting Started — Installation](docs/getting_started/installation.md) | Install scripts, manual setup, `vg` CLI |
| [Getting Started — Introduction](docs/getting_started/introduction.md) | What VG is and why you'd use it |
| [Godot Programming Manual](docs/GODOT_PROGRAMMING_MANUAL.md) | Using Godot APIs from VG code |
| [Command Quick Reference](docs/reference/commands.md) | Concise control-flow + namespace wrappers table |
| [Godot Functions Reference](docs/reference/GODOT_FUNCTIONS_REFERENCE.md) | All Pass 1–6 namespace verbs with signatures |
| [Builtin Functions Reference](docs/reference/BUILTIN_FUNCTIONS_REFERENCE.md) | Print, Input, MsgBox, file I/O, math, etc. |
| [Controls Reference](docs/reference/CONTROLS_REFERENCE.md) | All 40+ toolbox controls and their IDE properties |
| [Migration Guide (VB6/VBA)](docs/guides/MIGRATION_GUIDE.md) | Moving existing VB6 or VBA code to VG |
| [Importing VB6 Projects](docs/guides/IMPORTING_VB6.md) | Using the VB6 → VG importer |
| [Form Designer Guide](docs/WINFORMS_FORM_GUIDE.md) | Designing forms in the IDE |
| [Immediate Window](docs/IMMEDIATE_WINDOW.md) | The REPL/debugger window |
| [Advanced Features Manual](docs/ADVANCED_FEATURES_MANUAL.md) | Multitasking, FFI, JIT, threading and more |
| [VG vs GDScript](docs/guides/VG_ADVANTAGES_OVER_GDSCRIPT.md) | 19 capabilities VG has that GDScript does not |

---

## �🐛 Bug fixes

- **SIGSEGV crash** creating a blank code-mode project — fixed.
- **Toolbox blank tabs** — wrapping `GridContainer`s in `ScrollContainer`
  fixed empty tab rendering and scrollbar styling.
- **GDScript parse errors** in several addon files — explicit types added
  for `calls`, `fenced`, `ok` variables.
- **WN picker crash** when no scene is loaded — shows a hint popup
  instead of crashing.
- **`get_editor_interface()` deprecation** — replaced with
  `EditorInterface` singleton across Working Nodes pickers.
- **plugin.cfg version** corrected from `5.0.1-beta` to `5.2.0-Beta1`.

---

## 📸 Screenshots

**VGMusic (Bosca Ceoil) — instrument selection**  
![VGMusic showing Bosca Ceoil with Guitar instrument picker open](docs/screenshots/Screenshot%20at%202026-05-18%2019-02-59.png)

> ⚠️ VGMusic requires a restart to show correctly on first load — see Known Issues above.

**AI Pair — Narcea building a Pong game live**  
![AI Pair panel showing Narcea generating a Pong game with the game running in the viewport](docs/screenshots/Screenshot%20at%202026-05-18%2019-13-22.png)

**AI Pair — code view + Narcea session**  
![Code editor with Narcea conversation and AI Pair toolbar](docs/screenshots/Screenshot%20at%202026-05-18%2019-13-02.png)

**Hex Editor**  
![Built-in hex editor showing binary file content with text view sidebar](docs/screenshots/Screenshot%20at%202026-05-18%2019-09-14.png)

**Form Designer — Game UI toolbox**  
![Form Designer showing the full Game UI toolbox with controls on the canvas](docs/screenshots/Screenshot%20at%202026-05-03%2020-41-10.png)

**Welcome shell — project launcher**  
![VisualGasic welcome shell with recent projects and Ask Narcea to Make a Project option](docs/screenshots/Screenshot%20at%202026-05-03%2020-38-10.png)

**AGCK — Working Nodes + AI Pair**  
![AGCK project with Working Nodes open and AI Pair panel at the bottom](docs/screenshots/Screenshot%20at%202026-05-01%2020-41-27.png)

**Web Publish plugin**  
![Web Publish plugin showing Form → HTML export with theme and layout options](docs/screenshots/Screenshot%20at%202026-04-29%2009-26-33.png)

---

## 🧪 Test suite

**700/700** VG assertions + **289/289** GDScript assertions, **0 failures**
on Linux x86_64 at time of tagging.

Verify locally:

```bash
bash run_test_suite.sh
```

---

## 📦 Downloads

| Platform | One-click installer | Portable zip | Offline bundle (Godot bundled) |
|---|---|---|---|
| 🐧 Linux x86_64 | `VisualGasic-Installer-v5.2.0-Beta2-x86_64.AppImage` | `VisualGasic_v5.2.0-Beta2_linux_x86_64.zip` | `VisualGasic-Installer-Offline-v5.2.0-Beta2-linux-x86_64.zip` |
| 🪟 Windows x64 | `VisualGasic-Installer-v5.2.0-Beta2-x86_64.exe` | `VisualGasic_v5.2.0-Beta2_windows_x86_64.zip` | `VisualGasic-Installer-Offline-v5.2.0-Beta2-windows-x86_64.zip` |
| 🍏 macOS | *not available for 5.2 — open an issue* | — | — |

The AppImage / .exe installers handle everything: they download Godot 4.6.1
if needed, install the addon, and register the `vg` CLI. The offline bundles
include a Godot 4.6.1 download so no internet is required after unpacking.

---

## 🐞 Known limitations (unchanged from Beta1)

- macOS builds are paused for the 5.2 line.
- The Android plugin is a **preview**: the three namespaces work in
  editor-side tests, but end-to-end APK signing still needs polish.
- `JS.*` web-export bindings are only meaningful when targeting HTML5 export.
- **VGMusic / Bosca Ceoil requires a restart** — see top of page.

---

## 🙏 Help needed

Beta2 has a lot of new surface area and I can only test on one machine
(Linux x86_64). If you can spare 10 minutes, here are the things most
likely to behave differently on your setup:

1. **VGMusic restart workaround** — does Bosca open correctly after a
   restart on your machine? Does the blank-tab happen every time or only
   sometimes? Any detail helps narrow it down.
2. **Browser Dashboard** — does `vg-dashboard` start on Windows? Does the
   tray icon appear? (It uses GTK on Linux and the Windows system tray API —
   both are new code paths.)
3. **Full-duplex voice** — if you have an OpenAI or Gemini API key, does
   the Realtime / Live connection establish? What happens when you interrupt
   mid-sentence?
4. **Make EXE on Windows** — does the platform picker work? Are the export
   template download links correct for your Godot version?
5. **First-run wizard** — if you install fresh on a machine without a
   `%APPDATA%/VisualGasic` config, does the 2-step wizard appear?

File issues at the issue tracker. If you just want to say "it worked" or
"it broke", a one-liner comment on the release page is very welcome too.

Thanks to everyone who tested Beta1 and filed reports.
