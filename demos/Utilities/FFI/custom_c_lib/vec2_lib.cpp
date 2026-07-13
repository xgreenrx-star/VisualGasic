// vec2_lib.cpp
// Simple 2D vector library with C ABI — for FFI demo from VisualGasic
//
// Build:  g++ -shared -fPIC -o vec2.so vec2_lib.cpp -O2
// Usage:  see vec2_lib.h and demo_ffi_cpp_lib.vg

#include "vec2_lib.h"
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <string>

// ================================================================
// C++ implementation
// ================================================================

struct Vec2 {
    double x, y;
    Vec2(double x_, double y_) : x(x_), y(y_) {}
};

// ================================================================
// C ABI wrappers
// ================================================================

long long vec2_create(double x, double y) {
    Vec2 *v = new Vec2(x, y);
    return reinterpret_cast<long long>(v);
}

void vec2_destroy(long long ptr) {
    delete reinterpret_cast<Vec2 *>(ptr);
}

double vec2_get_x(long long ptr) {
    return reinterpret_cast<Vec2 *>(ptr)->x;
}

double vec2_get_y(long long ptr) {
    return reinterpret_cast<Vec2 *>(ptr)->y;
}

void vec2_set_x(long long ptr, double x) {
    reinterpret_cast<Vec2 *>(ptr)->x = x;
}

void vec2_set_y(long long ptr, double y) {
    reinterpret_cast<Vec2 *>(ptr)->y = y;
}

long long vec2_add(long long a, long long b) {
    Vec2 *va = reinterpret_cast<Vec2 *>(a);
    Vec2 *vb = reinterpret_cast<Vec2 *>(b);
    Vec2 *result = new Vec2(va->x + vb->x, va->y + vb->y);
    return reinterpret_cast<long long>(result);
}

long long vec2_sub(long long a, long long b) {
    Vec2 *va = reinterpret_cast<Vec2 *>(a);
    Vec2 *vb = reinterpret_cast<Vec2 *>(b);
    Vec2 *result = new Vec2(va->x - vb->x, va->y - vb->y);
    return reinterpret_cast<long long>(result);
}

long long vec2_scale(long long v, double s) {
    Vec2 *vv = reinterpret_cast<Vec2 *>(v);
    Vec2 *result = new Vec2(vv->x * s, vv->y * s);
    return reinterpret_cast<long long>(result);
}

double vec2_dot(long long a, long long b) {
    Vec2 *va = reinterpret_cast<Vec2 *>(a);
    Vec2 *vb = reinterpret_cast<Vec2 *>(b);
    return va->x * vb->x + va->y * vb->y;
}

double vec2_length(long long v) {
    Vec2 *vv = reinterpret_cast<Vec2 *>(v);
    return std::sqrt(vv->x * vv->x + vv->y * vv->y);
}

double vec2_length_squared(long long v) {
    Vec2 *vv = reinterpret_cast<Vec2 *>(v);
    return vv->x * vv->x + vv->y * vv->y;
}

int vec2_normalize(long long v) {
    Vec2 *vv = reinterpret_cast<Vec2 *>(v);
    double len = std::sqrt(vv->x * vv->x + vv->y * vv->y);
    if (len < 1e-15) return -1;  // zero vector
    vv->x /= len;
    vv->y /= len;
    return 0;
}

const char *vec2_to_string(long long v) {
    Vec2 *vv = reinterpret_cast<Vec2 *>(v);
    std::string s = "Vec2(" + std::to_string(vv->x) + ", " + std::to_string(vv->y) + ")";
    char *cstr = (char *)std::malloc(s.size() + 1);
    std::strcpy(cstr, s.c_str());
    return cstr;
}

const char *vec2_to_string_static(long long v) {
    static thread_local std::string s;
    Vec2 *vv = reinterpret_cast<Vec2 *>(v);
    s = "Vec2(" + std::to_string(vv->x) + ", " + std::to_string(vv->y) + ")";
    return s.c_str();
}

void vec2_free_string(const char *s) {
    std::free(const_cast<char *>(s));
}
