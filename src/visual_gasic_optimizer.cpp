#include "visual_gasic_optimizer.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/templates/hash_set.hpp>

using namespace godot;

// ============================================================================
//  Instruction Metadata
// ============================================================================

// We use a sentinel OP for NOP (internal use only during optimization).
// OP_POP is opcode 2. We'll re-use 0xFF as our internal NOP marker since
// no valid opcode uses it.
static constexpr uint8_t OP_NOP = 0xFF;

int VisualGasicOptimizer::instruction_size(const Vector<uint8_t>& code, int ip) {
    if (ip < 0 || ip >= code.size()) return 1;
    uint8_t op = code[ip];
    switch (op) {
        // 1-byte instructions (opcode only)
        case OP_POP:
        case OP_ADD: case OP_SUBTRACT: case OP_MULTIPLY: case OP_DIVIDE:
        case OP_NEGATE: case OP_CONCAT: case OP_MOD: case OP_INT_DIVIDE:
        case OP_POWER: case OP_LIKE:
        case OP_ADD_I64: case OP_SUB_I64: case OP_MUL_I64:
        case OP_ADD_F64: case OP_SUB_F64: case OP_MUL_F64: case OP_DIV_F64:
        case OP_ABS: case OP_SGN: case OP_LEN:
        case OP_EQUAL: case OP_NOT_EQUAL: case OP_GREATER: case OP_LESS:
        case OP_GREATER_EQUAL: case OP_LESS_EQUAL:
        case OP_EQUAL_I64: case OP_NOT_EQUAL_I64: case OP_LESS_EQUAL_I64:
        case OP_NOT: case OP_AND: case OP_OR: case OP_XOR:
        case OP_RETURN: case OP_RETURN_VALUE:
        case OP_PRINT: case OP_DEBUG_PRINT:
        case OP_NEW_DICT:
        case OP_DICT_HAS_KEY: case OP_DICT_SIZE: case OP_DICT_CLEAR_INPLACE:
        case OP_DICT_KEYS: case OP_DICT_VALUES: case OP_DICT_ERASE:
        case OP_RESTORE_DATA:
        case OP_ON_ERROR_RESUME_NEXT: case OP_ON_ERROR_GOTO_0:
        case OP_NIL: case OP_TRUE: case OP_FALSE:
        case OP_NOP:
        case OP_STRING_REPEAT:   // stack-only: pops 2, pushes 1
            return 1;

        // 2-byte instructions (opcode + 1 operand)
        case OP_CONSTANT:
        case OP_GET_GLOBAL: case OP_SET_GLOBAL:
        case OP_GET_LOCAL: case OP_SET_LOCAL:
        case OP_NEW_ARRAY: case OP_NEW_ARRAY_I64:
        case OP_GET_MEMBER: case OP_SET_MEMBER:
        case OP_REGISTER_WHENEVER: case OP_SUSPEND_WHENEVER: case OP_RESUME_WHENEVER:
        case OP_ON_ERROR_GOTO:
        case OP_INC_LOCAL_I64:
        case OP_SUM_ARRAY_I64: case OP_SUM_DICT_I64:
            return 2;

        // 3-byte instructions (opcode + 2 operands)
        case OP_CONSTANT_LONG:
        case OP_JUMP: case OP_JUMP_IF_FALSE: case OP_JUMP_IF_TRUE: case OP_LOOP:
        case OP_CALL: case OP_CALL_BUILTIN:
        case OP_GET_ARRAY: case OP_SET_ARRAY:
        case OP_GET_ARRAY_UNCHECKED: case OP_SET_ARRAY_UNCHECKED:
        case OP_GET_ARRAY_FAST: case OP_SET_ARRAY_FAST:
        case OP_GET_ARRAY_FAST_UNCHECKED: case OP_SET_ARRAY_FAST_UNCHECKED:
        case OP_GET_DICT_FAST: case OP_SET_DICT_FAST:
        case OP_GET_DICT_TRUSTED: case OP_SET_DICT_TRUSTED:
        case OP_ADD_I64_CONST: case OP_SUB_I64_CONST:
        case OP_ADD_LOCAL_I64_STACK: case OP_SUB_LOCAL_I64_STACK:
        case OP_ADD_LOCAL_I64_CONST: case OP_SUB_LOCAL_I64_CONST:
        case OP_ARITH_SUM: case OP_BRANCH_SUM:
        case OP_INTEROP_SET_NAME_LEN:
        case OP_STRING_REPEAT_OUTER: // [OP] [SLOT] [LIT_IDX]
        case OP_DEBUG_LINE:
            return 3;

        // 4-byte instructions
        case OP_SET_DICT_LOCAL: case OP_SET_DICT_GLOBAL:
        case OP_ARRAY_FILL_I64_SEQ:
        case OP_ALLOC_FILL_I64:
        case OP_ALLOC_FILL_I64_OFFSET:
        case OP_ALLOC_FILL_REPEAT_I64:
        case OP_ARRAY_FILL_I64_OFFSET:
        case OP_ACCUM_I64_MULADD_CONST:
            return 4;

        default:
            // Unknown opcode — assume 1 byte (safest)
            return 1;
    }
}

