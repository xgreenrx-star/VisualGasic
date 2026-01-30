# Future Optimization Opportunities

## Dictionary Performance (Low Priority)

**Current Status**: Dictionary operations 3-12× slower than GDScript
- DictFastGet: 105ms vs 28ms (3.7× slower)
- DictFastSet: 220ms vs 18ms (12× slower)

**Root Cause**: Godot's `HashMap<Variant, Variant>` is not optimized for tight loops

**Potential Solution**: Implement specialized `StringDictionary` class
```
Estimated Effort: ~1000-1500 lines
Expected Improvement: 2-3× faster, could match GDScript
Implementation: HashMap<String, Variant> with cached hashes
```

**Decision**: Skip for now - core operations (math, arrays, strings, control flow) are 10-124× faster than GDScript. Only revisit if profiling shows dictionary operations are actual bottleneck in real applications.

**References**:
- DICT_PERFORMANCE_ANALYSIS.md - detailed analysis
- Godot source: core/variant/dictionary.cpp, core/templates/hash_map.h
- GDScript VM: modules/gdscript/gdscript_vm.cpp

## Other Potential Optimizations

### JIT Compilation (Medium Priority)
- Compile hot loops to native code
- Expected: 5-10% additional speedup
- Complexity: High
- Wait until 1.0 release

### Allocations Benchmark (Medium Priority)  
- ReDim operations currently 8× slower
- Could optimize array resizing
- Expected: Match GDScript on Allocations benchmark

### Custom Array Pool (Low Priority)
- Pre-allocated array objects for common sizes
- Expected: 10-20% speedup on array-heavy code
- Adds memory overhead
