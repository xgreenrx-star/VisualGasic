# VisualGasic v5.2.0-Beta1 — Release Notes

**Released:** May 11 2026
**Status:** Public beta (Linux x86_64 + Windows x64)
**Codename:** *Phone, Mic, & a Thousand Verbs*

This is the first beta on the **5.2 line** and the largest single jump since
4.0. It opens VG up to mobile devices, finishes the VG⇄Godot namespace
wrapping project (Pass 6 gap-fillers), and substantially polishes the
in-editor AI assistant. Numbers are unchanged from the v5.1 series — VG is
still **2–92× faster than GDScript** on the published microbenchmarks, and
the new namespaces compile to the same bytecode dispatcher used by the rest
of the runtime.

> 🍏 **macOS:** the 5.2 line ships **Linux + Windows only**. macOS builds are
> on hold until enough requests come in — open an issue if you want one.

---

## 🤖 AI features

VisualGasic has been an "AI-native IDE" since 5.0; 5.2 turns that into a
genuinely usable everyday workflow.

- **AI correctness verified at two scales** — Same prompts, same model,
  same temperature, four languages, measured first-attempt parse-success:

  | Model | **VG** | GDScript | Python | TypeScript |
  |---|---:|---:|---:|---:|
  | Claude Sonnet 4.5 | **100%** | 100% | 100% | 92% |
  | qwen2.5-coder:7b (local) | **100%** | 68% | 100% | 84% |

  VG ties or beats Python in both runs — and the smaller the model, the
  bigger VG's relative advantage. Re-run on your own model with
  `python bench/ai_correctness/scripts/run_bench.py`.
- **AI Help panel** is the new home for in-IDE AI assistance. Five
  built-in personas (general, coder, reviewer, gamedev, teacher), plus
  preset commands: *Explain Error*, *Explain Code*, *Translate Code*,
  *Generate Tests*.
- **Pluggable providers** — Ollama (local), OpenAI, Claude, and Gemini all
  shipped with the same VG-aware prompt scaffold. Switch providers from a
  single dropdown.
- **Voice mode** — push-to-talk dictation into the AI Help panel, powered
  by Whisper. `scripts/install_whisper.sh` / `.ps1` set up the model on
  first use.
- **Narcea project scaffolder** — "Ask Narcea to Make a Project" on the
  VG Welcome launcher: type what you want, the AI emits a complete
  multi-file VG project with form layouts wired up.
- **AI Diff dialog** — every AI-generated edit shows a side-by-side diff
  with accept-per-hunk granularity before anything touches your file.

---

## 📱 Android features (preview)

- **VGAndroidPlugin scaffold** — the new `addons/visual_gasic/plugins/`
  hosts a minimal Java/Kotlin Android plugin that VG calls through three
  new namespaces. Exports targeting Android pick it up automatically when
  the `Android - VGAndroidPlugin` flag is enabled in Project Settings.
- **`GPS.*` namespace** — `GPS.Lat`, `GPS.Lng`, `GPS.Alt`, `GPS.Speed`,
  `GPS.Accuracy`. Location updates arrive via an auto-wired
  `GPS_Updated(lat, lng)` Sub.
- **`Steps.*` namespace** — `Steps.Today`, `Steps.Total`, `Steps.Reset`,
  with auto-wired `Steps_Detected(count)` Sub.
- **`Permission.*` namespace** — `Permission.Has(name)`,
  `Permission.Request(name)`, `Permission.All`. Result events fire
  `Permission_Granted(name)` / `Permission_Denied(name)`.
- **Existing Pass 4 sensors round out the device layer** —
  `Sensor.Accel/Gyro/Magnet/Magnetometer/Tilt/Gravity`,
  `Joypad.Stick/IsConnected`, `Screen.DPI/Orientation/KeepOn`,
  `Vibrate(ms)`. All wired through the same bytecode dispatcher as
  desktop VG — no per-platform code path.
- **Mobile showcase demos** under `demos/Mobile/`:
  - **TiltMaze** — accelerometer-driven ball through a hand-drawn maze.
  - **Pedometer** — step counter with daily/total UI and `Vibrate` haptic
    feedback when a milestone is hit.

---

## 🌐 Pass 6 — v5.1/v5.2 namespace gap-fillers

The five-pass VG⇄Godot wrapping project rolled out across 5.0 and 5.1
covered ~140 verbs. Pass 6 adds the verbs people kept asking for after
shipping each previous pass:

| Namespace | New verbs |
|---|---|
| `Camera.*` | `PanTo(pos, duration)`, `Bounce(dir, strength)`, `FlashColor(color, dur)` |
| `Animation.*` | `Loop(name, bool)` |
| `Physics.*` | `Gravity(v)`, `GravityV2(v2)`, `GravityV3(v3)`, `Bounce(value, body)` |
| `Ray.*` | `Cast2D(from, to[, mask])`, `Cast3D(from, to[, mask])` — one-shot raycasts, no node required |
| `Joypad.*` | `IsConnected(idx)`, `Stick(idx, side)` |
| `Sensor.*` | `Magnetometer()` (alias of `Magnet`) |
| `Crypto.*` | `Hex(bytes)`, `FromHex(string)`, `Base64(bytes)` |
| `Theme.*` | `Get(ctrl, kind, name)`, `Set(ctrl, kind, name, value)` — generic accessor |
| `Shader.*` | `Set(mat, key, value)`, `Get(mat, key)` — aliases of `Param`/`GetParam` |
| `Speaker.*` | `Speaker.Bus` alias for the namespace itself |

