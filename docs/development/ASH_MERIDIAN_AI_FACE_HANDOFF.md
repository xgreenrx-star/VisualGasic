# Ash Meridian: Narcean AI face (opening video + small FEB face)

Revised November 1, 2026 (v3). History:

- v1, a procedural "fractured signal mask", was rejected ("It looks bad").
- v2 asked Cursor to draw the full holographic face and tunnel live in VG. The
  port works but stutters, because about 3,000 separate draw calls per frame go
  through the interpreter, and `_draw` has no anti-aliasing or blur.
- **v3 (this brief):** the user approved this split:
  1. The **opening is a pre-rendered video** with a synthesized robotic scream, made
     offline by the same Python pipeline as the approved mockup.
  2. **In game, the FEB's AI uses a simplified line face**, because it is small on
     screen.

Keep all alternates (human, wire and human-holo GIFs, `human_face.json`). Do not
delete them.

## 1. Assets (already in the repo, all under `samples/games/ash_meridian_part1/`)

| Path | What |
|---|---|
| `assets/ai_face/intro_alien_holo.ogv` | **Opening video**: 960x540, 60 fps, 16.0 s, Theora video with Vorbis stereo audio (about 10 MB) |
| `assets/ai_face/intro_alien_holo.ogg` | The same audio on its own (48 kHz Vorbis). Use it only if the audio inside the video fails (see §2) |
| `assets/ai_face/alien_face_small.json` | **Small FEB face**: 30 polylines, 203 segments, plus 2 irises |
| `assets/ai_face/alien_face.json`, `human_face.json` | Full meshes (used to make the video; human is an alternate) |
| `reference/ai_face/intro_alien_holo_preview.mp4` | H.264 copy with audio, for review in any player |
| `reference/ai_face/small_face_preview.png` | Small face at rest and with the mouth open |
| `reference/ai_face/*.gif`, `*_keyframes.png` | Approved mockups and the alternates |
| `tools/ai_face/render_video.py` | Renders the frames: `TUNNEL_LEN=26 python3 render_video.py /tmp/vframes 60` |
| `tools/ai_face/scream.py` | Synthesizes the audio: `python3 scream.py /tmp/intro.wav` |
| `tools/ai_face/export_mesh.py` | Writes all three JSON files: `python3 export_mesh.py ../../assets/ai_face` |
| `tools/ai_face/face.py`, `anim.py` | Mesh design and the reference renderer |

To rebuild the video:

```
ffmpeg -framerate 60 -i /tmp/vframes/f%04d.png -i /tmp/intro.wav \
  -c:v libtheora -q:v 5 -c:a libvorbis -q:a 6 -shortest assets/ai_face/intro_alien_holo.ogv
```

The Python tools are offline authoring aids only. The game must never run Python.

Verified on Nov 1 with Godot 4.7.2 (`gl_compatibility`, under Xvfb):

- `load()` returns a `VideoStreamTheora`, and `get_stream_length()` is 16.0.
- `VideoStreamPlayer` plays, and its frames at 3, 9 and 13 s match the mockup.
- Audio was **not** checked: the test used the dummy audio driver. Check it by ear.

## 2. Opening sequence (video)

What the video shows:

| Time | Picture | Sound |
|---|---|---|
| 0.0–2.4 s | Face fades in | Machine drone and mains hum |
| 2.4–4.8 s | Face watches | Data chirps |
| 4.6–6.4 s | Jaw opens | Servo grind and latch clicks |
| 5.0–14.2 s | Camera dives into the mouth, through the faceted tunnel | Robotic scream: formant "AAH→EEE", rising pitch, tritone voice, ring mod, stutter and bit-crush. It becomes muffled inside and sags in pitch from 11.5 s. Whooshes as each light ring passes |
| 13.4–14.6 s | Light at the end swells | Shimmer cluster |
| 14.45 s | — | Sub-bass impact |
| 14.6–16.0 s | Light cools to blue, then black | Low pad tail fading to silence |

**The video contains no menu.** The game draws its own live title over the last
1.4 s.

Implementation in `part1.vg`:

