#include "visual_gasic_script.h"
#include "visual_gasic_parser.h"
#include <godot_cpp/classes/project_settings.hpp>

void VisualGasicScript::format_source_code() {
    // Check Project Setting (if I implement it)
    // Or just always do it for now if called.
    
    // Auto-Format IIF
    bool auto_iif = ProjectSettings::get_singleton()->get_setting("visual_gasic/auto_format_iif", false);
    
    if (auto_iif) {
        String new_code = VisualGasicParser::format_iif_to_inline(source_code);
        if (new_code != source_code) {
             source_code = new_code;
             // Emit changed signal?
             emit_signal("changed"); 
        }
    }
}
