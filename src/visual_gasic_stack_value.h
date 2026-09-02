#ifndef VISUAL_GASIC_STACK_VALUE_H
#define VISUAL_GASIC_STACK_VALUE_H

// ─────────────────────────────────────────────────────────────────────────────
// StackValue — Phase 2 unboxed typed value-stack element (VM performance sprint)
// ─────────────────────────────────────────────────────────────────────────────
//
// WHY THIS EXISTS
//   The bytecode VM's operand stack is currently `std::vector<Variant>`. Every
//   push/pop constructs/destructs a Variant, even on the typed integer/float hot
//   paths. Profiling (see /memories/repo/vg_bytecode_perf.md, "POST-AG FLOOR")
//   proved this Variant-boxing tax is THE sole remaining architectural cost: the
//   interpreter is instruction-bound (IPC 2.63, ~0 branch-misses — computed-goto
//   already measured & ruled out), so the only way to cut cycles is to cut the
//   number of Variant operations. An unboxed typed value stack is the documented
//   lever that closes the ~6× per-instruction gap to GDScript on NON-fused code.
//
// WHAT IT IS
//   A tagged union that holds a scalar (int64/double/bool) DIRECTLY — with zero
//   Variant construction, destruction, or refcount traffic — or falls back to an
//   inline boxed `Variant` for every non-scalar type (String/Array/Dictionary/
//   Object/Vector2/Color/…). Scalars are the numeric hot path; the boxed lane is
//   the correctness fallback that keeps 100% of language semantics intact.
//
// THE CRUX: UNION LIFETIME
//   A union member of non-trivial type (`Variant`) makes the union's implicit
//   special members deleted. StackValue therefore manages the active member's
//   lifetime MANUALLY: the boxed Variant is created with placement-new and ended
//   with an explicit destructor call, gated on `tag == TAG_BOXED`. Getting this
//   exactly right (copy/move ctor+assign, tag transitions, vector reallocation)
//   is the hard part of the whole Phase 2 redesign — so it lives in one small,
//   self-contained, unit-tested header rather than being smeared across ~150
//   opcode handlers.
//
// STATUS
//   FOUNDATION ONLY. This type is NOT yet wired into the live `VMState::stack`.
//   Migrating the real stack is an incremental, multi-step effort (see the plan
//   in docs/vm_tagged_stack_migration.md). This header is validated in isolation
//   by src/visual_gasic_stack_value_selftest.cpp (built with `scons tagged_stack=1`).
//
// DESIGN NOTES
//   • Only int64/double/bool are unboxed. Objects/strings/containers stay BOXED
//     for now — 100% of the arithmetic-path win comes from the scalar lane, and a
//     boxed fallback keeps correctness trivial. A future unboxed TAG_OBJECT
//     (bare Object*) is a possible refinement, deliberately deferred.
//   • The move constructor/assignment are `noexcept` so std::vector<StackValue>
//     reallocation uses moves (not copies) for boxed elements.
//   • copy_from/move_from read only the ACTIVE union member (no inactive-member
//     type-punning) so the type is strictly well-defined, not just works-in-practice.
// ─────────────────────────────────────────────────────────────────────────────

#include <godot_cpp/variant/variant.hpp>

#include <cstdint>
#include <new>
#include <utility>

using namespace godot;

struct StackValue {
	enum Tag : uint8_t {
		TAG_NIL = 0,
		TAG_INT = 1,   // scalar int64, unboxed
		TAG_FLOAT = 2, // scalar double, unboxed
		TAG_BOOL = 3,  // scalar bool, unboxed
		TAG_BOXED = 4, // `boxed` Variant member is active (all non-scalar types)
	};

	Tag tag;
	union {
		int64_t i;
		double f;
		bool b;
		Variant boxed; // active iff tag == TAG_BOXED
	};

	// ── construction / destruction ──────────────────────────────────────────
	StackValue() noexcept : tag(TAG_NIL), i(0) {}
	~StackValue() { destroy_boxed_if_needed(); }

	StackValue(const StackValue &o) { copy_from(o); }
	StackValue(StackValue &&o) noexcept { move_from(std::move(o)); }

	StackValue &operator=(const StackValue &o) {
		if (this == &o) {
			return *this;
		}
		if (tag == TAG_BOXED && o.tag == TAG_BOXED) {
			boxed = o.boxed; // in-place Variant copy-assign (no ctor/dtor churn)
		} else {
			destroy_boxed_if_needed();
			copy_from(o);
		}
		return *this;
	}

	StackValue &operator=(StackValue &&o) noexcept {
		if (this == &o) {
			return *this;
		}
		if (tag == TAG_BOXED && o.tag == TAG_BOXED) {
			boxed = std::move(o.boxed);
			o.reset_to_nil_after_move();
		} else {
			destroy_boxed_if_needed();
			move_from(std::move(o));
		}
		return *this;
	}

