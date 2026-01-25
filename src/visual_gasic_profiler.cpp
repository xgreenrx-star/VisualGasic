#include "visual_gasic_profiler.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <algorithm>
#include <sstream>
#include <iomanip>

#if defined(__AVX2__)
    #if defined(_MSC_VER)
        #include <intrin.h>
        #include <immintrin.h>
    #elif defined(__GNUC__) || defined(__clang__)
        #include <immintrin.h>
        #include <x86intrin.h>
    #endif
#endif

using namespace godot;

// ============================================================================
// VISUAL GASIC PROFILER IMPLEMENTATION
// ============================================================================

VisualGasicProfiler* VisualGasicProfiler::instance_ = nullptr;

VisualGasicProfiler& VisualGasicProfiler::getInstance() {
    if (!instance_) {
        instance_ = new VisualGasicProfiler();
    }
    return *instance_;
}

VisualGasicProfiler::VisualGasicProfiler() {
    memory_pool_ = std::make_unique<MemoryPool>();
    
    // Initialize common performance counters
    add_counter("parser.lines_parsed", "lines");
    add_counter("parser.tokens_generated", "tokens");
    add_counter("parser.parse_errors", "errors");
    add_counter("ast.nodes_created", "nodes");
    add_counter("ast.nodes_optimized", "nodes");
    add_counter("execution.functions_called", "calls");
    add_counter("execution.async_operations", "operations");
    add_counter("memory.allocations", "allocations");
    add_counter("memory.deallocations", "deallocations");
    add_counter("gpu.operations", "operations");
    add_counter("repl.evaluations", "evaluations");
    add_counter("jit.linear_sequences", "sequences");
    add_counter("jit.linear_ops", "ops");
    add_counter("jit.loop_optimizations", "optimizations");
    add_counter("jit.conditional_optimizations", "optimizations");
    add_counter("jit.math_optimizations", "optimizations");
    add_counter("jit.string_optimizations", "optimizations");
    add_counter("jit.array_optimizations", "optimizations");
}

void VisualGasicProfiler::start_profile(const std::string& name, const std::string& category) {
    if (!profiling_enabled_) return;
    
    auto it = profiles_.find(name);
    if (it == profiles_.end()) {
        profiles_[name] = std::make_unique<ProfileData>();
        profiles_[name]->name = name;
        profiles_[name]->category = category;
    }
    
    profiles_[name]->start_time = std::chrono::high_resolution_clock::now();
}

void VisualGasicProfiler::end_profile(const std::string& name) {
    if (!profiling_enabled_) return;
    
    auto end_time = std::chrono::high_resolution_clock::now();
    auto it = profiles_.find(name);
    if (it != profiles_.end()) {
        auto& profile = it->second;
        profile->end_time = end_time;
        
        auto duration = std::chrono::duration_cast<std::chrono::microseconds>(
            end_time - profile->start_time).count() / 1000.0; // Convert to milliseconds
        
        profile->call_count++;
        // std::atomic<double> doesn't support +=, use fetch_add pattern
        double current = profile->total_time_ms.load();
        while (!profile->total_time_ms.compare_exchange_weak(current, current + duration)) {}
        
        // Update min/max
        double current_min = profile->min_time_ms.load();
        while (duration < current_min && 
               !profile->min_time_ms.compare_exchange_weak(current_min, duration)) {}
        
        double current_max = profile->max_time_ms.load();
        while (duration > current_max && 
               !profile->max_time_ms.compare_exchange_weak(current_max, duration)) {}
    }
}

void VisualGasicProfiler::add_counter(const std::string& name, const std::string& unit) {
    if (counters_.find(name) == counters_.end()) {
        counters_[name] = std::make_unique<PerformanceCounter>();
        counters_[name]->name = name;
        counters_[name]->unit = unit;
    }
}

void VisualGasicProfiler::increment_counter(const std::string& name, double value) {
    auto it = counters_.find(name);
    if (it != counters_.end()) {
        it->second->count++;
        // std::atomic<double> doesn't support +=, use compare_exchange
        double current = it->second->value.load();
        while (!it->second->value.compare_exchange_weak(current, current + value)) {}
    }
}

