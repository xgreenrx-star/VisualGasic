#ifndef VISUAL_GASIC_BYTECODE_H
#define VISUAL_GASIC_BYTECODE_H

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/templates/vector.hpp>

using namespace godot;

enum OpCode {
    OP_CONSTANT, // [OP] [CONST_IDX] - Load constant
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
    
    // Comparison
    OP_EQUAL,
    OP_NOT_EQUAL,
    OP_GREATER,
    OP_LESS,
    OP_GREATER_EQUAL,
    OP_LESS_EQUAL,
    
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
    OP_GET_ARRAY,      // [OP] [ARG_COUNT] (Base + Args on stack)
    OP_SET_ARRAY,      // [OP] [ARG_COUNT] (Value + Base + Args on stack)
    OP_GET_MEMBER,     // [OP] [NAME_IDX]
    OP_SET_MEMBER,     // [OP] [NAME_IDX]

    // Literals
    OP_NIL,
    OP_TRUE,
    OP_FALSE
};

struct BytecodeChunk {
    Vector<uint8_t> code;
    Vector<Variant> constants;
    Vector<int> lines; // Line number per byte (RLE compressed ideally, but flat for now)

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
    Vector<Variant> stack;
    
    // Call Frame info usually needed here for recursion
    // For now we can assume flat execution or use C++ recursion for calls
};

#endif
