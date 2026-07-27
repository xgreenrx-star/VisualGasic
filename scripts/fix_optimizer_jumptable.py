#!/usr/bin/env python3
"""Add OP_JUMP_TABLE handling to the optimizer's instruction_size() function."""

def main():
    filepath = 'src/visual_gasic_optimizer.cpp'
    with open(filepath, 'r') as f:
        lines = f.readlines()
    
    insert_at = None
    for i, line in enumerate(lines):
        if 'OP_ALLOC_FILL_REPEAT_I64' in line and 'return 8;' in lines[i+1]:
            insert_at = i + 2
            break
    
    if insert_at is None:
        print("ERROR: Could not find insertion point")
        return
    
    handler = (
        "        // Variable-length: OP_JUMP_TABLE = 8 header + count*2 table bytes\n"
        "        case OP_JUMP_TABLE: {\n"
        "            if (ip + 8 <= code.size()) {\n"
        "                int num_cases = (code[ip + 6]) | (code[ip + 7] << 8);\n"
        "                return 8 + num_cases * 2;\n"
        "            }\n"
        "            return 1;\n"
        "        }\n"
        "\n"
    )
    lines.insert(insert_at, handler)
    
    with open(filepath, 'w') as f:
        f.writelines(lines)
    print("Fixed optimizer instruction_size for OP_JUMP_TABLE")

if __name__ == '__main__':
    main()
