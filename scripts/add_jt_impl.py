#!/usr/bin/env python3
# Add try_compile_jump_table implementation to compiler.cpp

filepath = 'src/visual_gasic_compiler.cpp'
with open(filepath, 'r') as f:
    lines = f.readlines()

# Find 'void VisualGasicCompiler::compile_statement(Statement* stmt)'
target = None
for i, line in enumerate(lines):
    if 'void VisualGasicCompiler::compile_statement(Statement* stmt)' in line:
        target = i
        break

if target is None:
    print('ERROR: could not find compile_statement')
    exit(1)

print(f'compile_statement at line {target + 1}')

impl = '''
// ====== M6: Select Case Jump Table Optimization ============================
// Attempts to compile a Select Case using the O(1) OP_JUMP_TABLE bytecode.
// Returns true if successful, false if the case structure isn't suitable.
bool VisualGasicCompiler::try_compile_jump_table(SelectStatement* s) {
    int64_t jt_min, jt_max;
    int jt_count;

    // 1. Heuristic check
    {
        jt_min = INT64_MAX;
        jt_max = INT64_MIN;
        int case_count = 0;
        for (int i = 0; i < s->cases.size(); i++) {
            CaseBlock* cb = s->cases[i];
            if (cb->is_else) continue;
            if (cb->values.size() != 1) return false;
            for (int r = 0; r < cb->range_ends.size(); r++)
                if (cb->range_ends[r] != nullptr) return false;
            if (cb->comparison_ops.size() > 0) return false;
            ExpressionNode* e = cb->values[0];
            if (!e || e->type != ExpressionNode::LITERAL) return false;
            LiteralNode* lit = static_cast<LiteralNode*>(e);
            if (lit->value.get_type() != Variant::INT) return false;
            int64_t v = (int64_t)lit->value;
            if (v < jt_min) jt_min = v;
            if (v > jt_max) jt_max = v;
            case_count++;
        }
        if (case_count < 8) return false;
        int64_t range = jt_max - jt_min + 1;
        if (range < 1 || range > 65535) return false;
        float density = (float)case_count / (float)range;
        if (density < 0.30f) return false;
        jt_count = case_count;
    }

    // 2. Compile expression and emit jump table
    int jt_slot = get_or_add_local(String("__jtsel_") + String::num_int64(temp_local_id++),
                                   infer_type(s->expression));
    compile_expression(s->expression);
    emit_bytes(OP_SET_LOCAL, (uint8_t)jt_slot);
    emit_bytes(OP_GET_LOCAL, (uint8_t)jt_slot);
    emit_byte(OP_JUMP_TABLE);

    int min_cix = current_chunk->add_constant(Variant(jt_min));
    int max_cix = current_chunk->add_constant(Variant(jt_max));
    emit_bytes((uint8_t)(min_cix & 0xFF), (uint8_t)((min_cix >> 8) & 0xFF));
    emit_bytes((uint8_t)(max_cix & 0xFF), (uint8_t)((max_cix >> 8) & 0xFF));

    int def_pos = current_chunk->code.size();
    emit_bytes(0, 0);  // default_offset (patched later)
    emit_bytes((uint8_t)(jt_count & 0xFF), (uint8_t)((jt_count >> 8) & 0xFF));

    int table_start = current_chunk->code.size();
    for (int ti = 0; ti < jt_count; ti++) emit_bytes(0, 0);
    int table_end = current_chunk->code.size();

    // 3. Build value-to-case-index map
    HashMap<int64_t, int> vmap;
    for (int ci = 0; ci < s->cases.size(); ci++) {
        CaseBlock* cb = s->cases[ci];
        if (!cb->is_else && cb->values.size() == 1) {
            ExpressionNode* e = cb->values[0];
            if (e && e->type == ExpressionNode::LITERAL) {
                LiteralNode* lit = static_cast<LiteralNode*>(e);
                if (lit->value.get_type() == Variant::INT)
                    vmap[(int64_t)lit->value] = ci;
            }
        }
    }

    // 4. Find Case Else index
    int else_idx = -1;
    for (int ci = 0; ci < s->cases.size(); ci++) {
        if (s->cases[ci]->is_else) { else_idx = ci; break; }
    }

    // 5. Compile case bodies and record slot offsets (relative to table_end)
    Vector<int> offsets;
    offsets.resize(jt_count);
    for (int slot = 0; slot < jt_count; slot++) {
        offsets.write[slot] = current_chunk->code.size() - table_end;
        if (vmap.has(jt_min + (int64_t)slot)) {
            CaseBlock* cb = s->cases[vmap[jt_min + (int64_t)slot]];
            for (int bj = 0; bj < cb->body.size(); bj++)
                compile_statement(cb->body[bj]);
        }
    }

    // 6. Compile Case Else (default)
    int else_start = current_chunk->code.size();
    if (else_idx >= 0) {
        CaseBlock* cb = s->cases[else_idx];
        for (int bj = 0; bj < cb->body.size(); bj++)
            compile_statement(cb->body[bj]);
    }

    // 7. Backpatch default_offset and slot offsets
    int16_t default_off = (int16_t)(else_start - table_end);
    current_chunk->code.write[def_pos] = (uint8_t)(default_off & 0xFF);
    current_chunk->code.write[def_pos + 1] = (uint8_t)((default_off >> 8) & 0xFF);

    for (int slot = 0; slot < jt_count; slot++) {
        int16_t off = vmap.has(jt_min + (int64_t)slot) ? (int16_t)offsets[slot] : default_off;
        int pp = table_start + slot * 2;
        current_chunk->code.write[pp] = (uint8_t)(off & 0xFF);
        current_chunk->code.write[pp + 1] = (uint8_t)((off >> 8) & 0xFF);
    }

    compile_ok = true;
    return true;
}
// ===========================================================================

'''

lines.insert(target, impl)

with open(filepath, 'w') as f:
    f.writelines(lines)

print('Implementation inserted.')
