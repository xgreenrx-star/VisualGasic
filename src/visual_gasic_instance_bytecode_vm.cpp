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
#include "visual_gasic_jit_tier3.h"
#include "gasic_ai_controller.h"
#include "visual_gasic_comm.h"
#include "visual_gasic_memory_buffer.h"
#include <cmath>  // ::sin, ::cos, ::sqrt, ::tan, ::atan2, ::floor, ::ceil, ::exp, ::log

// POSIX unlink / Win32 DeleteFile for Kill symlink fallback
#if defined(__linux__) || defined(__APPLE__) || defined(__unix__)
#include <unistd.h>
#endif
#if defined(_WIN32)
#include <windows.h>
#endif

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
#include <godot_cpp/classes/scene_tree_timer.hpp>
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
#include <godot_cpp/classes/system_font.hpp>
#include <godot_cpp/classes/font_variation.hpp>
#include <godot_cpp/classes/theme_db.hpp>
#include <godot_cpp/classes/theme.hpp>
#include <godot_cpp/classes/style_box_flat.hpp>
#include <godot_cpp/classes/style_box_empty.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/classes/texture_rect.hpp>
#include <godot_cpp/classes/option_button.hpp>
#include <godot_cpp/classes/check_box.hpp>
#include <godot_cpp/classes/check_button.hpp>
#include <godot_cpp/classes/spin_box.hpp>
#include <godot_cpp/classes/tab_container.hpp>
#include <godot_cpp/classes/rich_text_label.hpp>
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
// Pass 1 — value-type field access (May 11 2026)
#include <godot_cpp/variant/quaternion.hpp>
#include <godot_cpp/variant/plane.hpp>
#include <godot_cpp/variant/aabb.hpp>
#include <godot_cpp/variant/transform2d.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/variant/basis.hpp>
#include <godot_cpp/variant/vector4.hpp>
#include <godot_cpp/core/object.hpp>
#include <godot_cpp/templates/hash_set.hpp>
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
                                           const Vector<Variant>* p_initial_locals,
                                           const Vector<Variant>* p_fast_args) {
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

    // ── JIT Tier 2/3: attempt native execution for hot functions ──────────
#ifdef __linux__
    // Fast-call chunks (fast_params) seed params directly into local slots and
    // never place them in variables[]; the JIT marshaler reads params FROM
    // variables[], so it would read stale/empty values.  Skip JIT for them —
    // the interpreter fast-call path is what wins the benchmark anyway.
    if (p_ip_start == 0 && p_ip_end <= 0 && func && !p_initial_locals && !chunk->fast_params) {
        std::string jit_name;
        if (func->name.length() > 0) {
            jit_name = std::string(func->name.utf8().get_data());
        }
        if (!jit_name.empty()) {
            // ── Tier 3: record bytecode size for call-graph profiling ───
            vgjit3::Tier3& t3 = vgjit3::thread_jit3();
            if (t3.enabled()) {
                t3.record_bytecode_size(jit_name, chunk->code.size());
            }

            // ── Tier 3: try fused call-graph compilation first ──────────
            if (t3.enabled()) {
                // Provide a chunk resolver that looks up compiled chunks
                // from this script instance's function table.
                struct ResolverCtx {
                    VisualGasicInstance* self;
                };
                ResolverCtx rctx { this };
                auto chunk_resolver = [](const std::string& name, void* ctx) -> BytecodeChunk* {
                    auto* rc = static_cast<ResolverCtx*>(ctx);
                    String gname = String(name.c_str());
                    if (rc->self->script.is_valid()) {
                        return rc->self->script->get_bytecode_for(gname, &rc->self->get_global_buffer_var_names());
                    }
                    return nullptr;
                };
                vgjit2::CompiledFunc* fused = t3.get_or_compile(jit_name, chunk_resolver, &rctx);
                if (fused && fused->fn) {
                    int slot_count = fused->total_slots > 0 ? fused->total_slots : chunk->local_count;
                    if (slot_count < 1) slot_count = 1;
                    std::vector<int64_t> jit_locals(slot_count, 0);
                    for (int i = 0; i < chunk->local_count && i < chunk->local_names.size(); i++) {
                        const String &lname = chunk->local_names[i];
                        if (!lname.is_empty()) {
                            Variant v;
                            if (variables.has(lname)) v = variables[lname];
                            else if (builtin_constants.has(lname)) v = builtin_constants[lname];
                            if (v.get_type() == Variant::INT) jit_locals[i] = (int64_t)v;
                            else if (v.get_type() == Variant::FLOAT) {
                                double d = (double)v; memcpy(&jit_locals[i], &d, 8);
                            }
                        }
                    }
                    int64_t has_retval = fused->fn(jit_locals.data(), (int64_t)slot_count);
                    for (int i = 0; i < chunk->local_count && i < chunk->local_names.size(); i++) {
                        const String &lname = chunk->local_names[i];
                        if (!lname.is_empty() && !builtin_constants.has(lname)) variables[lname] = Variant((int64_t)jit_locals[i]);
                    }
                    if (has_retval) {
                        r_ret = Variant((int64_t)jit_locals[0]);
                    } else {
                        r_ret = Variant();
                    }
                    // Restore the shared thread-local VM state (ip/stack)
                    // that this frame clobbered before returning to the
                    // caller — otherwise the caller's vm.ip stays at
                    // p_ip_start (0) and its interpreter loop restarts.
                    restore_vm();
                    return true;
                }
            }

            // ── Tier 2: per-function native compilation ─────────────────
            vgjit2::CompiledFunc* native = vgjit2::thread_jit().get_or_compile(jit_name, chunk);
            if (native && native->fn) {
                // Marshal locals + virtual global slots into int64 array
                int slot_count = native->total_slots > 0 ? native->total_slots : chunk->local_count;
                if (slot_count < 1) slot_count = 1;
                std::vector<int64_t> jit_locals(slot_count, 0);
                // Pre-populate real locals from variable values
                for (int i = 0; i < chunk->local_count && i < chunk->local_names.size(); i++) {
                    const String &lname = chunk->local_names[i];
                    if (!lname.is_empty()) {
                        Variant v;
                        if (variables.has(lname)) v = variables[lname];
                        else if (builtin_constants.has(lname)) v = builtin_constants[lname];
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
                    if (slot >= 0 && slot < slot_count) {
                        Variant v;
                        if (variables.has(gname)) v = variables[gname];
                        else if (builtin_constants.has(gname)) v = builtin_constants[gname];
                        if (v.get_type() == Variant::INT) {
                            jit_locals[slot] = (int64_t)v;
                        } else if (v.get_type() == Variant::FLOAT) {
                            double d = (double)v;
                            memcpy(&jit_locals[slot], &d, 8);
                        }
                    }
                }
                int64_t has_retval = native->fn(jit_locals.data(), (int64_t)slot_count);
                // Sync real locals back to variables (skip built-in constants)
                for (int i = 0; i < chunk->local_count && i < chunk->local_names.size(); i++) {
                    const String &lname = chunk->local_names[i];
                    if (!lname.is_empty() && !builtin_constants.has(lname)) {
                        variables[lname] = Variant((int64_t)jit_locals[i]);
                    }
                }
                // Sync virtual global slots back to variables (skip built-in constants)
                for (const auto& gs : native->global_slots) {
                    String gname = String(gs.first.c_str());
                    int slot = gs.second;
                    if (slot >= 0 && slot < slot_count && !builtin_constants.has(gname)) {
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
                // Restore the shared thread-local VM state (ip/stack) this
                // frame clobbered before returning to the caller — otherwise
                // the caller's vm.ip stays at p_ip_start (0) and its
                // interpreter loop restarts, hanging the process.
                restore_vm();
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
                if (!name.is_empty()) {
                    if (variables.has(name)) {
                        initial = variables[name];
                    } else if (builtin_constants.has(name)) {
                        initial = builtin_constants[name];
                    } else if (get_global_scope().has(name)) {
                        initial = get_global_scope()[name];
                    }
                }
            }
            locals.write[i] = initial;
        }
    }

    // ── Fast-call convention (v6.0) ────────────────────────────────────
    // When the compiler flagged this chunk fast_params, the caller
    // (call_internal) did NOT bind the parameters or return variable into the
    // variables[] Dictionary.  Instead the coerced argument values arrive via
    // p_fast_args and are dropped straight into the leading local slots here,
    // and the return value is read back out of return_slot on exit (below).
    // Slots [0, param_count) are parameters; return_slot (if >= 0) holds the
    // Function result and is initialised from the last p_fast_args element (the
    // typed zero the caller computed from the return type).
    const bool fast_call = (chunk->fast_params && p_fast_args != nullptr);
    const int  fast_param_count = fast_call ? chunk->param_count : 0;
    const int  fast_return_slot = fast_call ? chunk->return_slot : -1;
    auto is_fast_slot = [&](int slot) -> bool {
        return fast_call && (slot < fast_param_count || slot == fast_return_slot);
    };
    if (fast_call) {
        for (int i = 0; i < fast_param_count && i < p_fast_args->size() && i < locals.size(); i++) {
            locals.write[i] = (*p_fast_args)[i];
        }
        if (fast_return_slot >= 0 && fast_return_slot < locals.size()) {
            // The caller appends the typed return-init value after the params.
            if (p_fast_args->size() > fast_param_count) {
                locals.write[fast_return_slot] = (*p_fast_args)[fast_param_count];
            }
        }
    }

    // ── v4.8: Hybrid typed local storage ──────────────────────────────
    // Parallel typed arrays let us bypass the Variant constructor/destructor
    // overhead for variables with known compiler types (VT_INT=1, VT_FLOAT=2).
    // read_local() / sync_local() maintain both views in sync.
    // ────────────────────────────────────────────────────────────────────
    PackedInt64Array typed_i64_locals;
    PackedFloat64Array typed_f64_locals;
    typed_i64_locals.resize(chunk->local_count);
    typed_f64_locals.resize(chunk->local_count);
    for (int i = 0; i < chunk->local_count; i++) {
        typed_i64_locals.set(i, 0);
        typed_f64_locals.set(i, 0.0);
    }
    // Seed typed locals from initial Variant locals using type info.
    for (int i = 0; i < chunk->local_count && i < chunk->local_types.size(); i++) {
        uint8_t lt = chunk->local_types[i];
        if (lt == 1 && i < locals.size()) {
            typed_i64_locals.set(i, (int64_t)locals[i]);
        } else if (lt == 2 && i < locals.size()) {
            typed_f64_locals.set(i, (double)locals[i]);
        }
    }

    // Expose the current bytecode frame's locals to the debugger.
    // Saved/restored so nested execute_bytecode() calls (e.g. Function calls)
    // don't clobber the outer frame's pointer on return.
    Vector<Variant>* prev_debug_bc_locals = debug_bc_locals;
    BytecodeChunk*   prev_debug_bc_chunk  = debug_bc_chunk;
    debug_bc_locals = &locals;
    debug_bc_chunk  = chunk;

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
        // ── v4.8: Update typed shadow arrays ───────────────────
        if (slot < chunk->local_types.size()) {
            uint8_t lt = chunk->local_types[slot];
            if (lt == 1) {
                typed_i64_locals.set(slot, (int64_t)value);
            } else if (lt == 2) {
                typed_f64_locals.set(slot, (double)value);
            }
        }
        // Fast path: skip the expensive variables[] Dictionary sync
        // when no Whenever callbacks need it (v2.4.1 optimisation).
        // Also skip when running as isolated parallel worker (v4.1).
        // Fast-call param/return slots are ALWAYS pure-local (never mirrored
        // into variables[]) so that even an active Whenever can't leak them.
        if (needs_var_sync && !isolated_locals && !is_fast_slot(slot)) {
            String name = get_local_name(slot);
            if (!name.is_empty() && !builtin_constants.has(name)) {
                variables[name] = value;
            }
        }
    };

    auto read_local = [&](int slot) -> Variant {
        if (slot >= 0 && slot < locals.size()) {
            if (!needs_var_sync || isolated_locals || is_fast_slot(slot)) {
                return locals[slot];
            }
            // Slow path: read from variables dictionary to pick up
            // changes made by Whenever callbacks or nested calls
            String name = get_local_name(slot);
            if (!name.is_empty()) {
                if (variables.has(name)) {
                    Variant current = variables[name];
                    locals.write[slot] = current;
                    if (slot < chunk->local_types.size()) {
                        uint8_t lt = chunk->local_types[slot];
                        if (lt == 1) typed_i64_locals.set(slot, (int64_t)current);
                        else if (lt == 2) typed_f64_locals.set(slot, (double)current);
                    }
                    return current;
                }
                if (builtin_constants.has(name)) {
                    Variant current = builtin_constants[name];
                    locals.write[slot] = current;
                    if (slot < chunk->local_types.size()) {
                        uint8_t lt = chunk->local_types[slot];
                        if (lt == 1) typed_i64_locals.set(slot, (int64_t)current);
                        else if (lt == 2) typed_f64_locals.set(slot, (double)current);
                    }
                    return current;
                }
                if (get_global_scope().has(name)) {
                    Variant current = get_global_scope()[name];
                    locals.write[slot] = current;
                    if (slot < chunk->local_types.size()) {
                        uint8_t lt = chunk->local_types[slot];
                        if (lt == 1) typed_i64_locals.set(slot, (int64_t)current);
                        else if (lt == 2) typed_f64_locals.set(slot, (double)current);
                    }
                    return current;
                }
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

    // ── v4.8: Fast typed local readers/writers ─────────────────────
    // Bypass Variant entirely for known-typed locals. These are used
    // by the typed arithmetic opcodes (OP_INC_LOCAL_I64, etc.) to
    // avoid the read_local()→to_int() Variant round-trip.
    auto read_local_i64 = [&](int slot) -> int64_t {
        if (slot >= 0 && slot < locals.size()) {
            if ((!needs_var_sync || isolated_locals) && slot < chunk->local_types.size() && chunk->local_types[slot] == 1) {
                return typed_i64_locals[slot];
            }
            // Fallback: use Variant path
            return to_int(read_local(slot));
        }
        return 0;
    };
    auto read_local_f64 = [&](int slot) -> double {
        if (slot >= 0 && slot < locals.size()) {
            if ((!needs_var_sync || isolated_locals) && slot < chunk->local_types.size() && chunk->local_types[slot] == 2) {
                return typed_f64_locals[slot];
            }
            return to_double(read_local(slot));
        }
        return 0.0;
    };
    // Direct typed write that also updates the shadow array
    auto sync_local_i64 = [&](int slot, int64_t value) {
        if (slot < 0 || slot >= locals.size()) return;
        typed_i64_locals.set(slot, value);
        // Always keep locals[] in sync for debugger and Variant read_local
        locals.write[slot] = Variant(value);
        if (slot < chunk->local_types.size() && chunk->local_types[slot] == 1) {
            if (needs_var_sync && !isolated_locals) {
                String name = get_local_name(slot);
                if (!name.is_empty() && !builtin_constants.has(name)) {
                    variables[name] = Variant(value);
                }
            }
        } else {
            sync_local(slot, Variant(value));
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
                String debug_msg = vformat("Op:%d TypeA:%d TypeB:%d ValA:%s ValB:%s line:%d (count: %d)", 
                    (int)op, (int)a.get_type(), (int)b.get_type(), a, b, debug_state.current_line, error_count);
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
    // v6.0 perf: Vector<Pair> instead of a heap Dictionary — usually holds 0-1
    // entries, and an empty Vector allocates nothing, so this removes a per-call
    // Dictionary construction (+ a keys() Array on the rare rollback path).
    Vector<Pair<String, Variant>> saved_globals;
    if (p_ip_end <= 0) {
      if (!chunk->globals_scan_done) {
        // One-time full-chunk walk: collect the deterministic set of global
        // names written via OP_SET_GLOBAL into chunk->globals_written, so the
        // per-call rollback snapshot below iterates that small list instead of
        // re-walking the ENTIRE bytecode on every single call (a large per-call
        // cost for big Subs like the C64 CPU-step function).
        int scan_ip = 0;
        while (scan_ip < code_size) {
            uint8_t scan_op = code[scan_ip++];
            if (scan_op == OP_SET_GLOBAL && scan_ip + 1 < code_size) {
                int idx = (code[scan_ip + 1] << 8) | code[scan_ip];
                if (idx >= 0 && idx < chunk->constants.size()) {
                    String gname = chunk->constants[idx];
                    if (chunk->globals_written.find(gname) == -1) {
                        chunk->globals_written.push_back(gname);
                    }
                }
                scan_ip += 2; // skip the 2-byte name index
            } else {
                // Skip operand bytes for multi-byte opcodes so the scan
                // doesn't misinterpret data bytes as OP_SET_GLOBAL.
                switch (scan_op) {
                    // 1-operand opcodes: local slot / non-const (1 byte)
                    case OP_GET_LOCAL: case OP_SET_LOCAL:
                    case OP_INC_LOCAL_I64:
                    case OP_ADD_LOCAL_I64_STACK: case OP_SUB_LOCAL_I64_STACK:
                    case OP_BRANCH_SUM:
                    case OP_GET_ARRAY: case OP_SET_ARRAY:
                    case OP_GET_ARRAY_UNCHECKED: case OP_SET_ARRAY_UNCHECKED:
                    case OP_GET_ARRAY_FAST: case OP_SET_ARRAY_FAST:
                    case OP_GET_ARRAY_FAST_UNCHECKED: case OP_SET_ARRAY_FAST_UNCHECKED:
                    case OP_GET_DICT_FAST: case OP_SET_DICT_FAST:
                    case OP_GET_DICT_TRUSTED: case OP_SET_DICT_TRUSTED:
                    case OP_INTEROP_SET_NAME_LEN:
                    case OP_SUM_VGDICT_ALL_I64:
                    case OP_NEW_VGDICT: case OP_GET_VGDICT_LOCAL: case OP_SET_VGDICT_LOCAL:
                    case OP_ITER_ARRAY:
                    case OP_NEW_ARRAY: case OP_NEW_ARRAY_I64:
                    case OP_GOSUB: case OP_PRINT_FILE:
                    // M5: MemoryBuffer opcodes (opcode + slot)
                    case OP_BUF_ALLOC: case OP_BUF_FREE:
                    case OP_BUF_READ8: case OP_BUF_WRITE8:
                    case OP_BUF_READ16: case OP_BUF_WRITE16:
                    case OP_BUF_READ32: case OP_BUF_WRITE32:
                    case OP_BUF_SIZE: case OP_BUF_RESIZE:
                    // M6: Optimization hints (opcode + slot/idx)
                    case OP_HINT_ACCUMULATOR: case OP_HINT_LOOP_COUNTER:
                    case OP_HINT_PURE_CALL:
                        scan_ip += 1; break;
                    // M6: Jump table (variable-length: 8 header + count*2 table bytes)
                    case OP_JUMP_TABLE: {
                        if (scan_ip + 8 <= code_size) {
                            int num_cases = (int)code[scan_ip + 6] | ((int)code[scan_ip + 7] << 8);
                            scan_ip += 8 + num_cases * 2;
                        } else {
                            scan_ip = code_size;  // Malformed bytecode, abort scan
                        }
                        break;
                    }
                    // 1-operand opcodes: 2-byte const pool index
                    case OP_CONSTANT: case OP_CONSTANT_LONG:
                    case OP_GET_GLOBAL:
                    case OP_GET_MEMBER: case OP_SET_MEMBER:
                    case OP_REGISTER_WHENEVER: case OP_SUSPEND_WHENEVER: case OP_RESUME_WHENEVER:
                    case OP_ON_ERROR_GOTO:
                    case OP_ADD_I64_CONST: case OP_SUB_I64_CONST: case OP_MUL_I64_CONST:
                    case OP_COERCE_TYPE:
                    case OP_GET_GLOBAL_BUF8: case OP_SET_GLOBAL_BUF8:
                        scan_ip += 2; break;
                    // OP_BYREF_LOAD: 2-byte const index + 1-byte flag + 2-byte dest = 5 bytes
                    case OP_BYREF_LOAD:
                        scan_ip += 5; break;
                    // 2-operand opcodes: two 1-byte non-const operands
                    case OP_JUMP: case OP_JUMP_IF_FALSE: case OP_JUMP_IF_TRUE:
                    case OP_LOOP:
                    case OP_CALL_BUILTIN:
                    case OP_SETUP_TRY:
                    case OP_DEBUG_LINE:
                    case OP_SET_DICT_LOCAL:
                    case OP_OPEN_FILE:
                    case OP_WRITE_FILE:
                        scan_ip += 2; break;
                    // 2-byte const index + 1-byte operand = 3 bytes
                    case OP_CALL:
                    case OP_METHOD_CALL:
                    case OP_ADD_LOCAL_I64_CONST: case OP_SUB_LOCAL_I64_CONST:
                    case OP_STRING_REPEAT_OUTER:
                    case OP_SET_DICT_GLOBAL:
                    case OP_NEW_OBJECT:
                    case OP_RAISE_EVENT:
                        scan_ip += 3; break;
                    // 4-byte opcodes (all-slot operands)
                    case OP_ALLOC_FILL_I64_OFFSET:
                    case OP_ARRAY_FILL_I64_OFFSET:
                        scan_ip += 3; break;
                    // 4-byte opcodes (slots + 2-byte const)
                    case OP_ACCUM_I64_MULADD_CONST:  // s_slot(1) + j_slot(1) + k_const(2)
                    case OP_ARITH_SUM:  // k_const(2) + c_const(2)
                        scan_ip += 4; break;
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
                    // OP_TASK_RUN_BEGIN: [NAME_CONST(2)] [BG_FLAG] [BODY_LEN_HI] [BODY_LEN_LO] + body
                    case OP_TASK_RUN_BEGIN: {
                        if (scan_ip + 4 < code_size) {
                            scan_ip += 3; // name_const (2 bytes), bg_flag
                            int body_len = (code[scan_ip] << 8) | code[scan_ip + 1];
                            scan_ip += 2; // body_len_hi, body_len_lo
                            scan_ip += body_len; // skip entire body
                        } else {
                            scan_ip = code_size;
                        }
                        break;
                    }
                    // OP_ALLOC_FILL_REPEAT_I64: 3 slots + lit_const(2) + 2 slots = 7 bytes
                    case OP_ALLOC_FILL_REPEAT_I64:
                        scan_ip += 7; break;
                    default:
                        // 1-byte opcodes (no operands) — nothing to skip
                        break;
                }
            }
        }
        chunk->globals_scan_done = true;
      }
      // Per-call: snapshot only the known written globals that currently exist
      // in variables[] (behavior-identical to the old inline scan+snapshot, but
      // O(globals written) instead of O(entire chunk)).
      for (int gi = 0; gi < chunk->globals_written.size(); gi++) {
          const String &gname = chunk->globals_written[gi];
          if (variables.has(gname)) {
              saved_globals.push_back({gname, variables[gname]});
          }
      }
    }

    auto read_constant = [&](int idx) -> Variant {
        if (idx >= 0 && idx < chunk->constants.size()) {
            return chunk->constants[idx];
        }
        return Variant();
    };

    // Read a 16-bit little-endian constant pool index from the bytecode
    // stream, advancing vm.ip by 2.  All constant-pool operands use this
    // encoding as of v4.3 (lifted from the old 1-byte / 256-entry limit).
    auto read_const_index = [&]() -> int {
        if (vm.ip + 1 >= code_size) {
            return 0;
        }
        uint8_t lo = code[vm.ip++];
        uint8_t hi = code[vm.ip++];
        return (hi << 8) | lo;
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
        
        // Exception Assistant: break into debugger on unhandled errors (VB6 style)
        if (error_state.mode == ErrorState::NONE && VisualGasicLanguage::get_break_on_error()) {
            EngineDebugger* err_debugger = EngineDebugger::get_singleton();
            String err_script_path = debug_state.current_file;
            if (err_debugger && err_debugger->is_active() && !err_script_path.is_empty()) {
                VisualGasicLanguage::set_current_break_location(err_script_path, debug_state.current_line);
                
                // Send error_break message with error details
                Array error_data;
                error_data.push_back(err_script_path);
                error_data.push_back(debug_state.current_line);
                error_data.push_back(error_state.message);
                error_data.push_back(error_state.code);
                err_debugger->send_message("visualgasic:error_break", error_data);
                
                // Also send current state for inspection
                _send_variables_to_debugger(err_debugger);
                _send_call_stack_to_debugger(err_debugger);
                err_debugger->line_poll();
                
                VisualGasicLanguage::vg_debug_wait();
                
                // VB6 behavior: when the user presses Continue (or Debug
                // then later Continue), the error is dismissed and execution
                // resumes past the errored statement.  Clear the error state
                // and return true so the opcode handler continues normally
                // instead of propagating to a native_msgbox.
                // (If the user chose End, the game process is terminated by
                // the editor, so we'll never reach this point.)
                error_state.has_error = false;
                if (push_default) push_value(default_val);
                return true;
            }
        }
        
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
        // Part F: memoized special-global test (-1 unknown, 0 no, 1 yes).
        // The name at a given constant slot is immutable, so OP_GET_GLOBAL
        // runs to_lower + the HashSet probe once per distinct name instead of
        // once per read (to_lower was ~12% of C64 runtime after Part E).
        int8_t is_special_global = -1;
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
        dispatch_table[OP_SHL]            = &&vg_op_shl;
        dispatch_table[OP_SHR]            = &&vg_op_shr;
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
        dispatch_table[OP_SIN]            = &&vg_op_sin;
        dispatch_table[OP_COS]            = &&vg_op_cos;
        dispatch_table[OP_SQRT]           = &&vg_op_sqrt;
        dispatch_table[OP_TAN]            = &&vg_op_tan;
        dispatch_table[OP_ATAN2]          = &&vg_op_atan2;
        dispatch_table[OP_FLOOR_F]        = &&vg_op_floor_f;
        dispatch_table[OP_CEIL_F]         = &&vg_op_ceil_f;
        dispatch_table[OP_EXP]            = &&vg_op_exp;
        dispatch_table[OP_LOG]            = &&vg_op_log;
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
        dispatch_table[OP_ADDRESS_OF]         = &&vg_op_address_of;
        // M5: MemoryBuffer (v5.0)
        dispatch_table[OP_BUF_ALLOC]      = &&vg_op_buf_alloc;
        dispatch_table[OP_BUF_FREE]       = &&vg_op_buf_free;
        dispatch_table[OP_BUF_READ8]      = &&vg_op_buf_read8;
        dispatch_table[OP_BUF_WRITE8]     = &&vg_op_buf_write8;
        dispatch_table[OP_BUF_READ16]     = &&vg_op_buf_read16;
        dispatch_table[OP_BUF_WRITE16]    = &&vg_op_buf_write16;
        dispatch_table[OP_BUF_READ32]     = &&vg_op_buf_read32;
        dispatch_table[OP_BUF_WRITE32]    = &&vg_op_buf_write32;
        dispatch_table[OP_BUF_SIZE]       = &&vg_op_buf_size;
        dispatch_table[OP_BUF_RESIZE]     = &&vg_op_buf_resize;
        // v6.2: Global VGMemoryBuffer fast path (fused OP_GET_GLOBAL + OP_GET_ARRAY)
        dispatch_table[OP_GET_GLOBAL_BUF8] = &&vg_op_get_global_buf8;
        dispatch_table[OP_SET_GLOBAL_BUF8] = &&vg_op_set_global_buf8;
        // M6: Optimization Hints (v6.0)
        dispatch_table[OP_HINT_ACCUMULATOR] = &&vg_op_hint_accum;
        dispatch_table[OP_HINT_LOOP_COUNTER] = &&vg_op_hint_counter;
        dispatch_table[OP_HINT_PURE_CALL]    = &&vg_op_hint_pure;
        dispatch_table[OP_JUMP_TABLE]        = &&vg_op_jump_table;
        dispatch_table[OP_BYREF_LOAD]        = &&vg_op_byref_load;
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
                if (vm.ip + 1 >= code_size) {
                    success = false;
                    goto cleanup;
                }
                int idx = read_const_index();
                push_value(read_constant(idx));
                break;
            }
            VG_CASE(vg_op_constant_long, OP_CONSTANT_LONG): {
                if (vm.ip + 1 >= code_size) {
                    success = false;
                    goto cleanup;
                }
                int idx = read_const_index();
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
                } else if (arr_v.get_type() == Variant::PACKED_VECTOR2_ARRAY) {
                    PackedVector2Array arr = arr_v;
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
                // [OP] [CLASS_NAME_IDX(2)] [ARG_COUNT]
                if (vm.ip + 2 >= code_size) { success = false; goto cleanup; }
                int name_idx = read_const_index();
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
                    // v4.3 aliases – Database controls
                    else if (class_name.nocasecmp_to("Recordset") == 0 || class_name.nocasecmp_to("ADODB.Recordset") == 0) resolved = "VGRecordset";
                    // Also resolve full VG* names for v3.0+ (bypass can_instantiate issue)
                    else if (class_name.begins_with("VG") && ClassDB::class_exists(class_name)) resolved = class_name;

                    if (!resolved.is_empty() && ClassDB::class_exists(resolved)) {
                        Variant inst = ClassDB::instantiate(resolved);
                        if (inst.get_type() == Variant::OBJECT) {
                            // v4.4.0: New MemoryBuffer(size) via the generic OP_NEW_OBJECT
                            // path (e.g. assigning to a module-level/global var) never used
                            // to allocate the backing storage — only the local-slot fast
                            // path (OP_BUF_ALLOC) did. Allocate here too so global
                            // MemoryBuffer objects actually work.
                            if (resolved == "VGMemoryBuffer" && arg_count > 0) {
                                Object *obj = inst;
                                VGMemoryBuffer *mb = Object::cast_to<VGMemoryBuffer>(obj);
                                if (mb) mb->allocate((int64_t)to_int(args_arr[0]));
                            }
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
                if (vm.ip + 1 >= code_size) {
                    success = false;
                    goto cleanup;
                }
                int idx = read_const_index();
                Variant name_var = read_constant(idx);
                String name = name_var;
                
                // Handle special keywords first
                // "Me" - returns owner (self reference), or the current class
                // instance's object ID when executing inside a Class method
                // (see visual_gasic_instance_evaluate.inc for the tree-walk
                // equivalent — class methods currently only run via the tree-
                // walk interpreter, but keep this in sync in case that changes).
                // ── Perf gate (Part E) ── the special-identifier cascade below
                // (Me/Super/Input/Godot/App/Screen/Err/Printer) issued up to 8
                // nocasecmp_to GDExtension ptrcalls on EVERY global read, which
                // dominated hot loops that read module-level variables (10.76% of
                // C64-emulator runtime, per perf). Every one of these identifiers
                // is rare; the common case is an ordinary user/global variable.
                // Probe one lowercased-name HashSet and enter the cascade only
                // when the name really is special — same pattern/justification as
                // the OP_CALL special-call gate (commit f2a6213b). The dynamic
                // owner form-name self-reference (name == owner node's Name) can't
                // live in a static set, so it moved to the not-a-variable fallback
                // path below.
                static const HashSet<String> _vg_global_special_names = []() {
                    HashSet<String> s;
                    const char *nm[] = { "me", "super", "input", "godot", "app", "screen", "err", "printer" };
                    for (const char *n : nm) s.insert(String(n));
                    return s;
                }();
                // Part F: memoize the special-name test per constant index so the
                // to_lower ptrcall runs once per distinct global name, not per read.
                bool _name_is_special;
                if (idx >= 0 && idx < member_name_cache.size()) {
                    int8_t &_sp = member_name_cache.write[idx].is_special_global;
                    if (_sp < 0) {
                        _sp = _vg_global_special_names.has(name.to_lower()) ? 1 : 0;
                    }
                    _name_is_special = (_sp == 1);
                } else {
                    _name_is_special = _vg_global_special_names.has(name.to_lower());
                }
                if (_name_is_special) {
                if (name.nocasecmp_to("Me") == 0) {
                    if (current_object_id != -1) {
                        push_value(Variant((int64_t)current_object_id));
                        break;
                    }
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
                // VB6 Printer global object (v3.5.0) — persistent dictionary
                if (name.nocasecmp_to("Printer") == 0) {
                    if (variables.has("__vg_Printer")) {
                        push_value(variables["__vg_Printer"]);
                    } else {
                        Dictionary printer;
                        printer["Font"] = String("Arial");
                        printer["FontSize"] = 12;
                        printer["FontBold"] = false;
                        printer["FontItalic"] = false;
                        printer["Orientation"] = 1;
                        printer["Copies"] = 1;
                        printer["Page"] = 1;
                        printer["CurrentX"] = 0;
                        printer["CurrentY"] = 0;
                        printer["ScaleWidth"] = 8500;
                        printer["ScaleHeight"] = 11000;
                        printer["hDC"] = 0;
                        printer["ColorMode"] = 1;
                        printer["PaperSize"] = 1;
                        variables["__vg_Printer"] = printer;
                        push_value(printer);
                    }
                    break;
                }
                }  // end special-identifier gate (Part E)
                
                Variant val = variables.get(name, Variant());
                
                // Fallback to built-in constants (separated so debugger only shows user vars)
                if (val.get_type() == Variant::NIL && builtin_constants.has(name)) {
                    val = builtin_constants[name];
                }

                // Fallback to project-wide "Global Const"/"Global Dim" registry (v4.4.0)
                if (val.get_type() == Variant::NIL && get_global_scope().has(name)) {
                    val = get_global_scope()[name];
                }
                
                // Owner form-name self-reference (e.g. "Form1" → the owning
                // form/node itself). Moved here from before the variable lookup
                // (Part E) so ordinary global reads no longer pay its
                // nocasecmp_to + get_name() on every access; it runs only when
                // the name isn't a plain variable.
                if (val.get_type() == Variant::NIL && owner) {
                    Node *owner_node = Object::cast_to<Node>(owner);
                    if (owner_node && name.nocasecmp_to(owner_node->get_name()) == 0) {
                        push_value(Variant(owner));
                        break;
                    }
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
                
                // Cross-form reference: search scene tree root for another
                // loaded form Window with the matching name (e.g. "Form1"
                // accessed from MyCalculator context).  VB6 allows referencing
                // any loaded form by its Name.
                if (val.get_type() == Variant::NIL && owner) {
                    SceneTree *tree = Object::cast_to<SceneTree>(Engine::get_singleton()->get_main_loop());
                    if (tree) {
                        Window *root = tree->get_root();
                        if (root) {
                            // First check already-loaded forms
                            for (int i = 0; i < root->get_child_count(); i++) {
                                Node *child = root->get_child(i);
                                if (child && name.nocasecmp_to(child->get_name()) == 0) {
                                    val = Variant(child);
                                    break;
                                }
                            }
                            // VB6 auto-load: if not found, try to load the .tscn
                            // from the project (res://<Name>.tscn).  In VB6,
                            // referencing a form by name implicitly loads it.
                            if (val.get_type() == Variant::NIL) {
                                String tscn_path = "res://" + name + ".tscn";
                                if (ResourceLoader::get_singleton()->exists(tscn_path)) {
                                    Ref<PackedScene> scene = ResourceLoader::get_singleton()->load(tscn_path);
                                    if (scene.is_valid()) {
                                        Node *instance = scene->instantiate();
                                        if (instance) {
                                            root->add_child(instance);
                                            val = Variant(instance);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // If not found in variables, try owner node properties (PascalCase → snake_case)
                // e.g. "Position" → owner->get("position") for Area2D/CharacterBody2D
                if (val.get_type() == Variant::NIL && owner) {
                    Variant prop = owner->get(name);
                    if (prop.get_type() != Variant::NIL) {
                        val = prop;
                    } else {
                        String snake = name.to_snake_case();
                        if (snake != name) {
                            prop = owner->get(snake);
                            if (prop.get_type() != Variant::NIL) {
                                val = prop;
                            }
                        }
                    }
                }

                // If not found in variables, search for child control by name (VB6 style)
                if (val.get_type() == Variant::NIL && owner) {
                    Node* owner_node = Object::cast_to<Node>(owner);
                    if (owner_node) {
                        Node *found = owner_node->find_child(name, true, false);
                        // Fallback: search parent (VGASIC helper node pattern)
                        if (!found && owner_node->get_parent()) {
                            found = owner_node->get_parent()->find_child(name, true, false);
                        }
                        if (found) {
                            val = found;
                        }
                    }
                }

                // Builtin namespace sentinels — names like SoundGen, Clipboard,
                // Debug, RegExp are not variables but dispatch targets handled by
                // call_builtin_for_base_variable.  Push a sentinel dict so that
                // OP_METHOD_CALL's call_builtin_for_base_variant can recognise them.
                if (val.get_type() == Variant::NIL) {
                    static const char *known_ns[] = {
                        "SoundGen", "Clipboard", "Debug", "RegExp", "Array",
                        "Music", "Tracker", nullptr
                    };
                    for (int ni = 0; known_ns[ni]; ni++) {
                        if (name.nocasecmp_to(known_ns[ni]) == 0) {
                            Dictionary ns_dict;
                            ns_dict["__vg_namespace"] = name;
                            val = ns_dict;
                            break;
                        }
                    }
                }

                push_value(val);
                break;
            }
            VG_CASE(vg_op_set_global, OP_SET_GLOBAL): {
                if (vm.ip + 1 >= code_size) {
                    success = false;
                    goto cleanup;
                }
                int idx = read_const_index();
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
                    VisualGasicLanguage::vg_debug_wait();
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
                    // Check if it's an owner node property (PascalCase → snake_case)
                    // e.g. "Position = val" → owner->set("position", val) for Area2D
                    bool wrote_to_owner = false;
                    if (owner) {
                        Variant current = owner->get(name);
                        if (current.get_type() != Variant::NIL) {
                            owner->set(name, value);
                            wrote_to_owner = true;
                        } else {
                            String snake = name.to_snake_case();
                            if (snake != name) {
                                current = owner->get(snake);
                                if (current.get_type() != Variant::NIL) {
                                    owner->set(snake, value);
                                    wrote_to_owner = true;
                                }
                            }
                        }
                    }
                    if (!wrote_to_owner) {
                        variables[name] = value;
                    }
                }
                
                // Trigger Whenever system (must match assign_variable behavior)
                check_whenever_conditions(name, variables[name]);
                check_expression_conditions();
                
                break;
            }
            VG_CASE(vg_op_byref_load, OP_BYREF_LOAD): {
                // Push the post-call value of a ByRef parameter captured by the
                // most recent call_internal() (stored in _last_byref_captures).
                // The compiler follows this with an OP_SET_LOCAL / OP_SET_GLOBAL
                // to write the value back into the caller's variable — giving
                // ByRef write-back the same semantics as a normal assignment.
                if (vm.ip + 4 >= code_size) {
                    success = false;
                    goto cleanup;
                }
                int idx = read_const_index();
                Variant pname_var = read_constant(idx);
                String pname = pname_var;
                uint8_t is_global = code[vm.ip++];
                int dest_lo = code[vm.ip++];
                int dest_hi = code[vm.ip++];
                int dest_idx = dest_lo | (dest_hi << 8);

                Variant result;
                bool found = false;
                for (int ci = 0; ci < _last_byref_captures.size(); ci++) {
                    if (_last_byref_captures[ci].first == pname) {
                        result = _last_byref_captures[ci].second;
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    // No write-back was actually captured for this parameter —
                    // most commonly because the call the compiler resolved
                    // target_func against for write-back purposes wasn't what
                    // actually executed at runtime (e.g. a builtin of the same
                    // name always wins over a same-named user Sub/Function).
                    // Re-push the destination's CURRENT value so the following
                    // OP_SET_LOCAL/OP_SET_GLOBAL is a true no-op instead of
                    // overwriting the variable with Nil.
                    if (is_global) {
                        Variant dest_name_var = read_constant(dest_idx);
                        String dest_name = dest_name_var;
                        result = variables.has(dest_name) ? variables[dest_name] : Variant();
                    } else {
                        result = read_local(dest_idx);
                    }
                }
                push_value(result);
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
                // or a form name reference (Form1.BackColor from within Form1)
                if (val.get_type() == Variant::NIL && owner) {
                    String local_name;
                    if (slot < chunk->local_names.size()) {
                        local_name = chunk->local_names[slot];
                    }
                    if (!local_name.is_empty()) {
                        Node* owner_node = Object::cast_to<Node>(owner);
                        if (owner_node) {
                            // Form name self-reference (e.g. "Form1" inside Form1's code)
                            if (local_name.nocasecmp_to(owner_node->get_name()) == 0) {
                                val = Variant(owner);
                            } else {
                                // Child control lookup (e.g. btnPlay, txtName)
                                Node *found = owner_node->find_child(local_name, true, false);
                                // Fallback: search parent (VGASIC helper node pattern)
                                if (!found && owner_node->get_parent()) {
                                    found = owner_node->get_parent()->find_child(local_name, true, false);
                                }
                                if (found) {
                                    val = found;
                                }
                            }
                        }
                        // Cross-form reference: search scene tree for another form
                        if (val.get_type() == Variant::NIL) {
                            SceneTree *tree = Object::cast_to<SceneTree>(Engine::get_singleton()->get_main_loop());
                            if (tree) {
                                Window *root = tree->get_root();
                                if (root) {
                                    for (int i = 0; i < root->get_child_count(); i++) {
                                        Node *child = root->get_child(i);
                                        if (child && local_name.nocasecmp_to(child->get_name()) == 0) {
                                            val = Variant(child);
                                            break;
                                        }
                                    }
                                    // VB6 auto-load: try to load .tscn from project
                                    if (val.get_type() == Variant::NIL) {
                                        String tscn_path = "res://" + local_name + ".tscn";
                                        if (ResourceLoader::get_singleton()->exists(tscn_path)) {
                                            Ref<PackedScene> scene = ResourceLoader::get_singleton()->load(tscn_path);
                                            if (scene.is_valid()) {
                                                Node *instance = scene->instantiate();
                                                if (instance) {
                                                    root->add_child(instance);
                                                    val = Variant(instance);
                                                }
                                            }
                                        }
                                    }
                                }
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
            VG_CASE(vg_op_shl, OP_SHL): {
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                Variant b = pop_value();
                Variant a = pop_value();
                push_value(Variant((int64_t)a << (int64_t)b));
                break;
            }
            VG_CASE(vg_op_shr, OP_SHR): {
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                Variant b = pop_value();
                Variant a = pop_value();
                push_value(Variant((int64_t)a >> (int64_t)b));
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
                if (vm.ip + 2 >= code_size) { success = false; goto cleanup; }
                uint8_t slot = code[vm.ip++];
                int lit_idx = read_const_index();
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
                // Direct int64 extraction avoids to_int() type-switch overhead.
                // The compiler only emits OP_ADD_I64 when both operands are INT.
                if (vm.stack.size() >= 2) {
                    const Variant &bv = vm.stack[vm.stack.size() - 1];
                    const Variant &av = vm.stack[vm.stack.size() - 2];
                    int64_t b = (bv.get_type() == Variant::INT) ? (int64_t)bv : (int64_t)((double)bv);
                    int64_t a = (av.get_type() == Variant::INT) ? (int64_t)av : (int64_t)((double)av);
                    vm.stack.pop_back();
                    vm.stack.pop_back();
                    push_value((int64_t)(a + b));
                } else {
                    success = false;
                    goto cleanup;
                }
                break;
            }
            VG_CASE(vg_op_sub_i64, OP_SUB_I64): {
                if (!ensure_stack(2)) {
                    success = false;
                    goto cleanup;
                }
                if (vm.stack.size() >= 2) {
                    const Variant &bv = vm.stack[vm.stack.size() - 1];
                    const Variant &av = vm.stack[vm.stack.size() - 2];
                    int64_t b = (bv.get_type() == Variant::INT) ? (int64_t)bv : (int64_t)((double)bv);
                    int64_t a = (av.get_type() == Variant::INT) ? (int64_t)av : (int64_t)((double)av);
                    vm.stack.pop_back();
                    vm.stack.pop_back();
                    push_value((int64_t)(a - b));
                } else {
                    success = false;
                    goto cleanup;
                }
                break;
            }
            VG_CASE(vg_op_mul_i64, OP_MUL_I64): {
                if (!ensure_stack(2)) {
                    success = false;
                    goto cleanup;
                }
                if (vm.stack.size() >= 2) {
                    const Variant &bv = vm.stack[vm.stack.size() - 1];
                    const Variant &av = vm.stack[vm.stack.size() - 2];
                    int64_t b = (bv.get_type() == Variant::INT) ? (int64_t)bv : (int64_t)((double)bv);
                    int64_t a = (av.get_type() == Variant::INT) ? (int64_t)av : (int64_t)((double)av);
                    vm.stack.pop_back();
                    vm.stack.pop_back();
                    push_value((int64_t)(a * b));
                } else {
                    success = false;
                    goto cleanup;
                }
                break;
            }
            VG_CASE(vg_op_add_f64, OP_ADD_F64): {
                if (!ensure_stack(2)) {
                    success = false;
                    goto cleanup;
                }
                {
                    Variant bv2 = pop_value();
                    Variant av2 = pop_value();
                    Variant::Type at2 = av2.get_type(), bt2 = bv2.get_type();
                    bool an2 = (at2 == Variant::INT || at2 == Variant::FLOAT || at2 == Variant::BOOL || at2 == Variant::NIL);
                    bool bn2 = (bt2 == Variant::INT || bt2 == Variant::FLOAT || bt2 == Variant::BOOL || bt2 == Variant::NIL);
                    if (an2 && bn2) {
                        push_value(to_double(av2) + to_double(bv2));
                    } else {
                        Variant res2; bool ok2 = false;
                        Variant::evaluate(Variant::OP_ADD, av2, bv2, res2, ok2);
                        if (!ok2) { success = false; goto cleanup; }
                        push_value(res2);
                    }
                }
                break;
            }
            VG_CASE(vg_op_sub_f64, OP_SUB_F64): {
                if (!ensure_stack(2)) {
                    success = false;
                    goto cleanup;
                }
                {
                    Variant bv2 = pop_value();
                    Variant av2 = pop_value();
                    Variant::Type at2 = av2.get_type(), bt2 = bv2.get_type();
                    bool an2 = (at2 == Variant::INT || at2 == Variant::FLOAT || at2 == Variant::BOOL || at2 == Variant::NIL);
                    bool bn2 = (bt2 == Variant::INT || bt2 == Variant::FLOAT || bt2 == Variant::BOOL || bt2 == Variant::NIL);
                    if (an2 && bn2) {
                        push_value(to_double(av2) - to_double(bv2));
                    } else {
                        Variant res2; bool ok2 = false;
                        Variant::evaluate(Variant::OP_SUBTRACT, av2, bv2, res2, ok2);
                        if (!ok2) { success = false; goto cleanup; }
                        push_value(res2);
                    }
                }
                break;
            }
            VG_CASE(vg_op_mul_f64, OP_MUL_F64): {
                if (!ensure_stack(2)) {
                    success = false;
                    goto cleanup;
                }
                Variant bv = pop_value();
                Variant av = pop_value();
                // Only use fast float path for numeric types; fall back to
                // generic Variant::evaluate for Vector2, Color, etc.
                Variant::Type at = av.get_type();
                Variant::Type bt = bv.get_type();
                bool a_numeric = (at == Variant::INT || at == Variant::FLOAT || at == Variant::BOOL || at == Variant::NIL);
                bool b_numeric = (bt == Variant::INT || bt == Variant::FLOAT || bt == Variant::BOOL || bt == Variant::NIL);
                if (a_numeric && b_numeric) {
                    push_value(to_double(av) * to_double(bv));
                } else {
                    Variant result;
                    bool valid = false;
                    Variant::evaluate(Variant::OP_MULTIPLY, av, bv, result, valid);
                    if (!valid) {
                        // Report and bail
                        static int mul_err_count = 0;
                        static uint64_t mul_err_time = 0;
                        uint64_t now2 = Time::get_singleton()->get_ticks_msec();
                        mul_err_count++;
                        if (now2 - mul_err_time > 1000) {
                            UtilityFunctions::printerr("VisualGasic: MUL_F64 fallback failed Op:8 TypeA:", (int)at, " TypeB:", (int)bt, " line:", debug_state.current_line);
                            mul_err_time = now2;
                            mul_err_count = 0;
                        }
                        success = false;
                        goto cleanup;
                    }
                    push_value(result);
                }
                break;
            }
            VG_CASE(vg_op_div_f64, OP_DIV_F64): {
                if (!ensure_stack(2)) {
                    success = false;
                    goto cleanup;
                }
                {
                    Variant bv3 = pop_value();
                    Variant av3 = pop_value();
                    Variant::Type at3 = av3.get_type(), bt3 = bv3.get_type();
                    bool an3 = (at3 == Variant::INT || at3 == Variant::FLOAT || at3 == Variant::BOOL || at3 == Variant::NIL);
                    bool bn3 = (bt3 == Variant::INT || bt3 == Variant::FLOAT || bt3 == Variant::BOOL || bt3 == Variant::NIL);
                    if (an3 && bn3) {
                        double b3 = to_double(bv3);
                        if (b3 == 0.0) {
                            raise_error("Division by zero", 11);
                            if (try_recover_error(Variant(0.0))) break;
                            success = false;
                            goto cleanup;
                        }
                        push_value(to_double(av3) / b3);
                    } else {
                        Variant res3; bool ok3 = false;
                        Variant::evaluate(Variant::OP_DIVIDE, av3, bv3, res3, ok3);
                        if (!ok3) { success = false; goto cleanup; }
                        push_value(res3);
                    }
                }
                break;
            }
            VG_CASE(vg_op_add_i64_const, OP_ADD_I64_CONST): {
                if (vm.ip + 1 >= code_size) { success = false; goto cleanup; }
                int idx = read_const_index();
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                pop_value(); // discard literal operand on stack
                int64_t a;
                {
                    const Variant &av = vm.stack[vm.stack.size() - 1];
                    a = (av.get_type() == Variant::INT) ? (int64_t)av : (int64_t)((double)av);
                    vm.stack.pop_back();
                }
                int64_t c;
                {
                    const Variant &cv = read_constant(idx);
                    c = (cv.get_type() == Variant::INT) ? (int64_t)cv : (int64_t)((double)cv);
                }
                push_value((int64_t)(a + c));
                break;
            }
            VG_CASE(vg_op_sub_i64_const, OP_SUB_I64_CONST): {
                if (vm.ip + 1 >= code_size) { success = false; goto cleanup; }
                int idx = read_const_index();
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                pop_value();
                int64_t a;
                {
                    const Variant &av = vm.stack[vm.stack.size() - 1];
                    a = (av.get_type() == Variant::INT) ? (int64_t)av : (int64_t)((double)av);
                    vm.stack.pop_back();
                }
                int64_t c;
                {
                    const Variant &cv = read_constant(idx);
                    c = (cv.get_type() == Variant::INT) ? (int64_t)cv : (int64_t)((double)cv);
                }
                push_value((int64_t)(a - c));
                break;
            }
            VG_CASE(vg_op_mul_i64_const, OP_MUL_I64_CONST): {
                if (vm.ip + 1 >= code_size) { success = false; goto cleanup; }
                int idx = read_const_index();
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                pop_value();
                int64_t a;
                {
                    const Variant &av = vm.stack[vm.stack.size() - 1];
                    a = (av.get_type() == Variant::INT) ? (int64_t)av : (int64_t)((double)av);
                    vm.stack.pop_back();
                }
                int64_t c;
                {
                    const Variant &cv = read_constant(idx);
                    c = (cv.get_type() == Variant::INT) ? (int64_t)cv : (int64_t)((double)cv);
                }
                push_value((int64_t)(a * c));
                break;
            }
            VG_CASE(vg_op_add_local_i64_stack, OP_ADD_LOCAL_I64_STACK): {
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t slot = code[vm.ip++];
                int64_t delta = to_int(pop_value());
                int64_t base = read_local_i64(slot);
                int64_t result = base + delta;
                sync_local_i64(slot, result);
                break;
            }
            VG_CASE(vg_op_sub_local_i64_stack, OP_SUB_LOCAL_I64_STACK): {
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t slot = code[vm.ip++];
                int64_t delta = to_int(pop_value());
                int64_t base = read_local_i64(slot);
                sync_local_i64(slot, base - delta);
                break;
            }
            VG_CASE(vg_op_add_local_i64_const, OP_ADD_LOCAL_I64_CONST): {
                if (vm.ip + 2 >= code_size) { success = false; goto cleanup; }
                uint8_t slot = code[vm.ip++];
                int idx = read_const_index();
                int64_t base = read_local_i64(slot);
                sync_local_i64(slot, base + to_int(read_constant(idx)));
                break;
            }
            VG_CASE(vg_op_sub_local_i64_const, OP_SUB_LOCAL_I64_CONST): {
                if (vm.ip + 2 >= code_size) { success = false; goto cleanup; }
                uint8_t slot = code[vm.ip++];
                int idx = read_const_index();
                int64_t base = read_local_i64(slot);
                sync_local_i64(slot, base - to_int(read_constant(idx)));
                break;
            }
            VG_CASE(vg_op_inc_local_i64, OP_INC_LOCAL_I64): {
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t slot = code[vm.ip++];
                int64_t base = read_local_i64(slot);
                sync_local_i64(slot, base + 1);
                break;
            }
            VG_CASE(vg_op_accum_i64_muladd_const, OP_ACCUM_I64_MULADD_CONST): {
                // [OP] [S_SLOT] [J_SLOT] [K_CONST(2)]
                // locals[s] += locals[j] * K
                if (vm.ip + 3 >= code_size) { success = false; goto cleanup; }
                uint8_t s_slot = code[vm.ip++];
                uint8_t j_slot = code[vm.ip++];
                int k_idx  = read_const_index();
                int64_t s_val = read_local_i64(s_slot);
                int64_t j_val = read_local_i64(j_slot);
                int64_t k_val = to_int(read_constant(k_idx));
                sync_local_i64(s_slot, s_val + j_val * k_val);
                break;
            }
            VG_CASE(vg_op_arith_sum, OP_ARITH_SUM): {
                if (vm.ip + 3 >= code_size) { success = false; goto cleanup; }
                int k_idx = read_const_index();
                int c_idx = read_const_index();
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
                if (vm.stack.size() >= 2) {
                    const Variant &bv = vm.stack[vm.stack.size() - 1];
                    const Variant &av = vm.stack[vm.stack.size() - 2];
                    int64_t b = (bv.get_type() == Variant::INT) ? (int64_t)bv : (int64_t)((double)bv);
                    int64_t a = (av.get_type() == Variant::INT) ? (int64_t)av : (int64_t)((double)av);
                    vm.stack.pop_back();
                    vm.stack.pop_back();
                    push_value(a == b);
                } else { success = false; goto cleanup; }
                break;
            }
            VG_CASE(vg_op_not_equal_i64, OP_NOT_EQUAL_I64): {
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                if (vm.stack.size() >= 2) {
                    const Variant &bv = vm.stack[vm.stack.size() - 1];
                    const Variant &av = vm.stack[vm.stack.size() - 2];
                    int64_t b = (bv.get_type() == Variant::INT) ? (int64_t)bv : (int64_t)((double)bv);
                    int64_t a = (av.get_type() == Variant::INT) ? (int64_t)av : (int64_t)((double)av);
                    vm.stack.pop_back();
                    vm.stack.pop_back();
                    push_value(a != b);
                } else { success = false; goto cleanup; }
                break;
            }
            VG_CASE(vg_op_less_equal_i64, OP_LESS_EQUAL_I64): {
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                if (vm.stack.size() >= 2) {
                    const Variant &bv = vm.stack[vm.stack.size() - 1];
                    const Variant &av = vm.stack[vm.stack.size() - 2];
                    int64_t b = (bv.get_type() == Variant::INT) ? (int64_t)bv : (int64_t)((double)bv);
                    int64_t a = (av.get_type() == Variant::INT) ? (int64_t)av : (int64_t)((double)av);
                    vm.stack.pop_back();
                    vm.stack.pop_back();
                    push_value(a <= b);
                } else { success = false; goto cleanup; }
                break;
            }
            VG_CASE(vg_op_not, OP_NOT): {
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                push_value(!to_bool(pop_value()));
                break;
            }
            VG_CASE(vg_op_and, OP_AND): {
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                Variant b = pop_value();
                Variant a = pop_value();
                // VB6: bitwise when both operands are numeric, logical otherwise
                if ((a.get_type() == Variant::INT || a.get_type() == Variant::FLOAT) &&
                    (b.get_type() == Variant::INT || b.get_type() == Variant::FLOAT)) {
                    push_value(Variant((int64_t)a & (int64_t)b));
                } else {
                    push_value(to_bool(a) && to_bool(b));
                }
                break;
            }
            VG_CASE(vg_op_or, OP_OR): {
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                Variant b = pop_value();
                Variant a = pop_value();
                if ((a.get_type() == Variant::INT || a.get_type() == Variant::FLOAT) &&
                    (b.get_type() == Variant::INT || b.get_type() == Variant::FLOAT)) {
                    push_value(Variant((int64_t)a | (int64_t)b));
                } else {
                    push_value(to_bool(a) || to_bool(b));
                }
                break;
            }
            VG_CASE(vg_op_xor, OP_XOR): {
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                Variant b = pop_value();
                Variant a = pop_value();
                if ((a.get_type() == Variant::INT || a.get_type() == Variant::FLOAT) &&
                    (b.get_type() == Variant::INT || b.get_type() == Variant::FLOAT)) {
                    push_value(Variant((int64_t)a ^ (int64_t)b));
                } else {
                    bool ab = to_bool(a);
                    bool bb = to_bool(b);
                    push_value((ab && !bb) || (!ab && bb));
                }
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
                if (vm.ip + 2 >= code_size) { success = false; goto cleanup; }
                int name_idx = read_const_index();
                uint8_t arg_count = code[vm.ip++];
                if (!ensure_stack(arg_count)) { success = false; goto cleanup; }
                Array args;
                args.resize(arg_count);
                for (int i = arg_count - 1; i >= 0; i--) {
                    args[i] = pop_value();
                }
                String method = read_constant(name_idx);
                {
                    vgjit3::Tier3& t3 = vgjit3::thread_jit3();
                    if (t3.enabled() && func && !method.is_empty()) {
                        std::string caller_name(func->name.utf8().get_data());
                        std::string callee_name(method.utf8().get_data());
                        if (!caller_name.empty() && !callee_name.empty()) {
                            t3.record_call(caller_name, callee_name);
                        }
                    }
                }

                bool handled = false;
                Variant call_ret;

                // ── Part B: skip the builtin + special-case cascades for calls
                // already resolved as user Subs (perf) ──
                // call_internal() — and therefore a _call_resolution_cache entry
                // for this (name, arg count) — is reached ONLY when BOTH cascades
                // below returned handled=false.  Both cascades are pure functions
                // of (method name, arg count): call_builtin_expr_evaluated() sets
                // r_handled solely on name + args.size() (verified: never on arg
                // type/value), and the special cascade matches on name alone.  So
                // a cached "resolved user Sub" entry proves both cascades will miss
                // again for this exact (name, arg count) — skip them and dispatch
                // straight to call_internal().  This removes the 449-entry builtin
                // strcmp cascade plus its per-call lowercase/utf8 setup (10.30% of
                // total C64-emulator runtime, per perf) from every hot user-Sub
                // call.  The key format matches call_internal()'s own _res_key.
                String _method_lower = method.to_lower();
                String _pc_res_key = _method_lower + "#" + String::num_int64(arg_count);
                bool _pb_known_user_sub = false;
                bool _pc_engine_call = false;   // Part C: cached deep-fallback call (statement builtin / owner method)
                {
                    if (_call_resolution_cache.has(_pc_res_key)) {
                        const CallResolutionCacheEntry &_pb_cached = _call_resolution_cache[_pc_res_key];
                        if (_pb_cached.resolved) _pb_known_user_sub = true;
                    }
                    // Part C: (name, arg count) pairs proven to resolve only at the
                    // deep fallback — statement/drawing builtins (SetImagePixel,
                    // BlitImage, …) or owner-node methods — skip the builtin-expr
                    // cascade + the variables.keys() case-insensitive scan below.
                    // Same determinism argument as Part B: call_builtin_expr_evaluated
                    // and the special cascade are pure functions of (name, arg count),
                    // so a proven deep-fallback resolution repeats.  Restricted to
                    // module-level context (current_object_id == -1) so in-class
                    // sibling-method resolution in call_internal() is never bypassed.
                    if (!_pb_known_user_sub && current_object_id == -1 &&
                        _engine_call_cache.has(_pc_res_key)) {
                        _pc_engine_call = true;
                    }
                }

                if (!_pb_known_user_sub && !_pc_engine_call) {
                call_ret = VisualGasicBuiltins::call_builtin_expr_evaluated(this, method, args, handled);

                // ── Special-case engine-method cascade gate (perf) ──
                // The ~17 checks below (Array/GetNode/Vector2/Load/CreateTween/
                // IsOnFloor/IsOnWall/MoveAndSlide/SetVelocity/GetCollisionCount/
                // GetAxis/IsAction*/Connect/Sleep/Kill) each construct a String
                // from a literal, do a case-insensitive compare, then destruct.
                // A normal user-Sub call — the hot path in call-heavy code
                // (emulators, interpreters, recursive algorithms) — matches NONE
                // of them, yet paid all 17 String-construct+compare+destruct ops
                // on EVERY call (16.35% of total C64-emulator runtime, per perf).
                // Gate the whole cascade behind one lowercased-name HashSet
                // lookup so user-Sub calls skip it entirely.  Semantically
                // identical: the inner nocasecmp_to checks are only reachable
                // when the name IS one of these special names, and only one can
                // ever match a given name.  C++11 guarantees the function-local
                // static is initialised exactly once, thread-safely (matters for
                // Parallel-For worker threads that reach this OP_CALL).
                static const HashSet<String> _vg_special_call_names = []() {
                    HashSet<String> s;
                    const char *names[] = {
                        "array", "getnode", "vector2", "load", "createtween",
                        "isonfloor", "isonwall", "moveandslide", "setvelocity",
                        "getcollisioncount", "getaxis", "isactionpressed",
                        "isactionjustpressed", "isactionjustreleased", "connect",
                        "sleep", "kill"
                    };
                    for (const char *n : names) s.insert(String(n));
                    return s;
                }();
                if (!handled && _vg_special_call_names.has(_method_lower)) {

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

                // Connect(source, signal, method) — 3-arg unqualified form
                // Matches the AST interpreter's explicit Connect handler.
                if (!handled && method.nocasecmp_to("Connect") == 0 && args.size() == 3) {
                    Object *source = args[0];
                    String sig = args[1];
                    String target = args[2];
                    if (source && owner) {
                        if (source->has_signal(sig)) {
                            Callable callable = Callable(owner, target);
                            if (!source->is_connected(sig, callable)) {
                                Error err = source->connect(sig, callable);
                                call_ret = (int)err;
                            } else {
                                call_ret = (int64_t)0;
                            }
                        } else {
                            UtilityFunctions::print("Runtime Warning: Signal '", sig, "' not found on object");
                            call_ret = (int64_t)0;
                        }
                    } else {
                        call_ret = (int64_t)0;
                    }
                    handled = true;
                }

                // Sleep(ms) — block the calling thread for N milliseconds.
                // Mirror the AST interpreter handler (execute.inc ~1006).
                if (!handled && method.nocasecmp_to("Sleep") == 0 && args.size() == 1) {
                    int ms = (int)(int64_t)args[0];
                    if (ms > 0) OS::get_singleton()->delay_msec(ms);
                    call_ret = Variant();
                    handled = true;
                }

                // Kill <path> — VB6 file/symlink delete. Mirror the AST
                // interpreter handler in visual_gasic_instance_execute.inc
                // so bytecode-compiled subs delete files too. Falls back to
                // raw POSIX unlink / Win32 DeleteFile when Godot's
                // DirAccess::remove_absolute() can't handle symlinks.
                if (!handled && method.nocasecmp_to("Kill") == 0 && args.size() == 1) {
                    String path = args[0];
                    bool is_abs = path.begins_with("res://") || path.begins_with("user://")
                               || path.begins_with("/")
                               || (path.length() >= 2 && path[1] == ':');
                    if (!is_abs) path = "user://" + path;
                    Error err = DirAccess::remove_absolute(path);
                    if (err != Error::OK) {
#if defined(__linux__) || defined(__APPLE__) || defined(__unix__)
                        CharString utf8 = path.utf8();
                        if (::unlink(utf8.get_data()) != 0) {
                            raise_error("File not found: " + path, 53);
                        }
#elif defined(_WIN32)
                        CharString utf8 = path.utf8();
                        if (!DeleteFileA(utf8.get_data())) {
                            raise_error("File not found: " + path, 53);
                        }
#else
                        raise_error("File not found: " + path, 53);
#endif
                    }
                    call_ret = Variant();
                    handled = true;
                }

                }  // end special-case engine-method cascade gate

                }  // end Part B: skip builtin+special cascades for cached user Subs

                if (!handled) {
                    bool found = false;
                    if (!_pc_engine_call) {
                        call_ret = call_internal(method, args, found);
                    }
                    if (!found) {
                        // Check if this is a variable used as array/dict index or lambda
                        // (matches AST interpreter's CallExpression → variable fallback).
                        // Must search BOTH the variables[] dict AND the local slot
                        // array, because the fast-path (needs_var_sync==false) does
                        // NOT sync locals into variables[].
                        Variant v;
                        bool have_var = false;
                        if (variables.has(method)) {
                            v = variables[method];
                            have_var = true;
                        }
                        // Case-insensitive fallback: VB identifiers are
                        // case-insensitive, but Dictionary keys are not.
                        // Part C: skip this O(n) variables.keys() scan for names
                        // already proven to be deep-fallback engine/statement calls.
                        if (!have_var && !_pc_engine_call) {
                            Array keys = variables.keys();
                            for (int ki = 0; ki < keys.size(); ki++) {
                                String k = keys[ki];
                                if (k.nocasecmp_to(method) == 0) {
                                    v = variables[k];
                                    have_var = true;
                                    break;
                                }
                            }
                        }
                        if (!have_var) {
                            for (int li = 0; li < chunk->local_names.size() && li < locals.size(); li++) {
                                if (chunk->local_names[li].nocasecmp_to(method) == 0) {
                                    v = locals[li];
                                    have_var = true;
                                    break;
                                }
                            }
                        }
                        if (have_var) {
                            if (v.get_type() == Variant::ARRAY) {
                                // Array indexing: arr(idx) → arr[idx]
                                Variant current = v;
                                bool fail = false;
                                for (int ai = 0; ai < args.size(); ai++) {
                                    if (current.get_type() != Variant::ARRAY) {
                                        fail = true;
                                        break;
                                    }
                                    Array arr = current;
                                    int idx = args[ai];
                                    if (idx >= 0 && idx < arr.size()) {
                                        current = arr[idx];
                                    } else {
                                        raise_error("Subscript out of range", 9);
                                        if (try_recover_error(Variant())) {
                                            current = Variant();
                                            fail = true;
                                        } else {
                                            success = false;
                                            goto cleanup;
                                        }
                                    }
                                }
                                if (!fail) {
                                    call_ret = current;
                                    found = true;
                                }
                            } else if (v.get_type() == Variant::DICTIONARY) {
                                Dictionary d = v;
                                if (d.has("__vg_lambda") && (bool)d["__vg_lambda"]) {
                                    call_ret = invoke_lambda(d, args);
                                    found = true;
                                } else if (args.size() == 1) {
                                    // Dictionary indexing: dict(key) → dict[key]
                                    call_ret = d.get(args[0], Variant());
                                    found = true;
                                }
                            } else if (v.get_type() >= Variant::PACKED_BYTE_ARRAY && v.get_type() <= Variant::PACKED_COLOR_ARRAY) {
                                // Packed array indexing
                                if (args.size() == 1) {
                                    int idx = args[0];
                                    bool valid = false;
                                    bool oob = false;
                                    Variant res = v.get_indexed(idx, valid, oob);
                                    if (oob) {
                                        raise_error("Subscript out of range", 9);
                                        if (!try_recover_error(Variant())) {
                                            success = false;
                                            goto cleanup;
                                        }
                                    } else if (valid) {
                                        call_ret = res;
                                        found = true;
                                    }
                                }
                            }
                        } // have_var
                        if (!found) {
                            bool stmt_found = false;
                            dispatch_builtin_call(method, args, stmt_found);
                            bool _pc_resolved_deep = stmt_found;
                            if (!stmt_found && owner) {
                                // Fallback: try calling the method on the owner node
                                // (matches AST interpreter's STMT_CALL fallback at end)
                                if (owner->has_method(method)) {
                                    call_ret = owner->callv(method, args);
                                    _pc_resolved_deep = true;
                                } else {
                                    String snake = method.to_snake_case();
                                    if (owner->has_method(snake)) {
                                        call_ret = owner->callv(snake, args);
                                        _pc_resolved_deep = true;
                                    } else {
                                        raise_error("Sub or Function not defined: " + method, 35);
                                        if (try_recover_error(Variant())) {
                                            call_ret = Variant();
                                        } else {
                                            success = false;
                                            goto cleanup;
                                        }
                                    }
                                }
                            } else if (!stmt_found) {
                                raise_error("Sub or Function not defined: " + method, 35);
                                if (try_recover_error(Variant())) {
                                    call_ret = Variant();
                                } else {
                                    success = false;
                                    goto cleanup;
                                }
                            }
                            // ── Part C: cache this (name, arg count) as a deep
                            // engine/statement call so subsequent calls skip the
                            // builtin-expr cascade + the variables.keys() scan.
                            // Only when it actually resolved here (not the
                            // undefined-name error path) and only at module-level
                            // scope, so class sibling-method calls are unaffected.
                            if (_pc_resolved_deep && !_pc_engine_call && current_object_id == -1) {
                                _engine_call_cache.insert(_pc_res_key);
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
                    // Array::fill() is a single GDExtension call that zero-fills
                    // all elements in one shot — ~100× faster than a per-element
                    // Variant assignment loop for large arrays (>= 1000 elements).
                    if (length > 0) arr.fill((int64_t)0);
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
                } else if (base.get_type() == Variant::PACKED_STRING_ARRAY && arg_count == 1) {
                    PackedStringArray psa = base;
                    int idx = (int)to_int(indices[0]);
                    if (idx < 0 || idx >= psa.size()) {
                        if (op == OP_GET_ARRAY_UNCHECKED) {
                            result = Variant();
                        } else {
                            raise_error("Array subscript out of range", 9);
                            if (try_recover_error(Variant())) break;
                            success = false;
                            goto cleanup;
                        }
                    } else {
                        result = psa[idx];
                    }
                } else if (base.get_type() == Variant::PACKED_INT64_ARRAY && arg_count == 1) {
                    PackedInt64Array arr = base;
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
                        result = Variant((int64_t)arr[idx]);
                    }
                } else if (base.get_type() == Variant::PACKED_FLOAT64_ARRAY && arg_count == 1) {
                    PackedFloat64Array arr = base;
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
                        result = Variant(arr[idx]);
                    }
                } else if (base.get_type() == Variant::PACKED_FLOAT32_ARRAY && arg_count == 1) {
                    PackedFloat32Array arr = base;
                    int idx = (int)to_int(indices[0]);
                    if (idx < 0 || idx >= arr.size()) {
                        if (op == OP_GET_ARRAY_UNCHECKED) { result = Variant(); }
                        else { raise_error("Array subscript out of range", 9); if (try_recover_error(Variant())) break; success = false; goto cleanup; }
                    } else {
                        result = Variant((double)arr[idx]);
                    }
                } else if (base.get_type() == Variant::PACKED_INT32_ARRAY && arg_count == 1) {
                    PackedInt32Array arr = base;
                    int idx = (int)to_int(indices[0]);
                    if (idx < 0 || idx >= arr.size()) {
                        if (op == OP_GET_ARRAY_UNCHECKED) { result = Variant(); }
                        else { raise_error("Array subscript out of range", 9); if (try_recover_error(Variant())) break; success = false; goto cleanup; }
                    } else {
                        result = Variant((int64_t)arr[idx]);
                    }
                } else if (base.get_type() == Variant::PACKED_BYTE_ARRAY && arg_count == 1) {
                    PackedByteArray arr = base;
                    int idx = (int)to_int(indices[0]);
                    if (idx < 0 || idx >= arr.size()) {
                        if (op == OP_GET_ARRAY_UNCHECKED) { result = Variant(); }
                        else { raise_error("Array subscript out of range", 9); if (try_recover_error(Variant())) break; success = false; goto cleanup; }
                    } else {
                        result = Variant((int64_t)arr[idx]);
                    }
                } else if (base.get_type() == Variant::DICTIONARY && arg_count == 1) {
                    Dictionary dict = base;
                    result = dict.get(indices[0], Variant());
                } else if (base.get_type() == Variant::OBJECT && arg_count == 1) {
                    // v4.4.0: module-level/global MemoryBuffer vars stay as a real
                    // VGMemoryBuffer Object (only local-slot buffer vars use the
                    // PackedByteArray fast path) — support buf(offset) reads on it too.
                    Object *obj = base;
                    VGMemoryBuffer *mb = Object::cast_to<VGMemoryBuffer>(obj);
                    if (mb) {
                        result = Variant((int64_t)mb->peek_byte((int64_t)to_int(indices[0])));
                    } else {
                        raise_error("Unsupported array base type");
                        if (try_recover_error(Variant())) break;
                        success = false;
                        goto cleanup;
                    }
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
                if (base.get_type() == Variant::PACKED_STRING_ARRAY) {
                    // Convert PackedStringArray to Array for uniform handling
                    PackedStringArray psa = base;
                    Array converted;
                    converted.resize(psa.size());
                    for (int i = 0; i < psa.size(); i++) { converted[i] = psa[i]; }
                    base = converted;
                }
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
                } else if (base.get_type() == Variant::PACKED_INT64_ARRAY && arg_count == 1) {
                    PackedInt64Array arr = base;
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
                        arr[idx] = (int64_t)to_int(value);
                        updated = arr;
                    }
                } else if (base.get_type() == Variant::PACKED_FLOAT64_ARRAY && arg_count == 1) {
                    PackedFloat64Array arr = base;
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
                        arr[idx] = (double)value;
                        updated = arr;
                    }
                } else if (base.get_type() == Variant::PACKED_BYTE_ARRAY && arg_count == 1) {
                    PackedByteArray arr = base;
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
                        arr.set(idx, (uint8_t)to_int(value));
                        updated = arr;
                    }
                } else if (base.get_type() == Variant::OBJECT && arg_count == 1) {
                    // v4.4.0: module-level/global MemoryBuffer vars (see OP_GET_ARRAY
                    // comment above) — support buf(offset) = value writes on it too.
                    Object *obj = base;
                    VGMemoryBuffer *mb = Object::cast_to<VGMemoryBuffer>(obj);
                    if (mb) {
                        mb->poke_byte((int64_t)to_int(indices[0]), (int)to_int(value));
                        // The Object is reference-counted; no need to push a modified
                        // copy back onto the stack the way value-type arrays require —
                        // but the caller always expects a value after this opcode, so
                        // just push the (unchanged) base back.
                        updated = base;
                    } else {
                        raise_error("Unsupported array assignment base");
                        if (try_recover_error(base)) break;
                        success = false;
                        goto cleanup;
                    }
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
                int slot_or_idx;
                if (op == OP_SET_DICT_LOCAL) {
                    if (vm.ip >= code_size) { success = false; goto cleanup; }
                    slot_or_idx = code[vm.ip++];
                } else {
                    if (vm.ip + 1 >= code_size) { success = false; goto cleanup; }
                    slot_or_idx = read_const_index();
                }
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
                if (vm.ip + 6 >= code_size) { success = false; goto cleanup; }
                uint8_t sum_slot = code[vm.ip++];
                uint8_t arr_slot = code[vm.ip++];
                uint8_t tmp_slot = code[vm.ip++];
                int lit_idx = read_const_index();
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
                if (vm.ip + 1 >= code_size) { success = false; goto cleanup; }
                int idx = read_const_index();
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
                    String member = cache.primary_string;
                    if (member.nocasecmp_to("Count") == 0) result = dict->size();
                    else if (member.nocasecmp_to("Keys") == 0) result = dict->keys();
                    else if (member.nocasecmp_to("Items") == 0 || member.nocasecmp_to("Values") == 0) result = dict->values();
                    else result = dict->get(cache.primary_string, Variant());
                } else if (base.get_type() == Variant::ARRAY) {
                    const Array *arr = VariantInternal::get_array(&base);
                    String member = cache.primary_string;
                    if (member.nocasecmp_to("Count") == 0 || member.nocasecmp_to("Length") == 0)
                        result = (int64_t)arr->size();
                    else result = Variant();
                } else if (base.get_type() == Variant::PACKED_INT64_ARRAY ||
                           base.get_type() == Variant::PACKED_FLOAT64_ARRAY ||
                           base.get_type() == Variant::PACKED_STRING_ARRAY ||
                           base.get_type() == Variant::PACKED_INT32_ARRAY ||
                           base.get_type() == Variant::PACKED_FLOAT32_ARRAY) {
                    String member = cache.primary_string;
                    if (member.nocasecmp_to("Count") == 0 || member.nocasecmp_to("Length") == 0) {
                        int sz = 0;
                        if (base.get_type() == Variant::PACKED_INT64_ARRAY) sz = VariantInternal::get_int64_array(&base)->size();
                        else if (base.get_type() == Variant::PACKED_FLOAT64_ARRAY) sz = VariantInternal::get_float64_array(&base)->size();
                        else if (base.get_type() == Variant::PACKED_STRING_ARRAY) sz = VariantInternal::get_string_array(&base)->size();
                        else if (base.get_type() == Variant::PACKED_INT32_ARRAY) sz = VariantInternal::get_int32_array(&base)->size();
                        else if (base.get_type() == Variant::PACKED_FLOAT32_ARRAY) sz = VariantInternal::get_float32_array(&base)->size();
                        result = (int64_t)sz;
                    } else result = Variant();
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
                } else if (base.get_type() == Variant::QUATERNION) {
                    // Pass 1: Quaternion.x/y/z/w
                    Quaternion q = base;
                    String member = cache.primary_string.to_lower();
                    if (member == "x") result = q.x;
                    else if (member == "y") result = q.y;
                    else if (member == "z") result = q.z;
                    else if (member == "w") result = q.w;
                } else if (base.get_type() == Variant::PLANE) {
                    // Pass 1: Plane.normal / .d / .x / .y / .z
                    Plane pl = base;
                    String member = cache.primary_string.to_lower();
                    if (member == "normal") result = pl.normal;
                    else if (member == "d") result = pl.d;
                    else if (member == "x") result = pl.normal.x;
                    else if (member == "y") result = pl.normal.y;
                    else if (member == "z") result = pl.normal.z;
                } else if (base.get_type() == Variant::AABB) {
                    // Pass 1: AABB.position / .size / .end
                    AABB box = base;
                    String member = cache.primary_string.to_lower();
                    if (member == "position") result = box.position;
                    else if (member == "size") result = box.size;
                    else if (member == "end") result = box.get_end();
                } else if (base.get_type() == Variant::TRANSFORM2D) {
                    // Pass 1: Transform2D.origin / .x / .y (basis columns)
                    Transform2D t = base;
                    String member = cache.primary_string.to_lower();
                    if (member == "origin") result = t.get_origin();
                    else if (member == "x") result = t.columns[0];
                    else if (member == "y") result = t.columns[1];
                } else if (base.get_type() == Variant::TRANSFORM3D) {
                    // Pass 1: Transform3D.origin / .basis
                    Transform3D t = base;
                    String member = cache.primary_string.to_lower();
                    if (member == "origin") result = t.origin;
                    else if (member == "basis") result = t.basis;
                } else if (base.get_type() == Variant::BASIS) {
                    // Pass 1: Basis.x / .y / .z (rows)
                    Basis b = base;
                    String member = cache.primary_string.to_lower();
                    if (member == "x") result = b.rows[0];
                    else if (member == "y") result = b.rows[1];
                    else if (member == "z") result = b.rows[2];
                } else if (base.get_type() == Variant::VECTOR4) {
                    // Pass 1: Vector4.x/y/z/w
                    Vector4 v = base;
                    String member = cache.primary_string.to_lower();
                    if (member == "x") result = v.x;
                    else if (member == "y") result = v.y;
                    else if (member == "z") result = v.z;
                    else if (member == "w") result = v.w;
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
                            // If obj is a Window (form root), target _FormBackground Panel child
                            if (!ctrl) {
                                Window *win = Object::cast_to<Window>(obj);
                                if (win) {
                                    Node *bg = win->find_child("_FormBackground", false, false);
                                    if (bg) ctrl = Object::cast_to<Control>(bg);
                                }
                            }
                            if (ctrl) {
                                String sb_name = (ctrl->get_class() == "Panel") ? "panel" : "normal";
                                Ref<StyleBox> sb = ctrl->get_theme_stylebox(sb_name);
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
                        // ---- Font properties ----
                        // FontBold → theme font override embolden > 0
                        else if (prop_name == "FontBold") {
                            Control *ctrl = Object::cast_to<Control>(obj);
                            if (ctrl) {
                                Ref<Font> fnt = ctrl->get_theme_font("font");
                                if (fnt.is_valid()) {
                                    Ref<FontVariation> fv = fnt;
                                    if (fv.is_valid()) {
                                        result = fv->get_variation_embolden() > 0.0f;
                                    } else {
                                        Ref<SystemFont> sf = fnt;
                                        if (sf.is_valid()) {
                                            PackedStringArray names = sf->get_font_names();
                                            // Heuristic: check if name contains "Bold"
                                            for (int fi = 0; fi < names.size(); fi++) {
                                                if (String(names[fi]).findn("Bold") >= 0) { result = true; break; }
                                            }
                                            if (result.get_type() == Variant::NIL) result = false;
                                        } else {
                                            result = false;
                                        }
                                    }
                                } else {
                                    result = false;
                                }
                                handled = true;
                            }
                        }
                        // FontItalic → theme font override variation_transform skew
                        else if (prop_name == "FontItalic") {
                            Control *ctrl = Object::cast_to<Control>(obj);
                            if (ctrl) {
                                Ref<Font> fnt = ctrl->get_theme_font("font");
                                if (fnt.is_valid()) {
                                    Ref<FontVariation> fv = fnt;
                                    if (fv.is_valid()) {
                                        Transform2D t = fv->get_variation_transform();
                                        result = (t[0][1] != 0.0f); // skew indicates italic
                                    } else {
                                        Ref<SystemFont> sf = fnt;
                                        if (sf.is_valid()) {
                                            result = sf->get_font_italic();
                                        } else {
                                            result = false;
                                        }
                                    }
                                } else {
                                    result = false;
                                }
                                handled = true;
                            }
                        }
                        // FontName → system font family name
                        else if (prop_name == "FontName") {
                            Control *ctrl = Object::cast_to<Control>(obj);
                            if (ctrl) {
                                Ref<Font> fnt = ctrl->get_theme_font("font");
                                if (fnt.is_valid()) {
                                    Ref<FontVariation> fv = fnt;
                                    if (fv.is_valid()) {
                                        Ref<Font> base = fv->get_base_font();
                                        Ref<SystemFont> sf = base;
                                        if (sf.is_valid()) {
                                            PackedStringArray names = sf->get_font_names();
                                            result = names.size() > 0 ? String(names[0]) : String("");
                                        } else {
                                            result = String("");
                                        }
                                    } else {
                                        Ref<SystemFont> sf = fnt;
                                        if (sf.is_valid()) {
                                            PackedStringArray names = sf->get_font_names();
                                            result = names.size() > 0 ? String(names[0]) : String("");
                                        } else {
                                            result = String("");
                                        }
                                    }
                                } else {
                                    result = String("");
                                }
                                handled = true;
                            }
                        }
                        // FontUnderline → stored as meta (Godot has no native underline on Control fonts)
                        else if (prop_name == "FontUnderline") {
                            result = obj->has_meta("vg_font_underline") ? (bool)obj->get_meta("vg_font_underline") : false;
                            handled = true;
                        }
                        // FontStrikethrough → stored as meta
                        else if (prop_name == "FontStrikethrough") {
                            result = obj->has_meta("vg_font_strikethrough") ? (bool)obj->get_meta("vg_font_strikethrough") : false;
                            handled = true;
                        }
                        // ---- Border / Appearance ----
                        // BorderStyle → 0=None, 1=FixedSingle (check if stylebox has border)
                        else if (prop_name == "BorderStyle") {
                            Control *ctrl = Object::cast_to<Control>(obj);
                            if (ctrl) {
                                Ref<StyleBox> sb = ctrl->get_theme_stylebox("normal");
                                Ref<StyleBoxFlat> sbf = sb;
                                if (sbf.is_valid()) {
                                    // If any border width > 0 → FixedSingle (1)
                                    result = (sbf->get_border_width(SIDE_LEFT) > 0 ||
                                              sbf->get_border_width(SIDE_TOP) > 0 ||
                                              sbf->get_border_width(SIDE_RIGHT) > 0 ||
                                              sbf->get_border_width(SIDE_BOTTOM) > 0) ? 1 : 0;
                                } else {
                                    result = 0;
                                }
                                handled = true;
                            }
                        }
                        // Style / Flat → Button.flat
                        else if (prop_name == "Style" || prop_name == "Flat") {
                            Button *btn = Object::cast_to<Button>(obj);
                            if (btn) {
                                result = btn->is_flat();
                                handled = true;
                            }
                        }
                        // ---- TextBox-specific ----
                        // MultiLine → true if the control IS a TextEdit (vs LineEdit)
                        else if (prop_name == "MultiLine") {
                            TextEdit *te = Object::cast_to<TextEdit>(obj);
                            result = (te != nullptr);
                            handled = true;
                        }
                        // ScrollBars → TextEdit scroll settings (0=None,1=Horiz,2=Vert,3=Both)
                        else if (prop_name == "ScrollBars") {
                            TextEdit *te = Object::cast_to<TextEdit>(obj);
                            if (te) {
                                if (te->has_meta("vg_scrollbars")) result = (int)te->get_meta("vg_scrollbars"); else result = 2;
                                handled = true;
                            }
                        }
                        // PasswordChar → LineEdit secret_character
                        else if (prop_name == "PasswordChar") {
                            LineEdit *le = Object::cast_to<LineEdit>(obj);
                            if (le) {
                                if (le->is_secret()) {
                                    result = String(le->get("secret_character"));
                                } else {
                                    result = String("");
                                }
                                handled = true;
                            }
                        }
                        // PlaceholderText → placeholder_text
                        else if (prop_name == "PlaceholderText") {
                            result = obj->get("placeholder_text");
                            handled = true;
                        }
                        // Editable → editable (direct, not inverted like Locked)
                        else if (prop_name == "Editable") {
                            Variant ed = obj->get("editable");
                            if (ed.get_type() == Variant::BOOL) {
                                result = ed;
                            } else {
                                result = true;
                            }
                            handled = true;
                        }
                        // SelStart → caret column / selection start
                        else if (prop_name == "SelStart") {
                            LineEdit *le = Object::cast_to<LineEdit>(obj);
                            if (le) {
                                if (le->has_selection()) {
                                    // selection_begin gives the start of the selection
                                    result = le->get("caret_column");
                                } else {
                                    result = le->get_caret_column();
                                }
                                handled = true;
                            } else {
                                TextEdit *te = Object::cast_to<TextEdit>(obj);
                                if (te) {
                                    result = te->get_caret_column();
                                    handled = true;
                                }
                            }
                        }
                        // SelLength → length of current selection
                        else if (prop_name == "SelLength") {
                            LineEdit *le = Object::cast_to<LineEdit>(obj);
                            if (le) {
                                if (le->has_selection()) {
                                    String sel = le->get_selected_text();
                                    result = sel.length();
                                } else {
                                    result = 0;
                                }
                                handled = true;
                            } else {
                                TextEdit *te = Object::cast_to<TextEdit>(obj);
                                if (te) {
                                    String sel = te->get_selected_text();
                                    result = sel.length();
                                    handled = true;
                                }
                            }
                        }
                        // SelText → selected text content
                        else if (prop_name == "SelText") {
                            LineEdit *le = Object::cast_to<LineEdit>(obj);
                            if (le) {
                                result = le->get_selected_text();
                                handled = true;
                            } else {
                                TextEdit *te = Object::cast_to<TextEdit>(obj);
                                if (te) {
                                    result = te->get_selected_text();
                                    handled = true;
                                }
                            }
                        }
                        // ---- Picture / Icon ----
                        // Picture → TextureRect.texture or meta path
                        else if (prop_name == "Picture") {
                            TextureRect *tr = Object::cast_to<TextureRect>(obj);
                            if (tr) {
                                result = Variant(tr->get_texture());
                                handled = true;
                            } else if (obj->has_meta("vg_picture_path")) {
                                result = obj->get_meta("vg_picture_path");
                                handled = true;
                            }
                        }
                        // Icon → Button.icon
                        else if (prop_name == "Icon") {
                            Button *btn = Object::cast_to<Button>(obj);
                            if (btn) {
                                result = Variant(btn->get_button_icon());
                                handled = true;
                            }
                        }
                        // ---- Tag (generic user data) ----
                        else if (prop_name == "Tag") {
                            result = obj->has_meta("vg_tag") ? obj->get_meta("vg_tag") : Variant();
                            handled = true;
                        }
                        // ---- Timer properties ----
                        // Interval → wait_time * 1000 (Godot seconds → VB6 milliseconds)
                        else if (prop_name == "Interval") {
                            Timer *tmr = Object::cast_to<Timer>(obj);
                            if (tmr) {
                                result = (int)(tmr->get_wait_time() * 1000.0);
                                handled = true;
                            }
                        }
                        // OneShot → one_shot (Timer)
                        else if (prop_name == "OneShot") {
                            Timer *tmr = Object::cast_to<Timer>(obj);
                            if (tmr) {
                                result = tmr->is_one_shot();
                                handled = true;
                            }
                        }
                        // Autostart → autostart (Timer)
                        else if (prop_name == "Autostart") {
                            Timer *tmr = Object::cast_to<Timer>(obj);
                            if (tmr) {
                                result = tmr->has_autostart();
                                handled = true;
                            }
                        }
                        // ---- ListBox / ComboBox properties ----
                        // ListCount → item_count (ItemList / OptionButton)
                        else if (prop_name == "ListCount") {
                            ItemList *il = Object::cast_to<ItemList>(obj);
                            if (il) {
                                result = il->get_item_count();
                                handled = true;
                            } else {
                                OptionButton *ob = Object::cast_to<OptionButton>(obj);
                                if (ob) {
                                    result = ob->get_item_count();
                                    handled = true;
                                }
                            }
                        }
                        // ListIndex → selected index
                        else if (prop_name == "ListIndex") {
                            ItemList *il = Object::cast_to<ItemList>(obj);
                            if (il) {
                                PackedInt32Array sel = il->get_selected_items();
                                result = sel.size() > 0 ? (int)sel[0] : -1;
                                handled = true;
                            } else {
                                OptionButton *ob = Object::cast_to<OptionButton>(obj);
                                if (ob) {
                                    result = ob->get_selected();
                                    handled = true;
                                }
                            }
                        }
                        // Sorted → meta flag (ItemList)
                        else if (prop_name == "Sorted") {
                            result = obj->has_meta("vg_sorted") ? (bool)obj->get_meta("vg_sorted") : false;
                            handled = true;
                        }
                        // ---- AutoSize / ClipText ----
                        // AutoSize → Label clip_text inverted
                        else if (prop_name == "AutoSize") {
                            Label *lbl = Object::cast_to<Label>(obj);
                            if (lbl) {
                                result = (lbl->get_autowrap_mode() == TextServer::AUTOWRAP_OFF &&
                                          !lbl->is_clipping_text());
                                handled = true;
                            }
                        }
                        // ClipText → Button clip_text
                        else if (prop_name == "ClipText") {
                            Button *btn = Object::cast_to<Button>(obj);
                            if (btn) {
                                result = btn->get_clip_text();
                                handled = true;
                            }
                        }
                        // ---- Form-level properties (Window) ----
                        // WindowState → 0=Normal, 1=Minimized, 2=Maximized
                        else if (prop_name == "WindowState") {
                            Window *win = Object::cast_to<Window>(obj);
                            if (win) {
                                if (win->get_mode() == Window::MODE_MINIMIZED) result = 1;
                                else if (win->get_mode() == Window::MODE_MAXIMIZED) result = 2;
                                else result = 0;
                                handled = true;
                            }
                        }
                        // ShowInTaskbar → Window flag (always_on_top inverse proxy)
                        else if (prop_name == "ShowInTaskbar") {
                            Window *win = Object::cast_to<Window>(obj);
                            if (win) {
                                result = !win->get_flag(Window::FLAG_NO_FOCUS);
                                handled = true;
                            }
                        }
                        // Moveable → Window unresizable inverse
                        else if (prop_name == "Moveable") {
                            Window *win = Object::cast_to<Window>(obj);
                            if (win) {
                                result = !win->get_flag(Window::FLAG_RESIZE_DISABLED);
                                handled = true;
                            }
                        }
                        // MinButton → Window flag
                        else if (prop_name == "MinButton") {
                            Window *win = Object::cast_to<Window>(obj);
                            if (win) {
                                result = !win->get_flag(Window::FLAG_RESIZE_DISABLED);
                                handled = true;
                            }
                        }
                        // MaxButton → Window flag
                        else if (prop_name == "MaxButton") {
                            Window *win = Object::cast_to<Window>(obj);
                            if (win) {
                                result = !win->get_flag(Window::FLAG_RESIZE_DISABLED);
                                handled = true;
                            }
                        }
                        // ControlBox → borderless inverse
                        else if (prop_name == "ControlBox") {
                            Window *win = Object::cast_to<Window>(obj);
                            if (win) {
                                result = !win->get_flag(Window::FLAG_BORDERLESS);
                                handled = true;
                            }
                        }
                        // ---- Misc ----
                        // ZOrder / ZIndex → z_index (Control/Node2D)
                        else if (prop_name == "ZOrder" || prop_name == "ZIndex") {
                            result = obj->get("z_index");
                            handled = true;
                        }
                        // Rotation → rotation_degrees (Control)
                        else if (prop_name == "Rotation") {
                            Control *ctrl = Object::cast_to<Control>(obj);
                            if (ctrl) {
                                result = Math::rad_to_deg(ctrl->get_rotation());
                                handled = true;
                            }
                        }
                        // hWnd → instance ID (compatibility alias)
                        else if (prop_name == "hWnd") {
                            result = (int64_t)obj->get_instance_id();
                            handled = true;
                        }
                        // Name → node name
                        else if (prop_name == "Name") {
                            Node *node = Object::cast_to<Node>(obj);
                            if (node) {
                                result = node->get_name();
                                handled = true;
                            }
                        }
                        // ---- New properties (v4.4.0) ----
                        // BackStyle: 0=Transparent, 1=Opaque
                        else if (prop_name == "BackStyle") {
                            result = obj->has_meta("vg_backstyle") ? (int)obj->get_meta("vg_backstyle") : 1;
                            handled = true;
                        }
                        // Appearance: 0=Flat, 1=3D
                        else if (prop_name == "Appearance") {
                            result = obj->has_meta("vg_appearance") ? (int)obj->get_meta("vg_appearance") : 1;
                            handled = true;
                        }
                        // TabIndex
                        else if (prop_name == "TabIndex") {
                            result = obj->has_meta("vg_tabindex") ? (int)obj->get_meta("vg_tabindex") : 0;
                            handled = true;
                        }
                        // Parent — returns parent Node
                        else if (prop_name == "Parent") {
                            Node *node = Object::cast_to<Node>(obj);
                            if (node && node->get_parent()) {
                                result = Variant(node->get_parent());
                            }
                            handled = true;
                        }
                        // Container — returns parent container
                        else if (prop_name == "Container") {
                            Node *node = Object::cast_to<Node>(obj);
                            if (node && node->get_parent()) {
                                result = Variant(node->get_parent());
                            }
                            handled = true;
                        }
                        // Index (control array index)
                        else if (prop_name == "Index") {
                            result = obj->has_meta("vg_index") ? (int)obj->get_meta("vg_index") : -1;
                            handled = true;
                        }
                        // DragMode: 0=Manual, 1=Automatic
                        else if (prop_name == "DragMode") {
                            result = obj->has_meta("vg_dragmode") ? (int)obj->get_meta("vg_dragmode") : 0;
                            handled = true;
                        }
                        // ---- Custom control VG_Properties support ----
                        // If the node has a "VG_Properties" meta dictionary, look
                        // up the VB6 property name there.  The dictionary maps
                        //   "PropertyName" → "godot_property"       (on self)
                        //   "PropertyName" → "Child:godot_property"  (on child)
                        if (!handled) {
                            Node *node = Object::cast_to<Node>(obj);
                            if (node && node->has_meta("VG_Properties")) {
                                Dictionary vgp = node->get_meta("VG_Properties");
                                if (vgp.has(prop_name)) {
                                    String mapping = vgp[prop_name];
                                    int colon = mapping.find(":");
                                    if (colon >= 0) {
                                        String child_path = mapping.substr(0, colon);
                                        String gprop = mapping.substr(colon + 1);
                                        Node *child = node->find_child(child_path, false, false);
                                        if (!child) child = node->get_node_or_null(NodePath(child_path));
                                        if (child) {
                                            result = child->get(gprop);
                                            handled = true;
                                        }
                                    } else {
                                        result = obj->get(mapping);
                                        handled = true;
                                    }
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
                        // Try as-is first, then UPPER_CASE (tokeniser normalises keywords
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
                        // VB6-style child control access: Me.btnPlay, Form1.txtName
                        // If the property wasn't found on the object, try find_child()
                        // to locate a child node with that name.
                        if (result.get_type() == Variant::NIL && obj) {
                            Node *node = Object::cast_to<Node>(obj);
                            if (node) {
                                Node *child = node->find_child(cache.primary_string, true, false);
                                if (child) {
                                    result = Variant(child);
                                }
                            }
                        }
                    }
                }
                push_value(result);
                break;
            }
            VG_CASE(vg_op_set_member, OP_SET_MEMBER): {
                PROFILE_OPCODE(SetMember);
                if (vm.ip + 1 >= code_size) { success = false; goto cleanup; }
                int idx = read_const_index();
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
                } else if (base.get_type() == Variant::QUATERNION) {
                    Quaternion q = base;
                    String member = cache.primary_string.to_lower();
                    if (member == "x") q.x = (real_t)(double)value;
                    else if (member == "y") q.y = (real_t)(double)value;
                    else if (member == "z") q.z = (real_t)(double)value;
                    else if (member == "w") q.w = (real_t)(double)value;
                    push_value(q);
                } else if (base.get_type() == Variant::PLANE) {
                    Plane pl = base;
                    String member = cache.primary_string.to_lower();
                    if (member == "normal") pl.normal = (Vector3)value;
                    else if (member == "d") pl.d = (real_t)(double)value;
                    else if (member == "x") pl.normal.x = (real_t)(double)value;
                    else if (member == "y") pl.normal.y = (real_t)(double)value;
                    else if (member == "z") pl.normal.z = (real_t)(double)value;
                    push_value(pl);
                } else if (base.get_type() == Variant::AABB) {
                    AABB box = base;
                    String member = cache.primary_string.to_lower();
                    if (member == "position") box.position = (Vector3)value;
                    else if (member == "size") box.size = (Vector3)value;
                    push_value(box);
                } else if (base.get_type() == Variant::TRANSFORM2D) {
                    Transform2D t = base;
                    String member = cache.primary_string.to_lower();
                    if (member == "origin") t.set_origin((Vector2)value);
                    else if (member == "x") t.columns[0] = (Vector2)value;
                    else if (member == "y") t.columns[1] = (Vector2)value;
                    push_value(t);
                } else if (base.get_type() == Variant::TRANSFORM3D) {
                    Transform3D t = base;
                    String member = cache.primary_string.to_lower();
                    if (member == "origin") t.origin = (Vector3)value;
                    else if (member == "basis") t.basis = (Basis)value;
                    push_value(t);
                } else if (base.get_type() == Variant::BASIS) {
                    Basis b = base;
                    String member = cache.primary_string.to_lower();
                    if (member == "x") b.rows[0] = (Vector3)value;
                    else if (member == "y") b.rows[1] = (Vector3)value;
                    else if (member == "z") b.rows[2] = (Vector3)value;
                    push_value(b);
                } else if (base.get_type() == Variant::VECTOR4) {
                    Vector4 v = base;
                    String member = cache.primary_string.to_lower();
                    if (member == "x") v.x = (real_t)(double)value;
                    else if (member == "y") v.y = (real_t)(double)value;
                    else if (member == "z") v.z = (real_t)(double)value;
                    else if (member == "w") v.w = (real_t)(double)value;
                    push_value(v);
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
                            bool is_form_background = false;
                            // If obj is a Window (form root), target _FormBackground Panel child
                            if (!ctrl) {
                                Window *win = Object::cast_to<Window>(obj);
                                if (win) {
                                    Node *bg = win->find_child("_FormBackground", false, false);
                                    if (bg) {
                                        ctrl = Object::cast_to<Control>(bg);
                                        is_form_background = true;
                                    }
                                }
                            }
                            if (ctrl) {
                                Color c = value;
                                // Panel uses "panel" theme stylebox, other Controls use "normal"
                                bool is_panel = (ctrl->get_class() == "Panel");
                                String sb_name = is_panel ? "panel" : "normal";

                                // Helper: create a StyleBoxFlat with the given color,
                                // cloning from the existing stylebox if possible.
                                auto make_color_sbf = [&](const String &name) -> Ref<StyleBoxFlat> {
                                    Ref<StyleBoxFlat> sbf;
                                    Ref<StyleBox> existing = ctrl->get_theme_stylebox(name);
                                    if (existing.is_valid()) {
                                        Ref<StyleBoxFlat> ef = existing;
                                        if (ef.is_valid()) sbf = ef->duplicate();
                                    }
                                    if (sbf.is_null()) sbf.instantiate();
                                    sbf->set_bg_color(c);
                                    return sbf;
                                };

                                Ref<StyleBoxFlat> sbf = make_color_sbf(sb_name);
                                ctrl->add_theme_stylebox_override(sb_name, sbf);

                                // For Button-like controls, also override hover/pressed/disabled
                                // so the color persists across all interaction states.
                                if (!is_panel) {
                                    static const char* extra_states[] = {"hover", "pressed", "disabled", nullptr};
                                    for (int si = 0; extra_states[si]; si++) {
                                        Ref<StyleBoxFlat> state_sbf = make_color_sbf(extra_states[si]);
                                        ctrl->add_theme_stylebox_override(extra_states[si], state_sbf);
                                    }
                                }

                                // Immediately update the theme cache so that the new
                                // stylebox is used during the next force_draw() or
                                // normal render.  add_theme_stylebox_override() defers
                                // the NOTIFICATION_THEME_CHANGED via call_deferred,
                                // which means force_draw() in MsgBox would still see
                                // the OLD theme cache.  Sending the notification now
                                // forces an immediate cache update.
                                ctrl->notification(Control::NOTIFICATION_THEME_CHANGED);

                                // Force immediate visual update ONLY for the form
                                // background Panel.  For other controls (Button, etc.)
                                // canvas_item_clear is destructive — it wipes text,
                                // icons, and all child drawing.  Those controls will
                                // re-draw properly on force_draw() since the theme
                                // cache is now up-to-date.
                                if (is_form_background) {
                                    RID ci = ctrl->get_canvas_item();
                                    if (ci.is_valid()) {
                                        RenderingServer::get_singleton()->canvas_item_clear(ci);
                                        sbf->draw(ci, Rect2(Vector2(), ctrl->get_size()));
                                    }
                                }
                            }
                            push_value(base);
                            break;
                        }
                        // ---- Font properties (SET) ----
                        // FontBold → create/modify FontVariation with embolden
                        else if (prop_name == "FontBold") {
                            Control *ctrl = Object::cast_to<Control>(obj);
                            if (ctrl) {
                                bool bold = (bool)value;
                                Ref<Font> existing = ctrl->get_theme_font("font");
                                Ref<FontVariation> fv;
                                if (existing.is_valid()) {
                                    fv = existing;
                                }
                                if (fv.is_null()) {
                                    fv.instantiate();
                                    if (existing.is_valid()) fv->set_base_font(existing);
                                }
                                fv->set_variation_embolden(bold ? 1.2f : 0.0f);
                                ctrl->add_theme_font_override("font", fv);
                            }
                            push_value(base);
                            break;
                        }
                        // FontItalic → create/modify FontVariation with skew transform
                        else if (prop_name == "FontItalic") {
                            Control *ctrl = Object::cast_to<Control>(obj);
                            if (ctrl) {
                                bool italic = (bool)value;
                                Ref<Font> existing = ctrl->get_theme_font("font");
                                Ref<FontVariation> fv;
                                if (existing.is_valid()) {
                                    fv = existing;
                                }
                                if (fv.is_null()) {
                                    fv.instantiate();
                                    if (existing.is_valid()) fv->set_base_font(existing);
                                }
                                Transform2D t = Transform2D();
                                if (italic) {
                                    t[0][1] = 0.2f; // skew for italic effect
                                }
                                fv->set_variation_transform(t);
                                ctrl->add_theme_font_override("font", fv);
                            }
                            push_value(base);
                            break;
                        }
                        // FontName → create SystemFont with given family name
                        else if (prop_name == "FontName") {
                            Control *ctrl = Object::cast_to<Control>(obj);
                            if (ctrl) {
                                String font_name = value;
                                Ref<SystemFont> sf;
                                sf.instantiate();
                                PackedStringArray names;
                                names.push_back(font_name);
                                sf->set_font_names(names);
                                // Preserve existing bold/italic via FontVariation wrapper
                                Ref<Font> existing = ctrl->get_theme_font("font");
                                Ref<FontVariation> fv_existing;
                                if (existing.is_valid()) fv_existing = existing;
                                if (fv_existing.is_valid()) {
                                    // Keep the variation, just swap base font
                                    Ref<FontVariation> fv;
                                    fv.instantiate();
                                    fv->set_base_font(sf);
                                    fv->set_variation_embolden(fv_existing->get_variation_embolden());
                                    fv->set_variation_transform(fv_existing->get_variation_transform());
                                    ctrl->add_theme_font_override("font", fv);
                                } else {
                                    ctrl->add_theme_font_override("font", sf);
                                }
                            }
                            push_value(base);
                            break;
                        }
                        // FontUnderline → stored as meta (no native Godot support on Control fonts)
                        else if (prop_name == "FontUnderline") {
                            obj->set_meta("vg_font_underline", (bool)value);
                            push_value(base);
                            break;
                        }
                        // FontStrikethrough → stored as meta
                        else if (prop_name == "FontStrikethrough") {
                            obj->set_meta("vg_font_strikethrough", (bool)value);
                            push_value(base);
                            break;
                        }
                        // ---- Border / Appearance (SET) ----
                        // BorderStyle → 0=None (remove borders), 1=FixedSingle (1px border)
                        else if (prop_name == "BorderStyle") {
                            Control *ctrl = Object::cast_to<Control>(obj);
                            if (ctrl) {
                                int bs = (int)value;
                                String sb_name = "normal";
                                Ref<StyleBox> existing = ctrl->get_theme_stylebox(sb_name);
                                Ref<StyleBoxFlat> sbf;
                                if (existing.is_valid()) {
                                    sbf = existing;
                                    if (sbf.is_valid()) sbf = sbf->duplicate();
                                }
                                if (sbf.is_null()) sbf.instantiate();
                                if (bs == 0) {
                                    sbf->set_border_width(SIDE_LEFT, 0);
                                    sbf->set_border_width(SIDE_TOP, 0);
                                    sbf->set_border_width(SIDE_RIGHT, 0);
                                    sbf->set_border_width(SIDE_BOTTOM, 0);
                                } else {
                                    sbf->set_border_width(SIDE_LEFT, 1);
                                    sbf->set_border_width(SIDE_TOP, 1);
                                    sbf->set_border_width(SIDE_RIGHT, 1);
                                    sbf->set_border_width(SIDE_BOTTOM, 1);
                                    sbf->set_border_color(Color(0, 0, 0));
                                }
                                ctrl->add_theme_stylebox_override(sb_name, sbf);
                                ctrl->notification(Control::NOTIFICATION_THEME_CHANGED);
                            }
                            push_value(base);
                            break;
                        }
                        // Style / Flat → Button.flat
                        else if (prop_name == "Style" || prop_name == "Flat") {
                            Button *btn = Object::cast_to<Button>(obj);
                            if (btn) {
                                btn->set_flat((bool)value);
                            }
                            push_value(base);
                            break;
                        }
                        // ---- TextBox-specific (SET) ----
                        // ScrollBars → TextEdit (placeholder — Godot always has vert scroll)
                        else if (prop_name == "ScrollBars") {
                            // Godot TextEdit doesn't expose h/v scroll toggles directly;
                            // store as meta for design-time reference.
                            obj->set_meta("vg_scrollbars", (int)value);
                            push_value(base);
                            break;
                        }
                        // PasswordChar → LineEdit secret + secret_character
                        else if (prop_name == "PasswordChar") {
                            LineEdit *le = Object::cast_to<LineEdit>(obj);
                            if (le) {
                                String ch = value;
                                if (ch.is_empty()) {
                                    le->set_secret(false);
                                } else {
                                    le->set_secret(true);
                                    le->set("secret_character", String(String::chr(ch[0])));
                                }
                            }
                            push_value(base);
                            break;
                        }
                        // PlaceholderText → placeholder_text
                        else if (prop_name == "PlaceholderText") {
                            godot_prop = "placeholder_text";
                        }
                        // Editable → editable (direct)
                        else if (prop_name == "Editable") {
                            godot_prop = "editable";
                        }
                        // SelStart → set caret column
                        else if (prop_name == "SelStart") {
                            LineEdit *le = Object::cast_to<LineEdit>(obj);
                            if (le) {
                                le->set_caret_column((int)value);
                            } else {
                                TextEdit *te = Object::cast_to<TextEdit>(obj);
                                if (te) {
                                    te->set_caret_column((int)value);
                                }
                            }
                            push_value(base);
                            break;
                        }
                        // SelLength → select from current caret
                        else if (prop_name == "SelLength") {
                            LineEdit *le = Object::cast_to<LineEdit>(obj);
                            if (le) {
                                int start = le->get_caret_column();
                                le->select(start, start + (int)value);
                            } else {
                                TextEdit *te = Object::cast_to<TextEdit>(obj);
                                if (te) {
                                    int col = te->get_caret_column();
                                    int line = te->get_caret_line();
                                    te->select(line, col, line, col + (int)value);
                                }
                            }
                            push_value(base);
                            break;
                        }
                        // SelText → replace selected text
                        else if (prop_name == "SelText") {
                            LineEdit *le = Object::cast_to<LineEdit>(obj);
                            if (le) {
                                if (le->has_selection()) {
                                    le->delete_text(le->get_selection_from_column(), le->get_selection_to_column());
                                    le->insert_text_at_caret(String(value));
                                } else {
                                    le->insert_text_at_caret(String(value));
                                }
                            } else {
                                TextEdit *te = Object::cast_to<TextEdit>(obj);
                                if (te) {
                                    te->insert_text_at_caret(String(value));
                                }
                            }
                            push_value(base);
                            break;
                        }
                        // ---- Picture / Icon (SET) ----
                        // Picture → load texture from path and set on TextureRect
                        else if (prop_name == "Picture") {
                            TextureRect *tr = Object::cast_to<TextureRect>(obj);
                            if (tr) {
                                if (value.get_type() == Variant::STRING) {
                                    String path = value;
                                    Ref<Texture2D> tex = ResourceLoader::get_singleton()->load(path);
                                    if (tex.is_valid()) tr->set_texture(tex);
                                    obj->set_meta("vg_picture_path", path);
                                } else if (value.get_type() == Variant::OBJECT) {
                                    Ref<Texture2D> tex = value;
                                    if (tex.is_valid()) tr->set_texture(tex);
                                }
                            } else {
                                // For non-TextureRect, store path as meta
                                obj->set_meta("vg_picture_path", String(value));
                            }
                            push_value(base);
                            break;
                        }
                        // Icon → Button icon
                        else if (prop_name == "Icon") {
                            Button *btn = Object::cast_to<Button>(obj);
                            if (btn) {
                                if (value.get_type() == Variant::STRING) {
                                    String path = value;
                                    Ref<Texture2D> tex = ResourceLoader::get_singleton()->load(path);
                                    if (tex.is_valid()) btn->set_button_icon(tex);
                                } else if (value.get_type() == Variant::OBJECT) {
                                    Ref<Texture2D> tex = value;
                                    if (tex.is_valid()) btn->set_button_icon(tex);
                                }
                            }
                            push_value(base);
                            break;
                        }
                        // ---- Tag (SET) ----
                        else if (prop_name == "Tag") {
                            obj->set_meta("vg_tag", value);
                            push_value(base);
                            break;
                        }
                        // ---- Timer properties (SET) ----
                        // Interval → wait_time (VB6 milliseconds → Godot seconds)
                        else if (prop_name == "Interval") {
                            Timer *tmr = Object::cast_to<Timer>(obj);
                            if (tmr) {
                                double ms = (double)value;
                                tmr->set_wait_time(ms / 1000.0);
                                push_value(base);
                                break;
                            }
                            // Fall through for non-Timer objects (e.g. VGTimer)
                        }
                        // OneShot → one_shot (Timer)
                        else if (prop_name == "OneShot") {
                            Timer *tmr = Object::cast_to<Timer>(obj);
                            if (tmr) {
                                tmr->set_one_shot((bool)value);
                                push_value(base);
                                break;
                            }
                        }
                        // Autostart → autostart (Timer)
                        else if (prop_name == "Autostart") {
                            Timer *tmr = Object::cast_to<Timer>(obj);
                            if (tmr) {
                                tmr->set_autostart((bool)value);
                                push_value(base);
                                break;
                            }
                        }
                        // ---- ListBox / ComboBox (SET) ----
                        // ListIndex → select item
                        else if (prop_name == "ListIndex") {
                            ItemList *il = Object::cast_to<ItemList>(obj);
                            if (il) {
                                int idx_val = (int)value;
                                il->deselect_all();
                                if (idx_val >= 0 && idx_val < il->get_item_count()) {
                                    il->select(idx_val);
                                }
                            } else {
                                OptionButton *ob = Object::cast_to<OptionButton>(obj);
                                if (ob) {
                                    ob->select((int)value);
                                }
                            }
                            push_value(base);
                            break;
                        }
                        // Sorted → meta flag + sort items
                        else if (prop_name == "Sorted") {
                            obj->set_meta("vg_sorted", (bool)value);
                            ItemList *il = Object::cast_to<ItemList>(obj);
                            if (il && (bool)value) {
                                il->sort_items_by_text();
                            }
                            push_value(base);
                            break;
                        }
                        // ---- AutoSize / ClipText (SET) ----
                        // AutoSize → Label: turn off clip_text + set autowrap OFF
                        else if (prop_name == "AutoSize") {
                            Label *lbl = Object::cast_to<Label>(obj);
                            if (lbl) {
                                bool autosize = (bool)value;
                                lbl->set_clip_text(!autosize);
                                if (autosize) lbl->set_autowrap_mode(TextServer::AUTOWRAP_OFF);
                            }
                            push_value(base);
                            break;
                        }
                        // ClipText → Button clip_text
                        else if (prop_name == "ClipText") {
                            Button *btn = Object::cast_to<Button>(obj);
                            if (btn) btn->set_clip_text((bool)value);
                            push_value(base);
                            break;
                        }
                        // ---- Form-level (SET) ----
                        // WindowState → 0=Normal, 1=Minimized, 2=Maximized
                        else if (prop_name == "WindowState") {
                            Window *win = Object::cast_to<Window>(obj);
                            if (win) {
                                int ws = (int)value;
                                if (ws == 1) win->set_mode(Window::MODE_MINIMIZED);
                                else if (ws == 2) win->set_mode(Window::MODE_MAXIMIZED);
                                else win->set_mode(Window::MODE_WINDOWED);
                            }
                            push_value(base);
                            break;
                        }
                        // ShowInTaskbar → Window no-focus flag
                        else if (prop_name == "ShowInTaskbar") {
                            Window *win = Object::cast_to<Window>(obj);
                            if (win) {
                                win->set_flag(Window::FLAG_NO_FOCUS, !(bool)value);
                            }
                            push_value(base);
                            break;
                        }
                        // Moveable → Window resize-disabled flag (inverse)
                        else if (prop_name == "Moveable") {
                            Window *win = Object::cast_to<Window>(obj);
                            if (win) {
                                win->set_flag(Window::FLAG_RESIZE_DISABLED, !(bool)value);
                            }
                            push_value(base);
                            break;
                        }
                        // MinButton / MaxButton → Window resize-disabled flag
                        else if (prop_name == "MinButton" || prop_name == "MaxButton") {
                            Window *win = Object::cast_to<Window>(obj);
                            if (win) {
                                win->set_flag(Window::FLAG_RESIZE_DISABLED, !(bool)value);
                            }
                            push_value(base);
                            break;
                        }
                        // ControlBox → Window borderless flag (inverse)
                        else if (prop_name == "ControlBox") {
                            Window *win = Object::cast_to<Window>(obj);
                            if (win) {
                                win->set_flag(Window::FLAG_BORDERLESS, !(bool)value);
                            }
                            push_value(base);
                            break;
                        }
                        // ---- Misc (SET) ----
                        // ZOrder / ZIndex → z_index (both spellings accepted)
                        else if (prop_name == "ZOrder" || prop_name == "ZIndex") {
                            godot_prop = "z_index";
                        }
                        // Rotation → rotation in degrees
                        else if (prop_name == "Rotation") {
                            Control *ctrl = Object::cast_to<Control>(obj);
                            if (ctrl) {
                                ctrl->set_rotation(Math::deg_to_rad((double)value));
                            }
                            push_value(base);
                            break;
                        }
                        // hWnd → read-only, ignore SET
                        else if (prop_name == "hWnd") {
                            push_value(base);
                            break;
                        }
                        // Name → node name
                        else if (prop_name == "Name") {
                            Node *node = Object::cast_to<Node>(obj);
                            if (node) {
                                node->set_name(String(value));
                            }
                            push_value(base);
                            break;
                        }
                        // ---- New properties (v4.4.0) ----
                        // BackStyle: 0=Transparent, 1=Opaque
                        else if (prop_name == "BackStyle") {
                            obj->set_meta("vg_backstyle", (int)value);
                            Control *ctrl = Object::cast_to<Control>(obj);
                            if (ctrl) {
                                ctrl->set_self_modulate((int)value == 0 ? Color(1,1,1,0) : Color(1,1,1,1));
                            }
                            push_value(base);
                            break;
                        }
                        // Appearance: 0=Flat, 1=3D
                        else if (prop_name == "Appearance") {
                            obj->set_meta("vg_appearance", (int)value);
                            push_value(base);
                            break;
                        }
                        // TabIndex
                        else if (prop_name == "TabIndex") {
                            obj->set_meta("vg_tabindex", (int)value);
                            push_value(base);
                            break;
                        }
                        // Index (control array index)
                        else if (prop_name == "Index") {
                            obj->set_meta("vg_index", (int)value);
                            push_value(base);
                            break;
                        }
                        // DragMode: 0=Manual, 1=Automatic
                        else if (prop_name == "DragMode") {
                            obj->set_meta("vg_dragmode", (int)value);
                            push_value(base);
                            break;
                        }
                        // ---- Custom control VG_Properties support (SET) ----
                        {
                            bool custom_handled = false;
                            Node *node = Object::cast_to<Node>(obj);
                            if (node && node->has_meta("VG_Properties")) {
                                Dictionary vgp = node->get_meta("VG_Properties");
                                if (vgp.has(prop_name)) {
                                    String mapping = vgp[prop_name];
                                    int colon = mapping.find(":");
                                    if (colon >= 0) {
                                        String child_path = mapping.substr(0, colon);
                                        String gprop = mapping.substr(colon + 1);
                                        Node *child = node->find_child(child_path, false, false);
                                        if (!child) child = node->get_node_or_null(NodePath(child_path));
                                        if (child) {
                                            child->set(gprop, value);
                                            custom_handled = true;
                                        }
                                    } else {
                                        obj->set(mapping, value);
                                        custom_handled = true;
                                    }
                                }
                            }
                            if (custom_handled) {
                                push_value(base);
                                break;
                            }
                        }
                        
                        if (!godot_prop.is_empty()) {
                            obj->set(godot_prop, value);
                            // Fire _Change event for data-changing properties (VB6 compat)
                            if (prop_name == "Text" || prop_name == "Caption" || prop_name == "Value") {
                                Node *_ce_node = Object::cast_to<Node>(obj);
                                if (_ce_node) {
                                    String _ce_sub = String(_ce_node->get_name()) + "_Change";
                                    bool _ce_found = false;
                                    call_internal(_ce_sub, Array(), _ce_found);
                                }
                            }
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
            VG_CASE(vg_op_sin, OP_SIN): {
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                push_value(::sin(to_double(pop_value())));
                break;
            }
            VG_CASE(vg_op_cos, OP_COS): {
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                push_value(::cos(to_double(pop_value())));
                break;
            }
            VG_CASE(vg_op_sqrt, OP_SQRT): {
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                push_value(::sqrt(to_double(pop_value())));
                break;
            }
            VG_CASE(vg_op_tan, OP_TAN): {
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                push_value(::tan(to_double(pop_value())));
                break;
            }
            VG_CASE(vg_op_atan2, OP_ATAN2): {
                // x pushed first, y pushed second → y is TOS
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                double y = to_double(pop_value());
                double x = to_double(pop_value());
                push_value(::atan2(y, x));
                break;
            }
            VG_CASE(vg_op_floor_f, OP_FLOOR_F): {
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                push_value(::floor(to_double(pop_value())));
                break;
            }
            VG_CASE(vg_op_ceil_f, OP_CEIL_F): {
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                push_value(::ceil(to_double(pop_value())));
                break;
            }
            VG_CASE(vg_op_exp, OP_EXP): {
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                push_value(::exp(to_double(pop_value())));
                break;
            }
            VG_CASE(vg_op_log, OP_LOG): {
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                push_value(::log(to_double(pop_value())));
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
                if (vm.ip + 1 >= code_size) { success = false; goto cleanup; }
                int data_idx = read_const_index();
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
                if (vm.ip + 1 >= code_size) { success = false; goto cleanup; }
                int name_idx = read_const_index();
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
                if (vm.ip + 1 >= code_size) { success = false; goto cleanup; }
                int name_idx = read_const_index();
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
                int type_idx = read_const_index();
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
                if (vm.ip + 1 >= code_size) { success = false; goto cleanup; }
                int label_idx = read_const_index();
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

                // ── Set Next Statement (early check) ──
                // If a set_next_statement message arrived between
                // instructions (after the previous vg_debug_wait
                // returned), catch it NOW before executing this line.
                if (VisualGasicLanguage::is_next_statement_requested()) {
                    int sns_target = VisualGasicLanguage::get_next_statement_line();
                    if (sns_target != line_number) {
                        VisualGasicLanguage::clear_next_statement();
                        // Scan bytecode for the target OP_DEBUG_LINE
                        for (int si = 0; si + 2 < code_size; si++) {
                            if (code[si] == OP_DEBUG_LINE) {
                                int el = (code[si + 2] << 8) | code[si + 1];
                                if (el == sns_target) {
                                    vm.ip = si;  // point AT the target OP_DEBUG_LINE
                                    UtilityFunctions::print("[VG Debug] Set Next Statement (early): redirected to line ", sns_target);
                                    break;  // exit scan loop — the main dispatch will process the target OP_DEBUG_LINE
                                }
                            }
                        }
                        break;  // exit this OP_DEBUG_LINE handler; the VM loop will fetch the target
                    } else {
                        // Already at the target line — just clear the flag
                        VisualGasicLanguage::clear_next_statement();
                    }
                }
                
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
                
                // Check our custom step mode (set by IW buttons via visualgasic:debug_* messages)
                VGStepMode current_step_mode = VisualGasicLanguage::get_step_mode();
                if (current_step_mode != VG_STEP_NONE && engine_debugger && engine_debugger->is_active()) {
                    int current_depth = VisualGasicLanguage::get_current_stack_depth();
                    int target_depth = VisualGasicLanguage::get_step_target_depth();
                    
                    switch (current_step_mode) {
                        case VG_STEP_INTO:
                            should_break = true;
                            break;
                        case VG_STEP_OVER:
                            should_break = (current_depth <= target_depth);
                            break;
                        case VG_STEP_OUT:
                            should_break = (current_depth <= target_depth);
                            break;
                        default:
                            break;
                    }
                    
                    if (should_break) {
                        VisualGasicLanguage::set_step_mode(VG_STEP_NONE);
                    }
                }
                
                // Unified step-break handler: pause if ANY mechanism set should_break
                // (Godot's lines_left/depth OR our custom step mode)
                if (should_break && engine_debugger && engine_debugger->is_active() && !script_path.is_empty()) {
                    VisualGasicLanguage::set_current_break_location(script_path, line_number);
                    
                    Array break_data;
                    break_data.push_back(script_path);
                    break_data.push_back(line_number);
                    engine_debugger->send_message("visualgasic:break_hit", break_data);
                    
                    _send_variables_to_debugger(engine_debugger);
                    _send_call_stack_to_debugger(engine_debugger);
                    engine_debugger->line_poll();
                    
                    VisualGasicLanguage::vg_debug_wait();
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
                        
                        VisualGasicLanguage::vg_debug_wait();
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
                        
                        VisualGasicLanguage::vg_debug_wait();
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
                                
                                VisualGasicLanguage::vg_debug_wait();
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
                    
                    VisualGasicLanguage::vg_debug_wait();
                }
                
                // ── Set Next Statement: after ANY debug wait returns, check if the
                //    user dragged the yellow arrow to a new line.  Scan the bytecode
                //    chunk for the first OP_DEBUG_LINE that encodes the target line
                //    and redirect vm.ip there. ──
                if (VisualGasicLanguage::is_next_statement_requested()) {
                    int target_line = VisualGasicLanguage::get_next_statement_line();
                    VisualGasicLanguage::clear_next_statement();
                    
                    // Scan bytecode for OP_DEBUG_LINE with matching line number
                    bool found_target = false;
                    for (int scan_ip = 0; scan_ip + 2 < code_size; scan_ip++) {
                        if (code[scan_ip] == OP_DEBUG_LINE) {
                            uint8_t lo = code[scan_ip + 1];
                            uint8_t hi = code[scan_ip + 2];
                            int encoded_line = (hi << 8) | lo;
                            if (encoded_line == target_line) {
                                // Point vm.ip AT the target OP_DEBUG_LINE so
                                // the VM naturally processes it on the next
                                // dispatch cycle — step mode, breakpoints,
                                // watchpoints etc. all work without an extra
                                // pause.  The main loop does op=code[vm.ip++],
                                // so placing ip at scan_ip means the target
                                // OP_DEBUG_LINE fires as if the VM just
                                // reached that line.
                                vm.ip = scan_ip;
                                found_target = true;
                                UtilityFunctions::print("[VG Debug] Set Next Statement: redirected to line ", target_line);
                                break;
                            }
                        }
                    }
                    if (!found_target) {
                        UtilityFunctions::print("[VG Debug] Set Next Statement: line ", target_line, " not found in bytecode — ignoring");
                        // Notify the editor so it can snap the yellow arrow back
                        EngineDebugger* sns_dbg = EngineDebugger::get_singleton();
                        if (sns_dbg && sns_dbg->is_active()) {
                            Array fail_data;
                            fail_data.push_back(target_line);
                            fail_data.push_back(debug_state.current_line);  // actual executing line
                            sns_dbg->send_message("visualgasic:set_next_statement_failed", fail_data);
                        }
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
                    VisualGasicLanguage::vg_debug_wait();
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
                // Operands: [METHOD_NAME_IDX(2)] [ARG_COUNT]
                if (vm.ip + 2 >= code_size) { success = false; goto cleanup; }
                int name_idx = read_const_index();
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
                int file_num = (int)pop_value();
                if (open_files.has(file_num)) {
                    Ref<FileAccess> fa = open_files[file_num];
                    PackedStringArray csv = fa->get_csv_line();
                    push_value(csv.size() > 0 ? Variant(csv[0]) : Variant(String()));
                } else {
                    raise_error(String("Bad file number: ") + String::num(file_num), 52);
                    push_value(String());
                    if (!try_recover_error(Variant(), false)) {
                        // NONE mode: error printed, continue
                    }
                }
                VG_BREAK;
            }
            VG_CASE(vg_op_line_input, OP_LINE_INPUT): {
                int file_num = (int)pop_value();
                if (open_files.has(file_num)) {
                    Ref<FileAccess> fa = open_files[file_num];
                    push_value(fa->get_line());
                } else {
                    raise_error(String("Bad file number: ") + String::num(file_num), 52);
                    push_value(String());
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
                    if (!lname.is_empty() && !builtin_constants.has(lname)) {
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
                        if (!lname.is_empty()) {
                            if (variables.has(lname)) locals.write[li] = variables[lname];
                            else if (builtin_constants.has(lname)) locals.write[li] = builtin_constants[lname];
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
                    if (!lname.is_empty()) {
                        if (variables.has(lname)) locals.write[li] = variables[lname];
                        else if (builtin_constants.has(lname)) locals.write[li] = builtin_constants[lname];
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
                // Layout: OP_TASK_RUN_BEGIN [name_const(2)] [bg_flag] [body_len_hi] [body_len_lo]
                if (vm.ip + 4 >= code_size) { success = false; goto cleanup; }
                int name_idx = read_const_index();
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
                    if (!lname.is_empty() && !builtin_constants.has(lname)) {
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
                    if (!lname.is_empty()) {
                        if (variables.has(lname)) locals.write[li] = variables[lname];
                        else if (builtin_constants.has(lname)) locals.write[li] = builtin_constants[lname];
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
                    if (!lname.is_empty()) {
                        if (variables.has(lname)) locals.write[li] = variables[lname];
                        else if (builtin_constants.has(lname)) locals.write[li] = builtin_constants[lname];
                    }
                }
                VG_BREAK;
            }

            // Await (v4.2.0) — coroutine dispatch with Signal/timer support.
            // If top-of-stack is a Signal, connect one-shot and create a scene
            // tree timer that resumes after the signal fires.  If it's a numeric
            // value, treat as a timer duration (seconds).  Otherwise synchronous.
            VG_CASE(vg_op_await, OP_AWAIT): {
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                Variant awaited = pop_value();
                
                if (awaited.get_type() == Variant::SIGNAL) {
                    // Real signal await — connect one-shot, then yield
                    Signal sig = (Signal)awaited;
                    if (sig.get_object() && owner) {
                        // Route resume through owner object's script dispatch
                        Callable resume_cb = Callable(owner, "_vg_resume_coroutine");
                        sig.get_object()->connect(sig.get_name(), resume_cb, Object::CONNECT_ONE_SHOT);
                        
                        // Save coroutine state for resume
                        CoroutineState cs;
                        cs.function_name = func ? func->name : String("<main>");
                        cs.instruction_pointer = vm.ip;
                        cs.is_awaiting = true;
                        // Snapshot instance variables as local state
                        cs.local_variables = variables.duplicate(true);
                        coroutine_stack.push_back(cs);
                        goto cleanup;  // Yield — exit VM loop
                    }
                } else if (awaited.get_type() == Variant::FLOAT || awaited.get_type() == Variant::INT) {
                    // Await <number> → create timer for N seconds, then resume
                    double seconds = (double)awaited;
                    if (seconds > 0.0 && owner) {
                        SceneTree* tree = Object::cast_to<SceneTree>(Engine::get_singleton()->get_main_loop());
                        if (tree) {
                            Ref<SceneTreeTimer> timer = tree->create_timer(seconds);
                            if (timer.is_valid()) {
                                Callable resume_cb = Callable(owner, "_vg_resume_coroutine");
                                timer->connect("timeout", resume_cb, Object::CONNECT_ONE_SHOT);
                                
                                CoroutineState cs;
                                cs.function_name = func ? func->name : String("<main>");
                                cs.instruction_pointer = vm.ip;
                                cs.is_awaiting = true;
                                cs.local_variables = variables.duplicate(true);
                                coroutine_stack.push_back(cs);
                                goto cleanup;
                            }
                        }
                    }
                }
                // For all other types (or failed timer/signal), treat as synchronous no-op.
                // The awaited value has been consumed from the stack.
                VG_BREAK;
            }

            // RaiseEvent (v3.5.0) — emit a Godot signal on the owner object.
            VG_CASE(vg_op_raise_event, OP_RAISE_EVENT): {
                if (vm.ip + 2 >= code_size) { success = false; goto cleanup; }
                int name_idx = read_const_index();
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

            // AddressOf (v5.0.1) — create a Callable from a method name.
            VG_CASE(vg_op_address_of, OP_ADDRESS_OF): {
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                String method_name = pop_value();
                if (owner) {
                    push_value(Callable(owner, method_name));
                } else {
                    UtilityFunctions::printerr("VisualGasic: AddressOf requires an owner object");
                    push_value(Variant());
                }
                VG_BREAK;
            }

            // ── M5: MemoryBuffer opcodes ──────────────────────────────────
            // Each accesses a PackedByteArray stored in a local slot,
            // performing direct byte/word/dword reads/writes without
            // the Variant overhead of OP_GET_ARRAY / OP_SET_ARRAY.
            // ───────────────────────────────────────────────────────────────

            // OP_BUF_ALLOC [SLOT]  — pop size, create PackedByteArray, store in locals[slot]
            VG_CASE(vg_op_buf_alloc, OP_BUF_ALLOC): {
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t slot = code[vm.ip++];
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                int64_t size = to_int(pop_value());
                if (size < 0) size = 0;
                if (slot >= locals.size()) {
                    raise_error("OP_BUF_ALLOC: slot out of range");
                    if (try_recover_error(Variant())) break;
                    success = false; goto cleanup;
                }
                PackedByteArray buf;
                buf.resize((int)size);
                // Zero-fill
                for (int i = 0; i < buf.size(); i++) buf.set(i, 0);
                sync_local(slot, Variant(buf));
                VG_BREAK;
            }

            // OP_BUF_FREE [SLOT]  — free buffer, set locals[slot] = nil
            VG_CASE(vg_op_buf_free, OP_BUF_FREE): {
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t slot = code[vm.ip++];
                if (slot < locals.size()) {
                    sync_local(slot, Variant());
                }
                VG_BREAK;
            }

            // OP_BUF_READ8 [SLOT]  — pop offset, push byte as int64
            VG_CASE(vg_op_buf_read8, OP_BUF_READ8): {
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t slot = code[vm.ip++];
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                int64_t offset = to_int(pop_value());
                if (slot >= locals.size()) {
                    push_value((int64_t)0);
                    VG_BREAK;
                }
                Variant &var = locals.write[slot];
                if (var.get_type() != Variant::PACKED_BYTE_ARRAY) {
                    push_value((int64_t)0);
                    VG_BREAK;
                }
                PackedByteArray buf = var;
                if (offset >= 0 && offset < buf.size()) {
                    push_value((int64_t)(uint8_t)buf[offset]);
                } else {
                    push_value((int64_t)0);
                }
                VG_BREAK;
            }

            // OP_BUF_WRITE8 [SLOT]  — pop value, pop offset, buf[offset] = (uint8_t)value
            VG_CASE(vg_op_buf_write8, OP_BUF_WRITE8): {
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t slot = code[vm.ip++];
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                int64_t value = to_int(pop_value());
                int64_t offset = to_int(pop_value());
                if (slot >= locals.size()) { VG_BREAK; }
                Variant &var = locals.write[slot];
                if (var.get_type() != Variant::PACKED_BYTE_ARRAY) { VG_BREAK; }
                PackedByteArray buf = var;
                if (offset >= 0 && offset < buf.size()) {
                    buf.set((int)offset, (uint8_t)(value & 0xFF));
                    sync_local(slot, Variant(buf));
                }
                VG_BREAK;
            }

            // OP_BUF_READ16 [SLOT]  — pop offset, push 16-bit LE word as int64
            VG_CASE(vg_op_buf_read16, OP_BUF_READ16): {
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t slot = code[vm.ip++];
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                int64_t offset = to_int(pop_value());
                if (slot >= locals.size()) { push_value((int64_t)0); VG_BREAK; }
                Variant &var = locals.write[slot];
                if (var.get_type() != Variant::PACKED_BYTE_ARRAY) { push_value((int64_t)0); VG_BREAK; }
                PackedByteArray buf = var;
                if (offset >= 0 && offset + 1 < buf.size()) {
                    uint16_t word = (uint8_t)buf[offset] | ((uint16_t)(uint8_t)buf[offset + 1] << 8);
                    push_value((int64_t)word);
                } else {
                    push_value((int64_t)0);
                }
                VG_BREAK;
            }

            // OP_BUF_WRITE16 [SLOT]  — pop value, pop offset, write 16-bit LE
            VG_CASE(vg_op_buf_write16, OP_BUF_WRITE16): {
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t slot = code[vm.ip++];
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                int64_t value = to_int(pop_value());
                int64_t offset = to_int(pop_value());
                if (slot >= locals.size()) { VG_BREAK; }
                Variant &var = locals.write[slot];
                if (var.get_type() != Variant::PACKED_BYTE_ARRAY) { VG_BREAK; }
                PackedByteArray buf = var;
                if (offset >= 0 && offset + 1 < buf.size()) {
                    buf.set((int)offset, (uint8_t)(value & 0xFF));
                    buf.set((int)(offset + 1), (uint8_t)((value >> 8) & 0xFF));
                    sync_local(slot, Variant(buf));
                }
                VG_BREAK;
            }

            // OP_BUF_READ32 [SLOT]  — pop offset, push 32-bit LE dword as int64
            VG_CASE(vg_op_buf_read32, OP_BUF_READ32): {
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t slot = code[vm.ip++];
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                int64_t offset = to_int(pop_value());
                if (slot >= locals.size()) { push_value((int64_t)0); VG_BREAK; }
                Variant &var = locals.write[slot];
                if (var.get_type() != Variant::PACKED_BYTE_ARRAY) { push_value((int64_t)0); VG_BREAK; }
                PackedByteArray buf = var;
                if (offset >= 0 && offset + 3 < buf.size()) {
                    uint32_t dword = (uint8_t)buf[offset]
                        | ((uint32_t)(uint8_t)buf[offset + 1] << 8)
                        | ((uint32_t)(uint8_t)buf[offset + 2] << 16)
                        | ((uint32_t)(uint8_t)buf[offset + 3] << 24);
                    push_value((int64_t)dword);
                } else {
                    push_value((int64_t)0);
                }
                VG_BREAK;
            }

            // OP_BUF_WRITE32 [SLOT]  — pop value, pop offset, write 32-bit LE
            VG_CASE(vg_op_buf_write32, OP_BUF_WRITE32): {
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t slot = code[vm.ip++];
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                int64_t value = to_int(pop_value());
                int64_t offset = to_int(pop_value());
                if (slot >= locals.size()) { VG_BREAK; }
                Variant &var = locals.write[slot];
                if (var.get_type() != Variant::PACKED_BYTE_ARRAY) { VG_BREAK; }
                PackedByteArray buf = var;
                if (offset >= 0 && offset + 3 < buf.size()) {
                    buf.set((int)offset, (uint8_t)(value & 0xFF));
                    buf.set((int)(offset + 1), (uint8_t)((value >> 8) & 0xFF));
                    buf.set((int)(offset + 2), (uint8_t)((value >> 16) & 0xFF));
                    buf.set((int)(offset + 3), (uint8_t)((value >> 24) & 0xFF));
                    sync_local(slot, Variant(buf));
                }
                VG_BREAK;
            }

            // OP_BUF_SIZE [SLOT]  — push buf.size()
            VG_CASE(vg_op_buf_size, OP_BUF_SIZE): {
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t slot = code[vm.ip++];
                if (slot >= locals.size()) { push_value((int64_t)0); VG_BREAK; }
                Variant &var = locals.write[slot];
                if (var.get_type() != Variant::PACKED_BYTE_ARRAY) {
                    push_value((int64_t)0);
                } else {
                    PackedByteArray buf = var;
                    push_value((int64_t)buf.size());
                }
                VG_BREAK;
            }

            // OP_BUF_RESIZE [SLOT]  — pop new_size, buf.resize()
            VG_CASE(vg_op_buf_resize, OP_BUF_RESIZE): {
                if (vm.ip >= code_size) { success = false; goto cleanup; }
                uint8_t slot = code[vm.ip++];
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                int64_t new_size = to_int(pop_value());
                if (slot >= locals.size()) { VG_BREAK; }
                Variant &var = locals.write[slot];
                if (var.get_type() != Variant::PACKED_BYTE_ARRAY) { VG_BREAK; }
                PackedByteArray buf = var;
                buf.resize((int)new_size);
                sync_local(slot, Variant(buf));
                VG_BREAK;
            }

            // v6.2: Global VGMemoryBuffer fast path — fuses OP_GET_GLOBAL +
            // the Object/VGMemoryBuffer branch of OP_GET_ARRAY into a single
            // opcode for Public/global "New MemoryBuffer(...)" variables
            // (module-level buffer vars stay a real VGMemoryBuffer Object;
            // see OP_BUF_* above for the separate local-slot PackedByteArray
            // path). Removes one opcode dispatch + one Variant stack
            // round-trip + the array-type cascade per access on the hottest
            // per-cycle path in the C64/GBA emulators (Mem_Read/Mem_Write).
            //
            // OP_GET_GLOBAL_BUF8 [NAME_CONST]  — pop offset, push PeekByte(offset)
            VG_CASE(vg_op_get_global_buf8, OP_GET_GLOBAL_BUF8): {
                if (vm.ip + 1 >= code_size) { success = false; goto cleanup; }
                int idx = read_const_index();
                if (!ensure_stack(1)) { success = false; goto cleanup; }
                int64_t offset = to_int(pop_value());
                String name = read_constant(idx);
                Variant gvar = variables.get(name, Variant());
                if (gvar.get_type() == Variant::OBJECT) {
                    Object *obj = gvar;
                    VGMemoryBuffer *mb = Object::cast_to<VGMemoryBuffer>(obj);
                    if (mb) {
                        push_value((int64_t)mb->peek_byte(offset));
                        VG_BREAK;
                    }
                }
                // Not allocated yet / wrong type — same graceful default as
                // the generic OP_GET_ARRAY Object branch would give.
                push_value((int64_t)0);
                VG_BREAK;
            }

            // OP_SET_GLOBAL_BUF8 [NAME_CONST]  — pop value, pop offset, PokeByte(offset, value)
            VG_CASE(vg_op_set_global_buf8, OP_SET_GLOBAL_BUF8): {
                if (vm.ip + 1 >= code_size) { success = false; goto cleanup; }
                int idx = read_const_index();
                if (!ensure_stack(2)) { success = false; goto cleanup; }
                int64_t value = to_int(pop_value());
                int64_t offset = to_int(pop_value());
                String name = read_constant(idx);
                Variant gvar = variables.get(name, Variant());
                if (gvar.get_type() == Variant::OBJECT) {
                    Object *obj = gvar;
                    VGMemoryBuffer *mb = Object::cast_to<VGMemoryBuffer>(obj);
                    if (mb) {
                        mb->poke_byte(offset, (int)(value & 0xFF));
                    }
                }
                VG_BREAK;
            }

            // ── M6: Optimization Hint opcodes ────────────────────────────
            // These are NOPs at runtime — they only serve as markers for the
            // optimizer/fusion passes. The compiler emits them to tell the
            // optimizer that a variable slot has specific properties.
            // ──────────────────────────────────────────────────────────────
            // ── M6: Select Case Jump Table ──────────────────────────
            // Dense integer Select Case (e.g. opcode decoders) compile to
            // O(1) dispatch instead of O(n) if-else chains.
            VG_CASE(vg_op_jump_table, OP_JUMP_TABLE): {
                int min_cix = (int)code[vm.ip] | ((int)code[vm.ip+1] << 8); vm.ip += 2;
                int max_cix = (int)code[vm.ip] | ((int)code[vm.ip+1] << 8); vm.ip += 2;
                int16_t def_off = (int16_t)(code[vm.ip] | (code[vm.ip+1] << 8)); vm.ip += 2;
                int num_cases = (int)code[vm.ip] | ((int)code[vm.ip+1] << 8); vm.ip += 2;
                // Table entries occupy [vm.ip, vm.ip + num_cases*2); all stored
                // offsets (def_off and per-slot offsets) are relative to the end
                // of the table (table_end), not to vm.ip itself (table_start) —
                // see try_compile_jump_table() in visual_gasic_compiler.cpp.
                int table_bytes = num_cases * 2;

                Variant top = pop_value();
                int64_t val = 0;
                if (top.get_type() == Variant::INT) val = (int64_t)top;
                else if (top.get_type() == Variant::FLOAT) val = (int64_t)(double)top;
                else { vm.ip += table_bytes + def_off; VG_BREAK; }

                int64_t min_val = (int64_t)chunk->constants[min_cix];
                int64_t max_val = (int64_t)chunk->constants[max_cix];

                if (val < min_val || val > max_val) {
                    vm.ip += table_bytes + def_off;
                } else {
                    int64_t idx = val - min_val;
                    if (idx >= 0 && idx < (int64_t)num_cases) {
                        int16_t _off = (int16_t)(code[vm.ip + idx*2] | (code[vm.ip + idx*2 + 1] << 8));
                        vm.ip += table_bytes + _off;
                    } else {
                        vm.ip += table_bytes + def_off;
                    }
                }
                VG_BREAK;
            }


            VG_CASE(vg_op_hint_accum, OP_HINT_ACCUMULATOR):
            VG_CASE(vg_op_hint_counter, OP_HINT_LOOP_COUNTER):
            VG_CASE(vg_op_hint_pure, OP_HINT_PURE_CALL): {
                // Hint opcodes: just skip the implicit 1-byte operand (slot/idx)
                // without executing anything. The optimizer will consume them
                // during the optimize() pass (they are NOP'd out before runtime).
                vm.ip++; // skip slot byte
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
            if (is_fast_slot(i)) continue; // fast-call params/return never enter variables[]
            const String &name = chunk->local_names[i];
            if (!name.is_empty() && !builtin_constants.has(name)) {
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
        for (int i = 0; i < saved_globals.size(); i++) {
            variables[saved_globals[i].first] = saved_globals[i].second;
        }
    }

    if (success) {
        if (has_explicit_return) {
            result_snapshot = explicit_return;
            // Bug fix: Also write to variables[func->name] so that
            // call_internal's return-value lookup sees it. Otherwise
            // the default-initialized value (0/"") wins over the
            // actual Return value.
            // Fast-call Functions read their result straight from the return
            // slot, so skip the variables[] write (it would leak func->name).
            if (func && func->type == SubDefinition::TYPE_FUNCTION && !fast_call) {
                variables[func->name] = explicit_return;
            }
        } else if (vm.stack.size() > stack_base) {
            result_snapshot = vm.stack[vm.stack.size() - 1];
        }
    }
    restore_vm();
    finalize_stack_profile();
    finalize_profile();

    // Restore the outer frame's debug pointers (for nested calls).
    debug_bc_locals = prev_debug_bc_locals;
    debug_bc_chunk  = prev_debug_bc_chunk;
    
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
        } else if (fast_call && fast_return_slot >= 0 && fast_return_slot < locals.size()) {
            // Fast-call: the implicit `FuncName = expr` result lives in the
            // dedicated return slot, never in variables[].
            r_ret = locals[fast_return_slot];
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

