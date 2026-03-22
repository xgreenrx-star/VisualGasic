#!/usr/bin/env python3
import subprocess
import sys
import shlex
import shutil
import os
import glob

expected_lines = [
    "Testing All Features",
    "Meta Result (should be 42):",
    "42.0",
    "Loop Counter (should be 6):",
    "6.0",
    "Done",
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
    rc, _ = run(f'{scons} platform=linux target=editor -j4')
    if rc != 0:
        print('Build failed')
        sys.exit(rc)

    # Detect Godot binary: prefer 4.5.x, then 4.6.x, then any version
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

    # Debug: verify binary and gdextension paths
    so_path = 'demo/addons/visual_gasic/bin/libvisualgasic.linux.template_debug.x86_64.so'
    gdext_path = 'demo/addons/visual_gasic/visual_gasic.gdextension'
    print(f'GDExtension file exists: {os.path.exists(gdext_path)}')
    print(f'Library .so exists: {os.path.exists(so_path)}')

    # Godot requires the project to be opened once to initialize .godot cache.
    # First run: --editor --headless --quit-after 2 to generate filesystem cache
    print('Initializing Godot project cache...')
    run(f'{godot} --path demo --headless --editor --quit-after 2')

    # Run headless demo
    rc, out_lines = run(f'{godot} --path demo --headless -s run_full.gd')
    if rc != 0:
        print('Godot run failed')
        sys.exit(rc)

    # Check expected
    missing = []
    for e in expected_lines:
        if not any(e in l for l in out_lines):
            missing.append(e)
    if missing:
        print('Missing expected output lines:')
        for m in missing:
            print(' -', m)
        sys.exit(2)

    print('Smoke tests passed')
    sys.exit(0)
