#include "visual_gasic_linter.h"

using namespace godot;
using namespace VisualGasic;

// ────────────────────────────────────────────────────────────────────────────
// Public entry point
// ────────────────────────────────────────────────────────────────────────────

Array VisualGasicLinter::analyze(const ModuleNode* root) {
    warnings.clear();
    global_var_names.clear();
    const_names.clear();
    sub_names.clear();
    class_names.clear();
    enum_names.clear();
    struct_names.clear();
    referenced_names.clear();

    if (!root) return Array();

    // Phase 1: Collect all top-level definitions
    collect_definitions(root);

    // Phase 2: Collect all references (what's actually used)
    for (int i = 0; i < root->subs.size(); i++) {
        const SubDefinition* sub = root->subs[i];
        collect_references_from_statements(sub->statements);
    }
    // Also scan global statements (DATA, labels, etc.)
    collect_references_from_statements(root->global_statements);
    // Scan class methods
    for (int i = 0; i < root->class_defs.size(); i++) {
        const ClassDefinition* cls = root->class_defs[i];
        for (int j = 0; j < cls->methods.size(); j++) {
            collect_references_from_statements(cls->methods[j]->statements);
        }
        if (cls->class_initialize) {
            collect_references_from_statements(cls->class_initialize->statements);
        }
        if (cls->class_terminate) {
            collect_references_from_statements(cls->class_terminate->statements);
        }
        // Scan property bodies
        for (int j = 0; j < cls->properties.size(); j++) {
            collect_references_from_statements(cls->properties[j]->body);
        }
    }
    // Scan module-level properties
    for (int i = 0; i < root->properties.size(); i++) {
        collect_references_from_statements(root->properties[i]->body);
    }

    // Phase 3: Run checks
    check_unused_variables(root);
    check_unused_subs(root);
    check_empty_subs(root);
    check_shadowed_variables(root);
    check_unreachable_code(root);
    check_unused_parameters(root);

    // Convert to Godot Array of Dictionaries
    Array result;
    for (int i = 0; i < warnings.size(); i++) {
        Dictionary w;
        w["start_line"] = warnings[i].line;
        w["end_line"] = warnings[i].line;
        w["leftmost_column"] = warnings[i].column;
        w["rightmost_column"] = warnings[i].column;
        w["message"] = warnings[i].message;
        w["code"] = warnings[i].code;
        w["string_code"] = warnings[i].code;
        w["severity"] = 1; // WARNING
        result.push_back(w);
    }
    return result;
}

// ────────────────────────────────────────────────────────────────────────────
// Phase 1: Collect definitions
// ────────────────────────────────────────────────────────────────────────────

void VisualGasicLinter::collect_definitions(const ModuleNode* root) {
    // Global variables
    for (int i = 0; i < root->variables.size(); i++) {
        global_var_names.insert(root->variables[i]->name.to_lower());
    }

    // Constants
    for (int i = 0; i < root->constants.size(); i++) {
        const_names.insert(root->constants[i]->name.to_lower());
    }

    // Subs/Functions
    for (int i = 0; i < root->subs.size(); i++) {
        sub_names.insert(root->subs[i]->name.to_lower());
    }

    // Classes
    for (int i = 0; i < root->class_defs.size(); i++) {
        class_names.insert(root->class_defs[i]->name.to_lower());
    }

    // Enums
    for (int i = 0; i < root->enums.size(); i++) {
        enum_names.insert(root->enums[i]->name.to_lower());
    }

    // Structs
    for (int i = 0; i < root->structs.size(); i++) {
        struct_names.insert(root->structs[i]->name.to_lower());
    }
}

// ────────────────────────────────────────────────────────────────────────────
// Phase 2: Collect references
// ────────────────────────────────────────────────────────────────────────────

