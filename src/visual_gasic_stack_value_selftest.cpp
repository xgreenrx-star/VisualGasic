// ─────────────────────────────────────────────────────────────────────────────
// StackValue self-test — Phase 2 foundation validation (VM performance sprint)
// ─────────────────────────────────────────────────────────────────────────────
//
// Compiled ONLY when `scons tagged_stack=1` defines VG_TAGGED_STACK, so the
// default shipping build is byte-identical (this whole translation unit is empty
// without the flag). Run it by launching a `tagged_stack=1` build with the env
// var VG_STACKVALUE_SELFTEST=1 — the hook in register_types.cpp calls
// vg_stack_value_selftest() at extension init and prints a PASS/FAIL summary.
//
// It exercises the parts of StackValue that are easy to get wrong: union-member
// lifetime across copy/move/assign, tag transitions that must destroy a boxed
// Variant, refcounted payload integrity across copies, and std::vector<StackValue>
// reallocation (which drives the move constructor). It also micro-benchmarks the
// unboxed scalar push/pop against a Variant stack to confirm the intended win.
// ─────────────────────────────────────────────────────────────────────────────

#ifdef VG_TAGGED_STACK

#include "visual_gasic_stack_value.h"

#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <chrono>
#include <vector>

using namespace godot;

namespace {

int g_pass = 0;
int g_fail = 0;

void check(bool cond, const char *what) {
	if (cond) {
		g_pass++;
	} else {
		g_fail++;
		UtilityFunctions::printerr("[STACKVALUE-SELFTEST] FAIL: ", what);
	}
}

} // namespace

