#include "vg_autoloads.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/classes/window.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/node_path.hpp>
#include <godot_cpp/variant/typed_array.hpp>

using namespace godot;

namespace {

HashMap<String, String> vg_autoload_lower_to_name;
HashSet<String> vg_autoload_names_lower;
bool vg_autoload_loaded = false;

void vg_autoload_load() {
	vg_autoload_lower_to_name.clear();
	vg_autoload_names_lower.clear();
	ProjectSettings *ps = ProjectSettings::get_singleton();
	if (!ps) {
		vg_autoload_loaded = true;
		return;
	}
	TypedArray<Dictionary> props = ps->get_property_list();
	for (int i = 0; i < props.size(); i++) {
		Dictionary p = props[i];
		String pname = p["name"];
		if (!pname.begins_with("autoload/")) {
			continue;
		}
		String ident = pname.substr(String("autoload/").length());
		if (ident.is_empty()) {
			continue;
		}
		String lower = ident.to_lower();
		vg_autoload_lower_to_name[lower] = ident;
		vg_autoload_names_lower.insert(lower);
	}
	vg_autoload_loaded = true;
}

} // namespace

namespace VGAutoloads {

void refresh() {
	vg_autoload_loaded = false;
	vg_autoload_load();
}

const HashSet<String> &names_lower() {
	if (!vg_autoload_loaded) {
		vg_autoload_load();
	}
	return vg_autoload_names_lower;
}

Node *get_node(const String &p_name) {
	if (!vg_autoload_loaded) {
		vg_autoload_load();
	}
	if (p_name.is_empty()) {
		return nullptr;
	}
	String lower = p_name.to_lower();
	if (!vg_autoload_lower_to_name.has(lower)) {
		return nullptr;
	}
	String ident = vg_autoload_lower_to_name[lower];
	Engine *eng = Engine::get_singleton();
	if (!eng) {
		return nullptr;
	}
	SceneTree *tree = Object::cast_to<SceneTree>(eng->get_main_loop());
	if (!tree) {
		return nullptr;
	}
	Window *root = tree->get_root();
	if (!root) {
		return nullptr;
	}
	Node *n = root->get_node_or_null(NodePath(ident));
	if (n) {
		return n;
	}
	return root->find_child(ident, false, false);
}

} // namespace VGAutoloads
