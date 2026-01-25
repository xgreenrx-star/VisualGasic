#ifndef VISUAL_GASIC_EDITOR_PLUGIN_H
#define VISUAL_GASIC_EDITOR_PLUGIN_H

#include <godot_cpp/classes/editor_plugin.hpp>
#include <godot_cpp/classes/editor_syntax_highlighter.hpp>
#include <godot_cpp/classes/text_edit.hpp>
#include "visual_gasic_toolbox.h"

using namespace godot;

class VisualGasicEditorPlugin : public EditorPlugin {
    GDCLASS(VisualGasicEditorPlugin, EditorPlugin);
    
    VisualGasicToolbox *toolbox;
    TextEdit *current_editor;

protected:
    static void _bind_methods();

public:
    VisualGasicEditorPlugin();
    ~VisualGasicEditorPlugin();

    virtual void _enter_tree() override;
    virtual void _exit_tree() override;
    virtual bool _handles(Object *p_object) const override;
    virtual void _edit(Object *p_object) override;
    
    // Text transformation methods
    void on_text_changed(int line);
    void transform_shortcuts(TextEdit* editor, int line);
    bool is_in_string_context(const String& line, int position);
    bool is_in_case_context(TextEdit* editor, int line);
    void replace_pattern(TextEdit* editor, int line, const String& pattern, const String& replacement);
    void add_type_inference(TextEdit* editor, int line);
    String infer_type_from_value(const String& value);
    void handle_incomplete_dim(TextEdit* editor, int line);
    void handle_incomplete_function(TextEdit* editor, int line, const String& pattern, const String& replacement);
    void convert_template_literal(TextEdit* editor, int line);
    void convert_f_string(TextEdit* editor, int line);
    void convert_interpolated_string(TextEdit* editor, int line);
    void convert_ternary_operator(TextEdit* editor, int line);
    void convert_c_style_for_loop(TextEdit* editor, int line);
    void convert_python_range_loop(TextEdit* editor, int line);
    void convert_c_style_while(TextEdit* editor, int line);
    void convert_array_brackets(TextEdit* editor, int line);
    void complete_control_structure(TextEdit* editor, int line);
    void fix_method_chaining(TextEdit* editor, int line);
    void convert_import_statements(TextEdit* editor, int line);
    String get_visualgasic_equivalent(const String& import_name);
    bool is_known_foreign_library(const String& line_text);
};

class VisualGasicSyntaxHighlighter : public EditorSyntaxHighlighter {
    GDCLASS(VisualGasicSyntaxHighlighter, EditorSyntaxHighlighter);

protected:
    static void _bind_methods();

public:
    virtual Dictionary _get_line_syntax_highlighting(int32_t p_line) const override;
};

#endif // VISUAL_GASIC_EDITOR_PLUGIN_H
