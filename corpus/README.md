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
