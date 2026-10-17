"""Bound the independent relay regression, including all owned child processes."""
import os
from pathlib import Path
import signal
import subprocess

ROOT = Path(__file__).resolve().parents[1]

if __name__ == '__main__':
    process = subprocess.Popen(
        ['lua5.4', 'tests/u12_audit_relay_red.lua'], cwd=ROOT,
        start_new_session=True,
    )
    try:
        try:
            status = process.wait(timeout=45)
        except subprocess.TimeoutExpired:
            print('FAIL relay regression external 45s watchdog', flush=True)
            status = 1
    finally:
        # Contain only the isolated test group, never other project processes.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()
    raise SystemExit(status)
