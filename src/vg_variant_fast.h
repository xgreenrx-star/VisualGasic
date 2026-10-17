// ============================================================================
// vg_variant_fast.h — engine-call-free Variant primitives for the VM hot path
//
// Every godot-cpp Variant operation (get_type, copy, assign, bool/int/float
// extraction) is an out-of-line call through the GDExtension interface table.
// The bytecode VM issues several of them per opcode, and on call/geometry-
// heavy code they were the dominant cost (perf: ~43% of samples inside the
// Godot binary, mostly Variant plumbing).
//
// Godot 4 lays a Variant out as { Type type; <pad>; union _data } — the type
// tag is the first 32 bits and the inline payload (bool / int64 / double /
// Vector2-4 / Color / ...) starts at byte 8.  That layout is not part of the
// written GDExtension contract, so it is VERIFIED ONCE at module init
// (vg_variant_fast_verify_layout) against the live engine: the inline paths
// are only taken while the probe passed, otherwise every helper falls back to
// the ordinary godot-cpp call.  All reads/writes go through memcpy (no type
// punning).
// ============================================================================
#ifndef VG_VARIANT_FAST_H
#define VG_VARIANT_FAST_H

#include <godot_cpp/variant/variant.hpp>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <new>
#include <utility>
#include <vector>

