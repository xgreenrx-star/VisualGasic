// ============================================================================
// Multitasking runtime + Advanced type system — extracted from visual_gasic_instance.cpp
// ============================================================================
#include "visual_gasic_instance.h"
#include "visual_gasic_parser.h"

#include <godot_cpp/variant/utility_functions.hpp>

// === MULTITASKING RUNTIME IMPLEMENTATION ===

void VisualGasicInstance::execute_async_function(AsyncFunctionStatement* async_func) {
    // For now, async functions run immediately (simplified implementation)
    // In full implementation, this would set up coroutine state
    
    CoroutineState coroutine;
    coroutine.function_name = async_func->function_name;
    coroutine.remaining_statements = async_func->body;
    coroutine.instruction_pointer = 0;
    
    // Create local scope for function parameters
    Dictionary backup_vars = variables;
    
    // Set parameter values (simplified)
    for (int i = 0; i < async_func->parameters.size(); i++) {
        variables[async_func->parameters[i]->name] = Variant(); // Default values
    }
    
    // Execute function body
    for (int i = 0; i < async_func->body.size(); i++) {
        execute_statement(async_func->body[i]);
        if (error_state.has_error || error_state.mode != ErrorState::NONE) {
            break;
        }
    }
    
    // Restore variables (simplified scope handling)
    variables = backup_vars;
}

Variant VisualGasicInstance::execute_await(ExpressionNode* expr) {
    // Evaluate the awaited expression
    Variant result = evaluate_expression(expr);
    
    // In real implementation, this would check if result is a Task/Promise
    // and yield execution until completion
    
    // For now, just return the result immediately
    return result;
}

void VisualGasicInstance::execute_task_run(TaskRunStatement* task) {
    TaskInfo task_info;
    task_info.task_name = task->task_name.is_empty() ? "Task_" + String::num(active_tasks.size()) : task->task_name;
    task_info.task_body = task->task_body;
    task_info.is_background = task->is_background;
    task_info.is_completed = false;
    
    // Execute task body synchronously as fallback
    // (True async via WorkerThreadPool is planned for a future release)
    // The previous guard `is_in_physics_frame()` prevented execution when
    // called from _Process (idle frame), which is the common case for
    // input-driven task launches.  Remove the guard so the body always runs.
    {
        // Execute task body
        for (int i = 0; i < task->task_body.size(); i++) {
            execute_statement(task->task_body[i]);
            if (error_state.has_error || error_state.mode != ErrorState::NONE) {
                break;
            }
        }
        task_info.is_completed = true;
        task_info.result = Variant("Task completed");
    }
    
    active_tasks.push_back(task_info);
    task_results[task_info.task_name] = task_info.result;
}

void VisualGasicInstance::execute_task_wait(TaskWaitStatement* wait_stmt) {
    if (wait_stmt->wait_all) {
        // Wait for all specified tasks
        for (int i = 0; i < wait_stmt->task_names.size(); i++) {
            String task_name = wait_stmt->task_names[i];
            // Find and wait for task completion
            for (int j = 0; j < active_tasks.size(); j++) {
                if (active_tasks[j].task_name == task_name) {
                    // In real implementation, would wait for actual completion
                    break;
                }
            }
        }
    } else {
        // Wait for any task to complete (WaitAny)
        // Simplified: just check if any task is completed
        for (int i = 0; i < active_tasks.size(); i++) {
            if (active_tasks[i].is_completed) {
                break;
            }
        }
    }
}

struct ParallelForWorkerData {
    VisualGasicInstance* instance;
    ParallelForStatement* par_for;
    int start_index;
    int end_index;
    int step;
};

void VisualGasicInstance::execute_parallel_for(ParallelForStatement* par_for) {
    int start = (int)evaluate_expression(par_for->start_expr);
    int end = (int)evaluate_expression(par_for->end_expr);
    int step = par_for->step_expr ? (int)evaluate_expression(par_for->step_expr) : 1;
    
    // For safety, execute sequentially for now
    // In full implementation, would use WorkerThreadPool
    for (int i = start; (step > 0 ? i <= end : i >= end); i += step) {
        // Set loop variable
        variables[par_for->variable_name] = i;
        
        // Execute loop body
        for (int j = 0; j < par_for->body.size(); j++) {
            execute_statement(par_for->body[j]);
            if (error_state.has_error || error_state.mode != ErrorState::NONE) {
                break;
            }
        }
    }
}

void VisualGasicInstance::execute_parallel_section(ParallelSectionStatement* par_section) {
    // Execute section sequentially for safety
    // In full implementation, would distribute work across threads
    for (int i = 0; i < par_section->section_body.size(); i++) {
        execute_statement(par_section->section_body[i]);
        if (error_state.has_error || error_state.mode != ErrorState::NONE) {
            break;
        }
    }
}

