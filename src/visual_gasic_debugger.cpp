#include "visual_gasic_debugger.h"
#include <algorithm>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/classes/os.hpp>

// Global debugger instance
static VisualGasicDebugger* g_global_debugger = nullptr;

VisualGasicDebugger::VisualGasicDebugger() {
    current_session = std::make_unique<DebugSession>();
    current_frame_index = 0;
    session_start_time = std::chrono::steady_clock::now();
    last_memory_snapshot = session_start_time;
}

VisualGasicDebugger::~VisualGasicDebugger() {
    if (debug_enabled) {
        end_debug_session();
    }
    
    if (g_global_debugger == this) {
        g_global_debugger = nullptr;
    }
}

void VisualGasicDebugger::_bind_methods() {
    ClassDB::bind_method(D_METHOD("start_debug_session"), &VisualGasicDebugger::start_debug_session);
    ClassDB::bind_method(D_METHOD("end_debug_session"), &VisualGasicDebugger::end_debug_session);
    ClassDB::bind_method(D_METHOD("set_breakpoint"), &VisualGasicDebugger::set_breakpoint);
    ClassDB::bind_method(D_METHOD("get_breakpoints"), &VisualGasicDebugger::get_breakpoints);
    ClassDB::bind_method(D_METHOD("enable_profiling"), &VisualGasicDebugger::enable_profiling);
    ClassDB::bind_method(D_METHOD("get_performance_profile"), &VisualGasicDebugger::get_performance_profile);
    ClassDB::bind_method(D_METHOD("get_memory_usage"), &VisualGasicDebugger::get_memory_usage);
}

// Debug Session Management
void VisualGasicDebugger::start_debug_session(const String& session_id) {
    debug_enabled = true;
    
    current_session = std::make_unique<DebugSession>();
    current_session->session_id = session_id.is_empty() ? generate_session_id() : session_id;
    current_session->start_time_us = get_current_timestamp_us();
    
    session_start_time = std::chrono::steady_clock::now();
    last_memory_snapshot = session_start_time;
    
    // Clear previous data
    current_frame_index = 0;
    function_start_times.clear();
    function_call_counts.clear();
    active_allocations.clear();
    total_allocated_bytes = 0;
    total_freed_bytes = 0;
    
    // Set as global debugger
    VisualGasicDebuggerGlobal::set_global_debugger(this);
    
    UtilityFunctions::print_rich("[color=green]Debug session started: " + current_session->session_id + "[/color]");
}

void VisualGasicDebugger::end_debug_session() {
    if (!debug_enabled) return;
    
    debug_enabled = false;
    
    if (current_session) {
        current_session->end_time_us = get_current_timestamp_us();
        
        // Final memory snapshot
        if (memory_tracking_enabled) {
            take_memory_snapshot();
            detect_memory_leaks();
        }
        
        // Generate final performance report
        if (profiling_enabled) {
            identify_performance_hotspots();
        }
        
        UtilityFunctions::print_rich("[color=yellow]Debug session ended: " + current_session->session_id + "[/color]");
        UtilityFunctions::print_rich("[color=cyan]Execution frames recorded: " + String::num(current_session->execution_history.size()) + "[/color]");
        UtilityFunctions::print_rich("[color=cyan]Functions profiled: " + String::num(current_session->function_profiles.size()) + "[/color]");
        UtilityFunctions::print_rich("[color=cyan]Memory snapshots: " + String::num(current_session->memory_snapshots.size()) + "[/color]");
    }
}

Dictionary VisualGasicDebugger::get_session_info() const {
    Dictionary info;
    
    if (current_session) {
        info["session_id"] = current_session->session_id;
        info["start_time"] = current_session->start_time_us;
        info["end_time"] = current_session->end_time_us;
        info["frame_count"] = current_session->execution_history.size();
        info["current_frame"] = current_frame_index;
        info["profiling_enabled"] = profiling_enabled;
        info["memory_tracking_enabled"] = memory_tracking_enabled;
        info["time_travel_enabled"] = time_travel_enabled;
    }
    
    return info;
}

