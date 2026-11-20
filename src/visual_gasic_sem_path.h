#pragma once
// Opt-in semantic-fuzz path evidence. Enabled only when VG_SEM_PATH=1.
// Hot path when disabled: a single cached getenv check — callers must guard
// ownership/normalize work with path_enabled() before building strings.
//
// Event shape (defining module resource path):
//   VG_SEM_PATH path=<tier> fn=<name> mod="<encoded>"
// Encoding is reversible percent-style: '%'→%25, '"'→%22, LF→%0A, CR→%0D.
// Decode left-to-right %XX. Untagged (no mod) lines remain valid for Phase 1.

#include <cstdlib>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace vgsem {

inline bool path_enabled() {
	static int cached = -1;
	if (cached < 0) {
		const char *env = std::getenv("VG_SEM_PATH");
		cached = (env && env[0] == '1' && env[1] == '\0') ? 1 : 0;
	}
	return cached == 1;
}

inline godot::String encode_mod(const godot::String &mod) {
	godot::String out;
	const int n = mod.length();
	for (int i = 0; i < n; i++) {
		const char32_t c = mod[i];
		if (c == U'%') {
			out += "%25";
		} else if (c == U'"') {
			out += "%22";
		} else if (c == U'\n') {
			out += "%0A";
		} else if (c == U'\r') {
			out += "%0D";
		} else {
			out += godot::String::chr(c);
		}
	}
	return out;
}

inline void note(const char *path, const godot::String &fn, const godot::String &mod = godot::String()) {
	if (!path_enabled()) {
		return;
	}
	if (mod.is_empty()) {
		godot::UtilityFunctions::print("VG_SEM_PATH path=", path, " fn=", fn);
		return;
	}
	godot::UtilityFunctions::print(
			"VG_SEM_PATH path=", path, " fn=", fn, " mod=\"", encode_mod(mod), "\"");
}

inline void note(const char *path, const char *fn, const godot::String &mod = godot::String()) {
	note(path, godot::String(fn), mod);
}

} // namespace vgsem
