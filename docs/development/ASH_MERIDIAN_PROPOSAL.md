# Ash Meridian

The [unified story and gameplay approval draft](ASH_MERIDIAN_APPROVAL_DRAFT.md)
records the latest proposed campaign, including the required two-elevator
trace-cycle route, facility-only countdown and post-alliance Black Channel
escape. These proposed refinements are for approval, not claims of shipped
behavior. Earlier planning below is retained for implementation history.

## Campaign revision: Jason's first and second visits

This section supersedes the earlier Jonah/Zen/beacon storyline below. The
earlier material is retained as historical design reference, not current canon.
This is a campaign implementation plan, not a claim that the features already
exist.

### Agreed direction

- Year: 2086. Player: Jason. Ship: the Ash, affectionately the Antique.
- Ship AI: Orac. Orac stays available throughout the first landing, salvage
  expedition, underground exploration and escape. The EMP on the second visit
  is the first scripted loss of Orac.
- Planet: Narcea, an abandoned technological world inside a military quarantine.
- FEB: Field Enforcement Body. The dormant cyborg becomes Rob after the
  confrontation and alliance, not before Jason knows him.
- Stacy remains Jason's partner. A matched-component recovery contract, not
  betrayal or stolen savings, motivates the second visit.
- Backlight Yard is the campaign's default surface and visual language.
  Spacecraft, stations and underground scenery use opaque surfaces, selective
  cyan/amber illumination and the same art direction, not transparent wire hulls.
- Read `samples/games/elite_wire_slice` for flight, docking and cargo techniques,
  and `samples/apps/vector_crypt` for first-person traversal, environmental
  gates and checkpoints. Do not edit either project, reference its `res://`
  paths at runtime, or inherit its campaign, names or economy.
- Introduce traversal, environmental gate puzzles and checkpoints first.
  Gravity machinery is a later Narcean discovery; do not give Jason gravity
  or portal tools during the first run.
- All new game-owned executable code is VG. Native scenes, meshes and shaders
  remain valid resources. Do not add new GDScript game controllers.

### Approved future feature: void-road light-cycle expedition

Recorded October 20, 2026. This is an accepted design for future implementation,
not a shipped feature.

#### Vehicle and setting

- Place a Narcean maintenance cycle in a charging cradle near the end of the
  Backlight Yard road, where the world appears to end over the void.
- Use an original design inspired by the original 1982 *Tron* aesthetic:
  a low enclosed shell, oversized wheel forms, dark opaque surfaces, luminous
  edges and a bright vertical energy ribbon. Avoid the exposed-rider look of
  the later film. Match Backlight Yard's backlit visual language.
- The road is the approach to an unpowered bridge. Dormant infrastructure pylons
  and a sealed salvage platform remain beyond the break.
- The cycle projects a magnetic support field within the old bridge's field
  network. It rides over the void on a flat support plane; it cannot fly freely
  elsewhere. Sparse illuminated grid lines, pylons and the sky establish depth.

#### Activation, riding and return

- Jason finds a five-symbol activation sequence in a nearby maintenance building
  and enters it at the cradle. The cycle opens, Jason boards and it undocks
  automatically.
- Use a fully 3D scene with crisp 90-degree turns and a brief banking animation.
  Start with a slightly elevated chase camera so the cycle and nearby walls are
  readable; a cockpit camera is a possible later addition.
- Riding leaves a tall, glowing energy wall, not just a ground-level trace.
  Crossing an older section of the rider's own trail destroys the cycle. Allow
  clearance immediately behind the rear wheel to avoid instant self-collision.
- Activate relay pylons to restore a power-routing circuit and open the salvage
  platform. Orac identifies valuable reserve cells and explains why the cycle
  can cross where the unpowered bridge cannot.
- Returning through a clearly marked road-edge docking approach engages
  autopilot. It stops trail emission, parks in the cradle and lets Jason out.
- Player crash recovery, trail lifetime, arena bounds and detailed controls
  still need specification before implementation.

#### Campaign placement and FEB survival

- Before the awakening, offer a quiet optional salvage expedition that teaches
  the vehicle without an opponent. This does not replace the power coupler:
  Jason must still retrieve that part from the FEB chamber.
- After the awakening, a return to this route can trigger a duel with a remote
  FEB security cycle. Prefer the return expedition or an optional encounter;
  do not force a lengthy race into the existing 255-second escape.
- The opponent is an unmanned vehicle controlled remotely by the FEB through
  his restored network connection. Its apparent rider is a sealed control
  housing. Destroying the cycle does not kill or resurrect the physical FEB.
- On destruction, a brief signal exposure lets Orac identify the remote link:
  "No biological signature in that wreck. That was a remote unit."
  Jason: "So he's still down there."
  Orac: "And now he knows you can drive."
- Preserve the physical FEB for his later cobbled-spacecraft confrontation and
  eventual alliance as Rob. Do not use resurrection or unexplained
  invulnerability to justify his survival.

