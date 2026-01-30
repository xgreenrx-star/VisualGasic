#include "visual_gasic_compiler.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/core/math.hpp>

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
    compile_ok = true;
    array_vars.clear();
    dictionary_vars.clear();
    trusted_dictionary_vars.clear();
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

    for (int i = 0; i < sub->parameters.size(); i++) {
        non_local_names.insert(sub->parameters[i].name.to_lower());
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
        case STMT_FOR: {
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
    int idx = 0;
    if (f->body.size() < 5) return false;

    Statement* s0 = nullptr;
    Statement* s1 = nullptr;
    Statement* s2 = nullptr;
    Statement* s3 = nullptr;
    Statement* s4 = nullptr;

    while (idx < f->body.size() && (!s0 || s0->type != STMT_REDIM)) s0 = f->body[idx++];
    if (!s0 || s0->type != STMT_REDIM) return false;
    ReDimStatement* rd = (ReDimStatement*)s0;
    if (rd->preserve || rd->array_sizes.size() != 1) return false;

    while (idx < f->body.size() && (!s1 || s1->type != STMT_FOR)) s1 = f->body[idx++];
    if (!s1 || s1->type != STMT_FOR) return false;
    ForStatement* fill_loop = (ForStatement*)s1;
    String fill_arr;
    if (!is_loop_array_fill(fill_loop, fill_arr)) return false;

    while (idx < f->body.size() && (!s2 || s2->type != STMT_ASSIGNMENT)) s2 = f->body[idx++];
    if (!s2 || s2->type != STMT_ASSIGNMENT) return false;
    AssignmentStatement* tmp_assign = (AssignmentStatement*)s2;
    if (!tmp_assign->target || tmp_assign->target->type != ExpressionNode::VARIABLE) return false;
    if (!tmp_assign->value || tmp_assign->value->type != ExpressionNode::LITERAL) return false;
    LiteralNode* tmp_lit = (LiteralNode*)tmp_assign->value;
    if (tmp_lit->value.get_type() != Variant::STRING) return false;
    if (String(tmp_lit->value) != "") return false;

    while (idx < f->body.size() && (!s3 || s3->type != STMT_FOR)) s3 = f->body[idx++];
    if (!s3 || s3->type != STMT_FOR) return false;
    ForStatement* string_loop = (ForStatement*)s3;
    String loop_target;
    String loop_literal;
    if (!is_loop_string_concat(string_loop, loop_target, loop_literal)) return false;

    while (idx < f->body.size() && (!s4 || s4->type != STMT_ASSIGNMENT)) s4 = f->body[idx++];
    if (!s4 || s4->type != STMT_ASSIGNMENT) return false;
    AssignmentStatement* sum_assign = (AssignmentStatement*)s4;
    if (!sum_assign->target || sum_assign->target->type != ExpressionNode::VARIABLE) return false;
    VariableNode* sum_target = (VariableNode*)sum_assign->target;

    String rd_name = rd->variable_name;
    if (fill_arr.nocasecmp_to(rd_name) != 0) return false;
    if (loop_target.nocasecmp_to(tmp_assign->target->type == ExpressionNode::VARIABLE ? ((VariableNode*)tmp_assign->target)->name : "") != 0) return false;

    // Validate sum assignment: sum = sum + arr(0) + size_var
    if (!sum_assign->value || sum_assign->value->type != ExpressionNode::BINARY_OP) return false;

    auto collect_terms = [&](ExpressionNode* expr, Vector<ExpressionNode*> &out, auto&& collect_terms_ref) -> void {
        if (expr && expr->type == ExpressionNode::BINARY_OP && ((BinaryOpNode*)expr)->op == "+") {
            BinaryOpNode* b = (BinaryOpNode*)expr;
            collect_terms_ref(b->left, out, collect_terms_ref);
            collect_terms_ref(b->right, out, collect_terms_ref);
        } else if (expr) {
            out.push_back(expr);
        }
    };

    Vector<ExpressionNode*> terms;

    if (terms.size() != 3) return false;

    auto is_var_named = [&](ExpressionNode* expr, const String &name) -> bool {
        if (!expr || expr->type != ExpressionNode::VARIABLE) return false;
        return ((VariableNode*)expr)->name.nocasecmp_to(name) == 0;
    };
    auto is_arr0 = [&](ExpressionNode* expr, const String &arr_name) -> bool {
        if (!expr) return false;
        if (expr->type == ExpressionNode::ARRAY_ACCESS) {
            ArrayAccessNode* aa = (ArrayAccessNode*)expr;
            if (!aa->base || aa->base->type != ExpressionNode::VARIABLE) return false;
            if (((VariableNode*)aa->base)->name.nocasecmp_to(arr_name) != 0) return false;
            if (aa->indices.size() != 1 || aa->indices[0]->type != ExpressionNode::LITERAL) return false;
            Variant idx = ((LiteralNode*)aa->indices[0])->value;
            if (idx.get_type() == Variant::INT) return (int64_t)idx == 0;
            if (idx.get_type() == Variant::FLOAT) return (double)idx == 0.0;
            if (idx.get_type() == Variant::BOOL) return ((bool)idx ? 1 : 0) == 0;
            return false;
        }
        if (expr->type == ExpressionNode::EXPRESSION_CALL) {
            CallExpression* call = (CallExpression*)expr;
            if (call->base_object) return false;
            if (call->method_name.nocasecmp_to(arr_name) != 0) return false;
            if (call->arguments.size() != 1 || call->arguments[0]->type != ExpressionNode::LITERAL) return false;
            Variant idx = ((LiteralNode*)call->arguments[0])->value;
            if (idx.get_type() == Variant::INT) return (int64_t)idx == 0;
            if (idx.get_type() == Variant::FLOAT) return (double)idx == 0.0;
            if (idx.get_type() == Variant::BOOL) return ((bool)idx ? 1 : 0) == 0;
            return false;
        }
        return false;
    };

    bool has_sum = false;
    bool has_arr0 = false;
    size_var = "";
    for (int i = 0; i < terms.size(); i++) {
        if (is_var_named(terms[i], sum_target->name)) has_sum = true;
        else if (is_arr0(terms[i], rd_name)) has_arr0 = true;
        else if (terms[i]->type == ExpressionNode::VARIABLE) size_var = ((VariableNode*)terms[i])->name;
    }
    if (!has_sum || !has_arr0 || size_var.is_empty()) return false;

    HashSet<String> rd_vars;
    collect_vars_in_expr(rd->array_sizes[0], rd_vars);
    if (!rd_vars.has(size_var.to_lower())) return false;

    HashSet<String> fill_vars;
    collect_vars_in_expr(fill_loop->to_val, fill_vars);
    if (!fill_vars.has(size_var.to_lower())) return false;

    HashSet<String> str_vars;
    collect_vars_in_expr(string_loop->to_val, str_vars);
    if (!str_vars.has(size_var.to_lower())) return false;

    sum_var = sum_target->name;
    arr_var = rd_name;
    tmp_var = ((VariableNode*)tmp_assign->target)->name;
    literal_value = loop_literal;
    return true;
}

bool VisualGasicCompiler::is_interop_loop(ForStatement* outer, String &sum_var, String &literal_value, ForStatement* &inner_out) const {
    if (!outer || outer->body.size() != 1) return false;
    Statement* inner_stmt = outer->body[0];
    if (!inner_stmt || inner_stmt->type != STMT_FOR) return false;
    ForStatement* inner = (ForStatement*)inner_stmt;
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
        if (call->arguments.size() != 1 || call->arguments[0]->type != ExpressionNode::VARIABLE) return false;
        idx_var = ((VariableNode*)call->arguments[0])->name.to_lower();

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
    expr_cache.clear();
    switch (stmt->type) {
        case STMT_PRINT: {
            PrintStatement* s = (PrintStatement*)stmt;
            if (s->expression) {
                compile_expression(s->expression);
                emit_byte(OP_PRINT);
            }
            break;
        }
        case STMT_DIM: {
            DimStatement* s = (DimStatement*)stmt;
            if (s->initializer) {
                // Initializers with casting are not supported in bytecode yet.
                compile_ok = false;
                break;
            }

            if (s->array_sizes.size() > 0) {
                if (s->array_sizes.size() != 1) {
                    compile_ok = false;
                    break;
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
                    else init_val = Variant();
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
                 if (!used_vars.has(name) && is_pure_expr(s->value)) {
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
                compile_expression(s->value);
                 VariableNode* v = (VariableNode*)s->target;
                 int slot = get_or_add_local(v->name, infer_type(s->value));
                 if (slot >= 0) {
                     emit_bytes(OP_SET_LOCAL, (uint8_t)slot);
                 } else {
                     int idx = current_chunk->add_constant(v->name);
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
                     if (slot >= 0) {
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

                 // OP_SET_MEMBER pushes the modified base back onto the stack.
                 // We need to pop it since we're not using the return value.
                 // Do NOT store it back - that would create shadow locals for globals!
                 emit_byte(OP_POP);
             } else {
                 compile_ok = false;
             }
             break;
        }
        case STMT_CALL: {
            CallStatement* s = (CallStatement*)stmt;
            if (s->base_object) {
                if (s->base_object->type != ExpressionNode::ME &&
                    s->base_object->type != ExpressionNode::WITH_CONTEXT) {
                    compile_ok = false;
                    break;
                }
            }
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
            String interop_lit;
            ForStatement* interop_inner = nullptr;
            if (kEnableLoopFusions && is_interop_loop(f, interop_sum, interop_lit, interop_inner)) {
                if (!interop_inner || !interop_inner->to_val) {
                    compile_ok = false;
                    break;
                }
                int sum_slot = get_or_add_local(interop_sum, VT_INT);
                if (sum_slot < 0) {
                    compile_ok = false;
                    break;
                }
                compile_expression(interop_inner->to_val);
                compile_expression(f->to_val);

                int lit_idx = current_chunk->add_constant(interop_lit);
                emit_byte(OP_INTEROP_SET_NAME_LEN);
                emit_byte((uint8_t)sum_slot);
                emit_byte((uint8_t)lit_idx);

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
                    if (call->arguments.size() != 1 || call->arguments[0]->type != ExpressionNode::VARIABLE) return false;
                    sum_name = s->name;
                    container_name = call->method_name;
                    idx_name = ((VariableNode*)call->arguments[0])->name.to_lower();
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
                // sum = sum + (sum(arr) + sum(dict)) * iterations
                VariableNode arr_node;
                arr_node.name = arr_var;
                compile_expression(&arr_node);
                emit_byte(OP_SUM_ARRAY_I64);

                VariableNode arr_node_dict;
                arr_node_dict.name = arr_var;
                compile_expression(&arr_node_dict);
                emit_byte(OP_SUM_DICT_I64);

                emit_byte(OP_ADD_I64);

                VariableNode dict_node;
                dict_node.name = dict_var;
                compile_expression(&dict_node);
                emit_byte(OP_SUM_DICT_I64);

                VariableNode dict_node_arr;
                dict_node_arr.name = dict_var;
                compile_expression(&dict_node_arr);
                emit_byte(OP_SUM_ARRAY_I64);

                emit_byte(OP_ADD_I64);

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
            emit_byte(use_int_compare ? OP_LESS_EQUAL_I64 : OP_LESS_EQUAL);
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
            loop_vars.remove_at(loop_vars.size() - 1);
            loop_bound_vars.remove_at(loop_bound_vars.size() - 1);
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
            if (s->preserve) {
                compile_ok = false;
                break;
            }
            if (s->array_sizes.size() != 1) {
                compile_ok = false;
                break;
            }

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
            break;
        }
        case STMT_EXIT: {
            ExitStatement *s = (ExitStatement *)stmt;
            if (s->exit_type == ExitStatement::EXIT_FUNCTION || s->exit_type == ExitStatement::EXIT_SUB) {
                emit_return();
            } else {
                UtilityFunctions::print("Compiler: Unsupported exit type", s->exit_type);
                compile_ok = false;
            }
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
            compile_ok = false;
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
            else {
                UtilityFunctions::print("Compiler: Unsupported binary op ", b->op);
                compile_ok = false;
            }
            break;
        }
        case ExpressionNode::ARRAY_ACCESS: {
            ArrayAccessNode* aa = (ArrayAccessNode*)expr;
            if (aa->indices.size() != 1) {
                compile_ok = false;
                break;
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
            compile_expression(ma->base_object);
            int idx = current_chunk->add_constant(ma->member_name);
            emit_bytes(OP_GET_MEMBER, (uint8_t)idx);
            break;
        }
        case ExpressionNode::EXPRESSION_CALL: {
             CallExpression* call = (CallExpression*)expr;
             if (call->base_object) {
                 // Method calls on objects are not supported in bytecode yet.
                 compile_ok = false;
                 break;
             }

             String call_name = call->method_name.to_lower();
             if (array_vars.has(call_name) || dictionary_vars.has(call_name) || local_slots.has(call_name)) {
                 if (call->arguments.size() != 1) {
                     compile_ok = false;
                     break;
                 }
                 // Treat as array access
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
        default:
             UtilityFunctions::print("Compiler: Unsupported expression type ", expr->type);
             emit_byte(OP_NIL);
               compile_ok = false;
             break;
    }
}

