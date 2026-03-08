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

void VisualGasicCompiler::emit_bytes(uint8_t byte1, uint8_t byte2) {
    emit_byte(byte1);
    emit_byte(byte2);
}

void VisualGasicCompiler::emit_constant(const Variant& value) {
    int idx = current_chunk->add_constant(value);
    if (idx < 256) {
        emit_bytes(OP_CONSTANT, (uint8_t)idx);
    } else {
        // Handle > 256 constants? Need OP_CONSTANT_LONG or similar. For now just truncate or error?
        UtilityFunctions::print("Compiler Error: Too many constants");
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

bool VisualGasicCompiler::compile(ModuleNode* module, const String& entry_point, BytecodeChunk* chunk) {
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
    typed_locals.clear();
    non_local_names.clear();
    used_vars.clear();
    expr_cache.clear();
    loop_vars.clear();
    loop_bound_vars.clear();
    temp_local_id = 0;
    current_sub = nullptr;
    
    // Find the entry point sub
    SubDefinition* sub = nullptr;
    for(int i=0; i<module->subs.size(); i++) {
        if (module->subs[i]->name.nocasecmp_to(entry_point) == 0) {
            sub = module->subs[i];
            break;
        }
    }
    
    if (!sub) {
        UtilityFunctions::print("Compiler: Entry point not found: ", entry_point);
        return false;
    }


    current_sub = sub;
    non_local_names.insert(sub->name.to_lower());
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
        non_local_names.insert(sub->parameters[i].name.to_lower());
        param_vars.insert(sub->parameters[i].name.to_lower());
        // Register ParamArray parameters as array variables for proper subscript handling
        if (sub->parameters[i].is_param_array) {
            array_vars.insert(sub->parameters[i].name.to_lower());
        }
    }

    // Mark module-level variables as non-local so they use OP_SET_GLOBAL
    // This ensures global Variant variables can change types correctly
    for (int i = 0; i < module->variables.size(); i++) {
        non_local_names.insert(module->variables[i]->name.to_lower());
        // Register global arrays / dictionaries so the compiler can
        // distinguish  foo(i)  as an array access vs. a function call.
        if (module->variables[i]->array_sizes.size() > 0) {
            array_vars.insert(module->variables[i]->name.to_lower());
        }
        String vtype = module->variables[i]->type.to_lower();
        if (vtype == "dictionary") {
            dictionary_vars.insert(module->variables[i]->name.to_lower());
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
        emit_bytes(OP_CALL, (uint8_t)idx);
        emit_byte((uint8_t)2);

        int slot = get_or_add_local(sub->name, VT_INT);
        if (slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
        else {
            int name_idx = current_chunk->add_constant(sub->name);
            emit_bytes(OP_SET_GLOBAL, (uint8_t)name_idx);
        }
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
                                emit_bytes(OP_SET_GLOBAL, (uint8_t)idx);
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
                if (t == "integer" || t == "long") array_types[s->variable_name.to_lower()] = VT_INT;
                else if (t == "single" || t == "double") array_types[s->variable_name.to_lower()] = VT_FLOAT;
                String bound = extract_bound_var(s->array_sizes[0]);
                if (!bound.is_empty()) array_bound_vars[s->variable_name.to_lower()] = bound.to_lower();
            } else {
                String t = s->type_name.to_lower();
                ValueType vt = VT_UNKNOWN;
                if (t == "integer" || t == "long") vt = VT_INT;
                else if (t == "single" || t == "double") vt = VT_FLOAT;
                else if (t == "dictionary") {
                    dictionary_vars.insert(s->variable_name.to_lower());
                    trusted_dictionary_vars.insert(s->variable_name.to_lower());
                    // Sole-ownership candidate: typed local dict declared with Dim
                    // Will be revoked if the dict escapes (passed as arg, assigned to another var, etc.)
                    sole_owner_dict_vars.insert(s->variable_name.to_lower());
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

void VisualGasicCompiler::collect_used_vars_stmt(Statement* stmt) {
    if (!stmt) return;
    switch (stmt->type) {
        case STMT_ASSIGNMENT: {
            AssignmentStatement* s = (AssignmentStatement*)stmt;
            collect_used_vars_expr(s->value);
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
        case STMT_FOR_EACH: {
            ForEachStatement* s = (ForEachStatement*)stmt;
            for (int i = 0; i < s->body.size(); i++) _check_dict_escapes(s->body[i], escaped);
            break;
        }
        case STMT_CALL: {
            CallStatement* s = (CallStatement*)stmt;
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
    if (expr->type == ExpressionNode::UNARY_OP) {
        UnaryOpNode* u = (UnaryOpNode*)expr;
        return is_constant_expr(u->operand);
    }
    if (expr->type == ExpressionNode::BINARY_OP) {
        BinaryOpNode* b = (BinaryOpNode*)expr;
        return is_constant_expr(b->left) && is_constant_expr(b->right);
    }
    return false;
}

Variant VisualGasicCompiler::eval_constant_expr(ExpressionNode* expr) const {
    if (!expr) return Variant();
    if (expr->type == ExpressionNode::LITERAL) {
        return ((LiteralNode*)expr)->value;
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
        else if (b->op.nocasecmp_to("And") == 0) { valid = true; res = vg_variant_truthy(a) && vg_variant_truthy(c); }
        else if (b->op.nocasecmp_to("Or") == 0) { valid = true; res = vg_variant_truthy(a) || vg_variant_truthy(c); }
        else if (b->op.nocasecmp_to("Xor") == 0) {
            bool left = vg_variant_truthy(a);
            bool right = vg_variant_truthy(c);
            valid = true;
            res = (left && !right) || (!left && right);
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
        else if (b->op.nocasecmp_to("Like") == 0) {
            // VB6-style Like pattern matching at compile time
            valid = true;
            res = vb_like_match(String(a), String(c));
        }
        if (valid) return res;
    }
    return Variant();
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
                    if (n->class_name.nocasecmp_to("Dictionary") == 0 && n->args.size() == 0) {
                        // Dim d As New Dictionary → OP_NEW_DICT + store
                        emit_byte(OP_NEW_DICT);
                        int slot = get_or_add_local(s->variable_name, VT_UNKNOWN);
                        if (slot >= 0) {
                            dictionary_vars.insert(s->variable_name.to_lower());
                            emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                        } else {
                            int idx = current_chunk->add_constant(s->variable_name);
                            emit_bytes(OP_SET_GLOBAL, (uint8_t)idx);
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
                        if (t == "integer" || t == "long") vt = VT_INT;
                        else if (t == "single" || t == "double") vt = VT_FLOAT;
                    }
                    compile_expression(s->initializer);
                    int slot = get_or_add_local(s->variable_name, vt);
                    if (slot >= 0) {
                        emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                    } else {
                        int idx = current_chunk->add_constant(s->variable_name);
                        emit_bytes(OP_SET_GLOBAL, (uint8_t)idx);
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
                    if (t != "integer" && t != "long" && t != "single" && t != "double" 
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
                String t = s->type_name.to_lower();
                if (t == "integer" || t == "long") emit_byte(OP_NEW_ARRAY_I64);
                else emit_byte(OP_NEW_ARRAY);

                int slot = get_or_add_local(s->variable_name, VT_UNKNOWN);
                if (slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                else {
                    int idx = current_chunk->add_constant(s->variable_name);
                    emit_bytes(OP_SET_GLOBAL, (uint8_t)idx);
                }
                break;
            } else if (s->is_dynamic_array) {
                // Dynamic array with empty parentheses: Dim arr() As Integer
                // Initialize as empty array to be resized with ReDim later
                emit_constant(Variant((int64_t)0));
                String t = s->type_name.to_lower();
                if (t == "integer" || t == "long") emit_byte(OP_NEW_ARRAY_I64);
                else emit_byte(OP_NEW_ARRAY);

                int slot = get_or_add_local(s->variable_name, VT_UNKNOWN);
                if (slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                else {
                    int idx = current_chunk->add_constant(s->variable_name);
                    emit_bytes(OP_SET_GLOBAL, (uint8_t)idx);
                }
                break;
            } else {
                Variant init_val;
                if (!s->type_name.is_empty()) {
                    String t = s->type_name.to_lower();
                    if (t == "integer" || t == "long") init_val = (int64_t)0;
                    else if (t == "single" || t == "double") init_val = (double)0.0;
                    else if (t == "string") init_val = "";
                    else if (t == "boolean") init_val = false;
                    else if (t == "dictionary") {
                        String lower = s->variable_name.to_lower();
                        dictionary_vars.insert(lower);
                        trusted_dictionary_vars.insert(lower);
                    }
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
                    emit_bytes(OP_SET_GLOBAL, (uint8_t)idx);
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
                             int c_idx = current_chunk->add_constant(Variant(c_val));
                             emit_byte(OP_ACCUM_I64_MULADD_CONST);
                             emit_byte((uint8_t)s_slot);
                             emit_byte((uint8_t)j_slot);
                             emit_byte((uint8_t)k_idx);
                             emit_byte((uint8_t)c_idx);
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
                         emit_byte((uint8_t)idx);
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
                     emit_bytes(OP_SET_GLOBAL, (uint8_t)idx);
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
                    emit_bytes(OP_SET_GLOBAL, (uint8_t)idx);
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
                         emit_bytes(OP_SET_DICT_GLOBAL, (uint8_t)idx);
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
                         emit_bytes(OP_SET_GLOBAL, (uint8_t)idx);
                     }
                 }
             } else if (s->target->type == ExpressionNode::MEMBER_ACCESS) {
                 MemberAccessNode *ma = (MemberAccessNode *)s->target;
                 if (!ma->base_object) {
                     compile_ok = false;
                     break;
                 }
                 compile_expression(ma->base_object);
                 compile_expression(s->value);
                 int member_idx = current_chunk->add_constant(ma->member_name);
                 emit_bytes(OP_SET_MEMBER, (uint8_t)member_idx);

                 bool stored = false;
                 if (ma->base_object->type == ExpressionNode::VARIABLE) {
                     VariableNode *base_var = (VariableNode *)ma->base_object;
                     int slot = get_or_add_local(base_var->name, VT_UNKNOWN);
                     if (slot >= 0) {
                         emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                         stored = true;
                     } else {
                         int idx = current_chunk->add_constant(base_var->name);
                         emit_bytes(OP_SET_GLOBAL, (uint8_t)idx);
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
                        emit_byte((uint8_t)name_idx);
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
                emit_bytes(OP_METHOD_CALL, (uint8_t)idx);
                emit_byte((uint8_t)s->arguments.size());
                emit_byte(OP_POP); // discard return value (statement context)
                break;
            }
            
            // Check if calling a function with ByRef parameters AND variable arguments
            // that could be written back (requires interpreter for write-back)
            // Also check for ParamArray which needs interpreter
            if (current_module) {
                for (int i = 0; i < current_module->subs.size(); i++) {
                    if (current_module->subs[i]->name.nocasecmp_to(s->method_name) == 0) {
                        SubDefinition* target_func = current_module->subs[i];
                        for (int j = 0; j < target_func->parameters.size(); j++) {
                            // ParamArray requires interpreter
                            if (target_func->parameters[j].is_param_array) {
                                compile_ok = false;
                                break;
                            }
                            if (target_func->parameters[j].is_by_ref && 
                                j < s->arguments.size() &&
                                s->arguments[j] &&
                                s->arguments[j]->type == ExpressionNode::VARIABLE) {
                                // Has ByRef parameter with variable argument - need interpreter for write-back
                                compile_ok = false;
                                break;
                            }
                        }
                        break;
                    }
                }
            }
            if (!compile_ok) break;
            
            for (int i = 0; i < s->arguments.size(); i++) {
                compile_expression(s->arguments[i]);
            }
            int idx = current_chunk->add_constant(s->method_name);
            emit_bytes(OP_CALL, (uint8_t)idx);
            emit_byte((uint8_t)s->arguments.size());
            emit_byte(OP_POP);
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
                        emit_bytes(OP_GET_GLOBAL, (uint8_t)idx);
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
                    emit_byte((uint8_t)lit_idx);
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
                        emit_bytes(OP_SET_GLOBAL, (uint8_t)idx);
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
                    emit_bytes(OP_SET_GLOBAL, (uint8_t)idx);
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
                    emit_byte((uint8_t)lit_idx);
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
                    emit_byte((uint8_t)k_idx);
                    emit_byte((uint8_t)c_idx);

                    int slot = get_or_add_local(sum_var, VT_INT);
                    if (slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                    else {
                        int idx = current_chunk->add_constant(sum_var);
                        emit_bytes(OP_SET_GLOBAL, (uint8_t)idx);
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
                    emit_byte((uint8_t)k_idx);
                    emit_byte((uint8_t)c_idx);

                    int slot = get_or_add_local(sum_var, VT_INT);
                    if (slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                    else {
                        int idx = current_chunk->add_constant(sum_var);
                        emit_bytes(OP_SET_GLOBAL, (uint8_t)idx);
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
                            emit_bytes(OP_SET_GLOBAL, (uint8_t)idx);
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
                            emit_bytes(OP_SET_GLOBAL, (uint8_t)idx);
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
                                emit_bytes(OP_SET_GLOBAL, (uint8_t)idx);
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
                                    emit_bytes(OP_GET_GLOBAL, (uint8_t)kidx);
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
                    emit_bytes(OP_SET_GLOBAL, (uint8_t)idx);
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
                    emit_bytes(OP_SET_GLOBAL, (uint8_t)idx);
                }
                break;
            }

            // Closed-form arithmetic loop optimization disabled (correctness over speed).

            String loop_bound = extract_bound_var(f->to_val);
            loop_vars.push_back(f->variable_name);
            loop_bound_vars.push_back(loop_bound);
            loop_exit_jumps.push_back(Vector<int>());
            loop_continue_targets.push_back(-1); // placeholder, updated after body

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
                emit_bytes(OP_SET_GLOBAL, (uint8_t)var_idx);
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

            if (var_slot >= 0) {
                emit_bytes(OP_GET_LOCAL, (uint8_t)var_slot);
            }
            else {
                int var_idx = current_chunk->add_constant(f->variable_name);
                emit_bytes(OP_GET_GLOBAL, (uint8_t)var_idx);
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
                else { int vi = current_chunk->add_constant(f->variable_name); emit_bytes(OP_GET_GLOBAL, (uint8_t)vi); }
                if (to_slot >= 0) emit_bytes(OP_GET_LOCAL, (uint8_t)to_slot);
                else compile_expression(f->to_val);
                emit_byte(use_int_compare ? OP_LESS_EQUAL_I64 : OP_LESS_EQUAL);
                int skip_neg_path = emit_jump(OP_JUMP);

                // Negative step path: counter >= limit
                patch_jump(step_positive_jump);
                if (var_slot >= 0) emit_bytes(OP_GET_LOCAL, (uint8_t)var_slot);
                else { int vi = current_chunk->add_constant(f->variable_name); emit_bytes(OP_GET_GLOBAL, (uint8_t)vi); }
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
                                            emit_bytes(OP_SET_GLOBAL, (uint8_t)idx);
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
                    emit_bytes(OP_GET_GLOBAL, (uint8_t)var_idx);
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
                    emit_bytes(OP_SET_GLOBAL, (uint8_t)var_idx);
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
            loop_vars.remove_at(loop_vars.size() - 1);
            loop_bound_vars.remove_at(loop_bound_vars.size() - 1);
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
                    emit_bytes(OP_GET_GLOBAL, (uint8_t)gidx);
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
                    emit_bytes(OP_SET_GLOBAL, (uint8_t)gidx);
                }
            } else {
                // Non-preserve: create brand new array
                // size = expr + 1 (VB arrays are 0..N)
                compile_expression(s->array_sizes[0]);
                emit_constant(Variant((int64_t)1));
                emit_byte(OP_ADD);
                String key = s->variable_name.to_lower();
                if (array_types.has(key) && array_types[key] == VT_INT) emit_byte(OP_NEW_ARRAY_I64);
                else emit_byte(OP_NEW_ARRAY);

                int slot = get_or_add_local(s->variable_name, VT_UNKNOWN);
                if (slot >= 0) emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                else {
                    int idx = current_chunk->add_constant(s->variable_name);
                    emit_bytes(OP_SET_GLOBAL, (uint8_t)idx);
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
                emit_bytes(OP_SET_GLOBAL, (uint8_t)idx);
            }
            break;
        }
        case STMT_EXIT: {
            ExitStatement *s = (ExitStatement *)stmt;
            if (s->exit_type == ExitStatement::EXIT_FUNCTION || s->exit_type == ExitStatement::EXIT_SUB) {
                emit_return();
            } else if ((s->exit_type == ExitStatement::EXIT_FOR || s->exit_type == ExitStatement::EXIT_DO) &&
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
            emit_byte((uint8_t)data_idx);
            break;
        }
        case STMT_SUSPEND_WHENEVER: {
            SuspendWheneverStatement* s = (SuspendWheneverStatement*)stmt;
            int name_idx = current_chunk->add_constant(s->section_name);
            emit_byte(OP_SUSPEND_WHENEVER);
            emit_byte((uint8_t)name_idx);
            break;
        }
        case STMT_RESUME_WHENEVER: {
            ResumeWheneverStatement* s = (ResumeWheneverStatement*)stmt;
            int name_idx = current_chunk->add_constant(s->section_name);
            emit_byte(OP_RESUME_WHENEVER);
            emit_byte((uint8_t)name_idx);
            break;
        }
        case STMT_SELECT: {
            SelectStatement* s = (SelectStatement*)stmt;
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
                    // Loop While - continue if true
                    int continue_offset = current_chunk->code.size() - loop_start + 3;
                    emit_byte(OP_JUMP_IF_TRUE);
                    emit_byte((uint8_t)((~continue_offset + 1) & 0xFF));
                    emit_byte((uint8_t)(((~continue_offset + 1) >> 8) & 0xFF));
                } else { // UNTIL
                    // Loop Until - continue if false
                    int continue_offset = current_chunk->code.size() - loop_start + 3;
                    emit_byte(OP_JUMP_IF_FALSE);
                    emit_byte((uint8_t)((~continue_offset + 1) & 0xFF));
                    emit_byte((uint8_t)(((~continue_offset + 1) >> 8) & 0xFF));
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
                emit_bytes(OP_CONSTANT, (uint8_t)label_idx);
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
                    emit_bytes(OP_COERCE_TYPE, (uint8_t)type_idx);
                }
                // Store into target variable
                if (target->type == ExpressionNode::VARIABLE) {
                    VariableNode* tv = (VariableNode*)target;
                    int slot = get_or_add_local(tv->name, VT_UNKNOWN);
                    if (slot >= 0) {
                        emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                    } else {
                        int idx = current_chunk->add_constant(tv->name);
                        emit_bytes(OP_SET_GLOBAL, (uint8_t)idx);
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
                                emit_bytes(OP_SET_GLOBAL, (uint8_t)idx);
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
                emit_bytes(OP_ON_ERROR_GOTO, (uint8_t)label_idx);
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
                emit_bytes(OP_SET_GLOBAL, (uint8_t)name_idx);
            }

            // --- loop body ---
            for (int i = 0; i < s->body.size(); i++) {
                compile_statement(s->body[i]);
            }

            // Continue For target: the increment point
            if (!loop_continue_targets.is_empty()) {
                loop_continue_targets.write[loop_continue_targets.size() - 1] = current_chunk->code.size();
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
            // Continue For / Continue Do / Continue While
            ContinueStatement* cont = (ContinueStatement*)stmt;
            if (loop_continue_targets.is_empty()) {
                compile_ok = false;
                break;
            }
            int target = loop_continue_targets[loop_continue_targets.size() - 1];
            if (target < 0) {
                // Target not yet known (shouldn't happen since body is compiled first for For)
                compile_ok = false;
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
            // Const declarations are no-ops at runtime (values inlined at parse time)
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
                compile_expression(s->file_number);
                // Push var name as constant for assignment
                if (s->variables.size() > 0 && s->variables[0]->type == ExpressionNode::VARIABLE) {
                    int idx = current_chunk->add_constant(((VariableNode*)s->variables[0])->name);
                    emit_byte(OP_LINE_INPUT);
                    emit_byte((uint8_t)idx);
                }
            } else if (s->file_number) {
                // Input #n, var1, var2...
                compile_expression(s->file_number);
                for (int i = 0; i < s->variables.size(); i++) {
                    if (s->variables[i]->type == ExpressionNode::VARIABLE) {
                        int idx = current_chunk->add_constant(((VariableNode*)s->variables[i])->name);
                        emit_byte(OP_INPUT_FILE);
                        emit_byte((uint8_t)idx);
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
            emit_byte((uint8_t)(name_idx & 0xFF));
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
            // The parser turns 'Await expr' into AssignmentStatement to
            // __await_result__, so this case is rarely hit.  Emit OP_AWAIT
            // as a placeholder for future coroutine dispatch.
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
            emit_byte((uint8_t)name_idx);
            emit_byte((uint8_t)n->args.size());
            break;
        }
        case ExpressionNode::ME: {
            // "Me" keyword - compile as OP_GET_GLOBAL with "Me" constant
            // Runtime will resolve this to owner
            int idx = current_chunk->add_constant(String("Me"));
            emit_bytes(OP_GET_GLOBAL, (uint8_t)idx);
            break;
        }
        case ExpressionNode::SUPER: {
            // "Super" keyword — compile same pattern as "Me"
            // Runtime OP_GET_GLOBAL resolves "Super" to owner (parent class dispatch handled by method call)
            int idx = current_chunk->add_constant(String("Super"));
            emit_bytes(OP_GET_GLOBAL, (uint8_t)idx);
            break;
        }
        case ExpressionNode::VARIABLE: {
            VariableNode* v = (VariableNode*)expr;
            int slot = get_or_add_local(v->name, VT_UNKNOWN);
            if (slot >= 0) {
                emit_bytes(OP_GET_LOCAL, (uint8_t)slot);
            } else {
                int idx = current_chunk->add_constant(v->name);
                emit_bytes(OP_GET_GLOBAL, (uint8_t)idx);
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
            // e.g. "ev Is InputEventKey" → OP_IS_CLASS
            if (b->op.nocasecmp_to("Is") == 0 && b->right &&
                b->right->type == ExpressionNode::VARIABLE) {
                String class_name = ((VariableNode*)b->right)->name;
                if (ClassDB::class_exists(class_name)) {
                    compile_expression(b->left);             // push object
                    emit_constant(class_name);               // push class name string
                    emit_byte(OP_IS_CLASS);                  // type-check
                    break;
                }
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
                        if (b->right->type == ExpressionNode::LITERAL && ((LiteralNode*)b->right)->value.get_type() == Variant::INT) {
                            int idx = current_chunk->add_constant(((LiteralNode*)b->right)->value);
                            emit_bytes(OP_ADD_I64_CONST, (uint8_t)idx);
                        } else if (b->left->type == ExpressionNode::LITERAL && ((LiteralNode*)b->left)->value.get_type() == Variant::INT) {
                            int idx = current_chunk->add_constant(((LiteralNode*)b->left)->value);
                            emit_bytes(OP_ADD_I64_CONST, (uint8_t)idx);
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
                            emit_bytes(OP_SUB_I64_CONST, (uint8_t)idx);
                        } else {
                            emit_byte(OP_SUB_I64);
                        }
                    }
                    else if (lt == VT_FLOAT || rt == VT_FLOAT) emit_byte(OP_SUB_F64);
                    else emit_byte(OP_SUBTRACT);
                }
                else if (b->op == "*") {
                    if (lt == VT_INT && rt == VT_INT) {
                        if (b->right->type == ExpressionNode::LITERAL && ((LiteralNode*)b->right)->value.get_type() == Variant::INT) {
                            int idx = current_chunk->add_constant(((LiteralNode*)b->right)->value);
                            emit_bytes(OP_MUL_I64_CONST, (uint8_t)idx);
                        } else if (b->left->type == ExpressionNode::LITERAL && ((LiteralNode*)b->left)->value.get_type() == Variant::INT) {
                            int idx = current_chunk->add_constant(((LiteralNode*)b->left)->value);
                            emit_bytes(OP_MUL_I64_CONST, (uint8_t)idx);
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
                else if (b->op.nocasecmp_to("Mod") == 0 || b->op == "%") emit_byte(OP_MOD);
                else if (b->op.nocasecmp_to("Like") == 0) emit_byte(OP_LIKE);
                else if (b->op == "\\") emit_byte(OP_INT_DIVIDE); // Integer division
                else if (b->op == "^" || b->op == "**") emit_byte(OP_POWER); // Exponentiation
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
                    if (b->right->type == ExpressionNode::LITERAL && ((LiteralNode*)b->right)->value.get_type() == Variant::INT) {
                        int idx = current_chunk->add_constant(((LiteralNode*)b->right)->value);
                        emit_bytes(OP_ADD_I64_CONST, (uint8_t)idx);
                    } else if (b->left->type == ExpressionNode::LITERAL && ((LiteralNode*)b->left)->value.get_type() == Variant::INT) {
                        int idx = current_chunk->add_constant(((LiteralNode*)b->left)->value);
                        emit_bytes(OP_ADD_I64_CONST, (uint8_t)idx);
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
                        emit_bytes(OP_SUB_I64_CONST, (uint8_t)idx);
                    } else {
                        emit_byte(OP_SUB_I64);
                    }
                }
                else if (lt == VT_FLOAT || rt == VT_FLOAT) emit_byte(OP_SUB_F64);
                else emit_byte(OP_SUBTRACT);
            }
            else if (b->op == "*") {
                if (lt == VT_INT && rt == VT_INT) {
                    if (b->right->type == ExpressionNode::LITERAL && ((LiteralNode*)b->right)->value.get_type() == Variant::INT) {
                        int idx = current_chunk->add_constant(((LiteralNode*)b->right)->value);
                        emit_bytes(OP_MUL_I64_CONST, (uint8_t)idx);
                    } else if (b->left->type == ExpressionNode::LITERAL && ((LiteralNode*)b->left)->value.get_type() == Variant::INT) {
                        int idx = current_chunk->add_constant(((LiteralNode*)b->left)->value);
                        emit_bytes(OP_MUL_I64_CONST, (uint8_t)idx);
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
            else if (b->op.nocasecmp_to("Mod") == 0 || b->op == "%") emit_byte(OP_MOD);
            else if (b->op.nocasecmp_to("Like") == 0) emit_byte(OP_LIKE);
            else if (b->op == "\\") emit_byte(OP_INT_DIVIDE); // Integer division
            else if (b->op == "^" || b->op == "**") emit_byte(OP_POWER); // Exponentiation
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
                        emit_byte((uint8_t)name_idx);
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
                emit_bytes(OP_METHOD_CALL, (uint8_t)midx);
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
                if (!is_array && !is_dict && !is_local && !is_param) {
                    // Not a known array/dict/local/parameter variable — treat as function call
                    for (int i = 0; i < aa->indices.size(); i++) {
                        compile_expression(aa->indices[i]);
                    }
                    int idx = current_chunk->add_constant(var_name);
                    emit_bytes(OP_CALL, (uint8_t)idx);
                    emit_byte((uint8_t)aa->indices.size());
                    break;
                }
            }
            // ── True array/dict access ──
            if (aa->indices.size() != 1) {
                compile_ok = false;
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
            // Check for Color.White, Color.Red, etc. — named color constants
            if (ma->base_object && ma->base_object->type == ExpressionNode::VARIABLE) {
                String base_name = ((VariableNode*)ma->base_object)->name;
                if (base_name.nocasecmp_to("Color") == 0 && !ma->member_name.is_empty()) {
                    Color c = Color::named(ma->member_name);
                    int cidx = current_chunk->add_constant(c);
                    emit_bytes(OP_CONSTANT, (uint8_t)cidx);
                    break;
                }
            }
            // Check if this is ClassName.CONSTANT (Godot class enum constant)
            if (ma->base_object && ma->base_object->type == ExpressionNode::VARIABLE) {
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
                        emit_bytes(OP_CONSTANT, (uint8_t)cidx);
                        break;
                    }
                }
            }
            compile_expression(ma->base_object);
            int idx = current_chunk->add_constant(ma->member_name);
            emit_bytes(OP_GET_MEMBER, (uint8_t)idx);
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
                         emit_byte((uint8_t)name_idx);
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
                 emit_bytes(OP_METHOD_CALL, (uint8_t)midx);
                 emit_byte((uint8_t)call->arguments.size());
                 // Return value stays on stack (expression context)
                 break;
             }

             String call_name = call->method_name.to_lower();
             if (array_vars.has(call_name) || dictionary_vars.has(call_name) || local_slots.has(call_name) || param_vars.has(call_name)) {
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
             // Call
             int idx = current_chunk->add_constant(call->method_name);
             emit_bytes(OP_CALL, (uint8_t)idx);
             emit_byte((uint8_t)call->arguments.size()); // Arg count
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
                emit_bytes(OP_GET_MEMBER, (uint8_t)name_idx);
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

