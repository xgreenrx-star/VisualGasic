#ifndef VISUAL_GASIC_JIT_TIER2_H
#define VISUAL_GASIC_JIT_TIER2_H

// VisualGasic JIT Tier 2 — Native x86-64 Function Body Compilation
//
// Extends Tier 1 (simple loop accumulation) to compile entire bytecode
// function bodies into native x86-64 machine code.
//
// Pipeline:  Bytecode → JIT IR → Linear Scan Reg Alloc → x86-64
//
// Supported bytecode opcodes:
//   Constants:   OP_CONSTANT, OP_NIL, OP_TRUE, OP_FALSE
//   Locals:      OP_GET_LOCAL, OP_SET_LOCAL, OP_INC_LOCAL_I64
//   Int arith:   OP_ADD_I64, OP_SUB_I64, OP_MUL_I64,
//                OP_ADD_I64_CONST, OP_SUB_I64_CONST, OP_MUL_I64_CONST
//   Float arith: OP_ADD_F64, OP_SUB_F64, OP_MUL_F64, OP_DIV_F64
//   Compare:     OP_EQUAL_I64, OP_NOT_EQUAL_I64, OP_LESS_EQUAL_I64
//   Flow:        OP_JUMP, OP_JUMP_IF_FALSE, OP_JUMP_IF_TRUE, OP_LOOP
//   Stack:       OP_POP, OP_DUP, OP_NEGATE
//   Return:      OP_RETURN, OP_RETURN_VALUE
//
// Any unsupported opcode causes the function to be skipped (interpreter fallback).

#include "visual_gasic_bytecode.h"
#include <cstdint>
#include <cstddef>
#include <vector>
#include <string>
#include <unordered_map>

#ifdef __linux__
#include <sys/mman.h>
#include <unistd.h>
#endif

namespace vgjit2 {

// ═══════════════════════════════════════════════════════════════════
//  JIT IR (typed intermediate representation)
// ═══════════════════════════════════════════════════════════════════

enum class IRType : uint8_t { I64, F64, BOOL, VOID };

enum class IROp : uint8_t {
    // Constants
    CONST_I64,       // dest = imm_i64
    CONST_F64,       // dest = imm_f64
    CONST_BOOL,      // dest = imm_i64 (0/1)
    CONST_ZERO,      // dest = 0
    
    // Locals  (slot in local_slot field)
    LOAD_LOCAL,      // dest = locals[slot]
    STORE_LOCAL,     // locals[slot] = src1
    
    // Integer arithmetic
    ADD_I64,         // dest = src1 + src2
    SUB_I64,         // dest = src1 - src2
    MUL_I64,         // dest = src1 * src2
    NEG_I64,         // dest = -src1
    INC_I64,         // dest = src1 + 1
    ADD_I64_CONST,   // dest = src1 + imm_i64
    SUB_I64_CONST,   // dest = src1 - imm_i64
    MUL_I64_CONST,   // dest = src1 * imm_i64
    
    // Float arithmetic
    ADD_F64,         SUB_F64,   MUL_F64,   DIV_F64,
    NEG_F64,
    
    // Integer comparison → bool
    EQ_I64,  NE_I64,  LE_I64,  LT_I64,  GE_I64,  GT_I64,
    
    // Control flow
    JUMP,            // goto label_id
    JUMP_IF_FALSE,   // if !src1 goto label_id
    JUMP_IF_TRUE,    // if  src1 goto label_id
    LABEL,           // marker (label_id)
    
    // Register move / copy
    MOV,             // dest = src1
    
    // Return
    RET,             // return void
    RET_VALUE,       // return src1
    
    // No-op (placeholder for popped values)
    NOP
};

struct IRInst {
    IROp    op;
    IRType  type      = IRType::VOID;
    int     dest      = -1;      // virtual register for result
    int     src1      = -1;      // first operand vreg
    int     src2      = -1;      // second operand vreg
    int64_t imm_i64   = 0;
    double  imm_f64   = 0.0;
    int     label_id  = -1;      // for jumps / LABEL
    int     local_slot = -1;     // for LOAD/STORE_LOCAL
    int     bc_offset = -1;      // original bytecode IP
};

// ═══════════════════════════════════════════════════════════════════
//  x86-64 Register Allocation (linear scan)
// ═══════════════════════════════════════════════════════════════════

enum class Reg : uint8_t {
    RAX=0, RCX=1, RDX=2, RBX=3, RSP=4, RBP=5, RSI=6, RDI=7,
    R8=8,  R9=9,  R10=10, R11=11, R12=12, R13=13, R14=14, R15=15,
    XMM0=16, XMM1=17, XMM2=18, XMM3=19,
    XMM4=20, XMM5=21, XMM6=22, XMM7=23,
    NONE=255, SPILL=254
};

struct LiveRange {
    int vreg;
    int first_use;
    int last_use;
    IRType type;
    Reg assigned = Reg::NONE;
    int spill_offset = -1;   // offset from rbp if spilled
};

struct RegAlloc {
    std::vector<LiveRange> ranges;
    int spill_bytes = 0;     // total spill area size
    
