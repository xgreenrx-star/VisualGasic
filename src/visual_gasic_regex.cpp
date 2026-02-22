// VGRegEx — VBScript.RegExp emulation
// Wraps Godot's RegEx class with VB6-style API

#include "visual_gasic_regex.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/reg_ex_match.hpp>

using namespace godot;

// ===========================================================================
// VGRegExMatch — individual match result
// ===========================================================================

void VGRegExMatch::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_value"), &VGRegExMatch::get_value);
    ClassDB::bind_method(D_METHOD("get_first_index"), &VGRegExMatch::get_first_index);
    ClassDB::bind_method(D_METHOD("get_length"), &VGRegExMatch::get_length);
    ClassDB::bind_method(D_METHOD("get_sub_matches"), &VGRegExMatch::get_sub_matches);

    // VB6-style aliases
    ClassDB::bind_method(D_METHOD("Value"), &VGRegExMatch::get_value);
    ClassDB::bind_method(D_METHOD("FirstIndex"), &VGRegExMatch::get_first_index);
    ClassDB::bind_method(D_METHOD("Length"), &VGRegExMatch::get_length);
    ClassDB::bind_method(D_METHOD("SubMatches"), &VGRegExMatch::get_sub_matches);

    ADD_PROPERTY(PropertyInfo(Variant::STRING, "Value"), "", "get_value");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "FirstIndex"), "", "get_first_index");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "Length"), "", "get_length");
}

VGRegExMatch::VGRegExMatch() : first_index(0), length(0) {}

String VGRegExMatch::get_value() const { return value; }
void VGRegExMatch::set_value(const String &p_value) { value = p_value; }
int VGRegExMatch::get_first_index() const { return first_index; }
void VGRegExMatch::set_first_index(int p_index) { first_index = p_index; }
int VGRegExMatch::get_length() const { return length; }
void VGRegExMatch::set_length(int p_length) { length = p_length; }
Array VGRegExMatch::get_sub_matches() const { return sub_matches; }
void VGRegExMatch::set_sub_matches(const Array &p_matches) { sub_matches = p_matches; }

// ===========================================================================
// VGRegEx — main regexp object
// ===========================================================================

void VGRegEx::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_pattern", "pattern"), &VGRegEx::set_pattern);
    ClassDB::bind_method(D_METHOD("get_pattern"), &VGRegEx::get_pattern);
    ClassDB::bind_method(D_METHOD("set_global", "global"), &VGRegEx::set_global);
    ClassDB::bind_method(D_METHOD("get_global"), &VGRegEx::get_global);
    ClassDB::bind_method(D_METHOD("set_ignore_case", "ignore"), &VGRegEx::set_ignore_case);
    ClassDB::bind_method(D_METHOD("get_ignore_case"), &VGRegEx::get_ignore_case);
    ClassDB::bind_method(D_METHOD("set_multiline", "multiline"), &VGRegEx::set_multiline);
    ClassDB::bind_method(D_METHOD("get_multiline"), &VGRegEx::get_multiline);
    ClassDB::bind_method(D_METHOD("test", "string"), &VGRegEx::test);
    ClassDB::bind_method(D_METHOD("execute", "string"), &VGRegEx::execute);
    ClassDB::bind_method(D_METHOD("replace", "string", "replacement"), &VGRegEx::replace);

    // VB6-style aliases
    ClassDB::bind_method(D_METHOD("Test", "string"), &VGRegEx::test);
    ClassDB::bind_method(D_METHOD("Execute", "string"), &VGRegEx::execute);
    ClassDB::bind_method(D_METHOD("Replace", "string", "replacement"), &VGRegEx::replace);

    ADD_PROPERTY(PropertyInfo(Variant::STRING, "Pattern"), "set_pattern", "get_pattern");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "Global"), "set_global", "get_global");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "IgnoreCase"), "set_ignore_case", "get_ignore_case");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "Multiline"), "set_multiline", "get_multiline");
}

VGRegEx::VGRegEx() {
    global = false;
    ignore_case = false;
    multiline = false;
    dirty = true;
    regex.instantiate();
}

VGRegEx::~VGRegEx() {}

void VGRegEx::set_pattern(const String &p_pattern) {
    pattern = p_pattern;
    dirty = true;
}

String VGRegEx::get_pattern() const { return pattern; }

void VGRegEx::set_global(bool p_global) {
    global = p_global;
}

bool VGRegEx::get_global() const { return global; }

void VGRegEx::set_ignore_case(bool p_ignore) {
    ignore_case = p_ignore;
    dirty = true;
}

bool VGRegEx::get_ignore_case() const { return ignore_case; }

void VGRegEx::set_multiline(bool p_multiline) {
    multiline = p_multiline;
    dirty = true;
}

bool VGRegEx::get_multiline() const { return multiline; }

void VGRegEx::compile_regex() {
    if (!dirty) return;
    dirty = false;

    if (pattern.is_empty()) return;

    // Build PCRE2 flags prefix
    String full_pattern;
    if (ignore_case && multiline) {
        full_pattern = String("(?im)") + pattern;
    } else if (ignore_case) {
        full_pattern = String("(?i)") + pattern;
    } else if (multiline) {
        full_pattern = String("(?m)") + pattern;
    } else {
        full_pattern = pattern;
    }

    Error err = regex->compile(full_pattern);
    if (err != OK) {
        UtilityFunctions::printerr("[VGRegEx] Invalid pattern: ", pattern);
    }
}

bool VGRegEx::test(const String &p_string) {
    compile_regex();
    if (!regex->is_valid()) return false;
    Ref<RegExMatch> m = regex->search(p_string);
    return m.is_valid();
}

Array VGRegEx::execute(const String &p_string) {
    compile_regex();
    Array results;
    if (!regex->is_valid()) return results;

    if (global) {
        // Return all matches
        TypedArray<RegExMatch> matches = regex->search_all(p_string);
        for (int i = 0; i < matches.size(); i++) {
            Ref<RegExMatch> m = matches[i];
            if (!m.is_valid()) continue;

            Ref<VGRegExMatch> vm;
            vm.instantiate();
            vm->set_value(m->get_string(0));
            vm->set_first_index(m->get_start(0));
            vm->set_length(m->get_end(0) - m->get_start(0));

            // Sub-matches (capture groups)
            Array subs;
            for (int g = 1; g <= m->get_group_count(); g++) {
                subs.push_back(m->get_string(g));
            }
            vm->set_sub_matches(subs);
            results.push_back(vm);
        }
    } else {
        // Return first match only
        Ref<RegExMatch> m = regex->search(p_string);
        if (m.is_valid()) {
            Ref<VGRegExMatch> vm;
            vm.instantiate();
            vm->set_value(m->get_string(0));
            vm->set_first_index(m->get_start(0));
            vm->set_length(m->get_end(0) - m->get_start(0));

            Array subs;
            for (int g = 1; g <= m->get_group_count(); g++) {
                subs.push_back(m->get_string(g));
            }
            vm->set_sub_matches(subs);
            results.push_back(vm);
        }
    }

    return results;
}

String VGRegEx::replace(const String &p_string, const String &p_replacement) {
    compile_regex();
    if (!regex->is_valid()) return p_string;

    if (global) {
        return regex->sub(p_string, p_replacement, true);
    } else {
        return regex->sub(p_string, p_replacement, false);
    }
}
