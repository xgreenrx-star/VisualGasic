// VisualGasic JIT Tier 2 — Native x86-64 Function Body Compilation
// See visual_gasic_jit_tier2.h for design overview.

#include "visual_gasic_jit_tier2.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <cstring>
#include <cstdlib>
#include <algorithm>

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
        if (f.label_id < 0 || f.label_id >= (int)label_pos_.size()) return false;
        int target = label_pos_[f.label_id];
        if (target < 0) return false;
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

// Conditional set helpers: setCC al, then movzx r64, al
static void emit_setcc(CodeBuf& cb, Reg dst, uint8_t cc_byte) {
    // setCC al
    cb.rex(false, false, false, false);
    cb.emit(0x0F); cb.emit(cc_byte);
    cb.modrm(3, 0, 0);  // al = reg 0
    // movzx dst, al
    cb.rex(true, needs_ext(dst), false, false);
    cb.emit(0x0F); cb.emit(0xB6);
    cb.modrm(3, lo3(dst), 0);
    // If dst != rax, move from rax
    if (dst != Reg::RAX) {
        cb.mov_rr(dst, Reg::RAX);
    }
}

void CodeBuf::sete(Reg dst)  { Reg save = dst; emit_setcc(*this, Reg::RAX, 0x94); if (save != Reg::RAX) mov_rr(save, Reg::RAX); }
void CodeBuf::setne(Reg dst) { Reg save = dst; emit_setcc(*this, Reg::RAX, 0x95); if (save != Reg::RAX) mov_rr(save, Reg::RAX); }
void CodeBuf::setle(Reg dst) { Reg save = dst; emit_setcc(*this, Reg::RAX, 0x9E); if (save != Reg::RAX) mov_rr(save, Reg::RAX); }
void CodeBuf::setl(Reg dst)  { Reg save = dst; emit_setcc(*this, Reg::RAX, 0x9C); if (save != Reg::RAX) mov_rr(save, Reg::RAX); }
void CodeBuf::setge(Reg dst) { Reg save = dst; emit_setcc(*this, Reg::RAX, 0x9D); if (save != Reg::RAX) mov_rr(save, Reg::RAX); }
void CodeBuf::setg(Reg dst)  { Reg save = dst; emit_setcc(*this, Reg::RAX, 0x9F); if (save != Reg::RAX) mov_rr(save, Reg::RAX); }

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
    // Restore callee-saved (reverse order)
    pop_r(Reg::R15);
    pop_r(Reg::R14);
    pop_r(Reg::R13);
    pop_r(Reg::R12);
    pop_r(Reg::RBX);
    // mov rsp, rbp; pop rbp; ret
    mov_rr(Reg::RSP, Reg::RBP);
    pop_r(Reg::RBP);
    emit(0xC3);
}

// ═══════════════════════════════════════════════════════════════════
//  Bytecode → IR lowering
// ═══════════════════════════════════════════════════════════════════

// Helper to read a 16-bit value from bytecode
static int read_u16(const uint8_t* code, int ip) {
    return (int)code[ip] | ((int)code[ip+1] << 8);
}