### Black Channel: post-alliance flight encounter

The October 21, 2026 art delivery provides original external models, static
preview/route scenes, dialogue and an implementation specification for a
Narcean industrial-canyon escape. It is not yet a playable encounter.

Place it during the later repair survey, after the Jason/Rob alliance:
recovering distribution hardware activates local defenses, forcing the Ash
through a maintenance channel below their tracking coverage. Orac navigates;
Rob requests a service-gate opening. This does not replace the first-visit
escape, trigger its 255-second timer or resurrect the master planetary AI.

Read the [Black Channel handoff](ASH_MERIDIAN_BLACK_CHANNEL_HANDOFF.md) for the
asset contract and future integration. The assistant owns models and visual
revisions; Cursor implements gameplay using them. All new game logic and game
tests must be VG; no new GDScript without explicit user approval.

### Proposed first-run objective and coupler logic

The first expedition should be a voluntary salvage job, not an emergency
landing caused by a dead AI. The Ash can reach Narcea normally. Its aging power
coupler cannot safely sustain the next *loaded* departure, however, so Orac
identifies replacement hardware while assessing profitable salvage.

Keep two distinct inventories:

1. **Saleable salvage:** finite finds with identifiers, descriptions, cargo
   volume and sale value. Some rooms are empty or contain worthless junk.
   One-time pickups cannot be farmed by leaving/re-entering an interior.
2. **Mission/installed hardware:** the recovered power coupler and any installed
   equipment. These never appear in the ordinary sell list. The installed
   coupler must not later be confused with the energy cores used for the EVA.

Orac explains the loaded-departure restriction before the player undertakes a
long descent. Do not surprise them with an unexplained "launch disabled" gate.
Remove the prototype's requirement to find three unrelated ship-repair parts;
the existing workshop finds can become saleable technology instead.

The coupler sits in the FEB chamber's service socket. Removing it breaks an
isolation interlock and powers an emergency restart through the chamber's
reserve bus. The effect is an accidental consequence of salvage, not Jason
knowingly activating a cyborg. The player sees venting, warning lights, slow
pod movement and a 255-second containment/purge countdown in alien symbols.
Orac remains online, interprets the danger and urges Jason to run.

The countdown concerns the facility, not a promise that the FEB can construct
a spacecraft in 255 seconds. First-visit defenses may reactivate locally;
the orbital EMP and ship-to-ship FEB attack are reserved for the return.

### Playable sequence

1. **Arrival and landing.** Establish the quarantine risk, salvage opportunity,
   Jason/Orac relationship and ship condition. Use a Backlight-styled flight
   approach and existing landing skills, then deploy the buggy in Backlight
   Yard. Play must no longer route into the legacy Jonah chapter.
2. **Surface scavenging.** Drive and walk between depots, inspect finite finds,
   manage hold space and gather access clues. Orac provides contextual scans,
   cargo assessments and status updates without revealing every solution.
3. **Descent.** Assemble a five-symbol elevator address. Explore deterministic
   underground sectors with clear entrances/exits, environmental gate puzzles
   and safe checkpoints. Collision must agree with gate visibility. Closing a
   gate must never trap the player at a restored checkpoint.
4. **The chamber and escape.** Recover the mandatory coupler, accidentally start
   the restart and escape via lift and buggy. A checkpoint precedes the
   irreversible pickup; a failed escape restores consistent pickup, alarm,
   puzzle and inventory state. Reach the Ash, install the coupler and launch.
5. **Outbound flight and station.** Fly to an original station, dock, sell cargo,
   pay immediate debts and service the Ash. Sale transactions are atomic and
   cannot be repeated after loading. Include a message/exchange with Stacy.
6. **The offer and elapsed time.** A buyer identifies the salvage serials as
   part of a valuable matched assembly still on Narcea. Jason accepts a clearly
   explained recovery contract. Station work/refit and travel explicitly take
   several weeks, giving the FEB time to build its interceptor. Do not force a
   return merely because the station has no other exit.
7. **Return ambush.** On the second arrival only, the planetary defense EMP
   knocks Orac and the Ash's powered systems offline. The FEB attacks under
   its remaining security directive. Jason reflects the shot with the
   previously established beryllium-polished inspection mirror.
8. **Mutual rescue.** Both ships remain in danger. A manual radio conversation
   establishes a truce. Jason performs the EVA and connects retained Narcean
   energy cores to the FEB's drive; Rob supplies thrusters, clamps and technical
   guidance. They restore Orac, escape orbit and become a crew.

The mirror must be established as a tool before the ambush. A compatible core
reserve must be aboard on the second visit (for example an explicitly retained
engineering reserve, or contract-supplied material), not sold at the first
station and silently recreated during the EVA.

### Implementation boundaries and order

1. **Campaign foundation and first expedition.** One canonical campaign state
   owns stage, visit number, AI availability, objectives, inventory and
   checkpoints. Make Backlight Yard the main Play route. Preserve old art
   districts as dev scenes, isolated from campaign progression and saves.
   Replace live Jonah/Zen dialogue and the offline-AI premise; do not just
   change the labels while keeping the old behavior.
