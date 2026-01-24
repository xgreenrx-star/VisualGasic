#include "visual_gasic_tokenizer.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <strings.h>
#include <vector>
#include <cstdlib>  // for std::strtod, std::strtol

VisualGasicTokenizer::VisualGasicTokenizer() {
    has_error = false;
    error_line = 0;
    error_column = 0;
}

VisualGasicTokenizer::~VisualGasicTokenizer() {
}

bool VisualGasicTokenizer::is_digit(char32_t c) {
    return c >= '0' && c <= '9';
}

bool VisualGasicTokenizer::is_alpha(char32_t c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_';
}

bool VisualGasicTokenizer::is_alphanumeric(char32_t c) {
    return is_alpha(c) || is_digit(c);
}

bool VisualGasicTokenizer::is_whitespace(char32_t c) {
    return c == ' ' || c == '\t' || c == '\r';
}

String VisualGasicTokenizer::token_type_to_string(TokenType p_type) {
    switch (p_type) {
        case TOKEN_EOF: return "EOF";
        case TOKEN_NEWLINE: return "NEWLINE";
        case TOKEN_IDENTIFIER: return "IDENTIFIER";
        case TOKEN_KEYWORD: return "KEYWORD";
        case TOKEN_LITERAL_INTEGER: return "INTEGER";
        case TOKEN_LITERAL_FLOAT: return "FLOAT";
        case TOKEN_LITERAL_STRING: return "STRING";
        case TOKEN_OPERATOR: return "OPERATOR";
        case TOKEN_PAREN_OPEN: return "PAREN_OPEN";
        case TOKEN_PAREN_CLOSE: return "PAREN_CLOSE";
        case TOKEN_COMMA: return "COMMA";
        case TOKEN_COMMENT: return "COMMENT";
        case TOKEN_ERROR: return "ERROR";
        default: return "UNKNOWN";
    }
}

Vector<VisualGasicTokenizer::Token> VisualGasicTokenizer::tokenize(const String &p_source_code) {
    // Keep the original wrapper that converts to UTF-8 std::string and forwards
    std::string utf8 = p_source_code.utf8().get_data();
    return tokenize_from_utf8(utf8);
}

