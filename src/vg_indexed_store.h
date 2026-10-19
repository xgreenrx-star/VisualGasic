#ifndef VG_INDEXED_STORE_H
#define VG_INDEXED_STORE_H

// Element store into an Array or any Packed*Array held by a Variant, shared
// by the bytecode VM and the AST walker so `arr(i) = v` behaves the same on
// every tier.  The write goes straight into the Variant's own storage: a
// packed buffer is copied only when another Variant still shares it.

#include "vg_variant_fast.h"
#include "vg_packed_cow.h"
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/variant_internal.hpp>
#include <godot_cpp/variant/vector4.hpp>

namespace vgidx {

using namespace godot;

enum StoreResult {
	STORE_OK = 0,
	STORE_OUT_OF_RANGE,
	STORE_UNSUPPORTED,
	STORE_TYPE_MISMATCH,
};

inline bool is_sequence(Variant::Type t) {
	return t == Variant::ARRAY || (t >= Variant::PACKED_BYTE_ARRAY && t <= Variant::PACKED_VECTOR4_ARRAY);
}

// Same coercion as the VM's to_int (VB Integer from Variant).
inline int64_t vb_int(const Variant &v) {
	switch (v.get_type()) {
		case Variant::INT:
			return (int64_t)v;
		case Variant::FLOAT:
			return (int64_t)(double)v;
		case Variant::BOOL:
			return (bool)v ? 1 : 0;
		case Variant::STRING:
			return ((String)v).to_int();
		default:
			return (int64_t)v;
	}
}

template <typename P>
inline bool in_range(const P *a, int64_t idx) {
	return idx >= 0 && idx < a->size();
}

inline void bytes_to_variant(Variant::Type packed, const uint8_t *buf, Variant &out) {
	switch (packed) {
		case Variant::PACKED_BYTE_ARRAY:
			vgfast::raw_init_int(&out, (int64_t)buf[0]);
			return;
		case Variant::PACKED_INT32_ARRAY: {
			int32_t x;
			memcpy(&x, buf, 4);
			vgfast::raw_init_int(&out, (int64_t)x);
			return;
		}
		case Variant::PACKED_INT64_ARRAY: {
			int64_t x;
			memcpy(&x, buf, 8);
			vgfast::raw_init_int(&out, x);
			return;
		}
		case Variant::PACKED_FLOAT32_ARRAY: {
			float x;
			memcpy(&x, buf, 4);
			vgfast::raw_init_float(&out, (double)x);
			return;
		}
		case Variant::PACKED_FLOAT64_ARRAY: {
			double x;
			memcpy(&x, buf, 8);
			vgfast::raw_init_float(&out, x);
			return;
		}
		case Variant::PACKED_VECTOR2_ARRAY: {
			float xy[2];
			memcpy(xy, buf, 8);
			vgfast::raw_init_vector2(&out, Vector2(xy[0], xy[1]));
			return;
		}
		case Variant::PACKED_VECTOR3_ARRAY: {
			float xyz[3];
			memcpy(xyz, buf, 12);
			vgfast::raw_init_vector3(&out, Vector3(xyz[0], xyz[1], xyz[2]));
			return;
		}
		case Variant::PACKED_COLOR_ARRAY: {
			float rgba[4];
			memcpy(rgba, buf, 16);
			vgfast::raw_init_color(&out, Color(rgba[0], rgba[1], rgba[2], rgba[3]));
			return;
		}
		case Variant::PACKED_VECTOR4_ARRAY: {
			if (vgfast::g_layout_ok) {
				uint8_t *b = reinterpret_cast<uint8_t *>(&out);
				memset(b, 0, sizeof(Variant));
				const uint32_t tag = (uint32_t)Variant::VECTOR4;
				memcpy(b, &tag, 4);
				memcpy(b + vgfast::PAYLOAD_OFFSET, buf, 16);
				return;
			}
			break;
		}
		default:
			break;
	}
}

inline bool variant_to_bytes(Variant::Type packed, const Variant &value, uint8_t *buf) {
	const Variant::Type vt = vgfast::vtype(value);
	switch (packed) {
		case Variant::PACKED_BYTE_ARRAY:
			if (vt != Variant::INT && vt != Variant::FLOAT && vt != Variant::BOOL) return false;
			buf[0] = (uint8_t)vb_int(value);
			return true;
		case Variant::PACKED_INT32_ARRAY: {
			if (vt != Variant::INT && vt != Variant::FLOAT && vt != Variant::BOOL) return false;
			int32_t x = (int32_t)vb_int(value);
			memcpy(buf, &x, 4);
			return true;
		}
		case Variant::PACKED_INT64_ARRAY: {
			if (vt != Variant::INT && vt != Variant::FLOAT && vt != Variant::BOOL) return false;
			int64_t x = vb_int(value);
			memcpy(buf, &x, 8);
			return true;
		}
		case Variant::PACKED_FLOAT32_ARRAY: {
			if (vt != Variant::INT && vt != Variant::FLOAT) return false;
			float x = (float)(vt == Variant::FLOAT ? vgfast::vfloat(value) : (double)vgfast::vint(value));
			memcpy(buf, &x, 4);
			return true;
		}
		case Variant::PACKED_FLOAT64_ARRAY: {
			if (vt != Variant::INT && vt != Variant::FLOAT) return false;
			double x = vt == Variant::FLOAT ? vgfast::vfloat(value) : (double)vgfast::vint(value);
			memcpy(buf, &x, 8);
			return true;
		}
		case Variant::PACKED_VECTOR2_ARRAY: {
			if (vt != Variant::VECTOR2 && vt != Variant::VECTOR2I) return false;
			const Vector2 v = vt == Variant::VECTOR2 ? vgfast::vvec2(value) : Vector2((Vector2i)value);
			const float xy[2] = { (float)v.x, (float)v.y };
			memcpy(buf, xy, 8);
			return true;
		}
		case Variant::PACKED_VECTOR3_ARRAY: {
			if (vt != Variant::VECTOR3 && vt != Variant::VECTOR3I) return false;
			const Vector3 v = vt == Variant::VECTOR3 ? vgfast::vvec3(value) : Vector3((Vector3i)value);
			const float xyz[3] = { (float)v.x, (float)v.y, (float)v.z };
			memcpy(buf, xyz, 12);
			return true;
		}
		case Variant::PACKED_COLOR_ARRAY: {
			if (vt != Variant::COLOR) return false;
			const Color c = vgfast::vcolor(value);
			const float rgba[4] = { c.r, c.g, c.b, c.a };
			memcpy(buf, rgba, 16);
			return true;
		}
		case Variant::PACKED_VECTOR4_ARRAY: {
			if (vt != Variant::VECTOR4 && vt != Variant::VECTOR4I) return false;
			if (vt == Variant::VECTOR4 && vgfast::g_layout_ok) {
				memcpy(buf, reinterpret_cast<const uint8_t *>(&value) + vgfast::PAYLOAD_OFFSET, 16);
				return true;
			}
			const Vector4 v = vt == Variant::VECTOR4 ? (Vector4)value : Vector4((Vector4i)value);
			const float xyzw[4] = { (float)v.x, (float)v.y, (float)v.z, (float)v.w };
			memcpy(buf, xyzw, 16);
			return true;
		}
		default:
			return false;
	}
}

// In-place CowData size writes are not safe. The offset is probed on one
// Vector3 array, then reused while arrays grow and share buffers. That
// write lands off the size field and corrupts the heap (mismatched mesh
// attribute lengths, then malloc abort). Packed ops use the engine path.
inline bool cow_layout_for(Variant::Type t) {
	(void)t;
	return false;
}

inline StoreResult cow_load(Variant &seq, int64_t idx, Variant &out) {
	if (!cow_layout_for(vgfast::vtype(seq))) return STORE_UNSUPPORTED;
	vgcow::Pin p;
	if (!vgcow::pin_ro(seq, p)) return STORE_UNSUPPORTED;
	uint8_t buf[16];
	if (!vgcow::load_bytes(p, idx, buf)) return idx < 0 ? STORE_OUT_OF_RANGE : STORE_OUT_OF_RANGE;
	bytes_to_variant(p.packed, buf, out);
	return STORE_OK;
}

inline StoreResult cow_store(Variant &seq, int64_t idx, const Variant &value) {
	if (!cow_layout_for(vgfast::vtype(seq))) return STORE_UNSUPPORTED;
	vgcow::Pin p;
	if (!vgcow::pin_rw(seq, p)) return STORE_UNSUPPORTED;
	uint8_t buf[16];
	if (!variant_to_bytes(p.packed, value, buf)) return STORE_TYPE_MISMATCH;
	if (!vgcow::store_bytes(p, idx, buf)) return STORE_OUT_OF_RANGE;
	return STORE_OK;
}

inline bool cow_append(Variant &seq, const Variant &value) {
	if (!vgcow::g_ok || !cow_layout_for(vgfast::vtype(seq))) return false;
	vgcow::Pin p;
	if (!vgcow::pin_rw(seq, p)) return false;
	uint8_t buf[16];
	if (!variant_to_bytes(p.packed, value, buf)) return false;
	return vgcow::append_bytes(p, buf);
}

// Read seq(idx) into `out`.  `out` must be NIL (zeroed); packed tuple
// elements are written with vgfast::raw_init so the GET path never boxes
// through Variant::get_indexed.
inline StoreResult load(Variant &seq, int64_t idx, Variant &out) {
	if (idx < 0) return is_sequence(seq.get_type()) ? STORE_OUT_OF_RANGE : STORE_UNSUPPORTED;
	if (vgcow::is_pod_packed(vgfast::vtype(seq))) {
		const StoreResult sr = cow_load(seq, idx, out);
		if (sr != STORE_UNSUPPORTED) return sr;
	}
	switch (seq.get_type()) {
		case Variant::ARRAY: {
			Array *a = VariantInternal::get_array(&seq);
			if (!in_range(a, idx)) return STORE_OUT_OF_RANGE;
			out = (*a)[idx];
			return STORE_OK;
		}
		case Variant::PACKED_BYTE_ARRAY: {
			PackedByteArray *a = VariantInternal::get_byte_array(&seq);
			if (!in_range(a, idx)) return STORE_OUT_OF_RANGE;
			const uint8_t *p = a->ptr();
			vgfast::raw_init_int(&out, p ? (int64_t)p[idx] : 0);
			return STORE_OK;
		}
		case Variant::PACKED_INT32_ARRAY: {
			PackedInt32Array *a = VariantInternal::get_int32_array(&seq);
			if (!in_range(a, idx)) return STORE_OUT_OF_RANGE;
			const int32_t *p = a->ptr();
			vgfast::raw_init_int(&out, p ? (int64_t)p[idx] : 0);
			return STORE_OK;
		}
		case Variant::PACKED_INT64_ARRAY: {
			PackedInt64Array *a = VariantInternal::get_int64_array(&seq);
			if (!in_range(a, idx)) return STORE_OUT_OF_RANGE;
			const int64_t *p = a->ptr();
			vgfast::raw_init_int(&out, p ? p[idx] : 0);
			return STORE_OK;
		}
		case Variant::PACKED_FLOAT32_ARRAY: {
			PackedFloat32Array *a = VariantInternal::get_float32_array(&seq);
			if (!in_range(a, idx)) return STORE_OUT_OF_RANGE;
			const float *p = a->ptr();
			vgfast::raw_init_float(&out, p ? (double)p[idx] : 0.0);
			return STORE_OK;
		}
		case Variant::PACKED_FLOAT64_ARRAY: {
			PackedFloat64Array *a = VariantInternal::get_float64_array(&seq);
			if (!in_range(a, idx)) return STORE_OUT_OF_RANGE;
			const double *p = a->ptr();
			vgfast::raw_init_float(&out, p ? p[idx] : 0.0);
			return STORE_OK;
		}
		case Variant::PACKED_STRING_ARRAY: {
			PackedStringArray *a = VariantInternal::get_string_array(&seq);
			if (!in_range(a, idx)) return STORE_OUT_OF_RANGE;
			out = (*a)[idx];
			return STORE_OK;
		}
		case Variant::PACKED_VECTOR2_ARRAY: {
			PackedVector2Array *a = VariantInternal::get_vector2_array(&seq);
			if (!in_range(a, idx)) return STORE_OUT_OF_RANGE;
			const Vector2 *p = a->ptr();
			if (!p) return STORE_UNSUPPORTED;
			vgfast::raw_init_vector2(&out, p[idx]);
			return STORE_OK;
		}
		case Variant::PACKED_VECTOR3_ARRAY: {
			PackedVector3Array *a = VariantInternal::get_vector3_array(&seq);
			if (!in_range(a, idx)) return STORE_OUT_OF_RANGE;
			const Vector3 *p = a->ptr();
			if (!p) return STORE_UNSUPPORTED;
			vgfast::raw_init_vector3(&out, p[idx]);
			return STORE_OK;
		}
		case Variant::PACKED_COLOR_ARRAY: {
			PackedColorArray *a = VariantInternal::get_color_array(&seq);
			if (!in_range(a, idx)) return STORE_OUT_OF_RANGE;
			const Color *p = a->ptr();
			if (!p) return STORE_UNSUPPORTED;
			vgfast::raw_init_color(&out, p[idx]);
			return STORE_OK;
		}
		case Variant::PACKED_VECTOR4_ARRAY: {
			PackedVector4Array *a = VariantInternal::get_vector4_array(&seq);
			if (!in_range(a, idx)) return STORE_OUT_OF_RANGE;
			out = (*a)[idx];
			return STORE_OK;
		}
		default:
			return STORE_UNSUPPORTED;
	}
}

inline StoreResult store(Variant &seq, int64_t idx, const Variant &value) {
	// Godot wraps negative indices; VB raises "subscript out of range".
	if (idx < 0) return is_sequence(seq.get_type()) ? STORE_OUT_OF_RANGE : STORE_UNSUPPORTED;
	const Variant::Type vt = value.get_type();
	if (vgcow::is_pod_packed(seq.get_type())) {
		const StoreResult sr = cow_store(seq, idx, value);
		if (sr != STORE_UNSUPPORTED) return sr;
	}
	switch (seq.get_type()) {
		case Variant::ARRAY: {
			Array *a = VariantInternal::get_array(&seq);
			if (!in_range(a, idx)) return STORE_OUT_OF_RANGE;
			(*a)[idx] = value;
			return STORE_OK;
		}
		case Variant::PACKED_BYTE_ARRAY: {
			PackedByteArray *a = VariantInternal::get_byte_array(&seq);
			if (!in_range(a, idx)) return STORE_OUT_OF_RANGE;
			(*a)[idx] = (uint8_t)vb_int(value);
			return STORE_OK;
		}
		case Variant::PACKED_INT32_ARRAY: {
			PackedInt32Array *a = VariantInternal::get_int32_array(&seq);
			if (!in_range(a, idx)) return STORE_OUT_OF_RANGE;
			(*a)[idx] = (int32_t)vb_int(value);
			return STORE_OK;
		}
		case Variant::PACKED_INT64_ARRAY: {
			PackedInt64Array *a = VariantInternal::get_int64_array(&seq);
			if (!in_range(a, idx)) return STORE_OUT_OF_RANGE;
			(*a)[idx] = vb_int(value);
			return STORE_OK;
		}
		case Variant::PACKED_FLOAT32_ARRAY: {
			PackedFloat32Array *a = VariantInternal::get_float32_array(&seq);
			if (!in_range(a, idx)) return STORE_OUT_OF_RANGE;
			(*a)[idx] = (float)(double)value;
			return STORE_OK;
		}
		case Variant::PACKED_FLOAT64_ARRAY: {
			PackedFloat64Array *a = VariantInternal::get_float64_array(&seq);
			if (!in_range(a, idx)) return STORE_OUT_OF_RANGE;
			(*a)[idx] = (double)value;
			return STORE_OK;
		}
		case Variant::PACKED_STRING_ARRAY: {
			PackedStringArray *a = VariantInternal::get_string_array(&seq);
			if (!in_range(a, idx)) return STORE_OUT_OF_RANGE;
			(*a)[idx] = (String)value;
			return STORE_OK;
		}
		case Variant::PACKED_VECTOR2_ARRAY: {
			if (vt != Variant::VECTOR2 && vt != Variant::VECTOR2I) return STORE_TYPE_MISMATCH;
			PackedVector2Array *a = VariantInternal::get_vector2_array(&seq);
			if (!in_range(a, idx)) return STORE_OUT_OF_RANGE;
			Vector2 *w = a->ptrw();
			if (!w) return STORE_UNSUPPORTED;
			w[idx] = vt == Variant::VECTOR2 ? vgfast::vvec2(value) : Vector2((Vector2i)value);
			return STORE_OK;
		}
		case Variant::PACKED_VECTOR3_ARRAY: {
			if (vt != Variant::VECTOR3 && vt != Variant::VECTOR3I) return STORE_TYPE_MISMATCH;
			PackedVector3Array *a = VariantInternal::get_vector3_array(&seq);
			if (!in_range(a, idx)) return STORE_OUT_OF_RANGE;
			Vector3 *w = a->ptrw();
			if (!w) return STORE_UNSUPPORTED;
			w[idx] = vt == Variant::VECTOR3 ? vgfast::vvec3(value) : Vector3((Vector3i)value);
			return STORE_OK;
		}
		case Variant::PACKED_COLOR_ARRAY: {
			if (vt != Variant::COLOR) return STORE_TYPE_MISMATCH;
			PackedColorArray *a = VariantInternal::get_color_array(&seq);
			if (!in_range(a, idx)) return STORE_OUT_OF_RANGE;
			Color *w = a->ptrw();
			if (!w) return STORE_UNSUPPORTED;
			w[idx] = vgfast::vcolor(value);
			return STORE_OK;
		}
		case Variant::PACKED_VECTOR4_ARRAY: {
			if (vt != Variant::VECTOR4 && vt != Variant::VECTOR4I) return STORE_TYPE_MISMATCH;
			PackedVector4Array *a = VariantInternal::get_vector4_array(&seq);
			if (!in_range(a, idx)) return STORE_OUT_OF_RANGE;
			(*a)[idx] = vt == Variant::VECTOR4 ? (Vector4)value : Vector4((Vector4i)value);
			return STORE_OK;
		}
		default:
			return STORE_UNSUPPORTED;
	}
}

// `seq.append(value)` in place.  False when seq is not a sequence or value
// needs a conversion the caller should leave to Variant::callp.
inline bool append(Variant &seq, const Variant &value) {
	if (cow_append(seq, value)) return true;
	const Variant::Type vt = value.get_type();
	switch (seq.get_type()) {
		case Variant::ARRAY:
			VariantInternal::get_array(&seq)->push_back(value);
			return true;
		case Variant::PACKED_BYTE_ARRAY:
			if (vt != Variant::INT && vt != Variant::FLOAT && vt != Variant::BOOL) return false;
			VariantInternal::get_byte_array(&seq)->push_back((uint8_t)vb_int(value));
			return true;
		case Variant::PACKED_INT32_ARRAY:
			if (vt != Variant::INT && vt != Variant::FLOAT && vt != Variant::BOOL) return false;
			VariantInternal::get_int32_array(&seq)->push_back((int32_t)vb_int(value));
			return true;
		case Variant::PACKED_INT64_ARRAY:
			if (vt != Variant::INT && vt != Variant::FLOAT && vt != Variant::BOOL) return false;
			VariantInternal::get_int64_array(&seq)->push_back(vb_int(value));
			return true;
		case Variant::PACKED_FLOAT32_ARRAY:
			if (vt != Variant::INT && vt != Variant::FLOAT) return false;
			VariantInternal::get_float32_array(&seq)->push_back((float)(double)value);
			return true;
		case Variant::PACKED_FLOAT64_ARRAY:
			if (vt != Variant::INT && vt != Variant::FLOAT) return false;
			VariantInternal::get_float64_array(&seq)->push_back((double)value);
			return true;
		case Variant::PACKED_STRING_ARRAY:
			VariantInternal::get_string_array(&seq)->push_back((String)value);
			return true;
		case Variant::PACKED_VECTOR2_ARRAY:
			if (vt != Variant::VECTOR2) return false;
			VariantInternal::get_vector2_array(&seq)->push_back((Vector2)value);
			return true;
		case Variant::PACKED_VECTOR3_ARRAY:
			if (vt != Variant::VECTOR3) return false;
			VariantInternal::get_vector3_array(&seq)->push_back((Vector3)value);
			return true;
		case Variant::PACKED_COLOR_ARRAY:
			if (vt != Variant::COLOR) return false;
			VariantInternal::get_color_array(&seq)->push_back((Color)value);
			return true;
		case Variant::PACKED_VECTOR4_ARRAY:
			if (vt != Variant::VECTOR4) return false;
			VariantInternal::get_vector4_array(&seq)->push_back((Vector4)value);
			return true;
		default:
			return false;
	}
}

inline StoreResult copy_index(Variant &dst, Variant &src, int64_t idx) {
	const Variant::Type st = vgfast::vtype(src);
	const Variant::Type dt = vgfast::vtype(dst);
	if (cow_layout_for(st) && vgcow::is_pod_packed(st) && st == dt) {
		uint8_t buf[16];
		if (vgcow::opaque_of(dst) == vgcow::opaque_of(src)) {
			vgcow::Pin p;
			if (vgcow::pin_rw(dst, p) && vgcow::load_bytes(p, idx, buf) && vgcow::append_bytes(p, buf)) {
				return STORE_OK;
			}
		} else {
			vgcow::Pin sp, dp;
			if (vgcow::pin_ro(src, sp) && vgcow::pin_rw(dst, dp) && sp.elem == dp.elem) {
				if (!vgcow::load_bytes(sp, idx, buf)) return STORE_OUT_OF_RANGE;
				if (vgcow::append_bytes(dp, buf)) return STORE_OK;
			}
		}
	}
	Variant tmp;
	const StoreResult sr = load(src, idx, tmp);
	if (sr != STORE_OK) return sr;
	return append(dst, tmp) ? STORE_OK : STORE_UNSUPPORTED;
}

inline StoreResult append_sub_index(Variant &dst, Variant &src, int64_t idx_left, int64_t idx_right) {
	const Variant::Type st = vgfast::vtype(src);
	const Variant::Type dt = vgfast::vtype(dst);
	if (st != dt || (st != Variant::PACKED_VECTOR3_ARRAY && st != Variant::PACKED_VECTOR2_ARRAY && st != Variant::PACKED_COLOR_ARRAY)) {
		return STORE_UNSUPPORTED;
	}
	if (!cow_layout_for(st)) {
		Variant lv, rv;
		const StoreResult left_sr = load(src, idx_left, lv);
		if (left_sr != STORE_OK) return left_sr;
		const StoreResult right_sr = load(src, idx_right, rv);
		if (right_sr != STORE_OK) return right_sr;
		if (st == Variant::PACKED_VECTOR2_ARRAY) {
			vgfast::raw_init_vector2(&lv, vgfast::vvec2(lv) - vgfast::vvec2(rv));
		} else {
			vgfast::raw_init_color(&lv, vgfast::vcolor(lv) - vgfast::vcolor(rv));
		}
		return append(dst, lv) ? STORE_OK : STORE_UNSUPPORTED;
	}
	vgcow::Pin sp, dp;
	if (vgcow::opaque_of(dst) == vgcow::opaque_of(src)) {
		if (!vgcow::pin_rw(dst, dp)) return STORE_UNSUPPORTED;
		sp = dp;
	} else if (!vgcow::pin_ro(src, sp) || !vgcow::pin_rw(dst, dp)) {
		return STORE_UNSUPPORTED;
	}
	uint8_t lb[16], rb[16], ob[16];
	if (!vgcow::load_bytes(sp, idx_left, lb) || !vgcow::load_bytes(sp, idx_right, rb)) {
		return STORE_OUT_OF_RANGE;
	}
	const uint32_t nfloat = sp.elem / 4;
	for (uint32_t i = 0; i < nfloat; i++) {
		float a, b;
		memcpy(&a, lb + i * 4, 4);
		memcpy(&b, rb + i * 4, 4);
		a -= b;
		memcpy(ob + i * 4, &a, 4);
	}
	if (vgcow::append_bytes(dp, ob)) return STORE_OK;
	Variant lv, rv;
	bytes_to_variant(st, lb, lv);
	bytes_to_variant(st, rb, rv);
	if (st == Variant::PACKED_VECTOR3_ARRAY) {
		vgfast::raw_init_vector3(&lv, vgfast::vvec3(lv) - vgfast::vvec3(rv));
	} else if (st == Variant::PACKED_VECTOR2_ARRAY) {
		vgfast::raw_init_vector2(&lv, vgfast::vvec2(lv) - vgfast::vvec2(rv));
	} else {
		vgfast::raw_init_color(&lv, vgfast::vcolor(lv) - vgfast::vcolor(rv));
	}
	return append(dst, lv) ? STORE_OK : STORE_UNSUPPORTED;
}

// Ribbon expansion used by line-mesh For i = 0 To n Step 2 bodies:
// six verts per edge pair, UV x in {-1,1,1,-1,1,-1}, endpoint a,a,b,a,b,b.
inline StoreResult expand_ribbon(Variant &edges, Variant &colors,
		Variant &verts, Variant &norms, Variant &vcolors, Variant &uvs,
		int64_t to_inclusive, bool append, int64_t &loop_out, int64_t &written) {
	loop_out = 0;
	written = 0;
	if (vgfast::vtype(edges) != Variant::PACKED_VECTOR3_ARRAY ||
			vgfast::vtype(colors) != Variant::PACKED_COLOR_ARRAY ||
			vgfast::vtype(verts) != Variant::PACKED_VECTOR3_ARRAY ||
			vgfast::vtype(norms) != Variant::PACKED_VECTOR3_ARRAY ||
			vgfast::vtype(vcolors) != Variant::PACKED_COLOR_ARRAY ||
			vgfast::vtype(uvs) != Variant::PACKED_VECTOR2_ARRAY) {
		return STORE_TYPE_MISMATCH;
	}
	PackedVector3Array *e = VariantInternal::get_vector3_array(&edges);
	PackedColorArray *c = VariantInternal::get_color_array(&colors);
	PackedVector3Array *v = VariantInternal::get_vector3_array(&verts);
	PackedVector3Array *n = VariantInternal::get_vector3_array(&norms);
	PackedColorArray *vc = VariantInternal::get_color_array(&vcolors);
	PackedVector2Array *u = VariantInternal::get_vector2_array(&uvs);
	if (!e || !c || !v || !n || !vc || !u) {
		return STORE_UNSUPPORTED;
	}
	if (to_inclusive < 0) {
		return STORE_OK;
	}
	const int64_t e_n = e->size();
	const int64_t c_n = c->size();
	int64_t limit = e_n < c_n ? e_n : c_n;
	if (limit < 2) {
		return STORE_OK;
	}
	int64_t last_i = to_inclusive - (to_inclusive & 1);
	const int64_t max_i = (limit - 2) & ~int64_t(1);
	if (last_i > max_i) {
		last_i = max_i;
	}
	if (last_i < 0) {
		return STORE_OK;
	}
	const int64_t pairs = (last_i / 2) + 1;
	const int64_t add = pairs * 6;
	const int64_t bv = v->size();
	const int64_t bn = n->size();
	const int64_t bc = vc->size();
	const int64_t bu = u->size();
	int64_t ov = 0, on = 0, oc = 0, ou = 0;
	if (append) {
		v->resize(bv + add);
		n->resize(bn + add);
		vc->resize(bc + add);
		u->resize(bu + add);
		ov = bv;
		on = bn;
		oc = bc;
		ou = bu;
	} else if (bv < add || bn < add || bc < add || bu < add) {
		v->resize(add);
		n->resize(add);
		vc->resize(add);
		u->resize(add);
	}
	const Vector3 *ep = e->ptr();
	const Color *cp = c->ptr();
	Vector3 *vp = v->ptrw();
	Vector3 *np = n->ptrw();
	Color *vcp = vc->ptrw();
	Vector2 *up = u->ptrw();
	if (!ep || !cp || !vp || !np || !vcp || !up) {
		return STORE_UNSUPPORTED;
	}
	static const int8_t k_end[6] = { 0, 0, 1, 0, 1, 1 };
	static const int8_t k_u[6] = { -1, 1, 1, -1, 1, -1 };
	for (int64_t i = 0; i <= last_i; i += 2) {
		const Vector3 a = ep[i];
		const Vector3 b = ep[i + 1];
		const Vector3 d = b - a;
		const Color ca = cp[i];
		const Color cb = cp[i + 1];
		for (int k = 0; k < 6; k++) {
			const Vector3 &p = k_end[k] ? b : a;
			const Color &col = k_end[k] ? cb : ca;
			vp[ov++] = p;
			np[on++] = d;
			vcp[oc++] = col;
			up[ou++] = Vector2((real_t)k_u[k], (real_t)0);
		}
	}
	loop_out = last_i + 2;
	written = add;
	return STORE_OK;
}

} // namespace vgidx

#endif // VG_INDEXED_STORE_H

