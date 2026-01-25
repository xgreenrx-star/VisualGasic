#ifndef VISUAL_GASIC_DEBUGGER_H
#define VISUAL_GASIC_DEBUGGER_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <vector>
#include <map>
#include <memory>
#include <chrono>
#include <stack>

using namespace godot;

/**
 * VisualGasic Advanced Debugger
 * 
 * Professional debugging system with time-travel capabilities:
 * - Execution recording and replay
 * - Time-travel debugging with state inspection
 * - Performance profiling and hotspot detection
 * - Memory usage analysis and leak detection
 * - Visual state inspection and modification
 * - Breakpoint management with conditions
 */
class VisualGasicDebugger : public RefCounted {
    GDCLASS(VisualGasicDebugger, RefCounted)

public:
    // Debugging Data Structures
    struct ExecutionFrame {
        String function_name;
        String file_path;
        int line_number = 0;
        Dictionary local_variables;
        Dictionary global_state;
        uint64_t timestamp_us = 0;
        uint64_t memory_usage = 0;
        double cpu_time_ms = 0.0;
        Array call_stack;
    };
    
    struct Breakpoint {
        String file_path;
        int line_number = 0;
        String condition;
        bool enabled = true;
        int hit_count = 0;
        String action; // "break", "log", "trace"
        Dictionary metadata;
    };
    
    struct MemorySnapshot {
        uint64_t timestamp_us = 0;
        uint64_t total_allocated = 0;
        uint64_t total_freed = 0;
        uint64_t active_allocations = 0;
        Dictionary allocation_sizes;
        Array allocation_stack_traces;
        Dictionary type_usage;
    };
    
    struct PerformanceProfile {
        String function_name;
        uint64_t total_time_us = 0;
        uint64_t call_count = 0;
        uint64_t avg_time_us = 0;
        uint64_t min_time_us = UINT64_MAX;
        uint64_t max_time_us = 0;
        double cpu_usage_percent = 0.0;
        Array hotspots;
    };
    
    struct DebugSession {
        String session_id;
        uint64_t start_time_us = 0;
        uint64_t end_time_us = 0;
        std::vector<ExecutionFrame> execution_history;
        std::map<String, PerformanceProfile> function_profiles;
        std::vector<MemorySnapshot> memory_snapshots;
        Dictionary session_metadata;
    };

private:
    // Debug State
    bool debug_enabled = false;
    bool time_travel_enabled = false;
    bool profiling_enabled = false;
    bool memory_tracking_enabled = false;
    
    // Current Session
    std::unique_ptr<DebugSession> current_session;
    size_t current_frame_index = 0;
    
    // Breakpoint Management
    std::map<String, std::map<int, Breakpoint>> breakpoints; // file_path -> line -> breakpoint
    std::vector<Breakpoint> conditional_breakpoints;
    
    // Execution Recording
    size_t max_history_size = 10000;
    bool recording_enabled = true;
    
    // Performance Profiling
    std::map<String, std::chrono::steady_clock::time_point> function_start_times;
    std::map<String, uint64_t> function_call_counts;
    std::chrono::steady_clock::time_point session_start_time;
    
    // Memory Tracking
    std::map<void*, size_t> active_allocations;
    uint64_t total_allocated_bytes = 0;
    uint64_t total_freed_bytes = 0;
    size_t memory_snapshot_interval_ms = 100;
    std::chrono::steady_clock::time_point last_memory_snapshot;
    
    // State Inspection
    Dictionary variable_watch_list;
    Array state_change_listeners;

public:
    VisualGasicDebugger();
    ~VisualGasicDebugger();
    
    // Debug Session Management
    void start_debug_session(const String& session_id = "");
    void end_debug_session();
    bool is_debugging() const { return debug_enabled; }
    Dictionary get_session_info() const;
    
    // Time-Travel Debugging
    void enable_time_travel(bool enabled);
    void record_execution_frame(const String& function_name, const String& file_path, 
                              int line_number, const Dictionary& variables);
    bool step_backward();
    bool step_forward();
    bool goto_frame(size_t frame_index);
    ExecutionFrame get_current_frame() const;
    Array get_execution_history(int max_frames = 100) const;
    
    // Breakpoint Management
    void set_breakpoint(const String& file_path, int line_number, const String& condition = "");
    void remove_breakpoint(const String& file_path, int line_number);
    void enable_breakpoint(const String& file_path, int line_number, bool enabled);
    Array get_breakpoints() const;
    bool should_break_at(const String& file_path, int line_number, const Dictionary& context);
    
