// VisualGasic JIT Tier 2 — Native x86-64 Function Body Compilation
// See visual_gasic_jit_tier2.h for design overview.

#include "visual_gasic_jit_tier2.h"
#include "visual_gasic_instance.h"
#include "visual_gasic_builtins.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <cmath>
#include <cstring>
#include <cstdlib>
#include <algorithm>
#include <unordered_set>
#if VG_JIT_WIN64
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
// minwindef.h defines VOID as void, which breaks IRType::VOID below.
#ifdef VOID
#undef VOID
#endif
#endif
#if VG_JIT_MACOS
#include <pthread.h>
#include <libkern/OSCacheControl.h>
#ifndef MAP_JIT
#define MAP_JIT 0x800
#endif
extern "C" void pthread_jit_write_protect_np(int enable) __attribute__((weak_import));
#endif

using namespace godot;

namespace {

// Tier2 locals are only I64/F64 bit patterns. String (and most Variant) results
// from host_call are dropped to 0, which then surfaces as 0.0 after finish_host_ret
// — e.g. FormatCoordHelper(ByVal Double) As String returned 0.0 for every call
// after HOT_THRESHOLD. Keep those bodies on the interpreter.
bool jit_tier2_name_eq_ci(const char *a, const char *b) {
	if (!a || !b) {
		return false;
	}
	for (int i = 0;; i++) {
		unsigned char ca = (unsigned char)a[i];
		unsigned char cb = (unsigned char)b[i];
		if (ca >= 'A' && ca <= 'Z') {
			ca = (unsigned char)(ca - 'A' + 'a');
		}
		if (cb >= 'A' && cb <= 'Z') {
			cb = (unsigned char)(cb - 'A' + 'a');
		}
		if (ca != cb) {
			return false;
		}
		if (ca == 0) {
			return true;
		}
	}
}

bool jit_tier2_non_numeric_callee(const char *name) {
	if (!name || !name[0]) {
		return false;
	}
	// Builtins whose return value is String (or otherwise not I64/F64).
	static const char *k_names[] = {
		"cstr", "str", "replace", "left", "right", "mid", "trim", "ltrim", "rtrim",
		"lcase", "ucase", "chr", "format", "space", "hex", "oct", "string",
		"join", "typename", "chrw", "strconv", "guidtostring", nullptr
	};
	for (int i = 0; k_names[i]; i++) {
		if (jit_tier2_name_eq_ci(name, k_names[i])) {
			return true;
		}
	}
	return false;
}

bool jit_tier2_chunk_has_non_numeric_slots(const BytecodeChunk *chunk) {
	if (!chunk || !chunk->fast_params) {
		return false;
	}
	// 3 = String in the compiler's fast_*_coerce enum.
	if (chunk->fast_return_coerce == 3) {
		return true;
	}
	for (int i = 0; i < chunk->fast_param_coerce.size(); i++) {
		if (chunk->fast_param_coerce[i] == 3) {
			return true;
		}
	}
	return false;
}

} // namespace

Variant VisualGasicInstance::jit_invoke_call(const String &method, const Array &args, bool &handled) {
    handled = false;
    return call_internal(method, args, handled);
}

Variant VisualGasicInstance::jit_byref_capture(const String &name, bool &found) const {
    found = false;
    for (int i = 0; i < _last_byref_captures.size(); i++) {
        if (_last_byref_captures[i].first == name) {
            found = true;
            return _last_byref_captures[i].second;
        }
    }
    return Variant();
}

