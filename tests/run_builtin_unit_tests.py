#!/usr/bin/env python3
import subprocess
import sys
import shlex
import shutil
import os
import glob

expected_ok = [
    "TEST_OK:01_string",
    "TEST_OK:02_math",
    "TEST_OK:03_array",
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

    user_data = os.environ.get('VG_GODOT_USER_DATA_DIR', '/tmp/vg-godot-builtin-unit')
    os.makedirs(user_data, exist_ok=True)

    rc, out_lines = run(
        f'{godot} --path demo --headless --user-data-dir {user_data} -s test_suites/run_builtin_unit_tests.gd'
    )
    if rc != 0:
        print('Godot run failed')
        sys.exit(rc)

    missing = []
    for ok in expected_ok:
        if not any(ok in l for l in out_lines):
            missing.append(ok)
    if missing:
        print('Missing expected test OK markers:')
        for m in missing:
            print(' -', m)
        sys.exit(2)

    print('All unit tests passed')
    sys.exit(0)
