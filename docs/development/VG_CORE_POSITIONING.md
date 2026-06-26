# VG Core Positioning (Godot-First, Language-First)

## Purpose

This note defines the short-term split strategy:

- `Visual Gasic Studio` remains the full IDE product line.
- `VG Script` is the language identity.
- `VG Core` is the language/runtime/compiler-focused project for cross-engine delivery.

The goal is to ship a stable, language-first deliverable sooner while preserving a path to Unity and Unreal.

## Scope Boundaries

### In Scope (VG Core)

- Tokenizer and parser
- AST and semantic analysis
- Intermediate representation (IR)
- Target emitters/transpilers
- Runtime compatibility layer(s)
- Automated language compatibility tests

### Out of Scope (VG Core, near-term)

- Full custom IDE UX feature work
- Form designer feature expansion
- Broad editor-specific UI/debugger customization not required for core language delivery

## Migration Strategy

- Start from the pre-UI VG1 core baseline where possible.
- Selectively port proven 5.x.x Beta4 core language/runtime improvements.
- Avoid reintroducing heavy IDE/UI coupling into core components.

## Delivery Order

1. Godot target first (reference backend)
2. Unity target parity
3. Unreal target parity

## Compatibility Contract

`VG Script` source compatibility is the primary requirement.

- The same `VG Script` program should preserve behavior across supported backends.
- Backend differences must be documented and tested with compatibility fixtures.

## Tooling Principle

Use Godot's built-in editor and debugger where feasible for the Godot target.
Add custom tooling only when a concrete blocker prevents required language/runtime validation.

## Initial Milestone (MVP)

- Core tokenizer/parser/AST pipeline for chosen MVP subset
- Godot backend emitter/runtime path for MVP subset
- CLI or scripted build/run flow
- Compatibility test corpus and baseline pass criteria
- Minimal developer documentation for compile/run workflow