    // State Inspection
    void add_variable_watch(const String& variable_name, const String& expression = "");
    void remove_variable_watch(const String& variable_name);
    Dictionary get_watched_variables() const;
    Dictionary get_local_variables() const;
    Dictionary get_global_state() const;
    void set_variable_value(const String& variable_name, const Variant& value);
    
    // Performance Profiling
    void enable_profiling(bool enabled);
    void start_function_profiling(const String& function_name);
    void end_function_profiling(const String& function_name);
    Dictionary get_performance_profile() const;
    Array get_function_hotspots(int max_results = 10) const;
    void clear_performance_data();
    
    // Memory Analysis
    void enable_memory_tracking(bool enabled);
    void track_allocation(void* ptr, size_t size, const String& type_name = "");
    void track_deallocation(void* ptr);
    Dictionary get_memory_usage() const;
    Array get_memory_leaks() const;
    void take_memory_snapshot();
    Array get_memory_snapshots() const;
    
    // Visual Debugging
    Dictionary get_call_stack() const;
    Dictionary get_execution_context() const;
    void highlight_current_line();
    void show_variable_inspector();
    void show_performance_graph();
    
    // Debug Output
    void debug_log(const String& message, const String& level = "info");
    void debug_trace(const String& function_name, const Array& arguments);
    Array get_debug_log() const;
    void clear_debug_log();
    
    // Session Persistence
    void save_session(const String& file_path);
    void load_session(const String& file_path);
    void export_session_data(const String& format = "json") const;

protected:
    static void _bind_methods();

private:
    // Internal Helper Methods
    uint64_t get_current_timestamp_us() const;
    String generate_session_id() const;
    void capture_current_state(ExecutionFrame& frame);
    bool evaluate_breakpoint_condition(const String& condition, const Dictionary& context);
    void update_function_profile(const String& function_name, uint64_t execution_time_us);
    void cleanup_old_history();
    
    // Memory Tracking Helpers
    void update_memory_stats();
    void detect_memory_leaks();
    String get_allocation_stack_trace() const;
    
    // Performance Analysis
    double calculate_cpu_usage() const;
    void identify_performance_hotspots();
    void analyze_function_call_patterns();
    
    // Utility Functions
    Dictionary frame_to_dictionary(const ExecutionFrame& frame) const;
    ExecutionFrame dictionary_to_frame(const Dictionary& dict) const;
    Dictionary breakpoint_to_dictionary(const Breakpoint& bp) const;
    Breakpoint dictionary_to_breakpoint(const Dictionary& dict) const;
};

// Debug Macros for VisualGasic Code
#define VG_DEBUG_BREAK(condition) \
    do { \
        if (VisualGasicDebugger::get_global_debugger() && (condition)) { \
            VisualGasicDebugger::get_global_debugger()->record_execution_frame(__FUNCTION__, __FILE__, __LINE__, Dictionary()); \
        } \
    } while(0)

#define VG_DEBUG_TRACE(func_name) \
    do { \
        if (VisualGasicDebugger::get_global_debugger()) { \
            VisualGasicDebugger::get_global_debugger()->start_function_profiling(func_name); \
        } \
    } while(0)

#define VG_DEBUG_TRACE_END(func_name) \
    do { \
        if (VisualGasicDebugger::get_global_debugger()) { \
            VisualGasicDebugger::get_global_debugger()->end_function_profiling(func_name); \
        } \
    } while(0)

#define VG_DEBUG_MEMORY_ALLOC(ptr, size, type) \
    do { \
        if (VisualGasicDebugger::get_global_debugger()) { \
            VisualGasicDebugger::get_global_debugger()->track_allocation(ptr, size, type); \
        } \
    } while(0)

#define VG_DEBUG_MEMORY_FREE(ptr) \
    do { \
        if (VisualGasicDebugger::get_global_debugger()) { \
            VisualGasicDebugger::get_global_debugger()->track_deallocation(ptr); \
        } \
    } while(0)

// Global debugger access
namespace VisualGasicDebuggerGlobal {
    VisualGasicDebugger* get_global_debugger();
    void set_global_debugger(VisualGasicDebugger* debugger);
}

#endif // VISUAL_GASIC_DEBUGGER_H