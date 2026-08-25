// Thin Array-based wrapper (kept for the ~15 cold callers: GUI event dispatch,
// evaluate.inc, execute.inc, statement.cpp, the _Change handler).  It copies the
// godot Array into a flat Variant buffer and forwards to the Variant* core.
// These sites are all cold (GUI events / AST fallback), never the tight call
// loops, so the copy is immaterial — the hot bytecode OP_CALL path calls the
// Variant* core directly with a C++-stack SBO and never builds an Array at all.
Variant VisualGasicInstance::call_internal(const String& p_method, const Array& p_args, bool &r_found, const CallResolutionCacheEntry* p_pre_resolved, VMState* p_vm) {
    const int _n = p_args.size();
    constexpr int _WRAP_INLINE = 8;
    Variant _wrap_inline[_WRAP_INLINE];
    Vector<Variant> _wrap_heap;
    Variant* _wp = _wrap_inline;
    if (_n > _WRAP_INLINE) { _wrap_heap.resize(_n); _wp = _wrap_heap.ptrw(); }
    for (int _i = 0; _i < _n; _i++) _wp[_i] = p_args[_i];
    return call_internal(p_method, _wp, _n, r_found, p_pre_resolved, p_vm);
}

Variant VisualGasicInstance::call_internal(const String& p_method, const Variant* p_args, int p_arg_count, bool &r_found, const CallResolutionCacheEntry* p_pre_resolved, VMState* p_vm) {
    r_found = false;
    if (!script.is_valid() || !script->ast_root) return Variant();

    // Block runtime methods in editor mode
    if (Engine::get_singleton()->is_editor_hint()) {
        String method_lower = p_method.to_lower();
        if (method_lower == "_ready" || method_lower == "_process" || 
            method_lower == "_physics_process" || method_lower == "_input" ||
            method_lower == "_unhandled_input" || method_lower == "_enter_tree" ||
            method_lower == "_exit_tree") {
            r_found = true; // Pretend we handled it to prevent errors
            return Variant();
        }
    }

    SubDefinition *func = nullptr;
    ImportedModule* owning_module = nullptr;
    BytecodeChunk *chunk_for_locals = nullptr;
    int call_arg_count = p_arg_count;

    // ── Call-site resolution cache (v6.0 perf, Jul 2026) ──
    // Resolving the callee used to be a full linear rescan of every module-level
    // Sub (twice — once for arity matching, once for overload-mangling) plus a
    // bytecode-chunk lookup, ALL repeated on every single call regardless of how
    // many times the exact same (name, arg count) pair had already been resolved.
    // The result is 100% deterministic for a given (name, arg count) for the
    // lifetime of this instance's AST, so cache it. This does NOT change the
    // saved_locals/argument-binding work below (still done per-call) — only the
    // "which function/bytecode-chunk is this?" resolution step.
    // ── VM-threaded pre-resolution fast path (Part I, v6.0 perf) ──
    // The bytecode OP_CALL handler memoizes the resolution for each immutable
    // call site and threads it here, letting a hot loop's repeated calls skip
    // the p_method.to_lower() + "name#argc" concat + the _call_resolution_cache
    // string-key probe below entirely (String::to_lower was ~12.7% of call-heavy
    // runtime, per perf, once fast_params engaged).  Mirrors the cache-hit branch
    // exactly; only ever set for module-level resolutions (never class siblings),
    // preserving the module-takes-precedence order below.
    if (p_pre_resolved && p_pre_resolved->resolved) {
        func = p_pre_resolved->func;
        owning_module = (p_pre_resolved->owning_module_index >= 0)
                        ? &imported_modules.write[p_pre_resolved->owning_module_index] : nullptr;
        chunk_for_locals = p_pre_resolved->chunk_for_locals;
    } else {
    String _res_key = p_method.to_lower() + "#" + String::num_int64(call_arg_count);
    if (_call_resolution_cache.has(_res_key)) {
        const CallResolutionCacheEntry &_cached = _call_resolution_cache[_res_key];
        if (_cached.resolved) {
            func = _cached.func;
            owning_module = (_cached.owning_module_index >= 0) ? &imported_modules.write[_cached.owning_module_index] : nullptr;
            chunk_for_locals = _cached.chunk_for_locals;
        }
        // _cached.resolved == false means "no module/import-level function with
        // this name/arity" — func stays nullptr, falls through to the same-class
        // sibling method check below exactly as an uncached miss would.
    } else {
        SubDefinition *first_match = nullptr;
        for(int i=0; i<script->ast_root->subs.size(); i++) {
            if (script->ast_root->subs[i]->name.nocasecmp_to(p_method) == 0) {
                if (!first_match) first_match = script->ast_root->subs[i];
                int param_count = script->ast_root->subs[i]->parameters.size();
                // Exact param count match
                if (param_count == call_arg_count) {
                    func = script->ast_root->subs[i];
                    break;
                }
                // Optional parameters: check if arg_count falls within [required, total] range
                int required = 0;
                for (int j = 0; j < param_count; j++) {
                    if (!script->ast_root->subs[i]->parameters[j].is_optional &&
                        !script->ast_root->subs[i]->parameters[j].is_param_array)
                        required++;
                }
                bool has_param_array = param_count > 0 && script->ast_root->subs[i]->parameters[param_count - 1].is_param_array;
                if (has_param_array ? (call_arg_count >= required) : (call_arg_count >= required && call_arg_count <= param_count)) {
                    func = script->ast_root->subs[i];
                    break;
                }
            }
        }
        if (!func) func = first_match; // Backward compat: single-overload always matches

        // ── Cross-module function resolution (v4.3.0) ──
        // If the function wasn't found in the current script, search imported modules.
        // v4.4.0: also remember which module the function actually came from, so its
        // bytecode can be compiled/cached against that module's own AST below instead
        // of the calling script's (which would never find it).
        int owning_module_index = -1;
        if (!func && imported_modules.size() > 0) {
            String found_module_name;
            func = find_imported_sub(p_method, call_arg_count, &found_module_name);
            if (func) {
                for (int m = 0; m < imported_modules.size(); m++) {
                    if (imported_modules[m].module_name.nocasecmp_to(found_module_name) == 0) {
                        owning_module = &imported_modules.write[m];
                        owning_module_index = m;
                        break;
                    }
                }
            }
        }

        CallResolutionCacheEntry _new_entry;
        _new_entry.resolved = (func != nullptr);
        if (func) {
            _new_entry.func = func;
            _new_entry.owning_module_index = owning_module_index;
            // v3.7: Use mangled bytecode key for overloaded functions (name$arity)
            // v4.4.0: mangle against the OWNING module's own subs list (main script
            // or an imported module), not always the calling script's ast_root.
            // Part AE (v6.0 perf): bytecode_key lives ONLY here — it is read solely
            // to compute chunk_for_locals below and to populate the cache entry.
            // The pre-resolved and cache-hit fast paths thread chunk_for_locals
            // directly and never read it back, so keeping the String at function
            // scope cost a construct + String::operator= + destruct on EVERY hot
            // call for a value those paths discard.  Sunk here, the hot paths pay
            // nothing; only the once-per-call-site cache-miss branch builds it.
            String bytecode_key;
            const Vector<SubDefinition*>& owner_subs = owning_module ? owning_module->ast->subs : script->ast_root->subs;
            for (int _oi = 0; _oi < owner_subs.size(); _oi++) {
                if (owner_subs[_oi] != func &&
                    owner_subs[_oi]->name.nocasecmp_to(func->name) == 0) {
                    bytecode_key = func->name + "$" + String::num_int64(func->parameters.size());
                    break;
                }
            }
            if (bytecode_key.is_empty()) bytecode_key = func->name;
            _new_entry.bytecode_key = bytecode_key;
            chunk_for_locals = owning_module ? get_bytecode_for_import(*owning_module, bytecode_key)
                                              : (script.is_valid() ? script->get_bytecode_for(bytecode_key, &get_global_buffer_var_names()) : nullptr);
            _new_entry.chunk_for_locals = chunk_for_locals;
        }
        _call_resolution_cache[_res_key] = _new_entry;
    }
    }  // end pre-resolution else (Part I)

    // ── Same-class sibling method resolution ──
    // Bare (unqualified) calls made from inside a Class ... End Class method
    // to a SIBLING method of that same class (e.g. Write16 calling Write8
    // without "Me." or a dot-qualified receiver) are NOT module-level Subs,
    // so they'd never be found above — that list only ever holds the
    // top-level script's own Subs/Functions. Route through the class's own
    // method table instead when we're currently executing inside a class
    // instance's method (current_object_id set by execute_class_method()).
    if (!func && current_object_id != -1 && object_instances.has(current_object_id)) {
        Dictionary obj_data = object_instances[current_object_id];
        String class_name = obj_data.get("__class__", String());
        ClassDefinition* cls = get_class_def(class_name);
        if (cls) {
            SubDefinition* sibling = find_method_in_hierarchy(cls, p_method, call_arg_count);
            if (sibling) {
                r_found = true;
                Array _oa;
                _oa.resize(p_arg_count);
                for (int _i = 0; _i < p_arg_count; _i++) _oa[_i] = p_args[_i];
                return call_object_method(current_object_id, p_method, _oa);
            }
        }
    }
    
    if (!func) return Variant();
    r_found = true;

    // Save Context
    SubDefinition* prev_sub = current_sub;
    int prev_jump = jump_target;
    ErrorState prev_error = error_state;
    
    // Save local variables for recursion support.
    // Only save variables the function will define: params, return var, and Dim'd locals.
    // v6.0 perf: use a small Vector<Pair> instead of a heap Dictionary.  The common
    // case saves 0-2 entries, and an empty Vector allocates nothing, so this removes
    // one heap Dictionary construction (+ per-name hash inserts + a keys() Array on
    // restore) from every single call.  The Dictionary's exact-key .has() maps to a
    // case-sensitive linear scan (saved_locals_has); N is tiny (params+locals).
    Vector<Pair<String, Variant>> saved_locals;
    auto saved_locals_has = [&saved_locals](const String &n) -> bool {
        for (int _i = 0; _i < saved_locals.size(); _i++)
            if (saved_locals[_i].first == n) return true;
        return false;
    };
    // Fast-call convention (v6.0): when the compiled chunk flagged fast_params,
    // the parameters and Function return variable live in dedicated local slots
    // and are NEVER written into the variables[] Dictionary (execute_bytecode's
    // is_fast_slot() skips them even under an active Whenever).  The bytecode
    // VM's per-call `locals` vector already gives them recursion isolation, so
    // there is nothing to save, restore, or erase here — skipping this dict
    // traffic is the bulk of the fast-call win.  Their slots are the leading
    // param_count entries plus return_slot in local_names[], so those indices
    // are skipped in the local_names loops below (save and erase, kept in
    // balance so a same-named module global a param shadows stays untouched).
    const bool use_fast_params = (chunk_for_locals && chunk_for_locals->fast_params);
    // Part P: capture the local<->variables[] sync mode ONCE at entry so the
    // save (pre-execution) and erase (post-execution) local_names scans below
    // make an IDENTICAL decision — even if the callee itself registers a
    // Whenever (STMT_WHENEVER flips needs_var_sync true mid-run, permanently).
    // When sync is off (the overwhelmingly common case), every slot-based local
    // lives only in locals[]/typed shadow arrays and is NEVER mirrored into the
    // variables[] Dictionary (see sync_local's `needs_var_sync && …` guard), so
    // there is nothing in variables[] to save, restore, or erase for those
    // names.  Skipping the scans removes one variables.has() + one
    // variables.erase() ptrcall PER CALL for every compiler-generated temp
    // (__cse_*, __inv_to_*, Dim locals) — ~8.5% Dictionary::has + 2.6%
    // Dictionary::erase of call-heavy runtime, per perf.
    const bool _sync_locals_to_dict = needs_var_sync;
    // Save parameters
    if (!use_fast_params) {
        for(int i=0; i<func->parameters.size(); i++) {
            const String &pname = func->parameters[i].name;
            if (variables.has(pname)) saved_locals.push_back({pname, variables[pname]});
        }
        // Save function return variable
        if (func->type == SubDefinition::TYPE_FUNCTION) {
            if (variables.has(func->name)) saved_locals.push_back({func->name, variables[func->name]});
        }
    }

    // v2.5: Use pre-computed local_names from bytecode instead of walking
    // the AST at runtime.  The compiler already collects every Dim/For/
    // ForEach variable name into BytecodeChunk::local_names, so we can
    // just iterate that flat vector — O(locals) instead of O(AST nodes).
    // (bytecode_key / chunk_for_locals were already resolved — from cache or
    // freshly computed — in the call-site resolution block above.)
    if (chunk_for_locals) {
        // Part P: slot-based locals only enter variables[] under Whenever/Task.Run
        // sync; otherwise the whole scan is wasted Dictionary probes — skip it.
        if (_sync_locals_to_dict) {
            for (int i = 0; i < chunk_for_locals->local_names.size(); i++) {
                // Fast-call slots (params + return) never touch variables[].
                if (use_fast_params && (i < chunk_for_locals->param_count || i == chunk_for_locals->return_slot)) {
                    continue;
                }
                const String &lname = chunk_for_locals->local_names[i];
                if (!lname.is_empty() && variables.has(lname)) {
                    saved_locals.push_back({lname, variables[lname]});
                }
            }
        }
    } else {
        // Fallback: AST-only path (no bytecode compiled for this function).
        // Recursively scan for Dim'd variables in all nested blocks.
        struct DimScanner {
            static void scan(const Vector<Statement*>& stmts, Vector<Pair<String, Variant>>& vars, const Dictionary& all_vars) {
                for(int i=0; i<stmts.size(); i++) {
                    if (!stmts[i]) continue;
                    if (stmts[i]->type == STMT_DIM) {
                        DimStatement* ds = (DimStatement*)stmts[i];
                        if (all_vars.has(ds->variable_name))
                            vars.push_back({ds->variable_name, all_vars[ds->variable_name]});
                    } else if (stmts[i]->type == STMT_IF) {
                        IfStatement* ifs = (IfStatement*)stmts[i];
                        scan(ifs->then_branch, vars, all_vars);
                        scan(ifs->else_branch, vars, all_vars);
                    } else if (stmts[i]->type == STMT_FOR) {
                        ForStatement* fs = (ForStatement*)stmts[i];
                        if (all_vars.has(fs->variable_name))
                            vars.push_back({fs->variable_name, all_vars[fs->variable_name]});
                        scan(fs->body, vars, all_vars);
                    } else if (stmts[i]->type == STMT_WHILE) {
                        scan(((WhileStatement*)stmts[i])->body, vars, all_vars);
                    } else if (stmts[i]->type == STMT_DO) {
                        scan(((DoStatement*)stmts[i])->body, vars, all_vars);
                    } else if (stmts[i]->type == STMT_FOR_EACH) {
                        ForEachStatement* fes = (ForEachStatement*)stmts[i];
                        if (all_vars.has(fes->variable_name))
                            vars.push_back({fes->variable_name, all_vars[fes->variable_name]});
                        scan(fes->body, vars, all_vars);
                    } else if (stmts[i]->type == STMT_OSCILLATE) {
                        OscillateStatement* oss = (OscillateStatement*)stmts[i];
                        if (all_vars.has(oss->variable_name))
                            vars.push_back({oss->variable_name, all_vars[oss->variable_name]});
                        scan(oss->body, vars, all_vars);
                    }
                }
            }
        };
        DimScanner::scan(func->statements, saved_locals, variables);
    }
    
    // Fast-call convention (v6.0): when the compiled chunk flagged fast_params,
    // the parameters and return variable get dedicated local slots (seeded by
    // execute_bytecode from p_fast_args) instead of being written into the
    // variables[] Dictionary — eliminating the per-call insert/lookup/erase that
    // dominates call overhead.  Build the coerced argument values once and reuse
    // them for both the bytecode seed and the (rare) AST fallback binding.
    // (use_fast_params was computed above, before the save loop.)
    // Part T: fast-call argument buffer.  The coerced ByVal arg values (plus the
    // typed return-init) are copied into the callee's leading local slots by
    // execute_bytecode's fast-call seeding BEFORE any nested call runs, so a
    // per-frame buffer suffices.  A small stack array covers the common case
    // (<= FAST_ARGS_INLINE args) and avoids the per-call heap allocation of a
    // godot Vector<Variant> (CowData::resize + Memory::alloc_static were each
    // ~3% of call-heavy runtime); many-arg calls fall back to the heap Vector.
    constexpr int FAST_ARGS_INLINE = 6;
    Variant _fast_args_inline[FAST_ARGS_INLINE];
    Vector<Variant> _fast_args_heap;   // fallback storage for > FAST_ARGS_INLINE
    Variant* fast_arg_values = _fast_args_inline;
    int fast_arg_count = 0;

    // Arguments
    int max_params = func->parameters.size();
    if (use_fast_params) {
        // Scalar ByVal params only (guaranteed by the compiler's fast_params
        // guard) → pure coercion into a flat buffer, no variables[] writes.
        // The trailing slot (Functions only) carries the typed return init.
        fast_arg_count = max_params + (func->type == SubDefinition::TYPE_FUNCTION ? 1 : 0);
        if (fast_arg_count > FAST_ARGS_INLINE) {
            _fast_args_heap.resize(fast_arg_count);
            fast_arg_values = _fast_args_heap.ptrw();
        }
        // Precomputed coercion codes (compiler) replace the per-call
        // type_hint.to_lower() + string compares.  Guarded by a size check so a
        // chunk somehow lacking them falls back to the original string path.
        const bool _have_pc = (chunk_for_locals->fast_param_coerce.size() == max_params);
        for (int i = 0; i < max_params; i++) {
            // Part AG (v6.0 perf): precomputed-coercion fast path — write the
            // coerced arg STRAIGHT into fast_arg_values[i] instead of routing it
            // through an intermediate `val` Variant.  The old shape
            // (`val = p_args[i]; val = (T)val; fast_arg_values[i] = val;`) cost
            // two extra Variant copy-assigns per arg (copy in + copy out); the
            // direct `fast_arg_values[i] = (T)p_args[i];` is one extract + one
            // typed assign.  Also skips the per-iteration `func->parameters.write[i]`
            // (a CoW write-proxy access the fast path never reads).  Rare paths
            // (no precomputed codes, optional default, missing arg) keep the
            // original val-based path below unchanged.
            if (_have_pc && i < p_arg_count) {
                const Variant& src = p_args[i];
                switch (chunk_for_locals->fast_param_coerce[i]) {
                    case 1: fast_arg_values[i] = (int64_t)src; break;
                    case 2: fast_arg_values[i] = (double)src;  break;
                    case 3: fast_arg_values[i] = (String)src;  break;
                    case 4: fast_arg_values[i] = (bool)src;    break;
                    default: fast_arg_values[i] = src;         break;   // 0 = no coercion
                }
                continue;
            }
            Parameter& param = func->parameters.write[i];
            Variant val;
            if (i < p_arg_count) {
                val = p_args[i];
                if (!param.type_hint.is_empty()) {
                    String t = param.type_hint.to_lower();
                    if (t == "integer" || t == "long") val = (int64_t)val;
                    else if (t == "single" || t == "double") val = (double)val;
                    else if (t == "string") val = (String)val;
                    else if (t == "boolean") val = (bool)val;
                }
            } else if (param.is_optional) {
                val = param.default_value;
            } else {
                UtilityFunctions::print("Runtime Error: Argument '", param.name, "' missing for ", func->name);
                val = Variant();
            }
            fast_arg_values[i] = val;
        }
        if (func->type == SubDefinition::TYPE_FUNCTION) {
            Variant init_val = Variant();
            const int8_t _rc = chunk_for_locals->fast_return_coerce;
            if (_rc >= 0) {
                switch (_rc) {
                    case 1: init_val = (int64_t)0; break;
                    case 2: init_val = 0.0;        break;
                    case 3: init_val = String();   break;
                    case 4: init_val = false;      break;
                    default: break;   // 0 = none
                }
            } else if (!func->return_type.is_empty()) {
                String t = func->return_type.to_lower();
                if (t == "integer" || t == "long") init_val = (int64_t)0;
                else if (t == "single" || t == "double") init_val = 0.0;
                else if (t == "string") init_val = "";
                else if (t == "boolean") init_val = false;
            }
            fast_arg_values[max_params] = init_val;
        }
    } else {
        // Use larger size if params exist, or args exist.
        // Actually we iterate params to define them.
        for(int i=0; i<max_params; i++) {
            Parameter& param = func->parameters.write[i];

            if (param.is_param_array) {
                // ParamArray collects all remaining arguments into an array
                Array rest;
                for(int k=i; k<p_arg_count; k++) {
                    rest.push_back(p_args[k]);
                }
                variables[param.name] = rest;
                break; // ParamArray is always the last argument
            }

            if (i < p_arg_count) {
                Variant val = p_args[i];
                 // Enforce Parameter Type
                if (!param.type_hint.is_empty()) {
                    String t = param.type_hint.to_lower();
                    if (t == "integer" || t == "long") val = (int64_t)val;
                    else if (t == "single" || t == "double") val = (double)val;
                    else if (t == "string") val = (String)val;
                    else if (t == "boolean") val = (bool)val;
                }
                variables[param.name] = val;
            } else {
                if (param.is_optional) {
                    variables[param.name] = param.default_value;
                } else {
                     UtilityFunctions::print("Runtime Error: Argument '", param.name, "' missing for ", func->name);
                     variables[param.name] = Variant(); // Default to Nil
                }
            }
        }
        // Init Return
        if (func->type == SubDefinition::TYPE_FUNCTION) {
            Variant init_val = Variant();
            if (!func->return_type.is_empty()) {
                 String t = func->return_type.to_lower();
                 if (t == "integer" || t == "long") init_val = (int64_t)0;
                 else if (t == "single" || t == "double") init_val = 0.0;
                 else if (t == "string") init_val = "";
                 else if (t == "boolean") init_val = false;
            }
            variables[func->name] = init_val;
        }
    }

    current_sub = func;
    error_state.mode = ErrorState::NONE;
    error_state.has_error = false;
    // NOTE: error_state.label is deliberately NOT reset here.  It is read ONLY
    // under `if (error_state.mode == ErrorState::GOTO_LABEL)` (below), and the
    // only two sites that set mode = GOTO_LABEL set label in the same breath
    // (the On-Error-Goto handlers in the bytecode VM and the AST executor).
    // Since mode is cleared to NONE just above, any later read of label is
    // always preceded by a fresh assignment — a stale value can never be
    // observed.  Dropping `error_state.label = ""` removes a godot String
    // construct-from-C-literal ptrcall on EVERY call (~1.6% of call-heavy work).

    // Push call stack frame for debugger.
    // Part M: reuse the pointer-guarded script-path cache (added in Part J for
    // execute_bytecode) instead of calling script->get_path() on EVERY call —
    // get_path was ~5.4% of call-heavy runtime (a fresh String alloc per call).
    // Part O: the debug frame is only ever read through is_active()-gated debugger
    // paths (see execute_bytecode), so skip the push (and matching pop) entirely
    // when no debugger is attached — that removes two String ref-copies + a
    // std::vector push_back per call on the hot path. pop_stack_frame guards an
    // empty stack, and runtime errors report via debug_state.current_line, so
    // gating is safe. push/pop share the SAME cached flag to stay balanced.
    EngineDebugger *_call_debugger = EngineDebugger::get_singleton();
    const bool debug_frames_active = _call_debugger && _call_debugger->is_active();
    if (debug_frames_active) {
        String file_path;
        if (script.is_valid()) {
            if (_debug_script_path_owner != script.ptr()) {
                _debug_script_path = script->get_path();
                _debug_script_path_owner = script.ptr();
            }
            file_path = _debug_script_path;
        }
        int start_line = func->statements.size() > 0 ? func->statements[0]->line : 0;
        VisualGasicLanguage::push_stack_frame(file_path, func->name, start_line, this);
    }

    bool used_bytecode = false;
    Variant bytecode_ret;
    if (chunk_for_locals) {
        // v2.5: No more variables.duplicate(true) deep copy!
        // execute_bytecode() now only flushes locals→variables on
        // success, so on failure the dictionary stays clean and the
        // AST fallback can re-execute without a rollback copy.
        used_bytecode = execute_bytecode(chunk_for_locals, func, bytecode_ret, 0, -1, nullptr,
                                         use_fast_params ? fast_arg_values : nullptr, fast_arg_count,
                                         p_vm);
        if (!used_bytecode) {
            if (error_state.has_error) {
                // Bytecode VM hit a runtime error (e.g. "Sub or Function not
                // defined").  Don't fall back to the AST interpreter — that
                // would re-execute partially-completed statements and double-
                // mutate state.  Mark as "used" to skip the AST loop; the
                // error will propagate to the caller at cleanup below.
                used_bytecode = true;
            } else {
                // Part AF (v6.0 perf): reconstruct the pre-execution error_state
                // snapshot from prev_error (saved at fn entry) instead of a per-call
                // SECOND full ErrorState copy (the old `bytecode_error_backup`).
                // Between that entry snapshot and this point the ONLY error_state
                // mutations are the mode=NONE + has_error=false reset above (label/
                // message/code/error_line are untouched), so restoring prev_error and
                // re-applying those two scalars is BYTE-IDENTICAL to the old backup.
                // The two String member copies now fall ONLY on this cold AST-fallback
                // branch, never the hot bytecode-success path every fast_params call
                // takes.  (ErrorState::ErrorState 1.61% + ErrorState::operator= 1.31%
                // surfaced as the top cluster once Part AE removed the String cost.)
                error_state = prev_error;
                error_state.mode = ErrorState::NONE;
                error_state.has_error = false;
            }
        }
    }

    if (!used_bytecode) {
        // Fast-call params were seeded straight into local slots for the
        // bytecode VM and never written to variables[]; the AST interpreter
        // reads params/return from variables[], so bind them now (rare
        // fallback path — only reached when the bytecode VM bailed without a
        // hard error).
        if (use_fast_params) {
            for (int i = 0; i < func->parameters.size() && i < fast_arg_count; i++) {
                variables[func->parameters[i].name] = fast_arg_values[i];
            }
            if (func->type == SubDefinition::TYPE_FUNCTION &&
                fast_arg_count > func->parameters.size()) {
                variables[func->name] = fast_arg_values[func->parameters.size()];
            }
        }
        // Execute Loop
        for (int i = 0; i < func->statements.size(); i++) {
            jump_target = -1;
            execute_statement(func->statements[i]);

            if (error_state.has_error) {
                if (error_state.mode == ErrorState::RESUME_NEXT) {
                    error_state.has_error = false;
                    continue;
                }
                if (error_state.mode == ErrorState::GOTO_LABEL) {
                    error_state.has_error = false;
                    if (func->label_map.has(error_state.label)) {
                        int idx = (int)func->label_map[error_state.label];
                        i = idx - 1;
                        continue;
                    }
                    UtilityFunctions::print("Runtime Error: Error Handler Label '", error_state.label, "' not found.");
                }
                if (error_state.mode == ErrorState::EXIT_SUB) {
                    error_state.has_error = false;
                    break;
                }
                // Unhandled
                break;
            }

            if (jump_target != -1) {
                i = jump_target;
            }
        }
    }
    
    Variant ret = Variant();
    if (func->type == SubDefinition::TYPE_FUNCTION) {
        if (used_bytecode) {
            ret = bytecode_ret;
        } else if (variables.has(func->name)) {
            ret = variables[func->name];
        }
    } else if (used_bytecode) {
        ret = bytecode_ret;
    }
    
    // Pop call stack frame for debugger (Part O: only if we pushed one — i.e. a
    // debugger was attached at call entry; the flag is cached so push/pop match).
    if (debug_frames_active) {
        VisualGasicLanguage::pop_stack_frame();
    }
    
    // Capture ByRef parameter values BEFORE restoring locals.
    // The local-restore step below overwrites variables[param.name]
    // with the pre-call snapshot, which would clobber the post-execution
    // value that the caller's STMT_CALL handler needs for ByRef write-back.
    // Example: HandleKeyboardInput calls PlayNote(i) where i=12.
    //   call_internal saves noteIndex=<old>, sets noteIndex=12, executes,
    //   then restores noteIndex=<old>.  Without this capture, the caller's
    //   ByRef write-back reads the stale <old> value and clobbers i.
    Vector<Pair<String, Variant>> byref_captures;
    if (func) {
        for (int i = 0; i < func->parameters.size(); i++) {
            if (!func->parameters[i].is_by_ref) continue;
            Variant captured;
            // Fast-call params live in bytecode local slots, not variables[].
            if (use_fast_params && chunk_for_locals && debug_bc_locals &&
                    i < chunk_for_locals->param_count && i < debug_bc_locals->size()) {
                captured = (*debug_bc_locals)[i];
            } else if (variables.has(func->parameters[i].name)) {
                captured = variables[func->parameters[i].name];
            } else if (chunk_for_locals && debug_bc_locals) {
                for (int s = 0; s < chunk_for_locals->local_names.size() && s < debug_bc_locals->size(); s++) {
                    if (chunk_for_locals->local_names[s].nocasecmp_to(func->parameters[i].name) == 0) {
                        captured = (*debug_bc_locals)[s];
                        break;
                    }
                }
            }
            byref_captures.push_back({func->parameters[i].name, captured});
        }
    }

    // Restore
    current_sub = prev_sub;
    jump_target = prev_jump;
    // VB6-style error propagation: if there's an unhandled runtime error
    // (mode == NONE means no On Error handler caught it), propagate it to
    // the caller so its own On Error handler gets a chance.  If no handler
    // exists anywhere up the call stack, the top-level event dispatcher
    // will report the error and halt execution.
    bool had_unhandled_error = error_state.has_error && error_state.mode == ErrorState::NONE;
    // Perf: the full `ErrorState propagated_error = error_state;` copy used to run
    // on EVERY call (two godot String copy ptrcalls for label+message), but its
    // fields are read ONLY on the rare unhandled-error path below.  Capture just
    // the propagated scalars/message inside that branch instead — the common
    // (no-error) path now does a single `error_state = prev_error` restore.
    if (had_unhandled_error) {
        const String prop_message = error_state.message;
        const int prop_code = error_state.code;
        const int prop_error_line = error_state.error_line;
        error_state = prev_error;
        error_state.has_error = true;
        error_state.message = prop_message;
        error_state.code = prop_code;
        error_state.error_line = prop_error_line;
    } else {
        error_state = prev_error;
    }
    
    // Save any static variables before restoring locals
    // Check func body for Static Dim statements and persist their values.
    // Perf: skip the O(statements) scan entirely for Subs with no top-level
    // Static locals (nearly all of them) via a one-time cached flag.
    if (func->has_static_locals_cache < 0) {
        int hs = 0;
        for (int si = 0; si < func->statements.size(); si++) {
            if (func->statements[si] && func->statements[si]->type == STMT_DIM &&
                ((DimStatement*)func->statements[si])->is_static) { hs = 1; break; }
        }
        func->has_static_locals_cache = hs;
    }
    if (func->has_static_locals_cache == 1) {
        for (int si = 0; si < func->statements.size(); si++) {
            if (func->statements[si] && func->statements[si]->type == STMT_DIM) {
                DimStatement* ds = (DimStatement*)func->statements[si];
                if (ds->is_static && variables.has(ds->variable_name)) {
                    String static_key = func->name + "." + ds->variable_name;
                    static_variables[static_key] = variables[ds->variable_name];
                }
            }
        }
    }
    
    // Restore saved local variables for recursion support.
    // Perf: the common case saved nothing (no callee param/local name collided
    // with an existing caller variable, e.g. non-recursive calls with fresh
    // locals), so this loop is a no-op over an empty (unallocated) Vector.
    for (int i = 0; i < saved_locals.size(); i++) {
        variables[saved_locals[i].first] = saved_locals[i].second;
    }

    // Erase callee-introduced variables that did NOT exist in the caller's
    // scope before the call.  Without this, the function return variable
    // (e.g. "Scale") leaks into `variables` and the tree-walk evaluator's
    // ARRAY_ACCESS handler sees it as an Array/Dictionary instead of
    // dispatching a function call on subsequent invocations.
    // -- Function return variable
    if (func->type == SubDefinition::TYPE_FUNCTION && !use_fast_params && !saved_locals_has(func->name)) {
        variables.erase(func->name);
    }
    // -- Parameters
    if (!use_fast_params) {
        for (int i = 0; i < func->parameters.size(); i++) {
            const String &pname = func->parameters[i].name;
            if (!saved_locals_has(pname)) {
                variables.erase(pname);
            }
        }
    }
    // -- Dim'd locals
    // Part P: mirror the save-loop guard.  When sync was off at entry, slot
    // locals never entered variables[] (nothing was saved for them either), so
    // there is nothing to erase — skipping keeps save/erase perfectly balanced
    // and avoids deleting a same-named module global that was never shadowed.
    if (chunk_for_locals && _sync_locals_to_dict) {
        for (int i = 0; i < chunk_for_locals->local_names.size(); i++) {
            // Fast-call slots (params + return) are never written to variables[],
            // so there is nothing to erase; skip them (kept in balance with the
            // save loop so a shadowed same-named module global is left intact).
            if (use_fast_params && (i < chunk_for_locals->param_count || i == chunk_for_locals->return_slot)) {
                continue;
            }
            const String &lname = chunk_for_locals->local_names[i];
            if (!lname.is_empty() && !saved_locals_has(lname)) {
                variables.erase(lname);
            }
        }
    }

    // Store captured ByRef parameter values for the caller's write-back
    // (AST STMT_CALL and bytecode OP_BYREF_LOAD).  Bytecode subs already
    // stashed captures from callee locals in execute_bytecode() before
    // debug_bc_locals was restored; overwriting here would clobber them.
    if (!used_bytecode) {
        _last_byref_captures = byref_captures;
    }
    
    return ret;
}

