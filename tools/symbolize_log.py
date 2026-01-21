#!/usr/bin/env python3
import re
from pathlib import Path

root = Path('/home/Commodore/Documents/VisualGasic')
log_in = root / 'run_headless_bt.log'
offsets = root / 'offsets.txt'
sym = root / 'sym_map.txt'
log_out = root / 'run_headless_sym.log'

# Read offsets and map to two-line symbol entries
offs = [line.strip() for line in offsets.read_text().splitlines() if line.strip()]
syms_lines = [line.rstrip('\n') for line in sym.read_text().splitlines()]

# Each offset corresponds to two lines in sym_map.txt (function line, file:line)
mapping = {}
idx = 0
for off in offs:
    if idx >= len(syms_lines):
        break
    func = syms_lines[idx] if idx < len(syms_lines) else '??'
    fileline = syms_lines[idx+1] if (idx+1) < len(syms_lines) else '??:0'
    mapping[off.lower().lstrip('0')] = (func, fileline)
    idx += 2

# Replacement: find +0x.... occurrences and add annotation
pattern = re.compile(r"\+0x([0-9a-fA-F]+)")

out_lines = []
for line in log_in.read_text().splitlines():
    def repl(m):
        key = m.group(0)
        off = m.group(1).lower()
        entry = mapping.get(off)
        if entry:
            func, fileline = entry
            return f"{key} ({func} -- {fileline})"
        return key
    newline = pattern.sub(repl, line)
    out_lines.append(newline)

log_out.write_text('\n'.join(out_lines))
print('Wrote', log_out)
