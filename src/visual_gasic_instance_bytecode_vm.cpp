// ============================================================================
// Bytecode VM execution — extracted from visual_gasic_instance.cpp
// ============================================================================
#include "visual_gasic_instance.h"
#include "visual_gasic_instance_internal.h"
#include "visual_gasic_language.h"
#include "visual_gasic_parser.h"
#include "visual_gasic_builtins.h"
#include "visual_gasic_debugger.h"
#include "visual_gasic_profiler.h"
#include "visual_gasic_jit_tier2.h"
#include "gasic_ai_controller.h"
#include "visual_gasic_comm.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/node2d.hpp>
#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/classes/window.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/packed_scene.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/classes/timer.hpp>
#include <godot_cpp/classes/tween.hpp>
#include <godot_cpp/classes/property_tweener.hpp>
#include <godot_cpp/classes/sprite2d.hpp>
#include <godot_cpp/classes/texture2d.hpp>
#include <godot_cpp/classes/audio_stream.hpp>
#include <godot_cpp/classes/audio_stream_player.hpp>
#include <godot_cpp/classes/label.hpp>
#include <godot_cpp/classes/button.hpp>
#include <godot_cpp/classes/line_edit.hpp>
#include <godot_cpp/classes/text_edit.hpp>
#include <godot_cpp/classes/accept_dialog.hpp>
#include <godot_cpp/classes/confirmation_dialog.hpp>
#include <godot_cpp/classes/display_server.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/classes/engine_debugger.hpp>
#include <godot_cpp/classes/character_body2d.hpp>
#include <godot_cpp/classes/character_body3d.hpp>
#include <godot_cpp/classes/rigid_body2d.hpp>
#include <godot_cpp/classes/rigid_body3d.hpp>
#include <godot_cpp/classes/collision_shape2d.hpp>
#include <godot_cpp/classes/collision_shape3d.hpp>
#include <godot_cpp/classes/rectangle_shape2d.hpp>
#include <godot_cpp/classes/circle_shape2d.hpp>
#include <godot_cpp/classes/sphere_shape3d.hpp>
#include <godot_cpp/classes/area2d.hpp>
#include <godot_cpp/classes/mesh_instance3d.hpp>
#include <godot_cpp/classes/box_mesh.hpp>
#include <godot_cpp/classes/sphere_mesh.hpp>
#include <godot_cpp/classes/standard_material3d.hpp>
#include <godot_cpp/classes/shader.hpp>
#include <godot_cpp/classes/shader_material.hpp>
#include <godot_cpp/classes/font.hpp>
#include <godot_cpp/classes/theme_db.hpp>
#include <godot_cpp/classes/theme.hpp>
#include <godot_cpp/classes/style_box_flat.hpp>
#include <godot_cpp/classes/gpu_particles2d.hpp>
#include <godot_cpp/classes/gpu_particles3d.hpp>
#include <godot_cpp/classes/particle_process_material.hpp>
#include <godot_cpp/classes/h_box_container.hpp>
#include <godot_cpp/classes/v_box_container.hpp>
#include <godot_cpp/classes/progress_bar.hpp>
#include <godot_cpp/classes/h_slider.hpp>
#include <godot_cpp/classes/v_slider.hpp>
#include <godot_cpp/classes/item_list.hpp>
#include <godot_cpp/classes/tree.hpp>
#include <godot_cpp/classes/tree_item.hpp>
#include <godot_cpp/classes/config_file.hpp>
#include <godot_cpp/classes/kinematic_collision2d.hpp>
#include <godot_cpp/classes/kinematic_collision3d.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/variant_internal.hpp>
#include <godot_cpp/core/object.hpp>
#include <godot_cpp/godot.hpp>

#include <cstdlib>
#include <limits>
#include <atomic>
#include <mutex>
#include <godot_cpp/classes/worker_thread_pool.hpp>

// Data block for bytecode Parallel For group task.
struct PForBytecodeData {
    VisualGasicInstance* instance;
    BytecodeChunk* chunk;
    SubDefinition* func;
    int body_start_ip;
    int body_end_ip;
    int var_slot;
    bool needs_lock;  // true only when body contains OP_LOCK
    std::vector<int64_t> indices;
    std::atomic<bool> any_error{false};
    Vector<Variant> parent_locals;  // snapshot of parent scope locals for lock-free workers
};

// Thread-local flag: set to true inside WorkerThreadPool callbacks so that
// execute_bytecode() can skip non-thread-safe debug/profiling code.
static thread_local bool tl_on_worker_thread = false;

// RAII guard that sets tl_on_worker_thread for the scope of a worker callback.
struct WorkerThreadGuard {
    bool prev;
    WorkerThreadGuard() : prev(tl_on_worker_thread) { tl_on_worker_thread = true; }
    ~WorkerThreadGuard() { tl_on_worker_thread = prev; }
};

// Static group-worker callback for bytecode Parallel For.
// Lock-free path: each worker gets its own locals snapshot + thread-local
// VM state inside execute_bytecode, achieving true parallel execution.
// Locked path (body contains Lock/Unlock): GIL-style serialisation so
// shared accumulator patterns work correctly through variables[].
void VisualGasicInstance::_pfor_bytecode_worker(void* user_data, uint32_t index) {
    WorkerThreadGuard _wg;  // Mark this thread as a worker for execute_bytecode
    PForBytecodeData* d = static_cast<PForBytecodeData*>(user_data);
    if (d->any_error.load(std::memory_order_relaxed)) return;

    VisualGasicInstance* inst = d->instance;

    if (d->needs_lock) {
        // Locked path: body uses Lock/Unlock — serialise through variables[].
        std::lock_guard<std::recursive_mutex> lock(inst->instance_mutex_);

        bool saved_vs = inst->needs_var_sync;
        inst->needs_var_sync = true;

        if (d->var_slot >= 0 && d->var_slot < d->chunk->local_names.size()) {
            String var_name = d->chunk->local_names[d->var_slot];
            if (!var_name.is_empty()) {
                inst->variables[var_name] = Variant(d->indices[index]);
            }
        }

        Variant ret;
        bool ok = inst->execute_bytecode(d->chunk, d->func, ret,
                                          d->body_start_ip, d->body_end_ip,
                                          nullptr);
        if (!ok) {
            d->any_error.store(true, std::memory_order_relaxed);
        }

        inst->needs_var_sync = saved_vs;
    } else {
        // Lock-free path: each worker gets isolated locals + thread-local VM.
        // No mutex, no shared Dictionary access — true parallel execution.
        // Godot Vector is COW so this copy is cheap until the worker writes.
        Vector<Variant> worker_locals = d->parent_locals;
        if (d->var_slot >= 0 && d->var_slot < worker_locals.size()) {
            worker_locals.write[d->var_slot] = Variant(d->indices[index]);
        }

        Variant ret;
        bool ok = inst->execute_bytecode(d->chunk, d->func, ret,
                                          d->body_start_ip, d->body_end_ip,
                                          &worker_locals);
        if (!ok) d->any_error.store(true, std::memory_order_relaxed);
    }
}

// Data block for bytecode Task.Run submitted to WorkerThreadPool.
struct TaskRunBCData {
    VisualGasicInstance* instance;
    BytecodeChunk* chunk;
    SubDefinition* func;
    int body_start_ip;
    int body_end_ip;
    String task_name;
    int task_idx;
    std::atomic<bool> error{false};
};

// Static worker callback for bytecode Task.Run.
void VisualGasicInstance::_task_run_bc_worker(void* user_data) {
    WorkerThreadGuard _wg;  // Mark this thread as a worker for execute_bytecode
    TaskRunBCData* d = static_cast<TaskRunBCData*>(user_data);
    VisualGasicInstance* inst = d->instance;
    std::lock_guard<std::recursive_mutex> lock(inst->instance_mutex_);

    bool saved_var_sync = inst->needs_var_sync;
    inst->needs_var_sync = true;

    Variant ret;
    bool ok = inst->execute_bytecode(d->chunk, d->func, ret,
                                      d->body_start_ip, d->body_end_ip,
                                      nullptr);
    if (!ok) {
        d->error.store(true, std::memory_order_relaxed);
    }

    inst->needs_var_sync = saved_var_sync;

    if (d->task_idx < (int)inst->active_tasks.size()) {
        inst->active_tasks.write[d->task_idx].is_completed = true;
        inst->active_tasks.write[d->task_idx].result = ok ? Variant("Task completed") : Variant("Task failed");
    }
    inst->task_results[d->task_name] = ok ? Variant("Task completed") : Variant("Task failed");
}