1. Cursor's v2 work already added `PH_FACE_INTRO` (21), plus `face_intro`,
   `face_played` and a live `narcean_ai_face.vg` node spawned through
   `presentation.SpawnVg`. All of it is uncommitted. **Keep the phase and its
   boot → intro → title flow, skip and play-once logic.** Replace only the live face
   node playback with the video below. The engine boot splash
   (`assets/branding/narcean_logo.png`) is separate from the face film.
2. In that phase, create one `VideoStreamPlayer` with
   `ClassDB.Instantiate("VideoStreamPlayer")`, set its stream to
   `Load("res://assets/ai_face/intro_alien_holo.ogv")`, and give it a size of
   960x540 at (0, 0). Add it as a child, then start playback **after** it is in
   the tree. Calling play before that fails with `!is_inside_tree()`.
3. The video is a child Control, so it covers `_Draw`. To draw the title on top
   during the fade, use a `CanvasLayer` or child order: video below, and the title
   drawn in an overlay Control above it (or move `DrawTitle()` into one). From
   `stream_position >= 14.6`, fade the title in (alpha 0 → 1 by 16.0) and accept
   menu input.
4. When playback ends (`finished` signal, or `is_playing()` false after starting),
   free the player and set `phase = PH_TITLE`.
5. **Skip:** any key or click before 14.6 s jumps to the menu fade:
   - Tween the player's `volume_db` to -40 and its `modulate` to black over 0.4 s.
   - Show the title fading in, then free the player.
   - Do not hard-cut the audio; it pops.
6. **Play once per launch.** Returning to the title from pause, options or game over
   goes straight to `PH_TITLE`.
7. **Reduced motion** (add it next to the existing options if there is no such flag):
   skip the video. Show a 1 s fade to the title with no audio.
8. **Audio fallback:** if a manual check shows no sound from the video, set the
   player's `volume_db` to -80 (leaving the video unchanged). Then start an
   `AudioStreamPlayer` with `intro_alien_holo.ogg` in the same frame as play.
   **Never play both.**
9. Volume follows the game's existing audio settings or bus, if any.

## 3. Small FEB AI face (live VG)

This is for the FEB's crazy AI on in-game screens and panels, typically 120–300 px.
It replaces the heavy full-mesh code in `narcean_ai_face.vg`.

### Data

`alien_face_small.json`, `format: "ash_meridian_ai_face_small"`:

- `features{name: [[x, y, jaw_w, upper_w], ...]}`: each point carries its own pose
  weights, so do **not** port Python's weight functions.
- `bold_features`, `irises[[cx, cy, r]]`, `mouth_y`, `jaw_drop`, `upper_lift`,
  `corner_push`, `rest_focus`, 1000-unit canvas.
- `in_up` + reversed `in_lo` = the mouth opening.

### Pose (open amount `o` 0..1)

```
lat = x - 500
c   = max(0, 1 - abs(abs(lat) - 75) / 55) * max(0, 1 - abs(y - mouth_y) / 30)
x'  = x + sign(lat) * corner_push * o * c
y'  = y + jaw_drop * o * jaw_w - upper_lift * o * upper_w
```

### Drawing

Each frame costs about 30 `DrawPolyline` calls plus 4 circles.

- Build each feature's `PackedVector2Array` once per frame.
- Glow: draw each line wide and dim first, then draw the bright core on top:

| Pass | Width | Alpha | Colour |
|---|---|---|---|
| Glow | 5 | 0.15 | Cyan `RGB(60,220,255)` |
| Core | 1.5 (bold features: 2.5) | 1.0 | `RGB(225,250,255)` |

- Irises: two circles each, at `r` and `0.42 r`, in `RGB(150,255,235)`.
- Optional: draw the scanlines over the face rectangle only.
- Scale with `size / 1000 * 0.92`, centred on `rest_focus`.

### API

Keep these names where Cursor already has them:

- `load_face(path)`, `set_time(seconds)`, `reset()`, `last_error`;
- `set_open(o)` for scripted moments;
- `set_voice_level(v)`, where the jaw follows the voice level (smoothed);
- `set_mode("idle" | "talk" | "breakdown")`;
- `set_reduced_motion(flag)`.

Modes:

- **idle:** faint breathing (scale ±1%), the irises drift slightly, and the face
  occasionally flickers for 1 frame.
