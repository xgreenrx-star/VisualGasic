// ============================================================================
// visual_gasic_vm_fastloop.h — lean loop for the bytecode VM's simple opcodes
//
// execute_bytecode() is one function of about 11k lines.  Its per-frame
// state is captured by reference in dozens of lambdas, so it lives in memory:
// the instruction pointer is loaded and stored for every operand byte and the
// simplest handler costs well over a hundred instructions.  About 85% of the
// opcodes a game executes are local and constant loads, local stores,
// Integer/Double arithmetic and compares, branches and the per-statement
// line marker.
//
// vm_fast_run() executes runs of exactly those opcodes with the instruction
// pointer, the operand-stack top and the locals pointer in registers.  It is
// entered from execute_bytecode()'s dispatch (vg_op_fastloop there) and
// returns the offset of the first instruction it did not execute; that one
// goes to its ordinary handler.
//
// Rules every handler in the loop follows:
//   * It covers only the cases that are the same plain operation in the
//     ordinary handler (numeric operands, slots in range, ...).  Anything
//     else — another operand type, a raise, an underflow, a name lookup —
//     leaves the loop BEFORE any state has changed, with the instruction
//     pointer still at that opcode, and the ordinary handler does the work.
//     So no error is ever raised from here.
//   * A store or pop that has to release a String/Array/Object publishes the
//     stack size, releases the old value last and returns: releasing can run
//     script code on the same VM state.
//   * Nothing derived from the operand stack or the locals vector is kept
//     between calls: both are read again on every entry.
//
// GCC only, like the threaded dispatch of the main loop it hooks into.
// Environment: VG_FASTLOOP=0 keeps every opcode on its ordinary handler;
// VG_FASTLOOP_VERIFY=1 (test runs) checks on every entry that the frame
// description below matches execute_bytecode()'s variables and aborts with
// a message when it does not.
// ============================================================================
#ifndef VISUAL_GASIC_VM_FASTLOOP_H
#define VISUAL_GASIC_VM_FASTLOOP_H

#include "visual_gasic_instance.h"

#if defined(__GNUC__) && !defined(__clang__)
#define VG_FASTLOOP_AVAILABLE 1
#else
#define VG_FASTLOOP_AVAILABLE 0
#endif

// Opcodes the loop has a handler for: X(opcode, handler label).
#define VG_FASTLOOP_OPS(X) \
	X(OP_CONSTANT, constant) \
	X(OP_CONSTANT_LONG, constant) \
	X(OP_POP, pop) \
	X(OP_NIL, lit_nil) \
	X(OP_TRUE, lit_true) \
	X(OP_FALSE, lit_false) \
	X(OP_GET_LOCAL, get_local) \
	X(OP_SET_LOCAL, set_local) \
	X(OP_GET_GLOBAL, get_global) \
	X(OP_TO_F64, to_f64) \
	X(OP_ADD, add) \
	X(OP_SUBTRACT, subtract) \
	X(OP_MULTIPLY, multiply) \
	X(OP_DIVIDE, divide) \
	X(OP_MOD, mod) \
	X(OP_INT_DIVIDE, int_divide) \
	X(OP_NEGATE, negate) \
	X(OP_ADD_I64, add_i64) \
	X(OP_SUB_I64, sub_i64) \
	X(OP_MUL_I64, mul_i64) \
	X(OP_ADD_I64_CONST, add_i64_const) \
	X(OP_SUB_I64_CONST, sub_i64_const) \
	X(OP_MUL_I64_CONST, mul_i64_const) \
	X(OP_ADD_F64, add_f64) \
	X(OP_SUB_F64, sub_f64) \
	X(OP_MUL_F64, mul_f64) \
	X(OP_DIV_F64, div_f64) \
	X(OP_INC_LOCAL_I64, inc_local_i64) \
	X(OP_ADD_LOCAL_I64_STACK, add_local_i64_stack) \
	X(OP_SUB_LOCAL_I64_STACK, sub_local_i64_stack) \
	X(OP_ADD_LOCAL_I64_CONST, add_local_i64_const) \
	X(OP_SUB_LOCAL_I64_CONST, sub_local_i64_const) \
	X(OP_ADD_LOCAL_F64_STACK, add_local_f64_stack) \
	X(OP_SUB_LOCAL_F64_STACK, sub_local_f64_stack) \
	X(OP_ADD_LOCAL_F64_CONST, add_local_f64_const) \
	X(OP_SUB_LOCAL_F64_CONST, sub_local_f64_const) \
	X(OP_EQUAL, equal) \
	X(OP_NOT_EQUAL, not_equal) \
	X(OP_GREATER, greater) \
	X(OP_LESS, less) \
	X(OP_GREATER_EQUAL, greater_equal) \
	X(OP_LESS_EQUAL, less_equal) \
	X(OP_EQUAL_I64, equal_i64) \
	X(OP_NOT_EQUAL_I64, not_equal_i64) \
	X(OP_LESS_EQUAL_I64, less_equal_i64) \
	X(OP_LESS_I64, less_i64) \
	X(OP_NOT, logic_not) \
	X(OP_AND, logic_and) \
	X(OP_OR, logic_or) \
	X(OP_JUMP, jump) \
	X(OP_JUMP_IF_FALSE, jump_if_false) \
	X(OP_JUMP_IF_TRUE, jump_if_true) \
	X(OP_LOOP, loop) \
	X(OP_FOR_INC_LE_LOOP, for_inc_le_loop) \
	X(OP_ABS, abs) \
	X(OP_SIN, sin) \
	X(OP_COS, cos) \
	X(OP_SQRT, sqrt) \
	X(OP_DEBUG_LINE, debug_line)

