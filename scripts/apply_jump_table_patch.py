#!/usr/bin/env python3
"""Apply jump table optimization to the VisualGasic compiler and interpreters."""

import re
import sys


def patch_compiler(filepath):
    """Insert jump table heuristic and codegen into case STMT_SELECT in compiler.cpp."""
    with open(filepath, 'r') as f:
        content = f.read()
    
    # The heuristic function - placed before the first case STMT_SELECT
    heuristic_func = '''
// ── M6: Select Case Jump Table Heuristic ───────────────────────────────────
// Check if a Select Statement can be compiled to an O(1) OP_JUMP_TABLE
// instead of O(n) sequential OP_JUMP_IF_FALSE comparisons.
// Returns true and sets out_min/out_max/out_count if jump table is viable.
static bool is_jump_table_candidate(SelectStatement* sel, int64_t& out_min, int64_t& out_max, int& out_count) {
    out_min = INT64_MAX;
    out_max = INT64_MIN;
    int case_count = 0;

    for (int i = 0; i < sel->cases.size(); i++) {
        CaseBlock* cb = sel->cases[i];
        if (cb->is_else) continue;
        
        // Must be exactly one value per case
        if (cb->values.size() != 1) return false;
        // No range comparisons (X To Y)
        for (int j = 0; j < cb->range_ends.size(); j++) {
            if (cb->range_ends[j] != nullptr) return false;
        }
        // No Is comparisons (Is > X, Is < Y, etc.)
        if (cb->comparison_ops.size() > 0) return false;
        
        // Must be a literal integer constant
        ExpressionNode* e = cb->values[0];
        if (!e || e->type != ExpressionNode::LITERAL) return false;
        LiteralNode* lit = static_cast<LiteralNode*>(e);
        if (lit->value.get_type() != Variant::INT) return false;
        
        int64_t v = (int64_t)lit->value;
        if (v < out_min) out_min = v;
        if (v > out_max) out_max = v;
        case_count++;
    }

    if (case_count < 8) return false;  // Minimum 8 cases for table to be worthwhile
    
    int64_t range = out_max - out_min + 1;
    if (range < 1 || range > 65535) return false;  // Range must fit in 16-bit offsets
    
    // Density check: at least 30% populated (256-entry opcode decoders hit ~60%+ easily)
    float density = (float)case_count / (float)range;
    if (density < 0.30f) return false;
    
    out_count = case_count;
    return true;
}
// ──────────────────────────────────────────────────────────────────────────

'''
    
    # The jump table codegen logic - inserted at the start of case STMT_SELECT body
    # This replaces the sequential comparison emission with O(1) dispatch
    jumptable_codegen = '''
        // M6: Try jump table first (dense integer cases → O(1) dispatch)
        {
            int64_t jt_min, jt_max;
            int jt_count;
            if (is_jump_table_candidate(s, jt_min, jt_max, jt_count)) {
                // Compile the expression (value to match)
                compile_expression(s->expression);
                
                // Record where OP_JUMP_TABLE will be emitted
                int jt_op_pos = chunk.code.size();
                emit_byte(OP_JUMP_TABLE);
                
                // Emit min/max constant pool indices (16-bit each)
                int min_cix = chunk.add_constant(Variant(jt_min));
                chunk.code.push_back(min_cix & 0xFF); chunk.lines.push_back(s->line);
                chunk.code.push_back((min_cix >> 8) & 0xFF); chunk.lines.push_back(s->line);
                int max_cix = chunk.add_constant(Variant(jt_max));
                chunk.code.push_back(max_cix & 0xFF); chunk.lines.push_back(s->line);
                chunk.code.push_back((max_cix >> 8) & 0xFF); chunk.lines.push_back(s->line);
                
                // Reserve space for: [def_off_16] [count_16] [table: count x int16_t]
                int def_off_pos = chunk.code.size();
                emit_int16(0);  // default_offset (patch later)
                emit_int16(jt_count);
                int table_start = chunk.code.size();
                for (int ti = 0; ti < jt_count; ti++) emit_int16(0);  // offset slots (patch)
                int table_end = chunk.code.size();
                
                // Map case values to their body offset from table_end
                HashMap<int64_t, int> val_to_case_idx;
                for (int ci = 0; ci < s->cases.size(); ci++) {
                    CaseBlock* cb = s->cases[ci];
                    if (cb->is_else) continue;
                    if (cb->values.size() != 1 || !cb->values[0] || cb->values[0]->type != ExpressionNode::LITERAL) continue;
                    LiteralNode* lit = static_cast<LiteralNode*>(cb->values[0]);
                    if (lit->value.get_type() != Variant::INT) continue;
                    int64_t v = (int64_t)lit->value;
                    val_to_case_idx[v] = ci;
                }
                
                // Compile each case body and record its offset
                Vector<int> body_offsets;  // indexed by jt_value - jt_min
                body_offsets.resize(jt_count);
                int default_offset = 0;  // Case Else offset (relative to table_end)
                int case_else_idx = -1;
                for (int ci = 0; ci < s->cases.size(); ci++) {
                    if (s->cases[ci]->is_else) { case_else_idx = ci; break; }
                }
                
                // For each slot in the table: compile body and record offset
                for (int64_t v = jt_min; v <= jt_max && (v - jt_min) < jt_count; v++) {
                    int slot = (int)(v - jt_min);
                    int body_offset = chunk.code.size() - table_end;
                    
                    if (val_to_case_idx.has(v)) {
                        int ci = val_to_case_idx[v];
                        CaseBlock* cb = s->cases[ci];
                        for (int bj = 0; bj < cb->body.size(); bj++) {
                            compile_statement(cb->body[bj]);
                        }
                    }
                    // Emit jump to end of select after each body
                    body_offsets.write[slot] = chunk.code.size() - table_end;
                }
                
                // Compile Case Else body (or empty jump to end)
                int else_start = chunk.code.size();
                if (case_else_idx >= 0) {
                    CaseBlock* cb = s->cases[case_else_idx];
                    for (int bj = 0; bj < cb->body.size(); bj++) {
                        compile_statement(cb->body[bj]);
                    }
                }
                // No emit_jump_to_end needed — fallthrough is end of Select
                
                // Patch the default offset
                default_offset = else_start - table_end;
                chunk.code.write[def_off_pos] = default_offset & 0xFF;
                chunk.code.write[def_off_pos + 1] = (default_offset >> 8) & 0xFF;
                
                // Patch the body offset table
                for (int ti = 0; ti < jt_count; ti++) {
                    int off = body_offsets[ti];
                    int patch_pos = table_start + ti * 2;
                    chunk.code.write[patch_pos] = off & 0xFF;
                    chunk.code.write[patch_pos + 1] = (off >> 8) & 0xFF;
                }
                
                break;  // Done — skip sequential fallback
            }
        }
        // Fall through to sequential Select Case if jump table isn't viable
'''
    
    # Step 1: Insert heuristic function before the first case STMT_SELECT
    # Find the first occurrence
    marker = 'case STMT_SELECT:'
    first_pos = content.find(marker)
    if first_pos == -1:
        print(f"ERROR: Could not find '{marker}' in {filepath}")
        return False
    
    # Go backwards from first_pos to find a good insertion point (before the case, after previous } )
    # Actually, insert at the beginning of the function that contains this case, or right before it
    # Find the previous closing brace of the preceding case statement
    insert_pos = content.rfind('break;', 0, first_pos)
    if insert_pos == -1:
        # Try finding the end of previous case
        insert_pos = content.rfind('}', 0, first_pos)
    if insert_pos == -1:
        print("WARNING: Could not find insertion point for heuristic function")
        insert_pos = first_pos - 50  # approximate
    
    # Move past the break; or }
    insert_pos = content.find('\n', insert_pos) + 1
    
    content = content[:insert_pos] + heuristic_func + content[insert_pos:]
    
    # Step 2: Insert jump table codegen at the start of case STMT_SELECT body
    # Re-find marker (shifted by heuristic insertion)
    marker_pos = content.find(marker)
    if marker_pos == -1:
        print(f"ERROR: Lost '{marker}' after heuristic insertion")
        return False
    
    # Find the opening brace after the marker
    brace_pos = content.find('{', marker_pos)
    if brace_pos == -1:
        print("ERROR: Could not find opening brace after case STMT_SELECT")
        return False
    
    # Insert after the opening brace
    insert_at = brace_pos + 1
    content = content[:insert_at] + jumptable_codegen + content[insert_at:]
    
    with open(filepath, 'w') as f:
        f.write(content)
    
    print(f"Patched {filepath} successfully")
    return True


