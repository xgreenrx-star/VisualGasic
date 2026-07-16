# Emulator Performance Roadmap

*Filed: Jul 16, 2026*
*Author: Agent-assisted design review*

## Goal

Make VG fast enough for cycle-level system emulation (C64, Atari 2600, GBA, etc.) 
without requiring an emulator project as the prerequisite. These optimizations 
benefit ALL game developers — emulators are just the stress test.

## Principled Approach

The Emulator Engineering Rules from ROADMAP.md forbid "black-box native cores" 
where VG is just UI glue. Every optimization here is either:

- **A general-purpose VG language/VM feature** (benefits all users), OR
- **A generic C++ primitive** with documented non-emulator use cases

No console-specific behavior in native code. No hidden emulator cores.

---

## Optimization 1: Bit Manipulation Builtins

**Status: ✅ IMPLEMENTED (Jul 16, 2026)**

### What
Low-latency intrinsic functions for bit-level operations. Maps to single x86 
instructions at the JIT level; avoids function-call overhead at the bytecode level.

### Functions Added

| Function | Description | Example |
|----------|-------------|---------|
| `GetBit(val, bit)` | Returns `True` if bit `n` is set | `GetBit(&b00001111, 2) = True` |
| `SetBit(val, bit, state)` | Sets/clears bit `n`, returns result | `SetBit(0, 3, True) = 8` |
| `ToggleBit(val, bit)` | Flips bit `n`, returns result | `ToggleBit(8, 3) = 0` |
| `CountBits(val)` | Population count (popcount) | `CountBits(255) = 8` |
| `RotateLeft(val, n)` | Circular left shift | `RotateLeft(&b10000001, 1) = &b00000011` |
| `RotateRight(val, n)` | Circular right shift | `RotateRight(&b00000011, 1) = &b10000001` |
| `BitCount(val)` | Alias for CountBits | — |

### Files Touched
- `src/visual_gasic_builtins.cpp` — `call_builtin_expr_evaluated()` / `call_builtin_expr()`
- `src/visual_gasic_instance_evaluate.inc` — expression evaluator builtin dispatch
- `src/visual_gasic_instance_bytecode_vm.cpp` — bytecode VM OP_CALL handler

### Game Dev Use Cases
- Collision masks (check/set/clear individual bits)
- Save codes (pack N booleans into a single Integer)
- Procedural generation (bit-twiddling RNG, Perlin noise)
- Graphics: color channel extraction, palette indexing
- Compression: run-length encoding, bitstream packing

### Non-Emulator Benchmarks
(TODO — run after implementation)

---

## Optimization 2: Rotate Operators (`<<<`, `>>>`)

**Status: ✅ IMPLEMENTED (Jul 16, 2026)**

### What
New binary operators for bitwise rotation — distinct from shift (`<<`, `>>`). 
Useful for CPU emulation (6502 ROL/ROR, 68000 ROL/ROR), cryptography (AES, 
SHA), and graphics (bitmap rotation).

### Syntax
```vb
Dim result As Integer
result = value <<< 3   ' Rotate left by 3 bits
result = value >>> 2   ' Rotate right by 2 bits
```

### Files Touched
- `src/visual_gasic_tokenizer.cpp` — new token types `TOKEN_OP_ROTL`, `TOKEN_OP_ROTR`
- `src/visual_gasic_parser.cpp` — operator precedence in `parse_shift()`
- `src/visual_gasic_compiler.cpp` — emit `OP_ROTL` / `OP_ROTR`
- `src/visual_gasic_bytecode.h` — new opcodes
- `src/visual_gasic_instance_evaluate.inc` — AST interpreter evaluation
- `src/visual_gasic_instance_bytecode_vm.cpp` — VM dispatch
- `src/visual_gasic_expression_evaluator.h/.cpp` — REPL/Immediate Window evaluation
- `src/visual_gasic_optimizer.cpp` — constant folding for rotate ops

### Game Dev Use Cases
- Graphics: rotation of tile data, sprite flipping
- Cryptography: in-game save encryption, seed generation
- Audio: waveform table rotation for detuning/chorus effects

---

## Optimization 3: SoundGen Tutorial + Documentation

**Status: ✅ COMPLETE (Jul 16, 2026)**

### What
The `SoundGen.*` real-time audio synthesis pipeline already works. 
Game devs don't know it exists. A guided tutorial and demo fills the gap.

### Deliverables
- `tutorials/audio_synthesis.md` — step-by-step guide
- `demo/audio_synthesis/` — playable VG project showing 3 synthesis techniques
- Updates to `docs/VisualGasic_Language_Reference.md` SoundGen section

### SoundGen API Reference (existing, for documentation)

