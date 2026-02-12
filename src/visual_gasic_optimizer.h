#ifndef VISUAL_GASIC_OPTIMIZER_H
#define VISUAL_GASIC_OPTIMIZER_H

#include "visual_gasic_bytecode.h"
#include <godot_cpp/variant/utility_functions.hpp>

/**
 * VisualGasic Bytecode Peephole Optimizer (v2.4.1)
 *
 * A post-compilation optimization pass that transforms the flat bytecode
 * in a BytecodeChunk to eliminate redundant instructions, fold constants,
 * thread jump chains, and strip dead code.
 *
 * The optimizer operates directly on the byte array and constant pool,
 * preserving line-number mappings. It runs multiple passes until a
 * fixed-point is reached (no further transformations).
 *
 * Integration: Called in VisualGasicScript::get_bytecode_for() after
 * successful compilation and before caching.
 */
class VisualGasicOptimizer {
public:
    struct Stats {
        int redundant_load_store = 0;    // SET_LOCAL x; GET_LOCAL x → DUP + SET
        int dead_stores = 0;             // SET_LOCAL x; ...; SET_LOCAL x (no read)
        int dead_pop = 0;                // CONSTANT/GET_LOCAL immediately popped
        int constant_fold = 0;           // CONST a; CONST b; OP → CONST result
        int jump_thread = 0;             // JUMP → JUMP chain shortened
        int dead_code = 0;              // Unreachable bytes after unconditional JUMP/RETURN
        int identity_ops = 0;            // +0, *1, -0 eliminated
        int double_negation = 0;         // NOT NOT eliminated
        int strength_reduction = 0;      // *2→+self, etc.
        int debug_line_stripped = 0;     // OP_DEBUG_LINE removed (release mode)
        int total_bytes_before = 0;
        int total_bytes_after = 0;

        int total() const {
            return redundant_load_store + dead_stores + dead_pop +
                   constant_fold + jump_thread + dead_code +
                   identity_ops + double_negation + strength_reduction +
                   debug_line_stripped;
        }
    };

    /**
     * Optimize a bytecode chunk in-place.
     * @param chunk  The bytecode chunk to optimize.
     * @param strip_debug  If true, remove OP_DEBUG_LINE instructions (release builds).
     * @return Stats describing what was optimized.
     */
    static Stats optimize(BytecodeChunk* chunk, bool strip_debug = false);

private:
    // Helper: instruction size at position ip in code
    static int instruction_size(const Vector<uint8_t>& code, int ip);

    // Helper: is this opcode a push-only instruction (puts exactly 1 value on stack)?
    static bool is_push_one(uint8_t op);

    // Helper: does this opcode jump unconditionally?
    static bool is_unconditional_exit(uint8_t op);

    // Individual optimization passes (return true if any transformation was applied)
    static bool pass_redundant_load_store(BytecodeChunk* chunk, Stats& stats);
    static bool pass_dead_pop(BytecodeChunk* chunk, Stats& stats);
    static bool pass_constant_fold(BytecodeChunk* chunk, Stats& stats);
    static bool pass_jump_threading(BytecodeChunk* chunk, Stats& stats);
    static bool pass_dead_code_elimination(BytecodeChunk* chunk, Stats& stats);
    static bool pass_identity_ops(BytecodeChunk* chunk, Stats& stats);
    static bool pass_double_negation(BytecodeChunk* chunk, Stats& stats);
    static bool pass_strength_reduction(BytecodeChunk* chunk, Stats& stats);
    static bool pass_strip_debug_lines(BytecodeChunk* chunk, Stats& stats);

    // Utility: erase bytes [start, start+count) from chunk, fixing all jump offsets
    static void erase_bytes(BytecodeChunk* chunk, int start, int count);

    // Utility: replace bytes at position with NOP-equivalent (for in-place patching)
    static void nop_out(BytecodeChunk* chunk, int start, int count);

    // Utility: rebuild chunk from code with NOPs removed
    static void compact(BytecodeChunk* chunk);

    // Utility: resolve a 16-bit jump offset at ip (returns absolute target)
    static int resolve_jump(const Vector<uint8_t>& code, int ip);

    // Utility: patch a 16-bit jump offset at ip to point to absolute target
    static void patch_jump_target(Vector<uint8_t>& code, int ip, int target);
};

#endif
