#include "vg_packed_cow.h"

#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace vgcow {

bool g_ok = false;
uint32_t g_size_back = 0;
int32_t g_cow_off = -1;
int32_t g_ref_cow_off = -1;

bool verify() {
	g_ok = false;
	g_size_back = 0;
	g_cow_off = -1;
	g_ref_cow_off = -1;
	if (!vgfast::g_layout_ok) {
		return false;
	}

	PackedVector3Array a;
	a.resize(3);
	a.set(0, Vector3(1.25f, 2.5f, 3.75f));
	a.set(1, Vector3(10.0f, 20.0f, 30.0f));
	a.set(2, Vector3(-4.0f, 5.5f, 6.25f));
	const Vector3 *p = a.ptr();
	if (!p) {
		return false;
	}
	if (p[0] != Vector3(1.25f, 2.5f, 3.75f) || p[2] != Vector3(-4.0f, 5.5f, 6.25f)) {
		return false;
	}

	uint32_t size_back = 0;
	for (uint32_t back : { 8u, 16u, 24u, 32u }) {
		uint64_t n = 0;
		memcpy(&n, reinterpret_cast<const uint8_t *>(p) - back, sizeof(n));
		if (n == 3) {
			size_back = back;
			break;
		}
	}
	if (size_back == 0) {
		UtilityFunctions::print("[VG] Packed CowData size header probe failed; using engine packed paths.");
		return false;
	}

	const uint8_t *wrap = reinterpret_cast<const uint8_t *>(&a);
	int32_t cow_off = -1;
	int32_t ref_cow_off = -1;
	const uintptr_t want = (uintptr_t)p;
	for (int off = 0; off <= 8; off += (int)sizeof(uintptr_t)) {
		uintptr_t slot = 0;
		memcpy(&slot, wrap + off, sizeof(slot));
		if (slot == want) {
			cow_off = off;
			break;
		}
		if (slot != 0) {
			for (int inner = 0; inner <= 24; inner += (int)sizeof(uintptr_t)) {
				uintptr_t inner_slot = 0;
				memcpy(&inner_slot, reinterpret_cast<const uint8_t *>(slot) + inner, sizeof(inner_slot));
				if (inner_slot == want) {
					cow_off = off;
					ref_cow_off = inner;
					break;
				}
			}
			if (ref_cow_off >= 0) break;
		}
	}
	if (cow_off < 0) {
		UtilityFunctions::print("[VG] Packed CowData pointer offset probe failed; using engine packed paths.");
		return false;
	}

	// Grow with resize, then shrink the logical size through the header and
	// append one Vector3 in place.  Engine size()/ptr() must agree.
	a.resize(8);
	Vector3 *w = a.ptrw();
	if (!w) {
		return false;
	}
	uint64_t *sizep = reinterpret_cast<uint64_t *>(reinterpret_cast<uint8_t *>(w) - size_back);
	if (*sizep != 8) {
		UtilityFunctions::print("[VG] Packed CowData size after resize(8) mismatch; using engine packed paths.");
		return false;
	}
	*sizep = 3;
	if (a.size() != 3) {
		*sizep = 8;
		UtilityFunctions::print("[VG] Packed CowData size write-back not visible to engine; using engine packed paths.");
		return false;
	}
	const Vector3 extra(7.0f, 8.0f, 9.0f);
	memcpy(w + 3, &extra, sizeof(extra));
	*sizep = 4;
	if (a.size() != 4 || a.get(3) != extra || a.get(0) != Vector3(1.25f, 2.5f, 3.75f)) {
		UtilityFunctions::print("[VG] Packed CowData in-place append probe failed; using engine packed paths.");
		return false;
	}

	g_size_back = size_back;
	g_cow_off = cow_off;
	g_ref_cow_off = ref_cow_off;
	g_ok = true;
	return true;
}

} // namespace vgcow
