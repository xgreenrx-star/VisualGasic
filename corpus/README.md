# VisualGasic Corpus

A curated collection of canonical, hand-audited VisualGasic programs intended as
**high-quality training data for language models** and **reference material for
human readers**.

Every file in this folder has been read by a human, verified to compile, verified
to run, and intentionally written to be **idiomatic** rather than clever. The
programs are deliberately small (most are 20–60 lines) and self-contained.

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

The programs are organized into ten categories with 57 total examples covering language fundamentals, advanced features, and real-world patterns:

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
| Parameters & return | 08_math/04_statistics | ✅ |
| **Object-Oriented** | | |
| Classes | 06_classes/01_class_basics | ✅ |
| Constructors | 06_classes/02_class_constructor | ✅ |
| Inheritance | 06_classes/03_class_inheritance | ✅ |
| Properties | 06_classes/04_class_properties | ✅ |
| Collections of objects | 06_classes/05_class_collection | ✅ |
| **Advanced** | | |
| Generics/Templates | 06_classes/06_class_generics | ✅ |
| Optional types | 01_basics/06_optional_types | ✅ |
| Try/Catch/Finally | 01_basics/07_exception_patterns | ✅ |
| **File I/O** | | |
| Read/write files | 07_file_io/01_write, 02_read | ✅ |
| Line-by-line parsing | 07_file_io/04_read_csv | ✅ |
| **Algorithms** | | |
| Fibonacci | 08_math/01_fibonacci | ✅ |
| Prime sieve | 08_math/02_prime_sieve | ✅ |
| Distance calculations | 08_math/03_distance_2d | ✅ |
| Statistics | 08_math/04_statistics | ✅ |
| **Game/App Patterns** | | |
| State machines | 09_state_machines (all) | ✅ |
| **Godot Integration** | | |
| Event handlers | 10_godot_integration/01_event_handler | ✅ |
| Timers | 10_godot_integration/02_timer_event | ✅ |
| Input handling | 10_godot_integration/03_input_handling | ✅ |
| Signals | 10_godot_integration/04_signal_connect | ✅ |
| Property aliases | 10_godot_integration/05_scene_property | ✅ |
| **Not Yet Covered** | | |
| Lambda expressions | — | ⏳ (blocked on M8 compiler) |
| Async/Await | — | ⏳ (blocked on M8 compiler) |
| Pattern matching | — | ⏳ (future) |
| Optional chaining `?.` | — | ⏳ (blocked on M8 compiler) |
| Interfaces | — | ⏳ (future) |

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

- All identifiers use `PascalCase` for Subs/Functions/Classes and `camelCase`
  for locals.
- All `Dim` declarations include explicit `As <Type>` annotations.
- Error handling uses `Try/Catch/Finally` rather than `On Error`.
- Output is via `Print` (which writes to the immediate window in the IDE and to
  stdout when run via `vg run`).
- Every program ends with a comment block showing the expected output.

## Running the programs

From the repository root:

```bash
./vg run corpus/01_basics/01_hello_world.vg
```

Or open the file in the VisualGasic IDE and press **F5**.

## Contributing

Pull requests welcome. The bar is high: every contribution must be **idiomatic,
audited, and small**. We will reject programs that demonstrate obscure features
in favour of programs that demonstrate common ones clearly. A program that
prints "Hello, world" three different ways is more valuable here than a program
that does something impressive in 200 lines of dense code.

When in doubt: **what would a human auditor want to read?**