void VisualGasicInstance::call(const StringName &p_method, const Variant *const *p_args, GDExtensionInt p_argcount, Variant *r_return, GDExtensionCallError *r_error) {
    // Block all script execution in editor mode
    if (Engine::get_singleton()->is_editor_hint()) {
        if (r_return) *r_return = Variant();
        r_error->error = GDEXTENSION_CALL_OK;
        return;
    }
    
    // Coroutine resume callback (v4.2.0) — invoked by signal/timer one-shot
    if (p_method == StringName("_vg_resume_coroutine")) {
        _resume_coroutine();
        if (r_return) *r_return = Variant();
        r_error->error = GDEXTENSION_CALL_OK;
        return;
    }
    
    // Special debug introspection methods (allowed even in editor for debugging)
    if (p_method == StringName("_vg_get_all_variables")) {
        // Return user-defined variables only (built-in constants live in
        // builtin_constants and are excluded from the debugger Vars panel).
        Dictionary result;
        Array keys = variables.keys();
        for (int i = 0; i < keys.size(); i++) {
            String key = keys[i];
            // Skip internal/mutable objects that aren't user variables
            if (key != "Err" && key != "__vg_Printer" && !builtin_constants.has(key)) {
                result[key] = variables[key];
            }
        }
        // Include bytecode locals from the current execution frame.
        if (debug_bc_locals && debug_bc_chunk) {
            for (int i = 0; i < debug_bc_chunk->local_names.size() && i < debug_bc_locals->size(); i++) {
                const String &name = debug_bc_chunk->local_names[i];
                if (!name.is_empty() && !name.begins_with("__") && !builtin_constants.has(name) && !result.has(name)) {
                    result[name] = (*debug_bc_locals)[i];
                }
            }
        }
        if (r_return) *r_return = result;
        r_error->error = GDEXTENSION_CALL_OK;
        return;
    }
    
    if (p_method == StringName("_vg_get_variable")) {
        if (p_argcount >= 1) {
            String var_name = *p_args[0];
            if (variables.has(var_name)) {
                if (r_return) *r_return = variables[var_name];
            } else if (builtin_constants.has(var_name)) {
                if (r_return) *r_return = builtin_constants[var_name];
            } else if (debug_bc_locals && debug_bc_chunk) {
                // Check bytecode locals for the current frame
                bool found = false;
                for (int i = 0; i < debug_bc_chunk->local_names.size() && i < debug_bc_locals->size(); i++) {
                    if (debug_bc_chunk->local_names[i] == var_name) {
                        if (r_return) *r_return = (*debug_bc_locals)[i];
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    if (r_return) *r_return = Variant();
                }
            } else {
                if (r_return) *r_return = Variant();
            }
        } else {
            if (r_return) *r_return = Variant();
        }
        r_error->error = GDEXTENSION_CALL_OK;
        return;
    }
    
    if (p_method == StringName("_vg_set_variable")) {
        if (p_argcount >= 2) {
            String var_name = *p_args[0];
            Variant value = *p_args[1];
            variables[var_name] = value;
            if (r_return) *r_return = true;
        } else {
            if (r_return) *r_return = false;
        }
        r_error->error = GDEXTENSION_CALL_OK;
        return;
    }
    
    if (p_method == StringName("_vg_get_whenever_sections")) {
        // Return all Whenever sections for debugging
        Array result;
        for (int i = 0; i < whenever_sections.size(); i++) {
            const WheneverSection& section = whenever_sections[i];
            Dictionary info;
            info["name"] = section.section_name;
            info["variable"] = section.variable_name;
            info["operator"] = section.comparison_operator;
            info["value"] = section.comparison_value;
            info["value2"] = section.comparison_value2;
            info["is_active"] = section.is_active;
            info["last_value"] = section.last_value;
            info["last_trigger_time"] = (int64_t)section.last_trigger_time;
            info["scope_type"] = section.scope_type;
            info["scope_context"] = section.scope_context;
            info["callbacks"] = section.callback_procedures.size();
            
            // Build callback names string
            String callbacks_str;
            for (int j = 0; j < section.callback_procedures.size(); j++) {
                if (j > 0) callbacks_str += ", ";
                callbacks_str += section.callback_procedures[j];
            }
            info["callback_names"] = callbacks_str;
            
            result.push_back(info);
        }
        if (r_return) *r_return = result;
        r_error->error = GDEXTENSION_CALL_OK;
        return;
    }
    
    if (p_method == StringName("_vg_set_whenever_active")) {
        // Pause/Resume a Whenever section by name
        if (p_argcount >= 2) {
            String section_name = *p_args[0];
            bool active = *p_args[1];
            for (int i = 0; i < whenever_sections.size(); i++) {
                if (whenever_sections[i].section_name == section_name) {
                    whenever_sections.write[i].is_active = active;
                    if (r_return) *r_return = true;
                    r_error->error = GDEXTENSION_CALL_OK;
                    return;
                }
            }
            if (r_return) *r_return = false;
        } else {
            if (r_return) *r_return = false;
        }
        r_error->error = GDEXTENSION_CALL_OK;
        return;
    }
    
    // Profiler methods — delegate to the global VisualGasicProfiler singleton
    if (p_method == StringName("_vg_profiler_enable")) {
        bool enable = (p_argcount >= 1) ? (bool)(*p_args[0]) : true;
        VisualGasicProfiler::getInstance().enable_profiling(enable);
        if (r_return) *r_return = true;
        r_error->error = GDEXTENSION_CALL_OK;
        return;
    }
    
    if (p_method == StringName("_vg_profiler_get_report")) {
        if (r_return) *r_return = VisualGasicProfiler::getInstance().get_performance_report();
        r_error->error = GDEXTENSION_CALL_OK;
        return;
    }
    
    if (p_method == StringName("_vg_profiler_clear")) {
        // Reset accumulated profiler data
        VisualGasicProfiler::getInstance().enable_profiling(false);
        VisualGasicProfiler::getInstance().reset_memory_pool();
        VisualGasicProfiler::getInstance().enable_profiling(true);
        if (r_return) *r_return = true;
        r_error->error = GDEXTENSION_CALL_OK;
        return;
    }
    
    // Adapter
    Array args;
    for(int i=0; i<p_argcount; i++) args.push_back(*p_args[i]);
    
    // Intercept _OnSignal
    if (p_method == StringName("_OnSignal")) {
         // Args: [SignalArg1, ..., SignalArgN, Bound1, Bound2]
         // Bound args are at the END.
         // Standard Pattern: ObjectName, EventName
         
         if (args.size() >= 2) {
             String name = args[args.size()-2];
             String event = args[args.size()-1];
             String sub_name;
             
             if (event.is_empty()) {
                 sub_name = name; // Direct callback name
             } else {
                 sub_name = name + "_" + event; // e.g. "Timer1_Timer"
             }
             
             // Construct args for Sub
             // Everything BEFORE the last 2 args are the signal parameters
             Array sub_args;
             for(int i=0; i < args.size() - 2; i++) {
                 sub_args.push_back(args[i]);
             }
             
             // Special handling for MenuClick to support custom callbacks
             if (event == "MenuClick" && sub_args.size() > 0) {
                 int id = sub_args[0];
                 // Find menu node by name
                 // We assume owner is Node
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                     // Note: find_child is slow, but Menus are not high freq
                     Node *menu = n->find_child(name, true, false);
                     // Fallback: search parent (VGASIC helper node pattern)
                     if (!menu && n->get_parent()) {
                         menu = n->get_parent()->find_child(name, true, false);
                     } 
                     if (menu) {
                         PopupMenu *pm = Object::cast_to<PopupMenu>(menu);
                         if (pm && pm->has_meta("callbacks")) {
                             Dictionary callback_map = pm->get_meta("callbacks");
                             if (callback_map.has(id)) {
                                 String callback = callback_map[id];
                                 if (!callback.is_empty()) {
                                     // Override target sub
                                     sub_name = callback;
                                     // Clear args? Helper usually doesn't take ID if it's specific.
                                     // "Sub OnExit()" vs "Sub OnExit(ID)"
                                     // Let's pass ID just in case.
                                 }
                             }
                         }
                     }
                 }
             }
             
             bool found = false;

             // Re-entrancy guard (Bug #3): if this sub is already executing
             // (e.g. blocked inside Proc.RunAndCapture), skip the phantom
             // repeat triggered by queued OS events.
             if (_active_signal_subs.has(sub_name)) {
                 if (r_return) *r_return = Variant();
                 r_error->error = GDEXTENSION_CALL_OK;
                 return;
             }
             _active_signal_subs.insert(sub_name);
             call_internal(sub_name, sub_args, found);

             // Unhandled runtime error → log, fire _OnError, or show dialog.
             report_unhandled_error(sub_name);
             _active_signal_subs.erase(sub_name);
             
             if (r_return) *r_return = Variant();
             r_error->error = GDEXTENSION_CALL_OK;
             return;
         }
    }

    // Intercept _OnArraySignal — VB6 control-array dispatcher.
    // Args: [SignalArg1, ..., SignalArgN, BaseName, EventName, ArrayIndex]
    // The handler is named <BaseName>_<EventName> and receives Index as its
    // first parameter, followed by the original signal args. All members of a
    // control array share the same handler.
    if (p_method == StringName("_OnArraySignal")) {
         if (args.size() >= 3) {
             String name = args[args.size()-3];
             String event = args[args.size()-2];
             int arr_idx = int(args[args.size()-1]);
             String sub_name = name + "_" + event;

             Array sub_args;
             sub_args.push_back(arr_idx);
             for(int i=0; i < args.size() - 3; i++) {
                 sub_args.push_back(args[i]);
             }

             bool found = false;

             // Re-entrancy guard (Bug #3): same as _OnSignal above.
             if (_active_signal_subs.has(sub_name)) {
                 if (r_return) *r_return = Variant();
                 r_error->error = GDEXTENSION_CALL_OK;
                 return;
             }
             _active_signal_subs.insert(sub_name);
             call_internal(sub_name, sub_args, found);

             // Unhandled runtime error → log, fire _OnError, or show dialog.
             report_unhandled_error(sub_name + " (Index " + String::num_int64(arr_idx) + ")");
             _active_signal_subs.erase(sub_name);

             if (r_return) *r_return = Variant();
             r_error->error = GDEXTENSION_CALL_OK;
             return;
         }
    }

    // Intercept _OnGuiInput — demuxes gui_input InputEvents into VB6 events
    // ArrayIndex == -1 means the control is NOT part of a VB6 control array;
    // otherwise it is prepended to every demuxed handler call as `Index`.
    if (p_method == StringName("_OnGuiInput")) {
         if (args.size() >= 3) {
             Ref<InputEvent> event = args[0];
             String ctrl_name = args[args.size() - 2];
             int gui_arr_idx = int(args[args.size() - 1]);
             bool is_array = (gui_arr_idx >= 0);

             // Check if the source control is a LineEdit (TextBox).
             // LineEdit already has text_submitted wired to _KeyPress, so we
             // must NOT fire _KeyPress from gui_input (every keystroke) — that
             // would cause each typed character to be treated as a submission.
             bool is_line_edit = false;
             Node *owner_node = Object::cast_to<Node>(owner);
             if (owner_node) {
                 Node *ctrl_node = owner_node->find_child(ctrl_name, true, false);
                 // Fallback: search parent (VGASIC helper node pattern)
                 if (!ctrl_node && owner_node->get_parent()) {
                     ctrl_node = owner_node->get_parent()->find_child(ctrl_name, true, false);
                 }
                 if (ctrl_node && ctrl_node->is_class("LineEdit")) {
                     is_line_edit = true;
                 }
             }

             if (event.is_valid()) {
                 Ref<InputEventMouseButton> mb = event;
                 Ref<InputEventMouseMotion> mm = event;
                 Ref<InputEventKey> key = event;

                 bool found = false;

                 // --- Mouse Button events ---
                 if (mb.is_valid()) {
                     int button = (int)mb->get_button_index();
                     int shift_state = 0;
                     if (mb->is_shift_pressed()) shift_state |= 1;
                     if (mb->is_ctrl_pressed())  shift_state |= 2;
                     if (mb->is_alt_pressed())   shift_state |= 4;
                     float x = mb->get_position().x;
                     float y = mb->get_position().y;

                     if (mb->is_pressed()) {
                         if (mb->is_double_click()) {
                             // DblClick
                             Array dbl_args;
                             if (is_array) dbl_args.push_back(gui_arr_idx);
                             call_internal(ctrl_name + "_DblClick", dbl_args, found);
                         } else {
                             // MouseDown(Button, Shift, X, Y)
                             Array md_args;
                             if (is_array) md_args.push_back(gui_arr_idx);
                             md_args.push_back(button);
                             md_args.push_back(shift_state);
                             md_args.push_back(x);
                             md_args.push_back(y);
                             call_internal(ctrl_name + "_MouseDown", md_args, found);

                             // Also fire Click for left button single-click
                             if (button == 1) {
                                 String click_sub = ctrl_name + "_Click";
                                 // Re-entrancy guard (Bug #3): skip if already
                                 // executing (blocked in a sync call).
                                 if (!_active_signal_subs.has(click_sub)) {
                                     _active_signal_subs.insert(click_sub);
                                     Array click_args;
                                     if (is_array) click_args.push_back(gui_arr_idx);
                                     call_internal(click_sub, click_args, found);
                                     _active_signal_subs.erase(click_sub);
                                 }
                             }
                         }
                     } else {
                         // MouseUp(Button, Shift, X, Y)
                         Array mu_args;
                         if (is_array) mu_args.push_back(gui_arr_idx);
                         mu_args.push_back(button);
                         mu_args.push_back(shift_state);
                         mu_args.push_back(x);
                         mu_args.push_back(y);
                         call_internal(ctrl_name + "_MouseUp", mu_args, found);
                     }
                 }

                 // --- Mouse Motion → MouseMove(Button, Shift, X, Y) ---
                 if (mm.is_valid()) {
                     int button_mask = (int)mm->get_button_mask();
                     int shift_state = 0;
                     if (mm->is_shift_pressed()) shift_state |= 1;
                     if (mm->is_ctrl_pressed())  shift_state |= 2;
                     if (mm->is_alt_pressed())   shift_state |= 4;
                     float x = mm->get_position().x;
                     float y = mm->get_position().y;

                     Array move_args;
                     if (is_array) move_args.push_back(gui_arr_idx);
                     move_args.push_back(button_mask);
                     move_args.push_back(shift_state);
                     move_args.push_back(x);
                     move_args.push_back(y);
                     call_internal(ctrl_name + "_MouseMove", move_args, found);
                 }

                 // --- Key events → KeyDown / KeyUp / KeyPress ---
                 if (key.is_valid()) {
                     int keycode = (int)key->get_keycode();
                     int shift_state = 0;
                     if (key->is_shift_pressed()) shift_state |= 1;
                     if (key->is_ctrl_pressed())  shift_state |= 2;
                     if (key->is_alt_pressed())   shift_state |= 4;

                     if (key->is_pressed() && !key->is_echo()) {
                         // KeyDown(KeyCode, Shift)
                         Array kd_args;
                         if (is_array) kd_args.push_back(gui_arr_idx);
                         kd_args.push_back(keycode);
                         kd_args.push_back(shift_state);
                         call_internal(ctrl_name + "_KeyDown", kd_args, found);

                         // KeyPress(KeyAscii) — only for printable characters
                         // Skip for LineEdit: text_submitted already wires _KeyPress on Enter
                         int unicode = (int)key->get_unicode();
                         if (unicode > 0 && !is_line_edit) {
                             Array kp_args;
                             if (is_array) kp_args.push_back(gui_arr_idx);
                             kp_args.push_back(unicode);
                             call_internal(ctrl_name + "_KeyPress", kp_args, found);
                         }
                     } else if (!key->is_pressed()) {
                         // KeyUp(KeyCode, Shift)
                         Array ku_args;
                         if (is_array) ku_args.push_back(gui_arr_idx);
                         ku_args.push_back(keycode);
                         ku_args.push_back(shift_state);
                         call_internal(ctrl_name + "_KeyUp", ku_args, found);
                     }
                 }
             }

             // Unhandled runtime error → log, fire _OnError, or show dialog.
             report_unhandled_error(ctrl_name);

             if (r_return) *r_return = Variant();
             r_error->error = GDEXTENSION_CALL_OK;
             return;
         }
    }

    bool found = false;

    // Guard: _Ready is handled exclusively by notification(NOTIFICATION_READY)
    // which also runs Form_Load and auto-wire signals.  Block the duplicate
    // ScriptInstance::call("_ready") from Godot engine to prevent double init.
    // Similarly guard _process, _physics_process, and _draw which are
    // already dispatched by our notification() handler.  Without these guards,
    // Godot's virtual-method dispatch calls them a SECOND time via call(),
    // causing double execution per frame.
    // NOTE: _input and _unhandled_input are NOT dispatched via notification —
    // they arrive exclusively through call(), so they must NOT be guarded here.
    {
        String guard_method = String(p_method).to_lower();
        if (guard_method == "_ready" || guard_method == "_process" ||
            guard_method == "_physics_process" || guard_method == "_draw") {
            if (r_return) *r_return = Variant();
            r_error->error = GDEXTENSION_CALL_OK;
            return;
        }
    }

    // Convert Godot snake_case to VG PascalCase for multi-word virtuals
    // e.g. "_unhandled_input" → "_UnhandledInput"
    String vg_method = godot_snake_to_vg_pascal(String(p_method));
    Variant ret = call_internal(vg_method, args, found);

    // If PascalCase lookup failed, try the original method name.
    // Signal handler callbacks (e.g. "_on_body_entered") are written in
    // snake_case WITH underscores in the VG source.  The PascalCase
    // conversion strips internal underscores ("_OnBodyEntered") which
    // won't match the actual sub name.
    if (!found && vg_method != String(p_method)) {
        ret = call_internal(String(p_method), args, found);
    }

    if (found) {
        if (r_return) *r_return = ret;
        r_error->error = GDEXTENSION_CALL_OK;
        
        // Unhandled runtime error → log, fire _OnError, or show dialog.
        report_unhandled_error(String(p_method));
        
        // After handling input events, trigger a redraw so visual changes
        // (e.g. updated display text) are painted on the next frame.
        // Without this, scripts that use _Draw() but not _Process() would
        // never repaint after user interaction.
        if (owner && script.is_valid()) {
            String ml = String(p_method).to_lower();
            if (ml.find("input") >= 0) {
                if (script->_has_method("_Draw") || script->_has_method("OnDraw")) {
                    CanvasItem *ci = Object::cast_to<CanvasItem>(owner);
                    if (ci) ci->queue_redraw();
                }
            }
        }
    } else {
        r_error->error = GDEXTENSION_CALL_ERROR_INVALID_METHOD;
    }
}

