#include "parser_std_parser.h"
#include <algorithm>
#include <memory>
#include <sstream>
#include <cstdio>

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
            // push both entry and AST node
            res.watches.push_back(std::move(w));
            auto node = std::make_unique<ASTWatch>();
            node->var = res.watches.back().var;
            node->once = res.watches.back().once;
            node->local = res.watches.back().local;
            node->body_lines = res.watches.back().body_lines;
            res.ast_nodes.push_back(std::move(node));
            continue;
        }
        if ((t.type == StandaloneTokenizer::TOKEN_KEYWORD || t.type == StandaloneTokenizer::TOKEN_IDENTIFIER) && to_lower(t.value) == "whenever") {
            WheneverEntry w = parse_whenever();
            res.whenevers.push_back(std::move(w));
            auto node = std::make_unique<ASTWhenever>();
            node->var = res.whenevers.back().var;
            node->branches = res.whenevers.back().branches;
            res.ast_nodes.push_back(std::move(node));
            continue;
        }
        if ((t.type == StandaloneTokenizer::TOKEN_KEYWORD || t.type == StandaloneTokenizer::TOKEN_IDENTIFIER) && to_lower(t.value) == "sub") {
            SubEntry s = parse_sub();
            res.subs.push_back(std::move(s));
            auto node = std::make_unique<ASTSub>();
            node->name = res.subs.back().name;
            node->body_lines = res.subs.back().body_lines;
            res.ast_nodes.push_back(std::move(node));
            continue;
        }
        if ((t.type == StandaloneTokenizer::TOKEN_KEYWORD || t.type == StandaloneTokenizer::TOKEN_IDENTIFIER) && to_lower(t.value) == "if") {
            IfEntry it = parse_if();
            res.ifs.push_back(std::move(it));
            auto node = std::make_unique<ASTIf>();
            node->condition = res.ifs.back().condition;
            node->body_lines = res.ifs.back().body_lines;
            res.ast_nodes.push_back(std::move(node));
            continue;
        }
        if ((t.type == StandaloneTokenizer::TOKEN_KEYWORD || t.type == StandaloneTokenizer::TOKEN_IDENTIFIER) && to_lower(t.value) == "function") {
            FunctionEntry f = parse_function();
            res.functions.push_back(std::move(f));
            auto node = std::make_unique<ASTFunction>();
            node->name = res.functions.back().name;
            node->body_lines = res.functions.back().body_lines;
            res.ast_nodes.push_back(std::move(node));
            continue;
        }
        if ((t.type == StandaloneTokenizer::TOKEN_KEYWORD || t.type == StandaloneTokenizer::TOKEN_IDENTIFIER) && to_lower(t.value) == "for") {
            ForEntry fr = parse_for();
            res.fors.push_back(std::move(fr));
            auto node = std::make_unique<ASTFor>();
            node->var = res.fors.back().var;
            node->start_expr = res.fors.back().start_expr;
            node->end_expr = res.fors.back().end_expr;
            node->body_lines = res.fors.back().body_lines;
            res.ast_nodes.push_back(std::move(node));
            continue;
        }
        if ((t.type == StandaloneTokenizer::TOKEN_KEYWORD || t.type == StandaloneTokenizer::TOKEN_IDENTIFIER) && to_lower(t.value) == "while") {
            WhileEntry wh = parse_while();
            res.whiles.push_back(std::move(wh));
            auto node = std::make_unique<ASTWhile>();
            node->condition = res.whiles.back().condition;
            node->body_lines = res.whiles.back().body_lines;
            res.ast_nodes.push_back(std::move(node));
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

    // New additions: parse_sub and parse_if implementations
}

