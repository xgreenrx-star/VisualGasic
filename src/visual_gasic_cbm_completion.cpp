#include "visual_gasic_cbm_completion.h"
#include <godot_cpp/variant/utility_functions.hpp>

Dictionary* CBMCompletionHelper::unambiguous_mappings = nullptr;
Dictionary* CBMCompletionHelper::ambiguous_mappings = nullptr;
bool CBMCompletionHelper::initialized = false;

void CBMCompletionHelper::initialize_mappings() {
    if (initialized) return;
    
    // Lazy initialize dictionaries
    if (!unambiguous_mappings) {
        unambiguous_mappings = memnew(Dictionary);
    }
    if (!ambiguous_mappings) {
        ambiguous_mappings = memnew(Dictionary);
    }
    
    // Unambiguous mappings (auto-expand immediately)
    (*unambiguous_mappings)["IF"] = "If";
    (*unambiguous_mappings)["TH"] = "Then";
    (*unambiguous_mappings)["WE"] = "Wend";
    (*unambiguous_mappings)["LO"] = "Loop";
    (*unambiguous_mappings)["DO"] = "Do";
    (*unambiguous_mappings)["NE"] = "Next";
    (*unambiguous_mappings)["AS"] = "As";
    (*unambiguous_mappings)["TO"] = "To";
    (*unambiguous_mappings)["ST"] = "Step";
    (*unambiguous_mappings)["GO"] = "GoTo";
    (*unambiguous_mappings)["GS"] = "GoSub";
    (*unambiguous_mappings)["CA"] = "Case";
    (*unambiguous_mappings)["TR"] = "Try";
    (*unambiguous_mappings)["FI"] = "Finally";
    (*unambiguous_mappings)["EX"] = "Exit";
    (*unambiguous_mappings)["CO"] = "Continue";
    (*unambiguous_mappings)["IS"] = "Is";
    (*unambiguous_mappings)["OF"] = "Of";
    (*unambiguous_mappings)["ME"] = "Me";
    (*unambiguous_mappings)["BY"] = "ByVal";
    (*unambiguous_mappings)["BR"] = "ByRef";
    (*unambiguous_mappings)["OP"] = "Option";
    (*unambiguous_mappings)["MO"] = "Module";
    (*unambiguous_mappings)["US"] = "Using";
    (*unambiguous_mappings)["NA"] = "Namespace";
    (*unambiguous_mappings)["IM"] = "Implements";
    (*unambiguous_mappings)["IN"] = "Inherits";
    (*unambiguous_mappings)["OV"] = "Overrides";
    (*unambiguous_mappings)["MU"] = "MustOverride";
    (*unambiguous_mappings)["NO"] = "NotOverridable";
    (*unambiguous_mappings)["SH"] = "Shared";
    (*unambiguous_mappings)["PA"] = "Parallel";
    (*unambiguous_mappings)["AW"] = "Await";
    (*unambiguous_mappings)["TA"] = "Task";
    (*unambiguous_mappings)["MA"] = "Match";
    
    // Ambiguous mappings (show selection menu)
    Array pr_options;
    pr_options.push_back("Print");
    pr_options.push_back("Private");
    pr_options.push_back("Property");
    (*ambiguous_mappings)["PR"] = pr_options;
    
    Array fo_options;
    fo_options.push_back("For");
    fo_options.push_back("Format");
    (*ambiguous_mappings)["FO"] = fo_options;
    
    Array fu_options;
    fu_options.push_back("Function");
    (*ambiguous_mappings)["FU"] = fu_options;
    
    Array su_options;
    su_options.push_back("Sub");
    (*ambiguous_mappings)["SU"] = su_options;
    
    Array en_options;
    en_options.push_back("End");
    en_options.push_back("Enum");
    (*ambiguous_mappings)["EN"] = en_options;
    
    Array wh_options;
    wh_options.push_back("While");
    wh_options.push_back("With");
    wh_options.push_back("When");
    (*ambiguous_mappings)["WH"] = wh_options;
    
    Array se_options;
    se_options.push_back("Select");
    se_options.push_back("Set");
    (*ambiguous_mappings)["SE"] = se_options;
    
    Array di_options;
    di_options.push_back("Dim");
    (*ambiguous_mappings)["DI"] = di_options;
    
    Array re_options;
    re_options.push_back("Return");
    re_options.push_back("ReDim");
    (*ambiguous_mappings)["RE"] = re_options;
    
    Array el_options;
    el_options.push_back("Else");
    el_options.push_back("ElseIf");
    (*ambiguous_mappings)["EL"] = el_options;
    
    Array cl_options;
    cl_options.push_back("Class");
    (*ambiguous_mappings)["CL"] = cl_options;
    
    Array pu_options;
    pu_options.push_back("Public");
    (*ambiguous_mappings)["PU"] = pu_options;
    
    Array fr_options;
    fr_options.push_back("Friend");
    (*ambiguous_mappings)["FR"] = fr_options;
    
    Array ea_options;
    ea_options.push_back("Each");
    (*ambiguous_mappings)["EA"] = ea_options;
    
    Array ge_options;
    ge_options.push_back("Get");
    (*ambiguous_mappings)["GE"] = ge_options;
    
    Array un_options;
    un_options.push_back("Until");
    (*ambiguous_mappings)["UN"] = un_options;
    
    Array ty_options;
    ty_options.push_back("TypeOf");
    ty_options.push_back("Type");
    (*ambiguous_mappings)["TY"] = ty_options;
    
    Array ch_options;
    ch_options.push_back("Catch");
    (*ambiguous_mappings)["CH"] = ch_options;
    
    Array th2_options;
    th2_options.push_back("Throw");
    (*ambiguous_mappings)["TW"] = th2_options;
    
    Array st2_options;
    st2_options.push_back("Static");
    st2_options.push_back("String");
    st2_options.push_back("Structure");
    (*ambiguous_mappings)["SR"] = st2_options;
    
    Array an_options;
    an_options.push_back("And");
    an_options.push_back("AndAlso");
    (*ambiguous_mappings)["AN"] = an_options;
    
    Array or_options;
    or_options.push_back("Or");
    or_options.push_back("OrElse");
    (*ambiguous_mappings)["OR"] = or_options;
    
    Array no2_options;
    no2_options.push_back("Not");
    (*ambiguous_mappings)["NT"] = no2_options;
    
    Array xo_options;
    xo_options.push_back("Xor");
    (*ambiguous_mappings)["XO"] = xo_options;
    
    Array as2_options;
    as2_options.push_back("Async");
    (*ambiguous_mappings)["AS"] = as2_options;
    
    initialized = true;
}

