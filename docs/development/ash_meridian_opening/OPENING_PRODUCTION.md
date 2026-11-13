# Ash Meridian opening: a wager and a warning

## Deliverable status — November 11, 2026

### Dialogue revision 4

The concept is accepted; the first dialogue pass sounded too written and
robotic. Revision 2 replaces the whole exchange with contractions, ordinary
responses, and familiar teasing. Mark's confidence fades rather than every
line trying to sound ominous. Jason asks what happened, and Mark declines
to discuss it; his return is not framed as proof that the place is safe.
Mark's last warning is practical: “If it feels wrong, leave. Don't wait.”

The “empty windows” observation is removed. At arrival Jason instead says,
“He didn't mention it was this big.” This reacts to the visible ring without
claiming he can inspect individual windows or read Narcean records. Orac
remains dry and capable, not a string of instrument-status announcements.
Jason's message to Stacy is an informal voice message, not an exposition
summary.

The scratch bake uses authored speed and sentence-silence settings per line.
Revision 4 shapes Mark's beats individually: the wager lands reluctantly, the
warning slows down, the retirement line pauses around his loss of confidence,
and his brief return to technical enthusiasm is quicker before the final
warning settles again. Jason's message to Stacy is less clipped, and Orac's
arrival line is more conversational. Punctuation supplies the available
phrase-level cues; the local Kokoro interface exposes speed and silence, not
actor-grade pitch or emotion controls. These are improved scratch cues, not a
claim of finished human performance.

The user explicitly reaffirmed the **Tron-like Backlight aesthetic**.
All production modeling, lighting and compositing must match the existing
game: solid industrial forms, dark material mass, selective cyan/amber
edge illumination and haze. The hand/table overlap was a real blocking
defect, not a stylistic choice. The later MakeHuman poker-table experiment was
also rejected: its scalp/hair fit, shoulder deformation, hand posing, table
intersections, and motion were not acceptable. Do not treat that render as an
approved result. The next 3D attempt must first pass a seated still and a short
motion test. See the [Cursor handoff](./CURSOR_3D_OPENING_HANDOFF.md).

### 3D review: gate 6 and gate 7

Cursor's [gate 6 export](./renders/gate6/ash_meridian_opening_v05.mp4) is
the first 3D cut whose character animation was accepted. It uses Rocketbox
characters, solved seated arms and lip sync. Its sets were not accepted:
- The bar was an open black box.
- The bottles and glasses were plain cylinders.
- The Narcean ring was a 14-unit torus beside a ship of similar size, with
  no planet.

Gate 7 ([ash_meridian_opening_v07.mp4](./renders/gate7/ash_meridian_opening_v07.mp4)
plus a [subtitle sidecar](./renders/gate7/ash_meridian_opening_v07.srt))
keeps gate 6's characters, animation, cameras, voices and edit unchanged.
It replaces only the sets.

The bar now has:
- An enclosed room with ribs, ducts and haze.
- A felt poker table with a cyan edge.
- Lathed glass tumblers holding whiskey and ice, and a bottle on the table.
- A backlit three-shelf back-bar.
- A DOCK / 07 window looking onto a docked courier.
- Booths, a BAR sign and a door.

Close-ups use bone-tracked focus.

The voyage now has:
- A hangar exit through a lit octagonal tunnel under a DEPARTURES / 07 sign.
- A 1,000-unit planet inside a 1,500-unit-radius Narcean ring, seen once
  from far away. The band has inner edge walls with cyan tops and a thin
  air haze.
- A cut to a separate true-scale ring section (`set_narcea.py`): radius
  250,000 units, band 30,000 wide, walls 4,500 high, against a 6-unit
  courier. Only one edge wall is in frame at a time.
- An atmosphere held on the band by spin and contained by the walls, with
  the top left open. It is an exponential haze volume with cloud decks.
- A descent through the clouds to the in-game landing view: a dark overcast,
  the cyan Backlight Yard grid and the orange landing gate. The approach
  matches the `ASH_VIEW=landing` captures from `test_part1.gd`. There is no
  docking tower.

Gate 7 v06 ended at a docking tower and was replaced by v07.

Preview stills sit beside the export in [renders/gate7](./renders/gate7/).

The scripts are in [pipeline/](./pipeline/). The gate 2–6 files are Cursor's
and are unmodified. `gate7.py` swaps in `set_bar.py`, `set_voyage.py` and `set_narcea.py`.
The scripts hard-code `/tmp/ash-opening-gate1` (Rocketbox characters, cards,
audio) and `/tmp/ash-opening-gate7` (frames). Restore those working folders
before rebuilding:

```sh
blender -b -P gate7.py -- bar      # frames 1–1976
blender -b -P gate7.py -- voyage   # frames 1977–3392
```

This is a **141.35-second illustrated, voiced animatic**, not the final cinematic.
It is a local review package, separate from the live game. Four original SVG
keyframes support seven editorial shots, with camera moves, dissolves, exact
speech subtitles, twenty locally baked neural dialogue clips, scrubbing,
pause/resume, mute and skip. Optional procedural ambience is a mix study,
not the score. No paid image-generation service was used.

The current full-cut review export is
[ash_meridian_opening_animatic_v05.mp4](./renders/ash_meridian_opening_animatic_v05.mp4).
Its scale pass uses the provisional dimensions documented below.

A portable MP4 review is exported as 1280 × 720, 24 fps H.264 video with AAC
dialogue. The complete file is checked for decode errors and rendered subtitle
readability before it is treated as a deliverable.

Open the [animatic](../../../samples/games/ash_meridian_part1/assets/opening_cinematic/index.html)
in a browser and press **Play with voices**. It works offline: the generated
review data embeds the dialogue so the file does not depend on a local server.
Keep the HTML, review-data.js and four SVGs together. Full-resolution keyframes
are linked below the player. Space pauses; Escape skips to the review's handoff
card. That card does not start the game.

The story is governed by the [unified proposal](../ASH_MERIDIAN_PROPOSAL.md).
The machine-readable [script](../../../samples/games/ash_meridian_part1/assets/opening_cinematic/script.json)
is the dialogue source; its text must match the generated voices.

## First in-engine bar staging pass

The separate [3D bar study](../../../samples/games/ash_meridian_part1/opening_bar_study.tscn)
now stages the conversation in Godot rather than moving a camera across a
flat drawing. This is **look development and production blocking, not final character art**.
The existing campaign entry point remains unchanged.

The scene includes a small original station bar, a framed dock window with
restrained moving traffic, solid furniture, shelves and practical lighting.
Warm face keys and cyan edge light preserve the Backlight direction without
turning the room into transparent wireframe. Character proxies are original
procedural meshes; their appearance is not an approved Jason/Mark redesign.
A separate [CC0 rigged-character audition](./character_audition/README.md)
tests an alternate modeling pipeline, corrected hair/eyebrow fit, and viseme
controls. Its two-shot uses lap-rest poses and hides the hands below the bar;
table contact and hand performance remain untested. It includes review stills
and two silent motion tests: a close-up
[facial-motion sample](./renders/mark_viseme_motion_audition_v01.mp4) and a
[two-shot blocking sample](./renders/mark_jason_two_shot_motion_audition_v01.mp4).
Like the other rendered opening reviews, both clips are kept in the central
`renders/` folder. Neither is integrated into Godot or approved final character
art.

The measured bar edit lasts **82.35 seconds**, ending at station departure.
It uses the same fifteen canonical dialogue clips and subtitles as the
illustrated edit. The animatic builder also exports `timeline.json`; the
Godot study reads that edit, checks text/delivery against the canonical
script and rejects missing or stale clips instead of synthesizing a fallback.
No second dialogue script or speech timing table is maintained.

Authored coverage includes an over-shoulder setup, Mark's warning close-up,
Jason reverse angles, a wider interrupted-rise beat, and a final close-up.
Both coverage directions stay on the same side of the table axis.
Mark looks away during his refusal to discuss Narcea. Jason begins to rise
before Mark stops him. A small coordinates device changes from a send prompt
to transfer confirmation and slides toward Jason; this is **not the Commander
from the stash**, and it does not grant inventory or translation knowledge.

Hands are deliberately hidden in this pass. The screenshot review showed that
the procedural palms and wrists still looked detached and palm-up, so the
visible hand model was removed instead of presenting misleading anatomy. The
arms now bend down toward the lap; wrists stay below and behind the table edge,
outside its footprint. Tests sample arm proportions, wrist height, hidden-hand
state, movement, and clearance from the tabletop edge throughout the edit.
This is a conservative staging choice, not a finished hand rig.
Head motion, breathing, reach and chair movement remain modest blocking. The
study uses clip-driven jaw motion, **not phoneme lip sync or finished emotional
acting**.

