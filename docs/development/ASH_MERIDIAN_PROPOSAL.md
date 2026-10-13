# Ash Meridian

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

**How he came to be here.** Feb was compiled and waiting in a cradle. His port had not been seated, so Latch's last write never reached him. He woke in that cradle on a dead planet: metal, machinery, no other organic life, and a data center that was still shooting. He walked out through the traps, reached the hangar while Latch could still aim, and stole the cutter **Keel**. Clearing the ring lane in a ship the AI still called its own is the end of that chapter. He left. He came back when the beacons, which Latch used to run, started to slip without a mind on them. Keel is the ship he arrives in. He will not give it to Jonah.

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

1. **Feb's wake, playable.** Cradle, traps, the dying data center, steal Keel, fly the ring lane out while Latch can still aim. This chapter ends in orbit. Latch does not survive it. The core remains as a dead, trapped interior for later.
2. **Jonah alone.** Fly a short lane. Learn the console. Land one practice ring lane at a friendly yard. Trade once.
3. **Feb returns in Keel.** The Narcea snare. Fight on the hull. The canyon reprints. Truce over the mast. He keeps Keel. He will ride the Ash only after Jonah turns down the tower-skin haul. Until then he is a hostile who shares a map.
4. **Greg.** The gate. He is an enemy with a half-lowered door. He becomes a companion when he breaks his own order in front of them. He does not pretend he was friendly first.

After that, the three share the Ash. Jonah flies. Feb reads, plate to sign. Greg holds doors and the hull when a slip hits. Arguments stay in the dialogue. They do not become a cheerful crew. They become a crew that has the same job.

## Other ships and people

They do not all board.

- **Pell.** Captain of a water hauler. Sells air and frost. Friendly from the first hail. Later docks at Narcea and refuses to leave until the mast is steady, because her tanks are her whole living. She joins the radio party. She does not walk the halls.
- **The Silt pair.** Two surveyors in one small ship. They will jump a ring lane ahead of the Ash once, as a guide, after Jonah shares a chart. One of them will come aboard for a single beacon interior if Greg is already in the party, because they will not enter a warden's yard alone.

That is the cast. No empires, no idols, no hidden ancient race waiting behind these three.

## Gameplay

**Feb's wake.** Played as Feb, before Jonah. The halls are Vector Crypt: wire rooms, visor, doors that still obey Latch. Traps are leftover orders, not a personality you can talk to. The 2D plate shows which corridors the dying core still owns. The hangar is 3D. Keel is there, and the ring lane out is the first flight test, flown while yard guns still track. Stealing the ship is the win. The core goes dark behind him.

**Flight.** Momentum, fuel, a scanner, and a few wire contacts in the lane. Friendly ships hail on the 2D console. Hostile contacts, early on, are Latch's leftover guns and Feb's snare, not a wanted-level fantasy. Combat is short: run, or cut a gun off a mast, or let Greg answer a door.

**Ring landing.** Each world and each beacon has a lane of rings. The lane is the level. Wind, a moving ring, or a reprint that shifts one ring mid-pass is the difficulty. Fail and you abort to orbit if you still have fuel. Fail low and you walk out of a crash and meet whoever was waiting.

**Walking.** Vector Crypt movement in Narcean halls and company yards. Signs are puzzles Feb can read and Jonah can trace on the plate. Greg opens seals the plate cannot.

**The plate (2D).** A top-down etch of the district. Routing a beacon's power is drawing a legal path on the plate. The 3D hall then matches that path. If the plate and the hall disagree, a slip is in progress.

**Trade.** Air, fuel, intact signs, tower-skin, company cells. Prices move by port, not by a famous market formula. Tower-skin pays well and costs Feb's trust. That is the moral trade, and it is one good, not a spreadsheet.

**Beacons.** Three of them. Each needs a flown lane, a read sign, and a door. Lighting one steadies the lanes behind it. Lighting all three steadies the road to Breakwater. The ending is the Ash on that road with the note still unpaid or paid, depending on whether Jonah sold the skin. The region is quiet. The city is still dead. Feb is still the last. Greg's order is the one he spoke.

## What we will not use

Ideas we are allowing ourselves: a hard haul with fuel and air, a last survivor of a dead world, a machine that was built as a guard and stays to protect, a dangerous landing corridor, a ship that changes shape slightly to land.

Names and pictures we will not use: Elite's ships and stations, any dropship or creature from Aliens, protomolecule or crew names from The Expanse, Time Lords, Daleks, or a police box, variable fighters, alien idols, transforming superweapons, an infiltration chassis sent from the future, or the word terminator as Greg's job.

The ring lane is a series of gates in a canyon. It is not a recreation of a licensed landing sequence.
