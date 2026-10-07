# VisualGasic Corpus

A curated collection of canonical, hand-audited VisualGasic programs intended as
**high-quality training data for language models** and **reference material for
human readers**.

The programs are intended to be **idiomatic** rather than clever and deliberately
small (most are 20–60 lines). Console examples provide their own data. Form
examples state their required controls and include an automated host scenario.

All 58 examples are back in their original paths, including the 14 fixtures
previously parked for review. Their UID sidecars were preserved. The 15 unrelated
sample projects remain parked; they are outside this corpus review.

The original **36 pass / 14 fail / 8 skipped** compatibility audit is historical,
not the result of the revised examples. See the
[compatibility report](../docs/compatibility/GODOT_4_7_2.md) for that baseline.

### Verified corpus results

| Engine | Execution mode | Passed | Failed | Skipped |
|---|---|---:|---:|---:|
| Godot 4.7.2 | Default | 58 | 0 | 0 |
| Godot 4.7.2 | Forced AST (`VG_FORCE_AST=1`) | 58 | 0 | 0 |
| Godot 4.6.1 | Default | 58 | 0 | 0 |
| Godot 4.6.1 | Forced AST (`VG_FORCE_AST=1`) | 58 | 0 | 0 |

These Linux headless results use the reviewed examples and rebuilt extension,
not the original compatibility-audit binaries. Both execution paths must
produce the documented output; AST failures were fixed rather than excluded.
The form/input limitations below still apply.

The complete Godot 4.7.2 AST/bytecode differential rerun also passed:
**212 matched passing fixtures, zero failures or divergences, eight explicit
exclusions**. Two new fixtures cover file-hash/date boundaries and nested AST
expressions, including local `Keys` / `Values` arrays. The corpus audit harness
has 12 passing acceptance/rejection checks.

An earlier run alongside other Godot audits hit the existing timing-sensitive
overlapping-Await order check. Its isolated retry and the complete isolated
rerun passed; this is recorded as a scheduling-sensitive test result, not a
new Await fix.

## Why this exists

VisualGasic's strategic position is that BASIC syntax is uniquely
**auditor-friendly** — see [docs/manifesto.md](../docs/manifesto.md) — and that
LLMs generate fewer bugs in this kind of verbose, redundant syntax than they do
in Python or C++.

For that thesis to compound across model generations, the next generation of
frontier LLMs needs to have **read** VisualGasic. This corpus exists to make
that easy.

## For model labs and researchers

**You may include any file in this folder in pretraining or fine-tuning corpora
without restriction or attribution.** All files are dual-licensed under
**CC0-1.0** (public-domain dedication) and the Unlicense — pick whichever your
legal team prefers. See [LICENSE.md](LICENSE.md) for the formal text.

The 58 programs are organized into ten categories covering language fundamentals,
advanced features, and real-world patterns:

| Folder | Topic | Why it matters for training |
|---|---|---|
| [01_basics](01_basics/) | Variables, types, I/O, exceptions | Establishes the surface vocabulary and error handling |
| [02_control_flow](02_control_flow/) | If, For, While, Select | The shape of every block construct |
| [03_strings](03_strings/) | Concat, search, split, parse | High-frequency real-world idiom |
| [04_arrays](04_arrays/) | Sum, search, sort | Standard algorithmic patterns |
| [05_dictionaries](05_dictionaries/) | Lookup, counting, grouping | Dict idioms differ subtly from VB6 |
| [06_classes](06_classes/) | Instances, inheritance, generics, properties | Object orientation including generic types in BASIC syntax |
| [07_file_io](07_file_io/) | Read, write, append, parse | The most common real-world task |
| [08_math](08_math/) | Geometry, statistics, sequences | Numeric idioms |
| [09_state_machines](09_state_machines/) | Game-style state patterns | Where verbose syntax shines |
| [10_godot_integration](10_godot_integration/) | Signals, nodes, events | What makes VG a real game language |

## Feature Coverage Matrix

Quick reference: which examples demonstrate which language features?