void VisualGasicLinter::collect_references_from_expression(const ExpressionNode* expr) {
    if (!expr) return;

    switch (expr->type) {
        case ExpressionNode::VARIABLE: {
            const VariableNode* var = static_cast<const VariableNode*>(expr);
            referenced_names.insert(var->name.to_lower());
            break;
        }
        case ExpressionNode::EXPRESSION_CALL: {
            const CallExpression* call = static_cast<const CallExpression*>(expr);
            referenced_names.insert(call->method_name.to_lower());
            if (call->base_object) {
                collect_references_from_expression(call->base_object);
            }
            for (int i = 0; i < call->arguments.size(); i++) {
                collect_references_from_expression(call->arguments[i]);
            }
            break;
        }
        case ExpressionNode::BINARY_OP: {
            const BinaryOpNode* bin = static_cast<const BinaryOpNode*>(expr);
            collect_references_from_expression(bin->left);
            collect_references_from_expression(bin->right);
            break;
        }
        case ExpressionNode::UNARY_OP: {
            const UnaryOpNode* un = static_cast<const UnaryOpNode*>(expr);
            collect_references_from_expression(un->operand);
            break;
        }
        case ExpressionNode::MEMBER_ACCESS: {
            const MemberAccessNode* mem = static_cast<const MemberAccessNode*>(expr);
            collect_references_from_expression(mem->base_object);
            // Don't add member_name as a top-level reference
            break;
        }
        case ExpressionNode::ARRAY_ACCESS: {
            const ArrayAccessNode* arr = static_cast<const ArrayAccessNode*>(expr);
            collect_references_from_expression(arr->base);
            for (int i = 0; i < arr->indices.size(); i++) {
                collect_references_from_expression(arr->indices[i]);
            }
            break;
        }
        case ExpressionNode::EXPRESSION_IIF: {
            const IIfNode* iif = static_cast<const IIfNode*>(expr);
            collect_references_from_expression(iif->condition);
            collect_references_from_expression(iif->true_part);
            collect_references_from_expression(iif->false_part);
            break;
        }
        case ExpressionNode::NEW: {
            const NewNode* nn = static_cast<const NewNode*>(expr);
            referenced_names.insert(nn->class_name.to_lower());
            for (int i = 0; i < nn->args.size(); i++) {
                collect_references_from_expression(nn->args[i]);
            }
            break;
        }
        case ExpressionNode::LAMBDA: {
            const LambdaNode* lam = static_cast<const LambdaNode*>(expr);
            collect_references_from_expression(lam->body_expression);
            // Block lambda
            collect_references_from_statements(lam->body_statements);
            break;
        }
        default:
            break;
    }
}