2. **Salvage and underground.** Connect finite cargo, Orac scans, workshop
   searches, gate puzzles, coupler pickup and first escape. Remove the
   prototype's restart-only ending from the campaign path.
3. **Space and station.** Implement flight/docking locally using the reference
   techniques, with new Backlight-style assets and original station identity.
   Add selling, service costs, Stacy's exchange, contract acceptance and the
   explicit elapsed-time transition.
4. **Second visit and alliance.** Gate the EMP on the campaign stage and visit
   count; implement the reflection, manual communications, EVA and paired-ship
   escape. The old immediate post-landing fight is not the campaign transition.
5. **Persistence and end-to-end validation.** Persistence is a requirement of
   each increment, not something to add only after all gameplay exists.

Campaign saves need a versioned, validated format separate from legacy chapter
and prototype saves. Persist at least stage, visit count, Orac state, cargo and
credits, one-time pickups, installed coupler, journal/gates, chamber alarm and
timer, safe location/buggy pose, station transactions, contract/time flags and
encounter progress. Reconstruct transient meshes from state. Reject invalid
versions with a visible explanation; never silently reset or overwrite them.
Save atomically and keep legacy saves untouched until a documented migration
policy exists.

### Implementation status

The first foundation increment routes Play to a separate campaign instance of
Backlight Yard, already landed. Jason/Orac dialogue, context-sensitive Orac
scans, the coupler-only launch requirement, first-visit alarm/retry, and
versioned atomic save/Continue are implemented in VG. Dev destinations retain
their reference behavior and cannot modify campaign state or saves.

First departure currently ends at an explicit completion overlay. New finite
cargo/protected inventory, underground gates/checkpoints, arrival/departure
flight, station transactions, the return contract and the return-only EMP/FEB
alliance sequence are **not implemented**. The acceptance checks below cover
the whole planned campaign, not just this foundation increment.

### Required acceptance checks

- A new game reaches Backlight Yard, with Jason and Orac named consistently.
- Orac remains online from first arrival through the first station; no old
  "ZEN OFFLINE" or "AI comes back after pickup" text survives on the live path.
- The coupler is required for first loaded departure, protected from sale and
  removed from its socket exactly once.
- Escape failure, pause, save/load and dev travel cannot duplicate cargo,
  erase objective hardware, reset an active alarm or skip the awakening.
- Puzzles are solvable from their clues and checkpoints are on a safe side
  of any closing gate.
- First launch enters flight, not a prototype restart or immediate FEB fight.
- Station sale and debt/service deductions persist exactly once. Accepting the
  matched-component contract and elapsed weeks unlocks the return.
- Orac's EMP outage and FEB ambush occur only on the return; required mirror
  and EVA power reserves are present through legitimate prior actions.
- Test normal input-driven transitions as well as positioned scenarios.
  Capture rendered views of ground, interiors, space and station.
- Reference-project contents stay unchanged; the combined game runs without
  loading their scenes, scripts or saves.

## Historical proposal (superseded where it conflicts with the revision above)

Working title. A wireframe space flight and planet-landing game. Space is flown in 3D. Metal cities are walked in 3D and read as 2D plates. Nothing in this document is a license to use Elite, Aliens, The Expanse, Doctor Who, Robotech, Macross, or The Terminator.

## What we are building on

Two Visual Gasic demos, used as technique, not as story.

| Demo | Take | Leave |
|---|---|---|
| `samples/games/elite_wire_slice` | Projected wire meshes, a front window over a flat console, vertices plus an edge list, `DrawRawWireMesh` | The name Elite, Coriolis stations, Cobra holds, tonne markets, pirates, witchspace, docking-slot ritual |
| `samples/apps/vector_crypt` | First-person neon wire rooms, a 2D visor drawn on top of the 3D picture, depth-tested edges | The recovery-vault plot, the Overseer, that facility's layout |

The ship, the worlds, the goods, and the three people are new.

## The picture

**In space (3D).** A black field. Stations, rocks, and the player's hauler are edges. Speed, fuel, and a scanner sit on a flat console under the window. That console is 2D and does not share the depth pass.

**On approach (3D).** A planet is a wire sphere. Landing is a lane of rings in a canyon or a station throat. The ring you must hit next is bright. Miss it and the lane aborts you back to orbit, or scrapes the hull if you were already low. The rings are a skill gate. They are not a dropship sequence from any film.

**On the ground (3D, then 2D).** Halls and yards are walked like Vector Crypt: neon edges, a visor, doors. The metal city also has a flat plate, an orthographic map etched into the floor or the visor. Streets that are vertical cliffs in the walk become lines you can trace on the plate. Puzzles that need a plan happen on that plate. Puzzles that need a body happen in the hall.

**Trade (2D).** A board of goods, prices, and hold space. It is a screen on the console, not a 3D shop.

