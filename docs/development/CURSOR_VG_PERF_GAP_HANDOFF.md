# Handoff: close the VG vs GDScript speed gap

Audience: Cursor agent. Read all of this before you edit code.
Recommended model: the strongest model you have, in max mode. This is JIT and VM work.
Mistakes show up as wrong results, not as crashes.

## 1. Goal and rules

Goal: every case in `test_proj/perf/vm_gap/run_gap.gd` runs at `vg/gd <= 1.00` in default mode (JIT on).
The secondary goal is `vg/gd <= 1.00` with `VG_JIT=0` (interpreter only).

Rules. Do not break any of them.

1. Correctness before speed. A faster wrong answer is a regression.
   `run_gap.gd` exits 1 when a VG result differs from the GD result. Keep it at 0.
2. Do not write GDScript game code. GDScript is allowed only for test harnesses like the ones in `test_proj/perf/vm_gap/`.
3. Run the full validation in §6 after each workstream, in every mode listed there.
4. Never rebuild the `.so` while a regression loop runs. The loop loads the library from disk. A rebuild mid-run gives random failures.
5. Commit one workstream per commit. Use `git add <paths>`. Never `git add -A`.
   Never commit `.so`, `.gradle`, or `.avi` files.
   Every commit message ends with:
   `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`
6. Follow the code conventions in `.github/copilot-instructions.md`.
   C++ uses tabs. Errors give actionable messages with exact line numbers.
   Do not refactor outside the task.
7. If a workstream does not reach its target after an honest attempt, stop. Commit what is correct and faster. Write down what you measured. Do not leave half-finished opcodes in the tree.

## 2. Benchmark

Files are in `test_proj/perf/vm_gap/`:

| File | Purpose |
|---|---|
| `micro.vg` | VG benchmark functions. Each takes `n` and loops `n` times. |
| `micro.gd` | The same functions in GDScript. Must stay semantically identical to `micro.vg`. |
| `run_gap.gd` | Best of 5 runs, N=200000, ns per iteration, `vg/gd` ratio, result check. |
| `dump_bytecode.gd` | Prints the optimized bytecode of the named functions. |
| `hot_case.gd` | Runs one VG case for a long time, for `perf record`. |

Run them from the repo root:

```bash
G=/home/Commodore/Downloads/Godot_v4.7.2-stable_linux.x86_64
cd test_proj
# default (JIT on)
taskset -c 2 $G --headless --path . --audio-driver Dummy --script res://perf/vm_gap/run_gap.gd
# interpreter only
VG_JIT=0 taskset -c 2 $G --headless --path . --audio-driver Dummy --script res://perf/vm_gap/run_gap.gd
# bytecode
$G --headless --path . --audio-driver Dummy --script res://perf/vm_gap/dump_bytecode.gd -- t_dict t_call
# JIT decisions
VG_JIT_LOG=1 $G --headless --path . --audio-driver Dummy --script res://perf/vm_gap/run_gap.gd 2>&1 | grep -i jit
# CPU profile of one case
P=/usr/src/linux-headers-6.12.7-2-liquorix-amd64/tools/perf/perf
VG_JIT=0 $P record -o /tmp/vg.data -F 2000 -g --call-graph=fp -- \
  $G --headless --path . --audio-driver Dummy --script res://perf/vm_gap/hot_case.gd -- t_call 5000000
$P report -i /tmp/vg.data --no-children --stdio --sort sym | head -40
```

Timings vary by about ±10% between runs. Always pin to one core (`taskset -c 2`).
Compare ratios from the same run, not absolute numbers from different runs.

## 3. Baseline (commit `e8f5f8f8`, 16 Nov 2026)

ns per loop iteration. Lower is better.

| Case | What it does | GD | VG JIT | ratio | VG `VG_JIT=0` | ratio |
|---|---|---|---|---|---|---|
| t_local | `s = s + h`, Single locals | 10.2 | 2.1 | 0.21 | 31.8 | 3.16 |
| t_global | `s = s + g`, g is a module Single | 9.3 | 2.2 | 0.24 | 34.9 | 3.45 |
| t_getx | `s = s + p.x`, p is a Variant holding Vector2 | 21.7 | 37.2 | 1.71 | 38.3 | 1.69 |
| t_getx_typed | same, `Dim p As Vector2` | 12.1 | 37.8 | 3.11 | 38.0 | 3.10 |
| t_sety | `p.y = p.y + 1` | 24.1 | 56.2 | 2.33 | 58.6 | 2.37 |
| t_dict | `s = s + d("k")`, module Dictionary | 34.5 | 83.1 | 2.40 | 77.9 | 1.95 |
| t_streq | `If gs = "talk" And Not gb Then c = c + 1` | 32.1 | 100.4 | 3.13 | 106.7 | 3.45 |
| t_call | `s = s + empty_fn()` | 69.1 | 151.4 | 2.19 | 109.0 | 1.45 |
| t_vec | `v = v + Vector2(0.5, 1)` | 12.1 | 40.8 | 3.36 | 38.8 | 3.12 |
| t_sin | `s = s + Sin(i)` | 38.6 | 24.1 | 0.63 | 76.7 | 1.94 |
| external_call | GDScript calls `vg.call("empty_fn")` | 67.8 | 163.3 | 2.41 | 270.5 | 3.86 |

Read the table like this:

- When the Tier-2 JIT compiles a function (`t_local`, `t_global`, `t_sin`), VG is 1.6–5x faster than GD. The JIT works for scalars.
- Every case that touches a Variant (Vector2, Dictionary, String, a function call) is 1.7–3.4x slower than GD in both modes.
  For those, the JIT either bails or calls back into the slow interpreter path.
- `t_call` is slower with the JIT (151) than without (109). This is a regression.
- The interpreter's per-op overhead is about 3x GDScript's. You can see it in `t_local` with `VG_JIT=0`: a 3-op loop takes 31.8 ns against GD's 10.2.

### 17 Nov 2026, after the integer-store fast path

`run_gap.gd`, one best-of-5 run, `mismatches=0` both modes. The CPU was at full speed (GD `t_local` ~13 ns, against ~80 ns in the WS2/WS3 tables). Ratios are the comparison.

| Case | GD | VG JIT | ratio | VG `VG_JIT=0` | ratio |
|---|---|---|---|---|---|
| t_local | 12.9 | 2.8 | 0.22 | 8.0 | 0.57 |
| t_global | 12.9 | 2.8 | 0.22 | 9.0 | 0.65 |
| t_gint | 12.6 | 0.8 | 0.07 | 14.4 | 1.08 |
| t_gint_if | 22.6 | 1.2 | 0.05 | 19.9 | 0.82 |
| t_getx | 29.0 | 22.3 | 0.77 | 23.2 | 0.73 |
| t_getx_typed | 16.0 | 22.3 | 1.39 | 24.1 | 1.40 |
| t_sety | 32.4 | 46.2 | 1.43 | 50.1 | 1.42 |
| t_dict | 51.2 | 85.0 | 1.66 | 95.8 | 1.75 |
| t_streq | 45.0 | 73.0 | 1.62 | 78.4 | 1.67 |
| t_call | 100.5 | 3.1 | 0.03 | 142.4 | 1.43 |
| t_vec | 20.4 | 33.8 | 1.66 | 60.3 | 1.61 |
| t_sin | 58.2 | 35.1 | 0.60 | 43.4 | 0.58 |
| external_call | 101.7 | 239.9 | 2.36 | 408.8 | 4.15 |

`t_gint` before this fast path, interpreter, `hot_case.gd` 2e6 iterations: 4018 ns/iter. After: 10.8 ns/iter. `t_gint_if` (the store inside `If`, a different global, step 2): 3956 ns → 17.8 ns. Both results match GDScript. Subtracted user-mode cost of the after loop: 44 cycles and 276 instructions per iteration.

The interpreter `t_gint` ratio is 1.08, just over the secondary goal of 1.00. The store still happens on every iteration.

### 17 Nov 2026, after local vector axis ops

`run_gap.gd`, one best-of-5 run, `mismatches=0` both modes. GD `t_local` was 8.9 ns with the JIT on and 10.1 ns with `VG_JIT=0`, so the clock is faster than the integer-store table. The GD column is the JIT-on run. Each ratio is from its own run.

