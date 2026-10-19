#ifndef VG_PACKED_COW_H
#define VG_PACKED_COW_H

// Direct CowData access for Packed*Array Variants.  godot-cpp's size()/ptr()/
// ptrw()/push_back() are GDExtension ptrcalls; GDScript pays an inline C++
// load.  After a layout probe (same spirit as vgfast) the hot path reads the
// CowData size header and element buffer without an engine call, and append
// grows with a geometric resize then in-place size bumps.

#include "vg_variant_fast.h"
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/variant_internal.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <cstdint>
#include <cstring>

namespace vgcow {

using namespace godot;

extern bool g_ok;
extern uint32_t g_size_back;     // bytes before T[0] where the uint64 size sits
extern int32_t g_cow_off;       // byte offset of CowData T* inside the 16-byte Packed* wrapper; -1 if nested
extern int32_t g_ref_cow_off;   // if wrapper[0:8] is PackedArrayRef*, offset of T* inside that ref; -1 if unused

bool verify();

inline uint32_t elem_bytes(Variant::Type t) {
	switch (t) {
		case Variant::PACKED_BYTE_ARRAY: return 1;
		case Variant::PACKED_INT32_ARRAY: return 4;
		case Variant::PACKED_INT64_ARRAY: return 8;
		case Variant::PACKED_FLOAT32_ARRAY: return 4;
		case Variant::PACKED_FLOAT64_ARRAY: return 8;
		case Variant::PACKED_VECTOR2_ARRAY: return 8;
		case Variant::PACKED_VECTOR3_ARRAY: return 12;
		case Variant::PACKED_COLOR_ARRAY: return 16;
		case Variant::PACKED_VECTOR4_ARRAY: return 16;
		default: return 0;
	}
}

inline Variant::Type elem_vtype(Variant::Type packed) {
	switch (packed) {
		case Variant::PACKED_BYTE_ARRAY:
		case Variant::PACKED_INT32_ARRAY:
		case Variant::PACKED_INT64_ARRAY:
			return Variant::INT;
		case Variant::PACKED_FLOAT32_ARRAY:
		case Variant::PACKED_FLOAT64_ARRAY:
			return Variant::FLOAT;
		case Variant::PACKED_VECTOR2_ARRAY: return Variant::VECTOR2;
		case Variant::PACKED_VECTOR3_ARRAY: return Variant::VECTOR3;
		case Variant::PACKED_COLOR_ARRAY: return Variant::COLOR;
		case Variant::PACKED_VECTOR4_ARRAY: return Variant::VECTOR4;
		default: return Variant::NIL;
	}
}

inline bool is_pod_packed(Variant::Type t) {
	return elem_bytes(t) != 0;
}

using IndexFn = GDExtensionTypePtr (*)(GDExtensionTypePtr, GDExtensionInt);
using IndexConstFn = GDExtensionTypePtr (*)(GDExtensionConstTypePtr, GDExtensionInt);

struct Ops {
	GDExtensionVariantGetInternalPtrFunc internal_ptr = nullptr;
	GDExtensionPtrBuiltInMethod size = nullptr;
	GDExtensionPtrBuiltInMethod resize = nullptr;
	GDExtensionPtrBuiltInMethod push_back = nullptr;
	IndexFn index = nullptr;
	IndexConstFn index_const = nullptr;
	uint8_t elem = 0;
	Variant::Type packed = Variant::NIL;
	Variant::Type elem_type = Variant::NIL;
};

inline const Ops *ops_for(Variant::Type t) {
	static const Ops *table = []() -> const Ops * {
		static Ops built[Variant::VARIANT_MAX];
		struct Row {
			Variant::Type type;
			Variant::Type elem;
			uint8_t bytes;
			int64_t h_push;
			IndexFn idx;
			IndexConstFn idxc;
		};
		const Row rows[] = {
			{ Variant::PACKED_BYTE_ARRAY, Variant::INT, 1, 694024632,
					(IndexFn)internal::gdextension_interface_packed_byte_array_operator_index,
					(IndexConstFn)internal::gdextension_interface_packed_byte_array_operator_index_const },
			{ Variant::PACKED_INT32_ARRAY, Variant::INT, 4, 694024632,
					(IndexFn)internal::gdextension_interface_packed_int32_array_operator_index,
					(IndexConstFn)internal::gdextension_interface_packed_int32_array_operator_index_const },
			{ Variant::PACKED_INT64_ARRAY, Variant::INT, 8, 694024632,
					(IndexFn)internal::gdextension_interface_packed_int64_array_operator_index,
					(IndexConstFn)internal::gdextension_interface_packed_int64_array_operator_index_const },
			{ Variant::PACKED_FLOAT32_ARRAY, Variant::FLOAT, 4, 4094791666,
					(IndexFn)internal::gdextension_interface_packed_float32_array_operator_index,
					(IndexConstFn)internal::gdextension_interface_packed_float32_array_operator_index_const },
			{ Variant::PACKED_FLOAT64_ARRAY, Variant::FLOAT, 8, 4094791666,
					(IndexFn)internal::gdextension_interface_packed_float64_array_operator_index,
					(IndexConstFn)internal::gdextension_interface_packed_float64_array_operator_index_const },
			{ Variant::PACKED_VECTOR2_ARRAY, Variant::VECTOR2, 8, 4188891560,
					(IndexFn)internal::gdextension_interface_packed_vector2_array_operator_index,
					(IndexConstFn)internal::gdextension_interface_packed_vector2_array_operator_index_const },
			{ Variant::PACKED_VECTOR3_ARRAY, Variant::VECTOR3, 12, 3295363524,
					(IndexFn)internal::gdextension_interface_packed_vector3_array_operator_index,
					(IndexConstFn)internal::gdextension_interface_packed_vector3_array_operator_index_const },
			{ Variant::PACKED_COLOR_ARRAY, Variant::COLOR, 16, 1007858200,
					(IndexFn)internal::gdextension_interface_packed_color_array_operator_index,
					(IndexConstFn)internal::gdextension_interface_packed_color_array_operator_index_const },
			{ Variant::PACKED_VECTOR4_ARRAY, Variant::VECTOR4, 16, 3289167688,
					(IndexFn)internal::gdextension_interface_packed_vector4_array_operator_index,
					(IndexConstFn)internal::gdextension_interface_packed_vector4_array_operator_index_const },
		};
		const StringName sn_size("size");
		const StringName sn_resize("resize");
		const StringName sn_push("push_back");
		for (const Row &r : rows) {
			Ops &m = built[r.type];
			const GDExtensionVariantType gt = (GDExtensionVariantType)r.type;
			m.internal_ptr = internal::gdextension_interface_variant_get_ptr_internal_getter(gt);
			m.size = internal::gdextension_interface_variant_get_ptr_builtin_method(gt, sn_size._native_ptr(), 3173160232);
			m.resize = internal::gdextension_interface_variant_get_ptr_builtin_method(gt, sn_resize._native_ptr(), 848867239);
			m.push_back = internal::gdextension_interface_variant_get_ptr_builtin_method(gt, sn_push._native_ptr(), r.h_push);
			m.index = r.idx;
			m.index_const = r.idxc;
			m.elem = r.bytes;
			m.packed = r.type;
			m.elem_type = r.elem;
		}
		return built;
	}();
	if ((unsigned)t >= (unsigned)Variant::VARIANT_MAX) return nullptr;
	const Ops &m = table[t];
	return m.internal_ptr ? &m : nullptr;
}

inline void *opaque_of(Variant &seq) {
	const Ops *o = ops_for(vgfast::vtype(seq));
	return o && o->internal_ptr ? o->internal_ptr(seq._native_ptr()) : nullptr;
}

inline const void *opaque_of(const Variant &seq) {
	return opaque_of(const_cast<Variant &>(seq));
}

struct Pin {
	Variant *seq = nullptr;
	void *opaque = nullptr;
	uintptr_t ident = 0;
	uint8_t *data = nullptr;
	uint64_t *sizep = nullptr;
	uint64_t cap = 0;
	uint32_t elem = 0;
	uint8_t rw = 0; // 0 empty/invalid, 1 ro, 2 rw
	Variant::Type packed = Variant::NIL;
	const Ops *ops = nullptr;
};

inline uint8_t *cow_ptr(void *opaque) {
	if (!g_ok || !opaque || g_cow_off < 0) return nullptr;
	uintptr_t slot = 0;
	memcpy(&slot, reinterpret_cast<uint8_t *>(opaque) + g_cow_off, sizeof(slot));
	if (g_ref_cow_off >= 0) {
		if (slot == 0) return nullptr;
		uintptr_t inner = 0;
		memcpy(&inner, reinterpret_cast<uint8_t *>(slot) + g_ref_cow_off, sizeof(inner));
		return reinterpret_cast<uint8_t *>(inner);
	}
	return reinterpret_cast<uint8_t *>(slot);
}

inline uint64_t cow_size(const Pin &p) {
	if (p.sizep) return *p.sizep;
	return p.cap;
}

inline Pin *cache() {
	thread_local Pin pins[8];
	return pins;
}

inline Pin *cached(Variant *seq) {
	if (!seq) return nullptr;
	Pin *p = cache();
	for (int i = 0; i < 8; i++) {
		if (p[i].seq != seq) continue;
		uint8_t *live = cow_ptr(p[i].opaque);
		if (p[i].data == live) return &p[i];
	}
	return nullptr;
}

inline Pin *take_slot(Variant *seq, void *opaque) {
	Pin *hit = cached(seq);
	if (hit) return hit;
	Pin *p = cache();
	static thread_local unsigned clock = 0;
	Pin *slot = &p[(clock++) & 7];
	*slot = Pin();
	slot->seq = seq;
	slot->opaque = opaque;
	return slot;
}

inline void drop(Variant *seq) {
	Pin *hit = cached(seq);
	if (hit) *hit = Pin();
}

inline int64_t engine_size(void *opaque, const Ops *o) {
	int64_t n = 0;
	if (o && o->size) o->size(opaque, nullptr, &n, 0);
	return n;
}

inline bool bind_cow(Pin &p, uint8_t *data, int64_t n) {
	if (!g_ok || !data || n <= 0) {
		p.data = data;
		p.sizep = nullptr;
		p.cap = n < 0 ? 0 : (uint64_t)n;
		return data != nullptr || n == 0;
	}
	p.data = data;
	p.sizep = reinterpret_cast<uint64_t *>(data - g_size_back);
	if (*p.sizep != (uint64_t)n) {
		p.sizep = nullptr;
		p.cap = (uint64_t)n;
		return false;
	}
	p.cap = (uint64_t)n;
	return true;
}

inline bool pin_ro(Variant &seq, Pin &out) {
	const Variant::Type t = vgfast::vtype(seq);
	const Ops *o = ops_for(t);
	if (!o) return false;
	Pin *c = cached(&seq);
	if (c && c->ops == o && c->rw >= 1) {
		out = *c;
		return true;
	}
	void *opaque = opaque_of(seq);
	if (!opaque) return false;
	Pin p;
	p.seq = &seq;
	p.opaque = opaque;
	p.ops = o;
	p.packed = t;
	p.elem = o->elem;
	if (g_ok) {
		uint8_t *data = cow_ptr(opaque);
		if (!data) {
			p.rw = 1;
			p.data = nullptr;
			p.sizep = nullptr;
			p.cap = 0;
			*take_slot(&seq, opaque) = p;
			out = p;
			return true;
		}
		p.data = data;
		p.sizep = reinterpret_cast<uint64_t *>(data - g_size_back);
		p.cap = *p.sizep;
		p.rw = 1;
		*take_slot(&seq, opaque) = p;
		out = p;
		return true;
	}
	const int64_t n = engine_size(opaque, o);
	if (n < 0) return false;
	if (n == 0) {
		p.rw = 1;
		p.data = nullptr;
		p.sizep = nullptr;
		p.cap = 0;
		*take_slot(&seq, opaque) = p;
		out = p;
		return true;
	}
	uint8_t *data = (uint8_t *)o->index_const((GDExtensionConstTypePtr)opaque, 0);
	if (!data) return false;
	bind_cow(p, data, n);
	p.rw = 1;
	*take_slot(&seq, opaque) = p;
	out = p;
	return true;
}

inline bool pin_rw(Variant &seq, Pin &out) {
	const Variant::Type t = vgfast::vtype(seq);
	const Ops *o = ops_for(t);
	if (!o) return false;
	Pin *c = cached(&seq);
	if (c && c->ops == o && c->rw == 2 && c->data) {
		out = *c;
		return true;
	}
	void *opaque = opaque_of(seq);
	if (!opaque) return false;
	Pin p;
	p.seq = &seq;
	p.opaque = opaque;
	p.ops = o;
	p.packed = t;
	p.elem = o->elem;
	if (g_ok) {
		uint8_t *data = cow_ptr(opaque);
		const uint64_t n = data ? *reinterpret_cast<uint64_t *>(data - g_size_back) : 0;
		if (n > 0 && o->index) {
			o->index(opaque, 0);
			data = cow_ptr(opaque);
		}
		if (!data) {
			p.rw = 2;
			p.data = nullptr;
			p.sizep = nullptr;
			p.cap = 0;
			*take_slot(&seq, opaque) = p;
			out = p;
			return true;
		}
		p.data = data;
		p.sizep = reinterpret_cast<uint64_t *>(data - g_size_back);
		p.cap = *p.sizep;
		p.rw = 2;
		*take_slot(&seq, opaque) = p;
		out = p;
		return true;
	}
	const int64_t n = engine_size(opaque, o);
	if (n < 0) return false;
	if (n == 0) {
		p.rw = 2;
		p.data = nullptr;
		p.sizep = nullptr;
		p.cap = 0;
		*take_slot(&seq, opaque) = p;
		out = p;
		return true;
	}
	uint8_t *data = (uint8_t *)o->index(opaque, 0);
	if (!data) return false;
	bind_cow(p, data, n);
	p.rw = 2;
	*take_slot(&seq, opaque) = p;
	out = p;
	return true;
}

inline uint64_t po2_at_least(uint64_t n) {
	uint64_t x = n < 8 ? 8 : n;
	x--;
	x |= x >> 1;
	x |= x >> 2;
	x |= x >> 4;
	x |= x >> 8;
	x |= x >> 16;
	x |= x >> 32;
	return x + 1;
}

inline bool grow_rw(Pin &p, uint64_t need) {
	if (!g_ok || !p.ops || !p.opaque || !p.ops->resize) return false;
	if (need <= p.cap && p.data) return true;
	const uint64_t n = p.sizep ? *p.sizep : p.cap;
	const uint64_t new_cap = po2_at_least(need);
	int64_t rs = (int64_t)new_cap;
	const GDExtensionConstTypePtr args[1] = { &rs };
	int64_t ret = 0;
	p.ops->resize(p.opaque, args, &ret, 1);
	uint8_t *data = nullptr;
	if (new_cap > 0) {
		data = (uint8_t *)p.ops->index(p.opaque, 0);
	}
	if (!bind_cow(p, data, (int64_t)new_cap) && !data) {
		p.cap = 0;
		p.rw = 2;
		*take_slot(p.seq, p.opaque) = p;
		return false;
	}
	if (p.sizep) {
		*p.sizep = n;
	}
	p.cap = new_cap;
	p.rw = 2;
	*take_slot(p.seq, p.opaque) = p;
	return p.data != nullptr || n == 0;
}

inline bool load_bytes(Pin &p, int64_t idx, void *dst) {
	const uint64_t n = cow_size(p);
	if (idx < 0 || (uint64_t)idx >= n || !p.data) return false;
	memcpy(dst, p.data + (size_t)idx * p.elem, p.elem);
	return true;
}

inline bool store_bytes(Pin &p, int64_t idx, const void *src) {
	const uint64_t n = cow_size(p);
	if (idx < 0 || (uint64_t)idx >= n || !p.data) return false;
	memcpy(p.data + (size_t)idx * p.elem, src, p.elem);
	return true;
}

inline bool append_bytes(Pin &p, const void *src) {
	if (!g_ok) return false;
	uint64_t n = p.sizep ? *p.sizep : (p.data ? p.cap : 0);
	if (!grow_rw(p, n + 1)) return false;
	n = p.sizep ? *p.sizep : n;
	memcpy(p.data + (size_t)n * p.elem, src, p.elem);
	if (p.sizep) {
		*p.sizep = n + 1;
	}
	Pin *c = cached(p.seq);
	if (c) *c = p;
	return true;
}

} // namespace vgcow

#endif // VG_PACKED_COW_H
