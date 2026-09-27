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
#include <deque>
#include <vector>
#include <string>
#include <unordered_map>

#if defined(__linux__) || defined(__APPLE__)
#include <sys/mman.h>
#include <unistd.h>
#endif
#if defined(__APPLE__)
#include <TargetConditionals.h>
#endif

// Tier 2 emits x86-64 only. On by default for every OS that can run those
// bytes: Linux x86-64, Android x86-64, Windows x64, and macOS Intel.
// ARM, iOS, and HTML5 stay on the interpreter.
#if defined(__x86_64__) || defined(_M_X64)
#define VG_JIT_X64 1
#else
#define VG_JIT_X64 0
#endif
#if defined(_WIN32) && VG_JIT_X64
#define VG_JIT_WIN64 1
#else
#define VG_JIT_WIN64 0
#endif
#if defined(__APPLE__) && VG_JIT_X64 && TARGET_OS_OSX
#define VG_JIT_MACOS 1
#else
#define VG_JIT_MACOS 0
#endif
#if VG_JIT_X64 && !defined(VG_WEB_BUILD) && (defined(__linux__) || defined(_WIN32) || VG_JIT_MACOS)
#define VG_JIT_NATIVE 1
#else
#define VG_JIT_NATIVE 0
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
    SHR_I64_CONST,   // dest = src1 >> imm_i64 (arithmetic shift right)
    SHL_I64_CONST,   // dest = src1 << imm_i64 (logical shift left)
    AND_I64,         // dest = src1 & src2   (bitwise)
    OR_I64,          // dest = src1 | src2   (bitwise)
    XOR_I64,         // dest = src1 ^ src2   (bitwise)
    MOD_I64_CONST,   // dest = src1 mod imm_i64  (signed; imm_i64 not in {0,-1})
    IDIV_I64_CONST,  // dest = src1 / imm_i64   (signed, trunc toward 0; imm_i64 not in {0,-1})
    
    // Float arithmetic
    ADD_F64,         SUB_F64,   MUL_F64,   DIV_F64,
    NEG_F64,
    
    // Integer comparison → bool
    EQ_I64,  NE_I64,  LE_I64,  LT_I64,  GE_I64,  GT_I64,
    
    // Float comparison → bool  (uses ucomisd; unsigned condition codes)
    EQ_F64,  NE_F64,  LE_F64,  LT_F64,  GE_F64,  GT_F64,
    
    // Type conversion
    I64_TO_F64,      // dest(f64) = (double)src1(i64)  — cvtsi2sd
    F64_TO_I64,      // dest(i64) = (int64_t)src1(f64) — cvttsd2si (truncate)
    
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
    NOP,

    // Host calls. Caller-saved registers are spilled around these.
    // LIBM1: dest(f64) = libm(imm_i64)(src1). 0 sin, 1 cos, 2 sqrt, 3 tan, 4 fabs, 5 sgn, 6 neg
    LIBM1,
    // RUNTIME_CALL: dest(f64 numeric) = host call. imm_i64 = constant-pool name index.
    // call_n / call_src / call_kind / call_pool describe arguments.
    RUNTIME_CALL,
    // ARRAY_GET: dest(i64) = array(src1). imm_i64 >= 0 → global constant index.
    // imm_i64 < 0 → local slot in local_slot.
    ARRAY_GET,
    // BYREF_LOAD: dest = post-call ByRef capture. imm_i64 = param-name const index.
    // call_kind[0] = 1 if the destination is a global (call_pool[0] = its const index).
    // local_slot is the destination local when call_kind[0] == 0.
    BYREF_LOAD
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
    // RUNTIME_CALL argument vregs (max 8: QbCircle). call_kind: 0 = i64, 1 = f64, 2 = string pool index.
    int     call_src[8] = {};
    int     call_pool[8] = {};
    uint8_t call_kind[8] = {};
    uint8_t call_n = 0;
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
    void and_rr(Reg dst, Reg src);
    void or_rr(Reg dst, Reg src);
    void xor_rr(Reg dst, Reg src);
    void neg_r(Reg r);
    void inc_r(Reg r);
    void cqo();               // sign-extend RAX into RDX:RAX (for idiv)
    void idiv_r(Reg r);       // signed divide RDX:RAX by r64 -> RAX=quot, RDX=rem
    void cmp_rr(Reg a, Reg b);
    void test_rr(Reg a, Reg b);
    
    // Conditional set → 8-bit, then zero-extend
    void sete(Reg dst);
    void setne(Reg dst);
    void setle(Reg dst);
    void setl(Reg dst);
    void setge(Reg dst);
    void setg(Reg dst);
    // Unsigned conditions (used after ucomisd for float comparisons)
    void setb(Reg dst);   // below (CF=1)
    void setbe(Reg dst);  // below or equal (CF=1 || ZF=1)
    void seta(Reg dst);   // above (CF=0 && ZF=0)
    void setae(Reg dst);  // above or equal (CF=0)
    
    // SSE2 double-precision
    void addsd(Reg dst, Reg src);
    void subsd(Reg dst, Reg src);
    void mulsd(Reg dst, Reg src);
    void divsd(Reg dst, Reg src);
    void xorpd(Reg dst, Reg src);
    void movsd_rr(Reg dst, Reg src);
    void ucomisd(Reg lhs, Reg rhs);  // compare floats → EFLAGS
    
    // Memory [rdi + slot*8]. Linux passes locals in rdi. Windows passes them
    // in rcx; the prologue copies rcx to rdi after saving the incoming rdi.
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
    void store_rbp_i64(int off, Reg src);
    void load_rbp_i64(Reg dst, int off);
    void store_rbp_f64(int off, Reg xmm);
    void load_rbp_f64(Reg xmm, int off);
    void lea_rbp(Reg dst, int32_t disp);
    // stack_arg5 is the Windows x64 fifth integer argument (ignored on Linux).
    void call_abs(uint64_t addr, bool stack_arg5 = false, Reg arg5 = Reg::NONE);
    
    const std::vector<uint8_t>& code() const { return buf_; }
    size_t code_size() const { return buf_.size(); }
    size_t label_count() const { return label_pos_.size(); }
    size_t fixup_count() const { return fixups_.size(); }
};

