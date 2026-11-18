// ============================================================================
// visual_gasic_vm_fastloop.cpp — lean loop for the bytecode VM's simple opcodes
//
// Design and rules: visual_gasic_vm_fastloop.h.  Each handler below is the
// plain case of the handler for the same opcode in
// visual_gasic_instance_bytecode_vm.cpp; its comment names what it leaves to
// that handler.
// ============================================================================
#include "visual_gasic_vm_fastloop.h"
#include "visual_gasic_language.h"
#include "visual_gasic_evidence.h"
#include "vg_variant_fast.h"

#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/variant_internal.hpp>
#include <atomic>
#include <cmath>
#include <cstring>
#include <mutex>
#include <new>

#if VG_FASTLOOP_AVAILABLE

namespace {

#define FL_INLINE inline __attribute__((always_inline))
#define FL_LIKELY(x) __builtin_expect(!!(x), 1)
#define FL_UNLIKELY(x) __builtin_expect(!!(x), 0)

constexpr size_t FL_VSZ = sizeof(Variant);
constexpr uint32_t FL_NIL = (uint32_t)Variant::NIL;
constexpr uint32_t FL_BOOL = (uint32_t)Variant::BOOL;
constexpr uint32_t FL_INT = (uint32_t)Variant::INT;
constexpr uint32_t FL_FLOAT = (uint32_t)Variant::FLOAT;

// Raw Variant access.  The loop only runs while vgfast::g_layout_ok holds
// (execute_bytecode checks it), so these skip the per-call layout test the
// vgfast:: helpers carry.  The bytes written are those of vgfast::raw_init_*.
FL_INLINE uint32_t fl_type(const Variant *v) {
	uint32_t t;
	memcpy(&t, v, sizeof(t));
	return t;
}
FL_INLINE bool fl_pod(uint32_t t) {
	return vgfast::is_pod_type((Variant::Type)t);
}
FL_INLINE int64_t fl_int(const Variant *v) {
	int64_t x;
	memcpy(&x, reinterpret_cast<const uint8_t *>(v) + vgfast::PAYLOAD_OFFSET, sizeof(x));
	return x;
}
FL_INLINE double fl_float(const Variant *v) {
	double x;
	memcpy(&x, reinterpret_cast<const uint8_t *>(v) + vgfast::PAYLOAD_OFFSET, sizeof(x));
	return x;
}
FL_INLINE bool fl_bool(const Variant *v) {
	uint8_t b;
	memcpy(&b, reinterpret_cast<const uint8_t *>(v) + vgfast::PAYLOAD_OFFSET, sizeof(b));
	return b != 0;
}
// Scalar writers and the 24-byte copy.  A Variant is written and copied as
// three 8-byte words (type word, payload word, zero word): a value stored by
// one handler is usually loaded by the next, and a load is only served from
// the store buffer when it lies within a single earlier store.  The bytes
// are those vgfast::raw_init_int / _float / _bool write.
static_assert(FL_VSZ == 24 && vgfast::PAYLOAD_OFFSET == 8, "the lean loop handles a Variant as three 8-byte words");
#if defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
FL_INLINE void fl_put_words(Variant *v, uint64_t type_word, uint64_t payload) {
	uint8_t *p = reinterpret_cast<uint8_t *>(v);
	const uint64_t zero = 0;
	memcpy(p, &type_word, 8);
	memcpy(p + 8, &payload, 8);
	memcpy(p + 16, &zero, 8);
}
FL_INLINE void fl_put_int(Variant *v, int64_t x) {
	fl_put_words(v, FL_INT, (uint64_t)x);
}
FL_INLINE void fl_put_float(Variant *v, double x) {
	uint64_t bits;
	memcpy(&bits, &x, 8);
	fl_put_words(v, FL_FLOAT, bits);
}
FL_INLINE void fl_put_bool(Variant *v, bool x) {
	fl_put_words(v, FL_BOOL, x ? 1 : 0);
}
#else
FL_INLINE void fl_put_int(Variant *v, int64_t x) {
	uint8_t *p = reinterpret_cast<uint8_t *>(v);
	memset(p, 0, FL_VSZ);
	memcpy(p, &FL_INT, sizeof(FL_INT));
	memcpy(p + vgfast::PAYLOAD_OFFSET, &x, sizeof(x));
}
FL_INLINE void fl_put_float(Variant *v, double x) {
	uint8_t *p = reinterpret_cast<uint8_t *>(v);
	memset(p, 0, FL_VSZ);
	memcpy(p, &FL_FLOAT, sizeof(FL_FLOAT));
	memcpy(p + vgfast::PAYLOAD_OFFSET, &x, sizeof(x));
}
FL_INLINE void fl_put_bool(Variant *v, bool x) {
	uint8_t *p = reinterpret_cast<uint8_t *>(v);
	memset(p, 0, FL_VSZ);
	memcpy(p, &FL_BOOL, sizeof(FL_BOOL));
	const uint8_t b = x ? 1 : 0;
	memcpy(p + vgfast::PAYLOAD_OFFSET, &b, sizeof(b));
}
#endif
// A complete copy of an inline payload, a move of anything else (the source
// must then be dropped without a destructor call).  The type is read as its
// four bytes and written as a word, so the bytes between it and the payload
// (padding) come out zero.
FL_INLINE void fl_copy(Variant *dst, const Variant *src) {
#if defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
	const uint8_t *s = reinterpret_cast<const uint8_t *>(src);
	uint8_t *d = reinterpret_cast<uint8_t *>(dst);
	uint32_t type;
	uint64_t w1;
	uint64_t w2;
	memcpy(&type, s, 4);
	memcpy(&w1, s + 8, 8);
	memcpy(&w2, s + 16, 8);
	const uint64_t w0 = type;
	memcpy(d, &w0, 8);
	memcpy(d + 8, &w1, 8);
	memcpy(d + 16, &w2, 8);
#else
	memcpy(static_cast<void *>(dst), static_cast<const void *>(src), FL_VSZ);
#endif
}

// Integer / Double operand as the VM's to_int() / to_double() read it.
// False for every other type (those conversions stay with the ordinary
// handlers).
FL_INLINE bool fl_as_i64(const Variant *v, int64_t &out) {
	const uint32_t t = fl_type(v);
	if (FL_LIKELY(t == FL_INT)) {
		out = fl_int(v);
		return true;
	}
	if (t == FL_FLOAT) {
		out = (int64_t)fl_float(v);
		return true;
	}
	return false;
}
FL_INLINE bool fl_as_f64(const Variant *v, double &out) {
	const uint32_t t = fl_type(v);
	if (FL_LIKELY(t == FL_FLOAT)) {
		out = fl_float(v);
		return true;
	}
	if (t == FL_INT) {
		out = (double)fl_int(v);
		return true;
	}
	return false;
}
// OP_EQ_STR_CONST / Len(global) string compare. Length then memcmp, or
// nocasecmp under Option Compare Text.
FL_INLINE bool fl_str_eq(const String *a, const String *b, bool compare_text) {
	if (compare_text) {
		return a->nocasecmp_to(*b) == 0;
	}
	if (a->length() != b->length()) {
		return false;
	}
	if (a->length() == 0) {
		return true;
	}
	return memcmp(a->ptr(), b->ptr(), (size_t)a->length() * sizeof(char32_t)) == 0;
}

// OP_LEN. Same table as the interpreter: character count, collection size,
// and 0 for every other type.
FL_INLINE int64_t fl_len(const Variant *v, uint32_t t) {
	if (t == (uint32_t)Variant::STRING) {
		const String *s = VariantInternal::get_string(v);
		return s ? (int64_t)s->length() : 0;
	}
	if (t == (uint32_t)Variant::STRING_NAME) {
		return (int64_t)String(*v).length();
	}
	if (t == (uint32_t)Variant::ARRAY) return (int64_t)((Array)*v).size();
	if (t == (uint32_t)Variant::DICTIONARY) return (int64_t)((Dictionary)*v).size();
	if (t == (uint32_t)Variant::PACKED_BYTE_ARRAY) return (int64_t)((PackedByteArray)*v).size();
	if (t == (uint32_t)Variant::PACKED_INT32_ARRAY) return (int64_t)((PackedInt32Array)*v).size();
	if (t == (uint32_t)Variant::PACKED_INT64_ARRAY) return (int64_t)((PackedInt64Array)*v).size();
	if (t == (uint32_t)Variant::PACKED_FLOAT32_ARRAY) return (int64_t)((PackedFloat32Array)*v).size();
	if (t == (uint32_t)Variant::PACKED_FLOAT64_ARRAY) return (int64_t)((PackedFloat64Array)*v).size();
	if (t == (uint32_t)Variant::PACKED_STRING_ARRAY) return (int64_t)((PackedStringArray)*v).size();
	if (t == (uint32_t)Variant::PACKED_VECTOR2_ARRAY) return (int64_t)((PackedVector2Array)*v).size();
	if (t == (uint32_t)Variant::PACKED_VECTOR3_ARRAY) return (int64_t)((PackedVector3Array)*v).size();
	if (t == (uint32_t)Variant::PACKED_COLOR_ARRAY) return (int64_t)((PackedColorArray)*v).size();
	if (t == (uint32_t)Variant::PACKED_VECTOR4_ARRAY) return (int64_t)((PackedVector4Array)*v).size();
	return 0;
}
// The VM's to_bool() for the types that need no engine call.
FL_INLINE bool fl_truth(const Variant *v, bool &out) {
	switch (fl_type(v)) {
		case FL_BOOL:
			out = fl_bool(v);
			return true;
		case FL_INT:
			out = fl_int(v) != 0;
			return true;
		case FL_FLOAT:
			out = !Math::is_zero_approx(fl_float(v));
			return true;
		case FL_NIL:
			out = false;
			return true;
		default:
			return false;
	}
}

// One numeric slot of a ByRef body. k is 0 (Nothing), 1 (Integer), or 2 (Double).
struct FlNum {
	uint8_t k;
	int64_t i;
	double f;
};

FL_INLINE double fl_num_f(const FlNum &s) {
	if (s.k == 2) {
		return s.f;
	}
	if (s.k == 1) {
		return (double)s.i;
	}
	return 0.0;
}

FL_INLINE int64_t fl_num_i(const FlNum &s) {
	if (s.k == 1) {
		return s.i;
	}
	if (s.k == 2) {
		return (int64_t)s.f;
	}
	return 0;
}

// The body vg_chunk_byref_scalar or vg_chunk_nret accepted. Returns false
// before any caller local is written. Arithmetic matches the VM: F64 uses
// to_double, I64 uses to_int, and an I64-const opcode discards the pushed
// literal and adds the pool constant. OP_ADD / OP_SUBTRACT / OP_MULTIPLY
// keep an Integer result when both sides are Integer (Variant::OP_ADD).
// Len(global) uses gptrs[gidxs]. out is null for a Sub. A Function stores
// the Return value there.
static bool fl_byref_exec(BytecodeChunk *chunk, FlNum *loc, int nbody, FlNum *out,
		Variant *const *gptrs, const int32_t *gidxs, int ng) {
	const uint8_t *code = chunk->code.ptr();
	const int n = chunk->code.size();
	const Variant *consts = chunk->constants.ptr();
	const int nconst = chunk->constants.size();
	if (!code || n <= 0) {
		return false;
	}
	FlNum stk[16];
	int spn = 0;
	int ip = 0;
	while (ip < n) {
		const uint8_t op = code[ip];
		if (op == 0xFF) {
			ip += 1;
			continue;
		}
		if (op == OP_DEBUG_LINE) {
			if (ip + 2 >= n) {
				return false;
			}
			ip += 3;
			continue;
		}
		switch (op) {
			case OP_GET_LOCAL: {
				if (ip + 1 >= n) {
					return false;
				}
				const uint8_t slot = code[ip + 1];
				if (slot >= nbody || spn >= 16) {
					return false;
				}
				stk[spn++] = loc[slot];
				ip += 2;
				break;
			}
			case OP_SET_LOCAL: {
				if (ip + 1 >= n || spn < 1) {
					return false;
				}
				const uint8_t slot = code[ip + 1];
				if (slot >= nbody) {
					return false;
				}
				loc[slot] = stk[--spn];
				ip += 2;
				break;
			}
			case OP_GET_GLOBAL: {
				if (ip + 3 >= n || code[ip + 3] != OP_LEN || spn >= 16 || ng < 1 ||
						!gptrs || !gidxs) {
					return false;
				}
				const int idx = (int)code[ip + 1] | ((int)code[ip + 2] << 8);
				int gi = -1;
				for (int g = 0; g < ng; g++) {
					if (gidxs[g] == idx) {
						gi = g;
						break;
					}
				}
				if (gi < 0 || !gptrs[gi]) {
					return false;
				}
				stk[spn].k = 1;
				stk[spn].i = fl_len(gptrs[gi], fl_type(gptrs[gi]));
				stk[spn].f = 0.0;
				spn++;
				ip += 4;
				break;
			}
			case OP_CONSTANT:
			case OP_CONSTANT_LONG: {
				if (ip + 2 >= n || spn >= 16) {
					return false;
				}
				const int idx = (int)code[ip + 1] | ((int)code[ip + 2] << 8);
				if (idx < 0 || idx >= nconst) {
					return false;
				}
				const uint32_t ct = fl_type(consts + idx);
				FlNum &d = stk[spn];
				if (ct == FL_FLOAT) {
					d.k = 2;
					d.f = fl_float(consts + idx);
					d.i = 0;
				} else if (ct == FL_INT) {
					d.k = 1;
					d.i = fl_int(consts + idx);
					d.f = 0.0;
				} else {
					return false;
				}
				spn++;
				ip += 3;
				break;
			}
			case OP_ADD:
			case OP_SUBTRACT:
			case OP_MULTIPLY: {
				if (spn < 2) {
					return false;
				}
				const FlNum b = stk[--spn];
				const FlNum a = stk[--spn];
				if ((a.k != 1 && a.k != 2) || (b.k != 1 && b.k != 2)) {
					return false;
				}
				if (a.k == 1 && b.k == 1) {
					const int64_t av = a.i;
					const int64_t bv = b.i;
					int64_t r;
					if (op == OP_ADD) {
						r = (int64_t)((uint64_t)av + (uint64_t)bv);
					} else if (op == OP_SUBTRACT) {
						r = (int64_t)((uint64_t)av - (uint64_t)bv);
					} else {
						r = (int64_t)((uint64_t)av * (uint64_t)bv);
					}
					stk[spn].k = 1;
					stk[spn].i = r;
					stk[spn].f = 0.0;
				} else {
					const double av = fl_num_f(a);
					const double bv = fl_num_f(b);
					double r;
					if (op == OP_ADD) {
						r = av + bv;
					} else if (op == OP_SUBTRACT) {
						r = av - bv;
					} else {
						r = av * bv;
					}
					stk[spn].k = 2;
					stk[spn].f = r;
					stk[spn].i = 0;
				}
				spn++;
				ip += 1;
				break;
			}
			case OP_ADD_F64:
			case OP_SUB_F64:
			case OP_MUL_F64: {
				if (spn < 2) {
					return false;
				}
				const FlNum b = stk[--spn];
				const FlNum a = stk[--spn];
				const double av = fl_num_f(a);
				const double bv = fl_num_f(b);
				double r;
				if (op == OP_ADD_F64) {
					r = av + bv;
				} else if (op == OP_SUB_F64) {
					r = av - bv;
				} else {
					r = av * bv;
				}
				stk[spn].k = 2;
				stk[spn].f = r;
				stk[spn].i = 0;
				spn++;
				ip += 1;
				break;
			}
			case OP_ADD_I64:
			case OP_SUB_I64:
			case OP_MUL_I64: {
				if (spn < 2) {
					return false;
				}
				const FlNum b = stk[--spn];
				const FlNum a = stk[--spn];
				const int64_t av = fl_num_i(a);
				const int64_t bv = fl_num_i(b);
				int64_t r;
				if (op == OP_ADD_I64) {
					r = (int64_t)((uint64_t)av + (uint64_t)bv);
				} else if (op == OP_SUB_I64) {
					r = (int64_t)((uint64_t)av - (uint64_t)bv);
				} else {
					r = (int64_t)((uint64_t)av * (uint64_t)bv);
				}
				stk[spn].k = 1;
				stk[spn].i = r;
				stk[spn].f = 0.0;
				spn++;
				ip += 1;
				break;
			}
			case OP_ADD_I64_CONST:
			case OP_SUB_I64_CONST:
			case OP_MUL_I64_CONST: {
				if (spn < 2 || ip + 2 >= n) {
					return false;
				}
				const int idx = (int)code[ip + 1] | ((int)code[ip + 2] << 8);
				if (idx < 0 || idx >= nconst || fl_type(consts + idx) != FL_INT) {
					return false;
				}
				spn--;
				const FlNum a = stk[--spn];
				const int64_t av = fl_num_i(a);
				const int64_t c = fl_int(consts + idx);
				int64_t r;
				if (op == OP_ADD_I64_CONST) {
					r = (int64_t)((uint64_t)av + (uint64_t)c);
				} else if (op == OP_SUB_I64_CONST) {
					r = (int64_t)((uint64_t)av - (uint64_t)c);
				} else {
					r = (int64_t)((uint64_t)av * (uint64_t)c);
				}
				stk[spn].k = 1;
				stk[spn].i = r;
				stk[spn].f = 0.0;
				spn++;
				ip += 3;
				break;
			}
			case OP_TO_F64: {
				if (spn < 1) {
					return false;
				}
				FlNum &a = stk[spn - 1];
				if (a.k == 1) {
					a.k = 2;
					a.f = (double)a.i;
				} else if (a.k != 2) {
					a.k = 2;
					a.f = 0.0;
					a.i = 0;
				}
				ip += 1;
				break;
			}
			case OP_NEGATE: {
				if (spn < 1) {
					return false;
				}
				FlNum &a = stk[spn - 1];
				if (a.k == 2) {
					a.f = -a.f;
				} else if (a.k == 1) {
					a.i = (int64_t)(0ULL - (uint64_t)a.i);
				} else {
					return false;
				}
				ip += 1;
				break;
			}
			case OP_POP:
				if (spn < 1) {
					return false;
				}
				spn--;
				ip += 1;
				break;
			case OP_RETURN:
				if (out) {
					return false;
				}
				return true;
			case OP_RETURN_VALUE:
				if (!out || spn < 1) {
					return false;
				}
				if (stk[spn - 1].k != 1 && stk[spn - 1].k != 2) {
					return false;
				}
				*out = stk[spn - 1];
				return true;
			default:
				return false;
		}
	}
	return false;
}

// Statement call: OP_CALL, OP_POP, then one OP_BYREF_LOAD + OP_SET_LOCAL per
// ByRef parameter, in parameter order, each storing a local. Returns the
// instruction after those write-backs, or null when this site stays on the
// ordinary handler. Nothing in the caller is written until the body finishes.
static const uint8_t *fl_byref_run(BytecodeChunk *chunk, SubDefinition *func,
		const uint8_t *pc, const uint8_t *code_end, Variant *args_top, int argc,
		Variant *L, uint32_t nloc, const uint8_t *ltypes, uint32_t ntypes,
		int64_t *ti, double *tf) __attribute__((noinline));

static const uint8_t *fl_byref_run(BytecodeChunk *chunk, SubDefinition *func,
		const uint8_t *pc, const uint8_t *code_end, Variant *args_top, int argc,
		Variant *L, uint32_t nloc, const uint8_t *ltypes, uint32_t ntypes,
		int64_t *ti, double *tf) {
	if (!chunk || !func || argc < 1 || argc > 8 || chunk->param_count != argc ||
			func->parameters.size() != argc || chunk->fast_param_coerce.size() != argc) {
		return nullptr;
	}
	const int nbody = chunk->local_count;
	if (nbody < argc || nbody > 32) {
		return nullptr;
	}
	int pref[8];
	int nref = 0;
	for (int i = 0; i < argc; i++) {
		if (func->parameters[i].is_by_ref) {
			pref[nref++] = i;
		}
	}
	if (nref == 0 || (ptrdiff_t)(code_end - pc) < 5 || pc[4] != OP_POP) {
		return nullptr;
	}
	const uint8_t *q = pc + 5;
	int dests[8];
	for (int r = 0; r < nref; r++) {
		if ((ptrdiff_t)(code_end - q) < 8 || q[0] != OP_BYREF_LOAD || q[3] != 0) {
			return nullptr;
		}
		const uint32_t dest = (uint32_t)q[4] | ((uint32_t)q[5] << 8);
		if (q[6] != OP_SET_LOCAL || (uint32_t)q[7] != dest || dest >= nloc) {
			return nullptr;
		}
		dests[r] = (int)dest;
		q += 8;
	}
	const int8_t *coerce = chunk->fast_param_coerce.ptr();
	FlNum loc[32];
	for (int i = 0; i < nbody; i++) {
		loc[i].k = 0;
		loc[i].i = 0;
		loc[i].f = 0.0;
	}
	for (int i = 0; i < argc; i++) {
		const Variant *arg = args_top - argc + i;
		const uint32_t t = fl_type(arg);
		FlNum &dst = loc[i];
		if (coerce[i] == 2) {
			if (t == FL_FLOAT) {
				dst.k = 2;
				dst.f = fl_float(arg);
			} else if (t == FL_INT) {
				dst.k = 2;
				dst.f = (double)fl_int(arg);
			} else if (t == FL_BOOL) {
				dst.k = 2;
				dst.f = fl_bool(arg) ? 1.0 : 0.0;
			} else if (t == FL_NIL) {
				dst.k = 2;
				dst.f = 0.0;
			} else {
				return nullptr;
			}
		} else if (coerce[i] == 1) {
			if (t == FL_INT) {
				dst.k = 1;
				dst.i = fl_int(arg);
			} else if (t == FL_FLOAT) {
				dst.k = 1;
				dst.i = VisualGasicInstance::vb_round_half_even(fl_float(arg));
			} else if (t == FL_BOOL) {
				dst.k = 1;
				dst.i = fl_bool(arg) ? (int64_t)1 : (int64_t)0;
			} else if (t == FL_NIL) {
				dst.k = 1;
				dst.i = 0;
			} else {
				return nullptr;
			}
		} else {
			return nullptr;
		}
	}
	if (!fl_byref_exec(chunk, loc, nbody, nullptr, nullptr, nullptr, 0)) {
		return nullptr;
	}
	for (int r = 0; r < nref; r++) {
		const FlNum &s = loc[pref[r]];
		if (s.k != 1 && s.k != 2) {
			return nullptr;
		}
		Variant *dst = L + dests[r];
		if (!fl_pod(fl_type(dst))) {
			return nullptr;
		}
		const uint32_t lt = (uint32_t)dests[r] < ntypes ? ltypes[dests[r]] : 0;
		if ((lt == 1 && ti == nullptr) || (lt == 2 && tf == nullptr)) {
			return nullptr;
		}
	}
	for (int r = 0; r < nref; r++) {
		const FlNum &s = loc[pref[r]];
		const int dest = dests[r];
		Variant *dst = L + dest;
		const uint32_t lt = (uint32_t)dest < ntypes ? ltypes[dest] : 0;
		if (s.k == 2) {
			fl_put_float(dst, s.f);
			if (lt == 2) {
				tf[dest] = s.f;
			} else if (lt == 1) {
				ti[dest] = (int64_t)s.f;
			}
		} else {
			fl_put_int(dst, s.i);
			if (lt == 1) {
				ti[dest] = s.i;
			} else if (lt == 2) {
				tf[dest] = (double)s.i;
			}
		}
	}
	return q;
}

// vg_chunk_nret. The Return value replaces the arguments. The caller's next
// instruction (the assignment, or a POP) still runs. gptrs are the module
// values Len(global) reads; ng is 0 when the body has no Len(global).
static bool fl_nret_run(BytecodeChunk *chunk, SubDefinition *func,
		Variant *args_top, int argc, FlNum &result,
		Variant *const *gptrs, const int32_t *gidxs, int ng) __attribute__((noinline));

static bool fl_nret_run(BytecodeChunk *chunk, SubDefinition *func,
		Variant *args_top, int argc, FlNum &result,
		Variant *const *gptrs, const int32_t *gidxs, int ng) {
	if (!chunk || !func || argc < 1 || argc > 8 || chunk->param_count != argc ||
			func->parameters.size() != argc || chunk->fast_param_coerce.size() != argc) {
		return false;
	}
	if (ng < 0 || ng > 4 || (ng > 0 && (!gptrs || !gidxs))) {
		return false;
	}
	const int nbody = chunk->local_count;
	if (nbody < argc || nbody > 32) {
		return false;
	}
	for (int i = 0; i < argc; i++) {
		if (func->parameters[i].is_by_ref) {
			return false;
		}
	}
	const int8_t *coerce = chunk->fast_param_coerce.ptr();
	FlNum loc[32];
	for (int i = 0; i < nbody; i++) {
		loc[i].k = 0;
		loc[i].i = 0;
		loc[i].f = 0.0;
	}
	for (int i = 0; i < argc; i++) {
		const Variant *arg = args_top - argc + i;
		const uint32_t t = fl_type(arg);
		FlNum &dst = loc[i];
		if (coerce[i] == 2) {
			if (t == FL_FLOAT) {
				dst.k = 2;
				dst.f = fl_float(arg);
			} else if (t == FL_INT) {
				dst.k = 2;
				dst.f = (double)fl_int(arg);
			} else if (t == FL_BOOL) {
				dst.k = 2;
				dst.f = fl_bool(arg) ? 1.0 : 0.0;
			} else if (t == FL_NIL) {
				dst.k = 2;
				dst.f = 0.0;
			} else {
				return false;
			}
		} else if (coerce[i] == 1) {
			if (t == FL_INT) {
				dst.k = 1;
				dst.i = fl_int(arg);
			} else if (t == FL_FLOAT) {
				dst.k = 1;
				dst.i = VisualGasicInstance::vb_round_half_even(fl_float(arg));
			} else if (t == FL_BOOL) {
				dst.k = 1;
				dst.i = fl_bool(arg) ? (int64_t)1 : (int64_t)0;
			} else if (t == FL_NIL) {
				dst.k = 1;
				dst.i = 0;
			} else {
				return false;
			}
		} else {
			return false;
		}
	}
	return fl_byref_exec(chunk, loc, nbody, &result, gptrs, gidxs, ng);
}

} // namespace

