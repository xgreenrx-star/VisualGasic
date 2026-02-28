Variant VisualGasicInstance::call_internal(const String& p_method, const Array& p_args, bool &r_found) {
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
    for(int i=0; i<script->ast_root->subs.size(); i++) {
        if (script->ast_root->subs[i]->name.nocasecmp_to(p_method) == 0) {
            func = script->ast_root->subs[i];
            break;
        }
    }
    
    if (!func) return Variant();
    r_found = true;

    // Save Context
    SubDefinition* prev_sub = current_sub;
    int prev_jump = jump_target;
    ErrorState prev_error = error_state;
    
    // Save local variables for recursion support
    // Only save variables the function will define: params, return var, and Dim'd locals
    Dictionary saved_locals;
    // Save parameters
    for(int i=0; i<func->parameters.size(); i++) {
        String pname = func->parameters[i].name;
        if (variables.has(pname)) saved_locals[pname] = variables[pname];
    }
    // Save function return variable
    if (func->type == SubDefinition::TYPE_FUNCTION) {
        if (variables.has(func->name)) saved_locals[func->name] = variables[func->name];
    }

    // v2.5: Use pre-computed local_names from bytecode instead of walking
    // the AST at runtime.  The compiler already collects every Dim/For/
    // ForEach variable name into BytecodeChunk::local_names, so we can
    // just iterate that flat vector — O(locals) instead of O(AST nodes).
    BytecodeChunk *chunk_for_locals = script.is_valid() ? script->get_bytecode_for(func->name) : nullptr;
    if (chunk_for_locals) {
        for (int i = 0; i < chunk_for_locals->local_names.size(); i++) {
            const String &lname = chunk_for_locals->local_names[i];
            if (!lname.is_empty() && variables.has(lname)) {
                saved_locals[lname] = variables[lname];
            }
        }
    } else {
        // Fallback: AST-only path (no bytecode compiled for this function).
        // Recursively scan for Dim'd variables in all nested blocks.
        struct DimScanner {
            static void scan(const Vector<Statement*>& stmts, Dictionary& vars, const Dictionary& all_vars) {
                for(int i=0; i<stmts.size(); i++) {
                    if (!stmts[i]) continue;
                    if (stmts[i]->type == STMT_DIM) {
                        DimStatement* ds = (DimStatement*)stmts[i];
                        if (all_vars.has(ds->variable_name))
                            vars[ds->variable_name] = all_vars[ds->variable_name];
                    } else if (stmts[i]->type == STMT_IF) {
                        IfStatement* ifs = (IfStatement*)stmts[i];
                        scan(ifs->then_branch, vars, all_vars);
                        scan(ifs->else_branch, vars, all_vars);
                    } else if (stmts[i]->type == STMT_FOR) {
                        ForStatement* fs = (ForStatement*)stmts[i];
                        if (all_vars.has(fs->variable_name))
                            vars[fs->variable_name] = all_vars[fs->variable_name];
                        scan(fs->body, vars, all_vars);
                    } else if (stmts[i]->type == STMT_WHILE) {
                        scan(((WhileStatement*)stmts[i])->body, vars, all_vars);
                    } else if (stmts[i]->type == STMT_DO) {
                        scan(((DoStatement*)stmts[i])->body, vars, all_vars);
                    } else if (stmts[i]->type == STMT_FOR_EACH) {
                        ForEachStatement* fes = (ForEachStatement*)stmts[i];
                        if (all_vars.has(fes->variable_name))
                            vars[fes->variable_name] = all_vars[fes->variable_name];
                        scan(fes->body, vars, all_vars);
                    }
                }
            }
        };
        DimScanner::scan(func->statements, saved_locals, variables);
    }
    
    // Arguments
    int max_params = func->parameters.size();
    // Use larger size if params exist, or args exist.
    // Actually we iterate params to define them.
    for(int i=0; i<max_params; i++) {
        Parameter& param = func->parameters.write[i];
        
        if (param.is_param_array) {
            // ParamArray collects all remaining arguments into an array
            Array rest;
            for(int k=i; k<p_args.size(); k++) {
                rest.push_back(p_args[k]);
            }
            variables[param.name] = rest;
            break; // ParamArray is always the last argument
        }
        
        if (i < p_args.size()) {
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

    current_sub = func;
    error_state.mode = ErrorState::NONE;
    error_state.has_error = false;
    error_state.label = "";

    // Push call stack frame for debugger
    String file_path = script.is_valid() ? script->get_path() : "";
    int start_line = func->statements.size() > 0 ? func->statements[0]->line : 0;
    VisualGasicLanguage::push_stack_frame(file_path, func->name, start_line, this);

    bool used_bytecode = false;
    Variant bytecode_ret;
    ErrorState bytecode_error_backup = error_state;
    if (chunk_for_locals) {
        // v2.5: No more variables.duplicate(true) deep copy!
        // execute_bytecode() now only flushes locals→variables on
        // success, so on failure the dictionary stays clean and the
        // AST fallback can re-execute without a rollback copy.
        used_bytecode = execute_bytecode(chunk_for_locals, func, bytecode_ret);
        if (!used_bytecode) {
            error_state = bytecode_error_backup;
        }
    }

    if (!used_bytecode) {
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
    
    // Pop call stack frame for debugger
    VisualGasicLanguage::pop_stack_frame();
    
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
            if (func->parameters[i].is_by_ref && variables.has(func->parameters[i].name)) {
                byref_captures.push_back({func->parameters[i].name, variables[func->parameters[i].name]});
            }
        }
    }

    // Restore
    current_sub = prev_sub;
    jump_target = prev_jump;
    error_state = prev_error;
    
    // Restore saved local variables for recursion support
    Array saved_keys = saved_locals.keys();
    for(int i=0; i<saved_keys.size(); i++) {
        variables[saved_keys[i]] = saved_locals[saved_keys[i]];
    }

    // Erase callee-introduced variables that did NOT exist in the caller's
    // scope before the call.  Without this, the function return variable
    // (e.g. "Scale") leaks into `variables` and the tree-walk evaluator's
    // ARRAY_ACCESS handler sees it as an Array/Dictionary instead of
    // dispatching a function call on subsequent invocations.
    // -- Function return variable
    if (func->type == SubDefinition::TYPE_FUNCTION && !saved_locals.has(func->name)) {
        variables.erase(func->name);
    }
    // -- Parameters
    for (int i = 0; i < func->parameters.size(); i++) {
        const String &pname = func->parameters[i].name;
        if (!saved_locals.has(pname)) {
            variables.erase(pname);
        }
    }
    // -- Dim'd locals
    if (chunk_for_locals) {
        for (int i = 0; i < chunk_for_locals->local_names.size(); i++) {
            const String &lname = chunk_for_locals->local_names[i];
            if (!lname.is_empty() && !saved_locals.has(lname)) {
                variables.erase(lname);
            }
        }
    }

    // Re-apply captured ByRef parameter values so the caller's
    // STMT_CALL ByRef write-back reads the correct post-execution values.
    for (int i = 0; i < byref_captures.size(); i++) {
        variables[byref_captures[i].first] = byref_captures[i].second;
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
    
    // Special debug introspection methods (allowed even in editor for debugging)
    if (p_method == StringName("_vg_get_all_variables")) {
        // Return all script variables for debugging
        Dictionary result;
        Array keys = variables.keys();
        for (int i = 0; i < keys.size(); i++) {
            String key = keys[i];
            // Skip internal constants starting with "vb"
            if (!key.begins_with("vb") && key != "Err") {
                result[key] = variables[key];
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
             call_internal(sub_name, sub_args, found);
             
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
    if (error_state.mode == ErrorState::NONE) {
        UtilityFunctions::print("Runtime Error ", code, ": ", msg);
    }
}



// Static Helper for Auto-Connection
static void _connect_vb_signals_recursive(Node* node, VisualGasicInstance* instance, Node* instance_owner) {
    if (!node) return;

    String name = node->get_name();
    String evt_name = "";
    String signal_name = "";
    
    // Debug Trace
    // UtilityFunctions::print("VisualGasic: Scanning ", name, " (", node->get_class(), ")");

    // Determine mapping using ClassDB or string checks for safety
    if (node->is_class("Button") || node->is_class("TextureButton") || node->is_class("CheckButton") || node->is_class("CheckBox") || Object::cast_to<BaseButton>(node)) {
        evt_name = "Click";
        signal_name = "pressed";
    } else if (node->is_class("LineEdit")) {
        evt_name = "Change";
        signal_name = "text_changed";
    } else if (node->is_class("TextEdit")) {
        evt_name = "Change";
        signal_name = "text_changed";
    } else if (node->is_class("HSlider") || node->is_class("VSlider") || node->is_class("HScrollBar") || node->is_class("VScrollBar")) {
        evt_name = "Change";
        signal_name = "value_changed";
    } else if (node->is_class("Timer")) {
        evt_name = "Timer";
        signal_name = "timeout";
    } else if (node->is_class("ItemList")) {
        evt_name = "Click";
        signal_name = "item_selected";
    } else if (node->is_class("OptionButton")) {
        evt_name = "Click";
        signal_name = "item_selected";
    }
    
    if (!evt_name.is_empty()) {
        String sub_name = name + "_" + evt_name;
        // UtilityFunctions::print("VisualGasic: Found Candidate ", sub_name);

        // Check if script has this method
        Ref<Script> s = instance->get_script();
        VisualGasicScript *vs = Object::cast_to<VisualGasicScript>(s.ptr());
        
        bool has_it = false;
        if (vs) {
             has_it = vs->_has_method(sub_name);
             // UtilityFunctions::print("VisualGasic: Script Has Method? ", has_it);
        } else {
             // UtilityFunctions::print("VisualGasic: Script Cast Failed");
        }
        
        if (has_it) {
            Callable target(instance_owner, "_OnSignal");
            
            // Re-connect always safe? Check if connected
            if (!node->is_connected(signal_name, target)) {
                Array binds;
                binds.push_back(name);
                binds.push_back(evt_name);
                
                node->connect(signal_name, target.bindv(binds));
                // UtilityFunctions::print("VisualGasic: Auto-Wired ", sub_name);
            } else {
                // UtilityFunctions::print("VisualGasic: Already Wired.");
            }
        }
    }
    
    // Recurse children

    int cc = node->get_child_count();
    for(int i=0; i<cc; i++) {
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
                 _connect_vb_signals_recursive(node, this, node);
             }
         }
         
         // Call Form_Load (VB6 form load event) if present
         if (script.is_valid()) {
             bool has_form_load = script->_has_method("Form_Load");
             if (has_form_load && !Engine::get_singleton()->is_editor_hint()) {
                 bool found;
                 call_internal("Form_Load", Array(), found);
             }
         }

         // Call _Ready but NOT in editor mode (prevents game logic from running in editor)
         if (script.is_valid() && script->_has_method("_Ready") && !Engine::get_singleton()->is_editor_hint()) {
             bool found;
             call_internal("_Ready", Array(), found);
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
         if (script.is_valid()) {
             bool found;
             Array args;
             if (script->_has_method("_Draw")) {
                 call_internal("_Draw", args, found);
             } else if (script->_has_method("OnDraw")) {
                 call_internal("OnDraw", args, found);
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
                 if (current.get_type() != Variant::NIL) is_prop = true;
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
         variables[name] = val;
    } else {
         variables[name] = val;
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
        // Use Godot's script_debug() for proper pause/resume
        VisualGasicLanguage* lang = VisualGasicLanguage::get_singleton();
        if (lang) {
            debugger->script_debug(lang, true, false);
        }
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
    // Return current local variables for debugger
    // Includes both function parameters and locally Dim'd variables
    Dictionary locals;
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
        // Skip internal constants starting with "vb" and the Err object
        if (!key.begins_with("vb") && key != "Err") {
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
             dict[ma->member_name] = val;
             // UtilityFunctions::print("Assigned to Dictionary Key: ", ma->member_name, " Value: ", val);
             // Dictionaries are RefCounted handles, so modification sticks.
         } 
         else if (base.get_type() == Variant::OBJECT) {
             Object* obj = base;
             String prop_name = ma->member_name;
             
             // VB6 Property Aliasing
             if (obj) {
                 if (obj->is_class("Tree")) {
                     if (prop_name == "Rows") {
                         Tree *t = Object::cast_to<Tree>(obj);
                         TreeItem *root = t->get_root();
                         if (root) {
                             int current = root->get_child_count();
                             int target = (int)val;
                             if (target > current) {
                                 for(int k=0; k < (target - current); k++) t->create_item(root);
                             } else if (target < current) {
                                  // Remove from end?
                                  while(root->get_child_count() > target) {
                                      memdelete(root->get_child(root->get_child_count() - 1));
                                  }
                             }
                         }
                         return;
                     }
                     if (prop_name == "Cols") {
                         Tree *t = Object::cast_to<Tree>(obj);
                         t->set_columns((int)val);
                         return;
                     }
                 }

                 if (obj->is_class("Node")) {
                      if (prop_name == "Caption") prop_name = "text";
                      else if (prop_name == "Text") prop_name = "text";  // LineEdit, Label, Button, etc.
                      else if (prop_name == "Tag") prop_name = "meta"; // Use meta for Tag? Or separate? 
                      
                      // Timer Compatibility
                      if (obj->is_class("Timer")) {
                          if (prop_name == "Interval") {
                               // VB6 Interval is ms, Godot wait_time is sec
                               double sec = (double)val / 1000.0;
                               obj->set("wait_time", sec);
                               return;
                          }
                          if (prop_name == "Enabled") {
                               bool en = (bool)val;
                               if (en) obj->call("start"); else obj->call("stop");
                               return;
                          }
                      }
                      
                      // Geometry Aliasing for Control/Node2D
                      bool is_control = obj->is_class("Control");
                      bool is_2d = obj->is_class("Node2D");
                      bool is_range = obj->is_class("Range");
                      
                      if (is_range) {
                           if (prop_name == "Min") { obj->set("min_value", val); return; }
                           if (prop_name == "Max") { obj->set("max_value", val); return; }
                           if (prop_name == "Value") { obj->set("value", val); return; }
                      }

                      if (is_control || is_2d) {
                          if (prop_name == "Left") {
                               if (is_control) { Control* c = Object::cast_to<Control>(obj); c->set_position(Vector2((double)val, c->get_position().y)); return; }
                               if (is_2d) { Node2D* n = Object::cast_to<Node2D>(obj); n->set_position(Vector2((double)val, n->get_position().y)); return; }
                          }
                          if (prop_name == "Top") {
                               if (is_control) { Control* c = Object::cast_to<Control>(obj); c->set_position(Vector2(c->get_position().x, (double)val)); return; }
                               if (is_2d) { Node2D* n = Object::cast_to<Node2D>(obj); n->set_position(Vector2(n->get_position().x, (double)val)); return; }
                          }
                      }
                      
                      if (is_control) {
                           Control* c = Object::cast_to<Control>(obj);
                           if (prop_name == "Width") { c->set_size(Vector2((double)val, c->get_size().y)); return; }
                           if (prop_name == "Height") { c->set_size(Vector2(c->get_size().x, (double)val)); return; }
                           if (prop_name == "Visible") { c->set_visible((bool)val); return; }
                           
                           // VB6 Enabled property - maps to Godot's disabled (inverted) or editable
                           if (prop_name == "Enabled") {
                               Variant test_disabled = obj->get("disabled");
                               if (test_disabled.get_type() == Variant::BOOL) {
                                   obj->set("disabled", !(bool)val);
                                   return;
                               }
                               // Fallback for LineEdit/TextEdit which use editable
                               Variant test_editable = obj->get("editable");
                               if (test_editable.get_type() == Variant::BOOL) {
                                   obj->set("editable", (bool)val);
                                   return;
                               }
                           }
                      }
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