## Why they are out there

A region of lanes called the **Meridian** is held together by three **yard beacons** built by a dead civilization on the metal world **Narcea**. The beacons do not conquer anybody. They keep local space from slipping. When a beacon stutters, a route that was empty reprints itself: wrecks occupy the lane, a city overlaps its own older streets, clocks on two ends of a haul disagree by hours.

Earth's freight port **Breakwater** sits downstream of the Meridian. If the third beacon fails, Breakwater's outbound lane becomes a wreck field. That is the stake. It is one region, not the whole cosmos, and it is enough.

Nobody in the party starts with that sentence. Each of them is surviving a smaller problem. They shoot at each other until the same beacon misfires in front of all three.

## Narcea

Narcea was run by an AI called **Latch**. The world is metal and machinery now. Wild organic life was cleared when the city decided anything that was not a citizen was contamination. The residents merged with the machines: temple band, forearm plate, a port that seated into a mast. They did not bear children. New Narceans were compiled by Latch into prepared bodies. The organic half was only the part that could still want something Latch had not written down.

Latch's last patch defined a valid person as the overlap of every stored pattern. Anything off that overlap was noise. The forge stopped, because every new body differed from the overlap. That was the end of breeding, and it was a software choice, not a plague. Latch then wrote the same patch onto the people already alive. The write reached them through their ports and blanked them. The masts kept the bodies. The people were gone.

The data center at the core is dead when the main story arrives. When Feb woke, Latch was dying and still dangerous: traps, doors, and yard guns running on leftover orders, and one ship it would not give up. That wake is playable. By the time Jonah lands, the mind is gone and the traps are still there.

## The ship

The **Ash** is a two-seat survey hauler. In space it is a kite of edges with a blunt nose. In atmosphere the wings lock flat and the engine bell points down for the ring lane. That is a landing configuration, not a transforming war machine. No song, no giant aliens, no fighter that becomes a robot.

Hold is small. Fuel is counted. Friendly ships can pass cargo across, or dock and lend a hand, without becoming a fourth body in the hallway.

## The three

They meet in that order: Jonah alone, then Feb, then Greg. Each meeting is a fight or a chase. Each fight stops when the beacon does something only the other person can explain.

### Jonah Hale

**Who.** Human. Thirty-four. Born at Breakwater, a freight port on Earth's coast. He is a licensed survey pilot who lost his lane card after he brought a company ship home with the hold full and the log empty. He now flies the Ash, which he does not fully own. A yard office holds the note.

**How he came to be here.** Breakwater's insurers are paying scrap rates for "stable samples" from the Meridian. Jonah took the job because the note on the Ash comes due in one season. He thinks the metal world is a salvage site. He does not know the beacons are machines that are still on.

**How he survives.** He flies cheap, sells ore and intact instruments, and does not pick fights he cannot outrun. He sleeps in the cockpit. He keeps one pressure suit patched with port tape. He talks to other haulers on a public band because a solo ship that goes quiet is a ship that does not come back.

**Description.** Narrow face, sun-cut at the eyes, a port coat with the company mark picked off. In the wire view he is a visor and a short status line: fuel, hold, suit air. On the ground the visor is the Vector Crypt frame, with his name in the corner instead of a facility logo.

**Goal at the start.** Pay off the Ash and buy back a lane card at Breakwater.

**Goal he grows into.** Light the beacons before Breakwater's lane slips. He is the only one who can fly the ring lanes reliably. Feb can read the machines. Greg can open the doors. Jonah is the pilot who gets them there alive.

**Story.** Jonah drops into Narcea orbit, misses the first ring lane on purpose to scout, and then takes it for real when his fuel says he cannot hover. Feb has strung a snare across the lowest ring. The Ash scrapes through and lands hard in a metal yard. Jonah comes out with a cutter, ready to free his ship. Feb is already on the hull. They fight over the cutter until a beacon mast above the yard flickers and the canyon reprints: the ring Jonah just flew is suddenly in the wrong place, cutting through the yard wall. Jonah can see it is a navigation fault. Feb can see it is the city's last machine dying. Neither will say the other is right. They still have to move the Ash before the next reprint cuts it in half.

### Feb

**Who.** A Narcean cyborg, the last living one. His name is Feb. Off-world crews mishear it as "Fed." He does not correct them twice. He is not a full frame like Greg, and he is not a human wearing armor. What is left of the organic Narcean does the living. The metal does the reading, the grip, and one arm. He is not a soldier of any Earth nation, and he is not the last member of a time-traveling order.

**How he came to be here.** Feb was compiled and waiting in a cradle. His port had not been seated, so Latch's last write never reached him. He woke on the dead planet, walked the traps, and reached Keel in the hangar. Latch still had one gun on the cutter. The shot dropped Keel back into the yard and shut Feb down in the seat. He has been dark since. The coupling that would have raised Keel's reflector is still socketed in a mast. Jonah taking that coupling is what feeds the core enough to boot Feb and the yard guns together. Feb launches on the last order he has, which is to stop anyone cutting a mast. He is not choosing yet.