void VisualGasicProfiler::set_counter(const std::string& name, double value) {
    auto it = counters_.find(name);
    if (it != counters_.end()) {
        it->second->value = value;
    }
}

Dictionary VisualGasicProfiler::get_performance_report() {
    Dictionary report;
    Dictionary profile_data;
    Dictionary counter_data;
    
    // Collect profile data
    for (const auto& [name, profile] : profiles_) {
        Dictionary prof_info;
        prof_info["name"] = String(profile->name.c_str());
        prof_info["category"] = String(profile->category.c_str());
        prof_info["call_count"] = (int64_t)profile->call_count.load();
        prof_info["total_time_ms"] = profile->total_time_ms.load();
        prof_info["avg_time_ms"] = profile->call_count.load() > 0 ? 
            profile->total_time_ms.load() / profile->call_count.load() : 0.0;
        prof_info["min_time_ms"] = profile->min_time_ms.load();
        prof_info["max_time_ms"] = profile->max_time_ms.load();
        
        profile_data[String(name.c_str())] = prof_info;
    }
    
    // Collect counter data
    for (const auto& [name, counter] : counters_) {
        Dictionary counter_info;
        counter_info["name"] = String(counter->name.c_str());
        counter_info["unit"] = String(counter->unit.c_str());
        counter_info["count"] = (int64_t)counter->count.load();
        counter_info["value"] = counter->value.load();
        
        counter_data[String(name.c_str())] = counter_info;
    }
    
    report["profiles"] = profile_data;
    report["counters"] = counter_data;
    report["memory_pool_utilization"] = memory_pool_->utilization();
    report["profiling_enabled"] = profiling_enabled_.load();
    
    return report;
}

void VisualGasicProfiler::print_performance_summary() {
    UtilityFunctions::print("=== VisualGasic Performance Summary ===");
    
    // Sort profiles by total time
    std::vector<std::pair<std::string, ProfileData*>> sorted_profiles;
    for (const auto& [name, profile] : profiles_) {
        sorted_profiles.emplace_back(name, profile.get());
    }
    
    std::sort(sorted_profiles.begin(), sorted_profiles.end(), 
        [](const auto& a, const auto& b) {
            return a.second->total_time_ms.load() > b.second->total_time_ms.load();
        });
    
    UtilityFunctions::print("Top Performance Hotspots:");
    for (size_t i = 0; i < std::min(sorted_profiles.size(), size_t(10)); ++i) {
        const auto& [name, profile] = sorted_profiles[i];
        double avg_time = profile->call_count.load() > 0 ? 
            profile->total_time_ms.load() / profile->call_count.load() : 0.0;
        
        UtilityFunctions::print(String("  ") + String(name.c_str()) + String(": ") + 
            String::num(profile->total_time_ms.load(), 2) + String("ms total (") +
            String::num(profile->call_count.load()) + String(" calls, ") +
            String::num(avg_time, 3) + String("ms avg)"));
    }
    
    UtilityFunctions::print("\nPerformance Counters:");
    for (const auto& [name, counter] : counters_) {
        if (counter->count.load() > 0) {
            UtilityFunctions::print(String("  ") + String(counter->name.c_str()) + String(": ") +
                String::num(counter->value.load()) + String(" ") + String(counter->unit.c_str()) + 
                String(" (") + String::num(counter->count.load()) + String(" updates)"));
        }
    }
    
    UtilityFunctions::print(String("Memory Pool Utilization: ") +
        String::num(memory_pool_->utilization() * 100.0, 1) + String("%"));
}