void VisualGasicInstance::raise_error(String msg, int code, const String &source) {
    // Update Err Object — create if it doesn't exist yet (v3.2 fix)
    Dictionary err;
    if (variables.has("Err")) {
        Variant v = variables["Err"];
        if (v.get_type() == Variant::DICTIONARY) {
            err = v;
        }
    }
    err["Number"] = code;
    err["Description"] = msg;
    err["Source"] = source.is_empty() ? String("VisualGasic Runtime") : source;
    variables["Err"] = err;

    if (error_state.has_error) return;
    error_state.has_error = true;
    error_state.message = msg;
    error_state.code = code;
    error_state.error_line = debug_state.current_line; // Capture line for Erl

    // Always log runtime errors — even when an On Error handler is active.
    // On Error Resume Next / Goto suppresses the DIALOG but should never
    // hide errors from the developer's Output panel.
    String sub_name = current_sub ? String(current_sub->name) : String("(unknown)");
    String script_path = script.is_valid() ? script->get_path() : String("(unknown)");
    if (error_state.mode == ErrorState::NONE) {
        UtilityFunctions::printerr("[VG Runtime Error ", code, "] ", msg,
            " — Sub: ", sub_name,
            " Line: ", debug_state.current_line,
            " (", script_path, ")");
    } else {
        // Handled by On Error — log at lower severity so it's visible but not alarming
        UtilityFunctions::print("[VG Handled Error ", code, "] ", msg,
            " — Sub: ", sub_name,
            " Line: ", debug_state.current_line,
            " (handled by On Error)");
    }
}