SubEntry ParserStd::parse_sub() {
    SubEntry out;
    const auto &start = peek();
    out.start_line = start.line;
    advance(); // consume 'Sub'

    if (check(StandaloneTokenizer::TOKEN_IDENTIFIER)) {
        out.name = peek().value;
        advance();
    }
    // consume rest of line if any
    while (!is_at_end() && peek().type != StandaloneTokenizer::TOKEN_NEWLINE) advance();
    consume_newline();

    // read body until End Sub
    while (!is_at_end()) {
        if ((peek().type == StandaloneTokenizer::TOKEN_KEYWORD || peek().type == StandaloneTokenizer::TOKEN_IDENTIFIER) && to_lower(peek().value) == "end") {
            if (peek(1).type == StandaloneTokenizer::TOKEN_KEYWORD || peek(1).type == StandaloneTokenizer::TOKEN_IDENTIFIER) {
                if (to_lower(peek(1).value) == "sub") { advance(); advance(); break; }
            }
        }
        std::string line;
        while (!is_at_end() && peek().type != StandaloneTokenizer::TOKEN_NEWLINE) { if (!line.empty()) line += " "; line += peek().value; advance(); }
        if (!line.empty()) out.body_lines.push_back(line);
        consume_newline();
    }
    out.end_line = peek().line;
    return out;
}

IfEntry ParserStd::parse_if() {
    IfEntry out;
    const auto &start = peek();
    out.start_line = start.line;
    advance(); // consume 'If'

    // collect condition until 'Then'
    std::string cond;
    while (!is_at_end() && !(peek().type == StandaloneTokenizer::TOKEN_KEYWORD && to_lower(peek().value) == "then")) {
        if (!cond.empty()) cond += " ";
        cond += peek().value;
        advance();
    }
    out.condition = cond;
    // consume 'Then' if present
    if ((peek().type == StandaloneTokenizer::TOKEN_KEYWORD || peek().type == StandaloneTokenizer::TOKEN_IDENTIFIER) && to_lower(peek().value) == "then") advance();
    consume_newline();

    // read body until End If
    while (!is_at_end()) {
        if ((peek().type == StandaloneTokenizer::TOKEN_KEYWORD || peek().type == StandaloneTokenizer::TOKEN_IDENTIFIER) && to_lower(peek().value) == "end") {
            if (peek(1).type == StandaloneTokenizer::TOKEN_KEYWORD || peek(1).type == StandaloneTokenizer::TOKEN_IDENTIFIER) {
                if (to_lower(peek(1).value) == "if") { advance(); advance(); break; }
            }
        }
        std::string line;
        while (!is_at_end() && peek().type != StandaloneTokenizer::TOKEN_NEWLINE) { if (!line.empty()) line += " "; line += peek().value; advance(); }
        if (!line.empty()) out.body_lines.push_back(line);
        consume_newline();
    }
    out.end_line = peek().line;
    return out;
}

FunctionEntry ParserStd::parse_function() {
    FunctionEntry out;
    const auto &start = peek();
    out.start_line = start.line;
    advance(); // consume 'Function'

    if (check(StandaloneTokenizer::TOKEN_IDENTIFIER)) {
        out.name = peek().value;
        advance();
    }
    // consume rest of line if any
    while (!is_at_end() && peek().type != StandaloneTokenizer::TOKEN_NEWLINE) advance();
    consume_newline();

    // read body until End Function
    while (!is_at_end()) {
        if ((peek().type == StandaloneTokenizer::TOKEN_KEYWORD || peek().type == StandaloneTokenizer::TOKEN_IDENTIFIER) && to_lower(peek().value) == "end") {
            if (peek(1).type == StandaloneTokenizer::TOKEN_KEYWORD || peek(1).type == StandaloneTokenizer::TOKEN_IDENTIFIER) {
                if (to_lower(peek(1).value) == "function") { advance(); advance(); break; }
            }
        }
        std::string line;
        while (!is_at_end() && peek().type != StandaloneTokenizer::TOKEN_NEWLINE) { if (!line.empty()) line += " "; line += peek().value; advance(); }
        if (!line.empty()) out.body_lines.push_back(line);
        consume_newline();
    }
    out.end_line = peek().line;
    return out;
}

