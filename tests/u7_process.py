#!/usr/bin/env python3
"""Run U7 real-process fixtures with scoped files and a process-group watchdog."""
import os
from pathlib import Path
import resource
import signal
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
work = Path(os.environ['SAIVAGE_CARD_WORK_ROOT']) / 'u7-process-verification'
work.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
env['LUA_PATH'] = f'{root}/?.lua;{root}/?/init.lua;' + env.get('LUA_PATH', ';')
for fixture, timeout in [('u7_fairness_process.lua', 25),
                         ('u7_transport_process.lua', 25),
                         ('u7_maximum_process.lua', 110)]:
    with tempfile.TemporaryDirectory(dir=work) as directory:
        env['U7_DIR'] = directory
        proc = subprocess.Popen(['lua5.4', str(root / 'tests' / fixture)],
                                cwd=root, env=env, start_new_session=True,
                                preexec_fn=lambda: resource.setrlimit(resource.RLIMIT_NOFILE, (256, 256)))
        try:
            result = proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            print('FAIL U7 watchdog: ' + fixture, flush=True)
            result = 124
        finally:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        if result:
            raise SystemExit(result)
print('PASS U7 real-process watchdog groups', flush=True)