void VisualGasicProfiler::suggest_optimizations() {
    UtilityFunctions::print("=== Performance Optimization Suggestions ===");
    
    // Analyze hotspots and suggest optimizations
    for (const auto& [name, profile] : profiles_) {
        double avg_time = profile->call_count.load() > 0 ? 
            profile->total_time_ms.load() / profile->call_count.load() : 0.0;
        
        if (avg_time > 10.0) { // >10ms average
            UtilityFunctions::print(String("HOT PATH: ") + String(name.c_str()) + 
                String(" (") + String::num(avg_time, 2) + String("ms avg) - Consider optimization"));
                
            if (name.find("parser") != std::string::npos) {
                UtilityFunctions::print("  Try: AST node pooling, token caching");
            } else if (name.find("execution") != std::string::npos) {
                UtilityFunctions::print("  Try: JIT compilation, instruction caching");
            } else if (name.find("memory") != std::string::npos) {
                UtilityFunctions::print("  Try: Memory pool expansion, object pooling");
            }
        }
        
        if (profile->call_count.load() > 10000) { // Very frequent calls
            UtilityFunctions::print(String("FREQUENT: ") + String(name.c_str()) + 
                String(" (") + String::num(profile->call_count.load()) + String(" calls) - Consider caching"));
        }
    }
    
    // Memory optimization suggestions
    double pool_util = memory_pool_->utilization();
    if (pool_util > 0.8) {
        UtilityFunctions::print(String("MEMORY: Pool utilization high (") + 
            String::num(pool_util * 100.0, 1) + String("%) - Consider expansion"));
    } else if (pool_util < 0.2) {
        UtilityFunctions::print(String("MEMORY: Pool utilization low (") +
            String::num(pool_util * 100.0, 1) + String("%) - Consider reduction"));
    }
}

// ============================================================================
// MEMORY POOL IMPLEMENTATION
// ============================================================================

void* VisualGasicProfiler::MemoryPool::allocate(size_t bytes) {
    // Align to 8-byte boundary
    size_t aligned_bytes = (bytes + 7) & ~7;
    
    if (position + aligned_bytes > size) {
        return nullptr; // Pool exhausted
    }
    
    void* ptr = &buffer[position];
    position += aligned_bytes;
    allocated_bytes += aligned_bytes;
    return ptr;
}

void VisualGasicProfiler::MemoryPool::reset() {
    position = 0;
    allocated_bytes = 0;
}

double VisualGasicProfiler::MemoryPool::utilization() const {
    return static_cast<double>(allocated_bytes.load()) / size;
}

// ============================================================================
// STRING INTERNER IMPLEMENTATION  
// ============================================================================

uint32_t StringInterner::intern(const std::string& str) {
    auto it = string_to_id_.find(str);
    if (it != string_to_id_.end()) {
        return it->second;
    }
    
    uint32_t id = next_id_++;
    string_to_id_[str] = id;
    id_to_string_.push_back(str);
    return id;
}

const std::string& StringInterner::get_string(uint32_t id) const {
    static const std::string empty_string;
    if (id >= id_to_string_.size()) {
        return empty_string;
    }
    return id_to_string_[id];
}

void StringInterner::clear() {
    string_to_id_.clear();
    id_to_string_.clear();
    next_id_ = 0;
}

// ============================================================================
// OPTIMIZED AST STORE IMPLEMENTATION
// ============================================================================

uint32_t OptimizedASTStore::allocate_node(OptimizedASTNode::NodeType type, const std::string& name) {
    uint32_t node_id;
    
    if (!free_list_.empty()) {
        node_id = free_list_.back();
        free_list_.pop_back();
    } else {
        node_id = static_cast<uint32_t>(nodes_.size());
        nodes_.emplace_back();
    }
    
    auto& node = nodes_[node_id];
    node.type = type;
    node.string_id = name.empty() ? 0 : string_interner_.intern(name);
    
    return node_id;
}

void OptimizedASTStore::deallocate_node(uint32_t node_id) {
    if (node_id < nodes_.size()) {
        free_list_.push_back(node_id);
    }
}

OptimizedASTNode& OptimizedASTStore::get_node(uint32_t node_id) {
    return nodes_[node_id];
}

const OptimizedASTNode& OptimizedASTStore::get_node(uint32_t node_id) const {
    return nodes_[node_id];
}

void OptimizedASTStore::clear() {
    nodes_.clear();
    string_interner_.clear();
    free_list_.clear();
}

double OptimizedASTStore::memory_usage_mb() const {
    return (nodes_.size() * sizeof(OptimizedASTNode) + 
            string_interner_.size() * 64) / (1024.0 * 1024.0); // Rough estimate
}

