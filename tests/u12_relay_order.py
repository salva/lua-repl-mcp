"""Bound complementary guardian relay ordering regressions and contain own group."""
import os
from pathlib import Path
import signal
import subprocess

root = Path(__file__).resolve().parents[1]
p = subprocess.Popen(['lua5.4', 'tests/u12_relay_order.lua'], cwd=root,
                     start_new_session=True)
try:
    try:
        status = p.wait(timeout=55)
    except subprocess.TimeoutExpired:
        print('FAIL relay ordering external 55s watchdog', flush=True)
        status = 1
finally:
    try:
        os.killpg(p.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
raise SystemExit(status)