- **talk:** `o` follows the voice level, plus small random jaw jitter.
- **breakdown:** features detach and drift apart with a jitter that is deterministic
  per feature; amber interference lines (`RGB(255,170,60)`); fades to nothing over
  2 s.

Reduced motion removes the jitter and flicker.

`ai_face_preview.tscn` / `ai_face_preview.vg` (F6) controls:

- Space: pause.
- 1 / 2 / 3: idle / talk / breakdown.
- V: a synthetic voice level for testing talk.
- Up / Down: face size, 120–480 px.

The **intro no longer uses this node.**

Do **not** wire the face into the FEB scene yet. That waits on the FEB story beat.

## 4. Tests (VG, `test_proj/run_suite.gd` harness)

Rewrite `test_ai_face.vg`.

Video:
- `intro_alien_holo.ogv` loads as a `VideoStreamTheora` and its length is between
  15.9 and 16.1 s.
- `intro_alien_holo.ogg` loads.

Small face:
- The JSON loads with 30 features and 203 segments total.
- All values are finite, and there are 2 irises.
- The mouth polygon has 8 or more points.
- Its height at `o = 1` minus its height at `o = 0` is roughly `jaw_drop`, within
  ±25%.
- `set_voice_level(0 / 0.5 / 1 / -3 / 9)` keeps `o` within 0..1.
- The same time gives the same posed points (deterministic), and `reset()` restarts.
- Breakdown reaches zero visibility by its end.

Intro flow (headless; video playback may not advance there, so drive the phase
logic directly or use the skip):
- Boot leads to `PH_FACE_INTRO`, then `PH_TITLE`.
- Skip goes to the title.
- Reduced motion bypasses the video.
- Returning to the title does not replay the intro.

Existing suites (`TRACE_MODELS`, `TRACE_CYCLE`, `TRACE_ROUTE`, `TRACE_YARD`, campaign)
still pass.

Manual and visual checks:
- **Listen** to the intro with real audio.
- Capture the game window at 3, 9, 14.8 and 16.5 s (the title must be visible and live).
- Confirm skip has no audio pop.

## 5. Constraints

- Game logic is VG only. Native Godot nodes, resources and shaders are fine. No
  GDScript, no Python at runtime, no new dependency.
- Do not re-encode or edit the video or audio in Godot. To change them, edit
  `render_video.py` / `scream.py` and rebuild (§1).
- Keep all reference media and alternates. `reference/` is Godot-ignored.
- Leave the other dirty work untouched: `backlight_exploration.vg`,
  `backlight_yard.vg`, `project.godot`, the test files and `ash_meridian1.avi`.
- No commit or push unless the user asks.

## 6. Copyable Cursor prompt

```text
Ash Meridian AI face v3. Read docs/development/ASH_MERIDIAN_AI_FACE_HANDOFF.md fully.

1) Opening: in the existing PH_FACE_INTRO phase in part1.vg (keep its flow, skip and
   play-once logic), replace the live narcean_ai_face node with the pre-rendered video
   assets/ai_face/intro_alien_holo.ogv (960x540, 60 fps, 16 s, Vorbis audio included),
   using a VideoStreamPlayer created with ClassDB.Instantiate and played only after it
   is in the tree. From 14.6 s fade the existing title menu in
   over the video and accept input; go to PH_TITLE when the video finishes. Any key skips
   to the menu fade, with a 0.4 s audio and picture fade (no pop). Play once per launch.
   Reduced motion skips the video. Keep the Lucid boot splash and credit.
2) Replace the heavy full-mesh code in narcean_ai_face.vg with a small line face loaded
   from assets/ai_face/alien_face_small.json (points carry [x,y,jaw_w,upper_w]): about
   30 DrawPolyline calls with a glow pass, idle/talk/breakdown modes, and voice-driven
   jaw. Update ai_face_preview for it. Do not wire it into the FEB scene yet.
3) Rewrite test_ai_face.vg per section 4 and keep the trace and campaign suites green.

VG only, no GDScript, do not edit the media, keep all reference and alternate assets,
no commit or push. Report test counts and window captures at 3/9/14.8/16.5 s, and
confirm you listened with real audio. Stop for review.
```
