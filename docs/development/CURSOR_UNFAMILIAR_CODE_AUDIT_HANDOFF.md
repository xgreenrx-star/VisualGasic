# Cursor Handoff: Unfamiliar-Code Audit & Comprehension Gate

## 1. Assignment and Stop Boundary

Extend VisualGasic's Behavior Evidence system so a developer can audit unfamiliar or AI-generated changes through an **execution-ordered breakdown**, **novel-symbol detection**, and an **active comprehension gate** before accepting changes.

### Deliverables:
1. **Execution-ordered card breakdown (Static section):** Expand changed/added `Whenever` sections into sequential execution steps (declaration line, guard, early exits, state writes, calls) and summarize non-Whenever procedure edits.
2. **Novel symbol markings:** Mark procedures and module variables in changed code as `new:` vs `already in project:`.
3. **Comprehension gate ("What does this change do?"):** Add a dedicated user input box, store the user's sentence in `vg_change_set` under `source: "user"`, and gate `Keep` until filled.
4. **Sentence vs Static comparison:** Add a non-blocking advisory check when the sentence references superseded target values without mentioning the new values.
5. **Protected expectation tie-in:** Optional checkbox to store the user's sentence as a note in `vg_expectations.json`.
6. **Paged multi-section audit:** Paginate multiple changed `Whenever` sections in the UI while keeping filesystem writes atomic.
7. **Regression tests:** Unit tests in `tests/` covering all parsing, formatting, matching, and storage logic on both Godot 4.6.1 and 4.7.2.

### Strictly Out of Scope:
- Modifying the standalone VG IDE shell or Context Rail.
- Partial filesystem writes (all file writes on disk must remain atomic to prevent syntax/reference corruption).
- Calling external AI models for verification.
- Rebuilding C++ libraries (this feature is pure GDScript within `addons/visual_gasic/` and `tests/`).

### Protected Files (Do Not Edit, Stage, or Revert):
- `.github/copilot-instructions.md`
- `samples/showcases/crystal_caverns/Caverns.vg`
- `samples/showcases/crystal_caverns/VisualEffects.vg`
- `samples/showcases/crystal_caverns/main.tscn`
- `evidence_exit_scenario.gd`
- `save_format_scenario.gd`
- `samples/showcases/crystal_caverns/vg_expectations.json`

---

## 2. Technical Specifications

### Phase A: Execution-Ordered Card Breakdown (`vg_change_card.gd`)
1. **Whenever Section Steps:**
   - In `_diff_reports()`, when a section is `added` or has `trigger changed`, `callbacks changed`, or `writes changed`, format the section details in execution order:
     - `line <N>` (declared line)
     - `guard: <condition>` (e.g. `gameState = StatePlaying And Not exitOpen`)
     - `exit: Exit Sub if ...` (if early returns/debounce guards exist)
     - `writes: <var> = <expr>`
     - `calls: <procedure_name>`
   - Retain unchanged sections as a single line: `<section> | unchanged`.
2. **Non-Whenever Procedures:**
   - Differentiate file-level diffs: if procedures outside of `Whenever` blocks (e.g., `Sub`, `Function`) were added, removed, or modified, append a summary row:
     - `procedures: modified Sub CalculateScore (lines 142-160), added Function GetKey ()`
   - Prevents blind spots when AI edits utility code alongside reactive watchers.

### Phase B: Novel Symbol Marking (`vg_change_card.gd`)
1. **Symbol Extraction:**
   - Scan procedure definitions (`Sub`, `Function`), event handlers, and module-level `Dim` variables in the `after` text.
   - Compare them against:
     - The `before` version of the file.
     - All other `.vg` files in the project workspace (`res://`).
2. **Display Row:**
   - Append a `symbols` row to the card's static report:
     - `symbols: new: [OnUnlockExit] | already in project: [PlayCue, GEM_TARGET]`
   - If no new symbols are introduced: `symbols: all existing in project`.

### Phase C: Comprehension Gate & Attribution (`vg_change_set.gd`, `code_navigator.gd`, `vg_ai_help.gd`)
1. **Storage Schema (`vg_change_set.gd`):**
   - Add optional field to the change set manifest:
     ```gdscript
     "user_summary": {
         "source": "user",
         "text": "",
         "timestamp": 0
     }
     ```
   - Keep the AI model's claim (`source: "model"`) and the developer's sentence (`source: "user"`) strictly separated.