void vg_stack_value_selftest() {
	g_pass = 0;
	g_fail = 0;

	// 1. Scalar round-trips: tag, raw value, and boxed Variant view all agree.
	{
		StackValue si = StackValue::make_int(42);
		check(si.is_int() && si.raw_int() == 42, "int tag/value");
		check(si.to_variant().get_type() == Variant::INT && (int64_t)si.to_variant() == 42, "int->variant");

		StackValue sf = StackValue::make_float(3.5);
		check(sf.is_float() && sf.raw_float() == 3.5, "float tag/value");
		check(sf.to_variant().get_type() == Variant::FLOAT && (double)sf.to_variant() == 3.5, "float->variant");

		StackValue sb = StackValue::make_bool(true);
		check(sb.is_bool() && sb.raw_bool() == true, "bool tag/value");
		check(sb.to_variant().get_type() == Variant::BOOL && (bool)sb.to_variant() == true, "bool->variant");

		StackValue sn = StackValue::make_nil();
		check(sn.is_nil() && sn.to_variant().get_type() == Variant::NIL, "nil round-trip");
	}

	// 2. from_variant classifies scalars unboxed and everything else boxed.
	{
		check(StackValue::from_variant(Variant((int64_t)7)).is_int(), "from_variant int");
		check(StackValue::from_variant(Variant(2.25)).is_float(), "from_variant float");
		check(StackValue::from_variant(Variant(false)).is_bool(), "from_variant bool");
		check(StackValue::from_variant(Variant()).is_nil(), "from_variant nil");
		check(StackValue::from_variant(Variant(String("hi"))).is_boxed(), "from_variant string boxed");
	}

	// 3. Boxed payloads survive the round-trip with correct type + value.
	{
		StackValue ss = StackValue::from_variant(Variant(String("hello")));
		check(ss.is_boxed() && ss.to_variant().get_type() == Variant::STRING &&
						(String)ss.to_variant() == String("hello"),
				"boxed string value");

		Array a;
		a.push_back(1);
		a.push_back(2);
		a.push_back(3);
		StackValue sa = StackValue::from_variant(Variant(a));
		check(sa.is_boxed() && ((Array)sa.to_variant()).size() == 3, "boxed array size");

		Dictionary d;
		d["k"] = 99;
		StackValue sd = StackValue::from_variant(Variant(d));
		check(sd.is_boxed() && (int64_t)((Dictionary)sd.to_variant())["k"] == 99, "boxed dict value");
	}

	// 4. Copying a boxed StackValue shares the refcounted payload safely; the
	//    original stays intact after the copies are destroyed.
	{
		Array a;
		a.push_back(10);
		a.push_back(20);
		StackValue original = StackValue::from_variant(Variant(a));
		{
			StackValue c1 = original;      // copy ctor (boxed)
			StackValue c2(original);       // copy ctor (boxed)
			StackValue c3;
			c3 = original;                 // copy assign into NIL
			check(((Array)c1.to_variant()).size() == 2, "copy1 intact");
			check(((Array)c2.to_variant()).size() == 2, "copy2 intact");
			check(((Array)c3.to_variant()).size() == 2, "copy3 intact");
		} // c1..c3 destroyed here
		check(original.is_boxed() && ((Array)original.to_variant()).size() == 2, "original survives copies");
	}

	// 5. Tag transitions must destroy a boxed Variant cleanly (no leak/crash),
	//    including boxed -> scalar -> boxed and copy-assign over a live boxed.
	{
		StackValue sv = StackValue::from_variant(Variant(String("temp")));
		check(sv.is_boxed(), "transition starts boxed");
		sv.set_int(9); // must destroy the String
		check(sv.is_int() && sv.raw_int() == 9, "boxed->int transition");
		sv.set_boxed(Variant(String("again")));
		check(sv.is_boxed() && (String)sv.to_variant() == String("again"), "int->boxed transition");

		StackValue boxedLhs = StackValue::from_variant(Variant(String("lhs")));
		StackValue scalarRhs = StackValue::make_int(5);
		boxedLhs = scalarRhs; // copy-assign scalar over a live boxed → must destroy boxed
		check(boxedLhs.is_int() && boxedLhs.raw_int() == 5, "copy-assign scalar over boxed");
	}

	// 6. Move transfers the payload and leaves the source as a clean NIL.
	{
		StackValue src = StackValue::from_variant(Variant(String("moveme")));
		StackValue dst(std::move(src)); // move ctor
		check(dst.is_boxed() && (String)dst.to_variant() == String("moveme"), "move ctor dest holds value");
		check(src.is_nil(), "move ctor source is nil");

		StackValue src2 = StackValue::from_variant(Variant(String("moveme2")));
		StackValue dst2;
		dst2 = std::move(src2); // move assign into NIL
		check(dst2.is_boxed() && (String)dst2.to_variant() == String("moveme2"), "move assign dest holds value");
		check(src2.is_nil(), "move assign source is nil");
	}

	// 7. std::vector<StackValue> reallocation drives the move ctor for mixed
	//    scalar+boxed elements; every value must survive the growth.
	{
		std::vector<StackValue> stack;
		stack.reserve(1); // force reallocation as we grow
		const int N = 200;
		for (int k = 0; k < N; k++) {
			if (k % 3 == 0) {
				stack.push_back(StackValue::make_int(k));
			} else if (k % 3 == 1) {
				stack.push_back(StackValue::make_float((double)k + 0.5));
			} else {
				stack.push_back(StackValue::from_variant(Variant(String("s") + String::num_int64(k))));
			}
		}
		bool ok = true;
		for (int k = 0; k < N; k++) {
			if (k % 3 == 0) {
				ok = ok && stack[k].is_int() && stack[k].raw_int() == k;
			} else if (k % 3 == 1) {
				ok = ok && stack[k].is_float() && stack[k].raw_float() == (double)k + 0.5;
			} else {
				ok = ok && stack[k].is_boxed() && (String)stack[k].to_variant() == (String("s") + String::num_int64(k));
			}
		}
		check(ok, "vector realloc preserves mixed values");
	}

	// 8. Micro-benchmark: unboxed int64 push/pop vs a Variant stack. Reports the
	//    ratio; the scalar lane should avoid Variant ctor/dtor entirely.
	{
		const int64_t ITER = 5000000;

		auto t0 = std::chrono::steady_clock::now();
		{
			std::vector<StackValue> s;
			s.reserve(4);
			int64_t acc = 0;
			for (int64_t k = 0; k < ITER; k++) {
				s.push_back(StackValue::make_int(k));
				s.push_back(StackValue::make_int(k + 1));
				int64_t bb = s.back().raw_int();
				s.pop_back();
				int64_t aa = s.back().raw_int();
				s.pop_back();
				acc += aa + bb;
			}
			if (acc == -1) {
				UtilityFunctions::print(""); // defeat dead-code elimination
			}
		}
		auto t1 = std::chrono::steady_clock::now();
		{
			std::vector<Variant> s;
			s.reserve(4);
			int64_t acc = 0;
			for (int64_t k = 0; k < ITER; k++) {
				s.push_back(Variant(k));
				s.push_back(Variant(k + 1));
				int64_t bb = (int64_t)s.back();
				s.pop_back();
				int64_t aa = (int64_t)s.back();
				s.pop_back();
				acc += aa + bb;
			}
			if (acc == -1) {
				UtilityFunctions::print("");
			}
		}
		auto t2 = std::chrono::steady_clock::now();

		double sv_us = std::chrono::duration_cast<std::chrono::microseconds>(t1 - t0).count();
		double var_us = std::chrono::duration_cast<std::chrono::microseconds>(t2 - t1).count();
		double ratio = (sv_us > 0.0) ? (var_us / sv_us) : 0.0;
		UtilityFunctions::print("[STACKVALUE-SELFTEST] bench int64 push/pop x", (int64_t)ITER,
				": StackValue=", sv_us, "us  Variant=", var_us, "us  (Variant/StackValue=", ratio, "x)");
	}

	UtilityFunctions::print("[STACKVALUE-SELFTEST] ", (g_fail == 0 ? "PASS " : "FAIL "),
			(int64_t)g_pass, "/", (int64_t)(g_pass + g_fail), " checks");
}

#endif // VG_TAGGED_STACK
