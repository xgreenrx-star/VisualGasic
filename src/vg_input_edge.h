#ifndef VG_INPUT_EDGE_H
#define VG_INPUT_EDGE_H

#include <godot_cpp/classes/global_constants.hpp>

namespace godot {

class VGInputEdge {
public:
	// Godot 4 Input Map stores arrows/WASD as physical_keycode with keycode=0.
	// is_key_pressed() misses those; also check is_physical_key_pressed().
	static bool is_key_down(Key p_key);
	static bool is_key_just_pressed(Key p_key);
	static bool is_key_just_released(Key p_key);
};

} // namespace godot

#endif // VG_INPUT_EDGE_H
