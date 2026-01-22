#include <iostream>
#include "standalone_tokenizer.h"
#include "parser_std_parser.h"

int main() {
    std::string src = "Watch x do\n  Print \"changed\"\nEnd Watch\n\nWhenever x is >10 then\n  Print \"big\"\nEnd Whenever\n";
    std::cout << "[unit-std] starting tokenization" << std::endl;
    StandaloneTokenizer tok;
    auto tokens = tok.tokenize(src);
    std::cout << "[unit-std] tokenization complete. count=" << tokens.size() << std::endl;
    for (size_t i=0;i<tokens.size();i++) {
        auto &t = tokens[i];
        std::cout << "tok[" << i << "] type=" << StandaloneTokenizer::token_type_to_string(t.type) << " val='" << t.value << "' line=" << t.line << " col=" << t.column << std::endl;
    }

    std::cout << "[unit-std] running std-parser" << std::endl;
    ParserStd p(tokens);
    ParserStdResult r = p.parse();

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
