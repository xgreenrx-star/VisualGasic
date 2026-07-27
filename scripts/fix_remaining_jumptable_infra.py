#!/usr/bin/env python3
"""Fix remaining infrastructure files for OP_JUMP_TABLE."""

import sys

FIXES = [
    # (filepath, search_line, insert_after_line, handler_lines)
    (
        'src/visual_gasic_script.cpp',
        'case OP_LINE_INPUT:',
        'break;',
        [
            '        case OP_JUMP_TABLE: {\n',
            '            // Variable-length: 8 header + count*2 table bytes\n',
            '            int min_cix = (int)code[ip+1] | ((int)code[ip+2] << 8);\n',
            '            int max_cix = (int)code[ip+3] | ((int)code[ip+4] << 8);\n',
            '            int16_t def_off = (int16_t)(code[ip+5] | (code[ip+6] << 8));\n',
            '            int num_cases = (int)code[ip+7] | ((int)code[ip+8] << 8);\n',
            '            int size = 9 + num_cases * 2;\n',
            '            return size;\n',
            '        }\n',
        ]
    ),
    (
        'src/visual_gasic_jit_tier2.cpp',
        'case OP_LOOP:',
        'advance = 3; break;',
        [
            '        case OP_JUMP_TABLE: {\n',
            '            if (ip + 8 <= code_len) {\n',
            '                int num_cases = (int)code[ip+6] | ((int)code[ip+7] << 8);\n',
            '                advance = 8 + num_cases * 2;\n',
            '            } else {\n',
            '                advance = 1;\n',
            '            }\n',
            '            break;\n',
            '        }\n',
        ]
    ),
    (
        'src/visual_gasic_jit_tier3.cpp',
        'case OP_LOOP:',
        'return 3;',
        [
            '        case OP_JUMP_TABLE: {\n',
            '            if (ip + 8 <= (int)bc.size()) {\n',
            '                int num_cases = (int)bc[ip+6] | ((int)bc[ip+7] << 8);\n',
            '                return 8 + num_cases * 2;\n',
            '            }\n',
            '            return 1;\n',
            '        }\n',
        ]
    ),
]


def apply_fix(filepath, search_line_text, insert_after_text, handler_lines):
    """Find search_line_text, then find insert_after_text after it, insert handler."""
    with open(filepath, 'r') as f:
        content = f.read()
    
    lines = content.split('\n')
    
    # Find the search line
    search_idx = None
    for i, line in enumerate(lines):
        if search_line_text in line:
            search_idx = i
            break
    
    if search_idx is None:
        print(f"WARNING: Could not find '{search_line_text}' in {filepath}")
        return False
    
    # Find insert_after_text after search_idx
    insert_after_idx = None
    for i in range(search_idx, min(search_idx + 200, len(lines))):
        if insert_after_text.strip() == lines[i].strip():
            insert_after_idx = i
            break
    
    if insert_after_idx is None:
        print(f"WARNING: Could not find '{insert_after_text}' after '{search_line_text}' in {filepath}")
        return False
    
    # Insert handler after insert_after_idx
    for j, handler_line in enumerate(reversed(handler_lines)):
        lines.insert(insert_after_idx + 1, handler_line.rstrip('\n'))
    
    with open(filepath, 'w') as f:
        f.write('\n'.join(lines))
    
    print(f"Fixed {filepath}")
    return True


def main():
    for filepath, search, after, handler in FIXES:
        try:
            apply_fix(filepath, search, after, handler)
        except Exception as e:
            print(f"FAILED {filepath}: {e}")
    
    print("\nAll infrastructure fixes applied.")


if __name__ == '__main__':
    main()
