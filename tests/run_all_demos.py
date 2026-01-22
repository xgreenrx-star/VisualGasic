#!/usr/bin/env python3
import subprocess, shlex, os, sys, shutil

# List of demo bas files to test
demos = [
    'examples/AssetLib/ballistic/demo/ballistic_demo.bas',
    'examples/AssetLib/dual_kawase/demo/dual_kawase_demo.bas',
    'examples/AssetLib/fancy_styleboxes/demo/styleboxes_demo.bas',
    'examples/AssetLib/fight_engine/demo/fight_demo.bas',
    'examples/AssetLib/fps_weapon/demo/fps_weapon_demo.bas',
    'examples/AssetLib/horror_survival/demo/horror_demo.bas',
    'examples/AssetLib/laser3d/demo/laser3d_demo.bas',
    'examples/AssetLib/procedural3d/demo/procedural_demo.bas',
    'examples/AssetLib/psx_visuals/demo/psx_demo.bas',
    'examples/AssetLib/starter_assets/demo/starter_demo.bas',
]

report = []

def run(cmd):
    p = subprocess.Popen(shlex.split(cmd), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    out = []
    while True:
        line = p.stdout.readline()
        if not line:
            break
        print(line, end='')
        out.append(line)
    p.wait()
    return p.returncode, out

# Ensure build is up to date
rc, _ = run('./.venv/bin/scons platform=linux target=template_debug -j4')
if rc != 0:
    print('Build failed')
    sys.exit(rc)

for demo in demos:
    base = os.path.dirname(demo)
    print('\n==== Running demo: ' + demo)
    # copy demo script into demo/test_demo.bas
    shutil.copy(demo, 'demo/test_demo.bas')
    # write demo identifier file for the runner to pick up
    with open('demo/.current_demo', 'w') as fh:
        fh.write(demo)
    # run headless
    rc, out = run('./Godot_v4.5.1-stable_linux.x86_64 --path demo --no-window -s run_demo.gd')
    # analyze
    success = any('DEMO_RUNNER_DONE' in l for l in out)
    errors = [l for l in out if 'ERROR' in l or 'Script error' in l or 'Exception' in l]
    missing_keywords = [l for l in out if 'not found' in l or 'Missing' in l or 'not implemented' in l]
    report.append((demo, success, errors, missing_keywords, out))

# Print summary
print('\n\n=== Demo run summary')
for demo, success, errors, missing, out in report:
    status = 'OK' if success and not errors else 'FAIL'
    print(f'{demo}: {status}')
    if errors:
        print('  Errors:')
        for e in errors[:5]:
            print('   -', e.strip())
    if missing:
        print('  Warnings / not found:')
        for m in missing[:5]:
            print('   -', m.strip())

# Exit non-zero if any failed
if any(not (s and not e) for (_, s, e, _, _) in report):
    print('\nSome demos failed. Use the output above to begin repairs.')
    sys.exit(2)

print('\nAll demos ran (no blocking errors found).')
sys.exit(0)