bool VisualGasicOptimizer::is_push_one(uint8_t op) {
    switch (op) {
        case OP_CONSTANT:
        case OP_CONSTANT_LONG:
        case OP_GET_GLOBAL:
        case OP_GET_LOCAL:
        case OP_NIL:
        case OP_TRUE:
        case OP_FALSE:
            return true;
        default:
            return false;
    }
}

bool VisualGasicOptimizer::is_unconditional_exit(uint8_t op) {
    return op == OP_JUMP || op == OP_RETURN || op == OP_RETURN_VALUE;
}

int VisualGasicOptimizer::resolve_jump(const Vector<uint8_t>& code, int ip) {
    // Jump opcodes store 16-bit offset: [OP] [HI] [LO]
    // For forward jumps (JUMP, JUMP_IF_*): target = ip + 3 + offset
    // For backward jumps (LOOP): target = ip + 3 - offset
    if (ip + 2 >= code.size()) return ip;
    uint8_t op = code[ip];
    int hi = code[ip + 1];
    int lo = code[ip + 2];
    int offset = (hi << 8) | lo;
    if (op == OP_LOOP) {
        return (ip + 3) - offset;
    }
    return (ip + 3) + offset;
}

void VisualGasicOptimizer::patch_jump_target(Vector<uint8_t>& code, int ip, int target) {
    if (ip + 2 >= code.size()) return;
    uint8_t op = code[ip];
    int offset;
    if (op == OP_LOOP) {
        offset = (ip + 3) - target;
    } else {
        offset = target - (ip + 3);
    }
    if (offset < 0) offset = 0;
    if (offset > 0xFFFF) offset = 0xFFFF;
    code.write[ip + 1] = (uint8_t)((offset >> 8) & 0xFF);
    code.write[ip + 2] = (uint8_t)(offset & 0xFF);
}

// ============================================================================
//  NOP-out & Compact
// ============================================================================

void VisualGasicOptimizer::nop_out(BytecodeChunk* chunk, int start, int count) {
    for (int i = start; i < start + count && i < chunk->code.size(); i++) {
        chunk->code.write[i] = OP_NOP;
    }
}

