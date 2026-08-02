// VisualGasic JIT Tier 2 — Native x86-64 Function Body Compilation
// See visual_gasic_jit_tier2.h for design overview.

#include "visual_gasic_jit_tier2.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <cstring>
#include <cstdlib>
#include <algorithm>
#include <unordered_set>

using namespace godot;

namespace vgjit2 {

// ═══════════════════════════════════════════════════════════════════
//  CompiledFunc destructor — free executable memory
// ═══════════════════════════════════════════════════════════════════

CompiledFunc::~CompiledFunc() {
#ifdef __linux__
    if (code_mem) {
        munmap(code_mem, code_size);
    }
#endif
}

// ═══════════════════════════════════════════════════════════════════
//  CodeBuf — x86-64 assembler helpers
// ═══════════════════════════════════════════════════════════════════

void CodeBuf::reset() {
    buf_.clear();
    fixups_.clear();
    label_pos_.clear();
}

int CodeBuf::new_label() {
    int id = (int)label_pos_.size();
    label_pos_.push_back(-1);
    return id;
}

void CodeBuf::bind_label(int id) {
    if (id >= 0 && id < (int)label_pos_.size()) {
        label_pos_[id] = (int)buf_.size();
    }
}

bool CodeBuf::resolve() {
    for (auto& f : fixups_) {
        if (f.label_id < 0 || f.label_id >= (int)label_pos_.size()) {
            return false;
        }
        int target = label_pos_[f.label_id];
        if (target < 0) {
            return false;
        }
        // rel32 patch: target - (patch_offset + 4)
        int32_t rel = (int32_t)(target - (int)(f.patch_offset + 4));
        memcpy(&buf_[f.patch_offset], &rel, 4);
    }
    return true;
}

void CodeBuf::emit_i32(int32_t v) {
    uint8_t b[4];
    memcpy(b, &v, 4);
    for (int i = 0; i < 4; i++) buf_.push_back(b[i]);
}

void CodeBuf::emit_u64(uint64_t v) {
    uint8_t b[8];
    memcpy(b, &v, 8);
    for (int i = 0; i < 8; i++) buf_.push_back(b[i]);
}

// REX prefix: [0100WRXB]
void CodeBuf::rex(bool w, bool r, bool x, bool b) {
    uint8_t v = 0x40;
    if (w) v |= 0x08;
    if (r) v |= 0x04;
    if (x) v |= 0x02;
    if (b) v |= 0x01;
    emit(v);
}

void CodeBuf::modrm(uint8_t mod, uint8_t reg, uint8_t rm) {
    emit((uint8_t)((mod << 6) | ((reg & 7) << 3) | (rm & 7)));
}

// Helper: does register need REX.B or REX.R?
static bool needs_ext(Reg r) { return (uint8_t)r >= 8 && (uint8_t)r <= 15; }
static uint8_t lo3(Reg r) { return (uint8_t)r & 7; }

// push r64
void CodeBuf::push_r(Reg r) {
    if (needs_ext(r)) rex(false, false, false, true);
    emit(0x50 + lo3(r));
}

// pop r64
void CodeBuf::pop_r(Reg r) {
    if (needs_ext(r)) rex(false, false, false, true);
    emit(0x58 + lo3(r));
}

// mov r64, r64
void CodeBuf::mov_rr(Reg dst, Reg src) {
    rex(true, needs_ext(src), false, needs_ext(dst));
    emit(0x89);
    modrm(3, lo3(src), lo3(dst));
}

// mov r64, imm64
void CodeBuf::mov_ri64(Reg dst, int64_t imm) {
    rex(true, false, false, needs_ext(dst));
    emit(0xB8 + lo3(dst));
    emit_u64((uint64_t)imm);
}

// mov r32, imm32 (zero-extends to 64-bit)
void CodeBuf::mov_ri32(Reg dst, int32_t imm) {
    if (needs_ext(dst)) rex(false, false, false, true);
    emit(0xB8 + lo3(dst));
    emit_i32(imm);
}

// add r64, r64
void CodeBuf::add_rr(Reg dst, Reg src) {
    rex(true, needs_ext(src), false, needs_ext(dst));
    emit(0x01);
    modrm(3, lo3(src), lo3(dst));
}

// sub r64, r64
void CodeBuf::sub_rr(Reg dst, Reg src) {
    rex(true, needs_ext(src), false, needs_ext(dst));
    emit(0x29);
    modrm(3, lo3(src), lo3(dst));
}

// imul r64, r64
void CodeBuf::imul_rr(Reg dst, Reg src) {
    rex(true, needs_ext(dst), false, needs_ext(src));
    emit(0x0F); emit(0xAF);
    modrm(3, lo3(dst), lo3(src));
}

// and r64, r64
void CodeBuf::and_rr(Reg dst, Reg src) {
    rex(true, needs_ext(src), false, needs_ext(dst));
    emit(0x21);
    modrm(3, lo3(src), lo3(dst));
}

// or r64, r64
void CodeBuf::or_rr(Reg dst, Reg src) {
    rex(true, needs_ext(src), false, needs_ext(dst));
    emit(0x09);
    modrm(3, lo3(src), lo3(dst));
}

// xor r64, r64
void CodeBuf::xor_rr(Reg dst, Reg src) {
    rex(true, needs_ext(src), false, needs_ext(dst));
    emit(0x31);
    modrm(3, lo3(src), lo3(dst));
}

// neg r64
void CodeBuf::neg_r(Reg r) {
    rex(true, false, false, needs_ext(r));
    emit(0xF7);
    modrm(3, 3, lo3(r));
}

// inc r64
void CodeBuf::inc_r(Reg r) {
    rex(true, false, false, needs_ext(r));
    emit(0xFF);
    modrm(3, 0, lo3(r));
}

// cmp r64, r64
void CodeBuf::cmp_rr(Reg a, Reg b) {
    rex(true, needs_ext(b), false, needs_ext(a));
    emit(0x39);
    modrm(3, lo3(b), lo3(a));
}

// test r64, r64
void CodeBuf::test_rr(Reg a, Reg b) {
    rex(true, needs_ext(b), false, needs_ext(a));
    emit(0x85);
    modrm(3, lo3(b), lo3(a));
}

// Conditional set helpers: setCC r/m8, then movzx r64, r/m8
// Uses the actual destination register directly when possible to avoid
// unnecessary moves through RAX.
static void emit_setcc(CodeBuf& cb, Reg dst, uint8_t cc_byte) {
    // setCC requires an 8-bit register (al, cl, dl, bl, sil, dil, r8b..r15b).
    // We write to the low byte of dst, then zero-extend.
    uint8_t lo = lo3(dst);
    bool ext = needs_ext(dst);
    // REX prefix needed for sil/dil/r8b+ or if dst >= R8
    if (ext || (uint8_t)dst >= 4) {
        cb.rex(false, false, false, ext);
    }
    cb.emit(0x0F); cb.emit(cc_byte);
    cb.modrm(3, 0, lo);
    // movzx r64, low byte of dst
    cb.rex(true, ext, false, ext);
    cb.emit(0x0F); cb.emit(0xB6);
    cb.modrm(3, lo, lo);
}

void CodeBuf::sete(Reg dst)  { emit_setcc(*this, dst, 0x94); }
void CodeBuf::setne(Reg dst) { emit_setcc(*this, dst, 0x95); }
void CodeBuf::setle(Reg dst) { emit_setcc(*this, dst, 0x9E); }
void CodeBuf::setl(Reg dst)  { emit_setcc(*this, dst, 0x9C); }
void CodeBuf::setge(Reg dst) { emit_setcc(*this, dst, 0x9D); }
void CodeBuf::setg(Reg dst)  { emit_setcc(*this, dst, 0x9F); }
// Unsigned conditions (used after ucomisd for float comparisons)
void CodeBuf::setb(Reg dst)  { emit_setcc(*this, dst, 0x92); }
void CodeBuf::setbe(Reg dst) { emit_setcc(*this, dst, 0x96); }
void CodeBuf::seta(Reg dst)  { emit_setcc(*this, dst, 0x97); }
void CodeBuf::setae(Reg dst) { emit_setcc(*this, dst, 0x93); }

// ── SSE2 double-precision ──

// prefix 0xF2 0x0F <op> for scalar double
static void sse2_arith(CodeBuf& cb, uint8_t op, Reg dst, Reg src) {
    uint8_t d = (uint8_t)dst - (uint8_t)Reg::XMM0;
    uint8_t s = (uint8_t)src - (uint8_t)Reg::XMM0;
    cb.emit(0xF2);
    // REX if needed (xmm8+ would need it, but we only use xmm0-xmm7)
    cb.emit(0x0F);
    cb.emit(op);
    cb.modrm(3, d & 7, s & 7);
}

void CodeBuf::addsd(Reg dst, Reg src) { sse2_arith(*this, 0x58, dst, src); }
void CodeBuf::subsd(Reg dst, Reg src) { sse2_arith(*this, 0x5C, dst, src); }
void CodeBuf::mulsd(Reg dst, Reg src) { sse2_arith(*this, 0x59, dst, src); }
void CodeBuf::divsd(Reg dst, Reg src) { sse2_arith(*this, 0x5E, dst, src); }

void CodeBuf::xorpd(Reg dst, Reg src) {
    uint8_t d = (uint8_t)dst - (uint8_t)Reg::XMM0;
    uint8_t s = (uint8_t)src - (uint8_t)Reg::XMM0;
    emit(0x66); emit(0x0F); emit(0x57);
    modrm(3, d & 7, s & 7);
}

void CodeBuf::movsd_rr(Reg dst, Reg src) {
    uint8_t d = (uint8_t)dst - (uint8_t)Reg::XMM0;
    uint8_t s = (uint8_t)src - (uint8_t)Reg::XMM0;
    emit(0xF2); emit(0x0F); emit(0x10);
    modrm(3, d & 7, s & 7);
}

// ucomisd xmm, xmm — sets EFLAGS for float comparison
void CodeBuf::ucomisd(Reg lhs, Reg rhs) {
    uint8_t l = (uint8_t)lhs - (uint8_t)Reg::XMM0;
    uint8_t r = (uint8_t)rhs - (uint8_t)Reg::XMM0;
    emit(0x66); emit(0x0F); emit(0x2E);
    modrm(3, l & 7, r & 7);
}

// ── Memory: locals array [rdi + slot*8] ──

// mov dst, [rdi + slot*8]
void CodeBuf::load_local_i64(Reg dst, int slot) {
    int32_t disp = slot * 8;
    rex(true, needs_ext(dst), false, false);
    emit(0x8B);
    if (disp == 0) {
        modrm(0, lo3(dst), 7); // [rdi]
    } else if (disp >= -128 && disp <= 127) {
        modrm(1, lo3(dst), 7);
        emit((uint8_t)(int8_t)disp);
    } else {
        modrm(2, lo3(dst), 7);
        emit_i32(disp);
    }
}

// mov [rdi + slot*8], src
void CodeBuf::store_local_i64(int slot, Reg src) {
    int32_t disp = slot * 8;
    rex(true, needs_ext(src), false, false);
    emit(0x89);
    if (disp == 0) {
        modrm(0, lo3(src), 7);
    } else if (disp >= -128 && disp <= 127) {
        modrm(1, lo3(src), 7);
        emit((uint8_t)(int8_t)disp);
    } else {
        modrm(2, lo3(src), 7);
        emit_i32(disp);
    }
}

// movsd xmm, [rdi + slot*8]
void CodeBuf::load_local_f64(Reg xmm, int slot) {
    int32_t disp = slot * 8;
    uint8_t x = (uint8_t)xmm - (uint8_t)Reg::XMM0;
    emit(0xF2); emit(0x0F); emit(0x10);
    if (disp == 0) {
        modrm(0, x & 7, 7);
    } else if (disp >= -128 && disp <= 127) {
        modrm(1, x & 7, 7);
        emit((uint8_t)(int8_t)disp);
    } else {
        modrm(2, x & 7, 7);
        emit_i32(disp);
    }
}

// movsd [rdi + slot*8], xmm
void CodeBuf::store_local_f64(int slot, Reg xmm) {
    int32_t disp = slot * 8;
    uint8_t x = (uint8_t)xmm - (uint8_t)Reg::XMM0;
    emit(0xF2); emit(0x0F); emit(0x11);
    if (disp == 0) {
        modrm(0, x & 7, 7);
    } else if (disp >= -128 && disp <= 127) {
        modrm(1, x & 7, 7);
        emit((uint8_t)(int8_t)disp);
    } else {
        modrm(2, x & 7, 7);
        emit_i32(disp);
    }
}

// Spill: mov dst, [rbp - off]
void CodeBuf::load_spill(Reg dst, int off) {
    int32_t disp = -off;
    rex(true, needs_ext(dst), false, false);
    emit(0x8B);
    if (disp >= -128 && disp <= 127) {
        modrm(1, lo3(dst), 5); // [rbp + disp8]
        emit((uint8_t)(int8_t)disp);
    } else {
        modrm(2, lo3(dst), 5);
        emit_i32(disp);
    }
}

void CodeBuf::store_spill(int off, Reg src) {
    int32_t disp = -off;
    rex(true, needs_ext(src), false, false);
    emit(0x89);
    if (disp >= -128 && disp <= 127) {
        modrm(1, lo3(src), 5);
        emit((uint8_t)(int8_t)disp);
    } else {
        modrm(2, lo3(src), 5);
        emit_i32(disp);
    }
}

// ── Jumps ──

void CodeBuf::jmp_label(int id) {
    emit(0xE9);
    Fixup f; f.label_id = id; f.patch_offset = (int)buf_.size();
    fixups_.push_back(f);
    emit_i32(0); // placeholder
}

void CodeBuf::je_label(int id) {
    emit(0x0F); emit(0x84);
    Fixup f; f.label_id = id; f.patch_offset = (int)buf_.size();
    fixups_.push_back(f);
    emit_i32(0);
}

void CodeBuf::jne_label(int id) {
    emit(0x0F); emit(0x85);
    Fixup f; f.label_id = id; f.patch_offset = (int)buf_.size();
    fixups_.push_back(f);
    emit_i32(0);
}

// ── Prologue / Epilogue ──

void CodeBuf::prologue(int spill_bytes) {
    // push rbp; mov rbp, rsp
    push_r(Reg::RBP);
    mov_rr(Reg::RBP, Reg::RSP);
    // Save callee-saved registers we use: rbx, r12, r13, r14, r15
    push_r(Reg::RBX);
    push_r(Reg::R12);
    push_r(Reg::R13);
    push_r(Reg::R14);
    push_r(Reg::R15);
    // Allocate spill area
    if (spill_bytes > 0) {
        // sub rsp, spill_bytes (align to 16)
        int aligned = (spill_bytes + 15) & ~15;
        rex(true, false, false, false);
        emit(0x81); modrm(3, 5, 4); // sub rsp, imm32
        emit_i32(aligned);
    }
}

void CodeBuf::epilogue() {
    // Stack layout: old_rbp [rbp], rbx, r12, r13, r14, r15, [spill...]
    // We need to skip the spill area first by restoring RSP to just below
    // the callee-saved registers: lea rsp, [rbp - 40]  (5 regs * 8 = 40)
    // REX.W LEA RSP, [RBP - 40]  → 48 8D 65 D8
    emit(0x48); emit(0x8D); emit(0x65); emit((uint8_t)(int8_t)-40);
    // Restore callee-saved (reverse order)
    pop_r(Reg::R15);
    pop_r(Reg::R14);
    pop_r(Reg::R13);
    pop_r(Reg::R12);
    pop_r(Reg::RBX);
    // pop rbp; ret
    pop_r(Reg::RBP);
    emit(0xC3);
}

// ═══════════════════════════════════════════════════════════════════
//  Bytecode → IR lowering
// ═══════════════════════════════════════════════════════════════════

// Helper to read a 16-bit value from bytecode
static int read_u16(const uint8_t* code, int ip) {
    return ((int)code[ip] << 8) | (int)code[ip+1];
}

bool Tier2::lower_bytecode(BytecodeChunk* chunk, std::vector<IRInst>& ir, int& vreg_count,
                           std::vector<std::pair<std::string, int>>& global_slots, int& total_slots) {
    const uint8_t* code = chunk->code.ptr();
    int size = chunk->code.size();
    int next_vreg = 0;
    
    // Simulated value stack → maps to virtual registers
    std::vector<int> vstack;
    
    // vreg → integer constant value (for constant-shift-count detection)
    std::unordered_map<int, int64_t> vreg_const_i64;
    
    // Track the type of each vreg so generic comparisons use correct type
    std::vector<IRType> vreg_type_map;
    auto set_vreg_type = [&](int vreg, IRType t) {
        if (vreg >= (int)vreg_type_map.size()) vreg_type_map.resize(vreg + 1, IRType::I64);
        vreg_type_map[vreg] = t;
    };
    auto get_vreg_type = [&](int vreg) -> IRType {
        if (vreg >= 0 && vreg < (int)vreg_type_map.size()) return vreg_type_map[vreg];
        return IRType::I64;
    };
    
    // Track the type of each local slot so LOAD_LOCAL inherits the correct type
    // when a local was previously stored from an F64 vreg.
    std::unordered_map<int, IRType> local_slot_type;
    
    // Virtual global→local slot mapping: globals get slots beyond local_count
    int base_locals = chunk->local_count;
    int next_global_slot = base_locals;
    std::unordered_map<int, int> global_const_to_slot; // constant index → virtual slot
    
    // Map bytecode IP → IR label (for jump targets)
    std::unordered_map<int, int> ip_to_label;
    
    // First pass: identify jump targets and create labels
    // We need to pre-scan for all jump destinations
    {
        int ip = 0;
        while (ip < size) {
            uint8_t op = code[ip];
            switch (op) {
                case OP_JUMP:
                case OP_JUMP_IF_FALSE:
                case OP_JUMP_IF_TRUE: {
                    int offset = read_u16(code, ip + 1);
                    int target = ip + 3 + offset;
                    if (ip_to_label.find(target) == ip_to_label.end()) {
                        ip_to_label[target] = -1; // Will assign label IDs later
                    }
                    ip += 3;
                    break;
                }
                case OP_LOOP: {
                    int offset = read_u16(code, ip + 1);
                    int target = ip + 3 - offset;
                    if (ip_to_label.find(target) == ip_to_label.end()) {
                        ip_to_label[target] = -1;
                    }
                    ip += 3;
                    break;
                }
                default: {
                    // Skip based on opcode operand count
                    // Most opcodes: 1 byte op + variable operands
                    // We use a simplified skip — if we encounter an unknown opcode, bail
                    int advance = 1;
                    switch (op) {
                        // 2-byte opcodes (op + 1 byte operand, no const pool index)
                        case OP_GET_LOCAL: case OP_SET_LOCAL:
                        case OP_CALL_BUILTIN: case OP_NEW_ARRAY: case OP_NEW_ARRAY_I64:
                        case OP_OPEN_FILE: case OP_INC_LOCAL_I64:
                        case OP_ADD_LOCAL_I64_STACK: case OP_SUB_LOCAL_I64_STACK:
                            advance = 2; break;
                        // 3-byte opcodes (op + 2-byte const index, or other 2-byte operands)
                        case OP_CONSTANT:
                        case OP_GET_GLOBAL: case OP_SET_GLOBAL:
                        case OP_ADD_I64_CONST: case OP_SUB_I64_CONST: case OP_MUL_I64_CONST:
                        case OP_GET_MEMBER: case OP_SET_MEMBER:
                        case OP_GET_ARRAY: case OP_SET_ARRAY:
                        case OP_GET_ARRAY_FAST: case OP_SET_ARRAY_FAST:
                        case OP_GET_DICT_FAST: case OP_SET_DICT_FAST:
                        case OP_SET_DICT_LOCAL:
                        case OP_ITER_ARRAY: case OP_NEW_VGDICT:
                        case OP_GET_VGDICT_LOCAL: case OP_SET_VGDICT_LOCAL:
                        case OP_PRINT_FILE: case OP_WRITE_FILE: case OP_INPUT_FILE:
                        case OP_REGISTER_WHENEVER: case OP_SUSPEND_WHENEVER: case OP_RESUME_WHENEVER:
                        case OP_ON_ERROR_GOTO: case OP_GOSUB:
                        case OP_CONSTANT_LONG:
                        case OP_COERCE_TYPE:
                            advance = 3; break;
                        case OP_DEBUG_LINE:
                            advance = 3; break;
                        case OP_JUMP: case OP_JUMP_IF_FALSE: case OP_JUMP_IF_TRUE: case OP_LOOP:
                        case OP_SETUP_TRY:
                            advance = 3; break;
                        // 4-byte opcodes (op + 2-byte const index + 1 byte operand, etc.)
                        case OP_CALL: case OP_METHOD_CALL:
                        case OP_ADD_LOCAL_I64_CONST: case OP_SUB_LOCAL_I64_CONST:
                        case OP_SET_DICT_GLOBAL:
                        case OP_RAISE_EVENT:
                        case OP_NEW_OBJECT:
                        case OP_STRING_REPEAT_OUTER:
                        case OP_PARALLEL_FOR_BEGIN:
                            advance = 4; break;
                        // 5-byte opcodes
                        case OP_ARITH_SUM:
                        case OP_ACCUM_I64_MULADD_CONST:
                            advance = 5; break;
                        // 6-byte opcodes
                        case OP_TASK_RUN_BEGIN:
                            advance = 6; break;
                        // 8-byte opcodes
                        case OP_ALLOC_FILL_REPEAT_I64:
                            advance = 8; break;
                        // 1-byte opcodes
                        case OP_POP: case OP_ADD: case OP_SUBTRACT: case OP_MULTIPLY:
                        case OP_DIVIDE: case OP_NEGATE: case OP_CONCAT: case OP_MOD:
                        case OP_INT_DIVIDE: case OP_POWER: case OP_NOT: case OP_AND:
                        case OP_OR: case OP_XOR: case OP_EQUAL: case OP_NOT_EQUAL:
                        case OP_GREATER: case OP_LESS: case OP_GREATER_EQUAL:
                        case OP_LESS_EQUAL: case OP_NIL: case OP_TRUE: case OP_FALSE:
                        case OP_PRINT: case OP_DEBUG_PRINT: case OP_RETURN: case OP_RETURN_VALUE:
                        case OP_DUP: case OP_NEW_DICT: case OP_THROW:
                        case OP_POP_TRY: case OP_ADD_I64: case OP_SUB_I64: case OP_MUL_I64:
                        case OP_ADD_F64: case OP_SUB_F64: case OP_MUL_F64: case OP_DIV_F64:
                        case OP_EQUAL_I64: case OP_NOT_EQUAL_I64: case OP_LESS_EQUAL_I64:
                        case OP_STOP: case OP_LIKE: case OP_LEN: case OP_ABS: case OP_SGN:
                        case OP_CLOSE_FILE: case OP_LINE_INPUT: case OP_RETURN_GOSUB:
                        case OP_LOCK: case OP_UNLOCK: case OP_IS_CLASS:
                        case OP_RESTORE_DATA: case OP_READ_DATA: case OP_ON_ERROR_RESUME_NEXT:
                        case OP_ON_ERROR_GOTO_0: case OP_PUSH_WITH: case OP_POP_WITH:
                        case OP_GET_WITH: case OP_DICT_HAS_KEY: case OP_DICT_SIZE:
                        case OP_DICT_CLEAR_INPLACE: case OP_DICT_KEYS: case OP_DICT_VALUES:
                        case OP_DICT_ERASE: case OP_DICT_KEYS_CALL:
                        case OP_ARRAY_RESIZE: case OP_AWAIT:
                        case OP_PARALLEL_FOR_END: case OP_TASK_RUN_END:
                            advance = 1; break;
                        case OP_TASK_WAIT: case OP_BRANCH_SUM:
                            advance = 2; break;
                        default:
                            advance = 1; break;
                    }
                    ip += advance;
                    break;
                }
            }
        }
    }
    
    // Assign label IDs
    int next_label = 0;
    for (auto& kv : ip_to_label) {
        kv.second = next_label++;
    }
    
    // Pre-analysis: identify slots that are ever modified by I64 fused opcodes.
    // These slots must always use I64 representation to avoid type mismatch across
    // loop iterations (e.g., init as F64 0.0 but incremented as I64).
    std::unordered_set<int> i64_pinned_slots;
    {
        int ip = 0;
        while (ip < size) {
            uint8_t op = code[ip];
            switch (op) {
                case OP_INC_LOCAL_I64:
                    i64_pinned_slots.insert(code[ip + 1]);
                    ip += 2; break;
                case OP_ADD_LOCAL_I64_STACK: case OP_SUB_LOCAL_I64_STACK:
                    i64_pinned_slots.insert(code[ip + 1]);
                    ip += 2; break;
                case OP_ADD_LOCAL_I64_CONST: case OP_SUB_LOCAL_I64_CONST:
                    i64_pinned_slots.insert(code[ip + 1]);
                    ip += 4; break;
                case OP_DEBUG_LINE:
                    ip += 3; break;
                case OP_JUMP: case OP_JUMP_IF_FALSE: case OP_JUMP_IF_TRUE: case OP_LOOP:
                    ip += 3; break;
                case OP_CONSTANT: case OP_GET_GLOBAL: case OP_SET_GLOBAL:
                    ip += 3; break;
                case OP_GET_LOCAL: case OP_SET_LOCAL:
                    ip += 2; break;
                case OP_CALL:
                    ip += 4; break;
                case OP_CALL_BUILTIN:
                    ip += 3; break;
                case OP_CONSTANT_LONG:
                    ip += 3; break;
                case OP_ACCUM_I64_MULADD_CONST:
                    ip += 5; break;
                default:
                    ip += 1; break;
            }
        }
    }
    
    // Second pass: generate IR
    int ip = 0;
    while (ip < size) {
        // Emit label if this IP is a jump target
        auto label_it = ip_to_label.find(ip);
        if (label_it != ip_to_label.end()) {
            IRInst lbl;
            lbl.op = IROp::LABEL;
            lbl.label_id = label_it->second;
            lbl.bc_offset = ip;
            ir.push_back(lbl);
        }
        
        uint8_t op = code[ip];
        
        switch (op) {
            case OP_CONSTANT: {
                int idx = (code[ip + 2] << 8) | code[ip + 1];
                // Check if the constant is an integer or float
                if (idx < chunk->constants.size()) {
                    Variant v = chunk->constants[idx];
                    if (v.get_type() == Variant::INT) {
                        IRInst inst;
                        inst.op = IROp::CONST_I64;
                        inst.type = IRType::I64;
                        inst.dest = next_vreg++;
                        set_vreg_type(inst.dest, IRType::I64);
                        inst.imm_i64 = (int64_t)v;
                        inst.bc_offset = ip;
                        ir.push_back(inst);
                        vstack.push_back(inst.dest);
                        vreg_const_i64[inst.dest] = inst.imm_i64;
                    } else if (v.get_type() == Variant::FLOAT) {
                        IRInst inst;
                        inst.op = IROp::CONST_F64;
                        inst.type = IRType::F64;
                        inst.dest = next_vreg++;
                        set_vreg_type(inst.dest, IRType::F64);
                        inst.imm_f64 = (double)v;
                        inst.bc_offset = ip;
                        ir.push_back(inst);
                        vstack.push_back(inst.dest);
                    } else {
                        return false; // Non-numeric constant — bail
                    }
                } else {
                    return false;
                }
                ip += 3;
                break;
            }
            
            case OP_NIL: {
                IRInst inst;
                inst.op = IROp::CONST_ZERO;
                inst.type = IRType::I64;
                inst.dest = next_vreg++;
                set_vreg_type(inst.dest, IRType::I64);
                inst.bc_offset = ip;
                ir.push_back(inst);
                vstack.push_back(inst.dest);
                ip += 1;
                break;
            }
            
            case OP_TRUE: {
                IRInst inst;
                inst.op = IROp::CONST_BOOL;
                inst.type = IRType::BOOL;
                inst.dest = next_vreg++;
                set_vreg_type(inst.dest, IRType::I64);
                inst.imm_i64 = 1;
                inst.bc_offset = ip;
                ir.push_back(inst);
                vstack.push_back(inst.dest);
                ip += 1;
                break;
            }
            
            case OP_FALSE: {
                IRInst inst;
                inst.op = IROp::CONST_BOOL;
                inst.type = IRType::BOOL;
                inst.dest = next_vreg++;
                set_vreg_type(inst.dest, IRType::I64);
                inst.imm_i64 = 0;
                inst.bc_offset = ip;
                ir.push_back(inst);
                vstack.push_back(inst.dest);
                ip += 1;
                break;
            }
            
            case OP_GET_LOCAL: {
                int slot = code[ip + 1];
                IRType slot_type = IRType::I64;
                auto stt = local_slot_type.find(slot);
                if (stt != local_slot_type.end()) slot_type = stt->second;
                IRInst inst;
                inst.op = IROp::LOAD_LOCAL;
                inst.type = slot_type;
                inst.dest = next_vreg++;
                set_vreg_type(inst.dest, slot_type);
                inst.local_slot = slot;
                inst.bc_offset = ip;
                ir.push_back(inst);
                vstack.push_back(inst.dest);
                ip += 2;
                break;
            }
            
            case OP_SET_LOCAL: {
                int slot = code[ip + 1];
                if (vstack.empty()) return false;
                int val = vstack.back(); vstack.pop_back();
                // If this slot is pinned to I64 (modified by fused I64 opcodes),
                // convert F64 values to I64 before storing so the slot stays I64.
                if (i64_pinned_slots.count(slot) && get_vreg_type(val) == IRType::F64) {
                    int conv = next_vreg++;
                    set_vreg_type(conv, IRType::I64);
                    IRInst cv; cv.op = IROp::F64_TO_I64; cv.type = IRType::I64;
                    cv.dest = conv; cv.src1 = val; cv.bc_offset = ip;
                    ir.push_back(cv);
                    val = conv;
                }
                // Track the type of the value being stored
                local_slot_type[slot] = get_vreg_type(val);
                IRInst inst;
                inst.op = IROp::STORE_LOCAL;
                inst.src1 = val;
                inst.local_slot = slot;
                inst.bc_offset = ip;
                ir.push_back(inst);
                ip += 2;
                break;
            }
            
            // ── Globals mapped to virtual local slots ──
            // Parameters and return values are globals in VisualGasic bytecode.
            // We assign each unique global a virtual local slot beyond local_count
            // so the JIT can treat them as regular locals.
            
            case OP_GET_GLOBAL: {
                int name_idx = (code[ip + 2] << 8) | code[ip + 1];
                // Resolve or assign virtual slot for this global
                auto it = global_const_to_slot.find(name_idx);
                int vslot;
                if (it != global_const_to_slot.end()) {
                    vslot = it->second;
                } else {
                    vslot = next_global_slot++;
                    global_const_to_slot[name_idx] = vslot;
                    // Record the name for the caller
                    if (name_idx < chunk->constants.size()) {
                        String gname = chunk->constants[name_idx].stringify();
                        global_slots.push_back({ std::string(gname.utf8().get_data()), vslot });
                    }
                }
                IRType slot_type = IRType::I64;
                auto stt = local_slot_type.find(vslot);
                if (stt != local_slot_type.end()) slot_type = stt->second;
                IRInst inst;
                inst.op = IROp::LOAD_LOCAL;
                inst.type = slot_type;
                inst.dest = next_vreg++;
                set_vreg_type(inst.dest, slot_type);
                inst.local_slot = vslot;
                inst.bc_offset = ip;
                ir.push_back(inst);
                vstack.push_back(inst.dest);
                ip += 3;
                break;
            }
            
            case OP_SET_GLOBAL: {
                int name_idx = (code[ip + 2] << 8) | code[ip + 1];
                if (vstack.empty()) return false;
                int val = vstack.back(); vstack.pop_back();
                // Resolve or assign virtual slot
                auto it = global_const_to_slot.find(name_idx);
                int vslot;
                if (it != global_const_to_slot.end()) {
                    vslot = it->second;
                } else {
                    vslot = next_global_slot++;
                    global_const_to_slot[name_idx] = vslot;
                    if (name_idx < chunk->constants.size()) {
                        String gname = chunk->constants[name_idx].stringify();
                        global_slots.push_back({ std::string(gname.utf8().get_data()), vslot });
                    }
                }
                local_slot_type[vslot] = get_vreg_type(val);
                IRInst inst;
                inst.op = IROp::STORE_LOCAL;
                inst.src1 = val;
                inst.local_slot = vslot;
                inst.bc_offset = ip;
                ir.push_back(inst);
                ip += 3;
                break;
            }
            
            case OP_INC_LOCAL_I64: {
                int slot = code[ip + 1];
                // Load, increment, store back
                int loaded = next_vreg++;
                set_vreg_type(loaded, IRType::I64);
                {
                    IRInst ld;
                    ld.op = IROp::LOAD_LOCAL;
                    ld.type = IRType::I64;
                    ld.dest = loaded;
                    ld.local_slot = slot;
                    ld.bc_offset = ip;
                    ir.push_back(ld);
                }
                int result = next_vreg++;
                set_vreg_type(result, IRType::I64);
                {
                    IRInst inc;
                    inc.op = IROp::INC_I64;
                    inc.type = IRType::I64;
                    inc.dest = result;
                    inc.src1 = loaded;
                    inc.bc_offset = ip;
                    ir.push_back(inc);
                }
                {
                    IRInst st;
                    st.op = IROp::STORE_LOCAL;
                    st.src1 = result;
                    st.local_slot = slot;
                    st.bc_offset = ip;
                    ir.push_back(st);
                }
                ip += 2;
                break;
            }
            
            // ── Fused local-modify opcodes ──
            // These are the critical opcodes that bench.vg inner loops emit.
            
            // OP_ADD_LOCAL_I64_STACK / OP_SUB_LOCAL_I64_STACK:
            //   [OP] [SLOT] — pop TOS as delta, locals[slot] ±= delta
            case OP_ADD_LOCAL_I64_STACK: case OP_SUB_LOCAL_I64_STACK: {
                int slot = code[ip + 1];
                if (vstack.empty()) return false;
                int delta = vstack.back(); vstack.pop_back();
                // Convert F64 delta to I64 if needed (opcode is explicitly I64)
                if (get_vreg_type(delta) == IRType::F64) {
                    int conv = next_vreg++;
                    set_vreg_type(conv, IRType::I64);
                    IRInst cv; cv.op = IROp::F64_TO_I64; cv.type = IRType::I64;
                    cv.dest = conv; cv.src1 = delta; cv.bc_offset = ip;
                    ir.push_back(cv);
                    delta = conv;
                }
                int loaded = next_vreg++;
                set_vreg_type(loaded, IRType::I64);
                { IRInst ld; ld.op = IROp::LOAD_LOCAL; ld.type = IRType::I64;
                  ld.dest = loaded; ld.local_slot = slot; ld.bc_offset = ip;
                  ir.push_back(ld); }
                int result = next_vreg++;
                set_vreg_type(result, IRType::I64);
                { IRInst ar; ar.type = IRType::I64; ar.dest = result;
                  ar.src1 = loaded; ar.src2 = delta; ar.bc_offset = ip;
                  ar.op = (op == OP_ADD_LOCAL_I64_STACK) ? IROp::ADD_I64 : IROp::SUB_I64;
                  ir.push_back(ar); }
                { IRInst st; st.op = IROp::STORE_LOCAL; st.src1 = result;
                  st.local_slot = slot; st.bc_offset = ip;
                  ir.push_back(st); }
                ip += 2;
                break;
            }
            
            // OP_ADD_LOCAL_I64_CONST / OP_SUB_LOCAL_I64_CONST:
            //   [OP] [SLOT] [CONST_IDX] — locals[slot] ±= constants[idx]
            case OP_ADD_LOCAL_I64_CONST: case OP_SUB_LOCAL_I64_CONST: {
                int slot = code[ip + 1];
                int cidx = (code[ip + 3] << 8) | code[ip + 2];
                if (cidx >= chunk->constants.size()) return false;
                Variant cv = chunk->constants[cidx];
                if (cv.get_type() != Variant::INT) return false;
                int64_t cval = (int64_t)cv;
                int loaded = next_vreg++;
                set_vreg_type(loaded, IRType::I64);
                { IRInst ld; ld.op = IROp::LOAD_LOCAL; ld.type = IRType::I64;
                  ld.dest = loaded; ld.local_slot = slot; ld.bc_offset = ip;
                  ir.push_back(ld); }
                int result = next_vreg++;
                set_vreg_type(result, IRType::I64);
                { IRInst ar; ar.type = IRType::I64; ar.dest = result;
                  ar.src1 = loaded; ar.imm_i64 = cval; ar.bc_offset = ip;
                  ar.op = (op == OP_ADD_LOCAL_I64_CONST) ? IROp::ADD_I64_CONST : IROp::SUB_I64_CONST;
                  ir.push_back(ar); }
                { IRInst st; st.op = IROp::STORE_LOCAL; st.src1 = result;
                  st.local_slot = slot; st.bc_offset = ip;
                  ir.push_back(st); }
                ip += 4;
                break;
            }
            
            // OP_ACCUM_I64_MULADD_CONST:
            //   [OP] [S_SLOT(1)] [J_SLOT(1)] [K_LO] [K_HI] — locals[s] += locals[j] * K
            case OP_ACCUM_I64_MULADD_CONST: {
                int s_slot = code[ip + 1];
                int j_slot = code[ip + 2];
                int k_idx  = (code[ip + 4] << 8) | code[ip + 3];
                if (k_idx >= chunk->constants.size()) return false;
                Variant kv = chunk->constants[k_idx];
                if (kv.get_type() != Variant::INT) return false;
                int64_t k_val = (int64_t)kv;
                // Load s, j
                int s_loaded = next_vreg++;
                set_vreg_type(s_loaded, IRType::I64);
                { IRInst ld; ld.op = IROp::LOAD_LOCAL; ld.type = IRType::I64;
                  ld.dest = s_loaded; ld.local_slot = s_slot; ld.bc_offset = ip;
                  ir.push_back(ld); }
                int j_loaded = next_vreg++;
                set_vreg_type(j_loaded, IRType::I64);
                { IRInst ld; ld.op = IROp::LOAD_LOCAL; ld.type = IRType::I64;
                  ld.dest = j_loaded; ld.local_slot = j_slot; ld.bc_offset = ip;
                  ir.push_back(ld); }
                // product = j * K
                int product = next_vreg++;
                set_vreg_type(product, IRType::I64);
                { IRInst m; m.op = IROp::MUL_I64_CONST; m.type = IRType::I64;
                  m.dest = product; m.src1 = j_loaded; m.imm_i64 = k_val; m.bc_offset = ip;
                  ir.push_back(m); }
                // result = s + product
                int result = next_vreg++;
                set_vreg_type(result, IRType::I64);
                { IRInst a; a.op = IROp::ADD_I64; a.type = IRType::I64;
                  a.dest = result; a.src1 = s_loaded; a.src2 = product; a.bc_offset = ip;
                  ir.push_back(a); }
                // Store back
                { IRInst st; st.op = IROp::STORE_LOCAL; st.src1 = result;
                  st.local_slot = s_slot; st.bc_offset = ip;
                  ir.push_back(st); }
                ip += 5;
                break;
            }
            
            // OP_ARITH_SUM: closed-form nested loop sum
            //   [OP] [K_IDX] [C_IDX]
            //   Stack: pops current_sum (top), outer_to, inner_to
            //   Computes: result = current_sum + (k * sum_j + c * n_inner) * n_outer
            //     where sum_j = inner_to * (inner_to + 1) / 2
            //           n_inner = inner_to + 1, n_outer = outer_to + 1
            //   (Assumes inner_to >= 0 and outer_to >= 0; guarded with jumps.)
            case OP_ARITH_SUM: {
                int k_idx = (code[ip + 2] << 8) | code[ip + 1];
                int c_idx = (code[ip + 4] << 8) | code[ip + 3];
                if (k_idx >= chunk->constants.size() || c_idx >= chunk->constants.size()) return false;
                Variant kv = chunk->constants[k_idx];
                Variant cv = chunk->constants[c_idx];
                if (kv.get_type() != Variant::INT || cv.get_type() != Variant::INT) return false;
                int64_t k_val = (int64_t)kv;
                int64_t c_val = (int64_t)cv;
                
                if (vstack.size() < 3) return false;
                int v_current = vstack.back(); vstack.pop_back();
                int v_outer   = vstack.back(); vstack.pop_back();
                int v_inner   = vstack.back(); vstack.pop_back();
                
                // Allocate internal labels for conditional skip
                int lbl_skip = next_label++;
                int lbl_done = next_label++;
                
                // result vreg — starts as current_sum, may be updated
                int v_result = next_vreg++;
                set_vreg_type(v_result, IRType::I64);
                { IRInst mv; mv.op = IROp::MOV; mv.type = IRType::I64;
                  mv.dest = v_result; mv.src1 = v_current; mv.bc_offset = ip;
                  ir.push_back(mv); }
                
                // Check inner_to >= 0 — compare with CONST_ZERO
                int v_zero = next_vreg++;
                set_vreg_type(v_zero, IRType::I64);
                { IRInst z; z.op = IROp::CONST_ZERO; z.type = IRType::I64;
                  z.dest = v_zero; z.bc_offset = ip; ir.push_back(z); }
                int v_cmp1 = next_vreg++;
                set_vreg_type(v_cmp1, IRType::I64);
                { IRInst c; c.op = IROp::LT_I64; c.type = IRType::BOOL;
                  c.dest = v_cmp1; c.src1 = v_inner; c.src2 = v_zero; c.bc_offset = ip;
                  ir.push_back(c); }
                { IRInst j; j.op = IROp::JUMP_IF_TRUE; j.src1 = v_cmp1;
                  j.label_id = lbl_skip; j.bc_offset = ip; ir.push_back(j); }
                // Check outer_to >= 0
                int v_cmp2 = next_vreg++;
                set_vreg_type(v_cmp2, IRType::I64);                { IRInst c; c.op = IROp::LT_I64; c.type = IRType::BOOL;
                  c.dest = v_cmp2; c.src1 = v_outer; c.src2 = v_zero; c.bc_offset = ip;
                  ir.push_back(c); }
                { IRInst j; j.op = IROp::JUMP_IF_TRUE; j.src1 = v_cmp2;
                  j.label_id = lbl_skip; j.bc_offset = ip; ir.push_back(j); }
                
                // n_inner = inner_to + 1
                int v_n_inner = next_vreg++;
                set_vreg_type(v_n_inner, IRType::I64);
                { IRInst i; i.op = IROp::INC_I64; i.type = IRType::I64;
                  i.dest = v_n_inner; i.src1 = v_inner; i.bc_offset = ip;
                  ir.push_back(i); }
                // n_outer = outer_to + 1
                int v_n_outer = next_vreg++;
                set_vreg_type(v_n_outer, IRType::I64);
                { IRInst i; i.op = IROp::INC_I64; i.type = IRType::I64;
                  i.dest = v_n_outer; i.src1 = v_outer; i.bc_offset = ip;
                  ir.push_back(i); }
                
                // sum_j = inner_to * (inner_to + 1) / 2 = inner_to * n_inner / 2
                int v_prod_j = next_vreg++;
                set_vreg_type(v_prod_j, IRType::I64);
                { IRInst m; m.op = IROp::MUL_I64; m.type = IRType::I64;
                  m.dest = v_prod_j; m.src1 = v_inner; m.src2 = v_n_inner; m.bc_offset = ip;
                  ir.push_back(m); }
                int v_sum_j = next_vreg++;
                set_vreg_type(v_sum_j, IRType::I64);
                { IRInst s; s.op = IROp::SHR_I64_CONST; s.type = IRType::I64;
                  s.dest = v_sum_j; s.src1 = v_prod_j; s.imm_i64 = 1; s.bc_offset = ip;
                  ir.push_back(s); }
                
                // per_inner = k * sum_j + c * n_inner
                int v_k_sum = next_vreg++;
                set_vreg_type(v_k_sum, IRType::I64);
                { IRInst m; m.op = IROp::MUL_I64_CONST; m.type = IRType::I64;
                  m.dest = v_k_sum; m.src1 = v_sum_j; m.imm_i64 = k_val; m.bc_offset = ip;
                  ir.push_back(m); }
                int v_c_n = next_vreg++;
                set_vreg_type(v_c_n, IRType::I64);
                { IRInst m; m.op = IROp::MUL_I64_CONST; m.type = IRType::I64;
                  m.dest = v_c_n; m.src1 = v_n_inner; m.imm_i64 = c_val; m.bc_offset = ip;
                  ir.push_back(m); }
                int v_per_inner = next_vreg++;
                set_vreg_type(v_per_inner, IRType::I64);
                { IRInst a; a.op = IROp::ADD_I64; a.type = IRType::I64;
                  a.dest = v_per_inner; a.src1 = v_k_sum; a.src2 = v_c_n; a.bc_offset = ip;
                  ir.push_back(a); }
                
                // total_delta = per_inner * n_outer
                int v_delta = next_vreg++;
                set_vreg_type(v_delta, IRType::I64);                { IRInst m; m.op = IROp::MUL_I64; m.type = IRType::I64;
                  m.dest = v_delta; m.src1 = v_per_inner; m.src2 = v_n_outer; m.bc_offset = ip;
                  ir.push_back(m); }
                
                // result = current_sum + total_delta
                { IRInst a; a.op = IROp::ADD_I64; a.type = IRType::I64;
                  a.dest = v_result; a.src1 = v_current; a.src2 = v_delta; a.bc_offset = ip;
                  ir.push_back(a); }
                
                // Jump over skip label to done
                { IRInst j; j.op = IROp::JUMP; j.label_id = lbl_done; j.bc_offset = ip;
                  ir.push_back(j); }
                
                // skip: result stays as current_sum (already set by MOV above)
                { IRInst lbl; lbl.op = IROp::LABEL; lbl.label_id = lbl_skip; lbl.bc_offset = ip;
                  ir.push_back(lbl); }
                // done:
                { IRInst lbl; lbl.op = IROp::LABEL; lbl.label_id = lbl_done; lbl.bc_offset = ip;
                  ir.push_back(lbl); }
                
                vstack.push_back(v_result);
                ip += 5;
                break;
            }
            
            // Integer binary ops
            case OP_ADD_I64: case OP_SUB_I64: case OP_MUL_I64: {
                if (vstack.size() < 2) return false;
                int rhs = vstack.back(); vstack.pop_back();
                int lhs = vstack.back(); vstack.pop_back();
                IRInst inst;
                if (op == OP_ADD_I64) inst.op = IROp::ADD_I64;
                else if (op == OP_SUB_I64) inst.op = IROp::SUB_I64;
                else inst.op = IROp::MUL_I64;
                inst.type = IRType::I64;
                inst.dest = next_vreg++;
                set_vreg_type(inst.dest, IRType::I64);
                inst.src1 = lhs;
                inst.src2 = rhs;
                inst.bc_offset = ip;
                ir.push_back(inst);
                vstack.push_back(inst.dest);
                ip += 1;
                break;
            }
            
            // Integer ops with constant operand
            case OP_ADD_I64_CONST: case OP_SUB_I64_CONST: case OP_MUL_I64_CONST: {
                int const_idx = (code[ip + 2] << 8) | code[ip + 1];
                // These opcodes: [OP] [CONST_LO] [CONST_HI]
                // They apply constants[const_idx] to the operand
                // Let's load, compute, and store back
                if (const_idx >= chunk->constants.size()) return false;
                Variant cv = chunk->constants[const_idx];
                if (cv.get_type() != Variant::INT) return false;
                int64_t cval = (int64_t)cv;
                
                // Encoding: [OP][CONST_LO][CONST_HI] — load from slot, apply const, push result
                int loaded = next_vreg++;
                set_vreg_type(loaded, IRType::I64);
                {
                    IRInst ld;
                    ld.op = IROp::LOAD_LOCAL;
                    ld.type = IRType::I64;
                    ld.dest = loaded;
                    ld.local_slot = code[ip + 1];
                    ld.bc_offset = ip;
                    ir.push_back(ld);
                }
                IRInst arith;
                if (op == OP_ADD_I64_CONST) arith.op = IROp::ADD_I64_CONST;
                else if (op == OP_SUB_I64_CONST) arith.op = IROp::SUB_I64_CONST;
                else arith.op = IROp::MUL_I64_CONST;
                arith.type = IRType::I64;
                arith.dest = next_vreg++;
                set_vreg_type(arith.dest, IRType::I64);
                arith.src1 = loaded;
                arith.imm_i64 = cval;
                arith.bc_offset = ip;
                ir.push_back(arith);
                vstack.push_back(arith.dest);
                ip += 3;
                break;
            }
            
            // Float binary ops — insert I64→F64 conversions if needed
            case OP_ADD_F64: case OP_SUB_F64: case OP_MUL_F64: case OP_DIV_F64: {
                if (vstack.size() < 2) return false;
                int rhs = vstack.back(); vstack.pop_back();
                int lhs = vstack.back(); vstack.pop_back();
                // Convert I64 operands to F64 if needed
                if (get_vreg_type(lhs) != IRType::F64) {
                    int conv = next_vreg++;
                    set_vreg_type(conv, IRType::F64);
                    IRInst cv; cv.op = IROp::I64_TO_F64; cv.type = IRType::F64;
                    cv.dest = conv; cv.src1 = lhs; cv.bc_offset = ip;
                    ir.push_back(cv);
                    lhs = conv;
                }
                if (get_vreg_type(rhs) != IRType::F64) {
                    int conv = next_vreg++;
                    set_vreg_type(conv, IRType::F64);
                    IRInst cv; cv.op = IROp::I64_TO_F64; cv.type = IRType::F64;
                    cv.dest = conv; cv.src1 = rhs; cv.bc_offset = ip;
                    ir.push_back(cv);
                    rhs = conv;
                }
                IRInst inst;
                if (op == OP_ADD_F64) inst.op = IROp::ADD_F64;
                else if (op == OP_SUB_F64) inst.op = IROp::SUB_F64;
                else if (op == OP_MUL_F64) inst.op = IROp::MUL_F64;
                else inst.op = IROp::DIV_F64;
                inst.type = IRType::F64;
                inst.dest = next_vreg++;
                set_vreg_type(inst.dest, IRType::F64);
                inst.src1 = lhs;
                inst.src2 = rhs;
                inst.bc_offset = ip;
                ir.push_back(inst);
                vstack.push_back(inst.dest);
                ip += 1;
                break;
            }
            
            // Negate
            case OP_NEGATE: {
                if (vstack.empty()) return false;
                int src = vstack.back(); vstack.pop_back();
                IRInst inst;
                inst.op = IROp::NEG_I64;
                inst.type = IRType::I64;
                inst.dest = next_vreg++;
                set_vreg_type(inst.dest, IRType::I64);
                inst.src1 = src;
                inst.bc_offset = ip;
                ir.push_back(inst);
                vstack.push_back(inst.dest);
                ip += 1;
                break;
            }
            
            // Generic arithmetic — type-aware: use F64 ops when either operand is F64.
            // When one operand is I64 and the other F64, insert I64_TO_F64 conversion.
            case OP_ADD: case OP_SUBTRACT: case OP_MULTIPLY: {
                if (vstack.size() < 2) return false;
                int rhs = vstack.back(); vstack.pop_back();
                int lhs = vstack.back(); vstack.pop_back();
                IRType ltype = get_vreg_type(lhs);
                IRType rtype = get_vreg_type(rhs);
                bool use_f64 = (ltype == IRType::F64 || rtype == IRType::F64);
                
                if (use_f64) {
                    // Convert I64 operand to F64 if needed
                    if (ltype != IRType::F64) {
                        int conv = next_vreg++;
                        set_vreg_type(conv, IRType::F64);
                        IRInst cv; cv.op = IROp::I64_TO_F64; cv.type = IRType::F64;
                        cv.dest = conv; cv.src1 = lhs; cv.bc_offset = ip;
                        ir.push_back(cv);
                        lhs = conv;
                    }
                    if (rtype != IRType::F64) {
                        int conv = next_vreg++;
                        set_vreg_type(conv, IRType::F64);
                        IRInst cv; cv.op = IROp::I64_TO_F64; cv.type = IRType::F64;
                        cv.dest = conv; cv.src1 = rhs; cv.bc_offset = ip;
                        ir.push_back(cv);
                        rhs = conv;
                    }
                    IRInst inst;
                    if (op == OP_ADD) inst.op = IROp::ADD_F64;
                    else if (op == OP_SUBTRACT) inst.op = IROp::SUB_F64;
                    else inst.op = IROp::MUL_F64;
                    inst.type = IRType::F64;
                    inst.dest = next_vreg++;
                    set_vreg_type(inst.dest, IRType::F64);
                    inst.src1 = lhs;
                    inst.src2 = rhs;
                    inst.bc_offset = ip;
                    ir.push_back(inst);
                    vstack.push_back(inst.dest);
                } else {
                    IRInst inst;
                    if (op == OP_ADD) inst.op = IROp::ADD_I64;
                    else if (op == OP_SUBTRACT) inst.op = IROp::SUB_I64;
                    else inst.op = IROp::MUL_I64;
                    inst.type = IRType::I64;
                    inst.dest = next_vreg++;
                    set_vreg_type(inst.dest, IRType::I64);
                    inst.src1 = lhs;
                    inst.src2 = rhs;
                    inst.bc_offset = ip;
                    ir.push_back(inst);
                    vstack.push_back(inst.dest);
                }
                ip += 1;
                break;
            }
            
            // Generic comparisons — type-aware: use F64 comparison when either operand is F64
            case OP_EQUAL: case OP_NOT_EQUAL: case OP_GREATER: case OP_LESS:
            case OP_GREATER_EQUAL: case OP_LESS_EQUAL: {
                if (vstack.size() < 2) return false;
                int rhs = vstack.back(); vstack.pop_back();
                int lhs = vstack.back(); vstack.pop_back();
                IRType ltype = get_vreg_type(lhs);
                IRType rtype = get_vreg_type(rhs);
                bool use_f64 = (ltype == IRType::F64 || rtype == IRType::F64);
                
                if (use_f64) {
                    // Convert I64 operand to F64 if needed
                    if (ltype != IRType::F64) {
                        int conv = next_vreg++;
                        set_vreg_type(conv, IRType::F64);
                        IRInst cv; cv.op = IROp::I64_TO_F64; cv.type = IRType::F64;
                        cv.dest = conv; cv.src1 = lhs; cv.bc_offset = ip;
                        ir.push_back(cv);
                        lhs = conv;
                    }
                    if (rtype != IRType::F64) {
                        int conv = next_vreg++;
                        set_vreg_type(conv, IRType::F64);
                        IRInst cv; cv.op = IROp::I64_TO_F64; cv.type = IRType::F64;
                        cv.dest = conv; cv.src1 = rhs; cv.bc_offset = ip;
                        ir.push_back(cv);
                        rhs = conv;
                    }
                    IRInst inst;
                    if (op == OP_EQUAL) inst.op = IROp::EQ_F64;
                    else if (op == OP_NOT_EQUAL) inst.op = IROp::NE_F64;
                    else if (op == OP_GREATER) inst.op = IROp::GT_F64;
                    else if (op == OP_LESS) inst.op = IROp::LT_F64;
                    else if (op == OP_GREATER_EQUAL) inst.op = IROp::GE_F64;
                    else inst.op = IROp::LE_F64;
                    inst.type = IRType::BOOL;
                    inst.dest = next_vreg++;
                    set_vreg_type(inst.dest, IRType::I64); // comparison result is boolean/int
                    inst.src1 = lhs;
                    inst.src2 = rhs;
                    inst.bc_offset = ip;
                    ir.push_back(inst);
                    vstack.push_back(inst.dest);
                } else {
                    IRInst inst;
                    if (op == OP_EQUAL) inst.op = IROp::EQ_I64;
                    else if (op == OP_NOT_EQUAL) inst.op = IROp::NE_I64;
                    else if (op == OP_GREATER) inst.op = IROp::GT_I64;
                    else if (op == OP_LESS) inst.op = IROp::LT_I64;
                    else if (op == OP_GREATER_EQUAL) inst.op = IROp::GE_I64;
                    else inst.op = IROp::LE_I64;
                    inst.type = IRType::BOOL;
                    inst.dest = next_vreg++;
                    set_vreg_type(inst.dest, IRType::I64);
                    inst.src1 = lhs;
                    inst.src2 = rhs;
                    inst.bc_offset = ip;
                    ir.push_back(inst);
                    vstack.push_back(inst.dest);
                }
                ip += 1;
                break;
            }
            
            // Integer comparisons (typed)
            case OP_EQUAL_I64: case OP_NOT_EQUAL_I64: case OP_LESS_EQUAL_I64: {
                if (vstack.size() < 2) return false;
                int rhs = vstack.back(); vstack.pop_back();
                int lhs = vstack.back(); vstack.pop_back();
                IRInst inst;
                if (op == OP_EQUAL_I64) inst.op = IROp::EQ_I64;
                else if (op == OP_NOT_EQUAL_I64) inst.op = IROp::NE_I64;
                else inst.op = IROp::LE_I64;
                inst.type = IRType::BOOL;
                inst.dest = next_vreg++;
                set_vreg_type(inst.dest, IRType::I64);
                inst.src1 = lhs;
                inst.src2 = rhs;
                inst.bc_offset = ip;
                ir.push_back(inst);
                vstack.push_back(inst.dest);
                ip += 1;
                break;
            }
            
            // Jump
            case OP_JUMP: {
                int offset = read_u16(code, ip + 1);
                int target = ip + 3 + offset;
                auto it = ip_to_label.find(target);
                if (it == ip_to_label.end()) return false;
                IRInst inst;
                inst.op = IROp::JUMP;
                inst.label_id = it->second;
                inst.bc_offset = ip;
                ir.push_back(inst);
                ip += 3;
                break;
            }
            
            case OP_JUMP_IF_FALSE: {
                int offset = read_u16(code, ip + 1);
                int target = ip + 3 + offset;
                auto it = ip_to_label.find(target);
                if (it == ip_to_label.end()) return false;
                if (vstack.empty()) return false;
                int cond = vstack.back(); vstack.pop_back();
                IRInst inst;
                inst.op = IROp::JUMP_IF_FALSE;
                inst.src1 = cond;
                inst.label_id = it->second;
                inst.bc_offset = ip;
                ir.push_back(inst);
                ip += 3;
                break;
            }
            
            case OP_JUMP_IF_TRUE: {
                int offset = read_u16(code, ip + 1);
                int target = ip + 3 + offset;
                auto it = ip_to_label.find(target);
                if (it == ip_to_label.end()) return false;
                if (vstack.empty()) return false;
                int cond = vstack.back(); vstack.pop_back();
                IRInst inst;
                inst.op = IROp::JUMP_IF_TRUE;
                inst.src1 = cond;
                inst.label_id = it->second;
                inst.bc_offset = ip;
                ir.push_back(inst);
                ip += 3;
                break;
            }
            
            case OP_LOOP: {
                int offset = read_u16(code, ip + 1);
                int target = ip + 3 - offset;
                auto it = ip_to_label.find(target);
                if (it == ip_to_label.end()) return false;
                IRInst inst;
                inst.op = IROp::JUMP;
                inst.label_id = it->second;
                inst.bc_offset = ip;
                ir.push_back(inst);
                ip += 3;
                break;
            }
            
            case OP_POP: {
                if (!vstack.empty()) vstack.pop_back();
                IRInst inst;
                inst.op = IROp::NOP;
                inst.bc_offset = ip;
                ir.push_back(inst);
                ip += 1;
                break;
            }
            
            case OP_DUP: {
                if (vstack.empty()) return false;
                int top = vstack.back();
                int dup = next_vreg++;
                set_vreg_type(dup, get_vreg_type(top)); // inherit type from source
                IRInst inst;
                inst.op = IROp::MOV;
                inst.type = IRType::I64;
                inst.dest = dup;
                inst.src1 = top;
                inst.bc_offset = ip;
                ir.push_back(inst);
                vstack.push_back(dup);
                ip += 1;
                break;
            }
            
            case OP_RETURN: {
                IRInst inst;
                inst.op = IROp::RET;
                inst.bc_offset = ip;
                ir.push_back(inst);
                ip += 1;
                break;
            }
            
            case OP_RETURN_VALUE: {
                if (vstack.empty()) return false;
                int val = vstack.back(); vstack.pop_back();
                IRInst inst;
                inst.op = IROp::RET_VALUE;
                inst.src1 = val;
                inst.bc_offset = ip;
                ir.push_back(inst);
                ip += 1;
                break;
            }
            
            case OP_DEBUG_LINE: {
                // Skip debug lines in JIT
                ip += 3;
                break;
            }
            
            // ── Bitwise AND / OR / XOR (integer only) ──
            // VG's OP_AND/OP_OR/OP_XOR are bitwise when both operands are numeric
            // and logical otherwise. We only compile the pure-integer case; any
            // non-I64 operand bails so the interpreter can apply the float-coerce
            // or logical-truthiness semantics correctly.
            case OP_AND: case OP_OR: case OP_XOR: {
                if (vstack.size() < 2) return false;
                int rhs = vstack.back(); vstack.pop_back();
                int lhs = vstack.back(); vstack.pop_back();
                if (get_vreg_type(lhs) != IRType::I64 || get_vreg_type(rhs) != IRType::I64) return false;
                IRInst inst;
                inst.type = IRType::I64;
                inst.dest = next_vreg++;
                set_vreg_type(inst.dest, IRType::I64);
                inst.src1 = lhs;
                inst.src2 = rhs;
                inst.bc_offset = ip;
                inst.op = (op == OP_AND) ? IROp::AND_I64
                        : (op == OP_OR)  ? IROp::OR_I64
                                         : IROp::XOR_I64;
                ir.push_back(inst);
                vstack.push_back(inst.dest);
                ip += 1;
                break;
            }
            
            // ── Shift left / arithmetic shift right by a constant count ──
            // Only constant shift counts in [0,63] with an integer operand are
            // compiled inline (SHL/SAR r64, imm8). Variable counts (which need the
            // count in CL) bail to the interpreter and remain a later increment.
            case OP_SHL: case OP_SHR: {
                if (vstack.size() < 2) return false;
                int rhs = vstack.back(); vstack.pop_back();
                int lhs = vstack.back(); vstack.pop_back();
                if (get_vreg_type(lhs) != IRType::I64 || get_vreg_type(rhs) != IRType::I64) return false;
                auto cit = vreg_const_i64.find(rhs);
                if (cit == vreg_const_i64.end()) return false;
                int64_t cnt = cit->second;
                if (cnt < 0 || cnt > 63) return false;
                IRInst inst;
                inst.type = IRType::I64;
                inst.dest = next_vreg++;
                set_vreg_type(inst.dest, IRType::I64);
                inst.src1 = lhs;
                inst.imm_i64 = cnt;
                inst.bc_offset = ip;
                inst.op = (op == OP_SHL) ? IROp::SHL_I64_CONST : IROp::SHR_I64_CONST;
                ir.push_back(inst);
                vstack.push_back(inst.dest);
                ip += 1;
                break;
            }
            
            default:
                // Unsupported opcode — cannot JIT this function
                return false;
        }
    }
    
    vreg_count = next_vreg;
    total_slots = next_global_slot; // local_count + virtual global count
    return true;
}

// ═══════════════════════════════════════════════════════════════════
//  Linear Scan Register Allocation
// ═══════════════════════════════════════════════════════════════════

Reg RegAlloc::reg_for(int vreg) const {
    for (const auto& r : ranges) {
        if (r.vreg == vreg) return r.assigned;
    }
    return Reg::NONE;
}

int RegAlloc::spill_for(int vreg) const {
    for (const auto& r : ranges) {
        if (r.vreg == vreg) return r.spill_offset;
    }
    return -1;
}

bool Tier2::alloc_regs(const std::vector<IRInst>& ir, int vreg_count, RegAlloc& out) {
    if (vreg_count == 0) return true;
    
    // Compute live ranges
    std::vector<LiveRange> ranges(vreg_count);
    for (int i = 0; i < vreg_count; i++) {
        ranges[i].vreg = i;
        ranges[i].first_use = INT32_MAX;
        ranges[i].last_use = -1;
        ranges[i].type = IRType::I64;
    }
    
    for (int i = 0; i < (int)ir.size(); i++) {
        const IRInst& inst = ir[i];
        auto touch = [&](int vreg) {
            if (vreg < 0 || vreg >= vreg_count) return;
            if (i < ranges[vreg].first_use) ranges[vreg].first_use = i;
            if (i > ranges[vreg].last_use) ranges[vreg].last_use = i;
        };
        if (inst.dest >= 0) {
            touch(inst.dest);
            if (inst.type == IRType::F64) ranges[inst.dest].type = IRType::F64;
        }
        touch(inst.src1);
        touch(inst.src2);
    }
    
    // Remove unused vregs
    std::vector<LiveRange> active_ranges;
    for (auto& r : ranges) {
        if (r.last_use >= 0) active_ranges.push_back(r);
    }
    
    // Sort by start position
    std::sort(active_ranges.begin(), active_ranges.end(),
              [](const LiveRange& a, const LiveRange& b) { return a.first_use < b.first_use; });
    
    // Allocatable GP registers (avoid rax=scratch, rsp, rbp, rdi=locals ptr, rsi=local_count)
    std::vector<Reg> gp_pool = { Reg::RCX, Reg::RDX, Reg::RBX, Reg::R8, Reg::R9,
                                  Reg::R10, Reg::R11, Reg::R12, Reg::R13, Reg::R14, Reg::R15 };
    std::vector<Reg> fp_pool = { Reg::XMM0, Reg::XMM1, Reg::XMM2, Reg::XMM3,
                                  Reg::XMM4, Reg::XMM5, Reg::XMM6, Reg::XMM7 };
    
    std::vector<bool> gp_used(gp_pool.size(), false);
    std::vector<bool> fp_used(fp_pool.size(), false);
    
    // Active intervals (currently live)
    std::vector<int> active_indices;  // indices into active_ranges
    
    int next_spill = 8; // Start spill at rbp-8 (below saved regs)
    
    for (int i = 0; i < (int)active_ranges.size(); i++) {
        LiveRange& cur = active_ranges[i];
        
        // Expire old intervals
        for (auto it = active_indices.begin(); it != active_indices.end(); ) {
            LiveRange& old = active_ranges[*it];
            if (old.last_use < cur.first_use) {
                // Free the register
                if (old.type == IRType::F64) {
                    for (int j = 0; j < (int)fp_pool.size(); j++) {
                        if (fp_pool[j] == old.assigned) { fp_used[j] = false; break; }
                    }
                } else {
                    for (int j = 0; j < (int)gp_pool.size(); j++) {
                        if (gp_pool[j] == old.assigned) { gp_used[j] = false; break; }
                    }
                }
                it = active_indices.erase(it);
            } else {
                ++it;
            }
        }
        
        // Try to allocate a register
        bool allocated = false;
        if (cur.type == IRType::F64) {
            for (int j = 0; j < (int)fp_pool.size(); j++) {
                if (!fp_used[j]) {
                    cur.assigned = fp_pool[j];
                    fp_used[j] = true;
                    allocated = true;
                    break;
                }
            }
        } else {
            for (int j = 0; j < (int)gp_pool.size(); j++) {
                if (!gp_used[j]) {
                    cur.assigned = gp_pool[j];
                    gp_used[j] = true;
                    allocated = true;
                    break;
                }
            }
        }
        
        if (!allocated) {
            // Spill: assign a stack slot
            cur.assigned = Reg::SPILL;
            cur.spill_offset = next_spill;
            next_spill += 8;
        }
        
        active_indices.push_back(i);
    }
    
    out.ranges = active_ranges;
    out.spill_bytes = next_spill;
    return true;
}

// ═══════════════════════════════════════════════════════════════════
//  Native Code Generation
// ═══════════════════════════════════════════════════════════════════

// Helper to emit a value into a target register (handles spills)
static void emit_to_reg(CodeBuf& cb, const RegAlloc& alloc, int vreg, Reg target) {
    Reg r = alloc.reg_for(vreg);
    if (r == Reg::NONE) return;
    if (r == Reg::SPILL) {
        cb.load_spill(target, alloc.spill_for(vreg));
    } else if (r != target) {
        cb.mov_rr(target, r);
    }
}

static Reg get_or_load(CodeBuf& cb, const RegAlloc& alloc, int vreg, Reg scratch) {
    Reg r = alloc.reg_for(vreg);
    if (r == Reg::SPILL) {
        cb.load_spill(scratch, alloc.spill_for(vreg));
        return scratch;
    }
    return r;
}

static void store_result(CodeBuf& cb, const RegAlloc& alloc, int vreg, Reg src) {
    Reg r = alloc.reg_for(vreg);
    if (r == Reg::NONE) return;
    if (r == Reg::SPILL) {
        cb.store_spill(alloc.spill_for(vreg), src);
    } else if (r != src) {
        cb.mov_rr(r, src);
    }
}

CompiledFunc* Tier2::emit_native(const std::vector<IRInst>& ir, const RegAlloc& alloc,
                                  BytecodeChunk* chunk, const std::string& name) {
#ifndef __linux__
    return nullptr;
#else
    CodeBuf cb;
    cb.reset();
    
    // Create labels
    int max_label = 0;
    for (const auto& inst : ir) {
        if (inst.label_id >= max_label) max_label = inst.label_id + 1;
    }
    for (int i = 0; i < max_label; i++) cb.new_label();
    
    cb.prologue(alloc.spill_bytes);
    // rdi = locals pointer (first parameter, System V ABI)
    // rsi = local_count (second parameter)
    
    for (const auto& inst : ir) {
        switch (inst.op) {
            case IROp::LABEL:
                cb.bind_label(inst.label_id);
                break;
                
            case IROp::NOP:
                break;
                
            case IROp::CONST_I64: {
                Reg dst = alloc.reg_for(inst.dest);
                if (dst == Reg::SPILL) {
                    cb.mov_ri64(Reg::RAX, inst.imm_i64);
                    cb.store_spill(alloc.spill_for(inst.dest), Reg::RAX);
                } else if (dst != Reg::NONE) {
                    cb.mov_ri64(dst, inst.imm_i64);
                }
                break;
            }
            
            case IROp::CONST_F64: {
                // Load f64 immediate: mov rax, imm64; movq xmm, rax
                Reg dst = alloc.reg_for(inst.dest);
                uint64_t bits;
                memcpy(&bits, &inst.imm_f64, 8);
                cb.mov_ri64(Reg::RAX, (int64_t)bits);
                if (dst >= Reg::XMM0 && dst <= Reg::XMM7) {
                    // movq xmm, rax: 66 48 0F 6E /r
                    uint8_t xr = (uint8_t)dst - (uint8_t)Reg::XMM0;
                    cb.emit(0x66);
                    cb.rex(true, false, false, false);
                    cb.emit(0x0F); cb.emit(0x6E);
                    cb.modrm(3, xr & 7, 0); // rax
                } else {
                    // Spill or GP: just store the bits
                    if (dst == Reg::SPILL) {
                        cb.store_spill(alloc.spill_for(inst.dest), Reg::RAX);
                    }
                }
                break;
            }
            
            case IROp::CONST_BOOL:
            case IROp::CONST_ZERO: {
                Reg dst = alloc.reg_for(inst.dest);
                if (dst == Reg::SPILL) {
                    cb.mov_ri32(Reg::RAX, (int32_t)inst.imm_i64);
                    cb.store_spill(alloc.spill_for(inst.dest), Reg::RAX);
                } else if (dst != Reg::NONE) {
                    cb.mov_ri32(dst, (int32_t)inst.imm_i64);
                }
                break;
            }
            
            case IROp::LOAD_LOCAL: {
                Reg dst = alloc.reg_for(inst.dest);
                if (dst >= Reg::XMM0 && dst <= Reg::XMM7) {
                    // F64 local → load into XMM register
                    cb.load_local_f64(dst, inst.local_slot);
                } else if (dst == Reg::SPILL) {
                    // Check if this is an F64 type that got spilled
                    if (inst.type == IRType::F64) {
                        cb.load_local_i64(Reg::RAX, inst.local_slot);
                        cb.store_spill(alloc.spill_for(inst.dest), Reg::RAX);
                    } else {
                        cb.load_local_i64(Reg::RAX, inst.local_slot);
                        cb.store_spill(alloc.spill_for(inst.dest), Reg::RAX);
                    }
                } else if (dst != Reg::NONE) {
                    cb.load_local_i64(dst, inst.local_slot);
                }
                break;
            }
            
            case IROp::STORE_LOCAL: {
                Reg src = alloc.reg_for(inst.src1);
                if (src >= Reg::XMM0 && src <= Reg::XMM7) {
                    // F64 value in XMM → store directly
                    cb.store_local_f64(inst.local_slot, src);
                } else {
                    Reg r = get_or_load(cb, alloc, inst.src1, Reg::RAX);
                    cb.store_local_i64(inst.local_slot, r);
                }
                break;
            }
            
            case IROp::ADD_I64: case IROp::SUB_I64: case IROp::MUL_I64: {
                Reg dst = alloc.reg_for(inst.dest);
                Reg work = (dst != Reg::SPILL && dst != Reg::NONE) ? dst : Reg::RAX;
                Reg lhs = get_or_load(cb, alloc, inst.src1, work);
                // Use RCX as scratch for RHS, but avoid clobbering lhs
                Reg rhs_scratch = (lhs == Reg::RCX) ? Reg::RDX : Reg::RCX;
                Reg rhs = get_or_load(cb, alloc, inst.src2, rhs_scratch);
                if (lhs != work) cb.mov_rr(work, lhs);
                if (inst.op == IROp::ADD_I64) cb.add_rr(work, rhs);
                else if (inst.op == IROp::SUB_I64) cb.sub_rr(work, rhs);
                else cb.imul_rr(work, rhs);
                store_result(cb, alloc, inst.dest, work);
                break;
            }
            
            case IROp::ADD_I64_CONST: case IROp::SUB_I64_CONST: case IROp::MUL_I64_CONST: {
                Reg dst = alloc.reg_for(inst.dest);
                Reg work = (dst != Reg::SPILL && dst != Reg::NONE) ? dst : Reg::RAX;
                Reg src = get_or_load(cb, alloc, inst.src1, work);
                if (src != work) cb.mov_rr(work, src);
                // Load immediate into a scratch that won't collide with work
                Reg imm_reg = (work == Reg::RCX) ? Reg::RDX : Reg::RCX;
                cb.mov_ri64(imm_reg, inst.imm_i64);
                if (inst.op == IROp::ADD_I64_CONST) cb.add_rr(work, imm_reg);
                else if (inst.op == IROp::SUB_I64_CONST) cb.sub_rr(work, imm_reg);
                else cb.imul_rr(work, imm_reg);
                store_result(cb, alloc, inst.dest, work);
                break;
            }
            
            case IROp::NEG_I64: {
                Reg dst = alloc.reg_for(inst.dest);
                Reg work = (dst != Reg::SPILL && dst != Reg::NONE) ? dst : Reg::RAX;
                Reg src = get_or_load(cb, alloc, inst.src1, work);
                if (src != work) cb.mov_rr(work, src);
                cb.neg_r(work);
                store_result(cb, alloc, inst.dest, work);
                break;
            }
            
            case IROp::INC_I64: {
                Reg dst = alloc.reg_for(inst.dest);
                Reg work = (dst != Reg::SPILL && dst != Reg::NONE) ? dst : Reg::RAX;
                Reg src = get_or_load(cb, alloc, inst.src1, work);
                if (src != work) cb.mov_rr(work, src);
                cb.inc_r(work);
                store_result(cb, alloc, inst.dest, work);
                break;
            }
            
            case IROp::SHR_I64_CONST: {
                // Arithmetic shift right by imm_i64 (SAR reg, imm8)
                Reg dst = alloc.reg_for(inst.dest);
                Reg work = (dst != Reg::SPILL && dst != Reg::NONE) ? dst : Reg::RAX;
                Reg src = get_or_load(cb, alloc, inst.src1, work);
                if (src != work) cb.mov_rr(work, src);
                // REX.W + C1 /7 ib  → SAR r64, imm8
                cb.rex(true, false, false, ((int)work >= 8));
                cb.emit(0xC1);
                cb.modrm(3, 7, (int)work & 7);
                cb.emit((uint8_t)(inst.imm_i64 & 0x3F));
                store_result(cb, alloc, inst.dest, work);
                break;
            }
            
            case IROp::SHL_I64_CONST: {
                // Logical shift left by imm_i64 (SHL reg, imm8)
                Reg dst = alloc.reg_for(inst.dest);
                Reg work = (dst != Reg::SPILL && dst != Reg::NONE) ? dst : Reg::RAX;
                Reg src = get_or_load(cb, alloc, inst.src1, work);
                if (src != work) cb.mov_rr(work, src);
                // REX.W + C1 /4 ib  → SHL r64, imm8
                cb.rex(true, false, false, ((int)work >= 8));
                cb.emit(0xC1);
                cb.modrm(3, 4, (int)work & 7);
                cb.emit((uint8_t)(inst.imm_i64 & 0x3F));
                store_result(cb, alloc, inst.dest, work);
                break;
            }
            
            case IROp::AND_I64: case IROp::OR_I64: case IROp::XOR_I64: {
                Reg dst = alloc.reg_for(inst.dest);
                Reg work = (dst != Reg::SPILL && dst != Reg::NONE) ? dst : Reg::RAX;
                Reg lhs = get_or_load(cb, alloc, inst.src1, work);
                // Use RCX as scratch for RHS, but avoid clobbering lhs
                Reg rhs_scratch = (lhs == Reg::RCX) ? Reg::RDX : Reg::RCX;
                Reg rhs = get_or_load(cb, alloc, inst.src2, rhs_scratch);
                if (lhs != work) cb.mov_rr(work, lhs);
                if (inst.op == IROp::AND_I64) cb.and_rr(work, rhs);
                else if (inst.op == IROp::OR_I64) cb.or_rr(work, rhs);
                else cb.xor_rr(work, rhs);
                store_result(cb, alloc, inst.dest, work);
                break;
            }
            
            case IROp::ADD_F64: case IROp::SUB_F64: case IROp::MUL_F64: case IROp::DIV_F64: {
                // Use allocated XMM registers directly to avoid clobber.
                // Strategy: get lhs into xmm_a, rhs into xmm_b, then
                // op xmm_a, xmm_b (destructive: xmm_a = xmm_a op xmm_b).
                // Finally move result to dest.
                
                Reg lhs = alloc.reg_for(inst.src1);
                Reg rhs = alloc.reg_for(inst.src2);
                Reg dst = alloc.reg_for(inst.dest);
                
                // Helper lambda: load a vreg into an XMM register.
                // If already in an XMM, return it. Otherwise load via GP→movq.
                auto load_xmm = [&](int vreg, Reg allocated, Reg gp_scratch, Reg xmm_scratch) -> Reg {
                    if (allocated >= Reg::XMM0 && allocated <= Reg::XMM7) return allocated;
                    // Spilled or in GP — load into xmm_scratch via movq
                    Reg gp = get_or_load(cb, alloc, vreg, gp_scratch);
                    if (gp != gp_scratch) cb.mov_rr(gp_scratch, gp);
                    // movq xmm_scratch, gp_scratch
                    uint8_t xlo = lo3(xmm_scratch);
                    bool xext = needs_ext(xmm_scratch);
                    bool gpext = ((int)gp_scratch >= 8);
                    cb.emit(0x66); cb.rex(true, xext, false, gpext);
                    cb.emit(0x0F); cb.emit(0x6E);
                    cb.modrm(3, xlo, (int)gp_scratch & 7);
                    return xmm_scratch;
                };
                
                // Pick scratch XMM registers that don't conflict with allocated regs
                Reg xmm_a = load_xmm(inst.src1, lhs, Reg::RAX, Reg::XMM0);
                // For rhs scratch, pick XMM1 unless xmm_a already is XMM1
                Reg rhs_xmm_scratch = (xmm_a == Reg::XMM1) ? Reg::XMM2 : Reg::XMM1;
                Reg xmm_b = load_xmm(inst.src2, rhs, Reg::RCX, rhs_xmm_scratch);
                
                // The SSE op is destructive: xmm_a = xmm_a op xmm_b.
                // If xmm_a is the same as a live src register we don't want to
                // destroy, we need to copy first. But since xmm_a IS src1's reg
                // and the register allocator treats it as consumed, it's fine.
                // However, if dst is a different XMM from xmm_a, copy lhs there first.
                Reg work = xmm_a;
                if (dst >= Reg::XMM0 && dst <= Reg::XMM7 && dst != xmm_a && dst != xmm_b) {
                    cb.movsd_rr(dst, xmm_a);
                    work = dst;
                }
                
                if (inst.op == IROp::ADD_F64) cb.addsd(work, xmm_b);
                else if (inst.op == IROp::SUB_F64) cb.subsd(work, xmm_b);
                else if (inst.op == IROp::MUL_F64) cb.mulsd(work, xmm_b);
                else cb.divsd(work, xmm_b);
                
                // Store result
                if (dst >= Reg::XMM0 && dst <= Reg::XMM7) {
                    if (dst != work) cb.movsd_rr(dst, work);
                } else if (dst == Reg::SPILL) {
                    // movq rax, work_xmm then store
                    uint8_t wlo = lo3(work);
                    bool wext = needs_ext(work);
                    cb.emit(0x66); cb.rex(true, false, false, wext);
                    cb.emit(0x0F); cb.emit(0x7E);
                    cb.modrm(3, wlo, 0); // movq rax, work
                    cb.store_spill(alloc.spill_for(inst.dest), Reg::RAX);
                }
                break;
            }
            
            // ── I64 → F64 conversion (cvtsi2sd) ──
            case IROp::I64_TO_F64: {
                // Load integer into a GP register
                Reg src = get_or_load(cb, alloc, inst.src1, Reg::RAX);
                if (src != Reg::RAX) cb.mov_rr(Reg::RAX, src);
                
                // Determine target XMM register
                Reg dst = alloc.reg_for(inst.dest);
                Reg xmm_target = Reg::XMM0;
                if (dst >= Reg::XMM0 && dst <= Reg::XMM7) {
                    xmm_target = dst;
                }
                
                // cvtsi2sd xmm_target, rax — F2 REX.W 0F 2A /r
                uint8_t xmm_lo = lo3(xmm_target);
                bool xmm_ext = needs_ext(xmm_target);
                cb.emit(0xF2);
                cb.rex(true, xmm_ext, false, false);
                cb.emit(0x0F); cb.emit(0x2A);
                cb.modrm(3, xmm_lo, 0); // modrm(3, xmm_reg, rax=0)
                
                if (dst == Reg::SPILL) {
                    // movq rax, xmm_target → store spill
                    cb.emit(0x66);
                    cb.rex(true, false, false, xmm_ext);
                    cb.emit(0x0F); cb.emit(0x7E);
                    cb.modrm(3, xmm_lo, 0); // movq rax, xmm_target
                    cb.store_spill(alloc.spill_for(inst.dest), Reg::RAX);
                }
                break;
            }
            
            case IROp::F64_TO_I64: {
                // Get F64 source into an XMM register (prefer the one it's already in)
                Reg src = alloc.reg_for(inst.src1);
                Reg xmm_src = Reg::XMM0;
                if (src >= Reg::XMM0 && src <= Reg::XMM7) {
                    xmm_src = src; // use directly, no move needed
                } else {
                    Reg gp = get_or_load(cb, alloc, inst.src1, Reg::RAX);
                    if (gp != Reg::RAX) cb.mov_rr(Reg::RAX, gp);
                    // movq xmm0, rax
                    cb.emit(0x66); cb.rex(true, false, false, false);
                    cb.emit(0x0F); cb.emit(0x6E); cb.modrm(3, 0, 0);
                }
                // cvttsd2si rax, xmm_src — F2 REX.W 0F 2C /r
                uint8_t xmm_lo = lo3(xmm_src);
                bool xmm_ext = needs_ext(xmm_src);
                cb.emit(0xF2); cb.rex(true, false, false, xmm_ext);
                cb.emit(0x0F); cb.emit(0x2C);
                cb.modrm(3, 0, xmm_lo); // cvttsd2si rax, xmm_src
                // Result is now in rax — store to dest
                Reg dst = alloc.reg_for(inst.dest);
                if (dst != Reg::RAX && dst != Reg::SPILL) {
                    cb.mov_rr(dst, Reg::RAX);
                }
                if (dst == Reg::SPILL) {
                    cb.store_spill(alloc.spill_for(inst.dest), Reg::RAX);
                }
                break;
            }
            
            // ── Float comparisons (ucomisd + unsigned setCC) ──
            case IROp::EQ_F64: case IROp::NE_F64: case IROp::LE_F64:
            case IROp::LT_F64: case IROp::GE_F64: case IROp::GT_F64: {
                // Use allocated XMM registers directly to avoid clobber.
                Reg lhs_r = alloc.reg_for(inst.src1);
                Reg rhs_r = alloc.reg_for(inst.src2);
                
                // Helper: get vreg into an XMM register
                auto load_xmm_cmp = [&](int vreg, Reg allocated, Reg gp_scratch, Reg xmm_scratch) -> Reg {
                    if (allocated >= Reg::XMM0 && allocated <= Reg::XMM7) return allocated;
                    Reg gp = get_or_load(cb, alloc, vreg, gp_scratch);
                    if (gp != gp_scratch) cb.mov_rr(gp_scratch, gp);
                    uint8_t xlo = lo3(xmm_scratch);
                    bool xext = needs_ext(xmm_scratch);
                    bool gpext = ((int)gp_scratch >= 8);
                    cb.emit(0x66); cb.rex(true, xext, false, gpext);
                    cb.emit(0x0F); cb.emit(0x6E);
                    cb.modrm(3, xlo, (int)gp_scratch & 7);
                    return xmm_scratch;
                };
                
                Reg xmm_l = load_xmm_cmp(inst.src1, lhs_r, Reg::RAX, Reg::XMM0);
                Reg rhs_xmm_scratch = (xmm_l == Reg::XMM1) ? Reg::XMM2 : Reg::XMM1;
                Reg xmm_r = load_xmm_cmp(inst.src2, rhs_r, Reg::RCX, rhs_xmm_scratch);
                
                cb.ucomisd(xmm_l, xmm_r);
                
                Reg dst = alloc.reg_for(inst.dest);
                Reg target = (dst != Reg::SPILL && dst != Reg::NONE) ? dst : Reg::RAX;
                
                // ucomisd sets CF, ZF for unsigned comparison:
                //   a > b  → CF=0, ZF=0  → seta
                //   a >= b → CF=0        → setae
                //   a < b  → CF=1        → setb
                //   a <= b → CF=1|ZF=1   → setbe
                //   a == b → ZF=1, PF=0  → sete (+ check PF for unordered, skip for now)
                //   a != b → ZF=0        → setne
                switch (inst.op) {
                    case IROp::EQ_F64: cb.sete(target); break;
                    case IROp::NE_F64: cb.setne(target); break;
                    case IROp::LE_F64: cb.setbe(target); break;
                    case IROp::LT_F64: cb.setb(target); break;
                    case IROp::GE_F64: cb.setae(target); break;
                    case IROp::GT_F64: cb.seta(target); break;
                    default: break;
                }
                
                if (dst == Reg::SPILL) {
                    cb.store_spill(alloc.spill_for(inst.dest), target);
                }
                break;
            }
            
            case IROp::EQ_I64: case IROp::NE_I64: case IROp::LE_I64:
            case IROp::LT_I64: case IROp::GE_I64: case IROp::GT_I64: {
                Reg lhs = get_or_load(cb, alloc, inst.src1, Reg::RAX);
                // Avoid RCX scratch colliding with lhs
                Reg rhs_scratch = (lhs == Reg::RCX) ? Reg::RDX : Reg::RCX;
                Reg rhs = get_or_load(cb, alloc, inst.src2, rhs_scratch);
                cb.cmp_rr(lhs, rhs);
                
                Reg dst = alloc.reg_for(inst.dest);
                Reg target = (dst != Reg::SPILL && dst != Reg::NONE) ? dst : Reg::RAX;
                
                // setCC + movzx already zero-extends to 64 bits — no pre-clear needed
                switch (inst.op) {
                    case IROp::EQ_I64: cb.sete(target); break;
                    case IROp::NE_I64: cb.setne(target); break;
                    case IROp::LE_I64: cb.setle(target); break;
                    case IROp::LT_I64: cb.setl(target); break;
                    case IROp::GE_I64: cb.setge(target); break;
                    case IROp::GT_I64: cb.setg(target); break;
                    default: break;
                }
                
                if (dst == Reg::SPILL) {
                    cb.store_spill(alloc.spill_for(inst.dest), target);
                }
                break;
            }
            
            case IROp::JUMP:
                cb.jmp_label(inst.label_id);
                break;
                
            case IROp::JUMP_IF_FALSE: {
                Reg cond = get_or_load(cb, alloc, inst.src1, Reg::RAX);
                cb.test_rr(cond, cond);
                cb.je_label(inst.label_id);
                break;
            }
            
            case IROp::JUMP_IF_TRUE: {
                Reg cond = get_or_load(cb, alloc, inst.src1, Reg::RAX);
                cb.test_rr(cond, cond);
                cb.jne_label(inst.label_id);
                break;
            }
            
            case IROp::MOV: {
                Reg src = get_or_load(cb, alloc, inst.src1, Reg::RAX);
                store_result(cb, alloc, inst.dest, src);
                break;
            }
            
            case IROp::RET: {
                cb.mov_ri32(Reg::RAX, 0); // return 0 (no value)
                cb.epilogue();
                break;
            }
            
            case IROp::RET_VALUE: {
                Reg val = get_or_load(cb, alloc, inst.src1, Reg::RCX);
                // Store return value in locals[0]
                cb.store_local_i64(0, val);
                cb.mov_ri32(Reg::RAX, 1); // return 1 (has value)
                cb.epilogue();
                break;
            }
            
            default:
                break;
        }
    }
    
    // Final return (in case no explicit return in IR)
    cb.mov_ri32(Reg::RAX, 0);
    cb.epilogue();
    
    if (!cb.resolve()) {
        return nullptr; // Label resolution failed
    }
    
    // Allocate executable memory
    size_t page_size = 4096;
    size_t alloc_size = ((cb.code_size() + page_size - 1) / page_size) * page_size;
    if (alloc_size == 0) alloc_size = page_size;
    
    void* mem = mmap(nullptr, alloc_size, PROT_READ | PROT_WRITE,
                     MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (mem == MAP_FAILED) return nullptr;
    
    memcpy(mem, cb.code().data(), cb.code_size());
    
    if (mprotect(mem, alloc_size, PROT_READ | PROT_EXEC) != 0) {
        munmap(mem, alloc_size);
        return nullptr;
    }
    
    CompiledFunc* func = new CompiledFunc();
    func->code_mem = mem;
    func->code_size = alloc_size;
    func->fn = (CompiledFunc::FnPtr)mem;
    func->name = name;
    
    return func;
#endif
}

// ═══════════════════════════════════════════════════════════════════
//  Tier2 Engine
// ═══════════════════════════════════════════════════════════════════

Tier2::Tier2() {
    const char* env = std::getenv("VG_JIT");
    if (env && env[0] != '\0' && env[0] != '0') {
        enabled_ = true;
        tier_level_ = std::atoi(env);
        if (tier_level_ < 1) tier_level_ = 1;
    }
}

Tier2::~Tier2() {
    for (auto& kv : cache_) {
        delete kv.second;
    }
}

Tier2::HotInfo& Tier2::get_hotness(const std::string& name) {
    // Linear search (small N)
    return hot_[name];
}

CompiledFunc* Tier2::get_or_compile(const std::string& name, BytecodeChunk* chunk) {
    if (!enabled_ || tier_level_ < 2) return nullptr;
    
    // Check cache
    auto cache_it = cache_.find(name);
    if (cache_it != cache_.end()) {
        cache_it->second->exec_count++;
        return cache_it->second;
    }
    
    // Update hotness
    HotInfo& hot = get_hotness(name);
    hot.calls++;
    
    if (hot.tried) return nullptr;
    if (hot.calls < HOT_THRESHOLD) return nullptr;
    if (!chunk || chunk->code.size() == 0) return nullptr;
    if (chunk->code.size() > MAX_BC_SIZE) { hot.tried = true; hot.failed = true; return nullptr; }
    if (cache_.size() >= MAX_CACHE) return nullptr;
    
    hot.tried = true;
    
    // Pipeline: bytecode → IR → regalloc → native
    std::vector<IRInst> ir;
    int vreg_count = 0;
    std::vector<std::pair<std::string, int>> global_slots;
    int total_slots = 0;
    
    UtilityFunctions::print("[VG_JIT T2] Attempting compile: '", String(name.c_str()), "' (", (int)chunk->code.size(), " bytes BC, ", chunk->local_count, " locals)");
    
    if (!lower_bytecode(chunk, ir, vreg_count, global_slots, total_slots)) {
        hot.failed = true;
        return nullptr;
    }
    
    RegAlloc alloc;
    if (!alloc_regs(ir, vreg_count, alloc)) {
        hot.failed = true;
        return nullptr;
    }
    
    CompiledFunc* func = emit_native(ir, alloc, chunk, name);
    if (!func) {
        hot.failed = true;
        return nullptr;
    }
    
    func->global_slots = std::move(global_slots);
    func->total_slots = total_slots;
    cache_[name] = func;
    
    UtilityFunctions::print("[VG_JIT T2] Compiled '", String(name.c_str()), "' → ",
                            (int)func->code_size, " bytes native x86-64 (",
                            (int)ir.size(), " IR ops, ", vreg_count, " vregs)");
    
    return func;
}

int Tier2::total_calls() const {
    int total = 0;
    for (const auto& kv : cache_) {
        total += (int)kv.second->exec_count;
    }
    return total;
}

// Per-thread JIT engine
thread_local Tier2* tl_jit = nullptr;

Tier2& thread_jit() {
    if (!tl_jit) {
        tl_jit = new Tier2();
    }
    return *tl_jit;
}

} // namespace vgjit2