void VisualGasicLinter::collect_references_from_statements(const Vector<Statement*>& stmts) {
    for (int i = 0; i < stmts.size(); i++) {
        const Statement* stmt = stmts[i];
        if (!stmt) continue;

        switch (stmt->type) {
            case STMT_DIM: {
                const DimStatement* dim = static_cast<const DimStatement*>(stmt);
                if (dim->initializer) {
                    collect_references_from_expression(dim->initializer);
                }
                for (int j = 0; j < dim->array_sizes.size(); j++) {
                    collect_references_from_expression(dim->array_sizes[j]);
                }
                break;
            }
            case STMT_ASSIGNMENT: {
                const AssignmentStatement* assign = static_cast<const AssignmentStatement*>(stmt);
                collect_references_from_expression(assign->target);
                collect_references_from_expression(assign->value);
                break;
            }
            case STMT_PRINT: {
                const PrintStatement* pr = static_cast<const PrintStatement*>(stmt);
                collect_references_from_expression(pr->expression);
                if (pr->file_number) collect_references_from_expression(pr->file_number);
                break;
            }
            case STMT_IF: {
                const IfStatement* ifs = static_cast<const IfStatement*>(stmt);
                collect_references_from_expression(ifs->condition);
                collect_references_from_statements(ifs->then_branch);
                collect_references_from_statements(ifs->else_branch);
                break;
            }
            case STMT_FOR: {
                const ForStatement* fs = static_cast<const ForStatement*>(stmt);
                referenced_names.insert(fs->variable_name.to_lower());
                collect_references_from_expression(fs->from_val);
                collect_references_from_expression(fs->to_val);
                if (fs->step_val) collect_references_from_expression(fs->step_val);
                collect_references_from_statements(fs->body);
                break;
            }
            case STMT_FOR_EACH: {
                const ForEachStatement* fe = static_cast<const ForEachStatement*>(stmt);
                referenced_names.insert(fe->variable_name.to_lower());
                collect_references_from_expression(fe->collection);
                collect_references_from_statements(fe->body);
                break;
            }
            case STMT_WHILE: {
                const WhileStatement* ws = static_cast<const WhileStatement*>(stmt);
                collect_references_from_expression(ws->condition);
                collect_references_from_statements(ws->body);
                break;
            }
            case STMT_DO: {
                const DoStatement* ds = static_cast<const DoStatement*>(stmt);
                if (ds->condition) collect_references_from_expression(ds->condition);
                collect_references_from_statements(ds->body);
                break;
            }
            case STMT_OSCILLATE: {
                const OscillateStatement* os = static_cast<const OscillateStatement*>(stmt);
                referenced_names.insert(os->variable_name.to_lower());
                collect_references_from_expression(os->from_val);
                collect_references_from_expression(os->to_val);
                if (os->step_val) collect_references_from_expression(os->step_val);
                if (os->cycles_val) collect_references_from_expression(os->cycles_val);
                collect_references_from_statements(os->body);
                break;
            }
            case STMT_CALL: {
                const CallStatement* cs = static_cast<const CallStatement*>(stmt);
                referenced_names.insert(cs->method_name.to_lower());
                if (cs->base_object) collect_references_from_expression(cs->base_object);
                for (int j = 0; j < cs->arguments.size(); j++) {
                    collect_references_from_expression(cs->arguments[j]);
                }
                break;
            }
            case STMT_SELECT: {
                const SelectStatement* sel = static_cast<const SelectStatement*>(stmt);
                collect_references_from_expression(sel->expression);
                for (int j = 0; j < sel->cases.size(); j++) {
                    const CaseBlock* cb = sel->cases[j];
                    for (int k = 0; k < cb->values.size(); k++) {
                        collect_references_from_expression(cb->values[k]);
                    }
                    collect_references_from_statements(cb->body);
                }
                break;
            }
            case STMT_RETURN: {
                const ReturnStatement* rs = static_cast<const ReturnStatement*>(stmt);
                if (rs->return_value) collect_references_from_expression(rs->return_value);
                break;
            }
            case STMT_WITH: {
                const WithStatement* ws = static_cast<const WithStatement*>(stmt);
                collect_references_from_expression(ws->expression);
                collect_references_from_statements(ws->body);
                break;
            }
            case STMT_RAISE_EVENT: {
                const RaiseEventStatement* re = static_cast<const RaiseEventStatement*>(stmt);
                referenced_names.insert(re->expression_name.to_lower());
                for (int j = 0; j < re->arguments.size(); j++) {
                    collect_references_from_expression(re->arguments[j]);
                }
                break;
            }
            case STMT_TRY: {
                const TryStatement* ts = static_cast<const TryStatement*>(stmt);
                collect_references_from_statements(ts->try_block);
                collect_references_from_statements(ts->catch_block);
                collect_references_from_statements(ts->finally_block);
                break;
            }
            case STMT_PARALLEL_FOR: {
                const ParallelForStatement* pf = static_cast<const ParallelForStatement*>(stmt);
                referenced_names.insert(pf->variable_name.to_lower());
                collect_references_from_expression(pf->start_expr);
                collect_references_from_expression(pf->end_expr);
                if (pf->step_expr) collect_references_from_expression(pf->step_expr);
                collect_references_from_statements(pf->body);
                break;
            }
            case STMT_READ: {
                const ReadStatement* rd = static_cast<const ReadStatement*>(stmt);
                for (int j = 0; j < rd->targets.size(); j++) {
                    collect_references_from_expression(rd->targets[j]);
                }
                break;
            }
            case STMT_RESTORE: {
                // Label reference
                const RestoreStatement* rs = static_cast<const RestoreStatement*>(stmt);
                if (!rs->label_name.is_empty()) {
                    referenced_names.insert(rs->label_name.to_lower());
                }
                break;
            }
            case STMT_GOTO: {
                const GotoStatement* gs = static_cast<const GotoStatement*>(stmt);
                referenced_names.insert(gs->label_name.to_lower());
                break;
            }
            case STMT_REDIM: {
                const ReDimStatement* rd = static_cast<const ReDimStatement*>(stmt);
                referenced_names.insert(rd->variable_name.to_lower());
                for (int j = 0; j < rd->array_sizes.size(); j++) {
                    collect_references_from_expression(rd->array_sizes[j]);
                }
                break;
            }
            case STMT_OPEN: {
                const OpenStatement* os = static_cast<const OpenStatement*>(stmt);
                collect_references_from_expression(os->path);
                if (os->file_number) collect_references_from_expression(os->file_number);
                break;
            }
            case STMT_CLOSE: {
                const CloseStatement* cs = static_cast<const CloseStatement*>(stmt);
                if (cs->file_number) collect_references_from_expression(cs->file_number);
                break;
            }
            case STMT_INPUT: {
                const InputStatement* is = static_cast<const InputStatement*>(stmt);
                if (is->file_number) collect_references_from_expression(is->file_number);
                for (int j = 0; j < is->variables.size(); j++) {
                    collect_references_from_expression(is->variables[j]);
                }
                break;
            }
            case STMT_WRITE: {
                const WriteStatement* ws = static_cast<const WriteStatement*>(stmt);
                if (ws->file_number) collect_references_from_expression(ws->file_number);
                for (int j = 0; j < ws->expressions.size(); j++) {
                    collect_references_from_expression(ws->expressions[j]);
                }
                break;
            }
            case STMT_WHENEVER_SECTION: {
                const WheneverSectionStatement* ws = static_cast<const WheneverSectionStatement*>(stmt);
                if (ws->condition_expression) collect_references_from_expression(ws->condition_expression);
                if (ws->comparison_value) collect_references_from_expression(ws->comparison_value);
                if (ws->comparison_value2) collect_references_from_expression(ws->comparison_value2);
                if (!ws->variable_name.is_empty()) referenced_names.insert(ws->variable_name.to_lower());
                for (int j = 0; j < ws->callback_procedures.size(); j++) {
                    referenced_names.insert(ws->callback_procedures[j].to_lower());
                }
                break;
            }
            case STMT_SUSPEND_WHENEVER: {
                const SuspendWheneverStatement* sw = static_cast<const SuspendWheneverStatement*>(stmt);
                referenced_names.insert(sw->section_name.to_lower());
                break;
            }
            case STMT_RESUME_WHENEVER: {
                const ResumeWheneverStatement* rw = static_cast<const ResumeWheneverStatement*>(stmt);
                referenced_names.insert(rw->section_name.to_lower());
                break;
            }
            default:
                break;
        }
    }
}

