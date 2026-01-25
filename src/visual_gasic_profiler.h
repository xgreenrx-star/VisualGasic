#pragma once

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include <chrono>
#include <unordered_map>
#include <string>
#include <vector>
#include <memory>
#include <functional>
#include <atomic>

using namespace godot;

// Performance profiler for VisualGasic critical paths
class VisualGasicProfiler {
public:
    struct ProfileData {
        std::chrono::high_resolution_clock::time_point start_time;
        std::chrono::high_resolution_clock::time_point end_time;
        std::string name;
        std::string category;
        Dictionary metadata;
        std::atomic<uint64_t> call_count{0};
        std::atomic<double> total_time_ms{0.0};
        std::atomic<double> min_time_ms{std::numeric_limits<double>::max()};
        std::atomic<double> max_time_ms{0.0};
    };

    struct PerformanceCounter {
        std::atomic<uint64_t> count{0};
        std::atomic<double> value{0.0};
        std::string name;
        std::string unit;
    };

    // Memory pool for fast allocation
    struct MemoryPool {
        std::vector<uint8_t> buffer;
        size_t position;
        size_t size;
        std::atomic<size_t> allocated_bytes{0};
        
        MemoryPool(size_t pool_size = 1024 * 1024) : // 1MB default
            buffer(pool_size), position(0), size(pool_size) {}
        
        void* allocate(size_t bytes);
        void reset();
        double utilization() const;
    };

private:
    static VisualGasicProfiler* instance_;
    std::unordered_map<std::string, std::unique_ptr<ProfileData>> profiles_;
    std::unordered_map<std::string, std::unique_ptr<PerformanceCounter>> counters_;
    std::unique_ptr<MemoryPool> memory_pool_;
    std::atomic<bool> profiling_enabled_{true};
    std::atomic<bool> detailed_profiling_{false};

public:
    static VisualGasicProfiler& getInstance();
    
    // Core profiling functions
    void start_profile(const std::string& name, const std::string& category = "general");
    void end_profile(const std::string& name);
    void add_counter(const std::string& name, const std::string& unit = "count");
    void increment_counter(const std::string& name, double value = 1.0);
    void set_counter(const std::string& name, double value);
    
    // Configuration
    void enable_profiling(bool enabled) { profiling_enabled_ = enabled; }
    void enable_detailed_profiling(bool enabled) { detailed_profiling_ = enabled; }
    bool is_profiling_enabled() const { return profiling_enabled_; }
    
    // Memory management
    MemoryPool& get_memory_pool() { return *memory_pool_; }
    void reset_memory_pool();
    
    // Reporting
    Dictionary get_performance_report();
    Dictionary get_memory_report();
    void print_performance_summary();
    void export_profile_data(const String& filename);
    
    // Optimization hints
    void suggest_optimizations();
    
    VisualGasicProfiler();
    ~VisualGasicProfiler() = default;
};

// RAII profiler helper
class ScopedProfiler {
private:
    std::string profile_name_;
    
public:
    ScopedProfiler(const std::string& name, const std::string& category = "general") 
        : profile_name_(name) {
        VisualGasicProfiler::getInstance().start_profile(name, category);
    }
    
    ~ScopedProfiler() {
        VisualGasicProfiler::getInstance().end_profile(profile_name_);
    }
};

// Helper macro to generate unique variable names
#define VG_PROFILE_CONCAT_IMPL(x, y) x##y
#define VG_PROFILE_CONCAT(x, y) VG_PROFILE_CONCAT_IMPL(x, y)
#define VG_PROFILE_VAR(base) VG_PROFILE_CONCAT(base, __LINE__)

// Convenience macros - each uses unique variable name based on line number
#define VG_PROFILE(name) ScopedProfiler VG_PROFILE_VAR(_prof_)(name)
#define VG_PROFILE_CATEGORY(name, category) ScopedProfiler VG_PROFILE_VAR(_prof_cat_)(name, category)
#define VG_PROFILE_FUNCTION() ScopedProfiler VG_PROFILE_VAR(_prof_fn_)(__FUNCTION__)
#define VG_COUNT(name) VisualGasicProfiler::getInstance().increment_counter(name)
#define VG_COUNT_VALUE(name, value) VisualGasicProfiler::getInstance().increment_counter(name, value)
#define VG_SET_COUNTER(name, value) VisualGasicProfiler::getInstance().set_counter(name, value)

// Fast string interning for performance
class StringInterner {
private:
    std::unordered_map<std::string, uint32_t> string_to_id_;
    std::vector<std::string> id_to_string_;
    uint32_t next_id_;

public:
    StringInterner() : next_id_(0) {}
    