ForEntry ParserStd::parse_for() {
    ForEntry out;
    const auto &start = peek();
    out.start_line = start.line;
    advance(); // consume 'For'

    // parse header until newline e.g. "i = 1 To 10" or "i 1 To 10"
    std::string hdr;
    while (!is_at_end() && peek().type != StandaloneTokenizer::TOKEN_NEWLINE) { if (!hdr.empty()) hdr += " "; hdr += peek().value; advance(); }
    consume_newline();

    // Attempt to split header by 'To'
    size_t pos_to = std::string::npos;
    {
        std::string lo = to_lower(hdr);
        pos_to = lo.find(" to ");
    }
    if (pos_to != std::string::npos) {
        std::string left = hdr.substr(0, pos_to);
        std::string right = hdr.substr(pos_to + 4);
        // left may be "i = 1" or "i 1". extract var and start
        size_t eq = left.find("=");
        if (eq != std::string::npos) {
            out.var = left.substr(0, eq);
            out.start_expr = left.substr(eq+1);
        } else {
            // split by space
            size_t sp = left.find(' ');
            if (sp != std::string::npos) {
                out.var = left.substr(0, sp);
                out.start_expr = left.substr(sp+1);
            } else {
                out.var = left;
            }
        }
        out.end_expr = right;
    } else {
        out.var = hdr;
    }

    // parse body until Next
    while (!is_at_end()) {
        if ((peek().type == StandaloneTokenizer::TOKEN_KEYWORD || peek().type == StandaloneTokenizer::TOKEN_IDENTIFIER) && to_lower(peek().value) == "next") { advance(); break; }
        std::string line;
        while (!is_at_end() && peek().type != StandaloneTokenizer::TOKEN_NEWLINE) { if (!line.empty()) line += " "; line += peek().value; advance(); }
        if (!line.empty()) out.body_lines.push_back(line);
        consume_newline();
    }
    out.end_line = peek().line;
    return out;
}

WhileEntry ParserStd::parse_while() {
    WhileEntry out;
    const auto &start = peek();
    out.start_line = start.line;
    advance(); // consume 'While'

    // collect condition until newline
    std::string cond;
    while (!is_at_end() && peek().type != StandaloneTokenizer::TOKEN_NEWLINE) { if (!cond.empty()) cond += " "; cond += peek().value; advance(); }
    out.condition = cond;
    consume_newline();

    // read body until Wend or End While
    while (!is_at_end()) {
        if ((peek().type == StandaloneTokenizer::TOKEN_KEYWORD || peek().type == StandaloneTokenizer::TOKEN_IDENTIFIER) && (to_lower(peek().value) == "wend" || (to_lower(peek().value) == "end" && (peek(1).type == StandaloneTokenizer::TOKEN_KEYWORD || peek(1).type == StandaloneTokenizer::TOKEN_IDENTIFIER) && to_lower(peek(1).value)=="while"))) {
            if (to_lower(peek().value) == "wend") { advance(); break; }
            if (to_lower(peek().value) == "end") { advance(); advance(); break; }
        }
        std::string line;
        while (!is_at_end() && peek().type != StandaloneTokenizer::TOKEN_NEWLINE) { if (!line.empty()) line += " "; line += peek().value; advance(); }
        if (!line.empty()) out.body_lines.push_back(line);
        consume_newline();
    }
    out.end_line = peek().line;
    return out;
}


// JSON serialization helpers
static std::string escape_json(const std::string &s) {
    std::string o; o.reserve(s.size());
    for (unsigned char c : s) {
        switch (c) {
            case '"': o += "\\\""; break;
            case '\\': o += "\\\\"; break;
            case '\b': o += "\\b"; break;
            case '\f': o += "\\f"; break;
            case '\n': o += "\\n"; break;
            case '\r': o += "\\r"; break;
            case '\t': o += "\\t"; break;
            default:
                if (c < 0x20) {
                    char buf[7]; snprintf(buf, sizeof(buf), "\\u%04x", c);
                    o += buf;
                } else {
                    o += (char)c;
                }
        }
    }
    return o;
}