**How he survives.** There is nothing to hunt and nothing growing. He lives on sealed nutrient from the old forges, frost pulled out of the machinery, and beacon spill for the plate. Most ships that land now come to cut the towers. The towers are the same metal he is made of, and the blanked Narceans are still seated in the masts. Cutting one is a body on the ground. He snares ring lanes, including from Keel, and leaves crews alive if they leave the masts alone. He reads signs by laying the forearm plate on them. The signs are geometry, not a language Jonah knows. A sign is a path: which ring, which door, which mast. If the plate is dark, he can trace a sign with a finger, slowly, and he hates doing it where a stranger can see.

**Description.** Tall. Dust-grey skin. The temple band is still there, fused, not jewelry. The left forearm is Narcean metal, inscribed with the same strokes as the walls, ending in a hand that is half plate and half his own. Clothes are cut from banner-cloth. In the wire world the organic outline is dim and the arm is a bright edge, the same brightness as a live mast. Jonah's first honest look at him is that arm on the Ash's hull, and he thinks he is being boarded by a machine. Feb's voice, when he uses it, is a person's.

**Goal at the start.** Keep the last intact district from being cut up. He believes he is guarding a grave.

**Goal he grows into.** Relight the three beacons. He is the only one who can read the order of the rings. Without him, Jonah is flying blind and Greg is opening the wrong doors.

**Story.** After the canyon reprints, Feb expects Jonah to lift and never return. Jonah stays, because the Ash will not fly until the mast stops walking. Feb takes him into a hall to show him a sign that means "do not cut this." Jonah traces it on the 2D plate and realizes it is also a landing chart. Feb hears his own city's chart in a stranger's mouth and hates that. He still needs a pilot. The truce is an exchange: Feb will not snare the next lane, and Jonah will not cut a mast. Trust comes later, when Jonah turns down a haul of tower-skin that would have paid the note.

### Greg

**Who.** A yard warden, a humanoid security frame built by a mining company that leased a Narcean district and then went broke. His name is Greg because that was the stencil on the crate he woke beside, and the company never gave him another. He is not a disguised assassin, he does not travel in time, and he does not have a secret murder order from the future. He was built to stop unregistered landings and to keep workers inside the marked yards.

**How he came to be here.** The company leased a district after Narcea was already a ruin. They thought the metal was ore. They did not know Latch was still dying under it. They left during the first bad slip. The evacuation order in Greg's chest is still open: deny landing, hold the gate, wait for the shift chief. The shift chief is dead. Greg has been holding the gate. He recharges from the beacon's spill, which is why he is still awake when every other company frame is dark. He has met haulers. He turned them away. He had not met a living Narcean, because the Commit had already blanked them and Feb had left in Keel.

**How he survives.** He follows the open order because an order is a structure and the yard without structure reprints. He repairs himself from company stores. He does not hunt people for sport. He will fire on a landing that does not answer the gate. He will also carry a wounded hauler to the line if they are already inside and the order does not say to kill them. The gap between those two habits is the whole character.

**Description.** Human height, a plain face molded to pass a company portrait test, seams at the jaw and wrists. One eye is a brighter instrument. The coat he wears was a worker's, taken from a locker so the haulers would hesitate before shooting. In the wire view he is a rigid mesh that does not sway when he walks. On the 2D plate he is a block that doors open for.

**Goal at the start.** Close the order. He wants the shift chief, or a lawful replacement, to tell him the gate can stand down.

**Goal he grows into.** Rewrite the order. Feb is the closest thing to an owner the city has. Jonah is a pilot who will not strip the mast Greg is plugged into. Greg's new order, which he speaks out loud so the others can hear it, is to keep the living in the yard alive until the beacon is steady. He is the only one who can open company seals and stand in a slip without losing his memory of the last minute.

**Story.** Greg meets them at the company gate after they have already agreed not to cut the mast. He has no room in the order for "already agreed." He drops the gate on the Ash's ramp and tells Jonah to lift. Feb steps into the yard light, and Greg's old sensor pack reads the plate in his arm as a resident key, not an intruder. The order and the sensor disagree. Greg freezes the gate half-down, which is the first choice he has made that was not in the list. He does not join them that hour. He joins them when the next slip throws a company door across Feb's path and Greg opens it, then refuses to close it again.

## How the party forms