    uint32_t intern(const std::string& str);
    const std::string& get_string(uint32_t id) const;
    size_t size() const { return id_to_string_.size(); }
    void clear();
};

// Cache-friendly AST node optimization
struct OptimizedASTNode {
    enum NodeType : uint8_t {
        EXPRESSION,
        STATEMENT, 
        FUNCTION_CALL,
        VARIABLE_ACCESS,
        LITERAL,
        BINARY_OP,
        UNARY_OP,
        BLOCK
    };
    
    NodeType type;
    uint32_t string_id;  // Interned string for names
    union {
        struct {
            uint32_t left_child;
            uint32_t right_child;
        } binary;
        struct {
            uint32_t child;
        } unary;
        struct {
            uint32_t first_child;
            uint32_t child_count;
        } block;
        double number_value;
        bool boolean_value;
    } data;
    
    Dictionary metadata;  // For additional data as needed
};

// High-performance AST storage
class OptimizedASTStore {
private:
    std::vector<OptimizedASTNode> nodes_;
    StringInterner string_interner_;
    std::vector<uint32_t> free_list_;

public:
    uint32_t allocate_node(OptimizedASTNode::NodeType type, const std::string& name = "");
    void deallocate_node(uint32_t node_id);
    OptimizedASTNode& get_node(uint32_t node_id);
    const OptimizedASTNode& get_node(uint32_t node_id) const;
    
    void clear();
    size_t size() const { return nodes_.size(); }
    double memory_usage_mb() const;
    
    // Performance metrics
    Dictionary get_metrics() const;
};

// JIT compilation hints
enum class JITHint {
    HOT_PATH,           // Frequently executed code
    COLD_PATH,          // Rarely executed code
    LOOP_INTENSIVE,     // Contains tight loops
    MATH_INTENSIVE,     // Heavy arithmetic operations
    IO_INTENSIVE,       // I/O operations
    MEMORY_INTENSIVE,   // Heavy memory allocation
    GPU_CANDIDATE       // Good for GPU acceleration
};

class JITOptimizer {
private:
    std::unordered_map<uint32_t, std::vector<JITHint>> node_hints_;
    std::unordered_map<uint32_t, uint64_t> execution_counts_;

public:
    void add_hint(uint32_t node_id, JITHint hint);
    void record_execution(uint32_t node_id);
    std::vector<JITHint> get_hints(uint32_t node_id) const;
    bool is_hot_path(uint32_t node_id, uint64_t threshold = 1000) const;
    
    Dictionary get_optimization_report() const;
    void suggest_optimizations(uint32_t node_id) const;
};

// SIMD-optimized operations
namespace SIMDOps {
    // Vector operations using SIMD when available
    void vector_add_f32(const float* a, const float* b, float* result, size_t count);
    void vector_mul_f32(const float* a, const float* b, float* result, size_t count);
    void vector_dot_f32(const float* a, const float* b, float& result, size_t count);
    
    // String operations
    bool fast_string_compare(const char* a, const char* b, size_t len);
    size_t fast_string_hash(const char* str, size_t len);
    
    // Memory operations
    void fast_memcopy(void* dst, const void* src, size_t size);
    void fast_memset(void* ptr, int value, size_t size);
}

// Async operation batching for performance
class AsyncBatcher {
private:
    struct BatchedOperation {
        std::function<void()> operation;
        std::chrono::high_resolution_clock::time_point enqueue_time;
        std::string category;
    };
    
    std::vector<BatchedOperation> pending_operations_;
    std::chrono::milliseconds batch_timeout_{10}; // 10ms batching window
    std::atomic<bool> processing_{false};

public:
    void enqueue_operation(std::function<void()> op, const std::string& category = "default");
    void process_batch();
    void set_batch_timeout(std::chrono::milliseconds timeout);
    
    size_t pending_count() const { return pending_operations_.size(); }
    Dictionary get_batch_stats() const;
};

// Performance monitoring dashboard
class PerformanceDashboard {
public:
    struct SystemMetrics {
        double cpu_usage_percent;
        double memory_usage_mb;
        double peak_memory_mb;
        uint64_t allocations_per_second;
        double gc_time_ms;
        double avg_frame_time_ms;
    };
    
    void update_metrics();
    SystemMetrics get_current_metrics() const;
    Dictionary export_metrics_json() const;
    void start_monitoring(double interval_seconds = 1.0);
    void stop_monitoring();
    
private:
    SystemMetrics current_metrics_;
    std::vector<SystemMetrics> metric_history_;
    std::atomic<bool> monitoring_active_{false};
    std::chrono::steady_clock::time_point last_update_;
};