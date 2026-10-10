# VisualGasic 5.7.0 Beta 1

This is a substantial update to VisualGasic, the BASIC-style scripting language
for Godot. It includes fixes to the language runtime, more reliable editor
behavior, better sprite editing, improved Python integration, and a new playable
example: **Crystal Caverns**.

Much of the work happened below the surface. We compared the two execution
paths, tested malformed programs, followed up crashes, and fixed bugs exposed
by real examples. The goal is simple: code should behave the same way whether
it runs through the interpreter or the compiler.

**Status: public beta.** This is not the final v6 stable release. Back up your
projects before upgrading and please report anything that still goes wrong.

## Downloads

Use **Godot 4.6.1** for the baseline setup. Godot 4.7.2 has also been tested on
Linux; that does not certify every platform, renderer, or export combination.

| What you need | Download |
| --- | --- |
| Add VisualGasic to an existing Godot project | [Asset Library addon ZIP](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.1/VisualGasic_AssetLibrary_v5.7.0-beta.1.zip) |
| Linux x86-64 setup | [AppImage installer](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.1/VisualGasic-Installer-v5.7.0-beta.1-x86_64.AppImage) |
| Windows x64 setup | [Windows installer](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.1/VisualGasic-Installer-v5.7.0-beta.1-x86_64.exe) |
| Mac setup, Intel and Apple Silicon | [macOS setup ZIP](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.1/VisualGasic-Installer-v5.7.0-beta.1-macos-universal.zip) |
| Linux setup with Godot included | [Linux offline bundle](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.1/VisualGasic-Installer-Offline-v5.7.0-beta.1-linux-x86_64.zip) |
| Windows setup with Godot included | [Windows offline bundle](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.1/VisualGasic-Installer-Offline-v5.7.0-beta.1-windows-x86_64.zip) |
| Mac setup with Godot included | [macOS offline bundle](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.1/VisualGasic-Installer-Offline-v5.7.0-beta.1-macos-universal.zip) |
| Games, teaching examples, and documentation | [Examples and docs ZIP](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.1/VisualGasic-Examples-and-Docs-v5.7.0-beta.1.zip) |

[All downloads and platform binaries](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.7.0-beta.1)
include editor, debug-export, and release-export builds for Linux, Windows,
and universal macOS, plus debug/release Web binaries.
[SHA256 checksums](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.1/SHA256SUMS)
and the build commit are supplied with the downloads.

The Mac setup is an **unsigned command launcher**, not a notarized DMG.
It needs Python 3; Control-click the launcher and choose Open if macOS prompts.
Linux setup needs Python 3 and Tkinter for the graphical wizard. Optional AI
companions require separate downloads. An offline bundle includes Godot and VG,
not those optional services.

The Asset Library ZIP is ready for submission. Updating the store listing and
moderator approval are separate from publishing these GitHub downloads.

## A better way to work with DATA sprites

Sprites can live directly in your BASIC source. A short `DATA` header describes
the size, transparent color, and palette; the remaining rows are a grid of
pixel-color numbers.

You can edit that grid by hand, or paint in the integrated Sprite Editor and
write the result back to the same DATA block. **The artwork is part of the
source, rather than a separate image you have to keep in sync.**

This release makes that workflow easier to use:

- Sprite thumbnails and enlarged previews work across the labeled sprite blocks.
- The sprite list helps you find a sprite and jump to its source.
- Header help explains what those first four numbers mean.
- Grid alignment pads the values so pixel columns line up in the code editor.
- Edit in Sprite Editor opens the editor where you can actually see it.
- New Sprite uses a bounded dialog instead of a window that runs off the screen.
- DATA blocks start folded under the default editor policy. Expand/collapse and
  relative indentation work without unexpectedly opening the Sprite Editor.
- Context updates no longer pull you away from a Help tab you deliberately chose.
- **Fix Indentation no longer corrupts folded code.** It changes only leading
  whitespace, preserves Undo, and recognizes inline Whenever declarations,
  comments, mixed-case keywords, and selected-block context.

The Vector/DATA panels share the relevant help, context, and contrast fixes.
The experimental full Vector Editor routing is not being presented as finished.

## Crystal Caverns: a complete example you can read and change

