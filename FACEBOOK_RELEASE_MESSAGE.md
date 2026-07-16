# VisualGasic 5.3.0-Beta2 — Facebook Release Message

Copy-paste ready. Pick the option that fits your page's tone.

---

## Option 1: Short & Catchy (Recommended for main announcement)

🚀 **VisualGasic 5.3.0-Beta2 is out!**

This release fixes a sneaky Python bridge bug that was silently turning every integer into a float (breaking numpy, range(), and more), adds the long-awaited `IsNot` operator, and fixes a ByRef parameter bug. Plus: two new AI providers (Codeium, Amazon Q), a Python/C++ FFI demo pack, and a tribute demo to the 1986 classic *Thrust*.

763/763 tests passing. Godot 4.6.1. Linux + Windows.

**Download:** https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.3.0-Beta2

Coming from GDScript? We wrote a full side-by-side comparison guide — link in the release notes. 👀

#GameDev #Godot #VisualGasic #BASIC #OpenSource #IndieGames

---

## Option 2: Technical Deep-Dive (For developer audiences)

🎯 **VisualGasic 5.3.0-Beta2 — Python Bridge Fix, IsNot, ByRef Write-Back**

Highlights from this release:

✅ **Python bridge int/float bug fixed** — Godot's JSON parser was silently collapsing every number to float. Built a custom decoder that preserves Python's int/float distinction end-to-end. numpy, math, and json workflows are now type-safe.

✅ **`IsNot` operator** — full VB.NET-style negated reference comparison, wired through parser → bytecode compiler → both evaluators.

✅ **ByRef write-back fix** — expression-level calls like `result = DoubleAndReturn(val)` now correctly update `val` (previously only worked as a standalone `Call` statement).

✅ **New demos** — Python bridge round-trip, C++ FFI custom library (Vec2 math via C ABI), and a full *Thrust* (1986) tribute game showing procedural `_Draw` rendering and tether physics.

✅ **Two new AI providers** — Codeium (Windsurf) and Amazon Q Developer join Ollama/OpenAI/Claude/Gemini in the Narcea AI Pair panel.

🔴 **Known issue (documented, not blocking):** outgoing PyCall arguments still lose int type on VG literals — workaround with `CInt()`. Full writeup in the release notes.

**Download:** https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.3.0-Beta2
**Roadmap:** 5.4-beta Oct 15 (Narcea AI pair), 6.0 stable Jan 1, 2027

We need beta testers on the Python bridge specifically — if you're doing any numpy/data work in VG, please try it and report back. 💬

#Godot #GameDev #OpenSource #BASIC #VisualGasic #PythonIntegration

---

## Option 3: Story-Driven (For building community narrative)

✨ **VisualGasic 5.3.0-Beta2 is live**

This release started with a bug report that looked simple: "Python integers come back as floats." Turned out the culprit was buried in Godot's own JSON parser — it has no int branch at all, so *every* number from *any* JSON source gets flattened to float. That's been true since Godot's JSON class existed.

We wrote a small, self-contained JSON decoder from scratch that mirrors how Python's own `json.loads()` decides int vs. float, and wired it into the two places VG talks to Python workers. Six new tests confirm scalars, negatives, nested dicts, and mixed arrays all round-trip with the right type now.

While we were in there, we also closed out the `IsNot` operator (`If obj IsNot Nothing Then`) and fixed a ByRef parameter bug that only showed up when you called a function inside an expression instead of as a standalone statement — the kind of bug that hides for months because most code happens to avoid the exact pattern that triggers it.

Also new: two more AI providers for the Narcea AI Pair, a C++ FFI demo showing VG calling a custom C++ math library, and — because we can't resist a good retro tribute — a playable *Thrust* clone (1986) built entirely in VG's procedural drawing API.

**Try it:** https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.3.0-Beta2

If you write BASIC, love Godot, or just miss the VB6 era — this is for you. 🎮

#GameDev #Godot #OpenSource #VisualGasic #IndieGames #RetroGaming

---

## Option 4: Minimal (Quick share / cross-post)

🎉 **VisualGasic 5.3.0-Beta2 — download now**

Python bridge int/float bug fixed · `IsNot` operator · ByRef fix · new AI providers · Python/FFI demos · Thrust tribute game.

763/763 tests passing.

[Download](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.3.0-Beta2) · [Release Notes](https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_NOTES_5.3.0-Beta2.md) · [Roadmap](https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_SCHEDULE.md)

#Godot #GameDev #VisualGasic #OpenSource

---

**Suggested hashtags (any option):** #GameDev #Godot #VisualGasic #BASIC #OpenSource #IndieGames #GodotEngine

**Best posting window:** Tuesday–Thursday, 10am–2pm local time for dev-community engagement.
