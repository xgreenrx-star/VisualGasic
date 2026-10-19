#ifndef VG_INDEXED_STORE_H
#define VG_INDEXED_STORE_H

// Element store into an Array or any Packed*Array held by a Variant, shared
// by the bytecode VM and the AST walker so `arr(i) = v` behaves the same on
// every tier.  The write goes straight into the Variant's own storage: a
// packed buffer is copied only when another Variant still shares it.

#include "vg_variant_fast.h"
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/variant_internal.hpp>

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

// Read seq(idx) into `out`.  `out` must be NIL (zeroed); packed tuple
// elements are written with vgfast::raw_init so the GET path never boxes
// through Variant::get_indexed.
inline StoreResult load(Variant &seq, int64_t idx, Variant &out) {
	if (idx < 0) return is_sequence(seq.get_type()) ? STORE_OUT_OF_RANGE : STORE_UNSUPPORTED;
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
			if (vt != Variant::STRING) return false;
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

} // namespace vgidx

#endif // VG_INDEXED_STORE_H
