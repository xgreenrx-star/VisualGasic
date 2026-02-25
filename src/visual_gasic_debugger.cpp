#include "visual_gasic_debugger.h"
#include <algorithm>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/json.hpp>

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
    // Session management
    ClassDB::bind_method(D_METHOD("start_debug_session", "session_id"), &VisualGasicDebugger::start_debug_session, DEFVAL(""));
    ClassDB::bind_method(D_METHOD("end_debug_session"), &VisualGasicDebugger::end_debug_session);
    ClassDB::bind_method(D_METHOD("is_debugging"), &VisualGasicDebugger::is_debugging);
    ClassDB::bind_method(D_METHOD("get_session_info"), &VisualGasicDebugger::get_session_info);
    ClassDB::bind_method(D_METHOD("save_session", "file_path"), &VisualGasicDebugger::save_session);
    ClassDB::bind_method(D_METHOD("load_session", "file_path"), &VisualGasicDebugger::load_session);
    
    // Time-travel debugging
    ClassDB::bind_method(D_METHOD("enable_time_travel", "enabled"), &VisualGasicDebugger::enable_time_travel);
    ClassDB::bind_method(D_METHOD("record_execution_frame", "function_name", "file_path", "line_number", "variables"), &VisualGasicDebugger::record_execution_frame);
    ClassDB::bind_method(D_METHOD("step_backward"), &VisualGasicDebugger::step_backward);
    ClassDB::bind_method(D_METHOD("step_forward"), &VisualGasicDebugger::step_forward);
    ClassDB::bind_method(D_METHOD("goto_frame", "frame_index"), &VisualGasicDebugger::goto_frame);
    ClassDB::bind_method(D_METHOD("get_execution_history", "max_frames"), &VisualGasicDebugger::get_execution_history, DEFVAL(100));
    
    // Breakpoint management
    ClassDB::bind_method(D_METHOD("set_breakpoint", "file_path", "line_number", "condition"), &VisualGasicDebugger::set_breakpoint, DEFVAL(""));
    ClassDB::bind_method(D_METHOD("remove_breakpoint", "file_path", "line_number"), &VisualGasicDebugger::remove_breakpoint);
    ClassDB::bind_method(D_METHOD("enable_breakpoint", "file_path", "line_number", "enabled"), &VisualGasicDebugger::enable_breakpoint);
    ClassDB::bind_method(D_METHOD("get_breakpoints"), &VisualGasicDebugger::get_breakpoints);
    ClassDB::bind_method(D_METHOD("should_break_at", "file_path", "line_number", "context"), &VisualGasicDebugger::should_break_at);
    
    // State inspection
    ClassDB::bind_method(D_METHOD("add_variable_watch", "variable_name", "expression"), &VisualGasicDebugger::add_variable_watch, DEFVAL(""));
    ClassDB::bind_method(D_METHOD("remove_variable_watch", "variable_name"), &VisualGasicDebugger::remove_variable_watch);
    ClassDB::bind_method(D_METHOD("get_watched_variables"), &VisualGasicDebugger::get_watched_variables);
    ClassDB::bind_method(D_METHOD("set_variable_value", "variable_name", "value"), &VisualGasicDebugger::set_variable_value);
    
    // Performance profiling
    ClassDB::bind_method(D_METHOD("enable_profiling", "enabled"), &VisualGasicDebugger::enable_profiling);
    ClassDB::bind_method(D_METHOD("start_function_profiling", "function_name"), &VisualGasicDebugger::start_function_profiling);
    ClassDB::bind_method(D_METHOD("end_function_profiling", "function_name"), &VisualGasicDebugger::end_function_profiling);
    ClassDB::bind_method(D_METHOD("get_performance_profile"), &VisualGasicDebugger::get_performance_profile);
    ClassDB::bind_method(D_METHOD("get_function_hotspots", "max_results"), &VisualGasicDebugger::get_function_hotspots, DEFVAL(10));
    ClassDB::bind_method(D_METHOD("clear_performance_data"), &VisualGasicDebugger::clear_performance_data);
    
    // Memory analysis
    ClassDB::bind_method(D_METHOD("enable_memory_tracking", "enabled"), &VisualGasicDebugger::enable_memory_tracking);
    ClassDB::bind_method(D_METHOD("get_memory_usage"), &VisualGasicDebugger::get_memory_usage);
    ClassDB::bind_method(D_METHOD("get_memory_leaks"), &VisualGasicDebugger::get_memory_leaks);
    ClassDB::bind_method(D_METHOD("take_memory_snapshot"), &VisualGasicDebugger::take_memory_snapshot);
    ClassDB::bind_method(D_METHOD("get_memory_snapshots"), &VisualGasicDebugger::get_memory_snapshots);
    
    // Debug output
    ClassDB::bind_method(D_METHOD("debug_log", "message", "level"), &VisualGasicDebugger::debug_log, DEFVAL("info"));
    ClassDB::bind_method(D_METHOD("get_debug_log"), &VisualGasicDebugger::get_debug_log);
    ClassDB::bind_method(D_METHOD("clear_debug_log"), &VisualGasicDebugger::clear_debug_log);
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
        info["frame_count"] = (int64_t)current_session->execution_history.size();
        info["current_frame"] = (int64_t)current_frame_index;
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