// ────────────────────────────────────────────────────────────────────────────
// Phase 3: Checks
// ────────────────────────────────────────────────────────────────────────────

void VisualGasicLinter::check_unused_variables(const ModuleNode* root) {
    for (int i = 0; i < root->variables.size(); i++) {
        const VariableDefinition* var = root->variables[i];
        String lower = var->name.to_lower();
        if (!referenced_names.has(lower)) {
            // Don't warn for variables that start with _ (convention for intentionally unused)
            if (!var->name.begins_with("_")) {
                add_warning(0, "Unused variable '" + var->name + "' is declared but never referenced.", WARN_UNUSED_VARIABLE);
            }
        }
    }
}

void VisualGasicLinter::check_unused_subs(const ModuleNode* root) {
    for (int i = 0; i < root->subs.size(); i++) {
        const SubDefinition* sub = root->subs[i];
        String lower = sub->name.to_lower();

        // Skip built-in lifecycle methods
        if (is_builtin_sub(lower)) continue;

        if (!referenced_names.has(lower)) {
            int line = find_line_for_sub(sub);
            add_warning(line, "Sub/Function '" + sub->name + "' is declared but never called.", WARN_UNUSED_SUB);
        }
    }
}

void VisualGasicLinter::check_empty_subs(const ModuleNode* root) {
    for (int i = 0; i < root->subs.size(); i++) {
        const SubDefinition* sub = root->subs[i];
        if (sub->statements.size() == 0) {
            // Skip Class_Initialize / Class_Terminate (often intentionally empty)
            String lower = sub->name.to_lower();
            if (lower == "class_initialize" || lower == "class_terminate") continue;
            
            int line = find_line_for_sub(sub);
            add_warning(line, "Sub/Function '" + sub->name + "' has an empty body.", WARN_EMPTY_SUB);
        }
    }
}