| Call | Description |
|------|-------------|
| `SoundGen.Open(mix_rate, buf_len)` | Create synth → returns handle |
| `SoundGen.Close(h)` | Free handle |
| `SoundGen.Available(h)` | Frames writable this frame |
| `SoundGen.PushMono(h, sample)` | Push one mono frame |
| `SoundGen.PushStereo(h, l, r)` | Push one stereo frame |
| `SoundGen.PushMonoBuffer(h, samples)` | Push PackedFloat32Array as mono |
| `SoundGen.PushStereoBuffer(h, samples)` | Push interleaved PackedFloat32Array |
| `SoundGen.FillVoices(h, ...)` | 3-voice synth (square, kick, noise) |
| `SoundGen.FillVoices4(h, ...)` | 4-voice synth (lead, bass, arp, hi-hat, 808 kick) |

---

## Optimization 4: Profiling Existing Game Demos

**Status: 🔲 NOT STARTED**

### What
Run the existing game demos (vector_storm, Pong, Space Shooter, etc.) through 
the VG Profiler to identify real-world hotspots. Use data to drive optimization 
priorities.

### Method
1. Install profiling build (template_debug or editor)
2. Run each demo for 60 seconds while profiling
3. Collect: top-10 hot functions, total frame time, GC/alloc pressure
4. Correlate with ROADMAP's Tier A/B optimization candidates

### Demos to Profile
| Demo | Expected Hotspot | Notes |
|------|-----------------|-------|
| vector_storm | Array/Single boxing (proven) | 240-cell loop = 16ms/frame |
| Pong | _draw() calls, collision loops | Simple, good baseline |
| Space Shooter | Bullet/Dictionary lookups | Object pools |
| Piano | AudioStreamGenerator push | Real-time audio |
| Galactic Defender | Inheritance dispatch | Large OOP project |

---

## Optimization 5: Tutorial on Fast VG Patterns

**Status: 🔲 NOT STARTED**

### What
A developer guide teaching how to write performant VG code without changing the 
runtime. Many slowdowns come from unawareness of Variant boxing, Dictionary 
lookup costs, and function call overhead.

### Topics to Cover
1. **Use `Dim x As Byte/Int32/Single` instead of untyped `Dim x`** — reduces Variant boxing
2. **Prefer `For i = 0 To N` over `For Each`** — For Each allocates an iterator
3. **Use locals, not globals** — global lookups are always Dictionary; locals are indexed array
4. **Avoid `&` string concat in hot loops** — use `String.join()` or buffer array
5. **Use `PackedFloat32Array` for large data** — direct C++ interop, no VG boxing
6. **Minimize `_draw()` calls** — batch rendering, use `queue_redraw()` sparingly
7. **Use `SoundGen.PushMonoBuffer()` not individual `PushMono()`** — one C++ call vs N
8. **Prefer `While`/`Wend` over `Do`/`Loop`** — fewer AST nodes, faster compile
9. **Use `Array.Resize` instead of `ReDim Preserve`** — less overhead
10. **Profile before optimizing** — use VG Profiler, not guesses

---

## Appendix: C++ Files to Modify (Complete List)

### For Bit Builtins (Optimization 1)
- `src/visual_gasic_builtins.cpp` — add 7 new function entries to `call_builtin_expr_evaluated()`
- No AST/compiler/VM changes — goes through existing `OP_CALL` dispatch

### For Rotate Operators (Optimization 2)
- `src/visual_gasic_tokenizer.cpp` — new tokens
- `src/visual_gasic_parser.h` — new AST node or reuse BinaryOpNode
- `src/visual_gasic_parser.cpp` — operator precedence
- `src/visual_gasic_compiler.cpp` — compile to opcodes or desugar to builtin calls
- `src/visual_gasic_bytecode.h` — new opcode enum values
- `src/visual_gasic_instance_evaluate.inc` — evaluator
- `src/visual_gasic_instance_bytecode_vm.cpp` — VM dispatch
- `src/visual_gasic_expression_evaluator.cpp` — REPL evaluator
- `src/visual_gasic_optimizer.cpp` — constant folding

### For Inline Builtins (Future)
- `src/visual_gasic_compiler.cpp` — recognize `Len(var)` pattern and emit `OP_BUILTIN_LEN`
- `src/visual_gasic_bytecode.h` — new opcodes
- `src/visual_gasic_instance_bytecode_vm.cpp` — fast-path handlers
- `src/visual_gasic_optimizer.cpp` — size registration

### For PackedArray Fast-Path (Future)
- `src/visual_gasic_compiler.cpp` — detect `Dim x(N) As Byte` → PackedByteArray
- `src/visual_gasic_bytecode.h` — new opcodes
- `src/visual_gasic_instance_bytecode_vm.cpp` — direct C++ array access
- `src/visual_gasic_optimizer.cpp` — size + DCE support

---

*This roadmap is a living document. Update as optimizations are implemented, 
profiled, and new priorities emerge.*
