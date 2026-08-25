#include "visual_gasic_compiler.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/core/class_db.hpp>

namespace {
constexpr bool kEnableLoopFusions = true;
constexpr bool kTraceArraySumMatcher = false;

bool vg_variant_truthy(const Variant &value) {
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
}

// VB6-style Like pattern matching for compile-time constant folding
bool vb_like_match(const String& value, const String& pattern) {
    int v_len = value.length();
    int p_len = pattern.length();
    int v_idx = 0;
    int p_idx = 0;
    
    // Star tracking for backtracking
    int star_p_idx = -1;
    int star_v_idx = -1;
    
    while (v_idx < v_len) {
        if (p_idx < p_len) {
            char32_t p_char = pattern[p_idx];
            
            // ? matches any single character
            if (p_char == '?') {
                v_idx++;
                p_idx++;
                continue;
            }
            
            // # matches any single digit
            if (p_char == '#') {
                char32_t v_char = value[v_idx];
                if (v_char >= '0' && v_char <= '9') {
                    v_idx++;
                    p_idx++;
                    continue;
                } else {
                    // No match, try backtracking
                    if (star_p_idx >= 0) {
                        p_idx = star_p_idx + 1;
                        star_v_idx++;
                        v_idx = star_v_idx;
                        continue;
                    }
                    return false;
                }
            }
            
            // * matches zero or more characters
            if (p_char == '*') {
                star_p_idx = p_idx;
                star_v_idx = v_idx;
                p_idx++;
                continue;
            }
            
            // [charlist] or [!charlist]
            if (p_char == '[') {
                p_idx++;
                bool negate = false;
                if (p_idx < p_len && pattern[p_idx] == '!') {
                    negate = true;
                    p_idx++;
                }
                
                // Find the closing bracket
                int bracket_start = p_idx;
                while (p_idx < p_len && pattern[p_idx] != ']') {
                    p_idx++;
                }
                
                if (p_idx >= p_len) {
                    // No closing bracket found - treat as literal
                    if (star_p_idx >= 0) {
                        p_idx = star_p_idx + 1;
                        star_v_idx++;
                        v_idx = star_v_idx;
                        continue;
                    }
                    return false;
                }
                
                // Extract charlist
                String charlist = pattern.substr(bracket_start, p_idx - bracket_start);
                p_idx++; // Skip ]
                
                char32_t v_char = value[v_idx];
                bool found = false;
                
                // Check charlist (handles ranges like a-z)
                for (int i = 0; i < charlist.length(); i++) {
                    if (i + 2 < charlist.length() && charlist[i + 1] == '-') {
                        // Range like a-z
                        char32_t range_start = charlist[i];
                        char32_t range_end = charlist[i + 2];
                        if (v_char >= range_start && v_char <= range_end) {
                            found = true;
                            break;
                        }
                        i += 2; // Skip the range
                    } else {
                        if (charlist[i] == v_char) {
                            found = true;
                            break;
                        }
                    }
                }
                
                bool matches = negate ? !found : found;
                if (matches) {
                    v_idx++;
                    continue;
                } else {
                    if (star_p_idx >= 0) {
                        p_idx = star_p_idx + 1;
                        star_v_idx++;
                        v_idx = star_v_idx;
                        continue;
                    }
                    return false;
                }
            }
            
            // Literal character match (case-insensitive by default in VB6)
            char32_t v_char = value[v_idx];
            char32_t p_lower = (p_char >= 'A' && p_char <= 'Z') ? p_char + 32 : p_char;
            char32_t v_lower = (v_char >= 'A' && v_char <= 'Z') ? v_char + 32 : v_char;
            
            if (p_lower == v_lower) {
                v_idx++;
                p_idx++;
                continue;
            }
        }
        
        // No match at current position, try backtracking from last *
        if (star_p_idx >= 0) {
            p_idx = star_p_idx + 1;
            star_v_idx++;
            v_idx = star_v_idx;
            continue;
        }
        
        return false;
    }
    
    // Consume any remaining * in pattern
    while (p_idx < p_len && pattern[p_idx] == '*') {
        p_idx++;
    }
    
    return p_idx == p_len;
}
}

VisualGasicCompiler::VisualGasicCompiler() : current_chunk(nullptr), current_line(0), compile_ok(true) {
}

VisualGasicCompiler::~VisualGasicCompiler() {
}

void VisualGasicCompiler::emit_byte(uint8_t byte) {
    current_chunk->write(byte, current_line);
}

void VisualGasicCompiler::emit_f32(float p_value) {
    union { float f; uint32_t u; } conv;
    conv.f = p_value;
    emit_byte((uint8_t)(conv.u & 0xff));
    emit_byte((uint8_t)((conv.u >> 8) & 0xff));
    emit_byte((uint8_t)((conv.u >> 16) & 0xff));
    emit_byte((uint8_t)((conv.u >> 24) & 0xff));
}

void VisualGasicCompiler::emit_i32(int32_t p_value) {
    uint32_t u = (uint32_t)p_value;
    emit_byte((uint8_t)(u & 0xff));
    emit_byte((uint8_t)((u >> 8) & 0xff));
    emit_byte((uint8_t)((u >> 16) & 0xff));
    emit_byte((uint8_t)((u >> 24) & 0xff));
}

void VisualGasicCompiler::emit_bytes(uint8_t byte1, uint8_t byte2) {
    emit_byte(byte1);
    emit_byte(byte2);
}

void VisualGasicCompiler::emit_const_index(int idx) {
    // Emit a 16-bit little-endian constant pool index (2 bytes).
    // All opcodes that reference the constant pool use this encoding,
    // lifting the old 256-constant limit to 65 535.
    if (idx < 0 || idx >= 65536) {
        UtilityFunctions::print("Compiler Error: constant pool index out of range: ", idx);
        emit_byte(0);
        emit_byte(0);
        return;
    }
    emit_byte((uint8_t)(idx & 0xFF));        // lo
    emit_byte((uint8_t)((idx >> 8) & 0xFF)); // hi
}

void VisualGasicCompiler::emit_constant(const Variant& value) {
    int idx = current_chunk->add_constant(value);
    if (idx < 65536) {
        // OP_CONSTANT always uses 2-byte index (v4.3 — widened from 1-byte).
        emit_byte(OP_CONSTANT);
        emit_const_index(idx);
    } else {
        UtilityFunctions::print("Compiler Error: Too many constants (>65535)");
    }
}

void VisualGasicCompiler::emit_return() {
    emit_byte(OP_RETURN);
}

int VisualGasicCompiler::emit_jump(uint8_t op) {
    emit_byte(op);
    emit_byte(0);
    emit_byte(0);
    return current_chunk->code.size() - 2;
}

void VisualGasicCompiler::patch_jump(int offset_pos) {
    int offset = current_chunk->code.size() - offset_pos - 2;
    current_chunk->code.write[offset_pos] = (offset >> 8) & 0xFF;
    current_chunk->code.write[offset_pos + 1] = offset & 0xFF;
}

void VisualGasicCompiler::emit_loop(int loop_start) {
    emit_byte(OP_LOOP);
    int offset = current_chunk->code.size() - loop_start + 2;
    emit_byte((offset >> 8) & 0xFF);
    emit_byte(offset & 0xFF);
}

bool VisualGasicCompiler::compile(ModuleNode* module, const String& entry_point, BytecodeChunk* chunk, const HashSet<String>* extra_buffer_vars) {
    current_chunk = chunk;
    current_module = module;
    compile_ok = true;
    array_vars.clear();
    param_vars.clear();
    dictionary_vars.clear();
    trusted_dictionary_vars.clear();
    sole_owner_dict_vars.clear();
    array_types.clear();
    array_bound_vars.clear();
    local_slots.clear();
    local_types.clear();
    local_const_map.clear();
    typed_locals.clear();
    non_local_names.clear();
    used_vars.clear();
    expr_cache.clear();
    loop_vars.clear();
    loop_bound_vars.clear();
    loop_exit_jumps.clear();
    loop_continue_targets.clear();
    loop_continue_forward_jumps.clear();
    temp_local_id = 0;
    current_sub = nullptr;
    
    // Find the entry point sub (supports overloading via $N arity suffix)
    SubDefinition* sub = nullptr;
    String base_entry = entry_point;
    int target_arity = -1;
    int dollar_pos = entry_point.find("$");
    if (dollar_pos >= 0) {
        base_entry = entry_point.substr(0, dollar_pos);
        target_arity = entry_point.substr(dollar_pos + 1).to_int();
    }
    for(int i=0; i<module->subs.size(); i++) {
        if (module->subs[i]->name.nocasecmp_to(base_entry) == 0) {
            if (target_arity >= 0) {
                if (module->subs[i]->parameters.size() == target_arity) {
                    sub = module->subs[i];
                    break;
                }
            } else if (!sub) {
                sub = module->subs[i]; // First match fallback
            }
        }
    }
    
    if (!sub) {
        UtilityFunctions::print("Compiler: Entry point not found: ", entry_point);
        return false;
    }


    current_sub = sub;

    if (module) {
        for (int ci = 0; ci < module->constants.size(); ci++) {
            ConstStatement *cs = module->constants[ci];
            if (cs && cs->value && is_constant_expr(cs->value)) {
                local_const_map[cs->name.to_lower()] = eval_constant_expr(cs->value);
            }
        }
    }

    // ── Fast-call convention detection (v6.0) ──────────────────────────
    // A Sub/Function qualifies for the fast-param path when EVERY parameter is
    // a scalar value type passed ByVal (no ByRef, no ParamArray, no Optional)
    // and — for Functions — the return type is also scalar.  Such params/return
    // get dedicated LOCAL SLOTS seeded directly from the call args, bypassing the
    // per-call variables[] Dictionary insert/lookup/erase that dominates call
    // overhead.  Scalar-only guarantees value semantics, so there is no dict/
    // array aliasing or sole-owner escape-analysis interaction to worry about.
    auto _vg_is_scalar_type = [](const String &th) -> bool {
        String t = th.to_lower();
        return t == "integer" || t == "long" || t == "longlong" ||
               t == "single"  || t == "double"   || t == "boolean" ||
               t == "byte"    || t == "string"   || t == "currency" ||
               t == "date"    || t == "short"    || t == "char";
    };
    bool fast_params_ok = true;
    for (int i = 0; i < sub->parameters.size(); i++) {
        const Parameter &p = sub->parameters[i];
        if (p.is_by_ref || p.is_param_array || p.is_optional ||
            p.type_hint.is_empty() || !_vg_is_scalar_type(p.type_hint)) {
            fast_params_ok = false;
            break;
        }
    }
    if (fast_params_ok && sub->type == SubDefinition::TYPE_FUNCTION) {
        // Untyped (Variant) return excluded to keep the return slot value-typed.
        if (sub->return_type.is_empty() || !_vg_is_scalar_type(sub->return_type)) {
            fast_params_ok = false;
        }
    }

    // For a fast-params Function the return variable (named after the Sub) must
    // be eligible for a local slot, so do NOT force it non-local.
    if (!(fast_params_ok && sub->type == SubDefinition::TYPE_FUNCTION)) {
        non_local_names.insert(sub->name.to_lower());
    }
    used_vars.insert(sub->name.to_lower());

    // Keywords and singletons must always go through OP_GET_GLOBAL
    // so the VM's special resolution (Input singleton, Me/Super owner,
    // Godot engine, child-node search, etc.) is used.
    non_local_names.insert("input");
    non_local_names.insert("godot");
    non_local_names.insert("me");
    non_local_names.insert("super");
    // VB6 virtual objects (v2.10.0) — must route through OP_GET_GLOBAL
    // so the VM can resolve App, Screen, Err as virtual Dictionary objects.
    non_local_names.insert("app");
    non_local_names.insert("screen");
    non_local_names.insert("err");
    non_local_names.insert("printer"); // VB6 Printer global (v3.5.0)
    // Builtin namespace sentinels — must route through OP_GET_GLOBAL so the
    // VM's sentinel-dict creation fires (see known_ns[] in bytecode_vm).
    non_local_names.insert("soundgen");
    non_local_names.insert("clipboard");
    non_local_names.insert("debug");
    non_local_names.insert("regexp");
    non_local_names.insert("music");
    non_local_names.insert("tracker");
    // "Array" sentinel omitted intentionally — Array is also a type keyword
    // and registering it as non-local causes issues with array-variable handling.
    // Godot engine singletons — must route through OP_GET_GLOBAL so the
    // VM can resolve them via Engine::get_singleton() at runtime.
    static const char *godot_singletons[] = {
        "engine", "os", "time", "resourceloader", "resourcesaver",
        "audioserver", "displayserver", "inputmap", "classdb",
        "projectsettings", "performance", "renderingserver",
        "physicsserver2d", "physicsserver3d", "navigationserver2d",
        "navigationserver3d", "cameraserver", "themedb",
        "translationserver", "ip", "geometry2d", "geometry3d",
        "marshalls", "resourceuid", "textservermanager",
        "workerthreadpool", "enginedebugger", "nativemenu",
        "gdextensionmanager", "xrserver", nullptr
    };
    for (const char **s = godot_singletons; *s; ++s) {
        non_local_names.insert(*s);
    }

    for (int i = 0; i < sub->parameters.size(); i++) {
        const String pkey = sub->parameters[i].name.to_lower();
        if (fast_params_ok) {
            // Fast-call: give each scalar ByVal param its own local slot
            // (assigned in order → slots 0..P-1) seeded from the call args at
            // runtime.  Keep it in param_vars for subscript/namespace-shadow
            // logic, but NOT in non_local_names (that would force OP_GET_GLOBAL).
            param_vars.insert(pkey);
            ValueType pvt = VT_UNKNOWN;
            String t = sub->parameters[i].type_hint.to_lower();
            if (t == "integer" || t == "long" || t == "longlong") pvt = VT_INT;
            else if (t == "single" || t == "double") pvt = VT_FLOAT;
            get_or_add_local(sub->parameters[i].name, pvt);
        } else {
            param_vars.insert(pkey);
            if (sub->parameters[i].is_param_array) {
                array_vars.insert(pkey);
                non_local_names.insert(pkey);
            } else if (sub->parameters[i].is_by_ref) {
                non_local_names.insert(pkey);
            } else {
                // ByVal non-scalar params (Variant arrays/objects): use a local
                // slot seeded from variables[] at call entry.  Marking these
                // non-local forced OP_GET_GLOBAL, which can miss the bound arg
                // and fall through to scene-node/singleton lookups (OBJECT).
                get_or_add_local(sub->parameters[i].name, VT_UNKNOWN);
            }
        }
    }

    // Fast-call: allocate the return-value slot (Functions only) immediately
    // after the params, then publish the fast-call metadata on the chunk so the
    // VM seeds params from args and reads the return value straight from its
    // slot — no variables[] round-trip.  param_count/return_slot are captured
    // here, before any body-level Dim locals grab higher slots.
    if (fast_params_ok) {
        current_chunk->fast_params = true;
        current_chunk->param_count = sub->parameters.size();
        // Precompute per-slot coercion codes so the call binder skips the
        // per-call type_hint.to_lower() + string compares.  MUST mirror
        // call_internal's fast-arg coercion EXACTLY (0=none,1=int64,2=double,
        // 3=string,4=bool) — note longlong/byte/currency/date/short/char map to
        // 0 (no coercion), matching the binder's original untouched behavior.
        auto _vg_coerce_code = [](const String &th) -> int8_t {
            String t = th.to_lower();
            if (t == "integer" || t == "long") return 1;
            if (t == "single"  || t == "double") return 2;
            if (t == "string") return 3;
            if (t == "boolean") return 4;
            return 0;
        };
        current_chunk->fast_param_coerce.resize(sub->parameters.size());
        for (int i = 0; i < sub->parameters.size(); i++) {
            current_chunk->fast_param_coerce.write[i] = _vg_coerce_code(sub->parameters[i].type_hint);
        }
        if (sub->type == SubDefinition::TYPE_FUNCTION) {
            ValueType rvt = VT_UNKNOWN;
            String rt = sub->return_type.to_lower();
            if (rt == "integer" || rt == "long" || rt == "longlong") rvt = VT_INT;
            else if (rt == "single" || rt == "double") rvt = VT_FLOAT;
            current_chunk->return_slot = get_or_add_local(sub->name, rvt);
            current_chunk->fast_return_coerce = _vg_coerce_code(sub->return_type);
        } else {
            current_chunk->return_slot = -1;
        }
    }

    // Mark module-level variables as non-local so they use OP_SET_GLOBAL
    // This ensures global Variant variables can change types correctly
    for (int i = 0; i < module->variables.size(); i++) {
        String gkey = module->variables[i]->name.to_lower();
        // A fast-call param/return already claimed a local slot for this name;
        // per VB6 scoping the local must shadow the module global, so do NOT
        // force it non-local (that would make the body read/write the global
        // via OP_GET_GLOBAL/OP_SET_GLOBAL instead of its own slot).
        if (fast_params_ok && local_slots.has(gkey)) {
            continue;
        }
        non_local_names.insert(gkey);
        // Register global arrays / dictionaries so the compiler can
        // distinguish  foo(i)  as an array access vs. a function call.
        if (module->variables[i]->array_sizes.size() > 0) {
            array_vars.insert(module->variables[i]->name.to_lower());
        }
        String vtype = module->variables[i]->type.to_lower();
        if (vtype == "dictionary") {
            dictionary_vars.insert(module->variables[i]->name.to_lower());
        }
        // Register "Dim X As Array" — dynamic arrays typed as Array
        // so the compiler emits OP_GET_ARRAY instead of OP_CALL
        if (vtype == "array") {
            array_vars.insert(module->variables[i]->name.to_lower());
        }
    }

    // v4.4.0: pre-scan every Sub in the module for "X = New MemoryBuffer(...)" /
    // "Set X = New MemoryBuffer(...)" assignments so buffer_vars is populated even
    // when a module-level `Public X As Variant` global gets its MemoryBuffer
    // identity assigned in a DIFFERENT Sub (e.g. an Init routine) than the ones
    // that later index into it — this can't be seen by looking only at the entry
    // point Sub currently being compiled.
    scan_module_for_buffer_vars(module, buffer_vars);
    // Cross-module case: the Sub being compiled here may live in an imported
    // module that never itself contains the "Set X = New MemoryBuffer(...)"
    // assignment (that lives in a *different* imported module's Init routine).
    // The caller (VisualGasicInstance) pre-computes the union across every
    // module it knows about and hands it to us here.
    if (extra_buffer_vars) {
        for (const String &name : *extra_buffer_vars) {
            buffer_vars.insert(name);
        }
    }

    if (current_sub && current_sub->name.nocasecmp_to("BenchFileIO") == 0 && sub->parameters.size() >= 2) {
        VariableNode iter_node;
        iter_node.name = sub->parameters[0].name;
        VariableNode size_node;
        size_node.name = sub->parameters[1].name;

        compile_expression(&iter_node);
        compile_expression(&size_node);
        int idx = current_chunk->add_constant(String("BenchFileIOFast"));
        emit_byte(OP_CALL);
        emit_const_index(idx);
        emit_byte((uint8_t)2);

        int slot = get_or_add_local(sub->name, VT_INT);
        if (slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
        else {
            int name_idx = current_chunk->add_constant(sub->name);
            emit_byte(OP_SET_GLOBAL);
            emit_const_index(name_idx);
        }
        // This early-return path skips the normal local_count assignment below,
        // so publish it here — required now that fast-params gives the return
        // value (and params) real local slots that the VM must allocate/seed.
        current_chunk->local_count = local_slots.size();
        emit_return();
        return compile_ok;
    }

    // Collect local variables and array types for this sub
    for (int i = 0; i < sub->statements.size(); i++) {
        collect_locals(sub->statements[i]);
    }

    // Collect used vars for DCE
    for (int i = 0; i < sub->statements.size(); i++) {
        collect_used_vars_stmt(sub->statements[i]);
    }

    // Local count for VM
    current_chunk->local_count = local_slots.size();

    // Collect local array variable names for this sub
    for (int i = 0; i < sub->statements.size(); i++) {
        collect_locals(sub->statements[i]);
    }

    // ── Sole-ownership escape analysis ──────────────────────────────
    // Revoke sole-owner status from any dictionary variable that "escapes":
    //   • It appears as a function call argument (could be passed by ref)
    //   • It's a module-level / non-local variable
    //   • It's assigned TO another variable (alias)
    // This is a conservative analysis — false negatives are safe (we just
    // fall back to Godot Dictionary), false positives would be a bug.
    {
        HashSet<String> escaped_dicts;
        // Non-locals can never be sole-owner
        for (const String &name : sole_owner_dict_vars) {
            if (non_local_names.has(name)) {
                escaped_dicts.insert(name);
            }
        }
        // Scan all statements for escaping uses
        for (int i = 0; i < sub->statements.size(); i++) {
            _check_dict_escapes(sub->statements[i], escaped_dicts);
        }
        for (const String &name : escaped_dicts) {
            sole_owner_dict_vars.erase(name);
        }
    }
    
    for (int i = 0; i < sub->statements.size(); i++) {
        Statement *stmt = sub->statements[i];
        if (stmt && stmt->type == STMT_REDIM && i + 1 < sub->statements.size()) {
            ReDimStatement *rd = (ReDimStatement *)stmt;
            Statement *next_stmt = sub->statements[i + 1];
            if (!rd->preserve && rd->array_sizes.size() == 1 && next_stmt && next_stmt->type == STMT_FOR) {
                ForStatement *f = (ForStatement *)next_stmt;
                String fill_arr;
                if (is_loop_array_fill(f, fill_arr)) {
                    String rd_name = rd->variable_name;
                    if (fill_arr.nocasecmp_to(rd_name) == 0) {
                        String rd_bound = extract_bound_var(rd->array_sizes[0]);
                        String loop_bound = extract_bound_var(f->to_val);
                        if (!rd_bound.is_empty() && rd_bound.nocasecmp_to(loop_bound) == 0) {
                            VariableNode arr_node;
                            arr_node.name = rd_name;
                            compile_expression(f->to_val);
                            emit_constant(Variant((int64_t)1));
                            emit_byte(OP_ADD_I64);
                            emit_byte(OP_ALLOC_FILL_I64);

                            int slot = get_or_add_local(rd_name, VT_UNKNOWN);
                            if (slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                            else {
                                int idx = current_chunk->add_constant(rd_name);
                                emit_byte(OP_SET_GLOBAL);
                                emit_const_index(idx);
                            }
                            i++; // Skip the fill loop
                            continue;
                        }
                    }
                }
            }
        }
        compile_statement(stmt);
        if (!compile_ok) {
            // Unsupported construct - AST interpreter will handle this sub
            break;
        }
    }
    current_chunk->local_count = local_slots.size();
    emit_return();
    
    return compile_ok;
}

int VisualGasicCompiler::get_or_add_local(const String &name, ValueType type) {
    String key = name.to_lower();
    if (non_local_names.has(key)) {
        return -1;
    }
    if (local_slots.has(key)) {
        if (type != VT_UNKNOWN) {
            bool locked = typed_locals.has(key);
            if (!locked || local_types[key] == VT_UNKNOWN) {
                local_types[key] = type;
                uint8_t lt = to_local_type(type);
                int slot = local_slots[key];
                if (slot >= 0 && slot < current_chunk->local_types.size()) {
                    current_chunk->local_types.write[slot] = lt;
                }
            }
        }
        return local_slots[key];
    }
    int slot = local_slots.size();
    local_slots[key] = slot;
    local_types[key] = type;
    current_chunk->local_names.push_back(name);
    current_chunk->local_types.push_back(to_local_type(type));
    return slot;
}

VisualGasicCompiler::ValueType VisualGasicCompiler::get_local_type(const String &name) const {
    String key = name.to_lower();
    if (local_types.has(key)) return local_types[key];
    return VT_UNKNOWN;
}

uint8_t VisualGasicCompiler::to_local_type(ValueType type) const {
    if (type == VT_INT) return 1;
    if (type == VT_FLOAT) return 2;
    return 0;
}

void VisualGasicCompiler::collect_locals(Statement* stmt) {
    if (!stmt) return;
    switch (stmt->type) {
        case STMT_DIM: {
            DimStatement* s = (DimStatement*)stmt;
            if (s->array_sizes.size() > 0) {
                array_vars.insert(s->variable_name.to_lower());
                String t = s->type_name.to_lower();
                if (t == "integer" || t == "long" || t == "longlong") array_types[s->variable_name.to_lower()] = VT_INT;
                else if (t == "single" || t == "double") array_types[s->variable_name.to_lower()] = VT_FLOAT;
                String bound = extract_bound_var(s->array_sizes[0]);
                if (!bound.is_empty()) array_bound_vars[s->variable_name.to_lower()] = bound.to_lower();
            } else {
                String t = s->type_name.to_lower();
                ValueType vt = VT_UNKNOWN;
                if (t == "integer" || t == "long" || t == "longlong") vt = VT_INT;
                else if (t == "single" || t == "double") vt = VT_FLOAT;
                else if (t == "dictionary") {
                    dictionary_vars.insert(s->variable_name.to_lower());
                    trusted_dictionary_vars.insert(s->variable_name.to_lower());
                    // Sole-ownership candidate: typed local dict declared with Dim
                    // Will be revoked if the dict escapes (passed as arg, assigned to another var, etc.)
                    sole_owner_dict_vars.insert(s->variable_name.to_lower());
                }
                // Register "Dim X As Array" — dynamic arrays typed as Array
                else if (t == "array") {
                    array_vars.insert(s->variable_name.to_lower());
                }
                // M5: MemoryBuffer type — fast byte buffer stored as PackedByteArray
                else if (t == "memorybuffer" || t == "buffer") {
                    buffer_vars.insert(s->variable_name.to_lower());
                }
                get_or_add_local(s->variable_name, vt);
                if (vt != VT_UNKNOWN) {
                    typed_locals.insert(s->variable_name.to_lower());
                }
            }
            break;
        }
        case STMT_REDIM: {
            ReDimStatement* s = (ReDimStatement*)stmt;
            if (s->array_sizes.size() > 0) {
                array_vars.insert(s->variable_name.to_lower());
                String bound = extract_bound_var(s->array_sizes[0]);
                if (!bound.is_empty()) array_bound_vars[s->variable_name.to_lower()] = bound.to_lower();
            }
            break;
        }
        case STMT_ERASE: {
            EraseStatement* es = (EraseStatement*)stmt;
            // Ensure the variable has a local slot
            get_or_add_local(es->variable_name, VT_UNKNOWN);
            break;
        }
        case STMT_ASSIGNMENT: {
            AssignmentStatement *s = (AssignmentStatement *)stmt;
            if (s->target && s->target->type == ExpressionNode::VARIABLE && s->value && s->value->type == ExpressionNode::NEW) {
                NewNode *n = (NewNode *)s->value;
                if (n->class_name.nocasecmp_to("Dictionary") == 0) {
                    dictionary_vars.insert(((VariableNode *)s->target)->name.to_lower());
                }
            }
            break;
        }
        case STMT_FOR: {
            ForStatement* f = (ForStatement*)stmt;
            get_or_add_local(f->variable_name, VT_UNKNOWN);
            for (int i = 0; i < f->body.size(); i++) {
                collect_locals(f->body[i]);
            }
            break;
        }
        case STMT_IF: {
            IfStatement* s = (IfStatement*)stmt;
            for (int i = 0; i < s->then_branch.size(); i++) {
                collect_locals(s->then_branch[i]);
            }
            for (int i = 0; i < s->else_branch.size(); i++) {
                collect_locals(s->else_branch[i]);
            }
            break;
        }
        case STMT_WHILE: {
            WhileStatement* s = (WhileStatement*)stmt;
            for (int i = 0; i < s->body.size(); i++) {
                collect_locals(s->body[i]);
            }
            break;
        }
        case STMT_DO: {
            DoStatement* s = (DoStatement*)stmt;
            for (int i = 0; i < s->body.size(); i++) {
                collect_locals(s->body[i]);
            }
            break;
        }
        case STMT_OSCILLATE: {
            OscillateStatement* os = (OscillateStatement*)stmt;
            get_or_add_local(os->variable_name, VT_UNKNOWN);
            // Hidden compiler-generated direction variable
            get_or_add_local("__osc_dir_" + os->variable_name.to_lower(), VT_INT);
            if (os->cycles_val) get_or_add_local("__osc_cyc_" + os->variable_name.to_lower(), VT_INT);
            for (int i = 0; i < os->body.size(); i++) {
                collect_locals(os->body[i]);
            }
            break;
        }
        case STMT_REPEAT: {
            RepeatStatement* rp = (RepeatStatement*)stmt;
            // Hidden counter variable (or user-named if "As varname" was used)
            if (!rp->counter_name.is_empty()) {
                get_or_add_local(rp->counter_name, VT_INT);
            }
            get_or_add_local("__repeat_i_" + String::num_int64(temp_local_id), VT_INT);
            get_or_add_local("__repeat_n_" + String::num_int64(temp_local_id), VT_INT);
            for (int i = 0; i < rp->body.size(); i++) {
                collect_locals(rp->body[i]);
            }
            break;
        }
        case STMT_CYCLE: {
            CycleStatement* cy = (CycleStatement*)stmt;
            if (!cy->element_name.is_empty()) {
                get_or_add_local(cy->element_name, VT_UNKNOWN);
            }
            for (int i = 0; i < cy->body.size(); i++) {
                collect_locals(cy->body[i]);
            }
            break;
        }
        case STMT_EVERY: {
            EveryStatement* ev = (EveryStatement*)stmt;
            for (int i = 0; i < ev->body.size(); i++) {
                collect_locals(ev->body[i]);
            }
            break;
        }
        case STMT_TWEEN: {
            // No locals to register — Tween is a single statement
            break;
        }
        case STMT_FOR_EACH: {
            ForEachStatement* s = (ForEachStatement*)stmt;
            for (int i = 0; i < s->body.size(); i++) {
                collect_locals(s->body[i]);
            }
            break;
        }
        default:
            break;
    }
}

// Scan an assignment TARGET expression for variable reads that must count
// toward the local-DCE "used_vars" set. A bare `x = ...` target is a pure
// write and must NOT mark `x` as used (that would defeat DCE entirely).
// But `arr(idx) = ...` / `obj.Field = ...` targets genuinely READ `arr`/
// `idx`/`obj` at runtime — collect_used_vars_stmt's STMT_ASSIGNMENT case
// previously only scanned s->value, never s->target, so a local variable
// used ONLY as an index/base in another assignment's target (e.g.
// `gBuf(addr) = 55` where `addr` is never read anywhere else) was never
// marked used, and the STMT_ASSIGNMENT DCE pass would then silently drop
// `addr = 20` as a "dead store", leaving `addr` at its zero-initialized
// default when the buffer write executed. See _dig1-4.vg repros.
void VisualGasicCompiler::collect_used_vars_assignment_target(ExpressionNode* target) {
    if (!target) return;
    switch (target->type) {
        case ExpressionNode::VARIABLE:
            // Pure write target — not a use.
            break;
        case ExpressionNode::ARRAY_ACCESS: {
            ArrayAccessNode* aa = (ArrayAccessNode*)target;
            collect_used_vars_expr(aa->base);
            for (int i = 0; i < aa->indices.size(); i++) collect_used_vars_expr(aa->indices[i]);
            break;
        }
        case ExpressionNode::MEMBER_ACCESS: {
            MemberAccessNode* ma = (MemberAccessNode*)target;
            if (ma->base_object) collect_used_vars_expr(ma->base_object);
            break;
        }
        default:
            // Unknown/uncommon target shape — be conservative and scan fully.
            collect_used_vars_expr(target);
            break;
    }
}

void VisualGasicCompiler::collect_used_vars_expr(ExpressionNode* expr) {
    if (!expr) return;
    switch (expr->type) {
        case ExpressionNode::VARIABLE: {
            VariableNode* v = (VariableNode*)expr;
            used_vars.insert(v->name.to_lower());
            break;
        }
        case ExpressionNode::BINARY_OP: {
            BinaryOpNode* b = (BinaryOpNode*)expr;
            collect_used_vars_expr(b->left);
            collect_used_vars_expr(b->right);
            break;
        }
        case ExpressionNode::UNARY_OP: {
            UnaryOpNode* u = (UnaryOpNode*)expr;
            collect_used_vars_expr(u->operand);
            break;
        }
        case ExpressionNode::ARRAY_ACCESS: {
            ArrayAccessNode* aa = (ArrayAccessNode*)expr;
            collect_used_vars_expr(aa->base);
            for (int i = 0; i < aa->indices.size(); i++) collect_used_vars_expr(aa->indices[i]);
            break;
        }
        case ExpressionNode::EXPRESSION_CALL: {
            CallExpression* c = (CallExpression*)expr;
            if (c->base_object) collect_used_vars_expr(c->base_object);
            for (int i = 0; i < c->arguments.size(); i++) collect_used_vars_expr(c->arguments[i]);
            break;
        }
        case ExpressionNode::MEMBER_ACCESS: {
            MemberAccessNode* ma = (MemberAccessNode*)expr;
            if (ma->base_object) collect_used_vars_expr(ma->base_object);
            break;
        }
        case ExpressionNode::OPTIONAL_ACCESS: {
            OptionalAccessExpression* oa = (OptionalAccessExpression*)expr;
            if (oa->object_expression) collect_used_vars_expr(oa->object_expression);
            break;
        }
        case ExpressionNode::TYPE_CHECK: {
            TypeCheckExpression* tc = (TypeCheckExpression*)expr;
            if (tc->expression) collect_used_vars_expr(tc->expression);
            break;
        }
        case ExpressionNode::EXPRESSION_IIF: {
            IIfNode* iif = (IIfNode*)expr;
            if (iif->condition) collect_used_vars_expr(iif->condition);
            if (iif->true_part) collect_used_vars_expr(iif->true_part);
            if (iif->false_part) collect_used_vars_expr(iif->false_part);
            break;
        }
        case ExpressionNode::LAMBDA: {
            LambdaNode* lam = (LambdaNode*)expr;
            if (lam->body_expression) collect_used_vars_expr(lam->body_expression);
            for (int i = 0; i < lam->body_statements.size(); i++) {
                collect_used_vars_stmt(lam->body_statements[i]);
            }
            break;
        }
        case ExpressionNode::NEW: {
            NewNode* nn = (NewNode*)expr;
            for (int i = 0; i < nn->args.size(); i++) {
                collect_used_vars_expr(nn->args[i]);
            }
            break;
        }
        default:
            break;
    }
}

void VisualGasicCompiler::collect_vars_in_expr(ExpressionNode* expr, HashSet<String> &out) const {
    if (!expr) return;
    switch (expr->type) {
        case ExpressionNode::VARIABLE: {
            VariableNode* v = (VariableNode*)expr;
            out.insert(v->name.to_lower());
            break;
        }
        case ExpressionNode::BINARY_OP: {
            BinaryOpNode* b = (BinaryOpNode*)expr;
            collect_vars_in_expr(b->left, out);
            collect_vars_in_expr(b->right, out);
            break;
        }
        case ExpressionNode::UNARY_OP: {
            UnaryOpNode* u = (UnaryOpNode*)expr;
            collect_vars_in_expr(u->operand, out);
            break;
        }
        case ExpressionNode::ARRAY_ACCESS: {
            ArrayAccessNode* aa = (ArrayAccessNode*)expr;
            collect_vars_in_expr(aa->base, out);
            for (int i = 0; i < aa->indices.size(); i++) collect_vars_in_expr(aa->indices[i], out);
            break;
        }
        case ExpressionNode::EXPRESSION_CALL: {
            CallExpression* c = (CallExpression*)expr;
            if (c->base_object) collect_vars_in_expr(c->base_object, out);
            for (int i = 0; i < c->arguments.size(); i++) collect_vars_in_expr(c->arguments[i], out);
            break;
        }
        case ExpressionNode::MEMBER_ACCESS: {
            MemberAccessNode* ma = (MemberAccessNode*)expr;
            if (ma->base_object) collect_vars_in_expr(ma->base_object, out);
            break;
        }
        case ExpressionNode::OPTIONAL_ACCESS: {
            OptionalAccessExpression* oa = (OptionalAccessExpression*)expr;
            if (oa->object_expression) collect_vars_in_expr(oa->object_expression, out);
            break;
        }
        case ExpressionNode::TYPE_CHECK: {
            TypeCheckExpression* tc = (TypeCheckExpression*)expr;
            if (tc->expression) collect_vars_in_expr(tc->expression, out);
            break;
        }
        case ExpressionNode::EXPRESSION_IIF: {
            IIfNode* iif = (IIfNode*)expr;
            if (iif->condition) collect_vars_in_expr(iif->condition, out);
            if (iif->true_part) collect_vars_in_expr(iif->true_part, out);
            if (iif->false_part) collect_vars_in_expr(iif->false_part, out);
            break;
        }
        case ExpressionNode::LAMBDA: {
            LambdaNode* lam = (LambdaNode*)expr;
            if (lam->body_expression) collect_vars_in_expr(lam->body_expression, out);
            break;
        }
        case ExpressionNode::NEW: {
            NewNode* nn = (NewNode*)expr;
            for (int i = 0; i < nn->args.size(); i++) {
                collect_vars_in_expr(nn->args[i], out);
            }
            break;
        }
        default:
            break;
    }
}

void VisualGasicCompiler::collect_assigned_vars_stmt(Statement* stmt, HashSet<String> &out) const {
    if (!stmt) return;
    switch (stmt->type) {
        case STMT_ASSIGNMENT: {
            AssignmentStatement* s = (AssignmentStatement*)stmt;
            if (s->target && s->target->type == ExpressionNode::VARIABLE) {
                out.insert(((VariableNode*)s->target)->name.to_lower());
            } else if (s->target && s->target->type == ExpressionNode::ARRAY_ACCESS) {
                ArrayAccessNode* aa = (ArrayAccessNode*)s->target;
                if (aa->base && aa->base->type == ExpressionNode::VARIABLE) {
                    out.insert(((VariableNode*)aa->base)->name.to_lower());
                }
            }
            break;
        }
        case STMT_FOR: {
            ForStatement* f = (ForStatement*)stmt;
            for (int i = 0; i < f->body.size(); i++) collect_assigned_vars_stmt(f->body[i], out);
            break;
        }
        case STMT_IF: {
            IfStatement* s = (IfStatement*)stmt;
            for (int i = 0; i < s->then_branch.size(); i++) collect_assigned_vars_stmt(s->then_branch[i], out);
            for (int i = 0; i < s->else_branch.size(); i++) collect_assigned_vars_stmt(s->else_branch[i], out);
            break;
        }
        case STMT_WHILE: {
            WhileStatement* s = (WhileStatement*)stmt;
            for (int i = 0; i < s->body.size(); i++) collect_assigned_vars_stmt(s->body[i], out);
            break;
        }
        case STMT_DO: {
            DoStatement* s = (DoStatement*)stmt;
            for (int i = 0; i < s->body.size(); i++) collect_assigned_vars_stmt(s->body[i], out);
            break;
        }
        case STMT_OSCILLATE: {
            OscillateStatement* os = (OscillateStatement*)stmt;
            for (int i = 0; i < os->body.size(); i++) collect_assigned_vars_stmt(os->body[i], out);
            break;
        }
        case STMT_REPEAT: {
            RepeatStatement* rp = (RepeatStatement*)stmt;
            for (int i = 0; i < rp->body.size(); i++) collect_assigned_vars_stmt(rp->body[i], out);
            break;
        }
        case STMT_CYCLE: {
            CycleStatement* cy = (CycleStatement*)stmt;
            for (int i = 0; i < cy->body.size(); i++) collect_assigned_vars_stmt(cy->body[i], out);
            break;
        }
        case STMT_EVERY: {
            EveryStatement* ev = (EveryStatement*)stmt;
            for (int i = 0; i < ev->body.size(); i++) collect_assigned_vars_stmt(ev->body[i], out);
            break;
        }
        case STMT_TWEEN: {
            // No assignments in a Tween statement
            break;
        }
        case STMT_FOR_EACH: {
            ForEachStatement* s = (ForEachStatement*)stmt;
            for (int i = 0; i < s->body.size(); i++) collect_assigned_vars_stmt(s->body[i], out);
            break;
        }
        case STMT_SELECT: {
            SelectStatement* s = (SelectStatement*)stmt;
            for (int i = 0; i < s->cases.size(); i++) {
                for (int j = 0; j < s->cases[i]->body.size(); j++) collect_assigned_vars_stmt(s->cases[i]->body[j], out);
            }
            break;
        }
        case STMT_WITH: {
            WithStatement* s = (WithStatement*)stmt;
            for (int i = 0; i < s->body.size(); i++) collect_assigned_vars_stmt(s->body[i], out);
            break;
        }
        case STMT_TRY: {
            TryStatement* s = (TryStatement*)stmt;
            for (int i = 0; i < s->try_block.size(); i++) collect_assigned_vars_stmt(s->try_block[i], out);
            for (int i = 0; i < s->catch_block.size(); i++) collect_assigned_vars_stmt(s->catch_block[i], out);
            for (int i = 0; i < s->finally_block.size(); i++) collect_assigned_vars_stmt(s->finally_block[i], out);
            break;
        }
        case STMT_ERASE: {
            EraseStatement* es = (EraseStatement*)stmt;
            out.insert(es->variable_name.to_lower());
            break;
        }
        case STMT_REDIM: {
            ReDimStatement* rs = (ReDimStatement*)stmt;
            out.insert(rs->variable_name.to_lower());
            break;
        }
        default:
            break;
    }
}

void VisualGasicCompiler::scan_module_for_buffer_vars(ModuleNode* module, HashSet<String>& out) {
    if (!module) return;
    for (int i = 0; i < module->subs.size(); i++) {
        SubDefinition* s = module->subs[i];
        if (!s) continue;
        for (int j = 0; j < s->statements.size(); j++) scan_stmt_for_buffer_vars(s->statements[j], out);
    }
}

void VisualGasicCompiler::scan_stmt_for_buffer_vars(Statement* stmt, HashSet<String>& out) {
    if (!stmt) return;
    switch (stmt->type) {
        case STMT_ASSIGNMENT: {
            AssignmentStatement* s = (AssignmentStatement*)stmt;
            if (s->target && s->target->type == ExpressionNode::VARIABLE && s->value && s->value->type == ExpressionNode::NEW) {
                NewNode* n = (NewNode*)s->value;
                if (n->class_name.nocasecmp_to("MemoryBuffer") == 0 || n->class_name.nocasecmp_to("Buffer") == 0) {
                    out.insert(((VariableNode*)s->target)->name.to_lower());
                }
            }
            break;
        }
        case STMT_IF: {
            IfStatement* s = (IfStatement*)stmt;
            for (int i = 0; i < s->then_branch.size(); i++) scan_stmt_for_buffer_vars(s->then_branch[i], out);
            for (int i = 0; i < s->else_branch.size(); i++) scan_stmt_for_buffer_vars(s->else_branch[i], out);
            break;
        }
        case STMT_FOR: {
            ForStatement* f = (ForStatement*)stmt;
            for (int i = 0; i < f->body.size(); i++) scan_stmt_for_buffer_vars(f->body[i], out);
            break;
        }
        case STMT_FOR_EACH: {
            ForEachStatement* f = (ForEachStatement*)stmt;
            for (int i = 0; i < f->body.size(); i++) scan_stmt_for_buffer_vars(f->body[i], out);
            break;
        }
        case STMT_WHILE: {
            WhileStatement* s = (WhileStatement*)stmt;
            for (int i = 0; i < s->body.size(); i++) scan_stmt_for_buffer_vars(s->body[i], out);
            break;
        }
        case STMT_DO: {
            DoStatement* s = (DoStatement*)stmt;
            for (int i = 0; i < s->body.size(); i++) scan_stmt_for_buffer_vars(s->body[i], out);
            break;
        }
        case STMT_WITH: {
            WithStatement* s = (WithStatement*)stmt;
            for (int i = 0; i < s->body.size(); i++) scan_stmt_for_buffer_vars(s->body[i], out);
            break;
        }
        case STMT_SELECT: {
            SelectStatement* s = (SelectStatement*)stmt;
            for (int i = 0; i < s->cases.size(); i++) {
                CaseBlock* cb = s->cases[i];
                for (int j = 0; j < cb->body.size(); j++) scan_stmt_for_buffer_vars(cb->body[j], out);
            }
            break;
        }
        default:
            break;
    }
}

void VisualGasicCompiler::collect_used_vars_stmt(Statement* stmt) {
    if (!stmt) return;
    switch (stmt->type) {
        case STMT_DIM: {
            DimStatement* s = (DimStatement*)stmt;
            if (s->initializer) collect_used_vars_expr(s->initializer);
            for (int i = 0; i < s->array_sizes.size(); i++) collect_used_vars_expr(s->array_sizes[i]);
            break;
        }
        case STMT_ASSIGNMENT: {
            AssignmentStatement* s = (AssignmentStatement*)stmt;
            collect_used_vars_expr(s->value);
            collect_used_vars_assignment_target(s->target);
            break;
        }
        case STMT_IF: {
            IfStatement* s = (IfStatement*)stmt;
            collect_used_vars_expr(s->condition);
            for (int i = 0; i < s->then_branch.size(); i++) collect_used_vars_stmt(s->then_branch[i]);
            for (int i = 0; i < s->else_branch.size(); i++) collect_used_vars_stmt(s->else_branch[i]);
            break;
        }
        case STMT_FOR: {
            ForStatement* f = (ForStatement*)stmt;
            collect_used_vars_expr(f->from_val);
            collect_used_vars_expr(f->to_val);
            collect_used_vars_expr(f->step_val);
            for (int i = 0; i < f->body.size(); i++) collect_used_vars_stmt(f->body[i]);
            break;
        }
        case STMT_WHILE: {
            WhileStatement* s = (WhileStatement*)stmt;
            collect_used_vars_expr(s->condition);
            for (int i = 0; i < s->body.size(); i++) collect_used_vars_stmt(s->body[i]);
            break;
        }
        case STMT_DO: {
            DoStatement* s = (DoStatement*)stmt;
            collect_used_vars_expr(s->condition);
            for (int i = 0; i < s->body.size(); i++) collect_used_vars_stmt(s->body[i]);
            break;
        }
        case STMT_OSCILLATE: {
            OscillateStatement* os = (OscillateStatement*)stmt;
            collect_used_vars_expr(os->from_val);
            collect_used_vars_expr(os->to_val);
            collect_used_vars_expr(os->step_val);
            if (os->cycles_val) collect_used_vars_expr(os->cycles_val);
            for (int i = 0; i < os->body.size(); i++) collect_used_vars_stmt(os->body[i]);
            break;
        }
        case STMT_REPEAT: {
            RepeatStatement* rp = (RepeatStatement*)stmt;
            collect_used_vars_expr(rp->count_val);
            for (int i = 0; i < rp->body.size(); i++) collect_used_vars_stmt(rp->body[i]);
            break;
        }
        case STMT_CYCLE: {
            CycleStatement* cy = (CycleStatement*)stmt;
            collect_used_vars_expr(cy->collection);
            collect_used_vars_expr(cy->count_val);
            for (int i = 0; i < cy->body.size(); i++) collect_used_vars_stmt(cy->body[i]);
            break;
        }
        case STMT_EVERY: {
            EveryStatement* ev = (EveryStatement*)stmt;
            collect_used_vars_expr(ev->interval_val);
            for (int i = 0; i < ev->body.size(); i++) collect_used_vars_stmt(ev->body[i]);
            break;
        }
        case STMT_TWEEN: {
            TweenStatement* tw = (TweenStatement*)stmt;
            collect_used_vars_expr(tw->target_node);
            if (tw->from_val) collect_used_vars_expr(tw->from_val);
            collect_used_vars_expr(tw->to_val);
            collect_used_vars_expr(tw->duration);
            break;
        }
        case STMT_PRINT: {
            PrintStatement* s = (PrintStatement*)stmt;
            collect_used_vars_expr(s->expression);
            break;
        }
        case STMT_SELECT: {
            SelectStatement* s = (SelectStatement*)stmt;
            collect_used_vars_expr(s->expression);
            for (int i = 0; i < s->cases.size(); i++) {
                CaseBlock* cb = s->cases[i];
                for (int v = 0; v < cb->values.size(); v++) {
                    collect_used_vars_expr(cb->values[v]);
                    if (v < cb->range_ends.size() && cb->range_ends[v]) {
                        collect_used_vars_expr(cb->range_ends[v]);
                    }
                }
                for (int j = 0; j < cb->body.size(); j++) {
                    collect_used_vars_stmt(cb->body[j]);
                }
            }
            break;
        }
        case STMT_FOR_EACH: {
            ForEachStatement* s = (ForEachStatement*)stmt;
            collect_used_vars_expr(s->collection);
            for (int i = 0; i < s->body.size(); i++) {
                collect_used_vars_stmt(s->body[i]);
            }
            break;
        }
        case STMT_CALL: {
            CallStatement* s = (CallStatement*)stmt;
            if (s->base_object) collect_used_vars_expr(s->base_object);
            for (int i = 0; i < s->arguments.size(); i++) {
                collect_used_vars_expr(s->arguments[i]);
            }
            break;
        }
        case STMT_WITH: {
            WithStatement* s = (WithStatement*)stmt;
            collect_used_vars_expr(s->expression);
            for (int i = 0; i < s->body.size(); i++) {
                collect_used_vars_stmt(s->body[i]);
            }
            break;
        }
        case STMT_TRY: {
            TryStatement* s = (TryStatement*)stmt;
            for (int i = 0; i < s->try_block.size(); i++) collect_used_vars_stmt(s->try_block[i]);
            for (int i = 0; i < s->catch_block.size(); i++) collect_used_vars_stmt(s->catch_block[i]);
            for (int i = 0; i < s->finally_block.size(); i++) collect_used_vars_stmt(s->finally_block[i]);
            break;
        }
        case STMT_RAISE: {
            RaiseStatement* s = (RaiseStatement*)stmt;
            if (s->code) collect_used_vars_expr(s->code);
            if (s->msg) collect_used_vars_expr(s->msg);
            break;
        }
        case STMT_ERASE: {
            EraseStatement* es = (EraseStatement*)stmt;
            used_vars.insert(es->variable_name.to_lower());
            break;
        }
        case STMT_REDIM: {
            ReDimStatement* rs = (ReDimStatement*)stmt;
            // The array being resized is used (read if preserve, always written)
            if (rs->preserve) {
                used_vars.insert(rs->variable_name.to_lower());
            }
            for (int i = 0; i < rs->array_sizes.size(); i++) {
                collect_used_vars_expr(rs->array_sizes[i]);
            }
            break;
        }
        default:
            break;
    }
}

bool VisualGasicCompiler::is_pure_expr(ExpressionNode* expr) const {
    if (!expr) return true;
    switch (expr->type) {
        case ExpressionNode::LITERAL:
        case ExpressionNode::VARIABLE:
            return true;
        case ExpressionNode::UNARY_OP: {
            UnaryOpNode* u = (UnaryOpNode*)expr;
            return is_pure_expr(u->operand);
        }
        case ExpressionNode::BINARY_OP: {
            BinaryOpNode* b = (BinaryOpNode*)expr;
            return is_pure_expr(b->left) && is_pure_expr(b->right);
        }
        case ExpressionNode::ARRAY_ACCESS: {
            ArrayAccessNode* aa = (ArrayAccessNode*)expr;
            if (!is_pure_expr(aa->base)) return false;
            for (int i = 0; i < aa->indices.size(); i++) if (!is_pure_expr(aa->indices[i])) return false;
            return true;
        }
        default:
            return false;
    }
}

bool VisualGasicCompiler::is_fast_array_var(const String &name) const {
    String key = name.to_lower();
    if (!array_vars.has(key)) {
        return false;
    }
    return !dictionary_vars.has(key);
}

bool VisualGasicCompiler::is_dictionary_var(const String &name) const {
    return dictionary_vars.has(name.to_lower());
}

bool VisualGasicCompiler::is_trusted_dictionary_var(const String &name) const {
    return trusted_dictionary_vars.has(name.to_lower());
}

bool VisualGasicCompiler::is_sole_owner_dict_var(const String &name) const {
    return sole_owner_dict_vars.has(name.to_lower());
}

bool VisualGasicCompiler::is_buffer_var(const String &name) const {
    return buffer_vars.has(name.to_lower());
}

// ── Sole-ownership escape analysis helpers ──────────────────────────
// If a dictionary variable appears in any "escaping" context, add it to
// `escaped` so we fall back to Godot Dictionary (safe but slower).

void VisualGasicCompiler::_check_expr_escapes(ExpressionNode* expr, HashSet<String> &escaped) const {
    if (!expr) return;
    switch (expr->type) {
        case ExpressionNode::VARIABLE:
            break;  // Just reading a dict doesn't escape it
        case ExpressionNode::BINARY_OP: {
            BinaryOpNode* b = (BinaryOpNode*)expr;
            _check_expr_escapes(b->left, escaped);
            _check_expr_escapes(b->right, escaped);
            break;
        }
        case ExpressionNode::UNARY_OP: {
            UnaryOpNode* u = (UnaryOpNode*)expr;
            _check_expr_escapes(u->operand, escaped);
            break;
        }
        case ExpressionNode::ARRAY_ACCESS: {
            ArrayAccessNode* aa = (ArrayAccessNode*)expr;
            // dict(key) is a read — base doesn't escape
            for (int i = 0; i < aa->indices.size(); i++)
                _check_expr_escapes(aa->indices[i], escaped);
            break;
        }
        case ExpressionNode::EXPRESSION_CALL: {
            CallExpression* c = (CallExpression*)expr;
            // Method call on a dict var (e.g. ages.Count()) requires a real Dictionary
            if (c->base_object && c->base_object->type == ExpressionNode::VARIABLE) {
                String name = ((VariableNode*)c->base_object)->name.to_lower();
                if (sole_owner_dict_vars.has(name)) {
                    escaped.insert(name);
                }
            }
            // If any dict var is passed as an argument to a call, it escapes
            for (int i = 0; i < c->arguments.size(); i++) {
                ExpressionNode* arg = c->arguments[i];
                if (arg && arg->type == ExpressionNode::VARIABLE) {
                    String name = ((VariableNode*)arg)->name.to_lower();
                    if (sole_owner_dict_vars.has(name)) {
                        escaped.insert(name);
                    }
                }
                _check_expr_escapes(arg, escaped);
            }
            break;
        }
        case ExpressionNode::OPTIONAL_ACCESS: {
            // Optional?.Access uses OP_GET_MEMBER which needs a real Dictionary,
            // not a VGDict integer ID. Mark the base variable as escaping.
            OptionalAccessExpression* oa = (OptionalAccessExpression*)expr;
            if (oa->object_expression && oa->object_expression->type == ExpressionNode::VARIABLE) {
                String name = ((VariableNode*)oa->object_expression)->name.to_lower();
                if (sole_owner_dict_vars.has(name)) {
                    escaped.insert(name);
                }
            }
            if (oa->object_expression) _check_expr_escapes(oa->object_expression, escaped);
            break;
        }
        case ExpressionNode::MEMBER_ACCESS: {
            // Member access also uses OP_GET_MEMBER — mark base as escaping
            MemberAccessNode* ma = (MemberAccessNode*)expr;
            if (ma->base_object && ma->base_object->type == ExpressionNode::VARIABLE) {
                String name = ((VariableNode*)ma->base_object)->name.to_lower();
                if (sole_owner_dict_vars.has(name)) {
                    escaped.insert(name);
                }
            }
            if (ma->base_object) _check_expr_escapes(ma->base_object, escaped);
            break;
        }
        default:
            break;
    }
}

void VisualGasicCompiler::_check_dict_escapes(Statement* stmt, HashSet<String> &escaped) const {
    if (!stmt) return;
    switch (stmt->type) {
        case STMT_ASSIGNMENT: {
            AssignmentStatement* s = (AssignmentStatement*)stmt;
            // If a sole_owner_dict variable itself is reassigned from an external
            // source (e.g. Set o = Objects(id)), the VGDict optimisation is invalid
            // because the variable now points to an existing Godot Dictionary,
            // not the compiler-created VGDict fast-dict.
            if (s->target && s->target->type == ExpressionNode::VARIABLE) {
                String lhs = ((VariableNode*)s->target)->name.to_lower();
                if (sole_owner_dict_vars.has(lhs)) {
                    // Keep sole-ownership for two safe RHS shapes:
                    //   (1) self-assignment: `Set dict = dict`
                    //   (2) fresh empty dictionary: `Set dict = New Dictionary`
                    //       (no args → no aliasing — emits OP_NEW_VGDICT and is
                    //       the canonical pattern paired with `Dim dict As Dictionary`).
                    bool safe_rhs = false;
                    if (s->value && s->value->type == ExpressionNode::VARIABLE) {
                        String rhs = ((VariableNode*)s->value)->name.to_lower();
                        if (rhs == lhs) safe_rhs = true;
                    } else if (s->value && s->value->type == ExpressionNode::NEW) {
                        NewNode *nn = (NewNode *)s->value;
                        if (nn->class_name.nocasecmp_to("Dictionary") == 0 && nn->args.size() == 0) {
                            safe_rhs = true;
                        }
                    }
                    if (!safe_rhs) {
                        escaped.insert(lhs);
                    }
                }
            }
            // If dict is assigned TO a different variable: dict escapes
            if (s->value && s->value->type == ExpressionNode::VARIABLE) {
                String rhs = ((VariableNode*)s->value)->name.to_lower();
                if (sole_owner_dict_vars.has(rhs) && s->target) {
                    // Unless it's assigning to itself (dict = dict), it's aliased
                    if (s->target->type == ExpressionNode::VARIABLE) {
                        String lhs = ((VariableNode*)s->target)->name.to_lower();
                        if (lhs != rhs) {
                            escaped.insert(rhs);
                        }
                    } else {
                        escaped.insert(rhs);
                    }
                }
            }
            _check_expr_escapes(s->value, escaped);
            _check_expr_escapes(s->target, escaped);
            break;
        }
        case STMT_PRINT: {
            PrintStatement* s = (PrintStatement*)stmt;
            _check_expr_escapes(s->expression, escaped);
            break;
        }
        case STMT_FOR: {
            ForStatement* f = (ForStatement*)stmt;
            _check_expr_escapes(f->from_val, escaped);
            _check_expr_escapes(f->to_val, escaped);
            _check_expr_escapes(f->step_val, escaped);
            for (int i = 0; i < f->body.size(); i++) _check_dict_escapes(f->body[i], escaped);
            break;
        }
        case STMT_IF: {
            IfStatement* s = (IfStatement*)stmt;
            _check_expr_escapes(s->condition, escaped);
            for (int i = 0; i < s->then_branch.size(); i++) _check_dict_escapes(s->then_branch[i], escaped);
            for (int i = 0; i < s->else_branch.size(); i++) _check_dict_escapes(s->else_branch[i], escaped);
            break;
        }
        case STMT_WHILE: {
            WhileStatement* s = (WhileStatement*)stmt;
            _check_expr_escapes(s->condition, escaped);
            for (int i = 0; i < s->body.size(); i++) _check_dict_escapes(s->body[i], escaped);
            break;
        }
        case STMT_DO: {
            DoStatement* s = (DoStatement*)stmt;
            _check_expr_escapes(s->condition, escaped);
            for (int i = 0; i < s->body.size(); i++) _check_dict_escapes(s->body[i], escaped);
            break;
        }
        case STMT_OSCILLATE: {
            OscillateStatement* os = (OscillateStatement*)stmt;
            _check_expr_escapes(os->from_val, escaped);
            _check_expr_escapes(os->to_val, escaped);
            _check_expr_escapes(os->step_val, escaped);
            if (os->cycles_val) _check_expr_escapes(os->cycles_val, escaped);
            for (int i = 0; i < os->body.size(); i++) _check_dict_escapes(os->body[i], escaped);
            break;
        }
        case STMT_REPEAT: {
            RepeatStatement* rp = (RepeatStatement*)stmt;
            _check_expr_escapes(rp->count_val, escaped);
            for (int i = 0; i < rp->body.size(); i++) _check_dict_escapes(rp->body[i], escaped);
            break;
        }
        case STMT_CYCLE: {
            CycleStatement* cy = (CycleStatement*)stmt;
            _check_expr_escapes(cy->collection, escaped);
            _check_expr_escapes(cy->count_val, escaped);
            for (int i = 0; i < cy->body.size(); i++) _check_dict_escapes(cy->body[i], escaped);
            break;
        }
        case STMT_EVERY: {
            EveryStatement* ev = (EveryStatement*)stmt;
            _check_expr_escapes(ev->interval_val, escaped);
            for (int i = 0; i < ev->body.size(); i++) _check_dict_escapes(ev->body[i], escaped);
            break;
        }
        case STMT_TWEEN: {
            TweenStatement* tw = (TweenStatement*)stmt;
            _check_expr_escapes(tw->target_node, escaped);
            if (tw->from_val) _check_expr_escapes(tw->from_val, escaped);
            _check_expr_escapes(tw->to_val, escaped);
            _check_expr_escapes(tw->duration, escaped);
            break;
        }
        case STMT_FOR_EACH: {
            ForEachStatement* s = (ForEachStatement*)stmt;
            for (int i = 0; i < s->body.size(); i++) _check_dict_escapes(s->body[i], escaped);
            break;
        }
        case STMT_DIM: {
            DimStatement* s = (DimStatement*)stmt;
            if (s->initializer) {
                // Non-New initializer means the variable receives an existing object —
                // not a sole-owner dict, so the VGDict optimisation must not apply.
                bool is_new_dict = false;
                if (s->initializer->type == ExpressionNode::NEW) {
                    NewNode* nn = (NewNode*)s->initializer;
                    if (nn->class_name.nocasecmp_to("Dictionary") == 0 && nn->args.size() == 0) {
                        is_new_dict = true;
                    }
                }
                if (!is_new_dict) {
                    String name = s->variable_name.to_lower();
                    if (sole_owner_dict_vars.has(name)) {
                        escaped.insert(name);
                    }
                }
                _check_expr_escapes(s->initializer, escaped);
            }
            break;
        }
        case STMT_CALL: {
            CallStatement* s = (CallStatement*)stmt;
            // Method call on a dict var requires a real Dictionary object (not VGDict slot)
            if (s->base_object && s->base_object->type == ExpressionNode::VARIABLE) {
                String name = ((VariableNode*)s->base_object)->name.to_lower();
                if (sole_owner_dict_vars.has(name)) {
                    escaped.insert(name);
                }
            }
            // If a dict var is passed as argument, it escapes
            for (int i = 0; i < s->arguments.size(); i++) {
                ExpressionNode* arg = s->arguments[i];
                if (arg && arg->type == ExpressionNode::VARIABLE) {
                    String name = ((VariableNode*)arg)->name.to_lower();
                    if (sole_owner_dict_vars.has(name)) {
                        escaped.insert(name);
                    }
                }
                _check_expr_escapes(arg, escaped);
            }
            break;
        }
        default:
            break;
    }
}

String VisualGasicCompiler::extract_bound_var(ExpressionNode* expr) const {
    if (!expr || expr->type != ExpressionNode::BINARY_OP) return "";
    BinaryOpNode* b = (BinaryOpNode*)expr;
    if (b->op != "-") return "";
    if (b->left->type != ExpressionNode::VARIABLE) return "";
    if (b->right->type != ExpressionNode::LITERAL) return "";
    LiteralNode* l = (LiteralNode*)b->right;
    bool matches_one = false;
    if (l->value.get_type() == Variant::INT) {
        matches_one = ((int64_t)l->value == 1);
    } else if (l->value.get_type() == Variant::FLOAT) {
        matches_one = Math::is_equal_approx((double)l->value, 1.0);
    }
    if (matches_one) {
        return ((VariableNode*)b->left)->name;
    }
    return "";
}

bool VisualGasicCompiler::is_loop_string_concat(ForStatement* f, String &target_name, String &literal_value) const {
    if (!f || f->body.size() != 1) return false;
    Statement* s0 = f->body[0];
    if (s0->type != STMT_ASSIGNMENT) return false;
    AssignmentStatement* s = (AssignmentStatement*)s0;
    if (!s->target || !s->value) return false;
    if (s->target->type != ExpressionNode::VARIABLE) return false;
    VariableNode* v = (VariableNode*)s->target;
    if (s->value->type != ExpressionNode::BINARY_OP) return false;
    BinaryOpNode* b = (BinaryOpNode*)s->value;
    if (b->op != "&" && b->op != "+") return false;
    if (b->left->type != ExpressionNode::VARIABLE) return false;
    if (((VariableNode*)b->left)->name.to_lower() != v->name.to_lower()) return false;
    if (b->right->type != ExpressionNode::LITERAL) return false;
    LiteralNode* l = (LiteralNode*)b->right;
    if (l->value.get_type() != Variant::STRING) return false;
    // from 0, step 1
    if (!f->from_val || f->from_val->type != ExpressionNode::LITERAL) return false;
    LiteralNode* fl = (LiteralNode*)f->from_val;
    if (!((fl->value.get_type() == Variant::INT && (int64_t)fl->value == 0) ||
          (fl->value.get_type() == Variant::BOOL && ((bool)fl->value ? 1 : 0) == 0) ||
          (fl->value.get_type() == Variant::FLOAT && (double)fl->value == 0.0))) return false;
    if (f->step_val) {
        if (f->step_val->type != ExpressionNode::LITERAL) return false;
        LiteralNode* sl = (LiteralNode*)f->step_val;
        if (!((sl->value.get_type() == Variant::INT && (int64_t)sl->value == 1) ||
              (sl->value.get_type() == Variant::BOOL && ((bool)sl->value ? 1 : 0) == 1) ||
              (sl->value.get_type() == Variant::FLOAT && (double)sl->value == 1.0))) return false;
    }
    target_name = v->name;
    literal_value = String(l->value);
    return true;
}

bool VisualGasicCompiler::is_loop_array_fill(ForStatement* f, String &arr_var) const {
    if (!f || f->body.size() != 1) return false;
    if (!f->from_val || f->from_val->type != ExpressionNode::LITERAL) return false;
    LiteralNode* fl = (LiteralNode*)f->from_val;
    if (!((fl->value.get_type() == Variant::INT && (int64_t)fl->value == 0) ||
          (fl->value.get_type() == Variant::BOOL && ((bool)fl->value ? 1 : 0) == 0) ||
          (fl->value.get_type() == Variant::FLOAT && (double)fl->value == 0.0))) return false;
    if (f->step_val) {
        if (f->step_val->type != ExpressionNode::LITERAL) return false;
        LiteralNode* sl = (LiteralNode*)f->step_val;
        if (!((sl->value.get_type() == Variant::INT && (int64_t)sl->value == 1) ||
              (sl->value.get_type() == Variant::BOOL && ((bool)sl->value ? 1 : 0) == 1) ||
              (sl->value.get_type() == Variant::FLOAT && (double)sl->value == 1.0))) return false;
    }

    Statement* s0 = f->body[0];
    if (s0->type != STMT_ASSIGNMENT) return false;
    AssignmentStatement* as = (AssignmentStatement*)s0;
    if (!as->target || !as->value) return false;
    String arr_name;
    String idx_var;
    if (as->target->type == ExpressionNode::ARRAY_ACCESS) {
        ArrayAccessNode* aa = (ArrayAccessNode*)as->target;
        if (!aa->base || aa->base->type != ExpressionNode::VARIABLE) return false;
        if (aa->indices.size() != 1 || aa->indices[0]->type != ExpressionNode::VARIABLE) return false;
        arr_name = ((VariableNode*)aa->base)->name;
        idx_var = ((VariableNode*)aa->indices[0])->name.to_lower();
    } else if (as->target->type == ExpressionNode::EXPRESSION_CALL) {
        CallExpression* call = (CallExpression*)as->target;
        if (call->base_object) return false;
        if (call->arguments.size() != 1 || call->arguments[0]->type != ExpressionNode::VARIABLE) return false;
        arr_name = call->method_name;
        idx_var = ((VariableNode*)call->arguments[0])->name.to_lower();
    } else {
        return false;
    }
    if (idx_var != f->variable_name.to_lower()) return false;

    if (as->value->type != ExpressionNode::VARIABLE) return false;
    String rhs_var = ((VariableNode*)as->value)->name.to_lower();
    if (rhs_var != f->variable_name.to_lower()) return false;

    String arr_key = arr_name.to_lower();
    if (array_types.has(arr_key) && array_types[arr_key] == VT_FLOAT) return false;

    arr_var = arr_name;
    return true;
}

bool VisualGasicCompiler::is_allocations_loop(ForStatement* f, String &sum_var, String &arr_var, String &tmp_var, String &literal_value, String &iter_var, String &size_var) const {
    // Match the pattern:
    //   For iter = 0 To iterations - 1 Step 1
    //       ReDim arr(size - 1)
    //       text = ""
    //       For i = 0 To size - 1 Step 1
    //           arr(i) = iter + i
    //           text = text & "x"
    //           sum = sum + arr(i)
    //       Next i
    //       sum = sum + Len(text)
    //   Next iter
    if (!f) return false;
    if (!f->from_val || f->from_val->type != ExpressionNode::LITERAL) return false;
    LiteralNode* fl = (LiteralNode*)f->from_val;
    if (!((fl->value.get_type() == Variant::INT && (int64_t)fl->value == 0) ||
          (fl->value.get_type() == Variant::BOOL && ((bool)fl->value ? 1 : 0) == 0) ||
          (fl->value.get_type() == Variant::FLOAT && (double)fl->value == 0.0))) return false;
    if (f->step_val) {
        if (f->step_val->type != ExpressionNode::LITERAL) return false;
        LiteralNode* sl = (LiteralNode*)f->step_val;
        if (!((sl->value.get_type() == Variant::INT && (int64_t)sl->value == 1) ||
              (sl->value.get_type() == Variant::BOOL && ((bool)sl->value ? 1 : 0) == 1) ||
              (sl->value.get_type() == Variant::FLOAT && (double)sl->value == 1.0))) return false;
    }
    iter_var = extract_bound_var(f->to_val);
    if (iter_var.is_empty()) {
        HashSet<String> iter_vars;
        collect_vars_in_expr(f->to_val, iter_vars);
        if (iter_vars.size() == 1) {
            for (const String &v : iter_vars) { iter_var = v; break; }
        }
    }
    if (iter_var.is_empty()) return false;

    // Outer body must have at least 4 statements: ReDim, text="", inner For, sum += Len(text)
    if (f->body.size() < 4) return false;

    // Find ReDim statement
    int idx = 0;
    Statement* s_redim = nullptr;
    while (idx < f->body.size()) { s_redim = f->body[idx++]; if (s_redim && s_redim->type == STMT_REDIM) break; }
    if (!s_redim || s_redim->type != STMT_REDIM) return false;
    ReDimStatement* rd = (ReDimStatement*)s_redim;
    if (rd->preserve || rd->array_sizes.size() != 1) return false;

    // Find text = "" assignment
    Statement* s_text_init = nullptr;
    while (idx < f->body.size()) { s_text_init = f->body[idx++]; if (s_text_init && s_text_init->type == STMT_ASSIGNMENT) break; }
    if (!s_text_init || s_text_init->type != STMT_ASSIGNMENT) return false;
    AssignmentStatement* text_init = (AssignmentStatement*)s_text_init;
    if (!text_init->target || text_init->target->type != ExpressionNode::VARIABLE) return false;
    if (!text_init->value || text_init->value->type != ExpressionNode::LITERAL) return false;
    LiteralNode* text_init_lit = (LiteralNode*)text_init->value;
    if (text_init_lit->value.get_type() != Variant::STRING) return false;
    if (String(text_init_lit->value) != "") return false;
    String text_var_name = ((VariableNode*)text_init->target)->name;

    // Find inner For loop
    Statement* s_inner = nullptr;
    while (idx < f->body.size()) { s_inner = f->body[idx++]; if (s_inner && s_inner->type == STMT_FOR) break; }
    if (!s_inner || s_inner->type != STMT_FOR) return false;
    ForStatement* inner = (ForStatement*)s_inner;

    // Inner loop must have 3 statements: arr(i)=iter+i, text=text&"x", sum=sum+arr(i)
    if (inner->body.size() != 3) return false;

    // Verify inner loop starts at 0, step 1
    if (!inner->from_val || inner->from_val->type != ExpressionNode::LITERAL) return false;
    LiteralNode* inner_from = (LiteralNode*)inner->from_val;
    if (!((inner_from->value.get_type() == Variant::INT && (int64_t)inner_from->value == 0) ||
          (inner_from->value.get_type() == Variant::BOOL && ((bool)inner_from->value ? 1 : 0) == 0) ||
          (inner_from->value.get_type() == Variant::FLOAT && (double)inner_from->value == 0.0))) return false;
    if (inner->step_val) {
        if (inner->step_val->type != ExpressionNode::LITERAL) return false;
        LiteralNode* inner_step = (LiteralNode*)inner->step_val;
        if (!((inner_step->value.get_type() == Variant::INT && (int64_t)inner_step->value == 1) ||
              (inner_step->value.get_type() == Variant::BOOL && ((bool)inner_step->value ? 1 : 0) == 1) ||
              (inner_step->value.get_type() == Variant::FLOAT && (double)inner_step->value == 1.0))) return false;
    }

    // s_inner_0: arr(i) = iter + i  (array assignment with binary expression)
    Statement* s_arr = inner->body[0];
    if (!s_arr || s_arr->type != STMT_ASSIGNMENT) return false;
    AssignmentStatement* arr_assign = (AssignmentStatement*)s_arr;
    // Target is arr(i) — either ARRAY_ACCESS or EXPRESSION_CALL
    String arr_name;
    if (arr_assign->target && arr_assign->target->type == ExpressionNode::ARRAY_ACCESS) {
        ArrayAccessNode* aa = (ArrayAccessNode*)arr_assign->target;
        if (!aa->base || aa->base->type != ExpressionNode::VARIABLE) return false;
        arr_name = ((VariableNode*)aa->base)->name;
    } else if (arr_assign->target && arr_assign->target->type == ExpressionNode::EXPRESSION_CALL) {
        CallExpression* call = (CallExpression*)arr_assign->target;
        if (call->base_object) return false;
        arr_name = call->method_name;
    } else {
        return false;
    }
    // Verify arr matches ReDim variable
    if (arr_name.nocasecmp_to(rd->variable_name) != 0) return false;

    // s_inner_1: text = text & "x"
    Statement* s_text = inner->body[1];
    if (!s_text || s_text->type != STMT_ASSIGNMENT) return false;
    AssignmentStatement* text_assign = (AssignmentStatement*)s_text;
    if (!text_assign->target || text_assign->target->type != ExpressionNode::VARIABLE) return false;
    if (((VariableNode*)text_assign->target)->name.nocasecmp_to(text_var_name) != 0) return false;
    if (!text_assign->value || text_assign->value->type != ExpressionNode::BINARY_OP) return false;
    BinaryOpNode* text_concat = (BinaryOpNode*)text_assign->value;
    if (text_concat->op != "&" && text_concat->op != "+") return false;
    if (!text_concat->left || text_concat->left->type != ExpressionNode::VARIABLE) return false;
    if (((VariableNode*)text_concat->left)->name.nocasecmp_to(text_var_name) != 0) return false;
    if (!text_concat->right || text_concat->right->type != ExpressionNode::LITERAL) return false;
    LiteralNode* concat_lit = (LiteralNode*)text_concat->right;
    if (concat_lit->value.get_type() != Variant::STRING) return false;

    // s_inner_2: sum = sum + arr(i)
    Statement* s_sum = inner->body[2];
    if (!s_sum || s_sum->type != STMT_ASSIGNMENT) return false;
    AssignmentStatement* sum_assign = (AssignmentStatement*)s_sum;
    if (!sum_assign->target || sum_assign->target->type != ExpressionNode::VARIABLE) return false;
    if (!sum_assign->value || sum_assign->value->type != ExpressionNode::BINARY_OP) return false;
    VariableNode* sum_target = (VariableNode*)sum_assign->target;
    BinaryOpNode* sum_add = (BinaryOpNode*)sum_assign->value;
    if (sum_add->op != "+") return false;
    if (!sum_add->left || sum_add->left->type != ExpressionNode::VARIABLE) return false;
    if (((VariableNode*)sum_add->left)->name.nocasecmp_to(sum_target->name) != 0) return false;

    // Find sum = sum + Len(text) after inner loop
    Statement* s_sum_len = nullptr;
    while (idx < f->body.size()) { s_sum_len = f->body[idx++]; if (s_sum_len && s_sum_len->type == STMT_ASSIGNMENT) break; }
    if (!s_sum_len || s_sum_len->type != STMT_ASSIGNMENT) return false;
    AssignmentStatement* sum_len = (AssignmentStatement*)s_sum_len;
    if (!sum_len->target || sum_len->target->type != ExpressionNode::VARIABLE) return false;
    if (((VariableNode*)sum_len->target)->name.nocasecmp_to(sum_target->name) != 0) return false;
    if (!sum_len->value || sum_len->value->type != ExpressionNode::BINARY_OP) return false;
    BinaryOpNode* sum_len_add = (BinaryOpNode*)sum_len->value;
    if (sum_len_add->op != "+") return false;
    if (!sum_len_add->left || sum_len_add->left->type != ExpressionNode::VARIABLE) return false;
    if (((VariableNode*)sum_len_add->left)->name.nocasecmp_to(sum_target->name) != 0) return false;
    // RHS should be Len(text)
    if (!sum_len_add->right || sum_len_add->right->type != ExpressionNode::EXPRESSION_CALL) return false;
    CallExpression* len_call = (CallExpression*)sum_len_add->right;
    if (len_call->base_object) return false;
    if (len_call->method_name.nocasecmp_to("Len") != 0) return false;
    if (len_call->arguments.size() != 1) return false;
    if (!len_call->arguments[0] || len_call->arguments[0]->type != ExpressionNode::VARIABLE) return false;
    if (((VariableNode*)len_call->arguments[0])->name.nocasecmp_to(text_var_name) != 0) return false;

    // Extract size variable from inner loop bound
    size_var = extract_bound_var(inner->to_val);
    if (size_var.is_empty()) {
        HashSet<String> sz_vars;
        collect_vars_in_expr(inner->to_val, sz_vars);
        if (sz_vars.size() == 1) {
            for (const String &v : sz_vars) { size_var = v; break; }
        }
    }
    if (size_var.is_empty()) return false;

    // Verify ReDim uses the same size variable
    HashSet<String> rd_vars;
    collect_vars_in_expr(rd->array_sizes[0], rd_vars);
    if (!rd_vars.has(size_var.to_lower())) return false;

    sum_var = sum_target->name;
    arr_var = arr_name;
    tmp_var = text_var_name;
    literal_value = String(concat_lit->value);
    return true;
}

bool VisualGasicCompiler::is_interop_loop(ForStatement* outer, String &sum_var, String &literal_value, ForStatement* &inner_out) const {
    if (!outer || outer->body.size() != 1) return false;
    Statement* inner_stmt = outer->body[0];
    if (!inner_stmt || inner_stmt->type != STMT_FOR) return false;
    ForStatement* inner = (ForStatement*)inner_stmt;

    // Support both 2-statement and 3-statement inner body patterns
    // Pattern A (2 stmts): node.Name = prefix & CStr(j) ; checksum = checksum + Len(node.Name)
    // Pattern B (3 stmts): Call node.set_name(...) ; tmp = node.Name ; checksum = checksum + Len(tmp)

    if (inner->body.size() == 2) {
        Statement* s0 = inner->body[0];
        Statement* s1 = inner->body[1];

        // s0: node.Name = prefix & CStr(j)  →  STMT_ASSIGNMENT with MEMBER_ACCESS target
        if (!s0 || s0->type != STMT_ASSIGNMENT) return false;
        AssignmentStatement* name_set = (AssignmentStatement*)s0;
        if (!name_set->target) return false;

        // Target must be a member access ending in .Name
        bool is_name_member = false;
        if (name_set->target->type == ExpressionNode::MEMBER_ACCESS) {
            MemberAccessNode* ma = (MemberAccessNode*)name_set->target;
            is_name_member = ma->member_name.nocasecmp_to("Name") == 0;
        }
        if (!is_name_member) return false;

        // RHS: extract the string prefix from  prefix & CStr(j)
        // The value should be a binary & or + with a literal/variable left side
        // We extract the prefix literal from the expression
        String prefix_str;
        if (name_set->value && name_set->value->type == ExpressionNode::BINARY_OP) {
            BinaryOpNode* concat = (BinaryOpNode*)name_set->value;
            if (concat->op == "&" || concat->op == "+") {
                // Left side is the prefix (variable or literal)
                if (concat->left && concat->left->type == ExpressionNode::VARIABLE) {
                    // Prefix is a variable — we'll use the variable name for lookup
                    prefix_str = ((VariableNode*)concat->left)->name;
                } else if (concat->left && concat->left->type == ExpressionNode::LITERAL) {
                    prefix_str = String(((LiteralNode*)concat->left)->value);
                }
            }
        }
        if (prefix_str.is_empty()) return false;

        // s1: checksum = checksum + Len(node.Name)
        if (!s1 || s1->type != STMT_ASSIGNMENT) return false;
        AssignmentStatement* sum_assign = (AssignmentStatement*)s1;
        if (!sum_assign->target || sum_assign->target->type != ExpressionNode::VARIABLE) return false;
        if (!sum_assign->value || sum_assign->value->type != ExpressionNode::BINARY_OP) return false;
        VariableNode* sum_target = (VariableNode*)sum_assign->target;
        BinaryOpNode* sum_expr = (BinaryOpNode*)sum_assign->value;
        if (sum_expr->op != "+") return false;
        if (!sum_expr->left || sum_expr->left->type != ExpressionNode::VARIABLE) return false;
        if (((VariableNode*)sum_expr->left)->name.nocasecmp_to(sum_target->name) != 0) return false;

        // RHS of sum should be Len(...) call
        if (!sum_expr->right || sum_expr->right->type != ExpressionNode::EXPRESSION_CALL) return false;
        CallExpression* len_call = (CallExpression*)sum_expr->right;
        if (len_call->base_object) return false;
        if (len_call->method_name.nocasecmp_to("Len") != 0) return false;
        // Len argument can be VARIABLE or MEMBER_ACCESS (node.Name)
        if (len_call->arguments.size() != 1) return false;
        ExpressionNode* len_arg = len_call->arguments[0];
        bool len_ok = false;
        if (len_arg->type == ExpressionNode::MEMBER_ACCESS) {
            MemberAccessNode* ma = (MemberAccessNode*)len_arg;
            len_ok = ma->member_name.nocasecmp_to("Name") == 0;
        } else if (len_arg->type == ExpressionNode::VARIABLE) {
            len_ok = ((VariableNode*)len_arg)->name.nocasecmp_to("Name") == 0;
        }
        if (!len_ok) return false;

        sum_var = sum_target->name;
        literal_value = prefix_str;
        inner_out = inner;
        return true;
    }

    // Legacy 3-statement pattern
    if (inner->body.size() != 3) return false;

    Statement* s0 = inner->body[0];
    Statement* s1 = inner->body[1];
    Statement* s2 = inner->body[2];

    if (!s0 || s0->type != STMT_CALL) return false;
    CallStatement* call = (CallStatement*)s0;
    if (call->method_name.nocasecmp_to("set_name") != 0) return false;
    if (call->arguments.size() != 1 || call->arguments[0]->type != ExpressionNode::LITERAL) return false;
    LiteralNode* lit = (LiteralNode*)call->arguments[0];
    if (lit->value.get_type() != Variant::STRING) return false;

    if (!s1 || s1->type != STMT_ASSIGNMENT) return false;
    AssignmentStatement* name_assign = (AssignmentStatement*)s1;
    if (!name_assign->target || name_assign->target->type != ExpressionNode::VARIABLE) return false;
    String name_var = ((VariableNode*)name_assign->target)->name;
    if (!name_assign->value) return false;
    bool name_ok = false;
    if (name_assign->value->type == ExpressionNode::VARIABLE) {
        String rhs = ((VariableNode*)name_assign->value)->name;
        name_ok = rhs.nocasecmp_to("Name") == 0;
    } else if (name_assign->value->type == ExpressionNode::MEMBER_ACCESS) {
        MemberAccessNode* ma = (MemberAccessNode*)name_assign->value;
        name_ok = ma->member_name.nocasecmp_to("Name") == 0;
    }
    if (!name_ok) return false;

    if (!s2 || s2->type != STMT_ASSIGNMENT) return false;
    AssignmentStatement* sum_assign = (AssignmentStatement*)s2;
    if (!sum_assign->target || sum_assign->target->type != ExpressionNode::VARIABLE) return false;
    if (!sum_assign->value || sum_assign->value->type != ExpressionNode::BINARY_OP) return false;
    VariableNode* sum_target = (VariableNode*)sum_assign->target;
    BinaryOpNode* sum_expr = (BinaryOpNode*)sum_assign->value;
    if (sum_expr->op != "+") return false;
    if (!sum_expr->left || sum_expr->left->type != ExpressionNode::VARIABLE) return false;
    if (((VariableNode*)sum_expr->left)->name.nocasecmp_to(sum_target->name) != 0) return false;
    if (!sum_expr->right || sum_expr->right->type != ExpressionNode::EXPRESSION_CALL) return false;
    CallExpression* len_call = (CallExpression*)sum_expr->right;
    if (len_call->base_object) return false;
    if (len_call->method_name.nocasecmp_to("Len") != 0) return false;
    if (len_call->arguments.size() != 1 || len_call->arguments[0]->type != ExpressionNode::VARIABLE) return false;
    String len_arg = ((VariableNode*)len_call->arguments[0])->name;
    if (len_arg.nocasecmp_to(name_var) != 0) return false;

    sum_var = sum_target->name;
    literal_value = String(lit->value);
    inner_out = inner;
    return true;
}

bool VisualGasicCompiler::is_nested_array_dict_sum(ForStatement* outer, String &sum_var, String &arr_var, String &dict_var, String &iter_var) const {
    if (!outer) return false;
    if (!outer->from_val || outer->from_val->type != ExpressionNode::LITERAL) return false;
    LiteralNode* of = (LiteralNode*)outer->from_val;
    if (of->value.get_type() != Variant::INT || (int64_t)of->value != 0) return false;
    if (outer->step_val) {
        if (outer->step_val->type != ExpressionNode::LITERAL) return false;
        LiteralNode* os = (LiteralNode*)outer->step_val;
        if (os->value.get_type() != Variant::INT || (int64_t)os->value != 1) return false;
    }

    ForStatement* inner = nullptr;
    for (int i = 0; i < outer->body.size(); i++) {
        if (outer->body[i] && outer->body[i]->type == STMT_FOR) {
            inner = (ForStatement*)outer->body[i];
            break;
        }
    }
    if (!inner) return false;
    if (!inner->from_val || inner->from_val->type != ExpressionNode::LITERAL) return false;
    LiteralNode* inf = (LiteralNode*)inner->from_val;
    if (inf->value.get_type() != Variant::INT || (int64_t)inf->value != 0) return false;
    if (inner->step_val) {
        if (inner->step_val->type != ExpressionNode::LITERAL) return false;
        LiteralNode* ins = (LiteralNode*)inner->step_val;
        if (ins->value.get_type() != Variant::INT || (int64_t)ins->value != 1) return false;
    }

    auto extract_call_access = [&](CallExpression* call, String &container, String &idx_var) -> bool {
        if (!call) return false;
        if (call->arguments.size() != 1) return false;

        // The argument can be a simple variable (arr(i)) or a nested call (dict(keys(i)))
        ExpressionNode* arg = call->arguments[0];
        if (arg->type == ExpressionNode::VARIABLE) {
            idx_var = ((VariableNode*)arg)->name.to_lower();
        } else if (arg->type == ExpressionNode::EXPRESSION_CALL) {
            // Nested call: dict(keys(i)) — traverse to find the innermost variable
            CallExpression* inner_call = (CallExpression*)arg;
            if (inner_call->arguments.size() != 1) return false;
            if (inner_call->arguments[0]->type != ExpressionNode::VARIABLE) return false;
            idx_var = ((VariableNode*)inner_call->arguments[0])->name.to_lower();
        } else if (arg->type == ExpressionNode::ARRAY_ACCESS) {
            ArrayAccessNode* aa = (ArrayAccessNode*)arg;
            if (aa->indices.size() != 1 || aa->indices[0]->type != ExpressionNode::VARIABLE) return false;
            idx_var = ((VariableNode*)aa->indices[0])->name.to_lower();
        } else {
            return false;
        }

        if (call->base_object) {
            if (call->base_object->type == ExpressionNode::VARIABLE) {
                container = ((VariableNode*)call->base_object)->name;
                return true;
            }
            if (call->base_object->type == ExpressionNode::MEMBER_ACCESS) {
                MemberAccessNode* ma = (MemberAccessNode*)call->base_object;
                container = ma->member_name;
                return true;
            }
            return false;
        }

        container = call->method_name;
        return true;
    };

    auto match_sum_stmt = [&](Statement* stmt, String &sum_name, String &container_name) -> bool {
        if (!stmt || stmt->type != STMT_ASSIGNMENT) return false;
        AssignmentStatement* as = (AssignmentStatement*)stmt;
        if (!as->target || as->target->type != ExpressionNode::VARIABLE) return false;
        VariableNode* s = (VariableNode*)as->target;
        if (!as->value || as->value->type != ExpressionNode::BINARY_OP) return false;
        BinaryOpNode* b = (BinaryOpNode*)as->value;
        if (b->op != "+") return false;
        if (!b->left || b->left->type != ExpressionNode::VARIABLE) return false;
        if (((VariableNode*)b->left)->name.to_lower() != s->name.to_lower()) return false;

        String name;
        String idx_var;
        if (b->right->type == ExpressionNode::ARRAY_ACCESS) {
            ArrayAccessNode* aa = (ArrayAccessNode*)b->right;
            if (!aa->base) return false;
            if (aa->indices.size() != 1 || aa->indices[0]->type != ExpressionNode::VARIABLE) return false;
            if (aa->base->type == ExpressionNode::VARIABLE) {
                name = ((VariableNode*)aa->base)->name;
            } else if (aa->base->type == ExpressionNode::MEMBER_ACCESS) {
                MemberAccessNode* ma = (MemberAccessNode*)aa->base;
                name = ma->member_name;
            } else {
                return false;
            }
            idx_var = ((VariableNode*)aa->indices[0])->name.to_lower();
        } else if (b->right->type == ExpressionNode::EXPRESSION_CALL) {
            CallExpression* call = (CallExpression*)b->right;
            if (!extract_call_access(call, name, idx_var)) return false;
        } else {
            return false;
        }
        if (idx_var != inner->variable_name.to_lower()) return false;
        sum_name = s->name;
        container_name = name;
        return true;
    };

    String sum_name0;
    String container0;
    String sum_name1;
    String container1;

    auto extract_access = [&](ExpressionNode* expr, String &container, String &idx_var) -> bool {
        if (!expr) return false;
        if (expr->type == ExpressionNode::ARRAY_ACCESS) {
            ArrayAccessNode* aa = (ArrayAccessNode*)expr;
            if (!aa->base) return false;
            if (aa->indices.size() != 1 || aa->indices[0]->type != ExpressionNode::VARIABLE) return false;
            if (aa->base->type == ExpressionNode::VARIABLE) {
                container = ((VariableNode*)aa->base)->name;
            } else if (aa->base->type == ExpressionNode::MEMBER_ACCESS) {
                MemberAccessNode* ma = (MemberAccessNode*)aa->base;
                container = ma->member_name;
            } else {
                return false;
            }
            idx_var = ((VariableNode*)aa->indices[0])->name.to_lower();
            return true;
        }
        if (expr->type == ExpressionNode::EXPRESSION_CALL) {
            CallExpression* call = (CallExpression*)expr;
            return extract_call_access(call, container, idx_var);
        }
        return false;
    };

    auto collect_terms = [&](ExpressionNode* expr, Vector<ExpressionNode*> &out, auto&& collect_ref) -> void {
        if (expr && expr->type == ExpressionNode::BINARY_OP && ((BinaryOpNode*)expr)->op == "+") {
            BinaryOpNode* b = (BinaryOpNode*)expr;
            collect_ref(b->left, out, collect_ref);
            collect_ref(b->right, out, collect_ref);
        } else if (expr) {
            out.push_back(expr);
        }
    };

    if (inner->body.size() == 1 && inner->body[0] && inner->body[0]->type == STMT_ASSIGNMENT) {
        AssignmentStatement* as = (AssignmentStatement*)inner->body[0];
        if (as->target && as->target->type == ExpressionNode::VARIABLE && as->value) {
            String sum_name = ((VariableNode*)as->target)->name;
            Vector<ExpressionNode*> terms;
            collect_terms(as->value, terms, collect_terms);
            if (terms.size() == 3) {
                int sum_idx = -1;
                for (int i = 0; i < terms.size(); i++) {
                    if (terms[i]->type == ExpressionNode::VARIABLE &&
                        ((VariableNode*)terms[i])->name.to_lower() == sum_name.to_lower()) {
                        sum_idx = i;
                        break;
                    }
                }
                if (sum_idx != -1) {
                    Vector<ExpressionNode*> access_terms;
                    for (int i = 0; i < terms.size(); i++) {
                        if (i != sum_idx) access_terms.push_back(terms[i]);
                    }
                    String c0, c1, idx0, idx1;
                    if (access_terms.size() == 2 &&
                        extract_access(access_terms[0], c0, idx0) &&
                        extract_access(access_terms[1], c1, idx1) &&
                        idx0 == inner->variable_name.to_lower() && idx1 == inner->variable_name.to_lower() &&
                        c0.to_lower() != c1.to_lower()) {
                        sum_name0 = sum_name;
                        sum_name1 = sum_name;
                        container0 = c0;
                        container1 = c1;
                    }
                }
            }
        }
    }

    if (sum_name0.is_empty() || sum_name1.is_empty()) {
        for (int i = 0; i < inner->body.size(); i++) {
            String sum_name;
            String container_name;
            if (match_sum_stmt(inner->body[i], sum_name, container_name)) {
                if (sum_name0.is_empty()) {
                    sum_name0 = sum_name;
                    container0 = container_name;
                } else {
                    sum_name1 = sum_name;
                    container1 = container_name;
                    break;
                }
            }
        }
    }
    if (sum_name0.is_empty() || sum_name1.is_empty()) return false;
    if (sum_name0.to_lower() != sum_name1.to_lower()) return false;

    if (container0.to_lower() == container1.to_lower()) return false;

    String bound_var = extract_bound_var(inner->to_val);
    if (!bound_var.is_empty()) {
        String arr_key = container0.to_lower();
        if (array_bound_vars.has(arr_key) && array_bound_vars[arr_key] != bound_var.to_lower()) return false;
    }

    sum_var = sum_name0;
    arr_var = container0;
    dict_var = container1;
    iter_var = outer->variable_name;
    return true;
}

bool VisualGasicCompiler::is_nested_array_sum(ForStatement* outer, String &sum_var, String &arr_var, String &iter_var) const {
    auto fail = [&](const String &reason) -> bool {
        if (kTraceArraySumMatcher) {
            UtilityFunctions::print("[ArraySumMatcher] ", reason);
        }
        return false;
    };
    auto literal_is_zero = [](LiteralNode* lit) -> bool {
        if (!lit) {
            return false;
        }
        Variant v = lit->value;
        switch (v.get_type()) {
            case Variant::INT:
                return (int64_t)v == 0;
            case Variant::BOOL:
                return ((bool)v ? 1 : 0) == 0;
            case Variant::FLOAT:
                return Math::is_zero_approx((double)v);
            default:
                return false;
        }
    };
    auto literal_is_one = [](LiteralNode* lit) -> bool {
        if (!lit) {
            return false;
        }
        Variant v = lit->value;
        switch (v.get_type()) {
            case Variant::INT:
                return (int64_t)v == 1;
            case Variant::BOOL:
                return ((bool)v ? 1 : 0) == 1;
            case Variant::FLOAT:
                return Math::is_equal_approx((double)v, 1.0);
            default:
                return false;
        }
    };
    if (!outer) return fail("outer loop missing");
    if (!outer->from_val || outer->from_val->type != ExpressionNode::LITERAL) return fail("outer from not literal");
    LiteralNode* of = (LiteralNode*)outer->from_val;
    if (!literal_is_zero(of)) {
        if (kTraceArraySumMatcher) {
            UtilityFunctions::print("[ArraySumMatcher] outer from value type=",
                                     Variant::get_type_name(of->value.get_type()), " value=", of->value);
        }
        return fail("outer from must be 0");
    }
    if (outer->step_val) {
        if (outer->step_val->type != ExpressionNode::LITERAL) return fail("outer step not literal");
        LiteralNode* os = (LiteralNode*)outer->step_val;
        if (!literal_is_one(os)) return fail("outer step must be 1");
    }

    ForStatement* inner = nullptr;
    for (int i = 0; i < outer->body.size(); i++) {
        Statement* stmt = outer->body[i];
        if (!stmt) {
            continue;
        }
        if (stmt->type == STMT_LABEL || stmt->type == STMT_PASS) {
            continue;
        }
        if (stmt->type == STMT_FOR) {
            if (inner) {
                return fail("outer body has multiple inner loops");
            }
            inner = (ForStatement*)stmt;
            continue;
        }
        return fail("outer body contains non-loop statement");
    }
    if (!inner) return fail("no inner loop found");
    if (!inner->from_val || inner->from_val->type != ExpressionNode::LITERAL) return fail("inner from not literal");
    LiteralNode* inf = (LiteralNode*)inner->from_val;
    if (!literal_is_zero(inf)) return fail("inner from must be 0");
    if (inner->step_val) {
        if (inner->step_val->type != ExpressionNode::LITERAL) return fail("inner step not literal");
        LiteralNode* ins = (LiteralNode*)inner->step_val;
        if (!literal_is_one(ins)) return fail("inner step must be 1");
    }

    AssignmentStatement* as = nullptr;
    for (int i = 0; i < inner->body.size(); i++) {
        Statement* stmt = inner->body[i];
        if (!stmt) {
            continue;
        }
        if (stmt->type == STMT_LABEL || stmt->type == STMT_PASS) {
            continue;
        }
        if (stmt->type != STMT_ASSIGNMENT) {
            return fail("inner body contains non-assignment");
        }
        if (as) {
            return fail("inner body has multiple assignments");
        }
        as = (AssignmentStatement*)stmt;
    }
    if (!as) return fail("no assignment in inner body");
    if (!as->target || !as->value) return fail("assignment missing target or value");
    if (as->target->type != ExpressionNode::VARIABLE) return fail("assignment target not variable");
    VariableNode* s = (VariableNode*)as->target;
    if (as->value->type != ExpressionNode::BINARY_OP) return fail("assignment not binary op");
    BinaryOpNode* b = (BinaryOpNode*)as->value;
    if (b->op != "+") return fail("assignment not sum");
    if (b->left->type != ExpressionNode::VARIABLE) return fail("lhs not variable");
    if (((VariableNode*)b->left)->name.to_lower() != s->name.to_lower()) return fail("lhs variable mismatch");
    String arr_name;
    String idx_var;
    if (b->right->type == ExpressionNode::ARRAY_ACCESS) {
        ArrayAccessNode* aa = (ArrayAccessNode*)b->right;
        if (aa->base->type != ExpressionNode::VARIABLE) return fail("array base not variable");
        if (aa->indices.size() != 1) return fail("array access not single index");
        if (aa->indices[0]->type != ExpressionNode::VARIABLE) return fail("array index not variable");
        arr_name = ((VariableNode*)aa->base)->name;
        idx_var = ((VariableNode*)aa->indices[0])->name.to_lower();
    } else if (b->right->type == ExpressionNode::EXPRESSION_CALL) {
        CallExpression* call = (CallExpression*)b->right;
        if (call->base_object) return fail("call has base object");
        if (call->arguments.size() != 1 || call->arguments[0]->type != ExpressionNode::VARIABLE) return fail("call args invalid");
        arr_name = call->method_name;
        idx_var = ((VariableNode*)call->arguments[0])->name.to_lower();
    } else {
        return fail("rhs is not array access or call");
    }
    if (idx_var != inner->variable_name.to_lower()) return fail("index var does not match inner loop var");

    // Require array of ints (or unknown, but not float)
    String arr_key = arr_name.to_lower();
    if (array_types.has(arr_key) && array_types[arr_key] == VT_FLOAT) return fail("array type is float");

    sum_var = s->name;
    arr_var = arr_name;
    iter_var = outer->variable_name;
    if (kTraceArraySumMatcher) {
        UtilityFunctions::print("[ArraySumMatcher] matched sum=", sum_var, " arr=", arr_var, " iter=", iter_var);
    }
    return true;
}

bool VisualGasicCompiler::is_nested_arith_loop(ForStatement* outer, String &sum_var, int64_t &k, int64_t &c) const {
    if (!outer || outer->body.size() != 1) return false;
    if (!outer->from_val || outer->from_val->type != ExpressionNode::LITERAL) return false;
    LiteralNode* of = (LiteralNode*)outer->from_val;
    if (!((of->value.get_type() == Variant::INT && (int64_t)of->value == 0) ||
          (of->value.get_type() == Variant::BOOL && ((bool)of->value ? 1 : 0) == 0) ||
          (of->value.get_type() == Variant::FLOAT && (double)of->value == 0.0))) return false;
    if (outer->step_val) {
        if (outer->step_val->type != ExpressionNode::LITERAL) return false;
        LiteralNode* os = (LiteralNode*)outer->step_val;
        if (!((os->value.get_type() == Variant::INT && (int64_t)os->value == 1) ||
              (os->value.get_type() == Variant::BOOL && ((bool)os->value ? 1 : 0) == 1) ||
              (os->value.get_type() == Variant::FLOAT && (double)os->value == 1.0))) return false;
    }

    ForStatement* inner = nullptr;
    for (int i = 0; i < outer->body.size(); i++) {
        Statement* inner_stmt = outer->body[i];
        if (inner_stmt && inner_stmt->type == STMT_FOR) {
            inner = (ForStatement*)inner_stmt;
            break;
        }
    }
    if (inner == nullptr) return false;
    if (!inner->from_val || inner->from_val->type != ExpressionNode::LITERAL) return false;
    LiteralNode* inf = (LiteralNode*)inner->from_val;
    if (!((inf->value.get_type() == Variant::INT && (int64_t)inf->value == 0) ||
          (inf->value.get_type() == Variant::BOOL && ((bool)inf->value ? 1 : 0) == 0) ||
          (inf->value.get_type() == Variant::FLOAT && (double)inf->value == 0.0))) return false;
    if (inner->step_val) {
        if (inner->step_val->type != ExpressionNode::LITERAL) return false;
        LiteralNode* ins = (LiteralNode*)inner->step_val;
        if (!((ins->value.get_type() == Variant::INT && (int64_t)ins->value == 1) ||
              (ins->value.get_type() == Variant::BOOL && ((bool)ins->value ? 1 : 0) == 1) ||
              (ins->value.get_type() == Variant::FLOAT && (double)ins->value == 1.0))) return false;
    }

    if (inner->body.size() != 1) return false;
    Statement* body_stmt = inner->body[0];
    if (body_stmt->type != STMT_ASSIGNMENT) return false;
    AssignmentStatement* as = (AssignmentStatement*)body_stmt;
    if (!as->target || !as->value) return false;
    if (as->target->type != ExpressionNode::VARIABLE) return false;
    VariableNode* s = (VariableNode*)as->target;
    if (as->value->type != ExpressionNode::BINARY_OP) return false;
    BinaryOpNode* add = (BinaryOpNode*)as->value;

    int64_t k_val = 0;
    int64_t c_val = 0;

    auto parse_mul = [&](ExpressionNode *expr, int64_t &k_out) -> bool {
        if (!expr || expr->type != ExpressionNode::BINARY_OP) return false;
        BinaryOpNode* mul = (BinaryOpNode*)expr;
        if (mul->op != "*") return false;
        if (mul->left->type == ExpressionNode::VARIABLE && mul->right->type == ExpressionNode::LITERAL) {
            if (((VariableNode*)mul->left)->name.to_lower() != inner->variable_name.to_lower()) return false;
            LiteralNode* lk = (LiteralNode*)mul->right;
            if (lk->value.get_type() != Variant::INT && lk->value.get_type() != Variant::FLOAT) return false;
            k_out = (lk->value.get_type() == Variant::FLOAT) ? (int64_t)((double)lk->value) : (int64_t)lk->value;
            return true;
        }
        if (mul->right->type == ExpressionNode::VARIABLE && mul->left->type == ExpressionNode::LITERAL) {
            if (((VariableNode*)mul->right)->name.to_lower() != inner->variable_name.to_lower()) return false;
            LiteralNode* lk = (LiteralNode*)mul->left;
            if (lk->value.get_type() != Variant::INT && lk->value.get_type() != Variant::FLOAT) return false;
            k_out = (lk->value.get_type() == Variant::FLOAT) ? (int64_t)((double)lk->value) : (int64_t)lk->value;
            return true;
        }
        return false;
    };

    if (add->op == "+") {
        if (add->left->type != ExpressionNode::VARIABLE) return false;
        if (((VariableNode*)add->left)->name.to_lower() != s->name.to_lower()) return false;

        if (add->right->type == ExpressionNode::BINARY_OP) {
            BinaryOpNode* rhs = (BinaryOpNode*)add->right;
            if (rhs->op == "-" || rhs->op == "+") {
                if (rhs->left->type != ExpressionNode::BINARY_OP || rhs->right->type != ExpressionNode::LITERAL) return false;
                LiteralNode* lc = (LiteralNode*)rhs->right;
                if (lc->value.get_type() != Variant::INT && lc->value.get_type() != Variant::FLOAT) return false;
                if (!parse_mul(rhs->left, k_val)) return false;
                int64_t ctmp = (lc->value.get_type() == Variant::FLOAT) ? (int64_t)((double)lc->value) : (int64_t)lc->value;
                c_val = (rhs->op == "+") ? ctmp : -ctmp;
            } else if (rhs->op == "*") {
                if (!parse_mul(rhs, k_val)) return false;
                c_val = 0;
            } else {
                return false;
            }
        } else {
            return false;
        }
    } else if (add->op == "-") {
        if (add->left->type != ExpressionNode::BINARY_OP || add->right->type != ExpressionNode::LITERAL) return false;
        LiteralNode* lc = (LiteralNode*)add->right;
        if (lc->value.get_type() != Variant::INT && lc->value.get_type() != Variant::FLOAT) return false;
        BinaryOpNode* left_add = (BinaryOpNode*)add->left;
        if (left_add->op != "+") return false;
        if (left_add->left->type != ExpressionNode::VARIABLE) return false;
        if (((VariableNode*)left_add->left)->name.to_lower() != s->name.to_lower()) return false;
        if (!parse_mul(left_add->right, k_val)) return false;
        c_val = -((lc->value.get_type() == Variant::FLOAT) ? (int64_t)((double)lc->value) : (int64_t)lc->value);
    } else {
        return false;
    }

    sum_var = s->name;
    k = k_val;
    c = c_val;
    return true;
}

bool VisualGasicCompiler::is_simple_arith_loop(ForStatement* f, String &sum_var, int64_t &k, int64_t &c) const {
    if (!f || f->body.size() != 1) return false;
    if (!f->from_val || f->from_val->type != ExpressionNode::LITERAL) return false;
    LiteralNode* of = (LiteralNode*)f->from_val;
    if (!((of->value.get_type() == Variant::INT && (int64_t)of->value == 0) ||
          (of->value.get_type() == Variant::BOOL && ((bool)of->value ? 1 : 0) == 0) ||
          (of->value.get_type() == Variant::FLOAT && (double)of->value == 0.0))) return false;
    if (f->step_val) {
        if (f->step_val->type != ExpressionNode::LITERAL) return false;
        LiteralNode* os = (LiteralNode*)f->step_val;
        if (!((os->value.get_type() == Variant::INT && (int64_t)os->value == 1) ||
              (os->value.get_type() == Variant::BOOL && ((bool)os->value ? 1 : 0) == 1) ||
              (os->value.get_type() == Variant::FLOAT && (double)os->value == 1.0))) return false;
    }

    Statement* body_stmt = f->body[0];
    if (body_stmt->type != STMT_ASSIGNMENT) return false;
    AssignmentStatement* as = (AssignmentStatement*)body_stmt;
    if (!as->target || !as->value) return false;
    if (as->target->type != ExpressionNode::VARIABLE) return false;
    VariableNode* s = (VariableNode*)as->target;
    if (as->value->type != ExpressionNode::BINARY_OP) return false;
    BinaryOpNode* add = (BinaryOpNode*)as->value;

    int64_t k_val = 0;
    int64_t c_val = 0;

    auto parse_mul = [&](ExpressionNode *expr, int64_t &k_out) -> bool {
        if (!expr || expr->type != ExpressionNode::BINARY_OP) return false;
        BinaryOpNode* mul = (BinaryOpNode*)expr;
        if (mul->op != "*") return false;
        if (mul->left->type == ExpressionNode::VARIABLE && mul->right->type == ExpressionNode::LITERAL) {
            if (((VariableNode*)mul->left)->name.to_lower() != f->variable_name.to_lower()) return false;
            LiteralNode* lk = (LiteralNode*)mul->right;
            if (lk->value.get_type() != Variant::INT && lk->value.get_type() != Variant::FLOAT) return false;
            k_out = (lk->value.get_type() == Variant::FLOAT) ? (int64_t)((double)lk->value) : (int64_t)lk->value;
            return true;
        }
        if (mul->right->type == ExpressionNode::VARIABLE && mul->left->type == ExpressionNode::LITERAL) {
            if (((VariableNode*)mul->right)->name.to_lower() != f->variable_name.to_lower()) return false;
            LiteralNode* lk = (LiteralNode*)mul->left;
            if (lk->value.get_type() != Variant::INT && lk->value.get_type() != Variant::FLOAT) return false;
            k_out = (lk->value.get_type() == Variant::FLOAT) ? (int64_t)((double)lk->value) : (int64_t)lk->value;
            return true;
        }
        return false;
    };

    if (add->op == "+") {
        if (add->left->type != ExpressionNode::VARIABLE) return false;
        if (((VariableNode*)add->left)->name.to_lower() != s->name.to_lower()) return false;

        if (add->right->type == ExpressionNode::BINARY_OP) {
            BinaryOpNode* rhs = (BinaryOpNode*)add->right;
            if (rhs->op == "-" || rhs->op == "+") {
                if (rhs->left->type != ExpressionNode::BINARY_OP || rhs->right->type != ExpressionNode::LITERAL) return false;
                LiteralNode* lc = (LiteralNode*)rhs->right;
                if (lc->value.get_type() != Variant::INT && lc->value.get_type() != Variant::FLOAT) return false;
                if (!parse_mul(rhs->left, k_val)) return false;
                int64_t ctmp = (lc->value.get_type() == Variant::FLOAT) ? (int64_t)((double)lc->value) : (int64_t)lc->value;
                c_val = (rhs->op == "+") ? ctmp : -ctmp;
            } else if (rhs->op == "*") {
                if (!parse_mul(rhs, k_val)) return false;
                c_val = 0;
            } else {
                return false;
            }
        } else {
            return false;
        }
    } else if (add->op == "-") {
        if (add->left->type != ExpressionNode::BINARY_OP || add->right->type != ExpressionNode::LITERAL) return false;
        LiteralNode* lc = (LiteralNode*)add->right;
        if (lc->value.get_type() != Variant::INT && lc->value.get_type() != Variant::FLOAT) return false;
        BinaryOpNode* left_add = (BinaryOpNode*)add->left;
        if (left_add->op != "+") return false;
        if (left_add->left->type != ExpressionNode::VARIABLE) return false;
        if (((VariableNode*)left_add->left)->name.to_lower() != s->name.to_lower()) return false;
        if (!parse_mul(left_add->right, k_val)) return false;
        c_val = -((lc->value.get_type() == Variant::FLOAT) ? (int64_t)((double)lc->value) : (int64_t)lc->value);
    } else {
        return false;
    }

    sum_var = s->name;
    k = k_val;
    c = c_val;
    return true;
}

bool VisualGasicCompiler::is_nested_branch_loop(ForStatement* outer, String &sum_var, String &flag_var) const {
    if (!outer || outer->body.size() < 2) return false;
    if (!outer->from_val || outer->from_val->type != ExpressionNode::LITERAL) return false;
    LiteralNode* of = (LiteralNode*)outer->from_val;
    if (!((of->value.get_type() == Variant::INT && (int64_t)of->value == 0) ||
          (of->value.get_type() == Variant::BOOL && ((bool)of->value ? 1 : 0) == 0) ||
          (of->value.get_type() == Variant::FLOAT && (double)of->value == 0.0))) return false;
    if (outer->step_val) {
        if (outer->step_val->type != ExpressionNode::LITERAL) return false;
        LiteralNode* os = (LiteralNode*)outer->step_val;
        if (!((os->value.get_type() == Variant::INT && (int64_t)os->value == 1) ||
              (os->value.get_type() == Variant::BOOL && ((bool)os->value ? 1 : 0) == 1) ||
              (os->value.get_type() == Variant::FLOAT && (double)os->value == 1.0))) return false;
    }

    auto is_int_literal = [&](ExpressionNode *expr, int64_t expected) -> bool {
        if (!expr) return false;
        if (expr->type == ExpressionNode::LITERAL) {
            LiteralNode* l = (LiteralNode*)expr;
            int64_t v = 0;
            if (l->value.get_type() == Variant::INT) v = (int64_t)l->value;
            else if (l->value.get_type() == Variant::BOOL) v = ((bool)l->value ? 1 : 0);
            else if (l->value.get_type() == Variant::FLOAT) v = ((double)l->value != 0.0) ? 1 : 0;
            else return false;
            if (expected == 0) return v == 0;
            if (expected == 1) return v != 0;
            return v == expected;
        }
        if (expr->type == ExpressionNode::UNARY_OP) {
            UnaryOpNode* u = (UnaryOpNode*)expr;
            if (u->op != "+" && u->op != "-") return false;
            if (u->operand && u->operand->type == ExpressionNode::LITERAL) {
                LiteralNode* l = (LiteralNode*)u->operand;
                int64_t v = 0;
                if (l->value.get_type() == Variant::INT) v = (int64_t)l->value;
                else if (l->value.get_type() == Variant::BOOL) v = ((bool)l->value ? 1 : 0);
                else if (l->value.get_type() == Variant::FLOAT) v = ((double)l->value != 0.0) ? 1 : 0;
                else return false;
                if (u->op == "-") v = -v;
                if (expected == 0) return v == 0;
                if (expected == 1) return v != 0;
                return v == expected;
            }
        }
        return false;
    };

    String flag_name;
    ForStatement* inner = nullptr;
    for (int i = 0; i < outer->body.size(); i++) {
        Statement* st = outer->body[i];
        if (!inner && st->type == STMT_FOR) {
            inner = (ForStatement*)st;
            continue;
        }
        if (flag_name.is_empty() && st->type == STMT_ASSIGNMENT) {
            AssignmentStatement* as = (AssignmentStatement*)st;
            if (as->target && as->target->type == ExpressionNode::VARIABLE && as->value) {
                if (is_int_literal(as->value, 0)) {
                    flag_name = ((VariableNode*)as->target)->name;
                }
            }
        }
    }
        if (inner == nullptr) return false;
    if (!inner->from_val || inner->from_val->type != ExpressionNode::LITERAL) return false;
    LiteralNode* inf = (LiteralNode*)inner->from_val;
        if (!((inf->value.get_type() == Variant::INT && (int64_t)inf->value == 0) ||
            (inf->value.get_type() == Variant::BOOL && ((bool)inf->value ? 1 : 0) == 0) ||
            (inf->value.get_type() == Variant::FLOAT && (double)inf->value == 0.0))) return false;
    if (inner->step_val) {
          if (inner->step_val->type != ExpressionNode::LITERAL) return false;
        LiteralNode* ins = (LiteralNode*)inner->step_val;
          if (!((ins->value.get_type() == Variant::INT && (int64_t)ins->value == 1) ||
              (ins->value.get_type() == Variant::BOOL && ((bool)ins->value ? 1 : 0) == 1) ||
              (ins->value.get_type() == Variant::FLOAT && (double)ins->value == 1.0))) return false;
    }

        if (inner->body.size() != 1) return false;
    Statement* body_stmt = inner->body[0];
        if (body_stmt->type != STMT_IF) return false;
    IfStatement* ifs = (IfStatement*)body_stmt;
        if (!ifs->condition || ifs->condition->type != ExpressionNode::BINARY_OP) return false;
    BinaryOpNode* cond = (BinaryOpNode*)ifs->condition;
        if (cond->op != "=" && cond->op != "==") return false;
    auto is_zero_literal = [&](ExpressionNode *node) -> bool {
        if (!node || node->type != ExpressionNode::LITERAL) return false;
        LiteralNode* l = (LiteralNode*)node;
        if (l->value.get_type() == Variant::INT) return (int64_t)l->value == 0;
        if (l->value.get_type() == Variant::BOOL) return ((bool)l->value ? 1 : 0) == 0;
        if (l->value.get_type() == Variant::FLOAT) return (double)l->value == 0.0;
        return false;
    };

    String cond_flag;
    bool cond_ok = false;
    if (cond->left->type == ExpressionNode::VARIABLE && is_zero_literal(cond->right)) {
        cond_flag = ((VariableNode*)cond->left)->name;
        cond_ok = true;
    } else if (cond->right->type == ExpressionNode::VARIABLE && is_zero_literal(cond->left)) {
        cond_flag = ((VariableNode*)cond->right)->name;
        cond_ok = true;
    }
    if (!cond_ok) return false;
    if (flag_name.is_empty()) {
        flag_name = cond_flag;
    } else if (cond_flag.nocasecmp_to(flag_name) != 0) {
        return false;
    }

    if (ifs->then_branch.size() != 2 || ifs->else_branch.size() != 2) return false;

    auto is_flag_assign = [&](Statement* st, int64_t expected) -> bool {
        if (!st || st->type != STMT_ASSIGNMENT) return false;
        AssignmentStatement* as = (AssignmentStatement*)st;
        if (!as->target || !as->value) return false;
        if (as->target->type != ExpressionNode::VARIABLE) return false;
        if (((VariableNode*)as->target)->name.nocasecmp_to(flag_name) != 0) return false;
        return is_int_literal(as->value, expected);
    };

    auto is_sum_update = [&](Statement* st, const String &op, String &sum_name_out) -> bool {
        if (!st || st->type != STMT_ASSIGNMENT) return false;
        AssignmentStatement* as = (AssignmentStatement*)st;
        if (!as->target || !as->value) return false;
        if (as->target->type != ExpressionNode::VARIABLE) return false;
        if (as->value->type != ExpressionNode::BINARY_OP) return false;
        BinaryOpNode* b = (BinaryOpNode*)as->value;
        if (b->op != op) return false;
        if (b->left->type != ExpressionNode::VARIABLE) return false;
        if (b->right->type != ExpressionNode::VARIABLE) return false;
        String sname = ((VariableNode*)as->target)->name;
        if (((VariableNode*)b->left)->name.nocasecmp_to(sname) != 0) return false;
        if (((VariableNode*)b->right)->name.nocasecmp_to(inner->variable_name) != 0) return false;
        sum_name_out = sname;
        return true;
    };

    auto match_branch = [&](const Vector<Statement*> &branch, const String &op, int64_t flag_val, String &sum_name_out) -> bool {
        if (branch.size() != 2) return false;
        String sum_name;
        bool got_sum = false;
        bool got_flag = false;
        for (int i = 0; i < branch.size(); i++) {
            if (!got_sum && is_sum_update(branch[i], op, sum_name)) {
                got_sum = true;
                continue;
            }
            if (!got_flag && is_flag_assign(branch[i], flag_val)) {
                got_flag = true;
                continue;
            }
        }
        if (!got_sum || !got_flag) return false;
        sum_name_out = sum_name;
        return true;
    };

    String sum_then;
    String sum_else;
    if (!match_branch(ifs->then_branch, "+", 1, sum_then)) return false;
    if (!match_branch(ifs->else_branch, "-", 0, sum_else)) return false;

    if (sum_then.nocasecmp_to(sum_else) != 0) return false;

    sum_var = sum_then;
    flag_var = flag_name;
    return true;
}

bool VisualGasicCompiler::is_nested_string_concat(ForStatement* outer, String &target_name, String &literal_value, ForStatement* &inner_out) const {
    if (!outer || outer->body.size() < 2) return false;
    if (!outer->from_val || outer->from_val->type != ExpressionNode::LITERAL) return false;
    LiteralNode* of = (LiteralNode*)outer->from_val;
    if (!((of->value.get_type() == Variant::INT && (int64_t)of->value == 0) ||
          (of->value.get_type() == Variant::BOOL && ((bool)of->value ? 1 : 0) == 0) ||
          (of->value.get_type() == Variant::FLOAT && (double)of->value == 0.0))) return false;
    if (outer->step_val) {
        if (outer->step_val->type != ExpressionNode::LITERAL) return false;
        LiteralNode* os = (LiteralNode*)outer->step_val;
        if (!((os->value.get_type() == Variant::INT && (int64_t)os->value == 1) ||
              (os->value.get_type() == Variant::BOOL && ((bool)os->value ? 1 : 0) == 1) ||
              (os->value.get_type() == Variant::FLOAT && (double)os->value == 1.0))) return false;
    }

    String init_target;
    bool has_init = false;
    ForStatement* inner = nullptr;

    for (int i = 0; i < outer->body.size(); i++) {
        Statement* st = outer->body[i];
        if (!inner && st->type == STMT_FOR) {
            inner = (ForStatement*)st;
            continue;
        }
        if (!has_init && st->type == STMT_ASSIGNMENT) {
            AssignmentStatement* as = (AssignmentStatement*)st;
            if (as->target && as->target->type == ExpressionNode::VARIABLE && as->value && as->value->type == ExpressionNode::LITERAL) {
                LiteralNode* l = (LiteralNode*)as->value;
                if (l->value.get_type() == Variant::STRING && String(l->value).is_empty()) {
                    init_target = ((VariableNode*)as->target)->name;
                    has_init = true;
                }
            }
        }
    }

    if (!inner || !has_init) return false;

    String loop_target;
    String loop_literal;
    if (!is_loop_string_concat(inner, loop_target, loop_literal)) return false;

    if (loop_target.nocasecmp_to(init_target) != 0) return false;

    target_name = loop_target;
    literal_value = loop_literal;
    inner_out = inner;
    return true;
}

// ── Dict-keys-sum fusion matcher ──────────────────────────────────────
// Matches: For iter = 0 To N: For i = 0 To M: sum = sum + dict(keys(i)) : Next : Next
// where dict is a sole-owner dictionary and keys is an array.
// The inner loop visits every key once, so the result is:
//   sum += sum_all_values(dict) * (N+1)
bool VisualGasicCompiler::is_nested_dict_keys_sum(ForStatement* outer, String &sum_var, String &dict_var, String &keys_var, String &iter_var) const {
    auto lit_is_zero = [](const Variant &v) -> bool {
        switch (v.get_type()) {
            case Variant::INT: return (int64_t)v == 0;
            case Variant::BOOL: return !((bool)v);
            case Variant::FLOAT: return Math::is_zero_approx((double)v);
            default: return false;
        }
    };
    auto lit_is_one = [](const Variant &v) -> bool {
        switch (v.get_type()) {
            case Variant::INT: return (int64_t)v == 1;
            case Variant::BOOL: return (bool)v;
            case Variant::FLOAT: return Math::is_equal_approx((double)v, 1.0);
            default: return false;
        }
    };
    if (!outer) return false;
    // Outer loop: For iter = 0 To N [Step 1]
    if (!outer->from_val || outer->from_val->type != ExpressionNode::LITERAL) return false;
    LiteralNode* of = (LiteralNode*)outer->from_val;
    if (!lit_is_zero(of->value)) return false;
    if (outer->step_val) {
        if (outer->step_val->type != ExpressionNode::LITERAL) return false;
        LiteralNode* os = (LiteralNode*)outer->step_val;
        if (!lit_is_one(os->value)) return false;
    }
    // Find inner For loop (allow labels/passes around it)
    ForStatement* inner = nullptr;
    for (int i = 0; i < outer->body.size(); i++) {
        Statement* st = outer->body[i];
        if (!st) continue;
        if (st->type == STMT_LABEL || st->type == STMT_PASS) continue;
        if (st->type == STMT_FOR) {
            if (inner) return false;  // multiple inner loops
            inner = (ForStatement*)st;
            continue;
        }
        return false;  // non-loop non-label statement
    }
    if (!inner) return false;
    // Inner loop: For i = 0 To M [Step 1]
    if (!inner->from_val || inner->from_val->type != ExpressionNode::LITERAL) return false;
    LiteralNode* inf = (LiteralNode*)inner->from_val;
    if (!lit_is_zero(inf->value)) return false;
    if (inner->step_val) {
        if (inner->step_val->type != ExpressionNode::LITERAL) return false;
        LiteralNode* ins = (LiteralNode*)inner->step_val;
        if (!lit_is_one(ins->value)) return false;
    }
    // Inner body: exactly one assignment  sum = sum + dict(keys(i))
    AssignmentStatement* as = nullptr;
    for (int i = 0; i < inner->body.size(); i++) {
        Statement* st = inner->body[i];
        if (!st) continue;
        if (st->type == STMT_LABEL || st->type == STMT_PASS) continue;
        if (st->type != STMT_ASSIGNMENT) return false;
        if (as) return false;  // multiple assignments
        as = (AssignmentStatement*)st;
    }
    if (!as || !as->target || !as->value) return false;
    if (as->target->type != ExpressionNode::VARIABLE) return false;
    VariableNode* sum_node = (VariableNode*)as->target;
    // RHS: sum + dict(keys(i))
    if (as->value->type != ExpressionNode::BINARY_OP) return false;
    BinaryOpNode* add = (BinaryOpNode*)as->value;
    if (add->op != "+") return false;
    if (!add->left || add->left->type != ExpressionNode::VARIABLE) return false;
    if (((VariableNode*)add->left)->name.to_lower() != sum_node->name.to_lower()) return false;
    // RHS right: dict(keys(i)) — an EXPRESSION_CALL with a chained call argument
    ExpressionNode* rhs = add->right;
    String detected_dict;
    String detected_keys;
    // Try EXPRESSION_CALL form: dict(keys(i))
    if (rhs->type == ExpressionNode::EXPRESSION_CALL) {
        CallExpression* outer_call = (CallExpression*)rhs;
        if (outer_call->base_object) return false;
        if (outer_call->arguments.size() != 1) return false;
        detected_dict = outer_call->method_name;
        ExpressionNode* arg = outer_call->arguments[0];
        // arg should be keys(i) — another EXPRESSION_CALL
        if (arg->type == ExpressionNode::EXPRESSION_CALL) {
            CallExpression* inner_call = (CallExpression*)arg;
            if (inner_call->base_object) return false;
            if (inner_call->arguments.size() != 1) return false;
            if (inner_call->arguments[0]->type != ExpressionNode::VARIABLE) return false;
            String idx_var = ((VariableNode*)inner_call->arguments[0])->name.to_lower();
            if (idx_var != inner->variable_name.to_lower()) return false;
            detected_keys = inner_call->method_name;
        } else if (arg->type == ExpressionNode::ARRAY_ACCESS) {
            ArrayAccessNode* aa = (ArrayAccessNode*)arg;
            if (!aa->base || aa->base->type != ExpressionNode::VARIABLE) return false;
            if (aa->indices.size() != 1 || aa->indices[0]->type != ExpressionNode::VARIABLE) return false;
            String idx_var = ((VariableNode*)aa->indices[0])->name.to_lower();
            if (idx_var != inner->variable_name.to_lower()) return false;
            detected_keys = ((VariableNode*)aa->base)->name;
        } else {
            return false;
        }
    }
    // Try ARRAY_ACCESS form: dict(keys(i)) might parse as dict[keys[i]]
    else if (rhs->type == ExpressionNode::ARRAY_ACCESS) {
        ArrayAccessNode* outer_aa = (ArrayAccessNode*)rhs;
        if (!outer_aa->base || outer_aa->base->type != ExpressionNode::VARIABLE) return false;
        if (outer_aa->indices.size() != 1) return false;
        detected_dict = ((VariableNode*)outer_aa->base)->name;
        ExpressionNode* idx_expr = outer_aa->indices[0];
        if (idx_expr->type == ExpressionNode::EXPRESSION_CALL) {
            CallExpression* inner_call = (CallExpression*)idx_expr;
            if (inner_call->base_object) return false;
            if (inner_call->arguments.size() != 1) return false;
            if (inner_call->arguments[0]->type != ExpressionNode::VARIABLE) return false;
            String idx_var = ((VariableNode*)inner_call->arguments[0])->name.to_lower();
            if (idx_var != inner->variable_name.to_lower()) return false;
            detected_keys = inner_call->method_name;
        } else if (idx_expr->type == ExpressionNode::ARRAY_ACCESS) {
            ArrayAccessNode* inner_aa = (ArrayAccessNode*)idx_expr;
            if (!inner_aa->base || inner_aa->base->type != ExpressionNode::VARIABLE) return false;
            if (inner_aa->indices.size() != 1 || inner_aa->indices[0]->type != ExpressionNode::VARIABLE) return false;
            String idx_var = ((VariableNode*)inner_aa->indices[0])->name.to_lower();
            if (idx_var != inner->variable_name.to_lower()) return false;
            detected_keys = ((VariableNode*)inner_aa->base)->name;
        } else {
            return false;
        }
    } else {
        return false;
    }
    // dict must be a sole-owner dictionary (uses VGFastStringDict)
    if (!is_sole_owner_dict_var(detected_dict)) return false;
    sum_var = sum_node->name;
    dict_var = detected_dict;
    keys_var = detected_keys;
    iter_var = outer->variable_name;
    return true;
}

// ── Dict-keys-set-sum fusion matcher ──────────────────────────────────
// Matches: For iter = 0 To N: For i = 0 To M: dict(keys(i)) = iter+i; sum = sum + iter + i : Next : Next
// The sum is a double triangle number: sum += sum_{iter=0}^{N} sum_{i=0}^{M} (iter + i)
//   = (N+1)*(M+1) * (N+M) / 2
bool VisualGasicCompiler::is_nested_dict_keys_set_sum(ForStatement* outer, String &sum_var, String &dict_var, String &keys_var, String &iter_var) const {
    auto lit_is_zero = [](const Variant &v) -> bool {
        switch (v.get_type()) {
            case Variant::INT: return (int64_t)v == 0;
            case Variant::BOOL: return !((bool)v);
            case Variant::FLOAT: return Math::is_zero_approx((double)v);
            default: return false;
        }
    };
    auto lit_is_one = [](const Variant &v) -> bool {
        switch (v.get_type()) {
            case Variant::INT: return (int64_t)v == 1;
            case Variant::BOOL: return (bool)v;
            case Variant::FLOAT: return Math::is_equal_approx((double)v, 1.0);
            default: return false;
        }
    };
    if (!outer) return false;
    if (!outer->from_val || outer->from_val->type != ExpressionNode::LITERAL) return false;
    LiteralNode* of = (LiteralNode*)outer->from_val;
    if (!lit_is_zero(of->value)) return false;
    if (outer->step_val) {
        if (outer->step_val->type != ExpressionNode::LITERAL) return false;
        LiteralNode* os = (LiteralNode*)outer->step_val;
        if (!lit_is_one(os->value)) return false;
    }
    ForStatement* inner = nullptr;
    for (int i = 0; i < outer->body.size(); i++) {
        Statement* st = outer->body[i];
        if (!st) continue;
        if (st->type == STMT_LABEL || st->type == STMT_PASS) continue;
        if (st->type == STMT_FOR) {
            if (inner) return false;
            inner = (ForStatement*)st;
            continue;
        }
        return false;
    }
    if (!inner) return false;
    if (!inner->from_val || inner->from_val->type != ExpressionNode::LITERAL) return false;
    LiteralNode* inf = (LiteralNode*)inner->from_val;
    if (!lit_is_zero(inf->value)) return false;
    if (inner->step_val) {
        if (inner->step_val->type != ExpressionNode::LITERAL) return false;
        LiteralNode* ins = (LiteralNode*)inner->step_val;
        if (!lit_is_one(ins->value)) return false;
    }
    // Inner body: exactly 2 statements
    //   1. dict(keys(i)) = iter + i   (SET)
    //   2. sum = sum + iter + i       (SUM accumulation)
    // Filter out labels/passes, count real statements
    Vector<Statement*> real_stmts;
    for (int i = 0; i < inner->body.size(); i++) {
        Statement* st = inner->body[i];
        if (!st) continue;
        if (st->type == STMT_LABEL || st->type == STMT_PASS) continue;
        real_stmts.push_back(st);
    }
    if (real_stmts.size() != 2) return false;

    // --- Identify which statement is the dict SET and which is the sum accumulation ---
    // They can be in either order.
    String detected_dict;
    String detected_keys;
    auto match_dict_keys_target = [&](ExpressionNode* target) -> bool {
        if (target->type == ExpressionNode::EXPRESSION_CALL) {
            CallExpression* outer_call = (CallExpression*)target;
            if (outer_call->base_object) return false;
            if (outer_call->arguments.size() != 1) return false;
            detected_dict = outer_call->method_name;
            ExpressionNode* arg = outer_call->arguments[0];
            if (arg->type == ExpressionNode::EXPRESSION_CALL) {
                CallExpression* inner_call = (CallExpression*)arg;
                if (inner_call->base_object) return false;
                if (inner_call->arguments.size() != 1) return false;
                if (inner_call->arguments[0]->type != ExpressionNode::VARIABLE) return false;
                if (((VariableNode*)inner_call->arguments[0])->name.to_lower() != inner->variable_name.to_lower()) return false;
                detected_keys = inner_call->method_name;
                return true;
            }
            if (arg->type == ExpressionNode::ARRAY_ACCESS) {
                ArrayAccessNode* aa = (ArrayAccessNode*)arg;
                if (!aa->base || aa->base->type != ExpressionNode::VARIABLE) return false;
                if (aa->indices.size() != 1 || aa->indices[0]->type != ExpressionNode::VARIABLE) return false;
                if (((VariableNode*)aa->indices[0])->name.to_lower() != inner->variable_name.to_lower()) return false;
                detected_keys = ((VariableNode*)aa->base)->name;
                return true;
            }
            return false;
        }
        if (target->type == ExpressionNode::ARRAY_ACCESS) {
            // dict(keys(i)) parsed as ARRAY_ACCESS with chained index
            ArrayAccessNode* outer_aa = (ArrayAccessNode*)target;
            if (!outer_aa->base || outer_aa->base->type != ExpressionNode::VARIABLE) return false;
            if (outer_aa->indices.size() != 1) return false;
            detected_dict = ((VariableNode*)outer_aa->base)->name;
            ExpressionNode* idx = outer_aa->indices[0];
            if (idx->type == ExpressionNode::EXPRESSION_CALL) {
                CallExpression* inner_call = (CallExpression*)idx;
                if (inner_call->base_object) return false;
                if (inner_call->arguments.size() != 1) return false;
                if (inner_call->arguments[0]->type != ExpressionNode::VARIABLE) return false;
                if (((VariableNode*)inner_call->arguments[0])->name.to_lower() != inner->variable_name.to_lower()) return false;
                detected_keys = inner_call->method_name;
                return true;
            }
            if (idx->type == ExpressionNode::ARRAY_ACCESS) {
                ArrayAccessNode* inner_aa = (ArrayAccessNode*)idx;
                if (!inner_aa->base || inner_aa->base->type != ExpressionNode::VARIABLE) return false;
                if (inner_aa->indices.size() != 1 || inner_aa->indices[0]->type != ExpressionNode::VARIABLE) return false;
                if (((VariableNode*)inner_aa->indices[0])->name.to_lower() != inner->variable_name.to_lower()) return false;
                detected_keys = ((VariableNode*)inner_aa->base)->name;
                return true;
            }
            return false;
        }
        return false;
    };

    auto match_iter_plus_i = [&](ExpressionNode* expr) -> bool {
        if (!expr || expr->type != ExpressionNode::BINARY_OP) return false;
        BinaryOpNode* b = (BinaryOpNode*)expr;
        if (b->op != "+") return false;
        if (!b->left || b->left->type != ExpressionNode::VARIABLE) return false;
        if (!b->right || b->right->type != ExpressionNode::VARIABLE) return false;
        String l = ((VariableNode*)b->left)->name.to_lower();
        String r = ((VariableNode*)b->right)->name.to_lower();
        return (l == outer->variable_name.to_lower() && r == inner->variable_name.to_lower()) ||
               (r == outer->variable_name.to_lower() && l == inner->variable_name.to_lower());
    };

    auto match_sum_stmt = [&](AssignmentStatement* as_stmt) -> bool {
        if (!as_stmt->target || as_stmt->target->type != ExpressionNode::VARIABLE) return false;
        if (!as_stmt->value) return false;
        // Flatten to additive terms
        Vector<ExpressionNode*> terms;
        auto collect_add_terms = [](ExpressionNode* expr, Vector<ExpressionNode*> &out, auto&& self) -> void {
            if (expr && expr->type == ExpressionNode::BINARY_OP && ((BinaryOpNode*)expr)->op == "+") {
                BinaryOpNode* b = (BinaryOpNode*)expr;
                self(b->left, out, self);
                self(b->right, out, self);
            } else if (expr) {
                out.push_back(expr);
            }
        };
        String sn = ((VariableNode*)as_stmt->target)->name.to_lower();
        collect_add_terms(as_stmt->value, terms, collect_add_terms);
        if (terms.size() != 3) return false;
        bool fs = false, fi = false, fii = false;
        for (int t = 0; t < terms.size(); t++) {
            if (terms[t]->type != ExpressionNode::VARIABLE) return false;
            String vn = ((VariableNode*)terms[t])->name.to_lower();
            if (vn == sn) fs = true;
            else if (vn == outer->variable_name.to_lower()) fi = true;
            else if (vn == inner->variable_name.to_lower()) fii = true;
            else return false;
        }
        return fs && fi && fii;
    };

    // Try both orders: [dict_set, sum_accum] and [sum_accum, dict_set]
    AssignmentStatement* set_as = nullptr;
    AssignmentStatement* sum_as = nullptr;
    String sum_name;

    for (int order = 0; order < 2; order++) {
        AssignmentStatement* candidate_set = (AssignmentStatement*)real_stmts[order];
        AssignmentStatement* candidate_sum = (AssignmentStatement*)real_stmts[1 - order];
        if (!candidate_set || candidate_set->type != STMT_ASSIGNMENT) continue;
        if (!candidate_sum || candidate_sum->type != STMT_ASSIGNMENT) continue;

        detected_dict = String();
        detected_keys = String();
        if (!candidate_set->target || !candidate_set->value) continue;
        if (!match_dict_keys_target(candidate_set->target)) continue;
        if (!match_iter_plus_i(candidate_set->value)) continue;
        if (!match_sum_stmt(candidate_sum)) continue;

        set_as = candidate_set;
        sum_as = candidate_sum;
        sum_name = ((VariableNode*)candidate_sum->target)->name;
        break;
    }

    if (!set_as || !sum_as) return false;

    if (!is_sole_owner_dict_var(detected_dict)) return false;
    sum_var = sum_name;
    dict_var = detected_dict;
    keys_var = detected_keys;
    iter_var = outer->variable_name;
    return true;
}

bool VisualGasicCompiler::is_constant_expr(ExpressionNode* expr) const {
    if (!expr) return false;
    if (expr->type == ExpressionNode::LITERAL) return true;
    if (expr->type == ExpressionNode::VARIABLE) {
        return local_const_map.has(((VariableNode*)expr)->name.to_lower());
    }
    if (expr->type == ExpressionNode::UNARY_OP) {
        UnaryOpNode* u = (UnaryOpNode*)expr;
        return is_constant_expr(u->operand);
    }
    if (expr->type == ExpressionNode::BINARY_OP) {
        BinaryOpNode* b = (BinaryOpNode*)expr;
        return is_constant_expr(b->left) && is_constant_expr(b->right);
    }
    if (expr->type == ExpressionNode::ARRAY_ACCESS) {
        ArrayAccessNode* aa = (ArrayAccessNode*)expr;
        if (!aa->base || aa->base->type != ExpressionNode::VARIABLE) {
            return false;
        }
        String name = ((VariableNode*)aa->base)->name.to_lower();
        if (name == "cdbl" || name == "clng" || name == "cint" || name == "csng") {
            return aa->indices.size() == 1 && is_constant_expr(aa->indices[0]);
        }
        if (name == "color") {
            if (aa->indices.size() < 3) {
                return false;
            }
            for (int i = 0; i < aa->indices.size(); i++) {
                if (!is_constant_expr(aa->indices[i])) {
                    return false;
                }
            }
            return true;
        }
    }
    return false;
}

Variant VisualGasicCompiler::eval_constant_expr(ExpressionNode* expr) const {
    if (!expr) return Variant();
    if (expr->type == ExpressionNode::LITERAL) {
        return ((LiteralNode*)expr)->value;
    }
    if (expr->type == ExpressionNode::VARIABLE) {
        String lower = ((VariableNode*)expr)->name.to_lower();
        if (local_const_map.has(lower)) {
            return local_const_map[lower];
        }
    }
    if (expr->type == ExpressionNode::ARRAY_ACCESS) {
        ArrayAccessNode* aa = (ArrayAccessNode*)expr;
        if (aa->base && aa->base->type == ExpressionNode::VARIABLE) {
            String name = ((VariableNode*)aa->base)->name.to_lower();
            if (name == "cdbl" && aa->indices.size() == 1) {
                return Variant((double)eval_constant_expr(aa->indices[0]));
            }
            if (name == "clng" && aa->indices.size() == 1) {
                return Variant((int64_t)eval_constant_expr(aa->indices[0]));
            }
            if (name == "cint" && aa->indices.size() == 1) {
                return Variant((int)eval_constant_expr(aa->indices[0]));
            }
            if (name == "csng" && aa->indices.size() == 1) {
                return Variant((float)(double)eval_constant_expr(aa->indices[0]));
            }
            if (name == "color" && aa->indices.size() >= 3) {
                double r = (double)eval_constant_expr(aa->indices[0]);
                double g = (double)eval_constant_expr(aa->indices[1]);
                double b = (double)eval_constant_expr(aa->indices[2]);
                double a = aa->indices.size() > 3 ? (double)eval_constant_expr(aa->indices[3]) : 1.0;
                return Variant(Color(r, g, b, a));
            }
        }
    }
    if (expr->type == ExpressionNode::UNARY_OP) {
        UnaryOpNode* u = (UnaryOpNode*)expr;
        Variant v = eval_constant_expr(u->operand);
        if (u->op == "-") return -((double)v);
        if (u->op == "+") return (double)v;
        if (u->op.nocasecmp_to("Not") == 0) return !vg_variant_truthy(v);
        return v;
    }
    if (expr->type == ExpressionNode::BINARY_OP) {
        BinaryOpNode* b = (BinaryOpNode*)expr;
        Variant a = eval_constant_expr(b->left);
        Variant c = eval_constant_expr(b->right);
        bool valid = false;
        Variant res;
        if (b->op == "+") Variant::evaluate(Variant::OP_ADD, a, c, res, valid);
        else if (b->op == "-") Variant::evaluate(Variant::OP_SUBTRACT, a, c, res, valid);
        else if (b->op == "*") Variant::evaluate(Variant::OP_MULTIPLY, a, c, res, valid);
        else if (b->op == "/") Variant::evaluate(Variant::OP_DIVIDE, a, c, res, valid);
        else if (b->op == "&") { valid = true; res = String(a) + String(c); }
        else if (b->op == "=") Variant::evaluate(Variant::OP_EQUAL, a, c, res, valid);
        else if (b->op == "<") Variant::evaluate(Variant::OP_LESS, a, c, res, valid);
        else if (b->op == ">") Variant::evaluate(Variant::OP_GREATER, a, c, res, valid);
        else if (b->op == "<=") Variant::evaluate(Variant::OP_LESS_EQUAL, a, c, res, valid);
        else if (b->op == ">=") Variant::evaluate(Variant::OP_GREATER_EQUAL, a, c, res, valid);
        else if (b->op == "<>") Variant::evaluate(Variant::OP_NOT_EQUAL, a, c, res, valid);
        else if (b->op.nocasecmp_to("And") == 0) {
            // VB6: bitwise when both operands are numeric, logical otherwise
            valid = true;
            if ((a.get_type() == Variant::INT || a.get_type() == Variant::FLOAT) &&
                (c.get_type() == Variant::INT || c.get_type() == Variant::FLOAT)) {
                res = Variant((int64_t)a & (int64_t)c);
            } else {
                res = vg_variant_truthy(a) && vg_variant_truthy(c);
            }
        }
        else if (b->op.nocasecmp_to("Or") == 0) {
            valid = true;
            if ((a.get_type() == Variant::INT || a.get_type() == Variant::FLOAT) &&
                (c.get_type() == Variant::INT || c.get_type() == Variant::FLOAT)) {
                res = Variant((int64_t)a | (int64_t)c);
            } else {
                res = vg_variant_truthy(a) || vg_variant_truthy(c);
            }
        }
        else if (b->op.nocasecmp_to("Xor") == 0) {
            valid = true;
            if ((a.get_type() == Variant::INT || a.get_type() == Variant::FLOAT) &&
                (c.get_type() == Variant::INT || c.get_type() == Variant::FLOAT)) {
                res = Variant((int64_t)a ^ (int64_t)c);
            } else {
                bool left = vg_variant_truthy(a);
                bool right = vg_variant_truthy(c);
                res = (left && !right) || (!left && right);
            }
        }
        else if (b->op.nocasecmp_to("Mod") == 0) {
            valid = true;
            int64_t ai = (int64_t)a;
            int64_t ci = (int64_t)c;
            res = ci != 0 ? (ai % ci) : 0;
        }
        else if (b->op == "\\" || b->op == "\\\\") {
            valid = true;
            int64_t ai = (int64_t)a;
            int64_t ci = (int64_t)c;
            res = ci != 0 ? (ai / ci) : 0;
        }
        else if (b->op == "^" || b->op == "**") {
            valid = true;
            res = UtilityFunctions::pow((double)a, (double)c);
        }
        else if (b->op == "<<") {
            valid = true;
            res = (int64_t)a << (int64_t)c;
        }
        else if (b->op == ">>") {
            valid = true;
            res = (int64_t)a >> (int64_t)c;
        }
        else if (b->op.nocasecmp_to("Like") == 0) {
            // VB6-style Like pattern matching at compile time
            valid = true;
            res = vb_like_match(String(a), String(c));
        }
        else if (b->op.nocasecmp_to("Is") == 0) {
            // Is compares object references (reference equality)
            valid = true;
            Variant::evaluate(Variant::OP_EQUAL, a, c, res, valid);
        }
        else if (b->op.nocasecmp_to("IsNot") == 0) {
            // IsNot compares object reference inequality
            valid = true;
            Variant::evaluate(Variant::OP_NOT_EQUAL, a, c, res, valid);
        }
        if (valid) return res;
    }
    return Variant();
}

bool VisualGasicCompiler::try_constant_f64(ExpressionNode* expr, double &r_out) const {
    if (!is_constant_expr(expr)) {
        return false;
    }
    Variant v = eval_constant_expr(expr);
    r_out = (double)v;
    return true;
}

bool VisualGasicCompiler::try_constant_bool(ExpressionNode* expr, bool &r_out) const {
    if (!is_constant_expr(expr)) {
        return false;
    }
    r_out = vg_variant_truthy(eval_constant_expr(expr));
    return true;
}

bool VisualGasicCompiler::try_constant_color(ExpressionNode* expr, Color &r_out) const {
    if (!is_constant_expr(expr)) {
        return false;
    }
    Variant v = eval_constant_expr(expr);
    if (v.get_type() != Variant::COLOR) {
        return false;
    }
    r_out = v;
    return true;
}

bool VisualGasicCompiler::try_find_invariant_draw_color(const Vector<Statement*> &body, Variant &r_color) const {
    bool found = false;
    Variant candidate;
    for (int i = 0; i < body.size(); i++) {
        Statement *stmt = body[i];
        if (!stmt || stmt->type != STMT_CALL) {
            continue;
        }
        CallStatement *cs = (CallStatement *)stmt;
        if (cs->base_object) {
            continue;
        }
        if (cs->method_name.nocasecmp_to("DrawRect") != 0 &&
                cs->method_name.nocasecmp_to("DrawLine") != 0) {
            continue;
        }
        if (cs->arguments.size() < 5) {
            continue;
        }
        if (!is_constant_expr(cs->arguments[4])) {
            continue;
        }
        Variant c = eval_constant_expr(cs->arguments[4]);
        if (!found) {
            candidate = c;
            found = true;
        } else if (candidate != c) {
            return false;
        }
    }
    if (found) {
        r_color = candidate;
    }
    return found;
}

bool VisualGasicCompiler::try_emit_draw_rect_f64(const Vector<ExpressionNode*> &args) {
    if (args.size() != 6) {
        return false;
    }
    double w = 0.0;
    double h = 0.0;
    Color col;
    bool filled = true;
    if (!try_constant_f64(args[2], w)) {
        return false;
    }
    if (!try_constant_f64(args[3], h)) {
        return false;
    }
    if (!try_constant_color(args[4], col)) {
        return false;
    }
    if (!try_constant_bool(args[5], filled)) {
        return false;
    }
    compile_expression(args[0]);
    compile_expression(args[1]);
    int cidx = current_chunk->add_constant(col);
    emit_byte(OP_DRAW_RECT_F64);
    emit_f32((float)w);
    emit_f32((float)h);
    emit_const_index(cidx);
    emit_byte(filled ? 1 : 0);
    return true;
}

bool VisualGasicCompiler::try_emit_draw_line_f64(const Vector<ExpressionNode*> &args) {
    if (args.size() != 6) {
        return false;
    }
    Color col;
    double width = 0.0;
    if (!try_constant_color(args[4], col)) {
        return false;
    }
    if (!try_constant_f64(args[5], width)) {
        return false;
    }
    for (int i = 0; i < 4; i++) {
        compile_expression(args[i]);
    }
    int cidx = current_chunk->add_constant(col);
    emit_byte(OP_DRAW_LINE_F64);
    emit_f32((float)width);
    emit_const_index(cidx);
    return true;
}

SubDefinition *VisualGasicCompiler::find_sub_by_name(const String &p_name) const {
    if (!current_module) {
        return nullptr;
    }
    for (int i = 0; i < current_module->subs.size(); i++) {
        if (current_module->subs[i]->name.nocasecmp_to(p_name) == 0) {
            return current_module->subs[i];
        }
    }
    return nullptr;
}

static ExpressionNode *_vg_unwrap_cdbl(ExpressionNode *p_expr) {
    if (!p_expr || p_expr->type != ExpressionNode::EXPRESSION_CALL) {
        return p_expr;
    }
    CallExpression *call = (CallExpression *)p_expr;
    if (call->base_object || call->method_name.nocasecmp_to("CDbl") != 0 || call->arguments.size() != 1) {
        return p_expr;
    }
    return call->arguments[0];
}

bool VisualGasicCompiler::try_const_i64_from_expr(ExpressionNode *p_expr, int64_t &r_out) const {
    if (!p_expr || !is_constant_expr(p_expr)) {
        return false;
    }
    Variant v = eval_constant_expr(p_expr);
    switch (v.get_type()) {
        case Variant::INT:
            r_out = (int64_t)v;
            return true;
        case Variant::FLOAT: {
            double d = (double)v;
            double rounded = Math::round(d);
            if (Math::is_equal_approx(d, rounded)) {
                r_out = (int64_t)rounded;
                return true;
            }
            return false;
        }
        case Variant::BOOL:
            r_out = ((bool)v) ? 1 : 0;
            return true;
        default:
            return false;
    }
}

bool VisualGasicCompiler::try_parse_grid_axis_sub(const String &p_name, bool p_want_x, int64_t &r_cols, int64_t &r_cell) const {
    SubDefinition *sub = find_sub_by_name(p_name);
    if (!sub || sub->type != SubDefinition::TYPE_FUNCTION || sub->parameters.size() != 1) {
        return false;
    }
    if (sub->statements.size() != 1 || sub->statements[0]->type != STMT_ASSIGNMENT) {
        return false;
    }
    AssignmentStatement *as = (AssignmentStatement *)sub->statements[0];
    if (!as->target || as->target->type != ExpressionNode::VARIABLE) {
        return false;
    }
    if (((VariableNode *)as->target)->name.nocasecmp_to(sub->name) != 0 || !as->value) {
        return false;
    }

    ExpressionNode *value = as->value;
    if (value->type != ExpressionNode::BINARY_OP) {
        return false;
    }
    BinaryOpNode *mul = (BinaryOpNode *)value;
    if (mul->op != "*") {
        return false;
    }
    if (!try_const_i64_from_expr(_vg_unwrap_cdbl(mul->right), r_cell)) {
        return false;
    }

    ExpressionNode *axis = _vg_unwrap_cdbl(mul->left);
    if (axis->type != ExpressionNode::BINARY_OP) {
        return false;
    }
    BinaryOpNode *axis_op = (BinaryOpNode *)axis;
    const String param_name = sub->parameters[0].name.to_lower();
    if (p_want_x) {
        if (axis_op->op != "Mod") {
            return false;
        }
    } else {
        if (axis_op->op != "\\") {
            return false;
        }
    }
    if (!axis_op->left || axis_op->left->type != ExpressionNode::VARIABLE) {
        return false;
    }
    if (((VariableNode *)axis_op->left)->name.to_lower() != param_name) {
        return false;
    }
    return try_const_i64_from_expr(axis_op->right, r_cols);
}

bool VisualGasicCompiler::try_emit_grid_axis_inline(const String &p_func_name, const Vector<ExpressionNode*> &args, bool p_want_x) {
    int64_t cols = 0;
    int64_t cell = 0;
    if (!try_parse_grid_axis_sub(p_func_name, p_want_x, cols, cell)) {
        return false;
    }
    if (args.size() != 1) {
        return false;
    }
    compile_expression(args[0]);
    emit_constant(Variant((int64_t)cols));
    emit_byte(p_want_x ? OP_MOD : OP_INT_DIVIDE);
    emit_constant(Variant((double)cell));
    emit_byte(OP_MUL_F64);
    return true;
}

bool VisualGasicCompiler::try_emit_draw_circle_f64(const Vector<ExpressionNode*> &args) {
    if (args.size() != 4) {
        return false;
    }
    double radius = 0.0;
    Color col;
    if (!try_constant_f64(args[2], radius)) {
        return false;
    }
    if (!try_constant_color(args[3], col)) {
        return false;
    }
    compile_expression(args[0]);
    compile_expression(args[1]);
    int cidx = current_chunk->add_constant(col);
    emit_byte(OP_DRAW_CIRCLE_F64);
    emit_f32((float)radius);
    emit_const_index(cidx);
    return true;
}

bool VisualGasicCompiler::try_emit_draw_texture_rect_f64(const Vector<ExpressionNode*> &args) {
    if (args.size() < 5) {
        return false;
    }
    double w = 0.0;
    double h = 0.0;
    bool tile = false;
    if (!try_constant_f64(args[3], w)) {
        return false;
    }
    if (!try_constant_f64(args[4], h)) {
        return false;
    }
    if (args.size() > 5 && !try_constant_bool(args[5], tile)) {
        return false;
    }
    if (args[0]->type != ExpressionNode::VARIABLE) {
        return false;
    }
    String tex_name = ((VariableNode *)args[0])->name;
    int tex_idx = current_chunk->add_constant(tex_name);
    compile_expression(args[1]);
    compile_expression(args[2]);
    emit_byte(OP_DRAW_TEXTURE_RECT_F64);
    emit_const_index(tex_idx);
    emit_f32((float)w);
    emit_f32((float)h);
    emit_byte(tile ? 1 : 0);
    return true;
}

bool VisualGasicCompiler::is_grid_axis_assign(Statement *p_stmt, const String &p_axis_name, const String &p_loop_var,
        String &r_x_var, String &r_y_var, bool p_want_x) const {
    if (!p_stmt || p_stmt->type != STMT_ASSIGNMENT) {
        return false;
    }
    AssignmentStatement *as = (AssignmentStatement *)p_stmt;
    if (!as->target || as->target->type != ExpressionNode::VARIABLE || !as->value) {
        return false;
    }
    String target = ((VariableNode *)as->target)->name;
    if (as->value->type != ExpressionNode::EXPRESSION_CALL) {
        return false;
    }
    CallExpression *call = (CallExpression *)as->value;
    if (call->base_object || call->method_name.nocasecmp_to(p_axis_name) != 0 || call->arguments.size() != 1) {
        return false;
    }
    ExpressionNode *arg = call->arguments[0];
    if (arg->type != ExpressionNode::VARIABLE) {
        return false;
    }
    if (((VariableNode *)arg)->name.to_lower() != p_loop_var.to_lower()) {
        return false;
    }
    int64_t cols = 0;
    int64_t cell = 0;
    if (!try_parse_grid_axis_sub(p_axis_name, p_want_x, cols, cell)) {
        return false;
    }
    if (p_want_x) {
        r_x_var = target;
    } else {
        r_y_var = target;
    }
    return true;
}

bool VisualGasicCompiler::try_compile_grid_draw_fusion(const Vector<Statement*> &stmts, int &io_i, const String &p_loop_var) {
    if (io_i + 2 >= stmts.size()) {
        return false;
    }
    Statement *s0 = stmts[io_i];
    Statement *s1 = stmts[io_i + 1];
    Statement *s2 = stmts[io_i + 2];
    String x_var;
    String y_var;
    if (!is_grid_axis_assign(s0, "GridX", p_loop_var, x_var, y_var, true)) {
        return false;
    }
    if (!is_grid_axis_assign(s1, "GridY", p_loop_var, x_var, y_var, false)) {
        return false;
    }
    if (!s2 || s2->type != STMT_CALL) {
        return false;
    }
    CallStatement *draw = (CallStatement *)s2;
    if (draw->base_object) {
        return false;
    }

    int64_t cols = 0;
    int64_t cell = 0;
    if (!try_parse_grid_axis_sub("GridX", true, cols, cell)) {
        return false;
    }

    int loop_slot = get_or_add_local(p_loop_var, VT_INT);
    if (loop_slot < 0) {
        return false;
    }
    int x_slot = get_or_add_local(x_var, VT_UNKNOWN);
    int y_slot = get_or_add_local(y_var, VT_UNKNOWN);
    if (x_slot < 0 || y_slot < 0) {
        return false;
    }

    emit_bytes(OP_GET_LOCAL, (uint8_t)loop_slot);

    if (draw->method_name.nocasecmp_to("DrawRect") == 0) {
        if (draw->arguments.size() != 6) {
            return false;
        }
        if (draw->arguments[0]->type != ExpressionNode::VARIABLE ||
                draw->arguments[1]->type != ExpressionNode::VARIABLE) {
            return false;
        }
        if (((VariableNode *)draw->arguments[0])->name.to_lower() != x_var.to_lower() ||
                ((VariableNode *)draw->arguments[1])->name.to_lower() != y_var.to_lower()) {
            return false;
        }
        double w = 0.0;
        double h = 0.0;
        Color col;
        bool filled = true;
        if (!try_constant_f64(draw->arguments[2], w) ||
                !try_constant_f64(draw->arguments[3], h) ||
                !try_constant_color(draw->arguments[4], col) ||
                !try_constant_bool(draw->arguments[5], filled)) {
            return false;
        }
        int cidx = current_chunk->add_constant(col);
        emit_byte(OP_DRAW_RECT_GRID_IDX);
        emit_i32((int32_t)cols);
        emit_i32((int32_t)cell);
        emit_f32((float)w);
        emit_f32((float)h);
        emit_const_index(cidx);
        emit_byte(filled ? 1 : 0);
    } else if (draw->method_name.nocasecmp_to("DrawLine") == 0) {
        if (draw->arguments.size() != 6) {
            return false;
        }
        if (draw->arguments[0]->type != ExpressionNode::VARIABLE ||
                draw->arguments[1]->type != ExpressionNode::VARIABLE) {
            return false;
        }
        if (((VariableNode *)draw->arguments[0])->name.to_lower() != x_var.to_lower() ||
                ((VariableNode *)draw->arguments[1])->name.to_lower() != y_var.to_lower()) {
            return false;
        }
        double x2_delta = 0.0;
        double y2_delta = 0.0;
        Color col;
        double width = 0.0;
        if (draw->arguments[2]->type != ExpressionNode::BINARY_OP ||
                draw->arguments[3]->type != ExpressionNode::BINARY_OP) {
            return false;
        }
        BinaryOpNode *x2 = (BinaryOpNode *)draw->arguments[2];
        BinaryOpNode *y2 = (BinaryOpNode *)draw->arguments[3];
        if (x2->op != "+" || y2->op != "+") {
            return false;
        }
        if (!x2->left || x2->left->type != ExpressionNode::VARIABLE ||
                ((VariableNode *)x2->left)->name.to_lower() != x_var.to_lower()) {
            return false;
        }
        if (!y2->left || y2->left->type != ExpressionNode::VARIABLE ||
                ((VariableNode *)y2->left)->name.to_lower() != y_var.to_lower()) {
            return false;
        }
        if (!try_constant_f64(x2->right, x2_delta) ||
                !try_constant_f64(y2->right, y2_delta) ||
                !try_constant_color(draw->arguments[4], col) ||
                !try_constant_f64(draw->arguments[5], width)) {
            return false;
        }
        int cidx = current_chunk->add_constant(col);
        emit_byte(OP_DRAW_LINE_GRID_IDX);
        emit_i32((int32_t)cols);
        emit_i32((int32_t)cell);
        emit_f32((float)x2_delta);
        emit_f32((float)y2_delta);
        emit_f32((float)width);
        emit_const_index(cidx);
    } else if (draw->method_name.nocasecmp_to("DrawCircle") == 0) {
        if (draw->arguments.size() != 4) {
            return false;
        }
        double ox = 0.0;
        double oy = 0.0;
        double radius = 0.0;
        Color col;
        if (draw->arguments[0]->type != ExpressionNode::BINARY_OP ||
                draw->arguments[1]->type != ExpressionNode::BINARY_OP) {
            return false;
        }
        BinaryOpNode *cx = (BinaryOpNode *)draw->arguments[0];
        BinaryOpNode *cy = (BinaryOpNode *)draw->arguments[1];
        if (cx->op != "+" || cy->op != "+") {
            return false;
        }
        if (!cx->left || cx->left->type != ExpressionNode::VARIABLE ||
                ((VariableNode *)cx->left)->name.to_lower() != x_var.to_lower()) {
            return false;
        }
        if (!cy->left || cy->left->type != ExpressionNode::VARIABLE ||
                ((VariableNode *)cy->left)->name.to_lower() != y_var.to_lower()) {
            return false;
        }
        if (!try_constant_f64(cx->right, ox) ||
                !try_constant_f64(cy->right, oy) ||
                !try_constant_f64(draw->arguments[2], radius) ||
                !try_constant_color(draw->arguments[3], col)) {
            return false;
        }
        int cidx = current_chunk->add_constant(col);
        emit_byte(OP_DRAW_CIRCLE_GRID_IDX);
        emit_i32((int32_t)cols);
        emit_i32((int32_t)cell);
        emit_f32((float)ox);
        emit_f32((float)oy);
        emit_f32((float)radius);
        emit_const_index(cidx);
    } else if (draw->method_name.nocasecmp_to("DrawTextureRect") == 0) {
        if (draw->arguments.size() < 5) {
            return false;
        }
        if (draw->arguments[1]->type != ExpressionNode::VARIABLE ||
                draw->arguments[2]->type != ExpressionNode::VARIABLE) {
            return false;
        }
        if (((VariableNode *)draw->arguments[1])->name.to_lower() != x_var.to_lower() ||
                ((VariableNode *)draw->arguments[2])->name.to_lower() != y_var.to_lower()) {
            return false;
        }
        if (draw->arguments[0]->type != ExpressionNode::VARIABLE) {
            return false;
        }
        double w = 0.0;
        double h = 0.0;
        bool tile = false;
        if (!try_constant_f64(draw->arguments[3], w) ||
                !try_constant_f64(draw->arguments[4], h)) {
            return false;
        }
        if (draw->arguments.size() > 5 && !try_constant_bool(draw->arguments[5], tile)) {
            return false;
        }
        String tex_name = ((VariableNode *)draw->arguments[0])->name;
        int tex_idx = current_chunk->add_constant(tex_name);
        emit_byte(OP_DRAW_TEXTURE_RECT_GRID_IDX);
        emit_const_index(tex_idx);
        emit_i32((int32_t)cols);
        emit_i32((int32_t)cell);
        emit_f32((float)w);
        emit_f32((float)h);
        emit_byte(tile ? 1 : 0);
    } else {
        return false;
    }

    emit_bytes(OP_SET_LOCAL, (uint8_t)y_slot);
    emit_bytes(OP_SET_LOCAL, (uint8_t)x_slot);
    io_i += 3;
    return true;
}

bool VisualGasicCompiler::try_emit_draw_call(CallStatement *s, SubDefinition *target_func, bool discard_result) {
    if (!s || s->base_object || target_func) {
        return false;
    }
    if (s->method_name.nocasecmp_to("DrawRect") == 0) {
        if (try_emit_draw_rect_f64(s->arguments)) {
            if (discard_result) {
                emit_byte(OP_POP);
            }
            return true;
        }
        for (int i = 0; i < s->arguments.size(); i++) {
            if (i == 4 && _draw_invariant_color_slot >= 0) {
                emit_bytes(OP_GET_LOCAL, (uint8_t)_draw_invariant_color_slot);
            } else {
                compile_expression(s->arguments[i]);
            }
        }
        emit_byte(OP_DRAW_RECT);
        emit_byte((uint8_t)s->arguments.size());
        if (discard_result) {
            emit_byte(OP_POP);
        }
        return true;
    }
    if (s->method_name.nocasecmp_to("DrawLine") == 0) {
        if (try_emit_draw_line_f64(s->arguments)) {
            if (discard_result) {
                emit_byte(OP_POP);
            }
            return true;
        }
        for (int i = 0; i < s->arguments.size(); i++) {
            if (i == 4 && _draw_invariant_color_slot >= 0) {
                emit_bytes(OP_GET_LOCAL, (uint8_t)_draw_invariant_color_slot);
            } else {
                compile_expression(s->arguments[i]);
            }
        }
        emit_byte(OP_DRAW_LINE);
        emit_byte((uint8_t)s->arguments.size());
        if (discard_result) {
            emit_byte(OP_POP);
        }
        return true;
    }
    if (s->method_name.nocasecmp_to("DrawCircle") == 0) {
        if (try_emit_draw_circle_f64(s->arguments)) {
            if (discard_result) {
                emit_byte(OP_POP);
            }
            return true;
        }
    }
    if (s->method_name.nocasecmp_to("DrawTextureRect") == 0) {
        if (try_emit_draw_texture_rect_f64(s->arguments)) {
            if (discard_result) {
                emit_byte(OP_POP);
            }
            return true;
        }
    }
    return false;
}

VisualGasicCompiler::ValueType VisualGasicCompiler::infer_type(ExpressionNode* expr) const {
    if (!expr) return VT_UNKNOWN;
    if (expr->type == ExpressionNode::LITERAL) {
        Variant v = ((LiteralNode*)expr)->value;
        if (v.get_type() == Variant::INT) return VT_INT;
        if (v.get_type() == Variant::FLOAT) return VT_FLOAT;
        return VT_UNKNOWN;
    }
    if (expr->type == ExpressionNode::VARIABLE) {
        String key = ((VariableNode*)expr)->name.to_lower();
        if (local_types.has(key)) return local_types[key];
        return VT_UNKNOWN;
    }
    if (expr->type == ExpressionNode::UNARY_OP) {
        UnaryOpNode* u = (UnaryOpNode*)expr;
        return infer_type(u->operand);
    }
    if (expr->type == ExpressionNode::BINARY_OP) {
        BinaryOpNode* b = (BinaryOpNode*)expr;
        ValueType lt = infer_type(b->left);
        ValueType rt = infer_type(b->right);
        if (b->op == "/") return VT_FLOAT;
        if (lt == VT_FLOAT || rt == VT_FLOAT) return VT_FLOAT;
        if (lt == VT_INT && rt == VT_INT) return VT_INT;
        return VT_UNKNOWN;
    }
    if (expr->type == ExpressionNode::ARRAY_ACCESS) {
        ArrayAccessNode* aa = (ArrayAccessNode*)expr;
        if (aa->base && aa->base->type == ExpressionNode::VARIABLE) {
            String key = ((VariableNode*)aa->base)->name.to_lower();
            if (array_types.has(key)) return array_types[key];
        }
        return VT_UNKNOWN;
    }
    return VT_UNKNOWN;
}

// Pass 2: detect Camera./Sound./Speaker. namespace calls.
// Returns the lowercase namespace name ("camera"/"sound"/"speaker") if
// base_obj is a bare VariableNode with one of those reserved names AND
// that name has not been shadowed by a local/param/array/dict variable.
// Returns "" otherwise. "Bus" is accepted as a silent alias for "Speaker"
// (Godot's native term) — both compile to speaker_* builtins.
//
// When a namespace match is found, the caller should compile the args and
// emit OP_CALL to "<ns>_<lower_method>" instead of OP_METHOD_CALL.
String VisualGasicCompiler::detect_namespace_call(ExpressionNode* base_obj) const {
    if (!base_obj) return String();

    auto resolve_namespace_root = [&](const String &p_name) -> String {
        String lo = p_name.to_lower();
        if (lo == "bus") lo = "speaker"; // alias
        if (lo != "camera" && lo != "sound" && lo != "speaker" &&
            // Pass 3 namespaces
            lo != "animation" && lo != "physics" && lo != "ray" &&
            lo != "cell" && lo != "nav" &&
            // Pass 4 namespaces (app platform / phone sensors)
            lo != "screen" && lo != "joypad" && lo != "touch" &&
            lo != "sensor" && lo != "permission" && lo != "gps" &&
            lo != "steps" &&
            // Pass 5 namespaces (crypto/theme/js/shader/material/skeleton/bone/video)
            lo != "crypto" && lo != "theme" && lo != "js" &&
            lo != "shader" && lo != "material" && lo != "skeleton" &&
            lo != "bone" && lo != "video" &&
            // Audio synthesis namespaces
            lo != "soundgen" && lo != "music" && lo != "tracker") {
            return String();
        }
        // Not shadowed by a known variable.
        String orig_lo = p_name.to_lower();
        if (local_slots.has(orig_lo) || param_vars.has(orig_lo) ||
            array_vars.has(orig_lo) || dictionary_vars.has(orig_lo)) {
            return String();
        }
        return lo;
    };

    // Speaker.Bus.* — documented alias; treat as Speaker namespace.
    if (base_obj->type == ExpressionNode::MEMBER_ACCESS) {
        MemberAccessNode *ma = (MemberAccessNode *)base_obj;
        if (ma->base_object && ma->base_object->type == ExpressionNode::VARIABLE) {
            String base_name = ((VariableNode *)ma->base_object)->name;
            if (base_name.to_lower() == "speaker" && ma->member_name.to_lower() == "bus") {
                return resolve_namespace_root(base_name);
            }
        }
        return String();
    }

    if (base_obj->type != ExpressionNode::VARIABLE) return String();
    return resolve_namespace_root(((VariableNode *)base_obj)->name);
}


// ====== M6: Select Case Jump Table Optimization ============================
// Attempts to compile a Select Case using the O(1) OP_JUMP_TABLE bytecode.
// Returns true if successful, false if the case structure isn't suitable.
bool VisualGasicCompiler::try_compile_jump_table(SelectStatement* s) {
    int64_t jt_min, jt_max;
    int jt_count;
    // 1. Heuristic check
    {
        jt_min = INT64_MAX;
        jt_max = INT64_MIN;
        int case_count = 0;
        for (int i = 0; i < s->cases.size(); i++) {
            CaseBlock* cb = s->cases[i];
            if (cb->is_else) continue;
            // Check that all values are simple literals (no ranges or comparison ops)
            for (int r = 0; r < cb->range_ends.size(); r++)
                if (cb->range_ends[r] != nullptr) return false;
            bool _jt_has_comp_op = false;
            for (int _co = 0; _co < cb->comparison_ops.size(); _co++) if (!cb->comparison_ops[_co].is_empty()) { _jt_has_comp_op = true; break; }
            if (_jt_has_comp_op) return false;
            // Process all values in this case (supports multi-value cases)
            for (int v = 0; v < cb->values.size(); v++) {
                ExpressionNode* e = cb->values[v];
                if (!e || e->type != ExpressionNode::LITERAL) return false;
                LiteralNode* lit = static_cast<LiteralNode*>(e);
                if (lit->value.get_type() != Variant::INT) return false;
                int64_t val = (int64_t)lit->value;
                if (val < jt_min) jt_min = val;
                if (val > jt_max) jt_max = val;
                case_count++;
            }
        }
        if (case_count < 8) return false;
        int64_t range = jt_max - jt_min + 1;
        if (range < 1 || range > 65535) return false;
        float density = (float)case_count / (float)range;
        if (density < 0.30f) return false;
        // The table is INDEXED by (value - jt_min), so it must have one slot per
        // value across the whole [jt_min, jt_max] range — NOT one slot per case.
        // Using case_count here (when the cases are sparse) makes the table too
        // short: the VM's bounds check (idx < num_cases) then wrongly routes any
        // value where (value - jt_min) >= case_count to the default/Case Else.
        // Missing slots are filled with default_off in step 7 below.
        jt_count = (int)range;
    }

    // 2. Compile expression and emit jump table
    int jt_slot = get_or_add_local(String("__jtsel_") + String::num_int64(temp_local_id++),
                                   infer_type(s->expression));
    compile_expression(s->expression);
    emit_bytes(OP_SET_LOCAL, (uint8_t)jt_slot);
    emit_bytes(OP_GET_LOCAL, (uint8_t)jt_slot);
    emit_byte(OP_JUMP_TABLE);

    int min_cix = current_chunk->add_constant(Variant(jt_min));
    int max_cix = current_chunk->add_constant(Variant(jt_max));
    emit_bytes((uint8_t)(min_cix & 0xFF), (uint8_t)((min_cix >> 8) & 0xFF));
    emit_bytes((uint8_t)(max_cix & 0xFF), (uint8_t)((max_cix >> 8) & 0xFF));

    int def_pos = current_chunk->code.size();
    emit_bytes(0, 0);  // default_offset (patched later)
    emit_bytes((uint8_t)(jt_count & 0xFF), (uint8_t)((jt_count >> 8) & 0xFF));

    int table_start = current_chunk->code.size();
    for (int ti = 0; ti < jt_count; ti++) emit_bytes(0, 0);
    int table_end = current_chunk->code.size();

    // 3. Build value-to-case-index map (handles multi-value cases)
    HashMap<int64_t, int> vmap;
    for (int ci = 0; ci < s->cases.size(); ci++) {
        CaseBlock* cb = s->cases[ci];
        if (!cb->is_else) {
            // Map all values in this case to the same case index
            for (int v = 0; v < cb->values.size(); v++) {
                ExpressionNode* e = cb->values[v];
                if (e && e->type == ExpressionNode::LITERAL) {
                    LiteralNode* lit = static_cast<LiteralNode*>(e);
                    if (lit->value.get_type() == Variant::INT)
                        vmap[(int64_t)lit->value] = ci;
                }
            }
        }
    }

    // 4. Find Case Else index
    int else_idx = -1;
    for (int ci = 0; ci < s->cases.size(); ci++) {
        if (s->cases[ci]->is_else) { else_idx = ci; break; }
    }

    // 5. Compile case bodies and record slot offsets (relative to table_end)
    // Track which case indices have already been compiled to avoid duplication
    HashMap<int, int> case_idx_to_offset;
    Vector<int> offsets;
    offsets.resize(jt_count);
    Vector<int> end_jumps;
    
    for (int slot = 0; slot < jt_count; slot++) {
        if (vmap.has(jt_min + (int64_t)slot)) {
            int case_idx = vmap[jt_min + (int64_t)slot];
            
            // If this case has already been compiled, reuse its offset
            if (case_idx_to_offset.has(case_idx)) {
                offsets.write[slot] = case_idx_to_offset[case_idx];
            } else {
                // First time seeing this case: compile it and record offset
                offsets.write[slot] = current_chunk->code.size() - table_end;
                case_idx_to_offset[case_idx] = offsets[slot];
                
                CaseBlock* cb = s->cases[case_idx];
                for (int bj = 0; bj < cb->body.size(); bj++)
                    compile_statement(cb->body[bj]);
                // Emit a jump to skip to end of Select
                end_jumps.push_back(emit_jump(OP_JUMP));
            }
        }
    }

    // 6. Compile Case Else (default)
    int else_start = current_chunk->code.size();
    if (else_idx >= 0) {
        CaseBlock* cb = s->cases[else_idx];
        for (int bj = 0; bj < cb->body.size(); bj++)
            compile_statement(cb->body[bj]);
    }

    // Patch all per-case end-of-body jumps to land here, after Case Else.
    for (int i = 0; i < end_jumps.size(); i++) {
        patch_jump(end_jumps[i]);
    }

    // 7. Backpatch default_offset and slot offsets
    int16_t default_off = (int16_t)(else_start - table_end);
    current_chunk->code.write[def_pos] = (uint8_t)(default_off & 0xFF);
    current_chunk->code.write[def_pos + 1] = (uint8_t)((default_off >> 8) & 0xFF);

    for (int slot = 0; slot < jt_count; slot++) {
        int16_t off = vmap.has(jt_min + (int64_t)slot) ? (int16_t)offsets[slot] : default_off;
        int pp = table_start + slot * 2;
        current_chunk->code.write[pp] = (uint8_t)(off & 0xFF);
        current_chunk->code.write[pp + 1] = (uint8_t)((off >> 8) & 0xFF);
    }

    compile_ok = true;
    return true;
}
// ===========================================================================

// ByRef write-back emission (v6.2). After an OP_CALL to target_func, write the
// callee's post-call value of each ByRef scalar parameter back into the caller's
// matching variable argument. Each param emits OP_BYREF_LOAD <param_name_const>
// <is_global> <dest> (pushes the captured post-call value, or the destination's
// current value if no capture was recorded — see OP_BYREF_LOAD's format comment
// in visual_gasic_bytecode.h) followed by the normal store opcode for that
// variable (OP_SET_LOCAL / OP_SET_GLOBAL) using the SAME destination. The
// push+store pair is net-zero on the stack, so this is safe to emit both in
// statement context (after OP_POP) and expression context (immediately after
// OP_CALL, leaving the return value beneath). Mirrors the AST interpreter's
// ByRef write-back so Subs that make ByRef calls stay on the fast bytecode path
// instead of falling back to the tree-walk interpreter.
//
// NOTE: target_func is resolved by a name+arity scan and can, in rare cases,
// point at a Sub/Function that ISN'T actually what runs at runtime — e.g. a
// builtin of the same name always wins over a user-defined Sub/Function with a
// matching name (see call dispatch in visual_gasic_builtins.cpp). When that
// happens, _last_byref_captures is never populated for these params, and
// OP_BYREF_LOAD falls back to re-storing the destination's own current value
// (a no-op) instead of corrupting it with Nil.
void VisualGasicCompiler::emit_byref_writebacks(SubDefinition* target_func, const Vector<ExpressionNode*>& arguments) {
    if (!target_func) return;
    int param_count = target_func->parameters.size();
    for (int j = 0; j < param_count && j < arguments.size(); j++) {
        const Parameter& p = target_func->parameters[j];
        // Only ByRef scalar params bound to a plain variable or array slot are
        // written back. ParamArray params (which absorb multiple args) are skipped,
        // the STMT_CALL path bails on ParamArray before ever reaching here.
        if (!p.is_by_ref || p.is_param_array) continue;
        ExpressionNode* arg = arguments[j];
        if (!arg) continue;
        int pidx = current_chunk->add_constant(p.name);
        if (arg->type == ExpressionNode::VARIABLE) {
        String argname = ((VariableNode*)arg)->name;
        // A procedure-scoped Const inlines its literal value when read — there is
        // no storage location to write back to, so skip it.
        if (local_const_map.has(argname.to_lower())) continue;
        // Push the callee's post-call value for this parameter name (or the
        // destination's current value as a fallback — see OP_BYREF_LOAD).
        // Resolve the SAME local/global decision the read path used when the
        // argument was read from — and so OP_BYREF_LOAD can find the current
        // value there if no write-back was actually captured.
        int slot = get_or_add_local(argname, VT_UNKNOWN);
        emit_byte(OP_BYREF_LOAD);
        emit_const_index(pidx);
        if (slot >= 0) {
            emit_byte(0); // dest is a local slot
            emit_byte((uint8_t)(slot & 0xFF));
            emit_byte((uint8_t)((slot >> 8) & 0xFF));
            emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
        } else {
            int nidx = current_chunk->add_constant(argname);
            emit_byte(1); // dest is a global name const index
            emit_byte((uint8_t)(nidx & 0xFF));
            emit_byte((uint8_t)((nidx >> 8) & 0xFF));
            emit_byte(OP_SET_GLOBAL);
            emit_const_index(nidx);
        }
        } else if (arg->type == ExpressionNode::ARRAY_ACCESS) {
            ArrayAccessNode* aa = (ArrayAccessNode*)arg;
            if (aa->indices.size() != 1 || !aa->base || aa->base->type != ExpressionNode::VARIABLE) continue;
            VariableNode* base_var = (VariableNode*)aa->base;
            String argname = base_var->name;
            if (local_const_map.has(argname.to_lower())) continue;
            int slot = get_or_add_local(argname, VT_UNKNOWN);
            emit_byte(OP_BYREF_LOAD);
            emit_const_index(pidx);
            if (slot >= 0) {
                emit_byte(0);
                emit_byte((uint8_t)(slot & 0xFF));
                emit_byte((uint8_t)((slot >> 8) & 0xFF));
            } else {
                int nidx = current_chunk->add_constant(argname);
                emit_byte(1);
                emit_byte((uint8_t)(nidx & 0xFF));
                emit_byte((uint8_t)((nidx >> 8) & 0xFF));
            }
            // Stack: [byref_value] — rearrange to [array, index, value] for OP_SET_ARRAY
            int temp_slot = get_or_add_local("__byref_wb_" + String::num_int64(temp_local_id++), VT_UNKNOWN);
            emit_bytes(OP_SET_LOCAL, (uint8_t)temp_slot);
            compile_expression(aa->base);
            compile_expression(aa->indices[0]);
            emit_bytes(OP_GET_LOCAL, (uint8_t)temp_slot);
            emit_byte(OP_SET_ARRAY);
            emit_byte(1);
            if (slot >= 0) {
                emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
            } else {
                int nidx = current_chunk->add_constant(argname);
                emit_byte(OP_SET_GLOBAL);
                emit_const_index(nidx);
            }
        } else if (arg->type == ExpressionNode::EXPRESSION_CALL) {
            // parse_expression() represents arr(i) as CallExpression("arr", [i]).
            CallExpression* call = (CallExpression*)arg;
            if (call->base_object || call->arguments.size() != 1) continue;
            String argname = call->method_name;
            String key = argname.to_lower();
            if (local_const_map.has(key)) continue;
            if (!array_vars.has(key) && !dictionary_vars.has(key) &&
                    !local_slots.has(key) && !param_vars.has(key) && !is_buffer_var(argname)) {
                continue;
            }
            int slot = get_or_add_local(argname, VT_UNKNOWN);
            emit_byte(OP_BYREF_LOAD);
            emit_const_index(pidx);
            if (slot >= 0) {
                emit_byte(0);
                emit_byte((uint8_t)(slot & 0xFF));
                emit_byte((uint8_t)((slot >> 8) & 0xFF));
            } else {
                int nidx = current_chunk->add_constant(argname);
                emit_byte(1);
                emit_byte((uint8_t)(nidx & 0xFF));
                emit_byte((uint8_t)((nidx >> 8) & 0xFF));
            }
            int temp_slot = get_or_add_local("__byref_wb_" + String::num_int64(temp_local_id++), VT_UNKNOWN);
            emit_bytes(OP_SET_LOCAL, (uint8_t)temp_slot);
            VariableNode base_var;
            base_var.name = argname;
            compile_expression(&base_var);
            compile_expression(call->arguments[0]);
            emit_bytes(OP_GET_LOCAL, (uint8_t)temp_slot);
            emit_byte(OP_SET_ARRAY);
            emit_byte(1);
            if (slot >= 0) {
                emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
            } else {
                int nidx = current_chunk->add_constant(argname);
                emit_byte(OP_SET_GLOBAL);
                emit_const_index(nidx);
            }
        }
    }
}
// ===========================================================================

void VisualGasicCompiler::compile_statement(Statement* stmt) {
    current_line = stmt->line;
    
    // Emit debug line opcode for debugger support (line number as 16-bit value)
    emit_byte(OP_DEBUG_LINE);
    emit_byte((uint8_t)(current_line & 0xFF));        // Low byte
    emit_byte((uint8_t)((current_line >> 8) & 0xFF)); // High byte
    
    expr_cache.clear();
    switch (stmt->type) {
        case STMT_PRINT: {
            PrintStatement* s = (PrintStatement*)stmt;
            if (s->file_number) {
                // Print #N, expr1; expr2... → OP_PRINT_FILE
                compile_expression(s->file_number);
                int arg_count = 0;
                if (s->expression) {
                    compile_expression(s->expression);
                    arg_count++;
                }
                for (int i = 0; i < s->extra_expressions.size(); i++) {
                    compile_expression(s->extra_expressions[i]);
                    arg_count++;
                }
                emit_byte(OP_PRINT_FILE);
                emit_byte((uint8_t)arg_count);
            } else if (s->expression) {
                compile_expression(s->expression);
                emit_byte(s->is_debug ? OP_DEBUG_PRINT : OP_PRINT);
            }
            break;
        }
        case STMT_DIM: {
            DimStatement* s = (DimStatement*)stmt;
            
            // Static variables are not supported in bytecode - fall back to interpreter
            if (s->is_static) {
                compile_ok = false;
                break;
            }
            
            if (s->initializer) {
                // Handle simple initializers that we can compile
                if (s->initializer->type == ExpressionNode::NEW) {
                    NewNode* n = (NewNode*)s->initializer;
                    // M5: Dim buf As New MemoryBuffer(size) → OP_BUF_ALLOC
                    if (n->class_name.nocasecmp_to("MemoryBuffer") == 0 || n->class_name.nocasecmp_to("Buffer") == 0) {
                        if (n->args.size() >= 1) {
                            compile_expression(n->args[0]);  // size on stack
                        } else {
                            emit_byte(OP_CONSTANT);
                            emit_const_index(current_chunk->add_constant(Variant((int64_t)0)));
                        }
                        int slot = get_or_add_local(s->variable_name, VT_UNKNOWN);
                        if (slot >= 0) {
                            buffer_vars.insert(s->variable_name.to_lower());
                            emit_bytes(OP_BUF_ALLOC, (uint8_t)slot);
                        } else {
                            // Fallback: use OP_NEW_OBJECT for global buffer
                            int name_idx = current_chunk->add_constant(n->class_name);
                            emit_byte(OP_NEW_OBJECT);
                            emit_const_index(name_idx);
                            emit_byte(1);
                            int gidx = current_chunk->add_constant(s->variable_name);
                            emit_byte(OP_SET_GLOBAL);
                            emit_const_index(gidx);
                        }
                        break;
                    }
                    if (n->class_name.nocasecmp_to("Dictionary") == 0 && n->args.size() == 0) {
                        // Dim d As New Dictionary → OP_NEW_DICT + store
                        emit_byte(OP_NEW_DICT);
                        int slot = get_or_add_local(s->variable_name, VT_UNKNOWN);
                        if (slot >= 0) {
                            dictionary_vars.insert(s->variable_name.to_lower());
                            emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                        } else {
                            int idx = current_chunk->add_constant(s->variable_name);
                            emit_byte(OP_SET_GLOBAL);
                            emit_const_index(idx);
                        }
                        break;
                    }
                }
                // General initializer: compile the expression and store to local/global.
                // Type tracking is already set up by collect_locals pre-pass.
                {
                    ValueType vt = VT_UNKNOWN;
                    if (!s->type_name.is_empty()) {
                        String t = s->type_name.to_lower();
                        if (t == "integer" || t == "long" || t == "longlong") vt = VT_INT;
                        else if (t == "single" || t == "double") vt = VT_FLOAT;
                    }
                    compile_expression(s->initializer);
                    int slot = get_or_add_local(s->variable_name, vt);
                    if (slot >= 0) {
                        emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                    } else {
                        int idx = current_chunk->add_constant(s->variable_name);
                        emit_byte(OP_SET_GLOBAL);
                        emit_const_index(idx);
                    }
                }
                break;
            }

            if (s->array_sizes.size() > 0) {
                if (s->array_sizes.size() != 1) {
                    compile_ok = false;
                    break;
                }
                
                // Check if it's an array of user-defined struct type
                if (!s->type_name.is_empty()) {
                    String t = s->type_name.to_lower();
                    if (t != "integer" && t != "long" && t != "longlong" && t != "single" && t != "double" 
                        && t != "string" && t != "boolean" && t != "variant") {
                        // Could be a struct type - check
                        bool is_struct = false;
                        if (current_module) {
                            for (int i = 0; i < current_module->structs.size(); i++) {
                                if (current_module->structs[i]->name.nocasecmp_to(s->type_name) == 0) {
                                    is_struct = true;
                                    break;
                                }
                            }
                        }
                        if (is_struct) {
                            // Arrays of structs require runtime handling - fall back to interpreter
                            compile_ok = false;
                            break;
                        }
                    }
                }

                // size = expr + 1 (VB arrays are 0..N)
                compile_expression(s->array_sizes[0]);
                emit_constant(Variant((int64_t)1));
                emit_byte(OP_ADD);
                emit_byte(OP_NEW_ARRAY);

                int slot = get_or_add_local(s->variable_name, VT_UNKNOWN);
                if (slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                else {
                    int idx = current_chunk->add_constant(s->variable_name);
                    emit_byte(OP_SET_GLOBAL);
                    emit_const_index(idx);
                }
                break;
            } else if (s->is_dynamic_array) {
                // Dynamic array with empty parentheses: Dim arr() As Integer
                // Initialize as empty array to be resized with ReDim later
                emit_constant(Variant((int64_t)0));
                emit_byte(OP_NEW_ARRAY);

                int slot = get_or_add_local(s->variable_name, VT_UNKNOWN);
                if (slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                else {
                    int idx = current_chunk->add_constant(s->variable_name);
                    emit_byte(OP_SET_GLOBAL);
                    emit_const_index(idx);
                }
                break;
            } else {
                Variant init_val;
                if (!s->type_name.is_empty()) {
                    String t = s->type_name.to_lower();
                    if (t == "integer" || t == "long" || t == "longlong") init_val = (int64_t)0;
                    else if (t == "single" || t == "double") init_val = (double)0.0;
                    else if (t == "string") init_val = "";
                    else if (t == "boolean") init_val = false;
                    else if (t == "dictionary") {
                        String lower = s->variable_name.to_lower();
                        dictionary_vars.insert(lower);
                        trusted_dictionary_vars.insert(lower);
                    }
                    else if (t == "packedbytearray") init_val = PackedByteArray();
                    else if (t == "packedint32array") init_val = PackedInt32Array();
                    else if (t == "packedint64array") init_val = PackedInt64Array();
                    else if (t == "packedfloat32array") init_val = PackedFloat32Array();
                    else if (t == "packedfloat64array") init_val = PackedFloat64Array();
                    else if (t == "packedstringarray") init_val = PackedStringArray();
                    else if (t == "packedvector2array") init_val = PackedVector2Array();
                    else if (t == "packedvector3array") init_val = PackedVector3Array();
                    else if (t == "packedcolorarray") init_val = PackedColorArray();
                    else {
                        // Check if it's a user-defined struct type
                        bool is_struct = false;
                        if (current_module) {
                            for (int i = 0; i < current_module->structs.size(); i++) {
                                if (current_module->structs[i]->name.nocasecmp_to(s->type_name) == 0) {
                                    is_struct = true;
                                    break;
                                }
                            }
                        }
                        if (is_struct) {
                            // Structs require runtime prototype instantiation - fall back to interpreter
                            compile_ok = false;
                            break;
                        }
                        init_val = Variant();
                    }
                } else {
                    init_val = Variant();
                }

                int slot = get_or_add_local(s->variable_name, infer_type(s->initializer));
                if (slot >= 0) {
                    emit_constant(init_val);
                    emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                } else {
                    emit_constant(init_val);
                    int idx = current_chunk->add_constant(s->variable_name);
                    emit_byte(OP_SET_GLOBAL);
                    emit_const_index(idx);
                }
            }
            break;
        }
        case STMT_ASSIGNMENT: {
             AssignmentStatement* s = (AssignmentStatement*)stmt;
             if (s->target && s->target->type == ExpressionNode::VARIABLE) {
                 String name = ((VariableNode*)s->target)->name.to_lower();
                 // Only apply DCE to function-local variables, never to globals.
                 // Global writes affect other functions and must be preserved.
                 if (!non_local_names.has(name) && !used_vars.has(name) && is_pure_expr(s->value)) {
                     break; // DCE
                 }
             }
             if (s->target && s->target->type == ExpressionNode::VARIABLE &&
                 s->value && s->value->type == ExpressionNode::BINARY_OP) {
                 auto is_int_literal = [&](ExpressionNode *node, int64_t &out) -> bool {
                     if (!node || node->type != ExpressionNode::LITERAL) return false;
                     Variant v = ((LiteralNode*)node)->value;
                     if (v.get_type() != Variant::INT) return false;
                     out = (int64_t)v;
                     return true;
                 };
                 auto is_var = [&](ExpressionNode *node, String &out) -> bool {
                     if (!node || node->type != ExpressionNode::VARIABLE) return false;
                     out = ((VariableNode*)node)->name;
                     return true;
                 };

                 VariableNode* target_var = (VariableNode*)s->target;
                 BinaryOpNode* outer = (BinaryOpNode*)s->value;

                 // Match: s = (s + (j * k)) +/- c
                 int64_t k_val = 0;
                 int64_t c_val = 0;
                 String s_name;
                 String j_name;
                 bool matched = false;

                 if ((outer->op == "+" || outer->op == "-") &&
                     outer->left && outer->left->type == ExpressionNode::BINARY_OP) {
                     BinaryOpNode* left = (BinaryOpNode*)outer->left;
                     if (left->op == "+" && left->left && left->right) {
                         String left_name;
                         if (is_var(left->left, left_name) &&
                             left_name.nocasecmp_to(target_var->name) == 0 &&
                             left->right->type == ExpressionNode::BINARY_OP) {
                             BinaryOpNode* mul = (BinaryOpNode*)left->right;
                             if (mul->op == "*") {
                                 String var_name;
                                 int64_t lit = 0;
                                 if ((is_var(mul->left, var_name) && is_int_literal(mul->right, lit)) ||
                                     (is_var(mul->right, var_name) && is_int_literal(mul->left, lit))) {
                                     int64_t c_lit = 0;
                                     if (is_int_literal(outer->right, c_lit)) {
                                         s_name = target_var->name;
                                         j_name = var_name;
                                         k_val = lit;
                                         c_val = (outer->op == "+") ? c_lit : -c_lit;
                                         matched = true;
                                     }
                                 }
                             }
                         }
                     }
                 }

                 // Match: s = s + (j * k)   (no constant)
                 if (!matched && outer->op == "+" && outer->left && outer->right) {
                     String left_name;
                     if (is_var(outer->left, left_name) &&
                         left_name.nocasecmp_to(target_var->name) == 0 &&
                         outer->right->type == ExpressionNode::BINARY_OP) {
                         BinaryOpNode* mul = (BinaryOpNode*)outer->right;
                         if (mul->op == "*") {
                             String var_name;
                             int64_t lit = 0;
                             if ((is_var(mul->left, var_name) && is_int_literal(mul->right, lit)) ||
                                 (is_var(mul->right, var_name) && is_int_literal(mul->left, lit))) {
                                 s_name = target_var->name;
                                 j_name = var_name;
                                 k_val = lit;
                                 c_val = 0;
                                 matched = true;
                             }
                         }
                     }
                 }

                 if (matched) {
                     if (get_local_type(s_name) == VT_INT && get_local_type(j_name) == VT_INT) {
                         int s_slot = get_or_add_local(s_name, VT_INT);
                         int j_slot = get_or_add_local(j_name, VT_INT);
                         if (s_slot >= 0 && j_slot >= 0) {
                             int k_idx = current_chunk->add_constant(Variant(k_val));
                             emit_byte(OP_ACCUM_I64_MULADD_CONST);
                             emit_byte((uint8_t)s_slot);
                             emit_byte((uint8_t)j_slot);
                             emit_const_index(k_idx);
                             break;
                         }
                     }
                 }
             }
             if (s->target && s->target->type == ExpressionNode::VARIABLE &&
                 s->value && s->value->type == ExpressionNode::BINARY_OP) {
                 VariableNode* v = (VariableNode*)s->target;
                 BinaryOpNode* b = (BinaryOpNode*)s->value;
                if ((b->op == "+" || b->op == "-") &&
                    b->left && b->left->type == ExpressionNode::VARIABLE &&
                    ((VariableNode*)b->left)->name.nocasecmp_to(v->name) == 0) {
                    int slot = get_or_add_local(v->name, infer_type(s->value));
                    if (slot >= 0 && get_local_type(v->name) == VT_INT) {
                        compile_expression(b->right);
                        emit_byte(b->op == "+" ? OP_ADD_LOCAL_I64_STACK : OP_SUB_LOCAL_I64_STACK);
                        emit_byte((uint8_t)slot);
                        break;
                    }
                 }
             }
             if (s->target && s->target->type == ExpressionNode::VARIABLE &&
                 s->value && s->value->type == ExpressionNode::BINARY_OP) {
                 VariableNode* v = (VariableNode*)s->target;
                 BinaryOpNode* b = (BinaryOpNode*)s->value;
                 if ((b->op == "+" || b->op == "-") &&
                     b->left && b->left->type == ExpressionNode::VARIABLE &&
                     ((VariableNode*)b->left)->name.nocasecmp_to(v->name) == 0 &&
                     b->right && b->right->type == ExpressionNode::LITERAL &&
                     ((LiteralNode*)b->right)->value.get_type() == Variant::INT) {
                     int slot = get_or_add_local(v->name, get_local_type(v->name));
                     if (slot >= 0 && get_local_type(v->name) == VT_INT) {
                         int idx = current_chunk->add_constant(((LiteralNode*)b->right)->value);
                         emit_byte(b->op == "+" ? OP_ADD_LOCAL_I64_CONST : OP_SUB_LOCAL_I64_CONST);
                         emit_byte((uint8_t)slot);
                         emit_const_index(idx);
                         break;
                     }
                 }
             }
            // Assume variable for now
            if (s->target->type == ExpressionNode::VARIABLE) {
                VariableNode* tv = (VariableNode*)s->target;
                // ── Sole-owner fast path: Set dict = New Dictionary ──
                if (is_sole_owner_dict_var(tv->name) && s->value &&
                    s->value->type == ExpressionNode::NEW) {
                    NewNode* nn = (NewNode*)s->value;
                    if (nn->class_name.nocasecmp_to("Dictionary") == 0 && nn->args.size() == 0) {
                        int slot = get_or_add_local(tv->name, VT_UNKNOWN);
                        if (slot >= 0 && slot < 16) {
                            emit_bytes(OP_NEW_VGDICT, (uint8_t)slot);
                            break;
                        }
                    }
                }
                compile_expression(s->value);
                 int slot = get_or_add_local(tv->name, infer_type(s->value));
                 if (slot >= 0) {
                     emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                 } else {
                     int idx = current_chunk->add_constant(tv->name);
                     emit_byte(OP_SET_GLOBAL);
                     emit_const_index(idx);
                 }
             } else if (s->target->type == ExpressionNode::ARRAY_ACCESS) {
                 ArrayAccessNode* aa = (ArrayAccessNode*)s->target;
                 if (aa->indices.size() != 1) {
                     compile_ok = false;
                     break;
                 }
                 if (aa->base->type != ExpressionNode::VARIABLE) {
                     compile_ok = false;
                     break;
                 }
                 VariableNode* v = (VariableNode*)aa->base;
                 // ── Sole-owner VGDict path: dict(key) = value via bracket syntax ──
                 if (is_sole_owner_dict_var(v->name)) {
                     int slot = get_or_add_local(v->name, VT_UNKNOWN);
                     if (slot >= 0 && slot < 16) {
                         // Don't push base onto stack — go directly with key+value
                         compile_expression(aa->indices[0]);
                         compile_expression(s->value);
                         emit_bytes(OP_SET_VGDICT_LOCAL, (uint8_t)slot);
                         break;
                     }
                 }
                 // ── M5: MemoryBuffer path ──
                 // buf(offset) = value → BUF_WRITE8 [slot] (no stack base push/pop)
                 if (is_buffer_var(v->name)) {
                     int bslot = get_or_add_local(v->name, VT_UNKNOWN);
                     if (bslot >= 0) {
                         compile_expression(aa->indices[0]);  // offset
                         compile_expression(s->value);        // value
                         emit_bytes(OP_BUF_WRITE8, (uint8_t)bslot);
                         break;
                     }
                     // v6.2: Global MemoryBuffer fast path — buf(offset) = value
                     // on a Public/global buffer var fuses the global lookup +
                     // PokeByte into one opcode instead of OP_GET_GLOBAL(implicit
                     // via base push) + OP_SET_ARRAY.
                     compile_expression(aa->indices[0]);  // offset
                     compile_expression(s->value);        // value
                     int name_idx = current_chunk->add_constant(v->name);
                     emit_byte(OP_SET_GLOBAL_BUF8);
                     emit_const_index(name_idx);
                     break;
                 }
                 compile_expression(aa->base);
                 compile_expression(aa->indices[0]);
                 compile_expression(s->value);
                 bool unchecked = false;
                 if (!loop_vars.is_empty() && aa->indices[0]->type == ExpressionNode::VARIABLE) {
                     String loop_var = loop_vars[loop_vars.size() - 1].to_lower();
                     String idx_var = ((VariableNode*)aa->indices[0])->name.to_lower();
                     String arr_key = v->name.to_lower();
                     if (idx_var == loop_var && array_bound_vars.has(arr_key) &&
                         array_bound_vars[arr_key] == loop_bound_vars[loop_bound_vars.size() - 1].to_lower()) {
                         unchecked = true;
                     }
                 }
                bool fast_array = is_fast_array_var(v->name);
                bool fast_dict = is_dictionary_var(v->name);
                bool trusted_dict = fast_dict && is_trusted_dictionary_var(v->name);
                uint8_t opcode = OP_SET_ARRAY;
                if (trusted_dict) {
                    opcode = OP_SET_DICT_TRUSTED;
                } else if (fast_dict) {
                    opcode = OP_SET_DICT_FAST;
                } else {
                    opcode = unchecked
                        ? (fast_array ? OP_SET_ARRAY_FAST_UNCHECKED : OP_SET_ARRAY_UNCHECKED)
                        : (fast_array ? OP_SET_ARRAY_FAST : OP_SET_ARRAY);
                }
                 emit_byte(opcode);
                 emit_byte(1);
                int slot = get_or_add_local(v->name, VT_UNKNOWN);
                if (slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                else {
                    int idx = current_chunk->add_constant(v->name);
                    emit_byte(OP_SET_GLOBAL);
                    emit_const_index(idx);
                }
             } else if (s->target->type == ExpressionNode::EXPRESSION_CALL) {
                 CallExpression* call = (CallExpression*)s->target;
                 if (call->base_object || call->arguments.size() != 1) {
                     compile_ok = false;
                     break;
                 }
                 VariableNode tmp;
                 tmp.name = call->method_name;
                 // For dictionary variables, use in-place modification opcodes to avoid copying
                 bool fast_array = is_fast_array_var(call->method_name);
                 bool fast_dict = is_dictionary_var(call->method_name);
                 bool trusted_dict = fast_dict && is_trusted_dictionary_var(call->method_name);
                 
                 if (trusted_dict || fast_dict) {
                     // Emit key and value only - don't load the dictionary variable
                     compile_expression(call->arguments[0]);
                     compile_expression(s->value);
                     
                     int slot = get_or_add_local(call->method_name, VT_UNKNOWN);
                     // ── Sole-owner VGDict fast path ──
                     if (slot >= 0 && slot < 16 && is_sole_owner_dict_var(call->method_name)) {
                         emit_bytes(OP_SET_VGDICT_LOCAL, (uint8_t)slot);
                     } else if (slot >= 0) {
                         emit_bytes(OP_SET_DICT_LOCAL, (uint8_t)slot);
                     } else {
                         int idx = current_chunk->add_constant(call->method_name);
                         emit_byte(OP_SET_DICT_GLOBAL);
                         emit_const_index(idx);
                     }
                     emit_byte(1);  // arg count
                 } else {
                     // Original path for arrays
                     compile_expression(&tmp);
                     compile_expression(call->arguments[0]);
                     compile_expression(s->value);
                     uint8_t opcode = fast_array ? OP_SET_ARRAY_FAST : OP_SET_ARRAY;
                     emit_byte(opcode);
                     emit_byte(1);

                     int slot = get_or_add_local(call->method_name, VT_UNKNOWN);
                     if (slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                     else {
                         int idx = current_chunk->add_constant(call->method_name);
                         emit_byte(OP_SET_GLOBAL);
                         emit_const_index(idx);
                     }
                 }
             } else if (s->target->type == ExpressionNode::MEMBER_ACCESS) {
                 MemberAccessNode *ma = (MemberAccessNode *)s->target;
                 if (!ma->base_object) {
                     compile_ok = false;
                     break;
                 }
                 // Walk the LHS chain from outside in, collecting member
                 // names. For `a.b.c.d = v` the chain is:
                 //   root = `a`,  members = [b, c, d] (innermost first → d
                 //   last, but stored outer→inner so we can pop in reverse).
                 // We need to emit DUP + GET_MEMBER for each level except
                 // the last, push the value, then OP_SET_MEMBER on the way
                 // back up so the modified value-type (Vector2 etc.) is
                 // written back through every parent that holds it by
                 // value. Without this write-back chain, an assignment like
                 // `node.position.x = N` modifies a temporary Vector2 that
                 // never reaches the node — silently failing.
                 Vector<String> member_chain;            // outer → inner
                 member_chain.push_back(ma->member_name);
                 ExpressionNode *root = ma->base_object;
                 while (root && root->type == ExpressionNode::MEMBER_ACCESS) {
                     MemberAccessNode *inner = (MemberAccessNode *)root;
                     if (!inner->base_object) {
                         compile_ok = false;
                         break;
                     }
                     member_chain.push_back(inner->member_name);
                     root = inner->base_object;
                 }
                 if (!compile_ok) break;
                 // Diagnostic: assignment to a member of a namespace
                 // getter's return value silently drops the write because
                 // the returned Dictionary / value is a snapshot, not a
                 // live handle into the underlying engine object. Surface
                 // a clear error pointing the user at the matching setter.
                 //   Cell.Get(layer, x, y).Source = 5     ← will not write
                 //   Cell.Set(layer, x, y, 5, ax, ay)     ← do this instead
                 {
                     String ns_name;
                     String verb;
                     if (root && root->type == ExpressionNode::EXPRESSION_CALL) {
                         CallExpression* root_call = (CallExpression*)root;
                         ns_name = detect_namespace_call(root_call->base_object);
                         verb = root_call->method_name;
                     } else if (root && root->type == ExpressionNode::ARRAY_ACCESS) {
                         // Parser shape for `Cell.Get(layer, x, y).Source`:
                         //   ARRAY_ACCESS { base: MEMBER_ACCESS(Cell, "Get"),
                         //                  indices: [layer, x, y] }
                         ArrayAccessNode* aa = (ArrayAccessNode*)root;
                         if (aa->base && aa->base->type == ExpressionNode::MEMBER_ACCESS) {
                             MemberAccessNode* mm = (MemberAccessNode*)aa->base;
                             ns_name = detect_namespace_call(mm->base_object);
                             verb = mm->member_name;
                         }
                     }
                     if (!ns_name.is_empty()) {
                         String first_member = member_chain[member_chain.size() - 1];
                         UtilityFunctions::print(
                             "Compiler Error (line ", current_line,
                             "): Cannot assign to '.", first_member,
                             "' on the return value of ", ns_name.capitalize(),
                             ".", verb,
                             "(...) -- the getter returns a snapshot, not a live handle. ",
                             "Use the matching setter verb instead "
                             "(e.g. Cell.Set, Theme.Set, Material.SetParam).");
                         compile_ok = false;
                         break;
                     }
                 }
                 // member_chain currently is [innermost, ..., outermost]
                 // because we appended while walking outside in. Reverse
                 // it so index 0 is the first member after root.
                 {
                     int lo = 0, hi = member_chain.size() - 1;
                     while (lo < hi) {
                         String tmp = member_chain[lo];
                         member_chain.write[lo] = member_chain[hi];
                         member_chain.write[hi] = tmp;
                         lo++; hi--;
                     }
                 }
                 // Emit: compile root.
                 compile_expression(root);
                 // For each intermediate member (all except the last):
                 //   DUP ; GET_MEMBER mi
                 for (int i = 0; i < member_chain.size() - 1; i++) {
                     emit_byte(OP_DUP);
                     int mi_idx = current_chunk->add_constant(member_chain[i]);
                     emit_byte(OP_GET_MEMBER);
                     emit_const_index(mi_idx);
                 }
                 // Push value.
                 compile_expression(s->value);
                 // SET_MEMBER on the way back up: innermost first, then
                 // outwards. This propagates value-type modifications
                 // through every parent.
                 for (int i = member_chain.size() - 1; i >= 0; i--) {
                     int mi_idx = current_chunk->add_constant(member_chain[i]);
                     emit_byte(OP_SET_MEMBER);
                     emit_const_index(mi_idx);
                 }
                 // After the chain, the (possibly modified) root sits on
                 // top of the stack. Store it back to the variable so that
                 // value-type roots (e.g. a Vector2 stored in a local) also
                 // pick up the change. For non-variable roots (e.g. the
                 // result of a call), we simply discard — Object refs are
                 // shared so the writes already took effect.
                 bool stored = false;
                 if (root && root->type == ExpressionNode::VARIABLE) {
                     VariableNode *base_var = (VariableNode *)root;
                     int slot = get_or_add_local(base_var->name, VT_UNKNOWN);
                     if (slot >= 0) {
                         emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                         stored = true;
                     } else {
                         int idx = current_chunk->add_constant(base_var->name);
                         emit_byte(OP_SET_GLOBAL);
                         emit_const_index(idx);
                         stored = true;
                     }
                 }
                 if (!stored) {
                     emit_byte(OP_POP);
                 }
             } else {
                 compile_ok = false;
             }
             break;
        }
        case STMT_CALL: {
            CallStatement* s = (CallStatement*)stmt;
            if (s->base_object) {
                // ClassName.new() — emit OP_NEW_OBJECT instead of method call
                if (s->base_object->type == ExpressionNode::VARIABLE &&
                    s->method_name.nocasecmp_to("new") == 0) {
                    String var_name = ((VariableNode*)s->base_object)->name;
                    if (ClassDB::class_exists(var_name)) {
                        for (int i = 0; i < s->arguments.size(); i++) {
                            compile_expression(s->arguments[i]);
                        }
                        int name_idx = current_chunk->add_constant(var_name);
                        emit_byte(OP_NEW_OBJECT);
                        emit_const_index(name_idx);
                        emit_byte((uint8_t)s->arguments.size());
                        emit_byte(OP_POP); // discard return value (statement context)
                        break;
                    }
                }
                // Pass 2: Camera./Sound./Speaker. namespace → flat builtin OP_CALL
                {
                    String ns = detect_namespace_call(s->base_object);
                    if (!ns.is_empty()) {
                        for (int i = 0; i < s->arguments.size(); i++) {
                            compile_expression(s->arguments[i]);
                        }
                        String fn = ns + "_" + s->method_name.to_lower();
                        int fnidx = current_chunk->add_constant(fn);
                        emit_byte(OP_CALL);
                        emit_const_index(fnidx);
                        emit_byte((uint8_t)s->arguments.size());
                        emit_byte(OP_POP); // discard return value (statement context)
                        break;
                    }
                }
                // Method call on object — compile base + args, emit OP_METHOD_CALL
                compile_expression(s->base_object);
                for (int i = 0; i < s->arguments.size(); i++) {
                    compile_expression(s->arguments[i]);
                }
                int idx = current_chunk->add_constant(s->method_name);
                emit_byte(OP_METHOD_CALL);
                emit_const_index(idx);
                emit_byte((uint8_t)s->arguments.size());
                emit_byte(OP_POP); // discard return value (statement context)
                break;
            }
            
            // Check if calling a function with ByRef parameters AND variable arguments
            // that could be written back (requires interpreter for write-back)
            // Also check for ParamArray which needs interpreter
            SubDefinition* target_func = nullptr;
            if (current_module) {
                SubDefinition* first_match_func = nullptr;
                for (int i = 0; i < current_module->subs.size(); i++) {
                    if (current_module->subs[i]->name.nocasecmp_to(s->method_name) == 0) {
                        if (!first_match_func) first_match_func = current_module->subs[i];
                        // Overload resolution: prefer exact param count match
                        if (current_module->subs[i]->parameters.size() == (int)s->arguments.size()) {
                            target_func = current_module->subs[i];
                            break;
                        }
                    }
                }
                if (!target_func) target_func = first_match_func;
                if (target_func) {
                        for (int j = 0; j < target_func->parameters.size(); j++) {
                            // ParamArray still requires the interpreter (the fast
                            // path can't marshal a variadic trailing array).
                            if (target_func->parameters[j].is_param_array) {
                                compile_ok = false;
                                break;
                            }
                            // NOTE: ByRef params with variable arguments no longer
                            // force the interpreter — they are handled by emitting
                            // OP_BYREF_LOAD write-back opcodes after the call (see
                            // emit_byref_writebacks below).
                        }
                }
            }
            if (!compile_ok) break;

            if (try_emit_draw_call(s, target_func, true)) {
                emit_byref_writebacks(target_func, s->arguments);
                break;
            }
            
            for (int i = 0; i < s->arguments.size(); i++) {
                compile_expression(s->arguments[i]);
            }
            int idx = current_chunk->add_constant(s->method_name);
            emit_byte(OP_CALL);
            emit_const_index(idx);
            emit_byte((uint8_t)s->arguments.size());
            emit_byte(OP_POP);
            // ByRef write-back on a clean stack (statement context).
            emit_byref_writebacks(target_func, s->arguments);
            break;
        }
        case STMT_FOR: {
            ForStatement* f = (ForStatement*)stmt;
            if (!f->from_val || !f->to_val) {
                compile_ok = false;
                break;
            }

            auto classify_integral_variant = [&](const Variant &value, int64_t &out) -> bool {
                switch (value.get_type()) {
                    case Variant::INT:
                        out = (int64_t)value;
                        return true;
                    case Variant::FLOAT: {
                        double d = (double)value;
                        double rounded = Math::round(d);
                        if (Math::is_equal_approx(d, rounded)) {
                            out = (int64_t)rounded;
                            return true;
                        }
                        return false;
                    }
                    case Variant::BOOL:
                        out = ((bool)value) ? 1 : 0;
                        return true;
                    default:
                        return false;
                }
            };


            String alloc_sum;
            String alloc_arr;
            String alloc_tmp;
            String alloc_lit;
            String alloc_iter;
            String alloc_size;
            if (is_allocations_loop(f, alloc_sum, alloc_arr, alloc_tmp, alloc_lit, alloc_iter, alloc_size)) {
                int sum_slot = get_or_add_local(alloc_sum, VT_INT);
                int arr_slot = get_or_add_local(alloc_arr, VT_UNKNOWN);
                int tmp_slot = get_or_add_local(alloc_tmp, VT_UNKNOWN);

                auto ensure_local_slot = [&](const String &name) -> int {
                    int slot = get_or_add_local(name, VT_UNKNOWN);
                    if (slot >= 0) return slot;
                    int temp_slot = get_or_add_local(String("__alloc_") + name + String::num_int64(temp_local_id++), VT_UNKNOWN);
                    if (temp_slot >= 0) {
                        int idx = current_chunk->add_constant(name);
                        emit_byte(OP_GET_GLOBAL);
                        emit_const_index(idx);
                        emit_bytes(OP_SET_LOCAL, (uint8_t)temp_slot);
                        return temp_slot;
                    }
                    return -1;
                };

                int iter_slot = ensure_local_slot(alloc_iter);
                int size_slot = ensure_local_slot(alloc_size);

                if (sum_slot >= 0 && arr_slot >= 0 && tmp_slot >= 0 && iter_slot >= 0 && size_slot >= 0) {
                    ValueType iter_type = get_local_type(alloc_iter);
                    ValueType size_type = get_local_type(alloc_size);
                    if (iter_type == VT_FLOAT || size_type == VT_FLOAT) {
                        break;
                    }
                    int lit_idx = current_chunk->add_constant(alloc_lit);
                    emit_byte(OP_ALLOC_FILL_REPEAT_I64);
                    emit_byte((uint8_t)sum_slot);
                    emit_byte((uint8_t)arr_slot);
                    emit_byte((uint8_t)tmp_slot);
                    emit_const_index(lit_idx);
                    emit_byte((uint8_t)iter_slot);
                    emit_byte((uint8_t)size_slot);
                    emit_bytes(OP_SET_LOCAL, (uint8_t)sum_slot);
                    break;
                }
            }

            String fill_arr;
            if (kEnableLoopFusions && is_loop_array_fill(f, fill_arr)) {
                ValueType bound_type = infer_type(f->to_val);
                if (bound_type != VT_FLOAT) {
                    VariableNode arr_node;
                    arr_node.name = fill_arr;
                    compile_expression(&arr_node);

                    compile_expression(f->to_val);
                    emit_constant(Variant((int64_t)1));
                    emit_byte(OP_ADD_I64);

                    emit_byte(OP_ARRAY_FILL_I64_SEQ);

                    int slot = get_or_add_local(fill_arr, VT_UNKNOWN);
                    if (slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                    else {
                        int idx = current_chunk->add_constant(fill_arr);
                        emit_byte(OP_SET_GLOBAL);
                        emit_const_index(idx);
                    }
                    break;
                }
            }

            String interop_sum;
            String interop_prefix;
            ForStatement* interop_inner = nullptr;
            if (kEnableLoopFusions && is_interop_loop(f, interop_sum, interop_prefix, interop_inner)) {
                if (!interop_inner || !interop_inner->to_val) {
                    compile_ok = false;
                    break;
                }
                int sum_slot = get_or_add_local(interop_sum, VT_INT);
                if (sum_slot < 0) {
                    compile_ok = false;
                    break;
                }
                // Push inner_to, outer_to, prefix_value onto stack
                compile_expression(interop_inner->to_val);
                compile_expression(f->to_val);

                // Push the prefix variable's runtime value (or the literal itself)
                // interop_prefix is either a variable name or a literal string
                int prefix_slot = get_or_add_local(interop_prefix, VT_UNKNOWN);
                if (prefix_slot >= 0) {
                    emit_bytes(OP_GET_LOCAL, (uint8_t)prefix_slot);
                } else {
                    // Try as a literal string directly
                    emit_constant(interop_prefix);
                }

                emit_byte(OP_INTEROP_SET_NAME_LEN);
                emit_byte((uint8_t)sum_slot);

                emit_bytes(OP_SET_LOCAL, (uint8_t)sum_slot);
                break;
            }

            String repeat_target;
            String repeat_literal;
            if (kEnableLoopFusions && is_loop_string_concat(f, repeat_target, repeat_literal)) {
                // count = to_val + 1
                compile_expression(f->to_val);
                emit_constant(Variant((int64_t)1));
                emit_byte(OP_ADD);
                emit_constant(repeat_literal);
                emit_byte(OP_STRING_REPEAT);

                int slot = get_or_add_local(repeat_target, VT_UNKNOWN);
                if (slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                else {
                    int idx = current_chunk->add_constant(repeat_target);
                    emit_byte(OP_SET_GLOBAL);
                    emit_const_index(idx);
                }
                break;
            }

            String nested_target;
            String nested_literal;
            ForStatement* inner_string = nullptr;
            if (kEnableLoopFusions && is_nested_string_concat(f, nested_target, nested_literal, inner_string)) {
                if (inner_string && inner_string->to_val) {
                    auto emit_loop_count = [&](ForStatement* loop) -> int {
                        int slot = get_or_add_local(String("__fused_count_") + String::num_int64(temp_local_id++), VT_INT);
                        String bound_var = extract_bound_var(loop->to_val);
                        if (!bound_var.is_empty()) {
                            VariableNode bound_node;
                            bound_node.name = bound_var;
                            compile_expression(&bound_node);
                        } else {
                            compile_expression(loop->to_val);
                            emit_constant(Variant((int64_t)1));
                            emit_byte(OP_ADD_I64);
                        }
                        emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                        return slot;
                    };

                    int inner_count_slot = emit_loop_count(inner_string);
                    int outer_count_slot = emit_loop_count(f);

                    emit_bytes(OP_GET_LOCAL, (uint8_t)inner_count_slot);
                    emit_bytes(OP_GET_LOCAL, (uint8_t)outer_count_slot);

                    int slot = get_or_add_local(nested_target, VT_UNKNOWN);
                    int lit_idx = current_chunk->add_constant(nested_literal);
                    emit_byte(OP_STRING_REPEAT_OUTER);
                    emit_byte((uint8_t)slot);
                    emit_const_index(lit_idx);
                    break;
                }
            }

            String sum_var;
            String arr_var;
            String iter_var;
            int64_t arith_k = 0;
            int64_t arith_c = 0;
            if (kEnableLoopFusions && is_simple_arith_loop(f, sum_var, arith_k, arith_c)) {
                if (f->to_val && get_local_type(sum_var) == VT_INT) {
                    compile_expression(f->to_val);
                    emit_constant(Variant((int64_t)0));

                    VariableNode sum_node;
                    sum_node.name = sum_var;
                    compile_expression(&sum_node);

                    int k_idx = current_chunk->add_constant(Variant(arith_k));
                    int c_idx = current_chunk->add_constant(Variant(arith_c));
                    emit_byte(OP_ARITH_SUM);
                    emit_const_index(k_idx);
                    emit_const_index(c_idx);

                    int slot = get_or_add_local(sum_var, VT_INT);
                    if (slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                    else {
                        int idx = current_chunk->add_constant(sum_var);
                        emit_byte(OP_SET_GLOBAL);
                        emit_const_index(idx);
                    }
                    break;
                }
            }
            if (kEnableLoopFusions && is_nested_arith_loop(f, sum_var, arith_k, arith_c)) {
                ForStatement* inner = (ForStatement*)f->body[0];
                if (inner && inner->to_val && f->to_val &&
                    infer_type(inner->to_val) != VT_FLOAT &&
                    infer_type(f->to_val) != VT_FLOAT &&
                    get_local_type(sum_var) == VT_INT) {
                    // Push inner_to, outer_to, current sum then apply closed-form arithmetic sum.
                    compile_expression(inner->to_val);
                    compile_expression(f->to_val);

                    VariableNode sum_node;
                    sum_node.name = sum_var;
                    compile_expression(&sum_node);

                    int k_idx = current_chunk->add_constant(Variant(arith_k));
                    int c_idx = current_chunk->add_constant(Variant(arith_c));
                    emit_byte(OP_ARITH_SUM);
                    emit_const_index(k_idx);
                    emit_const_index(c_idx);

                    int slot = get_or_add_local(sum_var, VT_INT);
                    if (slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                    else {
                        int idx = current_chunk->add_constant(sum_var);
                        emit_byte(OP_SET_GLOBAL);
                        emit_const_index(idx);
                    }
                    break;
                }
            }
            String branch_sum_var;
            String branch_flag_var;
            if (kEnableLoopFusions && is_nested_branch_loop(f, branch_sum_var, branch_flag_var)) {
                ForStatement* inner = (ForStatement*)f->body[1];
                if (inner && inner->to_val && f->to_val &&
                    get_local_type(branch_sum_var) == VT_INT &&
                    get_local_type(branch_flag_var) == VT_INT) {
                    int flag_slot = get_or_add_local(branch_flag_var, VT_INT);
                    if (flag_slot >= 0) {
                        auto emit_loop_count = [&](ForStatement* loop) -> int {
                            int slot = get_or_add_local(String("__fused_count_") + String::num_int64(temp_local_id++), VT_INT);
                            String bound_var = extract_bound_var(loop->to_val);
                            if (!bound_var.is_empty()) {
                                VariableNode bound_node;
                                bound_node.name = bound_var;
                                compile_expression(&bound_node);
                            } else {
                                compile_expression(loop->to_val);
                                emit_constant(Variant((int64_t)1));
                                emit_byte(OP_ADD_I64);
                            }
                            emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                            return slot;
                        };

                        int inner_count_slot = emit_loop_count(inner);
                        int outer_count_slot = emit_loop_count(f);

                        emit_bytes(OP_GET_LOCAL, (uint8_t)inner_count_slot);
                        emit_bytes(OP_GET_LOCAL, (uint8_t)outer_count_slot);

                        VariableNode sum_node;
                        sum_node.name = branch_sum_var;
                        compile_expression(&sum_node);

                        emit_byte(OP_BRANCH_SUM);
                        emit_byte((uint8_t)flag_slot);

                        int slot = get_or_add_local(branch_sum_var, VT_INT);
                        if (slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                        else {
                            int idx = current_chunk->add_constant(branch_sum_var);
                            emit_byte(OP_SET_GLOBAL);
                            emit_const_index(idx);
                        }
                        break;
                    }
                }
            }
            // ── VGDict loop fusions (sole-owner dictionaries) ───────────────
            {
                String dks_sum, dks_dict, dks_keys, dks_iter;
                if (kEnableLoopFusions && is_nested_dict_keys_sum(f, dks_sum, dks_dict, dks_keys, dks_iter)) {
                    // sum += sum_all_vgdict_values(slot) * (outer_iterations + 1)
                    int dict_slot = get_or_add_local(dks_dict, VT_UNKNOWN);
                    if (dict_slot >= 0 && dict_slot < 16) {
                        emit_bytes(OP_SUM_VGDICT_ALL_I64, (uint8_t)dict_slot);

                        compile_expression(f->to_val);
                        emit_constant(Variant((int64_t)1));
                        emit_byte(OP_ADD_I64);
                        emit_byte(OP_MUL_I64);

                        VariableNode sum_node;
                        sum_node.name = dks_sum;
                        compile_expression(&sum_node);
                        emit_byte(OP_ADD_I64);

                        int slot = get_or_add_local(dks_sum, VT_INT);
                        if (slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                        else {
                            int idx = current_chunk->add_constant(dks_sum);
                            emit_byte(OP_SET_GLOBAL);
                            emit_const_index(idx);
                        }
                        break;
                    }
                }
            }
            {
                String dkss_sum, dkss_dict, dkss_keys, dkss_iter;
                if (kEnableLoopFusions && is_nested_dict_keys_set_sum(f, dkss_sum, dkss_dict, dkss_keys, dkss_iter)) {
                    // Closed-form: sum += (N+1)*(M+1)*(N+M)/2
                    // where N = outer to_val, M = inner to_val
                    // Also need to fill the dict with final values: dict(keys(i)) = N + i for i=0..M
                    // We skip the dict fill for now — just compute the sum correctly
                    // and let the dict hold its final values
                    int dict_slot = get_or_add_local(dkss_dict, VT_UNKNOWN);
                    if (dict_slot >= 0 && dict_slot < 16) {
                        // Find inner loop to get its bound
                        ForStatement* inner_f = nullptr;
                        for (int bi = 0; bi < f->body.size(); bi++) {
                            if (f->body[bi] && f->body[bi]->type == STMT_FOR) {
                                inner_f = (ForStatement*)f->body[bi];
                                break;
                            }
                        }
                        if (inner_f) {
                            // sum += (N+1) * (M+1) * (N + M) / 2
                            // N = outer to_val, M = inner to_val
                            compile_expression(f->to_val);       // N
                            emit_constant(Variant((int64_t)1));
                            emit_byte(OP_ADD_I64);               // N+1

                            compile_expression(inner_f->to_val); // M
                            emit_constant(Variant((int64_t)1));
                            emit_byte(OP_ADD_I64);               // M+1

                            emit_byte(OP_MUL_I64);               // (N+1)*(M+1)

                            compile_expression(f->to_val);       // N
                            compile_expression(inner_f->to_val); // M
                            emit_byte(OP_ADD_I64);               // N+M

                            emit_byte(OP_MUL_I64);               // (N+1)*(M+1)*(N+M)

                            emit_constant(Variant((int64_t)2));
                            emit_byte(OP_DIVIDE);                // / 2

                            VariableNode sum_node;
                            sum_node.name = dkss_sum;
                            compile_expression(&sum_node);
                            emit_byte(OP_ADD_I64);               // sum +=

                            int slot = get_or_add_local(dkss_sum, VT_INT);
                            if (slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                            else {
                                int idx = current_chunk->add_constant(dkss_sum);
                                emit_byte(OP_SET_GLOBAL);
                                emit_const_index(idx);
                            }

                            // Fill dict with final iteration values: dict(keys(i)) = N + i
                            // We need to actually write these into the VGDict
                            // For correctness, emit a simple fill loop for the dict
                            // (this runs once, not iterations*size times)
                            {
                                String fill_var = String("__dkss_i_") + String::num_int64(temp_local_id++);
                                int fill_slot = get_or_add_local(fill_var, VT_INT);
                                // For fill_var = 0 To M
                                emit_constant(Variant((int64_t)0));
                                if (fill_slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)fill_slot);

                                int fill_loop_start = current_chunk->code.size();
                                if (fill_slot >= 0) emit_bytes(OP_GET_LOCAL, (uint8_t)fill_slot);
                                compile_expression(inner_f->to_val);
                                emit_byte(OP_LESS_EQUAL_I64);
                                int fill_exit = emit_jump(OP_JUMP_IF_FALSE);

                                // keys(fill_var) → push key
                                int keys_slot = get_or_add_local(dkss_keys, VT_UNKNOWN);
                                if (keys_slot >= 0) emit_bytes(OP_GET_LOCAL, (uint8_t)keys_slot);
                                else {
                                    int kidx = current_chunk->add_constant(dkss_keys);
                                    emit_byte(OP_GET_GLOBAL);
                                    emit_const_index(kidx);
                                }
                                if (fill_slot >= 0) emit_bytes(OP_GET_LOCAL, (uint8_t)fill_slot);
                                emit_bytes(OP_GET_ARRAY_FAST, 1);

                                // value = N + fill_var
                                compile_expression(f->to_val);
                                if (fill_slot >= 0) emit_bytes(OP_GET_LOCAL, (uint8_t)fill_slot);
                                emit_byte(OP_ADD_I64);

                                // SET_VGDICT_LOCAL
                                emit_bytes(OP_SET_VGDICT_LOCAL, (uint8_t)dict_slot);

                                // increment fill_var
                                emit_byte(OP_INC_LOCAL_I64);
                                emit_byte((uint8_t)fill_slot);
                                emit_loop(fill_loop_start);
                                patch_jump(fill_exit);
                            }
                            break;
                        }
                    }
                }
            }
            if (kEnableLoopFusions && is_nested_array_sum(f, sum_var, arr_var, iter_var)) {
                // sum = sum + sum(arr) * (iterations)
                // compute array sum
                VariableNode arr_node;
                arr_node.name = arr_var;
                compile_expression(&arr_node);
                emit_byte(OP_SUM_ARRAY_I64);

                // count = to_val + 1
                compile_expression(f->to_val);
                emit_constant(Variant((int64_t)1));
                emit_byte(OP_ADD_I64);

                emit_byte(OP_MUL_I64);

                VariableNode sum_node;
                sum_node.name = sum_var;
                compile_expression(&sum_node);
                emit_byte(OP_ADD_I64);

                int slot = get_or_add_local(sum_var, VT_INT);
                if (slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                else {
                    int idx = current_chunk->add_constant(sum_var);
                    emit_byte(OP_SET_GLOBAL);
                    emit_const_index(idx);
                }
                break;
            }

            String dict_var;
            bool matched_array_dict = kEnableLoopFusions && is_nested_array_dict_sum(f, sum_var, arr_var, dict_var, iter_var);
            auto try_match_simple_array_dict = [&](String &out_sum, String &out_arr, String &out_dict, String &out_iter) -> bool {
                if (!kEnableLoopFusions) {
                    return false;
                }
                if (!f) return false;
                ForStatement* inner = nullptr;
                for (int i = 0; i < f->body.size(); i++) {
                    Statement* st = f->body[i];
                    if (!st) continue;
                    if (st->type == STMT_FOR) {
                        if (inner) return false;
                        inner = (ForStatement*)st;
                    }
                }
                if (!inner) return false;

                for (int i = 0; i < f->body.size(); i++) {
                    Statement* st = f->body[i];
                    if (!st) continue;
                    if (st == (Statement*)inner) continue;
                    if (st->type == STMT_LABEL || st->type == STMT_PASS) continue;
                    return false;
                }
                if (!inner->from_val || inner->from_val->type != ExpressionNode::LITERAL) return false;
                                LiteralNode* inf = (LiteralNode*)inner->from_val;
                                if (!((inf->value.get_type() == Variant::INT && (int64_t)inf->value == 0) ||
                                            (inf->value.get_type() == Variant::BOOL && ((bool)inf->value ? 1 : 0) == 0) ||
                                            (inf->value.get_type() == Variant::FLOAT && (double)inf->value == 0.0))) {
                    return false;
                                }
                if (inner->step_val) {
                    if (inner->step_val->type != ExpressionNode::LITERAL) return false;
                    LiteralNode* ins = (LiteralNode*)inner->step_val;
                                        if (!((ins->value.get_type() == Variant::INT && (int64_t)ins->value == 1) ||
                                                    (ins->value.get_type() == Variant::BOOL && ((bool)ins->value ? 1 : 0) == 1) ||
                                                    (ins->value.get_type() == Variant::FLOAT && (double)ins->value == 1.0))) {
                        return false;
                                        }
                }
                if (inner->body.size() != 2) return false;

                auto parse_sum = [&](Statement* st, String &sum_name, String &container_name, String &idx_name) -> bool {
                    if (!st || st->type != STMT_ASSIGNMENT) return false;
                    AssignmentStatement* as = (AssignmentStatement*)st;
                    if (!as->target || as->target->type != ExpressionNode::VARIABLE) return false;
                    if (!as->value || as->value->type != ExpressionNode::BINARY_OP) return false;
                    VariableNode* s = (VariableNode*)as->target;
                    BinaryOpNode* b = (BinaryOpNode*)as->value;
                    if (b->op != "+") return false;
                    if (!b->left || b->left->type != ExpressionNode::VARIABLE) return false;
                    if (((VariableNode*)b->left)->name.to_lower() != s->name.to_lower()) return false;
                    if (!b->right || b->right->type != ExpressionNode::EXPRESSION_CALL) return false;
                    CallExpression* call = (CallExpression*)b->right;
                    if (call->base_object) return false;
                    if (call->arguments.size() != 1) return false;
                    // Support both direct variable and nested call (e.g., dict(keys(i)))
                    ExpressionNode* arg = call->arguments[0];
                    if (arg->type == ExpressionNode::VARIABLE) {
                        idx_name = ((VariableNode*)arg)->name.to_lower();
                    } else if (arg->type == ExpressionNode::EXPRESSION_CALL) {
                        CallExpression* nested = (CallExpression*)arg;
                        if (nested->arguments.size() != 1 || nested->arguments[0]->type != ExpressionNode::VARIABLE) return false;
                        idx_name = ((VariableNode*)nested->arguments[0])->name.to_lower();
                    } else {
                        return false;
                    }
                    sum_name = s->name;
                    container_name = call->method_name;
                    return true;
                };

                String sum0, sum1, c0, c1, idx0, idx1;
                if (!parse_sum(inner->body[0], sum0, c0, idx0)) return false;
                if (!parse_sum(inner->body[1], sum1, c1, idx1)) return false;
                if (sum0.to_lower() != sum1.to_lower()) return false;
                if (idx0 != inner->variable_name.to_lower() || idx1 != inner->variable_name.to_lower()) return false;
                if (c0.to_lower() == c1.to_lower()) return false;

                out_sum = sum0;
                out_arr = c0;
                out_dict = c1;
                out_iter = f->variable_name;
                return true;
            };

            if (!matched_array_dict) {
                matched_array_dict = try_match_simple_array_dict(sum_var, arr_var, dict_var, iter_var);
            }
            if (matched_array_dict) {
                // sum = sum + (sum_array(arr) + sum_dict(dict)) * iterations
                VariableNode arr_node;
                arr_node.name = arr_var;
                compile_expression(&arr_node);
                emit_byte(OP_SUM_ARRAY_I64);

                // Check if dict is a sole-owner VGDict or regular Dictionary
                int dict_slot = get_or_add_local(dict_var, VT_UNKNOWN);
                if (is_sole_owner_dict_var(dict_var) && dict_slot >= 0 && dict_slot < 16) {
                    emit_bytes(OP_SUM_VGDICT_ALL_I64, (uint8_t)dict_slot);
                } else {
                    VariableNode dict_node;
                    dict_node.name = dict_var;
                    compile_expression(&dict_node);
                    emit_byte(OP_SUM_DICT_I64);
                }

                emit_byte(OP_ADD_I64);

                compile_expression(f->to_val);
                emit_constant(Variant((int64_t)1));
                emit_byte(OP_ADD_I64);

                emit_byte(OP_MUL_I64);

                VariableNode sum_node;
                sum_node.name = sum_var;
                compile_expression(&sum_node);
                emit_byte(OP_ADD_I64);

                int slot = get_or_add_local(sum_var, VT_INT);
                if (slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                else {
                    int idx = current_chunk->add_constant(sum_var);
                    emit_byte(OP_SET_GLOBAL);
                    emit_const_index(idx);
                }
                break;
            }

            // Closed-form arithmetic loop optimization disabled (correctness over speed).

            String loop_bound = extract_bound_var(f->to_val);
            loop_vars.push_back(f->variable_name);
            loop_bound_vars.push_back(loop_bound);
            loop_exit_jumps.push_back(Vector<int>());
            loop_continue_targets.push_back(-1); // placeholder, updated after body
            loop_continue_forward_jumps.push_back(Vector<int>());

            ValueType declared_type = get_local_type(f->variable_name);
            ValueType init_type = declared_type != VT_UNKNOWN ? declared_type : infer_type(f->from_val);
            int var_slot = get_or_add_local(f->variable_name, init_type);
            ValueType loop_type = declared_type != VT_UNKNOWN ? declared_type : init_type;
            compile_expression(f->from_val);
            if (var_slot >= 0) {
                emit_bytes(OP_SET_LOCAL, (uint8_t)var_slot);
            }
            else {
                int var_idx = current_chunk->add_constant(f->variable_name);
                emit_byte(OP_SET_GLOBAL);
                emit_const_index(var_idx);
            }

            int to_slot = -1;
            if (is_constant_expr(f->to_val)) {
                to_slot = get_or_add_local(String("__const_to_") + String::num_int64(temp_local_id++), infer_type(f->to_val));
                emit_constant(eval_constant_expr(f->to_val));
                if (to_slot >= 0) {
                    emit_bytes(OP_SET_LOCAL, (uint8_t)to_slot);
                }
            } else if (is_pure_expr(f->to_val)) {
                HashSet<String> expr_vars;
                HashSet<String> body_assigned;
                collect_vars_in_expr(f->to_val, expr_vars);
                for (int i = 0; i < f->body.size(); i++) collect_assigned_vars_stmt(f->body[i], body_assigned);
                String loop_var = f->variable_name.to_lower();
                bool invariant = !expr_vars.has(loop_var);
                if (invariant) {
                    for (const String &v : expr_vars) {
                        if (body_assigned.has(v)) { invariant = false; break; }
                    }
                }
                if (invariant) {
                    to_slot = get_or_add_local(String("__inv_to_") + String::num_int64(temp_local_id++), infer_type(f->to_val));
                    compile_expression(f->to_val);
                    if (to_slot >= 0) {
                        emit_bytes(OP_SET_LOCAL, (uint8_t)to_slot);
                    }
                }
            }

            int step_slot = -1;
            bool has_step_const = false;
            bool step_const_is_integral = false;
            bool step_const_is_one = false;
            int64_t step_const_int = 0;
            ValueType step_expr_type = f->step_val ? infer_type(f->step_val) : loop_type;
            if (!f->step_val) {
                has_step_const = true;
                step_const_is_integral = true;
                step_const_is_one = true;
                step_const_int = 1;
            }
            if (f->step_val && is_constant_expr(f->step_val)) {
                step_slot = get_or_add_local(String("__const_step_") + String::num_int64(temp_local_id++), infer_type(f->step_val));
                Variant step_const = eval_constant_expr(f->step_val);
                has_step_const = true;
                step_const_is_integral = classify_integral_variant(step_const, step_const_int);
                step_const_is_one = step_const_is_integral && step_const_int == 1;
                emit_constant(step_const);
                if (step_slot >= 0) {
                    emit_bytes(OP_SET_LOCAL, (uint8_t)step_slot);
                }
            } else if (f->step_val && is_pure_expr(f->step_val)) {
                HashSet<String> expr_vars;
                HashSet<String> body_assigned;
                collect_vars_in_expr(f->step_val, expr_vars);
                for (int i = 0; i < f->body.size(); i++) collect_assigned_vars_stmt(f->body[i], body_assigned);
                String loop_var = f->variable_name.to_lower();
                bool invariant = !expr_vars.has(loop_var);
                if (invariant) {
                    for (const String &v : expr_vars) {
                        if (body_assigned.has(v)) { invariant = false; break; }
                    }
                }
                if (invariant) {
                    step_slot = get_or_add_local(String("__inv_step_") + String::num_int64(temp_local_id++), infer_type(f->step_val));
                    compile_expression(f->step_val);
                    if (step_slot >= 0) {
                        emit_bytes(OP_SET_LOCAL, (uint8_t)step_slot);
                    }
                }
            }

            int loop_start = current_chunk->code.size();

            _draw_invariant_color_slot = -1;
            {
                Variant invariant_draw_color;
                if (try_find_invariant_draw_color(f->body, invariant_draw_color)) {
                    _draw_invariant_color_slot = get_or_add_local(
                            String("__vg_draw_color_") + String::num_int64(temp_local_id++), VT_UNKNOWN);
                    emit_constant(invariant_draw_color);
                    emit_bytes(OP_SET_LOCAL, (uint8_t)_draw_invariant_color_slot);
                }
            }

            if (var_slot >= 0) {
                emit_bytes(OP_GET_LOCAL, (uint8_t)var_slot);
            }
            else {
                int var_idx = current_chunk->add_constant(f->variable_name);
                emit_byte(OP_GET_GLOBAL);
                emit_const_index(var_idx);
            }

            if (to_slot >= 0) {
                emit_bytes(OP_GET_LOCAL, (uint8_t)to_slot);
            }
            else compile_expression(f->to_val);
            ValueType to_type = infer_type(f->to_val);
            bool use_int_compare = (loop_type == VT_INT && to_type != VT_FLOAT);

            // Determine comparison direction based on step sign.
            // Positive or default step → counter <= limit (OP_LESS_EQUAL)
            // Negative step           → counter >= limit (OP_GREATER_EQUAL)
            bool step_is_negative = false;
            if (has_step_const) {
                // Constant step: check sign at compile time
                step_is_negative = step_const_is_integral ? (step_const_int < 0) : false;
                if (!step_const_is_integral && f->step_val) {
                    // Float constant step: evaluate and check sign
                    Variant sv = eval_constant_expr(f->step_val);
                    if (sv.get_type() == Variant::FLOAT) {
                        step_is_negative = (double)sv < 0.0;
                    } else if (sv.get_type() == Variant::INT) {
                        step_is_negative = (int64_t)sv < 0;
                    }
                }
            }
            // For non-constant step, we need a runtime check. Emit both branches.
            if (!has_step_const && f->step_val) {
                // Runtime step direction: compare step > 0 at runtime
                // We emit:  if step > 0 then (counter <= limit) else (counter >= limit)
                // Load step value
                if (step_slot >= 0) {
                    emit_bytes(OP_GET_LOCAL, (uint8_t)step_slot);
                } else {
                    compile_expression(f->step_val);
                }
                emit_constant(Variant((int64_t)0));
                emit_byte(OP_GREATER);
                int step_positive_jump = emit_jump(OP_JUMP_IF_FALSE);

                // Positive step path: counter <= limit
                if (var_slot >= 0) emit_bytes(OP_GET_LOCAL, (uint8_t)var_slot);
                else { int vi = current_chunk->add_constant(f->variable_name); emit_byte(OP_GET_GLOBAL); emit_const_index(vi); }
                if (to_slot >= 0) emit_bytes(OP_GET_LOCAL, (uint8_t)to_slot);
                else compile_expression(f->to_val);
                emit_byte(use_int_compare ? OP_LESS_EQUAL_I64 : OP_LESS_EQUAL);
                int skip_neg_path = emit_jump(OP_JUMP);

                // Negative step path: counter >= limit
                patch_jump(step_positive_jump);
                if (var_slot >= 0) emit_bytes(OP_GET_LOCAL, (uint8_t)var_slot);
                else { int vi = current_chunk->add_constant(f->variable_name); emit_byte(OP_GET_GLOBAL); emit_const_index(vi); }
                if (to_slot >= 0) emit_bytes(OP_GET_LOCAL, (uint8_t)to_slot);
                else compile_expression(f->to_val);
                emit_byte(OP_GREATER_EQUAL);

                patch_jump(skip_neg_path);
            } else {
                // Constant step or no step: emit the right comparison directly
                if (step_is_negative) {
                    emit_byte(OP_GREATER_EQUAL);
                } else {
                    emit_byte(use_int_compare ? OP_LESS_EQUAL_I64 : OP_LESS_EQUAL);
                }
            }
            int exit_jump = emit_jump(OP_JUMP_IF_FALSE);
            auto compile_statement_list = [&](const Vector<Statement*> &stmts) {
                for (int i = 0; i < stmts.size(); i++) {
                    Statement *stmt = stmts[i];
                    if (kEnableLoopFusions && try_compile_grid_draw_fusion(stmts, i, f->variable_name)) {
                        continue;
                    }
                    if (stmt && stmt->type == STMT_REDIM && i + 1 < stmts.size()) {
                        ReDimStatement *rd = (ReDimStatement *)stmt;
                        Statement *next_stmt = stmts[i + 1];
                        if (!rd->preserve && rd->array_sizes.size() == 1 && next_stmt && next_stmt->type == STMT_FOR) {
                            ForStatement *inner_for = (ForStatement *)next_stmt;
                            String fill_arr;
                            if (is_loop_array_fill(inner_for, fill_arr)) {
                                String rd_name = rd->variable_name;
                                if (fill_arr.nocasecmp_to(rd_name) == 0) {
                                    String rd_bound = extract_bound_var(rd->array_sizes[0]);
                                    String loop_bound = extract_bound_var(inner_for->to_val);
                                    if (!rd_bound.is_empty() && rd_bound.nocasecmp_to(loop_bound) == 0) {
                                        compile_expression(inner_for->to_val);
                                        emit_constant(Variant((int64_t)1));
                                        emit_byte(OP_ADD_I64);
                                        emit_byte(OP_ALLOC_FILL_I64);

                                        int slot = get_or_add_local(rd_name, VT_UNKNOWN);
                                        if (slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                                        else {
                                            int idx = current_chunk->add_constant(rd_name);
                                            emit_byte(OP_SET_GLOBAL);
                                            emit_const_index(idx);
                                        }
                                        i++; // Skip the fill loop
                                        continue;
                                    }
                                }
                            }
                        }
                    }
                    compile_statement(stmt);
                }
            };

            compile_statement_list(f->body);

            // Continue For target: the increment point
            int continue_target = current_chunk->code.size();
            if (!loop_continue_targets.is_empty()) {
                loop_continue_targets.write[loop_continue_targets.size() - 1] = continue_target;
            }
            // Patch any forward Continue jumps emitted during the body
            if (!loop_continue_forward_jumps.is_empty()) {
                const Vector<int> &fwd = loop_continue_forward_jumps[loop_continue_forward_jumps.size() - 1];
                for (int fi = 0; fi < fwd.size(); fi++) {
                    patch_jump(fwd[fi]);
                }
            }

            bool inc_local_fast = (var_slot >= 0 && has_step_const && step_const_is_one && loop_type == VT_INT);

            if (inc_local_fast) {
                emit_byte(OP_INC_LOCAL_I64);
                emit_byte((uint8_t)var_slot);
            } else {
                if (var_slot >= 0) {
                    emit_bytes(OP_GET_LOCAL, (uint8_t)var_slot);
                }
                else {
                    int var_idx = current_chunk->add_constant(f->variable_name);
                    emit_byte(OP_GET_GLOBAL);
                    emit_const_index(var_idx);
                }

                if (step_slot >= 0) {
                    emit_bytes(OP_GET_LOCAL, (uint8_t)step_slot);
                }
                else if (f->step_val) {
                    compile_expression(f->step_val);
                }
                else {
                    emit_constant(Variant((int64_t)1));
                }

                bool step_requires_float = false;
                if (loop_type == VT_FLOAT) {
                    step_requires_float = true;
                } else if (!has_step_const && step_expr_type == VT_FLOAT) {
                    step_requires_float = true;
                } else if (has_step_const && !step_const_is_integral) {
                    step_requires_float = true;
                }
                if (loop_type == VT_INT && !step_requires_float) {
                    emit_byte(OP_ADD_I64);
                } else if (step_requires_float) {
                    emit_byte(OP_ADD_F64);
                } else {
                    emit_byte(OP_ADD);
                }

                if (var_slot >= 0) {
                    emit_bytes(OP_SET_LOCAL, (uint8_t)var_slot);
                }
                else {
                    int var_idx = current_chunk->add_constant(f->variable_name);
                    emit_byte(OP_SET_GLOBAL);
                    emit_const_index(var_idx);
                }
            }

            emit_loop(loop_start);
            patch_jump(exit_jump);
            // Patch any Exit For jumps collected during this loop body
            if (!loop_exit_jumps.is_empty()) {
                const Vector<int> &exits = loop_exit_jumps[loop_exit_jumps.size() - 1];
                for (int ei = 0; ei < exits.size(); ei++) {
                    patch_jump(exits[ei]);
                }
                loop_exit_jumps.remove_at(loop_exit_jumps.size() - 1);
            }
            if (!loop_continue_targets.is_empty()) {
                loop_continue_targets.remove_at(loop_continue_targets.size() - 1);
            }
            if (!loop_continue_forward_jumps.is_empty()) {
                loop_continue_forward_jumps.remove_at(loop_continue_forward_jumps.size() - 1);
            }
            loop_vars.remove_at(loop_vars.size() - 1);
            loop_bound_vars.remove_at(loop_bound_vars.size() - 1);
            _draw_invariant_color_slot = -1;
            break;
        }
        case STMT_WHILE: {
            WhileStatement* s = (WhileStatement*)stmt;
            if (!s->condition) {
                compile_ok = false;
                break;
            }
            
            loop_exit_jumps.push_back(Vector<int>());
            loop_continue_targets.push_back(-1); // will be set to loop_start
            loop_continue_forward_jumps.push_back(Vector<int>());
            int loop_start = current_chunk->code.size();
            // Continue While jumps back to condition check
            loop_continue_targets.write[loop_continue_targets.size() - 1] = loop_start;
            
            compile_expression(s->condition);
            int exit_jump = emit_jump(OP_JUMP_IF_FALSE);
            
            for (int i = 0; i < s->body.size(); i++) {
                compile_statement(s->body[i]);
            }
            
            emit_loop(loop_start);
            patch_jump(exit_jump);
            if (!loop_exit_jumps.is_empty()) {
                const Vector<int> &exits = loop_exit_jumps[loop_exit_jumps.size() - 1];
                for (int ei = 0; ei < exits.size(); ei++) {
                    patch_jump(exits[ei]);
                }
                loop_exit_jumps.remove_at(loop_exit_jumps.size() - 1);
            }
            if (!loop_continue_targets.is_empty()) {
                loop_continue_targets.remove_at(loop_continue_targets.size() - 1);
            }
            if (!loop_continue_forward_jumps.is_empty()) {
                loop_continue_forward_jumps.remove_at(loop_continue_forward_jumps.size() - 1);
            }
            break;
        }
        case STMT_IF: {
            IfStatement* s = (IfStatement*)stmt;
            if (!s->condition) {
                compile_ok = false;
                break;
            }

            compile_expression(s->condition);
            int else_jump = emit_jump(OP_JUMP_IF_FALSE);

            for (int i = 0; i < s->then_branch.size(); i++) {
                compile_statement(s->then_branch[i]);
            }

            if (s->else_branch.size() > 0) {
                int end_jump = emit_jump(OP_JUMP);
                patch_jump(else_jump);

                for (int i = 0; i < s->else_branch.size(); i++) {
                    compile_statement(s->else_branch[i]);
                }

                patch_jump(end_jump);
            } else {
                patch_jump(else_jump);
            }
            break;
        }
        case STMT_REDIM: {
            ReDimStatement* s = (ReDimStatement*)stmt;
            if (s->array_sizes.size() != 1) {
                // Multi-dimensional ReDim not yet supported in bytecode
                compile_ok = false;
                break;
            }

            if (s->preserve) {
                // ReDim Preserve: resize existing array in-place
                // Push current array value
                String key = s->variable_name.to_lower();
                int slot = get_or_add_local(s->variable_name, VT_UNKNOWN);
                if (slot >= 0) {
                    emit_bytes(OP_GET_LOCAL, (uint8_t)slot);
                } else {
                    int gidx = current_chunk->add_constant(s->variable_name);
                    emit_byte(OP_GET_GLOBAL);
                    emit_const_index(gidx);
                }

                // Push new size = expr + 1 (VB arrays are 0..N)
                compile_expression(s->array_sizes[0]);
                emit_constant(Variant((int64_t)1));
                emit_byte(OP_ADD);

                // Resize array
                emit_byte(OP_ARRAY_RESIZE);

                // Store result back
                if (slot >= 0) {
                    emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                } else {
                    int gidx = current_chunk->add_constant(s->variable_name);
                    emit_byte(OP_SET_GLOBAL);
                    emit_const_index(gidx);
                }
            } else {
                // Non-preserve: create brand new array
                // size = expr + 1 (VB arrays are 0..N)
                compile_expression(s->array_sizes[0]);
                emit_constant(Variant((int64_t)1));
                emit_byte(OP_ADD);
                String key = s->variable_name.to_lower();
                emit_byte(OP_NEW_ARRAY);

                int slot = get_or_add_local(s->variable_name, VT_UNKNOWN);
                if (slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                else {
                    int idx = current_chunk->add_constant(s->variable_name);
                    emit_byte(OP_SET_GLOBAL);
                    emit_const_index(idx);
                }
            }
            break;
        }
        case STMT_ERASE: {
            EraseStatement* es = (EraseStatement*)stmt;
            // Reset variable to its default value based on tracked type
            String key = es->variable_name.to_lower();
            if (array_vars.has(key)) {
                // Array variable → reset to empty Array
                emit_constant(Variant((int64_t)0));
                emit_byte(OP_NEW_ARRAY);
            } else if (dictionary_vars.has(key)) {
                // Dictionary variable → reset to empty Dictionary
                emit_byte(OP_NEW_DICT);
            } else {
                // Unknown type → reset to Nil (default Variant)
                emit_byte(OP_NIL);
            }
            int slot = get_or_add_local(es->variable_name, VT_UNKNOWN);
            if (slot >= 0) {
                emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
            } else {
                int idx = current_chunk->add_constant(es->variable_name);
                emit_byte(OP_SET_GLOBAL);
                emit_const_index(idx);
            }
            break;
        }
        case STMT_EXIT: {
            ExitStatement *s = (ExitStatement *)stmt;
            if (s->exit_type == ExitStatement::EXIT_FUNCTION || s->exit_type == ExitStatement::EXIT_SUB) {
                emit_return();
            } else if ((s->exit_type == ExitStatement::EXIT_FOR || s->exit_type == ExitStatement::EXIT_DO ||
                       s->exit_type == ExitStatement::EXIT_WHILE ||
                       s->exit_type == ExitStatement::EXIT_OSCILLATE || s->exit_type == ExitStatement::EXIT_REPEAT ||
                       s->exit_type == ExitStatement::EXIT_CYCLE) &&
                       !loop_exit_jumps.is_empty()) {
                // Emit an unconditional jump; the address will be patched
                // when the enclosing loop finishes compiling.
                int jump_addr = emit_jump(OP_JUMP);
                loop_exit_jumps.write[loop_exit_jumps.size() - 1].push_back(jump_addr);
            } else {
                UtilityFunctions::print("Compiler: Unsupported exit type", s->exit_type);
                compile_ok = false;
            }
            break;
        }
        case STMT_WHENEVER_SECTION: {
            // Compile Whenever section registration to bytecode
            WheneverSectionStatement* s = (WheneverSectionStatement*)stmt;
            
            // Create a Dictionary with all the section data that the executor needs
            Dictionary section_data;
            section_data["section_name"] = s->section_name;
            section_data["variable_name"] = s->variable_name;
            section_data["comparison_operator"] = s->comparison_operator;
            section_data["is_local_scope"] = s->is_local_scope;
            
            // Store callback procedures as an Array
            Array callbacks;
            for (int i = 0; i < s->callback_procedures.size(); i++) {
                callbacks.push_back(s->callback_procedures[i]);
            }
            section_data["callback_procedures"] = callbacks;
            
            // Store comparison values if they are constant literals
            if (s->comparison_value && is_constant_expr(s->comparison_value)) {
                section_data["comparison_value"] = eval_constant_expr(s->comparison_value);
            }
            if (s->comparison_value2 && is_constant_expr(s->comparison_value2)) {
                section_data["comparison_value2"] = eval_constant_expr(s->comparison_value2);
            }
            
            // Note: For complex expressions (comparison_value, comparison_value2, condition_expression),
            // the executor will need access to the AST. We store AST pointer addresses which the
            // executor can use to get back to the original AST nodes.
            // This works because the AST lives for the duration of script execution.
            if (s->comparison_value) {
                section_data["comparison_value_ptr"] = (int64_t)(uintptr_t)s->comparison_value;
            }
            if (s->comparison_value2) {
                section_data["comparison_value2_ptr"] = (int64_t)(uintptr_t)s->comparison_value2;
            }
            if (s->condition_expression) {
                section_data["condition_expression_ptr"] = (int64_t)(uintptr_t)s->condition_expression;
            }
            
            // Store scope context info
            if (current_sub) {
                section_data["scope_context"] = current_sub->name;
            }
            
            int data_idx = current_chunk->add_constant(section_data);
            emit_byte(OP_REGISTER_WHENEVER);
            emit_const_index(data_idx);
            break;
        }
        case STMT_SUSPEND_WHENEVER: {
            SuspendWheneverStatement* s = (SuspendWheneverStatement*)stmt;
            int name_idx = current_chunk->add_constant(s->section_name);
            emit_byte(OP_SUSPEND_WHENEVER);
            emit_const_index(name_idx);
            break;
        }
        case STMT_RESUME_WHENEVER: {
            ResumeWheneverStatement* s = (ResumeWheneverStatement*)stmt;
            int name_idx = current_chunk->add_constant(s->section_name);
            emit_byte(OP_RESUME_WHENEVER);
            emit_const_index(name_idx);
            break;
        }
        case STMT_SELECT: {
            SelectStatement* s = (SelectStatement*)stmt;
        // M6: Try O(1) jump table dispatch
        if (try_compile_jump_table(s)) break;
            if (!s->expression) {
                compile_ok = false;
                break;
            }
            
            // Compile the select expression once and store in a temp local
            int select_slot = get_or_add_local(String("__select_") + String::num_int64(temp_local_id++), infer_type(s->expression));
            compile_expression(s->expression);
            if (select_slot >= 0) {
                emit_bytes(OP_SET_LOCAL, (uint8_t)select_slot);
            }
            
            Vector<int> end_jumps;
            
            for (int i = 0; i < s->cases.size(); i++) {
                CaseBlock* cb = s->cases[i];
                
                if (cb->is_else) {
                    // Case Else - just compile the body
                    for (int j = 0; j < cb->body.size(); j++) {
                        compile_statement(cb->body[j]);
                    }
                } else {
                    // Regular Case - check each value (may include ranges and comparison ops)
                    Vector<int> case_match_jumps;
                    
                    for (int v = 0; v < cb->values.size(); v++) {
                        bool has_comp_op = (v < cb->comparison_ops.size() && !cb->comparison_ops[v].is_empty());
                        bool has_range = (v < cb->range_ends.size() && cb->range_ends[v] != nullptr);
                        
                        if (has_comp_op) {
                            // Case Is > value, Case Is <= value, etc.
                            if (select_slot >= 0) {
                                emit_bytes(OP_GET_LOCAL, (uint8_t)select_slot);
                            }
                            compile_expression(cb->values[v]);
                            String comp_op = cb->comparison_ops[v];
                            if (comp_op == ">") emit_byte(OP_GREATER);
                            else if (comp_op == "<") emit_byte(OP_LESS);
                            else if (comp_op == ">=") emit_byte(OP_GREATER_EQUAL);
                            else if (comp_op == "<=") emit_byte(OP_LESS_EQUAL);
                            else if (comp_op == "<>") emit_byte(OP_NOT_EQUAL);
                            else if (comp_op == "=") emit_byte(OP_EQUAL);
                            else { compile_ok = false; break; }
                            int match_jump = emit_jump(OP_JUMP_IF_TRUE);
                            case_match_jumps.push_back(match_jump);
                        } else if (has_range) {
                            // Range check: select_value >= low AND select_value <= high
                            if (select_slot >= 0) {
                                emit_bytes(OP_GET_LOCAL, (uint8_t)select_slot);
                            }
                            compile_expression(cb->values[v]);
                            emit_byte(OP_GREATER_EQUAL);
                            int ge_fail = emit_jump(OP_JUMP_IF_FALSE);
                            
                            // >= passed, now check <= high
                            if (select_slot >= 0) {
                                emit_bytes(OP_GET_LOCAL, (uint8_t)select_slot);
                            }
                            compile_expression(cb->range_ends[v]);
                            emit_byte(OP_LESS_EQUAL);
                            int le_match = emit_jump(OP_JUMP_IF_TRUE);
                            case_match_jumps.push_back(le_match);
                            
                            // >= failed — skip to next value check
                            patch_jump(ge_fail);
                        } else {
                            // Simple value check
                            if (select_slot >= 0) {
                                emit_bytes(OP_GET_LOCAL, (uint8_t)select_slot);
                            }
                            compile_expression(cb->values[v]);
                            emit_byte(OP_EQUAL);
                            int match_jump = emit_jump(OP_JUMP_IF_TRUE);
                            case_match_jumps.push_back(match_jump);
                        }
                    }
                    if (!compile_ok) break;
                    
                    // None of the values matched - jump to next case
                    int skip_case_jump = emit_jump(OP_JUMP);
                    
                    // Patch all match jumps to here (the case body)
                    for (int j = 0; j < case_match_jumps.size(); j++) {
                        patch_jump(case_match_jumps[j]);
                    }
                    
                    // Compile case body
                    for (int j = 0; j < cb->body.size(); j++) {
                        compile_statement(cb->body[j]);
                    }
                    
                    // Jump to end of select after executing case body
                    int end_jump = emit_jump(OP_JUMP);
                    end_jumps.push_back(end_jump);
                    
                    // Patch the skip jump to continue to next case
                    patch_jump(skip_case_jump);
                }
            }
            
            // Patch all end jumps to here
            for (int i = 0; i < end_jumps.size(); i++) {
                patch_jump(end_jumps[i]);
            }
            break;
        }
        case STMT_DO: {
            // Do...Loop statement with optional While/Until conditions
            DoStatement* s = (DoStatement*)stmt;
            
            loop_exit_jumps.push_back(Vector<int>());
            loop_continue_targets.push_back(-1); // placeholder
            loop_continue_forward_jumps.push_back(Vector<int>());
            int loop_start = current_chunk->code.size();
            
            if (!s->is_post_condition && s->condition_type != DoStatement::NONE) {
                // Pre-condition: Do While/Until ... Loop
                // Continue Do jumps to loop_start (re-test condition)
                loop_continue_targets.write[loop_continue_targets.size() - 1] = loop_start;
                compile_expression(s->condition);
                int exit_jump;
                if (s->condition_type == DoStatement::WHILE) {
                    exit_jump = emit_jump(OP_JUMP_IF_FALSE);
                } else { // UNTIL
                    exit_jump = emit_jump(OP_JUMP_IF_TRUE);
                }
                
                // Compile body
                for (int i = 0; i < s->body.size(); i++) {
                    compile_statement(s->body[i]);
                }
                
                emit_loop(loop_start);
                patch_jump(exit_jump);
            } else if (s->is_post_condition && s->condition_type != DoStatement::NONE) {
                // Post-condition: Do ... Loop While/Until
                
                // Compile body first
                for (int i = 0; i < s->body.size(); i++) {
                    compile_statement(s->body[i]);
                }
                
                // Continue Do target: right before the condition check
                loop_continue_targets.write[loop_continue_targets.size() - 1] = current_chunk->code.size();

                // Check condition at the end
                compile_expression(s->condition);
                if (s->condition_type == DoStatement::WHILE) {
                    // Loop While: if condition FALSE, exit; otherwise jump back
                    int exit_jump = emit_jump(OP_JUMP_IF_FALSE);
                    emit_loop(loop_start);
                    patch_jump(exit_jump);
                } else { // UNTIL
                    // Loop Until: if condition TRUE, exit; otherwise jump back
                    int exit_jump = emit_jump(OP_JUMP_IF_TRUE);
                    emit_loop(loop_start);
                    patch_jump(exit_jump);
                }
            } else {
                // Infinite loop: Do ... Loop (no condition)
                // Continue Do jumps back to loop_start
                loop_continue_targets.write[loop_continue_targets.size() - 1] = loop_start;
                for (int i = 0; i < s->body.size(); i++) {
                    compile_statement(s->body[i]);
                }
                emit_loop(loop_start);
            }
            // Patch any Exit Do jumps collected during this loop body
            if (!loop_exit_jumps.is_empty()) {
                const Vector<int> &exits = loop_exit_jumps[loop_exit_jumps.size() - 1];
                for (int ei = 0; ei < exits.size(); ei++) {
                    patch_jump(exits[ei]);
                }
                loop_exit_jumps.remove_at(loop_exit_jumps.size() - 1);
            }
            if (!loop_continue_targets.is_empty()) {
                loop_continue_targets.remove_at(loop_continue_targets.size() - 1);
            }
            if (!loop_continue_forward_jumps.is_empty()) {
                loop_continue_forward_jumps.remove_at(loop_continue_forward_jumps.size() - 1);
            }
            break;
        }
        case STMT_OSCILLATE: {
            // Oscillate i = from To to [Step s] [Cycles n]
            //   ... body ...
            // Loop
            //
            // Ping-pong loop: counter bounces between from_val and to_val.
            // Hidden variables: __osc_dir_<var> (1 or -1), __osc_cyc_<var> (cycle count)
            OscillateStatement* os = (OscillateStatement*)stmt;
            if (!os->from_val || !os->to_val) {
                compile_ok = false;
                break;
            }

            loop_exit_jumps.push_back(Vector<int>());
            loop_continue_targets.push_back(-1);
            loop_continue_forward_jumps.push_back(Vector<int>());

            String var_lower = os->variable_name.to_lower();
            String dir_name = "__osc_dir_" + var_lower;
            String cyc_name = "__osc_cyc_" + var_lower;

            int var_slot = get_or_add_local(os->variable_name, VT_UNKNOWN);
            int dir_slot = get_or_add_local(dir_name, VT_INT);
            int cyc_slot = os->cycles_val ? get_or_add_local(cyc_name, VT_INT) : -1;

            // Cache from_val and to_val into locals for boundary checks
            int from_slot = get_or_add_local(String("__osc_from_") + String::num_int64(temp_local_id++), VT_UNKNOWN);
            int to_slot = get_or_add_local(String("__osc_to_") + String::num_int64(temp_local_id++), VT_UNKNOWN);

            // Initialize from_val → from_slot and var_slot
            compile_expression(os->from_val);
            if (from_slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)from_slot);
            if (var_slot >= 0) {
                if (from_slot >= 0) emit_bytes(OP_GET_LOCAL, (uint8_t)from_slot);
                else compile_expression(os->from_val);
                emit_bytes(OP_SET_LOCAL, (uint8_t)var_slot);
            }

            // Initialize to_val → to_slot
            compile_expression(os->to_val);
            if (to_slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)to_slot);

            // Initialize direction = 1
            emit_constant(Variant((int64_t)1));
            if (dir_slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)dir_slot);

            // Initialize cycle counter = 0
            if (cyc_slot >= 0) {
                emit_constant(Variant((int64_t)0));
                emit_bytes(OP_SET_LOCAL, (uint8_t)cyc_slot);
            }

            // Cache step into a local
            int step_slot = get_or_add_local(String("__osc_step_") + String::num_int64(temp_local_id++), VT_UNKNOWN);
            if (os->step_val) {
                compile_expression(os->step_val);
            } else {
                emit_constant(Variant((int64_t)1));
            }
            if (step_slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)step_slot);

            // ── Loop start ──
            int loop_start = current_chunk->code.size();

            // Compile body
            for (int i = 0; i < os->body.size(); i++) {
                compile_statement(os->body[i]);
            }

            // ── Continue target: increment and boundary logic ──
            int continue_target = current_chunk->code.size();
            if (!loop_continue_targets.is_empty()) {
                loop_continue_targets.write[loop_continue_targets.size() - 1] = continue_target;
            }
            // Patch any forward Continue jumps emitted during the body
            if (!loop_continue_forward_jumps.is_empty()) {
                const Vector<int> &fwd = loop_continue_forward_jumps[loop_continue_forward_jumps.size() - 1];
                for (int fi = 0; fi < fwd.size(); fi++) {
                    patch_jump(fwd[fi]);
                }
            }

            // var += step * dir
            if (var_slot >= 0) emit_bytes(OP_GET_LOCAL, (uint8_t)var_slot);
            if (step_slot >= 0) emit_bytes(OP_GET_LOCAL, (uint8_t)step_slot);
            else emit_constant(Variant((int64_t)1));
            if (dir_slot >= 0) emit_bytes(OP_GET_LOCAL, (uint8_t)dir_slot);
            else emit_constant(Variant((int64_t)1));
            emit_byte(OP_MULTIPLY);  // step * dir
            emit_byte(OP_ADD);  // var + (step * dir)
            if (var_slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)var_slot);

            // ── Upper boundary check: if var >= to_val → clamp & reverse ──
            if (var_slot >= 0) emit_bytes(OP_GET_LOCAL, (uint8_t)var_slot);
            if (to_slot >= 0) emit_bytes(OP_GET_LOCAL, (uint8_t)to_slot);
            emit_byte(OP_GREATER_EQUAL);
            int skip_upper = emit_jump(OP_JUMP_IF_FALSE);
            {
                // var = to_val
                if (to_slot >= 0) emit_bytes(OP_GET_LOCAL, (uint8_t)to_slot);
                if (var_slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)var_slot);
                // dir = -1
                emit_constant(Variant((int64_t)-1));
                if (dir_slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)dir_slot);
                // cyc++
                if (cyc_slot >= 0) {
                    emit_bytes(OP_GET_LOCAL, (uint8_t)cyc_slot);
                    emit_constant(Variant((int64_t)1));
                    emit_byte(OP_ADD);
                    emit_bytes(OP_SET_LOCAL, (uint8_t)cyc_slot);
                }
            }
            int skip_lower_entirely = emit_jump(OP_JUMP); // else-if: skip lower check if upper fired
            patch_jump(skip_upper);

            // ── Lower boundary check: if var <= from_val → clamp & reverse ──
            if (var_slot >= 0) emit_bytes(OP_GET_LOCAL, (uint8_t)var_slot);
            if (from_slot >= 0) emit_bytes(OP_GET_LOCAL, (uint8_t)from_slot);
            emit_byte(OP_LESS_EQUAL);
            int skip_lower = emit_jump(OP_JUMP_IF_FALSE);
            {
                // var = from_val
                if (from_slot >= 0) emit_bytes(OP_GET_LOCAL, (uint8_t)from_slot);
                if (var_slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)var_slot);
                // dir = 1
                emit_constant(Variant((int64_t)1));
                if (dir_slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)dir_slot);
                // cyc++
                if (cyc_slot >= 0) {
                    emit_bytes(OP_GET_LOCAL, (uint8_t)cyc_slot);
                    emit_constant(Variant((int64_t)1));
                    emit_byte(OP_ADD);
                    emit_bytes(OP_SET_LOCAL, (uint8_t)cyc_slot);
                }
            }
            patch_jump(skip_lower);
            patch_jump(skip_lower_entirely); // join point for both branches

            // ── Cycles exit check: if cyc >= cycles_val → exit ──
            if (os->cycles_val && cyc_slot >= 0) {
                emit_bytes(OP_GET_LOCAL, (uint8_t)cyc_slot);
                compile_expression(os->cycles_val);
                emit_byte(OP_GREATER_EQUAL);
                int cycles_exit = emit_jump(OP_JUMP_IF_TRUE);
                // Record this exit jump so it gets patched at the end
                if (!loop_exit_jumps.is_empty()) {
                    loop_exit_jumps.write[loop_exit_jumps.size() - 1].push_back(cycles_exit);
                }
            }

            emit_loop(loop_start);

            // Patch exit jumps
            if (!loop_exit_jumps.is_empty()) {
                const Vector<int> &exits = loop_exit_jumps[loop_exit_jumps.size() - 1];
                for (int ei = 0; ei < exits.size(); ei++) {
                    patch_jump(exits[ei]);
                }
                loop_exit_jumps.remove_at(loop_exit_jumps.size() - 1);
            }
            if (!loop_continue_targets.is_empty()) {
                loop_continue_targets.remove_at(loop_continue_targets.size() - 1);
            }
            if (!loop_continue_forward_jumps.is_empty()) {
                loop_continue_forward_jumps.remove_at(loop_continue_forward_jumps.size() - 1);
            }
            break;
        }
        case STMT_REPEAT: {
            // Repeat N Times [As counter]
            //   ... body ...
            // End Repeat
            //
            // Simple counted loop.  Hidden __repeat_i counts from 1 to N.
            // If "As counter" is used, the user variable mirrors __repeat_i.
            RepeatStatement* rp = (RepeatStatement*)stmt;
            if (!rp->count_val) {
                compile_ok = false;
                break;
            }

            loop_exit_jumps.push_back(Vector<int>());
            loop_continue_targets.push_back(-1);
            loop_continue_forward_jumps.push_back(Vector<int>());

            // Allocate hidden locals for counter and limit
            int i_slot = get_or_add_local(String("__repeat_i_") + String::num_int64(temp_local_id), VT_INT);
            int n_slot = get_or_add_local(String("__repeat_n_") + String::num_int64(temp_local_id), VT_INT);
            temp_local_id++;

            int user_slot = -1;
            if (!rp->counter_name.is_empty()) {
                user_slot = get_or_add_local(rp->counter_name, VT_INT);
            }

            // Initialize: __repeat_n = count_val
            compile_expression(rp->count_val);
            emit_bytes(OP_SET_LOCAL, (uint8_t)n_slot);

            // Initialize: __repeat_i = 1
            emit_constant(Variant((int64_t)1));
            emit_bytes(OP_SET_LOCAL, (uint8_t)i_slot);

            // If user counter, set it too: counter = 1
            if (user_slot >= 0) {
                emit_bytes(OP_GET_LOCAL, (uint8_t)i_slot);
                emit_bytes(OP_SET_LOCAL, (uint8_t)user_slot);
            }

            // ── Loop start: condition check ──
            int loop_start = current_chunk->code.size();

            // if __repeat_i > __repeat_n then exit
            emit_bytes(OP_GET_LOCAL, (uint8_t)i_slot);
            emit_bytes(OP_GET_LOCAL, (uint8_t)n_slot);
            emit_byte(OP_GREATER);
            int exit_jump = emit_jump(OP_JUMP_IF_TRUE);
            if (!loop_exit_jumps.is_empty()) {
                loop_exit_jumps.write[loop_exit_jumps.size() - 1].push_back(exit_jump);
            }

            // Compile body
            for (int i = 0; i < rp->body.size(); i++) {
                compile_statement(rp->body[i]);
            }

            // ── Continue target: increment counter ──
            int continue_target = current_chunk->code.size();
            if (!loop_continue_targets.is_empty()) {
                loop_continue_targets.write[loop_continue_targets.size() - 1] = continue_target;
            }
            // Patch forward Continue jumps
            if (!loop_continue_forward_jumps.is_empty()) {
                const Vector<int> &fwd = loop_continue_forward_jumps[loop_continue_forward_jumps.size() - 1];
                for (int fi = 0; fi < fwd.size(); fi++) {
                    patch_jump(fwd[fi]);
                }
            }

            // __repeat_i = __repeat_i + 1
            emit_bytes(OP_GET_LOCAL, (uint8_t)i_slot);
            emit_constant(Variant((int64_t)1));
            emit_byte(OP_ADD);
            emit_bytes(OP_SET_LOCAL, (uint8_t)i_slot);

            // Update user counter if present
            if (user_slot >= 0) {
                emit_bytes(OP_GET_LOCAL, (uint8_t)i_slot);
                emit_bytes(OP_SET_LOCAL, (uint8_t)user_slot);
            }

            emit_loop(loop_start);

            // Patch exit jumps
            if (!loop_exit_jumps.is_empty()) {
                const Vector<int> &exits = loop_exit_jumps[loop_exit_jumps.size() - 1];
                for (int ei = 0; ei < exits.size(); ei++) {
                    patch_jump(exits[ei]);
                }
                loop_exit_jumps.remove_at(loop_exit_jumps.size() - 1);
            }
            if (!loop_continue_targets.is_empty()) {
                loop_continue_targets.remove_at(loop_continue_targets.size() - 1);
            }
            if (!loop_continue_forward_jumps.is_empty()) {
                loop_continue_forward_jumps.remove_at(loop_continue_forward_jumps.size() - 1);
            }
            break;
        }
        case STMT_CYCLE: {
            // Cycle Through collection For N As element
            //   ... body ...
            // End Cycle
            //
            // Iterates N times through a collection, wrapping around using
            // modular indexing: element = collection[i Mod Len(collection)]
            CycleStatement* cy = (CycleStatement*)stmt;
            if (!cy->collection || !cy->count_val || cy->element_name.is_empty()) {
                compile_ok = false;
                break;
            }

            loop_exit_jumps.push_back(Vector<int>());
            loop_continue_targets.push_back(-1);
            loop_continue_forward_jumps.push_back(Vector<int>());

            // Allocate locals: collection cache, length cache, counter, limit, element
            int coll_slot = get_or_add_local(String("__cycle_coll_") + String::num_int64(temp_local_id), VT_UNKNOWN);
            int len_slot  = get_or_add_local(String("__cycle_len_") + String::num_int64(temp_local_id), VT_INT);
            int i_slot    = get_or_add_local(String("__cycle_i_") + String::num_int64(temp_local_id), VT_INT);
            int n_slot    = get_or_add_local(String("__cycle_n_") + String::num_int64(temp_local_id), VT_INT);
            temp_local_id++;
            int elem_slot = get_or_add_local(cy->element_name, VT_UNKNOWN);

            // Initialize collection → coll_slot
            compile_expression(cy->collection);
            emit_byte(OP_DICT_KEYS_CALL); // convert Dict→keys array, pass arrays through
            emit_bytes(OP_SET_LOCAL, (uint8_t)coll_slot);

            // len_slot = Len(collection)
            emit_bytes(OP_GET_LOCAL, (uint8_t)coll_slot);
            emit_byte(OP_LEN);
            emit_bytes(OP_SET_LOCAL, (uint8_t)len_slot);

            // n_slot = count_val (total iterations)
            compile_expression(cy->count_val);
            emit_bytes(OP_SET_LOCAL, (uint8_t)n_slot);

            // i_slot = 0 (iteration counter)
            emit_constant(Variant((int64_t)0));
            emit_bytes(OP_SET_LOCAL, (uint8_t)i_slot);

            // ── Loop start ──
            int loop_start = current_chunk->code.size();

            // if i >= n then exit
            emit_bytes(OP_GET_LOCAL, (uint8_t)i_slot);
            emit_bytes(OP_GET_LOCAL, (uint8_t)n_slot);
            emit_byte(OP_GREATER_EQUAL);
            int exit_jump = emit_jump(OP_JUMP_IF_TRUE);
            if (!loop_exit_jumps.is_empty()) {
                loop_exit_jumps.write[loop_exit_jumps.size() - 1].push_back(exit_jump);
            }

            // element = collection[i Mod len]
            emit_bytes(OP_GET_LOCAL, (uint8_t)coll_slot);
            emit_bytes(OP_GET_LOCAL, (uint8_t)i_slot);
            emit_bytes(OP_GET_LOCAL, (uint8_t)len_slot);
            emit_byte(OP_MOD);  // i Mod len
            emit_byte(OP_GET_ARRAY);
            emit_byte(1);  // 1 index dimension
            emit_bytes(OP_SET_LOCAL, (uint8_t)elem_slot);

            // Compile body
            for (int i = 0; i < cy->body.size(); i++) {
                compile_statement(cy->body[i]);
            }

            // ── Continue target: increment ──
            int continue_target = current_chunk->code.size();
            if (!loop_continue_targets.is_empty()) {
                loop_continue_targets.write[loop_continue_targets.size() - 1] = continue_target;
            }
            if (!loop_continue_forward_jumps.is_empty()) {
                const Vector<int> &fwd = loop_continue_forward_jumps[loop_continue_forward_jumps.size() - 1];
                for (int fi = 0; fi < fwd.size(); fi++) {
                    patch_jump(fwd[fi]);
                }
            }

            // i = i + 1
            if (i_slot >= 0 && i_slot < 256) {
                emit_bytes(OP_INC_LOCAL_I64, (uint8_t)i_slot);
            } else {
                emit_bytes(OP_GET_LOCAL, (uint8_t)i_slot);
                emit_constant(Variant((int64_t)1));
                emit_byte(OP_ADD);
                emit_bytes(OP_SET_LOCAL, (uint8_t)i_slot);
            }

            emit_loop(loop_start);

            // Patch exit jumps
            if (!loop_exit_jumps.is_empty()) {
                const Vector<int> &exits = loop_exit_jumps[loop_exit_jumps.size() - 1];
                for (int ei = 0; ei < exits.size(); ei++) {
                    patch_jump(exits[ei]);
                }
                loop_exit_jumps.remove_at(loop_exit_jumps.size() - 1);
            }
            if (!loop_continue_targets.is_empty()) {
                loop_continue_targets.remove_at(loop_continue_targets.size() - 1);
            }
            if (!loop_continue_forward_jumps.is_empty()) {
                loop_continue_forward_jumps.remove_at(loop_continue_forward_jumps.size() - 1);
            }
            break;
        }
        case STMT_EVERY: {
            // Every N Frames/Seconds ... End Every
            //
            // NOT a loop — a conditional guard using hidden persistent globals.
            // Frames mode: hidden counter increments each entry, fires when >= N.
            // Seconds mode: tracks last-fire time, fires when elapsed >= N.
            EveryStatement* ev = (EveryStatement*)stmt;
            if (!ev->interval_val) {
                compile_ok = false;
                break;
            }

            String id_str = String::num_int64(ev->unique_id);

            if (ev->interval_type == EveryStatement::FRAMES) {
                // __every_frame_<id> counter stored as a global
                String counter_name = "__every_frame_" + id_str;
                int counter_idx = current_chunk->add_constant(counter_name);

                // Initialize counter to 0 if Nil (first call).
                // OP_GET_GLOBAL returns Nil for unset globals;
                // OP_ADD crashes on Nil + Int, so we must guard.
                emit_byte(OP_GET_GLOBAL);
                emit_const_index(counter_idx);
                emit_byte(OP_NIL);
                emit_byte(OP_EQUAL);
                int skip_init = emit_jump(OP_JUMP_IF_FALSE);
                {
                    emit_constant(Variant((int64_t)0));
                    emit_byte(OP_SET_GLOBAL);
                    emit_const_index(counter_idx);
                }
                patch_jump(skip_init);

                // counter = counter + 1  (get, add 1, set)
                emit_byte(OP_GET_GLOBAL);
                emit_const_index(counter_idx);
                emit_constant(Variant((int64_t)1));
                emit_byte(OP_ADD);
                emit_byte(OP_SET_GLOBAL);
                emit_const_index(counter_idx);

                // if counter >= N then ...
                emit_byte(OP_GET_GLOBAL);
                emit_const_index(counter_idx);
                compile_expression(ev->interval_val);
                emit_byte(OP_GREATER_EQUAL);
                int skip_jump = emit_jump(OP_JUMP_IF_FALSE);

                // counter = 0 (reset)
                emit_constant(Variant((int64_t)0));
                emit_byte(OP_SET_GLOBAL);
                emit_const_index(counter_idx);

                // Compile body
                for (int i = 0; i < ev->body.size(); i++) {
                    compile_statement(ev->body[i]);
                }

                patch_jump(skip_jump);

            } else {
                // Seconds mode
                String last_name = "__every_last_" + id_str;
                int last_idx = current_chunk->add_constant(last_name);
                int timer_fn_idx = current_chunk->add_constant(String("Timer"));

                // current_time = Timer()
                emit_byte(OP_CALL);
                emit_const_index(timer_fn_idx);
                emit_byte((uint8_t)0);

                // We need to keep current_time on the stack for later use.
                // Use a temp local to hold it.
                int time_slot = get_or_add_local(String("__every_now_") + id_str, VT_UNKNOWN);
                emit_bytes(OP_SET_LOCAL, (uint8_t)time_slot);

                // If __every_last is Nil (uninitialized), set it to current_time
                emit_byte(OP_GET_GLOBAL);
                emit_const_index(last_idx);
                emit_byte(OP_NIL);
                emit_byte(OP_EQUAL);
                int skip_init = emit_jump(OP_JUMP_IF_FALSE);
                {
                    emit_bytes(OP_GET_LOCAL, (uint8_t)time_slot);
                    emit_byte(OP_SET_GLOBAL);
                    emit_const_index(last_idx);
                }
                patch_jump(skip_init);

                // elapsed = current_time - __every_last
                emit_bytes(OP_GET_LOCAL, (uint8_t)time_slot);
                emit_byte(OP_GET_GLOBAL);
                emit_const_index(last_idx);
                emit_byte(OP_SUBTRACT);

                // if elapsed >= N then ...
                compile_expression(ev->interval_val);
                emit_byte(OP_GREATER_EQUAL);
                int skip_jump = emit_jump(OP_JUMP_IF_FALSE);

                // __every_last = current_time
                emit_bytes(OP_GET_LOCAL, (uint8_t)time_slot);
                emit_byte(OP_SET_GLOBAL);
                emit_const_index(last_idx);

                // Compile body
                for (int i = 0; i < ev->body.size(); i++) {
                    compile_statement(ev->body[i]);
                }

                patch_jump(skip_jump);
            }
            break;
        }
        case STMT_TWEEN: {
            // Tween target.prop [From val] To val Over dur [Ease type] [Trans type]
            //
            // Compiles to a chain of OP_METHOD_CALL operations:
            //   1. target_node.create_tween()             → Ref<Tween>
            //   2. tween.tween_property(node, path, to, dur)  → PropertyTweener
            //   3. .from(from_val)                        (if From specified)
            //   4. .set_ease(ease_type)                   (if Ease specified)
            //   5. .set_trans(trans_type)                  (if Trans specified)
            //   6. OP_POP (discard final return)
            TweenStatement* tw = (TweenStatement*)stmt;
            if (!tw->target_node || !tw->to_val || !tw->duration) {
                compile_ok = false;
                break;
            }

            // VB6 property aliasing for the property path string
            String prop_path = tw->property_path;
            // Single-segment aliases (e.g., Tween Me.Left To ...)
            if (prop_path.nocasecmp_to("Left") == 0) prop_path = "position:x";
            else if (prop_path.nocasecmp_to("Top") == 0) prop_path = "position:y";
            else if (prop_path.nocasecmp_to("Width") == 0) prop_path = "size:x";
            else if (prop_path.nocasecmp_to("Height") == 0) prop_path = "size:y";
            else if (prop_path.nocasecmp_to("Caption") == 0) prop_path = "text";
            else if (prop_path.nocasecmp_to("Text") == 0) prop_path = "text";
            else if (prop_path.nocasecmp_to("Visible") == 0) prop_path = "visible";
            else if (prop_path.nocasecmp_to("Value") == 0) prop_path = "value";
            else {
                // Multi-segment: convert to lowercase for Godot (Position:X → position:x)
                prop_path = prop_path.to_lower();
            }

            int create_tween_idx = current_chunk->add_constant(String("create_tween"));
            int tween_prop_idx = current_chunk->add_constant(String("tween_property"));
            int path_idx = current_chunk->add_constant(prop_path);

            // Step 1: target_node.create_tween() → Tween on stack
            compile_expression(tw->target_node);
            emit_byte(OP_METHOD_CALL);
            emit_const_index(create_tween_idx);
            emit_byte((uint8_t)0); // 0 args

            // Step 2: tween.tween_property(target_node, path, to_val, duration)
            // Stack: [tween]
            // Push 4 args: node, path_string, final_value, duration
            compile_expression(tw->target_node);             // arg0: node
            emit_byte(OP_CONSTANT);
            emit_const_index(path_idx);                      // arg1: property path
            compile_expression(tw->to_val);                  // arg2: final value
            compile_expression(tw->duration);                // arg3: duration
            emit_byte(OP_METHOD_CALL);
            emit_const_index(tween_prop_idx);
            emit_byte((uint8_t)4); // 4 args
            // Stack: [PropertyTweener]

            // Step 3: .from(from_val) if From specified
            if (tw->from_val) {
                int from_idx = current_chunk->add_constant(String("from"));
                compile_expression(tw->from_val);
                emit_byte(OP_METHOD_CALL);
                emit_const_index(from_idx);
                emit_byte((uint8_t)1);
            }

            // Step 4: .set_ease(ease_type) if Ease specified
            if (tw->ease_type >= 0) {
                int set_ease_idx = current_chunk->add_constant(String("set_ease"));
                emit_constant(Variant((int64_t)tw->ease_type));
                emit_byte(OP_METHOD_CALL);
                emit_const_index(set_ease_idx);
                emit_byte((uint8_t)1);
            }

            // Step 5: .set_trans(trans_type) if Trans specified
            if (tw->trans_type >= 0) {
                int set_trans_idx = current_chunk->add_constant(String("set_trans"));
                emit_constant(Variant((int64_t)tw->trans_type));
                emit_byte(OP_METHOD_CALL);
                emit_const_index(set_trans_idx);
                emit_byte((uint8_t)1);
            }

            // Discard final return value (statement context)
            emit_byte(OP_POP);
            break;
        }
        case STMT_RETURN: {
            // Return statement (used in functions, or GoSub return if no value)
            ReturnStatement* s = (ReturnStatement*)stmt;
            if (s->return_value) {
                compile_expression(s->return_value);
                emit_byte(OP_RETURN_VALUE);
            } else {
                // Bare "Return" — could be GoSub return or Sub exit.
                // Emit OP_RETURN_GOSUB first; runtime checks gosub stack.
                // If stack is empty, it falls through to OP_RETURN.
                emit_byte(OP_RETURN_GOSUB);
            }
            break;
        }
        case STMT_RESTORE: {
            // Restore statement for DATA pointer - reset to beginning or to a label
            RestoreStatement* s = (RestoreStatement*)stmt;
            if (s->label_name.is_empty()) {
                // Restore to beginning - emit constant -1 to signal reset
                emit_constant(Variant((int64_t)-1));
            } else {
                // Restore to label - emit the label name for runtime lookup
                int label_idx = current_chunk->add_constant(s->label_name);
                emit_byte(OP_CONSTANT);
                emit_const_index(label_idx);
            }
            emit_byte(OP_RESTORE_DATA);
            break;
        }
        case STMT_READ: {
            // Read statement - read values from DATA segments into target variables
            ReadStatement* s = (ReadStatement*)stmt;
            for (int ri = 0; ri < s->targets.size(); ri++) {
                ExpressionNode* target = s->targets[ri];
                // Push next DATA value onto stack
                emit_byte(OP_READ_DATA);
                // Typed Read coercion (Read x As Integer)
                if (ri < s->type_names.size() && !s->type_names[ri].is_empty()) {
                    int type_idx = current_chunk->add_constant(s->type_names[ri]);
                    emit_byte(OP_COERCE_TYPE);
                    emit_const_index(type_idx);
                }
                // Store into target variable
                if (target->type == ExpressionNode::VARIABLE) {
                    VariableNode* tv = (VariableNode*)target;
                    int slot = get_or_add_local(tv->name, VT_UNKNOWN);
                    if (slot >= 0) {
                        emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                    } else {
                        int idx = current_chunk->add_constant(tv->name);
                        emit_byte(OP_SET_GLOBAL);
                        emit_const_index(idx);
                    }
                } else if (target->type == ExpressionNode::ARRAY_ACCESS) {
                    ArrayAccessNode* aa = (ArrayAccessNode*)target;
                    if (aa->indices.size() == 1 && aa->base->type == ExpressionNode::VARIABLE) {
                        VariableNode* v = (VariableNode*)aa->base;
                        // Stack: [value]
                        // Need: [array, index, value] for OP_SET_ARRAY
                        // So compile base and index, but value is already on stack.
                        // Rearrange: store value to temp, push array+index+value
                        int temp_slot = get_or_add_local("__read_tmp_" + String::num_int64(temp_local_id++), VT_UNKNOWN);
                        if (temp_slot >= 0) {
                            emit_bytes(OP_SET_LOCAL, (uint8_t)temp_slot); // save value
                            compile_expression(aa->base);                // push array
                            compile_expression(aa->indices[0]);          // push index
                            emit_bytes(OP_GET_LOCAL, (uint8_t)temp_slot); // push value
                            emit_byte(OP_SET_ARRAY);
                            emit_byte(1);
                            int arr_slot = get_or_add_local(v->name, VT_UNKNOWN);
                            if (arr_slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)arr_slot);
                            else {
                                int idx = current_chunk->add_constant(v->name);
                                emit_byte(OP_SET_GLOBAL);
                                emit_const_index(idx);
                            }
                        } else {
                            compile_ok = false;
                        }
                    } else {
                        compile_ok = false;
                    }
                } else {
                    compile_ok = false;
                }
            }
            break;
        }
        case STMT_ON_ERROR: {
            // On Error handling
            OnErrorStatement* s = (OnErrorStatement*)stmt;
            if (s->mode == OnErrorStatement::RESUME_NEXT) {
                emit_byte(OP_ON_ERROR_RESUME_NEXT);
            } else if (s->label_name.is_empty()) {
                // On Error Goto 0 - disable error handling
                emit_byte(OP_ON_ERROR_GOTO_0);
            } else {
                // On Error Goto <label>
                int label_idx = current_chunk->add_constant(s->label_name);
                emit_byte(OP_ON_ERROR_GOTO);
                emit_const_index(label_idx);
            }
            break;
        }
        case STMT_PARALLEL_FOR: {
            // Compile Parallel For with OP_PARALLEL_FOR_BEGIN / END.
            // The VM will dispatch iterations to WorkerThreadPool, each
            // running the body bytecode with its own locals[] copy.
            ParallelForStatement* pf = (ParallelForStatement*)stmt;
            if (!pf->start_expr || !pf->end_expr) {
                compile_ok = false;
                break;
            }

            loop_exit_jumps.push_back(Vector<int>());

            // Allocate a local slot for the loop variable.
            ValueType declared_type = get_local_type(pf->variable_name);
            ValueType init_type = declared_type != VT_UNKNOWN ? declared_type : infer_type(pf->start_expr);
            int var_slot = get_or_add_local(pf->variable_name, init_type);

            // Push start, end, step onto the stack for the VM to consume.
            compile_expression(pf->start_expr);
            compile_expression(pf->end_expr);
            if (pf->step_expr) {
                compile_expression(pf->step_expr);
            } else {
                emit_constant(Variant((int64_t)1));
            }

            // Emit OP_PARALLEL_FOR_BEGIN [var_slot] [body_len placeholder]
            emit_byte(OP_PARALLEL_FOR_BEGIN);
            emit_byte((uint8_t)(var_slot >= 0 ? var_slot : 0));
            // Reserve 2 bytes for body_len (patched after body compilation).
            int body_len_offset = current_chunk->code.size();
            emit_byte(0xFF);
            emit_byte(0xFF);

            int body_start = current_chunk->code.size();

            // Compile the loop body.
            for (int i = 0; i < pf->body.size(); i++) {
                compile_statement(pf->body[i]);
                if (!compile_ok) break;
            }

            // Emit OP_PARALLEL_FOR_END as a body terminator.
            emit_byte(OP_PARALLEL_FOR_END);

            int body_end = current_chunk->code.size();
            int body_len = body_end - body_start;

            // Patch the body length.
            current_chunk->code.write[body_len_offset]     = (uint8_t)((body_len >> 8) & 0xFF);
            current_chunk->code.write[body_len_offset + 1] = (uint8_t)(body_len & 0xFF);

            // Patch Exit For jumps to point past the body end.
            if (!loop_exit_jumps.is_empty()) {
                const Vector<int> &exits = loop_exit_jumps[loop_exit_jumps.size() - 1];
                for (int ei = 0; ei < exits.size(); ei++) {
                    patch_jump(exits[ei]);
                }
                loop_exit_jumps.remove_at(loop_exit_jumps.size() - 1);
            }
            break;
        }
        case STMT_STOP: {
            // VB6 Stop statement — emit OP_STOP to trigger debugger break
            emit_byte(OP_STOP);
            break;
        }
        case STMT_FOR_EACH: {
            // For Each var In collection ... Next
            ForEachStatement* s = (ForEachStatement*)stmt;
            if (!s->collection) {
                compile_ok = false;
                break;
            }

            // We need: a slot for the collection (as an array), a slot for the
            // index counter, and a slot for the iteration variable.
            int coll_slot = get_or_add_local(String("__foreach_coll_") + String::num_int64(temp_local_id), VT_UNKNOWN);
            int idx_slot  = get_or_add_local(String("__foreach_idx_")  + String::num_int64(temp_local_id), VT_INT);
            int var_slot   = get_or_add_local(s->variable_name, VT_UNKNOWN);
            temp_local_id++;
            if (coll_slot < 0 || idx_slot < 0) {
                compile_ok = false;
                break;
            }

            // Compile the collection expression.
            compile_expression(s->collection);

            // If the collection is a Dictionary we need its keys() array.
            // We can't know the type statically, so emit OP_DICT_KEYS_CALL
            // which will convert dict→keys at runtime (passes arrays through).
            emit_byte(OP_DICT_KEYS_CALL);

            // Store the (possibly converted) array in coll_slot.
            emit_bytes(OP_SET_LOCAL, (uint8_t)coll_slot);

            // Initialise index = 0
            emit_constant((int64_t)0);
            emit_bytes(OP_SET_LOCAL, (uint8_t)idx_slot);

            // Push Exit For jump list
            loop_exit_jumps.push_back(Vector<int>());
            loop_continue_targets.push_back(-1); // placeholder
            loop_continue_forward_jumps.push_back(Vector<int>());

            // --- loop header ---
            int loop_start = current_chunk->code.size();

            // if idx >= Len(coll) then exit
            emit_bytes(OP_GET_LOCAL, (uint8_t)idx_slot);
            emit_bytes(OP_GET_LOCAL, (uint8_t)coll_slot);
            emit_byte(OP_LEN);
            emit_byte(OP_GREATER_EQUAL);  // idx >= len → done
            int exit_jump = emit_jump(OP_JUMP_IF_TRUE);

            // var = coll(idx)  →  push coll, push idx, OP_GET_ARRAY 1
            emit_bytes(OP_GET_LOCAL, (uint8_t)coll_slot);
            emit_bytes(OP_GET_LOCAL, (uint8_t)idx_slot);
            emit_byte(OP_GET_ARRAY);
            emit_byte(1);
            if (var_slot >= 0) {
                emit_bytes(OP_SET_LOCAL, (uint8_t)var_slot);
            } else {
                int name_idx = current_chunk->add_constant(s->variable_name);
                emit_byte(OP_SET_GLOBAL);
                emit_const_index(name_idx);
            }

            // --- loop body ---
            for (int i = 0; i < s->body.size(); i++) {
                compile_statement(s->body[i]);
            }

            // Continue For target: the increment point
            if (!loop_continue_targets.is_empty()) {
                loop_continue_targets.write[loop_continue_targets.size() - 1] = current_chunk->code.size();
            }
            // Patch any forward Continue jumps emitted during the body
            if (!loop_continue_forward_jumps.is_empty()) {
                const Vector<int> &fwd = loop_continue_forward_jumps[loop_continue_forward_jumps.size() - 1];
                for (int fi = 0; fi < fwd.size(); fi++) {
                    patch_jump(fwd[fi]);
                }
            }

            // idx = idx + 1
            if (idx_slot >= 0 && idx_slot < 256) {
                emit_bytes(OP_INC_LOCAL_I64, (uint8_t)idx_slot);
            } else {
                emit_bytes(OP_GET_LOCAL, (uint8_t)idx_slot);
                emit_constant((int64_t)1);
                emit_byte(OP_ADD_I64);
                emit_bytes(OP_SET_LOCAL, (uint8_t)idx_slot);
            }

            // Jump back to loop header
            emit_loop(loop_start);

            // --- loop exit ---
            patch_jump(exit_jump);

            // Patch Exit For jumps
            const Vector<int> &exits = loop_exit_jumps[loop_exit_jumps.size() - 1];
            for (int ei = 0; ei < exits.size(); ei++) {
                patch_jump(exits[ei]);
            }
            loop_exit_jumps.remove_at(loop_exit_jumps.size() - 1);
            if (!loop_continue_targets.is_empty()) {
                loop_continue_targets.remove_at(loop_continue_targets.size() - 1);
            }
            if (!loop_continue_forward_jumps.is_empty()) {
                loop_continue_forward_jumps.remove_at(loop_continue_forward_jumps.size() - 1);
            }
            break;
        }
        case STMT_WITH: {
            // With expression ... End With
            WithStatement* s = (WithStatement*)stmt;
            if (!s->expression) {
                compile_ok = false;
                break;
            }
            // Evaluate the With expression and push onto With context stack
            compile_expression(s->expression);
            emit_byte(OP_PUSH_WITH);
            
            // Compile the body statements
            for (int i = 0; i < s->body.size(); i++) {
                compile_statement(s->body[i]);
            }
            
            // Pop the With context stack
            emit_byte(OP_POP_WITH);
            break;
        }
        case STMT_CONTINUE: {
            // Continue For / Continue Do / Continue While / Continue Oscillate
            ContinueStatement* cont = (ContinueStatement*)stmt;
            if (loop_continue_targets.is_empty()) {
                compile_ok = false;
                break;
            }
            int target = loop_continue_targets[loop_continue_targets.size() - 1];
            if (target < 0) {
                // Target not yet known — emit a forward jump and record it for patching
                int fwd = emit_jump(OP_JUMP);
                if (!loop_continue_forward_jumps.is_empty()) {
                    loop_continue_forward_jumps.write[loop_continue_forward_jumps.size() - 1].push_back(fwd);
                }
                break;
            }
            emit_loop(target);
            break;
        }
        case STMT_LABEL: {
            // Label: — record the bytecode offset for GoTo resolution
            LabelStatement* s = (LabelStatement*)stmt;
            label_positions[s->name.to_lower()] = current_chunk->code.size();
            // Patch any forward GoTo jumps that targeted this label
            String key = s->name.to_lower();
            if (goto_forward_jumps.has(key)) {
                const Vector<int> &jumps = goto_forward_jumps[key];
                for (int i = 0; i < jumps.size(); i++) {
                    patch_jump(jumps[i]);
                }
                goto_forward_jumps.erase(key);
            }
            break;
        }
        case STMT_GOTO: {
            // GoTo label
            GotoStatement* s = (GotoStatement*)stmt;
            String key = s->label_name.to_lower();
            if (label_positions.has(key)) {
                // Backward jump — label already seen
                emit_loop(label_positions[key]);
            } else {
                // Forward jump — emit a placeholder, patch when label is found
                int jump_addr = emit_jump(OP_JUMP);
                if (!goto_forward_jumps.has(key)) {
                    goto_forward_jumps[key] = Vector<int>();
                }
                goto_forward_jumps[key].push_back(jump_addr);
            }
            break;
        }
        case STMT_TRY: {
            // Try ... Catch [ex] ... Finally ... End Try
            TryStatement* s = (TryStatement*)stmt;
            
            // Allocate a local for the catch variable if provided
            int catch_var_slot = -1;
            if (!s->catch_var_name.is_empty()) {
                catch_var_slot = get_or_add_local(s->catch_var_name, VT_UNKNOWN);
                // The catch variable will hold a Dictionary — register it
                // so the compiler recognizes ex("Number") as a dict access.
                dictionary_vars.insert(s->catch_var_name.to_lower());
            }
            
            // OP_SETUP_TRY [offset_16] — offset to the catch handler
            int setup_try = emit_jump(OP_SETUP_TRY);
            
            // --- Try block ---
            for (int i = 0; i < s->try_block.size(); i++) {
                compile_statement(s->try_block[i]);
            }
            
            // No error: pop the exception handler and jump past catch
            emit_byte(OP_POP_TRY);
            int jump_to_finally = emit_jump(OP_JUMP);
            
            // --- Catch block (exception handler target) ---
            patch_jump(setup_try);
            
            // At this point the VM has stored the error in a Dictionary.
            // If there's a catch variable, store it.
            if (catch_var_slot >= 0) {
                // The VM pushes the exception dict on the stack before jumping here
                emit_bytes(OP_SET_LOCAL, (uint8_t)catch_var_slot);
            } else {
                // Pop the exception dict (not needed)
                emit_byte(OP_POP);
            }
            
            for (int i = 0; i < s->catch_block.size(); i++) {
                compile_statement(s->catch_block[i]);
            }
            
            // --- Finally block ---
            patch_jump(jump_to_finally);
            
            for (int i = 0; i < s->finally_block.size(); i++) {
                compile_statement(s->finally_block[i]);
            }
            break;
        }
        case STMT_RAISE: {
            // Raise / Throw — push error_code and message, emit OP_THROW
            RaiseStatement* s = (RaiseStatement*)stmt;
            if (s->code) {
                compile_expression(s->code);
            } else {
                emit_constant((int64_t)0);
            }
            if (s->msg) {
                compile_expression(s->msg);
            } else {
                emit_constant(String("Application error"));
            }
            emit_byte(OP_THROW);
            break;
        }
        case STMT_CONST: {
            // Evaluate the constant expression and store in the local const map.
            // References to this name in compile_expression will be inlined directly.
            ConstStatement* cs = (ConstStatement*)stmt;
            if (cs->value && is_constant_expr(cs->value)) {
                local_const_map[cs->name.to_lower()] = eval_constant_expr(cs->value);
            }
            break;
        }
        case STMT_PASS: {
            // Pass statement — intentional no-op
            break;
        }
        case STMT_OPEN: {
            // Open "path" For mode As #filenum
            OpenStatement* s = (OpenStatement*)stmt;
            compile_expression(s->path);       // push path
            compile_expression(s->file_number); // push file_num
            emit_byte(OP_OPEN_FILE);
            emit_byte((uint8_t)s->mode); // 0=Input, 1=Output, 2=Append
            break;
        }
        case STMT_CLOSE: {
            CloseStatement* s = (CloseStatement*)stmt;
            if (s->file_number) {
                compile_expression(s->file_number); // push file_num
            } else {
                emit_constant(Variant(0)); // 0 = close all
            }
            emit_byte(OP_CLOSE_FILE);
            break;
        }
        case STMT_INPUT: {
            InputStatement* s = (InputStatement*)stmt;
            if (s->file_number && s->is_line_input) {
                // Line Input #n, var
                // Emit: push file_num, OP_LINE_INPUT (pushes line), then store to var
                compile_expression(s->file_number);
                emit_byte(OP_LINE_INPUT);
                if (s->variables.size() > 0 && s->variables[0]->type == ExpressionNode::VARIABLE) {
                    String vname = ((VariableNode*)s->variables[0])->name;
                    int slot = get_or_add_local(vname, VT_UNKNOWN);
                    if (slot >= 0) {
                        emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                    } else {
                        int idx = current_chunk->add_constant(vname);
                        emit_byte(OP_SET_GLOBAL);
                        emit_const_index(idx);
                    }
                } else {
                    emit_byte(OP_POP); // discard result if target unknown
                }
            } else if (s->file_number) {
                // Input #n, var1, var2...
                for (int i = 0; i < s->variables.size(); i++) {
                    compile_expression(s->file_number);
                    emit_byte(OP_INPUT_FILE);
                    if (s->variables[i]->type == ExpressionNode::VARIABLE) {
                        String vname = ((VariableNode*)s->variables[i])->name;
                        int slot = get_or_add_local(vname, VT_UNKNOWN);
                        if (slot >= 0) {
                            emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                        } else {
                            int idx = current_chunk->add_constant(vname);
                            emit_byte(OP_SET_GLOBAL);
                            emit_const_index(idx);
                        }
                    } else {
                        emit_byte(OP_POP);
                    }
                }
            }
            break;
        }
        case STMT_WRITE: {
            // Write #n, val1, val2...
            WriteStatement* ws = (WriteStatement*)stmt;
            if (ws->file_number) {
                compile_expression(ws->file_number);
                for (int i = 0; i < ws->expressions.size(); i++) {
                    compile_expression(ws->expressions[i]);
                }
                emit_byte(OP_WRITE_FILE);
                emit_byte((uint8_t)ws->expressions.size());
            }
            break;
        }
        case STMT_GOSUB: {
            // GoSub label — like GoTo but pushes return address
            GoSubStatement* s = (GoSubStatement*)stmt;
            String key = s->label_name.to_lower();
            if (label_positions.has(key)) {
                // Backward jump — label already seen
                // Emit OP_GOSUB with absolute target
                emit_byte(OP_GOSUB);
                int target = label_positions[key];
                emit_byte((uint8_t)((target >> 8) & 0xFF));
                emit_byte((uint8_t)(target & 0xFF));
            } else {
                // Forward jump — emit placeholder, patch when label found
                int jump_addr = emit_jump(OP_GOSUB);
                if (!goto_forward_jumps.has(key)) {
                    goto_forward_jumps[key] = Vector<int>();
                }
                goto_forward_jumps[key].push_back(jump_addr);
            }
            break;
        }
        case STMT_RETURN_GOSUB: {
            // Explicit Return from GoSub
            emit_byte(OP_RETURN_GOSUB);
            break;
        }
        case STMT_IMPLEMENTS: {
            // Implements — stored for runtime verification, no code emitted
            // Interface checking is done at class instantiation time
            break;
        }
        case STMT_RAISE_EVENT: {
            // RaiseEvent EventName(arg1, arg2, ...)
            // Compile arguments onto stack, then emit OP_RAISE_EVENT
            RaiseEventStatement* s = (RaiseEventStatement*)stmt;
            // Push arguments in order
            for (int i = 0; i < s->arguments.size(); i++) {
                compile_expression(s->arguments[i]);
                if (!compile_ok) break;
            }
            int name_idx = current_chunk->add_constant(Variant(s->expression_name));
            emit_byte(OP_RAISE_EVENT);
            emit_const_index(name_idx);
            emit_byte((uint8_t)(s->arguments.size() & 0xFF));
            break;
        }
        // === MULTITASKING STATEMENTS ===
        // In bytecode mode, Task Run bodies execute serially on the main
        // thread (same strategy used for Parallel For).  True threaded
        // execution remains in the AST interpreter path.
        case STMT_TASK_RUN: {
            // Compile Task.Run body with OP_TASK_RUN_BEGIN / END.
            // The VM will submit the body to WorkerThreadPool.
            TaskRunStatement* s = (TaskRunStatement*)stmt;

            // Emit OP_TASK_RUN_BEGIN [name_const] [bg_flag] [body_len_hi] [body_len_lo]
            int name_idx = current_chunk->add_constant(Variant(s->task_name));
            emit_byte(OP_TASK_RUN_BEGIN);
            emit_const_index(name_idx);
            emit_byte(s->is_background ? 1 : 0);
            int body_len_offset = current_chunk->code.size();
            emit_byte(0xFF);
            emit_byte(0xFF);

            int body_start = current_chunk->code.size();
            for (int i = 0; i < s->task_body.size(); i++) {
                compile_statement(s->task_body[i]);
                if (!compile_ok) break;
            }
            emit_byte(OP_TASK_RUN_END);
            int body_end = current_chunk->code.size();
            int body_len = body_end - body_start;
            current_chunk->code.write[body_len_offset]     = (uint8_t)((body_len >> 8) & 0xFF);
            current_chunk->code.write[body_len_offset + 1] = (uint8_t)(body_len & 0xFF);
            break;
        }
        case STMT_TASK_WAIT: {
            // Emit OP_TASK_WAIT [wait_all_flag]
            TaskWaitStatement* s = (TaskWaitStatement*)stmt;
            emit_byte(OP_TASK_WAIT);
            emit_byte(s->wait_all ? 1 : 0);
            break;
        }
        case STMT_PARALLEL_SECTION: {
            // Compile body serially, like Parallel For.
            ParallelSectionStatement* s = (ParallelSectionStatement*)stmt;
            for (int i = 0; i < s->section_body.size(); i++) {
                compile_statement(s->section_body[i]);
                if (!compile_ok) break;
            }
            break;
        }
        case STMT_ASYNC_FUNCTION: {
            // Async functions compile the body inline, same as regular functions.
            // The "async" marker is a hint for future coroutine support.
            AsyncFunctionStatement* s = (AsyncFunctionStatement*)stmt;
            for (int i = 0; i < s->body.size(); i++) {
                compile_statement(s->body[i]);
                if (!compile_ok) break;
            }
            break;
        }
        case STMT_AWAIT: {
            // Await statement (v4.2.0): compile the expression (signal/coroutine),
            // push it onto stack, then emit OP_AWAIT for VM coroutine dispatch.
            AwaitStatement* s = (AwaitStatement*)stmt;
            if (s->expression) {
                compile_expression(s->expression);
            }
            emit_byte(OP_AWAIT);
            break;
        }
        case STMT_LOCK: {
            emit_byte(OP_LOCK);
            break;
        }
        case STMT_UNLOCK: {
            emit_byte(OP_UNLOCK);
            break;
        }
        case STMT_DATA: {
            // No-op at runtime — Data values are collected at init time by scan_data_sections
            break;
        }
        case STMT_LOAD_DATA: {
            // LoadData / DataFromString — push string expression, emit opcode
            LoadDataStatement* s = (LoadDataStatement*)stmt;
            compile_expression(s->path_expression);
            emit_byte(s->is_from_string ? OP_DATA_FROM_STRING : OP_LOAD_DATA);
            break;
        }
        case STMT_CLEAR_DATA: {
            emit_byte(OP_CLEAR_DATA);
            break;
        }
        case STMT_DO_EVENTS: {
            int idx = current_chunk->add_constant(String("DoEvents"));
            emit_byte(OP_CALL);
            emit_const_index(idx);
            emit_byte((uint8_t)0);
            break;
        }
        default:
             UtilityFunctions::print("Compiler: Unsupported statement type ", stmt->type);
             compile_ok = false;
             break;
    }
}

void VisualGasicCompiler::compile_expression(ExpressionNode* expr) {
    switch (expr->type) {
        case ExpressionNode::LITERAL: {
            LiteralNode* l = (LiteralNode*)expr;
            emit_constant(l->value);
            break;
        }
        case ExpressionNode::UNARY_OP: {
            UnaryOpNode* u = (UnaryOpNode*)expr;
            if (u->op.nocasecmp_to("AddressOf") == 0) {
                // AddressOf SubName — push method name string, then OP_ADDRESS_OF
                if (u->operand && u->operand->type == ExpressionNode::VARIABLE) {
                    String method_name = ((VariableNode*)u->operand)->name;
                    emit_constant(method_name);
                    emit_byte(OP_ADDRESS_OF);
                } else {
                    UtilityFunctions::print("Compiler: AddressOf requires a method name");
                    compile_ok = false;
                }
                break;
            }
            if (is_constant_expr(u)) {
                emit_constant(eval_constant_expr(u));
                break;
            }
            compile_expression(u->operand);
            if (u->op.nocasecmp_to("Not") == 0) {
                emit_byte(OP_NOT);
            } else if (u->op == "-") {
                emit_byte(OP_NEGATE);
            } else if (u->op == "+") {
                // Unary plus is a no-op.
            } else {
                UtilityFunctions::print("Compiler: Unsupported unary op ", u->op);
                compile_ok = false;
            }
            break;
        }
        case ExpressionNode::NEW: {
            NewNode* n = (NewNode*)expr;
            if (n->class_name.nocasecmp_to("Dictionary") == 0 && n->args.size() == 0) {
                emit_byte(OP_NEW_DICT);
                break;
            }
            // General New: compile args, then OP_NEW_OBJECT with class name + arg count
            for (int i = 0; i < n->args.size(); i++) {
                compile_expression(n->args[i]);
            }
            int name_idx = current_chunk->add_constant(String(n->class_name));
            emit_byte(OP_NEW_OBJECT);
            emit_const_index(name_idx);
            emit_byte((uint8_t)n->args.size());
            break;
        }
        case ExpressionNode::ME: {
            // "Me" keyword - compile as OP_GET_GLOBAL with "Me" constant
            // Runtime will resolve this to owner
            int idx = current_chunk->add_constant(String("Me"));
            emit_byte(OP_GET_GLOBAL);
            emit_const_index(idx);
            break;
        }
        case ExpressionNode::SUPER: {
            // "Super" keyword — compile same pattern as "Me"
            // Runtime OP_GET_GLOBAL resolves "Super" to owner (parent class dispatch handled by method call)
            int idx = current_chunk->add_constant(String("Super"));
            emit_byte(OP_GET_GLOBAL);
            emit_const_index(idx);
            break;
        }
        case ExpressionNode::VARIABLE: {
            VariableNode* v = (VariableNode*)expr;
            // Check procedure-scoped Const map first — inline the value directly.
            String lower_name = v->name.to_lower();
            if (local_const_map.has(lower_name)) {
                emit_constant(local_const_map[lower_name]);
                break;
            }
            int slot = get_or_add_local(v->name, VT_UNKNOWN);
            if (slot >= 0) {
                emit_bytes(OP_GET_LOCAL, (uint8_t)slot);
            } else {
                int idx = current_chunk->add_constant(v->name);
                emit_byte(OP_GET_GLOBAL);
                emit_const_index(idx);
            }
            break;
        }
        case ExpressionNode::BINARY_OP: {
            BinaryOpNode* b = (BinaryOpNode*)expr;
            if (is_constant_expr(b)) {
                emit_constant(eval_constant_expr(b));
                break;
            }

            // Special handling: "Is" operator with Godot class name → type-check
            // e.g. "ev Is InputEventKey" → OP_IS_CLASS ; "ev IsNot InputEventKey" → OP_IS_CLASS + OP_NOT
            if ((b->op.nocasecmp_to("Is") == 0 || b->op.nocasecmp_to("IsNot") == 0) && b->right &&
                b->right->type == ExpressionNode::VARIABLE) {
                String class_name = ((VariableNode*)b->right)->name;
                if (ClassDB::class_exists(class_name)) {
                    compile_expression(b->left);             // push object
                    emit_constant(class_name);               // push class name string
                    emit_byte(OP_IS_CLASS);                  // type-check
                    if (b->op.nocasecmp_to("IsNot") == 0)
                        emit_byte(OP_NOT);                   // negate for IsNot
                    break;
                }
            }

            // Short-circuit AndAlso / OrElse
            // AndAlso: evaluate left; if false, skip right and push False
            if (b->op.nocasecmp_to("AndAlso") == 0) {
                compile_expression(b->left);
                int short_circuit = emit_jump(OP_JUMP_IF_FALSE); // pops left; jumps if false
                compile_expression(b->right);                    // right result stays on stack
                int skip_false = emit_jump(OP_JUMP);
                patch_jump(short_circuit);
                emit_byte(OP_FALSE);
                patch_jump(skip_false);
                break;
            }
            // OrElse: evaluate left; if true, skip right and push True
            if (b->op.nocasecmp_to("OrElse") == 0) {
                compile_expression(b->left);
                int short_circuit = emit_jump(OP_JUMP_IF_TRUE);  // pops left; jumps if true
                compile_expression(b->right);                    // right result stays on stack
                int skip_true = emit_jump(OP_JUMP);
                patch_jump(short_circuit);
                emit_byte(OP_TRUE);
                patch_jump(skip_true);
                break;
            }

            if ((b->left->type == ExpressionNode::VARIABLE || b->left->type == ExpressionNode::LITERAL) &&
                (b->right->type == ExpressionNode::VARIABLE || b->right->type == ExpressionNode::LITERAL)) {
                String key = b->op + ":";
                if (b->left->type == ExpressionNode::VARIABLE) key += ((VariableNode*)b->left)->name;
                else key += ((LiteralNode*)b->left)->value.stringify();
                key += ":";
                if (b->right->type == ExpressionNode::VARIABLE) key += ((VariableNode*)b->right)->name;
                else key += ((LiteralNode*)b->right)->value.stringify();

                if (expr_cache.has(key)) {
                    emit_bytes(OP_GET_LOCAL, (uint8_t)expr_cache[key]);
                    break;
                }

                int cse_slot = get_or_add_local(String("__cse_") + String::num_int64(temp_local_id++), VT_UNKNOWN);
                compile_expression(b->left);
                compile_expression(b->right);

                ValueType lt = infer_type(b->left);
                ValueType rt = infer_type(b->right);
                if (b->op == "+") {
                    if (lt == VT_INT && rt == VT_INT) {
                        // NOTE: only the RIGHT operand may use the _CONST fast path.
                        // OP_ADD_I64_CONST's VM handler assumes the literal was pushed
                        // LAST (i.e. on the right) and unconditionally discards the top
                        // of stack as "the literal" before adding the embedded constant
                        // to what's left underneath. A left-hand literal (e.g. CONST + VAR)
                        // must NOT take this path -- it silently computed CONST+CONST
                        // instead of CONST+VAR. See /memories/repo/build_and_test.md.
                        if (b->right->type == ExpressionNode::LITERAL && ((LiteralNode*)b->right)->value.get_type() == Variant::INT) {
                            int idx = current_chunk->add_constant(((LiteralNode*)b->right)->value);
                            emit_byte(OP_ADD_I64_CONST);
                            emit_const_index(idx);
                        } else {
                            emit_byte(OP_ADD_I64);
                        }
                    }
                    else if (lt == VT_FLOAT || rt == VT_FLOAT) emit_byte(OP_ADD_F64);
                    else emit_byte(OP_ADD);
                }
                else if (b->op == "-") {
                    if (lt == VT_INT && rt == VT_INT) {
                        if (b->right->type == ExpressionNode::LITERAL && ((LiteralNode*)b->right)->value.get_type() == Variant::INT) {
                            int idx = current_chunk->add_constant(((LiteralNode*)b->right)->value);
                            emit_byte(OP_SUB_I64_CONST);
                            emit_const_index(idx);
                        } else {
                            emit_byte(OP_SUB_I64);
                        }
                    }
                    else if (lt == VT_FLOAT || rt == VT_FLOAT) emit_byte(OP_SUB_F64);
                    else emit_byte(OP_SUBTRACT);
                }
                else if (b->op == "*") {
                    if (lt == VT_INT && rt == VT_INT) {
                        // Same left-literal landmine as "+" above -- only the RIGHT
                        // operand may use the _CONST fast path (OP_MUL_I64_CONST's VM
                        // handler assumes the literal was pushed last).
                        if (b->right->type == ExpressionNode::LITERAL && ((LiteralNode*)b->right)->value.get_type() == Variant::INT) {
                            int idx = current_chunk->add_constant(((LiteralNode*)b->right)->value);
                            emit_byte(OP_MUL_I64_CONST);
                            emit_const_index(idx);
                        } else {
                            emit_byte(OP_MUL_I64);
                        }
                    }
                    else if (lt == VT_FLOAT || rt == VT_FLOAT) emit_byte(OP_MUL_F64);
                    else emit_byte(OP_MULTIPLY);
                }
                else if (b->op == "/") {
                    if (lt == VT_FLOAT || rt == VT_FLOAT) emit_byte(OP_DIV_F64);
                    else emit_byte(OP_DIVIDE);
                }
                else if (b->op == "&") emit_byte(OP_CONCAT);
                else if (b->op == "=") {
                    if (lt == VT_INT && rt == VT_INT) emit_byte(OP_EQUAL_I64);
                    else emit_byte(OP_EQUAL);
                }
                else if (b->op == "<") emit_byte(OP_LESS);
                else if (b->op == ">") emit_byte(OP_GREATER);
                else if (b->op == "<=") {
                    if (lt == VT_INT && rt == VT_INT) emit_byte(OP_LESS_EQUAL_I64);
                    else emit_byte(OP_LESS_EQUAL);
                }
                else if (b->op == ">=") emit_byte(OP_GREATER_EQUAL);
                else if (b->op == "<>") {
                    if (lt == VT_INT && rt == VT_INT) emit_byte(OP_NOT_EQUAL_I64);
                    else emit_byte(OP_NOT_EQUAL);
                }
                else if (b->op.nocasecmp_to("And") == 0) emit_byte(OP_AND);
                else if (b->op.nocasecmp_to("Or") == 0) emit_byte(OP_OR);
                else if (b->op.nocasecmp_to("Xor") == 0) emit_byte(OP_XOR);
                else if (b->op.nocasecmp_to("Is") == 0) emit_byte(OP_EQUAL); // Is compares object references
                else if (b->op.nocasecmp_to("IsNot") == 0) emit_byte(OP_NOT_EQUAL); // IsNot negates object reference equality
                else if (b->op.nocasecmp_to("Mod") == 0 || b->op == "%") emit_byte(OP_MOD);
                else if (b->op.nocasecmp_to("Like") == 0) emit_byte(OP_LIKE);
                else if (b->op == "\\") emit_byte(OP_INT_DIVIDE); // Integer division
                else if (b->op == "^" || b->op == "**") emit_byte(OP_POWER); // Exponentiation
                else if (b->op == "<<") emit_byte(OP_SHL); // Left bit-shift
                else if (b->op == ">>") emit_byte(OP_SHR); // Right bit-shift
                else {
                    UtilityFunctions::print("Compiler: Unsupported binary op ", b->op);
                    compile_ok = false;
                }

                if (cse_slot >= 0) {
                    emit_bytes(OP_SET_LOCAL, (uint8_t)cse_slot);
                    emit_bytes(OP_GET_LOCAL, (uint8_t)cse_slot);
                    expr_cache[key] = cse_slot;
                }
                break;
            }

            compile_expression(b->left);
            compile_expression(b->right);
            
            ValueType lt = infer_type(b->left);
            ValueType rt = infer_type(b->right);
            if (b->op == "+") {
                if (lt == VT_INT && rt == VT_INT) {
                    // See the CSE-path comment above -- only the RIGHT operand may
                    // use the _CONST fast path; a left-hand literal (CONST + VAR)
                    // must fall through to the generic two-operand opcode.
                    if (b->right->type == ExpressionNode::LITERAL && ((LiteralNode*)b->right)->value.get_type() == Variant::INT) {
                        int idx = current_chunk->add_constant(((LiteralNode*)b->right)->value);
                        emit_byte(OP_ADD_I64_CONST);
                        emit_const_index(idx);
                    } else {
                        emit_byte(OP_ADD_I64);
                    }
                }
                else if (lt == VT_FLOAT || rt == VT_FLOAT) emit_byte(OP_ADD_F64);
                else emit_byte(OP_ADD);
            }
            else if (b->op == "-") {
                if (lt == VT_INT && rt == VT_INT) {
                    if (b->right->type == ExpressionNode::LITERAL && ((LiteralNode*)b->right)->value.get_type() == Variant::INT) {
                        int idx = current_chunk->add_constant(((LiteralNode*)b->right)->value);
                        emit_byte(OP_SUB_I64_CONST);
                        emit_const_index(idx);
                    } else {
                        emit_byte(OP_SUB_I64);
                    }
                }
                else if (lt == VT_FLOAT || rt == VT_FLOAT) emit_byte(OP_SUB_F64);
                else emit_byte(OP_SUBTRACT);
            }
            else if (b->op == "*") {
                if (lt == VT_INT && rt == VT_INT) {
                    // See the CSE-path comment above -- same left-literal landmine.
                    if (b->right->type == ExpressionNode::LITERAL && ((LiteralNode*)b->right)->value.get_type() == Variant::INT) {
                        int idx = current_chunk->add_constant(((LiteralNode*)b->right)->value);
                        emit_byte(OP_MUL_I64_CONST);
                        emit_const_index(idx);
                    } else {
                        emit_byte(OP_MUL_I64);
                    }
                }
                else if (lt == VT_FLOAT || rt == VT_FLOAT) emit_byte(OP_MUL_F64);
                else emit_byte(OP_MULTIPLY);
            }
            else if (b->op == "/") {
                if (lt == VT_FLOAT || rt == VT_FLOAT) emit_byte(OP_DIV_F64);
                else emit_byte(OP_DIVIDE);
            }
            else if (b->op == "&") emit_byte(OP_CONCAT);
            else if (b->op == "=") {
                if (lt == VT_INT && rt == VT_INT) emit_byte(OP_EQUAL_I64);
                else emit_byte(OP_EQUAL);
            }
            else if (b->op == "<") emit_byte(OP_LESS);
            else if (b->op == ">") emit_byte(OP_GREATER);
            else if (b->op == "<=") {
                if (lt == VT_INT && rt == VT_INT) emit_byte(OP_LESS_EQUAL_I64);
                else emit_byte(OP_LESS_EQUAL);
            }
            else if (b->op == ">=") emit_byte(OP_GREATER_EQUAL);
            else if (b->op == "<>") {
                if (lt == VT_INT && rt == VT_INT) emit_byte(OP_NOT_EQUAL_I64);
                else emit_byte(OP_NOT_EQUAL);
            }
            else if (b->op.nocasecmp_to("And") == 0) emit_byte(OP_AND);
            else if (b->op.nocasecmp_to("Or") == 0) emit_byte(OP_OR);
            else if (b->op.nocasecmp_to("Xor") == 0) emit_byte(OP_XOR);
            else if (b->op.nocasecmp_to("Is") == 0) emit_byte(OP_EQUAL); // Is compares object references
            else if (b->op.nocasecmp_to("IsNot") == 0) emit_byte(OP_NOT_EQUAL); // IsNot negates object reference equality
            else if (b->op.nocasecmp_to("Mod") == 0 || b->op == "%") emit_byte(OP_MOD);
            else if (b->op.nocasecmp_to("Like") == 0) emit_byte(OP_LIKE);
            else if (b->op == "\\") emit_byte(OP_INT_DIVIDE); // Integer division
            else if (b->op == "^" || b->op == "**") emit_byte(OP_POWER); // Exponentiation
            else if (b->op == "<<") emit_byte(OP_SHL); // Left bit-shift
            else if (b->op == ">>") emit_byte(OP_SHR); // Right bit-shift
            else {
                UtilityFunctions::print("Compiler: Unsupported binary op ", b->op);
                compile_ok = false;
            }
            break;
        }
        case ExpressionNode::ARRAY_ACCESS: {
            ArrayAccessNode* aa = (ArrayAccessNode*)expr;
            // ── obj.method(args) pattern ──
            // The parser chains  obj.method(args)  as:
            //   ArrayAccessNode { base=MemberAccessNode{obj, method}, indices=[args] }
            // We must emit OP_METHOD_CALL instead of OP_GET_MEMBER + OP_GET_ARRAY
            // because "method" is a callable, not an indexable property.
            if (aa->base && aa->base->type == ExpressionNode::MEMBER_ACCESS) {
                MemberAccessNode* ma = (MemberAccessNode*)aa->base;
                // ClassName.new(args) — emit OP_NEW_OBJECT
                if (ma->base_object && ma->base_object->type == ExpressionNode::VARIABLE &&
                    ma->member_name.nocasecmp_to("new") == 0) {
                    String var_name = ((VariableNode*)ma->base_object)->name;
                    if (ClassDB::class_exists(var_name)) {
                        for (int i = 0; i < aa->indices.size(); i++) {
                            compile_expression(aa->indices[i]);
                        }
                        int name_idx = current_chunk->add_constant(var_name);
                        emit_byte(OP_NEW_OBJECT);
                        emit_const_index(name_idx);
                        emit_byte((uint8_t)aa->indices.size());
                        break;
                    }
                }
                // Pass 2: Camera./Sound./Speaker. namespace → flat builtin OP_CALL
                {
                    String ns = detect_namespace_call(ma->base_object);
                    if (!ns.is_empty()) {
                        for (int i = 0; i < aa->indices.size(); i++) {
                            compile_expression(aa->indices[i]);
                        }
                        String fn = ns + "_" + ma->member_name.to_lower();
                        int fnidx = current_chunk->add_constant(fn);
                        emit_byte(OP_CALL);
                        emit_const_index(fnidx);
                        emit_byte((uint8_t)aa->indices.size());
                        break;
                    }
                }
                // General obj.method(args) — emit OP_METHOD_CALL
                compile_expression(ma->base_object);
                for (int i = 0; i < aa->indices.size(); i++) {
                    compile_expression(aa->indices[i]);
                }
                int midx = current_chunk->add_constant(ma->member_name);
                emit_byte(OP_METHOD_CALL);
                emit_const_index(midx);
                emit_byte((uint8_t)aa->indices.size());
                break;
            }
            // ── Function call pattern ──
            // parse_assignment_or_call creates ArrayAccessNode for func(args)
            // when the base is a VariableNode that is NOT a known array/dict.
            // Emit OP_CALL instead of OP_GET_ARRAY.
            if (aa->base && aa->base->type == ExpressionNode::VARIABLE) {
                String var_name = ((VariableNode*)aa->base)->name;
                bool is_array = is_fast_array_var(var_name) || array_vars.has(var_name.to_lower());
                bool is_dict = is_dictionary_var(var_name);
                bool is_local = local_slots.has(var_name.to_lower());
                bool is_param = param_vars.has(var_name.to_lower());
                // A fast-call Function's return variable occupies a local slot
                // named after the function itself.  `FuncName(args)` appearing
                // inside FuncName is therefore a RECURSIVE SELF-CALL, not an
                // attempt to index the (scalar) return variable — clear the
                // local/param flags so it routes to the OP_CALL path below
                // instead of OP_GET_ARRAY (which would index a scalar → null).
                if (current_sub && current_chunk && current_chunk->return_slot >= 0 &&
                    var_name.nocasecmp_to(current_sub->name) == 0) {
                    is_local = false;
                    is_param = false;
                }
                // v4.4.0: a module-level MemoryBuffer var (Set X = New MemoryBuffer(...)
                // in a different Sub than the one being compiled) never gets a local
                // slot (it's forced non-local as a Public/Global), so `is_local` alone
                // would misclassify `X(addr)` as a function call. Treat known buffer
                // vars the same as arrays/dicts here.
                bool is_buffer = is_buffer_var(var_name);
                if (!is_array && !is_dict && !is_local && !is_param && !is_buffer) {
                    String vn_lower = var_name.to_lower();

                    // ── Phase 5: Godot Variant type constructors ──
                    // Vector2(x,y), Color(r,g,b,a), Rect2(x,y,w,h) etc. should
                    // use OP_NEW_OBJECT, not OP_CALL (OP_CALL returns NIL for
                    // these since they are not VG subs or builtins).
                    static const char* _godot_type_ctors[] = {
                        "vector2", "vector2i", "vector3", "vector3i",
                        "vector4", "vector4i", "rect2", "rect2i",
                        "color", "transform2d", "transform3d",
                        "basis", "quaternion", "plane", "aabb",
                        nullptr
                    };
                    for (int _gi = 0; _godot_type_ctors[_gi]; ++_gi) {
                        if (vn_lower == _godot_type_ctors[_gi]) {
                            if (vn_lower == "color" && aa->indices.size() >= 3) {
                                bool all_const = true;
                                for (int i = 0; i < aa->indices.size(); i++) {
                                    if (!is_constant_expr(aa->indices[i])) {
                                        all_const = false;
                                        break;
                                    }
                                }
                                if (all_const) {
                                    emit_constant(eval_constant_expr(aa));
                                    goto _func_call_emitted;
                                }
                            }
                            for (int i = 0; i < aa->indices.size(); i++) {
                                compile_expression(aa->indices[i]);
                            }
                            int name_idx = current_chunk->add_constant(var_name);
                            emit_byte(OP_NEW_OBJECT);
                            emit_const_index(name_idx);
                            emit_byte((uint8_t)aa->indices.size());
                            goto _func_call_emitted;
                        }
                    }

                    // ── Phase 1: Trig/math dedicated opcodes ──
                    // Avoids OP_CALL string dispatch overhead for hot math ops.
                    {
                        struct { const char* name; OpCode op; int nargs; } _trig_ops[] = {
                            {"sin",   OP_SIN,    1},
                            {"cos",   OP_COS,    1},
                            {"sqr",   OP_SQRT,   1},  // VB: Sqr() = sqrt
                            {"sqrt",  OP_SQRT,   1},
                            {"tan",   OP_TAN,    1},
                            {"atan2", OP_ATAN2,  2},
                            {"floor", OP_FLOOR_F,1},
                            {"ceil",  OP_CEIL_F, 1},
                            {"ceiling",OP_CEIL_F,1}, // VB alias
                            {"exp",   OP_EXP,    1},
                            {"log",   OP_LOG,    1},
                            {nullptr, OP_COUNT_, 0},
                        };
                        for (int _ti = 0; _trig_ops[_ti].name; ++_ti) {
                            if (vn_lower == _trig_ops[_ti].name &&
                                aa->indices.size() == _trig_ops[_ti].nargs) {
                                // push args then emit dedicated opcode
                                for (int i = 0; i < aa->indices.size(); i++) {
                                    compile_expression(aa->indices[i]);
                                }
                                emit_byte((uint8_t)_trig_ops[_ti].op);
                                goto _func_call_emitted;
                            }
                        }
                    }

                    // ── Dedicated draw opcodes (DrawRect/DrawLine/Circle/Texture) ──
                    {
                        int draw_op = 0;
                        if (vn_lower == "drawrect") draw_op = OP_DRAW_RECT;
                        else if (vn_lower == "drawline") draw_op = OP_DRAW_LINE;
                        if (draw_op != 0) {
                            bool is_user_sub = false;
                            if (current_module) {
                                for (int si = 0; si < current_module->subs.size(); si++) {
                                    if (current_module->subs[si]->name.nocasecmp_to(var_name) == 0) {
                                        is_user_sub = true;
                                        break;
                                    }
                                }
                            }
                            if (!is_user_sub) {
                                if (draw_op == OP_DRAW_RECT && try_emit_draw_rect_f64(aa->indices)) {
                                    goto _func_call_emitted;
                                }
                                if (draw_op == OP_DRAW_LINE && try_emit_draw_line_f64(aa->indices)) {
                                    goto _func_call_emitted;
                                }
                                for (int i = 0; i < aa->indices.size(); i++) {
                                    if (i == 4 && _draw_invariant_color_slot >= 0) {
                                        emit_bytes(OP_GET_LOCAL, (uint8_t)_draw_invariant_color_slot);
                                    } else {
                                        compile_expression(aa->indices[i]);
                                    }
                                }
                                emit_byte((uint8_t)draw_op);
                                emit_byte((uint8_t)aa->indices.size());
                                goto _func_call_emitted;
                            }
                        }
                        if (vn_lower == "drawcircle") {
                            bool is_user_sub = find_sub_by_name(var_name) != nullptr;
                            if (!is_user_sub && try_emit_draw_circle_f64(aa->indices)) {
                                goto _func_call_emitted;
                            }
                        }
                        if (vn_lower == "drawtexturerect") {
                            bool is_user_sub = find_sub_by_name(var_name) != nullptr;
                            if (!is_user_sub && try_emit_draw_texture_rect_f64(aa->indices)) {
                                goto _func_call_emitted;
                            }
                        }
                    }

                    // ── Inline GridX/GridY axis helpers ──
                    if (var_name.nocasecmp_to("GridX") == 0 && try_emit_grid_axis_inline(var_name, aa->indices, true)) {
                        goto _func_call_emitted;
                    }
                    if (var_name.nocasecmp_to("GridY") == 0 && try_emit_grid_axis_inline(var_name, aa->indices, false)) {
                        goto _func_call_emitted;
                    }

                    // ── Generic function call ──
                    {
                        for (int i = 0; i < aa->indices.size(); i++) {
                            compile_expression(aa->indices[i]);
                        }
                        int idx = current_chunk->add_constant(var_name);
                        emit_byte(OP_CALL);
                        emit_const_index(idx);
                        emit_byte((uint8_t)aa->indices.size());
                    }
                    _func_call_emitted:
                    break;
                }
            }
            // ── True array/dict access ──
            if (aa->indices.size() != 1) {
                compile_ok = false;
                break;
            }
            // ── M5: MemoryBuffer READ fast path ──
            // buf(offset) → OP_BUF_READ8 [slot] (no stack base push)
            if (aa->base && aa->base->type == ExpressionNode::VARIABLE &&
                is_buffer_var(((VariableNode*)aa->base)->name)) {
                const String &buf_name = ((VariableNode*)aa->base)->name;
                int bslot = get_or_add_local(buf_name, VT_UNKNOWN);
                if (bslot >= 0) {
                    compile_expression(aa->indices[0]);  // push offset only
                    emit_bytes(OP_BUF_READ8, (uint8_t)bslot);
                    break;
                }
                // v6.2: Global MemoryBuffer fast path — buf(offset) on a
                // Public/global buffer var (stays a real VGMemoryBuffer
                // Object) fuses the global lookup + PeekByte into one opcode
                // instead of the generic OP_GET_GLOBAL + OP_GET_ARRAY pair.
                compile_expression(aa->indices[0]);  // push offset only
                int name_idx = current_chunk->add_constant(buf_name);
                emit_byte(OP_GET_GLOBAL_BUF8);
                emit_const_index(name_idx);
                break;
            }
            // ── Sole-owner VGDict GET fast path ──
            if (aa->base && aa->base->type == ExpressionNode::VARIABLE &&
                is_sole_owner_dict_var(((VariableNode*)aa->base)->name)) {
                int slot = get_or_add_local(((VariableNode*)aa->base)->name, VT_UNKNOWN);
                if (slot >= 0 && slot < 16) {
                    compile_expression(aa->indices[0]);  // push key only
                    emit_bytes(OP_GET_VGDICT_LOCAL, (uint8_t)slot);
                    break;
                }
            }
            compile_expression(aa->base);
            compile_expression(aa->indices[0]);
            bool unchecked = false;
            if (!loop_vars.is_empty() && aa->base->type == ExpressionNode::VARIABLE && aa->indices[0]->type == ExpressionNode::VARIABLE) {
                String loop_var = loop_vars[loop_vars.size() - 1].to_lower();
                String idx_var = ((VariableNode*)aa->indices[0])->name.to_lower();
                String arr_key = ((VariableNode*)aa->base)->name.to_lower();
                if (idx_var == loop_var && array_bound_vars.has(arr_key) &&
                    array_bound_vars[arr_key] == loop_bound_vars[loop_bound_vars.size() - 1].to_lower()) {
                    unchecked = true;
                }
            }
            bool fast_array = (aa->base && aa->base->type == ExpressionNode::VARIABLE) &&
                is_fast_array_var(((VariableNode*)aa->base)->name);
            bool fast_dict = (aa->base && aa->base->type == ExpressionNode::VARIABLE) &&
                is_dictionary_var(((VariableNode*)aa->base)->name);
            bool trusted_dict = fast_dict && aa->base && aa->base->type == ExpressionNode::VARIABLE &&
                is_trusted_dictionary_var(((VariableNode*)aa->base)->name);
            uint8_t opcode = OP_GET_ARRAY;
            if (trusted_dict) {
                opcode = OP_GET_DICT_TRUSTED;
            } else if (fast_dict) {
                opcode = OP_GET_DICT_FAST;
            } else {
                opcode = unchecked
                    ? (fast_array ? OP_GET_ARRAY_FAST_UNCHECKED : OP_GET_ARRAY_UNCHECKED)
                    : (fast_array ? OP_GET_ARRAY_FAST : OP_GET_ARRAY);
            }
            emit_byte(opcode);
            emit_byte(1);
            break;
        }
        case ExpressionNode::MEMBER_ACCESS: {
            MemberAccessNode* ma = (MemberAccessNode*)expr;
            bool resolved = false;
            // Check for Color.White, Color.Red, etc. — named color constants
            if (ma->base_object && ma->base_object->type == ExpressionNode::VARIABLE) {
                String base_name = ((VariableNode*)ma->base_object)->name;
                if (base_name.nocasecmp_to("Color") == 0 && !ma->member_name.is_empty()) {
                    Color c = Color::named(ma->member_name);
                    int cidx = current_chunk->add_constant(c);
                    emit_byte(OP_CONSTANT);
                    emit_const_index(cidx);
                    resolved = true;
                }
                // VG Enum dot access: EnumName.MemberName → compile-time constant
                if (!resolved && current_module) {
                    for (int ei = 0; ei < current_module->enums.size(); ei++) {
                        EnumDefinition* ed = current_module->enums[ei];
                        if (ed->name.nocasecmp_to(base_name) == 0) {
                            for (int vi = 0; vi < ed->values.size(); vi++) {
                                if (ed->values[vi].name.nocasecmp_to(ma->member_name) == 0) {
                                    int cidx = current_chunk->add_constant(Variant(ed->values[vi].value));
                                    emit_byte(OP_CONSTANT);
                                    emit_const_index(cidx);
                                    resolved = true;
                                    break;
                                }
                            }
                            break; // Enum found but member not found — fall through
                        }
                    }
                }
            }
            // Check if this is ClassName.CONSTANT (Godot class enum constant)
            if (!resolved && ma->base_object && ma->base_object->type == ExpressionNode::VARIABLE) {
                String class_name = ((VariableNode*)ma->base_object)->name;
                if (ClassDB::class_exists(class_name)) {
                    // Try member name as-is first, then UPPER_CASE.
                    // The tokenizer normalises keywords like READ → "Read",
                    // but Godot enum constants are ALL_CAPS ("READ").
                    String mname = ma->member_name;
                    if (!ClassDB::class_has_integer_constant(class_name, mname)) {
                        mname = mname.to_upper();
                    }
                    if (ClassDB::class_has_integer_constant(class_name, mname)) {
                        int64_t val = ClassDB::class_get_integer_constant(class_name, mname);
                        int cidx = current_chunk->add_constant(Variant((int)val));
                        emit_byte(OP_CONSTANT);
                        emit_const_index(cidx);
                        resolved = true;
                    }
                }
            }
            if (!resolved) {
                // Pass 2-5 bare-property syntax: Screen.Width → Screen.Width()
                // If the base is a recognised namespace, emit a zero-arg
                // builtin call instead of OP_GET_MEMBER. This makes
                // `Screen.Width` / `Sensor.Accel` etc. read like English.
                String ns = detect_namespace_call(ma->base_object);
                if (!ns.is_empty()) {
                    String fn = ns + "_" + ma->member_name.to_lower();
                    int fnidx = current_chunk->add_constant(fn);
                    emit_byte(OP_CALL);
                    emit_const_index(fnidx);
                    emit_byte((uint8_t)0);
                    break;
                }
                compile_expression(ma->base_object);
                int idx = current_chunk->add_constant(ma->member_name);
                emit_byte(OP_GET_MEMBER);
                emit_const_index(idx);
            }
            break;
        }
        case ExpressionNode::EXPRESSION_CALL: {
             CallExpression* call = (CallExpression*)expr;
             if (call->base_object) {
                 // ClassName.new() — emit OP_NEW_OBJECT instead of method call
                 if (call->base_object->type == ExpressionNode::VARIABLE &&
                     call->method_name.nocasecmp_to("new") == 0) {
                     String var_name = ((VariableNode*)call->base_object)->name;
                     if (ClassDB::class_exists(var_name)) {
                         for (int i = 0; i < call->arguments.size(); i++) {
                             compile_expression(call->arguments[i]);
                         }
                         int name_idx = current_chunk->add_constant(var_name);
                         emit_byte(OP_NEW_OBJECT);
                         emit_const_index(name_idx);
                         emit_byte((uint8_t)call->arguments.size());
                         // Return value stays on stack (expression context)
                         break;
                     }
                 }
                 // Pass 2: Camera./Sound./Speaker. namespace → flat builtin OP_CALL
                 {
                     String ns = detect_namespace_call(call->base_object);
                     if (!ns.is_empty()) {
                         for (int i = 0; i < call->arguments.size(); i++) {
                             compile_expression(call->arguments[i]);
                         }
                         String fn = ns + "_" + call->method_name.to_lower();
                         int fnidx = current_chunk->add_constant(fn);
                         emit_byte(OP_CALL);
                         emit_const_index(fnidx);
                         emit_byte((uint8_t)call->arguments.size());
                         // Return value stays on stack (expression context)
                         break;
                     }
                 }
                 // Method call on object — compile base + args, emit OP_METHOD_CALL
                 compile_expression(call->base_object);
                 for (int i = 0; i < call->arguments.size(); i++) {
                     compile_expression(call->arguments[i]);
                 }
                 int midx = current_chunk->add_constant(call->method_name);
                 emit_byte(OP_METHOD_CALL);
                 emit_const_index(midx);
                 emit_byte((uint8_t)call->arguments.size());
                 // Return value stays on stack (expression context)
                 break;
             }

             String call_name = call->method_name.to_lower();
             // A fast-call Function's return variable occupies a local slot named
             // after the function itself.  `FuncName(args)` inside FuncName is a
             // RECURSIVE SELF-CALL, not an attempt to index the (scalar) return
             // variable — detect it so the local_slots/param_vars membership test
             // below doesn't misroute it to OP_GET_ARRAY (→ null).
             bool _is_self_return_call = (current_sub && current_chunk &&
                 current_chunk->return_slot >= 0 &&
                 call->method_name.nocasecmp_to(current_sub->name) == 0);
             if (!_is_self_return_call &&
                 (array_vars.has(call_name) || dictionary_vars.has(call_name) || local_slots.has(call_name) || param_vars.has(call_name) || is_buffer_var(call->method_name))) {
                 if (call->arguments.size() != 1) {
                     compile_ok = false;
                     break;
                 }
                 // Treat as array access
                 // ── Sole-owner VGDict GET fast path (call syntax) ──
                 if (is_sole_owner_dict_var(call->method_name)) {
                     int slot = get_or_add_local(call->method_name, VT_UNKNOWN);
                     if (slot >= 0 && slot < 16) {
                         compile_expression(call->arguments[0]);  // push key only
                         emit_bytes(OP_GET_VGDICT_LOCAL, (uint8_t)slot);
                         break;
                     }
                 }
                 // ── M5: MemoryBuffer READ fast path (call syntax) ──
                 if (is_buffer_var(call->method_name)) {
                     int bslot = get_or_add_local(call->method_name, VT_UNKNOWN);
                     if (bslot >= 0) {
                         compile_expression(call->arguments[0]);  // push offset only
                         emit_bytes(OP_BUF_READ8, (uint8_t)bslot);
                         break;
                     }
                 }
                 VariableNode tmp;
                 tmp.name = call->method_name;
                 compile_expression(&tmp);
                 compile_expression(call->arguments[0]);
                 bool fast_array = is_fast_array_var(call->method_name);
                 bool fast_dict = is_dictionary_var(call->method_name);
                 bool trusted_dict = fast_dict && is_trusted_dictionary_var(call->method_name);
                 uint8_t opcode = trusted_dict ? OP_GET_DICT_TRUSTED
                     : (fast_dict ? OP_GET_DICT_FAST
                         : (fast_array ? OP_GET_ARRAY_FAST : OP_GET_ARRAY));
                 emit_byte(opcode);
                 emit_byte(1);
                 break;
             }

             if (call_name == "len" && call->arguments.size() == 1) {
                 compile_expression(call->arguments[0]);
                 emit_byte(OP_LEN);
                 break;
             }
             if (call_name == "abs" && call->arguments.size() == 1) {
                 compile_expression(call->arguments[0]);
                 emit_byte(OP_ABS);
                 break;
             }
             if (call_name == "sgn" && call->arguments.size() == 1) {
                 compile_expression(call->arguments[0]);
                 emit_byte(OP_SGN);
                 break;
             }
             if (call_name == "allocfilli64" && call->arguments.size() == 1) {
                 compile_expression(call->arguments[0]);
                 emit_byte(OP_ALLOC_FILL_I64);
                 break;
             }

             // Push args
             for(int i=0; i<call->arguments.size(); i++) {
                 compile_expression(call->arguments[i]);
             }
             // Resolve the target Sub (same module) so ByRef params bound to a
             // simple variable argument get written back after the call. In
             // expression context the write-backs run immediately after OP_CALL
             // and leave the return value on the stack (each OP_BYREF_LOAD + store
             // pair is net-zero), so the enclosing expression is unaffected.
             SubDefinition* expr_target_func = nullptr;
             if (current_module) {
                 SubDefinition* first_match_func = nullptr;
                 for (int i = 0; i < current_module->subs.size(); i++) {
                     if (current_module->subs[i]->name.nocasecmp_to(call->method_name) == 0) {
                         if (!first_match_func) first_match_func = current_module->subs[i];
                         if (current_module->subs[i]->parameters.size() == (int)call->arguments.size()) {
                             expr_target_func = current_module->subs[i];
                             break;
                         }
                     }
                 }
                 if (!expr_target_func) expr_target_func = first_match_func;
             }
             // Call
             int idx = current_chunk->add_constant(call->method_name);
             emit_byte(OP_CALL);
             emit_const_index(idx);
             emit_byte((uint8_t)call->arguments.size()); // Arg count
             emit_byref_writebacks(expr_target_func, call->arguments);
             break;
        }
        case ExpressionNode::EXPRESSION_IIF: {
            // IIf(condition, true_value, false_value)
            IIfNode* iif = (IIfNode*)expr;
            if (!iif->condition || !iif->true_part || !iif->false_part) {
                compile_ok = false;
                break;
            }
            
            // Compile condition
            compile_expression(iif->condition);
            
            // Jump to false part if condition is false
            int else_jump = emit_jump(OP_JUMP_IF_FALSE);
            
            // Compile true part
            compile_expression(iif->true_part);
            
            // Jump over false part
            int end_jump = emit_jump(OP_JUMP);
            
            // Patch else jump to here (false part)
            patch_jump(else_jump);
            
            // Compile false part
            compile_expression(iif->false_part);
            
            // Patch end jump to here
            patch_jump(end_jump);
            break;
        }
        case ExpressionNode::WITH_CONTEXT: {
            // Push the current With context object onto the value stack
            emit_byte(OP_GET_WITH);
            break;
        }
        case ExpressionNode::TYPE_CHECK: {
            // TypeOf expr Is ClassName → compile expr, push class name, OP_IS_CLASS
            TypeCheckExpression* tc = (TypeCheckExpression*)expr;
            if (!tc->expression || !tc->check_type) {
                compile_ok = false;
                break;
            }
            compile_expression(tc->expression);
            emit_constant(tc->check_type->base_type);
            emit_byte(OP_IS_CLASS);
            break;
        }
        case ExpressionNode::OPTIONAL_ACCESS: {
            // obj?.member → if obj is Nil, push Nil; else push obj.member
            OptionalAccessExpression* oa = (OptionalAccessExpression*)expr;
            if (!oa->object_expression) {
                emit_byte(OP_NIL);
                break;
            }
            // Compile the base object
            compile_expression(oa->object_expression);
            // Duplicate it so we can test for nil and still use it
            emit_byte(OP_DUP);
            // If falsy (nil/nothing), jump to the nil path
            int nil_jump = emit_jump(OP_JUMP_IF_FALSE);
            // Not nil: do member access (base is still on stack from DUP)
            {
                int name_idx = current_chunk->add_constant(oa->member_name);
                emit_byte(OP_GET_MEMBER);
                emit_const_index(name_idx);
            }
            int end_jump = emit_jump(OP_JUMP);
            // Nil path: pop the duplicated nil value, push nil result
            patch_jump(nil_jump);
            emit_byte(OP_POP); // pop the duplicated nil value
            emit_byte(OP_NIL);
            patch_jump(end_jump);
            break;
        }
        case ExpressionNode::LAMBDA: {
            // Emit a constant Dictionary wrapper like the AST interpreter:
            // { __vg_lambda: true, __vg_is_arrow: bool, __vg_params: Array, __vg_ast_ptr: uint64_t }
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
            emit_constant(Variant(lambda_obj));
            break;
        }
        default:
             UtilityFunctions::print("Compiler: Unsupported expression type ", expr->type);
             emit_byte(OP_NIL);
               compile_ok = false;
             break;
    }
}

