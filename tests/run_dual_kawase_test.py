#!/usr/bin/env python3
import subprocess
import sys
import shlex

expected_substrings = [
    "DUAL_KAWASE_TEST_START",
    "DualKawaseFake: apply_to_viewport called",
    "DualKawaseFake: compositor/eff created",
    "DUAL_KAWASE_FAKE_FREED",
    "DUAL_KAWASE_TEST_DONE",
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
    # Ensure output dir exists and remove any previous screenshot
    import os
    out_dir = 'tests/output'
    os.makedirs(out_dir, exist_ok=True)
    out_file = os.path.join(out_dir, 'dual_kawase.png')
    try:
        os.remove(out_file)
    except FileNotFoundError:
        pass

    rc, _ = run('./.venv/bin/scons platform=linux target=template_debug -j4')
    if rc != 0:
        print('Build failed')
        sys.exit(rc)

    rc, out_lines = run('./Godot_v4.5.1-stable_linux.x86_64 --path demo --no-window -s run_dual_kawase_test.gd')
    if rc != 0:
        print('Godot run failed')
        sys.exit(rc)

    # Fail if Godot reported leaked compositor RIDs
    for l in out_lines:
        if 'RID allocations' in l and 'were leaked' in l:
            print('RID leak detected:')
            print(l)
            sys.exit(3)

    missing = []
    for e in expected_substrings:
        if not any(e in l for l in out_lines):
            missing.append(e)
    if missing:
        print('Missing expected substrings:')
        for m in missing:
            print(' -', m)
        sys.exit(2)

    # Verify screenshot saved and is non-trivial
    saved_line = None
    for l in out_lines:
        if 'DUAL_KAWASE_SCREENSHOT_SAVED:' in l:
            saved_line = l
            break
    if not saved_line:
        print('Screenshot not saved:')
        for l in out_lines:
            print(l)
        sys.exit(4)

    path = saved_line.split(':', 1)[1]
    if not os.path.exists(path):
        print('Screenshot file not found at', path)
        sys.exit(5)

    size = os.path.getsize(path)
    print('Screenshot file size:', size)
    if size < 1024:
        print('Screenshot file too small, probably blank or failed')
        sys.exit(6)

    # Pixel-diff check against golden baseline
    from PIL import Image, ImageChops, ImageStat
    golden_path = os.path.join('tests', 'goldens', 'dual_kawase.png')
    if not os.path.exists(golden_path):
        print('Golden baseline not found, creating baseline at', golden_path)
        import shutil
        shutil.copy(path, golden_path)
        print('Baseline created — consider committing tests/goldens/dual_kawase.png')
        print('Dual Kawase test passed (baseline created)')
        sys.exit(0)

    g = Image.open(golden_path).convert('RGBA')
    o = Image.open(path).convert('RGBA')
    if g.size != o.size:
        print('Golden and output sizes differ:', g.size, o.size)
        sys.exit(7)

    diff = ImageChops.difference(g, o)
    # count non-zero pixels
    nonzero = 0
    for px in diff.getdata():
        if px != (0, 0, 0, 0):
            nonzero += 1
    total = diff.size[0] * diff.size[1]
    nonzero_pct = (nonzero / total) * 100.0
    stat = ImageStat.Stat(diff)
    mean_diff = sum(stat.mean) / len(stat.mean)

    print(f'Pixel diff: {nonzero} pixels ({nonzero_pct:.3f}%), mean channel diff {mean_diff:.3f}')

    # thresholds: <2% pixels different AND mean channel diff < 8
    if nonzero_pct > 2.0 or mean_diff > 8.0:
        diff_path = os.path.join('tests', 'output', 'dual_kawase_diff.png')
        diff.save(diff_path)
        print('Visual diff too large, saved diff to', diff_path)
        sys.exit(8)

    print('Dual Kawase test passed with screenshot (visual match)')
    sys.exit(0)