The review starts paused and provides Play, Restart, Mute, timeline scrubbing
and Skip. Space pauses/resumes; Escape ends the study. Pause freezes scene
time and audio, and resume preserves the speech offset. Muted playback keeps
the exact subtitles. Skip stops speech and displays an explicit end-of-study
message; it does not enter the campaign or pretend the departure is finished.
Freeing the scene stops/releases audio and its clip references.

Run this isolated preview from the repository root:

```sh
./Godot_v4.6.1-stable_linux.x86_64 \
  --path samples/games/ash_meridian_part1 \
  --windowed --resolution 1280x720 res://opening_bar_study.tscn
```

For deterministic stills, set `ASH_BAR_TIME` to seconds and
`ASH_BAR_CAPTURE` to an absolute PNG output path before that command.
Rendering requires a display; headless mode is for the structural tests:

```sh
./Godot_v4.6.1-stable_linux.x86_64 --headless --audio-driver Dummy \
  --path samples/games/ash_meridian_part1 \
  --script res://tools/test_opening_bar.gd
```

The [movie runner](../../../samples/games/ash_meridian_part1/tools/export_opening_bar.gd)
plays the whole study once and exits in a clean presentation mode: review
controls are hidden, subtitles retained, and the work-in-progress label stays
visible. Use Godot's `--fixed-fps 24` and
`--write-movie /absolute/review/path.avi` with that script to capture actual
3D coverage and audio, then encode the review outside the runtime assets.
This is separate from the illustrated 141.35-second movie.

### Staging review evidence

- **101 Godot checks passed:** exact bar line count/end boundary, lap-rest
  arm/table-edge clearance throughout the edit, safe head framing for each
  coverage setup, measured arm proportions and wrist height, hidden hands,
  reduced arm movement,
  actual audio advance, pause/resume offsets, mute/scrub, skip/restart,
  unchanged campaign entry, clip-driven facial poses, silent listeners,
  deterministic scrubbing, muted mouth motion, clean presentation and
  voice-node destruction. The completed test
  run reported no leaked objects after allowing the audio mixer to release
  stopped playback. Minimum measured distance from the arms to the table
  footprint is **160 mm**.
- **Seven Node edit checks passed**, including equality between the browser
  edit and Godot's timeline export, clip hashes and independently decoded
  waveform samples for the mouth-motion data.
- Recorded the complete scene from Godot at the project's **960 x 540,
  24 fps** movie viewport; the H.264/AAC review is **82.584 seconds**
  (1,982 frames). The complete movie decodes without errors.
- Compared each of the fifteen recorded voice waveforms with its canonical
  clip: correlations **0.980–1.000**, edit offsets **22.6–32 ms**, below the
  verifier's 125 ms limit. This verifies recorded speech identity and timing,
  not whether the synthetic scratch acting sounds sufficiently human.
- Inspected actual wide, transfer, warning, reverse, interrupted-rise and
  final-warning frames. Reduced the initial overexposed face lights,
  corrected wall shadow artifacts, and retained dark material mass with
  distinct cyan/amber accents.

The current review export is
[ash_meridian_opening_bar_v04.mp4](./renders/ash_meridian_opening_bar_v04.mp4).
Verify an export against the canonical dialogue with:

```sh
node samples/games/ash_meridian_part1/tools/verify_opening_bar_movie.mjs \
  /absolute/path/to/ash_meridian_opening_bar_v04.mp4
```

The characters remain visibly simplified proxies. Final rigs, expressive
eyes, fingers, cloth/contact animation, lip sync, distinctive Mark casting,
bar sound design and exterior choreography are still required. This pass
must not be presented as the finished opening or silently enabled in New Game.

### Visual refinement pass

The second 3D pass replaces the first flat eye/brow bars, separate nose
pieces and angular head profiles with smoother continuous facial surfaces,
recessed eyes, irises/catchlights, shaped lids, softer brows, a continuous
hair cap, and restrained age/stubble detail on Mark. These remain stylized
procedural characters, not photoreal people or approved final casting.
The early segmented hair and round nose tests were rejected after actual
close-up renders made their toy-like appearance apparent.

Jackets now have shaped torsos, rounded/tapered sleeves, shoulder/elbow volume,
small seams and pockets. Hands are hidden below the table in this review pass;
the visible fingers, wrist connections and tabletop-contact work described in
earlier blocking notes are deferred until proper character rigs exist. Final
skinning, finger joints and polished physical contact remain outstanding.

