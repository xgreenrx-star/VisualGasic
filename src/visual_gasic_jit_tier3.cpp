// VisualGasic JIT Tier 3 — Call Graph Compilation
//
// Full implementation: call graph profiling, inlining decisions,
// IR merging, and native code emission via the Tier 2 pipeline.

#include "visual_gasic_jit_tier3.h"
#include <algorithm>
#include <cstring>
#include <cstdlib>
#include <unordered_set>

#ifdef __linux__
#include <sys/mman.h>
#include <unistd.h>
#endif
#ifdef __APPLE__
#include <sys/mman.h>
#include <unistd.h>
#include <libkern/OSCacheControl.h>
#endif

namespace vgjit3 {

// ═══════════════════════════════════════════════════════════════════
//  Helpers
// ═══════════════════════════════════════════════════════════════════

static int read_u16(const uint8_t* code, int ip) {
    return ((int)code[ip+1] << 8) | (int)code[ip];
}

// ═══════════════════════════════════════════════════════════════════
//  Thread-local Tier 3 Engine
// ═══════════════════════════════════════════════════════════════════

static thread_local Tier3 s_tier3;

Tier3& thread_jit3() { return s_tier3; }

// ═══════════════════════════════════════════════════════════════════
//  Tier3 Lifecycle
// ═══════════════════════════════════════════════════════════════════

Tier3::Tier3() {
    // Enable via VG_JIT=3 environment variable
    const char* env = std::getenv("VG_JIT");
    if (env) {
        int level = std::atoi(env);
        enabled_ = (level >= 3);
    }
}

Tier3::~Tier3() {
    for (auto& [name, unit] : fused_cache_) {
        if (unit) {
            delete unit->compiled;
            delete unit;
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
//  Call Graph Recording
// ═══════════════════════════════════════════════════════════════════

CallGraphNode& Tier3::get_or_create_node(const std::string& name) {
    auto it = graph_.find(name);
    if (it != graph_.end()) return it->second;
    auto& node = graph_[name];
    node.name = name;
    return node;
}

void Tier3::record_call(const std::string& caller, const std::string& callee) {
    if (!enabled_) return;

    auto& caller_node = get_or_create_node(caller);
    caller_node.is_leaf = false;

    // Update or insert edge
    bool found = false;
    for (auto& edge : caller_node.edges) {
        if (edge.callee == callee) {
            edge.count++;
            found = true;
            break;
        }
    }
    if (!found) {
        CallEdge e;
        e.callee = callee;
        e.count = 1;
        caller_node.edges.push_back(e);
    }

    // Increment callee's self-call counter
    auto& callee_node = get_or_create_node(callee);
    callee_node.self_calls++;
}

void Tier3::record_bytecode_size(const std::string& name, int bc_size) {
    if (!enabled_) return;
    get_or_create_node(name).bytecode_size = bc_size;
}

// ═══════════════════════════════════════════════════════════════════
//  Inlining Decisions
// ═══════════════════════════════════════════════════════════════════

std::vector<std::pair<std::string, int>>
Tier3::select_inline_candidates(const std::string& root, int depth) {
    std::vector<std::pair<std::string, int>> result;
    if (depth >= policy_.max_depth) return result;

    auto it = graph_.find(root);
    if (it == graph_.end()) return result;

    const auto& node = it->second;

    // Sort edges by frequency (descending) — inline hottest first
    std::vector<const CallEdge*> sorted_edges;
    for (const auto& e : node.edges) {
        sorted_edges.push_back(&e);
    }
    std::sort(sorted_edges.begin(), sorted_edges.end(),
              [](const CallEdge* a, const CallEdge* b) {
                  return a->count > b->count;
              });

    for (const auto* edge : sorted_edges) {
        if ((int)result.size() >= policy_.max_inline_count) break;
        if (edge->count < policy_.min_edge_calls) continue;

        // Check callee bytecode size
        auto callee_it = graph_.find(edge->callee);
        if (callee_it == graph_.end()) continue;
        if (callee_it->second.bytecode_size > policy_.max_callee_bc_size) continue;

        // Don't inline self-recursive calls
        if (edge->callee == root) continue;

        result.push_back({edge->callee, depth + 1});

        // Transitively inline callee's hot callees (if depth allows)
        if (depth + 1 < policy_.max_depth) {
            auto sub = select_inline_candidates(edge->callee, depth + 1);
            for (const auto& s : sub) {
                if ((int)result.size() >= policy_.max_inline_count) break;
                // Avoid duplicates
                bool dup = false;
                for (const auto& existing : result) {
                    if (existing.first == s.first) { dup = true; break; }
                }
                if (!dup) result.push_back(s);
            }
        }
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════
//  Opcode Size Helper (mirrors Tier 2 opcode advance table)
// ═══════════════════════════════════════════════════════════════════

static int opcode_size(uint8_t op) {
    switch (op) {
        // 1-byte opcodes
        case OP_POP: case OP_ADD: case OP_SUBTRACT: case OP_MULTIPLY:
        case OP_DIVIDE: case OP_NEGATE: case OP_CONCAT: case OP_MOD:
        case OP_INT_DIVIDE: case OP_POWER: case OP_NOT: case OP_AND:
        case OP_OR: case OP_XOR: case OP_EQUAL: case OP_NOT_EQUAL:
        case OP_GREATER: case OP_LESS: case OP_GREATER_EQUAL:
        case OP_LESS_EQUAL: case OP_NIL: case OP_TRUE: case OP_FALSE:
        case OP_PRINT: case OP_DEBUG_PRINT: case OP_RETURN: case OP_RETURN_VALUE:
        case OP_DUP: case OP_NEW_DICT: case OP_THROW:
        case OP_ADD_I64: case OP_SUB_I64: case OP_MUL_I64:
        case OP_ADD_F64: case OP_SUB_F64: case OP_MUL_F64: case OP_DIV_F64:
        case OP_EQUAL_I64: case OP_NOT_EQUAL_I64: case OP_LESS_EQUAL_I64:
        case OP_STOP: case OP_LIKE: case OP_LEN: case OP_ABS: case OP_SGN:
            return 1;
        // 2-byte opcodes
        case OP_GET_LOCAL: case OP_SET_LOCAL:
        case OP_INC_LOCAL_I64:
            return 2;
        // 3-byte opcodes
        case OP_CONSTANT: case OP_CONSTANT_LONG:
        case OP_GET_GLOBAL: case OP_SET_GLOBAL:
        case OP_ADD_I64_CONST: case OP_SUB_I64_CONST: case OP_MUL_I64_CONST:
        case OP_JUMP: case OP_JUMP_IF_FALSE: case OP_JUMP_IF_TRUE: case OP_LOOP:
        case OP_DEBUG_LINE:
            return 3;
        // 4-byte opcodes
        case OP_CALL:
            return 4;
        default:
            return 1; // conservative — bail will catch unsupported ops
    }
}

// ═══════════════════════════════════════════════════════════════════
//  Callee IR Lowering (rebase slots and labels)
// ═══════════════════════════════════════════════════════════════════

bool Tier3::lower_callee(BytecodeChunk* chunk,
                         std::vector<IRInst>& out_ir,
                         int& vreg_base,
                         int local_offset,
                         int label_offset) {
    // Simplified IR generation for the callee, matching Tier 2 encoding.
    // BytecodeChunk uses: Vector<uint8_t> code, Vector<Variant> constants.
    const uint8_t* bc = chunk->code.ptr();
    int bc_size = chunk->code.size();
    int vreg = vreg_base;
    int ip = 0;
    int label_count = 0;

    // Map bytecode offsets to label IDs for jump targets
    std::unordered_map<int, int> bc_to_label;

    // First pass: find all jump targets
    {
        int scan_ip = 0;
        while (scan_ip < bc_size) {
            uint8_t op = bc[scan_ip];
            switch (op) {
                case OP_JUMP:
                case OP_JUMP_IF_FALSE:
                case OP_JUMP_IF_TRUE: {
                    if (scan_ip + 3 <= bc_size) {
                        int offset = read_u16(bc, scan_ip + 1);
                        int target = scan_ip + 3 + offset;
                        if (bc_to_label.find(target) == bc_to_label.end()) {
                            bc_to_label[target] = label_count + label_offset;
                            label_count++;
                        }
                    }
                    scan_ip += 3;
                    break;
                }
                case OP_LOOP: {
                    if (scan_ip + 3 <= bc_size) {
                        int offset = read_u16(bc, scan_ip + 1);
                        int target = scan_ip + 3 - offset;
                        if (bc_to_label.find(target) == bc_to_label.end()) {
                            bc_to_label[target] = label_count + label_offset;
                            label_count++;
                        }
                    }
                    scan_ip += 3;
                    break;
                }
                default:
                    scan_ip += opcode_size(op);
                    break;
            }
        }
    }

    // Second pass: generate IR
    std::vector<int> value_stack;  // virtual registers on the value stack

    while (ip < bc_size) {
        // Emit label if this offset is a jump target
        if (bc_to_label.count(ip)) {
            IRInst lbl;
            lbl.op = IROp::LABEL;
            lbl.label_id = bc_to_label[ip];
            lbl.bc_offset = ip;
            out_ir.push_back(lbl);
        }

        uint8_t op = bc[ip];

        switch (op) {
            case OP_CONSTANT:
            case OP_CONSTANT_LONG: {
                int idx = read_u16(bc, ip + 1);
                ip += 3;
                if (idx < (int)chunk->constants.size()) {
                    godot::Variant v = chunk->constants[idx];
                    if (v.get_type() == godot::Variant::INT) {
                        IRInst inst;
                        inst.op = IROp::CONST_I64;
                        inst.type = IRType::I64;
                        inst.dest = vreg++;
                        inst.imm_i64 = (int64_t)v;
                        inst.bc_offset = ip - 3;
                        out_ir.push_back(inst);
                        value_stack.push_back(inst.dest);
                    } else if (v.get_type() == godot::Variant::FLOAT) {
                        IRInst inst;
                        inst.op = IROp::CONST_F64;
                        inst.type = IRType::F64;
                        inst.dest = vreg++;
                        inst.imm_f64 = (double)v;
                        inst.bc_offset = ip - 3;
                        out_ir.push_back(inst);
                        value_stack.push_back(inst.dest);
                    } else {
                        return false; // Non-numeric constant — bail
                    }
                } else {
                    return false;
                }
                break;
            }

            case OP_GET_LOCAL: {
                int slot = bc[ip + 1] + local_offset;
                ip += 2;
                IRInst inst;
                inst.op = IROp::LOAD_LOCAL;
                inst.type = IRType::I64;
                inst.dest = vreg++;
                inst.local_slot = slot;
                inst.bc_offset = ip - 2;
                out_ir.push_back(inst);
                value_stack.push_back(inst.dest);
                break;
            }

            case OP_SET_LOCAL: {
                int slot = bc[ip + 1] + local_offset;
                ip += 2;
                if (value_stack.empty()) { return false; }
                int val = value_stack.back(); value_stack.pop_back();
                IRInst inst;
                inst.op = IROp::STORE_LOCAL;
                inst.type = IRType::I64;
                inst.src1 = val;
                inst.local_slot = slot;
                inst.bc_offset = ip - 2;
                out_ir.push_back(inst);
                break;
            }

            case OP_ADD_I64: case OP_SUB_I64: case OP_MUL_I64: {
                ip += 1;
                if (value_stack.size() < 2) { return false; }
                int b = value_stack.back(); value_stack.pop_back();
                int a = value_stack.back(); value_stack.pop_back();
                IRInst inst;
                inst.op = (op == OP_ADD_I64) ? IROp::ADD_I64 :
                          (op == OP_SUB_I64) ? IROp::SUB_I64 : IROp::MUL_I64;
                inst.type = IRType::I64;
                inst.dest = vreg++;
                inst.src1 = a;
                inst.src2 = b;
                inst.bc_offset = ip - 1;
                out_ir.push_back(inst);
                value_stack.push_back(inst.dest);
                break;
            }

            case OP_ADD_I64_CONST: case OP_SUB_I64_CONST: case OP_MUL_I64_CONST: {
                int const_idx = read_u16(bc, ip + 1);
                ip += 3;
                if (value_stack.empty()) { return false; }
                if (const_idx >= (int)chunk->constants.size()) { return false; }
                int64_t imm = (int64_t)(godot::Variant)chunk->constants[const_idx];
                int a = value_stack.back(); value_stack.pop_back();
                IRInst inst;
                inst.op = (op == OP_ADD_I64_CONST) ? IROp::ADD_I64_CONST :
                          (op == OP_SUB_I64_CONST) ? IROp::SUB_I64_CONST :
                                                     IROp::MUL_I64_CONST;
                inst.type = IRType::I64;
                inst.dest = vreg++;
                inst.src1 = a;
                inst.imm_i64 = imm;
                inst.bc_offset = ip - 3;
                out_ir.push_back(inst);
                value_stack.push_back(inst.dest);
                break;
            }

            case OP_INC_LOCAL_I64: {
                int slot = bc[ip + 1] + local_offset;
                ip += 2;
                IRInst ld;
                ld.op = IROp::LOAD_LOCAL;
                ld.type = IRType::I64;
                ld.dest = vreg++;
                ld.local_slot = slot;
                out_ir.push_back(ld);

                IRInst inc;
                inc.op = IROp::INC_I64;
                inc.type = IRType::I64;
                inc.dest = vreg++;
                inc.src1 = ld.dest;
                out_ir.push_back(inc);

                IRInst st;
                st.op = IROp::STORE_LOCAL;
                st.type = IRType::I64;
                st.src1 = inc.dest;
                st.local_slot = slot;
                out_ir.push_back(st);
                break;
            }

            case OP_ADD_F64: case OP_SUB_F64: case OP_MUL_F64: case OP_DIV_F64: {
                ip += 1;
                if (value_stack.size() < 2) { return false; }
                int b = value_stack.back(); value_stack.pop_back();
                int a = value_stack.back(); value_stack.pop_back();
                IRInst inst;
                inst.op = (op == OP_ADD_F64) ? IROp::ADD_F64 :
                          (op == OP_SUB_F64) ? IROp::SUB_F64 :
                          (op == OP_MUL_F64) ? IROp::MUL_F64 : IROp::DIV_F64;
                inst.type = IRType::F64;
                inst.dest = vreg++;
                inst.src1 = a;
                inst.src2 = b;
                inst.bc_offset = ip - 1;
                out_ir.push_back(inst);
                value_stack.push_back(inst.dest);
                break;
            }

            case OP_JUMP:
            case OP_JUMP_IF_FALSE:
            case OP_JUMP_IF_TRUE:
            case OP_LOOP: {
                int offset = read_u16(bc, ip + 1);
                int target = (op == OP_LOOP) ? (ip + 3 - offset) : (ip + 3 + offset);
                ip += 3;

                IRInst inst;
                if (op == OP_JUMP || op == OP_LOOP) {
                    inst.op = IROp::JUMP;
                } else if (op == OP_JUMP_IF_FALSE) {
                    inst.op = IROp::JUMP_IF_FALSE;
                    if (!value_stack.empty()) {
                        inst.src1 = value_stack.back();
                        value_stack.pop_back();
                    }
                } else {
                    inst.op = IROp::JUMP_IF_TRUE;
                    if (!value_stack.empty()) {
                        inst.src1 = value_stack.back();
                        value_stack.pop_back();
                    }
                }
                inst.label_id = bc_to_label.count(target) ? bc_to_label[target] : -1;
                inst.bc_offset = ip - 3;
                out_ir.push_back(inst);
                break;
            }

            case OP_RETURN:
            case OP_RETURN_VALUE: {
                ip += 1;
                // For inlined functions, return becomes a jump to the inline exit label.
                // The caller will add the exit label after the inlined block.
                // For now, emit RET/RET_VALUE — the compile_fused step will fix it up.
                IRInst inst;
                if (op == OP_RETURN_VALUE && !value_stack.empty()) {
                    inst.op = IROp::RET_VALUE;
                    inst.src1 = value_stack.back();
                    value_stack.pop_back();
                } else {
                    inst.op = IROp::RET;
                }
                inst.bc_offset = ip - 1;
                out_ir.push_back(inst);
                break;
            }

            case OP_EQUAL_I64:
            case OP_NOT_EQUAL_I64:
            case OP_LESS_EQUAL_I64: {
                ip += 1;
                if (value_stack.size() < 2) { return false; }
                int b = value_stack.back(); value_stack.pop_back();
                int a = value_stack.back(); value_stack.pop_back();
                IRInst inst;
                inst.op = (op == OP_EQUAL_I64) ? IROp::EQ_I64 :
                          (op == OP_NOT_EQUAL_I64) ? IROp::NE_I64 : IROp::LE_I64;
                inst.type = IRType::BOOL;
                inst.dest = vreg++;
                inst.src1 = a;
                inst.src2 = b;
                out_ir.push_back(inst);
                value_stack.push_back(inst.dest);
                break;
            }

            case OP_POP: {
                ip += 1;
                if (!value_stack.empty()) value_stack.pop_back();
                break;
            }

            case OP_DUP: {
                ip += 1;
                if (value_stack.empty()) { return false; }
                int src = value_stack.back();
                IRInst inst;
                inst.op = IROp::MOV;
                inst.type = IRType::I64;
                inst.dest = vreg++;
                inst.src1 = src;
                out_ir.push_back(inst);
                value_stack.push_back(inst.dest);
                break;
            }

            case OP_NEGATE: {
                ip += 1;
                if (value_stack.empty()) { return false; }
                int src = value_stack.back(); value_stack.pop_back();
                IRInst inst;
                inst.op = IROp::NEG_I64;
                inst.type = IRType::I64;
                inst.dest = vreg++;
                inst.src1 = src;
                out_ir.push_back(inst);
                value_stack.push_back(inst.dest);
                break;
            }

            case OP_NIL: {
                ip += 1;
                IRInst inst;
                inst.op = IROp::CONST_ZERO;
                inst.type = IRType::I64;
                inst.dest = vreg++;
                out_ir.push_back(inst);
                value_stack.push_back(inst.dest);
                break;
            }

            case OP_TRUE: case OP_FALSE: {
                ip += 1;
                IRInst inst;
                inst.op = IROp::CONST_BOOL;
                inst.type = IRType::BOOL;
                inst.dest = vreg++;
                inst.imm_i64 = (op == OP_TRUE) ? 1 : 0;
                out_ir.push_back(inst);
                value_stack.push_back(inst.dest);
                break;
            }

            case OP_DEBUG_LINE: {
                // Skip debug line markers
                ip += 3;
                break;
            }

            default:
                // Unsupported opcode — cannot inline this callee
                return false;
        }
    }

    vreg_base = vreg;
    return true;
}

// ═══════════════════════════════════════════════════════════════════
//  Inline Expansion
// ═══════════════════════════════════════════════════════════════════

bool Tier3::expand_inline_sites(
    std::vector<IRInst>& root_ir,
    int& root_vreg_count,
    const std::vector<std::pair<std::string, int>>& candidates,
    ChunkResolver resolver, void* ctx,
    std::vector<InlineSite>& out_sites)
{
    // For each candidate, find CALL instructions in root_ir that match the callee
    // and replace them with the inlined IR.
    //
    // Since Tier 2 doesn't emit OP_CALL IR (it bails on unsupported ops),
    // Tier 3 inlining currently operates at the bytecode level during the
    // initial IR lowering phase rather than as a post-pass. The merged IR
    // is built directly in compile_fused().
    //
    // This method serves as a validation pass to ensure candidates are viable.
    
    for (const auto& [callee_name, depth] : candidates) {
        BytecodeChunk* chunk = resolver(callee_name, ctx);
        if (!chunk) continue;
        
        // Verify callee can be lowered to IR
        std::vector<IRInst> test_ir;
        int test_vreg = root_vreg_count;
        int l_offset = 0; // will be set properly in compile_fused
        int lb_offset = 0;

        if (!lower_callee(chunk, test_ir, test_vreg, l_offset, lb_offset)) {
            // Callee contains unsupported opcodes — skip
            continue;
        }
        
        InlineSite site;
        site.callee_name = callee_name;
        site.ir_start = 0;
        site.ir_end = (int)test_ir.size();
        site.local_offset = 0;
        site.label_offset = 0;
        out_sites.push_back(site);
    }
    
    return !out_sites.empty();
}

// ═══════════════════════════════════════════════════════════════════
//  Fused Compilation Pipeline
// ═══════════════════════════════════════════════════════════════════

FusedUnit* Tier3::compile_fused(const std::string& root,
                                ChunkResolver resolver, void* ctx) {
    BytecodeChunk* root_chunk = resolver(root, ctx);
    if (!root_chunk) return nullptr;
    
    // Select candidates for inlining
    auto candidates = select_inline_candidates(root);
    if (candidates.empty()) return nullptr;  // Nothing to inline — Tier 2 is sufficient
    
    FusedUnit* unit = new FusedUnit();
    unit->root_name = root;
    
    int vreg_count = 0;
    int label_count = 0;
    int local_count = root_chunk->local_count;
    
    // Lower root function to IR
    {
        std::vector<IRInst> root_ir;
        int vreg = 0;
        if (!lower_callee(root_chunk, root_ir, vreg, 0, 0)) {
            delete unit;
            return nullptr;
        }
        unit->merged_ir = std::move(root_ir);
        vreg_count = vreg;
        
        // Count labels in root IR
        for (const auto& inst : unit->merged_ir) {
            if (inst.op == IROp::LABEL && inst.label_id >= label_count) {
                label_count = inst.label_id + 1;
            }
            if ((inst.op == IROp::JUMP || inst.op == IROp::JUMP_IF_FALSE || inst.op == IROp::JUMP_IF_TRUE)
                && inst.label_id >= label_count) {
                label_count = inst.label_id + 1;
            }
        }
    }
    
    // Lower each callee and append to merged IR with offset slots/labels
    for (const auto& [callee_name, depth] : candidates) {
        BytecodeChunk* callee_chunk = resolver(callee_name, ctx);
        if (!callee_chunk) continue;
        
        int callee_local_offset = local_count;
        int callee_label_offset = label_count;
        
        std::vector<IRInst> callee_ir;
        int callee_vreg = vreg_count;
        if (!lower_callee(callee_chunk, callee_ir, callee_vreg,
                          callee_local_offset, callee_label_offset)) {
            continue;  // Skip callees that can't be lowered
        }
        
        InlineSite site;
        site.callee_name = callee_name;
        site.ir_start = (int)unit->merged_ir.size();
        site.local_offset = callee_local_offset;
        site.label_offset = callee_label_offset;
        
        // Add entry label for the inlined callee
        IRInst entry_label;
        entry_label.op = IROp::LABEL;
        entry_label.label_id = label_count++;
        unit->merged_ir.push_back(entry_label);
        
        // Replace RET/RET_VALUE in callee IR with jumps to exit label
        int exit_label = label_count++;
        for (auto& inst : callee_ir) {
            if (inst.op == IROp::RET || inst.op == IROp::RET_VALUE) {
                inst.op = IROp::JUMP;
                inst.label_id = exit_label;
            }
        }
        
        // Append callee IR
        unit->merged_ir.insert(unit->merged_ir.end(), callee_ir.begin(), callee_ir.end());
        
        // Exit label
        IRInst exit;
        exit.op = IROp::LABEL;
        exit.label_id = exit_label;
        unit->merged_ir.push_back(exit);
        
        site.ir_end = (int)unit->merged_ir.size();
        unit->inline_sites.push_back(site);
        unit->inlined.push_back(callee_name);
        
        // Update counts
        int callee_labels = 0;
        for (const auto& inst : callee_ir) {
            if (inst.op == IROp::LABEL && inst.label_id >= label_count) {
                label_count = inst.label_id + 1;
            }
        }
        label_count = std::max(label_count, callee_label_offset + callee_labels + 2);
        vreg_count = callee_vreg;
        local_count += callee_chunk->local_count;
    }
    
    unit->total_vregs = vreg_count;
    unit->total_locals = local_count;
    
    // Verify merged IR doesn't exceed policy limit
    if ((int)unit->merged_ir.size() > policy_.max_merged_ir) {
        delete unit;
        return nullptr;
    }
    
    // Run register allocation over the merged IR
    RegAlloc alloc;

    // Build live ranges for merged IR
    alloc.ranges.clear();
    alloc.spill_bytes = 0;
    
    std::unordered_map<int, int> vreg_to_range;
    for (int i = 0; i < (int)unit->merged_ir.size(); i++) {
        const auto& inst = unit->merged_ir[i];
        
        auto touch = [&](int vr, IRType type) {
            if (vr < 0) return;
            auto it = vreg_to_range.find(vr);
            if (it == vreg_to_range.end()) {
                LiveRange lr;
                lr.vreg = vr;
                lr.first_use = i;
                lr.last_use = i;
                lr.type = type;
                vreg_to_range[vr] = (int)alloc.ranges.size();
                alloc.ranges.push_back(lr);
            } else {
                alloc.ranges[it->second].last_use = i;
            }
        };
        
        if (inst.dest >= 0) touch(inst.dest, inst.type);
        if (inst.src1 >= 0) touch(inst.src1, inst.type);
        if (inst.src2 >= 0) touch(inst.src2, inst.type);
    }
    
    // Simple linear-scan register allocation
    // Available integer registers (callee-saved: rbx, r12-r15; caller-saved: rax, rcx, rdx, r8-r11)
    // We avoid RSP, RBP, RDI (locals pointer), RSI
    std::vector<Reg> free_int_regs = {
        Reg::RAX, Reg::RCX, Reg::RDX, Reg::R8, Reg::R9, Reg::R10, Reg::R11,
        Reg::RBX, Reg::R12, Reg::R13, Reg::R14, Reg::R15
    };
    std::vector<Reg> free_fp_regs = {
        Reg::XMM0, Reg::XMM1, Reg::XMM2, Reg::XMM3,
        Reg::XMM4, Reg::XMM5, Reg::XMM6, Reg::XMM7
    };
    
    // Sort by first use
    std::sort(alloc.ranges.begin(), alloc.ranges.end(),
              [](const LiveRange& a, const LiveRange& b) {
                  return a.first_use < b.first_use;
              });
    
    // Linear scan
    struct Active { int range_idx; Reg reg; int end; };
    std::vector<Active> active;
    int spill_offset = 0;
    
    for (int ri = 0; ri < (int)alloc.ranges.size(); ri++) {
        auto& lr = alloc.ranges[ri];
        
        // Expire old intervals
        active.erase(std::remove_if(active.begin(), active.end(),
            [&](const Active& a) {
                if (alloc.ranges[a.range_idx].last_use < lr.first_use) {
                    // Return register
                    if (alloc.ranges[a.range_idx].type == IRType::F64) {
                        free_fp_regs.push_back(a.reg);
                    } else {
                        free_int_regs.push_back(a.reg);
                    }
                    return true;
                }
                return false;
            }), active.end());
        
        // Allocate register
        bool is_fp = (lr.type == IRType::F64);
        auto& pool = is_fp ? free_fp_regs : free_int_regs;
        
        if (!pool.empty()) {
            lr.assigned = pool.back();
            pool.pop_back();
            active.push_back({ri, lr.assigned, lr.last_use});
        } else {
            // Spill
            lr.assigned = Reg::SPILL;
            spill_offset += 8;
            lr.spill_offset = spill_offset;
        }
    }
    alloc.spill_bytes = spill_offset;
    
    // Emit native code using the Tier 2 assembler
    CodeBuf code;
    code.prologue(alloc.spill_bytes);
    
    // Pre-allocate labels
    for (int i = 0; i < label_count; i++) {
        code.new_label();
    }
    
    auto reg_for = [&](int vreg) -> Reg {
        for (const auto& lr : alloc.ranges) {
            if (lr.vreg == vreg) return lr.assigned;
        }
        return Reg::NONE;
    };
    
    // Emit instructions
    for (const auto& inst : unit->merged_ir) {
        switch (inst.op) {
            case IROp::LABEL:
                code.bind_label(inst.label_id);
                break;
                
            case IROp::CONST_I64: {
                Reg dst = reg_for(inst.dest);
                if (dst != Reg::NONE && dst != Reg::SPILL) {
                    code.mov_ri64(dst, inst.imm_i64);
                }
                break;
            }
            
            case IROp::CONST_ZERO: {
                Reg dst = reg_for(inst.dest);
                if (dst != Reg::NONE && dst != Reg::SPILL) {
                    // xor reg, reg → zero
                    code.mov_ri64(dst, 0);
                }
                break;
            }
            
            case IROp::CONST_BOOL: {
                Reg dst = reg_for(inst.dest);
                if (dst != Reg::NONE && dst != Reg::SPILL) {
                    code.mov_ri64(dst, inst.imm_i64);
                }
                break;
            }
            
            case IROp::LOAD_LOCAL: {
                Reg dst = reg_for(inst.dest);
                if (dst != Reg::NONE && dst != Reg::SPILL) {
                    code.load_local_i64(dst, inst.local_slot);
                }
                break;
            }
            
            case IROp::STORE_LOCAL: {
                Reg src = reg_for(inst.src1);
                if (src != Reg::NONE && src != Reg::SPILL) {
                    code.store_local_i64(inst.local_slot, src);
                }
                break;
            }
            
            case IROp::ADD_I64: case IROp::SUB_I64: case IROp::MUL_I64: {
                Reg dst = reg_for(inst.dest);
                Reg s1 = reg_for(inst.src1);
                Reg s2 = reg_for(inst.src2);
                if (dst == Reg::NONE || dst == Reg::SPILL) break;
                if (s1 == Reg::NONE || s1 == Reg::SPILL) break;
                if (s2 == Reg::NONE || s2 == Reg::SPILL) break;
                
                if (dst != s1) code.mov_rr(dst, s1);
                if (inst.op == IROp::ADD_I64) code.add_rr(dst, s2);
                else if (inst.op == IROp::SUB_I64) code.sub_rr(dst, s2);
                else code.imul_rr(dst, s2);
                break;
            }
            
            case IROp::INC_I64: {
                Reg dst = reg_for(inst.dest);
                Reg src = reg_for(inst.src1);
                if (dst == Reg::NONE || dst == Reg::SPILL) break;
                if (src == Reg::NONE || src == Reg::SPILL) break;
                if (dst != src) code.mov_rr(dst, src);
                code.inc_r(dst);
                break;
            }
            
            case IROp::NEG_I64: {
                Reg dst = reg_for(inst.dest);
                Reg src = reg_for(inst.src1);
                if (dst == Reg::NONE || dst == Reg::SPILL) break;
                if (src == Reg::NONE || src == Reg::SPILL) break;
                if (dst != src) code.mov_rr(dst, src);
                code.neg_r(dst);
                break;
            }
            
            case IROp::EQ_I64: case IROp::NE_I64: case IROp::LE_I64: {
                Reg dst = reg_for(inst.dest);
                Reg s1 = reg_for(inst.src1);
                Reg s2 = reg_for(inst.src2);
                if (dst == Reg::NONE || dst == Reg::SPILL) break;
                if (s1 == Reg::NONE || s1 == Reg::SPILL) break;
                if (s2 == Reg::NONE || s2 == Reg::SPILL) break;
                
                code.cmp_rr(s1, s2);
                if (inst.op == IROp::EQ_I64) code.sete(dst);
                else if (inst.op == IROp::NE_I64) code.setne(dst);
                else code.setle(dst);
                break;
            }
            
            case IROp::JUMP:
                if (inst.label_id >= 0) code.jmp_label(inst.label_id);
                break;
                
            case IROp::JUMP_IF_FALSE: {
                Reg src = reg_for(inst.src1);
                if (src != Reg::NONE && src != Reg::SPILL) {
                    code.test_rr(src, src);
                    code.je_label(inst.label_id);
                }
                break;
            }
            
            case IROp::JUMP_IF_TRUE: {
                Reg src = reg_for(inst.src1);
                if (src != Reg::NONE && src != Reg::SPILL) {
                    code.test_rr(src, src);
                    code.jne_label(inst.label_id);
                }
                break;
            }
            
            case IROp::RET:
                code.epilogue();
                break;
                
            case IROp::RET_VALUE: {
                Reg src = reg_for(inst.src1);
                if (src != Reg::NONE && src != Reg::SPILL && src != Reg::RAX) {
                    code.mov_rr(Reg::RAX, src);
                }
                code.epilogue();
                break;
            }
            
            case IROp::NOP:
                break;
                
            default:
                // Unsupported IR op — bail
                delete unit;
                return nullptr;
        }
    }
    
    // Resolve jump fixups
    if (!code.resolve()) {
        delete unit;
        return nullptr;
    }
    
    // Allocate executable memory and copy code
    size_t code_size = code.code_size();
    if (code_size == 0) {
        delete unit;
        return nullptr;
    }
    
#if defined(__linux__) || defined(__APPLE__)
    void* mem = mmap(nullptr, code_size, PROT_READ | PROT_WRITE,
                     MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (mem == MAP_FAILED) {
        delete unit;
        return nullptr;
    }
    std::memcpy(mem, code.code().data(), code_size);
    mprotect(mem, code_size, PROT_READ | PROT_EXEC);
    
#ifdef __APPLE__
    sys_icache_invalidate(mem, code_size);
#endif
    
    CompiledFunc* cf = new CompiledFunc();
    cf->code_mem = mem;
    cf->code_size = code_size;
    cf->fn = (CompiledFunc::FnPtr)mem;
    cf->name = root + "+inlined";
    cf->total_slots = local_count;
    
    unit->compiled = cf;
    return unit;
#else
    // Platform not supported for JIT
    delete unit;
    return nullptr;
#endif
}

// ═══════════════════════════════════════════════════════════════════
//  Public API
// ═══════════════════════════════════════════════════════════════════

CompiledFunc* Tier3::get_or_compile(const std::string& root,
                                    ChunkResolver resolver, void* ctx) {
    if (!enabled_) return nullptr;
    
    // Check cache
    auto cache_it = fused_cache_.find(root);
    if (cache_it != fused_cache_.end()) {
        if (cache_it->second && cache_it->second->compiled) {
            cache_it->second->compiled->exec_count++;
            return cache_it->second->compiled;
        }
        return nullptr;  // Previously attempted and failed
    }
    
    // Check if we have enough call data
    auto graph_it = graph_.find(root);
    if (graph_it == graph_.end()) return nullptr;
    
    const auto& node = graph_it->second;
    if (node.self_calls < HOT_CHAIN_THRESHOLD) return nullptr;
    
    // Check if any edge is hot enough
    bool has_hot_edge = false;
    for (const auto& edge : node.edges) {
        if (edge.count >= policy_.min_edge_calls) {
            has_hot_edge = true;
            break;
        }
    }
    if (!has_hot_edge) return nullptr;
    
    // Check if already attempted
    auto& info = compile_info_[root];
    if (info.attempted) return nullptr;
    info.attempted = true;
    
    // Evict oldest entry if cache is full
    if (fused_cache_.size() >= MAX_FUSED_CACHE) {
        // Evict least-executed
        std::string evict_name;
        uint64_t min_exec = UINT64_MAX;
        for (const auto& [name, unit] : fused_cache_) {
            if (unit && unit->compiled && unit->compiled->exec_count < min_exec) {
                min_exec = unit->compiled->exec_count;
                evict_name = name;
            }
        }
        if (!evict_name.empty()) {
            auto* old = fused_cache_[evict_name];
            if (old) {
                delete old->compiled;
                delete old;
            }
            fused_cache_.erase(evict_name);
        }
    }
    
    // Compile
    FusedUnit* unit = compile_fused(root, resolver, ctx);
    fused_cache_[root] = unit;
    
    if (unit && unit->compiled) {
        info.succeeded = true;
        return unit->compiled;
    }
    
    return nullptr;
}

int Tier3::total_inlined() const {
    int total = 0;
    for (const auto& [name, unit] : fused_cache_) {
        if (unit) total += (int)unit->inlined.size();
    }
    return total;
}

} // namespace vgjit3
