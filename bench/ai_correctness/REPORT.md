# AI Correctness Benchmark — Results

First-attempt parse-success rate, by model and language.

| Model | vg | gdscript | python | csharp | typescript | N |
|---|---:|---:|---:|---:|---:|---:|
| claude-sonnet-4-6 | 25/25 (100%) | 24/25 (96%) | 25/25 (100%) | 20/25 (80%) | — | 25 |
| claude-sonnet-4-5 | 25/25 (100%) | 25/25 (100%) | 25/25 (100%) | — | 23/25 (92%) | 25 |
| qwen2.5-coder:7b | 25/25 (100%) | 17/25 (68%) | 25/25 (100%) | — | 21/25 (84%) | 25 |

## Per-category breakdown (claude-sonnet-4-6)

| Category | vg | gdscript | python | csharp |
|---|---:|---:|---:|---:|
| arrays | 3/3 | 3/3 | 3/3 | 3/3 |
| basics | 3/3 | 3/3 | 3/3 | 3/3 |
| classes | 2/2 | 1/2 | 2/2 | 0/2 |
| control_flow | 3/3 | 3/3 | 3/3 | 3/3 |
| dictionaries | 2/2 | 2/2 | 2/2 | 2/2 |
| file_io | 2/2 | 2/2 | 2/2 | 2/2 |
| godot_integration | 2/2 | 2/2 | 2/2 | 0/2 |
| math | 3/3 | 3/3 | 3/3 | 3/3 |
| state_machines | 2/2 | 2/2 | 2/2 | 1/2 |
| strings | 3/3 | 3/3 | 3/3 | 3/3 |

## Per-category breakdown (claude-sonnet-4-5)

| Category | vg | gdscript | python | typescript |
|---|---:|---:|---:|---:|
| arrays | 3/3 | 3/3 | 3/3 | 3/3 |
| basics | 3/3 | 3/3 | 3/3 | 2/3 |
| classes | 2/2 | 2/2 | 2/2 | 2/2 |
| control_flow | 3/3 | 3/3 | 3/3 | 3/3 |
| dictionaries | 2/2 | 2/2 | 2/2 | 2/2 |
| file_io | 2/2 | 2/2 | 2/2 | 1/2 |
| godot_integration | 2/2 | 2/2 | 2/2 | 2/2 |
| math | 3/3 | 3/3 | 3/3 | 3/3 |
| state_machines | 2/2 | 2/2 | 2/2 | 2/2 |
| strings | 3/3 | 3/3 | 3/3 | 3/3 |

## Failed attempts (sample)

- **qwen2.5-coder:7b** / gdscript / G02 (godot_integration): `SCRIPT ERROR: Parse Error: The function signature doesn't match the parent. Parent signature is "quit(int = <default>) -`
- **qwen2.5-coder:7b** / gdscript / F01 (file_io): `SCRIPT ERROR: Parse Error: Identifier "File" not declared in the current scope.`
- **qwen2.5-coder:7b** / gdscript / T01 (state_machines): `SCRIPT ERROR: Parse Error: "yield" was removed in Godot 4. Use "await" instead.`
- **qwen2.5-coder:7b** / typescript / B03 (basics): `bench/ai_correctness/results/qwen2_5-coder_7b/B03_typescript.ts(3,19): error TS1351: An identifier or keyword cannot imm`
- **qwen2.5-coder:7b** / gdscript / K02 (classes): `SCRIPT ERROR: Parse Error: Too many arguments for "new()" call. Expected at most 0 but received 2.`
- **qwen2.5-coder:7b** / typescript / B02 (basics): `bench/ai_correctness/results/qwen2_5-coder_7b/B02_typescript.ts(1,5): error TS2451: Cannot redeclare block-scoped variab`
- **qwen2.5-coder:7b** / gdscript / F02 (file_io): `SCRIPT ERROR: Parse Error: Expected "]" after subscription index.`
- **qwen2.5-coder:7b** / gdscript / K01 (classes): `SCRIPT ERROR: Parse Error: Too many arguments for "new()" call. Expected at most 0 but received 2.`
- **qwen2.5-coder:7b** / typescript / G02 (godot_integration): `bench/ai_correctness/results/qwen2_5-coder_7b/G02_typescript.ts(5,5): error TS2304: Cannot find name 'lblTime'.`
- **qwen2.5-coder:7b** / typescript / F01 (file_io): `bench/ai_correctness/results/qwen2_5-coder_7b/F01_typescript.ts(1,21): error TS2591: Cannot find name 'fs'. Do you need `
- **qwen2.5-coder:7b** / gdscript / G01 (godot_integration): `SCRIPT ERROR: Parse Error: Static function "get_datetime()" not found in base "GDScriptNativeClass".`
- **qwen2.5-coder:7b** / gdscript / D02 (dictionaries): `SCRIPT ERROR: Parse Error: Expected "in" or ":" after "for" variable name.`
- **claude-sonnet-4-5** / typescript / B02 (basics): `bench/ai_correctness/results/claude-sonnet-4-5/B02_typescript.ts(1,7): error TS2451: Cannot redeclare block-scoped varia`
- **claude-sonnet-4-5** / typescript / F01 (file_io): `bench/ai_correctness/results/claude-sonnet-4-5/F01_typescript.ts(1,21): error TS2591: Cannot find name 'fs'. Do you need`
- **claude-sonnet-4-6** / csharp / K01 (classes): `error CS8803: Top-level statements must precede namespace and type declarations` — model generated a class body instead of top-level statements
- **claude-sonnet-4-6** / csharp / K02 (classes): `error CS8803: Top-level statements must precede namespace and type declarations` — same pattern
- **claude-sonnet-4-6** / csharp / T01 (state_machines): `error CS8803: Top-level statements must precede namespace and type declarations` — model added a class wrapper unprompted
- **claude-sonnet-4-6** / csharp / G01 (godot_integration): `error CS0234: The type or namespace 'Forms' does not exist in 'System.Windows'` — model assumed WinForms availability
- **claude-sonnet-4-6** / csharp / G02 (godot_integration): `error CS0234: The type or namespace 'Forms' does not exist in 'System.Windows'` — same WinForms assumption
- **claude-sonnet-4-6** / gdscript / K01 (classes): `Parse Error: The method "to_string()" overrides a method from native class "Object"` — Godot-specific naming collision
