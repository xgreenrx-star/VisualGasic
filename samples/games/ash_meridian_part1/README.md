# Ash Meridian — Part 1

Jason scavenges Narcea with Orac, the Ash's onboard assistant. The campaign
uses Backlight Yard's buildings, materials, distance fog and sky. Orac remains
online throughout this first expedition and helps Jason locate salvage and
the power coupler needed for a loaded departure. Removing that coupler from
the underground chamber breaks its isolation interlock and awakens the FEB
(Field Enforcement Body).

**October 31 planning:** the
[underground handoff](../../../docs/development/ASH_MERIDIAN_UNDERGROUND_HANDOFF.md)
plans three distinct local levels before the cycle, a sole FEB encounter at the
far-dock facility, and consolidation of the real yard and ride. These changes
are not yet implemented; current Play still has the old underground chamber.

## Play

**Opening cinematic preproduction:** the separate
[141-second voiced animatic](assets/opening_cinematic/index.html) and
[production/storyboard brief](../../../docs/development/ash_meridian_opening/OPENING_PRODUCTION.md)
cover Mark's wager, warning, station departure and the ring approach. Open
the HTML in a browser and press Play. It is an illustrated review, not final
character animation; the live game still uses its existing opening. The
[central MP4 review export](../../../docs/development/ash_meridian_opening/renders/ash_meridian_opening_animatic_v05.mp4)
is the complete illustrated cut.

**In-engine bar staging:** open [opening_bar_study.tscn](opening_bar_study.tscn)
for an isolated 82.35-second 3D pass with the revised dialogue and reverse
coverage. Hands are intentionally hidden at lap level after review found the
procedural hand pose unconvincing; no visible hand reaches for the coordinate
device. Revision 4 adjusts phrase pauses and pacing, while the neural voices
remain scratch performances rather than finished acting. The look-development
pass adds smoother stylized faces, blinking, clip-driven mouth motion, shaped
jackets, and a detailed cyan/amber bar. It starts paused; Play, Mute,
scrubbing, Space pause and Escape skip are available. The character meshes
are staging assets, not final cinematic characters or phoneme lip sync.
The separate [rigged-character study](../../../docs/development/ash_meridian_opening/character_audition/README.md)
records the earlier silent tests and the rejected CC0 poker-table review
(`ash_meridian_opening_poker_v01.mp4`, kept as a failure reference only).
The current 3D review is [ash_meridian_opening_v07.mp4](../../../docs/development/ash_meridian_opening/renders/gate7/ash_meridian_opening_v07.mp4),
with a [subtitle sidecar](../../../docs/development/ash_meridian_opening/renders/gate7/ash_meridian_opening_v07.srt).
It keeps the accepted gate 6 character animation and adds a rebuilt bar,
glassware, and a true-scale Narcean ring with an atmosphere. The ship descends through the ring's clouds to the Backlight Yard landing gate.
Play shows that cut before Orac's approach warning. Escape, Space, Enter, or a
click skips it, and either skipping or letting it finish is remembered, so the
next Play goes straight to the approach.
The [central review export](../../../docs/development/ash_meridian_opening/renders/ash_meridian_opening_bar_v04.mp4)
is separate from runtime assets. Movie capture hides the review controls. See
the production brief above for launch, capture and regression-test commands.

### Story document and approved hacking revision

