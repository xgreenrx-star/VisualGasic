#ifndef VISUAL_GASIC_EDITOR_PLUGIN_H
#define VISUAL_GASIC_EDITOR_PLUGIN_H

#include <godot_cpp/classes/editor_plugin.hpp>
#include <godot_cpp/classes/editor_syntax_highlighter.hpp>
#include "visual_gasic_toolbox.h"

using namespace godot;

class VisualGasicEditorPlugin : public EditorPlugin {
    GDCLASS(VisualGasicEditorPlugin, EditorPlugin);
    
    VisualGasicToolbox *toolbox;

protected:
    static void _bind_methods();

public:
    VisualGasicEditorPlugin();
    ~VisualGasicEditorPlugin();

    virtual void _enter_tree() override;
    virtual void _exit_tree() override;
};

class VisualGasicSyntaxHighlighter : public EditorSyntaxHighlighter {
    GDCLASS(VisualGasicSyntaxHighlighter, EditorSyntaxHighlighter);

protected:
    static void _bind_methods();

public:
    virtual Dictionary _get_line_syntax_highlighting(int32_t p_line) const override;
};

#endif // VISUAL_GASIC_EDITOR_PLUGIN_H
