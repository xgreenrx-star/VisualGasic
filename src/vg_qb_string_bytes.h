#ifndef VG_QB_STRING_BYTES_H
#define VG_QB_STRING_BYTES_H

#include <godot_cpp/variant/string.hpp>

// Godot String UTF-8 cannot hold U+0000 (logs "Unexpected NUL character").
// QBasic Chr(0) / INKEY$ extended prefix use this private-use code point instead.
namespace VGStringBytes {

static constexpr char32_t NUL_SENTINEL = 0xE000;

inline bool is_nul_sentinel(const godot::String &p_s) {
	return p_s.length() == 1 && p_s.unicode_at(0) == NUL_SENTINEL;
}

inline godot::String from_byte(int p_byte) {
	if (p_byte == 0) {
		return godot::String::chr(NUL_SENTINEL);
	}
	if (p_byte < 0 || p_byte > 255) {
		return godot::String();
	}
	return godot::String::chr(p_byte);
}

inline int to_byte(const godot::String &p_s) {
	if (p_s.is_empty()) {
		return 0;
	}
	char32_t cp = p_s.unicode_at(0);
	if (cp == NUL_SENTINEL) {
		return 0;
	}
	return (int)cp;
}

inline godot::String chr_qb(int p_code) {
	if (p_code == 0) {
		return godot::String::chr(NUL_SENTINEL);
	}
	if (p_code < 0 || p_code > 255) {
		return godot::String();
	}
	return godot::String::chr(p_code);
}

} // namespace VGStringBytes

#endif
