# FFI (Native Library) Examples

Demonstrates calling native C and C++ shared libraries from VisualGasic scripts.

## Examples

| File | Description |
|------|-------------|
| `demo_ffi.vg` | Basic FFI — load `libm.so.6`, call `sqrt`, `sin`, `cos`, `pow`. Uses `QuickCall` (auto-detect types) and `CallFunction` (explicit types). Also shows `NativeStruct` for C struct layout. |
| `demo_ffi_cpp_lib.vg` | C++ class via C ABI — compile `custom_c_lib/vec2_lib.cpp` to `.so`, then create/destroy/set/get/normalize Vec2 objects from VG. Demonstrates `pointer` type, object lifecycle, and `string` return type. |
| `custom_c_lib/vec2_lib.h` | C header for the Vec2 library |
| `custom_c_lib/vec2_lib.cpp` | C++ implementation with C ABI wrappers |
| `custom_c_lib/build_vec2.sh` | Build script |

## Building the C++ Example

```bash
cd demos/Utilities/FFI/custom_c_lib/
bash build_vec2.sh
# Creates vec2.so
```

## Running

```bash
# From the project root:
godot --headless --script demos/Utilities/FFI/demo_ffi.vg
godot --headless --script demos/Utilities/FFI/demo_ffi_cpp_lib.vg
```

## Key FFI Concepts

- **`QuickCall(name, ...)`** — Convenience alias for simple calls. Prefer `CallFunction(...)` when the return type matters, especially for `double`, `string`, and `pointer` results.
- **`CallFunction(name, returnType, argTypes, args)`** — Full control. Required for `pointer`, `string`, and mixed-type signatures.
- **`NativeStruct`** — Define C struct layout in VG, allocate, read/write fields. For passing structs to C functions.

## Type Mapping

| VG Type     | C Type     | Notes |
|-------------|------------|-------|
| `"int"`     | `int`      | 32-bit signed |
| `"double"`  | `double`   | 64-bit float |
| `"float"`   | `float`    | 32-bit float |
| `"pointer"` | `void*`    | Pass/receive as int64 |
| `"string"`  | `char*`    | C string (null-terminated) |
| `"void"`    | `void`     | No return value |

## Security Note

Only load shared libraries you trust. FFI gives VG full native code execution access.
