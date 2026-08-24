#include "visual_gasic_vgd_loader.h"
#include "visual_gasic_memory_buffer.h"

#include <godot_cpp/classes/file_access.hpp>

using namespace godot;

namespace VisualGasicVgd {

static uint32_t read_u32_le(const uint8_t *p) {
	return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

bool is_vgd_magic(const PackedByteArray &p_bytes) {
	return p_bytes.size() >= 4
			&& p_bytes[0] == 'V' && p_bytes[1] == 'G' && p_bytes[2] == 'D' && p_bytes[3] == 0x01;
}

bool parse_bytes(const PackedByteArray &p_bytes, Ref<VGMemoryBuffer> &r_buffer, VgdHeader &r_header, String &r_error) {
	r_error = "";
	r_header = VgdHeader();
	if (!is_vgd_magic(p_bytes)) {
		r_error = "Not a VGD file (expected magic VGD\\x01)";
		return false;
	}
	if (p_bytes.size() < 32) {
		r_error = "VGD header too short";
		return false;
	}
	const uint8_t *h = p_bytes.ptr();
	r_header.kind = (int)h[4];
	r_header.flags = (int)h[5];
	r_header.width = read_u32_le(h + 8);
	r_header.height = read_u32_le(h + 12);
	r_header.elem_size = h[16];
	r_header.palette_id = h[17];
	r_header.stride = read_u32_le(h + 20);
	r_header.payload_len = read_u32_le(h + 24);
	if (r_header.payload_len > 64 * 1024 * 1024) {
		r_error = "VGD payload too large (>64MB)";
		return false;
	}
	if (p_bytes.size() < 32 + (int)r_header.payload_len) {
		r_error = "VGD file truncated (payload shorter than header)";
		return false;
	}
	r_buffer.instantiate();
	if (!r_buffer->allocate((int64_t)r_header.payload_len)) {
		r_error = "VGD: could not allocate buffer: " + r_buffer->get_last_error();
		r_buffer.unref();
		return false;
	}
	if (r_header.payload_len > 0) {
		PackedByteArray payload = p_bytes.slice(32, 32 + (int)r_header.payload_len);
		r_buffer->from_byte_array(payload);
	}
	return true;
}

bool load_file(const String &p_path, Ref<VGMemoryBuffer> &r_buffer, VgdHeader &r_header, String &r_error) {
	Ref<FileAccess> f = FileAccess::open(p_path, FileAccess::READ);
	if (f.is_null()) {
		r_error = "Could not open file: " + p_path;
		return false;
	}
	PackedByteArray raw = f->get_buffer((int64_t)f->get_length());
	f->close();
	return parse_bytes(raw, r_buffer, r_header, r_error);
}

} // namespace VisualGasicVgd
