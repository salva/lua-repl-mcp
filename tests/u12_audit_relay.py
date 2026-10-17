"""Bound the independent relay regression, including all owned child processes."""
from containment import enter
enter(420)
import os
from pathlib import Path
import signal
import subprocess

ROOT = Path(__file__).resolve().parents[1]

if __name__ == '__main__':
    process = subprocess.Popen(
        ['lua5.4', str(ROOT / 'tests' / 'u12_audit_relay_red.lua')], cwd=os.environ.get('U9_INSTALLED_CWD', ROOT),
        start_new_session=False,
    )
    try:
        try:
            status = process.wait(timeout=45)
        except subprocess.TimeoutExpired:
            print('FAIL relay regression external 45s watchdog', flush=True)
            status = 1
    finally:
        # Local wait ends here; the external owner reaps the complete tree.
        try:
            process.kill()
        except ProcessLookupError:
            pass
        process.wait()
    raise SystemExit(status)