The room gains bottle labels and under-shelf lighting, pendant cages, panel
joins and fasteners, conduit, vents, a reverse-angle menu, docking gantries
outside the window, a coaster, counters, discarded cards and restrained table
wear. An original surface shader adds subtle brushed/mottled variation without
external textures. Face keys are less orange; cyan remains a rim/infrastructure
accent rather than a blanket wash. Four-sample MSAA is enabled only on the
study viewport; the main project's renderer/settings are unchanged.

Blinking and concern poses are deterministic in scene time. Mouth opening is
derived from the **actual recorded audio energy**, not a random sine wave
while a character's subtitle is visible. The normal animatic builder now calls
the [performance-data builder](../../../samples/games/ash_meridian_part1/tools/build_opening_performance.mjs)
and exports `speech-envelope.json`: 50 Hz smoothed RMS samples and source-clip
SHA-256 hashes for the fifteen bar lines. The Godot stage rejects stale text,
hashes, sample counts, rates or invalid values. A listening character stays
still, pauses retain the pose, scrubbing reproduces it, and mute does not
remove the authored animation.

This is **audio-driven jaw blocking only**. It does not infer phonemes,
visemes, language, emotional intention or believable acting. Those are still
production gates; the revised voices remain the existing neural scratch
performances. Rebuilding the animatic also rebuilds this data, so no additional
manual timing file is maintained.

The hand-hidden capture above describes the separate Godot bar study; it
remains unchanged. A later MakeHuman poker-table experiment is available at
[ash_meridian_opening_poker_v01.mp4](./renders/ash_meridian_opening_poker_v01.mp4),
but it is **rejected**, not an approved review: hairline/scalp fit, shoulder
and arm shapes, wrists/fingers, table intersections, and motion all failed
review. Do not use its character posing or animation as a target.

The next 3D attempt should use the existing Backlight/storyboard SVGs and
canonical dialogue assets, but must validate characters before a long render.
Follow the [Cursor 3D opening handoff](./CURSOR_3D_OPENING_HANDOFF.md) for asset
licensing, a character contact sheet, a seated still, and a short motion proof.
Keep all such work out of the live campaign until the user approves it. Place
review exports in this central `renders/` folder.

## Editorial storyboard

| Time | Picture and camera | Performance and sound | Purpose |
|---|---|---|---|
| 0:00–0:10 | Over Jason's shoulder: winning cards in foreground, Mark beyond the table. Slow, restrained push. | Cards settle, ventilation, one glass. Mark jokes about the hand; Jason reminds him he claimed to read people. | Establish their familiarity and Mark's bruised pride without explaining card rules. |
| 0:10–0:31 | Tighter Mark coverage. In production, insert his hand transferring the coordinate file, then hold his eyes. | The drink is acknowledged, not played as slurred comedy. Jason asks what happened; Mark doesn't want to discuss it. | Make the coordinates legitimate and the warning sincere. |
| 0:31–0:49 | Return to a two-shot/reverse in final production; the animatic uses a wider crop of the table drawing. | Mark mentions retirement. Jason answers with Stacy and their future. Give Mark a short reaction before his reply. | Jason chooses risk; he is not tricked or forced. |
| 0:49–1:23 | In final production Jason begins to stand; a chair shifts. Mark stops him, slides the directions across the table. The current drawing cannot show that action. | Mark gives the shelter directions and software. His old confidence briefly returns when describing the computer, then he asks Jason to leave if things feel wrong. | Introduce the real stash without explaining Narcean history. |
| 1:23–1:41 | Match the coordinate display's amber point to a docking light. The Ash leaves an original, faceted working station. | Low machinery replaces bar ventilation. Jason records a brief message to Stacy. A transition indicates travel; the station is not next door to Narcea. | Open the scale and establish home before isolation. |
| 1:41–2:04 | Planet-and-ring establishing view; let the image arrive before Orac speaks. Small Ash silhouette provides scale. | Remove station chatter. Orac notes Mark was telling the truth but nobody answers. Jason reacts to the ring's sheer size. | Awe first, unease second. Do not have Orac know the civilization's history on arrival. |
| 2:04–2:22 | Close to an industrial approach entry. In production, show relative motion settling as the Ash matches the habitat. | Orac asks for time to match rotation; Jason agrees to look inside. Machinery appears through the hull. | Bridge to the mandatory cockpit-controls briefing and existing playable landing. |

