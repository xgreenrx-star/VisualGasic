void VisualGasicInstance::execute_statement(Statement* stmt) {
    if (!stmt) return;
    
    // Check for step debugging and breakpoints (for AST interpreter fallback when bytecode fails)
    if (stmt->line > 0 && script.is_valid()) {
        EngineDebugger* engine_debugger = EngineDebugger::get_singleton();
        String script_path = script->get_path();
        
        if (engine_debugger && engine_debugger->is_active() && !script_path.is_empty()) {
            bool should_break = false;
            
            // Check step mode first
            VGStepMode current_step_mode = VisualGasicLanguage::get_step_mode();
            if (current_step_mode != VG_STEP_NONE) {
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
                    
                    // Store breakpoint location before blocking (for editor query)
                    VisualGasicLanguage::set_current_break_location(script_path, stmt->line);
                    
                    // Send break notification directly to editor via EngineDebugger
                    Array break_data;
                    break_data.push_back(script_path);
                    break_data.push_back(stmt->line);
                    engine_debugger->send_message("visualgasic:break_hit", break_data);
                    
                    // Send current variables and call stack for inspection
                    _send_variables_to_debugger(engine_debugger);
                    _send_call_stack_to_debugger(engine_debugger);
                    
                    // Poll to ensure messages are sent before blocking
                    engine_debugger->line_poll();
                    
                    // Use Godot's script_debug() for proper pause/resume
                    VisualGasicLanguage* lang = VisualGasicLanguage::get_singleton();
                    if (lang) {
                        engine_debugger->script_debug(lang, true, false);
                    }
                }
            }
            
            // Check VGDebugHandler for breakpoints (using C++ check to avoid GDScript call during debug)
            if (!should_break) {
                bool has_bp = VisualGasicLanguage::has_breakpoint(script_path, stmt->line);
                
                if (has_bp) {
                    // Store breakpoint location before blocking (for editor query)
                    VisualGasicLanguage::set_current_break_location(script_path, stmt->line);
                    
                    // Send break notification directly to editor via EngineDebugger
                    Array break_data;
                    break_data.push_back(script_path);
                    break_data.push_back(stmt->line);
                    engine_debugger->send_message("visualgasic:break_hit", break_data);
                    
                    // Send current variables and call stack for inspection
                    _send_variables_to_debugger(engine_debugger);
                    _send_call_stack_to_debugger(engine_debugger);
                    
                    // Poll to ensure messages are sent before blocking
                    engine_debugger->line_poll();
                    
                    // Use Godot's script_debug() for proper pause/resume
                    VisualGasicLanguage* lang = VisualGasicLanguage::get_singleton();
                    if (lang) {
                        engine_debugger->script_debug(lang, true, false);
                    }
                }
            }
            
            // Also check conditional breakpoints via VisualGasicDebugger (AST path)
            if (!should_break) {
                VisualGasicDebugger* debugger = VisualGasicDebuggerGlobal::get_global_debugger();
                if (debugger) {
                    Dictionary context;
                    context["variables"] = variables;
                    if (current_sub) {
                        context["function"] = current_sub->name;
                    }
                    
                    if (debugger->should_break_at(script_path, stmt->line, context)) {
                        debug_state.debug_paused = true;
                        UtilityFunctions::print_rich("[color=cyan][VG Debug] Conditional breakpoint at ",
                            script_path, ":", stmt->line, "[/color]");
                        
                        if (current_sub) {
                            debugger->record_execution_frame(
                                current_sub->name,
                                script_path,
                                stmt->line,
                                variables
                            );
                        }
                        
                        // Send variables and call stack for inspection
                        _send_variables_to_debugger(engine_debugger);
                        _send_call_stack_to_debugger(engine_debugger);
                        
                        // Use Godot's script_debug() for proper pause/resume
                        VisualGasicLanguage* lang = VisualGasicLanguage::get_singleton();
                        if (lang) {
                            engine_debugger->script_debug(lang, true, false);
                        }
                    }
                }
            }
            
            // Check for pause request (Break/Pause button)
            if (!should_break && VisualGasicLanguage::is_break_requested()) {
                VisualGasicLanguage::clear_break_request();
                
                VisualGasicLanguage::set_current_break_location(script_path, stmt->line);
                
                Array break_data;
                break_data.push_back(script_path);
                break_data.push_back(stmt->line);
                engine_debugger->send_message("visualgasic:break_hit", break_data);
                
                _send_variables_to_debugger(engine_debugger);
                _send_call_stack_to_debugger(engine_debugger);
                engine_debugger->line_poll();
                
                VisualGasicLanguage* lang = VisualGasicLanguage::get_singleton();
                if (lang) {
                    engine_debugger->script_debug(lang, true, false);
                }
            }
        }
    }
    
    switch (stmt->type) {
        case STMT_PASS: break; // Do nothing
        case STMT_STOP: {
            // VB6 Stop statement: pause execution like a breakpoint
            EngineDebugger* stop_dbg = EngineDebugger::get_singleton();
            if (stop_dbg && stop_dbg->is_active()) {
                String stop_path;
                if (script.is_valid()) {
                    stop_path = script->get_path();
                }
                int stop_line = stmt->line;
                VisualGasicLanguage::set_current_break_location(stop_path, stop_line);
                Array break_data;
                break_data.push_back(stop_path);
                break_data.push_back(stop_line);
                stop_dbg->send_message("visualgasic:break_hit", break_data);
                _send_variables_to_debugger(stop_dbg);
                _send_call_stack_to_debugger(stop_dbg);
                stop_dbg->line_poll();
                VisualGasicLanguage* lang = VisualGasicLanguage::get_singleton();
                if (lang) {
                    stop_dbg->script_debug(lang, true, false);
                }
            } else {
                UtilityFunctions::print("[VG] Stop statement hit (no debugger attached)");
            }
            break;
        }
        case STMT_PRINT: {
            PrintStatement* s = (PrintStatement*)stmt;
            // Build combined output string
            String output;
            if (s->expression) {
                output += String(evaluate_expression(s->expression));
            }
            for (int ei = 0; ei < s->extra_expressions.size(); ei++) {
                output += String(evaluate_expression(s->extra_expressions[ei]));
            }
            if (s->file_number) {
                int fn = evaluate_expression(s->file_number);
                if (open_files.has(fn)) {
                     Ref<FileAccess> fa = open_files[fn];
                     if (s->suppress_newline) {
                         fa->store_string(output);
                     } else {
                         fa->store_line(output);
                     }
                } else {
                     raise_error("Bad File Name or Number");
                }
            } else if (s->is_debug) {
                UtilityFunctions::print(output);
                EngineDebugger* engine_debugger = EngineDebugger::get_singleton();
                if (engine_debugger && engine_debugger->is_active()) {
                    Array data;
                    data.push_back(output);
                    engine_debugger->send_message("visualgasic:debug_print", data);
                }
            } else {
                if (s->suppress_newline) {
                    // Print without trailing newline - use print_rich with no newline
                    UtilityFunctions::print_rich(output);
                } else {
                    UtilityFunctions::print(output);
                }
            }
            break;
        }
        case STMT_WRITE: {
            WriteStatement* s = (WriteStatement*)stmt;
            if (s->file_number) {
                int fn = evaluate_expression(s->file_number);
                if (open_files.has(fn)) {
                    Ref<FileAccess> fa = open_files[fn];
                    String line;
                    for (int i = 0; i < s->expressions.size(); i++) {
                        if (i > 0) line += ",";
                        Variant val = evaluate_expression(s->expressions[i]);
                        if (val.get_type() == Variant::STRING) {
                            line += "\"" + String(val) + "\"";
                        } else if (val.get_type() == Variant::BOOL) {
                            line += ((bool)val) ? "#TRUE#" : "#FALSE#";
                        } else {
                            line += String(val);
                        }
                    }
                    fa->store_line(line);
                } else {
                    raise_error("Bad File Name or Number");
                }
            }
            break;
        }
        case STMT_CONST: {
            ConstStatement* s = (ConstStatement*)stmt;
            Variant val = evaluate_expression(s->value);
            variables[s->name] = val; // Treat as variable for now
            break;
        }
        case STMT_DO_EVENTS: {
             DisplayServer::get_singleton()->process_events();
             // Maybe also add a small delay if needed? OS::get_singleton()->delay_usec(1);
             break;
        }
        case STMT_DIM: {
            DimStatement* s = (DimStatement*)stmt;
            
            // Static handling: persist variable across calls using static_variables store
            if (s->is_static) {
                String static_key = (current_sub ? current_sub->name + "." : String("")) + s->variable_name;
                if (static_variables.has(static_key)) {
                    variables[s->variable_name] = static_variables[static_key];
                    break;
                }
                // First time: continue to initialize, will be saved on function exit
            }
            
            if (s->array_sizes.size() > 0) {
                // Multidimensional: Create nested arrays
                Vector<int> dims;
                for(int i=0; i<s->array_sizes.size(); i++) {
                    dims.push_back((int)evaluate_expression(s->array_sizes[i]) + 1); // 0..N
                }
                
                struct ArrayBuilder {
                    static Array create(const Vector<int>& d, int depth, const String& type_name, const Dictionary& prototypes) {
                         Array a;
                         int size = d[depth];
                         a.resize(size);
                         if (depth < d.size() - 1) {
                             for(int i=0; i<size; i++) {
                                 a[i] = create(d, depth+1, type_name, prototypes);
                             }
                         } else {
                             // Leaf — initialize with correct typed default
                             if (!type_name.is_empty() && prototypes.has(type_name)) {
                                 for(int i=0; i<size; i++) {
                                     a[i] = ((Dictionary)prototypes[type_name]).duplicate(true);
                                 }
                             } else if (!type_name.is_empty()) {
                                 String tn = type_name.to_lower();
                                 Variant def_val;
                                 if (tn == "integer" || tn == "long" || tn == "longlong" || tn == "int") def_val = (int64_t)0;
                                 else if (tn == "single" || tn == "double" || tn == "float") def_val = 0.0;
                                 else if (tn == "string") def_val = String("");
                                 else if (tn == "boolean" || tn == "bool") def_val = false;
                                 // Only fill if we have a non-null default
                                 if (def_val.get_type() != Variant::NIL) {
                                     for(int i=0; i<size; i++) {
                                         a[i] = def_val;
                                     }
                                 }
                             }
                         }
                         return a;
                    }
                };
                
                variables[s->variable_name] = ArrayBuilder::create(dims, 0, s->type_name, struct_prototypes);

            } else if (s->is_dynamic_array) {
                // Dynamic array with empty parentheses: Dim arr() As Integer
                if (s->initializer) {
                    // Dynamic array with initializer: Dim arr() As String = Split(...)
                    Variant val = evaluate_expression(s->initializer);
                    variables[s->variable_name] = val;
                } else {
                    // Initialize as empty array, to be resized with ReDim later
                    variables[s->variable_name] = Array();
                }
            } else {
                if (s->initializer) {
                     Variant val = evaluate_expression(s->initializer);
                     if (!s->type_name.is_empty()) {
                         String t = s->type_name.to_lower();
                         if (t == "integer" || t == "long" || t == "longlong") val = (int64_t)val;
                         else if (t == "single" || t == "double") val = (double)val;
                         else if (t == "string") val = (String)val;
                         else if (t == "boolean") val = (bool)val;
                     }
                     // Generics Phase 1: set element_type on Collection(Of T) instances
                     if (!s->generic_type_param.is_empty() && val.get_type() == Variant::OBJECT) {
                         Object *obj = val;
                         if (obj && obj->has_method("set_element_type")) {
                             obj->call("set_element_type", s->generic_type_param);
                         }
                     }
                     variables[s->variable_name] = val;
                } else if (!s->type_name.is_empty()) {
                    if (struct_prototypes.has(s->type_name)) {
                        // Instantiate Struct
                        variables[s->variable_name] = ((Dictionary)struct_prototypes[s->type_name]).duplicate(true);
                    } else {
                        String t = s->type_name.to_lower();
                        if (t == "integer" || t == "long" || t == "longlong") variables[s->variable_name] = 0;
                        else if (t == "single" || t == "double") variables[s->variable_name] = 0.0;
                        else if (t == "string") variables[s->variable_name] = "";
                        else if (t == "boolean") variables[s->variable_name] = false;
                        else if (t == "dictionary") variables[s->variable_name] = Dictionary();
                        else if (t == "collection") {
                            // Auto-instantiate Collection (with optional generic type param)
                            Variant col = ClassDB::instantiate("VGCollection");
                            if (!s->generic_type_param.is_empty() && col.get_type() == Variant::OBJECT) {
                                Object *obj = col;
                                if (obj && obj->has_method("set_element_type")) {
                                    obj->call("set_element_type", s->generic_type_param);
                                }
                            }
                            variables[s->variable_name] = col;
                        }
                        else variables[s->variable_name] = Variant();
                    }
                } else {
                    variables[s->variable_name] = Variant();
                }
            }
            break;
        }
        case STMT_DATA: {
             // Do nothing at runtime, handled by scan
             break;
        }
        case STMT_READ: {
             ReadStatement* s = (ReadStatement*)stmt;
             for(int i=0; i<s->targets.size(); i++) {
                 if (data_pointer >= data_segments.size()) {
                     raise_error("Out of Data");
                     break;
                 }
                 Variant val = evaluate_expression(data_segments[data_pointer]);
                 data_pointer++;
                 // Typed Read coercion (Read x As Integer)
                 if (i < s->type_names.size() && !s->type_names[i].is_empty()) {
                     val = coerce_to_type(val, s->type_names[i]);
                 }
                 assign_to_target(s->targets[i], val);
             }
             break;
        }
        case STMT_RESTORE: {
             RestoreStatement* s = (RestoreStatement*)stmt;
             if (s->label_name.is_empty()) {
                 data_pointer = 0;
             } else {
                 String key = s->label_name.to_lower();
                 if (label_to_data_index.has(key)) {
                     data_pointer = (int)label_to_data_index[key];
                 } else {
                     raise_error("Label not found for Restore: " + s->label_name);
                 }
             }
             break;
        }
        case STMT_ASSIGNMENT: {
            AssignmentStatement* s = (AssignmentStatement*)stmt;
            Variant val = evaluate_expression(s->value);
            assign_to_target(s->target, val);
            break;
        }
        case STMT_IF: {
            IfStatement* s = (IfStatement*)stmt;
            if (evaluate_expression(s->condition).booleanize()) {
                for(int i=0; i<s->then_branch.size(); i++) execute_statement(s->then_branch[i]);
            } else {
                for(int i=0; i<s->else_branch.size(); i++) execute_statement(s->else_branch[i]);
            }
            break;
        }
        case STMT_WITH: {
             WithStatement* s = (WithStatement*)stmt;
             Variant context = evaluate_expression(s->expression);
             with_stack.push_back(context);
             
             for(int i=0; i<s->body.size(); i++) {
                 execute_statement(s->body[i]);
                 if (error_state.has_error || error_state.mode != ErrorState::NONE) break;
             }
             
             if (!with_stack.is_empty()) with_stack.remove_at(with_stack.size() - 1);
             break;
        }
        case STMT_FOR_EACH: {
             ForEachStatement* s = (ForEachStatement*)stmt;
             Variant col = evaluate_expression(s->collection);
             bool has_index = !s->index_variable_name.is_empty();
             
             if (col.get_type() == Variant::ARRAY) {
                 Array arr = col;
                 for(int i=0; i<arr.size(); i++) {
                     assign_variable(s->variable_name, arr[i]);
                     if (has_index) assign_variable(s->index_variable_name, i);
                     
                     for(int b=0; b<s->body.size(); b++) {
                         execute_statement(s->body[b]);
                         if (error_state.has_error) break;
                         if (error_state.mode == ErrorState::EXIT_FOR) break;
                         if (error_state.mode != ErrorState::NONE) break;
                     }
                     
                     if (error_state.has_error) break;
                     if (error_state.mode == ErrorState::EXIT_FOR) {
                         error_state.mode = ErrorState::NONE;
                         break;
                     }
                     if (error_state.mode != ErrorState::NONE) break;
                 }
             } else if (col.get_type() == Variant::DICTIONARY) {
                 Dictionary dict = col;
                 Array keys = dict.keys();
                 for(int i=0; i<keys.size(); i++) {
                     assign_variable(s->variable_name, keys[i]);
                     if (has_index) assign_variable(s->index_variable_name, i);
                     
                     for(int b=0; b<s->body.size(); b++) {
                         execute_statement(s->body[b]);
                         if (error_state.has_error) break;
                         if (error_state.mode == ErrorState::EXIT_FOR) break;
                         if (error_state.mode != ErrorState::NONE) break;
                     }
                     
                     if (error_state.has_error) break;
                     if (error_state.mode == ErrorState::EXIT_FOR) {
                         error_state.mode = ErrorState::NONE;
                         break;
                     }
                     if (error_state.mode != ErrorState::NONE) break;
                 }
             } else if (col.get_type() == Variant::STRING) {
                 // Iterate characters of a string
                 String str = col;
                 for(int i=0; i<str.length(); i++) {
                     assign_variable(s->variable_name, String(String::chr(str[i])));
                     if (has_index) assign_variable(s->index_variable_name, i);
                     
                     for(int b=0; b<s->body.size(); b++) {
                         execute_statement(s->body[b]);
                         if (error_state.has_error) break;
                         if (error_state.mode == ErrorState::EXIT_FOR) break;
                         if (error_state.mode != ErrorState::NONE) break;
                     }
                     if (error_state.has_error) break;
                     if (error_state.mode == ErrorState::EXIT_FOR) {
                         error_state.mode = ErrorState::NONE;
                         break;
                     }
                     if (error_state.mode != ErrorState::NONE) break;
                 }
             } else {
                 raise_error("For Each requires an Array, Dictionary, or String");
             }
             break;
        }
        
        case STMT_FOR: {
            ForStatement* s = (ForStatement*)stmt;
            String var = s->variable_name;
            Variant start = evaluate_expression(s->from_val);
            Variant end = evaluate_expression(s->to_val);
            Variant step = s->step_val ? evaluate_expression(s->step_val) : Variant(1);
            
            // UtilityFunctions::print("FOR Loop: ", var, " from ", start, " to ", end, " step ", step);

            assign_variable(var, start);
            
            int safety = 0;
            while (safety < 10000000) {
                 Variant current = variables[var];
                 // UtilityFunctions::print("  Loop iter: ", current);

                 bool condition = false;
                 Variant res; bool valid;
                 if (double(step) >= 0) {
                     Variant::evaluate(Variant::OP_LESS_EQUAL, current, end, res, valid);
                     condition = res.booleanize();
                 } else {
                     Variant::evaluate(Variant::OP_GREATER_EQUAL, current, end, res, valid);
                     condition = res.booleanize();
                 }
                 
                 if (!condition) break;
                 
                 for(int i=0; i<s->body.size(); i++) {
                     execute_statement(s->body[i]);
                     if (error_state.has_error) break;
                 }
                 
                 if (error_state.has_error) {
                     if (error_state.mode == ErrorState::CONTINUE_FOR) {
                         error_state.has_error = false;
                         error_state.mode = ErrorState::NONE;
                         // Increment and continue
                         Variant res; bool valid;
                         Variant::evaluate(Variant::OP_ADD, variables[var], step, res, valid);
                         assign_variable(var, res);
                         safety++;
                         continue;
                     }

                     if (error_state.mode == ErrorState::EXIT_FOR) {
                         error_state.has_error = false;
                         error_state.mode = ErrorState::NONE;
                         break;
                     }
                     break; // Propagate other errors/exits
                 }
                 
                 Variant::evaluate(Variant::OP_ADD, variables[var], step, res, valid);
                 assign_variable(var, res);
                 safety++;
            }
            break;
        }
        case STMT_WHILE: {
            WhileStatement* s = (WhileStatement*)stmt;
            int safety = 0;
            while (safety < 10000) {
                if (!evaluate_expression(s->condition).booleanize()) break;
                for(int i=0; i<s->body.size(); i++) {
                    execute_statement(s->body[i]);
                    if (error_state.has_error) break;
                }
                
                if (error_state.has_error) {
                     if (error_state.mode == ErrorState::CONTINUE_WHILE || error_state.mode == ErrorState::CONTINUE_DO) {
                         error_state.has_error = false;
                         error_state.mode = ErrorState::NONE;
                         safety++;
                         continue; // Next iteration
                     }
                     if (error_state.mode == ErrorState::EXIT_DO) {
                         error_state.has_error = false;
                         error_state.mode = ErrorState::NONE;
                         break;
                     }
                     break;
                }
                
                safety++;
            }
            if (safety >= 10000) UtilityFunctions::print("Runtime: While loop limit reached.");
            break;
        }
        case STMT_DO: {
            DoStatement* s = (DoStatement*)stmt;
            int safety = 0;
            while (safety < 10000) {
                // Pre Check
                if (!s->is_post_condition && s->condition_type != DoStatement::NONE) {
                    bool res = evaluate_expression(s->condition).booleanize();
                    if (s->condition_type == DoStatement::WHILE && !res) break;
                    if (s->condition_type == DoStatement::UNTIL && res) break;
                }
                
                for(int i=0; i<s->body.size(); i++) {
                    execute_statement(s->body[i]);
                    if (error_state.has_error) break;
                }
                
                if (error_state.has_error) {
                     if (error_state.mode == ErrorState::CONTINUE_DO) {
                         error_state.has_error = false;
                         error_state.mode = ErrorState::NONE;
                         
                         // Handle Post-Condition Check for Continue Do
                         if (s->is_post_condition && s->condition_type != DoStatement::NONE) {
                             bool res = evaluate_expression(s->condition).booleanize();
                             if (s->condition_type == DoStatement::WHILE && !res) break;
                             if (s->condition_type == DoStatement::UNTIL && res) break;
                         }
                         
                         safety++;
                         continue;
                     }

                     if (error_state.mode == ErrorState::EXIT_DO) {
                         error_state.has_error = false;
                         error_state.mode = ErrorState::NONE;
                         break;
                     }
                     break; 
                }
                
                // Post Check
                if (s->is_post_condition && s->condition_type != DoStatement::NONE) {
                    bool res = evaluate_expression(s->condition).booleanize();
                    if (s->condition_type == DoStatement::WHILE && !res) break;
                    if (s->condition_type == DoStatement::UNTIL && res) break;
                }
                
                safety++;
            }
            if (safety >= 10000) UtilityFunctions::print("Runtime: Do loop limit reached.");
            break;
        }

        case STMT_RETURN: {
            ReturnStatement* ret = (ReturnStatement*)stmt;
            if (ret->return_value) {
                if (current_sub) {
                    variables[current_sub->name] = evaluate_expression(ret->return_value);
                }
            } else if (gosub_return_stack.size() > 0) {
                // Bare "Return" with GoSub context — return to GoSub caller
                jump_target = gosub_return_stack[gosub_return_stack.size() - 1] - 1;
                gosub_return_stack.resize(gosub_return_stack.size() - 1);
                break;
            }
            error_state.has_error = true; 
            error_state.mode = ErrorState::EXIT_SUB; 
            // EXIT_SUB works for Function too
            break;
        }
        
        case STMT_CONTINUE: {
            ContinueStatement* cont = (ContinueStatement*)stmt;
            error_state.has_error = true;
            if (cont->loop_type == ContinueStatement::FOR) error_state.mode = ErrorState::CONTINUE_FOR;
            else if (cont->loop_type == ContinueStatement::DO) error_state.mode = ErrorState::CONTINUE_DO;
            else if (cont->loop_type == ContinueStatement::WHILE) error_state.mode = ErrorState::CONTINUE_WHILE;
            else error_state.mode = ErrorState::NONE; // Unknown?
            break;
        }

        case STMT_CALL: {
            CallStatement* s = (CallStatement*)stmt;
            Array call_args;
            int arg_count = s->arguments.size();
            for(int i=0; i<arg_count; i++) {
                call_args.push_back(evaluate_expression(s->arguments[i]));
            }

            // Try centralized statement-level builtins first
            {
                Variant _bg_ret;
                bool _bg_found = false;
                if (VisualGasicBuiltins::call_builtin(this, s->method_name, call_args, _bg_ret, _bg_found)) {
                    if (_bg_found) break;
                }
            }

            if (s->method_name.nocasecmp_to("TweenProperty") == 0) {
                 if (call_args.size() == 4) {
                      Object *obj = call_args[0];
                      String prop = call_args[1];
                      Variant final_val = call_args[2];
                      double duration = call_args[3];
                      if (obj && owner) {
                           Node *n = Object::cast_to<Node>(owner);
                           if (n) {
                                Ref<Tween> t = n->create_tween();
                                t->tween_property(obj, NodePath(prop), final_val, duration);
                           }
                      }
                      break; 
                 }
            }


            if (s->base_object) {
                // Delegate variable-base builtins (Clipboard etc.) to centralized handler
                 if (s->base_object->type == ExpressionNode::VARIABLE) {
                     String var_name = ((VariableNode*)s->base_object)->name;
                     Variant _var_ret;
                     if (VisualGasicBuiltins::call_builtin_for_base_variable(this, var_name, s->method_name, call_args, _var_ret)) {
                         break;
                     }
                 }
                 
                Variant base = evaluate_expression(s->base_object);

                    // Let builtins handle dictionary/object cases first
                    {
                        Variant _bb_ret;
                        if (VisualGasicBuiltins::call_builtin_for_base_variant(this, base, s->method_name, call_args, _bb_ret)) {
                            break;
                        }
                    }
                
                    // VG class instance method call (object ID is an integer)
                    if (base.get_type() == Variant::INT) {
                        int obj_id = (int)base;
                        if (object_instances.has(obj_id)) {
                            call_object_method(obj_id, s->method_name, call_args);
                            break;
                        }
                    }

                    if (base.get_type() == Variant::OBJECT) {
                        Object* obj = base;
                    if (obj) {
                         // FlexGrid / Tree Helpers
                         if (obj->is_class("Tree")) {
                             if (s->method_name == "SetTextMatrix" && call_args.size() >= 3) {
                                 Tree *t = Object::cast_to<Tree>(obj);
                                 int row = call_args[0];
                                 int col = call_args[1];
                                 String text = call_args[2];
                                 
                                 // Access item. Tree items are hierarchical.
                                 // If used as simple grid, we assume flat list under root.
                                 // Row 0 is header usually? No, header is separate.
                                 // Let's assume Row indices match get_child index.
                                 TreeItem *root = t->get_root();
                                 if (root && row >= 0 && row < root->get_child_count()) {
                                     TreeItem *it = root->get_child(row);
                                     it->set_text(col, text);
                                 }
                                 break;
                             }
                             if (s->method_name == "AddItem" && call_args.size() >= 1) {
                                 Tree *t = Object::cast_to<Tree>(obj);
                                 TreeItem *root = t->get_root();
                                 if (root) {
                                     TreeItem *it = t->create_item(root);
                                     String text = call_args[0];
                                     // Split by tab? FlexGrid AddItem often supports tab separated columns
                                     PackedStringArray parts = text.split("\t");
                                     int cols = t->get_columns();
                                     for(int i=0; i<parts.size(); i++) {
                                         if (i < cols) it->set_text(i, parts[i]);
                                     }
                                 }
                                 break;
                             }
                             if (s->method_name == "RemoveItem" && call_args.size() == 1) {
                                  Tree *t = Object::cast_to<Tree>(obj);
                                  int idx = call_args[0];
                                  TreeItem *root = t->get_root();
                                  if (root && idx >= 0 && idx < root->get_child_count()) {
                                      // Tree doesn't have remove_child by index directly easily?
                                      // root->get_child(idx)->free(); // Memdelete?
                                      // In Godot, freeing the item removes it.
                                      TreeItem *it = root->get_child(idx);
                                      memdelete(it); 
                                  }
                                  break;
                             }
                         }


                         if (s->method_name.nocasecmp_to("Connect") == 0 && call_args.size() == 2) {
                             String signal = call_args[0];
                             String target = call_args[1];
                             if (owner) {
                                 if (obj->has_signal(signal)) {
                                     obj->connect(signal, Callable(owner, target));
                                 } else {
                                     UtilityFunctions::print("Runtime Warning: Signal '", signal, "' not found on object");
                                 }
                                 break;
                             }
                         }

                         // UtilityFunctions::print("Call on object: ", s->method_name);
                         if (obj->has_method(s->method_name)) {
                             obj->callv(s->method_name, call_args);
                         } else {
                             String snake = s->method_name.to_snake_case();
                             if (obj->has_method(snake)) {
                                 obj->callv(snake, call_args);
                             } else {
                                 // Handle 3D Shape special method calls?
                                 // e.g. Cube.LookAt(x,y,z) -> look_at
                                 if (s->method_name == "LookAt" && call_args.size() == 3) {
                                     Node3D *n3d = Object::cast_to<Node3D>(obj);
                                     if (n3d) {
                                         n3d->look_at(Vector3(call_args[0], call_args[1], call_args[2]));
                                         break; // Handled
                                     }
                                 }
                                 raise_error("Object does not have method " + s->method_name);
                             }
                         }
                    } else {
                        raise_error("Method call on null Object");
                    }
                } else {
                    // UtilityFunctions::print("Debug: Base type: ", base.get_type());
                    raise_error("Method call base is not an Object");
                }
            } else {            
                // Built-ins (Helpers for Statements that look like calls)
                if (s->method_name.nocasecmp_to("Connect") == 0 && call_args.size() == 3) {
                     Object *obj = call_args[0];
                     String signal_name = call_args[1];
                     String target_method = call_args[2];
                     
                     if (obj && owner) {
                          if (obj->has_signal(signal_name)) {
                              Callable callable = Callable(owner, target_method);
                              if (!obj->is_connected(signal_name, callable)) {
                                   obj->connect(signal_name, callable);
                              }
                          } else {
                              UtilityFunctions::print("Runtime Warning: Signal '", signal_name, "' not found on object");
                          }
                     }
                     break;
                }

                if (s->method_name.nocasecmp_to("Randomize") == 0) {
                    UtilityFunctions::randomize();
                    break;
                }
                if (s->method_name.nocasecmp_to("Beep") == 0) {
                    if (owner && Object::cast_to<Node>(owner)) {
                         Node *n = Object::cast_to<Node>(owner);
                         AudioStreamPlayer *player = memnew(AudioStreamPlayer);
                         AudioStreamWAV *wav = memnew(AudioStreamWAV);
                         wav->set_format(AudioStreamWAV::FORMAT_16_BITS);
                         wav->set_mix_rate(44100);
                         
                         int sample_rate = 44100;
                         float duration = 0.2f;
                         int frames = (int)(sample_rate * duration);
                         PackedByteArray pba;
                         pba.resize(frames * 2);
                         
                         for(int i=0; i<frames; i++) {
                              float t = (float)i / (float)sample_rate;
                              float wave = UtilityFunctions::sin(t * 880.0f * 2.0f * Math_PI); // 880Hz Beep
                              int16_t sample = (int16_t)(wave * 30000.0f);
                              pba.encode_s16(i * 2, sample);
                         }
                         
                         wav->set_data(pba);
                         player->set_stream(wav);
                         n->add_child(player);
                         player->play();
                         
                         // Auto-delete on finish
                         player->connect("finished", Callable(player, "queue_free"));
                    }
                    break;
                }
                if (s->method_name.nocasecmp_to("Sleep") == 0 && call_args.size() == 1) {
                     int ms = (int)call_args[0];
                     OS::get_singleton()->delay_msec(ms);
                     break;
                }
                // Assert condition [, message]
                if (s->method_name.nocasecmp_to("Assert") == 0 && call_args.size() >= 1) {
                     bool cond = (bool)call_args[0];
                     if (!cond) {
                         String msg = (call_args.size() >= 2) ? String(call_args[1]) : String("Assertion failed");
                         UtilityFunctions::print("[VG] ASSERT FAILED: ", msg);
                         raise_error(msg);
                     }
                     break;
                }
                if (s->method_name.nocasecmp_to("Shell") == 0 && call_args.size() >= 1) {
                     String cmd_line = call_args[0];
                     
                     String exe = "";
                     Array args;
                     int i = 0;
                     while(i < cmd_line.length() && cmd_line[i] == ' ') i++;
                     if (i < cmd_line.length()) {
                         if (cmd_line[i] == '"') {
                             i++;
                             while(i < cmd_line.length() && cmd_line[i] != '"') { exe += cmd_line[i]; i++; }
                             i++;
                         } else {
                             while(i < cmd_line.length() && cmd_line[i] != ' ') { exe += cmd_line[i]; i++; }
                         }
                     }
                     while(i < cmd_line.length()) {
                          while(i < cmd_line.length() && cmd_line[i] == ' ') i++; 
                          if (i >= cmd_line.length()) break;
                          String arg = "";
                          if (cmd_line[i] == '"') {
                               i++;
                               while(i < cmd_line.length() && cmd_line[i] != '"') { arg += cmd_line[i]; i++; }
                               i++;
                          } else {
                               while(i < cmd_line.length() && cmd_line[i] != ' ') { arg += cmd_line[i]; i++; }
                          }
                          args.push_back(arg);
                     }

                     OS::get_singleton()->execute(exe, args);
                     break;
                }
                if (s->method_name.nocasecmp_to("MkDir") == 0 && call_args.size() == 1) {
                     String path = call_args[0];
                     DirAccess::make_dir_recursive_absolute(path);
                     break;
                }
                if (s->method_name.nocasecmp_to("RmDir") == 0 && call_args.size() == 1) {
                     String path = call_args[0];
                     DirAccess::remove_absolute(path); // Or remove? remove_absolute likely maps to simple remove if folder? Godot behavior for DirAccess::remove on folder?
                     // Usually works on empty folder.
                     break;
                }
                
                // --- File System Extended ---
                if (s->method_name.nocasecmp_to("Kill") == 0 && call_args.size() == 1) {
                     String path = call_args[0];
                     if (!path.begins_with("res://") && !path.begins_with("user://")) path = "user://" + path;
                     if (FileAccess::file_exists(path)) {
                         DirAccess::remove_absolute(path);
                     } else {
                         raise_error("File not found: " + path, 53);
                     }
                     break;
                }
                if (s->method_name.nocasecmp_to("Name") == 0 && call_args.size() == 2) {
                     String p1 = call_args[0];
                     String p2 = call_args[1];
                     if (!p1.begins_with("res://") && !p1.begins_with("user://")) p1 = "user://" + p1;
                     if (!p2.begins_with("res://") && !p2.begins_with("user://")) p2 = "user://" + p2;
                     
                     if (DirAccess::rename_absolute(p1, p2) != OK) {
                         raise_error("Failed to rename file");
                     }
                     break;
                }
                if (s->method_name.nocasecmp_to("FileCopy") == 0 && call_args.size() == 2) {
                     String p1 = call_args[0];
                     String p2 = call_args[1];
                     if (!p1.begins_with("res://") && !p1.begins_with("user://")) p1 = "user://" + p1;
                     if (!p2.begins_with("res://") && !p2.begins_with("user://")) p2 = "user://" + p2;
                     
                     if (DirAccess::copy_absolute(p1, p2) != OK) {
                         raise_error("Failed to copy file");
                     }
                     break;
                }

                // --- Physics Commands ---
                if (s->method_name.nocasecmp_to("ApplyForce") == 0 && call_args.size() >= 3) {
                     Object *obj = call_args[0];
                     if (obj) {
                         double x = call_args[1];
                         double y = call_args[2];
                         if (obj->is_class("RigidBody2D")) {
                             Object::cast_to<RigidBody2D>(obj)->apply_force(Vector2(x, y));
                         } else if (obj->is_class("RigidBody3D")) {
                             double z = (call_args.size() >= 4) ? (double)call_args[3] : 0.0;
                             Object::cast_to<RigidBody3D>(obj)->apply_force(Vector3(x, y, z));
                         }
                     }
                     break;
                }
                if (s->method_name.nocasecmp_to("ApplyImpulse") == 0 && call_args.size() >= 3) {
                     Object *obj = call_args[0];
                     if (obj) {
                         double x = call_args[1];
                         double y = call_args[2];
                         if (obj->is_class("RigidBody2D")) {
                             Object::cast_to<RigidBody2D>(obj)->apply_impulse(Vector2(x, y));
                         } else if (obj->is_class("RigidBody3D")) {
                             double z = (call_args.size() >= 4) ? (double)call_args[3] : 0.0;
                             Object::cast_to<RigidBody3D>(obj)->apply_impulse(Vector3(x, y, z));
                         }
                     }
                     break;
                }
                if (s->method_name.nocasecmp_to("SetVelocity") == 0 && call_args.size() >= 3) {
                     Object *obj = call_args[0];
                     if (obj) {
                         double x = call_args[1];
                         double y = call_args[2];
                         if (obj->is_class("RigidBody2D")) {
                             Object::cast_to<RigidBody2D>(obj)->set_linear_velocity(Vector2(x, y));
                         } else if (obj->is_class("RigidBody3D")) {
                             double z = (call_args.size() >= 4) ? (double)call_args[3] : 0.0;
                             Object::cast_to<RigidBody3D>(obj)->set_linear_velocity(Vector3(x, y, z));
                         } else if (obj->is_class("CharacterBody2D")) {
                             Object::cast_to<CharacterBody2D>(obj)->set_velocity(Vector2(x, y));
                         } else if (obj->is_class("CharacterBody3D")) {
                             double z = (call_args.size() >= 4) ? (double)call_args[3] : 0.0;
                             Object::cast_to<CharacterBody3D>(obj)->set_velocity(Vector3(x, y, z));
                         }
                     }
                     break;
                }

                // --- Animation System ---
                if (s->method_name.nocasecmp_to("Animate") == 0 && call_args.size() >= 4) {
                     Object *obj = call_args[0];
                     String prop = call_args[1];
                     Variant val = call_args[2];
                     double dur = call_args[3];
                     
                     Node *n = Object::cast_to<Node>(obj);
                     if (n) {
                         // Property Aliasing for Tween
                         String actual_prop = prop;
                         if (prop == "Left") actual_prop = "position:x";
                         if (prop == "Top") actual_prop = "position:y";
                         if (prop == "Width") actual_prop = "size:x";
                         if (prop == "Height") actual_prop = "size:y";
                         if (prop == "Caption") actual_prop = "text";
                         if (prop == "Value") actual_prop = "value";
                         // Timer
                         if (n->is_class("Timer") && prop == "Interval") {
                             actual_prop = "wait_time";
                             val = (double)val / 1000.0;
                         }

                         Ref<Tween> tween = n->create_tween();
                         if (tween.is_valid()) {
                             tween->tween_property(n, actual_prop, val, dur);
                         }
                     }
                     break;
                }

                if (s->method_name.nocasecmp_to("MsgBox") == 0 && call_args.size() >= 1) {
                     String msg = call_args[0];
                     int buttons = 0;
                     if (call_args.size() >= 2) buttons = (int)call_args[1];
                     String title = "VisualGasic";
                     if (call_args.size() >= 3) title = call_args[2];

                     if (!owner || !Object::cast_to<Node>(owner)) {
                          break;
                     }
                     Node *root = Object::cast_to<Node>(owner);

                     AcceptDialog *dlg = nullptr;
                     bool is_confirm = false;

                     // Determine Dialog Type
                     if (buttons == 4 || buttons == 1) { // vbYesNo or vbOKCancel
                          ConfirmationDialog *cd = memnew(ConfirmationDialog);
                          if (buttons == 4) {
                               cd->get_ok_button()->set_text("Yes");
                               cd->get_cancel_button()->set_text("No");
                          }
                          dlg = cd;
                          is_confirm = true;
                     } else {
                          dlg = memnew(AcceptDialog);
                     }
                     
                     dlg->set_title(title);
                     dlg->set_text(msg);
                     root->add_child(dlg);

                     // Signal Magic
                     dlg->set_meta("result_ok", false);
                     dlg->connect("confirmed", Callable(dlg, "set_meta").bind("result_ok", true));

                     dlg->popup_centered();
                     
                     while (dlg->is_visible() && dlg->is_inside_tree()) {
                          DisplayServer::get_singleton()->process_events();
                          OS::get_singleton()->delay_msec(10);
                     }
                     
                     bool ok = (bool)dlg->get_meta("result_ok");
                     dlg->queue_free();
                     
                     // Return Value logic (though this is a Statement, VB6 MsgBox statement ignores return)
                     // If used as function, it's handled in expression parser.
                     // But here we might just block.
                     break;
                }

                // Persistence (Registry emulation via ConfigFile)
                if (s->method_name.nocasecmp_to("SaveSetting") == 0 && call_args.size() == 4) {
                     // SaveSetting(AppName, Section, Key, Value)
                     String app = call_args[0];
                     String section = call_args[1];
                     String key = call_args[2];
                     Variant val = call_args[3];
                     
                     Ref<ConfigFile> cfg;
                     cfg.instantiate();
                     String path = "user://vb_settings.cfg";
                     cfg->load(path); // Load existing
                     
                     // We prefix section with AppName to simulate registry structure
                     String real_section = app + "/" + section;
                     cfg->set_value(real_section, key, val);
                     cfg->save(path);
                     break;
                }

                // GetSetting and OpenDatabase moved to evaluate_expression as they return values.
                
                if (s->method_name.nocasecmp_to("SaveDatabase") == 0 && call_args.size() == 2) {
                     String path = call_args[0];
                     Variant data = call_args[1];
                     
                     if (!path.begins_with("res://") && !path.begins_with("user://")) {
                         path = "user://" + path;
                     }
                     Ref<FileAccess> f = FileAccess::open(path, FileAccess::WRITE);
                     if (f.is_valid()) {
                         String text = JSON::stringify(data, "\t");
                         f->store_string(text);
                     } else {
                         raise_error("Could not write to database: " + path);
                     }
                     break;
                }
                
                if (s->method_name.nocasecmp_to("LoadForm") == 0 && call_args.size() == 1) {
                     String path = call_args[0];
                     if (!path.begins_with("res://")) path = "res://" + path;
                     
                     Ref<PackedScene> scene = ResourceLoader::get_singleton()->load(path);
                         if (scene.is_valid()) {
                         Node* new_form = scene->instantiate();
                         if (owner) {
                             Node* owner_node = Object::cast_to<Node>(owner);
                             if (owner_node && owner_node->is_inside_tree()) {
                                 SceneTree *tree = owner_node->get_tree();
                                 if (tree) {
                                     Node* root = tree->get_root();
                                     if (root) root->add_child(new_form);
                                 }
                             } else {
                                 // Not inside scene tree; skip adding for headless/test environments.
                             }
                         }
                     } else {
                         raise_error("Could not load form: " + path);
                     }
                     break;
                }

                if (s->method_name.nocasecmp_to("AddChild") == 0 && call_args.size() == 1) {
                     Object *obj = call_args[0];
                     Node *child = Object::cast_to<Node>(obj);
                     if (child && owner) {
                          Node *parent = Object::cast_to<Node>(owner);
                          if (parent) {
                               parent->add_child(child);
                               dynamic_nodes.push_back(child->get_instance_id());
                          }
                     }
                     break;
                }
                
                if (s->method_name.nocasecmp_to("CLS") == 0 || s->method_name.nocasecmp_to("ClearScreen") == 0) {
                     for(int i=0; i<dynamic_nodes.size(); i++) {
                         Object *obj = ObjectDB::get_instance(dynamic_nodes[i]);
                         if (obj) {
                             Node *n = Object::cast_to<Node>(obj);
                             if (n) n->queue_free();
                         }
                     }
                     dynamic_nodes.clear();
                     break;
                }
                
                // AI Helpers
                int cmd_ai = 0;
                Object *enemy = nullptr;
                Object *target = nullptr;
                double speed = 0;
                double stop_dist = 0;
                double radius = 0;
                Array points;
                bool loop = false;

                if (s->method_name.nocasecmp_to("AI_Chase") == 0 && call_args.size() >= 3) {
                    cmd_ai = 1;
                    enemy = call_args[0];
                    target = call_args[1];
                    speed = call_args[2];
                    if (call_args.size() >= 4) stop_dist = call_args[3];
                }
                else if (s->method_name.nocasecmp_to("AI_Wander") == 0 && call_args.size() >= 3) {
                    cmd_ai = 2;
                    enemy = call_args[0];
                    speed = call_args[1];
                    radius = call_args[2];
                }
                else if (s->method_name.nocasecmp_to("AI_Patrol") == 0 && call_args.size() >= 3) {
                     cmd_ai = 3;
                     enemy = call_args[0];
                     points = call_args[1];
                     speed = call_args[2];
                     if (call_args.size() >= 4) loop = call_args[3];
                }

                if (cmd_ai > 0 && enemy) {
                    Node *enemy_node = Object::cast_to<Node>(enemy);
                    if (enemy_node) {
                        GasicAIController *ai = nullptr;
                        TypedArray<Node> children = enemy_node->get_children();
                        for(int i=0; i<children.size(); i++) {
                            Node *c = Object::cast_to<Node>(children[i]);
                            if (c && c->is_class("GasicAIController")) {
                                ai = Object::cast_to<GasicAIController>(c);
                                break;
                            }
                        }
                        
                        if (!ai) {
                            ai = memnew(GasicAIController);
                            ai->set_name("GasicAI");
                            enemy_node->add_child(ai);
                        }
                        
                        if (cmd_ai == 1) ai->start_chase(target, speed, stop_dist);
                        if (cmd_ai == 2) ai->start_wander(speed, radius);
                        if (cmd_ai == 3) ai->start_patrol(points, speed, loop);
                    }
                    break;
                }
                
                if (s->method_name.nocasecmp_to("AI_Stop") == 0 && call_args.size() == 1) {
                    Object *enemy = call_args[0];
                     if (enemy) {
                        Node *enemy_node = Object::cast_to<Node>(enemy);
                        if (enemy_node) {
                            TypedArray<Node> children = enemy_node->get_children();
                            for(int i=0; i<children.size(); i++) {
                                Node *c = Object::cast_to<Node>(children[i]);
                                if (c && c->is_class("GasicAIController")) {
                                    GasicAIController *ai = Object::cast_to<GasicAIController>(c);
                                    ai->stop();
                                    break;
                                }
                            }
                        }
                     }
                     break;
                }

                // Helper to create simple text label
                if (s->method_name.nocasecmp_to("CreateText") == 0 && call_args.size() >= 3) {
                     // CreateText(text, x, y, [out_var]) -> But this is a statement, so "CreateText "Hello", 10, 10"
                     // Ideally it returns the label object if possible?
                     // Commands in Basic usually don't return.
                     // But we can implement it as:
                     // Dim l
                     // Set l = CreateText("Hello", 10, 10) -> In Expression Evaluator?
                     // Let's implement it in Expression Evaluator instead.
                }

                if (s->method_name.nocasecmp_to("ChangeScene") == 0 && call_args.size() == 1) {
                     String path = call_args[0];
                     if (owner) {
                          Node *n = Object::cast_to<Node>(owner);
                          if (n && n->is_inside_tree()) {
                               SceneTree *tree = n->get_tree();
                               if (tree) {
                                    tree->change_scene_to_file(path);
                               }
                          }
                     }
                     break;
                }

                // Audio Helpers
                if (s->method_name.nocasecmp_to("PlayMusic") == 0 && call_args.size() == 1) {
                     String path = call_args[0];
                     Ref<AudioStream> stream = ResourceLoader::get_singleton()->load(path);
                     if (stream.is_valid() && owner) {
                          Node *n = Object::cast_to<Node>(owner);
                          if (n) {
                               // Check existing
                               if (n->has_meta("__BG_MUSIC__")) {
                                   Object *old = n->get_meta("__BG_MUSIC__");
                                   if (old) {
                                       Node *old_n = Object::cast_to<Node>(old);
                                       if (old_n) old_n->queue_free();
                                   }
                               }
                               
                               AudioStreamPlayer *p = memnew(AudioStreamPlayer);
                               p->set_stream(stream);
                               p->set_autoplay(true);
                               // Loop? Resource loop mode determines it usually, or we can explicit loop.
                               // Godot 4: Loop is property of AudioStream (import settings) or WAV/OGG resource.
                               n->add_child(p);
                               n->set_meta("__BG_MUSIC__", p);
                          }
                     }
                     break;
                }

                if (s->method_name.nocasecmp_to("StopMusic") == 0) {
                     if (owner) {
                         Node *n = Object::cast_to<Node>(owner);
                         if (n && n->has_meta("__BG_MUSIC__")) {
                             Object *old = n->get_meta("__BG_MUSIC__");
                             if (old) {
                                  Node *old_n = Object::cast_to<Node>(old);
                                  if (old_n) old_n->queue_free();
                             }
                             n->remove_meta("__BG_MUSIC__");
                         }
                     }
                     break;
                }

                if (s->method_name.nocasecmp_to("AddMenuItem") == 0 && call_args.size() >= 3) {
                     Object *menu_obj = call_args[0];
                     if (menu_obj && menu_obj->is_class("PopupMenu")) {
                         PopupMenu *pm = Object::cast_to<PopupMenu>(menu_obj);
                         String text = call_args[1];
                         String callback = call_args[2];
                         
                         pm->add_item(text);
                         int idx = pm->get_item_count() - 1;
                         // Logic to bind index?
                         // We can bind "id_pressed(int)" to a dispatcher.
                         // But we need to know WHICH item triggered.
                         // Simple approach: Map ID to Callback name in metadata?
                         
                         // Or connect "id_pressed" to _OnSignal, and let it pass the ID.
                         // But we want to call specific callback.
                         
                         // Let's use metadata on the PopupMenu: Map<ID, CallbackName>
                         Dictionary callback_map;
                         if (pm->has_meta("callbacks")) {
                             callback_map = pm->get_meta("callbacks");
                         } else {
                             // First time: connect signal
                             pm->connect("id_pressed", Callable(owner, "_OnSignal").bind(pm->get_name(), "MenuClick")); 
                             // Wait, name of popup might be auto gen.
                         }
                         
                         // Let's assume the user handles "Menu_MenuClick(ID)".
                         // But user asked for specific callback.
                         // "Sub File_New_Click()"
                         
                         // We can store the callback name in the Item Meta?
                         // PopupMenu doesn't support item metadata easily until Godot 4.x?
                         // set_item_metadata(idx, metadata)
                         pm->set_item_metadata(idx, callback);
                         
                         // Ensure handler is connected
                         if (!pm->is_connected("id_pressed", Callable(owner, "_OnSignal"))) {
                             // Bind "Menu" as Name, "Click" as Event.
                             // But we need to dispatch dynamically based on metadata.
                             // Complex.
                             // Workaround: We bind to a special internal handler?
                             // No, let's use the Metadata approach.
                             // Modify _OnSignal to check for metadata if the sender is a PopupMenu?
                             // Or just bind to "Menu" and let VB user write:
                             // Sub Menu_MenuClick(ID)
                             //    Select Case ID ...
                             // End Sub
                             
                             // User Request: "AddMenuItem(Menu, Text, CallbackName)"
                             // This implies the callback is specific.
                             // VB6 style was Menu Editor -> Name -> Sub Name_Click().
                             
                             // Let's support: "Sub MyCallbackname(ItemText)"
                             // We need a trampoline.
                             // Let's rely on _OnSignal intercepting.
                         }
                         
                         // Store callback name in a Dictionary in the Menu object Meta
                         callback_map[idx] = callback;
                         pm->set_meta("callbacks", callback_map);
                     }
                     break;
                }
                
                if (s->method_name.nocasecmp_to("MoveAndSlide") == 0 && call_args.size() >= 1) {
                     Object *obj = call_args[0];
                     CharacterBody2D *cb2d = Object::cast_to<CharacterBody2D>(obj);
                     if (cb2d) {
                         cb2d->move_and_slide();
                         break;
                     }
                     CharacterBody3D *cb3d = Object::cast_to<CharacterBody3D>(obj);
                     if (cb3d) {
                         cb3d->move_and_slide();
                         break;
                     }
                     break;
                }

                if (s->method_name.nocasecmp_to("PlaySound") == 0 && call_args.size() == 1) {
                     String path = call_args[0];
                     Ref<AudioStream> stream = ResourceLoader::get_singleton()->load(path);
                     if (stream.is_valid() && owner) {
                          Node *n = Object::cast_to<Node>(owner);
                          if (n) {
                               AudioStreamPlayer *p = memnew(AudioStreamPlayer);
                               p->set_stream(stream);
                               p->set_autoplay(true);
                               // Auto-free when done? Not built-in for simple player.
                               // For now, just add child. It will leak if we spawn tons.
                               // Real BASIC engines manage channels.
                               // We can set it to free on finish signal?
                               // Connect "finished" to "queue_free".
                               p->connect("finished", Callable(p, "queue_free"));
                               n->add_child(p);
                          }
                     }
                     break;
                }
                
                if (s->method_name.nocasecmp_to("PlayTone") == 0 && call_args.size() >= 2) {
                    double freq = (double)call_args[0];
                    double dur_ms = (double)call_args[1];
                    int waveform = 0; // Sine default
                    if (call_args.size() >= 3) waveform = (int)call_args[2];

                    Ref<AudioStreamWAV> stream;
                    stream.instantiate();
                    
                    int mix_rate = 44100;
                    stream->set_mix_rate(mix_rate);
                    stream->set_format(AudioStreamWAV::FORMAT_16_BITS);
                    stream->set_stereo(false); // Mono

                    int samples = (int)(dur_ms * mix_rate / 1000.0);
                    if (samples > 0) {
                        PackedByteArray data;
                        data.resize(samples * 2); // 16-bit = 2 bytes

                        // Envelope: 5ms fade-in, 30ms fade-out to prevent click/pop
                        int fade_in_samples = (int)(0.005 * mix_rate);
                        int fade_out_samples = (int)(0.030 * mix_rate);
                        if (fade_in_samples > samples / 2) fade_in_samples = samples / 2;
                        if (fade_out_samples > samples / 2) fade_out_samples = samples / 2;

                        for (int i = 0; i < samples; ++i) {
                            double t = (double)i / mix_rate;
                            double val = 0.0;
                            // Use explicit PI constant
                            const double PI = 3.14159265358979323846;
                            
                            switch (waveform) {
                                case 1: // Square
                                    val = (sin(2.0 * PI * freq * t) > 0) ? 1.0 : -1.0;
                                    break;
                                case 2: // Sawtooth
                                    val = 2.0 * (t * freq - floor(t * freq + 0.5));
                                    break;
                                case 3: // Noise
                                    val = ((double)rand() / RAND_MAX) * 2.0 - 1.0; 
                                    break;
                                default: // Sine
                                    val = sin(2.0 * PI * freq * t);
                                    break;
                            }
                            
                            // Apply envelope
                            double envelope = 1.0;
                            if (i < fade_in_samples) {
                                envelope = (double)i / fade_in_samples;
                            } else if (i >= samples - fade_out_samples) {
                                envelope = (double)(samples - 1 - i) / fade_out_samples;
                            }
                            val *= 0.2 * envelope; // Safe for polyphonic mixing

                            int16_t sample_int = (int16_t)(val * 32767.0);
                            data[i * 2] = (uint8_t)(sample_int & 0xFF);
                            data[i * 2 + 1] = (uint8_t)((sample_int >> 8) & 0xFF);
                        }
                        stream->set_data(data);
                    }

                    if (owner) {
                         Node *n = Object::cast_to<Node>(owner);
                         if (n) {
                              // Polyphony limiter: stop oldest PlayTone players if too many active
                              const int MAX_TONE_VOICES = 4;
                              Vector<AudioStreamPlayer *> active_tones;
                              for (int ci2 = 0; ci2 < n->get_child_count(); ci2++) {
                                  AudioStreamPlayer *asp = Object::cast_to<AudioStreamPlayer>(n->get_child(ci2));
                                  if (asp && asp->has_meta("__playtone__")) {
                                      active_tones.push_back(asp);
                                  }
                              }
                              while (active_tones.size() >= MAX_TONE_VOICES) {
                                  active_tones[0]->stop();
                                  active_tones[0]->queue_free();
                                  active_tones.remove_at(0);
                              }

                              AudioStreamPlayer *p = memnew(AudioStreamPlayer);
                              p->set_stream(stream);
                              p->set_autoplay(true);
                              p->set_meta("__playtone__", true);
                              p->connect("finished", Callable(p, "queue_free"));
                              n->add_child(p);
                         }
                    }
                     break;
                }

                // --- Immediate Drawing Commands ---
                // Works when called from OnDraw event
                // DrawLine — VG style: DrawLine x1, y1, x2, y2[, color][, width]
                //            Godot style: DrawLine Vector2, Vector2[, color][, width]
                if (s->method_name.nocasecmp_to("DrawLine") == 0 && call_args.size() >= 2) {
                     if (owner) {
                          CanvasItem *ci = Object::cast_to<CanvasItem>(owner);
                          if (ci) {
                               Color c = Color(1,1,1);
                               float width = 1.0f;
                               if (call_args[0].get_type() == Variant::VECTOR2 && call_args.size() >= 2) {
                                    // Godot style: Vector2, Vector2[, Color][, width]
                                    Vector2 from = call_args[0];
                                    Vector2 to = call_args[1];
                                    if (call_args.size() > 2) c = (Color)call_args[2];
                                    if (call_args.size() > 3) width = (float)call_args[3];
                                    ci->draw_line(from, to, c, width);
                               } else if (call_args.size() >= 4) {
                                    // VG style: x1, y1, x2, y2[, color][, width]
                                    double x1 = call_args[0]; double y1 = call_args[1];
                                    double x2 = call_args[2]; double y2 = call_args[3];
                                    if (call_args.size() > 4) c = (Color)call_args[4];
                                    if (call_args.size() > 5) width = (float)call_args[5];
                                    ci->draw_line(Vector2(x1, y1), Vector2(x2, y2), c, width);
                               }
                          }
                     }
                     break;
                }
                // DrawRect — VG style: DrawRect x, y, w, h[, color][, filled]
                //            Godot style: DrawRect Rect2[, color][, filled]
                if (s->method_name.nocasecmp_to("DrawRect") == 0 && call_args.size() >= 1) {
                     if (owner) {
                          CanvasItem *ci = Object::cast_to<CanvasItem>(owner);
                          if (ci) {
                               Color c = Color(1,1,1);
                               bool filled = true;
                               if (call_args[0].get_type() == Variant::RECT2) {
                                    // Godot style: Rect2[, Color][, filled]
                                    Rect2 rect = call_args[0];
                                    if (call_args.size() > 1) c = (Color)call_args[1];
                                    if (call_args.size() > 2) filled = (bool)call_args[2];
                                    ci->draw_rect(rect, c, filled);
                               } else if (call_args.size() >= 4) {
                                    // VG style: x, y, w, h[, Color][, filled]
                                    double x = call_args[0]; double y = call_args[1];
                                    double w = call_args[2]; double h = call_args[3];
                                    if (call_args.size() > 4) c = (Color)call_args[4];
                                    if (call_args.size() > 5) filled = (bool)call_args[5];
                                    ci->draw_rect(Rect2(x, y, w, h), c, filled);
                               }
                          }
                     }
                     break;
                }
                // DrawCircle — VG style: DrawCircle x, y, radius[, color]
                //              Godot style: DrawCircle Vector2, radius[, color]
                if (s->method_name.nocasecmp_to("DrawCircle") == 0 && call_args.size() >= 2) {
                     if (owner) {
                          CanvasItem *ci = Object::cast_to<CanvasItem>(owner);
                          if (ci) {
                               Color c = Color(1,1,1);
                               if (call_args[0].get_type() == Variant::VECTOR2 && call_args.size() >= 2) {
                                    // Godot style: Vector2, radius[, Color]
                                    Vector2 pos = call_args[0];
                                    float r = call_args[1];
                                    if (call_args.size() > 2) c = (Color)call_args[2];
                                    ci->draw_circle(pos, r, c);
                               } else if (call_args.size() >= 3) {
                                    // VG style: x, y, radius[, Color]
                                    double x = call_args[0]; double y = call_args[1];
                                    float r = call_args[2];
                                    if (call_args.size() > 3) c = (Color)call_args[3];
                                    ci->draw_circle(Vector2(x,y), r, c);
                               }
                          }
                     }
                     break;
                }
                if (s->method_name.nocasecmp_to("DrawPixel") == 0 || s->method_name.nocasecmp_to("PSet") == 0) {
                     // PSet(x, y, color)
                     if (call_args.size() >= 3) {
                          double x = call_args[0]; double y = call_args[1];
                          Color c = call_args[2];
                          if (owner) {
                               CanvasItem *ci = Object::cast_to<CanvasItem>(owner);
                               // draw_primitive needs arrays. simpler to use draw_rect 1x1
                               if (ci) ci->draw_rect(Rect2(x, y, 1, 1), c, true);
                          }
                     }
                     break;
                }

                // --- 3D Primitive Shapes ---
                if (s->method_name.nocasecmp_to("CreateCube") == 0 && call_args.size() >= 3) {
                     // CreateCube(sx, sy, sz, [px, py, pz], [color])
                     // Arguments are complex to parse optionally, so let's check size.
                     double sx = call_args[0]; double sy = call_args[1]; double sz = call_args[2];
                     
                     MeshInstance3D *mi = memnew(MeshInstance3D);
                     Ref<BoxMesh> box; box.instantiate();
                     box->set_size(Vector3(sx, sy, sz));
                     
                     // Optional Color -> Material
                     int last_arg_idx = call_args.size() - 1;
                     if (call_args[last_arg_idx].get_type() == Variant::COLOR) {
                         Ref<StandardMaterial3D> mat; mat.instantiate();
                         mat->set_albedo((Color)call_args[last_arg_idx]);
                         box->set_material(mat);
                     }
                     
                     mi->set_mesh(box);
                     
                     // Position?
                     if (call_args.size() >= 6) { 
                         double px = call_args[3]; double py = call_args[4]; double pz = call_args[5];
                         mi->set_position(Vector3(px, py, pz));
                     }
                     
                     if (owner) {
                         Node* n = Object::cast_to<Node>(owner);
                         if (n) { n->add_child(mi); dynamic_nodes.push_back(mi->get_instance_id()); }
                     }
                     break;
                }
                
                if (s->method_name.nocasecmp_to("CreateSphere") == 0 && call_args.size() >= 1) {
                     float r = call_args[0];
                     
                     MeshInstance3D *mi = memnew(MeshInstance3D);
                     Ref<SphereMesh> sphere; sphere.instantiate();
                     sphere->set_radius(r);
                     sphere->set_height(r * 2);
                     
                     // Optional Color
                     int last_arg_idx = call_args.size() - 1;
                     if (call_args.size() > 1 && call_args[last_arg_idx].get_type() == Variant::COLOR) {
                         Ref<StandardMaterial3D> mat; mat.instantiate();
                         mat->set_albedo((Color)call_args[last_arg_idx]);
                         sphere->set_material(mat);
                     }
                     
                     if (call_args.size() >= 4) {
                         mi->set_position(Vector3(call_args[1], call_args[2], call_args[3]));
                     }
                     
                     mi->set_mesh(sphere);
                     
                     if (owner) {
                         Node* n = Object::cast_to<Node>(owner);
                         if (n) { n->add_child(mi); dynamic_nodes.push_back(mi->get_instance_id()); }
                     }
                     break;
                }

                // Shader Helpers
                if (s->method_name.nocasecmp_to("SetShader") == 0 && call_args.size() == 2) {
                     // SetShader(node, shader_or_null)
                     Object *obj = call_args[0];
                     CanvasItem *ci = Object::cast_to<CanvasItem>(obj);
                     if (ci) {
                         Variant sh = call_args[1];
                         if (sh.get_type() == Variant::OBJECT) {
                              Object *check_obj = sh;
                              if (check_obj) {
                                  Ref<Shader> shader = sh;
                                  if (shader.is_valid()) {
                                      Ref<ShaderMaterial> mat;
                                      mat.instantiate();
                                      mat->set_shader(shader);
                                      ci->set_material(mat);
                                  } else {
                                      // Maybe they passed a material?
                                      Ref<Material> mat_res = sh;
                                      if (mat_res.is_valid()) {
                                          ci->set_material(mat_res);
                                      }
                                  }
                              } else {
                                   // Null object variant
                                   ci->set_material(Ref<Material>());
                              }
                         } else {
                              // Clear shader if not object
                              ci->set_material(Ref<Material>());
                         }
                     }
                     break;
                }
                
                // Screen & Window
                if (s->method_name.nocasecmp_to("SetTitle") == 0 && call_args.size() == 1) {
                     String title = call_args[0];
                     if (owner) {
                          Node *n = Object::cast_to<Node>(owner);
                          if (n) {
                              Window *w = n->get_window();
                              if (w) w->set_title(title);
                          }
                     }
                     break;
                }
                if (s->method_name.nocasecmp_to("SetScreenSize") == 0 && call_args.size() == 2) {
                     int w_val = call_args[0];
                     int h_val = call_args[1];
                     if (owner) {
                          Node *n = Object::cast_to<Node>(owner);
                          if (n) {
                              Window *w = n->get_window();
                              if (w) w->set_size(Vector2i(w_val, h_val));
                          }
                     }
                     break;
                }
                
                // Text Drawing (Basic)
                if (s->method_name.nocasecmp_to("DrawText") == 0 && call_args.size() >= 2) {
                     // DrawText(pos, text, [color])
                     if (owner) {
                          CanvasItem *ci = Object::cast_to<CanvasItem>(owner);
                          if (ci) {
                               Vector2 pos = call_args[0];
                               String text = call_args[1];
                               Color col = Color(1,1,1,1);
                               if (call_args.size() > 2) col = call_args[2];
                               Ref<Font> font = ThemeDB::get_singleton()->get_fallback_font();
                               ci->draw_string(font, pos, text, HorizontalAlignment::HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col);
                          }
                     }
                     break;
                }

                // DrawString — VG style: DrawString text, x, y, color[, fontSize]
                //              Godot style: DrawString font, Vector2, text, color[, fontSize]
                if (s->method_name.nocasecmp_to("DrawString") == 0 && call_args.size() >= 4) {
                     if (owner) {
                          CanvasItem *ci = Object::cast_to<CanvasItem>(owner);
                          if (ci) {
                               Ref<Font> font = ThemeDB::get_singleton()->get_fallback_font();
                               if (font.is_null()) {
                                   Control *ctrl = Object::cast_to<Control>(owner);
                                   if (ctrl) font = ctrl->get_theme_default_font();
                               }
                               if (font.is_valid()) {
                                   int font_size = 16;
                                   if (call_args[0].get_type() == Variant::OBJECT) {
                                        // Godot style: font, Vector2(x,y), text, color
                                        Vector2 pos = call_args[1];
                                        String text = call_args[2];
                                        Color col = Color(1,1,1,1);
                                        if (call_args.size() > 3) col = (Color)call_args[3];
                                        if (call_args.size() > 4) font_size = (int)call_args[4];
                                        ci->draw_string(font, pos, text, HorizontalAlignment::HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col);
                                   } else {
                                        // VG style: text, x, y, color
                                        String text = call_args[0];
                                        float x = call_args[1];
                                        float y = call_args[2];
                                        Color col = call_args[3];
                                        if (call_args.size() > 4) font_size = (int)call_args[4];
                                        ci->draw_string(font, Vector2(x, y + font_size), text, HorizontalAlignment::HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col);
                                   }
                               }
                          }
                     }
                     break;
                }

                // Try Internal Call
                bool found = false;
                call_internal(s->method_name, call_args, found);
                
                // Handle ByRef parameter write-back
                if (found && script.is_valid() && script->ast_root) {
                    SubDefinition *called_func = nullptr;
                    for (int i = 0; i < script->ast_root->subs.size(); i++) {
                        if (script->ast_root->subs[i]->name.nocasecmp_to(s->method_name) == 0) {
                            called_func = script->ast_root->subs[i];
                            break;
                        }
                    }
                    
                    if (called_func) {
                        int max_params = called_func->parameters.size();
                        int arg_count = s->arguments.size();
                        for (int i = 0; i < max_params && i < arg_count; i++) {
                            const Parameter& param = called_func->parameters[i];
                            // If ByRef (not ByVal), and the argument was a variable, write back
                            if (param.is_by_ref && s->arguments[i]->type == ExpressionNode::VARIABLE) {
                                String caller_var_name = ((VariableNode*)s->arguments[i])->name;
                                // Get the parameter's current value from the function's scope
                                if (variables.has(param.name)) {
                                    // Capture value before write to avoid Godot Dictionary
                                    // self-reference issue when caller_var_name == param.name
                                    Variant byref_val = variables[param.name];
                                    variables[caller_var_name] = byref_val;
                                }
                            }
                        }
                    }
                }
                
                if (!found) {
                    // Check if it's a lambda variable being called
                    if (variables.has(s->method_name)) {
                        Variant var_val = variables[s->method_name];
                        if (var_val.get_type() == Variant::DICTIONARY) {
                            Dictionary d = var_val;
                            if (d.has("__vg_lambda") && (bool)d["__vg_lambda"]) {
                                invoke_lambda(d, call_args);
                                found = true;
                            }
                        }
                    }
                    if (!found) {
                        if (owner) {
                            if (owner->has_method(s->method_name)) {
                                 owner->callv(s->method_name, call_args);
                            } else {
                                 String snake = s->method_name.to_snake_case();
                                 if (owner->has_method(snake)) {
                                     owner->callv(snake, call_args);
                                 } else {
                                     UtilityFunctions::print("Runtime Error: Object does not have method ", s->method_name);
                                 }
                            }
                        } else {
                             raise_error("No owner for method call");
                        }
                    }
                }
            }
            break;
        }
        case STMT_RAISE: {
             RaiseStatement* s = (RaiseStatement*)stmt;
             Variant v_code = evaluate_expression(s->error_code);
             int code = (int)v_code;
             String msg = "Application error";
             if (s->message) {
                 msg = (String)evaluate_expression(s->message);
             }
             raise_error(msg, code);
             break;
        }
        case STMT_WHENEVER_SECTION: {
            WheneverSectionStatement* s = (WheneverSectionStatement*)stmt;
            
            WheneverSection section;
            section.section_name = s->section_name;
            section.variable_name = s->variable_name;
            section.comparison_operator = s->comparison_operator;
            section.callback_procedures = s->callback_procedures;  // Copy all callbacks
            section.condition_expression = s->condition_expression;  // Copy expression reference
            
            // Set scope information
            if (s->is_local_scope) {
                section.scope_type = "local";
                section.scope_context = current_sub ? current_sub->name : "global";
            } else {
                section.scope_type = "global";
                section.scope_context = "";
            }
            
            section.is_active = true;
            
            if (s->comparison_value) {
                section.comparison_value = evaluate_expression(s->comparison_value);
            }
            
            if (s->comparison_value2) {
                section.comparison_value2 = evaluate_expression(s->comparison_value2);
            }
            
            // Initialize last_value with current variable value
            Variant current_value;
            if (get_variable(s->variable_name, current_value)) {
                section.last_value = current_value;
            }
            
            whenever_sections.push_back(section);
            needs_var_sync = true;  // Enable variable sync for bytecode VM
            break;
        }
        case STMT_SUSPEND_WHENEVER: {
            SuspendWheneverStatement* s = (SuspendWheneverStatement*)stmt;
            
            for (int i = 0; i < whenever_sections.size(); i++) {
                if (whenever_sections[i].section_name == s->section_name) {
                    whenever_sections.write[i].is_active = false;
                    break;
                }
            }
            break;
        }
        case STMT_RESUME_WHENEVER: {
            ResumeWheneverStatement* s = (ResumeWheneverStatement*)stmt;
            
            for (int i = 0; i < whenever_sections.size(); i++) {
                if (whenever_sections[i].section_name == s->section_name) {
                    whenever_sections.write[i].is_active = true;
                    // Sync last_value to current variable value to prevent
                    // stale state from before suspension causing false triggers
                    String var_name = whenever_sections[i].variable_name;
                    if (variables.has(var_name)) {
                        whenever_sections.write[i].last_value = variables[var_name];
                    }
                    break;
                }
            }
            break;
        }
        case STMT_TRY: {
            TryStatement* s = (TryStatement*)stmt;
            
            // Execute Try Block
            for(int i=0; i<s->try_block.size(); i++) {
                execute_statement(s->try_block[i]);
                if (error_state.has_error && error_state.mode == ErrorState::NONE) break; // Runtime Error
                if (error_state.mode != ErrorState::NONE && error_state.mode != ErrorState::GOTO_LABEL) break; // Break/Return/Exit
            }
            
            bool error_handled = false;
            if (error_state.has_error && error_state.mode == ErrorState::NONE) {
                 // Check if we need to capture the exception in a variable
                 if (!s->catch_var_name.is_empty()) {
                      Dictionary ex;
                      ex["Description"] = error_state.message;
                      ex["Number"] = error_state.code;
                      ex["Source"] = "VisualGasic"; 
                      assign_variable(s->catch_var_name, ex);
                 }

                 error_state.has_error = false; // Caught
                 error_handled = true;
                 
                 for(int i=0; i<s->catch_block.size(); i++) {
                     execute_statement(s->catch_block[i]);
                     if (error_state.has_error || error_state.mode != ErrorState::NONE) break;
                 }
            }
            
            // Finally Block
            ErrorState backup_state = error_state;
            
            // Temporarily clear state to run finally
            // If finally succeeds, we restore backup_state.
            // If finally fails/returns, it overwrites backup_state.
            
            error_state.has_error = false;
            error_state.mode = ErrorState::NONE;
            
            for(int i=0; i<s->finally_block.size(); i++) {
                 execute_statement(s->finally_block[i]);
                 if (error_state.has_error || error_state.mode != ErrorState::NONE) break;
            }
            
            if (!error_state.has_error && error_state.mode == ErrorState::NONE) {
                 // Restore previous state (e.g. Return from Try block, or Error propagated if not caught)
                 error_state = backup_state;
            }
            
            break;
        }
        case STMT_LABEL: break;
        case STMT_GOTO: {
             GotoStatement* s = (GotoStatement*)stmt;
             if (current_sub && current_sub->label_map.has(s->label_name)) {
                 jump_target = (int)current_sub->label_map[s->label_name] - 1;
             } else {
                 raise_error("Label not found: " + s->label_name);
             }
             break;
        }
        case STMT_GOSUB: {
             GoSubStatement* s = (GoSubStatement*)stmt;
             if (current_sub && current_sub->label_map.has(s->label_name)) {
                 // Push current position as return address
                 // jump_target is the index into the body array
                 // We need to save where we are and jump
                 // The outer execution loop uses jump_target to set i
                 gosub_return_stack.push_back(jump_target + 1); // save next stmt index (will be set by outer loop)
                 jump_target = (int)current_sub->label_map[s->label_name] - 1;
             } else {
                 raise_error("Label not found: " + s->label_name);
             }
             break;
        }
        case STMT_RETURN_GOSUB: {
             if (gosub_return_stack.size() > 0) {
                 jump_target = gosub_return_stack[gosub_return_stack.size() - 1] - 1;
                 gosub_return_stack.resize(gosub_return_stack.size() - 1);
             } else {
                 // No GoSub context — treat as normal return
                 return;
             }
             break;
        }
        case STMT_IMPLEMENTS: {
             ImplementsStatement* s = (ImplementsStatement*)stmt;
             UtilityFunctions::print("[VG] Implements ", s->interface_name, " declared (interface verification pending)");
             break;
        }
        // ── v3.3.0 New Statement Execution ──
        case STMT_RESUME: {
            ResumeStatement* s = (ResumeStatement*)stmt;
            if (s->resume_type == ResumeStatement::RESUME_NEXT) {
                // Resume Next: clear error and continue to next statement
                error_state.has_error = false;
                error_state.message = "";
                error_state.code = 0;
            } else if (s->resume_type == ResumeStatement::RESUME_LABEL) {
                // Resume <label>: clear error and jump to label
                error_state.has_error = false;
                error_state.message = "";
                error_state.code = 0;
                jump_target = -1; // Will be resolved by label lookup
                // Find label in current sub
                if (current_sub) {
                    for (int li = 0; li < current_sub->statements.size(); li++) {
                        if (current_sub->statements[li]->type == STMT_LABEL) {
                            LabelStatement* ls = (LabelStatement*)current_sub->statements[li];
                            if (ls->name.nocasecmp_to(s->label_name) == 0) {
                                jump_target = li;
                                break;
                            }
                        }
                    }
                }
            } else {
                // Plain Resume: clear error (re-execute failing statement not supported in tree-walk)
                error_state.has_error = false;
                error_state.message = "";
                error_state.code = 0;
            }
            break;
        }
        case STMT_ON_GOTO: {
            OnGotoStatement* s = (OnGotoStatement*)stmt;
            int idx = (int)evaluate_expression(s->index_expression);
            if (idx >= 1 && idx <= s->labels.size()) {
                String target_label = s->labels[idx - 1]; // 1-based
                // Jump to label
                if (current_sub) {
                    for (int li = 0; li < current_sub->statements.size(); li++) {
                        if (current_sub->statements[li]->type == STMT_LABEL) {
                            LabelStatement* ls = (LabelStatement*)current_sub->statements[li];
                            if (ls->name.nocasecmp_to(target_label) == 0) {
                                jump_target = li;
                                break;
                            }
                        }
                    }
                }
            }
            // If out of range, falls through (VB6 behavior)
            break;
        }
        case STMT_ON_GOSUB: {
            OnGosubStatement* s = (OnGosubStatement*)stmt;
            int idx = (int)evaluate_expression(s->index_expression);
            if (idx >= 1 && idx <= s->labels.size()) {
                String target_label = s->labels[idx - 1];
                // Push return address and jump
                if (current_sub) {
                    int target = -1;
                    for (int li = 0; li < current_sub->statements.size(); li++) {
                        if (current_sub->statements[li]->type == STMT_LABEL) {
                            LabelStatement* ls = (LabelStatement*)current_sub->statements[li];
                            if (ls->name.nocasecmp_to(target_label) == 0) {
                                target = li;
                                break;
                            }
                        }
                    }
                    if (target >= 0) {
                        gosub_return_stack.push_back(jump_target >= 0 ? jump_target : 0);
                        jump_target = target;
                    }
                }
            }
            break;
        }
        case STMT_GET_FILE: {
            GetFileStatement* s = (GetFileStatement*)stmt;
            int fn = (int)evaluate_expression(s->file_number);
            if (!open_files.has(fn)) {
                raise_error("Bad File Name or Number");
                break;
            }
            Ref<FileAccess> fa = open_files[fn];
            if (s->record_number) {
                int recno = (int)evaluate_expression(s->record_number);
                if (recno > 0) fa->seek((recno - 1) * 128); // Default record size
            }
            // Read a line or binary data into variable
            if (s->variable) {
                String var_name;
                if (s->variable->type == ExpressionNode::VARIABLE) {
                    var_name = ((VariableNode*)s->variable)->name;
                }
                if (!var_name.is_empty()) {
                    // Read binary data as string
                    PackedByteArray data = fa->get_buffer(128);
                    assign_variable(var_name, data.get_string_from_ascii());
                }
            }
            break;
        }
        case STMT_PUT_FILE: {
            PutFileStatement* s = (PutFileStatement*)stmt;
            int fn = (int)evaluate_expression(s->file_number);
            if (!open_files.has(fn)) {
                raise_error("Bad File Name or Number");
                break;
            }
            Ref<FileAccess> fa = open_files[fn];
            if (s->record_number) {
                int recno = (int)evaluate_expression(s->record_number);
                if (recno > 0) fa->seek((recno - 1) * 128);
            }
            if (s->expression) {
                Variant val = evaluate_expression(s->expression);
                String str_val = String(val);
                fa->store_string(str_val);
            }
            break;
        }
        case STMT_SWAP: {
            SwapStatement* s = (SwapStatement*)stmt;
            // Get left and right values
            Variant left_val = evaluate_expression(s->left);
            Variant right_val = evaluate_expression(s->right);
            // Assign swapped
            assign_to_target(s->left, right_val);
            assign_to_target(s->right, left_val);
            break;
        }
        case STMT_MODULE: {
            // Module statement: module-level subs are already registered during parsing
            // This is a no-op at execution time (declarations happen at parse/load time)
            break;
        }
        case STMT_ON_ERROR: {
             OnErrorStatement* s = (OnErrorStatement*)stmt;
             if (s->mode == OnErrorStatement::RESUME_NEXT) {
                 error_state.mode = ErrorState::RESUME_NEXT;
             } else {
                 error_state.mode = ErrorState::GOTO_LABEL;
                 error_state.label = s->label_name;
             }
             break;
        }
        case STMT_LOAD_DATA: {
            LoadDataStatement* s = (LoadDataStatement*)stmt;
            Variant v_val = evaluate_expression(s->path_expression);
            String content;
            
            if (s->is_from_string) {
                // DataFromString — use expression result directly as CSV data
                content = v_val;
            } else {
                // LoadData — expression is a file path
                String path = v_val;
                if (!FileAccess::file_exists(path)) {
                     raise_error("LoadData: File not found: " + path, 200);
                     break;
                }
                Ref<FileAccess> file = FileAccess::open(path, FileAccess::READ);
                if (file.is_null()) {
                    raise_error("LoadData: Could not open file: " + path, 201);
                    break;
                }
                content = file->get_as_text();
                file->close();
            }
            
            // Parse using static helper
            Vector<ExpressionNode*> new_data = VisualGasicParser::parse_data_values_from_text(content);
            
            // Append to data_segments
            for(int i=0; i<new_data.size(); i++) {
                data_segments.push_back(new_data[i]);
                runtime_data_nodes.push_back(new_data[i]);
            }
            
            break;
        }
        case STMT_CLEAR_DATA: {
            clear_data_tape();
            break;
        }
        case STMT_SELECT: {
            SelectStatement* s = (SelectStatement*)stmt;
            Variant val = evaluate_expression(s->expression);
            
            for(int i=0; i<s->cases.size(); i++) {
                CaseBlock* block = s->cases[i];
                bool match = false;
                
                if (block->is_else) {
                    match = true;
                } else {
                    for(int j=0; j<block->values.size(); j++) {
                        Variant c = evaluate_expression(block->values[j]);
                        
                        // Check for comparison operator (Case Is > value)
                        if (j < block->comparison_ops.size() && !block->comparison_ops[j].is_empty()) {
                            String comp_op = block->comparison_ops[j];
                            bool valid;
                            Variant res;
                            
                            if (comp_op == ">") {
                                Variant::evaluate(Variant::OP_GREATER, val, c, res, valid);
                            } else if (comp_op == "<") {
                                Variant::evaluate(Variant::OP_LESS, val, c, res, valid);
                            } else if (comp_op == ">=") {
                                Variant::evaluate(Variant::OP_GREATER_EQUAL, val, c, res, valid);
                            } else if (comp_op == "<=") {
                                Variant::evaluate(Variant::OP_LESS_EQUAL, val, c, res, valid);
                            } else if (comp_op == "<>") {
                                Variant::evaluate(Variant::OP_NOT_EQUAL, val, c, res, valid);
                            } else if (comp_op == "=") {
                                Variant::evaluate(Variant::OP_EQUAL, val, c, res, valid);
                            } else {
                                valid = false;
                            }
                            
                            if (valid && res.booleanize()) {
                                match = true;
                                break;
                            }
                        }
                        // Check if this is a range (X To Y)
                        else if (j < block->range_ends.size() && block->range_ends[j] != nullptr) {
                            Variant range_end = evaluate_expression(block->range_ends[j]);
                            // val >= c AND val <= range_end
                            bool valid1, valid2;
                            Variant res1, res2;
                            Variant::evaluate(Variant::OP_GREATER_EQUAL, val, c, res1, valid1);
                            Variant::evaluate(Variant::OP_LESS_EQUAL, val, range_end, res2, valid2);
                            if (res1.booleanize() && res2.booleanize()) {
                                match = true;
                                break;
                            }
                        } else {
                            // Simple value match
                            bool valid; Variant res;
                            Variant::evaluate(Variant::OP_EQUAL, val, c, res, valid);
                            if (res.booleanize()) {
                                match = true;
                                break;
                            }
                        }
                    }
                }
                
                if (match) {
                    for(int k=0; k<block->body.size(); k++) execute_statement(block->body[k]);
                    break;
                }
            }
            break;
        }
        case STMT_SEEK: {
            SeekStatement* s = (SeekStatement*)stmt;
            int fn = (int)evaluate_expression(s->file_number);
            int pos = (int)evaluate_expression(s->position);
            
            if (open_files.has(fn)) {
                Ref<FileAccess> fa = open_files[fn];
                fa->seek(pos); // In Godot, seek is absolute from beginning
                if (fa->get_error() != Error::OK) {
                   raise_error("Seek Failed", 53); // File not found or IO Error? 53 is generic file error
                }
            } else {
                raise_error("Bad File Number", 52);
            }
            break;
        }
        case STMT_KILL: {
            KillStatement* s = (KillStatement*)stmt;
            String path = evaluate_expression(s->path);
            Error err = DirAccess::remove_absolute(path);
            if (err != Error::OK) {
                // If relative to "user://" implied? No, default behavior is exact path.
                // Try ProjectSettings globalize_path?
                // For now, raw path.
                raise_error("Kill Failed (Error " + String::num(err) + "): " + path, 53);
            }
            break;
        }
        case STMT_RAISE_EVENT: {
            RaiseEventStatement* s = (RaiseEventStatement*)stmt;
            if (owner) {
                // Check if signal exists on script?
                // Actually emit_signal checks this.
                // We need to pass args.
                // Godot's emit_signal takes variadic, but in C++ it's emit_signal(name, val1, val2...)
                // We have a version taking an array of variants? No?
                // We must use callv or similar?
                // Object::emit_signal is vararg.
                // But we can call "emit_signal" via call() which takes varargs?
                // Actually internal emit_signal takes a const Variant **p_args, int p_argcount.
                
                // Let's assume max args or use a helper. 
                // Using call("emit_signal", "name", arg1...) is clumsy.
                // AccessObject::get_internal_ptr(owner)->emit_signal(...)
                
                // Workaround: Use 'emit_signal' method dynamic call.
                // It requires arguments.
                
                Array args;
                args.push_back(s->expression_name);
                for(int i=0; i<s->arguments.size(); i++) {
                     args.push_back(evaluate_expression(s->arguments[i]));
                }
                
                bool err=false;
                // We can't easily call emit_signal with array without callv, but Object doesn't expose callv for everything.
                // Actually Object::emit_signal acts like a method.
                // But wait! There is no 'callv' on Object in C++.
                // We can use emit_signal exposed in godot-cpp, but it is variadic template.
                // We can't spread an array.
                
                // Fallback: Use 'emit_signal' via call()? No, emit_signal is not a script method usually.
                // However, GDScript `emit_signal` IS a method.
                // Correct way in GDExtension:
                int argc = args.size() - 1; // First is name
                StringName sname = s->expression_name;
                
                if (argc == 0) owner->emit_signal(sname);
                else if (argc == 1) owner->emit_signal(sname, args[1]);
                else if (argc == 2) owner->emit_signal(sname, args[1], args[2]);
                else if (argc == 3) owner->emit_signal(sname, args[1], args[2], args[3]);
                else if (argc == 4) owner->emit_signal(sname, args[1], args[2], args[3], args[4]);
                else if (argc == 5) owner->emit_signal(sname, args[1], args[2], args[3], args[4], args[5]);
                // Limit 5 args for now.
            }
            break;
        }


        case STMT_EXIT: {
            ExitStatement* s = (ExitStatement*)stmt;
            if (s->exit_type == ExitStatement::EXIT_SUB || s->exit_type == ExitStatement::EXIT_FUNCTION) {
                error_state.mode = ErrorState::EXIT_SUB;
            } else if (s->exit_type == ExitStatement::EXIT_FOR) {
                error_state.mode = ErrorState::EXIT_FOR;
            } else if (s->exit_type == ExitStatement::EXIT_DO) {
                error_state.mode = ErrorState::EXIT_DO;
            }
            error_state.has_error = true; // Signal interruption flow
            break;
        }
        case STMT_REDIM: {
            ReDimStatement* s = (ReDimStatement*)stmt;
            
            // Calculate Dims
            Vector<int> dims;
            for(int i=0; i<s->array_sizes.size(); i++) {
                dims.push_back((int)evaluate_expression(s->array_sizes[i]) + 1); // 0..N
            }
            
            if (s->preserve) {
                if (!variables.has(s->variable_name)) {
                     raise_error("ReDim Preserve require existing array");
                     break;
                }
                Variant v = variables[s->variable_name];
                if (v.get_type() != Variant::ARRAY) {
                    raise_error("Variable is not an array");
                    break;
                }
                
                // VB6 rule: ReDim Preserve can only change the LAST dimension
                if (dims.size() == 1) {
                    // 1D array - simple resize
                    Array arr = v;
                    arr.resize(dims[0]);
                    variables[s->variable_name] = arr;
                } else {
                    // Multi-dimensional array: only the last dimension can change
                    // Validate that the existing array has the same number of dimensions
                    Array existing_arr = v;
                    
                    // Helper lambda to get dimensions of a nested array
                    auto get_array_dims = [](Array arr) -> Vector<int> {
                        Vector<int> result;
                        Array current = arr;
                        while (current.size() > 0) {
                            result.push_back(current.size());
                            if (current[0].get_type() == Variant::ARRAY) {
                                current = current[0];
                            } else {
                                break;
                            }
                        }
                        if (result.size() == 0 && arr.size() > 0) {
                            result.push_back(arr.size());
                        }
                        return result;
                    };
                    
                    Vector<int> old_dims = get_array_dims(existing_arr);
                    
                    if (old_dims.size() != dims.size()) {
                        raise_error("ReDim Preserve cannot change number of dimensions");
                        break;
                    }
                    
                    // Check that all dimensions except the last one match
                    for (int i = 0; i < dims.size() - 1; i++) {
                        if (old_dims[i] != dims[i]) {
                            raise_error("ReDim Preserve can only change the last dimension");
                            break;
                        }
                    }
                    
                    if (error_state.has_error) break;
                    
                    // Resize the last dimension of each innermost array
                    // For 2D arr(a, b): arr is outer (size a+1), arr[i] are inner (resize to b+1)
                    // For 3D arr(a, b, c): arr[i] are middle, arr[i][j] are inner (resize to c+1)
                    
                    int new_last_dim_size = dims[dims.size() - 1];
                    int num_dims = dims.size();
                    
                    // Recursive helper to resize innermost arrays
                    // depth_from_leaf: 0 = current array is the innermost, 1 = children are innermost, etc.
                    struct PreserveResizer {
                        static void resize_at_depth(Array& arr, int current_depth, int leaf_depth, int new_size) {
                            // leaf_depth is where the innermost arrays are (num_dims - 2)
                            // For 2D (num_dims=2): leaf_depth=0, so at depth 0 we resize arr[i]
                            // For 3D (num_dims=3): leaf_depth=1, so at depth 1 we resize arr[i][j]
                            
                            if (current_depth == leaf_depth) {
                                // The elements of this array are the innermost arrays to resize
                                for (int i = 0; i < arr.size(); i++) {
                                    if (arr[i].get_type() == Variant::ARRAY) {
                                        Array inner = arr[i];
                                        inner.resize(new_size);
                                        arr[i] = inner;
                                    }
                                }
                            } else if (current_depth < leaf_depth) {
                                // Go deeper
                                for (int i = 0; i < arr.size(); i++) {
                                    if (arr[i].get_type() == Variant::ARRAY) {
                                        Array inner = arr[i];
                                        resize_at_depth(inner, current_depth + 1, leaf_depth, new_size);
                                        arr[i] = inner;
                                    }
                                }
                            }
                        }
                    };
                    
                    // For 2D (num_dims=2), leaf_depth = 0
                    // For 3D (num_dims=3), leaf_depth = 1
                    int leaf_depth = num_dims - 2;
                    PreserveResizer::resize_at_depth(existing_arr, 0, leaf_depth, new_last_dim_size);
                    
                    variables[s->variable_name] = existing_arr;
                }
            } else {
                 // Clone ArrayBuilder logic
                 struct LocalArrayBuilder {
                    static Array create(const Vector<int>& d, int depth, const String& type_name, const Dictionary& prototypes) {
                         Array a;
                         int size = d[depth];
                         a.resize(size);
                         if (depth < d.size() - 1) {
                             for(int i=0; i<size; i++) {
                                 a[i] = create(d, depth+1, type_name, prototypes);
                             }
                         } else {
                             // Leaf: Try to init structs, otherwise null
                             if (!type_name.is_empty() && prototypes.has(type_name)) {
                                 for(int i=0; i<size; i++) {
                                     a[i] = ((Dictionary)prototypes[type_name]).duplicate(true);
                                 }
                             }
                         }
                         return a;
                    }
                };
                
                // We don't have type info in ReDimStatement directly in current Parser.
                // Assuming Variant arrays (nulls) unless we track variable types separately.
                // For now, type_name is empty.
                variables[s->variable_name] = LocalArrayBuilder::create(dims, 0, "", struct_prototypes);
            }
            break;
        }
        case STMT_ERASE: {
            EraseStatement* es = (EraseStatement*)stmt;
            if (variables.has(es->variable_name)) {
                Variant cur = variables[es->variable_name];
                if (cur.get_type() == Variant::ARRAY) {
                    variables[es->variable_name] = Array();
                } else if (cur.get_type() == Variant::DICTIONARY) {
                    variables[es->variable_name] = Dictionary();
                } else {
                    // For numeric/string types, reset to default
                    variables[es->variable_name] = Variant();
                }
            }
            break;
        }
        case STMT_OPEN: {
            OpenStatement* s = (OpenStatement*)stmt;
            String path = evaluate_expression(s->path);
            int fn = evaluate_expression(s->file_number);
            
            if (open_files.has(fn)) {
                raise_error("File already open: " + String::num(fn));
                break;
            }
            
            Ref<FileAccess> fa;
            if (s->mode == OpenStatement::MODE_INPUT) fa = FileAccess::open(path, FileAccess::READ);
            else if (s->mode == OpenStatement::MODE_OUTPUT) fa = FileAccess::open(path, FileAccess::WRITE);
            else if (s->mode == OpenStatement::MODE_APPEND) {
                 if (FileAccess::file_exists(path)) {
                     fa = FileAccess::open(path, FileAccess::READ_WRITE);
                     if (fa.is_valid()) fa->seek_end();
                 } else {
                     fa = FileAccess::open(path, FileAccess::WRITE);
                 }
            }
            else if (s->mode == OpenStatement::MODE_BINARY || s->mode == OpenStatement::MODE_RANDOM) {
                 // Binary/Random: open read-write, create if needed
                 if (FileAccess::file_exists(path)) {
                     fa = FileAccess::open(path, FileAccess::READ_WRITE);
                 } else {
                     fa = FileAccess::open(path, FileAccess::WRITE_READ);
                 }
            }
            
            if (fa.is_null()) { 
                 raise_error("Failed to open file: " + path);
            } else {
                 open_files[fn] = fa;
            }
            break;
        }
        case STMT_CLOSE: {
             CloseStatement* s = (CloseStatement*)stmt;
             if (s->file_number) {
                 int fn = evaluate_expression(s->file_number);
                 if (open_files.has(fn)) {
                      open_files.erase(fn); 
                 }
             } else {
                 open_files.clear();
             }
             break;
        }
        case STMT_INPUT: {
            InputStatement* s = (InputStatement*)stmt;
            if (s->file_number) {
                int fn = evaluate_expression(s->file_number);
                if (open_files.has(fn)) {
                    Ref<FileAccess> fa = open_files[fn];
                    if (s->is_line_input) {
                        String line = fa->get_line();
                        if (s->variables.size() > 0) {
                             assign_to_target(s->variables[0], line);
                        }
                    } else {
                        PackedStringArray values = fa->get_csv_line();
                        for(int i=0; i<s->variables.size() && i<values.size(); i++) {
                             Variant val = values[i];
                             if (String(val).is_valid_float()) val = String(val).to_float(); 
                             assign_to_target(s->variables[i], val); 
                        }
                    }
                } else {
                    raise_error("Bad File Name or Number");
                }
            }
            break;
        }
        case STMT_NAME: {
            NameStatement* s = (NameStatement*)stmt;
            String old_path = evaluate_expression(s->old_path);
            String new_path = evaluate_expression(s->new_path);
            Error err = DirAccess::rename_absolute(old_path, new_path);
            if (err != Error::OK) {
                raise_error("Name (Rename) Failed (Error " + String::num(err) + "): " + old_path + " -> " + new_path, 53);
            }
            break;
        }
        
        // === MULTITASKING STATEMENT EXECUTION ===
        case STMT_ASYNC_FUNCTION: {
            AsyncFunctionStatement* s = (AsyncFunctionStatement*)stmt;
            execute_async_function(s);
            break;
        }
        case STMT_AWAIT: {
            // This would be handled in expression evaluation, but could be a statement too
            break;
        }
        case STMT_TASK_RUN: {
            TaskRunStatement* s = (TaskRunStatement*)stmt;
            execute_task_run(s);
            break;
        }
        case STMT_TASK_WAIT: {
            TaskWaitStatement* s = (TaskWaitStatement*)stmt;
            execute_task_wait(s);
            break;
        }
        case STMT_PARALLEL_FOR: {
            ParallelForStatement* s = (ParallelForStatement*)stmt;
            execute_parallel_for(s);
            break;
        }
        case STMT_PARALLEL_SECTION: {
            ParallelSectionStatement* s = (ParallelSectionStatement*)stmt;
            execute_parallel_section(s);
            break;
        }
        case STMT_LOCK: {
            instance_mutex_.lock();
            break;
        }
        case STMT_UNLOCK: {
            instance_mutex_.unlock();
            break;
        }
        
        case STMT_PATTERN_MATCH: {
            PatternMatchStatement* s = (PatternMatchStatement*)stmt;
            execute_pattern_match(s);
            break;
        }
        
        default: break;
    }
}

// Convert Godot snake_case virtual method names to VG PascalCase.
// e.g. "_unhandled_input" → "_UnhandledInput", "_physics_process" → "_PhysicsProcess"
// Single-word methods like "_input" → "_Input" also work (though nocasecmp_to
// already handles those, this keeps the conversion uniform).
static String godot_snake_to_vg_pascal(const String& method) {
    // Only convert methods starting with underscore (Godot virtuals)
    if (!method.begins_with("_") || method.length() < 2) return method;
    // Check if there are any underscores after the leading one
    // (if not, it's already single-word like "_input" — no conversion needed)
    if (method.find("_", 1) < 0) return method;
    
    String result = "_";
    bool cap_next = true;
    for (int i = 1; i < method.length(); i++) {
        char32_t c = method[i];
        if (c == '_') {
            cap_next = true;
        } else {
            if (cap_next) {
                // Capitalize: convert to uppercase
                if (c >= 'a' && c <= 'z') c = c - 'a' + 'A';
                cap_next = false;
            }
            result += String::chr(c);
        }
    }
    return result;
}
