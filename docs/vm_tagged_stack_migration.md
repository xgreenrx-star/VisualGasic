# VM Tagged (Unboxed) Value-Stack Migration Plan

Status: **Phase 2 foundation landed; live-VM migration NOT started.**
Owner scope: `src/visual_gasic_instance_bytecode_vm.cpp`, `src/visual_gasic_bytecode.h`.
Prereq reading: `/memories/repo/vg_bytecode_perf.md` ("POST-AG FLOOR"), this file.

---

## 1. Why

The bytecode VM's operand stack is `std::vector<Variant>` (`VMState::stack`). Every
push/pop constructs/destructs a `Variant` even on the typed integer/float hot paths.
Profiling proved the interpreter is **instruction-bound** (IPC 2.63, ~0 branch-misses —
computed-goto is measured and ruled out), so the only lever left is cutting the number
of Variant operations. The **fresh baseline** shows the fused-op benchmarks already beat
GDScript 50–250× (Arithmetic 26µs vs 6604µs), but **non-fused** code (irregular numeric
logic, the C64 CPU core, interpreters, state machines) still pays the full boxed-stack tax
and runs ~6.2× slower per instruction than GDScript (8,323 vs 1,338 instr/call). The
unboxed stack is the documented path to close that gap.

## 2. What already exists (Phase 1 — DONE)

- Typed shadow locals `_typed_i64_inline[8]` / `_typed_f64_inline[8]` (+ heap spill),
  maintained by `sync_local` / `read_local` / `sync_local_i64`.
- Typed opcodes: `OP_ADD_I64` / `SUB` / `MUL`, `OP_ADD_F64` / `SUB` / `MUL` / `DIV`,
  `OP_*_I64_CONST`, `OP_INC_LOCAL_I64`, `OP_LESS_EQUAL_I64` / `EQUAL_I64` / `NOT_EQUAL_I64`,
  and a large family of fused superword ops (`OP_ARITH_SUM`, `OP_SUM_ARRAY_I64`,
  `OP_ALLOC_FILL_I64`, `OP_BRANCH_SUM`, `OP_SUM_VGDICT_ALL_I64`, closed-form Gauss sums).
- **These still push/pop `Variant` on the operand stack.** Even `OP_ADD_I64` reads two
  Variants from `vm.stack`, pops two, and constructs one. That residual is Phase 2's target.

## 3. The foundation (landed this sprint)

- `src/visual_gasic_stack_value.h` — `StackValue` tagged union (int64/double/bool unboxed;
  everything else inline-boxed as `Variant`), with correct union-member lifetime
  (placement-new + explicit dtor gated on the tag), `noexcept` move, and from/to-Variant
  conversion. This isolates the single hardest correctness problem of the whole redesign.
- `src/visual_gasic_stack_value_selftest.cpp` — in-process validation (lifetime across
  copy/move/assign, tag transitions, refcounted payload integrity, `std::vector` realloc,
  and a scalar push/pop micro-benchmark vs a Variant stack). Built with `scons tagged_stack=1`,
  run with `VG_STACKVALUE_SELFTEST=1`.
