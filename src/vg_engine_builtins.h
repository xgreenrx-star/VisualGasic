#ifndef VG_ENGINE_BUILTINS_H
#define VG_ENGINE_BUILTINS_H

#include <godot_cpp/templates/hash_set.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>

using namespace godot;

// Godot Key / VB6 vbKey* names shared by the VM (builtin_constants) and compiler.
void vg_populate_engine_key_builtin_constants(Dictionary &r_out);
void vg_register_engine_builtin_non_local_names(HashSet<String> &r_names);
bool vg_try_engine_builtin_constant(const String &p_name, Variant &r_out);
inline bool vg_has_engine_builtin_constant(const String &p_name) {
	Variant ignored;
	return vg_try_engine_builtin_constant(p_name, ignored);
}

#endif