bool VisualGasicInstance::execute_bytecode(BytecodeChunk* chunk, SubDefinition* func, Variant &r_ret,
                                           int p_ip_start, int p_ip_end,
                                           const Vector<Variant>* p_initial_locals) {
    if (!chunk) {
        r_ret = Variant();
        return false;
    }

    // Detect when running on a WorkerThreadPool thread.  Worker callbacks
    // set the file-scope thread_local tl_on_worker_thread flag via
    // WorkerThreadGuard.  When true, skip all non-thread-safe debug/
    // profiling infrastructure (debug stack, EngineDebugger, debug_state,
    // opcode profiling, etc.) to avoid data races and crashes.
    const bool is_parallel_worker = tl_on_worker_thread;

    // Also skip debug stack for sub-range execution (serial fallback bodies)
    const bool is_sub_range = (p_ip_end > 0);

    // Push debug stack frame for Godot debugger integration
    // (skip for parallel workers AND sub-range bodies — these are internal
    // recursive calls that don't need their own stack frames)
    String debug_file = (!is_parallel_worker && !is_sub_range && script.is_valid()) ? script->get_path() : String("<unknown>");
    if (!is_parallel_worker && !is_sub_range) {
        String debug_func = func ? func->name : String("<main>");
        VisualGasicLanguage::push_stack_frame(debug_file, debug_func, 0, this);
    }

    const bool profiling_enabled = !is_parallel_worker && vg_opcode_profile_enabled();
    const bool is_outermost_profile = profiling_enabled && vg_opcode_profile_depth == 0;
    if (profiling_enabled) {
        if (is_outermost_profile) {
            opcode_profile_reset();
        }
        vg_opcode_profile_depth++;
    }

    const bool stack_profile_enabled = !is_parallel_worker && vg_stack_profile_enabled();
    const bool stack_trace_enabled = !is_parallel_worker && []() {
        const char *trace_env = std::getenv("VG_STACK_TRACE");
        return trace_env && trace_env[0] != '\0' && trace_env[0] != '0';
    }();
    StackProfileSample stack_profile_sample;
    String stack_profile_label = "<bytecode>";
    if (stack_profile_enabled) {
        String func_label = func ? func->name : String();
        String script_label;
        if (script.is_valid()) {
            script_label = script->get_path();
        }
        if (!func_label.is_empty() && !script_label.is_empty()) {
            stack_profile_label = func_label + "@" + script_label;
        } else if (!func_label.is_empty()) {
            stack_profile_label = func_label;
        } else if (!script_label.is_empty()) {
            stack_profile_label = script_label;
        }
    }

    // Thread-local VM state: each OS thread gets its own execution stack
    // and instruction pointer.  Parallel-for workers running on different
    // pool threads execute bytecode concurrently without conflicting.
    // Recursive calls (OP_CALL → call_internal → execute_bytecode) nest
    // correctly via the stack_base / previous_ip save-restore pattern.
    static thread_local VMState tl_vm;
    auto& vm = tl_vm;  // shadow instance member for thread-safety

    const size_t stack_base = vm.stack.size();
    int previous_ip = vm.ip;
    vm.stack.resize(stack_base);
    vm.ip = p_ip_start;  // Start at custom IP for parallel workers

    auto restore_vm = [&]() {
        vm.stack.resize(stack_base);
        vm.ip = previous_ip;
    };

    // ── JIT Tier 2: attempt native execution for hot functions ──────────
#ifdef __linux__
    if (p_ip_start == 0 && p_ip_end <= 0 && func && !p_initial_locals) {
        std::string jit_name;
        if (func->name.length() > 0) {
            jit_name = std::string(func->name.utf8().get_data());
        }
        if (!jit_name.empty()) {
            vgjit2::CompiledFunc* native = vgjit2::thread_jit().get_or_compile(jit_name, chunk);
            if (native && native->fn) {
                // Marshal locals + virtual global slots into int64 array
                int slot_count = native->total_slots > 0 ? native->total_slots : chunk->local_count;
                if (slot_count < 1) slot_count = 1;
                std::vector<int64_t> jit_locals(slot_count, 0);
                // Pre-populate real locals from variable values
                for (int i = 0; i < chunk->local_count && i < chunk->local_names.size(); i++) {
                    const String &lname = chunk->local_names[i];
                    if (!lname.is_empty() && variables.has(lname)) {
                        Variant v = variables[lname];
                        if (v.get_type() == Variant::INT) {
                            jit_locals[i] = (int64_t)v;
                        } else if (v.get_type() == Variant::FLOAT) {
                            double d = (double)v;
                            memcpy(&jit_locals[i], &d, 8);
                        }
                    }
                }
                // Pre-populate virtual global slots from variables dictionary
                for (const auto& gs : native->global_slots) {
                    String gname = String(gs.first.c_str());
                    int slot = gs.second;
                    if (slot >= 0 && slot < slot_count && variables.has(gname)) {
                        Variant v = variables[gname];
                        if (v.get_type() == Variant::INT) {
                            jit_locals[slot] = (int64_t)v;
                        } else if (v.get_type() == Variant::FLOAT) {
                            double d = (double)v;
                            memcpy(&jit_locals[slot], &d, 8);
                        }
                    }
                }
                int64_t has_retval = native->fn(jit_locals.data(), (int64_t)slot_count);
                // Sync real locals back to variables
                for (int i = 0; i < chunk->local_count && i < chunk->local_names.size(); i++) {
                    const String &lname = chunk->local_names[i];
                    if (!lname.is_empty()) {
                        variables[lname] = Variant((int64_t)jit_locals[i]);
                    }
                }
                // Sync virtual global slots back to variables
                for (const auto& gs : native->global_slots) {
                    String gname = String(gs.first.c_str());
                    int slot = gs.second;
                    if (slot >= 0 && slot < slot_count) {
                        variables[gname] = Variant((int64_t)jit_locals[slot]);
                    }
                }
                if (has_retval) {
                    r_ret = Variant((int64_t)jit_locals[0]);
                } else {
                    // VB6 convention: FunctionName = value sets return via
                    // OP_SET_GLOBAL. Check if the function name has a global
                    // slot and use that as the return value.
                    bool found_ret = false;
                    if (func) {
                        std::string fn_name(func->name.utf8().get_data());
                        for (const auto& gs : native->global_slots) {
                            if (gs.first == fn_name) {
                                int slot = gs.second;
                                if (slot >= 0 && slot < slot_count) {
                                    r_ret = Variant((int64_t)jit_locals[slot]);
                                    found_ret = true;
                                }
                                break;
                            }
                        }
                    }
                    if (!found_ret) {
                        r_ret = Variant();
                    }
                }
                return true;
            }
        }
    }
#endif
    // ── End JIT Tier 2 ────────────────────────────────────────────────

    Vector<Variant> locals;
    if (p_initial_locals) {
        // Parallel worker — use pre-initialized locals (with loop var set).
        locals = *p_initial_locals;
    } else {
        locals.resize(chunk->local_count);
        for (int i = 0; i < chunk->local_count; i++) {
            Variant initial;
            if (i < chunk->local_names.size()) {
                const String &name = chunk->local_names[i];
                if (!name.is_empty() && variables.has(name)) {
                    initial = variables[name];
                }
            }
            locals.write[i] = initial;
        }
    }

    // When running as a parallel worker (p_initial_locals provided), keep
    // all local variable access thread-local — never touch the shared
    // variables[] Dictionary.  This enables lock-free parallel execution.
    const bool isolated_locals = (p_initial_locals != nullptr);

    auto get_local_name = [&](int slot) -> String {
        if (slot >= 0 && slot < chunk->local_names.size()) {
            return chunk->local_names[slot];
        }
        return String();
    };

    auto sync_local = [&](int slot, const Variant &value) {
        if (slot < 0 || slot >= locals.size()) {
            return;
        }
        locals.write[slot] = value;
        // Fast path: skip the expensive variables[] Dictionary sync
        // when no Whenever callbacks need it (v2.4.1 optimisation).
        // Also skip when running as isolated parallel worker (v4.1).
        if (needs_var_sync && !isolated_locals) {
            String name = get_local_name(slot);
            if (!name.is_empty()) {
                variables[name] = value;
            }
        }
    };

    auto read_local = [&](int slot) -> Variant {
        if (slot >= 0 && slot < locals.size()) {
            // Fast path: when no Whenever sections exist or when running
            // as an isolated parallel worker, skip the expensive
            // variables[] HashMap lookup entirely (v2.4.1 / v4.1).
            if (!needs_var_sync || isolated_locals) {
                return locals[slot];
            }
            // Slow path: read from variables dictionary to pick up
            // changes made by Whenever callbacks or nested calls
            String name = get_local_name(slot);
            if (!name.is_empty() && variables.has(name)) {
                Variant current = variables[name];
                locals.write[slot] = current;
                return current;
            }
            return locals[slot];
        }
        return Variant();
    };

    auto pop_value = [&]() -> Variant {
        if (vm.stack.size() <= stack_base) {
            if (stack_profile_enabled) {
                stack_profile_sample.underflow_count++;
            }
            return Variant();
        }
        int top_idx = vm.stack.size() - 1;
        Variant v = std::move(vm.stack[top_idx]);
        vm.stack.pop_back();
        if (stack_profile_enabled) {
            stack_profile_sample.pop_count++;
        }
        return v;
    };

    uint8_t current_opcode = 0;
    int last_opcode_offset = 0;

    auto push_value = [&](auto &&value) {
        vm.stack.push_back(std::forward<decltype(value)>(value));
        if (stack_profile_enabled) {
            stack_profile_sample.push_count++;
            uint64_t depth = (uint64_t)(vm.stack.size() - stack_base);
            if (depth > stack_profile_sample.max_depth) {
                stack_profile_sample.max_depth = depth;
                stack_profile_sample.growth_events++;
                if (stack_trace_enabled) {
                    UtilityFunctions::print("[VG_STACK_TRACE] depth=", (int64_t)depth,
                        " op=", (int)current_opcode,
                        " offset=", last_opcode_offset);
                }
            }
        }
    };

    auto to_int = [&](const Variant &value) -> int64_t {
        switch (value.get_type()) {
            case Variant::INT:
                return (int64_t)value;
            case Variant::FLOAT:
                return (int64_t)((double)value);
            case Variant::BOOL:
                return (bool)value ? 1 : 0;
            case Variant::STRING:
                return ((String)value).to_int();
            default:
                return (int64_t)value;
        }
    };

    auto to_double = [&](const Variant &value) -> double {
        switch (value.get_type()) {
            case Variant::FLOAT:
                return (double)value;
            case Variant::INT:
                return (double)((int64_t)value);
            case Variant::BOOL:
                return (bool)value ? 1.0 : 0.0;
            case Variant::STRING:
                return ((String)value).to_float();
            default:
                return (double)value;
        }
    };

    auto to_bool = [&](const Variant &value) -> bool {
        switch (value.get_type()) {
            case Variant::BOOL:
                return (bool)value;
            case Variant::INT:
                return (int64_t)value != 0;
            case Variant::FLOAT:
                return !Math::is_zero_approx((double)value);
            case Variant::STRING:
                return !String(value).is_empty();
            case Variant::NIL:
                return false;
            default:
                return value != Variant();
        }
    };

    auto ensure_stack = [&](int count) -> bool {
        if ((int)(vm.stack.size() - stack_base) < count) {
            if (stack_profile_enabled) {
                stack_profile_sample.underflow_count++;
            }
            UtilityFunctions::printerr("VisualGasic: bytecode stack underflow in ",
                func ? func->name : "<null>", " need=", count,
                " have=", (int64_t)(vm.stack.size() - stack_base),
                " ip=", vm.ip, " last_op=", (int)current_opcode,
                " code_size=", (int)chunk->code.size(),
                " stack_base=", (int64_t)stack_base,
                " stack_size=", (int64_t)vm.stack.size(),
                " p_ip_start=", p_ip_start,
                " p_ip_end=", p_ip_end,
                " isolated=", isolated_locals ? 1 : 0);
            // Dump full bytecode for diagnosis
            String dump = "  [DUMP] bytecode for " + (func ? func->name : String("<null>")) + ": ";
            for (int di = 0; di < chunk->code.size() && di < 80; di++) {
                dump += String::num_int64(chunk->code[di]) + " ";
            }
            UtilityFunctions::printerr(dump);
            // Dump constants
            String cdump = "  [DUMP] constants: ";
            for (int ci = 0; ci < chunk->constants.size() && ci < 16; ci++) {
                cdump += "[" + String::num_int64(ci) + "]=" + String(chunk->constants[ci]) + " ";
            }
            UtilityFunctions::printerr(cdump);
            return false;
        }
        return true;
    };

    auto finalize_profile = [&]() {
        if (!profiling_enabled) {
            return;
        }
        vg_opcode_profile_depth--;
        if (vg_opcode_profile_depth < 0) {
            vg_opcode_profile_depth = 0;
        }
        if (is_outermost_profile) {
            opcode_profile_dump();
        }
    };

    auto finalize_stack_profile = [&]() {
        if (!stack_profile_enabled) {
            return;
        }
        vg_stack_profile_dump(stack_profile_sample, stack_profile_label);
    };

    auto apply_variant_op = [&](Variant::Operator op) -> bool {
        if (!ensure_stack(2)) {
            return false;
        }
        Variant b = pop_value();
        Variant a = pop_value();
        Variant result;
        bool valid = false;
        Variant::evaluate(op, a, b, result, valid);
        if (!valid) {
            // Rate-limit error output to avoid spam
            static int error_count = 0;
            static uint64_t last_error_time = 0;
            uint64_t now = Time::get_singleton()->get_ticks_msec();
            error_count++;
            
            // Only print error once per second max
            if (now - last_error_time > 1000) {
                String debug_msg = vformat("Op:%d TypeA:%d TypeB:%d ValA:%s ValB:%s (count: %d)", 
                    (int)op, (int)a.get_type(), (int)b.get_type(), a, b, error_count);
                UtilityFunctions::printerr("VisualGasic: invalid operation in bytecode - ", debug_msg);
                last_error_time = now;
                error_count = 0;
            }
            return false;
        }
        push_value(result);
        return true;
    };

    const Vector<uint8_t> &code = chunk->code;
    const int code_size = code.size();
    // For parallel workers p_ip_end constrains execution to the body range.
    const int effective_code_end = (p_ip_end > 0 && p_ip_end <= code_size) ? p_ip_end : code_size;
    bool success = true;
    Variant result_snapshot;
    Variant explicit_return;
    bool has_explicit_return = false;

    // ── v3.2: Try/Catch handler stack for nested exception handling ──
    struct TryHandler {
        int catch_ip;
        int stack_depth;  // vm.stack.size() at OP_SETUP_TRY (for unwinding)
    };
    Vector<TryHandler> try_handler_stack;

    // Snapshot global variables that this function may write via OP_SET_GLOBAL.
    // If bytecode execution fails and the AST fallback re-runs the function,
    // we need to rollback globals to prevent double-mutation (e.g. wave += 1
    // executed in bytecode, then again in AST fallback → wave += 2).
    //
    // Skip this scan for parallel-body sub-range execution (p_ip_end > 0):
    //  1. The scan would run over the FULL chunk (not just the body range),
    //     and multi-byte opcodes like OP_PARALLEL_FOR_BEGIN can desync it.
    //  2. Parallel bodies have no AST fallback, so rollback is unnecessary.
    Dictionary saved_globals;
    if (p_ip_end <= 0) {
        int scan_ip = 0;
        while (scan_ip < code_size) {
            uint8_t scan_op = code[scan_ip++];
            if (scan_op == OP_SET_GLOBAL && scan_ip < code_size) {
                uint8_t idx = code[scan_ip];
                if (idx < chunk->constants.size()) {
                    String gname = chunk->constants[idx];
                    if (!saved_globals.has(gname) && variables.has(gname)) {
                        saved_globals[gname] = variables[gname];
                    }
                }
                scan_ip++; // skip the name index byte
            } else {
                // Skip operand bytes for multi-byte opcodes so the scan
                // doesn't misinterpret data bytes as OP_SET_GLOBAL.
                switch (scan_op) {
                    // 2-byte opcodes (1 operand)
                    case OP_CONSTANT: case OP_GET_GLOBAL: case OP_GET_LOCAL:
                    case OP_SET_LOCAL:
                    case OP_GET_MEMBER: case OP_SET_MEMBER:
                    case OP_REGISTER_WHENEVER: case OP_SUSPEND_WHENEVER: case OP_RESUME_WHENEVER:
                    case OP_ON_ERROR_GOTO:
                    case OP_INC_LOCAL_I64:
                    case OP_ADD_I64_CONST: case OP_SUB_I64_CONST:
                    case OP_ADD_LOCAL_I64_STACK: case OP_SUB_LOCAL_I64_STACK:
                    case OP_BRANCH_SUM:
                    case OP_GET_ARRAY: case OP_SET_ARRAY:
                    case OP_GET_ARRAY_UNCHECKED: case OP_SET_ARRAY_UNCHECKED:
                    case OP_GET_ARRAY_FAST: case OP_SET_ARRAY_FAST:
                    case OP_GET_ARRAY_FAST_UNCHECKED: case OP_SET_ARRAY_FAST_UNCHECKED:
                    case OP_GET_DICT_FAST: case OP_SET_DICT_FAST:
                    case OP_GET_DICT_TRUSTED: case OP_SET_DICT_TRUSTED:
                    case OP_INTEROP_SET_NAME_LEN:
                    case OP_MUL_I64_CONST:
                    case OP_SUM_VGDICT_ALL_I64:
                    case OP_NEW_VGDICT: case OP_GET_VGDICT_LOCAL: case OP_SET_VGDICT_LOCAL:
                    case OP_ITER_ARRAY:
                    case OP_NEW_ARRAY: case OP_NEW_ARRAY_I64:
                    case OP_GOSUB: case OP_PRINT_FILE:
                        scan_ip += 1; break;
                    // 3-byte opcodes (2 operands)
                    case OP_CONSTANT_LONG:
                    case OP_JUMP: case OP_JUMP_IF_FALSE: case OP_JUMP_IF_TRUE:
                    case OP_LOOP:
                    case OP_CALL:
                    case OP_CALL_BUILTIN:
                    case OP_METHOD_CALL:
                    case OP_SETUP_TRY:
                    case OP_ADD_LOCAL_I64_CONST: case OP_SUB_LOCAL_I64_CONST:
                    case OP_ARITH_SUM:
                    case OP_STRING_REPEAT_OUTER:
                    case OP_DEBUG_LINE:
                    case OP_SET_DICT_LOCAL: case OP_SET_DICT_GLOBAL:
                    case OP_NEW_OBJECT:  // [OP] [CLASS_NAME_IDX] [ARG_COUNT]
                    case OP_OPEN_FILE:   // [OP] [MODE]
                    case OP_WRITE_FILE:  // [OP] [ARG_COUNT]
                    case OP_INPUT_FILE:  // [OP] [VAR_COUNT]
                        scan_ip += 2; break;
                    // 4-byte opcodes (3 operands)
                    case OP_ALLOC_FILL_I64_OFFSET:
                    case OP_ARRAY_FILL_I64_OFFSET:
                    case OP_ACCUM_I64_MULADD_CONST:
                        scan_ip += 3; break;
                    // OP_PARALLEL_FOR_BEGIN: [VAR_SLOT] [BODY_LEN_HI] [BODY_LEN_LO] + body bytes
                    // Must skip the 3 operand bytes PLUS the entire body length.
                    case OP_PARALLEL_FOR_BEGIN: {
                        if (scan_ip + 2 < code_size) {
                            scan_ip++; // var_slot
                            int body_len = (code[scan_ip] << 8) | code[scan_ip + 1];
                            scan_ip += 2; // body_len_hi, body_len_lo
                            scan_ip += body_len; // skip entire body
                        } else {
                            scan_ip = code_size;
                        }
                        break;
                    }
                    // OP_TASK_RUN_BEGIN: [NAME_CONST] [BG_FLAG] [BODY_LEN_HI] [BODY_LEN_LO] + body bytes
                    case OP_TASK_RUN_BEGIN: {
                        if (scan_ip + 3 < code_size) {
                            scan_ip += 2; // name_const, bg_flag
                            int body_len = (code[scan_ip] << 8) | code[scan_ip + 1];
                            scan_ip += 2; // body_len_hi, body_len_lo
                            scan_ip += body_len; // skip entire body
                        } else {
                            scan_ip = code_size;
                        }
                        break;
                    }
                    // 7-byte opcodes (6 operands)
                    case OP_ALLOC_FILL_REPEAT_I64:
                        scan_ip += 6; break;
                    default:
                        // 1-byte opcodes (no operands) — nothing to skip
                        break;
                }
            }
        }
    }

    auto read_constant = [&](int idx) -> Variant {
        if (idx >= 0 && idx < chunk->constants.size()) {
            return chunk->constants[idx];
        }
        return Variant();
    };

    // ── v3.2: Centralized error recovery (Runtime Error Recovery) ──
    // Called after raise_error(). Checks try handler stack and On Error mode.
    // Returns true if error was handled (caller should break/VG_BREAK).
    // When push_default=true, pushes default_val onto stack for expression contexts.
    auto try_recover_error = [&](const Variant& default_val = Variant(), bool push_default = true) -> bool {
        // Priority 1: Try/Catch handler stack (innermost handler wins)
        if (!try_handler_stack.is_empty()) {
            TryHandler handler = try_handler_stack[try_handler_stack.size() - 1];
            try_handler_stack.resize(try_handler_stack.size() - 1);
            // Build exception dictionary (matches OP_THROW behavior)
            Dictionary ex;
            ex["Description"] = error_state.message;
            ex["Number"] = error_state.code;
            ex["Source"] = String("VisualGasic");
            // Unwind VM stack to handler's saved depth
            while ((int)vm.stack.size() > handler.stack_depth) {
                vm.stack.pop_back();
            }
            push_value(ex);
            error_state.has_error = false;
            vm.ip = handler.catch_ip;
            return true;
        }
        // Priority 2: On Error Resume Next
        if (error_state.mode == ErrorState::RESUME_NEXT) {
            error_state.has_error = false;
            if (push_default) push_value(default_val);
            return true;
        }
        // Priority 3: On Error GoTo Label — return false so caller does
        // goto cleanup → AST fallback handles the label jump.
        // Also NONE mode: return false → abort.
        return false;
    };

    struct MemberNameCacheEntry {
        enum class AccessPreference : uint8_t {
            UNKNOWN,
            PRIMARY,
            SNAKE,
        };
        struct ClassPreference {
            StringName class_name;
            AccessPreference preference = AccessPreference::UNKNOWN;
        };
        bool initialized = false;
        String primary_string;
        StringName primary_name;
        bool snake_computed = false;
        bool has_snake = false;
        StringName snake_name;
        Vector<ClassPreference> class_preferences;
    };

    Vector<MemberNameCacheEntry> member_name_cache;
    member_name_cache.resize(chunk->constants.size());

    auto ensure_member_cache_entry = [&](int idx) -> MemberNameCacheEntry& {
        MemberNameCacheEntry &entry = member_name_cache.write[idx];
        if (!entry.initialized) {
            Variant member_variant = read_constant(idx);
            entry.primary_string = String(member_variant);
            entry.primary_name = entry.primary_string;
            entry.initialized = true;
        }
        return entry;
    };

    auto ensure_snake_case = [&](MemberNameCacheEntry &entry) -> bool {
        if (entry.snake_computed) {
            return entry.has_snake;
        }
        entry.snake_computed = true;
        String snake = entry.primary_string.to_snake_case();
        if (snake != entry.primary_string) {
            entry.snake_name = StringName(snake);
            entry.has_snake = true;
        } else {
            entry.has_snake = false;
        }
        return entry.has_snake;
    };

    auto resolve_class_preference = [&](MemberNameCacheEntry &entry, const StringName &class_name) -> MemberNameCacheEntry::AccessPreference* {
        for (int i = 0; i < entry.class_preferences.size(); i++) {
            if (entry.class_preferences[i].class_name == class_name) {
                return &entry.class_preferences.write[i].preference;
            }
        }
        MemberNameCacheEntry::ClassPreference pref;
        pref.class_name = class_name;
        entry.class_preferences.push_back(pref);
        return &entry.class_preferences.write[entry.class_preferences.size() - 1].preference;
    };

    // -------- Computed-goto threaded dispatch (GCC/Clang) --------
    // We prefix each `case` label with a goto-label, and on GCC/Clang
    // the end of each handler jumps directly to the next opcode's label
    // via an indirect goto through a static dispatch table.  This avoids
    // the branch-predictor overhead of the switch and the while-loop
    // back-edge, giving ~15-25% faster opcode throughput.
    // MSVC falls back to the classic while+switch.

#if defined(__GNUC__) && !defined(__clang__)
// GCC: use computed goto for ~15-25% faster opcode dispatch.
// Clang: disabled — Clang's strict indirect-goto analysis rejects
// jumps across scoped variable declarations (e.g. Variant, String).
#define VG_USE_COMPUTED_GOTO 1
#else
#define VG_USE_COMPUTED_GOTO 0
#endif

#if VG_USE_COMPUTED_GOTO
    // Dispatch table: maps each opcode byte to the address of its handler label.
    // THREAD-LOCAL: each thread gets its own copy to avoid a data race
    // during initialisation.  The old `static` table was filled under a plain
    // bool flag with no memory barrier — a worker thread entering
    // execute_bytecode() could observe dispatch_table_init==true before the
    // table entries were committed, dispatching through stale/zero pointers
    // and causing random stack-underflow / SIGSEGV.
    // Thread-local is the simplest correct fix (one init per OS thread; cheap
    // for the handful of WorkerThreadPool threads).
    static thread_local const void* dispatch_table[256];
    static thread_local bool dispatch_table_init = false;
    if (!dispatch_table_init) {
        for (int _i = 0; _i < 256; _i++) dispatch_table[_i] = &&vg_op_default;
        dispatch_table[OP_CONSTANT]       = &&vg_op_constant;
        dispatch_table[OP_CONSTANT_LONG]  = &&vg_op_constant_long;
        dispatch_table[OP_POP]            = &&vg_op_pop;
        dispatch_table[OP_GET_GLOBAL]     = &&vg_op_get_global;
        dispatch_table[OP_SET_GLOBAL]     = &&vg_op_set_global;
        dispatch_table[OP_GET_LOCAL]      = &&vg_op_get_local;
        dispatch_table[OP_SET_LOCAL]      = &&vg_op_set_local;
        dispatch_table[OP_ADD]            = &&vg_op_add;
        dispatch_table[OP_SUBTRACT]       = &&vg_op_subtract;
        dispatch_table[OP_MULTIPLY]       = &&vg_op_multiply;
        dispatch_table[OP_DIVIDE]         = &&vg_op_divide;
        dispatch_table[OP_NEGATE]         = &&vg_op_negate;
        dispatch_table[OP_CONCAT]         = &&vg_op_concat;
        dispatch_table[OP_MOD]            = &&vg_op_mod;
        dispatch_table[OP_INT_DIVIDE]     = &&vg_op_int_divide;
        dispatch_table[OP_POWER]          = &&vg_op_power;
        dispatch_table[OP_LIKE]           = &&vg_op_like;
        dispatch_table[OP_ADD_I64]        = &&vg_op_add_i64;
        dispatch_table[OP_ADD_I64_CONST]  = &&vg_op_add_i64_const;
        dispatch_table[OP_SUB_I64]        = &&vg_op_sub_i64;
        dispatch_table[OP_SUB_I64_CONST]  = &&vg_op_sub_i64_const;
        dispatch_table[OP_MUL_I64]        = &&vg_op_mul_i64;
        dispatch_table[OP_MUL_I64_CONST]  = &&vg_op_mul_i64_const;
        dispatch_table[OP_ADD_F64]        = &&vg_op_add_f64;
        dispatch_table[OP_SUB_F64]        = &&vg_op_sub_f64;
        dispatch_table[OP_MUL_F64]        = &&vg_op_mul_f64;
        dispatch_table[OP_DIV_F64]        = &&vg_op_div_f64;
        dispatch_table[OP_ADD_LOCAL_I64_STACK]  = &&vg_op_add_local_i64_stack;
        dispatch_table[OP_SUB_LOCAL_I64_STACK]  = &&vg_op_sub_local_i64_stack;
        dispatch_table[OP_ADD_LOCAL_I64_CONST]  = &&vg_op_add_local_i64_const;
        dispatch_table[OP_SUB_LOCAL_I64_CONST]  = &&vg_op_sub_local_i64_const;
        dispatch_table[OP_INC_LOCAL_I64]  = &&vg_op_inc_local_i64;
        dispatch_table[OP_ACCUM_I64_MULADD_CONST] = &&vg_op_accum_i64_muladd_const;
        dispatch_table[OP_ARITH_SUM]      = &&vg_op_arith_sum;
        dispatch_table[OP_BRANCH_SUM]     = &&vg_op_branch_sum;
        dispatch_table[OP_SUM_ARRAY_I64]  = &&vg_op_sum_array_i64;
        dispatch_table[OP_SUM_DICT_I64]   = &&vg_op_sum_dict_i64;
        dispatch_table[OP_SUM_VGDICT_ALL_I64] = &&vg_op_sum_vgdict_all_i64;
        dispatch_table[OP_ARRAY_FILL_I64_SEQ]  = &&vg_op_array_fill_i64_seq;
        dispatch_table[OP_ALLOC_FILL_I64]      = &&vg_op_alloc_fill_i64;
        dispatch_table[OP_ALLOC_FILL_REPEAT_I64] = &&vg_op_alloc_fill_repeat_i64;
        dispatch_table[OP_STRING_REPEAT]       = &&vg_op_string_repeat;
        dispatch_table[OP_STRING_REPEAT_OUTER] = &&vg_op_string_repeat_outer;
        dispatch_table[OP_ABS]            = &&vg_op_abs;
        dispatch_table[OP_SGN]            = &&vg_op_sgn;
        dispatch_table[OP_LEN]            = &&vg_op_len;
        dispatch_table[OP_EQUAL]          = &&vg_op_equal;
        dispatch_table[OP_NOT_EQUAL]      = &&vg_op_not_equal;
        dispatch_table[OP_GREATER]        = &&vg_op_greater;
        dispatch_table[OP_LESS]           = &&vg_op_less;
        dispatch_table[OP_GREATER_EQUAL]  = &&vg_op_greater_equal;
        dispatch_table[OP_LESS_EQUAL]     = &&vg_op_less_equal;
        dispatch_table[OP_EQUAL_I64]      = &&vg_op_equal_i64;
        dispatch_table[OP_NOT_EQUAL_I64]  = &&vg_op_not_equal_i64;
        dispatch_table[OP_LESS_EQUAL_I64] = &&vg_op_less_equal_i64;
        dispatch_table[OP_NOT]            = &&vg_op_not;
        dispatch_table[OP_AND]            = &&vg_op_and;
        dispatch_table[OP_OR]             = &&vg_op_or;
        dispatch_table[OP_XOR]            = &&vg_op_xor;
        dispatch_table[OP_JUMP]           = &&vg_op_jump;
        dispatch_table[OP_JUMP_IF_FALSE]  = &&vg_op_jump_if_false;
        dispatch_table[OP_JUMP_IF_TRUE]   = &&vg_op_jump_if_true;
        dispatch_table[OP_LOOP]           = &&vg_op_loop;
        dispatch_table[OP_CALL]           = &&vg_op_call;
        dispatch_table[OP_RETURN]         = &&vg_op_return;
        dispatch_table[OP_RETURN_VALUE]   = &&vg_op_return_value;
        dispatch_table[OP_PRINT]          = &&vg_op_print;
        dispatch_table[OP_DEBUG_PRINT]    = &&vg_op_debug_print;
        dispatch_table[OP_NEW_ARRAY]      = &&vg_op_new_array;
        dispatch_table[OP_NEW_ARRAY_I64]  = &&vg_op_new_array_i64;
        dispatch_table[OP_NEW_DICT]       = &&vg_op_new_dict;
        dispatch_table[OP_GET_ARRAY]      = &&vg_op_get_array;
        dispatch_table[OP_SET_ARRAY]      = &&vg_op_set_array;
        dispatch_table[OP_GET_ARRAY_UNCHECKED]  = &&vg_op_get_array_unchecked;
        dispatch_table[OP_SET_ARRAY_UNCHECKED]  = &&vg_op_set_array_unchecked;
        dispatch_table[OP_GET_ARRAY_FAST]       = &&vg_op_get_array_fast;
        dispatch_table[OP_SET_ARRAY_FAST]       = &&vg_op_set_array_fast;
        dispatch_table[OP_GET_ARRAY_FAST_UNCHECKED] = &&vg_op_get_array_fast_unchecked;
        dispatch_table[OP_SET_ARRAY_FAST_UNCHECKED] = &&vg_op_set_array_fast_unchecked;
        dispatch_table[OP_GET_DICT_FAST]        = &&vg_op_get_dict_fast;
        dispatch_table[OP_SET_DICT_FAST]        = &&vg_op_set_dict_fast;
        dispatch_table[OP_GET_DICT_TRUSTED]     = &&vg_op_get_dict_trusted;
        dispatch_table[OP_SET_DICT_TRUSTED]     = &&vg_op_set_dict_trusted;
        dispatch_table[OP_SET_DICT_LOCAL]       = &&vg_op_set_dict_local;
        dispatch_table[OP_SET_DICT_GLOBAL]      = &&vg_op_set_dict_global;
        dispatch_table[OP_DICT_HAS_KEY]         = &&vg_op_dict_has_key;
        dispatch_table[OP_DICT_SIZE]            = &&vg_op_dict_size;
        dispatch_table[OP_DICT_CLEAR_INPLACE]   = &&vg_op_dict_clear_inplace;
        dispatch_table[OP_DICT_KEYS]            = &&vg_op_dict_keys;
        dispatch_table[OP_DICT_VALUES]          = &&vg_op_dict_values;
        dispatch_table[OP_DICT_ERASE]           = &&vg_op_dict_erase;
        dispatch_table[OP_NEW_VGDICT]           = &&vg_op_new_vgdict;
        dispatch_table[OP_GET_VGDICT_LOCAL]     = &&vg_op_get_vgdict_local;
        dispatch_table[OP_SET_VGDICT_LOCAL]     = &&vg_op_set_vgdict_local;
        dispatch_table[OP_GET_MEMBER]    = &&vg_op_get_member;
        dispatch_table[OP_SET_MEMBER]    = &&vg_op_set_member;
        dispatch_table[OP_INTEROP_SET_NAME_LEN] = &&vg_op_interop_set_name_len;
        dispatch_table[OP_REGISTER_WHENEVER]    = &&vg_op_register_whenever;
        dispatch_table[OP_SUSPEND_WHENEVER]     = &&vg_op_suspend_whenever;
        dispatch_table[OP_RESUME_WHENEVER]      = &&vg_op_resume_whenever;
        dispatch_table[OP_RESTORE_DATA]         = &&vg_op_restore_data;
        dispatch_table[OP_READ_DATA]            = &&vg_op_read_data;
        dispatch_table[OP_LOAD_DATA]            = &&vg_op_load_data;
        dispatch_table[OP_DATA_FROM_STRING]     = &&vg_op_data_from_string;
        dispatch_table[OP_CLEAR_DATA]           = &&vg_op_clear_data;
        dispatch_table[OP_COERCE_TYPE]          = &&vg_op_coerce_type;
        dispatch_table[OP_ON_ERROR_RESUME_NEXT] = &&vg_op_on_error_resume_next;
        dispatch_table[OP_ON_ERROR_GOTO]        = &&vg_op_on_error_goto;
        dispatch_table[OP_ON_ERROR_GOTO_0]      = &&vg_op_on_error_goto_0;
        dispatch_table[OP_NIL]            = &&vg_op_nil;
        dispatch_table[OP_TRUE]           = &&vg_op_true;
        dispatch_table[OP_FALSE]          = &&vg_op_false;
        dispatch_table[OP_DEBUG_LINE]     = &&vg_op_debug_line;
        dispatch_table[OP_STOP]           = &&vg_op_stop;
        dispatch_table[OP_IS_CLASS]       = &&vg_op_is_class;
        dispatch_table[OP_METHOD_CALL]    = &&vg_op_method_call;
        dispatch_table[OP_ITER_ARRAY]     = &&vg_op_iter_array;
        dispatch_table[OP_DICT_KEYS_CALL] = &&vg_op_dict_keys_call;
        dispatch_table[OP_PUSH_WITH]      = &&vg_op_push_with;
        dispatch_table[OP_POP_WITH]       = &&vg_op_pop_with;
        dispatch_table[OP_GET_WITH]       = &&vg_op_get_with;
        dispatch_table[OP_SETUP_TRY]      = &&vg_op_setup_try;
        dispatch_table[OP_POP_TRY]        = &&vg_op_pop_try;
        dispatch_table[OP_THROW]          = &&vg_op_throw;
        dispatch_table[OP_DUP]            = &&vg_op_dup;
        dispatch_table[OP_ARRAY_RESIZE]   = &&vg_op_array_resize;
        dispatch_table[OP_NEW_OBJECT]     = &&vg_op_new_object;
        // v2.10.0 File I/O + GoSub
        dispatch_table[OP_OPEN_FILE]      = &&vg_op_open_file;
        dispatch_table[OP_CLOSE_FILE]     = &&vg_op_close_file;
        dispatch_table[OP_PRINT_FILE]     = &&vg_op_print_file;
        dispatch_table[OP_WRITE_FILE]     = &&vg_op_write_file;
        dispatch_table[OP_INPUT_FILE]     = &&vg_op_input_file;
        dispatch_table[OP_LINE_INPUT]     = &&vg_op_line_input;
        dispatch_table[OP_GOSUB]          = &&vg_op_gosub;
        dispatch_table[OP_RETURN_GOSUB]   = &&vg_op_return_gosub;
        // Threading (v2.11.0)
        dispatch_table[OP_LOCK]           = &&vg_op_lock;
        dispatch_table[OP_UNLOCK]         = &&vg_op_unlock;
        dispatch_table[OP_PARALLEL_FOR_BEGIN] = &&vg_op_parallel_for_begin;
        dispatch_table[OP_PARALLEL_FOR_END]   = &&vg_op_parallel_for_end;
        dispatch_table[OP_TASK_RUN_BEGIN]     = &&vg_op_task_run_begin;
        dispatch_table[OP_TASK_RUN_END]       = &&vg_op_task_run_end;
        dispatch_table[OP_TASK_WAIT]          = &&vg_op_task_wait;
        dispatch_table[OP_AWAIT]              = &&vg_op_await;
        // Event system (v3.5.0)
        dispatch_table[OP_RAISE_EVENT]        = &&vg_op_raise_event;
        dispatch_table_init = true;
    }

    // VG_CASE(label, opcode):  on GCC/Clang emits `label: case opcode:`
    //                          on MSVC emits `case opcode:` only.
    // VG_BREAK:  on GCC/Clang fetches next opcode + goto *dispatch_table[op]
    //            on MSVC is plain `break`.
#define VG_CASE(label, opcode)  label: case opcode
#define VG_BREAK                                    \
    do {                                            \
        if (vm.ip >= effective_code_end) goto cleanup; \
        last_opcode_offset = vm.ip;                 \
        op = code[vm.ip++];                         \
        current_opcode = op;                        \
        goto *dispatch_table[op];                   \
    } while (0)

#else  // !VG_USE_COMPUTED_GOTO  (MSVC fallback)
#define VG_CASE(label, opcode)  case opcode
#define VG_BREAK  break
#endif // VG_USE_COMPUTED_GOTO

    while (vm.ip < effective_code_end) {
        last_opcode_offset = vm.ip;
        uint8_t op = code[vm.ip++];
        current_opcode = op;
#if VG_USE_COMPUTED_GOTO
        goto *dispatch_table[op];  // skip the switch on GCC/Clang
#endif
        switch (op) {
            VG_CASE(vg_op_constant, OP_CONSTANT): {
                if (vm.ip >= code_size) {
                    success = false;
                    goto cleanup;
                }
                uint8_t idx = code[vm.ip++];
                push_value(read_constant(idx));
                break;
            }
            VG_CASE(vg_op_constant_long, OP_CONSTANT_LONG): {
                if (vm.ip + 1 >= code_size) {
                    success = false;
                    goto cleanup;
                }
                uint8_t lo = code[vm.ip++];
                uint8_t hi = code[vm.ip++];
                int idx = (hi << 8) | lo;
                push_value(read_constant(idx));
                break;
            }
            VG_CASE(vg_op_pop, OP_POP): {
                if (vm.stack.size() > stack_base) {
                    vm.stack.pop_back();
                }
                break;
            }
            VG_CASE(vg_op_dup, OP_DUP): {
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                push_value(vm.stack[vm.stack.size() - 1]);
                break;
            }
            VG_CASE(vg_op_array_resize, OP_ARRAY_RESIZE): {
                // Stack: [... array new_size]  →  [... resized_array]
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                Variant new_size_v = pop_value();
                Variant arr_v = pop_value();
                int new_size = (int)(int64_t)new_size_v;
                if (arr_v.get_type() == Variant::ARRAY) {
                    Array arr = arr_v;
                    arr.resize(new_size);
                    push_value(arr);
                } else if (arr_v.get_type() == Variant::PACKED_INT64_ARRAY) {
                    PackedInt64Array arr = arr_v;
                    arr.resize(new_size);
                    push_value(arr);
                } else if (arr_v.get_type() == Variant::PACKED_FLOAT64_ARRAY) {
                    PackedFloat64Array arr = arr_v;
                    arr.resize(new_size);
                    push_value(arr);
                } else {
                    // Not an array — create a new one
                    Array arr;
                    arr.resize(new_size);
                    push_value(arr);
                }
                break;
            }
            VG_CASE(vg_op_new_object, OP_NEW_OBJECT): {
                // [OP] [CLASS_NAME_IDX] [ARG_COUNT]
                if (vm.ip + 1 >= code_size) { success = false; goto cleanup; }
                uint8_t name_idx = code[vm.ip++];
                uint8_t arg_count = code[vm.ip++];
                String class_name = read_constant(name_idx);

                // Pop args (pushed left-to-right, so collect in reverse)
                Array args_arr;
                args_arr.resize(arg_count);
                for (int i = arg_count - 1; i >= 0; i--) {
                    args_arr[i] = pop_value();
                }

                // MemoryBlock → PackedByteArray
                if (class_name.nocasecmp_to("MemoryBlock") == 0) {
                    int sz = 0;
                    if (arg_count > 0) sz = (int)(int64_t)args_arr[0];
                    PackedByteArray pba;
                    pba.resize(sz);
                    push_value(pba);
                    break;
                }
                // Dictionary (with args — shouldn't normally happen, but be safe)
                if (class_name.nocasecmp_to("Dictionary") == 0) {
                    push_value(Dictionary());
                    break;
                }
                // Struct definitions
                if (script.is_valid() && script->ast_root) {
                    bool found_struct = false;
                    for (int i = 0; i < script->ast_root->structs.size(); i++) {
                        if (script->ast_root->structs[i]->name.nocasecmp_to(class_name) == 0) {
                            Dictionary d;
                            StructDefinition* def = script->ast_root->structs[i];
                            for (int m = 0; m < def->members.size(); m++) {
                                d[def->members[m].name] = Variant();
                            }
                            push_value(d);
                            found_struct = true;
                            break;
                        }
                    }
                    if (found_struct) break;
                }
                // VG class definitions
                if (class_registry.has(class_name)) {
                    Variant result = instantiate_class(class_name, args_arr);
                    push_value(result);
                    break;
                }

                // VB6-friendly aliases for system classes (v2.9.0)
                {
                    String resolved;
                    if (class_name.nocasecmp_to("Process") == 0) resolved = "VGProcess";
                    else if (class_name.nocasecmp_to("Database") == 0) resolved = "VGDatabase";
                    else if (class_name.nocasecmp_to("FileSystemWatcher") == 0) resolved = "VGFileWatcher";
                    else if (class_name.nocasecmp_to("CommonDialog") == 0) resolved = "VGCommonDialog";
                    else if (class_name.nocasecmp_to("WinSock") == 0 || class_name.nocasecmp_to("Socket") == 0) resolved = "VGSocket";
                    else if (class_name.nocasecmp_to("SysTray") == 0) resolved = "VGSysTray";
                    else if (class_name.nocasecmp_to("Settings") == 0) resolved = "VGSettings";
                    else if (class_name.nocasecmp_to("FileSystemObject") == 0) resolved = "VGFileSystemObject";
                    else if (class_name.nocasecmp_to("ScriptingDictionary") == 0) resolved = "VGScriptingDict";
                    else if (class_name.nocasecmp_to("WScriptShell") == 0) resolved = "VGWScriptShell";
                    else if (class_name.nocasecmp_to("ComObject") == 0) resolved = "VGComObject";
                    // v2.10.0 aliases
                    else if (class_name.nocasecmp_to("HttpRequest") == 0 || class_name.nocasecmp_to("XMLHTTP") == 0) resolved = "VGHttpRequest";
                    else if (class_name.nocasecmp_to("Collection") == 0) resolved = "VGCollection";
                    else if (class_name.nocasecmp_to("RegExp") == 0) resolved = "VGRegEx";
                    else if (class_name.nocasecmp_to("Timer") == 0 || class_name.nocasecmp_to("VBTimer") == 0) resolved = "VGTimer";
                    // v3.0 aliases
                    else if (class_name.nocasecmp_to("NativeLibrary") == 0) resolved = "VGNativeLibrary";
                    else if (class_name.nocasecmp_to("NativeStruct") == 0) resolved = "VGNativeStruct";
                    else if (class_name.nocasecmp_to("Odbc") == 0) resolved = "VGOdbc";
                    else if (class_name.nocasecmp_to("Crypto") == 0) resolved = "VGCrypto";
                    else if (class_name.nocasecmp_to("Xml") == 0) resolved = "VGXml";
                    else if (class_name.nocasecmp_to("Zip") == 0) resolved = "VGZip";
                    else if (class_name.nocasecmp_to("Task") == 0) resolved = "VGTask";
                    else if (class_name.nocasecmp_to("TaskRunner") == 0) resolved = "VGTaskRunner";
                    // v3.1 aliases
                    else if (class_name.nocasecmp_to("System") == 0) resolved = "VGSystem";
                    else if (class_name.nocasecmp_to("SignalHandler") == 0) resolved = "VGSignalHandler";
                    else if (class_name.nocasecmp_to("FilePermissions") == 0) resolved = "VGFilePermissions";
                    else if (class_name.nocasecmp_to("MemoryBuffer") == 0) resolved = "VGMemoryBuffer";
                    else if (class_name.nocasecmp_to("IPC") == 0) resolved = "VGIPC";
                    else if (class_name.nocasecmp_to("AndroidBridge") == 0) resolved = "VGAndroidBridge";
                    // v3.2 aliases – GPU & ECS
                    else if (class_name.nocasecmp_to("Gpu") == 0 || class_name.nocasecmp_to("VGGpu") == 0) resolved = "VisualGasicGPU";
                    else if (class_name.nocasecmp_to("ECS") == 0 || class_name.nocasecmp_to("VGEcs") == 0) resolved = "VisualGasicECS";
                    // Also resolve full VG* names for v3.0+ (bypass can_instantiate issue)
                    else if (class_name.begins_with("VG") && ClassDB::class_exists(class_name)) resolved = class_name;

                    if (!resolved.is_empty() && ClassDB::class_exists(resolved)) {
                        Variant inst = ClassDB::instantiate(resolved);
                        if (inst.get_type() == Variant::OBJECT) {
                            push_value(inst);
                            break;
                        }
                    }
                }

                // Godot ClassDB
                if (ClassDB::class_exists(class_name)) {
                    // Guard: singletons like ProjectSettings crash if you
                    // call ClassDB::instantiate() on them.  Return the
                    // existing singleton instead.
                    if (Engine::get_singleton()->has_singleton(class_name)) {
                        Object *s = Engine::get_singleton()->get_singleton(class_name);
                        push_value(s ? Variant(s) : Variant());
                        break;
                    }
                    if (!ClassDB::can_instantiate(class_name)) {
                        push_value(Variant());
                        break;
                    }
                    // instantiate() returns Variant — keep it as Variant so that
                    // RefCounted subclasses (SphereMesh, StandardMaterial3D, …)
                    // retain their reference count instead of being freed when a
                    // temporary Object* goes out of scope.
                    Variant inst = ClassDB::instantiate(class_name);
                    if (inst.get_type() == Variant::OBJECT) {
                        push_value(inst);
                        break;
                    }
                }
                // Unknown class — push Nil
                push_value(Variant());
                break;
            }
            VG_CASE(vg_op_get_global, OP_GET_GLOBAL): {
                if (vm.ip >= code_size) {
                    success = false;
                    goto cleanup;
                }
                uint8_t idx = code[vm.ip++];
                Variant name_var = read_constant(idx);
                String name = name_var;
                
                // Handle special keywords first
                // "Me" - returns owner (self reference)
                if (name.nocasecmp_to("Me") == 0) {
                    push_value(owner ? Variant(owner) : Variant());
                    break;
                }
                // "Super" - returns owner (parent-class method dispatch is handled at call site)
                if (name.nocasecmp_to("Super") == 0) {
                    push_value(owner ? Variant(owner) : Variant());
                    break;
                }
                // "Input" singleton
                if (name.nocasecmp_to("Input") == 0) {
                    push_value(Variant(Input::get_singleton()));
                    break;
                }
                // "Godot" (Engine) singleton
                if (name.nocasecmp_to("Godot") == 0) {
                    push_value(Variant(Engine::get_singleton()));
                    break;
                }

                // VB6 virtual objects: App, Screen, Err (v2.10.0)
                if (name.nocasecmp_to("App") == 0) {
                    Dictionary app;
                    app["Path"] = OS::get_singleton()->get_executable_path().get_base_dir();
                    String exe_full = OS::get_singleton()->get_executable_path().get_file();
                    app["EXEName"] = exe_full.get_basename();
                    app["Title"] = ProjectSettings::get_singleton()->get_setting("application/config/name", String("VisualGasic App"));
                    app["Major"] = 1;
                    app["Minor"] = 0;
                    app["Revision"] = 0;
                    app["PrevInstance"] = false;
                    app["ProductName"] = app["Title"];
                    app["CompanyName"] = String("");
                    push_value(app);
                    break;
                }
                if (name.nocasecmp_to("Screen") == 0) {
                    Dictionary screen;
                    Vector2i screen_size = DisplayServer::get_singleton()->screen_get_size();
                    screen["Width"] = screen_size.x;
                    screen["Height"] = screen_size.y;
                    screen["TwipsPerPixelX"] = 1;
                    screen["TwipsPerPixelY"] = 1;
                    screen["MousePointer"] = 0;
                    push_value(screen);
                    break;
                }
                if (name.nocasecmp_to("Err") == 0) {
                    // Return the Err dictionary from variables, or create default
                    if (variables.has("Err")) {
                        push_value(variables["Err"]);
                    } else {
                        Dictionary err;
                        err["Number"] = 0;
                        err["Description"] = String("");
                        err["Source"] = String("");
                        variables["Err"] = err;
                        push_value(err);
                    }
                    break;
                }
                
                Variant val = variables.get(name, Variant());
                
                if (name.nocasecmp_to("wheneverTriggered") == 0) {
                }
                
                // If not found in variables, try Godot engine singletons
                if (val.get_type() == Variant::NIL) {
                    if (Engine::get_singleton()->has_singleton(name)) {
                        Object *singleton = Engine::get_singleton()->get_singleton(name);
                        if (singleton) {
                            push_value(Variant(singleton));
                            break;
                        }
                    }
                }
                
                // If not found in variables, search for child control by name (VB6 style)
                if (val.get_type() == Variant::NIL && owner) {
                    Node* owner_node = Object::cast_to<Node>(owner);
                    if (owner_node) {
                        Node *found = owner_node->find_child(name, true, false);
                        if (found) {
                            val = found;
                        }
                    }
                }
                
                push_value(val);
                break;
            }
            VG_CASE(vg_op_set_global, OP_SET_GLOBAL): {
                if (vm.ip >= code_size) {
                    success = false;
                    goto cleanup;
                }
                uint8_t idx = code[vm.ip++];
                Variant name_var = read_constant(idx);
                String name = name_var;
                if (!ensure_stack(1)) {
                    success = false;
                    goto cleanup;
                }
                Variant value = pop_value();
                
                // Check for data breakpoint (watchpoint)
                if (VisualGasicLanguage::check_watchpoint(name, value)) {
                    // Watchpoint hit - variable value changed
                    int wp_line = debug_state.current_line > 0 ? debug_state.current_line : 0;
                    VisualGasicLanguage::set_current_break_location(debug_file, wp_line);
                    EngineDebugger* debugger = EngineDebugger::get_singleton();
                    debugger->send_message("visualgasic:watchpoint_hit", 
                        Array::make(name, variables.get(name, Variant()), value, debug_file, wp_line));
                    // Use Godot's script_debug() for proper pause/resume
                    VisualGasicLanguage* lang = VisualGasicLanguage::get_singleton();
                    if (lang) {
                        debugger->script_debug(lang, true, false);
                    }
                }
                
                // Type-preservation matching assign_variable() behavior
                if (variables.has(name)) {
                    Variant::Type target_type = variables[name].get_type();
                    if (target_type == Variant::INT) {
                        variables[name] = (int64_t)value;
                    } else if (target_type == Variant::FLOAT) {
                        variables[name] = (double)value;
                    } else if (target_type == Variant::STRING) {
                        variables[name] = (String)value;
                    } else if (target_type == Variant::BOOL) {
                        variables[name] = (bool)value;
                    } else {
                        variables[name] = value;
                    }
                } else {
                    variables[name] = value;
                }
                
                // Trigger Whenever system (must match assign_variable behavior)
                check_whenever_conditions(name, variables[name]);
                check_expression_conditions();
                
                break;
            }
            VG_CASE(vg_op_get_local, OP_GET_LOCAL): {
                if (vm.ip >= code_size) {
                    success = false;
                    goto cleanup;
                }
                uint8_t slot = code[vm.ip++];
                Variant val = read_local(slot);
                
                // If local is NIL, check if it's actually a control name (VB6 style)
                if (val.get_type() == Variant::NIL && owner) {
                    String local_name;
                    if (slot < chunk->local_names.size()) {
                        local_name = chunk->local_names[slot];
                    }
                    if (!local_name.is_empty()) {
                        Node* owner_node = Object::cast_to<Node>(owner);
                        if (owner_node) {
                            Node *found = owner_node->find_child(local_name, true, false);
                            if (found) {
                                val = found;
                            }
                        }
                    }
                }
                
                push_value(val);
                break;
            }
            VG_CASE(vg_op_set_local, OP_SET_LOCAL): {
                if (vm.ip >= code_size) {
                    success = false;
                    goto cleanup;
                }
                uint8_t slot = code[vm.ip++];
                if (!ensure_stack(1)) {
                    success = false;
                    goto cleanup;
                }
                Variant value = pop_value();
                sync_local(slot, value);
                break;
            }
            VG_CASE(vg_op_add, OP_ADD):
                if (!apply_variant_op(Variant::OP_ADD)) {
                    success = false;
                    goto cleanup;
                }
                break;
            VG_CASE(vg_op_subtract, OP_SUBTRACT):
                if (!apply_variant_op(Variant::OP_SUBTRACT)) {
                    success = false;
                    goto cleanup;
                }
                break;
            VG_CASE(vg_op_multiply, OP_MULTIPLY):
                if (!apply_variant_op(Variant::OP_MULTIPLY)) {
                    success = false;
                    goto cleanup;
                }
                break;
            VG_CASE(vg_op_divide, OP_DIVIDE): {
                if (!ensure_stack(2)) {
                    success = false;
                    goto cleanup;
                }
                Variant b = pop_value();
                Variant a = pop_value();
                // Check for division by zero
                double divisor = (double)b;
                if (divisor == 0.0) {
                    raise_error("Division by zero", 11);
                    if (try_recover_error(Variant(0.0))) break;
                    success = false;
                    goto cleanup;
                }
                push_value(Variant((double)a / divisor));
                break;
            }
            VG_CASE(vg_op_mod, OP_MOD): {
                if (!ensure_stack(2)) {
                    success = false;
                    goto cleanup;
                }
                Variant b = pop_value();
                Variant a = pop_value();
                // GDScript-style string format: "fmt" % value
                if (a.get_type() == Variant::STRING) {
                    String fmt = a;
                    // Godot's String::operator% expects Array for multiple placeholders
                    // or single Variant. Wrap non-Array values in Array for consistency.
                    if (b.get_type() == Variant::ARRAY) {
                        push_value(Variant(fmt % b));
                    } else {
                        Array arr;
                        arr.push_back(b);
                        push_value(Variant(fmt % arr));
                    }
                    break;
                }
                int64_t ival_b = to_int(b);
                if (ival_b == 0) {
                    raise_error("Division by zero", 11);
                    if (try_recover_error(Variant((int64_t)0))) break;
                    success = false;
                    goto cleanup;
                }
                push_value(Variant(to_int(a) % ival_b));
                break;
            }
            VG_CASE(vg_op_int_divide, OP_INT_DIVIDE): {
                if (!ensure_stack(2)) {
                    success = false;
                    goto cleanup;
                }
                Variant b = pop_value();
                Variant a = pop_value();
                int64_t ival_a = to_int(a);
                int64_t ival_b = to_int(b);
                if (ival_b == 0) {
                    raise_error("Division by zero", 11);
                    if (try_recover_error(Variant((int64_t)0))) break;
                    success = false;
                    goto cleanup;
                } else {
                    push_value(Variant(ival_a / ival_b));
                }
                break;
            }
            VG_CASE(vg_op_power, OP_POWER): {
                if (!ensure_stack(2)) {
                    success = false;
                    goto cleanup;
                }
                Variant b = pop_value();
                Variant a = pop_value();
                double val = UtilityFunctions::pow((double)a, (double)b);
                push_value(Variant(val));
                break;
            }
            VG_CASE(vg_op_like, OP_LIKE): {
                // VB-style Like pattern matching
                if (!ensure_stack(2)) {
                    success = false;
                    goto cleanup;
                }
                String pattern = String(pop_value());
                String value = String(pop_value());
                // Use full VB6 Like pattern matching
                bool matches = vb_like_match(value, pattern);
                push_value(Variant(matches));
                break;
            }
            VG_CASE(vg_op_negate, OP_NEGATE): {
                // OP_NEGATE is a unary operation - only pop and push 1 value
                if (!ensure_stack(1)) {
                    success = false;
                    goto cleanup;
                }
                Variant value = pop_value();
                Variant result;
                bool valid = false;
                Variant::evaluate(Variant::OP_NEGATE, value, Variant(), result, valid);
                if (!valid) {
                    UtilityFunctions::printerr("VisualGasic: invalid negate operation on type ", (int)value.get_type());
                    success = false;
                    goto cleanup;
                }
                push_value(result);
                break;
            }
            VG_CASE(vg_op_concat, OP_CONCAT): {
                if (!ensure_stack(2)) {
                    success = false;
                    goto cleanup;
                }
                Variant b = pop_value();
                Variant a = pop_value();
                // Fast path: avoid conversion if already strings
                if (a.get_type() == Variant::STRING && b.get_type() == Variant::STRING) {
                    push_value(Variant(String(a) + String(b)));
                } else {
                    push_value(Variant(String(a) + String(b)));
                }
                break;
            }
            VG_CASE(vg_op_string_repeat, OP_STRING_REPEAT): {
                if (!ensure_stack(2)) {
                    success = false;
                    goto cleanup;
                }
                String literal = String(pop_value());
                int64_t count = to_int(pop_value());
                push_value(vg_repeat_literal(literal, count));
                break;
            }
            VG_CASE(vg_op_string_repeat_outer, OP_STRING_REPEAT_OUTER): {
                if (vm.ip + 1 >= code_size) { success = false; goto cleanup; }
                uint8_t slot = code[vm.ip++];
                uint8_t lit_idx = code[vm.ip++];
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                Variant outer_variant = pop_value();
                Variant inner_variant = pop_value();
                int64_t outer_count = to_int(outer_variant);
                int64_t inner_count = to_int(inner_variant);
                if (outer_count <= 0) {
                    break;
                }
                if (inner_count < 0) {
                    inner_count = 0;
                }
                String literal = read_constant(lit_idx);
                String result;
                if (inner_count <= 0) {
                    result = String();
                } else {
                    result = vg_repeat_literal(literal, inner_count);
                }
                sync_local(slot, result);
                break;
            }
            VG_CASE(vg_op_interop_set_name_len, OP_INTEROP_SET_NAME_LEN): {
                if (vm.ip + 0 >= code_size) { success = false; goto cleanup; }
                uint8_t sum_slot = code[vm.ip++];
                if (!ensure_stack(3)) { success = false; goto cleanup; }
                String prefix_str = pop_value().stringify();
                int64_t outer_to = to_int(pop_value());
                int64_t inner_to = to_int(pop_value());
                int64_t n_outer = vg_loop_count(outer_to);
                int64_t n_inner = vg_loop_count(inner_to);
                int64_t prefix_len = (int64_t)prefix_str.length();
                int64_t current_sum = to_int(read_local(sum_slot));

                // Compute sum of Len(prefix & CStr(j)) for j = 0..n_inner-1
                // = n_inner * prefix_len + sum_of_digit_lengths(0..n_inner-1)
                // digit_count(j) = floor(log10(max(j,1))) + 1
                // We compute sum of digit lengths in O(log10(n)) using powers of 10
                int64_t digit_len_sum = 0;
                if (n_inner > 0) {
                    // Single-digit numbers: j=0..min(9, n_inner-1), all have 1 digit
                    int64_t single_digit_count = (n_inner < 10) ? n_inner : 10;
                    digit_len_sum = single_digit_count;  // each contributes 1 digit
                    // Multi-digit numbers: groups of 10^d .. 10^(d+1)-1
                    int64_t power = 10;
                    int digits = 2;  // 10..99 have 2 digits, 100..999 have 3, etc.
                    while (power < n_inner) {
                        int64_t next_power = power * 10;
                        int64_t upper = (next_power < n_inner) ? next_power : n_inner;
                        digit_len_sum += (int64_t)digits * (upper - power);
                        power = next_power;
                        digits++;
                    }
                }
                int64_t per_outer = n_inner * prefix_len + digit_len_sum;
                int64_t delta = per_outer * n_outer;
                if (delta != 0) {
                    current_sum += delta;
                }
                push_value(current_sum);
                break;
            }
            VG_CASE(vg_op_add_i64, OP_ADD_I64): {
                if (!ensure_stack(2)) {
                    success = false;
                    goto cleanup;
                }
                int64_t b = to_int(pop_value());
                int64_t a = to_int(pop_value());
                push_value((int64_t)(a + b));
                break;
            }
            VG_CASE(vg_op_sub_i64, OP_SUB_I64): {
                if (!ensure_stack(2)) {
                    success = false;
                    goto cleanup;
                }
                int64_t b = to_int(pop_value());
                int64_t a = to_int(pop_value());
                push_value((int64_t)(a - b));
                break;
            }
            VG_CASE(vg_op_mul_i64, OP_MUL_I64): {
                if (!ensure_stack(2)) {
                    success = false;
                    goto cleanup;
                }
                int64_t b = to_int(pop_value());
                int64_t a = to_int(pop_value());
                push_value((int64_t)(a * b));
                break;
            }
            VG_CASE(vg_op_add_f64, OP_ADD_F64): {
                if (!ensure_stack(2)) {
                    success = false;
                    goto cleanup;
                }
                double b = to_double(pop_value());
                double a = to_double(pop_value());
                push_value(a + b);
                break;
            }
            VG_CASE(vg_op_sub_f64, OP_SUB_F64): {
                if (!ensure_stack(2)) {
                    success = false;
                    goto cleanup;
                }
                double b = to_double(pop_value());
                double a = to_double(pop_value());
                push_value(a - b);
                break;
            }
            VG_CASE(vg_op_mul_f64, OP_MUL_F64): {
                if (!ensure_stack(2)) {
                    success = false;
                    goto cleanup;
                }
                double b = to_double(pop_value());
                double a = to_double(pop_value());
                push_value(a * b);
                break;
            }
            VG_CASE(vg_op_div_f64, OP_DIV_F64): {
                if (!ensure_stack(2)) {
                    success = false;
                    goto cleanup;
                }
                double b = to_double(pop_value());
                double a = to_double(pop_value());
                // v3.2: Division-by-zero check (mirrors OP_DIVIDE)
                if (b == 0.0) {
                    raise_error("Division by zero", 11);
                    if (try_recover_error(Variant(0.0))) break;
                    success = false;
                    goto cleanup;
                }
                push_value(a / b);
                break;
            }
            VG_CASE(vg_op_add_i64_const, OP_ADD_I64_CONST): {
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t idx = code[vm.ip++];
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                pop_value(); // discard literal operand on stack
                int64_t a = to_int(pop_value());
                int64_t c = to_int(read_constant(idx));
                push_value((int64_t)(a + c));
                break;
            }
            VG_CASE(vg_op_sub_i64_const, OP_SUB_I64_CONST): {
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t idx = code[vm.ip++];
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                pop_value();
                int64_t a = to_int(pop_value());
                int64_t c = to_int(read_constant(idx));
                push_value((int64_t)(a - c));
                break;
            }
            VG_CASE(vg_op_mul_i64_const, OP_MUL_I64_CONST): {
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t idx = code[vm.ip++];
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                pop_value();
                int64_t a = to_int(pop_value());
                int64_t c = to_int(read_constant(idx));
                push_value((int64_t)(a * c));
                break;
            }
            VG_CASE(vg_op_add_local_i64_stack, OP_ADD_LOCAL_I64_STACK): {
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t slot = code[vm.ip++];
                int64_t delta = to_int(pop_value());
                int64_t base = to_int(read_local(slot));
                int64_t result = base + delta;
                sync_local(slot, (int64_t)result);
                break;
            }
            VG_CASE(vg_op_sub_local_i64_stack, OP_SUB_LOCAL_I64_STACK): {
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t slot = code[vm.ip++];
                int64_t delta = to_int(pop_value());
                int64_t base = to_int(read_local(slot));
                sync_local(slot, (int64_t)(base - delta));
                break;
            }
            VG_CASE(vg_op_add_local_i64_const, OP_ADD_LOCAL_I64_CONST): {
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t slot = code[vm.ip++];
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t idx = code[vm.ip++];
                int64_t base = to_int(read_local(slot));
                sync_local(slot, (int64_t)(base + to_int(read_constant(idx))));
                break;
            }
            VG_CASE(vg_op_sub_local_i64_const, OP_SUB_LOCAL_I64_CONST): {
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t slot = code[vm.ip++];
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t idx = code[vm.ip++];
                int64_t base = to_int(read_local(slot));
                sync_local(slot, (int64_t)(base - to_int(read_constant(idx))));
                break;
            }
            VG_CASE(vg_op_inc_local_i64, OP_INC_LOCAL_I64): {
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t slot = code[vm.ip++];
                int64_t base = to_int(read_local(slot));
                sync_local(slot, (int64_t)(base + 1));
                break;
            }
            VG_CASE(vg_op_accum_i64_muladd_const, OP_ACCUM_I64_MULADD_CONST): {
                // [OP] [S_SLOT] [J_SLOT] [K_CONST]
                // locals[s] += locals[j] * K
                if (vm.ip + 2 >= code_size) { success = false; goto cleanup; }
                uint8_t s_slot = code[vm.ip++];
                uint8_t j_slot = code[vm.ip++];
                uint8_t k_idx  = code[vm.ip++];
                int64_t s_val = to_int(read_local(s_slot));
                int64_t j_val = to_int(read_local(j_slot));
                int64_t k_val = to_int(read_constant(k_idx));
                sync_local(s_slot, (int64_t)(s_val + j_val * k_val));
                break;
            }
            VG_CASE(vg_op_arith_sum, OP_ARITH_SUM): {
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t k_idx = code[vm.ip++];
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t c_idx = code[vm.ip++];
                if (!ensure_stack(3)) { success = false; goto cleanup; }
                Variant current_sum_var = pop_value();
                Variant outer_variant = pop_value();
                Variant inner_variant = pop_value();
                int64_t current_sum = to_int(current_sum_var);
                int64_t outer_to = to_int(outer_variant);
                int64_t inner_to = to_int(inner_variant);
                int64_t k = to_int(read_constant(k_idx));
                int64_t c = to_int(read_constant(c_idx));
                int64_t n_inner = vg_loop_count(inner_to);
                int64_t n_outer = vg_loop_count(outer_to);
                int64_t result_sum = current_sum;
                if (n_inner > 0 && n_outer > 0) {
                    int64_t inner_end = inner_to >= 0 ? inner_to : -1;
                    int64_t sum_j = (inner_end >= 0) ? (inner_end * (inner_end + 1)) / 2 : 0;
                    int64_t per_inner = k * sum_j + c * n_inner;
                    result_sum += per_inner * n_outer;
                }
                push_value(result_sum);
                break;
            }
            VG_CASE(vg_op_branch_sum, OP_BRANCH_SUM): {
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t flag_slot = code[vm.ip++];
                if (!ensure_stack(3)) { success = false; goto cleanup; }
                int64_t current_sum = to_int(pop_value());
                int64_t n_outer = to_int(pop_value());
                int64_t n_inner = to_int(pop_value());
                if (n_inner < 0) n_inner = 0;
                if (n_outer < 0) n_outer = 0;
                int64_t result_sum = current_sum;
                if (n_inner > 0 && n_outer > 0) {
                    int64_t pairs = n_inner / 2;
                    int64_t per_inner = -pairs;
                    if ((n_inner % 2) == 1) {
                        int64_t last_index = n_inner - 1;
                        if (last_index >= 0) {
                            per_inner += last_index;
                        }
                    }
                    result_sum += per_inner * n_outer;
                    int64_t final_flag = (n_inner % 2) == 1 ? 1 : 0;
                    sync_local(flag_slot, final_flag);
                } else if (n_outer > 0) {
                    sync_local(flag_slot, (int64_t)0);
                }
                push_value(result_sum);
                break;
            }
            VG_CASE(vg_op_len, OP_LEN): {
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                Variant value = pop_value();
                int64_t length = 0;
                switch (value.get_type()) {
                    case Variant::STRING:
                    case Variant::STRING_NAME:
                        length = String(value).length();
                        break;
                    case Variant::ARRAY:
                        length = ((Array)value).size();
                        break;
                    case Variant::DICTIONARY:
                        length = ((Dictionary)value).size();
                        break;
                    default:
                        length = 0;
                        break;
                }
                push_value(length);
                break;
            }
            VG_CASE(vg_op_equal, OP_EQUAL): {
                if (!apply_variant_op(Variant::OP_EQUAL)) { success = false; goto cleanup; }
                break;
            }
            VG_CASE(vg_op_not_equal, OP_NOT_EQUAL):
                if (!apply_variant_op(Variant::OP_NOT_EQUAL)) { success = false; goto cleanup; }
                break;
            VG_CASE(vg_op_greater, OP_GREATER):
                if (!apply_variant_op(Variant::OP_GREATER)) { success = false; goto cleanup; }
                break;
            VG_CASE(vg_op_less, OP_LESS):
                if (!apply_variant_op(Variant::OP_LESS)) { success = false; goto cleanup; }
                break;
            VG_CASE(vg_op_greater_equal, OP_GREATER_EQUAL):
                if (!apply_variant_op(Variant::OP_GREATER_EQUAL)) { success = false; goto cleanup; }
                break;
            VG_CASE(vg_op_less_equal, OP_LESS_EQUAL):
                if (!apply_variant_op(Variant::OP_LESS_EQUAL)) { success = false; goto cleanup; }
                break;
            VG_CASE(vg_op_equal_i64, OP_EQUAL_I64): {
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                int64_t b = to_int(pop_value());
                int64_t a = to_int(pop_value());
                push_value(a == b);
                break;
            }
            VG_CASE(vg_op_not_equal_i64, OP_NOT_EQUAL_I64): {
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                int64_t b = to_int(pop_value());
                int64_t a = to_int(pop_value());
                push_value(a != b);
                break;
            }
            VG_CASE(vg_op_less_equal_i64, OP_LESS_EQUAL_I64): {
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                int64_t b = to_int(pop_value());
                int64_t a = to_int(pop_value());
                push_value(a <= b);
                break;
            }
            VG_CASE(vg_op_not, OP_NOT): {
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                push_value(!to_bool(pop_value()));
                break;
            }
            VG_CASE(vg_op_and, OP_AND): {
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                bool b = to_bool(pop_value());
                bool a = to_bool(pop_value());
                push_value(a && b);
                break;
            }
            VG_CASE(vg_op_or, OP_OR): {
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                bool b = to_bool(pop_value());
                bool a = to_bool(pop_value());
                push_value(a || b);
                break;
            }
            VG_CASE(vg_op_xor, OP_XOR): {
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                bool b = to_bool(pop_value());
                bool a = to_bool(pop_value());
                push_value((a && !b) || (!a && b));
                break;
            }
            VG_CASE(vg_op_jump, OP_JUMP): {
                if (vm.ip + 1 >= code_size) { success = false; goto cleanup; }
                uint8_t hi = code[vm.ip++];
                uint8_t lo = code[vm.ip++];
                int offset = (hi << 8) | lo;
                vm.ip += offset;
                break;
            }
            VG_CASE(vg_op_jump_if_false, OP_JUMP_IF_FALSE): {
                if (vm.ip + 1 >= code_size) { success = false; goto cleanup; }
                uint8_t hi = code[vm.ip++];
                uint8_t lo = code[vm.ip++];
                int offset = (hi << 8) | lo;
                bool condition = to_bool(pop_value());
                if (!condition) {
                    vm.ip += offset;
                }
                break;
            }
            VG_CASE(vg_op_jump_if_true, OP_JUMP_IF_TRUE): {
                if (vm.ip + 1 >= code_size) { success = false; goto cleanup; }
                uint8_t hi = code[vm.ip++];
                uint8_t lo = code[vm.ip++];
                int offset = (hi << 8) | lo;
                bool condition = to_bool(pop_value());
                if (condition) {
                    vm.ip += offset;
                }
                break;
            }
            VG_CASE(vg_op_loop, OP_LOOP): {
                if (vm.ip + 1 >= code_size) { success = false; goto cleanup; }
                uint8_t hi = code[vm.ip++];
                uint8_t lo = code[vm.ip++];
                int offset = (hi << 8) | lo;
                vm.ip -= offset;
                break;
            }
            VG_CASE(vg_op_call, OP_CALL): {
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t name_idx = code[vm.ip++];
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t arg_count = code[vm.ip++];
                if (!ensure_stack(arg_count)) { success = false; goto cleanup; }
                Array args;
                args.resize(arg_count);
                for (int i = arg_count - 1; i >= 0; i--) {
                    args[i] = pop_value();
                }
                String method = read_constant(name_idx);
                bool handled = false;
                Variant call_ret = VisualGasicBuiltins::call_builtin_expr_evaluated(this, method, args, handled);

                // VB6 Array() — build a Godot Array from the arguments
                if (!handled && method.nocasecmp_to("Array") == 0) {
                    call_ret = args;   // args is already a Godot Array of the evaluated arguments
                    handled = true;
                }

                // GetNode("path") — Godot node path lookup (bytecode path)
                if (!handled && method.nocasecmp_to("GetNode") == 0 && args.size() == 1) {
                    String path = args[0];
                    Node *resolve_from = nullptr;
                    if (owner) {
                        resolve_from = Object::cast_to<Node>(owner);
                    }
                    if (resolve_from && resolve_from->is_inside_tree()) {
                        call_ret = resolve_from->get_node_or_null(NodePath(path));
                    } else {
                        call_ret = Variant();
                    }
                    handled = true;
                }

                // Vector2(x, y) — convenience constructor
                if (!handled && method.nocasecmp_to("Vector2") == 0 && args.size() == 2) {
                    call_ret = Vector2(args[0], args[1]);
                    handled = true;
                }

                // Load("path") — load a resource (PackedScene, Texture, etc.)
                if (!handled && method.nocasecmp_to("Load") == 0 && args.size() == 1) {
                    call_ret = ResourceLoader::get_singleton()->load(args[0]);
                    handled = true;
                }

                // CreateTween() — create a Tween on the owner node
                if (!handled && method.nocasecmp_to("CreateTween") == 0 && args.size() == 0) {
                    if (owner) {
                        Node *n = Object::cast_to<Node>(owner);
                        if (n) {
                            call_ret = n->create_tween();
                        } else {
                            call_ret = Variant();
                        }
                    } else {
                        call_ret = Variant();
                    }
                    handled = true;
                }

                // IsOnFloor(body) — CharacterBody2D/3D floor check
                if (!handled && method.nocasecmp_to("IsOnFloor") == 0 && args.size() == 1) {
                    Object *o = args[0];
                    if (o) {
                        CharacterBody2D *cb2 = Object::cast_to<CharacterBody2D>(o);
                        if (cb2) { call_ret = cb2->is_on_floor(); }
                        else {
                            CharacterBody3D *cb3 = Object::cast_to<CharacterBody3D>(o);
                            if (cb3) { call_ret = cb3->is_on_floor(); }
                            else { call_ret = false; }
                        }
                    } else { call_ret = false; }
                    handled = true;
                }

                // IsOnWall(body) — CharacterBody2D/3D wall check
                if (!handled && method.nocasecmp_to("IsOnWall") == 0 && args.size() == 1) {
                    Object *o = args[0];
                    if (o) {
                        CharacterBody2D *cb2 = Object::cast_to<CharacterBody2D>(o);
                        if (cb2) { call_ret = cb2->is_on_wall(); }
                        else {
                            CharacterBody3D *cb3 = Object::cast_to<CharacterBody3D>(o);
                            if (cb3) { call_ret = cb3->is_on_wall(); }
                            else { call_ret = false; }
                        }
                    } else { call_ret = false; }
                    handled = true;
                }

                // MoveAndSlide(body) — CharacterBody2D/3D move and slide
                if (!handled && method.nocasecmp_to("MoveAndSlide") == 0 && args.size() >= 1) {
                    Object *o = args[0];
                    if (o) {
                        CharacterBody2D *cb2 = Object::cast_to<CharacterBody2D>(o);
                        if (cb2) { cb2->move_and_slide(); }
                        else {
                            CharacterBody3D *cb3 = Object::cast_to<CharacterBody3D>(o);
                            if (cb3) { cb3->move_and_slide(); }
                        }
                    }
                    call_ret = Variant();
                    handled = true;
                }

                // SetVelocity(body, x, y [, z]) — set velocity on CharacterBody/RigidBody 2D/3D
                if (!handled && method.nocasecmp_to("SetVelocity") == 0 && args.size() >= 3) {
                    Object *o = args[0];
                    if (o) {
                        double x = args[1];
                        double y = args[2];
                        if (o->is_class("CharacterBody2D")) {
                            Object::cast_to<CharacterBody2D>(o)->set_velocity(Vector2(x, y));
                        } else if (o->is_class("CharacterBody3D")) {
                            double z = (args.size() >= 4) ? (double)args[3] : 0.0;
                            Object::cast_to<CharacterBody3D>(o)->set_velocity(Vector3(x, y, z));
                        } else if (o->is_class("RigidBody2D")) {
                            Object::cast_to<RigidBody2D>(o)->set_linear_velocity(Vector2(x, y));
                        } else if (o->is_class("RigidBody3D")) {
                            double z = (args.size() >= 4) ? (double)args[3] : 0.0;
                            Object::cast_to<RigidBody3D>(o)->set_linear_velocity(Vector3(x, y, z));
                        }
                    }
                    call_ret = Variant();
                    handled = true;
                }

                // GetCollisionCount(body) — CharacterBody2D/3D slide collision count
                if (!handled && method.nocasecmp_to("GetCollisionCount") == 0 && args.size() == 1) {
                    Object *o = args[0];
                    if (o) {
                        CharacterBody2D *cb2 = Object::cast_to<CharacterBody2D>(o);
                        if (cb2) { call_ret = cb2->get_slide_collision_count(); }
                        else {
                            CharacterBody3D *cb3 = Object::cast_to<CharacterBody3D>(o);
                            if (cb3) { call_ret = cb3->get_slide_collision_count(); }
                            else { call_ret = (int64_t)0; }
                        }
                    } else { call_ret = (int64_t)0; }
                    handled = true;
                }

                // GetAxis("negative", "positive") — Input axis
                if (!handled && method.nocasecmp_to("GetAxis") == 0 && args.size() == 2) {
                    call_ret = Input::get_singleton()->get_axis(args[0], args[1]);
                    handled = true;
                }

                // IsActionPressed / IsActionJustPressed / IsActionJustReleased
                if (!handled && method.nocasecmp_to("IsActionPressed") == 0 && args.size() == 1) {
                    call_ret = Input::get_singleton()->is_action_pressed(String(args[0]));
                    handled = true;
                }
                if (!handled && method.nocasecmp_to("IsActionJustPressed") == 0 && args.size() == 1) {
                    call_ret = Input::get_singleton()->is_action_just_pressed(String(args[0]));
                    handled = true;
                }
                if (!handled && method.nocasecmp_to("IsActionJustReleased") == 0 && args.size() == 1) {
                    call_ret = Input::get_singleton()->is_action_just_released(String(args[0]));
                    handled = true;
                }

                if (!handled) {
                    bool found = false;
                    call_ret = call_internal(method, args, found);
                    if (!found) {
                        // Check for lambda variable invocation (e.g. Collides(...), Distance(...))
                        if (variables.has(method)) {
                            Variant v = variables[method];
                            if (v.get_type() == Variant::DICTIONARY) {
                                Dictionary d = v;
                                if (d.has("__vg_lambda") && (bool)d["__vg_lambda"]) {
                                    call_ret = invoke_lambda(d, args);
                                    found = true;
                                }
                            }
                        }
                        if (!found) {
                            bool stmt_found = false;
                            dispatch_builtin_call(method, args, stmt_found);
                            if (!stmt_found && owner) {
                                // Fallback: try calling the method on the owner node
                                // (matches AST interpreter's STMT_CALL fallback at end)
                                if (owner->has_method(method)) {
                                    call_ret = owner->callv(method, args);
                                } else {
                                    String snake = method.to_snake_case();
                                    if (owner->has_method(snake)) {
                                        call_ret = owner->callv(snake, args);
                                    } else {
                                        call_ret = Variant();
                                    }
                                }
                            } else {
                                call_ret = Variant();
                            }
                        }
                    }
                }
                push_value(call_ret);
                break;
            }
            VG_CASE(vg_op_return, OP_RETURN): {
                vm.ip = code_size;
                break;
            }
            VG_CASE(vg_op_return_value, OP_RETURN_VALUE): {
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                explicit_return = pop_value();
                has_explicit_return = true;
                vm.ip = code_size;
                break;
            }
            VG_CASE(vg_op_print, OP_PRINT): {
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                Variant val = pop_value();
                UtilityFunctions::print(val);
                if (owner) {
                    Node *owner_node = Object::cast_to<Node>(owner);
                    if (owner_node && owner_node->is_inside_tree()) {
                        Node *console = owner_node->get_tree()->get_root()->find_child("ImmediateWindow", true, false);
                        if (console && console->has_method("append_text")) {
                            console->call("append_text", String(val) + "\n");
                        } else {
                            Node *dbg = owner_node->get_tree()->get_root()->find_child("DebugConsole", true, false);
                            if (dbg && dbg->has_method("append_text")) {
                                dbg->call("append_text", String(val) + "\n");
                            }
                        }
                    }
                }
                break;
            }
            VG_CASE(vg_op_debug_print, OP_DEBUG_PRINT): {
                // Debug.Print → route to Immediate Window via debugger protocol
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                Variant val = pop_value();
                UtilityFunctions::print(val);  // Also print to Output console
                EngineDebugger* engine_debugger = EngineDebugger::get_singleton();
                if (engine_debugger && engine_debugger->is_active()) {
                    Array data;
                    data.push_back(String(val));
                    engine_debugger->send_message("visualgasic:debug_print", data);
                }
                // Also try scene tree approach as fallback
                if (owner) {
                    Node *owner_node = Object::cast_to<Node>(owner);
                    if (owner_node && owner_node->is_inside_tree()) {
                        Node *console = owner_node->get_tree()->get_root()->find_child("ImmediateWindow", true, false);
                        if (console && console->has_method("append_text")) {
                            console->call("append_text", "[Debug] " + String(val) + "\n");
                        }
                    }
                }
                break;
            }
            VG_CASE(vg_op_new_array, OP_NEW_ARRAY):
            VG_CASE(vg_op_new_array_i64, OP_NEW_ARRAY_I64): {
                PROFILE_OPCODE(NewArray);
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                int64_t length = to_int(pop_value());
                if (length < 0) {
                    length = 0;
                }
                Array arr;
                arr.resize(length);
                if (op == OP_NEW_ARRAY_I64) {
                    for (int64_t i = 0; i < length; i++) {
                        arr[i] = (int64_t)0;
                    }
                }
                push_value(arr);
                break;
            }
            VG_CASE(vg_op_new_dict, OP_NEW_DICT): {
                PROFILE_OPCODE(NewDict);
                Dictionary dict;
                push_value(dict);
                break;
            }
            VG_CASE(vg_op_get_array, OP_GET_ARRAY):
            VG_CASE(vg_op_get_array_unchecked, OP_GET_ARRAY_UNCHECKED): {
                PROFILE_OPCODE(GetArray);
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t arg_count = code[vm.ip++];
                if (!ensure_stack(arg_count + 1)) { success = false; goto cleanup; }
                Vector<Variant> indices;
                indices.resize(arg_count);
                for (int i = arg_count - 1; i >= 0; i--) {
                    indices.write[i] = pop_value();
                }
                Variant base = pop_value();
                Variant result;
                if (base.get_type() == Variant::ARRAY && arg_count == 1) {
                    Array arr = base;
                    int idx = (int)to_int(indices[0]);
                    if (idx < 0 || idx >= arr.size()) {
                        if (op == OP_GET_ARRAY_UNCHECKED) {
                            result = Variant();
                        } else {
                            raise_error("Array subscript out of range", 9);
                            if (try_recover_error(Variant())) break;
                            success = false;
                            goto cleanup;
                        }
                    } else {
                        result = arr[idx];
                    }
                } else if (base.get_type() == Variant::DICTIONARY && arg_count == 1) {
                    Dictionary dict = base;
                    result = dict.get(indices[0], Variant());
                } else {
                    raise_error("Unsupported array base type");
                    if (try_recover_error(Variant())) break;
                    success = false;
                    goto cleanup;
                }
                push_value(result);
                break;
            }
            VG_CASE(vg_op_get_array_fast, OP_GET_ARRAY_FAST):
            VG_CASE(vg_op_get_array_fast_unchecked, OP_GET_ARRAY_FAST_UNCHECKED): {
                PROFILE_OPCODE(GetArray);
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t arg_count = code[vm.ip++];
                if (arg_count != 1) {
                    raise_error("Fast array opcode supports exactly one index");
                    if (try_recover_error(Variant())) break;
                    success = false;
                    goto cleanup;
                }
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                Variant index_var = pop_value();
                Variant base = pop_value();
                if (base.get_type() != Variant::ARRAY) {
                    raise_error("Fast array base is not an array");
                    if (try_recover_error(Variant())) break;
                    success = false;
                    goto cleanup;
                }
                const Array *arr_ptr = VariantInternal::get_array(&base);
                int64_t idx = to_int(index_var);
                if (idx < 0 || idx >= arr_ptr->size()) {
                    if (op == OP_GET_ARRAY_FAST_UNCHECKED) {
                        push_value(Variant());
                        break;
                    }
                    raise_error("Array subscript out of range", 9);
                    if (try_recover_error(Variant())) break;
                    success = false;
                    goto cleanup;
                }
                push_value((*arr_ptr)[idx]);
                break;
            }
            VG_CASE(vg_op_get_dict_fast, OP_GET_DICT_FAST):
            VG_CASE(vg_op_get_dict_trusted, OP_GET_DICT_TRUSTED): {
                PROFILE_OPCODE(GetDict);
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t arg_count = code[vm.ip++];
                if (arg_count != 1) {
                    raise_error("Fast dictionary opcode supports exactly one key");
                    if (try_recover_error(Variant())) break;
                    success = false;
                    goto cleanup;
                }
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                Variant key_var = pop_value();
                Variant base = pop_value();
                if (op == OP_GET_DICT_FAST) {
                    if (base.get_type() != Variant::DICTIONARY) {
                        raise_error("Fast dictionary base is not a dictionary");
                        if (try_recover_error(Variant())) break;
                        success = false;
                        goto cleanup;
                    }
                }
#ifdef DEBUG_ENABLED
                else {
                    if (base.get_type() != Variant::DICTIONARY) {
                        raise_error("Trusted dictionary base is not a dictionary");
                        if (try_recover_error(Variant())) break;
                        success = false;
                        goto cleanup;
                    }
                }
#endif
                // Direct dictionary access via pointer
                const Dictionary *dict_ptr = VariantInternal::get_dictionary(&base);
                push_value(dict_ptr->get(key_var, Variant()));
                break;
            }
            VG_CASE(vg_op_set_array, OP_SET_ARRAY):
            VG_CASE(vg_op_set_array_unchecked, OP_SET_ARRAY_UNCHECKED): {
                PROFILE_OPCODE(SetArray);
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t arg_count = code[vm.ip++];
                if (!ensure_stack(arg_count + 2)) { success = false; goto cleanup; }
                Variant value = pop_value();
                Vector<Variant> indices;
                indices.resize(arg_count);
                for (int i = arg_count - 1; i >= 0; i--) {
                    indices.write[i] = pop_value();
                }
                Variant base = pop_value();
                Variant updated = base;
                bool ok = true;
                if (base.get_type() == Variant::ARRAY && arg_count == 1) {
                    Array arr = base;
                    int idx = (int)to_int(indices[0]);
                    if (idx < 0 || idx >= arr.size()) {
                        if (op == OP_SET_ARRAY_UNCHECKED) {
                            ok = false;
                        } else {
                            raise_error("Array subscript out of range", 9);
                            if (try_recover_error(base)) break;
                            success = false;
                            goto cleanup;
                        }
                    } else if (ok) {
                        arr[idx] = value;
                        updated = arr;
                    }
                } else if (base.get_type() == Variant::DICTIONARY && arg_count == 1) {
                    Dictionary dict = base;
                    dict[indices[0]] = value;
                    updated = dict;
                } else {
                    raise_error("Unsupported array assignment base");
                    if (try_recover_error(base)) break;
                    success = false;
                    goto cleanup;
                }
                push_value(updated);
                break;
            }
            VG_CASE(vg_op_set_array_fast, OP_SET_ARRAY_FAST):
            VG_CASE(vg_op_set_array_fast_unchecked, OP_SET_ARRAY_FAST_UNCHECKED): {
                PROFILE_OPCODE(SetArray);
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t arg_count = code[vm.ip++];
                if (arg_count != 1) {
                    raise_error("Fast array opcode supports exactly one index");
                    if (try_recover_error(Variant(), false)) break;
                    success = false;
                    goto cleanup;
                }
                if (!ensure_stack(arg_count + 2)) { success = false; goto cleanup; }
                Variant value = pop_value();
                Variant index_var = pop_value();
                Variant base = pop_value();
                if (base.get_type() != Variant::ARRAY) {
                    raise_error("Fast array assignment base is not an array");
                    if (try_recover_error(base)) break;
                    success = false;
                    goto cleanup;
                }
                Array *arr_ptr = VariantInternal::get_array(&base);
                int64_t idx = to_int(index_var);
                if (idx < 0 || idx >= arr_ptr->size()) {
                    if (op == OP_SET_ARRAY_FAST_UNCHECKED) {
                        push_value(base);
                        break;
                    }
                    raise_error("Array subscript out of range", 9);
                    if (try_recover_error(base)) break;
                    success = false;
                    goto cleanup;
                }
                (*arr_ptr)[idx] = value;
                push_value(base);
                break;
            }
            VG_CASE(vg_op_set_dict_fast, OP_SET_DICT_FAST):
            VG_CASE(vg_op_set_dict_trusted, OP_SET_DICT_TRUSTED): {
                PROFILE_OPCODE(SetDict);
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t arg_count = code[vm.ip++];
                if (arg_count != 1) {
                    raise_error("Fast dictionary opcode supports exactly one key");
                    if (try_recover_error(Variant(), false)) break;
                    success = false;
                    goto cleanup;
                }
                if (!ensure_stack(arg_count + 2)) { success = false; goto cleanup; }
                Variant value = pop_value();
                Variant key_var = pop_value();
                Variant base = pop_value();
                if (op == OP_SET_DICT_FAST) {
                    if (base.get_type() != Variant::DICTIONARY) {
                        raise_error("Fast dictionary assignment base is not a dictionary");
                        if (try_recover_error(base)) break;
                        success = false;
                        goto cleanup;
                    }
                }
#ifdef DEBUG_ENABLED
                else {
                    if (base.get_type() != Variant::DICTIONARY) {
                        raise_error("Trusted dictionary assignment base is not a dictionary");
                        if (try_recover_error(base)) break;
                        success = false;
                        goto cleanup;
                    }
                }
#endif
                // Direct dictionary modification via pointer
                Dictionary *dict_ptr = VariantInternal::get_dictionary(&base);
                (*dict_ptr)[key_var] = value;
                push_value(base);
                break;
            }
            VG_CASE(vg_op_set_dict_local, OP_SET_DICT_LOCAL):
            VG_CASE(vg_op_set_dict_global, OP_SET_DICT_GLOBAL): {
                PROFILE_OPCODE(SetDict);
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t slot_or_idx = code[vm.ip++];
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t arg_count = code[vm.ip++];
                
                if (arg_count != 1) {
                    raise_error("In-place dictionary opcode supports exactly one key");
                    if (try_recover_error(Variant(), false)) break;
                    success = false;
                    goto cleanup;
                }
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                
                Variant value = pop_value();
                Variant key_var = pop_value();
                
                // Get reference to the dict variable without copying
                Variant *dict_var_ptr = nullptr;
                if (op == OP_SET_DICT_LOCAL) {
                    if (slot_or_idx < 0 || slot_or_idx >= locals.size()) {
                        raise_error("Invalid local slot in OP_SET_DICT_LOCAL");
                        if (try_recover_error(Variant(), false)) break;
                        success = false;
                        goto cleanup;
                    }
                    dict_var_ptr = &locals.write[slot_or_idx];
                } else {  // OP_SET_DICT_GLOBAL
                    String var_name = read_constant(slot_or_idx);
                    if (!variables.has(var_name)) {
                        raise_error("Global variable not found: " + var_name);
                        if (try_recover_error(Variant(), false)) break;
                        success = false;
                        goto cleanup;
                    }
                    dict_var_ptr = &variables[var_name];
                }
                
                if (dict_var_ptr->get_type() != Variant::DICTIONARY) {
                    raise_error("In-place dictionary opcode: variable is not a dictionary");
                    if (try_recover_error(Variant(), false)) break;
                    success = false;
                    goto cleanup;
                }
                
                // Direct dictionary modification via pointer
                Dictionary *dict_ptr = VariantInternal::get_dictionary(dict_var_ptr);
                (*dict_ptr)[key_var] = value;
                
                // Note: No need to sync to variables HashMap - COW ensures both point to same data
                break;
            }
            // ── VGFastStringDict opcodes (sole-owner fast path) ──────────
            VG_CASE(vg_op_new_vgdict, OP_NEW_VGDICT): {
                PROFILE_OPCODE(NewDict);
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t slot = code[vm.ip++];
                if (slot >= VGDICT_POOL_MAX) {
                    raise_error("OP_NEW_VGDICT: slot out of range");
                    if (try_recover_error(Variant(), false)) break;
                    success = false;
                    goto cleanup;
                }
                vgdict_pool[slot].clear();
                vgdict_slot_active[slot] = true;
                // Also put a placeholder in locals[] so the rest of the VM
                // doesn't trip on an uninitialised slot (e.g. variable sync at cleanup)
                if (slot < locals.size()) {
                    locals.write[slot] = Dictionary();  // placeholder
                }
                break;
            }
            VG_CASE(vg_op_get_vgdict_local, OP_GET_VGDICT_LOCAL): {
                PROFILE_OPCODE(GetDict);
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t slot = code[vm.ip++];
                if (vm.stack.size() <= stack_base) { success = false; goto cleanup; }
                if (slot >= VGDICT_POOL_MAX || !vgdict_slot_active[slot]) {
                    raise_error("OP_GET_VGDICT_LOCAL: invalid VGDict slot");
                    if (try_recover_error(Variant())) break;
                    success = false;
                    goto cleanup;
                }
                {
                    // Access key directly on TOS without copy, then replace TOS with result
                    int top = vm.stack.size() - 1;
                    const Variant &key_ref = vm.stack[top];
                    Variant *vptr = nullptr;
                    if (key_ref.get_type() == Variant::STRING) {
                        vptr = vgdict_pool[slot].getptr(key_ref);
                    } else {
                        String skey = key_ref;
                        vptr = vgdict_pool[slot].getptr(skey);
                    }
                    // Replace TOS in-place (avoids pop+push Variant copy)
                    vm.stack[top] = vptr ? *vptr : Variant();
                }
                break;
            }
            VG_CASE(vg_op_set_vgdict_local, OP_SET_VGDICT_LOCAL): {
                PROFILE_OPCODE(SetDict);
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t slot = code[vm.ip++];
                if (vm.stack.size() < stack_base + 2) { success = false; goto cleanup; }
                if (slot >= VGDICT_POOL_MAX || !vgdict_slot_active[slot]) {
                    raise_error("OP_SET_VGDICT_LOCAL: invalid VGDict slot");
                    if (try_recover_error(Variant(), false)) break;
                    success = false;
                    goto cleanup;
                }
                {
                    int top = vm.stack.size() - 1;
                    // Stack: [..., key, value]  (value is TOS)
                    const Variant &val_ref = vm.stack[top];
                    const Variant &key_ref = vm.stack[top - 1];
                    if (key_ref.get_type() == Variant::STRING) {
                        vgdict_pool[slot].set(key_ref, val_ref);
                    } else {
                        String skey = key_ref;
                        vgdict_pool[slot].set(skey, val_ref);
                    }
                    // Pop both key and value
                    vm.stack.resize(top - 1);
                }
                break;
            }
            VG_CASE(vg_op_sum_array_i64, OP_SUM_ARRAY_I64): {
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                Variant arr_var = pop_value();
                int64_t sum = 0;
                if (arr_var.get_type() == Variant::ARRAY) {
                    const Array *arr_ptr = VariantInternal::get_array(&arr_var);
                    int count = arr_ptr->size();
                    for (int i = 0; i < count; i++) {
                        sum += to_int((*arr_ptr)[i]);
                    }
                }
                push_value(sum);
                break;
            }
            VG_CASE(vg_op_sum_dict_i64, OP_SUM_DICT_I64): {
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                Variant dict_var = pop_value();
                int64_t sum = 0;
                if (dict_var.get_type() == Variant::DICTIONARY) {
                    Dictionary dict = dict_var;
                    Array keys = dict.keys();
                    for (int i = 0; i < keys.size(); i++) {
                        Variant key = keys[i];
                        sum += to_int(dict.get(key, Variant()));
                    }
                } else {
                    // Non-dictionary type, sum stays 0
                }
                push_value(sum);
                break;
            }
            VG_CASE(vg_op_sum_vgdict_all_i64, OP_SUM_VGDICT_ALL_I64): {
                PROFILE_OPCODE(SumVGDictAll);
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t slot = code[vm.ip++];
                if (slot >= VGDICT_POOL_MAX || !vgdict_slot_active[slot]) {
                    raise_error("OP_SUM_VGDICT_ALL_I64: invalid VGDict slot");
                    if (try_recover_error(Variant((int64_t)0))) break;
                    success = false;
                    goto cleanup;
                }
                {
                    int64_t sum = 0;
                    VGFastStringDict &d = vgdict_pool[slot];
                    if (d.table) {
                        for (uint32_t i = 0; i < d.capacity; i++) {
                            if (d.table[i].occupied) {
                                sum += to_int(d.table[i].value);
                            }
                        }
                    }
                    push_value(sum);
                }
                break;
            }
            VG_CASE(vg_op_array_fill_i64_seq, OP_ARRAY_FILL_I64_SEQ): {
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                int64_t count = to_int(pop_value());
                Variant arr_var = pop_value();
                Array arr;
                if (arr_var.get_type() == Variant::ARRAY) {
                    arr = arr_var;
                }
                if (count < 0) {
                    count = 0;
                }
                arr.resize((int)count);
                for (int64_t i = 0; i < count; i++) {
                    arr[(int)i] = (int64_t)i;
                }
                push_value(arr);
                break;
            }
            VG_CASE(vg_op_alloc_fill_i64, OP_ALLOC_FILL_I64): {
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                int64_t count = to_int(pop_value());
                if (count < 0) {
                    count = 0;
                }
                Array arr;
                arr.resize((int)count);
                for (int64_t i = 0; i < count; i++) {
                    arr[(int)i] = (int64_t)i;
                }
                push_value(arr);
                break;
            }
            VG_CASE(vg_op_alloc_fill_repeat_i64, OP_ALLOC_FILL_REPEAT_I64): {
                if (vm.ip + 5 >= code_size) { success = false; goto cleanup; }
                uint8_t sum_slot = code[vm.ip++];
                uint8_t arr_slot = code[vm.ip++];
                uint8_t tmp_slot = code[vm.ip++];
                uint8_t lit_idx = code[vm.ip++];
                uint8_t iter_slot = code[vm.ip++];
                uint8_t size_slot = code[vm.ip++];

                int64_t iterations = to_int(read_local(iter_slot));
                if (iterations < 0) {
                    iterations = 0;
                }
                int64_t size = to_int(read_local(size_slot));
                if (size < 0) {
                    size = 0;
                }

                // Simulate the final state of the arrays
                Array arr;
                arr.resize((int)size);
                for (int64_t i = 0; i < size; i++) {
                    arr[(int)i] = (int64_t)(iterations - 1 + i);
                }
                sync_local(arr_slot, arr);

                String literal = read_constant(lit_idx);
                String tmp = vg_repeat_literal(literal, size);
                sync_local(tmp_slot, tmp);

                // Compute closed-form sum:
                // For each iter in 0..iterations-1:
                //   inner_sum = sum(iter + i, i=0..size-1) = iter*size + size*(size-1)/2
                //   len_text = size (number of chars in text = "x" repeated size times)
                //   total_per_iter = inner_sum + len_text
                // Total = sum over iter: size * iterations*(iterations-1)/2 + iterations * (size*(size-1)/2 + size)
                //       = size * iterations*(iterations-1)/2 + iterations * size * (size+1) / 2
                int64_t base_sum = to_int(read_local(sum_slot));
                int64_t sum_increase = size * (iterations * (iterations - 1) / 2)
                                     + iterations * size * (size + 1) / 2;
                base_sum += sum_increase;
                push_value(base_sum);
                break;
            }
            VG_CASE(vg_op_get_member, OP_GET_MEMBER): {
                PROFILE_OPCODE(GetMember);
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t idx = code[vm.ip++];
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                int member_idx = idx;
                if (member_idx >= member_name_cache.size()) {
                    raise_error("Invalid member constant index");
                    if (try_recover_error(Variant())) break;
                    success = false;
                    goto cleanup;
                }
                MemberNameCacheEntry &cache = ensure_member_cache_entry(member_idx);
                Variant base = pop_value();
                
                Variant result;
                // VG class instance (object ID is an integer)
                if (base.get_type() == Variant::INT) {
                    int obj_id = (int)base;
                    if (object_instances.has(obj_id)) {
                        get_object_member(obj_id, cache.primary_string, result);
                        push_value(result);
                        break;
                    }
                }
                if (base.get_type() == Variant::DICTIONARY) {
                    const Dictionary *dict = VariantInternal::get_dictionary(&base);
                    result = dict->get(cache.primary_string, Variant());
                } else if (base.get_type() == Variant::VECTOR2) {
                    // Handle Vector2.x, Vector2.y member access
                    Vector2 vec = base;
                    String member = cache.primary_string.to_lower();
                    if (member == "x") result = vec.x;
                    else if (member == "y") result = vec.y;
                } else if (base.get_type() == Variant::VECTOR3) {
                    // Handle Vector3.x, Vector3.y, Vector3.z member access
                    Vector3 vec = base;
                    String member = cache.primary_string.to_lower();
                    if (member == "x") result = vec.x;
                    else if (member == "y") result = vec.y;
                    else if (member == "z") result = vec.z;
                } else if (base.get_type() == Variant::COLOR) {
                    // Handle Color.r, Color.g, Color.b, Color.a member access
                    Color col = base;
                    String member = cache.primary_string.to_lower();
                    if (member == "r" || member == "red") result = col.r;
                    else if (member == "g" || member == "green") result = col.g;
                    else if (member == "b" || member == "blue") result = col.b;
                    else if (member == "a" || member == "alpha") result = col.a;
                } else if (base.get_type() == Variant::RECT2) {
                    // Handle Rect2.position, Rect2.size member access
                    Rect2 rect = base;
                    String member = cache.primary_string.to_lower();
                    if (member == "position") result = rect.position;
                    else if (member == "size") result = rect.size;
                    else if (member == "end") result = rect.get_end();
                } else if (base.get_type() == Variant::OBJECT) {
                    Object *obj = base;
                    if (obj) {
                        // VB6 Property Aliasing for common properties (READ)
                        String prop_name = cache.primary_string;
                        bool handled = false;
                        
                        // Text/Caption properties
                        if (prop_name == "Text" || prop_name == "Caption") {
                            result = obj->get("text");
                            handled = true;
                        }
                        // Visibility
                        else if (prop_name == "Visible") {
                            result = obj->get("visible");
                            handled = true;
                        }
                        // Enabled (invert Godot's "disabled")
                        else if (prop_name == "Enabled") {
                            // Try to get disabled property using StringName
                            StringName disabled_sn = StringName("disabled");
                            Variant disabled_val = obj->get(disabled_sn);
                            if (disabled_val.get_type() == Variant::BOOL) {
                                result = !(bool)disabled_val;
                            } else {
                                // Fallback: try editable property for LineEdit, etc.
                                StringName editable_sn = StringName("editable");
                                Variant editable_val = obj->get(editable_sn);
                                if (editable_val.get_type() == Variant::BOOL) {
                                    result = (bool)editable_val;
                                } else {
                                    result = true; // Default to enabled
                                }
                            }
                            handled = true;
                        }
                        // Position properties
                        else if (prop_name == "Left") {
                            Control* ctrl = Object::cast_to<Control>(obj);
                            if (ctrl) {
                                result = ctrl->get_position().x;
                                handled = true;
                            }
                        }
                        else if (prop_name == "Top") {
                            Control* ctrl = Object::cast_to<Control>(obj);
                            if (ctrl) {
                                result = ctrl->get_position().y;
                                handled = true;
                            }
                        }
                        // Size properties
                        else if (prop_name == "Width") {
                            Control* ctrl = Object::cast_to<Control>(obj);
                            if (ctrl) {
                                result = ctrl->get_size().x;
                                handled = true;
                            }
                        }
                        else if (prop_name == "Height") {
                            Control* ctrl = Object::cast_to<Control>(obj);
                            if (ctrl) {
                                result = ctrl->get_size().y;
                                handled = true;
                            }
                        }
                        // Value property
                        else if (prop_name == "Value") {
                            result = obj->get("value");
                            handled = true;
                        }
                        // ToolTipText → tooltip_text
                        else if (prop_name == "ToolTipText") {
                            result = obj->get("tooltip_text");
                            handled = true;
                        }
                        // TabStop → focus_mode (True = FOCUS_ALL, False = FOCUS_NONE)
                        else if (prop_name == "TabStop") {
                            int fm = (int)obj->get("focus_mode");
                            result = (fm != 0);  // FOCUS_NONE=0
                            handled = true;
                        }
                        // Opacity → modulate.a (0–100 VB6 scale → 0.0–1.0)
                        else if (prop_name == "Opacity") {
                            Control *ctrl = Object::cast_to<Control>(obj);
                            if (ctrl) {
                                result = (int)(ctrl->get_modulate().a * 100.0f);
                                handled = true;
                            }
                        }
                        // MousePointer → mouse_default_cursor_shape
                        else if (prop_name == "MousePointer") {
                            result = obj->get("mouse_default_cursor_shape");
                            handled = true;
                        }
                        // Locked → !editable (TextEdit/LineEdit)
                        else if (prop_name == "Locked") {
                            Variant ed = obj->get("editable");
                            if (ed.get_type() == Variant::BOOL) {
                                result = !(bool)ed;
                            } else {
                                result = false;
                            }
                            handled = true;
                        }
                        // MaxLength → max_length (LineEdit)
                        else if (prop_name == "MaxLength") {
                            result = obj->get("max_length");
                            handled = true;
                        }
                        // Alignment → horizontal_alignment
                        else if (prop_name == "Alignment") {
                            result = obj->get("horizontal_alignment");
                            handled = true;
                        }
                        // WordWrap → autowrap_mode (Label)
                        else if (prop_name == "WordWrap") {
                            int mode = (int)obj->get("autowrap_mode");
                            result = (mode != 0);  // OFF=0
                            handled = true;
                        }
                        // FontSize (runtime read)
                        else if (prop_name == "FontSize") {
                            Control *ctrl = Object::cast_to<Control>(obj);
                            if (ctrl) {
                                result = ctrl->get_theme_font_size("font_size");
                                handled = true;
                            }
                        }
                        // ForeColor → theme font_color
                        else if (prop_name == "ForeColor") {
                            Control *ctrl = Object::cast_to<Control>(obj);
                            if (ctrl) {
                                result = ctrl->get_theme_color("font_color");
                                handled = true;
                            }
                        }
                        // BackColor → StyleBox bg_color or self_modulate fallback
                        else if (prop_name == "BackColor") {
                            Control *ctrl = Object::cast_to<Control>(obj);
                            if (ctrl) {
                                Ref<StyleBox> sb = ctrl->get_theme_stylebox("normal");
                                if (sb.is_valid()) {
                                    Ref<StyleBoxFlat> sbf = sb;
                                    if (sbf.is_valid()) {
                                        result = sbf->get_bg_color();
                                        handled = true;
                                    }
                                }
                                if (!handled) {
                                    result = ctrl->get_self_modulate();
                                    handled = true;
                                }
                            }
                        }
                        
                        if (handled) {
                            push_value(result);
                            break;
                        }
                        
                        StringName class_name = StringName(obj->get_class());
                        MemberNameCacheEntry::AccessPreference *class_pref = resolve_class_preference(cache, class_name);
                        auto try_primary = [&]() -> bool {
                            Variant value = obj->get(cache.primary_name);
                            if (value.get_type() != Variant::NIL) {
                                result = value;
                                *class_pref = MemberNameCacheEntry::AccessPreference::PRIMARY;
                                return true;
                            }
                            return false;
                        };
                        auto try_snake = [&]() -> bool {
                            if (!ensure_snake_case(cache)) {
                                return false;
                            }
                            Variant value = obj->get(cache.snake_name);
                            if (value.get_type() != Variant::NIL) {
                                result = value;
                                *class_pref = MemberNameCacheEntry::AccessPreference::SNAKE;
                                return true;
                            }
                            return false;
                        };

                        switch (*class_pref) {
                            case MemberNameCacheEntry::AccessPreference::SNAKE:
                                if (try_snake()) {
                                    break;
                                }
                                try_primary();
                                break;
                            case MemberNameCacheEntry::AccessPreference::PRIMARY:
                                if (try_primary()) {
                                    break;
                                }
                                try_snake();
                                break;
                            default:
                                if (!try_primary()) {
                                    try_snake();
                                }
                                break;
                        }
                        // Fallback: if result is still NIL, try class integer constants
                        // This handles ClassName.ENUM_VALUE (e.g. Input.MOUSE_MODE_CAPTURED)
                        // Try as-is first, then UPPER_CASE (tokenizer normalises keywords
                        // like READ → "Read" but Godot constants are ALL_CAPS).
                        if (result.get_type() == Variant::NIL && obj) {
                            StringName cn = obj->get_class();
                            StringName mname = cache.primary_string;
                            if (!ClassDB::class_has_integer_constant(cn, mname)) {
                                mname = String(mname).to_upper();
                            }
                            if (ClassDB::class_has_integer_constant(cn, mname)) {
                                result = (int)ClassDB::class_get_integer_constant(cn, mname);
                            }
                        }
                    }
                }
                push_value(result);
                break;
            }
            VG_CASE(vg_op_set_member, OP_SET_MEMBER): {
                PROFILE_OPCODE(SetMember);
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t idx = code[vm.ip++];
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                int member_idx = idx;
                if (member_idx >= member_name_cache.size()) {
                    raise_error("Invalid member constant index");
                    if (try_recover_error(Variant(), false)) break;
                    success = false;
                    goto cleanup;
                }
                MemberNameCacheEntry &cache = ensure_member_cache_entry(member_idx);
                Variant value = pop_value();
                Variant base = pop_value();
                // VG class instance (object ID is an integer)
                if (base.get_type() == Variant::INT) {
                    int obj_id = (int)base;
                    if (object_instances.has(obj_id)) {
                        set_object_member(obj_id, cache.primary_string, value);
                        push_value(base);  // Push base back (object ID unchanged)
                        break;
                    }
                }
                if (base.get_type() == Variant::DICTIONARY) {
                    Dictionary *dict = VariantInternal::get_dictionary(&base);
                    (*dict)[cache.primary_string] = value;
                    push_value(base);  // Push modified dictionary back
                } else if (base.get_type() == Variant::VECTOR2) {
                    // Value types need to be reconstructed
                    Vector2 vec = base;
                    String member = cache.primary_string.to_lower();
                    if (member == "x") vec.x = (real_t)(double)value;
                    else if (member == "y") vec.y = (real_t)(double)value;
                    push_value(vec);
                } else if (base.get_type() == Variant::VECTOR3) {
                    Vector3 vec = base;
                    String member = cache.primary_string.to_lower();
                    if (member == "x") vec.x = (real_t)(double)value;
                    else if (member == "y") vec.y = (real_t)(double)value;
                    else if (member == "z") vec.z = (real_t)(double)value;
                    push_value(vec);
                } else if (base.get_type() == Variant::COLOR) {
                    Color col = base;
                    String member = cache.primary_string.to_lower();
                    if (member == "r" || member == "red") col.r = (float)(double)value;
                    else if (member == "g" || member == "green") col.g = (float)(double)value;
                    else if (member == "b" || member == "blue") col.b = (float)(double)value;
                    else if (member == "a" || member == "alpha") col.a = (float)(double)value;
                    push_value(col);
                } else if (base.get_type() == Variant::OBJECT) {
                    Object *obj = base;
                    if (obj) {
                        // VB6 Property Aliasing for common properties
                        String prop_name = cache.primary_string;
                        String godot_prop;
                        
                        // Text/Caption properties
                        if (prop_name == "Text" || prop_name == "Caption") {
                            godot_prop = "text";
                        }
                        // Visibility
                        else if (prop_name == "Visible") {
                            godot_prop = "visible";
                        }
                        // Enabled/Disabled
                        else if (prop_name == "Enabled") {
                            // Check if object has "disabled" property (Button, CheckBox, etc.)
                            // or "editable" property (LineEdit, TextEdit)
                            Variant test_disabled = obj->get("disabled");
                            if (test_disabled.get_type() == Variant::BOOL) {
                                godot_prop = "disabled";
                                // Invert the boolean for Godot's "disabled" property
                                value = !(bool)value;
                            } else {
                                // Try editable for LineEdit/TextEdit
                                Variant test_editable = obj->get("editable");
                                if (test_editable.get_type() == Variant::BOOL) {
                                    godot_prop = "editable";
                                    // editable is not inverted (Enabled=True means editable=True)
                                }
                            }
                        }
                        // Position properties
                        else if (prop_name == "Left") {
                            Node* node = Object::cast_to<Node>(obj);
                            Control* ctrl = Object::cast_to<Control>(obj);
                            if (ctrl) {
                                Vector2 pos = ctrl->get_position();
                                pos.x = (real_t)(double)value;
                                ctrl->set_position(pos);
                                push_value(base);
                                break;
                            }
                        }
                        else if (prop_name == "Top") {
                            Control* ctrl = Object::cast_to<Control>(obj);
                            if (ctrl) {
                                Vector2 pos = ctrl->get_position();
                                pos.y = (real_t)(double)value;
                                ctrl->set_position(pos);
                                push_value(base);
                                break;
                            }
                        }
                        // Size properties
                        else if (prop_name == "Width") {
                            Control* ctrl = Object::cast_to<Control>(obj);
                            if (ctrl) {
                                Vector2 sz = ctrl->get_size();
                                sz.x = (real_t)(double)value;
                                ctrl->set_size(sz);
                                push_value(base);
                                break;
                            }
                        }
                        else if (prop_name == "Height") {
                            Control* ctrl = Object::cast_to<Control>(obj);
                            if (ctrl) {
                                Vector2 sz = ctrl->get_size();
                                sz.y = (real_t)(double)value;
                                ctrl->set_size(sz);
                                push_value(base);
                                break;
                            }
                        }
                        // Value property (for sliders, spinboxes, progress bars)
                        else if (prop_name == "Value") {
                            godot_prop = "value";
                        }
                        // ToolTipText → tooltip_text
                        else if (prop_name == "ToolTipText") {
                            godot_prop = "tooltip_text";
                        }
                        // TabStop → focus_mode (True = FOCUS_ALL=2, False = FOCUS_NONE=0)
                        else if (prop_name == "TabStop") {
                            int mode = (bool)value ? 2 : 0;  // FOCUS_ALL=2, FOCUS_NONE=0
                            obj->set("focus_mode", mode);
                            push_value(base);
                            break;
                        }
                        // Opacity → modulate.a (0–100 VB6 → 0.0–1.0)
                        else if (prop_name == "Opacity") {
                            Control *ctrl = Object::cast_to<Control>(obj);
                            if (ctrl) {
                                Color mod = ctrl->get_modulate();
                                mod.a = CLAMP((double)value / 100.0, 0.0, 1.0);
                                ctrl->set_modulate(mod);
                            }
                            push_value(base);
                            break;
                        }
                        // MousePointer → mouse_default_cursor_shape
                        else if (prop_name == "MousePointer") {
                            godot_prop = "mouse_default_cursor_shape";
                        }
                        // Locked → !editable (TextEdit/LineEdit)
                        else if (prop_name == "Locked") {
                            Variant test_ed = obj->get("editable");
                            if (test_ed.get_type() == Variant::BOOL) {
                                obj->set("editable", !(bool)value);
                            }
                            push_value(base);
                            break;
                        }
                        // MaxLength → max_length (LineEdit)
                        else if (prop_name == "MaxLength") {
                            godot_prop = "max_length";
                        }
                        // Alignment → horizontal_alignment
                        else if (prop_name == "Alignment") {
                            godot_prop = "horizontal_alignment";
                        }
                        // WordWrap → autowrap_mode (True=WORD_SMART=3, False=OFF=0)
                        else if (prop_name == "WordWrap") {
                            int mode = (bool)value ? 3 : 0;  // AUTOWRAP_WORD_SMART=3
                            obj->set("autowrap_mode", mode);
                            push_value(base);
                            break;
                        }
                        // FontSize → theme_override font size
                        else if (prop_name == "FontSize") {
                            Control *ctrl = Object::cast_to<Control>(obj);
                            if (ctrl) {
                                ctrl->add_theme_font_size_override("font_size", (int)value);
                            }
                            push_value(base);
                            break;
                        }
                        // ForeColor → theme_override font_color
                        else if (prop_name == "ForeColor") {
                            Control *ctrl = Object::cast_to<Control>(obj);
                            if (ctrl) {
                                Color c = value;
                                ctrl->add_theme_color_override("font_color", c);
                            }
                            push_value(base);
                            break;
                        }
                        // BackColor → StyleBox override bg_color
                        else if (prop_name == "BackColor") {
                            Control *ctrl = Object::cast_to<Control>(obj);
                            if (ctrl) {
                                Color c = value;
                                // Create a new StyleBoxFlat override for the "normal" stylebox
                                Ref<StyleBoxFlat> sbf;
                                Ref<StyleBox> existing = ctrl->get_theme_stylebox("normal");
                                if (existing.is_valid()) {
                                    Ref<StyleBoxFlat> existing_flat = existing;
                                    if (existing_flat.is_valid()) {
                                        sbf = existing_flat->duplicate();
                                    }
                                }
                                if (sbf.is_null()) {
                                    sbf.instantiate();
                                }
                                sbf->set_bg_color(c);
                                ctrl->add_theme_stylebox_override("normal", sbf);
                            }
                            push_value(base);
                            break;
                        }
                        
                        if (!godot_prop.is_empty()) {
                            obj->set(godot_prop, value);
                            push_value(base);
                            break;
                        }
                        
                        StringName class_name = StringName(obj->get_class());
                        MemberNameCacheEntry::AccessPreference *class_pref = resolve_class_preference(cache, class_name);
                        
                        // Optimization: Once preference is established, trust it without verification
                        // This eliminates the extra get() call that was creating Variant allocations
                        switch (*class_pref) {
                            case MemberNameCacheEntry::AccessPreference::SNAKE:
                                if (ensure_snake_case(cache)) {
                                    obj->set(cache.snake_name, value);
                                } else {
                                    obj->set(cache.primary_name, value);
                                    *class_pref = MemberNameCacheEntry::AccessPreference::PRIMARY;
                                }
                                break;
                            case MemberNameCacheEntry::AccessPreference::PRIMARY:
                                obj->set(cache.primary_name, value);
                                break;
                            default:
                                // First time: try primary, then snake if needed
                                obj->set(cache.primary_name, value);
                                Variant verify = obj->get(cache.primary_name);
                                if (verify.get_type() == Variant::NIL) {
                                    if (ensure_snake_case(cache)) {
                                        obj->set(cache.snake_name, value);
                                        *class_pref = MemberNameCacheEntry::AccessPreference::SNAKE;
                                    }
                                } else {
                                    *class_pref = MemberNameCacheEntry::AccessPreference::PRIMARY;
                                }
                                break;
                        }
                    }
                    push_value(base);
                } else {
                    push_value(base);
                }
                break;
            }
            VG_CASE(vg_op_nil, OP_NIL):
                push_value(Variant());
                break;
            VG_CASE(vg_op_true, OP_TRUE):
                push_value(true);
                break;
            VG_CASE(vg_op_false, OP_FALSE):
                push_value(false);
                break;
            VG_CASE(vg_op_abs, OP_ABS): {
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                Variant value = pop_value();
                if (value.get_type() == Variant::INT) {
                    push_value(Math::abs((int64_t)value));
                } else {
                    push_value(Math::abs(to_double(value)));
                }
                break;
            }
            VG_CASE(vg_op_sgn, OP_SGN): {
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                double v = to_double(pop_value());
                int64_t sign = (v > 0.0) - (v < 0.0);
                push_value(sign);
                break;
            }
            VG_CASE(vg_op_dict_has_key, OP_DICT_HAS_KEY): {
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                Variant key = pop_value();
                Variant dict_var = pop_value();
                bool result = false;
                if (dict_var.get_type() == Variant::DICTIONARY) {
                    const Dictionary *dict = VariantInternal::get_dictionary(&dict_var);
                    result = dict->has(key);
                }
                push_value(result);
                break;
            }
            VG_CASE(vg_op_dict_size, OP_DICT_SIZE): {
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                Variant dict_var = pop_value();
                int64_t size = 0;
                if (dict_var.get_type() == Variant::DICTIONARY) {
                    const Dictionary *dict = VariantInternal::get_dictionary(&dict_var);
                    size = dict->size();
                }
                push_value(size);
                break;
            }
            VG_CASE(vg_op_dict_clear_inplace, OP_DICT_CLEAR_INPLACE): {
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                Variant dict_var = pop_value();
                if (dict_var.get_type() == Variant::DICTIONARY) {
                    Dictionary *dict = VariantInternal::get_dictionary(&dict_var);
                    dict->clear();
                }
                push_value(dict_var);
                break;
            }
            VG_CASE(vg_op_dict_keys, OP_DICT_KEYS): {
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                Variant dict_var = pop_value();
                Array keys;
                if (dict_var.get_type() == Variant::DICTIONARY) {
                    const Dictionary *dict = VariantInternal::get_dictionary(&dict_var);
                    keys = dict->keys();
                }
                push_value(keys);
                break;
            }
            VG_CASE(vg_op_dict_values, OP_DICT_VALUES): {
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                Variant dict_var = pop_value();
                Array values;
                if (dict_var.get_type() == Variant::DICTIONARY) {
                    const Dictionary *dict = VariantInternal::get_dictionary(&dict_var);
                    values = dict->values();
                }
                push_value(values);
                break;
            }
            VG_CASE(vg_op_dict_erase, OP_DICT_ERASE): {
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                Variant key = pop_value();
                Variant dict_var = pop_value();
                if (dict_var.get_type() == Variant::DICTIONARY) {
                    Dictionary *dict = VariantInternal::get_dictionary(&dict_var);
                    dict->erase(key);
                }
                push_value(dict_var);
                break;
            }
            VG_CASE(vg_op_register_whenever, OP_REGISTER_WHENEVER): {
                // Register a Whenever section from compiled bytecode
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t data_idx = code[vm.ip++];
                Variant data_var = read_constant(data_idx);
                if (data_var.get_type() != Variant::DICTIONARY) {
                    UtilityFunctions::printerr("VisualGasic: OP_REGISTER_WHENEVER expected Dictionary");
                    success = false;
                    goto cleanup;
                }
                Dictionary section_data = data_var;
                
                WheneverSection section;
                section.section_name = String(section_data.get("section_name", ""));
                section.variable_name = String(section_data.get("variable_name", ""));
                section.comparison_operator = String(section_data.get("comparison_operator", ""));
                section.is_active = true;
                
                // Get callback procedures
                Array callbacks = section_data.get("callback_procedures", Array());
                for (int cb_i = 0; cb_i < callbacks.size(); cb_i++) {
                    section.callback_procedures.push_back(String(callbacks[cb_i]));
                }
                
                // Get comparison values if available as constants
                if (section_data.has("comparison_value")) {
                    section.comparison_value = section_data.get("comparison_value", Variant());
                } else if (section_data.has("comparison_value_ptr")) {
                    // Evaluate the expression at runtime
                    int64_t ptr = (int64_t)section_data.get("comparison_value_ptr", 0);
                    if (ptr != 0) {
                        ExpressionNode* expr = (ExpressionNode*)(uintptr_t)ptr;
                        section.comparison_value = evaluate_expression(expr);
                    }
                }
                
                if (section_data.has("comparison_value2")) {
                    section.comparison_value2 = section_data.get("comparison_value2", Variant());
                } else if (section_data.has("comparison_value2_ptr")) {
                    int64_t ptr = (int64_t)section_data.get("comparison_value2_ptr", 0);
                    if (ptr != 0) {
                        ExpressionNode* expr = (ExpressionNode*)(uintptr_t)ptr;
                        section.comparison_value2 = evaluate_expression(expr);
                    }
                }
                
                // Store condition expression pointer for runtime evaluation
                if (section_data.has("condition_expression_ptr")) {
                    int64_t ptr = (int64_t)section_data.get("condition_expression_ptr", 0);
                    section.condition_expression = (ExpressionNode*)(uintptr_t)ptr;
                }
                
                // Set scope information
                bool is_local_scope = (bool)section_data.get("is_local_scope", false);
                if (is_local_scope) {
                    section.scope_type = "local";
                    section.scope_context = String(section_data.get("scope_context", "global"));
                } else {
                    section.scope_type = "global";
                    section.scope_context = "";
                }
                
                // Initialize last_value with current variable value
                Variant current_value;
                if (get_variable(section.variable_name, current_value)) {
                    section.last_value = current_value;
                }
                
                whenever_sections.push_back(section);
                break;
            }
            VG_CASE(vg_op_suspend_whenever, OP_SUSPEND_WHENEVER): {
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t name_idx = code[vm.ip++];
                String section_name = read_constant(name_idx);
                
                for (int ws_i = 0; ws_i < whenever_sections.size(); ws_i++) {
                    if (whenever_sections[ws_i].section_name == section_name) {
                        whenever_sections.write[ws_i].is_active = false;
                        break;
                    }
                }
                break;
            }
            VG_CASE(vg_op_resume_whenever, OP_RESUME_WHENEVER): {
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t name_idx = code[vm.ip++];
                String section_name = read_constant(name_idx);
                
                for (int ws_i = 0; ws_i < whenever_sections.size(); ws_i++) {
                    if (whenever_sections[ws_i].section_name == section_name) {
                        whenever_sections.write[ws_i].is_active = true;
                        // Sync last_value to current variable value to prevent
                        // stale state from before suspension causing false triggers
                        String var_name = whenever_sections[ws_i].variable_name;
                        if (variables.has(var_name)) {
                            whenever_sections.write[ws_i].last_value = variables[var_name];
                        }
                        break;
                    }
                }
                break;
            }
            VG_CASE(vg_op_restore_data, OP_RESTORE_DATA): {
                // Reset DATA pointer based on value on stack
                // -1 means reset to start, otherwise it's a label name to restore to
                Variant restore_val = pop_value();
                if (restore_val.get_type() == Variant::INT && (int64_t)restore_val == -1) {
                    // Reset to beginning
                    data_pointer = 0;
                } else if (restore_val.get_type() == Variant::STRING) {
                    // Restore to label - labels stored lowercase in label_to_data_index
                    String key = String(restore_val).to_lower();
                    if (label_to_data_index.has(key)) {
                        data_pointer = (int)label_to_data_index[key];
                    } else {
                        // Label not found - reset to beginning
                        data_pointer = 0;
                    }
                } else {
                    // Default: reset to beginning
                    data_pointer = 0;
                }
                break;
            }
            VG_CASE(vg_op_read_data, OP_READ_DATA): {
                // Read the next value from DATA segments and push onto stack
                if (data_pointer >= data_segments.size()) {
                    raise_error("Out of Data", 5);
                    if (try_recover_error(Variant())) break;
                    success = false;
                    goto cleanup;
                } else {
                    Variant val = evaluate_expression(data_segments[data_pointer]);
                    data_pointer++;
                    push_value(val);
                }
                break;
            }
            VG_CASE(vg_op_load_data, OP_LOAD_DATA): {
                // LoadData — pop path string, load file, append to data tape
                Variant v_path = pop_value();
                String path = v_path;
                if (!FileAccess::file_exists(path)) {
                    raise_error("LoadData: File not found: " + path, 200);
                    if (try_recover_error(Variant())) break;
                    success = false;
                    goto cleanup;
                }
                {
                    Ref<FileAccess> file = FileAccess::open(path, FileAccess::READ);
                    if (file.is_null()) {
                        raise_error("LoadData: Could not open file: " + path, 201);
                        if (try_recover_error(Variant())) break;
                        success = false;
                        goto cleanup;
                    }
                    String content = file->get_as_text();
                    file->close();
                    Vector<ExpressionNode*> new_data = VisualGasicParser::parse_data_values_from_text(content);
                    for (int i = 0; i < new_data.size(); i++) {
                        data_segments.push_back(new_data[i]);
                        runtime_data_nodes.push_back(new_data[i]);
                    }
                }
                break;
            }
            VG_CASE(vg_op_data_from_string, OP_DATA_FROM_STRING): {
                // DataFromString — pop string, parse as CSV data values, append to tape
                Variant v_str = pop_value();
                String content = v_str;
                Vector<ExpressionNode*> new_data = VisualGasicParser::parse_data_values_from_text(content);
                for (int i = 0; i < new_data.size(); i++) {
                    data_segments.push_back(new_data[i]);
                    runtime_data_nodes.push_back(new_data[i]);
                }
                break;
            }
            VG_CASE(vg_op_clear_data, OP_CLEAR_DATA): {
                clear_data_tape();
                break;
            }
            VG_CASE(vg_op_coerce_type, OP_COERCE_TYPE): {
                uint8_t type_idx = code[vm.ip++];
                String type_name = chunk->constants[type_idx];
                Variant val = pop_value();
                push_value(coerce_to_type(val, type_name));
                break;
            }
            VG_CASE(vg_op_on_error_resume_next, OP_ON_ERROR_RESUME_NEXT): {
                // Enable On Error Resume Next mode
                error_state.mode = ErrorState::RESUME_NEXT;
                break;
            }
            VG_CASE(vg_op_on_error_goto, OP_ON_ERROR_GOTO): {
                // Set On Error Goto label
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t label_idx = code[vm.ip++];
                String label_name = read_constant(label_idx);
                error_state.mode = ErrorState::GOTO_LABEL;
                error_state.label = label_name;
                break;
            }
            VG_CASE(vg_op_on_error_goto_0, OP_ON_ERROR_GOTO_0): {
                // Disable error handling (On Error Goto 0)
                error_state.mode = ErrorState::NONE;
                error_state.label = "";
                break;
            }
            VG_CASE(vg_op_debug_line, OP_DEBUG_LINE): {
                // Read the line number (16-bit)
                if (vm.ip + 1 >= code_size) { success = false; goto cleanup; }
                uint8_t line_lo = code[vm.ip++];
                uint8_t line_hi = code[vm.ip++];

                // Parallel workers: skip ALL debug/debugger logic.
                // The debug stack, EngineDebugger, debug_state, and
                // VisualGasicLanguage singletons are NOT thread-safe.
                if (is_parallel_worker) {
                    break;
                }

                int line_number = (line_hi << 8) | line_lo;
                
                // Update debug state
                debug_state.current_line = line_number;
                String script_path;
                if (script.is_valid()) {
                    script_path = script->get_path();
                    debug_state.current_file = script_path;
                }
                
                // Update the current stack frame line for Godot debugger
                VisualGasicLanguage::update_stack_frame_line(line_number);
                
                // Check for step debugging using both our custom step mode AND Godot's built-in stepping
                EngineDebugger* engine_debugger = EngineDebugger::get_singleton();
                bool should_break = false;
                
                // First check Godot's built-in stepping mechanism (set by debugger panel buttons)
                if (engine_debugger && engine_debugger->is_active()) {
                    int lines_left = engine_debugger->get_lines_left();
                    int godot_depth = engine_debugger->get_depth();
                    int current_depth = VisualGasicLanguage::get_current_stack_depth();
                    
                    // Godot's stepping:
                    // - Step Into: lines_left = 1, depth = -1 (break on any next line)
                    // - Step Over: lines_left = 1, depth = current (break at same or shallower depth)
                    // - Step Out: lines_left = 0, depth = current-1 (break when returning to parent)
                    if (lines_left > 0) {
                        if (godot_depth < 0 || current_depth <= godot_depth) {
                            should_break = true;
                            // Decrement lines_left to consume this step
                            engine_debugger->set_lines_left(lines_left - 1);
                        }
                    } else if (godot_depth >= 0 && current_depth <= godot_depth) {
                        // Step out mode: break when returning to shallower depth
                        should_break = true;
                    }
                }
                
                // Also check our custom step mode (for file-based debugging fallback)
                VGStepMode current_step_mode = VisualGasicLanguage::get_step_mode();
                if (current_step_mode != VG_STEP_NONE && engine_debugger && engine_debugger->is_active()) {
                    int current_depth = VisualGasicLanguage::get_current_stack_depth();
                    int target_depth = VisualGasicLanguage::get_step_target_depth();
                    
                    switch (current_step_mode) {
                        case VG_STEP_INTO:
                            // Always break on next line
                            should_break = true;
                            break;
                        case VG_STEP_OVER:
                            // Break if at same or shallower depth
                            should_break = (current_depth <= target_depth);
                            break;
                        case VG_STEP_OUT:
                            // Break if at shallower depth (returned from function)
                            should_break = (current_depth <= target_depth);
                            break;
                        default:
                            break;
                    }
                    
                    if (should_break) {
                        // Clear step mode before breaking
                        VisualGasicLanguage::set_step_mode(VG_STEP_NONE);
                        
                        // Send break notification directly to editor via EngineDebugger
                        Array break_data;
                        break_data.push_back(script_path);
                        break_data.push_back(line_number);
                        engine_debugger->send_message("visualgasic:break_hit", break_data);
                        
                        // Send current variables and call stack for inspection
                        _send_variables_to_debugger(engine_debugger);
                        _send_call_stack_to_debugger(engine_debugger);
                        
                        // Poll to ensure messages are sent before blocking
                        engine_debugger->line_poll();
                        
                        // Use Godot's built-in script_debug() for proper pause/resume
                        // This integrates with Godot's debugger panel (Continue, Step buttons)
                        VisualGasicLanguage* lang = VisualGasicLanguage::get_singleton();
                        if (lang) {
                            engine_debugger->script_debug(lang, true, false);
                        }
                    }
                }
                
                // Check for breakpoints using Godot's EngineDebugger
                if (!should_break && engine_debugger && engine_debugger->is_active() && !script_path.is_empty()) {
                    // First check Godot's built-in breakpoint system
                    bool godot_bp = engine_debugger->is_breakpoint(line_number, StringName(script_path));
                    bool has_bp = godot_bp;
                    
                    // Also check our C++ breakpoint storage (loaded from JSON file)
                    if (!has_bp) {
                        has_bp = VisualGasicLanguage::has_breakpoint(script_path, line_number);
                    }
                    
                    if (has_bp) {
                        // Store breakpoint location before blocking (for editor query)
                        VisualGasicLanguage::set_current_break_location(script_path, line_number);
                        
                        // Send break notification directly to editor via EngineDebugger
                        Array break_data;
                        break_data.push_back(script_path);
                        break_data.push_back(line_number);
                        engine_debugger->send_message("visualgasic:break_hit", break_data);
                        
                        // Send current variables and call stack for inspection
                        _send_variables_to_debugger(engine_debugger);
                        _send_call_stack_to_debugger(engine_debugger);
                        
                        // Poll to ensure messages are sent before blocking
                        engine_debugger->line_poll();
                        
                        // Use Godot's built-in script_debug() for proper pause/resume
                        // This integrates with Godot's debugger panel (Continue, Step buttons)
                        VisualGasicLanguage* lang = VisualGasicLanguage::get_singleton();
                        if (lang) {
                            engine_debugger->script_debug(lang, true, false);
                        }
                    }
                }
                
                // Also check our internal debugger for conditional breakpoints
                VisualGasicDebugger* debugger = VisualGasicDebuggerGlobal::get_global_debugger();
                if (debugger && engine_debugger && engine_debugger->is_active() && !script_path.is_empty()) {
                    Dictionary context;
                    context["variables"] = variables;
                    if (current_sub) {
                        context["function"] = current_sub->name;
                    }
                    
                    if (debugger->should_break_at(script_path, line_number, context)) {
                        debug_state.debug_paused = true;
                        UtilityFunctions::print_rich("[color=cyan][VG Debug] Conditional breakpoint at ", 
                            script_path, ":", line_number, "[/color]");
                        
                        if (current_sub) {
                            debugger->record_execution_frame(
                                current_sub->name,
                                script_path,
                                line_number,
                                variables
                            );
                        }
                        
                        // Send enhanced break data with reason
                        Array cond_break_data;
                        cond_break_data.push_back(script_path);
                        cond_break_data.push_back(line_number);
                        engine_debugger->send_message("visualgasic:break_hit", cond_break_data);
                        
                        _send_variables_to_debugger(engine_debugger);
                        _send_call_stack_to_debugger(engine_debugger);
                        engine_debugger->line_poll();
                        
                        // Use Godot's script_debug() for proper pause/resume
                        VisualGasicLanguage* lang = VisualGasicLanguage::get_singleton();
                        if (lang) {
                            engine_debugger->script_debug(lang, true, false);
                        }
                    }
                }
                
                // ── v3.2: Data Breakpoints (Watchpoints) ──
                // Check if any watched variables changed value since last debug line.
                if (!should_break && engine_debugger && engine_debugger->is_active() && !script_path.is_empty()) {
                    Array wp_list = VisualGasicLanguage::get_watchpoints();
                    for (int wi = 0; wi < wp_list.size(); wi++) {
                        Dictionary wp_info = wp_list[wi];
                        String wp_name = wp_info["name"];
                        if (variables.has(wp_name)) {
                            Variant current_val = variables[wp_name];
                            if (VisualGasicLanguage::check_watchpoint(wp_name, current_val)) {
                                // Value changed — break!
                                VisualGasicLanguage::set_current_break_location(script_path, line_number);
                                
                                // Send watchpoint hit notification with old/new values
                                Array wp_break_data;
                                wp_break_data.push_back(script_path);
                                wp_break_data.push_back(line_number);
                                engine_debugger->send_message("visualgasic:break_hit", wp_break_data);
                                
                                // Send watchpoint-specific info
                                Dictionary wp_hit;
                                wp_hit["variable"] = wp_name;
                                wp_hit["new_value"] = current_val;
                                wp_hit["reason"] = "watchpoint";
                                Array wp_hit_data;
                                wp_hit_data.push_back(wp_hit);
                                engine_debugger->send_message("visualgasic:watchpoint_hit", wp_hit_data);
                                
                                _send_variables_to_debugger(engine_debugger);
                                _send_call_stack_to_debugger(engine_debugger);
                                engine_debugger->line_poll();
                                
                                VisualGasicLanguage* lang = VisualGasicLanguage::get_singleton();
                                if (lang) {
                                    engine_debugger->script_debug(lang, true, false);
                                }
                                break;  // Only break once per debug line
                            }
                        }
                    }
                }
                
                // Check for pause request (Break/Pause button) in bytecode path
                if (!should_break && engine_debugger && engine_debugger->is_active() && !script_path.is_empty()
                    && VisualGasicLanguage::is_break_requested()) {
                    VisualGasicLanguage::clear_break_request();
                    
                    VisualGasicLanguage::set_current_break_location(script_path, line_number);
                    
                    Array break_data;
                    break_data.push_back(script_path);
                    break_data.push_back(line_number);
                    engine_debugger->send_message("visualgasic:break_hit", break_data);
                    
                    _send_variables_to_debugger(engine_debugger);
                    _send_call_stack_to_debugger(engine_debugger);
                    engine_debugger->line_poll();
                    
                    VisualGasicLanguage* lang = VisualGasicLanguage::get_singleton();
                    if (lang) {
                        engine_debugger->script_debug(lang, true, false);
                    }
                }
                break;
            }
            VG_CASE(vg_op_stop, OP_STOP): {
                // VB6 Stop statement: pause execution like a breakpoint
                EngineDebugger* stop_debugger = EngineDebugger::get_singleton();
                if (stop_debugger && stop_debugger->is_active()) {
                    String stop_path;
                    if (script.is_valid()) {
                        stop_path = script->get_path();
                    }
                    int stop_line = debug_state.current_line;
                    VisualGasicLanguage::set_current_break_location(stop_path, stop_line);
                    Array break_data;
                    break_data.push_back(stop_path);
                    break_data.push_back(stop_line);
                    stop_debugger->send_message("visualgasic:break_hit", break_data);
                    _send_variables_to_debugger(stop_debugger);
                    _send_call_stack_to_debugger(stop_debugger);
                    stop_debugger->line_poll();
                    VisualGasicLanguage* lang = VisualGasicLanguage::get_singleton();
                    if (lang) {
                        stop_debugger->script_debug(lang, true, false);
                    }
                } else {
                    UtilityFunctions::print("[VG] Stop statement hit (no debugger attached)");
                }
                break;
            }
            VG_CASE(vg_op_is_class, OP_IS_CLASS): {
                // Type-check: pop class-name (String) and object, push bool
                // Implements VB6 "obj Is ClassName" pattern
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                Variant class_v = pop_value(); // class name (String)
                Variant obj_v   = pop_value(); // object
                bool result = false;
                if (obj_v.get_type() == Variant::OBJECT && class_v.get_type() == Variant::STRING) {
                    Object* obj = Object::cast_to<Object>(obj_v);
                    if (obj) result = obj->is_class(String(class_v));
                }
                push_value(result);
                VG_BREAK;
            }
            VG_CASE(vg_op_method_call, OP_METHOD_CALL): {
                // Object method call: base_object.Method(args...)
                // Stack layout (top→bottom): argN, ..., arg1, base_object
                // Operands: [METHOD_NAME_IDX] [ARG_COUNT]
                if (vm.ip + 1 >= code_size) { success = false; goto cleanup; }
                uint8_t name_idx = code[vm.ip++];
                uint8_t arg_count = code[vm.ip++];
                if (!ensure_stack(arg_count + 1)) { success = false; goto cleanup; }

                // Pop arguments (reverse order)
                Array args;
                args.resize(arg_count);
                for (int i = arg_count - 1; i >= 0; i--) {
                    args[i] = pop_value();
                }
                // Pop the base object
                Variant base = pop_value();
                String method = read_constant(name_idx);

                Variant call_ret;
                bool handled = false;

                // --- Check builtin-for-base-variable dispatchers ---
                {
                    Variant br;
                    if (VisualGasicBuiltins::call_builtin_for_base_variant(this, base, method, args, br)) {
                        call_ret = br;
                        handled = true;
                    }
                }

                // --- VG class instance method call (object ID stored as int) ---
                if (!handled && base.get_type() == Variant::INT) {
                    int obj_id = (int)base;
                    if (object_instances.has(obj_id)) {
                        call_ret = call_object_method(obj_id, method, args);
                        handled = true;
                    }
                }

                // --- Godot Object method call ---
                if (!handled && base.get_type() == Variant::OBJECT) {
                    Object* obj = Object::cast_to<Object>(base);
                    if (obj) {
                        if (obj->has_method(method)) {
                            call_ret = obj->callv(method, args);
                            handled = true;
                        } else {
                            String snake = method.to_snake_case();
                            if (obj->has_method(snake)) {
                                call_ret = obj->callv(snake, args);
                                handled = true;
                            }
                        }
                    }
                }

                // --- Variant method call (structs like Vector2, Rect2, etc.) ---
                if (!handled && base.get_type() != Variant::OBJECT && base.get_type() != Variant::NIL) {
                    String method_to_call;
                    if (base.has_method(method)) {
                        method_to_call = method;
                    } else {
                        String snake = method.to_snake_case();
                        if (base.has_method(snake)) {
                            method_to_call = snake;
                        }
                    }
                    if (!method_to_call.is_empty()) {
                        GDExtensionCallError err;
                        Variant res;
                        Vector<Variant> args_store;
                        args_store.resize(args.size());
                        Variant *args_w = args_store.ptrw();
                        Vector<const Variant*> arg_ptrs;
                        arg_ptrs.resize(args.size());
                        const Variant **ptrs_w = arg_ptrs.ptrw();
                        for (int i = 0; i < args.size(); i++) {
                            args_w[i] = args[i];
                            ptrs_w[i] = &args_w[i];
                        }
                        base.callp(method_to_call, ptrs_w, args.size(), res, err);
                        call_ret = res;
                        handled = true;
                    }
                }

                if (!handled) {
                    // Method call on Null / Nothing — raise error
                    if (base.get_type() == Variant::NIL) {
                        raise_error("Method call on Null object: ." + method, 91);
                        if (try_recover_error(Variant())) { VG_BREAK; }
                        success = false;
                        goto cleanup;
                    }
                    // Last resort: call_internal with the method name
                    // (some builtins might only exist in the statement path)
                    bool stmt_found = false;
                    dispatch_builtin_call(method, args, stmt_found);
                    call_ret = Variant();
                }

                push_value(call_ret);
                VG_BREAK;
            }
            VG_CASE(vg_op_iter_array, OP_ITER_ARRAY): {
                // Push arr[idx] for For Each loop body (currently unused —
                // For Each uses OP_GET_ARRAY instead, but reserved for future
                // optimization with fused iteration).
                if (vm.ip + 1 >= code_size) { success = false; goto cleanup; }
                uint8_t arr_slot = code[vm.ip++];
                uint8_t idx_slot = code[vm.ip++];
                if (arr_slot >= locals.size() || idx_slot >= locals.size()) {
                    success = false; goto cleanup;
                }
                Variant &arr_v = locals.write[arr_slot];
                int64_t idx = (int64_t)locals[idx_slot];
                if (arr_v.get_type() == Variant::ARRAY) {
                    Array a = arr_v;
                    if (idx >= 0 && idx < a.size()) {
                        push_value(a[idx]);
                    } else {
                        push_value(Variant());
                    }
                } else {
                    push_value(Variant());
                }
                VG_BREAK;
            }
            VG_CASE(vg_op_dict_keys_call, OP_DICT_KEYS_CALL): {
                // If TOS is a Dictionary, replace it with its keys() array.
                // If it's already an Array, leave it as-is.
                // This supports For Each on both Arrays and Dictionaries.
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                Variant &top = vm.stack.back();
                if (top.get_type() == Variant::DICTIONARY) {
                    Dictionary dict = top;
                    if (!dict.is_empty()) {
                        top = dict.keys();
                    } else {
                        // Empty Dictionary placeholder — check VGDict pool.
                        // The For Each collection was likely loaded from a local slot
                        // that uses sole-owner VGDict optimization. Reconstruct keys.
                        Array keys;
                        // Scan backward in bytecode for the source local slot
                        // Pattern: OP_GET_LOCAL(1) slot(1) | OP_DICT_KEYS_CALL(1)
                        // vm.ip currently points past OP_DICT_KEYS_CALL:
                        //   vm.ip - 1 = OP_DICT_KEYS_CALL
                        //   vm.ip - 2 = slot byte
                        //   vm.ip - 3 = OP_GET_LOCAL
                        int dkc_pos = (int)vm.ip - 1;
                        if (dkc_pos >= 2 && code[dkc_pos - 2] == OP_GET_LOCAL) {
                            uint8_t slot = code[dkc_pos - 1];
                            if (slot < VGDICT_POOL_MAX && vgdict_slot_active[slot]) {
                                keys = vgdict_pool[slot].keys();
                            }
                        }
                        if (keys.size() > 0) {
                            top = keys;
                        } else {
                            top = dict.keys(); // empty array
                        }
                    }
                }
                // If it's an Array (or anything else), leave unchanged.
                VG_BREAK;
            }
            VG_CASE(vg_op_push_with, OP_PUSH_WITH): {
                // Pop TOS and push onto the With context stack.
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                Variant val = pop_value();
                // Handle VGDict sole-owner optimization: if the value is an
                // empty Dictionary placeholder, check if it came from a VGDict slot
                // and materialize the real dictionary.
                if (val.get_type() == Variant::DICTIONARY) {
                    Dictionary d = val;
                    if (d.is_empty()) {
                        // Check preceding bytecode for OP_GET_LOCAL pattern
                        int pw_pos = (int)vm.ip - 1; // OP_PUSH_WITH position
                        if (pw_pos >= 2 && code[pw_pos - 2] == OP_GET_LOCAL) {
                            uint8_t slot = code[pw_pos - 1];
                            if (slot < VGDICT_POOL_MAX && vgdict_slot_active[slot]) {
                                val = vgdict_pool[slot].to_godot_dict();
                            }
                        }
                    }
                }
                with_stack.push_back(val);
                VG_BREAK;
            }
            VG_CASE(vg_op_pop_with, OP_POP_WITH): {
                // Pop the With context stack.
                if (!with_stack.is_empty()) {
                    with_stack.remove_at(with_stack.size() - 1);
                }
                VG_BREAK;
            }
            VG_CASE(vg_op_get_with, OP_GET_WITH): {
                // Push the current With context object onto the value stack.
                if (with_stack.is_empty()) {
                    UtilityFunctions::printerr("VisualGasic: OP_GET_WITH outside With block");
                    push_value(Variant());
                } else {
                    push_value(with_stack[with_stack.size() - 1]);
                }
                VG_BREAK;
            }
            VG_CASE(vg_op_setup_try, OP_SETUP_TRY): {
                // Set up an exception handler: [OP] [OFFSET_16]
                // v3.2: Push onto handler stack (supports nested Try/Catch).
                if (vm.ip + 1 >= code_size) { success = false; goto cleanup; }
                uint8_t hi = code[vm.ip++];
                uint8_t lo = code[vm.ip++];
                int offset = (hi << 8) | lo;
                int catch_ip = (int)vm.ip + offset;
                
                TryHandler handler;
                handler.catch_ip = catch_ip;
                handler.stack_depth = (int)vm.stack.size();
                try_handler_stack.push_back(handler);
                error_state.has_error = false;
                VG_BREAK;
            }
            VG_CASE(vg_op_pop_try, OP_POP_TRY): {
                // No error in try block — pop the handler.
                if (!try_handler_stack.is_empty()) {
                    try_handler_stack.resize(try_handler_stack.size() - 1);
                }
                VG_BREAK;
            }
            VG_CASE(vg_op_throw, OP_THROW): {
                // Throw an exception: stack has [error_code, message]
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                Variant msg_v = pop_value();
                Variant code_v = pop_value();
                String msg = (String)msg_v;
                int err_code = (int)code_v;
                
                // Always update the Err object (VB6 Err.Raise contract)
                raise_error(msg, err_code);
                
                // v3.2: Use centralized error recovery (try/catch, On Error, etc.)
                if (!try_recover_error(Variant(), false)) {
                    UtilityFunctions::printerr("VisualGasic: Unhandled exception: ", msg, " (code ", err_code, ")");
                    success = false;
                    goto cleanup;
                }
                VG_BREAK;
            }

            // ── v2.10.0: File I/O Opcodes ──
            VG_CASE(vg_op_open_file, OP_OPEN_FILE): {
                uint8_t mode = code[vm.ip++];
                int file_num = (int)pop_value();
                String path = pop_value();
                if (open_files.has(file_num)) {
                    raise_error(String("File already open: ") + String::num(file_num), 55);
                    if (!try_recover_error(Variant(), false)) {
                        // In NONE mode, keep VB6 behavior: error printed, continue
                    }
                } else {
                    Ref<FileAccess> fa;
                    if (mode == 0) fa = FileAccess::open(path, FileAccess::READ);
                    else if (mode == 1) fa = FileAccess::open(path, FileAccess::WRITE);
                    else if (mode == 2) {
                        if (FileAccess::file_exists(path)) {
                            fa = FileAccess::open(path, FileAccess::READ_WRITE);
                            if (fa.is_valid()) fa->seek_end();
                        } else {
                            fa = FileAccess::open(path, FileAccess::WRITE);
                        }
                    }
                    if (fa.is_null()) {
                        raise_error(String("Failed to open file: ") + path, 53);
                        if (!try_recover_error(Variant(), false)) {
                            // In NONE mode, keep VB6 behavior: error printed, continue
                        }
                    } else {
                        open_files[file_num] = fa;
                    }
                }
                VG_BREAK;
            }
            VG_CASE(vg_op_close_file, OP_CLOSE_FILE): {
                int file_num = (int)pop_value();
                if (file_num == 0) {
                    open_files.clear();
                } else if (open_files.has(file_num)) {
                    open_files.erase(file_num);
                }
                VG_BREAK;
            }
            VG_CASE(vg_op_print_file, OP_PRINT_FILE): {
                uint8_t arg_count = code[vm.ip++];
                // Pop args in reverse (they were pushed left-to-right)
                Vector<Variant> args;
                args.resize(arg_count);
                for (int i = arg_count - 1; i >= 0; i--) args.write[i] = pop_value();
                int file_num = (int)pop_value();
                if (open_files.has(file_num)) {
                    Ref<FileAccess> fa = open_files[file_num];
                    String line;
                    for (int i = 0; i < args.size(); i++) {
                        if (i > 0) line += " ";
                        line += String(args[i]);
                    }
                    fa->store_line(line);
                } else {
                    raise_error(String("Bad file number: ") + String::num(file_num), 52);
                    if (!try_recover_error(Variant(), false)) {
                        // NONE mode: error printed, continue
                    }
                }
                VG_BREAK;
            }
            VG_CASE(vg_op_write_file, OP_WRITE_FILE): {
                uint8_t arg_count = code[vm.ip++];
                Vector<Variant> args;
                args.resize(arg_count);
                for (int i = arg_count - 1; i >= 0; i--) args.write[i] = pop_value();
                int file_num = (int)pop_value();
                if (open_files.has(file_num)) {
                    Ref<FileAccess> fa = open_files[file_num];
                    String line;
                    for (int i = 0; i < args.size(); i++) {
                        if (i > 0) line += ",";
                        Variant v = args[i];
                        if (v.get_type() == Variant::STRING) {
                            line += String("\"") + String(v) + String("\"");
                        } else {
                            line += String(v);
                        }
                    }
                    fa->store_line(line);
                } else {
                    raise_error(String("Bad file number: ") + String::num(file_num), 52);
                    if (!try_recover_error(Variant(), false)) {
                        // NONE mode: error printed, continue
                    }
                }
                VG_BREAK;
            }
            VG_CASE(vg_op_input_file, OP_INPUT_FILE): {
                uint8_t var_idx = code[vm.ip++];
                String var_name = read_constant(var_idx);
                int file_num = (int)pop_value();
                if (open_files.has(file_num)) {
                    Ref<FileAccess> fa = open_files[file_num];
                    PackedStringArray csv = fa->get_csv_line();
                    if (csv.size() > 0) {
                        variables[var_name] = csv[0];
                    }
                } else {
                    raise_error(String("Bad file number: ") + String::num(file_num), 52);
                    if (!try_recover_error(Variant(), false)) {
                        // NONE mode: error printed, continue
                    }
                }
                VG_BREAK;
            }
            VG_CASE(vg_op_line_input, OP_LINE_INPUT): {
                uint8_t var_idx = code[vm.ip++];
                String var_name = read_constant(var_idx);
                int file_num = (int)pop_value();
                if (open_files.has(file_num)) {
                    Ref<FileAccess> fa = open_files[file_num];
                    String line = fa->get_line();
                    variables[var_name] = line;
                } else {
                    raise_error(String("Bad file number: ") + String::num(file_num), 52);
                    if (!try_recover_error(Variant(), false)) {
                        // NONE mode: error printed, continue
                    }
                }
                VG_BREAK;
            }

            // ── v2.10.0: GoSub / Return ──
            VG_CASE(vg_op_gosub, OP_GOSUB): {
                // Read 16-bit offset (like OP_JUMP)
                uint8_t hi = code[vm.ip++];
                uint8_t lo = code[vm.ip++];
                int target = (hi << 8) | lo;
                // Push return address
                gosub_return_stack.push_back(vm.ip);
                vm.ip = target;
                VG_BREAK;
            }
            VG_CASE(vg_op_return_gosub, OP_RETURN_GOSUB): {
                if (gosub_return_stack.size() > 0) {
                    vm.ip = gosub_return_stack[gosub_return_stack.size() - 1];
                    gosub_return_stack.resize(gosub_return_stack.size() - 1);
                } else {
                    // No GoSub context — treat as normal return (exit sub/function)
                    r_ret = Variant();
                    success = true;
                    goto cleanup;
                }
                VG_BREAK;
            }

            // Threading (v2.11.0)
            VG_CASE(vg_op_lock, OP_LOCK): {
                instance_mutex_.lock();
                VG_BREAK;
            }
            VG_CASE(vg_op_unlock, OP_UNLOCK): {
                instance_mutex_.unlock();
                VG_BREAK;
            }

            // Bytecode Parallel For (v2.11.0 Phase 4)
            VG_CASE(vg_op_parallel_for_begin, OP_PARALLEL_FOR_BEGIN): {
                // Layout: OP_PARALLEL_FOR_BEGIN [var_slot] [body_len_hi] [body_len_lo]
                // Stack (TOS first): step, end, start
                if (vm.ip + 2 >= code_size) { success = false; goto cleanup; }
                int var_slot = code[vm.ip++];
                int body_len = (code[vm.ip] << 8) | code[vm.ip + 1];
                vm.ip += 2;

                Variant v_step  = pop_value();
                Variant v_end   = pop_value();
                Variant v_start = pop_value();

                int64_t start_val = to_int(v_start);
                int64_t end_val   = to_int(v_end);
                int64_t step_val  = to_int(v_step);
                if (step_val == 0) step_val = 1;

                int body_start_ip = vm.ip;
                int body_end_ip   = vm.ip + body_len;

                // Build iteration indices.
                std::vector<int64_t> indices;
                for (int64_t i = start_val;
                     (step_val > 0 ? i <= end_val : i >= end_val);
                     i += step_val) {
                    indices.push_back(i);
                }
                int iter_count = (int)indices.size();

                if (iter_count <= 0) {
                    // No iterations — skip body.
                    vm.ip = body_end_ip;
                    VG_BREAK;
                }

                // Before dispatching body iterations, flush current locals
                // to variables[] so that the body (which uses var_sync) can
                // see the parent scope.
                for (int li = 0; li < locals.size() && li < chunk->local_names.size(); li++) {
                    const String &lname = chunk->local_names[li];
                    if (!lname.is_empty()) {
                        variables[lname] = locals[li];
                    }
                }

                // --- Serial fallback for small loops (thread overhead > benefit) ---
                if (iter_count <= 32) {
                    bool saved_vs = needs_var_sync;
                    needs_var_sync = true;
                    for (int idx = 0; idx < iter_count; idx++) {
                        if (var_slot >= 0 && var_slot < chunk->local_names.size()) {
                            String vn = chunk->local_names[var_slot];
                            if (!vn.is_empty()) {
                                variables[vn] = Variant(indices[idx]);
                            }
                        }
                        Variant body_ret;
                        execute_bytecode(chunk, func, body_ret,
                                         body_start_ip, body_end_ip,
                                         nullptr);
                    }
                    needs_var_sync = saved_vs;

                    // Refresh parent locals from variables[] so subsequent
                    // OP_GET_LOCAL picks up body changes (e.g. total).
                    for (int li = 0; li < locals.size() && li < chunk->local_names.size(); li++) {
                        const String &lname = chunk->local_names[li];
                        if (!lname.is_empty() && variables.has(lname)) {
                            locals.write[li] = variables[lname];
                        }
                    }
                    vm.ip = body_end_ip;
                    VG_BREAK;
                }

                // --- Parallel execution via WorkerThreadPool ---
                {
                    // Force locked (serialised) path for ALL parallel workers.
                    // The lock-free path (per-worker isolated locals) requires
                    // a truly thread-safe execution environment, but
                    // execute_bytecode() accesses shared instance state (debug
                    // stack, debug_state, vgdict_pool, EngineDebugger, etc.)
                    // that is NOT thread-safe.  Until a lightweight worker-only
                    // interpreter is implemented, serialise through the mutex
                    // to guarantee correctness.
                    //
                    // Performance is still improved over the original because:
                    //  - No per-iteration deep Dictionary clone
                    //  - Thread-local VM state avoids stack conflicts
                    //  - Serial threshold (≤32) avoids pool overhead for small loops
                    bool body_has_lock = true;

                    PForBytecodeData pf_data;
                    pf_data.instance      = this;
                    pf_data.chunk         = chunk;
                    pf_data.func          = func;
                    pf_data.body_start_ip = body_start_ip;
                    pf_data.body_end_ip   = body_end_ip;
                    pf_data.var_slot      = var_slot;
                    pf_data.needs_lock    = body_has_lock;
                    pf_data.indices.assign(indices.begin(), indices.end());
                    pf_data.parent_locals = locals;  // snapshot for lock-free workers

                    WorkerThreadPool* pool = WorkerThreadPool::get_singleton();
                    int64_t group_id = pool->add_native_group_task(
                        &VisualGasicInstance::_pfor_bytecode_worker,
                        &pf_data,
                        iter_count,
                        -1,    // tasks_needed = auto
                        false  // not high priority
                    );
                    pool->wait_for_group_task_completion(group_id);
                }

                // Refresh parent locals from variables[] after parallel body.
                for (int li = 0; li < locals.size() && li < chunk->local_names.size(); li++) {
                    const String &lname = chunk->local_names[li];
                    if (!lname.is_empty() && variables.has(lname)) {
                        locals.write[li] = variables[lname];
                    }
                }

                vm.ip = body_end_ip;
                VG_BREAK;
            }

            VG_CASE(vg_op_parallel_for_end, OP_PARALLEL_FOR_END): {
                // Workers reach this opcode at the end of the parallel body.
                // The main thread should never execute it (it skips past via
                // vm.ip = body_end_ip above).  Treat as clean exit for safety.
                success = true;
                goto cleanup;
            }

            // Task.Run bytecode (v2.11.0 Phase 5)
            VG_CASE(vg_op_task_run_begin, OP_TASK_RUN_BEGIN): {
                // Layout: OP_TASK_RUN_BEGIN [name_const] [bg_flag] [body_len_hi] [body_len_lo]
                if (vm.ip + 3 >= code_size) { success = false; goto cleanup; }
                uint8_t name_idx = code[vm.ip++];
                uint8_t bg_flag  = code[vm.ip++];
                int body_len = (code[vm.ip] << 8) | code[vm.ip + 1];
                vm.ip += 2;

                String task_name = (name_idx < chunk->constants.size())
                    ? String(chunk->constants[name_idx])
                    : String("Task_") + String::num_int64(active_tasks.size());
                bool is_background = (bg_flag != 0);

                int body_start_ip = vm.ip;
                int body_end_ip   = vm.ip + body_len;

                // Flush locals to variables[] so the worker body can see them.
                for (int li = 0; li < locals.size() && li < chunk->local_names.size(); li++) {
                    const String &lname = chunk->local_names[li];
                    if (!lname.is_empty()) {
                        variables[lname] = locals[li];
                    }
                }

                // Allocate worker data (freed after wait/completion).
                TaskRunBCData* data = new TaskRunBCData();
                data->instance      = this;
                data->chunk         = chunk;
                data->func          = func;
                data->body_start_ip = body_start_ip;
                data->body_end_ip   = body_end_ip;
                data->task_name     = task_name;
                data->task_idx      = active_tasks.size();

                TaskInfo task_info;
                task_info.task_name = task_name;
                task_info.is_background = is_background;
                task_info.is_completed = false;

                WorkerThreadPool* pool = WorkerThreadPool::get_singleton();
                int64_t pool_task_id = pool->add_native_task(
                    &VisualGasicInstance::_task_run_bc_worker, data);
                task_info.task_id = pool_task_id;
                active_tasks.push_back(task_info);

                // In the bytecode path ALL tasks wait immediately because
                // VMState (vm.ip, vm.stack) is per-instance, not per-thread.
                // A background worker calling execute_bytecode would race
                // with the main thread's VM state.  True background execution
                // will be available when VMState is made per-call (future).
                pool->wait_for_task_completion(pool_task_id);
                active_tasks.write[data->task_idx].is_completed = true;
                // Refresh locals from variables[] after task completes.
                for (int li = 0; li < locals.size() && li < chunk->local_names.size(); li++) {
                    const String &lname = chunk->local_names[li];
                    if (!lname.is_empty() && variables.has(lname)) {
                        locals.write[li] = variables[lname];
                    }
                }
                delete data;

                vm.ip = body_end_ip;
                VG_BREAK;
            }

            VG_CASE(vg_op_task_run_end, OP_TASK_RUN_END): {
                // Workers reach this at the end of a task body.
                success = true;
                goto cleanup;
            }

            VG_CASE(vg_op_task_wait, OP_TASK_WAIT): {
                // Layout: OP_TASK_WAIT [wait_all_flag]
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t wait_all_flag = code[vm.ip++];

                WorkerThreadPool* pool = WorkerThreadPool::get_singleton();

                if (wait_all_flag) {
                    // Wait for ALL active tasks.
                    for (int ti = 0; ti < active_tasks.size(); ti++) {
                        if (!active_tasks[ti].is_completed && active_tasks[ti].task_id >= 0) {
                            pool->wait_for_task_completion(active_tasks[ti].task_id);
                            active_tasks.write[ti].is_completed = true;
                        }
                    }
                } else {
                    // Wait for ANY active task.
                    bool found = false;
                    while (!found) {
                        for (int ti = 0; ti < active_tasks.size(); ti++) {
                            if (!active_tasks[ti].is_completed && active_tasks[ti].task_id >= 0) {
                                if (pool->is_task_completed(active_tasks[ti].task_id)) {
                                    active_tasks.write[ti].is_completed = true;
                                    found = true;
                                    break;
                                }
                            }
                        }
                        if (!found) {
                            OS::get_singleton()->delay_usec(100);
                        }
                    }
                }

                // Refresh locals from variables[] after wait.
                for (int li = 0; li < locals.size() && li < chunk->local_names.size(); li++) {
                    const String &lname = chunk->local_names[li];
                    if (!lname.is_empty() && variables.has(lname)) {
                        locals.write[li] = variables[lname];
                    }
                }
                VG_BREAK;
            }

            // Await (v2.11.0 Phase 5) — placeholder for future coroutine dispatch.
            VG_CASE(vg_op_await, OP_AWAIT): {
                // Currently a no-op: the awaited expression was already evaluated
                // synchronously.  This opcode establishes the infrastructure for
                // future async dispatch (e.g. OP_ASYNC_CALL → future handle).
                VG_BREAK;
            }

            // RaiseEvent (v3.5.0) — emit a Godot signal on the owner object.
            VG_CASE(vg_op_raise_event, OP_RAISE_EVENT): {
                if (vm.ip + 1 >= code_size) { success = false; goto cleanup; }
                uint8_t name_idx = code[vm.ip++];
                uint8_t arg_count = code[vm.ip++];
                if (!ensure_stack(arg_count)) { success = false; goto cleanup; }
                StringName sname = String(read_constant(name_idx));
                if (owner) {
                    if (arg_count == 0) {
                        owner->emit_signal(sname);
                    } else if (arg_count == 1) {
                        Variant a0 = pop_value();
                        owner->emit_signal(sname, a0);
                    } else if (arg_count == 2) {
                        Variant a1 = pop_value();
                        Variant a0 = pop_value();
                        owner->emit_signal(sname, a0, a1);
                    } else if (arg_count == 3) {
                        Variant a2 = pop_value();
                        Variant a1 = pop_value();
                        Variant a0 = pop_value();
                        owner->emit_signal(sname, a0, a1, a2);
                    } else if (arg_count == 4) {
                        Variant a3 = pop_value();
                        Variant a2 = pop_value();
                        Variant a1 = pop_value();
                        Variant a0 = pop_value();
                        owner->emit_signal(sname, a0, a1, a2, a3);
                    } else {
                        // 5+ args: pop all, use first 5
                        Array args;
                        args.resize(arg_count);
                        for (int i = arg_count - 1; i >= 0; i--) {
                            args[i] = pop_value();
                        }
                        owner->emit_signal(sname, args[0], args[1], args[2], args[3], args[4]);
                    }
                } else {
                    // No owner — just pop and discard args
                    for (int i = 0; i < arg_count; i++) pop_value();
                }
                VG_BREAK;
            }

            vg_op_default: default:
                UtilityFunctions::printerr("VisualGasic: unsupported opcode ", (int)op);
                success = false;
                goto cleanup;
        }
    }

#undef VG_CASE
#undef VG_BREAK
#if VG_USE_COMPUTED_GOTO
#undef VG_USE_COMPUTED_GOTO
#endif

cleanup:
    // Materialize any active VGFastStringDict pools back into locals[]
    // so that cleanup/return-value logic sees a proper Godot Dictionary.
    for (int i = 0; i < VGDICT_POOL_MAX; i++) {
        if (vgdict_slot_active[i]) {
            if (i < locals.size()) {
                locals.write[i] = vgdict_pool[i].to_godot_dict();
            }
            vgdict_pool[i].clear();
            vgdict_slot_active[i] = false;
        }
    }

    // When fast-path was active (needs_var_sync == false), locals were NOT
    // written to the variables[] Dictionary during execution.  Flush them
    // now so that the caller / AST interpreter can read the final values.
    // IMPORTANT: Only flush on success.  On failure the AST fallback will
    // re-execute the function from scratch, so we must leave variables[]
    // untouched.  This eliminates the need for variables.duplicate(true)
    // in call_internal() — the single biggest performance bottleneck.
    // NOTE: Skip the flush for parallel workers (p_initial_locals != nullptr)
    // because worker locals are private; shared state goes through
    // OP_GET_GLOBAL / OP_SET_GLOBAL protected by Lock/Unlock.
    if (success && !needs_var_sync && !p_initial_locals) {
        for (int i = 0; i < locals.size() && i < chunk->local_names.size(); i++) {
            const String &name = chunk->local_names[i];
            if (!name.is_empty()) {
                variables[name] = locals[i];
            }
        }
    }

    // On failure, rollback global variables that OP_SET_GLOBAL wrote directly
    // to variables[].  Without this, the AST fallback would re-execute the
    // entire function, causing globals to be double-mutated (e.g. wave += 1
    // runs in bytecode, then again in AST → wave += 2).
    // Skip for parallel workers — they don't own global rollback.
    if (!success && !p_initial_locals && saved_globals.size() > 0) {
        Array gkeys = saved_globals.keys();
        for (int i = 0; i < gkeys.size(); i++) {
            variables[gkeys[i]] = saved_globals[gkeys[i]];
        }
    }

    if (success) {
        if (has_explicit_return) {
            result_snapshot = explicit_return;
            // Bug fix: Also write to variables[func->name] so that
            // call_internal's return-value lookup sees it. Otherwise
            // the default-initialized value (0/"") wins over the
            // actual Return value.
            if (func && func->type == SubDefinition::TYPE_FUNCTION) {
                variables[func->name] = explicit_return;
            }
        } else if (vm.stack.size() > stack_base) {
            result_snapshot = vm.stack[vm.stack.size() - 1];
        }
    }
    restore_vm();
    finalize_stack_profile();
    finalize_profile();
    
    // Pop debug stack frame (must match push above; skipped for parallel workers and sub-range bodies)
    if (!is_parallel_worker && !is_sub_range) {
        VisualGasicLanguage::pop_stack_frame();
    }
    
    if (!success) {
        r_ret = Variant();
        return false;
    }

    if (func && func->type == SubDefinition::TYPE_FUNCTION) {
        if (has_explicit_return) {
            r_ret = result_snapshot;
        } else if (variables.has(func->name)) {
            r_ret = variables[func->name];
        } else {
            r_ret = result_snapshot;
        }
    } else {
        r_ret = result_snapshot;
    }
    return true;
}

