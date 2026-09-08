#ifndef VG_GODOT_OWNER_BUILTINS_H
#define VG_GODOT_OWNER_BUILTINS_H

#include "visual_gasic_instance.h"
#include <godot_cpp/variant/variant.hpp>

namespace godot {

class VGGodotOwnerBuiltins {
public:
	// Global / owner-relative Godot node, scene, input, and engine builtins.
	// Handles PascalCase and snake_case spellings documented in the reference.
	static bool try_call(VisualGasicInstance *instance, const String &p_method, const Array &p_args, bool &r_handled, Variant &r_ret);
};

} // namespace godot

#endif // VG_GODOT_OWNER_BUILTINS_H
