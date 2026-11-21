# Cursor handoff: C3 collection testing

## Objective

Find reproducible collection and indexed-access bugs using small, independently
reviewed checkpoints. Start with deterministic tests for arrays and dictionaries
before designing a generated campaign. This is not a claim that broader bug
testing is complete.

Cursor is on **Auto** for this assignment. Do not edit C++ runtime, parser,
compiler, or VM code on Auto: if a confirmed defect needs such a change, stop
with a minimal reproduction and ask for review. The user can then switch Cursor
to **Grok 4.7 xhigh** for the focused fix. Return to Auto for mechanical testing
and documentation only after the runtime changes are stable.

## Collaboration

Work one checkpoint at a time. At each checkpoint, submit a status containing
the exact changes, commands, results, log locations, binary provenance, actual
execution paths, exclusions, and any blockers. Then stop modifying files until
Copilot reviews the status and supplies the next checkpoint. If your environment
permits an attached, low-frequency wait, wait for the next instruction; never
use a detached or busy-loop watcher. If waiting is blocked, say so and ask the
user to relay the next instruction. Do not claim to be waiting if you are not.

Copilot will review independently; do not proceed autonomously to a runtime
fix, new generator, commit, or release. Stop the exchange when Copilot says
`DECISION: COMPLETE` or `DECISION: BLOCKED`.

## Baseline and safeguards

- Inspect `git status --short`, HEAD, and the actual engine and extension binary
  paths and hashes. The checkout already has unrelated dirty and untracked work;
  preserve it. Do not stage, clean, revert, commit, push, or change releases.
- The main editor `.so` is already modified and is not the tested candidate from
  the preceding task. Do not overwrite it. Use an isolated checkout and project;
  verify the candidate's source and binary provenance before using it. If the
  prior isolated checkout is unavailable or has drifted, report it and stop
  rather than silently testing the old main binary.
- The previous isolated candidate was under
  `/tmp/vg-bugfix-002-byval-iso-a28c81f0` with extension SHA-256 prefix
  `3bdcff526a01370d`. Verify rather than assume it still matches the current
  uncommitted sources. Use an independent `godot-cpp` directory, not a symlink
  into the main checkout, when building.
- Do not overwrite `test_proj/current_test.txt`; use the isolated project's
  supported argument-based test runner. Run shared-resource tests serially and
  clean up only paths created for this work.
- The prior VG-only run reported 298 files and 2,128 passing assertions; it did
  not run every test phase. A Tier-3 *request* is not proof of Tier-3 execution.
  GitHub Actions and leak-checker results were not established for these changes.

## Checkpoint 1: inventory and deterministic test plan

Read [SEMANTIC_FUZZ_CONTRACTS.md](SEMANTIC_FUZZ_CONTRACTS.md), the existing
collection/index fixtures and semantic gate code, and the language reference.
Search for existing array, dictionary, missing-key, `ReDim`, and ByRef tests
before proposing new ones. Record exact source references for every proposed
expected result. Do not treat agreement between runtime modes as an independent
oracle.

Produce a compact coverage matrix covering:

1. Array reads and writes at valid indices, including changing-index side
   effects and an unchanged neighboring slot.
2. Dictionary present/missing keys, value and type observations, mutation, and
   the documented missing-key `Err.Number` behavior where applicable.
3. Collection elements passed to procedures, including ByVal controls and
   supported ByRef write-back in standalone and expression calls.
4. Mutation, replacement, or resize during a call as **observational** probes
   unless the language contract establishes the result independently.
5. Boundary and error cases only where their behavior is supported by a
   documented rule or existing agreed test contract.

Distinguish already-covered cases from real gaps, and mark unsupported or
ambiguous semantics as exclusions. Propose a small first fixture set with
hand-worked expected values, types, event counts/order, and target functions
whose paths should be captured. Do not write fixtures, alter the oracle, or
change runtime code in this checkpoint. Submit the matrix and stop for review.

## Later checkpoints, only after review

- Add approved deterministic fixtures and a fail-closed runner or reuse an
  existing gate. Check exit status, script/runtime errors, exact assertion
  identities/counts, completion, and required paths. Prove the actual gate
  rejects injected wrong value, wrong type, missing/duplicate assertions,
  unexpected errors, and path mismatch. No silently accepted known failures.
- Run forced AST, interpreter, default, and Tier-3-request modes. Record actual
  target-function paths and explicit fallback or decline; don't label a mode
  bytecode/native if the function actually ran in AST.
- Preserve full logs and minimal reproductions. When a case fails, establish
  whether it is a harness problem, an unsupported feature, a disputed contract,
  or a runtime defect; report uncertainty instead of changing expectations to
  make it green.
- Only after deterministic coverage and contracts are reviewed, propose a bounded
  independent collection model and generated cases. Keep unsupported and
  unsettled cases out of the random oracle and report coverage honestly.

## Explicit exclusions and known issues

- Indexed ByRef currently freezes the **index**, not the container identity.
  `ReDim` during a call can redirect write-back; its intended semantics are
  unsettled. Do not turn the observed result into a language law.
- MemoryBuffer indexed ByRef write-back remains an explicit known limitation;
  direct indexed assignment is a separate behavior. Do not hide or silently
  accept the limitation as correct general collection behavior.
- Repeated ByRef alias behavior and named-argument ordering are not locked
  contracts. Same-name imported `Twin` dispatch is a separate known defect.
- C1 Variant/Double random modeling, C4 short-circuit/error handling, longer
  campaigns, game-shaped integration, and sanitizer testing remain future
  work. Do not claim C3 or overall bug testing complete from a single checkpoint.
