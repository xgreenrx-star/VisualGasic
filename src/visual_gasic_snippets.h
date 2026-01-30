#ifndef VISUAL_GASIC_SNIPPETS_H
#define VISUAL_GASIC_SNIPPETS_H

#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>

using namespace godot;

/**
 * Code Snippets and Smart Completion System
 * 
 * Provides:
 * - Common code pattern snippets (fori, tryc, prop, etc.)
 * - Smart line completion (auto-add Then, To, etc.)
 * - Parameter hints for functions
 * - Auto-pair structures (For...Next, If...End If, etc.)
 */
class SnippetHelper {
public:
    struct Snippet {
        String trigger;           // "fori", "tryc", etc.
        String description;       // "For loop with index"
        String code_template;     // Code with ${1:placeholder} markers
        String insert_text;       // Code with cursor position markers
    };

    struct ParameterHint {
        String function_name;
        String signature;
        String description;
    };

    /**
     * Get all available snippets
     */
    static Array get_all_snippets();
    
    /**
     * Find snippet by trigger word
     */
    static Dictionary get_snippet(const String& trigger);
    
    /**
     * Check if line needs smart completion (missing Then, To, etc.)
     */
    static String detect_incomplete_statement(const String& line);
    
    /**
     * Get completion for incomplete statement
     * E.g., "If x > 10" → suggests "Then"
     */
    static String get_statement_completion(const String& line);
    
    /**
     * Detect if "{" should trigger keyword completion
     * E.g., "If x > 10 {" → replace with "If x > 10 Then"
     */
    static String detect_brace_keyword_completion(const String& line);
    
    /**
     * Get parameter hints for a function call
     * E.g., "CreateActor2D(" → returns signature
     */
    static Dictionary get_parameter_hint(const String& function_name);
    
    /**
     * Generate auto-paired structure for opening statement
     * E.g., "For i = 1 To 10" → generates complete For...Next block
     */
    static String generate_paired_structure(const String& opening_line);
    
    /**
     * Check if we should auto-generate paired structure
     */
    static bool should_generate_pair(const String& line);
    
    /**
     * Extract function name from line with opening parenthesis
     * E.g., "MsgBox(" → "MsgBox"
     */
    static String extract_function_name(const String& line);

private:
    static void initialize_snippets();
    static void initialize_parameter_hints();
    static Array* snippets;
    static Dictionary* parameter_hints;
    static bool initialized;
};

#endif // VISUAL_GASIC_SNIPPETS_H