// Time-Travel Debugging
void VisualGasicDebugger::enable_time_travel(bool enabled) {
    time_travel_enabled = enabled;
    if (enabled) {
        recording_enabled = true;
        UtilityFunctions::print_rich("[color=green]Time-travel debugging enabled[/color]");
    } else {
        UtilityFunctions::print_rich("[color=yellow]Time-travel debugging disabled[/color]");
    }
}

void VisualGasicDebugger::record_execution_frame(const String& function_name, const String& file_path, 
                                                int line_number, const Dictionary& variables) {
    if (!debug_enabled || !recording_enabled || !current_session) return;
    
    ExecutionFrame frame;
    frame.function_name = function_name;
    frame.file_path = file_path;
    frame.line_number = line_number;
    frame.local_variables = variables;
    frame.timestamp_us = get_current_timestamp_us();
    frame.memory_usage = total_allocated_bytes - total_freed_bytes;
    
    // Capture call stack
    Array call_stack;
    for (size_t i = 0; i < current_session->execution_history.size() && i < 10; i++) {
        size_t index = current_session->execution_history.size() - 1 - i;
        const ExecutionFrame& prev_frame = current_session->execution_history[index];
        Dictionary stack_entry;
        stack_entry["function"] = prev_frame.function_name;
        stack_entry["file"] = prev_frame.file_path;
        stack_entry["line"] = prev_frame.line_number;
        call_stack.push_back(stack_entry);
    }
    frame.call_stack = call_stack;
    
    // Add to history
    current_session->execution_history.push_back(frame);
    current_frame_index = current_session->execution_history.size() - 1;
    
    // Cleanup old history if needed
    if (current_session->execution_history.size() > max_history_size) {
        cleanup_old_history();
    }
    
    // Check for memory snapshots
    auto now = std::chrono::steady_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(now - last_memory_snapshot);
    if (memory_tracking_enabled && duration.count() >= static_cast<long>(memory_snapshot_interval_ms)) {
        take_memory_snapshot();
        last_memory_snapshot = now;
    }
}

bool VisualGasicDebugger::step_backward() {
    if (!time_travel_enabled || !current_session || current_frame_index == 0) {
        return false;
    }
    
    current_frame_index--;
    highlight_current_line();
    return true;
}

bool VisualGasicDebugger::step_forward() {
    if (!time_travel_enabled || !current_session || 
        current_frame_index >= current_session->execution_history.size() - 1) {
        return false;
    }
    
    current_frame_index++;
    highlight_current_line();
    return true;
}

bool VisualGasicDebugger::goto_frame(size_t frame_index) {
    if (!time_travel_enabled || !current_session || 
        frame_index >= current_session->execution_history.size()) {
        return false;
    }
    
    current_frame_index = frame_index;
    highlight_current_line();
    return true;
}

VisualGasicDebugger::ExecutionFrame VisualGasicDebugger::get_current_frame() const {
    if (current_session && current_frame_index < current_session->execution_history.size()) {
        return current_session->execution_history[current_frame_index];
    }
    return ExecutionFrame();
}

Array VisualGasicDebugger::get_execution_history(int max_frames) const {
    Array history;
    
    if (!current_session) return history;
    
    size_t start_index = 0;
    if (current_session->execution_history.size() > static_cast<size_t>(max_frames)) {
        start_index = current_session->execution_history.size() - max_frames;
    }
    
    for (size_t i = start_index; i < current_session->execution_history.size(); i++) {
        history.push_back(frame_to_dictionary(current_session->execution_history[i]));
    }
    
    return history;
}

// Breakpoint Management
void VisualGasicDebugger::set_breakpoint(const String& file_path, int line_number, const String& condition) {
    Breakpoint bp;
    bp.file_path = file_path;
    bp.line_number = line_number;
    bp.condition = condition;
    bp.enabled = true;
    bp.hit_count = 0;
    bp.action = "break";
    
    breakpoints[file_path][line_number] = bp;
    
    UtilityFunctions::print_rich("[color=green]Breakpoint set at " + file_path + ":" + String::num(line_number) + "[/color]");
    if (!condition.is_empty()) {
        UtilityFunctions::print_rich("[color=cyan]  Condition: " + condition + "[/color]");
    }
}

