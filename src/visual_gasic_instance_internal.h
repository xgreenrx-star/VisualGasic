// ============================================================================
// Internal helpers shared between visual_gasic_instance*.cpp translation units
// ============================================================================
#ifndef VISUAL_GASIC_INSTANCE_INTERNAL_H
#define VISUAL_GASIC_INSTANCE_INTERNAL_H

#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/time.hpp>
#include <cstdlib>

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