// ---------------------------------------------------------------------------
// report_unhandled_error: central handler for an unhandled runtime error that
// surfaced from an event Sub.  Every top-level dispatcher in call() invokes
// this after the user Sub returns.  It:
//   1. Logs the error to the Output panel (developer visibility).
//   2. Fires a synthetic _OnError(subName, errMessage, errNumber, errLine)
//      callback — if the form defines one — so user code can reset app-level
//      state (e.g. WorkerBusy = False, button captions) that the aborted Sub
//      never reached.  This is the fix for the "stuck WorkerBusy" class of bug:
//      when an event handler errors mid-way, its own cleanup code never runs,
//      so _OnError gives the form a single place to recover.
//   3. If no _OnError handler exists, falls back to the VB6-style native error
//      dialog so the failure is never silent.
// Re-entrancy: while _OnError runs, in_error_handler is set so a fresh error
// raised inside _OnError is reported directly instead of recursing.
// ---------------------------------------------------------------------------
void VisualGasicInstance::report_unhandled_error(const String &p_sub_name) {
    if (!error_state.has_error || error_state.mode != ErrorState::NONE) {
        return; // No unhandled error to report.
    }

    // Snapshot the error details before any dispatch mutates error_state.
    int err_code = error_state.code;
    String err_message = error_state.message;
    int err_line = error_state.error_line;

    UtilityFunctions::printerr(
        "Unhandled runtime error in '", p_sub_name, "': Error ",
        err_code, ": ", err_message, " (Line ", err_line, ")");

    // Clear now so the _OnError handler starts with a clean slate and so a
    // re-entrant error inside _OnError is reported directly (not recursed).
    error_state.has_error = false;
    error_state.mode = ErrorState::NONE;

    bool handled_by_user = false;
    if (!in_error_handler && script.is_valid() &&
        script->_has_method(StringName("_OnError"))) {
        in_error_handler = true;

        Array err_args;
        err_args.push_back(p_sub_name);
        err_args.push_back(err_message);
        err_args.push_back(err_code);
        err_args.push_back(err_line);

        bool found = false;
        call_internal("_OnError", err_args, found);
        handled_by_user = found;

        // If _OnError itself raised an unhandled error, report it directly —
        // never recurse back into this function.
        if (error_state.has_error && error_state.mode == ErrorState::NONE) {
            UtilityFunctions::printerr(
                "Unhandled runtime error inside _OnError: Error ",
                error_state.code, ": ", error_state.message,
                " (Line ", error_state.error_line, ")");
            error_state.has_error = false;
            error_state.mode = ErrorState::NONE;
        }

        in_error_handler = false;
    }

    // No user handler → VB6-style native dialog so the failure is visible.
    if (!handled_by_user) {
        String dlg = "Run-time error '" + String::num_int64(err_code) + "':\n\n" + err_message;
        if (err_line > 0) {
            dlg += "\n\nLine: " + String::num_int64(err_line);
        }
        VisualGasicBuiltins::native_msgbox(dlg, "VisualGasic", 0);
    }
}



// Static Helper for Auto-Connection
// ---------------------------------------------------------------------------
// _try_wire: Attempts to connect a Godot signal to a VB6-style event handler
// (e.g. "Button1_Click").  Returns true if the connection was made.
// ---------------------------------------------------------------------------
static bool _try_wire(Node* node, const String& name, const String& evt_name,
                      const String& signal_name, VisualGasicScript* vs,
                      Node* instance_owner, uint32_t flags = 0) {
    // VB6 control-array support: when this node was emitted with a disambiguated
    // sibling name, its logical VB6 base name lives in metadata/vb6_base_name.
    // All array members share the same <BaseName>_<Event> handler and receive
    // the array Index as the first argument.
    String vb_name = name;
    bool is_array_member = false;
    int arr_idx = -1;
    if (node->has_meta("vb6_base_name")) {
        vb_name = String(node->get_meta("vb6_base_name"));
    }
    if (node->has_meta("vb6_control_array_index")) {
        arr_idx = int(node->get_meta("vb6_control_array_index"));
        if (arr_idx >= 0) is_array_member = true;
    }

    String sub_name = vb_name + String("_") + evt_name;
    if (!vs->_has_method(sub_name)) return false;

    if (is_array_member) {
        Callable target(instance_owner, "_OnArraySignal");
        Array binds;
        binds.push_back(vb_name);
        binds.push_back(evt_name);
        binds.push_back(arr_idx);
        Callable bound = target.bindv(binds);
        if (!node->is_connected(signal_name, target)) {
            node->connect(signal_name, bound, flags);
        }
    } else {
        Callable target(instance_owner, "_OnSignal");
        Array binds;
        binds.push_back(vb_name);
        binds.push_back(evt_name);
        Callable bound = target.bindv(binds);

        if (!node->is_connected(signal_name, target)) {
            node->connect(signal_name, bound, flags);
        }
    }
    return true;
}

