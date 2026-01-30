#include "visual_gasic_test_runner.h"

#include "visual_gasic_instance.h"
#include "visual_gasic_script.h"
#include "visual_gasic_bytecode.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <functional>
#include <vector>

using namespace godot;

namespace {

void push_byte(BytecodeChunk &chunk, uint8_t byte) {
    chunk.write(byte, 0);
}

bool run_chunk(BytecodeChunk &chunk, Variant &ret, String &error) {
    Ref<VisualGasicScript> script;
    VisualGasicInstance instance(script, nullptr);
    if (!instance.execute_bytecode(&chunk, nullptr, ret)) {
        error = "execute_bytecode() returned false";
        return false;
    }
    return true;
}

String format_value(const Variant &value) {
    return String(value);
}

bool test_bytecode_addition(String &err) {
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
    if (!run_chunk(chunk, ret, err)) {
        return false;
    }

    if (ret.get_type() != Variant::INT || (int64_t)ret != 5) {
        err = String("Expected 5, got ") + format_value(ret);
        return false;
    }
    return true;
}

bool test_bytecode_locals(String &err) {
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
    if (!run_chunk(chunk, ret, err)) {
        return false;
    }

    if (ret.get_type() != Variant::INT || (int64_t)ret != 15) {
        err = String("Expected 15, got ") + format_value(ret);
        return false;
    }
    return true;
}

bool test_bytecode_conditionals(String &err) {
    BytecodeChunk chunk;
    int idx_one = chunk.add_constant((int64_t)1);
    int idx_zero = chunk.add_constant((int64_t)0);
    int idx_true_value = chunk.add_constant((int64_t)42);
    int idx_fallback = chunk.add_constant((int64_t)-1);

    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_one);
    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_zero);
    push_byte(chunk, OP_GREATER);
    push_byte(chunk, OP_JUMP_IF_FALSE);
    push_byte(chunk, 0x00);
    push_byte(chunk, 0x03);
    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_true_value);
    push_byte(chunk, OP_RETURN_VALUE);
    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_fallback);
    push_byte(chunk, OP_RETURN_VALUE);

    Variant ret;
    if (!run_chunk(chunk, ret, err)) {
        return false;
    }

    if (ret.get_type() != Variant::INT || (int64_t)ret != 42) {
        err = String("Expected 42, got ") + format_value(ret);
        return false;
    }
    return true;
}

bool test_bytecode_array_ops(String &err) {
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
    if (!run_chunk(chunk, ret, err)) {
        return false;
    }

    if (ret.get_type() != Variant::INT || (int64_t)ret != 99) {
        err = String("Expected 99, got ") + format_value(ret);
        return false;
    }
    return true;
}

bool test_bytecode_interop_name_len(String &err) {
    BytecodeChunk chunk;
    chunk.local_count = 1;
    chunk.local_names.push_back("sum");
    chunk.local_types.push_back(0);

    int idx_zero = chunk.add_constant((int64_t)0);
    int idx_inner_to = chunk.add_constant((int64_t)3);
    int idx_outer_to = chunk.add_constant((int64_t)1);
    int idx_literal = chunk.add_constant(String("abc"));

    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_zero);
    push_byte(chunk, OP_SET_LOCAL);
    push_byte(chunk, 0);

    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_inner_to);
    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_outer_to);
    push_byte(chunk, OP_INTEROP_SET_NAME_LEN);
    push_byte(chunk, 0);
    push_byte(chunk, (uint8_t)idx_literal);
    push_byte(chunk, OP_SET_LOCAL);
    push_byte(chunk, 0);

    push_byte(chunk, OP_GET_LOCAL);
    push_byte(chunk, 0);
    push_byte(chunk, OP_RETURN_VALUE);

    Variant ret;
    if (!run_chunk(chunk, ret, err)) {
        return false;
    }

    int64_t expected = 3 * 4 * 2; // literal len * inner iterations * outer iterations
    if (ret.get_type() != Variant::INT || (int64_t)ret != expected) {
        err = String("Expected ") + String::num_int64(expected) + ", got " + format_value(ret);
        return false;
    }
    return true;
}