namespace vgfast {

// Set by vg_variant_fast_verify_layout(); false until proven.
extern bool g_layout_ok;

// Probe the live engine's Variant layout.  Call once, after the GDExtension
// interface is bound (module init).  Returns the verdict.
bool verify_layout();

static constexpr int PAYLOAD_OFFSET = 8;

// Types whose payload lives inline in the Variant and needs no deinit — a
// raw 24-byte copy is a complete, correct copy (mirrors Godot's needs_deinit[]).
static constexpr uint64_t POD_MASK =
        (1ull << godot::Variant::NIL) | (1ull << godot::Variant::BOOL) |
        (1ull << godot::Variant::INT) | (1ull << godot::Variant::FLOAT) |
        (1ull << godot::Variant::VECTOR2) | (1ull << godot::Variant::VECTOR2I) |
        (1ull << godot::Variant::RECT2) | (1ull << godot::Variant::RECT2I) |
        (1ull << godot::Variant::VECTOR3) | (1ull << godot::Variant::VECTOR3I) |
        (1ull << godot::Variant::VECTOR4) | (1ull << godot::Variant::VECTOR4I) |
        (1ull << godot::Variant::PLANE) | (1ull << godot::Variant::QUATERNION) |
        (1ull << godot::Variant::COLOR) | (1ull << godot::Variant::RID);

inline godot::Variant::Type vtype(const godot::Variant &v) {
    if (g_layout_ok) {
        uint32_t t;
        memcpy(&t, &v, sizeof(t));
        return (godot::Variant::Type)t;
    }
    return v.get_type();
}

inline bool is_pod_type(godot::Variant::Type t) {
    return (unsigned)t < 64u && ((POD_MASK >> (unsigned)t) & 1ull) != 0;
}

// Raw payload readers — caller must have checked vtype() first.
inline int64_t vint(const godot::Variant &v) {
    if (g_layout_ok) {
        int64_t x;
        memcpy(&x, reinterpret_cast<const uint8_t *>(&v) + PAYLOAD_OFFSET, sizeof(x));
        return x;
    }
    return (int64_t)v;
}
inline double vfloat(const godot::Variant &v) {
    if (g_layout_ok) {
        double x;
        memcpy(&x, reinterpret_cast<const uint8_t *>(&v) + PAYLOAD_OFFSET, sizeof(x));
        return x;
    }
    return (double)v;
}
inline bool vbool(const godot::Variant &v) {
    if (g_layout_ok) {
        uint8_t b;
        memcpy(&b, reinterpret_cast<const uint8_t *>(&v) + PAYLOAD_OFFSET, sizeof(b));
        return b != 0;
    }
    return (bool)v;
}

// dst = src without an engine round-trip when BOTH sides hold inline,
// deinit-free payloads (nothing to release in dst, nothing to retain in src).
inline void assign(godot::Variant &dst, const godot::Variant &src) {
    if (g_layout_ok && is_pod_type(vtype(src)) && is_pod_type(vtype(dst))) {
        memcpy(&dst, &src, sizeof(godot::Variant));
        return;
    }
    dst = src;
}

// Overwrite dst (which must currently hold a POD payload, e.g. a freshly
// default-constructed NIL) with a typed scalar — no from_type_constructor call.
inline void set_int(godot::Variant &dst, int64_t value) {
    if (g_layout_ok && is_pod_type(vtype(dst))) {
        uint8_t *p = reinterpret_cast<uint8_t *>(&dst);
        memset(p, 0, sizeof(godot::Variant));
        const uint32_t t = (uint32_t)godot::Variant::INT;
        memcpy(p, &t, sizeof(t));
        memcpy(p + PAYLOAD_OFFSET, &value, sizeof(value));
        return;
    }
    dst = godot::Variant(value);
}
inline void set_float(godot::Variant &dst, double value) {
    if (g_layout_ok && is_pod_type(vtype(dst))) {
        uint8_t *p = reinterpret_cast<uint8_t *>(&dst);
        memset(p, 0, sizeof(godot::Variant));
        const uint32_t t = (uint32_t)godot::Variant::FLOAT;
        memcpy(p, &t, sizeof(t));
        memcpy(p + PAYLOAD_OFFSET, &value, sizeof(value));
        return;
    }
    dst = godot::Variant(value);
}
inline void set_bool(godot::Variant &dst, bool value) {
    if (g_layout_ok && is_pod_type(vtype(dst))) {
        uint8_t *p = reinterpret_cast<uint8_t *>(&dst);
        memset(p, 0, sizeof(godot::Variant));
        const uint32_t t = (uint32_t)godot::Variant::BOOL;
        memcpy(p, &t, sizeof(t));
        const uint8_t b = value ? 1 : 0;
        memcpy(p + PAYLOAD_OFFSET, &b, sizeof(b));
        return;
    }
    dst = godot::Variant(value);
}

// Write a scalar into raw storage (uninitialised bytes, or a slot known to
// hold a POD payload).  No from_type_constructor call.
inline void raw_init_int(godot::Variant *p, int64_t value) {
    if (g_layout_ok) {
        uint8_t *b = reinterpret_cast<uint8_t *>(p);
        memset(b, 0, sizeof(godot::Variant));
        const uint32_t t = (uint32_t)godot::Variant::INT;
        memcpy(b, &t, sizeof(t));
        memcpy(b + PAYLOAD_OFFSET, &value, sizeof(value));
        return;
    }
    new (p) godot::Variant(value);
}
inline void raw_init_float(godot::Variant *p, double value) {
    if (g_layout_ok) {
        uint8_t *b = reinterpret_cast<uint8_t *>(p);
        memset(b, 0, sizeof(godot::Variant));
        const uint32_t t = (uint32_t)godot::Variant::FLOAT;
        memcpy(b, &t, sizeof(t));
        memcpy(b + PAYLOAD_OFFSET, &value, sizeof(value));
        return;
    }
    new (p) godot::Variant(value);
}
inline void raw_init_bool(godot::Variant *p, bool value) {
    if (g_layout_ok) {
        uint8_t *b = reinterpret_cast<uint8_t *>(p);
        memset(b, 0, sizeof(godot::Variant));
        const uint32_t t = (uint32_t)godot::Variant::BOOL;
        memcpy(b, &t, sizeof(t));
        const uint8_t bv = value ? 1 : 0;
        memcpy(b + PAYLOAD_OFFSET, &bv, sizeof(bv));
        return;
    }
    new (p) godot::Variant(value);
}
// Inline float-tuple payloads (Vector2 / Vector3 / Color): verify_layout()
// checks that their components sit at PAYLOAD_OFFSET as consecutive floats.
inline void raw_init_vector2(godot::Variant *p, const godot::Vector2 &value) {
    if (g_layout_ok) {
        uint8_t *b = reinterpret_cast<uint8_t *>(p);
        memset(b, 0, sizeof(godot::Variant));
        const uint32_t t = (uint32_t)godot::Variant::VECTOR2;
        memcpy(b, &t, sizeof(t));
        const float xy[2] = { (float)value.x, (float)value.y };
        memcpy(b + PAYLOAD_OFFSET, xy, sizeof(xy));
        return;
    }
    new (p) godot::Variant(value);
}
inline void raw_init_vector3(godot::Variant *p, const godot::Vector3 &value) {
    if (g_layout_ok) {
        uint8_t *b = reinterpret_cast<uint8_t *>(p);
        memset(b, 0, sizeof(godot::Variant));
        const uint32_t t = (uint32_t)godot::Variant::VECTOR3;
        memcpy(b, &t, sizeof(t));
        const float xyz[3] = { (float)value.x, (float)value.y, (float)value.z };
        memcpy(b + PAYLOAD_OFFSET, xyz, sizeof(xyz));
        return;
    }
    new (p) godot::Variant(value);
}
inline void raw_init_color(godot::Variant *p, const godot::Color &value) {
    if (g_layout_ok) {
        uint8_t *b = reinterpret_cast<uint8_t *>(p);
        memset(b, 0, sizeof(godot::Variant));
        const uint32_t t = (uint32_t)godot::Variant::COLOR;
        memcpy(b, &t, sizeof(t));
        const float rgba[4] = { value.r, value.g, value.b, value.a };
        memcpy(b + PAYLOAD_OFFSET, rgba, sizeof(rgba));
        return;
    }
    new (p) godot::Variant(value);
}

// INT or FLOAT payload as a double — caller has checked vtype() is one of
// the two.  No to_type_constructor call.
inline double vnum(const godot::Variant &v) {
    return vtype(v) == godot::Variant::FLOAT ? vfloat(v) : (double)vint(v);
}
// Inline float-tuple readers — caller has checked vtype().
inline godot::Vector2 vvec2(const godot::Variant &v) {
    if (g_layout_ok) {
        float xy[2];
        memcpy(xy, reinterpret_cast<const uint8_t *>(&v) + PAYLOAD_OFFSET, sizeof(xy));
        return godot::Vector2(xy[0], xy[1]);
    }
    return (godot::Vector2)v;
}
inline godot::Vector3 vvec3(const godot::Variant &v) {
    if (g_layout_ok) {
        float xyz[3];
        memcpy(xyz, reinterpret_cast<const uint8_t *>(&v) + PAYLOAD_OFFSET, sizeof(xyz));
        return godot::Vector3(xyz[0], xyz[1], xyz[2]);
    }
    return (godot::Vector3)v;
}
inline godot::Color vcolor(const godot::Variant &v) {
    if (g_layout_ok) {
        float rgba[4];
        memcpy(rgba, reinterpret_cast<const uint8_t *>(&v) + PAYLOAD_OFFSET, sizeof(rgba));
        return godot::Color(rgba[0], rgba[1], rgba[2], rgba[3]);
    }
    return (godot::Color)v;
}

// Operand stack for the bytecode VM.  Drop-in for the std::vector<Variant>
// subset the VM uses (size/[]/back/begin/end/push_back/pop_back/resize), but:
//   * pushing an inline-payload Variant (int/float/bool/Vector3/Color/...) is a
//     24-byte copy, not a variant_new_copy engine call;
//   * popping one is a size decrement, not a variant_destroy engine call;
//   * push_int/push_float/push_bool build the Variant in place (no
//     from_type_constructor call);
//   * growth relocates elements bytewise, exactly as Godot's own
//     CowData<Variant>::_realloc does (Variant holds no self-pointers).
// Non-POD elements (String/Array/Object/...) go through the ordinary Variant
// copy constructor / destructor, so refcounts stay exact.  The element type is
// still godot::Variant, so every opcode handler compiles unchanged.
class VariantStack {
public:
    using value_type = godot::Variant;
    using iterator = godot::Variant *;
    using const_iterator = const godot::Variant *;