// True when vm_fast_run() has a handler for `op` (used once, to build the
// main loop's second dispatch table).
inline bool vg_fastloop_handles(uint8_t op) {
	switch (op) {
#define VG_FASTLOOP_CASE(opcode, name) case opcode:
		VG_FASTLOOP_OPS(VG_FASTLOOP_CASE)
#undef VG_FASTLOOP_CASE
		return true;
		default:
			return false;
	}
}

// One execute_bytecode() run's view for the loop.  (Kept small: it sits in
// execute_bytecode()'s C++ frame, which deep interpreted recursion repeats.)
struct VisualGasicInstance::VMFastFrame {
	// The frame being executed.  execute_bytecode() fills these in where its
	// own frame variables are set: the base frame's setup, an inline call and
	// the return from one (fast_frame_sync there).
	const uint8_t *code = nullptr;              // chunk->code
	// An instruction of up to three bytes that starts before this lies
	// inside the code; handlers of longer ones check their own length.
	// Equal to `code` when the loop must not run this frame.
	const uint8_t *safe_end = nullptr;
	const Variant *constants = nullptr;         // chunk->constants
	const uint8_t *local_types = nullptr;       // chunk->local_types: 1 = Integer shadow, 2 = Double shadow
	const uint8_t *local_declared = nullptr;    // chunk->local_declared
	int64_t *typed_i64 = nullptr;               // typed_i64_locals
	double *typed_f64 = nullptr;                // typed_f64_locals
	Vector<MemberNameCacheEntry> *member_cache = nullptr;   // member_name_cache_ptr
	size_t stack_base = 0;                      // stack_base
	uint32_t constant_count = 0;
	uint32_t local_type_count = 0;
	uint32_t local_declared_count = 0;
	// The run: these two objects stay, their contents change.
	vgfast::VariantStack *stack = nullptr;      // &vm.stack
	Vector<Variant> *locals = nullptr;          // &locals

	// For VG_FASTLOOP_VERIFY=1.
	bool same_as(const VMFastFrame &o) const {
		return code == o.code && safe_end == o.safe_end && constants == o.constants &&
				local_types == o.local_types && local_declared == o.local_declared &&
				typed_i64 == o.typed_i64 && typed_f64 == o.typed_f64 && member_cache == o.member_cache &&
				stack_base == o.stack_base && constant_count == o.constant_count &&
				local_type_count == o.local_type_count && local_declared_count == o.local_declared_count &&
				stack == o.stack && locals == o.locals;
	}
};

#endif // VISUAL_GASIC_VM_FASTLOOP_H