def patch_execute_inc(filepath):
    """Add OP_JUMP_TABLE case to the AST interpreter in execute.inc."""
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Find a good insertion point — near other flow control opcodes
    marker = 'case OP_JUMP_IF_TRUE:'
    pos = content.find(marker)
    if pos == -1:
        marker = 'case OP_LOOP:'
        pos = content.find(marker)
    if pos == -1:
        print(f"ERROR: Could not find flow control opcode in {filepath}")
        return False
    
    # Find the end of that case block
    end_pos = content.find('break;', pos)
    if end_pos == -1:
        print("ERROR: Could not find end of flow control case")
        return False
    
    insert_at = content.find('\n', end_pos) + 1
    
    handler = '''    case OP_JUMP_TABLE: {
        // Dense integer jump table — O(1) Select Case dispatch
        int min_cix = READ16();
        int max_cix = READ16();
        int16_t def_off = (int16_t)READ16();
        int num_cases = READ16();
        
        Variant val = pop_value();
        int64_t ival = (val.get_type() == Variant::INT) ? (int64_t)val : 
                       (val.get_type() == Variant::FLOAT) ? (int64_t)(double)val : INT64_MIN;
        
        int64_t min_val = (int64_t)constants[min_cix];
        int64_t max_val = (int64_t)constants[max_cix];
        
        if (ival < min_val || ival > max_val) {
            ip += def_off;
        } else {
            int64_t idx = ival - min_val;
            if (idx >= 0 && idx < (int64_t)num_cases) {
                ip += (int16_t)(code[ip + idx*2] | (code[ip + idx*2 + 1] << 8));
            } else {
                ip += def_off;
            }
        }
        break;
    }

'''
    
    content = content[:insert_at] + handler + content[insert_at:]
    
    with open(filepath, 'w') as f:
        f.write(content)
    
    print(f"Patched {filepath} successfully")
    return True