std::string ast_to_json(const ParserStdResult &r) {
    std::ostringstream out;
    out << "{\"nodes\":[";
    bool first = true;
    for (auto &nptr : r.ast_nodes) {
        if (!first) out << ',';
        first = false;
        switch (nptr->type) {
            case AST_WATCH: {
                ASTWatch *w = static_cast<ASTWatch*>(nptr.get());
                out << "{\"type\":\"Watch\",\"var\":\"" << escape_json(w->var) << "\",\"once\":" << (w->once?"true":"false") << ",\"local\":" << (w->local?"true":"false") << ",\"body\":[";
                for (size_t i=0;i<w->body_lines.size();i++) {
                    if (i) out << ',';
                    out << '"' << escape_json(w->body_lines[i]) << '"';
                }
                out << "]}";
                break; }
            case AST_WHENEVER: {
                ASTWhenever *aw = static_cast<ASTWhenever*>(nptr.get());
                out << "{\"type\":\"Whenever\",\"var\":\"" << escape_json(aw->var) << "\",\"branches\":[";
                for (size_t i=0;i<aw->branches.size();i++) {
                    if (i) out << ',';
                    out << "{\"pattern\":\"" << escape_json(aw->branches[i].pattern) << "\",\"body\":[";
                    for (size_t j=0;j<aw->branches[i].body_lines.size();j++) { if (j) out << ','; out << '"' << escape_json(aw->branches[i].body_lines[j]) << '"'; }
                    out << "]}";
                }
                out << "]}";
                break; }
            case AST_SUB: {
                ASTSub *as = static_cast<ASTSub*>(nptr.get());
                out << "{\"type\":\"Sub\",\"name\":\"" << escape_json(as->name) << "\",\"body\":[";
                for (size_t i=0;i<as->body_lines.size();i++) { if (i) out << ','; out << '"' << escape_json(as->body_lines[i]) << '"'; }
                out << "]}";
                break; }
            case AST_IF: {
                ASTIf *ai = static_cast<ASTIf*>(nptr.get());
                out << "{\"type\":\"If\",\"cond\":\"" << escape_json(ai->condition) << "\",\"body\":[";
                for (size_t i=0;i<ai->body_lines.size();i++) { if (i) out << ','; out << '"' << escape_json(ai->body_lines[i]) << '"'; }
                out << "]}";
                break; }
            case AST_FUNCTION: {
                ASTFunction *af = static_cast<ASTFunction*>(nptr.get());
                out << "{\"type\":\"Function\",\"name\":\"" << escape_json(af->name) << "\",\"body\":[";
                for (size_t i=0;i<af->body_lines.size();i++) { if (i) out << ','; out << '"' << escape_json(af->body_lines[i]) << '"'; }
                out << "]}";
                break; }
            case AST_FOR: {
                ASTFor *af = static_cast<ASTFor*>(nptr.get());
                out << "{\"type\":\"For\",\"var\":\"" << escape_json(af->var) << "\",\"start\":\"" << escape_json(af->start_expr) << "\",\"end\":\"" << escape_json(af->end_expr) << "\",\"body\":[";
                for (size_t i=0;i<af->body_lines.size();i++) { if (i) out << ','; out << '"' << escape_json(af->body_lines[i]) << '"'; }
                out << "]}";
                break; }
            case AST_WHILE: {
                ASTWhile *aw = static_cast<ASTWhile*>(nptr.get());
                out << "{\"type\":\"While\",\"cond\":\"" << escape_json(aw->condition) << "\",\"body\":[";
                for (size_t i=0;i<aw->body_lines.size();i++) { if (i) out << ','; out << '"' << escape_json(aw->body_lines[i]) << '"'; }
                out << "]}";
                break; }
            default: break;
        }
    }
    out << "]}";
    return out.str();
}
