#ifndef VISUAL_GASIC_BYTECODE_H
#define VISUAL_GASIC_BYTECODE_H

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/templates/vector.hpp>
#include <vector>

using namespace godot;

enum OpCode {
    OP_CONSTANT,      // [OP] [CONST_IDX] - Load constant
    OP_CONSTANT_LONG, // [OP] [CONST_IDX_LO] [CONST_IDX_HI] (future proofing)
    OP_POP,      // [OP] - Pop stack
    
    // Variables
    OP_GET_GLOBAL, // [OP] [NAME_IDX]
    OP_SET_GLOBAL, // [OP] [NAME_IDX]
    OP_GET_LOCAL,  // [OP] [SLOT_IDX] (For future scoped locals)
    OP_SET_LOCAL,  // [OP] [SLOT_IDX]

    // Math / Logic
    OP_ADD, 
    OP_SUBTRACT,
    OP_MULTIPLY,
    OP_DIVIDE,
    OP_NEGATE,
    OP_CONCAT, // &

    // Extended numeric ops
    OP_ADD_I64,
    OP_ADD_I64_CONST,
    OP_SUB_I64,
    OP_SUB_I64_CONST,
    OP_MUL_I64,
    OP_MUL_I64_CONST,
    OP_ADD_F64,
    OP_SUB_F64,
    OP_MUL_F64,
    OP_DIV_F64,
    OP_ACCUM_I64_MULADD_CONST,
    OP_ADD_LOCAL_I64_STACK,
    OP_SUB_LOCAL_I64_STACK,
    OP_ADD_LOCAL_I64_CONST,
    OP_SUB_LOCAL_I64_CONST,
    OP_INC_LOCAL_I64,
    OP_ARITH_SUM,
    OP_BRANCH_SUM,
    OP_SUM_ARRAY_I64,
    OP_SUM_DICT_I64,
    OP_ARRAY_FILL_I64_SEQ,
    OP_ALLOC_FILL_I64,
    OP_ALLOC_FILL_I64_OFFSET,
    OP_ALLOC_FILL_REPEAT_I64,
    OP_STRING_REPEAT,
    OP_STRING_REPEAT_OUTER,
    OP_ABS,
    OP_SGN,

    // String/collection helpers
    OP_LEN,
    
    // Comparison
    OP_EQUAL,
    OP_NOT_EQUAL,
    OP_GREATER,
    OP_LESS,
    OP_GREATER_EQUAL,
    OP_LESS_EQUAL,
    OP_EQUAL_I64,
    OP_NOT_EQUAL_I64,
    OP_LESS_EQUAL_I64,
    
    // Logical
    OP_NOT,
    OP_AND,
    OP_OR,
    OP_XOR,

    // Flow Control
    OP_JUMP,           // [OP] [OFFSET_16]
    OP_JUMP_IF_FALSE,  // [OP] [OFFSET_16]
    OP_LOOP,           // [OP] [OFFSET_16] (Jump back)
    
    // Functions
    OP_CALL,           // [OP] [METHOD_NAME_IDX] [ARG_COUNT]
    OP_CALL_BUILTIN,   // [OP] [FUNC_ID] [ARG_COUNT]
    OP_RETURN,         // [OP]
    OP_RETURN_VALUE,   // [OP]

    // Advanced
    OP_PRINT,          // [OP] - Print TOS
    OP_NEW_ARRAY,      // [OP] [SIZE]
    OP_NEW_ARRAY_I64,  // [OP] [SIZE]
    OP_NEW_DICT,       // [OP]
    OP_GET_ARRAY,      // [OP] [ARG_COUNT] (Base + Args on stack)
    OP_SET_ARRAY,      // [OP] [ARG_COUNT] (Value + Base + Args on stack)
    OP_GET_ARRAY_UNCHECKED,
    OP_SET_ARRAY_UNCHECKED,
    OP_GET_ARRAY_FAST,           // [OP] [ARG_COUNT] (Array-only fast path)
    OP_SET_ARRAY_FAST,
    OP_GET_ARRAY_FAST_UNCHECKED,
    OP_SET_ARRAY_FAST_UNCHECKED,
    OP_GET_DICT_FAST,            // [OP] [ARG_COUNT] (Dictionary fast path)
    OP_SET_DICT_FAST,
    OP_GET_DICT_TRUSTED,         // [OP] [ARG_COUNT] (Dictionary without runtime type checks)
    OP_SET_DICT_TRUSTED,
    OP_SET_DICT_LOCAL,           // [OP] [SLOT_IDX] [ARG_COUNT] - Modify dict local in-place (key+value on stack)
    OP_SET_DICT_GLOBAL,          // [OP] [NAME_IDX] [ARG_COUNT] - Modify dict global in-place
    OP_DICT_HAS_KEY,             // [OP] - Specialized has_key check (dict, key on stack)
    OP_DICT_SIZE,                // [OP] - Get dictionary size (dict on stack)
    OP_DICT_CLEAR_INPLACE,       // [OP] - Clear dictionary in place (dict on stack, pushes dict back)
    OP_DICT_KEYS,                // [OP] - Get dictionary keys array (dict on stack)
    OP_DICT_VALUES,              // [OP] - Get dictionary values array (dict on stack)
    OP_DICT_ERASE,               // [OP] - Erase key from dict (dict, key on stack, pushes dict back)
    OP_ARRAY_FILL_I64_OFFSET,
    OP_GET_MEMBER,     // [OP] [NAME_IDX]
    OP_SET_MEMBER,     // [OP] [NAME_IDX]
    OP_INTEROP_SET_NAME_LEN,

    // Literals
    OP_NIL,
    OP_TRUE,
    OP_FALSE
};

struct BytecodeChunk {
    Vector<uint8_t> code;
    Vector<Variant> constants;
    Vector<int> lines; // Line number per byte (RLE compressed ideally, but flat for now)
    Vector<String> local_names;
    Vector<uint8_t> local_types;
    int local_count = 0;

    void write(uint8_t byte, int line) {
        code.push_back(byte);
        lines.push_back(line); // Simplify mapping 1:1 for now
    }
    
    int add_constant(const Variant& value) {
        constants.push_back(value);
        return constants.size() - 1;
    }
};

struct VMState {
    int ip; // Instruction Pointer
    std::vector<Variant> stack;
    
    // Call Frame info usually needed here for recursion
    // For now we can assume flat execution or use C++ recursion for calls
};

#endif
