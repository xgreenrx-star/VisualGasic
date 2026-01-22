#include "standalone_tokenizer.h"
#include <cctype>

StandaloneTokenizer::StandaloneTokenizer() {}
StandaloneTokenizer::~StandaloneTokenizer() {}

static bool is_digit(char c) { return c >= '0' && c <= '9'; }
static bool is_alpha(char c) { return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'; }
static bool is_alphanumeric(char c) { return is_alpha(c) || is_digit(c); }

std::string StandaloneTokenizer::token_type_to_string(TokenType t) {
    switch (t) {
        case TOKEN_EOF: return "EOF";
        case TOKEN_NEWLINE: return "NEWLINE";
        case TOKEN_IDENTIFIER: return "IDENTIFIER";
        case TOKEN_KEYWORD: return "KEYWORD";
        case TOKEN_LITERAL_INTEGER: return "INTEGER";
        case TOKEN_LITERAL_FLOAT: return "FLOAT";
        case TOKEN_LITERAL_STRING: return "STRING";
        case TOKEN_STRING_INTERP: return "STRING_INTERP";
        case TOKEN_OPERATOR: return "OPERATOR";
        case TOKEN_PAREN_OPEN: return "PAREN_OPEN";
        case TOKEN_PAREN_CLOSE: return "PAREN_CLOSE";
        case TOKEN_COMMA: return "COMMA";
        case TOKEN_COLON: return "COLON";
        case TOKEN_COMMENT: return "COMMENT";
        case TOKEN_ERROR: return "ERROR";
        default: return "UNKNOWN";
    }
}

std::vector<StandaloneTokenizer::Token> StandaloneTokenizer::tokenize(const std::string &p_source_code) {
    std::vector<Token> tokens;
    int length = (int)p_source_code.size();
    int current = 0;
    int line = 1;
    int column = 1;

    // Expanded keyword set for tests
    std::vector<std::string> keywords = {"Watch","Sub","Function","End","Print","Whenever","If","Then","Else","For","To","Next","While","Wend","Return","Loop"};

    while (current < length) {
        char c = p_source_code[current];

        // Whitespace
        if (c == ' ' || c == '\t' || c == '\r') { current++; column++; continue; }

        if (c == '\n') {
            Token t; t.type = TOKEN_NEWLINE; t.line = line; t.column = column; t.value = "\n";
            tokens.push_back(t);
            current++; line++; column = 1; continue;
        }

        // Comments starting with '
        if (c == '\'') {
            int start = current;
            while (current < length && p_source_code[current] != '\n') current++;
            Token t; t.type = TOKEN_COMMENT; t.value = p_source_code.substr(start, current - start);
            t.line = line; t.column = column; tokens.push_back(t);
            column += (current - start);
            continue;
        }

        // Numbers
        if (is_digit(c)) {
            int start = current; bool is_float = false;
            while (current < length && (is_digit(p_source_code[current]) || p_source_code[current] == '.')) {
                if (p_source_code[current] == '.') { if (is_float) break; is_float = true; }
                current++;
            }
            Token t; t.type = is_float ? TOKEN_LITERAL_FLOAT : TOKEN_LITERAL_INTEGER; t.value = p_source_code.substr(start, current - start);
            t.line = line; t.column = column; tokens.push_back(t);
            column += (current - start); continue;
        }

        // Identifiers / Keywords
        if (is_alpha(c)) {
            int start = current; while (current < length && is_alphanumeric(p_source_code[current])) current++;
            std::string text = p_source_code.substr(start, current - start);
            Token t; t.value = text; t.line = line; t.column = column; t.type = TOKEN_IDENTIFIER;
            // case-insensitive check for keywords (simple)
            for (auto &k : keywords) {
                if (k.size() == text.size()) {
                    bool same = true;
                    for (size_t i=0;i<k.size();i++) if (tolower(k[i]) != tolower(text[i])) { same = false; break; }
                    if (same) { t.type = TOKEN_KEYWORD; t.value = k; break; }
                }
            }
            tokens.push_back(t); column += (current - start); continue;
        }

        // Strings
        bool is_interpolated = false;
        if (c == '$' && current + 1 < length && p_source_code[current+1] == '"') { is_interpolated = true; current++; c = '"'; }
        if (c == '"') {
            current++; int start = current;
            while (current < length && p_source_code[current] != '"' && p_source_code[current] != '\n') current++;
            if (current >= length || p_source_code[current] == '\n') {
                Token t; t.type = TOKEN_ERROR; t.value = "Unterminated string"; t.line = line; t.column = column; tokens.push_back(t); continue;
            }
            std::string s = p_source_code.substr(start, current - start);
            current++; Token t; t.type = is_interpolated ? TOKEN_STRING_INTERP : TOKEN_LITERAL_STRING; t.value = s; t.line = line; t.column = column; tokens.push_back(t);
            column += (current - start + 2 + (is_interpolated?1:0)); continue;
        }

        // Single-char tokens and operators
        Token t; t.line = line; t.column = column; bool handled = true;
        switch (c) {
            case '(' : t.type = TOKEN_PAREN_OPEN; t.value = "("; break;
            case ')' : t.type = TOKEN_PAREN_CLOSE; t.value = ")"; break;
            case ',' : t.type = TOKEN_COMMA; t.value = ","; break;
            case '+' : t.type = TOKEN_OPERATOR; t.value = "+"; break;
            case '-' : t.type = TOKEN_OPERATOR; t.value = "-"; break;
            case '*' : t.type = TOKEN_OPERATOR; t.value = "*"; break;
            case '/' : t.type = TOKEN_OPERATOR; t.value = "/"; break;
            case '&' : t.type = TOKEN_OPERATOR; t.value = "&"; break;
            case ':' : t.type = TOKEN_COLON; t.value = ":"; break;
            case '.' : t.type = TOKEN_OPERATOR; t.value = "."; break;
            case '=' : t.type = TOKEN_OPERATOR; t.value = "="; break;
            case '>' : t.type = TOKEN_OPERATOR; t.value = ">"; break;
            case '<' : t.type = TOKEN_OPERATOR; t.value = "<"; break;
            default:
                t.type = TOKEN_ERROR; t.value = std::string("Unexpected character: ") + c;
                handled = true; break;
        }
        if (handled) { current++; column += (int)t.value.size(); tokens.push_back(t); continue; }
    }

    Token eof; eof.type = TOKEN_EOF; eof.line = line; eof.column = column; eof.value = ""; tokens.push_back(eof);
    return tokens;
}