- `tagged_stack=1` SConstruct flag → `VG_TAGGED_STACK`. **Default build is byte-identical**
  (self-test TU compiles to nothing; init hook is `#ifdef`'d out).

## 4. DO-NOT-TOUCH (regression landmines — from vg_bytecode_perf.md)

- `OP_*_I64_CONST` **emission** — tier2/tier3 JIT models it as a LOCAL-slot load from `ip+1`.
  Changing the compiler emission risks JIT breakage the suite may not cover. (Migrating the
  VM-side *handler* to unboxed push is fine; do NOT touch the compiler's emission.)
- `push_value(std::move(lvalue))` for maybe-INT values — a 24-byte swap-MOVE costs more than
  an 8-byte int copy and regressed measurably. (Moot once the stack is unboxed, but relevant
  during the dual-representation transition.)
- The `__cse_` single-use round-trip peephole — needs liveness + jump re-patching.

## 5. The hard part: direct `vm.stack[...]` access sites

`push_value` / `pop_value` are the main interface, **but not the only one**. Several hot
handlers index `vm.stack` directly and assume the element type is `Variant`. These MUST be
converted first or the element-type change won't compile/run:

- `OP_ADD_I64` / `SUB_I64` / `MUL_I64`: read `vm.stack[size-1]` / `[size-2]` as `const Variant&`.
- `OP_DUP`: `push_value(vm.stack[vm.stack.size() - 1])`.
- `ensure_stack`, the stack-profile depth math, and the underflow diagnostics read `vm.stack.size()`.
- The `apply_variant_op` helper and every handler using `pop_value()` / `push_value(...)`.

Audit with: `grep -n 'vm\.stack\[' src/visual_gasic_instance_bytecode_vm.cpp` before starting.

## 6. Incremental migration strategy (dual-representation, flag-gated)

The goal is to change `VMState::stack` from `std::vector<Variant>` to `std::vector<StackValue>`
**without a big-bang rewrite**, keeping every step suite-green under BOTH flag states.

### Step A — element type + transparent conversion layer (behind VG_TAGGED_STACK)
1. In `bytecode.h`, gate the stack type:
   `#ifdef VG_TAGGED_STACK std::vector<StackValue> stack; #else std::vector<Variant> stack; #endif`.
2. Make `push_value(const Variant&)` / `push_value(Variant&&)` / `pop_value() -> Variant`
   convert via `StackValue::from_variant` / `to_variant`. Now EVERY existing handler compiles
   and runs unchanged (Variant in, Variant out) — just with a conversion at the boundary.
3. Convert the direct `vm.stack[...]` sites (§5) to read via `to_variant()` / `to_int()`.
4. Validate: full suite 895/895 under `tagged_stack=1` AND default. Expect a SMALL regression
   here (conversion overhead) — that's fine; the win comes in Step B. A/B per vg_bytecode_perf.md.

### Step B — unboxed fast paths (the actual win)
Migrate hot handlers to skip the Variant conversion, one coherent group at a time. After each
group: full suite (both flag states) + benchmark A/B (`scripts/benchmark_regression_check.sh`).
Order by ROI and isolation:
1. Arithmetic: `OP_ADD_I64/SUB_I64/MUL_I64` → `pop_int64()/push_int64()` (touch only the scalar
   union member; no Variant). Then `OP_ADD_F64/...` → `pop_float()/push_float()`.
2. Compare: `OP_EQUAL_I64/NOT_EQUAL_I64/LESS_EQUAL_I64` and the generic compares when both
   operands are scalar tags.
3. Local load/store: `OP_GET_LOCAL/SET_LOCAL` push/pop `StackValue` directly from the typed
   shadow arrays when `local_types[slot]` is VT_INT/VT_FLOAT.
4. Constants: `OP_CONSTANT` for INT/FLOAT constants → push scalar `StackValue` directly.
5. Control flow: `OP_JUMP_IF_FALSE/TRUE` → `pop().to_bool()` without boxing.

### Step C — interop boundary (box only here)
Anything that hands a value to Godot (`OP_CALL`, `OP_GET/SET_MEMBER`, array/dict ops, `OP_PRINT`,
signals, string ops) calls `.to_variant()` to box on the way out and `from_variant()` on the way
in. The boxed lane already handles all non-scalar types, so these keep working; they just lose the
"free" unbox on the scalar path (acceptable — interop is not the hot numeric loop).

### Step D — debugger / disassembler
`debug_bc_locals` still exposes the Variant `locals` view (unchanged — locals are a separate array
from the operand stack). Any stack-inspecting debug path boxes via `.to_variant()` on read.

### Step E — flip default + delete the Variant stack
Once Step B parity is proven across many sessions and the benchmark suite shows the win with no
regressions, make `VG_TAGGED_STACK` the default, then remove the `#else` Variant branch.

## 7. Success criteria

- Full suite 895/895 under both flag states at every step.
- `scripts/benchmark_regression_check.sh` stays green (VG within 1.05× of GDScript on published
  workloads — must not regress the fused wins).
- Two-point instr:u A/B (per vg_bytecode_perf.md) shows a net **reduction** in instr/call on the
  non-fused BenchCall path; target is meaningful progress toward GDScript's 1,338 instr/call.
- No new leaks (the StackValue self-test + suite under asan is the guard).

## 8. Risk controls

- Every step is behind `VG_TAGGED_STACK` until Step E; default stays byte-identical.
- Keep the Variant-stack `#else` branch as the always-available fallback until parity is proven.
- Never combine two Step-B opcode groups in one unvalidated change.
- Re-measure a FRESH baseline each session (git stash + rebuild); never trust a cached `.so`.
