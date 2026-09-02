// vg_msgpack.cpp — Minimal MessagePack for Variant round-trip (Python bridge C2).

#include "vg_msgpack.h"

#include <cstdint>
#include <cstring>

namespace godot {

namespace {

struct MsgPackWriter {
	PackedByteArray &out;

	void write_u8(uint8_t v) { out.push_back(v); }

	void write_u16_le(uint16_t v) {
		write_u8((uint8_t)(v & 0xFF));
		write_u8((uint8_t)((v >> 8) & 0xFF));
	}

	void write_u32_le(uint32_t v) {
		write_u8((uint8_t)(v & 0xFF));
		write_u8((uint8_t)((v >> 8) & 0xFF));
		write_u8((uint8_t)((v >> 16) & 0xFF));
		write_u8((uint8_t)((v >> 24) & 0xFF));
	}

	void write_i64_le(int64_t v) {
		for (int i = 0; i < 8; i++) {
			write_u8((uint8_t)((v >> (i * 8)) & 0xFF));
		}
	}

	void write_f64(double v) {
		uint64_t bits;
		memcpy(&bits, &v, sizeof(bits));
		for (int i = 0; i < 8; i++) {
			write_u8((uint8_t)((bits >> (i * 8)) & 0xFF));
		}
	}

	void write_bytes(const uint8_t *data, int len) {
		for (int i = 0; i < len; i++) {
			out.push_back(data[i]);
		}
	}

	void write_string(const String &s) {
		CharString utf8 = s.utf8();
		int len = utf8.length();
		if (len <= 31) {
			write_u8((uint8_t)(0xA0 | len));
		} else if (len <= 0xFF) {
			write_u8(0xD9);
			write_u8((uint8_t)len);
		} else if (len <= 0xFFFF) {
			write_u8(0xDA);
			write_u16_le((uint16_t)len);
		} else {
			write_u8(0xDB);
			write_u32_le((uint32_t)len);
		}
		write_bytes((const uint8_t *)utf8.get_data(), len);
	}

	bool encode_value(const Variant &v);
};

struct MsgPackReader {
	const uint8_t *data;
	int len;
	int pos;

	bool at_end() const { return pos >= len; }

	bool read_u8(uint8_t &r) {
		if (pos >= len) return false;
		r = data[pos++];
		return true;
	}

	bool read_u16_le(uint16_t &r) {
		if (pos + 2 > len) return false;
		r = (uint16_t)data[pos] | ((uint16_t)data[pos + 1] << 8);
		pos += 2;
		return true;
	}

	bool read_u32_le(uint32_t &r) {
		if (pos + 4 > len) return false;
		r = (uint32_t)data[pos] | ((uint32_t)data[pos + 1] << 8) |
			((uint32_t)data[pos + 2] << 16) | ((uint32_t)data[pos + 3] << 24);
		pos += 4;
		return true;
	}

	bool read_i64_le(int64_t &r) {
		if (pos + 8 > len) return false;
		uint64_t bits = 0;
		for (int i = 0; i < 8; i++) {
			bits |= ((uint64_t)data[pos + i] << (i * 8));
		}
		pos += 8;
		memcpy(&r, &bits, sizeof(r));
		return true;
	}

	bool read_f64(double &r) {
		if (pos + 8 > len) return false;
		uint64_t bits = 0;
		for (int i = 0; i < 8; i++) {
			bits |= ((uint64_t)data[pos + i] << (i * 8));
		}
		pos += 8;
		memcpy(&r, &bits, sizeof(r));
		return true;
	}

	bool read_bytes(int count, String &r_out, String &r_err) {
		if (pos + count > len) {
			r_err = "Unexpected end while reading string";
			return false;
		}
		r_out = String::utf8((const char *)(data + pos), count);
		pos += count;
		return true;
	}