int VisualGasicInstance::vm_fast_run(const VMFastFrame &f, int p_ip) {
	// Handler address per opcode; an opcode without one leaves the loop.
	static const void *labels[256];
	static std::atomic<bool> labels_ready{ false };
	if (FL_UNLIKELY(!labels_ready.load(std::memory_order_acquire))) {
		static std::mutex labels_mutex;
		std::lock_guard<std::mutex> labels_lock(labels_mutex);
		if (!labels_ready.load(std::memory_order_relaxed)) {
			for (int i = 0; i < 256; i++) {
				labels[i] = &&fl_leave;
			}
#define FL_SET_LABEL(opcode, name) labels[opcode] = &&fl_##name;
			VG_FASTLOOP_OPS(FL_SET_LABEL)
#undef FL_SET_LABEL
			labels_ready.store(true, std::memory_order_release);
		}
	}

	// The frame, as execute_bytecode() describes it (VMFastFrame): read where
	// it is used.
	const uint8_t *const &code = f.code;
	const uint8_t *const &safe_end = f.safe_end;
	const Variant *const &K = f.constants;
	const uint32_t &nconst = f.constant_count;
	const uint8_t *const &ltypes = f.local_types;
	const uint32_t &ntypes = f.local_type_count;
	int64_t *const &ti = f.typed_i64;
	double *const &tf = f.typed_f64;
	const bool compare_text = f.compare_text;

	const uint8_t *pc = code + p_ip;

	vgfast::VariantStack &stack = *f.stack;
	Variant *data = stack.raw_data();
	Variant *sp = data + stack.size();          // one past the top element
	Variant *floor = data + f.stack_base;       // this frame's first operand
	Variant *limit = data + stack.capacity();

	Vector<Variant> &locals_vec = *f.locals;
	Variant *const L = locals_vec.ptrw();       // unshares, as the next locals.write[] would
	const uint32_t nloc = (uint32_t)locals_vec.size();

	// OP_DEBUG_LINE: resolved at the first line marker of this call.
	// 0 = leave to the ordinary handler, 1 = host script, 2 = Import module.
	int dbg_mode = -1;

// The bound covers an instruction of up to three bytes (VMFastFrame::safe_end).
#define FL_NEXT() \
	do { \
		if (FL_UNLIKELY(pc >= safe_end)) { \
			goto fl_leave; \
		} \
		goto *labels[*pc]; \
	} while (0)
// At least `n` operands of this frame on the stack, else the ordinary
// handler reports the underflow.  (Signed: a stack below the frame's base
// is an underflow too, as it is for ensure_stack().)
#define FL_NEED(n) \
	if (FL_UNLIKELY((reinterpret_cast<const uint8_t *>(sp) - reinterpret_cast<const uint8_t *>(floor)) < (ptrdiff_t)((n) * FL_VSZ))) { \
		goto fl_leave; \
	}
#define FL_ROOM() \
	if (FL_UNLIKELY(sp == limit)) { \
		goto fl_grow; \
	}
#define FL_U16_LE(at) ((uint32_t)pc[at] | ((uint32_t)pc[(at) + 1] << 8))
#define FL_U16_BE(at) (((uint32_t)pc[at] << 8) | (uint32_t)pc[(at) + 1])
// For an instruction of 3 + `extra` bytes: all of it lies inside the code.
#define FL_LONG(extra) \
	if (FL_UNLIKELY((size_t)(safe_end - pc) <= (size_t)(extra))) { \
		goto fl_leave; \
	}

	FL_NEXT();

	// ── Loads ──────────────────────────────────────────────────────────────

fl_constant: { // OP_CONSTANT / OP_CONSTANT_LONG [const lo] [const hi]
	const uint32_t idx = FL_U16_LE(1);
	if (FL_UNLIKELY(idx >= nconst)) {
		goto fl_leave;
	}
	FL_ROOM();
	const Variant *src = K + idx;
	if (FL_LIKELY(fl_pod(fl_type(src)))) {
		fl_copy(sp, src);
	} else {
		new (sp) Variant(*src);
	}
	sp++;
	pc += 3;
	FL_NEXT();
}

fl_lit_nil: { // OP_NIL
	FL_ROOM();
	memset(static_cast<void *>(sp), 0, FL_VSZ);
	sp++;
	pc += 1;
	FL_NEXT();
}

fl_lit_true: { // OP_TRUE
	FL_ROOM();
	fl_put_bool(sp, true);
	sp++;
	pc += 1;
	FL_NEXT();
}

fl_lit_false: { // OP_FALSE
	FL_ROOM();
	fl_put_bool(sp, false);
	sp++;
	pc += 1;
	FL_NEXT();
}

fl_get_local: { // OP_GET_LOCAL [slot]
	const uint32_t slot = pc[1];
	if (FL_UNLIKELY(slot >= nloc)) {
		goto fl_leave;
	}
	const Variant *src = L + slot;
	const uint32_t t = fl_type(src);
	FL_ROOM();
	if (FL_LIKELY(fl_pod(t))) {
		// Nothing in an undeclared slot is a control / form name lookup.
		if (FL_UNLIKELY(t == FL_NIL) && !(slot < f.local_declared_count && f.local_declared[slot] != 0)) {
			goto fl_leave;
		}
		fl_copy(sp, src);
	} else {
		new (sp) Variant(*src);
	}
	sp++;
	pc += 2;
	FL_NEXT();
}

fl_get_local_axis: { // OP_GET_LOCAL_AXIS [slot] [axis] [skip hi] [skip lo]
	// Vector2/Vector3 component as a Double. The generic member code after
	// this instruction runs for every other type.
	FL_LONG(2)
	const uint32_t slot = pc[1];
	const uint32_t axis = pc[2];
	if (FL_UNLIKELY(slot >= nloc || !vgfast::g_layout_ok)) {
		goto fl_leave;
	}
	const Variant *src = L + slot;
	const uint32_t bt = fl_type(src);
	double component;
	if (bt == (uint32_t)Variant::VECTOR2 && axis <= 1) {
		component = (double)vgfast::vvec2(*src)[axis];
	} else if (bt == (uint32_t)Variant::VECTOR3 && axis <= 2) {
		component = (double)vgfast::vvec3(*src)[axis];
	} else {
		goto fl_leave;
	}
	FL_ROOM();
	fl_put_float(sp, component);
	sp++;
	pc += 5 + FL_U16_BE(3);
	FL_NEXT();
}

fl_set_local_axis: { // OP_SET_LOCAL_AXIS [slot] [axis] [skip hi] [skip lo]
	// Numeric write into a Vector2/Vector3, in place. The ordinary handler
	// does the generic SET_MEMBER path, including a non-numeric value.
	FL_LONG(2)
	FL_NEED(1);
	const uint32_t slot = pc[1];
	const uint32_t axis = pc[2];
	double d;
	if (FL_UNLIKELY(slot >= nloc || !vgfast::g_layout_ok || !fl_as_f64(sp - 1, d))) {
		goto fl_leave;
	}
	Variant *dst = L + slot;
	const uint32_t bt = fl_type(dst);
	if (bt == (uint32_t)Variant::VECTOR2 && axis <= 1) {
		Vector2 v = vgfast::vvec2(*dst);
		v[axis] = (real_t)d;
		vgfast::raw_init_vector2(dst, v);
	} else if (bt == (uint32_t)Variant::VECTOR3 && axis <= 2) {
		Vector3 v = vgfast::vvec3(*dst);
		v[axis] = (real_t)d;
		vgfast::raw_init_vector3(dst, v);
	} else {
		goto fl_leave;
	}
	sp--;
	pc += 5 + FL_U16_BE(3);
	FL_NEXT();
}

fl_add_local_vec2_const: { // OP_ADD_LOCAL_VEC2_CONST [slot] [const lo] [const hi]
	FL_LONG(1)
	const uint32_t slot = pc[1];
	const uint32_t idx = FL_U16_LE(2);
	if (FL_UNLIKELY(slot >= nloc || idx >= nconst || !vgfast::g_layout_ok)) {
		goto fl_leave;
	}
	const Variant *c = K + idx;
	Variant *dst = L + slot;
	if (FL_UNLIKELY(fl_type(dst) != (uint32_t)Variant::VECTOR2 ||
			fl_type(c) != (uint32_t)Variant::VECTOR2)) {
		goto fl_leave;
	}
	vgfast::raw_init_vector2(dst, vgfast::vvec2(*dst) + vgfast::vvec2(*c));
	pc += 4;
	FL_NEXT();
}

fl_get_global: { // OP_GET_GLOBAL [name lo] [name hi]
	// Only the memoized hit of a plain module variable: the value pointer
	// cached at this site is current and the value is not Nothing.  First
	// reads, special names (Me, Err, ...), builtin constants, autoloads and
	// owner properties are the ordinary handler's.
	const uint32_t idx = FL_U16_LE(1);
	if (FL_UNLIKELY(idx >= nconst)) {
		goto fl_leave;
	}
	const Vector<MemberNameCacheEntry> &memo = *f.member_cache;
	if (FL_UNLIKELY((uint32_t)memo.size() != nconst)) {
		goto fl_leave;
	}
	const MemberNameCacheEntry &e = memo.ptr()[idx];
	if (FL_UNLIKELY(!e.initialized || e.is_special_global != 0 || e.gptr == nullptr ||
				e.gptr_gen != variables.generation)) {
		goto fl_leave;
	}
	const Variant *src = e.gptr;
	const uint32_t t = fl_type(src);
	// Len(global) pushes the length. Copying a String or Dictionary onto
	// the stack first would refcount it, and OP_LEN is not itself in this
	// loop, so the rest of the call would leave too.
	if ((size_t)(safe_end - pc) > 3 && pc[3] == OP_LEN) {
		FL_ROOM();
		fl_put_int(sp, fl_len(src, t));
		sp++;
		pc += 4;
		FL_NEXT();
	}
	if (FL_UNLIKELY(t == FL_NIL)) {
		goto fl_leave;
	}
	// Dictionary global followed by a constant-key read: look the key up in
	// the global and push the value. Copying the Dictionary onto the stack
	// first would refcount it on every iteration.
	if (t == (uint32_t)Variant::DICTIONARY && (size_t)(safe_end - pc) > 3 &&
			pc[3] == OP_GET_DICT_CONST) {
		const uint32_t kidx = (uint32_t)pc[4] | ((uint32_t)pc[5] << 8);
		if (kidx < nconst && fl_type(K + kidx) != FL_FLOAT) {
			FL_ROOM();
			alignas(Variant) unsigned char raw[FL_VSZ];
			memset(raw, 0, sizeof(raw));
			GDExtensionBool valid = false;
			godot::internal::gdextension_interface_variant_get_keyed(
					const_cast<Variant *>(src)->_native_ptr(),
					const_cast<Variant *>(K + kidx)->_native_ptr(), raw, &valid);
			(void)valid;
			memcpy(static_cast<void *>(sp), raw, FL_VSZ);
			sp++;
			pc += 6;
			FL_NEXT();
		}
	}
	// String global compared to a constant. The compare reads the module
	// value in place so the String is not refcounted onto the stack.
	if (t == (uint32_t)Variant::STRING && (size_t)(safe_end - pc) > 5 &&
			pc[3] == OP_EQ_STR_CONST) {
		const uint32_t kidx = (uint32_t)pc[4] | ((uint32_t)pc[5] << 8);
		if (kidx < nconst && fl_type(K + kidx) == (uint32_t)Variant::STRING) {
			const String *a = VariantInternal::get_string(src);
			const String *b = VariantInternal::get_string(K + kidx);
			if (FL_LIKELY(a && b)) {
				FL_ROOM();
				fl_put_bool(sp, fl_str_eq(a, b, compare_text));
				sp++;
				pc += 6;
				FL_NEXT();
			}
		}
	}
	FL_ROOM();
	if (FL_LIKELY(fl_pod(t))) {
		fl_copy(sp, src);
	} else {
		new (sp) Variant(*src);
	}
	sp++;
	pc += 3;
	FL_NEXT();
}

fl_set_global: { // OP_SET_GLOBAL [name lo] [name hi]
	// An Integer already in an Integer module variable, written now.
	// Leaves the store alone when the value still needs CLng's other
	// cases, the slot is not an Integer, a watchpoint or a Whenever
	// section or an evidence recorder is listening, or this frame has
	// not yet snapshotted the pre-write value.  That first store is the
	// ordinary handler, which records it; later stores of the same
	// global find the bit set and write here.
	FL_NEED(1);
	const uint32_t idx = FL_U16_LE(1);
	if (FL_UNLIKELY(idx >= nconst)) {
		goto fl_leave;
	}
	const Vector<MemberNameCacheEntry> &memo = *f.member_cache;
	if (FL_UNLIKELY((uint32_t)memo.size() != nconst)) {
		goto fl_leave;
	}
	const MemberNameCacheEntry &e = memo.ptr()[idx];
	if (FL_UNLIKELY(!e.initialized || e.gptr == nullptr || e.gptr_gen != variables.generation)) {
		goto fl_leave;
	}
	Variant *dst = e.gptr;
	const Variant *src = sp - 1;
	if (FL_UNLIKELY(fl_type(dst) != FL_INT || fl_type(src) != FL_INT)) {
		goto fl_leave;
	}
	if (FL_UNLIKELY(VisualGasicLanguage::has_watchpoints() || vg_evidence_recording())) {
		goto fl_leave;
	}
	if (FL_UNLIKELY(!whenever_init_suppress && !whenever_sections.is_empty())) {
		goto fl_leave;
	}
	if (f.snapshot_globals_active) {
		const int gi = e.gw_index;
		if (FL_UNLIKELY(gi < 0 || f.gw_bits == nullptr)) {
			goto fl_leave;
		}
		const uint64_t mask = (uint64_t)1 << (gi & 63);
		if (FL_UNLIKELY((f.gw_bits[gi >> 6] & mask) == 0)) {
			goto fl_leave;
		}
	}
	fl_put_int(dst, fl_int(src));
	sp--;
	pc += 3;
	FL_NEXT();
}

fl_eq_str_const: { // OP_EQ_STR_CONST [const lo] [const hi]
	// Two strings: length then memcmp, or nocasecmp under Option Compare
	// Text. The string on the stack is released and replaced with a Boolean.
	// Anything else (a number equal to a numeric string, a non-string
	// constant) is the ordinary handler, which has not been started.
	FL_NEED(1);
	const uint32_t idx = FL_U16_LE(1);
	if (FL_UNLIKELY(idx >= nconst)) {
		goto fl_leave;
	}
	Variant *top = sp - 1;
	const Variant *lit = K + idx;
	if (FL_UNLIKELY(fl_type(top) != (uint32_t)Variant::STRING ||
			fl_type(lit) != (uint32_t)Variant::STRING)) {
		goto fl_leave;
	}
	const String *a = VariantInternal::get_string(top);
	const String *b = VariantInternal::get_string(lit);
	if (FL_UNLIKELY(!a || !b)) {
		goto fl_leave;
	}
	const bool eq = fl_str_eq(a, b, compare_text);
	{
		alignas(Variant) uint8_t old[FL_VSZ];
		memcpy(old, static_cast<const void *>(top), FL_VSZ);
		fl_put_bool(top, eq);
		pc += 3;
		reinterpret_cast<Variant *>(old)->~Variant();
	}
	FL_NEXT();
}

fl_get_dict_const: { // OP_GET_DICT_CONST [const lo] [const hi]
	// Dictionary on the stack, key already built in the constant pool.
	// A float key is normalized by the ordinary handler. A missing key
	// pushes Nothing, the same as OP_GET_DICT_FAST.
	FL_NEED(1);
	const uint32_t idx = FL_U16_LE(1);
	if (FL_UNLIKELY(idx >= nconst)) {
		goto fl_leave;
	}
	Variant *base = sp - 1;
	const Variant *key = K + idx;
	if (FL_UNLIKELY(fl_type(base) != (uint32_t)Variant::DICTIONARY ||
			fl_type(key) == FL_FLOAT)) {
		goto fl_leave;
	}
	{
		alignas(Variant) unsigned char raw[FL_VSZ];
		memset(raw, 0, sizeof(raw));
		GDExtensionBool valid = false;
		godot::internal::gdextension_interface_variant_get_keyed(
				const_cast<Variant *>(base)->_native_ptr(),
				const_cast<Variant *>(key)->_native_ptr(), raw, &valid);
		(void)valid;
		alignas(Variant) uint8_t old[FL_VSZ];
		memcpy(old, static_cast<const void *>(base), FL_VSZ);
		memcpy(static_cast<void *>(base), raw, FL_VSZ);
		pc += 3;
		reinterpret_cast<Variant *>(old)->~Variant();
	}
	FL_NEXT();
}

fl_call: { // OP_CALL [name lo] [name hi] [argc]
	// A zero-argument function whose body is `Return <constant>` pushes
	// that constant. A straight-line numeric Sub with ByRef scalars runs
	// its body here and writes the caller's locals. A straight-line
	// numeric Function leaves its Return value where the arguments were.
	// CInt / CLng / CLngLng of one number, Nothing or Boolean: the same
	// vb_to_integer the builtin cascade returns. A String or any other
	// value, and every other call, stays on the ordinary handler.
	FL_LONG(1);
	const uint32_t idx = FL_U16_LE(1);
	if (FL_UNLIKELY(idx >= nconst)) {
		goto fl_leave;
	}
	if (pc[3] == 0) {
		const Vector<MemberNameCacheEntry> &memo = *f.member_cache;
		if (FL_UNLIKELY((uint32_t)memo.size() != nconst)) {
			goto fl_leave;
		}
		const MemberNameCacheEntry &e = memo.ptr()[idx];
		if (e.leaf_kind < 2) {
			goto fl_leave;
		}
		FL_ROOM();
		if (e.leaf_kind == 2) {
			fl_put_int(sp, e.leaf_i64);
		} else if (e.leaf_kind == 3) {
			fl_put_float(sp, e.leaf_f64);
		} else if (e.leaf_kind == 4) {
			fl_put_bool(sp, e.leaf_i64 != 0);
		} else if (e.leaf_kind == 5) {
			memset(static_cast<void *>(sp), 0, FL_VSZ);
		} else {
			goto fl_leave;
		}
		sp++;
		pc += 4;
		FL_NEXT();
	}
	const int argc = (int)pc[3];
	if (FL_UNLIKELY(argc < 1)) {
		goto fl_leave;
	}
	FL_NEED(argc);
	const Vector<MemberNameCacheEntry> &memo = *f.member_cache;
	if (FL_UNLIKELY((uint32_t)memo.size() != nconst)) {
		goto fl_leave;
	}
	const MemberNameCacheEntry &e = memo.ptr()[idx];
	// A straight-line ByRef Sub. The first call classifies it. A watchpoint,
	// an evidence recorder, or a Whenever section still enters the Sub.
	// The POP and the local write-backs that follow a statement call are
	// skipped: the body already stored those locals.
	if (e.bref_kind >= 2) {
		if (FL_UNLIKELY(VisualGasicLanguage::has_watchpoints() || vg_evidence_recording())) {
			goto fl_leave;
		}
		if (FL_UNLIKELY(!whenever_init_suppress && !whenever_sections.is_empty())) {
			goto fl_leave;
		}
		const uint8_t *next = fl_byref_run(e.bref_chunk, e.bref_func, pc, safe_end + 2, sp, argc, L, nloc, ltypes, ntypes, ti, tf);
		if (next) {
			sp -= argc;
			pc = next;
			FL_NEXT();
		}
	}
	// A straight-line numeric Function. The first call classifies it. The
	// Return value replaces the arguments, so the assignment after the call
	// still runs here. Len(global) needs the memoized module pointers. A
	// watchpoint, an evidence recorder, or a Whenever section still enters
	// the Function.
	if (e.nret_kind >= 2) {
		if (FL_UNLIKELY(VisualGasicLanguage::has_watchpoints() || vg_evidence_recording())) {
			goto fl_leave;
		}
		if (FL_UNLIKELY(!whenever_init_suppress && !whenever_sections.is_empty())) {
			goto fl_leave;
		}
		if (FL_UNLIKELY(e.nret_ng > 0)) {
			if (e.nret_ggen != variables.generation) {
				goto fl_leave;
			}
			for (int g = 0; g < e.nret_ng; g++) {
				if (FL_UNLIKELY(e.nret_gptr[g] == nullptr)) {
					goto fl_leave;
				}
			}
		}
		FlNum result;
		if (fl_nret_run(e.nret_chunk, e.nret_func, sp, argc, result,
				e.nret_ng > 0 ? e.nret_gptr : nullptr,
				e.nret_ng > 0 ? e.nret_gconst : nullptr, e.nret_ng)) {
			Variant *dst = sp - argc;
			if (result.k == 2) {
				fl_put_float(dst, result.f);
			} else {
				fl_put_int(dst, result.i);
			}
			sp = dst + 1;
			pc += 4;
			FL_NEXT();
		}
	}
	if (FL_UNLIKELY(argc != 1)) {
		goto fl_leave;
	}
	Variant *top = sp - 1;
	// A Sub whose body is one module number plus this argument. The
	// first call classifies it. A watchpoint, an evidence recorder, or
	// a Whenever section still enters the Sub. A statement call's POP
	// is the Nothing the Sub would have pushed.
	if (e.gadd_kind >= 2) {
		if (FL_UNLIKELY(e.gadd_ptr == nullptr || e.gadd_gen != variables.generation)) {
			goto fl_leave;
		}
		if (FL_UNLIKELY(VisualGasicLanguage::has_watchpoints() || vg_evidence_recording())) {
			goto fl_leave;
		}
		if (FL_UNLIKELY(!whenever_init_suppress && !whenever_sections.is_empty())) {
			goto fl_leave;
		}
		Variant *dst = e.gadd_ptr;
		const uint32_t dt = fl_type(dst);
		const uint32_t at = fl_type(top);
		if (e.gadd_kind == 2) {
			double argd;
			if (e.gadd_coerce == 1) {
				if (at != FL_INT) {
					goto fl_leave;
				}
				argd = (double)fl_int(top);
			} else if (e.gadd_coerce == 0 || e.gadd_coerce == 2) {
				if (!fl_as_f64(top, argd)) {
					goto fl_leave;
				}
			} else {
				goto fl_leave;
			}
			double base;
			if (dt == FL_FLOAT) {
				base = fl_float(dst);
			} else if (dt == FL_INT) {
				base = (double)fl_int(dst);
			} else {
				goto fl_leave;
			}
			const double sum = e.gadd_arg_left ? argd + base : base + argd;
			if (dt == FL_FLOAT) {
				fl_put_float(dst, sum);
			} else {
				fl_put_int(dst, (int64_t)sum);
			}
		} else if (e.gadd_kind == 3) {
			if ((e.gadd_coerce != 0 && e.gadd_coerce != 1) || at != FL_INT) {
				goto fl_leave;
			}
			if (dt != FL_INT && dt != FL_FLOAT) {
				goto fl_leave;
			}
			const int64_t argi = fl_int(top);
			const int64_t base = dt == FL_INT ? fl_int(dst) : (int64_t)fl_float(dst);
			const int64_t left = e.gadd_arg_left ? argi : base;
			const int64_t right = e.gadd_arg_left ? base : argi;
			const int64_t sum = (int64_t)((uint64_t)left + (uint64_t)right);
			if (e.gadd_to_f64) {
				const double as_f = (double)sum;
				if (dt == FL_FLOAT) {
					fl_put_float(dst, as_f);
				} else {
					fl_put_int(dst, (int64_t)as_f);
				}
			} else if (dt == FL_INT) {
				fl_put_int(dst, sum);
			} else {
				fl_put_float(dst, (double)sum);
			}
		} else {
			goto fl_leave;
		}
		if ((size_t)(safe_end - pc) > 2 && pc[4] == OP_POP) {
			sp--;
			pc += 5;
		} else {
			memset(static_cast<void *>(top), 0, FL_VSZ);
			pc += 4;
		}
		FL_NEXT();
	}
	if (FL_UNLIKELY(!e.initialized || e.pure_builtin != MemberNameCacheEntry::PB_TO_I64)) {
		goto fl_leave;
	}
	const uint32_t t = fl_type(top);
	if (t == FL_INT) {
		// Already an Integer. vb_to_integer returns it unchanged.
	} else if (t == FL_FLOAT) {
		fl_put_int(top, vb_round_half_even(fl_float(top)));
	} else if (t == FL_BOOL) {
		fl_put_int(top, fl_bool(top) ? (int64_t)1 : (int64_t)0);
	} else if (t == FL_NIL) {
		fl_put_int(top, (int64_t)0);
	} else {
		goto fl_leave;
	}
	pc += 4;
	FL_NEXT();
}

	// ── Stores and drops ───────────────────────────────────────────────────

fl_set_local: { // OP_SET_LOCAL [slot]
	const uint32_t slot = pc[1];
	if (FL_UNLIKELY(sp <= floor || slot >= nloc)) {
		goto fl_leave;
	}
	const Variant *src = sp - 1;
	Variant *dst = L + slot;
	const uint32_t ts = fl_type(src);
	// Typed shadow of an Integer / Double slot, converted as
	// sync_local_tail() does for a number; other values go to it.
	const uint32_t lt = slot < ntypes ? ltypes[slot] : 0;
	int64_t shadow_i = 0;
	double shadow_f = 0.0;
	if (lt == 1) {
		if (ts == FL_INT) {
			shadow_i = fl_int(src);
		} else if (ts == FL_FLOAT) {
			shadow_i = (int64_t)fl_float(src);
		} else {
			goto fl_leave;
		}
	} else if (lt == 2) {
		if (ts == FL_FLOAT) {
			shadow_f = fl_float(src);
		} else if (ts == FL_INT) {
			shadow_f = (double)fl_int(src);
		} else {
			goto fl_leave;
		}
	}
	if (FL_LIKELY(fl_pod(fl_type(dst)))) {
		// The value moves into the slot; the stack entry is dropped as is.
		fl_copy(dst, src);
		sp--;
		if (lt == 1) {
			ti[slot] = shadow_i;
		} else if (lt == 2) {
			tf[slot] = shadow_f;
		}
		pc += 2;
		FL_NEXT();
	}
	{
		// The slot holds a String/Array/Object: complete the store, publish
		// the stack, release the old value last and return.
		alignas(Variant) uint8_t old[FL_VSZ];
		memcpy(old, static_cast<const void *>(dst), FL_VSZ);
		fl_copy(dst, src);
		sp--;
		if (lt == 1) {
			ti[slot] = shadow_i;
		} else if (lt == 2) {
			tf[slot] = shadow_f;
		}
		pc += 2;
		stack.raw_set_size((size_t)(sp - data));
		reinterpret_cast<Variant *>(old)->~Variant();
		return (int)(pc - code);
	}
}

fl_pop: { // OP_POP (nothing to drop is not an error)
	if (FL_LIKELY(sp > floor)) {
		Variant *top = sp - 1;
		if (FL_UNLIKELY(!fl_pod(fl_type(top)))) {
			alignas(Variant) uint8_t old[FL_VSZ];
			memcpy(old, static_cast<const void *>(top), FL_VSZ);
			sp--;
			pc += 1;
				stack.raw_set_size((size_t)(sp - data));
			reinterpret_cast<Variant *>(old)->~Variant();
			return (int)(pc - code);
		}
		sp--;
	}
	pc += 1;
	FL_NEXT();
}

	// ── Arithmetic ─────────────────────────────────────────────────────────

fl_to_f64: { // OP_TO_F64: Integer -> Double in place
	FL_NEED(1);
	Variant *top = sp - 1;
	const uint32_t t = fl_type(top);
	if (t == FL_INT) {
		fl_put_float(top, (double)fl_int(top));
	} else if (FL_UNLIKELY(t != FL_FLOAT)) {
		goto fl_leave;
	}
	pc += 1;
	FL_NEXT();
}

// OP_ADD / OP_SUBTRACT / OP_MULTIPLY on Integer and Double operands: two
// Integers stay Integer (wrapping), any Double makes a Double.
#define FL_ARITH(name, OP) \
fl_##name: { \
	FL_NEED(2); \
	Variant *a = sp - 2; \
	const Variant *b = sp - 1; \
	const uint32_t ta = fl_type(a); \
	const uint32_t tb = fl_type(b); \
	if (ta == FL_INT && tb == FL_INT) { \
		fl_put_int(a, (int64_t)((uint64_t)fl_int(a) OP (uint64_t)fl_int(b))); \
	} else if ((ta == FL_INT || ta == FL_FLOAT) && (tb == FL_INT || tb == FL_FLOAT)) { \
		const double x = ta == FL_INT ? (double)fl_int(a) : fl_float(a); \
		const double y = tb == FL_INT ? (double)fl_int(b) : fl_float(b); \
		fl_put_float(a, x OP y); \
	} else { \
		goto fl_leave; \
	} \
	sp--; \
	pc += 1; \
	FL_NEXT(); \
}
FL_ARITH(add, +)
FL_ARITH(subtract, -)
FL_ARITH(multiply, *)
#undef FL_ARITH