| Case | GD | VG JIT | ratio | VG `VG_JIT=0` | ratio |
|---|---|---|---|---|---|
| t_local | 8.9 | 1.9 | 0.22 | 5.8 | 0.58 |
| t_global | 8.8 | 2.1 | 0.24 | 6.3 | 0.66 |
| t_gint | 9.0 | 0.6 | 0.07 | 9.6 | 0.98 |
| t_gint_if | 15.3 | 0.8 | 0.05 | 14.1 | 0.81 |
| t_getx | 20.1 | 7.0 | 0.35 | 7.9 | 0.35 |
| t_getx_typed | 10.6 | 7.0 | 0.66 | 7.5 | 0.62 |
| t_sety | 21.3 | 10.7 | 0.50 | 10.9 | 0.45 |
| t_dict | 33.9 | 55.6 | 1.64 | 55.4 | 1.66 |
| t_streq | 28.7 | 45.8 | 1.60 | 48.5 | 1.49 |
| t_call | 62.4 | 2.0 | 0.03 | 77.7 | 1.31 |
| t_vec | 12.1 | 4.4 | 0.36 | 4.5 | 0.38 |
| t_sin | 34.5 | 22.2 | 0.64 | 15.3 | 0.44 |
| external_call | 61.1 | 153.7 | 2.52 | 252.3 | 4.18 |

`t_getx`, `t_getx_typed`, `t_sety` and `t_vec` were 0.77 / 1.39 / 1.43 / 1.66 with the JIT on, and 0.73 / 1.40 / 1.42 / 1.61 interpreted. They are now 0.35 / 0.66 / 0.50 / 0.36 and 0.35 / 0.62 / 0.45 / 0.38. All four are under 1.00 in both modes. The acceptance was a JIT ratio ≤ 1.00 and an interpreter ratio ≤ 1.50.

A local `.x` / `.y` / `.z` compiles to `OP_GET_LOCAL_AXIS` or `OP_SET_LOCAL_AXIS`. The generic member instructions are still emitted immediately after, and they run when the value is not a Vector2 or Vector3, or when a Whenever section is mirroring the local. `v = v + Vector2(c)` on a local is `OP_ADD_LOCAL_VEC2_CONST`. Typed and Variant locals both use these ops. Color `.r` stays on `OP_GET_MEMBER`.

Tier 2 still does not compile these four functions. A Vector2 constant is not INT, FLOAT or STRING, so lowering bails at op 0, and `t_vec` returns Variant so it is not attempted. The ratios above are the interpreter in both modes. Scalar replacement of vector locals remains; this commit does not include it.

### 17 Nov 2026, after Tier 2 String and Dictionary globals

`run_gap.gd`, one best-of-5 run, `mismatches=0` both modes. GD `t_local` was 10.1 ns with the JIT on and 9.1 ns with `VG_JIT=0`. The GD column is the JIT-on run. Each ratio is from its own run.

| Case | GD | VG JIT | ratio | VG `VG_JIT=0` | ratio |
|---|---|---|---|---|---|
| t_local | 10.1 | 2.4 | 0.23 | 5.4 | 0.60 |
| t_global | 10.1 | 2.2 | 0.22 | 5.6 | 0.63 |
| t_gint | 9.8 | 0.7 | 0.07 | 9.3 | 1.09 |
| t_gint_if | 17.9 | 0.9 | 0.05 | 12.9 | 0.82 |
| t_getx | 22.9 | 7.8 | 0.34 | 6.9 | 0.35 |
| t_getx_typed | 12.1 | 7.8 | 0.64 | 6.9 | 0.66 |
| t_sety | 24.6 | 12.2 | 0.50 | 10.9 | 0.51 |
| t_dict | 37.5 | 31.6 | 0.84 | 55.4 | 1.70 |
| t_streq | 32.8 | 24.6 | 0.75 | 45.5 | 1.51 |
| t_call | 60.9 | 2.2 | 0.04 | 80.4 | 1.37 |
| t_vec | 12.0 | 4.5 | 0.37 | 4.5 | 0.37 |
| t_sin | 36.3 | 20.9 | 0.58 | 15.5 | 0.44 |
| external_call | 62.0 | 148.2 | 2.39 | 250.6 | 3.69 |

`t_dict` and `t_streq` compile at Tier 2. `VG_JIT_LOG=1` prints Compiled for both and no "lowering failed" line for those names. With the JIT on they are 0.84 and 0.75. They were 1.64 and 1.60. With `VG_JIT=0` they stay on the interpreter (1.70 and 1.51). That is WS6.

A String or Dictionary module global is a pointer to its `Variant`. The pointer is resolved at function entry and again after a call. The lowered shapes are a global String compared with a string constant, and a global Dictionary read of a constant key into a float add. Any other use of that global still refuses the compile.

String compare checks the length, then `memcmp` of the UTF-32 bytes. `Option Compare Text` uses `String::nocasecmp_to`. `Compare` and `Text` were identifiers, so the directive never set the module flag. The parser accepts them now, and `OP_EQUAL` plus the other five relational ops follow the flag the same way the tree-walk already did. The default stays case-sensitive.

A dictionary value that is not a number, or a missing key, returns from the native function. The interpreter continues at that read with the JIT locals written back. It does not restart the function. `OP_GET_DICT_FAST` returns Nothing for a missing key and does not raise; the new test locks VarType 1 and `Err.Number = 0`. After the value becomes the string `"3"`, the sum is 11 (2.5 + 2.5 + 3 + 3).

AST and bytecode now agree: `"3"` coerces to 3 and a missing key coerces like 0 in numeric `+` (via `vg_vb_numeric`). See issue #24 / `CURSOR_5_8_CORE_CORRECTNESS_HANDOFF.md`.

### 17 Nov 2026, after interpreter string, dictionary and leaf-call paths

`run_gap.gd`, one best-of-5 run, `mismatches=0` both modes. GD `t_local` was 10.6 ns with the JIT on and 12.9 ns with `VG_JIT=0`. The GD column is the JIT-on run. Each ratio is from its own run.

| Case | GD | VG JIT | ratio | VG `VG_JIT=0` | ratio |
|---|---|---|---|---|---|
| t_local | 10.6 | 2.3 | 0.22 | 7.4 | 0.57 |
| t_global | 10.6 | 2.4 | 0.22 | 7.4 | 0.57 |
| t_gint | 10.6 | 0.7 | 0.07 | 13.3 | 1.05 |
| t_gint_if | 19.0 | 1.0 | 0.05 | 17.6 | 0.78 |
| t_getx | 24.9 | 8.7 | 0.35 | 9.8 | 0.35 |
| t_getx_typed | 13.4 | 8.7 | 0.65 | 9.7 | 0.64 |
| t_sety | 27.1 | 14.0 | 0.51 | 15.2 | 0.50 |
| t_dict | 42.4 | 30.6 | 0.72 | 50.2 | 1.09 |
| t_streq | 38.6 | 29.8 | 0.77 | 51.9 | 1.27 |
| t_call | 89.2 | 2.8 | 0.03 | 6.5 | 0.08 |
| t_vec | 16.2 | 6.2 | 0.38 | 6.9 | 0.38 |
| t_sin | 46.2 | 28.1 | 0.61 | 22.2 | 0.44 |
| external_call | 83.4 | 206.4 | 2.47 | 372.4 | 4.30 |

Interpreter acceptance: `t_streq` 1.27 (≤ 1.5), `t_dict` 1.09 (≤ 1.3), `t_call` 0.08 (≤ 1.0). With the JIT on, `t_dict` is 0.72 and `t_streq` is 0.77. Both still compile. `VG_JIT_LOG=1` prints Compiled for `t_dict`, `t_streq`, and `t_call`.

`gs = "talk"` is `OP_EQ_STR_CONST`. The compare uses the constant pool String: length and `memcmp`, or `nocasecmp_to` when Option Compare Text is on. A non-string falls through to `OP_EQUAL`. `d("k")` and `d["k"]` are `OP_GET_DICT_CONST` when the key literal is a string, int, bool, or float. A whole-number float still goes through `vg_dictionary_key`. A missing key is Nothing (VarType 1) and does not raise. In the lean loop, `OP_GET_GLOBAL` of a Dictionary followed by `OP_GET_DICT_CONST` reads the key from the global and pushes the value, so the Dictionary is not copied onto the stack. Tier 2's `lower_vref_use` recognizes both new opcodes after `OP_GET_GLOBAL`, and still recognizes the old `OP_CONSTANT` shape.

