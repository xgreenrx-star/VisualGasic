# DeepSeek Implementation Brief: Fix Integer/Float Loss in the Python Bridge

Use this as the exact implementation brief. Paste this whole file to DeepSeek.

## Bug Report (from user testing)

> Integer type issue: VG Array stores all numbers as floats, breaking
> `numpy.zeros(5)`, `rand(5,5)`, etc.

Reproduced with `demos/Utilities/PythonBridge/demo_python_game_dev.vg` and
`demos/Utilities/PythonBridge/demo_python_bridge.vg` — any Python integer
(numpy int arrays, `range()`, `random.randint`, plain dict counts) comes back
into VG as a Godot `float`, not an `int`.

## Confirmed Root Cause

`PyBridgeFacade::send_request()` in
[src/python_bridge/visual_gasic_py_facade.cpp](../src/python_bridge/visual_gasic_py_facade.cpp)
(~line 409) decodes the Python worker's JSON response with Godot's built-in
parser:

```cpp
Variant parsed = JSON::parse_string(response);
```

Godot's core JSON tokenizer (`core/io/json.cpp`, `JSON::_get_token`) parses
**every** numeric literal — `5`, `5.0`, `-3`, `1e10` — the same way:

```cpp
double number = String::to_float(&p_str[index], &rptr);
...
r_token.type = TK_NUMBER;
r_token.value = number;   // always becomes Variant::FLOAT
```

There is no branch that checks whether the literal contains `.`/`e`/`E`
before deciding int vs. float. **`JSON::parse_string()` cannot produce
`Variant::INT` — ever.** This is a real, long-standing Godot engine
limitation (JSON has no native int/float distinction; Godot's generic parser
always resolves to float), not something specific to VG's array system.

This means:
- `addons/visual_gasic/python_worker.py` correctly serializes Python ints as
  bare JSON integers (`json.dumps(5)` → `"5"`, no decimal point) — the
  int-ness **is present on the wire**.
- The C++ side throws that information away the moment it calls
  `JSON::parse_string()`, turning every number into a Godot float before it
  ever reaches VG script code.
- Every `PyImport`/`PyCall`/`PyCallAsync`/`PyCallMany` result that contains a
  Python `int` (scalars, list/tuple elements, dict values, nested
  numpy-array-via-`.tolist()` data) is silently corrupted to float.
- This is exactly why `numpy.zeros(5, dtype=int)`, `numpy.arange(5)`,
  `random.randint(...)`, JSON config integer fields, etc. all come back as
  floats in VG — regardless of what dtype/type Python actually returned.

## Why This Matters for VG Specifically

VG's array VM has real typed storage (`PackedInt64Array` vs
`PackedFloat64Array` — see engineering notes on packed arrays) and
`TypeName()`/`VarType()` are meant to reflect real types. A Python bridge
that silently rewrites every int to a float breaks:
- Assigning bridge results into `Dim arr() As Integer` / `Dim arr() As Long`
- Any `If VarType(x) = ...` / `TypeName(x) = "Integer"` check on bridge data
- Downstream code that uses returned ints as loop bounds, array indices, or
  dictionary keys where float vs int matters
- Round-tripping data through `PyCall` and back (e.g. incrementing a Python
  counter) — the value silently becomes float after one hop

## Required Fix

Do **not** try to patch Godot's engine-level `JSON` class (out of scope,
upstream engine code). Instead, stop using it for this one decode path and
replace it with a small purpose-built decoder that preserves Python/JSON int
vs. float semantics, matching what `json.loads()` in Python actually does:
an integer literal (no `.`, no `e`/`E`) becomes an integer; anything else
with a decimal point or exponent becomes a float.

### A. New minimal JSON decoder for bridge responses

Add a new pair of files:
- `src/python_bridge/vg_json_typed.h`
- `src/python_bridge/vg_json_typed.cpp`

Implement a small recursive-descent parser:

```cpp
namespace godot {
// Parses JSON text preserving int vs float distinction (unlike Godot's
// built-in JSON class, which always returns float for numbers).
// Returns true on success; on failure, r_err_str is set and r_out is Variant().
bool vg_json_parse_typed(const String &p_json, Variant &r_out, String &r_err_str);
}
```

