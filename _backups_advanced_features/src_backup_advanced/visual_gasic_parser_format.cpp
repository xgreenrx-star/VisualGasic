#include "visual_gasic_parser.h"
#include <godot_cpp/variant/utility_functions.hpp>

String VisualGasicParser::format_iif_to_inline(const String& p_source) {
    VisualGasicTokenizer tokenizer;
    Vector<VisualGasicTokenizer::Token> tokens = tokenizer.tokenize(p_source);
    
    String formatted_code = "";
    int current_idx = 0;
    int source_pos = 0;
    
    // We rebuild the string by copying chunks.
    // However, exact preservation of whitespace is tricky if we rely on getToken position.
    // Luckily our Tokenizer stores line/column but not absolute byte offset?
    // Wait, the Token struct in visual_gasic_tokenizer.h does not store absolute offset.
    // This makes accurate replacement hard without re-tokenizing.
    // 
    // New Plan: We iterate the source string and valid tokens simultaneously.
    // But since we don't have offsets, we will estimate or just implement a simpler scanner here
    // OR we update tokenizer to support offsets. Updating tokenizer is better for robust tools.
    
    // Check tokenizer definition again.
    // It has line/col.
    
    // ALTERNATIVE: Use a simplified scanner for "IIf" here since we just want to replace that call.
    // We need to match parens to find arguments.
    
    String result = p_source;
    int search_start = 0;
    
    while (true) {
        int iif_pos = result.findn("IIf", search_start);
        if (iif_pos == -1) break;
        
        // Check if it's a standalone keyword (not part of Identifier like 'myIIf')
        if (iif_pos > 0) {
            char32_t prev = result[iif_pos - 1];
            if (VisualGasicTokenizer::is_alphanumeric(prev)) {
                search_start = iif_pos + 3;
                continue;
            }
        }
        if (iif_pos + 3 < result.length()) {
            char32_t next = result[iif_pos + 3];
            if (VisualGasicTokenizer::is_alphanumeric(next)) {
                search_start = iif_pos + 3;
                continue;
            }
        }
        
        // Found IIf. Now look for (
        int open_paren = result.find("(", iif_pos);
        // Ensure only whitespace between IIf and (
        bool clean = true;
        for(int k=iif_pos+3; k<open_paren; k++) {
            if (result[k] != ' ' && result[k] != '\t' && result[k] != '\n') {
                clean = false; break;
            }
        }
        
        if (!clean || open_paren == -1) {
            search_start = iif_pos + 3;
            continue;
        }
        
        // Find Arguments: Cond, True, False
        // We need to handle nested parens and strings.
        int depth = 0;
        bool in_string = false;
        
        int arg1_start = open_paren + 1;
        int arg1_end = -1;
        int arg2_start = -1;
        int arg2_end = -1;
        int arg3_start = -1;
        int arg3_end = -1;
        int close_paren = -1;
        
        int current_arg = 1;
        
        for(int k=open_paren + 1; k < result.length(); k++) {
            char32_t c = result[k];
            
            if (c == '"') {
                in_string = !in_string;
                continue;
            }
            if (in_string) continue;
            
            if (c == '(') depth++;
            else if (c == ')') {
                if (depth > 0) depth--;
                else {
                    // End of IIf
                    close_paren = k;
                    if (current_arg == 3) arg3_end = k;
                    break;
                }
            } else if (c == ',' && depth == 0) {
                if (current_arg == 1) {
                    arg1_end = k;
                    arg2_start = k + 1;
                    current_arg = 2;
                } else if (current_arg == 2) {
                    arg2_end = k;
                    arg3_start = k + 1;
                    current_arg = 3;
                }
            }
        }
        
        if (close_paren != -1 && current_arg == 3) {
            // Extracted
            String cond = result.substr(arg1_start, arg1_end - arg1_start).strip_edges();
            String true_part = result.substr(arg2_start, arg2_end - arg2_start).strip_edges();
            String false_part = result.substr(arg3_start, arg3_end - arg3_start).strip_edges();
            
            // Clean named args
            if (true_part.begins_with("True") || true_part.begins_with("true")) {
                 int eq = true_part.find("=");
                 if (eq != -1) true_part = true_part.substr(eq+1).strip_edges();
            }
            if (false_part.begins_with("False") || false_part.begins_with("false")) {
                 int eq = false_part.find("=");
                 if (eq != -1) false_part = false_part.substr(eq+1).strip_edges();
            }
            
            // Construct Inline: "TruePart If Condition Else FalsePart"
            String substitution = true_part + " If " + cond + " Else " + false_part;
            
            // Replace
            // "IIf( ... )" -> substitution
            result = result.substr(0, iif_pos) + substitution + result.substr(close_paren + 1);
            
            // Do not advance search_start too much, continue from here (safe)
            search_start = iif_pos + substitution.length(); 
        } else {
             search_start = iif_pos + 3;
        }
    }
    
    return result;
}
