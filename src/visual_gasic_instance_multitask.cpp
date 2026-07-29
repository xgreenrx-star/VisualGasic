// ============================================================================
// Multitasking runtime + Advanced type system — extracted from visual_gasic_instance.cpp
// ============================================================================
#include "visual_gasic_instance.h"
#include "visual_gasic_parser.h"

#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/worker_thread_pool.hpp>
#include <mutex>
#include <atomic>
#include <vector>
#include <algorithm>

// === MULTITASKING RUNTIME IMPLEMENTATION ===
// v4.0: Uses Godot's WorkerThreadPool for Parallel For, Task Run,
// and Parallel Section.  Instance-level std::recursive_mutex
// (instance_mutex_) protects the shared 'variables' Dictionary.

// ---- Worker data structures for native pool callbacks ----------------------

// Data block shared among all elements of a Parallel For group task.
struct PForGroupData {
    VisualGasicInstance* instance;
    std::vector<int> indices;
    std::atomic<bool> any_error{false};
    String var_name;
    Vector<Statement*> body;
    Dictionary parent_scope;
};

// Data block for a single Task.Run submitted to the pool.
struct TaskRunPoolData {
    VisualGasicInstance* instance;
    Dictionary scope_snapshot;
    Vector<Statement*> body_copy;
    String task_name;
    int task_idx;
};

// Data block for a Parallel Section submitted to the pool.
struct PSectionPoolData {
    VisualGasicInstance* instance;
    Vector<Statement*> section_body;
    std::atomic<int> next_item{0};
    std::atomic<bool> any_error{false};
    Dictionary parent_scope;
};

// ---- Static worker callbacks (passed to WorkerThreadPool) ------------------

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

void VisualGasicInstance::_resume_coroutine() {
    // Resume a suspended coroutine after an Await signal/timer fires (v4.2.0).
    if (coroutine_stack.is_empty()) return;
    
    CoroutineState cs = coroutine_stack[coroutine_stack.size() - 1];
    coroutine_stack.remove_at(coroutine_stack.size() - 1);
    
    // Find the compiled bytecode chunk for the saved function.
    Ref<VisualGasicScript> scr = script;
    if (scr.is_null()) return;
    
    BytecodeChunk* chunk = scr->get_bytecode_for(cs.function_name, &get_global_buffer_var_names());
    SubDefinition* func_def = nullptr;
    
    // Look up the SubDefinition so execute_bytecode can set current_sub
    if (scr->ast_root) {
        for (int i = 0; i < scr->ast_root->subs.size(); i++) {
            if (scr->ast_root->subs[i]->name.nocasecmp_to(cs.function_name) == 0) {
                func_def = scr->ast_root->subs[i];
                break;
            }
        }
    }
    
    if (!chunk) return; // Cannot resume without compiled chunk
    
    // Merge saved locals back into instance variables (they'll be picked up
    // by the VM's get_variable path).
    Array keys = cs.local_variables.keys();
    for (int i = 0; i < keys.size(); i++) {
        variables[keys[i]] = cs.local_variables[keys[i]];
    }
    
    Variant ret;
    execute_bytecode(chunk, func_def, ret, cs.instruction_pointer);
}

void VisualGasicInstance::execute_task_run(TaskRunStatement* task) {
    TaskInfo task_info;
    task_info.task_name = task->task_name.is_empty() ? "Task_" + String::num(active_tasks.size()) : task->task_name;
    task_info.task_body = task->task_body;
    task_info.is_background = task->is_background;
    task_info.is_completed = false;

    Dictionary scope_snapshot = variables.duplicate(true);
    Vector<Statement*> body_copy = task->task_body;
    String t_name = task_info.task_name;
    int task_idx = active_tasks.size();

    // Allocate worker data on the heap (freed after join/completion).
    TaskRunPoolData* data = new TaskRunPoolData();
    data->instance = this;
    data->scope_snapshot = scope_snapshot;
    data->body_copy = body_copy;
    data->task_name = t_name;
    data->task_idx = task_idx;

    // Submit to Godot's WorkerThreadPool.
    WorkerThreadPool* pool = WorkerThreadPool::get_singleton();
    int64_t pool_task_id = pool->add_native_task(&VisualGasicInstance::_task_worker_function, data);

    task_info.task_id = pool_task_id;
    active_tasks.push_back(task_info);

    if (!task->is_background) {
        // Non-background: block until done.
        pool->wait_for_task_completion(pool_task_id);
        active_tasks.write[task_idx].is_completed = true;
        delete data;
    }
    // Background tasks are cleaned up in execute_task_wait / update_tasks.
}