Crystal Caverns is an original Boulder Dash-inspired digging game with three
authored caves. Collect six crystals, push rocks, watch what falls, and reach
the unlocked exit before time runs out.

Its twelve pixel-art sprites and cave layouts are DATA statements.
Six `Whenever` declarations handle counters, exit unlocks, warning thresholds,
and defeat. That makes it a useful example of reactive BASIC code, not just
a screenshot.

The game includes pause, restart, cave progression, and fullscreen. F8 turns
visual effects on or off; F9 controls sound independently.

Seven original shaders add the miner's swirl entrance, a completion wave and
sink, DATA-colored death fragments, an exit vortex, rock wobble, crystal glow,
and a subtle CRT treatment. All game-specific CPU scripting is `.vg`; the GPU
programs remain standard Godot shader files.

Ten original sound effects are synthesized from DATA recipes. Beginner-oriented
comments explain the game rules, sprite headers, shader control, and audio code.
This version also includes the maintainer's latest first-cave starting position
and sprite edits.

[Crystal Caverns guide and source](https://github.com/xgreenrx-star/VisualGasic/tree/v5.7.0-beta.1/samples/showcases/crystal_caverns)

## Core language fixes

This is not just an editor or sample update. New native binaries are required.

- **Tween, enums, and typed collections:** filled execution-path gaps so supported
  operations no longer depend on accidentally taking the interpreter path.
- **ByRef:** repaired updates through multidimensional arrays, imported helpers,
  and expression-level calls. A helper's changes should reach the caller.
- **Await:** ordinary procedures can suspend and resume without replaying earlier
  statements, blocking the game loop, or overwriting unrelated live state.
  Tests exercise overlapping calls, signals, locals, loops, and error handlers.
- **Dictionaries:** fixed initialization, per-call storage, recursion, and state
  held across Await. Finished calls release resource-owning dictionaries.
- **Error handling:** repaired Resume Next recovery, Err.Clear, handler state,
  and optimization around error paths.
- **Control flow and values:** fixed loop exits, string iteration, array helpers,
  Empty/Nothing arithmetic behavior, method chains, and property aliases.
- **DATA loading:** fixed DataFromString and related expression/lifetime handling.
- **Native arithmetic/JIT:** fixed constant-operand lowering, register/spill safety,
  and floating/String-returning helper behavior exposed by checksum tests.
- **Recursion and parsing:** reduced excessive VM stack use and rejected nested
  procedure declarations before malformed source could become recursive code.
- **Godot calls:** corrected native input/property dispatch, child method ownership,
  GetDelta handling, and optimized canvas command counts.
- **Files and sockets:** made wildcard deletion behavior consistent and bounded
  connection waiting, with local regression tests for failure paths.

These changes do not remove every interpreter/compiler difference. Known
remaining limitations are listed below rather than hidden by the samples.

## Editor reliability and UI improvements

- Fixed a native reload deadlock seen during cold editor imports.
- Improved cleanup of debugger, live-preview, popup, dock, and optional music
  resources when the plugin or scene shuts down.
- Fixed unreadable combinations of light backgrounds and light text in the
  assist and floating panels.
- Typing no longer triggers a repeated refresh dialog when two editors hold
  different buffers. A nonmodal warning and explicit Refresh preserve your choice.
- Help/Sprite panel ownership is more predictable while navigating and editing.
- The source dropdown lists sprite blocks and `Whenever` declarations.

Godot's own Script workspace remains the main editing path. Experimental UI
Forms and the legacy full-screen IDE/Form Designer remain opt-in Alpha features.

## Python, AI assistance, and platform work

- Fixed Windows worker-pipe reads and Windows DLL initialization problems.
- Improved portability of the test runner and native Mac architecture builds.
- Python bridge tests cover typed values, integer ranges, large arrays, and Await
  on Windows and macOS as well as Linux.
- Narcea can use custom OpenAI-compatible, Anthropic-compatible, and Ollama
  endpoints, with configurable model IDs and connection tests.
- Provider definitions and credentials stay separate; refreshed documentation
  explains setup and key storage.
- Release packaging now builds all desktop targets, Web binaries, installers,
  offline bundles, and the Asset Library archive from the candidate revision.
- Linux release builds use an older glibc baseline for wider compatibility.
  Desktop music libraries are rebuilt with the existing shutdown-lifetime fix.

## More useful examples and more honest tests

The teaching corpus now has **80 audited examples**, including 22 newly added
examples covering language features, storage, engine APIs, and local interop.
Restored sample projects and the updated command-reference coverage make it
easier to find a working starting point.

The bug campaign also strengthened the tests themselves. Aborted programs,
timeouts, missing assertions, incorrect benchmark checksums, and incomplete runs
can no longer quietly count as passes. Differential tests compare execution
paths; mutations deliberately feed malformed source; lifecycle tests check
cleanup instead of stopping at successful startup.

For the latest edited Crystal Caverns source, local Linux checks pass in default
and forced-AST modes: **81/89 gameplay checks** in headless/graphical runs,
**278/303 visual-effects checks**, **95 sound checks**, and **190 editor checks**.
Earlier full-workspace probes passed 118 checks on both tested Godot versions.
Audio tests capture actual mixer output, not physical speaker playback.

[Testing and release evidence](https://github.com/xgreenrx-star/VisualGasic/blob/v5.7.0-beta.1/docs/release/RELEASE_PROCESS.md)
explains exact scopes, exclusions, and outstanding manual checks.

## Performance: correctness comes first

The moving-rectangle optimization now recognizes scaled integer coordinates,
and benchmark checks require matching output and frame counts.
The published Linux report includes both faster and slower results.
Those are measurements of particular workloads, **not whole-game FPS promises**
or Windows/Mac benchmark claims.

[Bug campaign and benchmark report](https://github.com/xgreenrx-star/VisualGasic/blob/v5.7.0-beta.1/docs/benchmarks/BUG_CAMPAIGN_OCT2026.md)

## Upgrading and known limitations

1. Back up your project and save any open script buffers.
2. Close Godot before replacing native extension files.
3. Replace the entire `addons/visual_gasic` folder with the new package.
   Do not mix old binaries with the new editor scripts.
4. Open the project, let imports finish, and enable VisualGasic under Plugins.

This beta does **not** certify all clean-machine installs, upgrades, exports,
renderers, or interactive workflows. Mac setup is unsigned; manual listening
and cross-platform Crystal Caverns playtests still need feedback.

The release investigation retains an independently reproduced Godot
documentation-worker shutdown crash and intermittent cold font-import
corruption. They are not claimed fixed. Newly isolated conditional-clamp,
AST Vector2 division, and packed-array method-dispatch differences also remain
open; the showcase uses verified supported operations instead.
Advanced async contexts outside documented ordinary-procedure support remain
out of scope.

[Godot compatibility and crash investigation](https://github.com/xgreenrx-star/VisualGasic/blob/v5.7.0-beta.1/docs/compatibility/GODOT_4_7_2.md)
and [experimental IDE status](https://github.com/xgreenrx-star/VisualGasic/blob/v5.7.0-beta.1/docs/manual/VG_IDE_ALPHA.md)
provide the details.

## Documentation and videos

- [Documentation hub](https://github.com/xgreenrx-star/VisualGasic/blob/v5.7.0-beta.1/docs/DOCS.md)
- [Installation guide](https://github.com/xgreenrx-star/VisualGasic/blob/v5.7.0-beta.1/docs/guides/INSTALLATION.md)
- [Language reference](https://github.com/xgreenrx-star/VisualGasic/blob/v5.7.0-beta.1/docs/VisualGasic_Language_Reference.md)
- [Examples and showcases](https://github.com/xgreenrx-star/VisualGasic/blob/v5.7.0-beta.1/samples/README.md)
- [Performance guide](https://github.com/xgreenrx-star/VisualGasic/blob/v5.7.0-beta.1/docs/manual/performance.md)
- [Video: VisualGasic beta feature tour](https://youtu.be/FUw8zgbn_tU)
- [Video: Vector Crypt procedural 3D showcase](https://youtu.be/ntpOTNflE_M)

The videos show earlier feature demonstrations; they are not a recording of
this release or a Crystal Caverns trailer.

Found a problem? [Open an issue](https://github.com/xgreenrx-star/VisualGasic/issues)
with your Godot version, OS, a small example, and the error or steps to reproduce.