static void _connect_vb_signals_recursive(Node* node, VisualGasicInstance* instance, Node* instance_owner) {
    if (!node) return;

    String name = node->get_name();
    // Control-array members store their VB6 logical base name as metadata
    // (multiple siblings share it). Use that for handler lookup so all members
    // route to the same <BaseName>_<Event> sub.
    if (node->has_meta("vb6_base_name")) {
        name = String(node->get_meta("vb6_base_name"));
    }

    // Get VG script for _has_method checks
    Ref<Script> s = instance->get_script();
    VisualGasicScript *vs = Object::cast_to<VisualGasicScript>(s.ptr());
    if (!vs) {
        // Still recurse children even without a script
        int cc = node->get_child_count();
        for (int i = 0; i < cc; i++) {
            _connect_vb_signals_recursive(node->get_child(i), instance, instance_owner);
        }
        return;
    }

    // =====================================================================
    //  VB6 Event Wiring — comprehensive signal → Sub mapping
    //  Mirrors GasicForm::wire_events() so .vg scripts on any node work.
    // =====================================================================

    // --- BaseButton: Button, CheckBox, CheckButton, TextureButton, etc. ---
    if (Object::cast_to<BaseButton>(node)) {
        _try_wire(node, name, "Click",     "pressed",    vs, instance_owner);
        _try_wire(node, name, "MouseDown", "button_down", vs, instance_owner);
        _try_wire(node, name, "MouseUp",   "button_up",  vs, instance_owner);

        // CheckBox / CheckButton → Change (toggled)
        if (node->is_class("CheckBox") || node->is_class("CheckButton")) {
            _try_wire(node, name, "Change", "toggled", vs, instance_owner);
        }
        // OptionButton (ComboBox) → Change (item_selected)
        if (node->is_class("OptionButton")) {
            _try_wire(node, name, "Change", "item_selected", vs, instance_owner);
        }
    }

    // --- LineEdit (TextBox) ---
    else if (node->is_class("LineEdit")) {
        _try_wire(node, name, "Change",   "text_changed",   vs, instance_owner);
        // CONNECT_DEFERRED (1): run the VB6 KeyPress handler on the next
        // idle frame so that Godot's gui_input has fully returned first.
        // This prevents the LineEdit from losing focus after submission.
        _try_wire(node, name, "KeyPress", "text_submitted",  vs, instance_owner, 1);
        _try_wire(node, name, "GotFocus", "focus_entered",   vs, instance_owner);
        _try_wire(node, name, "LostFocus","focus_exited",    vs, instance_owner);
    }

    // --- TextEdit (TextArea / RichTextBox) ---
    else if (node->is_class("TextEdit")) {
        _try_wire(node, name, "Change",   "text_changed",  vs, instance_owner);
        _try_wire(node, name, "GotFocus", "focus_entered",  vs, instance_owner);
        _try_wire(node, name, "LostFocus","focus_exited",   vs, instance_owner);
    }

    // --- Range controls: Slider, ScrollBar, SpinBox, ProgressBar ---
    else if (node->is_class("HSlider") || node->is_class("VSlider") ||
             node->is_class("HScrollBar") || node->is_class("VScrollBar") ||
             node->is_class("SpinBox") || node->is_class("ProgressBar")) {
        _try_wire(node, name, "Change", "value_changed", vs, instance_owner);
        // Scroll alias for scrollbars
        if (node->is_class("HScrollBar") || node->is_class("VScrollBar")) {
            _try_wire(node, name, "Scroll", "value_changed", vs, instance_owner);
        }
    }

    // --- Timer ---
    else if (node->is_class("Timer")) {
        _try_wire(node, name, "Timer", "timeout", vs, instance_owner);
    }

    // --- Pass 3: AnimationPlayer ---
    else if (node->is_class("AnimationPlayer")) {
        _try_wire(node, name, "AnimationFinished", "animation_finished", vs, instance_owner);
        _try_wire(node, name, "AnimationStarted",  "animation_started",  vs, instance_owner);
        _try_wire(node, name, "AnimationChanged",  "animation_changed",  vs, instance_owner);
    }

    // --- Pass 3: Area2D / Area3D ---
    else if (node->is_class("Area2D") || node->is_class("Area3D")) {
        _try_wire(node, name, "BodyEntered", "body_entered", vs, instance_owner);
        _try_wire(node, name, "BodyExited",  "body_exited",  vs, instance_owner);
        _try_wire(node, name, "AreaEntered", "area_entered", vs, instance_owner);
        _try_wire(node, name, "AreaExited",  "area_exited",  vs, instance_owner);
    }

    // --- Pass 3: RigidBody2D / RigidBody3D ---
    else if (node->is_class("RigidBody2D") || node->is_class("RigidBody3D")) {
        _try_wire(node, name, "BodyEntered", "body_entered", vs, instance_owner);
        _try_wire(node, name, "BodyExited",  "body_exited",  vs, instance_owner);
        _try_wire(node, name, "Sleep",       "sleeping_state_changed", vs, instance_owner);
    }

    // --- Pass 3: NavigationAgent2D / 3D ---
    else if (node->is_class("NavigationAgent2D") || node->is_class("NavigationAgent3D")) {
        _try_wire(node, name, "TargetReached",      "target_reached",      vs, instance_owner);
        _try_wire(node, name, "NavigationFinished", "navigation_finished", vs, instance_owner);
        _try_wire(node, name, "WaypointReached",    "waypoint_reached",    vs, instance_owner);
    }

    // --- ItemList (ListBox) ---
    else if (node->is_class("ItemList")) {
        _try_wire(node, name, "Click",    "item_selected",  vs, instance_owner);
        _try_wire(node, name, "DblClick", "item_activated",  vs, instance_owner);
    }

    // --- Tree (TreeView) ---
    else if (node->is_class("Tree")) {
        _try_wire(node, name, "Click",        "item_selected",  vs, instance_owner);
        _try_wire(node, name, "DblClick",      "item_activated",  vs, instance_owner);
        _try_wire(node, name, "NodeSelected",  "item_selected",  vs, instance_owner);
        _try_wire(node, name, "Expand",        "item_collapsed",  vs, instance_owner);
    }

    // --- TabContainer (TabStrip) ---
    else if (node->is_class("TabContainer")) {
        _try_wire(node, name, "Click",  "tab_changed", vs, instance_owner);
        _try_wire(node, name, "Change", "tab_changed", vs, instance_owner);
    }

    // --- RichTextLabel ---
    else if (node->is_class("RichTextLabel")) {
        _try_wire(node, name, "Click", "meta_clicked", vs, instance_owner);
    }

    // --- Label — uses gui_input for Click/DblClick (no built-in pressed) ---
    else if (node->is_class("Label")) {
        // Labels need gui_input wiring — handled below in universal section
        // Ensure mouse events pass through
        if (vs->_has_method(name + "_Click") || vs->_has_method(name + "_DblClick") ||
            vs->_has_method(name + "_MouseDown") || vs->_has_method(name + "_MouseUp")) {
            node->set("mouse_filter", 0); // MOUSE_FILTER_STOP
        }
    }

    // --- Panel / ColorRect — also uses gui_input ---
    else if ((node->is_class("Panel") || node->is_class("ColorRect")) &&
             !Object::cast_to<BaseButton>(node)) {
        if (vs->_has_method(name + "_Click") || vs->_has_method(name + "_DblClick") ||
            vs->_has_method(name + "_MouseDown") || vs->_has_method(name + "_MouseUp")) {
            node->set("mouse_filter", 0); // MOUSE_FILTER_STOP
        }
    }

    // --- TextureRect (PictureBox) ---
    else if (node->is_class("TextureRect")) {
        if (vs->_has_method(name + "_Click") || vs->_has_method(name + "_DblClick") ||
            vs->_has_method(name + "_MouseDown") || vs->_has_method(name + "_MouseUp")) {
            node->set("mouse_filter", 0); // MOUSE_FILTER_STOP
        }
    }

    // --- MenuBar: wire each child PopupMenu's id_pressed ---
    else if (node->is_class("MenuBar")) {
        int mc = node->get_child_count();
        for (int m = 0; m < mc; m++) {
            Node* menu_child = node->get_child(m);
            if (menu_child && menu_child->is_class("PopupMenu")) {
                String menu_name = menu_child->get_name();
                _try_wire(menu_child, menu_name, "Click", "id_pressed", vs, instance_owner);
                _try_wire(menu_child, menu_name, "MenuClick", "id_pressed", vs, instance_owner);
            }
        }
    }

    // =====================================================================
    //  Universal events — any Control gets focus + mouse wiring
    // =====================================================================
    if (node->is_class("Control")) {
        // GotFocus / LostFocus (skip if already wired above for LineEdit/TextEdit)
        if (!node->is_class("LineEdit") && !node->is_class("TextEdit")) {
            _try_wire(node, name, "GotFocus",  "focus_entered", vs, instance_owner);
            _try_wire(node, name, "LostFocus", "focus_exited",  vs, instance_owner);
        }
        // MouseEnter / MouseExit
        _try_wire(node, name, "MouseMove", "mouse_entered", vs, instance_owner);
        _try_wire(node, name, "MouseExit", "mouse_exited",  vs, instance_owner);

        // Resize
        _try_wire(node, name, "Resize", "resized", vs, instance_owner);

        // gui_input for KeyDown, KeyUp, MouseDown, MouseUp, DblClick, MouseMove
        // We connect gui_input → _OnGuiInput which demuxes InputEvent types
        // Note: For LineEdit, _KeyPress is already handled by text_submitted signal,
        // so don't count it as a reason to wire gui_input.
        bool needs_gui_input = (
            vs->_has_method(name + "_KeyDown") ||
            vs->_has_method(name + "_KeyUp") ||
            (!node->is_class("LineEdit") && vs->_has_method(name + "_KeyPress")) ||
            vs->_has_method(name + "_MouseDown") ||
            vs->_has_method(name + "_MouseUp") ||
            vs->_has_method(name + "_DblClick") ||
            vs->_has_method(name + "_MouseMove")
        );
        if (needs_gui_input) {
            // Read array index from metadata so we can prepend it to handler args.
            int gui_arr_idx = -1;
            if (node->has_meta("vb6_control_array_index")) {
                gui_arr_idx = int(node->get_meta("vb6_control_array_index"));
            }
            Callable target(instance_owner, "_OnGuiInput");
            Array binds;
            binds.push_back(name);
            binds.push_back(gui_arr_idx);  // -1 = not an array member
            Callable bound = target.bindv(binds);
            if (!node->is_connected("gui_input", target)) {
                node->connect("gui_input", bound);
            }
            // Ensure mouse events are captured
            node->set("mouse_filter", 0); // MOUSE_FILTER_STOP
        }
    }

    // Recurse children
    int cc = node->get_child_count();
    for (int i = 0; i < cc; i++) {
        _connect_vb_signals_recursive(node->get_child(i), instance, instance_owner);
    }
}