bool VisualGasicDebugger::goto_frame(int64_t frame_index) {
    if (!time_travel_enabled || !current_session || frame_index < 0 ||
        (size_t)frame_index >= current_session->execution_history.size()) {
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
    usage["active_allocations"] = (int64_t)active_allocations.size();
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
        leak["size"] = (int64_t)alloc.second;
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
    // Simple expression evaluator for conditional breakpoints.
    // Supports:  variable comparisons (x > 5, counter == 10, name = "hi")
    //            boolean literals (true / false)
    //            logical And / Or / Not
    //            nested variable lookup from context["variables"]

    if (condition.strip_edges().is_empty()) return true;
    String cond = condition.strip_edges();

    // Literal booleans
    if (cond.to_lower() == "true") return true;
    if (cond.to_lower() == "false") return false;

    // Get the variables dictionary from context
    Dictionary vars;
    if (context.has("variables")) {
        vars = context["variables"];
    }

    // Helper: resolve a token to a Variant value
    // - If it's a variable name found in vars, return its value.
    // - If it looks like a number, parse it.
    // - If it's a quoted string, unquote it.
    // - "true"/"false" → bool.
    auto resolve_token = [&](const String& tok) -> Variant {
        String t = tok.strip_edges();
        if (t.is_empty()) return Variant();

        // Quoted string literal
        if ((t.begins_with("\"") && t.ends_with("\"")) ||
            (t.begins_with("'") && t.ends_with("'"))) {
            return t.substr(1, t.length() - 2);
        }

        // Boolean literals
        if (t.to_lower() == "true") return true;
        if (t.to_lower() == "false") return false;
        if (t.to_lower() == "nothing" || t.to_lower() == "null") return Variant();

        // Variable lookup (case-insensitive)
        if (vars.size() > 0) {
            // Try exact match first
            if (vars.has(t)) return vars[t];
            // Case-insensitive search
            Array keys = vars.keys();
            for (int i = 0; i < keys.size(); i++) {
                if (String(keys[i]).to_lower() == t.to_lower()) {
                    return vars[keys[i]];
                }
            }
        }

        // Number literal
        if (t.is_valid_int()) return t.to_int();
        if (t.is_valid_float()) return t.to_float();

        return t; // Return as string if nothing else matches
    };

    // Try to find a logical operator (And / Or) — split on the first one found
    // Process Or first (lower precedence), then And
    {
        // Find " Or " (case-insensitive, word boundary via spaces)
        int or_pos = cond.to_lower().find(" or ");
        if (or_pos >= 0) {
            String left = cond.substr(0, or_pos);
            String right = cond.substr(or_pos + 4);
            return evaluate_breakpoint_condition(left, context) ||
                   evaluate_breakpoint_condition(right, context);
        }
        int and_pos = cond.to_lower().find(" and ");
        if (and_pos >= 0) {
            String left = cond.substr(0, and_pos);
            String right = cond.substr(and_pos + 5);
            return evaluate_breakpoint_condition(left, context) &&
                   evaluate_breakpoint_condition(right, context);
        }
        // "Not " prefix
        if (cond.to_lower().begins_with("not ")) {
            String inner = cond.substr(4);
            return !evaluate_breakpoint_condition(inner, context);
        }
    }

    // Try to find a comparison operator
    // Order matters: check two-char operators before single-char ones.
    struct { const char* op; int len; } operators[] = {
        {"<>", 2}, {"!=", 2}, {">=", 2}, {"<=", 2}, {"==", 2},
        {"=", 1}, {">", 1}, {"<", 1}
    };

    for (auto& op_info : operators) {
        String op_str = op_info.op;
        int pos = -1;

        // Skip operators inside string literals
        bool in_string = false;
        char string_char = 0;
        for (int i = 0; i < cond.length() - op_info.len + 1; i++) {
            char32_t ch = cond[i];
            if (!in_string && (ch == '"' || ch == '\'')) {
                in_string = true;
                string_char = ch;
            } else if (in_string && ch == string_char) {
                in_string = false;
            } else if (!in_string && cond.substr(i, op_info.len) == op_str) {
                // For single-char operators, ensure we're not part of a two-char operator
                if (op_info.len == 1) {
                    if (op_str == "=" && i > 0 && (cond[i-1] == '<' || cond[i-1] == '>' || cond[i-1] == '!' || cond[i-1] == '=')) continue;
                    if (op_str == "=" && i + 1 < cond.length() && cond[i+1] == '=') continue;
                    if (op_str == ">" && i + 1 < cond.length() && cond[i+1] == '=') continue;
                    if (op_str == "<" && i + 1 < cond.length() && (cond[i+1] == '=' || cond[i+1] == '>')) continue;
                }
                pos = i;
                break;
            }
        }

        if (pos >= 0) {
            String left_str = cond.substr(0, pos).strip_edges();
            String right_str = cond.substr(pos + op_info.len).strip_edges();
            Variant left_val = resolve_token(left_str);
            Variant right_val = resolve_token(right_str);
            Variant cmp_result;
            bool cmp_valid = false;

            if (op_str == "=" || op_str == "==") {
                // Type-flexible comparison
                if (left_val.get_type() == Variant::STRING || right_val.get_type() == Variant::STRING) {
                    return String(left_val).to_lower() == String(right_val).to_lower();
                }
                Variant::evaluate(Variant::OP_EQUAL, left_val, right_val, cmp_result, cmp_valid);
                return cmp_valid && (bool)cmp_result;
            }
            if (op_str == "<>" || op_str == "!=") {
                if (left_val.get_type() == Variant::STRING || right_val.get_type() == Variant::STRING) {
                    return String(left_val).to_lower() != String(right_val).to_lower();
                }
                Variant::evaluate(Variant::OP_NOT_EQUAL, left_val, right_val, cmp_result, cmp_valid);
                return cmp_valid && (bool)cmp_result;
            }
            if (op_str == ">") {
                Variant::evaluate(Variant::OP_GREATER, left_val, right_val, cmp_result, cmp_valid);
                return cmp_valid && (bool)cmp_result;
            }
            if (op_str == "<") {
                Variant::evaluate(Variant::OP_LESS, left_val, right_val, cmp_result, cmp_valid);
                return cmp_valid && (bool)cmp_result;
            }
            if (op_str == ">=") {
                Variant::evaluate(Variant::OP_GREATER_EQUAL, left_val, right_val, cmp_result, cmp_valid);
                return cmp_valid && (bool)cmp_result;
            }
            if (op_str == "<=") {
                Variant::evaluate(Variant::OP_LESS_EQUAL, left_val, right_val, cmp_result, cmp_valid);
                return cmp_valid && (bool)cmp_result;
            }
        }
    }

    // No operator found: treat the whole condition as a single value.
    // A variable name that resolves to a truthy value → true.
    Variant val = resolve_token(cond);
    if (val.get_type() == Variant::BOOL) return (bool)val;
    if (val.get_type() == Variant::INT) return (int64_t)val != 0;
    if (val.get_type() == Variant::FLOAT) return (double)val != 0.0;
    if (val.get_type() == Variant::STRING) return !((String)val).is_empty();
    return val.booleanize();
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
    // Calculate CPU usage based on execution history timing
    if (!current_session || current_session->execution_history.size() < 2) {
        return 0.0;
    }
    
    // Calculate average time between frames to estimate CPU usage
    uint64_t total_time = 0;
    size_t sample_count = Math::min((size_t)100, current_session->execution_history.size() - 1);
    
    for (size_t i = current_session->execution_history.size() - sample_count; 
         i < current_session->execution_history.size() - 1; i++) {
        uint64_t delta = current_session->execution_history[i + 1].timestamp_us - 
                         current_session->execution_history[i].timestamp_us;
        total_time += delta;
    }
    
    if (sample_count == 0 || total_time == 0) return 0.0;
    
    // Average microseconds per instruction
    double avg_us_per_op = (double)total_time / sample_count;
    
    // Estimate CPU usage: more operations per second = higher usage
    // This is a heuristic: assume 100% CPU if processing > 10000 ops/sec
    double ops_per_sec = 1000000.0 / avg_us_per_op;
    double usage = Math::clamp(ops_per_sec / 10000.0, 0.0, 1.0) * 100.0;
    
    return usage;
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
    // Build stack trace from current execution history
    if (!current_session || current_session->execution_history.empty()) {
        return "No execution history available";
    }
    
    String trace;
    trace += "=== Stack Trace ===\n";
    
    // Get the last few frames as the call stack
    size_t start_index = current_session->execution_history.size() > 20 ? 
                         current_session->execution_history.size() - 20 : 0;
    
    for (size_t i = current_session->execution_history.size(); i > start_index; i--) {
        const ExecutionFrame& frame = current_session->execution_history[i - 1];
        String frame_str = String("  at ") + frame.function_name + 
                          " (" + frame.file_path + ":" + String::num(frame.line_number) + ")\n";
        trace += frame_str;
    }
    
    trace += "=== Memory Stats ===\n";
    trace += "  Allocated: " + String::num(total_allocated_bytes) + " bytes\n";
    trace += "  Freed: " + String::num(total_freed_bytes) + " bytes\n";
    trace += "  In Use: " + String::num(total_allocated_bytes - total_freed_bytes) + " bytes\n";
    trace += "  Active Allocations: " + String::num(active_allocations.size()) + "\n";
    
    return trace;
}

void VisualGasicDebugger::identify_performance_hotspots() {
    if (!current_session || current_session->execution_history.size() < 10) {
        UtilityFunctions::print_rich("[color=yellow]Not enough execution history to analyze[/color]");
        return;
    }
    
    // Count function call frequencies
    Dictionary function_counts;
    Dictionary function_times;
    
    for (size_t i = 0; i < current_session->execution_history.size(); i++) {
        const ExecutionFrame& frame = current_session->execution_history[i];
        String key = frame.function_name;
        
        if (function_counts.has(key)) {
            function_counts[key] = (int)function_counts[key] + 1;
        } else {
            function_counts[key] = 1;
        }
        
        // Track time spent in each function
        if (i > 0) {
            uint64_t delta = frame.timestamp_us - current_session->execution_history[i - 1].timestamp_us;
            if (function_times.has(key)) {
                function_times[key] = (int64_t)function_times[key] + delta;
            } else {
                function_times[key] = (int64_t)delta;
            }
        }
    }
    
    UtilityFunctions::print_rich("[color=cyan]=== Performance Hotspots ===[/color]");
    
    // Find functions with highest call count
    Array keys = function_counts.keys();
    UtilityFunctions::print_rich("[color=white]Top Functions by Call Count:[/color]");
    for (int i = 0; i < keys.size() && i < 5; i++) {
        String func = keys[i];
        int count = function_counts[func];
        int64_t time_us = function_times.has(func) ? (int64_t)function_times[func] : 0;
        UtilityFunctions::print_rich("  " + func + ": " + String::num(count) + 
                                    " calls, " + String::num(time_us / 1000.0, 2) + "ms total");
    }
}

// ============================================================================
// Debug Output
// ============================================================================

void VisualGasicDebugger::debug_log(const String& message, const String& level) {
    Dictionary entry;
    entry["message"] = message;
    entry["level"] = level;
    entry["timestamp"] = get_current_timestamp_us();
    debug_log_entries.push_back(entry);
    
    if (level == "error") {
        UtilityFunctions::printerr("[VG Debug] ", message);
    } else if (level == "warn") {
        UtilityFunctions::print_rich("[color=yellow][VG Debug] " + message + "[/color]");
    } else {
        UtilityFunctions::print("[VG Debug] ", message);
    }
}

void VisualGasicDebugger::debug_trace(const String& function_name, const Array& arguments) {
    String args_str;
    for (int i = 0; i < arguments.size(); i++) {
        if (i > 0) args_str += ", ";
        args_str += String(arguments[i]);
    }
    debug_log("TRACE: " + function_name + "(" + args_str + ")", "info");
}

Array VisualGasicDebugger::get_debug_log() const {
    return debug_log_entries;
}

void VisualGasicDebugger::clear_debug_log() {
    debug_log_entries.clear();
}

// ============================================================================
// Variable Watch
// ============================================================================

void VisualGasicDebugger::add_variable_watch(const String& variable_name, const String& expression) {
    Dictionary watch;
    watch["expression"] = expression.is_empty() ? variable_name : expression;
    variable_watch_list[variable_name] = watch;
}

void VisualGasicDebugger::remove_variable_watch(const String& variable_name) {
    variable_watch_list.erase(variable_name);
}

Dictionary VisualGasicDebugger::get_watched_variables() const {
    return variable_watch_list;
}

Dictionary VisualGasicDebugger::get_local_variables() const {
    // Returns local variables from the current debug frame
    if (current_session && current_frame_index < current_session->execution_history.size()) {
        return current_session->execution_history[current_frame_index].local_variables;
    }
    return Dictionary();
}

Dictionary VisualGasicDebugger::get_global_state() const {
    if (current_session && !current_session->execution_history.empty()) {
        return current_session->execution_history.back().global_state;
    }
    return Dictionary();
}

void VisualGasicDebugger::set_variable_value(const String& variable_name, const Variant& value) {
    // This would modify a running instance's variable - store the request
    pending_variable_changes[variable_name] = value;
    UtilityFunctions::print("[VG Debug] Variable '", variable_name, "' set to ", value);
}

// ============================================================================
// Session Persistence
// ============================================================================

void VisualGasicDebugger::save_session(const String& file_path) {
    if (!current_session) return;
    
    Ref<FileAccess> f = FileAccess::open(file_path, FileAccess::WRITE);
    if (f.is_null()) {
        UtilityFunctions::printerr("[VG Debug] Failed to save session to: ", file_path);
        return;
    }
    
    Dictionary data;
    data["session_id"] = current_session->session_id;
    data["start_time"] = (int64_t)current_session->start_time_us;
    data["end_time"] = (int64_t)current_session->end_time_us;
    
    Array frames;
    for (size_t i = 0; i < current_session->execution_history.size(); i++) {
        frames.push_back(frame_to_dictionary(current_session->execution_history[i]));
    }
    data["frames"] = frames;
    data["breakpoints"] = get_breakpoints();
    
    f->store_string(JSON::stringify(data, "\t"));
    UtilityFunctions::print("[VG Debug] Session saved to: ", file_path);
}

void VisualGasicDebugger::load_session(const String& file_path) {
    Ref<FileAccess> f = FileAccess::open(file_path, FileAccess::READ);
    if (f.is_null()) {
        UtilityFunctions::printerr("[VG Debug] Failed to load session from: ", file_path);
        return;
    }
    
    String json_str = f->get_as_text();
    JSON json;
    Error err = json.parse(json_str);
    if (err != OK) {
        UtilityFunctions::printerr("[VG Debug] Failed to parse session JSON");
        return;
    }
    
    UtilityFunctions::print("[VG Debug] Session loaded from: ", file_path);
}

void VisualGasicDebugger::export_session_data(const String& format) const {
    UtilityFunctions::print("[VG Debug] Export in format: ", format, " (", 
        (int64_t)(current_session ? current_session->execution_history.size() : 0), " frames)");
}

// ============================================================================
// Memory Snapshots
// ============================================================================

Array VisualGasicDebugger::get_memory_snapshots() const {
    Array result;
    if (current_session) {
        for (size_t i = 0; i < current_session->memory_snapshots.size(); i++) {
            Dictionary snap;
            snap["timestamp"] = (int64_t)current_session->memory_snapshots[i].timestamp_us;
            snap["total_allocated"] = (int64_t)current_session->memory_snapshots[i].total_allocated;
            snap["active_allocations"] = (int64_t)current_session->memory_snapshots[i].active_allocations;
            result.push_back(snap);
        }
    }
    return result;
}

// ============================================================================
// Visual Debugging (stubs for UI integration)
// ============================================================================

void VisualGasicDebugger::show_variable_inspector() {
    UtilityFunctions::print("[VG Debug] Variable inspector opened");
}

void VisualGasicDebugger::show_performance_graph() {
    UtilityFunctions::print("[VG Debug] Performance graph opened");
}

Dictionary VisualGasicDebugger::get_execution_context() const {
    Dictionary ctx;
    if (current_session && current_frame_index < current_session->execution_history.size()) {
        const ExecutionFrame& f = current_session->execution_history[current_frame_index];
        ctx["function"] = f.function_name;
        ctx["file"] = f.file_path;
        ctx["line"] = f.line_number;
        ctx["variables"] = f.local_variables;
    }
    return ctx;
}

void VisualGasicDebugger::clear_performance_data() {
    if (current_session) {
        current_session->function_profiles.clear();
    }
    function_start_times.clear();
    function_call_counts.clear();
}

void VisualGasicDebugger::capture_current_state(ExecutionFrame& frame) {
    frame.timestamp_us = get_current_timestamp_us();
    frame.memory_usage = total_allocated_bytes - total_freed_bytes;
}

void VisualGasicDebugger::analyze_function_call_patterns() {
    // Analysis happens in identify_performance_hotspots
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