bool test_bytecode_alloc_fill_i64(String &err) {
    BytecodeChunk chunk;
    chunk.local_count = 1;
    chunk.local_names.push_back("arr");
    chunk.local_types.push_back(0);

    int idx_size = chunk.add_constant((int64_t)5);
    int idx_index = chunk.add_constant((int64_t)4);

    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_size);
    push_byte(chunk, OP_ALLOC_FILL_I64);
    push_byte(chunk, OP_SET_LOCAL);
    push_byte(chunk, 0);

    push_byte(chunk, OP_GET_LOCAL);
    push_byte(chunk, 0);
    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_index);
    push_byte(chunk, OP_GET_ARRAY);
    push_byte(chunk, 1);
    push_byte(chunk, OP_RETURN_VALUE);

    Variant ret;
    if (!run_chunk(chunk, ret, err)) {
        return false;
    }

    if (ret.get_type() != Variant::INT || (int64_t)ret != 4) {
        err = String("Expected 4, got ") + format_value(ret);
        return false;
    }
    return true;
}

bool test_bytecode_sum_dict(String &err) {
    BytecodeChunk chunk;
    Dictionary dict;
    dict["a"] = (int64_t)5;
    dict["b"] = (int64_t)7;
    int idx_dict = chunk.add_constant(dict);

    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_dict);
    push_byte(chunk, OP_SUM_DICT_I64);
    push_byte(chunk, OP_RETURN_VALUE);

    Variant ret;
    if (!run_chunk(chunk, ret, err)) {
        return false;
    }

    if (ret.get_type() != Variant::INT || (int64_t)ret != 12) {
        err = String("Expected 12, got ") + format_value(ret);
        return false;
    }
    return true;
}

bool test_bytecode_alloc_fill_repeat(String &err) {
    BytecodeChunk chunk;
    chunk.local_count = 5;
    chunk.local_names.push_back("sum");
    chunk.local_types.push_back(0);
    chunk.local_names.push_back("arr");
    chunk.local_types.push_back(0);
    chunk.local_names.push_back("tmp");
    chunk.local_types.push_back(0);
    chunk.local_names.push_back("iterations");
    chunk.local_types.push_back(0);
    chunk.local_names.push_back("size");
    chunk.local_types.push_back(0);

    int idx_zero = chunk.add_constant((int64_t)0);
    int idx_iterations = chunk.add_constant((int64_t)3);
    int idx_size = chunk.add_constant((int64_t)4);
    String literal = "xy";
    int idx_literal = chunk.add_constant(literal);
    int idx_last_index = chunk.add_constant((int64_t)3);
    int idx_sum_key = chunk.add_constant(String("sum"));
    int idx_len_key = chunk.add_constant(String("tmp_len"));
    int idx_arr_key = chunk.add_constant(String("arr_last"));

    // Initialize locals
    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_zero);
    push_byte(chunk, OP_SET_LOCAL);
    push_byte(chunk, 0);

    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_iterations);
    push_byte(chunk, OP_SET_LOCAL);
    push_byte(chunk, 3);

    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_size);
    push_byte(chunk, OP_SET_LOCAL);
    push_byte(chunk, 4);

    push_byte(chunk, OP_ALLOC_FILL_REPEAT_I64);
    push_byte(chunk, 0); // sum slot
    push_byte(chunk, 1); // arr slot
    push_byte(chunk, 2); // tmp slot
    push_byte(chunk, (uint8_t)idx_literal);
    push_byte(chunk, 3); // iter slot
    push_byte(chunk, 4); // size slot
    push_byte(chunk, OP_SET_LOCAL);
    push_byte(chunk, 0);

    push_byte(chunk, OP_NEW_DICT);

    push_byte(chunk, OP_GET_LOCAL);
    push_byte(chunk, 0);
    push_byte(chunk, OP_SET_MEMBER);
    push_byte(chunk, (uint8_t)idx_sum_key);

    push_byte(chunk, OP_GET_LOCAL);
    push_byte(chunk, 2);
    push_byte(chunk, OP_LEN);
    push_byte(chunk, OP_SET_MEMBER);
    push_byte(chunk, (uint8_t)idx_len_key);

    push_byte(chunk, OP_GET_LOCAL);
    push_byte(chunk, 1);
    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_last_index);
    push_byte(chunk, OP_GET_ARRAY);
    push_byte(chunk, 1);
    push_byte(chunk, OP_SET_MEMBER);
    push_byte(chunk, (uint8_t)idx_arr_key);

    push_byte(chunk, OP_RETURN_VALUE);

    Variant ret;
    if (!run_chunk(chunk, ret, err)) {
        return false;
    }

    if (ret.get_type() != Variant::DICTIONARY) {
        err = "Allocation fusion opcode did not return a dictionary";
        return false;
    }
    Dictionary dict = ret;
    int64_t sum = dict.get("sum", (int64_t)-1);
    int64_t tmp_len = dict.get("tmp_len", (int64_t)-1);
    int64_t arr_last = dict.get("arr_last", (int64_t)-1);
    int64_t expected_tmp_len = literal.length() * 4;
    if (sum != 12 || tmp_len != expected_tmp_len || arr_last != 3) {
        err = String("Allocation fusion opcode invariants failed (sum=") + String::num_int64(sum)
            + ", tmp_len=" + String::num_int64(tmp_len)
            + ", arr_last=" + String::num_int64(arr_last) + ")";
        return false;
    }
    return true;
}

