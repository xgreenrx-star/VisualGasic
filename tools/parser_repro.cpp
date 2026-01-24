#include <iostream>
#include <fstream>
#include <string>

#include "visual_gasic_tokenizer.h"
#include "visual_gasic_parser.h"

int main(int argc, char **argv) {
    if (argc < 2) {
        std::cerr << "Usage: parser_repro <file.bas>" << std::endl;
        return 2;
    }

    std::ifstream in(argv[1]);
    if (!in.is_open()) {
        std::cerr << "Failed to open " << argv[1] << std::endl;
        return 2;
    }

    std::string content((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
    godot::String code(content.c_str());

    VisualGasicTokenizer tok;
    auto tokens = tok.tokenize(code);
    std::cout << "Tokenizer produced " << tokens.size() << " tokens. Last token type: " << tok.token_type_to_string(tokens[tokens.size()-1].type).utf8().get_data() << std::endl;

    VisualGasicParser parser;
    ModuleNode *module = parser.parse(tokens);
    if (!module) {
        std::cerr << "Parse failed, errors: " << parser.errors->size() << std::endl;
        for (size_t i = 0; i < parser.errors->size(); ++i) {
            std::cerr << " Error[" << i << "] line=" << (*parser.errors)[i].line << " col=" << (*parser.errors)[i].column << " msg='" << (*parser.errors)[i].message << "'" << std::endl;
        }
        return 1;
    }

    std::cout << "Parse succeeded. Module contains: subs=" << module->subs.size() << " vars=" << module->variables.size() << std::endl;

    // Clean up and exit
    delete module;

    return 0;
}