fl_divide: { // OP_DIVIDE: Double division; a zero divisor raises
	FL_NEED(2);
	Variant *a = sp - 2;
	double x;
	double y;
	if (FL_UNLIKELY(!fl_as_f64(a, x) || !fl_as_f64(sp - 1, y) || y == 0.0)) {
		goto fl_leave;
	}
	fl_put_float(a, x / y);
	sp--;
	pc += 1;
	FL_NEXT();
}

fl_mod: { // OP_MOD on numbers (a String left operand is a format)
	FL_NEED(2);
	Variant *a = sp - 2;
	int64_t x;
	int64_t y;
	if (FL_UNLIKELY(!fl_as_i64(a, x) || !fl_as_i64(sp - 1, y) || y == 0 || y == -1)) {
		goto fl_leave;
	}
	fl_put_int(a, x % y);
	sp--;
	pc += 1;
	FL_NEXT();
}

fl_int_divide: { // OP_INT_DIVIDE
	FL_NEED(2);
	Variant *a = sp - 2;
	int64_t x;
	int64_t y;
	if (FL_UNLIKELY(!fl_as_i64(a, x) || !fl_as_i64(sp - 1, y) || y == 0 || y == -1)) {
		goto fl_leave;
	}
	fl_put_int(a, x / y);
	sp--;
	pc += 1;
	FL_NEXT();
}