void VisualGasicOptimizer::erase_bytes(BytecodeChunk* chunk, int start, int count) {
    // Build a mapping from old positions to new positions
    Vector<int> old_to_new;
    old_to_new.resize(chunk->code.size() + 1);
    int shift = 0;
    for (int i = 0; i < chunk->code.size(); i++) {
        if (i >= start && i < start + count) {
            old_to_new.write[i] = -1; // removed
            shift++;
        } else {
            old_to_new.write[i] = i - shift;
        }
    }
    old_to_new.write[chunk->code.size()] = chunk->code.size() - shift;

    // Fix all jump targets BEFORE removing bytes
    for (int ip = 0; ip < chunk->code.size();) {
        uint8_t op = chunk->code[ip];
        if (op == OP_JUMP || op == OP_JUMP_IF_FALSE || op == OP_JUMP_IF_TRUE || op == OP_LOOP) {
            if (ip < start || ip >= start + count) {
                int target = resolve_jump(chunk->code, ip);
                if (target >= 0 && target <= chunk->code.size()) {
                    int new_ip = old_to_new[ip];
                    int new_target;
                    if (target < chunk->code.size()) {
                        new_target = old_to_new[target];
                        if (new_target < 0) {
                            // Target was in removed region — find next valid position
                            for (int t = target; t < chunk->code.size(); t++) {
                                if (old_to_new[t] >= 0) {
                                    new_target = old_to_new[t];
                                    break;
                                }
                            }
                        }
                    } else {
                        new_target = old_to_new[chunk->code.size()];
                    }
                    if (new_ip >= 0 && new_target >= 0) {
                        // Temporarily patch with new absolute positions — we'll recalculate offset
                        int new_offset;
                        if (op == OP_LOOP) {
                            new_offset = (new_ip + 3) - new_target;
                        } else {
                            new_offset = new_target - (new_ip + 3);
                        }
                        if (new_offset < 0) new_offset = 0;
                        if (new_offset > 0xFFFF) new_offset = 0xFFFF;
                        chunk->code.write[ip + 1] = (uint8_t)((new_offset >> 8) & 0xFF);
                        chunk->code.write[ip + 2] = (uint8_t)(new_offset & 0xFF);
                    }
                }
            }
        }
        int sz = instruction_size(chunk->code, ip);
        ip += sz;
    }

    // Now physically remove the bytes
    Vector<uint8_t> new_code;
    Vector<int> new_lines;
    new_code.resize(chunk->code.size() - count);
    new_lines.resize(chunk->code.size() - count);
    int dst = 0;
    for (int i = 0; i < chunk->code.size(); i++) {
        if (i >= start && i < start + count) continue;
        new_code.write[dst] = chunk->code[i];
        new_lines.write[dst] = (i < chunk->lines.size()) ? chunk->lines[i] : 0;
        dst++;
    }
    chunk->code = new_code;
    chunk->lines = new_lines;
}

void VisualGasicOptimizer::compact(BytecodeChunk* chunk) {
    // Count NOPs to remove
    int nop_count = 0;
    for (int i = 0; i < chunk->code.size(); i++) {
        if (chunk->code[i] == OP_NOP) nop_count++;
    }
    if (nop_count == 0) return;

    // Build position mapping
    Vector<int> old_to_new;
    old_to_new.resize(chunk->code.size() + 1);
    int shift = 0;
    for (int i = 0; i < chunk->code.size(); i++) {
        if (chunk->code[i] == OP_NOP) {
            old_to_new.write[i] = -1;
            shift++;
        } else {
            old_to_new.write[i] = i - shift;
        }
    }
    old_to_new.write[chunk->code.size()] = chunk->code.size() - shift;

    // Fix jump offsets
    for (int ip = 0; ip < chunk->code.size();) {
        uint8_t op = chunk->code[ip];
        if (op == OP_NOP) {
            ip++;
            continue;
        }
        if (op == OP_JUMP || op == OP_JUMP_IF_FALSE || op == OP_JUMP_IF_TRUE || op == OP_LOOP) {
            int target = resolve_jump(chunk->code, ip);
            int new_ip = old_to_new[ip];
            int new_target;

            if (target >= chunk->code.size()) {
                new_target = old_to_new[chunk->code.size()];
            } else if (target < 0) {
                new_target = 0;
            } else {
                new_target = old_to_new[target];
                if (new_target < 0) {
                    // Find next non-NOP position
                    for (int t = target; t < chunk->code.size(); t++) {
                        if (old_to_new[t] >= 0) {
                            new_target = old_to_new[t];
                            break;
                        }
                    }
                    if (new_target < 0) {
                        new_target = old_to_new[chunk->code.size()];
                    }
                }
            }

            int new_offset;
            if (op == OP_LOOP) {
                new_offset = (new_ip + 3) - new_target;
            } else {
                new_offset = new_target - (new_ip + 3);
            }
            if (new_offset < 0) new_offset = 0;
            if (new_offset > 0xFFFF) new_offset = 0xFFFF;
            chunk->code.write[ip + 1] = (uint8_t)((new_offset >> 8) & 0xFF);
            chunk->code.write[ip + 2] = (uint8_t)(new_offset & 0xFF);
        }
        ip += instruction_size(chunk->code, ip);
    }

    // Remove NOPs
    Vector<uint8_t> new_code;
    Vector<int> new_lines;
    for (int i = 0; i < chunk->code.size(); i++) {
        if (chunk->code[i] != OP_NOP) {
            new_code.push_back(chunk->code[i]);
            new_lines.push_back((i < chunk->lines.size()) ? chunk->lines[i] : 0);
        }
    }
    chunk->code = new_code;
    chunk->lines = new_lines;
}

