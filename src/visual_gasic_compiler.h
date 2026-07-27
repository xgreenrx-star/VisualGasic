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

    bool compile(ModuleNode* module, const String& entry_point, BytecodeChunk* chunk);

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
    SubDefinition* current_sub = nullptr;
    ModuleNode* current_module = nullptr;

    void emit_byte(uint8_t byte);
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
    bool is_simple_arith_loop(ForStatement* f, String &sum_var, int64_t &k, int64_t &c) const;
    bool is_nested_branch_loop(ForStatement* outer, String &sum_var, String &flag_var) const;
    bool is_nested_string_concat(ForStatement* outer, String &target_name, String &literal_value, ForStatement* &inner_out) const;
    bool is_nested_dict_keys_sum(ForStatement* outer, String &sum_var, String &dict_var, String &keys_var, String &iter_var) const;
    bool is_nested_dict_keys_set_sum(ForStatement* outer, String &sum_var, String &dict_var, String &keys_var, String &iter_var) const;
    bool is_constant_expr(ExpressionNode* expr) const;
    Variant eval_constant_expr(ExpressionNode* expr) const;
    ValueType infer_type(ExpressionNode* expr) const;

    void compile_statement(Statement* stmt);
    void compile_expression(ExpressionNode* expr);

    // M6: Try to compile a Select Case as a dense O(1) jump table.
    // Returns true if successful (and emits bytecode), false if fallback needed.
    bool try_compile_jump_table(SelectStatement* s);

    // Pass 2: namespace dispatch. If base_obj is the bare identifier
    // "Camera"/"Sound"/"Bus" (not shadowed by a local/param/array/dict),
    // returns the lowercase namespace name; otherwise returns "".
    String detect_namespace_call(ExpressionNode* base_obj) const;
};

#endif
