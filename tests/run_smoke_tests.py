#!/usr/bin/env python3
import subprocess
import sys
import shlex

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
    # Build
    rc, _ = run('./.venv/bin/scons platform=linux target=template_debug -j4')
    if rc != 0:
        print('Build failed')
        sys.exit(rc)

    # Run headless demo
    rc, out_lines = run('./Godot_v4.5.1-stable_linux.x86_64 --path demo --no-window -s run_full.gd')
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