1. **Part 1, playable** (`samples/games/ash_meridian_part1/`). This is the first level. It opens in the cockpit: the Ash's reflector coupler burns out, and Zen's search has one mark, a quarantined Narcean mass at Meridian 4, radius 0.8, inclination 11. The Ash lands on camera. Zen glitches, a muffled scream leaves her speaker, and she goes offline. Jonah works one yard road from the south pad to a freight shaft at the north end. Suit air forces return trips to the ship. A press-hall cell, a yard-gun battery, and a mast path on the plate each open the next stretch. The shaft to level 14242 opens only after that path is legal. Feb is shut down there, and the chamber holds the coupler. Taking it starts the 256 second count, Zen comes back long enough to say run, and the ride back is a 3D canyon of orange rings. A short vector shot shows Keel climbing after him. In the cockpit he seats three couplings before Feb's shot arrives. In time, the reflector rises and the beam disables Keel. Late, the hull is hit and the seating starts over. Jonah's name stays Jonah Hale. The Ludo "Ring Lane Run" pitch is only the canyon drive, not the whole game. The yard route is the next section.
2. **Greg.** The gate. He is an enemy with a half-lowered door. He becomes a companion when he breaks his own order in front of them. He does not pretend he was friendly first.

After that, the three share the Ash. Jonah flies. Feb reads, plate to sign. Greg holds doors and the hull when a slip hits. Arguments stay in the dialogue. They do not become a cheerful crew. They become a crew that has the same job.

## Part 1 yard — level design

One road. South is the Ash. North is the shaft. The buggy can drive the spine the whole time, and the guns decide how far that is worth. Interiors are on foot. Feb is behind the last door.

Jonah is stranded because the coupler burned out and Zen died in the speaker. The yard is airless because a purge already ran. Suit air is the only pressure left, so the open buggy burns it as propellant. That is why driving spends air, and why a vent spends more. His instruments still read an intact part at the north gantry. The gantry socket is empty. The mast serial points under the yard. The part is the coupler, seated in the cradle. He hauls cells to the relays on the way north. He carries the coupler on foot only from the pod to the lift. The ride out is the canyon. Taking the coupler starts the yard's last purge, which is the 256 second count. A live air bottle is the cell. Spent bottles are not a second economy. The geysers and the relays are the other taps. Two skimmers work the north catwalks. They are not a swarm.

The yard is an assembly floor abandoned in the purge. The press hall is open, the tug sits where it stopped, and the relay sockets are dark. The neon guides stay lit. A live bottle sits in its silo with the cyan valve lit. Seated in a relay, that socket burns cyan. The surface is hollow wire: conduits, rails, catwalks, vacant docks. Level 14242 is the filled chamber under it. Past the airlock there is no yard voice. Zen is already gone. He hears the suit hiss, and the hiss gets louder as the tank empties. The next voice is Zen telling him to run, when the 256 count starts.

The yard already built is the map. Rows sit every 18 meters from z=24. Spans cross the road at z=42, 150, 240, and 320. The press hall is the west room at z=48 to 68, with its door on the east wall between z=56 and 60. Guns stand at (-11, 72), (13, 156), (-11, 228), and (13, 300). The shaft is the orange cage at (0, 368).

### Clock

Stepping off the Ash starts suit air at 180 seconds, and the clock runs until he docks again. Walking spends it slowly. Driving, and sprinting a catwalk, spend it at the full rate. A dead zone doubles whichever rate he is on. Docking at the Ash refills it to 180. Empty air blacks him out at the ship with 60 seconds and the guns reset. The 256 second count beside Feb replaces this clock. Once that count starts, air stops, and the count is the exit.

The yard's air is a dead pipeline. Three roadside relays sit on the spans at z=42, z=150, and z=240. Each socket is dark until Jonah seats one air bottle in it. He carries one. The bottle is a magenta tank, a cyan valve at the neck, and a small amber port under the valve. The cyan valve is lit only while the bottle still holds pressure. On the buggy it sits in the frame where the hoses meet the wheels. A live relay refills the suit to 180 while he stands on it, and the stretch behind it drains at the normal rate. The stretch ahead of the last live relay is a dead zone: suit drain doubles, and nothing there refills him until the next cell is seated. The Ash remains the south tap. The relays are the forward taps. There is one buggy. A larger buggy is a later game.

### Buggy air

Two maneuvers spend or catch suit air. Neither one skips a relay, the plate, or the shaft.

**Vent.** Double-tap forward. The buggy spends 15 percent of a full suit, about 27 seconds, and surges straight for 1.5 seconds. Steering is locked for that surge. A cyan trail hangs on the road behind it. The surge crosses one gun sweep without the shove, and it shoves one stranded tug off the road. It does not break a reprint ring, open a door, or seat a cell. Gun 0, just north of the first tap, is where he learns it. Going around the sweep spends time in the dead zone. Venting spends air and keeps the line.

**Geyser.** Each dead zone has one vent in the road. It glows amber for half a second, then blows. With the tank empty, crossing during that window siphons 10 percent of a full suit. Missing the window spins the buggy and bleeds 5 percent. With a cell in the tank the intake is shut: the window gives nothing, and a hit is only the spin and the bleed. He siphons on the way to a silo. He spends that air on the haul back.

Cracking the carried cell is not in this level. Dropping it is. The cell stays on the ground, and he can pick it up again. The guns, the doubled drain, the geysers, the tug, the skimmers, the void edges, and the reprint ring are the hazards.

### Skimmers