    VariantStack() = default;
    VariantStack(const VariantStack &) = delete;
    VariantStack &operator=(const VariantStack &) = delete;
    ~VariantStack() {
        resize(0);
        free(_data);
    }

    size_t size() const { return _size; }
    bool empty() const { return _size == 0; }
    godot::Variant &operator[](size_t i) { return _data[i]; }
    const godot::Variant &operator[](size_t i) const { return _data[i]; }
    godot::Variant &back() { return _data[_size - 1]; }
    const godot::Variant &back() const { return _data[_size - 1]; }
    iterator begin() { return _data; }
    iterator end() { return _data + _size; }
    const_iterator begin() const { return _data; }
    const_iterator end() const { return _data + _size; }

    void reserve(size_t n) {
        if (n > _cap) _grow(n);
    }
    void push_back(const godot::Variant &v) {
        if (_size == _cap) _grow(_size + 1);
        godot::Variant *slot = _data + _size;
        if (is_pod_type(vtype(v))) {
            memcpy(slot, &v, sizeof(godot::Variant));
        } else {
            new (slot) godot::Variant(v);
        }
        _size++;
    }
    // Takes ownership; `v` is left NIL (same observable result as godot-cpp's
    // swap-with-zeroed-block move constructor).
    void push_back(godot::Variant &&v) {
        if (_size == _cap) _grow(_size + 1);
        memcpy(_data + _size, &v, sizeof(godot::Variant));
        memset(&v, 0, sizeof(godot::Variant));
        _size++;
    }
    template <typename T>
    void emplace_back(T &&v) {
        push_back(godot::Variant(std::forward<T>(v)));
    }
    void push_int(int64_t v) {
        if (_size == _cap) _grow(_size + 1);
        raw_init_int(_data + _size, v);
        _size++;
    }
    void push_float(double v) {
        if (_size == _cap) _grow(_size + 1);
        raw_init_float(_data + _size, v);
        _size++;
    }
    void push_bool(bool v) {
        if (_size == _cap) _grow(_size + 1);
        raw_init_bool(_data + _size, v);
        _size++;
    }
    void pop_back() {
        _size--;
        godot::Variant &v = _data[_size];
        if (!is_pod_type(vtype(v))) v.~Variant();
    }
    // Move the top element into `dst` (any valid Variant), then drop it.
    void pop_into(godot::Variant &dst) {
        _size--;
        if (!is_pod_type(vtype(dst))) dst.~Variant();
        memcpy(&dst, _data + _size, sizeof(godot::Variant));
    }
    void resize(size_t n) {
        if (n < _size) {
            for (size_t i = n; i < _size; i++) {
                if (!is_pod_type(vtype(_data[i]))) _data[i].~Variant();
            }
            _size = n;
        } else if (n > _size) {
            if (n > _cap) _grow(n);
            memset(_data + _size, 0, (n - _size) * sizeof(godot::Variant)); // NIL
            _size = n;
        }
    }
    void clear() { resize(0); }

private:
    void _grow(size_t min_cap) {
        size_t new_cap = _cap ? _cap * 2 : 64;
        if (new_cap < min_cap) new_cap = min_cap;
        godot::Variant *nd = static_cast<godot::Variant *>(malloc(new_cap * sizeof(godot::Variant)));
        if (_size) memcpy(nd, _data, _size * sizeof(godot::Variant));
        free(_data);
        _data = nd;
        _cap = new_cap;
    }
    godot::Variant *_data = nullptr;
    size_t _size = 0;
    size_t _cap = 0;
};

// Fixed-capacity argument buffer.  A plain `Variant buf[N]` costs N engine
// new_nil calls on entry and N destroy calls on exit even when only two
// slots are used; this constructs exactly `count` elements, in any order,
// and destroys only those.  Counts above N spill to a std::vector.
template <int N>
struct VariantBuf {
    alignas(godot::Variant) uint8_t raw[N * sizeof(godot::Variant)];
    std::vector<godot::Variant> heap;
    godot::Variant *ptr = nullptr;
    int count = 0;
    bool inline_storage = true;