These are editorial timings, not animation holds. Do not keep one immobile
character drawing onscreen for eighty seconds in the final game. The animatic
tests dialogue and coverage requirements. The separate poker-table experiment
was rejected for character anatomy, hair fit, hand posing, intersections, and
stiff motion. A new 3D attempt must pass the visual gates in the Cursor handoff
before its coverage or animation is treated as production progress.

## Four keyframes

- [The last hand](../../../samples/games/ash_meridian_part1/assets/opening_cinematic/table.svg):
  muted amber on Mark's face, cyan table edge, worn dark jacket, foreground
  cards, one glass and a small data device. This is costume/blocking reference,
  **not final character design**.
- [Departure](../../../samples/games/ash_meridian_part1/assets/opening_cinematic/station.svg):
  original faceted station with structural docking aperture and restrained
  traffic. Elite is an atmosphere reference, not permission to copy a station
  model or logo. The ship sketch references the existing Ash's broad wings,
  raised canopy, central fin and twin amber engines; the final shot must use
  the actual game mesh.
- [Beyond the frontier](../../../samples/games/ash_meridian_part1/assets/opening_cinematic/arrival.svg):
  a non-luminous wasteland planet, structural habitat, tiny ship and one
  service outcrop. The ring crosses in front of the planet and is hidden
  behind it correctly. The visual target uses a provisional 1,000 km outer
  ring radius, 750 km inner radius, 440 km planet radius and the actual Ash
  mesh dimensions (about 10.5 m long by 9.7 m wide). In the wide view, a
  tracking camera sits close to the Ash and far from the ring; this is why
  the ship remains visible but occupies under 3% of the ring's apparent
  diameter. The close approach uses a 20 m clear service opening. These are
  composition targets, **not locked engineering specifications**.
- [The approach](../../../samples/games/ash_meridian_part1/assets/opening_cinematic/approach.svg):
  hull panels, service trusses, sparse cyan lines and amber entry lights. The
  final corridor needs an authored path to the inhabited face; do not imply
  the ship can simply fly through solid hull to reach Backlight Yard.

## Visual and sound direction

The contrast is between a tired, populated human place and an enormous,
apparently empty alien one. Keep the opaque, weighty silhouettes of the
game. Cyan defines working infrastructure; amber signals habitation,
guidance and the Ash's engines. Use light sparingly. No transparent
wireframe architecture, generic neon nightclub, gratuitous lens flare or
continuous camera shake.

The table scene stays intimate. Mark's fear should be visible before it is
verbal: he stops playing with the glass, watches the coordinate transfer,
and briefly cannot meet Jason's eyes. Drink affects his judgment; it does not
erase his intelligence. Avoid constant fidgeting, comic hiccups, exaggerated
slurring or melodramatic flashbacks. Jason's confidence is hopeful, not cruel.

The final reveal can add a sun, distant debris or a restrained nebula, but
not a dense asteroid field beside an intact habitat without a reason. Do
not show active Narcean traffic to decorate an abandoned destination. Use
station traffic earlier to make the destination's silence meaningful.

The planet was abandoned long before the ring's society disappeared. It
has no Earth-like blue oceans or arbitrary modern city lights. Why its
people left remains unknown. The opening must not reveal MJH's identity or
explain how Mark found the coordinates.

### Scratch voices and casting

Jason and Orac use their established game profiles. Mark currently uses
`am_michael` with line-specific delivery settings as a **temporary audition**.
That is also Rob's existing profile: it is not acceptable final casting for both characters.
A distinct Mark voice/performance must be selected and reviewed before
production integration. Local Kokoro synthesis proves timing and playback,
not emotional acting quality. Do not claim this is a performed final script.

No background score is approved yet. The optional low-level browser ambience
is a temporary texture, deliberately below speech. Production needs a sound
edit: cards, glass, chair, station machinery, ship departure and the withdrawal
of familiar sound at arrival. Avoid a beat-driven trailer track under the warning.

## Review findings and remaining quality gates

The timing review iterations are represented in the current revision-4
141.35-second illustrated animatic, the separate 82.35-second Godot bar study,
and the newer hybrid poker-table review. Twenty clips are checked against the
canonical script and timeline; the Godot bar export's fifteen clips are
verified in the final movie against their subtitle-timed sources. The hybrid
review retains the revision-5 movie's complete audio track and captions.
This does **not** certify final cinematic integration.

The final lap-rest bar pass passed 101 Godot checks and seven Node edit checks.
The H.264/AAC movie fully decoded, all fifteen dialogue clips passed identity
and sync verification, and the reviewed frames confirm that no hand mesh is
visible. This is a polished **bar-study review**, not the complete final
opening: departure, space travel, ring approach, final character rigs,
distinctive Mark casting and production sound remain open.

