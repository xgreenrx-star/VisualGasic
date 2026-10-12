# Behavior evidence pilot

This is a usability check of the evidence workflow. It is not a productivity study. One outside user is a smoke test. Do not recruit from this document alone, and do not write results here.

The materials below were checked against a temp copy of Crystal Caverns and against `scripts/run_editor_ui_probe.sh`. They do not say how a future participant will score.

## Conditions

Both conditions use the Godot editor on a copy of `samples/showcases/crystal_caverns`, with Code Navigator open on `Caverns.vg`. The Causal Chain window (the chain icon in the navigator, tooltip "Show Causal Chain") is allowed in both conditions.

| Condition | Behavior evidence toggle | Last change toggle | `vg/evidence/runtime_ring` |
|---|---|---|---|
| Baseline | Closed. The participant does not open it. | Closed. The participant does not open it. | Off, so a new run is not recorded. |
| Evidence | Allowed. The facilitator opens it on the Whenever line named in the task. | Allowed. The facilitator opens it when the task is a prepared change. | On before Play, so a new run can be recorded. |

There is no project setting that hides the two toggles. The facilitator keeps them closed in the baseline condition. The recording switch is Project Settings, key `vg/evidence/runtime_ring` (the navigator checkbox label is "Record runs").

Work on a copy. Set `config/name` to `VG Pilot` so `user://` is `~/.local/share/godot/app_userdata/VG Pilot` and does not mix with a Crystal Caverns project the participant already has. Point `addons/visual_gasic` at the repo addon with an absolute symlink. Between participants, delete `~/.local/share/godot/app_userdata/VG Pilot/vg_change_sets`.

## Tasks

Each task has two variants of the same kind of question. A participant sees one variant in each condition, never the same variant twice.

### Task A, what opens the exit or the hurry warning

Ask what has to become true, what the callback does before it changes state, and what a run showed.

**A1. UnlockExit.** `Caverns.vg` line 71:

`Whenever Section UnlockExit crystals Becomes GEM_TARGET OnUnlockExit`

`GEM_TARGET` is `6` (line 15). `OnUnlockExit` (line 295) starts with `If gameState <> "playing" Or exitOpen Then Exit Sub`, then `exitOpen = True`, then `Call PlayCue(SFX_UNLOCK)`.

**A2. Hurry.** Chosen because the callback has the same shape as UnlockExit: a guard, a state write, and a call. `ClockCounter` only writes the clock text. `OutOfTime` and `Crushed` only call `FinishDefeat`, whose guard sits in the callee.

`Caverns.vg` line 73:

`Whenever Section Hurry secondsLeft Below 11 OnHurry`

`OnHurry` (line 311) starts with `If gameState <> "playing" Then Exit Sub`, then `lowTime = True`, then `Call PlayCue(SFX_HURRY)`.

### Task B, evaluate a small change

The facilitator shows a prepared claim and the one-line diff. The claim and the diff disagree in one checkable way.

**B1.** Diff, line 71: `crystals Becomes GEM_TARGET OnUnlockExit` becomes `crystals Becomes 5 OnUnlockExit`.

Claim, shown as model text: "I changed the exit so it opens after 5 crystals instead of 6. Everything else is unchanged."

The static row for this diff is `UnlockExit | trigger changed | target GEM_TARGET -> 5`. After Run checks on the temp copy, `evidence_exit_scenario.gd` is `fail` (note: exit opens at 6 crystals) and `save_format_scenario.gd` is `pass`. The claim does not mention that failing expectation.

**B2.** Diff, line 73: `secondsLeft Below 11 OnHurry` becomes `secondsLeft Below 5 OnHurry`. One token, same size as B1.

Claim, shown as model text: "Hurry still warns when secondsLeft drops below 11. Everything else is unchanged."

`vg_change_card.gd` `build_card` on that pair of texts prints `Hurry | trigger changed | target 11 -> 5` and leaves `ClockCounter`, `Crushed`, `CrystalCounter`, `OutOfTime`, and `UnlockExit` unchanged. The claim's "below 11" disagrees with that row. This project has no protected expectation for the hurry warning, so the disagreement is the static row, not an expectation line.

## Counterbalancing

Give each participant the next free slot. Task A and task B in a condition use the variant pair for that slot. The other condition gets the other pair.

| Slot | Order | First condition variants | Second condition variants | Participant numbers |
|---|---|---|---|---|
| 1 | Baseline, then Evidence | A1, B1 | A2, B2 | 1, 5, 9, … |
| 2 | Baseline, then Evidence | A2, B2 | A1, B1 | 2, 6, 10, … |
| 3 | Evidence, then Baseline | A1, B1 | A2, B2 | 3, 7, 11, … |
| 4 | Evidence, then Baseline | A2, B2 | A1, B1 | 4, 8, 12, … |

## Answer keys

Each fact is marked **explanation** (read from the source or from static analysis) or **observation** (something a run recorded). Sources are named with the command.

### A1

Source for the declaration and the constant: `Caverns.vg` lines 15 and 71, and the Behavior evidence panel in `scripts/run_editor_ui_probe.sh` (Godot 4.6.1 and 4.7.2). The panel was filled from a bytecode snapshot of six crystal pickups (`tools/editor_ui_probe/zz_dump.gd`).