    explicit VariantBuf(int n) : count(n) {
        if (n <= N) {
            ptr = reinterpret_cast<godot::Variant *>(raw);
        } else {
            inline_storage = false;
            heap.resize(n);
            ptr = heap.data();
        }
    }
    VariantBuf(const VariantBuf &) = delete;
    VariantBuf &operator=(const VariantBuf &) = delete;
    ~VariantBuf() {
        if (inline_storage) {
            for (int i = 0; i < count; i++) {
                // Inline payloads have nothing to release (Godot's own
                // Variant::clear is a no-op for them); skip the engine call.
                if (!is_pod_type(vtype(ptr[i]))) ptr[i].~Variant();
            }
        }
    }
    // Take ownership of `v` (leaves it NIL).  Move-construction is a byte swap
    // against the zero-initialised opaque block — no engine call.
    void construct_move(int i, godot::Variant &&v) {
        if (inline_storage) {
            new (&ptr[i]) godot::Variant(std::move(v));
        } else {
            ptr[i] = std::move(v);
        }
    }
    // Copy `v` in; inline payloads are a raw copy, everything else retains
    // through the engine copy constructor.
    void construct_copy(int i, const godot::Variant &v) {
        if (inline_storage) {
            if (g_layout_ok && is_pod_type(vtype(v))) {
                memcpy(&ptr[i], &v, sizeof(godot::Variant));
            } else {
                new (&ptr[i]) godot::Variant(v);
            }
        } else {
            assign(ptr[i], v);
        }
    }
};

// ── godot::String helpers ───────────────────────────────────────────────────
// A godot String is one CowData pointer (8 bytes).  godot-cpp's default
// constructor, copy constructor, destructor, operator= and is_empty() are ALL
// out-of-line engine calls; only the move operations are a pointer swap.  A
// null pointer is always the empty string (verified at init, see
// verify_layout); a non-null pointer may or may not be empty.
extern bool g_string_layout_ok;

// True when `s` is certainly empty, without an engine call.  False means
// "unknown" — callers that need an exact answer fall through to is_empty().
inline bool str_is_null(const godot::String &s) {
    if (!g_string_layout_ok) return false;
    uintptr_t p;
    memcpy(&p, &s, sizeof(p));
    return p == 0;
}
inline bool str_empty(const godot::String &s) {
    return str_is_null(s) || s.is_empty();
}

// A String slot that costs nothing unless a value is stored in it.  Replaces
// `String saved = member;` save/restore pairs on the call path, which paid a
// copy + an assign + a destroy engine call even when both sides were empty.
class OptString {
public:
    OptString() = default;
    OptString(const OptString &) = delete;
    OptString &operator=(const OptString &) = delete;
    ~OptString() { reset(); }