A zero-argument function whose body is `Return` of an Integer, Double, Boolean, or Nothing, with no parameters and no global write, is classified on the first resolved call. Later calls push that constant and do not build a frame. `empty_fn` is that shape (`OP_CONSTANT` 0, `OP_RETURN_VALUE`). A function that stores a global and then returns is not elided.

`And` stays `OP_AND`. The jump form for a pure Boolean `And` compiled, and Tier 2 then returned 0 from `t_streq`: the operand stack is not merged at the join, so the `If` tested the `False` pushed on the other edge. Integer `And` was never changed. The lean loop already uses `&&` for two Booleans and bitwise `&` for two numbers.

The member-name cache keeps the vector's data pointer and rebinds it when the frame changes or the vector grows. A call with no ByRef parameter skips the capture list. Integer and Double locals are not released on the way out; the next call resets those slots.

### 17 Nov 2026, after external constant returns

`run_gap.gd`, one quiet pair on the final binary, `mismatches=0` both modes. GD `t_local` was 8.8 ns with the JIT on and 9.6 ns with `VG_JIT=0`. The GD column is the JIT-on run. Each ratio is from its own run. Before this change `external_call` was 2.47 and 4.30.

| Case | GD | VG JIT | ratio | VG `VG_JIT=0` | ratio |
|---|---|---|---|---|---|
| t_local | 8.8 | 1.9 | 0.22 | 5.0 | 0.53 |
| t_global | 8.8 | 1.9 | 0.22 | 5.0 | 0.56 |
| t_gint | 8.5 | 0.6 | 0.07 | 9.1 | 1.04 |
| t_gint_if | 15.2 | 0.8 | 0.05 | 12.6 | 0.81 |
| t_getx | 19.9 | 6.9 | 0.35 | 6.9 | 0.35 |
| t_getx_typed | 10.5 | 6.8 | 0.64 | 7.8 | 0.74 |
| t_sety | 21.3 | 10.8 | 0.51 | 12.2 | 0.58 |
| t_dict | 32.5 | 22.7 | 0.70 | 30.9 | 0.96 |
| t_streq | 29.5 | 22.3 | 0.76 | 39.0 | 1.34 |
| t_call | 60.8 | 1.9 | 0.03 | 5.4 | 0.08 |
| t_vec | 11.8 | 4.9 | 0.41 | 5.2 | 0.40 |
| t_sin | 34.7 | 21.2 | 0.61 | 15.1 | 0.39 |
| t_call_host | 73.0 | 282.5 | 3.87 | 156.9 | 2.22 |
| external_call | 57.6 | 55.9 | 0.97 | 55.8 | 0.89 |

Acceptance is `external_call` ≤ 1.2 in both modes: 0.97 and 0.89. Two other pairs on this binary were 0.96 / 0.92 and 1.02 / 0.93, all with `mismatches=0`. A busy core pushed `t_dict` to 1.04 and interpreter `t_streq` to 1.76 while the absolute times were several times the quiet run. The quiet rerun is the table. JIT `t_dict` is 0.70 and `t_streq` is 0.76. Interpreter `t_streq` is 1.34 (≤ 1.5), `t_dict` is 0.96 (≤ 1.3), and `t_call` is 0.08 (≤ 1.0).

`call()` already remembered the `StringName`. A zero-argument function whose body is `Return` of an Integer, Double, Boolean, or Nothing, with no parameters and no global write, runs on the first call and is classified from that chunk. Later calls of the same `StringName` write the cached bits into the return Variant and return. The gap loop uses one name, so the instance keeps that name in one slot and skips the map. The slot stores `script->bytecode_generation` and `refresh_script_caches` clears it. A debugger, the opcode profiler, evidence recording, and `VG_INLINE_CALLS=0` still enter the function. A method whose name contains `input` still takes the normal path, which queues a redraw. `Answer` returns 7 on that same path. `Bump` writes a module integer, `ReadBumps` reads it, and `AddOne` takes an argument; those three still run. `test_proj/test_suite/test_ext_leaf.vg` and `tests/test_ext_leaf_call.gd` cover them. `hot_case.gd` accepts `external` for a profile. `empty_fn` is `Return 0`, and the bytecode pushes Integer 0. The gap does not compare that return.

### 18 Nov 2026, after Len of a global compiles

`run_gap.gd`, one quiet pair, `mismatches=0` both modes. GD `t_local` was 10.1 ns with the JIT on and 12.5 ns with `VG_JIT=0`. The GD column is the JIT-on run. Each ratio is from its own run. Before this change `t_call_host` was 3.87 and 2.22.

| Case | GD | VG JIT | ratio | VG `VG_JIT=0` | ratio |
|---|---|---|---|---|---|
| t_local | 10.1 | 2.3 | 0.22 | 7.1 | 0.56 |
| t_global | 10.3 | 2.5 | 0.24 | 7.6 | 0.61 |
| t_gint | 10.3 | 0.7 | 0.07 | 13.4 | 1.10 |
| t_gint_if | 18.6 | 1.0 | 0.05 | 17.7 | 0.82 |
| t_getx | 24.5 | 8.6 | 0.35 | 9.7 | 0.35 |
| t_getx_typed | 13.4 | 8.7 | 0.64 | 9.7 | 0.64 |
| t_sety | 27.1 | 13.6 | 0.50 | 15.2 | 0.50 |
| t_dict | 42.3 | 30.3 | 0.72 | 43.8 | 0.95 |
| t_streq | 38.5 | 31.0 | 0.80 | 53.4 | 1.32 |
| t_call | 87.3 | 2.7 | 0.03 | 6.5 | 0.07 |
| t_vec | 18.8 | 6.9 | 0.37 | 6.0 | 0.37 |
| t_sin | 53.8 | 31.7 | 0.59 | 20.6 | 0.43 |
| t_call_host | 106.9 | 10.2 | 0.10 | 152.7 | 1.60 |
| external_call | 96.1 | 87.6 | 0.91 | 76.5 | 0.96 |

`tag_len` is `Return Len(gs) + i`. Tier 2 compiles `Len` of a String or Dictionary global as the integer `OP_LEN` returns, and `t_call_host` calls that body directly. An Integer or Long direct-call result stays an integer. `wide` is the second shape: a different global, and the `Len` sits inside an `If`. The lean loop applies `Len` to the global in place, so the String is not copied onto the stack. With `VG_JIT=0` the call still enters the ordinary handler, which is why that ratio is 1.60. On this run every JIT-on case is at or under 1.00.

### 18 Nov 2026, after a one-argument add to a module number

`run_gap.gd`, one quiet pair, `mismatches=0` both modes. GD `t_local` was 8.8 ns with the JIT on and 8.9 ns with `VG_JIT=0`. The GD column is the JIT-on run. Each ratio is from its own run. Before this change, interpreter `t_call_global` was 4.57.

| Case | GD | VG JIT | ratio | VG `VG_JIT=0` | ratio |
|---|---|---|---|---|---|
| t_local | 8.8 | 2.0 | 0.23 | 5.0 | 0.57 |
| t_global | 9.8 | 1.9 | 0.20 | 5.8 | 0.66 |
| t_gint | 9.5 | 0.7 | 0.07 | 9.8 | 1.15 |
| t_gint_if | 16.2 | 0.8 | 0.05 | 12.9 | 0.82 |
| t_getx | 19.8 | 7.6 | 0.38 | 6.8 | 0.34 |
| t_getx_typed | 10.5 | 7.5 | 0.71 | 6.9 | 0.62 |
| t_sety | 21.5 | 10.8 | 0.50 | 10.7 | 0.50 |
| t_dict | 32.1 | 22.8 | 0.71 | 35.5 | 1.07 |
| t_streq | 28.5 | 23.9 | 0.84 | 37.6 | 1.31 |
| t_call | 59.8 | 1.9 | 0.03 | 4.8 | 0.08 |
| t_call_global | 63.2 | 3.2 | 0.05 | 6.0 | 0.10 |
| t_vec | 11.9 | 4.4 | 0.37 | 4.5 | 0.37 |
| t_sin | 35.1 | 21.1 | 0.60 | 15.0 | 0.43 |
| t_call_host | 72.7 | 6.7 | 0.09 | 120.2 | 1.66 |
| external_call | 61.1 | 55.2 | 0.90 | 58.7 | 0.99 |

`add_acc` is `gacc = gacc + v`, one ByVal Single, and the only write. The lean loop adds the argument to that module number and does not build a frame. The first call still enters the Sub, which is what classifies it. `add_count` is the same shape on an Integer. `add_swapped` puts the argument on the left. A Sub that writes a second global still enters. On this run every JIT-on case is at or under 1.00. Interpreter `t_call_global` is 0.10.