// ============================================================================
//  Pass: Redundant Load/Store — SET_LOCAL x; GET_LOCAL x → keep SET, value stays
//  Actually: we NOP-out the GET_LOCAL since after SET_LOCAL x the value was popped
//  from stack. So we need to check if the value is still needed on stack.
//  Safer pattern: GET_LOCAL x; SET_LOCAL y; GET_LOCAL y → GET_LOCAL x; SET_LOCAL y
//  (eliminate redundant re-read of just-written local)
// ============================================================================

bool VisualGasicOptimizer::pass_redundant_load_store(BytecodeChunk* chunk, Stats& stats) {
    bool changed = false;
    auto& code = chunk->code;

    for (int ip = 0; ip + 3 < code.size();) {
        int sz = instruction_size(code, ip);
        int next_ip = ip + sz;
        if (next_ip + 1 >= code.size()) {
            ip = next_ip;
            continue;
        }

        // Pattern: SET_LOCAL x; GET_LOCAL x → NOP the GET_LOCAL
        // The SET_LOCAL pops from stack, so GET_LOCAL x re-pushes the same value.
        // If we keep the value on stack (don't pop during SET), we can skip the GET.
        // BUT: SET_LOCAL semantics pop the value. We can't change that without a new opcode.
        //
        // Alternative safe pattern: If there's a GET_LOCAL x immediately before SET_LOCAL x,
        // we have: GET x → [some computation] → SET x → GET x
        // The SET x; GET x part means "write x, then immediately read it back".
        // We can instead do "DUP; SET x" and skip the GET x.
        // But DUP doesn't exist in our ISA. So we look for a simpler pattern:
        //
        // OP_CONSTANT c; OP_SET_LOCAL x; OP_GET_LOCAL x
        // → OP_CONSTANT c; OP_SET_LOCAL x; OP_CONSTANT c (same effect, avoids var read)
        //
        // Actually the simplest safe optimization:
        // SET_LOCAL x followed immediately by GET_LOCAL x with same slot.
        // This means the compiler generated a write-then-read sequence.
        // We leave the SET and replace GET with a re-push of the same expression.
        // Since we can't DUP, we just leave this pattern alone for safety.
        //
        // Let's look for: GET_LOCAL x; POP → useless read → NOP both
        if (code[ip] == OP_GET_LOCAL && code[next_ip] == OP_POP) {
            nop_out(chunk, ip, 2 + 1); // 2 bytes for GET_LOCAL, 1 for POP
            stats.dead_pop++;
            changed = true;
            ip = next_ip + 1;
            continue;
        }

        // Pattern: GET_GLOBAL x; POP → useless read → NOP both
        if (code[ip] == OP_GET_GLOBAL && code[next_ip] == OP_POP) {
            nop_out(chunk, ip, 2 + 1);
            stats.dead_pop++;
            changed = true;
            ip = next_ip + 1;
            continue;
        }

        ip = next_ip;
    }
    return changed;
}

// ============================================================================
//  Pass: Dead Pop — CONSTANT/NIL/TRUE/FALSE immediately followed by POP
// ============================================================================

bool VisualGasicOptimizer::pass_dead_pop(BytecodeChunk* chunk, Stats& stats) {
    bool changed = false;
    auto& code = chunk->code;

    for (int ip = 0; ip < code.size();) {
        int sz = instruction_size(code, ip);
        int next_ip = ip + sz;
        if (next_ip >= code.size()) break;

        if (code[next_ip] == OP_POP && is_push_one(code[ip])) {
            // Push immediately followed by Pop — useless
            nop_out(chunk, ip, sz + 1);
            stats.dead_pop++;
            changed = true;
            ip = next_ip + 1;
            continue;
        }

        ip = next_ip;
    }
    return changed;
}

// ============================================================================
//  Pass: Constant Folding — CONST a; CONST b; binary_op → CONST result
// ============================================================================