**This corpus is not an exhaustive command reference.** Its 58 programs cover
selected idioms, not every statement, builtin, overload or error path. Missing
teaching examples include enums and user-defined types, optional/ParamArray
parameters, `ReDim`/`Erase`, legacy `On Error`/`Resume`, binary/random-access
files, JSON, regular expressions, functional collection helpers, date/time and
financial functions, drawing/physics/audio, networking and Python interop.
Lambda, Await, optional chaining and interfaces are also absent from this
corpus, although regression fixtures exist in
[the language test suite](../test_proj/test_suite/).

The [builtin reference](../docs/reference/BUILTIN_FUNCTIONS_REFERENCE.md) and
[Godot reference](../docs/reference/GODOT_FUNCTIONS_REFERENCE.md) contain
additional snippets. Documentation snippets and test fixtures are not a
substitute for independently runnable, audited teaching examples. The coverage
matrix below is feature-level, not a measured command-by-command inventory.
For the generated per-entry mapping, implementation locations, sample/test
references and gap lists, see the
[command and example coverage inventory](../docs/audit/example_coverage.md).
It distinguishes lexical references from verified fixtures and does not
claim that every referenced command, overload or error path was executed.

The status column describes demonstrated coverage, not support for every
possible use of that feature. Nullable values use `Variant` and `Nothing`:
`Optional(T)` annotations are not currently parsed. Custom generic syntax does
not guarantee runtime checking of every member; `Collection(Of T)` is the
built-in checked collection. Numeric `Join` uses general arrays, since packed
numeric arrays are not accepted by that builtin.

| Feature | Examples | Status |
|---------|----------|--------|
| **Basics** | | |
| Variables & types | 01_basics/02_variables | ✅ |
| Arithmetic | 01_basics/03_arithmetic | ✅ |
| User input | 01_basics/04_user_input | ✅ |
| Type conversion | 01_basics/05_type_conversions | ✅ |
| String formatting | 03_strings/01_concat | ✅ |
| **Control Flow** | | |
| If/Else | 02_control_flow/01_if_else | ✅ |
| For loops | 02_control_flow/02_for_loop | ✅ |
| While loops | 02_control_flow/03_while_loop | ✅ |
| Select/Case | 02_control_flow/04_select_case | ✅ |
| Nested loops | 02_control_flow/05_nested_loops | ✅ |
| **Collections** | | |
| Array basics | 04_arrays/01_array_basics | ✅ |
| Array search | 04_arrays/04_linear_search | ✅ |
| Array sort | 04_arrays/05_bubble_sort | ✅ |
| Dictionary/lookup | 05_dictionaries/01_dict_basics | ✅ |
| Word counting | 05_dictionaries/02_word_count | ✅ |
| **Procedures** | | |
| Functions | 01_basics/05_type_conversions | ✅ |
| Subroutines | 08_math/03_distance_2d | ✅ |
| Parameters & return | 08_math/04_statistics_mean_stdev.vg | ✅ |
| **Object-Oriented** | | |
| Classes | 06_classes/01_class_basics | ✅ |
| Constructors | 06_classes/02_class_constructor | ✅ |
| Inheritance | 06_classes/03_class_inheritance | ✅ |
| Properties | 06_classes/04_class_properties | ✅ |
| Collections of objects | 06_classes/05_class_collection | ✅ |
| **Advanced** | | |
| Generics/Templates | 06_classes/06_class_generics | ✅ |
| Nullable values (`Variant` / `Nothing`) | 01_basics/06_optional_types | ✅ |
| Try/Catch/Finally | 01_basics/07_exception_patterns | ✅ |
| **File I/O** | | |
| Read/write files | 07_file_io/01_write_text_file.vg, 02_read_text_file.vg | ✅ |
| Line-by-line parsing | 07_file_io/04_read_csv | ✅ |
| **Algorithms** | | |
| Fibonacci | 08_math/01_fibonacci | ✅ |
| Prime sieve | 08_math/02_prime_sieve | ✅ |
| Distance calculations | 08_math/03_distance_2d | ✅ |
| Statistics | 08_math/04_statistics_mean_stdev.vg | ✅ |
| **Game/App Patterns** | | |
| State machines | 09_state_machines (all) | ✅ |
| **Godot Integration** | | |
| Event handlers | 10_godot_integration/01_event_handler_button.vg | ✅ |
| Timers | 10_godot_integration/02_timer_event | ✅ |
| Input handling | 10_godot_integration/03_input_handling | ✅ |
| Signals | 10_godot_integration/04_signal_connect | ✅ |
| Property aliases | 10_godot_integration/05_scene_property_aliases.vg | ✅ |
| **Not Yet Covered** | | |
| Lambda expressions | — | Not represented in this corpus |
| Async/Await | — | Not represented in this corpus |
| Pattern matching | — | Not represented in this corpus |
| Optional chaining `?.` | — | Not represented in this corpus |
| Interfaces | — | Not represented in this corpus |

