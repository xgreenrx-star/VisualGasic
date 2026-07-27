#!/usr/bin/env python3
"""Add OP_JUMP_TABLE opcode size handling to the script disassembler."""

def main():
    filepath = 'src/visual_gasic_script.cpp'
    with open(filepath, 'r') as f:
        lines = f.readlines()
    
    # Find the opcode size switch statement
    insert_at = None
    for i, line in enumerate(lines):
        if 'case OP_BUF_RESIZE:' in line:
            # The buffer opcodes are 2-byte; insert JT case nearby
            for j in range(i, min(i+10, len(lines))):
                if 'return 2;' in lines[j]:
                    insert_at = j + 1
                    break
            break
    
    # If OP_BUF_RESIZE not found, try another marker
    if insert_at is None:
        for i, line in enumerate(lines):
            if 'case OP_BUF_RESIZE:' in line:
                insert_at = i + 1
                break
    
    if insert_at is None:
        print("Could not find insertion point in script disassembler")
        return
    
    handler = [
        '        case OP_JUMP_TABLE: {\n',
        '            // Variable-length: 8 header bytes + num_cases * 2\n',
        '            if (operands.size() >= 8) {\n',
        '                int num_cases = (int(operands[7]) << 8) | int(operands[6]);\n',
        '                return 8 + num_cases * 2;\n',
        '            }\n',
        '            return 1;\n',
        '        }\n',
    ]
    
    for handler_line in reversed(handler):
        lines.insert(insert_at, handler_line)
    
    with open(filepath, 'w') as f:
        f.writelines(lines)
    
    print("Fixed script disassembler for OP_JUMP_TABLE")

if __name__ == '__main__':
    main()
