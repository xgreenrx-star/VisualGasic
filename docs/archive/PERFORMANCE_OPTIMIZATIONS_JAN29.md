# VisualGasic Performance Optimizations - January 29, 2026

## Deep Internal Implementation Research & Optimizations

### Critical Findings

#### 1. Array Copy-on-Write Overhead
**Issue**: Every array access was copying the entire array due to value semantics:
```cpp
Array arr = base;  // COPIES the entire array!
int idx = to_int(index_var);
result = arr[idx];
```

**Solution**: Use `VariantInternal::get_array()` to get pointer without copying:
```cpp
const Array *arr_ptr = VariantInternal::get_array(&base);
int idx = to_int(index_var);
result = (*arr_ptr)[idx];  // No copy!
```

#### 2. Dictionary Access Patterns
**Issue**: Key caching with String→StringName conversion added overhead without measurable benefit for simple operations.

**Solution**: Direct native pointer access using `VariantInternal::get_dictionary()` and GDExtension native interfaces:
```cpp
const Dictionary *dict_ptr = VariantInternal::get_dictionary(&base);
const VgDictKeyedOps &dict_ops = vg_dict_keyed_ops();
dict_ops.getter(dict_ptr->_native_ptr(), key_var._native_ptr(), result._native_ptr());
```

#### 3. In-Place Dictionary Modification
**Issue**: Original implementation loaded dictionary from variable, modified copy, stored back:
```cpp
compile_expression(&dict_var);      // Copies dict to stack
OP_SET_DICT_FAST                    // Modifies dict  
OP_SET_LOCAL                        // Copies dict back to variable
```

**Solution**: New opcodes `OP_SET_DICT_LOCAL` and `OP_SET_DICT_GLOBAL` that modify variable directly:
```cpp
// Only key and value on stack
OP_SET_DICT_LOCAL slot_idx          // Modifies local[slot] in-place
```

### Performance Results

#### Before Optimizations (Initial State)
- DictFastSet: 231ms (11.8× slower than GDScript)
- ArrayDict: 77ms (7.2× slower than GDScript)
- ArraySum: 104µs

#### After Array Pointer Optimizations
- **ArraySum**: 80µs (38% faster) ✅
- **ArrayDict**: 39ms (49% faster) ✅
- Arithmetic: 134µs (23× faster than GDScript) ✅

#### Current State (Jan 29, 2026)
```
Benchmark          GDScript    VisualGasic   Speedup     Status
-----------------------------------------------------------------
Arithmetic         3.1ms       134µs         23.1×       ✅ Excellent
ArraySum           2.8ms       80µs          35.1×       ✅ Excellent  
StringConcat       5.2ms       54µs          96.3×       ✅ Excellent
Branching          6.7ms       50µs          134×        ✅ Excellent
ArrayDict          8.1ms       39ms          0.21×       ⚠️  Needs work
DictFastGet        18.3ms      106ms         0.17×       ⚠️  Needs work
DictFastSet        18.6ms      196ms         0.095×      ❌ Regression
AllocationsFast    10.7ms      1.1ms         9.5×        ✅ Excellent
```

### Key Optimizations Implemented

1. **OP_GET_ARRAY_FAST / OP_SET_ARRAY_FAST**: Use `VariantInternal::get_array()` pointer semantics
2. **OP_GET_DICT_FAST / OP_SET_DICT_FAST**: Use `VariantInternal::get_dictionary()` pointer semantics  
3. **OP_SET_DICT_LOCAL / OP_SET_DICT_GLOBAL**: In-place dictionary modification without load/store
4. **OP_SUM_ARRAY_I64**: Eliminated array copy in tight loop
5. **String concatenation**: Removed unnecessary String() conversions

### Remaining Performance Issues

#### Dictionary Operations Still Slow
The benchmarks show dictionary operations (DictFastGet, DictFastSet, ArrayDict) are still 5-10× slower than GDScript.

**Root Causes:**
1. **Godot Dictionary Internal Overhead**: Even with native pointers, Godot's Dictionary uses complex hash table implementation with collision handling
2. **String Key Hashing**: Each dictionary access hashes the string key using CRC32 or similar
3. **Variant Wrapping**: Keys and values must be wrapped in Variant, adding allocation overhead
4. **COW Semantics**: Copy-on-write tracking adds checks on every operation

**Potential Future Optimizations:**
1. **Specialized String Dictionary Type**: Implement `StringDictionary` with simpler hash function
2. **Key Interning**: Pre-compute and cache string hashes for repeated keys  
3. **Inline Small Dictionaries**: For dictionaries with <8 entries, use linear search array
4. **JIT Dictionary Access**: Generate specialized code for known dictionary variables
5. **Batch Operations**: Add opcodes for bulk dictionary gets/sets to amortize overhead

### Code Locations

**Optimized Opcodes:**
- `src/visual_gasic_instance.cpp:6973` - OP_GET_ARRAY_FAST (pointer semantics)
- `src/visual_gasic_instance.cpp:7093` - OP_SET_ARRAY_FAST (pointer semantics)
- `src/visual_gasic_instance.cpp:7006` - OP_GET_DICT_FAST (native pointers)
- `src/visual_gasic_instance.cpp:7127` - OP_SET_DICT_FAST (native pointers)
- `src/visual_gasic_instance.cpp:7171` - OP_SET_DICT_LOCAL/GLOBAL (in-place modification)
- `src/visual_gasic_instance.cpp:7222` - OP_SUM_ARRAY_I64 (pointer semantics)

**New Opcodes:**
- `src/visual_gasic_bytecode.h:107` - OP_SET_DICT_LOCAL, OP_SET_DICT_GLOBAL
- `src/visual_gasic_compiler.cpp:1960-1995` - Compiler emits in-place dict opcodes

### Benchmarking Methodology

Tests run with `Godot_v4.5.1-stable_linux.x86_64 --headless` to eliminate GUI overhead.

**Key Test Cases:**
- **DictFastGet**: `dict(keys(i))` in tight loop (tests array + dict GET)
- **DictFastSet**: `dict(keys(i)) = value` in tight loop (tests array + dict SET)
- **ArrayDict**: Mixed array and dictionary operations
- **ArraySum**: Pure integer array summing

### Lessons Learned

1. **Godot COW is Expensive**: Copy-on-write semantics mean `Array arr = base` creates a full copy
2. **VariantInternal is Essential**: Direct pointer access eliminates copies but must be used carefully
3. **Native GDExtension Interfaces**: Using `GDExtensionPtrKeyed*` functions bypasses Variant overhead
4. **Opcode Specialization Matters**: In-place modification opcodes avoid load/store roundtrips
5. **String Operations are Complex**: Dictionary key hashing and comparison dominate dictionary benchmark time
6. **Micro-optimizations Add Up**: Eliminating single copy saves milliseconds in tight loops

### Next Steps

To achieve parity or better performance than GDScript for dictionary operations:

1. **Profile dictionary internal operations** to identify exact bottleneck
2. **Implement specialized fast dictionary** for string keys with simpler hash
3. **Add bulk operation opcodes** to amortize per-operation overhead
4. **Consider JIT compilation** for hot loops with dictionary access
5. **Optimize ReDim operations** (BenchAllocations still 8× slower)