### 18 Nov 2026, after a straight-line ByRef Sub

`run_gap.gd`, one quiet pair, `mismatches=0` both modes. GD `t_local` was 8.8 ns with the JIT on and 8.9 ns with `VG_JIT=0`. The GD column is the JIT-on run. Each ratio is from its own run. Before this change, interpreter `t_call_byref` was 2.66.

| Case | GD | VG JIT | ratio | VG `VG_JIT=0` | ratio |
|---|---|---|---|---|---|
| t_local | 8.8 | 1.9 | 0.22 | 6.0 | 0.67 |
| t_global | 8.8 | 2.2 | 0.25 | 5.5 | 0.55 |
| t_gint | 9.0 | 0.6 | 0.07 | 10.3 | 1.16 |
| t_gint_if | 15.3 | 0.8 | 0.05 | 13.5 | 0.87 |
| t_getx | 20.1 | 7.1 | 0.36 | 7.1 | 0.35 |
| t_getx_typed | 10.6 | 6.9 | 0.66 | 7.1 | 0.67 |
| t_sety | 21.5 | 11.0 | 0.51 | 10.9 | 0.51 |
| t_dict | 32.4 | 23.6 | 0.73 | 34.9 | 1.07 |
| t_streq | 28.8 | 22.4 | 0.78 | 37.1 | 1.28 |
| t_call | 61.0 | 2.1 | 0.03 | 5.1 | 0.09 |
| t_call_args | 93.1 | 6.2 | 0.07 | 152.0 | 1.64 |
| t_call_byref | 159.3 | 6.7 | 0.04 | 59.3 | 0.36 |
| t_call_global | 63.6 | 3.5 | 0.05 | 7.4 | 0.10 |
| t_call_host | 72.0 | 6.2 | 0.09 | 126.9 | 1.62 |
| t_vec | 11.9 | 4.5 | 0.38 | 4.5 | 0.37 |
| t_sin | 35.0 | 20.9 | 0.60 | 15.6 | 0.45 |
| t_branch | 74.5 | 29.2 | 0.39 | 31.0 | 0.43 |
| t_poly | 48.7 | 24.8 | 0.51 | 24.8 | 0.51 |
| external_call | 60.6 | 58.0 | 0.96 | 55.9 | 0.95 |

`polar_step` takes two ByRef Singles and one ByVal Single. Its body is straight-line float arithmetic. The lean loop runs that body without a frame and stores the ByRef results in the caller's locals. The first call still enters the Sub, which is what classifies it. `swap_pair` is two Integer ByRefs and no ByVal. `scale_one` is one ByRef Single. A body with a branch, or one that writes a module number, still enters. On this run every JIT-on case is at or under 1.00. Interpreter `t_call_byref` is 0.36.

### 18 Nov 2026, after a straight-line numeric Function

`run_gap.gd`, one quiet pair, `mismatches=0` both modes. GD `t_local` was 9.0 ns with the JIT on and 8.8 ns with `VG_JIT=0`. The GD column is the JIT-on run. Each ratio is from its own run. Before this change, interpreter `t_call_args` was 1.64.

| Case | GD | VG JIT | ratio | VG `VG_JIT=0` | ratio |
|---|---|---|---|---|---|
| t_local | 9.0 | 2.2 | 0.25 | 5.2 | 0.59 |
| t_global | 10.1 | 2.2 | 0.22 | 5.5 | 0.62 |
| t_gint | 10.0 | 0.7 | 0.07 | 10.5 | 1.22 |
| t_gint_if | 17.8 | 0.9 | 0.05 | 15.3 | 1.00 |
| t_getx | 22.5 | 7.0 | 0.31 | 7.0 | 0.35 |
| t_getx_typed | 10.6 | 7.1 | 0.67 | 7.0 | 0.67 |
| t_sety | 21.6 | 11.2 | 0.52 | 10.9 | 0.50 |
| t_dict | 32.6 | 25.4 | 0.78 | 30.7 | 0.91 |
| t_streq | 29.3 | 22.3 | 0.76 | 37.7 | 1.30 |
| t_call | 60.7 | 2.2 | 0.04 | 4.8 | 0.08 |
| t_call_args | 94.6 | 6.3 | 0.07 | 35.7 | 0.38 |
| t_call_byref | 159.9 | 7.0 | 0.04 | 59.0 | 0.37 |
| t_call_global | 63.3 | 3.2 | 0.05 | 7.6 | 0.12 |
| t_call_host | 73.7 | 7.2 | 0.10 | 149.4 | 2.05 |
| t_vec | 11.9 | 4.4 | 0.37 | 5.0 | 0.37 |
| t_sin | 34.8 | 21.2 | 0.61 | 15.6 | 0.41 |
| t_branch | 74.8 | 30.0 | 0.40 | 31.1 | 0.42 |
| t_poly | 47.4 | 26.1 | 0.55 | 25.5 | 0.50 |
| external_call | 66.5 | 61.1 | 0.92 | 55.8 | 0.94 |

`blend3` takes three ByVal Singles and returns `a + (b - a) * t`. The lean loop runs that body without a frame and leaves the Return value where the arguments were. The first call still enters the Function, which is what classifies it. `add2` is two Integer ByVals. A body with a branch, or one that writes a module number, still enters. On this run every JIT-on case is at or under 1.00. Interpreter `t_call_args` is 0.38.

### 18 Nov 2026, after Len(global) + argument without a frame

`run_gap.gd`, one quiet pair, `mismatches=0` both modes. GD `t_local` was 8.8 ns with the JIT on and 10.4 ns with `VG_JIT=0`. The GD column is the JIT-on run. Each ratio is from its own run. Before this change, interpreter `t_call_host` was 2.05.

| Case | GD | VG JIT | ratio | VG `VG_JIT=0` | ratio |
|---|---|---|---|---|---|
| t_local | 8.8 | 1.9 | 0.22 | 6.1 | 0.59 |
| t_global | 8.8 | 2.2 | 0.25 | 6.7 | 0.65 |
| t_gint | 8.6 | 0.6 | 0.07 | 12.6 | 1.23 |
| t_gint_if | 17.0 | 0.9 | 0.05 | 16.2 | 0.87 |
| t_getx | 20.7 | 7.2 | 0.35 | 8.8 | 0.32 |
| t_getx_typed | 11.2 | 8.2 | 0.73 | 8.8 | 0.67 |
| t_sety | 21.6 | 10.9 | 0.51 | 25.8 | 0.47 |
| t_dict | 32.5 | 25.4 | 0.78 | 58.4 | 1.01 |
| t_streq | 28.8 | 23.7 | 0.82 | 57.0 | 1.23 |
| t_call | 60.1 | 2.2 | 0.04 | 7.0 | 0.08 |
| t_call_args | 94.1 | 6.2 | 0.07 | 46.4 | 0.37 |
| t_call_byref | 161.5 | 6.7 | 0.04 | 75.8 | 0.37 |
| t_call_global | 63.5 | 3.2 | 0.05 | 8.7 | 0.10 |
| t_call_host | 71.2 | 6.4 | 0.09 | 37.6 | 0.42 |
| t_vec | 28.5 | 7.9 | 0.28 | 5.5 | 0.36 |
| t_sin | 54.4 | 24.4 | 0.45 | 19.8 | 0.45 |
| t_branch | 93.6 | 38.1 | 0.41 | 37.2 | 0.41 |
| t_poly | 63.1 | 31.0 | 0.49 | 30.7 | 0.44 |
| external_call | 79.1 | 72.4 | 0.92 | 70.0 | 0.97 |

`tag_len` is `Return Len(gs) + i`. The straight-line numeric Function path now accepts `Len` of a module String or Dictionary and the untyped `OP_ADD` that Len emits, so later calls leave the length-plus-argument without a frame. `add_left` puts the argument on the left. `bag_len` uses a Dictionary. A body with a branch still enters. On this run every JIT-on case is at or under 1.00. Interpreter `t_call_host` is 0.42.

### 18 Nov 2026, after Len-style compare of a String global

`run_gap.gd`, one quiet pair, `mismatches=0` both modes. GD `t_local` was 8.9 ns with the JIT on and 9.0 ns with `VG_JIT=0`. The GD column is the JIT-on run. Each ratio is from its own run. Before this change, interpreter `t_streq` was 1.23 (57.0 ns).

