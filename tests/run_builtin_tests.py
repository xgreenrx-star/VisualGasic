#!/usr/bin/env python3
import subprocess
import sys
import shlex

expected_substrings = [
    "BUILTINS_START",
    "LEN:5",
    "LEFT:he",
    "RIGHT:lo",
    "MID:el",
    "UCASE:ABC",
    "LCASE:abc",
    "ASC:65",
    "CHR:A",
    "SIN0:0",
    "ABS:5",
    "INT:3",
    "ROUND:4",
    # Vector helpers
    "VADD_X:3",
    "VDOT:20",
    "VCROSS_X:-1",
    "VCROSS_Y:2",
    "VCROSS_Z:-1",
    "VLEN:5.0",
    # AddChild/SetProp smoke
    "ADDCHILD_POS_X:10",
    "BUILTINS_DONE",
]

def run(cmd):
    print(f"> {cmd}")
    p = subprocess.Popen(shlex.split(cmd), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    out_lines = []
    while True:
        line = p.stdout.readline()
        if not line:
            break
        print(line, end='')
        out_lines.append(line.strip())
    p.wait()
    return p.returncode, out_lines

if __name__ == '__main__':
    # Build
    rc, _ = run('./.venv/bin/scons platform=linux target=template_debug -j4')
    if rc != 0:
        print('Build failed')
        sys.exit(rc)

    # Run headless demo test runner
    rc, out_lines = run('./Godot_v4.5.1-stable_linux.x86_64 --path demo --no-window -s run_builtins.gd')
    if rc != 0:
        print('Godot run failed')
        sys.exit(rc)

    # Check expected substrings
    missing = []
    for e in expected_substrings:
        if not any(e in l for l in out_lines):
            missing.append(e)
    if missing:
        print('Missing expected substrings:')
        for m in missing:
            print(' -', m)
        sys.exit(2)

    print('Builtin tests passed')
    sys.exit(0)