bool Tier2::lower_bytecode(BytecodeChunk* chunk, std::vector<IRInst>& ir, int& vreg_count) {
    const uint8_t* code = chunk->code.ptr();
    int size = chunk->code.size();
    int next_vreg = 0;
    
    // Simulated value stack → maps to virtual registers
    std::vector<int> vstack;
    
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
                        case OP_CONSTANT: case OP_GET_LOCAL: case OP_SET_LOCAL:
                        case OP_GET_GLOBAL: case OP_SET_GLOBAL:
                        case OP_CALL_BUILTIN: case OP_NEW_ARRAY: case OP_NEW_ARRAY_I64:
                        case OP_OPEN_FILE: case OP_INC_LOCAL_I64:
                            advance = 2; break;
                        case OP_CALL: case OP_METHOD_CALL: case OP_GET_ARRAY: case OP_SET_ARRAY:
                        case OP_ADD_I64_CONST: case OP_SUB_I64_CONST: case OP_MUL_I64_CONST:
                        case OP_GET_MEMBER: case OP_SET_MEMBER:
                        case OP_GET_ARRAY_FAST: case OP_SET_ARRAY_FAST:
                        case OP_GET_DICT_FAST: case OP_SET_DICT_FAST:
                        case OP_SET_DICT_LOCAL: case OP_SET_DICT_GLOBAL:
                        case OP_ITER_ARRAY: case OP_NEW_VGDICT:
                        case OP_GET_VGDICT_LOCAL: case OP_SET_VGDICT_LOCAL:
                        case OP_PRINT_FILE: case OP_WRITE_FILE: case OP_INPUT_FILE:
                        case OP_REGISTER_WHENEVER: case OP_SUSPEND_WHENEVER: case OP_RESUME_WHENEVER:
                        case OP_ON_ERROR_GOTO: case OP_GOSUB:
                        case OP_CONSTANT_LONG:
                            advance = 3; break;
                        case OP_DEBUG_LINE:
                            advance = 3; break;
                        case OP_JUMP: case OP_JUMP_IF_FALSE: case OP_JUMP_IF_TRUE: case OP_LOOP:
                        case OP_SETUP_TRY:
                            advance = 3; break;
                        case OP_ACCUM_I64_MULADD_CONST:
                            advance = 4; break;
                        case OP_TASK_RUN_BEGIN:
                            advance = 5; break;
                        case OP_PARALLEL_FOR_BEGIN:
                            advance = 4; break;
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
                int idx = code[ip + 1];
                // Check if the constant is an integer or float
                if (idx < chunk->constants.size()) {
                    Variant v = chunk->constants[idx];
                    if (v.get_type() == Variant::INT) {
                        IRInst inst;
                        inst.op = IROp::CONST_I64;
                        inst.type = IRType::I64;
                        inst.dest = next_vreg++;
                        inst.imm_i64 = (int64_t)v;
                        inst.bc_offset = ip;
                        ir.push_back(inst);
                        vstack.push_back(inst.dest);
                    } else if (v.get_type() == Variant::FLOAT) {
                        IRInst inst;
                        inst.op = IROp::CONST_F64;
                        inst.type = IRType::F64;
                        inst.dest = next_vreg++;
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
                ip += 2;
                break;
            }
            
            case OP_NIL: {
                IRInst inst;
                inst.op = IROp::CONST_ZERO;
                inst.type = IRType::I64;
                inst.dest = next_vreg++;
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
                inst.imm_i64 = 0;
                inst.bc_offset = ip;
                ir.push_back(inst);
                vstack.push_back(inst.dest);
                ip += 1;
                break;
            }
            
            case OP_GET_LOCAL: {
                int slot = code[ip + 1];
                IRInst inst;
                inst.op = IROp::LOAD_LOCAL;
                inst.type = IRType::I64; // Treat all locals as i64 for now
                inst.dest = next_vreg++;
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
                IRInst inst;
                inst.op = IROp::STORE_LOCAL;
                inst.src1 = val;
                inst.local_slot = slot;
                inst.bc_offset = ip;
                ir.push_back(inst);
                ip += 2;
                break;
            }
            
            case OP_INC_LOCAL_I64: {
                int slot = code[ip + 1];
                // Load, increment, store back
                int loaded = next_vreg++;
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
                int const_idx = code[ip + 1];
                int slot = code[ip + 2]; // Actually these opcodes use slot + const differently
                // These opcodes: [OP] [SLOT] [CONST_IDX]
                // They operate on local[slot] with constants[const_idx]
                // Let's load, compute, and store back
                if (const_idx >= chunk->constants.size()) return false;
                Variant cv = chunk->constants[const_idx];
                if (cv.get_type() != Variant::INT) return false;
                int64_t cval = (int64_t)cv;
                
                // Actually the encoding is [OP][SLOT][CONST_IDX] — load from slot, apply const, push result
                int loaded = next_vreg++;
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
                arith.src1 = loaded;
                arith.imm_i64 = cval;
                arith.bc_offset = ip;
                ir.push_back(arith);
                vstack.push_back(arith.dest);
                ip += 3;
                break;
            }
            
            // Float binary ops
            case OP_ADD_F64: case OP_SUB_F64: case OP_MUL_F64: case OP_DIV_F64: {
                if (vstack.size() < 2) return false;
                int rhs = vstack.back(); vstack.pop_back();
                int lhs = vstack.back(); vstack.pop_back();
                IRInst inst;
                if (op == OP_ADD_F64) inst.op = IROp::ADD_F64;
                else if (op == OP_SUB_F64) inst.op = IROp::SUB_F64;
                else if (op == OP_MUL_F64) inst.op = IROp::MUL_F64;
                else inst.op = IROp::DIV_F64;
                inst.type = IRType::F64;
                inst.dest = next_vreg++;
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
                inst.src1 = src;
                inst.bc_offset = ip;
                ir.push_back(inst);
                vstack.push_back(inst.dest);
                ip += 1;
                break;
            }
            
            // Integer comparisons
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
            
            default:
                // Unsupported opcode — cannot JIT this function
                return false;
        }
    }
    
    vreg_count = next_vreg;
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
                if (dst == Reg::SPILL) {
                    cb.load_local_i64(Reg::RAX, inst.local_slot);
                    cb.store_spill(alloc.spill_for(inst.dest), Reg::RAX);
                } else if (dst != Reg::NONE) {
                    cb.load_local_i64(dst, inst.local_slot);
                }
                break;
            }
            
            case IROp::STORE_LOCAL: {
                Reg src = get_or_load(cb, alloc, inst.src1, Reg::RAX);
                cb.store_local_i64(inst.local_slot, src);
                break;
            }
            
            case IROp::ADD_I64: case IROp::SUB_I64: case IROp::MUL_I64: {
                Reg lhs = get_or_load(cb, alloc, inst.src1, Reg::RAX);
                Reg rhs = get_or_load(cb, alloc, inst.src2, Reg::RCX);
                // Result in RAX
                if (lhs != Reg::RAX) cb.mov_rr(Reg::RAX, lhs);
                if (inst.op == IROp::ADD_I64) cb.add_rr(Reg::RAX, rhs);
                else if (inst.op == IROp::SUB_I64) cb.sub_rr(Reg::RAX, rhs);
                else cb.imul_rr(Reg::RAX, rhs);
                store_result(cb, alloc, inst.dest, Reg::RAX);
                break;
            }
            
            case IROp::ADD_I64_CONST: case IROp::SUB_I64_CONST: case IROp::MUL_I64_CONST: {
                Reg src = get_or_load(cb, alloc, inst.src1, Reg::RAX);
                if (src != Reg::RAX) cb.mov_rr(Reg::RAX, src);
                cb.mov_ri64(Reg::RCX, inst.imm_i64);
                if (inst.op == IROp::ADD_I64_CONST) cb.add_rr(Reg::RAX, Reg::RCX);
                else if (inst.op == IROp::SUB_I64_CONST) cb.sub_rr(Reg::RAX, Reg::RCX);
                else cb.imul_rr(Reg::RAX, Reg::RCX);
                store_result(cb, alloc, inst.dest, Reg::RAX);
                break;
            }
            
            case IROp::NEG_I64: {
                Reg src = get_or_load(cb, alloc, inst.src1, Reg::RAX);
                if (src != Reg::RAX) cb.mov_rr(Reg::RAX, src);
                cb.neg_r(Reg::RAX);
                store_result(cb, alloc, inst.dest, Reg::RAX);
                break;
            }
            
            case IROp::INC_I64: {
                Reg src = get_or_load(cb, alloc, inst.src1, Reg::RAX);
                if (src != Reg::RAX) cb.mov_rr(Reg::RAX, src);
                cb.inc_r(Reg::RAX);
                store_result(cb, alloc, inst.dest, Reg::RAX);
                break;
            }
            
            case IROp::ADD_F64: case IROp::SUB_F64: case IROp::MUL_F64: case IROp::DIV_F64: {
                // For simplicity, use XMM0 and XMM1 as scratch
                Reg lhs = alloc.reg_for(inst.src1);
                Reg rhs = alloc.reg_for(inst.src2);
                
                // Load into xmm0 and xmm1 if not already there
                if (lhs >= Reg::XMM0 && lhs <= Reg::XMM7) {
                    if (lhs != Reg::XMM0) cb.movsd_rr(Reg::XMM0, lhs);
                } else {
                    // Load from spill or GP
                    // movq xmm0, rax
                    Reg src = get_or_load(cb, alloc, inst.src1, Reg::RAX);
                    if (src != Reg::RAX) cb.mov_rr(Reg::RAX, src);
                    cb.emit(0x66); cb.rex(true, false, false, false);
                    cb.emit(0x0F); cb.emit(0x6E); cb.modrm(3, 0, 0);
                }
                
                if (rhs >= Reg::XMM0 && rhs <= Reg::XMM7) {
                    if (rhs != Reg::XMM1) cb.movsd_rr(Reg::XMM1, rhs);
                } else {
                    Reg src = get_or_load(cb, alloc, inst.src2, Reg::RCX);
                    if (src != Reg::RCX) cb.mov_rr(Reg::RCX, src);
                    cb.emit(0x66); cb.rex(true, false, false, false);
                    cb.emit(0x0F); cb.emit(0x6E); cb.modrm(3, 1, 1);
                }
                
                if (inst.op == IROp::ADD_F64) cb.addsd(Reg::XMM0, Reg::XMM1);
                else if (inst.op == IROp::SUB_F64) cb.subsd(Reg::XMM0, Reg::XMM1);
                else if (inst.op == IROp::MUL_F64) cb.mulsd(Reg::XMM0, Reg::XMM1);
                else cb.divsd(Reg::XMM0, Reg::XMM1);
                
                Reg dst = alloc.reg_for(inst.dest);
                if (dst >= Reg::XMM0 && dst <= Reg::XMM7 && dst != Reg::XMM0) {
                    cb.movsd_rr(dst, Reg::XMM0);
                }
                // If spilled, movq rax,xmm0 then store
                if (dst == Reg::SPILL) {
                    cb.emit(0x66); cb.rex(true, false, false, false);
                    cb.emit(0x0F); cb.emit(0x7E); cb.modrm(3, 0, 0); // movq rax, xmm0
                    cb.store_spill(alloc.spill_for(inst.dest), Reg::RAX);
                }
                break;
            }
            
            case IROp::EQ_I64: case IROp::NE_I64: case IROp::LE_I64:
            case IROp::LT_I64: case IROp::GE_I64: case IROp::GT_I64: {
                Reg lhs = get_or_load(cb, alloc, inst.src1, Reg::RAX);
                Reg rhs = get_or_load(cb, alloc, inst.src2, Reg::RCX);
                cb.cmp_rr(lhs, rhs);
                
                // Result goes through RAX via setCC
                Reg dst = alloc.reg_for(inst.dest);
                Reg target = (dst != Reg::SPILL && dst != Reg::NONE) ? dst : Reg::RAX;
                
                // xor target first to clear upper bits
                cb.mov_ri32(target, 0);
                
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
                    cb.store_spill(alloc.spill_for(inst.dest), Reg::RAX);
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
    
    if (!lower_bytecode(chunk, ir, vreg_count)) {
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