void VisualGasicLinter::check_shadowed_variables(const ModuleNode* root) {
    for (int i = 0; i < root->subs.size(); i++) {
        const SubDefinition* sub = root->subs[i];
        for (int j = 0; j < sub->statements.size(); j++) {
            const Statement* stmt = sub->statements[j];
            if (stmt->type == STMT_DIM) {
                const DimStatement* dim = static_cast<const DimStatement*>(stmt);
                String lower = dim->variable_name.to_lower();
                if (global_var_names.has(lower)) {
                    add_warning(stmt->line, "Local variable '" + dim->variable_name + "' shadows a module-level variable with the same name.", WARN_SHADOWED_VARIABLE);
                }
            }
        }
    }
}

void VisualGasicLinter::check_unreachable_code(const ModuleNode* root) {
    for (int i = 0; i < root->subs.size(); i++) {
        const SubDefinition* sub = root->subs[i];
        const Vector<Statement*>& stmts = sub->statements;

        for (int j = 0; j < stmts.size() - 1; j++) {
            const Statement* stmt = stmts[j];
            bool is_terminal = false;

            // Check for terminal statements
            if (stmt->type == STMT_EXIT) {
                const ExitStatement* ex = static_cast<const ExitStatement*>(stmt);
                if (ex->exit_type == ExitStatement::EXIT_SUB || ex->exit_type == ExitStatement::EXIT_FUNCTION) {
                    is_terminal = true;
                }
            } else if (stmt->type == STMT_RETURN) {
                is_terminal = true;
            } else if (stmt->type == STMT_GOTO) {
                is_terminal = true;
            }

            if (is_terminal) {
                // Next statement is unreachable (unless it's a label — GoTo target)
                const Statement* next = stmts[j + 1];
                if (next->type != STMT_LABEL) {
                    add_warning(next->line, "Unreachable code after Exit/Return/GoTo statement.", WARN_UNREACHABLE_CODE);
                    break; // Only warn once per sub
                }
            }
        }
    }
}