bool CBMCompletionHelper::is_inside_string_or_comment(const String& code, int position) {
    bool in_string = false;
    char32_t string_char = 0;
    
    for (int i = 0; i < position && i < code.length(); i++) {
        char32_t c = code[i];
        
        // Check for comment start
        if (!in_string && c == '\'') {
            // Check if rest of line is comment (find newline)
            for (int j = i; j < code.length(); j++) {
                if (code[j] == '\n') {
                    if (position <= j) return true; // Position is in comment
                    break;
                }
            }
        }
        
        // Check for string delimiters
        if (c == '"') {
            if (!in_string) {
                in_string = true;
                string_char = c;
            } else if (c == string_char) {
                in_string = false;
            }
        }
    }
    
    return in_string;
}

bool CBMCompletionHelper::is_after_dot(const String& code, int position) {
    // Look backward for non-whitespace character
    for (int i = position - 1; i >= 0; i--) {
        char32_t c = code[i];
        if (c == ' ' || c == '\t') continue;
        return c == '.';
    }
    return false;
}

bool CBMCompletionHelper::is_inside_identifier(const String& code, int position) {
    // Check if character before abbreviation is alphanumeric or underscore
    if (position >= 2) {
        char32_t prev = code[position - 2];
        if ((prev >= 'a' && prev <= 'z') || 
            (prev >= 'A' && prev <= 'Z') || 
            (prev >= '0' && prev <= '9') || 
            prev == '_') {
            return true;
        }
    }
    
    return false;
}

bool CBMCompletionHelper::is_statement_boundary(const String& code, int position) {
    // Look backward to find what comes before
    int check_pos = position - 1;
    
    // Skip whitespace
    while (check_pos >= 0 && (code[check_pos] == ' ' || code[check_pos] == '\t')) {
        check_pos--;
    }
    
    // At start of file
    if (check_pos < 0) return true;
    
    // After newline
    if (code[check_pos] == '\n') return true;
    
    // After statement keywords
    // Look for "Then", "Else", ":", etc.
    String prev_word;
    int word_end = check_pos;
    while (check_pos >= 0) {
        char32_t c = code[check_pos];
        if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')) {
            prev_word = String::chr(c) + prev_word;
            check_pos--;
        } else {
            break;
        }
    }
    
    String prev_lower = prev_word.to_lower();
    if (prev_lower == "then" || prev_lower == "else" || 
        prev_lower == "do" || code[check_pos] == ':') {
        return true;
    }
    
    return false;
}

bool CBMCompletionHelper::should_trigger_cbm_completion(const String& code, const String& two_letter_abbrev) {
    if (two_letter_abbrev.length() != 2) return false;
    
    int position = code.length();
    
    // Safety checks
    if (is_inside_string_or_comment(code, position)) return false;
    if (is_after_dot(code, position)) return false;
    if (is_inside_identifier(code, position)) return false;
    
    // Must be at statement boundary
    if (!is_statement_boundary(code, position)) return false;
    
    // Check if we have a mapping for this abbreviation
    String upper_abbrev = two_letter_abbrev.to_upper();
    initialize_mappings();
    
    return unambiguous_mappings->has(upper_abbrev) || ambiguous_mappings->has(upper_abbrev);
}

Array CBMCompletionHelper::get_cbm_completions(const String& abbrev) {
    initialize_mappings();
    
    String upper_abbrev = abbrev.to_upper();
    Array results;
    
    // Check unambiguous first
    if (unambiguous_mappings->has(upper_abbrev)) {
        results.push_back((*unambiguous_mappings)[upper_abbrev]);
        return results;
    }
    
    // Check ambiguous
    if (ambiguous_mappings->has(upper_abbrev)) {
        return (*ambiguous_mappings)[upper_abbrev];
    }
    
    return results;
}

String CBMCompletionHelper::get_primary_expansion(const String& abbrev) {
    initialize_mappings();
    
    String upper_abbrev = abbrev.to_upper();
    
    // Unambiguous - return the mapping
    if (unambiguous_mappings->has(upper_abbrev)) {
        return (*unambiguous_mappings)[upper_abbrev];
    }
    
    // Ambiguous - return first option (most common)
    if (ambiguous_mappings->has(upper_abbrev)) {
        Array options = (*ambiguous_mappings)[upper_abbrev];
        if (options.size() > 0) {
            return options[0];
        }
    }
    
    return "";
}

bool CBMCompletionHelper::is_unambiguous(const String& abbrev) {
    initialize_mappings();
    String upper_abbrev = abbrev.to_upper();
    return unambiguous_mappings->has(upper_abbrev);
}