void VisualGasicInstance::execute_task_wait(TaskWaitStatement* wait_stmt) {
    WorkerThreadPool* pool = WorkerThreadPool::get_singleton();

    if (wait_stmt->wait_all) {
        // WaitAll — block until every named task (or all active tasks) completes.
        if (wait_stmt->task_names.size() > 0) {
            for (int i = 0; i < wait_stmt->task_names.size(); i++) {
                String task_name = wait_stmt->task_names[i];
                for (int j = 0; j < active_tasks.size(); j++) {
                    if (active_tasks[j].task_name == task_name && !active_tasks[j].is_completed) {
                        if (active_tasks[j].task_id >= 0) {
                            pool->wait_for_task_completion(active_tasks[j].task_id);
                        }
                        active_tasks.write[j].is_completed = true;
                        break;
                    }
                }
            }
        } else {
            // No names specified — wait for ALL active tasks.
            for (int j = 0; j < active_tasks.size(); j++) {
                if (!active_tasks[j].is_completed && active_tasks[j].task_id >= 0) {
                    pool->wait_for_task_completion(active_tasks[j].task_id);
                    active_tasks.write[j].is_completed = true;
                }
            }
        }
    } else {
        // WaitAny — block until at least one named task completes.
        // Poll in a tight loop (WorkerThreadPool doesn't have a WaitAny API).
        bool found = false;
        while (!found) {
            for (int i = 0; i < active_tasks.size(); i++) {
                if (!active_tasks[i].is_completed && active_tasks[i].task_id >= 0) {
                    if (pool->is_task_completed(active_tasks[i].task_id)) {
                        active_tasks.write[i].is_completed = true;
                        found = true;
                        break;
                    }
                }
            }
            if (!found) {
                // Yield briefly to avoid busy-spin.
                OS::get_singleton()->delay_usec(100);
            }
        }
    }
}

void VisualGasicInstance::execute_parallel_for(ParallelForStatement* par_for) {
    int start = (int)evaluate_expression(par_for->start_expr);
    int end   = (int)evaluate_expression(par_for->end_expr);
    int step  = par_for->step_expr ? (int)evaluate_expression(par_for->step_expr) : 1;
    if (step == 0) step = 1;

    // Determine iteration count
    int iter_count = 0;
    for (int i = start; (step > 0 ? i <= end : i >= end); i += step) iter_count++;
    if (iter_count <= 0) return;

    // AST interpreter shares instance variables[] across all iterations
    // (mutex serialises workers).  Use a direct loop for modest counts
    // to avoid thread-pool dispatch/join overhead.
    if (iter_count <= 128) {
        for (int i = start; (step > 0 ? i <= end : i >= end); i += step) {
            variables[par_for->variable_name] = i;
            for (int j = 0; j < par_for->body.size(); j++) {
                execute_statement(par_for->body[j]);
                if (error_state.has_error || error_state.mode != ErrorState::NONE) return;
            }
        }
        return;
    }

    // Build iteration indices
    PForGroupData data;
    data.instance = this;
    data.indices.reserve(iter_count);
    for (int i = start; (step > 0 ? i <= end : i >= end); i += step)
        data.indices.push_back(i);
    data.var_name = par_for->variable_name;
    data.body = par_for->body;

    // Submit as a group task — WorkerThreadPool distributes elements
    // across its thread pool automatically.
    WorkerThreadPool* pool = WorkerThreadPool::get_singleton();
    int64_t group_id = pool->add_native_group_task(
        &VisualGasicInstance::_parallel_worker_function,
        &data,
        iter_count,
        -1,       // tasks_needed = auto (let the pool decide)
        false     // not high priority
    );

    // Block until all elements are done.
    pool->wait_for_group_task_completion(group_id);
}