void VisualGasicDebugger::remove_breakpoint(const String& file_path, int line_number) {
    auto file_it = breakpoints.find(file_path);
    if (file_it != breakpoints.end()) {
        auto bp_it = file_it->second.find(line_number);
        if (bp_it != file_it->second.end()) {
            file_it->second.erase(bp_it);
            UtilityFunctions::print_rich("[color=yellow]Breakpoint removed from " + file_path + ":" + String::num(line_number) + "[/color]");
            
            if (file_it->second.empty()) {
                breakpoints.erase(file_it);
            }
        }
    }
}

void VisualGasicDebugger::enable_breakpoint(const String& file_path, int line_number, bool enabled) {
    auto file_it = breakpoints.find(file_path);
    if (file_it != breakpoints.end()) {
        auto bp_it = file_it->second.find(line_number);
        if (bp_it != file_it->second.end()) {
            bp_it->second.enabled = enabled;
            String status = enabled ? "enabled" : "disabled";
            UtilityFunctions::print_rich("[color=cyan]Breakpoint " + status + " at " + file_path + ":" + String::num(line_number) + "[/color]");
        }
    }
}

Array VisualGasicDebugger::get_breakpoints() const {
    Array bp_list;
    
    for (const auto& file_pair : breakpoints) {
        for (const auto& bp_pair : file_pair.second) {
            bp_list.push_back(breakpoint_to_dictionary(bp_pair.second));
        }
    }
    
    return bp_list;
}

bool VisualGasicDebugger::should_break_at(const String& file_path, int line_number, const Dictionary& context) {
    auto file_it = breakpoints.find(file_path);
    if (file_it == breakpoints.end()) return false;
    
    auto bp_it = file_it->second.find(line_number);
    if (bp_it == file_it->second.end() || !bp_it->second.enabled) return false;
    
    Breakpoint& bp = bp_it->second;
    bp.hit_count++;
    
    if (bp.condition.is_empty()) {
        return true;
    }
    
    return evaluate_breakpoint_condition(bp.condition, context);
}

// Performance Profiling
void VisualGasicDebugger::enable_profiling(bool enabled) {
    profiling_enabled = enabled;
    if (enabled) {
        UtilityFunctions::print_rich("[color=green]Performance profiling enabled[/color]");
    } else {
        UtilityFunctions::print_rich("[color=yellow]Performance profiling disabled[/color]");
    }
}

void VisualGasicDebugger::start_function_profiling(const String& function_name) {
    if (!profiling_enabled) return;
    
    function_start_times[function_name] = std::chrono::steady_clock::now();
    function_call_counts[function_name]++;
}

void VisualGasicDebugger::end_function_profiling(const String& function_name) {
    if (!profiling_enabled) return;
    
    auto it = function_start_times.find(function_name);
    if (it != function_start_times.end()) {
        auto end_time = std::chrono::steady_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end_time - it->second);
        
        update_function_profile(function_name, duration.count());
        function_start_times.erase(it);
    }
}

Dictionary VisualGasicDebugger::get_performance_profile() const {
    Dictionary profile;
    
    if (!current_session) return profile;
    
    Array functions;
    for (const auto& func_pair : current_session->function_profiles) {
        Dictionary func_info;
        const PerformanceProfile& prof = func_pair.second;
        
        func_info["name"] = prof.function_name;
        func_info["total_time_us"] = prof.total_time_us;
        func_info["call_count"] = prof.call_count;
        func_info["avg_time_us"] = prof.avg_time_us;
        func_info["min_time_us"] = prof.min_time_us;
        func_info["max_time_us"] = prof.max_time_us;
        func_info["cpu_usage_percent"] = prof.cpu_usage_percent;
        
        functions.push_back(func_info);
    }
    
    profile["functions"] = functions;
    profile["total_session_time"] = get_current_timestamp_us() - current_session->start_time_us;
    profile["cpu_usage"] = calculate_cpu_usage();
    
    return profile;
}