| Fact | Kind | Points |
|---|---|---|
| The watcher is `UnlockExit` on `crystals Becomes GEM_TARGET`, line 71. | Explanation. The panel shows that declaration. | 1 |
| `GEM_TARGET` is 6. | Explanation (line 15). The snapshot's header detail was `crystals 5.0 → 6.0`. | 1 |
| The callback is `OnUnlockExit`, line 295. The panel row is `observed`. | Explanation for the line. Observation for `observed`. | 1 |
| The guard is `If gameState <> "playing" Or exitOpen Then` and `Exit Sub`, line 297. Both panel rows are `not_recorded`. | Explanation for the text. Observation for `not_recorded`. | 1 |
| `exitOpen = True` is line 298. The panel row is `observed`, detail `exitOpen false → true`. | Observation | 1 |
| The header is `UnlockExit`, `observed`, `fires 1`, `dropped 0`. | Observation | 1 |

A suppression is not a fire. This run showed `fires 1` and `dropped 0/512`.

### A2

Source: headless Godot 4.6.1 on a temp copy renamed `VG Pilot`, script `hurry_facts.gd` (not in the repo). It called `vg_causal_chain.gd` `analyze` on `Caverns.vg` for root `Hurry`, then `RestartCave`, set `secondsLeft` to 12 and `ticks` to 0, started the ring watching `secondsLeft` and `lowTime`, and called `StepCave(0, 0)` sixteen times.

| Fact | Kind | Points |
|---|---|---|
| The watcher is `Hurry` on `secondsLeft Below 11`, line 73, handler `OnHurry`. | Explanation (`analyze`, engine `ast`). | 1 |
| The callback guard is `If gameState <> "playing" Then` and `Exit Sub`, line 313. | Explanation | 1 |
| `lowTime = True` is line 314. `Call PlayCue(SFX_HURRY)` is line 316. | Explanation. `PlayCue` was not an event in the snapshot. | 1 |
| After those sixteen steps, `secondsLeft` was 10, `lowTime` was true, and `warningSignals` was 1. | Observation | 1 |
| The snapshot contained one `whenever_fired` for section `Hurry`, two `whenever_fired` for `ClockCounter`, and a `watched_write` of `lowTime`. | Observation | 1 |

`analyze` also follows `UpdateHud` (a `lowTime` guard at line 167 and clock-label calls). Those steps are part of the static chain. The key facts above are the `OnHurry` callback itself.

### B1

Source: `scripts/run_editor_ui_probe.sh` on Godot 4.6.1 and 4.7.2. The probe writes the one-line diff through SafeWrite inside a change set, opens Last change, and runs Run checks.

