# VisualGasic — The language you read when you don't trust the AI.


[![CI](https://github.com/xgreenrx-star/VisualGasic/actions/workflows/ci.yml/badge.svg)](https://github.com/xgreenrx-star/VisualGasic/actions/workflows/ci.yml)
[![Version](https://img.shields.io/badge/version-5.2.0--Beta4-blue.svg)](https://github.com/xgreenrx-star/VisualGasic/releases)
[![License](https://img.shields.io/badge/license-GPL--3.0-green.svg)](LICENSE)
[![Godot](https://img.shields.io/badge/Godot-4.6.1+-purple.svg)](https://godotengine.org)


> **For 50 years, programming languages have been optimized for the human writer. The next 50 years will be optimized for the human reader auditing AI output. That is a different job, and it wants a different language.**
>
> VisualGasic is BASIC, redesigned for the AI era — a VB6-syntax language with a 5-tier JIT compiler, a full WYSIWYG IDE, and an AI Pair panel built in. It runs as a C++ GDExtension inside Godot 4.6.


## 🧭 The thesis


In 2026, working programmers spend more time **reviewing AI-generated code** than writing original code from scratch. The bottleneck has moved from authoring to **auditing**. Almost no language in mainstream use was designed for auditing.


**BASIC was.** It is the only mainstream syntax family ever explicitly engineered for code-reading at a glance. Verbose blocks (`End Sub`, `End If`, `End Class`) are harder to mis-nest. Explicit type annotations (`Dim x As Integer`) carry more signal per token than `let x = 0`. There are no operator overloads, no implicit constructors, no hidden destructors. **What you see is what runs.**


It also turns out that LLMs *write* this kind of language with fewer bugs than they write Python or C++. Verbose, redundant syntax is easier for the model to get right at every closing token. So the AI era delivers a double win: **humans audit BASIC faster, and AI writes BASIC more correctly.** Those compound.


The historical reason BASIC lost the popularity contest was tooling, not language — and we have solved tooling. VG's 5-tier JIT compiles to bytecode that runs at native-class speed (30–119× faster than GDScript, beats C++ on some workloads — numbers below). The "BASIC can't compete" excuse is no longer available.


### The next decade — and why BASIC wins it


The trajectory of the next ten years is already visible. Three things are happening at once:


1. **Authoring cost collapses to zero.** A junior model in 2026 emits more code per dollar than a senior engineer wrote in a year. By 2030 the marginal cost of a draft is rounding error. Whatever's still scarce, it isn't typing.
