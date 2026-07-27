#!/usr/bin/env python3
# Add try_compile_jump_table call in case STMT_SELECT of compile_statement

filepath = 'src/visual_gasic_compiler.cpp'
with open(filepath, 'r') as f:
    lines = f.readlines()

# Find the main compilation STMT_SELECT (third occurrence, has compile_expression)
stmts = []
for i, line in enumerate(lines):
    if 'case STMT_SELECT:' in line:
        stmts.append(i)

print(f'STMT_SELECT occurrences: {[x+1 for x in stmts]}')

if len(stmts) < 3:
    print('ERROR: need at least 3 occurrences')
    exit(1)

main_idx = stmts[2]
print(f'Main compilation STMT_SELECT at line {main_idx + 1}')

# Find the s declaration inside this case
sdecl_idx = None
for i in range(main_idx, min(main_idx + 20, len(lines))):
    if 'SelectStatement* s = (SelectStatement*)stmt;' in lines[i]:
        sdecl_idx = i
        break

if sdecl_idx is None:
    print('ERROR: could not find s declaration')
    exit(1)

print(f"'s' declaration at line {sdecl_idx + 1}: {lines[sdecl_idx].strip()}")

# Insert the call after the s declaration
call_line = '        // M6: Try O(1) jump table dispatch\n        if (try_compile_jump_table(s)) break;\n'
lines.insert(sdecl_idx + 1, call_line)

print(f'Inserted call at line {sdecl_idx + 2}')

with open(filepath, 'w') as f:
    f.writelines(lines)

print('Call inserted.')
