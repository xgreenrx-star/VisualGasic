#include "parser_std_parser.h"
#include <algorithm>

static inline std::string to_lower(const std::string &s) {
    std::string r = s;
    std::transform(r.begin(), r.end(), r.begin(), [](unsigned char c){ return std::tolower(c); });
    return r;
}

ParserStd::ParserStd(const std::vector<StandaloneTokenizer::Token>& toks) : tokens(toks), pos(0) {}

const StandaloneTokenizer::Token& ParserStd::peek(int offset) const {
    size_t idx = pos + offset;
    static StandaloneTokenizer::Token eof_token{StandaloneTokenizer::TOKEN_EOF, "", 0, 0};
    if (idx >= tokens.size()) return eof_token;
    return tokens[idx];
}

const StandaloneTokenizer::Token& ParserStd::advance() {
    const auto &t = peek();
    if (!is_at_end()) pos++;
    return t;
}

bool ParserStd::check(StandaloneTokenizer::TokenType t) const {
    return peek().type == t;
}

bool ParserStd::is_at_end() const {
    return peek().type == StandaloneTokenizer::TOKEN_EOF;
}

void ParserStd::consume_newline() {
    if (check(StandaloneTokenizer::TOKEN_NEWLINE)) advance();
}

bool ParserStd::is_keyword(const StandaloneTokenizer::Token& t, const std::string &kw) const {
    if (t.type != StandaloneTokenizer::TOKEN_KEYWORD && t.type != StandaloneTokenizer::TOKEN_IDENTIFIER) return false;
    return to_lower(t.value) == to_lower(kw);
}

ParserStdResult ParserStd::parse() {
    ParserStdResult res;
    while (!is_at_end()) {
        const auto &t = peek();
        if (t.type == StandaloneTokenizer::TOKEN_NEWLINE) { advance(); continue; }
        if ((t.type == StandaloneTokenizer::TOKEN_KEYWORD || t.type == StandaloneTokenizer::TOKEN_IDENTIFIER) && to_lower(t.value) == "watch") {
            WatchEntry w = parse_watch();
            res.watches.push_back(std::move(w));
            continue;
        }
        if ((t.type == StandaloneTokenizer::TOKEN_KEYWORD || t.type == StandaloneTokenizer::TOKEN_IDENTIFIER) && to_lower(t.value) == "whenever") {
            WheneverEntry w = parse_whenever();
            res.whenevers.push_back(std::move(w));
            continue;
        }
        // Unknown top-level - skip token
        advance();
    }
    return res;
}

WatchEntry ParserStd::parse_watch() {
    WatchEntry out;
    const auto &start = peek();
    out.start_line = start.line;
    advance(); // consume 'Watch'

    if (check(StandaloneTokenizer::TOKEN_IDENTIFIER)) {
        out.var = peek().value;
        advance();
    } else {
        // malformed - return empty
    }

    // optional modifiers once/local
    if (check(StandaloneTokenizer::TOKEN_KEYWORD)) {
        std::string mod = to_lower(peek().value);
        if (mod == "once") { out.once = true; advance(); }
        else if (mod == "local") { out.local = true; advance(); }
    }

    // expect do (keyword or identifier)
    if ((check(StandaloneTokenizer::TOKEN_KEYWORD) || check(StandaloneTokenizer::TOKEN_IDENTIFIER)) && to_lower(peek().value) == "do") {
        advance();
    }
    // eat optional newline
    consume_newline();

    // read body until End Watch
    while (!is_at_end()) {
        if ((peek().type == StandaloneTokenizer::TOKEN_KEYWORD || peek().type == StandaloneTokenizer::TOKEN_IDENTIFIER) && to_lower(peek().value) == "end") {
            // check "End Watch"
            if (peek(1).type == StandaloneTokenizer::TOKEN_KEYWORD || peek(1).type == StandaloneTokenizer::TOKEN_IDENTIFIER) {
                if (to_lower(peek(1).value) == "watch") {
                    advance(); // end
                    advance(); // watch
                    break;
                }
            }
        }
        // collect a line: read until newline
        std::string line;
        while (!is_at_end() && peek().type != StandaloneTokenizer::TOKEN_NEWLINE) {
            if (!line.empty()) line += " ";
            line += peek().value;
            advance();
        }
        if (!line.empty()) out.body_lines.push_back(line);
        consume_newline();
    }
    out.end_line = peek().line;
    return out;
}

