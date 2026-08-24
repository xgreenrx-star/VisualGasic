#ifndef VISUAL_GASIC_VGD_LOADER_H
#define VISUAL_GASIC_VGD_LOADER_H

#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/classes/ref_counted.hpp>

using namespace godot;

class VGMemoryBuffer;

struct VgdHeader {
	int kind = 0;
	int flags = 0;
	uint32_t width = 0;
	uint32_t height = 0;
	uint8_t elem_size = 1;
	uint8_t palette_id = 255;
	uint32_t stride = 0;
	uint32_t payload_len = 0;
};

namespace VisualGasicVgd {

bool is_vgd_magic(const PackedByteArray &p_bytes);
bool parse_bytes(const PackedByteArray &p_bytes, Ref<VGMemoryBuffer> &r_buffer, VgdHeader &r_header, String &r_error);
bool load_file(const String &p_path, Ref<VGMemoryBuffer> &r_buffer, VgdHeader &r_header, String &r_error);

} // namespace VisualGasicVgd

#endif