void VisualGasicInstance::notification(int32_t p_what) {
    if (p_what == Node::NOTIFICATION_READY) {
         // Skip all script execution in editor mode
         if (Engine::get_singleton()->is_editor_hint()) {
             return;
         }

         // Guard against double _Ready calls from GDExtension lifecycle
         if (ready_executed) {
             return;
         }
         ready_executed = true;
         
         // === Parse-error diagnostics (VB6-style: warn but continue) ===
         // VB6 allows forms with parse errors to load — only the affected
         // Sub/Function fails at call time.  Log warnings but do NOT block
         // signal wiring or Form_Load execution.
         if (script.is_valid() && script->has_reload_errors()) {
             String script_path = script->get_path();
             UtilityFunctions::print_rich("[color=yellow][b]VisualGasic Warning:[/b] Script '" + script_path + "' has parse warnings. Affected Subs may fail at runtime.[/color]");
             const Vector<VisualGasicParser::ParsingError>& errors = script->get_parser_errors();
             for (int i = 0; i < errors.size(); i++) {
                 UtilityFunctions::print_rich(vformat("[color=yellow]  Line %d: %s[/color]", errors[i].line, errors[i].message));
             }
             // Do NOT return — continue with signal wiring and Form_Load
         }
         
         // NOTE: Instance registration is handled in C++ at construction time
         // (see VisualGasicDebug::register_instance call in constructor)
         // We do NOT call the GDScript debug_handler->register_instance() here
         // because it causes the Godot debugger to break into GDScript during
         // step debugging of VG scripts.
         
         // Lazy Init Processing if needed (e.g. if ast was null in constructor)
         if (owner && script.is_valid()) {
             Node* node = Object::cast_to<Node>(owner);
             if (node) {
                 if (!node->is_processing() && script->_has_method("_Process")) node->set_process(true);
                 if (!node->is_physics_processing() && script->_has_method("_PhysicsProcess")) node->set_physics_process(true);
                 if (!node->is_processing_input() && script->_has_method("_Input")) {
                     node->set_process_input(true);
                 }
                 if (!node->is_processing_unhandled_input() && script->_has_method("_UnhandledInput")) node->set_process_unhandled_input(true);
                 
                 // Run Auto-Wire for Signals
                 // If this node is not the scene root (e.g. "VGASIC" helper node),
                 // wire from the parent so sibling controls are found.
                 Node *wire_root = node;
                 if (node->get_parent() && node->get_name() == StringName("VGASIC")) {
                     wire_root = node->get_parent();
                 } else if (node->get_parent() && node->get_parent()->get_owner() == nullptr && !node->get_parent()->is_class("Window")) {
                     // Parent is the scene root (owner==null means it IS the root)
                     wire_root = node->get_parent();
                 }
                 _connect_vb_signals_recursive(wire_root, this, node);

                 // Pass-4 Android plugin: wire VGAndroidPlugin's permission /
                 // GPS / steps signals to global VG subs of matching names
                 // (Permission_Granted, Permission_Denied, GPS_Updated,
                 // Steps_Detected). Safe no-op on non-Android since the
                 // singleton isn't registered there.
                 Engine *e_and = Engine::get_singleton();
                 if (e_and && e_and->has_singleton("VGAndroidPlugin")) {
                     Object *plug = e_and->get_singleton("VGAndroidPlugin");
                     if (plug && script.is_valid()) {
                         struct { const char *signal; const char *vg_sub; } wires[] = {
                             { "permission_granted", "Permission_Granted" },
                             { "permission_denied",  "Permission_Denied"  },
                             { "gps_updated",        "GPS_Updated"        },
                             { "steps_detected",     "Steps_Detected"     },
                         };
                         Callable target(node, "_OnSignal");
                         for (int i = 0; i < 4; i++) {
                             if (!script->_has_method(wires[i].vg_sub)) continue;
                             Array binds;
                             binds.push_back(String(wires[i].vg_sub));
                             binds.push_back(String("")); // empty event → direct sub name
                             Callable bound = target.bindv(binds);
                             if (!plug->is_connected(wires[i].signal, target)) {
                                 plug->connect(wires[i].signal, bound);
                             }
                         }
                     }
                 }
             }
         }
         
         // Call Form_Load (VB6 form load event) if present
         if (script.is_valid()) {
             bool has_form_load = script->_has_method("Form_Load");
             if (has_form_load && !Engine::get_singleton()->is_editor_hint()) {
                 bool found;
                 call_internal("Form_Load", Array(), found);
                 // Clear any runtime error from Form_Load so it doesn't
                 // pollute subsequent button-click dispatches.  The error
                 // was already handled (Exception Assistant or msgbox) inside
                 // call_internal / try_recover_error.
                 error_state.has_error = false;
             }
         }

         // Call _Ready but NOT in editor mode (prevents game logic from running in editor)
         if (script.is_valid() && script->_has_method("_Ready") && !Engine::get_singleton()->is_editor_hint()) {
             bool found;
             call_internal("_Ready", Array(), found);
             error_state.has_error = false;  // Same cleanup as Form_Load above
         }
         
         // Run Auto-Wire again for nodes created in _Ready/Form_Load (Dynamic Controls)
         if (owner && !Engine::get_singleton()->is_editor_hint()) {
             Node* node = Object::cast_to<Node>(owner);
             if (node) _connect_vb_signals_recursive(node, this, node);
         }
    }
    else if (p_what == Node::NOTIFICATION_EXIT_TREE) {
         // Skip in editor mode
         if (Engine::get_singleton()->is_editor_hint()) {
             return;
         }
         
         // Call Form_Unload (VB6 form unload event) if present
         if (script.is_valid() && script->_has_method("Form_Unload")) {
             bool found;
             call_internal("Form_Unload", Array(), found);
         }
    }
    else if (p_what == Node::NOTIFICATION_PROCESS) {
         // Skip _Process in editor mode
         if (Engine::get_singleton()->is_editor_hint()) {
             return;
         }
         if (script.is_valid() && script->_has_method("_Process")) {
             double delta = 0.0;
             if (owner) {
                 Node* node = Object::cast_to<Node>(owner);
                 if (node) delta = node->get_process_delta_time();
             }
             
             Array args; 
             args.push_back(delta);
             
             bool found;
             call_internal("_Process", args, found);
             
             // Trigger redraw if script has a draw method
             if (owner && (script->_has_method("_Draw") || script->_has_method("OnDraw"))) {
                 CanvasItem *ci = Object::cast_to<CanvasItem>(owner);
                 if (ci) ci->queue_redraw();
             }
         }
    }
    else if (p_what == Node::NOTIFICATION_PHYSICS_PROCESS) {
         // Skip _PhysicsProcess in editor mode
         if (Engine::get_singleton()->is_editor_hint()) {
             return;
         }
         if (script.is_valid() && script->_has_method("_PhysicsProcess")) {
             double delta = 0.0;
             if (owner) {
                 Node* node = Object::cast_to<Node>(owner);
                 if (node) delta = node->get_physics_process_delta_time();
             }
             
             Array args; 
             args.push_back(delta);
             
             bool found;
             call_internal("_PhysicsProcess", args, found);
         }
    }
    // Handle Drawing
    else if (p_what == CanvasItem::NOTIFICATION_DRAW) {
         // Match _Process/_Ready: skip game draw handlers in the editor.
         // Without this, _Draw can run during scene edit / script reload while
         // _Ready is suppressed, so init like playerRaw = DataToArray(...) never
         // ran and Variant param subs fail on raw(0) ("Unsupported array base type").
         if (Engine::get_singleton()->is_editor_hint()) {
             return;
         }
         if (script.is_valid()) {
             bool found;
             Array args;
             if (script->_has_method("_Draw")) {
                 call_internal("_Draw", args, found);
             } else if (script->_has_method("OnDraw")) {
                 call_internal("OnDraw", args, found);
             }
             if (VGVectorCanvas2D *vc = Object::cast_to<VGVectorCanvas2D>(owner)) {
                 vc->ExecuteQueuedCommands();
             }
         }
    }
}

void VisualGasicInstance::to_string(GDExtensionBool *r_is_valid, GDExtensionStringPtr r_out) {
    if (r_is_valid) *r_is_valid = true;
    // To properly write to r_out, we would need to call the constructor via interface.
    // For now, let's leave it to default.
}

// Static Wrappers

static GDExtensionBool instance_set(GDExtensionScriptInstanceDataPtr p_instance, GDExtensionConstStringNamePtr p_name, GDExtensionConstVariantPtr p_value) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    return instance->set(*(const StringName *)p_name, *(const Variant *)p_value);
}

static GDExtensionBool instance_get(GDExtensionScriptInstanceDataPtr p_instance, GDExtensionConstStringNamePtr p_name, GDExtensionVariantPtr r_ret) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    return instance->get(*(const StringName *)p_name, *(Variant *)r_ret);
}

static const GDExtensionPropertyInfo *instance_get_property_list(GDExtensionScriptInstanceDataPtr p_instance, uint32_t *r_count) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    return instance->get_property_list(r_count);
}

static void instance_free_property_list(GDExtensionScriptInstanceDataPtr p_instance, const GDExtensionPropertyInfo *p_list, uint32_t p_count) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    instance->free_property_list(p_list, p_count);
}

static GDExtensionBool instance_property_can_revert(GDExtensionScriptInstanceDataPtr p_instance, GDExtensionConstStringNamePtr p_name) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    return instance->property_can_revert(*(const StringName *)p_name);
}

static GDExtensionBool instance_property_get_revert(GDExtensionScriptInstanceDataPtr p_instance, GDExtensionConstStringNamePtr p_name, GDExtensionVariantPtr r_ret) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    return instance->property_get_revert(*(const StringName *)p_name, *(Variant *)r_ret);
}

static GDExtensionObjectPtr instance_get_owner(GDExtensionScriptInstanceDataPtr p_instance) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    return AccessObject::get_internal_ptr(instance->get_owner());
}

static void instance_get_property_state(GDExtensionScriptInstanceDataPtr p_instance, GDExtensionScriptInstancePropertyStateAdd p_add_func, void *p_userdata) {
}

static GDExtensionObjectPtr instance_get_language(GDExtensionScriptInstanceDataPtr p_instance) {
    VisualGasicLanguage *lang = VisualGasicLanguage::get_singleton();
    return AccessObject::get_internal_ptr(lang);
}

static GDExtensionScriptInstancePtr instance_get_script(GDExtensionScriptInstanceDataPtr p_instance) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    Ref<Script> script = instance->get_script();
    return script.is_valid() ? AccessObject::get_internal_ptr(script.ptr()) : nullptr;
}

static GDExtensionBool instance_is_placeholder(GDExtensionScriptInstanceDataPtr p_instance) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    return instance->is_placeholder();
}

static GDExtensionBool instance_has_method(GDExtensionScriptInstanceDataPtr p_instance, GDExtensionConstStringNamePtr p_name) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    const StringName &name = *(const StringName *)p_name;
    
    // Check for internal debug methods
    if (name == StringName("_vg_get_all_variables") ||
        name == StringName("_vg_get_variable") ||
        name == StringName("_vg_set_variable") ||
        name == StringName("_vg_get_whenever_sections") ||
        name == StringName("_vg_set_whenever_active") ||
        name == StringName("_vg_profiler_enable") ||
        name == StringName("_vg_profiler_get_report") ||
        name == StringName("_vg_profiler_clear")) {
        return true;
    }
    
    Ref<Script> s = instance->get_script();
    VisualGasicScript *script = Object::cast_to<VisualGasicScript>(s.ptr());
    if (script) {
        return script->_has_method(name);
    }
    return false;
}

static void instance_call(GDExtensionScriptInstanceDataPtr p_instance, GDExtensionConstStringNamePtr p_method, const GDExtensionConstVariantPtr *p_args, GDExtensionInt p_argcount, GDExtensionVariantPtr r_return, GDExtensionCallError *r_error) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    instance->call(*(const StringName *)p_method, (const Variant **)p_args, p_argcount, (Variant *)r_return, r_error);
}

static void instance_notification(GDExtensionScriptInstanceDataPtr p_instance, int32_t p_what, GDExtensionBool p_reversed) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    instance->notification(p_what);
}

static void instance_to_string(GDExtensionScriptInstanceDataPtr p_instance, GDExtensionBool *r_is_valid, GDExtensionStringPtr r_out) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    instance->to_string(r_is_valid, r_out);
}

static void instance_ref_count_incremented(GDExtensionScriptInstanceDataPtr p_instance) {}
static GDExtensionBool instance_ref_count_decremented(GDExtensionScriptInstanceDataPtr p_instance) { return true; } 

static void instance_free(GDExtensionScriptInstanceDataPtr p_instance) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    memdelete(instance);
}

const GDExtensionScriptInstanceInfo3 *VisualGasicInstance::get_script_instance_info() {
    static GDExtensionScriptInstanceInfo3 info;
    static bool initialized = false;
    
    if (!initialized) {
        info.set_func = instance_set;
        info.get_func = instance_get;
        info.get_property_list_func = instance_get_property_list;
        info.free_property_list_func = instance_free_property_list;
        info.property_can_revert_func = instance_property_can_revert;
        info.property_get_revert_func = instance_property_get_revert;
        
        info.get_owner_func = instance_get_owner;
        info.get_property_state_func = instance_get_property_state;
        info.get_method_list_func = nullptr; 
        info.free_method_list_func = nullptr;
        info.get_property_type_func = nullptr;
        info.validate_property_func = nullptr;

        info.get_script_func = instance_get_script;
        info.is_placeholder_func = instance_is_placeholder;
        info.has_method_func = instance_has_method;
        info.call_func = instance_call;
        info.notification_func = instance_notification;
        info.to_string_func = instance_to_string;
        
        info.refcount_incremented_func = instance_ref_count_incremented;
        info.refcount_decremented_func = instance_ref_count_decremented;
        info.get_language_func = instance_get_language;
        info.free_func = instance_free;
        
        info.get_method_argument_count_func = nullptr;
        info.set_fallback_func = nullptr;
        info.get_fallback_func = nullptr;

        initialized = true;
    }
    
    return &info;
}

void VisualGasicInstance::assign_variable(const String& name, Variant val) {
    if (script.is_valid() && script->ast_root && script->ast_root->option_explicit) {
         if (!variables.has(name)) {
             bool is_prop = false;
             if (owner) {
                 Variant current = owner->get(name);
                 if (current.get_type() != Variant::NIL) {
                     is_prop = true;
                 } else {
                     String snake = name.to_snake_case();
                     if (snake != name) {
                         current = owner->get(snake);
                         if (current.get_type() != Variant::NIL) is_prop = true;
                     }
                 }
             }
             
             if (!is_prop) {
                 raise_error("Variable not defined: " + name + " (Option Explicit is On)");
                 return;
             }
         }
    }

    if (variables.has(name)) {
         if (name.nocasecmp_to("wheneverTriggered") == 0) {
         }
         Variant::Type target_type = variables[name].get_type();
         Variant::Type source_type = val.get_type();
         
         // Only coerce when the source and target are in compatible
         // numeric/bool/string families.  Assigning a String to a
         // numeric Variant (e.g. Dim v As Variant / v = 100 / v = "hi")
         // must NOT force the string through (double) — that silently
         // produces 0.0 and clobbers the value.  VB6 Variants are
         // truly polymorphic and accept any type.
         bool coerce = false;
         if (target_type == Variant::INT && (source_type == Variant::INT || source_type == Variant::FLOAT || source_type == Variant::BOOL)) {
             coerce = true;
         } else if (target_type == Variant::FLOAT && (source_type == Variant::INT || source_type == Variant::FLOAT || source_type == Variant::BOOL)) {
             coerce = true;
         } else if (target_type == Variant::STRING && source_type == Variant::STRING) {
             coerce = true;
         } else if (target_type == Variant::BOOL && (source_type == Variant::BOOL || source_type == Variant::INT)) {
             coerce = true;
         }
         
         if (coerce) {
             if (target_type == Variant::INT) {
                 variables[name] = (int64_t)val;
             } else if (target_type == Variant::FLOAT) {
                 variables[name] = (double)val;
             } else if (target_type == Variant::STRING) {
                 variables[name] = (String)val;
             } else if (target_type == Variant::BOOL) {
                 variables[name] = (bool)val;
             }
         } else {
             variables[name] = val;
         }
         if (name.nocasecmp_to("wheneverTriggered") == 0) {
         }
    } else if (owner) {
         Variant current = owner->get(name);
         if (current.get_type() != Variant::NIL) {
             owner->set(name, val);
             return;
         }
         // Snake_case fallback: Position → position, Rotation → rotation, etc.
         String snake = name.to_snake_case();
         if (snake != name) {
             current = owner->get(snake);
             if (current.get_type() != Variant::NIL) {
                 owner->set(snake, val);
                 return;
             }
         }
         variables[name] = val;
    } else {
         variables[name] = val;
    }
    
    // WithEvents auto-wiring (v3.5.0)
    // When a WithEvents variable is Set to an object, connect its signals
    // to any matching varname_SignalName subs in this module.
    if (with_events_vars.has(name) && val.get_type() == Variant::OBJECT) {
        Object *obj = val;
        if (obj && script.is_valid() && script->ast_root) {
            String prefix = name + String("_");
            for (int si = 0; si < script->ast_root->subs.size(); si++) {
                SubDefinition *sub = script->ast_root->subs[si];
                if (sub->name.begins_with(prefix)) {
                    String signal_name = sub->name.substr(prefix.length());
                    if (obj->has_signal(signal_name) && !obj->is_connected(signal_name, Callable(owner, sub->name))) {
                        obj->connect(signal_name, Callable(owner, sub->name));
                    }
                }
            }
        }
    }
    
    // Check for data breakpoint (watchpoint) - after assignment
    if (VisualGasicLanguage::check_watchpoint(name, val)) {
        // Watchpoint hit - variable value changed
        String path = script.is_valid() ? script->get_path() : "unknown";
        int line = debug_state.current_line > 0 ? debug_state.current_line : 0;
        VisualGasicLanguage::set_current_break_location(path, line);
        EngineDebugger* debugger = EngineDebugger::get_singleton();
        debugger->send_message("visualgasic:watchpoint_hit", 
            Array::make(name, variables.get(name, Variant()), val, path, line));
        VisualGasicLanguage::vg_debug_wait();
    }
    
    // Check Whenever sections for this variable
    check_whenever_conditions(name, val);
    
    // Check complex expression conditions
    check_expression_conditions();
}

