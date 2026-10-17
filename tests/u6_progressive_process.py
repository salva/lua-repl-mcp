#!/usr/bin/env python3
"""Bound and contain the real progressive-termination fixture."""
import os
from pathlib import Path
import signal
import subprocess
root = Path(__file__).resolve().parents[1]
proc = subprocess.Popen(['lua5.4', 'tests/u6_progressive_process.lua'],
                        cwd=root, start_new_session=True)
try:
    result = proc.wait(timeout=28)
except subprocess.TimeoutExpired:
    result = 124
    print('FAIL progressive termination 28s watchdog', flush=True)
finally:
    try:
        os.killpg(proc.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
raise SystemExit(result)
