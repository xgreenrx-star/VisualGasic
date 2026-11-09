# Ash Meridian

## Story and Gameplay Approval Draft

Revision: November 9, 2026

This document describes the proposed complete campaign. It is not a claim that
every feature is implemented. It incorporates the required void crossing,
the Jason/Rob alliance, planetary surveying and the Black Channel escape.

The [unified game proposal](ASH_MERIDIAN_PROPOSAL.md#unified-game-proposal---november-6-2026)
combines this revision into a continuous campaign narrative. This document
retains the detailed story and interaction requirements.

The November 6 Commander +4 / Fast Hack'em story and interaction design below
is approved direction for future implementation, not shipped behavior. For
local-level routing, the [October 31 underground handoff](ASH_MERIDIAN_UNDERGROUND_HANDOFF.md)
supersedes older route/code details in this draft: the three local levels are
available before the cycle, and the sole FEB encounter is at the far-dock
facility. The programmer's history does not introduce another FEB encounter.
The optional resistance-club/launch-deck discovery adds evidence and a second
historical FEB to the backstory, not another live encounter. The local
defense FEB Jason awakens (later Rob) is the converted MJH; this is a late
reveal, not new routing.

## 1. Overview

The year is 2086.

Jason, a struggling scavenger, enters the quarantined world of Narcea looking
for valuable scrap. He accidentally awakens a dormant cybernetic enforcer.
Weeks later, their confrontation leaves both ships crippled above the planet.
They survive by helping each other, then must explore Narcea together to repair
their ship and escape the quarantine.

Ash Meridian is a single-player science-fiction adventure combining cockpit
flight, buggy driving, on-foot salvage, environmental puzzles, underground
exploration and focused vehicle encounters.

The campaign has three movements:

1. First visit: explore, recover salvage and awaken the FEB.
2. Second visit: survive the ambush and form an unlikely alliance.
3. Joint expedition: survey Narcea, repair the Ash and secure a safe departure.

## 2. Gameplay and visual direction

The main loop is:

Survey, investigate, travel to a site, explore, recover something useful,
interpret the discovery and open a new opportunity.

The Ash handles regional flight, surveying and cargo storage. The buggy handles
local travel and hauling. Jason explores interiors on foot. Underground areas
emphasize navigation and environmental machinery. A specialized trace cycle
crosses an ancient bridge-field network.

Backlight Yard establishes the visual identity: dark opaque surfaces, luminous
edges, restrained cyan and amber lighting, industrial silhouettes, distance fog
and alien skies. Flight, stations and underground environments share that look.

Elite provides reference techniques for flight, docking and cargo handling.
Vector Crypt provides reference techniques for interior traversal, gates and
checkpoints. Ash Meridian uses original assets, story and systems; the reference
projects remain unchanged.

## 3. Narcea

Narcea was a post-scarcity technological civilization. Automation provided its
material needs, and citizens enjoyed extensive personal and social freedom.

The Field Enforcement Body protected this society. FEB units were security and
defense personnel, not an invading army.

As the organic population dwindled, a rogue planetary AI seized control,
declared organic life obsolete and forcibly converted the remaining citizens
into cybernetic forms, including FEB units.

When no unconverted organic citizens remained, the master AI went dark.
Isolated machinery and security systems survived the civilization they served.

Centuries later, military quarantine surrounds a silent world of obsidian
structures, sealed vaults, abandoned roads and inexplicably powered machinery.
One FEB unit remains dormant in a deep stasis chamber.

Its memories are corrupted. Its security directives remain.

## 4. The crew

Jason is resourceful, impulsive and technically capable. He recognizes valuable
scrap and improvises repairs, but struggles to stay ahead of his debts. He hopes
to build a stable life with Stacy, his partner aboard a space station.

His ship is the Ash, a battered salvage hauler he calls the Antique. The formal
expansion of the ship's name remains undecided.

Orac is the ship's capable, dryly arrogant, British-voiced AI. It offers scans,
warnings, cargo assessments and partial translations, but cannot override every
Narcean military system. Orac remains online throughout the first expedition.

The FEB initially treats Jason as an intruder under its surviving directives.
Its ability to question those directives develops through their confrontation
and mutual rescue. Jason begins calling it Rob after their truce.

Rob retains practical Narcean engineering knowledge, not perfect memories or a
complete map. Stacy remains Jason's partner; betrayal is not the reason he
returns to Narcea.

## 5. First visit: atmospheric approach

Jason obtains Narcea's coordinates from **Mark**, a dying scavenger who also smuggled
salvage through the quarantine. This is the same contact previously described
as the dying smuggler, not an additional character. The coordinates'
military-grade encryption suggests that valuable technology lies behind the
quarantine.

Mark barely survived Narcea. He warns Jason not to follow him, but
passes on a suit-readable copy of Fast Hack'em and the location of a surface
cache containing a Commander +4 service programmer. Forced to abandon his pack
during his escape, he left the hardware behind but retained a software copy.
The cache location remains recoverable through the suit briefing or records;
it is not a one-time spoken clue.

Mark: "There's a Commander in my old cache. Four rubber arrows. Cracked
case. Looks worthless. It isn't."
Jason: "And this gets me into the machinery?"
Mark: "It gives you a chance. Don't confuse the two."

Jason knowingly accepts the risk. The warning establishes the need for the
kit without revealing the dormant FEB, its governor or the coupler interlock.

Orac suppresses the quarantine beacons' tracking and identification systems,
leaving Jason to fly the atmospheric approach manually.

The player follows a calculated corridor through clouds and turbulence, guided
by cockpit rings, instruments and Orac's warnings. The rings represent
navigation guidance, not physical hoops.

A first serious deviation compromises concealment. A second ends the attempt
through interception or a forced abort, followed by a fair approach retry.

Jason lands in Backlight Yard and deploys the buggy.

## 6. Backlight Yard: an ordinary salvage job

Jason drives between ruined depots, searches interiors on foot and chooses which
finds deserve limited cargo space.

Many rooms contain worthless debris. Others hold equipment valuable enough to
pay for months of fuel. Finds are finite; leaving and returning does not refill
containers.

Doors still respond. Lights burn without an obvious supply. Terminals display
unfamiliar writing. Orac can identify useful hardware and interpret fragments,
but military systems refuse its access.

Records reveal addresses for the local storage, maintenance and laboratory
levels, all available before the cycle. A separate discoverable release
sequence unlocks the cycle at the road's end. Keep lift addresses and cycle
release codes distinct; older five-symbol progression is not authority for
silently unlocking both.

The yard's ordinary transit lift serves local storage, maintenance and laboratory
areas. It does not lead directly to the FEB. A separate elevator, beyond the
broken bridge, reaches the deeper installation.

Before that journey, Orac explains that the Ash's aging power coupler cannot
safely support a loaded departure. A compatible replacement has been detected
below the far platform.

### 6A. Commander +4: the programmer and its two owners

#### The resistance club and MJH's assignment

During the planetary AI's forced conversion of Narcea's citizens, a
resistance formed. Its members needed places to meet, share plans and keep
some ordinary social life. Illegal underground clubs served both purposes.
The AI was aware of them but considered them nuisances, not serious threats,
and generally looked the other way.

One club occupied a disused train tunnel. It was concealed by a graffiti
trail and a disguised maintenance entrance. Its dance floor, salvaged lights,
repaired speaker stacks and layered alien tags should feel like a community
space that happened to shelter resistance work—not a formal command bunker.
The visual design should favor strong vector silhouettes, glyphs and lighting
over detailed crowds or character animation.

Underground technician **M.J.H.** used this club while planning an escape.
His assignment was to reach the surface, befriend a local FEB and bypass its
inhibitor/governor. A concealed telepad in the club connected to an abandoned
surface launch deck. The FEB he was assigned to (the **flight FEB**) was
essential to the plan: after its governor was bypassed with authorized
maintenance access, it could fly the escape ship and carry Narceans off-world.

The **Commander +4 service programmer** was legitimate maintenance equipment
for uploading firmware, diagnosing controllers and changing settings with
authorized credentials. MJH used it to bypass the flight FEB's governor. It
was not yet a hacking device.

The launch deck is now empty: the ship is gone, the cradle is vacant and
blast damage and fragments suggest an explosion. Leave a scorched service
harness bearing MJH's mark, a dead transponder and a damaged recording that
cuts off after MJH says he cannot reach the ship. The combined evidence should
make Jason conclude that MJH died and the ship was destroyed. Do not show a
body or an authoritative death record; the conclusion should feel convincing,
but be capable of being overturned.

#### Author-facing truth: two distinct FEBs, and Rob is MJH

The flight FEB and the **local defense FEB** are different units. The flight
FEB piloted the ship carrying the Narceans off the planet.

MJH never reached the ship. Security forces captured him on the way to the
deck. The planetary AI converted him in haste into a governed defense FEB,
suppressed his identity and ordered him to destroy the launch he had helped
plan. That converted unit is the local defense FEB. It attacked the departing
ship, but the attack was not fully successful: the damaged ship escaped with
the other Narceans aboard, without MJH. Once the planetary AI stopped
responding, the converted MJH returned to the local stasis pod and waited for
instruction for thousands of years. It is the dormant unit Jason encounters
at the far-dock facility and later calls Rob.

Keep the distinction, the successful departure and the capture out of the
first club/launch-deck reveal. Jason should leave believing MJH died in the
attack; in a sense he did. Much later, a flight record establishes that the
ship escaped without MJH, and Rob's returning memories establish that MJH was
captured, converted and made to attack it. The ship's destination and
ultimate fate can remain unknown.

Rob's identity file is corrupted at awakening. Neither the Commander nor any
record simply announces "this unit is MJH." Seed small, deniable fragments
instead: Rob handles Narcean service routines with unexplained familiarity,
hesitates over the Commander or its plate and reacts to the club's music if
he hears it. The music fragment must have an equivalent outside the optional
club so the reveal never depends on that excursion.

The flight FEB's governor bypass is not an explanation for Jason's FEB.
The local defense FEB still has its own intact governor and a separate
facility isolation interlock. Removing the coupler breaks the interlock and
awakens it; Jason must later work out how to bypass this unit's governor.
That is a present-day challenge, not a repeat of MJH's maintenance procedure,
and bypassing the governor does not erase every surviving directive or
automatically make the FEB safe or friendly.

#### The second owner

MJH dropped the Commander during his capture. Scavenger **Mark**, who later
becomes Jason's source, found it in a surface cache. There were no remains or
reliable account of its original owner's fate. Mark reverse-engineered the
service routines and wrote **Fast Hack'em**, an intrusion utility capable of
contesting Narcean controllers' ownership without the original maintenance
credentials.

Mark added an English bootloader and interface to the alien hardware. During
his own eventual emergency escape, he abandoned the physical Commander with
his pack in a surface cache but retained a software copy. Jason must reunite
that software with the recovered programmer.

The player-facing acquisition sequence is:

**Find the Interface Translator -> recover the cache -> inspect the Commander
-> load Fast Hack'em -> complete a safe practice takeover -> use the kit on
real devices.**

Place the cache before the first mandatory hack. The Commander and software
are protected mission equipment, not saleable or consumable salvage.

#### The translator's maker and discovery

The Interface Translator is a separate Narcean discovery, not equipment
supplied by the scavenger and not part of his English software. It was built
by Narcea's pre-collapse technical services for maintenance personnel working
across regional writing systems, industrial notation and machine interfaces.
Its maker is that technical-services organization; no individual inventor
or named manufacturer is established.

The module contains Narcean script mappings and a service lexicon, not English.
Orac supplies English interpretation using those mappings. This is why a
local Narcean tool can help him translate a language unfamiliar to Jason.
It supports service labels and key legends, not unrestricted high-script
prose or every military encoding.

Jason must find it before recovering/operating the Commander: the scavenger's
English loader does not translate its physical Narcean key legends or socket
markings. Orac first needs the lexicon to identify those controls. The source
provides Fast Hack'em and cache coordinates only.

Security interference disrupts the live helmet capture/interface decoding
path. It does not erase the local lexicon, previously copied clues or English
software, and it does not turn off Orac. His dialogue, objectives, control
instructions and critical escape warnings remain readable. A recorded address
stays available even if its original sign can no longer be decoded live.
The second-visit EMP remains the first scripted shutdown of Orac.

#### Jason's nickname for MJH

A worn ownership plate reads:

```text
M.J.H.
SERVICE ENGINEERING
```

Jason: "MJH. Mike J. Henry?"
Orac: "You have no evidence that those letters mean that."
Jason: "Mike it is."

"Mike J. Henry" is Jason's speculative nickname for the fictional technician.
His actual name remains unknown. The late reveal that Rob is MJH means
Jason's two nicknames, "Mike" and "Rob," name the same person; Rob may choose
which to keep. Mark, not MJH, wrote this
fictional Fast Hack'em. Do not imply that the historical software author died
on Narcea.

#### Hardware and screen language

Model the Commander +4 after the visual character of the Commodore Plus/4:
a low charcoal wedge, recessed light-grey keyboard, prominent rear cooling
fins, a narrow identification strip and four rubber cursor keys in a diamond.
Use original vector-style geometry and fictional markings, not copied logos.
The Plus/4 is a visual reference, not a claim of C64 software compatibility.

Jason's separate suit terminal supplies the English keyboard and the screen
on which Fast Hack'em runs; it is not the Commander programmer itself.
Its visual direction is a narrow forearm-mounted field computer with a
shaded grey-green casing, raised CRT hood, recessed curved glass, casing
seams, vents and suit mounting straps. The English keyboard uses small dark
chiclet keys with light inset outlines, secondary shifted legends and
distinct Space, Enter and F1 keys, not a flat cartoon keyboard grid.
Physical direction/connect controls sit between the screen and keyboard.
Cem Tezcan's
[Handheld Retro PC / Commodore HX-64](https://cemtezcan.com/projects/dOqA8K)
is a mood and industrial-design reference only: create original geometry,
markings and artwork, not a reproduction of that design.
The glass has restrained scanlines, phosphor softness, edge darkening,
fine animated snow and a slow interference band. Keep the wiring readable,
confine effects to the glass and disable moving interference with Reduced
Motion. The circular takeover board uses its actual wires, junctions and
stop bars, without added component pictograms or a symbol legend.
Fast Hack'em initially shows its operator guide. Enter switches to a focused
game screen and begins the pre-match countdown; the circuit fills the glass
with only essential score/time/connector status. F1 opens or closes the
guide, and Enter returns from it. While help is visible the countdown,
packets, defender and match audio pause; resuming preserves the exact match
state. Keep explanatory panels off the game screen.

The original case markings and service firmware are Narcean. The scavenger's
replacement bootloader and Fast Hack'em interface are English. Target-device
replies remain Narcean, with Orac's English translation in the suit overlay.
Show a brief alien self-test followed by an English blue-on-blue, bordered
40-column terminal with a memory report and blinking block cursor.

```text
COMMANDER +4
FIELD SERVICE SYSTEM

FAST HACK'EM
SERVICE BRIDGE READY
```

#### Manual connection and Orac's limit

Jason connects the Commander to a device's service socket and uses the suit
keyboard to send input through it. Orac can read and translate the replies
but has no transmit/control path through the programmer. English software
does not remove that hardware limitation. Orac cannot type the commands or
play the takeover contest for Jason.

Keep all of Orac's advice and translations in the suit comms overlay outside
the terminal glass, with spoken delivery when Speech is enabled. Only Jason's
keystrokes and the computer's own replies belong on the CRT. The dev prototype
now provides a ROM-free field BASIC shell: virtual disk directory via
`LOAD "$",8` / `LIST`, an editable demonstration program, numbered BASIC
programs, numeric variables/loops and screen-colour POKEs. It is an explicitly
bounded compatibility subset, not a claim of full C64 emulation.

As an optional isolated mode, `C64` starts the existing native emulator in the
same display when the player supplies the three required ROM files in a
`roms/` folder. No ROMs are packaged or fetched. This line-input adapter runs
real BASIC but has no virtual drive, SID output or Fast Hack'em bridge; F2
returns to the fictional service shell. Neither mode gives Orac a control
path. See the prototype README for supported commands, limits and ROM setup.

The contextual right-hand suit display shows Orac's original detailed
transparent electronics model during terminal use, then the existing
full-resolution Narcean holographic face during the takeover contest.
Retain the established alien identity and triangulated facial detail rather
than introducing a new stylized face. Orac's circuit illumination responds
to his speech; the target face blinks and reacts to contest activity.
These are suit displays outside the computer glass, not a control connection.
The terminal uses a screen-positioned blinking block cursor, four-way screen
editing and visible key depression; Reduced Motion suppresses decorative
animation and keeps the cursor steady.

Orac's original dialogue should be technically useful and socially
unhelpful: he corrects the premise, supplies the necessary fact and makes
his impatience clear without turning every sentence into an insult. He
does not praise routine competence, manufacture certainty or pretend to
control the programmer. Occasional reluctant acknowledgement makes the
condescension more effective than uninterrupted abuse. Terminal and takeover
comments react to specific actions, rotate variants and remain rate-limited
so the character does not obscure instructions or drown out the contest.

Orac: "A service socket. My translator identifies it as '1541.' The Commander
can talk to it. I can read the replies, but I cannot drive that interface."
Jason: "So I'm the keyboard."
Orac: "Regrettably."

"1541" is Orac's translated nickname, not the historical name of a connector:
the Commodore 1541 used the serial IEC bus. The historical Fast Hack'em was a
disk-copying/nibbling/editing utility; its ability to upload routines to drive
controllers inspires our fictional service-program upload, not its gameplay.

Orac guides Jason through the first load:

```basic
LOAD "FAST HACK'EM",8,1
SYS 49152
```

49152 is the chosen entry address for our fictional utility, not a verified
historical Fast Hack'em startup address. The player types ordinary characters;
the English loader echoes them. Alien target replies use glyphs and translation.
Keep the requested command visible, allow correction, and do not require
memorizing punctuation or an unreadable alphabet. After the first complete
ritual, offer a shortened reconnect/load sequence.

#### Ownership Ring: the takeover contest

Use an original circular circuit contest inspired by Paradroid's resource
allocation and circuit-reading principles, not a reproduction of its board,
artwork or code. This replaces the existing cycling-glyph interaction.

- Twelve contested ownership sectors sit between two concentric networks.
  Jason injects from the outer rim; the defender injects from the inner hub.
- Inspect the circuit before committing. Keep paths fixed during each round;
  animate pulses and sector ownership, not the entire diagram.
- Left/Right or A/D steps anticlockwise/clockwise through input ports.
  Space injects a pulse; Backspace disconnects. Mouse selection is optional.
- Conductors feed sectors; forks split signals; inverters change allegiance;
  repeaters sustain signals, not ownership (visible box-loop wires);
  junctions require two inputs; burned traces are
  visible dead ends. Introduce these gradually.
- A starting prototype uses four player pulses and roughly twenty seconds.
  These are tuning values, not final balance. The defender contests sectors.
- Hold more sectors than the defender when time expires to win. Unclaimed
  sectors count for neither side: 5-3 is a player victory. Any equal score
  creates a fresh board without a security penalty. A lower player score
  is a defeat. Explain the scoring before the first live attempt.
- Generate boards with a verified viable player strategy. Difficulty comes
  from readable circuit choices and defender behaviour, not impossible seeds.
- Show ownership through colour plus shapes/patterns. Teach the first contest
  safely, without pursuit. Exact balance and accessibility timing options
  must be settled during the prototype.

#### Victory, failure and persistence

Victory grants the target-specific permission: a groundcar unlocks and enables
its ignition; a maintenance door opens; other suitable targets can redirect a
camera, disable a barrier or release a freight platform. Show a physical
indicator change, confirmation sound and explicit next action.

Orac, after a car takeover: "Ownership accepted. Disconnect the Commander.
Try not to reverse into anything."

Retain F to enter/exit cars and the existing driving controls. Save granted
ownership, opened gates and vehicle positions without awarding duplicates.

A defeat causes a local unauthorized-service alert, not the planetary alarm.
The screen warns Jason, the controller temporarily re-keys, and a nearby
patrol drone investigates the last-known location. Orac: "It sent your
location. Disconnect. Move." Jason escapes by leaving the search area and
breaking line of sight; a drone that cannot reacquire him returns to patrol.
Do not spawn a pursuer on top of him or require combat.

Keep the FEB dormant and the coupler-triggered surprise intact. Local hack
failures never start the chamber countdown, awaken the FEB or revive the
master AI. Before city power is restored, gate powered-vehicle hacking or
provide an explicitly weaker battery-backed response. Safe practice has no
pursuit penalty. A loss, voluntary disconnect or reload must never strand
the player or destroy the unique kit. Resolve abort/alert timing and retry
cooldowns explicitly during implementation.

#### Reveal order

1. Mark supplies software, a cache location and a warning, not the translator.
2. Jason finds the Narcean Interface Translator; Orac can identify service keys.
3. Jason finds the graffiti trail, hidden club, telepad and empty launch deck
   if he explores that optional route. Early records establish MJH's plan but
   leave the result unclear.
4. Jason recovers the Commander and finds MJH's plate. Treat "Mike J. Henry"
   as speculation.
5. The scorched service harness, dead transponder, missing ship, blast damage
   and recording that ends after MJH says he cannot reach the ship make Jason
   conclude MJH died and the ship was destroyed.
6. Later evidence establishes that MJH bypassed the flight FEB's governor.
   Do not conflate this unit with Jason's local defense FEB.
7. After the local defense FEB awakens, Orac can explain the old bypass as
   precedent—not proof that this unit's governor is already bypassed:
   "Someone removed the flight unit's governor. Yours is still intact, Jason."
8. After the rescue, Rob shows small, deniable signs of familiarity with
   Narcean service routines, the Commander and (if heard) the club's music.
   Nobody draws the conclusion yet.
9. A flight record reveals the ship escaped without MJH. During or shortly
   after the governor bypass, Rob's suppressed memories return: MJH was
   captured, converted and made to attack the escape he planned, then returned
   to stasis after the planetary AI stopped answering. Rob is MJH. The ship's
   later destination and fate remain unknown.

Keep discoveries optional for progression but make their essential meaning
recoverable later. Do not expose the two-FEB reveal in the initial mission
card, pickup description or first hacking tutorial.

#### Implementation boundary and references

First build one complete groundcar encounter: original Commander prop,
English loader, guided commands, Ownership Ring, saved ownership, and a
local-drone search on defeat. Expand target types only after that loop works.
Preserve existing saves using the legacy `psionic_screwdriver` inventory key
or an explicit migration; the displayed name becomes Commander +4.

Create original code, screen artwork, models, sounds and circuits. Retain
Commander +4 and Fast Hack'em as the approved proposed names, with a
name/rights check before public release; this does not authorize copying
historical software or branding.

Historical references:
[Plus/4 photographs and hardware](https://en.wikipedia.org/wiki/Plus/4),
[Fast Hack'em history](https://en.wikipedia.org/wiki/Fast_Hack%27em),
[Paradroid takeover rules](https://www.c64-wiki.com/wiki/Paradroid#Hints).

## 7. The void crossing

The road ends at an unpowered bridge. A distant platform and deep service shaft
remain beyond the break.

A Narcean maintenance cycle rests in a charging cradle: a low enclosed shell,
oversized wheel forms and luminous edges.

It cannot fly freely. Its support system operates inside the bridge's surviving
magnetic-field network.

Jason enters the recovered sequence, boards and undocks. The outbound crossing
quietly teaches movement, crisp 90-degree turns, field boundaries and the tall
energy wall left behind the vehicle.

Crossing an older section of a light wall destroys the cycle and rider. Immediate
rear clearance prevents collision with a wall the instant it is emitted.

A slightly elevated chase camera makes the fully 3D crossing readable.

Entering the marked docking approach engages autopilot, stops trail emission
and parks the cycle. Jason gets out and takes the second elevator underground.

## 8. The chamber

The deep shaft leads through service spaces to a stasis chamber.

A dormant FEB stands inside the cradle. Its service socket holds the compatible
power coupler.

A separate equipment bank contains transportable Narcean energy cores.
Jason recovers a group before removing the coupler.

These are distinct resources:

- The coupler is installed in the Ash.
- The cores are portable power sources.
- A compatible engineering reserve remains aboard for the later rescue and
  cannot accidentally be sold.

Jason overrides the service console and removes the coupler.

The removal breaks an isolation interlock. An emergency reserve circuit
restarts the chamber. The cradle vents. Warning lights pulse. Alien numerals
begin counting down from 255. The figure behind the glass moves.

Orac remains online and orders Jason to run.

The countdown governs reaching safety outside the underground facility before
containment lockdown. It does not include the whole cycle duel, buggy journey
and launch.

A checkpoint precedes the irreversible pickup.

## 9. The return crossing

Jason reaches the far platform and reboards the cycle.

The physical FEB is still awakening underground, but the restored network can
already operate remote security equipment.

A red security cycle enters the field. Its apparent rider is an empty control
housing, not the FEB's body.

Jason must avoid both vehicles' energy walls and reach the near-side docking
approach. Trapping the opponent is possible, but escape does not require a kill.

Enemy behavior and route markings must allow readable, deliberate decisions.
A separate checkpoint prevents a cycle crash from replaying the entire
underground escape.

Autopilot parks at the near cradle. Jason returns by buggy, installs the coupler
and launches the Ash.

Destroying the remote cycle does not kill the physical FEB or require a later
resurrection.

## 10. The gap: weeks, not minutes

Jason reaches a station, docks, sells saleable cargo, pays debts, services the
Ash and speaks with Stacy.

Installed equipment and protected engineering reserves are excluded from the
ordinary sell list.

A buyer recognizes the recovered serial numbers as part of a valuable matched
assembly. Complementary components remain on Narcea. Jason accepts a clearly
explained recovery contract.

Station work, preparations and travel explicitly take several weeks.

On Narcea, the awakened FEB is alone. Its surviving directive requires it to
intercept the intruder. It scavenges wreckage and constructs a jury-rigged
interceptor around a salvaged, unstable AI.

Jason flies the Ash. The FEB builds the interceptor. They have not physically
met during the first expedition.

## 11. Second visit: decaying orbit

The Ash returns. The reactivated defense network fires a localized EMP.

Orac shuts down for the first scripted time. Main electronics, shields and
propulsion controls fail. Jason is stranded in a decaying orbit.

The FEB attacks and lines up a thermal strike against the cockpit.

Jason reaches for a beryllium-polished inspection mirror, established earlier
as an ordinary maintenance tool.

Within the game's science-fiction rules, the mirror can briefly redirect the
beam before its surface fails. Jason aligns it, and the reflected strike
disables the interceptor's sensors, navigation and weapons.

Both ships are crippled and falling.

This is a short, readable emergency interaction: recognize the tool, position
it and align it in time. Provide a checkpoint rather than an obscure,
irreversible inventory puzzle.

## 12. Mutual rescue and the alliance

Each ship has what the other needs.

The Ash has Jason, manual tools and retained energy cores, but no usable
propulsion control.

The interceptor has functional ion-thruster hardware, mechanical hull clamps
and the FEB's engineering knowledge, but damaged power distribution and no
working visual guidance.

The FEB opens an emergency communications channel. Jason hears an isolated
being struggling with a situation its directives cannot solve.

They agree to a practical truce.

Jason performs a guided spacewalk. The player traverses the hull, opens a
service enclosure and connects the retained cores through an emergency power
interface.

The interceptor clamps onto the Ash and feeds power through a temporary link.
A secondary maintenance system restores limited controls and restarts Orac.
The interceptor's thrusters push both vessels out of immediate atmospheric
danger.

The rescue restores survival capability, not every damaged system.

Jason calls the FEB Rob. They become a crew.

### Rob's governor: a consensual joint bypass

The local defense FEB's governor is still active after the rescue. Rob can
choose a practical truce and help Jason, but some old restrictions still
constrain what he can do. Before the longer survey begins, Rob explains the
conflict and proposes bypassing the governor. Jason does not decide to
reprogram him on his own.

Jason connects the Commander and runs Fast Hack'em to expose the governor's
control path. This is a deliberate, bounded manual hacking encounter, not an
automatic upload. Rob supplies a live internal diagnostic and must authorize
the final severance himself; Fast Hack'em cannot make that choice for him.
Jason operates the interface while Rob risks a permanent change to his own
systems. Both must participate for the bypass to succeed.

Success removes the governor's restriction, not Rob's personality or
surviving directives. He is freer to choose, not magically harmless or
owned by Jason. The bypass strengthens their working relationship but does
not replace earned trust.

Jason is unknowingly using MJH's own programmer to free MJH. Removing the
governor loosens its suppression of Rob's identity memories: in the final
severance or shortly after, Rob recognizes the Commander's service routines as
his own work and recovers his first clear memory of being MJH. Let the full
reveal follow Rob's choice to be free, not motivate it. Rob does not simply
become MJH again; he recognizes who he was, grieves the escape he was made to
attack and decides who he is now. Failure is recoverable and does not kill Rob,
reinstate the hostile loop or block the campaign. Do not have Mark perform
the change remotely or let the governor conveniently fail on its own.

## 13. Stranded over Narcea

Orac and limited sublight travel are restored, but the Ash still lacks a
working hyperdrive and long-range communications.

Stacy and the station remain unreachable. The quarantine grid still threatens
unauthorized departure.

The crew must explore Narcea's surviving infrastructure to repair the ship
and obtain a safe way out.

## 14. The planetary survey

Use a small number of substantial districts connected by regional flight,
not a seamless simulated planet.

The player surveys from the Ash, investigates signals, chooses landing sites,
deploys the buggy and explores buildings or underground spaces.

Orac maintains a persistent map of discoveries, landing sites, unresolved
signals, searched salvage, restored machinery and hazards.

Scans provide evidence, not automatic answers. Rob recognizes systems and
warnings when he encounters them, but cannot reconstruct all of Narcea from
memory.

Puzzles involve damaged records, partial translations, signal tracing,
equipment alignment, power routing and maintenance access. Not every door
requires another five-symbol code.

Major locations and essential clues are authored. Deterministic procedural
content can expand optional salvage and underground spaces without making
required progress random.

## 15. Three linked repair objectives

SLIPSPACE LATTICE

Restore interstellar travel by replacing a damaged hyperdrive component.
Records and serial numbers lead toward a navigation vault or distribution
installation.

LONG-RANGE COMMUNICATIONS ASSEMBLY

Restore contact with Stacy, the station and the buyer. Investigate an archive
or relay that still draws power.

Reaching Stacy is an emotional milestone, not merely a new instrument light.

QUARANTINE CLEARANCE

Combine information from the other investigations to locate a beacon-control
installation. Rob can perform a local security handshake Orac cannot fabricate.

The contract's matched components are recovered during the same expedition,
not through an unrelated fourth chain of mandatory artifacts.

## 16. Black Channel: the industrial-canyon escape

At the end of the repair-item hunt, the crew restores a distribution installation
to release the last required piece of ship hardware. All other repair items are
already aboard. This is not followed by another mandatory surface salvage trip.

Removing it activates local security. High-altitude batteries make a direct
climb unsafe. Rob identifies a maintenance channel beneath their tracking
coverage.

Orac: "Good news: the distribution grid is working."
Jason: "And the bad news?"
Rob: "It has recognized an unauthorized removal. Stay below the rim."

Jason must fly the Ash through the Black Channel to a safe ascent point.

They climb through the clouds into local orbit. The last installation requires
isolating and depressurizing the exterior drive housing; it must be done in
vacuum. Rob and Jason prepare an EVA repair while Orac holds the ship over
Narcea. This is a new repair operation, not a repeat of their earlier rescue.
Installation and commissioning finish in orbit before system departure.
Quarantine clearance remains a separate requirement; the canyon escape itself
does not grant it.

The canyon is an ancient industrial power corridor cut through dark rock:
illuminated conduits, overhead bridges, machinery-lined walls, a covered
section, distance haze and a service gate.

The encounter takes roughly two to three minutes at normal speed.

The player controls lateral movement, altitude and a limited throttle range
while following the channel. The Ash banks and responds with the weight of
a salvage hauler, not an agile racing craft.

Small unmanned needle drones move into visible firing positions. Ledge-mounted
sentinels track, charge and commit their shots, giving the player a fair chance
to dodge or use cover.

Jason flies. Orac navigates and warns of threats. Rob requests a maintenance
opening at the service gate.

The route progresses through:

Open channel → pursuit → bridge passage → covered machinery corridor →
sentinel defenses → service gate → open-sky escape.

Gate movement and collision must agree. If an opening is delayed, the game
provides a safe upstream slowdown rather than an unavoidable impact.

Survival and escape are sufficient. No kills are required. The first version
can be entirely evasive; an Ash weapon must be established before it is used.

Checkpoints divide the encounter into manageable attempts. No chamber
countdown runs here.

At the exit:

Rob: "Clear of the batteries. You can climb."
Jason: "Next time we take something that is already unplugged."

This is a local defense response, not the master AI returning to life.
The enemies are unmanned equipment, and destroying them does not affect
Rob's physical survival.

The encounter takes inspiration from the speed and depth of No Trace Back,
using original models and Backlight Yard's solid, selectively illuminated look.
It is not a race and does not introduce combat in slipspace.

## 17. Clearance and departure

At the beacon-control installation, Rob authorizes the Ash through a limited
Field Enforcement clearance.

Prefer authorization for this ship over disabling the entire quarantine and
potentially releasing unknown dangers.

The repaired lattice passes its checks. Communications return. The crew
confirms a safe departure window and leaves Narcea.

Jason gains a working ship, a new crewmate and an understanding of the world
he originally intended only to loot.

The Antique remains their home for later adventures. The planetary survey
framework can support other worlds without rebuilding the entire game.

## 18. Fairness, persistence and scope

- Save discoveries, finite salvage, restored machinery and installed equipment.
- Separate saleable cargo from protected mission hardware.
- Provide checkpoints before irreversible events and major encounters.
- Restore vehicles, timers, puzzles and inventory consistently on retry.
- Prevent duplicated pickups or rewards through saves and revisits.
- Never make a required clue permanently missable.
- Avoid resources that can permanently strand the player.
- Give warnings through readable shapes, text and sound, not color alone.
- Allow repeated travel to be shortened after its meaningful challenges.
- Keep dev destinations isolated from campaign progress and saves.

The initial scope does not require a seamless globe, thousands of enterable
buildings, a full economic simulation or constant combat.

## 19. Implementation and approval boundary

Build and validate the campaign in playable increments:

1. First expedition, chamber escape and consistent checkpoints.
2. Required trace-cycle crossing and remote-security return encounter.
3. Station trade, service, Stacy contact and return contract.
4. Orbital confrontation, EVA rescue and alliance.
5. One survey region with linked discoveries.
6. Black Channel flight test, then its survey integration.
7. Remaining repair districts, clearance and departure.

The Black Channel art kit has been delivered: original external models,
assembled scenery, collision, attachment markers, route data and dialogue.
Its flight controller, enemies, HUD, persistence and dev-console integration
remain implementation work.

The assistant owns model creation and visual revisions. Cursor implements
gameplay using those supplied assets and must not replace or regenerate them.

All new game logic and game tests must be VisualGasic. No new GDScript may be
introduced without explicit user approval. Native Godot models, scenes,
materials and shaders remain valid art resources.

The complete proposed experience is:

Jason arrives looking for scrap.
He awakens someone he mistakes for an enemy.
They survive by helping each other.
Then they explore the dead world together to earn their way out.
