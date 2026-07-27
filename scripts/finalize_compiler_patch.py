#!/usr/bin/env python3
"""Fix compiler C++ issues: duplicate variable name, brace cleanup."""

def main():
    filepath = 'src/visual_gasic_compiler.cpp'
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Fix 1: Rename jt_select_slot to jt_sel_slot to avoid conflict with sequential path
    old = 'int select_slot = get_or_add_local(String("__jtsel_' 
    if old in content:
        new = 'int jt_sel_slot = get_or_add_local(String("__jtsel_'
        content = content.replace(old, new)
        print("Fixed jt_sel_slot name conflict")
    else:
        print("Could not find old jt_sel_slot pattern — searching...")
        idx = content.find('__jtsel_')
        if idx >= 0:
            print(f"Found at offset {idx}: {repr(content[idx:idx+80])}")
    
    # Fix 2: The emit_bytes calls using select_slot inside JT block also need renaming
    old2 = 'emit_bytes(OP_SET_LOCAL, (uint8_t)select_slot);'
    if old2 in content:
        # Check if it's inside the JT block by looking for jt_select context
        # Since we renamed to jt_sel_slot, the first occurrence might be the JT one
        # Hmm, actually single_find_and_replace with replace_all=false will fix it incrementally
        # But simple replace will fix all. Let me be more careful:
        # Replace only the ones in the JT block
        pass
    
    # Simpler approach: Find the JT block section and replace select_slot -> jt_sel_slot there
    jt_start = content.find('// M6: Jump table dispatch')
    jt_end = content.find('// Fall through if jump table not viable')
    if jt_start >= 0 and jt_end >= 0 and jt_start < jt_end:
        jt_section = content[jt_start:jt_end]
        # Replace select_slot with jt_sel_slot in this section only
        jt_section_fixed = jt_section.replace('int select_slot =', 'int jt_sel_slot =')
        jt_section_fixed = jt_section_fixed.replace('(uint8_t)select_slot', '(uint8_t)jt_sel_slot')
        content = content[:jt_start] + jt_section_fixed + content[jt_end:]
        print("Renamed select_slot → jt_sel_slot in JT block")
    
    # Fix 3: The JT block outer scope cleanup was incomplete (closing brace of outer else)
    # The code after break; should be:
    #            break;  // Done — skip sequential fallback
    #        }
    #        // Fall through if jump table not viable  
    #
    # But currently is:
    #            break;  // Done — skip sequential fallback
    #   // Fall through if jump table not viable
    # Let me verify the structure
    
    marker = 'break;  // Done — skip sequential fallback'
    idx = content.find(marker)
    if idx >= 0:
        after = content[idx:idx+200]
        print(f"After break: {repr(after[:120])}")
    
    # The issue: The jump table if block needs explicit braces and the else needs
    # to wrap the sequential fallback. Let me just ensure the failing code path
    # (jump table not viable) falls through cleanly to the sequential path.
    # As written, the if block either breaks (on success) or falls through (on failure).
    # This is correct. Just need the redeclaration fix.
    
    with open(filepath, 'w') as f:
        f.write(content)
    
    print("Finalization complete.")
    print("\nRemaining tasks:")
    print("  1. Fix script disassembler for OP_JUMP_TABLE variable-length")
    print("  2. Build and verify")


if __name__ == '__main__':
    main()
