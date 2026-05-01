# r/programming submission

## Title (pick one)

Primary (recommended):

> **Why the AI era needs BASIC again — a defense of verbose, auditor-friendly syntax**

Alternates:

- I think we picked the wrong programming language for the AI era
- BASIC-family syntax, reconsidered: the language you read when you don't trust the AI
- VisualGasic: a serious BASIC for game development, repositioned as "AI-readable BASIC"

## URL field

```
https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/manifesto.md
```

(Or, if you want a longer-form post, use the **text** option and paste the
body below in full.)

## Text body (for self-post variant)

For thirty years, the design pressure on programming languages has been to
make code **faster to write**. Python won, then JavaScript, then Go, then
Rust — all of them prioritising terseness, expressiveness, and getting out of
the writer's way.

That made sense when humans wrote every line. I no longer think it makes
sense, and I want to lay out the argument and invite people to punch holes in
it.

**The change.** The author of most lines of code in 2026 is an AI. Even
people who push back on every diff are pushing back on a draft they didn't
write. The cost of *writing* a line collapsed to roughly zero. The cost of
*trusting* a line went up — AI code that "looks right" and is subtly wrong
is the new normal failure mode.

So the new question is: **what makes a language good to *audit*?**

**The claim.** BASIC-family syntax has four properties most modern languages
have explicitly avoided, and all four directly help the auditor:

1. *Block boundaries are spelled out.* `If ... End If`, `For ... Next i`,
   `Sub Foo() ... End Sub`. Closing tokens name themselves. There are no
   silent indent changes that flip an entire block's meaning — which, when
   the AI emits a stray space, is the bug you spend an afternoon finding.
2. *Types are declared at point of use.* `Dim playerHealth As Single = 100.0`.
   No scrolling to find out what something is. The auditor has the answer in
   their eye line.
3. *Semantics are local.* No metaclasses. No decorators that rewrite the
   function below them. No `__getattr__` that turns `obj.foo` into a network
   call. What you read is what runs.
4. *There is one obvious way.* No list comprehension *and* `map()` *and*
   generator expression *and* loop. One construct per concept. Verbose.
   Unmissable.

**What I'm not claiming.** That BASIC is "better than Python at everything."
That you should rewrite your backend. That AI is bad. None of those.

**What I'm doing about it.** Three things:

- The full argument as a [manifesto](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/manifesto.md)
  (~1200 words).
- A [50-program reference corpus](https://github.com/xgreenrx-star/VisualGasic/tree/main/corpus),
  hand-audited, dual-licensed CC0/Unlicense so model labs can ingest it.
- A [benchmark harness](https://github.com/xgreenrx-star/VisualGasic/tree/main/bench/ai_correctness):
  same prompts across VG / GDScript / Python / TypeScript, same model, same
  temperature, measure first-attempt parse-success. First run is in:
  qwen2.5-coder:7b scores VG **100%**, Python **100%**, TypeScript **84%**,
  GDScript **68%** on N=25. Full report and raw outputs at
  [`bench/ai_correctness/REPORT.md`](https://github.com/xgreenrx-star/VisualGasic/blob/main/bench/ai_correctness/REPORT.md).
  Frontier-model run is the next post.

**Where I want to be wrong.** The strongest counter-argument I can think of
is that LLMs have seen so much more Python than BASIC that they simply make
fewer mistakes there in absolute terms, even if the surface syntax is harder
for a human to audit. The 7B-model numbers don't refute that — they suggest
VG's syntax advantage at least matches Python's training-data advantage at
this scale. If you have other counter-arguments, I want to hear them.

## Posting checklist

- r/programming requires a meaningful description; do not post URL-only.
- Mods are quick to remove "promotional" content. Frame the post around the
  *idea*, not the project — link to the project as evidence, not as the
  pitch.
- Best window: Tuesday–Thursday, 09:00–14:00 UTC. Avoid weekends (sub is
  quieter and more hostile).
- Stay engaged with comments for at least 6 hours. The first 2 hours
  determine whether it surfaces.

## Common comment patterns and prepared replies

| Pattern | Reply |
|---|---|
| "AI shouldn't write code at all." | Fair position; the post is about the world where it does, which is the world we ship into. |
| "Just use static analysis." | Static analysis is great. It is not a substitute for a syntax that lets a human catch the analyser's blind spots. |
| "Verbose syntax is annoying to write." | Agreed. But the cost has shifted: the AI writes it once, the human reads it many times. |
| "VB6 had its problems." | Nobody is shipping VB6. The claim is about the *syntax family*, not any specific 1990s implementation. |
| "Where are the numbers?" | `bench/ai_correctness/REPORT.md` — VG 100%, Py 100%, TS 84%, GDScript 68% on qwen2.5-coder:7b, N=25. Frontier-model run is next. |

## Tags / flair

If the sub allows flair, use **Discussion** or **Article** rather than
**Project**. The thesis is the lead, the project is the evidence.