| Case | GD | VG JIT | ratio | VG `VG_JIT=0` | ratio |
|---|---|---|---|---|---|
| t_local | 8.9 | 1.9 | 0.22 | 5.2 | 0.58 |
| t_global | 8.8 | 1.9 | 0.22 | 6.1 | 0.69 |
| t_gint | 8.8 | 0.6 | 0.07 | 11.2 | 1.27 |
| t_gint_if | 15.9 | 0.8 | 0.05 | 14.4 | 0.90 |
| t_getx | 21.1 | 7.3 | 0.35 | 8.1 | 0.39 |
| t_getx_typed | 10.9 | 7.1 | 0.65 | 8.1 | 0.70 |
| t_sety | 22.2 | 10.9 | 0.49 | 10.9 | 0.50 |
| t_dict | 33.5 | 23.4 | 0.70 | 32.5 | 0.94 |
| t_streq | 30.0 | 23.0 | 0.77 | 31.8 | 1.02 |
| t_call | 59.8 | 2.0 | 0.03 | 5.7 | 0.09 |
| t_call_args | 95.9 | 6.2 | 0.06 | 36.7 | 0.37 |
| t_call_byref | 163.6 | 7.9 | 0.05 | 65.0 | 0.39 |
| t_call_global | 65.0 | 3.7 | 0.06 | 8.1 | 0.11 |
| t_call_host | 74.0 | 6.6 | 0.09 | 36.7 | 0.42 |
| t_vec | 12.5 | 4.6 | 0.37 | 5.3 | 0.36 |
| t_sin | 35.1 | 20.9 | 0.60 | 19.2 | 0.45 |
| t_branch | 73.9 | 31.1 | 0.42 | 37.0 | 0.41 |
| t_poly | 52.8 | 25.1 | 0.48 | 30.2 | 0.49 |
| external_call | 67.7 | 62.9 | 0.93 | 72.5 | 0.92 |

`gs = "talk"` after `OP_GET_GLOBAL` compares the module String in place, the same way `Len(global)` and a Dictionary constant-key read already do. The stack path for a local String is unchanged. On this run every JIT-on case is at or under 1.00. Interpreter `t_streq` is 1.02: under the soft bar of 1.5, absolute time 57.0 → 31.8 ns, and still a hair over the hard 1.00 goal.

### 18 Nov 2026, after Integer module arithmetic without CLng

`run_gap.gd`, one quiet pair, `mismatches=0` both modes. GD `t_local` was 9.5 ns with the JIT on and 8.8 ns with `VG_JIT=0`. The GD column is the JIT-on run. Each ratio is from its own run. Before this change, interpreter `t_gint` was 1.27.

| Case | GD | VG JIT | ratio | VG `VG_JIT=0` | ratio |
|---|---|---|---|---|---|
| t_local | 9.5 | 1.9 | 0.20 | 5.2 | 0.59 |
| t_global | 8.9 | 2.2 | 0.25 | 6.1 | 0.69 |
| t_gint | 9.8 | 0.6 | 0.07 | 6.5 | 0.70 |
| t_gint_if | 15.2 | 0.9 | 0.06 | 9.7 | 0.64 |
| t_getx | 22.4 | 8.2 | 0.37 | 7.1 | 0.35 |
| t_getx_typed | 12.2 | 8.1 | 0.67 | 7.1 | 0.67 |
| t_sety | 22.7 | 10.9 | 0.48 | 11.1 | 0.49 |
| t_dict | 32.5 | 29.0 | 0.89 | 30.8 | 0.95 |
| t_streq | 28.8 | 24.6 | 0.86 | 30.0 | 0.99 |
| t_call | 61.1 | 1.9 | 0.03 | 5.7 | 0.10 |
| t_call_args | 93.1 | 6.3 | 0.07 | 33.7 | 0.35 |
| t_call_byref | 159.9 | 7.0 | 0.04 | 60.3 | 0.36 |
| t_call_global | 63.7 | 3.2 | 0.05 | 7.0 | 0.11 |
| t_call_host | 74.2 | 7.1 | 0.10 | 29.4 | 0.40 |
| t_vec | 11.8 | 4.4 | 0.37 | 5.0 | 0.42 |
| t_sin | 34.9 | 20.9 | 0.60 | 15.5 | 0.41 |
| t_branch | 74.5 | 29.4 | 0.39 | 29.6 | 0.40 |
| t_poly | 51.3 | 24.0 | 0.47 | 25.3 | 0.51 |
| external_call | 63.5 | 56.7 | 0.89 | 56.4 | 0.99 |

A `Dim As Integer` module value now types as Integer in `infer_type`, so `gi = gi + 1` emits `ADD_I64_CONST` and skips `CLng`. The lean loop then folds `GET_GLOBAL`, the pushed constant, `ADD_I64_CONST`, and `SET_GLOBAL` of the same name into one in-place add when the frame has already snapshotted that global. `gk = gk + 2` inside an `If` is the same shape. On this run every case in `run_gap.gd` is at or under 1.00 in both modes. Interpreter `t_gint` is 0.70. Interpreter `t_streq` is 0.99.

### Status (18 Nov 2026)

Done:

- WS1, direct compiled calls: `db024904`
- Tier 2 slot typing: `3cddef24`
- WS2, lean interpreter loop: `568bf467`
- WS3, `OP_DEBUG_LINE` stripped unless a debugger is attached: `7e812044`
- Interpreter `CLng` + Integer `OP_SET_GLOBAL` fast path: `6f7a2500`
- WS4 axis ops in the VM and the compiler: `68857b12`. Tier 2 scalar replacement of Vector2/Vector3 locals is still open and was not required for the ratio.
- WS5, Tier 2 String and Dictionary globals: `c3ed88fb`. JIT ratios for `t_dict` and `t_streq` are under 1.00.
- WS6, interpreter string compare, constant dictionary key, and leaf call: `24ca8441`. Interpreter `t_streq` 1.27, `t_dict` 1.09, `t_call` 0.08. The pure-Boolean `And` jump form is not in that commit.
- WS7, external constant `Return`: `159592e7`. `external_call` is 0.97 with the JIT on and 0.89 with `VG_JIT=0`.
- `t_call_host` JIT Len: `061237d4`. JIT ratio 0.10.
- `t_call_global`: `dbe82c73`. JIT ratio 0.05. Interpreter ratio 0.10.
- `t_call_byref`: `41c15c89`. JIT ratio 0.04. Interpreter ratio 0.36.
- `t_call_args`: `3dcee439`. JIT ratio 0.07. Interpreter ratio 0.38.
- Interpreter `t_call_host`: `f34cd546`. JIT ratio 0.09. Interpreter ratio 0.42.
- Interpreter `t_streq` global compare: `b5136cd7`. JIT ratio 0.77. Interpreter ratio was 1.02; on this quiet pair it is 0.99.
- Interpreter `t_gint` typed add without CLng: this commit. JIT ratio 0.07. Interpreter ratio 0.70.

**Gap goal met.** Every case in `run_gap.gd` is at or under 1.00 with the JIT on and with `VG_JIT=0` on this quiet pair.

Tier 2 scalar replacement of Vector2/Vector3 locals is still open as an optional follow-up. Those ratios are already under 1.00 (`t_getx` 0.37, `t_getx_typed` 0.67, `t_sety` 0.48, `t_vec` 0.37).

#### Post-gap packaging (18 Nov 2026)

- Regression gate: `scripts/check_vm_gap.sh` (default `VG_GAP_MAX_RATIO=1.05` noise band; quiet-pair goal remains `1.00`). Runs JIT on and `VG_JIT=0`. `run_gap.gd` honors `VG_GAP_MAX_RATIO` and prints `over_limit=`.
- Published quiet-pair table: `BENCHMARK_PUBLISHED_RESULTS.md` § VM gap microbench, and `docs/manual/performance.md`.
- Visual demo: `samples/apps/vg_speed_race/` — side-by-side `.vg` / `.gd` particle integrate (`RaceHost.gd` + `sim_vg.vg` + `sim_gd.gd`). Headless smoke: `run_headless_race.gd`.

Next: optional Tier 2 scalar replacement, or stop. No interpreter case remains over 1.00 on this quiet pair.

