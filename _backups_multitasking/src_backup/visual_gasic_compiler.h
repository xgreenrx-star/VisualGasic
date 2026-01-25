#ifndef VISUAL_GASIC_COMPILER_H
#define VISUAL_GASIC_COMPILER_H

#include "visual_gasic_bytecode.h"
#include "visual_gasic_ast.h"

class VisualGasicCompiler {
    BytecodeChunk* current_chunk;
    int current_line; // Track current source line
    
    void emit_byte(uint8_t byte);
    void emit_bytes(uint8_t byte1, uint8_t byte2);
    void emit_constant(const Variant& value);
    void emit_return();
    
    // Visitors
    void compile_statement(Statement* stmt);
    void compile_expression(ExpressionNode* expr);

public:
    VisualGasicCompiler();
    ~VisualGasicCompiler();

    bool compile(ModuleNode* module, const String& entry_point, BytecodeChunk* chunk);
};

#endif
