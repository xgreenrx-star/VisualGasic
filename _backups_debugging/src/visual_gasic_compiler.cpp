#include "visual_gasic_compiler.h"
#include <godot_cpp/variant/utility_functions.hpp>

VisualGasicCompiler::VisualGasicCompiler() : current_chunk(nullptr), current_line(0) {
}

VisualGasicCompiler::~VisualGasicCompiler() {
}

void VisualGasicCompiler::emit_byte(uint8_t byte) {
    current_chunk->write(byte, current_line);
}

void VisualGasicCompiler::emit_bytes(uint8_t byte1, uint8_t byte2) {
    emit_byte(byte1);
    emit_byte(byte2);
}

void VisualGasicCompiler::emit_constant(const Variant& value) {
    int idx = current_chunk->add_constant(value);
    if (idx < 256) {
        emit_bytes(OP_CONSTANT, (uint8_t)idx);
    } else {
        // Handle > 256 constants? Need OP_CONSTANT_LONG or similar. For now just truncate or error?
        UtilityFunctions::print("Compiler Error: Too many constants");
    }
}

void VisualGasicCompiler::emit_return() {
    emit_byte(OP_RETURN);
}

bool VisualGasicCompiler::compile(ModuleNode* module, const String& entry_point, BytecodeChunk* chunk) {
    current_chunk = chunk;
    
    // Find the entry point sub
    SubDefinition* sub = nullptr;
    for(int i=0; i<module->subs.size(); i++) {
        if (module->subs[i]->name.nocasecmp_to(entry_point) == 0) {
            sub = module->subs[i];
            break;
        }
    }
    
    if (!sub) {
        UtilityFunctions::print("Compiler: Entry point not found: ", entry_point);
        return false;
    }
    
    for(int i=0; i<sub->statements.size(); i++) {
        compile_statement(sub->statements[i]);
    }
    
    emit_return();
    return true;
}

void VisualGasicCompiler::compile_statement(Statement* stmt) {
    current_line = stmt->line;
    switch (stmt->type) {
        case STMT_PRINT: {
            PrintStatement* s = (PrintStatement*)stmt;
            if (s->expression) {
                compile_expression(s->expression);
                emit_byte(OP_PRINT);
            }
            break;
        }
        case STMT_DIM: {
            // Usually handled at scope analysis, but for bytecode we might need to alloc locals if we do stack frames.
            // For now, ignore or treat as global (if we support Locals later).
            break;
        }
        case STMT_ASSIGNMENT: {
             AssignmentStatement* s = (AssignmentStatement*)stmt;
             compile_expression(s->value);
             // Assume variable for now
             if (s->target->type == ExpressionNode::VARIABLE) {
                 VariableNode* v = (VariableNode*)s->target;
                 int idx = current_chunk->add_constant(v->name);
                 emit_bytes(OP_SET_GLOBAL, (uint8_t)idx);
             }
             break;
        }
        default:
             UtilityFunctions::print("Compiler: Unsupported statement type ", stmt->type);
             break;
    }
}

void VisualGasicCompiler::compile_expression(ExpressionNode* expr) {
    switch (expr->type) {
        case ExpressionNode::LITERAL: {
            LiteralNode* l = (LiteralNode*)expr;
            emit_constant(l->value);
            break;
        }
        case ExpressionNode::VARIABLE: {
            VariableNode* v = (VariableNode*)expr;
            int idx = current_chunk->add_constant(v->name);
            emit_bytes(OP_GET_GLOBAL, (uint8_t)idx);
            break;
        }
        case ExpressionNode::BINARY_OP: {
            BinaryOpNode* b = (BinaryOpNode*)expr;
            compile_expression(b->left);
            compile_expression(b->right);
            
            if (b->op == "+") emit_byte(OP_ADD);
            else if (b->op == "-") emit_byte(OP_SUBTRACT);
            else if (b->op == "*") emit_byte(OP_MULTIPLY);
            else if (b->op == "/") emit_byte(OP_DIVIDE);
            else if (b->op == "&") emit_byte(OP_CONCAT);
            // ...
            break;
        }
        case ExpressionNode::EXPRESSION_CALL: {
             CallExpression* call = (CallExpression*)expr;
             // Push args
             for(int i=0; i<call->arguments.size(); i++) {
                 compile_expression(call->arguments[i]);
             }
             // Call
             int idx = current_chunk->add_constant(call->method_name);
             emit_bytes(OP_CALL, (uint8_t)idx);
             emit_byte((uint8_t)call->arguments.size()); // Arg count
             break;
        }
        default:
             UtilityFunctions::print("Compiler: Unsupported expression type ", expr->type);
             emit_byte(OP_NIL);
             break;
    }
}

