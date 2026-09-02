// vg_msgpack.h — Minimal MessagePack encode/decode for Godot Variant types.
// Subset: nil, bool, int, float, string, array, map (string keys).
// Used by the Python bridge typed binary protocol (vg/python/use_typed_protocol).

#ifndef VG_MSGPACK_H
#define VG_MSGPACK_H

#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

bool vg_msgpack_encode(const Variant &p_value, PackedByteArray &r_out, String &r_err);
bool vg_msgpack_decode(const uint8_t *p_data, int p_len, Variant &r_out, String &r_err);

} // namespace godot

#endif // VG_MSGPACK_H
