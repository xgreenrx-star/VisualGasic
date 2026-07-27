#!/usr/bin/env python3
# Add try_compile_jump_table declaration to compiler header

filepath = 'src/visual_gasic_compiler.h'
with open(filepath, 'r') as f:
    lines = f.readlines()

# Find line with void compile_expression(ExpressionNode* expr);
target = None
for i, line in enumerate(lines):
    if 'void compile_expression(ExpressionNode* expr);' in line:
        target = i
        break

if target is None:
    print('ERROR: could not find compile_expression declaration')
    exit(1)

print(f'Found at line {target + 1}: {lines[target].strip()}')

# Insert after this line
decl = '\n    // M6: Try to compile a Select Case as a dense O(1) jump table.\n    // Returns true if successful (and emits bytecode), false if fallback needed.\n    bool try_compile_jump_table(SelectStatement* s);\n'
lines.insert(target + 1, decl)

with open(filepath, 'w') as f:
    f.writelines(lines)

print('Header updated.')