bool VisualGasicOptimizer::pass_constant_fold(BytecodeChunk* chunk, Stats& stats) {
    bool changed = false;
    auto& code = chunk->code;
    auto& constants = chunk->constants;

    for (int ip = 0; ip + 4 < code.size();) {
        // Look for: OP_CONSTANT idx_a; OP_CONSTANT idx_b; OP_binary
        if (code[ip] != OP_CONSTANT) {
            ip += instruction_size(code, ip);
            continue;
        }
        int ip_b = ip + 2;
        if (ip_b >= code.size() || code[ip_b] != OP_CONSTANT) {
            ip += 2;
            continue;
        }
        int ip_op = ip_b + 2;
        if (ip_op >= code.size()) {
            ip += 2;
            continue;
        }

        uint8_t idx_a = code[ip + 1];
        uint8_t idx_b = code[ip_b + 1];
        if (idx_a >= constants.size() || idx_b >= constants.size()) {
            ip += 2;
            continue;
        }

        Variant a = constants[idx_a];
        Variant b = constants[idx_b];
        uint8_t op = code[ip_op];

        // Only fold numeric and string operations
        Variant result;
        bool can_fold = false;

        if ((a.get_type() == Variant::INT || a.get_type() == Variant::FLOAT) &&
            (b.get_type() == Variant::INT || b.get_type() == Variant::FLOAT)) {

            switch (op) {
                case OP_ADD: case OP_ADD_I64: case OP_ADD_F64: {
                    bool valid = false;
                    Variant::evaluate(Variant::OP_ADD, a, b, result, valid);
                    can_fold = valid;
                } break;
                case OP_SUBTRACT: case OP_SUB_I64: case OP_SUB_F64: {
                    bool valid = false;
                    Variant::evaluate(Variant::OP_SUBTRACT, a, b, result, valid);
                    can_fold = valid;
                } break;
                case OP_MULTIPLY: case OP_MUL_I64: case OP_MUL_F64: {
                    bool valid = false;
                    Variant::evaluate(Variant::OP_MULTIPLY, a, b, result, valid);
                    can_fold = valid;
                } break;
                case OP_DIVIDE: case OP_DIV_F64: {
                    if (b.operator double() != 0.0) {
                        bool valid = false;
                        Variant::evaluate(Variant::OP_DIVIDE, a, b, result, valid);
                        can_fold = valid;
                    }
                } break;
                case OP_MOD: {
                    if (b.operator int64_t() != 0) {
                        bool valid = false;
                        Variant::evaluate(Variant::OP_MODULE, a, b, result, valid);
                        can_fold = valid;
                    }
                } break;
                case OP_POWER: {
                    bool valid = false;
                    Variant::evaluate(Variant::OP_POWER, a, b, result, valid);
                    can_fold = valid;
                } break;
                default: break;
            }
        }

        // String concatenation
        if (a.get_type() == Variant::STRING && b.get_type() == Variant::STRING && op == OP_CONCAT) {
            result = a.operator String() + b.operator String();
            can_fold = true;
        }

        if (can_fold) {
            // Add the result as a new constant
            int new_idx = chunk->add_constant(result);
            if (new_idx <= 255) {
                // Replace 5 bytes (CONST a + CONST b + OP) with CONST result + 4 NOPs
                int line = (ip < chunk->lines.size()) ? chunk->lines[ip] : 0;
                code.write[ip] = OP_CONSTANT;
                code.write[ip + 1] = (uint8_t)new_idx;
                nop_out(chunk, ip + 2, 3); // NOP out remaining 3 bytes
                stats.constant_fold++;
                changed = true;
                ip += 5;
                continue;
            }
        }

        ip += 2;
    }
    return changed;
}

// ============================================================================
//  Pass: Jump Threading — JUMP → target is another JUMP → go to final target
// ============================================================================

bool VisualGasicOptimizer::pass_jump_threading(BytecodeChunk* chunk, Stats& stats) {
    bool changed = false;
    auto& code = chunk->code;

    for (int ip = 0; ip < code.size();) {
        uint8_t op = code[ip];
        if (op == OP_JUMP || op == OP_JUMP_IF_FALSE || op == OP_JUMP_IF_TRUE) {
            int target = resolve_jump(code, ip);
            // Follow chain of unconditional jumps
            int hops = 0;
            while (target >= 0 && target + 2 < code.size() &&
                   code[target] == OP_JUMP && hops < 10) {
                target = resolve_jump(code, target);
                hops++;
            }
            if (hops > 0) {
                patch_jump_target(code, ip, target);
                stats.jump_thread++;
                changed = true;
            }
        }
        ip += instruction_size(code, ip);
    }
    return changed;
}

// ============================================================================
//  Pass: Dead Code Elimination — bytes after unconditional JUMP/RETURN
//  that aren't jump targets are unreachable → NOP them out
// ============================================================================

