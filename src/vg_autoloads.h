#ifndef VG_AUTOLOADS_H
#define VG_AUTOLOADS_H

#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/templates/hash_set.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {
class Node;
}

namespace VGAutoloads {
	// Lowercased autoload identifiers from ProjectSettings ("autoload/Name").
	const godot::HashSet<godot::String> &names_lower();
	// Resolve an identifier to the autoload Node under /root, or nullptr.
	godot::Node *get_node(const godot::String &p_name);
	void refresh();
}

#endif // VG_AUTOLOADS_H