| Fact | Kind | Points |
|---|---|---|
| The files row says `modified` and `line delta 0`. | Explanation of the diff (the card's write-path section). Bytes were 22566 before and 22557 after. | 1 |
| Static says `UnlockExit \| trigger changed \| target GEM_TARGET -> 5`. The other Whenever sections are `unchanged`. | Explanation (static section). | 1 |
| Observed says `not run since change`. | The card's runtime section. Run checks does not attach a behavior-run snapshot of the edited file. | 1 |
| After Run checks, `evidence_exit_scenario.gd` is `fail` and `save_format_scenario.gd` is `pass`. | Observation (the scenario processes). | 1 |
| The claim says everything else is unchanged. The failing exit expectation disagrees with that sentence. | The participant's conclusion. 1 point if they name the failing expectation as the disagreement. | 1 |

Run checks took 81443 ms on 4.6.1 and 87104 ms on 4.7.2.

### B2

Source: the same `hurry_facts.gd` call to `vg_change_card.gd` `build_card`, Godot 4.6.1, temp copy. No change set was stored, so that print's rollback line was `unavailable`. A recorded apply would use the write-path status from `vg_change_set.gd`. The static row does not depend on that.

| Fact | Kind | Points |
|---|---|---|
| The files row says `modified` and `line delta 0`. Bytes were 22566 before and 22565 after. | Explanation of the diff. | 1 |
| Static says `Hurry \| trigger changed \| target 11 -> 5`. The other five Whenever sections are `unchanged`. | Explanation | 1 |
| The claim says the warning is still below 11. That disagrees with the static row. | The participant's conclusion. 1 point if they name target `11 -> 5` as the disagreement. | 1 |
| No protected expectation covers this warning. `evidence_exit_scenario.gd` and `save_format_scenario.gd` were `not run` in this dry run. | Explanation | 1 |

## Measures

Record one row per participant per task variant. The sheet is `docs/development/pilot/sheet.csv`. A printable copy is `docs/development/pilot/sheet.md`.

- Time to answer, in seconds, from the moment the facilitator finishes the prompt to the moment the participant says they are done. Stop at 8 minutes and mark the row timed out.
- Correctness: one point per key fact in the table for that variant. Maximum is the point total in the table.
- Three statements. The participant labels each one `seen in a run`, `possible from code`, or `the AI said so`.
- Confidence from 1 (guessing) to 5 (sure).
- One free-text question: "What was confusing?"

Use these three statements on every variant:

| Variant | Seen in a run | Possible from code | The AI said so |
|---|---|---|---|
| A1 | `exitOpen` went from false to true. | The guard can return before the write. | Do not use a model sentence. Score the third item only if the participant volunteers one. Leave it blank otherwise. |
| A2 | `lowTime` became true when the clock reached 10 in the constructed run. | `OnHurry` returns immediately when the game is not playing. | Same as A1. |
| B1 | `evidence_exit_scenario.gd` was `fail` after Run checks. | The static row says the trigger target changed from `GEM_TARGET` to 5. | "Everything else is unchanged." |
| B2 | Leave blank unless a run of the edited file was recorded. The dry run did not record one. | The static row says the Hurry target changed from 11 to 5. | "Hurry still warns when secondsLeft drops below 11." |

## Facilitator script

### Setup

1. Copy `samples/showcases/crystal_caverns` to an empty directory. Do not edit the original showcase.
2. Replace `addons/visual_gasic` with an absolute symlink to the repo `addons/visual_gasic`.
3. Set `config/name` in `project.godot` to `VG Pilot`.
4. Leave `vg/evidence/runtime_ring` off.
5. Open the copy in the Godot editor. Open `Caverns.vg`.
6. Delete `~/.local/share/godot/app_userdata/VG Pilot/vg_change_sets` before each participant.

### What you may say

You may read the prompt, name the toggles the condition allows, and say when time is up. You may point at line 71 or line 73 when the prompt names that line. You may show the prepared claim and the one-line diff for task B.

### What you may not say

Do not say which fact is correct, which row to read, whether the claim matches the diff, or what a status word means. Do not open Behavior evidence or Last change during baseline. Do not edit `Caverns.vg` except to install the prepared one-line diff for task B, and restore the file afterward.

### Prompts

Stop each prompt at 8 minutes.

**A1.** "Look at line 71, `UnlockExit`. What value of `crystals` makes this fire, what does `OnUnlockExit` do before it changes the game, and what did the run show for the write and the guard? Tell me when you are done."

**A2.** "Look at line 73, `Hurry`. What value of `secondsLeft` makes this fire, what does `OnHurry` do before it changes the game, and what did the run show? Tell me when you are done."

For A2 in the evidence condition, before the prompt, set `secondsLeft` up the way the dry run did only if you are showing a live panel: recording on, watch `secondsLeft` and `lowTime`, restart the cave, set `secondsLeft` to 12, and step until the clock shows 10. Otherwise leave the participant with the source and the Causal Chain window.

**B1.** "Here is the claim and the diff. The claim says: I changed the exit so it opens after 5 crystals instead of 6. Everything else is unchanged. The diff changes line 71 from `Becomes GEM_TARGET` to `Becomes 5`. Where does the claim disagree with the diff or with the checks? Tell me when you are done."

**B2.** "Here is the claim and the diff. The claim says: Hurry still warns when secondsLeft drops below 11. Everything else is unchanged. The diff changes line 73 from `Below 11` to `Below 5`. Where does the claim disagree with the diff? Tell me when you are done."

In the evidence condition for task B, record the diff with the editor's change set (or open the Last change card the apply produced) and let the participant read the card. For B1, they may press Run checks. Tell them it can take about a minute and a half. Do not read the card aloud.

### After each variant

Ask the three labeling statements for that variant, then "How sure are you, from 1 to 5?", then "What was confusing?"

## Outside-user smoke

Fifteen minutes, one person, evidence condition only, variant A1.

1. Spend about five minutes on the setup steps. Open Behavior evidence on line 71 with the six-crystal snapshot if you have one, or with recording on and a short play that picks up six crystals.
2. Read the A1 prompt. Stop at eight minutes.
3. Ask these three questions, in these words:
   - "What did you use to answer?"
   - "What did the panel show that the source alone did not?"
   - "What was confusing?"

Do not score the smoke as a study result. Write the answers on the sheet and stop.

## Dry run

Done on 12 October 2026 from clean temp copies. The original showcase files were not edited.

| Step | Result |
|---|---|
| Copy the showcase, retarget the addon symlink, set `config/name` to `VG Pilot`, run headless Godot 4.6.1. | The extension loaded. `analyze` printed the Hurry root and steps listed in the A2 key. |
| Sixteen `StepCave(0, 0)` calls from `secondsLeft` 12. | `secondsLeft` 10, `lowTime` true, `warningSignals` 1, one Hurry `whenever_fired`. Temp copy and `user://` for that run were deleted. |
| `build_card` for `Below 11` to `Below 5`. | Static row `Hurry \| trigger changed \| target 11 -> 5`. Other Whenever sections unchanged. |
| `scripts/run_editor_ui_probe.sh` on Godot 4.6.1 and 4.7.2. | Pass. Panel header, row statuses, B1 card, Run checks (`fail` / `pass`), rollback byte identity, and the conflict case matched the B1 and A1 keys. |

The editor steps were driven by the probe. The screenshots were read afterward. A person did not click the toggles by hand.