	bool decode_value(Variant &r_out, String &r_err);
};

bool MsgPackWriter::encode_value(const Variant &v) {
	switch (v.get_type()) {
		case Variant::NIL:
			write_u8(0xC0);
			return true;
		case Variant::BOOL:
			write_u8((bool)v ? 0xC3 : 0xC2);
			return true;
		case Variant::INT: {
			int64_t i = (int64_t)v;
			if (i >= 0 && i <= 127) {
				write_u8((uint8_t)i);
			} else if (i >= -32 && i < 0) {
				write_u8((uint8_t)(0xE0 | (int8_t)i));
			} else if (i >= INT8_MIN && i <= INT8_MAX) {
				write_u8(0xD0);
				write_u8((uint8_t)(int8_t)i);
			} else if (i >= INT16_MIN && i <= INT16_MAX) {
				write_u8(0xD1);
				write_u16_le((uint16_t)(int16_t)i);
			} else if (i >= INT32_MIN && i <= INT32_MAX) {
				write_u8(0xD2);
				write_u32_le((uint32_t)(int32_t)i);
			} else {
				write_u8(0xD3);
				write_i64_le(i);
			}
			return true;
		}
		case Variant::FLOAT: {
			write_u8(0xCB);
			write_f64((double)v);
			return true;
		}
		case Variant::STRING:
			write_string((String)v);
			return true;
		case Variant::ARRAY: {
			Array arr = v;
			int n = arr.size();
			if (n <= 15) {
				write_u8((uint8_t)(0x90 | n));
			} else if (n <= 0xFFFF) {
				write_u8(0xDC);
				write_u16_le((uint16_t)n);
			} else {
				write_u8(0xDD);
				write_u32_le((uint32_t)n);
			}
			for (int i = 0; i < n; i++) {
				if (!encode_value(arr[i])) return false;
			}
			return true;
		}
		case Variant::DICTIONARY: {
			Dictionary dict = v;
			Array keys = dict.keys();
			int n = keys.size();
			if (n <= 15) {
				write_u8((uint8_t)(0x80 | n));
			} else if (n <= 0xFFFF) {
				write_u8(0xDE);
				write_u16_le((uint16_t)n);
			} else {
				write_u8(0xDF);
				write_u32_le((uint32_t)n);
			}
			for (int i = 0; i < n; i++) {
				Variant key = keys[i];
				if (key.get_type() != Variant::STRING) {
					key = String(key);
				}
				if (!encode_value(key)) return false;
				if (!encode_value(dict[keys[i]])) return false;
			}
			return true;
		}
		default:
			// Fallback: stringify non-scalar types for transport safety.
			write_string(String(v));
			return true;
	}
}

bool MsgPackReader::decode_value(Variant &r_out, String &r_err) {
	if (at_end()) {
		r_err = "Unexpected end of msgpack payload";
		return false;
	}
	uint8_t tag = data[pos++];
	if (tag <= 0x7F) {
		r_out = Variant((int64_t)tag);
		return true;
	}
	if (tag >= 0xE0) {
		r_out = Variant((int64_t)(int8_t)tag);
		return true;
	}
	if (tag >= 0xA0 && tag <= 0xBF) {
		int slen = tag & 0x1F;
		String s;
		return read_bytes(slen, s, r_err) && (r_out = s, true);
	}
	if (tag >= 0x90 && tag <= 0x9F) {
		int n = tag & 0x0F;
		Array arr;
		for (int i = 0; i < n; i++) {
			Variant elem;
			if (!decode_value(elem, r_err)) return false;
			arr.push_back(elem);
		}
		r_out = arr;
		return true;
	}
	if (tag >= 0x80 && tag <= 0x8F) {
		int n = tag & 0x0F;
		Dictionary dict;
		for (int i = 0; i < n; i++) {
			Variant key;
			Variant val;
			if (!decode_value(key, r_err) || !decode_value(val, r_err)) return false;
			dict[key] = val;
		}
		r_out = dict;
		return true;
	}

	switch (tag) {
		case 0xC0:
			r_out = Variant();
			return true;
		case 0xC2:
			r_out = Variant(false);
			return true;
		case 0xC3:
			r_out = Variant(true);
			return true;
		case 0xD0: {
			uint8_t b;
			if (!read_u8(b)) { r_err = "Truncated int8"; return false; }
			r_out = Variant((int64_t)(int8_t)b);
			return true;
		}
		case 0xD1: {
			uint16_t u;
			if (!read_u16_le(u)) { r_err = "Truncated int16"; return false; }
			r_out = Variant((int64_t)(int16_t)u);
			return true;
		}
		case 0xD2: {
			uint32_t u;
			if (!read_u32_le(u)) { r_err = "Truncated int32"; return false; }
			r_out = Variant((int64_t)(int32_t)u);
			return true;
		}
		case 0xD3: {
			int64_t i;
			if (!read_i64_le(i)) { r_err = "Truncated int64"; return false; }
			r_out = Variant(i);
			return true;
		}
		case 0xCB: {
			double f;
			if (!read_f64(f)) { r_err = "Truncated float64"; return false; }
			r_out = Variant(f);
			return true;
		}
		case 0xD9: {
			uint8_t slen;
			if (!read_u8(slen)) { r_err = "Truncated str8"; return false; }
			String s;
			if (!read_bytes(slen, s, r_err)) return false;
			r_out = s;
			return true;
		}
		case 0xDA: {
			uint16_t slen;
			if (!read_u16_le(slen)) { r_err = "Truncated str16"; return false; }
			String s;
			if (!read_bytes(slen, s, r_err)) return false;
			r_out = s;
			return true;
		}
		case 0xDB: {
			uint32_t slen;
			if (!read_u32_le(slen)) { r_err = "Truncated str32"; return false; }
			if (slen > (uint32_t)0x7FFFFFFF) { r_err = "String too large"; return false; }
			String s;
			if (!read_bytes((int)slen, s, r_err)) return false;
			r_out = s;
			return true;
		}
		case 0xDC: {
			uint16_t n;
			if (!read_u16_le(n)) { r_err = "Truncated array16"; return false; }
			Array arr;
			for (int i = 0; i < (int)n; i++) {
				Variant elem;
				if (!decode_value(elem, r_err)) return false;
				arr.push_back(elem);
			}
			r_out = arr;
			return true;
		}
		case 0xDD: {
			uint32_t n;
			if (!read_u32_le(n)) { r_err = "Truncated array32"; return false; }
			if (n > (uint32_t)0x7FFFFFFF) { r_err = "Array too large"; return false; }
			Array arr;
			for (uint32_t i = 0; i < n; i++) {
				Variant elem;
				if (!decode_value(elem, r_err)) return false;
				arr.push_back(elem);
			}
			r_out = arr;
			return true;
		}
		case 0xDE: {
			uint16_t n;
			if (!read_u16_le(n)) { r_err = "Truncated map16"; return false; }
			Dictionary dict;
			for (int i = 0; i < (int)n; i++) {
				Variant key, val;
				if (!decode_value(key, r_err) || !decode_value(val, r_err)) return false;
				dict[key] = val;
			}
			r_out = dict;
			return true;
		}
		case 0xDF: {
			uint32_t n;
			if (!read_u32_le(n)) { r_err = "Truncated map32"; return false; }
			if (n > (uint32_t)0x7FFFFFFF) { r_err = "Map too large"; return false; }
			Dictionary dict;
			for (uint32_t i = 0; i < n; i++) {
				Variant key, val;
				if (!decode_value(key, r_err) || !decode_value(val, r_err)) return false;
				dict[key] = val;
			}
			r_out = dict;
			return true;
		}
		default:
			r_err = "Unsupported msgpack tag: 0x" + String::num_int64(tag, 16);
			return false;
	}
}

} // namespace

bool vg_msgpack_encode(const Variant &p_value, PackedByteArray &r_out, String &r_err) {
	r_out.clear();
	MsgPackWriter w{r_out};
	if (!w.encode_value(p_value)) {
		r_err = "Failed to encode Variant to msgpack";
		return false;
	}
	return true;
}

bool vg_msgpack_decode(const uint8_t *p_data, int p_len, Variant &r_out, String &r_err) {
	if (!p_data || p_len <= 0) {
		r_err = "Empty msgpack payload";
		return false;
	}
	MsgPackReader r{p_data, p_len, 0};
	if (!r.decode_value(r_out, r_err)) return false;
	if (r.pos != p_len) {
		r_err = "Trailing bytes in msgpack payload";
		return false;
	}
	return true;
}

} // namespace godot