All Pass 6 verbs have full Command Help entries with examples, see-also
neighbors, and links into the Language Reference.

---

## 🛠️ IDE polish

- **Command Help panel** in the embedded code editor grew from 292 → **358
  keyword entries**. Every Pass 1–6 namespace verb now has syntax, prose
  description, runnable example, "see also" cross-references, and a
  manual line-number deep-link.
- **IntelliSense** does dot-completion for all VG↔Godot Pass 1–5
  namespaces — type `Camera.` and get the menu of verbs with one-line
  signatures.
- **Form Designer toolbox** — full set of Standard and Game UI controls
  retained from v5.1 (pixel/segmented/retro progress bars, badge, toggle,
  breadcrumbs, splits, expander).
- **Welcome shell** keeps the v5.1 fullscreen cover + spinner, with the
  Narcea project-scaffolder entry now wired to the new AI provider stack.

---

## 📚 Documentation

- **`docs/VisualGasic_Language_Reference.md`** gained a comprehensive
  "v4.x–v5.1 Godot Namespace Wrappers" section covering all 23 namespaces
  with per-verb tables, signatures, and notes (~250 lines).
- **`docs/reference/GODOT_FUNCTIONS_REFERENCE.md`** has a Pass-grouped
  summary section cross-linked to the Language Reference.
- **`docs/reference/commands.md`** now includes a compact namespace-overview
  table.
- **`docs/BUILTINS.md`** points at the `// ── Pass 1..6` markers in
  `src/visual_gasic_builtins.cpp` for engine contributors.
- **10 short namespace tutorials** under `tutorials/` for VG↔Godot Pass
  1–5.

---

## ⚡ Speed test results (unchanged from v5.1 baseline)

From [`demo/bench_output.txt`](demo/bench_output.txt) — single-threaded
microbenchmarks. Verify on your own machine: open
[`demo/bench.vg`](demo/bench.vg) and press F5.

| Benchmark        | GDScript (µs) | VisualGasic (µs) | C++ (µs) | VG vs GDScript    | VG vs C++          |
|------------------|--------------:|-----------------:|---------:|------------------:|-------------------:|
| Arithmetic       | 5,299         | **486**          | 59       | **10.9× faster**  | 8.2× slower        |
| ArraySum         | 4,346         | **136**          | 58       | **32× faster**    | 2.3× slower        |
| **StringConcat** | 5,153         | **95**           | 475      | **54× faster**    | **🥇 5× faster than C++** |
| Branching        | 7,002         | **76**           | 52       | **92× faster**    | 1.5× slower        |
| ArrayDict        | 11,625        | **5,224**        | 3,466    | **2.2× faster**   | 1.5× slower        |
| DictFastGet      | 29,293        | **2,953**        | —        | **9.9× faster**   | —                  |
| DictFastSet      | 20,420        | **3,375**        | —        | **6.0× faster**   | —                  |
| Interop          | 8,617         | **162**          | 7,067    | **53× faster**    | **🥇 44× faster than C++** |
| Allocations      | 6,602         | **160**          | 464      | **41× faster**    | **🥇 2.9× faster than C++** |
| AllocationsFast  | 9,428         | **2,190**        | 275      | **4.3× faster**   | 8× slower          |
| FileIO           | 938           | **462**          | 387      | **2.0× faster**   | 1.2× slower        |

**TL;DR:** VG beats GDScript on every microbenchmark — from 2× on FileIO to
**92× on branching** — and beats C++ outright on three of them
(StringConcat, Interop, Allocations). The dict and allocation benches that
regressed in earlier 5.0 builds were fixed by the VGDict sole-owner fast
path (open-addressing hash, no Variant boxing, no COW).

---

## 🧪 Test suite

**700/700** VG assertions + **289/289** GDScript assertions, **0 failures**
on Linux x86_64. Three long-standing pre-existing failures
(`test_file_permissions`, `test_stress_arrays`, `test_vg_routing`) are
fixed in this beta — see `tests: fix 3 long-standing pre-existing failures`
in the commit log.

Verify locally with:

```bash
bash run_test_suite.sh
```

---

## 📦 Downloads

| Platform | Installer | Portable |
|---|---|---|
| 🐧 Linux x86_64 | `VisualGasic-Installer-v5.2.0-Beta1-x86_64.AppImage` | `VisualGasic_v5.2.0-Beta1_linux_x86_64.zip` |
| 🪟 Windows x64 | `VisualGasic-Installer-v5.2.0-Beta1-x86_64.exe` | `VisualGasic_v5.2.0-Beta1_windows_x86_64.zip` |
| 🍏 macOS | *not in this beta — open an issue if you need one* | — |

Offline bundles (Godot 4.6.1 bundled) for both platforms are also on the
release page.

---

## 🐞 Known limitations

- macOS builds are paused for the 5.2 line — see top-of-page note.
- The Android plugin is a **preview**: it scaffolds the Gradle module and
  the three namespaces work in editor-side tests, but a full
  end-to-end APK signing pipeline still needs polish before 5.2.0 stable.
- `JS.*` web-export bindings compile on every platform but are only
  meaningful when targeting the HTML5 export — no runtime error if you
  call them elsewhere, just empty returns.

---

## 🙏 Thanks

Thanks to everyone who filed issues against the 5.1 release candidates and
to the AI-correctness testers who re-ran the harness on local models.
Bug reports, ideas, and benchmark numbers from other hardware are very
welcome at the issue tracker.
