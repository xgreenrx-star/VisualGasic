#ifndef VG_INPUT_EDGE_H
#define VG_INPUT_EDGE_H

#include <godot_cpp/classes/global_constants.hpp>

namespace godot {

class VGInputEdge {
public:
	static bool is_key_just_pressed(Key p_key);
	static bool is_key_just_released(Key p_key);
};

} // namespace godot

#endif // VG_INPUT_EDGE_H
