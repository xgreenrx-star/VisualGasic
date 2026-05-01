# 📌 Vision: Why VisualGasic Exists in the AI Era

> **TL;DR** — We believe BASIC's verbose, redundant syntax is uniquely suited
> to the era of AI-generated code, because it is unusually easy for a
> *human auditor* to read. VisualGasic is the language you read when you
> don't trust the AI.

Welcome to Discussions. This is the inaugural Vision post and the place to
push back on, refine, or extend the thesis below.

---

## The thesis in one paragraph

For thirty years the design pressure on programming languages has been to
make code **faster to write**. Python won, then JavaScript, then Go, then
Rust — all of them prioritising terseness, expressiveness, and getting out of
the writer's way. That made sense when humans wrote every line. **It does
not make sense any more.** When the AI writes the line, the human's job is to
**read** it — and read it under suspicion. The optimal language for that job
looks almost nothing like the languages that won the writer-centric era. It
looks a lot more like 1985.

## What changed

Three things, in the last 24 months:

1. **The author of most lines of code is now an AI.** Even if you push back
   on every diff, you are pushing back on a draft you didn't write.
2. **The cost of *writing* a line collapsed to roughly zero.** Whatever
   the tooling once optimised for, that goal is solved.
3. **The cost of *trusting* a line went up.** AI code that "looks right"
   and is subtly wrong is the new normal failure mode.

So the new question is: **what makes a language good to *audit*?**

## Why BASIC, specifically

BASIC syntax has properties most modern languages have explicitly avoided:

- **Block boundaries are spelled out.** `If ... End If`, `For ... Next i`,
  `Sub Foo() ... End Sub`. The closing tokens *name themselves*. There are no
  silent indent changes that flip an entire block.
- **Types are declared at point of use.** `Dim playerHealth As Single = 100.0`
  means you don't have to scroll to find out what `playerHealth` is. The
  auditor has the answer in their eye line.
- **Semantics are local.** No metaclasses, no decorators that rewrite the
  function below them, no `__getattr__` that turns ordinary attribute access
  into a network call. What you read is what runs.
- **There is one obvious way.** No list comprehension *and* `map()` *and*
  generator expression *and* loop. One loop construct. Verbose. Unmissable.

These are not aesthetic preferences. They are **auditor-friendliness
properties**, and AI writes a lot of code in a lot of languages that *don't*
have them.

## What this is not

- We are **not** claiming BASIC is "better than Python at everything."
  Python remains a fine language for most things, including a lot of
  AI-driven workflows.
- We are **not** trying to push BASIC into web backends or cloud infra. The
  thesis is specifically about **the read-and-verify step in the AI pipeline**.
- We are **not** anti-AI. VisualGasic ships with deep AI integration —
  see [AI Pair](../addons/visual_gasic/vg_ai_help.gd). The point is to make
  the AI a more useful collaborator by giving the human a syntax they can
  audit at speed.

## What we're shipping behind the thesis

- **[The manifesto](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/manifesto.md)** —
  the full argument, ~1200 words.
- **[`corpus/`](https://github.com/xgreenrx-star/VisualGasic/tree/main/corpus)** —
  50 hand-audited canonical VG programs, dual-licensed CC0-1.0 / Unlicense
  so model labs can include them in pretraining without legal review.
- **[`bench/ai_correctness/`](https://github.com/xgreenrx-star/VisualGasic/tree/main/bench/ai_correctness)** —
  empirical benchmark, pluggable across OpenAI / Anthropic / Gemini / Ollama.
  First run (qwen2.5-coder:7b, N=25): VG 100%, Python 100%, TypeScript 84%,
  GDScript 68%. Full report at
  [`bench/ai_correctness/REPORT.md`](https://github.com/xgreenrx-star/VisualGasic/blob/main/bench/ai_correctness/REPORT.md).
- **AI Pair panel** — the in-IDE "read-and-verify console for AI-generated
  code", with multiple personas (Bob, Skippy, Orac, HAL, default) and
  push-to-talk voice mode.

## Where you come in

This thread is the right place for:

- **Disagreement.** If you think the thesis is wrong, post a counter-argument.
  We will take it seriously and either refine the position or, if you're
  right, change it.
- **Sharper framings.** "AI-readable BASIC" is the slogan today, but if
  there's a better one we'll switch.
- **Evidence.** If you have data — even a single anecdote about reading
  AI-generated VB / Python / Go / Rust under time pressure — drop it below.
- **Counter-examples.** Patterns where verbose syntax actively *hurts*
  auditing. We want to know about them before they bite users.

We will *not* use this thread to:

- Argue about taste. Whether you "like" BASIC syntax is not the question.
  Whether it lowers audit error rate is.
- Re-litigate Python vs. JavaScript debates. There are dozens of better
  threads for that on this very site.

Thanks for reading. The thesis is genuinely held but genuinely revisable.
Punch it.

— The VisualGasic team
