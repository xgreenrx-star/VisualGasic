#include "vg_variant_fast.h"
#include "vg_packed_cow.h"

#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/color.hpp>

using namespace godot;

namespace vgfast {

bool g_layout_ok = false;
bool g_string_layout_ok = false;

static bool verify_string_layout() {
    if (sizeof(String) != sizeof(uintptr_t)) {
        return false;
    }
    // Default / empty-literal strings must be the null pointer; a non-empty
    // one must not be.  Only "null ⇒ empty" is relied upon afterwards.
    String a;
    String b("x");
    String c("");
    String d = String("abc").substr(0, 0);
    uintptr_t pa, pb, pc, pd;
    memcpy(&pa, &a, sizeof(pa));
    memcpy(&pb, &b, sizeof(pb));
    memcpy(&pc, &c, sizeof(pc));
    memcpy(&pd, &d, sizeof(pd));
    if (pa != 0 || pb == 0) {
        return false;
    }
    // These may legitimately be null or not; whichever they are, is_empty()
    // must agree with the null test when it says "empty".
    if ((pc == 0 && !c.is_empty()) || (pd == 0 && !d.is_empty())) {
        return false;
    }
    return true;
}

static uint32_t raw_type(const Variant &v) {
    uint32_t t;
    memcpy(&t, &v, sizeof(t));
    return t;
}

bool verify_layout() {
    g_layout_ok = false;
    if (sizeof(Variant) != 24) {
        return false;
    }
    bool ok = true;

    // Type tag at offset 0.
    Variant v_nil;
    ok = ok && raw_type(v_nil) == (uint32_t)Variant::NIL;
    Variant v_bool(true);
    ok = ok && raw_type(v_bool) == (uint32_t)Variant::BOOL;
    Variant v_int((int64_t)0x1122334455667788LL);
    ok = ok && raw_type(v_int) == (uint32_t)Variant::INT;
    Variant v_float(1.5);
    ok = ok && raw_type(v_float) == (uint32_t)Variant::FLOAT;
    Variant v_str(String("x"));
    ok = ok && raw_type(v_str) == (uint32_t)Variant::STRING;
    Variant v_arr((Array()));
    ok = ok && raw_type(v_arr) == (uint32_t)Variant::ARRAY;
    Variant v_v3(Vector3(1.0f, 2.0f, 3.0f));
    ok = ok && raw_type(v_v3) == (uint32_t)Variant::VECTOR3;
    Variant v_col(Color(0.25f, 0.5f, 0.75f, 1.0f));
    ok = ok && raw_type(v_col) == (uint32_t)Variant::COLOR;

    // Inline payload at offset 8.
    const uint8_t *pi = reinterpret_cast<const uint8_t *>(&v_int) + PAYLOAD_OFFSET;
    int64_t i;
    memcpy(&i, pi, sizeof(i));
    ok = ok && i == 0x1122334455667788LL;
    const uint8_t *pf = reinterpret_cast<const uint8_t *>(&v_float) + PAYLOAD_OFFSET;
    double f;
    memcpy(&f, pf, sizeof(f));
    ok = ok && f == 1.5;
    const uint8_t *pb = reinterpret_cast<const uint8_t *>(&v_bool) + PAYLOAD_OFFSET;
    ok = ok && pb[0] == 1;
    Variant v_false(false);
    const uint8_t *pb0 = reinterpret_cast<const uint8_t *>(&v_false) + PAYLOAD_OFFSET;
    ok = ok && pb0[0] == 0;
    const uint8_t *pv = reinterpret_cast<const uint8_t *>(&v_v3) + PAYLOAD_OFFSET;
    float xyz[3];
    memcpy(xyz, pv, sizeof(xyz));
    ok = ok && xyz[0] == 1.0f && xyz[1] == 2.0f && xyz[2] == 3.0f;
    const uint8_t *pc = reinterpret_cast<const uint8_t *>(&v_col) + PAYLOAD_OFFSET;
    float rgba[4];
    memcpy(rgba, pc, sizeof(rgba));
    ok = ok && rgba[0] == 0.25f && rgba[1] == 0.5f && rgba[2] == 0.75f && rgba[3] == 1.0f;

    // Round-trip: a raw-written scalar must read back through the engine.
    if (ok) {
        Variant probe;
        g_layout_ok = true;   // enable the writers for the probe only
        set_int(probe, 42);
        ok = ok && probe.get_type() == Variant::INT && (int64_t)probe == 42;
        set_float(probe, 2.5);
        ok = ok && probe.get_type() == Variant::FLOAT && (double)probe == 2.5;
        set_bool(probe, true);
        ok = ok && probe.get_type() == Variant::BOOL && (bool)probe == true;
        Variant copy_dst;
        assign(copy_dst, v_v3);
        ok = ok && copy_dst.get_type() == Variant::VECTOR3 && (Vector3)copy_dst == Vector3(1.0f, 2.0f, 3.0f);
        g_layout_ok = false;
    }

    g_layout_ok = ok;
    if (!ok) {
        UtilityFunctions::print("[VG] Variant layout probe failed; using engine-call Variant paths.");
    }
    g_string_layout_ok = verify_string_layout();
    if (!g_string_layout_ok) {
        UtilityFunctions::print("[VG] String layout probe failed; using engine-call String paths.");
    }
    if (ok) {
        vgcow::verify();
    }
    return ok;
}

} // namespace vgfast
