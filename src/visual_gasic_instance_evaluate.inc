Variant VisualGasicInstance::evaluate_expression(ExpressionNode* expr) {
    if (!expr) return Variant();

    if (expr->type == ExpressionNode::EXPRESSION_IIF) {
        IIfNode* iif = (IIfNode*)expr;
        if (!iif->condition || !iif->true_part || !iif->false_part) {
            raise_error("Invalid IIf expression - missing parts");
            return Variant();
        }
        Variant cond = evaluate_expression(iif->condition);
        if (cond.booleanize()) {
            return evaluate_expression(iif->true_part);
        } else {
            return evaluate_expression(iif->false_part);
        }
    }

    if (expr->type == ExpressionNode::WITH_CONTEXT) {
        if (with_stack.is_empty()) {
            raise_error("Invalid use of .Member outside With block");
            return Variant();
        }
        return with_stack[with_stack.size() - 1]; // Top of stack
    }
    
    if (expr->type == ExpressionNode::LITERAL) {
        // Check if this is an ArrayLiteralNode or DictLiteralNode (both use LITERAL type)
        ArrayLiteralNode* arr_lit = dynamic_cast<ArrayLiteralNode*>(expr);
        if (arr_lit) {
            Array result;
            for (int i = 0; i < arr_lit->elements.size(); i++) {
                result.push_back(evaluate_expression(arr_lit->elements[i]));
            }
            return result;
        }
        DictLiteralNode* dict_lit = dynamic_cast<DictLiteralNode*>(expr);
        if (dict_lit) {
            Dictionary result;
            for (int i = 0; i < dict_lit->keys.size(); i++) {
                Variant key = evaluate_expression(dict_lit->keys[i]);
                Variant val = evaluate_expression(dict_lit->values[i]);
                result[key] = val;
            }
            return result;
        }
        return ((LiteralNode*)expr)->value;
    }
    if (expr->type == ExpressionNode::ME) {
        if (!owner) return Variant(); // Or error?
        // Note: owner is Object*. Returning it as Variant usually works but requires safety?
        // Godot-cpp Variant constructor from Object* should handle it.
        return owner;
    }
    if (expr->type == ExpressionNode::NEW) {
        NewNode* n = (NewNode*)expr;
        
        // MemoryBlock -> PackedByteArray
        if (n->class_name.nocasecmp_to("MemoryBlock") == 0) {
            int size = 0;
            if (n->args.size() > 0) {
                 Variant v = evaluate_expression(n->args[0]);
                 size = (int)v;
            }
            PackedByteArray pba;
            pba.resize(size);
            return pba;
        }

        if (n->class_name.nocasecmp_to("Dictionary") == 0) {
            return Dictionary();
        }
        
        // Custom Structs or Types?
        // Use struct_prototypes for proper typed defaults + fixed-length strings
        if (struct_prototypes.has(n->class_name)) {
            return ((Dictionary)struct_prototypes[n->class_name]).duplicate(true);
        }
        // Case-insensitive fallback
        if (script.is_valid() && script->ast_root) {
            for(int i=0; i<script->ast_root->structs.size(); i++) {
                if (script->ast_root->structs[i]->name.nocasecmp_to(n->class_name) == 0) {
                     String actual_name = script->ast_root->structs[i]->name;
                     if (struct_prototypes.has(actual_name)) {
                         return ((Dictionary)struct_prototypes[actual_name]).duplicate(true);
                     }
                     // Fallback: create with basic defaults
                     Dictionary d;
                     d[STRUCT_TYPE_KEY_CSTR] = actual_name;
                     StructDefinition* def = script->ast_root->structs[i];
                     for(int m=0; m<def->members.size(); m++) {
                         d[def->members[m].name] = Variant();
                     }
                     return d;
                }
            }
        }
        
        // Check VG class definitions
        if (class_registry.has(n->class_name)) {
            Array args_arr;
            for (int i = 0; i < n->args.size(); i++) {
                args_arr.push_back(evaluate_expression(n->args[i]));
            }
            return instantiate_class(n->class_name, args_arr);
        }

        // VB6-friendly aliases for system classes (v2.9.0)
        {
            String alias = n->class_name;
            String resolved;
            if (alias.nocasecmp_to("Process") == 0) resolved = "VGProcess";
            else if (alias.nocasecmp_to("Database") == 0) resolved = "VGDatabase";
            else if (alias.nocasecmp_to("FileSystemWatcher") == 0) resolved = "VGFileWatcher";
            else if (alias.nocasecmp_to("CommonDialog") == 0) resolved = "VGCommonDialog";
            else if (alias.nocasecmp_to("WinSock") == 0 || alias.nocasecmp_to("Socket") == 0) resolved = "VGSocket";
            else if (alias.nocasecmp_to("SysTray") == 0) resolved = "VGSysTray";
            else if (alias.nocasecmp_to("Settings") == 0) resolved = "VGSettings";
            else if (alias.nocasecmp_to("FileSystemObject") == 0) resolved = "VGFileSystemObject";
            else if (alias.nocasecmp_to("ScriptingDictionary") == 0) resolved = "VGScriptingDict";
            else if (alias.nocasecmp_to("WScriptShell") == 0) resolved = "VGWScriptShell";
            else if (alias.nocasecmp_to("ComObject") == 0) resolved = "VGComObject";
                    // v2.10.0 aliases
                    else if (alias.nocasecmp_to("HttpRequest") == 0 || alias.nocasecmp_to("XMLHTTP") == 0) resolved = "VGHttpRequest";
                    else if (alias.nocasecmp_to("Collection") == 0) resolved = "VGCollection";
                    else if (alias.nocasecmp_to("RegExp") == 0) resolved = "VGRegEx";
                    else if (alias.nocasecmp_to("Timer") == 0 || alias.nocasecmp_to("VBTimer") == 0) resolved = "VGTimer";
                    // v3.0 aliases
                    else if (alias.nocasecmp_to("NativeLibrary") == 0) resolved = "VGNativeLibrary";
                    else if (alias.nocasecmp_to("NativeStruct") == 0) resolved = "VGNativeStruct";
                    else if (alias.nocasecmp_to("Odbc") == 0) resolved = "VGOdbc";
                    else if (alias.nocasecmp_to("Crypto") == 0) resolved = "VGCrypto";
                    else if (alias.nocasecmp_to("Xml") == 0) resolved = "VGXml";
                    else if (alias.nocasecmp_to("Zip") == 0) resolved = "VGZip";
                    else if (alias.nocasecmp_to("Task") == 0) resolved = "VGTask";
                    else if (alias.nocasecmp_to("TaskRunner") == 0) resolved = "VGTaskRunner";
                    // v3.1 aliases
                    else if (alias.nocasecmp_to("System") == 0) resolved = "VGSystem";
                    else if (alias.nocasecmp_to("SignalHandler") == 0) resolved = "VGSignalHandler";
                    else if (alias.nocasecmp_to("FilePermissions") == 0) resolved = "VGFilePermissions";
                    else if (alias.nocasecmp_to("MemoryBuffer") == 0) resolved = "VGMemoryBuffer";
                    else if (alias.nocasecmp_to("IPC") == 0) resolved = "VGIPC";
                    else if (alias.nocasecmp_to("AndroidBridge") == 0) resolved = "VGAndroidBridge";
                    // v3.2 aliases – GPU & ECS
                    else if (alias.nocasecmp_to("Gpu") == 0 || alias.nocasecmp_to("VGGpu") == 0) resolved = "VisualGasicGPU";
                    else if (alias.nocasecmp_to("ECS") == 0 || alias.nocasecmp_to("VGEcs") == 0) resolved = "VisualGasicECS";
                    // v4.3 aliases – Database controls
                    else if (alias.nocasecmp_to("Recordset") == 0 || alias.nocasecmp_to("ADODB.Recordset") == 0) resolved = "VGRecordset";
                    // Also resolve full VG* names for v3.0+ (bypass can_instantiate issue)
                    else if (alias.begins_with("VG") && ClassDB::class_exists(alias)) resolved = alias;

            if (!resolved.is_empty() && ClassDB::class_exists(resolved)) {
                Variant inst = ClassDB::instantiate(resolved);
                if (inst.get_type() == Variant::OBJECT) return inst;
            }
        }

        // Try Godot ClassDB
        if (ClassDB::class_exists(n->class_name)) {
             // Guard: singletons like ProjectSettings crash if you
             // call ClassDB::instantiate() on them.  Return the
             // existing singleton instead.
             if (Engine::get_singleton()->has_singleton(n->class_name)) {
                 Object *s = Engine::get_singleton()->get_singleton(n->class_name);
                 if (s) return Variant(s);
                 return Variant();
             }
             if (!ClassDB::can_instantiate(n->class_name)) {
                 return Variant();
             }
             // Keep as Variant so RefCounted subclasses retain their refcount.
             Variant inst = ClassDB::instantiate(n->class_name);
             if (inst.get_type() == Variant::OBJECT) return inst;
        }

        return Variant(); 
    }

    if (expr->type == ExpressionNode::VARIABLE) {
        String name = ((VariableNode*)expr)->name;
        
        // VB6 "Me" keyword - returns the owner object (self reference)
        if (name.nocasecmp_to("Me") == 0) {
            if (owner) return owner;
            raise_error("'Me' keyword used but no owner object available");
            return Variant();
        }
        
        // ── VB6 Intrinsic Constants ──
        if (name.nocasecmp_to("vbCrLf") == 0) return String("\r\n");
        if (name.nocasecmp_to("vbCr") == 0) return String("\r");
        if (name.nocasecmp_to("vbLf") == 0) return String("\n");
        if (name.nocasecmp_to("vbTab") == 0) return String("\t");
        if (name.nocasecmp_to("vbNullString") == 0) return String("");
        if (name.nocasecmp_to("vbNullChar") == 0) return String(String::chr(0));
        if (name.nocasecmp_to("vbNewLine") == 0) return String("\n");
        if (name.nocasecmp_to("vbBack") == 0) return String(String::chr(8));
        if (name.nocasecmp_to("vbFormFeed") == 0) return String(String::chr(12));
        if (name.nocasecmp_to("vbVerticalTab") == 0) return String(String::chr(11));
        if (name.nocasecmp_to("vbQuote") == 0) return String("\"");
        if (name.nocasecmp_to("vbSpace") == 0) return String(" ");
        if (name.nocasecmp_to("vbComma") == 0) return String(",");
        if (name.nocasecmp_to("vbPipe") == 0) return String("|");
        // VB6 Boolean constants
        if (name.nocasecmp_to("vbTrue") == 0) return true;
        if (name.nocasecmp_to("vbFalse") == 0) return false;
        // Nothing / Null / Empty
        if (name.nocasecmp_to("Nothing") == 0) return Variant();
        if (name.nocasecmp_to("Null") == 0) return Variant();
        if (name.nocasecmp_to("Empty") == 0) return Variant();
        // PI and E as standalone constants
        if (name.nocasecmp_to("PI") == 0) return Math_PI;
        if (name.nocasecmp_to("E") == 0 && !variables.has("E") && !variables.has("e")) return Math_E;
        
        if (name.nocasecmp_to("FreeFile") == 0) {
             for(int i=1; i<=255; i++) {
                 if (!open_files.has(i)) return i;
             }
             raise_error("Too many files open");
             return 0;
        }

        if (name.nocasecmp_to("Godot") == 0) {
            // Return a special marker? Or can we return Engine?
            // Engine is an Object.
            return Engine::get_singleton();
        }
        
        // Input singleton for Input.IsActionPressed(), etc.
        if (name.nocasecmp_to("Input") == 0) {
            return Input::get_singleton();
        }
        
        // General Godot singleton resolution (Engine, OS, Time, etc.)
        if (Engine::get_singleton()->has_singleton(name)) {
            Object *singleton = Engine::get_singleton()->get_singleton(name);
            if (singleton) return Variant(singleton);
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
            return app;
        }
        if (name.nocasecmp_to("Screen") == 0) {
            Dictionary screen;
            Vector2i screen_size = DisplayServer::get_singleton()->screen_get_size();
            screen["Width"] = screen_size.x;
            screen["Height"] = screen_size.y;
            screen["TwipsPerPixelX"] = 1;
            screen["TwipsPerPixelY"] = 1;
            screen["MousePointer"] = 0;
            return screen;
        }
        if (name.nocasecmp_to("Err") == 0) {
            if (variables.has("Err")) {
                return variables["Err"];
            }
            Dictionary err;
            err["Number"] = 0;
            err["Description"] = String("");
            err["Source"] = String("");
            variables["Err"] = err;
            return err;
        }
        // VB6 Printer global object (v3.5.0) — persistent dictionary like Err
        if (name.nocasecmp_to("Printer") == 0) {
            if (variables.has("__vg_Printer")) {
                return variables["__vg_Printer"];
            }
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
            return printer;
        }
        
        if (variables.has(name)) {
            if (name.nocasecmp_to("wheneverTriggered") == 0) {
            }
            return variables[name];
        }
        // Fallback to built-in constants (separated so debugger only shows user vars)
        if (builtin_constants.has(name)) {
            return builtin_constants[name];
        }
        
        // Debug
        // UtilityFunctions::print("Variable not found in map: ", name);
        // UtilityFunctions::print("Map Keys: ", variables.keys());
        
        // Property Access on Owner
        if (owner) {
             Variant ret = owner->get(name);
             if (ret.get_type() != Variant::NIL) return ret;

             // Fallback: snake_case
             String snake = name.to_snake_case();
             ret = owner->get(snake);
             if (ret.get_type() != Variant::NIL) return ret;
             
             // Search for child controls by name (VB6 style - controls are accessible by name)
             Node* owner_node = Object::cast_to<Node>(owner);
             if (owner_node) {
                 Node *found = owner_node->find_child(name, true, false);
                 // Fallback: search parent (VGASIC helper node pattern)
                 if (!found && owner_node->get_parent()) {
                     found = owner_node->get_parent()->find_child(name, true, false);
                 }
                 if (found) {
                     return found;
                 }
             }
        }

        // Check Autoloads (Globals)
        if (owner) {
             Node* owner_node = Object::cast_to<Node>(owner);
             if (owner_node && owner_node->is_inside_tree()) {
                 SceneTree *tree = owner_node->get_tree();
                 if (tree) {
                     Node* root = tree->get_root();
                     if (root && root->has_node(name)) {
                         return root->get_node<Node>(name);
                     }
                 }
                 // Try PascalCase -> snake_case? Autoloads are usually PascalCase though.
             }
        }
        
        return Variant();
    }
    if (expr->type == ExpressionNode::MEMBER_ACCESS) {
         MemberAccessNode* ma = (MemberAccessNode*)expr;
         
         // Check for null base from parser errors
         if (!ma->base_object) {
             raise_error("Incomplete member access: missing base object");
             return Variant();
         }
         
         // Color.White, Color.Red, etc. — named color constants
         if (ma->base_object->type == ExpressionNode::VARIABLE) {
             String base_name = ((VariableNode*)ma->base_object)->name;
             if (base_name == "Color") {
                 return Color::named(ma->member_name);
             }
             // Math.PI, Math.E constants
             if (base_name.nocasecmp_to("Math") == 0) {
                 if (ma->member_name.nocasecmp_to("PI") == 0) return Math_PI;
                 if (ma->member_name.nocasecmp_to("E") == 0) return Math_E;
                 if (ma->member_name.nocasecmp_to("Tau") == 0) return Math_TAU;
                 if (ma->member_name.nocasecmp_to("Infinity") == 0) return INFINITY;
                 if (ma->member_name.nocasecmp_to("NaN") == 0) return NAN;
             }
             // Debug.Assert — assert expression is truthy
             if (base_name.nocasecmp_to("Debug") == 0) {
                 if (ma->member_name.nocasecmp_to("Assert") == 0) {
                     // Debug.Assert evaluated as a member access returns a marker;
                     // actual assertion is handled by Call dispatch
                     return String("__vg_debug_assert");
                 }
             }
             // ── Enum value access: EnumName.MemberName ──
             {
                 ModuleNode* root = cached_ast_root;
                 if (!root && script.is_valid() && script->ast_root) {
                     root = script->ast_root;
                 }
                 if (root) {
                     for (int ei = 0; ei < root->enums.size(); ei++) {
                         EnumDefinition* ed = root->enums[ei];
                         if (ed->name.nocasecmp_to(base_name) == 0) {
                             for (int vi = 0; vi < ed->values.size(); vi++) {
                                 if (ed->values[vi].name.nocasecmp_to(ma->member_name) == 0) {
                                     return ed->values[vi].value;
                                 }
                             }
                             raise_error("Enum '" + ed->name + "' has no member '" + ma->member_name + "'");
                             return Variant();
                         }
                     }
                 }
             }
             // Godot class enum constants: Input.MOUSE_MODE_CAPTURED, Sky.PROCESS_MODE_QUALITY, etc.
             // Try as-is first, then UPPER_CASE (tokenizer normalises keywords
             // like READ → "Read" but Godot constants are ALL_CAPS).
             if (ClassDB::class_exists(base_name)) {
                 String mname = ma->member_name;
                 if (!ClassDB::class_has_integer_constant(base_name, mname)) {
                     mname = mname.to_upper();
                 }
                 if (ClassDB::class_has_integer_constant(base_name, mname)) {
                     return (int)ClassDB::class_get_integer_constant(base_name, mname);
                 }
             }
             
             // ── Imported module member access: ModuleName.Variable / .Constant (v4.3.0) ──
             if (module_registry.has(base_name)) {
                 Dictionary mod_dict = module_registry[base_name];
                 if (mod_dict.has(ma->member_name)) {
                     return mod_dict[ma->member_name];
                 }
                 // Check enums in imported module
                 for (int m = 0; m < imported_modules.size(); m++) {
                     if (imported_modules[m].module_name.nocasecmp_to(base_name) == 0 && imported_modules[m].ast) {
                         ModuleNode* imod = imported_modules[m].ast;
                         for (int ei = 0; ei < imod->enums.size(); ei++) {
                             for (int vi = 0; vi < imod->enums[ei]->values.size(); vi++) {
                                 if (imod->enums[ei]->values[vi].name.nocasecmp_to(ma->member_name) == 0) {
                                     return imod->enums[ei]->values[vi].value;
                                 }
                             }
                         }
                         break;
                     }
                 }
             }
         }
         
         Variant base = evaluate_expression(ma->base_object);
         
         // VG class instance (object ID is an integer)
         if (base.get_type() == Variant::INT) {
             int obj_id = (int)base;
             if (object_instances.has(obj_id)) {
                 Variant ret;
                 if (get_object_member(obj_id, ma->member_name, ret)) {
                     return ret;
                 }
             }
         }

         if (base.get_type() == Variant::DICTIONARY) {
             Dictionary d = base;
             // StringBuilder property access
             if (d.has("__vg_stringbuilder")) {
                 if (ma->member_name.nocasecmp_to("Length") == 0) {
                     Array buf = d["__buffer"];
                     int len = 0;
                     for (int i = 0; i < buf.size(); i++) len += String(buf[i]).length();
                     return len;
                 }
             }
             // VB6 Scripting.Dictionary property-style access
             if (ma->member_name.nocasecmp_to("Count") == 0) return d.size();
             if (ma->member_name.nocasecmp_to("Keys") == 0) return d.keys();
             if (ma->member_name.nocasecmp_to("Items") == 0) return d.values();
             if (d.has(ma->member_name)) return d[ma->member_name];
         }
         
         // Generic Variant Member Access (Object, Vector2, etc.)
         bool valid = false;
         Variant ret = base.get_named(ma->member_name, valid);
         if (valid && (ret.get_type() != Variant::NIL || base.has_method(ma->member_name))) return ret;
         
         // Try lowercase (for Vector2.X -> x)
         if (!valid) {
              ret = base.get_named(ma->member_name.to_lower(), valid);
              if (valid) return ret;
         }
         
         if (base.get_type() == Variant::OBJECT) {
             Object* obj = base;
             String prop_name = ma->member_name;
             
             // VB6 Property Aliasing (Read) — shared helper handles all 62 aliases
             if (obj) {
                  Variant vb6_result;
                  if (_vb6_read_property(obj, prop_name, vb6_result)) {
                      return vb6_result;
                  }
                  
                  // Range: Min, Max (not in shared helper — AST-specific)
                  if (obj->is_class("Range")) {
                       if (prop_name == "Min") return obj->get("min_value");
                       if (prop_name == "Max") return obj->get("max_value");
                  }
                  
                  // Timer.Enabled (start/stop, not shared)
                  if (obj->is_class("Timer") && prop_name == "Enabled") {
                      return !Object::cast_to<Timer>(obj)->is_stopped();
                  }
                  
                  // Tree: Rows, Cols
                  if (obj->is_class("Tree")) {
                       if (prop_name == "Rows") {
                           Tree *t = Object::cast_to<Tree>(obj);
                           return t->get_root() ? t->get_root()->get_child_count() : 0;
                       }
                       if (prop_name == "Cols") {
                           return Object::cast_to<Tree>(obj)->get_columns();
                       }
                  }
             }
             if (obj) {
                 Variant val = obj->get(prop_name);
                 if (val.get_type() != Variant::NIL) return val;
                 
                 String snake = prop_name.to_snake_case();
                 val = obj->get(snake);
                 if (val.get_type() != Variant::NIL) return val;
                 
                 // Fallback: class integer constants (e.g. Input.MOUSE_MODE_CAPTURED)
                 // Try as-is first, then UPPER_CASE (tokenizer normalises keywords).
                 StringName cn = obj->get_class();
                 String mname2 = ma->member_name;
                 if (!ClassDB::class_has_integer_constant(cn, mname2)) {
                     mname2 = mname2.to_upper();
                 }
                 if (ClassDB::class_has_integer_constant(cn, StringName(mname2))) {
                     return (int)ClassDB::class_get_integer_constant(cn, StringName(mname2));
                 }
             }
         }
         
         return Variant();
    }

    if (expr->type == ExpressionNode::ARRAY_ACCESS) {
         ArrayAccessNode* aa = (ArrayAccessNode*)expr;
         
         // Check for null base from parser errors
         if (!aa->base) {
             raise_error("Incomplete array access: missing base");
             return Variant();
         }
         
         Variant base = evaluate_expression(aa->base);
         
         if (base.get_type() == Variant::DICTIONARY) {
             Dictionary d = base;
             // Check if this is a lambda invocation
             if (d.has("__vg_lambda") && (bool)d["__vg_lambda"]) {
                 Array call_args;
                 for (int i = 0; i < aa->indices.size(); i++) {
                     call_args.push_back(evaluate_expression(aa->indices[i]));
                 }
                 return invoke_lambda(d, call_args);
             }
             if (aa->indices.size() > 0) {
                 // Check for null index expression
                 if (!aa->indices[0]) {
                     raise_error("Incomplete array access: missing index");
                     return Variant();
                 }
                 Variant key = evaluate_expression(aa->indices[0]);
                 if (d.has(key)) return d[key];
                 return Variant(); // Or error?
             }
         }

         if (base.get_type() == Variant::ARRAY) {
             Variant container = base;
             for(int i=0; i<aa->indices.size(); i++) {
                 if (container.get_type() != Variant::ARRAY) return Variant();
                 
                 // Check for null index expression
                 if (!aa->indices[i]) {
                     raise_error("Incomplete array access: missing index");
                     return Variant();
                 }
                 
                 Array arr = container;
                 int idx = evaluate_expression(aa->indices[i]);
                 if (idx >= 0 && idx < arr.size()) {
                     container = arr[idx];
                 } else {
                     raise_error("Subscript out of range", 9);
                     return Variant();
                 }
             }
             return container;
         }

         if (base.get_type() == Variant::DICTIONARY) {
             Variant container = base;
             for (int i = 0; i < aa->indices.size(); i++) {
                 if (container.get_type() != Variant::DICTIONARY) {
                     raise_error("Dictionary subscript invalid");
                     return Variant();
                 }
                 Dictionary dict = container;
                 Variant key = evaluate_expression(aa->indices[i]);
                 container = dict.get(key, Variant());
             }
             return container;
         }
         
         if (aa->base->type == ExpressionNode::VARIABLE) {
             String func_name = ((VariableNode*)aa->base)->name;
             Array call_args; 
             for(int i=0; i<aa->indices.size(); i++) call_args.push_back(evaluate_expression(aa->indices[i]));
             
             bool found = false;
             Variant v_ret = call_internal(func_name, call_args, found);
             if (found) return v_ret;

             if (owner) {
                 if (owner->has_method(func_name)) return owner->callv(func_name, call_args);
                 String snake = func_name.to_snake_case();
                 if (owner->has_method(snake)) {
                     return owner->callv(snake, call_args);
                 }
             }
             
             if (func_name == "Len" && call_args.size() == 1) return String(call_args[0]).length();
             if (func_name == "Left" && call_args.size() == 2) return String(call_args[0]).left(call_args[1]);
             if (func_name == "Right" && call_args.size() == 2) return String(call_args[0]).right(call_args[1]);
             if (func_name == "Mid" && call_args.size() >= 2) {
                  String s = call_args[0]; int st = (int)call_args[1]-1; if(st<0)st=0; 
                  return (call_args.size()==3)?s.substr(st,call_args[2]):s.substr(st);
             }
             if (func_name == "InStr" && call_args.size() == 2) {
                 String s1 = call_args[0]; String s2 = call_args[1]; int pos = s1.find(s2);
                 return (pos == -1) ? 0 : pos + 1;
             }
             if (func_name == "Replace" && call_args.size() == 3) return String(call_args[0]).replace(call_args[1], call_args[2]);
             if (func_name == "UCase" && call_args.size() == 1) return String(call_args[0]).to_upper();
             if (func_name == "LCase" && call_args.size() == 1) return String(call_args[0]).to_lower();
             if (func_name == "Trim" && call_args.size() == 1) return String(call_args[0]).strip_edges();
             if (func_name == "StrReverse" && call_args.size() == 1) {
                  String s = call_args[0]; String res=""; for(int i=s.length()-1; i>=0; i--) res+=s[i]; return res;
             }
             
             if (func_name == "CType" && call_args.size() == 2) {
                 Variant val = call_args[0];
                 String type_name = String(call_args[1]).to_lower();
                 
                 if (type_name == "integer" || type_name == "int") return (int)val;
                 if (type_name == "long" || type_name == "longlong") return (int64_t)val;
                 if (type_name == "float" || type_name == "double" || type_name == "single") return (double)val;
                 if (type_name == "string") return String(val);
                 if (type_name == "boolean" || type_name == "bool") return (bool)val;
                 return val; 
             }
             if (func_name == "CInt" && call_args.size() == 1) return (int)call_args[0];
             if (func_name == "CLng" && call_args.size() == 1) return (int64_t)call_args[0];
             if (func_name == "CLngLng" && call_args.size() == 1) return (int64_t)call_args[0];
             if (func_name == "CDbl" && call_args.size() == 1) return (double)call_args[0];
             if (func_name == "CStr" && call_args.size() == 1) return String(call_args[0]);
             if (func_name == "CBool" && call_args.size() == 1) return (bool)call_args[0];

             if (func_name.nocasecmp_to("Array") == 0) {
                 return call_args; 
             }
             // TwinBasic / Extended String Functions
             if (func_name == "Split" && call_args.size() >= 2) {
                 String s = call_args[0];
                 String delim = call_args[1];
                 PackedStringArray psa = s.split(delim);
                 Array ret;
                 for(int i=0; i<psa.size(); i++) ret.push_back(psa[i]);
                 return ret;
             }
             if (func_name == "Join" && call_args.size() >= 1) {
                 Variant source = call_args[0];
                 String delim = (call_args.size() >= 2) ? (String)call_args[1] : " ";
                 if (source.get_type() == Variant::ARRAY) {
                     Array arr = source;
                     String res = "";
                     for(int i=0; i<arr.size(); i++) {
                         if(i>0) res += delim;
                         res += String(arr[i]);
                     }
                     return res;
                 }
                 else if (source.get_type() == Variant::PACKED_STRING_ARRAY) {
                     PackedStringArray psa = source;
                     String res = "";
                     for(int i=0; i<psa.size(); i++) {
                         if(i>0) res += delim;
                         res += psa[i];
                     }
                     return res;
                 }
                 return "";
             }
             if (func_name == "Asc" && call_args.size() == 1) {
                 String s = call_args[0];
                 if (s.length() > 0) return (int)s.unicode_at(0);
                 return 0;
             }
             if (func_name == "Chr" && call_args.size() == 1) {
                 return String::chr((int)call_args[0]);
             }
             if (func_name == "Space" && call_args.size() == 1) {
                 int count = (int)call_args[0];
                 String s = "";
                 for(int i=0; i<count; i++) s += " ";
                 return s;
             }
             
             if (func_name == "WeakRef" && call_args.size() == 1) {
                 return UtilityFunctions::weakref(call_args[0]);
             }
             
             // Array Helpers
             if (func_name == "UBound" && call_args.size() >= 1) {
                 Variant v = call_args[0];
                 if (v.get_type() == Variant::ARRAY) return ((Array)v).size() - 1;
                 if (v.get_type() == Variant::PACKED_STRING_ARRAY) return ((PackedStringArray)v).size() - 1;
                 return -1; 
             }
             if (func_name == "LBound" && call_args.size() >= 1) {
                 return 0; // Always 0 base
             }

             // Math Helpers
             if (func_name == "Int" && call_args.size() == 1) return floor((double)call_args[0]);
             if (func_name == "Abs" && call_args.size() == 1) return abs((double)call_args[0]);
             if (func_name == "Rnd" && (call_args.size() == 0 || call_args.size() == 1)) return UtilityFunctions::randf();
             if (func_name.nocasecmp_to("Min") == 0 && call_args.size() == 2) { double a = (double)call_args[0]; double b = (double)call_args[1]; return a < b ? a : b; }
             if (func_name.nocasecmp_to("Max") == 0 && call_args.size() == 2) { double a = (double)call_args[0]; double b = (double)call_args[1]; return a > b ? a : b; }
             
             // Formatting
             if (func_name == "Format" && call_args.size() == 2) {
                 Variant val = call_args[0];
                 String fmt = call_args[1];
                 // Simple mapping: if fmt contains %, assume sprintf style.
                 if (fmt.contains("%")) {
                     Array a; a.push_back(val);
                     return fmt % a;
                 } 
                 // Else if "General Number" or standard VB formats, we simplify to String(val) for now or basic rounding
                 if (fmt == "Percent") return String::num(val, 2) + "%";
                 if (fmt == "Currency") return "$" + String::num(val, 2);
                 return String(val); // Fallback
             }

             // Dynamic Control Access
             if (func_name == "GetControl" && call_args.size() == 1) {
                 String name = call_args[0];
                 if (owner) {
                     Node *n = Object::cast_to<Node>(owner);
                     if (n) {
                         Node *found = n->find_child(name, true, false);
                         if (!found && n->get_parent()) {
                             found = n->get_parent()->find_child(name, true, false);
                         }
                         if (found) return found;
                     }
                 }
                 return Variant();
             }

             // Multimedia
             if (func_name == "LoadPicture" && call_args.size() == 1) {
                 String path = call_args[0];
                 if (!path.begins_with("res://") && !path.begins_with("user://")) path = "res://" + path;
                 return ResourceLoader::get_singleton()->load(path);
             }
             
             // Persistence Functions
             if (func_name == "GetSetting" && call_args.size() >= 3) {
                 String app = call_args[0];
                 String section = call_args[1];
                 String key = call_args[2];
                 Variant def_val = (call_args.size() >= 4) ? call_args[3] : Variant();
                 
                 Ref<ConfigFile> cfg;
                 cfg.instantiate();
                 String path = "user://vb_settings.cfg";
                 if (cfg->load(path) == OK) {
                     String real_section = app + "/" + section;
                     return cfg->get_value(real_section, key, def_val);
                 }
                 return def_val;
             }
             
             // Database Functions
             if (func_name == "OpenDatabase" && call_args.size() == 1) {
                 String path = call_args[0];
                 if (!path.begins_with("res://") && !path.begins_with("user://")) path = "user://" + path;
                 
                 Ref<FileAccess> f = FileAccess::open(path, FileAccess::READ);
                 if (f.is_valid()) {
                     Ref<JSON> json;
                     json.instantiate();
                     if (json->parse(f->get_as_text()) == OK) return json->get_data();
                     else raise_error("JSON Parse Error in database: " + path);
                 } else {
                     raise_error("Database file not found: " + path);
                 }
                 return Dictionary(); 
             }
             
             // InputBox — uses native OS dialog (zenity/kdialog)
             if (func_name == "InputBox") {
                 String prompt = (call_args.size() > 0) ? String(call_args[0]) : String("");
                 String title  = (call_args.size() > 1) ? String(call_args[1]) : String("VisualGasic");
                 String def    = (call_args.size() > 2) ? String(call_args[2]) : String("");
                 return VisualGasicBuiltins::native_input_box(prompt, title, def);
             }
         }
         return Variant();
    }

    // Lambda expression: return a callable Dictionary wrapping the AST node
    if (expr->type == ExpressionNode::LAMBDA) {
        LambdaNode* lam = (LambdaNode*)expr;
        Dictionary lambda_obj;
        lambda_obj["__vg_lambda"] = true;
        lambda_obj["__vg_is_arrow"] = lam->is_arrow;
        Array param_names;
        for (int i = 0; i < lam->parameters.size(); i++) {
            param_names.push_back(lam->parameters[i].name);
        }
        lambda_obj["__vg_params"] = param_names;
        lambda_obj["__vg_ast_ptr"] = (uint64_t)lam;
        return lambda_obj;
    }

    // Optional chaining ?. — returns Nil if base is null
    if (expr->type == ExpressionNode::OPTIONAL_ACCESS) {
        OptionalAccessExpression* oa = (OptionalAccessExpression*)expr;
        Variant base = evaluate_expression(oa->object_expression);
        if (base.get_type() == Variant::NIL) return Variant();
        // Behave like normal member access
        if (base.get_type() == Variant::DICTIONARY) {
            Dictionary d = base;
            if (d.has(oa->member_name)) return d[oa->member_name];
            return Variant();
        }
        bool valid = false;
        Variant ret = base.get_named(oa->member_name, valid);
        if (valid) return ret;
        ret = base.get_named(oa->member_name.to_lower(), valid);
        if (valid) return ret;
        if (base.get_type() == Variant::OBJECT) {
            Object* obj = base;
            if (obj) {
                Variant val = obj->get(oa->member_name);
                if (val.get_type() != Variant::NIL) return val;
                val = obj->get(oa->member_name.to_snake_case());
                if (val.get_type() != Variant::NIL) return val;
            }
        }
        return Variant();
    }

    if (expr->type == ExpressionNode::EXPRESSION_CALL) {
        CallExpression* call = (CallExpression*)expr;
        
        // Delegate to centralized expression-level builtins first (they may evaluate arguments themselves)
        {
            bool _bg_handled = false;
            Variant _bg_res = VisualGasicBuiltins::call_builtin_expr(this, call, _bg_handled);
            if (_bg_handled) {
                return _bg_res;
            }
        }

        Array call_args;
        for(int i=0; i<call->arguments.size(); i++) {
            // Check for null argument from parser errors
            if (!call->arguments[i]) {
                raise_error("Incomplete function call: missing argument");
                return Variant();
            }
            call_args.push_back(evaluate_expression(call->arguments[i]));
        }

        // Dispatch to expression-level builtins with evaluated arguments
        // (Map, Filter, Reduce, Any, All, Find, string helpers, etc.)
        {
            bool _ev_handled = false;
            Variant _ev_res = VisualGasicBuiltins::call_builtin_expr_evaluated(this, call->method_name, call_args, _ev_handled);
            if (_ev_handled) return _ev_res;
        }

        if (call->method_name.nocasecmp_to("CreateNode") == 0) {
             // Debug 
             // UtilityFunctions::print("DEBUG: Handling Call: ", call->method_name);
        }
        
        // GetNode("path") - Godot node path lookup
        if (call->method_name.nocasecmp_to("GetNode") == 0 && call_args.size() == 1) {
            String path = call_args[0];
            // When called with a base object (e.g. child.GetNode("Camera")),
            // resolve relative to the base object, not the owner
            Node *resolve_from = nullptr;
            if (call->base_object) {
                Variant base = evaluate_expression(call->base_object);
                if (base.get_type() == Variant::OBJECT) {
                    resolve_from = Object::cast_to<Node>(base);
                }
            }
            if (!resolve_from && owner) {
                resolve_from = Object::cast_to<Node>(owner);
            }
            if (resolve_from && resolve_from->is_inside_tree()) {
                return resolve_from->get_node_or_null(NodePath(path));
            }
            return Variant();
        }

        if (call->method_name.nocasecmp_to("Vector2") == 0 && call_args.size() == 2) {
             return Vector2(call_args[0], call_args[1]);
        }
        if (call->method_name.nocasecmp_to("TweenProperty") == 0 && call_args.size() == 4) {
             Object *obj = call_args[0];
             String prop = call_args[1];
             Variant final_val = call_args[2];
             double duration = call_args[3];
             if (obj && owner) {
                  Node *n = Object::cast_to<Node>(owner);
                  if (n) {
                       Ref<Tween> t = n->create_tween();
                       t->tween_property(obj, NodePath(prop), final_val, duration);
                       return t;
                  }
             }
             return Variant();
        }

        if (call->base_object) {
            // If base is a simple variable (eg. Clipboard) let builtins handle it first
            if (call->base_object->type == ExpressionNode::VARIABLE) {
                String var_name = ((VariableNode*)call->base_object)->name;
                Variant br;
                if (VisualGasicBuiltins::call_builtin_for_base_variable(this, var_name, call->method_name, call_args, br)) {
                    return br;
                }
                // ClassName.new() — GDScript-style static constructor
                // e.g. Label.new(), MeshInstance3D.new(), StandardMaterial3D.new()
                if (call->method_name.nocasecmp_to("new") == 0 && ClassDB::class_exists(var_name)) {
                    if (ClassDB::can_instantiate(var_name)) {
                        Variant inst = ClassDB::instantiate(var_name);
                        if (inst.get_type() == Variant::OBJECT) {
                            return inst;
                        }
                    }
                    return Variant();
                }
                // ── Enum.Parse / Enum.Values / Enum.ToString / Enum.HasFlag ──
                {
                    ModuleNode* root = cached_ast_root;
                    if (!root && script.is_valid() && script->ast_root) {
                        root = script->ast_root;
                    }
                    if (root) {
                    for (int ei = 0; ei < root->enums.size(); ei++) {
                        EnumDefinition* ed = root->enums[ei];
                        if (ed->name.nocasecmp_to(var_name) == 0) {
                            if (call->method_name.nocasecmp_to("Parse") == 0 && call_args.size() >= 1) {
                                // Enum.Parse("MemberName") -> int value
                                String mname = String(call_args[0]);
                                for (int vi = 0; vi < ed->values.size(); vi++) {
                                    if (ed->values[vi].name.nocasecmp_to(mname) == 0) {
                                        return ed->values[vi].value;
                                    }
                                }
                                raise_error("Enum '" + ed->name + "' has no member '" + mname + "'");
                                return Variant();
                            }
                            if (call->method_name.nocasecmp_to("Values") == 0) {
                                // Enum.Values() -> Array of [name, value] pairs
                                Array result;
                                for (int vi = 0; vi < ed->values.size(); vi++) {
                                    Dictionary entry;
                                    entry["Name"] = ed->values[vi].name;
                                    entry["Value"] = ed->values[vi].value;
                                    result.push_back(entry);
                                }
                                return result;
                            }
                            if (call->method_name.nocasecmp_to("ToString") == 0 && call_args.size() >= 1) {
                                // Enum.ToString(intValue) -> name string
                                int val = (int)call_args[0];
                                // Exact match first
                                for (int vi = 0; vi < ed->values.size(); vi++) {
                                    if (ed->values[vi].value == val) {
                                        return ed->values[vi].name;
                                    }
                                }
                                // Flags decomposition for [Flags] enums
                                if (ed->is_flags && val != 0) {
                                    String result;
                                    int remaining = val;
                                    // Walk values largest-first to greedily decompose
                                    for (int vi = ed->values.size() - 1; vi >= 0; vi--) {
                                        int fv = ed->values[vi].value;
                                        if (fv != 0 && (remaining & fv) == fv) {
                                            if (!result.is_empty()) result = ed->values[vi].name + String(", ") + result;
                                            else result = ed->values[vi].name;
                                            remaining &= ~fv;
                                        }
                                    }
                                    if (remaining == 0 && !result.is_empty()) return result;
                                }
                                return String::num_int64(val); // Unknown value
                            }
                            if (call->method_name.nocasecmp_to("HasFlag") == 0 && call_args.size() >= 2) {
                                // Enum.HasFlag(value, flag) -> Boolean
                                int val = (int)call_args[0];
                                int flag = (int)call_args[1];
                                return (val & flag) == flag;
                            }
                        }
                    }
                    }
                }
            }

            Variant base = evaluate_expression(call->base_object);

            Variant br;
            if (VisualGasicBuiltins::call_builtin_for_base_variant(this, base, call->method_name, call_args, br)) {
                return br;
            }

            // VG class instance method call (object ID is an integer)
            if (base.get_type() == Variant::INT) {
                int obj_id = (int)base;
                if (object_instances.has(obj_id)) {
                    return call_object_method(obj_id, call->method_name, call_args);
                }
            }

            // Fallback: object method call (try direct, snake_case, or callp fallback)
            if (base.get_type() == Variant::OBJECT) {
                Object* obj = base;
                if (obj) {
                    if (obj->has_method(call->method_name)) {
                        return obj->callv(call->method_name, call_args);
                    }
                    String snake = call->method_name.to_snake_case();
                    if (obj->has_method(snake)) {
                        return obj->callv(snake, call_args);
                    }
                }
            }

             // Fallback for Variant types (Structs like Rect2, Vector2, etc.)
             if (base.get_type() != Variant::OBJECT && base.get_type() != Variant::NIL) {
                 String method_to_call = "";
                 if (base.has_method(call->method_name)) {
                     method_to_call = call->method_name;
                 } else {
                     String snake = call->method_name.to_snake_case();
                     if (base.has_method(snake)) {
                         method_to_call = snake;
                     }
                 }
                 
                 if (!method_to_call.is_empty()) {
                     GDExtensionCallError err;
                     Variant res;
                     
                     // Helper to manage arguments pointers
                     // We need to copy arguments to a stable container to take their addresses
                     Vector<Variant> args_store;
                     args_store.resize(call_args.size());
                     Variant *args_w = args_store.ptrw();

                     Vector<const Variant*> arg_ptrs;
                     arg_ptrs.resize(call_args.size());
                     const Variant **ptrs_w = arg_ptrs.ptrw();
                     
                     for(int i=0; i<call_args.size(); i++) {
                         args_w[i] = call_args[i];
                         ptrs_w[i] = &args_w[i];
                     }
                     
                     base.callp(method_to_call, ptrs_w, call_args.size(), res, err);
                     return res;
                 }
             }

            // If we got here, the base_object was evaluated but the method
            // could not be dispatched — either base was Nil (null object
            // reference) or the object didn't have the requested method.
            if (base.get_type() == Variant::NIL) {
                String base_name = (call->base_object->type == ExpressionNode::VARIABLE)
                    ? ((VariableNode*)call->base_object)->name : String("<expression>");
                raise_error("Object variable '" + base_name + "' is Nothing (null) — cannot call ." + call->method_name);
            } else {
                raise_error("Object does not support method '" + call->method_name + "'");
            }
            return Variant();
        }

        // Check if it is an array access
        // Case-insensitive lookup: VB identifiers are case-insensitive
        Variant _expr_var;
        bool _expr_has_var = false;
        if (variables.has(call->method_name)) {
            _expr_var = variables[call->method_name];
            _expr_has_var = true;
        }
        if (!_expr_has_var) {
            Array _ek = variables.keys();
            for (int _ei = 0; _ei < _ek.size(); _ei++) {
                String _ekn = _ek[_ei];
                if (_ekn.nocasecmp_to(call->method_name) == 0) {
                    _expr_var = variables[_ekn];
                    _expr_has_var = true;
                    break;
                }
            }
        }
        if (_expr_has_var) {
            Variant v = _expr_var;
            bool is_array = (v.get_type() == Variant::ARRAY);
            bool is_packed = (v.get_type() >= Variant::PACKED_BYTE_ARRAY && v.get_type() <= Variant::PACKED_COLOR_ARRAY); // Range check for packed arrays?
            
            if (is_array) {
                // Multidimensional Read (Recursive for generic Array)
                Variant current = v;
                bool fail = false;
                for(int i=0; i<call_args.size(); i++) {
                    if (current.get_type() != Variant::ARRAY) {
                         fail = true; break;
                    }
                    Array arr = current;
                    int idx = call_args[i];
                    if (idx >= 0 && idx < arr.size()) {
                        current = arr[idx];
                    } else {
                        raise_error("Array subscript out of range", 9);
                        return Variant();
                    }
                }
                if (!fail) {
                    return current;
                }
            } else if (is_packed) {
                 // Single dimension access for Packed Arrays usually
                 if (call_args.size() == 1) {
                      int idx = call_args[0];
                      // Use Variant indexing
                      bool valid = false;
                      bool oob = false;
                      Variant res = v.get_indexed(idx, valid, oob);
                      if (oob) {
                          raise_error("Array subscript out of range", 9);
                          return Variant();
                      }
                      if (valid) return res;
                 }
            } else if (v.get_type() == Variant::DICTIONARY) {
                Dictionary d = v;
                // Lambda invocation: myLambda(args...)
                if (d.has("__vg_lambda") && (bool)d["__vg_lambda"]) {
                    return invoke_lambda(d, call_args);
                }
                if (call_args.size() == 1) {
                    Variant key = call_args[0];
                    if (d.has(key)) return d[key];
                    return Variant();
                }
            }
        }

        // Built-in Connect function
        if (call->method_name == "Connect") {
             if (owner) {
                 if (call_args.size() == 2) {
                     String signal = call_args[0];
                     String method = call_args[1];
                     Callable callable = Callable(owner, method);
                     Error err = owner->connect(signal, callable);
                     return (int)err;
                 } else if (call_args.size() == 3) {
                     Object *source = call_args[0];
                     String signal = call_args[1];
                     String method = call_args[2];
                     if (source) {
                         Callable callable = Callable(owner, method);
                         Error err = source->connect(signal, callable);
                         return (int)err;
                     }
                 }
             }
        }
        
        // Expression-level builtins (strings, array helpers, file/dir, math, etc.)
        // are delegated to VisualGasicBuiltins::call_builtin_expr /
        // call_builtin_expr_evaluated earlier. This avoids duplicate
        // implementations here and keeps logic centralized.
        if (call->method_name.nocasecmp_to("Shell") == 0 && call_args.size() >= 1) {
             String cmd_line = call_args[0];
             // Parse command line (EXE + Args) VB6 Style
             String exe = "";
             Array args;
             
             int i = 0;
             while(i < cmd_line.length() && cmd_line[i] == ' ') i++;
             
             // Extract Exe
             if (i < cmd_line.length()) {
                 if (cmd_line[i] == '"') {
                     i++; // skip quote
                     while(i < cmd_line.length() && cmd_line[i] != '"') {
                         exe += cmd_line[i]; i++;
                     }
                     i++; // skip closing quote
                 } else {
                     while(i < cmd_line.length() && cmd_line[i] != ' ') {
                         exe += cmd_line[i]; i++;
                     }
                 }
             }
             
             // Extract Args
             while(i < cmd_line.length()) {
                  while(i < cmd_line.length() && cmd_line[i] == ' ') i++; 
                  if (i >= cmd_line.length()) break;
                  
                  String arg = "";
                  if (cmd_line[i] == '"') {
                       i++;
                       while(i < cmd_line.length() && cmd_line[i] != '"') {
                            arg += cmd_line[i]; i++;
                       }
                       i++;
                  } else {
                       while(i < cmd_line.length() && cmd_line[i] != ' ') {
                            arg += cmd_line[i]; i++;
                       }
                  }
                  args.push_back(arg);
             }
             
             return OS::get_singleton()->execute(exe, args);
        }

        // --- New Helpers ---
        if (call->method_name.nocasecmp_to("Sleep") == 0 && call_args.size() == 1) {
             int ms = (int)call_args[0];
             OS::get_singleton()->delay_msec(ms);
             return Variant();
        }
        if (call->method_name.nocasecmp_to("TypeName") == 0 && call_args.size() == 1) {
             Variant v = call_args[0];
             switch(v.get_type()) {
                 case Variant::NIL: return "Nothing";
                 case Variant::BOOL: return "Boolean";
                 case Variant::INT: return "Integer";
                 case Variant::FLOAT: return "Double";
                 case Variant::STRING: return "String";
                 case Variant::VECTOR2: return "Vector2";
                 case Variant::VECTOR3: return "Vector3";
                 case Variant::COLOR: return "Color";
                 case Variant::OBJECT: {
                     Object *obj = v;
                     if (obj) return obj->get_class();
                     return "Nothing";
                 } 
                 case Variant::DICTIONARY: return "Dictionary";
                 case Variant::ARRAY: return "Array";
                 default: return "Object"; // Simplified
             }
        }
        if (call->method_name.nocasecmp_to("IsNumeric") == 0 && call_args.size() == 1) {
             Variant v = call_args[0];
             if (v.get_type() == Variant::INT || v.get_type() == Variant::FLOAT) return true;
             if (v.get_type() == Variant::STRING) return String(v).is_valid_float();
             return false;
        }
        if (call->method_name.nocasecmp_to("IsObject") == 0 && call_args.size() == 1) {
             return call_args[0].get_type() == Variant::OBJECT || call_args[0].get_type() == Variant::NIL; 
        }
        if (call->method_name.nocasecmp_to("IsArray") == 0 && call_args.size() == 1) {
             Variant::Type t = call_args[0].get_type();
             return t == Variant::ARRAY || (t >= Variant::PACKED_BYTE_ARRAY && t <= Variant::PACKED_COLOR_ARRAY);
        }
        if (call->method_name.nocasecmp_to("Round") == 0 && call_args.size() >= 1) {
             double val = (double)call_args[0];
             if (call_args.size() > 1) {
                 int digits = (int)call_args[1];
                 double step = pow(10.0, -digits);
                 return Math::snapped(val, step);
             }
             return round(val);
        }
        if (call->method_name.nocasecmp_to("RandRange") == 0 && call_args.size() == 2) {
             float min = (float)call_args[0];
             float max = (float)call_args[1];
             return min + UtilityFunctions::randf() * (max - min);
        }
        if (call->method_name.nocasecmp_to("CInt") == 0 && call_args.size() == 1) return (int)round((double)call_args[0]);
        if (call->method_name.nocasecmp_to("CDbl") == 0 && call_args.size() == 1) return (double)call_args[0];
        if (call->method_name.nocasecmp_to("CBool") == 0 && call_args.size() == 1) return (bool)call_args[0];

        // --- GAP FILLERS ---
        if (call->method_name.nocasecmp_to("Lerp") == 0 && call_args.size() == 3) {
             double a = call_args[0];
             double b = call_args[1];
             double t = call_args[2];
             return Math::lerp(a, b, t);
        }
        if (call->method_name.nocasecmp_to("Clamp") == 0 && call_args.size() == 3) {
             double val = call_args[0];
             double min = call_args[1];
             double max = call_args[2];
             return Math::clamp(val, min, max);
        }
        if (call->method_name.nocasecmp_to("FileLen") == 0 && call_args.size() == 1) {
             String path = call_args[0];
             Ref<FileAccess> fa = FileAccess::open(path, FileAccess::READ);
             if (fa.is_valid()) return fa->get_length();
             return 0;
        }
        if (call->method_name.nocasecmp_to("Dir") == 0) {
             if (call_args.size() >= 1) {
                  // Dir(path, [attr]) - Start Iteration
                  String path = call_args[0];
                  
                  String folder = path.get_base_dir();
                  // If path is just "*.txt", base_dir might be empty, defaulting to valid res:// or user:// root? 
                  // In Godot, empty base dir of relative path depends on context. 
                  // Let's assume absolute paths or relative to res:// if not specified? 
                  // But standard DirAccess::open works with "res://".
                  if (folder.is_empty()) folder = "res://";
                  
                  dir_pattern = path.get_file();
                  if (dir_pattern.is_empty()) dir_pattern = "*"; // Default to all if folder only?
                  
                  current_dir = DirAccess::open(folder);
                  if (current_dir.is_valid()) {
                       current_dir->list_dir_begin(); 
                       String f = current_dir->get_next();
                       while (!f.is_empty()) {
                            if (f != "." && f != ".." && f.matchn(dir_pattern)) {
                                 return f;
                            }
                            f = current_dir->get_next();
                       }
                  }
                  return "";
             } else {
                  // Dir() - Next
                  if (current_dir.is_valid()) {
                       String f = current_dir->get_next();
                       while (!f.is_empty()) {
                            if (f != "." && f != ".." && f.matchn(dir_pattern)) {
                                 return f;
                            }
                            f = current_dir->get_next();
                       }
                  }
                  return "";
             }
        }
        if (call->method_name.nocasecmp_to("MsgBox") == 0 && call_args.size() >= 1) {
             String msg = call_args[0];
             int buttons = 0;
             if (call_args.size() >= 2) buttons = (int)call_args[1];
             String title = "VisualGasic";
             if (call_args.size() >= 3) title = call_args[2];

             // Use native OS dialog — always works, doesn't hang the Godot loop
             int btn_type = buttons & 0x0F;
             return VisualGasicBuiltins::native_msgbox(msg, title, btn_type);
        }

        // Godot Types
        if (call->method_name == "Vector2" && call_args.size() == 2) {
            return Vector2(call_args[0], call_args[1]);
        }
        if (call->method_name == "Vector3" && call_args.size() == 3) {
            return Vector3(call_args[0], call_args[1], call_args[2]);
        }
        if (call->method_name == "Rect2" && call_args.size() == 4) {
            return Rect2(call_args[0], call_args[1], call_args[2], call_args[3]);
        }
        if (call->method_name == "Color") {
            if (call_args.size() == 1 && call_args[0].get_type() == Variant::STRING) {
                String s = call_args[0];
                if (s.begins_with("#")) return Color::html(s);
                return Color::named(s);
            }
            if (call_args.size() >= 3) {
                float r = call_args[0];
                float g = call_args[1];
                float b = call_args[2];
                float a = call_args.size() > 3 ? (float)call_args[3] : 1.0f;
                return Color(r, g, b, a);
            }
            return Color();
        }

        // Math Library
        if (call->method_name == "Sin" && call_args.size() == 1) return UtilityFunctions::sin(call_args[0]);
        if (call->method_name == "Cos" && call_args.size() == 1) return UtilityFunctions::cos(call_args[0]);
        if (call->method_name == "Tan" && call_args.size() == 1) return UtilityFunctions::tan(call_args[0]);
        if (call->method_name == "Log" && call_args.size() == 1) return UtilityFunctions::log(call_args[0]);
        if (call->method_name == "Exp" && call_args.size() == 1) return UtilityFunctions::exp(call_args[0]);
        if (call->method_name == "Atn" && call_args.size() == 1) return UtilityFunctions::atan(call_args[0]); // Atn is ArcTan
        if (call->method_name == "Sqr" && call_args.size() == 1) return UtilityFunctions::sqrt(call_args[0]);
        if (call->method_name == "Abs" && call_args.size() == 1) return UtilityFunctions::abs(call_args[0]);
        if (call->method_name == "Sgn" && call_args.size() == 1) {
             double d = (double)call_args[0];
             if (d > 0) return 1;
             if (d < 0) return -1;
             return 0;
        }
        if (call->method_name == "Int" && call_args.size() == 1) return UtilityFunctions::floor(call_args[0]); // Int usually floors
        if (call->method_name == "Rnd") return UtilityFunctions::randf(); // 0..1
        if (call->method_name.nocasecmp_to("Min") == 0 && call_args.size() == 2) { double a = (double)call_args[0]; double b = (double)call_args[1]; return a < b ? a : b; }
        if (call->method_name.nocasecmp_to("Max") == 0 && call_args.size() == 2) { double a = (double)call_args[0]; double b = (double)call_args[1]; return a > b ? a : b; }
        
        if (call->method_name.nocasecmp_to("EOF") == 0 && call_args.size() == 1) {
            int file_num = (int)call_args[0];
            if (open_files.has(file_num)) {
                 Ref<FileAccess> fa = open_files[file_num];
                 return fa->get_position() >= fa->get_length();
            }
            return true; 
        }

        if (call->method_name.nocasecmp_to("FreeFile") == 0) {
             int start = 1;
             if (call_args.size() > 0) {
                 int range = (int)call_args[0];
                 if (range == 1) start = 256;
             }
             for(int i=start; i < start + 255; i++) {
                 if (!open_files.has(i)) return i;
             }
             raise_error("Too many files open");
             return 0;
        }
        if (call->method_name == "Randomize") {
            UtilityFunctions::randomize();
            return Variant();
        }

        // Date and Time Library
        if (call->method_name == "Now") {
             return Time::get_singleton()->get_datetime_dict_from_system();
        }
        if (call->method_name == "Date") {
             return Time::get_singleton()->get_date_dict_from_system();
        }
        if (call->method_name == "Time") {
             return Time::get_singleton()->get_time_dict_from_system();
        }
        if (call->method_name == "Timer") {
             return VGTimer::timer_function();
        }
        if (call->method_name == "Year" && call_args.size() == 1) {
             Dictionary d = call_args[0];
             if (d.has("year")) return d["year"];
             return 0;
        }
        if (call->method_name == "Month" && call_args.size() == 1) {
             Dictionary d = call_args[0];
             if (d.has("month")) return d["month"];
             return 0;
        }
        if (call->method_name == "Day" && call_args.size() == 1) {
             Dictionary d = call_args[0];
             if (d.has("day")) return d["day"];
             return 0;
        }
        if (call->method_name == "Hour" && call_args.size() == 1) {
             Dictionary d = call_args[0];
             if (d.has("hour")) return d["hour"];
             return 0;
        }
        if (call->method_name == "Minute" && call_args.size() == 1) {
             Dictionary d = call_args[0];
             if (d.has("minute")) return d["minute"];
             return 0;
        }
        if (call->method_name == "Second" && call_args.size() == 1) {
             Dictionary d = call_args[0];
             if (d.has("second")) return d["second"];
             return 0;
        }

        // Godot Integration
        if (call->method_name == "Load" && call_args.size() == 1) {
             return ResourceLoader::get_singleton()->load(call_args[0]);
        }
        if (call->method_name == "LoadTexture" && call_args.size() == 1) {
             return ResourceLoader::get_singleton()->load(call_args[0]);
        }
        if (call->method_name == "LoadTexture3D" && call_args.size() == 1) {
             return ResourceLoader::get_singleton()->load(call_args[0]);
        }
        if (call->method_name == "LoadSprite" && call_args.size() == 1) {
             Ref<Texture2D> tex = ResourceLoader::get_singleton()->load(call_args[0]);
             if (tex.is_valid()) {
                  Sprite2D *s = memnew(Sprite2D);
                  s->set_texture(tex);
                  return s;
             }
             return Variant(); 
        }

        if (call->method_name == "CreateMSComm") {
             MSComm *comm = memnew(MSComm);
             // MSComm is now RefCounted, so we don't add to tree.
             // It is managed by the variable (Variant) holding the Ref.
             return Ref<MSComm>(comm);
        }

        if (call->method_name == "CreateSprite" && call_args.size() == 1) {
             Variant arg = call_args[0];
             Ref<Texture2D> tex = arg;
             Sprite2D *s = memnew(Sprite2D);
             if (tex.is_valid()) s->set_texture(tex);
             return s;
        }

        if (call->method_name == "CreateProgressBar") {
             ProgressBar *pb = memnew(ProgressBar);
             if (call_args.size() >= 1) pb->set_min(call_args[0]);
             if (call_args.size() >= 2) pb->set_max(call_args[1]);
             if (call_args.size() >= 3) pb->set_value(call_args[2]);
             
             // Optional Position
             if (call_args.size() >= 5) {
                 pb->set_position(Vector2(call_args[3], call_args[4]));
                 pb->set_size(Vector2(200, 20)); // Default size
             } else {
                 pb->set_size(Vector2(200, 20));
                 pb->set_position(Vector2(50, 50));
             }

             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                      n->add_child(pb);
                      dynamic_nodes.push_back(pb->get_instance_id());
                 }
             }
             return pb;
        }

        if (call->method_name == "CreateSlider") {
             HSlider *s = memnew(HSlider);
             if (call_args.size() >= 1) s->set_min(call_args[0]);
             if (call_args.size() >= 2) s->set_max(call_args[1]);
             if (call_args.size() >= 3) s->set_value(call_args[2]);
             
             if (call_args.size() >= 5) {
                 s->set_position(Vector2(call_args[3], call_args[4]));
                 s->set_size(Vector2(200, 20));
             } else {
                 s->set_size(Vector2(200, 20));
                 s->set_position(Vector2(50, 100));
             }

             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                      n->add_child(s);
                      dynamic_nodes.push_back(s->get_instance_id());
                 }
             }
             return s;
        }

        if (call->method_name == "CreateListView") {
             ItemList *il = memnew(ItemList);
             
             if (call_args.size() >= 2) {
                 il->set_position(Vector2(call_args[0], call_args[1]));
                 il->set_size(Vector2(200, 150));
             } else {
                 il->set_position(Vector2(50, 150));
                 il->set_size(Vector2(200, 150));
             }

             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                      n->add_child(il);
                      dynamic_nodes.push_back(il->get_instance_id());
                 }
             }
             return il;
        }

        if (call->method_name == "CreateFlexGrid") {
             int rows = 2;
             int cols = 2;
             if (call_args.size() >= 1) rows = call_args[0];
             if (call_args.size() >= 2) cols = call_args[1];
             
             Tree *t = memnew(Tree);
             t->set_columns(cols);
             t->set_column_titles_visible(true);
             t->set_select_mode(Tree::SELECT_SINGLE);
             
             // Create Root (Hidden usually in FlexGrid context, but Tree needs one)
             TreeItem *root = t->create_item();
             
             // Create Rows
             for(int i=0; i<rows; i++) {
                 TreeItem *it = t->create_item(root);
                 // Initialize text?
             }
             
             if (call_args.size() >= 4) {
                 t->set_position(Vector2(call_args[2], call_args[3]));
                 t->set_size(Vector2(300, 200));
             } else {
                 t->set_position(Vector2(50, 200));
                 t->set_size(Vector2(300, 200));
             }
             
             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                      n->add_child(t);
                      dynamic_nodes.push_back(t->get_instance_id());
                 }
             }
             return t;
        }



        if (call->method_name == "CreateText" && call_args.size() >= 1) {
             String text = call_args[0];
             Label *l = memnew(Label);
             l->set_text(text);
             if (call_args.size() >= 3) {
                 l->set_position(Vector2(call_args[1], call_args[2]));
             }
             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                      n->add_child(l);
                      dynamic_nodes.push_back(l->get_instance_id());
                 }
             }
             return l;
        }

        if (call->method_name.nocasecmp_to("GetAxis") == 0 && call_args.size() == 2) {
             String neg = call_args[0];
             String pos = call_args[1];
             return Input::get_singleton()->get_axis(neg, pos);
        }

        if (call->method_name.nocasecmp_to("GetJoyAxis") == 0 && call_args.size() == 2) {
             int device = call_args[0];
             int axis = call_args[1];
             return Input::get_singleton()->get_joy_axis(device, (JoyAxis)axis);
        }

        if (call->method_name == "CreateParticles2D" && call_args.size() >= 1) {
             Variant arg = call_args[0];
             Ref<Material> mat;
             if (arg.get_type() == Variant::STRING) {
                 mat = ResourceLoader::get_singleton()->load(arg);
             } else if (arg.get_type() == Variant::OBJECT) {
                 mat = arg;
             }

             GPUParticles2D *p = memnew(GPUParticles2D);
             if (mat.is_valid()) p->set_process_material(mat);
             p->set_emitting(true); // Auto start

             if (call_args.size() >= 3) {
                 p->set_position(Vector2(call_args[1], call_args[2]));
             }

             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                      n->add_child(p);
                      dynamic_nodes.push_back(p->get_instance_id());
                 }
             }
             return p;
        }

        if (call->method_name == "CreateParticles3D" && call_args.size() >= 1) {
             Variant arg = call_args[0];
             Ref<Material> mat;
             if (arg.get_type() == Variant::STRING) {
                 mat = ResourceLoader::get_singleton()->load(arg);
             } else if (arg.get_type() == Variant::OBJECT) {
                 mat = arg;
             }

             GPUParticles3D *p = memnew(GPUParticles3D);
             if (mat.is_valid()) p->set_process_material(mat);
             p->set_emitting(true); // Auto start

             if (call_args.size() >= 4) {
                 p->set_position(Vector3(call_args[1], call_args[2], call_args[3]));
             }

             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                      n->add_child(p);
                      dynamic_nodes.push_back(p->get_instance_id());
                 }
             }
             return p;
        }

        if (call->method_name == "CreateMultiMeshInstance3D" && call_args.size() >= 1) {
             Variant arg = call_args[0];
             Ref<MultiMesh> mesh;
             if (arg.get_type() == Variant::STRING) {
                 mesh = ResourceLoader::get_singleton()->load(arg);
             } else if (arg.get_type() == Variant::OBJECT) {
                 mesh = arg;
             }
             
             MultiMeshInstance3D *m = memnew(MultiMeshInstance3D);
             if (mesh.is_valid()) m->set_multimesh(mesh);
             
             if (call_args.size() >= 4) {
                 m->set_position(Vector3(call_args[1], call_args[2], call_args[3]));
             }

             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                      n->add_child(m);
                      dynamic_nodes.push_back(m->get_instance_id());
                 }
             }
             return m;
        }

        if (call->method_name == "CreateTextureRect" && call_args.size() >= 1) {
             Variant arg = call_args[0];
             Ref<Texture2D> tex;
             if (arg.get_type() == Variant::STRING) {
                 tex = ResourceLoader::get_singleton()->load(arg);
             } else if (arg.get_type() == Variant::OBJECT) {
                 tex = arg;
             }
             
             TextureRect *tr = memnew(TextureRect);
             if (tex.is_valid()) tr->set_texture(tex);
             
             if (call_args.size() >= 3) {
                 tr->set_position(Vector2(call_args[1], call_args[2]));
             }

             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                      n->add_child(tr);
                      dynamic_nodes.push_back(tr->get_instance_id());
                 }
             }
             return tr;
        }

        if (call->method_name == "CreateSprite3D" && call_args.size() >= 1) {
             Variant arg = call_args[0];
             Ref<Texture2D> tex;
             if (arg.get_type() == Variant::STRING) {
                 tex = ResourceLoader::get_singleton()->load(arg);
             } else if (arg.get_type() == Variant::OBJECT) {
                 tex = arg;
             }
             
             Sprite3D *s = memnew(Sprite3D);
             if (tex.is_valid()) s->set_texture(tex);
             
             if (call_args.size() >= 4) {
                 s->set_position(Vector3(call_args[1], call_args[2], call_args[3]));
             }

             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                      n->add_child(s);
                      dynamic_nodes.push_back(s->get_instance_id());
                 }
             }
             return s;
        }

        if (call->method_name == "CreateNode" && call_args.size() == 1) {
             String type = call_args[0];
             if (ClassDB::class_exists(type) && ClassDB::can_instantiate(type)) {
                  Variant res = ClassDB::instantiate(type);
                  return res;
             }
             return Variant();
        }
        if (call->method_name == "AddChild" && call_args.size() == 1) {
             Object *obj = call_args[0];
             Node *child = Object::cast_to<Node>(obj);
             if (child && owner) {
                  Node *parent = Object::cast_to<Node>(owner);
                  if (parent) {
                       parent->add_child(child);
                  }
             }
             return Variant();
        }

        if (call->method_name == "Instantiate" && call_args.size() == 1) {
             // Supports path or PackedScene
             Variant arg = call_args[0];
             Ref<PackedScene> scene;
             if (arg.get_type() == Variant::STRING) {
                  scene = ResourceLoader::get_singleton()->load(arg);
             } else if (arg.get_type() == Variant::OBJECT) {
                  scene = arg;
             }
             
             if (scene.is_valid()) {
                  return scene->instantiate();
             }
             return Variant(); 
        }

        if (call->method_name == "LoadShader" && call_args.size() == 1) {
             return ResourceLoader::get_singleton()->load(call_args[0]);
        }
        
        if (call->method_name == "CompileShader" && call_args.size() == 1) {
             String code = call_args[0];
             Ref<Shader> shader;
             shader.instantiate();
             shader->set_code(code);
             return shader;
        }
        
        if (call->method_name == "GetDelta" && call_args.size() == 0) {
             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) return n->get_process_delta_time();
             }
             return 0.0;
        }

        // Input Handling
        if (call->method_name == "IsActionPressed" && call_args.size() == 1) {
            String action = call_args[0];
            return Input::get_singleton()->is_action_pressed(action);
        }
        if (call->method_name == "IsActionJustPressed" && call_args.size() == 1) {
            String action = call_args[0];
            return Input::get_singleton()->is_action_just_pressed(action);
        }
        if (call->method_name == "IsActionJustReleased" && call_args.size() == 1) {
            String action = call_args[0];
            return Input::get_singleton()->is_action_just_released(action);
        }
        if (call->method_name == "IsKeyPressed" && call_args.size() == 1) {
            int key = call_args[0];
            return Input::get_singleton()->is_key_pressed((Key)key);
        }
        if (call->method_name == "IsMouseButtonPressed" && call_args.size() == 1) {
            int btn = call_args[0];
            return Input::get_singleton()->is_mouse_button_pressed((MouseButton)btn);
        }
        if (call->method_name == "GetMousePosition" && call_args.size() == 0) {
             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                      Viewport *vp = n->get_viewport();
                      if (vp) return vp->get_mouse_position();
                 }
             }
             return DisplayServer::get_singleton()->mouse_get_position();
        }
        
        // Factory for Vector2
        if (call->method_name.nocasecmp_to("Vector2") == 0 && call_args.size() == 2) {
             return Vector2(call_args[0], call_args[1]);
        }

        if (call->method_name.nocasecmp_to("TweenProperty") == 0 && call_args.size() == 4) {
             Object *obj = call_args[0];
             String prop = call_args[1];
             Variant final_val = call_args[2];
             double duration = call_args[3];
             
             if (obj && owner) {
                  Node *n = Object::cast_to<Node>(owner);
                  if (n) {
                       Ref<Tween> t = n->create_tween();
                       t->tween_property(obj, NodePath(prop), final_val, duration);
                       return t;
                  }
             }
             return Variant();
        }

        if (call->method_name == "CreateFileDialog" || call->method_name == "CreateCommonDialog") {
             FileDialog *fd = memnew(FileDialog);
             fd->set_access(FileDialog::ACCESS_FILESYSTEM); 
             fd->set_file_mode(FileDialog::FILE_MODE_OPEN_FILE);
             fd->set_size(Vector2(600, 400));
             fd->set_title("Open File");
             
             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                      n->add_child(fd);
                      dynamic_nodes.push_back(fd->get_instance_id());
                      fd->call_deferred("popup_centered");
                 }
             }
             return fd;
        }

        if (call->method_name == "HasCollided" && call_args.size() == 1) {
             Object *obj = call_args[0];
             CharacterBody2D *cb2d = Object::cast_to<CharacterBody2D>(obj);
             if (cb2d) {
                 return cb2d->get_slide_collision_count() > 0;
             }
             CharacterBody3D *cb3d = Object::cast_to<CharacterBody3D>(obj);
             if (cb3d) {
                 return cb3d->get_slide_collision_count() > 0;
             }
             return false;
        }

        if (call->method_name == "GetCollider" && call_args.size() == 1) {
             Object *obj = call_args[0];
             CharacterBody2D *cb2d = Object::cast_to<CharacterBody2D>(obj);
             if (cb2d && cb2d->get_slide_collision_count() > 0) {
                 Ref<KinematicCollision2D> col = cb2d->get_slide_collision(0);
                 if (col.is_valid()) return col->get_collider();
             }
             CharacterBody3D *cb3d = Object::cast_to<CharacterBody3D>(obj);
             if (cb3d && cb3d->get_slide_collision_count() > 0) {
                 Ref<KinematicCollision3D> col = cb3d->get_slide_collision(0);
                 if (col.is_valid()) return col->get_collider();
             }
             return Variant();
        }

        if (call->method_name == "CreateTrigger" && call_args.size() >= 4) {
             String name = call_args[0];
             double x = call_args[1];
             double y = call_args[2];
             double w = call_args[3];
             double h = (call_args.size() > 4) ? (double)call_args[4] : w;
             
             Area2D *area = memnew(Area2D);
             area->set_name(name);
             area->set_position(Vector2(x,y));
             
             CollisionShape2D *shape = memnew(CollisionShape2D);
             Ref<RectangleShape2D> rect;
             rect.instantiate();
             rect->set_size(Vector2(w, h));
             shape->set_shape(rect);
             area->add_child(shape);
             
             if (owner) {
                  Node *n = Object::cast_to<Node>(owner);
                  if (n) {
                      n->add_child(area);
                      dynamic_nodes.push_back(area->get_instance_id());
                      area->connect("body_entered", Callable(owner, "_OnSignal").bind(name, "Collision"));
                  }
             }
             return area;
        }

        if (call->method_name == "CreateTimer" && call_args.size() >= 1) {
             double interval = call_args[0]; // in seconds
             bool active = true;
             if (call_args.size() >= 2) active = call_args[1];
             
             Timer *t = memnew(Timer);
             t->set_wait_time(interval);
             t->set_autostart(active);
             t->set_one_shot(false);
             
             // Name? "Timer"+ID
             // We need a stable name/ID for the event binding if arguments don't provide it.
             // VB6 Timers were controls drawn on form with a name.
             // Here, CreateTimer needs to return the object so we can stop it.
             // But to hook up events.. "Sub MyTimer_Timer()"?
             // We need to know the variable name assigned to? We don't know that here.
             // User should probably Set Name property? 
             // Or allow CreateTimer("Name", Interval)
             
             String name = "TimerVal"; 
             if (call_args.size() == 3) name = call_args[3]; // Not ideal arg order
             
             // Better: Allow binding later via name set? 
             // Or assume user passes name as first arg: CreateTimer("MyTimer", 1000)
             
             if (call_args[0].get_type() == Variant::STRING) {
                  name = call_args[0];
                  interval = call_args[1];
                  if (call_args.size() >= 3) active = call_args[2];
                  t->set_wait_time(interval);
                  t->set_name(name);
             } else {
                  // Anonymous timer? Hard to bind events.
             }

             if (owner) {
                  Node *n = Object::cast_to<Node>(owner);
                  if (n) {
                      n->add_child(t);
                      dynamic_nodes.push_back(t->get_instance_id());
                      // Bind timeout
                      t->connect("timeout", Callable(owner, "_OnSignal").bind(name, "Timer"));
                      // Autostart handles it if in tree. If not, autostart=true will start it when it enters.
                      // No need to call start() manually.
                  }
             }
             return t;
        }
        
        if (call->method_name == "CreateMenu" && call_args.size() >= 1) {
             String title = call_args[0];
             String name = title; // Default name matches title
             if (call_args.size() >= 2) name = call_args[1];

             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 CanvasItem *ci = Object::cast_to<CanvasItem>(n);
                 if (ci) {
                     // Find or Create MenuBar container
                     Node *menu_bar = n->find_child("VisualGasicMenuBar", false, false);
                     HBoxContainer *hbox = nullptr;
                     
                     if (!menu_bar) {
                         hbox = memnew(HBoxContainer);
                         hbox->set_name("VisualGasicMenuBar");
                         hbox->set_position(Vector2(0,0));
                         hbox->set_size(Vector2(1024, 30)); // Stretch later?
                         // Ideally anchored top
                         hbox->set_anchors_and_offsets_preset(Control::PRESET_TOP_WIDE);
                         n->add_child(hbox);
                     } else {
                         hbox = Object::cast_to<HBoxContainer>(menu_bar);
                     }
                     
                     if (hbox) {
                         MenuButton *mb = memnew(MenuButton);
                         mb->set_text(title);
                         mb->set_name(name);
                         mb->set_switch_on_hover(true);
                         hbox->add_child(mb);
                         
                         dynamic_nodes.push_back(mb->get_instance_id());
                         
                         // Return the PopupMenu so we can add items
                         return mb->get_popup();
                     }
                 }
             }
             return Variant();
        }

        if (call->method_name == "CreateActor2D" && call_args.size() >= 3) {
             String img_path = call_args[0];
             double x = call_args[1];
             double y = call_args[2];
             
             CharacterBody2D *body = memnew(CharacterBody2D);
             body->set_position(Vector2(x, y));
             
             // Sprite
             Sprite2D *sprite = memnew(Sprite2D);
             Ref<Texture2D> tex = ResourceLoader::get_singleton()->load(img_path);
             if (tex.is_valid()) {
                 sprite->set_texture(tex);
                 // Collision Shape (Circle based on texture size approx)
                 CollisionShape2D *shape = memnew(CollisionShape2D);
                 Ref<CircleShape2D> circle;
                 circle.instantiate();
                 float radius = tex->get_width() / 2.0;
                 circle->set_radius(radius);
                 shape->set_shape(circle);
                 body->add_child(shape);
             } else {
                 // Fallback Shape
                 CollisionShape2D *shape = memnew(CollisionShape2D);
                 Ref<CircleShape2D> circle;
                 circle.instantiate();
                 circle->set_radius(20.0);
                 shape->set_shape(circle);
                 body->add_child(shape);
             }
             body->add_child(sprite);
             
             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                     n->add_child(body);
                     dynamic_nodes.push_back(body->get_instance_id());
                 }
             }
             return body;
        }
        
        if (call->method_name == "CreateText" && call_args.size() >= 1) {
             String text = call_args[0];
             Label *l = memnew(Label);
             l->set_text(text);
             if (call_args.size() >= 2) {
                  // Only if vector?
                  if (call_args.size() == 2 && call_args[1].get_type() == Variant::VECTOR2) {
                       l->set_position(call_args[1]);
                  } else if (call_args.size() >= 3) {
                       l->set_position(Vector2(call_args[1], call_args[2]));
                  }
             }
             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                     n->add_child(l);
                     dynamic_nodes.push_back(l->get_instance_id());
                 }
             }
             return l;
        }

        // --- NEW PRO FEATURES ---
        if (call->method_name.nocasecmp_to("CreateLabel") == 0 && call_args.size() >= 3) {
            String text = call_args[0];
            double x = call_args[1]; 
            double y = call_args[2];
            
            Label *l = memnew(Label);
            l->set_text(text);
            l->set_position(Vector2(x,y));
            
            if (owner) {
                Node *n = Object::cast_to<Node>(owner);
                if (n) {
                    n->add_child(l);
                    dynamic_nodes.push_back(l->get_instance_id());
                }
            }
            return l;
        }

        if (call->method_name.nocasecmp_to("CreateButton") == 0 && call_args.size() >= 3) {
             String text = call_args[0];
             double x = call_args[1];
             double y = call_args[2];
             
             Button *b = memnew(Button);
             b->set_text(text);
             b->set_position(Vector2(x, y));
             
             if (call_args.size() >= 4) {
                 // Callback Name
                 String callback = call_args[3];
                 // Bind "pressed" to _OnSignal (which calls BASIC sub)
                 b->connect("pressed", Callable(owner, "_OnSignal").bind(callback, ""));
             }

             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                     n->add_child(b);
                     dynamic_nodes.push_back(b->get_instance_id());
                 }
             }
             return b;
        }

        if (call->method_name.nocasecmp_to("CreateInput") == 0 && call_args.size() >= 3) {
             String text = call_args[0];
             double x = call_args[1];
             double y = call_args[2];
             
             LineEdit *le = memnew(LineEdit);
             le->set_text(text);
             le->set_position(Vector2(x,y));
             
             if (call_args.size() >= 4) {
                 double width = call_args[3];
                 le->set_size(Vector2(width, le->get_size().y));
             } else {
                 le->set_size(Vector2(100, le->get_size().y));
             }
             
             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                     n->add_child(le);
                     dynamic_nodes.push_back(le->get_instance_id());
                 }
             }
             return le;
        }

        if (call->method_name.nocasecmp_to("GetKey") == 0 && call_args.size() == 1) {
            Key key = Key::KEY_NONE;
            if (call_args[0].get_type() == Variant::INT || call_args[0].get_type() == Variant::FLOAT) {
                key = (Key)(int)call_args[0];
            } else {
                String k = call_args[0];
                key = (Key)OS::get_singleton()->find_keycode_from_string(k);
            }
            return Input::get_singleton()->is_key_pressed(key);
        }
        if (call->method_name.nocasecmp_to("IsKeyDown") == 0 && call_args.size() == 1) {
            Key key = Key::KEY_NONE;
            if (call_args[0].get_type() == Variant::INT || call_args[0].get_type() == Variant::FLOAT) {
                key = (Key)(int)call_args[0];
            } else {
                String k = call_args[0];
                key = (Key)OS::get_singleton()->find_keycode_from_string(k);
            }
            return Input::get_singleton()->is_key_pressed(key);
        }
        if (call->method_name.nocasecmp_to("IsMouseButtonDown") == 0 && call_args.size() == 1) {
            int btn = call_args[0];
            return Input::get_singleton()->is_mouse_button_pressed((MouseButton)btn);
        }
        if (call->method_name.nocasecmp_to("GetMouseX") == 0) {
            if (owner) {
                Node *n = Object::cast_to<Node>(owner);
                if (n && n->get_viewport()) return n->get_viewport()->get_mouse_position().x;
            }
            return 0.0;
        }
        if (call->method_name.nocasecmp_to("GetMouseY") == 0) {
            if (owner) {
                Node *n = Object::cast_to<Node>(owner);
                if (n && n->get_viewport()) return n->get_viewport()->get_mouse_position().y;
            }
            return 0.0;
        }

        if (call->method_name.nocasecmp_to("IsOnFloor") == 0 && call_args.size() == 1) {
            Object *o = call_args[0];
            CharacterBody2D *cb2 = Object::cast_to<CharacterBody2D>(o);
            if (cb2) return cb2->is_on_floor();
            CharacterBody3D *cb3 = Object::cast_to<CharacterBody3D>(o);
            if (cb3) return cb3->is_on_floor();
            return false;
        }
        if (call->method_name.nocasecmp_to("GetCollisionCount") == 0 && call_args.size() == 1) {
            Object *o = call_args[0];
            CharacterBody2D *cb2 = Object::cast_to<CharacterBody2D>(o);
            if (cb2) return cb2->get_slide_collision_count();
            CharacterBody3D *cb3 = Object::cast_to<CharacterBody3D>(o);
            if (cb3) return cb3->get_slide_collision_count();
            return 0;
        }

        if (call->method_name == "GetAxis" && call_args.size() == 2) {
             return Input::get_singleton()->get_axis(call_args[0], call_args[1]);
        }
        
        if (call->method_name == "GetJoyAxis" && call_args.size() == 2) {
             return Input::get_singleton()->get_joy_axis(call_args[0], (JoyAxis)(int)call_args[1]);
        }

        if (call->method_name == "GetMousePos" && call_args.size() == 0) {
             // Return global or viewport position?
             // Viewport makes most sense for Canvas
             // But we need a node context.
             if (owner) {
                  CanvasItem *ci = Object::cast_to<CanvasItem>(owner);
                  // Check viewport availability to prevent crashes in headless/unititialized state
                  if (ci && ci->get_viewport()) return ci->get_local_mouse_position();
                  
                  Node *n = Object::cast_to<Node>(owner);
                  if (n) {
                       Viewport *vp = n->get_viewport();
                       if (vp) return vp->get_mouse_position();
                  }
             }
             return Vector2(0,0);
        }
        if (call->method_name == "GetGlobalMousePos" && call_args.size() == 0) {
             if (owner) {
                  CanvasItem *ci = Object::cast_to<CanvasItem>(owner);
                  if (ci && ci->get_viewport()) return ci->get_global_mouse_position();
             }
             // Or display server
             return DisplayServer::get_singleton()->mouse_get_position(); 
        }
        
        // ============================================
        // Game-Specific Keyword Functions
        // ============================================
        
        // Whenever system functions
        if (call->method_name.nocasecmp_to("ActiveWheneverCount") == 0 && call_args.size() == 0) {
            return get_active_whenever_count();
        }
        if (call->method_name.nocasecmp_to("WheneverStatus") == 0 && call_args.size() == 0) {
            return get_whenever_status();
        }
        
        // Keyboard input functions
        if (call->method_name.nocasecmp_to("Inkey") == 0 && call_args.size() == 0) {
            // Return last key pressed (empty string if none)
            // Check Input for any key by scanning common keys
            // For now, just return empty - real implementation would track last key
            return String("");
        }
        
        // Mouse input functions
        if (call->method_name.nocasecmp_to("MouseClick") == 0 && call_args.size() == 0) {
            // Return mouse button state as bitmask
            int state = 0;
            if (Input::get_singleton()->is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) state |= 1;
            if (Input::get_singleton()->is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) state |= 2;
            if (Input::get_singleton()->is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)) state |= 4;
            return state;
        }
        if (call->method_name.nocasecmp_to("MouseX") == 0 && call_args.size() == 0) {
            if (owner) {
                Node *n = Object::cast_to<Node>(owner);
                if (n && n->get_viewport()) return n->get_viewport()->get_mouse_position().x;
            }
            return 0.0;
        }
        if (call->method_name.nocasecmp_to("MouseY") == 0 && call_args.size() == 0) {
            if (owner) {
                Node *n = Object::cast_to<Node>(owner);
                if (n && n->get_viewport()) return n->get_viewport()->get_mouse_position().y;
            }
            return 0.0;
        }

        if (call->method_name.nocasecmp_to("Array") == 0) {
            return call_args;
        }

        // Try Internal Call
        bool found = false;
        Variant v_ret = call_internal(call->method_name, call_args, found);
        if (found) {
            // ByRef parameter write-back for expression-level function calls.
            // When a function with ByRef params is called as an expression
            // (e.g. result = DoubleAndReturn(val)), we need to write back
            // modified parameter values to the caller's variables.
            //
            // IMPORTANT: call_internal() already erased the callee's
            // parameter slots from variables[] (see visual_gasic_instance_call.inc)
            // unless the parameter name collided with a pre-existing caller
            // variable — so `variables.has(param.name)` is unreliable here.
            // The correct post-call value is stashed in _last_byref_captures
            // (the same mechanism the STMT_CALL path in
            // visual_gasic_instance_execute.inc uses). Read from there.
            if (script.is_valid() && script->ast_root) {
                SubDefinition *called_func = nullptr;
                for (int i = 0; i < script->ast_root->subs.size(); i++) {
                    if (script->ast_root->subs[i]->name.nocasecmp_to(call->method_name) == 0) {
                        called_func = script->ast_root->subs[i];
                        break;
                    }
                }
                if (called_func) {
                    int max_params = called_func->parameters.size();
                    int arg_count = call->arguments.size();
                    for (int i = 0; i < max_params && i < arg_count; i++) {
                        const Parameter& param = called_func->parameters[i];
                        if (param.is_by_ref && call->arguments[i] && call->arguments[i]->type == ExpressionNode::VARIABLE) {
                            String caller_var_name = ((VariableNode*)call->arguments[i])->name;
                            for (int j = 0; j < _last_byref_captures.size(); j++) {
                                if (_last_byref_captures[j].first == param.name) {
                                    assign_variable(caller_var_name, _last_byref_captures[j].second);
                                    break;
                                }
                            }
                        }
                    }
                }
            }
            return v_ret;
        }

        if (owner) {
             if (owner->has_method(call->method_name)) {
                 return owner->callv(call->method_name, call_args);
             }
             String snake = call->method_name.to_snake_case();
             if (owner->has_method(snake)) {
                 return owner->callv(snake, call_args);
             }
        }
        raise_error("Failed to call function " + call->method_name);
        return Variant();
    }
    if (expr->type == ExpressionNode::UNARY_OP) {
        UnaryOpNode* u = (UnaryOpNode*)expr;
        Variant val = evaluate_expression(u->operand);
        if (u->op.nocasecmp_to("Not") == 0) {
            return !val.booleanize();
        }
        if (u->op == "-") {
            // Unary Negation
            if (val.get_type() == Variant::INT) {
                return -static_cast<int64_t>(val);
            }
            if (val.get_type() == Variant::FLOAT) {
                return -static_cast<double>(val);
            }
            bool valid;
            Variant res;
            Variant::evaluate(Variant::OP_NEGATE, val, Variant(), res, valid);
            return res;
        }
        return Variant();
    }
    if (expr->type == ExpressionNode::BINARY_OP) {
        BinaryOpNode* bin = (BinaryOpNode*)expr;

        // Check for null operands from parser errors
        if (!bin->left || !bin->right) {
            raise_error("Incomplete binary operation: missing operand");
            return Variant();
        }

        // Short-circuit operators
        if (bin->op.nocasecmp_to("AndAlso") == 0) {
             Variant l = evaluate_expression(bin->left);
             if (!l.booleanize()) return false;
             return evaluate_expression(bin->right).booleanize();
        }
        if (bin->op.nocasecmp_to("OrElse") == 0) {
             Variant l = evaluate_expression(bin->left);
             if (l.booleanize()) return true;
             return evaluate_expression(bin->right).booleanize();
        }
        // Null coalescing operator ??
        if (bin->op == "??") {
             Variant l = evaluate_expression(bin->left);
             if (l.get_type() != Variant::NIL) return l;
             return evaluate_expression(bin->right);
        }

        // "Is" operator — handle BEFORE evaluating right side to avoid
        // noisy variable lookups when the right side is a Godot class name
        // (e.g. TypeOf input_event Is InputEventMouseMotion).
        if (bin->op.nocasecmp_to("Is") == 0) {
             Variant l = evaluate_expression(bin->left);
             
             // Check if right side is a known Godot class name — skip variable evaluation
             if (bin->right && bin->right->type == ExpressionNode::VARIABLE) {
                 String class_name = ((VariableNode*)bin->right)->name;
                 if (ClassDB::class_exists(class_name)) {
                     if (l.get_type() == Variant::OBJECT) {
                         Object* obj = Object::cast_to<Object>(l);
                         if (obj) return obj->is_class(class_name);
                     }
                     return false;
                 }
                 // "Nothing" keyword — null check
                 if (class_name.nocasecmp_to("Nothing") == 0) {
                     return l.get_type() == Variant::NIL;
                 }
             }
             
             // Normal evaluation for non-class-name right side
             Variant r = evaluate_expression(bin->right);
             
             // Null check: obj Is Nothing
             if (r.get_type() == Variant::NIL) {
                 return l.get_type() == Variant::NIL;
             }
             
             // String class name (from variable that resolved to a string)
             if (l.get_type() == Variant::OBJECT && r.get_type() == Variant::STRING) {
                 String class_name = String(r);
                 if (ClassDB::class_exists(class_name)) {
                     Object* obj = Object::cast_to<Object>(l);
                     if (obj) return obj->is_class(class_name);
                     return false;
                 }
             }
             
             // Reference equality fallback
             bool valid;
             Variant res;
             Variant::evaluate(Variant::OP_EQUAL, l, r, res, valid);
             return res;
        }

        // "IsNot" operator — negated reference equality
        if (bin->op.nocasecmp_to("IsNot") == 0) {
             Variant l = evaluate_expression(bin->left);

             // Check if right side is a known Godot class name — skip variable evaluation
             if (bin->right && bin->right->type == ExpressionNode::VARIABLE) {
                 String class_name = ((VariableNode*)bin->right)->name;
                 if (ClassDB::class_exists(class_name)) {
                     if (l.get_type() == Variant::OBJECT) {
                         Object* obj = Object::cast_to<Object>(l);
                         if (obj) return !obj->is_class(class_name);
                     }
                     return true;
                 }
                 // "Nothing" keyword — null check
                 if (class_name.nocasecmp_to("Nothing") == 0) {
                     return l.get_type() != Variant::NIL;
                 }
             }

             // Normal evaluation for non-class-name right side
             Variant r = evaluate_expression(bin->right);

             // Null check: obj IsNot Nothing
             if (r.get_type() == Variant::NIL) {
                 return l.get_type() != Variant::NIL;
             }

             // String class name (from variable that resolved to a string)
             if (l.get_type() == Variant::OBJECT && r.get_type() == Variant::STRING) {
                 String class_name = String(r);
                 if (ClassDB::class_exists(class_name)) {
                     Object* obj = Object::cast_to<Object>(l);
                     if (obj) return !obj->is_class(class_name);
                     return true;
                 }
             }

             // Reference inequality fallback
             bool valid;
             Variant res;
             Variant::evaluate(Variant::OP_NOT_EQUAL, l, r, res, valid);
             return res;
        }

        Variant l = evaluate_expression(bin->left);
        Variant r = evaluate_expression(bin->right);
        
        String op = bin->op;
        Variant result;
        bool valid;
        
        if (op == "&") {
             return String(l) + String(r);
        }

        if (op == "**" || op == "^") {
             // Power/Exponent
             return UtilityFunctions::pow(l, r);
        }
        if (op == "//") {
             // Floor Division
             double val = (double)l / (double)r;
             return floor(val);
        }
        if (op == "\\") {
             // Integer Division (VB style)
             int64_t li = (int64_t)l;
             int64_t ri = (int64_t)r;
             if (ri == 0) {
                 raise_error("Division by zero", 11);
                 return 0;
             }
             return li / ri;
        }
        if (op.nocasecmp_to("Mod") == 0 || op == "%") {
             // GDScript-style string format: "fmt" % value
             if (l.get_type() == Variant::STRING) {
                 String fmt = l;
                 if (r.get_type() == Variant::ARRAY) {
                     return fmt % r;
                 } else {
                     Array arr;
                     arr.push_back(r);
                     return fmt % arr;
                 }
             }
             // Modulo
             int64_t li = (int64_t)l;
             int64_t ri = (int64_t)r;
             if (ri == 0) {
                 raise_error("Division by zero", 11);
                 return 0;
             }
             return li % ri;
        }

        // Bit-shift operators
        if (op == "<<") {
             return Variant((int64_t)l << (int64_t)r);
        }
        if (op == ">>") {
             return Variant((int64_t)l >> (int64_t)r);
        }
        
        if (op.nocasecmp_to("And") == 0) {
            // VB6: bitwise when both operands are numeric, logical otherwise
            if ((l.get_type() == Variant::INT || l.get_type() == Variant::FLOAT) &&
                (r.get_type() == Variant::INT || r.get_type() == Variant::FLOAT)) {
                return Variant((int64_t)l & (int64_t)r);
            }
            return l.booleanize() && r.booleanize();
        }
        if (op.nocasecmp_to("Or") == 0) {
            if ((l.get_type() == Variant::INT || l.get_type() == Variant::FLOAT) &&
                (r.get_type() == Variant::INT || r.get_type() == Variant::FLOAT)) {
                return Variant((int64_t)l | (int64_t)r);
            }
            return l.booleanize() || r.booleanize();
        }
        if (op.nocasecmp_to("Xor") == 0) {
            if ((l.get_type() == Variant::INT || l.get_type() == Variant::FLOAT) &&
                (r.get_type() == Variant::INT || r.get_type() == Variant::FLOAT)) {
                return Variant((int64_t)l ^ (int64_t)r);
            }
            return l.booleanize() != r.booleanize();
        }
        // VB6 Eqv: logical equivalence (XNOR). Bitwise when numeric, logical otherwise.
        if (op.nocasecmp_to("Eqv") == 0) {
            if ((l.get_type() == Variant::INT || l.get_type() == Variant::FLOAT) &&
                (r.get_type() == Variant::INT || r.get_type() == Variant::FLOAT)) {
                return Variant(~((int64_t)l ^ (int64_t)r)); // bitwise XNOR
            }
            return l.booleanize() == r.booleanize();
        }
        // VB6 Imp: logical implication. Bitwise: (Not A) Or B. Logical: (Not A) Or B.
        if (op.nocasecmp_to("Imp") == 0) {
            if ((l.get_type() == Variant::INT || l.get_type() == Variant::FLOAT) &&
                (r.get_type() == Variant::INT || r.get_type() == Variant::FLOAT)) {
                return Variant(~(int64_t)l | (int64_t)r); // bitwise implication
            }
            return !l.booleanize() || r.booleanize();
        }
        if (op.nocasecmp_to("Like") == 0) {
            // VB6-style Like pattern matching
            // Pattern characters:
            //   ? - matches any single character
            //   * - matches zero or more characters
            //   # - matches any single digit (0-9)
            //   [charlist] - matches any single character in charlist
            //   [!charlist] - matches any single character NOT in charlist
            String value = String(l);
            String pattern = String(r);
            return vb_like_match(value, pattern);
        }
        
        Variant::Operator v_op = Variant::OP_ADD;
        if (op == "+") v_op = Variant::OP_ADD;
        else if (op == "-") v_op = Variant::OP_SUBTRACT;
        else if (op == "*") v_op = Variant::OP_MULTIPLY;
        else if (op == "/") {
            // Check for division by zero
            double divisor = (double)r;
            if (divisor == 0.0) {
                raise_error("Division by zero", 11);
                return 0.0;
            }
            return (double)l / divisor;
        }
        else if (op == "=") {
             if (option_compare_text && l.get_type() == Variant::STRING && r.get_type() == Variant::STRING) {
                 return String(l).nocasecmp_to(String(r)) == 0;
             }
             v_op = Variant::OP_EQUAL;
        }
        else if (op == "<") {
             if (option_compare_text && l.get_type() == Variant::STRING && r.get_type() == Variant::STRING) {
                 return String(l).nocasecmp_to(String(r)) < 0;
             }
             v_op = Variant::OP_LESS;
        }
        else if (op == ">") {
             if (option_compare_text && l.get_type() == Variant::STRING && r.get_type() == Variant::STRING) {
                 return String(l).nocasecmp_to(String(r)) > 0;
             }
             
             // Explicit numeric comparison to ensure correctness
             if ((l.get_type() == Variant::FLOAT || l.get_type() == Variant::INT) && 
                 (r.get_type() == Variant::FLOAT || r.get_type() == Variant::INT)) {
                  return (double)l > (double)r;
             }
             
             v_op = Variant::OP_GREATER;
             Variant::evaluate(v_op, l, r, result, valid);
             return result;
        }
        else if (op == "<=") {
             if (option_compare_text && l.get_type() == Variant::STRING && r.get_type() == Variant::STRING) {
                 return String(l).nocasecmp_to(String(r)) <= 0;
             }
             v_op = Variant::OP_LESS_EQUAL;
        }
        else if (op == ">=") {
             if (option_compare_text && l.get_type() == Variant::STRING && r.get_type() == Variant::STRING) {
                 return String(l).nocasecmp_to(String(r)) >= 0;
             }
             v_op = Variant::OP_GREATER_EQUAL;
        }
        else if (op == "<>") {
             if (option_compare_text && l.get_type() == Variant::STRING && r.get_type() == Variant::STRING) {
                 return String(l).nocasecmp_to(String(r)) != 0;
             }
             v_op = Variant::OP_NOT_EQUAL;
        }
        else if (op == "!=") {
             if (option_compare_text && l.get_type() == Variant::STRING && r.get_type() == Variant::STRING) {
                 return String(l).nocasecmp_to(String(r)) != 0;
             }
             v_op = Variant::OP_NOT_EQUAL;
        }
        
        // Fast numeric path
        if ((l.get_type() == Variant::INT || l.get_type() == Variant::FLOAT) &&
            (r.get_type() == Variant::INT || r.get_type() == Variant::FLOAT)) {
            const bool l_int = l.get_type() == Variant::INT;
            const bool r_int = r.get_type() == Variant::INT;
            if (l_int && r_int) {
                int64_t li = static_cast<int64_t>(l);
                int64_t ri = static_cast<int64_t>(r);
                if (op == "+") return li + ri;
                if (op == "-") return li - ri;
                if (op == "*") return li * ri;
                if (op == "/") return (double)li / (double)ri;
                if (op == "=") return li == ri;
                if (op == "<") return li < ri;
                if (op == ">") return li > ri;
                if (op == "<=") return li <= ri;
                if (op == ">=") return li >= ri;
                if (op == "<>") return li != ri;
                if (op == "!=") return li != ri;
            } else {
                double ld = (double)l;
                double rd = (double)r;
                if (op == "+") return ld + rd;
                if (op == "-") return ld - rd;
                if (op == "*") return ld * rd;
                if (op == "/") return ld / rd;
                if (op == "=") return ld == rd;
                if (op == "<") return ld < rd;
                if (op == ">") return ld > rd;
                if (op == "<=") return ld <= rd;
                if (op == ">=") return ld >= rd;
                if (op == "<>") return ld != rd;
                if (op == "!=") return ld != rd;
            }
        }

        Variant::evaluate(v_op, l, r, result, valid);
        return result;
    }
    return Variant();
}
