"""Bound complementary guardian relay ordering regressions and inherit external containment."""
from containment import enter
enter(420)
import os
from pathlib import Path
import signal
import subprocess

root = Path(__file__).resolve().parents[1]
p = subprocess.Popen(['lua5.4', str(root / 'tests' / 'u12_relay_order.lua')], cwd=os.environ.get('U9_INSTALLED_CWD', root),
                     start_new_session=False)
try:
    try:
        status = p.wait(timeout=55)
    except subprocess.TimeoutExpired:
        print('FAIL relay ordering external 55s watchdog', flush=True)
        status = 1
finally:
    try:
        p.kill()
    except ProcessLookupError:
        pass
raise SystemExit(status)