fl_negate: { // OP_NEGATE
	FL_NEED(1);
	Variant *top = sp - 1;
	const uint32_t t = fl_type(top);
	if (t == FL_INT) {
		fl_put_int(top, (int64_t)(0 - (uint64_t)fl_int(top)));
	} else if (t == FL_FLOAT) {
		fl_put_float(top, -fl_float(top));
	} else {
		goto fl_leave;
	}
	pc += 1;
	FL_NEXT();
}

// OP_ADD_I64 / OP_SUB_I64 / OP_MUL_I64
#define FL_ARITH_I64(name, OP) \
fl_##name: { \
	FL_NEED(2); \
	Variant *a = sp - 2; \
	int64_t x; \
	int64_t y; \
	if (FL_UNLIKELY(!fl_as_i64(a, x) || !fl_as_i64(sp - 1, y))) { \
		goto fl_leave; \
	} \
	fl_put_int(a, (int64_t)((uint64_t)x OP (uint64_t)y)); \
	sp--; \
	pc += 1; \
	FL_NEXT(); \
}
FL_ARITH_I64(add_i64, +)
FL_ARITH_I64(sub_i64, -)
FL_ARITH_I64(mul_i64, *)
#undef FL_ARITH_I64

// OP_ADD_I64_CONST / SUB / MUL [const lo] [const hi]: the literal is on the
// stack as well; it is dropped and the pool value is used.
#define FL_ARITH_I64_CONST(name, OP) \
fl_##name: { \
	const uint32_t idx = FL_U16_LE(1); \
	if (FL_UNLIKELY(idx >= nconst)) { \
		goto fl_leave; \
	} \
	FL_NEED(2); \
	Variant *a = sp - 2; \
	int64_t x; \
	int64_t c; \
	if (FL_UNLIKELY(!fl_pod(fl_type(sp - 1)) || !fl_as_i64(a, x) || !fl_as_i64(K + idx, c))) { \
		goto fl_leave; \
	} \
	fl_put_int(a, (int64_t)((uint64_t)x OP (uint64_t)c)); \
	sp--; \
	pc += 3; \
	FL_NEXT(); \
}
FL_ARITH_I64_CONST(add_i64_const, +)
FL_ARITH_I64_CONST(sub_i64_const, -)
FL_ARITH_I64_CONST(mul_i64_const, *)
#undef FL_ARITH_I64_CONST

