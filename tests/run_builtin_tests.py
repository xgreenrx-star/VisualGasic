#!/usr/bin/env python3
import subprocess
import sys
import shlex
import shutil
import os
import glob

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
    # Find scons: prefer venv, then system PATH
    scons = './.venv/bin/scons'
    if not shutil.which(scons):
        scons = shutil.which('scons') or 'scons'

    # Build
    rc, _ = run(f'{scons} platform=linux target=template_debug -j4')
    if rc != 0:
        print('Build failed')
        sys.exit(rc)

    # Detect Godot binary
    godot = None
    for pattern in ['./Godot_v4.5*_linux.x86_64', './Godot_v4.6*_linux.x86_64', './Godot_v*_linux.x86_64']:
        matches = sorted(glob.glob(pattern))
        if matches:
            godot = matches[-1]
            break
    if not godot:
        print('No Godot binary found')
        sys.exit(1)
    print(f'Using Godot: {godot}')

    # Ensure .godot/extension_list.cfg exists (may be gitignored)
    ext_list = 'demo/.godot/extension_list.cfg'
    os.makedirs('demo/.godot', exist_ok=True)
    if not os.path.exists(ext_list):
        with open(ext_list, 'w') as f:
            f.write('res://addons/visual_gasic/visual_gasic.gdextension\n')

    # Import project first to generate caches
    print('Importing project...')
    run(f'{godot} --path demo --headless --import')

    # Run headless demo test runner
    rc, out_lines = run(f'{godot} --path demo --headless -s run_builtins.gd')
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
