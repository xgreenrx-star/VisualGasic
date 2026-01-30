#include "visual_gasic_bracket_completion.h"
#include <godot_cpp/variant/utility_functions.hpp>

bool BracketCompletionHelper::is_trigger_char(char32_t c) {
    return c == '}' || c == ']';
}

int BracketCompletionHelper::get_indent_level(const String& line) {
    int indent = 0;
    for (int i = 0; i < line.length(); i++) {
        if (line[i] == ' ') {
            indent++;
        } else if (line[i] == '\t') {
            indent += 4;
        } else {
            break;
        }
    }
    return indent;
}

bool BracketCompletionHelper::is_opening_statement(const String& line, String& out_keyword, String& out_variable) {
    String trimmed = line.strip_edges().to_lower();
    
    // For loops: "For i = 1 To 10"
    if (trimmed.begins_with("for ")) {
        out_keyword = "For";
        // Extract variable name
        int space_pos = trimmed.find(" ", 4);
        if (space_pos > 4) {
            out_variable = trimmed.substr(4, space_pos - 4).strip_edges();
        }
        return true;
    }
    
    // While loops: "While condition"
    if (trimmed.begins_with("while ")) {
        out_keyword = "While";
        return true;
    }
    
    // Do loops: "Do"
    if (trimmed == "do" || trimmed.begins_with("do ")) {
        out_keyword = "Do";
        return true;
    }
    
    // If statements: "If condition Then"
    if (trimmed.begins_with("if ") && (trimmed.contains(" then") || trimmed.ends_with(" then"))) {
        // Check for single-line if (has code after Then)
        int then_pos = trimmed.find(" then");
        if (then_pos != -1) {
            String after_then = trimmed.substr(then_pos + 5).strip_edges();
            if (after_then.is_empty() || after_then.begins_with("'")) {
                out_keyword = "If";
                return true;
            }
        }
    }
    
    // Select Case: "Select Case variable"
    if (trimmed.begins_with("select ")) {
        out_keyword = "Select";
        return true;
    }
    
    // With blocks: "With object"
    if (trimmed.begins_with("with ")) {
        out_keyword = "With";
        return true;
    }
    
    // Sub/Function: "Sub MyFunc()" or "Function MyFunc() As Type"
    if (trimmed.begins_with("sub ")) {
        out_keyword = "Sub";
        // Extract function name
        int paren_pos = trimmed.find("(");
        if (paren_pos > 4) {
            out_variable = trimmed.substr(4, paren_pos - 4).strip_edges();
        }
        return true;
    }
    
    if (trimmed.begins_with("function ")) {
        out_keyword = "Function";
        int paren_pos = trimmed.find("(");
        if (paren_pos > 9) {
            out_variable = trimmed.substr(9, paren_pos - 9).strip_edges();
        }
        return true;
    }
    
    // Property: "Property Get/Set MyProp"
    if (trimmed.begins_with("property ")) {
        out_keyword = "Property";
        return true;
    }
    
    // Class: "Class MyClass"
    if (trimmed.begins_with("class ")) {
        out_keyword = "Class";
        return true;
    }
    
    // Try blocks: "Try"
    if (trimmed == "try") {
        out_keyword = "Try";
        return true;
    }
    
    return false;
}

bool BracketCompletionHelper::is_closing_statement(const String& line, String& out_keyword) {
    String trimmed = line.strip_edges().to_lower();
    
    if (trimmed == "next" || trimmed.begins_with("next ")) {
        out_keyword = "For";
        return true;
    }
    
    if (trimmed == "wend" || trimmed == "end while") {
        out_keyword = "While";
        return true;
    }
    
    if (trimmed == "loop" || trimmed.begins_with("loop ")) {
        out_keyword = "Do";
        return true;
    }
    
    if (trimmed == "end if") {
        out_keyword = "If";
        return true;
    }
    
    if (trimmed == "end select") {
        out_keyword = "Select";
        return true;
    }
    
    if (trimmed == "end with") {
        out_keyword = "With";
        return true;
    }
    
    if (trimmed == "end sub") {
        out_keyword = "Sub";
        return true;
    }
    
    if (trimmed == "end function") {
        out_keyword = "Function";
        return true;
    }
    
    if (trimmed == "end property") {
        out_keyword = "Property";
        return true;
    }
    
    if (trimmed == "end class") {
        out_keyword = "Class";
        return true;
    }
    
    if (trimmed == "end try" || trimmed.begins_with("catch") || trimmed == "finally") {
        out_keyword = "Try";
        return true;
    }
    
    return false;
}

BracketCompletionHelper::BlockInfo BracketCompletionHelper::find_open_block(const String& code, int cursor_line) {
    BlockInfo result;
    result.keyword = "";
    result.variable = "";
    result.indent_level = -1;
    result.line_number = -1;
    
    PackedStringArray lines = code.split("\n");
    if (cursor_line < 0 || cursor_line >= lines.size()) {
        return result;
    }
    
    // Stack to track nested blocks
    struct StackItem {
        String keyword;
        String variable;
        int indent;
        int line;
    };
    
    godot::Vector<StackItem> block_stack;
    
    // Scan from start to cursor line
    for (int i = 0; i <= cursor_line; i++) {
        String line = lines[i];
        String keyword, variable;
        
        // Check for opening statement
        if (is_opening_statement(line, keyword, variable)) {
            StackItem item;
            item.keyword = keyword;
            item.variable = variable;
            item.indent = get_indent_level(line);
            item.line = i;
            block_stack.push_back(item);
            continue;
        }
        
        // Check for closing statement
        if (is_closing_statement(line, keyword)) {
            // Pop matching block from stack
            for (int j = block_stack.size() - 1; j >= 0; j--) {
                if (block_stack[j].keyword.to_lower() == keyword.to_lower()) {
                    block_stack.remove_at(j);
                    break;
                }
            }
        }
    }
    
    // Return the most recent unclosed block
    if (!block_stack.is_empty()) {
        const StackItem& top = block_stack[block_stack.size() - 1];
        result.keyword = top.keyword;
        result.variable = top.variable;
        result.indent_level = top.indent;
        result.line_number = top.line;
    }
    
    return result;
}

String BracketCompletionHelper::get_completion_for_block(const String& block_type, const String& variable) {
    String keyword_lower = block_type.to_lower();
    
    if (keyword_lower == "for") {
        if (!variable.is_empty()) {
            return "Next " + variable;
        }
        return "Next";
    }
    
    if (keyword_lower == "while") {
        return "Wend"; // or "End While" - prefer traditional VB6 style
    }
    
    if (keyword_lower == "do") {
        return "Loop";
    }
    
    if (keyword_lower == "if") {
        return "End If";
    }
    
    if (keyword_lower == "select") {
        return "End Select";
    }
    
    if (keyword_lower == "with") {
        return "End With";
    }
    
    if (keyword_lower == "sub") {
        return "End Sub";
    }
    
    if (keyword_lower == "function") {
        return "End Function";
    }
    
    if (keyword_lower == "property") {
        return "End Property";
    }
    
    if (keyword_lower == "class") {
        return "End Class";
    }
    
    if (keyword_lower == "try") {
        return "End Try";
    }
    
    return "";
}

String BracketCompletionHelper::detect_closing_keyword(const String& code, int cursor_line) {
    BlockInfo block = find_open_block(code, cursor_line);
    
    if (block.keyword.is_empty()) {
        return "";
    }
    
    return get_completion_for_block(block.keyword, block.variable);
}
