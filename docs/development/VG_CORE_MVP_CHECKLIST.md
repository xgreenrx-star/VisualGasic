# VG Core MVP Checklist

## Goal

Ship a language-first Godot-target deliverable quickly with clear pass/fail criteria.

Product names for this plan:
- Visual Gasic Studio (full IDE track, out-of-scope for MVP work)
- VG Script (language)
- VG Core (language/runtime/compiler project)

## Scope Guardrails

### In Scope (MVP)

- VG Script tokenizer for MVP syntax subset
- Parser + AST generation for MVP syntax subset
- Minimal semantic checks (undefined symbols, basic type/shape checks)
- Intermediate representation (IR) or equivalent normalized internal model
- Godot target emitter/runtime path for MVP subset
- CLI/scripted compile-run workflow
- Compatibility test corpus + baseline pass criteria
- Minimal developer docs for setup/compile/run/debug

### Out of Scope (MVP)

- New custom IDE feature work in Visual Gasic Studio
- Form Designer expansion/fixes unless they block core language validation
- Unity/Unreal production parity (design for it, do not implement full parity now)
- Non-essential debugger UX customizations
- Marketplace/packaging polish not required for MVP validation

## MVP Syntax/Feature Subset (v1)

- Variables: Dim, assignment, basic scalar types
- Expressions: arithmetic, comparison, boolean operators
- Control flow: If/ElseIf/Else, For/Next, While/Wend or Do/Loop subset
- Procedures: Sub/Function definitions and calls
- Core built-ins needed by sample apps/tests
- Basic object/member access used by Godot target

## Acceptance Criteria (Must Pass)

1. Compile pipeline works end-to-end for MVP subset.
2. At least 10 representative VG Script samples compile and run.
3. Compatibility tests pass on Godot reference backend.
4. Clear error messages for common parser/semantic failures.
5. One-command developer workflow documented.
6. No dependency on custom IDE features for core validation.

## Test Gates

### Parser/AST
- Golden AST snapshots for canonical inputs
- Syntax error fixture suite (invalid token/order/structure)

### Semantic
- Undefined symbol checks
- Duplicate declaration checks (within agreed scope)
- Procedure signature/arity checks (within agreed scope)

### Backend/Runtime
- Output compile/run smoke tests
- Behavior equivalence tests for control-flow and procedure calls
- Regression fixture set for previously fixed language bugs

## Milestones

### M1: Frontend Core
- Tokenizer done
- Parser done
- AST smoke tests green

### M2: Semantic + IR
- Minimal semantic pass done
- IR normalization done
- Core diagnostics stable

### M3: Godot Backend MVP
- Emitter/runtime path done for MVP subset
- Compile-run scripts stable
- Sample programs pass

### M4: Release Readiness
- Compatibility test baseline frozen
- Documentation complete
- Known limitations documented

## Definition of Done (MVP)

- All acceptance criteria satisfied
- Test gates green at agreed threshold
- MVP scope unchanged for final week (scope freeze)
- Team can onboard and run from docs without tribal knowledge

## Deferred to Post-MVP

- Unity backend implementation parity
- Unreal backend implementation parity
- Advanced language features outside v1 subset
- IDE-level convenience integrations beyond essentials
