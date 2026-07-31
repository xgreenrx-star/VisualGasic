# VisualGasic 5.3.0-Beta3 — Facebook Release Message

Copy-paste ready. Pick the option that fits your page's tone.

---

## Option 1: Short & Catchy (Recommended for main announcement)

🚀 **VisualGasic 5.3.0-Beta3 is out!**

This release ships two brand-new hardware emulator demos — a full **Commodore 64** (6510 CPU, VIC-II, real KERNAL/BASIC ROMs) and a **Game Boy Advance** (ARM7TDMI) — built entirely in VisualGasic. Building them shook loose a whole chain of real interpreter bugs (a sneaky boot-time stack corruption bug that was silently eating the C64's startup banner!), plus cross-module bytecode compilation, a new buffer type, a `Global` keyword, and ~21-40% less call overhead.

777/777 tests passing. 54 corpus examples. Godot 4.6.1. Linux + Windows.

**Download:** https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.3.0-Beta3

Yes, it boots to a real "READY." prompt. 👀

#GameDev #Godot #VisualGasic #BASIC #OpenSource #IndieGames #RetroGaming

---

## Option 2: Technical Deep-Dive (For developer audiences)

🎯 **VisualGasic 5.3.0-Beta3 — C64/GBA Emulators, Cross-Module Bytecode, Buffer Type**

Highlights from this release:

✅ **Commodore 64 Emulator demo** — full 6510 CPU (151 opcodes), VIC-II graphics chip, CIA I/O, running the real KERNAL + BASIC V2 ROMs. Boots to the actual `**** COMMODORE 64 BASIC V2 ****` banner.

✅ **Game Boy Advance Emulator demo** — ARM7TDMI/Thumb core, with a fresh batch of decode and class-visibility bug fixes from real-ROM testing.

✅ **Cross-module bytecode compilation** — Subs/Functions in `Import`'d files now compile to bytecode instead of falling back to the slower AST interpreter.

✅ **Buffer Type + Optimizer Hints** — `Dim buf As New MemoryBuffer(N)` now uses 10 dedicated opcodes for direct `PackedByteArray` access.

✅ **`Global` keyword, cross-file class `Import`, `Exit While`** — three language additions closing real gaps.

✅ **~21-40% less call/hot-path overhead** measured via new micro-benchmarks.

🐛 **The bug of the release:** the C64 emulator reached "READY." but never printed its boot banner. Root cause: the boot stub didn't replicate the real 6502 reset sequence (`LDX #$FF : TXS`), so a `JSR` return address landed exactly where the KERNAL's RAM-init routine writes — corrupting the stack and silently triggering a warm-start. Found via cycle-by-cycle PC tracing. Full writeup in the release notes.

**Download:** https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.3.0-Beta3
**Roadmap:** 5.4-beta Oct 15 (Narcea AI pair), 6.0 stable Jan 1, 2027

#Godot #GameDev #OpenSource #BASIC #VisualGasic #EmulationDev

---

## Option 3: Story-Driven (For building community narrative)

✨ **VisualGasic 5.3.0-Beta3 is live — and it boots a real Commodore 64**

We wanted a stress test that would find bugs no synthetic unit test ever would, so we built a Commodore 64 emulator in VisualGasic — real 6510 CPU, real VIC-II graphics chip, and the *actual, unmodified* KERNAL and BASIC V2 ROMs from 1982.

It found bugs immediately. A `BlitImage` call that silently did nothing because it got a `Rect2` instead of a `Rect2i`. A frame-render race that painted the whole screen border color forever. A border that was scaled to monitor resolution instead of the game window, cutting off 90% of the screen. And then the big one: the emulator would boot cleanly, reach the "READY." prompt... and never print the startup banner.

Turned out the boot code wasn't resetting the stack pointer the way real 6502 hardware does. One JSR call, one wrong stack address, and the KERNAL's own memory-test routine overwrote its own return address — a silent warm-start that skipped the banner every single time. We traced it cycle-by-cycle until we caught the exact corrupted jump.

Alongside the C64, we also fixed a pile of real bugs in our Game Boy Advance emulator demo, added cross-module bytecode compilation (so imported files run at full speed, not falling back to the slow interpreter path), a new buffer type for raw memory access, and a `Global` keyword.

**Try it:** https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.3.0-Beta3

If you write BASIC, love Godot, or think emulating a 1982 computer inside a game engine is a completely reasonable way to stress-test a language — this is for you. 🎮

#GameDev #Godot #OpenSource #VisualGasic #IndieGames #RetroGaming #Commodore64

---

## Option 4: Minimal (Quick share / cross-post)

🎉 **VisualGasic 5.3.0-Beta3 — download now**

New C64 + GBA emulator demos (real ROMs!) · cross-module bytecode compilation · Buffer Type · `Global` keyword · Exit While · ~21-40% less call overhead.

777/777 tests passing · 54 corpus examples.

[Download](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.3.0-Beta3) · [Release Notes](https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_NOTES_5.3.0-Beta3.md) · [Roadmap](https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_SCHEDULE.md)

#Godot #GameDev #VisualGasic #OpenSource

---

**Suggested hashtags (any option):** #GameDev #Godot #VisualGasic #BASIC #OpenSource #IndieGames #GodotEngine #RetroGaming

**Best posting window:** Tuesday–Thursday, 10am–2pm local time for dev-community engagement.

**Suggested image:** `docs/screenshots/c64_emulator_running.png` (C64 emulator running in the Godot editor — real `**** COMMODORE 64 BASIC V2 ****` boot banner and `READY.` prompt visible).
