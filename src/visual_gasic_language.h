#ifndef VISUAL_GASIC_LANGUAGE_H
#define VISUAL_GASIC_LANGUAGE_H

#include <godot_cpp/classes/script_language_extension.hpp>
#include "visual_gasic_script.h"
#include <vector>
#include <map>
#include <set>
#include <mutex>
#include <memory>

using namespace godot;

// Forward declaration
class VisualGasicInstance;

// Call stack frame for debugging (uses std::string to avoid Godot String static init issues)
struct VGDebugStackFrame {
    std::string file;
    std::string function;
    int line;
    VisualGasicInstance* instance;
    
    VGDebugStackFrame() : line(0), instance(nullptr) {}
    VGDebugStackFrame(const std::string& f, const std::string& fn, int l, VisualGasicInstance* i)
        : file(f), function(fn), line(l), instance(i) {}
};

// Step mode for debugging
enum VGStepMode {
    VG_STEP_NONE = 0,      // Not stepping, run freely
    VG_STEP_INTO = 1,      // Break at next line (any depth)
    VG_STEP_OVER = 2,      // Break at next line at same or shallower depth
    VG_STEP_OUT = 3        // Break when returning to shallower depth
};

class VisualGasicLanguage : public ScriptLanguageExtension {
	GDCLASS(VisualGasicLanguage, ScriptLanguageExtension);

    static VisualGasicLanguage *singleton;
    
    // Debug call stack (pointer to avoid static init issues with Godot types)
    static std::vector<VGDebugStackFrame>* debug_call_stack;
    static std::string debug_error;
    
    // Step debugging state (global across all instances)
    static VGStepMode step_mode;
    static int step_target_depth;  // For step over/out: the depth to break at
    static bool waiting_for_continue;  // Flag to control our custom debug wait loop
    
    // Current breakpoint location (set before script_debug blocks)
    static std::string current_break_file;
    static int current_break_line;
    
    // Breakpoints storage (loaded from JSON file, checked in C++ to avoid GDScript call during debug)
    static std::map<std::string, std::vector<int>> breakpoints;
    static bool breakpoints_loaded;
    
    // Data breakpoints (watchpoints) - break when variable value changes
    struct Watchpoint {
        std::string variable_name;
        Variant last_value;
        bool has_value;  // True after first read
    };
    static std::map<std::string, Watchpoint> watchpoints;
    
    // Pause/Break request flag (atomic-safe: only set by editor thread, cleared by script thread)
    static bool break_requested;
    
    // Exception Assistant: break into debugger on unhandled errors (VB6 style)
    static bool break_on_unhandled_error;
    
    // Set Next Statement state
    static bool next_statement_requested;
    static int next_statement_line;
    
    // Edit & Continue state
    static bool edit_and_continue_pending;
    static std::string edit_and_continue_source;
    static std::string edit_and_continue_path;
    
    // Hot Reload infrastructure — track all live scripts for reload-on-save
    static std::set<VisualGasicScript*> live_scripts;
    static std::mutex live_scripts_mutex;
    static std::vector<VisualGasicScript*> pending_reloads;  // Scripts queued for reload on next _frame()
    
    // Helper to ensure debug stack is initialized (lazy initialization)
    static std::vector<VGDebugStackFrame>& get_debug_stack();

protected:
	static void _bind_methods();

public:
    String format_source_code(const String &p_code) const;

    static VisualGasicLanguage *get_singleton();

    VisualGasicLanguage();
    ~VisualGasicLanguage();

    virtual String _get_name() const override;
    virtual void _init() override;
    virtual String _get_type() const override;
    virtual String _get_extension() const override;
    virtual void _finish() override;
    virtual PackedStringArray _get_reserved_words() const override;
    virtual bool _is_control_flow_keyword(const String &p_keyword) const override;
    virtual PackedStringArray _get_comment_delimiters() const override;
    virtual PackedStringArray _get_string_delimiters() const override;
    virtual Ref<Script> _make_template(const String &p_template, const String &p_class_name, const String &p_base_class_name) const override;
    virtual TypedArray<Dictionary> _get_built_in_templates(const StringName &p_object) const override;
    virtual bool _is_using_templates() override;
    virtual Dictionary _validate(const String &p_script, const String &p_path, bool p_validate_functions, bool p_validate_errors, bool p_validate_warnings, bool p_validate_safe_lines) const override;
    virtual String _validate_path(const String &p_path) const override;
    virtual Object *_create_script() const override;
    virtual bool _has_named_classes() const override;
    virtual bool _supports_builtin_mode() const override;
    virtual bool _can_inherit_from_file() const override;
    virtual int32_t _find_function(const String &p_class_name, const String &p_function_name) const override;
    virtual String _make_function(const String &p_class_name, const String &p_function_name, const PackedStringArray &p_function_args) const override;
    virtual Error _open_in_external_editor(const Ref<Script> &p_script, int32_t p_line, int32_t p_col) override;
    virtual bool _overrides_external_editor() override;
    
    // Completion helpers
    Node* _find_control_recursive(Node* node, const String& name) const;
    void _add_child_controls_to_completion(Node* owner, Array& options, const String& filter) const;
    void _add_form_properties_to_completion(Array& options, const String& filter) const;
    void _add_control_properties_to_completion(const String& control_class, Array& options, const String& filter) const;
    