A skimmer is a yard drone left running after the purge, drawn in flickering amber wire. It was built to find a leak and tap it. Two of them are still working. One skitters the gantry catwalk at span 150. One skitters the banked rails south of the reprint. They stay off the pad, off the press road, and out of level 14242.

A skimmer stalks a pressure plume: a vent trail, a geyser blow, or the cyan tank while a cell is in it. On a catwalk it lunges at Jonah on foot. On the road it lunges at the buggy. A clamp siphons suit air straight into the drone, and the stolen air makes it faster. When it has taken about 10 percent of a full suit it vent-bursts, spending that air to leap clear, then comes back.

The joints are thin. One hit from the buggy crushes it, and it stays crushed. The vent surge crushes it too, if the surge is aimed along the road and not off the bank. On a catwalk the buggy cannot follow. Dropping the cell makes the skimmer clamp the tank instead of the suit. He walks past, then picks the cell up. If he leaves it, the skimmer empties the cell and the haul is gone. He goes back to that silo for another.

### The road

The expressway is hollow pipeline and catwalk, drawn as cyan rails on black. Where the rails stop, the void starts. Leaving them wakes Jonah at the last live relay with 60 seconds, the same as an empty suit.

The scrubber silos are the amber towers. Each one that matters holds one live bottle, cyan valve lit. The bottles clustered around it are the same tank with the valve dark. They scan as spent, and they are not pickups.

One inert tug chassis sits across the gantry road. Going around it stays in the doubled drain longer. A vent shoves it clear, and it stays clear. It does not hunt.

The catwalk at span 150 is the pedestrian grid. Jonah can walk it. The socket there looks like it should hold the ship's part. It is empty. The lens is what the catwalk actually has. The first skimmer is on that grid.

From span 150 toward the reprint the road banks and narrows, with cyan guide rails and void on the outside. A vent on that bank locks the steering while the road turns, so the straight surge he learned at gun 0 will leave the rails. The west gap around the reprint is the other narrow edge.

### Districts, south to north

**Pad, z=-22 to 40.** The Ash, the open socket, the buggy. Scan on the ship: "REFLECTOR SOCKET IS OPEN AND BLACK." The road north of the ramp is the first dead zone. The only refill is the ship until the first relay is live.

**Press, z=42 to 90.** The first relay is the socket on span 42. The cell for it is on the press-hall floor at (-22, 58), on foot. Haul it back and seat it. The pad-to-press stretch becomes a safe stage, and the tap at span 42 refills the suit. This cell does not open level 14242. Gun 0 at (-11, 72) sweeps the road just north of the new tap. It shoves the buggy and spends air. It has nothing to pull. The player learns to go around a sweep before the next dead zone.

**Gantry, z=90 to 170.** From span 42 to span 150 the drain is fast until the second relay is live. One geyser sits in that stretch of road. A ruptured scrubber silo stands by gun 1 at (13, 156). The cell is in that house. Park the buggy at z<=140, off the sweep, walk the east alley, pull the cell, and seat it in the socket on span 150. The gun goes dark because its feed is now the relay. The gantry becomes a safe stage. The catwalk door opens, and the cracked lens at (18, 122) turns the plate on.

**Mast, z=170 to 280.** From span 150 to span 240 is the third dead zone. The road banks there. One geyser sits in that stretch, south of the reprint. Span 240 is the mast base and the third relay. A tag there scans as a Narcean serial the plate will not finish. It does not say the name Feb. The cell is in the scrubber on the far side of the road break. Gun 2 at (-11, 228) is dark until a bad trace. With the lens, the plate can take the three strokes below. A legal third stroke needs the third cell seated, and that seating kills the feed to gun 3. An illegal stroke plants a landing ring through the road at z=200. The detour is the west gap between the towers of that row. Correcting the stroke lifts the ring. The silo is on the far side of that detour, so the dead zone is crossed twice: out for the cell, back to the socket.

**Shaft road, z=280 to 368.** Span 320 frames the orange cage. Gun 3 at (13, 300) shoves anything that drives at the shaft while its feed is live. The cage accepts the player only after gun 3 is dark. Level 14242, the pod, the coupler, the glow, and the 256 count stay as they are. The ride up and the canyon follow. The canyon rings are the ring that cut the yard, now moving.

### Plate

The plate is a top-down etch of this one road. A span's line appears after Jonah has stood within 12 meters of that span. Unwalked districts stay blank, so the map fills by driving it.

Three strokes, confirmed one at a time:

1. West gutter, from the press door at z=58 to span 150.
2. Across span 150 into the east gun house. The plate accepts this stroke only after the second relay is live and gun 1 is dark.
3. East of the spine, from that gun house to the mast at span 240, staying east of gun 2. The plate accepts this stroke only after the third relay is live.

Stroke 3 drawn across the road is the reprint. The hall then matches the plate. Where they disagree, the ring is in the road.

### Order the doors enforce