// OP_ADD_F64 / OP_SUB_F64 / OP_MUL_F64 (Boolean and Nothing operands, and
// Vector/Color values that reach these, stay with the ordinary handler)
#define FL_ARITH_F64(name, OP) \
fl_##name: { \
	FL_NEED(2); \
	Variant *a = sp - 2; \
	double x; \
	double y; \
	if (FL_UNLIKELY(!fl_as_f64(a, x) || !fl_as_f64(sp - 1, y))) { \
		goto fl_leave; \
	} \
	fl_put_float(a, x OP y); \
	sp--; \
	pc += 1; \
	FL_NEXT(); \
}
FL_ARITH_F64(add_f64, +)
FL_ARITH_F64(sub_f64, -)
FL_ARITH_F64(mul_f64, *)
#undef FL_ARITH_F64

fl_div_f64: { // OP_DIV_F64; a zero divisor raises
	FL_NEED(2);
	Variant *a = sp - 2;
	double x;
	double y;
	if (FL_UNLIKELY(!fl_as_f64(a, x) || !fl_as_f64(sp - 1, y) || y == 0.0)) {
		goto fl_leave;
	}
	fl_put_float(a, x / y);
	sp--;
	pc += 1;
	FL_NEXT();
}

	// ── Typed local updates ────────────────────────────────────────────────
	// An Integer (Double) slot keeps its value in the shadow array and as an
	// Integer (Double) Variant in the frame.  A slot of another declared
	// type, or one whose frame Variant is not a scalar or Nothing (the reset
	// state of a Dim'd slot), is the ordinary handler's.

