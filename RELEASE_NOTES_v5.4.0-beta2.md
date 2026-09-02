# VisualGasic 5.4.0-beta2 Release Notes

**Release Date:** October 15, 2026  
**Status:** Beta (Pre-release)  
**Milestone:** M5 — Buffer Type + Optimizer Hints + Narcea golden path  
**Previous Release:** [5.4.0-beta1](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.4.0-beta1)  
**Target Engine:** Godot 4.6.1  
**Platforms:** Linux x86_64, Windows x86_64

---

## Overview

VisualGasic 5.4.0-beta2 closes the M5 milestone with the final language/runtime pieces for Buffer Type and optimizer hints, plus the Narcea golden-path validation and CI hardening that keeps the GDExtension smoke gate stable on GitHub runners.

This release is about correctness and release hygiene: the extension can now be materialized reliably in fresh CI clones, the `.vg` suite stays green under the headless runner, and the golden-path harness covers both the canonical scaffold and a recorded Tier B gameplay scenario.

---

## What shipped

### Buffer Type

- `Dim mem As Buffer` and related byte-level access paths compile through dedicated `OP_BUF_*` opcodes.
- Local buffer reads/writes round-trip cleanly for emulation-style workloads and I/O-heavy patterns.
- The buffer semantics are covered by dedicated regressions in `test_proj/test_suite/test_buffer_type.vg`.

### Optimizer Hints

- User-facing directives like `@accumulator`, `@loop_counter`, `@fast_loop`, `@simd_candidate`, and `@pure` remain runtime-safe metadata markers.
- They are accepted by the compiler without altering semantics, so optimizer passes can tune hot loops without requiring a new VM contract.
- Covered by `test_proj/test_suite/test_optimizer_hints.vg`.

### Narcea ready-state

- Tier A canonical form scaffold remains green.
- Tier B recorded replay support adds a platformer-style game scenario to the manifest and response set.
- The golden validator is now a real project check for both form scaffolds and replay compatibility.

### CI / release hardening

- `scripts/prepare_ci_gdextension.sh` now replaces nested symlinks with a real addon tree before loading the extension in CI.
- This addresses the GitHub runner failure mode where the loader was not being registered even though the local checkout was fine.
- The `--vg-only` suite gate and GDExtension smoke check now run reliably on fresh Actions workers.

---

## Validation

The release cut was validated with the project’s actual headless gates:

- `./run_test_suite.sh --vg-only` — green on the local runner
- GDExtension smoke load — green after materializing the real addon tree
- Narcea Tier A/B golden path — green
- Benchmark regression and command-reference gates were checked as part of the release gate sequence

---

## Release checklist

- [x] Move M5 items from `CHANGELOG.md` “Upcoming” into a release section
- [x] Add `RELEASE_NOTES_v5.4.0-beta2.md`
- [x] Fix CI GDExtension loader registration path
- [x] Validate `.vg` suite + smoke gate
- [x] Validate Narcea Tier A/B
- [ ] Create GitHub pre-release tag and publish release (Oct 15 target)

---

## Known notes

- The GitHub release itself should be published as a pre-release with the tag `v5.4.0-beta2` once the repository owner is ready to push the cut.
- The project remains aligned with Godot 4.6.1 for runtime compatibility and published benchmark gates.
