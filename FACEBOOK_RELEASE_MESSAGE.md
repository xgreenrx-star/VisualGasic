# VisualGasic 5.4.0-beta1 — Facebook Release Message

Copy-paste the **Recommended post** below into Facebook. Plain URLs — no markdown.

**Suggested image:** `docs/screenshots/Screenshot at 2026-08-25 13-59-02.png` (Beta Showcase title — 12/12 compute · 9/9 draw HUD)  
**Or:** link the YouTube video directly — Facebook will pull the preview thumbnail.

---

## Recommended post (copy from here ↓)

🚀 **VisualGasic 5.4.0-beta1 is out — the full-speed beta.**

Nine days after Beta7, this is the release we've been building toward: Visual Gasic now beats GDScript on **every published speed test** we ship.

📊 **The numbers (verified, checksums on static workloads):**
• **12/12 compute** benchmarks — faster than GDScript
• **9/9 draw** benchmarks — faster than GDScript
• **891/891** automated regression tests passing (up from 871)
• FunctionCall — previously our weak spot — is now **~60× faster** than GDScript after compiler inlining and loop fusion

This isn't a marketing claim. CI runs a benchmark regression gate on every build. If VG slips behind GDScript, the build fails.

🎬 **Watch the ~6-minute Beta Showcase tour:**
https://youtu.be/FUw8zgbn_tU

Backrooms hub → shader reel → About VG → Squash the Creeps in pure .vg → Neon Runner → Vector Storm bullet-hell. Open the same project in Godot and press F5, or just watch the video first.

⚡ **What's new since 5.3.0-Beta7 (Aug 21):**
• Draw grid-loop fusion — hot _Draw paths compile straight to native C++
• FunctionCall inlining + nested-loop closed-form fusion
• CI benchmark regression gate (`benchmark_regression_check.sh`)
• **VG Beta Showcase** — full release tour project in the repo
• IDE: context rail sidecar, sprite Data editor, `.vgd` DataFile groundwork
• Fixed: `CInt(3.7)` now returns 4 (VB6-style rounding)

Visual Gasic is VB6-style BASIC for Godot 4.6 — a language designed so **you can read and audit AI-generated code line by line**, with a real IDE, debugger, and Narcea AI Pair built in.

📥 **Download (Linux & Windows):**
https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.4.0-beta1

One-click installers (AppImage / .exe), offline bundles, Godot Asset Library zip, or install from AssetLib inside Godot 4.6.1+.

🌐 Website: https://xgreenrx-star.github.io/VisualGasic/

---

**What's next?** This was a big cut — the next beta will take longer.

**v5.4.0-beta2** — target **October 15, 2026** — Narcea AI pair (describe a form or game in plain English, get working VG code), Buffer type, optimizer hints.

Stable **v6.0.0 (VG6)** remains targeted for **January 1, 2027**.

Questions, bugs, or "I tried it and here's what happened" — drop them in the GitHub issues or reply here. We read everything.

#GameDev #Godot #GodotEngine #VisualGasic #BASIC #OpenSource #IndieGames #AI #Programming

---

## Short version (if character limit bites)

🚀 **VisualGasic 5.4.0-beta1** — VG beats GDScript on **12/12 compute + 9/9 draw** benchmarks. FunctionCall fixed (~60× faster). 891/891 tests. Full Beta Showcase tour.

🎬 Demo: https://youtu.be/FUw8zgbn_tU
📥 Download: https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.4.0-beta1

Next: **v5.4.0-beta2** (Oct 15, 2026). Stable **v6.0.0** Jan 1, 2027.

#GameDev #Godot #VisualGasic #OpenSource

---

## Posting tips

- **Best window:** Tuesday–Thursday, 10am–2pm local time
- **Pin the YouTube link** as first comment if the post preview doesn't embed it
- **Asset Library:** https://store.godotengine.org/asset/visual-gasic/visual-gasic/