bool VisualGasicOptimizer::pass_dead_code_elimination(BytecodeChunk* chunk, Stats& stats) {
    auto& code = chunk->code;
    if (code.size() == 0) return false;

    // Step 1: collect all jump targets (they're reachable entry points)
    HashSet<int> jump_targets;
    for (int ip = 0; ip < code.size();) {
        uint8_t op = code[ip];
        if (op == OP_JUMP || op == OP_JUMP_IF_FALSE || op == OP_JUMP_IF_TRUE || op == OP_LOOP) {
            int target = resolve_jump(code, ip);
            if (target >= 0 && target < code.size()) {
                jump_targets.insert(target);
            }
        }
        ip += instruction_size(code, ip);
    }

    // Step 2: scan for unreachable code after unconditional exits
    bool changed = false;
    for (int ip = 0; ip < code.size();) {
        uint8_t op = code[ip];
        int sz = instruction_size(code, ip);
        int next_ip = ip + sz;

        if (is_unconditional_exit(op)) {
            // NOP out everything from next_ip until we hit a jump target or end
            int dead_start = next_ip;
            int dead_ip = next_ip;
            while (dead_ip < code.size() && !jump_targets.has(dead_ip)) {
                dead_ip += instruction_size(code, dead_ip);
            }
            if (dead_ip > dead_start) {
                int count = dead_ip - dead_start;
                nop_out(chunk, dead_start, count);
                stats.dead_code += count;
                changed = true;
                ip = dead_ip;
                continue;
            }
        }
        ip = next_ip;
    }
    return changed;
}

// ============================================================================
//  Pass: Identity Operations — CONST 0; ADD → remove both (+0)
//  CONST 1; MULTIPLY → remove both (*1), CONST 0; SUBTRACT → NEGATE, etc.
// ============================================================================

bool VisualGasicOptimizer::pass_identity_ops(BytecodeChunk* chunk, Stats& stats) {
    bool changed = false;
    auto& code = chunk->code;
    auto& constants = chunk->constants;

    for (int ip = 0; ip + 2 < code.size();) {
        // Pattern: ... ; CONSTANT idx; OP  where the constant is an identity
        if (code[ip] == OP_CONSTANT && ip + 2 < code.size()) {
            uint8_t idx = code[ip + 1];
            uint8_t next_op = code[ip + 2];

            if (idx < constants.size()) {
                Variant val = constants[idx];
                bool is_zero = false;
                bool is_one = false;

                if (val.get_type() == Variant::INT) {
                    is_zero = (val.operator int64_t() == 0);
                    is_one = (val.operator int64_t() == 1);
                } else if (val.get_type() == Variant::FLOAT) {
                    is_zero = (val.operator double() == 0.0);
                    is_one = (val.operator double() == 1.0);
                }

                // x + 0 = x, x - 0 = x
                if (is_zero && (next_op == OP_ADD || next_op == OP_ADD_I64 ||
                                next_op == OP_ADD_F64 || next_op == OP_SUBTRACT ||
                                next_op == OP_SUB_I64 || next_op == OP_SUB_F64)) {
                    nop_out(chunk, ip, 3); // remove CONSTANT 0 + ADD/SUB
                    stats.identity_ops++;
                    changed = true;
                    ip += 3;
                    continue;
                }

                // x * 1 = x, x / 1 = x
                if (is_one && (next_op == OP_MULTIPLY || next_op == OP_MUL_I64 ||
                               next_op == OP_MUL_F64 || next_op == OP_DIVIDE ||
                               next_op == OP_DIV_F64)) {
                    nop_out(chunk, ip, 3);
                    stats.identity_ops++;
                    changed = true;
                    ip += 3;
                    continue;
                }

                // x * 0 = 0 (replace entire sequence with CONST 0)
                // But this changes stack effect — the value before * is consumed.
                // Skip this for safety.
            }
        }
        ip += instruction_size(code, ip);
    }
    return changed;
}

// ============================================================================
//  Pass: Double Negation — NOT; NOT → remove both
// ============================================================================

bool VisualGasicOptimizer::pass_double_negation(BytecodeChunk* chunk, Stats& stats) {
    bool changed = false;
    auto& code = chunk->code;

    for (int ip = 0; ip + 1 < code.size();) {
        if (code[ip] == OP_NOT && code[ip + 1] == OP_NOT) {
            nop_out(chunk, ip, 2);
            stats.double_negation++;
            changed = true;
            ip += 2;
            continue;
        }
        // Also: NEGATE; NEGATE → remove both
        if (code[ip] == OP_NEGATE && code[ip + 1] == OP_NEGATE) {
            nop_out(chunk, ip, 2);
            stats.double_negation++;
            changed = true;
            ip += 2;
            continue;
        }
        ip += instruction_size(code, ip);
    }
    return changed;
}

