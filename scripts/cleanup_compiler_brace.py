#!/usr/bin/env python3
"""Clean up the ugly if(false) else wrapping in the compiler patch."""

def main():
    filepath = 'src/visual_gasic_compiler.cpp'
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Find and remove the if(false){} else { wrapper
    old_pattern = '''            SelectStatement* s = (SelectStatement*)stmt;
        // M6: Jump table dispatch for dense integer Select Case
        if (false) {}  // scope bracket — we use a leading {} to balance
        else {'''
    
    new_pattern = '''            SelectStatement* s = (SelectStatement*)stmt;

        // M6: Jump table dispatch for dense integer Select Case'''
    
    if old_pattern in content:
        content = content.replace(old_pattern, new_pattern)
        print("Fixed ugly scope wrapper")
    else:
        print("Pattern not found — may already be clean or different")
        # Show the area around the pattern
        idx = content.find('SelectStatement* s = (SelectStatement*)stmt;')
        if idx >= 0:
            snippet = content[idx:idx+300]
            print(f"Found s declaration at offset {idx}:")
            print(repr(snippet[:200]))
    
    # Also find and remove the closing brace of the else block
    # Pattern: after the compile_ok = true; break; block, there's a closing }
    # followed by "// Fall through if jump table not viable"
    # The closing } is the end of the else block
    
    # Find the end of the jump table block
    marker = "break;  // Done — skip sequential fallback"
    idx = content.find(marker)
    if idx >= 0:
        # Find the next closing brace that ends the else block
        # Look for "}\n        }\n        // Fall through"
        after_break = content[idx + len(marker):]
        closing_end = after_break.find("}\n        }\n        // Fall through")
        if closing_end >= 0:
            # Remove the inner closing brace and the outer else closing brace
            # We want: keep everything up to marker, then remove } } and just have // Fall through
            before = content[:idx + len(marker)]
            after = content[idx + len(marker) + closing_end:]
            # The section we're removing includes "\n            }\n        }\n        // Fall through"
            # We want to remove the inner } and outer } but keep "// Fall through"
            # Find just the inner }
            inner_brace = after_break.find("\n            }")
            if inner_brace >= 0:
                # Verify the next line is "        }"
                after_inner = after_break[inner_brace:]
                start_of_outer = after_inner.find("\n        }")
                if start_of_outer >= 0:
                    # Remove from inner brace start to after outer brace
                    remove_start = idx + len(marker) + inner_brace
                    remove_end = idx + len(marker) + inner_brace + start_of_outer + len("\n        }")
                    content = content[:remove_start] + content[remove_end:]
                    print("Removed ugly else closing braces")
                else:
                    print("Could not find outer closing brace")
            else:
                print("Could not find inner closing brace")
        else:
            print("Could not find closing brace pattern")
    
    with open(filepath, 'w') as f:
        f.write(content)
    print("Cleanup done.")

if __name__ == '__main__':
    main()
