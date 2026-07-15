// vg_json_typed.h
// Minimal JSON decoder that preserves int vs float distinction
// (unlike Godot's built-in JSON class, which always returns float).
//
// Only depends on godot-cpp types (String, Array, Dictionary, Variant).
// No external dependencies, no new Godot-exposed classes.

#ifndef VG_JSON_TYPED_H
#define VG_JSON_TYPED_H

#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

// Parse JSON text preserving int vs float distinction.
// Returns true on success; on failure, r_err_str is set and r_out is Variant().
bool vg_json_parse_typed(const String &p_json, Variant &r_out, String &r_err_str);

} // namespace godot

#endif // VG_JSON_TYPED_H