// ============================================================================
//  Pass: Strength Reduction — CONST 2; MUL → DUP + ADD (but no DUP exists)
//  Instead: CONST 2; MUL_I64 → ADD_LOCAL_I64_STACK (if preceded by GET_LOCAL)
//  We keep this simple for now: just flag for future optimization.
// ============================================================================

bool VisualGasicOptimizer::pass_strength_reduction(BytecodeChunk* chunk, Stats& stats) {
    bool changed = false;
    auto& code = chunk->code;
    auto& constants = chunk->constants;

    for (int ip = 0; ip + 2 < code.size();) {
        // Pattern: CONST 2; MUL → can be strength-reduced if preceded by GET_LOCAL
        // GET_LOCAL x; CONST 2; MUL_I64 → GET_LOCAL x; GET_LOCAL x; ADD_I64
        // This is 3 instructions either way but ADD is faster than MUL.
        // We'd need to insert a byte, which changes offsets. Skip for safety.

        // Simpler pattern: CONST -1; MUL → NEGATE
        if (code[ip] == OP_CONSTANT && ip + 2 < code.size()) {
            uint8_t idx = code[ip + 1];
            uint8_t next_op = code[ip + 2];
            if (idx < constants.size()) {
                Variant val = constants[idx];
                bool is_neg_one = false;
                if (val.get_type() == Variant::INT) {
                    is_neg_one = (val.operator int64_t() == -1);
                } else if (val.get_type() == Variant::FLOAT) {
                    is_neg_one = (val.operator double() == -1.0);
                }

                if (is_neg_one && (next_op == OP_MULTIPLY || next_op == OP_MUL_I64 || next_op == OP_MUL_F64)) {
                    // Replace CONST(-1) + MUL → NEGATE + NOP + NOP
                    code.write[ip] = OP_NEGATE;
                    nop_out(chunk, ip + 1, 2);
                    stats.strength_reduction++;
                    changed = true;
                    ip += 3;
                    continue;
                }
            }
        }

        ip += instruction_size(code, ip);
    }
    return changed;
}

// ============================================================================
//  Pass: Strip Debug Lines — Remove OP_DEBUG_LINE instructions (release mode)
// ============================================================================

bool VisualGasicOptimizer::pass_strip_debug_lines(BytecodeChunk* chunk, Stats& stats) {
    bool changed = false;
    auto& code = chunk->code;

    for (int ip = 0; ip < code.size();) {
        if (code[ip] == OP_DEBUG_LINE) {
            nop_out(chunk, ip, 3);
            stats.debug_line_stripped++;
            changed = true;
            ip += 3;
            continue;
        }
        ip += instruction_size(code, ip);
    }
    return changed;
}

// ============================================================================
//  Main Optimizer Entry Point
// ============================================================================

VisualGasicOptimizer::Stats VisualGasicOptimizer::optimize(BytecodeChunk* chunk, bool strip_debug) {
    Stats stats;
    if (!chunk || chunk->code.size() == 0) return stats;

    stats.total_bytes_before = chunk->code.size();

    // Run optimization passes in a fixed-point loop (max 8 iterations)
    for (int iteration = 0; iteration < 8; iteration++) {
        bool any_changed = false;

        // Strip debug lines first if requested (creates more optimization opportunities)
        if (strip_debug) {
            any_changed |= pass_strip_debug_lines(chunk, stats);
        }

        // Peephole passes
        any_changed |= pass_dead_pop(chunk, stats);
        any_changed |= pass_redundant_load_store(chunk, stats);
        any_changed |= pass_constant_fold(chunk, stats);
        any_changed |= pass_identity_ops(chunk, stats);
        any_changed |= pass_double_negation(chunk, stats);
        any_changed |= pass_strength_reduction(chunk, stats);

        // Control flow passes
        any_changed |= pass_jump_threading(chunk, stats);
        any_changed |= pass_dead_code_elimination(chunk, stats);

        // Compact: remove NOPs and fix all jump offsets
        compact(chunk);

        if (!any_changed) break;
    }

    stats.total_bytes_after = chunk->code.size();
    return stats;
}
