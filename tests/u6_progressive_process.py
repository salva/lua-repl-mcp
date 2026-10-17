#!/usr/bin/env python3
"""Bound and contain the real progressive-termination fixture."""
from containment import enter
enter(420)
import os
from pathlib import Path
import signal
import subprocess
root = Path(__file__).resolve().parents[1]
proc = subprocess.Popen(['lua5.4', str(root / 'tests/u6_progressive_process.lua')],
                        cwd=os.environ.get('U9_INSTALLED_CWD', root), start_new_session=False)
try:
    result = proc.wait(timeout=28)
except subprocess.TimeoutExpired:
    result = 124
    print('FAIL progressive termination 28s watchdog', flush=True)
finally:
    try:
        proc.kill()
    except ProcessLookupError:
        pass
raise SystemExit(result)
