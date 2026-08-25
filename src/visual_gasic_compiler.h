#ifndef VISUAL_GASIC_COMPILER_H
#define VISUAL_GASIC_COMPILER_H

#include "visual_gasic_bytecode.h"
#include "visual_gasic_ast.h"
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/templates/hash_set.hpp>
#include <godot_cpp/templates/vector.hpp>

using namespace VisualGasic;
using namespace godot;

class VisualGasicCompiler {
public:
    enum ValueType {
        VT_UNKNOWN = 0,
        VT_INT,
        VT_FLOAT
    };

    VisualGasicCompiler();
    ~VisualGasicCompiler();

    // extra_buffer_vars: optional set of lowercased variable names (gathered by the
    // caller across ALL modules of the running instance, e.g. via collect_buffer_var_names())
    // that are known to hold MemoryBuffer objects. Needed because a module-level global can be
    // assigned its MemoryBuffer identity in one module (e.g. a shared "memory" module's Init sub)
    // while being indexed from Subs compiled out of a completely different imported module — a
    // purely intra-module AST scan can never see across that boundary.
    bool compile(ModuleNode* module, const String& entry_point, BytecodeChunk* chunk, const HashSet<String>* extra_buffer_vars = nullptr);

    // Static utility: recursively scans a single module's Subs for "X = New MemoryBuffer(...)"
    // / "Set X = New MemoryBuffer(...)" assignments, inserting lowercased names into `out`.
    // Exposed so callers (e.g. VisualGasicInstance) can pre-compute a cross-module buffer-var
    // name set to pass into compile() via extra_buffer_vars.
    static void scan_module_for_buffer_vars(ModuleNode* module, HashSet<String>& out);
    static void scan_stmt_for_buffer_vars(Statement* stmt, HashSet<String>& out);

private:
    BytecodeChunk* current_chunk;
    int current_line;
    bool compile_ok;

    HashMap<String, int> local_slots;
    HashMap<String, ValueType> local_types;
    HashMap<String, Variant> local_const_map;  // Procedure-scoped Const name → inlined value
    HashSet<String> array_vars;
    HashSet<String> param_vars;  // Parameter names — needed for array-access disambiguation
    HashSet<String> dictionary_vars;
    HashSet<String> trusted_dictionary_vars;
    HashSet<String> sole_owner_dict_vars;  // Dicts proven to have sole ownership → use VGFastStringDict
    HashSet<String> buffer_vars;        // (M5) Variables declared As New MemoryBuffer → use Buffer opcodes
    HashMap<String, ValueType> array_types;
    HashMap<String, String> array_bound_vars;
    HashSet<String> typed_locals;
    HashSet<String> non_local_names;
    HashSet<String> used_vars;
    HashMap<String, int> expr_cache;
    Vector<String> loop_vars;
    Vector<String> loop_bound_vars;
    // Stack of pending exit-jump addresses for Exit For / Exit Do.
    // Each entry is a list of jump offsets that must be patched to
    // point past the enclosing loop once it finishes compiling.
    Vector<Vector<int>> loop_exit_jumps;
    // Stack of bytecode offsets where Continue should jump to (the
    // increment/re-test point of each enclosing loop).
    Vector<int> loop_continue_targets;
    // Stack of forward-jump addresses emitted by Continue when the
    // target is not yet known (body compiled before increment).
    Vector<Vector<int>> loop_continue_forward_jumps;
    // GoTo label support: label_name → bytecode offset (filled in first pass)
    HashMap<String, int> label_positions;
    // Forward GoTo jumps that need patching: label_name → list of jump offsets
    HashMap<String, Vector<int>> goto_forward_jumps;
    int temp_local_id = 0;
    int pending_vector_draw_skip = 0;
    int _draw_invariant_color_slot = -1;
    SubDefinition* current_sub = nullptr;
    ModuleNode* current_module = nullptr;

    void emit_byte(uint8_t byte);
    void emit_f32(float p_value);
    void emit_i32(int32_t p_value);
    void emit_bytes(uint8_t byte1, uint8_t byte2);
    void emit_const_index(int idx);  // 2-byte LE constant pool index
    void emit_constant(const Variant& value);
    void emit_return();
    int emit_jump(uint8_t op);
    void patch_jump(int offset_pos);
    void emit_loop(int loop_start);

    int get_or_add_local(const String &name, ValueType type);
    ValueType get_local_type(const String &name) const;
    uint8_t to_local_type(ValueType type) const;

    void collect_locals(Statement* stmt);
    void collect_used_vars_stmt(Statement* stmt);
    void collect_used_vars_expr(ExpressionNode* expr);
    void collect_used_vars_assignment_target(ExpressionNode* target);
    void collect_vars_in_expr(ExpressionNode* expr, HashSet<String> &out) const;
    void collect_assigned_vars_stmt(Statement* stmt, HashSet<String> &out) const;

