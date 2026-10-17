// ============================================================================
// Internal helpers shared between visual_gasic_instance*.cpp translation units
// ============================================================================
#ifndef VISUAL_GASIC_INSTANCE_INTERNAL_H
#define VISUAL_GASIC_INSTANCE_INTERNAL_H

#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/time.hpp>
#include <cstdlib>
#if defined(__x86_64__) || defined(_M_X64)
#include <x86intrin.h>
#endif

using namespace godot;

// ---------------------------------------------------------------------------
// Opcode profiling
// ---------------------------------------------------------------------------
enum class OpcodeProfileKind {
    GetMember = 0,
    SetMember,
    GetArray,
    SetArray,
    GetDict,
    SetDict,
    NewArray,
    NewDict,
    SumVGDictAll,
    COUNT
};

struct OpcodeProfileEntry {
    const char *name = "";
    uint64_t hit_count = 0;
    uint64_t total_time_us = 0;
};

inline bool vg_opcode_profile_enabled() {
    static bool initialized = false;
    static bool enabled = false;
    if (!initialized) {
        const char *env = std::getenv("VG_OPCODE_PROFILE");
        enabled = env && env[0] != '\0' && env[0] != '0';
        initialized = true;
    }
    return enabled;
}

inline OpcodeProfileEntry *vg_opcode_profiles_array() {
    static OpcodeProfileEntry profiles[(int)OpcodeProfileKind::COUNT] = {
        {"OP_GET_MEMBER", 0, 0},
        {"OP_SET_MEMBER", 0, 0},
        {"OP_GET_ARRAY", 0, 0},
        {"OP_SET_ARRAY", 0, 0},
        {"OP_GET_DICT", 0, 0},
        {"OP_SET_DICT", 0, 0},
        {"OP_NEW_ARRAY", 0, 0},
        {"OP_NEW_DICT", 0, 0},
        {"OP_SUM_VGDICT_ALL", 0, 0},
    };
    return profiles;
}

inline thread_local int vg_opcode_profile_depth = 0;

class OpcodeProfileScope {
public:
    explicit OpcodeProfileScope(OpcodeProfileKind p_kind) : kind(p_kind) {
        enabled = vg_opcode_profile_enabled();
        if (enabled && Time::get_singleton() != nullptr) {
            start_us = Time::get_singleton()->get_ticks_usec();
        } else {
            enabled = false;
        }
    }

    ~OpcodeProfileScope() {
        if (!enabled || Time::get_singleton() == nullptr) {
            return;
        }
        uint64_t end_us = Time::get_singleton()->get_ticks_usec();
        OpcodeProfileEntry &entry = vg_opcode_profiles_array()[(int)kind];
        entry.hit_count++;
        entry.total_time_us += (end_us - start_us);
    }

private:
    OpcodeProfileKind kind;
    uint64_t start_us = 0;
    bool enabled = false;
};

// Whole-dispatch-loop profile (VG_OPCODE_PROFILE=2): every executed opcode
// is bucketed by opcode byte with a TSC cycle count attributed to it, so the
// dump shows which opcodes a hot Sub actually spends its time in.  Nested
// execute_bytecode frames (OP_CALL) attribute the callee's whole run to the
// caller's OP_CALL bucket (inclusive), which is what you want when hunting
// call overhead.  Zero cost unless the env var is set (one well-predicted
// local-bool branch per opcode).
struct OpcodeFullProfileEntry {
    uint64_t hits = 0;
    uint64_t cycles = 0;
};

inline uint64_t vg_profile_tsc() {
#if defined(__x86_64__) || defined(_M_X64)
    return __rdtsc();
#else
    return (uint64_t)Time::get_singleton()->get_ticks_usec() * 1000ULL;
#endif
}

inline bool vg_opcode_full_profile_enabled() {
    static bool initialized = false;
    static bool enabled = false;
    if (!initialized) {
        const char *env = std::getenv("VG_OPCODE_PROFILE");
        enabled = env && env[0] == '2';
        initialized = true;
    }
    return enabled;
}

inline OpcodeFullProfileEntry *vg_opcode_full_profiles() {
    static OpcodeFullProfileEntry entries[256];
    return entries;
}

// Cycles spent in nested execute_bytecode frames, so a caller's OP_CALL
// bucket can be made EXCLUSIVE of the callee body (which is itself profiled
// opcode by opcode).  A frame sets this to entry_value + its own inclusive
// time on exit, so grandchildren are not double-subtracted.
inline uint64_t &vg_opcode_profile_nested_acc() {
    static thread_local uint64_t acc = 0;
    return acc;
}

String vg_opcode_name(uint8_t op);