// ═══════════════════════════════════════════════════════════════════
//  Compiled Function Handle
// ═══════════════════════════════════════════════════════════════════

struct CompiledFunc {
    // ABI:  int64_t fn(int64_t *locals, int64_t local_count)
    //  Linux: rdi/rsi. Windows x64: rcx/rdx. Return is rax on both.
    //  returns 0 = normal, 1 = value returned in locals[0]
    typedef int64_t (*FnPtr)(int64_t* locals, int64_t local_count);
    
    void*  code_mem  = nullptr;
    size_t code_size = 0;
    FnPtr  fn        = nullptr;
    std::string name;
    uint64_t exec_count = 0;
    
    // Virtual global→local slot mapping: globals are assigned local slots
    // beyond chunk->local_count so the caller can pre-populate them.
    // Each pair: (global_name, virtual_slot_index).
    std::vector<std::pair<std::string, int>> global_slots;
    int total_slots = 0; // local_count + number of virtual global slots
    // 1 = slot holds an IEEE float bit pattern. Writeback must not cast it to int.
    std::vector<uint8_t> slot_is_f64;
    // Stable storage for string pointers embedded in native code.
    std::deque<std::string> str_pool;
    std::vector<std::string> local_names;
    
    ~CompiledFunc();
};

// ═══════════════════════════════════════════════════════════════════
//  JIT Tier 2 Engine
// ═══════════════════════════════════════════════════════════════════

class Tier2 {
public:
    static constexpr uint64_t HOT_THRESHOLD = 2;
    static constexpr int      MAX_BC_SIZE   = 16384;
    static constexpr size_t   MAX_CACHE     = 256;
    
    Tier2();
    ~Tier2();
    
    bool enabled() const { return enabled_; }
    
    // Record a call; returns compiled fn if ready, else nullptr.
    CompiledFunc* get_or_compile(const std::string& name, BytecodeChunk* chunk, void* inst);
    
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
    bool lower_bytecode(BytecodeChunk* chunk, std::vector<IRInst>& ir, int& vreg_count,
                        std::vector<std::pair<std::string, int>>& global_slots, int& total_slots,
                        std::vector<uint8_t>& slot_is_f64, void* inst, const std::string &fn_name);
    bool alloc_regs(const std::vector<IRInst>& ir, int vreg_count, RegAlloc& out);
    CompiledFunc* emit_native(const std::vector<IRInst>& ir, const RegAlloc& alloc,
                              BytecodeChunk* chunk, const std::string& name);
};

// Per-thread JIT engine
Tier2& thread_jit();

// Active native frame. Host calls (PSet, user Subs) read this.
struct JitFrame {
    void* inst = nullptr;
    CompiledFunc* func = nullptr;
    int64_t* locals = nullptr;
};
JitFrame jit_swap_frame(JitFrame next);
bool jit_func_active(const CompiledFunc *fn);

} // namespace vgjit2

#endif // VISUAL_GASIC_JIT_TIER2_H