    bool engaged() const { return _has; }
    godot::String &get() { return *ptr(); }
    const godot::String &get() const { return *ptr(); }

    void reset() {
        if (_has) {
            ptr()->~String();
            _has = false;
        }
    }
    void set_copy(const godot::String &s) {
        reset();
        new (_raw) godot::String(s);
        _has = true;
    }
    void set_move(godot::String &&s) {
        reset();
        new (_raw) godot::String(std::move(s));
        _has = true;
    }
    // Save `src` only when it is (possibly) non-empty.
    void save_if_set(const godot::String &src) {
        if (!str_is_null(src)) set_copy(src);
    }
    // Put the saved value back into `dst` (the slot stays engaged, so this
    // can run more than once); an unsaved slot restores "empty", touching
    // dst only if it is not already empty.
    void restore_into(godot::String &dst) const {
        if (_has) {
            dst = *ptr();
        } else if (!str_is_null(dst)) {
            godot::String empty;
            dst = std::move(empty);
        }
    }
    // Move the saved value into `dst` (slot disengaged); same empty rule.
    void move_into(godot::String &dst) {
        if (_has) {
            dst = std::move(*ptr());   // pointer swap
            ptr()->~String();          // releases dst's previous contents
            _has = false;
        } else if (!str_is_null(dst)) {
            godot::String empty;
            dst = std::move(empty);
        }
    }

private:
    godot::String *ptr() { return reinterpret_cast<godot::String *>(_raw); }
    const godot::String *ptr() const { return reinterpret_cast<const godot::String *>(_raw); }
    alignas(godot::String) uint8_t _raw[sizeof(godot::String)];
    bool _has = false;
};

} // namespace vgfast

#endif // VG_VARIANT_FAST_H