    virtual Dictionary _complete_code(const String &p_code, const String &p_path, Object *p_owner) const override;
    virtual Dictionary _lookup_code(const String &p_code, const String &p_symbol, const String &p_path, Object *p_owner) const override;
    virtual String _auto_indent_code(const String &p_code, int32_t p_from_line, int32_t p_to_line) const override;
    virtual void _add_global_constant(const StringName &p_name, const Variant &p_value) override;
    virtual void _add_named_global_constant(const StringName &p_name, const Variant &p_value) override;
    virtual void _remove_named_global_constant(const StringName &p_name) override;
    virtual bool _handles_global_class_type(const String &p_type) const override;
    virtual bool _supports_documentation() const override;
    virtual void _thread_enter() override;
    virtual void _thread_exit() override;
    virtual String _debug_get_error() const override;
    virtual int32_t _debug_get_stack_level_count() const override;
    virtual int32_t _debug_get_stack_level_line(int32_t p_level) const override;
    virtual String _debug_get_stack_level_function(int32_t p_level) const override;
    virtual Dictionary _debug_get_stack_level_locals(int32_t p_level, int32_t p_max_subitems, int32_t p_max_depth) override;
    virtual Dictionary _debug_get_stack_level_members(int32_t p_level, int32_t p_max_subitems, int32_t p_max_depth) override;
    virtual void *_debug_get_stack_level_instance(int32_t p_level) override;
    
    virtual TypedArray<Dictionary> _debug_get_current_stack_info() override;
    virtual void _frame() override;
    virtual Dictionary _debug_get_globals(int32_t p_max_subitems, int32_t p_max_depth) override;
    virtual String _debug_parse_stack_level_expression(int32_t p_level, const String &p_expression, int32_t p_max_subitems, int32_t p_max_depth) override;
    virtual void _reload_all_scripts() override;
    virtual void _reload_tool_script(const Ref<Script> &p_script, bool p_soft_reload) override;
    virtual String _debug_get_stack_level_source(int32_t p_level) const override;
    virtual PackedStringArray _get_doc_comment_delimiters() const override;
    PackedStringArray _get_code_region_tags() const;
    virtual PackedStringArray _get_recognized_extensions() const override;
    virtual TypedArray<Dictionary> _get_public_functions() const override;
    virtual Dictionary _get_public_constants() const override;
    virtual TypedArray<Dictionary> _get_public_annotations() const override;
    virtual void _profiling_start() override;
    virtual void _profiling_stop() override;
    virtual Dictionary _get_global_class_name(const String &p_path) const override;
    
    // Static methods for call stack management (called from VisualGasicInstance)
    static void push_stack_frame(const String& file, const String& function, int line, VisualGasicInstance* instance);
    static void pop_stack_frame();
    static void update_stack_frame_line(int line);
    static void set_debug_error(const String& error);
    static void clear_debug_error();
    
    // Step debugging control
    static VGStepMode get_step_mode() { return step_mode; }
    static void set_step_mode(VGStepMode mode);
    static int get_step_target_depth() { return step_target_depth; }
    static void set_step_target_depth(int depth) { step_target_depth = depth; }
    static int get_current_stack_depth();
    static void debug_continue();  // Resume execution
    static void debug_step_into(); // Step to next line
    static void debug_step_over(); // Step over function calls
    static void debug_step_out();  // Step out of current function
    
    // GDScript-accessible wrapper methods
    static int get_step_mode_int();
    static String get_current_debug_file();
    static int get_current_debug_line();
    static Array get_call_stack_array();  // Get current call stack for debugger
    
    // Set/get current breakpoint location (for editor navigation)
    static void set_current_break_location(const String& file, int line);
    static String get_break_file();
    static int get_break_line();
    
    // Custom debug wait function (replaces script_debug for stepping)
    static void wait_for_debug_command();
    
    // Breakpoint management (C++ side - avoid GDScript calls during debug)
    static void load_breakpoints_from_file();
    static bool has_breakpoint(const String& script_path, int line);
    static void clear_breakpoints();
    
    // Data breakpoints (watchpoints) - break when variable value changes
    static void add_watchpoint(const String& variable_name);
    static void remove_watchpoint(const String& variable_name);
    static void clear_watchpoints();
    static Array get_watchpoints();  // Returns list of watched variable names
    static bool check_watchpoint(const String& variable_name, const Variant& new_value);  // Returns true if value changed
    
    // Pause/Break request - allows pausing a running program without pre-set breakpoints
    static void request_break();     // Called from UI/editor to request a break
    static bool is_break_requested();
    static void clear_break_request();
    
    // Expression evaluation in debug context
    static String evaluate_expression_in_context(const String& expression);

    // Immediate Window evaluate — callable from GDScript
    static Dictionary evaluate_immediate_by_index(int instance_index, const String& code);
    
    // Hot Reload — script registry
    static void register_script(VisualGasicScript* script);
    static void unregister_script(VisualGasicScript* script);
    static void queue_hot_reload(VisualGasicScript* script);
    static int get_live_script_count();
    
    // Debug wait — enters Godot's EngineDebugger::script_debug() loop
    static void vg_debug_wait();
    
    // Idle break — called from _process to handle break-when-idle
    static void idle_break();
    
    // Exception Assistant: break on unhandled error (VB6-style)
    static bool get_break_on_error();
    static void set_break_on_error(bool enabled);
    
    // Set Next Statement (yellow-arrow drag)
    static void set_next_statement(int line);
    static bool is_next_statement_requested();
    static int get_next_statement_line();
    static void clear_next_statement();
    
    // Edit & Continue
    static bool apply_edit_and_continue(const String& script_path, const String& new_source);
    
    // Stack locals by level (for debug message handler)
    static Dictionary get_stack_locals_by_level(int level);
};

#endif // VISUAL_GASIC_LANGUAGE_H
