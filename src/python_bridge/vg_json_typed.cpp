// vg_json_typed.cpp
// Minimal JSON decoder preserving int vs. float distinction.
//
// RFC 8259 compliant. Numbers without '.' or 'e'/'E' -> Variant::INT (int64).
// Numbers with '.' or 'e'/'E' -> Variant::FLOAT (double).
// Integer overflow -> fall back to float, log warning.

#include "vg_json_typed.h"

#include <godot_cpp/variant/utility_functions.hpp>

#include <cstdint>
#include <cmath>

namespace godot {

// ---------------------------------------------------------------------------
// Internal: position-tracked string view
// ---------------------------------------------------------------------------
struct JsonCursor {
    const String &str;
    int pos;
    int len;

    JsonCursor(const String &s) : str(s), pos(0), len(s.length()) {}

    bool at_end() const { return pos >= len; }
    char32_t peek() const { return (pos < len) ? str[pos] : char32_t(0); }
    char32_t advance() { return (pos < len) ? str[pos++] : char32_t(0); }
    void skip_ws() {
        while (pos < len) {
            char32_t c = str[pos];
            if (c == ' ' || c == '\t' || c == '\n' || c == '\r')
                pos++;
            else
                break;
        }
    }
    bool match(char32_t expected) {
        if (pos < len && str[pos] == expected) {
            pos++;
            return true;
        }
        return false;
    }
};

// ---------------------------------------------------------------------------
// Forward declarations
// ---------------------------------------------------------------------------
static bool parse_value(JsonCursor &c, Variant &r_out, String &r_err, int depth);

// ---------------------------------------------------------------------------
// String parsing
// ---------------------------------------------------------------------------
static bool parse_string(JsonCursor &c, String &r_out, String &r_err) {
    if (c.at_end() || c.peek() != '"') {
        r_err = "Expected '\"'";
        return false;
    }
    c.advance();

    String result;
    while (!c.at_end()) {
        char32_t ch = c.advance();
        if (ch == '"') {
            r_out = result;
            return true;
        }
        if (ch == '\\') {
            if (c.at_end()) {
                r_err = "Unexpected end in string escape";
                return false;
            }
            char32_t esc = c.advance();
            switch (esc) {
                case '"':  result += char32_t('"'); break;
                case '\\': result += char32_t('\\'); break;
                case '/':  result += char32_t('/'); break;
                case 'b':  result += char32_t('\b'); break;
                case 'f':  result += char32_t('\f'); break;
                case 'n':  result += char32_t('\n'); break;
                case 'r':  result += char32_t('\r'); break;
                case 't':  result += char32_t('\t'); break;
                case 'u': {
                    if (c.pos + 4 > c.len) {
                        r_err = "Invalid \\uXXXX escape";
                        return false;
                    }
                    String hex = c.str.substr(c.pos, 4);
                    c.pos += 4;
                    int64_t cp = hex.hex_to_int();
                    if (cp < 0 || cp > 0x10FFFF) {
                        r_err = "Invalid codepoint in \\uXXXX";
                        return false;
                    }
                    if (cp >= 0xD800 && cp <= 0xDBFF) {
                        if (c.pos + 6 > c.len || c.str[c.pos] != '\\' || c.str[c.pos+1] != 'u') {
                            r_err = "Expected low surrogate after high surrogate";
                            return false;
                        }
                        String hex2 = c.str.substr(c.pos + 2, 4);
                        c.pos += 6;
                        int64_t cp2 = hex2.hex_to_int();
                        if (cp2 < 0xDC00 || cp2 > 0xDFFF) {
                            r_err = "Invalid low surrogate";
                            return false;
                        }
                        cp = 0x10000 + (cp - 0xD800) * 0x400 + (cp2 - 0xDC00);
                    }
                    if (cp <= 0x7F) {
                        result += char32_t((uint8_t)cp);
                    } else if (cp <= 0x7FF) {
                        result += char32_t((uint8_t)(0xC0 | (cp >> 6)));
                        result += char32_t((uint8_t)(0x80 | (cp & 0x3F)));
                    } else if (cp <= 0xFFFF) {
                        result += char32_t((uint8_t)(0xE0 | (cp >> 12)));
                        result += char32_t((uint8_t)(0x80 | ((cp >> 6) & 0x3F)));
                        result += char32_t((uint8_t)(0x80 | (cp & 0x3F)));
                    } else {
                        result += char32_t((uint8_t)(0xF0 | (cp >> 18)));
                        result += char32_t((uint8_t)(0x80 | ((cp >> 12) & 0x3F)));
                        result += char32_t((uint8_t)(0x80 | ((cp >> 6) & 0x3F)));
                        result += char32_t((uint8_t)(0x80 | (cp & 0x3F)));
                    }
                    break;
                }
                default:
                    r_err = "Invalid escape character";
                    return false;
            }
        } else {
            result += ch;
        }
    }
    r_err = "Unterminated string";
    return false;
}

// ---------------------------------------------------------------------------
// Number parsing
// ---------------------------------------------------------------------------
static bool parse_number(JsonCursor &c, Variant &r_out, String &r_err) {
    int start = c.pos;

    if (c.peek() == '-') c.advance();

    if (c.at_end() || c.peek() < '0' || c.peek() > '9') {
        r_err = "Expected digit";
        return false;
    }
    while (!c.at_end() && c.peek() >= '0' && c.peek() <= '9')
        c.advance();

    bool is_float = false;

    if (!c.at_end() && c.peek() == '.') {
        is_float = true;
        c.advance();
        if (c.at_end() || c.peek() < '0' || c.peek() > '9') {
            r_err = "Expected digit after '.'";
            return false;
        }
        while (!c.at_end() && c.peek() >= '0' && c.peek() <= '9')
            c.advance();
    }

    if (!c.at_end() && (c.peek() == 'e' || c.peek() == 'E')) {
        is_float = true;
        c.advance();
        if (!c.at_end() && (c.peek() == '+' || c.peek() == '-'))
            c.advance();
        if (c.at_end() || c.peek() < '0' || c.peek() > '9') {
            r_err = "Expected digit in exponent";
            return false;
        }
        while (!c.at_end() && c.peek() >= '0' && c.peek() <= '9')
            c.advance();
    }

    String token = c.str.substr(start, c.pos - start);

    if (is_float) {
        double val = token.to_float();
        r_out = val;
    } else {
        // int64 range is [-9223372036854775808, 9223372036854775807] (19
        // significant digits max). Compare digit count (excluding sign)
        // against that to decide whether to fall back to float rather than
        // risk silent truncation from String::to_int().
        bool negative = token.begins_with("-");
        int digit_count = negative ? token.length() - 1 : token.length();
        bool overflow = false;
        if (digit_count > 19) {
            overflow = true;
        } else if (digit_count == 19) {
            // 19-digit values may or may not fit; compare against the
            // known int64 bounds textually.
            String digits = negative ? token.substr(1, token.length() - 1) : token;
            String max_digits = negative ? String("9223372036854775808") : String("9223372036854775807");
            if (digits > max_digits) {
                overflow = true;
            }
        }
        if (overflow) {
            UtilityFunctions::print("[vg_json_typed] Warning: integer overflow for '" +
                                    token + "', falling back to float");
            double fval = token.to_float();
            r_out = fval;
        } else {
            int64_t val = token.to_int();
            r_out = val;
        }
    }
    return true;
}

// ---------------------------------------------------------------------------
// Array parsing
// ---------------------------------------------------------------------------
static bool parse_array(JsonCursor &c, Variant &r_out, String &r_err, int depth) {
    Array arr;
    c.advance();
    c.skip_ws();
    if (c.match(']')) {
        r_out = arr;
        return true;
    }
    for (;;) {
        c.skip_ws();
        Variant elem;
        if (!parse_value(c, elem, r_err, depth)) return false;
        arr.append(elem);
        c.skip_ws();
        if (c.match(']')) {
            r_out = arr;
            return true;
        }
        if (!c.match(',')) {
            r_err = "Expected ',' or ']' in array";
            return false;
        }
    }
}

// ---------------------------------------------------------------------------
// Object parsing
// ---------------------------------------------------------------------------
static bool parse_object(JsonCursor &c, Variant &r_out, String &r_err, int depth) {
    Dictionary dict;
    c.advance();
    c.skip_ws();
    if (c.match('}')) {
        r_out = dict;
        return true;
    }
    for (;;) {
        c.skip_ws();
        if (c.peek() != '"') {
            r_err = "Expected string key in object";
            return false;
        }
        String key;
        if (!parse_string(c, key, r_err)) return false;
        c.skip_ws();
        if (!c.match(':')) {
            r_err = "Expected ':' in object";
            return false;
        }
        c.skip_ws();
        Variant val;
        if (!parse_value(c, val, r_err, depth)) return false;
        dict[key] = val;
        c.skip_ws();
        if (c.match('}')) {
            r_out = dict;
            return true;
        }
        if (!c.match(',')) {
            r_err = "Expected ',' or '}' in object";
            return false;
        }
    }
}

// ---------------------------------------------------------------------------
// Value dispatch
// ---------------------------------------------------------------------------
static bool parse_value(JsonCursor &c, Variant &r_out, String &r_err, int depth) {
    if (depth > 64) {
        r_err = "JSON recursion depth exceeded (max 64)";
        return false;
    }
    c.skip_ws();
    if (c.at_end()) {
        r_err = "Unexpected end of JSON";
        return false;
    }

    char32_t ch = c.peek();

    if (ch == '"') {
        String s;
        if (!parse_string(c, s, r_err)) return false;
        r_out = s;
        return true;
    }

    if (ch == '{') {
        return parse_object(c, r_out, r_err, depth + 1);
    }
    if (ch == '[') {
        return parse_array(c, r_out, r_err, depth + 1);
    }
    if (ch == 't') {
        if (c.str.substr(c.pos, 4) == "true") {
            c.pos += 4;
            r_out = true;
            return true;
        }
        r_err = "Expected 'true'";
        return false;
    }
    if (ch == 'f') {
        if (c.str.substr(c.pos, 5) == "false") {
            c.pos += 5;
            r_out = false;
            return true;
        }
        r_err = "Expected 'false'";
        return false;
    }
    if (ch == 'n') {
        if (c.str.substr(c.pos, 4) == "null") {
            c.pos += 4;
            r_out = Variant();
            return true;
        }
        r_err = "Expected 'null'";
        return false;
    }
    if (ch == '-' || (ch >= '0' && ch <= '9')) {
        return parse_number(c, r_out, r_err);
    }

    r_err = "Unexpected character";
    return false;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------
bool vg_json_parse_typed(const String &p_json, Variant &r_out, String &r_err_str) {
    if (p_json.is_empty()) {
        r_err_str = "Empty JSON string";
        return false;
    }

    JsonCursor cursor(p_json);
    bool ok = parse_value(cursor, r_out, r_err_str, 0);

    if (!ok) {
        r_out = Variant();
        return false;
    }

    cursor.skip_ws();
    if (!cursor.at_end()) {
        r_err_str = "Trailing data after JSON value";
        r_out = Variant();
        return false;
    }

    return true;
}

} // namespace godot
