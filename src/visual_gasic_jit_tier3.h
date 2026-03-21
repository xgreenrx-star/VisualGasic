#ifndef VISUAL_GASIC_JIT_TIER3_H
#define VISUAL_GASIC_JIT_TIER3_H

// VisualGasic JIT Tier 3 — Call Graph Compilation
//
// Extends Tier 2 (function body native code) to compile entire call graphs:
//   • Tracks caller→callee call frequencies
//   • Identifies hot call chains via edge profiling
//   • Inlines small hot callees into the caller's IR
//   • Inter-procedural register allocation over combined IR
//   • Emits a single native code blob for the fused graph
//
// Pipeline:
//   Edge profiling → hot chain detection → callee IR extraction →
//   inline expansion → combined reg alloc → x86-64 emission
//
// Integration:
//   When a function compiled by Tier 2 calls another Tier-2 compiled function
//   frequently enough, Tier 3 fuses them into a single compiled unit.

#include "visual_gasic_jit_tier2.h"
#include "visual_gasic_bytecode.h"
#include <string>
#include <vector>
#include <unordered_map>
#include <cstdint>

namespace vgjit3 {

using namespace vgjit2;

// ═══════════════════════════════════════════════════════════════════
//  Call Graph Structures
// ═══════════════════════════════════════════════════════════════════

/// Directed edge in the call graph (caller → callee + frequency).
struct CallEdge {
    std::string callee;
    uint64_t    count = 0;
};

/// Node in the call graph with outgoing edges.
struct CallGraphNode {
    std::string         name;
    uint64_t            self_calls   = 0;   // how many times this function was invoked
    std::vector<CallEdge> edges;            // outgoing call edges
    int                 bytecode_size = 0;  // size in bytes of the function's bytecode
    bool                is_leaf       = true;
};

/// Represents a callee inlined into a caller's IR stream.
struct InlineSite {
    std::string callee_name;
    int         ir_start;        // index into merged IR where inlined body begins
    int         ir_end;          // index past last inlined instruction
    int         local_offset;    // base offset added to callee's local slots
    int         label_offset;    // base offset added to callee's label IDs
};

/// A fused compilation unit: one or more functions merged.
struct FusedUnit {
    std::string root_name;                       // root (outermost) function
    std::vector<std::string> inlined;            // names of inlined callees
    std::vector<InlineSite> inline_sites;
    std::vector<IRInst> merged_ir;               // combined IR
    int total_vregs  = 0;
    int total_locals = 0;
    CompiledFunc* compiled = nullptr;            // resulting native code
};

// ═══════════════════════════════════════════════════════════════════
//  Inlining Heuristics
// ═══════════════════════════════════════════════════════════════════

struct InlinePolicy {
    /// Maximum bytecode bytes for a callee to be eligible for inlining.
    int max_callee_bc_size = 128;

    /// Minimum call-edge count before considering inlining.
    uint64_t min_edge_calls = 50;

    /// Maximum inlining depth (recursive / transitive).
    int max_depth = 3;

    /// Maximum total IR instructions after merging.
    int max_merged_ir = 2048;

    /// Maximum number of functions inlined into a single root.
    int max_inline_count = 8;
};

// ═══════════════════════════════════════════════════════════════════
//  JIT Tier 3 Engine
// ═══════════════════════════════════════════════════════════════════

class Tier3 {
public:
    static constexpr uint64_t HOT_CHAIN_THRESHOLD = 100;
    static constexpr size_t   MAX_FUSED_CACHE = 32;

    Tier3();
    ~Tier3();

    bool enabled() const { return enabled_; }

    // ── Call Graph Recording ───────────────────────────────────────
    /// Record one call from `caller` to `callee`.
    void record_call(const std::string& caller, const std::string& callee);

    /// Record bytecode size for a function (called at first compile).
    void record_bytecode_size(const std::string& name, int bc_size);

    // ── Compilation ────────────────────────────────────────────────
    /// Check if a hot call chain exists for `root` and compile it.
    /// Returns the fused compiled function if ready, else nullptr.
    /// `resolve_chunk` is a callback to look up BytecodeChunk* by name.
    typedef BytecodeChunk* (*ChunkResolver)(const std::string& name, void* ctx);
    CompiledFunc* get_or_compile(const std::string& root,
                                 ChunkResolver resolver, void* ctx);

    // ── Stats ──────────────────────────────────────────────────────
    int fused_count()  const { return (int)fused_cache_.size(); }
    int total_inlined() const;
    const std::unordered_map<std::string, CallGraphNode>& call_graph() const { return graph_; }

    // ── Configuration ──────────────────────────────────────────────
    InlinePolicy& policy() { return policy_; }

private:
    bool enabled_ = false;
    InlinePolicy policy_;

    // Call graph
    std::unordered_map<std::string, CallGraphNode> graph_;

    // Compilation tracking
    struct CompileInfo {
        bool attempted = false;
        bool succeeded = false;
    };
    std::unordered_map<std::string, CompileInfo> compile_info_;

    // Fused compilation cache
    std::unordered_map<std::string, FusedUnit*> fused_cache_;

    // ── Internal ───────────────────────────────────────────────────
    CallGraphNode& get_or_create_node(const std::string& name);

    /// Identify callees to inline for `root`, respecting the policy.
    /// Returns an ordered list of (callee_name, depth) to inline.
    std::vector<std::pair<std::string, int>>
    select_inline_candidates(const std::string& root, int depth = 0);

    /// Lower a callee's bytecode to IR, adjusting slots/labels.
    bool lower_callee(BytecodeChunk* chunk,
                      std::vector<IRInst>& out_ir,
                      int& vreg_base,
                      int local_offset,
                      int label_offset);

    /// Replace OP_CALL sites in the root IR with inlined IR.
    bool expand_inline_sites(std::vector<IRInst>& root_ir,
                             int& root_vreg_count,
                             const std::vector<std::pair<std::string, int>>& candidates,
                             ChunkResolver resolver, void* ctx,
                             std::vector<InlineSite>& out_sites);

    /// Full pipeline: build merged IR → register alloc → emit native.
    FusedUnit* compile_fused(const std::string& root,
                             ChunkResolver resolver, void* ctx);
};

/// Per-thread Tier 3 engine.
Tier3& thread_jit3();

} // namespace vgjit3

#endif // VISUAL_GASIC_JIT_TIER3_H