void VisualGasicLinter::check_unused_parameters(const ModuleNode* root) {
    for (int i = 0; i < root->subs.size(); i++) {
        const SubDefinition* sub = root->subs[i];
        if (sub->parameters.size() == 0) continue;
        // Skip event handlers (may have unused params by convention)
        if (is_builtin_sub(sub->name.to_lower())) continue;

        // Collect all variable references within this sub
        HashSet<String> local_refs;
        for (int j = 0; j < sub->statements.size(); j++) {
            collect_local_refs(sub->statements[j], local_refs);
        }

        for (int p = 0; p < sub->parameters.size(); p++) {
            String param_lower = sub->parameters[p].name.to_lower();
            if (!local_refs.has(param_lower)) {
                int line = find_line_for_sub(sub);
                add_warning(line, "Parameter '" + sub->parameters[p].name + "' in '" + sub->name + "' is never used.", WARN_UNUSED_PARAMETER);
            }
        }
    }
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

bool VisualGasicLinter::is_builtin_sub(const String& name) const {
    // Godot lifecycle callbacks & VB6 special subs
    return name == "_ready" || name == "_process" || name == "_draw" || name == "_input" ||
           name == "_unhandled_input" || name == "_physics_process" ||
           name == "_enter_tree" || name == "_exit_tree" ||
           name == "_notification" ||
           name == "form_load" || name == "form_unload" ||
           name == "class_initialize" || name == "class_terminate" ||
           name == "main";
}

void VisualGasicLinter::add_warning(int line, const String& message, int code) {
    Warning w;
    w.line = line;
    w.column = 0;
    w.message = message;
    w.code = code;
    warnings.push_back(w);
}

int VisualGasicLinter::find_line_for_sub(const SubDefinition* sub) const {
    // If the sub has statements, use the first statement's line - 1 (approximate)
    if (sub->statements.size() > 0 && sub->statements[0]->line > 0) {
        return sub->statements[0]->line - 1; // Sub declaration is typically 1 line before first stmt
    }
    return 0;
}

// Recursively collect variable references within a statement (for parameter usage checking)
void VisualGasicLinter::collect_local_refs(const Statement* stmt, HashSet<String>& refs) {
    if (!stmt) return;

    switch (stmt->type) {
        case STMT_ASSIGNMENT: {
            const AssignmentStatement* a = static_cast<const AssignmentStatement*>(stmt);
            collect_expr_refs(a->target, refs);
            collect_expr_refs(a->value, refs);
            break;
        }
        case STMT_PRINT: {
            const PrintStatement* p = static_cast<const PrintStatement*>(stmt);
            collect_expr_refs(p->expression, refs);
            break;
        }
        case STMT_IF: {
            const IfStatement* ifs = static_cast<const IfStatement*>(stmt);
            collect_expr_refs(ifs->condition, refs);
            for (int i = 0; i < ifs->then_branch.size(); i++) collect_local_refs(ifs->then_branch[i], refs);
            for (int i = 0; i < ifs->else_branch.size(); i++) collect_local_refs(ifs->else_branch[i], refs);
            break;
        }
        case STMT_FOR: {
            const ForStatement* f = static_cast<const ForStatement*>(stmt);
            refs.insert(f->variable_name.to_lower());
            collect_expr_refs(f->from_val, refs);
            collect_expr_refs(f->to_val, refs);
            if (f->step_val) collect_expr_refs(f->step_val, refs);
            for (int i = 0; i < f->body.size(); i++) collect_local_refs(f->body[i], refs);
            break;
        }
        case STMT_CALL: {
            const CallStatement* c = static_cast<const CallStatement*>(stmt);
            if (c->base_object) collect_expr_refs(c->base_object, refs);
            for (int i = 0; i < c->arguments.size(); i++) collect_expr_refs(c->arguments[i], refs);
            break;
        }
        case STMT_SELECT: {
            const SelectStatement* s = static_cast<const SelectStatement*>(stmt);
            collect_expr_refs(s->expression, refs);
            for (int i = 0; i < s->cases.size(); i++) {
                for (int j = 0; j < s->cases[i]->body.size(); j++) {
                    collect_local_refs(s->cases[i]->body[j], refs);
                }
            }
            break;
        }
        case STMT_DO: {
            const DoStatement* d = static_cast<const DoStatement*>(stmt);
            if (d->condition) collect_expr_refs(d->condition, refs);
            for (int i = 0; i < d->body.size(); i++) collect_local_refs(d->body[i], refs);
            break;
        }
        case STMT_OSCILLATE: {
            const OscillateStatement* os = static_cast<const OscillateStatement*>(stmt);
            refs.insert(os->variable_name.to_lower());
            collect_expr_refs(os->from_val, refs);
            collect_expr_refs(os->to_val, refs);
            if (os->step_val) collect_expr_refs(os->step_val, refs);
            if (os->cycles_val) collect_expr_refs(os->cycles_val, refs);
            for (int i = 0; i < os->body.size(); i++) collect_local_refs(os->body[i], refs);
            break;
        }
        case STMT_WHILE: {
            const WhileStatement* w = static_cast<const WhileStatement*>(stmt);
            collect_expr_refs(w->condition, refs);
            for (int i = 0; i < w->body.size(); i++) collect_local_refs(w->body[i], refs);
            break;
        }
        case STMT_FOR_EACH: {
            const ForEachStatement* fe = static_cast<const ForEachStatement*>(stmt);
            refs.insert(fe->variable_name.to_lower());
            collect_expr_refs(fe->collection, refs);
            for (int i = 0; i < fe->body.size(); i++) collect_local_refs(fe->body[i], refs);
            break;
        }
        case STMT_RETURN: {
            const ReturnStatement* r = static_cast<const ReturnStatement*>(stmt);
            if (r->return_value) collect_expr_refs(r->return_value, refs);
            break;
        }
        case STMT_WITH: {
            const WithStatement* w = static_cast<const WithStatement*>(stmt);
            collect_expr_refs(w->expression, refs);
            for (int i = 0; i < w->body.size(); i++) collect_local_refs(w->body[i], refs);
            break;
        }
        case STMT_TRY: {
            const TryStatement* t = static_cast<const TryStatement*>(stmt);
            for (int i = 0; i < t->try_block.size(); i++) collect_local_refs(t->try_block[i], refs);
            for (int i = 0; i < t->catch_block.size(); i++) collect_local_refs(t->catch_block[i], refs);
            for (int i = 0; i < t->finally_block.size(); i++) collect_local_refs(t->finally_block[i], refs);
            break;
        }
        default:
            break;
    }
}

void VisualGasicLinter::collect_expr_refs(const ExpressionNode* expr, HashSet<String>& refs) {
    if (!expr) return;

    switch (expr->type) {
        case ExpressionNode::VARIABLE: {
            const VariableNode* v = static_cast<const VariableNode*>(expr);
            refs.insert(v->name.to_lower());
            break;
        }
        case ExpressionNode::EXPRESSION_CALL: {
            const CallExpression* c = static_cast<const CallExpression*>(expr);
            if (c->base_object) collect_expr_refs(c->base_object, refs);
            for (int i = 0; i < c->arguments.size(); i++) collect_expr_refs(c->arguments[i], refs);
            break;
        }
        case ExpressionNode::BINARY_OP: {
            const BinaryOpNode* b = static_cast<const BinaryOpNode*>(expr);
            collect_expr_refs(b->left, refs);
            collect_expr_refs(b->right, refs);
            break;
        }
        case ExpressionNode::UNARY_OP: {
            const UnaryOpNode* u = static_cast<const UnaryOpNode*>(expr);
            collect_expr_refs(u->operand, refs);
            break;
        }
        case ExpressionNode::MEMBER_ACCESS: {
            const MemberAccessNode* m = static_cast<const MemberAccessNode*>(expr);
            collect_expr_refs(m->base_object, refs);
            break;
        }
        case ExpressionNode::ARRAY_ACCESS: {
            const ArrayAccessNode* a = static_cast<const ArrayAccessNode*>(expr);
            collect_expr_refs(a->base, refs);
            for (int i = 0; i < a->indices.size(); i++) collect_expr_refs(a->indices[i], refs);
            break;
        }
        case ExpressionNode::EXPRESSION_IIF: {
            const IIfNode* iif = static_cast<const IIfNode*>(expr);
            collect_expr_refs(iif->condition, refs);
            collect_expr_refs(iif->true_part, refs);
            collect_expr_refs(iif->false_part, refs);
            break;
        }
        case ExpressionNode::LAMBDA: {
            const LambdaNode* l = static_cast<const LambdaNode*>(expr);
            collect_expr_refs(l->body_expression, refs);
            for (int i = 0; i < l->body_statements.size(); i++) {
                collect_local_refs(l->body_statements[i], refs);
            }
            break;
        }
        default:
            break;
    }
}