#define FL_I64_SLOT(slot, dst) \
	if (FL_UNLIKELY((slot) >= nloc || (slot) >= ntypes || ltypes[slot] != 1)) { \
		goto fl_leave; \
	} \
	Variant *dst = L + (slot); \
	if (FL_UNLIKELY(fl_type(dst) > FL_FLOAT)) { \
		goto fl_leave; \
	}
#define FL_F64_SLOT(slot, dst) \
	if (FL_UNLIKELY((slot) >= nloc || (slot) >= ntypes || ltypes[slot] != 2)) { \
		goto fl_leave; \
	} \
	Variant *dst = L + (slot); \
	if (FL_UNLIKELY(fl_type(dst) > FL_FLOAT)) { \
		goto fl_leave; \
	}

fl_inc_local_i64: { // OP_INC_LOCAL_I64 [slot]
	const uint32_t slot = pc[1];
	FL_I64_SLOT(slot, dst)
	const int64_t v = (int64_t)((uint64_t)ti[slot] + 1);
	ti[slot] = v;
	fl_put_int(dst, v);
	pc += 2;
	FL_NEXT();
}

// OP_ADD_LOCAL_I64_STACK / OP_SUB_LOCAL_I64_STACK [slot]
#define FL_LOCAL_I64_STACK(name, OP) \
fl_##name: { \
	const uint32_t slot = pc[1]; \
	FL_NEED(1); \
	int64_t delta; \
	if (FL_UNLIKELY(!fl_as_i64(sp - 1, delta))) { \
		goto fl_leave; \
	} \
	FL_I64_SLOT(slot, dst) \
	const int64_t v = (int64_t)((uint64_t)ti[slot] OP (uint64_t)delta); \
	ti[slot] = v; \
	fl_put_int(dst, v); \
	sp--; \
	pc += 2; \
	FL_NEXT(); \
}
FL_LOCAL_I64_STACK(add_local_i64_stack, +)
FL_LOCAL_I64_STACK(sub_local_i64_stack, -)
#undef FL_LOCAL_I64_STACK

