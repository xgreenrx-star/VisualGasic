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
    "42",
    "Loop Counter (should be 6):",
    "6",
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

    so_path = 'demo/bin/libvisualgasic.linux.editor.x86_64.so'
    if os.environ.get('VG_SKIP_SCONS') != '1' and not os.path.isfile(so_path):
        rc, _ = run(f'{scons} platform=linux target=editor -j4')
        if rc != 0:
            print('Build failed')
            sys.exit(rc)
    elif os.path.isfile(so_path):
        print(f'Skipping scons; using existing {so_path}')

    # Detect Godot binary: GODOT env, then 4.6.x, 4.5.x, then any version
    godot = os.environ.get('GODOT') or None
    if godot and not os.path.isfile(godot):
        godot = None
    for pattern in ['./Godot_v4.6*_linux.x86_64', './Godot_v4.5*_linux.x86_64', './Godot_v*_linux.x86_64']:
        matches = sorted(glob.glob(pattern))
        if matches:
            godot = matches[-1]
            break
    if not godot:
        print('No Godot binary found')
        sys.exit(1)
    print(f'Using Godot: {godot}')

    prepare = './scripts/prepare_ci_gdextension.sh'
    if os.path.isfile(prepare):
        rc, _ = run(f'bash {prepare}')
        if rc != 0:
            print('prepare_ci_gdextension.sh failed')
            sys.exit(rc)

    gdext_path = 'demo/addons/visual_gasic/visual_gasic.gdextension'
    bin_so = 'demo/addons/visual_gasic/bin/libvisualgasic.linux.editor.x86_64.so'
    print(f'GDExtension file exists: {os.path.exists(gdext_path)}')
    print(f'Library .so exists: {os.path.exists(bin_so)}')

    user_data = os.environ.get('VG_GODOT_USER_DATA_DIR', '/tmp/vg-godot-smoke')
    os.makedirs(user_data, exist_ok=True)

    # Run headless demo (runners live under demo/test_suites/)
    rc, out_lines = run(
        f'{godot} --path demo --headless --user-data-dir {user_data} -s test_suites/run_full.gd'
    )
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
