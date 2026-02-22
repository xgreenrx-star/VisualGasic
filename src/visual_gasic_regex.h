// VGRegEx — VBScript.RegExp emulation
// Wraps Godot's RegEx class with VB6-style API

#ifndef VISUAL_GASIC_REGEX_H
#define VISUAL_GASIC_REGEX_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/reg_ex.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>

namespace godot {

// VGRegExMatch — individual match result
class VGRegExMatch : public RefCounted {
    GDCLASS(VGRegExMatch, RefCounted)

protected:
    static void _bind_methods();

public:
    VGRegExMatch();

    String get_value() const;
    void set_value(const String &p_value);
    int get_first_index() const;
    void set_first_index(int p_index);
    int get_length() const;
    void set_length(int p_length);
    Array get_sub_matches() const;
    void set_sub_matches(const Array &p_matches);

private:
    String value;
    int first_index;
    int length;
    Array sub_matches;
};

// VGRegEx — main regexp object
class VGRegEx : public RefCounted {
    GDCLASS(VGRegEx, RefCounted)

protected:
    static void _bind_methods();

public:
    VGRegEx();
    ~VGRegEx();

    // VBScript.RegExp API
    void set_pattern(const String &p_pattern);
    String get_pattern() const;
    void set_global(bool p_global);
    bool get_global() const;
    void set_ignore_case(bool p_ignore);
    bool get_ignore_case() const;
    void set_multiline(bool p_multiline);
    bool get_multiline() const;

    bool test(const String &p_string);
    Array execute(const String &p_string);
    String replace(const String &p_string, const String &p_replacement);

private:
    String pattern;
    bool global;
    bool ignore_case;
    bool multiline;

    void compile_regex();
    Ref<RegEx> regex;
    bool dirty;
};

} // namespace godot

#endif // VISUAL_GASIC_REGEX_H