Array VisualGasicDebugger::get_function_hotspots(int max_results) const {
    Array hotspots;
    
    if (!current_session) return hotspots;
    
    // Sort functions by total time
    std::vector<std::pair<uint64_t, String>> sorted_functions;
    for (const auto& func_pair : current_session->function_profiles) {
        sorted_functions.push_back({func_pair.second.total_time_us, func_pair.first});
    }
    
    std::sort(sorted_functions.rbegin(), sorted_functions.rend());
    
    for (int i = 0; i < std::min(max_results, static_cast<int>(sorted_functions.size())); i++) {
        Dictionary hotspot;
        const String& func_name = sorted_functions[i].second;
        const PerformanceProfile& profile = current_session->function_profiles.at(func_name);
        
        hotspot["function"] = func_name;
        hotspot["total_time_us"] = profile.total_time_us;
        hotspot["percentage"] = (profile.total_time_us * 100.0) / (get_current_timestamp_us() - current_session->start_time_us);
        hotspot["call_count"] = profile.call_count;
        hotspot["avg_time_us"] = profile.avg_time_us;
        
        hotspots.push_back(hotspot);
    }
    
    return hotspots;
}

// Memory Analysis
void VisualGasicDebugger::enable_memory_tracking(bool enabled) {
    memory_tracking_enabled = enabled;
    if (enabled) {
        UtilityFunctions::print_rich("[color=green]Memory tracking enabled[/color]");
    } else {
        UtilityFunctions::print_rich("[color=yellow]Memory tracking disabled[/color]");
    }
}

void VisualGasicDebugger::track_allocation(void* ptr, size_t size, const String& type_name) {
    if (!memory_tracking_enabled || ptr == nullptr) return;
    
    active_allocations[ptr] = size;
    total_allocated_bytes += size;
    
    update_memory_stats();
}

void VisualGasicDebugger::track_deallocation(void* ptr) {
    if (!memory_tracking_enabled || ptr == nullptr) return;
    
    auto it = active_allocations.find(ptr);
    if (it != active_allocations.end()) {
        total_freed_bytes += it->second;
        active_allocations.erase(it);
    }
    
    update_memory_stats();
}

Dictionary VisualGasicDebugger::get_memory_usage() const {
    Dictionary usage;
    
    usage["total_allocated"] = total_allocated_bytes;
    usage["total_freed"] = total_freed_bytes;
    usage["active_allocations"] = active_allocations.size();
    usage["current_usage"] = total_allocated_bytes - total_freed_bytes;
    
    if (!current_session->memory_snapshots.empty()) {
        const MemorySnapshot& latest = current_session->memory_snapshots.back();
        usage["peak_usage"] = latest.total_allocated;
    }
    
    return usage;
}

Array VisualGasicDebugger::get_memory_leaks() const {
    Array leaks;
    
    for (const auto& alloc : active_allocations) {
        Dictionary leak;
        leak["address"] = String::num_uint64(reinterpret_cast<uintptr_t>(alloc.first));
        leak["size"] = alloc.second;
        leak["stack_trace"] = get_allocation_stack_trace();
        leaks.push_back(leak);
    }
    
    return leaks;
}

void VisualGasicDebugger::take_memory_snapshot() {
    if (!memory_tracking_enabled || !current_session) return;
    
    MemorySnapshot snapshot;
    snapshot.timestamp_us = get_current_timestamp_us();
    snapshot.total_allocated = total_allocated_bytes;
    snapshot.total_freed = total_freed_bytes;
    snapshot.active_allocations = active_allocations.size();
    
    current_session->memory_snapshots.push_back(snapshot);
}

// Visual Debugging
void VisualGasicDebugger::highlight_current_line() {
    ExecutionFrame frame = get_current_frame();
    if (!frame.function_name.is_empty()) {
        UtilityFunctions::print_rich("[color=yellow]>>> " + frame.file_path + ":" + String::num(frame.line_number) + " in " + frame.function_name + "()[/color]");
    }
}

