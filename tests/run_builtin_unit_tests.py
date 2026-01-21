#!/usr/bin/env python3
import subprocess
import sys
import shlex

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
    # No rebuild by default — assume built library is present. Build if missing.
    rc, _ = run('./.venv/bin/scons platform=linux target=template_debug -j4')
    if rc != 0:
        print('Build failed')
        sys.exit(rc)

    rc, out_lines = run('./Godot_v4.5.1-stable_linux.x86_64 --path demo --no-window -s run_builtin_unit_tests.gd')
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
