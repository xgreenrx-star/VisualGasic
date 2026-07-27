#!/usr/bin/env python3
"""Inject Select Case jump table optimization into the bytecode compiler."""

import sys


def main():
    filepath = 'src/visual_gasic_compiler.cpp'
    
    with open(filepath, 'r') as f:
        lines = f.readlines()
    
    # -----------------------------------------------------------------
    # STEP 1: Find insertion point for heuristic function
    # Insert right before the first case in the compilation switch
    # that contains compile_expression calls (the main STMT_SELECT comp)
    # -----------------------------------------------------------------
    
    # Find the main compilation STMT_SELECT (third occurrence contains compile_expression)
    select_compile_line = None
    for i, line in enumerate(lines):
        if 'case STMT_SELECT:' not in line:
            continue
        # This is a candidate. Check if compile_expression appears nearby
        for j in range(i, min(i + 30, len(lines))):
            if 'compile_expression' in lines[j]:
                select_compile_line = i
                break
        if select_compile_line is not None:
            break
    
    if select_compile_line is None:
        print("ERROR: Could not find main STMT_SELECT compilation block")
        sys.exit(1)
    
    print(f"Main STMT_SELECT compilation at line {select_compile_line + 1}")
    
    # Go backwards to find the break; of the previous case
    heuristic_insert = None
    for i in range(select_compile_line - 1, max(select_compile_line - 50, 0), -1):
        stripped = lines[i].strip()
        if stripped == 'break;' or stripped.startswith('break;'):
            heuristic_insert = i + 1  # after the break;
            break
    
    if heuristic_insert is None:
        # Fallback: insert right before select_compile_line
        heuristic_insert = select_compile_line
    
    print(f"Inserting heuristic function at line {heuristic_insert + 1}")
    
    heuristic_code = '''
// ====== M6: Select Case Jump Table Heuristic ==============================
// Determines whether a Select Statement qualifies for O(1) OP_JUMP_TABLE
// dispatch instead of O(n) sequential OP_JUMP_IF_FALSE comparisons.
static bool _vg_is_jump_table_candidate(SelectStatement* sel, int64_t& out_min, int64_t& out_max, int& out_count) {
    out_min = INT64_MAX;
    out_max = INT64_MIN;
    int case_count = 0;

    for (int i = 0; i < sel->cases.size(); i++) {
        CaseBlock* cb = sel->cases[i];
        if (cb->is_else) continue;

        // 1) Exactly one case value (no multi-value: Case 1, 2, 3)
        if (cb->values.size() != 1) return false;
        // 2) No range ends (Case X To Y is handled by sequential code only)
        for (int r = 0; r < cb->range_ends.size(); r++) {
            if (cb->range_ends[r] != nullptr) return false;
        }
        // 3) No Is comparisons (Case Is > X, Is < Y, etc.)
        if (cb->comparison_ops.size() > 0) return false;

        // 4) Must be an integer literal constant
        ExpressionNode* e = cb->values[0];
        if (!e || e->type != ExpressionNode::LITERAL) return false;
        LiteralNode* lit = static_cast<LiteralNode*>(e);
        if (lit->value.get_type() != Variant::INT) return false;

        int64_t v = (int64_t)lit->value;
        if (v < out_min) out_min = v;
        if (v > out_max) out_max = v;
        case_count++;
    }

    // Require minimum 8 cases to justify the 10-byte header overhead
    if (case_count < 8) return false;

    int64_t range = out_max - out_min + 1;
    if (range < 1 || range > 65535) return false;

    // Density: at least 30% of the range must be populated
    // (256-entry opcode decoders reach 60-100% density easily)
    float density = (float)case_count / (float)range;
    if (density < 0.30f) return false;

    out_count = case_count;
    return true;
}
// ===========================================================================

'''
    
    lines.insert(heuristic_insert, heuristic_code)
    
    # -----------------------------------------------------------------
    # STEP 2: Insert jump table shortcut at top of STMT_SELECT body
    # -----------------------------------------------------------------
    
    # Re-find select_compile_line (shifted by insertion above)
    select_compile_line = None
    for i, line in enumerate(lines):
        if 'case STMT_SELECT:' not in line:
            continue
        for j in range(i, min(i + 30, len(lines))):
            if 'compile_expression' in lines[j]:
                select_compile_line = i
                break
        if select_compile_line is not None:
            break
    
    if select_compile_line is None:
        print("ERROR: Lost STMT_SELECT after heuristic insertion")
        sys.exit(1)
    
    print(f"Re-found STMT_SELECT compilation at line {select_compile_line + 1}")
    
    # Find the opening brace of this case block
    brace_line = None
    for i in range(select_compile_line, min(select_compile_line + 10, len(lines))):
        if '{' in lines[i]:
            brace_line = i
            break
    
    if brace_line is None:
        print("ERROR: Could not find opening brace")
        sys.exit(1)
    
    print(f"Opening brace at line {brace_line + 1}")
    
    jump_table_code = '''
        // M6: Jump table dispatch for dense integer Select Case
        if (false) {}  // scope bracket — we use a leading {} to balance
        else {
            int64_t jt_min, jt_max;
            int jt_count;
            if (_vg_is_jump_table_candidate(s, jt_min, jt_max, jt_count)) {
                // ------- O(1) JUMP TABLE PATH -------
                //
                // Layout:  [expression on stack] [OP_JUMP_TABLE + header]
                //          [offset table: jt_count x int16_t]
                //          [case body 0] ... [case body N-1]
                //          [Case Else body or fallthrough]
                //
                // The expression is loaded onto the stack, then
                // OP_JUMP_TABLE pops it, bounds-checks against [min,max],
                // and adds the appropriate int16_t offset to vm.ip.

                // Compile and load the expression
                int select_slot = get_or_add_local(String("__jtsel_") + String::num_int64(temp_local_id++), infer_type(s->expression));
                compile_expression(s->expression);
                emit_bytes(OP_SET_LOCAL, (uint8_t)select_slot);
                emit_bytes(OP_GET_LOCAL, (uint8_t)select_slot);

                // Emit OP_JUMP_TABLE header
                emit_byte(OP_JUMP_TABLE);

                // Emit min/max as constant pool indices (16-bit each)
                int min_cix = current_chunk->add_constant(Variant(jt_min));
                int max_cix = current_chunk->add_constant(Variant(jt_max));
                emit_bytes((uint8_t)(min_cix & 0xFF), (uint8_t)((min_cix >> 8) & 0xFF));
                emit_bytes((uint8_t)(max_cix & 0xFF), (uint8_t)((max_cix >> 8) & 0xFF));

                // Reserve default_offset (2 bytes) — patched later
                int def_off_pos = current_chunk->code.size();
                emit_bytes(0, 0);

                // Emit num_cases (2 bytes)
                emit_bytes((uint8_t)(jt_count & 0xFF), (uint8_t)((jt_count >> 8) & 0xFF));

                // Reserve offset table: jt_count x 2 bytes
                int table_start = current_chunk->code.size();
                for (int ti = 0; ti < jt_count; ti++) {
                    emit_bytes(0, 0);
                }
                int table_end = current_chunk->code.size();

                // Build value-to-case-index map
                HashMap<int64_t, int> val_to_case_idx;
                for (int ci = 0; ci < s->cases.size(); ci++) {
                    CaseBlock* cb = s->cases[ci];
                    if (cb->is_else) continue;
                    if (cb->values.size() != 1) continue;
                    ExpressionNode* e = cb->values[0];
                    if (!e || e->type != ExpressionNode::LITERAL) continue;
                    LiteralNode* lit = static_cast<LiteralNode*>(e);
                    if (lit->value.get_type() != Variant::INT) continue;
                    val_to_case_idx[(int64_t)lit->value] = ci;
                }

                // Find the Case Else index (if any)
                int case_else_idx = -1;
                for (int ci = 0; ci < s->cases.size(); ci++) {
                    if (s->cases[ci]->is_else) { case_else_idx = ci; break; }
                }

                // Compile each slot body and record offset
                // slot_offsets[i] = bytecode offset from table_end to body start
                Vector<int> slot_offsets;
                slot_offsets.resize(jt_count);

                for (int slot = 0; slot < jt_count; slot++) {
                    int64_t case_value = jt_min + (int64_t)slot;
                    slot_offsets.write[slot] = current_chunk->code.size() - table_end;

                    if (val_to_case_idx.has(case_value)) {
                        int ci = val_to_case_idx[case_value];
                        CaseBlock* cb = s->cases[ci];
                        for (int bj = 0; bj < cb->body.size(); bj++) {
                            compile_statement(cb->body[bj]);
                        }
                        // Emit a jump to end of Select after each body
                        // (end_jump will be patched after Case Else is compiled)
                    }
                }

                // Compile Case Else (default) body
                int else_start = current_chunk->code.size();
                if (case_else_idx >= 0) {
                    CaseBlock* cb = s->cases[case_else_idx];
                    for (int bj = 0; bj < cb->body.size(); bj++) {
                        compile_statement(cb->body[bj]);
                    }
                }

                // Backpatch default_offset
                int16_t default_off = (int16_t)(else_start - table_end);
                current_chunk->code.write[def_off_pos] = (uint8_t)(default_off & 0xFF);
                current_chunk->code.write[def_off_pos + 1] = (uint8_t)((default_off >> 8) & 0xFF);

                // Backpatch each slot offset
                // Dead/unused slots point to the default (Case Else)
                for (int slot = 0; slot < jt_count; slot++) {
                    int64_t case_value = jt_min + (int64_t)slot;
                    int16_t off;
                    if (val_to_case_idx.has(case_value)) {
                        off = (int16_t)slot_offsets[slot];
                    } else {
                        off = default_off;
                    }
                    int patch_pos = table_start + slot * 2;
                    current_chunk->code.write[patch_pos] = (uint8_t)(off & 0xFF);
                    current_chunk->code.write[patch_pos + 1] = (uint8_t)((off >> 8) & 0xFF);
                }

                compile_ok = true;
                break;  // Done — skip sequential fallback
            }
        }
        // Fall through if jump table not viable
        
'''
    
    # Insert after the opening brace
    lines.insert(brace_line + 1, jump_table_code)
    
    # Write back
    with open(filepath, 'w') as f:
        f.writelines(lines)
    
    print("Compiler patched successfully.")
    print(f"  Heuristic function at line {heuristic_insert + 1}")
    print(f"  Jump table codegen at line {brace_line + 2}")


if __name__ == '__main__':
    main()
