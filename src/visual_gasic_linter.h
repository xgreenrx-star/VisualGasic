#ifndef VISUAL_GASIC_LINTER_H
#define VISUAL_GASIC_LINTER_H

#include "visual_gasic_ast.h"
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/templates/hash_set.hpp>

using namespace godot;
using namespace VisualGasic;

// VisualGasic Static Analyzer & Linter
// Provides warnings for common code issues without modifying the AST
class VisualGasicLinter {
public:
    struct Warning {
        int line;
        int column;
        String message;
        int code; // Warning code for categorization
    };

    // Warning codes
    enum WarningCode {
        WARN_UNUSED_VARIABLE = 100,
        WARN_UNUSED_SUB = 101,
        WARN_EMPTY_SUB = 102,
        WARN_SHADOWED_VARIABLE = 103,
        WARN_UNREACHABLE_CODE = 104,
        WARN_EMPTY_IF = 105,
        WARN_UNUSED_PARAMETER = 106,
        WARN_INTEGER_DIVISION = 107,
        WARN_RETURN_IN_SUB = 108,
    };

    Array analyze(const ModuleNode* root);

private:
    Vector<Warning> warnings;

    // Collected identifiers
    HashSet<String> global_var_names;
    HashSet<String> const_names;
    HashSet<String> sub_names;
    HashSet<String> class_names;
    HashSet<String> enum_names;
    HashSet<String> struct_names;

    // Names referenced in code (lower-cased for case-insensitive matching)
    HashSet<String> referenced_names;

    // Special built-in sub names that should never be flagged as unused
    bool is_builtin_sub(const String& name) const;

    // Phase 1: Collect all definitions
    void collect_definitions(const ModuleNode* root);

    // Phase 2: Collect all references from expressions and statements
    void collect_references_from_statements(const Vector<Statement*>& stmts);
    void collect_references_from_expression(const ExpressionNode* expr);

    // Phase 3: Check for issues
    void check_unused_variables(const ModuleNode* root);
    void check_unused_subs(const ModuleNode* root);
    void check_empty_subs(const ModuleNode* root);
    void check_shadowed_variables(const ModuleNode* root);
    void check_unreachable_code(const ModuleNode* root);
    void check_empty_if_branches(const Vector<Statement*>& stmts, const String& context);
    void check_unused_parameters(const ModuleNode* root);

    // Helpers
    void add_warning(int line, const String& message, int code);
    void scan_statement_block_for_refs(const Vector<Statement*>& stmts);
    int find_line_for_sub(const SubDefinition* sub) const;
    void collect_local_refs(const Statement* stmt, HashSet<String>& refs);
    void collect_expr_refs(const ExpressionNode* expr, HashSet<String>& refs);
};

#endif // VISUAL_GASIC_LINTER_H
