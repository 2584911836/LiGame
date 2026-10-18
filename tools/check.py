"""Run useful Godot checks in isolated user-data directories.
Usage: python3 tools/check.py [path-to-godot]
Only Python's standard library is needed. Fails on nonzero exit, engine errors,
missing/empty test summaries, failed assertions or resource-leak warnings.
"""
from pathlib import Path
import os
import re
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
engine = sys.argv[1] if len(sys.argv) > 1 else 'godot'
suites = ('smoke', 'systems', 'levels', 'preferences', 'input_options', 'menus', 'traversal')
with tempfile.TemporaryDirectory(prefix='ligame-check-') as runtime:
    environment = os.environ.copy()
    for name, directory in (('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache')):
        destination = Path(runtime) / directory
        destination.mkdir()
        environment[name] = str(destination)
    commands = [('import', ['--editor', '--import', '--quit'])]
    commands += [(name, ['--fixed-fps', '60', '--script', f'tests/{name}.gd']) for name in suites]
    for name, arguments in commands:
        result = subprocess.run([engine, '--headless', '--path', str(root), *arguments],
                                env=environment, text=True, capture_output=True, timeout=180)
        output = result.stdout + result.stderr
        bad = result.returncode != 0 or re.search(r'(SCRIPT ERROR:|^ERROR:|^FAIL:|instances leaked)', output, re.M)
        if name != 'import':
            summary = re.search(r'RESULT: (\d+) passed, 0 failed', output)
            traversal = re.search(r'RESULT: (\d+) complete stages; failure=false', output)
            bad = bad or not ((summary and int(summary[1]) > 0) or (traversal and int(traversal[1]) > 0))
        if bad:
            print(output)
            raise SystemExit(f'FAILED: {name} (exit {result.returncode})')
        lines = [line for line in output.splitlines() if line.startswith('RESULT:')]
        print(f'PASS: {name}' + (f' — {lines[-1]}' if lines else ''), flush=True)
print('All checks passed; real-user saves and settings were not touched.')