Dictionary VisualGasicDebugger::get_call_stack() const {
    Dictionary stack;
    ExecutionFrame frame = get_current_frame();
    stack["current_function"] = frame.function_name;
    stack["current_file"] = frame.file_path;
    stack["current_line"] = frame.line_number;
    stack["call_stack"] = frame.call_stack;
    return stack;
}

// Utility Methods
uint64_t VisualGasicDebugger::get_current_timestamp_us() const {
    return Time::get_singleton()->get_unix_time_from_system() * 1000000;
}

String VisualGasicDebugger::generate_session_id() const {
    return "vg_debug_" + String::num(get_current_timestamp_us());
}

bool VisualGasicDebugger::evaluate_breakpoint_condition(const String& condition, const Dictionary& context) {
    // Simplified condition evaluation
    if (condition == "true") return true;
    if (condition == "false") return false;
    
    // Could implement full expression evaluation here
    return true; // Default to breaking
}

void VisualGasicDebugger::update_function_profile(const String& function_name, uint64_t execution_time_us) {
    if (!current_session) return;
    
    PerformanceProfile& profile = current_session->function_profiles[function_name];
    profile.function_name = function_name;
    profile.total_time_us += execution_time_us;
    profile.call_count++;
    profile.avg_time_us = profile.total_time_us / profile.call_count;
    
    if (execution_time_us < profile.min_time_us) {
        profile.min_time_us = execution_time_us;
    }
    if (execution_time_us > profile.max_time_us) {
        profile.max_time_us = execution_time_us;
    }
}

void VisualGasicDebugger::cleanup_old_history() {
    if (current_session && current_session->execution_history.size() > max_history_size) {
        size_t remove_count = current_session->execution_history.size() - max_history_size + 1000; // Remove extra
        current_session->execution_history.erase(
            current_session->execution_history.begin(),
            current_session->execution_history.begin() + remove_count
        );
        
        if (current_frame_index >= remove_count) {
            current_frame_index -= remove_count;
        } else {
            current_frame_index = 0;
        }
    }
}

double VisualGasicDebugger::calculate_cpu_usage() const {
    // Simplified CPU usage calculation
    return 0.0; // Would implement actual CPU usage tracking
}

void VisualGasicDebugger::update_memory_stats() {
    // Update memory statistics
}

void VisualGasicDebugger::detect_memory_leaks() {
    if (active_allocations.size() > 0) {
        UtilityFunctions::print_rich("[color=red]Potential memory leaks detected: " + String::num(active_allocations.size()) + " allocations[/color]");
    }
}

Dictionary VisualGasicDebugger::frame_to_dictionary(const ExecutionFrame& frame) const {
    Dictionary dict;
    dict["function_name"] = frame.function_name;
    dict["file_path"] = frame.file_path;
    dict["line_number"] = frame.line_number;
    dict["local_variables"] = frame.local_variables;
    dict["timestamp_us"] = frame.timestamp_us;
    dict["memory_usage"] = frame.memory_usage;
    dict["call_stack"] = frame.call_stack;
    return dict;
}

Dictionary VisualGasicDebugger::breakpoint_to_dictionary(const Breakpoint& bp) const {
    Dictionary dict;
    dict["file_path"] = bp.file_path;
    dict["line_number"] = bp.line_number;
    dict["condition"] = bp.condition;
    dict["enabled"] = bp.enabled;
    dict["hit_count"] = bp.hit_count;
    dict["action"] = bp.action;
    return dict;
}

String VisualGasicDebugger::get_allocation_stack_trace() const {
    return "Stack trace not implemented"; // Would implement actual stack trace
}

void VisualGasicDebugger::identify_performance_hotspots() {
    // Analyze and identify performance bottlenecks
}

// Global debugger functions
namespace VisualGasicDebuggerGlobal {
    VisualGasicDebugger* get_global_debugger() {
        return g_global_debugger;
    }
    
    void set_global_debugger(VisualGasicDebugger* debugger) {
        g_global_debugger = debugger;
    }
}