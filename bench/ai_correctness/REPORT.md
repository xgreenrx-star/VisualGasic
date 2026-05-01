# AI Correctness Benchmark — Results

First-attempt parse-success rate, by model and language.

| Model | vg | gdscript | python | typescript | N |
|---|---:|---:|---:|---:|---:|
| qwen2.5-coder:7b | 25/25  (100%) | 17/25  (68%) | 25/25  (100%) | 21/25  (84%) | 25 |

## Per-category breakdown (qwen2.5-coder:7b)

| Category | vg | gdscript | python | typescript |
|---|---:|---:|---:|---:|
| arrays | 3/3 | 3/3 | 3/3 | 3/3 |
| basics | 3/3 | 3/3 | 3/3 | 1/3 |
| classes | 2/2 | 0/2 | 2/2 | 2/2 |
| control_flow | 3/3 | 3/3 | 3/3 | 3/3 |
| dictionaries | 2/2 | 1/2 | 2/2 | 2/2 |
| file_io | 2/2 | 0/2 | 2/2 | 1/2 |
| godot_integration | 2/2 | 0/2 | 2/2 | 1/2 |
| math | 3/3 | 3/3 | 3/3 | 3/3 |
| state_machines | 2/2 | 1/2 | 2/2 | 2/2 |
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