	// ── factories ───────────────────────────────────────────────────────────
	static inline StackValue make_nil() { return StackValue(); }
	static inline StackValue make_int(int64_t v) {
		StackValue s;
		s.tag = TAG_INT;
		s.i = v;
		return s;
	}
	static inline StackValue make_float(double v) {
		StackValue s;
		s.tag = TAG_FLOAT;
		s.f = v;
		return s;
	}
	static inline StackValue make_bool(bool v) {
		StackValue s;
		s.tag = TAG_BOOL;
		s.b = v;
		return s;
	}
	static inline StackValue from_variant(const Variant &v) {
		StackValue s;
		switch (v.get_type()) {
			case Variant::NIL:
				s.tag = TAG_NIL;
				s.i = 0;
				break;
			case Variant::BOOL:
				s.tag = TAG_BOOL;
				s.b = (bool)v;
				break;
			case Variant::INT:
				s.tag = TAG_INT;
				s.i = (int64_t)v;
				break;
			case Variant::FLOAT:
				s.tag = TAG_FLOAT;
				s.f = (double)v;
				break;
			default:
				new (&s.boxed) Variant(v);
				s.tag = TAG_BOXED;
				break;
		}
		return s;
	}

	// ── in-place setters (manage the active-member lifetime) ─────────────────
	inline void set_nil() {
		destroy_boxed_if_needed();
		tag = TAG_NIL;
		i = 0;
	}
	inline void set_int(int64_t v) {
		destroy_boxed_if_needed();
		tag = TAG_INT;
		i = v;
	}
	inline void set_float(double v) {
		destroy_boxed_if_needed();
		tag = TAG_FLOAT;
		f = v;
	}
	inline void set_bool(bool v) {
		destroy_boxed_if_needed();
		tag = TAG_BOOL;
		b = v;
	}
	inline void set_boxed(const Variant &v) {
		if (tag == TAG_BOXED) {
			boxed = v;
		} else {
			new (&boxed) Variant(v);
			tag = TAG_BOXED;
		}
	}
	inline void set_boxed(Variant &&v) {
		if (tag == TAG_BOXED) {
			boxed = std::move(v);
		} else {
			new (&boxed) Variant(std::move(v));
			tag = TAG_BOXED;
		}
	}

	// ── type queries ─────────────────────────────────────────────────────────
	inline bool is_nil() const { return tag == TAG_NIL; }
	inline bool is_int() const { return tag == TAG_INT; }
	inline bool is_float() const { return tag == TAG_FLOAT; }
	inline bool is_bool() const { return tag == TAG_BOOL; }
	inline bool is_boxed() const { return tag == TAG_BOXED; }
	inline bool is_number() const { return tag == TAG_INT || tag == TAG_FLOAT; }

	// ── raw accessors (caller guarantees the tag) ─────────────────────────────
	inline int64_t raw_int() const { return i; }
	inline double raw_float() const { return f; }
	inline bool raw_bool() const { return b; }
	inline const Variant &raw_boxed() const { return boxed; }

	// ── coercing accessors (safe at boundaries) ───────────────────────────────
	inline int64_t to_int() const {
		switch (tag) {
			case TAG_INT:
				return i;
			case TAG_FLOAT:
				return (int64_t)f;
			case TAG_BOOL:
				return b ? 1 : 0;
			case TAG_NIL:
				return 0;
			default:
				return (int64_t)boxed;
		}
	}
	inline double to_float() const {
		switch (tag) {
			case TAG_FLOAT:
				return f;
			case TAG_INT:
				return (double)i;
			case TAG_BOOL:
				return b ? 1.0 : 0.0;
			case TAG_NIL:
				return 0.0;
			default:
				return (double)boxed;
		}
	}
	inline bool to_bool() const {
		switch (tag) {
			case TAG_BOOL:
				return b;
			case TAG_INT:
				return i != 0;
			case TAG_FLOAT:
				return f != 0.0;
			case TAG_NIL:
				return false;
			default:
				return (bool)boxed;
		}
	}

	// Box back to a Variant (the interop / debugger boundary).
	inline Variant to_variant() const {
		switch (tag) {
			case TAG_INT:
				return Variant(i);
			case TAG_FLOAT:
				return Variant(f);
			case TAG_BOOL:
				return Variant(b);
			case TAG_NIL:
				return Variant();
			default:
				return boxed;
		}
	}

private:
	inline void destroy_boxed_if_needed() {
		if (tag == TAG_BOXED) {
			boxed.~Variant();
		}
	}

	// Reads only the ACTIVE member of `o` (no inactive-member type-punning).
	inline void copy_from(const StackValue &o) {
		tag = o.tag;
		switch (o.tag) {
			case TAG_BOXED:
				new (&boxed) Variant(o.boxed);
				break;
			case TAG_FLOAT:
				f = o.f;
				break;
			case TAG_BOOL:
				b = o.b;
				break;
			case TAG_INT:
				i = o.i;
				break;
			default: // TAG_NIL
				i = 0;
				break;
		}
	}

	// `this` is uninitialized (called only from move ctor / after destroy).
	inline void move_from(StackValue &&o) noexcept {
		tag = o.tag;
		switch (o.tag) {
			case TAG_BOXED:
				new (&boxed) Variant(std::move(o.boxed));
				o.reset_to_nil_after_move();
				break;
			case TAG_FLOAT:
				f = o.f;
				break;
			case TAG_BOOL:
				b = o.b;
				break;
			case TAG_INT:
				i = o.i;
				break;
			default: // TAG_NIL
				i = 0;
				break;
		}
	}

	// End the moved-from boxed Variant's lifetime and leave `o` as a clean NIL
	// so its eventual destructor is a no-op (no double-destroy, no shell leak).
	inline void reset_to_nil_after_move() {
		boxed.~Variant();
		tag = TAG_NIL;
		i = 0;
	}
};

#endif // VISUAL_GASIC_STACK_VALUE_H