// OP_ADD_LOCAL_I64_CONST / OP_SUB_LOCAL_I64_CONST [slot] [const lo] [const hi]
#define FL_LOCAL_I64_CONST(name, OP) \
fl_##name: { \
	FL_LONG(1) \
	const uint32_t slot = pc[1]; \
	const uint32_t idx = FL_U16_LE(2); \
	int64_t delta; \
	if (FL_UNLIKELY(idx >= nconst || !fl_as_i64(K + idx, delta))) { \
		goto fl_leave; \
	} \
	FL_I64_SLOT(slot, dst) \
	const int64_t v = (int64_t)((uint64_t)ti[slot] OP (uint64_t)delta); \
	ti[slot] = v; \
	fl_put_int(dst, v); \
	pc += 4; \
	FL_NEXT(); \
}
FL_LOCAL_I64_CONST(add_local_i64_const, +)
FL_LOCAL_I64_CONST(sub_local_i64_const, -)
#undef FL_LOCAL_I64_CONST

// OP_ADD_LOCAL_F64_STACK / OP_SUB_LOCAL_F64_STACK [slot]
#define FL_LOCAL_F64_STACK(name, OP) \
fl_##name: { \
	const uint32_t slot = pc[1]; \
	FL_NEED(1); \
	double delta; \
	if (FL_UNLIKELY(!fl_as_f64(sp - 1, delta))) { \
		goto fl_leave; \
	} \
	FL_F64_SLOT(slot, dst) \
	const double v = tf[slot] OP delta; \
	tf[slot] = v; \
	fl_put_float(dst, v); \
	sp--; \
	pc += 2; \
	FL_NEXT(); \
}
FL_LOCAL_F64_STACK(add_local_f64_stack, +)
FL_LOCAL_F64_STACK(sub_local_f64_stack, -)
#undef FL_LOCAL_F64_STACK

// OP_ADD_LOCAL_F64_CONST / OP_SUB_LOCAL_F64_CONST [slot] [const lo] [const hi]
#define FL_LOCAL_F64_CONST(name, OP) \
fl_##name: { \
	FL_LONG(1) \
	const uint32_t slot = pc[1]; \
	const uint32_t idx = FL_U16_LE(2); \
	double delta; \
	if (FL_UNLIKELY(idx >= nconst || !fl_as_f64(K + idx, delta))) { \
		goto fl_leave; \
	} \
	FL_F64_SLOT(slot, dst) \
	const double v = tf[slot] OP delta; \
	tf[slot] = v; \
	fl_put_float(dst, v); \
	pc += 4; \
	FL_NEXT(); \
}
FL_LOCAL_F64_CONST(add_local_f64_const, +)
FL_LOCAL_F64_CONST(sub_local_f64_const, -)
#undef FL_LOCAL_F64_CONST

	// ── Compares and logic ─────────────────────────────────────────────────