void VisualGasicInstance::update_tasks() {
    // Check for completed tasks and clean up
    for (int i = active_tasks.size() - 1; i >= 0; i--) {
        if (active_tasks[i].is_completed) {
            // Task finished - could remove or keep for result access
        }
    }
}

// Static worker functions for thread pool integration
void VisualGasicInstance::_task_worker_function(void* user_data) {
    TaskInfo* task = static_cast<TaskInfo*>(user_data);
    // Execute task body in worker thread
    // This would require thread-safe execution context
}

void VisualGasicInstance::_parallel_worker_function(void* user_data, uint32_t index) {
    ParallelForWorkerData* data = static_cast<ParallelForWorkerData*>(user_data);
    // Execute parallel work item
    // This would require thread-safe variable access
}

// === ADVANCED TYPE SYSTEM RUNTIME ===

void VisualGasicInstance::execute_pattern_match(PatternMatchStatement* match_stmt) {
    Variant value = evaluate_expression(match_stmt->expression);
    
    Dictionary captured_vars;
    
    // Try each case in order
    for (int i = 0; i < match_stmt->cases.size(); i++) {
        MatchCase* match_case = match_stmt->cases[i];
        
        if (pattern_matches(match_case->pattern, value, captured_vars)) {
            // Save current variable state
            Dictionary backup_vars = variables;
            
            // Add captured variables to scope
            Array keys = captured_vars.keys();
            for (int j = 0; j < keys.size(); j++) {
                String key = keys[j];
                variables[key] = captured_vars[key];
            }
            
            // Execute case statements
            for (int j = 0; j < match_case->statements.size(); j++) {
                execute_statement(match_case->statements[j]);
                if (error_state.has_error || error_state.mode != ErrorState::NONE) {
                    break;
                }
            }
            
            // Restore variable state (remove captured vars)
            variables = backup_vars;
            return; // Exit after first match
        }
    }
    
    // No pattern matched - could be an error or have a default case
}

bool VisualGasicInstance::pattern_matches(Pattern* pattern, const Variant& value, Dictionary& captured_vars) {
    switch (pattern->type) {
        case Pattern::LITERAL_PATTERN: {
            return value == pattern->literal_value;
        }
        
        case Pattern::VARIABLE_PATTERN: {
            if (pattern->variable_name == "_") {
                return true; // Wildcard matches anything
            }
            captured_vars[pattern->variable_name] = value;
            return true;
        }
        
        case Pattern::TYPE_PATTERN: {
            // Check if value is of the expected type
            String value_type = Variant::get_type_name(value.get_type());
            bool type_matches = (value_type.to_lower() == pattern->type_name.to_lower());
            
            if (type_matches && pattern->sub_patterns.size() > 0) {
                // Destructure the value (simplified)
                if (value.get_type() == Variant::DICTIONARY) {
                    Dictionary dict = value;
                    Array keys = dict.keys();
                    
                    for (int i = 0; i < pattern->sub_patterns.size() && i < keys.size(); i++) {
                        Pattern* sub_pattern = pattern->sub_patterns[i];
                        if (sub_pattern->type == Pattern::VARIABLE_PATTERN) {
                            captured_vars[sub_pattern->variable_name] = dict[keys[i]];
                        }
                    }
                }
            }
            
            return type_matches;
        }
        
        case Pattern::GUARD_PATTERN: {
            // Guard expressions are evaluated as conditions
            if (pattern->guard_expression) {
                Variant guard_result = evaluate_expression(pattern->guard_expression);
                return (bool)guard_result;
            }
            return true;
        }
        
        default:
            return false;
    }
}

AdvancedType* VisualGasicInstance::infer_type(const Variant& value) {
    AdvancedType* type = new AdvancedType();
    
    switch (value.get_type()) {
        case Variant::INT:
            type->base_type = "Integer";
            break;
        case Variant::FLOAT:
            type->base_type = "Double";
            break;
        case Variant::STRING:
            type->base_type = "String";
            break;
        case Variant::BOOL:
            type->base_type = "Boolean";
            break;
        case Variant::ARRAY:
            type->base_type = "Array";
            type->kind = AdvancedType::ARRAY;
            break;
        case Variant::DICTIONARY:
            type->base_type = "Dictionary";
            break;
        default:
            type->base_type = "Object";
            break;
    }
    
    return type;
}

bool VisualGasicInstance::is_type_compatible(const AdvancedType* expected, const AdvancedType* actual) {
    if (!expected || !actual) return false;
    
    // Basic type compatibility
    if (expected->base_type == actual->base_type) return true;
    
    // Optional type compatibility
    if (expected->is_optional && actual->base_type == expected->base_type) {
        return true;
    }
    
    // Union type compatibility (simplified)
    if (expected->kind == AdvancedType::UNION) {
        for (int i = 0; i < expected->union_types.size(); i++) {
            if (is_type_compatible(expected->union_types[i], actual)) {
                return true;
            }
        }
    }
    
    return false;
}