2. **UI Container:**
   - Rather than embedding an input into `_output` (`RichTextLabel`), add a dedicated container in the Code Navigator Change Card review area (or in `vg_ai_help.gd` action bar):
     - `Label`: "What does this change do?"
     - `LineEdit`: Placeholder `"Summarize the intended behavior in one sentence..."`
     - Connect `text_changed`: disable `Keep` button / link until stripped text has at least 5 characters.
   - When `Keep` is triggered:
     - Call `CS.record_user_summary(id, text)`.
     - Clear the undo stack as usual.

### Phase D: Soft Mismatch Advisory Heuristic (`vg_change_card.gd`)
1. **Contradiction Detection:**
   - Inspect the static changes (e.g. `target GEM_TARGET -> 5`).
   - If the user's sentence contains tokens of the old target (e.g. `"6"`, `"GEM_TARGET"`) and *omits* the new target (`"5"`):
     - Flag an advisory banner: `Advisory: Code sets target to 5, but your sentence only mentions 6. Verify before keeping.`
   - **Crucial:** Never block the user from proceeding if they intended to describe a transition (e.g., *"Changed target from 6 to 5"* must pass without warning).

### Phase E: Protected Expectation Tie-In (`vg_expectations.gd`, `code_navigator.gd`)
1. **Opt-in Checkbox:**
   - Beside the sentence input, show `[ ] Save as protected expectation`.
2. **Manifest Update:**
   - If checked and the project has `vg_expectations.json`:
     - Append a new expectation item:
       ```json
       {
         "id": "exp_<hash>",
         "note": "<user_sentence>",
         "file": "<path>",
         "section": "<section_name>",
         "status": "pending"
       }
       ```
   - If the file does not exist, leave it untouched unless explicitly requested.

### Phase F: Multi-Section Paged Audit (`code_navigator.gd`)
1. **Atomic Disk Persistence:**
   - File writes on disk must NOT be split. All files in the change set are applied at once to avoid broken compilation.
2. **UI Pagination:**
   - If the static diff has multiple modified/added `Whenever` sections:
     - Code Navigator shows pagination controls: `Section 1 of N: <Name> [Next >]`.
     - Track `reviewed_sections: Array[String]`.
     - `Keep` is enabled only after each changed section has been viewed and the summary sentence is confirmed.

---

## 3. Files to Touch

- `addons/visual_gasic/vg_change_card.gd`:
  - Add execution ordering in `_diff_reports()`.
  - Add non-Whenever procedure diffing.
  - Add symbol novelty scanner (`new:` vs `already in project:`).
  - Add advisory comparison heuristic.
- `addons/visual_gasic/vg_change_set.gd`:
  - Add `record_user_summary(id: String, text: String)`.
  - Add `user_summary` to change set JSON output.
- `addons/visual_gasic/code_navigator.gd`:
  - Add sentence `LineEdit` and "Save as expectation" `CheckBox`.
  - Add multi-section pagination state and controls.
  - Wire up gating for the Keep action.
- `addons/visual_gasic/vg_ai_help.gd`:
  - Ensure `Review change` link opens the card with the comprehension prompt focused.
- `tests/test_vg_change_card.gd`:
  - Unit tests for step ordering, procedure diffs, symbol classification, and advisory detection.
- `tests/test_vg_change_set.gd`:
  - Unit tests for `user_summary` persistence and retrieval.

---

## 4. Verification & Validation Steps

1. **Headless Unit Tests:**
   Run on both Godot 4.6.1 and 4.7.2:
   ```bash
   ./Godot_v4.6.1-stable_linux.x86_64 --headless --path samples/showcases/crystal_caverns --script $PWD/tests/test_vg_change_card.gd
   ./Godot_v4.6.1-stable_linux.x86_64 --headless --path samples/showcases/crystal_caverns --script $PWD/tests/test_vg_change_set.gd
   ```
2. **In-Editor UI Probe:**
   Verify that the editor probe still passes cleanly without regressions:
   ```bash
   ./scripts/run_editor_ui_probe.sh
   ```
3. **Full Suite Smoke:**
   ```bash
   ./run_test_suite.sh --vg-only
   ```

---

## 5. Instructions for Cursor

- **Write failing unit tests first** in `tests/test_vg_change_card.gd` and `tests/test_vg_change_set.gd` before modifying the addon code.
- Implement Phase A and Phase B first, verify unit tests, then proceed to Phases C–F.
- When finished, run tests on both Godots, confirm `scripts/run_editor_ui_probe.sh` passes, and report the exact pass counts and diffs.
- **Do not commit or push.** Leave staging and committing for Copilot review.
