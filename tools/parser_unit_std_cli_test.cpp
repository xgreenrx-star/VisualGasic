#include <iostream>
#include <cstdio>
#include <memory>
#include <array>

static std::string run_cmd(const std::string &cmd) {
    std::array<char, 512> buf;
    std::string out;
    FILE *fp = popen(cmd.c_str(), "r");
    if (!fp) return out;
    while (fgets(buf.data(), (int)buf.size(), fp)) out += buf.data();
    pclose(fp);
    return out;
}

int main() {
    std::string out = run_cmd("./tools/parser_unit_std --json");
    if (out.find("{\"nodes\"") == std::string::npos) {
        std::cerr << "CLI JSON not found in output:\n" << out << std::endl;
        return 1;
    }
    std::cout << "[cli-test] JSON present" << std::endl;
    return 0;
}
