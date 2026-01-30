#ifndef VISUAL_GASIC_BRACKET_COMPLETION_H
#define VISUAL_GASIC_BRACKET_COMPLETION_H

#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

using namespace godot;

/**
 * Smart Bracket Completion System for VisualGasic
 * 
 * Provides automatic keyword completion when typing closing brackets:
 * - Typing "}" after For loop → auto-suggests "Next"
 * - Typing "}" after While loop → auto-suggests "Wend" or "End While"
 * - Typing "}" after If statement → auto-suggests "End If"
 * - Typing "}" after Sub/Function → auto-suggests "End Sub" or "End Function"
 */
class BracketCompletionHelper {
public:
    struct BlockInfo {
        String keyword;      // "For", "While", "If", "Sub", "Function"
        String variable;     // Loop variable name (for For loops)
        int indent_level;    // Indentation level
        int line_number;     // Line where block starts
    };

    /**
     * Analyze code and detect what closing keyword should be suggested
     * when user types "}" at current position
     */
    static String detect_closing_keyword(const String& code, int cursor_line);
    
    /**
     * Find the most recent unclosed block at the cursor position
     */
    static BlockInfo find_open_block(const String& code, int cursor_line);
    
    /**
     * Check if a character should trigger completion
     */
    static bool is_trigger_char(char32_t c);
    
    /**
     * Get completion suggestion for a specific block type
     */
    static String get_completion_for_block(const String& block_type, const String& variable = "");
    
    /**
     * Calculate indentation level of a line
     */
    static int get_indent_level(const String& line);
    
    /**
     * Check if line is an opening block statement
     */
    static bool is_opening_statement(const String& line, String& out_keyword, String& out_variable);
    
    /**
     * Check if line is a closing block statement
     */
    static bool is_closing_statement(const String& line, String& out_keyword);
};

#endif // VISUAL_GASIC_BRACKET_COMPLETION_H
