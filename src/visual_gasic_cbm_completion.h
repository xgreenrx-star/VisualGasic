#ifndef VISUAL_GASIC_CBM_COMPLETION_H
#define VISUAL_GASIC_CBM_COMPLETION_H

#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

using namespace godot;

/**
 * CBM-Style Abbreviation Completion System
 * 
 * Provides Commodore BASIC-style two-letter abbreviations:
 * - P<Shift+R> → Print
 * - F<Shift+O> → For
 * - I<Shift+F> → If
 * 
 * Features:
 * - Context-aware (only at statement boundaries)
 * - Safe (doesn't interfere with user identifiers)
 * - Unambiguous keywords auto-expand
 * - Ambiguous keywords show selection menu
 */
class CBMCompletionHelper {
public:
    /**
     * Check if a two-letter sequence should trigger CBM completion
     * Returns true if this looks like a CBM abbreviation in valid context
     */
    static bool should_trigger_cbm_completion(const String& code, const String& two_letter_abbrev);
    
    /**
     * Get completion(s) for a CBM abbreviation
     * Returns array of possible expansions
     * If only one match, auto-expand
     * If multiple, show menu
     */
    static Array get_cbm_completions(const String& abbrev);
    
    /**
     * Check if we're at a valid statement boundary
     * (start of line, after whitespace, after keywords like Then/Else)
     */
    static bool is_statement_boundary(const String& code, int position);
    
    /**
     * Check if abbreviation is inside an identifier
     * (e.g., "FormatData" contains "FO" but shouldn't expand)
     */
    static bool is_inside_identifier(const String& code, int position);
    
    /**
     * Check if we're after a dot (member access)
     */
    static bool is_after_dot(const String& code, int position);
    
    /**
     * Check if we're inside a string or comment
     */
    static bool is_inside_string_or_comment(const String& code, int position);
    
    /**
     * Get the primary (most common) expansion for ambiguous abbreviations
     */
    static String get_primary_expansion(const String& abbrev);
    
    /**
     * Check if abbreviation is unambiguous (single expansion)
     */
    static bool is_unambiguous(const String& abbrev);

private:
    static void initialize_mappings();
    static Dictionary* unambiguous_mappings;  // IF→If, TH→Then, etc.
    static Dictionary* ambiguous_mappings;     // PR→[Print,Private,Property]
    static bool initialized;
};

#endif // VISUAL_GASIC_CBM_COMPLETION_H