Dictionary OptimizedASTStore::get_metrics() const {
    Dictionary metrics;
    metrics["total_nodes"] = (int64_t)nodes_.size();
    metrics["free_nodes"] = (int64_t)free_list_.size();
    metrics["active_nodes"] = (int64_t)(nodes_.size() - free_list_.size());
    metrics["interned_strings"] = (int64_t)string_interner_.size();
    metrics["memory_usage_mb"] = memory_usage_mb();
    return metrics;
}

// ============================================================================
// JIT OPTIMIZER IMPLEMENTATION
// ============================================================================

void JITOptimizer::add_hint(uint32_t node_id, JITHint hint) {
    node_hints_[node_id].push_back(hint);
}

void JITOptimizer::record_execution(uint32_t node_id) {
    execution_counts_[node_id]++;
}

std::vector<JITHint> JITOptimizer::get_hints(uint32_t node_id) const {
    auto it = node_hints_.find(node_id);
    if (it != node_hints_.end()) {
        return it->second;
    }
    return {};
}

bool JITOptimizer::is_hot_path(uint32_t node_id, uint64_t threshold) const {
    auto it = execution_counts_.find(node_id);
    return it != execution_counts_.end() && it->second >= threshold;
}

Dictionary JITOptimizer::get_optimization_report() const {
    Dictionary report;
    Dictionary hot_paths;
    Dictionary hint_summary;
    
    // Identify hot paths
    for (const auto& [node_id, count] : execution_counts_) {
        if (count >= 1000) { // Hot path threshold
            hot_paths[String::num(node_id)] = (int64_t)count;
        }
    }
    
    // Summarize hints
    std::unordered_map<JITHint, int> hint_counts;
    for (const auto& [node_id, hints] : node_hints_) {
        for (JITHint hint : hints) {
            hint_counts[hint]++;
        }
    }
    
    hint_summary["hot_path"] = hint_counts[JITHint::HOT_PATH];
    hint_summary["loop_intensive"] = hint_counts[JITHint::LOOP_INTENSIVE];
    hint_summary["math_intensive"] = hint_counts[JITHint::MATH_INTENSIVE];
    hint_summary["gpu_candidate"] = hint_counts[JITHint::GPU_CANDIDATE];
    
    report["hot_paths"] = hot_paths;
    report["hint_summary"] = hint_summary;
    return report;
}

// ============================================================================
// SIMD OPERATIONS IMPLEMENTATION
// ============================================================================