Vector<VisualGasicTokenizer::Token> VisualGasicTokenizer::tokenize_from_utf8(const std::string &p_source_code) {
    Vector<Token> tokens;
    int length = (int)p_source_code.size();
    int current = 0;
    int line = 1;
    int column = 1;

    // VB6 Keywords - use std::vector for standalone tests
    std::vector<std::string> keywords;
    keywords.push_back("Dim");
    keywords.push_back("Sub");
    keywords.push_back("End");
    keywords.push_back("Function");
    keywords.push_back("If");
    keywords.push_back("Then");
    keywords.push_back("Else");
    keywords.push_back("For");
    keywords.push_back("To");
    keywords.push_back("Next");
    keywords.push_back("Step");
    keywords.push_back("While");
    keywords.push_back("Wend");
    keywords.push_back("Do");
    keywords.push_back("Loop");
    keywords.push_back("Print");
    keywords.push_back("Call");
    keywords.push_back("And");
    keywords.push_back("Or");
    keywords.push_back("Not");
    keywords.push_back("Xor");
    keywords.push_back("On");
    keywords.push_back("Error");
    keywords.push_back("Resume");
    keywords.push_back("Goto");
    keywords.push_back("Until");
    keywords.push_back("Select");
    keywords.push_back("Case");
    keywords.push_back("Type");
    keywords.push_back("As");
    keywords.push_back("Open");
    keywords.push_back("Close");
    keywords.push_back("Input");
    keywords.push_back("Output");
    keywords.push_back("Append");
    keywords.push_back("Line");
    keywords.push_back("Include");
    keywords.push_back("Exit");
    keywords.push_back("Public");
    keywords.push_back("Private");
    keywords.push_back("Redim");
    keywords.push_back("Preserve");
    keywords.push_back("Set");
    keywords.push_back("Nothing");
    keywords.push_back("Inherits");
    keywords.push_back("Extends");
    keywords.push_back("Me");
    // 'Event' is intentionally omitted from keywords to allow common parameter name 'event' in handlers
    // (e.g., Sub _unhandled_input(event As Object)). Keep 'RaiseEvent' if needed.
    keywords.push_back("RaiseEvent");
    keywords.push_back("New");
    keywords.push_back("Dictionary");
    keywords.push_back("each");
    keywords.push_back("in");
    keywords.push_back("with");
    keywords.push_back("Return");
    keywords.push_back("Continue");
    keywords.push_back("AndAlso");
    keywords.push_back("OrElse");
    keywords.push_back("IIf");
    keywords.push_back("True");
    keywords.push_back("False");
    keywords.push_back("Const");
    keywords.push_back("DoEvents");
    keywords.push_back("Data");
    keywords.push_back("Read");
    keywords.push_back("Restore");
    keywords.push_back("Option");
    keywords.push_back("Explicit");
    keywords.push_back("Try");
    keywords.push_back("Catch");
    keywords.push_back("Finally");
    keywords.push_back("Pass");
    keywords.push_back("Elif");
    keywords.push_back("ElseIf");
    keywords.push_back("Optional");
    keywords.push_back("ByVal");
    keywords.push_back("ByRef");
    keywords.push_back("ParamArray");
    keywords.push_back("Static");

    while (current < length) {
        unsigned char uc = p_source_code[current];
        char32_t c = (char32_t)uc; // ASCII/UTF-8-safe for our test inputs

        // Whitespace (ignore spaces and tabs, but keep track of column)
        if (c == ' ' || c == '\t' || c == '\r') {
            current++;
            column++;
            continue;
        }

        // Newline
        if (c == '\n') {
            Token t;
            t.type = TOKEN_NEWLINE;
            t.line = line;
            t.column = column;
            tokens.push_back(t);
            
            current++;
            line++;
            column = 1;
            continue;
        }

        // Comments
        if (c == '\'') {
            int start = current;
            while (current < length && p_source_code[current] != '\n') {
                current++;
            }
            Token t;
            t.type = TOKEN_COMMENT;
            t.text = std::string(p_source_code.c_str()+start, current-start);
            t.line = line;
            t.column = column;
            tokens.push_back(t);
            column += (current - start);
            continue;
        }

        // Numbers
        if (is_digit(c)) {
            int start = current;
            bool is_float = false;
            while (current < length && ((unsigned char)p_source_code[current] >= '0' && (unsigned char)p_source_code[current] <= '9' || p_source_code[current] == '.')) {
                if (p_source_code[current] == '.') {
                    if (is_float) break;
                    is_float = true;
                }
                current++;
            }
            // Use std::string for numeric parsing to avoid godot::String initialization issues
            std::string num_str(p_source_code.c_str()+start, current-start);
            Token t;
            t.type = is_float ? TOKEN_LITERAL_FLOAT : TOKEN_LITERAL_INTEGER;
            // Parse numeric value using strtod/strtol instead of String methods
            t.value = is_float ? std::strtod(num_str.c_str(), nullptr) : std::strtol(num_str.c_str(), nullptr, 10);
            t.text = num_str;
            t.line = line;
            t.column = column;
            tokens.push_back(t);
            column += (current - start);
            continue;
        }

        // Identifiers and Keywords
        auto is_alnum_local = [](unsigned char ch){ return (ch=='_' || (ch>='a' && ch<='z') || (ch>='A' && ch<='Z') || (ch>='0' && ch<='9')); };
        auto is_alpha_local = [](unsigned char ch){ return (ch=='_' || (ch>='a' && ch<='z') || (ch>='A' && ch<='Z')); };

        if (is_alpha_local(uc)) {
            int start = current;
            while (current < length && is_alnum_local((unsigned char)p_source_code[current])) {
                current++;
            }
            Token t;
            t.text = std::string(p_source_code.c_str()+start, current-start);
            t.line = line;
            t.column = column;

            bool is_keyword = false;
            // Determine case-insensitive keyword match using std::string comparison
            for (size_t i = 0; i < keywords.size(); i++) {
                if (strcasecmp(keywords[i].c_str(), t.text.c_str()) == 0) {
                    is_keyword = true;
                    break;
                }
            }
            t.type = is_keyword ? TOKEN_KEYWORD : TOKEN_IDENTIFIER;
            tokens.push_back(t);
            column += (current - start);
            continue;
        }

        // Strings
        bool is_interpolated = false;
        if (c == '$' && current + 1 < length && p_source_code[current+1] == '"') {
             is_interpolated = true;
             current++; // Eat $
             c = '"';
        }

        if (c == '"') {
            current++; // Skip opening
            int start = current;
            while (current < length && p_source_code[current] != '"' && p_source_code[current] != '\n') {
                current++;
            }
            if (current >= length || p_source_code[current] == '\n') {
                 Token t;
                 t.type = TOKEN_ERROR;
                 t.text = "Unterminated string";
                 t.line = line;
                 t.column = column;
                 tokens.push_back(t);
                 continue;
            }
            // Removed godot::String construction that could cause memory corruption
            current++; // Skip closing
            Token t;
            t.type = is_interpolated ? TOKEN_STRING_INTERP : TOKEN_LITERAL_STRING;
            t.text = std::string(p_source_code.c_str()+start, current-start);
            t.line = line;
            t.column = column;
            tokens.push_back(t);
            column += (current - start + 2 + (is_interpolated?1:0));
            continue;
        }

        // Single Character Tokens
        Token t;
        t.line = line;
        t.column = column;
        bool handled = true;

        switch (c) {
            case '(': t.type = TOKEN_PAREN_OPEN; t.text = "("; break;
            case ')': t.type = TOKEN_PAREN_CLOSE; t.text = ")"; break;
            case ',': t.type = TOKEN_COMMA; t.text = ","; break;
            case '+': 
                if (current + 1 < length && p_source_code[current+1] == '=') { t.type = TOKEN_OPERATOR; t.text = "+="; current++; }
                else if (current + 1 < length && p_source_code[current+1] == '+') { t.type = TOKEN_OPERATOR; t.text = "++"; current++; }
                else { t.type = TOKEN_OPERATOR; t.text = "+"; }
                break;
            case '-': 
                if (current + 1 < length && p_source_code[current+1] == '=') { t.type = TOKEN_OPERATOR; t.text = "-="; current++; }
                else if (current + 1 < length && p_source_code[current+1] == '-') { t.type = TOKEN_OPERATOR; t.text = "--"; current++; }
                else { t.type = TOKEN_OPERATOR; t.text = "-"; }
                break;
            case '*': 
                if (current + 1 < length && p_source_code[current+1] == '=') { t.type = TOKEN_OPERATOR; t.text = "*="; current++; }
                else if (current + 1 < length && p_source_code[current+1] == '*') { t.type = TOKEN_OPERATOR; t.text = "**"; current++; }
                else { t.type = TOKEN_OPERATOR; t.text = "*"; }
                break;
            case '/': 
                if (current + 1 < length && p_source_code[current+1] == '=') { t.type = TOKEN_OPERATOR; t.text = "/="; current++; }
                else if (current + 1 < length && p_source_code[current+1] == '/') { t.type = TOKEN_OPERATOR; t.text = "//"; current++; }
                else { t.type = TOKEN_OPERATOR; t.text = "/"; }
                break;
            case '&': t.type = TOKEN_OPERATOR; t.text = "&"; break;
            case ':': t.type = TOKEN_COLON;    t.text = ":"; break;
            case '.': t.type = TOKEN_OPERATOR; t.text = "."; break;
            case '=': t.type = TOKEN_OPERATOR; t.text = "="; break;
            case '#': t.type = TOKEN_OPERATOR; t.text = "#"; break;
            case '>': 
                if (current + 1 < length && p_source_code[current+1] == '=') { t.type = TOKEN_OPERATOR; t.text = ">="; current++; }
                else { t.type = TOKEN_OPERATOR; t.text = ">"; }
                break;
            case '<': 
                if (current + 1 < length && p_source_code[current+1] == '=') { t.type = TOKEN_OPERATOR; t.text = "<="; current++; }
                else if (current + 1 < length && p_source_code[current+1] == '>') { t.type = TOKEN_OPERATOR; t.text = "<>"; current++; }
                else { t.type = TOKEN_OPERATOR; t.text = "<"; }
                break;
            default:
                t.type = TOKEN_ERROR;
                // Build textual error without creating a godot::String
                std::string tmp = std::string("Unexpected character: ");
                tmp.push_back((char)c);
                t.text = tmp;
                if (!has_error) {
                    has_error = true;
                    error_line = line;
                    error_column = column;
                    error_message = tmp;
                }
                handled = true;
                break;
        }

        if (handled) {
            current++;
            column += (int)t.text.size();
            tokens.push_back(t);
            continue;
        }
    }

    Token eof;
    eof.type = TOKEN_EOF;
    eof.line = line;
    eof.column = column;
    tokens.push_back(eof);

    return tokens;
}
