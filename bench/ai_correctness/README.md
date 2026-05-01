# AI Correctness Benchmark

> *"Do LLMs actually write better BASIC than they write Python?"*
> This harness lets you find out.

## What this measures

For each prompt × language × model, we record:

1. **Generation success** — did the model emit *some* code? (Yes if non-empty.)
2. **Parse success** — does the emitted code parse without syntax errors?
3. **Compile success** — does the emitted code load/typecheck cleanly?
4. **Run success** *(optional, slow path)* — does the emitted code run to
   completion without throwing, and produce the expected stdout?

The headline number we publish is **first-attempt parse + compile success
rate**, because that is the metric that captures "AI auditor pain": every
program that fails to parse is a program a human has to debug before they can
even *read* what the AI tried to do.

## Languages compared

| Language | Parse check | Compile/typecheck | Run |
|---|---|---|---|
| VisualGasic | Godot headless `load()` | same | optional |
| GDScript | Godot headless `--check-only` | same | optional |
| Python | `ast.parse` | `py_compile` | optional |
| TypeScript | `tsc --noEmit` | same | optional |

All four are checked **identically** for fairness: same prompt phrasing
(adapted only for language name), same model, same temperature, same retry
policy.

## Quick start

```bash
# 0. One-time setup — install local TypeScript checker (~5 MB)
cd bench/ai_correctness/checkers && npm install typescript && cd -

# 1. Pick a model (env vars). Set whichever you have credentials for:
export OPENAI_API_KEY=sk-...
export ANTHROPIC_API_KEY=sk-ant-...
export GEMINI_API_KEY=...
# or for local models:
export OLLAMA_URL=http://localhost:11434

# 2. Run a small smoke test — 3 prompts × 4 langs × 1 model
python scripts/run_bench.py --model gpt-4o --prompts 3 --langs all

# 3. Run the full benchmark
python scripts/run_bench.py --model gpt-4o --prompts all --langs all

# 4. Aggregate results into a Markdown table
python scripts/aggregate.py results/ > REPORT.md
```

## Files

- `prompts/prompts.json` — task specifications, language-agnostic
- `scripts/run_bench.py` — generate + check, writes per-attempt JSON to `results/`
- `scripts/aggregate.py` — collapse per-attempt files into a summary table
- `checkers/check_*.sh` — per-language syntax/compile checkers (return exit 0 = OK)
- `results/` — gitignored output directory

## Methodology notes

- **Single-attempt only.** No retries, no error feedback to the model. The
  question is "how good is the *first* draft?"
- **Temperature 0.2.** Low but nonzero — we want the model's most confident
  answer, not maximum determinism.
- **Same prompt scaffold across languages.** Only the literal language name
  and any language-specific note (e.g. file extension) varies.
- **N=25 prompts in v0.1**, expanding to 100. The prompts are deliberately
  spread across the same ten categories as the [VG corpus](../../corpus/),
  so the comparison is apples-to-apples.

## Reporting

When you publish results, **also publish the raw per-attempt JSON files**.
That lets readers verify the comparison was fair (same prompts, same
temperature, no language-specific re-prompting).

## Caveats

- Parse-success is a *floor*, not a ceiling. A program can parse and still
  be wrong. The level-2 "run + check stdout" mode catches more, but requires
  expected-output specs we have not yet authored for every prompt.
- Comparing across model versions: pin the model string (e.g. `gpt-4o-2024-08-06`,
  not `gpt-4o`) and record it in the result file.
- Costs add up. 100 prompts × 4 langs × 4 models × ~500 tokens each is
  ~800K tokens. Budget accordingly or run on local Ollama.

## License

CC0-1.0, same as the corpus. Reproduce, redistribute, fork freely.
