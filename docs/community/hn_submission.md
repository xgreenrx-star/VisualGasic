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

I am running an empirical benchmark next: same 25–100 prompts across VG /
GDScript / Python / TypeScript, same model, same temperature, measure
first-attempt parse-success rate. Harness is in the repo
(`bench/ai_correctness/`) along with a 50-program reference corpus
(`corpus/`, CC0). Numbers will follow in a separate post.

Happy to be wrong about any of this. The strongest counter-argument I can
think of myself is that LLMs have seen *so much* Python that they make fewer
mistakes there in absolute terms even if the surface syntax is harder to
audit. That's exactly what the benchmark is supposed to settle.

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
| "Where are the numbers?" | In `bench/ai_correctness/`, runnable today. Results will be a follow-up post. |