Missing dictionary keys return Nothing without raising (`Err.Number` stays 0) — confirmed language contract for 5.8 (issue #26). AST/`Len`/mixed Variant arithmetic parity is restored (issue #24). Tier 2 declines `AndAlso`/`OrElse` expression joins that need a stack phi rather than emitting a wrong result (issue #25). `Option Compare Text` takes effect on the parser, the bytecode VM, and Tier 2.

The Cdecl `strlen` assert is still the pre-existing suite noise. Suite result: 1875 PASS / 0 FAIL in all three modes in the parallel run. Corpus 80/80 in all four modes. Draw dispatch `failures=0` in all three modes on the first try. Ash Meridian: `test_part1` 88/91, `test_suit_terminal_input` the same three failures, `test_departure_render` still times out at the lambda on line 19. `test_suit_panel_performance` alone: face=true 13.98 ms, face=false 6.94 ms, under the written baseline of 63.66 ms and 38.13 ms. Under `VG_FORCE_AST=1`, `test_jit_len_global.vg` fails three checks: `Len` of an Integer variant is 1, `Len` of the two-entry Dictionary is 18, and `Len` of the three-element Array is 9. The bytecode VM and the JIT report 0, 2, and 3. That `Len` difference is the AST interpreter's.

### JIT log at baseline (`VG_JIT_LOG=1`)

| Function | Result | Why |
|---|---|---|
| t_local, t_global, t_sin, t_call, empty_fn | Tier 2 compiled | — |
| t_getx, t_getx_typed | lowering failed, op 0 (`OP_CONSTANT`) | The `Vector2(3,4)` constant is not INT/FLOAT/STRING |
| t_sety | lowering failed, op 0 | same |
| t_dict | lowering failed, op 3 (`OP_GET_GLOBAL`) | The global `d` is a Dictionary |
| t_streq | lowering failed, op 3 | The global `gs` is a String |
| t_vec | not attempted | Returns a Variant (Vector2); Tier 2 only takes numeric returns |

### Bytecode at baseline (`dump_bytecode.gd`)

- Every loop: `OP_FOR_INC_LE_LOOP` jumps back to an `OP_DEBUG_LINE`, which runs on every iteration.
- t_getx: `GET_LOCAL p`, `GET_MEMBER "x"`, `ADD_LOCAL_F64_STACK`.
  `Dim p As Vector2` produces the same bytecode as the Variant version. The type declaration is not used.
- t_sety: `GET_LOCAL p`, `GET_LOCAL p`, `GET_MEMBER y`, `CONSTANT 1`, `ADD`, `SET_MEMBER y`, `SET_LOCAL p`.
  This copies the Vector2 out, edits it, and stores it back.
- t_dict: `GET_GLOBAL d`, `CONSTANT "k"`, `GET_DICT_FAST`, `ADD_LOCAL_F64_STACK`.
- t_streq: `GET_GLOBAL gs`, `CONSTANT "talk"`, `EQUAL`, `GET_GLOBAL gb`, `NOT`, `AND`, `JUMP_IF_FALSE`.
  There is no short-circuit, and `EQUAL` is the generic Variant compare.
- t_call: `CALL "empty_fn" argc 0`, `ADD_LOCAL_F64_STACK`.
- t_vec: `GET_LOCAL v`, `CONSTANT Vector2(0.5,1)` (pre-folded), `ADD`, `SET_LOCAL v`.

### perf profile at baseline (`VG_JIT=0`)

- t_call: 23% in `execute_bytecode` itself, 21% in the `inline_frame_push` lambda, 10% in `inline_frame_pop`, plus `malloc` and `CowData<Variant>::_copy_on_write`.
  Pushing and popping a frame costs more than the work in the call.
- t_streq: 43% in `execute_bytecode`, then several small lambdas: the Variant push lambda #15, the const-index read, the operator dispatch lambda #27, and `CowData<MemberNameCacheEntry>::_copy_on_write`.
- t_dict: time is spread over the stripped Godot binary (Dictionary hashing and Variant copies). No single VG symbol dominates.

## 4. Where the code is

Line numbers are approximate as of `e8f5f8f8`. Grep for the symbol; do not trust the number.

| Area | File | Anchor |
|---|---|---|
| Interpreter entry | `src/visual_gasic_instance_bytecode_vm.cpp` | `bool VisualGasicInstance::execute_bytecode` ~870 |
| Member-name cache | same | `ensure_member_cache_entry` ~2168–2215 |
| Inline call frames | same | `inline_frame_push` ~2341, `inline_frame_pop` ~2557 |
| Dispatch loop | same | `vg_dispatch_next` / computed goto ~2973–3018 |
| OP_GET_GLOBAL | same | `VG_CASE(vg_op_get_global` ~3523 |
| OP_ADD | same | `VG_CASE(vg_op_add` ~4228 |
| OP_EQUAL | same | `VG_CASE(vg_op_equal` ~5313 |
| OP_NOT / OP_AND | same | ~5577 / ~5586 |
| OP_CALL | same | `VG_CASE(vg_op_call` ~6369 |
| OP_GET_DICT_FAST | same | ~7388 |
| OP_GET_MEMBER | same | ~7893 (already has an in-place Vector2/Vector3/Color axis fast path) |
| OP_SET_MEMBER | same | ~8854 |
| OP_DEBUG_LINE | same | ~10183 |
| Opcode enum | `src/visual_gasic_bytecode.h` | add new ops before `OP_COUNT_` |
| Opcode names | `src/visual_gasic_script.cpp` | `OP_NAME_CASE` list |
| Instruction lengths | `src/visual_gasic_optimizer.cpp` | the length table used by every pass and by `VG_OPLEN_CHECK=1` |
| Debug-line strip | `src/visual_gasic_optimizer.cpp` | `pass_strip_debug_lines` ~1184, called ~1310 (release builds only) |
| Opcode selection | `src/visual_gasic_compiler.cpp` | expression codegen; coercion helpers ~958–1010; `declared_string_vars` |
| Tier-2 IR | `src/visual_gasic_jit_tier2.h` | `IRType` `{I64, F64, BOOL, VOID}` ~70, `IROp` list ~72–150 |
| Tier-2 lowering | `src/visual_gasic_jit_tier2.cpp` | `OP_CONSTANT` ~955, `OP_GET_GLOBAL` ~1092, `OP_CALL` → `RUNTIME_CALL` ~2140–2165, failure log ~3852, `VG_JIT` env ~3730 |
| Tier-2 host call | same | `host_call` ~2743, emitted at `case IROp::RUNTIME_CALL` ~3558 |
| JIT global sync | same | `jit_sync_globals` ~2664 |
| Callee type gate | same | `jit_callee_returns_non_numeric` ~179 |
| Tier-3 inliner | `src/visual_gasic_jit_tier3.cpp` | its default case bails |
| Old loop JIT | `src/visual_gasic_jit.cpp` | `VG_JIT` read in `visual_gasic_instance.cpp` ~863 |
| Fast Variant access | `src/vg_variant_fast.h` | `vtype`, `vint`, `vnum`, `vvec2`, `set_float`, `set_int`, `g_layout_ok` |
| Record helpers | `src/visual_gasic_instance.h` | `copy_if_record`, `record_member_ci`, `vb_display_string` |

### Checklist for adding an opcode

Skip any step and you get random failures.

1. Add the enum before `OP_COUNT_` in `visual_gasic_bytecode.h`.
2. Add the name to `OP_NAME_CASE` in `visual_gasic_script.cpp`.
3. Add its length to the optimizer length table. `VG_OPLEN_CHECK=1` asserts on a mismatch, so run it.
4. Add a `VG_CASE(vg_op_..., OP_...)` handler and a dispatch-table entry in the VM.
5. Tier 2: lower it, or bail explicitly. Do not let it fall into the default case without a log.
   Tier 3: same. Its default case bails.
6. Check every optimizer pass that pattern-matches neighbouring ops (peephole, fusion, jump-target remap).
   A new op inside a fused window must not be skipped by a hard-coded length.
7. The VM stack API is `vm.stack.back()`, `pop_value()`, `push_value()`, `vm.stack.pop_into()`.
   There is no `.write` on the stack.

## 5. Workstreams, in priority order

Do them in this order. Each one is a separate commit. After each, re-run `run_gap.gd` in both modes and record the new table in the commit message.

### WS1. The JIT makes `t_call` slower (151 vs 109 ns). Fix it.

Cause: Tier 2 lowers every `OP_CALL` to `IROp::RUNTIME_CALL`, which calls `host_call()` (`visual_gasic_jit_tier2.cpp` ~2743). On every call, `host_call()`:

- saves `g_jit_frame`;
- runs `jit_sync_globals(true)`, which writes every JIT global slot back into the `variables` Dictionary by String name;
- boxes the arguments into `Variant argv[8]`;
- does a linear search of a `thread_local std::vector` memo, using `strlen` on the name;
- calls `jit_invoke_user_call()`, which goes back into the interpreter or the callee's compiled code with a full frame;
- runs `jit_sync_globals(false)`, which reads every global back from the Dictionary.

That is two Dictionary walks per call, even for `empty_fn`, which touches no globals.

Fix, in steps:

1. **Direct compiled-to-compiled calls.** When a callee is a user Function in the same script, Tier 2 compiles it with a numeric return, and it has no ByRef parameters, emit a native `call` to the callee's machine code with arguments in registers.
   Resolve the callee at compile time. The `JitCallSiteMemo` already resolves user calls; reuse that resolution.
   Guard it with a code generation counter. Hot reload must invalidate it; see the Gotchas.
2. **Skip global sync when it cannot matter.** Compute, per compiled function, whether it reads or writes any module global.
   Do this transitively over callees you can see; otherwise assume yes.
   Only sync around a call when the caller holds globals in registers *and* the callee touches globals.
   For `empty_fn` the answer is no.
3. **Faster memo lookup.** Key it by call-site id, an integer assigned at lowering time, stored in an array. Drop the `strlen` and the linear scan.
4. Tier 3 (`visual_gasic_jit_tier3.cpp`) already inlines Tier-2 callees. Check why it did not inline `empty_fn` into `t_call`.
   A zero-argument function that returns a constant should inline completely. If Tier 3 is gated off by default, find out why, and say so in the commit.

Acceptance:
- `t_call` JIT ≤ 69 ns (GD).
- `external_call` is unchanged or better.
- No regressions.
- Add a test with a ByRef callee, a callee that writes a module global, and a recursive callee, all called from a hot JIT loop, checking results.
  Name it `test_proj/test_suite/test_jit_direct_call.vg`.

Risks:
- ByRef write-back (`BYREF_LOAD` after the call).
- `On Error` inside the callee.
- A callee that raises: the JIT must deopt cleanly to the interpreter.
- A callee redefined by hot reload.
- Recursion depth.

### WS2. Interpreter dispatch overhead (affects every case with `VG_JIT=0`)

Each op currently does all of this in `vg_dispatch_next`:

- an `ip >= effective_code_end` bounds check;
- a store to `last_opcode_offset`;
- a check of `error_state.has_error`;
- `op = code[vm.ip++]`, where `vm.ip` lives in a struct in memory, so it is not a register;
- a store to `current_opcode`;
- a check of `full_profile_enabled`;
- the computed goto.

Handlers end in `break`, which goes back to the loop top instead of dispatching directly.

Fix, in steps:

1. Keep `ip` in a local variable (`const uint8_t *pc`). Write it back to `vm.ip` only where something else reads it: calls, errors, yields, `Await`, coroutine save, debugger hook, and inline frame push/pop.
   This is the big win. Do it carefully: grep every `vm.ip` use inside `execute_bytecode`.
2. Replace the per-op `error_state.has_error` check and `full_profile_enabled` check with one `uint32_t slow_flags` local.
   Set it whenever an error is raised or profiling toggles; test it once per op.
   Even better: only test it after ops that can raise. Most can, so measure first.
3. Drop the `last_opcode_offset` and `current_opcode` stores. Recompute them from `pc` when an error is raised.
4. Make `VG_CASE` handlers end in `DISPATCH()` (an inline computed goto) instead of `break`, so each op has its own indirect branch. This helps branch prediction.
5. The bounds check: the compiler always ends a chunk with `OP_RETURN`/`OP_HALT`. Verify that. If it holds, the check is redundant for straight-line ops; keep it only on jumps (validate the target at jump time).

Acceptance:
- `t_local` with `VG_JIT=0` ≤ 15 ns.
- Every other interpreter case improves.
- `VG_OPLEN_CHECK=1` regression passes.
- Error line numbers in `test_proj/test_suite/*error*` tests are unchanged.

Risks:
- Coroutines and `Await` save and restore `vm.ip`. If `pc` is not written back first, a resumed coroutine jumps to the wrong place. The tests are under `test_suite/*await*`.

### WS3. `OP_DEBUG_LINE` runs on every loop iteration

The handler reads 2 bytes, checks `is_parallel_worker`, writes `debug_state.merged_line`, compares the script-path owner, and updates `current_line` and the file id.

Fix: generate a line table at compile time, the same idea as CPython's `co_lines`: a sorted array of `(bytecode_offset, line)`.

- Error reporting: map the faulting `pc` offset to a line with a binary search.
- `Debug.Print` line info, `Erl`, and `On Error` line state: map the same way.
- Debugger breakpoints and stepping: only when a debugger hook is attached, either keep emitting `OP_DEBUG_LINE`, or re-compile the chunk with them. A recompile when the debugger attaches is fine.
- Then let `pass_strip_debug_lines` (`visual_gasic_optimizer.cpp` ~1184) run in editor builds too when no debugger is attached. Today it only runs in release.

Acceptance:
- No `OP_DEBUG_LINE` in `dump_bytecode.gd` output for `t_local` when no debugger is attached.
- Every runtime-error test reports the same line as before.
- The editor debugger can still stop on a breakpoint inside a loop. Test it manually in the Godot editor and say so in the commit.

### WS4. Typed `Vector2`/`Vector3` locals should not be Variants (t_getx_typed, t_sety, t_vec)

`Dim p As Vector2` is ignored. The bytecode matches the Variant version.

Step 1, VM (helps both modes):
- Add `OP_GET_LOCAL_AXIS slot, axis`: push `locals[slot].x/y/z` as a float without copying the Vector2 to the stack.
- Add `OP_SET_LOCAL_AXIS slot, axis`: pop a float and write it into the local's Vector2 in place.
  Use `vgfast::vvec2` with a writable variant. Check `vgfast::g_layout_ok` first and fall back to the generic path when it is false.
- Emit them in the compiler when the base is a local declared `As Vector2`/`As Vector3` and the member is a constant x/y/z.
  Also emit them for Variant locals when the member is x/y/z, with a runtime type check that falls back to the generic `GET_MEMBER`/`SET_MEMBER` code.
- `p.y = p.y + 1` becomes `GET_LOCAL_AXIS p,1`, `CONSTANT 1`, `ADD`, `SET_LOCAL_AXIS p,1`. That is 4 ops instead of 7, with no Vector2 copies.
- `v = v + Vector2(c)` with a typed local: add `OP_ADD_LOCAL_VEC2_CONST slot, const_idx`, which adds in place.

Step 2, Tier 2:
- Scalar-replace typed Vector2/Vector3 locals. Each axis becomes an F64 vreg; there are no Variants in the loop.
- Load the axes on function entry, and store them back at return or before any call or deopt point.
- Lower `OP_CONSTANT` with a Vector2 constant to two `CONST_F64` values when the only use is an axis read or a Vector2 add.
  This removes the "op 0" bail for `t_getx` and `t_sety`.
- Let Tier 2 compile a function whose return type is `Vector2` (`t_vec`): box the result once at return.

Acceptance:
- `t_getx`, `t_getx_typed`, `t_sety` and `t_vec` reach JIT ratio ≤ 1.0 and interpreter ratio ≤ 1.5.
- Add `test_proj/test_suite/test_vec_axis_ops.vg`. Cover:
  - typed and Variant locals;
  - a Variant local that changes type mid-loop (Vector2, then Integer, then Vector2): the fallback must work;
  - `ByRef` Vector2 parameters;
  - Vector3 `.z`;
  - Color `.r`.

Risks:
- A Variant local can hold any type. The fast op must type-check every time.
- `With p` blocks and `p.x` inside `ByRef` calls.
- Godot's `Vector2` uses `real_t`, which is float unless built with doubles. Keep the existing cast to double.

### WS5. Tier 2 bails on any String or Dictionary global (t_dict, t_streq)

`OP_GET_GLOBAL` lowering (~1092) bails when the global is not INT, BOOL, NIL or FLOAT, so any loop that reads a String or Dictionary runs in the interpreter.

Fix: add a Variant-handle path to Tier 2 without boxing everything.

1. Add `IRType::VREF`: a pointer to a `Variant` that lives somewhere stable.
   That is either the module-global storage or a JIT-frame spill slot.
   For globals, resolve the pointer once at function entry. Re-resolve it after any call, because a callee may resize the storage.
2. Add helper-call IR ops. Each one is a plain C function, with caller-saved registers spilled like `RUNTIME_CALL`:
   - `VSTR_EQ_CONST(vref, const_idx) -> BOOL`: compare a String Variant to an interned constant. Compare lengths first, then memcmp.
     If the Variant is not a String, fall back to the generic `Variant::evaluate(OP_EQUAL)` rules.
     Note: VB6 `=` on strings is case-sensitive under `Option Compare Binary`, which is the default. Check how the VM's `OP_EQUAL` handles `Option Compare Text` and copy that behaviour exactly.
   - `VDICT_GET_F64(vref, const_key_idx) -> F64`, with a cached key hash or the pre-built `Variant` key.
     It deopts when the value is not numeric. A missing key is Nothing (not a raise); see issue #26.
3. Deopt: on any type mismatch, return a "deopt" flag. The caller resumes in the interpreter at the current bytecode offset. Tier 2 must already do this for some op; find that mechanism and reuse it.
   If there is none, bail at compile time instead of guessing. Do not write wrong results.

Acceptance:
- `t_dict` and `t_streq` compile at Tier 2, with no "lowering failed" lines in `VG_JIT_LOG=1`.
- Both reach JIT ratio ≤ 1.0.
- Add `test_proj/test_suite/test_jit_string_dict_globals.vg`. Cover:
  - a global String that changes inside the loop;
  - a Dictionary whose value changes type from Double to String mid-loop (deopt);
  - a missing key (error message and line);
  - `Option Compare Text`.

### WS6. Interpreter fast paths for strings, dictionaries and member lookup

Each of these helps the interpreter, and therefore also every function the JIT cannot compile.

1. `OP_EQUAL` with a constant String operand: the compiler emits `OP_EQ_STR_CONST const_idx`.
   The handler compares the top-of-stack String to the constant's pre-built `String` with no Variant temporaries.
   It falls back to generic `EQUAL` for non-Strings.
2. `If a And Not b Then`: VB6 `And` does not short-circuit, but when both sides are side-effect-free (variable reads, constant compares, no calls), the compiler may emit `JUMP_IF_FALSE` chains.
   The result is the same because evaluating a pure expression has no effects. Make sure `Integer And Integer` is a bitwise op in VB6. Only do this when both sides are known Boolean (comparisons, `Not` of a Boolean, Boolean variables).
3. `GET_DICT_FAST` with a constant key: pass the constant index and keep a `Variant` key already built in the chunk. That avoids building a String Variant on every iteration.
4. `ensure_member_cache_entry` (~2208) calls `cache_vec.ptrw()`. In godot-cpp that is an out-of-line `CowData::_copy_on_write` check on every member access; it showed 1.4% in the profile.
   Store the raw `MemberNameCacheEntry *` next to `member_name_cache_ptr`. Update it everywhere the pointer is repointed: inline frame push/pop and the slow resize path.
5. Inline frame push/pop (`inline_frame_push` ~2341 and `inline_frame_pop` ~2557) is 31% of `t_call` in the interpreter.
   - For a callee with no ByRef parameters, skip building `bc_byref_captures`.
   - Skip the locals-release loop for slots the compiler knows are scalar-typed.
   - Avoid the `malloc` seen in the profile: find what allocates; it is probably a `Vector` resize or a `String` build.
   - Save fewer caller fields: many are constant per chunk and can come from the chunk.

Acceptance:
- Interpreter (`VG_JIT=0`) ratios: `t_streq` ≤ 1.5, `t_dict` ≤ 1.3, `t_call` ≤ 1.0.

### WS7. External calls into VG (`external_call` 2.4x / 3.9x)

When GDScript calls `vg_node.call("empty_fn")`, VG pays script-instance lookup, argument boxing and frame setup.
Profile it with a GDScript loop in `hot_case.gd`; add a mode for that.
Look for per-call `String` builds from the `StringName` method, a per-call map lookup by String, and `Array` allocation for arguments.
Cache a `StringName` → `SubDefinition*`/compiled-chunk map on the script.

Acceptance: `external_call` ratio ≤ 1.2 in both modes.

## 6. Validation (after every workstream)

Build (about 4 minutes; the `.so` loads from `addons/visual_gasic/bin`):

```bash
scons platform=linux target=editor nostrip=1 -j8
```

The regression suite runs in three modes. Run them in parallel, but only after the build has finished:

```bash
export GODOT=/home/Commodore/Downloads/Godot_v4.7.2-stable_linux.x86_64
(VG_OPLEN_CHECK=1 scripts/run_vg_regression_loop.sh /tmp/reg_jit.log &)
(VG_OPLEN_CHECK=1 VG_JIT=0 scripts/run_vg_regression_loop.sh /tmp/reg_nojit.log &)
(VG_OPLEN_CHECK=1 VG_JIT=3 scripts/run_vg_regression_loop.sh /tmp/reg_jit3.log &)
# when all three finish:
tail -1 /tmp/reg_*.log
grep -B3 '^FAIL' /tmp/reg_jit.log | head -40
```

- Baseline is `PASS=1605` in each mode. The only allowed failure is the Cdecl `strlen` assert (pre-existing).
- New tests add to PASS. Any other FAIL is a regression; fix it before you commit.

Corpus, in 4 modes. Each must print 80/80:

```bash
for m in X=1 VG_JIT=0 VG_JIT=3 VG_FORCE_AST=1; do env $m GODOT=$GODOT bash scripts/audit_corpus.sh | tail -3; done
```

Engine draw dispatch, in 3 modes. Each must print `failures=0`:

```bash
for m in X=1 VG_JIT=0 VG_JIT=3; do env $m timeout 300 taskset -c 3 $GODOT --headless --path test_proj \
  --audio-driver Dummy --script res://../tests/test_engine_draw_dispatch.gd 2>&1 | grep failures=; done
```

Ash Meridian, the real game:

```bash
cd samples/games/ash_meridian_part1
for t in test_*.gd; do echo "== $t"; timeout 600 $GODOT --headless --path . --audio-driver Dummy --script res://$t 2>&1 | tail -3; done
```

Known baseline:
- `test_part1` passes 88/91.
- `suit_terminal` has 3 known failures under the dummy renderer.
- `test_departure_render` has 3 coverage failures on dark starfield shots, but only with a real display; this is a stale threshold.

Anything else that fails is yours.
Also run `test_suit_panel_performance.gd`. Baseline: face=true 63.66 ms, face=false 38.13 ms. It must not get slower.

Benchmark: run `run_gap.gd` in both modes. `mismatches=0` is required. Paste the table into the commit message.

## 7. Gotchas

These bit earlier sessions:

- **Hot reload.** A script can be recompiled while instances run. Any cached pointer to a chunk, compiled function, constant or member cache must be keyed by a generation counter (`_member_cache_generation` already exists) and checked before use.
- **Await and coroutines** suspend in the middle of `execute_bytecode` and resume later from saved `vm` state. Anything you hoist into locals (pc, flags, cached pointers) must be saved into `vm` before a yield and reloaded after a resume.
- **The AST fallback.** When bytecode bails, the AST interpreter re-runs the Sub from the start. Globals written before the bail are rolled back with `saved_globals`. A JIT path that writes globals directly must keep this contract, or it must never bail after its first global write.
- **ByRef.** Parameter write-back goes through `_last_byref_captures` and `OP_BYREF_LOAD`. Inline frames and JIT calls must fill it the same way.
- **`On Error Resume Next` / `On Error GoTo`.** An error inside a fast path must raise through `raise_error()` with a correct line. It must never return a default value silently.
- **Option Explicit and declared types** drive coercion (`declared_string_vars`, `typed_i64_locals`, `typed_f64_locals`). A fast path that stores into a typed local must apply the same coercion (banker's rounding for Integer/Long, VB6 display formatting for String).
- **`VG_FORCE_AST=1`** must keep working. The AST path is the reference implementation.
- **`vgfast::g_layout_ok`** is false if the Variant memory layout check fails at startup. Every raw-layout fast path must have a fallback.
- **Benchmark honesty.** Do not special-case benchmark function names or shapes. Every optimization must be general.
  Add a second case shaped differently (different variable names, a nested loop, the work inside an `If`) and show that it also speeds up.

## 8. Reporting back

When you finish or stop, update §3 of this file with a new dated table. Keep the old one. Add a short "Status" section listing:
- which workstreams are done, with their commits;
- which are partial, and what is missing;
- anything you found that looks like a correctness bug. File those separately; do not fix them inside a perf commit.