WheneverEntry ParserStd::parse_whenever() {
    WheneverEntry out;
    const auto &start = peek();
    out.start_line = start.line;
    advance(); // consume 'Whenever'

    if (check(StandaloneTokenizer::TOKEN_IDENTIFIER)) {
        out.var = peek().value;
        advance();
    }
    // expect 'is' (keyword or identifier)
    if ((check(StandaloneTokenizer::TOKEN_KEYWORD) || check(StandaloneTokenizer::TOKEN_IDENTIFIER)) && to_lower(peek().value) == "is") advance();
    // allow optional newline
    consume_newline();

    // parse branches until End Whenever
    while (!is_at_end()) {
        // detect End Whenever
        if ((peek().type == StandaloneTokenizer::TOKEN_KEYWORD || peek().type == StandaloneTokenizer::TOKEN_IDENTIFIER) && to_lower(peek().value) == "end") {
            if (peek(1).type == StandaloneTokenizer::TOKEN_KEYWORD || peek(1).type == StandaloneTokenizer::TOKEN_IDENTIFIER) {
                if (to_lower(peek(1).value) == "whenever") { advance(); advance(); break; }
            }
        }

        // handle '_' else branch
        if ((peek().type == StandaloneTokenizer::TOKEN_IDENTIFIER || peek().type == StandaloneTokenizer::TOKEN_OPERATOR) && peek().value == "_") {
            advance(); // consume _
            // optional then
            if (check(StandaloneTokenizer::TOKEN_KEYWORD) && to_lower(peek().value) == "then") advance();
            consume_newline();
            WheneverBranch br; br.pattern = "_";
            while (!is_at_end() && !( (peek().type == StandaloneTokenizer::TOKEN_KEYWORD || peek().type == StandaloneTokenizer::TOKEN_IDENTIFIER) && (to_lower(peek().value) == "end" || peek().value == "_"))) {
                std::string line;
                while (!is_at_end() && peek().type != StandaloneTokenizer::TOKEN_NEWLINE) { if (!line.empty()) line += " "; line += peek().value; advance(); }
                if (!line.empty()) br.body_lines.push_back(line);
                consume_newline();
            }
            out.branches.push_back(std::move(br));
            continue;
        }

        // parse pattern tokens until 'then'
        std::string pat;
        while (!is_at_end() && !(peek().type == StandaloneTokenizer::TOKEN_KEYWORD && to_lower(peek().value) == "then")) {
            if (!pat.empty()) pat += " ";
            pat += peek().value;
            advance();
        }
        // consume 'then'
        if (check(StandaloneTokenizer::TOKEN_KEYWORD) && to_lower(peek().value) == "then") advance();
        consume_newline();

        // parse body
        WheneverBranch br; br.pattern = pat;
        while (!is_at_end()) {
            if ((peek().type == StandaloneTokenizer::TOKEN_KEYWORD || peek().type == StandaloneTokenizer::TOKEN_IDENTIFIER) && (to_lower(peek().value) == "end" || peek().value == "_")) break;
            std::string line;
            while (!is_at_end() && peek().type != StandaloneTokenizer::TOKEN_NEWLINE) { if (!line.empty()) line += " "; line += peek().value; advance(); }
            if (!line.empty()) br.body_lines.push_back(line);
            consume_newline();
        }
        out.branches.push_back(std::move(br));
    }

    out.end_line = peek().line;
    return out;
}
