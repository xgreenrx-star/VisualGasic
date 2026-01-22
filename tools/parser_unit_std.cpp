#include <iostream>
#include "standalone_tokenizer.h"
#include "parser_std_parser.h"

#include <fstream>
#include <sstream>

int main(int argc, char** argv) {
    bool json_mode = false;
    bool json_only = false;
    std::string input_file;
    for (int i=1;i<argc;i++) {
        std::string a = argv[i];
        if (a == "--json") json_mode = true;
        else if (a == "--json-only") { json_mode = true; json_only = true; }
        else if (a == "--input" && i+1<argc) { input_file = argv[++i]; }
        else input_file = a;
    }

    std::string src;
    if (!input_file.empty()) {
        std::ifstream f(input_file);
        if (!f) {
            std::cerr << "Failed to open input file: " << input_file << std::endl;
            return 2;
        }
        std::ostringstream ss; ss << f.rdbuf(); src = ss.str();
    } else {
        src = "Watch x do\n  Print \"changed\"\nEnd Watch\n\nWhenever x is >10 then\n  Print \"big\"\nEnd Whenever\n\nSub Foo\n  Print \"inside\"\nEnd Sub\n";
    }

    StandaloneTokenizer tok;
    auto tokens = tok.tokenize(src);

    ParserStd p(tokens);
    ParserStdResult r = p.parse();

    if (json_mode) {
        std::string json = ast_to_json(r);
        if (json_only) std::cout << json << std::endl;
        else std::cout << "[AST_JSON] " << json << std::endl;
        return 0;
    }

    std::cout << "[unit-std] tokenization complete. count=" << tokens.size() << std::endl;
    for (size_t i=0;i<tokens.size();i++) {
        auto &t = tokens[i];
        std::cout << "tok[" << i << "] type=" << StandaloneTokenizer::token_type_to_string(t.type) << " val='" << t.value << "' line=" << t.line << " col=" << t.column << std::endl;
    }

    std::cout << "[unit-std] running std-parser" << std::endl;

    std::cout << "Found " << r.watches.size() << " watch(es) and " << r.whenevers.size() << " whenever(s)" << std::endl;
    for (size_t i=0;i<r.watches.size();i++) {
        auto &w = r.watches[i];
        std::cout << "Watch: var='" << w.var << "' once=" << (w.once?"true":"false") << " local=" << (w.local?"true":"false") << " lines=" << w.start_line << "-" << w.end_line << std::endl;
        for (auto &ln : w.body_lines) std::cout << "  body: " << ln << std::endl;
    }

    for (size_t i=0;i<r.whenevers.size();i++) {
        auto &w = r.whenevers[i];
        std::cout << "Whenever on var='" << w.var << "' lines=" << w.start_line << "-" << w.end_line << std::endl;
        for (size_t bi=0;bi<w.branches.size();bi++) {
            auto &br = w.branches[bi];
            std::cout << "  branch[" << bi << "] pattern='" << br.pattern << "'" << std::endl;
            for (auto &ln : br.body_lines) std::cout << "    body: " << ln << std::endl;
        }
    }

    return 0;
}