// Per-Sub exclusive cycles (VG_OPCODE_PROFILE=2), keyed by Sub name.  Tells
// WHICH body the opcode table above is describing when a build has several
// hot loops.  Exclusive: a frame records (inclusive − nested callee time).
struct SubProfileEntry { uint64_t hits = 0, cycles = 0; };
inline HashMap<String, SubProfileEntry> &vg_sub_profiles() {
    static HashMap<String, SubProfileEntry> m;
    return m;
}
inline void vg_sub_profile_add(const String &name, uint64_t exclusive_cycles) {
    SubProfileEntry &e = vg_sub_profiles()[name];
    e.hits++;
    e.cycles += exclusive_cycles;
}
inline void sub_profile_dump() {
    HashMap<String, SubProfileEntry> &m = vg_sub_profiles();
    if (m.is_empty()) return;
    Vector<Pair<String, SubProfileEntry>> rows;
    uint64_t total = 0;
    for (const KeyValue<String, SubProfileEntry> &kv : m) {
        rows.push_back({ kv.key, kv.value });
        total += kv.value.cycles;
    }
    for (int i = 1; i < rows.size(); i++) {
        Pair<String, SubProfileEntry> k = rows[i]; int j = i - 1;
        while (j >= 0 && rows[j].second.cycles < k.second.cycles) { rows.write[j + 1] = rows[j]; j--; }
        rows.write[j + 1] = k;
    }
    UtilityFunctions::print("=== Bytecode Sub Profile (exclusive cycles) ===");
    for (int i = 0; i < rows.size() && i < 40; i++) {
        double pct = total ? 100.0 * (double)rows[i].second.cycles / (double)total : 0.0;
        if (pct < 0.05) break;
        UtilityFunctions::print(vformat("%6.2f%%  %-40s hits=%-8d Mcycles=%d",
                pct, rows[i].first, (int64_t)rows[i].second.hits,
                (int64_t)(rows[i].second.cycles / 1000000)));
    }
    m.clear();
}

inline void opcode_full_profile_dump() {
    OpcodeFullProfileEntry *e = vg_opcode_full_profiles();
    uint64_t total_cycles = 0, total_hits = 0;
    for (int i = 0; i < 256; i++) { total_cycles += e[i].cycles; total_hits += e[i].hits; }
    if (total_hits == 0) return;
    // Sort indices by cycles, descending (256 entries: insertion sort is fine).
    int order[256];
    for (int i = 0; i < 256; i++) order[i] = i;
    for (int i = 1; i < 256; i++) {
        int k = order[i]; int j = i - 1;
        while (j >= 0 && e[order[j]].cycles < e[k].cycles) { order[j + 1] = order[j]; j--; }
        order[j + 1] = k;
    }
    UtilityFunctions::print("=== Bytecode Opcode Profile (all opcodes, inclusive cycles) ===");
    UtilityFunctions::print(vformat("total_hits=%d total_Mcycles=%d", (int64_t)total_hits, (int64_t)(total_cycles / 1000000)));
    for (int i = 0; i < 256; i++) {
        int op = order[i];
        if (e[op].hits == 0) continue;
        double pct = total_cycles ? 100.0 * (double)e[op].cycles / (double)total_cycles : 0.0;
        if (pct < 0.05) break;
        UtilityFunctions::print(vformat("%6.2f%%  %-32s hits=%-10d avg_cycles=%d",
                pct, vg_opcode_name((uint8_t)op), (int64_t)e[op].hits,
                (int64_t)(e[op].cycles / e[op].hits)));
    }
    for (int i = 0; i < 256; i++) { e[i].hits = 0; e[i].cycles = 0; }
}

inline void opcode_profile_reset() {
    if (!vg_opcode_profile_enabled()) {
        return;
    }
    auto *profiles = vg_opcode_profiles_array();
    for (int i = 0; i < (int)OpcodeProfileKind::COUNT; i++) {
        profiles[i].hit_count = 0;
        profiles[i].total_time_us = 0;
    }
}

inline void opcode_profile_dump() {
    if (!vg_opcode_profile_enabled()) {
        return;
    }
    auto *profiles = vg_opcode_profiles_array();
    bool has_data = false;
    for (int i = 0; i < (int)OpcodeProfileKind::COUNT; i++) {
        if (profiles[i].hit_count > 0) {
            has_data = true;
            break;
        }
    }
    if (!has_data) {
        return;
    }
    UtilityFunctions::print("=== Bytecode Opcode Profile ===");
    for (int i = 0; i < (int)OpcodeProfileKind::COUNT; i++) {
        const OpcodeProfileEntry &entry = profiles[i];
        if (entry.hit_count == 0) {
            continue;
        }
        double average = (entry.hit_count > 0)
            ? ((double)entry.total_time_us / (double)entry.hit_count)
            : 0.0;
        UtilityFunctions::print(entry.name,
            " hits=", (int64_t)entry.hit_count,
            " total_us=", (int64_t)entry.total_time_us,
            " avg_us=", average);
    }
}