// OP_LESS / OP_GREATER / ... on Integer and Double operands (an Integer
// beside a Double is compared as a Double).
#define FL_COMPARE(name, OP) \
fl_##name: { \
	FL_NEED(2); \
	Variant *a = sp - 2; \
	const Variant *b = sp - 1; \
	const uint32_t ta = fl_type(a); \
	const uint32_t tb = fl_type(b); \
	bool r; \
	if (ta == FL_INT && tb == FL_INT) { \
		r = fl_int(a) OP fl_int(b); \
	} else if ((ta == FL_INT || ta == FL_FLOAT) && (tb == FL_INT || tb == FL_FLOAT)) { \
		const double x = ta == FL_INT ? (double)fl_int(a) : fl_float(a); \
		const double y = tb == FL_INT ? (double)fl_int(b) : fl_float(b); \
		r = x OP y; \
	} else { \
		goto fl_leave; \
	} \
	fl_put_bool(a, r); \
	sp--; \
	pc += 1; \
	FL_NEXT(); \
}
// OP_EQUAL / OP_NOT_EQUAL: the same, plus two Booleans.
#define FL_COMPARE_EQ(name, OP) \
fl_##name: { \
	FL_NEED(2); \
	Variant *a = sp - 2; \
	const Variant *b = sp - 1; \
	const uint32_t ta = fl_type(a); \
	const uint32_t tb = fl_type(b); \
	bool r; \
	if (ta == FL_INT && tb == FL_INT) { \
		r = fl_int(a) OP fl_int(b); \
	} else if ((ta == FL_INT || ta == FL_FLOAT) && (tb == FL_INT || tb == FL_FLOAT)) { \
		const double x = ta == FL_INT ? (double)fl_int(a) : fl_float(a); \
		const double y = tb == FL_INT ? (double)fl_int(b) : fl_float(b); \
		r = x OP y; \
	} else if (ta == FL_BOOL && tb == FL_BOOL) { \
		r = fl_bool(a) OP fl_bool(b); \
	} else { \
		goto fl_leave; \
	} \
	fl_put_bool(a, r); \
	sp--; \
	pc += 1; \
	FL_NEXT(); \
}
FL_COMPARE_EQ(equal, ==)
FL_COMPARE_EQ(not_equal, !=)
FL_COMPARE(greater, >)
FL_COMPARE(less, <)
FL_COMPARE(greater_equal, >=)
FL_COMPARE(less_equal, <=)
#undef FL_COMPARE
#undef FL_COMPARE_EQ

// OP_EQUAL_I64 / OP_NOT_EQUAL_I64 / OP_LESS_EQUAL_I64 / OP_LESS_I64
#define FL_COMPARE_I64(name, OP) \
fl_##name: { \
	FL_NEED(2); \
	Variant *a = sp - 2; \
	int64_t x; \
	int64_t y; \
	if (FL_UNLIKELY(!fl_as_i64(a, x) || !fl_as_i64(sp - 1, y))) { \
		goto fl_leave; \
	} \
	fl_put_bool(a, x OP y); \
	sp--; \
	pc += 1; \
	FL_NEXT(); \
}
FL_COMPARE_I64(equal_i64, ==)
FL_COMPARE_I64(not_equal_i64, !=)
FL_COMPARE_I64(less_equal_i64, <=)
FL_COMPARE_I64(less_i64, <)
#undef FL_COMPARE_I64

fl_logic_not: { // OP_NOT: logical Not of a Boolean, number or Nothing
	FL_NEED(1);
	Variant *top = sp - 1;
	bool c;
	if (FL_UNLIKELY(!fl_truth(top, c))) {
		goto fl_leave;
	}
	fl_put_bool(top, !c);
	pc += 1;
	FL_NEXT();
}

// OP_AND / OP_OR: logical for two Booleans, bitwise for two numbers.
#define FL_LOGIC(name, BOOL_OP, BIT_OP) \
fl_##name: { \
	FL_NEED(2); \
	Variant *a = sp - 2; \
	const Variant *b = sp - 1; \
	const uint32_t ta = fl_type(a); \
	const uint32_t tb = fl_type(b); \
	if (ta == FL_BOOL && tb == FL_BOOL) { \
		fl_put_bool(a, fl_bool(a) BOOL_OP fl_bool(b)); \
	} else { \
		int64_t x; \
		int64_t y; \
		if (FL_UNLIKELY(!fl_as_i64(a, x) || !fl_as_i64(b, y))) { \
			goto fl_leave; \
		} \
		fl_put_int(a, x BIT_OP y); \
	} \
	sp--; \
	pc += 1; \
	FL_NEXT(); \
}
FL_LOGIC(logic_and, &&, &)
FL_LOGIC(logic_or, ||, |)
#undef FL_LOGIC

	// ── Branches ───────────────────────────────────────────────────────────

fl_jump: { // OP_JUMP [offset hi] [offset lo], forward
	pc += 3 + FL_U16_BE(1);
	FL_NEXT();
}

fl_jump_if_false: { // OP_JUMP_IF_FALSE [offset hi] [offset lo]
	// An empty stack counts as False without an error, and a String/Object
	// condition needs the engine: both are the ordinary handler's.
	bool cond;
	if (FL_UNLIKELY(sp <= floor || !fl_truth(sp - 1, cond))) {
		goto fl_leave;
	}
	sp--;
	pc += cond ? 3 : 3 + FL_U16_BE(1);
	FL_NEXT();
}

fl_jump_if_true: { // OP_JUMP_IF_TRUE [offset hi] [offset lo]
	bool cond;
	if (FL_UNLIKELY(sp <= floor || !fl_truth(sp - 1, cond))) {
		goto fl_leave;
	}
	sp--;
	pc += cond ? 3 + FL_U16_BE(1) : 3;
	FL_NEXT();
}

fl_loop: { // OP_LOOP [offset hi] [offset lo], backward
	const size_t back = FL_U16_BE(1);
	if (FL_UNLIKELY(back > (size_t)(pc - code) + 3)) {
		goto fl_leave;
	}
	pc = pc + 3 - back;
	FL_NEXT();
}

fl_for_inc_le_loop: { // OP_FOR_INC_LE_LOOP [var] [limit] [offset hi] [offset lo]
	// var += 1; back to the body while var <= limit.
	FL_LONG(2)
	const uint32_t var = pc[1];
	const uint32_t lim = pc[2];
	const size_t back = FL_U16_BE(3);
	if (FL_UNLIKELY(lim >= nloc || back > (size_t)(pc - code) + 5)) {
		goto fl_leave;
	}
	const Variant *lv = L + lim;
	{
		const uint32_t tl = fl_type(lv);
		if (FL_UNLIKELY(tl != FL_INT && tl != FL_FLOAT)) {
			goto fl_leave;
		}
	}
	FL_I64_SLOT(var, vv)
	const int64_t cur = (int64_t)((uint64_t)ti[var] + 1);
	ti[var] = cur;
	fl_put_int(vv, cur);
	// Read after the store, as the ordinary handler does.
	const int64_t limit_value = fl_type(lv) == FL_INT ? fl_int(lv) : (int64_t)fl_float(lv);
	pc += 5;
	if (cur <= limit_value) {
		pc -= back;
	}
	FL_NEXT();
}

	// ── Numeric builtins ───────────────────────────────────────────────────

fl_abs: { // OP_ABS
	FL_NEED(1);
	Variant *top = sp - 1;
	const uint32_t t = fl_type(top);
	if (t == FL_INT) {
		const int64_t x = fl_int(top);
		fl_put_int(top, x < 0 ? (int64_t)(0 - (uint64_t)x) : x);
	} else if (t == FL_FLOAT) {
		fl_put_float(top, Math::abs(fl_float(top)));
	} else {
		goto fl_leave;
	}
	pc += 1;
	FL_NEXT();
}

// OP_SIN / OP_COS / OP_SQRT
#define FL_MATH(name, FN) \
fl_##name: { \
	FL_NEED(1); \
	Variant *top = sp - 1; \
	double x; \
	if (FL_UNLIKELY(!fl_as_f64(top, x))) { \
		goto fl_leave; \
	} \
	fl_put_float(top, FN(x)); \
	pc += 1; \
	FL_NEXT(); \
}
FL_MATH(sin, ::sin)
FL_MATH(cos, ::cos)
FL_MATH(sqrt, ::sqrt)
#undef FL_MATH

	// ── Line marker ────────────────────────────────────────────────────────

fl_debug_line: { // OP_DEBUG_LINE [line lo] [line hi]
	// Only the bookkeeping of the no-debugger case, and only while the file
	// identity recorded by the last full OP_DEBUG_LINE still applies: the
	// current line is stored.  A debug hook (breakpoints, stepping, trace),
	// a script path not memoized yet or a change of source file is the
	// ordinary handler's.
	if (FL_UNLIKELY(dbg_mode < 0)) {
		dbg_mode = 0;
		if (!VisualGasicLanguage::is_debug_hook_active() && script.is_valid() &&
				_debug_script_path_owner == static_cast<const void *>(script.ptr())) {
			if (vgfast::str_empty(debug_bc_source_file)) {
				if (debug_state.current_file_script == static_cast<const void *>(script.ptr())) {
					dbg_mode = 1;
				}
			} else if (debug_state.current_file_id == -2) {
				dbg_mode = 2;
			}
		}
	}
	const int line = (int)FL_U16_LE(1);
	if (FL_LIKELY(dbg_mode == 1)) {
		int source_line = line;
		if (FL_UNLIKELY(script.ptr()->source_file_id_for_line(line, source_line) != debug_state.current_file_id)) {
			goto fl_leave;
		}
		debug_state.merged_line = line;
		debug_state.current_line = source_line;
	} else if (dbg_mode == 2) {
		debug_state.merged_line = line;
		debug_state.current_line = line;
	} else {
		goto fl_leave;
	}
	pc += 3;
	FL_NEXT();
}

fl_grow:
	// Operand stack full: grow it (the elements relocate bytewise) and run
	// the opcode again.
	stack.raw_set_size((size_t)(sp - data));
	stack.reserve(stack.size() + 1);
	data = stack.raw_data();
	sp = data + stack.size();
	floor = data + f.stack_base;
	limit = data + stack.capacity();
	goto *labels[*pc];

fl_leave:
	stack.raw_set_size((size_t)(sp - data));
	return (int)(pc - code);

#undef FL_NEXT
#undef FL_NEED
#undef FL_ROOM
#undef FL_U16_LE
#undef FL_U16_BE
#undef FL_LONG
#undef FL_I64_SLOT
#undef FL_F64_SLOT
}

#else // !VG_FASTLOOP_AVAILABLE

int VisualGasicInstance::vm_fast_run(const VMFastFrame &f, int p_ip) {
	(void)f;
	return p_ip;
}

#endif // VG_FASTLOOP_AVAILABLE
