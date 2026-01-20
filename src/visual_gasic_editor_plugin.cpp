#include "visual_gasic_editor_plugin.h"
#include "visual_gasic_tokenizer.h"
#include <godot_cpp/classes/text_edit.hpp>

void VisualGasicSyntaxHighlighter::_bind_methods() {
}

Dictionary VisualGasicSyntaxHighlighter::_get_line_syntax_highlighting(int32_t p_line) const {
    Dictionary color_map;
    
    TextEdit* te = get_text_edit();
    if (!te) return color_map;

    String line = te->get_line(p_line);
    
    VisualGasicTokenizer tokenizer;
    Vector<VisualGasicTokenizer::Token> tokens = tokenizer.tokenize(line);
    
    // Color definitions
    Color keyword_color = Color(1.0, 0.44, 0.52); // Pinkish red
    Color string_color = Color(1.0, 0.93, 0.5); // Yellowish
    Color comment_color = Color(0.4, 0.8, 0.4); // Greenish
    Color number_color = Color(0.6, 0.8, 1.0); // Cyanish
    Color symbol_color = Color(0.8, 0.8, 1.0); // White-ish blue
    Color type_color = Color(0.5, 1.0, 0.8); // Teal
    
    for(int i=0; i<tokens.size(); i++) {
        VisualGasicTokenizer::Token t = tokens[i];
        if (t.type == VisualGasicTokenizer::TOKEN_EOF || t.type == VisualGasicTokenizer::TOKEN_NEWLINE) continue;
        
        Color c = Color(1,1,1);
        bool set = false;
        
        switch(t.type) {
            case VisualGasicTokenizer::TOKEN_KEYWORD: c = keyword_color; set=true; break;
            case VisualGasicTokenizer::TOKEN_LITERAL_STRING: c = string_color; set=true; break;
            case VisualGasicTokenizer::TOKEN_COMMENT: c = comment_color; set=true; break;
            case VisualGasicTokenizer::TOKEN_LITERAL_INTEGER:
            case VisualGasicTokenizer::TOKEN_LITERAL_FLOAT: c = number_color; set=true; break;
            case VisualGasicTokenizer::TOKEN_IDENTIFIER: 
                 c = symbol_color; set=true; 
                 break; 
            default: break;
        }
        
        if (set && t.column > 0) {
            color_map[t.column - 1] = c;
        }
    }
    
    return color_map;
}

#include <godot_cpp/classes/editor_interface.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

void VisualGasicEditorPlugin::_bind_methods() {}

VisualGasicEditorPlugin::VisualGasicEditorPlugin() {
    toolbox = nullptr;
}

VisualGasicEditorPlugin::~VisualGasicEditorPlugin() {}

void VisualGasicEditorPlugin::_enter_tree() {
    UtilityFunctions::print("VisualGasicEditorPlugin: Entering tree");
    toolbox = memnew(VisualGasicToolbox);
    toolbox->set_name("Toolbox");
    // Switch to bottom panel to ensure visibility
    add_control_to_bottom_panel(toolbox, "Visual Gasic");
    UtilityFunctions::print("VisualGasicEditorPlugin: Toolbox added to BOTTOM panel");
}

void VisualGasicEditorPlugin::_exit_tree() {
    if (toolbox) {
        remove_control_from_docks(toolbox);
        memdelete(toolbox);
        toolbox = nullptr;
    }
}