    bool is_pure_expr(ExpressionNode* expr) const;
    bool is_fast_array_var(const String &name) const;
    bool is_dictionary_var(const String &name) const;
    bool is_trusted_dictionary_var(const String &name) const;
    bool is_sole_owner_dict_var(const String &name) const;
    bool is_buffer_var(const String &name) const;
    void _check_dict_escapes(Statement* stmt, HashSet<String> &escaped) const;
    void _check_expr_escapes(ExpressionNode* expr, HashSet<String> &escaped) const;
    String extract_bound_var(ExpressionNode* expr) const;
    bool is_loop_string_concat(ForStatement* f, String &target_name, String &literal_value) const;
    bool is_loop_array_fill(ForStatement* f, String &arr_var) const;
    bool is_allocations_loop(ForStatement* f, String &sum_var, String &arr_var, String &tmp_var, String &literal_value, String &iter_var, String &size_var) const;
    bool is_interop_loop(ForStatement* outer, String &sum_var, String &literal_value, ForStatement* &inner_out) const;
    bool is_nested_array_dict_sum(ForStatement* outer, String &sum_var, String &arr_var, String &dict_var, String &iter_var) const;
    bool is_nested_array_sum(ForStatement* outer, String &sum_var, String &arr_var, String &iter_var) const;
    bool is_nested_arith_loop(ForStatement* outer, String &sum_var, int64_t &k, int64_t &c) const;
    bool is_nested_inc_loop(ForStatement *outer, String &r_var, int64_t &r_delta) const;
    bool is_simple_arith_loop(ForStatement* f, String &sum_var, int64_t &k, int64_t &c) const;
    bool is_nested_branch_loop(ForStatement* outer, String &sum_var, String &flag_var) const;
    bool is_nested_string_concat(ForStatement* outer, String &target_name, String &literal_value, ForStatement* &inner_out) const;
    bool is_nested_dict_keys_sum(ForStatement* outer, String &sum_var, String &dict_var, String &keys_var, String &iter_var) const;
    bool is_nested_dict_keys_set_sum(ForStatement* outer, String &sum_var, String &dict_var, String &keys_var, String &iter_var) const;
    bool is_constant_expr(ExpressionNode* expr) const;
    Variant eval_constant_expr(ExpressionNode* expr) const;
    bool try_constant_f64(ExpressionNode* expr, double &r_out) const;
    bool try_constant_bool(ExpressionNode* expr, bool &r_out) const;
    bool try_constant_color(ExpressionNode* expr, Color &r_out) const;
    bool try_find_invariant_draw_color(const Vector<Statement*> &body, Variant &r_color) const;
    bool try_emit_draw_rect_f64(const Vector<ExpressionNode*> &args);
    bool try_emit_draw_line_f64(const Vector<ExpressionNode*> &args);
    bool try_emit_draw_circle_f64(const Vector<ExpressionNode*> &args);
    bool try_emit_draw_texture_rect_f64(const Vector<ExpressionNode*> &args);
    bool try_emit_draw_call(CallStatement *s, SubDefinition *target_func, bool discard_result);
    SubDefinition *find_sub_by_name(const String &p_name) const;
    bool try_get_module_grid_constants(int64_t &r_cols, int64_t &r_cell) const;
    bool try_parse_grid_axis_sub(const String &p_name, bool p_want_x, int64_t &r_cols, int64_t &r_cell) const;
    bool try_emit_grid_axis_inline(const String &p_func_name, const Vector<ExpressionNode*> &args, bool p_want_x);
    bool is_scalar_fast_param_sub(SubDefinition *sub) const;
    bool try_parse_trivial_i64_call_delta(SubDefinition *sub, int64_t &r_delta) const;
    bool try_emit_inline_trivial_user_call(CallExpression *call, SubDefinition *target);
    bool try_compile_grid_draw_fusion(const Vector<Statement*> &stmts, int &io_i, const String &p_loop_var);
    bool try_const_i64_from_expr(ExpressionNode *p_expr, int64_t &r_out) const;
    bool is_grid_axis_assign(Statement *p_stmt, const String &p_axis_name, const String &p_loop_var,
            String &r_x_var, String &r_y_var, bool p_want_x) const;
    bool try_compile_grid_draw_for_fusion(ForStatement *p_for);
    bool try_compile_grid_polyline_for_fusion(ForStatement *p_for);
    bool try_compile_offset_rect_for_fusion(ForStatement *p_for);
    bool try_compile_vector_uniform_rect_for_fusion(ForStatement *p_for, const Vector<Statement*> &p_stmts, int p_index, int &r_skip_after);
    bool parse_checksum_tail(ExpressionNode *p_expr, int64_t &r_add) const;
    bool parse_grid_checksum_stmt(Statement *p_stmt, String &r_cs_var, const String &p_x_var,
            const String &p_y_var, int64_t &r_add) const;
    ValueType infer_type(ExpressionNode* expr) const;

    void compile_statement(Statement* stmt);
    void compile_expression(ExpressionNode* expr);

    // ByRef write-back (v6.2): after an OP_CALL to target_func, emit
    // OP_BYREF_LOAD + OP_SET_LOCAL/OP_SET_GLOBAL for every ByRef parameter that
    // is bound to a simple variable argument, so the caller's variable receives
    // the callee's post-call value. This lets Subs that make ByRef calls compile
    // to bytecode instead of falling back to the AST interpreter. Net-zero stack
    // effect per param (push captured value, then store pops it), so it is safe
    // to emit in both statement and expression call contexts.
    void emit_byref_writebacks(SubDefinition* target_func, const Vector<ExpressionNode*>& arguments);

    // M6: Try to compile a Select Case as a dense O(1) jump table.
    // Returns true if successful (and emits bytecode), false if fallback needed.
    bool try_compile_jump_table(SelectStatement* s);

    // Pass 2: namespace dispatch. If base_obj is the bare identifier
    // "Camera"/"Sound"/"Bus" (not shadowed by a local/param/array/dict),
    // returns the lowercase namespace name; otherwise returns "".
    String detect_namespace_call(ExpressionNode* base_obj) const;
};

#endif