namespace SIMDOps {

void vector_add_f32(const float* a, const float* b, float* result, size_t count) {
#ifdef __AVX2__
    size_t simd_count = count & ~7; // Process 8 floats at a time
    for (size_t i = 0; i < simd_count; i += 8) {
        __m256 va = _mm256_load_ps(&a[i]);
        __m256 vb = _mm256_load_ps(&b[i]);
        __m256 vr = _mm256_add_ps(va, vb);
        _mm256_store_ps(&result[i], vr);
    }
    
    // Handle remaining elements
    for (size_t i = simd_count; i < count; ++i) {
        result[i] = a[i] + b[i];
    }
#else
    // Fallback implementation
    for (size_t i = 0; i < count; ++i) {
        result[i] = a[i] + b[i];
    }
#endif
}

void vector_mul_f32(const float* a, const float* b, float* result, size_t count) {
#ifdef __AVX2__
    size_t simd_count = count & ~7;
    for (size_t i = 0; i < simd_count; i += 8) {
        __m256 va = _mm256_load_ps(&a[i]);
        __m256 vb = _mm256_load_ps(&b[i]);
        __m256 vr = _mm256_mul_ps(va, vb);
        _mm256_store_ps(&result[i], vr);
    }
    
    for (size_t i = simd_count; i < count; ++i) {
        result[i] = a[i] * b[i];
    }
#else
    for (size_t i = 0; i < count; ++i) {
        result[i] = a[i] * b[i];
    }
#endif
}

bool fast_string_compare(const char* a, const char* b, size_t len) {
#ifdef __AVX2__
    if (len >= 32) {
        size_t simd_len = len & ~31; // 32-byte chunks
        for (size_t i = 0; i < simd_len; i += 32) {
            __m256i va = _mm256_loadu_si256(reinterpret_cast<const __m256i*>(&a[i]));
            __m256i vb = _mm256_loadu_si256(reinterpret_cast<const __m256i*>(&b[i]));
            __m256i cmp = _mm256_cmpeq_epi8(va, vb);
            if (_mm256_movemask_epi8(cmp) != 0xFFFFFFFF) {
                return false;
            }
        }
        
        // Handle remaining bytes
        return memcmp(a + simd_len, b + simd_len, len - simd_len) == 0;
    }
#endif
    return memcmp(a, b, len) == 0;
}

size_t fast_string_hash(const char* str, size_t len) {
    // FNV-1a hash with SIMD optimization potential
    size_t hash = 2166136261UL;
    for (size_t i = 0; i < len; ++i) {
        hash ^= static_cast<size_t>(str[i]);
        hash *= 16777619UL;
    }
    return hash;
}

void fast_memcopy(void* dst, const void* src, size_t size) {
#ifdef __AVX2__
    if (size >= 32 && ((uintptr_t)dst & 31) == 0 && ((uintptr_t)src & 31) == 0) {
        // Aligned AVX2 copy
        size_t simd_size = size & ~31;
        const __m256i* src_vec = reinterpret_cast<const __m256i*>(src);
        __m256i* dst_vec = reinterpret_cast<__m256i*>(dst);
        
        for (size_t i = 0; i < simd_size / 32; ++i) {
            _mm256_store_si256(&dst_vec[i], _mm256_load_si256(&src_vec[i]));
        }
        
        // Copy remaining bytes
        memcpy(static_cast<char*>(dst) + simd_size, 
               static_cast<const char*>(src) + simd_size, 
               size - simd_size);
        return;
    }
#endif
    memcpy(dst, src, size);
}

void fast_memset(void* ptr, int value, size_t size) {
#ifdef __AVX2__
    if (size >= 32) {
        __m256i val = _mm256_set1_epi8(static_cast<char>(value));
        size_t simd_size = size & ~31;
        
        for (size_t i = 0; i < simd_size; i += 32) {
            _mm256_storeu_si256(reinterpret_cast<__m256i*>(static_cast<char*>(ptr) + i), val);
        }
        
        // Handle remaining bytes
        memset(static_cast<char*>(ptr) + simd_size, value, size - simd_size);
        return;
    }
#endif
    memset(ptr, value, size);
}

} // namespace SIMDOps

// ============================================================================
// ASYNC BATCHER IMPLEMENTATION
// ============================================================================

void AsyncBatcher::enqueue_operation(std::function<void()> op, const std::string& category) {
    BatchedOperation batch_op;
    batch_op.operation = std::move(op);
    batch_op.enqueue_time = std::chrono::high_resolution_clock::now();
    batch_op.category = category;
    
    pending_operations_.push_back(std::move(batch_op));
    
    // Auto-process if batch is full or timeout exceeded
    if (pending_operations_.size() >= 10 || 
        std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::high_resolution_clock::now() - pending_operations_.front().enqueue_time) 
        >= batch_timeout_) {
        process_batch();
    }
}

void AsyncBatcher::process_batch() {
    if (processing_.exchange(true)) {
        return; // Already processing
    }
    
    std::vector<BatchedOperation> operations_to_process;
    operations_to_process.swap(pending_operations_);
    
    for (auto& op : operations_to_process) {
        op.operation();
    }
    
    processing_ = false;
}

void AsyncBatcher::set_batch_timeout(std::chrono::milliseconds timeout) {
    batch_timeout_ = timeout;
}

Dictionary AsyncBatcher::get_batch_stats() const {
    Dictionary stats;
    stats["pending_operations"] = (int64_t)pending_operations_.size();
    stats["processing"] = processing_.load();
    stats["batch_timeout_ms"] = (int64_t)batch_timeout_.count();
    return stats;
}