void VisualGasicInstance::check_whenever_conditions(const String& variable_name, const Variant& new_value) {
    // Suppress during module-level initialization to prevent false triggers
    if (whenever_init_suppress) return;

    // Re-entrancy guard: if we're already evaluating Whenever callbacks,
    // don't re-enter (prevents infinite recursion when callbacks assign variables)
    if (whenever_evaluating) return;

    for (int i = 0; i < whenever_sections.size(); i++) {
        WheneverSection& section = whenever_sections.write[i];
        
        // Case-insensitive comparison for VB6 compatibility
        if (!section.is_active || section.variable_name.nocasecmp_to(variable_name) != 0) {
            continue;
        }
        
        bool condition_met = false;
        
        if (section.comparison_operator.to_lower() == "changes") {
            // Always trigger if value changed
            condition_met = (section.last_value != new_value);
        }
        else if (section.comparison_operator.to_lower() == "becomes") {
            // Trigger only on TRANSITION to the target value
            // (value was NOT the target before, and now IS the target)
            condition_met = (new_value == section.comparison_value && section.last_value != section.comparison_value);
        }
        else if (section.comparison_operator.to_lower() == "exceeds") {
            // Trigger only on TRANSITION: value was NOT above threshold, now IS above
            double new_num = (double)new_value;
            double old_num = (double)section.last_value;
            double threshold = (double)section.comparison_value;
            bool now_exceeds = (new_num > threshold);
            bool was_exceeding = (section.last_value.get_type() != Variant::NIL && old_num > threshold);
            condition_met = (now_exceeds && !was_exceeding);
        }
        else if (section.comparison_operator.to_lower() == "below") {
            // Trigger only on TRANSITION: value was NOT below threshold, now IS below
            double new_num = (double)new_value;
            double old_num = (double)section.last_value;
            double threshold = (double)section.comparison_value;
            bool now_below = (new_num < threshold);
            bool was_below = (section.last_value.get_type() != Variant::NIL && old_num < threshold);
            condition_met = (now_below && !was_below);
        }
        else if (section.comparison_operator.to_lower() == "between") {
            // Trigger only on TRANSITION into the range
            double new_num = (double)new_value;
            double min_val = (double)section.comparison_value;
            double max_val = (double)section.comparison_value2;
            bool now_between = (new_num >= min_val && new_num <= max_val);
            bool was_between = false;
            if (section.last_value.get_type() != Variant::NIL) {
                double old_num = (double)section.last_value;
                was_between = (old_num >= min_val && old_num <= max_val);
            }
            condition_met = (now_between && !was_between);
        }
        else if (section.comparison_operator.to_lower() == "contains") {
            // Trigger only on TRANSITION to containing the value
            String haystack = String(new_value);
            String needle = String(section.comparison_value);
            bool now_contains = haystack.contains(needle);
            bool was_containing = false;
            if (section.last_value.get_type() != Variant::NIL) {
                was_containing = String(section.last_value).contains(needle);
            }
            condition_met = (now_contains && !was_containing);
        }
        
        if (condition_met) {
            // Check debounce timing
            uint64_t current_time = Time::get_singleton()->get_ticks_msec();
            if (section.debounce_ms > 0 && (current_time - section.last_trigger_time) < section.debounce_ms) {
                // Skip this trigger due to debouncing
                section.last_value = new_value;  // Still update last value
                continue;
            }
            
            // Update last trigger time
            section.last_trigger_time = current_time;
            
            // Update last value for future comparisons
            section.last_value = new_value;
            
            // Set re-entrancy guard before calling callbacks
            whenever_evaluating = true;
            
            // Call all callback procedures
            Array empty_args;
            for (int j = 0; j < section.callback_procedures.size(); j++) {
                bool found = false;
                call_internal(section.callback_procedures[j], empty_args, found);
                
                if (!found) {
                    UtilityFunctions::print("Warning: Whenever callback procedure '", section.callback_procedures[j], "' not found");
                }
            }
            
            // Release re-entrancy guard
            whenever_evaluating = false;
        } else {
            // Update last value even if condition wasn't met (for "changes" tracking)
            section.last_value = new_value;
        }
    }
}

void VisualGasicInstance::check_expression_conditions() {
    // Suppress during module-level initialization
    if (whenever_init_suppress) return;

    // Re-entrancy guard: prevent infinite recursion when callbacks assign variables
    if (whenever_evaluating) return;

    for (int i = 0; i < whenever_sections.size(); i++) {
        WheneverSection& section = whenever_sections.write[i];
        
        if (!section.is_active || !section.condition_expression) {
            continue;
        }
        
        // Check debounce timing
        uint64_t current_time = Time::get_singleton()->get_ticks_msec();
        if (section.debounce_ms > 0 && (current_time - section.last_trigger_time) < section.debounce_ms) {
            continue;
        }
        
        // Evaluate the complex expression
        Variant result = evaluate_expression(section.condition_expression);
        bool condition_now = (bool)result;
        
        // Edge detection: only fire on false -> true transition
        bool was_true = section.last_condition_result;
        section.last_condition_result = condition_now;
        
        if (condition_now && !was_true) {
            // Update last trigger time
            section.last_trigger_time = current_time;
            
            // Set re-entrancy guard before calling callbacks
            whenever_evaluating = true;
            
            // Call all callback procedures
            Array empty_args;
            for (int j = 0; j < section.callback_procedures.size(); j++) {
                bool found = false;
                call_internal(section.callback_procedures[j], empty_args, found);
                
                if (!found) {
                    UtilityFunctions::print("Warning: Whenever callback procedure '", section.callback_procedures[j], "' not found");
                }
            }
            
            // Release re-entrancy guard
            whenever_evaluating = false;
        }
    }
}

String VisualGasicInstance::get_whenever_status() const {
    String status = "Whenever System Status:\n";
    status += "Total Sections: " + String::num(whenever_sections.size()) + "\n";
    
    int active_count = 0;
    for (int i = 0; i < whenever_sections.size(); i++) {
        const WheneverSection& section = whenever_sections[i];
        if (section.is_active) active_count++;
        
        String state = section.is_active ? "Active" : "Suspended";
        String callbacks = "";
        for (int j = 0; j < section.callback_procedures.size(); j++) {
            if (j > 0) callbacks += ", ";
            callbacks += section.callback_procedures[j];
        }
        status += "- " + section.section_name + " (" + section.variable_name + " " + 
                 section.comparison_operator + ") -> " + callbacks + " [" + state + "]\n";
    }
    
    status += "Active Sections: " + String::num(active_count) + "\n";
    return status;
}

void VisualGasicInstance::clear_whenever_sections() {
    whenever_sections.clear();
}

int VisualGasicInstance::get_active_whenever_count() const {
    int count = 0;
    for (int i = 0; i < whenever_sections.size(); i++) {
        if (whenever_sections[i].is_active) count++;
    }
    return count;
}

void VisualGasicInstance::cleanup_scoped_whenever(const String& scope_type, const String& scope_context) {
    for (int i = whenever_sections.size() - 1; i >= 0; i--) {
        const WheneverSection& section = whenever_sections[i];
        if (section.scope_type == scope_type && section.scope_context == scope_context) {
            whenever_sections.remove_at(i);
        }
    }
}

void VisualGasicInstance::enter_scope(const String& scope_name) {
    scope_stack.push_back(scope_name);
}

void VisualGasicInstance::exit_scope(const String& scope_name) {
    if (!scope_stack.is_empty() && scope_stack[scope_stack.size() - 1] == scope_name) {
        scope_stack.remove_at(scope_stack.size() - 1);
        
        // Cleanup local Whenever sections for this scope
        cleanup_scoped_whenever("local", scope_name);
    }
}

Dictionary VisualGasicInstance::get_debug_locals() const {
    // Return current local variables for debugger.
    // Prefers the live bytecode locals vector (debug_bc_locals) since
    // bytecode locals may not be synced to the variables dictionary.
    Dictionary locals;

    // If we're inside a bytecode frame, read directly from the locals vector.
    if (debug_bc_locals && debug_bc_chunk) {
        for (int i = 0; i < debug_bc_chunk->local_names.size() && i < debug_bc_locals->size(); i++) {
            const String &name = debug_bc_chunk->local_names[i];
            if (!name.is_empty() && !name.begins_with("__") && !builtin_constants.has(name)) {
                locals[name] = (*debug_bc_locals)[i];
            }
        }
        return locals;
    }

    // Fallback: AST interpreter path — read from variables dictionary.
    if (current_sub) {
        // Include parameters defined in current function
        for (int i = 0; i < current_sub->parameters.size(); i++) {
            String param_name = current_sub->parameters[i].name;
            if (variables.has(param_name)) {
                locals[param_name] = variables[param_name];
            }
        }
        // Include local variables declared with Dim in the function body
        for (int i = 0; i < current_sub->statements.size(); i++) {
            Statement* s = current_sub->statements[i];
            if (s && s->type == STMT_DIM) {
                DimStatement* dim = static_cast<DimStatement*>(s);
                if (variables.has(dim->variable_name)) {
                    locals[dim->variable_name] = variables[dim->variable_name];
                }
            }
        }
    }
    return locals;
}

Array VisualGasicInstance::get_debug_whenever_sections() const {
    // Return all Whenever sections for debugging
    Array result;
    for (int i = 0; i < whenever_sections.size(); i++) {
        const WheneverSection& section = whenever_sections[i];
        Dictionary info;
        info["name"] = section.section_name;
        info["variable"] = section.variable_name;
        info["operator"] = section.comparison_operator;
        info["value"] = section.comparison_value;
        info["value2"] = section.comparison_value2;
        info["is_active"] = section.is_active;
        info["last_value"] = section.last_value;
        info["last_trigger_time"] = (int64_t)section.last_trigger_time;
        info["scope_type"] = section.scope_type;
        info["scope_context"] = section.scope_context;
        info["callbacks"] = section.callback_procedures.size();
        
        // Build callback names string
        String callbacks_str;
        for (int j = 0; j < section.callback_procedures.size(); j++) {
            if (j > 0) callbacks_str += ", ";
            callbacks_str += section.callback_procedures[j];
        }
        info["callback_names"] = callbacks_str;
        
        result.push_back(info);
    }
    return result;
}

void VisualGasicInstance::set_whenever_section_active(const String& section_name, bool active) {
    for (int i = 0; i < whenever_sections.size(); i++) {
        if (whenever_sections[i].section_name == section_name) {
            whenever_sections.write[i].is_active = active;
            return;
        }
    }
}

Variant VisualGasicInstance::invoke_lambda(const Dictionary& lambda_dict, const Array& call_args) {
    if (!lambda_dict.has("__vg_lambda") || !(bool)lambda_dict["__vg_lambda"]) {
        return Variant();
    }
    LambdaNode* lam = (LambdaNode*)(uint64_t)lambda_dict["__vg_ast_ptr"];
    if (!lam) return Variant();

    // Save and bind parameters
    HashMap<String, Variant> saved_vars;
    Array param_names = lambda_dict["__vg_params"];
    for (int i = 0; i < param_names.size(); i++) {
        String pname = param_names[i];
        if (variables.has(pname)) saved_vars[pname] = variables[pname];
        if (i < call_args.size()) {
            variables[pname] = call_args[i];
        } else {
            variables[pname] = Variant();
        }
    }

    Variant lambda_result;
    if (lam->is_arrow && lam->body_expression) {
        lambda_result = evaluate_expression(lam->body_expression);
    } else {
        // Block lambda: save current_sub, set synthetic context for Return statement
        SubDefinition* prev_sub = current_sub;
        ErrorState prev_error = error_state;
        // Create a temporary sub definition for block lambda context
        SubDefinition lambda_sub;
        lambda_sub.name = "__lambda";
        lambda_sub.type = SubDefinition::TYPE_FUNCTION;
        current_sub = &lambda_sub;
        variables["__lambda"] = Variant(); // Initialize return variable

        for (int i = 0; i < lam->body_statements.size(); i++) {
            execute_statement(lam->body_statements[i]);
            // Check for Return statement (sets EXIT_SUB)
            if (error_state.has_error && error_state.mode == ErrorState::EXIT_SUB) {
                break;
            }
            if (variables.has("__vg_return_value")) {
                lambda_result = variables["__vg_return_value"];
                variables.erase("__vg_return_value");
                break;
            }
        }
        // Get return value: Return X sets variables["__lambda"]
        if (variables.has("__lambda") && variables["__lambda"].get_type() != Variant::NIL) {
            lambda_result = variables["__lambda"];
        }
        variables.erase("__lambda");
        // Clear EXIT_SUB state (not a real error for lambdas)
        if (error_state.has_error && error_state.mode == ErrorState::EXIT_SUB) {
            error_state = prev_error;
        }
        current_sub = prev_sub;
    }

    // Restore saved variables
    for (int i = 0; i < param_names.size(); i++) {
        String pname = param_names[i];
        if (saved_vars.has(pname)) {
            variables[pname] = saved_vars[pname];
        } else {
            variables.erase(pname);
        }
    }
    return lambda_result;
}