namespace vgjit2 {

// ═══════════════════════════════════════════════════════════════════
//  CompiledFunc destructor — free executable memory
// ═══════════════════════════════════════════════════════════════════

CompiledFunc::~CompiledFunc() {
    if (!code_mem) return;
#if VG_JIT_WIN64
    VirtualFree(code_mem, 0, MEM_RELEASE);
#elif defined(__linux__) || defined(__APPLE__)
    munmap(code_mem, code_size);
#endif
}

void* install_executable_code(const void* code, size_t code_size, size_t* out_alloc_size) {
    if (!code || code_size == 0 || !out_alloc_size) {
        return nullptr;
    }
#if VG_JIT_NATIVE
    size_t page_size = 4096;
    size_t alloc_size = ((code_size + page_size - 1) / page_size) * page_size;
    if (alloc_size == 0) {
        alloc_size = page_size;
    }

#if VG_JIT_WIN64
    void* mem = VirtualAlloc(nullptr, alloc_size, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    if (!mem) {
        return nullptr;
    }
    memcpy(mem, code, code_size);
    DWORD old_protect = 0;
    if (!VirtualProtect(mem, alloc_size, PAGE_EXECUTE_READ, &old_protect)) {
        VirtualFree(mem, 0, MEM_RELEASE);
        return nullptr;
    }
    FlushInstructionCache(GetCurrentProcess(), mem, alloc_size);
    {
        using SetTargetsFn = int (WINAPI *)(HANDLE, void*, SIZE_T, ULONG, void*);
        auto set_targets = (SetTargetsFn)GetProcAddress(GetModuleHandleA("kernel32.dll"), "SetProcessValidCallTargets");
        if (set_targets) {
            struct CfgTarget { ULONG_PTR offset; ULONG_PTR flags; };
            CfgTarget target;
            target.offset = 0;
            target.flags = 0x1;
            set_targets(GetCurrentProcess(), mem, alloc_size, 1, &target);
        }
    }
#elif VG_JIT_MACOS
    void* mem = mmap(nullptr, alloc_size, PROT_READ | PROT_WRITE | PROT_EXEC,
                     MAP_PRIVATE | MAP_ANONYMOUS | MAP_JIT, -1, 0);
    bool map_jit = mem != MAP_FAILED;
    if (!map_jit) {
        mem = mmap(nullptr, alloc_size, PROT_READ | PROT_WRITE,
                   MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        if (mem == MAP_FAILED) {
            return nullptr;
        }
    }
    if (map_jit && pthread_jit_write_protect_np) {
        pthread_jit_write_protect_np(0);
    }
    memcpy(mem, code, code_size);
    if (map_jit && pthread_jit_write_protect_np) {
        pthread_jit_write_protect_np(1);
    } else if (!map_jit && mprotect(mem, alloc_size, PROT_READ | PROT_EXEC) != 0) {
        munmap(mem, alloc_size);
        return nullptr;
    }
    sys_icache_invalidate(mem, code_size);
#else
    void* mem = mmap(nullptr, alloc_size, PROT_READ | PROT_WRITE,
                     MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (mem == MAP_FAILED) {
        return nullptr;
    }
    memcpy(mem, code, code_size);
    if (mprotect(mem, alloc_size, PROT_READ | PROT_EXEC) != 0) {
        munmap(mem, alloc_size);
        return nullptr;
    }
#endif
    *out_alloc_size = alloc_size;
    return mem;
#else
    (void)code;
    (void)code_size;
    *out_alloc_size = 0;
    return nullptr;
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

// cqo — sign-extend RAX into RDX:RAX (REX.W 99). Required before idiv.
void CodeBuf::cqo() {
    rex(true, false, false, false);
    emit(0x99);
}

// idiv r64 — signed divide RDX:RAX by r64. Quotient -> RAX, remainder -> RDX.
// REX.W + F7 /7
void CodeBuf::idiv_r(Reg r) {
    rex(true, false, false, needs_ext(r));
    emit(0xF7);
    modrm(3, 7, lo3(r));
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
    // Save callee-saved registers we use: rbx, r12, r13, r14, r15.
    // Windows x64 also treats rdi as callee-saved. The locals pointer is
    // copied into rdi after this prologue.
    push_r(Reg::RBX);
    push_r(Reg::R12);
    push_r(Reg::R13);
    push_r(Reg::R14);
    push_r(Reg::R15);
#if VG_JIT_WIN64
    push_r(Reg::RDI);
#endif
    // Allocate spill area
    if (spill_bytes > 0) {
#if VG_JIT_WIN64
        // push rbp + 6 callee saves leaves rsp ≡ 0. Round the spill to 16.
        int aligned = (spill_bytes + 15) & ~15;
#else
        // After push rbp + 5 callee-saved pushes, rsp ≡ 8 (mod 16).
        // Round the spill up to 16, then add 8 so rsp ≡ 0 before a host call.
        int aligned = ((spill_bytes + 15) & ~15) + 8;
#endif
        rex(true, false, false, false);
        emit(0x81); modrm(3, 5, 4); // sub rsp, imm32
        emit_i32(aligned);
    }
}

void CodeBuf::store_rbp_i64(int off, Reg src) {
    int32_t disp = -off;
    rex(true, needs_ext(src), false, false);
    emit(0x89);
    modrm(2, lo3(src), 5);
    emit_i32(disp);
}

void CodeBuf::load_rbp_i64(Reg dst, int off) {
    int32_t disp = -off;
    rex(true, needs_ext(dst), false, false);
    emit(0x8B);
    modrm(2, lo3(dst), 5);
    emit_i32(disp);
}

void CodeBuf::store_rbp_f64(int off, Reg xmm) {
    int32_t disp = -off;
    uint8_t x = (uint8_t)xmm - (uint8_t)Reg::XMM0;
    emit(0xF2); emit(0x0F); emit(0x11);
    modrm(2, x & 7, 5);
    emit_i32(disp);
}

void CodeBuf::load_rbp_f64(Reg xmm, int off) {
    int32_t disp = -off;
    uint8_t x = (uint8_t)xmm - (uint8_t)Reg::XMM0;
    emit(0xF2); emit(0x0F); emit(0x10);
    modrm(2, x & 7, 5);
    emit_i32(disp);
}

void CodeBuf::lea_rbp(Reg dst, int32_t disp) {
    rex(true, needs_ext(dst), false, false);
    emit(0x8D);
    modrm(2, lo3(dst), 5);
    emit_i32(disp);
}

void CodeBuf::call_abs(uint64_t addr, bool stack_arg5, Reg arg5) {
#if VG_JIT_WIN64
    // Microsoft x64: 32-byte shadow space, rsp 16-aligned at the call.
    // A fifth integer argument sits at [rsp+32]. 48 bytes keeps alignment.
    mov_ri64(Reg::R11, (int64_t)addr);
    int shadow = stack_arg5 ? 48 : 32;
    rex(true, false, false, false);
    emit(0x83); modrm(3, 5, 4); emit((uint8_t)shadow); // sub rsp, shadow
    if (stack_arg5 && arg5 != Reg::NONE) {
        rex(true, needs_ext(arg5), false, false);
        emit(0x89);
        modrm(1, lo3(arg5), 4); // [rsp+disp8] via SIB
        emit(0x24);
        emit(32);
    }
    emit(0x41); emit(0xFF); emit(0xD3); // call r11
    rex(true, false, false, false);
    emit(0x83); modrm(3, 0, 4); emit((uint8_t)shadow); // add rsp, shadow
#else
    (void)stack_arg5;
    (void)arg5;
    mov_ri64(Reg::RAX, (int64_t)addr);
    emit(0xFF);
    emit(0xD0);
#endif
}

void CodeBuf::epilogue() {
    // Skip the spill area and land on the callee-saved registers.
#if VG_JIT_WIN64
    // rbx, r12, r13, r14, r15, rdi → 48 bytes
    emit(0x48); emit(0x8D); emit(0x65); emit((uint8_t)(int8_t)-48);
    pop_r(Reg::RDI);
#else
    // rbx, r12, r13, r14, r15 → 40 bytes. 48 8D 65 D8
    emit(0x48); emit(0x8D); emit(0x65); emit((uint8_t)(int8_t)-40);
#endif
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

// Last opcode lower_bytecode was looking at, so a silent bail can be logged.
static int g_jit_lower_ip = -1;
static int g_jit_lower_op = -1;

// Helper to read a 16-bit value from bytecode
static int read_u16(const uint8_t* code, int ip) {
    return ((int)code[ip] << 8) | (int)code[ip+1];
}

bool Tier2::lower_bytecode(BytecodeChunk* chunk, std::vector<IRInst>& ir, int& vreg_count,
                           std::vector<std::pair<std::string, int>>& global_slots, int& total_slots,
                           std::vector<uint8_t>& slot_is_f64, void* inst, const std::string &fn_name) {
    const uint8_t* code = chunk->code.ptr();
    int size = chunk->code.size();
    int next_vreg = 0;
    
    // Simulated value stack → maps to virtual registers
    std::vector<int> vstack;
    
    // vreg → integer constant value (for constant-shift-count detection)
    std::unordered_map<int, int64_t> vreg_const_i64;
    // vreg → global constant-pool index (array base or numeric global)
    std::unordered_map<int, int> vreg_global_idx;
    // vreg → string constant-pool index (only valid as a call argument)
    std::unordered_map<int, int> vreg_str_pool;
    
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
    // Compiler type tags: 2 = Single/Double. Params are loaded before any store,
    // so the slot must start as F64 or a float argument is cvtsi2sd'd as an int.
    for (int si = 0; chunk && si < chunk->local_count && si < chunk->local_types.size(); si++) {
        if (chunk->local_types[si] == 2) {
            local_slot_type[si] = IRType::F64;
        }
    }
    
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
                        case OP_GET_ARRAY: case OP_SET_ARRAY:
                        case OP_GET_ARRAY_FAST: case OP_SET_ARRAY_FAST:
                        case OP_GET_ARRAY_UNCHECKED: case OP_SET_ARRAY_UNCHECKED:
                        case OP_GET_ARRAY_FAST_UNCHECKED: case OP_SET_ARRAY_FAST_UNCHECKED:
                        case OP_GET_ARRAY_I64_LOCAL: case OP_SET_ARRAY_I64_LOCAL:
                        case OP_PUSH_SCOPE:
                            advance = 2; break;
                        // 3-byte opcodes (op + 2-byte const index, or other 2-byte operands)
                        case OP_CONSTANT:
                        case OP_GET_BLOCK_LOCAL: case OP_SET_BLOCK_LOCAL:
                        case OP_GET_GLOBAL: case OP_SET_GLOBAL:
                        case OP_ADD_I64_CONST: case OP_SUB_I64_CONST: case OP_MUL_I64_CONST:
                        case OP_GET_MEMBER: case OP_SET_MEMBER:
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
                        case OP_BYREF_LOAD:
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
                case OP_PUSH_SCOPE:
                    ip += 2; break;
                case OP_GET_BLOCK_LOCAL: case OP_SET_BLOCK_LOCAL:
                    ip += 3; break;
                case OP_CALL:
                    ip += 4; break;
                case OP_CALL_BUILTIN:
                    ip += 3; break;
                case OP_CONSTANT_LONG:
                    ip += 3; break;
                case OP_ACCUM_I64_MULADD_CONST:
                    ip += 5; break;
                case OP_BYREF_LOAD:
                    ip += 6; break;
                default:
                    ip += 1; break;
            }
        }
    }
    
    // Block-scoped Dims (Dim inside For/Do) are a side stack in the VM.
    // Each static PUSH_SCOPE owns a fixed range of JIT slots, zeroed every entry.
    struct BlockScope { int base; int count; };
    std::vector<BlockScope> block_scopes;
    auto block_slot = [&](int frame_from_top, int offset, int &slot_out) -> bool {
        int idx = (int)block_scopes.size() - 1 - frame_from_top;
        if (idx < 0 || idx >= (int)block_scopes.size()) return false;
        if (offset < 0 || offset >= block_scopes[idx].count) return false;
        slot_out = block_scopes[idx].base + offset;
        return true;
    };

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
        g_jit_lower_ip = ip;
        g_jit_lower_op = op;
        
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
                    } else if (v.get_type() == Variant::STRING) {
                        IRInst inst;
                        inst.op = IROp::CONST_I64;
                        inst.type = IRType::VOID;
                        inst.dest = next_vreg++;
                        set_vreg_type(inst.dest, IRType::VOID);
                        inst.imm_i64 = idx;
                        inst.bc_offset = ip;
                        ir.push_back(inst);
                        vstack.push_back(inst.dest);
                        vreg_str_pool[inst.dest] = idx;
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
                if (stt != local_slot_type.end()) {
                    slot_type = stt->second;
                } else if (inst && name_idx < chunk->constants.size()) {
                    VisualGasicInstance *vi = static_cast<VisualGasicInstance *>(inst);
                    Variant cv = chunk->constants[name_idx];
                    String gname = (cv.get_type() == Variant::STRING) ? String(cv) : cv.stringify();
                    if (vi->get_variables().has(gname)) {
                        Variant gv = vi->get_variables()[gname];
                        Variant::Type gt = gv.get_type();
                        if (gt == Variant::FLOAT) {
                            slot_type = IRType::F64;
                            local_slot_type[vslot] = IRType::F64;
                        } else if (gt != Variant::INT && gt != Variant::BOOL && gt != Variant::NIL) {
                            // Object, String, Array, Vector2, and Color are not
                            // integer slots. Loading one as I64 passes 0 into
                            // the next call, so the callee sees Nothing and the
                            // canvas never redraws. Stay on the interpreter.
                            return false;
                        }
                    }
                }
                IRInst ld;
                ld.op = IROp::LOAD_LOCAL;
                ld.type = slot_type;
                ld.dest = next_vreg++;
                set_vreg_type(ld.dest, slot_type);
                ld.local_slot = vslot;
                ld.bc_offset = ip;
                ir.push_back(ld);
                vstack.push_back(ld.dest);
                vreg_global_idx[ld.dest] = name_idx;
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
                auto force_i64 = [&](int v) -> int {
                    if (get_vreg_type(v) == IRType::VOID) return -1;
                    if (get_vreg_type(v) != IRType::F64) return v;
                    int conv = next_vreg++;
                    set_vreg_type(conv, IRType::I64);
                    IRInst cv; cv.op = IROp::F64_TO_I64; cv.type = IRType::I64;
                    cv.dest = conv; cv.src1 = v; cv.bc_offset = ip;
                    ir.push_back(cv);
                    return conv;
                };
                lhs = force_i64(lhs);
                rhs = force_i64(rhs);
                if (lhs < 0 || rhs < 0) return false;
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
                if (const_idx >= chunk->constants.size()) return false;
                Variant cv = chunk->constants[const_idx];
                if (cv.get_type() != Variant::INT) return false;
                int64_t cval = (int64_t)cv;
                
                // Match the VM's [operand, literal] stack contract.
                if (vstack.size() < 2) return false;
                vstack.pop_back();
                int loaded = vstack.back();
                vstack.pop_back();
                if (get_vreg_type(loaded) == IRType::VOID) return false;
                if (get_vreg_type(loaded) == IRType::F64) {
                    IRInst conv;
                    conv.op = IROp::F64_TO_I64;
                    conv.type = IRType::I64;
                    conv.dest = next_vreg++;
                    conv.src1 = loaded;
                    conv.bc_offset = ip;
                    set_vreg_type(conv.dest, IRType::I64);
                    ir.push_back(conv);
                    loaded = conv.dest;
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
                if (get_vreg_type(src) == IRType::VOID) return false;
                IRInst ninst;
                if (get_vreg_type(src) == IRType::F64) {
                    ninst.op = IROp::LIBM1;
                    ninst.type = IRType::F64;
                    ninst.imm_i64 = 6;
                    ninst.dest = next_vreg++;
                    set_vreg_type(ninst.dest, IRType::F64);
                } else {
                    ninst.op = IROp::NEG_I64;
                    ninst.type = IRType::I64;
                    ninst.dest = next_vreg++;
                    set_vreg_type(ninst.dest, IRType::I64);
                }
                ninst.src1 = src;
                ninst.bc_offset = ip;
                ir.push_back(ninst);
                vstack.push_back(ninst.dest);
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
            
            // ── Bitwise AND / OR / XOR ──
            // The interpreter uses bitwise ops when both operands are numeric
            // (float truncated to int64) and logical ops otherwise. JIT values
            // are only I64 or F64, and booleans are 0/1, where bitwise and
            // logical agree. A non-numeric vreg still bails.
            case OP_AND: case OP_OR: case OP_XOR: {
                if (vstack.size() < 2) return false;
                int rhs = vstack.back(); vstack.pop_back();
                int lhs = vstack.back(); vstack.pop_back();
                auto to_i64 = [&](int v) -> int {
                    IRType t = get_vreg_type(v);
                    if (t == IRType::I64) return v;
                    if (t != IRType::F64) return -1;
                    int conv = next_vreg++;
                    set_vreg_type(conv, IRType::I64);
                    IRInst cv;
                    cv.op = IROp::F64_TO_I64;
                    cv.type = IRType::I64;
                    cv.dest = conv;
                    cv.src1 = v;
                    cv.bc_offset = ip;
                    ir.push_back(cv);
                    return conv;
                };
                lhs = to_i64(lhs);
                rhs = to_i64(rhs);
                if (lhs < 0 || rhs < 0) return false;
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

            // Logical Not: !to_bool(x). Numeric 0 is false; any other number is
            // true. The 0/1 result is written back as Boolean when the
            // destination variable already is one.
            case OP_NOT: {
                if (vstack.empty()) return false;
                int src = vstack.back(); vstack.pop_back();
                IRType ty = get_vreg_type(src);
                int zero = next_vreg++;
                IRInst cz;
                cz.dest = zero;
                cz.bc_offset = ip;
                IROp cmp;
                if (ty == IRType::F64) {
                    set_vreg_type(zero, IRType::F64);
                    cz.op = IROp::CONST_F64;
                    cz.type = IRType::F64;
                    cz.imm_f64 = 0.0;
                    cmp = IROp::EQ_F64;
                } else if (ty == IRType::I64) {
                    set_vreg_type(zero, IRType::I64);
                    cz.op = IROp::CONST_I64;
                    cz.type = IRType::I64;
                    cz.imm_i64 = 0;
                    cmp = IROp::EQ_I64;
                } else {
                    return false;
                }
                ir.push_back(cz);
                IRInst inst;
                inst.op = cmp;
                inst.type = IRType::BOOL;
                inst.dest = next_vreg++;
                set_vreg_type(inst.dest, IRType::I64);
                inst.src1 = src;
                inst.src2 = zero;
                inst.bc_offset = ip;
                ir.push_back(inst);
                vstack.push_back(inst.dest);
                ip += 1;
                break;
            }
            
            // ── Integer modulo / integer divide by a CONSTANT divisor ────
            // idiv clobbers RDX and can raise #DE (SIGFPE) on divide-by-zero
            // or the INT64_MIN / -1 overflow. To stay trap-free (a hard
            // requirement for eventually enabling the JIT by default) we only
            // compile these when the divisor is a compile-time constant that
            // is neither 0 nor -1. Variable or unsafe divisors bail to the
            // interpreter, which raises a clean VG "Division by zero" error.
            // C++ `%` / `/` on int64 truncate toward zero — identical to the
            // interpreter (to_int(a) % b, ival_a / ival_b) and to x86 idiv.
            case OP_MOD: case OP_INT_DIVIDE: {
                if (vstack.size() < 2) return false;
                int rhs = vstack.back(); vstack.pop_back();
                int lhs = vstack.back(); vstack.pop_back();
                if (get_vreg_type(lhs) != IRType::I64 || get_vreg_type(rhs) != IRType::I64) return false;
                auto cit = vreg_const_i64.find(rhs);
                if (cit == vreg_const_i64.end()) return false;
                int64_t divisor = cit->second;
                if (divisor == 0 || divisor == -1) return false;
                IRInst inst;
                inst.op = (op == OP_MOD) ? IROp::MOD_I64_CONST : IROp::IDIV_I64_CONST;
                inst.type = IRType::I64;
                inst.dest = next_vreg++;
                set_vreg_type(inst.dest, IRType::I64);
                inst.src1 = lhs;
                inst.imm_i64 = divisor;
                inst.bc_offset = ip;
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
            
            case OP_DIVIDE: {
                if (vstack.size() < 2) return false;
                int rhs = vstack.back(); vstack.pop_back();
                int lhs = vstack.back(); vstack.pop_back();
                if (get_vreg_type(lhs) == IRType::VOID || get_vreg_type(rhs) == IRType::VOID) return false;
                auto force_f = [&](int v) -> int {
                    if (get_vreg_type(v) == IRType::F64) return v;
                    int conv = next_vreg++;
                    set_vreg_type(conv, IRType::F64);
                    IRInst cv; cv.op = IROp::I64_TO_F64; cv.type = IRType::F64;
                    cv.dest = conv; cv.src1 = v; cv.bc_offset = ip;
                    ir.push_back(cv);
                    return conv;
                };
                lhs = force_f(lhs);
                rhs = force_f(rhs);
                IRInst dinst;
                dinst.op = IROp::DIV_F64;
                dinst.type = IRType::F64;
                dinst.dest = next_vreg++;
                set_vreg_type(dinst.dest, IRType::F64);
                dinst.src1 = lhs;
                dinst.src2 = rhs;
                dinst.bc_offset = ip;
                ir.push_back(dinst);
                vstack.push_back(dinst.dest);
                ip += 1;
                break;
            }

            case OP_SIN: case OP_COS: case OP_SQRT: case OP_TAN: case OP_ABS: case OP_SGN: {
                if (vstack.empty()) return false;
                int src = vstack.back(); vstack.pop_back();
                if (get_vreg_type(src) == IRType::VOID) return false;
                if (get_vreg_type(src) != IRType::F64 && op != OP_ABS && op != OP_SGN) {
                    int conv = next_vreg++;
                    set_vreg_type(conv, IRType::F64);
                    IRInst cv; cv.op = IROp::I64_TO_F64; cv.type = IRType::F64;
                    cv.dest = conv; cv.src1 = src; cv.bc_offset = ip;
                    ir.push_back(cv);
                    src = conv;
                }
                if (op == OP_ABS && get_vreg_type(src) != IRType::F64) {
                    // Integer absolute value stays on the integer path via a host call
                    // only when the value is float. Integer abs is a compare/neg below.
                    IRInst ainst;
                    ainst.op = IROp::LIBM1;
                    ainst.imm_i64 = 4;
                    ainst.type = IRType::I64;
                    ainst.dest = next_vreg++;
                    set_vreg_type(ainst.dest, IRType::I64);
                    ainst.src1 = src;
                    ainst.bc_offset = ip;
                    ir.push_back(ainst);
                    vstack.push_back(ainst.dest);
                    ip += 1;
                    break;
                }
                IRInst minst;
                minst.op = IROp::LIBM1;
                minst.type = (op == OP_SGN) ? IRType::I64 : IRType::F64;
                minst.dest = next_vreg++;
                set_vreg_type(minst.dest, minst.type);
                minst.src1 = src;
                minst.bc_offset = ip;
                if (op == OP_SIN) minst.imm_i64 = 0;
                else if (op == OP_COS) minst.imm_i64 = 1;
                else if (op == OP_SQRT) minst.imm_i64 = 2;
                else if (op == OP_TAN) minst.imm_i64 = 3;
                else if (op == OP_ABS) minst.imm_i64 = 4;
                else minst.imm_i64 = 5;
                ir.push_back(minst);
                vstack.push_back(minst.dest);
                ip += 1;
                break;
            }

            case OP_CALL: {
                int name_idx = (code[ip + 2] << 8) | code[ip + 1];
                int argc = code[ip + 3];
                if (argc < 0 || argc > 8) return false;
                // Direct recursion shares the function-name return slot across
                // frames. Leave those bodies on the interpreter.
                if (name_idx >= 0 && name_idx < chunk->constants.size()) {
                    Variant cv = chunk->constants[name_idx];
                    String cn = (cv.get_type() == Variant::STRING) ? String(cv) : cv.stringify();
                    CharString cs = cn.utf8();
                    const char *got = cs.get_data();
                    const char *want = fn_name.c_str();
                    if (jit_tier2_non_numeric_callee(got)) {
                        // CStr/Replace/… return String; host_call drops that to 0.
                        return false;
                    }
                    if (got && want && !fn_name.empty() && jit_tier2_name_eq_ci(got, want)) {
                        return false;
                    }
                }
                if ((int)vstack.size() < argc) return false;
                IRInst cinst;
                cinst.op = IROp::RUNTIME_CALL;
                cinst.imm_i64 = name_idx;
                cinst.call_n = (uint8_t)argc;
                cinst.type = IRType::F64;
                cinst.dest = next_vreg++;
                set_vreg_type(cinst.dest, IRType::F64);
                cinst.bc_offset = ip;
                for (int a = argc - 1; a >= 0; a--) {
                    int v = vstack.back(); vstack.pop_back();
                    cinst.call_src[a] = v;
                    auto sit = vreg_str_pool.find(v);
                    if (sit != vreg_str_pool.end()) {
                        // String-literal args mean a string-oriented call; Tier2
                        // cannot keep the String result either.
                        return false;
                    } else if (get_vreg_type(v) == IRType::F64) {
                        cinst.call_kind[a] = 1;
                    } else if (get_vreg_type(v) == IRType::VOID) {
                        return false;
                    } else {
                        cinst.call_kind[a] = 0;
                    }
                }
                ir.push_back(cinst);
                vstack.push_back(cinst.dest);
                ip += 4;
                break;
            }

            case OP_GET_ARRAY: case OP_GET_ARRAY_FAST:
            case OP_GET_ARRAY_UNCHECKED: case OP_GET_ARRAY_FAST_UNCHECKED: {
                int argc = code[ip + 1];
                if (argc != 1 || vstack.size() < 2) return false;
                int idx = vstack.back(); vstack.pop_back();
                int base = vstack.back(); vstack.pop_back();
                auto git = vreg_global_idx.find(base);
                if (git == vreg_global_idx.end()) return false;
                if (get_vreg_type(idx) == IRType::F64) {
                    int conv = next_vreg++;
                    set_vreg_type(conv, IRType::I64);
                    IRInst cv; cv.op = IROp::F64_TO_I64; cv.type = IRType::I64;
                    cv.dest = conv; cv.src1 = idx; cv.bc_offset = ip;
                    ir.push_back(cv);
                    idx = conv;
                }
                IRInst ainst;
                ainst.op = IROp::ARRAY_GET;
                ainst.type = IRType::I64;
                ainst.dest = next_vreg++;
                set_vreg_type(ainst.dest, IRType::I64);
                ainst.src1 = idx;
                ainst.imm_i64 = git->second;
                ainst.local_slot = -1;
                ainst.bc_offset = ip;
                ir.push_back(ainst);
                vstack.push_back(ainst.dest);
                ip += 2;
                break;
            }

            case OP_GET_ARRAY_I64_LOCAL: {
                int slot = code[ip + 1];
                if (vstack.empty()) return false;
                int idx = vstack.back(); vstack.pop_back();
                if (get_vreg_type(idx) == IRType::F64) {
                    int conv = next_vreg++;
                    set_vreg_type(conv, IRType::I64);
                    IRInst cv; cv.op = IROp::F64_TO_I64; cv.type = IRType::I64;
                    cv.dest = conv; cv.src1 = idx; cv.bc_offset = ip;
                    ir.push_back(cv);
                    idx = conv;
                }
                IRInst ainst;
                ainst.op = IROp::ARRAY_GET;
                ainst.type = IRType::I64;
                ainst.dest = next_vreg++;
                set_vreg_type(ainst.dest, IRType::I64);
                ainst.src1 = idx;
                ainst.imm_i64 = -1;
                ainst.local_slot = slot;
                ainst.bc_offset = ip;
                ir.push_back(ainst);
                vstack.push_back(ainst.dest);
                ip += 2;
                break;
            }

            case OP_PUSH_SCOPE: {
                int count = code[ip + 1];
                BlockScope sc;
                sc.base = next_global_slot;
                sc.count = count;
                next_global_slot += count;
                block_scopes.push_back(sc);
                for (int s = 0; s < count; s++) {
                    int z = next_vreg++;
                    set_vreg_type(z, IRType::I64);
                    IRInst cz;
                    cz.op = IROp::CONST_I64;
                    cz.type = IRType::I64;
                    cz.dest = z;
                    cz.imm_i64 = 0;
                    cz.bc_offset = ip;
                    ir.push_back(cz);
                    IRInst st;
                    st.op = IROp::STORE_LOCAL;
                    st.src1 = z;
                    st.local_slot = sc.base + s;
                    st.bc_offset = ip;
                    ir.push_back(st);
                }
                ip += 2;
                break;
            }
            case OP_POP_SCOPE: {
                if (block_scopes.empty()) return false;
                block_scopes.pop_back();
                ip += 1;
                break;
            }
            case OP_GET_BLOCK_LOCAL: {
                int frame = code[ip + 1];
                int offset = code[ip + 2];
                int slot = 0;
                if (!block_slot(frame, offset, slot)) return false;
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
                ip += 3;
                break;
            }
            case OP_SET_BLOCK_LOCAL: {
                int frame = code[ip + 1];
                int offset = code[ip + 2];
                if (vstack.empty()) return false;
                int slot = 0;
                if (!block_slot(frame, offset, slot)) return false;
                int val = vstack.back(); vstack.pop_back();
                if (i64_pinned_slots.count(slot) && get_vreg_type(val) == IRType::F64) {
                    int conv = next_vreg++;
                    set_vreg_type(conv, IRType::I64);
                    IRInst cv; cv.op = IROp::F64_TO_I64; cv.type = IRType::I64;
                    cv.dest = conv; cv.src1 = val; cv.bc_offset = ip;
                    ir.push_back(cv);
                    val = conv;
                }
                local_slot_type[slot] = get_vreg_type(val);
                IRInst inst;
                inst.op = IROp::STORE_LOCAL;
                inst.src1 = val;
                inst.local_slot = slot;
                inst.bc_offset = ip;
                ir.push_back(inst);
                ip += 3;
                break;
            }

            case OP_BYREF_LOAD: {
                int name_idx = (code[ip + 2] << 8) | code[ip + 1];
                int is_global = code[ip + 3];
                int dest = (code[ip + 5] << 8) | code[ip + 4];
                IRType ty = IRType::I64;
                if (is_global) {
                    auto git = global_const_to_slot.find(dest);
                    if (git != global_const_to_slot.end()) {
                        auto stt = local_slot_type.find(git->second);
                        if (stt != local_slot_type.end()) ty = stt->second;
                    }
                } else {
                    auto stt = local_slot_type.find(dest);
                    if (stt != local_slot_type.end()) ty = stt->second;
                }
                IRInst binst;
                binst.op = IROp::BYREF_LOAD;
                binst.type = ty;
                binst.dest = next_vreg++;
                set_vreg_type(binst.dest, ty);
                binst.imm_i64 = name_idx;
                binst.call_kind[0] = (uint8_t)(is_global ? 1 : 0);
                binst.call_pool[0] = dest;
                binst.local_slot = is_global ? -1 : dest;
                binst.bc_offset = ip;
                ir.push_back(binst);
                vstack.push_back(binst.dest);
                ip += 6;
                break;
            }

            default: {
                const char *jit_log = std::getenv("VG_JIT_LOG");
                if (jit_log && jit_log[0] == '1') {
                    UtilityFunctions::print("[VG_JIT T2] bail opcode ", (int)op, " at ", ip);
                }
                return false;
            }
        }
    }
    
    vreg_count = next_vreg;
    total_slots = next_global_slot; // local_count + virtual global count
    slot_is_f64.assign(total_slots > 0 ? total_slots : 0, 0);
    for (const auto &kv : local_slot_type) {
        if (kv.first >= 0 && kv.first < (int)slot_is_f64.size() && kv.second == IRType::F64) {
            slot_is_f64[kv.first] = 1;
        }
    }
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
        for (int c = 0; c < (int)inst.call_n && c < 8; c++) {
            if (inst.call_kind[c] != 2) {
                touch(inst.call_src[c]);
            }
        }
    }
    
    // Remove unused vregs
    std::vector<LiveRange> active_ranges;
    for (auto& r : ranges) {
        if (r.last_use >= 0) active_ranges.push_back(r);
    }
    
    // Sort by start position
    std::sort(active_ranges.begin(), active_ranges.end(),
              [](const LiveRange& a, const LiveRange& b) { return a.first_use < b.first_use; });
    
    // The emitter reserves rax/rcx/rdx and xmm0-xmm2 for temporary operands.
    std::vector<Reg> gp_pool = { Reg::RBX, Reg::R8, Reg::R9,
                                  Reg::R10, Reg::R11, Reg::R12, Reg::R13, Reg::R14, Reg::R15 };
#if VG_JIT_WIN64
    // XMM6 and XMM7 are callee-saved on Windows x64.
    std::vector<Reg> fp_pool = { Reg::XMM3,
                                  Reg::XMM4, Reg::XMM5 };
#else
    std::vector<Reg> fp_pool = { Reg::XMM3,
                                  Reg::XMM4, Reg::XMM5, Reg::XMM6, Reg::XMM7 };
#endif
    
    std::vector<bool> gp_used(gp_pool.size(), false);
    std::vector<bool> fp_used(fp_pool.size(), false);
    
    // Active intervals (currently live)
    std::vector<int> active_indices;  // indices into active_ranges
    
#if VG_JIT_WIN64
    // rbp-8 .. rbp-48 hold rbx, r12-r15, and rdi. Spills start underneath them.
    int next_spill = 56;
#else
    int next_spill = 48; // rbp-8 .. rbp-40 hold callee-saved registers.
#endif
    // Keep spills below the emitter's 960-byte host-call frame.
    for (const auto &inst : ir) {
        if (inst.op == IROp::LIBM1 || inst.op == IROp::RUNTIME_CALL ||
            inst.op == IROp::ARRAY_GET || inst.op == IROp::BYREF_LOAD) {
            next_spill = 968;
            break;
        }
    }
    
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
//  Host calls from native code (math, PSet/LINE, user Subs, arrays)
// ═══════════════════════════════════════════════════════════════════

static thread_local JitFrame g_jit_frame;

JitFrame jit_swap_frame(JitFrame next) {
    JitFrame prev = g_jit_frame;
    g_jit_frame = next;
    return prev;
}

bool jit_func_active(const CompiledFunc *fn) {
    return fn && g_jit_frame.func == fn;
}

static bool jit_numeric_var(const Variant &v) {
    Variant::Type t = v.get_type();
    return t == Variant::NIL || t == Variant::INT || t == Variant::FLOAT || t == Variant::BOOL;
}

static void jit_sync_globals(bool to_vars) {
    VisualGasicInstance *vi = static_cast<VisualGasicInstance *>(g_jit_frame.inst);
    if (!vi || !g_jit_frame.func || !g_jit_frame.locals) {
        return;
    }
    Dictionary &vars = vi->get_variables();
    const CompiledFunc *fn = g_jit_frame.func;
    for (const auto &gs : fn->global_slots) {
        int slot = gs.second;
        if (slot < 0) {
            continue;
        }
        String name(gs.first.c_str());
        bool is_f = slot < (int)fn->slot_is_f64.size() && fn->slot_is_f64[slot];
        if (to_vars) {
            if (vars.has(name) && !jit_numeric_var(vars[name])) {
                continue;
            }
            // Keep Boolean variables boolean. Writing 0/1 as Integer makes
            // `flag = True` fail after a JIT write-back.
            if (vars.has(name) && vars[name].get_type() == Variant::BOOL) {
                vars[name] = g_jit_frame.locals[slot] != 0;
                continue;
            }
            if (is_f) {
                double d = 0;
                memcpy(&d, &g_jit_frame.locals[slot], 8);
                vars[name] = d;
            } else {
                vars[name] = (int64_t)g_jit_frame.locals[slot];
            }
        } else if (vars.has(name)) {
            Variant cur = vars[name];
            if (cur.get_type() == Variant::FLOAT) {
                double d = (double)cur;
                memcpy(&g_jit_frame.locals[slot], &d, 8);
            } else if (cur.get_type() == Variant::INT || cur.get_type() == Variant::BOOL) {
                g_jit_frame.locals[slot] = (int64_t)cur;
            }
        }
    }
}

static int64_t host_libm(int64_t which, int64_t bits, int64_t is_float, int64_t *flag_out) {
    if (flag_out) {
        *flag_out = 0;
    }
    if (which == 4 && !is_float) {
        int64_t v = bits;
        if (v < 0) {
            v = -v;
        }
        return v;
    }
    double d = 0;
    if (is_float) {
        memcpy(&d, &bits, 8);
    } else {
        d = (double)bits;
    }
    if (which == 5) {
        int64_t s = (d > 0.0) - (d < 0.0);
        return s;
    }
    double r = d;
    if (which == 0) r = ::sin(d);
    else if (which == 1) r = ::cos(d);
    else if (which == 2) r = ::sqrt(d);
    else if (which == 3) r = ::tan(d);
    else if (which == 4) r = ::fabs(d);
    else if (which == 6) r = -d;
    int64_t out = 0;
    memcpy(&out, &r, 8);
    if (flag_out) {
        *flag_out = 1;
    }
    return out;
}

static int64_t host_call(int64_t name_ptr, int64_t argc, int64_t bits_ptr, int64_t kind_ptr, int64_t *flag_out) {
    int64_t ret = 0;
    if (flag_out) {
        *flag_out = 0;
    }
    VisualGasicInstance *vi = static_cast<VisualGasicInstance *>(g_jit_frame.inst);
    if (!vi || !name_ptr || argc < 0 || argc > 8) {
        return ret;
    }
    JitFrame saved = g_jit_frame;
    jit_sync_globals(true);
    const int64_t *bits = reinterpret_cast<const int64_t *>(bits_ptr);
    const int64_t *kinds = reinterpret_cast<const int64_t *>(kind_ptr);
    Array args;
    args.resize((int)argc);
    for (int i = 0; i < (int)argc; i++) {
        int kind = kinds ? (int)kinds[i] : 0;
        if (kind == 2) {
            const char *s = reinterpret_cast<const char *>(bits[i]);
            args[i] = String(s ? s : "");
        } else if (kind == 1) {
            double d = 0;
            memcpy(&d, &bits[i], 8);
            args[i] = d;
        } else {
            args[i] = bits[i];
        }
    }
    String method(reinterpret_cast<const char *>(name_ptr));
    bool handled = false;
    Variant r = VisualGasicBuiltins::call_builtin_expr_evaluated(vi, method, args, handled);
    if (!handled) {
        VisualGasicBuiltins::call_builtin(vi, method, args, r, handled);
    }
    if (!handled) {
        r = vi->jit_invoke_call(method, args, handled);
    }
    g_jit_frame = saved;
    jit_sync_globals(false);
    if (!handled || r.get_type() == Variant::NIL) {
        return ret;
    }
    if (r.get_type() == Variant::FLOAT) {
        double d = (double)r;
        memcpy(&ret, &d, 8);
        if (flag_out) {
            *flag_out = 1;
        }
        return ret;
    }
    if (r.get_type() == Variant::INT || r.get_type() == Variant::BOOL) {
        ret = (int64_t)r;
    }
    return ret;
}

static int64_t host_array_get(int64_t name_ptr, int64_t index) {
    VisualGasicInstance *vi = static_cast<VisualGasicInstance *>(g_jit_frame.inst);
    if (!vi || !name_ptr) {
        return 0;
    }
    String name(reinterpret_cast<const char *>(name_ptr));
    Dictionary &vars = vi->get_variables();
    if (!vars.has(name)) {
        return 0;
    }
    Variant base = vars[name];
    int idx = (int)index;
    if (idx < 0) {
        return 0;
    }
    if (base.get_type() == Variant::PACKED_INT64_ARRAY) {
        PackedInt64Array a = base;
        if (idx >= a.size()) return 0;
        return (int64_t)a[idx];
    }
    if (base.get_type() == Variant::PACKED_INT32_ARRAY) {
        PackedInt32Array a = base;
        if (idx >= a.size()) return 0;
        return (int64_t)a[idx];
    }
    if (base.get_type() == Variant::ARRAY) {
        Array a = base;
        if (idx >= a.size()) return 0;
        Variant el = a[idx];
        if (el.get_type() == Variant::FLOAT) {
            return (int64_t)(double)el;
        }
        return (int64_t)el;
    }
    return 0;
}

static int64_t host_byref(int64_t name_ptr, int64_t is_global, int64_t dest, int64_t *flag_out) {
    int64_t ret = 0;
    if (flag_out) {
        *flag_out = 0;
    }
    VisualGasicInstance *vi = static_cast<VisualGasicInstance *>(g_jit_frame.inst);
    if (!vi || !name_ptr) {
        return ret;
    }
    String pname(reinterpret_cast<const char *>(name_ptr));
    bool found = false;
    Variant result = vi->jit_byref_capture(pname, found);
    if (!found) {
        if (is_global && dest) {
            String dname(reinterpret_cast<const char *>(dest));
            if (vi->get_variables().has(dname)) {
                result = vi->get_variables()[dname];
            }
        } else if (!is_global && g_jit_frame.locals && dest >= 0) {
            CompiledFunc *fn = g_jit_frame.func;
            int64_t bits = g_jit_frame.locals[dest];
            if (fn && dest < (int64_t)fn->slot_is_f64.size() && fn->slot_is_f64[(size_t)dest]) {
                if (flag_out) {
                    *flag_out = 1;
                }
            }
            return bits;
        }
    }
    if (result.get_type() == Variant::FLOAT) {
        double d = (double)result;
        memcpy(&ret, &d, 8);
        if (flag_out) {
            *flag_out = 1;
        }
        return ret;
    }
    if (result.get_type() == Variant::INT || result.get_type() == Variant::BOOL) {
        ret = (int64_t)result;
    }
    return ret;
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

#if VG_JIT_WIN64
static Reg host_arg_reg(int n) {
    static const Reg r[4] = { Reg::RCX, Reg::RDX, Reg::R8, Reg::R9 };
    return r[n];
}
#else
static Reg host_arg_reg(int n) {
    static const Reg r[6] = { Reg::RDI, Reg::RSI, Reg::RDX, Reg::RCX, Reg::R8, Reg::R9 };
    return r[n];
}
#endif

static void emit_host_imm(CodeBuf &cb, int n, int64_t imm) {
    cb.mov_ri64(host_arg_reg(n), imm);
}

static void emit_host_reg(CodeBuf &cb, int n, Reg src) {
    Reg dst = host_arg_reg(n);
    if (src != dst) cb.mov_rr(dst, src);
}

CompiledFunc* Tier2::emit_native(const std::vector<IRInst>& ir, const RegAlloc& alloc,
                                  BytecodeChunk* chunk, const std::string& name) {
#if !VG_JIT_NATIVE
    (void)ir; (void)alloc; (void)chunk; (void)name;
    return nullptr;
#else
    CompiledFunc *out_func = new CompiledFunc();
    out_func->name = name;
    if (chunk) {
        for (int i = 0; i < chunk->local_names.size(); i++) {
            out_func->local_names.push_back(std::string(String(chunk->local_names[i]).utf8().get_data()));
        }
    }
    auto intern = [&](const String &s) -> const char * {
        out_func->str_pool.push_back(std::string(s.utf8().get_data()));
        return out_func->str_pool.back().c_str();
    };
    CodeBuf cb;
    cb.reset();
    
    // Create labels
    int max_label = 0;
    for (const auto& inst : ir) {
        if (inst.label_id >= max_label) max_label = inst.label_id + 1;
    }
    for (int i = 0; i < max_label; i++) cb.new_label();
    
    bool needs_host = false;
    for (const auto &probe : ir) {
        if (probe.op == IROp::LIBM1 || probe.op == IROp::RUNTIME_CALL || probe.op == IROp::ARRAY_GET ||
            probe.op == IROp::BYREF_LOAD) {
            needs_host = true;
            break;
        }
    }
    int spill_bytes = alloc.spill_bytes;
    if (needs_host && spill_bytes < 960) {
        spill_bytes = 960;
    }
    cb.prologue(spill_bytes);
#if VG_JIT_WIN64
    // Microsoft x64 passes the locals pointer in rcx. The rest of the
    // emitter addresses locals through rdi, matching the Linux body.
    cb.mov_rr(Reg::RDI, Reg::RCX);
#endif
    // rdi = locals pointer. rsi (Linux) / rdx (Windows) = local_count, unused.

    auto reg_live = [&](int ir_index, Reg r, int dest_vreg) {
        for (const auto &range : alloc.ranges) {
            if (range.vreg == dest_vreg) continue;
            if (range.assigned != r) continue;
            if (range.first_use <= ir_index && range.last_use >= ir_index) return true;
        }
        return false;
    };
    auto save_caller = [&](int ir_index, int dest_vreg) {
        const Reg gps[] = { Reg::RCX, Reg::RDX, Reg::R8, Reg::R9, Reg::R10, Reg::R11 };
        for (int i = 0; i < 6; i++) {
            if (reg_live(ir_index, gps[i], dest_vreg)) {
                cb.store_rbp_i64(520 + i * 8, gps[i]);
            }
        }
        for (int i = 0; i < 8; i++) {
            Reg xm = (Reg)((int)Reg::XMM0 + i);
            if (reg_live(ir_index, xm, dest_vreg)) {
                cb.store_rbp_f64(576 + i * 8, xm);
            }
        }
    };
    auto restore_caller = [&](int ir_index, int dest_vreg) {
        const Reg gps[] = { Reg::RCX, Reg::RDX, Reg::R8, Reg::R9, Reg::R10, Reg::R11 };
        for (int i = 0; i < 6; i++) {
            if (reg_live(ir_index, gps[i], dest_vreg)) {
                cb.load_rbp_i64(gps[i], 520 + i * 8);
            }
        }
        for (int i = 0; i < 8; i++) {
            Reg xm = (Reg)((int)Reg::XMM0 + i);
            if (reg_live(ir_index, xm, dest_vreg)) {
                cb.load_rbp_f64(xm, 576 + i * 8);
            }
        }
    };
    // Host return is in rax (bits) and rdx (is_float). XMM0 is scratch here:
    // caller-saved values are already on the stack and restored afterwards.
    auto finish_host_ret = [&](const IRInst &hin, int ir_index) {
        bool want_f = hin.type == IRType::F64;
        int isf_lab = cb.new_label();
        int done_lab = cb.new_label();
        cb.test_rr(Reg::RDX, Reg::RDX);
        cb.jne_label(isf_lab);
        if (want_f) {
            cb.emit(0xF2); cb.rex(true, false, false, false);
            cb.emit(0x0F); cb.emit(0x2A); cb.modrm(3, 0, 0);
            cb.emit(0x66); cb.rex(true, false, false, false);
            cb.emit(0x0F); cb.emit(0x7E); cb.modrm(3, 0, 0);
        }
        cb.jmp_label(done_lab);
        cb.bind_label(isf_lab);
        if (!want_f) {
            cb.emit(0x66); cb.rex(true, false, false, false);
            cb.emit(0x0F); cb.emit(0x6E); cb.modrm(3, 0, 0);
            cb.emit(0xF2); cb.rex(true, false, false, false);
            cb.emit(0x0F); cb.emit(0x2C); cb.modrm(3, 0, 0);
        }
        cb.bind_label(done_lab);
        cb.store_rbp_i64(496, Reg::RAX);
        cb.load_rbp_i64(Reg::RDI, 512);
        restore_caller(ir_index, hin.dest);
        cb.load_rbp_i64(Reg::RAX, 496);
        Reg dst = alloc.reg_for(hin.dest);
        if (dst >= Reg::XMM0 && dst <= Reg::XMM7) {
            uint8_t xi = (uint8_t)((uint8_t)dst - (uint8_t)Reg::XMM0);
            cb.emit(0x66); cb.rex(true, false, false, false);
            cb.emit(0x0F); cb.emit(0x6E); cb.modrm(3, xi, 0);
        } else {
            store_result(cb, alloc, hin.dest, Reg::RAX);
        }
    };
    
    for (int ii = 0; ii < (int)ir.size(); ii++) {
        const auto& inst = ir[ii];
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
            
            case IROp::MOD_I64_CONST: case IROp::IDIV_I64_CONST: {
                // Signed divide by a known-safe constant (never 0 or -1, so no
                // #DE trap). idiv clobbers RAX (quotient) and RDX (remainder).
                // RAX is the reserved scratch; RCX/RDX are allocatable, so we
                // save and restore them around the divide. Spills are rbp-
                // relative and locals rdi-relative, so the balanced push/pop
                // of rsp does not disturb them, and no call occurs in between.
                cb.push_r(Reg::RDX);
                cb.push_r(Reg::RCX);
                // lhs -> RAX. get_or_load reads the current register/spill; the
                // pushes above did not change any register contents, so if lhs
                // lives in RCX/RDX it is still captured into RAX before we
                // overwrite those registers below.
                Reg lhs = get_or_load(cb, alloc, inst.src1, Reg::RAX);
                if (lhs != Reg::RAX) cb.mov_rr(Reg::RAX, lhs);
                cb.mov_ri64(Reg::RCX, inst.imm_i64);   // divisor
                cb.cqo();                              // sign-extend RAX -> RDX:RAX
                cb.idiv_r(Reg::RCX);                   // RAX=quot, RDX=rem
                if (inst.op == IROp::MOD_I64_CONST) cb.mov_rr(Reg::RAX, Reg::RDX);
                cb.pop_r(Reg::RCX);
                cb.pop_r(Reg::RDX);
                store_result(cb, alloc, inst.dest, Reg::RAX);
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
                
                // A spilled destination must not overwrite a still-live source.
                Reg work = Reg::XMM2;
                if (dst >= Reg::XMM0 && dst <= Reg::XMM7 && dst != xmm_a && dst != xmm_b) {
                    work = dst;
                }
                if (work != xmm_a) cb.movsd_rr(work, xmm_a);
                
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
            
            case IROp::LIBM1: {
                save_caller(ii, inst.dest);
                cb.store_rbp_i64(512, Reg::RDI);
                bool src_f = false;
                for (const auto &range : alloc.ranges) {
                    if (range.vreg == inst.src1 && range.type == IRType::F64) src_f = true;
                }
                if (src_f) {
                    Reg xm = alloc.reg_for(inst.src1);
                    if (xm == Reg::SPILL) {
                        cb.load_spill(Reg::RAX, alloc.spill_for(inst.src1));
                    } else if (xm >= Reg::XMM0 && xm <= Reg::XMM7) {
                        uint8_t xi = (uint8_t)((uint8_t)xm - (uint8_t)Reg::XMM0);
                        cb.emit(0x66); cb.rex(true, false, false, false);
                        cb.emit(0x0F); cb.emit(0x7E);
                        cb.modrm(3, xi, 0);
                    }
                } else {
                    Reg gp = get_or_load(cb, alloc, inst.src1, Reg::RAX);
                    if (gp != Reg::RAX) cb.mov_rr(Reg::RAX, gp);
                }
                emit_host_reg(cb, 1, Reg::RAX);
                emit_host_imm(cb, 0, inst.imm_i64);
                emit_host_imm(cb, 2, src_f ? 1 : 0);
                cb.lea_rbp(host_arg_reg(3), -488);
                cb.call_abs((uint64_t)&host_libm);
                cb.load_rbp_i64(Reg::RDX, 488);
                finish_host_ret(inst, ii);
                break;
            }
            case IROp::RUNTIME_CALL: {
                save_caller(ii, inst.dest);
                cb.store_rbp_i64(512, Reg::RDI);
                String mname;
                if (chunk && inst.imm_i64 >= 0 && inst.imm_i64 < chunk->constants.size()) {
                    Variant cv = chunk->constants[(int)inst.imm_i64];
                    mname = (cv.get_type() == Variant::STRING) ? String(cv) : cv.stringify();
                }
                const char *np = intern(mname);
                for (int a = 0; a < (int)inst.call_n; a++) {
                    // Element 0 is the lowest address so a C pointer indexes +i.
                    // Eight bits at rbp-864 and eight kinds at rbp-800, clear of
                    // the XMM spill slots at rbp-576 .. rbp-632.
                    int off = 864 - a * 8;
                    int koff = 800 - a * 8;
                    if (inst.call_kind[a] == 2) {
                        String lit;
                        int pidx = inst.call_pool[a];
                        if (chunk && pidx >= 0 && pidx < chunk->constants.size()) {
                            Variant cv = chunk->constants[pidx];
                            lit = (cv.get_type() == Variant::STRING) ? String(cv) : cv.stringify();
                        }
                        const char *sp = intern(lit);
                        cb.mov_ri64(Reg::RAX, (int64_t)sp);
                        cb.store_rbp_i64(off, Reg::RAX);
                        cb.mov_ri64(Reg::RAX, 2);
                        cb.store_rbp_i64(koff, Reg::RAX);
                    } else if (inst.call_kind[a] == 1) {
                        Reg xm = alloc.reg_for(inst.call_src[a]);
                        if (xm < Reg::XMM0 || xm > Reg::XMM7) {
                            if (alloc.reg_for(inst.call_src[a]) == Reg::SPILL) {
                                cb.load_spill(Reg::RAX, alloc.spill_for(inst.call_src[a]));
                            }
                        } else {
                            cb.emit(0x66); cb.rex(true, false, false, false);
                            cb.emit(0x0F); cb.emit(0x7E);
                            cb.modrm(3, (uint8_t)((uint8_t)xm - (uint8_t)Reg::XMM0) & 7, 0);
                        }
                        cb.store_rbp_i64(off, Reg::RAX);
                        cb.mov_ri64(Reg::RAX, 1);
                        cb.store_rbp_i64(koff, Reg::RAX);
                    } else {
                        Reg gp = get_or_load(cb, alloc, inst.call_src[a], Reg::RAX);
                        if (gp != Reg::RAX) cb.mov_rr(Reg::RAX, gp);
                        cb.store_rbp_i64(off, Reg::RAX);
                        cb.mov_ri64(Reg::RAX, 0);
                        cb.store_rbp_i64(koff, Reg::RAX);
                    }
                }
                emit_host_imm(cb, 0, (int64_t)np);
                emit_host_imm(cb, 1, (int64_t)inst.call_n);
                cb.lea_rbp(host_arg_reg(2), -864);
                cb.lea_rbp(host_arg_reg(3), -800);
#if VG_JIT_WIN64
                cb.lea_rbp(Reg::R10, -488);
                cb.call_abs((uint64_t)&host_call, true, Reg::R10);
#else
                cb.lea_rbp(Reg::R8, -488);
                cb.call_abs((uint64_t)&host_call);
#endif
                cb.load_rbp_i64(Reg::RDX, 488);
                finish_host_ret(inst, ii);
                break;
            }
            case IROp::ARRAY_GET: {
                save_caller(ii, inst.dest);
                cb.store_rbp_i64(512, Reg::RDI);
                String aname;
                if (inst.imm_i64 >= 0 && chunk && inst.imm_i64 < chunk->constants.size()) {
                    Variant cv = chunk->constants[(int)inst.imm_i64];
                    aname = (cv.get_type() == Variant::STRING) ? String(cv) : cv.stringify();
                } else if (inst.local_slot >= 0 && inst.local_slot < (int)out_func->local_names.size()) {
                    aname = String(out_func->local_names[inst.local_slot].c_str());
                }
                const char *ap = intern(aname);
                Reg gp = get_or_load(cb, alloc, inst.src1, Reg::RAX);
                emit_host_reg(cb, 1, gp);
                emit_host_imm(cb, 0, (int64_t)ap);
                cb.call_abs((uint64_t)&host_array_get);
                cb.store_rbp_i64(496, Reg::RAX);
                cb.load_rbp_i64(Reg::RDI, 512);
                restore_caller(ii, inst.dest);
                cb.load_rbp_i64(Reg::RAX, 496);
                store_result(cb, alloc, inst.dest, Reg::RAX);
                break;
            }
            case IROp::BYREF_LOAD: {
                save_caller(ii, inst.dest);
                cb.store_rbp_i64(512, Reg::RDI);
                String pname;
                if (chunk && inst.imm_i64 >= 0 && inst.imm_i64 < chunk->constants.size()) {
                    Variant cv = chunk->constants[(int)inst.imm_i64];
                    pname = (cv.get_type() == Variant::STRING) ? String(cv) : cv.stringify();
                }
                const char *pp = intern(pname);
                emit_host_imm(cb, 0, (int64_t)pp);
                emit_host_imm(cb, 1, inst.call_kind[0] ? 1 : 0);
                if (inst.call_kind[0]) {
                    String dname;
                    int didx = inst.call_pool[0];
                    if (chunk && didx >= 0 && didx < chunk->constants.size()) {
                        Variant cv = chunk->constants[didx];
                        dname = (cv.get_type() == Variant::STRING) ? String(cv) : cv.stringify();
                    }
                    const char *dp = intern(dname);
                    emit_host_imm(cb, 2, (int64_t)dp);
                } else {
                    emit_host_imm(cb, 2, (int64_t)inst.local_slot);
                }
                cb.lea_rbp(host_arg_reg(3), -488);
                cb.call_abs((uint64_t)&host_byref);
                cb.load_rbp_i64(Reg::RDX, 488);
                finish_host_ret(inst, ii);
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
        delete out_func;
        return nullptr;
    }
    
    size_t alloc_size = 0;
    void* mem = install_executable_code(cb.code().data(), cb.code_size(), &alloc_size);
    if (!mem) {
        delete out_func;
        return nullptr;
    }

    out_func->code_mem = mem;
    out_func->code_size = alloc_size;
    out_func->fn = (CompiledFunc::FnPtr)mem;
    return out_func;
#endif
}

// ═══════════════════════════════════════════════════════════════════
//  Tier2 Engine
// ═══════════════════════════════════════════════════════════════════

Tier2::Tier2() {
    const char* env = std::getenv("VG_JIT");
    // Default on for every x86-64 target this compiler can emit:
    // Linux, Android x86-64, Windows x64, and macOS Intel.
    // VG_JIT=0 keeps every function on the interpreter.
    if (env && env[0] == '0' && env[1] == '\0') {
        enabled_ = false;
        return;
    }
#if VG_JIT_NATIVE
    enabled_ = true;
    tier_level_ = 2;
    if (env && env[0] != '\0') {
        int lvl = std::atoi(env);
        if (lvl >= 1) tier_level_ = lvl;
    }
#else
    if (env && env[0] != '\0' && env[0] != '0') {
        enabled_ = true;
        tier_level_ = std::atoi(env);
        if (tier_level_ < 1) tier_level_ = 1;
    }
#endif
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

CompiledFunc* Tier2::get_or_compile(const std::string& name, BytecodeChunk* chunk, void* inst) {
    if (!enabled_ || tier_level_ < 2) return nullptr;
    // Overloads share a name and must not share native code. The chunk
    // pointer is stable for one compiled body, including recursive calls.
    std::string cache_key = name;
    cache_key.push_back('@');
    cache_key += std::to_string(reinterpret_cast<uintptr_t>(chunk));
    
    // Check cache
    auto cache_it = cache_.find(cache_key);
    if (cache_it != cache_.end()) {
        cache_it->second->exec_count++;
        return cache_it->second;
    }
    
    // Update hotness
    HotInfo& hot = get_hotness(cache_key);
    hot.calls++;
    
    if (hot.tried) return nullptr;
    if (hot.calls < HOT_THRESHOLD) return nullptr;
    if (!chunk || chunk->code.size() == 0) return nullptr;
    if (chunk->code.size() > MAX_BC_SIZE) { hot.tried = true; hot.failed = true; return nullptr; }
    if (cache_.size() >= MAX_CACHE) return nullptr;
    // String params/returns are not representable in Tier2 locals (see
    // jit_tier2_chunk_has_non_numeric_slots). Compiling them made ByVal Double
    // helpers that return String hand back 0.0 after the hot threshold.
    if (jit_tier2_chunk_has_non_numeric_slots(chunk)) {
        hot.tried = true;
        hot.failed = true;
        return nullptr;
    }
    
    hot.tried = true;
    
    // Pipeline: bytecode → IR → regalloc → native
    std::vector<IRInst> ir;
    int vreg_count = 0;
    std::vector<std::pair<std::string, int>> global_slots;
    std::vector<uint8_t> slot_is_f64;
    int total_slots = 0;
    
    const char *jit_log = std::getenv("VG_JIT_LOG");
    if (jit_log && jit_log[0] == '1') {
        UtilityFunctions::print("[VG_JIT T2] Attempting compile: '", String(name.c_str()), "' (", (int)chunk->code.size(), " bytes BC, ", chunk->local_count, " locals)");
    }
    
    if (!lower_bytecode(chunk, ir, vreg_count, global_slots, total_slots, slot_is_f64, inst, name)) {
        if (jit_log && jit_log[0] == '1') {
            String extra;
            if (g_jit_lower_op == (int)OP_CALL && chunk && g_jit_lower_ip >= 0 &&
                g_jit_lower_ip + 3 < chunk->code.size()) {
                int ni = (chunk->code[g_jit_lower_ip + 2] << 8) | chunk->code[g_jit_lower_ip + 1];
                int argc = chunk->code[g_jit_lower_ip + 3];
                String cn;
                if (ni >= 0 && ni < chunk->constants.size()) {
                    Variant cv = chunk->constants[ni];
                    cn = (cv.get_type() == Variant::STRING) ? String(cv) : cv.stringify();
                }
                extra = String(" call ") + cn + " argc " + String::num_int64(argc);
            }
            UtilityFunctions::print("[VG_JIT T2] lower failed '", String(name.c_str()),
                                    "' ip ", g_jit_lower_ip, " op ", g_jit_lower_op, extra);
        }
        hot.failed = true;
        return nullptr;
    }
    
    RegAlloc alloc;
    if (!alloc_regs(ir, vreg_count, alloc)) {
        if (jit_log && jit_log[0] == '1') {
            UtilityFunctions::print("[VG_JIT T2] regalloc failed '", String(name.c_str()), "'");
        }
        hot.failed = true;
        return nullptr;
    }
    
    CompiledFunc* func = emit_native(ir, alloc, chunk, name);
    if (!func) {
        if (jit_log && jit_log[0] == '1') {
            UtilityFunctions::print("[VG_JIT T2] emit failed '", String(name.c_str()), "'");
        }
        hot.failed = true;
        return nullptr;
    }
    
    func->global_slots = std::move(global_slots);
    func->total_slots = total_slots;
    func->slot_is_f64 = std::move(slot_is_f64);
    cache_[cache_key] = func;
    
    if (jit_log && jit_log[0] == '1') {
        UtilityFunctions::print("[VG_JIT T2] Compiled '", String(name.c_str()), "' → ",
                                (int)func->code_size, " bytes native x86-64 (",
                                (int)ir.size(), " IR ops, ", vreg_count, " vregs)");
    }
    
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
