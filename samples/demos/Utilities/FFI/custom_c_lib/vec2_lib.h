#ifndef VEC2_LIB_H
#define VEC2_LIB_H

#ifdef __cplusplus
extern "C" {
#endif

/* ================================================================
 * Simple 2D vector library — C ABI interface
 *
 * Demonstrates calling C++ code from VisualGasic via FFI.
 * Compile with:
 *   g++ -shared -fPIC -o vec2.so vec2_lib.cpp -O2
 *
 * VG usage:
 *   Dim lib = New NativeLibrary
 *   lib.Load("vec2.so")
 *   Dim v = lib.CallSimple("vec2_create", Array(3.0, 4.0))
 *   Dim len = lib.CallFunction("vec2_length", "double", Array("pointer"), Array(v))
 * ================================================================ */

/* Create a new Vec2, returns pointer as int64 */
long long vec2_create(double x, double y);

/* Destroy a Vec2 (free memory) */
void vec2_destroy(long long ptr);

/* Get/set components */
double vec2_get_x(long long ptr);
double vec2_get_y(long long ptr);
void   vec2_set_x(long long ptr, double x);
void   vec2_set_y(long long ptr, double y);

/* Math operations — return new vectors */
long long vec2_add(long long a, long long b);
long long vec2_sub(long long a, long long b);
long long vec2_scale(long long v, double s);

/* Dot product, length, normalize */
double vec2_dot(long long a, long long b);
double vec2_length(long long v);
double vec2_length_squared(long long v);

/* Normalize in-place. Returns 0 on success, -1 on zero-vector. */
int vec2_normalize(long long v);

/* String representation (caller must free with vec2_free_string) */
const char *vec2_to_string(long long v);
const char *vec2_to_string_static(long long v);
void vec2_free_string(const char *s);

#ifdef __cplusplus
}
#endif

#endif /* VEC2_LIB_H */