The [unified game proposal](../../../docs/development/ASH_MERIDIAN_PROPOSAL.md#unified-game-proposal---november-6-2026)
combines the full campaign with the Commander history in one narrative.
The [complete story and gameplay draft](../../../docs/development/ASH_MERIDIAN_APPROVAL_DRAFT.md)
retains detailed requirements. Its November 6 revision records the approved
[Commander +4 / Fast Hack'em history and interaction design](../../../docs/development/ASH_MERIDIAN_APPROVAL_DRAFT.md#6a-commander-4-the-programmer-and-its-two-owners):
MJH's original maintenance programmer, the surviving scavenger's English
software, Jason's manual suit-keyboard connection, the Ownership Ring contest
and local patrol-drone alerts on failure. The governor-bypass explanation is
withheld until after the FEB awakens. The complete encounter is **planned**;
the campaign currently uses the Commander with the cycling-glyph hack
described below. The implemented translation prerequisite and compatibility
handling are described next.

**Mark's stash:** Jason won Narcea's coordinates from Mark Mitnick in a card
game. Mark survived his visit, warned Jason away, and gave him the stash
location when Jason decided to go anyway. In campaign play, press F1 for the
directions: east of the yard road, near the broken amber drain marker. Park,
walk into the small shelter and press F to recover the Commander +4. It is
protected in the pack and persists in campaign saves; translation is not needed
to pick it up. The full Commander/Fast Hack'em campaign encounter is not yet
connected. The screwdriver is shelved in campaign; older saves carrying it
receive the Commander instead. It remains in the standalone deep-stratum
prototype for compatibility.

**Language progression:** Orac cannot initially translate Narcean. Archive
workbenches copy visible glyphs into the journal without explaining their
meaning. Match those shapes at early locks and lifts; no translator pickup
is present. Address consoles likewise copy shapes without exposing their
translated records. Reach Alien in the club backroom: he learns English,
explains why he chooses to help, and gives Orac a Narcean service lexicon.
Only then do visor translations, song titles and the programmer's service keys
become readable. Standalone Deep Stratum previews remain intentionally ungated.

Language knowledge persists as `stratum.narcean_lexicon`, separately from
`alien_english`. Older saves with an Interface Translator migrate it to learned
knowledge. Older programmer-only saves retain usable equipment through the
existing explicit compatibility migration. New empty saves gain no translation.
An older English-only encounter can resume the conversation and receive the
missing lexicon. TRACE YARD retains its translator flag for legacy/preview
states, not as a new-run pickup or an early lift requirement.

Security interference affects live visor decoding, not recorded journal
glyphs, objectives, controls or Orac's English messages. The planned Commander
model/cache, English loader and local-drone failure response
are **not implemented by this prerequisite increment**. The Ownership Ring
now has the separate dev prototype described below. The current kit's
name, location and campaign cycling-glyph game remain until the next increment.

### Fast Hack'em development test

The **FAST HACK'EM - OWNERSHIP RING** destination on the dev terminal's main
SCENES page opens the new circular hacking prototype immediately. Open the
terminal with **Up, Up, Down, Down, Left, Right, Left, Right, B, A, B, A**,
select that destination and press Enter. Alternatively launch directly:

```bash
godot --path samples/games/ash_meridian_part1 -- --hack-test
```

For the earlier boot-and-command sequence, select **FAST HACK'EM - BOOT /
COMMANDS** on the same dev page, or use `--hack-boot-test` instead.
Type `LOAD "FAST HACK'EM",8,1`, press Enter, wait for the load, then type
`SYS 49152` and press Enter. Orac gives the requested commands in the **suit
comms overlay outside the glass**, and speaks through the existing Orac voice
pipeline when **Speech** is enabled. He never writes to the computer display
or supplies keyboard input. Backspace corrects input; errors stay on the
computer transcript and leave the input editable. SYS opens the operator
guide below. This entry is
isolated from campaign inventory and saves, just like the direct board test.

#### Field BASIC terminal

This ROM-free service shell is a deliberately small C64-style BASIC, **not
a C64 emulator**. It accepts commands rather than enforcing a two-line script:

```basic
LOAD "$",8
LIST
LOAD "DEMO",8
RUN
NEW
10 FOR I=1 TO 5
20 PRINT "HELLO ";I
30 NEXT I
LIST
RUN
POKE 53280,2
POKE 53281,0
POKE 646,5
```

- `HELP` lists commands. The virtual field disk contains `FAST HACK'EM` and
  an editable `DEMO` BASIC listing; `LOAD "*",8,1` selects Fast Hack'em.
- Numbered lines insert/replace program lines; a bare number deletes a line.
  `LIST`, `NEW`, `RUN`, numeric variables/`LET`, `PRINT` (strings, expressions,
  semicolon joining), `FOR/TO/STEP/NEXT`, `GOTO`, `REM`, `END` and `STOP` work.
  Expressions support parentheses, unary signs and `+ - * /`.
- `POKE 53280,n`, `POKE 53281,n` and `POKE 646,n` change the actual border,
  background and text palette. Other POKEs affect a private sandbox memory
  dictionary, not the host or a real C64; `PEEK(address)` reads it.
- `Esc` breaks a running BASIC program; otherwise it opens the pause menu.
  Execution yields after 32 statements per frame and reports an error after
  10,000 statements. Programs allow 100 lines, 16 nested loops, expression
  nesting of 24 and numeric magnitudes up to 10^15. Input is limited to 120
  characters and wraps across 38-column screen rows.
- The cursor is a blinking block immediately below `READY.`, not a detached
  bottom input bar. All four arrows move through screen text and blank cells.
  Move up to an earlier command or listed program line, overwrite characters
  and press Return to execute/store the edited line. Home/End and Backspace
  use the native editor. Reduced Motion keeps the block steady.
- The illustrated chiclet keys depress when typed (including the cursor,
  Return, Space and Delete keys); held keys remain down until released.
- This subset has no arrays, string variables, `IF`, `GOSUB`, arbitrary
  machine-code `SYS`, filesystem access or saved programs. Unsupported input
  produces an explicit error. Programs and POKEs reset on a fresh dev entry.
- `SYS 49152` requires Fast Hack'em to be loaded. **F2** returns from the
  hacking screen to the service terminal; a subsequent SYS starts a fresh
  match. The existing direct board shortcut remains unchanged.

#### Optional real C64 mode

Type **`C64`** at the service prompt to start the existing native
`VGC64Machine` inside the same CRT. It uses real BASIC/KERNAL/character ROMs,
not the subset above. No ROMs are included or downloaded by this feature.
Install your own legally obtained ROM files under `roms/` in this game folder:

| Filename | Exact size |
|---|---:|
| `basic.901226-01.bin` | 8192 bytes |
| `kernal.901227-03.bin` | 8192 bytes |
| `characters.901225-01.bin` | 4096 bytes |

For exported games, use `user://roms/` in Godot's application user-data folder;
a complete set there takes precedence over `res://roms/`. Missing, unreadable
or incorrectly sized ROMs report an error and leave the service shell usable.
Do not add ROMs to source control or redistribute them with the game.

Allow about five seconds for boot, then type at the real machine's blinking
cursor and press Enter. Printable keys, all four cursor directions, Home,
Delete and Return go through the real KERNAL keyboard buffer; typing and
screen editing appear directly in its framebuffer, with no second input bar.
This is not a full keyboard-matrix/joystick frontend. It adds no disk drive,
cartridge loader or SID audio. The service shell's virtual directory and
Fast Hack'em upload are **not** attached to the emulated machine. **F2**
returns to the service shell and releases the emulator; starting `C64`
again cold-boots it. Pause/dev menus freeze execution; changing scenes ends
the terminal session. Orac still has no input path in either mode.

#### Contextual suit display

The right-hand suit panel shows an original dimensional logic-core model
while the terminal is active: clear casing, horizontal tube banks, circuit
cards, bundled cables and ribbed conduits. Its illuminated circuits pulse
more strongly during Orac's speech, with rate-limited original electronic
chatter through the Effects bus. The model is original geometry; no reference
photographs, television footage or recordings are bundled.
Six internal indicator bulbs and three coloured local lights pulse
independently, illuminating the case interior; Reduced Motion holds them
steady.

During Fast Hack'em, the panel switches to the **existing full-detail Narcean
alien face** from `assets/ai_face/alien_face.json`, not the reduced
`alien_face_small.json` or a replacement character. All 335 mesh vertices,
571 shaded triangles, 908 wire edges and 30 feature polylines are retained.
The face blinks, drifts its gaze and reacts to circuit attacks and ownership
changes. Reduced Motion stops decorative core movement/pulsing and facial
blinking/drift. Both panels remain outside the CRT and show no Orac transmit
or computer-control capability.
Portraits update at up to 20 Hz independently of input and game simulation.
The detailed face's shaded triangles use one indexed render batch rather
than hundreds of separate polygon submissions; its geometry is not reduced.
`test_suit_panel_performance.gd` measures gameplay with the face visible and
hidden to separate portrait overhead from the remaining board-rendering cost.
Ring controls remain Left/A counter-clockwise and Right/D clockwise.

#### Narcean defender voice

The takeover defender uses short edited phrases from the original Undercity
`alien_murmur.ogg` synthetic voice, not English TTS or a new translated script.
Different rhythms and pitches convey threats at connection, mocking insults
after wasted paths or recaptured sectors, shock when Jason steals a sector
or reaches four, curses at seven sectors or defeat, and gloating on a failed
takeover. These are fictional alien utterances, not a fully specified language.
No glyphs, English translations or speech subtitles are drawn.

The existing Speech option gates the voice; its player uses the SFX bus and
plays at -3 dB (six dB above its initial level), ducking to -12 dB under Orac.
Optional taunts have a four-second cooldown with no queue.
Shock and majority reactions each occur once per round; results supersede
unfinished phrases. Help/pause freezes playback, and terminal mode, disconnect,
new boards and scene exit stop it.

The full-detail face follows the measured source-audio envelope at the actual
playback position, with jaw/lip motion, subtle head movement, blinking and
angry/startled eye poses. Reduced Motion keeps the face steady without muting
speech. Portrait rendering retains the existing 20 Hz limit and mesh batching.
`test_suit_defender_voice.gd` checks events, playback, variants, lip/head poses,
pause, speech gating and cleanup.

#### Orac dialogue direction

Suit-terminal commentary is original writing, not dialogue copied from
*Blake's 7*. Orac treats himself as an independent analyst, not a cheerful
assistant: exact terminology, impatient corrections, reluctant approval and
no social cushioning. His technical observation should remain useful even
when his delivery is condescending. Avoid constant insults, modern meme
phrasing, unexplained omniscience and claims that he can operate the programmer.

The contextual bank in `suit_orac_dialogue.gd` rotates variants for syntax
errors, missing files, premature SYS, BASIC failures/limits, directories,
palette experiments, program execution, stopped paths, joins, repeaters and
win/loss/tie results. Optional comments have a 14-second cooldown, expire
after at least 12 seconds (never while that voice is still playing) and never
queue behind active speech or interrupt required instructions. Commentary
appears when playback actually starts, not when synthesis is requested.
Essential command instructions remain immediately readable. Generated suit
Orac clips are cached locally under `user://suit-orac-voice/` for instant reuse;
cache keys include text, backend, voice and delivery settings. First-time
uncached speech still requires local synthesis. Results replace stale commentary.
No periodic idle nagging is
scheduled; Speech-off retains subtitles without queuing voice. Scene exit
clears both. `test_suit_orac_dialogue.gd` covers routing, variety, cooldown,
subtitle expiry and speech gating.

To prepare all fixed suit Orac lines in advance using the installed local
Kokoro/espeak backend, run from this sample directory:

```bash
ASH_SPEECH_LIVE=1 godot --headless --audio-driver Dummy --path . \
  --script res://tools/precache_suit_orac.gd
```

This performs offline generation without changing the selected voice or
shipping generated audio. It skips existing clips and verifies that a cached
line starts in under 100 ms without a synthesis job. Preparation can take
several minutes on a CPU. New instructions supersede obsolete queued guidance;
Orac's activity lights now follow playback, not the synthesis request.

Tests: `test_ownership_ring.vg` covers the shell, bounded interpreter, speech
gating and game integration. `test_suit_terminal_input.gd` exercises actual
keyboard events and rendering. `test_suit_c64.gd` checks ROM loading and,
when `ASH_C64_ROM_DIR` points to your ROM folder, real boot, POKEs and a BASIC
loop. The graphical input test accepts the same variable for a C64 round trip;
`ASH_TERMINAL_CAPTURE_DIR` optionally selects an existing screenshot directory.

The sandbox opens on an **operator guide**, with no running match timer.
**Enter** closes the guide and shows the circuit with a five-second countdown.
**F1** toggles the guide from the circuit or result screen; **Enter** also
returns from help. Opening help freezes the countdown, packets, defender
and match audio without resetting connectors or ownership.

On the game screen, **A/D or Left/Right** selects an outer port. **Space** installs a connector,
ends the opening countdown immediately and starts the fight; otherwise the
fight begins automatically when the countdown reaches zero. **Enter** starts
early without spending a connector. Both sides have four connectors.
Both networks have **two component stages**, not direct port-to-sector
shortcuts:

- **SPLIT:** the middle input feeds the two neighboring output lines, not its
  own middle output. A later split can branch these again.
- **JOIN:** both neighboring inputs must be powered at the same time to feed
  the middle output. Repeated shots on one input cannot substitute for the
  other; expired input power does not count.
- **STOP:** a red perpendicular cap ends the wire before the junction, with
  a visible gap. Packets stop there; there is no hidden route through it.
  Unused inputs of splits and joins are capped as well.
- **REPEATER:** an activated generator keeps emitting after its incoming
  connector expires. It does **not** make a sector immune to enemy signals.
- **INVERT:** the triangle/bubble changes colour at that stage. Two inverters
  in succession restore the original colour.
- **LINK:** an ordinary uninterrupted wire.

There are no added component pictograms or symbol legend. Read the actual
wires, junctions and stop bars; follow both stages to determine an input's
final destinations. Cyan
player packets travel inward, orange defender packets travel outward, and
arrivals flash the destination. Splits and joins have their own short local
arcs connecting adjacent lines, rather than a shared whole-board bus or
diagonal chords. Packets branch only when they reach a component, and use the
same paths as the drawn wires. Sector labels **P / D / -** show player,
defender or neutral ownership without relying on colour.
The dedicated game screen fills the glass with the circuit and only essential
score, time, connector count and a short F1 prompt. Pre-attack markers remain
on the inner network. Detailed instructions live on the separate guide,
not beside the board.

An installed connector sends a packet every 0.65 seconds for 4.5 seconds;
activated repeaters remain powered until the match ends. Each circuit stage
takes 0.2 seconds at the fixed simulation tick rate. Ownership changes
when packets reach the ownership ring, and recurring streams can recapture
enemy sectors, including sectors supplied by repeaters. Marks remain in their
last owner's colour after a stream expires.
The defender reads its own inner network and connects useful circuits from
0.8 seconds onward, targeting player territory where possible. It uses the
same components, recurring flow, connector budget and expiration rules.

Existing original electronic SFX provide selection ticks, injection bursts,
lock/charge feedback, defender chirps and win/loss cues through the **Effects**
volume bus. A bounded eight-voice pool allows overlapping shots without
restarting every branch's sound. Pause, menus and leaving the sandbox suspend
its audio; retry clears old packets and sounds. There are no imported
Paradroid graphics or recordings. Circuit behavior was checked against the
local reference video around 47 seconds and the original developer's
[description of the transfer game](https://programmingconceptsblog.blogspot.com/2017/04/the-paradroid-transfer-game.html).

The game is presented inside Jason's narrow forearm terminal: an original
shaded grey-green housing with a stepped CRT hood, casing seams, vents,
mounting straps and recessed English chiclet keys. The dark keytops have
light inset outlines, small shifted legends and separate Space/Enter/F1 keys
instead of the previous flat keyboard grid. The visual reference is Cem Tezcan's
[Handheld Retro PC / Commodore HX-64](https://cemtezcan.com/projects/dOqA8K);
no artwork, logos or model assets from that project are included.
The glass-only shader adds scanlines, subtle phosphor glow, vignette, fine
snow and a slow interference band. **Reduced Motion** in Options disables
the animated interference; the housing and keyboard remain unfiltered.
This is the suit's display/input terminal, separate from the Commander +4
service programmer connected to the target.

The housing is one static texture rather than per-frame procedural drawing.
Its editable original source is `assets/ui/suit_terminal.svg`; regenerate
the runtime texture with:

```bash
inkscape samples/games/ash_meridian_part1/assets/ui/suit_terminal.svg \
  --export-type=png \
  --export-filename=samples/games/ash_meridian_part1/assets/ui/suit_terminal.png
```

Own more sectors than the defender when the twenty-second match ends to win.
Unclaimed sectors count for neither side: 5-3 wins; 3-5 loses; any equal
score (including 0-0) is a tie. The centre shows the result and final score.
**Up** switches to optional safe practice on the startup guide or during the opening countdown;
**Down** toggles its timer. Untimed practice keeps streams running until
**Backspace** disconnects; spending all connectors does not end it.
Each rotated board is tested against an actual winning late-connection
strategy through the defender's final stream. These timings and the four
connectors per side are prototype balance, not a claim of exact historical
Paradroid difficulty. **Backspace** disconnects; **Enter** after a result
opens a fresh board's guide; Enter then reveals its countdown.
Any tied score has no penalty. **Esc** pauses; the dev terminal can change scenes.
**F10** returns to the retained campaign when one exists.
The existing hidden developer-menu sequence also works on the startup guide,
live board, result screen and focused service terminal. It opens the same dev
menu without restarting the current board. Held-key repeats do not advance it.

This is a board/controls prototype, not a finished encounter: ownership and
local alerts are simulated text only, and no car or pursuing drone is spawned.
It does not include the Commander prop or campaign
integration. Existing campaign hacks are unchanged. Neither Save nor retries
write campaign or legacy chapter saves. Logic and integration coverage lives
in `test_ownership_ring.vg`.

Open this folder in Godot 4.6 with Visual Gasic enabled and press F5.

```bash
./Godot_v4.6.1-stable_linux.x86_64 --path samples/games/ash_meridian_part1
```

### Current campaign increment

Press **F1** to open or close the four-line Orac briefing. It is hidden by default,
does not pause gameplay, and remains available after searching archives.
It identifies Jason as a scavenger, Orac as the Ash's
onboard assistant, and the replacement power coupler needed for a loaded
departure. It also explains the first action: walk to a lit building door,
press **F** to enter, then **F** at its rear workbench to search.

The **CURRENT JOB** readout stays beneath the HUD header independently of timed
messages and nearby interaction prompts. It explains the five building glyphs
and Deep Transit lift code, advances to underground address exploration, and
directs Jason to all three transfer-station bus levers while the Undercity is
unpowered. Once power is restored it resumes the coupler search; recovery changes
the job to returning to the Ash. Jobs derive from existing progress, so saves
need no migration. New games and Continue start with the briefing closed.
The briefing does not reveal the coupler's isolation interlock or FEB.
The **BACKLIGHT YARD** development destination also shows the briefing and current
job; its briefing retains the prototype's additional ship-parts requirement.
It remains a development demo and cannot overwrite the campaign save. Other
development destinations retain their existing HUD.

The yard-only cradle deck sits above the yard floor, with its luminous guides
raised to match; the shared crossing cradle and its collision are unchanged.
Buggy idle, loaded drive and coast loops use smooth periodic tones without
synthetic freewheel clicks, square-wave buzz or noise layers. Healthy motors do
not randomly pop or drop out, and pitch rises continuously with speed. Damage
and turret interference retain their distinct fault cues. Gravel remains audible
at a reduced level rather than masking the electric motor. Audio synthesis
regressions run with `python3 -m unittest discover -s tools/audio -p 'test_*.py'`.

Undercity window-light changes use staggered 24-second intervals with roughly
two-second fades; isolated terminal windows breathe slowly instead of blinking.
Near the powered talking-face hologram, music fades down by up to 12 dB within
25 metres horizontally, tapering to normal at 65 metres. Leaving the area,
switching floors or losing grid power restores the score gradually. This uses
the music players' levels and does not change the player's saved volume sliders.

The project boot splash uses the Narcean Technologies logo at
`assets/branding/narcean_logo.png`. That PNG is converted from the unchanged
copy `assets/branding/narcean_logo.jpg`, taken from
`scratch/Lucid_Music/NarceanTech_logo1.jpg`. Godot only accepts a PNG for the
boot splash. The earlier Lucid sketch remains in that folder and is no longer
the boot image. This replaces the game's engine boot image, not the Godot
editor's own splash. The square logo keeps its aspect ratio on the black boot
background and has a 2.5-second minimum display time.

After the splash, `boot_terminal.vg` plays a ~5-second green CRT boot log
(`shaders/boot_crt.gdshader`) written in Narcean glyphs. Orac's overlay sweeps
down and translates it to English. The translated log stays readable for
under a second before the carrier corrupts it under a static surge. The face
intro then pushes through the static over 1.6 seconds, brightest lines first.
Setting `PUSH_THROUGH = False` restores the alternate ending, where the tube
collapses to a dot and the face irises open from it. Audio is one
timeline-matched track per ending in `assets/boot`, generated by
`tools/boot_audio.py`: hum, flyback whine, relay ticks per line, Orac's chirp
and sweep, the static surge, a hard thunk on the cut, and a decaying hiss
tail. Click, Space, Enter or Esc skips to the static surge. Reduced motion
removes static and tearing and fades instead.

The 16-second face film continues inside a recessed CRT surround with curved
edges, green phosphor noise and moving scan bands. The same face starts turned
away with closed eyes, opens its eyes unevenly, looks toward the viewer and
turns to hold eye contact before the jaw opens at 4.8 seconds. A faint signal
echo settles, the carrier quiets into an electrical inhale, then the existing
robotic scream and mouth-tunnel plunge take over. The CRT bands bend toward
the mouth and the surround fades out during entry. Reduced motion still skips
the film; the live title fade and skip controls are unchanged.
Offline sources are in `tools/ai_face`: `render_video.py`, `face.py` and
`scream.py`. `test_render_video.py` checks the wake timing, deterministic CRT
noise, render dimensions and final black frame. Rebuild with Python plus NumPy,
SciPy, Pillow and FFmpeg (use a temporary directory for the PNG frames):

```bash
python3 tools/ai_face/render_video.py /tmp/ash-face-frames 60 alien holo
python3 tools/ai_face/scream.py /tmp/ash-face-audio.wav
ffmpeg -y -framerate 60 -i /tmp/ash-face-frames/f%04d.png -i /tmp/ash-face-audio.wav -c:v libtheora -q:v 7 -pix_fmt yuv444p -c:a libvorbis -q:a 6 -t 16 assets/ai_face/intro_alien_holo.ogv
ffmpeg -y -i assets/ai_face/intro_alien_holo.ogv -vn -c:a copy assets/ai_face/intro_alien_holo.ogg
ffmpeg -v warning -i assets/ai_face/intro_alien_holo.ogv -f null -
python3 -m unittest discover -s tools/ai_face -p 'test_*.py'
```

Trace Cycle has an isolated dest so the supplied kit can be ridden, taken
through the far lift and vault, then chased on the return crossing. It does
not change Play. The ride is first-person; a live exterior feed and a flat
tactical map sit in the dashboard. A/D is a 90-degree left/right turn. Relays
are numbered link sockets to pass through, not pylons to ram.
Open [trace_cycle_test.tscn](trace_cycle_test.tscn) and press **F6**, or choose
**TRACE CYCLE** on the development destination menu (F5, then the dest list).
**VAULT** starts already docked at the far cradle so the lift/FEB pickup can be
reviewed without riding the crossing. The legacy wireframe **FEB** chamber is
under **ARCHIVE**.
The TRACE CYCLE, VAULT and TRACE YARD menu destinations use
`yard_void_field.tscn`, with the near cradle at `YardDock/DockPose` on the
yard's north rim. The smaller `void_crossing.tscn` remains an automated
crossing fixture and static art preview. Campaign save version 1 is never
loaded or written by these destinations.
See the [cycle sheet](assets/trace_vault/concepts/trace_cycle.png),
[vault/FEB sheet](assets/trace_vault/concepts/feb_vault.png) and
[Cursor handoff](../../../docs/development/ASH_MERIDIAN_TRACE_VAULT_HANDOFF.md).
The assistant owns original models/art; Cursor owns VG gameplay and tests.
The existing campaign still uses its procedural FEB/cradle prototype.
The native [model scenes](assets/trace_vault/scenes) include player/remote
cycles, docking cradle, relays, articulated FEB/stasis cradle, removable coupler,
core bank, vault and separate deep-lift landing. The 160x240 m support field has
two docks and three relay sockets. Four static previews remain available.
The crossing now has open space between cliff banks instead of a rendered
floor/grid. Distant ruins, faint lights and layered patchy haze are far below
the ride height; they are non-colliding depth scenery, not traversable ground.
Invisible support uses collision bit value 4, outside the ride obstacle mask.
The tactical map runs outbound from bottom to top and retains its relay/dock
markers after initialization. Unknown-collision and cyan turn-artifact reports
remain open for Cursor; see the latest corrective section in the handoff.
No direct film references are intended in the game.
`trace_route.vg` and `test_trace_route.vg` hold the isolated stage/save contract.
Play and campaign save version 1 are unchanged. Local lift codes `11111` /
`22222` / `33333` are development placeholders for storage, maintenance and
laboratory rooms. First-release riding saves restore the last safe dock only.
Those three local interiors are still unauthored. Campaign version 2 and
Play wiring still wait; the TRACE CYCLE dest now includes the far lift,
vault/FEB pickup, return chase and surface buggy escape as an isolated review.

Open [cycle_preview.tscn](assets/trace_vault/scenes/cycle_preview.tscn),
[vault_preview.tscn](assets/trace_vault/scenes/vault_preview.tscn),
[asset_gallery.tscn](assets/trace_vault/scenes/asset_gallery.tscn) or
[crossing_preview.tscn](assets/trace_vault/scenes/crossing_preview.tscn),
[yard_field_preview.tscn](assets/trace_vault/scenes/yard_field_preview.tscn) (the proposed
yard-wide void field, art only) or
[backlight_cycle_combined.tscn](assets/trace_vault/scenes/backlight_cycle_combined.tscn)
(combined Backlight yard + trace cycle scene, with the far secondary dock) or
[translator_preview.tscn](assets/trace_vault/scenes/translator_preview.tscn) (Interface
Translator, release lock and code clue, art only) in Godot
and run that scene to review it without changing Play.
[test_trace_models.vg](test_trace_models.vg) passes 317/317 resource, marker, Narcean-script,
geometry and articulation checks. [test_trace_cycle.vg](test_trace_cycle.vg)
covers the crossing fixture and menu destinations at 248/248 (including helmet HUD, underground enclosure, visor translation interference, in-cabin lift arrivals, the stasis capsule and dodgeable vault defence), including real-frame turn, trail-span,
model-faces-travel and named-collision checks. While riding, the camera sees the
original bike cockpit ([trace_cockpit.tscn](assets/trace_vault/scenes/trace_cockpit.tscn)):
a clear raked windscreen with a cyan rim and glass HUD (speed, trace count,
next relay), plus a binnacle, bars and grips. It is on render layer 3, so the
exterior monitor never shows it. Relays use a Trace-On handshake: ride
into a relay's lit lane (cyan rails, amber chevrons) toward the next relay
and its mast sinks so you pass over the pad and link. A cross-lane
approach hits the solid mast and reports a pylon crash. A gold objective line
always states the next step. After the third link, an amber beacon marks the
far dock; enter it from the south. Then press E for the deep lift, take the
core and coupler in the vault, and ride back under the green near-dock beacon.
The Trace Cycle/vault lift now uses a 5.4-second cabin ride in both directions:
doors close for 0.7 seconds, the cabin and on-foot camera travel 32 metres
through a stationary, window-visible illuminated shaft over 4 seconds, then
the cabin docks at the destination before its doors reopen. The player remains
inside, facing out toward the vault or surface lobby, and walks out manually.
The cabin's native floor indicator uses Narcean stroke glyphs only. There is no
second English sign: Orac translates nearby interface labels in a screen-space
helmet readout, including `00 - SURFACE DOCK` and
`B04 - ISOLATION VAULT`. Floor glyphs use the same word-hash/stroke encoding as
the other Narcean signs. World-space English gloss labels stay hidden, including
keypad digits; normal yard play uses glyph copying before language acquisition, and high script
remains unreadable. Nearby multi-line clues remain grouped in the visor.
The readout uses translucent dark glass with a cyan chamfered frame, a glyph
row and a compact `TRANSLATED:` line. It appears for nearby text or Orac messages,
then hides when neither is present. Orac's spoken escape warning uses this same
panel, with priority over translation interference. Dark helmet edges frame
the on-foot/lift view without covering the centre; they are hidden in inspection
and bike-cockpit views.
Taking the coupler activates FEB interference: a repeating 3.2-second cycle
allows 1.2 seconds of readable reacquisition, 1 second of corrupted characters
and small horizontal jitter, then 1 second of translation-link loss. Only the
visor changes; the native lettering stays stable. Interference persists through
the return lift and escape, pauses with gameplay, and clears on a fresh run.
Objectives, controls and defence warnings remain readable. Language ownership
and clue checks are covered by [test_trace_yard.vg](test_trace_yard.vg).
Normal combined-yard mode (`yard`, including TRACE YARD) starts without the
lexicon. Scan the Narcean address plaque on the archive bay's rear wall
(x=39, z=44.12) to copy the five-symbol lift address (developer value **14242**).
The helmet stores glyph shapes, not an English translation.
The objectives guide these steps before the cycle can be boarded. The nearby
yard service tag's **2741** is a separate bike-cradle release code.
At the far lift, F opens a helmet keypad: 0-9 to enter the address, Backspace
to edit, Enter to submit, F to cancel. A glyph reference row maps keyboard
positions to visible shapes, with copied and entered glyph rows. Unscanned
clues and incorrect addresses are rejected; language knowledge is not required.
Successful entry starts the normal travelling lift.
The clue and lift authorization survive in-scene retries; they are not new
campaign-save fields. A new controller starts a fresh search. `yard_test` and
standalone crossing/vault previews explicitly skip progression; normal `yard`
does not. The older campaign's five archive-symbol puzzle is unchanged.
At docking, the travel shell is hidden and the authored landing cabin supplies
the floor and walls, avoiding overlapping surfaces. The animated doors remain.
The underground landing has an instance-specific roof, upper walls and portal
header: the shared outdoor lobby asset was open above, exposing the star sky.
The surface lobby remains outdoors.
A motor loop accompanies the ride. Mouse/A/D look remains available; movement and interaction are locked
until arrival. Pause stops both travel and motor audio. This is separate from
the campaign yard's procedural lift; both now have visible travel.
Taking the coupler wakes the FEB at 65% animation/audio speed. Orac warns at
8 seconds; the visible vault defence emitter stays offline until
16 seconds. It needs 2 seconds of clear sight to acquire the player, then
marks a fixed floor position for 1.5 seconds before firing. Move at least
1.4 metres off that position or break sight behind either solid cyan-topped
pillar to avoid the shot. Each shot has a visible beam and a recovery window;
the first hit warns and flashes red, the second is fatal. On-foot deaths keep
the on-foot camera and show the cause rather than switching into the cycle
cockpit. The return lift ends targeting; R retries the existing checkpoint.
The damage flash fades within 0.9 seconds in walking, lift and cycle states.
Both crossing dock aprons support walking after dismount; leaving their edges
still drops the player into the void.

### Backlight Yard trace-cycle cradle and power

In the campaign yard the player's Trace Cycle sits in a cradle at the north
end, beside the lift head, at `(15, 414)`; stand at about `(15, 409)` and press
F. Until the B13 Undercity transfer-station levers are thrown, the yard runs
on auxiliary power: the backlit surfaces are dimmed (`glow_gain` 0.14) and the
cradle terminal only reports that main power is off. Once the grid is live,
the yard lights come up brighter than before (`glow_gain` 1.45), and F
releases the clamps and starts the Trace Cycle ride. `res://test_backlight_yard.vg`
covers the cradle placement, prompt and power gating.

### Return to Backlight Yard and surface escape

In the main developer menu, **TRACE CYCLE**, **VAULT** and **TRACE YARD** now
continue after the return chase. Dock, then press F (E also dismounts). Control
passes to the playable Backlight Yard at the same yard-side dock coordinates,
not to an empty cliff-bank platform. The native dock and parked cycle remain;
the detailed yard replaces the crossing's static yard silhouette.
The buggy is parked just ahead at `(11, 399)`, facing south toward the Ash.
Orac's messages use the same helmet readout and the on-foot helmet frame remains.

There are eight seconds to reach the buggy before the six surface turrets
begin tracking. F boards it, W accelerates, S brakes/reverses, A/D steers,
and F parks/exits. Follow the road south to the Ash at `(0, -5)`. Turrets
acquire a clear target, show a fixed amber beam for 0.9 seconds, then fire a
brief thick red pulse at that committed position. Keep moving off the beam or
use solid buildings to break sight. A hit removes 20 suit points and slows
the buggy; it is not an invisible instant-death timer.

At the Ash, park and exit with F, then F at the ship installs the recovered
coupler and starts its visible lift-off. The surface escape has no reused
underground purge countdown. Pause freezes it. Enter after a fatal hit restores
the yard-dock checkpoint, suit and parked buggy, keeping the translator, scanned
address, coupler, cores and protected reserve; it does not replay the vault or
cycle chase. This remains session-only development progress, not campaign-save
integration or a replacement for normal Play.

[test_trace_yard_escape.vg](test_trace_yard_escape.vg) exercises all three menu
handoffs, retained hardware, safe buggy boarding, telegraphed/dodgeable shots,
building cover, pause, dock retries, the complete southbound drive and takeoff.
Run it through the existing VG suite runner. Set
`ASH_TRACE_ESCAPE_CAPTURE=/tmp/ash-yard-escape` with rendering enabled to retain
dock, buggy, targeting and firing screenshots.
This is not a chase performance or balance
test. The assistant maintains the offline original-art source:

```bash
node samples/games/ash_meridian_part1/tools/build_trace_vault.mjs --check
```

**Play** starts with Orac's approach warning, then the landing rings. The
landing is flown from the Ash's flight deck. The green marker in the centre of
the canopy is exactly where the hull will cross; keep it inside the orange ring
as the ring reaches you. The canopy shakes with speed,
cloud banks and hull strikes, and the dashboard carries Orac's descent scope
(upcoming rings), an external chase-camera monitor (no clouds), hull-stress and
thrust traces, glide altitude, the gate counter and status lamps. Strikes crack
the canopy and fill the monitors with static. When the bay opens, the buggy
rolls out into Jason's Backlight Yard expedition with Orac online. Search the depot consoles for five ordered alien
symbols, enter the address in the transit depot, explore underground, and
recover the chamber's power coupler. Escape to the Ash before the 255-second
alarm expires. The campaign launch gate requires the coupler, not the
prototype's additional regulator and ignition parts.

| Control | Campaign action |
|---|---|
| W / S, Up / Down | Walk or accelerate/brake/reverse the buggy |
| A / D, Left / Right | Turn |
| Q / E | Strafe left/right on foot |
| Mouse | Look around on foot (pointer is captured; Esc releases it) |
| F, Left click | Enter/leave the buggy or a depot, examine consoles, collect parts, use a lift or board the Ash; cancel the lift keypad |
| H | Ask Orac for a location-sensitive scan or escape hint |
| 0–9, Backspace, Enter | Enter, correct and submit a five-symbol lift address |
| V | Cycle street, district and buggy-inspection views |
| Esc | Pause; resume, save, return to title or change options |
| F10 | Resume the current campaign after visiting a dev destination |

### TRACE CYCLE model test (F6 or dest)

This is an isolated review scene, not the finished chase. Normal Play is unchanged.

| Control | Trace Cycle action |
|---|---|
| E (or F) | Board and launch from a dock after the canopy closes |
| On foot | W/S walk, A/D turn, Q/E strafe, mouse look, F or left click to use |
| W / S | Adjust speed between 24 and 64 (starts at 32) |
| A / D | Request a 90-degree turn (edge, not analog steer) |
| R | Retry the isolated run: trails, speed, relays and dock |
| I | Model inspection while docked (pauses riding) |
| 1 / 2 / 3 | Inspect player cycle, parked remote cycle, or vault preview |
| A / D, W / S | Orbit / zoom while inspecting |
| F3 | Verbose crash/collider diagnostics (off the windshield by default) |
| Esc | Pause (F5 dest uses the game pause menu; F6 toggles locally) |
| F10 | Return to Jason's campaign after a dest visit |

Campaign **Save** writes a validated, versioned
`user://ash_meridian_campaign.cfg` through an adjacent temporary file and
atomic replacement. **Continue** restores the expedition, including the
parked buggy, interior/lift position, inventory, journal and remaining alarm
time. Invalid or unsupported saves show an explanation rather than silently
starting over. Legacy `user://ash_meridian_save.txt` saves are untouched and
are not automatically migrated. Dev Backlight Yard is a separate instance;
its reset, pickups and save command cannot alter the campaign expedition.

### Deep Stratum

The building-7 transit depot lift reaches ten underground floors
([deep_stratum.vg](deep_stratum.vg)). The player rides inside the lift car;
the doors open onto the floor and a floor display shows the level. No floor
shows the sky. Five-symbol addresses are recovered from consoles, and F at a
console reads it through Orac's visor translation.

#### Floor addresses

| Address | Floor | Where the address is found | Layout |
|---|---|---|---|
| 70315 | B00 Transit Depot / Surface | B04 garrison transit index console | Ascent code; the only way back to the surface |
| 14242 | B04 Military Chamber | Backlight Yard, rear wall of the cycle bay (x=39, z=44.12) | The FEB and the power coupler |
| 31707 | B05 Maintenance Concourse | B04 garrison transit index console | Open pillared hall; derelict Trace Cycle; rad meter, star chart, sealed store |
| 52914 | B06 Service Warrens | B05 concourse transit index console | Procedural maze of hallways with timed traps and sealed rooms (buggy armour, supplies) |
| 66038 | B07 Cistern | B05 concourse transit index console | Tall reservoir with waterfalls, plants and ledges; ship scanner, relic, core gem |
| 80451 | B08 Inverted Vault | B06 warrens dispatch console | Gravity-flip pads and sentry sweeps; grade-3 vault (ship shield, buggy boost) |
| 93162 | B09 Fractured Deep | B07 reservoir control console | Pits, sparks and radiation zones; jetpack room |
| 40404 | B10 Yellow Rooms (Holding Annex) | B09 deep survey index console | Backrooms-style maze of yellow partitions with amber glow trims; sealed closet (core gem) |
| 58120 | B11 Archive Offices | B10 annex console (misfiled records note) | Office floor with alien terminals, a pulse-tile corridor, a debris-choked hall and a flooded staff room with a live cable; buggy boost, gold, relic, ship scanner |
| 36912 | B12 Verdant Gallery | B11 records index console | Terraced hydroponic gallery under magenta grow-lights; flooded lower beds, pulse plates and rubble |
| 88216 | B13 Undercity Transit | B12 gallery index console | Underground city: central transit hall, three train lines, street grid, enterable towers, plaza of ad screens, power transfer station |

Floors are also linked on foot: B04 and B05 by stairs, B05 and B06 by an
escalator, and B06 and B07 by a service lift behind a sealed door. Any other
address shows ADDRESS NOT IN SERVICE.

B10 is a 60 x 72 m grid of 6 m rooms with wallpapered partitions, damp
carpet, a dropped tile ceiling and fluorescent panels. Some panels flicker,
and a low mains hum plays on the floor. Glow lines along the wall bases and
floor grid keep the Tron look. Every room is reachable, apart from the sealed
annex closet in the far corner, which needs the Commander and language knowledge in campaign.

B11 terminals are Narcean machines, not Orac. F at a terminal opens it;
0-9 key glyphs, Enter sends, Backspace deletes and F closes. The terminal
answers in glyphs that Orac cannot translate yet. Pulse tiles fire in a
checkerboard and flicker before they turn on. Floodwater with a live cable
arcs on a timer.

B13 starts dark: trains are parked, the station boards refuse travel, and the
cars are dead. The power transfer station on the street level (north of the
central hall, x -30..-16, z 146) has three levers. When all three are pulled, the street lamps,
the plaza screens and the neon light up. The trains then run, and a moving
train hurts the player on the tracks. Station boards (F) send the player to
Neon Crossing (line 1, beside the plaza), Spire Terminus (line 2) or Halt
Junction (line 3). The Meridian tower has a lift to its roof. Cars must be
hacked with the Commander after the language transfer; F enters and leaves, and W/S/A/D drive.
The power state, hacked cars and where they are parked are saved.

Four projectors cast 3D scanline holograms under the ceiling. The largest
is the broadcast face from the opening sequence, built from the same mesh and
hung from a ceiling emitter. It turns to look down at the player, blinks,
moves its mouth as it talks, and its words fall from its mouth as glyphs.
Rooftop projectors show a turning car, a ringed planet, and a ring above the
central hall. Until the grid is
powered they show only brief glitch flashes. The face's broadcast scrolls
through several lines in the visor translation. An artificial red sun runs
along a ceiling track and follows the local system clock: it rises in the
east at 06:00, crosses to the west by 18:00, and is dark at night. During the
day it tints the city red. The city's edge is a wall of lit panels covered in
graffiti. Translated, it reads as anti-AI slogans, panic, "NO ONE IS LEFT" and
"DON'T TRUST THE FLIES".

`undercity_fx.vg` adds the B13 ambience. `deep_stratum` loads it on demand and
rebuilds it with each room. It uses its own RNG, so the seeded layout is
unchanged.

- **Power-up wave.** Pulling the last lever sends a ring of light out from the
  transfer station. Lamps, neon, holograms, tower windows and the plaza screens
  switch on as the ring reaches them, and relays clunk near the player. After
  that, light pulses run along the building edges.
- **Street.** Wet puddles reflect the neon once the grid is on. Grates puff
  steam, and only the ones near the player emit. Water drips from the cavern
  roof, and dust drifts around the player, tinted by nearby light sources.
- **Sun.** Light shafts hang under the artificial sun and follow it along its
  track.
- **Towers.** Procedural windows: some lit, some flickering, some with
  silhouettes, and a few showing terminal screens. Torn banners hang on cables
  strung between facing towers.
- **Faults.** Some neon signs have one dead glyph, and signs short out at
  random and throw sparks. Holograms glitch and stutter. Moving trains spark
  at the wheels.
- **Patrols.** Drones sweep the streets with scan beams, and two crashed
  drones still spark. Fly swarms circle the surveillance cameras, and a few of
  the flies have red eyes. The swarms scatter when the player comes close.
- **Graffiti.** Holographic tags on the city-edge wall. "NO ONE IS LEFT"
  scrolls. The visor translates the tags.
- **Lighting.** At most six fake point lights on the city shell: moving trains,
  plaza screens and drone footprints.

Returning to the surface is never automatic: in the lift car, F opens the
keypad and the ascent address **70315** must be entered (it is on the first
transit index console). The keypad lists the addresses already recovered.
The derelict Trace Cycle on B05 is cold scenery; the player's own cycle stays
docked in the Backlight Yard.

In campaign, **Mark's Commander +4** opens sealed doors once Orac has learned
the Narcean language: F at the door, then F/Space when the cycling glyph matches
the lit slot. Each door grade adds slots and the lock re-keys after a time
limit; Backspace aborts. **I** opens the pack. W/S selects an item and Enter
uses consumables: med gel restores 40 suit integrity and anti-rad purges 60
units of radiation. Each item has a resale value, but the HUD does not show
it. The jetpack thrusts while Space is held in the air and recharges on the
ground. The buggy upgrades take effect while they are in the pack: boost
raises the buggy's top speed from 18 to 22, and armour reduces turret hits
by 40% while driving. The ship modules are cargo for a later chapter.

Hazards (trip lasers, pulse barriers, crushers, vents, sentries, sparks,
radiation and pits) damage the suit. A fatal hit returns the player to the lift car with half integrity.
After the coupler wakes the FEB, the visor translation glitches. The pack,
recovered codes, opened doors, collected pickups and radiation dose are saved
in an optional `[stratum]` section of the campaign save. Older saves without
that section load with an empty pack.

`res://test_deep_stratum.vg` checks layouts, collision, lift codes, pickups,
hacking, gravity, hazards, upgrades, B10 room reachability, B11 terminals,
B12 flooding and the B13 power grid, trains, cars and reachability. `res://test_campaign.vg` checks the
stratum save round trip.

This increment ends at the first-departure overlay. It does **not** start
the old reflection encounter or restart the prototype. Flight,
station trading of salvage, the matched-component return contract and the return-only
EMP/FEB encounter remain planned. Stacy remains Jason's partner.
See the current [campaign revision](../../../docs/development/ASH_MERIDIAN_PROPOSAL.md).

### Sound and music

All sound effects and music are generated procedurally. There are no
sampled or licensed recordings. The generators are under `tools/audio/` and
need Python 3 with `numpy` and `scipy`, plus `sox` and `ffmpeg` with
libvorbis.

```bash
cd tools/audio
python3 sfx.py              # footsteps, keypad, lift, levers, grid power-up
python3 sfx2.py             # vehicles, trains, holograms, lasers, hacking, ship
python3 sfx3.py             # vehicle layers: idle, coast, tyres, skid, brake, thumps
python3 sfx4.py             # Undercity ambience: neon, steam, drones, flies, drips, relays
python3 music_undercity.py  # assets/audio/music/undercity_dark.ogg
python3 music2.py           # yard_dread, stratum_deep, chase, black_channel
```

`game_audio.vg` is a `Node` owned by the explorer and by Black Channel. It provides:

- A pool of one-shot players, plus positional (3D) one-shots and attached loops.
- Footsteps every 1.7 m walked. The surface sets the sound: concrete outside and in
  the Undercity, tile in buildings, metal on Deep Stratum floors.
- A dedicated lift-motor player and one drive loop (jetpack, ship engine) whose
  level and pitch follow speed.
- A layered vehicle mix for the buggy and Undercity cars (see below).
- An `Echo` bus (reverb, routed to SFX) for footsteps and vehicle sounds. The
  wet level follows the location: none on the surface, light in buildings and
  the lift, more on Deep Stratum floors, and most in B13 tunnels.
- A two-deck music crossfade.
- `Music`, `SFX` and `Ambience` buses. Ambience is routed through SFX.

Music by area:

| Area | Track |
|---|---|
| Backlight Yard | `yard_dread` |
| Lift cabin | keeps the current track |
| Yard awakening / trace escape | `chase` |
| Deep Stratum floors | `stratum_deep` |
| B13 Undercity (88216) | `undercity_dark` |
| Black Channel flight | `black_channel` (fades out on failure) |

Hooks:

- Keypad, lift doors, lift motor and arrival chime.
- B13 transfer station lever pulls and the grid power-up.
- Buggy and Undercity cars: see the vehicle mix below.
- Undercity trains: positional rumble and horn; holograms hum, and the talking
  face plays a soft alien murmur.
- Undercity ambience: neon buzz and crackle, steam hiss, drone hum and chirps,
  fly buzz, drips, sparks, screen boot-ups, relay clunks and hologram glitches.
  Looping sounds move to the nearest source of their kind.
- Hacking kit ticks, success and failure; alien terminals; pickups; jetpack.
- Yard turrets: lock-on and shots from the turret position; hits on foot or in
  the buggy; ship ignition at launch.
- Black Channel: ship engine hum, laser shots and hull hits.

Vehicle mix (`update_vehicle` / `tick_vehicle` in `game_audio.vg`):

- Layers: idle hum at standstill, load whine under throttle, coast whine with
  the throttle released, a tyre bed and a skid squeal. Each layer fades toward
  its target level.
- Motor pitch climbs with speed and dips once at half speed (a gear step).
- Tyre bed by ground: gravel on the surface (with random stone knocks),
  smooth Undercity streets, hollow over the B13 tunnels, metal elsewhere.
  `deep_stratum.ground_sound` picks the Undercity surface.
- Skid squeal when turning hard at speed.
- One-shots: regenerative-brake whir on braking or a sudden drop in speed,
  a thump on collisions and kerb steps, and a shut-down sound on exit.
- A damaged buggy (low shield) stutters with motor pops. The `buggy_boost`
  upgrade makes it run cleaner.
- Hacked Undercity cars use a lower motor and idle, detuned per car id, with
  an alien start chime and a power-down chime.
- A turret lock-on in the Yard adds interference crackle and pitch wobble
  while driving.

Options **MUSIC** and **EFFECTS** set the Music and SFX bus levels (0-100%,
arrow keys step 10%, mouse drags the bar). They are saved with the other
options and applied at start-up.

The `undercity_dark` track is an original 6/8 piece in the style of 1970s
Italian horror prog: a music box over a descending chromatic line, tabla and
bouzouki tremolo, tolling bells, an organ and a gliding Moog-style lead
section. The other tracks use the same palette at different tempos.
Playback is skipped while the node is outside the scene tree.
`res://test_deep_stratum.vg` checks that the assets load, that music
switches with the floor, that footsteps and sound-effect hooks fire, and
that the vehicle layers, one-shots and per-car detune behave as described.

Menu input is sampled once per game frame in the presentation adapter. The VG
menu handlers consume those samples directly, so holding Enter cannot activate
the next screen, and pause-menu Options returns to the paused game.

Options **VIEW DISTANCE** sets the camera far plane from 50 m to 600 m (arrow
keys step 25 m; default 100 m). At 600 m the whole Backlight Yard (236 x 432 m)
stays in view. Bleed City and the legacy chapter also use this value to cull
props, so long distances cost frame time there.

Options **ANTIALIASING** is independent of Detail: Off, MSAA 2x, MSAA 4x
(default), MSAA 8x, FXAA, or MSAA 4x + FXAA. MSAA smooths geometry edges;
the custom FXAA pass filters only the world image, not the separately drawn HUD
or menus. Existing options files without an AA setting default to MSAA 4x.
This project uses Godot's Compatibility renderer; built-in TAA is unavailable,
and DLAA is not integrated. Procedural window edges and water ripples also use
distance filtering to reduce subpixel shimmer.

The optional resistance club is reached from the Undercity's east train tunnel;
use the marked side refuges to wait clear of trains. Once the city grid is on,
walk to the **DJ booth beneath the video wall** and press **F** at its lit
switch to start the lights and music. The control on the right cycles flashing
lights Off/Low/Full. Real musical onsets trigger 120 ms flashes with minimum
intervals of 3 seconds (Low) or 1.8 seconds (Full); Off disables them.
The separate **track selector on the left of the booth** shows the current title;
press **F** there to cycle recordings. Your selection persists across visits,
including the muffled music outside. Changing tracks does not bypass the booth
power switch. The club uses tiled-floor footsteps and suppresses the normal
exploration score.

Take the marked passage **to the right of the DJ booth** into the private
meeting room. Its resident intelligence, **Alien**, appears as a human
holographic head. Approach him for an untranslated Narcean greeting; press
**F** near him to continue the conversation. Jason and Orac supply a language
sample and he quickly switches to English, remembering it on later visits.
Jason asks why he would help. Alien's uncertain memory that Jason resembles
former resistance visitors is not a species-history reveal. Orac denies membership; Alien chooses
to help people who ask instead of ordering him, and is quietly glad to have
someone to answer him. He then gives Orac the Narcean service lexicon. Until
this transfer, song labels and Narcean records remain untranslated; afterwards,
song titles are explicitly Orac's translations.
Jason and Orac use the same local Kokoro neural voices as the rest of the game
(`am_adam` and `bm_george`). Alien uses the distinct male `bm_lewis` voice
with a slower, dry delivery, without the previous eSpeak voice or robotic filter.
His head smoothly turns and tilts toward the player within the meeting room,
then settles forward when the player leaves.
The Speech option also controls these voices; subtitles remain available.
Alien's projector has emergency power, independent of the city grid.

The backroom telepad reaches the **ruined surface launch dock**: stand on the
ripple pad and press **F**. Alien must first restore its link during the initial
conversation; it then stays available without asking him again. No key is required;
city power is. The dock has no
ship, only an empty cradle, broken gantries, hull debris and ancient blast
damage. Four consoles hold the optional evidence records. The matching pad near
the arrival point returns to the club. This detour does not change the required
descent route.

Four original prototype tracks are installed, each a 105.1-second stereo loop:

| Track | Arrangement |
|---|---|
| The Membrane Remembers | Eerie drones and organic calls with pitch-dropping 808-style kicks in uneven clusters |
| Sleep Beneath the Glass | Ethereal, hypnotic lullaby with sustained invented Narcean vocal syllables; no kick pattern |
| Teeth of the Relay | Short alien vocal/rap-like phrases, hard sub kicks and fractured bass |
| The Floor Answers | Heavier dubstep-like growls, sub kicks and alien chants |

These are synthesized prototype compositions, including formant-synthesized
vocal syllables, not sampled singers or English songs. Unequal 7.3-12.7-second
chambers, fractional subdivisions and microtonal tuning avoid a global BPM or
regular 4/4 grid. Lights follow the selected recording's actual audio energy.
Generators: `tools/audio/alien_club.py` and `tools/audio/alien_club_set.py`;
tests: `tools/audio/test_alien_club.py` and `tools/audio/test_alien_club_set.py`.
Each recording has a matching JSON sidecar documenting its events and validation.

The Undercity ceiling is a continuous ribbed dome, rising from 60 m at the
retaining walls to 86 m at its crown. The sun carriage follows the curved roof.
Player movement limits remain unchanged. Street puddles and indoor flood pools
share a water shader, including pools carrying electrical hazards. Indoor
surfaces use their room's palette; electrical arcs add to, rather than replace,
the water shading. Reflections are procedural approximations, not planar
reflections of scene geometry. Hazard timing and existing movement penalties
are unchanged.

Run the focused checks from the repository root:

```bash
./Godot_v4.6.1-stable_linux.x86_64 --headless \
  --path samples/games/ash_meridian_part1 --script test_part1.gd
```

For rendered occlusion checks and a screenshot, use a real display or Xvfb:

```bash
ASH_VIEW=turret ASH_CAPTURE=/tmp/ash-turret.png xvfb-run -a \
  ./Godot_v4.6.1-stable_linux.x86_64 \
  --path samples/games/ash_meridian_part1 \
  --rendering-method gl_compatibility --script test_part1.gd
```

`ASH_VIEW` accepts `cockpit`, `landing`, `turret`, or `city`; with `landing`, `ASH_LAND_Z` moves the ship along the course (for example `188` is inside a cloud bank) and `ASH_LAND_HURT` (for example `0.8`) captures an active hull strike; unset it for the buggy's yard
view. The checks restore the options file to its original bytes and do not
write a game save. `YARD_FRAME_US` measures warmed redraws; `GAMEPLAY_FRAME_US`
includes real process callbacks while holding W to drive the buggy. Neither
headless timing nor software-OpenGL timing guarantees FPS on another machine.
The regression also keyboard-steers the entire landing course and checks hull
strikes, retry, bay entry, and (with a display) changing gauge and star pixels.

Trace Cycle: press **T** to shut the trace down. After a 5-second countdown the field is wiped and relays reset. The trace then returns and you restart at beacon 1.