The newer [poker-table review](./renders/ash_meridian_opening_poker_v01.mp4)
supersedes the lap-rest footage only for visual blocking: its four rigged
hands are visible on the tabletop and its first 82.375 seconds use the existing
canonical poker dialogue. Its remaining illustrated shots, scratch voices and
audio-driven facial blocking are explicit review limitations, not production
approval.

Remaining production problems:

1. The drawings are deliberately graphic. They are storyboard compositions,
   not the cinematic-quality character and environment assets requested.
2. Mark needs a more distinctive, older, travel-worn final design and proper
   performance. The simple current face cannot sell fear through animation.
3. Use reverse coverage and action inserts; a slow zoom cannot replace acting.
4. The station needs depth, believable launch clearance, scale and moving
   traffic. Its final design must remain original.
5. The ring needs a consistent physical model, nonrepetitive major structures,
   recognizable former habitation on its inner face and an approach route.
   The scale targets in the illustrations remain provisional pending the
   habitat's engineering and rotation design.
6. Final space shots need continuous ship motion and camera staging, not
   motion across one flat image. The planet's surface needs authored detail.
7. Voice casting and final emotional inflection still need human approval.
   The speed/pause/punctuation pass improves scratch cadence but is not a
   substitute for a performed take. Sound mix, shot continuity, motion
   smoothness and readability also need human audiovisual approval.

Do not wire this illustrated review into New Game as if it were the finished
opening. Preserve the existing working opening until the complete replacement
passes normal playback, skip at each beat, pause during speech, mute, title
return, save/load and the existing landing/intro regression tests.

## Runtime integration boundary

The current Cursor task is preproduction art/animation investigation, not
campaign integration. First establish acceptable character assets, a seated
still, and a short motion proof using the
[Cursor 3D opening handoff](./CURSOR_3D_OPENING_HANDOFF.md). Only after the
user approves the visual direction should a separate task implement the
cinematic controller or connect the sequence to campaign flow. Do not modify
campaign flow as part of the current review effort.

Contract for that future implementation:

- Keep the sequence outside the old phase-number table until a complete
  state-transition change has been designed; do not renumber legacy phases.
- New campaign only: station scene → departure → arrival → approach →
  mandatory cockpit briefing → existing landing → campaign yard.
- Legacy/dev StartRun and save loading must not acquire an unexpected prologue.
- One owner for cinematic picture, dialogue, input and music. Stop all of them
  on skip/title return. Consume the skip input so it cannot also skip briefing.
- Voice completion drives subtitle timing. Muted dialogue uses authored readable
  durations. Never silently fall back to a robotic voice.
- Pause freezes both playback and camera/character motion. Resume does not
  repeat a line. Skip keeps Mark's directions in the briefing and does not
  grant the Commander without visiting the stash.
- Replace the current Orac recap rather than repeating the entire wager
  after showing it. Keep the mandatory orange-gate instructions.
- Use original, approved assets. Reuse the actual Ash model and existing
  Jason/Orac speech identities.
- Attach regression evidence and rendered captures; passing code tests
  alone is not creative approval.

## Rebuilding the review

From the repository root, generate speech with the existing local Kokoro
installation:

```sh
./Godot_v4.6.1-stable_linux.x86_64 --headless --audio-driver Dummy \
  --path samples/games/ash_meridian_part1 \
  --script res://tools/audio/bake_opening_animatic.gd
node samples/games/ash_meridian_part1/tools/build_opening_animatic.mjs
node --test samples/games/ash_meridian_part1/tools/test_opening_animatic.mjs
```

For a portable subtitled 720p/24 fps review movie, run:

```sh
node samples/games/ash_meridian_part1/tools/export_opening_animatic.mjs \
  /absolute/path/outside/runtime/assets/ash-meridian-opening-animatic.mp4
```

The export uses the same measured dialogue and edit, with camera moves and
dissolves. It contains scratch dialogue, not the optional browser ambience
or a final soundtrack. The offline HTML remains the interactive review.

The baker refuses robotic fallback, records profile/text/duration provenance,
and requires `ffmpeg`/`ffprobe`. The builder verifies the voice text before
assembling the timeline; it extends shot durations rather than cutting speech
or overlapping dialogue. `--art-only` regenerates drawings without assembling
the voice-backed review. No package installation is required.