bool test_bytecode_string_repeat_outer(String &err) {
    BytecodeChunk chunk;
    chunk.local_count = 1;
    chunk.local_names.push_back("s");
    chunk.local_types.push_back(0);

    int idx_inner_count = chunk.add_constant((int64_t)400);
    int idx_outer_count = chunk.add_constant((int64_t)100);
    int idx_literal = chunk.add_constant(String("x"));

    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_inner_count);
    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_outer_count);
    push_byte(chunk, OP_STRING_REPEAT_OUTER);
    push_byte(chunk, 0);
    push_byte(chunk, (uint8_t)idx_literal);

    push_byte(chunk, OP_GET_LOCAL);
    push_byte(chunk, 0);
    push_byte(chunk, OP_LEN);
    push_byte(chunk, OP_RETURN_VALUE);

    Variant ret;
    if (!run_chunk(chunk, ret, err)) {
        return false;
    }

    if (ret.get_type() != Variant::INT || (int64_t)ret != 400) {
        err = String("Expected 400, got ") + format_value(ret);
        return false;
    }
    return true;
}

bool test_bytecode_branch_sum(String &err) {
    BytecodeChunk chunk;
    chunk.local_count = 2;
    chunk.local_names.push_back("s");
    chunk.local_types.push_back(0);
    chunk.local_names.push_back("flag");
    chunk.local_types.push_back(0);

    int idx_zero = chunk.add_constant((int64_t)0);
    int idx_inner_count = chunk.add_constant((int64_t)1000);
    int idx_outer_count = chunk.add_constant((int64_t)200);

    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_zero);
    push_byte(chunk, OP_SET_LOCAL);
    push_byte(chunk, 0);

    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_zero);
    push_byte(chunk, OP_SET_LOCAL);
    push_byte(chunk, 1);

    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_inner_count);
    push_byte(chunk, OP_CONSTANT);
    push_byte(chunk, (uint8_t)idx_outer_count);
    push_byte(chunk, OP_GET_LOCAL);
    push_byte(chunk, 0);
    push_byte(chunk, OP_BRANCH_SUM);
    push_byte(chunk, 1);
    push_byte(chunk, OP_SET_LOCAL);
    push_byte(chunk, 0);

    push_byte(chunk, OP_GET_LOCAL);
    push_byte(chunk, 0);
    push_byte(chunk, OP_RETURN_VALUE);

    Variant ret;
    if (!run_chunk(chunk, ret, err)) {
        return false;
    }

    if (ret.get_type() != Variant::INT || (int64_t)ret != -100000) {
        err = String("Expected -100000, got ") + format_value(ret);
        return false;
    }
    return true;
}

} // namespace

void VisualGasicTestRunner::_bind_methods() {
    ClassDB::bind_method(D_METHOD("run_bytecode_tests"), &VisualGasicTestRunner::run_bytecode_tests);
}

Dictionary VisualGasicTestRunner::run_bytecode_tests() {
    struct TestCase {
        const char *name;
        std::function<bool(String &)> fn;
    };

    std::vector<TestCase> tests = {
        {"Bytecode integer addition", test_bytecode_addition},
        {"Bytecode local arithmetic", test_bytecode_locals},
        {"Bytecode conditional flow", test_bytecode_conditionals},
        {"Bytecode array operations", test_bytecode_array_ops},
        {"Bytecode interop fusion", test_bytecode_interop_name_len},
        {"Bytecode alloc fill", test_bytecode_alloc_fill_i64},
        {"Bytecode dict sum", test_bytecode_sum_dict},
        {"Bytecode allocation fusion", test_bytecode_alloc_fill_repeat},
        {"Bytecode nested string fusion", test_bytecode_string_repeat_outer},
        {"Bytecode branch fusion", test_bytecode_branch_sum},
    };

    Array details;
    int passed = 0;

    for (const TestCase &test : tests) {
        String message;
        bool success = test.fn(message);

        Dictionary entry;
        entry["name"] = String(test.name);
        entry["success"] = success;
        entry["message"] = message;
        details.append(entry);

        if (success) {
            passed++;
        }
    }

    Dictionary summary;
    summary["passed"] = passed;
    summary["failed"] = (int)details.size() - passed;
    summary["total"] = (int)details.size();
    summary["details"] = details;
    return summary;
}