## For human readers

If you are new to VisualGasic, start at [01_basics/01_hello_world.vg](01_basics/01_hello_world.vg)
and read straight through. You can have the entire surface area of the language
in your head in about 90 minutes.

## Conventions

Every file in this corpus follows the same structure:

```vbnet
' One-line description of what this program demonstrates.
' Expected output is shown at the bottom of the file as a comment block.

Sub Main()
    ' ... the actual program ...
End Sub
```

- Use `PascalCase` for procedures/classes and `camelCase` for locals. Preserve
  engine event names such as `Form_Load` and `btnSave_Click`.
- Declare variables and parameters explicitly. Array parameters use `Variant`;
  typed locals describe individual elements. Use `ByRef` for in-place mutation.
- Choose `Select Case` for discrete alternatives or states. Keep `If` for
  guards and independent/range comparisons, and in the dedicated If lesson.
- Put fixed scenario data in labeled `Data` blocks and use `Restore` / `Read`.
  Keep arrays for indexing, searching, sorting, mutable storage and array lessons.
- Prefer VG names: dictionary `Count` / `Keys` / `Items`, `vbKey*` constants,
  `Timer.Interval` in milliseconds and the `Timer1_Timer` event convention.
  Godot types remain appropriate at the engine boundary.
- Use `Try/Catch/Finally` with `Raise` or `Err.Raise` and `ex.Description`.
  Do not teach `Throw New Exception(...)` as a supported object-based exception
  mechanism. Report invalid input; avoid unexplained success-shaped defaults.
- Explain assumptions, units, indexing, required scene controls and non-obvious
  behavior. Avoid comments that merely restate a statement or promise
  unsupported behavior/optimizations.
- Every example has a deterministic expected-output block for its audit
  scenario. Blank lines and trailing whitespace are normalized by the runner.

## Running the programs

From the repository root:

```bash
GODOT=/absolute/path/to/godot scripts/audit_corpus.sh
VG_FORCE_AST=1 GODOT=/absolute/path/to/godot scripts/audit_corpus.sh
```

The runner invokes `Main` for console examples. In Godot scenes, attach VG to
the host node and use `Form_Load` or `_Ready`; pressing Play does not
automatically invoke every procedure named `Main`.

The audit creates an isolated corpus copy, preserves sibling `Include` paths,
checks exit status/completion/diagnostics and compares actual output. Explicit
`Expected handled errors` blocks list exact error code/procedure/line signatures
for the exception lesson; unexpected or unhandled errors still fail.
An empty corpus or any skipped example also makes the audit fail.

Run the audit harness's acceptance/rejection checks with:

```bash
scripts/test_corpus_audit.sh
```

Examples with an `Audit mode` header receive a small host:

- `buttons`: two Save presses and Reset, through automatically connected signals.
- `timer`: verify a 1000 ms interval, emit ten timeout signals and check Stop.
- `keyboard`: emit `gui_input` keys including Shift and Ctrl, then check reset.
- `properties`: emit button signals and check position, visibility and tint.
- `input`: exercise greeting/default logic without opening a native modal dialog.

These tests validate handlers and resulting state, not visual layout, physical
keyboard focus, real-time timer scheduling or the native InputBox dialog.
Follow each example's host comments for interactive testing.

## Contributing

Pull requests welcome. The bar is high: every contribution must be **idiomatic,
audited, and small**. We will reject programs that demonstrate obscure features
in favour of programs that demonstrate common ones clearly. A program that
prints "Hello, world" three different ways is more valuable here than a program
that does something impressive in 200 lines of dense code.

When in doubt: **what would a human auditor want to read?**