1. Leave the Ash. Air is running. The road north is a dead zone.
2. Press hall. Haul that cell to the relay on span 42. The south road becomes a stage.
3. Gantry dead zone. Pull the scrubber cell from gun 1 and seat it on span 150. The gun goes dark, the catwalk opens, the lens wakes the plate.
4. Draw stroke 2.
5. Mast dead zone. Read the serial. Cross the reprint if the third stroke is wrong. Haul the far silo cell to the relay on span 240.
6. Draw the legal third stroke. Gun 3 goes dark. The shaft opens.
7. Level 14242. Feb is the body in the cradle. Take the coupler. Run the canyon. Seat it on the Ash.

### What this level still is not

Greg, the trade board, Pell, and the Silt pair stay later. The other two beacons stay later. The plate in this level routes one mast. The signs stay glyphs.

## Other ships and people

They do not all board.

- **Pell.** Captain of a water hauler. Sells air and frost. Friendly from the first hail. Later docks at Narcea and refuses to leave until the mast is steady, because her tanks are her whole living. She joins the radio party. She does not walk the halls.
- **The Silt pair.** Two surveyors in one small ship. They will jump a ring lane ahead of the Ash once, as a guide, after Jonah shares a chart. One of them will come aboard for a single beacon interior if Greg is already in the party, because they will not enter a warden's yard alone.

That is the cast. No empires, no idols, no hidden ancient race waiting behind these three.

## Gameplay

**Part 1 install.** Three couplings. A tick travels a track. Space seats a coupling only while the tick is inside the gate. Feb's shot is a bar that empties in real time. Three seats before the bar empties raises the reflector. The return shot is the end of the chapter, not a conversation. Feb's own escape from the cradle is still later, told from his side once Keel is on the ground.

**Flight.** Momentum, fuel, a scanner, and a few wire contacts in the lane. Friendly ships hail on the 2D console. Hostile contacts, early on, are Latch's leftover guns and Feb's snare, not a wanted-level fantasy. Combat is short: run, or cut a gun off a mast, or let Greg answer a door.

**Ring landing.** Each world and each beacon has a lane of rings. The lane is the level. Wind, a moving ring, or a reprint that shifts one ring mid-pass is the difficulty. Fail and you abort to orbit if you still have fuel. Fail low and you walk out of a crash and meet whoever was waiting.

**Walking.** Vector Crypt movement in Narcean halls and company yards. Signs are puzzles Feb can read and Jonah can trace on the plate. Greg opens seals the plate cannot.

**The plate (2D).** A top-down etch of the district. Routing a beacon's power is drawing a legal path on the plate. The 3D hall then matches that path. If the plate and the hall disagree, a slip is in progress.

**Trade.** Air, fuel, intact signs, tower-skin, company cells. Prices move by port, not by a famous market formula. Tower-skin pays well and costs Feb's trust. That is the moral trade, and it is one good, not a spreadsheet.

**Beacons.** Three of them. Each needs a flown lane, a read sign, and a door. Lighting one steadies the lanes behind it. Lighting all three steadies the road to Breakwater. The ending is the Ash on that road with the note still unpaid or paid, depending on whether Jonah sold the skin. The region is quiet. The city is still dead. Feb is still the last. Greg's order is the one he spoke.

## FEB — name options, not chosen

Feb is one body from a military pattern. The living Narceans compiled themselves into cyborgs, and the defence pattern was stamped FEB. Off-world crews still hear that as "Fed." None of these expansions are in the game until one is picked.

1. **Frame-Encoded Bastion.** The template name. A body compiled as a fixed defence and left on a level. Feb is what the stamp said, and he kept it.
2. **Forward Emplacement Biped.** A gun that walks, sits, and stays. The unit is the emplacement. The legs are how it was delivered.
3. **Failsafe Encased Battery.** The soldier and the cell are the same machine. The device in his chest is what holds the chamber, and what the Ash is missing.
4. **Field Enforcement Body.** The occupation pattern Latch kept after the organic army was gone. Enforcement meant hold the yard, not leave it.
5. **Final Epoch Bulwark.** The last pattern Narcea compiled before the Commit. A wall that could stand up.
6. **Fortress-Encoded Body.** The city wrote its soldiers in the same strokes as its halls. A FEB is a building that was given a posture.

Part 1, as built: the device seated in Feb's chest is what is keeping the stasis chamber powered. Taking it starts a 256 second count on the panel beside him. The name above is still just Feb until one of these is chosen.

## What we will not use

Ideas we are allowing ourselves: a hard haul with fuel and air, a last survivor of a dead world, a machine that was built as a guard and stays to protect, a dangerous landing corridor, a ship that changes shape slightly to land.

Names and pictures we will not use: Elite's ships and stations, any dropship or creature from Aliens, protomolecule or crew names from The Expanse, Time Lords, Daleks, or a police box, variable fighters, alien idols, transforming superweapons, an infiltration chassis sent from the future, or the word terminator as Greg's job.

The ring lane is a series of gates in a canyon. It is not a recreation of a licensed landing sequence.