Behavior requirements (mirror Python's `json` module + RFC 8259):
1. Object → `Dictionary` (string keys).
2. Array → `Array`.
3. String → `String` (handle the standard JSON escapes: `\"`, `\\`, `\/`,
   `\b`, `\f`, `\n`, `\r`, `\t`, `\uXXXX` including surrogate pairs — Godot's
   own `JSON::_get_token` string-scanning code can be used as a reference
   for correctness, do not need to copy it verbatim).
4. `true` / `false` → `bool`.
5. `null` → empty `Variant()`.
6. Number:
   - Scan the full numeric token (optional `-`, digits, optional `.digits`,
     optional `[eE][+-]digits`) same as standard JSON grammar.
   - If the token contains **no** `.` and **no** `e`/`E` → parse with
     `token.to_int()` (int64) → `Variant::INT`.
   - Otherwise → parse with `token.to_float()` (double) → `Variant::FLOAT`.
   - If an integer literal overflows int64, fall back to float rather than
     crashing (log a warning, don't hard-fail the whole payload).
7. Malformed JSON → return `false` with a descriptive `r_err_str` (mirror the
   existing error message style already used elsewhere in the bridge, e.g.
   `"Invalid JSON response from worker"`).
8. Recursion depth guard (reject/­bail past ~64 levels deep) to avoid stack
   overflow from malicious/corrupt payloads — match the spirit of Godot's
   own `Variant::MAX_RECURSION_DEPTH` guard in `core/io/json.cpp`.

Keep this file self-contained — it only depends on godot-cpp's `String`,
`Array`, `Dictionary`, `Variant`. No new third-party dependency, no vendoring
a JSON library.

### B. Wire it into the bridge facade

In `src/python_bridge/visual_gasic_py_facade.cpp`, replace the one call site
in `send_request()` (~line 409):

```cpp
// BEFORE
Variant parsed = JSON::parse_string(response);
if (parsed.get_type() != Variant::DICTIONARY) {
    Dictionary err_resp;
    err_resp["status"] = "error";
    err_resp["message"] = "Invalid JSON response from worker";
    return err_resp;
}
```

```cpp
// AFTER
Variant parsed;
String parse_err;
if (!vg_json_parse_typed(response, parsed, parse_err) ||
    parsed.get_type() != Variant::DICTIONARY) {
    Dictionary err_resp;
    err_resp["status"] = "error";
    err_resp["message"] = parse_err.is_empty()
        ? "Invalid JSON response from worker"
        : ("Invalid JSON response from worker: " + parse_err);
    return err_resp;
}
```

Add `#include "vg_json_typed.h"` at the top of `visual_gasic_py_facade.cpp`.

**Do not** touch `JSON::stringify()` usage in `send_request()` (building the
*outgoing* request) — Godot's stringify already correctly serializes
`Variant::INT` as a bare integer literal (confirmed in `JSON::_stringify`,
`case Variant::INT: r_result += itos(p_var);`). The bug is only on the
*parse* side, in one direction (worker → VG).

### C. Build wiring

- Add `src/python_bridge/vg_json_typed.cpp` to whatever glob/source list
  picks up `src/python_bridge/*.cpp` in `SConstruct` (it already globs this
  directory for the existing facade file — verify the new file is picked up
  by the same pattern; no changes needed if it's a wildcard glob, only add
  an explicit source line if the build system lists files individually).
- No new `register_types.cpp` registration needed — `vg_json_typed.h/.cpp`
  is a plain internal utility, not a new Godot-exposed class.

### D. Python worker — no changes required

`addons/visual_gasic/python_worker.py`'s `_make_json_safe()` already emits
correct JSON (ints stay ints, floats stay floats, numpy scalars/arrays are
unwrapped via `.tolist()`/`.item()` which preserve Python's own int/float
distinction). Confirm this remains true — do not "fix" the Python side; the
bug is 100% on the C++ decode side. If you find a spot in
`_make_json_safe()` that coerces an int-like numpy value to float
unnecessarily, flag it separately but it is not expected to need a change.

## Test Plan

Add a new test file `test_proj/test_python_bridge_int_types.vg` (or extend
an existing bridge test) covering:

1. **Scalar int round-trip**: `bridge.PyCall(mathMod, "floor", Array(5.0))`
   in Python returns an `int` (math.floor returns int in Python 3) — assert
   `VarType(result) = <integer VarType constant>` / `TypeName(result) =
   "Integer"` (or `"Long"`/whatever VG's int type name is for a Python int
   this size), not `"Single"`/`"Double"`.
2. **List of ints**: call a Python helper (add one to `python_worker.py`'s
   test fixtures if needed, or use `list(range(5))` via a small inline
   helper module) and assert every element's `VarType`/`TypeName` is
   integer, and `arr(i) = i` holds exactly (no `4.0 = 4` fuzzy-equality
   masking a real type bug).
3. **numpy int array**: `npMod.arange(5)` (or `.tolist()` result) — assert
   elements are ints. Guard this test with the existing
   `If IsEmpty(npMod) Then ... SKIP` pattern already used in
   `demo_python_game_dev.vg` so CI without numpy installed doesn't fail.
4. **Mixed dict**: a Python dict response with both int and float values
   (e.g. `{"count": 3, "ratio": 0.5}`) — assert `count` is integer-typed and
   `ratio` is float-typed after the round trip.
5. **Float still works**: `bridge.PyCall(mathMod, "sqrt", Array(2.0))` still
   returns a float — regression guard that the fix didn't overcorrect and
   turn everything into an int.
6. **Existing demos still pass**: re-run
   `demos/Utilities/PythonBridge/demo_python_bridge.vg` and
   `demos/Utilities/PythonBridge/demo_python_game_dev.vg` end-to-end and
   confirm output unchanged except now-correct int formatting (some
   `CStr(CInt(x))` calls in those demos exist specifically to paper over
   this bug via truncation — after the fix `CInt()` becomes unnecessary
   there, but leave the demo files as-is unless asked to clean them up
   separately).
7. **Malformed JSON safety**: feed a deliberately corrupted response through
   `vg_json_parse_typed` directly (unit-level C++ test if the project has a
   C++ test harness, otherwise a scripted fault-injection at the worker
   level) and confirm it returns a structured error instead of crashing.
8. **Large-number edge case**: an integer literal larger than int64 range
   (e.g. a Python arbitrary-precision int) must fall back to float, not
   crash or truncate silently in a way that corrupts unrelated fields.

## Acceptance Criteria

All must pass:
1. `vg_json_parse_typed` round-trips ints as `Variant::INT` and floats as
   `Variant::FLOAT` for scalars, arrays, and nested dict/array structures.
2. `send_request()` uses the new decoder; `JSON::parse_string()` is no
   longer called anywhere in the int/float-sensitive response path.
3. All existing Python bridge tests/demos still pass with unchanged
   (or now-more-correct) output.
4. New test(s) from the Test Plan above pass.
5. No change to the outgoing request encoding (`JSON::stringify()` path) —
   confirm requests are byte-identical before/after for the same input.
6. No performance regression > 10% on a bridge round-trip micro-benchmark
   for typical small payloads (a few hundred bytes) — this is a small
   hand-written parser doing one pass over the string, should be at least
   as fast as Godot's own JSON parser for this use case.
7. Malformed/corrupt JSON responses produce a structured error Dictionary
   (`status: "error"`), never a crash or hang.

## Known Follow-up (v6.1+, out of scope for this fix)

For **large** numpy arrays/matrices, JSON (even with this int/float fix) is
still a slow, memory-hungry transport — every element becomes a boxed
`Variant` plus a text round-trip. `PyBridgeFacade::py_process_buffer()`
already has a binary-framed lane stubbed in for exactly this case. A future
pass should:
- Extend `py_process_buffer` (or add a sibling call) so numpy arrays can be
  sent/received as raw bytes + a small dtype/shape header (e.g.
  `{"dtype":"int64","shape":[5,5]}` + a `PackedByteArray`), decoded directly
  into `PackedInt64Array`/`PackedFloat64Array` without ever going through
  JSON for the bulk data.
- This is a performance optimization on top of a now-correct baseline —
  do not block this correctness fix on it.

## Output Format Expected From DeepSeek

1. File-by-file patch summary (new files + the one-line-site change in
   `visual_gasic_py_facade.cpp`).
2. Confirmation that `JSON::stringify()` (outgoing) was left untouched.
3. Acceptance criteria checklist with pass/fail per item above.
4. Any known limitations deferred to v6.1+ (e.g. the binary-lane numpy
   follow-up above).
