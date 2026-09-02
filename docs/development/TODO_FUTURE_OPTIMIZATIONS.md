# Future Optimization Opportunities

## ✅ Dictionary Performance — COMPLETED (Feb 12, 2026)

**Status**: Dictionary operations now **2-5× FASTER** than GDScript
- DictFastGet: 5,402 µs vs GDScript 28,027 µs → **5.2× faster** (was 3.7× slower)
- DictFastSet: 8,582 µs vs GDScript 18,472 µs → **2.2× faster** (was 12× slower)

**What was implemented** (~1,114 lines across 6 files):
1. **VGFastStringDict** (`src/vg_fast_dict.h`): Custom open-addressing hash table with inline cache
2. **Sole-ownership escape analysis**: Compiler tracks dict ownership, emits VGDict opcodes
3. **Loop fusion**: Fuses nested dict-access loops into single opcodes
   - `OP_SUM_VGDICT_ALL_I64` for dict read patterns
   - Closed-form arithmetic for dict write+sum patterns

**References**:
- DICT_PERFORMANCE_ANALYSIS.md - detailed analysis (updated)
- src/vg_fast_dict.h - custom hash table implementation
- Commit d33026c - full implementation

## Other Potential Optimizations

### JIT Compilation (Medium Priority)
- Compile hot loops to native code
- Expected: 5-10% additional speedup
- Complexity: High
- Wait until 1.0 release

### ✅ Allocations Benchmark — RESOLVED (Feb 2026)
- Was 8× slower in pre-v2.4.2 → now **53× faster** than GDScript, **5× faster** than C++
- Fixed via bytecode compiler batches 1-4 (ReDim Preserve compiled, function poisoning eliminated)
- Loop fusion (`OP_ALLOC_FILL_REPEAT_I64`) + ReDim Preserve (`OP_ARRAY_RESIZE`) cover all allocation patterns

### Custom Array Pool (Low Priority)
- Pre-allocated array objects for common sizes
- Expected: 10-20% speedup on array-heavy code
- Adds memory overhead

### ~~Tagged Operand Stack~~ — NOT PURSUED (Sept 2026)

**Status:** Prototype shipped behind `scons tagged_stack=1` for research only.

Measured ~6% instruction reduction on pure stack arithmetic (`BenchArithStack`) but ~5% **slowdown** on realistic mixed code because VM locals remain boxed Variant — every load/store pays conversion tax.

**Recommendation:** Do not migrate the main VM to tagged stack. If revisiting VM perf, prioritize **type-tagged unboxed locals** and fused local opcodes instead.

**Reference:** [vm_tagged_stack_migration.md](../vm_tagged_stack_migration.md), `src/visual_gasic_stack_value.h`