void VisualGasicInstance::execute_parallel_section(ParallelSectionStatement* par_section) {
    int n = par_section->section_body.size();
    if (n == 0) return;

    // For tiny sections just run serially
    if (n <= 2) {
        for (int i = 0; i < n; i++) {
            execute_statement(par_section->section_body[i]);
            if (error_state.has_error || error_state.mode != ErrorState::NONE) return;
        }
        return;
    }

    // Submit each section statement as a WorkerThreadPool task.
    PSectionPoolData data;
    data.instance = this;
    data.section_body = par_section->section_body;
    data.parent_scope = variables.duplicate(true);

    WorkerThreadPool* pool = WorkerThreadPool::get_singleton();
    int64_t group_id = pool->add_native_group_task(
        [](void* ud, uint32_t index) {
            PSectionPoolData* d = static_cast<PSectionPoolData*>(ud);
            if (d->any_error.load()) return;

            VisualGasicInstance* inst = d->instance;
            std::lock_guard<std::recursive_mutex> lock(inst->instance_mutex_);

            // Shallow copy for section isolation (sections are few, so
            // one shallow COW copy each is acceptable).
            Dictionary saved = inst->variables;
            inst->variables = d->parent_scope.duplicate(false);

            inst->execute_statement(d->section_body[index]);
            if (inst->error_state.has_error || inst->error_state.mode != VisualGasicInstance::ErrorState::NONE) {
                d->any_error.store(true);
            }

            inst->variables = saved;
        },
        &data,
        n,
        -1,
        false
    );

    pool->wait_for_group_task_completion(group_id);
}

void VisualGasicInstance::update_tasks() {
    // Check for completed tasks and clean up
    for (int i = active_tasks.size() - 1; i >= 0; i--) {
        if (active_tasks[i].is_completed) {
            // Task finished - could remove or keep for result access
        }
    }
}

// Static worker callback for Task.Run — called by WorkerThreadPool.
void VisualGasicInstance::_task_worker_function(void* user_data) {
    TaskRunPoolData* data = static_cast<TaskRunPoolData*>(user_data);
    VisualGasicInstance* inst = data->instance;

    Variant result;
    bool had_error = false;

    {
        std::lock_guard<std::recursive_mutex> lock(inst->instance_mutex_);

        Dictionary saved = inst->variables;
        inst->variables = data->scope_snapshot;

        for (int i = 0; i < data->body_copy.size(); i++) {
            inst->execute_statement(data->body_copy[i]);
            if (inst->error_state.has_error || inst->error_state.mode != ErrorState::NONE) {
                had_error = true;
                break;
            }
        }
        result = had_error ? Variant("Task failed") : Variant("Task completed");
        inst->variables = saved;
    }

    if (data->task_idx < (int)inst->active_tasks.size()) {
        inst->active_tasks.write[data->task_idx].is_completed = true;
        inst->active_tasks.write[data->task_idx].result = result;
    }
    inst->task_results[data->task_name] = result;
}

// Static group-worker callback for Parallel For — called once per element.
// The mutex serialises iterations; body runs against the live variables[]
// dict so modifications persist across iterations (matching serial semantics).
// No per-iteration deep Dictionary clone — just set the loop variable.
void VisualGasicInstance::_parallel_worker_function(void* user_data, uint32_t index) {
    PForGroupData* data = static_cast<PForGroupData*>(user_data);
    if (data->any_error.load()) return;

    VisualGasicInstance* inst = data->instance;
    std::lock_guard<std::recursive_mutex> lock(inst->instance_mutex_);

    inst->variables[data->var_name] = data->indices[index];

    for (int j = 0; j < data->body.size(); j++) {
        inst->execute_statement(data->body[j]);
        if (inst->error_state.has_error || inst->error_state.mode != VisualGasicInstance::ErrorState::NONE) {
            data->any_error.store(true);
            break;
        }
    }
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
    // NOTE: Caller is responsible for deleting the returned pointer.
    // Consider migrating to std::unique_ptr in the future.
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
