// Lightweight bytecode-oriented regression tests for the VisualGasic VM.

#include <iostream>
#include <functional>
#include <vector>

#include "visual_gasic_instance.h"
#include "visual_gasic_script.h"
#include "visual_gasic_bytecode.h"

using namespace godot;

namespace {

struct TestCase {
    const char *name;
    std::function<bool()> fn;
};

void push_byte(BytecodeChunk &chunk, uint8_t byte) {
    chunk.write(byte, 0);
}

BytecodeChunk make_chunk(const std::vector<uint8_t> &bytes, const std::vector<Variant> &constants, int locals = 0, const std::vector<String> &local_names = {}) {
    BytecodeChunk chunk;
    for (const Variant &value : constants) {
        chunk.constants.push_back(value);
    }
    chunk.local_count = locals;
    for (const String &name : local_names) {
        chunk.local_names.push_back(name);
        chunk.local_types.push_back(0);
    }
    for (uint8_t byte : bytes) {
        push_byte(chunk, byte);
    }
    return chunk;
}

bool run_chunk(BytecodeChunk &chunk, Variant &ret) {
    Ref<VisualGasicScript> script; // invalid -> avoids constructor side effects
    VisualGasicInstance instance(script, nullptr);
    return instance.execute_bytecode(&chunk, nullptr, ret);
}

bool test_bytecode_addition() {
    BytecodeChunk chunk;
    int idx_two = chunk.add_constant((int64_t)2);
    int idx_three = chunk.add_constant((int64_t)3);

    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_two);
    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_three);
    push_byte(chunk, OP_ADD_I64);
    push_byte(chunk, OP_RETURN_VALUE);

    Variant ret;
    bool ok = run_chunk(chunk, ret);
    return ok && ret.get_type() == Variant::INT && (int64_t)ret == 5;
}

bool test_bytecode_locals() {
    BytecodeChunk chunk;
    chunk.local_count = 1;
    chunk.local_names.push_back("result");
    chunk.local_types.push_back(0);
    int idx_ten = chunk.add_constant((int64_t)10);
    int idx_five = chunk.add_constant((int64_t)5);

    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_ten);
    push_byte(chunk, OP_SET_LOCAL);
    push_byte(chunk, 0);
    push_byte(chunk, OP_GET_LOCAL);
    push_byte(chunk, 0);
    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_five);
    push_byte(chunk, OP_ADD_I64);
    push_byte(chunk, OP_RETURN_VALUE);

    Variant ret;
    bool ok = run_chunk(chunk, ret);
    return ok && ret.get_type() == Variant::INT && (int64_t)ret == 15;
}

bool test_bytecode_conditionals() {
    BytecodeChunk chunk;
    int idx_one = chunk.add_constant((int64_t)1);
    int idx_zero = chunk.add_constant((int64_t)0);
    int idx_true_value = chunk.add_constant((int64_t)42);
    int idx_fallback = chunk.add_constant((int64_t)-1);

    push_byte(chunk, OP_CONSTANT); // push 1
    push_byte(chunk, (uint8_t)idx_one);
    push_byte(chunk, OP_CONSTANT); // push 0
    push_byte(chunk, (uint8_t)idx_zero);
    push_byte(chunk, OP_GREATER);
    push_byte(chunk, OP_JUMP_IF_FALSE);
    push_byte(chunk, 0x00);
    push_byte(chunk, 0x03); // skip next 3 bytes if condition is false
    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_true_value);
    push_byte(chunk, OP_RETURN_VALUE);
    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_fallback);
    push_byte(chunk, OP_RETURN_VALUE);

    Variant ret;
    bool ok = run_chunk(chunk, ret);
    return ok && ret.get_type() == Variant::INT && (int64_t)ret == 42;
}

bool test_bytecode_array_ops() {
    BytecodeChunk chunk;
    int idx_len = chunk.add_constant((int64_t)3);
    int idx_arr_name = chunk.add_constant(String("testArray"));
    int idx_zero = chunk.add_constant((int64_t)0);
    int idx_value = chunk.add_constant((int64_t)99);

    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_len);
    push_byte(chunk, OP_NEW_ARRAY);
    push_byte(chunk, OP_SET_GLOBAL);
    push_byte(chunk, (uint8_t)idx_arr_name);

    push_byte(chunk, OP_GET_GLOBAL);
    push_byte(chunk, (uint8_t)idx_arr_name);
    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_zero);
    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_value);
    push_byte(chunk, OP_SET_ARRAY);
    push_byte(chunk, 1);
    push_byte(chunk, OP_POP);

    push_byte(chunk, OP_GET_GLOBAL);
    push_byte(chunk, (uint8_t)idx_arr_name);
    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_zero);
    push_byte(chunk, OP_GET_ARRAY);
    push_byte(chunk, 1);
    push_byte(chunk, OP_RETURN_VALUE);

    Variant ret;
    bool ok = run_chunk(chunk, ret);
    return ok && ret.get_type() == Variant::INT && (int64_t)ret == 99;
}

} // namespace

int run_all_integration_tests() {
    std::vector<TestCase> tests = {
        {"Bytecode integer addition", test_bytecode_addition},
        {"Bytecode local arithmetic", test_bytecode_locals},
        {"Bytecode conditional flow", test_bytecode_conditionals},
        {"Bytecode array operations", test_bytecode_array_ops},
    };

    int passed = 0;
    for (const TestCase &test : tests) {
        bool ok = false;
        try {
            ok = test.fn();
        } catch (...) {
            ok = false;
        }
        std::cout << (ok ? "[PASS] " : "[FAIL] ") << test.name << std::endl;
        if (ok) {
            passed++;
        }
    }

    std::cout << "\n" << passed << "/" << tests.size() << " tests passed" << std::endl;
    return passed == (int)tests.size() ? 0 : 1;
}

int main() {
    return run_all_integration_tests();
}