// ---------------------------------------------------------------------------
// Stack profiling
// ---------------------------------------------------------------------------
inline bool vg_stack_profile_enabled() {
    static bool initialized = false;
    static bool enabled = false;
    if (!initialized) {
        const char *env = std::getenv("VG_STACK_PROFILE");
        enabled = env && env[0] != '\0' && env[0] != '0';
        initialized = true;
    }
    return enabled;
}

struct StackProfileSample {
    uint64_t push_count = 0;
    uint64_t pop_count = 0;
    uint64_t underflow_count = 0;
    uint64_t max_depth = 0;
    uint64_t growth_events = 0;
};

inline void vg_stack_profile_dump(const StackProfileSample &sample, const String &label) {
    if (!vg_stack_profile_enabled()) {
        return;
    }
    UtilityFunctions::print("[VG_STACK] scope=", label,
        " pushes=", (int64_t)sample.push_count,
        " pops=", (int64_t)sample.pop_count,
        " underflows=", (int64_t)sample.underflow_count,
        " max_depth=", (int64_t)sample.max_depth,
        " growth_events=", (int64_t)sample.growth_events);
}

// ---------------------------------------------------------------------------
// Convenience macros
// ---------------------------------------------------------------------------
#define VG_CONCAT_IMPL(a, b) a##b
#define VG_CONCAT(a, b) VG_CONCAT_IMPL(a, b)
#define PROFILE_OPCODE(kind) OpcodeProfileScope VG_CONCAT(_vg_opcode_scope_, __COUNTER__)(OpcodeProfileKind::kind)

inline String vg_repeat_literal(const String &literal, int64_t count) {
    if (count <= 0 || literal.is_empty()) {
        return String();
    }
    return literal.repeat((int)count);
}

inline int64_t vg_loop_count(int64_t upper_bound) {
    return upper_bound >= 0 ? (upper_bound + 1) : 0;
}

// ---------------------------------------------------------------------------
// VB6-style Like pattern matching
// ---------------------------------------------------------------------------
// Pattern characters:
//   ? - matches any single character
//   * - matches zero or more characters
//   # - matches any single digit (0-9)
//   [charlist] - matches any single character in charlist
//   [!charlist] - matches any single character NOT in charlist
inline bool vb_like_match(const String& value, const String& pattern) {
    int v_len = value.length();
    int p_len = pattern.length();
    int v_idx = 0;
    int p_idx = 0;

    int star_p_idx = -1;
    int star_v_idx = -1;

    while (v_idx < v_len) {
        if (p_idx < p_len) {
            char32_t p_char = pattern[p_idx];

            if (p_char == '?') { v_idx++; p_idx++; continue; }

            if (p_char == '#') {
                char32_t v_char = value[v_idx];
                if (v_char >= '0' && v_char <= '9') { v_idx++; p_idx++; continue; }
                if (star_p_idx >= 0) { p_idx = star_p_idx + 1; star_v_idx++; v_idx = star_v_idx; continue; }
                return false;
            }

            if (p_char == '*') { star_p_idx = p_idx; star_v_idx = v_idx; p_idx++; continue; }

            if (p_char == '[') {
                p_idx++;
                bool negate = false;
                if (p_idx < p_len && pattern[p_idx] == '!') { negate = true; p_idx++; }
                int bracket_start = p_idx;
                while (p_idx < p_len && pattern[p_idx] != ']') p_idx++;
                if (p_idx >= p_len) {
                    if (star_p_idx >= 0) { p_idx = star_p_idx + 1; star_v_idx++; v_idx = star_v_idx; continue; }
                    return false;
                }
                String charlist = pattern.substr(bracket_start, p_idx - bracket_start);
                p_idx++;
                char32_t v_char = value[v_idx];
                bool found = false;
                for (int i = 0; i < charlist.length(); i++) {
                    if (i + 2 < charlist.length() && charlist[i + 1] == '-') {
                        if (v_char >= charlist[i] && v_char <= charlist[i + 2]) { found = true; break; }
                        i += 2;
                    } else {
                        if (charlist[i] == v_char) { found = true; break; }
                    }
                }
                bool matches = negate ? !found : found;
                if (matches) { v_idx++; continue; }
                if (star_p_idx >= 0) { p_idx = star_p_idx + 1; star_v_idx++; v_idx = star_v_idx; continue; }
                return false;
            }

            char32_t v_char = value[v_idx];
            char32_t p_lower = (p_char >= 'A' && p_char <= 'Z') ? p_char + 32 : p_char;
            char32_t v_lower = (v_char >= 'A' && v_char <= 'Z') ? v_char + 32 : v_char;
            if (p_lower == v_lower) { v_idx++; p_idx++; continue; }
        }
        if (star_p_idx >= 0) { p_idx = star_p_idx + 1; star_v_idx++; v_idx = star_v_idx; continue; }
        return false;
    }
    while (p_idx < p_len && pattern[p_idx] == '*') p_idx++;
    return p_idx == p_len;
}

#endif // VISUAL_GASIC_INSTANCE_INTERNAL_H
