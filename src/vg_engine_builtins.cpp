#include "vg_engine_builtins.h"

#include <godot_cpp/templates/hash_map.hpp>

using namespace godot;

namespace {

struct BuiltinEntry {
	String name;
	Variant value;
};

static Vector<BuiltinEntry> &builtin_entries() {
	static Vector<BuiltinEntry> entries;
	static bool ready = false;
	if (ready) {
		return entries;
	}
	ready = true;

	auto add_int = [&](const String &name, int v) {
		BuiltinEntry e;
		e.name = name;
		e.value = Variant(v);
		entries.push_back(e);
	};

	// VB6-style key aliases (mirrors VisualGasicInstance::builtin_constants).
	add_int("vbKeyReturn", (int)Key::KEY_ENTER);
	add_int("vbKeyEnter", (int)Key::KEY_ENTER);
	add_int("vbKeySpace", (int)Key::KEY_SPACE);
	add_int("vbKeyEscape", (int)Key::KEY_ESCAPE);
	add_int("vbKeyUp", (int)Key::KEY_UP);
	add_int("vbKeyDown", (int)Key::KEY_DOWN);
	add_int("vbKeyLeft", (int)Key::KEY_LEFT);
	add_int("vbKeyRight", (int)Key::KEY_RIGHT);
	add_int("vbKeyBack", (int)Key::KEY_BACKSPACE);
	add_int("vbKeyTab", (int)Key::KEY_TAB);
	add_int("vbKeyDelete", (int)Key::KEY_DELETE);
	add_int("vbKeyInsert", (int)Key::KEY_INSERT);
	add_int("vbKeyHome", (int)Key::KEY_HOME);
	add_int("vbKeyEnd", (int)Key::KEY_END);
	add_int("vbKeyPageUp", (int)Key::KEY_PAGEUP);
	add_int("vbKeyPageDown", (int)Key::KEY_PAGEDOWN);
	add_int("vbKeyShift", (int)Key::KEY_SHIFT);
	add_int("vbKeyControl", (int)Key::KEY_CTRL);
	add_int("vbKeyMenu", (int)Key::KEY_ALT);
	add_int("vbKeyF1", (int)Key::KEY_F1);
	add_int("vbKeyF2", (int)Key::KEY_F2);
	add_int("vbKeyF3", (int)Key::KEY_F3);
	add_int("vbKeyF4", (int)Key::KEY_F4);
	add_int("vbKeyF5", (int)Key::KEY_F5);
	add_int("vbKeyF6", (int)Key::KEY_F6);
	add_int("vbKeyF7", (int)Key::KEY_F7);
	add_int("vbKeyF8", (int)Key::KEY_F8);
	add_int("vbKeyF9", (int)Key::KEY_F9);
	add_int("vbKeyF10", (int)Key::KEY_F10);
	add_int("vbKeyF11", (int)Key::KEY_F11);
	add_int("vbKeyF12", (int)Key::KEY_F12);
	add_int("vbKeyA", (int)Key::KEY_A);
	add_int("vbKeyB", (int)Key::KEY_B);
	add_int("vbKeyC", (int)Key::KEY_C);
	add_int("vbKeyD", (int)Key::KEY_D);
	add_int("vbKeyE", (int)Key::KEY_E);
	add_int("vbKeyF", (int)Key::KEY_F);
	add_int("vbKeyG", (int)Key::KEY_G);
	add_int("vbKeyH", (int)Key::KEY_H);
	add_int("vbKeyI", (int)Key::KEY_I);
	add_int("vbKeyJ", (int)Key::KEY_J);
	add_int("vbKeyK", (int)Key::KEY_K);
	add_int("vbKeyL", (int)Key::KEY_L);
	add_int("vbKeyM", (int)Key::KEY_M);
	add_int("vbKeyN", (int)Key::KEY_N);
	add_int("vbKeyO", (int)Key::KEY_O);
	add_int("vbKeyP", (int)Key::KEY_P);
	add_int("vbKeyQ", (int)Key::KEY_Q);
	add_int("vbKeyR", (int)Key::KEY_R);
	add_int("vbKeyS", (int)Key::KEY_S);
	add_int("vbKeyT", (int)Key::KEY_T);
	add_int("vbKeyU", (int)Key::KEY_U);
	add_int("vbKeyV", (int)Key::KEY_V);
	add_int("vbKeyW", (int)Key::KEY_W);
	add_int("vbKeyX", (int)Key::KEY_X);
	add_int("vbKeyY", (int)Key::KEY_Y);
	add_int("vbKeyZ", (int)Key::KEY_Z);
	for (int d = 0; d <= 9; d++) {
		add_int(String("vbKey") + String::num_int64(d), (int)Key::KEY_0 + d);
	}

	// Godot-style KEY_* (Input / _Input keycode comparisons).
	add_int("KEY_NONE", (int)Key::KEY_NONE);
	add_int("KEY_SPACE", (int)Key::KEY_SPACE);
	add_int("KEY_ENTER", (int)Key::KEY_ENTER);
	add_int("KEY_ESCAPE", (int)Key::KEY_ESCAPE);
	add_int("KEY_TAB", (int)Key::KEY_TAB);
	add_int("KEY_BACKSPACE", (int)Key::KEY_BACKSPACE);
	add_int("KEY_DELETE", (int)Key::KEY_DELETE);
	add_int("KEY_INSERT", (int)Key::KEY_INSERT);
	add_int("KEY_HOME", (int)Key::KEY_HOME);
	add_int("KEY_END", (int)Key::KEY_END);
	add_int("KEY_PAGEUP", (int)Key::KEY_PAGEUP);
	add_int("KEY_PAGEDOWN", (int)Key::KEY_PAGEDOWN);
	add_int("KEY_UP", (int)Key::KEY_UP);
	add_int("KEY_DOWN", (int)Key::KEY_DOWN);
	add_int("KEY_LEFT", (int)Key::KEY_LEFT);
	add_int("KEY_RIGHT", (int)Key::KEY_RIGHT);
	add_int("KEY_SHIFT", (int)Key::KEY_SHIFT);
	add_int("KEY_CTRL", (int)Key::KEY_CTRL);
	add_int("KEY_ALT", (int)Key::KEY_ALT);
	add_int("KEY_CAPSLOCK", (int)Key::KEY_CAPSLOCK);
	add_int("KEY_A", (int)Key::KEY_A);
	add_int("KEY_B", (int)Key::KEY_B);
	add_int("KEY_C", (int)Key::KEY_C);
	add_int("KEY_D", (int)Key::KEY_D);
	add_int("KEY_E", (int)Key::KEY_E);
	add_int("KEY_F", (int)Key::KEY_F);
	add_int("KEY_G", (int)Key::KEY_G);
	add_int("KEY_H", (int)Key::KEY_H);
	add_int("KEY_I", (int)Key::KEY_I);
	add_int("KEY_J", (int)Key::KEY_J);
	add_int("KEY_K", (int)Key::KEY_K);
	add_int("KEY_L", (int)Key::KEY_L);
	add_int("KEY_M", (int)Key::KEY_M);
	add_int("KEY_N", (int)Key::KEY_N);
	add_int("KEY_O", (int)Key::KEY_O);
	add_int("KEY_P", (int)Key::KEY_P);
	add_int("KEY_Q", (int)Key::KEY_Q);
	add_int("KEY_R", (int)Key::KEY_R);
	add_int("KEY_S", (int)Key::KEY_S);
	add_int("KEY_T", (int)Key::KEY_T);
	add_int("KEY_U", (int)Key::KEY_U);
	add_int("KEY_V", (int)Key::KEY_V);
	add_int("KEY_W", (int)Key::KEY_W);
	add_int("KEY_X", (int)Key::KEY_X);
	add_int("KEY_Y", (int)Key::KEY_Y);
	add_int("KEY_Z", (int)Key::KEY_Z);
	for (int d = 0; d <= 9; d++) {
		add_int(String("KEY_") + String::num_int64(d), (int)Key::KEY_0 + d);
	}
	add_int("KEY_F1", (int)Key::KEY_F1);
	add_int("KEY_F2", (int)Key::KEY_F2);
	add_int("KEY_F3", (int)Key::KEY_F3);
	add_int("KEY_F4", (int)Key::KEY_F4);
	add_int("KEY_F5", (int)Key::KEY_F5);
	add_int("KEY_F6", (int)Key::KEY_F6);
	add_int("KEY_F7", (int)Key::KEY_F7);
	add_int("KEY_F8", (int)Key::KEY_F8);
	add_int("KEY_F9", (int)Key::KEY_F9);
	add_int("KEY_F10", (int)Key::KEY_F10);
	add_int("KEY_F11", (int)Key::KEY_F11);
	add_int("KEY_F12", (int)Key::KEY_F12);
	add_int("KEY_KP_ENTER", (int)Key::KEY_KP_ENTER);
	for (int d = 0; d <= 9; d++) {
		add_int(String("KEY_KP_") + String::num_int64(d), (int)Key::KEY_KP_0 + d);
	}

	return entries;
}

static HashMap<String, Variant> &builtin_lookup() {
	static HashMap<String, Variant> map;
	static bool ready = false;
	if (ready) {
		return map;
	}
	ready = true;
	for (const BuiltinEntry &e : builtin_entries()) {
		map[e.name] = e.value;
	}
	return map;
}

} // namespace

void vg_populate_engine_key_builtin_constants(Dictionary &r_out) {
	for (const BuiltinEntry &e : builtin_entries()) {
		r_out[e.name] = e.value;
	}
}

void vg_register_engine_builtin_non_local_names(HashSet<String> &r_names) {
	for (const KeyValue<String, Variant> &kv : builtin_lookup()) {
		r_names.insert(kv.key.to_lower());
	}
}

bool vg_try_engine_builtin_constant(const String &p_name, Variant &r_out) {
	const HashMap<String, Variant> &map = builtin_lookup();
	if (map.has(p_name)) {
		r_out = map[p_name];
		return true;
	}
	String upper = p_name.to_upper();
	if (map.has(upper)) {
		r_out = map[upper];
		return true;
	}
	return false;
}