    Reg reg_for(int vreg) const;
    int  spill_for(int vreg) const;
};

// ═══════════════════════════════════════════════════════════════════
//  x86-64 Code Buffer
// ═══════════════════════════════════════════════════════════════════

class CodeBuf {
    std::vector<uint8_t> buf_;
    
    struct Fixup { int label_id; size_t patch_offset; };
    std::vector<Fixup> fixups_;
    std::vector<int>   label_pos_;   // label_id → buf offset (-1 = unresolved)
    
public:
    void reset();
    int  new_label();
    void bind_label(int id);
    bool resolve();                  // patch all forward jumps; returns false on error
    
    // raw emit
    void emit(uint8_t b)        { buf_.push_back(b); }
    void emit_i32(int32_t v);
    void emit_u64(uint64_t v);
    size_t pos() const           { return buf_.size(); }
    
    // REX / ModRM helpers
    void rex(bool w, bool r, bool x, bool b);
    void modrm(uint8_t mod, uint8_t reg, uint8_t rm);
    
    // Structured instructions
    void push_r(Reg r);
    void pop_r(Reg r);
    void mov_rr(Reg dst, Reg src);
    void mov_ri64(Reg dst, int64_t imm);
    void mov_ri32(Reg dst, int32_t imm);
    
    void add_rr(Reg dst, Reg src);
    void sub_rr(Reg dst, Reg src);
    void imul_rr(Reg dst, Reg src);
    void neg_r(Reg r);
    void inc_r(Reg r);
    void cmp_rr(Reg a, Reg b);
    void test_rr(Reg a, Reg b);
    
    // Conditional set → 8-bit, then zero-extend
    void sete(Reg dst);
    void setne(Reg dst);
    void setle(Reg dst);
    void setl(Reg dst);
    void setge(Reg dst);
    void setg(Reg dst);
    
    // SSE2 double-precision
    void addsd(Reg dst, Reg src);
    void subsd(Reg dst, Reg src);
    void mulsd(Reg dst, Reg src);
    void divsd(Reg dst, Reg src);
    void xorpd(Reg dst, Reg src);
    void movsd_rr(Reg dst, Reg src);
    
    // Memory [rdi + slot*8]  (locals array passed in rdi)
    void load_local_i64(Reg dst, int slot);
    void store_local_i64(int slot, Reg src);
    void load_local_f64(Reg xmm, int slot);
    void store_local_f64(int slot, Reg xmm);
    
    // Spill [rbp - off]
    void load_spill(Reg dst, int off);
    void store_spill(int off, Reg src);
    
    // Jumps (32-bit relative)
    void jmp_label(int id);
    void je_label(int id);
    void jne_label(int id);
    
    // Prologue / Epilogue
    void prologue(int spill_bytes);
    void epilogue();
    
    const std::vector<uint8_t>& code() const { return buf_; }
    size_t code_size() const { return buf_.size(); }
};

// ═══════════════════════════════════════════════════════════════════
//  Compiled Function Handle
// ═══════════════════════════════════════════════════════════════════

struct CompiledFunc {
    // ABI:  int64_t fn(int64_t *locals, int64_t local_count)
    //  returns 0 = normal, 1 = value returned in locals[0]
    typedef int64_t (*FnPtr)(int64_t* locals, int64_t local_count);
    
    void*  code_mem  = nullptr;
    size_t code_size = 0;
    FnPtr  fn        = nullptr;
    std::string name;
    uint64_t exec_count = 0;
    
    ~CompiledFunc();
};

// ═══════════════════════════════════════════════════════════════════
//  JIT Tier 2 Engine
// ═══════════════════════════════════════════════════════════════════

class Tier2 {
public:
    static constexpr uint64_t HOT_THRESHOLD = 50;
    static constexpr int      MAX_BC_SIZE   = 4096;
    static constexpr size_t   MAX_CACHE     = 64;
    
    Tier2();
    ~Tier2();
    
    bool enabled() const { return enabled_; }
    
    // Record a call; returns compiled fn if ready, else nullptr.
    CompiledFunc* get_or_compile(const std::string& name, BytecodeChunk* chunk);
    
    // Stats
    int  compiled_count() const { return (int)cache_.size(); }
    int  total_calls()   const;
    
private:
    bool enabled_ = false;
    int  tier_level_ = 0;
    
    struct HotInfo {
        uint64_t calls = 0;
        bool tried = false;
        bool failed = false;
    };
    std::unordered_map<std::string, HotInfo> hot_;
    std::unordered_map<std::string, CompiledFunc*> cache_;
    
    HotInfo& get_hotness(const std::string& name);
    
    // Pipeline
    bool lower_bytecode(BytecodeChunk* chunk, std::vector<IRInst>& ir, int& vreg_count);
    bool alloc_regs(const std::vector<IRInst>& ir, int vreg_count, RegAlloc& out);
    CompiledFunc* emit_native(const std::vector<IRInst>& ir, const RegAlloc& alloc,
                              BytecodeChunk* chunk, const std::string& name);
};

// Per-thread JIT engine
Tier2& thread_jit();

} // namespace vgjit2

#endif // VISUAL_GASIC_JIT_TIER2_H