void VisualGasicInstance::_send_variables_to_debugger(EngineDebugger* debugger) {
    // Send all script variables to the editor for inspection
    if (!debugger) return;
    
    Dictionary vars;
    Array keys = variables.keys();
    for (int i = 0; i < keys.size(); i++) {
        String key = keys[i];
        // Skip internal objects that aren't user variables
        if (key != "Err" && key != "__vg_Printer" && !builtin_constants.has(key)) {
            Variant val = variables[key];
            // Convert complex types to string representation for display
            if (val.get_type() == Variant::OBJECT) {
                Object* obj = val;
                if (obj) {
                    vars[key] = String("<") + obj->get_class() + String(">");
                } else {
                    vars[key] = "Nothing";
                }
            } else {
                vars[key] = val;
            }
        }
    }

    // Include bytecode locals from the current execution frame.
    // These live on the stack, not in the variables dictionary.
    if (debug_bc_locals && debug_bc_chunk) {
        for (int i = 0; i < debug_bc_chunk->local_names.size() && i < debug_bc_locals->size(); i++) {
            const String &name = debug_bc_chunk->local_names[i];
            if (!name.is_empty() && !name.begins_with("__") && !builtin_constants.has(name) && !vars.has(name)) {
                Variant val = (*debug_bc_locals)[i];
                if (val.get_type() == Variant::OBJECT) {
                    Object* obj = val;
                    vars[name] = obj ? (String("<") + obj->get_class() + String(">")) : String("Nothing");
                } else {
                    vars[name] = val;
                }
            }
        }
    }
    
    Array data;
    data.push_back(vars);
    debugger->send_message("visualgasic:variables_list", data);
}

void VisualGasicInstance::_send_call_stack_to_debugger(EngineDebugger* debugger) {
    // Send current call stack to the editor
    if (!debugger) return;
    
    Array call_stack = VisualGasicLanguage::get_call_stack_array();
    
    Array data;
    data.push_back(call_stack);
    debugger->send_message("visualgasic:call_stack", data);
}

void VisualGasicInstance::assign_to_target(ExpressionNode* target, Variant val) {
    if (target->type == ExpressionNode::VARIABLE) {
         String name = ((VariableNode*)target)->name;
         assign_variable(name, val);
    } 
    else if (target->type == ExpressionNode::MEMBER_ACCESS) {
         MemberAccessNode* ma = (MemberAccessNode*)target;
         Variant base = evaluate_expression(ma->base_object);

         // Error on Nothing/Null base — user likely has a typo or control doesn't exist
         if (base.get_type() == Variant::NIL) {
             String base_name = "?";
             if (ma->base_object && ma->base_object->type == ExpressionNode::VARIABLE) {
                 base_name = ((VariableNode*)ma->base_object)->name;
             }
             raise_error("Object variable not set: '" + base_name + "' is Nothing (cannot access ." + ma->member_name + ")");
             return;
         }

         // VG class instance member assignment (object ID is an integer)
         if (base.get_type() == Variant::INT) {
             int obj_id = (int)base;
             if (object_instances.has(obj_id)) {
                 set_object_member(obj_id, ma->member_name, val);
                 return;
             }
         }

         if (base.get_type() == Variant::DICTIONARY) {
             Dictionary dict = base;
             // Strict struct member type checking
             if (dict.has(STRUCT_TYPE_KEY_CSTR)) {
                 String struct_type = dict[STRUCT_TYPE_KEY_CSTR];
                 val = coerce_struct_member(struct_type, ma->member_name, val);
             }
             dict[ma->member_name] = val;
             // Dictionaries are RefCounted handles, so modification sticks.
         } 
         else if (base.get_type() == Variant::OBJECT) {
             Object* obj = base;
             String prop_name = ma->member_name;
             
             // VB6 Property Aliasing — shared helper handles all 55+ aliases
             if (obj) {
                 if (_vb6_write_property(obj, prop_name, val)) {
                     // Fire _Change event for data-changing properties (VB6 compat)
                     if (prop_name == "Text" || prop_name == "Caption" || prop_name == "Value") {
                         Node* _ce_node = Object::cast_to<Node>(obj);
                         if (_ce_node) {
                             String _ce_sub = String(_ce_node->get_name()) + "_Change";
                             bool _ce_found = false;
                             call_internal(_ce_sub, Array(), _ce_found);
                         }
                     }
                     return;
                 }
                 
                 // Tree: Rows, Cols (not in shared helper — AST-specific)
                 if (obj->is_class("Tree")) {
                     if (prop_name == "Rows") {
                         Tree *t = Object::cast_to<Tree>(obj);
                         TreeItem *root = t->get_root();
                         if (root) {
                             int current = root->get_child_count();
                             int target_count = (int)val;
                             if (target_count > current) {
                                 for(int k=0; k < (target_count - current); k++) t->create_item(root);
                             } else if (target_count < current) {
                                  while(root->get_child_count() > target_count) {
                                      memdelete(root->get_child(root->get_child_count() - 1));
                                  }
                             }
                         }
                         return;
                     }
                     if (prop_name == "Cols") {
                         Object::cast_to<Tree>(obj)->set_columns((int)val);
                         return;
                     }
                 }
                 
                 // Range: Min, Max (not in shared helper — AST-specific)
                 if (obj->is_class("Range")) {
                      if (prop_name == "Min") { obj->set("min_value", val); return; }
                      if (prop_name == "Max") { obj->set("max_value", val); return; }
                 }
                 
                 // Timer.Enabled (start/stop)
                 if (obj->is_class("Timer") && prop_name == "Enabled") {
                      if ((bool)val) obj->call("start"); else obj->call("stop");
                      return;
                 }
             }

             if (obj) {
                 obj->set(prop_name, val);
                 // Fallback to snake_case (e.g. Text -> text)
                 if (obj->get(prop_name).get_type() == Variant::NIL && obj->get(prop_name.to_snake_case()).get_type() != Variant::NIL) {
                      obj->set(prop_name.to_snake_case(), val);
                 }
             }
         }
         else {
             // Handling Value Types (Vector2, etc.) for L-Value assignment
             // E.g. V.x = 10. `base` is V (copy). `base.set_named("x", 10)` modifes copy.
             // We modify the base value, then write it back to the base object (recursively).
             
             bool valid = false;
             base.set_named(ma->member_name, val, valid);
             
             if (!valid) {
                 // Try snake_case fallback
                 base.set_named(ma->member_name.to_snake_case(), val, valid);
             }

             if (valid) {
                 assign_to_target(ma->base_object, base);
                 return;
             }
             
             raise_error("Member assignment failed or not supported for this type: " + ma->member_name);
         }
    } 
    else if (target->type == ExpressionNode::ARRAY_ACCESS) {
         ArrayAccessNode* aa = (ArrayAccessNode*)target;
         
         // Get the variable name from the base
         String var_name;
         if (aa->base->type == ExpressionNode::VARIABLE) {
             var_name = ((VariableNode*)aa->base)->name;
         }
         
         Variant base = evaluate_expression(aa->base);

         // VB6 Dictionary.Item("key") = value pattern
         // Parser sees this as ArrayAccess(MemberAccess(dict, "Item"), [key])
         // We need to detect this and treat it as dict[key] = value
         if (base.get_type() == Variant::NIL && aa->base->type == ExpressionNode::MEMBER_ACCESS) {
             MemberAccessNode* ma = (MemberAccessNode*)aa->base;
             if (ma->member_name.nocasecmp_to("Item") == 0 && aa->indices.size() > 0) {
                 Variant dict_base = evaluate_expression(ma->base_object);
                 if (dict_base.get_type() == Variant::DICTIONARY) {
                     Dictionary d = dict_base;
                     Variant key = evaluate_expression(aa->indices[0]);
                     d[key] = val;
                     // Write back the dictionary to the source variable
                     if (ma->base_object->type == ExpressionNode::VARIABLE) {
                         String vn = ((VariableNode*)ma->base_object)->name;
                         assign_variable(vn, d);
                     }
                     return;
                 }
             }
         }

         if (base.get_type() == Variant::DICTIONARY) {
             if (aa->indices.size() > 0) {
                 Dictionary d = base;
                 Variant key = evaluate_expression(aa->indices[0]);
                 d[key] = val;
                 // Write back the dictionary to the variable
                 if (!var_name.is_empty()) {
                     assign_variable(var_name, d);
                 }
                 return;
             }
         }

         if (base.get_type() == Variant::OBJECT) {
             // MemoryBuffer byte-indexing: buf(i) = value -> buf.PokeByte(i, value)
             Object* obj = base;
             if (obj && aa->indices.size() == 1 && obj->has_method("PokeByte")) {
                 Variant idx = evaluate_expression(aa->indices[0]);
                 obj->call("PokeByte", idx, val);
                 return;
             }
         }

         if (base.get_type() != Variant::ARRAY) {
             raise_error("Expected Array for index access");
             return;
         }

         // Evaluate all indices upfront
         Vector<int64_t> indices;
         indices.resize(aa->indices.size());
         for (int i = 0; i < aa->indices.size(); i++) {
             indices.write[i] = (int64_t)evaluate_expression(aa->indices[i]);
         }

         // Simple 1D case
         if (indices.size() == 1) {
             Array arr = base;
             int idx = (int)indices[0];
             if (idx < 0 || idx >= arr.size()) {
                 raise_error("Array subscript out of range", 9);
                 return;
             }
             arr[idx] = val;
             if (!var_name.is_empty()) {
                 assign_variable(var_name, arr);
             }
             return;
         }

         // Multi-dimensional case: need to properly propagate changes back
         Vector<Array> arr_stack;
         Vector<int> idx_stack;
         Array root_arr = base;
         arr_stack.push_back(root_arr);

         // Navigate to the target, building a stack of arrays
         for (int i = 0; i < indices.size() - 1; i++) {
             int idx = (int)indices[i];
             Array current = arr_stack[arr_stack.size() - 1];
             if (idx < 0 || idx >= current.size()) {
                 raise_error("Array subscript out of range", 9);
                 return;
             }
             if (current[idx].get_type() != Variant::ARRAY) {
                 raise_error("Array assignment base must be an array");
                 return;
             }
             idx_stack.push_back(idx);
             arr_stack.push_back(current[idx]);
         }

         // Set the value in the innermost array
         Array innermost = arr_stack[arr_stack.size() - 1];
         int last_idx = (int)indices[indices.size() - 1];
         if (last_idx < 0 || last_idx >= innermost.size()) {
             raise_error("Array subscript out of range", 9);
             return;
         }
         innermost[last_idx] = val;
         // CRITICAL: Store the modified innermost back into arr_stack
         arr_stack.write[arr_stack.size() - 1] = innermost;

         // Propagate changes back up the stack
         for (int i = arr_stack.size() - 2; i >= 0; i--) {
             Array parent = arr_stack[i];
             int parent_idx = idx_stack[i];
             parent[parent_idx] = arr_stack[i + 1];
             arr_stack.write[i] = parent;
         }

         if (!var_name.is_empty()) {
             assign_variable(var_name, arr_stack[0]);
         }
    }
    else if (target->type == ExpressionNode::EXPRESSION_CALL) {
         CallExpression *call = (CallExpression *)target;
         if (call->base_object) {
             raise_error("Assignment to method calls is not supported");
             return;
         }
         String name = call->method_name;
         VariableNode base_var;
         base_var.name = name;
         Variant container = evaluate_expression(&base_var);
         if (container.get_type() == Variant::DICTIONARY) {
             if (call->arguments.size() != 1) {
                 raise_error("Dictionary assignment requires a single key");
                 return;
             }
             Dictionary dict = container;
             Variant key = evaluate_expression(call->arguments[0]);
             dict[key] = val;
             assign_variable(name, dict);
             return;
         }
         if (container.get_type() == Variant::ARRAY) {
             if (call->arguments.is_empty()) {
                 raise_error("Array assignment missing indices");
                 return;
             }
             Vector<int64_t> indices;
             indices.resize(call->arguments.size());
             for (int i = 0; i < call->arguments.size(); i++) {
                 indices.write[i] = (int64_t)evaluate_expression(call->arguments[i]);
             }

             // For multi-dimensional arrays, we need to track the path of arrays
             // so we can rebuild and reassign the entire structure
             if (indices.size() == 1) {
                 // Simple 1D case
                 Array arr = container;
                 int idx = (int)indices[0];
                 if (idx < 0 || idx >= arr.size()) {
                     raise_error("Array subscript out of range", 9);
                     return;
                 }
                 arr[idx] = val;
                 assign_variable(name, arr);
                 return;
             }

             // Multi-dimensional case: need to properly propagate changes back
             Vector<Array> arr_stack;
             Vector<int> idx_stack;
             Array root_arr = container;
             arr_stack.push_back(root_arr);

             // Navigate to the target, building a stack of arrays
             for (int i = 0; i < indices.size() - 1; i++) {
                 int idx = (int)indices[i];
                 Array current = arr_stack[arr_stack.size() - 1];
                 if (idx < 0 || idx >= current.size()) {
                     raise_error("Array subscript out of range", 9);
                     return;
                 }
                 if (current[idx].get_type() != Variant::ARRAY) {
                     raise_error("Array assignment base must be an array");
                     return;
                 }
                 idx_stack.push_back(idx);
                 arr_stack.push_back(current[idx]);
             }

             // Set the value in the innermost array
             Array innermost = arr_stack[arr_stack.size() - 1];
             int last_idx = (int)indices[indices.size() - 1];
             if (last_idx < 0 || last_idx >= innermost.size()) {
                 raise_error("Array subscript out of range", 9);
                 return;
             }
             innermost[last_idx] = val;

             // Propagate changes back up the stack
             for (int i = arr_stack.size() - 2; i >= 0; i--) {
                 Array parent = arr_stack[i];
                 int parent_idx = idx_stack[i];
                 parent[parent_idx] = arr_stack[i + 1];
                 arr_stack.write[i] = parent;
             }

             assign_variable(name, arr_stack[0]);
             return;
         }
         String err = "Unsupported array assignment base";
         if (!name.is_empty()) {
             err += ": " + name;
         }
         err += " (type " + Variant::get_type_name(container.get_type()) + ")";
         raise_error(err);
    }
}

// CallByName support — call a VG sub/function by string name
Variant VisualGasicInstance::call_method_by_name(const String &p_name, const Array &p_args) {
    if (!script.is_valid()) {
        raise_error("CallByName: no script loaded", 35);
        return Variant();
    }
    VisualGasicScript *vs = Object::cast_to<VisualGasicScript>(script.ptr());
    if (!vs || !vs->ast_root) {
        raise_error("CallByName: no AST available", 35);
        return Variant();
    }
    // Search for the sub/function in the AST
    for (int i = 0; i < vs->ast_root->subs.size(); i++) {
        if (vs->ast_root->subs[i]->name.nocasecmp_to(p_name) == 0) {
            // Found it — invoke via call_internal
            bool found = false;
            Variant result = call_internal(p_name, p_args, found);
            if (found) return result;
            return Variant();
        }
    }
    raise_error("Sub or Function not defined: " + p_name, 35);
    return Variant();
}

