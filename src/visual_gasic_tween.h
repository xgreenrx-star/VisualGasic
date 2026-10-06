#ifndef VISUAL_GASIC_TWEEN_H
#define VISUAL_GASIC_TWEEN_H

#include <godot_cpp/variant/string.hpp>

inline godot::String vg_tween_property_path(const godot::String &p_property) {
	if (p_property.nocasecmp_to("Left") == 0) return "position:x";
	if (p_property.nocasecmp_to("Top") == 0) return "position:y";
	if (p_property.nocasecmp_to("Width") == 0) return "size:x";
	if (p_property.nocasecmp_to("Height") == 0) return "size:y";
	if (p_property.nocasecmp_to("Caption") == 0) return "text";
	return p_property.to_lower();
}

#endif