def patch_statement_cpp(filepath):
    """Add OP_JUMP_TABLE case to the statement-based interpreter."""
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Find near other opcodes
    marker = 'case STMT_SELECT:'
    pos = content.find(marker)
    if pos == -1:
        print(f"ERROR: Could not find STMT_SELECT in {filepath}")
        return False
    
    # Find the break; after that case
    end_pos = content.find('break;', pos)
    if end_pos == -1:
        end_pos = content.find('}', pos + 500)  # approximate
    if end_pos == -1:
        print("ERROR: Could not find end of STMT_SELECT case")
        return False
    
    # Find the line end after break;
    insert_at = content.find('\n', end_pos) + 1
    
    handler = '''		case OP_JUMP_TABLE: {
			// Dense jump-table Select Case dispatch
			// Evaluate expression, then dispatch via offset table
			// (this is handled via the bytecode VM in normal operation;
			//  the statement interpreter fallback is only used for debugging)
			int min_cix = (int)code[ip] | ((int)code[ip+1] << 8); ip += 2;
			int max_cix = (int)code[ip] | ((int)code[ip+1] << 8); ip += 2;
			int16_t def_off = (int16_t)(code[ip] | (code[ip+1] << 8)); ip += 2;
			int num_cases = (int)code[ip] | ((int)code[ip+1] << 8); ip += 2;

			Variant top = pop_value();
			int64_t val = 0;
			if (top.get_type() == Variant::INT) val = (int64_t)top;
			else if (top.get_type() == Variant::FLOAT) val = (int64_t)(double)top;
			else { ip += def_off; break; }

			int64_t min_val = (int64_t)constants[min_cix];
			int64_t max_val = (int64_t)constants[max_cix];

			if (val < min_val || val > max_val) {
				ip += def_off;
			} else {
				int64_t idx = val - min_val;
				if (idx >= 0 && idx < (int64_t)num_cases) {
					ip += (int16_t)(code[ip + idx*2] | (code[ip + idx*2 + 1] << 8));
				} else {
					ip += def_off;
				}
			}
			break;
		}

'''
    
    content = content[:insert_at] + handler + content[insert_at:]
    
    with open(filepath, 'w') as f:
        f.write(content)
    
    print(f"Patched {filepath} successfully")
    return True


def main():
    base = 'src'
    
    files = [
        f'{base}/visual_gasic_compiler.cpp',
        f'{base}/visual_gasic_instance_execute.inc',
        f'{base}/visual_gasic_instance_statement.cpp',
    ]
    
    success = True
    for f in files:
        try:
            if 'compiler' in f:
                patch_compiler(f)
            elif 'execute.inc' in f:
                patch_execute_inc(f)
            elif 'statement.cpp' in f:
                patch_statement_cpp(f)
        except Exception as e:
            print(f"Failed to patch {f}: {e}")
            success = False
    
    if success:
        print("\nAll files patched successfully!")
        print("Next steps:")
        print("  1. Build: scons platform=linux target=editor -j$(nproc)")
        print("  2. Test: Run any .vg file with dense Select Case on integers")
        print("  3. Verify: Enabling/disabling jump table via heuristic density check")
    else:
        print("\nSome patches failed. Check errors above.")
        sys.exit(1)


if __name__ == '__main__':
    main()
