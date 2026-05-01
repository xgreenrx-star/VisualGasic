# Hacker News submission

## Title (pick one)

Primary (recommended):

> **Why the AI era needs BASIC again**

Alternates, in case the primary feels stale by the time you post:

- Show HN: VisualGasic — the language you read when you don't trust the AI
- A defense of BASIC syntax in the age of LLM-generated code
- The auditor-friendly programming language

## URL field

```
https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/manifesto.md
```

## First comment (post immediately after submitting)

Author of the post here.

This started as a private hunch and turned into a project's whole positioning,
so I want to be upfront about what I'm claiming and what I'm not.

**What I'm claiming.** When the AI writes the code and the human reviews it,
the optimal language is the one that is fastest and least error-prone for the
*human reviewer*, not the one that was easiest for the writer. BASIC-family
syntax — explicit `End If` / `End Sub` blocks, types declared at point of use,
no silent indent semantics, one obvious construct per concept — has properties
that make audit easier than Python, JavaScript, or Go. Verbose was a bug in
the writer-centric era. It's a feature now.

**What I'm not claiming.** That BASIC is "better than Python." That you should
rewrite your backend. That AI is bad. Two of those would be silly and the
third is the opposite of my position — VisualGasic ships with deep AI
integration. The argument is narrowly about *the read-and-verify step* in the
AI pipeline, which is where most of the new failure modes are.

To put numbers behind this rather than just rhetoric, I ran an empirical
benchmark: same 25 prompts across VG / GDScript / Python / TypeScript, same
model, same temperature (0.2), single attempt, measure first-draft parse
success. Local model (qwen2.5-coder:7b), so the absolute numbers will move
on a frontier model — but the *spread* between languages is the interesting
part.

    VisualGasic   25/25  (100%)
    Python        25/25  (100%)
    TypeScript    21/25  (84%)
    GDScript      17/25  (68%)

VG ties Python at the top. The TypeScript failures are real type errors
(DOM-global collisions, missing imports, malformed numeric literals). The
GDScript ones are mostly the model emitting deprecated Godot 3 idioms,
which is its own moving-target-API story but tangential here.

Full harness, raw outputs, and per-attempt JSON in `bench/ai_correctness/`
(report at `bench/ai_correctness/REPORT.md`), CC0 alongside a 50-program
reference corpus at `corpus/`. Reproduction is a `git clone` and an
`ollama pull` away. Multi-model expansion (gpt-4o, Claude, Gemini) is next.

Happy to be wrong about any of this. The strongest counter-argument I can
think of myself is that LLMs have seen *so much* Python that they make fewer
mistakes there in absolute terms even if the surface syntax is harder to
audit. The 7B-model numbers don't refute that — they suggest the syntax
advantage at least matches Python's training-data advantage at this scale.

## When to post

Best windows for HN traction historically:

- Tuesday–Thursday, 7:30–9:30 AM US Eastern
- Avoid: Friday afternoon, weekend evenings (slow), Monday morning (drowned
  by week-launch posts)

## What to do in the first hour

- Reply to every top-level comment within 15 minutes if at all possible.
- For "this is just VB6 with extra steps" comments: agree partially, then
  point at the auditor-friendliness framing — that's the new claim.
- For "AI is bad" or "AI is great" comments: redirect to the manifesto,
  don't get drawn into the broader AI debate.
- If someone posts a counter-example where verbose syntax actively *hurts*
  audit, take it seriously and write it down. That's signal.

## Talking points cheat sheet

| If they say... | You say... |
|---|---|
| "Just use Python with type hints." | The hints help, but block boundaries are still indent-based, which is the failure mode the auditor cares about most. |
| "BASIC was always bad." | We're claiming a property of the *syntax* (explicit closers, point-of-use types, local semantics). The 1980s implementations being slow or buggy is a separate axis. |
| "This is anti-AI." | Read the AI Pair section. The whole point is that the human's tool is the one that lets them keep up with an AI collaborator. |
| "Why not just write better prompts?" | Prompt quality is uncorrelated with output language. The audit cost is paid every time, regardless of prompt. |
| "Where are the numbers?" | `bench/ai_correctness/REPORT.md` — VG 100%, Python 100%, TS 84%, GDScript 68% on qwen2.5-coder:7b, N=25. Frontier-model run is next. |
| "That's just one 7B model." | Correct, and that's why the harness is in the repo: every per-attempt JSON is committed, anyone can re-run on gpt-4o or Claude in 10 minutes. |
| "BASIC tied with Python is not 'better than'." | Right, and I'm not claiming better-than on parse rate. The claim is *audit cost*, of which parse rate is one floor — and BASIC is not paying a tax for being verbose, which was the worry. |
